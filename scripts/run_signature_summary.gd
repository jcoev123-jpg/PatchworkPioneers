class_name RunSignatureSummary
extends RefCounted
## Scene-free read-only projection of crafted/current stitched cards and worn
## HEAD/ARM/COAT patches from an authentic run ledger and wardrobe.
## Exposes no mutable aliases; does not compute combat power, active statuses,
## gold, scraps, or consume RNG.

const HERO_IDS := ["warden", "seamstress", "tinker"]
const SLOTS := ["HEAD", "ARM", "COAT"]
const MAX_INT := 9223372036854775807


static func summarize(deck_ids: Variant, descriptors: Variant, next_stitch_id: Variant, wardrobe: Variant) -> Dictionary:
	# Check all input types BEFORE constructing services.
	if typeof(deck_ids) != TYPE_ARRAY or typeof(descriptors) != TYPE_DICTIONARY:
		return _failure()
	if typeof(next_stitch_id) != TYPE_INT or next_stitch_id < 1 or next_stitch_id >= MAX_INT:
		return _failure()
	if deck_ids.is_empty():
		return _failure()
	for card in deck_ids:
		if typeof(card) != TYPE_STRING or card.is_empty():
			return _failure()
	if wardrobe == null or typeof(wardrobe) != TYPE_OBJECT or not (wardrobe is RunPatchWardrobe):
		return _failure()

	# Validate the deck, descriptor registry and allocator with RunRestStitchCards.
	var stitch_validator := RunRestStitchCards.new(deck_ids, descriptors, 0, next_stitch_id)
	if not stitch_validator.is_valid():
		return _failure()

	# Validate wardrobe validity and snapshot.
	if not wardrobe.is_valid():
		return _failure()
	var snapshot: Variant = wardrobe.get_snapshot()
	if typeof(snapshot) != TYPE_DICTIONARY or snapshot.get("valid") != true:
		return _failure()

	# Reject if wardrobe's cards are not the same ordered current deck snapshot.
	var wardrobe_cards: Variant = snapshot.get("cards")
	if typeof(wardrobe_cards) != TYPE_ARRAY:
		return _failure()
	if wardrobe_cards.size() != deck_ids.size():
		return _failure()
	for i in range(deck_ids.size()):
		if wardrobe_cards[i] != deck_ids[i]:
			return _failure()

	var owned_val: Variant = snapshot.get("owned")
	var defs_val: Variant = snapshot.get("definitions")
	var worn_val: Variant = snapshot.get("worn")
	var heroes_val: Variant = snapshot.get("heroes")
	if typeof(owned_val) != TYPE_ARRAY or typeof(defs_val) != TYPE_DICTIONARY \
			or typeof(worn_val) != TYPE_DICTIONARY or typeof(heroes_val) != TYPE_ARRAY:
		return _failure()

	# Verify heroes roster container shape and order.
	if heroes_val.size() != HERO_IDS.size():
		return _failure()
	for i in range(HERO_IDS.size()):
		var hero_info: Variant = heroes_val[i]
		if typeof(hero_info) != TYPE_DICTIONARY or hero_info.get("id") != HERO_IDS[i]:
			return _failure()

	# Check worn records against the wardrobe's actual owned/definition maps
	# in exact HERO_IDS/SLOTS order, rejecting duplicate IDs, wrong slots,
	# unknown IDs, missing heroes or invalid slot container shapes.
	if worn_val.size() != HERO_IDS.size():
		return _failure()

	var seen_worn: Dictionary = {}
	var worn_total: int = 0
	var hero_rows: Array = []
	var all_worn_ids: Array = []

	for hero_id in HERO_IDS:
		if not worn_val.has(hero_id):
			return _failure()
		var hero_slots_val: Variant = worn_val[hero_id]
		if typeof(hero_slots_val) != TYPE_DICTIONARY or hero_slots_val.size() != SLOTS.size():
			return _failure()

		var row_slots: Dictionary = {}
		var hero_worn_ids: Array = []

		for slot in SLOTS:
			if not hero_slots_val.has(slot):
				return _failure()
			var patch_id: Variant = hero_slots_val[slot]
			if typeof(patch_id) != TYPE_STRING:
				return _failure()

			if patch_id == "":
				row_slots[slot] = ""
				continue

			# Must be owned, defined, matching slot, and not duplicate across the party.
			if not owned_val.has(patch_id):
				return _failure()
			if not defs_val.has(patch_id) or defs_val[patch_id] != slot:
				return _failure()
			if seen_worn.has(patch_id):
				return _failure()

			seen_worn[patch_id] = true
			worn_total += 1
			row_slots[slot] = patch_id
			hero_worn_ids.append(patch_id)
			all_worn_ids.append(patch_id)

		hero_rows.append({
			"hero_id": hero_id,
			"id": hero_id,
			"slots": row_slots.duplicate(),
			"HEAD": row_slots["HEAD"],
			"ARM": row_slots["ARM"],
			"COAT": row_slots["COAT"],
			"worn_ids": hero_worn_ids.duplicate(),
		})

	# Stitched cards summary:
	var stitched_created: int = next_stitch_id - 1
	var stitched_current: int = descriptors.size()
	var detached_descriptors: Dictionary = descriptors.duplicate(true)
	var stitched_ids: Array = []
	for card_id in deck_ids:
		if detached_descriptors.has(card_id):
			stitched_ids.append(card_id)

	return {
		"ok": true,
		"stitched_created": stitched_created,
		"stitched_current": stitched_current,
		"worn_total": worn_total,
		"heroes": hero_rows,
		"descriptors": detached_descriptors,
		"worn_ids": all_worn_ids,
		"stitched_ids": stitched_ids,
	}


static func _failure() -> Dictionary:
	return {
		"ok": false,
		"stitched_created": 0,
		"stitched_current": 0,
		"worn_total": 0,
		"heroes": [],
		"descriptors": {},
		"worn_ids": [],
		"stitched_ids": [],
	}
