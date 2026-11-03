extends SceneTree
## V3-1 focused headless regression for Yarn Ranger's paid Unspool (7) and
## Unspool+ (10) over a genuine four-capacity roster. The roster is an explicitly
## opted-in post-summon/post-split snapshot built from local valid enemy records:
## four real, occupied original slots, the fourth being the summoned broodling.
## Nothing here reads data/enemies/run_enemies.json.
##
## The paid service must walk the authoritative records in original order and
## hit every LIVING foe whose authentic Tangled count is positive, including a
## fourth-only Tangled foe. Untangled, slain and unused slots are never targets
## and positions never compact. Blocks, statuses, Thorns and Enrage are the real
## shared rules; a cast pays exactly two energy, discards exactly one held copy
## and draws no RNG. Default-capacity 2-3-foe battles keep their old outcomes,
## and every unlawful request is a complete no-op including the seeded RNG.
##
## No live hand, app flow or mounted play is claimed here: the brief scopes this
## task to the paid rules service, not the separately owned app/hand wiring.

const BASE_ID := "yarn_ranger_unspool"
const PLUS_ID := "yarn_ranger_unspool_plus"
const IDS: Array[String] = [BASE_ID, PLUS_ID]
const PRINTED_DAMAGE := {BASE_ID: 7, PLUS_ID: 10}
const FOURTH_ID := "moth_swarm_broodling"
const SEED := 4751793726168
## Four fillers plus the printing fill exactly the five-card opening draw, so the
## seeded real CombatDeck genuinely holds the card without a seed search.
const FILLER: Array[String] = ["warden_strike", "warden_brace",
	"seamstress_stitch", "tinker_scrap"]

var failures: Array[String] = []
var checks := 0
var resolver := CombatYarnRangerUnspoolCards.new()
var rules := CombatStatuses.new()


func _initialize() -> void:
	_test_printings_and_capacity()
	_test_fixture_is_genuine()
	_test_real_summon_snapshot()
	_test_fourth_only_tangled()
	_test_mixed_four_slot_receipts()
	_test_keyword_fourth()
	_test_default_and_partial_rosters()
	_test_refusals()
	if failures.is_empty():
		print("combat_yarn_ranger_unspool_four_foe_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr("FAIL: " + failure)
		print("combat_yarn_ranger_unspool_four_foe_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ---------------------------------------------------------------------------------------------
# The two shipped printings and the model's real capacities. No catalog total or
# full ordered catalog list is asserted, only the required IDs and values.
# ---------------------------------------------------------------------------------------------

func _test_printings_and_capacity() -> void:
	_check(CombatEnemies.MAX_ENEMIES == 3 and CombatEnemies.OPT_IN_MAX_ENEMIES == 4,
		"model still prints three default and four explicit opt-in slots")
	var catalog := YarnRangerPoolCards.new()
	for id: String in IDS:
		var definition: Dictionary = catalog.get_definition(id)
		_check(definition.get("id") == id and definition.get("owner") == "yarn_ranger"
			and definition.get("cost") == 2 and definition.get("from_positions") == [2, 3]
			and definition.get("to_positions") == [1, 2, 3]
			and definition.get("target_kind") == "enemy_all",
			id + ": authentic cost, seats and unchanged printed TO metadata")
		var effects: Dictionary = definition.get("effects", {})
		_check(int(effects.get("damage", 0)) == int(PRINTED_DAMAGE[id]),
			id + ": printed base damage")
		_check(effects.get("requires_target_status") == "tangled"
			and effects.get("living_targets_only") == true,
			id + ": still requires a living Tangled target")


func _test_fixture_is_genuine() -> void:
	var enemies := _four_enemies()
	_check(enemies.get_enemies().size() == 4
		and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES,
		"fixture really occupies four slots under the explicit opt-in")
	var positions: Array[int] = []
	var ids: Array[String] = []
	for foe: Dictionary in enemies.get_enemies():
		positions.append(int(foe["position"]))
		ids.append(str(foe["id"]))
	_check(positions == [1, 2, 3, 4] and ids[3] == FOURTH_ID,
		"four living foes occupy original slots 1-4 with the summoned fourth last")
	_check(enemies.get_enemy(4).get("id") == FOURTH_ID
		and enemies.get_enemy(4).get("position") == 4
		and int(enemies.get_enemy(4).get("hp", 0)) > 0,
		"the fourth foe is a real occupied, living authoritative record")
	for seat in [2, 3]:
		var party := _party(seat)
		_check(party.is_valid() and party.get_hero(seat).get("id") == "yarn_ranger"
			and not party.is_downed(seat) and party.get_heroes().size() == 3,
			"real three-hero party has a living Yarn Ranger in seat " + str(seat))
	# Four definitions through the default constructor stay empty and inert, so
	# this change never opens a four-foe STARTING Fight.
	var default_roster := CombatEnemies.new([
		{"id": "start_one", "max_hp": 10}, {"id": "start_two", "max_hp": 10},
		{"id": "start_three", "max_hp": 10}, {"id": "start_four", "max_hp": 10}])
	_check(default_roster.get_capacity() == CombatEnemies.MAX_ENEMIES
		and not default_roster.is_valid() and default_roster.get_enemies().is_empty(),
		"default-capacity four-definition construction is still inert")


# ---------------------------------------------------------------------------------------------
# AC1: a genuine model summon (not only a four-record construction) really makes
# position 4 occupied, and the same paid resolver reaches that summoned foe.
# ---------------------------------------------------------------------------------------------

func _test_real_summon_snapshot() -> void:
	var mother := {
		"id": "moth_swarm", "name": "Moth Swarm", "max_hp": 21,
		"art_path": "res://assets/paper/enemies/moth_swarm.png",
		"chew_block_on_attack": true,
		"intent": {"target": "front", "actions": [
			{"type": "snip_block", "amount": 0, "weight": 2},
			{"type": "attack", "amount": 7, "weight": 3},
			{"type": "debuff", "status": "weak", "amount": 1, "weight": 1},
			{"type": "summon", "amount": 0, "weight": 1},
			{"type": "attack", "amount": 6, "hits": 2, "move": "attack2",
				"weight": 1}]}}
	var enemies := CombatEnemies.new([mother, {"id": "lair_guard", "max_hp": 40},
		{"id": "lair_ward", "max_hp": 40}], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid() and enemies.get_enemies().size() == 3,
		"genuine pre-summon roster holds three occupied records")
	var summon := enemies.stage_broodling(1)
	_check(summon == {"ok": true, "spawned": true, "position": 4}
		and enemies.get_enemies().size() == 4
		and enemies.get_enemy(4).get("id") == CombatEnemies.BROODLING_ID
		and enemies.get_enemy(4).get("position") == 4,
		"the real summon model fills occupied slot 4 with the broodling")
	enemies._enemies[3]["statuses"] = {"tangled": 1}
	var receipt := _receipt(int(PRINTED_DAMAGE[BASE_ID]), {},
		enemies.get_enemy(4))
	var result := resolver.play_card(_deck(BASE_ID), _party(2), enemies, BASE_ID)
	_check(result.get("ok") == true and result.get("hits", []).size() == 1
		and result.get("hits", [])[0].get("position") == 4
		and result.get("hits", [])[0].get("damage") == receipt["damage"],
		"the paid resolver reaches a genuinely summoned fourth Tangled foe")


# ---------------------------------------------------------------------------------------------
# AC1: slot 4 is the ONLY living Tangled enemy while slots 1-3 are alive but
# untangled. The cast is legal and hits exactly position 4 once per printing and
# legal Ranger seat. Payment, discard, statuses, identities and RNG stay exact.
# ---------------------------------------------------------------------------------------------

func _test_fourth_only_tangled() -> void:
	for id: String in IDS:
		for seat in [2, 3]:
			var label := "%s / seat %d / fourth only" % [id, seat]
			var deck := _deck(id)
			var party := _party(seat)
			var enemies := _four_enemies()
			_check(enemies.apply_statuses({1: {"bleed": 1}, 2: {"weak": 1}}),
				label + ": slots 1-2 carry authentic non-Tangled statuses")
			_check(enemies.gain_block(2, 4) and enemies.gain_block(3, 2),
				label + ": slots 2-3 really hold pre-hit Block")
			enemies._enemies[3]["statuses"] = {"tangled": 1}
			_check(enemies.get_enemy(4).get("statuses") == {"tangled": 1},
				label + ": only the occupied fourth slot is Tangled")
			var before := _snapshot(deck, party, enemies)
			var attacker: Dictionary = party.get_hero(seat).get("statuses", {})
			var receipt := _receipt(int(PRINTED_DAMAGE[id]), attacker,
				enemies.get_enemy(4))
			var hits_expected: Array = [{"position": 4,
				"damage": receipt["damage"],
				"block_absorbed": receipt["block_absorbed"],
				"hp_loss": receipt["hp_loss"]}]
			var result := resolver.play_card(deck, party, enemies, id)
			_check(result.get("ok") == true and result.get("hits") == hits_expected,
				label + ": a fourth-only Tangled foe alone makes the cast legal and is hit once")
			_check(_snapshot(deck, party, enemies) == _apply_receipts(before, hits_expected,
				seat, id), label + ": exact receipt, one 2-energy payment, one discard and RNG")
			_check(enemies.get_enemy(4).get("statuses") == {"tangled": 1}
				and enemies.get_enemy(4).get("position") == 4
				and enemies.get_enemy(4).get("id") == FOURTH_ID,
				label + ": Tangled is never aged and the fourth identity/position never moves")
			_check(enemies.get_enemy(1).get("hp") == 40
				and enemies.get_enemy(2).get("hp") == 40
				and enemies.get_enemy(3).get("hp") == 40
				and enemies.get_enemy(2).get("block") == 4
				and enemies.get_enemy(3).get("block") == 2
				and enemies.get_enemy(1).get("statuses") == {"bleed": 1},
				label + ": untangled slots 1-3 never take the strike")


# ---------------------------------------------------------------------------------------------
# AC2: mixed Tangled 1/4, untangled 2, slain Tangled 3 with pre-hit Block and
# statuses. Both living Tangled slots take one independent status-adjusted hit
# through Block; the slain slot and the untangled slot are complete non-participants.
# ---------------------------------------------------------------------------------------------

func _test_mixed_four_slot_receipts() -> void:
	for id: String in IDS:
		for seat in [2, 3]:
			var label := "%s / seat %d / mixed" % [id, seat]
			var deck := _deck(id)
			var party := _party(seat)
			party._heroes[seat - 1]["statuses"] = {"weak": 1}
			var enemies := _four_enemies()
			enemies._enemies[0]["statuses"] = {"tangled": 2, "exposed": 1}
			_check(enemies.apply_statuses({2: {"bleed": 2}}),
				label + ": untangled slot 2 carries a real Bleed counter")
			enemies._enemies[2]["statuses"] = {"tangled": 3, "exposed": 1}
			enemies._enemies[2]["hp"] = 0
			enemies._enemies[2]["block"] = 4
			enemies._enemies[3]["statuses"] = {"tangled": 1, "weak": 1}
			_check(enemies.gain_block(4, 5),
				label + ": living fourth Tangled foe starts with Block")
			_check(enemies.is_slain(3) and enemies.get_enemy(3).get("block") == 4
				and enemies.get_enemy(3).get("statuses") == {"tangled": 3, "exposed": 1},
				label + ": real slain slot 3 keeps its Tangled/Exposed statuses and Block")
			var before := _snapshot(deck, party, enemies)
			var attacker: Dictionary = party.get_hero(seat).get("statuses", {})
			var hits_expected: Array = []
			for pos in [1, 4]:
				var receipt := _receipt(int(PRINTED_DAMAGE[id]), attacker,
					before["foes"][pos - 1])
				hits_expected.append({"position": pos, "damage": receipt["damage"],
					"block_absorbed": receipt["block_absorbed"],
					"hp_loss": receipt["hp_loss"]})
			var result := resolver.play_card(deck, party, enemies, id)
			_check(result.get("ok") == true and result.get("hits") == hits_expected,
				label + ": living Tangled slots 1 and 4 are hit once each, in original order")
			_check(_snapshot(deck, party, enemies) == _apply_receipts(before, hits_expected,
				seat, id), label + ": exact combined receipt, payment and untouched records")
			_check(enemies.get_enemy(2).get("hp") == 40
				and enemies.get_enemy(2).get("statuses") == {"bleed": 2},
				label + ": untangled slot 2 is never a target")
			_check(enemies.get_enemy(3).get("hp") == 0
				and enemies.get_enemy(3).get("block") == 4
				and enemies.get_enemy(3).get("position") == 3,
				label + ": slain Tangled slot 3 keeps slot, Block and statuses")
			_check(enemies.get_enemy(4).get("statuses") == {"tangled": 1, "weak": 1}
				and enemies.get_enemy(4).get("position") == 4,
				label + ": fourth statuses are untouched and never aged")


# ---------------------------------------------------------------------------------------------
# AC2: a keyword-bearing fourth foe. Its own Thorns retaliates once through the
# Ranger's Block before HP, and its Enrage gains exactly one stack for exactly
# one confirmed hit; the unrelated Tangled slot 1 triggers neither.
# ---------------------------------------------------------------------------------------------

func _test_keyword_fourth() -> void:
	for id: String in IDS:
		for seat in [2, 3]:
			var label := "%s / seat %d / keyword fourth" % [id, seat]
			var deck := _deck(id)
			var party := _party(seat)
			_check(party.gain_block(seat, 2),
				label + ": Ranger Block really guards the Thorns contact")
			var enemies := _four_enemies()
			enemies._enemies[0]["statuses"] = {"tangled": 1}
			enemies._enemies[3]["statuses"] = {"tangled": 1}
			enemies._enemies[3]["thorns"] = 3
			enemies._enemies[3]["enrage"] = true
			enemies._enemies[3]["enrage_stacks"] = 0
			var before := _snapshot(deck, party, enemies)
			var attacker: Dictionary = party.get_hero(seat).get("statuses", {})
			var hits_expected: Array = []
			for pos in [1, 4]:
				var receipt := _receipt(int(PRINTED_DAMAGE[id]), attacker,
					before["foes"][pos - 1])
				hits_expected.append({"position": pos, "damage": receipt["damage"],
					"block_absorbed": receipt["block_absorbed"],
					"hp_loss": receipt["hp_loss"]})
			var result := resolver.play_card(deck, party, enemies, id)
			_check(result.get("ok") == true and result.get("hits") == hits_expected,
				label + ": both living Tangled slots take their own exact hit")
			_check(_snapshot(deck, party, enemies) == _apply_receipts(before, hits_expected,
				seat, id), label + ": whole-battle state matches independent receipts")
			_check(enemies.get_enemy(4).get("enrage_stacks") == 1,
				label + ": the fourth foe's Enrage gains exactly one stack for one hit")
			_check(not enemies.get_enemy(1).has("enrage_stacks"),
				label + ": the unrelated Tangled slot 1 gains no Enrage stack")
			_check(enemies.get_enemy(4).get("thorns") == 3
				and enemies.get_enemy(4).get("statuses") == {"tangled": 1},
				label + ": keyword metadata and Tangled count stay untouched")
			var ranger: Dictionary = party.get_hero(seat)
			_check(ranger.get("block") == 0 and ranger.get("hp") == 29,
				label + ": Thorns 3 spent Block 2 then exactly 1 HP, once")


# ---------------------------------------------------------------------------------------------
# AC3: ordinary default-capacity 2-3-foe battles keep their original eligible
# targets and damage, and a four-capacity roster with an unused slot never
# invents a fourth target.
# ---------------------------------------------------------------------------------------------

func _test_default_and_partial_rosters() -> void:
	for size in [2, 3]:
		for id: String in IDS:
			for seat in [2, 3]:
				var label := "%s / seat %d / default %d foes" % [id, seat, size]
				var deck := _deck(id)
				var party := _party(seat)
				var enemies := _default_enemies(size)
				enemies._enemies[0]["statuses"] = {"tangled": 2}
				var expected_positions: Array[int] = [1]
				if size == 2:
					enemies._enemies[1]["statuses"] = {"tangled": 1}
					expected_positions.append(2)
				else:
					enemies._enemies[1]["statuses"] = {"bleed": 1}
					enemies._enemies[2]["statuses"] = {"tangled": 3}
					expected_positions.append(3)
				var before := _snapshot(deck, party, enemies)
				var attacker: Dictionary = party.get_hero(seat).get("statuses", {})
				var hits_expected: Array = []
				for pos in expected_positions:
					var receipt := _receipt(int(PRINTED_DAMAGE[id]), attacker,
						before["foes"][pos - 1])
					hits_expected.append({"position": pos, "damage": receipt["damage"],
						"block_absorbed": receipt["block_absorbed"],
						"hp_loss": receipt["hp_loss"]})
				var result := resolver.play_card(deck, party, enemies, id)
				_check(result.get("ok") == true and result.get("hits") == hits_expected,
					label + ": original eligible slots and damage are unchanged")
				_check(_snapshot(deck, party, enemies) == _apply_receipts(before,
					hits_expected, seat, id), label + ": payment and state are unchanged")
	# An opted-in four-capacity roster is legal before a summon with only three
	# occupied records; the unused slot 4 is never a target.
	var deck := _deck(BASE_ID)
	var party := _party(2)
	var partial := CombatEnemies.new([
		{"id": "capacity_one", "max_hp": 30},
		{"id": "capacity_two", "max_hp": 30},
		{"id": "capacity_three", "max_hp": 30}], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(partial.is_valid() and partial.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and partial.get_enemies().size() == 3,
		"opt-in four-capacity roster may genuinely hold only three actors")
	partial._enemies[0]["statuses"] = {"tangled": 1}
	partial._enemies[2]["statuses"] = {"tangled": 1}
	var before := _snapshot(deck, party, partial)
	var attacker: Dictionary = party.get_hero(2).get("statuses", {})
	var hits_expected: Array = []
	for pos in [1, 3]:
		var receipt := _receipt(int(PRINTED_DAMAGE[BASE_ID]), attacker,
			before["foes"][pos - 1])
		hits_expected.append({"position": pos, "damage": receipt["damage"],
			"block_absorbed": receipt["block_absorbed"],
			"hp_loss": receipt["hp_loss"]})
	var result := resolver.play_card(deck, party, partial, BASE_ID)
	_check(result.get("ok") == true and result.get("hits") == hits_expected
		and result.get("hits", []).size() == 2,
		"the unused capacity slot is not a target and no fourth hit is invented")
	_check(_snapshot(deck, party, partial) == _apply_receipts(before, hits_expected, 2,
		BASE_ID), "partial opt-in roster pays once with no invented slot")


# ---------------------------------------------------------------------------------------------
# AC3: every unlawful request fails BEFORE spending, discarding, damaging,
# changing statuses/metadata or advancing the seeded RNG.
# ---------------------------------------------------------------------------------------------

func _test_refusals() -> void:
	var id := BASE_ID
	# No living Tangled target at all, including an untangled fourth.
	_expect_refusal("four living but untangled foes", _deck(id), _party(2),
		_four_enemies(), id)
	# A perfectly legal fourth-only roster still cannot pay with one energy.
	var broke := _deck(id)
	_check(broke.try_spend_energy(2) and broke.energy == 1 and broke.hand.has(id),
		"energy-short fixture really holds one energy and the card")
	var fourth_tangled := _four_enemies()
	fourth_tangled._enemies[3]["statuses"] = {"tangled": 1}
	_expect_refusal("fourth-only Tangled foe with one energy", broke, _party(2),
		fourth_tangled, id)
	# Inactive turn, missing real held copy, no cost change.
	var inactive := CombatDeck.new([id], _rng())
	inactive.hand.append(id)
	_check(not inactive.turn_active and inactive.hand.has(id),
		"inactive-turn fixture really has not started its turn")
	_expect_refusal("inactive turn", inactive, _party(2), fourth_tangled, id)
	var absent := _deck(id)
	_check(absent.discard_played(id) and not absent.hand.has(id),
		"missing-copy fixture really holds no printed copy")
	_expect_refusal("missing held copy", absent, _party(2), fourth_tangled, id)
	# Dead or illegally seated owner.
	var downed := _party(3)
	_check(downed.apply_damage(3, 999) and downed.is_downed(3),
		"downed-Ranger fixture is genuinely downed")
	_expect_refusal("downed Yarn Ranger", _deck(id), downed, fourth_tangled, id)
	var front := CombatParty.new([
		{"id": "yarn_ranger", "max_hp": 30},
		{"id": "warden", "max_hp": 40},
		{"id": "seamstress", "max_hp": 26}])
	_check(front.get_hero(1).get("id") == "yarn_ranger",
		"front-seat fixture really places the Ranger in seat 1")
	_expect_refusal("Yarn Ranger in illegal seat 1", _deck(id), front, fourth_tangled, id)
	# Unauthentic card ID and a malformed attacker status snapshot.
	_expect_refusal("unauthentic card ID", _deck(id), _party(2), fourth_tangled,
		"yarn_ranger_unspool_plus_plus")
	var bad_owner := _party(2)
	bad_owner._heroes[1]["statuses"] = {"weak": "1"}
	_check(bad_owner.get_hero(2).get("statuses") == {"weak": "1"},
		"malformed-owner fixture really stores a string Weak counter")
	_expect_refusal("malformed owner status", _deck(id), bad_owner, fourth_tangled, id)
	# A malformed eligible fourth foe: bad status map/token, bad keyword metadata,
	# an impossible record, a tampered capacity or a roster that was never opted in.
	var malformed: Array[Dictionary] = [
		{"label": "status map is not a dictionary", "field": "statuses", "value": "bad"},
		{"label": "status token is not an integer", "field": "exposed", "value": "1"},
		{"label": "Thorns is negative", "field": "thorns", "value": -1},
		{"label": "Enrage flag is not a bool", "field": "enrage", "value": 1},
		{"label": "Enrage stacks exceed the cap", "field": "enrage_stacks", "value": 4},
		{"label": "HP exceeds its maximum", "field": "hp", "value": 41},
		{"label": "position does not match its slot", "field": "position", "value": 5},
		{"label": "ID is empty", "field": "id", "value": ""},
	]
	for entry: Dictionary in malformed:
		var enemies := _four_enemies()
		enemies._enemies[3]["statuses"] = {"tangled": 1}
		match entry["field"]:
			"statuses":
				enemies._enemies[3]["statuses"] = entry["value"]
			"exposed":
				enemies._enemies[3]["statuses"]["exposed"] = entry["value"]
			"thorns":
				enemies._enemies[3]["thorns"] = entry["value"]
			"enrage":
				enemies._enemies[3]["enrage"] = entry["value"]
			"enrage_stacks":
				enemies._enemies[3]["enrage_stacks"] = entry["value"]
			"hp":
				enemies._enemies[3]["hp"] = entry["value"]
			"position":
				enemies._enemies[3]["position"] = entry["value"]
			"id":
				enemies._enemies[3]["id"] = entry["value"]
		_expect_refusal("malformed eligible fourth: " + str(entry["label"]),
			_deck(id), _party(2), enemies, id)
	var tampered := _four_enemies()
	tampered._enemies[3]["statuses"] = {"tangled": 1}
	tampered._capacity = CombatEnemies.OPT_IN_MAX_ENEMIES + 1
	_check(tampered.is_valid() and tampered.get_capacity() == 5,
		"tampered-capacity fixture really claims five slots")
	_expect_refusal("tampered five-slot capacity", _deck(id), _party(2), tampered, id)
	var not_opted_in := CombatEnemies.new([
		{"id": "no_opt_one", "max_hp": 10}, {"id": "no_opt_two", "max_hp": 10},
		{"id": "no_opt_three", "max_hp": 10},
		{"id": FOURTH_ID, "max_hp": 10, "statuses": {"tangled": 1}}])
	_check(not not_opted_in.is_valid() and not_opted_in.get_enemies().is_empty()
		and not_opted_in.get_capacity() == CombatEnemies.MAX_ENEMIES,
		"non-opted-in four-foe fixture is empty and inert")
	_expect_refusal("four foes without the explicit opt-in", _deck(id), _party(2),
		not_opted_in, id)


func _expect_refusal(label: String, deck: CombatDeck, party: CombatParty,
		enemies: CombatEnemies, card_id: String) -> void:
	var before := _snapshot(deck, party, enemies)
	var result := resolver.play_card(deck, party, enemies, card_id)
	_check(result.get("ok") == false, label + ": refused")
	_check(result.get("hits", []) == [], label + ": reports no hits")
	_check(_snapshot(deck, party, enemies) == before,
		label + ": deck, energy, hand, discard, party, roster and seeded RNG unchanged")


# ---------------------------------------------------------------------------------------------
# Fixtures and receipt oracle. All gameplay numbers come from the shared rules.
# ---------------------------------------------------------------------------------------------

## Explicitly opted-in four-capacity roster from local valid records. It is the
## authoritative snapshot after a summon/split: four occupied original slots,
## the fourth being the summoned broodling. No run-enemy catalog is read.
func _four_enemies() -> CombatEnemies:
	var definitions: Array = [
		{"id": "moth_swarm", "name": "Moth Swarm", "max_hp": 40},
		{"id": "patch_imp", "name": "Patch Imp", "max_hp": 40},
		{"id": "stitch_horror", "name": "Stitch Horror", "max_hp": 40},
		{"id": FOURTH_ID, "name": "Moth Broodling", "max_hp": 40},
	]
	var enemies := CombatEnemies.new(definitions, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(enemies.is_valid()
		and enemies.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES,
		"explicit opt-in four-capacity roster is valid")
	return enemies


func _default_enemies(size: int) -> CombatEnemies:
	var definitions: Array = []
	for index in range(size):
		definitions.append({"id": "default_foe_%d" % (index + 1), "max_hp": 40})
	var enemies := CombatEnemies.new(definitions)
	_check(enemies.is_valid() and enemies.get_capacity() == CombatEnemies.MAX_ENEMIES
		and enemies.get_enemies().size() == size,
		"real default-capacity roster of " + str(size) + " foe(s)")
	return enemies


func _party(ranger_seat: int) -> CombatParty:
	var order: Array[String] = ["warden", "seamstress"]
	order.insert(ranger_seat - 1, "yarn_ranger")
	var hit_points := {"yarn_ranger": 30, "warden": 40, "seamstress": 26}
	var definitions: Array = []
	for hero_id: String in order:
		definitions.append({"id": hero_id, "max_hp": hit_points[hero_id]})
	var party := CombatParty.new(definitions)
	_check(party.is_valid() and party.get_hero(ranger_seat).get("id") == "yarn_ranger"
		and not party.is_downed(ranger_seat),
		"real three-hero party with a living Yarn Ranger in seat " + str(ranger_seat))
	return party


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	return rng


## Real seeded CombatDeck whose five-card opening draw genuinely holds the
## printing (four filler cards plus the printing fill TURN_DRAW exactly).
func _deck(card_id: String) -> CombatDeck:
	var cards: Array[String] = [card_id]
	cards.append_array(FILLER)
	var deck := CombatDeck.new(cards, _rng())
	_check(deck.start_turn() and deck.turn_active and deck.energy == 3
		and deck.hand.size() == CombatDeck.TURN_DRAW and deck.hand.has(card_id)
		and deck.draw_pile.is_empty(),
		"seeded real CombatDeck draws and holds " + card_id)
	return deck


func _snapshot(deck: CombatDeck, party: CombatParty, enemies: CombatEnemies) -> Dictionary:
	return {
		"draw": deck.draw_pile.duplicate(true),
		"hand": deck.hand.duplicate(true),
		"discard": deck.discard_pile.duplicate(true),
		"turn": deck.turn_active,
		"energy": deck.energy,
		"rng_seed": deck._rng.seed,
		"rng_state": deck._rng.state,
		"heroes": party.get_heroes(),
		"foes": enemies.get_enemies(),
		"capacity": enemies.get_capacity(),
		"valid": enemies.is_valid(),
	}


## One attack's independent, status-adjusted, Block-before-HP receipt from the
## shared damage rules (the card never reimplements the calculator).
func _receipt(base: int, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var defender_statuses: Dictionary = defender.get("statuses", {})
	var damage := rules.adjusted_attack_damage(base, attacker, defender_statuses)
	var absorbed := mini(int(defender.get("block", 0)), damage)
	var hp_loss := mini(int(defender.get("hp", 0)), damage - absorbed)
	return {"damage": damage, "block_absorbed": absorbed, "hp_loss": hp_loss}


## Apply one successful cast's receipts to a detached PRE-cast snapshot, using the
## same payment, Block-before-HP, Enrage and Thorns contracts the game uses.
func _apply_receipts(before: Dictionary, hits: Array, seat: int,
		card_id: String) -> Dictionary:
	var expected := before.duplicate(true)
	expected["energy"] = int(expected["energy"]) - 2
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	expected["discard"].append(card_id)
	for hit: Dictionary in hits:
		var foe: Dictionary = expected["foes"][int(hit["position"]) - 1]
		foe["block"] = int(foe.get("block", 0)) - int(hit["block_absorbed"])
		foe["hp"] = int(foe["hp"]) - int(hit["hp_loss"])
		if foe.get("enrage", false) == true and int(hit["damage"]) > 0 \
				and int(foe.get("enrage_stacks", 0)) \
					< CombatEnemyKeywordRules.ENRAGE_MAX_STACKS:
			foe["enrage_stacks"] = int(foe.get("enrage_stacks", 0)) + 1
	var hero: Dictionary = expected["heroes"][seat - 1]
	for hit: Dictionary in hits:
		var foe: Dictionary = expected["foes"][int(hit["position"]) - 1]
		var thorns := int(foe.get("thorns", 0))
		if thorns > 0 and int(hit["damage"]) > 0 and int(hero["hp"]) > 0:
			var absorbed := mini(int(hero["block"]), thorns)
			hero["block"] = int(hero["block"]) - absorbed
			hero["hp"] = int(hero["hp"]) - (thorns - absorbed)
	return expected
