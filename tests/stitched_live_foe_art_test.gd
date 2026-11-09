extends SceneTree
## Every live-battle foe (the S15 resist table names them all) maps to drawn stage art;
## a foe without an ACTOR_ART entry stands invisible and its plate drifts to the corner.

const ROSTER := preload("res://scripts/live_enemy_roster.gd")
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _run() -> void:
	var seams := StitchedDeeperSeams.table()
	_check(not seams.is_empty(), "the S15 table loads")
	_check(seams.get("resists", {}).has("moth_queen"), "the Moth Queen boss is a live foe")
	for foe_id in seams.get("resists", {}):
		var idle := str(ROSTER.art_paths(foe_id).get("idle", ""))
		_check(not idle.is_empty(), foe_id + " has an ACTOR_ART entry")
		_check(ResourceLoader.exists(idle, "Texture2D"), foe_id + " idle art loads: " + idle)
	for failure in failures:
		printerr(failure)
	print("stitched_live_foe_art_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
