class_name RaceHud
extends CanvasLayer
## Race screen: position, lap, speed, gap to the leader (car lengths), DRAFT/PUSH lights, the track map,
## a radar of the cars around you, flags, and the full finishing order with buttons at the end.

signal menu_pressed
signal again_pressed       # single player: race again / online: back to the lobby

var race: Race
var _info: Label
var _flag: Label
var _lights: Control
var _radar: Control
var _map: Control
var _map_pts := PackedVector2Array()
var _standings: Control
var _board: Control
var _again: Button
const RADAR := Rect2(780, 20, 160, 470)
const RADAR_RANGE := 220.0     # metres ahead/behind shown on the radar
const INFO := Rect2(12, 12, 270, 114)
const METERS := Rect2(12, 136, 270, 74)
const MAP := Rect2(12, 220, 270, 150)


func _ready() -> void:
	_panel(INFO)
	_info = _label(INFO.position + Vector2(12, 6), 16, Color.WHITE)
	_info.size = INFO.size - Vector2(24, 12)
	_info.clip_text = true
	_flag = _label(Vector2(300, 14), 26, Color.WHITE)
	_flag.size = Vector2(360, 34)
	_flag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel(METERS)
	_lights = _canvas(METERS, _draw_meters)
	_panel(MAP)
	_map = _canvas(MAP, _draw_map)
	_panel(RADAR.grow(6))
	_radar = _canvas(RADAR, _draw_radar)
	var help := _label(Vector2(12, 512), 15, Color(1, 1, 1, 0.75))
	help.text = "A / D  or  Left / Right : switch lane (tap)"

	# finishing order (hidden until you finish)
	_standings = Control.new()
	_standings.visible = false
	_standings.position = Vector2(100, 22)
	_standings.size = Vector2(760, 496)
	add_child(_standings)
	var bg := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.03, 0.06, 0.93)
	sb.set_corner_radius_all(8)
	sb.border_color = Color(1, 0.8, 0.2, 0.6)
	sb.set_border_width_all(2)
	bg.add_theme_stylebox_override("panel", sb)
	bg.size = _standings.size
	_standings.add_child(bg)
	_board = Control.new()
	_board.size = _standings.size
	_board.draw.connect(_draw_board)
	_standings.add_child(_board)
	var menu := _button("Return to menu", Vector2(420, 450))
	menu.pressed.connect(func() -> void: menu_pressed.emit())
	_again = _button("Race again" if race.mode == "local" else "Back to lobby", Vector2(170, 450))
	_again.pressed.connect(func() -> void: again_pressed.emit())


func _button(text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(170, 34)
	b.add_theme_font_size_override("font_size", 16)
	_standings.add_child(b)
	return b


func _canvas(r: Rect2, cb: Callable) -> Control:
	var c := Control.new()
	c.position = r.position
	c.size = r.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(cb)
	add_child(c)
	return c


func _panel(r: Rect2) -> void:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.07, 0.78)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)


func _label(pos: Vector2, sz: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(_delta: float) -> void:
	if race == null or race.player == null or race.order.is_empty():
		return
	var p := race.player
	var leader := race.order[0]
	var gap := "Leading!" if leader == p else "Gap: %.1f car lengths" % ((leader.s - p.s) / Car.LENGTH)
	_info.text = "P%d / %d\nLap %d / %d\n%d MPH\n%s" % [p.place, race.cars.size(), race.lap_of(maxf(p.s, 0.0)), race.laps, int(p.v * Race.MPH), gap]
	match race.flag:
		Race.Flag.PACE:
			_flag.text = "PACE LAP - GREEN IN %d" % int(ceil(Race.PACE_TIME - race.clock))
			_flag.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
		Race.Flag.GREEN:
			_flag.text = "GREEN FLAG" if race.clock < Race.PACE_TIME + 3.0 else ""
			_flag.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		Race.Flag.WHITE:
			_flag.text = "WHITE FLAG - LAST LAP"
			_flag.add_theme_color_override("font_color", Color.WHITE)
		Race.Flag.CHECKERED:
			_flag.text = "CHECKERED FLAG"
			_flag.add_theme_color_override("font_color", Color.WHITE)
	_lights.queue_redraw()
	_radar.queue_redraw()
	_map.queue_redraw()
	if (p.finished or race.done) and not _standings.visible:
		_standings.visible = true
	if _standings.visible:
		_flag.text = ""
		_again.disabled = race.mode == "client" and not race.done
		_board.queue_redraw()


## DRAFT and PUSH meters: how strong each force is right now, red (none) through yellow to green (full).
func _draw_meters() -> void:
	var font := ThemeDB.fallback_font
	var p := race.player
	var items := [["DRAFT", p.draft_meter], ["PUSH", p.push_meter]]
	var segs := 14
	for i in items.size():
		var y := 12.0 + i * 31.0
		var v: float = items[i][1]
		_lights.draw_string(font, Vector2(10, y + 15), items[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
		var bar := Rect2(70, y, 150, 20)
		_lights.draw_rect(bar.grow(2), Color(0, 0, 0, 0.6))
		var w := bar.size.x / segs
		var lit := int(round(v * segs))
		for k in segs:
			var t := float(k) / (segs - 1)
			var col := Color(0.9, 0.15, 0.1).lerp(Color(0.95, 0.85, 0.1), t * 2.0) if t < 0.5 \
				else Color(0.95, 0.85, 0.1).lerp(Color(0.15, 0.9, 0.25), (t - 0.5) * 2.0)
			if k >= lit:
				col = col.darkened(0.8)
			_lights.draw_rect(Rect2(bar.position.x + k * w + 1, bar.position.y + 1, w - 2, bar.size.y - 2), col)
		_lights.draw_string(font, Vector2(228, y + 15), "%d%%" % int(round(v * 100.0)), HORIZONTAL_ALIGNMENT_LEFT, 38, 14, Color(1, 1, 1, 0.85))


## Full finishing order: two columns of 32, humans in their colours, times or gaps.
func _draw_board() -> void:
	var font := ThemeDB.fallback_font
	var me := race.finish_order.find(race.player) + 1
	var title := "FINISHED  P%d" % me if me > 0 else "RESULTS"
	_board.draw_string(font, Vector2(20, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.85, 0.2))
	if not race.done:
		_board.draw_string(font, Vector2(300, 34), "cars still finishing...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	var win_t := race.finish_order[0].finish_time if not race.finish_order.is_empty() else 0.0
	var rows := 32
	for i in race.cars.size():
		var col := i / rows
		var row := i % rows
		var pos := Vector2(20 + col * 370, 62 + row * 12)
		var txt_col := Color(1, 1, 1, 0.35)
		var line := "%2d." % (i + 1)
		if i < race.finish_order.size():
			var c: Car = race.finish_order[i]
			var t := ""
			if c.finish_time < 0.0:
				t = "running"
			elif i == 0:
				t = "%d:%04.1f" % [int(c.finish_time) / 60, fmod(c.finish_time, 60.0)]
			else:
				t = "+%.3f" % (c.finish_time - win_t)
			txt_col = c.color.lightened(0.3) if c.is_player else Color(0.9, 0.9, 0.9)
			if c == race.player:
				_board.draw_rect(Rect2(pos + Vector2(-6, -10), Vector2(350, 12)), Color(1, 1, 1, 0.12))
			_board.draw_string(font, pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
			_board.draw_string(font, pos + Vector2(28, 0), "#%d" % c.number, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
			_board.draw_string(font, pos + Vector2(66, 0), c.driver_name.left(20), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
			_board.draw_string(font, pos + Vector2(270, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)
		else:
			_board.draw_string(font, pos, line + "  ...", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, txt_col)


func _draw_radar() -> void:
	var r := Rect2(Vector2.ZERO, RADAR.size)
	_radar.draw_rect(r, Color(0.08, 0.1, 0.09))
	var font := ThemeDB.fallback_font
	_radar.draw_string(font, Vector2(6, 14), "PACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
	var p := race.player
	var hw := Race.half_width()
	var track := Rect2(r.size.x * 0.5 - 56, 20, 112, r.size.y - 26)
	_radar.draw_rect(track, Color(0.18, 0.18, 0.2))
	for i in range(1, Race.LANES):
		var lx := track.position.x + track.size.x * i / Race.LANES
		_radar.draw_line(Vector2(lx, track.position.y), Vector2(lx, track.end.y), Color(1, 1, 1, 0.08), 1.0)
	var cy := track.position.y + track.size.y * 0.6
	var scale := (track.size.y * 0.5) / RADAR_RANGE
	for c in race.cars:
		if c == p:
			continue
		var py := cy - (c.s - p.s) * scale
		if py < track.position.y or py > track.end.y:
			continue
		var px := track.position.x + (c.x + hw) / (hw * 2.0) * track.size.x
		_radar.draw_rect(Rect2(px - 2.5, py - 4, 5, 8), c.color.darkened(0.15))
		if c.is_player:       # another human: outlined
			_radar.draw_rect(Rect2(px - 3.5, py - 5, 7, 10), Color.WHITE, false, 1.0)
	# you: drawn last, bigger, outlined
	var ppx := track.position.x + (p.x + hw) / (hw * 2.0) * track.size.x
	_radar.draw_rect(Rect2(ppx - 4.5, cy - 6.5, 9, 13), Color(1, 0.2, 0.15) if p.blocked_flash > 0.0 else Color.WHITE)
	_radar.draw_rect(Rect2(ppx - 3.5, cy - 5.5, 7, 11), p.color)
	_radar.draw_string(font, Vector2(2, cy + 4), "YOU", HORIZONTAL_ALIGNMENT_LEFT, 22, 10, p.color)
	# leader arrow if the front of the pack is off the radar
	var lead := race.order[0]
	if (lead.s - p.s) * scale > cy - track.position.y:
		_radar.draw_string(font, Vector2(track.position.x, track.position.y + 12), "^ leader %d lengths" % int((lead.s - p.s) / Car.LENGTH), HORIZONTAL_ALIGNMENT_LEFT, track.size.x, 11, Color(1, 1, 1, 0.8))


## The whole tri-oval with every car on it.
func _map_xf() -> Transform2D:
	var half := Oval.bounds.size * 0.5 + Vector2(20.0, 20.0)
	var sc := minf((MAP.size.x - 16.0) / (half.x * 2.0), (MAP.size.y - 30.0) / (half.y * 2.0))
	return Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2(MAP.size.x * 0.5, 20.0 + (MAP.size.y - 20.0) * 0.5))


func _draw_map() -> void:
	var font := ThemeDB.fallback_font
	_map.draw_string(font, Vector2(8, 14), "TRACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
	var xf := _map_xf()
	if _map_pts.is_empty():
		_map_pts = xf * Oval.outline(0.0, 25.0)
	_map.draw_polyline(_map_pts, Color(0.32, 0.32, 0.36), 7.0)
	var f0 := xf * Oval.point(0.0, -Race.half_width())
	var f1 := xf * Oval.point(0.0, Race.half_width())
	_map.draw_line(f0 + (f0 - f1).normalized() * 3.0, f1 + (f1 - f0).normalized() * 3.0, Color.WHITE, 2.0)
	for c in race.cars:
		if c == race.player:
			continue
		if c.is_player:
			var hp := xf * Oval.point(c.s, c.x)
			_map.draw_circle(hp, 4.0, Color.BLACK)
			_map.draw_circle(hp, 3.0, c.color)
		else:
			_map.draw_rect(Rect2(xf * Oval.point(c.s, c.x) - Vector2(1.5, 1.5), Vector2(3, 3)), c.color)
	var me := xf * Oval.point(race.player.s, race.player.x)
	_map.draw_circle(me, 5.0, Color.WHITE)
	_map.draw_circle(me, 3.8, race.player.color)
