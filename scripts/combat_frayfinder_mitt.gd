class_name CombatFrayfinderMitt
extends RefCounted
## Scene-free, battle-scoped bonus quote. Never resolves a card, changes a
## roster, rolls RNG, or spends a card/energy. Live adapter wiring is M05 follow-up.

const CATALOG := "res://data/patches/m05_attack_patches.json"
const PATCH_ID := "frayfinder_mitt"
const EFFECT := "first_single_target_half_unravel_attack_bonus"

const POOL_PLAIN_IDS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
]

const POOL_HEAVY_IDS := [
	"warden_heavy_thimble", "warden_heavy_thimble_plus",
	"warden_pin_and_pound", "warden_pin_and_pound_plus",
]

var _deck: CombatDeck
var _party: CombatParty
var _enemies: CombatEnemies
var _unravel: CombatUnravel
var _wardrobe: RunPatchWardrobe
var _torn: RunTornMending
## Live attack authority: authentic pre-commit Scope state for stitched replay.
var _attacks: CombatAttackCards = null
var _wardrobe_state: Dictionary = {}
var _torn_state: Dictionary = {}
var _active: Dictionary = {}
var _used: Dictionary = {}
var _turn_open := false
var _generation := 0
var _stitched_sequence: Dictionary = {}


func bind_battle(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		unravel: CombatUnravel, wardrobe: RunPatchWardrobe,
		torn: RunTornMending, attacks: CombatAttackCards = null) -> bool:
	# Invalid rebind invalidates any old battle, including all pending quotes.
	_turn_open = false
	_generation += 1
	_used.clear()
	_stitched_sequence.clear()
	_deck = null
	_party = null
	_enemies = null
	_unravel = null
	_wardrobe = null
	_torn = null
	_attacks = null
	_active.clear()
	if deck == null or party == null or enemies == null or unravel == null:
		return false
	if wardrobe == null or torn == null or not party.is_valid() or not enemies.is_valid():
		return false
	if not wardrobe.is_valid() or not torn.is_valid() or unravel._bound_enemies != enemies:
		return false
	if not _valid_catalog(JSON.parse_string(FileAccess.get_file_as_string(CATALOG))):
		return false
	var state := wardrobe.get_snapshot()
	var run_state := torn.read_state()
	var projection := wardrobe.project_active(run_state)
	if not _valid_projection(state, run_state, projection):
		return false
	for slot in range(1, enemies.get_enemies().size() + 1):
		if not _valid_gauge(unravel.get_snapshot(slot)):
			return false
	_deck = deck
	_party = party
	_enemies = enemies
	_unravel = unravel
	_wardrobe = wardrobe
	_torn = torn
	_attacks = attacks
	_wardrobe_state = state
	_torn_state = run_state
	_active = projection.active.duplicate(true)
	return true


func is_valid() -> bool:
	if _deck == null or _party == null or _enemies == null or _unravel == null:
		return false
	if _wardrobe == null or _torn == null:
		return false
	if not _party.is_valid() or not _enemies.is_valid() or _unravel._bound_enemies != _enemies:
		return false
	if _wardrobe.get_snapshot() != _wardrobe_state or _torn.read_state() != _torn_state:
		return false
	if not _valid_projection(_wardrobe_state, _torn_state,
			_wardrobe.project_active(_torn_state)):
		return false
	for position in range(1, _enemies.get_enemies().size() + 1):
		if not _valid_gauge(_unravel.get_snapshot(position)):
			return false
	return true


func begin_player_turn() -> bool:
	# Must follow an actual CombatDeck.start_turn(), and can open only once
	# until the real deck has ended that turn. Previews cannot reset latches.
	if not is_valid() or _turn_open or not _deck.turn_active or _deck.energy != 3:
		return false
	_turn_open = true
	_generation += 1
	_used.clear()
	_stitched_sequence.clear()
	return true


func end_player_turn() -> bool:
	if not _turn_open or _deck == null or _deck.turn_active:
		return false
	_turn_open = false
	return true


## Live RoundFlow atomically ends the old deck turn and starts the next one
## before the presenter can observe an inactive deck. Only the presenter,
## after witnessing a matching enemy-intents turn-index increment, calls this.
func advance_confirmed_turn() -> bool:
	if not _turn_open or not is_valid() or not _deck.turn_active or _deck.energy != 3:
		return false
	_turn_open = false
	return begin_player_turn()


func latch_snapshot() -> Dictionary:
	return _used.duplicate(true)


func quote_starter_hit(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	if not _ready() or not _deck.hand.has(card_id):
		return {"bonus": 0}
	if card_id not in CombatAttackCards.ATTACK_IDS:
		return {"bonus": 0}
	var definition := StarterCards.new().get_definition(card_id)
	if definition.get("id") != card_id or definition.get("target_kind") != "enemy_single":
		return {"bonus": 0}
	return _quote(definition, card_id, target_position, hit_number, "starter", 0, "",
		cost_discount)


func quote_stitched_half(run_cards: RunRestStitchCards, stitched_id: String,
		half_index: int, target_position: int, hit_number: int = 1) -> Dictionary:
	if not _ready() or run_cards == null or not run_cards.is_valid():
		return {"bonus": 0}
	if half_index not in [0, 1] or not _deck.hand.has(stitched_id):
		return {"bonus": 0}
	var preview := run_cards.preview_play(stitched_id, _party.get_heroes())
	if not preview.get("ok", false) or _deck.energy < preview.cost:
		return {"bonus": 0}
	var half: Dictionary = preview.halves[half_index]
	if half.get("target_kind") != "enemy_single":
		return {"bonus": 0}
	if half != RunRestStitchCards.resolve_card_definition(half.get("id", "")):
		return {"bonus": 0}
	var quote := _quote(half, stitched_id, target_position, hit_number, "stitched",
		half_index, run_cards.get_snapshot().receipt)
	if quote.has("seal"):
		quote.cost = preview.cost
		# Seal the real attack authority's pre-commit one-shot Scope state.
		quote.tinker_path_bonus_before = _attacks._tinker.path_bonus() if _attacks != null else 0
		quote.seal = _seal(quote)
	return quote


func quote_heavy_hit(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	if not _ready() or not _deck.hand.has(card_id):
		return {"bonus": 0}
	if card_id not in POOL_HEAVY_IDS:
		return {"bonus": 0}
	var definition: Dictionary = WardenPoolCards.new().get_definition(card_id)
	if definition.get("id") != card_id or definition.get("owner") != "warden" \
			or definition.get("target_kind") != "enemy_single":
		return {"bonus": 0}
	return _quote(definition, card_id, target_position, hit_number, "heavy", 0, "",
		cost_discount)


func quote_heavy_attack(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	return quote_heavy_hit(card_id, target_position, hit_number, cost_discount)


func quote_pool_hit(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	if card_id in POOL_HEAVY_IDS:
		return quote_heavy_hit(card_id, target_position, hit_number, cost_discount)
	if not _ready() or not _deck.hand.has(card_id):
		return {"bonus": 0}
	if card_id not in POOL_PLAIN_IDS:
		return {"bonus": 0}
	var warden_card: bool = card_id.begins_with("warden_")
	var definition: Dictionary = (WardenPoolCards.new().get_definition(card_id)
		if warden_card else SeamstressPoolCards.new().get_definition(card_id))
	var owner_id := "warden" if warden_card else "seamstress"
	if definition.get("id") != card_id or definition.get("owner") != owner_id \
			or definition.get("target_kind") != "enemy_single":
		return {"bonus": 0}
	return _quote(definition, card_id, target_position, hit_number, "pool", 0, "",
		cost_discount)


func quote_pool_strike(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	return quote_pool_hit(card_id, target_position, hit_number, cost_discount)


func quote_plain_strike(card_id: String, target_position: int, hit_number: int = 1,
		cost_discount: int = 0) -> Dictionary:
	return quote_pool_hit(card_id, target_position, hit_number, cost_discount)


## A resolver may use +2 only when the complete sealed quote still matches the
## SAME live authorities immediately before its genuine commit. No caller can
## supply a free-form damage amount or reuse a quote from an older hand.
func authorize_starter_hit(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	if deck != _deck or party != _party or enemies != _enemies or quote.get("bonus") != 2:
		return 0
	if not quote.has("seal") or quote.get("seal") != _seal(quote):
		return 0
	return 2 if quote_starter_hit(card_id, target, 1, cost_discount) == quote else 0


func authorize_stitched_half(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, run_cards: RunRestStitchCards,
		card_id: String, half_index: int, target: int) -> int:
	if deck != _deck or party != _party or enemies != _enemies or quote.get("bonus") != 2:
		return 0
	if not quote.has("seal") or quote.get("seal") != _seal(quote):
		return 0
	return 2 if quote_stitched_half(run_cards, card_id, half_index, target) == quote else 0


func authorize_heavy_hit(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	if deck != _deck or party != _party or enemies != _enemies or quote.get("bonus") != 2:
		return 0
	if not quote.has("seal") or quote.get("seal") != _seal(quote):
		return 0
	return 2 if quote_heavy_hit(card_id, target, 1, cost_discount) == quote else 0


func authorize_heavy_attack(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	return authorize_heavy_hit(quote, deck, party, enemies, card_id, target, cost_discount)


func authorize_pool_hit(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	if card_id in POOL_HEAVY_IDS:
		return authorize_heavy_hit(quote, deck, party, enemies, card_id, target, cost_discount)
	if deck != _deck or party != _party or enemies != _enemies or quote.get("bonus") != 2:
		return 0
	if not quote.has("seal") or quote.get("seal") != _seal(quote):
		return 0
	return 2 if quote_pool_hit(card_id, target, 1, cost_discount) == quote else 0


func authorize_pool_strike(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	return authorize_pool_hit(quote, deck, party, enemies, card_id, target, cost_discount)


func authorize_plain_strike(quote: Dictionary, deck: CombatDeck,
		party: CombatParty, enemies: CombatEnemies, card_id: String, target: int,
		cost_discount: int = 0) -> int:
	return authorize_pool_hit(quote, deck, party, enemies, card_id, target, cost_discount)


func consume_confirmed_hit(quote: Dictionary, receipt: Dictionary,
		run_cards: RunRestStitchCards = null) -> bool:
	# Only a real committed attack receipt + observed post-commit deck/roster
	# transition can consume a quoted entitlement. A preview has neither.
	if not is_valid() or not _turn_open or not _deck.turn_active:
		return false
	if not quote.has("seal") or quote.get("seal") != _seal(quote):
		return false
	if quote.get("generation") != _generation or quote.get("battle_id") != get_instance_id():
		return false
	var owner: Variant = quote.get("owner")
	if typeof(owner) != TYPE_STRING or _used.get(owner, false):
		return false
	if quote.get("bonus") not in [0, 2]:
		return false
	var source: String = quote.get("source", "")
	var before: Variant = quote.get("before")
	if typeof(before) != TYPE_DICTIONARY or not _transition_matches(quote, receipt, run_cards):
		return false
	if source == "stitched":
		if run_cards == null or not run_cards.is_valid():
			return false
		if run_cards.get_snapshot().receipt != quote.get("run_receipt"):
			return false
		var next_half: int = _stitched_sequence.get(quote.card_id, 0)
		# A genuine support first half cannot be quoted as an attack, but
		# its verified successful receipt advances the composite's order.
		# Never skip an attack, including an unpatched/zero-bonus attack.
		var descriptor: Dictionary = run_cards.get_snapshot().descriptors.get(quote.card_id, {})
		if next_half == 0 and quote.half_index == 1:
			var first: Dictionary = descriptor.get("first_half", {})
			if first.get("target_kind") in ["enemy_single", "enemy_all"]:
				return false
			next_half = 1
		if quote.half_index != next_half:
			return false
		next_half += 1
		if next_half == 1:
			var second: Dictionary = descriptor.get("second_half", {})
			if second.get("target_kind") not in ["enemy_single", "enemy_all"]:
				next_half = 2
		_stitched_sequence[quote.card_id] = next_half
	elif source != "starter" and source != "pool" and source != "heavy":
		return false
	# A confirmed unpatched/low-gauge first stitched half advances the ordered
	# half sequence but never spends a wearer's Frayfinder entitlement.
	if quote.bonus == 2:
		_used[owner] = true
	return true


func _quote(definition: Dictionary, card_id: String, target: int, hit_number: int,
		source: String, half_index: int, run_receipt: String,
		cost_discount: int = 0) -> Dictionary:
	if hit_number != 1 or definition.get("target_kind") != "enemy_single":
		return {"bonus": 0}
	var owner: Variant = definition.get("owner")
	var cost: Variant = definition.get("cost")
	var from_positions: Variant = definition.get("from_positions")
	var to_positions: Variant = definition.get("to_positions")
	if typeof(owner) != TYPE_STRING or typeof(cost) != TYPE_INT or cost < 0:
		return {"bonus": 0}
	if typeof(from_positions) != TYPE_ARRAY or typeof(to_positions) != TYPE_ARRAY:
		return {"bonus": 0}
	if cost_discount < 0 or cost_discount > 1 or cost_discount > cost:
		return {"bonus": 0}
	var effective_cost: int = cost - cost_discount
	if _deck.energy < effective_cost or not _deck.hand.has(card_id):
		return {"bonus": 0}
	var actor := _hero_for(owner)
	if actor.is_empty() or actor.hp <= 0 or not from_positions.has(actor.position):
		return {"bonus": 0}
	if _party.is_downed(actor.position):
		return {"bonus": 0}
	if not to_positions.is_empty() and not to_positions.has(target):
		return {"bonus": 0}
	var enemy := _enemies.get_enemy(target)
	if enemy.is_empty() or enemy.hp <= 0 or _enemies.is_slain(target):
		return {"bonus": 0}
	var gauge := _unravel.get_snapshot(target)
	if not _valid_gauge(gauge):
		return {"bonus": 0}
	var bonus := 0
	var is_worn: bool = _active.get(owner, []).has(PATCH_ID)
	var is_arm: bool = _wardrobe_state.worn.get(owner, {}).get("ARM") == PATCH_ID
	if is_worn and is_arm and not _used.get(owner, false):
		if gauge.gauge * 2 >= gauge.threshold:
			bonus = 2
	var quote := {
		"bonus": bonus, "owner": owner, "card_id": card_id,
		"source": source, "half_index": half_index, "target": target,
		"hit_number": hit_number, "cost": effective_cost,
		"generation": _generation, "battle_id": get_instance_id(),
		"run_receipt": run_receipt, "gauge_before": gauge.duplicate(true),
		"before": _battle_snapshot(),
	}
	quote["seal"] = _seal(quote)
	return quote


func _transition_matches(quote: Dictionary, receipt: Dictionary,
		run_cards: RunRestStitchCards) -> bool:
	if receipt.get("ok") != true or not quote.has("before"):
		return false
	var before: Dictionary = quote.before
	var after := _battle_snapshot()
	if quote.source == "stitched":
		return _verified_stitched_transition(quote, receipt, run_cards, before, after)
	if quote.source == "pool":
		return _verified_pool_transition(quote, receipt, before, after)
	if quote.source == "heavy":
		return _verified_heavy_transition(quote, receipt, before, after)
	if quote.source != "starter":
		return false
	if before.get("party") != after.party or before.get("rng") != after.rng:
		return false
	if before.get("draw") != after.draw:
		return false
	if before.get("energy") != after.energy + quote.cost:
		return false
	var hand: Array = before.hand.duplicate()
	if not hand.has(quote.card_id):
		return false
	hand.erase(quote.card_id)
	if hand != after.hand:
		return false
	var discard: Array = before.discard.duplicate()
	discard.append(quote.card_id)
	if discard != after.discard:
		return false
	var hits: Variant = receipt.get("hits")
	if typeof(hits) != TYPE_ARRAY or hits.size() != 1:
		return false
	if typeof(hits[0]) != TYPE_DICTIONARY or hits[0].get("position") != quote.target:
		return false
	var expected_damage := {}
	for event in hits:
		var position: Variant = event.get("position")
		if typeof(position) != TYPE_INT or position < 1 or position > before.enemies.size():
			return false
		for field in ["hp_loss", "block_absorbed", "damage"]:
			if typeof(event.get(field)) != TYPE_INT or event[field] < 0:
				return false
		if event.hp_loss + event.block_absorbed > event.damage:
			return false
		var tally: Dictionary = expected_damage.get(position, {"hp": 0, "block": 0})
		tally.hp += event.hp_loss
		tally.block += event.block_absorbed
		expected_damage[position] = tally
	for i in range(before.enemies.size()):
		var earlier: Dictionary = before.enemies[i]
		var later: Dictionary = after.enemies[i]
		if earlier.position != later.position or earlier.id != later.id:
			return false
		var tally: Dictionary = expected_damage.get(i + 1, {"hp": 0, "block": 0})
		if earlier.hp - later.hp != tally.hp or earlier.block - later.block != tally.block:
			return false
	return true


## Prove the WHOLE committed stitched receipt by replaying the two authentic
## Rest halves against detached copies of the quoted pre-commit authorities.
## Support halves have no hits: they may change HP/Block, draw/hand/discard and
## advance the shared RNG on shuffle. A damage-only tally cannot authenticate
## such a transaction. No replay object is ever the live deck or roster.
func _verified_stitched_transition(quote: Dictionary, receipt: Dictionary,
		run_cards: RunRestStitchCards, before: Dictionary, after: Dictionary) -> bool:
	if run_cards == null or not run_cards.is_valid():
		return false
	var ledger := run_cards.get_snapshot()
	if ledger.get("receipt") != quote.get("run_receipt"):
		return false
	var verified := RunRestStitchCards.new(ledger.get("deck"), ledger.get("descriptors"),
		ledger.get("remaining_scraps"), ledger.get("next_stitch_id"))
	if not verified.is_valid() or verified.get_snapshot() != ledger:
		return false
	var preview := verified.preview_play(quote.card_id, before.party)
	if not preview.get("ok", false) or preview.cost != quote.cost:
		return false
	var halves: Variant = receipt.get("halves")
	if typeof(halves) != TYPE_ARRAY or halves.size() != 2:
		return false
	for result in halves:
		if typeof(result) != TYPE_DICTIONARY or result.get("ok") != true:
			return false
	var path_bonus: Variant = quote.get("tinker_path_bonus_before", 0)
	# Only the authored zero or one-shot Scope +4 is valid.
	if typeof(path_bonus) != TYPE_INT or path_bonus not in [0, 4]:
		return false
	var selected: Dictionary = preview.halves[quote.half_index]
	if selected.get("owner") != quote.owner or selected.get("target_kind") != "enemy_single":
		return false
	var hit_events: Variant = halves[quote.half_index].get("hits")
	if typeof(hit_events) != TYPE_ARRAY or hit_events.size() != 1:
		return false
	if typeof(hit_events[0]) != TYPE_DICTIONARY or hit_events[0].get("position") != quote.target:
		return false
	var first_targets := _receipt_targets(preview.halves[0], halves[0], before)
	var second_targets := _receipt_targets(preview.halves[1], halves[1], before)
	if first_targets.is_empty() or second_targets.is_empty():
		return false
	# One sewn Button Eye can be consumed by an earlier real attack.
	var button_eye_owner := ""
	for owner in RunPatchWardrobe.HERO_IDS:
		if _wardrobe_state.worn.get(owner, {}).get("HEAD") == "button_eye":
			button_eye_owner = owner
			break
	for first_target in first_targets:
		for second_target in second_targets:
			# The ordinary resolver may run with or without independently bound
			# M04 attack and support patches. Replay both legal binding modes;
			# never infer effects from untrusted receipt fields alone.
			for attack_patches in [false, true]:
				for support_patches in [false, true]:
					# Reconstruct both legal pre-commit first-attack latch states.
					# An exact receipt AND exact post-state must still match.
					for replay_case in range(12):
						var prior_consumed: Array = [[false, false], [false, true],
							[true, false], [true, true]][replay_case % 4]
						var bonus_index := floori(float(replay_case) / 4.0) - 1
						# Exact replay with ordinary legacy damage, or with
						# one authorized +2 on either attacking half. Both
						# receipt AND resulting authorities must still match.
						var replay_bonuses := [0, 0]
						if bonus_index >= 0:
							var bonus_half: Dictionary = preview.halves[bonus_index]
							var bonus_owner: String = bonus_half.get("owner", "")
							var bonus_target: int = first_target if bonus_index == 0 else second_target
							var bonus_gauge := _unravel.get_snapshot(bonus_target)
							if bonus_half.get("target_kind") != "enemy_single" \
									or not _active.get(bonus_owner, []).has(PATCH_ID) \
									or _wardrobe_state.worn.get(bonus_owner, {}).get("ARM") != PATCH_ID \
									or not _valid_gauge(bonus_gauge) \
									or bonus_gauge.gauge * 2 < bonus_gauge.threshold:
								continue
							replay_bonuses[bonus_index] = 2
						var rng := RandomNumberGenerator.new()
						rng.state = before.rng
						var deck := CombatDeck.new([], rng)
						deck.draw_pile.assign(before.draw)
						deck.hand.assign(before.hand)
						deck.discard_pile.assign(before.discard)
						deck.combat_state.player_turn_active = true
						deck.combat_state.energy = before.energy
						var party := CombatParty.new(before.party)
						party._heroes.assign(before.party)
						var enemies := CombatEnemies.new(before.enemies)
						enemies._enemies.assign(before.enemies)
						var attacks := CombatAttackCards.new()
						attacks._tinker._consumed = prior_consumed[0]
						attacks._tinker._path_bonus = path_bonus
						if attack_patches and not attacks.bind_patch_wardrobe(_wardrobe, _torn):
							continue
						if attack_patches and not button_eye_owner.is_empty():
							attacks._patches._consumed[button_eye_owner] = prior_consumed[1]
						var resolver := CombatStitchedCards.new(attacks)
						if support_patches and not resolver.bind_patch_wardrobe(_wardrobe, _torn):
							continue
						var played := resolver._play_with_bonuses(deck, party, enemies,
							verified, quote.card_id, first_target, second_target, replay_bonuses)
						# A +2 quote must be the replayed +2, not a coincidental
						# matching transition with the Frayfinder bonus absent.
						if played != receipt or (quote.bonus == 2 \
								and replay_bonuses[quote.half_index] != 2):
							continue
						if party.get_heroes() == after.party and enemies.get_enemies() == after.enemies \
								and deck.draw_pile == after.draw and deck.hand == after.hand \
								and deck.discard_pile == after.discard and deck.energy == after.energy \
								and rng.state == after.rng:
							return true
	return false


func _verified_pool_transition(quote: Dictionary, receipt: Dictionary,
		before: Dictionary, after: Dictionary) -> bool:
	if quote.card_id not in POOL_PLAIN_IDS:
		return false
	if before.get("rng") != after.rng:
		return false
	if before.get("draw") != after.draw:
		return false
	if before.get("energy") != after.energy + quote.cost:
		return false
	var hand: Array = before.hand.duplicate()
	if not hand.has(quote.card_id):
		return false
	hand.erase(quote.card_id)
	if hand != after.hand:
		return false
	var discard: Array = before.discard.duplicate()
	discard.append(quote.card_id)
	if discard != after.discard:
		return false
	var hits: Variant = receipt.get("hits")
	if typeof(hits) != TYPE_ARRAY or hits.size() != 1:
		return false
	if typeof(hits[0]) != TYPE_DICTIONARY or hits[0].get("position") != quote.target:
		return false
	var expected_damage := {}
	for event in hits:
		var position: Variant = event.get("position")
		if typeof(position) != TYPE_INT or position < 1 or position > before.enemies.size():
			return false
		for field in ["hp_loss", "block_absorbed", "damage"]:
			if typeof(event.get(field)) != TYPE_INT or event[field] < 0:
				return false
		if event.hp_loss + event.block_absorbed > event.damage:
			return false
		var tally: Dictionary = expected_damage.get(position, {"hp": 0, "block": 0})
		tally.hp += event.hp_loss
		tally.block += event.block_absorbed
		expected_damage[position] = tally
	for i in range(before.enemies.size()):
		var earlier: Dictionary = before.enemies[i]
		var later: Dictionary = after.enemies[i]
		if earlier.position != later.position or earlier.id != later.id:
			return false
		var tally: Dictionary = expected_damage.get(i + 1, {"hp": 0, "block": 0})
		if earlier.hp - later.hp != tally.hp or earlier.block - later.block != tally.block:
			return false
	var earlier_party: Array = before.party
	var later_party: Array = after.party
	if earlier_party.size() != later_party.size():
		return false
	var is_warden: bool = quote.card_id.begins_with("warden_")
	var block_deltas: Variant = receipt.get("block_deltas")
	if typeof(block_deltas) != TYPE_DICTIONARY:
		return false
	var owner_found := false
	for i in range(earlier_party.size()):
		var ep: Dictionary = earlier_party[i]
		var lp: Dictionary = later_party[i]
		if ep.get("id") != lp.get("id") or ep.get("position") != lp.get("position"):
			return false
		if ep.get("hp") != lp.get("hp") or ep.get("max_hp") != lp.get("max_hp") \
				or ep.get("statuses", {}) != lp.get("statuses", {}):
			return false
		var ep_block: int = ep.get("block", 0)
		var lp_block: int = lp.get("block", 0)
		if ep.get("id") == quote.owner:
			owner_found = true
			if not is_warden:
				if ep_block != lp_block:
					return false
			else:
				var min_gain: int = 4 if quote.card_id == "warden_brass_buckle" else 6
				var max_gain: int = min_gain
				if _active.get("warden", []).has("hemguard_cuff"):
					max_gain += 2
				if _active.get("warden", []).has("reinforced_browband"):
					max_gain += 2
				if block_deltas.size() != 1 or not block_deltas.has(ep.get("position")):
					return false
				var gain: Variant = block_deltas[ep.get("position")]
				if typeof(gain) != TYPE_INT or gain < min_gain or gain > max_gain:
					return false
				if (gain - min_gain) % 2 != 0:
					return false
				if lp_block != ep_block + gain:
					return false
		else:
			if ep_block != lp_block:
				return false
	if not owner_found:
		return false
	if not is_warden and not block_deltas.is_empty():
		return false
	return true


func _verified_heavy_transition(quote: Dictionary, receipt: Dictionary,
		before: Dictionary, after: Dictionary) -> bool:
	if quote.card_id not in POOL_HEAVY_IDS:
		return false
	if receipt.get("card_id") != quote.card_id or receipt.get("target_position") != quote.target:
		return false
	if before.get("rng") != after.rng:
		return false
	if before.get("draw") != after.draw:
		return false
	if before.get("energy") != after.energy + quote.cost:
		return false
	var hand: Array = before.hand.duplicate()
	if not hand.has(quote.card_id):
		return false
	hand.erase(quote.card_id)
	if hand != after.hand:
		return false
	var discard: Array = before.discard.duplicate()
	discard.append(quote.card_id)
	if discard != after.discard:
		return false

	var earlier_party: Array = before.party
	var later_party: Array = after.party
	if earlier_party != later_party:
		return false

	var hits: Variant = receipt.get("hits")
	if typeof(hits) != TYPE_ARRAY or hits.is_empty():
		return false

	var is_single_hit: bool = (quote.card_id == "warden_heavy_thimble" or quote.card_id == "warden_heavy_thimble_plus")
	if is_single_hit and hits.size() != 1:
		return false
	if not is_single_hit and hits.size() not in [1, 2]:
		return false

	var earlier_enemies: Array = before.enemies
	var later_enemies: Array = after.enemies
	if earlier_enemies.size() != later_enemies.size() or quote.target < 1 or quote.target > earlier_enemies.size():
		return false

	var earlier_target: Dictionary = earlier_enemies[quote.target - 1]
	var later_target: Dictionary = later_enemies[quote.target - 1]
	if earlier_target.get("id") != later_target.get("id") or earlier_target.get("position") != later_target.get("position"):
		return false

	var total_hp_loss := 0
	var total_block_absorbed := 0
	for hit in hits:
		if typeof(hit) != TYPE_DICTIONARY or hit.get("position") != quote.target:
			return false
		for field in ["hp_loss", "block_absorbed", "damage"]:
			if typeof(hit.get(field)) != TYPE_INT or hit[field] < 0:
				return false
		if hit.hp_loss + hit.block_absorbed > hit.damage:
			return false
		total_hp_loss += hit.hp_loss
		total_block_absorbed += hit.block_absorbed

	var earlier_hp: int = int(earlier_target.get("hp", 0))
	var later_hp: int = int(later_target.get("hp", 0))
	var earlier_block: int = int(earlier_target.get("block", 0))
	var later_block: int = int(later_target.get("block", 0))

	if earlier_hp - later_hp != total_hp_loss:
		return false
	if earlier_block - later_block != total_block_absorbed:
		return false

	if not is_single_hit:
		if hits.size() == 1:
			if hits[0].hp_loss < earlier_hp or later_hp > 0:
				return false
		else:
			if hits[0].hp_loss >= earlier_hp:
				return false

	for i in range(earlier_enemies.size()):
		if i + 1 == quote.target:
			continue
		var ee: Dictionary = earlier_enemies[i]
		var le: Dictionary = later_enemies[i]
		if ee.get("id") != le.get("id") or ee.get("position") != le.get("position"):
			return false
		if ee.get("hp") != le.get("hp") or ee.get("block") != le.get("block") or ee.get("statuses", {}) != le.get("statuses", {}):
			return false

	var definition: Dictionary = WardenPoolCards.new().get_definition(quote.card_id)
	var base_damage: int = int(definition.get("effects", {}).get("damage", 0))

	var warden_hero: Dictionary = {}
	for hero in before.party:
		if hero.get("id") == "warden":
			warden_hero = hero
			break
	if warden_hero.is_empty():
		return false
	var warden_statuses: Dictionary = warden_hero.get("statuses", {})
	var foe_statuses: Dictionary = earlier_target.get("statuses", {})

	var patch_damage: int = 1 if _active.get("warden", []).has("pincushion_arm") else 0

	var hit0_mitt_bonus: int = quote.bonus
	var hit0_pin_bonus: int = int(hits[0].get("pinned_bonus", 0))
	if hit0_pin_bonus not in [0, 5]:
		return false
	var expected_hit0_damage: int = CombatStatuses.new().adjusted_attack_damage(
		base_damage + hit0_pin_bonus + patch_damage + hit0_mitt_bonus, warden_statuses, foe_statuses)
	if hits[0].damage != expected_hit0_damage:
		return false

	if hits.size() > 1:
		var hit1_pin_bonus: int = int(hits[1].get("pinned_bonus", 0))
		if hit1_pin_bonus != 0:
			return false
		var expected_hit1_damage: int = CombatStatuses.new().adjusted_attack_damage(
			base_damage + patch_damage, warden_statuses, foe_statuses)
		if hits[1].damage != expected_hit1_damage:
			return false

	var earlier_statuses: Dictionary = earlier_target.get("statuses", {})
	var later_statuses: Dictionary = later_target.get("statuses", {})
	if earlier_statuses.get("weak", 0) != later_statuses.get("weak", 0) \
			or earlier_statuses.get("bleed", 0) != later_statuses.get("bleed", 0):
		return false
	var exp_delta: int = int(later_statuses.get("exposed", 0)) - int(earlier_statuses.get("exposed", 0))
	if exp_delta not in [0, 1]:
		return false
	var hit0_statuses: Dictionary = hits[0].get("statuses", {})
	if int(hit0_statuses.get("exposed", 0)) != exp_delta:
		return false

	return true


## Authoritative descriptor restricts the target shape. Receipts only narrow
## enemy hit positions; support recipients are tried against the real resolver,
## which checks owner, live HP, authored positions and all effects.
func _receipt_targets(half: Dictionary, outcome: Dictionary, before: Dictionary) -> Array[int]:
	var targets: Array[int] = []
	var kind: String = half.get("target_kind", "")
	if kind == "enemy_single":
		var events: Variant = outcome.get("hits")
		if typeof(events) != TYPE_ARRAY or events.size() != 1:
			return targets
		if typeof(events[0]) != TYPE_DICTIONARY:
			return targets
		var position: Variant = events[0].get("position")
		if typeof(position) == TYPE_INT and position >= 1 and position <= before.enemies.size():
			targets.append(position)
	elif kind == "ally_single":
		var allowed: Array = half.get("to_positions", [])
		for hero in before.party:
			if hero.hp > 0 and (allowed.is_empty() or allowed.has(hero.position)):
				targets.append(hero.position)
	elif kind in ["self", "none", "enemy_all", "party_all"]:
		targets.append(0)
	return targets

func _battle_snapshot() -> Dictionary:
	return {"party": _party.get_heroes(), "enemies": _enemies.get_enemies(),
		"draw": _deck.draw_pile.duplicate(), "hand": _deck.hand.duplicate(),
		"discard": _deck.discard_pile.duplicate(), "energy": _deck.energy,
		"rng": _deck._rng.state}


func _hero_for(id: String) -> Dictionary:
	for actor in _party.get_heroes():
		if actor.id == id:
			return actor
	return {}


func _ready() -> bool:
	return is_valid() and _turn_open and _deck.turn_active


func _seal(quote: Dictionary) -> String:
	var unsigned := quote.duplicate(true)
	unsigned.erase("seal")
	return JSON.stringify(unsigned).sha256_text()


func _valid_gauge(gauge: Dictionary) -> bool:
	return gauge.size() == 4 and typeof(gauge.get("gauge")) == TYPE_INT \
		and typeof(gauge.get("threshold")) == TYPE_INT \
		and typeof(gauge.get("unravelled")) == TYPE_BOOL \
		and typeof(gauge.get("skip_pending")) == TYPE_BOOL \
		and gauge.threshold >= 8 and gauge.gauge >= 0 and gauge.gauge <= gauge.threshold


func _valid_catalog(raw: Variant) -> bool:
	if typeof(raw) != TYPE_ARRAY:
		return false
	var found := 0
	for record in raw:
		if typeof(record) != TYPE_DICTIONARY:
			return false
		if record.get("id") != PATCH_ID:
			continue
		found += 1
		if record.size() != 9 or record.get("slot") != "ARM" or record.get("effect") != EFFECT:
			return false
		for field in ["amount", "minimum_unravel_numerator",
				"minimum_unravel_denominator", "hit_number"]:
			if typeof(record.get(field)) not in [TYPE_INT, TYPE_FLOAT]:
				return false
		if record.amount != 2 or record.minimum_unravel_numerator != 1 \
				or record.minimum_unravel_denominator != 2 or record.hit_number != 1:
			return false
		if record.get("once_per_player_turn") != true or record.get("target_kind") != "enemy_single":
			return false
	return found == 1


func _valid_projection(state: Dictionary, torn_state: Dictionary, projection: Dictionary) -> bool:
	if state.get("valid") != true or torn_state.get("ok") != true or projection.get("ok") != true:
		return false
	if state.get("worn") != projection.get("worn"):
		return false
	var defs: Variant = state.get("definitions")
	var owned: Variant = state.get("owned")
	var worn: Variant = state.get("worn")
	var active: Variant = projection.get("active")
	var heroes: Variant = torn_state.get("heroes")
	if typeof(defs) != TYPE_DICTIONARY or typeof(owned) != TYPE_ARRAY:
		return false
	if typeof(worn) != TYPE_DICTIONARY or typeof(active) != TYPE_DICTIONARY:
		return false
	if typeof(heroes) != TYPE_ARRAY or heroes.size() != 3:
		return false
	if defs.get(PATCH_ID) != "ARM" and owned.has(PATCH_ID):
		return false
	if worn.size() != 3 or active.size() != 3:
		return false
	for index in range(3):
		var owner: String = RunPatchWardrobe.HERO_IDS[index]
		var hero: Dictionary = heroes[index]
		if hero.get("id") != owner or hero.get("position") != index + 1:
			return false
		var slots: Variant = worn.get(owner)
		if typeof(slots) != TYPE_DICTIONARY or slots.size() != 3:
			return false
		var wanted := []
		for slot in RunPatchWardrobe.SLOTS:
			var patch: Variant = slots.get(slot)
			if typeof(patch) != TYPE_STRING:
				return false
			if patch != "":
				if not owned.has(patch) or defs.get(patch) != slot:
					return false
				if hero.hp > 0:
					wanted.append(patch)
		if active.get(owner) != wanted:
			return false
	return true
