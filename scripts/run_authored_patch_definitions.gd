class_name RunAuthoredPatchDefinitions
extends RefCounted
## Validated ID/slot-only projection for Elite sewing. Effect data remains in
## its authored catalog and is never copied into the wardrobe.
##
## Two projections share one validation pass:
## - load_definitions()/project_catalogs(): every authored record, including
##   the inert starter slots of initial_patch_slots.json, for the wardrobe.
## - load_power_definitions()/project_power_catalogs(): real power records
##   only, for future Shop and Elite stock. The initial catalog is still
##   validated in full, but none of its entries (including ones authored
##   later) are power stock.

const CATALOG_PATHS := [
	"res://data/patches/initial_patch_slots.json",
	"res://data/patches/m04_attack_patches.json",
	"res://data/patches/m04_coat_patches.json",
	"res://data/patches/m05_head_patches.json",
	"res://data/patches/m05_arm_support_patches.json",
	"res://data/patches/m05_attack_patches.json",
	"res://data/patches/m05_coat_patches.json",
	"res://data/patches/mpw_synergy_patches.json",
	"res://data/patches/mpw_heirloom_patches.json",
]

## The starter catalog holds inert slots, never power stock.
const INITIAL_CATALOG_INDEX := 0
const HEIRLOOM_CATALOG_INDEX := 8
const HEIRLOOM_IDS := ["needle_echo", "shared_hem"]
const HEIRLOOM_REQUIRED := {
	"needle_echo": {
		"id": "needle_echo", "name": "Needle Echo", "slot": "HEAD", "rarity": "rare",
		"effect": "first_confirmed_pinned_hit_bonus_damage",
		"trigger": "first_confirmed_wearer_hit_on_pinned_enemy_per_turn",
		"requires_confirmed_receipt": true, "requires_pinned_enemy": true,
		"wearer_must_be_living": true, "wearer_must_be_untorn": true,
		"bonus_damage": 1, "uses_per_turn": 1, "shop_price_gold": 100,
		"stock_weight_percent": 100, "stock_weight_basis": "ordinary_patch",
		"stock_competes_for_existing_slot": true,
	},
	"shared_hem": {
		"id": "shared_hem", "name": "Shared Hem", "slot": "ARM", "rarity": "rare",
		"effect": "different_living_hero_block_gain_wearer_block",
		"trigger": "different_living_hero_actually_gains_block",
		"requires_actual_block_gain": true, "source_hero_must_be_living": true,
		"source_hero_must_differ_from_wearer": true,
		"wearer_must_be_living": true, "wearer_must_be_untorn": true,
		"block": 1, "uses_per_turn": 1, "shop_price_gold": 100,
		"stock_weight_percent": 100, "stock_weight_basis": "ordinary_patch",
		"stock_competes_for_existing_slot": true,
	},
}


static func load_definitions() -> Array:
	var texts: Array = _read_catalog_texts()
	if texts.is_empty():
		return []
	return from_json_texts(texts)


## Production power-only accessor for Shop and Elite stock candidates. Returns
## only the seven power catalogs' authored {id, slot} records (the initial
## starter catalog is excluded, the P8 rare catalog is included).
static func load_power_definitions() -> Array:
	var texts: Array = _read_catalog_texts()
	if texts.is_empty():
		return []
	return power_definitions_from_json_texts(texts)


## The standard power projection remains locked until a completed run.
static func load_eligible_power_definitions(unlocked: Variant) -> Array:
	var texts: Array = _read_catalog_texts()
	if texts.is_empty():
		return []
	return eligible_power_definitions_from_json_texts(texts, unlocked)


static func _read_catalog_texts() -> Array:
	var texts: Array = []
	for path in CATALOG_PATHS:
		if not FileAccess.file_exists(path):
			return []
		texts.append(FileAccess.get_file_as_string(path))
	return texts


## Pure fixture entry: malformed JSON (including a valid JSON non-array)
## invalidates the entire collection before any records are trusted.
static func from_json_texts(texts: Variant) -> Array:
	var catalogs: Array = _parse_catalogs(texts)
	if catalogs.size() != CATALOG_PATHS.size():
		return []
	return project_catalogs(catalogs)


## Pure power-only fixture entry; same fail-closed validation as the full
## projection before any initial-catalog entry is excluded.
static func power_definitions_from_json_texts(texts: Variant) -> Array:
	var catalogs: Array = _parse_catalogs(texts)
	if catalogs.size() != CATALOG_PATHS.size():
		return []
	return project_power_catalogs(catalogs)


static func eligible_power_definitions_from_json_texts(texts: Variant, unlocked: Variant) -> Array:
	if typeof(unlocked) != TYPE_BOOL:
		return []
	var catalogs: Array = _parse_catalogs(texts)
	if catalogs.size() != CATALOG_PATHS.size():
		return []
	return project_eligible_power_catalogs(catalogs, unlocked)


static func _parse_catalogs(texts: Variant) -> Array:
	var catalogs: Array = []
	if typeof(texts) != TYPE_ARRAY or texts.size() != CATALOG_PATHS.size():
		return catalogs
	for source in texts:
		if typeof(source) != TYPE_STRING or source.is_empty():
			return []
		var parser := JSON.new()
		if parser.parse(source) != OK or typeof(parser.data) != TYPE_ARRAY:
			return []
		catalogs.append(parser.data)
	return catalogs


## Pure fixture entry; accepts added authored IDs without a size/order oracle.
## Existing named powers must remain in their original catalog and slot.
static func project_catalogs(catalogs: Variant) -> Array:
	return _project(catalogs, false, false)


## Pure power-only record entry. Every catalog is validated first; only the
## initial starter catalog is then withheld from the returned candidates.
static func project_power_catalogs(catalogs: Variant) -> Array:
	return _project(catalogs, true, false)


static func project_eligible_power_catalogs(catalogs: Variant, unlocked: Variant) -> Array:
	if typeof(unlocked) != TYPE_BOOL:
		return []
	return _project(catalogs, true, unlocked)


static func _valid_heirloom(record: Dictionary) -> bool:
	var id: Variant = record.get("id")
	if typeof(id) != TYPE_STRING or not HEIRLOOM_REQUIRED.has(id):
		return false
	var required: Dictionary = HEIRLOOM_REQUIRED[id]
	if record.size() != required.size():
		return false
	for field in required:
		if not record.has(field):
			return false
		var value: Variant = record[field]
		var expected: Variant = required[field]
		# Godot JSON parses numeric metadata as floats; only finite whole
		# numbers equal to their authored contract are permitted.
		if typeof(expected) == TYPE_INT and typeof(value) == TYPE_FLOAT:
			if not is_finite(value) or floor(value) != value or value != expected:
				return false
		elif typeof(value) != typeof(expected) or value != expected:
			return false
	return true


static func _project(catalogs: Variant, power_only: bool, heirloom_unlocked: bool) -> Array:
	if typeof(catalogs) != TYPE_ARRAY or catalogs.size() != CATALOG_PATHS.size():
		return []
	var known: Array = [
		CombatShopPatchRules.EFFECTS,
		RunPatchWearerSummary.KNOWN_ATTACK_POWERS,
		RunPatchWearerSummary.KNOWN_COAT_POWERS,
		RunPatchWearerSummary.KNOWN_M05_HEAD_POWERS,
		RunPatchWearerSummary.KNOWN_M05_ARM_POWERS,
		RunPatchWearerSummary.KNOWN_M05_ATTACK_POWERS,
		RunPatchWearerSummary.KNOWN_M05_COAT_POWERS,
		{
			"relay_bobbin": {"slot": "HEAD"},
			"hearth_lining": {"slot": "COAT"},
		},
		{"needle_echo": {"slot": "HEAD"}, "shared_hem": {"slot": "ARM"}},
	]
	var projected: Array = []
	var seen: Dictionary = {}
	for index in range(catalogs.size()):
		var entries: Variant = catalogs[index]
		if typeof(entries) != TYPE_ARRAY or entries.is_empty():
			return []
		var required: Dictionary = known[index]
		var local: Dictionary = {}
		for record in entries:
			if typeof(record) != TYPE_DICTIONARY:
				return []
			var id: Variant = record.get("id")
			var slot: Variant = record.get("slot")
			if not RunPatchWardrobe._id(id) or typeof(slot) != TYPE_STRING \
					or not RunPatchWardrobe.SLOTS.has(slot) or seen.has(id):
				return []
			if required.has(id) and slot != required[id]["slot"]:
				return []
			if index == HEIRLOOM_CATALOG_INDEX and not _valid_heirloom(record):
				return []
			# This catalog's slot family cannot silently admit a power from
			# another family, even if the slot name is otherwise well-formed.
			if index == 2 or index == 6:
				if slot != "COAT":
					return []
			elif index == 3:
				if slot != "HEAD":
					return []
			elif index == 4 or index == 5:
				if slot != "ARM":
					return []
			elif index == 0 or index == 1 or index == HEIRLOOM_CATALOG_INDEX:
				if slot != "HEAD" and slot != "ARM":
					return []
			seen[id] = true
			local[id] = true
			# The starter catalog is validated above exactly like the power
			# catalogs, then kept out of the power-only candidates, so entries
			# authored into it later stay inert too.
			if power_only and (index == INITIAL_CATALOG_INDEX or (index == HEIRLOOM_CATALOG_INDEX and not heirloom_unlocked)):
				continue
			projected.append({"id": id, "slot": slot})
		for known_id in required:
			if not local.has(known_id):
				return []
	return projected
