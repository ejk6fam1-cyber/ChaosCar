class_name TrackView
extends Node2D
## Draws the part of the tri-oval around you: mown grass, the apron with its yellow lines, seven lanes of
## asphalt, the outside SAFER wall with sponsor boards, the catch fence, packed grandstands along the front
## stretch and tri-oval, and the start/finish line.

var race: Race
var _crowd: ImageTexture
var _asphalt: ImageTexture
const APRON := 10.0      # metres
const WALL := 1.2
const BEHIND := 150.0    # metres of track drawn behind you ...
const AHEAD := 200.0     # ... and ahead
const SEG := 2.0         # metres per drawn segment


func _ready() -> void:
	z_index = 0
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.26, 0.27, 0.3))
	for y in range(0, 64, 8):
		for x in 64:
			img.set_pixel(x, y + 6, Color(0.19, 0.2, 0.23))        # step edge
			img.set_pixel(x, y + 7, Color(0.19, 0.2, 0.23))
		for x in range(1, 61, 5):
			if rng.randf() < 0.75:
				var shirt := Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.55), rng.randf_range(0.45, 0.75))
				var skin := Color(0.78, 0.62, 0.48).darkened(rng.randf_range(0.0, 0.45))
				for dx in 2:
					img.set_pixel(x + dx + 1, y + 1, skin)            # head
					img.set_pixel(x + dx + 1, y + 2, skin)
				for dx in 4:
					img.set_pixel(x + dx, y + 3, shirt)               # shoulders
					img.set_pixel(x + dx, y + 4, shirt)
	_crowd = ImageTexture.create_from_image(img)
	var a := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var k := rng.randf_range(-0.025, 0.025)
			a.set_pixel(x, y, Color(0.2 + k, 0.2 + k, 0.22 + k))
	_asphalt = ImageTexture.create_from_image(a)


func _process(_delta: float) -> void:
	queue_redraw()


## Screen point (pixels) of distance s, x metres right of the centre line.
func _p(s: float, x: float) -> Vector2:
	return Oval.point(s, x) * Race.PPM


## A strip of track between x0 and x1 (metres from the centre line), from s0 to s1.
func _band(s0: float, s1: float, x0: float, x1: float, col: Color, tex: Texture2D = null, tex_px := 64.0) -> void:
	var s := s0
	while s < s1:
		var e := minf(s + SEG, s1)
		if e - s < 0.2:          # a sliver too thin to draw (would fail to triangulate)
			break
		var q := PackedVector2Array([_p(s, x0), _p(e, x0), _p(e, x1), _p(s, x1)])
		if tex:
			var uv := PackedVector2Array()
			for v in q:
				uv.append(v / tex_px)
			draw_polygon(q, PackedColorArray([col, col, col, col]), uv, tex)
		else:
			draw_colored_polygon(q, col)
		s = e


func _line(s0: float, s1: float, x: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var s := s0
	while s <= s1:
		pts.append(_p(s, x))
		s += SEG
	draw_polyline(pts, col, width)


func _draw() -> void:
	if race.player == null:
		return
	var ppm := Race.PPM
	var cam := race.camera.position
	var ps := race.player.s
	var s0 := ps - BEHIND
	var s1 := ps + AHEAD
	var hw := Race.half_width()
	# grass everywhere, with mowing stripes
	var view := Rect2(cam - Vector2(560, 340), Vector2(1120, 680))
	draw_rect(view, Color(0.2, 0.42, 0.18))
	var band := 90.0
	var y := floorf(view.position.y / band) * band
	while y < view.end.y:
		if int(floorf(y / band)) % 2 == 0:
			draw_rect(Rect2(view.position.x, y, view.size.x, band), Color(0.23, 0.47, 0.2))
		y += band
	# grandstands along the front stretch (outside), parking/grass elsewhere
	var lap0 := floorf(ps / Race.LAP) * Race.LAP
	for k: float in [-1.0, 0.0, 1.0]:
		var line := lap0 + k * Race.LAP
		var a := maxf(s0, line - Oval.front_behind)
		var b := minf(s1, line + Oval.front_ahead)
		if a < b:
			_band(a, b, hw + WALL + 2.2, hw + WALL + 4.0, Color(0.4, 0.4, 0.44))
			_band(a, b, hw + WALL + 4.0, hw + 60.0, Color.WHITE, _crowd)
	# apron and its yellow lines
	_band(s0, s1, -hw - APRON, -hw, Color(0.36, 0.37, 0.4))
	_line(s0, s1, -hw - 0.25, Color(0.95, 0.8, 0.15), 3.0)
	_line(s0, s1, -hw - 1.1, Color(0.95, 0.8, 0.15), 2.0)
	# the racing surface
	_band(s0, s1, -hw, hw, Color.WHITE, _asphalt)
	# faint dashed lane seams
	for i in range(1, Race.LANES):
		var lx := -hw + i * Race.LANE_W
		var s := floorf(s0 / 10.0) * 10.0
		while s < s1:
			draw_line(_p(s, lx), _p(s + 4.0, lx), Color(1, 1, 1, 0.07), 1.0)
			s += 10.0
	# outside SAFER wall and catch fence
	_band(s0, s1, hw, hw + WALL, Color(0.92, 0.92, 0.9))
	_band(s0, s1, hw + WALL, hw + WALL + 1.7, Color(0.3, 0.3, 0.33))
	var fs := floorf(s0)
	while fs < s1:
		draw_line(_p(fs, hw + WALL), _p(fs + 1.0, hw + WALL + 1.7), Color(0.5, 0.5, 0.55), 1.0)
		fs += 1.0
	# sponsor boards on the wall, every 60 m
	var font := ThemeDB.fallback_font
	var names := ["DRAFT DAY", "SPEEDWAY", "FULL THROTTLE", "BUMP & RUN", "SUPER 500", "PIT LANE"]
	var bs := floorf(s0 / 60.0) * 60.0
	while bs < s1:
		var idx := absi(int(fposmod(bs, Race.LAP) / 60.0))
		_band(bs - 4.0, bs + 4.0, hw + 0.1, hw + WALL - 0.1, Color.from_hsv(fmod(idx * 0.17, 1.0), 0.7, 0.75))
		var t: String = names[idx % names.size()]
		draw_set_transform(_p(bs, hw + WALL * 0.5), Oval.heading(bs), Vector2.ONE)
		var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		draw_string(font, Vector2(-w * 0.5, 2.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		bs += 60.0
	# start/finish line (crossed every lap)
	for k: float in [0.0, 1.0]:
		var ls := lap0 + k * Race.LAP
		if ls < s0 or ls > s1:
			continue
		draw_set_transform(_p(ls, 0.0), Oval.heading(ls), Vector2.ONE)
		var sq := 1.0 * ppm
		var across := int(hw * 2.0 * ppm / sq)
		for i in across:
			for r in 2:
				var c := Color.WHITE if (i + r) % 2 == 0 else Color(0.05, 0.05, 0.05)
				draw_rect(Rect2(r * sq - sq, -hw * ppm + i * sq, sq, sq), c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
