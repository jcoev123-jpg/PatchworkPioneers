class_name M05SeededRunStrategy
extends RefCounted
## Deterministic decisions over detached, authoritative run/combat snapshots.
## Never spends, damages, draws RNG, or changes a live ledger.

const STARTER_ATTACKS := [
	"warden_strike", "warden_strike_plus", "warden_shield_bash",
	"seamstress_prick", "tinker_pop_shot", "tinker_scrap_bomb"
]
const EFFECTIVE_PATCH_EXCLUSIONS := ["stitched_badge", "spare_spool"]
const EARNED_POOL_ATTACKS := [
	"warden_brass_buckle", "warden_brass_buckle_plus",
	"seamstress_thread_whip", "seamstress_thread_whip_plus",
	"warden_heavy_thimble", "warden_heavy_thimble_plus",
	"warden_pin_and_pound", "warden_pin_and_pound_plus",
]
const EARNED_POOL_BLOCKS := [
	"warden_hold_the_line", "warden_patch_guard", "warden_quick_darn",
	"warden_iron_hem", "warden_bastion_quilt",
]


func choose_route(map: RunMap, heroes: Array, scraps: int, stitched: int,
		fights: int, elites: int, gold: int, card_candidates: Array) -> String:
	var legal := map.get_legal_choices()
	var purchase_plausible := card_candidates.any(func(offer): return offer.price <= gold)
	var best := ""
	var best_score := -100000
	var need_stitch := stitched == 0 and scraps >= RunRestStitchCards.SCRAP_COST
	var wounded := false
	for hero in heroes:
		if hero.hp == 0 or hero.hp * 2 < hero.max_hp:
			wounded = true
	for id in legal:
		var node := map.get_node(id)
		var kind: String = node.type
		var score := 0
		match kind:
			"Boss":
				score = 200
			"Fight":
				score = 95 if scraps < 3 and fights < 2 else 23
			"Elite":
				score = 112 if scraps < 3 and elites == 0 else 15
			"Rest":
				score = 155 if need_stitch else (100 if wounded else 44)
			"Shop":
				score = 80 if purchase_plausible else 46
			"Event":
				score = 72
			"Treasure":
				score = 54
		# Prefer a legal next-floor Rest once a real reward can fund stitching.
		if scraps >= 3 and stitched == 0 and kind != "Rest":
			for next_id in node.outgoing:
				if map.get_node(next_id).type == "Rest":
					score += 12
					break
		if score > best_score or (score == best_score and (best.is_empty() or id < best)):
			best = id
			best_score = score
	return best


func choose_shop_card(stock: Dictionary, gold: int) -> String:
	# Buy the cheapest unsold card; canonical ID breaks equal-price ties.
	var best := ""
	var price := gold + 1
	for offer in stock.cards:
		if offer.sold or offer.price > gold:
			continue
		if offer.price < price or (offer.price == price and (best.is_empty() or offer.id < best)):
			best = offer.id
			price = offer.price
	return best


func choose_event_choice(forecast: Dictionary) -> String:
	# Value thread for stitching, with canonical choice ID breaking ties.
	var best := ""
	var best_score := -100000
	for choice in forecast.get("choices", []):
		if not choice.affordable:
			continue
		var score: int = choice.gold_delta + 12 * choice.scraps_delta
		if score > best_score or (score == best_score and (best.is_empty() or choice.choice_id < best)):
			best = choice.choice_id
			best_score = score
	return best


func choose_reward(offers: Array, seed_value: int, previous_picks: int) -> String:
	if offers.is_empty() or seed_value % 3 != 0 or previous_picks != 0:
		return "" # Real Skip is an authored choice, not an invented award.
	for offer in offers:
		var id := str(offer.get("id", ""))
		var definition := _pool_definition(id)
		if definition.get("reward_eligible", false) and (
				EARNED_POOL_ATTACKS.has(id) or EARNED_POOL_BLOCKS.has(id)):
			return str(offer.id)
	return "" # Unsupported earned shapes stay unselected in this bounded cohort.


func choose_stitch(deck_ids: Array, heroes: Array, scraps: int) -> Dictionary:
	if scraps < RunRestStitchCards.SCRAP_COST:
		return {}
	var preferred := ["seamstress_prick", "tinker_pop_shot"]
	for i in range(deck_ids.size()):
		var a := RunRestStitchCards.resolve_card_definition(deck_ids[i])
		if a.is_empty() or not _living_owner_in_from(heroes, a):
			continue
		for j in range(i + 1, deck_ids.size()):
			var b := RunRestStitchCards.resolve_card_definition(deck_ids[j])
			if b.is_empty() or a.owner == b.owner or not _living_owner_in_from(heroes, b):
				continue
			if deck_ids[i] == preferred[0] and deck_ids[j] == preferred[1]:
				return {"first": i, "second": j}
			# Only starter attack halves have a fully wired scene-free resolver
			# in this baseline; other legitimate Rest choices remain available.
			if STARTER_ATTACKS.has(deck_ids[i]) and STARTER_ATTACKS.has(deck_ids[j]):
				return {"first": i, "second": j}
	return {}


func choose_sew(wardrobe: RunPatchWardrobe, heroes: Array) -> Dictionary:
	var snapshot := wardrobe.get_snapshot()
	for patch_id in snapshot.owned:
		if patch_id in EFFECTIVE_PATCH_EXCLUSIONS:
			continue
		var slot: String = snapshot.definitions.get(patch_id, "")
		if not slot in RunPatchWardrobe.SLOTS:
			continue
		var already_worn := false
		for wearer_id in RunPatchWardrobe.HERO_IDS:
			if snapshot.worn[wearer_id][slot] == patch_id:
				already_worn = true
				break
		if already_worn:
			continue
		for hero in heroes:
			if hero.hp > 0 and snapshot.worn[hero.id][slot] == "":
				return {"patch_id": patch_id, "hero_id": hero.id, "slot": slot}
	return {}


func choose_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		attacks: CombatAttackCards, run_cards: RunRestStitchCards,
		plain: CombatPoolPlainStrikes, heavy: CombatWardenPoolHeavyAttacks,
		rejected_ids: Array, blocks: CombatWardenPoolBlockCards = null) -> Dictionary:
	if not deck.turn_active or party.is_defeated() or enemies.is_victorious():
		return {}
	var best := {}
	var best_score := -1
	var targeter := CombatAttackTargeting.new()
	for id in deck.hand:
		if rejected_ids.has(id):
			continue
		if EARNED_POOL_BLOCKS.has(id.trim_suffix("_plus")):
			var definition := _pool_definition(id)
			if blocks == null or not blocks.is_patch_binding_valid() or definition.is_empty() \
					or definition.cost > deck.energy \
					or not _living_owner_in_from(party.get_heroes(), definition):
				continue
			var target := 0
			if definition.target_kind == "ally_single":
				for hero in party.get_heroes():
					if hero.hp > 0 and (target == 0 or hero.block < party.get_hero(target).block):
						target = hero.position
				if target == 0:
					continue
			if 190 > best_score:
				best_score = 190
				best = {"kind": "earned_block", "id": id, "target": target}
			continue
		if EARNED_POOL_ATTACKS.has(id):
			var definition := _pool_definition(id)
			if definition.is_empty() or definition.cost > deck.energy \
					or not _living_owner_in_from(party.get_heroes(), definition):
				continue
			for position in definition.to_positions:
				var enemy := enemies.get_enemy(position)
				if enemy.is_empty() or enemy.hp <= 0 or enemy.position != position:
					continue
				if heavy.is_supported_card(id) and not heavy.can_play(deck, party, enemies, id, position):
					continue
				if not heavy.is_supported_card(id) and not plain.is_patch_binding_valid():
					continue
				# Earned direct hits get first consideration; tie order follows the hand
				# and authored target slots, with no RNG or speculative damage.
				if 200 > best_score:
					best_score = 200
					best = {"kind": "earned_pool", "id": id, "target": position}
			continue
		if STARTER_ATTACKS.has(id):
			var forecast := attacks.forecast_attack(deck, party, enemies, id)
			if not forecast.get("playable", false):
				continue
			for hit in forecast.hits:
				var enemy := enemies.get_enemy(hit.position)
				var score: int = hit.damage * 2
				if hit.damage >= enemy.hp + enemy.block:
					score += 100
				elif enemy.hp <= 8:
					score += 12
				if score > best_score:
					best_score = score
					best = {"kind": "attack", "id": id,
						"target": hit.position if forecast.requires_selection else 0}
			continue
		if id.begins_with(RunRestStitchCards.ID_PREFIX):
			var preview := CombatStitchedTargetPreview.new().get_preview(
				run_cards, run_cards.get_snapshot(), deck, party, enemies, id)
			if not preview.get("playable", false):
				continue
			var halves: Array = preview.halves
			var both_starter_attacks := true
			var target_values := [0, 0]
			for index in range(2):
				var half: Dictionary = halves[index]
				if not STARTER_ATTACKS.has(half.card_id):
					both_starter_attacks = false
					break
				if half.requires_selection:
					if half.target_positions.is_empty():
						both_starter_attacks = false
						break
					target_values[index] = half.target_positions[0]
			if both_starter_attacks and 45 > best_score:
				best_score = 45
				best = {"kind": "stitched", "id": id,
					"first": target_values[0], "second": target_values[1]}
			continue
		var def := StarterCards.new().get_definition(id)
		if def.is_empty() or def.cost > deck.energy or not _living_owner_in_from(party.get_heroes(), def):
			continue
		var kind: String = def.target_kind
		var effects: Dictionary = def.effects
		var target := 0
		var score := -1
		if kind == "ally_single":
			var missing := 0
			for hero in party.get_heroes():
				if hero.hp <= 0 or (not def.to_positions.is_empty() and not def.to_positions.has(hero.position)):
					continue
				var value: int = hero.max_hp - hero.hp if effects.has("heal") else hero.max_hp - hero.hp + 2
				if value > missing:
					missing = value
					target = hero.position
			if target > 0:
				score = 14 + missing if effects.has("heal") and missing > 0 else 3
		elif kind == "self" and effects.has("block"):
			score = 4
		elif kind == "none" and effects.has("draw"):
			score = 60
		if score > best_score:
			best_score = score
			best = {"kind": "support", "id": id, "target": target}
	return best


func _pool_definition(id: String) -> Dictionary:
	if id.begins_with("warden_"):
		return WardenPoolCards.new().get_definition(id)
	return SeamstressPoolCards.new().get_definition(id)


func _living_owner_in_from(heroes: Array, definition: Dictionary) -> bool:
	for hero in heroes:
		if hero.id == definition.owner:
			return hero.hp > 0 and definition.from_positions.has(hero.position)
	return false
