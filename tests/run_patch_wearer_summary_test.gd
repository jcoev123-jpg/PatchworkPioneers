extends SceneTree
## Deterministic headless regression for the scene-free patch wearer summary.
## Every fixture is built from the shipped catalogs and the real services;
## no on-disk JSON is changed and no rule is re-implemented here.

var failures: Array[String] = []
var checks := 0

const ATTACK_CATALOG := "res://data/patches/m04_attack_patches.json"
const COAT_CATALOG := "res://data/patches/m04_coat_patches.json"
const SLOT_CATALOG := "res://data/patches/initial_patch_slots.json"
const M05_HEAD_CATALOG := "res://data/patches/m05_head_patches.json"
const M05_ARM_CATALOG := "res://data/patches/m05_arm_support_patches.json"
const M05_ATTACK_CATALOG := "res://data/patches/m05_attack_patches.json"
const M05_COAT_CATALOG := "res://data/patches/m05_coat_patches.json"
const EYE_TEXT := "first successful attack each combat also applies Exposed 1"
const ARM_TEXT := "+1 damage on that wearer's damaging cards"
const COAT_TEXT := "+6 maximum HP"
const PADDED_VEST_TEXT := "+4 maximum HP"
const DOUBLE_QUILT_TEXT := "+8 maximum HP"
const SCRAP_LINED_VEST_TEXT := "+3 maximum HP"
const WOOL_PATCH_CLOAK_TEXT := "+5 maximum HP"
const CHAIN_STITCHED_COAT_TEXT := "+7 maximum HP"
const REINFORCED_PATCHCOAT_TEXT := "+9 maximum HP"
const THICK_FELT_MANTLE_TEXT := "+10 maximum HP"
const M05_BLEED_TEXT := "+1 Bleed on eligible Bleed cards owned by this living wearer only"
const M05_EXPOSED_TEXT := "+1 Exposed on eligible Exposed cards owned by this living wearer only"
const M05_WEAK_TEXT := "+1 Weak on eligible Weak cards owned by this living wearer only"
const M05_HEAD_BLOCK_TEXT := "+2 Block on eligible Block cards owned by this living wearer only"
const M05_ARM_BLOCK_TEXT := "+2 Block on eligible Block cards owned by this living wearer only"
const M05_UNRAVEL_TEXT := "+1 Unravel on eligible Unravel cards owned by this living wearer only"
const M05_FRAYFINDER_TEXT := "+2 Unravel once per player turn on this living wearer's first single-target attack hit, only against a target already at least 1/2 of its current Unravel threshold (not on every attack)"
const BORROWED_BUTTON_TEXT := "Once per combat, when another living hero's committed card or stitched half restores at least 1 HP to this living wearer, gain 3 Block."


func _badge_text() -> String:
	return "+%d opening Block for this living wearer (stacks with innate Block)" % CombatShopPatchRules.OPENING_BLOCK_BONUS


func _spool_text() -> String:
	return "+%d healing on positive-heal cards owned by this living wearer only" % CombatShopPatchRules.HEALING_CARD_BONUS


func _initialize() -> void:
	_test_catalog_backed_definitions()
	_test_full_summary()
	_test_slot_only_patches()
	_test_shop_torn_activation()
	_test_unknown_patch()
	_test_torn_and_active_flags()
	_test_replacement_and_readonly()
	_test_rest_resew_summary()
	_test_rejections()
	_test_sew_previews()
	_test_detachment_and_isolation()
	_test_coat_powers_lifecycle_and_previews()
	_test_new_coat_patches_lifecycle()
	_test_m05_coat_patches_lifecycle()
	_test_borrowed_button_readout()
	_test_m05_head_and_arm_summary()
	_test_m05_torn_and_replacement_previews()
	_test_m05_authority_fail_closed()
	if failures.is_empty():
		print("run_patch_wearer_summary_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		print("run_patch_wearer_summary_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _json(path: String) -> Variant:
	var source := FileAccess.get_file_as_string(path)
	_check(not source.is_empty(), path + " is readable")
	if source.is_empty():
		return null
	return JSON.parse_string(source)


func _catalogs() -> Dictionary:
	var attack: Variant = _json(ATTACK_CATALOG)
	var coat: Variant = _json(COAT_CATALOG)
	var initial: Variant = _json(SLOT_CATALOG)
	var m05_head: Variant = _json(M05_HEAD_CATALOG)
	var m05_arm: Variant = _json(M05_ARM_CATALOG)
	var m05_attack: Variant = _json(M05_ATTACK_CATALOG)
	var m05_coat: Variant = _json(M05_COAT_CATALOG)
	if typeof(attack) != TYPE_ARRAY or typeof(coat) != TYPE_ARRAY \
			or typeof(initial) != TYPE_ARRAY or typeof(m05_head) != TYPE_ARRAY \
			or typeof(m05_arm) != TYPE_ARRAY or typeof(m05_attack) != TYPE_ARRAY \
			or typeof(m05_coat) != TYPE_ARRAY:
		_check(false, "the seven shipped patch catalogs are readable arrays")
		return {}
	return {"attack": attack, "coat": coat, "initial": initial,
		"m05_head": m05_head, "m05_arm": m05_arm, "m05_attack": m05_attack,
		"m05_coat": m05_coat}


## Every shipped record of one ID, so a duplicate can never pass unnoticed.
func _records(catalogs: Dictionary, id: String) -> Array:
	var found: Array = []
	for key in ["attack", "coat", "initial", "m05_head", "m05_arm", "m05_attack", "m05_coat"]:
		for entry in catalogs.get(key, []):
			if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
				found.append(entry)
	return found


## The wardrobe's strict two-field identity/slot records, projected by ID
## from the shipped catalogs instead of hand-written fixture metadata.
func _projected_definitions(catalogs: Dictionary) -> Array:
	var definitions: Array = []
	for key in ["initial", "attack", "coat", "m05_head", "m05_arm", "m05_attack", "m05_coat"]:
		for entry in catalogs.get(key, []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id: Variant = entry.get("id")
			var slot: Variant = entry.get("slot")
			if typeof(id) != TYPE_STRING or typeof(slot) != TYPE_STRING:
				continue
			definitions.append({"id": id, "slot": slot})
	return definitions


## A copy of the shipped catalogs with one authored field changed.
func _with_field(catalogs: Dictionary, key: String, id: String,
		field: String, value: Variant) -> Dictionary:
	var copy: Dictionary = catalogs.duplicate(true)
	for entry in copy.get(key, []):
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
			entry[field] = value
	return copy


## A copy of the shipped catalogs with one authored field removed.
func _without_field(catalogs: Dictionary, key: String, id: String,
		field: String) -> Dictionary:
	var copy: Dictionary = catalogs.duplicate(true)
	for entry in copy.get(key, []):
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
			entry.erase(field)
	return copy


## A copy of the shipped catalogs with one authored record removed.
func _without_record(catalogs: Dictionary, key: String, id: String) -> Dictionary:
	var copy: Dictionary = catalogs.duplicate(true)
	var kept: Array = []
	for entry in copy.get(key, []):
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
			continue
		kept.append(entry)
	copy[key] = kept
	return copy


## A copy of the shipped catalogs with one authored record present twice.
func _with_duplicate_record(catalogs: Dictionary, key: String, id: String) -> Dictionary:
	var copy: Dictionary = catalogs.duplicate(true)
	var entries: Array = []
	for entry in copy.get(key, []):
		entries.append(entry)
		if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
			entries.append(entry.duplicate(true))
	copy[key] = entries
	return copy


func _party() -> Array:
	var authored: Variant = _json("res://data/heroes/starter_party.json")
	_check(typeof(authored) == TYPE_ARRAY and authored.size() == 3,
		"the authored starter party has three heroes")
	if typeof(authored) != TYPE_ARRAY or authored.size() != 3:
		return []
	var definitions: Array = []
	for hero in authored:
		definitions.append({"id": hero["id"], "max_hp": int(hero["max_hp"]),
			"art_path": hero.get("art_path", "")})
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "CombatParty accepts the real starter definitions")
	if not party.is_valid():
		return []
	var heroes: Array = party.get_heroes()
	_check(heroes[0]["id"] == "warden" and heroes[0]["position"] == 1
		and heroes[0]["hp"] == 40 and heroes[0]["max_hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["position"] == 2
		and heroes[1]["hp"] == 30 and heroes[1]["max_hp"] == 30
		and heroes[2]["id"] == "tinker" and heroes[2]["position"] == 3
		and heroes[2]["hp"] == 26 and heroes[2]["max_hp"] == 26,
		"the authored hero identities positions and HP are real preconditions")
	return heroes


func _fixture(scraps: int = 2) -> Dictionary:
	var catalogs := _catalogs()
	if catalogs.is_empty():
		return {}
	var heroes := _party()
	if heroes.is_empty():
		return {}
	var definitions := _projected_definitions(catalogs)
	var owned: Array = []
	for record in definitions:
		if not owned.has(record["id"]):
			owned.append(record["id"])
	var wardrobe := RunPatchWardrobe.new(heroes, owned, definitions, scraps, 170,
		["warden_strike", "seamstress_prick"], 8197)
	if not wardrobe.is_valid():
		_check(false, "the catalog projected wardrobe is a valid real ledger")
		return {}
	return {"heroes": heroes, "wardrobe": wardrobe, "catalogs": catalogs,
		"definitions": definitions}


func _test_catalog_backed_definitions() -> void:
	var catalogs := _catalogs()
	if catalogs.is_empty():
		return
	# The records this readout supports are located by ID, never by a total.
	var expectations := {
		"button_eye": {"slot": "HEAD", "effect": "first_attack_exposed", "amount": 1},
		"pincushion_arm": {"slot": "ARM", "effect": "card_attack_bonus", "amount": 1},
		"quilted_coat": {"slot": "COAT", "max_hp_bonus": 6},
		"padded_vest": {"slot": "COAT", "max_hp_bonus": 4},
		"double_quilt_coat": {"slot": "COAT", "max_hp_bonus": 8},
		"scrap_lined_vest": {"slot": "COAT", "max_hp_bonus": 3},
		"wool_patch_cloak": {"slot": "COAT", "max_hp_bonus": 5},
		"chain_stitched_coat": {"slot": "COAT", "max_hp_bonus": 7},
		"reinforced_patchcoat": {"slot": "COAT", "max_hp_bonus": 9},
		"thick_felt_mantle": {"slot": "COAT", "max_hp_bonus": 10},
		"stitched_badge": {"slot": "HEAD"},
		"spare_spool": {"slot": "ARM"},
		"bloodstitch_bonnet": {"slot": "HEAD", "effect": "card_bleed_bonus", "amount": 1},
		"button_glass_visor": {"slot": "HEAD", "effect": "card_exposed_bonus", "amount": 1},
		"stern_seam_cap": {"slot": "HEAD", "effect": "card_weak_bonus", "amount": 1},
		"reinforced_browband": {"slot": "HEAD", "effect": "card_block_bonus", "amount": 2},
		"hemguard_cuff": {"slot": "ARM", "effect": "card_block_bonus", "amount": 2},
		"red_bobbin_cuff": {"slot": "ARM", "effect": "card_bleed_bonus", "amount": 1},
		"loose_thread_glove": {"slot": "ARM", "effect": "card_unravel_bonus", "amount": 1},
		"frayfinder_mitt": {"slot": "ARM",
			"effect": "first_single_target_half_unravel_attack_bonus", "amount": 2,
			"minimum_unravel_numerator": 1, "minimum_unravel_denominator": 2,
			"once_per_player_turn": true, "hit_number": 1, "target_kind": "enemy_single"},
		"borrowed_button": {"slot": "COAT",
			"effect": "other_hero_committed_heal_block", "heal_threshold": 1,
			"block": 3, "uses_per_combat": 1},
	}
	for id in expectations:
		var records := _records(catalogs, id)
		_check(records.size() == 1, "exactly one shipped record authors " + id)
		if records.size() != 1:
			continue
		var record: Dictionary = records[0]
		var expected: Dictionary = expectations[id]
		for field in expected:
			_check(record.get(field) == expected[field],
				id + " authors " + field + " " + str(expected[field]))
		if id == "stitched_badge" or id == "spare_spool":
			_check(not record.has("effect") and not record.has("amount")
				and not record.has("max_hp_bonus"),
				id + " ships slot metadata only")
	# Shop powers come from combat rules, not the slot-only authored records.
	_check(CombatShopPatchRules.EFFECTS["stitched_badge"] == {
		"slot": "HEAD", "effect": "opening_block_bonus",
		"amount": CombatShopPatchRules.OPENING_BLOCK_BONUS},
		"combat authority specifies the badge slot and opening Block")
	_check(CombatShopPatchRules.EFFECTS["spare_spool"] == {
		"slot": "ARM", "effect": "healing_card_bonus",
		"amount": CombatShopPatchRules.HEALING_CARD_BONUS},
		"combat authority specifies the spool slot and healing")
	# The wardrobe records are projected from those shipped catalogs.
	var definitions := _projected_definitions(catalogs)
	_check(definitions.size() >= 5, "the shipped catalogs project the named records")
	for record in definitions:
		_check(record.size() == 2 and record.has("id") and record.has("slot"),
			"a projected wardrobe record carries exactly id and slot")
	var f := _fixture()
	if f.is_empty():
		return
	var snapshot: Dictionary = f.wardrobe.get_snapshot()
	for record in definitions:
		_check(snapshot.get("definitions", {}).get(record["id"]) == record["slot"],
			"the wardrobe definition for " + str(record["id"]) + " matches the shipped slot")


func _test_full_summary() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var heroes: Array = f.heroes
	_check(w.sew("button_eye", "warden", "HEAD", "sew_eye", w.get_snapshot()).ok,
		"Button Eye is sewn onto the Warden HEAD")
	_check(w.sew("pincushion_arm", "seamstress", "ARM", "sew_arm", w.get_snapshot()).ok,
		"Pincushion Arm is sewn onto the Seamstress ARM")
	_check(w.sew("quilted_coat", "tinker", "COAT", "sew_coat", w.get_snapshot()).ok,
		"Quilted Coat is sewn onto the Tinker COAT")
	var torn := RunTornMending.new(heroes)
	_check(torn.is_valid(), "a real torn ledger accepts the authored party")
	var torn_state := torn.read_state()
	var result := RunPatchWearerSummary.summarize(w, torn_state)
	_check(result.get("ok") == true and result.get("heroes") is Array,
		"a valid wardrobe and ledger publish a summary")
	if result.get("ok") != true:
		return
	_check(result.heroes.size() == 3, "the summary publishes exactly three heroes")
	var identities := [["warden", 1], ["seamstress", 2], ["tinker", 3]]
	var expected := [
		[["button_eye", true, EYE_TEXT], ["", false, ""], ["", false, ""]],
		[["", false, ""], ["pincushion_arm", true, ARM_TEXT], ["", false, ""]],
		[["", false, ""], ["", false, ""], ["quilted_coat", true, COAT_TEXT]],
	]
	var projection := w.project_active(torn_state)
	_check(projection.get("ok") == true,
		"the independent wardrobe projection succeeds")
	for i in range(3):
		var hero_id: String = result.heroes[i]["id"]
		_check(hero_id == identities[i][0]
			and result.heroes[i]["position"] == identities[i][1]
			and result.heroes[i]["hp"] == heroes[i]["hp"],
			hero_id + " keeps its exact identity position and HP")
		var slots: Array = result.heroes[i]["slots"]
		_check(slots.size() == 3, hero_id + " publishes HEAD ARM and COAT")
		if slots.size() != 3:
			continue
		var active_ids: Array = projection.get("active", {}).get(hero_id, [])
		for s in range(3):
			var record: Dictionary = slots[s]
			var wanted: Array = expected[i][s]
			_check(record["slot"] == ["HEAD", "ARM", "COAT"][s]
				and record["patch_id"] == wanted[0]
				and record["active"] == wanted[1]
				and record["rules_text"] == wanted[2],
				hero_id + " " + ["HEAD", "ARM", "COAT"][s] + " publishes its exact slot record")
			var projected_active := false
			if record["patch_id"] != "" and heroes[i]["hp"] > 0:
				projected_active = active_ids.has(record["patch_id"])
			_check(record["active"] == projected_active,
				hero_id + " " + record["slot"] + " activation matches the independent projection")


func _test_slot_only_patches() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("stitched_badge", "warden", "HEAD", "sew_badge", w.get_snapshot()).ok,
		"Stitched Badge is sewn onto the Warden HEAD")
	_check(w.sew("spare_spool", "seamstress", "ARM", "sew_spool", w.get_snapshot()).ok,
		"Spare Spool is sewn onto the Seamstress ARM")
	var torn := RunTornMending.new(f.heroes)
	var result := RunPatchWearerSummary.summarize(w, torn.read_state())
	_check(result.get("ok") == true, "slot-only patches publish a summary")
	if result.get("ok") != true:
		return
	var badge: Dictionary = result.heroes[0]["slots"][0]
	_check(badge["slot"] == "HEAD" and badge["patch_id"] == "stitched_badge"
		and badge["active"] == true and badge["rules_text"] == _badge_text(),
		"badge shows the genuine +3 opening Block")
	var spool: Dictionary = result.heroes[1]["slots"][1]
	_check(spool["slot"] == "ARM" and spool["patch_id"] == "spare_spool"
		and spool["active"] == true and spool["rules_text"] == _spool_text(),
		"spool shows genuine +2 owned positive-heal card effect")
	var combat := CombatShopPatchRules.new()
	_check(combat.bind_wardrobe(w, torn, w.get_snapshot(), torn.read_state()),
		"actual combat authority binds to same live wardrobe")
	_check(combat.project_opening_block("warden") == CombatStartingBlock.BLOCK_AMOUNT
			+ CombatShopPatchRules.OPENING_BLOCK_BONUS
		and combat.opening_block_bonus("seamstress") == 0
		and combat.healing_card_bonus("seamstress", "seamstress_mend")
			== CombatShopPatchRules.HEALING_CARD_BONUS
		and combat.healing_card_bonus("seamstress", "seamstress_prick") == 0
		and combat.healing_card_bonus("seamstress", "tinker_tune_up") == 0
		and combat.healing_card_bonus("warden", "seamstress_mend") == 0,
		"real bonus is Warden 6+3 and positive owner-heal only")


func _test_unknown_patch() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	var w := RunPatchWardrobe.new(f.heroes, ["future_unwritten_patch"],
		[{"id": "future_unwritten_patch", "slot": "ARM"}], 2, 170,
		["warden_strike"], 8197)
	_check(w.is_valid() and w.sew("future_unwritten_patch", "tinker", "ARM",
		"future_sew", w.get_snapshot()).ok, "unknown-but-owned patch sewn in real ledger")
	var torn := RunTornMending.new(f.heroes)
	var result := RunPatchWearerSummary.summarize(w, torn.read_state())
	_check(result.ok and result.heroes[2].slots[1].patch_id == "future_unwritten_patch"
		and result.heroes[2].slots[1].active
		and result.heroes[2].slots[1].rules_text == "",
		"genuinely unknown patch remains visible without invented power")


func _test_shop_torn_activation() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("stitched_badge", "warden", "HEAD", "shop_badge", w.get_snapshot()).ok
		and w.sew("spare_spool", "seamstress", "ARM", "shop_spool", w.get_snapshot()).ok,
		"both Shop patches equipped before battle")
	var torn := RunTornMending.new(f.heroes)
	var original: Array = torn.read_state().heroes
	var ending: Array = original.duplicate(true)
	ending[0].hp = 0
	ending[1].hp = 0
	_check(torn.observe_battle_end("shop_tear", original, ending).ok,
		"actual tear records both Shop wearers downed")
	var prior_w := w.get_snapshot()
	var before_t := torn.read_state()
	_check(w.refresh_run_context(before_t.heroes, prior_w.owned,
		prior_w.scraps, prior_w.gold, prior_w.cards, prior_w),
		"wardrobe is refreshed to the genuine torn roster")
	var before_w := w.get_snapshot()
	var result := RunPatchWearerSummary.summarize(w, before_t)
	_check(result.ok and result.heroes[0].hp == 0 and result.heroes[1].hp == 0
		and not result.heroes[0].slots[0].active
		and result.heroes[0].slots[0].rules_text == _badge_text()
		and not result.heroes[1].slots[1].active
		and result.heroes[1].slots[1].rules_text == _spool_text(),
		"torn wearers retain descriptions but both Shop powers are dormant")
	var rules := CombatShopPatchRules.new()
	_check(rules.bind_wardrobe(w, torn, before_w, before_t)
		and rules.opening_block_bonus("warden") == 0
		and rules.healing_card_bonus("seamstress", "seamstress_mend") == 0,
		"real combat rule confirms no bonuses on torn wearers")
	_check(w.get_snapshot() == before_w and torn.read_state() == before_t,
		"summary and combat rule leave full snapshots unchanged")
	var mend := torn.choose_mend("shop_mend", "shop_mend_receipt", "warden", 1, 2,
		before_t.heroes, true)
	_check(mend.ok, "real mend restores Warden")
	var restored := RunPatchWearerSummary.summarize(w, torn.read_state())
	_check(restored.ok and restored.heroes[0].slots[0].active
		and not restored.heroes[1].slots[1].active
		and restored.heroes[0].slots[0].rules_text == _badge_text()
		and restored.heroes[1].slots[1].rules_text == _spool_text(),
		"only mended wearer has active Shop power")


func _test_torn_and_active_flags() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("button_eye", "warden", "HEAD", "tear_eye", w.get_snapshot()).ok
		and w.sew("pincushion_arm", "seamstress", "ARM", "tear_arm", w.get_snapshot()).ok
		and w.sew("quilted_coat", "tinker", "COAT", "tear_coat", w.get_snapshot()).ok,
		"all three named powers are worn before the battle")
	var torn := RunTornMending.new(f.heroes)
	var start: Array = torn.read_state().heroes
	var end_state: Array = start.duplicate(true)
	end_state[0]["hp"] = 0
	_check(torn.observe_battle_end("battle_tear", start, end_state).ok,
		"the real ledger witnesses the Warden tear")
	var torn_state := torn.read_state()
	_check(torn_state.heroes[0]["hp"] == 0 and torn_state.heroes[0]["max_hp"] == 37
		and torn_state.tear_counts["warden"] == 1,
		"the tear costs three maximum HP and records one tear")
	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.get("ok") == true, "the summary survives a genuine tear")
	if summary.get("ok") != true:
		return
	var head: Dictionary = summary.heroes[0]["slots"][0]
	_check(head["patch_id"] == "button_eye" and head["active"] == false
		and head["rules_text"] == EYE_TEXT,
		"the torn wearer keeps the sewn patch visible but inactive")
	_check(summary.heroes[0]["hp"] == 0,
		"the summary reports the torn ledger health, not the wardrobe roster")
	_check(summary.heroes[1]["slots"][1]["patch_id"] == "pincushion_arm"
		and summary.heroes[1]["slots"][1]["active"] == true,
		"the Seamstress power survives the Warden's tear")
	_check(summary.heroes[2]["slots"][2]["patch_id"] == "quilted_coat"
		and summary.heroes[2]["slots"][2]["active"] == true,
		"the Tinker power survives the Warden's tear")
	var mend := torn.choose_mend("map_node", "mend_receipt", "warden", 1, 2,
		torn_state.heroes, true)
	_check(mend.get("ok") == true and mend.get("remaining_scraps") == 0
		and mend.get("heroes")[0]["hp"] == 9
		and mend.get("heroes")[0]["max_hp"] == 37,
		"the real two-scrap mend restores floor(37 / 4) = 9 HP")
	var restored_state := torn.read_state()
	var restored := RunPatchWearerSummary.summarize(w, restored_state)
	_check(restored.get("ok") == true, "the summary survives the mend")
	if restored.get("ok") != true:
		return
	_check(restored.heroes[0]["slots"][0]["patch_id"] == "button_eye"
		and restored.heroes[0]["slots"][0]["active"] == true
		and restored.heroes[0]["hp"] == 9,
		"the mend flips the Warden's activation back without changing the sewn patch")
	_check(restored.heroes[1]["slots"][1]["active"] == true
		and restored.heroes[2]["slots"][2]["active"] == true,
		"the other two powers stay active through tear and mend")
	# A lawful health change is not by itself a stale ledger.
	var healed: Dictionary = restored_state.duplicate(true)
	healed["heroes"][0]["hp"] = 20
	var healed_summary := RunPatchWearerSummary.summarize(w, healed)
	_check(healed_summary.get("ok") == true
		and healed_summary.heroes[0]["hp"] == 20
		and healed_summary.heroes[0]["slots"][0]["active"] == true,
		"a lawful health change after the mend is still summarised")


func _test_replacement_and_readonly() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("button_eye", "warden", "HEAD", "first_sew", w.get_snapshot()).ok,
		"the Warden's HEAD carries Button Eye")
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var before_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(before_summary.get("ok") == true, "the summary before the replacement succeeds")
	var before_state := w.get_snapshot()
	var replaced := w.sew("stitched_badge", "warden", "HEAD", "replace_head", w.get_snapshot())
	_check(replaced.get("ok") == true, "the replacement sew commits")
	if replaced.get("ok") == true:
		_check(replaced.get("receipt", {}).get("displaced_id") == "button_eye"
			and replaced.get("receipt", {}).get("scrap_delta") == 1,
			"the replacement destroys the displaced patch for exactly one scrap")
	var after_state := w.get_snapshot()
	_check(after_state["scraps"] == before_state["scraps"] + 1
		and not after_state["owned"].has("button_eye")
		and after_state["owned"].has("stitched_badge")
		and after_state["worn"]["warden"]["HEAD"] == "stitched_badge",
		"the ledger destroys the displaced patch and gains exactly one scrap")
	var after_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(after_summary.get("ok") == true, "the summary after the replacement succeeds")
	if after_summary.get("ok") == true:
		var head: Dictionary = after_summary.heroes[0]["slots"][0]
		_check(head["patch_id"] == "stitched_badge" and head["active"] == true
			and head["rules_text"] == _badge_text(),
			"the new Shop power replaces the displaced patch text")
	_check(before_summary.get("ok") == true
		and before_summary.heroes[0]["slots"][0]["patch_id"] == "button_eye",
		"the earlier summary keeps its own detached patch identity")
	before_summary.heroes[0]["slots"][0]["patch_id"] = "spoof"
	before_summary.heroes[0]["slots"][0]["rules_text"] = "spoof"
	before_summary.heroes[0]["hp"] = 999
	_check(w.get_snapshot() == after_state, "summarizing never changes the wardrobe")
	_check(torn.read_state() == torn_state, "summarizing never changes the torn ledger")


func _test_rest_resew_summary() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("button_eye", "warden", "HEAD", "rest_eye", w.get_snapshot()).ok
		and w.sew("stitched_badge", "seamstress", "HEAD", "rest_badge", w.get_snapshot()).ok,
		"two HEAD patches are worn before the paid Rest re-sew")
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var before := RunPatchWearerSummary.summarize(w, torn_state)
	var recovery := RunRestRecovery.new(f.heroes)
	_check(not recovery.is_consumed(), "the Rest heal choice is still available")
	_check(w.start_rest("rest_node", w.get_snapshot()).ok, "a Rest session opens")
	var moved := w.re_sew("button_eye", "warden", "tinker", "rest_node",
		"rest_move", w.get_snapshot())
	_check(moved.get("ok") == true
		and moved.get("receipt", {}).get("scrap_delta") == -1
		and moved.get("receipt", {}).get("exchanged_id") == "",
		"the paid Rest move costs exactly one scrap")
	var after_move := w.get_snapshot()
	_check(after_move["scraps"] == 1
		and after_move["worn"]["warden"]["HEAD"] == ""
		and after_move["worn"]["tinker"]["HEAD"] == "button_eye",
		"the moved patch now belongs to the Tinker")
	var moved_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(moved_summary.get("ok") == true
		and moved_summary.heroes[0]["slots"][0]["patch_id"] == ""
		and moved_summary.heroes[2]["slots"][0]["patch_id"] == "button_eye"
		and moved_summary.heroes[2]["slots"][0]["active"] == true
		and moved_summary.heroes[2]["slots"][0]["rules_text"] == EYE_TEXT,
		"the summary follows the patch to its new wearer")
	var swapped := w.re_sew("stitched_badge", "seamstress", "tinker", "rest_node",
		"rest_swap", w.get_snapshot())
	_check(swapped.get("ok") == true
		and swapped.get("receipt", {}).get("exchanged_id") == "button_eye",
		"the same-slot Rest swap exchanges both HEAD patches")
	var after_swap := w.get_snapshot()
	_check(after_swap["scraps"] == 0
		and after_swap["worn"]["tinker"]["HEAD"] == "stitched_badge"
		and after_swap["worn"]["seamstress"]["HEAD"] == "button_eye",
		"the swap keeps both identities and costs a second scrap")
	var swapped_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(swapped_summary.get("ok") == true
		and swapped_summary.heroes[1]["slots"][0]["patch_id"] == "button_eye"
		and swapped_summary.heroes[1]["slots"][0]["rules_text"] == EYE_TEXT
		and swapped_summary.heroes[2]["slots"][0]["patch_id"] == "stitched_badge"
		and swapped_summary.heroes[2]["slots"][0]["rules_text"] == _badge_text(),
		"the summary shows the swapped wearers with their authored texts")
	_check(before.get("ok") == true
		and before.heroes[0]["slots"][0]["patch_id"] == "button_eye"
		and before.heroes[1]["slots"][0]["patch_id"] == "stitched_badge",
		"the earlier summary keeps its own detached wearers")
	_check(not recovery.is_consumed(),
		"the paid re-sew never consumes the Rest heal choice")


func _test_rejections() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}

	_check(RunPatchWearerSummary.summarize(null, torn_state) == rejected,
		"a null wardrobe is rejected exactly")
	var invalid := RunPatchWardrobe.new([])
	_check(not invalid.is_valid(), "the invalid wardrobe fixture really is invalid")
	_check(RunPatchWearerSummary.summarize(invalid, torn_state) == rejected,
		"an invalid wardrobe is rejected exactly")
	_check(RunPatchWearerSummary.summarize(w, {"heroes": torn_state.heroes}) == rejected,
		"a torn state without ok is rejected exactly")
	_check(RunPatchWearerSummary.summarize(w,
		{"ok": true, "heroes": torn_state.heroes}) == rejected,
		"a fabricated envelope without the ledger fields is rejected exactly")
	var no_counts: Dictionary = torn_state.duplicate(true)
	no_counts.erase("tear_counts")
	_check(RunPatchWearerSummary.summarize(w, no_counts) == rejected,
		"a torn state without tear counts is rejected exactly")
	var no_defeated: Dictionary = torn_state.duplicate(true)
	no_defeated.erase("defeated")
	_check(RunPatchWearerSummary.summarize(w, no_defeated) == rejected,
		"a torn state without the defeated flag is rejected exactly")
	var wrong_size := {"ok": true, "heroes": [torn_state.heroes[0].duplicate(true)],
		"tear_counts": torn_state.tear_counts, "completed_battles": [],
		"completed_mends": [], "completed_rests": [], "defeated": false}
	_check(RunPatchWearerSummary.summarize(w, wrong_size) == rejected,
		"a wrong sized torn roster is rejected exactly with a valid wardrobe")
	var foreign: Dictionary = torn_state.duplicate(true)
	foreign["heroes"][2]["id"] = "outsider"
	_check(RunPatchWearerSummary.summarize(w, foreign) == rejected,
		"a foreign hero identity is rejected exactly")
	var contradictory: Dictionary = torn_state.duplicate(true)
	contradictory["tear_counts"]["warden"] = 1
	_check(RunPatchWearerSummary.summarize(w, contradictory) == rejected,
		"a tear count that contradicts the maximum HP is rejected exactly")
	var capped: Dictionary = torn_state.duplicate(true)
	capped["heroes"][0]["max_hp"] = 35
	_check(RunPatchWearerSummary.summarize(w, capped) == rejected,
		"a maximum HP that contradicts the tear count is rejected exactly")
	var defeated: Dictionary = torn_state.duplicate(true)
	defeated["defeated"] = true
	_check(RunPatchWearerSummary.summarize(w, defeated) == rejected,
		"a defeated claim that contradicts the roster is rejected exactly")

	# A known patch whose wardrobe definition contradicts its authored slot.
	var wrong_slot := RunPatchWardrobe.new(f.heroes, ["button_eye"],
		[{"id": "button_eye", "slot": "COAT"}], 2, 170,
		["warden_strike", "seamstress_prick"], 8197)
	_check(wrong_slot.is_valid(), "the contradicting wardrobe fixture is a valid ledger")
	if wrong_slot.is_valid():
		_check(RunPatchWearerSummary.summarize(wrong_slot, torn_state) == rejected,
			"an unworn known patch in the wrong authored slot is rejected exactly")
		_check(wrong_slot.sew("button_eye", "warden", "COAT", "wrong_slot_sew",
			wrong_slot.get_snapshot()).ok,
			"the contradicting wardrobe really sews Button Eye into the COAT slot")
		_check(RunPatchWearerSummary.summarize(wrong_slot, torn_state) == rejected,
			"a known patch in the wrong authored slot is rejected exactly")

	# Shop slot contradictions fail closed even before a patch is equipped.
	var wrong_shop := RunPatchWardrobe.new(f.heroes, ["spare_spool"],
		[{"id": "spare_spool", "slot": "HEAD"}], 2, 170, ["warden_strike"], 8197)
	_check(wrong_shop.is_valid() and RunPatchWearerSummary.summarize(
		wrong_shop, torn_state) == rejected, "wrong Shop slot fails closed")
	# Malformed authored catalog records fail closed.
	var broken := [
		["a known attack record with the wrong amount", "attack", "button_eye",
			"amount", 2],
		["a known attack record with the wrong effect", "attack", "button_eye",
			"effect", "exposed"],
		["a known attack record with the wrong slot", "attack", "button_eye",
			"slot", "ARM"],
		["a known coat record with the wrong bonus", "coat", "quilted_coat",
			"max_hp_bonus", 5],
		["a known coat record with the wrong slot", "coat", "quilted_coat",
			"slot", "HEAD"],
		["a known padded_vest record with the wrong bonus", "coat", "padded_vest",
			"max_hp_bonus", 5],
		["a known padded_vest record with the wrong slot", "coat", "padded_vest",
			"slot", "ARM"],
		["a known double_quilt_coat record with the wrong bonus", "coat", "double_quilt_coat",
			"max_hp_bonus", 7],
		["a known double_quilt_coat record with the wrong slot", "coat", "double_quilt_coat",
			"slot", "HEAD"],
		["a known scrap_lined_vest record with the wrong bonus", "coat", "scrap_lined_vest",
			"max_hp_bonus", 5],
		["a known scrap_lined_vest record with the wrong slot", "coat", "scrap_lined_vest",
			"slot", "ARM"],
		["a known wool_patch_cloak record with the wrong bonus", "coat", "wool_patch_cloak",
			"max_hp_bonus", 7],
		["a known wool_patch_cloak record with the wrong slot", "coat", "wool_patch_cloak",
			"slot", "HEAD"],
		["a known chain_stitched_coat record with the wrong bonus", "coat", "chain_stitched_coat",
			"max_hp_bonus", 9],
		["a known chain_stitched_coat record with the wrong slot", "coat", "chain_stitched_coat",
			"slot", "ARM"],
		["a known reinforced_patchcoat record with the wrong bonus", "coat", "reinforced_patchcoat",
			"max_hp_bonus", 8],
		["a known reinforced_patchcoat record with the wrong slot", "coat", "reinforced_patchcoat",
			"slot", "ARM"],
		["a known thick_felt_mantle record with the wrong bonus", "coat", "thick_felt_mantle",
			"max_hp_bonus", 11],
		["a known thick_felt_mantle record with the wrong slot", "coat", "thick_felt_mantle",
			"slot", "HEAD"],
		["a known slot-only record with the wrong slot", "initial", "stitched_badge",
			"slot", "ARM"],
		["a known slot-only record with an invented effect", "initial", "spare_spool",
			"effect", "first_attack_exposed"],
	]
	for entry in broken:
		var patched := _with_field(catalogs, entry[1], entry[2], entry[3], entry[4])
		_check(RunPatchWearerSummary.summarize(w, torn_state, patched) == rejected,
			str(entry[0]) + " is rejected exactly")
	var missing_amount := _without_field(catalogs, "attack", "button_eye", "amount")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_amount) == rejected,
		"a known attack record without its amount is rejected exactly")
	var missing_shop := _without_record(catalogs, "initial", "spare_spool")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_shop) == rejected,
		"missing Shop identity fails closed")
	var missing_record := _without_record(catalogs, "attack", "button_eye")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_record) == rejected,
		"a missing known catalog record is rejected exactly")
	var missing_vest := _without_record(catalogs, "coat", "padded_vest")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_vest) == rejected,
		"a missing padded_vest record is rejected exactly")
	var missing_double := _without_record(catalogs, "coat", "double_quilt_coat")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_double) == rejected,
		"a missing double_quilt_coat record is rejected exactly")
	var missing_scrap := _without_record(catalogs, "coat", "scrap_lined_vest")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_scrap) == rejected,
		"a missing scrap_lined_vest record is rejected exactly")
	var missing_wool := _without_record(catalogs, "coat", "wool_patch_cloak")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_wool) == rejected,
		"a missing wool_patch_cloak record is rejected exactly")
	var missing_chain := _without_record(catalogs, "coat", "chain_stitched_coat")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_chain) == rejected,
		"a missing chain_stitched_coat record is rejected exactly")
	var missing_reinforced := _without_record(catalogs, "coat", "reinforced_patchcoat")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_reinforced) == rejected,
		"a missing reinforced_patchcoat record is rejected exactly")
	var missing_thick := _without_record(catalogs, "coat", "thick_felt_mantle")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_thick) == rejected,
		"a missing thick_felt_mantle record is rejected exactly")
	var missing_reinforced_bonus := _without_field(catalogs, "coat", "reinforced_patchcoat", "max_hp_bonus")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_reinforced_bonus) == rejected,
		"a reinforced_patchcoat record without its bonus is rejected exactly")
	var missing_thick_bonus := _without_field(catalogs, "coat", "thick_felt_mantle", "max_hp_bonus")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_thick_bonus) == rejected,
		"a thick_felt_mantle record without its bonus is rejected exactly")
	var missing_vest_bonus := _without_field(catalogs, "coat", "padded_vest", "max_hp_bonus")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_vest_bonus) == rejected,
		"a padded_vest record without its bonus is rejected exactly")
	var missing_double_bonus := _without_field(catalogs, "coat", "double_quilt_coat", "max_hp_bonus")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_double_bonus) == rejected,
		"a double_quilt_coat record without its bonus is rejected exactly")
	# A later authored patch that this readout cannot describe must not break it.
	var extra: Dictionary = catalogs.duplicate(true)
	var attack_extra: Array = extra["attack"].duplicate(true)
	attack_extra.append({"id": "brass_button", "slot": "HEAD",
		"effect": "unknown_effect", "amount": 3})
	extra["attack"] = attack_extra
	_check(RunPatchWearerSummary.summarize(w, torn_state, extra).get("ok") == true,
		"an unknown later authored patch leaves the known readout intact")
	_check(RunPatchWearerSummary.summarize(w, torn_state, {"attack": "nonsense"}) == rejected,
		"a malformed catalog collection is rejected exactly")


## Actual sewn receipts independently check the proposal for every living hero,
## both with an empty slot and with an owned patch displaced from THAT wearer.
func _test_sew_previews() -> void:
	var known := [
		["stitched_badge", "HEAD", _badge_text()],
		["spare_spool", "ARM", _spool_text()],
		["quilted_coat", "COAT", COAT_TEXT],
		["padded_vest", "COAT", PADDED_VEST_TEXT],
		["double_quilt_coat", "COAT", DOUBLE_QUILT_TEXT],
		["scrap_lined_vest", "COAT", SCRAP_LINED_VEST_TEXT],
		["wool_patch_cloak", "COAT", WOOL_PATCH_CLOAK_TEXT],
		["chain_stitched_coat", "COAT", CHAIN_STITCHED_COAT_TEXT],
		["reinforced_patchcoat", "COAT", REINFORCED_PATCHCOAT_TEXT],
		["thick_felt_mantle", "COAT", THICK_FELT_MANTLE_TEXT],
		["button_eye", "HEAD", EYE_TEXT],
		["pincushion_arm", "ARM", ARM_TEXT],
		["bloodstitch_bonnet", "HEAD", M05_BLEED_TEXT],
		["button_glass_visor", "HEAD", M05_EXPOSED_TEXT],
		["stern_seam_cap", "HEAD", M05_WEAK_TEXT],
		["reinforced_browband", "HEAD", M05_HEAD_BLOCK_TEXT],
		["hemguard_cuff", "ARM", M05_ARM_BLOCK_TEXT],
		["red_bobbin_cuff", "ARM", M05_BLEED_TEXT],
		["loose_thread_glove", "ARM", M05_UNRAVEL_TEXT],
		["frayfinder_mitt", "ARM", M05_FRAYFINDER_TEXT],
		["borrowed_button", "COAT", BORROWED_BUTTON_TEXT]
	]
	for record in known:
		var fixture := _fixture()
		if fixture.is_empty():
			return
		var wardrobe: RunPatchWardrobe = fixture.wardrobe
		var torn := RunTornMending.new(fixture.heroes)
		var before_w := wardrobe.get_snapshot()
		var before_t := torn.read_state()
		var proposal := RunPatchWearerSummary.preview_sew(
			wardrobe, before_t, record[0], "tinker")
		_check(proposal.get("ok") == true and proposal.get("patch_id") == record[0]
			and proposal.get("slot") == record[1] and proposal.get("rules_text") == record[2]
			and proposal.get("wearer") == "tinker" and proposal.get("displaced_id") == ""
			and proposal.get("scrap_delta") == 0,
			"independently authored %s slot and power preview" % record[0])
		_check(wardrobe.get_snapshot() == before_w and torn.read_state() == before_t,
			"%s preview changes neither ledger" % record[0])

	for hero_id in RunPatchWearerSummary.HERO_IDS:
		for occupied in [false, true]:
			var fixture := _fixture()
			if fixture.is_empty():
				return
			var wardrobe: RunPatchWardrobe = fixture.wardrobe
			var torn := RunTornMending.new(fixture.heroes)
			_check(torn.is_valid() and wardrobe.is_valid(), "real preview owners have valid ledgers")
			if occupied:
				_check(wardrobe.sew("button_eye", hero_id, "HEAD",
					"prior_" + hero_id, wardrobe.get_snapshot()).ok,
					"the chosen hero genuinely wears Button Eye before replacement")
			var before_w := wardrobe.get_snapshot()
			var before_t := torn.read_state()
			var local := RandomNumberGenerator.new()
			local.seed = 16438
			var local_rng: int = local.state
			seed(47001)
			var global_next: int = randi()
			seed(47001)
			var preview := RunPatchWearerSummary.preview_sew(
				wardrobe, before_t, "stitched_badge", hero_id)
			var again := RunPatchWearerSummary.preview_sew(
				wardrobe, before_t, "stitched_badge", hero_id)
			_check(preview.get("ok") == true and preview == again
				and preview.get("wearer") == hero_id and preview.get("slot") == "HEAD"
				and preview.get("rules_text") == _badge_text()
				and preview.get("displaced_id") == ("button_eye" if occupied else "")
				and preview.get("displaced_rules_text") == (EYE_TEXT if occupied else "")
				and preview.get("scrap_delta") == (1 if occupied else 0),
				"%s exact %s-slot preview matches owned prior patch" % [
					hero_id, "occupied" if occupied else "empty"])
			_check(wardrobe.get_snapshot() == before_w and torn.read_state() == before_t
				and local.state == local_rng and randi() == global_next,
				"pure choice neither changes wardrobe/torn nor consumes local/global RNG")
			if preview.get("ok") != true:
				continue
			var sewn := wardrobe.sew("stitched_badge", hero_id, "HEAD",
				"offer_" + hero_id, wardrobe.get_snapshot())
			var after_w := wardrobe.get_snapshot()
			_check(sewn.get("ok") == true and sewn.receipt.patch_id == preview.patch_id
				and sewn.receipt.hero_id == preview.wearer
				and sewn.receipt.slot == preview.slot
				and sewn.receipt.displaced_id == preview.displaced_id
				and sewn.receipt.scrap_delta == preview.scrap_delta
				and after_w.scraps == before_w.scraps + preview.scrap_delta
				and after_w.worn[hero_id].HEAD == preview.patch_id
				and (after_w.owned.has("button_eye") == not occupied),
				"%s receipt verifies actual empty/replacement economy" % hero_id)
			_check(RunPatchWearerSummary.preview_sew(wardrobe, before_t,
				"stitched_badge", hero_id) == {"ok": false},
				"already-sewn offered patch cannot be previewed again")
			preview["rules_text"] = "forged effect"
			preview["displaced_id"] = "forged"
			_check(wardrobe.get_snapshot() == after_w and torn.read_state() == before_t,
				"mutating returned preview does not alter services")

	var fixture := _fixture()
	if fixture.is_empty():
		return
	var w: RunPatchWardrobe = fixture.wardrobe
	var torn := RunTornMending.new(fixture.heroes)
	var original := w.get_snapshot()
	var torn_state := torn.read_state()
	var reject := {"ok": false}
	_check(RunPatchWearerSummary.preview_sew(w, torn_state, "unowned", "warden") == reject
		and RunPatchWearerSummary.preview_sew(w, torn_state, "button_eye", "outsider") == reject
		and RunPatchWearerSummary.preview_sew(w, torn_state, 12, "warden") == reject
		and RunPatchWearerSummary.preview_sew(w, torn_state, "button_eye", " ") == reject,
		"unowned, invalid type and foreign wearer are never previewable")
	var malformed := _with_field(fixture.catalogs, "attack", "button_eye", "amount", 4)
	_check(RunPatchWearerSummary.preview_sew(w, torn_state,
		"button_eye", "warden", malformed) == reject,
		"malformed known record cannot promise a forged amount")
	var wrong := RunPatchWardrobe.new(fixture.heroes, ["button_eye"],
		[{"id": "button_eye", "slot": "ARM"}], 2)
	_check(wrong.is_valid() and RunPatchWearerSummary.preview_sew(
		wrong, torn_state, "button_eye", "warden") == reject,
		"mismatched actual catalog slot fails closed")
	var unknown := RunPatchWardrobe.new(fixture.heroes, ["future_head"],
		[{"id": "future_head", "slot": "HEAD"}], 2)
	var future := RunPatchWearerSummary.preview_sew(
		unknown, torn_state, "future_head", "warden")
	_check(unknown.is_valid() and future.get("ok") == true
		and future.get("slot") == "HEAD" and future.get("patch_id") == "future_head"
		and future.get("rules_text") == "",
		"unknown legal owned ID keeps slot but gains no fabricated power")

	var ending: Array = torn_state.heroes.duplicate(true)
	ending[0].hp = 0
	_check(torn.observe_battle_end("preview_tear", torn_state.heroes, ending).ok,
		"real torn ledger records an eligible hero becoming torn")
	var downed := torn.read_state()
	_check(RunPatchWearerSummary.preview_sew(w, downed,
		"stitched_badge", "warden") == reject,
		"stale wardrobe versus torn roster cannot authorize sew")
	_check(w.refresh_run_context(downed.heroes, original.owned, original.scraps,
		original.gold, original.cards, original),
		"torn roster refresh is a legitimate wardrobe context")
	var refreshed := w.get_snapshot()
	_check(RunPatchWearerSummary.preview_sew(w, downed,
		"stitched_badge", "warden") == reject
		and RunPatchWearerSummary.preview_sew(w, downed,
			"stitched_badge", "seamstress").get("ok") == true,
		"torn wearer rejected but living recipient still previews without a mend")
	var invalid_state: Dictionary = downed.duplicate(true)
	invalid_state.tear_counts.warden = 0
	_check(RunPatchWearerSummary.preview_sew(w, invalid_state,
		"stitched_badge", "seamstress") == reject,
		"invalid actual tear-count projection never previews")
	_check(w.get_snapshot() == refreshed and torn.read_state() == downed,
		"all rejected proposals leave the two genuine ledgers intact")


func _test_detachment_and_isolation() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("button_eye", "warden", "HEAD", "detach_sew", w.get_snapshot()).ok
		and w.sew("quilted_coat", "tinker", "COAT", "detach_coat", w.get_snapshot()).ok,
		"two patches are worn for the detachment checks")
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var before_w := w.get_snapshot()
	var before_t := torn.read_state()

	seed(12345)
	var expected_randi := randi()
	seed(12345)

	var first := RunPatchWearerSummary.summarize(w, torn_state)
	var second := RunPatchWearerSummary.summarize(w, torn_state)

	_check(first == second and first.get("ok") == true,
		"repeated independent summaries agree")
	_check(w.get_snapshot() == before_w, "summarizing never changes the wardrobe")
	_check(torn.read_state() == before_t, "summarizing never changes the torn ledger")
	_check(randi() == expected_randi, "summarizing never consumes the global RNG")

	first.heroes[0]["slots"][0]["patch_id"] = "mutated"
	first.heroes[0]["hp"] = 999
	var fresh := RunPatchWearerSummary.summarize(w, torn_state)
	_check(fresh.heroes[0]["slots"][0]["patch_id"] == "button_eye",
		"a fresh summary is independent of a mutated earlier result")
	_check(fresh.heroes[0]["hp"] == f.heroes[0]["hp"],
		"a fresh summary keeps the authoritative hero HP")
	_check(second.heroes[0]["slots"][0]["patch_id"] == "button_eye",
		"a second result is independent of a mutated earlier result")
	_check(w.get_snapshot() == before_w and torn.read_state() == before_t,
		"the services stay unchanged after a returned summary is mutated")


func _test_coat_powers_lifecycle_and_previews() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var heroes: Array = f.heroes
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}
	var reject_preview := {"ok": false}

	# 1. AC1 & AC2: Valid wardrobe and living heroes wearing the 3 COAT patches.
	_check(w.sew("padded_vest", "warden", "COAT", "sew_vest", w.get_snapshot()).ok,
		"Padded Vest is sewn onto Warden COAT")
	_check(w.sew("quilted_coat", "seamstress", "COAT", "sew_quilt", w.get_snapshot()).ok,
		"Quilted Coat is sewn onto Seamstress COAT")
	_check(w.sew("double_quilt_coat", "tinker", "COAT", "sew_double", w.get_snapshot()).ok,
		"Double Quilt Coat is sewn onto Tinker COAT")

	var torn := RunTornMending.new(heroes)
	_check(torn.is_valid(), "RunTornMending accepts starter party for coat tests")
	var torn_state := torn.read_state()
	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.get("ok") == true, "summarize succeeds with all three coats sewn")
	if summary.get("ok") != true:
		return

	# Named assertions for all three coats (AC1)
	var warden_coat: Dictionary = summary.heroes[0]["slots"][2]
	_check(warden_coat["slot"] == "COAT" and warden_coat["patch_id"] == "padded_vest"
		and warden_coat["active"] == true and warden_coat["rules_text"] == PADDED_VEST_TEXT,
		"Warden COAT publishes padded_vest with +4 maximum HP and active=true")

	var seamstress_coat: Dictionary = summary.heroes[1]["slots"][2]
	_check(seamstress_coat["slot"] == "COAT" and seamstress_coat["patch_id"] == "quilted_coat"
		and seamstress_coat["active"] == true and seamstress_coat["rules_text"] == COAT_TEXT,
		"Seamstress COAT publishes quilted_coat with +6 maximum HP and active=true")

	var tinker_coat: Dictionary = summary.heroes[2]["slots"][2]
	_check(tinker_coat["slot"] == "COAT" and tinker_coat["patch_id"] == "double_quilt_coat"
		and tinker_coat["active"] == true and tinker_coat["rules_text"] == DOUBLE_QUILT_TEXT,
		"Tinker COAT publishes double_quilt_coat with +8 maximum HP and active=true")

	# Wearer only: other slots empty and blank rules text
	for i in range(3):
		_check(summary.heroes[i]["slots"][0]["patch_id"] == ""
			and summary.heroes[i]["slots"][0]["rules_text"] == ""
			and not summary.heroes[i]["slots"][0]["active"],
			summary.heroes[i]["id"] + " HEAD slot is empty and inactive")
		_check(summary.heroes[i]["slots"][1]["patch_id"] == ""
			and summary.heroes[i]["slots"][1]["rules_text"] == ""
			and not summary.heroes[i]["slots"][1]["active"],
			summary.heroes[i]["id"] + " ARM slot is empty and inactive")

	# Verify RunPatchCoatRules numeric projection (+4 / +6 / +8)
	var health_proj := RunPatchCoatRules.project_health(torn_state, w, catalogs["coat"])
	_check(health_proj.get("ok") == true, "RunPatchCoatRules projects health with all 3 coats")
	if health_proj.get("ok") == true:
		_check(health_proj.heroes[0]["max_hp"] == 44 and health_proj.heroes[0]["hp"] == 40,
			"Warden effective max HP projected as 40 + 4 = 44 while stored hp is 40")
		_check(health_proj.heroes[1]["max_hp"] == 36 and health_proj.heroes[1]["hp"] == 30,
			"Seamstress effective max HP projected as 30 + 6 = 36 while stored hp is 30")
		_check(health_proj.heroes[2]["max_hp"] == 34 and health_proj.heroes[2]["hp"] == 26,
			"Tinker effective max HP projected as 26 + 8 = 34 while stored hp is 26")
		# Base max HP in torn state and wardrobe snapshot remains unchanged
		_check(torn_state.heroes[0]["max_hp"] == 40 and torn_state.heroes[1]["max_hp"] == 30
			and torn_state.heroes[2]["max_hp"] == 26,
			"base max HP in torn state remains 40, 30, 26")

	# AC1 fail-closed with copied detached catalogs
	var corrupted_checks := [
		["coat", "padded_vest", "max_hp_bonus", 5, "padded_vest wrong bonus"],
		["coat", "padded_vest", "slot", "HEAD", "padded_vest wrong slot"],
		["coat", "double_quilt_coat", "max_hp_bonus", 10, "double_quilt_coat wrong bonus"],
		["coat", "double_quilt_coat", "slot", "ARM", "double_quilt_coat wrong slot"],
	]
	for c in corrupted_checks:
		var corrupted := _with_field(catalogs, c[0], c[1], c[2], c[3])
		_check(RunPatchWearerSummary.summarize(w, torn_state, corrupted) == rejected,
			c[4] + " makes summarize refuse")
		_check(RunPatchWearerSummary.preview_sew(w, torn_state, c[1], "warden", corrupted) == reject_preview,
			c[4] + " makes preview_sew refuse")

	var missing_vest := _without_record(catalogs, "coat", "padded_vest")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_vest) == rejected,
		"missing padded_vest makes summarize refuse")
	_check(RunPatchWearerSummary.preview_sew(w, torn_state, "padded_vest", "warden", missing_vest) == reject_preview,
		"missing padded_vest makes preview_sew refuse")

	var missing_double := _without_record(catalogs, "coat", "double_quilt_coat")
	_check(RunPatchWearerSummary.summarize(w, torn_state, missing_double) == rejected,
		"missing double_quilt_coat makes summarize refuse")
	_check(RunPatchWearerSummary.preview_sew(w, torn_state, "double_quilt_coat", "tinker", missing_double) == reject_preview,
		"missing double_quilt_coat makes preview_sew refuse")

	# 2. AC2: Real tear -> wardrobe refresh -> described yet inactive -> legal mend -> reactivation
	var b_start: Array = torn_state.heroes
	var b_end: Array = b_start.duplicate(true)
	b_end[0]["hp"] = 0 # Warden downed
	b_end[2]["hp"] = 0 # Tinker downed
	_check(torn.observe_battle_end("coat_battle_tear", b_start, b_end).ok,
		"real battle ends with Warden and Tinker torn")
	var torn_state2 := torn.read_state()
	var w_snap := w.get_snapshot()
	_check(w.refresh_run_context(torn_state2.heroes, w_snap.owned, w_snap.scraps,
		w_snap.gold, w_snap.cards, w_snap),
		"wardrobe refreshed to reflect torn heroes")
	var torn_summary := RunPatchWearerSummary.summarize(w, torn_state2)
	_check(torn_summary.get("ok") == true, "summarize succeeds after heroes are torn")
	if torn_summary.get("ok") == true:
		var w_torn_coat: Dictionary = torn_summary.heroes[0]["slots"][2]
		_check(w_torn_coat["patch_id"] == "padded_vest" and w_torn_coat["active"] == false
			and w_torn_coat["rules_text"] == PADDED_VEST_TEXT,
			"torn Warden keeps padded_vest described (+4 maximum HP) but active=false")

		var s_live_coat: Dictionary = torn_summary.heroes[1]["slots"][2]
		_check(s_live_coat["patch_id"] == "quilted_coat" and s_live_coat["active"] == true
			and s_live_coat["rules_text"] == COAT_TEXT,
			"living Seamstress keeps quilted_coat active=true and described")

		var t_torn_coat: Dictionary = torn_summary.heroes[2]["slots"][2]
		_check(t_torn_coat["patch_id"] == "double_quilt_coat" and t_torn_coat["active"] == false
			and t_torn_coat["rules_text"] == DOUBLE_QUILT_TEXT,
			"torn Tinker keeps double_quilt_coat described (+8 maximum HP) but active=false")

	# Verify RunPatchCoatRules does not apply bonus to torn wearers
	var torn_proj := RunPatchCoatRules.project_health(torn_state2, w, catalogs["coat"])
	_check(torn_proj.get("ok") == true, "project_health succeeds on torn roster")
	if torn_proj.get("ok") == true:
		_check(torn_proj.heroes[0]["max_hp"] == 37,
			"torn Warden max HP remains 37 (40-3, no coat bonus)")
		_check(torn_proj.heroes[1]["max_hp"] == 36,
			"living Seamstress max HP remains 36 (30+6)")
		_check(torn_proj.heroes[2]["max_hp"] == 23,
			"torn Tinker max HP remains 23 (26-3, no coat bonus)")

	# Legal mend on Warden
	var mend_w := torn.choose_mend("mend_node_w", "receipt_coat_w", "warden", 1, 4,
		torn_state2.heroes, true)
	_check(mend_w.get("ok") == true, "Warden mended successfully")
	var state_after_mend_w := torn.read_state()
	var w_snap2 := w.get_snapshot()
	_check(w.refresh_run_context(state_after_mend_w.heroes, w_snap2.owned, w_snap2.scraps,
		w_snap2.gold, w_snap2.cards, w_snap2),
		"wardrobe refreshed after Warden mend")
	var mended_w_summary := RunPatchWearerSummary.summarize(w, state_after_mend_w)
	_check(mended_w_summary.get("ok") == true, "summarize succeeds after Warden mend")
	if mended_w_summary.get("ok") == true:
		var w_mended_coat: Dictionary = mended_w_summary.heroes[0]["slots"][2]
		_check(w_mended_coat["patch_id"] == "padded_vest" and w_mended_coat["active"] == true
			and w_mended_coat["rules_text"] == PADDED_VEST_TEXT,
			"mended Warden reactivates padded_vest with +4 maximum HP")
		var t_still_torn: Dictionary = mended_w_summary.heroes[2]["slots"][2]
		_check(t_still_torn["patch_id"] == "double_quilt_coat" and t_still_torn["active"] == false,
			"unmended Tinker double_quilt_coat stays inactive")

	# Legal mend on Tinker
	var mend_t := torn.choose_mend("mend_node_t", "receipt_coat_t", "tinker", 3, 2,
		state_after_mend_w.heroes, true)
	_check(mend_t.get("ok") == true, "Tinker mended successfully")
	var state_after_mend_t := torn.read_state()
	var w_snap3 := w.get_snapshot()
	_check(w.refresh_run_context(state_after_mend_t.heroes, w_snap3.owned, w_snap3.scraps,
		w_snap3.gold, w_snap3.cards, w_snap3),
		"wardrobe refreshed after Tinker mend")
	var mended_t_summary := RunPatchWearerSummary.summarize(w, state_after_mend_t)
	_check(mended_t_summary.get("ok") == true, "summarize succeeds after Tinker mend")
	if mended_t_summary.get("ok") == true:
		var t_mended_coat: Dictionary = mended_t_summary.heroes[2]["slots"][2]
		_check(t_mended_coat["patch_id"] == "double_quilt_coat" and t_mended_coat["active"] == true
			and t_mended_coat["rules_text"] == DOUBLE_QUILT_TEXT,
			"mended Tinker reactivates double_quilt_coat with +8 maximum HP")

	# Verify project_health restores numeric bonus on both mended heroes
	var mended_proj := RunPatchCoatRules.project_health(state_after_mend_t, w, catalogs["coat"])
	_check(mended_proj.get("ok") == true, "project_health succeeds after both heroes mended")
	if mended_proj.get("ok") == true:
		_check(mended_proj.heroes[0]["max_hp"] == 41,
			"mended Warden max HP is 37 + 4 = 41")
		_check(mended_proj.heroes[1]["max_hp"] == 36,
			"Seamstress max HP remains 30 + 6 = 36")
		_check(mended_proj.heroes[2]["max_hp"] == 31,
			"mended Tinker max HP is 23 + 8 = 31")

	# 3. AC3: Accurate nonmutating previews for empty and occupied COAT slots
	var prev_f := _fixture(2)
	if prev_f.is_empty():
		return
	var pw: RunPatchWardrobe = prev_f.wardrobe
	var ptorn := RunTornMending.new(prev_f.heroes)
	var ptorn_state := ptorn.read_state()
	var pre_snap := pw.get_snapshot()

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 998877
	var pre_local_state := local_rng.state
	seed(554433)
	var pre_global_rand := randi()
	seed(554433)

	# Empty slot preview for Padded Vest on Warden
	var vest_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "padded_vest", "warden")
	_check(vest_prev.get("ok") == true and vest_prev.get("patch_id") == "padded_vest"
		and vest_prev.get("slot") == "COAT" and vest_prev.get("rules_text") == PADDED_VEST_TEXT
		and vest_prev.get("wearer") == "warden" and vest_prev.get("displaced_id") == ""
		and vest_prev.get("displaced_rules_text") == "" and vest_prev.get("scrap_delta") == 0,
		"empty COAT preview for Padded Vest on Warden matches specification")

	# Empty slot preview for Double Quilt Coat on Seamstress
	var double_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "double_quilt_coat", "seamstress")
	_check(double_prev.get("ok") == true and double_prev.get("patch_id") == "double_quilt_coat"
		and double_prev.get("slot") == "COAT" and double_prev.get("rules_text") == DOUBLE_QUILT_TEXT
		and double_prev.get("wearer") == "seamstress" and double_prev.get("displaced_id") == ""
		and double_prev.get("displaced_rules_text") == "" and double_prev.get("scrap_delta") == 0,
		"empty COAT preview for Double Quilt Coat on Seamstress matches specification")

	# Invariants: wardrobe, torn state and RNG are completely untouched
	_check(pw.get_snapshot() == pre_snap, "wardrobe snapshot unchanged after empty previews")
	_check(ptorn.read_state() == ptorn_state, "torn ledger unchanged after empty previews")
	_check(local_rng.state == pre_local_state and randi() == pre_global_rand,
		"RNG untouched after empty previews")

	# Now occupy Warden's COAT slot with quilted_coat
	_check(pw.sew("quilted_coat", "warden", "COAT", "prev_sew_quilt", pw.get_snapshot()).ok,
		"Warden equips Quilted Coat before replacement preview")
	var occ_snap := pw.get_snapshot()

	seed(554433)
	pre_global_rand = randi()
	seed(554433)

	# Occupied slot preview: Padded Vest displacing Quilted Coat
	var occ_vest_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "padded_vest", "warden")
	_check(occ_vest_prev.get("ok") == true and occ_vest_prev.get("patch_id") == "padded_vest"
		and occ_vest_prev.get("slot") == "COAT" and occ_vest_prev.get("rules_text") == PADDED_VEST_TEXT
		and occ_vest_prev.get("wearer") == "warden" and occ_vest_prev.get("displaced_id") == "quilted_coat"
		and occ_vest_prev.get("displaced_rules_text") == COAT_TEXT
		and occ_vest_prev.get("scrap_delta") == 1,
		"occupied COAT preview: Padded Vest displacing Quilted Coat projects +1 scrap and displaced text")

	# Occupied slot preview: Double Quilt Coat displacing Quilted Coat
	var occ_double_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "double_quilt_coat", "warden")
	_check(occ_double_prev.get("ok") == true and occ_double_prev.get("patch_id") == "double_quilt_coat"
		and occ_double_prev.get("slot") == "COAT" and occ_double_prev.get("rules_text") == DOUBLE_QUILT_TEXT
		and occ_double_prev.get("wearer") == "warden" and occ_double_prev.get("displaced_id") == "quilted_coat"
		and occ_double_prev.get("displaced_rules_text") == COAT_TEXT
		and occ_double_prev.get("scrap_delta") == 1,
		"occupied COAT preview: Double Quilt Coat displacing Quilted Coat projects +1 scrap and displaced text")

	# Invariants after occupied preview
	_check(pw.get_snapshot() == occ_snap, "wardrobe snapshot unchanged after occupied previews")
	_check(ptorn.read_state() == ptorn_state, "torn ledger unchanged after occupied previews")
	_check(local_rng.state == pre_local_state and randi() == pre_global_rand,
		"RNG untouched after occupied previews")

	# Commit sew of Padded Vest displacing Quilted Coat and verify receipt matches preview
	var commit_sew := pw.sew("padded_vest", "warden", "COAT", "commit_vest", pw.get_snapshot())
	_check(commit_sew.get("ok") == true, "commit sew of Padded Vest succeeds")
	if commit_sew.get("ok") == true:
		var rc: Dictionary = commit_sew.get("receipt", {})
		_check(rc.get("patch_id") == occ_vest_prev.get("patch_id")
			and rc.get("hero_id") == occ_vest_prev.get("wearer")
			and rc.get("slot") == occ_vest_prev.get("slot")
			and rc.get("displaced_id") == occ_vest_prev.get("displaced_id")
			and rc.get("scrap_delta") == occ_vest_prev.get("scrap_delta"),
			"actual commit receipt matches occupied preview projection")
		var post_w := pw.get_snapshot()
		_check(post_w.scraps == occ_snap.scraps + 1, "scraps increased by 1 upon displacing coat")
		_check(not post_w.owned.has("quilted_coat"), "displaced Quilted Coat destroyed")
		_check(post_w.worn["warden"]["COAT"] == "padded_vest", "Warden now wears Padded Vest")

	# Preview Double Quilt Coat displacing Padded Vest
	var occ_double_prev2 := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "double_quilt_coat", "warden")
	_check(occ_double_prev2.get("ok") == true and occ_double_prev2.get("patch_id") == "double_quilt_coat"
		and occ_double_prev2.get("slot") == "COAT" and occ_double_prev2.get("rules_text") == DOUBLE_QUILT_TEXT
		and occ_double_prev2.get("wearer") == "warden" and occ_double_prev2.get("displaced_id") == "padded_vest"
		and occ_double_prev2.get("displaced_rules_text") == PADDED_VEST_TEXT
		and occ_double_prev2.get("scrap_delta") == 1,
		"occupied COAT preview: Double Quilt Coat displacing Padded Vest projects +1 scrap and +4 max HP displaced")

	# Preview on torn hero fails closed
	var p_start: Array = ptorn_state.heroes
	var p_end: Array = p_start.duplicate(true)
	p_end[0]["hp"] = 0
	_check(ptorn.observe_battle_end("prev_tear", p_start, p_end).ok, "Warden torn for preview check")
	var ptorn_down := ptorn.read_state()
	var cur_snap := pw.get_snapshot()
	_check(pw.refresh_run_context(ptorn_down.heroes, cur_snap.owned, cur_snap.scraps,
		cur_snap.gold, cur_snap.cards, cur_snap), "wardrobe context refreshed for torn preview")
	_check(RunPatchWearerSummary.preview_sew(pw, ptorn_down, "double_quilt_coat", "warden") == reject_preview,
		"preview_sew rejects torn hero for Double Quilt Coat")
	_check(RunPatchWearerSummary.preview_sew(pw, ptorn_down, "double_quilt_coat", "seamstress").get("ok") == true,
		"preview_sew still succeeds for living hero on torn run")


func _test_new_coat_patches_lifecycle() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var heroes: Array = f.heroes
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}
	var reject_preview := {"ok": false}

	_check(w.sew("scrap_lined_vest", "warden", "COAT", "sew_scrap", w.get_snapshot()).ok,
		"Scrap Lined Vest is sewn onto Warden COAT")
	_check(w.sew("wool_patch_cloak", "seamstress", "COAT", "sew_wool", w.get_snapshot()).ok,
		"Wool Patch Cloak is sewn onto Seamstress COAT")
	_check(w.sew("chain_stitched_coat", "tinker", "COAT", "sew_chain", w.get_snapshot()).ok,
		"Chain Stitched Coat is sewn onto Tinker COAT")

	var torn := RunTornMending.new(heroes)
	_check(torn.is_valid(), "RunTornMending accepts starter party for new coat tests")
	var torn_state := torn.read_state()
	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.get("ok") == true, "summarize succeeds with all three new coats sewn")
	if summary.get("ok") != true:
		return

	var warden_coat: Dictionary = summary.heroes[0]["slots"][2]
	_check(warden_coat["slot"] == "COAT" and warden_coat["patch_id"] == "scrap_lined_vest"
		and warden_coat["active"] == true and warden_coat["rules_text"] == SCRAP_LINED_VEST_TEXT,
		"Warden COAT publishes scrap_lined_vest with +3 maximum HP and active=true")

	var seamstress_coat: Dictionary = summary.heroes[1]["slots"][2]
	_check(seamstress_coat["slot"] == "COAT" and seamstress_coat["patch_id"] == "wool_patch_cloak"
		and seamstress_coat["active"] == true and seamstress_coat["rules_text"] == WOOL_PATCH_CLOAK_TEXT,
		"Seamstress COAT publishes wool_patch_cloak with +5 maximum HP and active=true")

	var tinker_coat: Dictionary = summary.heroes[2]["slots"][2]
	_check(tinker_coat["slot"] == "COAT" and tinker_coat["patch_id"] == "chain_stitched_coat"
		and tinker_coat["active"] == true and tinker_coat["rules_text"] == CHAIN_STITCHED_COAT_TEXT,
		"Tinker COAT publishes chain_stitched_coat with +7 maximum HP and active=true")

	for i in range(3):
		_check(summary.heroes[i]["slots"][0]["patch_id"] == ""
			and summary.heroes[i]["slots"][0]["rules_text"] == ""
			and not summary.heroes[i]["slots"][0]["active"],
			summary.heroes[i]["id"] + " HEAD slot is empty and inactive")
		_check(summary.heroes[i]["slots"][1]["patch_id"] == ""
			and summary.heroes[i]["slots"][1]["rules_text"] == ""
			and not summary.heroes[i]["slots"][1]["active"],
			summary.heroes[i]["id"] + " ARM slot is empty and inactive")

	var health_proj := RunPatchCoatRules.project_health(torn_state, w, catalogs["coat"])
	_check(health_proj.get("ok") == true, "RunPatchCoatRules projects health with all 3 new coats")
	if health_proj.get("ok") == true:
		_check(health_proj.heroes[0]["max_hp"] == 43 and health_proj.heroes[0]["hp"] == 40,
			"Warden effective max HP projected as 40 + 3 = 43 while stored hp is 40")
		_check(health_proj.heroes[1]["max_hp"] == 35 and health_proj.heroes[1]["hp"] == 30,
			"Seamstress effective max HP projected as 30 + 5 = 35 while stored hp is 30")
		_check(health_proj.heroes[2]["max_hp"] == 33 and health_proj.heroes[2]["hp"] == 26,
			"Tinker effective max HP projected as 26 + 7 = 33 while stored hp is 26")
		_check(torn_state.heroes[0]["max_hp"] == 40 and torn_state.heroes[1]["max_hp"] == 30
			and torn_state.heroes[2]["max_hp"] == 26,
			"base max HP in torn state remains 40, 30, 26")

	# Torn suppression for one newly worn coat (Warden scrap_lined_vest)
	var b_start: Array = torn_state.heroes
	var b_end: Array = b_start.duplicate(true)
	b_end[0]["hp"] = 0
	_check(torn.observe_battle_end("new_coat_battle_tear", b_start, b_end).ok,
		"real battle ends with Warden torn")
	var torn_state2 := torn.read_state()
	var w_snap := w.get_snapshot()
	_check(w.refresh_run_context(torn_state2.heroes, w_snap.owned, w_snap.scraps,
		w_snap.gold, w_snap.cards, w_snap),
		"wardrobe refreshed to reflect torn Warden")
	var torn_summary := RunPatchWearerSummary.summarize(w, torn_state2)
	_check(torn_summary.get("ok") == true, "summarize succeeds after Warden torn")
	if torn_summary.get("ok") == true:
		var w_torn_coat: Dictionary = torn_summary.heroes[0]["slots"][2]
		_check(w_torn_coat["patch_id"] == "scrap_lined_vest" and w_torn_coat["active"] == false
			and w_torn_coat["rules_text"] == SCRAP_LINED_VEST_TEXT,
			"torn Warden keeps scrap_lined_vest described (+3 maximum HP) but active=false")
	var torn_proj := RunPatchCoatRules.project_health(torn_state2, w, catalogs["coat"])
	_check(torn_proj.get("ok") == true, "project_health succeeds on torn roster")
	if torn_proj.get("ok") == true:
		_check(torn_proj.heroes[0]["max_hp"] == 37,
			"torn Warden max HP remains 37 (40-3, no coat bonus)")
		_check(torn_proj.heroes[1]["max_hp"] == 35,
			"living Seamstress max HP remains 35 (30+5)")
		_check(torn_proj.heroes[2]["max_hp"] == 33,
			"living Tinker max HP remains 33 (26+7)")

	# Legal mend on Warden (2 scraps)
	var mend_w := torn.choose_mend("mend_new_coat", "receipt_new_coat", "warden", 1, 2,
		torn_state2.heroes, true)
	_check(mend_w.get("ok") == true, "Warden mended successfully")
	var state_after_mend := torn.read_state()
	var w_snap2 := w.get_snapshot()
	_check(w.refresh_run_context(state_after_mend.heroes, w_snap2.owned, w_snap2.scraps,
		w_snap2.gold, w_snap2.cards, w_snap2),
		"wardrobe refreshed after Warden mend")
	var mended_summary := RunPatchWearerSummary.summarize(w, state_after_mend)
	_check(mended_summary.get("ok") == true, "summarize succeeds after Warden mend")
	if mended_summary.get("ok") == true:
		var w_mended_coat: Dictionary = mended_summary.heroes[0]["slots"][2]
		_check(w_mended_coat["patch_id"] == "scrap_lined_vest" and w_mended_coat["active"] == true
			and w_mended_coat["rules_text"] == SCRAP_LINED_VEST_TEXT,
			"mended Warden reactivates scrap_lined_vest with +3 maximum HP")
	var mended_proj := RunPatchCoatRules.project_health(state_after_mend, w, catalogs["coat"])
	_check(mended_proj.get("ok") == true, "project_health succeeds after mend")
	if mended_proj.get("ok") == true:
		_check(mended_proj.heroes[0]["max_hp"] == 40,
			"mended Warden max HP is 37 + 3 = 40")
		_check(mended_proj.heroes[0]["hp"] == state_after_mend.heroes[0]["hp"],
			"projection does not change current HP")
	_check(RunPatchCoatRules.project_health(state_after_mend, w, catalogs["coat"]) == mended_proj,
		"repeated projection is exact and non-stacking")

	# Preview on a valid owned, unworn new coat
	var prev_f := _fixture(2)
	if prev_f.is_empty():
		return
	var pw: RunPatchWardrobe = prev_f.wardrobe
	var ptorn := RunTornMending.new(prev_f.heroes)
	var ptorn_state := ptorn.read_state()
	var pre_snap := pw.get_snapshot()
	var scrap_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "scrap_lined_vest", "warden")
	_check(scrap_prev.get("ok") == true and scrap_prev.get("patch_id") == "scrap_lined_vest"
		and scrap_prev.get("slot") == "COAT" and scrap_prev.get("rules_text") == SCRAP_LINED_VEST_TEXT
		and scrap_prev.get("wearer") == "warden" and scrap_prev.get("displaced_id") == ""
		and scrap_prev.get("scrap_delta") == 0,
		"empty COAT preview for Scrap Lined Vest on Warden matches specification")
	var wool_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "wool_patch_cloak", "seamstress")
	_check(wool_prev.get("ok") == true and wool_prev.get("patch_id") == "wool_patch_cloak"
		and wool_prev.get("slot") == "COAT" and wool_prev.get("rules_text") == WOOL_PATCH_CLOAK_TEXT
		and wool_prev.get("wearer") == "seamstress" and wool_prev.get("displaced_id") == ""
		and wool_prev.get("scrap_delta") == 0,
		"empty COAT preview for Wool Patch Cloak on Seamstress matches specification")
	_check(pw.get_snapshot() == pre_snap, "wardrobe snapshot unchanged after new coat previews")
	_check(ptorn.read_state() == ptorn_state, "torn ledger unchanged after new coat previews")


func _test_m05_coat_patches_lifecycle() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var heroes: Array = f.heroes
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}
	var reject_preview := {"ok": false}

	# Sew reinforced_patchcoat (+9) on Warden, thick_felt_mantle (+10) on Seamstress, Tinker unpatched
	_check(w.sew("reinforced_patchcoat", "warden", "COAT", "sew_reinf_m05", w.get_snapshot()).ok,
		"Reinforced Patchcoat is sewn onto Warden COAT")
	_check(w.sew("thick_felt_mantle", "seamstress", "COAT", "sew_thick_m05", w.get_snapshot()).ok,
		"Thick Felt Mantle is sewn onto Seamstress COAT")

	var torn := RunTornMending.new(heroes)
	_check(torn.is_valid(), "RunTornMending accepts starter party for M05 coat tests")
	var torn_state := torn.read_state()
	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.get("ok") == true, "summarize succeeds with M05 coats sewn")
	if summary.get("ok") != true:
		return

	# AC3: summarize shows exact catalog-validated +9/+10 maximum HP rules, COAT slot and proper active flags
	var warden_coat: Dictionary = summary.heroes[0]["slots"][2]
	_check(warden_coat["slot"] == "COAT" and warden_coat["patch_id"] == "reinforced_patchcoat"
		and warden_coat["active"] == true and warden_coat["rules_text"] == REINFORCED_PATCHCOAT_TEXT,
		"Warden COAT publishes reinforced_patchcoat with +9 maximum HP and active=true")

	var seamstress_coat: Dictionary = summary.heroes[1]["slots"][2]
	_check(seamstress_coat["slot"] == "COAT" and seamstress_coat["patch_id"] == "thick_felt_mantle"
		and seamstress_coat["active"] == true and seamstress_coat["rules_text"] == THICK_FELT_MANTLE_TEXT,
		"Seamstress COAT publishes thick_felt_mantle with +10 maximum HP and active=true")

	var tinker_coat: Dictionary = summary.heroes[2]["slots"][2]
	_check(tinker_coat["slot"] == "COAT" and tinker_coat["patch_id"] == ""
		and tinker_coat["active"] == false and tinker_coat["rules_text"] == "",
		"unpatched Tinker COAT slot is empty, inactive and has no rules text")

	for i in range(3):
		_check(summary.heroes[i]["slots"][0]["patch_id"] == ""
			and summary.heroes[i]["slots"][0]["rules_text"] == ""
			and not summary.heroes[i]["slots"][0]["active"],
			summary.heroes[i]["id"] + " HEAD slot is empty and inactive")
		_check(summary.heroes[i]["slots"][1]["patch_id"] == ""
			and summary.heroes[i]["slots"][1]["rules_text"] == ""
			and not summary.heroes[i]["slots"][1]["active"],
			summary.heroes[i]["id"] + " ARM slot is empty and inactive")

	# RunPatchCoatRules effective max HP: Warden 40+9=49, Seamstress 30+10=40, Tinker 26
	var health_proj := RunPatchCoatRules.project_health(torn_state, w, catalogs["coat"])
	_check(health_proj.get("ok") == true, "RunPatchCoatRules projects health with M05 coats")
	if health_proj.get("ok") == true:
		_check(health_proj.heroes[0]["max_hp"] == 49 and health_proj.heroes[0]["hp"] == 40,
			"Warden effective max HP projected as 40 + 9 = 49 while stored hp is 40")
		_check(health_proj.heroes[1]["max_hp"] == 40 and health_proj.heroes[1]["hp"] == 30,
			"Seamstress effective max HP projected as 30 + 10 = 40 while stored hp is 30")
		_check(health_proj.heroes[2]["max_hp"] == 26 and health_proj.heroes[2]["hp"] == 26,
			"unpatched Tinker effective max HP remains 26 while stored hp is 26")
		_check(torn_state.heroes[0]["max_hp"] == 40 and torn_state.heroes[1]["max_hp"] == 30
			and torn_state.heroes[2]["max_hp"] == 26,
			"base max HP in torn state remains 40, 30, 26")

	# AC3: Authoritative catalog validation rejects unsupported advertised powers
	var corrupted_checks := [
		["coat", "reinforced_patchcoat", "max_hp_bonus", 8, "reinforced_patchcoat wrong bonus"],
		["coat", "reinforced_patchcoat", "slot", "ARM", "reinforced_patchcoat wrong slot"],
		["coat", "thick_felt_mantle", "max_hp_bonus", 12, "thick_felt_mantle wrong bonus"],
		["coat", "thick_felt_mantle", "slot", "HEAD", "thick_felt_mantle wrong slot"],
	]
	for c in corrupted_checks:
		var corrupted := _with_field(catalogs, c[0], c[1], c[2], c[3])
		_check(RunPatchWearerSummary.summarize(w, torn_state, corrupted) == rejected,
			c[4] + " makes summarize refuse")
		_check(RunPatchWearerSummary.preview_sew(w, torn_state, c[1], "warden", corrupted) == reject_preview,
			c[4] + " makes preview_sew refuse")

	# AC3: Preview sew on empty slots
	var prev_f := _fixture(2)
	if prev_f.is_empty():
		return
	var pw: RunPatchWardrobe = prev_f.wardrobe
	var ptorn := RunTornMending.new(prev_f.heroes)
	var ptorn_state := ptorn.read_state()
	var pre_snap := pw.get_snapshot()

	var reinf_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "reinforced_patchcoat", "warden")
	_check(reinf_prev.get("ok") == true and reinf_prev.get("patch_id") == "reinforced_patchcoat"
		and reinf_prev.get("slot") == "COAT" and reinf_prev.get("rules_text") == REINFORCED_PATCHCOAT_TEXT
		and reinf_prev.get("wearer") == "warden" and reinf_prev.get("displaced_id") == ""
		and reinf_prev.get("displaced_rules_text") == "" and reinf_prev.get("scrap_delta") == 0,
		"empty COAT preview for reinforced_patchcoat on Warden shows +9 maximum HP, scrap_delta 0")

	var thick_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "thick_felt_mantle", "seamstress")
	_check(thick_prev.get("ok") == true and thick_prev.get("patch_id") == "thick_felt_mantle"
		and thick_prev.get("slot") == "COAT" and thick_prev.get("rules_text") == THICK_FELT_MANTLE_TEXT
		and thick_prev.get("wearer") == "seamstress" and thick_prev.get("displaced_id") == ""
		and thick_prev.get("displaced_rules_text") == "" and thick_prev.get("scrap_delta") == 0,
		"empty COAT preview for thick_felt_mantle on Seamstress shows +10 maximum HP, scrap_delta 0")

	_check(pw.get_snapshot() == pre_snap and ptorn.read_state() == ptorn_state,
		"previews leave wardrobe and torn state completely untouched")

	# Preview sew on occupied slot: displace reinforced_patchcoat with thick_felt_mantle
	_check(pw.sew("reinforced_patchcoat", "warden", "COAT", "prev_sew_reinf", pw.get_snapshot()).ok,
		"Warden equips reinforced_patchcoat before displacement preview")
	var occ_snap := pw.get_snapshot()

	var occ_thick_prev := RunPatchWearerSummary.preview_sew(pw, ptorn_state, "thick_felt_mantle", "warden")
	_check(occ_thick_prev.get("ok") == true and occ_thick_prev.get("patch_id") == "thick_felt_mantle"
		and occ_thick_prev.get("slot") == "COAT" and occ_thick_prev.get("rules_text") == THICK_FELT_MANTLE_TEXT
		and occ_thick_prev.get("wearer") == "warden" and occ_thick_prev.get("displaced_id") == "reinforced_patchcoat"
		and occ_thick_prev.get("displaced_rules_text") == REINFORCED_PATCHCOAT_TEXT
		and occ_thick_prev.get("scrap_delta") == 1,
		"occupied preview: thick_felt_mantle displacing reinforced_patchcoat shows +1 scrap and displaced text")
	_check(pw.get_snapshot() == occ_snap, "wardrobe unchanged by occupied preview")

	# Commit sew replacement and verify receipt matches preview
	var commit_thick := pw.sew("thick_felt_mantle", "warden", "COAT", "commit_thick_m05", pw.get_snapshot())
	_check(commit_thick.get("ok") == true, "commit sew of thick_felt_mantle succeeds")
	if commit_thick.get("ok") == true:
		var rc: Dictionary = commit_thick.get("receipt", {})
		_check(rc.get("patch_id") == "thick_felt_mantle" and rc.get("hero_id") == "warden"
			and rc.get("slot") == "COAT" and rc.get("displaced_id") == "reinforced_patchcoat"
			and rc.get("scrap_delta") == 1,
			"commit receipt matches preview: displaced reinforced_patchcoat for 1 scrap")
		var post_w := pw.get_snapshot()
		_check(post_w.scraps == occ_snap.scraps + 1, "scraps increased by 1 upon displacing coat")
		_check(not post_w.owned.has("reinforced_patchcoat"), "displaced reinforced_patchcoat destroyed")
		_check(post_w.worn["warden"]["COAT"] == "thick_felt_mantle", "Warden now wears thick_felt_mantle")

	# AC3: Torn suppression: down Warden in battle
	var b_start: Array = torn_state.heroes
	var b_end: Array = b_start.duplicate(true)
	b_end[0]["hp"] = 0
	_check(torn.observe_battle_end("m05_battle_tear", b_start, b_end).ok,
		"battle ends with Warden torn")
	var torn_state2 := torn.read_state()
	var w_snap := w.get_snapshot()
	_check(w.refresh_run_context(torn_state2.heroes, w_snap.owned, w_snap.scraps,
		w_snap.gold, w_snap.cards, w_snap),
		"wardrobe refreshed after Warden torn")
	var torn_summary := RunPatchWearerSummary.summarize(w, torn_state2)
	_check(torn_summary.get("ok") == true, "summarize succeeds after Warden torn")
	if torn_summary.get("ok") == true:
		var w_torn_coat: Dictionary = torn_summary.heroes[0]["slots"][2]
		_check(w_torn_coat["patch_id"] == "reinforced_patchcoat" and w_torn_coat["active"] == false
			and w_torn_coat["rules_text"] == REINFORCED_PATCHCOAT_TEXT,
			"torn Warden keeps reinforced_patchcoat visible (+9 maximum HP) but active=false")
		var s_live_coat: Dictionary = torn_summary.heroes[1]["slots"][2]
		_check(s_live_coat["patch_id"] == "thick_felt_mantle" and s_live_coat["active"] == true
			and s_live_coat["rules_text"] == THICK_FELT_MANTLE_TEXT,
			"living Seamstress keeps thick_felt_mantle active=true and described")

	# AC3: RunPatchCoatRules gives no bonus to torn wearer
	var torn_proj := RunPatchCoatRules.project_health(torn_state2, w, catalogs["coat"])
	_check(torn_proj.get("ok") == true, "project_health succeeds on torn roster")
	if torn_proj.get("ok") == true:
		_check(torn_proj.heroes[0]["max_hp"] == 37,
			"torn Warden max HP remains 37 (40-3, no coat bonus)")
		_check(torn_proj.heroes[1]["max_hp"] == 40,
			"living Seamstress max HP remains 40 (30+10)")
		_check(torn_proj.heroes[2]["max_hp"] == 26,
			"unpatched Tinker max HP remains 26")

	# AC3: Legal map mend on Warden (costs 2 scraps) -> reactivates without healing from coat
	var mend_w := torn.choose_mend("mend_m05_w", "rc_mend_m05_w", "warden", 1, 4,
		torn_state2.heroes, true)
	_check(mend_w.get("ok") == true, "Warden mended successfully")
	var state_after_mend := torn.read_state()
	var w_snap2 := w.get_snapshot()
	_check(w.refresh_run_context(state_after_mend.heroes, w_snap2.owned, w_snap2.scraps,
		w_snap2.gold, w_snap2.cards, w_snap2),
		"wardrobe refreshed after Warden mend")
	var mended_summary := RunPatchWearerSummary.summarize(w, state_after_mend)
	_check(mended_summary.get("ok") == true, "summarize succeeds after Warden mend")
	if mended_summary.get("ok") == true:
		var w_mended_coat: Dictionary = mended_summary.heroes[0]["slots"][2]
		_check(w_mended_coat["patch_id"] == "reinforced_patchcoat" and w_mended_coat["active"] == true
			and w_mended_coat["rules_text"] == REINFORCED_PATCHCOAT_TEXT,
			"mended Warden reactivates reinforced_patchcoat with +9 maximum HP")

	var mended_proj := RunPatchCoatRules.project_health(state_after_mend, w, catalogs["coat"])
	_check(mended_proj.get("ok") == true, "project_health succeeds after mend")
	if mended_proj.get("ok") == true:
		_check(mended_proj.heroes[0]["max_hp"] == 46,
			"mended Warden max HP is 37 + 9 = 46")
		_check(mended_proj.heroes[0]["hp"] == state_after_mend.heroes[0]["hp"],
			"effective max HP projection does not heal HP")

	# AC3: Rest revival route: tear Seamstress in battle
	var s_start: Array = state_after_mend.heroes
	var s_end: Array = s_start.duplicate(true)
	s_end[1]["hp"] = 0
	_check(torn.observe_battle_end("m05_s_tear", s_start, s_end).ok, "Seamstress torn in battle")
	var s_down_state := torn.read_state()
	var w_snap3 := w.get_snapshot()
	_check(w.refresh_run_context(s_down_state.heroes, w_snap3.owned, w_snap3.scraps,
		w_snap3.gold, w_snap3.cards, w_snap3),
		"wardrobe refreshed after Seamstress torn")
	var s_down_summary := RunPatchWearerSummary.summarize(w, s_down_state)
	_check(s_down_summary.get("ok") == true, "summarize succeeds when Seamstress torn")
	if s_down_summary.get("ok") == true:
		var s_down_coat: Dictionary = s_down_summary.heroes[1]["slots"][2]
		_check(s_down_coat["patch_id"] == "thick_felt_mantle" and s_down_coat["active"] == false
			and s_down_coat["rules_text"] == THICK_FELT_MANTLE_TEXT,
			"torn Seamstress keeps thick_felt_mantle described (+10 maximum HP) but active=false")

	# Rest revival
	_check(torn.apply_rest("rest_m05_summary_revival", s_down_state.heroes, true).ok,
		"Rest revival revives Seamstress")
	var s_revived_state := torn.read_state()
	var w_snap4 := w.get_snapshot()
	_check(w.refresh_run_context(s_revived_state.heroes, w_snap4.owned, w_snap4.scraps,
		w_snap4.gold, w_snap4.cards, w_snap4),
		"wardrobe refreshed after Rest revival")
	var s_revived_summary := RunPatchWearerSummary.summarize(w, s_revived_state)
	_check(s_revived_summary.get("ok") == true, "summarize succeeds after Rest revival")
	if s_revived_summary.get("ok") == true:
		var s_rev_coat: Dictionary = s_revived_summary.heroes[1]["slots"][2]
		_check(s_rev_coat["patch_id"] == "thick_felt_mantle" and s_rev_coat["active"] == true
			and s_rev_coat["rules_text"] == THICK_FELT_MANTLE_TEXT,
			"Rest revived Seamstress reactivates thick_felt_mantle (+10 maximum HP)")
	var s_rev_proj := RunPatchCoatRules.project_health(s_revived_state, w, catalogs["coat"])
	_check(s_rev_proj.get("ok") == true and s_rev_proj.heroes[1]["max_hp"] == 37,
		"Rest revived Seamstress max HP is 27 + 10 = 37")

	# AC4: Rest re-sew/swap between living heroes
	_check(w.start_rest("rest_m05_summary_swap", w.get_snapshot()).ok, "Rest opens for re-sew")
	var resew_res := w.re_sew("reinforced_patchcoat", "warden", "tinker",
		"rest_m05_summary_swap", "resew_w_to_t", w.get_snapshot())
	_check(resew_res.ok and resew_res.receipt.scrap_delta == -1,
		"moving reinforced_patchcoat from Warden to Tinker costs 1 scrap")
	var post_move_summary := RunPatchWearerSummary.summarize(w, s_revived_state)
	_check(post_move_summary.get("ok") == true, "summarize succeeds after Rest move")
	if post_move_summary.get("ok") == true:
		_check(post_move_summary.heroes[0]["slots"][2]["patch_id"] == ""
			and not post_move_summary.heroes[0]["slots"][2]["active"],
			"Warden COAT slot is now empty and inactive")
		_check(post_move_summary.heroes[2]["slots"][2]["patch_id"] == "reinforced_patchcoat"
			and post_move_summary.heroes[2]["slots"][2]["active"] == true
			and post_move_summary.heroes[2]["slots"][2]["rules_text"] == REINFORCED_PATCHCOAT_TEXT,
			"Tinker COAT slot now has reinforced_patchcoat active (+9 maximum HP)")
	_check(w.end_rest("rest_m05_summary_swap", w.get_snapshot()).ok, "Rest ends cleanly")


## AC1/AC2/AC3: the authored Borrowed Button COAT record is described through
## the existing catalog-authenticated summary and preview route, keeps its text
## when torn, and fails closed when the M05 COAT catalog is falsified.
func _test_borrowed_button_readout() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}
	var reject_preview := {"ok": false}

	var records := _records(catalogs, "borrowed_button")
	_check(records.size() == 1, "exactly one shipped record authors borrowed_button")
	if records.size() == 1:
		var record: Dictionary = records[0]
		_check(record["id"] == "borrowed_button" and record["slot"] == "COAT"
			and record["effect"] == "other_hero_committed_heal_block"
			and int(record["heal_threshold"]) == 1 and int(record["block"]) == 3
			and int(record["uses_per_combat"]) == 1,
			"borrowed_button authors one other-hero heal for exactly 3 Block once per combat")
	elif records.is_empty():
		return

	var torn := RunTornMending.new(f.heroes)
	_check(torn.is_valid(), "the Borrowed Button fixture has a real torn ledger")
	var torn_state := torn.read_state()
	var before_w := w.get_snapshot()
	var before_t := torn.read_state()
	var local := RandomNumberGenerator.new()
	local.seed = 77129
	var local_before: int = local.state
	seed(93217)
	var global_next: int = randi()
	seed(93217)

	var empty_preview := RunPatchWearerSummary.preview_sew(
		w, torn_state, "borrowed_button", "tinker")
	_check(empty_preview.get("ok") == true
		and empty_preview.get("patch_id") == "borrowed_button"
		and empty_preview.get("slot") == "COAT"
		and empty_preview.get("rules_text") == BORROWED_BUTTON_TEXT
		and empty_preview.get("wearer") == "tinker"
		and empty_preview.get("displaced_id") == ""
		and empty_preview.get("displaced_rules_text") == ""
		and empty_preview.get("scrap_delta") == 0,
		"a legal empty-COAT preview publishes the authored once-per-combat Block condition")
	_check(w.get_snapshot() == before_w and torn.read_state() == before_t
		and local.state == local_before and randi() == global_next,
		"the preview changes neither ledger and consumes no local or global RNG")

	_check(w.sew("quilted_coat", "warden", "COAT", "bb_prior_coat", w.get_snapshot()).ok,
		"a real M04 COAT is worn before the displacement preview")
	var occupied_w := w.get_snapshot()
	var displaced_preview := RunPatchWearerSummary.preview_sew(
		w, torn_state, "borrowed_button", "warden")
	_check(displaced_preview.get("ok") == true
		and displaced_preview.get("patch_id") == "borrowed_button"
		and displaced_preview.get("slot") == "COAT"
		and displaced_preview.get("rules_text") == BORROWED_BUTTON_TEXT
		and displaced_preview.get("wearer") == "warden"
		and displaced_preview.get("displaced_id") == "quilted_coat"
		and displaced_preview.get("displaced_rules_text") == COAT_TEXT
		and displaced_preview.get("scrap_delta") == 1,
		"a filled-COAT preview forecasts the displaced coat text and exactly one scrap")
	_check(w.get_snapshot() == occupied_w and torn.read_state() == before_t,
		"the displacement preview changes neither ledger")

	var sew_eye := w.sew("button_eye", "seamstress", "HEAD", "bb_eye", w.get_snapshot())
	_check(sew_eye.get("ok") == true,
		"an established HEAD readout wearer is sewn alongside Borrowed Button")
	var baseline := RunPatchWearerSummary.summarize(w, torn_state)
	_check(baseline.get("ok") == true, "the readout before the Borrowed Button sew is genuine")
	var sewn := w.sew("borrowed_button", "warden", "COAT", "bb_sew", w.get_snapshot())
	_check(sewn.get("ok") == true and sewn.get("receipt", {}).get("patch_id") == "borrowed_button"
		and sewn.get("receipt", {}).get("hero_id") == "warden"
		and sewn.get("receipt", {}).get("slot") == "COAT"
		and sewn.get("receipt", {}).get("displaced_id") == "quilted_coat"
		and sewn.get("receipt", {}).get("scrap_delta") == 1,
		"the real sew receipt matches the previewed displacement and scrap")

	var summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(summary.get("ok") == true, "the genuine readout publishes the sewn Borrowed Button")
	if summary.get("ok") != true:
		return
	var coat: Dictionary = summary.heroes[0]["slots"][2]
	_check(coat["slot"] == "COAT" and coat["patch_id"] == "borrowed_button"
		and coat["active"] == true and coat["rules_text"] == BORROWED_BUTTON_TEXT,
		"the living wearer shows one active Borrowed Button with its exact condition")
	_check(coat["rules_text"].contains("Once per combat")
		and coat["rules_text"].contains("another living hero")
		and coat["rules_text"].contains("at least 1 HP")
		and coat["rules_text"].contains("gain 3 Block")
		and not coat["rules_text"].contains("maximum HP"),
		"the description names the once-per-combat other-hero actual-heal +3 Block condition")
	for s in range(2):
		_check(summary.heroes[0]["slots"][s]["patch_id"] == ""
			and summary.heroes[0]["slots"][s]["rules_text"] == ""
			and not summary.heroes[0]["slots"][s]["active"],
			"the Borrowed Button wearer keeps its other slots empty")
	var eye: Dictionary = summary.heroes[1]["slots"][0]
	_check(eye["patch_id"] == "button_eye" and eye["active"] == true
		and eye["rules_text"] == EYE_TEXT,
		"an established HEAD power keeps its authored identity and description")
	for s in [1, 2]:
		_check(summary.heroes[1]["slots"][s]["patch_id"] == ""
			and summary.heroes[1]["slots"][s]["rules_text"] == "",
			"the other wearer's remaining slots stay untouched")
	for s in range(3):
		_check(summary.heroes[2]["slots"][s]["patch_id"] == ""
			and summary.heroes[2]["slots"][s]["rules_text"] == ""
			and not summary.heroes[2]["slots"][s]["active"],
			"a wearer without patches inherits nothing from Borrowed Button")
	_check(baseline.get("ok") == true and summary.heroes[1] == baseline.heroes[1]
		and summary.heroes[2] == baseline.heroes[2]
		and summary.heroes[0]["slots"][0] == baseline.heroes[0]["slots"][0]
		and summary.heroes[0]["slots"][1] == baseline.heroes[0]["slots"][1],
		"the other wearers and unaffected slots keep their exact earlier records")
	var no_bonus := RunPatchCoatRules.project_health(torn_state, w, catalogs["coat"])
	_check(no_bonus.get("ok") == true and no_bonus.heroes[0]["max_hp"] == 40
		and no_bonus.heroes[0]["hp"] == 40,
		"the Borrowed Button COAT never projects a maximum-HP bonus or heal")

	# A genuinely torn wearer keeps the description but publishes inactive.
	var start: Array = torn_state.heroes
	var ending: Array = start.duplicate(true)
	ending[0]["hp"] = 0
	_check(torn.observe_battle_end("bb_battle_tear", start, ending).ok,
		"the real ledger witnesses the Borrowed Button wearer's tear")
	var downed := torn.read_state()
	var w_snap := w.get_snapshot()
	_check(w.refresh_run_context(downed.heroes, w_snap.owned, w_snap.scraps,
		w_snap.gold, w_snap.cards, w_snap),
		"the wardrobe is refreshed to the genuine torn roster")
	var down_summary := RunPatchWearerSummary.summarize(w, downed)
	_check(down_summary.get("ok") == true, "the summary survives the tear")
	if down_summary.get("ok") != true:
		return
	var down_coat: Dictionary = down_summary.heroes[0]["slots"][2]
	_check(down_coat["patch_id"] == "borrowed_button" and down_coat["active"] == false
		and down_coat["rules_text"] == BORROWED_BUTTON_TEXT,
		"the torn wearer keeps the same Borrowed Button explanation as inactive")
	_check(down_summary.heroes[1]["slots"][0]["patch_id"] == "button_eye"
		and down_summary.heroes[1]["slots"][0]["active"] == true
		and down_summary.heroes[1]["slots"][0]["rules_text"] == EYE_TEXT,
		"the living wearer's established description is unchanged by the tear")
	var before_downed := w.get_snapshot()
	_check(RunPatchWearerSummary.preview_sew(w, downed,
		"padded_vest", "warden") == reject_preview,
		"a torn wearer cannot preview a new sew")
	_check(w.get_snapshot() == before_downed and torn.read_state() == downed,
		"the refused torn preview changes neither ledger")

	var mend := torn.choose_mend("bb_mend_node", "bb_mend_receipt", "warden", 1, 2,
		downed.heroes, true)
	_check(mend.get("ok") == true and mend.get("heroes")[0]["hp"] == 9,
		"the real mend restores the Borrowed Button wearer")
	var mended := torn.read_state()
	var mended_w := w.get_snapshot()
	_check(w.refresh_run_context(mended.heroes, mended_w.owned, mended_w.scraps,
		mended_w.gold, mended_w.cards, mended_w),
		"the wardrobe is refreshed to the mended roster")
	var mended_summary := RunPatchWearerSummary.summarize(w, mended)
	_check(mended_summary.get("ok") == true, "the summary survives the mend")
	if mended_summary.get("ok") == true:
		var mended_coat: Dictionary = mended_summary.heroes[0]["slots"][2]
		_check(mended_coat["patch_id"] == "borrowed_button" and mended_coat["active"] == true
			and mended_coat["rules_text"] == BORROWED_BUTTON_TEXT,
			"the permitted mend restores Borrowed Button eligibility with the same text")
	var eligibility := RunPatchWearerSummary.preview_sew(w, mended, "padded_vest", "warden")
	_check(eligibility.get("ok") == true and eligibility.get("slot") == "COAT"
		and eligibility.get("rules_text") == PADDED_VEST_TEXT
		and eligibility.get("displaced_id") == "borrowed_button"
		and eligibility.get("displaced_rules_text") == BORROWED_BUTTON_TEXT
		and eligibility.get("scrap_delta") == 1,
		"the mended wearer previews a COAT replacement with the Borrowed Button text displaced")

	# A genuinely unknown COAT patch is still named, but never invents a rule.
	var future_w := RunPatchWardrobe.new(f.heroes, ["future_coat_patch"],
		[{"id": "future_coat_patch", "slot": "COAT"}], 2, 170,
		["warden_strike"], 8197)
	_check(future_w.is_valid(), "the unknown COAT fixture is a real ledger")
	var future_preview := RunPatchWearerSummary.preview_sew(
		future_w, torn_state, "future_coat_patch", "warden")
	_check(future_preview.get("ok") == true and future_preview.get("slot") == "COAT"
		and future_preview.get("wearer") == "warden"
		and future_preview.get("rules_text") == "",
		"an unknown COAT preview keeps its slot without fabricating a power")
	_check(future_w.sew("future_coat_patch", "tinker",
		"COAT", "future_coat_sew", future_w.get_snapshot()).ok,
		"an unknown COAT patch can be sewn in a real ledger")
	var future_summary := RunPatchWearerSummary.summarize(future_w, torn_state)
	_check(future_summary.get("ok") == true
		and future_summary.heroes[2]["slots"][2]["patch_id"] == "future_coat_patch"
		and future_summary.heroes[2]["slots"][2]["active"] == true
		and future_summary.heroes[2]["slots"][2]["rules_text"] == "",
		"an unknown COAT patch remains visible without an invented rule")

	# AC3: missing, duplicated or falsified M05 COAT records fail closed.
	var guarded_w := w.get_snapshot()
	var guarded_t := torn.read_state()
	var guard := RunPatchWearerSummary.preview_sew(w, mended, "padded_vest", "tinker")
	_check(guard.get("ok") == true and guard.get("rules_text") == PADDED_VEST_TEXT,
		"the guard preview legitimately succeeds with the shipped catalog")
	var broken := [
		["a borrowed_button with a wrong slot", "slot", "ARM"],
		["a borrowed_button with a wrong effect", "effect", "other_hero_heal_block"],
		["a borrowed_button with a wrong heal threshold", "heal_threshold", 2],
		["a borrowed_button with a wrong Block", "block", 5],
		["a borrowed_button with a wrong use count", "uses_per_combat", 2],
		["a borrowed_button with a zero Block", "block", 0],
		["a borrowed_button with a string Block", "block", "3"],
	]
	for entry in broken:
		var patched := _with_field(catalogs, "m05_coat", "borrowed_button", entry[1], entry[2])
		_check(RunPatchWearerSummary.summarize(w, mended, patched) == rejected,
			str(entry[0]) + " is rejected exactly")
		_check(RunPatchWearerSummary.preview_sew(w, mended,
			"padded_vest", "tinker", patched) == reject_preview,
			str(entry[0]) + " refuses every preview")
	for field in ["heal_threshold", "block", "uses_per_combat"]:
		var patched := _without_field(catalogs, "m05_coat", "borrowed_button", field)
		_check(RunPatchWearerSummary.summarize(w, mended, patched) == rejected,
			"a borrowed_button without " + field + " is rejected exactly")
		_check(RunPatchWearerSummary.preview_sew(w, mended,
			"padded_vest", "tinker", patched) == reject_preview,
			"a borrowed_button without " + field + " refuses every preview")
	var missing := _without_record(catalogs, "m05_coat", "borrowed_button")
	_check(RunPatchWearerSummary.summarize(w, mended, missing) == rejected,
		"a missing borrowed_button record is rejected exactly")
	_check(RunPatchWearerSummary.preview_sew(w, mended,
		"padded_vest", "tinker", missing) == reject_preview,
		"a missing borrowed_button record refuses every preview")
	var duplicated := _with_duplicate_record(catalogs, "m05_coat", "borrowed_button")
	_check(RunPatchWearerSummary.summarize(w, mended, duplicated) == rejected,
		"a duplicated borrowed_button record is rejected exactly")
	_check(RunPatchWearerSummary.preview_sew(w, mended,
		"padded_vest", "tinker", duplicated) == reject_preview,
		"a duplicated borrowed_button record refuses every preview")
	_check(RunPatchWearerSummary.summarize(w, mended,
		{"m05_coat": "nonsense"}) == rejected,
		"a malformed M05 COAT catalog collection is rejected exactly")
	_check(w.get_snapshot() == guarded_w and torn.read_state() == guarded_t,
		"every M05 COAT rejection leaves both genuine ledgers unchanged")


func _m05_expectations() -> Dictionary:
	return {
		"bloodstitch_bonnet": {"slot": "HEAD", "text": M05_BLEED_TEXT},
		"button_glass_visor": {"slot": "HEAD", "text": M05_EXPOSED_TEXT},
		"stern_seam_cap": {"slot": "HEAD", "text": M05_WEAK_TEXT},
		"reinforced_browband": {"slot": "HEAD", "text": M05_HEAD_BLOCK_TEXT},
		"hemguard_cuff": {"slot": "ARM", "text": M05_ARM_BLOCK_TEXT},
		"red_bobbin_cuff": {"slot": "ARM", "text": M05_BLEED_TEXT},
		"loose_thread_glove": {"slot": "ARM", "text": M05_UNRAVEL_TEXT},
		"frayfinder_mitt": {"slot": "ARM", "text": M05_FRAYFINDER_TEXT},
	}


## AC1 and AC2: every shipped M05 HEAD/ARM record described for a genuine
## sewn living wearer and for an eligible empty-slot sew preview.
func _test_m05_head_and_arm_summary() -> void:
	var expectations := _m05_expectations()
	var slot_index := {"HEAD": 0, "ARM": 1}
	for id in expectations:
		var f := _fixture()
		if f.is_empty():
			return
		var w: RunPatchWardrobe = f.wardrobe
		var slot: String = expectations[id]["slot"]
		var text: String = expectations[id]["text"]
		var index: int = slot_index[slot]
		_check(w.sew(id, "warden", slot, "sew_" + id, w.get_snapshot()).ok,
			id + " is sewn onto the Warden " + slot)
		var torn := RunTornMending.new(f.heroes)
		_check(torn.is_valid(), id + " fixture has a real torn ledger")
		var torn_state := torn.read_state()
		var before_w := w.get_snapshot()
		var summary := RunPatchWearerSummary.summarize(w, torn_state)
		_check(summary.get("ok") == true, id + " living wearer publishes a summary")
		if summary.get("ok") != true:
			continue
		var worn: Dictionary = summary.heroes[0]["slots"][index]
		_check(worn["slot"] == slot and worn["patch_id"] == id and worn["active"] == true
			and worn["rules_text"] == text,
			id + " publishes its verified slot, active flag and authored effect")
		for s in range(3):
			if s == index:
				continue
			_check(summary.heroes[0]["slots"][s]["patch_id"] == ""
				and summary.heroes[0]["slots"][s]["rules_text"] == ""
				and not summary.heroes[0]["slots"][s]["active"],
				id + " leaves the Warden's other slots empty")
		for h in [1, 2]:
			for s in range(3):
				_check(summary.heroes[h]["slots"][s]["patch_id"] == ""
					and summary.heroes[h]["slots"][s]["rules_text"] == "",
					id + " affects only its own wearer")
		_check(w.get_snapshot() == before_w and torn.read_state() == torn_state,
			id + " summarizing changes neither ledger")

		var pf := _fixture()
		if pf.is_empty():
			return
		var pw: RunPatchWardrobe = pf.wardrobe
		var ptorn := RunTornMending.new(pf.heroes)
		var ptorn_state := ptorn.read_state()
		var before_pw := pw.get_snapshot()
		var preview := RunPatchWearerSummary.preview_sew(pw, ptorn_state, id, "tinker")
		_check(preview.get("ok") == true and preview.get("patch_id") == id
			and preview.get("slot") == slot and preview.get("rules_text") == text
			and preview.get("wearer") == "tinker" and preview.get("displaced_id") == ""
			and preview.get("displaced_rules_text") == "" and preview.get("scrap_delta") == 0,
			id + " empty-slot preview publishes the same truthful effect")
		_check(pw.get_snapshot() == before_pw and ptorn.read_state() == ptorn_state,
			id + " preview changes neither ledger")
		var sewn := pw.sew(id, "tinker", slot, "commit_" + id, pw.get_snapshot())
		_check(sewn.get("ok") == true and sewn.receipt.patch_id == id
			and sewn.receipt.slot == slot and sewn.receipt.displaced_id == ""
			and sewn.receipt.scrap_delta == 0,
			id + " real sew receipt matches the preview")
		var committed := RunPatchWearerSummary.summarize(pw, ptorn_state)
		var committed_slot: Dictionary = committed.heroes[2]["slots"][index]
		_check(committed.get("ok") == true and committed_slot["patch_id"] == id
			and committed_slot["active"] == true and committed_slot["rules_text"] == text,
			id + " committed sew then summarizes with the same authored effect")


## AC3: torn definitions keep their text but publish active=false, and a
## replacement preview keeps the exact displaced M05 text and +1 scrap.
func _test_m05_torn_and_replacement_previews() -> void:
	var f := _fixture(4)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	_check(w.sew("bloodstitch_bonnet", "warden", "HEAD", "m05_tear_head", w.get_snapshot()).ok
		and w.sew("frayfinder_mitt", "warden", "ARM", "m05_tear_arm", w.get_snapshot()).ok
		and w.sew("hemguard_cuff", "seamstress", "ARM", "m05_tear_hem", w.get_snapshot()).ok,
		"the M05 patches are sewn before the tear")
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var before_summary := RunPatchWearerSummary.summarize(w, torn_state)
	_check(before_summary.get("ok") == true
		and before_summary.heroes[0]["slots"][0]["rules_text"] == M05_BLEED_TEXT
		and before_summary.heroes[0]["slots"][1]["rules_text"] == M05_FRAYFINDER_TEXT
		and before_summary.heroes[1]["slots"][1]["rules_text"] == M05_ARM_BLOCK_TEXT,
		"all three living wearers publish their M05 effects")
	var before_w := w.get_snapshot()
	var replaced := RunPatchWearerSummary.preview_sew(w, torn_state,
		"reinforced_browband", "warden")
	_check(replaced.get("ok") == true and replaced.get("patch_id") == "reinforced_browband"
		and replaced.get("slot") == "HEAD" and replaced.get("rules_text") == M05_HEAD_BLOCK_TEXT
		and replaced.get("wearer") == "warden"
		and replaced.get("displaced_id") == "bloodstitch_bonnet"
		and replaced.get("displaced_rules_text") == M05_BLEED_TEXT
		and replaced.get("scrap_delta") == 1,
		"replacement preview reports the displaced M05 text and exactly one scrap")
	_check(w.get_snapshot() == before_w and torn.read_state() == torn_state,
		"the replacement preview changes neither ledger")
	var start: Array = torn_state.heroes
	var ending: Array = start.duplicate(true)
	ending[0]["hp"] = 0
	_check(torn.observe_battle_end("m05_head_arm_tear", start, ending).ok,
		"the real ledger witnesses the Warden tear")
	var downed := torn.read_state()
	_check(w.refresh_run_context(downed.heroes, before_w.owned, before_w.scraps,
		before_w.gold, before_w.cards, before_w),
		"the wardrobe is refreshed to the genuine torn roster")
	var down_summary := RunPatchWearerSummary.summarize(w, downed)
	_check(down_summary.get("ok") == true, "the summary survives the tear")
	if down_summary.get("ok") != true:
		return
	var torn_head: Dictionary = down_summary.heroes[0]["slots"][0]
	_check(torn_head["patch_id"] == "bloodstitch_bonnet" and torn_head["active"] == false
		and torn_head["rules_text"] == M05_BLEED_TEXT,
		"torn wearer keeps bloodstitch_bonnet as a definition but inactive")
	var torn_arm: Dictionary = down_summary.heroes[0]["slots"][1]
	_check(torn_arm["patch_id"] == "frayfinder_mitt" and torn_arm["active"] == false
		and torn_arm["rules_text"] == M05_FRAYFINDER_TEXT,
		"torn wearer keeps the full conditional Frayfinder text but inactive")
	var living_arm: Dictionary = down_summary.heroes[1]["slots"][1]
	_check(living_arm["patch_id"] == "hemguard_cuff" and living_arm["active"] == true
		and living_arm["rules_text"] == M05_ARM_BLOCK_TEXT,
		"the living Seamstress keeps hemguard_cuff active")
	var before_downed_preview := w.get_snapshot()
	_check(RunPatchWearerSummary.preview_sew(w, downed,
		"reinforced_browband", "warden") == {"ok": false},
		"a torn wearer cannot be previewed for a new sew")
	var living := RunPatchWearerSummary.preview_sew(w, downed,
		"reinforced_browband", "seamstress")
	_check(living.get("ok") == true and living.get("slot") == "HEAD"
		and living.get("rules_text") == M05_HEAD_BLOCK_TEXT
		and living.get("wearer") == "seamstress" and living.get("displaced_id") == ""
		and living.get("scrap_delta") == 0,
		"a living wearer still previews the same authored M05 effect after a tear")
	_check(w.get_snapshot() == before_downed_preview and torn.read_state() == downed,
		"torn and preview checks leave the torn ledger intact")


## AC3: tampered or missing known M05 records fail closed and never invent text.
func _test_m05_authority_fail_closed() -> void:
	var f := _fixture(2)
	if f.is_empty():
		return
	var w: RunPatchWardrobe = f.wardrobe
	var torn := RunTornMending.new(f.heroes)
	var torn_state := torn.read_state()
	var catalogs: Dictionary = f.catalogs
	var rejected := {"ok": false, "heroes": []}
	var reject_preview := {"ok": false}
	var before_w := w.get_snapshot()
	var before_t := torn.read_state()

	var broken := [
		["a bloodstitch_bonnet with a wrong amount", "m05_head",
			"bloodstitch_bonnet", "amount", 2],
		["a bloodstitch_bonnet with a wrong slot", "m05_head",
			"bloodstitch_bonnet", "slot", "ARM"],
		["a bloodstitch_bonnet with a wrong effect", "m05_head",
			"bloodstitch_bonnet", "effect", "card_weak_bonus"],
		["a button_glass_visor with a wrong amount", "m05_head",
			"button_glass_visor", "amount", 2],
		["a reinforced_browband with a wrong amount", "m05_head",
			"reinforced_browband", "amount", 1],
		["a hemguard_cuff with a wrong amount", "m05_arm",
			"hemguard_cuff", "amount", 1],
		["a hemguard_cuff with a wrong slot", "m05_arm",
			"hemguard_cuff", "slot", "HEAD"],
		["a red_bobbin_cuff with a wrong effect", "m05_arm",
			"red_bobbin_cuff", "effect", "card_weak_bonus"],
		["a loose_thread_glove with a wrong effect", "m05_arm",
			"loose_thread_glove", "effect", "card_bleed_bonus"],
		["a frayfinder_mitt with a wrong amount", "m05_attack",
			"frayfinder_mitt", "amount", 3],
		["a frayfinder_mitt with a wrong slot", "m05_attack",
			"frayfinder_mitt", "slot", "HEAD"],
		["a frayfinder_mitt without once_per_player_turn", "m05_attack",
			"frayfinder_mitt", "once_per_player_turn", false],
		["a frayfinder_mitt with a wrong hit_number", "m05_attack",
			"frayfinder_mitt", "hit_number", 2],
		["a frayfinder_mitt with a wrong target_kind", "m05_attack",
			"frayfinder_mitt", "target_kind", "enemy_all"],
		["a frayfinder_mitt with a wrong threshold numerator", "m05_attack",
			"frayfinder_mitt", "minimum_unravel_numerator", 2],
		["a frayfinder_mitt with a wrong threshold denominator", "m05_attack",
			"frayfinder_mitt", "minimum_unravel_denominator", 3],
	]
	for entry in broken:
		var patched := _with_field(catalogs, entry[1], entry[2], entry[3], entry[4])
		_check(RunPatchWearerSummary.summarize(w, torn_state, patched) == rejected,
			str(entry[0]) + " is rejected exactly")
		_check(RunPatchWearerSummary.preview_sew(w, torn_state,
			entry[2], "warden", patched) == reject_preview,
			str(entry[0]) + " cannot promise a forged preview")

	var missing_fields := [
		["m05_head", "stern_seam_cap", "amount"],
		["m05_head", "stern_seam_cap", "effect"],
		["m05_arm", "red_bobbin_cuff", "effect"],
		["m05_attack", "frayfinder_mitt", "amount"],
		["m05_attack", "frayfinder_mitt", "minimum_unravel_numerator"],
		["m05_attack", "frayfinder_mitt", "minimum_unravel_denominator"],
		["m05_attack", "frayfinder_mitt", "once_per_player_turn"],
		["m05_attack", "frayfinder_mitt", "hit_number"],
		["m05_attack", "frayfinder_mitt", "target_kind"],
	]
	for entry in missing_fields:
		var patched := _without_field(catalogs, entry[0], entry[1], entry[2])
		_check(RunPatchWearerSummary.summarize(w, torn_state, patched) == rejected,
			entry[1] + " without " + entry[2] + " is rejected exactly")

	var missing_records := [
		["m05_head", "button_glass_visor"],
		["m05_arm", "loose_thread_glove"],
		["m05_attack", "frayfinder_mitt"],
	]
	for pair in missing_records:
		var patched := _without_record(catalogs, pair[0], pair[1])
		_check(RunPatchWearerSummary.summarize(w, torn_state, patched) == rejected,
			"a missing " + pair[1] + " record is rejected exactly")
		_check(RunPatchWearerSummary.preview_sew(w, torn_state,
			pair[1], "warden", patched) == reject_preview,
			"a missing " + pair[1] + " record cannot be previewed")
	_check(RunPatchWearerSummary.summarize(w, torn_state,
		{"m05_arm": "nonsense"}) == rejected,
		"a malformed M05 catalog collection is rejected exactly")

	# A later authored M05 record this readout cannot describe is tolerated.
	var extra: Dictionary = catalogs.duplicate(true)
	var head_extra: Array = extra["m05_head"].duplicate(true)
	head_extra.append({"id": "future_m05_head", "slot": "HEAD",
		"effect": "future_effect", "amount": 3})
	extra["m05_head"] = head_extra
	_check(RunPatchWearerSummary.summarize(w, torn_state, extra).get("ok") == true,
		"an unknown later M05 record leaves the known readout intact")

	# A genuinely owned but unknown M05-shaped patch stays visible and blank.
	var future_w := RunPatchWardrobe.new(f.heroes, ["future_m05_head"],
		[{"id": "future_m05_head", "slot": "HEAD"}], 2, 170,
		["warden_strike"], 8197)
	_check(future_w.is_valid() and future_w.sew("future_m05_head", "tinker",
		"HEAD", "future_m05_sew", future_w.get_snapshot()).ok,
		"an unknown M05 patch can be sewn in a real ledger")
	var future_summary := RunPatchWearerSummary.summarize(future_w, torn_state)
	_check(future_summary.get("ok") == true
		and future_summary.heroes[2]["slots"][0]["patch_id"] == "future_m05_head"
		and future_summary.heroes[2]["slots"][0]["active"] == true
		and future_summary.heroes[2]["slots"][0]["rules_text"] == "",
		"an unknown M05 patch stays visible without invented power")

	# A known M05 definition in a contradicting slot fails closed.
	var wrong_slot := RunPatchWardrobe.new(f.heroes, ["bloodstitch_bonnet"],
		[{"id": "bloodstitch_bonnet", "slot": "COAT"}], 2, 170,
		["warden_strike"], 8197)
	_check(wrong_slot.is_valid()
		and RunPatchWearerSummary.summarize(wrong_slot, torn_state) == rejected,
		"a known M05 patch in the wrong authored slot is rejected exactly")

	_check(w.get_snapshot() == before_w and torn.read_state() == before_t,
		"every M05 rejection leaves both genuine ledgers unchanged")
