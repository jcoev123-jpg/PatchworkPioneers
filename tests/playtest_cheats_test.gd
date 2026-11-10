extends SceneTree
## Debug-build playtest cheats: each jump lands on a sealed, consistent session showing the right view.

var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var cheats: Node = app.get_node_or_null("PlaytestCheats")
	_check(OS.is_debug_build() and cheats != null, "debug build mounts the cheat node on App")
	if cheats == null:
		_finish()
		return
	_check(cheats.run("help").contains("floor N"), "help lists the commands")
	_check(cheats.run("bogus").begins_with("unknown command"), "unknown commands are refused")

	_check(cheats.run("run 77").begins_with("new run"), "run starts a new Stitched run")
	var session: StitchedRunSession = app.stitched_run_session
	_check(session != null and session.seed_value == 77 and session.walks_enabled and session.phase == "map"
		and session.is_consistent() and not app.title_view.visible, "run: seed 77 map with walks, title hidden")

	cheats.run("floor 6")
	session = app.stitched_run_session
	_check(session.map.get_current_floor() == 5 and session.phase == "map" and session.is_consistent(),
		"floor 6: map before floor 6")
	_check(session.choices().size() > 0, "floor 6: the next floor's nodes are choosable")

	var said: String = cheats.run("walk walls")
	_check(session.phase == "walk" and session.walk != null and session.is_consistent()
		and is_instance_valid(app.stitched_run_walk), "walk walls: a mounted Walk (%s)" % said)
	_check(session.walk_area() == "walls", "walk walls: on a walls floor")
	cheats.run("walk basket")
	_check(session.phase == "walk" and session.walk_area() == "sewing_basket" and session.is_consistent(),
		"walk basket: moves to a basket floor")

	for kind in ["normal", "elite", "boss"]:
		said = cheats.run("fight " + kind)
		_check(session.phase == "battle" and session.battle != null and session.is_consistent()
			and is_instance_valid(app.stitched_run_battle) and app.stitched_run_battle.battle == session.battle,
			"fight %s: a mounted battle (%s)" % [kind, said])
	cheats.run("fight elite")
	var gold_before := session.gold
	said = cheats.run("win")
	_check(said == "battle won" and session.phase == "map" and session.gold > gold_before and session.is_consistent(),
		"win: elite settles to the map with gold (%s)" % said)

	said = cheats.run("event needle_gate")
	_check(session.phase == "visit" and session.pending.get("event_id") == "needle_gate" and session.is_consistent(),
		"event needle_gate opens that event (%s)" % said)
	said = cheats.run("event")
	_check(session.phase == "visit" and not str(session.pending.get("event_id", "")).is_empty(),
		"event without an id opens a random one (%s)" % said)
	for verb in ["camp", "shop", "sewing", "unpicker", "stall"]:
		said = cheats.run(verb)
		_check(session.phase == "visit" and session.is_consistent() and is_instance_valid(app.stitched_run_panel),
			"%s opens its visit page (%s)" % [verb, said])

	cheats.run("candle 7")
	cheats.run("gold 250")
	cheats.run("scraps 9")
	cheats.run("fear 40")
	_check(session.candle == 7 and session.gold == 250 and session.scraps == 9 and session.kid_fear() == 40
		and session.is_consistent(), "candle, gold, scraps and fear set")
	session.heroes[0].hp = 1
	session._seal()
	cheats.run("heal")
	_check(session.heroes[0].hp == session.heroes[0].max_hp and session.is_consistent(), "heal restores HP")

	_check(cheats.run_script("run;floor:3;fight boss") == "Boss battle" and app.stitched_run_session.phase == "battle"
		and app.stitched_run_session.map.get_current_floor() == 12,
		"a ';' script chains commands and the Boss stands on floor 12")
	_finish()


func _finish() -> void:
	print("playtest_cheats_test: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)
