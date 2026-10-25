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
]

## The starter catalog holds inert slots, never power stock.
const INITIAL_CATALOG_INDEX := 0


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
	return _project(catalogs, false)


## Pure power-only record entry. Every catalog is validated first; only the
## initial starter catalog is then withheld from the returned candidates.
static func project_power_catalogs(catalogs: Variant) -> Array:
	return _project(catalogs, true)


static func _project(catalogs: Variant, power_only: bool) -> Array:
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
			elif index == 0 or index == 1:
				if slot != "HEAD" and slot != "ARM":
					return []
			seen[id] = true
			local[id] = true
			# The starter catalog is validated above exactly like the power
			# catalogs, then kept out of the power-only candidates, so entries
			# authored into it later stay inert too.
			if power_only and index == INITIAL_CATALOG_INDEX:
				continue
			projected.append({"id": id, "slot": slot})
		for known_id in required:
			if not local.has(known_id):
				return []
	return projected
