class_name Spotter
extends Node
## Your spotter on the radio: tells you who's alongside, when it's clear, who's coming, and how the
## race is going. Shown in the radio box on the race screen, with a radio click.
##  "Car outside!" / "Car inside!" / "Three wide!"     someone pulls alongside
##  "Clear outside" / "Clear inside" / "All clear"     they've gone
##  "Still there!"                                     still alongside (every 3 s, or when you tap into them)
##  "Car coming outside/inside"                        closing fast in the next lane
##  "You got help" / "Lost the draft"                  your draft and push
##  "You're the leader!" / "White flag - last lap!" / "Checkered! P5"
## Outside = the lane to your right (toward the wall), inside = to your left (toward the infield).

var race: Race
var hud: RaceHud
var audio: RaceAudio

var _out := false          # someone alongside outside right now
var _in := false
var _out_t := 0.0          # how long they've been there
var _in_t := 0.0
var _still_t := 0.0
var _coming_t := {-1: 0.0, 1: 0.0}
var _draft_t := 0.0
var _push_t := 0.0
var _had_draft := false
var _had_push := false
var _was_leader := false
var _white := false
var _done := false
var _last := ""
var _last_t := 0.0
var _quiet := 0.0
const ALONGSIDE := Car.LENGTH + 1.0   # metres nose-to-tail that counts as alongside


func _ready() -> void:
	race.tapped.connect(_on_tap)


func say(text: String, important := false) -> void:
	if not important and (_quiet > 0.0 or (text == _last and _last_t < 2.0)):
		return
	_last = text
	_last_t = 0.0
	_quiet = 0.6
	hud.spotter(text)
	if audio:
		audio.radio()


func _alongside(lane: int) -> Car:
	var p := race.player
	if lane < 0 or lane >= Race.LANES:
		return null
	for c in race.cars:
		if c != p and c.lane == lane and not c.finished and absf(c.s - p.s) < ALONGSIDE:
			return c
	return null


func _on_tap(dir: int) -> void:
	var p := race.player
	if p == null or p.finished:
		return
	if _alongside(p.lane + dir) != null:
		say("Still there!", true)


func _process(delta: float) -> void:
	var p := race.player
	if p == null or race.flag == Race.Flag.PACE:
		return
	_last_t += delta
	_quiet -= delta
	if p.finished:
		if not _done:
			_done = true
			say("Checkered flag! P%d" % p.place, true)
		return
	# alongside
	var out_now := _alongside(p.lane + 1) != null
	var in_now := _alongside(p.lane - 1) != null
	if out_now and in_now and not (_out and _in):
		say("Three wide!", true)
	elif out_now and not _out:
		say("Car outside!", true)
	elif in_now and not _in:
		say("Car inside!", true)
	if _out and not out_now and _out_t > 0.4:
		say("All clear" if not in_now else "Clear outside", true)
	if _in and not in_now and _in_t > 0.4:
		say("All clear" if not out_now else "Clear inside", true)
	_out_t = _out_t + delta if out_now else 0.0
	_in_t = _in_t + delta if in_now else 0.0
	_out = out_now
	_in = in_now
	if out_now or in_now:
		_still_t += delta
		if _still_t > 3.0:
			_still_t = 0.0
			say("Still there")
	else:
		_still_t = 0.0
	# someone closing fast in the next lane
	for side: int in [-1, 1]:
		_coming_t[side] -= delta
		if (side == 1 and out_now) or (side == -1 and in_now) or _coming_t[side] > 0.0:
			continue
		var lane := p.lane + side
		if lane < 0 or lane >= Race.LANES:
			continue
		for c in race.cars:
			if c.lane == lane and c.s < p.s - ALONGSIDE and p.s - c.s < 25.0 and c.v - p.v > 3.0:
				say("Car coming %s" % ("outside" if side == 1 else "inside"))
				_coming_t[side] = 4.0
				break
	# draft and push
	_draft_t -= delta
	_push_t -= delta
	var has_push := p.push_meter > 0.05
	if has_push and not _had_push and _push_t <= 0.0:
		say("You got help")
		_push_t = 8.0
	_had_push = has_push
	var has_draft := p.draft_meter > 0.45
	if _had_draft and p.draft_meter < 0.12 and _draft_t <= 0.0:
		say("Lost the draft")
		_draft_t = 8.0
	if has_draft:
		_had_draft = true
	elif p.draft_meter < 0.12:
		_had_draft = false
	# the race
	var leader := p.place == 1
	if leader and not _was_leader:
		say("You're the leader!", true)
	_was_leader = leader
	if race.flag == Race.Flag.WHITE and not _white:
		_white = true
		say("White flag - last lap!", true)
