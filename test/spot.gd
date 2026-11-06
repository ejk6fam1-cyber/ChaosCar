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
	if f == 3600:
		print("spotter calls in 60 s: ", said)
		get_tree().quit()
