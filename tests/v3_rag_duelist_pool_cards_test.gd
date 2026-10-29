extends SceneTree
## V3-1 Rag Duelist catalog contract. No live combat/reward/Rest behavior is assumed.
##
## The same real seeded CombatDeck and three-hero CombatParty fixtures also drive the scene-free
## CombatRagDuelistRiposteCards service for all six Cape Parry / Cape Guard / Duelist Reprise
## printings: one paid play, the printed Block, Riposte N on the owning hero, the canonical
## confirmed-hit projection, one owner-turn expiry, and fail-closed rejection snapshots. Like the
## Feint helper, this is callable rules-layer behaviour only: no live hand, reward, app or run-deck
## wiring is asserted here.
##
## The real seeded deck, party and CombatEnemies rosters additionally drive the scene-free
## CombatRagDuelistNeedleBarrageCards service for the rare Needle Barrage / Needle Barrage+
## printings: one paid play, three SEPARATE strikes of the printed base damage, per-strike
## Block-before-HP accounting against the current defender state, legal Weak/Exposed/Tangled
## adjustment, a mid-barrage kill that stops the remaining strikes without retargeting, seeded
## replay, and fail-closed refusal/forgery snapshots. It too is callable rules-layer behaviour
## only: no live hand, reward, app or run-deck wiring is asserted here.

const ScriptClass = preload("res://data/cards/rag_duelist_pool_cards.gd")

## Paid self-targeting Block-and-Riposte fixtures, copied from the v3 design rather than read back
## from the service.
const PARRY := "rag_duelist_cape_parry"
const PARRY_PLUS := "rag_duelist_cape_parry_plus"
const GUARD := "rag_duelist_cape_guard"
const GUARD_PLUS := "rag_duelist_cape_guard_plus"
const REPRISE := "rag_duelist_duelist_reprise"
const REPRISE_PLUS := "rag_duelist_duelist_reprise_plus"
const RIPOSTE_IDS := [PARRY, PARRY_PLUS, GUARD, GUARD_PLUS, REPRISE, REPRISE_PLUS]
const RIPOSTE_COST := 1
const RIPOSTE_BLOCK := {
	PARRY: 4, PARRY_PLUS: 6, GUARD: 5, GUARD_PLUS: 7, REPRISE: 0, REPRISE_PLUS: 0,
}
const RIPOSTE_N := {
	PARRY: 2, PARRY_PLUS: 3, GUARD: 3, GUARD_PLUS: 4, REPRISE: 5, REPRISE_PLUS: 7,
}
const RIPOSTE_FROM := {
	PARRY: [1, 2, 3], PARRY_PLUS: [1, 2, 3], GUARD: [1, 2, 3], GUARD_PLUS: [1, 2, 3],
	REPRISE: [1, 2], REPRISE_PLUS: [1, 2],
}
const RIPOSTE_CATALOG := {
	PARRY: "starter", PARRY_PLUS: "starter", GUARD: "pool", GUARD_PLUS: "pool",
	REPRISE: "pool", REPRISE_PLUS: "pool",
}
const RIPOSTE_FILLERS := ["filler_stitch", "filler_thread", "filler_needle"]
const HEROES_PATH := "res://data/heroes/v3_party_roster.json"
const ALLY_PATH := "res://data/heroes/starter_party.json"

## The rare pool printing this task resolves, and the per-strike damage each one prints (never
## read back from the service).
const BARRAGE := "rag_duelist_needle_barrage"
const BARRAGE_PLUS := "rag_duelist_needle_barrage_plus"
const BARRAGE_IDS := [BARRAGE, BARRAGE_PLUS]
const BARRAGE_COST := 2
const BARRAGE_HITS := 3
const BARRAGE_DAMAGE := {BARRAGE: 3, BARRAGE_PLUS: 4}
## The Scarecrow's authored Fear flag, copied from the data rather than read back from the service.
const FEAR := "cannot_buff_next_turn"

## The Tattered Snare pair this task resolves.
const SNARE := "rag_duelist_tattered_snare"
const SNARE_PLUS := "rag_duelist_tattered_snare_plus"
const SNARE_IDS := [SNARE, SNARE_PLUS]
const SNARE_COST := 1
const SNARE_TANGLED := {SNARE: 2, SNARE_PLUS: 3}

## Catalog seam double: only Riposte authentication reads it, so a forged record proves the paid
## service fails closed on a rewritten catalog. Every other case uses the real catalogs.
class ForgedRiposte extends CombatRagDuelistRiposteCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)

## The same seam for the Needle Barrage resolver: one exact printing is rewritten, the other stays
## authentic, so both directions of the base/'+' link are exercised.
class ForgedBarrage extends CombatRagDuelistNeedleBarrageCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)


class ForgedSnare extends CombatRagDuelistTatteredSnareCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)

var failures: Array[String] = []
var checks: int = 0
var riposte_service := CombatRagDuelistRiposteCards.new()
var barrage_service := CombatRagDuelistNeedleBarrageCards.new()
var snare_service := CombatRagDuelistTatteredSnareCards.new()


func _initialize() -> void:
	_test_all_base_and_upgrades()
	_test_special_descriptors()
	_test_detached_results()
	_test_invalid_ids()
	_test_rng_state()
	_test_riposte_cards_authored()
	_test_riposte_ac1_paid_play()
	_test_riposte_ac2_projection_and_expiry()
	_test_riposte_ac3_rejections()
	_test_riposte_seeded_replay()
	_test_barrage_cards_authored()
	_test_barrage_ac1_paid_play()
	_test_barrage_ac2_accounting()
	_test_barrage_fear_statuses()
	_test_barrage_fear_rejections()
	_test_barrage_ac3_rejections()
	_test_barrage_forged_catalog()
	_test_barrage_seeded_replay()
	_test_snare_cards_authored()
	_test_snare_ac1_paid_play()
	_test_snare_ac2_tangled_lifecycle()
	_test_snare_ac3_rejections()
	_test_snare_forged_catalog()
	if failures.is_empty():
		print("v3_rag_duelist_pool_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("v3_rag_duelist_pool_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## Independent, named expectations: no global catalog total or insertion-order assertion.
func _cases() -> Dictionary:
	return {
		"rag_duelist_needle_prick": {
			"name": "Needle Prick", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 4, "bleed": 2}, "plus_cost": 1,
			"plus_effects": {"damage": 6, "bleed": 3}},
		"rag_duelist_needle_lunge": {
			"name": "Needle Lunge", "rarity": "common", "cost": 1,
			"from": [2, 3], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 6, "move_self_forward": 1}, "plus_cost": 1,
			"plus_effects": {"damage": 8, "move_self_forward": 1}},
		"rag_duelist_cape_guard": {
			"name": "Cape Guard", "rarity": "common", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"block": 5, "riposte": 3, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"block": 7, "riposte": 4, "duration": 1}},
		"rag_duelist_velvet_feint": {
			"name": "Velvet Feint", "rarity": "common", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"exposed": 1, "draw": 1}, "plus_cost": 0,
			"plus_effects": {"exposed": 1, "draw": 1}},
		"rag_duelist_duelist_reprise": {
			"name": "Duelist Reprise", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "self", "to": [],
			"effects": {"riposte": 5, "duration": 1}, "plus_cost": 1,
			"plus_effects": {"riposte": 7, "duration": 1}},
		"rag_duelist_cape_flourish": {
			"name": "Cape Flourish", "rarity": "uncommon", "cost": 1,
			"from": [1, 2, 3], "target": "self", "to": [],
			"effects": {"dodge_next_attack": 1, "duration": 1}, "plus_cost": 0,
			"plus_effects": {"dodge_next_attack": 1, "duration": 1}},
		"rag_duelist_tattered_snare": {
			"name": "Tattered Snare", "rarity": "uncommon", "cost": 1,
			"from": [1, 2], "target": "enemy_single", "to": [1, 2, 3],
			"effects": {"tangled": 2}, "plus_cost": 1,
			"plus_effects": {"tangled": 3}},
		"rag_duelist_needle_barrage": {
			"name": "Needle Barrage", "rarity": "rare", "cost": 2,
			"from": [1], "target": "enemy_single", "to": [1, 2],
			"effects": {"damage": 3, "hit_count": 3, "independent_hits": true}, "plus_cost": 2,
			"plus_effects": {"damage": 4, "hit_count": 3, "independent_hits": true}},
	}


func _expected_record(base_id: String, spec: Dictionary, upgraded: bool) -> Dictionary:
	var expected: Dictionary = {
		"id": base_id + ("_plus" if upgraded else ""),
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": "rag_duelist",
		"cost": spec["plus_cost"] if upgraded else spec["cost"],
		"from_positions": spec["from"],
		"target_kind": spec["target"],
		"to_positions": spec["to"],
		"effects": spec["plus_effects"] if upgraded else spec["effects"],
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0,
		"rarity": spec["rarity"],
		"reward_eligible": not upgraded,
	}
	if upgraded:
		expected["upgrade_of"] = base_id
	else:
		expected["upgrade_id"] = base_id + "_plus"
	return expected


func _test_all_base_and_upgrades() -> void:
	var catalog = ScriptClass.new()
	var cases: Dictionary = _cases()
	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	var seen: Dictionary = {}
	var rarity_counts: Dictionary = {"common": 0, "uncommon": 0, "rare": 0}

	for base_id: String in cases:
		var spec: Dictionary = cases[base_id]
		var plus_id: String = base_id + "_plus"
		_check(not seen.has(base_id), base_id + " is a distinct base identifier")
		seen[base_id] = true
		_check(base_ids.has(base_id), base_id + " is listed as a base")
		_check(base_ids.count(base_id) == 1, base_id + " has one base-list occurrence")
		_check(not base_ids.has(plus_id), plus_id + " is not a base")
		_check(all_ids.has(base_id) and all_ids.has(plus_id), base_id + " both IDs discoverable")
		_check(catalog.has_card(base_id) and catalog.has_card(plus_id), base_id + " both exist")
		_check(catalog.get_upgrade_id(base_id) == plus_id, base_id + " maps to its upgrade")
		_check(catalog.get_upgrade_id(plus_id) == "", plus_id + " cannot upgrade again")
		rarity_counts[spec["rarity"]] += 1

		for upgraded: bool in [false, true]:
			var card_id: String = plus_id if upgraded else base_id
			var record: Dictionary = catalog.get_definition(card_id)
			var expected: Dictionary = _expected_record(base_id, spec, upgraded)
			_check(not record.is_empty(), card_id + " definition exists")
			for field: String in expected:
				_check(record.has(field) and str(record.get(field)) == str(expected[field]),
					card_id + " matches " + field + ": " + str(record.get(field)))
			_check(record.size() == expected.size(), card_id + " has exactly the documented fields")
			_check(record.get("from_positions") is Array and record.get("to_positions") is Array,
				card_id + " has both position arrays")
			_check(record.get("effects") is Dictionary, card_id + " has effect descriptors")
		_check(base_id != plus_id, base_id + " upgrade has distinct stable ID")

	_check(rarity_counts["common"] == 4, "Exactly 4 common cards")
	_check(rarity_counts["uncommon"] == 3, "Exactly 3 uncommon cards")
	_check(rarity_counts["rare"] == 1, "Exactly 1 rare card")


func _test_special_descriptors() -> void:
	var catalog = ScriptClass.new()
	for suffix: String in ["", "_plus"]:
		var lunge: Dictionary = catalog.get_definition("rag_duelist_needle_lunge" + suffix)
		_check(lunge.get("effects").has("move_self_forward") and lunge.get("effects").get("move_self_forward") == 1,
			"Needle Lunge specifies exactly one slot of forward movement" + suffix)

		var flourish: Dictionary = catalog.get_definition("rag_duelist_cape_flourish" + suffix)
		_check(flourish.get("effects").has("dodge_next_attack") and flourish.get("effects").get("dodge_next_attack") == 1,
			"Cape Flourish specifically identifies dodging the next incoming attack" + suffix)

		var snare: Dictionary = catalog.get_definition("rag_duelist_tattered_snare" + suffix)
		_check(snare.get("effects").has("tangled"),
			"Tattered Snare specifies Tangled duration" + suffix)

		var barrage: Dictionary = catalog.get_definition("rag_duelist_needle_barrage" + suffix)
		_check(barrage.get("effects").has("hit_count") and barrage.get("effects").get("hit_count") == 3,
			"Needle Barrage specifies 3 hits" + suffix)
		_check(barrage.get("effects").has("independent_hits") and barrage.get("effects").get("independent_hits") == true,
			"Needle Barrage specifies independent hits for V3 Thorns" + suffix)

		var reprise: Dictionary = catalog.get_definition("rag_duelist_duelist_reprise" + suffix)
		_check(reprise.get("effects").has("riposte") and reprise.get("effects").has("duration"),
			"Riposte explicitly tracks value and duration" + suffix)


func _test_detached_results() -> void:
	var catalog = ScriptClass.new()
	var sample: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(not sample.is_empty(), "mutation fixture loaded")
	if sample.is_empty():
		return
	sample["effects"]["damage"] = -99
	sample["effects"]["bleed"] = -99
	sample["from_positions"].clear()
	sample["to_positions"][0] = 88
	sample["to_positions"].append(77)
	sample["id"] = "mutated"
	var pristine: Dictionary = catalog.get_definition("rag_duelist_needle_prick")
	_check(pristine.get("effects") == {"damage": 4, "bleed": 2},
		"effects are deeply detached from catalog")
	_check(pristine.get("from_positions") == [1, 2],
		"FROM arrays are deeply detached from catalog")
	_check(pristine.get("to_positions") == [1, 2],
		"TO arrays are deeply detached from catalog")
	_check(pristine.get("id") == "rag_duelist_needle_prick", "metadata is detached")

	var upgraded: Dictionary = catalog.get_definition("rag_duelist_cape_guard_plus")
	upgraded["effects"]["block"] = 900
	upgraded["from_positions"][0] = 900
	upgraded["to_positions"].append(900)
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("effects") == {"block": 7, "riposte": 4, "duration": 1},
		"upgrade effects are detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("from_positions") == [1, 2, 3],
		"upgrade FROM is detached")
	_check(catalog.get_definition("rag_duelist_cape_guard_plus").get("to_positions") == [],
		"empty upgrade TO is detached")

	var base_ids: Array[String] = catalog.get_base_ids()
	var all_ids: Array[String] = catalog.get_all_card_ids()
	_check(base_ids.has("rag_duelist_cape_guard") and all_ids.has("rag_duelist_cape_guard_plus"),
		"ID lists are populated before mutation")
	base_ids.clear()
	all_ids.clear()
	_check(catalog.get_base_ids().has("rag_duelist_cape_guard"), "base ID array is a fresh copy")
	_check(catalog.get_all_card_ids().has("rag_duelist_cape_guard_plus"), "all-ID array is a fresh copy")
	_check(ScriptClass.new().get_definition("rag_duelist_needle_prick").get("effects") == pristine.get("effects"),
		"fresh instance retains canonical definition")


func _test_invalid_ids() -> void:
	var catalog = ScriptClass.new()
	var invalid: Array = [null, 0, 3.5, false, [], {}, StringName("rag_duelist_cape_guard"),
		"", "rag_duelist_not_a_card", "rag_duelist_needle_prick+", "rag_duelist_cape_guard_plus_plus"]
	for id: Variant in invalid:
		_check(not catalog.has_card(id), "invalid id rejected by has_card: " + str(id))
		_check(catalog.get_definition(id).is_empty(), "invalid id returns no record: " + str(id))
		_check(catalog.get_upgrade_id(id) == "", "invalid id has no upgrade: " + str(id))


func _test_rng_state() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var initial_state: int = rng.state
	var catalog = ScriptClass.new()
	var ids: Array[String] = catalog.get_all_card_ids()
	for id: String in ids:
		var def: Dictionary = catalog.get_definition(id)
	_check(rng.state == initial_state, "constructing/enumerating catalog consumes no run RNG")


## --- Paid self Block-and-Riposte cards (Cape Parry / Cape Guard / Duelist Reprise) -----------
##
## These cases drive the scene-free CombatRagDuelistRiposteCards service over real seeded CombatDeck
## and CombatParty fixtures. Like the Feint helper they claim callable rules-layer behaviour only:
## no live hand, reward, app or run-deck wiring is asserted here.

func _riposte_effects(card_id: String) -> Dictionary:
	var effects := {"riposte": int(RIPOSTE_N[card_id]), "duration": 1}
	if int(RIPOSTE_BLOCK[card_id]) > 0:
		effects["block"] = int(RIPOSTE_BLOCK[card_id])
	return effects


func _riposte_catalog_record(card_id: String) -> Dictionary:
	if RIPOSTE_CATALOG.get(card_id, "") == "starter":
		return RagDuelistStarterCards.new().get_definition(card_id)
	return RagDuelistPoolCards.new().get_definition(card_id)


## Both catalogs must still carry the exact authored line for all six printings, and nothing else
## may be accepted as one of these effects.
func _test_riposte_cards_authored() -> void:
	var starter := RagDuelistStarterCards.new()
	var pool := RagDuelistPoolCards.new()
	var copies := {PARRY: 1, PARRY_PLUS: 0, GUARD: 0, GUARD_PLUS: 0, REPRISE: 0, REPRISE_PLUS: 0}
	var reward := {PARRY: false, PARRY_PLUS: false, GUARD: true, GUARD_PLUS: false,
		REPRISE: true, REPRISE_PLUS: false}
	for card_id: String in RIPOSTE_IDS:
		var record: Dictionary = _riposte_catalog_record(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + ": authored catalog record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "rag_duelist", card_id + ": authored owner is the Rag Duelist")
		_check(record.get("cost") == RIPOSTE_COST,
			card_id + ": authored cost is " + str(RIPOSTE_COST))
		_check(record.get("from_positions") == RIPOSTE_FROM[card_id],
			card_id + ": authored FROM seats " + str(RIPOSTE_FROM[card_id]))
		_check(record.get("target_kind") == "self", card_id + ": targets only its owner")
		_check(record.get("to_positions") == [], card_id + ": names no enemy position")
		_check(record.get("effects") == _riposte_effects(card_id),
			card_id + ": exact authored Block/Riposte/duration line")
		_check(record.get("starting_copies") == copies[card_id],
			card_id + ": authored starting copies untouched")
		_check(record.get("reward_eligible") == reward[card_id],
			card_id + ": authored reward eligibility untouched")
		_check(riposte_service.is_supported_card(card_id),
			card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(PARRY) == PARRY_PLUS
		and starter.get_definition(PARRY_PLUS).get("upgrade_of") == PARRY,
		"starter Cape Parry base-to-+ link is intact")
	_check(pool.get_upgrade_id(GUARD) == GUARD_PLUS
		and pool.get_definition(GUARD_PLUS).get("upgrade_of") == GUARD,
		"pool Cape Guard base-to-+ link is intact")
	_check(pool.get_upgrade_id(REPRISE) == REPRISE_PLUS
		and pool.get_definition(REPRISE_PLUS).get("upgrade_of") == REPRISE,
		"pool Duelist Reprise base-to-+ link is intact")
	# Real Rag Duelist cards this resolver must not play as a Riposte card.
	for unsupported: String in ["rag_duelist_rapier_lunge", "rag_duelist_needle_lunge",
			"rag_duelist_feather_feint", "rag_duelist_velvet_feint", "rag_duelist_cape_slip",
			"rag_duelist_needle_prick", "rag_duelist_cape_flourish", "rag_duelist_tattered_snare",
			"rag_duelist_needle_barrage", "rag_duelist_cape_parry_plus_plus",
			"RAG_DUELIST_CAPE_PARRY", "rag_duelist_cape_parry ", ""]:
		_check(not riposte_service.is_supported_card(unsupported),
			unsupported + ": not a paid Riposte printing for this service")
	_check(not riposte_service.is_supported_card(null)
		and not riposte_service.is_supported_card(7)
		and not riposte_service.is_supported_card(true)
		and not riposte_service.is_supported_card(StringName(PARRY)),
		"non-string IDs are never supported")
	var rng := _rng(8241)
	var state_before: int = rng.state
	for card_id: String in RIPOSTE_IDS:
		riposte_service.is_supported_card(card_id)
	riposte_service.is_supported_card("rag_duelist_unknown")
	_check(rng.state == state_before and not RIPOSTE_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


## AC1: each authentic base/'+' printing is charged exactly once, discards exactly one held copy
## and lands on the living owner in every printed seat (including Cape Parry/Guard at rear seat 3).
## AC2 is checked on the resulting owner statuses: exact Block/Riposte, the canonical confirmed-hit
## projection, an unconfirmed attempt returning zero, and one-owner-turn expiry.
func _test_riposte_ac1_paid_play() -> void:
	for card_id: String in RIPOSTE_IDS:
		for owner_position: int in RIPOSTE_FROM[card_id]:
			var label := "%s seat=%d" % [card_id, owner_position]
			var party := _riposte_party(owner_position)
			party._heroes[owner_position - 1]["block"] = 2
			party._heroes[owner_position - 1]["statuses"] = {"bleed": 2}
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					party._heroes[index]["statuses"] = {"weak": 1}
			var deck := _riposte_deck(card_id, 2100 + 10 * owner_position, 1)
			_check(deck.energy == 1 and deck.hand.has(card_id) and deck.hand.count(card_id) >= 2,
				label + ": real seeded hand holds the printing with exactly enough energy")
			var held_before: int = deck.hand.count(card_id)
			var before := _riposte_snapshot(deck, party)
			var result: Dictionary = riposte_service.play_card(deck, party, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied",
				label + ": authorized paid play")
			_check(result.get("card_id") == card_id and result.get("cost") == RIPOSTE_COST,
				label + ": receipt names the authentic card and its printed cost")
			_check(result.get("owner_position") == owner_position
				and result.get("owner_id") == "rag_duelist",
				label + ": receipt reports the real owning seat")
			_check(result.get("energy_before") == 1 and result.get("energy_after") == 0,
				label + ": exactly one shared energy was charged")
			_check(result.get("block") == RIPOSTE_BLOCK[card_id]
				and result.get("block_before") == 2
				and result.get("block_after") == 2 + int(RIPOSTE_BLOCK[card_id]),
				label + ": the receipt reports the printed Block")
			_check(result.get("riposte") == RIPOSTE_N[card_id]
				and result.get("riposte_before") == 0
				and result.get("riposte_after") == RIPOSTE_N[card_id],
				label + ": the receipt reports the printed Riposte N")
			var owner: Dictionary = party.get_hero(owner_position)
			var expected_statuses := {"bleed": 2, "riposte": int(RIPOSTE_N[card_id])}
			_check(owner["block"] == 2 + int(RIPOSTE_BLOCK[card_id]),
				label + ": only the owning hero gains the printed Block")
			_check(owner["statuses"] == expected_statuses,
				label + ": the owning hero keeps unrelated statuses and gains Riposte N")
			_check(owner["hp"] == before["heroes"][owner_position - 1]["hp"],
				label + ": owner HP is untouched")
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					_check(party.get_hero(index + 1) == before["heroes"][index],
						label + ": hero " + str(index + 1) + " is untouched")
			_check(deck.hand.count(card_id) == held_before - 1
				and deck.discard_pile == [card_id] and deck.hand.size() == 4,
				label + ": exactly one held copy moved to the discard with no extra draw")
			_check(deck.draw_pile == before["draw"],
				label + ": the other cards keep their draw-pile order")
			_check(_riposte_snapshot(deck, party)
				== _riposte_expected_play(before, card_id, owner_position),
				label + ": exact party, piles, energy and untouched injected RNG")
			# The receipt carries detached statuses, never the live roster.
			result["statuses"]["riposte"] = 99
			_check(party.get_hero(owner_position)["statuses"] == expected_statuses,
				label + ": a mutated receipt cannot change the hero")

			# AC2: the canonical projection repeats the exact counterdamage on confirmed hits, returns
			# zero for an unconfirmed attempt, and never mutates the statuses.
			var rules := CombatStatuses.new()
			var live: Dictionary = party.get_hero(owner_position)["statuses"]
			var live_snapshot: Dictionary = live.duplicate(true)
			for hit in range(1, 4):
				_check(rules.riposte_damage_for_confirmed_hit(live, true) == RIPOSTE_N[card_id],
					label + ": confirmed hit %d returns exactly Riposte %d" % [hit, RIPOSTE_N[card_id]])
			_check(rules.riposte_damage_for_confirmed_hit(live, false) == 0,
				label + ": an unconfirmed attempt returns zero counterdamage")
			_check(live == live_snapshot,
				label + ": projecting confirmed/unconfirmed hits never mutates Riposte")
			var ended: Dictionary = rules.end_owner_turn(owner["hp"], owner["block"], live)
			_check(ended.get("ok") == true and not ended["statuses"].has("riposte"),
				label + ": the next owner-turn boundary expires Riposte completely")
			_check(ended["statuses"] == {"bleed": 1},
				label + ": expiry keeps the surviving unrelated status counters")
			_check(ended["block"] == owner["block"] and ended["bleed_hp_loss"] == 2,
				label + ": expiry leaves the printed Block and deals only Bleed loss")
			_check(rules.riposte_damage_for_confirmed_hit(ended["statuses"], true) == 0,
				label + ": an expired Riposte yields no counterdamage")


## AC2: Duelist Reprise grants Riposte 5/7 with no Block at all, while re-applying any printing over
## an already active Riposte is refused rather than choosing a stacking/refresh policy. A fresh
## Riposte 0 is inert and may be replaced by the printed N.
func _test_riposte_ac2_projection_and_expiry() -> void:
	for card_id: String in [REPRISE, REPRISE_PLUS]:
		var party := _riposte_party(2)
		party._heroes[1]["block"] = 3
		party._heroes[1]["statuses"] = {"weak": 2, "bleed": 1}
		var deck := _riposte_deck(card_id, 3400, 1)
		var before := _riposte_snapshot(deck, party)
		var result: Dictionary = riposte_service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("block") == 0,
			card_id + ": a legal Reprise play applies no Block")
		var owner: Dictionary = party.get_hero(2)
		_check(owner["block"] == 3,
			card_id + ": Reprise leaves the owner's existing Block exactly as it was")
		_check(owner["statuses"] == {"weak": 2, "bleed": 1, "riposte": RIPOSTE_N[card_id]},
			card_id + ": Reprise adds only Riposte N beside the existing counters")
		_check(_riposte_snapshot(deck, party) == _riposte_expected_play(before, card_id, 2),
			card_id + ": exact one-payment Reprise transaction with an untouched RNG")
		var rules := CombatStatuses.new()
		_check(rules.riposte_damage_for_confirmed_hit(owner["statuses"], true)
			== RIPOSTE_N[card_id],
			card_id + ": the canonical projection repeats Riposte " + str(RIPOSTE_N[card_id]))
		_check(rules.riposte_damage_for_confirmed_hit(owner["statuses"], false) == 0,
			card_id + ": an unconfirmed hit returns zero counterdamage")

	# A second authentic copy while Riposte is active fails closed instead of stacking or refreshing.
	for card_id: String in RIPOSTE_IDS:
		var party := _riposte_party(2)
		party._heroes[1]["statuses"] = {"riposte": 9, "bleed": 1}
		var deck := _riposte_deck(card_id, 3410)
		_riposte_rejected(deck, party, card_id,
			card_id + ": already active Riposte " + str(RIPOSTE_N[card_id]))

	# An inert Riposte 0 is not an active status, so the fresh printed N replaces it.
	for card_id: String in RIPOSTE_IDS:
		var party := _riposte_party(2)
		party._heroes[1]["block"] = 1
		party._heroes[1]["statuses"] = {"riposte": 0, "exposed": 2}
		var deck := _riposte_deck(card_id, 3420, 1)
		var before := _riposte_snapshot(deck, party)
		var result: Dictionary = riposte_service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("riposte_before") == 0,
			card_id + ": a genuine play replaces an inert Riposte 0")
		_check(party.get_hero(2)["statuses"]
			== {"riposte": RIPOSTE_N[card_id], "exposed": 2},
			card_id + ": only Riposte changes; the unrelated Exposed counter survives")
		_check(_riposte_snapshot(deck, party) == _riposte_expected_play(before, card_id, 2),
			card_id + ": exact transaction from the inert-Riposte fixture")

	# Duelist Reprise never adds Block, so a maximal existing Block is not an overflow for it.
	var huge_party := _riposte_party(2)
	huge_party._heroes[1]["block"] = CombatParty.MAX_INT
	var huge_deck := _riposte_deck(REPRISE, 3430, 1)
	var huge_result: Dictionary = riposte_service.play_card(huge_deck, huge_party, REPRISE)
	_check(huge_result.get("ok") == true
		and huge_party.get_hero(2)["block"] == CombatParty.MAX_INT,
		"Duelist Reprise at maximal Block plays without inventing a Block gain")


## AC3: bad payment, forged/foreign/absent cards, invalid actors, malformed statuses and exceeded
## capacity all fail closed and leave hand, draw, discard, energy, party and seeded RNG unchanged.
func _test_riposte_ac3_rejections() -> void:
	var party := _riposte_party(2)

	_riposte_rejected(null, party, PARRY, "null deck")
	_riposte_rejected(_riposte_deck(PARRY, 4001), null, PARRY, "null party")
	_riposte_rejected(_riposte_deck(PARRY, 4002), CombatParty.new([]), PARRY,
		"invalid party roster")

	var inactive := _riposte_deck(PARRY, 4003, -1, false)
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_riposte_rejected(inactive, party, PARRY, "inactive turn")

	var held := _riposte_deck(PARRY, 4004)
	_check(held.hand.has(PARRY) and not held.hand.has(PARRY_PLUS),
		"absent-card fixture holds the base Cape Parry only")
	_riposte_rejected(held, party, PARRY_PLUS, "authentic '+' absent from the hand")

	var foreign := _riposte_deck("rag_duelist_feather_feint", 4005)
	_check(foreign.hand.has("rag_duelist_feather_feint"),
		"foreign-card fixture really holds another Rag Duelist card")
	_riposte_rejected(foreign, party, "rag_duelist_feather_feint", "foreign Rag Duelist card")
	for unsupported: Variant in ["", "rag_duelist_cape_parry_plus_plus",
			"rag_duelist_cape_parry ", "RAG_DUELIST_CAPE_PARRY", "rag_duelist_feather_feint",
			"rag_duelist_rapier_lunge", "rag_duelist_needle_prick", 7, null, true,
			StringName(PARRY)]:
		_riposte_rejected(_riposte_deck(PARRY, 4006), party, unsupported,
			"unsupported or forged printing " + str(unsupported))

	var broke := _riposte_deck(PARRY, 4007, 0)
	_check(broke.energy == 0 and broke.hand.has(PARRY),
		"energy-short fixture is genuinely broke and still holds the card")
	_riposte_rejected(broke, party, PARRY, "insufficient energy")

	var rear_reprise := _riposte_party(3)
	_check(rear_reprise.get_hero(3)["id"] == "rag_duelist",
		"rear-slot fixture really seats the Rag Duelist in slot 3")
	_riposte_rejected(_riposte_deck(REPRISE, 4008), rear_reprise, REPRISE,
		"Duelist Reprise from its unprinted rear seat 3")

	var downed := _riposte_party(1)
	_check(downed.apply_damage(1, downed.get_hero(1)["max_hp"]) and downed.is_downed(1),
		"downed-owner fixture really has a downed Rag Duelist")
	_riposte_rejected(_riposte_deck(PARRY, 4009), downed, PARRY, "downed Rag Duelist")

	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1)["id"] != "rag_duelist"
		and no_owner.get_hero(2)["id"] != "rag_duelist"
		and no_owner.get_hero(3)["id"] != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	_riposte_rejected(_riposte_deck(PARRY, 4010), no_owner, PARRY, "party with no Rag Duelist owner")

	var duplicated := _riposte_party(2)
	duplicated._heroes[0]["id"] = "rag_duelist"
	_check(duplicated.get_hero(1)["id"] == "rag_duelist"
		and duplicated.get_hero(2)["id"] == "rag_duelist",
		"duplicate-identity fixture really repeats the owner ID")
	_riposte_rejected(_riposte_deck(PARRY, 4011), duplicated, PARRY, "duplicate Rag Duelist identity")

	var above_max := _riposte_party(2)
	above_max._heroes[1]["hp"] = int(above_max._heroes[1]["max_hp"]) + 1
	_check(above_max.get_hero(2)["hp"] > above_max.get_hero(2)["max_hp"],
		"malformed-roster fixture really has HP above max")
	_riposte_rejected(_riposte_deck(PARRY, 4012), above_max, PARRY, "HP above max")

	var bad_block := _riposte_party(2)
	bad_block._heroes[1]["block"] = -1
	_check(bad_block.get_hero(2)["block"] == -1, "negative-Block fixture really stores -1")
	_riposte_rejected(_riposte_deck(PARRY, 4013), bad_block, PARRY, "negative Block")

	var bad_position := _riposte_party(2)
	bad_position._heroes[0]["position"] = 3
	_check(bad_position.get_hero(1)["position"] == 3,
		"wrong-position fixture really stores the wrong slot")
	_riposte_rejected(_riposte_deck(PARRY, 4014), bad_position, PARRY, "wrong stored hero position")

	for bad_statuses: Variant in ["bleed", [], null, {"bleed": -1}, {"bleed": "3"},
			{"bleed": 1.5}, {"weak": true}, {1: 2}, {"": 1}, {"unknown_status": 1},
			{"dodge_next_attack": 2}, {"blind_next_attack": 2}, {"riposte": -1},
			{"riposte": 1.5}, {"riposte": "3"}, {"riposte": true}]:
		var broken := _riposte_party(2)
		broken._heroes[1]["statuses"] = bad_statuses
		_check(broken.get_hero(2)["statuses"] == bad_statuses,
			"malformed-status fixture really stores " + str(bad_statuses))
		_riposte_rejected(_riposte_deck(PARRY, 4015), broken, PARRY,
			"malformed owner statuses " + str(bad_statuses))

	var ally_statuses := _riposte_party(2)
	ally_statuses._heroes[0]["statuses"] = {"poison": 1}
	_check(ally_statuses.get_hero(1)["statuses"] == {"poison": 1},
		"malformed-ally fixture really stores an unknown status")
	_riposte_rejected(_riposte_deck(PARRY, 4016), ally_statuses, PARRY,
		"malformed statuses on a non-owner hero")

	for block_card: String in [PARRY, PARRY_PLUS, GUARD, GUARD_PLUS]:
		var huge_block := _riposte_party(2)
		huge_block._heroes[1]["block"] = CombatParty.MAX_INT
		_check(huge_block.get_hero(2)["block"] == CombatParty.MAX_INT,
			block_card + ": Block-overflow fixture really stores MAX_INT Block")
		_riposte_rejected(_riposte_deck(block_card, 4017), huge_block, block_card,
			block_card + ": unrepresentable Block gain")
		var nearly_full := _riposte_party(2)
		nearly_full._heroes[1]["block"] = CombatParty.MAX_INT - int(RIPOSTE_BLOCK[block_card]) + 1
		_check(nearly_full.get_hero(2)["block"]
			> CombatParty.MAX_INT - int(RIPOSTE_BLOCK[block_card]),
			block_card + ": near-overflow fixture leaves too little room for the gain")
		_riposte_rejected(_riposte_deck(block_card, 4018), nearly_full, block_card,
			block_card + ": Block gain would overflow")

	# A rejected attempt never poisons the next authentic one.
	var retry_deck := _riposte_deck(PARRY, 4019, 1)
	var retry_party := _riposte_party(2)
	var retry_before := _riposte_snapshot(retry_deck, retry_party)
	_riposte_rejected(retry_deck, retry_party, PARRY_PLUS, "retry: absent '+' printing")
	var retried: Dictionary = riposte_service.play_card(retry_deck, retry_party, PARRY)
	_check(retried.get("ok") == true, "retry: the authentic play then succeeds")
	_check(_riposte_snapshot(retry_deck, retry_party)
		== _riposte_expected_play(retry_before, PARRY, 2),
		"retry: exactly one charge, one discard and an untouched RNG")

	# A forged catalog record - every authenticated field omitted or altered - is never paid for,
	# while the restored authentic record still plays, so the refusal comes from the forgery.
	for card_id: String in RIPOSTE_IDS:
		var authentic: Dictionary = _riposte_catalog_record(card_id)
		_check(not authentic.is_empty(),
			card_id + ": authentic record available (forgery precondition)")
		if authentic.is_empty():
			continue
		var link_field := "upgrade_of" if card_id.ends_with("_plus") else "upgrade_id"
		var mutations: Array = []
		for field in ["id", "owner", "cost", "from_positions", "to_positions", "target_kind",
				"effects", link_field]:
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			mutations.append(omitted)
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = {"id": "fake_riposte", "owner": "warden", "cost": 2.0,
				"from_positions": [3], "to_positions": [1, 2], "target_kind": "enemy_single",
				"effects": {"riposte": 99, "duration": 2},
				"upgrade_id": "fake_riposte", "upgrade_of": "fake_riposte"}[field]
			mutations.append(altered)
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["weak"] = 1
		mutations.append(extra_effect)
		var stacked_riposte: Dictionary = authentic.duplicate(true)
		stacked_riposte["effects"]["riposte"] = int(stacked_riposte["effects"]["riposte"]) + 1
		mutations.append(stacked_riposte)
		var wrong_duration: Dictionary = authentic.duplicate(true)
		wrong_duration["effects"]["duration"] = 2
		mutations.append(wrong_duration)
		var typed_riposte: Dictionary = authentic.duplicate(true)
		typed_riposte["effects"]["riposte"] = float(typed_riposte["effects"]["riposte"])
		mutations.append(typed_riposte)
		if authentic["effects"].has("block"):
			var missing_block: Dictionary = authentic.duplicate(true)
			missing_block["effects"].erase("block")
			mutations.append(missing_block)
			var typed_block: Dictionary = authentic.duplicate(true)
			typed_block["effects"]["block"] = float(typed_block["effects"]["block"])
			mutations.append(typed_block)
		else:
			var invented_block: Dictionary = authentic.duplicate(true)
			invented_block["effects"]["block"] = 1
			mutations.append(invented_block)
		_check(not mutations.is_empty(), card_id + ": forgery fixtures are non-empty (precondition)")

		var forged_service := ForgedRiposte.new()
		var forged_deck := _riposte_deck(card_id, 4020)
		var forged_party := _riposte_party(2)
		forged_service.forged_id = card_id
		for forged: Dictionary in mutations:
			forged_service.forged = forged
			var forged_before := _riposte_snapshot(forged_deck, forged_party)
			var result: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
			_check(result.get("ok") == false, card_id + ": forged catalog record rejected")
			_check(_riposte_snapshot(forged_deck, forged_party) == forged_before,
				card_id + ": forged record rejection leaves deck, party and RNG unchanged")
		forged_service.forged_id = ""
		var restored: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
		_check(restored.get("ok") == true and restored.get("card_id") == card_id,
			card_id + ": the restored authentic record plays")


## The same seed replays each paid play exactly, and resolution reseeds neither the injected
## generator nor the global RNG (these cards draw no cards).
func _test_riposte_seeded_replay() -> void:
	for card_id: String in RIPOSTE_IDS:
		var first: Dictionary = _riposte_replay_run(card_id, 5201)
		var second: Dictionary = _riposte_replay_run(card_id, 5201)
		_check(not first["snapshot"].is_empty() and first["result"].get("ok") == true,
			card_id + ": seeded replay fixture really plays (non-empty precondition)")
		_check(second["snapshot"] == first["snapshot"]
			and second["result"] == first["result"],
			card_id + ": the same seed replays the final state exactly")
		_check(first["rng_state"] == first["rng_start"]
			and first["rng_seed"] == first["rng_seed_start"]
			and first["snapshot"]["rng_state"] == first["rng_start"],
			card_id + ": a non-drawing paid play consumes no injected RNG state")

	seed(13579)
	var expected_next: int = randi()
	seed(13579)
	var party := _riposte_party(1)
	var deck := _riposte_deck(REPRISE, 5202, 1)
	var state_before: int = deck._rng.state
	var result: Dictionary = riposte_service.play_card(deck, party, REPRISE)
	_check(result.get("ok") == true and deck._rng.state == state_before,
		"a genuine play never consumes the injected generator")
	_check(randi() == expected_next, "resolution never draws from the global RNG")


func _riposte_replay_run(card_id: String, seed_value: int) -> Dictionary:
	var party := _riposte_party(2)
	party._heroes[0]["statuses"] = {"bleed": 1}
	party._heroes[1]["statuses"] = {"weak": 2}
	var deck := _riposte_deck(card_id, seed_value, 1)
	var rng_start: int = deck._rng.state
	var rng_seed: int = deck._rng.seed
	var result: Dictionary = riposte_service.play_card(deck, party, card_id)
	return {"result": result, "snapshot": _riposte_snapshot(deck, party),
		"rng_start": rng_start, "rng_state": deck._rng.state,
		"rng_seed_start": rng_seed, "rng_seed": deck._rng.seed}


func _riposte_rejected(deck: CombatDeck, party: CombatParty, card_id: Variant,
		label: String) -> void:
	var before := _riposte_snapshot(deck, party)
	var result: Dictionary = riposte_service.play_card(deck, party, card_id)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_riposte_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state for one paid play: one cost, one discard, the printed
## Block on the owning seat and the printed Riposte N on that hero only.
func _riposte_expected_play(before: Dictionary, card_id: String,
		owner_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - RIPOSTE_COST
	expected["state_energy"] = int(expected["state_energy"]) - RIPOSTE_COST
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var hero: Dictionary = expected["heroes"][owner_position - 1]
	hero["block"] = int(hero["block"]) + int(RIPOSTE_BLOCK[card_id])
	var statuses: Dictionary = hero.get("statuses", {})
	statuses["riposte"] = int(RIPOSTE_N[card_id])
	hero["statuses"] = statuses
	return expected


## The full observable deck/party state plus the injected RNG state, for exact comparisons.
func _riposte_snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
		result["party_valid"] = party.is_valid()
	if deck != null:
		result["hand"] = deck.hand.duplicate(true)
		result["draw"] = deck.draw_pile.duplicate(true)
		result["discard"] = deck.discard_pile.duplicate(true)
		result["energy"] = deck.energy
		result["turn"] = deck.turn_active
		if deck.combat_state != null:
			result["state_energy"] = deck.combat_state.energy
			result["state_turn"] = deck.combat_state.player_turn_active
		if deck._rng != null:
			result["rng_state"] = deck._rng.state
			result["rng_seed"] = deck._rng.seed
	return result


## A real seeded five-card hand from six cards (three copies of the named ID), so at least two
## copies are genuinely held. `energy` of 0+ spends down to exactly that budget before the play.
func _riposte_deck(card_id: String, seed_value: int, energy: int = -1,
		start_turn: bool = true) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, RIPOSTE_FILLERS[0],
		RIPOSTE_FILLERS[1], RIPOSTE_FILLERS[2]]
	var deck := CombatDeck.new(ids, _rng(seed_value))
	if not start_turn:
		return deck
	_check(deck.start_turn() and deck.turn_active and deck.hand.size() == 5
		and deck.hand.count(card_id) >= 2,
		card_id + ": real seeded five-card hand holding duplicate copies")
	if energy >= 0:
		var spend: int = deck.energy - energy
		_check(spend >= 0 and deck.try_spend_energy(spend) and deck.energy == energy,
			card_id + ": energy fixture holds exactly " + str(energy) + " energy")
	return deck


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real three-hero CombatParty with the authored Rag Duelist in the requested seat and the two
## authored starter allies filling the rest. No run roster or data file is changed.
func _riposte_party(owner_position: int) -> CombatParty:
	var duelist := _authored_record(HEROES_PATH, "rag_duelist")
	var warden := _authored_record(ALLY_PATH, "warden")
	var seamstress := _authored_record(ALLY_PATH, "seamstress")
	_check(int(duelist.get("max_hp", 0)) == 32, "authored Rag Duelist max HP is 32")
	_check(not warden.is_empty() and not seamstress.is_empty(),
		"authored starter party supplies the two ally records")
	var allies: Array = [warden, seamstress]
	var definitions: Array = []
	for index in range(CombatParty.PARTY_SIZE):
		if index + 1 == owner_position:
			definitions.append(duelist)
		else:
			definitions.append(allies.pop_front())
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(owner_position).get("id") == "rag_duelist"
		and not party.is_downed(owner_position),
		"valid party with the unique living Rag Duelist in seat " + str(owner_position))
	return party


func _authored_record(path: String, hero_id: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array, path + " parses")
	if not parsed is Array:
		return {}
	for entry in parsed:
		if not entry is Dictionary:
			continue
		if str(entry.get("id", "")) != hero_id:
			continue
		var max_hp: Variant = entry.get("max_hp")
		if max_hp is float:
			max_hp = int(max_hp)
		_check(max_hp is int and max_hp > 0, path + " gives " + hero_id + " a positive max HP")
		return {"id": hero_id, "name": str(entry.get("name", "")), "max_hp": int(max_hp)}
	_check(false, path + " contains " + hero_id)
	return {}


## --- Paid three-strike Needle Barrage cards (rare pool) ---------------------------------------
##
## These cases drive the scene-free CombatRagDuelistNeedleBarrageCards service over the same real
## seeded CombatDeck and CombatParty fixtures plus real CombatEnemies rosters. Like the Feint and
## Riposte helpers they claim callable rules-layer behaviour only: no live hand, reward, app or
## run-deck wiring is asserted here.

## The exact authored line the pool must still carry for both printings, and the service's own
## authentication of that pair. Fails closed on any rewritten, relinked or mistyped record.
func _test_barrage_cards_authored() -> void:
	var pool := RagDuelistPoolCards.new()
	for card_id: String in BARRAGE_IDS:
		var record: Dictionary = pool.get_definition(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + ": authored catalog record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "rag_duelist", card_id + ": owned by the Rag Duelist")
		_check(record.get("cost") == BARRAGE_COST,
			card_id + ": cost is " + str(BARRAGE_COST))
		_check(record.get("from_positions") == [1], card_id + ": prints only hero seat 1")
		_check(record.get("target_kind") == "enemy_single", card_id + ": targets one enemy")
		_check(record.get("to_positions") == [1, 2], card_id + ": prints enemy slots 1-2")
		_check(record.get("effects") == {"damage": int(BARRAGE_DAMAGE[card_id]),
			"hit_count": BARRAGE_HITS, "independent_hits": true},
			card_id + ": exact independent line of " + str(BARRAGE_DAMAGE[card_id]) + " x 3")
		_check(record.get("starting_copies") == 0,
			card_id + ": authored starting copies untouched")
		_check(record.get("reward_eligible") == (card_id == BARRAGE),
			card_id + ": authored reward eligibility untouched")
		_check(barrage_service.is_supported_card(card_id),
			card_id + ": the service authenticates the ID")
	_check(pool.get_upgrade_id(BARRAGE) == BARRAGE_PLUS
		and pool.get_definition(BARRAGE_PLUS).get("upgrade_of") == BARRAGE,
		"Needle Barrage base-to-+ link is intact")
	# Real Rag Duelist pool cards this resolver must not play, plus aliases of the pair.
	for unsupported: String in ["rag_duelist_needle_prick", "rag_duelist_needle_prick_plus",
			"rag_duelist_needle_lunge", "rag_duelist_needle_lunge_plus",
			"rag_duelist_cape_guard", "rag_duelist_cape_guard_plus",
			"rag_duelist_velvet_feint", "rag_duelist_velvet_feint_plus",
			"rag_duelist_duelist_reprise", "rag_duelist_duelist_reprise_plus",
			"rag_duelist_cape_flourish", "rag_duelist_cape_flourish_plus",
			"rag_duelist_tattered_snare", "rag_duelist_tattered_snare_plus",
			"rag_duelist_needle_barrage_plus_plus", "rag_duelist_needle_barrage+",
			"rag_duelist_needle_barrage ", "RAG_DUELIST_NEEDLE_BARRAGE", ""]:
		_check(not barrage_service.is_supported_card(unsupported),
			unsupported + ": not a Needle Barrage printing for this service")
	for malformed: Variant in [null, 0, 3.5, false, [], {}, StringName(BARRAGE)]:
		_check(not barrage_service.is_supported_card(malformed),
			"non-string or forged ID is never supported: " + str(malformed))
	var rng := _rng(8242)
	var state_before: int = rng.state
	for card_id: String in BARRAGE_IDS:
		barrage_service.is_supported_card(card_id)
	barrage_service.is_supported_card("rag_duelist_unknown")
	_check(rng.state == state_before and not BARRAGE_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


## AC1: both authentic printings, from the one printed hero seat onto enemy slot 1 or 2, charge
## exactly two energy, discard exactly one genuinely held copy and land three SEPARATE strikes of
## the printed base damage - never one pooled 9/12-damage blow.
func _test_barrage_ac1_paid_play() -> void:
	for card_id: String in BARRAGE_IDS:
		var base: int = int(BARRAGE_DAMAGE[card_id])
		for target_position in [1, 2]:
			_play_barrage_survivor(card_id, base, target_position)


func _play_barrage_survivor(card_id: String, base: int, target_position: int) -> void:
	var label := "%s onto enemy %d" % [card_id, target_position]
	var deck := _barrage_deck(card_id, 6100 + 10 * target_position)
	var party := _riposte_party(1)
	var enemies := _barrage_enemies(60, target_position)
	var held_before: int = deck.hand.count(card_id)
	var before := _barrage_snapshot(deck, party, enemies)
	_check(deck.energy == BARRAGE_COST and held_before >= 1,
		label + ": the fixture holds the printing with exactly its printed cost")
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id,
		target_position)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": authorized paid play")
	_check(receipt.get("card_id") == card_id and receipt.get("cost") == BARRAGE_COST
		and receipt.get("energy_spent") == BARRAGE_COST,
		label + ": the receipt names the printing and its printed cost")
	_check(receipt.get("energy_before") == BARRAGE_COST and receipt.get("energy_after") == 0,
		label + ": exactly the shared two energy was charged")
	_check(receipt.get("owner_position") == 1 and receipt.get("owner_id") == "rag_duelist",
		label + ": the owning seat is the real living Rag Duelist in seat 1")
	_check(receipt.get("target_position") == target_position,
		label + ": the chosen enemy slot is reported")
	_check(receipt.get("base_damage") == base
		and receipt.get("printed_hit_count") == BARRAGE_HITS
		and receipt.get("hit_count") == BARRAGE_HITS,
		label + ": three printed strikes of base " + str(base))
	_check(receipt.get("target_hp_before") == 60
		and receipt.get("target_hp_after") == 60 - BARRAGE_HITS * base,
		label + ": the survivor lost exactly three separate printed strikes")
	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == BARRAGE_HITS, label + ": every strike has its own receipt")
	for index in range(mini(hits.size(), BARRAGE_HITS)):
		var hit: Dictionary = hits[index]
		_check(hit.get("hit") == index + 1 and hit.get("position") == target_position,
			label + ": strike " + str(index + 1) + " is the chosen enemy slot")
		_check(hit.get("base_damage") == base and hit.get("damage") == base,
			label + ": strike " + str(index + 1) + " is the printed base " + str(base)
			+ ", never a pooled " + str(BARRAGE_HITS * base))
		_check(hit.get("block_absorbed") == 0 and hit.get("hp_loss") == base,
			label + ": unblocked strike " + str(index + 1) + " loses exactly " + str(base) + " HP")
		_check(hit.get("target_hp_after") == 60 - (index + 1) * base,
			label + ": strike " + str(index + 1) + " reports the real remaining HP")
	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.hand == expected_hand and deck.discard_pile == before["discard"] + [card_id]
		and deck.hand.count(card_id) == held_before - 1,
		label + ": exactly one held copy moved to the discard with no extra draw")
	_check(deck.draw_pile == before["draw"],
		label + ": the draw pile keeps its exact order and nothing is drawn")
	_check(deck.energy == before["energy"] - BARRAGE_COST,
		label + ": exactly one two-energy payment left the shared turn")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": resolution consumes no seeded RNG draw")
	_check(party.get_heroes() == before["heroes"], label + ": no hero record changed")
	var target: Dictionary = enemies.get_enemy(target_position)
	_check(target.get("hp") == 60 - BARRAGE_HITS * base and target.get("block") == 0
		and target.get("position") == target_position,
		label + ": the target keeps its slot and took all three strikes")
	for slot in [1, 2]:
		if slot != target_position:
			_check(enemies.get_enemy(slot) == before["enemies"][slot - 1],
				label + ": the untargeted enemy in slot " + str(slot) + " is untouched")
	# Receipts are detached: mutating one cannot change the real roster.
	hits[0]["damage"] = -99
	_check(enemies.get_enemy(target_position).get("hp") == 60 - BARRAGE_HITS * base,
		label + ": a mutated receipt cannot change the enemy")


## AC2: every strike is resolved against the CURRENT defender state (Block absorbed before HP,
## recalculated each strike), legal Weak/Exposed/Tangled modifiers apply to each separate strike,
## an enemy slain by an early strike stops the barrage without retargeting, and the same seed
## replays the exact receipts.
func _test_barrage_ac2_accounting() -> void:
	for card_id: String in BARRAGE_IDS:
		var base: int = int(BARRAGE_DAMAGE[card_id])
		_barrage_block_strikes(card_id, base)
		_barrage_status_adjusted(card_id, base)
		for kill_after in [1, 2]:
			_barrage_mid_kill(card_id, base, kill_after)


## Four Block against three separate strikes: strike one empties the remaining Block and strike two
## lands on HP, which a single pooled blow can never show in its per-strike record.
func _barrage_block_strikes(card_id: String, base: int) -> void:
	var label := "%s against four Block" % card_id
	var deck := _barrage_deck(card_id, 6200)
	var party := _riposte_party(1)
	var enemies := _barrage_enemies(60, 1)
	_check(enemies.gain_block(1, 4), label + ": the target starts with four Block")
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id, 1)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid barrage resolves")

	# Independent per-strike expectation: Block first, then HP, recomputed every strike.
	var expected_hits: Array = []
	var block := 4
	var hp := 60
	for _index in range(BARRAGE_HITS):
		var absorbed: int = mini(block, base)
		block -= absorbed
		var loss: int = mini(hp, base - absorbed)
		hp -= loss
		expected_hits.append({"damage": base, "block_absorbed": absorbed,
			"hp_loss": loss, "target_hp_after": hp, "target_block_after": block})
	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == BARRAGE_HITS, label + ": three strikes are reported")
	for index in range(mini(hits.size(), expected_hits.size())):
		var hit: Dictionary = hits[index]
		var expected: Dictionary = expected_hits[index]
		_check(hit.get("damage") == expected["damage"], label + ": strike " + str(index + 1)
			+ " deals its own printed " + str(expected["damage"]))
		_check(hit.get("block_absorbed") == expected["block_absorbed"],
			label + ": strike " + str(index + 1) + " absorbs "
			+ str(expected["block_absorbed"]) + " of the remaining Block")
		_check(hit.get("hp_loss") == expected["hp_loss"], label + ": strike " + str(index + 1)
			+ " takes " + str(expected["hp_loss"]) + " HP after that Block")
		_check(hit.get("target_hp_after") == expected["target_hp_after"]
			and hit.get("target_block_after") == expected["target_block_after"],
			label + ": strike " + str(index + 1) + " reports the real HP and Block left")
	# Hand-derived values for both printings, so the shared rules and this oracle cannot drift.
	var absorbed_series: Array = []
	var loss_series: Array = []
	for hit: Dictionary in hits:
		absorbed_series.append(hit.get("block_absorbed"))
		loss_series.append(hit.get("hp_loss"))
	if base == 3:
		_check(absorbed_series == [3, 1, 0] and loss_series == [0, 2, 3],
			label + ": 3/3/3 recomputes Block strike by strike (3, 1, 0 absorbed)")
		_check(receipt.get("target_hp_after") == 55,
			label + ": three 3-damage strikes through four Block cost exactly 5 HP")
	else:
		_check(absorbed_series == [4, 0, 0] and loss_series == [0, 4, 4],
			label + ": 4/4/4 recomputes Block strike by strike (4, 0, 0 absorbed)")
		_check(receipt.get("target_hp_after") == 52,
			label + ": three 4-damage strikes through four Block cost exactly 8 HP")
	_check(receipt.get("target_hp_before") == 60 and receipt.get("target_block_before") == 4,
		label + ": the receipt reports the pre-barrage HP and Block")
	_check(receipt.get("target_block_after") == 0
		and enemies.get_enemy(1).get("block") == 0,
		label + ": the target's Block is spent exactly once, strike by strike")


## Weak on the owner, Exposed and Tangled on the defender: each of the three strikes is adjusted on
## its own (Tangled's flat +2 applies per strike, not once), and no status or token is consumed.
func _barrage_status_adjusted(card_id: String, base: int) -> void:
	var label := "%s with legal Weak/Exposed/Tangled" % card_id
	var deck := _barrage_deck(card_id, 6300)
	var party := _riposte_party(1)
	party._heroes[0]["statuses"] = {"weak": 1, "bleed": 2, "riposte": 2,
		"dodge_next_attack": 1}
	var enemies := _barrage_enemies(80, 1)
	enemies._enemies[0]["statuses"] = {"exposed": 2, "tangled": 1}
	var before := _barrage_snapshot(deck, party, enemies)
	var rules := CombatStatuses.new()
	var per_strike: int = rules.adjusted_attack_damage(base, {"weak": 1},
		{"exposed": 2, "tangled": 1})
	var pooled: int = rules.adjusted_attack_damage(base * BARRAGE_HITS, {"weak": 1},
		{"exposed": 2, "tangled": 1})
	_check(per_strike > 0 and per_strike * BARRAGE_HITS != pooled,
		label + ": three separately adjusted strikes differ from one pooled "
		+ str(base * BARRAGE_HITS) + " strike")
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id, 1)
	_check(receipt.get("ok") == true and receipt.get("hit_count") == BARRAGE_HITS,
		label + ": all three status-adjusted strikes resolve")
	var hits: Array = receipt.get("hits", [])
	for index in range(mini(hits.size(), BARRAGE_HITS)):
		var hit: Dictionary = hits[index]
		_check(hit.get("damage") == per_strike, label + ": strike " + str(index + 1)
			+ " is adjusted on its own to " + str(per_strike))
		_check(hit.get("hp_loss") == per_strike and hit.get("block_absorbed") == 0,
			label + ": unblocked adjusted strike " + str(index + 1) + " takes "
			+ str(per_strike) + " HP")
	_check(enemies.get_enemy(1).get("hp") == 80 - per_strike * BARRAGE_HITS,
		label + ": the target took every adjusted strike separately")
	# Hand-derived cross-check of the shared rules used above.
	var weak_only: int = rules.adjusted_attack_damage(base, {"weak": 1}, {})
	var exposed_only: int = rules.adjusted_attack_damage(base, {}, {"exposed": 1})
	var tangled_only: int = rules.adjusted_attack_damage(base, {}, {"tangled": 1})
	_check(weak_only == (2 if base == 3 else 3),
		label + ": Weak floors one " + str(base) + "-damage strike to " + str(weak_only))
	_check(exposed_only == (4 if base == 3 else 6),
		label + ": Exposed raises one " + str(base) + "-damage strike to " + str(exposed_only))
	_check(tangled_only == base + 2, label + ": Tangled adds its flat +2 to one strike")
	# The authoritative status maps are untouched: no token consumed, no rider applied.
	_check(party.get_hero(1).get("statuses") == {"weak": 1, "bleed": 2, "riposte": 2,
		"dodge_next_attack": 1},
		label + ": the owner keeps every counter and its unspent Dodge token")
	_check(enemies.get_enemy(1).get("statuses") == {"exposed": 2, "tangled": 1},
		label + ": the target keeps its counters and gains no invented status")
	_check(party.get_heroes() == before["heroes"],
		label + ": no hero HP or Block changed")
	_check(_barrage_snapshot(deck, party, enemies)["rng_state"] == before["rng_state"],
		label + ": a status-adjusted barrage consumes no seeded RNG draw")


## A foe slain by strike one or two stops the barrage: no corpse hit, no retargeting, no slot
## compaction and no RNG advancement.
func _barrage_mid_kill(card_id: String, base: int, kill_after: int) -> void:
	var label := "%s slaying on strike %d" % [card_id, kill_after]
	var deck := _barrage_deck(card_id, 6400 + kill_after)
	var party := _riposte_party(1)
	var enemies := _barrage_enemies(base * kill_after, 1)
	var before := _barrage_snapshot(deck, party, enemies)
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id, 1)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": the paid barrage resolves")
	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == kill_after and receipt.get("hit_count") == kill_after,
		label + ": exactly " + str(kill_after) + " strikes land, never a corpse hit")
	for index in range(hits.size()):
		var hit: Dictionary = hits[index]
		_check(hit.get("hit") == index + 1 and hit.get("position") == 1,
			label + ": strike " + str(index + 1) + " stays on the chosen enemy")
	_check(int(receipt.get("target_hp_after")) == 0 and enemies.is_slain(1),
		label + ": the chosen enemy is slain")
	_check(enemies.get_enemy(1).get("position") == 1,
		label + ": the slain slot never compacts")
	_check(enemies.get_enemy(2) == before["enemies"][1],
		label + ": no other enemy is targeted or damaged after the kill")
	_check(deck.energy == before["energy"] - BARRAGE_COST
		and deck.discard_pile == before["discard"] + [card_id],
		label + ": the payment and the one discard happen exactly once")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": a mid-barrage kill consumes no seeded RNG draw")


## Fear (`cannot_buff_next_turn: true`) is the Scarecrow's already-merged authored status: a legal
## non-damage buff lock that the narrower CombatStatusAttacks bridge never accepts. Both printings
## must still resolve their three independent strikes against a feared+weakened target with a feared
## bystander, leaving every authoritative status map and the seeded RNG exactly as they were.
func _test_barrage_fear_statuses() -> void:
	for card_id: String in BARRAGE_IDS:
		var base: int = int(BARRAGE_DAMAGE[card_id])
		for target_position in [1, 2]:
			_barrage_fear_survivor(card_id, base, target_position)


func _barrage_fear_survivor(card_id: String, base: int, target_position: int) -> void:
	var label := "%s with authored Fear on enemy %d" % [card_id, target_position]
	var other_position: int = 1 if target_position == 2 else 2
	var deck := _barrage_deck(card_id, 6600 + 10 * target_position)
	var party := _riposte_party(1)
	var enemies := _barrage_enemies(60, target_position)
	enemies._enemies[target_position - 1]["statuses"] = {"weak": 1, FEAR: true}
	enemies._enemies[other_position - 1]["statuses"] = {FEAR: true}
	var before := _barrage_snapshot(deck, party, enemies)
	_check(deck.energy == BARRAGE_COST and deck.hand.has(card_id),
		label + ": the fixture holds the printing with exactly its printed cost")
	_check(enemies.get_enemy(target_position).get("statuses") == {"weak": 1, FEAR: true}
		and enemies.get_enemy(other_position).get("statuses") == {FEAR: true},
		label + ": the fixture really stores authored Fear plus Weak and a feared bystander")

	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id,
		target_position)
	_check(receipt.get("ok") == true and receipt.get("reason") == "applied",
		label + ": a feared target does not make a legal Needle Barrage malformed")
	_check(receipt.get("energy_before") == BARRAGE_COST and receipt.get("energy_after") == 0,
		label + ": exactly the shared two energy was charged")
	var hits: Array = receipt.get("hits", [])
	_check(hits.size() == BARRAGE_HITS and receipt.get("hit_count") == BARRAGE_HITS,
		label + ": all three independent strikes land")
	for index in range(mini(hits.size(), BARRAGE_HITS)):
		var hit: Dictionary = hits[index]
		_check(hit.get("hit") == index + 1 and hit.get("position") == target_position,
			label + ": strike " + str(index + 1) + " stays on the chosen enemy slot")
		_check(hit.get("damage") == base and hit.get("base_damage") == base,
			label + ": strike " + str(index + 1) + " keeps the printed base " + str(base))
		_check(hit.get("block_absorbed") == 0 and hit.get("hp_loss") == base,
			label + ": Fear never absorbs strike " + str(index + 1))
		_check(hit.get("target_hp_after") == 60 - (index + 1) * base,
			label + ": strike " + str(index + 1) + " reports the real remaining HP")
	_check(receipt.get("target_hp_before") == 60
		and receipt.get("target_hp_after") == 60 - BARRAGE_HITS * base
		and enemies.get_enemy(target_position).get("hp") == 60 - BARRAGE_HITS * base,
		label + ": the feared target took the three separate printed strikes")
	# The authoritative maps are neither rewritten nor consumed by the detached bridge copy.
	_check(enemies.get_enemy(target_position).get("statuses") == {"weak": 1, FEAR: true},
		label + ": the target keeps its authored Fear and Weak exactly")
	_check(enemies.get_enemy(other_position).get("statuses") == {FEAR: true},
		label + ": the feared bystander keeps its status map exactly")
	_check(enemies.get_enemy(other_position) == before["enemies"][other_position - 1],
		label + ": the feared bystander takes no strike")
	_check(party.get_heroes() == before["heroes"], label + ": no hero record changed")
	var expected_hand: Array = before["hand"].duplicate()
	expected_hand.erase(card_id)
	_check(deck.hand == expected_hand and deck.discard_pile == before["discard"] + [card_id]
		and deck.energy == before["energy"] - BARRAGE_COST,
		label + ": exactly one held copy is discarded after one two-energy payment")
	_check(deck._rng.state == before["rng_state"] and deck._rng.seed == before["rng_seed"],
		label + ": an accepted barrage against Fear consumes no seeded RNG draw")


## Fail closed on any non-true Fear value: `false`, numbers, strings and containers are malformed
## rather than inactive, on the target and on an untargeted enemy alike, and nothing is spent.
func _test_barrage_fear_rejections() -> void:
	var invalid_fear: Array = [false, 0, 1, 1.0, "true", 0.0, ["true"], {}]
	for card_id: String in BARRAGE_IDS:
		for bad_value: Variant in invalid_fear:
			var target := _barrage_enemies(40, 1)
			target._enemies[0]["statuses"] = {"weak": 1, FEAR: bad_value}
			_check(target.get_enemy(1).get("statuses") == {"weak": 1, FEAR: bad_value},
				card_id + ": malformed-Fear target fixture really stores " + str(bad_value))
			_barrage_rejected(card_id + ": invalid target Fear " + str(bad_value),
				_barrage_deck(card_id, 6700), _riposte_party(1), target, card_id, 1,
				"malformed_statuses")
			var bystander := _barrage_enemies(40, 1)
			bystander._enemies[1]["statuses"] = {FEAR: bad_value}
			_check(bystander.get_enemy(2).get("statuses") == {FEAR: bad_value},
				card_id + ": malformed-Fear bystander fixture really stores " + str(bad_value))
			_barrage_rejected(card_id + ": invalid bystander Fear " + str(bad_value),
				_barrage_deck(card_id, 6701), _riposte_party(1), bystander, card_id, 1,
				"malformed_statuses")


## AC3: bad payment, forged/unknown/absent printings, invalid actors, malformed status maps,
## illegal or slain enemy seats and invalid combat state all fail closed and leave hand, draw,
## discard, energy, party, enemy roster, status maps and the seeded RNG exactly as they were.
func _test_barrage_ac3_rejections() -> void:
	var party := _riposte_party(1)

	# Missing inputs and an invalid combat state.
	_barrage_rejected("null deck", null, party, _barrage_enemies(30, 1), BARRAGE, 1,
		"invalid_request")
	_barrage_rejected("null party", _barrage_deck(BARRAGE, 7002), null,
		_barrage_enemies(30, 1), BARRAGE, 1, "invalid_request")
	_barrage_rejected("null enemies", _barrage_deck(BARRAGE, 7003), party, null, BARRAGE, 1,
		"invalid_request")
	var broken := _barrage_deck(BARRAGE, 7004)
	broken.combat_state = null
	_check(broken.combat_state == null and broken.hand.has(BARRAGE),
		"broken-deck fixture really has no combat state and still holds the card")
	_barrage_rejected("deck without combat state", broken, party, _barrage_enemies(30, 1),
		BARRAGE, 1, "invalid_deck")
	var rngless := _barrage_deck(BARRAGE, 7005)
	rngless._rng = null
	_check(rngless._rng == null and rngless.turn_active,
		"rngless-deck fixture really has no seeded generator and an active turn")
	_barrage_rejected("deck without a seeded generator", rngless, party,
		_barrage_enemies(30, 1), BARRAGE, 1, "invalid_deck")

	# Turn, hold and card identity.
	var inactive := _barrage_deck(BARRAGE, 7006, BARRAGE_COST, false)
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_barrage_rejected("inactive turn", inactive, party, _barrage_enemies(30, 1), BARRAGE, 1,
		"inactive_turn")
	var held := _barrage_deck(BARRAGE, 7007)
	_check(held.hand.has(BARRAGE) and not held.hand.has(BARRAGE_PLUS),
		"absent-card fixture holds the base Needle Barrage only")
	_barrage_rejected("authentic '+' absent from the hand", held, party,
		_barrage_enemies(30, 1), BARRAGE_PLUS, 1, "card_not_held")
	var foreign := _barrage_deck("rag_duelist_needle_prick", 7008)
	_check(foreign.hand.has("rag_duelist_needle_prick"),
		"foreign-card fixture really holds another Rag Duelist card")
	_barrage_rejected("another Rag Duelist card held in its place", foreign, party,
		_barrage_enemies(30, 1), BARRAGE, 1, "card_not_held")
	for unsupported: Variant in ["", "rag_duelist_needle_barrage_plus_plus",
			"rag_duelist_needle_barrage ", "RAG_DUELIST_NEEDLE_BARRAGE",
			"rag_duelist_needle_prick", "rag_duelist_needle_prick_plus",
			"rag_duelist_needle_lunge_plus", 7, null, true, StringName(BARRAGE)]:
		_barrage_rejected("unsupported or forged printing " + str(unsupported),
			_barrage_deck(BARRAGE, 7009), party, _barrage_enemies(30, 1), unsupported, 1,
			"unsupported_card")

	# Payment.
	for energy in [0, 1]:
		var broke := _barrage_deck(BARRAGE, 7010 + energy, energy)
		_check(broke.energy == energy and broke.hand.has(BARRAGE),
			"energy-short fixture really holds " + str(energy)
			+ " energy and still holds the card")
		_barrage_rejected(str(energy) + " energy is short of the printed cost", broke, party,
			_barrage_enemies(30, 1), BARRAGE, 1, "insufficient_energy")

	# Owner seat, presence and health.
	var rear := _riposte_party(2)
	_check(rear.get_hero(2).get("id") == "rag_duelist",
		"rear-slot fixture really seats the Rag Duelist in slot 2")
	_barrage_rejected("Needle Barrage from its unprinted seat 2",
		_barrage_deck(BARRAGE, 7012), rear, _barrage_enemies(30, 1), BARRAGE, 1,
		"invalid_owner_position")
	var downed := _riposte_party(1)
	_check(downed.apply_damage(1, 400) and downed.is_downed(1),
		"downed-owner fixture really has a downed Rag Duelist")
	_barrage_rejected("downed Rag Duelist", _barrage_deck(BARRAGE, 7013), downed,
		_barrage_enemies(30, 1), BARRAGE, 1, "owner_torn")
	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1).get("id") != "rag_duelist"
		and no_owner.get_hero(2).get("id") != "rag_duelist"
		and no_owner.get_hero(3).get("id") != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	_barrage_rejected("party with no Rag Duelist owner", _barrage_deck(BARRAGE, 7014),
		no_owner, _barrage_enemies(30, 1), BARRAGE, 1, "owner_missing")
	var duplicated := _riposte_party(1)
	duplicated._heroes[1]["id"] = "rag_duelist"
	_check(duplicated.get_hero(1).get("id") == "rag_duelist"
		and duplicated.get_hero(2).get("id") == "rag_duelist",
		"duplicate-identity fixture really repeats the owner ID")
	_barrage_rejected("duplicate Rag Duelist identity", _barrage_deck(BARRAGE, 7015),
		duplicated, _barrage_enemies(30, 1), BARRAGE, 1, "duplicate_owner")

	# Target seat.
	for bad_target in [0, 3, -1, 99]:
		_barrage_rejected("enemy slot " + str(bad_target) + " is outside the printed TO line",
			_barrage_deck(BARRAGE, 7016), party, _barrage_enemies(30, 1), BARRAGE, bad_target,
			"invalid_target")
	var single := CombatEnemies.new([{"id": "barrage_solo", "max_hp": 30}])
	_check(single.is_valid() and not single.is_slain(1),
		"single-enemy fixture has one living slot")
	_barrage_rejected("printed slot 2 with only one enemy", _barrage_deck(BARRAGE, 7017),
		party, single, BARRAGE, 2, "invalid_target")
	var dead_target := _barrage_enemies(30, 1)
	_check(dead_target.apply_damage(1, 30) and dead_target.is_slain(1),
		"slain-target fixture really has a dead first slot")
	_barrage_rejected("slain target", _barrage_deck(BARRAGE, 7018), party, dead_target,
		BARRAGE, 1, "target_slain")

	# Rosters.
	_barrage_rejected("invalid party roster", _barrage_deck(BARRAGE, 7019),
		CombatParty.new([]), _barrage_enemies(30, 1), BARRAGE, 1, "invalid_roster")
	_barrage_rejected("invalid enemy roster", _barrage_deck(BARRAGE, 7020), party,
		CombatEnemies.new([]), BARRAGE, 1, "invalid_roster")
	var bad_position := _riposte_party(1)
	bad_position._heroes[1]["position"] = 3
	_check(bad_position.get_hero(2).get("position") == 3,
		"wrong-position fixture really stores the wrong hero seat")
	_barrage_rejected("wrong stored hero position", _barrage_deck(BARRAGE, 7021),
		bad_position, _barrage_enemies(30, 1), BARRAGE, 1, "invalid_roster")
	var above_max := _riposte_party(1)
	above_max._heroes[0]["hp"] = int(above_max._heroes[0]["max_hp"]) + 1
	_check(above_max.get_hero(1).get("hp") > above_max.get_hero(1).get("max_hp"),
		"malformed-roster fixture really has HP above max")
	_barrage_rejected("hero HP above max", _barrage_deck(BARRAGE, 7022), above_max,
		_barrage_enemies(30, 1), BARRAGE, 1, "invalid_roster")
	var bad_block := _riposte_party(1)
	bad_block._heroes[0]["block"] = -1
	_check(bad_block.get_hero(1).get("block") == -1,
		"negative-Block fixture really stores -1")
	_barrage_rejected("negative hero Block", _barrage_deck(BARRAGE, 7023), bad_block,
		_barrage_enemies(30, 1), BARRAGE, 1, "invalid_roster")
	var bad_enemy_position := _barrage_enemies(30, 1)
	bad_enemy_position._enemies[0]["position"] = 2
	_check(bad_enemy_position.get_enemy(1).get("position") == 2,
		"wrong-enemy-position fixture really stores the wrong enemy seat")
	_barrage_rejected("wrong stored enemy position", _barrage_deck(BARRAGE, 7024), party,
		bad_enemy_position, BARRAGE, 1, "invalid_roster")
	var above_max_enemy := _barrage_enemies(30, 1)
	above_max_enemy._enemies[0]["hp"] = 31
	_check(above_max_enemy.get_enemy(1).get("hp") > above_max_enemy.get_enemy(1).get("max_hp"),
		"malformed-enemy fixture really has HP above max")
	_barrage_rejected("enemy HP above max", _barrage_deck(BARRAGE, 7025), party,
		above_max_enemy, BARRAGE, 1, "invalid_roster")
	var bad_enemy_block := _barrage_enemies(30, 1)
	bad_enemy_block._enemies[0]["block"] = -1
	_check(bad_enemy_block.get_enemy(1).get("block") == -1,
		"negative-enemy-Block fixture really stores -1")
	_barrage_rejected("negative enemy Block", _barrage_deck(BARRAGE, 7026), party,
		bad_enemy_block, BARRAGE, 1, "invalid_roster")

	# Status maps, on the owner and on the target.
	for bad_statuses: Variant in ["bleed", [], null, {"bleed": -1}, {"bleed": "3"},
			{"bleed": 1.5}, {"weak": true}, {1: 2}, {"": 1}, {"unknown_status": 1},
			{"dodge_next_attack": 2}, {"blind_next_attack": -1}, {"riposte": -1}]:
		var broken_owner := _riposte_party(1)
		broken_owner._heroes[0]["statuses"] = bad_statuses
		_check(broken_owner.get_hero(1).get("statuses") == bad_statuses,
			"malformed owner status fixture really stores " + str(bad_statuses))
		_barrage_rejected("malformed owner statuses " + str(bad_statuses),
			_barrage_deck(BARRAGE, 7027), broken_owner, _barrage_enemies(30, 1), BARRAGE, 1,
			"malformed_statuses")
	for bad_enemy_statuses: Variant in [{"tangled": -2}, {"exposed": "2"},
			{"unknown_status": 1}, {"blind_next_attack": 2}]:
		var broken_target := _barrage_enemies(30, 1)
		broken_target._enemies[0]["statuses"] = bad_enemy_statuses
		_check(broken_target.get_enemy(1).get("statuses") == bad_enemy_statuses,
			"malformed target status fixture really stores " + str(bad_enemy_statuses))
		_barrage_rejected("malformed target statuses " + str(bad_enemy_statuses),
			_barrage_deck(BARRAGE, 7028), party, broken_target, BARRAGE, 1,
			"malformed_statuses")
	var bad_ally_statuses := _riposte_party(1)
	bad_ally_statuses._heroes[2]["statuses"] = {"poison": 1}
	_check(bad_ally_statuses.get_hero(3).get("statuses") == {"poison": 1},
		"malformed-ally fixture really stores an unknown status")
	_barrage_rejected("malformed statuses on a non-owner hero", _barrage_deck(BARRAGE, 7029),
		bad_ally_statuses, _barrage_enemies(30, 1), BARRAGE, 1, "malformed_statuses")

	# Defense tokens this resolver must never silently skip: an armed Blind on the attacker (the
	# miss path) and a Dodge on the defender (the evasion path) refuse before payment instead.
	var blinded := _riposte_party(1)
	blinded._heroes[0]["statuses"] = {"blind_next_attack": 1}
	_check(blinded.get_hero(1).get("statuses") == {"blind_next_attack": 1},
		"blinded-owner fixture really carries an armed Blind")
	_barrage_rejected("armed Blind on the attacker", _barrage_deck(BARRAGE, 7030), blinded,
		_barrage_enemies(30, 1), BARRAGE, 1, "owner_blinded")
	var dodging_target := _barrage_enemies(30, 1)
	dodging_target._enemies[0]["statuses"] = {"dodge_next_attack": 1}
	_check(dodging_target.get_enemy(1).get("statuses") == {"dodge_next_attack": 1},
		"dodging-target fixture really carries an armed Dodge")
	_barrage_rejected("armed Dodge on the defender", _barrage_deck(BARRAGE, 7031), party,
		dodging_target, BARRAGE, 1, "target_dodging")
	# An inert token (0) is not an armed state: it neither refuses nor is consumed.
	var inert_parties := _riposte_party(1)
	inert_parties._heroes[0]["statuses"] = {"blind_next_attack": 0, "dodge_next_attack": 0}
	var inert_enemies := _barrage_enemies(40, 1)
	inert_enemies._enemies[0]["statuses"] = {"dodge_next_attack": 0, "blind_next_attack": 0}
	var inert_deck := _barrage_deck(BARRAGE, 7032)
	var inert_before := _barrage_snapshot(inert_deck, inert_parties, inert_enemies)
	var inert_receipt: Dictionary = barrage_service.play_card(inert_deck, inert_parties,
		inert_enemies, BARRAGE, 1)
	_check(inert_receipt.get("ok") == true and inert_receipt.get("hit_count") == BARRAGE_HITS,
		"inert 0 defense tokens do not refuse a genuine barrage")
	_check(inert_parties.get_hero(1).get("statuses")
		== {"blind_next_attack": 0, "dodge_next_attack": 0}
		and inert_enemies.get_enemy(1).get("statuses")
		== {"dodge_next_attack": 0, "blind_next_attack": 0},
		"inert 0 defense tokens are neither consumed nor rewritten")
	_check(inert_enemies.get_enemy(1).get("hp") == 40 - int(BARRAGE_DAMAGE[BARRAGE]) * 3,
		"an inert token never changes the three printed strikes")
	_check(inert_deck.energy == inert_before["energy"] - BARRAGE_COST,
		"the inert-token play still charges exactly its printed cost")

	# A refused attempt never poisons the next authentic one.
	var retry_deck := _barrage_deck(BARRAGE, 7033)
	var retry_party := _riposte_party(1)
	var retry_enemies := _barrage_enemies(40, 1)
	var retry_before := _barrage_snapshot(retry_deck, retry_party, retry_enemies)
	_barrage_rejected("retry: absent '+' printing", retry_deck, retry_party, retry_enemies,
		BARRAGE_PLUS, 1, "card_not_held")
	var retried: Dictionary = barrage_service.play_card(retry_deck, retry_party, retry_enemies,
		BARRAGE, 1)
	_check(retried.get("ok") == true and retried.get("reason") == "applied",
		"retry: the authentic play then succeeds")
	_check(retry_deck.energy == retry_before["energy"] - BARRAGE_COST
		and retry_deck.discard_pile == retry_before["discard"] + [BARRAGE]
		and retry_deck._rng.state == retry_before["rng_state"],
		"retry: exactly one charge, one discard and an untouched RNG")


func _barrage_rejected(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: Variant, target_position: int,
		reason: String) -> void:
	var before := _barrage_snapshot(deck, party, enemies)
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id,
		target_position)
	_check(receipt.get("ok") == false, label + ": refused")
	_check(receipt.get("reason") == reason,
		label + ": refusal reason is " + reason + " (got " + str(receipt.get("reason")) + ")")
	for key: String in ["ok", "reason", "card_id", "cost", "owner_position", "owner_id",
			"target_position", "printed_hit_count", "hit_count", "base_damage", "energy_before",
			"energy_after", "energy_spent", "target_hp_before", "target_hp_after",
			"target_block_before", "target_block_after", "attacker_statuses", "hits"]:
		_check(receipt.has(key), label + ": refusal receipt carries " + key)
	_check(receipt.get("energy_spent") == 0 and receipt.get("hits") == [],
		label + ": refusal reports no spend and no strikes")
	_check(_barrage_snapshot(deck, party, enemies) == before,
		label + ": deck, party, enemy roster, status maps and seeded RNG are unchanged")


## AC3: a rewritten, relinked or mistyped pool record is refused as catalog_mismatch before any
## energy, card, HP, Block or RNG state moves, while the same seam serving the authentic records
## still plays the paid card.
func _test_barrage_forged_catalog() -> void:
	var pool := RagDuelistPoolCards.new()
	for card_id: String in BARRAGE_IDS:
		var authentic: Dictionary = pool.get_definition(card_id)
		_check(not authentic.is_empty(),
			card_id + ": authentic record available (forgery precondition)")
		if authentic.is_empty():
			continue
		var link_key := "upgrade_of" if card_id.ends_with("_plus") else "upgrade_id"
		var fields: Array[String] = ["id", "owner", "cost", "from_positions", "to_positions",
			"target_kind", "effects", "starting_copies", "reward_eligible", link_key]
		var replacements: Dictionary = {
			"id": "rag_duelist_forged_barrage", "owner": "warden", "cost": 1,
			"from_positions": [1, 2], "to_positions": [1], "target_kind": "self",
			"effects": {"damage": 9, "hit_count": 1},
			"starting_copies": 1,
			"reward_eligible": not bool(authentic.get("reward_eligible", false)),
			"upgrade_id": "rag_duelist_forged_barrage",
			"upgrade_of": "rag_duelist_forged_barrage",
		}
		var mutations: Array = []
		for field: String in fields:
			var omitted: Dictionary = authentic.duplicate(true)
			omitted.erase(field)
			mutations.append(omitted)
			var altered: Dictionary = authentic.duplicate(true)
			altered[field] = replacements[field]
			mutations.append(altered)
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["bleed"] = 2
		mutations.append(extra_effect)
		var typed_damage: Dictionary = authentic.duplicate(true)
		typed_damage["effects"]["damage"] = float(typed_damage["effects"]["damage"])
		mutations.append(typed_damage)
		var typed_hit_count: Dictionary = authentic.duplicate(true)
		typed_hit_count["effects"]["hit_count"] = float(BARRAGE_HITS)
		mutations.append(typed_hit_count)
		var merged_hits: Dictionary = authentic.duplicate(true)
		merged_hits["effects"]["hit_count"] = 1
		merged_hits["effects"]["damage"] = int(BARRAGE_DAMAGE[card_id]) * BARRAGE_HITS
		mutations.append(merged_hits)
		var not_independent: Dictionary = authentic.duplicate(true)
		not_independent["effects"]["independent_hits"] = 1
		mutations.append(not_independent)
		_check(not mutations.is_empty(), card_id + ": forgery fixtures are non-empty (precondition)")

		var forged_service := ForgedBarrage.new()
		forged_service.forged_id = card_id
		var forged_deck := _barrage_deck(card_id, 7100)
		var forged_party := _riposte_party(1)
		var forged_enemies := _barrage_enemies(40, 1)
		for forged: Dictionary in mutations:
			forged_service.forged = forged
			var forged_before := _barrage_snapshot(forged_deck, forged_party, forged_enemies)
			var receipt: Dictionary = forged_service.play_card(forged_deck, forged_party,
				forged_enemies, card_id, 1)
			_check(receipt.get("ok") == false
				and receipt.get("reason") == "catalog_mismatch",
				card_id + ": a forged catalog record is refused as catalog_mismatch")
			_check(_barrage_snapshot(forged_deck, forged_party, forged_enemies)
				== forged_before,
				card_id + ": a forged record spends, discards and damages nothing")
			_check(not forged_service.is_supported_card(card_id),
				card_id + ": the forged pair is not an authenticated printing")
		forged_service.forged_id = ""
		var restored: Dictionary = forged_service.play_card(forged_deck, forged_party,
			forged_enemies, card_id, 1)
		_check(restored.get("ok") == true and restored.get("reason") == "applied",
			card_id + ": the restored authentic record plays")
		_check(forged_deck.energy == 0 and forged_deck.discard_pile == [card_id],
			card_id + ": the restored record spends exactly two energy and one held copy")
		_check(forged_enemies.get_enemy(1).get("hp")
			== 40 - int(BARRAGE_DAMAGE[card_id]) * BARRAGE_HITS,
			card_id + ": the restored record lands all three printed strikes")


## The same seed replays every per-strike receipt and the final state exactly, and resolution
## reseeds neither the injected generator nor the global RNG.
func _test_barrage_seeded_replay() -> void:
	for card_id: String in BARRAGE_IDS:
		var first := _barrage_replay_run(card_id, 6501)
		var second := _barrage_replay_run(card_id, 6501)
		_check(first["receipt"].get("ok") == true and not first["snapshot"].is_empty(),
			card_id + ": the seeded replay fixture really plays (non-empty precondition)")
		_check(second["snapshot"] == first["snapshot"]
			and second["receipt"] == first["receipt"],
			card_id + ": the same seed replays the exact receipts and final state")
		_check((first["receipt"].get("hits", []) as Array).size() == BARRAGE_HITS,
			card_id + ": the replay really resolved three strikes")
		_check(first["rng_state"] == first["rng_start"]
			and first["rng_seed"] == first["rng_seed_start"],
			card_id + ": the barrage consumes no injected RNG state")

	seed(24680)
	var expected_next: int = randi()
	seed(24680)
	var played := _barrage_replay_run(BARRAGE, 6502)
	_check(played["receipt"].get("ok") == true, "global-RNG fixture really plays")
	_check(randi() == expected_next, "resolving the barrage never draws from the global RNG")


func _barrage_replay_run(card_id: String, seed_value: int) -> Dictionary:
	var deck := _barrage_deck(card_id, seed_value)
	var party := _riposte_party(1)
	party._heroes[0]["statuses"] = {"weak": 1}
	var enemies := _barrage_enemies(60, 2)
	_check(enemies.gain_block(2, 2), "replay fixture gives the second slot two Block")
	var rng_start: int = deck._rng.state
	var rng_seed: int = deck._rng.seed
	var receipt: Dictionary = barrage_service.play_card(deck, party, enemies, card_id, 2)
	return {"receipt": receipt, "snapshot": _barrage_snapshot(deck, party, enemies),
		"rng_start": rng_start, "rng_state": deck._rng.state,
		"rng_seed_start": rng_seed, "rng_seed": deck._rng.seed}


## A real seeded roster with a living target in the requested slot and one untouched decoy.
func _barrage_enemies(target_hp: int, target_position: int,
		decoy_hp: int = 40) -> CombatEnemies:
	var definitions: Array = []
	for index in range(2):
		var slot := index + 1
		var is_target: bool = slot == target_position
		definitions.append({
			"id": "barrage_target" if is_target else "barrage_decoy",
			"max_hp": target_hp if is_target else decoy_hp,
		})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and not enemies.is_slain(target_position)
		and enemies.get_enemy(target_position).get("max_hp") == target_hp,
		"barrage fixture has a living target in slot " + str(target_position))
	return enemies


## A real seeded five-card hand holding the exact printing, with exactly its printed cost left.
func _barrage_deck(card_id: String, seed_value: int, energy: int = BARRAGE_COST,
		start_turn: bool = true) -> CombatDeck:
	var deck := _riposte_deck(card_id, seed_value, energy, start_turn)
	if start_turn:
		_check(deck.hand.has(card_id) and deck.energy == energy,
			card_id + ": seeded hand holds the printing with exactly " + str(energy)
			+ " energy")
	return deck


## Detached before/after state for refusals: piles, turn, energy, seeded RNG and actor records,
## tolerant of a deck whose combat state or generator is missing.
func _barrage_snapshot(deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies) -> Dictionary:
	var snapshot: Dictionary = {}
	if deck != null:
		snapshot["draw"] = deck.draw_pile.duplicate(true)
		snapshot["hand"] = deck.hand.duplicate(true)
		snapshot["discard"] = deck.discard_pile.duplicate(true)
		if deck.combat_state != null:
			snapshot["turn"] = deck.turn_active
			snapshot["energy"] = deck.energy
			snapshot["state_turn"] = deck.combat_state.player_turn_active
			snapshot["state_energy"] = deck.combat_state.energy
		else:
			snapshot["combat_state"] = "missing"
		if deck._rng != null:
			snapshot["rng_state"] = deck._rng.state
			snapshot["rng_seed"] = deck._rng.seed
		else:
			snapshot["rng"] = "missing"
	if party != null:
		snapshot["party_valid"] = party.is_valid()
		snapshot["heroes"] = party.get_heroes()
	if enemies != null:
		snapshot["enemies_valid"] = enemies.is_valid()
		snapshot["enemies"] = enemies.get_enemies()
	return snapshot




## --- Tattered Snare cards (uncommon pool) ---------------------------------------------

func _test_snare_cards_authored() -> void:
	var pool := RagDuelistPoolCards.new()
	for card_id: String in SNARE_IDS:
		var record: Dictionary = pool.get_definition(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + ": authored catalog record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "rag_duelist", card_id + ": owned by Rag Duelist")
		_check(record.get("cost") == SNARE_COST, card_id + ": cost is 1")
		_check(record.get("from_positions") == [1, 2], card_id + ": from seats 1-2")
		_check(record.get("target_kind") == "enemy_single", card_id + ": targets one enemy")
		_check(record.get("to_positions") == [1, 2, 3], card_id + ": targets slots 1-3")
		_check(record.get("effects") == {"tangled": int(SNARE_TANGLED[card_id])},
			card_id + ": exact Tangled line")
		_check(record.get("starting_copies") == 0,
			card_id + ": authored starting copies untouched")
		_check(record.get("reward_eligible") == (card_id == SNARE),
			card_id + ": reward eligibility matches base only")
		_check(snare_service.is_supported_card(card_id),
			card_id + ": service authenticates the ID")
	_check(pool.get_upgrade_id(SNARE) == SNARE_PLUS
		and pool.get_definition(SNARE_PLUS).get("upgrade_of") == SNARE,
		"Tattered Snare base-to-+ link is intact")
	for unsupported: Variant in ["rag_duelist_needle_prick", "rag_duelist_needle_prick_plus",
		"rag_duelist_cape_guard", "rag_duelist_tattered_snare_plus_plus",
		"rag_duelist_tattered_snare ", "", 7, null, true,
		StringName("fake_snare")]:
		_check(not snare_service.is_supported_card(unsupported),
			str(unsupported) + ": not a Tattered Snare printing")
	var rng := _rng(8243)
	var state_before: int = rng.state
	for card_id in SNARE_IDS:
		snare_service.is_supported_card(card_id)
	snare_service.is_supported_card("rag_duelist_unknown")
	_check(rng.state == state_before and not SNARE_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


func _test_snare_ac1_paid_play() -> void:
	for card_id: String in SNARE_IDS:
		for owner_position in [1, 2]:
			for target_slot in [1, 2, 3]:
				var label := "%s seat=%d target=%d" % [card_id, owner_position, target_slot]
				var party := _riposte_party(owner_position)
				var enemies := _snare_enemies(30, target_slot)
				# Seed existing positive Tangled plus an unrelated status on the selected foe.
				enemies._enemies[target_slot - 1]["statuses"] = {"tangled": 1, "weak": 1}
				var deck := _riposte_deck(card_id, 9100 + 10 * owner_position + target_slot, SNARE_COST)
				_check(deck.energy == SNARE_COST and deck.hand.has(card_id),
					label + ": fixture holds card with exactly 1 energy")
				var held_before: int = deck.hand.count(card_id)
				var before := _barrage_snapshot(deck, party, enemies)
				before["enemies"] = enemies.get_enemies()
				var result: Dictionary = snare_service.play_card(deck, party, enemies, card_id, target_slot)
				_check(result.get("ok") == true and result.get("reason") == "applied",
					label + ": authorized paid play")
				_check(result.get("card_id") == card_id and result.get("cost") == SNARE_COST,
					label + ": receipt names card and cost 1")
				_check(result.get("owner_position") == owner_position and result.get("owner_id") == "rag_duelist",
					label + ": receipt reports real seat")
				_check(result.get("target_position") == target_slot,
					label + ": receipt reports chosen target slot")
				_check(result.get("tangled_added") == int(SNARE_TANGLED[card_id]),
					label + ": receipt reports printed Tangled count")
				# Exactly 1 energy spent, exactly one copy discarded.
				_check(deck.energy == 0 and deck.hand.count(card_id) == held_before - 1,
					label + ": exactly 1 energy spent and one copy discarded")
				_check(deck.discard_pile == [card_id], label + ": discard holds exactly the copy")
				# Target stacked exactly the printed increment and preserved its other status.
				var target_after: Dictionary = enemies.get_enemy(target_slot)
				_check(target_after.get("statuses", {}).get("tangled") == 1 + int(SNARE_TANGLED[card_id]),
					label + ": target stacked existing Tangled by printed amount")
				_check(target_after.get("statuses", {}).get("weak") == 1,
					label + ": target preserved unrelated Weak status")
				# Non-target enemies untouched (full record equality, not just HP).
				for slot in [1, 2, 3]:
					if slot == target_slot:
						continue
					_check(enemies.get_enemy(slot) == before["enemies"][slot - 1],
						label + ": non-target slot %d untouched entirely" % slot)
				# Heroes untouched entirely.
				_check(party.get_heroes() == before.get("heroes", []),
					label + ": heroes unchanged entirely")
				# Draw pile unchanged; no extra cards drawn.
				_check(deck.draw_pile.duplicate(true) == before.get("draw", []),
					label + ": draw pile unchanged")
				# No damage, no Block change, no movement.
				_check(target_after.get("hp") == 30,
					label + ": target HP untouched (no damage)")
				_check(target_after.get("block") == 0,
					label + ": target Block untouched")
				# Full isolation assertions using the before/after snapshot pattern.
				_check(deck.energy == before.get("energy", SNARE_COST) - SNARE_COST,
					label + ": exactly one energy charged (snapshot-isolated)")
				_check(deck.hand.count(card_id) == held_before - 1,
					label + ": exactly one held copy discarded")
				_check(deck.discard_pile == [card_id],
					label + ": discard pile holds exactly the played copy")
				_check(deck.draw_pile.duplicate(true) == before.get("draw", []),
					label + ": draw pile order unchanged")
				_check(party.get_heroes() == before.get("heroes", []),
					label + ": all hero records unchanged (snapshot-isolated)")
				_check(enemies.get_enemies()[target_slot - 1]["statuses"].get("tangled")
					== 1 + int(SNARE_TANGLED[card_id]),
					label + ": target stacked exactly the printed increment")
				_check(enemies.get_enemy(target_slot).get("statuses", {}).get("weak") == 1,
					label + ": target preserved unrelated status")
				# Non-target enemies fully preserved.
				for slot in [1, 2, 3]:
					if slot == target_slot:
						continue
					_check(enemies.get_enemies()[slot - 1] == before.get("enemies", [])[slot - 1],
						label + ": non-target slot %d fully preserved" % slot)
				# RNG state preserved exactly.
				_check(deck._rng.state == before.get("rng_state", 0) and deck._rng.seed == before.get("rng_seed", 0),
					label + ": injected RNG unchanged (snapshot-isolated)")
				# Verify the exact printed increment matches authored data, not pooled.
				_check(int(SNARE_TANGLED[card_id]) == (2 if card_id == SNARE else 3),
					label + ": exact increment is 2 (base) or 3 (+), never pooled")


func _test_snare_ac2_tangled_lifecycle() -> void:
	# AC2: the existing +2 modifier, owner-turn expiry, and zero-damage contract.
	var rules := CombatStatuses.new()
	var batch := CombatStatusTurnBatch.new()

	# Existing Tangled provides flat +2 once to a positive-base hit.
	_check(rules.adjusted_attack_damage(5, {}, {"tangled": 2}) == 7,
		"Tang 2 grants flat +2 to a 5-damage hit")
	_check(rules.adjusted_attack_damage(5, {}, {"tangled": 3}) == 7,
		"Tang 3 still grants flat +2, not +6")
	_check(rules.adjusted_attack_damage(0, {}, {"tangled": 2}) == 0,
		"zero-base hit never borrows Tangled's +2")

	# The card itself applies no damage, no draw, no Block change, no movement, no RNG.
	for card_id in SNARE_IDS:
		var party := _riposte_party(1)
		var enemies := _snare_enemies(20, 1)
		# Inject existing Tangled plus another status to prove isolation.
		enemies._enemies[0]["statuses"] = {"tangled": 1, "exposed": 1}
		var deck := _riposte_deck(card_id, 9300, SNARE_COST)
		var before := _barrage_snapshot(deck, party, enemies)
		before["enemies"] = enemies.get_enemies()
		var result := snare_service.play_card(deck, party, enemies, card_id, 1)
		_check(result.get("ok") == true, card_id + ": plays cleanly")
		_check(result.get("tangled_added") == int(SNARE_TANGLED[card_id]),
			card_id + ": adds its printed Tangled only")
		# No damage, draw, block change, movement, or RNG mutation; full snapshot isolation.
		var enemy_after := enemies.get_enemy(1)
		_check(enemy_after.get("hp") == 20, card_id + ": enemy HP untouched by status-only card")
		_check(enemy_after.get("block") == 0, card_id + ": enemy Block untouched")
		_check(enemy_after.get("statuses", {}).get("tangled") == 1 + int(SNARE_TANGLED[card_id]),
			card_id + ": stacked existing Tangled by printed amount")
		_check(enemy_after.get("statuses", {}).get("exposed") == 1,
			card_id + ": preserved unrelated Exposed status")
		_check(deck.draw_pile.duplicate(true) == before.get("draw", []),
			card_id + ": draw pile unchanged (snapshot-isolated)")
		_check(party.get_heroes() == before.get("heroes", []),
			card_id + ": heroes unchanged (snapshot-isolated)")
		_check(deck._rng.state == before.get("rng_state", 0) and deck._rng.seed == before.get("rng_seed", 0),
			card_id + ": RNG unchanged (snapshot-isolated)")
		# The snapshot before and after differs only by the exact transaction.
		_check(deck.hand.count(card_id) == before.get("hand", []).count(card_id) - 1,
			card_id + ": exactly one copy discarded")
		_check(deck.energy == before.get("energy", SNARE_COST) - SNARE_COST,
			card_id + ": exactly one energy spent")

	# Owner-turn expiry: Tangled counts down by 1 each tick, never clearing early.
	var tick_enemies := _snare_enemies(20, 1)
	tick_enemies._enemies[0]["statuses"] = {"tangled": int(SNARE_TANGLED[SNARE])}
	var roster_before: Array[Dictionary] = tick_enemies.get_enemies().duplicate(true)
	var tick1 := batch.tick_side("enemies", roster_before)
	_check(tick1.get("ok"), "owner-turn tick accepts the bound roster")
	var ticked: Array = tick1["actors"]
	_check(ticked[0]["statuses"].get("tangled") == int(SNARE_TANGLED[SNARE]) - 1,
		"first tick decrements Tangled by 1")
	# Full expiry after enough ticks: the counter reaches 0 and is removed.
	var expiry_enemies := _snare_enemies(20, 1)
	expiry_enemies._enemies[0]["statuses"] = {"tangled": 1}
	var expiry_roster: Array = expiry_enemies.get_enemies()
	var expiry_tick := batch.tick_side("enemies", expiry_roster)
	_check(expiry_tick.get("ok"), "expiry tick accepts the roster")
	var expiry_actors: Array = expiry_tick["actors"]
	_check(not expiry_actors[0]["statuses"].has("tangled"),
		"full expiry removes Tangled completely")
	# Existing shared movement lock: a positive Tangled prevents movement.
	var locked_party := _riposte_party(1)
	locked_party._heroes[0]["statuses"] = {"tangled": 2}
	_check(locked_party.get_hero(1).get("statuses", {}).get("tangled") == 2,
		"movement-lock fixture really stores positive Tangled")


func _test_snare_ac3_rejections() -> void:
	var party := _riposte_party(1)
	var enemies := _snare_enemies(20, 1)
	var deck := _riposte_deck(SNARE, 9400, SNARE_COST)

	# Basic invalid inputs: full snapshot before/after.
	var null_before := _barrage_snapshot(deck, party, enemies)
	var null_deck_result := snare_service.play_card(null, party, enemies, SNARE, 1)
	_check(not null_deck_result.get("ok"), "null deck rejected")
	_check(_barrage_snapshot(deck, party, enemies) == null_before,
		"null deck refusal leaves everything unchanged (full snapshot)")

	# Inactive turn.
	var inactive := _riposte_deck(SNARE, 9410, SNARE_COST, false)
	_check(not inactive.turn_active, "inactive fixture really inactive")
	var inactive_before := _barrage_snapshot(inactive, party, enemies)
	var inactive_result := snare_service.play_card(inactive, party, enemies, SNARE, 1)
	_check(not inactive_result.get("ok") and inactive_result.get("reason") == "inactive_turn",
		"inactive turn rejected")
	_check(_barrage_snapshot(inactive, party, enemies) == inactive_before,
		"inactive turn refusal leaves everything unchanged (full snapshot)")

	# Unsupported / forged / missing IDs with snapshot isolation.
	for unsupported: Variant in ["rag_duelist_tattered_snare_plus_plus",
		"rag_duelist_needle_prick", 0, null, true, StringName("fake_snare"), ""]:
		var r_before := _barrage_snapshot(deck, party, enemies)
		var r: Dictionary = snare_service.play_card(deck, party, enemies, unsupported, 1)
		_check(not r.get("ok"), str(unsupported) + " rejected")
		_check(_barrage_snapshot(deck, party, enemies) == r_before,
			str(unsupported) + ": refusal leaves full snapshot unchanged")

	# Absent card from hand.
	var missing_copy := _riposte_deck("filler_stitch", 9420, SNARE_COST)
	missing_copy.start_turn()
	missing_copy.hand.clear()
	missing_copy.hand.append("filler_stitch")
	missing_copy.energy = SNARE_COST
	var missing_before := _barrage_snapshot(missing_copy, party, enemies)
	var missing_r := snare_service.play_card(missing_copy, party, enemies, SNARE, 1)
	_check(not missing_r.get("ok") and missing_r.get("reason") == "card_not_held",
		"missing held copy rejected")
	_check(_barrage_snapshot(missing_copy, party, enemies) == missing_before,
		"missing copy refusal leaves full snapshot unchanged")

	# Wrong owner seat (only 1-2 allowed).
	var rear_party := _riposte_party(3)
	var rear_before := _barrage_snapshot(_riposte_deck(SNARE, 9430, SNARE_COST), rear_party, enemies)
	var rear_result := snare_service.play_card(_riposte_deck(SNARE, 9430, SNARE_COST),
		rear_party, enemies, SNARE, 1)
	_check(not rear_result.get("ok") and rear_result.get("reason") == "invalid_owner_position",
		"seat 3 rejected for snare")
	_check(_barrage_snapshot(_riposte_deck(SNARE, 9430, SNARE_COST), rear_party, enemies) == rear_before,
		"illegal seat refusal leaves full snapshot unchanged")

	# Downed owner.
	var downed := _riposte_party(1)
	downed.apply_damage(1, downed.get_hero(1)["max_hp"])
	var downed_before := _barrage_snapshot(_riposte_deck(SNARE, 9440, SNARE_COST), downed, enemies)
	var downed_result := snare_service.play_card(_riposte_deck(SNARE, 9440, SNARE_COST),
		downed, enemies, SNARE, 1)
	_check(not downed_result.get("ok") and downed_result.get("reason") == "owner_downed",
		"downed owner rejected")
	_check(_barrage_snapshot(_riposte_deck(SNARE, 9440, SNARE_COST), downed, enemies) == downed_before,
		"downed owner refusal leaves full snapshot unchanged")

	# Insufficient energy.
	var poor := _riposte_deck(SNARE, 9450, 0)
	poor.hand.clear()
	poor.hand.append(SNARE)
	var poor_before := _barrage_snapshot(poor, party, enemies)
	var poor_result := snare_service.play_card(poor, party, enemies, SNARE, 1)
	_check(not poor_result.get("ok") and poor_result.get("reason") == "insufficient_energy",
		"zero energy rejected")
	_check(_barrage_snapshot(poor, party, enemies) == poor_before,
		"insufficient energy refusal leaves full snapshot unchanged")

	# Absent owner party (genuine three-hero party without Rag Duelist).
	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1)["id"] != "rag_duelist"
		and no_owner.get_hero(2)["id"] != "rag_duelist"
		and no_owner.get_hero(3)["id"] != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	var absent_before := _barrage_snapshot(_riposte_deck(SNARE, 9455, SNARE_COST), no_owner, enemies)
	var absent_result := snare_service.play_card(_riposte_deck(SNARE, 9455, SNARE_COST),
		no_owner, enemies, SNARE, 1)
	_check(not absent_result.get("ok") and absent_result.get("reason") == "invalid_party",
		"absent owner rejected")
	_check(_barrage_snapshot(_riposte_deck(SNARE, 9455, SNARE_COST), no_owner, enemies) == absent_before,
		"absent owner refusal leaves full snapshot unchanged")

	# Invalid / slain target with full snapshot isolation.
	var bad_target := _barrage_enemies(20, 1)
	bad_target.apply_damage(1, 20)
	var slain_before := _barrage_snapshot(_riposte_deck(SNARE, 9460, SNARE_COST), party, bad_target)
	var slain_result := snare_service.play_card(_riposte_deck(SNARE, 9460, SNARE_COST),
		party, bad_target, SNARE, 1)
	_check(not slain_result.get("ok") and slain_result.get("reason") == "target_slain",
		"slain target rejected")
	_check(_barrage_snapshot(_riposte_deck(SNARE, 9460, SNARE_COST), party, bad_target) == slain_before,
		"slain target refusal leaves full snapshot unchanged")

	var bad_slot := snare_service.play_card(_riposte_deck(SNARE, 9470, SNARE_COST),
		party, enemies, SNARE, 99)
	_check(not bad_slot.get("ok") and bad_slot.get("reason") == "invalid_target",
		"slot 99 rejected")

	# Malformed status map on target.
	var broken_target := _barrage_enemies(20, 1)
	broken_target._enemies[0]["statuses"] = {"tangled": -1}
	var broken_before := _barrage_snapshot(_riposte_deck(SNARE, 9480, SNARE_COST), party, broken_target)
	var broken_target_result := snare_service.play_card(_riposte_deck(SNARE, 9480, SNARE_COST),
		party, broken_target, SNARE, 1)
	_check(not broken_target_result.get("ok"), "negative tangled rejected before spend")
	_check(_barrage_snapshot(_riposte_deck(SNARE, 9480, SNARE_COST), party, broken_target) == broken_before,
		"malformed status refusal leaves full snapshot unchanged")

	# Refusal leaves deck/party/enemies unchanged (full snapshot comparison using same instance).
	var retry_deck := _riposte_deck(SNARE, 9490, SNARE_COST, false)
	var retry_before := _barrage_snapshot(retry_deck, party, enemies)
	var refused := snare_service.play_card(retry_deck, party, enemies, SNARE, 1)
	_check(not refused.get("ok"), "refused snapshot unchanged")
	_check(_barrage_snapshot(retry_deck, party, enemies) == retry_before,
		"final refusal comparison uses full snapshot equality on same instance")


func _test_snare_forged_catalog() -> void:
	var pool := RagDuelistPoolCards.new()
	var authentic := pool.get_definition(SNARE)
	_check(not authentic.is_empty(), "authentic Tattered Snare available")
	if authentic.is_empty():
		return

	# Create a forged service with a modified real SNARE source definition.
	var forged_service := ForgedSnare.new()
	var forged_record: Dictionary = authentic.duplicate(true)
	# Modify cost, effects, from_positions and upgrade link.
	forged_record["cost"] = 99
	forged_record["effects"] = {"tangled": 99}
	forged_record["from_positions"] = [3]
	forged_record["to_positions"] = [3]
	if forged_record.has("upgrade_id"):
		forged_record["upgrade_id"] = "fake_upgrade"
	if forged_record.has("upgrade_of"):
		forged_record["upgrade_of"] = "fake_base"

	# The unsupported-ID negative case stays separate (unsupported spelling).
	var deck := _riposte_deck(SNARE, 9500, SNARE_COST)
	var party := _riposte_party(1)
	var enemies := _snare_enemies(20, 1)
	var before := _barrage_snapshot(deck, party, enemies)
	var unsupported_result := snare_service.play_card(deck, party, enemies,
		"rag_duelist_tattered_snare_plus_plus", 1)
	_check(not unsupported_result.get("ok") and unsupported_result.get("reason") == "unsupported_card",
		"unsupported spelling rejected as unsupported_card (separate negative)")
	_check(_barrage_snapshot(deck, party, enemies) == before,
		"unsupported spelling refusal leaves full snapshot unchanged")

	# Forged catalog: substitute a modified real SNARE record via the resolver's seam.
	forged_service.forged_id = SNARE
	forged_service.forged = forged_record
	var forged_deck := _riposte_deck(SNARE, 9510, SNARE_COST)
	var forged_party := _riposte_party(1)
	var forged_enemies := _snare_enemies(20, 1)
	var forged_before := _barrage_snapshot(forged_deck, forged_party, forged_enemies)
	var forged_result := forged_service.play_card(forged_deck, forged_party, forged_enemies,
		SNARE, 1)
	_check(not forged_result.get("ok") and forged_result.get("reason") == "catalog_mismatch",
		"forged modified SNARE source record rejected as catalog_mismatch")
	_check(_barrage_snapshot(forged_deck, forged_party, forged_enemies) == forged_before,
		"forged SNARE refusal leaves full snapshot unchanged (deck/party/enemies/RNG)")

	# Forged catalog with the '+' printing as well (modified upgrade link and effects).
	var plus_record: Dictionary = pool.get_definition(SNARE_PLUS).duplicate(true)
	plus_record["cost"] = 99
	plus_record["effects"] = {"tangled": 99}
	plus_record["upgrade_of"] = "fake_base"
	forged_service.forged_id = SNARE_PLUS
	forged_service.forged = plus_record
	var plus_forged_deck := _riposte_deck(SNARE_PLUS, 9520, SNARE_COST)
	var plus_forged_party := _riposte_party(1)
	var plus_forged_enemies := _snare_enemies(20, 1)
	var plus_forged_before := _barrage_snapshot(plus_forged_deck, plus_forged_party, plus_forged_enemies)
	var plus_forged_result := forged_service.play_card(plus_forged_deck, plus_forged_party,
		plus_forged_enemies, SNARE_PLUS, 1)
	_check(not plus_forged_result.get("ok") and plus_forged_result.get("reason") == "catalog_mismatch",
		"forged modified SNARE_PLUS source record rejected as catalog_mismatch")
	_check(_barrage_snapshot(plus_forged_deck, plus_forged_party, plus_forged_enemies) == plus_forged_before,
		"forged SNARE_PLUS refusal leaves full snapshot unchanged")

	# Restore authentic record and prove it plays again.
	forged_service.forged_id = ""
	forged_service.forged = {}
	var restored_deck := _riposte_deck(SNARE, 9530, SNARE_COST)
	var restored_party := _riposte_party(1)
	var restored_enemies := _snare_enemies(20, 1)
	var restored_result := forged_service.play_card(restored_deck, restored_party,
		restored_enemies, SNARE, 1)
	_check(restored_result.get("ok") == true and restored_result.get("card_id") == SNARE,
		"restored authentic SNARE plays after forged refusal")


## Fixture helpers for Snare cards.
func _snare_enemies(target_hp: int, target_position: int,
		decoy_hp: int = 30) -> CombatEnemies:
	var definitions: Array = []
	for index in range(3):
		var slot := index + 1
		definitions.append({
			"id": "snare_foe_" + str(slot),
			"max_hp": target_hp if slot == target_position else decoy_hp,
		})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid(), "snare enemy fixture valid")
	return enemies
