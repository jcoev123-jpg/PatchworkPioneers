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
# Battle-bound pending Wind-up Turret instances, committed only by a paid live
# play of this fight and fired only by an accepted end_turn below.
var _turrets: Array[Dictionary] = []
var _turret_service := CombatTinkerV3TurretCards.new()
# One Taunt authority per fight: both the mounted hand and enemy turn use this instance.
var _taunt_service := CombatWardenV3TauntCards.new()
# One Eyelet Guard authority per fight: the mounted held cast arms it and the
# same instance's retaliation is quoted by the enemy turn. It is never a status
# key and is never recreated per click, so a second fight starts unarmed.
var _eyelet_guard := CombatButtonGolemEyeletGuardCards.new()
# Exactly one authenticated Shield Catch / Guard Stitch latch per admitted fight.
var _v3_guard := CombatWardenV3GuardCards.new()


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
	_eyelet_guard.reset_fight()
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


## Validate a real held Warden Taunt against this fight before spending anything.
func can_play_warden_taunt_card(card_id: Variant) -> bool:
	if not _started or not _valid_bindings() or not _deck.turn_active:
		return false
	if _deck != _battle_deck or _party != _battle_party \
			or _enemies != _battle_enemies or _intents != _battle_intents \
			or _result != _battle_result:
		return false
	if not _result.can_continue() or _party.is_defeated() or _enemies.is_victorious():
		return false
	if not _taunt_service.is_supported_card(card_id):
		return false
	var kind: String = CombatWardenV3TauntCards.CARDS[card_id]["target_kind"]
	return bool(_taunt_service._prepare(_deck, _party, card_id, kind, 0).get("ok", false))


func play_warden_taunt_card(card_id: Variant) -> bool:
	if not can_play_warden_taunt_card(card_id):
		return false
	var kind: String = CombatWardenV3TauntCards.CARDS[card_id]["target_kind"]
	return bool(_taunt_service.play_card(_deck, _party, card_id, kind, 0).get("ok", false))


## Validate a real held Button Golem Eyelet Guard against THIS admitted fight
## before spending anything. Self-only, so no target seat is ever selected.
func can_play_button_golem_eyelet_card(card_id: Variant) -> bool:
	if not _started or not _valid_bindings() or not _deck.turn_active:
		return false
	if _deck != _battle_deck or _party != _battle_party \
			or _enemies != _battle_enemies or _intents != _battle_intents \
			or _result != _battle_result:
		return false
	if not _result.can_continue() or _party.is_defeated() or _enemies.is_victorious():
		return false
	if not _eyelet_guard.is_supported_card(card_id):
		return false
	return bool(_eyelet_guard._prepare(_deck, _party, card_id, 0).get("ok", false))


## Paid Eyelet Guard/Guard+ through the fight's ONE resolver: the printed Block
## lands on the Golem's real seat and its printed one-turn Thorns is armed on
## this same instance, which end_turn quotes and the next player turn expires.
func play_button_golem_eyelet_card(card_id: Variant) -> bool:
	if not can_play_button_golem_eyelet_card(card_id):
		return false
	return bool(_eyelet_guard.play_card(_deck, _party, card_id, 0).get("ok", false))


## This fight's single Eyelet Guard authority. Read-only for callers: the mode is
## armed only by a paid play and cleared only by this flow's own turn boundary.
func get_eyelet_guard_authority() -> CombatButtonGolemEyeletGuardCards:
	return _eyelet_guard


## The real held-card and ally-target preflight; never accept a stale fight,
## a fake printing, or an unavailable recipient. The service owns all numbers.
func can_play_warden_guard_card(card_id: Variant, target_position: int) -> bool:
	if not _started or not _valid_bindings() or not _deck.turn_active:
		return false
	if _deck != _battle_deck or _party != _battle_party \
			or _enemies != _battle_enemies or _intents != _battle_intents \
			or _result != _battle_result:
		return false
	if not _result.can_continue() or _party.is_defeated() or _enemies.is_victorious():
		return false
	return bool(_v3_guard._prepare(_deck, _party, card_id, target_position).get("ok", false))


func play_warden_guard_card(card_id: Variant, target_position: int) -> bool:
	if not can_play_warden_guard_card(card_id, target_position):
		return false
	return bool(_v3_guard.play_card(_deck, _party, card_id, target_position).get("ok", false))


func get_warden_guard_authority() -> CombatWardenV3GuardCards:
	return _v3_guard


## A private per-execution reaction adapter is essential: the phase executor
## rehearses attacks on detached parties before the authoritative commit.
func _phase_reactions() -> CombatWardenGuardReactions:
	if not _v3_guard.has_pending_guard():
		return _reactions
	var base := _reactions if _reactions != null else CombatWardenGuardReactions.new()
	return base.phase_adapter(_v3_guard)


## True only while this begun fight can still accept a freshly paid turret:
## the admitted actors, an active hand and a result that can continue.
func can_register_turret() -> bool:
	if not _started or not _valid_bindings() or not _deck.turn_active:
		return false
	if _deck != _battle_deck or _party != _battle_party \
			or _enemies != _battle_enemies or _intents != _battle_intents \
			or _result != _battle_result:
		return false
	return _result.can_continue() and not _party.is_defeated() and not _enemies.is_victorious()


## Keep one detached, freshly deployed three-beat turret for this fight. A
## malformed, partly spent or foreign instance is refused and nothing is stored.
func register_turret(state: Variant) -> bool:
	if not can_register_turret() or not CombatTinkerV3TurretCards.is_pending_instance(state):
		return false
	if int(state["remaining"]) != CombatTinkerV3TurretCards.DURATION_TURNS:
		return false
	_turrets.append(state.duplicate(true))
	return true


## Detached copies of this fight's live turrets, in deployment order.
func get_turrets() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for state in _turrets:
		copies.append(state.duplicate(true))
	return copies


## The battle session closed: no pending turret may survive into any later fight.
func clear_turrets() -> void:
	_turrets.clear()


func clear_taunt() -> void:
	_taunt_service.complete_enemy_turn()


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
	# An armed Taunt redirects THIS announced phase, so refuse to run it against
	# any fight other than the one that authenticated the arming. Ordinary turns
	# keep their existing binding checks alone: legacy fixtures legitimately
	# swap a valid scheduler, and a detached already-active oracle never went
	# through begin_fight.
	if (_taunt_service.has_pending_taunt() or _v3_guard.has_pending_guard()) \
			and (_deck != _battle_deck or _party != _battle_party \
				or _enemies != _battle_enemies or _intents != _battle_intents \
				or _result != _battle_result):
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
	# Turret shots precede the enemy phase; a slain shove source must not
	# move heroes during Taunt projection. Both roster and RNG stay detached.
	var turret_plan := _turrets_are_executable()
	if not turret_plan["ok"]:
		return false
	# Rehearse the cached actions in the executor's source order. A shove can
	# move the Warden before a later attack; attacks can also down a target
	# before a bound policy falls back. Each beat is applied only to detached
	# actors. The whole-phase preflight below still owns admission/atomicity.
	if _taunt_service.has_pending_taunt() and not turret_plan["victorious"]:
		var projected_party := CombatParty.new(tick["actors"])
		projected_party._heroes.assign(tick["actors"].duplicate(true))
		var projected_enemies := CombatEnemies.new(turret_plan["roster"])
		projected_enemies._enemies.assign(turret_plan["roster"].duplicate(true))
		var preview_reactions := _phase_reactions()
		var ordered: Array = effective.duplicate(true)
		ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.enemy_position < b.enemy_position)
		var projected: Array = []
		for action in ordered:
			var beat: Dictionary = action
			if action.get("type") == "attack":
				var announced: Dictionary = action
				if bound_policies:
					announced = CombatEnemyIntents.resolve_announced_action(
						projected_party, action, projected_enemies)
				var plan := _taunt_service.project_enemy_action(projected_party, announced)
				if not plan.get("ok", false):
					return false
				beat = plan["action"]
			projected.append(beat)
			# The existing executor owns legal shove/special semantics, multi-hit
			# damage and source deaths. No authoritative party, deck or RNG writes.
			# The same Eyelet authority is quoted here, so a projected Thorns kill
			# matches what the committed phase will really do.
			if not CombatEnemyPhase.new().execute_phase(projected_party,
					projected_enemies, [beat], preview_reactions, bound_policies,
					_eyelet_guard).get("ok", false):
				return false
		effective = projected
	if not turret_plan["victorious"] \
			and not _phase_is_executable(tick["actors"], effective, turret_plan["roster"]):
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
	# End-of-player-turn turret shots land before any enemy acts; a turret kill
	# of the last enemy ends the fight before retaliation.
	_fire_turrets()
	if _result.evaluate() != CombatBattleResult.ACTIVE:
		return true
	var committed_reactions := _phase_reactions()
	var phase := CombatEnemyPhase.new().execute_phase(_party, _enemies, effective, committed_reactions,
		_intents.is_bound(), _eyelet_guard)
	# _phase_is_executable prevalidates the entire batch against this roster.
	if not phase["ok"]:
		return false
	# Even a lethal enemy phase is complete: consume the one armed Taunt now,
	# not during preflight or on a refused End Turn.
	_taunt_service.complete_enemy_turn()
	if committed_reactions != null:
		var confirmed: Dictionary = committed_reactions.confirmed_v3_guard_hit()
		if not confirmed.is_empty():
			# The witness is the actual pre-hit staged roster and announced seat.
			# Post-hit HP/death or a preceding shove cannot invalidate the receipt.
			_v3_guard.consume_confirmed_hit(confirmed["party"], confirmed["target"], true)
	# A birth expands the genuine fight's gauge without resetting its older
	# charges. That child becomes a legal target and source next player turn.
	if _unravel != null and _enemies.get_enemies().size() > _unravel._gauges.size():
		if not _unravel.admit_broodling(_enemies):
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
		# them only after an accepted new player turn has opened. The armed
		# Eyelet Guard Thorns lasts exactly that same one turn.
		if _reactions != null:
			_reactions.begin_player_turn()
		_eyelet_guard.expire_on_next_player_turn()
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


## Rehearse each live turret's next beat with the real resolver on a detached
## roster and a copy of the run RNG. Returns the roster those shots would leave.
func _turrets_are_executable() -> Dictionary:
	var roster := _enemies.get_enemies()
	if _turrets.is_empty():
		return {"ok": true, "victorious": false, "roster": roster}
	var enemies := CombatEnemies.new(roster)
	enemies._enemies.assign(roster.duplicate(true))
	var rng := RandomNumberGenerator.new()
	rng.seed = _deck._rng.seed
	rng.state = _deck._rng.state
	for state in _turrets:
		if not _turret_service.tick_turret(state, enemies, rng)["ok"]:
			return {"ok": false}
	return {"ok": true, "victorious": enemies.is_victorious(), "roster": enemies.get_enemies()}


## Fire every live turret once, in deployment order, with the shared run RNG,
## then drop the instances whose three beats are spent.
func _fire_turrets() -> void:
	var next: Array[Dictionary] = []
	for state in _turrets:
		var receipt := _turret_service.tick_turret(state, _enemies, _deck._rng)
		if receipt["ok"] and int(receipt["remaining"]) > 0:
			next.append(receipt["state"])
	_turrets = next


func _phase_is_executable(next_heroes: Array, effective: Array, roster: Array = []) -> bool:
	# Use the actual executor on independent actors to preflight every announced
	# action, including capacity checks, without touching live actors or RNG.
	var party := CombatParty.new(next_heroes)
	party._heroes.assign(next_heroes.duplicate(true))
	if roster.is_empty():
		roster = _enemies.get_enemies()
	var enemies := CombatEnemies.new(roster)
	enemies._enemies.assign(roster.duplicate(true))
	if not CombatEnemyPhase.new().execute_phase(party, enemies, effective, _phase_reactions(),
			_intents.is_bound(), _eyelet_guard)["ok"]:
		return false
	return CombatStatusTurnBatch.new().tick_side("enemies", enemies.get_enemies())["ok"]
