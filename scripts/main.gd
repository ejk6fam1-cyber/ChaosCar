extends Node
## Chaos Car: menus and game flow.
##   Title -> Single player setup -> race
##         -> Online: create a race (get a code), or join one with its code -> lobby -> race
## In single player and the lobby you pick your car number and livery (with a preview).
## Launched with "-- --server" (or CHAOS_SERVER set) it runs as the online server instead: no window,
## no menus, just rooms and races (see net.gd). Port: $PORT, default 9080.

var race: Race
var _ui: CanvasLayer
var _screens := {}
var _status: Label
var _preview: Car              # the car shown on the single player / lobby screens
# single player
var _sp_laps: SpinBox
var _sp_grid: OptionButton
var _sp_spot: SpinBox
var _sp_spot_row: Control
var _sp_num: SpinBox
var _sp_scheme: OptionButton
# online
var _on_name: LineEdit
var _on_server: LineEdit
var _on_code: LineEdit
var _on_create: Button
# lobby
var _lb_title: Label
var _lb_code: Label
var _lb_players: Label
var _lb_num: SpinBox
var _lb_scheme: OptionButton
var _lb_spot: SpinBox
var _lb_spot_desc: Label
var _lb_spot_row: Control
var _lb_host_box: Control
var _lb_laps: SpinBox
var _lb_grid: OptionButton
var _lb_settings_txt: Label
var _lb_start: Button

var _local_cfg := {}
var _pending := ""             # "create" or "join:CODE" waiting for the connection
var _hello_ok := false         # connected, and the server answered
var _connect_t := -1.0         # seconds spent connecting (-1 = not connecting)
var _connect_url := ""
var _wait_t := -1.0            # seconds waiting for the server to answer a request (-1 = not waiting)
var _wait_what := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--server") or OS.has_environment("CHAOS_SERVER"):
		var port := int(OS.get_environment("PORT")) if OS.has_environment("PORT") else 9080
		if Net.start_server(port) != OK:
			push_error("couldn't listen on port %d" % port)
			get_tree().quit(1)
		return
	_build_ui()
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(func(reason: String) -> void:
		_connect_t = -1.0
		_set_status("%s (%s) Check the address and that the Render server is Live." % [reason, _connect_url]))
	Net.disconnected.connect(_on_disconnected)
	Net.lobby_changed.connect(_on_lobby)
	Net.race_started.connect(_on_race_started)
	Net.error_message.connect(func(t: String) -> void:
		_wait_t = -1.0
		_set_status(t))
	Net.server_answered.connect(_on_server_answered)
	_show("title")


# =================================================================== UI building

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(func() -> void: bg.draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(0.08, 0.09, 0.13)))
	_ui.add_child(bg)
	var title := _text(_ui, "CHAOS CAR", 56, Color(1, 0.82, 0.1))
	title.position = Vector2(0, 24)
	title.size = Vector2(960, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	var sub := _text(_ui, "64-car pack racing on a 2.66-mile tri-oval", 15, Color(1, 1, 1, 0.7))
	sub.position = Vector2(0, 92)
	sub.size = Vector2(960, 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status = _text(_ui, "", 15, Color(1, 0.6, 0.5))
	_status.position = Vector2(40, 490)
	_status.size = Vector2(880, 46)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview = Car.new()
	_preview.position = Vector2(860, 300)
	_preview.scale = Vector2(3, 3)
	_preview.visible = false
	_ui.add_child(_preview)

	# --- title
	var t := _screen("title")
	_btn(t, "Single Player", func() -> void: _show("single"))
	_btn(t, "Online Race", _open_online)
	if OS.get_name() != "Web":
		_btn(t, "Quit", func() -> void: get_tree().quit())

	# --- single player
	var s := _screen("single")
	var r1 := _row(s, "Laps")
	_sp_laps = _spin(r1, 1, 20, Race.DEFAULT_LAPS)
	_sp_grid = _grid_option(r1)
	_sp_spot_row = _row(s, "Your spot (1 = pole)")
	_sp_spot = _spin(_sp_spot_row, 1, Race.FIELD, Race.DEFAULT_SPOT)
	var sp_desc := _text(_sp_spot_row, _spot_text(Race.DEFAULT_SPOT), 14, Color(1, 1, 1, 0.7))
	_sp_spot.value_changed.connect(func(v: float) -> void: sp_desc.text = _spot_text(int(v)))
	_sp_grid.item_selected.connect(func(_i: int) -> void: _sp_spot_row.visible = _sp_grid.selected == 1)
	_sp_spot_row.visible = false
	var r2 := _row(s, "Your car  #")
	_sp_num = _spin(r2, 1, 99, Net.load_setting("number", 7))
	_sp_scheme = _scheme_option(r2)
	_sp_scheme.selected = Net.load_setting("scheme", 0)
	_sp_num.value_changed.connect(func(_v: float) -> void: _car_changed(_sp_num, _sp_scheme, false))
	_sp_scheme.item_selected.connect(func(_i: int) -> void: _car_changed(_sp_num, _sp_scheme, false))
	var b1 := _hrow(s)
	_btn(b1, "Start Race", _start_single)
	_btn(b1, "Back", func() -> void: _show("title"))

	# --- online: your name, the server, create a race, or join one with its code (all centred)
	var o := _screen("online")
	_on_name = _edit(_crow(o, "Your name"), Net.load_setting("name", ""), "Driver name", 14)
	var sr := _crow(o, "Server")
	_on_server = _edit(sr, Net.default_server(), "wss://your-server.onrender.com", 64)
	_on_server.custom_minimum_size.x = 280
	var rc := Button.new()
	rc.text = "Connect"
	rc.custom_minimum_size = Vector2(90, 32)
	rc.pressed.connect(func() -> void:
		Net.disconnect_from()
		_hello_ok = false
		_connect())
	sr.add_child(rc)
	_on_create = _btn(o, "Create a Race", func() -> void: _request("create"))
	var jr := _crow(o, "Race code")
	_on_code = _edit(jr, "", "ABCD", 4)
	_on_code.custom_minimum_size.x = 90
	var jb := Button.new()
	jb.text = "Join"
	jb.custom_minimum_size = Vector2(90, 32)
	jb.pressed.connect(func() -> void:
		var code := _on_code.text.strip_edges().to_upper()
		if code.length() != 4:
			_set_status("Race codes are 4 letters.")
			return
		_request("join:" + code))
	jr.add_child(jb)
	_btn(o, "Back", func() -> void:
		Net.disconnect_from()
		_hello_ok = false
		_show("title"))

	# --- lobby
	var l := _screen("lobby")
	_lb_title = _text(l, "", 24, Color(1, 0.82, 0.1))
	_lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_code = _text(l, "", 15, Color(1, 1, 1, 0.75))
	_lb_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_players = _text(l, "", 15, Color.WHITE)
	_lb_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_players.custom_minimum_size = Vector2(0, 84)
	var cr := _row(l, "Your car  #")
	_lb_num = _spin(cr, 1, 99, 7)
	_lb_scheme = _scheme_option(cr)
	_lb_num.value_changed.connect(func(_v: float) -> void: _car_changed(_lb_num, _lb_scheme, true))
	_lb_scheme.item_selected.connect(func(_i: int) -> void: _car_changed(_lb_num, _lb_scheme, true))
	_lb_spot_row = _row(l, "Your spot (1 = pole)")
	_lb_spot = _spin(_lb_spot_row, 1, Race.FIELD, Race.DEFAULT_SPOT)
	_lb_spot_desc = _text(_lb_spot_row, "", 14, Color(1, 1, 1, 0.7))
	_lb_spot.value_changed.connect(func(v: float) -> void:
		_lb_spot_desc.text = _spot_text(int(v))
		Net.pick_spot(int(v)))
	_lb_host_box = _row(l, "Laps")
	_lb_laps = _spin(_lb_host_box, 1, 20, Race.DEFAULT_LAPS)
	_lb_grid = _grid_option(_lb_host_box)
	_lb_laps.value_changed.connect(func(_v: float) -> void: Net.set_settings(int(_lb_laps.value), _grid_key(_lb_grid)))
	_lb_grid.item_selected.connect(func(_i: int) -> void: Net.set_settings(int(_lb_laps.value), _grid_key(_lb_grid)))
	_lb_settings_txt = _text(l, "", 16, Color(1, 1, 1, 0.85))
	_lb_settings_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b2 := _hrow(l)
	_lb_start = _btn(b2, "Start Race", func() -> void: Net.start_race())
	_btn(b2, "Leave", func() -> void:
		Net.leave_room()
		_open_online())


func _screen(key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(140, 128)
	box.size = Vector2(680, 356)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.visible = false
	_ui.add_child(box)
	_screens[key] = box
	return box


func _show(key: String) -> void:
	for k in _screens:
		_screens[k].visible = k == key
	_ui.visible = true
	_set_status("")
	_preview.visible = key == "single" or key == "lobby"
	if key == "single":
		_car_changed(_sp_num, _sp_scheme, false)


func _set_status(t: String) -> void:
	_status.text = t


func _text(parent: Node, txt: String, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	parent.add_child(l)
	return l


func _btn(parent: Node, txt: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(220, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A form row: a fixed-width, right-aligned label column, then the controls starting at the same x on
## every row - so all the labels and boxes line up, and the form sits in the middle of the screen.
const LABEL_W := 230.0
const FORM_W := 640.0


func _row(parent: Node, label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_BEGIN
	r.add_theme_constant_override("separation", 10)
	r.custom_minimum_size.x = FORM_W
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(r)
	var l := _text(r, label, 17, Color.WHITE)
	l.custom_minimum_size.x = LABEL_W
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return r


## A centred row: label and controls together in the middle of the screen.
func _crow(parent: Node, label: String) -> HBoxContainer:
	var r := _hrow(parent)
	_text(r, label, 17, Color.WHITE)
	return r


func _hrow(parent: Node) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 10)
	parent.add_child(r)
	return r


func _spin(parent: Node, lo: int, hi: int, v: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.value = v
	sb.custom_minimum_size = Vector2(84, 32)
	parent.add_child(sb)
	return sb


func _edit(parent: Node, v: String, placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = v
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(200, 32)
	parent.add_child(e)
	return e


func _grid_option(parent: Node) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_item("Random spots")
	ob.add_item("Pick your spot")
	ob.custom_minimum_size = Vector2(170, 32)
	parent.add_child(ob)
	return ob


## Livery picker: each entry has a little swatch of its body and trim colours.
func _scheme_option(parent: Node) -> OptionButton:
	var ob := OptionButton.new()
	for sc: Array in Race.SCHEMES:
		var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
		img.fill(sc[1])
		img.fill_rect(Rect2i(6, 0, 4, 16), sc[2])
		ob.add_icon_item(ImageTexture.create_from_image(img), sc[0])
	ob.custom_minimum_size = Vector2(170, 32)
	parent.add_child(ob)
	return ob


func _grid_key(ob: OptionButton) -> String:
	return "custom" if ob.selected == 1 else "random"


func _spot_text(spot: int) -> String:
	return "row %d, %s" % [(spot - 1) / 2 + 1, "inside" if spot % 2 == 1 else "outside"]


## Number or livery changed: update the preview, remember it, and tell the lobby.
func _car_changed(num: SpinBox, scheme: OptionButton, online: bool) -> void:
	var sc: Array = Race.SCHEMES[clampi(scheme.selected, 0, Race.SCHEMES.size() - 1)]
	_preview.number = int(num.value)
	_preview.color = sc[1]
	_preview.trim = sc[2]
	_preview.queue_redraw()
	Net.save_setting("number", int(num.value))
	Net.save_setting("scheme", scheme.selected)
	if online:
		Net.set_car(int(num.value), scheme.selected)


# =================================================================== single player

func _start_single() -> void:
	_local_cfg = {"mode": "local", "laps": int(_sp_laps.value), "grid": _grid_key(_sp_grid),
		"humans": [{"id": 1, "name": "You", "spot": int(_sp_spot.value), "number": int(_sp_num.value),
			"scheme": _sp_scheme.selected}], "local_id": 1}
	_launch(_local_cfg)


func _launch(cfg: Dictionary) -> void:
	_end_race()
	race = Race.new()
	race.setup(cfg)
	add_child(race)
	race.hud.menu_pressed.connect(_back_to_menu)
	race.hud.again_pressed.connect(_again)
	_ui.visible = false
	if cfg["mode"] == "client":
		Net.race = race


func _end_race() -> void:
	if race and is_instance_valid(race):
		race.queue_free()
	race = null
	Net.race = null


func _back_to_menu() -> void:
	var online := race != null and race.mode == "client"
	_end_race()
	if online:
		Net.leave_room()
		Net.disconnect_from()
		_hello_ok = false
	_show("title")


func _again() -> void:
	if race and race.mode == "client":
		_end_race()
		_show("lobby")
		if not Net.room_state.is_empty():
			_on_lobby(Net.room_state)
	else:
		_launch(_local_cfg)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and race != null:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_back_to_menu()
		elif (event as InputEventKey).keycode == KEY_R and race.mode == "local":
			_launch(_local_cfg)


# =================================================================== online

## The online screen: connects straight away and lists the open races.
func _open_online() -> void:
	_show("online")
	if not (_hello_ok and Net.is_online()):
		_connect()


func _connect() -> void:
	var url := _on_server.text.strip_edges()
	if url == "":
		_set_status("Enter the server address.")
		return
	Net.save_setting("server", url)
	_connect_url = Net.normalize_url(url)
	_on_server.text = _connect_url
	_hello_ok = false
	if Net.connect_to(url) != OK:
		_set_status("That server address doesn't look right: %s" % _connect_url)
		return
	_connect_t = 0.0


## Create a race, or join one ("join:CODE"). Waits for the connection if it isn't up yet.
func _request(what: String) -> void:
	Net.save_setting("name", _on_name.text)
	_pending = what
	if _hello_ok and Net.is_online():
		_send_pending()
	elif _connect_t < 0.0:
		_connect()


func _send_pending() -> void:
	if _pending == "":
		return
	_wait_what = "create" if _pending == "create" else "join"
	_wait_t = 0.0
	var num := int(Net.load_setting("number", 7))
	var sch := int(Net.load_setting("scheme", 0))
	if _pending == "create":
		_set_status("Creating your race...")
		Net.create_room(_on_name.text, num, sch)
	else:
		_set_status("Joining...")
		Net.join_room(_pending.substr(5), _on_name.text, num, sch)


func _process(delta: float) -> void:
	if _wait_t >= 0.0:
		_wait_t += delta
		if _wait_t > 6.0 and _wait_t - delta <= 6.0:
			if _wait_what == "hello":
				Net.hello()
			else:
				_send_pending()
				_wait_t = 6.01
			_set_status("Still waiting for the server to answer (%s, asked twice)..." % _wait_what)
		elif _wait_t > 15.0:
			_wait_t = -1.0
			_set_status("Connected to %s, but the server isn't answering '%s' requests. Tell Claude this message." % [_connect_url, _wait_what])
	if _connect_t < 0.0:
		return
	_connect_t += delta
	var st := Net.connection_status()
	if st == MultiplayerPeer.CONNECTION_CONNECTED or st == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_connect_t = -1.0
		return
	if _connect_t > 90.0:
		_connect_t = -1.0
		Net.disconnect_from()
		_set_status("No answer from %s. Check the address (it should start with wss://) and that the Render server is Live." % _connect_url)
	else:
		_set_status("Connecting to %s ... %ds  (a sleeping free server takes about a minute to wake up)" % [_connect_url, int(_connect_t)])


func _on_connected() -> void:
	_connect_t = -1.0
	_set_status("Connected - checking the server answers...")
	_wait_what = "hello"
	_wait_t = 0.0
	Net.hello()


func _on_server_answered(server_protocol: int) -> void:
	if _wait_what == "hello":
		_wait_t = -1.0
	if server_protocol != Net.PROTOCOL:
		_set_status("The server is running a different version (%d, this page is %d). Refresh the page in a few minutes - the server may still be updating." % [server_protocol, Net.PROTOCOL])
		return
	_hello_ok = true
	_set_status("Connected - create a race, or type a race code and Join.")
	_send_pending()


func _on_disconnected() -> void:
	_hello_ok = false
	_end_race()
	_show("online")
	_set_status("Lost the connection to the server.")


func _on_lobby(st: Dictionary) -> void:
	_wait_t = -1.0
	_pending = ""
	if race != null:
		return              # racing: the lobby screen comes back after
	if not _screens["lobby"].visible:
		_show("lobby")
		_set_status("")
	var me := Net.my_id()
	var host: bool = st["host"] == me
	var host_name := "?"
	var lines := []
	for p in st["players"]:
		if p["id"] == st["host"]:
			host_name = p["name"]
		var spot_txt := "spot %d" % p["spot"] if st["grid"] == "custom" else "random spot"
		var sc: Array = Race.SCHEMES[clampi(int(p["scheme"]), 0, Race.SCHEMES.size() - 1)]
		lines.append("#%d  %s%s   -   %s, %s%s" % [p["number"], p["name"], "  (you)" if p["id"] == me else "",
			sc[0], spot_txt, "   [host]" if p["id"] == st["host"] else ""])
	_lb_title.text = "RACE CODE:  %s" % st["code"]
	_lb_code.text = "%s's race  -  %d/%d players.  Give the code to the other drivers." % [host_name, st["players"].size(), Net.MAX_PLAYERS]
	_lb_players.text = "\n".join(lines)
	_lb_host_box.visible = host
	_lb_laps.set_value_no_signal(st["laps"])
	_lb_grid.selected = 1 if st["grid"] == "custom" else 0
	_lb_settings_txt.visible = not host
	_lb_settings_txt.text = "%d laps   -   %s" % [st["laps"], "pick your spot" if st["grid"] == "custom" else "random starting spots"]
	_lb_spot_row.visible = st["grid"] == "custom"
	for p in st["players"]:
		if p["id"] == me:
			_lb_spot.set_value_no_signal(p["spot"])
			_lb_spot_desc.text = _spot_text(int(p["spot"]))
			_lb_num.set_value_no_signal(p["number"])
			_lb_scheme.selected = int(p["scheme"])
	_car_changed_preview_only()
	_lb_start.visible = host
	_lb_start.disabled = st["racing"]
	_lb_start.text = "Race in progress..." if st["racing"] else "Start Race"


func _car_changed_preview_only() -> void:
	var sc: Array = Race.SCHEMES[clampi(_lb_scheme.selected, 0, Race.SCHEMES.size() - 1)]
	_preview.number = int(_lb_num.value)
	_preview.color = sc[1]
	_preview.trim = sc[2]
	_preview.queue_redraw()


func _on_race_started(cfg: Dictionary) -> void:
	_launch({"mode": "client", "laps": cfg["laps"], "roster": cfg["roster"], "local_id": cfg["local_id"]})
