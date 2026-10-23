class_name RunRestPatchResewOptions
extends RefCounted
## Read-only Rest option projector. Only the run owner can commit a choice.
## All accepted inputs must be current service snapshots, not UI claims.

const HERO_IDS := ["warden", "seamstress", "tinker"]
const SLOTS := ["HEAD", "ARM", "COAT"]


static func project(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		exact_snapshot: Variant, rest_node_id: Variant) -> Dictionary:
	var denied := {"ok": false, "options": [], "scraps": 0, "rest_node_id": ""}
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return denied
	if typeof(exact_snapshot) != TYPE_DICTIONARY or not RunPatchWardrobe._id(rest_node_id):
		return denied
	var current := wardrobe.get_snapshot()
	if exact_snapshot != current or current.get("valid") != true:
		return denied
	if current.get("rest_id") != rest_node_id or not current.get("rest_ids", []).has(rest_node_id):
		return denied
	if typeof(current.get("scraps")) != TYPE_INT or current["scraps"] < 1:
		return denied
	var torn_state := torn.read_state()
	var heroes: Variant = torn_state.get("heroes")
	if torn_state.get("ok") != true or not RunPatchWardrobe._valid_roster(heroes, false):
		return denied
	if heroes != current.get("heroes"):
		return denied
	var worn: Variant = current.get("worn")
	var owned: Variant = current.get("owned")
	var definitions: Variant = current.get("definitions")
	if typeof(worn) != TYPE_DICTIONARY or worn.size() != 3 \
			or typeof(owned) != TYPE_ARRAY or typeof(definitions) != TYPE_DICTIONARY:
		return denied
	var active := wardrobe.project_active(torn_state)
	if active.get("ok") != true or active.get("worn") != worn:
		return denied
	var seen := {}
	for hero_id in HERO_IDS:
		if typeof(worn.get(hero_id)) != TYPE_DICTIONARY or worn[hero_id].size() != 3:
			return denied
		for slot in SLOTS:
			var id: Variant = worn[hero_id].get(slot)
			if typeof(id) != TYPE_STRING:
				return denied
			if id == "":
				continue
			if seen.has(id) or not owned.has(id) or definitions.get(id) != slot:
				return denied
			seen[id] = true
	var options := []
	for from_id in HERO_IDS:
		var from_alive: bool = _alive(heroes, from_id)
		for slot in SLOTS:
			var patch_id: String = worn[from_id][slot]
			if patch_id == "":
				continue
			for to_id in HERO_IDS:
				if to_id == from_id:
					continue
				var exchanged: String = worn[to_id][slot]
				options.append({
					"patch_id": patch_id, "from_hero": from_id, "to_hero": to_id,
					"slot": slot, "kind": "MOVE" if exchanged == "" else "SWAP",
					"exchanged_id": exchanged, "cost": 1,
					"source_active": from_alive,
					"destination_active": _alive(heroes, to_id),
					"exchanged_active": exchanged != "" and _alive(heroes, to_id)
				})
	return {"ok": true, "options": options.duplicate(true),
		"scraps": current["scraps"], "rest_node_id": rest_node_id}


static func _alive(heroes: Array, hero_id: String) -> bool:
	for hero in heroes:
		if hero["id"] == hero_id:
			return hero["hp"] > 0
	return false


## Detached wearer forecast for an EXACT, currently legal option. This does
## not reserve scraps, change HP, spend a Rest action or commit re_sew().
static func forecast(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		exact_snapshot: Variant, rest_node_id: Variant, option: Variant) -> Dictionary:
	var rejected := {"ok": false}
	if typeof(option) != TYPE_DICTIONARY:
		return rejected
	var model := project(wardrobe, torn, exact_snapshot, rest_node_id)
	if model.get("ok") != true or not model["options"].has(option):
		return rejected
	var torn_state := torn.read_state()
	if not RunPatchCoatRules._valid_heroes(torn_state.get("heroes"),
			torn_state.get("tear_counts")):
		return rejected
	var attack_rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatPatchAttackRules.CATALOG))
	var coat_rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	var shop_slots: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		CombatShopPatchRules.SLOTS_CATALOG))
	if not CombatPatchAttackRules.new()._valid_catalog(attack_rules) \
			or typeof(coat_rules) != TYPE_ARRAY \
			or not RunPatchCoatRules._valid_authored(coat_rules) \
			or not CombatShopPatchRules._valid_slot_catalog(shop_slots):
		return rejected
	var authority := RunPatchWearerSummary._authority({})
	if authority.is_empty():
		return rejected
	var catalog_slots: Dictionary = authority["slots"]
	var definitions: Dictionary = exact_snapshot["definitions"]
	# Known authored IDs must not be mis-slotted in a caller-supplied ledger.
	for id in catalog_slots:
		if definitions.has(id) and definitions[id] != catalog_slots[id]:
			return rejected
	var coat_bonuses := {}
	for entry in coat_rules:
		var coat_id: String = entry["id"]
		coat_bonuses[coat_id] = int(entry["max_hp_bonus"])
	var source_id: String = option["from_hero"]
	var destination_id: String = option["to_hero"]
	var slot: String = option["slot"]
	var before_worn: Dictionary = exact_snapshot["worn"]
	var after_worn: Dictionary = before_worn.duplicate(true)
	after_worn[source_id][slot] = option["exchanged_id"]
	after_worn[destination_id][slot] = option["patch_id"]
	var source_hero: Dictionary = {}
	var destination_hero: Dictionary = {}
	for hero in torn_state["heroes"]:
		if hero["id"] == source_id:
			source_hero = hero
		elif hero["id"] == destination_id:
			destination_hero = hero
	if source_hero.is_empty() or destination_hero.is_empty():
		return rejected
	return {
		"ok": true, "kind": option["kind"], "slot": slot,
		"patch_id": option["patch_id"], "exchanged_id": option["exchanged_id"],
		"cost": option["cost"],
		"source": {
			"hero_id": source_id,
			"before": _wearer(source_hero, before_worn[source_id], coat_bonuses),
			"after": _wearer(source_hero, after_worn[source_id], coat_bonuses)
		},
		"destination": {
			"hero_id": destination_id,
			"before": _wearer(destination_hero, before_worn[destination_id], coat_bonuses),
			"after": _wearer(destination_hero, after_worn[destination_id], coat_bonuses)
		}
	}


static func _wearer(hero: Dictionary, assignments: Dictionary, coat_bonuses: Dictionary = {}) -> Dictionary:
	var hp: int = hero["hp"]
	var base_max: int = hero["max_hp"]
	var slots := {}
	for slot in SLOTS:
		var id: String = assignments[slot]
		var effect := ""
		# Only authoritative documented rules get a power description.
		if id == CombatShopPatchRules.STITCHED_BADGE_ID \
				and slot == CombatShopPatchRules.EFFECTS[id]["slot"]:
			effect = "+%d opening Block to living wearer (stacks with innate Block)" % CombatShopPatchRules.OPENING_BLOCK_BONUS
		elif id == CombatShopPatchRules.SPARE_SPOOL_ID \
				and slot == CombatShopPatchRules.EFFECTS[id]["slot"]:
			effect = "+%d healing on positive-heal cards owned by wearer only" % CombatShopPatchRules.HEALING_CARD_BONUS
		elif id == "button_eye" and slot == CombatPatchAttackRules.EFFECTS[id]["slot"]:
			effect = "first attack each combat: Exposed %d" % CombatPatchAttackRules.EFFECTS[id]["amount"]
		elif id == "pincushion_arm" and slot == CombatPatchAttackRules.EFFECTS[id]["slot"]:
			effect = "damage-dealing cards: +%d damage" % CombatPatchAttackRules.EFFECTS[id]["amount"]
		elif slot == "COAT" and coat_bonuses.has(id):
			effect = "+%d effective max HP (no heal)" % coat_bonuses[id]
		elif RunPatchWearerSummary.KNOWN_M05_HEAD_POWERS.has(id) and slot == "HEAD":
			effect = RunPatchWearerSummary.KNOWN_TEXTS.get(id, "")
		elif (RunPatchWearerSummary.KNOWN_M05_ARM_POWERS.has(id) or RunPatchWearerSummary.KNOWN_M05_ATTACK_POWERS.has(id)) and slot == "ARM":
			effect = RunPatchWearerSummary.KNOWN_TEXTS.get(id, "")
		slots[slot] = {"id": id, "active": id != "" and hp > 0, "effect": effect}
	var coat_id: String = slots["COAT"]["id"]
	var coat_active: bool = hp > 0 and coat_bonuses.has(coat_id)
	var coat_bonus: int = coat_bonuses.get(coat_id, 0) if coat_active else 0
	return {"hp": hp, "base_max_hp": base_max,
		"effective_max_hp": base_max + coat_bonus,
		"slots": slots}
