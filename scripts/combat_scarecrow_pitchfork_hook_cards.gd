class_name CombatScarecrowPitchforkHookCards
extends RefCounted
## V3-1 rules-only preview and paid receipt for the Scarecrow's two "Pitchfork Hook" printings.
##
## Pitchfork Hook (uncommon pool) and Pitchfork Hook+ print two energy, a single enemy target in
## slot 2 or 3 reached from hero seat 1 or 2, one strike of 7 (or 10) and `pull_forward: 1`. The
## look is the burlap-sack Scarecrow hooking a foe with the pitchfork and dragging it one step
## toward the front line. One play therefore resolves ONE strike through the existing status rules
## and then proposes moving that SAME surviving enemy exactly one slot forward (2 -> 1 or 3 -> 2).
##
## The catalogs stay authoritative. The caller supplies only a held card ID and a target slot,
## never a card record, a damage magnitude, an owner, a pull distance or a replacement actor. Each
## ID is authenticated against its complete exact Scarecrow pool record (recursive, type-exact
## equality) before anything is proposed, so a rewritten magnitude, a free cost, a widened seat
## line, an extra effect or a broken base/"+" link is refused instead of resolving as this card.
##
## `enemy_slots` is a DETACHED explicit mapping for enemy slots 1-4 whose vacant slots are absent
## or empty, exactly like scripts/combat_yarn_ranger_reel_cards.gd. It is a preview/receipt over a
## copy, not an authoritative CombatEnemies mutation: a possible fourth bystander after a summon is
## preserved byte-for-byte, and only the chosen foe is ever copied forward. Slot 4 keeps this
## service's own literal four-slot domain and deliberately does NOT widen the battle-wide
## CombatEnemies.MAX_ENEMIES (which stays 3).
##
## Damage uses CombatStatuses.adjusted_attack_damage on the printed positive base with the real
## attacker/defender status records, so Weak, Exposed and Tangled keep their existing floor and
## Tangled's flat +2. The strike then spends enemy Block before HP, exactly like the other paid
## single-hit resolvers. A Tangled target is still pulled: the pull is movement by the HERO side,
## and V3-2 Tangled only forbids the afflicted actor's own side moving it (the Yarn Ranger Reel
## contract). No status is added, consumed or aged by this card.
##
## A lethal hit retains the defeated actor in its original slot at 0 HP: the helper never moves a
## corpse and never duplicates a living identity. `propose_hook` never charges energy, discards a
## card, mutates the party or the caller's snapshot, consumes RNG or alters any core combat state.
## `play_held_hook` is the paid entry point for a mounted hand: it authenticates the printing,
## preflights the WHOLE request against the REAL CombatDeck, the REAL CombatParty and the detached
## proposal, and only then spends the printed two energy and discards exactly one held copy. Both
## receipts stay detached: neither places the moved actor into the live CombatEnemies roster, and
## the caller must apply the proposed map explicitly. Registering these IDs in the live hand, card
## admission and enemy-target choice remains a separate follow-on wiring task, so nothing here
## claims live playability, mounted UI, reward admission or a true enemy-roster mutation.

const OWNER := "scarecrow"
const FROM_POSITIONS := [1, 2]
const TO_POSITIONS := [2, 3]
const TARGET_KIND := "enemy_single"
const PULL_FORWARD := 1
## This preview is a four-slot contract: a Hook reads and proposes enemy slots 1-4, matching the
## V3-2 floor bands that place an enemy group of 2-4 in the battle, so a bystander behind the
## hook's two-slot target line is preserved untouched. It keeps its OWN literal domain constant
## and deliberately does NOT derive it from CombatEnemies.MAX_ENEMIES.
const MAX_HOOK_SLOTS := 4

const _POOL_CATALOG := preload("res://data/cards/scarecrow_pool_cards.gd")

## The two authentic printings. `record` is the complete expected pool definition (top-level
## metadata, exact key set and nested values); `cost` and `damage` are the printed numbers the
## proposal must obey. Both live in the Scarecrow reward pool; neither is a starter.
const CARDS := {
	"scarecrow_pitchfork_hook": {
		"cost": 2,
		"damage": 7,
		"record": {
			"id": "scarecrow_pitchfork_hook",
			"display_name": "Pitchfork Hook",
			"owner": "scarecrow",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"damage": 7, "pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/scarecrow_pitchfork_hook.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": true,
			"upgrade_id": "scarecrow_pitchfork_hook_plus",
		},
	},
	"scarecrow_pitchfork_hook_plus": {
		"cost": 2,
		"damage": 10,
		"record": {
			"id": "scarecrow_pitchfork_hook_plus",
			"display_name": "Pitchfork Hook+",
			"owner": "scarecrow",
			"cost": 2,
			"from_positions": [1, 2],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"damage": 10, "pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/scarecrow_pitchfork_hook.png",
			"starting_copies": 0,
			"rarity": "uncommon",
			"reward_eligible": false,
			"upgrade_of": "scarecrow_pitchfork_hook",
		},
	},
}

var _statuses := CombatStatuses.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, fully authenticated Hook definition from the Scarecrow pool, or {} for anything
## else. Unrelated cards, forged spellings and tampered records all resolve to {}.
## `definition_lookup` is an optional testable catalog seam: when it is null the real Scarecrow
## pool is read, and any record it returns is authenticated exactly like the real one.
static func hook_definition(card_id: Variant, definition_lookup: Variant = null) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Variant = _lookup(id, definition_lookup)
	if not is_authentic_definition(definition, id):
		return {}
	return (definition as Dictionary).duplicate(true)


## Exact-record authentication: the caller's (or the catalog's) record must equal the authored
## Hook record with identical types at every level, so a changed cost, a pull of two slots, an
## extra/missing metadata key, a stringified number, an unknown effect or a foreign upgrade link
## all fail closed.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Variant = CARDS.get(id, {})
	if typeof(card) != TYPE_DICTIONARY or (card as Dictionary).is_empty():
		return false
	return _values_equal(definition, (card as Dictionary)["record"])


## The single rules-only proposal: one printed strike on a detached target, then one-slot forward
## movement for that same surviving identity. `party` is the authoritative hero roster (read
## through get_heroes(), never mutated); `enemy_slots` is the detached slot snapshot described
## above. Returns {"ok": true, reason "proposed", printed cost/damage, owner and slot receipt, and
## a detached "slots" map} or {"ok": false, reason ...} with no proposed roster. The published map
## always carries exactly the integer keys 1-4 (a vacant slot maps to an empty dictionary), and
## only the chosen foe is ever damaged or moved.
func propose_hook(card_id: Variant, party: CombatParty, target_position: Variant,
		enemy_slots: Variant, definition_lookup: Variant = null) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The card is authenticated from the Scarecrow pool (or the authenticated seam) before any of
	# the battle state below is inspected: an unverified caller descriptor is never authority.
	if not is_authentic_definition(_lookup(id, definition_lookup), id):
		return _refusal("catalog_mismatch")

	if party == null:
		return _refusal("invalid_request")
	if not party.is_valid():
		return _refusal("invalid_party")

	var owner_position: int = _owner_position(party)
	if owner_position < 0:
		return _refusal(_owner_reason(owner_position))

	if typeof(target_position) != TYPE_INT:
		return _refusal("invalid_target")
	var target: int = target_position
	if target < 1 or target > MAX_HOOK_SLOTS:
		return _refusal("invalid_target")
	if not TO_POSITIONS.has(target):
		return _refusal("target_out_of_reach")
	var destination: int = target - PULL_FORWARD

	var occupied: Dictionary = _validate_slots(enemy_slots)
	if not occupied.get("ok", false):
		return _refusal(str(occupied.get("reason", "invalid_slots")))
	var records: Dictionary = occupied["slots"]
	if not records.has(target):
		return _refusal("target_missing")
	var struck: Dictionary = records[target]
	if int(struck["hp"]) == 0:
		return _refusal("target_downed")
	# A pull never displaces an occupied neighbour, living or otherwise: only a truly vacant slot
	# (absent/empty) may receive the enemy.
	if records.has(destination):
		return _refusal("destination_occupied")

	# CombatStatuses owns the Weak/Exposed/Tangled rounding: integer floor once, then a positive-
	# base Tangled defender adds its flat +2. The status maps are read, never consumed or aged.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_statuses: Dictionary = _statuses_of(heroes[owner_position - 1])
	var target_statuses: Dictionary = _statuses_of(struck)
	var base_damage: int = int(card["damage"])
	var damage: int = _statuses.adjusted_attack_damage(base_damage, owner_statuses,
		target_statuses)
	if damage <= 0:
		return _refusal("damage_overflow")

	# The strike lands on the detached copy only: enemy Block absorbs before HP.
	var hp_before: int = int(struck["hp"])
	var block_before: int = int(struck["block"])
	var absorbed: int = mini(block_before, damage)
	var hp_after: int = maxi(0, hp_before - (damage - absorbed))
	struck["block"] = block_before - absorbed
	struck["hp"] = hp_after
	var survived: bool = hp_after > 0

	var proposed: Dictionary = {}
	for slot in range(1, MAX_HOOK_SLOTS + 1):
		proposed[slot] = {}
	for slot: int in records:
		if slot == target:
			continue
		proposed[slot] = records[slot]
	if survived:
		# The canonical slot field follows the foe; every other copied field is preserved verbatim.
		struck["position"] = destination
		proposed[destination] = struck
	else:
		# A lethal hook leaves the defeated actor in its own slot: no corpse is dragged forward and
		# no living duplicate is created.
		proposed[target] = struck
	return {
		"ok": true,
		"reason": "proposed",
		"card_id": id,
		"catalog": "pool",
		"cost": int(card["cost"]),
		"owner_position": owner_position,
		"source_position": target,
		"target_position": target,
		"destination_position": destination,
		"pull_forward": PULL_FORWARD,
		"base_damage": base_damage,
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"hp_loss": hp_before - hp_after,
		"block_before": block_before,
		"block_after": block_before - absorbed,
		"block_absorbed": absorbed,
		"moved": survived,
		"slain": not survived,
		"slots": proposed,
	}


## The paid held-card entry point for one authentic Hook printing. The complete request is
## preflighted first: the ID is authenticated against the Scarecrow pool (or the authenticated
## seam), the shared deck is a real active turn that genuinely holds the card and can afford it,
## and the existing `propose_hook` accepts the party, owner seat, target and detached snapshot.
## Only then does it spend the printed energy once and discard exactly one held copy once, using
## the deck's standard operations. A refusal is a pure no-op on the deck, party, snapshot and RNG.
##
## The success receipt is still detached: it carries the card ID, paid cost, owner/source/
## destination seats, the actual damage/Block/HP transition and the proposed four-slot map, but it
## never places the moved actor into a live CombatEnemies roster. The caller applies that map
## explicitly later.
func play_held_hook(deck: CombatDeck, party: CombatParty, card_id: Variant,
		target_position: Variant, enemy_slots: Variant,
		definition_lookup: Variant = null) -> Dictionary:
	if not is_supported_card(card_id):
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS[id]
	if not is_authentic_definition(_lookup(id, definition_lookup), id):
		return _refusal("catalog_mismatch")
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null:
		return _refusal("invalid_deck")
	if not deck.turn_active:
		return _refusal("inactive_turn")
	# The deck must genuinely hold the chosen copy; exactly one copy is paid and discarded below.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(card["cost"])
	if deck.energy < cost:
		return _refusal("insufficient_energy")
	# The existing proposal is the full rules preflight: valid roster, living unique owner in a
	# printed seat, authenticated catalog, printed target line, living target, truly vacant
	# destination and a well-formed four-slot snapshot. Its detached map is what the receipt
	# publishes.
	var proposal: Dictionary = propose_hook(id, party, target_position, enemy_slots,
		definition_lookup)
	if not proposal.get("ok", false):
		return _refusal(str(proposal.get("reason", "invalid_request")))
	# Every operation below is guaranteed by the complete preflight above; keep the defensive
	# returns so an unexpected model change still fails closed. Nothing here draws a card, touches
	# the run RNG or mutates the caller's snapshot or party.
	var energy_before: int = deck.energy
	var copies_before: int = deck.hand.count(id)
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"catalog": "pool",
		"cost": cost,
		"energy_spent": cost,
		"energy_before": energy_before,
		"energy_after": deck.energy,
		"hand_copies_before": copies_before,
		"hand_copies_after": deck.hand.count(id),
		"owner_position": int(proposal["owner_position"]),
		"source_position": int(proposal["source_position"]),
		"target_position": int(proposal["target_position"]),
		"destination_position": int(proposal["destination_position"]),
		"pull_forward": int(proposal["pull_forward"]),
		"base_damage": int(proposal["base_damage"]),
		"damage": int(proposal["damage"]),
		"hp_before": int(proposal["hp_before"]),
		"hp_after": int(proposal["hp_after"]),
		"hp_loss": int(proposal["hp_loss"]),
		"block_before": int(proposal["block_before"]),
		"block_after": int(proposal["block_after"]),
		"block_absorbed": int(proposal["block_absorbed"]),
		"moved": bool(proposal["moved"]),
		"slain": bool(proposal["slain"]),
		"slots": proposal["slots"],
	}


## The live owner seat, or a negative code for the reason the Scarecrow is unusable:
## -1 malformed roster, -2 missing, -3 downed, -4 seated outside the printed FROM line.
static func _owner_position(party: CombatParty) -> int:
	var heroes: Array[Dictionary] = party.get_heroes()
	if heroes.size() != CombatParty.PARTY_SIZE:
		return -1
	var seen_ids: Array[String] = []
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id: Variant = hero.get("id")
		var position: Variant = hero.get("position")
		var hp: Variant = hero.get("hp")
		var max_hp: Variant = hero.get("max_hp")
		var block: Variant = hero.get("block")
		if typeof(hero_id) != TYPE_STRING or (hero_id as String).is_empty() \
				or seen_ids.has(hero_id):
			return -1
		if typeof(position) != TYPE_INT or position != index + 1:
			return -1
		if typeof(max_hp) != TYPE_INT or max_hp <= 0:
			return -1
		if typeof(hp) != TYPE_INT or hp < 0 or hp > max_hp:
			return -1
		if typeof(block) != TYPE_INT or block < 0 or block > CombatParty.MAX_INT:
			return -1
		if hero.has("statuses"):
			var hero_statuses: Variant = hero["statuses"]
			if typeof(hero_statuses) != TYPE_DICTIONARY or not _statuses_valid(hero_statuses):
				return -1
		seen_ids.append(hero_id as String)
		if hero_id == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return -2
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return -3
	if not FROM_POSITIONS.has(owner_position):
		return -4
	return owner_position


static func _owner_reason(code: int) -> String:
	match code:
		-1:
			return "invalid_party"
		-2:
			return "owner_missing"
		-3:
			return "owner_downed"
		_:
			return "owner_illegal_position"


## Validate the complete detached slot snapshot before anything is proposed. Returns
## {"ok": true, "slots": {slot: detached record}} for the occupied slots only, or a refusal.
## Absent and empty slots are vacant, never a displaced or slain record.
static func _validate_slots(enemy_slots: Variant) -> Dictionary:
	if typeof(enemy_slots) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "invalid_slots"}
	var raw: Dictionary = enemy_slots
	var occupied: Dictionary = {}
	var seen_ids: Array[String] = []
	for key: Variant in raw:
		if typeof(key) != TYPE_INT:
			return {"ok": false, "reason": "invalid_slots"}
		var slot: int = key
		if slot < 1 or slot > MAX_HOOK_SLOTS:
			return {"ok": false, "reason": "invalid_slots"}
		var record: Variant = raw[key]
		if typeof(record) != TYPE_DICTIONARY:
			return {"ok": false, "reason": "invalid_slots"}
		if (record as Dictionary).is_empty():
			continue
		if not _slot_record_valid(record, slot):
			return {"ok": false, "reason": "invalid_slots"}
		var enemy_id: String = (record as Dictionary)["id"]
		if seen_ids.has(enemy_id):
			return {"ok": false, "reason": "invalid_slots"}
		seen_ids.append(enemy_id)
		occupied[slot] = (record as Dictionary).duplicate(true)
	return {"ok": true, "slots": occupied}


## The canonical enemy-actor shape (same fields and types CombatEnemies insists on) plus this
## snapshot's own rule: a record lives in the slot it names. Extra authored fields are allowed and
## preserved verbatim; nothing is coerced.
static func _slot_record_valid(record: Variant, slot: int) -> bool:
	if typeof(record) != TYPE_DICTIONARY:
		return false
	var actor: Dictionary = record
	for field in ["id", "position", "hp", "max_hp", "block"]:
		if not actor.has(field):
			return false
	var enemy_id: Variant = actor["id"]
	var position: Variant = actor["position"]
	var hp: Variant = actor["hp"]
	var max_hp: Variant = actor["max_hp"]
	var block: Variant = actor["block"]
	if typeof(enemy_id) != TYPE_STRING or (enemy_id as String).is_empty():
		return false
	if typeof(position) != TYPE_INT or position != slot:
		return false
	if typeof(max_hp) != TYPE_INT or max_hp <= 0:
		return false
	if typeof(hp) != TYPE_INT or hp < 0 or hp > max_hp:
		return false
	if typeof(block) != TYPE_INT or block < 0 or block > CombatEnemies.MAX_INT:
		return false
	if actor.has("statuses"):
		var statuses: Variant = actor["statuses"]
		if typeof(statuses) != TYPE_DICTIONARY or not _statuses_valid(statuses):
			return false
	return true


## The canonical status-map schema from CombatStatuses: N-turn counters are non-negative
## integers, Dodge/Blind are the one-shot tokens 0/1, and Fear is the literal boolean true. Any
## other key or type is malformed rather than silently ignored.
static func _statuses_valid(statuses: Variant) -> bool:
	if typeof(statuses) != TYPE_DICTIONARY:
		return false
	var map: Dictionary = statuses
	for name: Variant in map:
		if typeof(name) != TYPE_STRING:
			return false
		var value: Variant = map[name]
		if name == "dodge_next_attack" or name == "blind_next_attack":
			if typeof(value) != TYPE_INT or (value != 0 and value != 1):
				return false
			continue
		if name == "cannot_buff_next_turn":
			if typeof(value) != TYPE_BOOL or value != true:
				return false
			continue
		if not ["bleed", "weak", "exposed", "tangled", "riposte"].has(name):
			return false
		if typeof(value) != TYPE_INT or value < 0:
			return false
	return true


## The authoritative status dictionary stored on a validated actor record. An absent key means no
## active counters.
static func _statuses_of(record: Dictionary) -> Dictionary:
	var value: Variant = record.get("statuses", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value


## The catalog record for an authenticated ID: the real Scarecrow pool, or the caller's
## authenticated seam. A missing/invalid seam can never authenticate anything.
static func _lookup(card_id: String, definition_lookup: Variant) -> Variant:
	if definition_lookup == null:
		return _POOL_CATALOG.new().get_definition(card_id)
	if typeof(definition_lookup) != TYPE_CALLABLE:
		return null
	var lookup: Callable = definition_lookup
	if not lookup.is_valid():
		return null
	return lookup.call(card_id)


## Recursive, type-exact value equality (type first, then key set, then every nested value), so a
## handpicked subset or a coerced number can never pass for the authored record.
static func _values_equal(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	match typeof(left):
		TYPE_DICTIONARY:
			var a: Dictionary = left
			var b: Dictionary = right
			if a.size() != b.size():
				return false
			for key: Variant in a:
				if not b.has(key):
					return false
				if not _values_equal(a[key], b[key]):
					return false
			return true
		TYPE_ARRAY:
			var x: Array = left
			var y: Array = right
			if x.size() != y.size():
				return false
			for index in range(x.size()):
				if not _values_equal(x[index], y[index]):
					return false
			return true
		_:
			return left == right


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
