class_name Oval
extends RefCounted
## Talladega-shaped tri-oval (2.66 miles): a 4,000 ft back stretch, two big 155-degree ends (turns 1-2 and
## 3-4), and a front stretch made of two angled chutes joined by the 50-degree tri-oval curve in front of the
## grandstands. Like the real track, the start/finish line is on the chute between the tri-oval and turn 1,
## not at the apex. Cars race counter-clockwise on screen (they turn left).
##
## The race itself is simulated as distance `s` along the centre line plus a sideways offset `x` (lanes);
## this just maps (s, x) onto the oval. Screen layout: back stretch along the top, tri-oval at the bottom.

const BACK := 1219.0         # metres: back stretch (4,000 ft)
const TURN_R := 278.117      # metres: radius of turns 1-2 and 3-4 (solved so the lap closes at 2.66 mi)
const TURN_DEG := 155.0      # each end sweeps 155 degrees
const TRI_R := 800.0         # metres: radius of the tri-oval curve
const TRI_DEG := 50.0        # ... which turns the remaining 50 degrees
const CHUTE := 429.555       # metres: each front-stretch chute
const LINE_AT := 0.55        # start/finish line: this far along the chute from the tri-oval to turn 1
const STEP := 1.0            # metres between stored centre-line points

static var length := 0.0
static var front_behind := 0.0   # front stretch (grandstands) runs from this far before the line ...
static var front_ahead := 0.0    # ... to this far after it
static var bounds := Rect2()
static var _pts := PackedVector2Array()     # evenly spaced centre-line points, starting at the line
static var _dirs := PackedVector2Array()    # unit direction of travel at each point


static func build() -> void:
	if not _pts.is_empty():
		return
	# dense raw outline, starting at the tri-oval apex heading right (on screen, y down: a left turn
	# makes the heading angle go down)
	var raw := PackedVector2Array()
	var pos := Vector2.ZERO
	var ang := 0.0
	var pieces := [
		[TRI_R, deg_to_rad(TRI_DEG * 0.5)], [0.0, CHUTE], [TURN_R, deg_to_rad(TURN_DEG)], [0.0, BACK],
		[TURN_R, deg_to_rad(TURN_DEG)], [0.0, CHUTE], [TRI_R, deg_to_rad(TRI_DEG * 0.5)]]
	raw.append(pos)
	for pc in pieces:
		var r: float = pc[0]
		if r == 0.0:       # straight
			var n := int(pc[1])
			for i in n:
				pos += Vector2.from_angle(ang) * (float(pc[1]) / n)
				raw.append(pos)
		else:              # left-hand arc
			var da: float = pc[1]
			var n := int(r * da)
			for i in n:
				var mid := ang - da / n * 0.5
				pos += Vector2.from_angle(mid) * (r * da / n)
				ang -= da / n
				raw.append(pos)
	raw.remove_at(raw.size() - 1)     # last point == first (the loop closes)
	# cumulative length
	var cum := PackedFloat32Array()
	cum.resize(raw.size() + 1)
	cum[0] = 0.0
	for i in raw.size():
		cum[i + 1] = cum[i] + raw[i].distance_to(raw[(i + 1) % raw.size()])
	var total := cum[raw.size()]
	var count := int(floor(total / STEP))
	length = count * STEP
	# s = 0 is the start/finish line
	var line := TRI_R * deg_to_rad(TRI_DEG * 0.5) + CHUTE * LINE_AT
	front_behind = line + CHUTE + TRI_R * deg_to_rad(TRI_DEG * 0.5)
	front_ahead = CHUTE * (1.0 - LINE_AT) + 40.0
	var j := 0
	var raw_pts := PackedVector2Array()
	for k in count:
		var target := fposmod(line + k * STEP, total)
		if k > 0 and target < STEP:
			j = 0
		while cum[j + 1] < target:
			j += 1
		var t := (target - cum[j]) / maxf(cum[j + 1] - cum[j], 0.0001)
		raw_pts.append(raw[j].lerp(raw[(j + 1) % raw.size()], t))
	# centre the whole oval on the origin
	bounds = Rect2(raw_pts[0], Vector2.ZERO)
	for v in raw_pts:
		bounds = bounds.expand(v)
	var c := bounds.get_center()
	for v in raw_pts:
		_pts.append(v - c)
	bounds.position -= c
	for k in count:
		_dirs.append((_pts[(k + 1) % count] - _pts[(k - 1 + count) % count]).normalized())


## Centre-line point and direction of travel at distance s (any s, it wraps every lap).
static func _sample(s: float) -> Array:
	var u := fposmod(s, length) / STEP
	var i := int(u)
	var t := u - i
	var n := _pts.size()
	var p := _pts[i % n].lerp(_pts[(i + 1) % n], t)
	var d := _dirs[i % n].lerp(_dirs[(i + 1) % n], t).normalized()
	return [p, d]


## World position (metres) of distance s, x metres to the right of the centre line (right = outside).
static func point(s: float, x: float) -> Vector2:
	var pd := _sample(s)
	var d: Vector2 = pd[1]
	return (pd[0] as Vector2) + Vector2(-d.y, d.x) * x


## Heading angle (radians) of travel at s.
static func heading(s: float) -> float:
	var d: Vector2 = _sample(s)[1]
	return d.angle()


## Whole lap outline at offset x (for the track map).
static func outline(x: float, every := 20.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := 0.0
	while s < length:
		out.append(point(s, x))
		s += every
	out.append(point(0.0, x))
	return out
