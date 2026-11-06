extends Node
## Chaos Car: menus and game flow.
##   Title -> Single player setup -> race
##         -> Online: create a race (get a code) or join one with a code -> lobby -> race
## Launched with "-- --server" (or CHAOS_SERVER set) it runs as the online server instead: no window,
## no menus, just rooms and races (see net.gd). Port: $PORT, default 9080.

var race: Race
var _ui: CanvasLayer
var _screens := {}
var _status: Label
var _sp_laps: SpinBox
var _sp_grid: OptionButton
var _sp_spot: SpinBox
var _sp_spot_row: Control
var _on_name: LineEdit
var _on_server: LineEdit
var _on_code: LineEdit
var _lb_code: Label
var _lb_players: Label
var _lb_laps: SpinBox
var _lb_grid: OptionButton
var _lb_settings_txt: Label
var _lb_spot: SpinBox
var _lb_spot_row: Control
var _lb_start: Button
var _lb_host_box: Control
var _pending := ""            # "create" or "join" while connecting
var _local_cfg := {}


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
	Net.connection_failed.connect(func(reason: String) -> void: _set_status(reason + " Check the server address."))
	Net.disconnected.connect(_on_disconnected)
	Net.lobby_changed.connect(_on_lobby)
	Net.race_started.connect(_on_race_started)
	Net.error_message.connect(func(t: String) -> void: _set_status(t))
	_show("title")


# =================================================================== UI building

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.draw.connect(_draw_bg.bind(bg))
	bg.name = "Bg"
	_ui.add_child(bg)
	var title := _text(_ui, "CHAOS CAR", 64, Color(1, 0.82, 0.1))
	title.position = Vector2(0, 30)
	title.size = Vector2(960, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 12)
	var sub := _text(_ui, "64-car pack racing on a 2.66-mile tri-oval", 16, Color(1, 1, 1, 0.75))
	sub.position = Vector2(0, 108)
	sub.size = Vector2(960, 24)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status = _text(_ui, "", 16, Color(1, 0.55, 0.45))
	_status.position = Vector2(0, 494)
	_status.size = Vector2(960, 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- title
	var t := _screen("title")
	_btn(t, "Single Player", func() -> void: _show("single"))
	_btn(t, "Online Race", func() -> void: _show("online"))
	if OS.get_name() != "Web":
		_btn(t, "Quit", func() -> void: get_tree().quit())

	# --- single player setup
	var s := _screen("single")
	_sp_laps = _spin(_row(s, "Laps"), 1, 20, Race.DEFAULT_LAPS)
	_sp_grid = _grid_option(_row(s, "Starting grid"))
	_sp_spot_row = _row(s, "Your spot (1 = pole)")
	_sp_spot = _spin(_sp_spot_row, 1, Race.FIELD, Race.DEFAULT_SPOT)
	var sp_desc := _text(_sp_spot_row, _spot_text(Race.DEFAULT_SPOT), 14, Color(1, 1, 1, 0.7))
	_sp_spot.value_changed.connect(func(v: float) -> void: sp_desc.text = _spot_text(int(v)))
	_sp_grid.item_selected.connect(func(_i: int) -> void: _sp_spot_row.visible = _sp_grid.selected == 1)
	_sp_spot_row.visible = false
	_btn(s, "Start Race", _start_single)
	_btn(s, "Back", func() -> void: _show("title"))

	# --- online: create / join
	var o := _screen("online")
	_on_name = _edit(_row(o, "Your name"), Net.load_setting("name", ""), "Driver name", 14)
	_on_server = _edit(_row(o, "Server"), Net.default_server(), "wss://your-server.onrender.com", 64)
	_on_server.custom_minimum_size.x = 330
	_btn(o, "Create a Race", func() -> void: _go_online("create"))
	var jr := _row(o, "Race code")
	_on_code = _edit(jr, "", "ABCD", 4)
	_on_code.custom_minimum_size.x = 90
	var jb := Button.new()
	jb.text = "Join"
	jb.custom_minimum_size = Vector2(90, 34)
	jb.add_theme_font_size_override("font_size", 18)
	jb.pressed.connect(func() -> void: _go_online("join"))
	jr.add_child(jb)
	_btn(o, "Back", func() -> void:
		Net.disconnect_from()
		_show("title"))

	# --- lobby
	var l := _screen("lobby")
	_lb_code = _text(l, "", 30, Color(1, 0.82, 0.1))
	_lb_code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _text(l, "Give this code to the other drivers. Up to 4 players; the computer drives the rest.", 13, Color(1, 1, 1, 0.65))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_players = _text(l, "", 16, Color.WHITE)
	_lb_players.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_host_box = VBoxContainer.new()
	l.add_child(_lb_host_box)
	_lb_laps = _spin(_row(_lb_host_box, "Laps"), 1, 20, Race.DEFAULT_LAPS)
	_lb_grid = _grid_option(_row(_lb_host_box, "Starting grid"))
	_lb_laps.value_changed.connect(func(_v: float) -> void: Net.set_settings(int(_lb_laps.value), _grid_key(_lb_grid)))
	_lb_grid.item_selected.connect(func(_i: int) -> void: Net.set_settings(int(_lb_laps.value), _grid_key(_lb_grid)))
	_lb_settings_txt = _text(l, "", 16, Color(1, 1, 1, 0.85))
	_lb_settings_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lb_spot_row = _row(l, "Your spot (1 = pole)")
	_lb_spot = _spin(_lb_spot_row, 1, Race.FIELD, Race.DEFAULT_SPOT)
	var lb_desc := _text(_lb_spot_row, "", 14, Color(1, 1, 1, 0.7))
	_lb_spot.value_changed.connect(func(v: float) -> void:
		lb_desc.text = _spot_text(int(v))
		Net.pick_spot(int(v)))
	_lb_start = _btn(l, "Start Race", func() -> void: Net.start_race())
	_btn(l, "Leave", func() -> void:
		Net.leave_room()
		Net.disconnect_from()
		_show("online"))


func _screen(key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.position = Vector2(230, 150)
	box.size = Vector2(500, 330)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.visible = false
	_ui.add_child(box)
	_screens[key] = box
	return box


func _show(key: String) -> void:
	for k in _screens:
		_screens[k].visible = k == key
	_ui.visible = true
	_set_status("")


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
	b.custom_minimum_size = Vector2(260, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _row(parent: Node, label: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 12)
	var l := _text(r, label, 18, Color.WHITE)
	l.custom_minimum_size.x = 170
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(r)
	return r


func _spin(parent: Node, lo: int, hi: int, v: int) -> SpinBox:
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.value = v
	sb.custom_minimum_size = Vector2(90, 34)
	parent.add_child(sb)
	return sb


func _edit(parent: Node, v: String, placeholder: String, max_len: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = v
	e.placeholder_text = placeholder
	e.max_length = max_len
	e.custom_minimum_size = Vector2(200, 34)
	parent.add_child(e)
	return e


func _grid_option(parent: Node) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_item("Random spots")
	ob.add_item("Pick your spot")
	ob.custom_minimum_size = Vector2(180, 34)
	parent.add_child(ob)
	return ob


func _grid_key(ob: OptionButton) -> String:
	return "custom" if ob.selected == 1 else "random"


func _spot_text(spot: int) -> String:
	return "row %d, %s" % [(spot - 1) / 2 + 1, "inside" if spot % 2 == 1 else "outside"]


func _draw_bg(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(0.07, 0.08, 0.12))
	# a sweep of banked asphalt with lane lines
	for i in 7:
		var y := 300.0 + i * 26.0
		c.draw_rect(Rect2(0, y, 960, 25), Color(0.16, 0.16, 0.19) if i % 2 == 0 else Color(0.18, 0.18, 0.21))
	c.draw_rect(Rect2(0, 296, 960, 4), Color(0.95, 0.8, 0.15))
	c.draw_rect(Rect2(0, 482, 960, 6), Color(0.9, 0.9, 0.88))
	# checkered band under the title
	for i in 80:
		for r in 2:
			c.draw_rect(Rect2(i * 12, 136 + r * 6, 12, 6), Color.WHITE if (i + r) % 2 == 0 else Color(0.05, 0.05, 0.05))


# =================================================================== single player

func _start_single() -> void:
	_local_cfg = {"mode": "local", "laps": int(_sp_laps.value), "grid": _grid_key(_sp_grid),
		"humans": [{"id": 1, "name": "You", "spot": int(_sp_spot.value)}], "local_id": 1}
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

func _go_online(what: String) -> void:
	var url := _on_server.text.strip_edges()
	if url == "":
		_set_status("Enter the server address.")
		return
	if what == "join" and _on_code.text.strip_edges().length() != 4:
		_set_status("Race codes are 4 letters.")
		return
	Net.save_setting("name", _on_name.text)
	Net.save_setting("server", url)
	_pending = what
	if Net.is_online():
		_on_connected()
		return
	_set_status("Connecting... (a sleeping free server can take about a minute to wake up)")
	if Net.connect_to(url) != OK:
		_set_status("That server address doesn't look right.")


func _on_connected() -> void:
	_set_status("")
	if _pending == "create":
		Net.create_room(_on_name.text)
	elif _pending == "join":
		Net.join_room(_on_code.text, _on_name.text)
	_pending = ""


func _on_disconnected() -> void:
	_end_race()
	_show("online")
	_set_status("Lost the connection to the server.")


func _on_lobby(st: Dictionary) -> void:
	if race != null:
		return              # racing: the lobby screen comes back after
	if not _screens["lobby"].visible:
		_show("lobby")
	var me := Net.my_id()
	var host: bool = st["host"] == me
	_lb_code.text = "RACE CODE:  %s" % st["code"]
	var lines := []
	for p in st["players"]:
		var spot_txt := "spot %d" % p["spot"] if st["grid"] == "custom" else "random spot"
		lines.append("%s%s  -  %s%s" % [p["name"], "  (you)" if p["id"] == me else "", spot_txt, "   [host]" if p["id"] == st["host"] else ""])
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
	_lb_start.visible = host
	_lb_start.disabled = st["racing"]
	_lb_start.text = "Race in progress..." if st["racing"] else "Start Race"


func _on_race_started(cfg: Dictionary) -> void:
	_launch({"mode": "client", "laps": cfg["laps"], "roster": cfg["roster"], "local_id": cfg["local_id"]})
