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
	for advertised in ["floor N", "defeat", "hp WHO N", "status WHO KIND N", "summon", "patch ABILITY ID"]:
		_check(cheats.run("help").contains(advertised), "help advertises %s" % advertised)
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
	var mounted_view: StitchedBattleScreen = app.stitched_run_battle
	var receipt_count := mounted_view.receipts.size()
	said = cheats.run("summon")
	_check(before_foes == 3 and session.battle._living_foes().size() == 4
		and not session.battle._foe_at(4).is_empty() and session.is_consistent(),
		"summon: fourth real foe joins the running battle (%s)" % said)
	_check(app.stitched_run_battle == mounted_view and mounted_view.receipts.size() == receipt_count + 1
		and str(mounted_view.last_receipt.get("action", "")) == "summon"
		and str(mounted_view.last_receipt.get("target", "")) == str(session.battle._foe_at(4).id),
		"summon keeps the mounted battle and records its actual fourth-seat arrival")
	await process_frame
	await process_frame
	var mounted_fight: StitchedCorridorFight = mounted_view.get_node_or_null("CorridorFight")
	_check(mounted_fight != null and mounted_fight._float_groups.has("foe_4")
		and mounted_fight._beats != null and mounted_fight._beats.is_running(),
		"summon floats a held fourth-seat arrival without rebuilding the view")
	var fourth: Dictionary = session.battle._foe_at(4)
	var before_status_receipts := mounted_view.receipts.size()
	said = cheats.run("status f4 bleed 2")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("bleed", 0)) == 2
		and session.is_consistent(), "status: new foe receives real bleed (%s)" % said)
	_check(app.stitched_run_battle == mounted_view
		and mounted_view.receipts.size() == before_status_receipts + 1
		and str(mounted_view.last_receipt.get("action", "")) == "cheat_status"
		and mounted_fight._float_events(mounted_view.last_receipt).has("foe_4"),
		"status setup preserves the mounted fight and queues the true status float")
	said = cheats.run("status f4 rot 3")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("rot", 0)) == 3
		and session.is_consistent(), "status: rot enters the real rule statuses (%s)" % said)
	said = cheats.run("status f4 stun 1")
	_check(int(session.battle.get_unit(str(fourth.id)).statuses.get("stun", 0)) == 1
		and session.is_consistent(), "status: stun enters the real rule statuses (%s)" % said)
	_check(cheats.run("summon").begins_with("failed:") and session.battle._living_foes().size() == 4,
		"summon refuses when fourth foe seat is occupied")
	var before_hp_receipts := mounted_view.receipts.size()
	said = cheats.run("hp f4 1")
	_check(int(session.battle.get_unit(str(fourth.id)).hp) == 1 and session.is_consistent(),
		"hp: fourth foe lowered through damage rules (%s)" % said)
	_check(app.stitched_run_battle == mounted_view
		and mounted_view.receipts.size() == before_hp_receipts + 1
		and str(mounted_view.last_receipt.get("action", "")) == "cheat_hp"
		and mounted_fight._float_events(mounted_view.last_receipt).has("foe_4"),
		"HP damage setup preserves the mounted fight and queues a true damage float")
	said = cheats.run("hp f4 2")
	_check(int(session.battle.get_unit(str(fourth.id)).hp) == 2 and session.is_consistent()
		and app.stitched_run_battle == mounted_view
		and mounted_fight._float_events(mounted_view.last_receipt).has("foe_4"),
		"HP healing setup keeps the fight and reports only actual recovered HP (%s)" % said)
	var before_patch_actor := session.battle.current_actor_id()
	var before_patch_receipts := mounted_view.receipts.size()
	var before_patch_stage := mounted_view.get_node_or_null("CorridorFight")
	said = cheats.run("patch Pot Helm Command cotton_red_lint")
	_check(session._battle_sockets().get("warden", {}).get("warden_head_pot_helm_command", []) == ["cotton_red_lint"]
		and session.battle._s14_sockets == session._battle_sockets() and session.is_consistent(),
		"patch: one signature socket is active in current battle (%s)" % said)
	_check(app.stitched_run_battle == mounted_view and mounted_view.get_node_or_null("CorridorFight") == before_patch_stage
		and mounted_view.receipts.size() == before_patch_receipts
		and session.battle.current_actor_id() == before_patch_actor,
		"patch: changing a socket retains the mounted fight, its turn and held receipts")
	_check(cheats.run("status unknown rot 2").begins_with("failed:") and session.is_consistent(),
		"invalid figure refuses without damaging the session")
	said = cheats.run("win")
	_check(said == "battle won" and session.phase == "map" and session.gold > gold_before and session.is_consistent(),
		"win: elite settles to the map with gold (%s)" % said)

	# A terminal HP shortcut must preserve the real damage float and its held
	# stage beat instead of freeing the battle before that blow is visible.
	cheats.run("fight normal")
	var final_view: StitchedBattleScreen = app.stitched_run_battle
	var final_foes: Array = session.battle._living_foes()
	for i in range(final_foes.size() - 1):
		session.battle._kill_foe(final_foes[i])
	var final_foe: Dictionary = final_foes.back()
	said = cheats.run("hp %s 0" % str(final_foe.id))
	_check(session.phase == "battle" and session.battle.is_over()
		and app.stitched_run_battle == final_view and final_view.last_receipt.get("action") == "cheat_hp",
		"terminal HP keeps the battle mounted and records its final blow (%s)" % said)
	await process_frame
	await process_frame
	await process_frame
	var final_stage: StitchedCorridorFight = final_view.get_node_or_null("CorridorFight")
	_check(final_stage != null and final_stage._beats != null and final_stage._beats.is_running()
		and session.phase == "battle" and final_stage._float_events(final_view.last_receipt).size() > 0,
		"terminal HP still shows its held damage cue before settlement")
	await create_timer(0.6).timeout
	_check(session.phase == "battle" and app.stitched_run_battle == final_view,
		"terminal HP does not cut away during the held damage pose")
	await create_timer(2.4).timeout
	_check(session.phase == "map" and session.battle == null and session.is_consistent(),
		"terminal HP settles after the held final blow")

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

	# The gold cheat must re-quote an already-open stall without rerolling stock.
	var stall_stock: Array = session.pending.stock.duplicate(true)
	var stall_rng := session.rng.state
	cheats.run("gold 0")
	var blocked := 0
	for action in session._actions:
		if action.id == "buy_patch" and not action.enabled:
			blocked += 1
	_check(blocked > 0 and session.is_consistent(), "gold 0 disables offers in the mounted stall")
	cheats.run("gold 250")
	var available := 0
	for action in session._actions:
		if action.id == "buy_patch" and action.enabled and not str(action.text).contains("need"):
			available += 1
	_check(available > 0 and session.is_consistent(), "gold 250 reprices the mounted stall immediately")
	_check(session.pending.stock == stall_stock and session.rng.state == stall_rng,
		"requoting the stall does not resample stock or consume RNG")

	cheats.run("shop")
	var peddler_stock: Dictionary = session.pending.peddler_stock.duplicate(true)
	var peddler_rng := session.rng.state
	cheats.run("gold 0")
	var part_blocked := false
	for action in session._actions:
		if action.id == "buy_part":
			part_blocked = not action.enabled
	_check(part_blocked and session.is_consistent(), "gold 0 disables the open Peddler part offer")
	cheats.run("gold 250")
	var part_available := false
	for action in session._actions:
		if action.id == "buy_part":
			part_available = action.enabled
	_check(part_available and session.is_consistent(), "gold 250 enables the same Peddler part offer")
	_check(session.pending.peddler_stock == peddler_stock and session.rng.state == peddler_rng,
		"requoting the Peddler preserves its sampled stock and RNG state")

	# A mounted event must not keep a stale unaffordable choice after gold changes,
	# nor replace its selected story or consume a second random event roll.
	cheats.run("event v3_copper_cicada_chapel")
	var event_id := str(session.pending.get("event_id", ""))
	var event_rng := session.rng.state
	cheats.run("gold 0")
	var incense_blocked := false
	for action in session._actions:
		if action.id == "purchase_incense_spools":
			incense_blocked = not action.enabled
	_check(event_id == "v3_copper_cicada_chapel" and incense_blocked
		and session.is_consistent(), "gold 0 disables incense in the mounted chapel")
	# An unrelated test-pinned event must not replace the current one during a quote refresh.
	StitchedRunSession.pinned_event_id = "needle_gate"
	cheats.run("gold 20")
	var incense_available := false
	for action in session._actions:
		if action.id == "purchase_incense_spools":
			incense_available = action.enabled
	_check(incense_available and session.is_consistent()
		and is_instance_valid(app.stitched_run_panel),
		"gold 20 re-enables the chapel purchase without reopening the event")
	_check(str(session.pending.get("event_id", "")) == event_id and session.rng.state == event_rng,
		"event re-quote preserves the selected event and the run RNG")
	_check(StitchedRunSession.pinned_event_id == "needle_gate",
		"event re-quote restores the debug-pinned event override")
	StitchedRunSession.pinned_event_id = ""

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
	# The first-floor recap must use the singular form, not "1 FLOORS REACHED".
	cheats.run("run 99")
	cheats.run("defeat")
	session = app.stitched_run_session
	var floor_caption := ""
	var visible_fray := false
	for candidate: Label in app.stitched_run_panel.find_children("*", "Label", true, false):
		if candidate.text.contains("FLOOR") and candidate.text.contains("REACHED"):
			floor_caption = candidate.text
		if candidate.is_visible_in_tree() and candidate.text.to_upper().contains("FRAY"):
			visible_fray = true
	_check(session.map.get_current_floor() == 1 and session.phase == "defeat" and not floor_caption.is_empty(),
		"defeat: a mounted first-floor recap is present")
	_check(floor_caption.contains("1 FLOOR REACHED") and not floor_caption.contains("1 FLOORS REACHED"),
		"first-floor defeat recap uses singular FLOOR")
	_check(not visible_fray, "disabled fray never appears in the terminal recap")
	_finish()


func _finish() -> void:
	print("playtest_cheats_test: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(1 if failures > 0 else 0)
