extends SceneTree
## Design v4 S13: the sewn-patch catalog is read-only for callers. data() hands
## out a detached deep copy, so scribbling over threads, favoured slots, pair,
## whole-cloth and break-in bonuses or the ill-fitting fray inside a result can
## never reach the cached rules the fights use. Cold and warm cache reads, torn
## and untorn patches, and the real StitchedRules and run-session paths all
## still project the shipped values from data/sewn_patches.json.

var checks := 0
var failures: Array[String] = []


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	# Legacy rule kept under test; it is switched off in the live game (owner 11-10).
	StitchedRules.fray_enabled = true
	_run.call_deferred()


func _run() -> void:
	var authored := _authored()
	if authored.is_empty():
		printerr("stitched_s13_sewn_catalog_detachment_test: authored catalog unreadable")
		quit(1)
		return
	_check(authored.has("threads") and authored.has("favoured") and authored.has("pair_bonus") and authored.has("whole_cloth_bonus") and authored.has("broken_in_bonus") and authored.has("ill_fitting_fray") and authored.has("foe_patches"), "the authored catalog carries every S13 rule")
	_cold_read_corruption()
	_warm_read_corruption()
	_torn_rules(authored)
	_service_projection(authored)
	for failure in failures:
		printerr(failure)
	print("stitched_s13_sewn_catalog_detachment_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## The shipped catalog, re-read straight from the authored JSON: independent of the class cache.
func _authored() -> Dictionary:
	var file := FileAccess.open("res://data/sewn_patches.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	return parsed if parsed is Dictionary else {}


func _worn(id: String, torn: bool = false) -> Dictionary:
	return {"id": id, "tier": 1, "torn": torn}


## Corrupt every nested rule a caller could reach through a data() result.
func _corrupt(book: Dictionary) -> void:
	book["threads"]["warden_head_pot_helm_bonk"] = "ash"
	book["threads"].erase("warden_torso_iron_challenge")
	book["favoured"]["warden"] = "head"
	book["favoured"].erase("seamstress")
	book["pair_bonus"]["crimson"] = {"dmg": 99}
	book["whole_cloth_bonus"]["bone"] = {"max_hp": 99, "prot": 99}
	book["broken_in_bonus"]["torso"] = {"max_hp": 99}
	book["ill_fitting_fray"] = 99
	book["foe_patches"].append("warden_arms_shield_catch")
	book["foe_patches"].erase("scissor_crab_claw_arm")


## A fresh process's first catalog read loads the cache; a mutated copy of that
## cold read must not dent the next read.
func _cold_read_corruption() -> void:
	var cold := StitchedSewnPatches.data()
	_corrupt(cold)
	_check(str(cold["threads"].get("warden_head_pot_helm_bonk", "")) == "ash" and int(cold["ill_fitting_fray"]) == 99, "the scribbled copy really diverged")
	_assert_pristine("a cold")


## Warm reads are separate copies: corrupting one leaves the other and every
## later read shipped.
func _warm_read_corruption() -> void:
	var first := StitchedSewnPatches.data()
	var second := StitchedSewnPatches.data()
	_corrupt(first)
	_check(second == _authored(), "two warm reads share no nested state")
	_corrupt(second)
	_assert_pristine("a warm")


## Every catalog read and helper lookup still shows the shipped values.
func _assert_pristine(label: String) -> void:
	var authored := _authored()
	var fresh := StitchedSewnPatches.data()
	_check(fresh == authored, "%s mutated read leaves the catalog equal to the authored JSON" % label)
	_check(str(fresh["threads"].get("warden_head_pot_helm_bonk", "")) == str(authored["threads"].get("warden_head_pot_helm_bonk", "")), "%s read keeps the authored thread colours" % label)
	_check(fresh["threads"].has("warden_torso_iron_challenge"), "%s read brings erased threads back" % label)
	_check(str(fresh["favoured"].get("warden", "")) == str(authored["favoured"].get("warden", "")), "%s read keeps the authored favoured slots" % label)
	_check(fresh["pair_bonus"]["crimson"] == authored["pair_bonus"]["crimson"], "%s read keeps the shipped pair bonus" % label)
	_check(fresh["whole_cloth_bonus"]["bone"] == authored["whole_cloth_bonus"]["bone"], "%s read keeps the shipped whole-cloth bonus" % label)
	_check(fresh["broken_in_bonus"]["torso"] == authored["broken_in_bonus"]["torso"], "%s read keeps the shipped break-in bonus" % label)
	_check(int(fresh["ill_fitting_fray"]) == int(authored["ill_fitting_fray"]), "%s read keeps the shipped fray" % label)
	_check(fresh["foe_patches"] == authored["foe_patches"], "%s read keeps the shipped foe patches" % label)
	_check(StitchedSewnPatches.thread_of("warden_head_pot_helm_bonk") == str(authored["threads"]["warden_head_pot_helm_bonk"]), "%s thread_of still reads the shipped thread" % label)
	_check(StitchedSewnPatches.favoured_slot("warden") == str(authored["favoured"]["warden"]), "%s favoured_slot still reads the shipped favourite" % label)
	_check(StitchedSewnPatches.is_foe_patch("scissor_crab_claw_arm") and not StitchedSewnPatches.is_foe_patch("warden_arms_shield_catch"), "%s foe patches are still told apart" % label)


## After every mutation attempt the S13 arithmetic still equals the shipped
## rules, and torn patches still count for nothing.
func _torn_rules(authored: Dictionary) -> void:
	var parts := {"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_buckle_rebound"), "legs": _worn("warden_legs_rim_toss")}
	_check(StitchedSewnPatches.set_thread(parts) == "crimson" and not StitchedSewnPatches.whole_cloth(parts), "the crimson pair still pairs")
	_check(StitchedSewnPatches.hidden_bonus("warden", parts) == _ints(authored["pair_bonus"]["crimson"]), "a pair still gives the shipped pair bonus")
	parts["head"]["torn"] = true
	_check(StitchedSewnPatches.set_thread(parts).is_empty() and StitchedSewnPatches.hidden_bonus("warden", parts).is_empty(), "a torn patch still breaks the pair")
	parts["head"]["torn"] = false
	var cloth := {"head": _worn("warden_head_helmet_rattle"), "arms": _worn("scarecrow_arms_fork_jab"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("lantern_monk_legs_pole_shelter")}
	_check(StitchedSewnPatches.whole_cloth(cloth) and StitchedSewnPatches.set_thread(cloth) == "bone", "four untorn bone patches still make a whole cloth")
	_check(StitchedSewnPatches.hidden_bonus("warden", cloth) == _ints(authored["whole_cloth_bonus"]["bone"]), "the whole cloth still gives its shipped bonus, not the pair's")
	cloth["head"]["torn"] = true
	_check(StitchedSewnPatches.set_thread(cloth) == "bone" and StitchedSewnPatches.hidden_bonus("warden", cloth) == _ints(authored["pair_bonus"]["bone"]), "three untorn patches still fall back to the shipped pair bonus")
	cloth["arms"]["torn"] = true
	cloth["torso"]["torn"] = true
	_check(StitchedSewnPatches.set_thread(cloth).is_empty() and StitchedSewnPatches.hidden_bonus("warden", cloth).is_empty(), "torn patches still leave no thread set")
	cloth["head"]["torn"] = false
	cloth["arms"]["torn"] = false
	cloth["torso"]["torn"] = false
	var wear := {"head": {"id": "warden_head_helmet_rattle", "fights": int(authored["broken_in_fights"]) - 1},"torso": {"id": "warden_torso_iron_challenge", "fights": int(authored["broken_in_fights_favoured"])}}
	_check(StitchedSewnPatches.broken_in("warden", "torso", cloth["torso"], wear), "the favoured slot still breaks in at the shipped threshold")
	_check(not StitchedSewnPatches.broken_in("warden", "head", cloth["head"], wear), "other slots still need the full shipped threshold")
	var stacked := _ints(authored["whole_cloth_bonus"]["bone"])
	_add_ints(stacked, _ints(authored["broken_in_bonus"]["torso"]))
	_check(StitchedSewnPatches.hidden_bonus("warden", cloth, wear) == stacked, "the whole cloth and break-in bonuses still stack")
	var torn_expected := _ints(authored["pair_bonus"]["bone"])
	cloth["torso"]["torn"] = true
	_check(StitchedSewnPatches.hidden_bonus("warden", cloth, wear) == torn_expected, "a torn patch still loses its break-in")
	var foe := {"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("scissor_crab_claw_arm"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss")}
	_check(StitchedSewnPatches.ill_fitting_fray("warden", foe) == int(authored["ill_fitting_fray"]), "an ill-fitting foe patch still frays at the shipped value")
	foe["torso"] = _worn("felt_bulwark_button_shield")
	_check(StitchedSewnPatches.ill_fitting_fray("warden", foe) == int(authored["ill_fitting_fray"]), "a foe patch in the favoured slot still fits")
	foe["arms"]["torn"] = true
	_check(StitchedSewnPatches.ill_fitting_fray("warden", foe) == 0, "a torn foe patch still adds nothing")


## The first Fight of a run, entered from the map; false when this seed opens without one.
func _enter_fight(session: StitchedRunSession) -> bool:
	if not session.gift_offer.is_empty():
		session.choose_gift("", "", session.snapshot())
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			return session.enter(id, session.snapshot()) and session.phase == "battle"
	return false


## The real battle service and run session still project the shipped rules
## after every mutation attempt above.
func _service_projection(authored: Dictionary) -> void:
	for seed_number in range(1, 60):
		var session := StitchedRunSession.start(seed_number)
		for hero in session.heroes:
			if hero.id == "warden":
				hero.parts.arms = _worn("scissor_crab_claw_arm")
		session._seal()
		if not _enter_fight(session):
			continue
		_check(int(session.battle.get_unit("warden").fray) == int(authored["ill_fitting_fray"]), "the real fight start still frays an ill-fitting patch by the shipped value")
		_check(int(session.battle.get_unit("seamstress").fray) == 0, "dolls in their own patches still start calm")
		var config := session.battle_config.duplicate(true)
		var plain := {"head": _worn("warden_head_pot_helm_bonk"), "arms": _worn("warden_arms_shield_catch"), "torso": _worn("warden_torso_iron_challenge"), "legs": _worn("warden_legs_rim_toss")}
		var built := {}
		for name in ["plain", "worn", "pair"]:
			var variant := config.duplicate(true)
			for hero in variant.heroes:
				if hero.id == "warden":
					hero.parts = plain.duplicate(true)
					if name == "worn":
						hero["patch_wear"] = {"torso": {"id": "warden_torso_iron_challenge", "fights": int(authored["broken_in_fights_favoured"])}}
					elif name == "pair":
						hero.parts.legs = _worn("warden_legs_shield_toss")
			var made := StitchedRules.create(variant)
			_check(bool(made.ok), "%s battle still builds: %s" % [name, made.get("error", "")])
			if made.ok:
				built[name] = (made.battle as StitchedRules).get_unit("warden")
		if built.size() == 3:
			_check(int(built["worn"].max_hp) == int(built["plain"].max_hp) + int(authored["broken_in_bonus"]["torso"].get("max_hp", 0)), "the real battle unit still carries the shipped break-in bonus")
			var legs_plain := StitchedParts.stat_at_tier(session.catalog["warden_legs_rim_toss"], 1)
			var legs_pair := StitchedParts.stat_at_tier(session.catalog["warden_legs_shield_toss"], 1)
			var expected := int(built["plain"].dodge) - int(legs_plain.get("dodge", 0)) + int(legs_pair.get("dodge", 0)) + int(authored["pair_bonus"]["indigo"].get("dodge", 0))
			_check(int(built["pair"].dodge) == expected, "the real battle unit still carries the shipped indigo pair bonus")
		else:
			_check(false, "all three battle variants still build")
		return
	_check(false, "a seed opens with a Fight")


func _ints(bonus: Dictionary) -> Dictionary:
	var ints := {}
	for key in bonus:
		ints[key] = int(bonus[key])
	return ints


func _add_ints(totals: Dictionary, bonus: Dictionary) -> void:
	for key in bonus:
		totals[key] = int(totals.get(key, 0)) + int(bonus[key])
