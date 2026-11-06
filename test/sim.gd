extends Node
## Headless race: pack shape over time, lane usage, lane changes, overlaps, finish time.
var race: Race
var t := 0.0
var nxt := 0.0
var lane_changes := 0
var prev_lane := {}
var overlaps := 0
var solo := []
var lined := []
var lead_changes := 0
var last_leader = null
func _ready() -> void:
	race = load("res://race.tscn").instantiate()
	race.autopilot = true
	add_child(race)
func _lane(c: Car) -> int:
	return c.lane
func _physics_process(d: float) -> void:
	t += d
	if race.order.is_empty(): return
	for c in race.cars:
		var l := _lane(c)
		if prev_lane.has(c) and prev_lane[c] != l: lane_changes += 1
		prev_lane[c] = l
		if race.flag == Race.Flag.GREEN:
			if c.draft < 0.05 and c.push < 0.05: solo.append(c.v)
			elif c.draft > 0.6 and c.line_behind >= 3: lined.append(c.v)
	for i in race.order.size() - 1:
		var a: Car = race.order[i]
		for j in range(i + 1, mini(i + 4, race.order.size())):
			var b: Car = race.order[j]
			if absf(a.x - b.x) < Car.WIDTH - 0.05 and a.s - b.s < Car.LENGTH - 0.05: overlaps += 1
	if race.flag != Race.Flag.PACE and int(t * 60) % 60 == 0 and race.order[0] != last_leader:
		if last_leader != null: lead_changes += 1
		last_leader = race.order[0]
	if t >= nxt:
		nxt += 30.0
		var o: Array = race.order
		var lanes := []
		lanes.resize(Race.LANES)
		lanes.fill(0)
		for c in race.cars: lanes[_lane(c)] += 1
		var within := 0
		var w150 := 0
		for c in o:
			if o[0].s - c.s < 60.0: within += 1
			if o[0].s - c.s < 150.0: w150 += 1
		var vs := []
		for c in o: vs.append(c.v * Race.MPH)
		vs.sort()
		var leaders := {}
		var buckets := [0, 0, 0, 0, 0, 0]
		for c in o:
			buckets[mini(int((o[0].s - c.s) / 100.0), 5)] += 1
		print("   cars per 100 m behind the leader: %s" % str(buckets))
		var front := ""
		for k in 12:
			var c: Car = o[k]
			front += " [L%d -%.0fm p%d %.0f]" % [c.lane, o[0].s - c.s, c.line_pos, c.v * Race.MPH]
		print("   front:" + front)
		var strag := 0
		var drafting := 0
		for c in o:
			if c.assist > 0.0:
				strag += 1
				if c.draft > 0.3 or c.push > 0.0:
					drafting += 1
		print("   stragglers (300 m+ back): %d, of them drafting or pushed: %d" % [strag, drafting])
		var lens := {}
		for c in o:
			if c.line_pos == 0:
				var L: int = c.line_behind + 1
				lens[L] = lens.get(L, 0) + 1
		print("   line lengths: ", lens)
		print("t=%5.1f leader #%d %5.0f m  pack length %5.1f m  within 60m %2d  within 150m %2d  lanes %s  mph %d-%d  player P%d  lane changes so far %d" % [
			race.clock, o[0].number, o[0].s, o[0].s - o[-1].s, within, w150, str(lanes), vs[0], vs[-1], race.player.place, lane_changes])
	if race.finish_order.size() == Race.FIELD or t > 400.0:
		var avg := func(a: Array) -> float:
			var s := 0.0
			for v in a: s += v
			return s / maxf(a.size(), 1)
		print("FINISH winner %.1f s, last %.1f s, field spread at the line %.1f s" % [race.finish_order[0].finish_time, race.finish_order[-1].finish_time, race.finish_order[-1].finish_time - race.finish_order[0].finish_time])
		print("speed: solo cars avg %.1f mph, cars drafting in a line of 3+ avg %.1f mph" % [avg.call(solo) * Race.MPH, avg.call(lined) * Race.MPH])
		print("overlapping-car frames: %d   total lane changes %d   lead changes %d" % [overlaps, lane_changes, lead_changes])
		print("by reason: ", race.stats)
		get_tree().quit()
