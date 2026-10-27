class_name CombatWardenGuardReactions
extends RefCounted
## Resolves Warden Guarding and Thorns reactions (D2-1).
## Scene-free, deterministic rule service for Draw Fire and Counter-stitch card plays
## and enemy attack reactions.

const WARDEN_ID := "warden"
## One-shot Dodge is an integer token on the hero's statuses: 1 is armed, 0 is
## inert. Spending it removes the key, exactly like CombatStatuses does.
const DODGE_STATUS_KEY := "dodge_next_attack"
const ALLOWED_CARD_IDS: Array[String] = [
	"warden_draw_fire",
	"warden_draw_fire_plus",
	"warden_counter_stitch",
	"warden_counter_stitch_plus",
]

var guarding: bool = false
var thorns: int = 0

var _binding_attempted: bool = false
var _binding_valid: bool = false
var _wardrobe: RunPatchWardrobe = null
var _torn: RunTornMending = null
var _wardrobe_snapshot: Dictionary = {}
var _torn_snapshot: Dictionary = {}
var _patch_rules: CombatPatchAttackRules = null
var _head_rules: CombatM05HeadPatchRules = null


## Authenticates a genuine run wardrobe and torn ledger for the worn Block patches.
## An explicit attempt always replaces any previous binding; a failed attempt
## leaves this service fail-closed instead of silently playing unpatched.
func bind_patch_wardrobe(wardrobe: Variant, torn: Variant,
		expected_wardrobe: Variant = null, expected_torn: Variant = null) -> bool:
	_binding_attempted = true
	_binding_valid = false
	_wardrobe = null
	_torn = null
	_wardrobe_snapshot = {}
	_torn_snapshot = {}
	_patch_rules = null
	_head_rules = null

	if not (wardrobe is RunPatchWardrobe) or not (torn is RunTornMending):
		return false
	if not wardrobe.is_valid() or not torn.is_valid():
		return false

	var snap: Dictionary = wardrobe.get_snapshot()
	var torn_state: Dictionary = torn.read_state()

	if expected_wardrobe != null:
		if typeof(expected_wardrobe) != TYPE_DICTIONARY or expected_wardrobe != snap:
			return false
	if expected_torn != null:
		if typeof(expected_torn) != TYPE_DICTIONARY or expected_torn != torn_state:
			return false

	var rules := CombatPatchAttackRules.new()
	if not rules.bind_wardrobe(wardrobe, torn):
		return false

	var head_rules := CombatM05HeadPatchRules.new()
	if not head_rules.bind_wardrobe(wardrobe, torn):
		return false

	_wardrobe = wardrobe
	_torn = torn
	_wardrobe_snapshot = snap.duplicate(true)
	_torn_snapshot = torn_state.duplicate(true)
	_patch_rules = rules
	_head_rules = head_rules
	_binding_valid = true
	return true


## True for the legacy unbound service and for a live, unchanged explicit bind.
func is_patch_binding_valid() -> bool:
	if not _binding_attempted:
		return true
	if not _binding_valid or _wardrobe == null or _torn == null:
		return false
	if not _wardrobe.is_valid() or not _torn.is_valid():
		return false
	if _wardrobe.get_snapshot() != _wardrobe_snapshot:
		return false
	if _torn.read_state() != _torn_snapshot:
		return false
	if _patch_rules == null or not _patch_rules.is_valid():
		return false
	if _head_rules == null or not _head_rules.read_projection().get("ok", false):
		return false
	return true


## Read-only wearer Block projection for one authored Warden reaction card.
## Returns the authored Block plus +2 per genuine, living, worn block patch.
## Guarding, Thorns and every other effect stay exactly as authored.
func project_block(card_id: Variant) -> Dictionary:
	var rejected := {"ok": false, "block": 0, "bonus": 0}
	if _binding_attempted and not is_patch_binding_valid():
		return rejected
	if typeof(card_id) != TYPE_STRING:
		return rejected
	var card: String = card_id as String
	if not ALLOWED_CARD_IDS.has(card):
		return rejected
	var definition: Dictionary = WardenPoolCards.new().get_definition(card)
	if definition.is_empty() or definition.get("id") != card \
			or definition.get("owner") != WARDEN_ID:
		return rejected
	var effects_v: Variant = definition.get("effects")
	if not effects_v is Dictionary:
		return rejected
	var authored_v: Variant = (effects_v as Dictionary).get("block")
	if not authored_v is int or (authored_v as int) <= 0:
		return rejected
	var authored: int = authored_v as int

	var bonus := 0
	if _binding_attempted:
		if _patch_rules == null or _head_rules == null:
			return rejected
		var arm_bonus: int = _patch_rules.card_block_bonus(WARDEN_ID, card)
		if arm_bonus < 0:
			return rejected
		var head_bonus: int = _head_rules.get_bonus(WARDEN_ID, card, "block")
		if head_bonus < 0:
			return rejected
		bonus = arm_bonus + head_bonus
		if bonus < 0 or authored > CombatParty.MAX_INT - bonus:
			return rejected
	return {"ok": true, "block": authored + bonus, "bonus": bonus}


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
	# Authenticated wearer projection: authored Block plus genuine worn patches.
	var projected: Dictionary = project_block(card_id)
	if not projected.get("ok", false):
		return false
	var block_amount: int = int(projected.get("block", 0))
	var thorns_gain: int = int(effects.get("thorns", 0))
	if thorns_gain < 0:
		return false

	# Every capacity refusal happens before any party or mode mutation.
	var current_block: int = int(party.get_hero(warden_position).get("block", 0))
	if block_amount > CombatParty.MAX_INT - current_block:
		return false
	if thorns_gain > 0 and thorns_gain > CombatParty.MAX_INT - thorns:
		return false

	# Apply projected Block to Warden
	if not party.gain_block(warden_position, block_amount):
		return false

	# Apply reaction mode
	if bool(effects.get("guarding", false)):
		guarding = true
	if thorns_gain > 0:
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

	# Authenticated wearer Block projection; a failed or stale bind refuses here.
	var projected: Dictionary = project_block(id)
	if not projected.get("ok", false):
		return false
	var projected_block: int = int(projected.get("block", 0))

	# Block upper bound before mutation.
	var warden_hero: Dictionary = p.get_hero(warden_position)
	var current_block: int = int(warden_hero.get("block", 0))
	if projected_block > CombatParty.MAX_INT - current_block:
		return false

	# Remaining Thorns bound before mutation.
	if thorns_gain > 0:
		if thorns_gain > CombatParty.MAX_INT - thorns:
			return false

	# Commit phase: all preflight passed.
	if not d.try_spend_energy(cost):
		return false
	if not p.gain_block(warden_position, projected_block):
		d.combat_state.energy += cost
		return false
	if guarding_gain:
		guarding = true
	if thorns_gain > 0:
		thorns += thorns_gain
	return d.discard_played(id)


## Read-only recipient preview shared with the ordered enemy phase so statuses
## are calculated for the actor who will actually take the hit.
## A downed announced target remains ineligible even if Guarding is active.
func preview_actual_recipient(party: CombatParty, target_position: int) -> Dictionary:
	var failure := {"ok": false, "eligible": false, "actual_target_position": 0, "redirected": false}
	if party == null or not party.is_valid() \
			or target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return failure
	if party.is_downed(target_position):
		return {"ok": true, "eligible": false, "actual_target_position": target_position, "redirected": false}
	var warden_position: int = _find_warden_position(party)
	var redirect: bool = guarding and warden_position > 0 \
		and not party.is_downed(warden_position) and target_position != warden_position
	return {"ok": true, "eligible": true,
		"actual_target_position": warden_position if redirect else target_position,
		"redirected": redirect}


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

	# 3. Use the same read-only recipient decision the phase used for damage math.
	var preview: Dictionary = preview_actual_recipient(party, target)
	if not preview["ok"]:
		return fail_res
	var warden_pos: int = _find_warden_position(party)
	var actual_target: int = preview["actual_target_position"]
	var redirected: bool = preview["redirected"]

	# 4. A genuine one-shot Dodge on the real recipient makes this attempt miss.
	# The token is spent on the authoritative hero record only after the actual
	# recipient (Guard redirect included) is known: no HP, Block or retarget
	# change, and no Thorns retaliation for a hit that never landed. A malformed
	# token fails closed, exactly like a malformed attack.
	var dodge_token: int = _dodge_token(party, actual_target)
	if dodge_token < 0:
		return fail_res
	if dodge_token == 1 and _spend_dodge(party, actual_target):
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

	# 5. Apply damage to actual target
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

	# 6. Retaliate with Thorns if the Warden's own hit really landed
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


## 1 when the fixed-slot hero really carries an armed one-shot Dodge, 0 when it
## carries none (absent or inert), -1 when the token is malformed. Read-only.
static func _dodge_token(party: CombatParty, position: int) -> int:
	if party == null or not party.is_valid() \
			or position < 1 or position > CombatParty.PARTY_SIZE:
		return -1
	var raw_statuses: Variant = party._heroes[position - 1].get("statuses", {})
	if not raw_statuses is Dictionary:
		return -1
	var raw_token: Variant = (raw_statuses as Dictionary).get(DODGE_STATUS_KEY, 0)
	if not raw_token is int:
		return -1
	var token: int = raw_token as int
	if token != 0 and token != 1:
		return -1
	return token


## Spends exactly one armed token on the authoritative hero record, so the
## consumed Dodge publishes with the rest of the attack.
static func _spend_dodge(party: CombatParty, position: int) -> bool:
	if _dodge_token(party, position) != 1:
		return false
	var statuses: Dictionary = party._heroes[position - 1]["statuses"]
	statuses.erase(DODGE_STATUS_KEY)
	return true
