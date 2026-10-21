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
var _wardrobe: RunPatchWardrobe


func clear_wardrobe(value: RunPatchWardrobe) -> void:
	if value == _wardrobe:
		_wardrobe = null


func can_bind_wardrobe(value: RunPatchWardrobe, owner: RunTornMending, expected: Dictionary) -> bool:
	return _valid and owner == torn and value != null and value.is_valid() \
		and (_wardrobe == null or _wardrobe == value) and value.get_snapshot() == expected \
		and expected.get("heroes") == _heroes and torn.read_state().heroes == _heroes \
		and _observer() != null


func bind_wardrobe(value: RunPatchWardrobe, owner: RunTornMending, expected: Dictionary) -> bool:
	if not can_bind_wardrobe(value, owner, expected):
		return false
	_wardrobe = value
	return true


func _projected_heroes() -> Array:
	if _wardrobe == null:
		return _heroes.duplicate(true)
	var coats: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/patches/m04_coat_patches.json"))
	if not coats is Array:
		return []
	var projected := RunPatchCoatRules.project_health(torn.read_state(), _wardrobe, coats)
	return projected.heroes


func _refresh_wardrobe() -> void:
	if _wardrobe != null:
		var state := _wardrobe.get_snapshot()
		_wardrobe.refresh_run_context(_heroes, state.owned, state.scraps, state.gold, state.cards, state)


## Reconcile against the admitted effective cap by ID, never the current slot.
## HP above the base cap is combat-only and cannot become permanent healing.
func _base_snapshot(raw: Array) -> Array:
	if not _valid_roster(raw, true) or not _valid_roster(_start, true):
		return []
	var caps := {}
	for hero in _start:
		caps[hero.id] = hero
	var normalized := raw.duplicate(true)
	for hero in normalized:
		if not caps.has(hero.id) or not _max_hp_by_id.has(hero.id) \
			or hero.max_hp != caps[hero.id].max_hp \
			or (caps[hero.id].hp == 0 and hero.hp != 0):
			return []
		hero.max_hp = _max_hp_by_id[hero.id]
		hero.hp = mini(hero.hp, hero.max_hp)
	return normalized


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
	var expected: Array = _projected_heroes()
	if not _valid_roster(observed, true) or expected.size() != observed.size():
		return false
	for i in range(expected.size()):
		expected[i].block = observed[i].block
	if observed != expected:
		return false
	_node = node
	_party = party
	_result = result
	_start = observed.duplicate(true)
	return true


func can_commit_victory(node_id: Variant, result: CombatBattleResult, party: CombatParty) -> bool:
	if not _valid or not _valid_id(node_id) or node_id != _node or _fight_ids.has(node_id) \
		or result == null or result != _result or party == null or party != _party \
		or result._party != party or result._enemies == null or not party.is_valid() \
		or result.get_outcome() != CombatBattleResult.VICTORY or party.is_defeated() \
		or not result._enemies.is_valid() or not result._enemies.is_victorious() \
		or torn.read_state().heroes != _heroes or not _same_identities(_heroes):
		return false
	var proposal := _observer()
	return proposal != null and proposal.observe_battle_end(node_id,
		_base_snapshot(_start), _base_snapshot(party.get_heroes())).ok


func commit_victory(node_id: Variant, result: CombatBattleResult, party: CombatParty) -> Dictionary:
	if not can_commit_victory(node_id, result, party):
		return _rejected()
	_heroes = _base_snapshot(party.get_heroes())
	for hero in _heroes:
		hero.block = 0
	_fight_ids.append(node_id)
	return {"ok": true, "heroes": _heroes.duplicate(true)}


## Rebuild detached proposals through the service's public receipt API. Invalid
## observations never mutate either ledger, even before a rejected reward.
func _observer() -> RunTornMending:
	var proposal := RunTornMending.new(_initial)
	for receipt in _receipts:
		if receipt.has("start"):
			if not proposal.observe_battle_end(receipt.node, receipt.start, receipt.end).ok:
				return null
		elif receipt.has("mend"):
			if not proposal.choose_mend(receipt.node, receipt.mend, receipt.hero,
				receipt.position, receipt.scraps, proposal.read_state().heroes, true).ok:
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
		var raw: Array = _base_snapshot(party.get_heroes())
		for hero in raw:
			hero.block = 0
		if raw != _heroes:
			return null
	elif not can_commit_victory(node, result, party):
		return null
	var proposal := _observer()
	if proposal == null or not proposal.observe_battle_end(node,
		_base_snapshot(_start), _base_snapshot(party.get_heroes())).ok:
		return null
	return proposal


func apply_reward(node: String, result: CombatBattleResult, party: CombatParty) -> Dictionary:
	if not _fight_ids.has(node):
		return _rejected()
	var proposal := preview_reward(node, result, party)
	if proposal == null:
		return _rejected()
	_receipts.append({"node": node, "start": _base_snapshot(_start), "end": _base_snapshot(party.get_heroes())})
	torn = proposal
	_heroes = torn.read_state().heroes
	for hero in _heroes:
		_max_hp_by_id[hero.id] = hero.max_hp
	_refresh_wardrobe()
	return {"ok": true, "heroes": _heroes.duplicate(true)}


## Map-only transaction. An unbound run owner must commit remaining_scraps
## with these heroes; a bound wardrobe supplies the authoritative purse.
## Both expected snapshots are exact concurrency guards, never new state.
func choose_mend(node: Variant, receipt: Variant, hero: Variant, position: Variant,
		available_scraps: Variant, expected_carryover: Variant,
		expected_wardrobe: Variant, between_nodes: Variant) -> Dictionary:
	var rejected := {"ok": false, "heroes": [], "remaining_scraps": available_scraps}
	if not _valid or expected_carryover != read_state() \
		or torn.read_state().heroes != _heroes or not _same_identities(_heroes):
		return rejected
	# A claimed reward must have published the admitted battle before a mend.
	if _node != "" and not torn.read_state().completed_battles.has(_node):
		return rejected
	if _wardrobe == null:
		if expected_wardrobe != null:
			return rejected
	elif not _wardrobe.is_valid() or expected_wardrobe != _wardrobe.get_snapshot() \
		or expected_wardrobe.heroes != _heroes \
		or expected_wardrobe.scraps != available_scraps or expected_wardrobe.rest_id != "":
		return rejected
	if _wardrobe != null and _projected_heroes().is_empty():
		return rejected
	var proposal := _observer()
	if proposal == null:
		return rejected
	var mended := proposal.choose_mend(node, receipt, hero, position,
		available_scraps, _heroes, between_nodes)
	if not mended.ok:
		return rejected
	# Refresh validates the entire replacement before mutating any wardrobe
	# field. Nothing in the carryover is published until that commit succeeds.
	if _wardrobe != null and not _wardrobe.refresh_run_context(mended.heroes,
		expected_wardrobe.owned, mended.remaining_scraps, expected_wardrobe.gold,
		expected_wardrobe.cards, expected_wardrobe):
		return rejected
	torn = proposal
	_heroes = mended.heroes.duplicate(true)
	_receipts.append({"node": node, "mend": receipt, "hero": hero,
		"position": position, "scraps": available_scraps})
	return {"ok": true, "heroes": _heroes.duplicate(true),
		"remaining_scraps": mended.remaining_scraps}


func choose_rest_heal(node: Variant) -> Dictionary:
	var proposal := _observer()
	if proposal == null or not proposal.apply_rest(node, _heroes, true).ok:
		return _rejected()
	var recovered := super.choose_rest_heal(node)
	if not recovered.ok:
		return recovered
	torn = proposal
	_receipts.append({"node": node})
	_refresh_wardrobe()
	return recovered


func create_next_fight_party() -> CombatParty:
	if not _valid or not _valid_roster(_heroes, true) \
		or not _same_identities(_heroes) or _observer() == null or torn.read_state().heroes != _heroes:
		return null
	for hero in _heroes:
		if hero.block != 0:
			return null
	var projected := _projected_heroes()
	if not _valid_roster(projected, true):
		return null
	var patches: CombatShopPatchRules
	if _wardrobe != null:
		patches = CombatShopPatchRules.new()
		if not patches.bind_wardrobe(_wardrobe, torn):
			return null
	var party := CombatParty.new(projected)
	party._heroes.assign(projected)
	if patches != null:
		party.set_meta("shop_patch_projection", {
			"rules": patches, "heroes": projected.duplicate(true)})
	return party
