class_name StitchedS14Abilities
extends RefCounted
## S14 fixed signature kits and separate, socketable ability-patch inventory.

const HERO_PATH := "res://data/stitched/s14_hero_abilities.json"
const PATCH_PATH := "res://data/stitched/s14_ability_patches.json"
const RARITIES := ["cotton", "wool", "silk", "gold"]
const EFFECTS := ["bleed", "pull", "push", "stun", "mark", "blind", "steal", "chain",
	"regen", "cleanse", "guard", "heal", "rot"]
const SOURCES := ["fight", "event", "elite", "boss"]

static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


## Authored catalogs are immutable data resources; validated copies are cached so a
## bounded seed search does not re-parse and re-validate them for every session.
## Callers always receive a detached duplicate.
static var _kits_cache: Dictionary = {}
static var _patches_cache: Dictionary = {}


static func kits(document: Variant = null) -> Dictionary:
	var from_file := document == null
	if from_file and not _kits_cache.is_empty():
		return _kits_cache.duplicate(true)
	if document == null:
		document = _json(HERO_PATH)
	if not document is Dictionary or document.keys() != ["abilities"] or not document.abilities is Array:
		return {}
	var ids := StitchedPartyAdmission.HERO_IDS
	var result := {}
	var used := {}
	for entry in document.abilities:
		if not entry is Dictionary or not entry.get("hero") is String or not entry.get("slot") is String:
			return {}
		var hero: String = entry.hero
		var slot: String = entry.slot
		if not hero in ids or not slot in StitchedParts.SLOTS:
			return {}
		var stripped: Dictionary = entry.duplicate(true)
		stripped.erase("hero")
		stripped.erase("slot")
		var checked := StitchedParts.validate_ability(stripped)
		if checked.get("ok") != true or str(checked.ability.id) in used:
			return {}
		if not result.has(hero):
			result[hero] = {}
		if result[hero].has(slot):
			return {}
		used[checked.ability.id] = true
		var ability: Dictionary = checked.ability
		ability["slot"] = slot
		result[hero][slot] = ability
	for hero in ids:
		if not result.has(hero) or result[hero].size() != StitchedParts.SLOTS.size():
			return {}
	if from_file:
		_kits_cache = result
		return result.duplicate(true)
	return result


static func patches(document: Variant = null) -> Dictionary:
	var from_file := document == null
	if from_file and not _patches_cache.is_empty():
		return _patches_cache.duplicate(true)
	if document == null:
		document = _json(PATCH_PATH)
	if not document is Dictionary or not document.get("patches") is Array or not document.get("weights") is Dictionary \
			or document.size() != 2:
		return {}
	var entries := {}
	for record in document.patches:
		if not record is Dictionary or record.size() != 5 or not record.get("id") is String \
				or not record.get("name") is String or not record.get("rarity") is String \
				or not record.get("effect") is String or not StitchedParts._integral(record.get("amount")):
			return {}
		if str(record.id).strip_edges().is_empty() or str(record.name).strip_edges().is_empty() \
				or entries.has(record.id) or not record.rarity in RARITIES \
				or not record.effect in EFFECTS or record.amount <= 0 or record.amount > 8:
			return {}
		if record.effect in ["pull", "push", "chain", "cleanse"] and record.amount != 1:
			return {}
		entries[record.id] = record.duplicate(true)
	var weights: Dictionary = document.weights
	if entries.is_empty() or weights.size() != SOURCES.size():
		return {}
	for source in SOURCES:
		var row: Variant = weights.get(source)
		if not row is Array or row.size() != RARITIES.size():
			return {}
		var sum := 0
		for weight in row:
			if not StitchedParts._integral(weight) or weight < 0:
				return {}
			sum += weight
		if sum != 100:
			return {}
	for rarity in RARITIES:
		if not entries.values().any(func(patch: Dictionary) -> bool: return patch.rarity == rarity):
			return {}
	var result := {"by_id": entries, "weights": weights.duplicate(true)}
	if from_file:
		_patches_cache = result
		return result.duplicate(true)
	return result


static func ability(hero_id: String, ability_id: String) -> Dictionary:
	var group: Dictionary = kits().get(hero_id, {})
	for entry in group.values():
		if entry.id == ability_id:
			return entry.duplicate(true)
	return {}


static func draw_patch(rng: RandomNumberGenerator, source: String, rarity_override: String = "") -> Dictionary:
	var catalog := patches()
	if rng == null or catalog.is_empty() or not source in SOURCES \
			or (not rarity_override.is_empty() and not rarity_override in RARITIES):
		return {}
	var rarity := rarity_override
	if rarity.is_empty():
		var roll := rng.randi_range(1, 100)
		var total := 0
		var weights: Array = catalog.weights[source]
		for index in RARITIES.size():
			total += int(weights[index])
			if roll <= total:
				rarity = RARITIES[index]
				break
	var candidates: Array = []
	for id in catalog.by_id:
		if catalog.by_id[id].rarity == rarity:
			candidates.append(id)
	candidates.sort()
	if candidates.is_empty():
		return {}
	return catalog.by_id[candidates[rng.randi_range(0, candidates.size() - 1)]].duplicate(true)


static func socket_limit(ids: Array) -> int:
	var catalog := patches()
	if catalog.is_empty():
		return 0
	for id in ids:
		if not catalog.by_id.has(id):
			return 0
	return 2 if ids.any(func(id: Variant) -> bool: return catalog.by_id[id].rarity == "gold") else 1


static func valid_loadout(hero_id: String, loadout: Variant) -> bool:
	if not loadout is Dictionary:
		return false
	var group: Dictionary = kits().get(hero_id, {})
	if group.is_empty():
		return false
	for key in loadout:
		if not key is String or not loadout[key] is Array:
			return false
		var found := false
		for ability_entry in group.values():
			if ability_entry.id == key:
				found = true
		if not found:
			return false
		var ids: Array = loadout[key]
		if ids.size() > 2 or ids.size() > socket_limit(ids):
			return false
	return true
