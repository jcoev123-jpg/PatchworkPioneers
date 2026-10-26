extends SceneTree
## Deterministic, headless contract for the V3-1 Scarecrow shoulder-crow strikes.
##
## Crow Dive lives in the dedicated v3 starter catalog and Crow Peck in the v3 reward pool, so neither
## is assumed to be part of the mounted starter deck: every case builds a real seeded CombatDeck that
## genuinely holds the named ID and starts the shared five-draw/three-energy turn. The party is a real
## three-member CombatParty whose Warden/Tinker records come from the authored starter party and whose
## Scarecrow seat is moved with the real adjacent-swap rules. Enemies are real CombatEnemies rosters
## with fixed positions, genuine HP loss and Block applied through gain_block().
##
## The resolver is scene-free. This test claims callable rules-layer behaviour only: no live hand,
## reward, app or run-deck wiring is asserted here.

const HEROES_PATH := "res://data/heroes/starter_party.json"

const DIVE := "scarecrow_crow_dive"
const DIVE_PLUS := "scarecrow_crow_dive_plus"
const PECK := "scarecrow_crow_peck"
const PECK_PLUS := "scarecrow_crow_peck_plus"
const CARD_IDS := [DIVE, DIVE_PLUS, PECK, PECK_PLUS]

## Independent literal expectations copied from the design, never read from the resolver.
const DAMAGE := {DIVE: 3, DIVE_PLUS: 5, PECK: 4, PECK_PLUS: 6}
const CATALOG := {DIVE: "starter", DIVE_PLUS: "starter", PECK: "pool", PECK_PLUS: "pool"}

const FILLERS := ["filler_twig", "filler_bobbin", "filler_scrap", "filler_thread",
	"filler_ribbon"]

var failures: Array[String] = []
var checks: int = 0
var service := CombatScarecrowCrowCards.new()
var _authored: Dictionary = {}


func _initialize() -> void:
	_test_authentic_catalog_and_api()
	_test_ac1_four_printings_pierce_block()
	_test_ac1_partial_and_lethal_hp()
	_test_ac2_backmost_priority_after_deaths()
	_test_ac2_status_rounding()
	_test_ac2_snapshots_and_owner_seats()
	_test_ac3_refusals()
	_test_ac3_retry_after_refusals()
	_test_once_only_payment()
	_test_seeded_replay()
	for failure: String in failures:
		printerr(failure)
	print("combat_scarecrow_crow_cards_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## The service authenticates the exact four printings in their own catalogs and nothing else.
func _test_authentic_catalog_and_api() -> void:
	var starter := ScarecrowStarterCards.new()
	var pool := ScarecrowPoolCards.new()
	for card_id: String in CARD_IDS:
		var source: Variant = starter if CATALOG[card_id] == "starter" else pool
		var definition: Dictionary = source.get_definition(card_id)
		_check(definition.get("id") == card_id, card_id + ": authored catalog record exists")
		_check(definition.get("owner") == "scarecrow", card_id + ": authored owner is Scarecrow")
		_check(definition.get("cost") == 1, card_id + ": authored cost is one energy")
		_check(definition.get("target_kind") == "enemy_back",
			card_id + ": authored target is the backmost living enemy")
		_check(definition.get("from_positions") == [1, 2, 3],
			card_id + ": authored FROM covers all three hero seats")
		_check(definition.get("to_positions") == [1, 2, 3],
			card_id + ": authored TO covers all three enemy slots")
		_check(definition.get("effects") == {"damage": DAMAGE[card_id], "ignore_block": true},
			card_id + ": authored printed damage plus the Block bypass")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(DIVE) == DIVE_PLUS and starter.get_upgrade_id(DIVE_PLUS) == ""
		and pool.get_upgrade_id(PECK) == PECK_PLUS and pool.get_upgrade_id(PECK_PLUS) == "",
		"base and '+' records point at each other in their own catalogs")
	_check(not starter.has_card(PECK) and not pool.has_card(DIVE),
		"the two printings are owned by separate catalogs")
	for unsupported in [
		"scarecrow_fork_jab", "scarecrow_fork_jab_plus", "scarecrow_sack_glare",
		"scarecrow_straw_padding", "scarecrow_sack_grin", "scarecrow_re_stuff",
		"scarecrow_crow_flock", "scarecrow_pitchfork_hook", "scarecrow_harvest_fright",
		"scarecrow_crow_dive_ultra", "scarecrow_crow_peck_plus_plus", "crow_dive",
		"warden_strike", "tinker_pop_shot", "SCARECROW_CROW_DIVE", " scarecrow_crow_dive", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a supported crow strike")
	_check(not service.is_supported_card(5) and not service.is_supported_card(null)
		and not service.is_supported_card(StringName(DIVE)),
		"non-string IDs are never supported")


## AC1: each printing pays once, discards once and pierces the backmost Block.
func _test_ac1_four_printings_pierce_block() -> void:
	for card_id: String in CARD_IDS:
		var party := _party()
		var enemies := _enemies([
			{"max_hp": 10, "hp": 10},
			{"max_hp": 10, "hp": 10},
			{"max_hp": 14, "hp": 14, "block": 9},
		])
		var deck := _deck(card_id)
		var damage: int = DAMAGE[card_id]
		var held_before: int = deck.hand.count(card_id)
		var before := _snapshot(deck, party, enemies)
		_check(before["enemies"][2]["block"] == 9 and 9 > damage,
			card_id + ": fixture Block really exceeds the printed hit")
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 3)
		_check(result.get("ok") == true and result.get("reason") == "applied",
			card_id + ": authorized paid play")
		_check(result.get("card_id") == card_id and result.get("cost") == 1,
			card_id + ": receipt names the authentic card and its one energy")
		_check(result.get("owner_position") == 2 and result.get("target_position") == 3,
			card_id + ": receipt reports the Scarecrow seat and the backmost enemy")
		_check(result.get("base_damage") == damage and result.get("damage") == damage,
			card_id + ": printed base resolves unchanged without statuses")
		_check(result.get("hp_before") == 14 and result.get("hp_after") == 14 - damage
			and result.get("hp_loss") == damage,
			card_id + ": exact HP before, after and loss")
		_check(result.get("block_before") == 9 and result.get("block_after") == 9
			and result.get("block_absorbed") == 0 and result.get("pierced_block") == true,
			card_id + ": the hit pierces rather than spends Block")
		_check(_snapshot(deck, party, enemies) == _expected(before, card_id, 3, damage),
			card_id + ": exact hand/piles/energy/party/enemy/RNG state")
		_check(deck.energy == 2 and deck.hand.count(card_id) == held_before - 1
			and deck.discard_pile.count(card_id) == 1,
			card_id + ": exactly one held copy was charged and discarded")
		_check(enemies.get_enemy(3)["block"] == 9 and enemies.get_enemy(1)["hp"] == 10
			and enemies.get_enemy(2)["hp"] == 10,
			card_id + ": only the backmost HP moved; Block and other enemies stay exact")
		result["hp_after"] = 999
		result["damage"] = 999
		_check(enemies.get_enemy(3)["hp"] == 14 - damage,
			card_id + ": a mutated receipt cannot change the enemy")


## AC1: a partial hit leaves HP, a lethal hit floors at zero and still reports the full damage.
func _test_ac1_partial_and_lethal_hp() -> void:
	for card_id: String in CARD_IDS:
		var damage: int = DAMAGE[card_id]
		var party := _party()
		var enemies := _enemies([{"max_hp": 20, "hp": 20, "block": 4}])
		var deck := _deck(card_id)
		var partial: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(partial.get("ok") == true and partial.get("hp_loss") == damage
			and enemies.get_enemy(1)["hp"] == 20 - damage
			and enemies.get_enemy(1)["hp"] > 0,
			card_id + ": nonlethal hit reduces HP by the printed damage")
		_check(enemies.get_enemy(1)["block"] == 4,
			card_id + ": nonlethal hit leaves Block intact")

		party = _party()
		enemies = _enemies([{"max_hp": 12, "hp": 2, "block": 7}])
		deck = _deck(card_id, 8181)
		var before := _snapshot(deck, party, enemies)
		var lethal: Dictionary = service.play_card(deck, party, enemies, card_id, 1)
		_check(lethal.get("ok") == true and lethal.get("damage") == damage
			and lethal.get("hp_before") == 2 and lethal.get("hp_loss") == 2
			and lethal.get("hp_after") == 0,
			card_id + ": lethal hit reports full damage but only the remaining HP as loss")
		_check(enemies.get_enemy(1)["hp"] == 0 and enemies.get_enemy(1)["block"] == 7,
			card_id + ": lethal hit slays without touching Block")
		_check(_snapshot(deck, party, enemies) == _expected(before, card_id, 1, 2),
			card_id + ": lethal transaction matches the exact oracle")


## AC2: the highest living enemy is hit first; dead rear slots are skipped, never compacted.
func _test_ac2_backmost_priority_after_deaths() -> void:
	var party := _party()
	var enemies := _enemies([
		{"max_hp": 12, "hp": 12, "block": 2},
		{"max_hp": 12, "hp": 12, "block": 2},
		{"max_hp": 12, "hp": 12, "block": 2},
	])
	var deck := _deck(PECK_PLUS, 9191, 5)
	_check(deck.hand.count(PECK_PLUS) >= 3 and deck.energy == 3,
		"rear-priority fixture holds three copies and three energy")
	for wrong in [0, 1, 2, 4, -1]:
		_rejected(deck, party, enemies, PECK_PLUS, wrong, {}, {},
			"front or absent target while the rear enemy lives: " + str(wrong))

	var first: Dictionary = service.play_card(deck, party, enemies, PECK_PLUS, 3)
	_check(first.get("ok") == true and first.get("target_position") == 3
		and enemies.get_enemy(3)["hp"] == 6,
		"first strike hits the living rear slot")
	var second: Dictionary = service.play_card(deck, party, enemies, PECK_PLUS, 3)
	_check(second.get("ok") == true and second.get("hp_loss") == 6
		and enemies.get_enemy(3)["hp"] == 0,
		"second strike lethally clears the rear slot")

	_rejected(deck, party, enemies, PECK_PLUS, 3, {}, {},
		"dead rear slot is no longer a legal target")
	_rejected(deck, party, enemies, PECK_PLUS, 1, {}, {},
		"front slot refused while the middle enemy still lives")
	var third: Dictionary = service.play_card(deck, party, enemies, PECK_PLUS, 2)
	_check(third.get("ok") == true and third.get("target_position") == 2
		and enemies.get_enemy(2)["hp"] == 6,
		"after the rear death the middle slot becomes the backmost living target")
	_check(enemies.get_enemy(1)["hp"] == 12 and enemies.get_enemy(1)["block"] == 2
		and enemies.get_enemy(3)["hp"] == 0 and enemies.get_enemy(3)["block"] == 2,
		"surviving front enemy and both Blocks stay exact")
	_check(deck.energy == 0 and not deck.hand.is_empty(),
		"three strikes spend the whole three-energy turn")

	var two := _enemies([{"max_hp": 9, "hp": 9}, {"max_hp": 9, "hp": 9, "block": 5}])
	var two_deck := _deck(PECK)
	var two_hit: Dictionary = service.play_card(two_deck, _party(), two, PECK, 2)
	_check(two_hit.get("ok") == true and two_hit.get("target_position") == 2
		and two.get_enemy(2)["hp"] == 5 and two.get_enemy(2)["block"] == 5,
		"a two-enemy roster targets slot 2 through its Block")

	# With both rear slots already slain, the front slot becomes the only legal target.
	var front := _enemies([{"max_hp": 12, "hp": 12, "block": 3},
		{"max_hp": 12, "hp": 0}, {"max_hp": 12, "hp": 0}])
	_check(front.is_slain(2) and front.is_slain(3) and not front.is_slain(1),
		"front-only fixture really has two slain rear slots and a living front")
	_rejected(_deck(PECK), _party(), front, PECK, 3, {}, {}, "slain rear slot refused")
	_rejected(_deck(PECK), _party(), front, PECK, 2, {}, {}, "slain middle slot refused")
	var front_hit: Dictionary = service.play_card(_deck(PECK), _party(), front, PECK, 1)
	_check(front_hit.get("ok") == true and front_hit.get("target_position") == 1
		and front.get_enemy(1)["hp"] == 8 and front.get_enemy(1)["block"] == 3,
		"the front slot is hit once both rear slots are dead")


## AC2: existing Weak/Exposed/Tangled rounding, with no status consumed and no RNG drawn.
func _test_ac2_status_rounding() -> void:
	var cases: Array[Dictionary] = [
		{"attacker": {"weak": 1}, "defender": {}, "base": DIVE, "damage": 2,
			"label": "Weak takes 25 percent off"},
		{"attacker": {}, "defender": {"exposed": 1}, "base": DIVE, "damage": 4,
			"label": "Exposed adds 50 percent"},
		{"attacker": {"weak": 2}, "defender": {"exposed": 3}, "base": DIVE, "damage": 3,
			"label": "Weak plus Exposed combines at nine eighths"},
		{"attacker": {}, "defender": {"tangled": 1}, "base": DIVE, "damage": 5,
			"label": "positive-base Tangled adds two after scaling"},
		{"attacker": {}, "defender": {"exposed": 1, "tangled": 2}, "base": DIVE, "damage": 6,
			"label": "Exposed then Tangled keeps one floor"},
		{"attacker": {"weak": 1}, "defender": {}, "base": DIVE_PLUS, "damage": 3,
			"label": "Weak floors once on the five-damage upgrade"},
		{"attacker": {"weak": 1}, "defender": {"tangled": 1}, "base": PECK_PLUS, "damage": 6,
			"label": "Weak then Tangled on six"},
	]
	for spec: Dictionary in cases:
		var card_id: String = spec["base"]
		var label: String = spec["label"] + " (" + card_id + ")"
		var party := _party()
		if not (spec["attacker"] as Dictionary).is_empty():
			party._heroes[1]["statuses"] = (spec["attacker"] as Dictionary).duplicate(true)
		var enemies := _enemies([{"max_hp": 20, "hp": 20}, {"max_hp": 20, "hp": 20}])
		if not (spec["defender"] as Dictionary).is_empty():
			enemies._enemies[1]["statuses"] = (spec["defender"] as Dictionary).duplicate(true)
		var deck := _deck(card_id)
		var before := _snapshot(deck, party, enemies)
		var result: Dictionary = service.play_card(deck, party, enemies, card_id, 2)
		var damage: int = spec["damage"]
		_check(result.get("ok") == true, label + ": authorized play")
		_check(result.get("damage") == damage and result.get("hp_loss") == damage,
			label + ": expected adjusted damage " + str(damage))
		_check(enemies.get_enemy(2)["hp"] == 20 - damage,
			label + ": adjusted damage lands on the backmost enemy")
		_check(party.get_hero(2).get("statuses", {}) == spec["attacker"]
			and enemies.get_enemy(2).get("statuses", {}) == spec["defender"],
			label + ": neither status record was consumed or aged")
		_check(_snapshot(deck, party, enemies) == _expected(before, card_id, 2, damage),
			label + ": exact party, enemy, piles, energy and untouched RNG")


## AC2/AC3: caller snapshots are assertions; the owner is bound by ID, not a fixed seat.
func _test_ac2_snapshots_and_owner_seats() -> void:
	var party := _party()
	party._heroes[1]["statuses"] = {"weak": 1}
	var enemies := _enemies([{"max_hp": 20, "hp": 20}, {"max_hp": 20, "hp": 20}])
	enemies._enemies[1]["statuses"] = {"exposed": 1}
	var deck := _deck(DIVE)
	var before := _snapshot(deck, party, enemies)
	var matching: Dictionary = service.play_card(deck, party, enemies, DIVE, 2,
		{"weak": 1}, {2: {"exposed": 1}})
	_check(matching.get("ok") == true and matching.get("damage") == 3,
		"matching caller snapshots are accepted and keep the nine-eighths result")
	_check(_snapshot(deck, party, enemies) == _expected(before, DIVE, 2, 3),
		"matching snapshots change nothing beyond the hit")

	for seat in [1, 3]:
		var moved := _moved_party(seat)
		var seat_enemies := _enemies([{"max_hp": 9, "hp": 9, "block": 6},
			{"max_hp": 9, "hp": 9, "block": 6}, {"max_hp": 9, "hp": 9, "block": 6}])
		var seat_deck := _deck(PECK, 4141)
		var hit: Dictionary = service.play_card(seat_deck, moved, seat_enemies, PECK, 3)
		_check(hit.get("ok") == true and hit.get("owner_position") == seat
			and seat_enemies.get_enemy(3)["hp"] == 5
			and seat_enemies.get_enemy(3)["block"] == 6,
			"Scarecrow in seat " + str(seat) + " may cast and pierce Block")

	var downed_seat := _party()
	_check(downed_seat.apply_damage(3, 26) and downed_seat.is_downed(3),
		"a different downed hero does not disable the living Scarecrow")
	_check(service.play_card(_deck(PECK), downed_seat, _enemies([{"max_hp": 9, "hp": 9}]),
		PECK, 1).get("ok") == true,
		"living Scarecrow still casts beside a torn ally")


## AC3: every invalid request is refused without changing any mutable state.
func _test_ac3_refusals() -> void:
	var party := _party()
	var enemies := _enemies([{"max_hp": 12, "hp": 12}, {"max_hp": 12, "hp": 12},
		{"max_hp": 12, "hp": 12}])
	var deck := _deck(DIVE)

	_rejected(null, party, enemies, DIVE, 3, {}, {}, "null deck")
	_rejected(deck, null, enemies, DIVE, 3, {}, {}, "null party")
	_rejected(deck, party, null, DIVE, 3, {}, {}, "null enemies")
	_rejected(CombatDeck.new([DIVE, FILLERS[0]], _rng(77)), party, enemies, DIVE, 3, {}, {},
		"inactive turn")

	for unsupported in ["scarecrow_fork_jab", PECK_PLUS + "_plus", "warden_strike", ""]:
		var holding := _deck(unsupported if unsupported != "" else DIVE)
		_rejected(holding, party, enemies, unsupported, 3, {}, {},
			"unsupported or malformed ID " + unsupported)
	_rejected(deck, party, enemies, 7, 3, {}, {}, "non-string ID")
	_rejected(deck, party, enemies, null, 3, {}, {}, "null ID")

	_rejected(deck, party, enemies, DIVE, 3, {"weak": 1}, {}, "stale attacker snapshot")
	_rejected(deck, party, enemies, DIVE, 3, {}, {3: {"exposed": 1}},
		"stale defender snapshot")
	for malformed in [{"weak": "1"}, {"weak": -1}, {"forged": 1}, {"weak": 1.5},
			{"weak": true}, {1: 2}]:
		_rejected(deck, party, enemies, DIVE, 3, malformed, {},
			"malformed attacker snapshot " + str(malformed))
		var broken := _party()
		broken._heroes[1]["statuses"] = malformed
		_rejected(_deck(DIVE), broken, enemies, DIVE, 3, {}, {},
			"malformed live status record " + str(malformed))
	for bad_map in [{"exposed": "1"}, {"exposed": -2}, {"forged": 1}, 5]:
		_rejected(deck, party, enemies, DIVE, 3, {}, {3: bad_map},
			"malformed defender snapshot " + str(bad_map))
	_rejected(deck, party, enemies, DIVE, 3, {}, {9: {}}, "snapshot for an absent enemy")
	_rejected(deck, party, enemies, DIVE, 3, {}, {"three": {}}, "non-integer snapshot key")

	var no_energy := _deck(DIVE)
	_check(no_energy.try_spend_energy(3) and no_energy.energy == 0,
		"no-energy fixture really spent the turn budget")
	_rejected(no_energy, party, enemies, DIVE, 3, {}, {}, "held copy with no energy")

	var no_owner := _party_without_scarecrow()
	_check(no_owner.is_valid() and no_owner.get_hero(1).get("id") == "warden"
		and no_owner.get_hero(2).get("id") == "mender",
		"missing-owner fixture is a valid three-hero party with no Scarecrow")
	_rejected(_deck(DIVE), no_owner, enemies, DIVE, 3, {}, {},
		"party with no Scarecrow owner")

	var duplicate := _party()
	duplicate._heroes[2]["id"] = "scarecrow"
	_check(duplicate.get_hero(2).get("id") == "scarecrow"
		and duplicate.get_hero(3).get("id") == "scarecrow",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected(_deck(DIVE), duplicate, enemies, DIVE, 3, {}, {},
		"duplicate hero identity")

	var torn := _party()
	_check(torn.apply_damage(2, 32) and torn.is_downed(2),
		"torn-owner fixture really has a downed Scarecrow")
	_rejected(_deck(DIVE), torn, enemies, DIVE, 3, {}, {}, "torn (downed) owner")

	var malformed_roster := _party()
	malformed_roster._heroes[1]["hp"] = 99
	_check(malformed_roster.get_hero(2)["hp"] == 99
		and malformed_roster.get_hero(2)["max_hp"] == 32,
		"malformed-roster fixture really has HP above max")
	_rejected(_deck(DIVE), malformed_roster, enemies, DIVE, 3, {}, {},
		"malformed party HP")

	var bad_position := _enemies([{"max_hp": 9, "hp": 9}])
	bad_position._enemies[0]["position"] = 2
	_rejected(_deck(DIVE), party, bad_position, DIVE, 1, {}, {},
		"malformed enemy slot index")
	var bad_hp := _enemies([{"max_hp": 9, "hp": 9}])
	bad_hp._enemies[0]["hp"] = 99
	_rejected(_deck(DIVE), party, bad_hp, DIVE, 1, {}, {}, "malformed enemy HP")

	var slain := _enemies([{"max_hp": 8, "hp": 8}, {"max_hp": 8, "hp": 8}])
	_check(slain.apply_damage(1, 8) and slain.apply_damage(2, 8) and slain.is_defeated(),
		"all-slain fixture really has no living target")
	_rejected(_deck(DIVE), party, slain, DIVE, 2, {}, {}, "no living target remains")
	_rejected(_deck(DIVE), party, CombatEnemies.new([]), DIVE, 1, {}, {},
		"invalid empty enemy roster")

	# The authored FROM is every seat, so an authentic Scarecrow can never be in an illegal
	# position; the catalog check is what rejects a record that prints different seats.
	for card_id: String in CARD_IDS:
		var source: Variant = ScarecrowStarterCards.new() if CATALOG[card_id] == "starter" else ScarecrowPoolCards.new()
		_check((source.get_definition(card_id) as Dictionary).get("from_positions") == [1, 2, 3],
			card_id + ": every authentic seat is a legal FROM position")


## AC3: a rejected attempt never poisons the next authentic one on the same objects.
func _test_ac3_retry_after_refusals() -> void:
	var party := _party()
	var enemies := _enemies([{"max_hp": 15, "hp": 15, "block": 8},
		{"max_hp": 15, "hp": 15, "block": 8}])
	var deck := _deck(PECK)
	_rejected(deck, party, enemies, PECK, 1, {}, {}, "retry: front target first")
	_rejected(deck, party, enemies, PECK, 2, {"weak": 1}, {}, "retry: stale snapshot second")
	_rejected(deck, party, enemies, DIVE, 2, {}, {}, "retry: unheld ID third")
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, PECK, 2)
	_check(result.get("ok") == true and result.get("hp_loss") == 4,
		"retry: the authentic play then succeeds")
	_check(_snapshot(deck, party, enemies) == _expected(before, PECK, 2, 4),
		"retry: exactly one charge, one discard and an untouched RNG")
	_check(enemies.get_enemy(2)["hp"] == 11 and enemies.get_enemy(2)["block"] == 8,
		"retry: the hit pierced the still-full Block")


## Each accepted play pays and discards once; one held copy cannot be replayed.
func _test_once_only_payment() -> void:
	var party := _party()
	var enemies := _enemies([{"max_hp": 40, "hp": 40}])
	var single := CombatDeck.new([DIVE, FILLERS[0], FILLERS[1], FILLERS[2], FILLERS[3]],
		_rng(5150))
	_check(single.start_turn() and single.hand.count(DIVE) == 1 and single.energy == 3,
		"single-copy fixture draws its one genuine copy")
	var first: Dictionary = service.play_card(single, party, enemies, DIVE, 1)
	_check(first.get("ok") == true and not single.hand.has(DIVE),
		"the single copy plays once and leaves the hand")
	var replayed_at := _snapshot(single, party, enemies)
	var replay: Dictionary = service.play_card(single, party, enemies, DIVE, 1)
	_check(replay.get("ok") == false and replay.get("reason") == "card_not_held",
		"a second play of the same ID fails once the copy is discarded")
	_check(_snapshot(single, party, enemies) == replayed_at,
		"the double-play refusal leaves deck, roster and RNG untouched")

	var one := _deck(DIVE, 3311)
	_check(one.try_spend_energy(2) and one.energy == 1,
		"one-energy fixture really has a single energy left")
	var one_enemies := _enemies([{"max_hp": 6, "hp": 6}])
	var one_hit: Dictionary = service.play_card(one, _party(), one_enemies, DIVE, 1)
	_check(one_hit.get("ok") == true and one_hit.get("cost") == 1 and one.energy == 0
		and one_enemies.get_enemy(1)["hp"] == 3,
		"a held crow strike plays with exactly one energy")


## The same seed and the same request sequence produce identical outcomes; no RNG is consumed.
func _test_seeded_replay() -> void:
	var first := _replay_run(90210)
	var second := _replay_run(90210)
	_check(first == second, "seeded replay produces identical final state")
	_check(first["rng_state"] == second["rng_state"],
		"seeded replay consumes no run RNG at any step")
	_check(first["results"].size() == 4 and first["results"][0].get("ok") == true
		and first["results"][1].get("ok") == true and first["results"][2].get("ok") == true
		and first["results"][3].get("ok") == false,
		"seeded replay keeps three legal strikes and the final refusal")
	_check(first["hp"] == [18, 18, 5], "seeded replay lands the exact piercing HP")
	_check(first["blocks"] == [5, 5, 5], "seeded replay leaves every Block untouched")
	_check(first["results"][3].get("reason") == "insufficient_energy",
		"seeded replay's last refusal is the spent-energy rejection")


func _replay_run(seed_value: int) -> Dictionary:
	var party := _party()
	var enemies := _enemies([{"max_hp": 18, "hp": 18, "block": 5},
		{"max_hp": 18, "hp": 18, "block": 5}, {"max_hp": 18, "hp": 18, "block": 5}])
	var deck := CombatDeck.new([DIVE, DIVE_PLUS, PECK, PECK_PLUS, FILLERS[0]], _rng(seed_value))
	_check(deck.start_turn() and deck.hand.size() == 5 and deck.energy == 3,
		"replay deck starts the real five-draw three-energy turn")
	for card_id: String in CARD_IDS:
		_check(deck.hand.has(card_id), "replay fixture holds " + card_id)
	var results: Array = []
	results.append(service.play_card(deck, party, enemies, DIVE, 3))
	results.append(service.play_card(deck, party, enemies, PECK, 3))
	results.append(service.play_card(deck, party, enemies, PECK_PLUS, 3))
	results.append(service.play_card(deck, party, enemies, DIVE_PLUS, 3))
	var snapshot := _snapshot(deck, party, enemies)
	snapshot["results"] = results
	snapshot["hp"] = [enemies.get_enemy(1)["hp"], enemies.get_enemy(2)["hp"],
		enemies.get_enemy(3)["hp"]]
	snapshot["blocks"] = [enemies.get_enemy(1)["block"], enemies.get_enemy(2)["block"],
		enemies.get_enemy(3)["block"]]
	return snapshot


func _rejected(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies, card_id: Variant,
		target_position: int, attacker_statuses: Dictionary,
		enemy_statuses_by_position: Dictionary, label: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var result: Dictionary = service.play_card(deck, party, enemies, card_id, target_position,
		attacker_statuses, enemy_statuses_by_position)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": unchanged party, enemies, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state: one energy, one discarded held copy, one pierced HP loss.
func _expected(before: Dictionary, card_id: String, target_position: int,
		hp_loss: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected["energy"] -= 1
	expected["state_energy"] -= 1
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var enemy: Dictionary = expected["enemies"][target_position - 1]
	enemy["hp"] = maxi(0, int(enemy["hp"]) - hp_loss)
	return expected


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	var result: Dictionary = {}
	if party != null:
		result["heroes"] = party.get_heroes()
		result["party_valid"] = party.is_valid()
	if enemies != null:
		result["enemies"] = enemies.get_enemies()
		result["enemies_valid"] = enemies.is_valid()
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


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## A real five-card hand from six cards, so at least two copies of the named ID are held.
func _deck(card_id: String, seed_value: int = 6452, copies: int = 3) -> CombatDeck:
	var ids: Array[String] = []
	for _copy in range(copies):
		ids.append(card_id)
	var filler_index := 0
	while ids.size() < 6:
		ids.append(FILLERS[filler_index])
		filler_index += 1
	var deck := CombatDeck.new(ids, _rng(seed_value))
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == 5 and deck.hand.count(card_id) >= mini(copies, 2),
		card_id + ": real seeded five-card hand holding genuine copies")
	return deck


## Real enemy slots with genuine HP loss and Block from the model's own state APIs.
func _enemies(specs: Array) -> CombatEnemies:
	var definitions: Array = []
	for index in range(specs.size()):
		definitions.append({"id": "fixture_crow_target_" + str(index + 1),
			"max_hp": int(specs[index]["max_hp"])})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_enemies().size() == specs.size(),
		"fixture builds a real indexed enemy roster")
	for index in range(specs.size()):
		var lost: int = int(specs[index]["max_hp"]) - int(specs[index]["hp"])
		if lost > 0:
			_check(enemies.apply_damage(index + 1, lost),
				"fixture enemy " + str(index + 1) + " really lost HP")
		var block := int(specs[index].get("block", 0))
		if block > 0:
			_check(enemies.gain_block(index + 1, block),
				"fixture enemy " + str(index + 1) + " really gained Block")
	return enemies


func _authored_party_records() -> Dictionary:
	if not _authored.is_empty():
		return _authored
	var raw: String = FileAccess.get_file_as_string(HEROES_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	_check(not raw.is_empty() and parsed is Array and parsed.size() == CombatParty.PARTY_SIZE,
		"real authored starter party file supplies all three heroes")
	if not parsed is Array or parsed.size() != CombatParty.PARTY_SIZE:
		return {}
	for record in parsed:
		if not record is Dictionary:
			continue
		var hero: Dictionary = record.duplicate(true)
		if hero.get("max_hp") is float:
			hero["max_hp"] = int(hero["max_hp"])
		_authored[str(hero.get("id", ""))] = hero
	return _authored


## A real three-member party: authored Warden and Tinker records plus the Scarecrow in the middle.
## No authored Scarecrow party record ships yet (the live party picker is a later task), so only the
## seat definition is a fixture; the two neighbours and the party model itself are authentic.
func _party() -> CombatParty:
	var records := _authored_party_records()
	if not records.has("warden") or not records.has("tinker"):
		_check(false, "authored starter party is missing a fixture neighbour")
		return CombatParty.new([])
	var definitions: Array = [
		(records["warden"] as Dictionary).duplicate(true),
		{"id": "scarecrow", "name": "Scarecrow", "max_hp": 32},
		(records["tinker"] as Dictionary).duplicate(true),
	]
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(1).get("id") == "warden"
		and party.get_hero(2).get("id") == "scarecrow" and party.get_hero(2).get("max_hp") == 32
		and party.get_hero(3).get("id") == "tinker",
		"valid real CombatParty with the Scarecrow in the middle seat")
	return party


func _party_without_scarecrow() -> CombatParty:
	var records := _authored_party_records()
	return CombatParty.new([
		(records["warden"] as Dictionary).duplicate(true),
		{"id": "mender", "name": "Mender", "max_hp": 20},
		(records["tinker"] as Dictionary).duplicate(true),
	])


## A genuine adjacent swap through the real position rules, not a hand-built roster.
func _moved_party(target_position: int) -> CombatParty:
	var party := _party()
	var move_id := "fixture_scarecrow_shift"
	var moving := CombatDeck.new([move_id, move_id], _rng(345))
	_check(moving.start_turn(), "position fixture begins a legitimate shared turn")
	var direction := -1 if target_position < 2 else 1
	var definition := {"id": move_id, "owner": "scarecrow", "cost": 0,
		"from_positions": [1, 2, 3], "action_kind": "adjacent_swap", "direction": direction}
	_check(CombatPositionSwaps.play_move_card(moving, party, move_id, definition),
		"actual adjacent move shifts the Scarecrow toward slot " + str(target_position))
	_check(party.get_hero(target_position).get("id") == "scarecrow"
		and party.get_hero(target_position).get("position") == target_position,
		"Scarecrow identity is really at actual slot " + str(target_position))
	return party
