class_name RaceAudio
extends Node
## Race sound, all synthesised (tools/make_sfx.py):
##  - your engine: pitch follows your speed;
##  - the pack: louder the more cars are close around you;
##  - wind: loud in clean air, quiet when you're tucked in the draft;
##  - the crowd: when you're on the front stretch and tri-oval, in front of the grandstands;
##  - a whoosh when a car passes you (or you pass it) in the next lane, from its side;
##  - the spotter's radio click (played by Spotter).
## M mutes / unmutes (remembered).

var race: Race
var _engine: AudioStreamPlayer
var _pack: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _crowd: AudioStreamPlayer
var _whoosh: Array[AudioStreamPlayer2D] = []
var _radio: AudioStreamPlayer
var _side_was := {}            # car -> which side of me it was on last frame (+1 ahead / -1 behind)
var _whoosh_t := 0.0


func _ready() -> void:
	_engine = _loop("engine")
	_pack = _loop("pack")
	_wind = _loop("wind")
	_crowd = _loop("crowd")
	for i in 3:
		var w := AudioStreamPlayer2D.new()
		w.stream = load("res://assets/sfx/whoosh.wav")
		w.max_distance = 3000.0
		add_child(w)
		_whoosh.append(w)
	_radio = AudioStreamPlayer.new()
	_radio.stream = load("res://assets/sfx/radio.wav")
	_radio.volume_db = -8.0
	add_child(_radio)
	AudioServer.set_bus_mute(0, bool(Net.load_setting("muted", false)))


func _loop(name: String) -> AudioStreamPlayer:
	var st: AudioStreamWAV = load("res://assets/sfx/%s.wav" % name)    # looping is set in its .import
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p


func radio() -> void:
	_radio.play()


static func toggle_mute() -> void:
	var m := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, m)
	Net.save_setting("muted", m)


func _process(delta: float) -> void:
	var p := race.player
	if p == null:
		return
	var v := p.v
	var spd := clampf(v / 95.0, 0.0, 1.2)
	var fade := 0.0 if not p.finished else clampf((race.clock - p.finish_time) / 4.0, 0.0, 1.0)  # quieter after the flag
	# your engine
	_engine.pitch_scale = 0.55 + spd * 0.75
	_engine.volume_db = lerpf(-10.0, -30.0, fade)
	# the pack: cars within 40 m
	var near := 0
	for c in race.cars:
		if c != p and absf(c.s - p.s) < 40.0:
			near += 1
	_pack.pitch_scale = 0.55 + spd * 0.7
	_pack.volume_db = lerpf(-40.0, -11.0, clampf(near / 10.0, 0.0, 1.0)) - fade * 20.0
	# wind: clean air roars, the draft is calm
	_wind.pitch_scale = 0.7 + spd * 0.5
	_wind.volume_db = lerpf(-14.0, -30.0, clampf(p.draft_meter * 1.5, 0.0, 1.0)) - (1.0 - clampf(spd, 0.0, 1.0)) * 20.0
	# crowd: in front of the grandstands
	var ls := fposmod(p.s + Oval.front_behind, Race.LAP)
	var in_front := ls < Oval.front_behind + Oval.front_ahead
	_crowd.volume_db = move_toward(_crowd.volume_db, -12.0 if in_front else -45.0, delta * 25.0)
	# whoosh: a car in the next lane crossing from behind me to ahead (or the other way), quickly
	_whoosh_t -= delta
	for c in race.cars:
		if c == p or absi(c.lane - p.lane) != 1 or absf(c.s - p.s) > 12.0:
			_side_was.erase(c)
			continue
		var side := 1 if c.s > p.s else -1
		if _side_was.has(c) and _side_was[c] != side and absf(c.v - p.v) > 2.0 and _whoosh_t <= 0.0:
			_play_whoosh(c, absf(c.v - p.v))
		_side_was[c] = side


func _play_whoosh(c: Car, closing: float) -> void:
	_whoosh_t = 0.25
	for w in _whoosh:
		if not w.playing:
			w.global_position = c.global_position
			w.pitch_scale = clampf(0.8 + closing / 15.0, 0.8, 1.5)
			w.volume_db = clampf(-12.0 + closing, -12.0, -2.0)
			w.play()
			return
