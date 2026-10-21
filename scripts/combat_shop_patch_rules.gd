class_name CombatShopPatchRules
extends RefCounted
## Read-only M04 scene-free wearer modifier projection for the two Shop starter patches:
## - stitched_badge (HEAD): +3 opening Block to its living wearer (additive to Warden's +6).
## - spare_spool (ARM): +2 healing to a positive-heal card owned by its living wearer.
## Never mutates run ledgers, combat actors, decks, or RNG.

const SLOTS_CATALOG := "res://data/patches/initial_patch_slots.json"
const OFFERS_CATALOG := "res://data/shop/initial_offers.json"
const STITCHED_BADGE_ID := "stitched_badge"
const SPARE_SPOOL_ID := "spare_spool"
const OPENING_BLOCK_BONUS := 3
const HEALING_CARD_BONUS := 2
const SHOP_PATCH_PRICE := 100
const STARTING_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const MIN_MAX_HP := 10
const TEAR_LOSS := 3
const EFFECTS := {
	"stitched_badge": {"slot": "HEAD", "effect": "opening_block_bonus", "amount": OPENING_BLOCK_BONUS},
	"spare_spool": {"slot": "ARM", "effect": "healing_card_bonus", "amount": HEALING_CARD_BONUS}
}

var _valid := false
var _active: Dictionary = {}
var _worn: Dictionary = {}
var _living: Dictionary = {}


func bind_wardrobe(wardrobe: Variant = null, torn: Variant = null,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_valid = false
	_active.clear()
	_worn.clear()
	_living.clear()
	if not (wardrobe is RunPatchWardrobe) or not (torn is RunTornMending):
		return false
	if not wardrobe.is_valid() or not torn.is_valid():
		return false
	var slots_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(SLOTS_CATALOG))
	var offers_raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(OFFERS_CATALOG))
	if not _valid_slot_catalog(slots_raw) or not _valid_offers_catalog(offers_raw):
		return false
	var state: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = torn.read_state()
	if expected_wardrobe != null:
		if typeof(expected_wardrobe) != TYPE_DICTIONARY or expected_wardrobe != state:
			return false
	if expected_torn != null:
		if typeof(expected_torn) != TYPE_DICTIONARY or expected_torn != torn_state:
			return false
	var projection: Dictionary = wardrobe.project_active(torn_state)
	if not _valid_projection(state, torn_state, projection):
		return false
	_active = projection["active"].duplicate(true)
	_worn = state["worn"].duplicate(true)
	for hero in torn_state["heroes"]:
		_living[hero["id"]] = hero["hp"] > 0
	_valid = true
	return true


func is_valid() -> bool:
	return _valid


func active_snapshot() -> Dictionary:
	return _active.duplicate(true)


func worn_snapshot() -> Dictionary:
	return _worn.duplicate(true)


func opening_block_bonus(hero_id: Variant) -> int:
	if not _valid or typeof(hero_id) != TYPE_STRING or not _living.get(hero_id, false):
		return 0
	if _worn.get(hero_id, {}).get("HEAD") != STITCHED_BADGE_ID:
		return 0
	return OPENING_BLOCK_BONUS if _active.get(hero_id, []).has(STITCHED_BADGE_ID) else 0


func healing_card_bonus(hero_id: Variant, card_id: Variant) -> int:
	if not _valid or typeof(hero_id) != TYPE_STRING or typeof(card_id) != TYPE_STRING:
		return 0
	if not _living.get(hero_id, false):
		return 0
	if _worn.get(hero_id, {}).get("ARM") != SPARE_SPOOL_ID:
		return 0
	if not _active.get(hero_id, []).has(SPARE_SPOOL_ID):
		return 0
	var catalog := StarterCards.new()
	if not catalog.has_card(card_id):
		return 0
	var definition: Dictionary = catalog.get_definition(card_id)
	if not _has_positive_authored_heal(definition, hero_id, card_id):
		return 0
	return HEALING_CARD_BONUS


func project_opening_block(hero_id: Variant) -> int:
	if not _valid or typeof(hero_id) != TYPE_STRING or not _living.get(hero_id, false):
		return 0
	var base_block := CombatStartingBlock.BLOCK_AMOUNT if hero_id == CombatStartingBlock.WARDEN_ID else 0
	return base_block + opening_block_bonus(hero_id)


func project_card_healing(hero_id: Variant, card_id: Variant) -> int:
	if not _valid or typeof(hero_id) != TYPE_STRING or typeof(card_id) != TYPE_STRING:
		return 0
	if not _living.get(hero_id, false):
		return 0
	var catalog := StarterCards.new()
	if not catalog.has_card(card_id):
		return 0
	var definition: Dictionary = catalog.get_definition(card_id)
	if not _has_positive_authored_heal(definition, hero_id, card_id):
		return 0
	var base_heal: int = definition["effects"]["heal"]
	return base_heal + healing_card_bonus(hero_id, card_id)


static func _has_positive_authored_heal(definition: Variant, hero_id: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(hero_id) != TYPE_STRING or typeof(card_id) != TYPE_STRING:
		return false
	if definition.get("id") != card_id or definition.get("owner") != hero_id:
		return false
	var effects: Variant = definition.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return false
	var heal: Variant = effects.get("heal")
	return typeof(heal) == TYPE_INT and heal > 0


static func _valid_slot_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var seen := {}
	var matched := {}
	for entry in raw:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 2:
			return false
		var id: Variant = entry.get("id")
		var slot: Variant = entry.get("slot")
		if not RunPatchWardrobe._id(id) or typeof(slot) != TYPE_STRING:
			return false
		if not RunPatchWardrobe.SLOTS.has(slot) or seen.has(id):
			return false
		seen[id] = slot
		if EFFECTS.has(id):
			if slot != EFFECTS[id]["slot"]:
				return false
			matched[id] = true
	return matched.size() == EFFECTS.size()


static func _valid_offers_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY:
		return false
	var trinkets: Variant = raw.get("trinkets")
	if typeof(trinkets) != TYPE_ARRAY:
		return false
	var seen := {}
	var matched := {}
	for entry in trinkets:
		if typeof(entry) != TYPE_DICTIONARY or entry.size() != 2:
			return false
		var id: Variant = entry.get("id")
		var price: Variant = entry.get("price")
		if not RunPatchWardrobe._id(id) or seen.has(id):
			return false
		if not _is_positive_int(price):
			return false
		seen[id] = int(price)
		if EFFECTS.has(id):
			if int(price) != SHOP_PATCH_PRICE:
				return false
			matched[id] = true
	return matched.size() == EFFECTS.size()


static func _is_positive_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return value > 0
	if typeof(value) == TYPE_FLOAT:
		return is_finite(value) and floor(value) == value and int(value) > 0
	return false


static func _valid_projection(state: Dictionary, torn_state: Dictionary, projection: Dictionary) -> bool:
	if state.get("valid") != true or torn_state.get("ok") != true or projection.get("ok") != true:
		return false
	if typeof(torn_state.get("defeated")) != TYPE_BOOL:
		return false
	var definitions: Variant = state.get("definitions")
	var owned: Variant = state.get("owned")
	var worn: Variant = state.get("worn")
	var active: Variant = projection.get("active")
	var heroes: Variant = torn_state.get("heroes")
	var counts: Variant = torn_state.get("tear_counts")
	if typeof(definitions) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY:
		return false
	if typeof(worn) != TYPE_DICTIONARY or typeof(active) != TYPE_DICTIONARY:
		return false
	if not _valid_heroes(heroes, counts):
		return false
	if state.get("heroes") != heroes or projection.get("worn") != worn:
		return false
	if worn.size() != RunPatchWardrobe.HERO_IDS.size() or active.size() != worn.size():
		return false
	var seen_owned := {}
	for item in owned:
		if not RunPatchWardrobe._id(item) or seen_owned.has(item):
			return false
		seen_owned[item] = true
	for def_id in definitions:
		if not RunPatchWardrobe._id(def_id) or not RunPatchWardrobe.SLOTS.has(definitions[def_id]):
			return false
	for id in EFFECTS:
		if not definitions.has(id):
			if owned.has(id):
				return false
		elif definitions[id] != EFFECTS[id]["slot"]:
			return false
	var seen_heroes := {}
	var seen_worn := {}
	for hero in heroes:
		var owner: String = hero["id"]
		seen_heroes[owner] = true
		var slots: Variant = worn.get(owner)
		var projected: Variant = active.get(owner)
		if typeof(slots) != TYPE_DICTIONARY or slots.size() != RunPatchWardrobe.SLOTS.size():
			return false
		if typeof(projected) != TYPE_ARRAY:
			return false
		var expected_active := []
		for slot in RunPatchWardrobe.SLOTS:
			var id: Variant = slots.get(slot)
			if typeof(id) != TYPE_STRING:
				return false
			if id == "":
				continue
			if not owned.has(id) or definitions.get(id) != slot or seen_worn.has(id):
				return false
			seen_worn[id] = true
			if hero.get("hp", 0) > 0:
				expected_active.append(id)
		if projected != expected_active:
			return false
	return seen_heroes.size() == RunPatchWardrobe.HERO_IDS.size()


static func _valid_heroes(heroes: Variant, counts: Variant) -> bool:
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != RunPatchWardrobe.HERO_IDS.size():
		return false
	if typeof(counts) != TYPE_DICTIONARY or counts.size() != RunPatchWardrobe.HERO_IDS.size():
		return false
	var seen := {}
	for i in range(heroes.size()):
		var hero: Variant = heroes[i]
		if typeof(hero) != TYPE_DICTIONARY:
			return false
		var id: Variant = hero.get("id")
		if typeof(id) != TYPE_STRING or not STARTING_HP.has(id) or seen.has(id):
			return false
		seen[id] = true
		for field in ["position", "hp", "max_hp", "block"]:
			if typeof(hero.get(field)) != TYPE_INT:
				return false
		if hero["position"] != i + 1 or hero["max_hp"] < MIN_MAX_HP:
			return false
		if hero["hp"] < 0 or hero["hp"] > hero["max_hp"] or hero["block"] < 0:
			return false
		var statuses: Variant = hero.get("statuses", {})
		if typeof(statuses) != TYPE_DICTIONARY:
			return false
		for status in statuses:
			if typeof(status) != TYPE_STRING or status not in ["bleed", "weak", "exposed"]:
				return false
			if typeof(statuses[status]) != TYPE_INT or statuses[status] < 0:
				return false
		var count: Variant = counts.get(id)
		if typeof(count) != TYPE_INT or count < 0:
			return false
		var starting: int = STARTING_HP[id]
		var turns_to_floor: int = ceili(float(starting - MIN_MAX_HP) / float(TEAR_LOSS))
		var expected_max: int = MIN_MAX_HP if count >= turns_to_floor else starting - TEAR_LOSS * count
		if hero["max_hp"] != expected_max:
			return false
	return seen.size() == RunPatchWardrobe.HERO_IDS.size()
