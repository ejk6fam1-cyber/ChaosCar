extends Node
## Two cars alone on the track: you start 40 m behind another car, follow its draft, then pull out
## 3 m from its bumper. Measures the closing speed you build and how fast you get past.
var race: Race
var other: Car
var phase := 0
var t := 0.0
var t_pull := 0.0
var max_adv := 0.0
func _ready() -> void:
	race = load("res://race.tscn").instantiate()
	race.autopilot = true
	add_child(race)
func _physics_process(d: float) -> void:
	if race.player == null: return
	if phase == 0:
		# clear the track except the player and one car ahead; both at solo speed
		for c in race.cars:
			if c != race.player:
				if other == null:
					other = c
				else:
					c.s = -100000.0
					c.v = 0.0
					c.finished = true
		race.flag = Race.Flag.GREEN
		race.clock = Race.PACE_TIME + 1.0
		other.lane = 2; other.from_lane = 2; other.x = Race.lane_x(2); other.target_x = other.x; other.s = 1000.0; other.v = Race.SOLO_TOP; other.think = 9999.0
		race.player.lane = 2; race.player.from_lane = 2; race.player.x = Race.lane_x(2); race.player.target_x = race.player.x; race.player.s = 1000.0 - 40.0 - Car.LENGTH; race.player.v = Race.SOLO_TOP
		race.player.think = 9999.0
		phase = 1
		return
	other.think = 9999.0
	race.player.think = 9999.0
	t += d
	var gap := other.s - race.player.s - Car.LENGTH
	var adv := (race.player.v - other.v) * Race.MPH
	max_adv = maxf(max_adv, adv)
	if phase == 1 and gap < 10.0:
		print("followed the draft for %.1f s: closing at %.1f mph when 10 m behind (you %.0f mph, them %.0f mph)" % [t, adv, race.player.v * Race.MPH, other.v * Race.MPH])
		race._go(race.player, 3)
		t_pull = t
		phase = 2
	elif phase == 2 and race.player.s - Car.LENGTH > other.s:
		print("SLINGSHOT: completely past %.1f s after pulling out, still %.1f mph faster" % [t - t_pull, adv])
		phase = 3
		t_pull = t
	elif phase == 3 and t - t_pull > 3.0:
		print("3 s later: %.1f m ahead" % (race.player.s - other.s - Car.LENGTH))
		get_tree().quit()
	if t > 60.0:
		print("timeout phase %d gap %.1f adv %.1f" % [phase, gap, adv]); get_tree().quit()
