extends Node
## A 10-car train running bumper to bumper at full speed, and you 30 m behind it in the same lane.
## Can the draft alone pull you up to it? Prints the gap every 2 s.
var race: Race
var train: Array[Car] = []
var phase := 0
var t := 0.0
var nxt := 0.0

func _ready() -> void:
	race = load("res://race.tscn").instantiate()
	race.autopilot = true
	add_child(race)

func _physics_process(d: float) -> void:
	if race.player == null:
		return
	if phase == 0:
		for c in race.cars:
			if c == race.player:
				continue
			if train.size() < 10:
				train.append(c)
			else:
				c.s = -100000.0
				c.v = 0.0
				c.finished = true
		race.flag = Race.Flag.GREEN
		race.clock = Race.PACE_TIME + 1.0
		for k in train.size():
			var c := train[k]
			c.lane = 3; c.from_lane = 3; c.x = Race.lane_x(3); c.target_x = c.x
			c.s = 2000.0 - k * Car.LENGTH
			c.v = 90.0
			c.engine = 1.0; c.form_target = 0.0; c.form = 0.0
			c.think = 99999.0
		var p := race.player
		p.lane = 3; p.from_lane = 3; p.x = Race.lane_x(3); p.target_x = p.x
		p.s = train[-1].s - Car.LENGTH - 30.0
		p.v = 90.0
		phase = 1
		return
	for c in train:
		c.think = 99999.0
		c.since_switch = 0.0
	race.player.think = 99999.0
	t += d
	if t >= nxt:
		nxt += 2.0
		var gap := train[-1].s - race.player.s - Car.LENGTH
		print("t=%4.1f  gap to the back of the train %5.1f m   train %5.1f mph   you %5.1f mph" % [t, gap, train[0].v * Race.MPH, race.player.v * Race.MPH])
		if gap < 0.5:
			print("JOINED the train after %.1f s" % t)
			get_tree().quit()
	if t > 40.0:
		print("never caught it")
		get_tree().quit()
