extends Node
## Times the race simulation (as the server runs it) and the track drawing (as the browser does).
var race: Race
var f := 0
var t_sim := 0
var t_draw := 0
func _ready() -> void:
	race = Race.new()
	race.setup({"mode": "server", "laps": 5, "grid": "random", "humans": [{"id": 5, "name": "A", "spot": 3}], "seed": 1})
	add_child(race)
func _physics_process(_d: float) -> void:
	f += 1
	if f == 300:
		var t0 := Time.get_ticks_usec()
		for i in 600:
			race._step(1.0 / 120.0)
		t_sim = Time.get_ticks_usec() - t0
		print("server sim: %.2f ms per 1/60 s frame (2 steps)  -> %.0f%% of one CPU core" % [t_sim / 300.0 / 1000.0, t_sim / 300.0 / 16666.0 * 100.0])
		# track drawing cost: Oval.point calls like track_view makes each frame
		var t1 := Time.get_ticks_usec()
		var n := 0
		for k in 30:
			var s := 0.0
			while s < 350.0:
				for x in 24:
					Oval.point(s, float(x))
					n += 1
				s += 2.0
		t_draw = Time.get_ticks_usec() - t1
		print("Oval.point: %.2f us each; ~%d calls per drawn frame -> %.1f ms per frame natively" % [float(t_draw) / n, n / 30, float(t_draw) / 30.0 / 1000.0])
		get_tree().quit()
