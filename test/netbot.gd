extends Node
## Online test player. --bot=create (makes the room, sets 1 lap / custom grid, starts when 2 are in)
## or --bot=join (reads the code from /tmp/cc_code.txt and joins). Taps lanes now and then.
var who := ""
var race: Race
var t := 0.0
var next_tap := 3.0
var next_log := 0.0
var snaps := 0
var started := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			who = a.substr(6)
	Net.connected.connect(_on_connected)
	Net.lobby_changed.connect(_on_lobby)
	Net.race_started.connect(_on_race)
	Net.error_message.connect(func(m: String) -> void: print(who, " ERROR: ", m))
	Net.connection_failed.connect(func(m: String) -> void: print(who, " FAILED: ", m); get_tree().quit(1))
	if who == "join":
		for i in 50:
			if FileAccess.file_exists("/tmp/cc_code.txt"):
				break
			await get_tree().create_timer(0.2).timeout
	Net.connect_to("ws://127.0.0.1:9080")

func _on_connected() -> void:
	print(who, " connected as ", Net.my_id())
	if who == "create":
		Net.create_room("Alice", 7, 0)
	else:
		Net.join_room(FileAccess.get_file_as_string("/tmp/cc_code.txt"), "Bob", 7, 1)

func _on_lobby(st: Dictionary) -> void:
	print(who, " lobby: code ", st["code"], " players ", st["players"].size(), " laps ", st["laps"], " grid ", st["grid"], " racing ", st["racing"])
	if who == "create":
		var f := FileAccess.open("/tmp/cc_code.txt", FileAccess.WRITE)
		f.store_string(st["code"])
		f.close()
		if st["laps"] != 1:
			Net.set_settings(1, "random", OS.get_cmdline_user_args().has("--hardcore"))
			Net.pick_spot(3)
		elif st["players"].size() >= (1 if OS.get_cmdline_user_args().has("--solo") else 2) and not started and not st["racing"]:
			started = true
			Net.start_race()
	elif st["grid"] == "custom" and not started:
		started = true
		Net.pick_spot(3)     # taken by Alice: server should refuse
		Net.pick_spot(6)

func _on_race(cfg: Dictionary) -> void:
	print(who, " race start: ", cfg["laps"], " laps, roster ", cfg["roster"].size(), " cars")
	race = Race.new()
	race.setup({"mode": "client", "laps": cfg["laps"], "roster": cfg["roster"], "local_id": cfg["local_id"]})
	add_child(race)
	Net.race = race
	var spot := race.cars.find(race.player) + 1
	print(who, " I am #", race.player.number, " starting spot ", spot)
	race.race_over.connect(_on_over)

func _physics_process(d: float) -> void:
	if race == null:
		return
	t += d
	if race.player.net_t > 0.0:
		snaps += 1
	if t > next_tap:
		next_tap += 2.0
		race._tap(1 if randf() < 0.5 else -1)
	if t > next_log:
		next_log += 10.0
		print("%s t=%4.1f P%d lap %d  %3d mph  lane %d  draft %.2f push %.2f  flag %d" % [who, t, race.player.place, race.lap_of(maxf(race.player.s, 0)), int(race.player.v * Race.MPH), race.player.lane, race.player.draft_meter, race.player.push_meter, race.flag])

func _on_over() -> void:
	var me := race.finish_order.find(race.player) + 1
	var top := []
	for i in 5:
		var c: Car = race.finish_order[i]
		top.append("%d.#%d %s %.1f" % [i + 1, c.number, c.driver_name, c.finish_time])
	print(who, " RACE OVER: I finished P", me, " of ", race.finish_order.size(), "  top: ", ", ".join(top))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
