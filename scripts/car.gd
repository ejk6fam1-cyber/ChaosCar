class_name Car
extends Node2D
## One stock car. The race (race.gd) owns the physics; a car just holds its state and draws itself.
## Units: metres and metres/second. `s` = distance along the track, `x` = sideways from the centre line.

const LENGTH := 4.8
const WIDTH := 2.3

var number := 0
var color := Color.RED
var trim := Color.WHITE
var is_player := false       # driven by a human (local or online)
var is_local := false        # the human at this computer (gets the marker and the camera)
var peer_id := 0             # online: the network id of the human driving it (0 = computer)
var driver_name := ""
var shift_dir := 0           # human: a lane tap waiting for a gap to open
var shift_wait := 0.0
var blocked_flash := 0.0     # human: HUD flashes when a tap is refused
var net_s := 0.0             # online client: last position/speed the server sent ...
var net_v := 0.0
var net_t := 0.0             # ... and when it arrived
var pred_until := 0.0        # online client: trust my own lane switch until then (hides lag)
var s := 0.0
var x := 0.0
var v := 70.0
var target_x := 0.0
var follow: Car = null       # AI: the car I was drafting just switched lanes - maybe go with it
var since_switch := 9.0      # AI: seconds since its last lane change
var rushed := false          # AI: already reacted to closing on the car ahead
var vx := 0.0                # drawn sideways position: slides to x in about a tenth of a second
var lane_idx := 0            # my index in Race.lane_cars[lane] (front first)
var lane := 0                # lane it is in or moving to (0 = far left)
var from_lane := 0           # lane it came from (it goes back there if the move gets shut)
var carry := 0.0             # draft that lingers for a moment after pulling out (momentum)
var engine := 1.0            # this car's base power (a few % either way)
var form := 0.0              # slow drift in power over the race (a car coming on, or fading)
var form_target := 0.0
var aggression := 0.5        # AI: how keen it is to change lines and block
var think := 0.0             # AI: seconds until it next reconsiders its lane
var draft_eff := 0.0         # draft including the long-line bonus (what actually cuts drag)
var draft := 0.0             # 0..1 drafting the car ahead
var draft_meter := 0.0       # 0..1 how strong the draft is right now (HUD meter)
var push_meter := 0.0        # 0..1 how strong the push is right now (HUD meter)
var push := 0.0              # 0..1 being pushed by the car(s) behind
var line_behind := 0         # cars in the line directly behind
var crew := 0                # AI: how many more cars behind me should jump out with me
var line_pos := 0            # my place in a nose-to-tail line (0 = at the front of it)
var bubble := 0.0            # 0..1 riding inside the pack
var wake := 0.0              # 0..1 in the wake of cars ahead (long range)
var turb := 0.0              # dirty-air wander in drag
var side := 0.0              # 1 = someone alongside my rear quarter (side draft)
var throttle := 1.0          # AI only: lifts off briefly to set up a run (you can't - you only steer)
var lift := 0.0              # seconds left of a lift
var run_gap := 15.0          # gap it wants before getting back on it
var finished := false
var finish_time := 0.0
var place := 0


func _ready() -> void:
	z_index = 5


func _draw() -> void:
	var ppm := Race.PPM
	var w := WIDTH * ppm
	var l := LENGTH * ppm
	var r := Rect2(-w * 0.5, -l * 0.5, w, l)
	# shadow
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0, 0, 0, 0.35))
	# tyres poking out at the corners
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_rect(Rect2(Vector2(corner.x * (w * 0.5 + 0.5) - 1.5, corner.y * l * 0.3 - 3), Vector2(3, 6)), Color(0.06, 0.06, 0.06))
	# body with a tapered nose
	draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(w, l - 3)), color)
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(w - 4, 4)), color)
	# racing stripes
	draw_rect(Rect2(-2, r.position.y, 1.5, l), trim)
	draw_rect(Rect2(0.5, r.position.y, 1.5, l), trim)
	# windscreen, roof with number, rear window, spoiler
	draw_rect(Rect2(r.position.x + 2, r.position.y + l * 0.22, w - 4, l * 0.13), Color(0.12, 0.16, 0.22))
	var roof := Rect2(r.position.x + 2, r.position.y + l * 0.36, w - 4, l * 0.3)
	draw_rect(roof, Color(0.95, 0.95, 0.92))
	var font := ThemeDB.fallback_font
	var txt := str(number)
	var fs := 9
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, roof.get_center() + Vector2(-tw * 0.5, 3.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(r.position.x + 2, r.position.y + l * 0.68, w - 4, l * 0.1), Color(0.12, 0.16, 0.22))
	draw_rect(Rect2(r.position.x, r.end.y - 2.5, w, 2.5), trim.darkened(0.3))
	draw_rect(r, color.darkened(0.55), false, 1.0)
	if is_local:
		# a marker so you can always find yourself
		draw_colored_polygon(PackedVector2Array([Vector2(0, r.end.y + 4), Vector2(-5, r.end.y + 11), Vector2(5, r.end.y + 11)]), Color(1.0, 0.9, 0.2))
