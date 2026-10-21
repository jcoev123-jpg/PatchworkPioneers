class_name RunShopVisit
extends RefCounted
## A run-owned, scene-free ledger for at most one paid card removal per
## confirmed Shop node. The caller owns the RNG and confirms node types.


var _deck: Array[String] = []
var _trinkets: Array[String] = []
var _gold: int = 0
var _prior_removals: int = 0
var _valid: bool = false
var _status: String = "inactive"
var _shop_node_id: String = ""
var _visited_ids: Array[String] = []
var _claimed_fight_ids: Array[String] = []


func _init(deck_ids: Array[String], gold: int, prior_removals: int,
		owned_trinket_ids: Array[String] = []) -> void:
	_deck.assign(deck_ids)
	_trinkets.assign(owned_trinket_ids)
	_gold = gold
	_prior_removals = prior_removals
	_valid = gold >= 0 and prior_removals >= 0
	var owned_seen := {}
	for trinket_id in owned_trinket_ids:
		if owned_seen.has(trinket_id):
			_valid = false
			return
		owned_seen[trinket_id] = true


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


## Reconcile one paid stock purchase during an open or post-removal Shop.
## A receipt is mandatory for trinkets and proves the exact charged price;
## legacy receipt-less cards retain their original append/nonincreasing-gold
## contract (with unchanged owned trinkets). No failure commits a partial state.
func reconcile_purchase(result: Dictionary) -> bool:
	if not _valid or (_status != "available" and _status != "used"):
		return false
	if result.get("ok") != true or not result.get("state") is Dictionary:
		return false
	var state: Dictionary = result["state"]
	var cards: Variant = state.get("deck")
	var gold: Variant = state.get("gold")
	var trinkets: Variant = state.get("trinkets", _trinkets.duplicate())
	if not cards is Array or not trinkets is Array or not gold is int:
		return false
	if gold < 0 or gold > _gold:
		return false
	var has_receipt := result.has("receipt")
	var kind := "card"
	var purchased_id: String = ""
	if has_receipt:
		if not result["receipt"] is Dictionary or not state.has("trinkets"):
			return false
		var receipt: Dictionary = result["receipt"]
		if receipt.size() != 3 or not receipt.has("kind") or not receipt.has("id") or not receipt.has("price"):
			return false
		if not receipt["kind"] is String or not receipt["id"] is String or not receipt["price"] is int:
			return false
		kind = receipt["kind"]
		purchased_id = receipt["id"]
		if (kind != "card" and kind != "trinket") or purchased_id.strip_edges().is_empty():
			return false
		if receipt["price"] < 0 or receipt["price"] > _gold or _gold - gold != receipt["price"]:
			return false
	if kind == "card":
		if trinkets != _trinkets or cards.size() != _deck.size() + 1 or cards.slice(0, _deck.size()) != _deck:
			return false
		var last_card: Variant = cards.back()
		if not last_card is String or last_card.strip_edges().is_empty():
			return false
		if has_receipt and last_card != purchased_id:
			return false
	else:
		if _trinkets.has(purchased_id):
			return false
		if cards != _deck or trinkets.size() != _trinkets.size() + 1 or trinkets.slice(0, _trinkets.size()) != _trinkets:
			return false
		if trinkets.back() != purchased_id:
			return false
	# Both ledgers are committed only after the whole snapshot is validated.
	_deck.assign(cards)
	_trinkets.assign(trinkets)
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


## Admit the complete, already-settled RunMultiFightRewards.choose() reply.
## Its typed receipt comes from the authoritative map and cached reward. This
## reconciles against our OWN ledger, never a caller-supplied pre-reward state.
## The caller must have checked the real committed outcome: this snapshot is
## not cryptographic proof of a battle, and the bridge never draws RNG.
func apply_battle_reward(node_id: Variant, settled: Variant) -> bool:
	if not _valid or (_status != "inactive" and _status != "closed"):
		return false
	if not node_id is String or node_id.is_empty() \
			or node_id != node_id.strip_edges() or _claimed_fight_ids.has(node_id):
		return false
	if not settled is Dictionary or settled.get("ok") != true \
			or not settled.get("ok") is bool:
		return false
	var receipt: Variant = settled.get("receipt")
	var state: Variant = settled.get("state")
	var skipped: Variant = settled.get("skipped")
	var selected: Variant = settled.get("selected_id")
	if not receipt is Dictionary or not state is Dictionary \
			or not skipped is bool or not selected is String:
		return false
	if receipt.size() != 3 or not receipt.has("node_id") \
			or not receipt.has("node_kind") or not receipt.has("trinket_drop_id"):
		return false
	var receipt_node: Variant = receipt["node_id"]
	var kind: Variant = receipt["node_kind"]
	var drop: Variant = receipt["trinket_drop_id"]
	if not receipt_node is String or receipt_node != node_id \
			or not kind is String or kind not in ["Fight", "Elite"] \
			or not drop is String:
		return false
	var cards: Variant = state.get("deck")
	var gold: Variant = state.get("gold")
	var trinkets: Variant = state.get("trinkets")
	var party: Variant = state.get("party")
	if not cards is Array or not gold is int or not trinkets is Array \
			or not party is Dictionary:
		return false
	# The actual carryover settlement records this node at the end of its
	# fight history. It cannot be a reward prepared but not yet chosen.
	var completed: Variant = party.get("completed_fights")
	if party.get("ok") != true or not completed is Array \
			or completed.is_empty() or completed.back() != node_id \
			or not party.get("heroes") is Array or not party.get("completed_rests") is Array:
		return false
	# Nonnegative operands make subtraction safe even at signed MAX_INT.
	if gold < _gold:
		return false
	var delta: int = gold - _gold
	if kind == "Fight":
		if delta < 10 or delta > 20 or drop != "" or trinkets != _trinkets:
			return false
	else:
		if delta < 25 or delta > 35 or drop.is_empty() \
				or drop != drop.strip_edges() or _trinkets.has(drop):
			return false
		if trinkets.size() != _trinkets.size() + 1 \
				or trinkets.slice(0, _trinkets.size()) != _trinkets \
				or trinkets.back() != drop:
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
		if cards.size() != _deck.size() + 1 \
				or cards.slice(0, _deck.size()) != _deck \
				or cards.back() != selected:
			return false
	# Atomic publication, including the shared legacy/typed claim history.
	_deck.assign(cards)
	_trinkets.assign(trinkets)
	_gold = gold
	_claimed_fight_ids.append(node_id)
	return true


## Every returned container is independent of the run's internal ledger.
func get_state() -> Dictionary:
	var deck_copy: Array[String] = _deck.duplicate()
	var trinket_copy: Array[String] = _trinkets.duplicate()
	var ids_copy: Array[String] = _visited_ids.duplicate()
	return {
		"valid": _valid,
		"status": _status,
		"shop_node_id": _shop_node_id,
		"removal_available": _valid and _status == "available",
		"price": quote(),
		"deck": deck_copy,
		"trinkets": trinket_copy,
		"gold": _gold,
		"prior_removals": _prior_removals,
		"visited_ids": ids_copy,
		"claimed_fight_ids": _claimed_fight_ids.duplicate(),
	}
