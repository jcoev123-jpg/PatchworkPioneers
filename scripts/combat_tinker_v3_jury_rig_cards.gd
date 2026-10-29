class_name CombatTinkerV3JuryRigCards
extends RefCounted
## Scene-free rules helper for Tinker's rare Jury-rig / Jury-rig+ (V3-1).
##
## Jury-rig is the goggled scrap-tinker's look-driven trick: he squints at whatever was just
## played, rattles through the scrap backpack and jams together one free copy of that card.
## Both printings are cast only from the middle or back seat (FROM 2-3), target self and print the
## same copy rule; the base costs two energy and the "+" costs one.
##
## This slice prepares the copy, it does not execute it. A successful paid play pays the printed
## cost once, discards exactly the one held copy, sets the once-per-combat marker and returns ONE
## detached, one-time free-play instruction for the most recent genuinely committed OTHER card of
## this combat (`cost_override` 0, the source ID and its original owner / FROM / TO / target kind).
## Running that instruction through the copied card's own resolver - a copied attack, heal or
## target choice - is a later, separately owned live-dispatch task, as is admitting these IDs to the
## mounted hand. Nothing here replays an effect.
##
## The witness is a series of committed card-play receipts for the CURRENT combat, supplied by the
## caller in play order. Each receipt is either a genuine rejected play (`ok: false`, e.g. an
## insufficient-energy refusal) which is never a source, or a successful play carrying the committed
## card's ID, owner, FROM/TO seats and target kind. Their shape is verified here; the most recent
## successful receipt that is not a Jury-rig printing is the source (`exclude_self`), so a failed
## attempt never overwrites an earlier success. An unverifiable receipt refuses the play outright
## instead of silently trusting the rest of the series. An unplayed discard pile is never evidence of
## a play: without receipts there is no source.
##
## The authored V3TinkerPoolCards catalog stays authoritative: both IDs are authenticated against
## their own printed record before anything is paid, so a forged, rewritten or relinked record is
## refused instead of acting as Jury-rig.
##
## Every rejection is a pure no-op: no energy, hand, pile, party, marker, witnessed history or RNG
## change. This is rules-layer behaviour only; it uses no run RNG, touches no run-wallet `scraps`,
## no Combat Scrap counter, no permanent deck or catalog entry, and never invents a second hand,
## extra damage, healing, target positions or a new card entry.

const OWNER := "tinker"
const TARGET_KIND := "self"
## These cards print `target_kind: self`: the Tinker himself is the only recipient.
const SELF_TARGET := 0
## A Jury-rig copy is played for free; the copied card keeps its own rules.
const FREE_COPY_COST := 0
## This helper's own seat domain (never a global party/roster capacity constant).
const SEATS := [1, 2, 3]

const CARD := "tinker_v3_jury_rig"
const CARD_PLUS := "tinker_v3_jury_rig_plus"
const CARD_IDS: Array[String] = [CARD, CARD_PLUS]

## The complete authored effect dictionary both printings must still carry (no extra or missing keys).
const EFFECTS := {
	"copy_previous_card": true,
	"copied_card_cost": FREE_COPY_COST,
	"once_per_combat": true,
	"exclude_self": true,
}

## The two authentic printings and the exact catalog line each one must still carry. Only the printed
## cost differs; the copy rule is identical, so "Jury-rig+" is an upgrade and never a new base card.
const CARDS := {
	"tinker_v3_jury_rig": {
		"cost": 2,
		"from_positions": [2, 3],
		"upgrade_id": "tinker_v3_jury_rig_plus",
	},
	"tinker_v3_jury_rig_plus": {
		"cost": 1,
		"from_positions": [2, 3],
		"base_id": "tinker_v3_jury_rig",
	},
}

const _CATALOG := preload("res://data/cards/v3_tinker_pool_cards.gd")

## A fresh fight's marker; `begin_combat()` clears it. Not serialized anywhere: nothing here is
## permanent deck, catalog or run state.
var _used_this_combat := false
## The verified committed-play receipts of the series the last accepted play used, for evidence.
var _history: Array[Dictionary] = []
var _catalog := _CATALOG.new()


## A fresh fight starts with the once-per-combat marker and the witnessed play order clean. The
## caller passes that combat's own receipt series to preflight/play_card.
func begin_combat() -> void:
	_used_this_combat = false
	_history.clear()


## Whether this combat's one free copy has already been prepared. Read-only.
func has_used_this_combat() -> bool:
	return _used_this_combat


## The committed-play receipts the last accepted play verified, detached. Empty before any play and
## after `begin_combat()`.
func committed_history() -> Array[Dictionary]:
	return _history.duplicate(true)


## True only for the two authentic catalog printings. Pure lookup; nothing is charged or mutated
## and no RNG is touched.
func is_supported_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	if not CARDS.has(id):
		return false
	return is_authentic_definition(_catalog.get_definition(id), id)


## A detached, shape-checked Jury-rig definition from V3TinkerPoolCards, or {} for anything else.
## Unrelated cards, forged spellings, tampered records and the v2 Tinker pool all resolve to {}.
static func jury_rig_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not CARDS.has(id):
		return {}
	var definition: Dictionary = _CATALOG.new().get_definition(id)
	if not is_authentic_definition(definition, id):
		return {}
	return definition


## The record must still carry exactly the authored line: id, Tinker owner, the printed integer cost,
## the self target, the exact FROM seats, an empty TO line, exactly the printed effect dictionary and
## the base/"+" link expressed with V3TinkerPoolCards' base_id/upgrade_id/is_upgrade fields. A stray
## `upgrade_of` is a foreign record shape.
static func is_authentic_definition(definition: Variant, card_id: Variant) -> bool:
	if typeof(definition) != TYPE_DICTIONARY or typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	var card: Dictionary = CARDS.get(id, {})
	if card.is_empty():
		return false
	if definition.get("id") != id or definition.get("owner") != OWNER:
		return false
	if typeof(definition.get("cost")) != TYPE_INT or definition["cost"] != card["cost"]:
		return false
	if definition.get("target_kind") != TARGET_KIND:
		return false
	if not _matches_authored(definition.get("from_positions"), card["from_positions"]):
		return false
	var to_positions: Variant = definition.get("to_positions")
	if typeof(to_positions) != TYPE_ARRAY or not (to_positions as Array).is_empty():
		return false
	if not _matches_authored(definition.get("effects"), EFFECTS):
		return false
	if definition.has("upgrade_of"):
		return false
	if card.has("upgrade_id"):
		return definition.get("base_id") == id \
			and definition.get("upgrade_id") == card["upgrade_id"] \
			and typeof(definition.get("is_upgrade")) == TYPE_BOOL \
			and definition["is_upgrade"] == false
	return definition.get("base_id") == card["base_id"] \
		and definition.get("upgrade_id") == id \
		and typeof(definition.get("is_upgrade")) == TYPE_BOOL \
		and definition["is_upgrade"] == true


## Recursive exact-shape comparison: every level must carry the authored keys, values and Variant
## types, so `0.0`, `"0"` or a missing/extra key never authenticates as the printed record.
static func _matches_authored(value: Variant, expected: Variant) -> bool:
	if typeof(expected) == TYPE_DICTIONARY:
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var actual: Dictionary = value
		var wanted: Dictionary = expected
		if actual.size() != wanted.size():
			return false
		for key in wanted:
			if not actual.has(key):
				return false
			if not _matches_authored(actual[key], wanted[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if typeof(value) != TYPE_ARRAY:
			return false
		var actual_items: Array = value
		var wanted_items: Array = expected
		if actual_items.size() != wanted_items.size():
			return false
		for index in range(wanted_items.size()):
			if not _matches_authored(actual_items[index], wanted_items[index]):
				return false
		return true
	if typeof(value) != typeof(expected):
		return false
	return value == expected


## "success" for a well-formed committed play, "failed" for a genuine rejected play receipt (never a
## source, and it never overwrites an earlier success) and "invalid" for anything unverifiable.
static func receipt_state(receipt: Variant) -> String:
	if typeof(receipt) != TYPE_DICTIONARY:
		return "invalid"
	var record: Dictionary = receipt
	var applied: Variant = record.get("ok")
	if typeof(applied) != TYPE_BOOL:
		return "invalid"
	if applied == false:
		return "failed"
	if not _is_card_id(record.get("card_id")):
		return "invalid"
	var card_owner: Variant = record.get("owner")
	if not card_owner is String or (card_owner as String).is_empty():
		return "invalid"
	if not _is_seat_list(record.get("from_positions"), false):
		return "invalid"
	if not _is_seat_list(record.get("to_positions"), true):
		return "invalid"
	var target_kind: Variant = record.get("target_kind")
	if not target_kind is String or (target_kind as String).is_empty():
		return "invalid"
	return "success"


## The most recent successfully committed OTHER card of this combat, or a refusal. The whole series
## is verified first: one unverifiable receipt refuses the play because the witness cannot be
## trusted. Genuine rejected plays are skipped. A successful Jury-rig receipt is skipped too
## (`exclude_self`); when Jury-rig is the only success the copy would be itself, so it refuses.
static func committed_source(receipts: Variant) -> Dictionary:
	if typeof(receipts) != TYPE_ARRAY:
		return _refusal("invalid_history")
	var series: Array = receipts
	var states: Array[String] = []
	for receipt in series:
		states.append(receipt_state(receipt))
	for state: String in states:
		if state == "invalid":
			return _refusal("invalid_history")
	var saw_self := false
	for index in range(series.size() - 1, -1, -1):
		if states[index] != "success":
			continue
		var record: Dictionary = series[index]
		var source_id: String = str(record.get("card_id", ""))
		if CARD_IDS.has(source_id):
			saw_self = true
			continue
		return {
			"ok": true,
			"reason": "legal",
			"source_index": index,
			"source": _detached_source(record),
		}
	if saw_self:
		return _refusal("self_copy")
	return _refusal("no_previous_play")


## The detached free-play instruction for one verified source card. It keeps the source ID and the
## original owner, FROM/TO seats and target kind, and overrides only the cost to 0. Playing it is the
## later dispatcher's job, through that same card's existing resolver.
static func copy_instruction(source: Dictionary) -> Dictionary:
	var from_positions: Array = []
	for seat in (source.get("from_positions", []) as Array):
		from_positions.append(int(seat))
	var to_positions: Array = []
	for seat in (source.get("to_positions", []) as Array):
		to_positions.append(int(seat))
	return {
		"kind": "free_card_copy",
		"card_id": str(source.get("card_id", "")),
		"owner": str(source.get("owner", "")),
		"from_positions": from_positions,
		"to_positions": to_positions,
		"target_kind": str(source.get("target_kind", "")),
		"cost_override": FREE_COPY_COST,
		"one_time": true,
	}


## Read-only preflight of the whole transaction: authentic held ID, living Tinker at an authored
## seat, an unused once-per-combat marker, a verifiable committed-play series naming another card,
## the held copy and the printed energy. Returns a detached plan or a refusal receipt.
func preflight(deck: CombatDeck, party: CombatParty, card_id: Variant, receipts: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	if deck == null or party == null:
		return _refusal("invalid_request")
	if deck.combat_state == null or deck._rng == null or not deck.turn_active:
		return _refusal("inactive_turn")
	if not party.is_valid() or party._heroes.size() != CombatParty.PARTY_SIZE:
		return _refusal("invalid_party")
	if typeof(card_id) != TYPE_STRING:
		return _refusal("unsupported_card")
	var id: String = card_id
	if not CARDS.has(id):
		return _refusal("unsupported_card")
	# Fetch the authored record from the catalog that owns this ID before anything is paid.
	var definition: Dictionary = _definition_for(id)
	if definition.is_empty():
		return _refusal("catalog_mismatch")

	# Validate the complete roster, then bind the owner by hero ID to its ACTUAL current slot.
	var scan: Dictionary = _scan_party(party)
	if not scan.get("ok", false):
		return _refusal(str(scan.get("reason", "invalid_party")))
	var heroes: Array[Dictionary] = party.get_heroes()
	var owner_position: int = int(scan.get("owner_position", 0))
	if owner_position == 0:
		return _refusal("owner_missing")
	# These cards print FROM 2-3: the front seat is never a legal caster.
	if not (CARDS[id]["from_positions"] as Array).has(owner_position):
		return _refusal("owner_illegal_position")
	if int(heroes[owner_position - 1]["hp"]) == 0:
		return _refusal("owner_downed")

	# These cards print target_kind self: only the Tinker himself is a legal recipient.
	if target_position != SELF_TARGET:
		return _refusal("invalid_target")
	# Once per combat is a combat-level rule: it outranks a second held copy and its energy.
	if _used_this_combat:
		return _refusal("already_used")

	var witness: Dictionary = committed_source(receipts)
	if not witness.get("ok", false):
		return _refusal(str(witness.get("reason", "no_previous_play")))
	var source: Dictionary = witness["source"]

	# Hand membership is the actual held copy, never just a catalog lookup.
	if not deck.hand.has(id):
		return _refusal("card_not_held")
	var cost: int = int(CARDS[id]["cost"])
	if cost < 0 or deck.energy < cost:
		return _refusal("insufficient_energy")

	return {
		"ok": true,
		"reason": "legal",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": owner_position,
		"source_index": int(witness["source_index"]),
		"source_card_id": str(source["card_id"]),
		"source": source,
		"energy_before": deck.energy,
	}


## The single paid transaction: pay the printed energy, discard exactly the held copy, set the
## once-per-combat marker and publish one detached zero-cost copy instruction for the most recent
## committed other card. The copied card's own effect is NOT replayed here. A refusal changes no
## deck, party, marker, witnessed history or RNG state.
func play_card(deck: CombatDeck, party: CombatParty, card_id: Variant, receipts: Variant,
		target_position: int = SELF_TARGET) -> Dictionary:
	var plan: Dictionary = preflight(deck, party, card_id, receipts, target_position)
	if not plan.get("ok", false):
		return _refusal(str(plan.get("reason", "refused")))
	# Every operation below is guaranteed by the complete preflight above. Keep the defensive returns
	# so an unexpected model change still fails closed.
	var id: String = str(plan["card_id"])
	var cost: int = int(plan["cost"])
	if not deck.try_spend_energy(cost):
		return _refusal("insufficient_energy")
	if not deck.discard_played(id):
		return _refusal("card_not_held")
	_used_this_combat = true
	_history = _verified_history(receipts)
	var instruction: Dictionary = copy_instruction(plan["source"])
	var owner_position: int = int(plan["owner_position"])
	return {
		"ok": true,
		"reason": "applied",
		"card_id": id,
		"cost": cost,
		"owner_position": owner_position,
		"target_position": owner_position,
		"source_card_id": str(plan["source_card_id"]),
		"copy": instruction,
		"energy_before": int(plan["energy_before"]),
		"energy_after": deck.energy,
		"used_this_combat": true,
	}


## Only the successful receipts of a verified series, detached, in play order.
static func _verified_history(receipts: Variant) -> Array[Dictionary]:
	var history: Array[Dictionary] = []
	if typeof(receipts) != TYPE_ARRAY:
		return history
	for receipt in (receipts as Array):
		if receipt_state(receipt) != "success":
			continue
		var record: Dictionary = receipt
		history.append({
			"ok": true,
			"card_id": str(record.get("card_id", "")),
			"owner": str(record.get("owner", "")),
			"from_positions": (record.get("from_positions", []) as Array).duplicate(),
			"to_positions": (record.get("to_positions", []) as Array).duplicate(),
			"target_kind": str(record.get("target_kind", "")),
		})
	return history


static func _detached_source(record: Dictionary) -> Dictionary:
	var from_positions: Array = []
	for seat in (record.get("from_positions", []) as Array):
		from_positions.append(int(seat))
	var to_positions: Array = []
	for seat in (record.get("to_positions", []) as Array):
		to_positions.append(int(seat))
	return {
		"card_id": str(record.get("card_id", "")),
		"owner": str(record.get("owner", "")),
		"from_positions": from_positions,
		"to_positions": to_positions,
		"target_kind": str(record.get("target_kind", "")),
	}


static func _is_card_id(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()


## A seat list is a real Array of ints inside this helper's own seat domain; TO may be empty.
static func _is_seat_list(value: Variant, allow_empty: bool) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var seats: Array = value
	if seats.is_empty():
		return allow_empty
	for seat in seats:
		if typeof(seat) != TYPE_INT or not SEATS.has(seat):
			return false
	return true


func _definition_for(card_id: String) -> Dictionary:
	var definition: Dictionary = _catalog.get_definition(card_id)
	if not is_authentic_definition(definition, card_id):
		return {}
	return definition


func _scan_party(party: CombatParty) -> Dictionary:
	# Validate the whole hero roster before anything is paid.
	var heroes: Array[Dictionary] = party.get_heroes()
	var seen_ids: Array[String] = []
	var owner_position := 0
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var hero_id = hero.get("id")
		var position = hero.get("position")
		var hp = hero.get("hp")
		var max_hp = hero.get("max_hp")
		var block = hero.get("block")
		if not hero_id is String or hero_id.is_empty() or seen_ids.has(hero_id):
			return _refusal("invalid_party")
		if not position is int or position != index + 1:
			return _refusal("invalid_party")
		if not max_hp is int or max_hp <= 0:
			return _refusal("invalid_party")
		if not hp is int or hp < 0 or hp > max_hp:
			return _refusal("invalid_party")
		if not block is int or block < 0:
			return _refusal("invalid_party")
		seen_ids.append(hero_id)
		if hero_id == OWNER:
			owner_position = index + 1
	return {"ok": true, "reason": "legal", "owner_position": owner_position}


static func _refusal(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
