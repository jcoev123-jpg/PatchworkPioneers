class_name RunFightVictoryRewards
extends RefCounted
## One pending post-victory Fight/Elite reward: gold and one card (or skip), plus
## one seeded trinket drop for an Elite.
## The *only* run RNG consumption is during the first successful prepare:
## 1 gold randi_range draw, then either the three legacy sorted-ID offer draws or
## the weighted six-draw D2-1 pool selection, then (Elite only) 1 sorted unowned
## trinket draw.
## Work on a cloned seed/state and publish that state atomically only after the
## reward transaction and Elite selection succeed.
## An optional Rest stitch ledger (owned descriptors plus allocator cursor) is
## frozen beside the run deck so an authentic composite is an accepted party card.

const MAX_INT := 9223372036854775807

var _battle: CombatBattleResult
var _rng: Variant
var _party_ids: Variant
var _candidate_ids: Variant
var _candidate_mode: String = "ids"
var _source_deck: Variant
var _starting_gold: Variant
var _elite: bool
var _stitched_descriptors: Variant
var _next_stitch_id: Variant
var _trinket_candidates: Variant
var _owned_trinket_ids: Variant
var _choice: RunCardRewardChoice = null
var _gold_service: RunVictoryGold = null
var _award: int = 0
var _trinket_drop_id: String = ""
var _prepared: bool = false


func _init(battle: CombatBattleResult, run_rng: Variant, party_ids: Variant,
		candidate_ids: Variant, run_deck: Variant, current_gold: Variant,
		is_elite: bool, trinket_candidates: Variant = [],
		owned_trinket_ids: Variant = [], stitched_descriptors: Variant = {},
		next_stitch_id: Variant = 1) -> void:
	_battle = battle
	_rng = run_rng
	_party_ids = party_ids.duplicate(true) if party_ids is Array else party_ids
	_candidate_ids = candidate_ids.duplicate(true) if candidate_ids is Array else candidate_ids
	_candidate_mode = _classify_candidates(_candidate_ids)
	_source_deck = run_deck.duplicate(true) if run_deck is Array else run_deck
	_starting_gold = current_gold
	_elite = is_elite
	_trinket_candidates = trinket_candidates.duplicate(true) if trinket_candidates is Array else trinket_candidates
	_owned_trinket_ids = owned_trinket_ids.duplicate(true) if owned_trinket_ids is Array else owned_trinket_ids
	# The run's stitch ledger is frozen beside the deck: a composite that was
	# owned when the reward was prepared keeps its exact authored halves, so a
	# later registry edit can never rewrite what this reward source admitted.
	_stitched_descriptors = (stitched_descriptors.duplicate(true)
		if stitched_descriptors is Dictionary else stitched_descriptors)
	_next_stitch_id = next_stitch_id


## Legacy callers supply authored catalog ID Strings; the routed run supplies
## D2-1 base records ({id, owner, rarity}). A mixed or otherwise malformed list
## fails closed instead of silently falling back to an unweighted draw.
static func _classify_candidates(candidates: Variant) -> String:
	if not candidates is Array:
		return "ids"
	var has_records := false
	var has_ids := false
	for candidate: Variant in candidates:
		if candidate is Dictionary:
			has_records = true
		elif candidate is String:
			has_ids = true
		else:
			return "invalid"
	if has_records and has_ids:
		return "invalid"
	return "records" if has_records else "ids"


func prepare() -> Dictionary:
	if _prepared:
		return _prepared_response()
	var rejected := {"ok": false, "gold_award": 0, "offers": [], "trinket_drop_id": ""}
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
	if _candidate_mode == "invalid":
		return rejected
	if not _source_deck is Array or _source_deck.is_empty():
		return rejected
	# The run's stitch ledger must be authentic before anything is drawn:
	# RunRestStitchCards is the canonical structural admission for a deck plus
	# its owned composites. A malformed registry, cursor, descriptor or card ID
	# fails closed here, and no forged "stitched_*" name can pass by prefix.
	var stitch_ledger := RunRestStitchCards.new(_source_deck, _stitched_descriptors, 0,
		_next_stitch_id)
	if not stitch_ledger.is_valid():
		return rejected
	# A run deck contains actual party-owned authored card IDs, with duplicates
	# allowed. Previously awarded D2-1 pool base cards and authentic canonical
	# pool plus cards acquired at Rest stay valid in later rewards; a genuine
	# Rest composite is one deck member whose two different authored half owners
	# are both in this party. Unknown IDs still fail closed.
	for card_id in _source_deck:
		if not card_id is String or card_id.is_empty():
			return rejected
		if _stitched_descriptors.has(card_id):
			var descriptor: Dictionary = _stitched_descriptors[card_id]
			var first_half: Dictionary = descriptor.get("first_half", {})
			var second_half: Dictionary = descriptor.get("second_half", {})
			var first_owner: Variant = first_half.get("owner")
			var second_owner: Variant = second_half.get("owner")
			if not first_owner is String or not second_owner is String \
					or first_owner == second_owner \
					or not _party_ids.has(first_owner) or not _party_ids.has(second_owner):
				return rejected
			continue
		var definition: Dictionary = RunRestStitchCards.resolve_card_definition(card_id)
		if definition.is_empty() or not _party_ids.has(definition.get("owner")):
			return rejected
	# Validate the supplier-owned trinket lists and filter already-owned IDs
	# before the staged RNG is cloned or drawn from.
	var eligible_trinkets: Array[String] = []
	if _elite:
		var eligible: Variant = _eligible_trinket_ids()
		if eligible == null or eligible.is_empty():
			return rejected
		eligible_trinkets.assign(eligible)

	var living_ids: Array[String] = []
	if _candidate_mode == "records":
		var party: CombatParty = _battle._party if ("_party" in _battle) else null
		if party == null or not is_instance_valid(party) or not party.is_valid():
			return rejected
		var battle_heroes: Array[Dictionary] = party.get_heroes()
		if battle_heroes.size() != 3 or _party_ids.size() != 3:
			return rejected
		var battle_ids: Array[String] = []
		for hero_dict: Dictionary in battle_heroes:
			var hid_val: Variant = hero_dict.get("id")
			var hp_val: Variant = hero_dict.get("hp")
			if not (hid_val is String) or not (hp_val is int):
				return rejected
			var hid: String = hid_val
			var hp: int = hp_val
			if hid.is_empty() or battle_ids.has(hid):
				return rejected
			battle_ids.append(hid)
			if hp > 0:
				living_ids.append(hid)
		if battle_ids.size() != 3:
			return rejected
		for pid: Variant in _party_ids:
			if not (pid is String) or not battle_ids.has(pid):
				return rejected
		for bid: String in battle_ids:
			if not _party_ids.has(bid):
				return rejected
		if living_ids.is_empty():
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
	var choice: RunCardRewardChoice
	if _candidate_mode == "records":
		choice = _weighted_choice(staged_rng, living_ids)
	else:
		choice = RunCardRewardChoice.from_seeded_pool(
			staged_rng, _party_ids, _candidate_ids)
	if choice == null or not choice.is_valid():
		return rejected
	var trinket_drop_id := ""
	if _elite:
		var index: int = RunShopStockOffers.draw_patch_index(staged_rng, eligible_trinkets)
		trinket_drop_id = eligible_trinkets[index]

	_gold_service = gold_service
	_choice = choice
	_award = award
	_trinket_drop_id = trinket_drop_id
	_prepared = true
	_rng.state = staged_rng.state
	return _prepared_response()


## Weighted D2-1 selection on the same staged stream as the gold roll, so a
## failure here leaves the run RNG exactly where it was. Returns null on a
## rejected selection so prepare can fail closed.
func _weighted_choice(staged_rng: RandomNumberGenerator, living_ids: Array[String]) -> RunCardRewardChoice:
	var generated: Dictionary = RunPoolCardRewardOffers.generate_for_living(
		staged_rng, _party_ids, living_ids, _candidate_ids)
	if not generated.get("ok", false):
		return null
	var copied_party: Array[String] = []
	for party_id in _party_ids:
		copied_party.append(party_id)
	return RunCardRewardChoice.new(generated["offers"], copied_party)


## Empty String means explicit skip. A stale offered ID leaves the choice open.
## Failed or repeated calls never pay and return detached snapshots. A successful
## Elite claim returns the existing owned IDs plus the one cached drop.
func choose(selected_id: Variant) -> Dictionary:
	var original_deck: Array[String] = []
	if _source_deck is Array:
		for card_id in _source_deck:
			if card_id is String:
				original_deck.append(card_id)
	var rejected := {
		"ok": false, "skipped": false, "selected_id": "",
		"deck": original_deck, "gold": _starting_gold if _starting_gold is int else 0,
		"trinkets": _owned_inventory()
	}
	if not _prepared or _choice == null or _choice.is_claimed():
		return rejected
	if not selected_id is String:
		return rejected
	var result: Dictionary = _choice.claim(original_deck, selected_id)
	if not result.get("ok", false):
		return rejected
	var trinkets := _owned_inventory()
	if not _trinket_drop_id.is_empty():
		trinkets.append(_trinket_drop_id)
	return {
		"ok": true, "skipped": result["skipped"],
		"selected_id": result["selected_id"],
		"deck": result["deck"].duplicate(),
		"gold": _starting_gold + _award,
		"trinkets": trinkets
	}


func _prepared_response() -> Dictionary:
	return {
		"ok": true, "gold_award": _award, "offers": _choice.get_offers(),
		"trinket_drop_id": _trinket_drop_id
	}


## A detached copy of the caller's owned trinket inventory, never internal state.
func _owned_inventory() -> Array:
	var inventory: Array = []
	if _owned_trinket_ids is Array:
		inventory = _owned_trinket_ids.duplicate(true)
	return inventory


## Null for a malformed candidate/owned list, else the sorted, unowned IDs.
## An empty returned array means every candidate is already owned.
func _eligible_trinket_ids() -> Variant:
	if not _trinket_candidates is Array or not _owned_trinket_ids is Array:
		return null
	var owned := {}
	for owned_id in _owned_trinket_ids:
		if not owned_id is String or owned_id.is_empty():
			return null
		if owned.has(owned_id):
			return null
		owned[owned_id] = true
	var seen := {}
	var eligible: Array[String] = []
	for candidate in _trinket_candidates:
		if not candidate is String or candidate.is_empty():
			return null
		if seen.has(candidate):
			return null
		seen[candidate] = true
		if not owned.has(candidate):
			eligible.append(candidate)
	eligible.sort()
	return eligible
