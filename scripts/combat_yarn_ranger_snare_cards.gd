class_name CombatYarnRangerSnareCards
extends RefCounted
## Scene-free paid resolver for the Yarn Ranger's Snare Net and Snare Net+ (V3-1).
##
## Both print the same knitted net: two energy, cast from the middle or back seat, binding EVERY
## living enemy with Tangled (base 1, "+" 2). Enemy positions never compact, so a slain slot keeps
## its place and is neither targeted nor changed. This is an enemy-binding card: it deals no damage,
## moves nobody, draws nothing, spends no Block and never advances the run RNG.
##
## The catalog stays authoritative: the caller supplies a held ID only, never a card record or a
## stack size. Each held ID is authenticated against its own exact pool record before anything is
## paid, so a rewritten, relinked or foreign record is refused.
##
## Tangled writes go straight into the authoritative CombatEnemies records because the shared
## CombatEnemies.can_apply_statuses/apply_statuses vocabulary is still Bleed/Weak/Exposed only;
## broadening that core API belongs to its own owners. This resolver therefore validates the whole
## roster and every recipient status map itself (through CombatStatusTurnBatch, the same validator
## the enemy owner-turn tick uses), preflights every addition including integer overflow, and only
## then pays once and adds the printed count. CombatStatuses/CombatStatusTurnBatch keep owning the
## Tangled count's owner-turn tick; nothing here invents a duration, refresh or early clear.
##
## This is callable rules-layer behaviour only. It does not register these IDs in the live hand,
## rewards, run deck or the app flow; that wiring is a later task.
##
## The file also owns the Yarn Ranger's Snare Shot combat passive ("her first attack each combat
## also applies Tangled 1") as a detached rules receipt. `propose_snare_shot` charges and writes
## nothing: the caller supplies an already confirmed paid attack receipt, its authenticated card ID,
## a detached party/enemy snapshot and the combat-level once-per-combat flag, and receives a NEW
## four-slot enemy map plus an updated flag. The once-per-combat flag's storage and consumption, and
## applying the proposal after a real paid attack, belong to the still-reserved mounted flow.

const OWNER := "yarn_ranger"
const TARGET_KIND := "enemy_all"
const FROM_POSITIONS := [2, 3]
const TO_POSITIONS := [1, 2, 3]

## The two authentic printings and the exact catalog line each one must still carry. `tangled` is
## the printed count added to every living enemy; a "+" only raises it.
const CARDS := {
	"yarn_ranger_snare_net": {
		"cost": 2,
		"tangled": 1,
		"effects": {"tangled": 1, "living_targets_only": true},
		"upgrade_id": "yarn_ranger_snare_net_plus",
	},
	"yarn_ranger_snare_net_plus": {
		"cost": 2,
		"tangled": 2,
		"effects": {"tangled": 2, "living_targets_only": true},
		"upgrade_of": "yarn_ranger_snare_net",
	},
}

## The Yarn Ranger's roster passive (data/heroes/v3_party_roster.json: `snare_shot`,
## trigger `first_attack_of_combat`, effects `{"tangled": 1}`), restated here as the one printed
## rider this proposal offers. It never invents Damage, a second copy of a card's own printed
## Tangled, a duration or a movement.
const SNARE_SHOT_PASSIVE := "snare_shot"
const SNARE_SHOT_TANGLED := 1
## Snare Shot reads and proposes the same detached four-slot enemy domain as the Reel preview,
## because the V3-2 floor bands may place a fourth foe behind a card's printed target line. It keeps
## its OWN literal constant and deliberately does not widen CombatEnemies.MAX_ENEMIES (which stays 3):
## this snapshot contract never enables a live four-foe battle.
const SNARE_SHOT_SLOTS := 4
## A Yarn Ranger attack is derived from the catalog record itself: an authentic `yarn_ranger`
## record aimed at enemies whose printed effects carry a real positive `damage`. A support card
## (Snare Net, Knit Shield, Hood Knit, Reel Thread, Reel In) never matches.
const ATTACK_TARGET_KINDS := ["enemy_single", "enemy_all", "enemy_random"]
## The canonical confirmed paid attack receipt. `target_position` (one chosen foe) and
## `hit_positions` (the confirmed hit list of a multi-target attack) are mutually exclusive; any
## other key is malformed rather than silently ignored, so a caller cannot smuggle in its own
## attack/amount authority.
const RECEIPT_KEYS := ["card_id", "owner_position", "cost_paid", "paid", "hit_confirmed",
	"missed", "target_position", "hit_positions"]

var _catalog := preload("res://data/cards/yarn_ranger_pool_cards.gd").new()
var _starter_catalog := preload("res://data/cards/yarn_ranger_starter_cards.gd").new()
var _batch := CombatStatusTurnBatch.new()


## True only for the two authentic catalog IDs. Pure lookup; nothing is charged or mutated.
func is_supported_card(card_id: Variant) -> bool:
	return typeof(card_id) == TYPE_STRING and CARDS.has(card_id)


## The single paid transaction: authenticate, preflight every input and every recipient counter,
## then charge the printed two energy, discard exactly the held copy and add Tangled to every
## living enemy in original slot order. A refusal changes no deck, party, enemy or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant) -> Dictionary:
	var plan: Dictionary = _prepare(deck, party, enemies, card_id)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above: the turn is active, the
	# exact held ID is affordable, the owner is alive in an authored seat, at least one living enemy
	# exists and every recipient counter can take the printed addition. Keep the defensive returns
	# so an unexpected model change still fails closed before any status is written.
	if not deck.try_spend_energy(plan["cost"]):
		return _refusal("insufficient_energy")
	if not deck.discard_played(plan["card_id"]):
		return _refusal("card_not_held")
	var added: int = plan["tangled_added"]
	var targets: Array = plan["target_positions"]
	for position in targets:
		# The real authoritative enemy record, never a detached get_enemy copy. Preflight already
		# guaranteed that an absent map means "no counters" and a present one is a valid dictionary,
		# so this write cannot fail part-way through the roster.
		var record: Dictionary = enemies._enemies[int(position) - 1]
		if not record.has("statuses"):
			record["statuses"] = {}
		var statuses: Dictionary = record["statuses"]
		statuses["tangled"] = int(statuses.get("tangled", 0)) + added
	return {
		"ok": true,
		"reason": "applied",
		"card_id": plan["card_id"],
		"cost": plan["cost"],
		"owner_position": plan["owner_position"],
		"tangled_added": added,
		"target_positions": targets.duplicate(),
	}


## Read-only preflight of the whole transaction. Returns a detached plan or a refusal receipt.
func _prepare(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies,
		card_id: Variant) -> Dictionary:
	if deck == null or party == null or enemies == null:
		return _refusal("invalid_request")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return _refusal("unsupported_card")
	# The authored pool owns this ID; a rewritten, relinked or copied record is never paid for.
	if not _authentic(_catalog.get_definition(id), id, card):
		return _refusal("catalog_mismatch")

	if deck.combat_state == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or not enemies.is_valid():
		return _refusal("invalid_roster")
	# CombatStatusTurnBatch is the shared validator for a real roster: distinct nonempty hero IDs in
	# fixed seats, one to three enemy slots with well-formed IDs, positions, HP/max HP, Block and
	# status maps. Reusing it keeps this card's accepted vocabulary identical to the owner-turn tick.
	if not _batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return _refusal("invalid_party")
	var roster: Array[Dictionary] = enemies.get_enemies()
	if not _batch.tick_side("enemies", roster).get("ok", false):
		return _refusal("invalid_enemies")

	# Bind the owner by hero ID to its *current* seat; a swapped or misplaced hero grants no authority.
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	for index in range(heroes.size()):
		if heroes[index]["id"] == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		return _refusal("owner_downed")
	if not FROM_POSITIONS.has(owner_position):
		return _refusal("owner_illegal_position")

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = card["cost"]
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	# Preflight every living recipient in original slot order before paying: a slain slot is skipped
	# untouched, and an absent Tangled count adds from zero while an existing count stacks (the same
	# additive owner-turn convention every other N-turn status uses).
	var added: int = card["tangled"]
	var targets: Array[int] = []
	for index in range(roster.size()):
		var enemy: Dictionary = roster[index]
		if int(enemy["hp"]) <= 0:
			continue
		var current: int = _current_tangled(enemy)
		if added > CombatStatuses.MAX_INT - current:
			return _refusal("status_overflow")
		targets.append(index + 1)
	if targets.is_empty():
		return _refusal("no_living_target")
	return {
		"ok": true,
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"tangled_added": added,
		"target_positions": targets,
	}


# --- Snare Shot: first-attack passive (detached proposal) -------------------------------------


## The starting value of the combat-level once-per-combat flag the mounted flow will own and store.
## Both fields are literal booleans and exactly one of them is true; any other combination is stale.
static func fresh_snare_shot_state() -> Dictionary:
	return {"available": true, "consumed": false}


## True only when the ID is an authentic Yarn Ranger attack: it resolves in her own starter or pool
## catalog with her owner tag and an enemy target plus a real printed positive Damage effect. Pure
## lookup; nothing is charged, proposed or mutated, and no caller-supplied flag is consulted.
func is_attack_card(card_id: Variant) -> bool:
	return not _attack_record(card_id).is_empty()


## The detached Snare Shot proposal. Preconditions, all validated before anything is published:
## - `card_id` is an exact authenticated Yarn Ranger ATTACK ID (derived from her starter/pool
##   records, never from a caller claim), and `hit_receipt` is the canonical confirmed paid receipt
##   for that ID: `paid` and `hit_confirmed` literal true, `cost_paid` equal to the printed cost,
##   `owner_position` naming the seat that attacked and exactly one of `target_position` or
##   `hit_positions` naming the foes the confirmed attack actually hit (duplicates collapse to one
##   recipient, because a second hit of the same foe still receives this rider only once).
## - `party` is the authoritative three-hero roster: a living Yarn Ranger is in it, the receipt's
##   seat is her current seat and that seat is inside the card's printed FROM line.
## - `enemy_slots` is a detached enemy snapshot for slots 1-4 (vacant = absent or `{}`), with the
##   canonical actor shape and status vocabulary the owner-turn tick already validates.
## - `passive_state` is the combat-level `fresh_snare_shot_state()` (or an equivalent flag) and is
##   still available, so this rider fires at most once per combat.
## The result is a NEW four-slot map where only the confirmed living hit recipients gain exactly
## Tangled 1 (stacking on any existing count), an ordered per-recipient receipt, and the consumed
## flag. The caller's receipt, snapshot, party and flag are never modified, no enemy is moved, no
## Damage or duration is invented, and nothing is written into a live battle.
func propose_snare_shot(card_id: Variant, party: CombatParty, enemy_slots: Variant,
		hit_receipt: Variant, passive_state: Variant) -> Dictionary:
	var found: Dictionary = _yarn_record(card_id)
	if found.is_empty():
		return _refusal("unsupported_card")
	var attack: Dictionary = _attack_record(card_id)
	if attack.is_empty():
		return _refusal("not_an_attack")
	var id: String = card_id
	var record: Dictionary = attack["record"]
	var receipt: Dictionary = _validate_receipt(hit_receipt, id, record)
	if not receipt.get("ok", false):
		return _refusal(str(receipt.get("reason", "malformed_receipt")))
	# The flag is checked before the roster so an already-spent passive is never evaluated twice.
	var flag: Dictionary = _validate_passive_state(passive_state)
	if not flag.get("ok", false):
		return _refusal(str(flag.get("reason", "invalid_passive_state")))

	if party == null:
		return _refusal("invalid_request")
	if not party.is_valid():
		return _refusal("invalid_party")
	# Same shared roster validator the paid Snare Net and the owner-turn tick use, so a malformed
	# hero record can never be the authority for a passive proposal.
	if not _batch.tick_side("heroes", party.get_heroes()).get("ok", false):
		return _refusal("invalid_party")
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position := 0
	for index in range(heroes.size()):
		if heroes[index].get("id") == OWNER:
			owner_position = index + 1
	if owner_position == 0:
		return _refusal("owner_missing")
	if int(heroes[owner_position - 1]["hp"]) <= 0:
		return _refusal("owner_downed")
	# The receipt must name her *current* seat, and the printing must be legal from that seat.
	if int(receipt["owner_position"]) != owner_position:
		return _refusal("owner_mismatch")
	if not (record["from_positions"] as Array).has(owner_position):
		return _refusal("owner_illegal_position")

	var slots: Dictionary = _validate_enemy_slots(enemy_slots)
	if not slots.get("ok", false):
		return _refusal(str(slots.get("reason", "invalid_enemies")))
	var records: Dictionary = slots["slots"]
	var recipients: Array[int] = receipt["recipients"]
	# Preflight every confirmed recipient before publishing: each one must be a real living foe in
	# its own slot and able to take exactly one more Tangled count.
	for position in recipients:
		if not records.has(position):
			return _refusal("recipient_missing")
		var candidate: Dictionary = records[position]
		if int(candidate["hp"]) <= 0:
			return _refusal("recipient_downed")
		if SNARE_SHOT_TANGLED > CombatStatuses.MAX_INT - _current_tangled(candidate):
			return _refusal("status_overflow")

	var proposed: Dictionary = {}
	for slot in range(1, SNARE_SHOT_SLOTS + 1):
		proposed[slot] = {}
	for slot: int in records:
		proposed[slot] = (records[slot] as Dictionary).duplicate(true)
	var updates: Array[Dictionary] = []
	for position in recipients:
		var enemy: Dictionary = proposed[position]
		var statuses: Dictionary = enemy.get("statuses", {})
		var before: int = int(statuses.get("tangled", 0))
		statuses["tangled"] = before + SNARE_SHOT_TANGLED
		enemy["statuses"] = statuses
		updates.append({"position": position, "enemy_id": str(enemy["id"]),
			"tangled_before": before, "tangled_after": before + SNARE_SHOT_TANGLED})
	return {
		"ok": true,
		"reason": "proposed",
		"passive": SNARE_SHOT_PASSIVE,
		"card_id": id,
		"catalog": attack["catalog"],
		"cost_paid": int(record["cost"]),
		"owner_position": owner_position,
		"tangled_added": SNARE_SHOT_TANGLED,
		"recipient_positions": recipients.duplicate(),
		"status_updates": updates,
		"enemies": proposed,
		"passive_state": {"available": false, "consumed": true},
	}


## The authenticated Yarn Ranger record for an ID plus the catalog that owns it, or {}.
func _yarn_record(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	var record: Dictionary = _starter_catalog.get_definition(id)
	if not record.is_empty():
		return {"catalog": "starter", "record": record}
	record = _catalog.get_definition(id)
	if not record.is_empty():
		return {"catalog": "pool", "record": record}
	return {}


## An authenticated Yarn Ranger attack record, or {} for a support, foreign, forged or unreadable
## record. Attack-vs-support is derived here from the catalog line only.
func _attack_record(card_id: Variant) -> Dictionary:
	var found: Dictionary = _yarn_record(card_id)
	if found.is_empty():
		return {}
	var record: Dictionary = found["record"]
	if record.get("id") != card_id or record.get("owner") != OWNER:
		return {}
	if not ATTACK_TARGET_KINDS.has(record.get("target_kind", "")):
		return {}
	var effects: Variant = record.get("effects")
	if typeof(effects) != TYPE_DICTIONARY:
		return {}
	var damage: Variant = (effects as Dictionary).get("damage")
	if typeof(damage) != TYPE_INT or int(damage) <= 0:
		return {}
	if typeof(record.get("cost")) != TYPE_INT or int(record["cost"]) < 0:
		return {}
	var from_positions: Variant = record.get("from_positions")
	if typeof(from_positions) != TYPE_ARRAY or (from_positions as Array).is_empty():
		return {}
	return found


## Validate the canonical confirmed paid attack receipt for this exact printed card. Returns the
## ordered distinct hit recipients, or a refusal. A miss, an unconfirmed attempt, an unpaid attack,
## a receipt for another card/price or a receipt naming both target forms is refused.
func _validate_receipt(receipt: Variant, card_id: String, record: Dictionary) -> Dictionary:
	if typeof(receipt) != TYPE_DICTIONARY:
		return _refusal("malformed_receipt")
	var given: Dictionary = receipt
	for key: Variant in given:
		if typeof(key) != TYPE_STRING or not RECEIPT_KEYS.has(key):
			return _refusal("malformed_receipt")
	for required in ["card_id", "owner_position", "cost_paid", "paid", "hit_confirmed"]:
		if not given.has(required):
			return _refusal("malformed_receipt")
	if typeof(given["card_id"]) != TYPE_STRING or String(given["card_id"]) != card_id:
		return _refusal("receipt_card_mismatch")
	if typeof(given["paid"]) != TYPE_BOOL or not bool(given["paid"]):
		return _refusal("unpaid_attack")
	if given.has("missed"):
		if typeof(given["missed"]) != TYPE_BOOL:
			return _refusal("malformed_receipt")
		if bool(given["missed"]):
			return _refusal("missed_attack")
	if typeof(given["hit_confirmed"]) != TYPE_BOOL or not bool(given["hit_confirmed"]):
		return _refusal("unconfirmed_hit")
	if typeof(given["cost_paid"]) != TYPE_INT or int(given["cost_paid"]) != int(record["cost"]):
		return _refusal("receipt_cost_mismatch")
	if typeof(given["owner_position"]) != TYPE_INT:
		return _refusal("malformed_receipt")
	var single: bool = given.has("target_position")
	var multi: bool = given.has("hit_positions")
	if single == multi:
		return _refusal("malformed_receipt")
	# The receipt form must match the printing: one chosen foe for a single-target attack, the
	# confirmed hit list for a real multi-target attack.
	if single != (record.get("target_kind") == "enemy_single"):
		return _refusal("receipt_target_mismatch")
	var recipients: Array[int] = []
	if single:
		if typeof(given["target_position"]) != TYPE_INT:
			return _refusal("malformed_receipt")
		recipients.append(int(given["target_position"]))
	else:
		if typeof(given["hit_positions"]) != TYPE_ARRAY:
			return _refusal("malformed_receipt")
		var hits: Array = given["hit_positions"]
		if hits.is_empty():
			return _refusal("no_hit_recipients")
		for hit: Variant in hits:
			if typeof(hit) != TYPE_INT:
				return _refusal("malformed_receipt")
			# A multi-hit card can hit the same foe twice; one rider per recipient, never two.
			if not recipients.has(int(hit)):
				recipients.append(int(hit))
	for position in recipients:
		if position < 1 or position > SNARE_SHOT_SLOTS:
			return _refusal("invalid_recipient")
	if recipients.is_empty():
		return _refusal("no_hit_recipients")
	return {"ok": true, "recipients": recipients, "owner_position": int(given["owner_position"])}


## The combat-level once-per-combat flag: exactly two literal booleans, exactly one of them true.
## A stale/inconsistent map is refused; an already consumed flag refuses the rider without being
## rewritten here, because the mounted flow owns storing and advancing it.
func _validate_passive_state(passive_state: Variant) -> Dictionary:
	if typeof(passive_state) != TYPE_DICTIONARY:
		return _refusal("invalid_passive_state")
	var flag: Dictionary = passive_state
	if flag.keys().size() != 2 or not flag.has("available") or not flag.has("consumed"):
		return _refusal("invalid_passive_state")
	if typeof(flag["available"]) != TYPE_BOOL or typeof(flag["consumed"]) != TYPE_BOOL:
		return _refusal("invalid_passive_state")
	if bool(flag["available"]) == bool(flag["consumed"]):
		return _refusal("invalid_passive_state")
	if not bool(flag["available"]):
		return _refusal("passive_spent")
	return {"ok": true}


## Validate the complete detached four-slot enemy snapshot. Absent and empty slots are vacant, never
## a displaced or slain record. Returns the occupied slots as detached copies, or a refusal.
func _validate_enemy_slots(enemy_slots: Variant) -> Dictionary:
	if typeof(enemy_slots) != TYPE_DICTIONARY:
		return _refusal("invalid_enemies")
	var raw: Dictionary = enemy_slots
	var occupied: Dictionary = {}
	var seen_ids: Array[String] = []
	for key: Variant in raw:
		if typeof(key) != TYPE_INT:
			return _refusal("invalid_enemies")
		var slot: int = key
		if slot < 1 or slot > SNARE_SHOT_SLOTS:
			return _refusal("invalid_enemies")
		var record: Variant = raw[key]
		if typeof(record) != TYPE_DICTIONARY:
			return _refusal("invalid_enemies")
		if (record as Dictionary).is_empty():
			continue
		if not _slot_record_valid(record, slot):
			return _refusal("invalid_enemies")
		var enemy_id: String = (record as Dictionary)["id"]
		if seen_ids.has(enemy_id):
			return _refusal("invalid_enemies")
		seen_ids.append(enemy_id)
		occupied[slot] = (record as Dictionary).duplicate(true)
	if occupied.is_empty():
		return _refusal("invalid_enemies")
	return {"ok": true, "slots": occupied}


## The canonical enemy-actor shape (the fields and types CombatEnemies and CombatStatusTurnBatch
## insist on) plus this snapshot's own rule: a record lives in the slot it names.
func _slot_record_valid(record: Variant, slot: int) -> bool:
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
func _statuses_valid(statuses: Variant) -> bool:
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


## The Tangled count already stored on a real enemy record; absent means no counter. The roster was
## already validated, so a present map and integer count are guaranteed here.
func _current_tangled(enemy: Dictionary) -> int:
	var statuses: Dictionary = enemy.get("statuses", {})
	return int(statuses.get("tangled", 0))


## The record must still carry exactly the authored line: owner, cost, seats, the all-enemy target,
## the one printed Tangled count plus the living-only flag, and the base/"+" link in its catalog.
func _authentic(definition: Dictionary, card_id: String, card: Dictionary) -> bool:
	if definition.get("id") != card_id or definition.get("owner") != OWNER:
		return false
	if definition.get("cost") != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if definition.get("from_positions") != FROM_POSITIONS:
		return false
	if definition.get("to_positions") != TO_POSITIONS:
		return false
	if definition.get("effects") != card["effects"]:
		return false
	if card.has("upgrade_id"):
		return definition.get("upgrade_id") == card["upgrade_id"] \
			and not definition.has("upgrade_of")
	return definition.get("upgrade_of") == card["upgrade_of"] \
		and not definition.has("upgrade_id")


func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
