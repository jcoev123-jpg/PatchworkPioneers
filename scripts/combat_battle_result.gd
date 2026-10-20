class_name CombatBattleResult
extends RefCounted
## Per-fight observation of authoritative CombatParty / CombatEnemies state.
## Call evaluate() after each fully resolved action or phase, then can_continue()
## before dispatching the next one. This service never modifies either roster.
## UNRESOLVED is a non-playable, fail-closed state (invalid roster or a tie).

const ACTIVE := "ACTIVE"
const VICTORY := "VICTORY"
const DEFEAT := "DEFEAT"
const UNRESOLVED := "UNRESOLVED"

var _party: CombatParty
var _enemies: CombatEnemies
var _outcome: String = UNRESOLVED


func _init(party: CombatParty, enemies: CombatEnemies) -> void:
	_party = party
	_enemies = enemies
	# A new fight needs two valid, living sides. Preexisting terminal/invalid
	# states are not results of a witnessed action and cannot be played.
	if _has_valid_rosters() and not _party.is_defeated() and not _enemies.is_victorious():
		_outcome = ACTIVE


## Observe the just-completed action/phase. First terminal observation wins.
func evaluate() -> String:
	if _outcome != ACTIVE:
		return _outcome
	if not _has_valid_rosters():
		_outcome = UNRESOLVED
		return _outcome
	var all_heroes_down := _party.is_defeated()
	var all_enemies_dead := _enemies.is_victorious()
	if all_heroes_down and all_enemies_dead:
		# No game-design tie-breaker exists. Never assign either winner.
		_outcome = UNRESOLVED
	elif all_enemies_dead:
		_outcome = VICTORY
	elif all_heroes_down:
		_outcome = DEFEAT
	return _outcome


## Explicit alias for callers checking a result after action resolution.
func check_outcome() -> String:
	return evaluate()


## Return only the previously observed outcome, without reevaluating actors.
func get_outcome() -> String:
	return _outcome


## This gate describes service-approved continuation, not a guard on the
## independent party/enemy mutation APIs. Call evaluate() first.
func can_continue() -> bool:
	return _outcome == ACTIVE


func is_finished() -> bool:
	return _outcome == VICTORY or _outcome == DEFEAT


func _has_valid_rosters() -> bool:
	return _party != null and _party.is_valid() and _enemies != null and _enemies.is_valid()