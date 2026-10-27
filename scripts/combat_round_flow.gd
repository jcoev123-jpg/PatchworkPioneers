class_name CombatRoundFlow
extends RefCounted
## Scene-free single-fight transition owner. Other card plays happen elsewhere;
## callers must observe the battle result after each completed play.

var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _intents: CombatEnemyIntents
var _result: CombatBattleResult
var _unravel: CombatUnravel
var _reactions: CombatWardenGuardReactions
var _opening_block: CombatStartingBlock
var _started := false
# Immutable admission identities for the paid-card entry point.
var _battle_deck: CombatDeck
var _battle_party: CombatParty
var _battle_enemies: CombatEnemies
var _battle_intents: CombatEnemyIntents
var _battle_result: CombatBattleResult


func _init(deck: CombatDeck = null, party: CombatParty = null,
		enemies: CombatEnemies = null, intents: CombatEnemyIntents = null,
		result: CombatBattleResult = null, unravel: CombatUnravel = null,
		reactions: CombatWardenGuardReactions = null,
		path_receipt: Variant = null) -> void:
	_deck = deck
	_party = party
	_enemies = enemies
	_intents = intents
	_result = result
	_unravel = unravel
	_reactions = reactions
	_opening_block = CombatStartingBlock.new(party, path_receipt)


## Begin exactly once: clear inherited hero Block, deal the first hand, then
## grant base opening Block and the optional worn Badge bonus once.
## The turn-zero intents are not advanced.
func begin_fight() -> bool:
	if _started or not _valid_bindings():
		return false
	if _deck.turn_active or _deck.energy != 0 or not _deck.hand.is_empty():
		return false
	# A first fight must not begin from a previously used shared deck.
	if not _deck.discard_pile.is_empty() or _deck.draw_pile.size() < CombatDeck.TURN_DRAW:
		return false
	# A downed Warden can be carried with living allies; the one-shot helper skips him.
	if _party.is_defeated() or _enemies.is_victorious() or not _result.can_continue():
		return false
	# Authenticate an optional Path before clearing Block or drawing cards.
	# Vanguard's zero is valid; a negative result is a forged receipt.
	var has_warden := false
	for hero in _party.get_heroes():
		has_warden = has_warden or hero.id == "warden"
	if (has_warden and not _opening_block.can_open()) \
		or (not has_warden and _opening_block.get_path_receipt() != null):
		return false
	# The optional battle-local projection is detached from the run wardrobe.
	# Reject a malformed binding or a roster changed since its admission before
	# clearing Block, dealing cards, or consuming the shared run RNG.
	var patches: CombatShopPatchRules
	if _party.has_meta("shop_patch_projection"):
		var projection: Variant = _party.get_meta("shop_patch_projection")
		if not projection is Dictionary or not projection.get("rules") is CombatShopPatchRules:
			return false
		patches = projection.rules
		if not patches.is_valid() or projection.get("heroes") != _party.get_heroes():
			return false
	# Preflight checked the unique Warden and authentic carryover before mutation.
	# A downed Warden is deliberately allowed without an opening latch.
	var living_warden := has_warden and not _party.is_downed(_opening_block._warden_position())
	_party.start_player_turn()
	if living_warden and not _opening_block.apply():
		return false
	_deck.start_turn()
	if patches != null:
		for hero in _party.get_heroes():
			var bonus := patches.opening_block_bonus(hero.id)
			if bonus > 0:
				_party.gain_block(hero.position, bonus)
	_started = true
	_battle_deck = _deck
	_battle_party = _party
	_battle_enemies = _enemies
	_battle_intents = _intents
	_battle_result = _result
	# The initial accepted player turn must not inherit modes from an older fight.
	if _reactions != null:
		_reactions.begin_player_turn()
	return true


## Admit one authored Warden reaction from this fight's real shared hand.
## Stage optional mode authority only for a successful paid play. Refusals
## never observe/advance the result or alter actors, piles, intents or RNG.
func play_warden_reaction_card(card_id: Variant) -> bool:
	if not card_id is String or not CombatWardenGuardReactions.ALLOWED_CARD_IDS.has(card_id):
		return false
	if not _started or not _valid_bindings():
		return false
	if _deck.combat_state == null or not is_instance_valid(_deck.combat_state) \
			or not _deck.turn_active:
		return false
	# A coordinator may be tampered with after fight admission. Do not let
	# a newly supplied deck or roster play cards against a different battle.
	if _deck != _battle_deck or _party != _battle_party \
			or _enemies != _battle_enemies or _intents != _battle_intents \
			or _result != _battle_result:
		return false
	if _deck.energy < 0 or _deck.energy > CombatState.TURN_ENERGY:
		return false
	# Check current actors without calling evaluate(): failed actions must not
	# latch even a previously unobserved terminal result.
	if not _result.can_continue() or _party.is_defeated() or _enemies.is_victorious():
		return false
	var candidate: CombatWardenGuardReactions = _reactions
	if candidate == null:
		candidate = CombatWardenGuardReactions.new()
	if not candidate.play_from_hand(_deck, _party, card_id):
		return false
	if _reactions == null:
		_reactions = candidate
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
	# Snapshot pending skips before any state is committed. The intent scheduler
	# keeps all original sources; only this phase's executable subset changes.
	var skipped: Array[int] = []
	if _unravel != null:
		for index in range(_enemies.get_enemies().size()):
			var position := index + 1
			if not _enemies.is_slain(position) and _unravel.get_snapshot(position)["skip_pending"]:
				skipped.append(position)
	# The phase adjusts each base attack at its execution point, after earlier
	# swaps/debuffs and the hero owner tick, while enemy Weak still applies.
	var effective := _intents.get_intents().duplicate(true)
	# An announced status cannot affect a hero already down at this turn's
	# boundary. Omit that beat without retargeting, so surviving allies can
	# finish the fight. A battle-bound policy announcement instead resolves its
	# own deterministic living-target fallback in the executor. The phase still
	# rejects a target downed by an earlier action in the SAME batch, preserving
	# its transactional validation.
	var bound_policies := _intents.is_bound()
	effective = effective.filter(func(action: Dictionary) -> bool:
		return action.enemy_position not in skipped \
			and not (action.type == "debuff" and _party.is_downed(action.target_position)
				and not bound_policies))
	if not _phase_is_executable(tick["actors"], effective):
		return false
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
	var phase := CombatEnemyPhase.new().execute_phase(_party, _enemies, effective, _reactions,
		_intents.is_bound())
	# _phase_is_executable prevalidates the entire batch against this roster.
	if not phase["ok"]:
		return false
	# A skipped action is consumed only after the actual phase succeeds, and
	# never for a source that died before its action could occur.
	if _unravel != null:
		for position in skipped:
			if not _enemies.is_slain(position):
				_unravel.consume_action_skip(_enemies, position)
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
	# Bleed is applied at the enemy owner's boundary, AFTER its action/skip.
	# Charge one Unravel per positive tick only on enemies still alive after
	# the authoritative HP/status commit, regardless of Bleed magnitude.
	if _unravel != null:
		for event in enemy_tick["events"]:
			var position: int = event["position"]
			if event["bleed_hp_loss"] > 0 and not _enemies.is_slain(position):
				_unravel.record_bleed_tick(_enemies, position)
	if _result.evaluate() == CombatBattleResult.ACTIVE:
		_intents.advance_turn()
		_party.start_player_turn()
		_deck.start_turn()
		# Retain Guarding and Thorns for the entire enemy phase, then expire
		# them only after an accepted new player turn has opened.
		if _reactions != null:
			_reactions.begin_player_turn()
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
	if not _valid_unravel_binding() or not _valid_reactions_binding():
		return false
	# Once begun, position changes are allowed but the original three actor
	# identities, occupied slot indices, and statuses remain authoritative.
	# A downed hero stays in their slot; no formation rollback is required.
	var ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = _party.get_hero(index + 1)
		if hero.get("id") not in RunV3PartyAdmission.HERO_IDS \
				or hero["id"] in ids:
			return false
		# Run carryover can lower his cap after a tear or raise it with a coat.
		# Without a worn-patch projection, a raw over-cap roster is invalid.
		if hero["id"] == "warden" and hero.get("max_hp", 0) > CombatStartingBlock.WARDEN_MAX_HP \
				and not _party.has_meta("shop_patch_projection"):
			return false
		ids.append(hero["id"])
	var preflight := CombatStatusTurnBatch.new()
	if not preflight.tick_side("heroes", _party.get_heroes())["ok"] \
			or not preflight.tick_side("enemies", _enemies.get_enemies())["ok"]:
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


func _valid_unravel_binding() -> bool:
	if _unravel == null:
		return true
	if not is_instance_valid(_unravel) or _unravel._bound_enemies != _enemies:
		return false
	# Validate every original slot, including slain slots: a partial or forged
	# binding must be rejected before any turn/deck/RNG mutation.
	for index in range(_enemies.get_enemies().size()):
		var snapshot: Dictionary = _unravel.get_snapshot(index + 1)
		if snapshot.size() != 4:
			return false
		var gauge = snapshot.get("gauge")
		var threshold = snapshot.get("threshold")
		var pending = snapshot.get("skip_pending")
		var unravelled = snapshot.get("unravelled")
		if not gauge is int or not threshold is int \
				or not pending is bool or not unravelled is bool:
			return false
		if threshold <= 0 or gauge < 0 or gauge > threshold \
				or pending != unravelled or (gauge == threshold) != pending:
			return false
	return true


func _valid_reactions_binding() -> bool:
	if _reactions == null:
		return true
	# Refuse a damaged/expired optional authority before touching any live
	# deck, actor, phase, result or RNG state.
	return is_instance_valid(_reactions) and _reactions.get_thorns() >= 0 \
		and _reactions.get_thorns() <= CombatParty.MAX_INT


func _phase_is_executable(next_heroes: Array, effective: Array) -> bool:
	# Use the actual executor on independent actors to preflight every announced
	# action, including capacity checks, without touching live actors or RNG.
	var party := CombatParty.new(next_heroes)
	party._heroes.assign(next_heroes.duplicate(true))
	var roster := _enemies.get_enemies()
	var enemies := CombatEnemies.new(roster)
	enemies._enemies.assign(roster.duplicate(true))
	if not CombatEnemyPhase.new().execute_phase(party, enemies, effective, _reactions,
			_intents.is_bound())["ok"]:
		return false
	return CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())["ok"]
