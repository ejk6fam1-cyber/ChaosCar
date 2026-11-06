extends Node
## Online play (autoload "Net"). The same script runs on the server and in every player's game.
##
## Server: one headless copy of Chaos Car listening for WebSocket connections. Players make race rooms
## with a 4-letter code; the server runs each room's race (all 64 cars, all the physics) and streams the
## cars to the players in it about 20 times a second. Players only send their lane taps.
##
## Client: connects to the server's address, creates or joins a room, and shows the race it's sent.

signal connected
signal connection_failed(reason: String)
signal disconnected
signal lobby_changed(state: Dictionary)
signal race_started(cfg: Dictionary)
signal error_message(text: String)

const PROTOCOL := 1                  # bump when client and server must update together
const MAX_PLAYERS := 4
const SEND_EVERY := 3                # physics ticks between snapshots (60 / 3 = 20 a second)
const DEFAULT_SERVER := "ws://localhost:9080"
const SETTINGS_FILE := "user://chaos_car.cfg"

var is_server := false
var room_state := {}                 # client: the lobby as the server last described it
var race: Race                       # client: the race on screen (set by main.gd)

# ---- server-side bookkeeping
var _rooms := {}                     # code -> room Dictionary
var _peer_room := {}                 # peer id -> code
var _tick := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: connected.emit())
	multiplayer.connection_failed.connect(func() -> void:
		multiplayer.multiplayer_peer = null
		connection_failed.emit("Couldn't reach the server."))
	multiplayer.server_disconnected.connect(func() -> void:
		multiplayer.multiplayer_peer = null
		room_state = {}
		disconnected.emit())


# =================================================================== settings saved between sessions

func load_setting(key: String, default: Variant) -> Variant:
	var cf := ConfigFile.new()
	if cf.load(SETTINGS_FILE) != OK:
		return default
	return cf.get_value("net", key, default)


func save_setting(key: String, value: Variant) -> void:
	var cf := ConfigFile.new()
	cf.load(SETTINGS_FILE)
	cf.set_value("net", key, value)
	cf.save(SETTINGS_FILE)


## The server address: one baked into the web build (server_url.txt) wins over the saved one.
func default_server() -> String:
	if FileAccess.file_exists("res://server_url.txt"):
		var baked := FileAccess.get_file_as_string("res://server_url.txt").strip_edges()
		if baked != "":
			return load_setting("server", baked)
	return load_setting("server", DEFAULT_SERVER)


# =================================================================== server

func start_server(port: int) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	print("Chaos Car server listening on port %d" % port)
	return OK


func _on_peer_connected(id: int) -> void:
	if is_server:
		print("player %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	if is_server:
		print("player %d left" % id)
		_leave_room(id)


func _new_code() -> String:
	var letters := "ABCDEFGHJKLMNPQRSTUVWXYZ"     # no I or O (they look like 1 and 0)
	while true:
		var code := ""
		for i in 4:
			code += letters[_rng.randi_range(0, letters.length() - 1)]
		if not _rooms.has(code):
			return code
	return ""


func _room_public(room: Dictionary) -> Dictionary:
	var players: Array = []
	for id in room["players"]:
		players.append({"id": id, "name": room["names"][id], "spot": room["spots"][id]})
	return {"code": room["code"], "host": room["host"], "laps": room["laps"], "grid": room["grid"],
		"racing": room["race"] != null, "players": players}


func _broadcast_lobby(room: Dictionary) -> void:
	var st := _room_public(room)
	for id in room["players"]:
		lobby_state.rpc_id(id, st)


func _leave_room(id: int) -> void:
	if not _peer_room.has(id):
		return
	var code: String = _peer_room[id]
	_peer_room.erase(id)
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	room["players"].erase(id)
	room["names"].erase(id)
	room["spots"].erase(id)
	if room["players"].is_empty():
		if room["race"]:
			(room["race"] as Race).queue_free()
		_rooms.erase(code)
		print("room %s closed" % code)
		return
	if room["host"] == id:
		room["host"] = room["players"][0]
	_broadcast_lobby(room)


func _clean_name(n: String) -> String:
	n = n.strip_edges().left(14)
	return n if n != "" else "Player"


# ---- requests from players (they arrive at the server)

@rpc("any_peer", "call_remote", "reliable")
func req_create(player_name: String, protocol: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		error_msg.rpc_id(id, "This game is out of date - refresh the page.")
		return
	_leave_room(id)
	var code := _new_code()
	var room := {"code": code, "host": id, "players": [id], "names": {id: _clean_name(player_name)},
		"spots": {id: Race.DEFAULT_SPOT}, "laps": Race.DEFAULT_LAPS, "grid": "random", "race": null}
	_rooms[code] = room
	_peer_room[id] = code
	print("room %s created by %d" % [code, id])
	_broadcast_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func req_join(code: String, player_name: String, protocol: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		error_msg.rpc_id(id, "This game is out of date - refresh the page.")
		return
	code = code.strip_edges().to_upper()
	if not _rooms.has(code):
		error_msg.rpc_id(id, "No race with code %s." % code)
		return
	var room: Dictionary = _rooms[code]
	if room["players"].size() >= MAX_PLAYERS:
		error_msg.rpc_id(id, "That race is full (%d players)." % MAX_PLAYERS)
		return
	if room["race"] != null:
		error_msg.rpc_id(id, "That race has already started - wait for it to finish.")
		return
	_leave_room(id)
	room["players"].append(id)
	room["names"][id] = _clean_name(player_name)
	# custom grid: start next to the others
	var spot := Race.DEFAULT_SPOT
	var taken: Array = room["spots"].values()
	while taken.has(spot):
		spot += 1
	room["spots"][id] = spot
	_peer_room[id] = code
	_broadcast_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func req_settings(new_laps: int, grid: String) -> void:
	var room := _sender_room()
	if room.is_empty() or room["host"] != multiplayer.get_remote_sender_id() or room["race"] != null:
		return
	room["laps"] = clampi(new_laps, 1, 20)
	room["grid"] = "custom" if grid == "custom" else "random"
	_broadcast_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func req_spot(spot: int) -> void:
	var room := _sender_room()
	if room.is_empty() or room["race"] != null:
		return
	var id := multiplayer.get_remote_sender_id()
	spot = clampi(spot, 1, Race.FIELD)
	for other in room["players"]:
		if other != id and room["spots"][other] == spot:
			error_msg.rpc_id(id, "Spot %d is taken." % spot)
			_broadcast_lobby(room)
			return
	room["spots"][id] = spot
	_broadcast_lobby(room)


@rpc("any_peer", "call_remote", "reliable")
func req_start() -> void:
	var room := _sender_room()
	if room.is_empty() or room["host"] != multiplayer.get_remote_sender_id() or room["race"] != null:
		return
	var humans: Array = []
	for id in room["players"]:
		humans.append({"id": id, "name": room["names"][id], "spot": room["spots"][id]})
	var r := Race.new()
	r.setup({"mode": "server", "laps": room["laps"], "grid": room["grid"], "humans": humans,
		"seed": _rng.randi()})
	r.name = "Race_" + room["code"]
	add_child(r)
	room["race"] = r
	r.race_over.connect(_on_race_over.bind(room["code"]))
	var roster := r.public_roster()
	for id in room["players"]:
		race_start.rpc_id(id, {"laps": room["laps"], "roster": roster, "local_id": id})
	_broadcast_lobby(room)
	print("room %s racing: %d players, %d laps" % [room["code"], humans.size(), room["laps"]])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func req_tap(dir: int) -> void:
	var room := _sender_room()
	if room.is_empty() or room["race"] == null:
		return
	(room["race"] as Race).human_tap(multiplayer.get_remote_sender_id(), dir)


@rpc("any_peer", "call_remote", "reliable")
func req_leave() -> void:
	if is_server:
		_leave_room(multiplayer.get_remote_sender_id())


func _sender_room() -> Dictionary:
	if not is_server:
		return {}
	var id := multiplayer.get_remote_sender_id()
	if not _peer_room.has(id) or not _rooms.has(_peer_room[id]):
		return {}
	return _rooms[_peer_room[id]]


func _on_race_over(code: String) -> void:
	if not _rooms.has(code):
		return
	var room: Dictionary = _rooms[code]
	var r: Race = room["race"]
	var fin := r.finish_data()
	for id in room["players"]:
		race_end.rpc_id(id, r.snapshot(), fin[0], fin[1])
	room["race"] = null
	r.queue_free()
	_broadcast_lobby(room)
	print("room %s race over" % code)


func _physics_process(_delta: float) -> void:
	if not is_server:
		return
	_tick += 1
	if _tick % SEND_EVERY != 0:
		return
	for room: Dictionary in _rooms.values():
		var r: Race = room["race"]
		if r == null or not r.is_inside_tree():
			continue
		var snap := r.snapshot()
		var fin := r.finish_data()
		for id in room["players"]:
			snapshot.rpc_id(id, snap, fin[0], fin[1])


# =================================================================== client

func connect_to(url: String) -> Error:
	disconnect_from()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func disconnect_from() -> void:
	if multiplayer.multiplayer_peer and not is_server:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	room_state = {}


func is_online() -> bool:
	return not is_server and multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func my_id() -> int:
	return multiplayer.get_unique_id()


func create_room(player_name: String) -> void:
	req_create.rpc_id(1, player_name, PROTOCOL)


func join_room(code: String, player_name: String) -> void:
	req_join.rpc_id(1, code, player_name, PROTOCOL)


func set_settings(new_laps: int, grid: String) -> void:
	req_settings.rpc_id(1, new_laps, grid)


func pick_spot(spot: int) -> void:
	req_spot.rpc_id(1, spot)


func start_race() -> void:
	req_start.rpc_id(1)


func send_tap(dir: int) -> void:
	if is_online():
		req_tap.rpc_id(1, dir)


func leave_room() -> void:
	if is_online():
		req_leave.rpc_id(1)
	room_state = {}


# ---- messages from the server (they arrive at players)

@rpc("authority", "call_remote", "reliable")
func lobby_state(st: Dictionary) -> void:
	room_state = st
	lobby_changed.emit(st)


@rpc("authority", "call_remote", "reliable")
func race_start(cfg: Dictionary) -> void:
	race_started.emit(cfg)


@rpc("authority", "call_remote", "unreliable_ordered")
func snapshot(data: PackedFloat32Array, fin_idx: PackedInt32Array, fin_t: PackedFloat32Array) -> void:
	if race and is_instance_valid(race):
		race.apply_snapshot(data, fin_idx, fin_t)


@rpc("authority", "call_remote", "reliable")
func race_end(data: PackedFloat32Array, fin_idx: PackedInt32Array, fin_t: PackedFloat32Array) -> void:
	if race and is_instance_valid(race):
		race.apply_snapshot(data, fin_idx, fin_t)
		race.set_done()


@rpc("authority", "call_remote", "reliable")
func error_msg(text: String) -> void:
	error_message.emit(text)
