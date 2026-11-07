class_name Race
extends Node2D
## Chaos Car: 64 stock cars pack racing on a Talladega-shaped tri-oval. Humans only switch between the
## 7 lanes (tap left/right, only into an open lane). Speed comes from the air and the bumpers:
##  - drafting: tuck in behind a car (lined up with it) and your drag drops; a long line ahead tows harder;
##  - pushing: only a car literally on your bumper pushes you, and every car touching nose to tail
##    behind you adds more;
##  - the pack bubble and the wake keep the field together;
##  - collisions conserve momentum: hit the car ahead and it takes your speed.
##
## Three modes (config.mode):
##  - "local":  single player - simulates everything, draws it, reads your keys;
##  - "server": online host - simulates everything, draws nothing (see net.gd);
##  - "client": online player - simulates nothing, draws the server's snapshots, sends your taps.

const PPM := 6.0                 # pixels per metre
const LANES := 7
const LANE_W := 3.7              # metres
const DEFAULT_LAPS := 5          # laps of the 2.66-mile tri-oval: about 4 minutes
static var LAP := 4281.0         # metres per lap (set from the oval's real length)
static var TRACK_LENGTH := 21405.0   # race distance of the race on screen (set per race)
const FIELD := 64
const DEFAULT_SPOT := 36         # single player default starting spot (row 18, outside)
const HUMAN_NUMBERS := [7, 11, 22, 88]     # defaults for players who don't pick
## Liveries players can choose: name, body colour, trim (stripes and spoiler).
const SCHEMES := [
	["Sunburst", Color(1.0, 0.82, 0.1), Color(0.08, 0.08, 0.1)],
	["Ice", Color(0.2, 0.85, 1.0), Color(0.05, 0.12, 0.35)],
	["Bubblegum", Color(1.0, 0.35, 0.7), Color(1.0, 1.0, 1.0)],
	["Blaze", Color(1.0, 0.5, 0.1), Color(0.08, 0.08, 0.1)],
	["Racing Red", Color(0.85, 0.1, 0.1), Color(1.0, 1.0, 1.0)],
	["Lime", Color(0.55, 0.95, 0.2), Color(0.08, 0.08, 0.1)],
	["Royal", Color(0.15, 0.3, 0.9), Color(1.0, 0.85, 0.15)],
	["Midnight", Color(0.12, 0.12, 0.16), Color(1.0, 0.5, 0.1)],
	["Ghost", Color(0.93, 0.93, 0.96), Color(0.85, 0.1, 0.1)],
	["Grape", Color(0.55, 0.2, 0.85), Color(0.6, 1.0, 0.25)],
	["Gold Rush", Color(0.85, 0.65, 0.2), Color(0.08, 0.08, 0.1)],
	["Mint", Color(0.4, 0.92, 0.72), Color(0.05, 0.3, 0.2)],
]
const AI_NAMES := ["Hollis", "Barrett", "Dunn", "Okafor", "Varga", "Lindqvist", "Pruitt", "Tanaka", "Moreau",
	"Castellanos", "Whitlock", "Gruber", "Abernathy", "Kowalski", "Rinaldi", "Fairbanks", "Delacroix",
	"Haverford", "Nakamura", "Oduya", "Petrov", "Sorensen", "McAllister", "Quinlan", "Ashby", "Brannigan",
	"Calloway", "Dempsey", "Escobar", "Fenwick", "Galloway", "Hargrove", "Ingram", "Jablonski", "Kessler",
	"Lockhart", "Mancini", "Norwood", "Ostrander", "Pembroke", "Ramsey", "Sutter", "Thibodeaux", "Underhill",
	"Vance", "Wexler", "Yates", "Zimmer", "Alder", "Bishop", "Crane", "Driscoll", "Ellery", "Fontaine",
	"Gentry", "Holloway", "Ivers", "Jarrett", "Keel", "Lyle", "Mercer", "Nash", "Orr", "Pike", "Royce"]
const PACE_SPEED := 70.0         # m/s (157 mph) behind the pace car
const PACE_TIME := 4.0           # seconds of rolling start before the green flag
const SOLO_TOP := 76.0           # m/s (170 mph) a car alone in clean air can reach
const ENGINE := 4.0              # m/s^2 of thrust at full throttle
const DRAFT_MAX := 0.22          # drag cut from drafting right on someone's bumper
const DRAFT_RANGE := 30.0        # metres: how quickly the draft fades with the gap (the tow reaches far)
const PUSH_MAX := 0.05          # drag cut from a car right behind you
const PUSH_RANGE := 4.0
const LINE_BONUS := 0.0          # extra push per extra car in the line behind (up to LINE_CAP)
const LINE_CAP := 12
const PUSH_LINE := 0.018         # drag cut for EVERY car in a line, per car pushing from behind it (up to LINE_CAP)
const LINE_TOUCH := 0.5          # metres: push only counts from a car actually on your bumper
const TOW_REACH := 0.1           # ... and reaches this much further back per car
const DRAFT_CAP := 3.0           # (draft_eff limit)
const DRAFT_LINE := 0.15         # the draft gets this much stronger per car in the line you're drafting (up to 12)
const BIG_LINE := 7              # a line this long that's running away makes the cars at the back jump out
const CARRY_FADE := 1.6          # per second: how fast the draft's tow fades after you pull out
const BUBBLE_MAX := 0.07         # drag cut from riding inside the pack's bubble of slow air
const BUBBLE_RANGE := 120.0      # metres ahead the pack's pull reaches (fading with distance)
const BUBBLE_CARS := 5.0         # weighted cars ahead (any lane) for the full bubble
const WAKE_MAX := 0.08           # drag cut for a whole group that has fallen behind the group ahead
const WAKE_RANGE := 900.0        # metres: past this the group ahead is too far gone to tow you
const STRAGGLER_FROM := 300.0    # metres behind the leader where the straggler tow starts ...
const STRAGGLER_FULL := 1300.0   # ... and where it's at full strength
const STRAGGLER_MAX := 0.2       # full-strength drag cut: a lone car out there runs about pack speed, so
								 # stragglers settle about a kilometre back - never lapped, never catching up
const GROUP_GAP := 15.0          # metres: cars closer than this (any lane) count as one group
const LATERAL := 40.0            # m/s the car is DRAWN sliding across (a switch looks like ~0.1 s)
const ROOM_PLAYER := 0.4         # metres of clear space you need nose and tail to switch into a lane
const ROOM_AI_AHEAD := 1.0       # the computer drivers leave a little more
const ROOM_AI_BEHIND := 2.0
const AI_COOLDOWN := 4.0          # seconds an AI car stays put after switching (unless following its line)
const SHIFT_WAIT := 0.35         # a blocked tap waits this long for the gap to open
const LOOK := 0.35               # s: a lane switch must still fit this long after, at the cars' speeds
const CLIENT_LOOK := 0.6         # s: online, your screen only shows a switch at once if it fits this long
const RESTITUTION := 0.25        # bounce in a hit (0 = they stick together, 1 = billiard balls)
const SIDE_DRAFT := 0.06         # extra drag on a car whose rear quarter has someone alongside (they steal its air)
const TURBULENCE := 0.008        # dirty air: each car's drag wanders by up to this much (makes lines surge)
const DEEP_FROM := 4              # cars further back than this in a nose-to-tail line ...
const DEEP_DRAG := 0.0            # ... get this much extra drag per place (dirty, buffeting air)
const ENGINE_SPREAD := 0.07       # base power varies +-7% car to car (you get exactly average)
const FORM_SPREAD := 0.06         # each car's power also drifts +-6% over the race (a car coming on, or fading)
const FORM_TIME := 15.0           # seconds: how slowly that drift moves
const MPH := 2.23694

enum Flag { PACE, GREEN, WHITE, CHECKERED }

var config := {}                    # see setup(); empty = single player with defaults
var mode := "local"
var laps := DEFAULT_LAPS
var race_length := 21405.0          # metres: laps * LAP
var cars: Array[Car] = []
var player: Car                     # the car this computer follows (null on the server)
var humans := {}                    # peer id -> Car (online)
var done := false                   # every car home (or long enough after the winner)
var roster: Array = []              # per grid spot: number, colours, name, peer (sent to online players)
var _net_clock := 0.0               # client: local clock (for lane-switch prediction)
var _snaps: Array = []              # client: recent server snapshots, [server clock, data]
var _rt := -1.0                     # client: the server time being shown (a little behind the newest)
const NET_DELAY := 0.15             # client: show the race this far behind the newest snapshot, so there
									# is always a later one to blend toward (smooth despite uneven arrival)
signal race_over
var flag := Flag.PACE
var clock := 0.0
var finish_order: Array[Car] = []
var order: Array[Car] = []          # sorted by distance, leader first
var lane_cars: Array = []           # per lane: its cars, front first (built in _sort, kept up to date by _go)
var camera: Camera2D
var track_view: TrackView
var hud: RaceHud
var stats := {}                     # test: lane changes by reason
var autopilot := false              # tests: the player car drives like the AI
var rng := RandomNumberGenerator.new()
var _drag := SOLO_TOP              # (set in _ready) drag coefficient: ENGINE / SOLO_TOP^2


## Configure before adding to the tree:
##   mode: "local" | "server" | "client"
##   laps: int
##   grid: "random" | "custom"
##   humans: [{id, name, spot}]   spot 1..64 (1 = pole); with "random" grid the spots are drawn at random
##   local_id: which human is at this computer (local/client)
##   seed: int (server/local)
##   roster: (client) the server's roster, so the cars look the same everywhere
func setup(cfg: Dictionary) -> void:
	config = cfg


func _ready() -> void:
	Oval.build()
	LAP = Oval.length
	if config.is_empty():
		config = {"mode": "local", "laps": DEFAULT_LAPS, "grid": "custom",
			"humans": [{"id": 1, "name": "You", "spot": DEFAULT_SPOT}], "local_id": 1}
	mode = config.get("mode", "local")
	laps = clampi(int(config.get("laps", DEFAULT_LAPS)), 1, 50)
	race_length = LAP * laps
	if mode != "server":
		TRACK_LENGTH = race_length
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	_drag = ENGINE / (SOLO_TOP * SOLO_TOP)
	if mode != "server":
		track_view = TrackView.new()
		track_view.race = self
		add_child(track_view)
		camera = Camera2D.new()
		camera.position_smoothing_enabled = false
		add_child(camera)
		camera.make_current()
		hud = RaceHud.new()
		hud.race = self
		add_child(hud)
	start()


## Build the field: 64 cars double file behind the line. Spot 1 is pole (inside, front row).
func start() -> void:
	for c in cars:
		c.queue_free()
	cars.clear()
	humans.clear()
	finish_order.clear()
	flag = Flag.PACE
	clock = 0.0
	done = false
	if mode == "client":
		roster = config.get("roster", [])
	else:
		roster = _make_roster()
	for i in roster.size():
		var r: Dictionary = roster[i]
		var c := Car.new()
		c.number = int(r["number"])
		c.color = Color.html(r["color"])
		c.trim = Color.html(r["trim"])
		c.driver_name = r["name"]
		c.peer_id = int(r["peer"])
		c.is_player = c.peer_id != 0
		c.is_local = c.is_player and c.peer_id == int(config.get("local_id", -1))
		c.engine = float(r.get("engine", 1.0))
		c.form = 0.0
		c.form_target = rng.randf_range(-FORM_SPREAD, FORM_SPREAD)
		c.aggression = float(r.get("aggression", 0.5))
		c.think = rng.randf_range(0.5, 3.0)
		var row := i / 2
		c.lane = LANES / 2 - 1 + i % 2     # double file just left of centre: odd spots inside
		c.from_lane = c.lane
		c.x = lane_x(c.lane)
		c.target_x = c.x
		c.vx = c.x
		c.s = -15.0 - float(row) * 9.0      # lined up behind the start/finish line
		c.v = PACE_SPEED
		c.net_s = c.s
		c.net_v = c.v
		add_child(c)
		cars.append(c)
		if c.is_player:
			humans[c.peer_id] = c
		if c.is_local:
			player = c
	_sort()


## Who starts where, and what every car looks like (made by the server / single player).
func _make_roster() -> Array:
	var spots := {}            # grid index (0 = pole) -> human dict
	var hs: Array = config.get("humans", [])
	var free: Array[int] = []
	for k in FIELD:
		free.append(k)
	if config.get("grid", "random") == "custom":
		for h in hs:
			var want := clampi(int(h.get("spot", DEFAULT_SPOT)) - 1, 0, FIELD - 1)
			# taken? the nearest free spot behind it, then ahead
			var k := want
			var step := 0
			while spots.has(k):
				step += 1
				k = want + step if want + step < FIELD else want - step
				if step > FIELD * 2:
					break
			spots[k] = h
			free.erase(k)
	else:
		for h in hs:
			var k: int = free[rng.randi_range(0, free.size() - 1)]
			spots[k] = h
			free.erase(k)
	var taken: Array[int] = []          # the players' numbers: the computer cars get the others
	for h in hs:
		taken.append(int(h.get("number", 0)))
	for n in HUMAN_NUMBERS:
		taken.append(n)
	var numbers: Array[int] = []
	for n in range(1, 100):
		if not taken.has(n):
			numbers.append(n)
	for i in range(numbers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := numbers[i]
		numbers[i] = numbers[j]
		numbers[j] = t
	var names: Array = AI_NAMES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: String = names[i]
		names[i] = names[j]
		names[j] = t
	var out: Array = []
	var human_i := 0
	for k in FIELD:
		var h := rng.randf()
		var col := Color.from_hsv(h, rng.randf_range(0.55, 0.9), rng.randf_range(0.6, 0.95))
		var trim := Color.from_hsv(fmod(h + 0.5, 1.0), 0.3, 1.0) if rng.randf() < 0.5 else Color(0.1, 0.1, 0.1)
		var r := {"number": numbers[k], "color": col.to_html(false), "trim": trim.to_html(false),
			"name": "%s. %s" % [char(65 + rng.randi_range(0, 25)), names[k % names.size()]], "peer": 0,
			"engine": 1.0 + rng.randf_range(-ENGINE_SPREAD, ENGINE_SPREAD), "aggression": rng.randf_range(0.2, 0.95)}
		if spots.has(k):
			var hd: Dictionary = spots[k]
			var num := int(hd.get("number", 0))
			r["number"] = num if num >= 1 and num <= 99 else HUMAN_NUMBERS[human_i % HUMAN_NUMBERS.size()]
			var sc: Array = SCHEMES[clampi(int(hd.get("scheme", human_i)), 0, SCHEMES.size() - 1)]
			r["color"] = (sc[1] as Color).to_html(false)
			r["trim"] = (sc[2] as Color).to_html(false)
			r["name"] = str(hd.get("name", "Player"))
			r["peer"] = int(hd.get("id", 1))
			r["engine"] = 1.0
			human_i += 1
		out.append(r)
	return out


## The roster as sent to online players (looks only).
func public_roster() -> Array:
	var out: Array = []
	for r in roster:
		out.append({"number": r["number"], "color": r["color"], "trim": r["trim"], "name": r["name"], "peer": r["peer"]})
	return out


## Which lap a car at distance s is on (1..laps).
func lap_of(s: float) -> int:
	return clampi(floori(s / LAP) + 1, 1, laps)


static func lane_x(lane: int) -> float:
	return (float(lane) - (LANES - 1) * 0.5) * LANE_W


static func half_width() -> float:
	return LANES * LANE_W * 0.5


# ------------------------------------------------------------------ simulation

func _physics_process(delta: float) -> void:
	if mode == "client":
		_net_clock += delta
		_follow_server(delta)
	else:
		var steps := 2
		var dt := delta / steps
		for i in steps:
			_step(dt)
	if mode == "server":
		return
	for c in cars:
		c.vx = move_toward(c.vx, c.x, LATERAL * delta)
		c.position = Oval.point(c.s, c.vx) * PPM
		c.rotation = Oval.heading(c.s) + PI * 0.5      # cars are drawn nose-up
	# camera on you, looking a little up the track
	if player == null:
		return
	camera.position = (Oval.point(player.s, 0.0) + Vector2.from_angle(Oval.heading(player.s)) * 22.0) * PPM


func _step(dt: float) -> void:
	clock += dt
	if flag == Flag.PACE and clock >= PACE_TIME:
		flag = Flag.GREEN
	_sort()
	_aero()
	for c in cars:
		c.carry = maxf(c.draft_eff, c.carry - CARRY_FADE * dt)
		c.draft_meter = draft_strength(c)
		c.push_meter = push_strength(c)
		# dirty air: a slow random wander in each car's drag
		c.turb = clampf(c.turb * (1.0 - 0.3 * dt) + rng.randf_range(-1.0, 1.0) * TURBULENCE * sqrt(dt), -TURBULENCE, TURBULENCE)
		if flag == Flag.PACE:
			c.v = PACE_SPEED
		else:
			var mult := aero_mult(c)
			# slow drift in power: every so often a car picks a new 'form' and eases toward it
			if rng.randf() < dt / FORM_TIME:
				c.form_target = rng.randf_range(-FORM_SPREAD, FORM_SPREAD)
			c.form = move_toward(c.form, c.form_target, dt * FORM_SPREAD / 8.0)
			var thrust := ENGINE * c.engine * (1.0 + c.form) * c.throttle if not c.finished else 0.0
			var drag := _drag * mult * c.v * c.v + (0.0 if not c.finished else 2.0)
			c.v = maxf(c.v + (thrust - drag) * dt, 0.0)
		c.s += c.v * dt
	_steer(dt)
	_runs(dt)
	_bumps(dt)
	_finishes()


func _sort() -> void:
	order = cars.duplicate()
	order.sort_custom(func(a: Car, b: Car) -> bool: return a.s > b.s)
	lane_cars.resize(LANES)
	for k in LANES:
		lane_cars[k] = []
	for i in order.size():
		var c := order[i]
		c.place = i + 1
		var lst: Array = lane_cars[c.lane]
		c.lane_idx = lst.size()
		lst.append(c)


## Move a car between lane lists (keeps them sorted, front first).
func _relane(c: Car, old_lane: int, new_lane: int) -> void:
	var a: Array = lane_cars[old_lane]
	a.erase(c)
	for k in a.size():
		a[k].lane_idx = k
	var b: Array = lane_cars[new_lane]
	var at := b.size()
	for k in b.size():
		if b[k].s < c.s:
			at = k
			break
	b.insert(at, c)
	for k in b.size():
		b[k].lane_idx = k


## Drag multiplier from drafting, being pushed and the pack bubble (1 = alone in clean air).
static func aero_mult(c: Car) -> float:
	return (1.0 - DRAFT_MAX * maxf(c.draft_eff, c.carry)) \
		* (1.0 - PUSH_MAX * c.push) \
		* (1.0 - PUSH_LINE * minf(c.line_behind, LINE_CAP)) \
		* (1.0 - BUBBLE_MAX * c.bubble) \
		* (1.0 - WAKE_MAX * c.wake) \
		* (1.0 - STRAGGLER_MAX * c.assist) \
		* (1.0 + c.turb) \
		* (1.0 + SIDE_DRAFT * c.side) \
		* (1.0 + DEEP_DRAG * clampf(c.line_pos - DEEP_FROM, 0, 10))


## HUD meters, 0..1. Draft: the tow you're getting (a long line ahead pulls hardest).
static func draft_strength(c: Car) -> float:
	return clampf(maxf(c.draft_eff, c.carry) / 2.0, 0.0, 1.0)


## Push: the drag cut from cars nose-to-tail on your bumper (full at about 8 cars).
static func push_strength(c: Car) -> float:
	var cut := 1.0 - (1.0 - PUSH_MAX * c.push) * (1.0 - PUSH_LINE * minf(c.line_behind, LINE_CAP))
	return clampf(cut / 0.2, 0.0, 1.0)


## Lined-up fraction of two cars side by side (1 = directly in line, 0 = a full car width apart).
static func overlap(a: Car, b: Car) -> float:
	return clampf(1.0 - absf(a.x - b.x) / (Car.WIDTH * 1.15), 0.0, 1.0)


func _aero() -> void:
	# wake: a group that has dropped behind the group ahead gets towed back up - all of it together
	var group_wake := 0.0
	for i in order.size():
		var c := order[i]
		if i > 0 and order[i - 1].s - c.s > GROUP_GAP:
			var g := order[i - 1].s - c.s
			group_wake = clampf(g / 80.0, 0.0, 1.0) * exp(-maxf(g - 300.0, 0.0) / WAKE_RANGE)
		c.wake = group_wake
		c.assist = clampf((order[0].s - c.s - STRAGGLER_FROM) / (STRAGGLER_FULL - STRAGGLER_FROM), 0.0, 1.0)
	# pack bubble: weighted count of cars ahead (any lane) within BUBBLE_RANGE, as a sliding window
	var w_start := 0
	var w_sum := 0.0          # sum of s over the window (cars ahead of i within range)
	for i in order.size():
		var c := order[i]
		while w_start < i and order[w_start].s - c.s > BUBBLE_RANGE:
			w_sum -= order[w_start].s
			w_start += 1
		var cnt := i - w_start
		# sum over the window of (1 - (s_j - s_c) / range)
		c.bubble = minf((cnt - (w_sum - cnt * c.s) / BUBBLE_RANGE) / BUBBLE_CARS, 1.0) if cnt > 0 else 0.0
		w_sum += c.s
	var side_ptr: Array[int] = []       # per lane: first car (front first) that is behind the current car
	side_ptr.resize(LANES)
	side_ptr.fill(0)
	for i in order.size():
		var c := order[i]
		var lst: Array = lane_cars[c.lane]
		var li := c.lane_idx
		c.draft = 0.0
		c.push = 0.0
		c.line_behind = 0
		# draft: the car ahead in my lane pulling hardest, plus a little from a second one further up
		var first := 0.0
		var second := 0.0
		var bonus := 1.0
		for j in range(li - 1, -1, -1):
			var a: Car = lst[j]
			var gap := a.s - c.s - Car.LENGTH
			if gap > DRAFT_RANGE * 5.0:
				break
			# nothing further up can pull harder than the two we already have: stop looking
			if second > 0.0 and exp(-maxf(gap, 0.0) / (DRAFT_RANGE * (1.0 + TOW_REACH * 12.0))) <= second:
				break
			# a long line punches a bigger, longer hole in the air: chasing one from behind (not
			# already on its bumper) the tow reaches further and pulls harder - enough to catch it
			var n := float(mini(a.line_pos + 1, 12))
			var chasing := gap > LINE_TOUCH
			var f := exp(-maxf(gap, 0.0) / (DRAFT_RANGE * (1.0 + (TOW_REACH * n if chasing else 0.0))))
			if f > first:
				second = first
				first = f
				bonus = 1.0 + DRAFT_LINE * n if chasing else 1.0
			elif f > second:
				second = f
		c.draft = minf(first + second * 0.25, 1.0)
		c.draft_eff = minf(c.draft * bonus, DRAFT_CAP)
		# place in a nose-to-tail line
		c.line_pos = 0
		if li > 0:
			var a: Car = lst[li - 1]
			if a.s - c.s <= Car.LENGTH + 8.0 and a.s - c.s - Car.LENGTH < 6.0:
				c.line_pos = a.line_pos + 1
		# side draft: someone alongside my rear quarter (in the next lane) steals my air
		c.side = 0.0
		for dl in [-1, 1]:
			var ln: int = c.lane + dl
			if ln < 0 or ln >= LANES:
				continue
			var lc: Array = lane_cars[ln]
			while side_ptr[ln] < lc.size() and lc[side_ptr[ln]].s >= c.s:
				side_ptr[ln] += 1
			for k in range(side_ptr[ln], lc.size()):
				var back: float = c.s - lc[k].s
				if back > Car.LENGTH:
					break
				if back > Car.LENGTH * 0.15:
					c.side = 1.0
					break
			if c.side > 0.0:
				break
		# push: cars nose-to-tail on my bumper, and how long that chain is
		var last := c
		for j in range(li + 1, lst.size()):
			var b: Car = lst[j]
			if c.s - b.s > 100.0 or last.s - b.s - Car.LENGTH >= LINE_TOUCH:
				break
			if last == c:
				c.push = 1.0
			c.line_behind += 1
			last = b


## Lane changes: the player's keys, or the AI's choice. Never slide into a car alongside.
func _steer(dt: float) -> void:
	# humans' taps: switch as soon as there's room (a tap waits a moment for a gap to open)
	for h: Car in humans.values():
		h.blocked_flash = maxf(h.blocked_flash - dt, 0.0)
		if h.shift_dir != 0:
			h.shift_wait -= dt
			if _go(h, h.lane + h.shift_dir):
				h.shift_dir = 0
			elif h.shift_wait <= 0.0:
				h.shift_dir = 0
				h.blocked_flash = 0.4
	if flag == Flag.PACE:
		return
	for c in cars:
		if c.finished or (c.is_player and not autopilot):
			continue
		c.think -= dt
		c.since_switch += dt
		if c.since_switch > 1.5:
			c.crew = 0
		var ah := _car_ahead(c, 14.0)
		if ah and c.v > ah.v + 1.5:
			if not c.rushed and c.think > 0.25:
				c.think = 0.0       # closing fast: decide now (once per approach)
			c.rushed = true
		else:
			c.rushed = false
		if c.think <= 0.0:
			_ai_choose(c)


## Computer driver: pick the lane whose line will carry it fastest; block runs from behind.
func _ai_choose(c: Car) -> void:
	c.think = rng.randf_range(1.5, 3.5)
	var cur := c.lane
	# in a bumper-to-bumper train (touching the car ahead or behind): very reluctant to leave it
	var tail := _car_ahead_of(c)
	var nose := _car_ahead(c, 3.0)
	var train := (nose != null or (tail != null and c.s - tail.s - Car.LENGTH < 3.0)) and c.line_pos <= DEEP_FROM + 2
	var keen := 0.25 if train else 1.0
	# the car I'm drafting is moving over: go with it and keep the tow (that's how lines move)
	var f := c.follow
	c.follow = null
	if f and f.lane != c.lane and f.s - c.s < 24.0 and rng.randf() < (0.95 if f.crew > 0 else (0.35 + c.aggression * 0.3) * (0.7 if train else 1.0)):
		c.crew = maxi(f.crew - 1, 0)      # part of a group jumping out together: pass the word back
		if _go(c, f.lane, "crew" if f.crew > 0 else "follow", true):
			c.think = rng.randf_range(1.2, 2.0)
			return
	# dropped off the pack: desperate to team up with anyone to draft with
	if c.assist > 0.0 and c.draft < 0.3 and not c.finished:
		if _regroup(c):
			return
	var lone := c.draft < 0.2 and not train
	if lone:
		c.think = rng.randf_range(0.5, 1.2)     # out in the wind: look for a line to join, quickly
	if c.since_switch < (1.0 if lone else AI_COOLDOWN):
		return
	var ahead := _car_ahead(c, 16.0)
	# stuck at the back of a big line that's running away: from back here we'll never win, so a group
	# of us jumps out together to start a new line - and the hole we leave cuts the big line's push
	var line_len := c.line_pos + 1 + c.line_behind
	if line_len >= BIG_LINE and c.line_pos >= 3 and c.line_behind >= 2 and _leading_line(c) \
			and rng.randf() < 0.25 + 0.3 * c.aggression:
		var sides := [cur - 1, cur + 1]
		sides.sort_custom(func(a1: int, b1: int) -> bool: return _lane_count(a1) < _lane_count(b1))
		for lane in sides:
			if lane >= 0 and lane < LANES:
				c.crew = mini(c.line_behind, rng.randi_range(2, 4))
				if _go(c, lane, "jump"):
					return
				c.crew = 0
	# stuck in a bump-locked line: back off to open a gap, then come with a run (more often late on)
	if ahead and ahead.s - c.s - Car.LENGTH < 4.0 and absf(c.v - ahead.v) < 0.5 and c.lift <= 0.0 \
			and rng.randf() < keen * 0.5 * (0.04 + 0.08 * c.aggression + 0.2 * clampf((c.s - (race_length - 3200.0)) / 3200.0, 0.0, 1.0)):
		c.lift = rng.randf_range(0.6, 1.4)
		c.run_gap = rng.randf_range(10.0, 25.0)
		return
	# sitting in line: now and then pull out and make a move (more often late in the race);
	# the car behind usually follows and pushes - that's how runs happen at Talladega
	var late := clampf((c.s - (race_length - 3200.0)) / 3200.0, 0.0, 1.0)
	if ahead and ahead.s - c.s - Car.LENGTH < 10.0 and rng.randf() < keen * 0.6 * (0.02 + 0.06 * c.aggression) + 0.3 * late * (0.5 if train else 1.0):
		var options := []
		for lane in [cur - 1, cur + 1]:
			if lane >= 0 and lane < LANES and _path_clear(c, lane_x(lane)):
				options.append(lane)
		if not options.is_empty():
			var lane: int = options[rng.randi_range(0, options.size() - 1)]
			_go(c, lane, "pullout")
			return
	# closing on a slower car ahead: pull out and make a run (the slingshot)
	if ahead and not train and c.v > ahead.v + 1.0 and ahead.s - c.s - Car.LENGTH < 12.0 and rng.randf() < 0.15 + c.aggression * 0.35:
		var sides := [cur - 1, cur + 1]
		if rng.randf() < 0.5:
			sides.reverse()
		for lane in sides:
			if lane >= 0 and lane < LANES and _path_clear(c, lane_x(lane)):
				_go(c, lane, "slingshot")
				c.think = rng.randf_range(1.5, 2.5)      # committed: see the move through
				return
	var best := cur
	var best_score := -INF
	for lane in [cur - 1, cur, cur + 1]:
		if lane < 0 or lane >= LANES:
			continue
		var sc := _lane_score(c, lane)
		if lane != cur:
			sc -= (0.05 if lone else 0.3) + (0.5 * (1.2 - c.aggression) if c.draft > 0.2 else 0.0) + (0.8 if train else 0.0)   # happy where it is (a car out in the wind doesn't hesitate)
			if not _path_clear(c, lane_x(lane)):
				continue
		if sc > best_score:
			best_score = sc
			best = lane
	# blocking: leading a line and a run is coming in the next lane? move over to stop it
	if best == cur and c.draft < 0.15 and rng.randf() < c.aggression * 0.6:
		for o in order:
			var behind := c.s - o.s
			if behind > 1.0 and behind < 18.0 and o.v - c.v > 1.2 and absf(o.x - c.x) > LANE_W * 0.6 and absf(o.x - c.x) < LANE_W * 1.5:
				var lane := clampi(roundi(o.x / LANE_W + (LANES - 1) * 0.5), 0, LANES - 1)
				if _path_clear(c, lane_x(lane)):
					best = lane
				break
	if best != c.lane:
		_go(c, best, "score")


## A straggler on its own: get in line with the nearest car ahead (up to 600 m away), or, if nobody is
## in reach ahead, pull in front of a straggler coming up behind and ease off until it's on the bumper,
## so the two of them can draft together. Moves one lane at a time. Returns true if it did something.
func _regroup(c: Car) -> bool:
	c.think = rng.randf_range(0.3, 0.7)
	if c.since_switch < 0.8:
		return true
	var i := c.place - 1
	var ahead: Car = order[i - 1] if i > 0 else null
	var behind: Car = order[i + 1] if i + 1 < order.size() else null
	var target_lane := -1
	if ahead and ahead.s - c.s < 600.0 and not ahead.finished:
		target_lane = ahead.lane
		c.wait_for = null
	elif behind and c.s - behind.s < 250.0 and not behind.finished:
		target_lane = behind.lane
		if target_lane == c.lane and c.wait_for == null:
			c.wait_for = behind      # same lane now: ease off and let it catch up
			c.wait_t = 8.0
	if target_lane < 0 or target_lane == c.lane:
		return target_lane >= 0
	var step := c.lane + signi(target_lane - c.lane)
	if _path_clear(c, lane_x(step)):
		_go(c, step, "regroup")
	return true


## The nearest car directly ahead (same lane), within `within` metres.
func _car_ahead(c: Car, within: float) -> Car:
	if c.lane_idx <= 0:
		return null
	var o: Car = lane_cars[c.lane][c.lane_idx - 1]
	return o if o.s - c.s - Car.LENGTH < within else null


## How good a lane looks: a close car to draft, a long line, a line that's moving faster than us.
func _lane_score(c: Car, lane: int) -> float:
	var lx := lane_x(lane)
	var nearest := 999.0
	var line := 0
	var line_speed := 0.0
	var last_s := c.s
	for o in order:
		if o == c or o.s <= c.s or absf(o.x - lx) > LANE_W * 0.5:
			continue
		var gap := o.s - c.s - Car.LENGTH
		if gap > (60.0 if c.draft > 0.1 else 250.0):
			continue
		nearest = minf(nearest, gap)
	# the line ahead in that lane (consecutive cars, nose to tail)
	for o in order:
		if o == c or absf(o.x - lx) > LANE_W * 0.5 or o.s <= c.s:
			continue
		if o.s - c.s < (80.0 if c.draft > 0.1 else 260.0):
			line += 1
			line_speed += o.v
	var sc := 0.0
	if nearest < 999.0:
		sc += exp(-maxf(nearest, 0.0) / DRAFT_RANGE) * 1.0
		sc += minf(line, 5) * 0.12 - maxf(line - 7, 0) * 0.08    # a long line is good; a very long one isn't
		sc += (line_speed / maxf(line, 1) - c.v) * 0.3
	else:
		sc -= 1.0       # nobody to draft: hung out in the wind - get back in line!
	return sc + rng.randf_range(-0.08, 0.08)


## Switch `c` into `lane` (one of the 7 fixed lanes) - instantly, and only if there's room there.
## A car is always in exactly one lane, so nobody can get stuck between two.
func _go(c: Car, lane: int, why := "", tight := false) -> bool:
	if lane < 0 or lane >= LANES or lane == c.lane:
		return false
	var human := (c.is_player and not autopilot) or tight
	if not _lane_free(c, lane, -0.05 if tight else (ROOM_PLAYER if human else ROOM_AI_AHEAD),
			ROOM_PLAYER if human else ROOM_AI_BEHIND, 0.0 if tight else LOOK):
		return false
	# the car drafting me in the old lane gets a moment to decide whether to follow
	var tail := _car_ahead_of(c)
	if tail and not tail.is_player:
		tail.follow = c
		tail.think = minf(tail.think, rng.randf_range(0.05, 0.2) if c.crew > 0 else rng.randf_range(0.1, 0.45))
	stats[why] = stats.get(why, 0) + 1
	c.since_switch = 0.0
	c.from_lane = c.lane
	c.lane = lane
	c.x = lane_x(lane)
	if lane_cars.size() == LANES:
		_relane(c, c.from_lane, lane)
	c.target_x = c.x
	return true


## The car right behind `c` in its lane (within 16 m), if any.
func _car_ahead_of(c: Car) -> Car:
	var lst: Array = lane_cars[c.lane]
	for j in range(c.lane_idx + 1, lst.size()):
		var o: Car = lst[j]
		if c.s - o.s - Car.LENGTH >= 16.0:
			return null
		if not o.finished:
			return o
	return null


## Is the line `c` is in at (or near) the front of the field? (that's the one that's running away)
func _leading_line(c: Car) -> bool:
	var front := c
	for o in order:
		if o.lane == c.lane and o.s > front.s and o.s - front.s < Car.LENGTH + LINE_TOUCH + 0.5:
			front = o
	# walk to the front of my line
	var moved := true
	while moved:
		moved = false
		for o in cars:
			if o.lane == c.lane and o.s > front.s and o.s - front.s < Car.LENGTH + LINE_TOUCH + 0.5:
				front = o
				moved = true
				break
	return order[0].s - front.s < 40.0


## Cars in `lane` near me (out-of-range lanes count as full).
func _lane_count(lane: int) -> int:
	if lane < 0 or lane >= LANES:
		return 999
	var n := 0
	for o in cars:
		if o.lane == lane:
			n += 1
	return n


## Nobody in `lane` within `ahead` metres of my nose or `behind` metres of my tail.
## Is there room in `lane`: nobody within `ahead` m of my nose or `behind` m of my tail - now, and (with
## `look` > 0) still `look` seconds from now at everyone's current speeds, so a gap that's closing doesn't
## count (and two cars can't dive into the same space).
func _lane_free(c: Car, lane: int, ahead: float, behind: float, look := 0.0) -> bool:
	if lane < 0 or lane >= LANES:
		return false
	for o in cars:
		if o == c or o.lane != lane or o.finished:
			continue
		var d := o.s - c.s
		if d < Car.LENGTH + ahead and -d < Car.LENGTH + behind:
			return false
		if look > 0.0:
			var d2 := d + (o.v - c.v) * look
			if signf(d) != signf(d2):
				return false            # we'd pass through each other
			if d2 < Car.LENGTH + ahead and -d2 < Car.LENGTH + behind:
				return false
	return true


## The player's lane switch: one lane per tap. Speed is untouched - whatever you built up
## in the draft carries into the new lane.
func shift(c: Car, dir: int) -> void:
	if c == null or c.finished or autopilot or flag == Flag.PACE:
		return
	if _go(c, c.lane + dir):
		c.shift_dir = 0
	else:
		c.shift_dir = dir
		c.shift_wait = SHIFT_WAIT


## Online: a human's tap arriving at the server.
func human_tap(peer: int, dir: int) -> void:
	if humans.has(peer):
		shift(humans[peer], clampi(dir, -1, 1))


func _path_clear(c: Car, tx: float) -> bool:
	return _lane_free(c, clampi(roundi(tx / LANE_W + (LANES - 1) * 0.5), 0, LANES - 1), ROOM_AI_AHEAD, ROOM_AI_BEHIND)
	for o in cars:
		if o == c:
			continue
		var lo := minf(c.x, tx) - Car.WIDTH
		var hi := maxf(c.x, tx) + Car.WIDTH
		if o.x > lo and o.x < hi and absf(o.x - c.x) > 0.3 and o.s - c.s < Car.LENGTH + 1.0 and c.s - o.s < Car.LENGTH + 2.5:
			return false
	return true


## Computer drivers setting up a slingshot: lift off for a moment to open a gap to the car ahead,
## then let the draft suck them back up with a head of steam, and pull out to pass (see _ai_choose).
func _runs(dt: float) -> void:
	for c in cars:
		if c.is_player and not autopilot:
			c.throttle = 1.0
			continue
		if c.wait_for != null:
			# straggler easing off for the car behind to join up (gives up after a few seconds)
			c.wait_t -= dt
			var w := c.wait_for
			if c.wait_t <= 0.0 or w.lane != c.lane or w.s > c.s or c.s - w.s - Car.LENGTH < 3.0 or c.assist <= 0.0:
				c.wait_for = null
				c.throttle = 1.0
			else:
				c.throttle = 0.8
			continue
		if c.lift > 0.0:
			c.lift -= dt
			var ahead := _car_ahead(c, 40.0)
			c.throttle = 0.6
			if c.lift <= 0.0 or ahead == null or ahead.s - c.s - Car.LENGTH > c.run_gap:
				c.lift = 0.0
				c.throttle = 1.0
		else:
			c.throttle = 1.0


## Bump drafting: a car that runs into the one ahead shoves it along.
## Collisions: same-mass cars, momentum conserved. Run into the car ahead and it takes your speed
## (with a little bounce); stay on its bumper and your engine pushes it along - a train in contact
## moves as one body, all the engines against all the drag.
func _bumps(_dt: float) -> void:
	for _pass in 2:
		for i in order.size():
			var a := order[i]
			for j in range(i + 1, order.size()):
				var b := order[j]
				if a.s - b.s > Car.LENGTH + 1.0:
					break
				if a.lane != b.lane or a.s - b.s >= Car.LENGTH:
					continue
				b.s = a.s - Car.LENGTH
				var rel := b.v - a.v
				if rel > 0.0:
					var mid := (a.v + b.v) * 0.5
					var e := RESTITUTION if rel > 0.5 else 0.0     # a real hit bounces, a lean just pushes
					a.v = mid + rel * 0.5 * e
					b.v = mid - rel * 0.5 * e
				break


func _finishes() -> void:
	for c in order:
		if not c.finished and c.s >= race_length:
			c.finished = true
			c.finish_time = clock
			finish_order.append(c)
			c.target_x = lane_x(c.lane)
	if flag == Flag.GREEN and order[0].s > race_length - LAP:
		flag = Flag.WHITE
	if flag != Flag.CHECKERED and not finish_order.is_empty():
		flag = Flag.CHECKERED
	# race over once everyone is home, or 60 s after the winner (stragglers get their running order)
	if not done and (finish_order.size() == cars.size() or (not finish_order.is_empty() and clock - finish_order[0].finish_time > 60.0)):
		done = true
		for c in order:
			if not c.finished:
				finish_order.append(c)
				c.finish_time = -1.0     # still running
		race_over.emit()


func _unhandled_input(event: InputEvent) -> void:
	if mode == "server" or player == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_A, KEY_LEFT:
				_tap(-1)
			KEY_D, KEY_RIGHT:
				_tap(1)


func _tap(dir: int) -> void:
	if mode == "local":
		shift(player, dir)
	elif mode == "client" and not player.finished and flag != Flag.PACE and player.lane + dir >= 0 and player.lane + dir < LANES:
		Net.send_tap(dir)
		# show the switch straight away if it's clearly open; the server has the final say
		if _lane_free(player, player.lane + dir, ROOM_PLAYER + 1.0, ROOM_PLAYER + 1.5, CLIENT_LOOK):
			player.lane += dir
			player.x = lane_x(player.lane)
			player.pred_until = _net_clock + 0.6


# ------------------------------------------------------------------ online

## Server: the state every online player needs, ~20 times a second.
## Per car: s, lane, v, draft meter, push meter.  Header: clock, flag.
func snapshot() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(2 + cars.size() * 5)
	out[0] = clock
	out[1] = float(flag)
	for i in cars.size():
		var c := cars[i]
		var k := 2 + i * 5
		out[k] = c.s
		out[k + 1] = float(c.lane)
		out[k + 2] = c.v
		out[k + 3] = c.draft_meter
		out[k + 4] = c.push_meter
	return out


## Server: finishing order so far (grid indices) and their times.
func finish_data() -> Array:
	var idx := PackedInt32Array()
	var times := PackedFloat32Array()
	for c in finish_order:
		idx.append(cars.find(c))
		times.append(c.finish_time)
	return [idx, times]


## Client: a snapshot from the server.
func apply_snapshot(data: PackedFloat32Array, fin_idx: PackedInt32Array, fin_t: PackedFloat32Array) -> void:
	if data.size() < 2 + cars.size() * 5:
		return
	if not _snaps.is_empty() and data[0] <= _snaps.back()[0]:
		return      # an old one arriving late
	_snaps.append([data[0], data])
	if _snaps.size() > 30:
		_snaps.pop_front()
	flag = int(data[1]) as Flag
	for i in cars.size():
		var c := cars[i]
		var k := 2 + i * 5
		c.net_t = _net_clock
		c.draft_meter = data[k + 3]
		c.push_meter = data[k + 4]
	if fin_idx.size() != finish_order.size():
		finish_order.clear()
		for j in fin_idx.size():
			var c := cars[fin_idx[j]]
			c.finished = true
			c.finish_time = fin_t[j]
			finish_order.append(c)


## Client: show the race NET_DELAY behind the newest snapshot, blending between the two snapshots
## either side of that moment. Snapshots arrive unevenly over the internet; blending between real
## positions (instead of guessing ahead from the last one) keeps the motion smooth.
func _follow_server(delta: float) -> void:
	if _snaps.is_empty():
		return
	var newest: float = _snaps.back()[0]
	var target := newest - NET_DELAY
	if _rt < 0.0 or absf(target - _rt) > 0.75:
		_rt = target
	else:
		_rt += delta
		_rt += (target - _rt) * minf(delta * 2.0, 1.0)     # drift gently back on schedule
	clock = maxf(_rt, 0.0)
	# the two snapshots either side of _rt
	var a: Array = _snaps[0]
	var b: Array = _snaps[0]
	for k in range(_snaps.size() - 1, -1, -1):
		if _snaps[k][0] <= _rt:
			a = _snaps[k]
			b = _snaps[mini(k + 1, _snaps.size() - 1)]
			break
	var ta: float = a[0]
	var tb: float = b[0]
	var da: PackedFloat32Array = a[1]
	var db: PackedFloat32Array = b[1]
	var alpha := clampf((_rt - ta) / (tb - ta), 0.0, 1.0) if tb > ta else 0.0
	var ahead := clampf(_rt - tb, 0.0, 0.25) if tb <= ta or _rt > tb else 0.0   # past the newest: guess a little
	for i in cars.size():
		var c := cars[i]
		var k := 2 + i * 5
		c.v = lerpf(da[k + 2], db[k + 2], alpha)
		c.s = lerpf(da[k], db[k], alpha) + c.v * ahead
		var lane := int(db[k + 1]) if alpha >= 0.5 else int(da[k + 1])
		if lane != c.lane and not (c == player and _net_clock < player.pred_until):
			c.lane = lane
			c.x = lane_x(lane)
	# drop snapshots we're well past
	while _snaps.size() > 2 and _snaps[1][0] < _rt - 0.5:
		_snaps.pop_front()
	_sort()


## Client: the server says the race is over.
func set_done() -> void:
	if not done:
		done = true
		race_over.emit()
