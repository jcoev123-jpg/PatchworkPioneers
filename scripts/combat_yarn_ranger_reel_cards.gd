class_name CombatYarnRangerReelCards
extends RefCounted
## V3-1 rules-only preview for the Yarn Ranger's two "Reel" pulls: the starter Reel Thread
## (and its "+") and the common-pool Reel In (and its "+").
##
## None of these four printings attacks, so the Yarn Ranger's "first attack each combat also
## applies Tangled 1" passive never fires here. Each printing pulls ONE chosen enemy exactly one
## slot forward (2 -> 1 or 3 -> 2) and never displaces an occupied neighbour: a pull is legal only
## into a truly vacant slot. Reel In then adds its printed Tangled (base 1, "+" 2) to the pulled
## foe. A pull is movement by the HERO side, so V3-2 Tangled on the target (its own side is not
## doing the moving) never prohibits it; the printed addition simply stacks on the existing count.
##
## The catalog stays authoritative. The caller supplies a card ID and a detached enemy-slot
## snapshot, never a card record, cost, pull distance or Tangled count, and never a "living
## record swapped into the vacant slot" trick: a snapshot is an explicit mapping for enemy slots
## 1-4 whose vacant slots are absent/empty. Each ID is authenticated against its own exact
## starter/pool record (full record, recursive type-exact equality) before anything is proposed,
## so a rewritten, relinked, outward-facing or foreign descriptor is refused instead of resolving
## as a reel card.
##
## The result is a NEW detached slot map that preserves every actor's unique identity and all of
## its original stats/statuses, moves only the chosen enemy, and adds Tangled only on Reel In.
## This helper never charges energy, discards a card, mutates the party or the enemies object,
## consumes RNG or alters any core combat state: the live held-card payment and target-selection
## hook is a separate follow-on wiring task, and nothing here claims live playability.

const OWNER := "yarn_ranger"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [2, 3]
const TARGET_KIND := "enemy_single"
const PULL_FORWARD := 1
## This preview is a four-slot contract: a reel pull reads and proposes enemy slots 1-4, matching
## the V3-2 floor bands that place an enemy group of 2-4 in the battle, so a bystander behind the
## reel's two-slot target line is preserved untouched. It keeps its OWN literal domain constant
## and deliberately does NOT derive it from the battle-wide CombatEnemies.MAX_ENEMIES (which stays
## at 3): widening this detached snapshot does not enable a live four-foe fight, and a record under
## key 5 or higher is an out-of-domain snapshot, never an accepted slot.
const MAX_REEL_SLOTS := 4

const _STARTER_CATALOG := preload("res://data/cards/yarn_ranger_starter_cards.gd")
const _POOL_CATALOG := preload("res://data/cards/yarn_ranger_pool_cards.gd")

## The four authentic printings. `record` is the complete expected catalog definition (top-level
## metadata, exact key set, nested values); `catalog` says which Yarn Ranger catalog owns the ID;
## `cost` and `tangled` are the printed numbers the proposal must obey.
const CARDS := {
	"yarn_ranger_reel_thread": {
		"catalog": "starter",
		"cost": 1,
		"tangled": 0,
		"record": {
			"id": "yarn_ranger_reel_thread",
			"display_name": "Reel Thread",
			"owner": "yarn_ranger",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/yarn_ranger_reel_thread.png",
			"starting_copies": 1,
			"reward_eligible": false,
			"upgrade_id": "yarn_ranger_reel_thread_plus",
		},
	},
	"yarn_ranger_reel_thread_plus": {
		"catalog": "starter",
		"cost": 0,
		"tangled": 0,
		"record": {
			"id": "yarn_ranger_reel_thread_plus",
			"display_name": "Reel Thread+",
			"owner": "yarn_ranger",
			"cost": 0,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"pull_forward": 1},
			"illustration_path": "res://assets/paper/cards/yarn_ranger_reel_thread.png",
			"starting_copies": 0,
			"reward_eligible": false,
			"upgrade_of": "yarn_ranger_reel_thread",
		},
	},
	"yarn_ranger_reel_in": {
		"catalog": "pool",
		"cost": 1,
		"tangled": 1,
		"record": {
			"id": "yarn_ranger_reel_in",
			"display_name": "Reel In",
			"owner": "yarn_ranger",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"pull_forward": 1, "tangled": 1},
			"illustration_path": "res://assets/paper/cards/yarn_ranger_reel_in.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": true,
			"upgrade_id": "yarn_ranger_reel_in_plus",
		},
	},
	"yarn_ranger_reel_in_plus": {
		"catalog": "pool",
		"cost": 1,
		"tangled": 2,
		"record": {
			"id": "yarn_ranger_reel_in_plus",
			"display_name": "Reel In+",
			"owner": "yarn_ranger",
			"cost": 1,
			"from_positions": [2, 3],
			"target_kind": "enemy_single",
			"to_positions": [2, 3],
			"effects": {"pull_forward": 1, "tangled": 2},
			"illustration_path": "res://assets/paper/cards/yarn_ranger_reel_in.png",
			"starting_copies": 0,
			"rarity": "common",
			"reward_eligible": false,
			"upgrade_of": "yarn_ranger_reel_in",
		},
	},
}


## True only for the four authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## A detached, fully authenticated reel definition from the catalog that owns the ID, or {} for
## anything else. Unrelated cards, forged spellings and tampered records all resolve to {}.
## `definition_lookup` is an optional testable catalog seam: when it is null the real Yarn Ranger
## catalog is read, and any record it returns is authenticated exactly like the real one.
static func reel_definition(card_id: Variant, definition_lookup: Variant = null) -> Dictionary:
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
## reel record with identical types at every level, so a changed cost, a pull of two slots, an
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


## The single rules-only proposal. `party` is the authoritative hero roster (read through
## get_heroes(), never mutated); `enemy_slots` is the detached slot snapshot described above.
## Returns {"ok": true, reason "proposed", printed cost/Tangled, owner and slot receipt, and a
## detached "slots" map} or {"ok": false, reason ...} with no proposed roster. The published map
## always carries exactly the integer keys 1-4 (a vacant slot maps to an empty dictionary), whether
## the caller's snapshot listed three or four slots, and only the chosen foe ever moves.
func propose_pull(card_id: Variant, party: CombatParty, target_position: Variant,
		enemy_slots: Variant, definition_lookup: Variant = null) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The card is authenticated from its own catalog (or the authenticated seam) before any of the
	# battle state below is even inspected: an unverified caller descriptor is never authority.
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
	if target < 1 or target > MAX_REEL_SLOTS:
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
	var pulled: Dictionary = records[target]
	if int(pulled["hp"]) == 0:
		return _refusal("target_downed")
	# A pull never displaces an occupied neighbour, living or otherwise: only a truly vacant slot
	# (absent/empty) may receive the enemy.
	if records.has(destination):
		return _refusal("destination_occupied")

	var added: int = int(card["tangled"])
	if added > 0:
		var existing: Dictionary = pulled["statuses"] if pulled.has("statuses") else {}
		var current: int = int(existing.get("tangled", 0))
		if added > CombatStatuses.MAX_INT - current:
			return _refusal("status_overflow")
		existing["tangled"] = current + added
		pulled["statuses"] = existing
	# The canonical slot field follows the foe; every other copied field is preserved verbatim.
	pulled["position"] = destination

	var proposed: Dictionary = {}
	for slot in range(1, MAX_REEL_SLOTS + 1):
		proposed[slot] = {}
	for slot: int in records:
		if slot == target:
			continue
		proposed[slot] = records[slot]
	proposed[destination] = pulled
	return {
		"ok": true,
		"reason": "proposed",
		"card_id": id,
		"catalog": card["catalog"],
		"cost": int(card["cost"]),
		"owner_position": owner_position,
		"target_position": target,
		"destination_position": destination,
		"pull_forward": PULL_FORWARD,
		"tangled_added": added,
		"slots": proposed,
	}


## The live owner seat, or a negative code for the reason the reel owner is unusable:
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
		if slot < 1 or slot > MAX_REEL_SLOTS:
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


## The canonical enemy-actor shape (same fields and types CombatEnemies and CombatStatusTurnBatch
## insist on) plus this snapshot's own rule: a record lives in the slot it names.
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


## The canonical status-map schema from CombatStatuses/CombatStatusTurnBatch: N-turn counters are
## non-negative integers, Dodge/Blind are the one-shot tokens 0/1, and Fear is the literal boolean
## true. Any other key or type is malformed rather than silently ignored.
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


## The catalog record for an authenticated ID: the real Yarn Ranger catalog that owns it, or the
## caller's authenticated seam. A missing/invalid seam can never authenticate anything.
static func _lookup(card_id: String, definition_lookup: Variant) -> Variant:
	if definition_lookup == null:
		var card: Dictionary = CARDS.get(card_id, {})
		if card.is_empty():
			return null
		var catalog: RefCounted = _STARTER_CATALOG.new() if card["catalog"] == "starter" \
			else _POOL_CATALOG.new()
		return catalog.get_definition(card_id)
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
