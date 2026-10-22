class_name RunRestCardUpgrade
extends RefCounted
## One Rest visit's scene-free upgrade transaction for the shared run deck:
## replace exactly one selected index with a caller-supplied upgraded card ID,
## exactly once per visit. The caller must authorize a subset through an
## explicit original-ID -> upgraded-ID mapping. Authored pool upgrades must
## also match the real catalog link; legacy starter mappings remain explicit
## transaction-only replacements, including synthetic fixture IDs. This class references
## no scene, no combat transaction and no run state, and takes no randomness.

var _source: Array = []
var _deck: Array[String] = []
var _upgrades: Dictionary = {}
var _catalog: StarterCards
var _valid: bool = false
var _consumed: bool = false


## Optional registry and allocator cursor admit a genuine stitched ledger. Passing
## neither preserves the legacy catalog-only transaction exactly. A supplied
## ledger must pass the SAME complete validation as Rest stitching; naming an
## ID "stitched_*" does not create authorization for that ID.
func _init(deck_ids: Variant = null, permitted_upgrades: Variant = null,
		descriptors: Variant = null, next_stitch_id: Variant = null) -> void:
	_catalog = StarterCards.new()
	if typeof(deck_ids) == TYPE_ARRAY:
		# Deep copy: later caller mutation cannot change this visit's snapshot.
		_source = deck_ids.duplicate(true)
	if descriptors == null and next_stitch_id == null:
		_valid = _is_valid_deck(_source)
	elif typeof(descriptors) == TYPE_DICTIONARY:
		# Do not retain a caller-owned nested half definition. Delegate ALL mixed
		# ledger coherence, ownership and allocator checks to the stitch service.
		var registry: Dictionary = descriptors.duplicate(true)
		var cursor: Variant = 1 if next_stitch_id == null else next_stitch_id
		_valid = RunRestStitchCards.new(_source, registry, 0, cursor).is_valid()
	if _valid:
		for entry in _source:
			var card_id: String = entry
			_deck.append(card_id)
	if typeof(permitted_upgrades) == TYPE_DICTIONARY:
		# Deep copy: later caller mutation cannot change eligibility.
		_upgrades = permitted_upgrades.duplicate(true)


## Read-only query that validates a deck and optional stitched ledger, then
## projects the canonical Rest upgrade options for every eligible owned card.
## Each choice records the card's original zero-based deck index, source ID,
## canonical plus ID, owner, and display metadata. The companion
## permitted_upgrades dictionary maps each base ID to its canonical plus ID and
## can be passed directly to RunRestCardUpgrade.new().
## Invalid deck/ledger input returns ok: false with empty collections.
static func list_authored_choices(deck_ids: Variant = null, descriptors: Variant = null,
		next_stitch_id: Variant = null) -> Dictionary:
	if not _validate_deck_and_ledger(deck_ids, descriptors, next_stitch_id):
		return {
			"ok": false,
			"choices": [],
			"permitted_upgrades": {},
		}

	var source: Array = deck_ids
	var choices: Array = []
	var permitted_upgrades: Dictionary = {}

	for i in range(source.size()):
		var card_id: String = source[i]
		var info: Dictionary = _get_canonical_upgrade_info(card_id)
		if info.is_empty():
			continue

		var choice: Dictionary = {
			"index": i,
			"source_id": card_id,
			"original_id": card_id,
			"base_id": card_id,
			"plus_id": String(info.get("plus_id", "")),
			"upgraded_id": String(info.get("plus_id", "")),
			"owner": String(info.get("owner", "")),
			"display_name": String(info.get("display_name", "")),
			"plus_display_name": String(info.get("plus_display_name", "")),
			"cost": int(info.get("cost", 0)),
			"plus_cost": int(info.get("plus_cost", 0)),
			"effects": info.get("effects", {}).duplicate(true),
			"plus_effects": info.get("plus_effects", {}).duplicate(true),
		}
		choices.append(choice)
		permitted_upgrades[card_id] = String(info.get("plus_id", ""))

	return {
		"ok": true,
		"choices": choices,
		"permitted_upgrades": permitted_upgrades,
	}


## Attempts the visit's single upgrade. index selects one position in the
## ORIGINAL deck snapshot; a card-name search is not offered. A rejected call
## returns a detached copy of the original snapshot, mutates nothing and keeps
## the visit open. A successful call replaces exactly that one index and
## latches the visit so every later call is rejected.
func choose_upgrade(index: Variant) -> Dictionary:
	if _consumed or not _valid:
		return _failure()
	if typeof(index) != TYPE_INT:
		return _failure()
	var selected: int = index
	if selected < 0 or selected >= _deck.size():
		return _failure()
	var original_id: String = _deck[selected]
	if original_id.is_empty():
		return _failure()
	if not _upgrades.has(original_id):
		return _failure()
	var replacement: Variant = _upgrades[original_id]
	if typeof(replacement) != TYPE_STRING:
		return _failure()
	var upgraded_id: String = replacement
	if upgraded_id.is_empty() or upgraded_id == original_id:
		return _failure()
	# Starter replacements retain the original caller-authorized transaction
	# semantics. Pool bases, by contrast, require their exact authored plus.
	if not _catalog.has_card(original_id) and not _is_canonical_pool_upgrade(original_id, upgraded_id):
		return _failure()
	_deck[selected] = upgraded_id
	_consumed = true
	return {
		"ok": true,
		"deck": _deck.duplicate(),
		"original_id": original_id,
		"upgraded_id": upgraded_id,
	}


## True once a legal selection has replaced one copy.
func is_consumed() -> bool:
	return _consumed


func _failure() -> Dictionary:
	return {
		"ok": false,
		"deck": _source.duplicate(true),
		"original_id": "",
		"upgraded_id": "",
	}


static func _validate_deck_and_ledger(deck_ids: Variant, descriptors: Variant = null,
		next_stitch_id: Variant = null) -> bool:
	if typeof(deck_ids) != TYPE_ARRAY:
		return false
	var source: Array = deck_ids
	if source.is_empty():
		return false
	if descriptors == null and next_stitch_id == null:
		return _is_valid_deck(source)
	elif typeof(descriptors) == TYPE_DICTIONARY:
		var registry: Dictionary = descriptors.duplicate(true)
		var cursor: Variant = 1 if next_stitch_id == null else next_stitch_id
		return RunRestStitchCards.new(source, registry, 0, cursor).is_valid()
	return false


## Fail-closed: only starter IDs, reward-eligible pool bases, and genuine
## non-reward pool plus IDs belong in a plain deck. Composites require a
## separately verified descriptor ledger at construction.
static func _is_valid_deck(deck: Array) -> bool:
	if deck.is_empty():
		return false
	for entry in deck:
		if typeof(entry) != TYPE_STRING:
			return false
		var card_id: String = entry
		if card_id.is_empty():
			return false
		if RunPoolCardRewardOffers.resolve_reward_definition(card_id).is_empty() \
				and not RunRestStitchCards.is_authored_pool_plus(card_id):
			return false
	return true


static func _is_canonical_pool_upgrade(original_id: String, upgraded_id: String) -> bool:
	# Look up the source through the reward-base catalog, not by an ID suffix.
	# Every pool has its own schema, so validate the canonical pair in BOTH
	# directions and require the same authored owner and definition.
	var original: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(original_id)
	if original.is_empty() or original.get("id") != original_id \
			or original.get("upgrade_id") != upgraded_id \
			or not RunRestStitchCards.is_authored_pool_plus(upgraded_id):
		return false
	var owner: String = String(original.get("owner", ""))
	var upgraded: Dictionary = _resolve_pool_card_definition(owner, upgraded_id)
	return not upgraded.is_empty() and upgraded.get("id") == upgraded_id \
		and upgraded.get("owner") == owner \
		and upgraded.get("upgrade_of", upgraded.get("base_id", "")) == original_id


static func _resolve_pool_card_definition(owner: String, card_id: String) -> Dictionary:
	match owner:
		"warden":
			return WardenPoolCards.new().get_definition(card_id)
		"seamstress":
			return SeamstressPoolCards.new().get_definition(card_id)
		"tinker":
			return TinkerPoolCards.new().get_definition(card_id)
		_:
			return {}


static func _get_canonical_upgrade_info(card_id: String) -> Dictionary:
	if card_id == "warden_strike":
		var starter := StarterCards.new()
		var base_def: Dictionary = starter.get_definition("warden_strike")
		var plus_def: Dictionary = starter.get_definition("warden_strike_plus")
		if base_def.is_empty() or plus_def.is_empty():
			return {}
		return {
			"plus_id": "warden_strike_plus",
			"owner": "warden",
			"display_name": String(base_def.get("display_name", "Strike")),
			"plus_display_name": String(plus_def.get("display_name", "Strike+")),
			"cost": int(base_def.get("cost", 1)),
			"plus_cost": int(plus_def.get("cost", 1)),
			"effects": base_def.get("effects", {}).duplicate(true),
			"plus_effects": plus_def.get("effects", {}).duplicate(true),
		}

	var starter := StarterCards.new()
	if starter.has_card(card_id):
		return {}

	var pool_def: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	if pool_def.is_empty() or pool_def.get("id") != card_id:
		return {}

	var plus_id: String = String(pool_def.get("upgrade_id", ""))
	if plus_id.is_empty():
		return {}

	if not _is_canonical_pool_upgrade(card_id, plus_id):
		return {}

	var owner: String = String(pool_def.get("owner", ""))
	var plus_def: Dictionary = _resolve_pool_card_definition(owner, plus_id)
	if plus_def.is_empty():
		return {}

	return {
		"plus_id": plus_id,
		"owner": owner,
		"display_name": String(pool_def.get("display_name", "")),
		"plus_display_name": String(plus_def.get("display_name", "")),
		"cost": int(pool_def.get("cost", 0)),
		"plus_cost": int(plus_def.get("cost", 0)),
		"effects": pool_def.get("effects", {}).duplicate(true),
		"plus_effects": plus_def.get("effects", {}).duplicate(true),
	}
