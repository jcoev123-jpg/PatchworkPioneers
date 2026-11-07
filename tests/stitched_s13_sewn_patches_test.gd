extends SceneTree
## Design v4 S13: sewn-on patches. Covers every part's thread, thread pairs and the whole cloth
## (torn patches count for nothing), starters wearing no set, break-in (sooner in the favoured
## slot), ill-fitting foe patches, the hidden bonus reaching a battle unit, the run session's
## wear record and fight-start fray, the Sewing Circle double-stitch, and the corridor hoops.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_threads()
	_sets()
	_break_in()
	_ill_fitting()
	_rules_bonus()
	_session_wear()
	_double_stitch()
	await _corridor_hoops()
	for failure in failures:
		printerr(failure)
	print("stitched_s13_sewn_patches_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _worn(id: String, torn: bool = false, tier: int = 1) -> Dictionary:
	return {"id": id, "tier": tier, "torn": torn}


func _warden(head: String, arms: String, torso: String, legs: String) -> Dictionary:
	return {"head": _worn(head), "arms": _worn(arms), "torso": _worn(torso), "legs": _worn(legs)}


func _threads() -> void:
	var book := StitchedSewnPatches.data()
	_check(book.get("threads", {}).size() >= 100, "every hero and foe part has a thread")
	var catalog: Dictionary = StitchedRunSession.start(3).catalog
	var missing: Array = []
	for id in book.get("threads", {}):
		if not catalog.has(id):
			missing.append(id)
		elif not str(book.threads[id]) in StitchedSewnPatches.THREADS:
			missing.append(id)
	_check(missing.is_empty(), "threads name real parts and real colours: %s" % [missing])
	for hero in ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]:
		_check(StitchedSewnPatches.favoured_slot(hero) in StitchedSewnPatches.SLOTS, "%s has a favoured slot" % hero)
	_check(StitchedSewnPatches.is_foe_patch("scissor_crab_claw_arm") and not StitchedSewnPatches.is_foe_patch("warden_arms_shield_catch"),
		"foe patches are told apart")
	for hero in StitchedRunSession.start(3).heroes:
		_check(StitchedSewnPatches.set_thread(hero.parts).is_empty() and StitchedSewnPatches.hidden_bonus(hero.id, hero.parts).is_empty(),
			"%s starts with no thread set" % hero.id)


func _sets() -> void:
	# Head and torso crimson, arms indigo, legs ash: one crimson pair.
	var parts := _warden("warden_head_pot_helm_bonk", "warden_arms_shield_catch", "warden_torso_buckle_rebound", "warden_legs_rim_toss")
	_check(StitchedSewnPatches.set_thread(parts) == "crimson" and not StitchedSewnPatches.whole_cloth(parts), "two crimson patches pair")
	_check(StitchedSewnPatches.hidden_bonus("warden", parts) == {"dmg": 1}, "a crimson pair adds a little damage")
	parts.head.torn = true
	_check(StitchedSewnPatches.set_thread(parts).is_empty() and StitchedSewnPatches.hidden_bonus("warden", parts).is_empty(),
		"a torn patch breaks the pair")
	var catalog: Dictionary = StitchedRunSession.start(3).catalog
	var cloth := {}
	for id in StitchedSewnPatches.data().threads:
		var slot := str(catalog.get(id, {}).get("slot", ""))
		if StitchedSewnPatches.thread_of(id) == "bone" and not cloth.has(slot) and not slot.is_empty():
			cloth[slot] = _worn(id)
	_check(cloth.size() == 4, "a bone patch exists for every slot")
	_check(StitchedSewnPatches.whole_cloth(cloth) and StitchedSewnPatches.set_thread(cloth) == "bone", "four bone patches are a whole cloth")
	var bone := {}
	for key in StitchedSewnPatches.data().whole_cloth_bonus.bone:
		bone[key] = int(StitchedSewnPatches.data().whole_cloth_bonus.bone[key])
	_check(StitchedSewnPatches.hidden_bonus("seamstress", cloth) == bone,
		"the whole cloth gives its own bonus, not the pair's")


func _break_in() -> void:
	var parts := _warden("warden_head_pot_helm_bonk", "warden_arms_shield_catch", "warden_torso_iron_challenge", "warden_legs_rim_toss")
	var wear := StitchedSewnPatches.wear_after_fight(parts, {})
	_check(wear.size() == 4 and wear.torso == {"id": "warden_torso_iron_challenge", "fights": 1}, "one fight starts the wear record")
	wear = StitchedSewnPatches.wear_after_fight(parts, wear)
	_check(wear.head.fights == 2, "a patch still worn counts up")
	_check(StitchedSewnPatches.broken_in("warden", "torso", parts.torso, wear), "the favoured slot breaks in after two fights")
	_check(not StitchedSewnPatches.broken_in("warden", "head", parts.head, wear), "other slots need three")
	_check(StitchedSewnPatches.hidden_bonus("warden", parts, wear) == {"max_hp": 2}, "a broken-in torso adds a little HP")
	wear = StitchedSewnPatches.wear_after_fight(parts, wear)
	_check(StitchedSewnPatches.hidden_bonus("warden", parts, wear) == {"acc": 2, "crit": 2, "max_hp": 2, "dodge": 2},
		"every slot is broken in after three fights")
	var swapped := parts.duplicate(true)
	swapped.head = _worn("warden_head_helmet_rattle")
	var fresh := StitchedSewnPatches.wear_after_fight(swapped, wear)
	_check(fresh.head.fights == 1 and fresh.torso.fights == 4, "a new patch starts over")
	_check(not StitchedSewnPatches.broken_in("warden", "head", swapped.head, wear), "a swapped patch is not broken in")
	parts.torso.torn = true
	_check(not StitchedSewnPatches.hidden_bonus("warden", parts, wear).has("max_hp"), "a torn patch loses its break-in")


func _ill_fitting() -> void:
	var parts := _warden("warden_head_pot_helm_bonk", "scissor_crab_claw_arm", "warden_torso_iron_challenge", "warden_legs_rim_toss")
	var fray := int(StitchedSewnPatches.data().ill_fitting_fray)
	_check(fray > 0 and StitchedSewnPatches.ill_fitting_fray("warden", parts) == fray, "a foe arm on the warden sits badly")
	_check(StitchedSewnPatches.ill_fitting_fray("seamstress", parts) == 0, "a foe arm in the seamstress's favoured slot fits")
	parts.torso = _worn("felt_bulwark_button_shield")
	_check(StitchedSewnPatches.ill_fitting_fray("warden", parts) == fray, "a foe torso in the warden's favoured slot fits")
	parts.arms.torn = true
	_check(StitchedSewnPatches.ill_fitting_fray("warden", parts) == 0, "a torn foe patch adds nothing")


## The first Fight of a run, entered from the map; null when this seed opens without one.
func _enter_fight(session: StitchedRunSession) -> bool:
	if not session.gift_offer.is_empty():
		session.choose_gift("", "", session.snapshot())
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			return session.enter(id, session.snapshot()) and session.phase == "battle"
	return false


func _win(session: StitchedRunSession) -> bool:
	# A test shortcut past the fight itself: the foes give up, then the session reseals.
	session.battle._outcome = "victory"
	session._seal()
	return session.settle_battle(session.battle)


func _rules_bonus() -> void:
	for seed_number in range(1, 60):
		var session := StitchedRunSession.start(seed_number)
		if not _enter_fight(session):
			continue
		var base: Dictionary = session.battle_config.duplicate(true)
		var plain := _warden("warden_head_pot_helm_bonk", "warden_arms_shield_catch", "warden_torso_iron_challenge", "warden_legs_rim_toss")
		var built := {}
		for name in ["plain", "worn", "pair"]:
			var config := base.duplicate(true)
			for hero in config.heroes:
				if hero.id == "warden":
					hero.parts = plain.duplicate(true)
					if name == "worn":
						hero["patch_wear"] = {"torso": {"id": "warden_torso_iron_challenge", "fights": 2}}
					elif name == "pair":
						hero.parts.legs = _worn("warden_legs_shield_toss")
			var made := StitchedRules.create(config)
			_check(bool(made.ok), "%s battle builds: %s" % [name, made.get("error", "")])
			if made.ok:
				built[name] = (made.battle as StitchedRules).get_unit("warden")
		if built.size() == 3:
			_check(int(built.worn.max_hp) == int(built.plain.max_hp) + 2, "a broken-in patch reaches the battle unit")
			_check(built.worn.get("patch_wear", {}).size() == 1, "the unit keeps its wear record")
			var legs_plain := StitchedParts.stat_at_tier(session.catalog["warden_legs_rim_toss"], 1)
			var legs_pair := StitchedParts.stat_at_tier(session.catalog["warden_legs_shield_toss"], 1)
			var expected := int(built.plain.dodge) - int(legs_plain.get("dodge", 0)) + int(legs_pair.get("dodge", 0)) + 4
			_check(int(built.pair.dodge) == expected, "an indigo pair reaches the battle unit's dodge")
		return
	_check(false, "a seed opens with a Fight")


func _session_wear() -> void:
	for seed_number in range(1, 120):
		var session := StitchedRunSession.start(seed_number)
		for hero in session.heroes:
			if hero.id == "warden":
				hero.parts.arms = _worn("scissor_crab_claw_arm")
		session._seal()
		if not _enter_fight(session):
			continue
		var fray := int(StitchedSewnPatches.data().ill_fitting_fray)
		_check(int(session.battle.get_unit("warden").fray) == fray, "an ill-fitting patch frays the doll at fight start")
		_check(int(session.battle.get_unit("seamstress").fray) == 0, "dolls in their own patches start calm")
		var first_max := int(session.battle.get_unit("warden").max_hp)
		_check(_win(session), "the first fight settles")
		var warden: Dictionary = session.heroes.filter(func(h): return h.id == "warden")[0]
		_check(warden.get("patch_wear", {}).size() == 4 and int(warden.patch_wear.arms.fights) == 1, "a settled fight records the wear")
		if not _enter_fight(session):
			continue
		_check(_win(session), "the second fight settles")
		warden = session.heroes.filter(func(h): return h.id == "warden")[0]
		_check(int(warden.patch_wear.torso.fights) == 2, "the wear keeps counting")
		if not _enter_fight(session):
			continue
		var torso_bonus := int(StitchedSewnPatches.data().broken_in_bonus.torso.get("max_hp", 0))
		_check(int(session.battle.get_unit("warden").max_hp) == first_max + torso_bonus,
			"the third fight's warden has a broken-in torso")
		return
	_check(false, "a seed opens with three Fights in a row")


func _double_stitch() -> void:
	var session := StitchedRunSession.start(4)
	var warden: Dictionary = session.heroes.filter(func(h): return h.id == "warden")[0]
	var head_id := str(warden.parts.head.id)
	session.satchel = [{"id": head_id, "slot": "head", "tier": 1, "torn": false},
		{"id": "warden_head_helmet_rattle" if head_id != "warden_head_helmet_rattle" else "warden_head_pot_helm_bonk",
			"slot": "head", "tier": 1, "torn": false}]
	session._actions.clear()
	session._add_double_stitches(session._roster())
	var offers: Array = session._actions.filter(func(a): return a.id == "double_stitch")
	_check(offers.size() == 1 and offers[0].arguments == ["warden", "head", 0] and offers[0].enabled,
		"only a matching spare offers a double-stitch")
	var result := session._double_stitch("warden", "head", 0)
	_check(bool(result.ok) and result.heroes[0].parts.head.tier == 2 and result.satchel.size() == 1,
		"double-stitching raises the tier and uses the spare")
	session.satchel[0].tier = 2
	_check(session._double_stitch("warden", "head", 0).heroes[0].parts.head.tier == 3, "the better of the two sets the tier")
	_check(not session._double_stitch("warden", "head", 1).ok, "a different part cannot be double-stitched")
	_check(not session._double_stitch("seamstress", "head", 0).ok, "the spare must match that doll's patch")
	warden.parts.head.tier = 3
	session._actions.clear()
	session._add_double_stitches(session._roster())
	_check(session._actions.filter(func(a): return a.id == "double_stitch").is_empty(), "a tier III patch is not offered")
	warden.parts.head.tier = 1
	warden.parts.head.torn = true
	_check(not session._double_stitch("warden", "head", 0).ok, "a torn patch must be mended first")


func _corridor_hoops() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	screen.begin(StitchedBattleScreen.read_preview())
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	for step in range(20):
		if screen.battle.current_side() == "hero":
			break
		screen.battle.pass_turn()
	fight.refresh()
	_check(fight.thread_knot != null and fight.thread_knot.name == "ThreadKnot", "the name plate has a thread knot")
	for slot in StitchedSewnPatches.SLOTS:
		var button: Node = fight.part_buttons.get(slot)
		_check(button != null and button.has_node("Patch") and button.has_node("Border") and button.has_node("Frayed"),
			"the %s hoop has patch, border and frayed layers" % slot)
	screen.queue_free()
	await process_frame
