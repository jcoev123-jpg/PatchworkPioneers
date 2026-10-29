class_name CombatStitchedCards
extends RefCounted
## Scene-free atomic Rest composite. Supply the run-owned Rest service, never
## caller-authored half dictionaries. Share attacks with ordinary card plays so
## Tinker's turn latch and wearer-only patch latches have one combat authority.

## The only two canonical halves carrying Spare Parts' printed Block + one draw.
const SPARE_PARTS_IDS: Array[String] = ["tinker_spare_parts", "tinker_spare_parts_plus"]

var _attacks: CombatAttackCards
var _support := CombatSupportCards.new()
var _pool := SeamstressPoolCards.new()
var _tinker_pool := TinkerPoolCards.new()
var _energy := CombatPoolEnergyCards.new()
## Reuse the ordinary healing service's combat-scoped COAT notifier and latch.
## The live hand owner will supply this same instance at its commit boundary.
var _button_heals: CombatSeamstressPoolHeals = null


func _init(attacks: CombatAttackCards = null) -> void:
	_attacks = attacks if attacks != null else CombatAttackCards.new()


func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	return _support.bind_patch_wardrobe(wardrobe, torn, expected_wardrobe, expected_torn)


## Optional P6 integration: the very same battle-bound healing service must
## handle ordinary cards as well as stitched commits, so neither path can refill
## the once-per-combat latch or generate colliding receipt sequences.
func bind_borrowed_button(heals: CombatSeamstressPoolHeals) -> void:
	_button_heals = heals


## The optional Frayfinder service authenticates its own half quotes against
## the real deck/party/roster before the atomic staged transaction starts.
func play_stitched(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		run_cards: RunRestStitchCards, stitched_id: String,
		first_target: int = 0, second_target: int = 0,
		mitt: CombatFrayfinderMitt = null) -> Dictionary:
	var bonuses := [0, 0]
	var quotes := [{}, {}]
	if mitt != null:
		# The sealed Scope state must belong to the actual staged resolver.
		if mitt._attacks != null and mitt._attacks != _attacks:
			return {"ok": false, "halves": []}
		if deck == null or party == null or enemies == null or run_cards == null:
			return {"ok": false, "halves": []}
		var preview := run_cards.preview_play(stitched_id, party.get_heroes())
		if not preview.get("ok", false) or not deck.hand.has(stitched_id):
			return {"ok": false, "halves": []}
		for index in range(2):
			if preview.halves[index].get("target_kind") != "enemy_single":
				continue
			var target: int = first_target if index == 0 else second_target
			var quote := mitt.quote_stitched_half(run_cards, stitched_id, index, target)
			if quote.get("bonus") == 2:
				if mitt.authorize_stitched_half(quote, deck, party, enemies,
						run_cards, stitched_id, index, target) != 2:
					return {"ok": false, "halves": []}
				bonuses[index] = 2
			quotes[index] = quote
	var receipt := _play_with_bonuses(deck, party, enemies, run_cards,
		stitched_id, first_target, second_target, bonuses)
	if receipt.get("ok", false) and mitt != null:
		for quote in quotes:
			if quote.has("seal"):
				mitt.consume_confirmed_hit(quote, receipt, run_cards)
	return receipt


## Replay seam also runs ONLY on detached authorities during receipt verification.
## Public play_stitched never takes a caller-supplied numerical bonus.
func _play_with_bonuses(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		run_cards: RunRestStitchCards, stitched_id: String,
		first_target: int, second_target: int, bonuses: Array) -> Dictionary:
	var failure := {"ok": false, "halves": []}
	if bonuses.size() != 2 or bonuses[0] not in [0, 2] or bonuses[1] not in [0, 2]:
		return failure
	if deck == null or party == null or enemies == null or run_cards == null:
		return failure
	if not _support.is_patch_binding_valid():
		return failure
	if not deck.turn_active or not deck.hand.has(stitched_id):
		return failure
	if not party.is_valid() or not enemies.is_valid() or enemies.is_victorious():
		return failure
	var preview := run_cards.preview_play(stitched_id, party.get_heroes())
	if not preview.ok or deck.energy < preview.cost:
		return failure
	# Reauthenticate the full Rest descriptor, including its capped cost, before
	# executing a half. is_valid() alone does not detect in-memory tampering.
	var ledger := run_cards.get_snapshot()
	var verified := RunRestStitchCards.new(ledger.deck, ledger.descriptors,
		ledger.remaining_scraps, ledger.next_stitch_id)
	if not verified.is_valid() or verified.get_snapshot() != ledger:
		return failure
	if not CombatStatusTurnBatch.new().tick_side("heroes", party.get_heroes()).ok:
		return failure
	if not enemies.can_apply_statuses({}):
		return failure

	# Construction with empty piles never draws RNG. Preserve the injected run
	# generator itself on publish; only its staged state advances on success.
	var rng := RandomNumberGenerator.new()
	rng.state = deck._rng.state
	var staged_deck := CombatDeck.new([], rng)
	staged_deck.draw_pile.assign(deck.draw_pile)
	staged_deck.hand.assign(deck.hand)
	staged_deck.discard_pile.assign(deck.discard_pile)
	staged_deck.combat_state.player_turn_active = true
	staged_deck.combat_state.energy = deck.energy
	var staged_party := CombatParty.new(party.get_heroes())
	staged_party._heroes = party.get_heroes()
	var staged_enemies := CombatEnemies.new(enemies.get_enemies())
	staged_enemies._enemies = enemies.get_enemies()
	var attacks := _attacks.stage_transaction()
	# Pool direct-fire halves read and spend the very same staged latches.
	var direct_fire := CombatTinkerPoolAttacks.stage_for_stitch(attacks)
	var plain_strikes := CombatPoolPlainStrikes.stage_for_stitch(attacks)
	var results: Array[Dictionary] = []
	var committed_heals: Array[Dictionary] = []
	var targets := [first_target, second_target]
	for index in range(2):
		var half: Dictionary = preview.halves[index]
		var target: int = targets[index]
		var kind: String = half.target_kind
		# Real per-half pre/post snapshots; discarded on any staged failure.
		var hp_before: Array = staged_party.get_heroes() if half.effects.has("heal") else []
		if kind in ["self", "none", "enemy_all", "party_all"] and target != 0:
			return failure
		if kind in ["enemy_single", "ally_single"] and not half.to_positions.is_empty() and not half.to_positions.has(target):
			return failure
		if half.id in CombatTinkerPoolAttacks.STITCHED_IDS \
				or half.id in CombatTinkerPoolAttacks.STITCHED_AREA_IDS:
			# Authenticate both target shapes against canonical Tinker printings.
			# The pool resolver owns per-living-slot hits and the shared latches.
			var expected_kind := "enemy_all" if half.id in CombatTinkerPoolAttacks.STITCHED_AREA_IDS else "enemy_single"
			if half != _tinker_pool.get_definition(half.id) or kind != expected_kind:
				return failure
			var pool_attack := direct_fire.resolve_staged_half(staged_party,
				staged_enemies, half.id, target, bonuses[index])
			if not pool_attack.get("ok", false):
				return failure
			results.append(pool_attack)
		elif half.id in CombatPoolPlainStrikes.SUPPORTED_IDS:
			var strike := plain_strikes.resolve_staged_half(staged_party,
				staged_enemies, half, target, bonuses[index])
			if not strike.get("ok", false):
				return failure
			results.append(strike)
		elif half.id in CombatTinkerPoolGadgets.SIGHT_GLASS_IDS:
			# Sight Glass is a nonattack: no Scope/latch bonus applies and the
			# generic attack resolver would reject its Exposed + draw outright.
			if bonuses[index] != 0:
				return failure
			var sight := CombatTinkerPoolGadgets.resolve_staged_sight_glass(staged_deck,
				staged_party, staged_enemies, half, target, _support._head_patches, _support._torn)
			if not sight.get("ok", false):
				return failure
			results.append(sight)
		elif kind in ["enemy_single", "enemy_all"]:
			var result := attacks.resolve_staged_half(staged_party, staged_enemies,
				half.id, target, bonuses[index])
			if not result.ok:
				return failure
			results.append(result)
		elif half.id in CombatStitchedTargetPreview.POOL_HEAL_IDS:
			var pool_result := _resolve_pool_heal_half(staged_party, half, target)
			if not pool_result.ok:
				return failure
			results.append(pool_result)
		elif half.id in CombatStitchedTargetPreview.WARDEN_BLOCK_IDS:
			var warden := CombatWardenPoolBlockCards.new()
			if _support._wardrobe != null and not warden.bind_patch_wardrobe(
					_support._wardrobe, _support._torn,
					_support._wardrobe_snapshot, _support._torn_snapshot):
				return failure
			var block_result := warden.resolve_staged_half(staged_deck, staged_party, half, target)
			if not block_result.get("ok", false):
				return failure
			results.append(block_result)
		elif _energy.is_supported_card(half.id):
			# Overclock and Tailor's Trance carry printed energy/draw/self-damage
			# effects the generic draw/Block fallback would silently drop. The
			# staged half neither holds, charges nor discards; the enclosing
			# transaction owns the one capped cost and the single discard.
			var energy_result := _energy.resolve_staged_half(
				staged_deck, staged_party, half.id, target)
			if not energy_result.get("ok", false):
				return failure
			results.append(energy_result)
		elif half.id in CombatYarnRangerKnitCards.CARDS:
			var knit_result := _resolve_knit_half(staged_deck, staged_party, half, target)
			if not knit_result.get("ok", false):
				return failure
			results.append(knit_result)
		elif half.id in SPARE_PARTS_IDS:
			# Spare Parts prints Block AND a draw; the generic single-effect
			# fallback would keep only the Block. Authenticate the canonical
			# base/+ record itself, never a caller-supplied effect dictionary.
			var spare_result := _resolve_spare_parts_half(staged_deck, staged_party, half)
			if not spare_result.get("ok", false):
				return failure
			results.append(spare_result)
		else:
			# Only these exact, single-effect support forms are implemented by
			# CombatSupportCards. In particular enemy_random (Ricochet) and
			# multi-effect halves must not masquerade as a zero-card draw.
			var effects: Dictionary = half.effects
			if effects.size() != 1:
				return failure
			var effect := ""
			var amount: Variant = null
			match kind:
				"none":
					if not effects.has("draw"):
						return failure
					effect = "draw"
					amount = effects.draw
				"self":
					if not effects.has("block"):
						return failure
					effect = "self_block"
					amount = effects.block
				"ally_single":
					if effects.has("block"):
						effect = "ally_block"
						amount = effects.block
					elif effects.has("heal"):
						effect = "ally_heal"
						amount = effects.heal
					else:
						return failure
				_:
					return failure
			if typeof(amount) != TYPE_INT or amount < 0:
				return failure
			var normalized := {"id": stitched_id, "owner_id": half.owner,
				"cost": 0, "from_positions": half.from_positions,
				"effect": effect, "amount": amount}
			if not _support.resolve_staged_half(staged_deck, staged_party, normalized, target, half.id):
				return failure
			results.append({"ok": true, "effect": effect, "amount": amount})
		if not hp_before.is_empty():
			var hp_after: Array = staged_party.get_heroes()
			var observations: Array[Dictionary] = []
			for seat in range(CombatParty.PARTY_SIZE):
				if hp_after[seat]["hp"] > hp_before[seat]["hp"]:
					observations.append({"position": seat + 1, "id": hp_after[seat]["id"],
						"before": hp_before[seat]["hp"], "after": hp_after[seat]["hp"]})
			# Keep every genuine healing half's own owner and ordered recipients.
			# Zero-restoration halves are not eligible for P6 receipts.
			if not observations.is_empty():
				committed_heals.append({"owner": half.owner, "index": index,
					"observations": observations})
	staged_deck.try_spend_energy(preview.cost)
	staged_deck.discard_played(stitched_id)
	party._heroes = staged_party.get_heroes()
	enemies._enemies = staged_enemies.get_enemies()
	deck.draw_pile.assign(staged_deck.draw_pile)
	deck.hand.assign(staged_deck.hand)
	deck.discard_pile.assign(staged_deck.discard_pile)
	deck.combat_state.energy = staged_deck.energy
	deck._rng.state = rng.state
	_attacks.commit_transaction(attacks)
	# No notification is possible until both ordered halves, the one charge,
	# discard and all authoritative roster/RNG publication have succeeded.
	if _button_heals != null and _button_heals._borrowed_button != null \
			and _button_heals.is_patch_binding_valid() \
			and _button_heals._wardrobe == _support._wardrobe \
			and _button_heals._torn == _support._torn \
			and (_button_heals._button_party in [null, party] or _button_heals._pending_new_party):
		for healed_half in committed_heals:
			_button_heals._notify_borrowed_button(party, healed_half.owner,
				healed_half.observations, "stitched_half_%d" % healed_half.index)
	return {"ok": true, "halves": results}


## Knit halves retain both printed effects without a separate payment or discard.
## The enclosing transaction keeps the composite held until all draws finish.
func _resolve_knit_half(deck: CombatDeck, party: CombatParty,
		half: Dictionary, target: int) -> Dictionary:
	var authored := CombatYarnRangerKnitCards.knit_definition(half.get("id"))
	if authored.is_empty() or authored != half:
		return {"ok": false}
	var owner_position := 0
	for hero in party.get_heroes():
		if hero.id == authored.owner:
			owner_position = hero.position
	if owner_position == 0 or party.is_downed(owner_position) \
			or not authored.from_positions.has(owner_position):
		return {"ok": false}
	if _support._torn != null:
		for hero in _support._torn.read_state().get("heroes", []):
			if hero.get("id") == authored.owner and int(hero.get("hp", 0)) <= 0:
				return {"ok": false}
	if target < 1 or target > CombatParty.PARTY_SIZE or party.is_downed(target):
		return {"ok": false}
	var block: int = authored.effects.block
	if block > CombatParty.MAX_INT - int(party.get_hero(target).block) \
			or not party.gain_block(target, block):
		return {"ok": false}
	var drawn := deck.draw_extra(1)
	if drawn < 0:
		return {"ok": false}
	return {"ok": true, "effect": "block_and_draw", "amount": block,
		"draw": 1, "drawn": drawn}


## Stage exactly the six authorized authored pool heals, including Darning's
## inseparable heal + Block and target-free Field Mend. A failed second half
## discards the entire staged party without publishing even the first heal.
func _resolve_pool_heal_half(party: CombatParty, half: Dictionary, target: int) -> Dictionary:
	var failed := {"ok": false}
	var card_id: String = half["id"]
	if card_id not in CombatStitchedTargetPreview.POOL_HEAL_IDS:
		return failed
	var authored: Dictionary = _pool.get_definition(card_id)
	if authored.is_empty() or authored != half or authored.get("owner") != "seamstress":
		return failed
	var darning := card_id in CombatSeamstressPoolHeals.DARNING_IDS
	var field_mend := card_id in CombatSeamstressPoolHeals.FIELD_MEND_IDS
	var effects: Dictionary = authored["effects"]
	var heal: Variant = effects.get("heal")
	var block: Variant = effects.get("block", 0)
	if typeof(heal) != TYPE_INT or heal <= 0 or typeof(block) != TYPE_INT or block < 0:
		return failed
	if darning:
		if block <= 0 or effects.size() != 2:
			return failed
	elif effects.size() != 1 or block != 0:
		return failed
	if authored["target_kind"] != ("party_all" if field_mend else "ally_single"):
		return failed
	if not authored["to_positions"].is_empty():
		return failed
	var owner_position := 0
	for hero in party.get_heroes():
		if hero["id"] == "seamstress":
			owner_position = hero["position"]
			break
	if owner_position == 0:
		return failed
	if party.is_downed(owner_position) or not authored["from_positions"].has(owner_position):
		return failed
	if _support._torn != null:
		for hero in _support._torn.read_state().get("heroes", []):
			if typeof(hero) == TYPE_DICTIONARY and hero.get("id") == "seamstress" and int(hero.get("hp", 0)) <= 0:
				return failed

	var recipients: Array[int] = []
	if field_mend:
		if target != 0:
			return failed
		for position in range(1, CombatParty.PARTY_SIZE + 1):
			if not party.is_downed(position):
				recipients.append(position)
	else:
		if target < 1 or target > CombatParty.PARTY_SIZE or party.is_downed(target):
			return failed
		recipients.append(target)
	if recipients.is_empty():
		return failed

	var applied_block: int = block
	if darning:
		if _support._head_patches != null:
			applied_block += _support._head_patches.get_bonus(authored["owner"], card_id, "block")
		if _support._arm_patches != null:
			applied_block += _support._arm_patches.card_block_bonus(authored["owner"], card_id)
		var existing: int = party.get_hero(target)["block"]
		if applied_block > CombatParty.MAX_INT - existing:
			return failed

	var applied_heal: int = heal
	if _support._patches != null:
		applied_heal += _support._patches.healing_card_bonus("seamstress", card_id)
	for position in recipients:
		party.heal(position, applied_heal)
	if darning:
		party.gain_block(target, applied_block)
	return {"ok": true, "effect": "ally_heal" if not field_mend else "party_heal",
		"amount": applied_heal, "block": applied_block, "affected_positions": recipients}


## Stage exactly the two canonical Spare Parts halves: their authored Block goes
## to the living Tinker in her CURRENT slot (plus only her own worn ARM/HEAD
## Block patch), then exactly one card is drawn with the staged seeded deck.
## The half is re-authenticated against the real Tinker catalog, so an inflated
## or otherwise forged effect record can never publish a larger Block or draw.
## The enclosing transaction still owns the one capped cost and single discard.
func _resolve_spare_parts_half(deck: CombatDeck, party: CombatParty,
		half: Dictionary) -> Dictionary:
	var failed := {"ok": false}
	if deck == null or party == null:
		return failed
	var id_value: Variant = half.get("id")
	if typeof(id_value) != TYPE_STRING or not id_value in SPARE_PARTS_IDS:
		return failed
	var card_id: String = id_value
	var authored: Dictionary = _tinker_pool.get_definition(card_id)
	if authored.is_empty() or authored != half or authored.get("owner") != "tinker":
		return failed
	if authored["cost"] != 0 or authored["target_kind"] != "self" \
			or not authored["to_positions"].is_empty():
		return failed
	var effects: Dictionary = authored["effects"]
	var printed_block: Variant = effects.get("block")
	var draw: Variant = effects.get("draw")
	if typeof(printed_block) != TYPE_INT or typeof(draw) != TYPE_INT \
			or effects.size() != 2 or draw != 1:
		return failed
	if printed_block != (4 if card_id.ends_with("_plus") else 3):
		return failed
	var owner_position := 0
	for hero in party.get_heroes():
		if hero["id"] == "tinker":
			owner_position = hero["position"]
			break
	if owner_position == 0 or party.is_downed(owner_position) \
			or not authored["from_positions"].has(owner_position):
		return failed
	# The battle party can still live while the run ledger marks Tinker torn.
	if _support._torn != null:
		for hero in _support._torn.read_state().get("heroes", []):
			if typeof(hero) == TYPE_DICTIONARY and hero.get("id") == "tinker" \
					and int(hero.get("hp", 0)) <= 0:
				return failed

	# Only Tinker's own worn ARM/HEAD Block patches touch her own half.
	var granted_block: int = printed_block
	if _support._arm_patches != null:
		granted_block += _support._arm_patches.card_block_bonus("tinker", card_id)
	if _support._head_patches != null:
		granted_block += _support._head_patches.get_bonus("tinker", card_id, "block")
	var current_block: int = party.get_hero(owner_position)["block"]
	if granted_block < printed_block or granted_block > CombatParty.MAX_INT - current_block:
		return failed
	if not party.gain_block(owner_position, granted_block):
		return failed
	# The composite itself is still held, so this draw can never reshuffle the
	# just-played copy; an exhausted supply legally draws zero, never a stand-in.
	var drawn: int = deck.draw_extra(int(draw))
	if drawn < 0:
		return failed
	return {"ok": true, "effect": "block_and_draw", "amount": granted_block,
		"draw": draw, "drawn": drawn}
