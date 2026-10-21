class_name RunTornCarryover
extends RunPartyCarryover
## Keep M03 reward settlement authoritative; publish tears only after its claim.

var torn: RunTornMending
var _initial: Array = []
var _receipts: Array = []
var _start: Array = []
var _node := ""
var _party: CombatParty
var _result: CombatBattleResult


func _init(initial_heroes: Variant = null) -> void:
	super(initial_heroes)
	torn = RunTornMending.new(initial_heroes)
	_valid = _valid and torn.is_valid()
	if _valid:
		_initial = initial_heroes.duplicate(true)


func begin_battle(node: String, result: CombatBattleResult, party: CombatParty) -> bool:
	if not _valid or result == null or party == null or result._party != party \
		or result.get_outcome() != CombatBattleResult.ACTIVE or not party.is_valid() \
		or not _valid_id(node) or _fight_ids.has(node) or torn.read_state().heroes != _heroes:
		return false
	var observed: Array = party.get_heroes()
	var expected: Array = _heroes.duplicate(true)
	for i in range(expected.size()):
		expected[i].block = observed[i].block
	if observed != expected:
		return false
	_node = node
	_party = party
	_result = result
	_start = observed.duplicate(true)
	return true


## Rebuild detached proposals through the service's public receipt API. Invalid
## observations never mutate either ledger, even before a rejected reward.
func _observer() -> RunTornMending:
	var proposal := RunTornMending.new(_initial)
	for receipt in _receipts:
		if receipt.has("start"):
			if not proposal.observe_battle_end(receipt.node, receipt.start, receipt.end).ok:
				return null
		elif not proposal.apply_rest(receipt.node, proposal.read_state().heroes, true).ok:
			return null
	if proposal.read_state() != torn.read_state():
		return null
	return proposal


func preview_reward(node: String, result: CombatBattleResult, party: CombatParty) -> RunTornMending:
	if node != _node or result != _result or party != _party or result == null \
		or result._party != party or result._enemies == null or party == null \
		or not party.is_valid() or party.is_defeated() \
		or result.get_outcome() != CombatBattleResult.VICTORY \
		or not result._enemies.is_valid() or not result._enemies.is_victorious() \
		or torn.read_state().completed_battles.has(node):
		return null
	if _fight_ids.has(node):
		var raw: Array = party.get_heroes()
		for hero in raw:
			hero.block = 0
		if raw != _heroes:
			return null
	elif not super.can_commit_victory(node, result, party):
		return null
	var proposal := _observer()
	if proposal == null or not proposal.observe_battle_end(node, _start, party.get_heroes()).ok:
		return null
	return proposal


func apply_reward(node: String, result: CombatBattleResult, party: CombatParty) -> Dictionary:
	if not _fight_ids.has(node):
		return _rejected()
	var proposal := preview_reward(node, result, party)
	if proposal == null:
		return _rejected()
	_receipts.append({"node": node, "start": _start.duplicate(true), "end": party.get_heroes()})
	torn = proposal
	_heroes = torn.read_state().heroes
	for hero in _heroes:
		_max_hp_by_id[hero.id] = hero.max_hp
	return {"ok": true, "heroes": _heroes.duplicate(true)}


func choose_rest_heal(node: Variant) -> Dictionary:
	var proposal := _observer()
	if proposal == null or not proposal.apply_rest(node, _heroes, true).ok:
		return _rejected()
	var recovered := super.choose_rest_heal(node)
	if not recovered.ok:
		return recovered
	torn = proposal
	_receipts.append({"node": node})
	return recovered


func create_next_fight_party() -> CombatParty:
	if not _valid or not _valid_roster(_heroes, true) \
		or not _same_identities(_heroes) or _observer() == null or torn.read_state().heroes != _heroes:
		return null
	for hero in _heroes:
		if hero.block != 0:
			return null
	var party := CombatParty.new(_heroes)
	party._heroes.assign(_heroes.duplicate(true))
	return party
