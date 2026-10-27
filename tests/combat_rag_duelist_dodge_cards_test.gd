extends SceneTree
## V3-1 Rag Duelist cape self-Dodge contract for the scene-free CombatRagDuelistDodgeCards service.
##
## The real seeded CombatDeck and three-hero CombatParty fixtures drive all four authored printings -
## Cape Slip / Cape Slip+ (v3 starter) and Cape Flourish / Cape Flourish+ (v3 uncommon pool) - through
## one paid shared-hand transaction each: the printed cost (1 or 0), exactly one held copy discarded,
## and the owning hero's own one-shot `dodge_next_attack` integer token set to 1 in every legal seat.
## The canonical CombatStatuses boundaries are then exercised on the live result: first attempted hit
## consumption (never a second consumer), an unattempted attack that keeps the token, and removal of an
## unspent token at the existing owner-turn boundary. Every refusal - absent card, forged catalog record,
## inactive turn, wrong/torn owner, broke wallet, invalid party/status state and invalid target - is
## compared against a full pre-call snapshot (piles, energy, heroes, statuses and injected RNG state) and
## is retried successfully afterwards.
##
## This is callable rules-layer behaviour only: these IDs are not yet admitted to the live battle hand,
## the reward pool or the app flow (that wiring is a later task), so nothing here asserts a mounted
## card, a run deck or a view change.

## Paid self-Dodge fixtures, copied from the v3 design rather than read back from the service.
const CAPE_SLIP := "rag_duelist_cape_slip"
const CAPE_SLIP_PLUS := "rag_duelist_cape_slip_plus"
const CAPE_FLOURISH := "rag_duelist_cape_flourish"
const CAPE_FLOURISH_PLUS := "rag_duelist_cape_flourish_plus"
const DODGE_IDS := [CAPE_SLIP, CAPE_SLIP_PLUS, CAPE_FLOURISH, CAPE_FLOURISH_PLUS]
const CAPE_COST := {CAPE_SLIP: 1, CAPE_SLIP_PLUS: 0, CAPE_FLOURISH: 1, CAPE_FLOURISH_PLUS: 0}
const CAPE_FROM := [1, 2, 3]
const CAPE_EFFECTS := {"dodge_next_attack": 1, "duration": 1}
const CAPE_CATALOG := {
	CAPE_SLIP: "starter", CAPE_SLIP_PLUS: "starter",
	CAPE_FLOURISH: "pool", CAPE_FLOURISH_PLUS: "pool",
}
const CAPE_COPIES := {CAPE_SLIP: 1, CAPE_SLIP_PLUS: 0, CAPE_FLOURISH: 0, CAPE_FLOURISH_PLUS: 0}
const CAPE_REWARD := {
	CAPE_SLIP: false, CAPE_SLIP_PLUS: false, CAPE_FLOURISH: true, CAPE_FLOURISH_PLUS: false,
}
const DODGE_KEY := "dodge_next_attack"
const FILLERS := ["filler_stitch", "filler_thread", "filler_needle"]
const HEROES_PATH := "res://data/heroes/v3_party_roster.json"
const ALLY_PATH := "res://data/heroes/starter_party.json"

## Catalog seam double: only authentication reads it, so a rewritten record proves the paid service
## fails closed on a forged catalog. Every other case uses the real catalogs.
class ForgedDodge extends CombatRagDuelistDodgeCards:
	var forged_id: String = ""
	var forged: Dictionary = {}

	func _catalog_definition(card_id: String) -> Dictionary:
		if card_id == forged_id:
			return forged.duplicate(true)
		return super(card_id)

var failures: Array[String] = []
var checks: int = 0
var service := CombatRagDuelistDodgeCards.new()


func _initialize() -> void:
	_test_cape_printings_authored()
	_test_ac1_paid_play()
	_test_ac2_no_stack_and_one_shot_boundaries()
	_test_ac3_rejections()
	_test_ac3_forged_catalogs()
	_test_seeded_replay()
	if failures.is_empty():
		print("combat_rag_duelist_dodge_cards_test: PASS (", checks, " checks)")
	else:
		for failure: String in failures:
			printerr(failure)
		print("combat_rag_duelist_dodge_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## --- Authored printings -------------------------------------------------------------------------

## Both catalogs must still carry the exact authored line for all four printings, and nothing else may
## be accepted as one of these effects. ID-presence checks only, never a catalog total or full list.
func _test_cape_printings_authored() -> void:
	var starter := RagDuelistStarterCards.new()
	var pool := RagDuelistPoolCards.new()
	for card_id: String in DODGE_IDS:
		var record: Dictionary = _catalog_record(card_id)
		_check(not record.is_empty() and record.get("id") == card_id,
			card_id + ": authored catalog record exists")
		if record.is_empty():
			continue
		_check(record.get("owner") == "rag_duelist", card_id + ": authored owner is the Rag Duelist")
		_check(record.get("cost") == CAPE_COST[card_id],
			card_id + ": authored cost is " + str(CAPE_COST[card_id]))
		_check(record.get("from_positions") == CAPE_FROM, card_id + ": authored FROM seats 1-3")
		_check(record.get("target_kind") == "self", card_id + ": targets only its owner")
		_check(record.get("to_positions") == [], card_id + ": names no enemy position")
		_check(record.get("effects") == CAPE_EFFECTS,
			card_id + ": exact authored one-shot Dodge/duration line")
		_check(record.get("starting_copies") == CAPE_COPIES[card_id],
			card_id + ": authored starting copies untouched")
		_check(record.get("reward_eligible") == CAPE_REWARD[card_id],
			card_id + ": authored reward eligibility untouched")
		_check(service.is_supported_card(card_id), card_id + ": service authenticates the ID")
	_check(starter.get_upgrade_id(CAPE_SLIP) == CAPE_SLIP_PLUS
		and starter.get_definition(CAPE_SLIP_PLUS).get("upgrade_of") == CAPE_SLIP,
		"starter Cape Slip base-to-+ link is intact")
	_check(pool.get_upgrade_id(CAPE_FLOURISH) == CAPE_FLOURISH_PLUS
		and pool.get_definition(CAPE_FLOURISH_PLUS).get("upgrade_of") == CAPE_FLOURISH,
		"pool Cape Flourish base-to-+ link is intact")
	# Real Rag Duelist / other-owner cards this resolver must never play as a cape Dodge card.
	for unsupported: String in ["rag_duelist_rapier_lunge", "rag_duelist_needle_lunge",
			"rag_duelist_cape_parry", "rag_duelist_cape_parry_plus", "rag_duelist_cape_guard",
			"rag_duelist_duelist_reprise", "rag_duelist_feather_feint", "rag_duelist_velvet_feint",
			"rag_duelist_needle_prick", "rag_duelist_tattered_snare", "rag_duelist_needle_barrage",
			"rag_duelist_cape_slip_plus_plus", "RAG_DUELIST_CAPE_SLIP", "rag_duelist_cape_slip ",
			"rag_duelist_cape_slip\n", ""]:
		_check(not service.is_supported_card(unsupported),
			unsupported + ": not a paid cape Dodge printing for this service")
	_check(not service.is_supported_card(null)
		and not service.is_supported_card(7)
		and not service.is_supported_card(true)
		and not service.is_supported_card(StringName(CAPE_SLIP)),
		"non-string IDs are never supported")
	var rng := _rng(8241)
	var state_before: int = rng.state
	for card_id: String in DODGE_IDS:
		service.is_supported_card(card_id)
	service.is_supported_card("rag_duelist_unknown")
	_check(rng.state == state_before and not DODGE_IDS.is_empty(),
		"supported-card queries consume no run RNG (non-empty precondition)")


## --- AC1: one paid transaction per printing and seat -------------------------------------------

## AC1: each authentic base/'+' printing is charged exactly once, discards exactly one genuinely held
## copy and writes the one-shot Dodge token (integer 1) onto the living Rag Duelist in every legal seat
## 1-3, in a real 3-energy shared-hand turn. AC2's token transitions are checked on each live result:
## exact unrelated-status preservation, non-stacking, unattempted preservation, first-attempt
## consumption through CombatStatuses.dodge_project_for_attempt and owner-turn expiry.
func _test_ac1_paid_play() -> void:
	for card_id: String in DODGE_IDS:
		for owner_position: int in CAPE_FROM:
			var label := "%s seat=%d" % [card_id, owner_position]
			var party := _party(owner_position)
			party._heroes[owner_position - 1]["block"] = 2
			party._heroes[owner_position - 1]["statuses"] = {"bleed": 2}
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					party._heroes[index]["statuses"] = {"weak": 1}
			var deck := _deck(card_id, 2100 + 10 * owner_position)
			_check(deck.turn_active and deck.energy == 3 and deck.hand.size() == 5
				and deck.hand.count(card_id) >= 2,
				label + ": real seeded 3-energy five-card hand holds the printing twice")
			var held_before: int = deck.hand.count(card_id)
			var before := _snapshot(deck, party)
			var result: Dictionary = service.play_card(deck, party, card_id)
			_check(result.get("ok") == true and result.get("reason") == "applied",
				label + ": authorized paid play")
			_check(result.get("card_id") == card_id and result.get("cost") == CAPE_COST[card_id],
				label + ": receipt names the authentic card and its printed cost")
			_check(result.get("owner_position") == owner_position
				and result.get("owner_id") == "rag_duelist",
				label + ": receipt reports the real owning seat")
			_check(result.get("energy_before") == 3
				and result.get("energy_after") == 3 - int(CAPE_COST[card_id]),
				label + ": exactly the printed cost was charged once")
			_check(result.get("dodge_before") == 0 and result.get("dodge_after") == 1
				and result.get("dodge_already_active") == false,
				label + ": the cast arms the one-shot Dodge and does not spend it")
			_check(result.get("target_position") == owner_position
				and result.get("self_target") == true,
				label + ": the receipt resolves the self target to the owning seat")
			var owner: Dictionary = party.get_hero(owner_position)
			var expected_statuses := {"bleed": 2, DODGE_KEY: 1}
			_check(owner["statuses"] == expected_statuses,
				label + ": the owning hero keeps unrelated statuses and gains exactly Dodge 1")
			_check(typeof(owner["statuses"][DODGE_KEY]) == TYPE_INT
				and owner["statuses"][DODGE_KEY] == 1,
				label + ": the Dodge token is the integer one-shot flag 1, never a bool or stack")
			_check(owner["block"] == 2 and owner["hp"] == before["heroes"][owner_position - 1]["hp"],
				label + ": a non-Block, non-damage cape leaves owner HP and Block untouched")
			for index in range(CombatParty.PARTY_SIZE):
				if index + 1 != owner_position:
					_check(party.get_hero(index + 1) == before["heroes"][index],
						label + ": hero " + str(index + 1) + " is untouched")
			_check(deck.hand.count(card_id) == held_before - 1
				and deck.discard_pile == [card_id] and deck.hand.size() == 4,
				label + ": exactly one held copy moved to the discard with no extra draw")
			_check(deck.draw_pile == before["draw"],
				label + ": the other cards keep their draw-pile order")
			_check(deck.combat_state.energy == 3 - int(CAPE_COST[card_id]),
				label + ": the shared combat state holds the same printed charge")
			_check(_snapshot(deck, party) == _expected_play(before, card_id, owner_position),
				label + ": exact party, piles, energy and untouched injected RNG")
			# The receipt carries detached statuses, never the live roster.
			result["statuses"][DODGE_KEY] = 99
			_check(party.get_hero(owner_position)["statuses"] == expected_statuses,
				label + ": a mutated receipt cannot change the hero")

			# AC2: the canonical one-shot boundaries on the genuine result, without a second consumer.
			var rules := CombatStatuses.new()
			var live: Dictionary = party.get_hero(owner_position)["statuses"]
			var live_snapshot: Dictionary = live.duplicate(true)
			var unattempted: Dictionary = rules.dodge_project_for_attempt(live, false)
			_check(unattempted.get("ok") == true and unattempted.get("miss") == false
				and unattempted["statuses"].get(DODGE_KEY, 0) == 1,
				label + ": an unattempted attack does not consume the Dodge token")
			var attempted: Dictionary = rules.dodge_project_for_attempt(live, true)
			_check(attempted.get("ok") == true and attempted.get("miss") == true
				and not attempted["statuses"].has(DODGE_KEY),
				label + ": the first attempted hit misses and consumes the token once")
			_check(attempted["statuses"].get("bleed", 0) == 2,
				label + ": consuming Dodge keeps the unrelated status counters")
			var second_attempt: Dictionary = rules.dodge_project_for_attempt(attempted["statuses"], true)
			_check(second_attempt.get("ok") == true and second_attempt.get("miss") == false,
				label + ": a second attempt against the consumed state does not miss again")
			_check(live == live_snapshot,
				label + ": projecting attacks never mutates the hero's live statuses")
			var ended: Dictionary = rules.end_owner_turn(owner["hp"], owner["block"], live)
			_check(ended.get("ok") == true and not ended["statuses"].has(DODGE_KEY),
				label + ": the existing owner-turn boundary expires the unspent Dodge token")
			_check(ended["statuses"] == {"bleed": 1},
				label + ": expiry keeps the surviving unrelated status counters")
			_check(ended["bleed_hp_loss"] == 2 and ended["block"] == owner["block"],
				label + ": expiry deals only Bleed loss and leaves Block alone")
			_check(rules.dodge_project_for_attempt(ended["statuses"], true).get("miss") == false,
				label + ": an expired Dodge never misses a later attack")


## --- AC2: never a stack, never a second clock ---------------------------------------------------

## Replaying a legal cape card over an already armed Dodge never stacks or changes it above 1, even
## across two different capes; an inert Dodge 0 is replaced by 1; and the cast itself never spends the
## token. The service exposes no second Dodge consumer or turn clock.
func _test_ac2_no_stack_and_one_shot_boundaries() -> void:
	# (a) The same printing twice in one turn: one charge per play, Dodge stays exactly 1.
	for card_id: String in DODGE_IDS:
		var party := _party(2)
		party._heroes[1]["statuses"] = {"bleed": 2}
		var deck := _deck(card_id, 3400)
		_check(deck.hand.count(card_id) >= 2 and deck.energy == 3,
			card_id + ": replay fixture really holds two copies with 3 energy")
		var first: Dictionary = service.play_card(deck, party, card_id)
		_check(first.get("ok") == true and first.get("dodge_before") == 0
			and first.get("dodge_after") == 1 and first.get("dodge_already_active") == false,
			card_id + ": the first play arms Dodge 1 from nothing")
		var second: Dictionary = service.play_card(deck, party, card_id)
		_check(second.get("ok") == true and second.get("dodge_before") == 1
			and second.get("dodge_after") == 1 and second.get("dodge_already_active") == true,
			card_id + ": replaying the cape keeps the active Dodge at exactly 1")
		_check(party.get_hero(2)["statuses"] == {"bleed": 2, DODGE_KEY: 1},
			card_id + ": no stack, no extra token and the unrelated counter survives both plays")
		_check(deck.energy == 3 - 2 * int(CAPE_COST[card_id]) and deck.discard_pile == [card_id, card_id],
			card_id + ": both plays paid the printed cost and discarded their own copies")

	# (b) Two different capes in one hand: the second never stacks on the first's token.
	var cross_deck := _hand_deck([CAPE_SLIP, CAPE_SLIP, CAPE_FLOURISH, CAPE_FLOURISH, FILLERS[0]], 3420)
	var cross_party := _party(1)
	cross_party._heroes[0]["statuses"] = {"weak": 1}
	_check(cross_deck.hand.count(CAPE_SLIP) == 2 and cross_deck.hand.count(CAPE_FLOURISH) == 2,
		"cross-cape fixture really holds both capes in the shared hand")
	var slip_play: Dictionary = service.play_card(cross_deck, cross_party, CAPE_SLIP)
	var flourish_play: Dictionary = service.play_card(cross_deck, cross_party, CAPE_FLOURISH)
	_check(slip_play.get("ok") == true and flourish_play.get("ok") == true,
		"both cross-cape plays resolve as paid plays")
	_check(flourish_play.get("dodge_before") == 1
		and flourish_play.get("dodge_after") == 1
		and flourish_play.get("dodge_already_active") == true,
		"the second cape keeps the already armed Dodge at 1")
	_check(cross_party.get_hero(1)["statuses"] == {"weak": 1, DODGE_KEY: 1},
		"two capes in one turn leave exactly one Dodge token and the unrelated counter")
	_check(cross_deck.energy == 1 and cross_deck.discard_pile == [CAPE_SLIP, CAPE_FLOURISH],
		"the cross-cape pair is charged once each and discards both held copies")

	# (c) A pre-armed Dodge 1 is never spent or re-shaped by the cast.
	for card_id: String in DODGE_IDS:
		var party := _party(3)
		party._heroes[2]["statuses"] = {DODGE_KEY: 1, "weak": 2}
		var deck := _deck(card_id, 3410)
		var before := _snapshot(deck, party)
		var result: Dictionary = service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("dodge_before") == 1
			and result.get("dodge_after") == 1 and result.get("dodge_already_active") == true,
			card_id + ": a pre-armed cape Dodge stays at 1")
		_check(party.get_hero(3)["statuses"] == {DODGE_KEY: 1, "weak": 2},
			card_id + ": the pre-armed token and the unrelated counter are unchanged")
		_check(_snapshot(deck, party) == _expected_play(before, card_id, 3),
			card_id + ": exact one-payment transaction from the pre-armed fixture")

	# (d) An inert Dodge 0 is not an active status: the printed cape replaces it with 1.
	for card_id: String in DODGE_IDS:
		var party := _party(2)
		party._heroes[1]["statuses"] = {DODGE_KEY: 0, "exposed": 1}
		var deck := _deck(card_id, 3425)
		var result: Dictionary = service.play_card(deck, party, card_id)
		_check(result.get("ok") == true and result.get("dodge_before") == 0
			and result.get("dodge_after") == 1 and result.get("dodge_already_active") == false,
			card_id + ": a genuine play replaces an inert Dodge 0 with 1")
		_check(party.get_hero(2)["statuses"] == {DODGE_KEY: 1, "exposed": 1},
			card_id + ": only Dodge changes; the unrelated Exposed counter survives")

	# (e) The unspent token only ever expires through the shared owner-turn rule; this service adds no
	# second consumer or clock of its own.
	_check(not service.has_method("consume_dodge")
		and not service.has_method("end_owner_turn")
		and not service.has_method("dodge_project_for_attempt"),
		"the cape service adds no second Dodge consumer or turn clock")
	var rules := CombatStatuses.new()
	var expiry_party := _party(2)
	var expiry_deck := _deck(CAPE_SLIP, 3430)
	_check(service.play_card(expiry_deck, expiry_party, CAPE_SLIP).get("ok") == true,
		"expiry fixture really plays a cape")
	var owned: Dictionary = expiry_party.get_hero(2)
	var ended: Dictionary = rules.end_owner_turn(owned["hp"], owned["block"], owned["statuses"])
	_check(ended.get("ok") == true and not ended["statuses"].has(DODGE_KEY),
		"an unattempted cape Dodge expires at the owner-turn boundary")
	_check(expiry_deck.turn_active and expiry_deck.energy == 2,
		"ending the owner turn is the shared rule's job, not this cast's")


## --- AC3: fail-closed refusals ----------------------------------------------------------------

## Every refusal leaves hand, draw, discard, energy, turn, heroes, statuses and the injected RNG
## exactly as they were, and the authentic play still works afterwards.
func _test_ac3_rejections() -> void:
	var party := _party(2)

	_rejected(null, party, CAPE_SLIP, 0, "null deck")
	_rejected(_deck(CAPE_SLIP, 4001), null, CAPE_SLIP, 0, "null party")
	_rejected(_deck(CAPE_SLIP, 4002), CombatParty.new([]), CAPE_SLIP, 0, "invalid party roster")

	var inactive := _deck(CAPE_SLIP, 4003, -1, false)
	_check(not inactive.turn_active and inactive.hand.is_empty(),
		"inactive-turn fixture really has no active turn")
	_rejected(inactive, party, CAPE_SLIP, 0, "inactive turn")

	var held := _deck(CAPE_SLIP, 4004)
	_check(held.hand.has(CAPE_SLIP) and not held.hand.has(CAPE_SLIP_PLUS),
		"absent-card fixture holds the base Cape Slip only")
	_rejected(held, party, CAPE_SLIP_PLUS, 0, "authentic '+' absent from the hand")
	var held_flourish := _deck(CAPE_FLOURISH, 4004)
	_check(held_flourish.hand.has(CAPE_FLOURISH)
		and not held_flourish.hand.has(CAPE_FLOURISH_PLUS),
		"absent-card fixture holds the base Cape Flourish only")
	_rejected(held_flourish, party, CAPE_FLOURISH_PLUS, 0, "authentic Flourish '+' absent")

	var foreign := _deck("rag_duelist_feather_feint", 4005)
	_check(foreign.hand.has("rag_duelist_feather_feint"),
		"foreign-card fixture really holds another Rag Duelist card")
	_rejected(foreign, party, "rag_duelist_feather_feint", 0, "foreign Rag Duelist card")
	for unsupported: Variant in ["", "rag_duelist_cape_slip_plus_plus", "rag_duelist_cape_slip ",
			"RAG_DUELIST_CAPE_SLIP", "rag_duelist_cape_parry", "rag_duelist_cape_guard",
			"rag_duelist_duelist_reprise", "rag_duelist_feather_feint", "rag_duelist_rapier_lunge",
			"rag_duelist_needle_prick", 7, null, true, 1.0, StringName(CAPE_SLIP)]:
		_rejected(_deck(CAPE_SLIP, 4006), party, unsupported, 0,
			"unsupported or forged printing " + str(unsupported))

	var broke := _deck(CAPE_SLIP, 4007, 0)
	_check(broke.energy == 0 and broke.hand.has(CAPE_SLIP),
		"energy-short fixture is genuinely broke and still holds the card")
	_rejected(broke, party, CAPE_SLIP, 0, "insufficient energy for the printed cost")
	var broke_flourish := _deck(CAPE_FLOURISH, 4008, 0)
	_check(broke_flourish.energy == 0 and broke_flourish.hand.has(CAPE_FLOURISH),
		"energy-short fixture really holds Cape Flourish with no energy")
	_rejected(broke_flourish, party, CAPE_FLOURISH, 0, "insufficient energy for Cape Flourish")

	# A zero-cost '+' printing is still genuinely held and still paid from a broke wallet.
	var free := _deck(CAPE_SLIP_PLUS, 4009, 0)
	_check(free.energy == 0 and free.hand.has(CAPE_SLIP_PLUS),
		"zero-cost fixture is broke and really holds Cape Slip+")
	var free_play: Dictionary = service.play_card(free, party, CAPE_SLIP_PLUS)
	_check(free_play.get("ok") == true and free.energy == 0 and free.hand.size() == 4,
		"a held zero-cost '+' cape plays without spending energy")
	_check(free.discard_pile == [CAPE_SLIP_PLUS],
		"the zero-cost '+' cape still discards exactly its own copy")

	var no_owner := CombatParty.new([
		{"id": "warden", "max_hp": 40}, {"id": "seamstress", "max_hp": 30},
		{"id": "tinker", "max_hp": 26},
	])
	_check(no_owner.is_valid() and no_owner.get_hero(1)["id"] != "rag_duelist"
		and no_owner.get_hero(2)["id"] != "rag_duelist"
		and no_owner.get_hero(3)["id"] != "rag_duelist",
		"absent-owner fixture is a valid party without a Rag Duelist")
	_rejected(_deck(CAPE_SLIP, 4010), no_owner, CAPE_SLIP, 0, "party with no Rag Duelist owner")

	var duplicated := _party(2)
	duplicated._heroes[0]["id"] = "rag_duelist"
	_check(duplicated.get_hero(1)["id"] == "rag_duelist"
		and duplicated.get_hero(2)["id"] == "rag_duelist",
		"duplicate-identity fixture really repeats the owner ID")
	_rejected(_deck(CAPE_SLIP, 4011), duplicated, CAPE_SLIP, 0, "duplicate Rag Duelist identity")

	var downed := _party(1)
	_check(downed.apply_damage(1, downed.get_hero(1)["max_hp"]) and downed.is_downed(1),
		"torn-owner fixture really has a downed Rag Duelist")
	_rejected(_deck(CAPE_SLIP, 4012), downed, CAPE_SLIP, 0, "torn (0 HP) Rag Duelist owner")

	var above_max := _party(2)
	above_max._heroes[1]["hp"] = int(above_max._heroes[1]["max_hp"]) + 1
	_check(above_max.get_hero(2)["hp"] > above_max.get_hero(2)["max_hp"],
		"malformed-roster fixture really has HP above max")
	_rejected(_deck(CAPE_SLIP, 4013), above_max, CAPE_SLIP, 0, "HP above max")

	var bad_block := _party(2)
	bad_block._heroes[1]["block"] = -1
	_check(bad_block.get_hero(2)["block"] == -1, "negative-Block fixture really stores -1")
	_rejected(_deck(CAPE_SLIP, 4014), bad_block, CAPE_SLIP, 0, "negative Block")

	var bad_position := _party(2)
	bad_position._heroes[0]["position"] = 3
	_check(bad_position.get_hero(1)["position"] == 3,
		"wrong-position fixture really stores the wrong slot")
	_rejected(_deck(CAPE_SLIP, 4015), bad_position, CAPE_SLIP, 0, "wrong stored hero position")

	for bad_statuses: Variant in ["bleed", [], null, {"bleed": -1}, {"bleed": "3"},
			{"bleed": 1.5}, {"weak": true}, {1: 2}, {"": 1}, {"unknown_status": 1},
			{DODGE_KEY: 2}, {DODGE_KEY: -1}, {DODGE_KEY: 1.5}, {DODGE_KEY: "1"},
			{DODGE_KEY: true}, {"blind_next_attack": 2}, {"riposte": -1}, {"riposte": true}]:
		var broken := _party(2)
		broken._heroes[1]["statuses"] = bad_statuses
		_check(broken.get_hero(2)["statuses"] == bad_statuses,
			"malformed-status fixture really stores " + str(bad_statuses))
		_rejected(_deck(CAPE_SLIP, 4016), broken, CAPE_SLIP, 0,
			"malformed owner statuses " + str(bad_statuses))

	var ally_statuses := _party(2)
	ally_statuses._heroes[0]["statuses"] = {"poison": 1}
	_check(ally_statuses.get_hero(1)["statuses"] == {"poison": 1},
		"malformed-ally fixture really stores an unknown status")
	_rejected(_deck(CAPE_SLIP, 4017), ally_statuses, CAPE_SLIP, 0,
		"malformed statuses on a non-owner hero")

	# A self cape names exactly its own seat: any other target argument fails closed before payment.
	var self_owner := _party(2)
	for bad_target: Variant in [1, 3, 4, -1, "2", 2.0, true, null, [2]]:
		_rejected(_deck(CAPE_SLIP, 4018), self_owner, CAPE_SLIP, bad_target,
			"invalid target argument " + str(bad_target))
	# ... while the implicit self target (0) and the owner's own explicit seat both play.
	var implicit_target := _party(2)
	var implicit_deck := _deck(CAPE_SLIP, 4019)
	var implicit_play: Dictionary = service.play_card(implicit_deck, implicit_target, CAPE_SLIP, 0)
	_check(implicit_play.get("ok") == true
		and implicit_play.get("target_position") == 2,
		"the implicit self target resolves to the owner's current seat")
	var explicit_target := _party(2)
	var explicit_deck := _deck(CAPE_SLIP, 4020)
	var explicit_play: Dictionary = service.play_card(explicit_deck, explicit_target, CAPE_SLIP, 2)
	_check(explicit_play.get("ok") == true
		and explicit_play.get("target_position") == 2
		and explicit_target.get_hero(2)["statuses"].get(DODGE_KEY, 0) == 1,
		"the owner's own explicit seat is a legal self target")

	# A rejected attempt never poisons the next authentic one, and the same seed replays the pair.
	var retry_deck := _deck(CAPE_SLIP, 4030)
	var retry_party := _party(2)
	var retry_before := _snapshot(retry_deck, retry_party)
	_rejected(retry_deck, retry_party, CAPE_SLIP_PLUS, 0, "retry: absent '+' printing")
	var retried: Dictionary = service.play_card(retry_deck, retry_party, CAPE_SLIP)
	_check(retried.get("ok") == true, "retry: the authentic play then succeeds")
	_check(_snapshot(retry_deck, retry_party)
		== _expected_play(retry_before, CAPE_SLIP, 2),
		"retry: exactly one charge, one discard and an untouched RNG")
	var refused_then_valid_a := _refused_then_valid_run(CAPE_FLOURISH, 4031)
	var refused_then_valid_b := _refused_then_valid_run(CAPE_FLOURISH, 4031)
	var valid_only := _valid_run(CAPE_FLOURISH, 4031)
	_check(refused_then_valid_a["refused"].get("ok") == false
		and valid_only["result"].get("ok") == true,
		"same-seed refusal replay fixture really refuses then plays (non-empty precondition)")
	_check(refused_then_valid_a["snapshot"] == refused_then_valid_b["snapshot"]
		and refused_then_valid_a["result"] == refused_then_valid_b["result"],
		"the same seed replays the refusal and the valid play exactly")
	_check(refused_then_valid_a["snapshot"] == valid_only["snapshot"],
		"a refused cast leaves exactly the state of a valid-only run")


## --- AC3: forged catalog records ---------------------------------------------------------------

## A rewritten catalog record - every authenticated field omitted or altered, an extra effect, a
## stacked Dodge 2, a longer duration or a coerced value - is never paid for, while the restored
## authentic record still plays, so the refusal comes from the forgery.
func _test_ac3_forged_catalogs() -> void:
	for card_id: String in DODGE_IDS:
		var authentic: Dictionary = _catalog_record(card_id)
		_check(not authentic.is_empty(), card_id + ": authentic record available (forgery precondition)")
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
			altered[field] = {"id": "fake_cape", "owner": "warden", "cost": 2.0,
				"from_positions": [3], "to_positions": [1, 2], "target_kind": "enemy_single",
				"effects": {DODGE_KEY: 2, "duration": 2},
				"upgrade_id": "fake_cape", "upgrade_of": "fake_cape"}[field]
			mutations.append(altered)
		var extra_effect: Dictionary = authentic.duplicate(true)
		extra_effect["effects"]["block"] = 2
		mutations.append(extra_effect)
		var extra_draw: Dictionary = authentic.duplicate(true)
		extra_draw["effects"]["draw"] = 1
		mutations.append(extra_draw)
		var stacked_dodge: Dictionary = authentic.duplicate(true)
		stacked_dodge["effects"][DODGE_KEY] = 2
		mutations.append(stacked_dodge)
		var permanent_dodge: Dictionary = authentic.duplicate(true)
		permanent_dodge["effects"].erase("duration")
		mutations.append(permanent_dodge)
		var wrong_duration: Dictionary = authentic.duplicate(true)
		wrong_duration["effects"]["duration"] = 2
		mutations.append(wrong_duration)
		var typed_dodge: Dictionary = authentic.duplicate(true)
		typed_dodge["effects"][DODGE_KEY] = float(typed_dodge["effects"][DODGE_KEY])
		mutations.append(typed_dodge)
		var bool_dodge: Dictionary = authentic.duplicate(true)
		bool_dodge["effects"][DODGE_KEY] = true
		mutations.append(bool_dodge)
		var copied_partner: Dictionary = authentic.duplicate(true)
		copied_partner["id"] = CAPE_SLIP if card_id != CAPE_SLIP else CAPE_FLOURISH
		mutations.append(copied_partner)
		_check(not mutations.is_empty(), card_id + ": forgery fixtures are non-empty (precondition)")

		var forged_service := ForgedDodge.new()
		var forged_deck := _deck(card_id, 4400)
		var forged_party := _party(2)
		forged_service.forged_id = card_id
		for forged: Dictionary in mutations:
			forged_service.forged = forged
			var forged_before := _snapshot(forged_deck, forged_party)
			var result: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
			_check(result.get("ok") == false,
				card_id + ": forged catalog record rejected: " + str(forged.get("effects")))
			_check(_snapshot(forged_deck, forged_party) == forged_before,
				card_id + ": forged record rejection leaves deck, party and RNG unchanged")
		forged_service.forged_id = ""
		var restored: Dictionary = forged_service.play_card(forged_deck, forged_party, card_id)
		_check(restored.get("ok") == true and restored.get("card_id") == card_id,
			card_id + ": the restored authentic record plays")

	# A forged partner printing also stops its authentic pair-mate from being paid for.
	for card_id: String in [CAPE_SLIP, CAPE_FLOURISH]:
		var plus_id: String = card_id + "_plus"
		var authentic: Dictionary = _catalog_record(plus_id)
		_check(not authentic.is_empty(), plus_id + ": authentic partner record available")
		if authentic.is_empty():
			continue
		var broken_pair := ForgedDodge.new()
		broken_pair.forged_id = plus_id
		broken_pair.forged = authentic.duplicate(true)
		broken_pair.forged["cost"] = 1
		_rejected(_deck(card_id, 4410), _party(2), card_id, 0,
			"broken upgrade partner for " + card_id, broken_pair)


## --- Seeded replay -----------------------------------------------------------------------------

func _test_seeded_replay() -> void:
	for card_id: String in DODGE_IDS:
		var first: Dictionary = _valid_run(card_id, 5201)
		var second: Dictionary = _valid_run(card_id, 5201)
		_check(not first["snapshot"].is_empty() and first["result"].get("ok") == true,
			card_id + ": seeded replay fixture really plays (non-empty precondition)")
		_check(second["snapshot"] == first["snapshot"] and second["result"] == first["result"],
			card_id + ": the same seed replays the final state exactly")
		_check(first["rng_state"] == first["rng_start"]
			and first["rng_seed"] == first["rng_seed_start"]
			and first["snapshot"]["rng_state"] == first["rng_start"],
			card_id + ": a non-drawing cape play consumes no injected RNG state")

	seed(13579)
	var expected_next: int = randi()
	seed(13579)
	var party := _party(1)
	var deck := _deck(CAPE_FLOURISH, 5202)
	var state_before: int = deck._rng.state
	var result: Dictionary = service.play_card(deck, party, CAPE_FLOURISH)
	_check(result.get("ok") == true and deck._rng.state == state_before,
		"a genuine cape play never consumes the injected generator")
	_check(randi() == expected_next, "cape resolution never draws from the global RNG")


func _valid_run(card_id: String, seed_value: int) -> Dictionary:
	var party := _party(2)
	party._heroes[0]["statuses"] = {"bleed": 1}
	party._heroes[1]["statuses"] = {"weak": 2}
	var deck := _deck(card_id, seed_value)
	var rng_start: int = deck._rng.state
	var rng_seed: int = deck._rng.seed
	var result: Dictionary = service.play_card(deck, party, card_id)
	return {"result": result, "snapshot": _snapshot(deck, party),
		"rng_start": rng_start, "rng_state": deck._rng.state,
		"rng_seed_start": rng_seed, "rng_seed": deck._rng.seed}


func _refused_then_valid_run(card_id: String, seed_value: int) -> Dictionary:
	var party := _party(2)
	party._heroes[0]["statuses"] = {"bleed": 1}
	party._heroes[1]["statuses"] = {"weak": 2}
	var deck := _deck(card_id, seed_value)
	var other_id: String = CAPE_SLIP_PLUS
	if card_id == CAPE_SLIP_PLUS:
		other_id = CAPE_FLOURISH_PLUS
	var refused: Dictionary = service.play_card(deck, party, other_id)
	var result: Dictionary = service.play_card(deck, party, card_id)
	return {"refused": refused, "result": result, "snapshot": _snapshot(deck, party)}


## --- Fixtures and comparisons ------------------------------------------------------------------

func _catalog_record(card_id: String) -> Dictionary:
	if CAPE_CATALOG.get(card_id, "") == "starter":
		return RagDuelistStarterCards.new().get_definition(card_id)
	return RagDuelistPoolCards.new().get_definition(card_id)


func _rejected(deck: CombatDeck, party: CombatParty, card_id: Variant, target_position: Variant,
		label: String, rejector: CombatRagDuelistDodgeCards = null) -> void:
	var before := _snapshot(deck, party)
	var actor: CombatRagDuelistDodgeCards = service if rejector == null else rejector
	var result: Dictionary = actor.play_card(deck, party, card_id, target_position)
	_check(result.get("ok") == false, label + ": rejected")
	_check(result.get("reason") is String and not (result.get("reason") as String).is_empty(),
		label + ": refusal carries a reason")
	_check(_snapshot(deck, party) == before,
		label + ": unchanged party, hand, draw, discard, energy, turn and RNG")


## The single-transaction expected state for one paid play: one printed cost, one held copy discarded
## and the one-shot Dodge token on the owning seat only. A non-Block cape changes no HP or Block.
func _expected_play(before: Dictionary, card_id: String, owner_position: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	var cost: int = int(CAPE_COST[card_id])
	expected["energy"] = int(expected["energy"]) - cost
	expected["state_energy"] = int(expected["state_energy"]) - cost
	var hand: Array = expected["hand"]
	hand.remove_at(hand.find(card_id))
	var discard: Array = expected["discard"]
	discard.append(card_id)
	var hero: Dictionary = expected["heroes"][owner_position - 1]
	var statuses: Dictionary = hero.get("statuses", {})
	statuses[DODGE_KEY] = 1
	hero["statuses"] = statuses
	return expected


## The full observable deck/party state plus the injected RNG state, for exact comparisons.
func _snapshot(deck: CombatDeck, party: CombatParty) -> Dictionary:
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


## A real seeded five-card hand from six cards (three copies of the named ID), so at least two copies
## are genuinely held. `energy` of 0+ spends down to exactly that budget before the play.
func _deck(card_id: String, seed_value: int, energy: int = -1,
		start_turn: bool = true) -> CombatDeck:
	var ids: Array[String] = [card_id, card_id, card_id, FILLERS[0], FILLERS[1], FILLERS[2]]
	return _hand_deck_for(ids, card_id, seed_value, energy, start_turn)


## A real seeded deck built from exactly the given cards, so a five-card list fills the whole hand.
func _hand_deck(card_ids: Array, seed_value: int,
		energy: int = -1) -> CombatDeck:
	var ids: Array[String] = []
	for card_id in card_ids:
		ids.append(str(card_id))
	return _hand_deck_for(ids, ids[0], seed_value, energy, true)


func _hand_deck_for(ids: Array[String], card_id: String, seed_value: int, energy: int,
		start_turn: bool) -> CombatDeck:
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


## A real three-hero CombatParty with the authored Rag Duelist in the requested seat and two authored
## starter allies filling the rest. No run roster or data file is changed.
func _party(owner_position: int) -> CombatParty:
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
