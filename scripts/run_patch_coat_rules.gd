class_name RunPatchCoatRules
extends RefCounted
## Read-only, scene-free effective maximum HP projection. Never persists a
## derived cap or heals HP; ownership and active wear are wardrobe-owned.

const STARTING_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const SLOTS := ["HEAD", "ARM", "COAT"]
const BONUS_ID := "quilted_coat"
const BONUS := 6

const REQUIRED_COATS := {
	"quilted_coat": 6,
	"padded_vest": 4,
	"double_quilt_coat": 8,
}


static func project_health(torn_state: Dictionary, wardrobe: RunPatchWardrobe,
		authored_coats: Variant) -> Dictionary:
	var rejected := {"ok": false, "heroes": []}
	if wardrobe == null or not wardrobe.is_valid():
		return rejected
	if not _valid_authored(authored_coats):
		return rejected
	var state: Dictionary = wardrobe.get_snapshot()
	if state.get("valid") != true or torn_state.get("ok") != true:
		return rejected
	var heroes: Variant = torn_state.get("heroes")
	if not _valid_heroes(heroes, torn_state.get("tear_counts"), torn_state.get("vital_cap_offsets", {})):
		return rejected
	# The optimistic run context MUST have been refreshed after each battle,
	# mend or Rest; accepting a prior roster would create phantom bonuses.
	if state.get("heroes") != heroes:
		return rejected
	var active: Dictionary = wardrobe.project_active(torn_state)
	if active.get("ok") != true:
		return rejected
	var worn: Variant = state.get("worn")
	var owned: Variant = state.get("owned")
	var definitions: Variant = state.get("definitions")
	if typeof(worn) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY \
			or typeof(definitions) != TYPE_DICTIONARY:
		return rejected
	if active.get("worn") != worn or typeof(active.get("active")) != TYPE_DICTIONARY:
		return rejected
	# The wardrobe is the authority: every sewn ID must be owned and assigned
	# once, in its declared slot, before ANY effective stats are returned.
	var seen := {}
	for hero in heroes:
		var id: String = hero["id"]
		if typeof(worn.get(id)) != TYPE_DICTIONARY:
			return rejected
		var slots: Dictionary = worn[id]
		if slots.size() != SLOTS.size():
			return rejected
		var eligible: Variant = active["active"].get(id)
		if typeof(eligible) != TYPE_ARRAY:
			return rejected
		var expected_active := []
		for slot in SLOTS:
			var patch_id: Variant = slots.get(slot)
			if typeof(patch_id) != TYPE_STRING:
				return rejected
			if patch_id == "":
				continue
			if seen.has(patch_id) or not owned.has(patch_id) \
					or definitions.get(patch_id) != slot:
				return rejected
			seen[patch_id] = true
			if hero["hp"] > 0:
				expected_active.append(patch_id)
		if eligible != expected_active:
			return rejected
	var coat_bonuses := {}
	for entry in authored_coats:
		coat_bonuses[entry["id"]] = int(entry["max_hp_bonus"])

	var result: Array = heroes.duplicate(true)
	for hero in result:
		var id: String = hero["id"]
		var coat_id: String = worn[id].get("COAT", "")
		if coat_id == "":
			continue
		if definitions.get(coat_id) != "COAT":
			return rejected
		if hero["hp"] > 0 and active["active"][id].has(coat_id):
			if coat_bonuses.has(coat_id):
				hero["max_hp"] += coat_bonuses[coat_id]
	return {"ok": true, "heroes": result}


static func _valid_authored(records: Variant) -> bool:
	if not (records is Array) or records.is_empty():
		return false
	var seen_ids := {}
	for entry in records:
		if not (entry is Dictionary) or entry.size() != 3:
			return false
		var id: Variant = entry.get("id")
		if typeof(id) != TYPE_STRING or id.is_empty():
			return false
		if seen_ids.has(id):
			return false
		seen_ids[id] = true
		if entry.get("slot") != "COAT":
			return false
		var amount: Variant = entry.get("max_hp_bonus")
		if typeof(amount) != TYPE_INT and typeof(amount) != TYPE_FLOAT:
			return false
		if typeof(amount) == TYPE_FLOAT and amount != floor(amount):
			return false
		var bonus_val := int(amount)
		if bonus_val <= 0:
			return false
		if REQUIRED_COATS.has(id) and bonus_val != REQUIRED_COATS[id]:
			return false
	for req_id in REQUIRED_COATS:
		if not seen_ids.has(req_id):
			return false
	return true


static func _valid_heroes(heroes: Variant, counts: Variant, offsets: Variant = {}) -> bool:
	if not offsets is Dictionary:
		return false
	var caps := {}
	if heroes is Array:
		var ids: Array = []
		for hero in heroes:
			if not hero is Dictionary:
				return false
			ids.append(hero.get("id"))
		var admission := RunV3PartyAdmission.admit(ids)
		if not admission.ok:
			return false
		for definition in admission.party:
			caps[definition.id] = definition.max_hp
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != 3 \
			or typeof(counts) != TYPE_DICTIONARY or counts.size() != 3:
		return false
	var seen := {}
	for i in range(heroes.size()):
		var hero: Variant = heroes[i]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var id: Variant = hero.get("id")
		if typeof(id) != TYPE_STRING or not caps.has(id) or seen.has(id):
			return false
		seen[id] = true
		for field in ["position", "hp", "max_hp", "block"]:
			if typeof(hero.get(field)) != TYPE_INT:
				return false
		if hero["position"] != i + 1 or hero["max_hp"] < 10 \
				or hero["hp"] < 0 or hero["hp"] > hero["max_hp"] or hero["block"] < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for status in statuses:
			if typeof(status) != TYPE_STRING or not ["bleed", "weak", "exposed"].has(status) \
					or typeof(statuses[status]) != TYPE_INT or statuses[status] < 0:
				return false
		var count: Variant = counts.get(id)
		if typeof(count) != TYPE_INT or count < 0:
			return false
		var starting: int = caps[id]
		# Saturate before multiplication, avoiding overflow from forged counts.
		var turns_to_floor: int = ceili(float(starting - 10) / 3.0)
		var expected: int = 10 if count >= turns_to_floor else starting - 3 * count
		if not offsets.is_empty():
			if offsets.size() != caps.size() or typeof(offsets.get(id)) != TYPE_INT:
				return false
			if hero["max_hp"] - expected != offsets[id]:
				return false
		elif hero["max_hp"] != expected:
			return false
	return true
