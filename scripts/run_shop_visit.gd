class_name RunShopVisit
extends RefCounted
## A run-owned, scene-free ledger for at most one paid card removal per
## confirmed Shop node. The caller owns the RNG and confirms node types.


var _deck: Array[String] = []
var _gold: int = 0
var _prior_removals: int = 0
var _valid: bool = false
var _status: String = "inactive"
var _shop_node_id: String = ""
var _visited_ids: Array[String] = []
var _claimed_fight_ids: Array[String] = []


func _init(deck_ids: Array[String], gold: int, prior_removals: int) -> void:
	_deck.assign(deck_ids)
	_gold = gold
	_prior_removals = prior_removals
	_valid = gold >= 0 and prior_removals >= 0


## Only a caller-confirmed Shop node ID may be submitted. Each ID can open
## once per ledger; a visit must be closed before starting another one.
func open_visit(shop_node_id: String) -> bool:
	if not _valid or _status == "available" or _status == "used":
		return false
	if shop_node_id.strip_edges().is_empty() or _visited_ids.has(shop_node_id):
		return false
	_visited_ids.append(shop_node_id)
	_shop_node_id = shop_node_id
	_status = "available"
	return true


## A failed attempt leaves the option available. The helper is the sole
## authority for price, first-match removal, charging, and removal count.
func remove_card(card_id: String) -> Dictionary:
	if not _valid or _status != "available":
		# Ask the helper for a failed, detached result (including its quote).
		return RunShopCardRemoval.try_remove(_deck, _gold, _prior_removals, "")
	var result := RunShopCardRemoval.try_remove(_deck, _gold, _prior_removals, card_id)
	if result["ok"]:
		_deck.assign(result["deck"])
		_gold = result["gold"]
		_prior_removals = result["prior_removals"]
		_status = "used"
	return result


func close_visit() -> bool:
	if _status != "available" and _status != "used":
		return false
	_status = "closed"
	return true


## Reconcile a successful purchase without reopening or resetting this visit.
## Card buying is legal before or after the visit's single paid removal, so an
## untouched "available" visit and a post-removal "used" visit both accept it.
## Inactive and closed ledgers never reconcile, and a successful reconciliation
## only commits deck and gold: status, removal count, quote and node history
## stay exactly as they were.
func reconcile_purchase(result: Dictionary) -> bool:
	if not _valid or (_status != "available" and _status != "used"):
		return false
	if result.get("ok") != true:
		return false
	var state: Dictionary = result.get("state", {})
	var cards: Variant = state.get("deck")
	var gold: Variant = state.get("gold")
	if typeof(cards) != TYPE_ARRAY or typeof(gold) != TYPE_INT or gold < 0 or gold > _gold:
		return false
	if cards.size() != _deck.size() + 1 or cards.slice(0, _deck.size()) != _deck:
		return false
	if typeof(cards.back()) != TYPE_STRING or cards.back().strip_edges().is_empty():
		return false
	_deck.assign(cards)
	_gold = gold
	return true


## Quote is delegated to the same helper, even when no visit is open.
func quote() -> int:
	return RunShopCardRemoval.try_remove(_deck, _gold, _prior_removals, "")["price"]


## Accept a completed normal Fight reward between visits. Validate the entire
## snapshot before committing anything; IDs must already be canonical.
func apply_fight_reward(fight_node_id: Variant, reward: Variant) -> bool:
	if not _valid or (_status != "inactive" and _status != "closed"):
		return false
	if not fight_node_id is String or fight_node_id.is_empty() \
			or fight_node_id != fight_node_id.strip_edges() \
			or _claimed_fight_ids.has(fight_node_id):
		return false
	if not reward is Dictionary or not reward.get("ok") is bool or reward.get("ok") != true:
		return false
	var skipped: Variant = reward.get("skipped")
	var selected: Variant = reward.get("selected_id")
	var cards: Variant = reward.get("deck")
	var gold: Variant = reward.get("gold")
	if not skipped is bool or not selected is String or not cards is Array or not gold is int:
		return false
	# Both operands are nonnegative before subtraction, so even MAX_INT is safe.
	if gold < _gold or gold - _gold < 10 or gold - _gold > 20:
		return false
	for card in cards:
		if not card is String:
			return false
	if skipped:
		if selected != "" or cards != _deck:
			return false
	else:
		if selected.is_empty() or StarterCards.new().get_definition(selected).is_empty():
			return false
		if cards.size() != _deck.size() + 1 or cards.slice(0, _deck.size()) != _deck \
				or cards.back() != selected:
			return false
	_deck.assign(cards)
	_gold = gold
	_claimed_fight_ids.append(fight_node_id)
	return true


## Every returned container is independent of the run's internal ledger.
func get_state() -> Dictionary:
	var deck_copy: Array[String] = _deck.duplicate()
	var ids_copy: Array[String] = _visited_ids.duplicate()
	return {
		"valid": _valid,
		"status": _status,
		"shop_node_id": _shop_node_id,
		"removal_available": _valid and _status == "available",
		"price": quote(),
		"deck": deck_copy,
		"gold": _gold,
		"prior_removals": _prior_removals,
		"visited_ids": ids_copy,
		"claimed_fight_ids": _claimed_fight_ids.duplicate(),
	}
