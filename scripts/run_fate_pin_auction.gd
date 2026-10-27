class_name RunFatePinAuction
extends RefCounted
## One detached offer and one atomic wardrobe transaction. No scene or global RNG.
const PATH := "res://data/events/mpw_fate_pin_auction.json"
const EVENT_ID := "fate_pin_auction"
var _source: Dictionary = {}
var _offers: Array = []
var _record: Dictionary = {}
var _claimed := false
var _valid := false

static func load_record() -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not value is Dictionary or not RunEventChoice.new(value).is_valid():
		return {}
	for key in ["hp_cost", "minimum_hp", "gold_cost", "exit_scraps", "offer_count", "visit_weight"]:
		var number: Variant = value.get(key)
		if not (number is float or number is int) or not is_finite(number) or floor(number) != number or number <= 0:
			return {}
		value[key] = int(number)
	if value.id != EVENT_ID or value.rarity != "ordinary" or value.once_per_run != true \
		or value.minimum_hp != value.hp_cost + 1 or value.offer_count != 2:
		return {}
	return value

static func ordinary_definitions() -> Array:
	var rare: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/patches/mpw_synergy_patches.json"))
	if not rare is Array:
		return []
	var rare_ids: Array = []
	for record in rare:
		rare_ids.append(record.id)
	return RunAuthoredPatchDefinitions.load_power_definitions().filter(func(d): return not rare_ids.has(d.id))

static func eligible_definitions(state: Dictionary) -> Array:
	var pool: Array = []
	for definition in ordinary_definitions():
		if state.get("definitions", {}).get(definition.id) == definition.slot and not state.get("owned", []).has(definition.id):
			pool.append(definition.duplicate(true))
	pool.sort_custom(func(a, b): return a.id < b.id)
	return pool

func _init(wardrobe: RunPatchWardrobe = null, rng: RandomNumberGenerator = null) -> void:
	_record = load_record()
	if wardrobe == null or not wardrobe.is_valid() or rng == null or _record.is_empty():
		return
	_source = wardrobe.get_snapshot()
	if _source.rest_id != "" or _source.operation_ids.has(EVENT_ID):
		return
	var pool := eligible_definitions(_source)
	if pool.size() < _record.offer_count:
		return
	# All validation precedes either draw. Caller stages this RNG until mounting.
	for index in range(_record.offer_count):
		var selected := rng.randi_range(0, pool.size() - 1)
		_offers.append(pool.pop_at(selected))
	_valid = true

func is_valid() -> bool:
	return _valid and not _claimed

func get_offers() -> Array:
	return _offers.duplicate(true)

func get_source() -> Dictionary:
	return _source.duplicate(true)

func get_event() -> Dictionary:
	return _record.duplicate(true)

func eligible_payers() -> Array:
	var ids: Array = []
	for hero in _source.get("heroes", []):
		if hero.hp >= _record.minimum_hp:
			ids.append(hero.id)
	return ids

static func _copy_wardrobe(w: RunPatchWardrobe) -> RunPatchWardrobe:
	var s := w.get_snapshot()
	var copy := RunPatchWardrobe.new(s.heroes, s.owned, w._definition_records(), s.scraps, s.gold, s.cards, s.seed, true)
	copy._worn = s.worn.duplicate(true)
	copy._operations.assign(s.operation_ids)
	copy._rest_ids.assign(s.rest_ids)
	copy._rest_id = s.rest_id
	return copy

## Read-only proposal. The caller can authenticate its route and other ledgers
## before committing. Wrong slots and changed offers fail before payment.
func prepare(wardrobe: RunPatchWardrobe, choice: Variant, payer: Variant, slot: Variant, expected: Variant) -> Dictionary:
	if not is_valid() or wardrobe == null or expected != _source or wardrobe.get_snapshot() != _source:
		return {"ok": false}
	var staged := _copy_wardrobe(wardrobe)
	var sewing := {}
	if choice == "safe_exit":
		if staged._scraps > RunPatchWardrobe.MAX_INT - _record.exit_scraps:
			return {"ok": false}
		staged._scraps += _record.exit_scraps
		staged._operations.append(EVENT_ID)
	else:
		var index := ["patch_0", "patch_1"].find(choice)
		if index < 0 or not eligible_payers().has(payer) or _source.gold < _record.gold_cost:
			return {"ok": false}
		var offer: Dictionary = _offers[index]
		if not ordinary_definitions().has(offer) or slot != offer.slot or _source.definitions.get(offer.id) != slot:
			return {"ok": false}
		for hero in staged._heroes:
			if hero.id == payer:
				hero.hp -= _record.hp_cost
		staged._gold -= _record.gold_cost
		staged._owned.append(offer.id)
		var result := staged.sew(offer.id, payer, slot, EVENT_ID, staged.get_snapshot())
		if not result.ok:
			return {"ok": false}
		sewing = result.receipt
	return {"ok": true, "event_id": EVENT_ID, "choice_id": choice, "payer": payer,
		"state": staged.get_snapshot(), "sewing": sewing}

## Recompute the complete receipt, then publish only the already validated fields.
func commit(wardrobe: RunPatchWardrobe, receipt: Dictionary) -> bool:
	var slot: Variant = receipt.get("sewing", {}).get("slot", "")
	var replay := prepare(wardrobe, receipt.get("choice_id"), receipt.get("payer"), slot, _source)
	if not replay.ok or replay != receipt:
		return false
	var s: Dictionary = replay.state
	wardrobe._heroes = s.heroes.duplicate(true)
	wardrobe._owned = s.owned.duplicate(true)
	wardrobe._worn = s.worn.duplicate(true)
	wardrobe._gold = s.gold
	wardrobe._scraps = s.scraps
	wardrobe._operations.assign(s.operation_ids)
	_claimed = true
	return true
