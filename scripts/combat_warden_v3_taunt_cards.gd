class_name CombatWardenV3TauntCards
extends RefCounted
## Scene-free paid resolver for the Warden's iron challenges (V3-1).
##
## Iron Challenge is a v3 starter card and Iron Taunt a v3 reward-pool card; both print their
## own Block plus `taunt_next_enemy_turn`, so the squat shield-bearer plants himself and draws
## the NEXT whole enemy turn's ordinary attacks onto his pot helmet. The two catalogs stay
## authoritative: this service authenticates the exact held ID and its printed metadata, then
## resolves against the real deck and party models.
##
## The service keeps one detached, battle-scoped pending Taunt. A later enemy-phase caller asks
## `project_attack_target` (or `project_enemy_action`) for EVERY otherwise valid targetable
## attack in that next enemy turn; the projection reads the Warden's actual live seat each time
## and never consumes the Taunt. `complete_enemy_turn` is the single explicit expiry, called
## once after the whole enemy turn has finished, so the following turn is unaffected and a
## second legal Taunt card only refreshes the same upcoming phase.
##
## Projection changes only which seat a targetable attack aims at: damage, hits, ownership,
## statuses and every non-targeted action (block, buff, debuff, shove, snip_block, ...) stay
## exactly as announced. The future actual hit executor keeps owning Guard/Dodge/Blind and the
## real damage. Nothing here uses the run RNG, draws, shuffles or invents status counters.
##
## This is a callable combat rules slice only. It does not admit these IDs into a live party
## deck, the reward pool, the mounted hand or any app flow; that wiring is a later task.

const OWNER := "warden"
const TARGET_KIND := "self"
const FROM_POSITIONS := [1]
const TO_POSITIONS := []
const WARDEN_SEAT := 1

## The four authentic IDs, the catalog that owns each one, and the exact printed line it must
## still carry. A base printing and its "+" differ only in authored Block magnitude.
const CARDS := {
	"warden_v3_iron_challenge": {
		"catalog": "starter",
		"cost": 1,
		"block": 3,
		"target_kind": "self",
		"from_positions": [1],
		"to_positions": [],
		"effects": {"block": 3, "taunt_next_enemy_turn": true},
		"starting_copies": 1,
		"reward_eligible": false,
		"rarity": "",
		"upgrade_id": "warden_v3_iron_challenge_plus",
		"upgrade_of": "",
	},
	"warden_v3_iron_challenge_plus": {
		"catalog": "starter",
		"cost": 1,
		"block": 5,
		"target_kind": "self",
		"from_positions": [1],
		"to_positions": [],
		"effects": {"block": 5, "taunt_next_enemy_turn": true},
		"starting_copies": 0,
		"reward_eligible": false,
		"rarity": "",
		"upgrade_id": "",
		"upgrade_of": "warden_v3_iron_challenge",
	},
	"warden_v3_iron_taunt": {
		"catalog": "pool",
		"cost": 1,
		"block": 4,
		"target_kind": "self",
		"from_positions": [1],
		"to_positions": [],
		"effects": {"block": 4, "taunt_next_enemy_turn": true},
		"starting_copies": 0,
		"reward_eligible": true,
		"rarity": "common",
		"upgrade_id": "warden_v3_iron_taunt_plus",
		"upgrade_of": "",
	},
	"warden_v3_iron_taunt_plus": {
		"catalog": "pool",
		"cost": 1,
		"block": 6,
		"target_kind": "self",
		"from_positions": [1],
		"to_positions": [],
		"effects": {"block": 6, "taunt_next_enemy_turn": true},
		"starting_copies": 0,
		"reward_eligible": false,
		"rarity": "common",
		"upgrade_id": "",
		"upgrade_of": "warden_v3_iron_taunt",
	},
	"warden_v3_shieldwall_chorus": {
		"catalog": "pool",
		"cost": 2,
		"block_all": 4,
		"target_kind": "party_all",
		"from_positions": [1, 2, 3],
		"to_positions": [],
		"effects": {"block_all": 4, "taunt_next_enemy_turn": true},
		"starting_copies": 0,
		"reward_eligible": true,
		"rarity": "uncommon",
		"upgrade_id": "warden_v3_shieldwall_chorus_plus",
		"upgrade_of": "",
	},
	"warden_v3_shieldwall_chorus_plus": {
		"catalog": "pool",
		"cost": 2,
		"block_all": 6,
		"target_kind": "party_all",
		"from_positions": [1, 2, 3],
		"to_positions": [],
		"effects": {"block_all": 6, "taunt_next_enemy_turn": true},
		"starting_copies": 0,
		"reward_eligible": false,
		"rarity": "uncommon",
		"upgrade_id": "",
		"upgrade_of": "warden_v3_shieldwall_chorus",
	},
}

var _taunt_armed := false
var _taunt_card_id := ""


## The single paid transaction: authenticate, preflight every input, then charge 1 energy, discard
## exactly the held copy, add the authored Block to the Warden and arm one next-enemy-turn Taunt.
## `target_kind` must stay "self"; `target_position` may be omitted (0) to mean the Warden's own
## seat, and an explicit value must equal that seat. A rejection changes no deck, party, Taunt or
## RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_kind: String = "self", target_position: int = 0) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, card_id, target_kind, target_position)
	if not plan.get("ok", false):
		return _failure()
	# Every operation below is guaranteed by the complete preflight above: the turn is active,
	# the held ID is authentic and affordable, the Warden is the living unique hero at seat 1 and
	# the Block addition fits the party's capacity. Keep the defensive returns so an unexpected
	# model change still fails closed.
	if not deck.try_spend_energy(plan["cost"]):
		return _failure()

	var target_kind_plan: String = plan.get("target_kind", "self")
	if target_kind_plan == "self":
		if not party.gain_block(plan["owner_position"], plan["block"]):
			deck.combat_state.energy += plan["cost"]
			return _failure()
	elif target_kind_plan == "party_all":
		var recipients: Array[int] = plan.get("block_recipients", [])
		var amount: int = plan["block_all"]
		# Apply to each recipient; preflight guarantees no overflow.
		for pos in recipients:
			if not party.gain_block(pos, amount):
				# Defensive rollback of energy only; partial block should not occur.
				deck.combat_state.energy += plan["cost"]
				return _failure()
	else:
		deck.combat_state.energy += plan["cost"]
		return _failure()

	if not deck.discard_played(plan["card_id"]):
		# If discard fails, rollback energy. Block rollback is complex; rely on preflight.
		deck.combat_state.energy += plan["cost"]
		return _failure()
	# A second legal Taunt card this turn refreshes this same upcoming enemy phase; it never
	# stacks a second redirection or extends the armed state to another turn.
	_taunt_armed = true
	_taunt_card_id = plan["card_id"]

	if target_kind_plan == "self":
		var final_block: int = party.get_hero(plan["owner_position"]).get("block", 0)
		return {
			"ok": true,
			"card_id": plan["card_id"],
			"cost": plan["cost"],
			"owner_position": plan["owner_position"],
			"block_gained": plan["block"],
			"block": final_block,
			"energy": deck.energy,
			"taunt_armed": true,
		}
	elif target_kind_plan == "party_all":
		var recipient_final_blocks: Dictionary = {}
		for pos in plan.get("block_recipients", []):
			recipient_final_blocks[pos] = party.get_hero(pos).get("block", 0)
		var first_recipient: int = plan.get("block_recipients", [0])[0]
		var first_final: int = recipient_final_blocks.get(first_recipient, 0)
		return {
			"ok": true,
			"card_id": plan["card_id"],
			"cost": plan["cost"],
			"owner_position": plan["owner_position"],
			"block_all": plan["block_all"],
			"block": first_final,
			"energy": deck.energy,
			"taunt_armed": true,
		}
	return _failure()


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## True only when the live catalog that owns this ID still carries the exact authored record.
## Read-only; a rewritten, relocated or forged record authenticates as nothing.
func is_authentic_card(card_id: Variant) -> bool:
	if not is_supported_card(card_id):
		return false
	var id: String = card_id
	return _authentic(_catalog_definition(id), id, CARDS[id])


## True while one next-enemy-turn Taunt waits for its complete enemy turn.
func has_pending_taunt() -> bool:
	return _taunt_armed


## The most recent legal Taunt card that armed the pending phase, or "" when none is armed.
func get_pending_taunt_card_id() -> String:
	return _taunt_card_id


## Read-only per-attack projection for the next enemy turn. `announced_target_position` is the
## enemy phase's originally chosen hero seat; `actual_target_position` is the seat the attack
## should really hit. A living Warden redirects every otherwise valid targetable attack, an
## attack already aimed at him stays there, and an invalid or already-downed announced target is
## never projected into a legal one. A missing or torn Warden preserves the announced target.
## Nothing is consumed or mutated here.
func project_attack_target(party: CombatParty, target_position: int) -> Dictionary:
	var failure := {"ok": false, "eligible": false, "redirected": false,
		"announced_target_position": 0, "actual_target_position": 0}
	if party == null or not party.is_valid():
		return failure
	if target_position < 1 or target_position > CombatParty.PARTY_SIZE:
		return failure
	if party.is_downed(target_position):
		return {"ok": true, "eligible": false, "redirected": false,
			"announced_target_position": target_position,
			"actual_target_position": target_position}
	var warden_position: int = _living_warden_position(party)
	var redirect: bool = _taunt_armed and warden_position > 0 \
		and warden_position != target_position
	return {
		"ok": true,
		"eligible": true,
		"redirected": redirect,
		"announced_target_position": target_position,
		"actual_target_position": warden_position if redirect else target_position,
	}


## Detached projection of one whole announced enemy action. Only a `type: "attack"` action with
## an integer announced target participates in Taunt; every other action is returned as an
## independent, unchanged copy so buff, Block, summon and other non-targeted beats stay outside
## this contract. The caller's action dictionary is never rewritten.
func project_enemy_action(party: CombatParty, action: Variant) -> Dictionary:
	var detached: Dictionary = {}
	if typeof(action) == TYPE_DICTIONARY:
		detached = (action as Dictionary).duplicate(true)
	var failure := {"ok": false, "targetable": false, "redirected": false,
		"action": detached,
		"announced_target_position": 0, "actual_target_position": 0}
	if typeof(action) != TYPE_DICTIONARY or (action as Dictionary).is_empty():
		return failure
	var source: Dictionary = action
	if source.get("type") != "attack":
		return {"ok": true, "targetable": false, "redirected": false,
			"action": source.duplicate(true),
			"announced_target_position": 0, "actual_target_position": 0}
	var announced = source.get("target_position")
	if not announced is int:
		return failure
	var target: Dictionary = project_attack_target(party, announced)
	if not target.get("ok", false):
		return failure
	var projected: Dictionary = source.duplicate(true)
	projected["target_position"] = target["actual_target_position"]
	return {
		"ok": true,
		"targetable": true,
		"redirected": target["redirected"],
		"action": projected,
		"announced_target_position": target["announced_target_position"],
		"actual_target_position": target["actual_target_position"],
	}


## Explicit expiry: call once after the WHOLE next enemy turn has completed. Returns true only
## when a genuinely armed Taunt was consumed; a following enemy turn then expires nothing. This
## is the only state transition besides a successful play.
func complete_enemy_turn() -> bool:
	var was_armed: bool = _taunt_armed
	_taunt_armed = false
	_taunt_card_id = ""
	return was_armed


## Read-only preflight of the whole transaction. Returns a detached plan or a failure record.
func _prepare(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_kind: String, target_position: int) -> Dictionary:
	if deck == null or party == null:
		return _failure()
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _failure()
	if not party.is_valid() or party.is_defeated():
		return _failure()
	if typeof(card_id) != TYPE_STRING:
		return _failure()
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _failure()
	if not _authentic(_catalog_definition(id), id, card):
		return _failure()
	# The card must be genuinely held and affordable before any state changes.
	if not deck.hand.has(id):
		return _failure()
	var cost: int = card["cost"]
	if deck.energy < cost:
		return _failure()
	var card_target_kind: String = card.get("target_kind", "self")
	var allowed_from: Array[int] = card.get("from_positions", [1])
	if target_kind != card_target_kind:
		return _failure()

	# Verify the complete hero roster, then bind the unique Warden to its current slot.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var warden_count := 0
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _failure()
		if not position is int or position != index + 1:
			return _failure()
		if not hp is int or not max_hp is int or max_hp <= 0 or hp < 0 or hp > max_hp:
			return _failure()
		if not block is int or block < 0:
			return _failure()
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			warden_count += 1
			owner_position = index + 1
	if warden_count != 1:
		return _failure()
	if not allowed_from.has(owner_position):
		return _failure()
	if heroes[owner_position - 1]["hp"] == 0:
		return _failure()
	if card_target_kind == "self":
		if target_position != 0 and target_position != owner_position:
			return _failure()
	elif card_target_kind == "party_all":
		if target_position != 0:
			return _failure()
	else:
		return _failure()

	if card_target_kind == "self":
		var block_gain: int = card.get("block", -1)
		if int(card["effects"].get("block", -1)) != block_gain:
			return _failure()
		var current_block: int = heroes[owner_position - 1]["block"]
		if block_gain > CombatParty.MAX_INT - current_block:
			return _failure()
		return {
			"ok": true,
			"card_id": id,
			"cost": cost,
			"owner_position": owner_position,
			"block": block_gain,
			"current_block": current_block,
			"target_kind": "self",
			"block_recipients": [owner_position],
		}
	elif card_target_kind == "party_all":
		var block_all_amount: int = card.get("block_all", -1)
		if int(card["effects"].get("block_all", -1)) != block_all_amount:
			return _failure()
		var recipients: Array[int] = []
		var recipient_current_blocks: Dictionary = {}
		for index in range(CombatParty.PARTY_SIZE):
			var position = index + 1
			if heroes[index]["hp"] > 0:
				recipients.append(position)
				var current_block: int = heroes[index]["block"]
				recipient_current_blocks[position] = current_block
				if block_all_amount > CombatParty.MAX_INT - current_block:
					return _failure()
		# The Warden must be among the living recipients.
		if not recipients.has(owner_position):
			return _failure()
		return {
			"ok": true,
			"card_id": id,
			"cost": cost,
			"owner_position": owner_position,
			"block_all": block_all_amount,
			"current_blocks": recipient_current_blocks,
			"target_kind": "party_all",
			"block_recipients": recipients,
		}
	else:
		return _failure()


## Reads the exact authored record from the catalog that owns this ID (never the other hero
## catalogs) and returns a detached copy, or {} when the ID is not in that catalog.
func _catalog_definition(card_id: String) -> Dictionary:
	var card: Dictionary = CARDS.get(card_id, {})
	var source: Variant = card.get("catalog", "")
	if source == "starter":
		return V3WardenStarterCards.new().get_definition(card_id)
	if source == "pool":
		return V3WardenPoolCards.new().get_definition(card_id)
	return {}


## The record must still carry exactly the authored line, upgrade link and starter/reward
## identity, so a rewritten catalog (different Block, a dropped Taunt, another target line or a
## moved upgrade/copy claim) can never be paid for as this effect.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != card.get("target_kind", "self"):
		return false
	if definition.get("from_positions") != card.get("from_positions", [1]):
		return false
	if definition.get("to_positions") != card.get("to_positions", []):
		return false
	if definition.get("effects") != card["effects"]:
		return false
	if definition.get("starting_copies") != card["starting_copies"]:
		return false
	if definition.get("reward_eligible") != card["reward_eligible"]:
		return false
	if str(definition.get("upgrade_id", "")) != str(card["upgrade_id"]):
		return false
	if str(definition.get("upgrade_of", "")) != str(card["upgrade_of"]):
		return false
	return str(definition.get("rarity", "")) == str(card["rarity"])


## The actual living seat of the party's unique Warden, or 0 when he is missing, duplicated or
## torn. Re-read on every projection so an earlier beat's swap is respected.
static func _living_warden_position(party: CombatParty) -> int:
	if party == null or not party.is_valid():
		return 0
	var count := 0
	var position := 0
	for hero: Dictionary in party.get_heroes():
		if hero.get("id") != OWNER:
			continue
		count += 1
		var hero_position = hero.get("position")
		position = hero_position if hero_position is int else 0
	if count != 1 or position < 1 or position > CombatParty.PARTY_SIZE:
		return 0
	return 0 if party.is_downed(position) else position


func _failure() -> Dictionary:
	return {
		"ok": false,
		"card_id": "",
		"cost": 0,
		"owner_position": 0,
		"block_gained": 0,
		"block": 0,
		"energy": 0,
		"taunt_armed": false,
	}
