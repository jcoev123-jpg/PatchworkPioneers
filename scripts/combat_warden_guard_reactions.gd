class_name CombatWardenGuardReactions
extends RefCounted
## Resolves Warden Guarding and Thorns reactions (D2-1).
## Scene-free, deterministic rule service for Draw Fire and Counter-stitch card plays
## and enemy attack reactions.

const WARDEN_ID := "warden"
const ALLOWED_CARD_IDS: Array[String] = [
	"warden_draw_fire",
	"warden_draw_fire_plus",
	"warden_counter_stitch",
	"warden_counter_stitch_plus",
]

var guarding: bool = false
var thorns: int = 0


func is_guarding() -> bool:
	return guarding


func get_thorns() -> int:
	return thorns


func is_active() -> bool:
	return guarding or thorns > 0


## Clears card-granted modes at player-turn start without resetting Block.
func begin_player_turn() -> bool:
	guarding = false
	thorns = 0
	return true


## Applies an already-paid, legally held card play to the party and activates the reaction mode.
## Accepts (card, party) or (party, card).
## Rejects invalid/wrong cards, wrong owner, wrong from-positions, downed/absent Warden, or failed Block.
func apply_committed_card(arg1: Variant, arg2: Variant) -> bool:
	var party: CombatParty = null
	var card: Variant = null

	if arg1 is CombatParty:
		party = arg1 as CombatParty
		card = arg2
	elif arg2 is CombatParty:
		party = arg2 as CombatParty
		card = arg1
	else:
		return false

	if party == null or not party.is_valid():
		return false
	if card == null:
		return false

	var card_id: String = ""
	var card_dict: Dictionary = {}
	if card is String:
		card_id = card as String
	elif card is Dictionary:
		card_dict = card as Dictionary
		var raw_id: Variant = card_dict.get("id", card_dict.get("card_id", ""))
		if raw_id is String:
			card_id = raw_id as String
		else:
			return false
	else:
		return false

	if not ALLOWED_CARD_IDS.has(card_id):
		return false

	var catalog: WardenPoolCards = WardenPoolCards.new()
	var auth_def: Dictionary = catalog.get_definition(card_id)
	if auth_def.is_empty():
		return false

	# Validate caller dictionary fields if provided
	if not card_dict.is_empty():
		if card_dict.has("owner") and card_dict["owner"] != WARDEN_ID:
			return false
		if card_dict.has("cost") and card_dict["cost"] != auth_def.get("cost", 1):
			return false
		if card_dict.has("target_kind") and card_dict["target_kind"] != "self":
			return false
		if card_dict.has("effects"):
			if not card_dict["effects"] is Dictionary:
				return false
			var caller_effects: Dictionary = card_dict["effects"] as Dictionary
			var auth_effects: Dictionary = auth_def.get("effects", {}) as Dictionary
			for k: Variant in auth_effects:
				if caller_effects.get(k) != auth_effects.get(k):
					return false

	# Find living Warden by ID
	var warden_position: int = _find_warden_position(party)
	if warden_position <= 0:
		return false
	if party.is_downed(warden_position):
		return false

	# Validate from-position against authored card definition
	var auth_from: Array = auth_def.get("from_positions", []) as Array
	if not auth_from.has(warden_position):
		return false

	# If caller dict provided from_positions, check it too
	if card_dict.has("from_positions"):
		if not card_dict["from_positions"] is Array:
			return false
		var caller_from: Array = card_dict["from_positions"] as Array
		if not caller_from.has(warden_position):
			return false

	var effects: Dictionary = auth_def.get("effects", {}) as Dictionary
	var block_amount: int = int(effects.get("block", 0))

	# Apply authored block to Warden
	if not party.gain_block(warden_position, block_amount):
		return false

	# Apply reaction mode
	if bool(effects.get("guarding", false)):
		guarding = true
	var thorns_gain: int = int(effects.get("thorns", 0))
	if thorns_gain > 0:
		if thorns_gain > CombatParty.MAX_INT - thorns:
			return false
		thorns += thorns_gain

	return true


## Paid shared-hand play: spends energy, commits the card to discard, and applies the
## reaction effect. All preflight checks run before any mutation. Returns false on
## any rejection without changing deck/party/mode/RNG state.
func play_from_hand(deck: Variant, party: Variant, card_id: Variant) -> bool:
	if deck == null or party == null:
		return false
	if not party is CombatParty:
		return false
	var p: CombatParty = party as CombatParty
	if not p.is_valid():
		return false
	if not deck is CombatDeck:
		return false
	var d: CombatDeck = deck as CombatDeck
	if d.combat_state == null:
		return false
	if not d.turn_active:
		return false
	if not card_id is String or (card_id as String).is_empty():
		return false
	var id: String = card_id as String
	if not ALLOWED_CARD_IDS.has(id):
		return false
	if not d.hand.has(id):
		return false

	var catalog: WardenPoolCards = WardenPoolCards.new()
	var auth_def: Dictionary = catalog.get_definition(id)
	if auth_def.is_empty() or auth_def.get("id") != id:
		return false

	var owner_id: String = str(auth_def.get("owner", ""))
	if owner_id != WARDEN_ID:
		return false

	var cost_v: Variant = auth_def.get("cost")
	if not cost_v is int:
		return false
	var cost: int = cost_v as int
	if cost < 0 or cost > CombatState.TURN_ENERGY:
		return false
	if cost > d.energy:
		return false

	var from_v: Variant = auth_def.get("from_positions")
	if not from_v is Array or (from_v as Array).is_empty():
		return false
	var from_positions: Array = from_v as Array
	for pos_v in from_positions:
		if not pos_v is int:
			return false
		var pos: int = pos_v as int
		if pos < 1 or pos > CombatParty.PARTY_SIZE:
			return false

	var target_kind: Variant = auth_def.get("target_kind")
	if target_kind != "self":
		return false

	var effects_v: Variant = auth_def.get("effects")
	if not effects_v is Dictionary:
		return false
	var effects: Dictionary = effects_v as Dictionary
	var block_v: Variant = effects.get("block", 0)
	if not block_v is int:
		return false
	var block_amount: int = block_v as int
	if block_amount < 0:
		return false

	var guarding_gain: bool = false
	if effects.has("guarding"):
		if not effects["guarding"] is bool:
			return false
		guarding_gain = effects["guarding"] as bool

	var thorns_gain: int = 0
	if effects.has("thorns"):
		var tg_v: Variant = effects.get("thorns")
		if not tg_v is int:
			return false
		thorns_gain = tg_v as int
		if thorns_gain < 0:
			return false

	# Roster integrity (fail-closed) using public snapshots.
	var heroes_check: Array[Dictionary] = p.get_heroes()
	if heroes_check.size() != CombatParty.PARTY_SIZE:
		return false
	var seen_ids: Array[String] = []
	for index in range(CombatParty.PARTY_SIZE):
		var h: Dictionary = heroes_check[index]
		var hid_v: Variant = h.get("id")
		var hpos_v: Variant = h.get("position")
		var hhp_v: Variant = h.get("hp")
		var hmax_v: Variant = h.get("max_hp")
		if not hid_v is String or (hid_v as String).is_empty() or seen_ids.has(hid_v as String):
			return false
		if not hpos_v is int or (hpos_v as int) != index + 1:
			return false
		if not hhp_v is int or not hmax_v is int:
			return false
		var hhp: int = hhp_v as int
		var hmax: int = hmax_v as int
		if hmax <= 0 or hhp < 0 or hhp > hmax:
			return false
		seen_ids.append(hid_v as String)

	# Unique living Warden.
	var warden_count := 0
	var warden_position := 0
	for hero: Dictionary in heroes_check:
		if hero.get("id") == WARDEN_ID:
			warden_count += 1
			warden_position = int(hero.get("position", 0))
	if warden_count != 1:
		return false
	if warden_position <= 0 or not from_positions.has(warden_position):
		return false
	if p.is_downed(warden_position):
		return false

	# Block upper bound before mutation.
	var warden_hero: Dictionary = p.get_hero(warden_position)
	var current_block: int = int(warden_hero.get("block", 0))
	if block_amount > CombatParty.MAX_INT - current_block:
		return false

	# Remaining Thorns bound before mutation.
	if thorns_gain > 0:
		if thorns_gain > CombatParty.MAX_INT - thorns:
			return false

	# Commit phase: all preflight passed.
	if not d.try_spend_energy(cost):
		return false
	if not p.gain_block(warden_position, block_amount):
		d.combat_state.energy += cost
		return false
	if guarding_gain:
		guarding = true
	if thorns_gain > 0:
		thorns += thorns_gain
	return d.discard_played(id)


## Resolves an incoming enemy attack against the party and roster.
## Validates input, skips slain sources and downed targets, retargets while Guarding,
## applies damage, and retaliates with Thorns if Warden was hit.
func resolve_enemy_attack(party_val: Variant, enemies_val: Variant, attack_val: Variant) -> Dictionary:
	var fail_res: Dictionary = {
		"ok": false,
		"success": false,
		"applied": false,
		"target_position": 0,
		"actual_target_position": 0,
		"redirected": false,
		"retaliation_damage": 0,
		"retaliatory_damage": 0,
	}

	if not party_val is CombatParty:
		return fail_res
	var party: CombatParty = party_val as CombatParty
	if not party.is_valid():
		return fail_res

	if not enemies_val is CombatEnemies:
		return fail_res
	var enemies: CombatEnemies = enemies_val as CombatEnemies
	if not enemies.is_valid():
		return fail_res

	if not attack_val is Dictionary:
		return fail_res
	var attack: Dictionary = attack_val as Dictionary

	if not attack.has("enemy_position") or not attack.has("target_position") or not attack.has("amount"):
		return fail_res

	var raw_source: Variant = attack.get("enemy_position")
	var raw_target: Variant = attack.get("target_position")
	var raw_amount: Variant = attack.get("amount")

	if not raw_source is int or not raw_target is int or not raw_amount is int:
		return fail_res

	var source: int = raw_source as int
	var target: int = raw_target as int
	var amount: int = raw_amount as int

	var enemy_count: int = enemies.get_enemies().size()
	if source < 1 or source > enemy_count:
		return fail_res

	if target < 1 or target > CombatParty.PARTY_SIZE:
		return fail_res

	if amount < 0 or amount > CombatParty.MAX_INT:
		return fail_res

	if attack.has("type") and str(attack.get("type")) != "attack":
		return fail_res

	# 1. Check if source enemy is slain: skip without action
	if enemies.is_slain(source):
		return {
			"ok": true,
			"success": true,
			"applied": false,
			"target_position": target,
			"actual_target_position": target,
			"redirected": false,
			"retaliation_damage": 0,
			"retaliatory_damage": 0,
		}

	# 2. Check if target hero is downed: skip without action
	if party.is_downed(target):
		return {
			"ok": true,
			"success": true,
			"applied": false,
			"target_position": target,
			"actual_target_position": target,
			"redirected": false,
			"retaliation_damage": 0,
			"retaliatory_damage": 0,
		}

	# 3. Determine actual target (Guarding redirection)
	var warden_pos: int = _find_warden_position(party)
	var warden_alive: bool = warden_pos > 0 and not party.is_downed(warden_pos)
	var actual_target: int = target
	var redirected: bool = false

	if guarding and warden_alive:
		if target != warden_pos:
			actual_target = warden_pos
			redirected = true

	# 4. Apply damage to actual target
	var applied: bool = party.apply_damage(actual_target, amount)
	if not applied:
		return {
			"ok": true,
			"success": true,
			"applied": false,
			"target_position": actual_target,
			"actual_target_position": actual_target,
			"redirected": redirected,
			"retaliation_damage": 0,
			"retaliatory_damage": 0,
		}

	# 5. Retaliate with Thorns if Warden was hit
	var retaliatory_damage: int = 0
	if actual_target == warden_pos and thorns > 0:
		retaliatory_damage = thorns
		enemies.apply_damage(source, retaliatory_damage)

	return {
		"ok": true,
		"success": true,
		"applied": true,
		"target_position": actual_target,
		"actual_target_position": actual_target,
		"redirected": redirected,
		"retaliation_damage": retaliatory_damage,
		"retaliatory_damage": retaliatory_damage,
	}


func _find_warden_position(party: CombatParty) -> int:
	if party == null or not party.is_valid():
		return 0
	var heroes: Array[Dictionary] = party.get_heroes()
	for hero: Dictionary in heroes:
		if hero.get("id") == WARDEN_ID:
			return int(hero.get("position", 0))
	return 0
