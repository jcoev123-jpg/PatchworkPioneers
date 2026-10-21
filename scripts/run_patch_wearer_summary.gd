class_name RunPatchWearerSummary
extends RefCounted
## Scene-free, read-only per-hero patch slot and wearer-effect summary.
## Does not alter wardrobe, torn ledger, or any run service.

const SLOTS := ["HEAD", "ARM", "COAT"]
const HERO_IDS := ["warden", "seamstress", "tinker"]

const ATTACK_PATCHES_PATH := "res://data/patches/m04_attack_patches.json"
const COAT_PATCHES_PATH := "res://data/patches/m04_coat_patches.json"
const INITIAL_SLOTS_PATH := "res://data/patches/initial_patch_slots.json"


static func summarize(wardrobe: RunPatchWardrobe, torn_state: Dictionary) -> Dictionary:
	if wardrobe == null or typeof(wardrobe) != TYPE_OBJECT or not wardrobe.is_valid():
		return {"ok": false, "heroes": []}
	if torn_state == null or typeof(torn_state) != TYPE_DICTIONARY or torn_state.get("ok") != true:
		return {"ok": false, "heroes": []}

	var heroes: Variant = torn_state.get("heroes")
	if not _valid_heroes(heroes):
		return {"ok": false, "heroes": []}

	var snapshot: Dictionary = wardrobe.get_snapshot()
	if snapshot.get("valid") != true:
		return {"ok": false, "heroes": []}

	# Project active against torn snapshot; must succeed and match.
	var projection: Dictionary = wardrobe.project_active(torn_state)
	if projection.get("ok") != true:
		return {"ok": false, "heroes": []}

	# Verify owned/worn/definition consistency (same contract as combat rules).
	var definitions: Variant = snapshot.get("definitions")
	var owned: Variant = snapshot.get("owned")
	var worn: Variant = snapshot.get("worn")
	if typeof(definitions) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY \
			or typeof(worn) != TYPE_DICTIONARY:
		return {"ok": false, "heroes": []}

	var projection_active: Variant = projection.get("active")
	var projection_worn: Variant = projection.get("worn")
	if typeof(projection_active) != TYPE_DICTIONARY or projection_worn != worn:
		return {"ok": false, "heroes": []}

	# Check that every worn patch is owned, defined for its slot, and unique.
	var seen_worn: Dictionary = {}
	for hero in heroes:
		var hero_id: String = hero.get("id")
		if typeof(worn.get(hero_id)) != TYPE_DICTIONARY:
			return {"ok": false, "heroes": []}
		var slots_dict: Dictionary = worn.get(hero_id)
		if slots_dict.size() != SLOTS.size():
			return {"ok": false, "heroes": []}
		for slot in SLOTS:
			var patch_id: Variant = slots_dict.get(slot)
			if patch_id == "":
				continue
			if typeof(patch_id) != TYPE_STRING:
				return {"ok": false, "heroes": []}
			if not owned.has(patch_id) or definitions.get(patch_id) != slot:
				return {"ok": false, "heroes": []}
			if seen_worn.has(patch_id):
				return {"ok": false, "heroes": []}
			seen_worn[patch_id] = true

	# Verify active arrays from project_active match our expectations.
	for hero in heroes:
		var hero_id: String = hero.get("id")
		var expected_active: Array = []
		var slots_dict: Dictionary = worn.get(hero_id)
		if hero.get("hp", 0) > 0:
			for slot in SLOTS:
				var pid: String = slots_dict.get(slot, "")
				if pid != "":
					expected_active.append(pid)
		var actual_active: Variant = projection_active.get(hero_id)
		if typeof(actual_active) != TYPE_ARRAY:
			return {"ok": false, "heroes": []}
		# Arrays of strings; compare sorted contents to avoid ordering issues.
		var expected_sorted: Array = expected_active.duplicate(true)
		expected_sorted.sort()
		var actual_sorted: Array = actual_active.duplicate(true)
		actual_sorted.sort()
		if expected_sorted != actual_sorted:
			return {"ok": false, "heroes": []}

	# Load authored catalogs for rules text resolution.
	var attack_catalog: Variant = _load_json(ATTACK_PATCHES_PATH)
	var coat_catalog: Variant = _load_json(COAT_PATCHES_PATH)
	var initial_catalog: Variant = _load_json(INITIAL_SLOTS_PATH)

	# Resolve rules descriptions from verified JSON entries.
	var result_heroes: Array = []
	for hero in heroes:
		var hero_id: String = hero.get("id")
		var position: int = hero.get("position", 0)
		var hp: int = hero.get("hp", 0)
		var slots_result: Array = []
		for slot in SLOTS:
			var patch_id: String = worn.get(hero_id, {}).get(slot, "")
			var active_for_slot: bool = false
			if patch_id != "" and hero.get("hp", 0) > 0:
				var active_array: Array = projection_active.get(hero_id, [])
				active_for_slot = active_array.has(patch_id)
			var rules_text: String = ""
			if patch_id != "":
				rules_text = _resolve_rules_text(patch_id, attack_catalog, coat_catalog, initial_catalog)
			slots_result.append({
				"slot": slot,
				"patch_id": patch_id,
				"active": active_for_slot,
				"rules_text": rules_text
			})
		result_heroes.append({
			"id": hero_id,
			"position": position,
			"hp": hp,
			"slots": slots_result
		})

	return {"ok": true, "heroes": result_heroes}


static func _valid_heroes(heroes: Variant) -> bool:
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != HERO_IDS.size():
		return false
	var seen: Dictionary = {}
	for i in range(heroes.size()):
		var hero: Variant = heroes[i]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var hero_id: Variant = hero.get("id")
		if typeof(hero_id) != TYPE_STRING or hero_id.is_empty() or hero_id.strip_edges() != hero_id:
			return false
		if seen.has(hero_id) or not HERO_IDS.has(hero_id):
			return false
		seen[hero_id] = true
		var position: Variant = hero.get("position")
		if typeof(position) != TYPE_INT or position != i + 1:
			return false
		for field in ["hp", "max_hp", "block"]:
			var val: Variant = hero.get(field)
			if typeof(val) != TYPE_INT:
				return false
		if hero.get("max_hp") < 10:
			return false
		if hero.get("hp") < 0 or hero.get("hp") > hero.get("max_hp") or hero.get("block") < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for status in statuses:
			if typeof(status) != TYPE_STRING or status not in ["bleed", "weak", "exposed"]:
				return false
			if typeof(statuses[status]) != TYPE_INT or statuses[status] < 0:
				return false
	return seen.size() == HERO_IDS.size()


static func _load_json(path: String) -> Variant:
	var file := FileAccess.get_file_as_string(path)
	if file.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(file)
	if parsed == null:
		return []
	return parsed


static func _resolve_rules_text(patch_id: String, attack_catalog: Variant,
		coat_catalog: Variant, initial_catalog: Variant) -> String:
	# Check attack patches (named powers from m04_attack_patches.json)
	if typeof(attack_catalog) == TYPE_ARRAY:
		for entry in attack_catalog:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id: Variant = entry.get("id")
			if id == patch_id:
				var slot: Variant = entry.get("slot")
				var effect: Variant = entry.get("effect")
				var amount: Variant = entry.get("amount")
				if typeof(slot) == TYPE_STRING and slot == entry.get("slot") \
						and typeof(effect) == TYPE_STRING and typeof(amount) in [TYPE_INT, TYPE_FLOAT]:
					var amount_int := int(amount)
					if effect == "first_attack_exposed" and amount_int == 1:
						return "first successful attack each combat also applies Exposed 1"
					if effect == "card_attack_bonus" and amount_int == 1:
						return "+1 damage on that wearer's damaging cards"
	# Check coat patches (from m04_coat_patches.json)
	if typeof(coat_catalog) == TYPE_ARRAY:
		for entry in coat_catalog:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id: Variant = entry.get("id")
			if id == patch_id:
				var slot: Variant = entry.get("slot")
				var max_hp_bonus: Variant = entry.get("max_hp_bonus")
				if typeof(slot) == TYPE_STRING and slot == "COAT" \
						and (typeof(max_hp_bonus) == TYPE_INT or typeof(max_hp_bonus) == TYPE_FLOAT):
					var bonus_int := int(max_hp_bonus)
					if bonus_int == 6:
						return "+6 maximum HP"
	# Check initial slot-only fixtures (no authored gameplay power)
	if typeof(initial_catalog) == TYPE_ARRAY:
		for entry in initial_catalog:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id: Variant = entry.get("id")
			if id == patch_id:
				return ""
	# Unknown/slotted-only patch: empty rules text.
	return ""
