class_name CombatRoundFlow
extends RefCounted
## Scene-free single-fight transition owner. Card plays happen elsewhere; callers
## must observe the battle result after each completed play.

var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _intents: CombatEnemyIntents
var _result: CombatBattleResult
var _opening_block: CombatStartingBlock
var _started := false


func _init(deck: CombatDeck = null, party: CombatParty = null,
		enemies: CombatEnemies = null, intents: CombatEnemyIntents = null,
		result: CombatBattleResult = null) -> void:
	_deck = deck
	_party = party
	_enemies = enemies
	_intents = intents
	_result = result
	_opening_block = CombatStartingBlock.new(party)


## Begin exactly once: clear inherited hero Block, deal the first hand, then
## grant the Warden's one-shot +6. The turn-zero intents are not advanced.
func begin_fight() -> bool:
	if _started or not _valid_bindings():
		return false
	if _deck.turn_active or _deck.energy != 0 or not _deck.hand.is_empty():
		return false
	# A first fight must not begin from a previously used shared deck.
	if not _deck.discard_pile.is_empty() or _deck.draw_pile.size() < CombatDeck.TURN_DRAW:
		return false
	# Starting Block cannot be granted to a downed Warden; fail before
	# resetting any Block or dealing cards, even if other heroes still live.
	if _party.is_downed(1) or _party.is_defeated() \
			or _enemies.is_victorious() or not _result.can_continue():
		return false
	# Validated services make all three operations total for this initial state.
	_party.start_player_turn()
	_deck.start_turn()
	_opening_block.apply()
	_started = true
	return true


## Close one active hand, execute the CURRENT announced phase once, and
## advance announcements and deal a new hand only if the fight remains active.
func end_turn() -> bool:
	# Validate all actor fields before result/phase readers access live records.
	if not _started or _party == null or _enemies == null:
		return false
	var batch := CombatStatusTurnBatch.new()
	var tick := batch.tick_side("heroes", _party.get_heroes())
	if not tick["ok"] or not batch.tick_side("enemies", _enemies.get_enemies())["ok"]:
		return false
	if not _started or not _valid_bindings() or not _deck.turn_active:
		return false
	# A caller may have completed a lethal card play without explicitly
	# observing it yet. Never discard/draw or let enemies act on that state.
	if _result.evaluate() != CombatBattleResult.ACTIVE:
		return false
	if not _phase_is_executable(tick["actors"]):
		return false
	var announced := _intents.get_intents()
	# Preflight succeeded for the complete transition. Preserve authoritative
	# record identities and metadata; only the owner tick's fields are committed.
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = _party._heroes[index]
		var next: Dictionary = tick["actors"][index]
		hero["hp"] = next["hp"]
		hero["block"] = next["block"]
		if hero.has("statuses") or not next["statuses"].is_empty():
			hero["statuses"] = next["statuses"]
	_deck.end_turn()
	if _result.evaluate() != CombatBattleResult.ACTIVE:
		return true
	var phase := CombatEnemyPhase.new().execute_phase(_party, _enemies, announced)
	# _phase_is_executable prevalidates the entire batch against this roster.
	if not phase["ok"]:
		return false
	# Latch a phase defeat before enemy Bleed can also kill the last enemy.
	_result.evaluate()
	var enemy_tick := batch.tick_side("enemies", _enemies.get_enemies())
	for index in range(_enemies._enemies.size()):
		var enemy: Dictionary = _enemies._enemies[index]
		var next: Dictionary = enemy_tick["actors"][index]
		enemy["hp"] = next["hp"]
		enemy["block"] = next["block"]
		if enemy.has("statuses") or not next["statuses"].is_empty():
			enemy["statuses"] = next["statuses"]
	if _result.evaluate() == CombatBattleResult.ACTIVE:
		_intents.advance_turn()
		_party.start_player_turn()
		_deck.start_turn()
	return true


## Read/observe the result of an externally resolved card. This never
## advances a turn, changes an actor or consumes deck RNG.
func observe_result() -> String:
	if not _started or not _valid_bindings():
		return CombatBattleResult.UNRESOLVED
	return _result.evaluate()


## Non-evaluating read of the last observed outcome.
func get_outcome() -> String:
	if _result == null:
		return CombatBattleResult.UNRESOLVED
	return _result.get_outcome()


func _valid_bindings() -> bool:
	if _deck == null or _party == null or _enemies == null \
			or _intents == null or _result == null:
		return false
	if not is_instance_valid(_deck) or not is_instance_valid(_party) \
			or not is_instance_valid(_enemies) or not is_instance_valid(_intents) \
			or not is_instance_valid(_result):
		return false
	if not _party.is_valid() or not _enemies.is_valid() or not _intents.is_valid():
		return false
	if _deck._rng == null or not is_instance_valid(_deck._rng):
		return false
	# CombatBattleResult must observe THESE authoritative actors, not a
	# separate still-ACTIVE fight that could incorrectly permit more turns.
	if _result._party != _party or _result._enemies != _enemies:
		return false
	# A replacement front hero has no Warden passive. Authored heroes must
	# still occupy their own slots; never accept a reversed/misplaced party.
	if _party.get_hero(1).get("id") in ["seamstress", "tinker"] \
			or _party.get_hero(2).get("id") != "seamstress" \
			or _party.get_hero(3).get("id") != "tinker":
		return false
	# The scheduler must contain exactly one action per actual occupied enemy
	# position: no phantom sources, gaps or omitted living/blocked enemies.
	var roster := _enemies.get_enemies()
	var announcements := _intents.get_intents()
	if announcements.size() != roster.size():
		return false
	for index in range(roster.size()):
		if announcements[index].get("enemy_position") != index + 1:
			return false
	return true


func _phase_is_executable(next_heroes: Array) -> bool:
	# Use the actual executor on independent actors to preflight every announced
	# action, including capacity checks, without touching live actors or RNG.
	var party := CombatParty.new(next_heroes)
	party._heroes.assign(next_heroes.duplicate(true))
	var roster := _enemies.get_enemies()
	var enemies := CombatEnemies.new(roster)
	enemies._enemies.assign(roster.duplicate(true))
	if not CombatEnemyPhase.new().execute_phase(party, enemies, _intents.get_intents())["ok"]:
		return false
	return CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())["ok"]
