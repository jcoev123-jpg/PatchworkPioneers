class_name CombatSeamstressTetherRules
extends RefCounted
## Scene-free V3-1/V3-2 Tether confirmed-hit echo rule helper for the Seamstress's
## four authored two-target red-thread cards:
##   - Tether Loop / Tether Loop+ (V3SeamstressStarterCards)
##   - Tether Stitch / Tether Stitch+ (V3SeamstressPoolCards)
##
## This service owns two deliberately bounded rules-layer operations:
##   1. `authorize_pair_link` (`admit_pair_link`): validates an authoritative
##      CombatEnemies roster, authenticates one of the four canonical Tether card
##      definitions against its owning catalog, and admits two distinct living
##      enemy positions in 1..3 as a detached pair-link record binding their
##      positions and enemy IDs.
##   2. `resolve_confirmed_hit_echo` (`apply_confirmed_hit_echo`): given an
##      authorised pair link, the primary target's pre-hit snapshot, and the
##      genuine post-hit CombatStatusAttacks.resolve_vs_enemy receipt against the
##      authoritative CombatEnemies roster, authenticates the primary hit
##      transition, prevents receipt replay, computes floor(50% of actual positive
##      HP lost), and applies that raw echo damage to the opposite living linked
##      enemy through CombatEnemies.apply_damage (secondary Block absorbs before HP).
##
## Boundary: this helper is NOT a card-play, hand, or turn-lifecycle owner. It
## never accepts CombatDeck, charges energy, discards cards, sets links in app.gd,
## ticks rounds, rolls RNG, or invents link duration, expiry, stacking, or
## replacement. An echo is not a separate card attack and never fabricates
## Bleed/Weak/Exposed, Thorns, Enrage, Riposte, or another echo.

const OWNER := "seamstress"
const TARGET_KIND := "enemy_pair"
const SHARE_PERCENT := 50
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The four authentic Tether printings and the exact catalog contract each must carry.
const CARDS := {
	"seamstress_v3_tether_loop": {
		"catalog": "starter",
		"display_name": "Tether Loop",
		"cost": 2,
		"from_positions": [2, 3],
		"target_kind": "enemy_pair",
		"to_positions": [1, 2, 3],
		"effects": {"tether_share_percent": 50},
		"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_loop.png",
		"starting_copies": 1,
		"reward_eligible": false,
		"upgrade_id": "seamstress_v3_tether_loop_plus",
	},
	"seamstress_v3_tether_loop_plus": {
		"catalog": "starter",
		"display_name": "Tether Loop+",
		"cost": 1,
		"from_positions": [2, 3],
		"target_kind": "enemy_pair",
		"to_positions": [1, 2, 3],
		"effects": {"tether_share_percent": 50},
		"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_loop.png",
		"starting_copies": 0,
		"reward_eligible": false,
		"upgrade_of": "seamstress_v3_tether_loop",
	},
	"seamstress_v3_tether_stitch": {
		"catalog": "pool",
		"display_name": "Tether Stitch",
		"cost": 2,
		"from_positions": [2, 3],
		"target_kind": "enemy_pair",
		"to_positions": [1, 2, 3],
		"effects": {"tether_share_percent": 50},
		"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
		"starting_copies": 0,
		"rarity": "uncommon",
		"reward_eligible": true,
		"upgrade_id": "seamstress_v3_tether_stitch_plus",
	},
	"seamstress_v3_tether_stitch_plus": {
		"catalog": "pool",
		"display_name": "Tether Stitch+",
		"cost": 1,
		"from_positions": [2, 3],
		"target_kind": "enemy_pair",
		"to_positions": [1, 2, 3],
		"effects": {"tether_share_percent": 50},
		"illustration_path": "res://assets/paper/cards/seamstress_v3_tether_stitch.png",
		"starting_copies": 0,
		"rarity": "uncommon",
		"reward_eligible": false,
		"upgrade_of": "seamstress_v3_tether_stitch",
	},
}

## Closed set of keys permitted on an authorised pair-link dictionary.
const ALLOWED_LINK_KEYS := [
	"ok", "reason", "card_id", "card_definition", "definition", "card",
	"share_percent", "first_position", "second_position", "first_id", "second_id",
	"positions", "enemy_ids",
]

## Closed set of keys on an authentic CombatStatusAttacks.resolve_vs_enemy receipt.
const RECEIPT_KEYS := ["ok", "damage", "block_absorbed", "hp_loss"]

var _consumed_receipts: Array[Dictionary] = []
var _consumed_receipt_ids: Dictionary = {}
var _consumed_transitions: Dictionary = {}
var _echo_transitions: Dictionary = {}


## True only for the four authentic Tether card IDs or their exact canonical
## definition dictionaries. Pure lookup; mutates nothing and touches no RNG.
func is_supported_card(card: Variant) -> bool:
	if typeof(card) == TYPE_STRING:
		var id: String = card
		if not CARDS.has(id):
			return false
		return is_authentic_definition(_catalog_definition(id))
	if typeof(card) == TYPE_DICTIONARY:
		return is_authentic_definition(card)
	return false


## Returns a detached canonical definition for one of the four Tether card IDs,
## or {} for any unknown, non-Tether, or tampered catalog entry.
func get_tether_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _catalog_definition(id)
	if not is_authentic_definition(definition):
		return {}
	return definition.duplicate(true)


## Verifies that a card definition dictionary matches both the authored Tether
## specification and the live owning catalog record byte-for-byte and type-for-type.
func is_authentic_definition(definition: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY:
		return false
	var record: Dictionary = definition
	var raw_id: Variant = record.get("id")
	if typeof(raw_id) != TYPE_STRING:
		return false
	var card_id: String = raw_id
	if not CARDS.has(card_id):
		return false
	var spec: Dictionary = CARDS[card_id]
	var expected: Dictionary = {
		"id": card_id,
		"display_name": spec["display_name"],
		"owner": OWNER,
		"cost": spec["cost"],
		"from_positions": spec["from_positions"],
		"target_kind": TARGET_KIND,
		"to_positions": spec["to_positions"],
		"effects": spec["effects"],
		"illustration_path": spec["illustration_path"],
		"starting_copies": spec["starting_copies"],
		"reward_eligible": spec["reward_eligible"],
	}
	if spec.has("rarity"):
		expected["rarity"] = spec["rarity"]
	if spec.has("upgrade_id"):
		expected["upgrade_id"] = spec["upgrade_id"]
	else:
		expected["upgrade_of"] = spec["upgrade_of"]
	if not _same_value(record, expected):
		return false
	var catalog_record: Dictionary = _catalog_definition(card_id)
	return _same_value(catalog_record, expected)


## Pure integer floor calculation for Tether's 50% shared HP loss.
## Returns floor(primary_hp_loss * 50 / 100) for positive integer HP loss, or 0.
func quote_echo_damage(primary_hp_loss: Variant, share_percent: Variant = SHARE_PERCENT) -> int:
	if typeof(primary_hp_loss) != TYPE_INT or typeof(share_percent) != TYPE_INT:
		return 0
	var loss: int = primary_hp_loss
	var pct: int = share_percent
	if loss <= 0 or pct != SHARE_PERCENT:
		return 0
	@warning_ignore("integer_division")
	var echo: int = (loss * pct) / 100
	return maxi(0, echo)


## Admits a caller-authorised pair link for one of the four canonical Tether cards
## and two distinct living enemy positions in 1..3 on an authoritative CombatEnemies
## roster. Accepts either `(enemies, card, pos_a, pos_b)` or `(enemies, card, [pos_a, pos_b])`,
## where `card` is either a canonical definition Dictionary or one of the four Tether card IDs.
## Does not charge energy, discard cards, mutate the roster, or touch RNG.
func authorize_pair_link(enemies: CombatEnemies, card: Variant,
		first_position: Variant, second_position: Variant = null) -> Dictionary:
	var pos_a: Variant = first_position
	var pos_b: Variant = second_position
	if second_position == null and typeof(first_position) == TYPE_ARRAY:
		var pair: Array = first_position
		if pair.size() != 2:
			return _link_refusal("invalid_positions")
		pos_a = pair[0]
		pos_b = pair[1]

	if not _valid_enemy_roster(enemies):
		return _link_refusal("invalid_enemies")

	var definition: Dictionary = _resolve_card_input(card)
	if definition.is_empty():
		return _link_refusal("unsupported_card")

	if typeof(pos_a) != TYPE_INT or typeof(pos_b) != TYPE_INT:
		return _link_refusal("invalid_positions")
	var first_pos: int = pos_a
	var second_pos: int = pos_b

	var to_positions: Array = definition["to_positions"]
	if not to_positions.has(first_pos) or not to_positions.has(second_pos):
		return _link_refusal("position_out_of_range")

	var roster: Array[Dictionary] = enemies.get_enemies()
	if first_pos < 1 or first_pos > roster.size() or second_pos < 1 or second_pos > roster.size():
		return _link_refusal("position_out_of_range")

	if first_pos == second_pos:
		return _link_refusal("duplicate_target")

	var first_enemy: Dictionary = enemies.get_enemy(first_pos)
	var second_enemy: Dictionary = enemies.get_enemy(second_pos)
	if first_enemy.is_empty() or second_enemy.is_empty():
		return _link_refusal("position_out_of_range")

	if enemies.is_slain(first_pos) or int(first_enemy.get("hp", 0)) <= 0 \
			or enemies.is_slain(second_pos) or int(second_enemy.get("hp", 0)) <= 0:
		return _link_refusal("target_slain")

	var first_id: String = str(first_enemy.get("id", ""))
	var second_id: String = str(second_enemy.get("id", ""))
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return _link_refusal("invalid_enemies")

	return {
		"ok": true,
		"reason": "authorized",
		"card_id": str(definition["id"]),
		"card_definition": definition.duplicate(true),
		"share_percent": SHARE_PERCENT,
		"first_position": first_pos,
		"second_position": second_pos,
		"first_id": first_id,
		"second_id": second_id,
		"positions": [first_pos, second_pos],
		"enemy_ids": {first_pos: first_id, second_pos: second_id},
	}


## Alias for authorize_pair_link.
func admit_pair_link(enemies: CombatEnemies, card: Variant,
		first_position: Variant, second_position: Variant = null) -> Dictionary:
	return authorize_pair_link(enemies, card, first_position, second_position)


## True when `pair_link` is a well-formed, untampered Tether pair-link record
## carrying one of the four canonical definitions and two distinct legal positions/IDs.
func is_valid_pair_link(pair_link: Variant) -> bool:
	return _extract_pair_link(pair_link).get("ok", false) == true


## Resolves the 50% confirmed-hit echo for one already-committed primary
## CombatStatusAttacks.resolve_vs_enemy receipt.
##
## Authenticates the primary target's pre-hit identity, position, HP, and Block
## against the authoritative post-hit `enemies` roster and `primary_receipt`.
## Rejects unconfirmed hits, fully/partially forged receipts, stale snapshots,
## replaced actor identities, unlinked positions, echo-of-echo attempts, and
## duplicate/replayed receipts without mutating the roster or RNG.
##
## When the primary hit caused positive HP loss and the linked partner is alive,
## applies floor(hp_loss / 2) raw damage to the partner via CombatEnemies.apply_damage
## so the partner's Block absorbs before HP. If primary HP loss is 0, floor(hp_loss / 2)
## is 0, or the partner is already slain, the echo is inert (ok=true, applied=false,
## echo_damage=0).
func resolve_confirmed_hit_echo(enemies: CombatEnemies, pair_link: Variant,
		primary_position: Variant, pre_hit_primary: Variant = null,
		primary_receipt: Variant = null, receipt_id: Variant = null) -> Dictionary:
	var actual_primary_pos: Variant = primary_position
	var actual_pre_hit: Variant = pre_hit_primary
	var actual_receipt: Variant = primary_receipt
	# Support 4-argument calls `(enemies, pair_link, pre_hit_primary, primary_receipt)`
	# where primary_position is read from pre_hit_primary["position"].
	if typeof(primary_position) == TYPE_DICTIONARY and typeof(pre_hit_primary) == TYPE_DICTIONARY \
			and primary_receipt == null and receipt_id == null:
		actual_pre_hit = primary_position
		actual_receipt = pre_hit_primary
		actual_primary_pos = (actual_pre_hit as Dictionary).get("position")

	if receipt_id != null:
		if typeof(receipt_id) != TYPE_STRING or (receipt_id as String).is_empty() \
				or (receipt_id as String) != (receipt_id as String).strip_edges():
			return _echo_failure("invalid_receipt_id")
		if _consumed_receipt_ids.has(receipt_id):
			return _echo_failure("duplicate_receipt")

	if typeof(actual_receipt) != TYPE_DICTIONARY:
		return _echo_failure("invalid_receipt")
	var receipt: Dictionary = actual_receipt
	for seen: Dictionary in _consumed_receipts:
		if is_same(seen, receipt):
			return _echo_failure("duplicate_receipt")
	if not _valid_primary_receipt(receipt):
		return _echo_failure("invalid_receipt")
	if not receipt["ok"]:
		return _echo_failure("unconfirmed_hit")

	if not _valid_enemy_roster(enemies):
		return _echo_failure("invalid_enemies")

	var link: Dictionary = _extract_pair_link(pair_link)
	if not link.get("ok", false):
		return _echo_failure(str(link.get("reason", "invalid_pair_link")))

	var roster: Array[Dictionary] = enemies.get_enemies()
	var first_pos: int = int(link["first_position"])
	var second_pos: int = int(link["second_position"])
	if first_pos < 1 or first_pos > roster.size() or second_pos < 1 or second_pos > roster.size():
		return _echo_failure("position_out_of_range")

	if typeof(actual_primary_pos) != TYPE_INT:
		return _echo_failure("invalid_primary_position")
	var primary_pos: int = actual_primary_pos

	var partner_pos := 0
	var expected_primary_id := ""
	var expected_partner_id := ""
	if primary_pos == first_pos:
		partner_pos = second_pos
		expected_primary_id = str(link["first_id"])
		expected_partner_id = str(link["second_id"])
	elif primary_pos == second_pos:
		partner_pos = first_pos
		expected_primary_id = str(link["second_id"])
		expected_partner_id = str(link["first_id"])
	else:
		return _echo_failure("unlinked_primary")

	if typeof(actual_pre_hit) != TYPE_DICTIONARY or (actual_pre_hit as Dictionary).is_empty():
		return _echo_failure("invalid_pre_hit_primary")
	var pre: Dictionary = actual_pre_hit
	if not _valid_pre_hit_enemy(pre, primary_pos, expected_primary_id):
		return _echo_failure("primary_identity_mismatch")

	var live_primary: Dictionary = enemies.get_enemy(primary_pos)
	if live_primary.is_empty() or live_primary.get("position") != primary_pos:
		return _echo_failure("invalid_primary_position")
	if live_primary.get("id") != expected_primary_id:
		return _echo_failure("primary_identity_mismatch")
	if live_primary.get("max_hp") != pre["max_hp"]:
		return _echo_failure("primary_state_mismatch")
	if live_primary.get("statuses", {}) != pre.get("statuses", {}):
		return _echo_failure("primary_state_mismatch")

	var damage: int = int(receipt["damage"])
	var simulated: Dictionary = pre.duplicate(true)
	var expected_absorbed: int = mini(int(simulated["block"]), damage)
	simulated["block"] = int(simulated["block"]) - expected_absorbed
	simulated["hp"] = maxi(0, int(simulated["hp"]) - (damage - expected_absorbed))
	CombatEnemies.settle_revival(simulated)
	var expected_block_absorbed: int = int(pre["block"]) - int(simulated["block"])
	var expected_hp_loss: int = int(pre["hp"]) - int(simulated["hp"])

	if int(receipt["block_absorbed"]) != expected_block_absorbed \
			or int(receipt["hp_loss"]) != expected_hp_loss:
		return _echo_failure("receipt_mismatch")

	if int(live_primary["block"]) != int(simulated["block"]) \
			or int(live_primary["hp"]) != int(simulated["hp"]) \
			or bool(live_primary.get("revived", false)) != bool(simulated.get("revived", false)):
		return _echo_failure("stale_or_uncommitted_primary")

	var transition_key := "%d:%d:%s:%d:%d:%d:%d:%d:%d:%d" % [
		enemies.get_instance_id(), primary_pos, expected_primary_id,
		int(pre["hp"]), int(pre["block"]),
		int(live_primary["hp"]), int(live_primary["block"]),
		damage, expected_block_absorbed, expected_hp_loss,
	]
	var primary_slot_key := "%d:%d" % [enemies.get_instance_id(), primary_pos]
	if _echo_transitions.get(primary_slot_key, "") == transition_key:
		return _echo_failure("echo_cannot_reecho")
	if _consumed_transitions.has(transition_key):
		return _echo_failure("duplicate_receipt")

	var live_partner: Dictionary = enemies.get_enemy(partner_pos)
	if live_partner.is_empty() or live_partner.get("position") != partner_pos:
		return _echo_failure("invalid_partner")
	if live_partner.get("id") != expected_partner_id:
		return _echo_failure("partner_identity_mismatch")

	var primary_hp_loss: int = int(receipt["hp_loss"])
	var partner_hp_before: int = int(live_partner["hp"])
	var partner_block_before: int = int(live_partner["block"])

	if enemies.is_slain(partner_pos) or partner_hp_before <= 0:
		_record_consumed(receipt, receipt_id, transition_key, primary_slot_key,
			damage > 0 or expected_block_absorbed > 0 or expected_hp_loss > 0)
		return _echo_inert(link, primary_pos, expected_primary_id, partner_pos,
			expected_partner_id, primary_hp_loss, partner_hp_before, partner_block_before,
			"partner_slain")

	if primary_hp_loss <= 0:
		_record_consumed(receipt, receipt_id, transition_key, primary_slot_key,
			damage > 0 or expected_block_absorbed > 0 or expected_hp_loss > 0)
		return _echo_inert(link, primary_pos, expected_primary_id, partner_pos,
			expected_partner_id, primary_hp_loss, partner_hp_before, partner_block_before,
			"no_hp_loss")

	var echo_damage: int = quote_echo_damage(primary_hp_loss, SHARE_PERCENT)
	if echo_damage <= 0:
		_record_consumed(receipt, receipt_id, transition_key, primary_slot_key,
			damage > 0 or expected_block_absorbed > 0 or expected_hp_loss > 0)
		return _echo_inert(link, primary_pos, expected_primary_id, partner_pos,
			expected_partner_id, primary_hp_loss, partner_hp_before, partner_block_before,
			"zero_echo")

	if not enemies.apply_damage(partner_pos, echo_damage):
		return _echo_failure("partner_damage_rejected")

	_record_consumed(receipt, receipt_id, transition_key, primary_slot_key, true)

	var partner_after: Dictionary = enemies.get_enemy(partner_pos)
	var partner_block_after: int = int(partner_after["block"])
	var partner_hp_after: int = int(partner_after["hp"])
	var echo_block_absorbed: int = partner_block_before - partner_block_after
	var echo_hp_loss: int = partner_hp_before - partner_hp_after

	var partner_slot_key := "%d:%d" % [enemies.get_instance_id(), partner_pos]
	var partner_echo_key := "%d:%d:%s:%d:%d:%d:%d:%d:%d:%d" % [
		enemies.get_instance_id(), partner_pos, expected_partner_id,
		partner_hp_before, partner_block_before,
		partner_hp_after, partner_block_after,
		echo_damage, echo_block_absorbed, echo_hp_loss,
	]
	_echo_transitions[partner_slot_key] = partner_echo_key

	return {
		"ok": true,
		"applied": true,
		"reason": "echo_applied",
		"card_id": str(link["card_id"]),
		"share_percent": SHARE_PERCENT,
		"primary_position": primary_pos,
		"primary_id": expected_primary_id,
		"partner_position": partner_pos,
		"partner_id": expected_partner_id,
		"primary_hp_loss": primary_hp_loss,
		"echo_damage": echo_damage,
		"block_absorbed": echo_block_absorbed,
		"hp_loss": echo_hp_loss,
		"partner_block_before": partner_block_before,
		"partner_block_after": partner_block_after,
		"partner_hp_before": partner_hp_before,
		"partner_hp_after": partner_hp_after,
	}


## Alias for resolve_confirmed_hit_echo.
func apply_confirmed_hit_echo(enemies: CombatEnemies, pair_link: Variant,
		primary_position: Variant, pre_hit_primary: Variant = null,
		primary_receipt: Variant = null, receipt_id: Variant = null) -> Dictionary:
	return resolve_confirmed_hit_echo(enemies, pair_link, primary_position,
		pre_hit_primary, primary_receipt, receipt_id)


func _record_consumed(receipt: Dictionary, receipt_id: Variant,
		transition_key: String, primary_slot_key: String,
		has_state_change: bool) -> void:
	_consumed_receipts.append(receipt)
	if receipt_id != null:
		_consumed_receipt_ids[str(receipt_id)] = true
	if has_state_change:
		_consumed_transitions[transition_key] = true
	_echo_transitions.erase(primary_slot_key)


func _resolve_card_input(card: Variant) -> Dictionary:
	if typeof(card) == TYPE_STRING:
		return get_tether_definition(card)
	if typeof(card) == TYPE_DICTIONARY:
		if not is_authentic_definition(card):
			return {}
		return (card as Dictionary).duplicate(true)
	return {}


func _catalog_definition(card_id: String) -> Dictionary:
	var spec: Dictionary = CARDS.get(card_id, {})
	var source: String = str(spec.get("catalog", ""))
	if source == "starter":
		return V3SeamstressStarterCards.new().get_definition(card_id)
	if source == "pool":
		return V3SeamstressPoolCards.new().get_definition(card_id)
	return {}


func _extract_pair_link(pair_link: Variant) -> Dictionary:
	if typeof(pair_link) != TYPE_DICTIONARY:
		return _link_refusal("invalid_pair_link")
	var raw: Dictionary = pair_link
	if raw.is_empty():
		return _link_refusal("invalid_pair_link")
	for key in raw:
		if typeof(key) != TYPE_STRING or not ALLOWED_LINK_KEYS.has(key):
			return _link_refusal("invalid_pair_link")
	if raw.has("ok") and (typeof(raw["ok"]) != TYPE_BOOL or not bool(raw["ok"])):
		return _link_refusal("invalid_pair_link")
	if raw.has("reason") and typeof(raw["reason"]) != TYPE_STRING:
		return _link_refusal("invalid_pair_link")

	var def_candidate: Variant = null
	var def_keys_present := 0
	for def_key in ["card_definition", "definition", "card"]:
		if raw.has(def_key):
			def_keys_present += 1
			def_candidate = raw[def_key]
	if def_keys_present != 1 or not is_authentic_definition(def_candidate):
		return _link_refusal("invalid_card_definition")
	var definition: Dictionary = (def_candidate as Dictionary).duplicate(true)
	var card_id: String = str(definition["id"])
	if raw.has("card_id"):
		if typeof(raw["card_id"]) != TYPE_STRING or raw["card_id"] != card_id:
			return _link_refusal("invalid_card_definition")
	if raw.has("share_percent"):
		if typeof(raw["share_percent"]) != TYPE_INT or int(raw["share_percent"]) != SHARE_PERCENT:
			return _link_refusal("invalid_share_percent")

	var first_pos_v: Variant = raw.get("first_position")
	var second_pos_v: Variant = raw.get("second_position")
	if raw.has("positions"):
		if typeof(raw["positions"]) != TYPE_ARRAY or (raw["positions"] as Array).size() != 2:
			return _link_refusal("invalid_positions")
		var pos_arr: Array = raw["positions"]
		if first_pos_v == null and second_pos_v == null:
			first_pos_v = pos_arr[0]
			second_pos_v = pos_arr[1]
		elif not _same_value(pos_arr, [first_pos_v, second_pos_v]):
			return _link_refusal("invalid_positions")
	if typeof(first_pos_v) != TYPE_INT or typeof(second_pos_v) != TYPE_INT:
		return _link_refusal("invalid_positions")
	var first_pos: int = first_pos_v
	var second_pos: int = second_pos_v
	if not TO_POSITIONS.has(first_pos) or not TO_POSITIONS.has(second_pos):
		return _link_refusal("position_out_of_range")
	if first_pos == second_pos:
		return _link_refusal("duplicate_target")

	var first_id_v: Variant = raw.get("first_id")
	var second_id_v: Variant = raw.get("second_id")
	if raw.has("enemy_ids"):
		if typeof(raw["enemy_ids"]) != TYPE_DICTIONARY or (raw["enemy_ids"] as Dictionary).size() != 2:
			return _link_refusal("invalid_enemy_ids")
		var id_map: Dictionary = raw["enemy_ids"]
		if not id_map.has(first_pos) or not id_map.has(second_pos):
			return _link_refusal("invalid_enemy_ids")
		if first_id_v == null and second_id_v == null:
			first_id_v = id_map[first_pos]
			second_id_v = id_map[second_pos]
		elif not _same_value(id_map, {first_pos: first_id_v, second_pos: second_id_v}):
			return _link_refusal("invalid_enemy_ids")
	if typeof(first_id_v) != TYPE_STRING or typeof(second_id_v) != TYPE_STRING:
		return _link_refusal("invalid_enemy_ids")
	var first_id: String = first_id_v
	var second_id: String = second_id_v
	if first_id.is_empty() or second_id.is_empty() or first_id == second_id:
		return _link_refusal("invalid_enemy_ids")

	return {
		"ok": true,
		"card_id": card_id,
		"card_definition": definition,
		"share_percent": SHARE_PERCENT,
		"first_position": first_pos,
		"second_position": second_pos,
		"first_id": first_id,
		"second_id": second_id,
	}


func _valid_enemy_roster(enemies: Variant) -> bool:
	if enemies == null or not (enemies is CombatEnemies):
		return false
	var roster_obj: CombatEnemies = enemies
	if not roster_obj.is_valid():
		return false
	var records: Array[Dictionary] = roster_obj.get_enemies()
	if records.is_empty() or records.size() > CombatEnemies.MAX_ENEMIES:
		return false
	var seen_ids: Array[String] = []
	for index in range(records.size()):
		var actor: Dictionary = records[index]
		var id: Variant = actor.get("id")
		var pos: Variant = actor.get("position")
		var max_hp: Variant = actor.get("max_hp")
		var hp: Variant = actor.get("hp")
		var block: Variant = actor.get("block")
		if typeof(id) != TYPE_STRING or (id as String).is_empty() or seen_ids.has(id):
			return false
		if typeof(pos) != TYPE_INT or int(pos) != index + 1:
			return false
		if typeof(max_hp) != TYPE_INT or int(max_hp) <= 0:
			return false
		if typeof(hp) != TYPE_INT or int(hp) < 0 or int(hp) > int(max_hp):
			return false
		if typeof(block) != TYPE_INT or int(block) < 0:
			return false
		if not CombatEnemies.valid_revive_flags(actor) or not CombatEnemies.valid_split_flags(actor):
			return false
		seen_ids.append(id)
	return true


func _valid_pre_hit_enemy(pre: Dictionary, expected_position: int, expected_id: String) -> bool:
	var id: Variant = pre.get("id")
	var pos: Variant = pre.get("position")
	var max_hp: Variant = pre.get("max_hp")
	var hp: Variant = pre.get("hp")
	var block: Variant = pre.get("block")
	if typeof(id) != TYPE_STRING or (id as String) != expected_id:
		return false
	if typeof(pos) != TYPE_INT or int(pos) != expected_position:
		return false
	if typeof(max_hp) != TYPE_INT or int(max_hp) <= 0:
		return false
	if typeof(hp) != TYPE_INT or int(hp) <= 0 or int(hp) > int(max_hp):
		return false
	if typeof(block) != TYPE_INT or int(block) < 0:
		return false
	if not CombatEnemies.valid_revive_flags(pre) or not CombatEnemies.valid_split_flags(pre):
		return false
	return true


func _valid_primary_receipt(receipt: Dictionary) -> bool:
	if receipt.size() != RECEIPT_KEYS.size():
		return false
	for key: String in RECEIPT_KEYS:
		if not receipt.has(key):
			return false
	if typeof(receipt["ok"]) != TYPE_BOOL:
		return false
	for key: String in ["damage", "block_absorbed", "hp_loss"]:
		if typeof(receipt[key]) != TYPE_INT or int(receipt[key]) < 0:
			return false
	return true


func _same_value(actual: Variant, expected: Variant) -> bool:
	if typeof(actual) != typeof(expected):
		return false
	if typeof(expected) == TYPE_DICTIONARY:
		var actual_dict: Dictionary = actual
		var expected_dict: Dictionary = expected
		if actual_dict.size() != expected_dict.size():
			return false
		for key in expected_dict:
			if not actual_dict.has(key) or not _same_value(actual_dict[key], expected_dict[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		var actual_arr: Array = actual
		var expected_arr: Array = expected
		if actual_arr.size() != expected_arr.size():
			return false
		for index in range(expected_arr.size()):
			if not _same_value(actual_arr[index], expected_arr[index]):
				return false
		return true
	return actual == expected


func _link_refusal(reason: String) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
	}


func _echo_inert(link: Dictionary, primary_pos: int, primary_id: String,
		partner_pos: int, partner_id: String, primary_hp_loss: int,
		partner_hp: int, partner_block: int, reason: String) -> Dictionary:
	return {
		"ok": true,
		"applied": false,
		"reason": reason,
		"card_id": str(link["card_id"]),
		"share_percent": SHARE_PERCENT,
		"primary_position": primary_pos,
		"primary_id": primary_id,
		"partner_position": partner_pos,
		"partner_id": partner_id,
		"primary_hp_loss": primary_hp_loss,
		"echo_damage": 0,
		"block_absorbed": 0,
		"hp_loss": 0,
		"partner_block_before": partner_block,
		"partner_block_after": partner_block,
		"partner_hp_before": partner_hp,
		"partner_hp_after": partner_hp,
	}


func _echo_failure(reason: String) -> Dictionary:
	return {
		"ok": false,
		"applied": false,
		"reason": reason,
		"echo_damage": 0,
		"block_absorbed": 0,
		"hp_loss": 0,
	}
