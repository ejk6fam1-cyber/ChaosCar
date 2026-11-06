class_name Spotter
extends Node
## Your spotter on the radio (shown in the radio box on the race screen). He keeps it short and only
## talks when it matters:
##  "Car outside." / "Car inside." / "Three wide!"     someone settles in alongside you (not just flashing by)
##  "Clear." / "Clear outside." / "Clear inside."      they've gone, after being alongside a while
##  "Still there!"                                     you tapped toward a car that's alongside
##  "You got help." / "Lost the draft."                now and then
##  "You're the leader!" / "White flag. Last lap!" / "Checkered flag."
## Outside = the lane to your right (toward the wall), inside = to your left (toward the infield).

var race: Race
var hud: RaceHud

var _out_t := 0.0          # how long someone's been alongside outside (0 = nobody)
var _in_t := 0.0
var _out_called := false   # we've told him about that car
var _in_called := false
var _three_called := false
var _out_long := 0.0       # how long the car we called was alongside
var _in_long := 0.0
var _help_t := 0.0         # cooldowns
var _draft_t := 0.0
var _had_push := false
var _had_draft := false
var _was_leader := false
var _white := false
var _done := false
var _quiet := 0.0          # no routine calls until this runs out
const ALONGSIDE := Car.LENGTH + 1.0   # metres nose-to-tail that counts as alongside
const SETTLE := 0.45                   # seconds alongside before it's worth a call
const GAP := 1.5                       # seconds between routine calls
const WORTH_CLEAR := 1.2               # only call 'clear' for a car that was alongside at least this long


func _ready() -> void:
	race.tapped.connect(_on_tap)


## important: alongside / safety calls - always shown. (`key` names the line; kept for if voice returns.)
func say(text: String, key: String, important := false) -> void:
	if not important and _quiet > 0.0:
		return
	_quiet = GAP
	hud.spotter(text)


func _alongside(lane: int) -> bool:
	var p := race.player
	if lane < 0 or lane >= Race.LANES:
		return false
	for c in race.cars:
		if c != p and c.lane == lane and not c.finished and absf(c.s - p.s) < ALONGSIDE:
			return true
	return false


func _on_tap(dir: int) -> void:
	var p := race.player
	if p == null or p.finished:
		return
	if _alongside(p.lane + dir):
		say("Still there!", "still_there", true)


func _process(delta: float) -> void:
	var p := race.player
	if p == null or race.flag == Race.Flag.PACE:
		return
	_quiet -= delta
	if p.finished:
		if not _done:
			_done = true
			if p.place == 1:
				say("Checkered flag! You won it!", "you_won", true)
			else:
				say("Checkered flag. P%d" % p.place, "checkered", true)
		return
	# --- alongside: only call cars that settle in beside you
	var out_now := _alongside(p.lane + 1)
	var in_now := _alongside(p.lane - 1)
	_out_t = _out_t + delta if out_now else 0.0
	_in_t = _in_t + delta if in_now else 0.0
	var out_set := _out_t > SETTLE
	var in_set := _in_t > SETTLE
	_out_long = maxf(_out_long, _out_t)
	_in_long = maxf(_in_long, _in_t)
	if out_set and in_set and not _three_called:
		say("Three wide!", "three_wide", true)
		_three_called = true
		_out_called = true
		_in_called = true
	elif out_set and not _out_called:
		say("Car outside.", "car_outside", true)
		_out_called = true
	elif in_set and not _in_called:
		say("Car inside.", "car_inside", true)
		_in_called = true
	# they've gone (after three wide: one "Clear." once both sides are)
	if _three_called:
		if not out_now and not in_now:
			_three_called = false
			_out_called = false
			_in_called = false
			say("Clear.", "clear", true)
	else:
		if not out_now and _out_called:
			_out_called = false
			if _out_long > WORTH_CLEAR:
				say("Clear." if not in_now else "Clear outside.", "clear" if not in_now else "clear_outside", true)
		if not in_now and _in_called:
			_in_called = false
			if _in_long > WORTH_CLEAR:
				say("Clear." if not out_now else "Clear inside.", "clear" if not out_now else "clear_inside", true)
	if not out_now:
		_out_long = 0.0
	if not in_now:
		_in_long = 0.0
	# --- now and then: draft and push
	_help_t -= delta
	_draft_t -= delta
	var has_push := p.push_meter > 0.05
	if has_push and not _had_push and _help_t <= 0.0:
		say("You got help.", "got_help")
		_help_t = 20.0
	_had_push = has_push
	if _had_draft and p.draft_meter < 0.12 and _draft_t <= 0.0:
		say("Lost the draft.", "lost_draft")
		_draft_t = 20.0
	if p.draft_meter > 0.45:
		_had_draft = true
	elif p.draft_meter < 0.12:
		_had_draft = false
	# --- the race
	var leader := p.place == 1
	if leader and not _was_leader:
		say("You're the leader!", "leader", true)
	_was_leader = leader
	if race.flag == Race.Flag.WHITE and not _white:
		_white = true
		say("White flag. Last lap!", "white_flag", true)
