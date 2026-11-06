extends Node
var race: Race
var f := 0
var last := ""
var said := {}
func _ready() -> void:
	race = load("res://race.tscn").instantiate()
	race.autopilot = true
	add_child(race)
func _process(_d: float) -> void:
	f += 1
	var t: String = race.hud._radio_text.text
	if t != last and race.hud._radio_t > 1.9:
		said[t] = said.get(t, 0) + 1
		if said[t] <= 2:
			print("t=%5.1f  P%-2d  spotter: %s" % [race.clock, race.player.place, t])
	last = t
	if f == 300:
		var a := race.audio
		print("audio: engine pitch %.2f vol %.0f dB, pack %.0f dB, wind %.0f dB, crowd %.0f dB, loop mode %d end %d, playing %s" % [a._engine.pitch_scale, a._engine.volume_db, a._pack.volume_db, a._wind.volume_db, a._crowd.volume_db, (a._engine.stream as AudioStreamWAV).loop_mode, (a._engine.stream as AudioStreamWAV).loop_end, a._engine.playing])
	if f == 400:
		print("spotter calls in 60 s: ", said)
		get_tree().quit()
