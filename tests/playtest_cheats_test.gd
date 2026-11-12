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
	var shortcut: String = cheats.run("fight elite")
	_check(session.map.get_current_floor() == 6 and session.phase == "battle"
		and session.is_consistent(), "floor 6 then fight: enters floor 6 rather than showing floor 5 (%s)" % shortcut)
	cheats.run("floor 6")

	var said: String = cheats.run("walk walls")
	_check(session.phase == "walk" and session.walk != null and session.is_consistent()
		and is_instance_valid(app.stitched_run_walk), "walk walls: a mounted Walk (%s)" % said)
	_check(session.map.get_current_floor() == 6 and session.walk_area() == "walls",
		"walk walls: enters floor 6 instead of displaying floor 5")
	cheats.run("walk basket")
	_check(session.phase == "walk" and session.map.get_current_floor() == 10
		and session.walk_area() == "sewing_basket" and session.is_consistent(),
		"walk basket: enters floor 10 instead of displaying floor 9")

	for kind in ["normal", "elite", "boss"]:
		said = cheats.run("fight " + kind)
		_check(session.phase == "battle" and session.battle != null and session.is_consistent()
			and is_instance_valid(app.stitched_run_battle) and app.stitched_run_battle.battle == session.battle,
			"fight %s: a mounted battle (%s)" % [kind, said])
		if kind == "normal":
			_check(session.map.get_current_floor() == 10,
				"fight from a floor-10 Walk does not accidentally enter floor 11")
	cheats.run("fight elite")
	# The held victory beat can precede settlement. Cheats must not corrupt a
	# terminal battle's heroes, HP, statuses or outcome in that interval.
	var terminal_battle: StitchedRules = session.battle
	terminal_battle._outcome = "victory"
	var terminal_state := terminal_battle.state_snapshot()
	for terminal_command in ["defeat", "hp h1 0", "status h1 stun 1"]:
		var refusal: String = cheats.run(terminal_command)
		_check(refusal.begins_with("failed:") and terminal_battle.state_snapshot() == terminal_state
			and session.battle == terminal_battle and session.phase == "battle",
			"terminal battle rejects %s without changing a finished snapshot" % terminal_command)
	terminal_battle._outcome = "ongoing"
	var gold_before := session.gold
	var before_foes := session.battle._living_foes().size()
	said = cheats.run("summon")
	_check(before_foes == 3 and session.battle._living_foes().size() == 4
		and not session.battle._foe_at(4).is_empty() and session.is_consistent(),
		"summon: fourth real foe joins the running battle (%s)" % said)
	var fourth: Dictionary = session.battle._foe_at(4)
	said = cheats.run("status f4 bleed 2")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("bleed", 0)) == 2
		and session.is_consistent(), "status: new foe receives real bleed (%s)" % said)
	said = cheats.run("status f4 rot 3")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("rot", 0)) == 3
		and session.is_consistent(), "status: rot enters the real rule statuses (%s)" % said)
	said = cheats.run("status f4 stun 1")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("stun", 0)) == 1
		and session.is_consistent(), "status: stun enters the real rule statuses (%s)" % said)
	_check(cheats.run("summon").begins_with("failed:") and session.battle._living_foes().size() == 4,
		"summon refuses when fourth foe seat is occupied")
	said = cheats.run("hp f4 1")
	_check(int(session.battle.get_unit(str(fourth.id)).hp) == 1 and session.is_consistent(),
		"hp: fourth foe lowered through damage rules (%s)" % said)
	said = cheats.run("patch Pot Helm Command cotton_red_lint")
	_check(session._battle_sockets().get("warden", {}).get("warden_head_pot_helm_command", []) == ["cotton_red_lint"]
		and session.battle._s14_sockets == session._battle_sockets() and session.is_consistent(),
		"patch: one signature socket is active in current battle (%s)" % said)
	_check(cheats.run("status unknown rot 2").begins_with("failed:") and session.is_consistent(),
		"invalid figure refuses without damaging the session")
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
	session = app.stitched_run_session
	said = cheats.run("hp h1 2")
	_check(session.battle != null and int(session.battle._hero_at(1).hp) == 2 and session.is_consistent(),
		"hp: hero seat obeys requested HP (%s)" % said)
	said = cheats.run("status Warden guard 2")
	_check(int(session.battle.get_unit("warden").statuses.get("guard", 0)) == 2
		and session.is_consistent(), "status: full hero name accepts guard (%s)" % said)
	said = cheats.run("defeat")
	_check(said == "party defeated" and session.phase == "defeat" and session.battle == null
		and session.is_consistent(), "defeat: a real terminal loss is settled (%s)" % said)
	_check(cheats.run("defeat").begins_with("party defeated") and app.stitched_run_session.phase == "defeat",
		"defeat: command can also create and end a fresh battle")
	_finish()


func _finish() -> void:
	print("playtest_cheats_test: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)
