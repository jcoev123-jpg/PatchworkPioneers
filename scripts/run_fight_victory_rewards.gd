class_name RunFightVictoryRewards
extends RefCounted
## One pending post-victory Fight/Elite reward: gold and one card (or skip).
## The *only* run RNG consumption is during the first successful prepare:
## 1 gold randi_range draw, followed by 3 sorted-pool offer draws.
## Work on a cloned seed/state and publish that state atomically only after
## both existing services succeed and the final gold sum is representable.

const MAX_INT := 9223372036854775807

var _battle: CombatBattleResult
var _rng: Variant
var _party_ids: Variant
var _candidate_ids: Variant
var _source_deck: Variant
var _starting_gold: Variant
var _elite: bool
var _choice: RunCardRewardChoice = null
var _gold_service: RunVictoryGold = null
var _award: int = 0
var _prepared: bool = false


func _init(battle: CombatBattleResult, run_rng: Variant, party_ids: Variant,
		candidate_ids: Variant, run_deck: Variant, current_gold: Variant,
		is_elite: bool) -> void:
	_battle = battle
	_rng = run_rng
	_party_ids = party_ids.duplicate(true) if party_ids is Array else party_ids
	_candidate_ids = candidate_ids.duplicate(true) if candidate_ids is Array else candidate_ids
	_source_deck = run_deck.duplicate(true) if run_deck is Array else run_deck
	_starting_gold = current_gold
	_elite = is_elite


func prepare() -> Dictionary:
	if _prepared:
		return {"ok": true, "gold_award": _award, "offers": _choice.get_offers()}
	var rejected := {"ok": false, "gold_award": 0, "offers": []}
	# Observe only previously evaluated battles; never call evaluate() here.
	if _battle == null or not is_instance_valid(_battle) \
			or _battle.get_outcome() != CombatBattleResult.VICTORY:
		return rejected
	if not _rng is RandomNumberGenerator or not is_instance_valid(_rng):
		return rejected
	if not _starting_gold is int or _starting_gold < 0:
		return rejected
	if not _party_ids is Array or not _candidate_ids is Array:
		return rejected
	if not _source_deck is Array or _source_deck.is_empty():
		return rejected
	var catalog := StarterCards.new()
	# A run deck contains actual party-owned authored card IDs, with duplicates
	# allowed. Neither invalid entries nor a mutated caller array can leak in.
	for card_id in _source_deck:
		if not card_id is String or card_id.is_empty():
			return rejected
		var definition: Dictionary = catalog.get_definition(card_id)
		if definition.is_empty() or not _party_ids.has(definition.get("owner")):
			return rejected

	var staged_rng := RandomNumberGenerator.new()
	staged_rng.seed = _rng.seed
	staged_rng.state = _rng.state
	var gold_service := RunVictoryGold.new(_battle)
	var award := gold_service.claim_gold(_elite, staged_rng)
	if award <= 0 or not gold_service.is_claimed():
		return rejected
	# Check the actual award before addition (avoids signed 64-bit wrap).
	if _starting_gold > MAX_INT - award:
		return rejected
	var choice := RunCardRewardChoice.from_seeded_pool(
		staged_rng, _party_ids, _candidate_ids)
	if not choice.is_valid():
		return rejected

	_gold_service = gold_service
	_choice = choice
	_award = award
	_prepared = true
	_rng.state = staged_rng.state
	return {"ok": true, "gold_award": _award, "offers": _choice.get_offers()}


## Empty String means explicit skip. A stale offered ID leaves the choice open.
## Failed or repeated calls never pay and return a detached base-deck snapshot.
func choose(selected_id: Variant) -> Dictionary:
	var original_deck: Array[String] = []
	if _source_deck is Array:
		for card_id in _source_deck:
			if card_id is String:
				original_deck.append(card_id)
	var rejected := {
		"ok": false, "skipped": false, "selected_id": "",
		"deck": original_deck, "gold": _starting_gold if _starting_gold is int else 0
	}
	if not _prepared or _choice == null or _choice.is_claimed():
		return rejected
	if not selected_id is String:
		return rejected
	var result: Dictionary = _choice.claim(original_deck, selected_id)
	if not result.get("ok", false):
		return rejected
	return {
		"ok": true, "skipped": result["skipped"],
		"selected_id": result["selected_id"],
		"deck": result["deck"].duplicate(),
		"gold": _starting_gold + _award
	}
