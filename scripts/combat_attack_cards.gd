class_name CombatAttackCards
extends RefCounted
## Scene-free, single authoritative charge/discard for authored starter attacks.
## Damage reads current actor records; confirmed hits persist on the enemy roster.

const ATTACK_IDS := [
	"warden_strike_plus",
	"warden_strike", "warden_shield_bash", "seamstress_prick",
	"tinker_pop_shot", "tinker_scrap_bomb"
]

var _targeting := CombatAttackTargeting.new()
var _damage := CombatStatusAttacks.new()
var _area := CombatAreaAttacks.new()
var _on_hit := CombatOnHitStatuses.new()
var _tinker := CombatTinkerFirstAttack.new()
var _basic := CombatBasicAttacks.new()
var _statuses := CombatStatuses.new()
var _patches: CombatPatchAttackRules = null
var _head_rules: CombatM05HeadPatchRules = null


## A failed explicit binding fails closed; an untouched service stays unbound.
## Binding again starts a new combat with a fresh wearer snapshot and latch.
## The rules keep the authenticated run receipts, so a later wardrobe or torn
## change rejects every forecast and hit instead of reusing stale powers.
func bind_patch_wardrobe(wardrobe: RunPatchWardrobe, torn: RunTornMending) -> bool:
	_patches = CombatPatchAttackRules.new()
	return _patches.bind_wardrobe(wardrobe, torn)


## A present, invalid or stale M05 HEAD binding rejects all attacks.
## The untouched unbound starter service continues with authored statuses.
func bind_head_patch_rules(rules: CombatM05HeadPatchRules) -> bool:
	_head_rules = rules
	return rules != null and rules.read_projection().get("ok", false)


## The live turn coordinator must call this once per new player turn.
## No deck, roster, or status state is changed by the reset.
func start_player_turn() -> void:
	_tinker.start_player_turn()


## Detached passive state for an atomic multi-effect transaction. The caller
## resolves against detached rosters and publishes only after every half succeeds.
func stage_transaction() -> CombatAttackCards:
	var staged := CombatAttackCards.new()
	staged._tinker._consumed = _tinker._consumed
	staged._tinker._path_bonus = _tinker._path_bonus
	# Read-only projection is battle-scoped; staged halves must use the exact
	# same live authority and reject if its source receipt has gone stale.
	staged._head_rules = _head_rules
	if _patches != null:
		staged._patches = CombatPatchAttackRules.new()
		staged._patches._valid = _patches._valid
		staged._patches._active = _patches._active.duplicate(true)
		staged._patches._consumed = _patches._consumed.duplicate(true)
		# The staged half must authenticate against the same live receipts.
		staged._patches._wardrobe = _patches._wardrobe
		staged._patches._torn = _patches._torn
		staged._patches._wardrobe_receipt = _patches._wardrobe_receipt.duplicate(true)
		staged._patches._torn_receipt = _patches._torn_receipt.duplicate(true)
	return staged


func commit_transaction(staged: CombatAttackCards) -> void:
	_tinker._consumed = staged._tinker._consumed
	_tinker._path_bonus = staged._tinker._path_bonus
	if _patches != null:
		_patches._consumed = staged._patches._consumed.duplicate(true)


## Reuse full authored attack validation/effects without charging a composite's
## real deck for this half. No RNG or synthetic half enters the shared piles.
func resolve_staged_half(party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, base_bonus: int = 0) -> Dictionary:
	var eligibility := CombatDeck.new([], RandomNumberGenerator.new())
	eligibility.hand.append(card_id)
	eligibility.combat_state.start_player_turn()
	return _play_attack(eligibility, party, enemies, card_id, target_position,
		{}, {}, 0, base_bonus)


## Rejects every invalid selection, recipient and status snapshot before mutating
## any real combat state. Target positions are original roster slots, never indices
## compacted after deaths. Supplied status snapshots are never mutated.
## cost_discount is an already-validated authored reduction (never more than the
## one Clockwork point) applied to the real charge exactly once, before spending.
func play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int = 0, attacker_statuses: Dictionary = {},
		enemy_statuses_by_position: Dictionary = {}, cost_discount: int = 0,
		mitt: CombatFrayfinderMitt = null, quote: Dictionary = {}) -> Dictionary:
	var bonus := 0
	if mitt != null and quote.get("bonus") == 2:
		bonus = mitt.authorize_starter_hit(quote, deck, party, enemies, card_id,
			target_position, cost_discount)
		if bonus != 2:
			return _failure()
	return _play_attack(deck, party, enemies, card_id, target_position,
		attacker_statuses, enemy_statuses_by_position, cost_discount, bonus)


## Internal damage seam: only an authenticated starter quote or a stitched
## transaction's validated per-half authorization reaches this base bonus.
func _play_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, attacker_statuses: Dictionary,
		enemy_statuses_by_position: Dictionary, cost_discount: int, base_bonus: int) -> Dictionary:
	var plan := _prepare(deck, party, enemies, card_id, target_position,
		attacker_statuses, enemy_statuses_by_position, true, cost_discount, base_bonus)
	if not plan.ok:
		return _failure()
	var positions: Array[int] = plan.positions
	var applications: Dictionary = plan.applications
	var attack_damage: int = plan.attack_damage
	var cost_value: int = plan.cost
	var owner_statuses: Dictionary = plan.owner_statuses
	var target_statuses: Dictionary = plan.target_statuses
	var owner_id: String = plan.owner_id
	# Detached pre-hit records survive lethal damage and multi-target resolution.
	var pre_hits: Dictionary = {}
	for position in positions:
		pre_hits[position] = enemies.get_enemy(position)
	if card_id in CombatBasicAttacks.SUPPORTED_CARD_IDS:
		var final_damage := _statuses.adjusted_attack_damage(attack_damage,
			owner_statuses, target_statuses[target_position])
		var before := enemies.get_enemy(target_position)
		if not _basic.play(deck, party, enemies, card_id, target_position, final_damage):
			return _failure()
		var after := enemies.get_enemy(target_position)
		enemies.apply_statuses(applications)
		_tinker.record_successful_attack(card_id)
		if _patches != null:
			_patches.record_successful_attack(owner_id)
		var hits: Array[Dictionary] = [{
			"position": target_position,
			"damage": final_damage,
			"block_absorbed": before["block"] - after["block"],
			"hp_loss": before["hp"] - after["hp"],
			"statuses": applications[target_position]
		}]
		_retaliate_hits(party, plan.owner_position, hits, pre_hits)
		return {"ok": true, "hits": hits}
	# All downstream operations are now guaranteed by the real models and
	# immutable preflight. The existing status bridge owns final-floor rounding.
	if not deck.try_spend_energy(cost_value):
		return _failure()
	var hits: Array[Dictionary] = []
	if card_id == CombatAreaAttacks.SCRAP_BOMB_ID:
		hits.assign(_area.resolve(enemies, attack_damage,
			owner_statuses, target_statuses)["hits"])
		for hit in hits:
			hit["statuses"] = applications[hit["position"]]
	else:
		for position in positions:
			var event := _damage.resolve_vs_enemy(enemies, position, attack_damage,
				owner_statuses, target_statuses[position])
			# The validated living recipient guarantees this bridge succeeds.
			var statuses: Dictionary = applications[position]
			hits.append({
				"position": position,
				"damage": event["damage"],
				"block_absorbed": event["block_absorbed"],
				"hp_loss": event["hp_loss"],
				"statuses": statuses
			})
	deck.discard_played(card_id)
	enemies.apply_statuses(applications)
	_tinker.record_successful_attack(card_id)
	if _patches != null:
		_patches.record_successful_attack(owner_id)
	_retaliate_hits(party, plan.owner_position, hits, pre_hits)
	return {"ok": true, "hits": hits}


## Reconstruct the authentic bridge receipt without changing public hit rows.
## Resolve after every confirmed enemy hit: an attacker downed by an earlier
## Thorns defender must never cancel later Bomb hits, status or card payment.
func _retaliate_hits(party: CombatParty, owner_position: int,
		hits: Array[Dictionary], pre_hits: Dictionary) -> void:
	var keywords := CombatEnemyKeywordRules.new()
	for hit in hits:
		if hit["damage"] <= 0:
			continue
		var receipt := {"ok": true, "damage": hit["damage"],
			"block_absorbed": hit["block_absorbed"], "hp_loss": hit["hp_loss"]}
		keywords.resolve_thorns_retaliation(party, owner_position,
			pre_hits[hit["position"]], receipt)


## Pure preflight shared by forecasts and committed attacks. No latch is consumed.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, target_position: int, attacker_statuses: Dictionary,
		enemy_statuses_by_position: Dictionary, select_target: bool,
		cost_discount: int = 0, base_bonus: int = 0) -> Dictionary:
	if base_bonus not in [0, 2]:
		return _failure()
	if deck == null or party == null or enemies == null:
		return _failure()
	# A frozen battle-start validity flag is not authority on its own: the live
	# wardrobe and torn ledger must still carry the receipts it was bound to.
	if _patches != null and (not _patches.is_valid() or not _patches.is_current()):
		return _failure()
	if _head_rules != null and not _head_rules.read_projection().get("ok", false):
		return _failure()
	if not ATTACK_IDS.has(card_id) or not enemies.can_apply_statuses({}):
		return _failure()
	if enemies.is_victorious():
		return _failure()

	var definition: Dictionary = StarterCards.new().get_definition(card_id)
	if definition.get("id") != card_id or not definition.get("effects") is Dictionary:
		return _failure()
	var damage_value: Variant = definition["effects"].get("damage")
	var cost_value: Variant = definition.get("cost")
	if not damage_value is int or damage_value < 0 or not cost_value is int or cost_value < 0:
		return _failure()

	# Preview owns hand/energy/owner-position and alive-target legality. Recheck
	# the chosen target below, as previews do not commit a selection.
	var preview := _targeting.get_preview(deck, party, enemies, card_id, cost_discount)
	if not preview.get("playable", false):
		return _failure()
	var positions: Array[int] = preview["target_positions"]
	if select_target and preview["requires_selection"]:
		if not positions.has(target_position):
			return _failure()
		positions = [target_position]
	elif select_target and target_position != 0:
		# Enemy-all is deliberately target-free, even when there is one enemy.
		return _failure()

	# Validate ALL supplied status entries, including late or unselected slots,
	# before damage/energy/discard or first-attack bonus can change.
	if not _valid_statuses(attacker_statuses):
		return _failure()
	for position in enemy_statuses_by_position:
		if not position is int or position < 1 or position > CombatEnemies.MAX_ENEMIES:
			return _failure()
		if enemies.get_enemy(position).is_empty():
			return _failure()
		var statuses: Variant = enemy_statuses_by_position[position]
		if not statuses is Dictionary or not _valid_statuses(statuses):
			return _failure()

	# Legacy caller snapshots are validated above but never control real damage.
	# Bind the status map to the unique card owner by ID, not their old slot.
	var heroes := party.get_heroes()
	if not CombatStatusTurnBatch.new().tick_side("heroes", heroes)["ok"]:
		return _failure()
	var owner_id: Variant = definition.get("owner")
	if not owner_id is String or owner_id.is_empty():
		return _failure()
	var owner_statuses: Dictionary = {}
	var owner_count := 0
	var owner_position := 0
	for hero in heroes:
		if hero["id"] == owner_id:
			owner_count += 1
			owner_position = hero["position"]
			owner_statuses = hero.get("statuses", {})
	if owner_count != 1:
		return _failure()
	# A freshly constructed CombatParty can have positive HP while the sewn
	# run ledger still marks this owner torn. Never let that actor cast.
	if _head_rules != null:
		var living_run_owner := false
		for run_hero in _head_rules._torn.read_state().get("heroes", []):
			if run_hero.get("id") == owner_id and run_hero.get("hp", 0) > 0:
				living_run_owner = true
		if not living_run_owner:
			return _failure()
	var patch_statuses := {} if _patches == null else _patches.exposed_for_first_hit(owner_id)
	var patch_damage := 0 if _patches == null else _patches.damage_bonus(owner_id)
	# Frayfinder is one base hit, never an area, later hit, or support cast.
	if base_bonus > 0 and (definition.get("target_kind") != "enemy_single"
			or not select_target or positions.size() != 1):
		return _failure()

	# Verify the entire batch before the first mutation (including late targets).
	var target_statuses: Dictionary = {}
	for position in positions:
		var enemy := enemies.get_enemy(position)
		if enemy.is_empty() or enemy.get("position") != position or enemies.is_slain(position):
			return _failure()
		if not enemy.get("hp") is int or not enemy.get("block") is int:
			return _failure()
		if enemy["hp"] <= 0 or enemy["block"] < 0:
			return _failure()
		# Thorns metadata is not a CombatStatuses counter. Inspect every actual
		# recipient before energy, discard, damage, statuses or latches mutate.
		var thorns: Variant = enemy.get("thorns", 0)
		if not thorns is int or thorns < 0:
			return _failure()
		target_statuses[position] = enemy.get("statuses", {})

	var applications := {}
	var eligible: Array[int] = []
	for position in positions:
		var additions := _on_hit.status_for_confirmed_hit(card_id, true)
		if _head_rules != null:
			for status in ["weak", "bleed"]:
				if additions.get(status, 0) > 0:
					var extra := _head_rules.get_bonus(owner_id, card_id, status)
					if extra > CombatStatuses.MAX_INT - additions[status]:
						return _failure()
					additions[status] += extra
		if _patches != null and additions.get("bleed", 0) > 0:
			var arm_bleed := _patches.card_bleed_bonus(owner_id, card_id)
			if arm_bleed > 0:
				if arm_bleed > CombatStatuses.MAX_INT - additions["bleed"]:
					return _failure()
				additions["bleed"] += arm_bleed
		for status in patch_statuses:
			additions[status] = additions.get(status, 0) + patch_statuses[status]
		var application := {position: additions}
		# A single-target forecast lists independently playable choices. One
		# overflowing on-hit status must not hide another valid destination.
		if not select_target and preview["requires_selection"] and not enemies.can_apply_statuses(application):
			continue
		eligible.append(position)
		applications[position] = application[position]
	positions = eligible
	if positions.is_empty():
		return _failure()
	if not enemies.can_apply_statuses(applications):
		return _failure()
	var bonus := _tinker.bonus_for_attack(card_id)
	if damage_value > CombatStatuses.MAX_INT - bonus - patch_damage - base_bonus:
		return _failure()
	var attack_damage: int = damage_value + bonus + patch_damage + base_bonus
	if card_id == CombatAreaAttacks.SCRAP_BOMB_ID and not _area.can_resolve(
			enemies, attack_damage, owner_statuses, target_statuses):
		return _failure()
	return {"ok": true, "positions": positions, "applications": applications,
		"attack_damage": attack_damage, "cost": cost_value - cost_discount,
		"printed_cost": cost_value,
		"requires_selection": preview["requires_selection"],
		"owner_id": owner_id, "owner_position": owner_position,
		"owner_statuses": owner_statuses, "target_statuses": target_statuses}


## Returns ordered damage choices for singles, or all recipients for target-free attacks.
## Uses the current instance's Tinker latch without spending or recording a hit.
func forecast_attack(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: String, attacker_statuses: Dictionary = {},
		enemy_statuses_by_position: Dictionary = {}, cost_discount: int = 0) -> Dictionary:
	var plan := _prepare(deck, party, enemies, card_id, 0,
		attacker_statuses, enemy_statuses_by_position, false, cost_discount)
	if not plan.ok:
		return {"playable": false, "requires_selection": false, "hits": []}
	var hits: Array[Dictionary] = []
	for position in plan.positions:
		hits.append({"position": position, "damage": _statuses.adjusted_attack_damage(
			plan.attack_damage, plan.owner_statuses, plan.target_statuses[position])})
	return {"playable": true, "requires_selection": plan.requires_selection, "hits": hits}


func _valid_statuses(statuses: Dictionary) -> bool:
	for name in statuses:
		if not name is String or name not in ["bleed", "weak", "exposed"]:
			return false
		var count: Variant = statuses[name]
		if not count is int or count < 0:
			return false
	return true


func _failure() -> Dictionary:
	return {"ok": false, "hits": []}
