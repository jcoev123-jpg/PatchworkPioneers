class_name RunMultiFightRewards
extends RefCounted
## Run-owned, scene-free settlement. Inputs are copied except the authoritative
## map, RNG and ledger. prepare(node, witnessed_result, party) caches one offer;
## choose(node, card_id) settles it, with "" meaning explicit Skip.
## External ledger changes invalidate this owner's resource snapshot.

var _map: RunMap
var _rng: RandomNumberGenerator
var _carry: RunPartyCarryover
var _deck: Array
var _gold: int
var _trinkets: Array
var _candidates: Array
var _trinket_candidates: Array
var _ledger: Dictionary
var _graph: Array
var _map_revision: int = 0
var _pending: RunFightVictoryRewards
var _node := ""
var _route: Array
var _battle: CombatBattleResult
var _party: CombatParty
var _heroes: Array
var _enemies: Array
var _paid_battles: Array[CombatBattleResult] = []


func _init(map: RunMap, rng: RandomNumberGenerator, carry: RunPartyCarryover,
		deck: Array, gold: int, owned_trinkets: Array, candidates: Array,
		trinket_candidates: Array = []) -> void:
	_map = map
	_rng = rng
	_carry = carry
	_deck = deck.duplicate(true)
	_gold = gold
	_trinkets = owned_trinkets.duplicate(true)
	_candidates = candidates.duplicate(true)
	_trinket_candidates = trinket_candidates.duplicate(true)
	_ledger = {} if carry == null else carry.read_state()
	_graph = [] if map == null else map.get_floors()
	_map_revision = 0 if map == null else map.get_generation_revision()


func read_state() -> Dictionary:
	return {"deck": _deck.duplicate(true), "gold": _gold,
		"trinkets": _trinkets.duplicate(true), "party": _ledger.duplicate(true)}


func prepare(node_id: Variant, battle: CombatBattleResult, party: CombatParty) -> Dictionary:
	if not _eligible(node_id, battle, party):
		return {"ok": false}
	if _pending != null:
		if node_id != _node or battle != _battle or party != _party or not _unchanged():
			return {"ok": false}
		return _pending.prepare()
	var ids: Array[String] = []
	for hero in party.get_heroes():
		ids.append(hero["id"])
	var reward := RunFightVictoryRewards.new(battle, _rng, ids, _candidates,
		_deck, _gold, _map.get_node(node_id)["type"] == "Elite",
		_trinket_candidates, _trinkets)
	var prepared := reward.prepare()
	if not prepared["ok"]:
		return prepared
	_pending = reward
	_node = node_id
	_route = _map.get_route()
	_battle = battle
	_party = party
	_heroes = party.get_heroes()
	_enemies = battle._enemies.get_enemies()
	return prepared


func choose(node_id: Variant, selected_id: Variant) -> Dictionary:
	if _pending == null or node_id != _node or not selected_id is String:
		return {"ok": false}
	if not _eligible(node_id, _battle, _party) or not _unchanged():
		return {"ok": false}
	# Preflight the choice before consuming either service. No calls yield, so
	# ledger admission and reward admission remain true throughout publication.
	var offered: bool = selected_id.is_empty()
	for offer in _pending.prepare()["offers"]:
		if offer["id"] == selected_id:
			offered = true
	if not offered:
		return {"ok": false}
	# These typed fields are bound to the cached winning node and seeded
	# preparation, not supplied by the choice caller.
	var node_kind: String = _map.get_node(_node)["type"]
	var trinket_drop_id: String = _pending.prepare()["trinket_drop_id"]
	var resolved := _pending.choose(selected_id)
	if not resolved["ok"]:
		return {"ok": false}
	var committed := _carry.commit_victory(_node, _battle, _party)
	if not committed["ok"]:
		return {"ok": false}
	_deck = resolved["deck"].duplicate(true)
	_gold = resolved["gold"]
	_trinkets = resolved["trinkets"].duplicate(true)
	_ledger = _carry.read_state()
	_paid_battles.append(_battle)
	_pending = null
	return {"ok": true, "skipped": resolved["skipped"],
		"selected_id": selected_id, "state": read_state(),
		"receipt": {"node_id": _node, "node_kind": node_kind,
			"trinket_drop_id": trinket_drop_id}}


func _eligible(node_id: Variant, battle: CombatBattleResult, party: CombatParty) -> bool:
	if not node_id is String or _map == null or _rng == null or _carry == null:
		return false
	if not _map.is_generated() or _map.get_current_node_id() != node_id:
		return false
	if _map.get_generation_revision() != _map_revision \
			or _map.get_floors() != _graph or _carry.read_state() != _ledger:
		return false
	if not _map.get_node(node_id).get("type") in ["Fight", "Elite"]:
		return false
	if _paid_battles.has(battle) or not _carry.can_commit_victory(node_id, battle, party):
		return false
	return true


func _unchanged() -> bool:
	return _map.get_route() == _route and _party.get_heroes() == _heroes \
		and _battle._enemies.get_enemies() == _enemies
