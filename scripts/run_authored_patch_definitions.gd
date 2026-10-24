class_name RunAuthoredPatchDefinitions
extends RefCounted
## Validated ID/slot-only projection for Elite sewing. Effect data remains in
## its authored catalog and is never copied into the wardrobe.

const CATALOG_PATHS := [
	"res://data/patches/initial_patch_slots.json",
	"res://data/patches/m04_attack_patches.json",
	"res://data/patches/m04_coat_patches.json",
	"res://data/patches/m05_head_patches.json",
	"res://data/patches/m05_arm_support_patches.json",
	"res://data/patches/m05_attack_patches.json",
	"res://data/patches/m05_coat_patches.json",
]


static func load_definitions() -> Array:
	var texts: Array = []
	for path in CATALOG_PATHS:
		if not FileAccess.file_exists(path):
			return []
		texts.append(FileAccess.get_file_as_string(path))
	return from_json_texts(texts)


## Pure fixture entry: malformed JSON (including a valid JSON non-array)
## invalidates the entire collection before any records are trusted.
static func from_json_texts(texts: Variant) -> Array:
	if typeof(texts) != TYPE_ARRAY or texts.size() != CATALOG_PATHS.size():
		return []
	var catalogs: Array = []
	for source in texts:
		if typeof(source) != TYPE_STRING or source.is_empty():
			return []
		var parser := JSON.new()
		if parser.parse(source) != OK or typeof(parser.data) != TYPE_ARRAY:
			return []
		catalogs.append(parser.data)
	return project_catalogs(catalogs)


## Pure fixture entry; accepts added authored IDs without a size/order oracle.
## Existing named powers must remain in their original catalog and slot.
static func project_catalogs(catalogs: Variant) -> Array:
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
			projected.append({"id": id, "slot": slot})
		for known_id in required:
			if not local.has(known_id):
				return []
	return projected
