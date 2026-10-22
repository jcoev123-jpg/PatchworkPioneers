extends SceneTree
## Deterministic headless regression for the scene-free patch wearer summary.
## Every fixture is built from the shipped catalogs and the real services;
## no on-disk JSON is changed and no rule is re-implemented here.

var failures: Array[String] = []
var checks := 0

const ATTACK_CATALOG := "res://data/patches/m04_attack_patches.json"
const COAT_CATALOG := "res://data/patches/m04_coat_patches.json"
const SLOT_CATALOG := "res://data/patches/initial_patch_slots.json"
const EYE_TEXT := "first successful attack each combat also applies Exposed 1"
const ARM_TEXT := "+1 damage on that wearer's damaging cards"
const COAT_TEXT := "+6 maximum HP"


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
	if typeof(attack) != TYPE_ARRAY or typeof(coat) != TYPE_ARRAY \
			or typeof(initial) != TYPE_ARRAY:
		_check(false, "the three shipped patch catalogs are readable arrays")
		return {}
	return {"attack": attack, "coat": coat, "initial": initial}


## Every shipped record of one ID, so a duplicate can never pass unnoticed.
func _records(catalogs: Dictionary, id: String) -> Array:
	var found: Array = []
	for key in ["attack", "coat", "initial"]:
		for entry in catalogs.get(key, []):
			if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
				found.append(entry)
	return found


## The wardrobe's strict two-field identity/slot records, projected by ID
## from the shipped catalogs instead of hand-written fixture metadata.
func _projected_definitions(catalogs: Dictionary) -> Array:
	var definitions: Array = []
	for key in ["initial", "attack", "coat"]:
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
		"stitched_badge": {"slot": "HEAD"},
		"spare_spool": {"slot": "ARM"},
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
		["button_eye", "HEAD", EYE_TEXT],
		["pincushion_arm", "ARM", ARM_TEXT]
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
