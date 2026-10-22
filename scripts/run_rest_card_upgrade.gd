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


## Fail-closed: only starter IDs, reward-eligible pool bases, and genuine
## non-reward pool plus IDs belong in a plain deck. Composites require a
## separately verified descriptor ledger at construction.
func _is_valid_deck(deck: Array) -> bool:
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


func _is_canonical_pool_upgrade(original_id: String, upgraded_id: String) -> bool:
	# Look up the source through the reward-base catalog, not by an ID suffix.
	# Every pool has its own schema, so validate the canonical pair in BOTH
	# directions and require the same authored owner and definition.
	var original: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(original_id)
	if original.is_empty() or original.get("id") != original_id \
			or original.get("upgrade_id") != upgraded_id \
			or not RunRestStitchCards.is_authored_pool_plus(upgraded_id):
		return false
	var upgraded: Dictionary = {}
	match original.get("owner"):
		"warden":
			upgraded = WardenPoolCards.new().get_definition(upgraded_id)
		"seamstress":
			upgraded = SeamstressPoolCards.new().get_definition(upgraded_id)
		"tinker":
			upgraded = TinkerPoolCards.new().get_definition(upgraded_id)
		_:
			return false
	return not upgraded.is_empty() and upgraded.get("id") == upgraded_id \
		and upgraded.get("owner") == original.get("owner") \
		and upgraded.get("upgrade_of", upgraded.get("base_id", "")) == original_id
