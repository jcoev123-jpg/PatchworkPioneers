extends SceneTree
## Design v4 S6 Stitched Peddler bandage visit contract: the opt-in
## quoted-gold one-use buy-bandage (cure integer Bleed on one chosen hero)
## or free Leave decision, guarded by the exact node and a complete open
## snapshot, fully detached state and no RNG draws. Scene-free service test.

const NODE := "route-peddler-7"
const MODE := "stitched"
const PRICE := 40

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(424242)
	var next_draw := randi()
	seed(424242)
	_test_quote_and_admission()
	_test_purchase_and_leave()
	_test_refusals()
	_test_lost_and_hanging()
	_test_bleed_outcomes()
	_check(randi() == next_draw,
		"bandage open, quote, buys, Leaves and every refusal draw no global RNG")
	if failures.is_empty():
		print("run_stitched_peddler_bandage_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_bandage_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## Authored-shape four-hero fixture: distinct rank/ID records, one hero with
## bleed 3 plus another status, one with bleed 1, two unbled, nested parts.
func _party() -> Array:
	return [
		{"id": "rag_duelist", "rank": 1, "hp": 30, "fray": 12,
			"parts": {"blade": {"tier": 2, "torn": false, "meta": {"kills": 3}}},
			"statuses": {"bleed": 3, "weak": 1}},
		{"id": "warden", "rank": 2, "hp": 40, "fray": 0,
			"parts": {"shield": {"tier": 1, "torn": true}},
			"statuses": {"bleed": 1}},
		{"id": "seamstress", "rank": 3, "hp": 25, "fray": 5,
			"parts": {"needle": {"tier": 3, "torn": false}},
			"statuses": {"guard": 1}},
		{"id": "tinker", "rank": 4, "hp": 28, "fray": 8,
			"parts": {"turret": {"tier": 1, "torn": false}},
			"statuses": {}},
	]


func _open(gold: Variant, price: Variant, node: Variant = NODE,
		heroes: Variant = null) -> RunStitchedPeddlerBandage:
	if heroes == null:
		heroes = _party()
	return RunStitchedPeddlerBandage.open_stitched(node, heroes, gold, price)


func _open_party(gold: Variant, price: Variant, party: Variant,
		node: Variant = NODE) -> RunStitchedPeddlerBandage:
	return RunStitchedPeddlerBandage.open_stitched(node, party, gold, price)


## A refused request must change nothing, keep the visit open and report no
## phantom charge or decision.
func _reject(visit: RunStitchedPeddlerBandage, hero: Variant, node: Variant,
		snapshot: Variant, label: String) -> void:
	var before := visit.read_state()
	var result := visit.choose_bandage(hero, node, snapshot)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": no drift in heroes, wallet, status or retry right")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


## AC1: a valid four-rank party, clean node, nonnegative wallet and positive
## caller quote open the visit and quote bandage + free Leave at that exact
## price, exposing only genuinely bleeding hero IDs; malformed input fails.
func _test_quote_and_admission() -> void:
	var party := _party()
	var visit := RunStitchedPeddlerBandage.open_stitched(NODE, party, 120, PRICE)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid party, node, wallet and positive quote open the visit")
	# Mutating the caller's input after opening cannot forge the roster.
	party[0]["statuses"]["bleed"] = 99
	party[1]["hp"] = 1
	var state := visit.read_state()
	_check(state.get("ok") == true and state.get("mode") == MODE
		and state.get("node_id") == NODE and state.get("gold") == 120
		and state.get("price") == PRICE and state.get("status") == "open"
		and state.get("consumed") == false,
		"read_state carries node, mode, wallet, quote, status and open flag")
	_check(state["heroes"][0]["statuses"]["bleed"] == 3
		and state["heroes"][1]["hp"] == 40,
		"the admitted roster is a deep copy of the caller's input")
	_check(state.get("eligible") == ["rag_duelist", "warden"],
		"only heroes with a positive integer bleed are eligible")
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("mode") == MODE
		and quote.get("node_id") == NODE and quote.get("item") == "bandage"
		and quote.get("price") == PRICE and quote.get("gold") == 120
		and quote.get("eligible") == ["rag_duelist", "warden"]
		and quote.get("choices") == ["buy_bandage", "leave"]
		and quote.get("can_buy") == true and quote.get("blocked") == "",
		"the open quote offers exactly buy_bandage and leave at the quoted price")
	_test_actionable_quotes()
	# Mutating returned state/quote cannot forge a cheaper price or roster.
	state["gold"] = 99999
	state["heroes"][0]["statuses"].erase("bleed")
	quote["price"] = 1
	var fresh := visit.read_state()
	_check(fresh["gold"] == 120 and fresh["heroes"][0]["statuses"]["bleed"] == 3
		and visit.quote()["price"] == PRICE,
		"mutating returned snapshots changes nothing in the service")
	# Malformed admissions never open a visit.
	var bad_nodes: Array = ["", " " + NODE, NODE + " ", null, 17]
	for node in bad_nodes:
		var bad := _open(120, PRICE, node)
		_check(not bad.is_valid() and not bad.is_open() and not bad.is_consumed()
			and bad.read_state().get("ok") == false
			and bad.quote().get("ok", true) == false
			and bad.quote().get("choices", ["x"]).is_empty()
			and bad.choose_bandage("rag_duelist", NODE, {}).get("ok", true) == false
			and bad.leave(NODE, {}).get("ok", true) == false,
			"invalid node fails admission: " + str(node))
	var bad_parties: Array = [
		[], _party().slice(0, 3), _party() + [{"id": "extra", "rank": 1, "statuses": {}}],
		"not-an-array", null,
	]
	var dup := _party()
	dup[1]["id"] = "rag_duelist"
	bad_parties.append(dup)
	var bad_ranks := _party()
	bad_ranks[3]["rank"] = 3
	bad_parties.append(bad_ranks)
	var high_rank := _party()
	high_rank[3]["rank"] = 5
	bad_parties.append(high_rank)
	var float_rank := _party()
	float_rank[3]["rank"] = 4.0
	bad_parties.append(float_rank)
	var no_status := _party()
	no_status[2].erase("statuses")
	bad_parties.append(no_status)
	var string_status := _party()
	string_status[2]["statuses"] = "bleed"
	bad_parties.append(string_status)
	for bad_party in bad_parties:
		var bad := _open_party(120, PRICE, bad_party)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed party fails admission: " + str(bad_party).substr(0, 60))
	var bad_gold: Array = [-1, 1.5, "120", null]
	var bad_price: Array = [0, -5, 40.5, "40", null]
	for gold in bad_gold:
		_check(not _open(gold, PRICE).is_valid(),
			"invalid wallet fails admission: " + str(gold))
	for price in bad_price:
		_check(not _open(120, price).is_valid(),
			"invalid quote fails admission: " + str(price))
	_check(_open(0, 1).is_valid() and _open(0, PRICE).is_valid(),
		"a zero wallet with a positive quote is a legal opening")


## Asserts one open quote's choices, can_buy, blocked, exact price and honest
## eligible IDs, and that quoting mutated nothing.
func _assert_quote(visit: RunStitchedPeddlerBandage, gold: int, choices: Array,
		can_buy: bool, blocked: String, eligible: Array, label: String) -> void:
	var before := visit.read_state()
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("choices") == choices
		and quote.get("can_buy") == can_buy and quote.get("blocked") == blocked
		and quote.get("price") == PRICE and quote.get("gold") == gold
		and quote.get("eligible") == eligible and quote.get("item") == "bandage"
		and quote.get("node_id") == NODE and quote.get("mode") == MODE,
		label + ": choices, can_buy, blocked, price and eligible IDs are honest")
	_check(quote.get("choices").has("leave"), label + ": free Leave is always offered")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": quoting changes nothing")


## AC1/AC2/AC4: Buy is quoted only when payable and curable; Leave always.
func _test_actionable_quotes() -> void:
	var both := ["rag_duelist", "warden"]
	_assert_quote(_open(PRICE, PRICE), PRICE, ["buy_bandage", "leave"], true, "",
		both, "exact-price gold")
	_assert_quote(_open(120, PRICE), 120, ["buy_bandage", "leave"], true, "",
		both, "ample gold")
	_assert_quote(_open(PRICE - 1, PRICE), PRICE - 1, ["leave"], false,
		"not enough gold", [], "one gold short")
	_assert_quote(_open(0, PRICE), 0, ["leave"], false, "not enough gold", [],
		"empty wallet")
	var unbled := _party()
	unbled[0]["statuses"] = {"weak": 1}
	unbled[1]["statuses"] = {}
	_assert_quote(_open_party(120, PRICE, unbled), 120, ["leave"], false,
		"no bleeding heroes", [], "wholly unbled roster at 120 gold")
	# Zero, negative, float and string Bleed are never positive cure targets.
	var invalid_bleed := _party()
	invalid_bleed[0]["statuses"] = {"bleed": 0}
	invalid_bleed[1]["statuses"] = {"bleed": -2}
	invalid_bleed[2]["statuses"] = {"bleed": 1.5}
	invalid_bleed[3]["statuses"] = {"bleed": "3"}
	_assert_quote(_open_party(120, PRICE, invalid_bleed), 120, ["leave"], false,
		"no bleeding heroes", [], "invalid Bleed values")
	# A mixed roster lists only the truly bleeding hero when payable; an
	# unaffordable quote advertises no target at all.
	var mixed := invalid_bleed.duplicate(true)
	mixed[2]["statuses"] = {"bleed": 2}
	_assert_quote(_open_party(120, PRICE, mixed), 120, ["buy_bandage", "leave"],
		true, "", ["seamstress"], "mixed roster affordable")
	_assert_quote(_open_party(PRICE - 1, PRICE, mixed), PRICE - 1, ["leave"], false,
		"not enough gold", [], "mixed roster unaffordable")
	# With nothing to cure and no gold, the missing target is reported first.
	_assert_quote(_open_party(0, PRICE, unbled), 0, ["leave"], false,
		"no bleeding heroes", [], "unbled and broke")
	# Closed visits quote nothing and report no purchase.
	var closed := _open(120, PRICE)
	closed.leave(NODE, closed.read_state())
	var closed_quote := closed.quote()
	_check(closed_quote.get("ok", true) == false
		and closed_quote.get("choices", ["x"]).is_empty()
		and not closed_quote.has("can_buy"),
		"a closed visit quotes no choices and no purchase")


## AC2: an affordable exact-snapshot buy cures only the target's integer Bleed
## key, charges exactly the quoted amount once and consumes the visit.
func _test_purchase_and_leave() -> void:
	# Exact price: caller quote 40, wallet 40 spends to zero.
	var visit := _open(PRICE, PRICE)
	var before: Array = visit.read_state()["heroes"]
	var snap := visit.read_state()
	var paid := visit.choose_bandage("rag_duelist", NODE, snap)
	_check(paid.get("ok") == true and paid.get("decision") == "buy_bandage"
		and paid.get("node_id") == NODE and paid.get("hero_id") == "rag_duelist"
		and paid.get("charged_gold") == PRICE and paid.get("gold") == 0
		and paid.get("status") == "used" and paid.get("consumed") == true,
		"an exact-price buy cures the target and spends the wallet to zero")
	var after: Array = paid["heroes"]
	_check(after[0]["statuses"] == {"weak": 1},
		"only the target's bleed key is removed; its other status stays")
	_check(after[0]["hp"] == 30 and after[0]["fray"] == 12
		and after[0]["parts"] == before[0]["parts"] and after[0]["rank"] == 1,
		"the target's HP, FRAY, nested parts and rank are untouched")
	_check(after[1] == before[1] and after[2] == before[2] and after[3] == before[3],
		"the other three heroes are deep-equal to before the buy")
	_check(visit.is_consumed() and not visit.is_open()
		and visit.read_state()["gold"] == 0
		and visit.read_state()["heroes"][0]["statuses"] == {"weak": 1}
		and visit.read_state()["eligible"] == ["warden"],
		"the visit holds the cured roster, remaining gold and used status")
	_check(visit.quote().get("ok", true) == false
		and visit.quote().get("choices", ["x"]).is_empty(),
		"the consumed visit offers no further choices")
	# The receipt's heroes are a deep copy: mutating them cannot rewrite state.
	after[1]["statuses"]["bleed"] = 50
	_check(visit.read_state()["heroes"][1]["statuses"]["bleed"] == 1,
		"mutating the receipt's roster changes nothing in the service")
	# Second use without charge.
	var again := visit.choose_bandage("warden", NODE, visit.read_state())
	_check(again.get("ok", true) == false and visit.read_state()["gold"] == 0
		and visit.read_state()["heroes"][1]["statuses"]["bleed"] == 1,
		"a second purchase is refused without charge or cure")
	# Partial available wallet: quote 40 against 100 leaves 60, other target.
	var rich := _open(100, PRICE)
	var rich_snap := rich.read_state()
	var rich_paid := rich.choose_bandage("warden", NODE, rich_snap)
	_check(rich_paid.get("ok") == true and rich_paid.get("charged_gold") == PRICE
		and rich_paid.get("gold") == 60
		and rich_paid["heroes"][1]["statuses"] == {}
		and rich_paid["heroes"][0]["statuses"] == {"bleed": 3, "weak": 1},
		"a partial wallet buys by hero ID, curing only that hero's bleed")
	# Leave is free and consumes the visit exactly once.
	var leaving := _open(80, PRICE)
	var left := leaving.leave(NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left.get("charged_gold") == 0 and left.get("gold") == 80
		and left["heroes"] == leaving.read_state()["heroes"],
		"Leave consumes the visit once without charging or curing")
	_check(leaving.is_consumed()
		and leaving.leave(NODE, leaving.read_state()).get("ok", true) == false
		and leaving.choose_bandage("rag_duelist", NODE,
			leaving.read_state()).get("ok", true) == false,
		"a left visit refuses both Leave and buy afterwards")


## AC3: insufficient gold, unbled or unknown target, wrong node, stale or
## malformed snapshot all refuse without mutation, and a refused buy never
## spends the later legal free Leave.
func _test_refusals() -> void:
	# Insufficient gold: refused, then a valid free Leave still works once.
	var poor := _open(PRICE - 1, PRICE)
	var poor_snap := poor.read_state()
	_check(poor.quote().get("ok") == true and poor.quote().get("price") == PRICE
		and poor.quote().get("choices") == ["leave"]
		and poor.quote().get("can_buy") == false
		and poor.quote().get("blocked") == "not enough gold"
		and poor.quote().get("eligible") == [],
		"an unaffordable quote is still honestly disclosed, with Leave only")
	_reject(poor, "rag_duelist", NODE, poor_snap, "insufficient gold")
	# A replayed or falsified quote cannot authorize a buy it does not permit.
	var forged_quote := poor.quote().duplicate(true)
	forged_quote["choices"] = ["buy_bandage", "leave"]
	forged_quote["can_buy"] = true
	forged_quote["blocked"] = ""
	_reject(poor, "rag_duelist", NODE, forged_quote, "falsified unaffordable quote")
	var replayed := _open(120, PRICE).quote()
	_reject(poor, "rag_duelist", NODE, replayed, "replayed affordable quote")
	var poor_left := poor.leave(NODE, poor_snap)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor_left.get("gold") == PRICE - 1 and poor.is_consumed(),
		"a refused buy preserves the later legal no-charge Leave")
	# A wholly unbled roster quotes only Leave, refuses every Buy, then leaves free.
	var clean := _party()
	clean[0]["statuses"] = {"weak": 1}
	clean[1]["statuses"] = {}
	var clean_visit := _open_party(120, PRICE, clean)
	var clean_snap := clean_visit.read_state()
	_check(clean_visit.quote().get("choices") == ["leave"]
		and clean_visit.quote().get("can_buy") == false
		and clean_visit.quote().get("blocked") == "no bleeding heroes"
		and clean_visit.quote().get("eligible") == [],
		"an unbled roster quotes only free Leave even with ample gold")
	for target in ["rag_duelist", "warden", "seamstress", "tinker"]:
		_reject(clean_visit, target, NODE, clean_snap, "unbled roster buy: " + target)
	var clean_forged := clean_visit.quote().duplicate(true)
	clean_forged["choices"] = ["buy_bandage", "leave"]
	clean_forged["can_buy"] = true
	_reject(clean_visit, "rag_duelist", NODE, clean_forged, "falsified unbled quote")
	var clean_left := clean_visit.leave(NODE, clean_snap)
	_check(clean_left.get("ok") == true and clean_left.get("charged_gold") == 0
		and clean_left.get("gold") == 120 and clean_left["heroes"] == clean
		and clean_visit.is_consumed(),
		"an unbled visit still permits a no-charge, no-change Leave")
	# Unbled, unknown and malformed targets refuse.
	var visit := _open(300, PRICE)
	var snap := visit.read_state()
	_reject(visit, "seamstress", NODE, snap, "unbled hero target")
	_reject(visit, "tinker", NODE, snap, "empty-status hero target")
	_reject(visit, "nobody", NODE, snap, "unknown hero target")
	_reject(visit, "", NODE, snap, "empty hero target")
	_reject(visit, null, NODE, snap, "null hero target")
	_reject(visit, 7, NODE, snap, "non-string hero target")
	# Wrong or empty node refuses both actions.
	_reject(visit, "rag_duelist", "other-node", snap, "wrong node buy")
	var wrong_leave := visit.leave("other-node", snap)
	_check(wrong_leave.get("ok", true) == false and visit.is_open(),
		"wrong node leave refuses without consuming")
	_reject(visit, "rag_duelist", "", snap, "empty node buy")
	# Omitted, null, non-dictionary and field-tampered snapshots refuse.
	_reject(visit, "rag_duelist", NODE, {}, "omitted snapshot")
	_reject(visit, "rag_duelist", NODE, null, "null snapshot")
	_reject(visit, "rag_duelist", NODE, "not-a-dictionary", "non-dictionary snapshot")
	for field in ["gold", "price", "status", "mode", "node_id", "consumed", "eligible"]:
		var stale := snap.duplicate(true)
		stale[field] = "wrong" if field != "gold" and field != "price" else int(stale[field]) + 1
		_reject(visit, "rag_duelist", NODE, stale, "stale snapshot: " + field)
		var stale_heroes := snap.duplicate(true)
		stale_heroes["heroes"][0]["statuses"]["bleed"] = 9
		_reject(visit, "rag_duelist", NODE, stale_heroes, "forged roster snapshot")
	# Another visit's differing snapshot is a stale intent here.
	var twin := _open(301, PRICE)
	_reject(visit, "rag_duelist", NODE, twin.read_state(),
		"another visit's differing snapshot")
	# Every refusal preserved the exact legal choice.
	var paid := visit.choose_bandage("rag_duelist", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 260
		and paid["heroes"][0]["statuses"] == {"weak": 1},
		"after every refusal the fresh exact choice still buys legally")


## AC1-AC4: a LOST (unpicked) doll is never a bandage target, while a HANGING
## doll (0 HP, lost=false) still is; lost=false/missing stays eligible.
func _test_lost_and_hanging() -> void:
	# AC1/AC2: one LOST bleeder is excluded, the living one is still sold to.
	var one_lost := _party()
	one_lost[0]["lost"] = true
	one_lost[1]["lost"] = false
	var visit := _open_party(120, PRICE, one_lost)
	_check(visit.is_open() and visit.read_state().get("eligible") == ["warden"],
		"a LOST bleeding hero is excluded from read_state eligible IDs")
	_assert_quote(visit, 120, ["buy_bandage", "leave"], true, "", ["warden"],
		"one LOST bleeder, one living bleeder")
	var snap := visit.read_state()
	_reject(visit, "rag_duelist", NODE, snap, "LOST bleeder buy with ample gold")
	_check(visit.read_state()["gold"] == 120
		and visit.read_state()["heroes"][0]["statuses"] == {"bleed": 3, "weak": 1},
		"the refused LOST buy spent no gold and cured nothing")
	var paid := visit.choose_bandage("warden", NODE, visit.read_state())
	var heroes: Array = paid.get("heroes", [])
	_check(paid.get("ok") == true and paid.get("decision") == "buy_bandage"
		and paid.get("hero_id") == "warden" and paid.get("charged_gold") == PRICE
		and paid.get("gold") == 120 - PRICE and visit.is_consumed()
		and heroes.size() == 4,
		"the living bleeder buys once at exactly the quoted price")
	if heroes.size() == 4:
		var expected_warden: Dictionary = one_lost[1].duplicate(true)
		expected_warden["statuses"] = {}
		_check(heroes[0] == one_lost[0] and heroes[1] == expected_warden
			and heroes[2] == one_lost[2] and heroes[3] == one_lost[3],
			"only the living target's bleed is stripped; peers incl. LOST are unchanged")
	_check(visit.choose_bandage("warden", NODE, visit.read_state()).get("ok", true) == false
		and visit.read_state()["gold"] == 120 - PRICE,
		"replaying the purchase is refused without a second charge")
	# A missing lost field counts as not lost.
	var missing := _party()
	missing[1]["lost"] = true
	_check(_open_party(120, PRICE, missing).read_state().get("eligible") == ["rag_duelist"],
		"a missing lost field is not lost; the other bleeder is LOST and excluded")
	# AC4: every bleeder LOST -> Leave only, no spend, free Leave still works.
	var all_lost := _party()
	all_lost[0]["lost"] = true
	all_lost[1]["lost"] = true
	var lost_visit := _open_party(120, PRICE, all_lost)
	var lost_snap := lost_visit.read_state()
	_check(lost_snap.get("eligible") == [], "all-LOST bleeders leave no eligible IDs")
	_assert_quote(lost_visit, 120, ["leave"], false, "no bleeding heroes", [],
		"all bleeders LOST")
	_reject(lost_visit, "rag_duelist", NODE, lost_snap, "all-LOST buy: rag_duelist")
	_reject(lost_visit, "warden", NODE, lost_snap, "all-LOST buy: warden")
	var lost_forged := lost_visit.quote().duplicate(true)
	lost_forged["choices"] = ["buy_bandage", "leave"]
	lost_forged["can_buy"] = true
	lost_forged["blocked"] = ""
	lost_forged["eligible"] = ["rag_duelist", "warden"]
	_reject(lost_visit, "rag_duelist", NODE, lost_forged, "all-LOST falsified quote")
	var lost_left := lost_visit.leave(NODE, lost_snap)
	_check(lost_left.get("ok") == true and lost_left.get("charged_gold") == 0
		and lost_left.get("gold") == 120 and lost_left["heroes"] == all_lost
		and lost_visit.is_consumed(),
		"the all-LOST visit still permits the free Leave, charging nothing")
	# Wrong node, stale snapshot and insufficient wallet stay refused with a LOST peer.
	var guarded := _open_party(PRICE - 1, PRICE, one_lost)
	_reject(guarded, "warden", NODE, guarded.read_state(), "LOST roster, short wallet")
	var guarded_ok := _open_party(PRICE, PRICE, one_lost)
	_reject(guarded_ok, "warden", "other-node", guarded_ok.read_state(),
		"LOST roster, wrong node")
	_reject(guarded_ok, "warden", NODE, visit.read_state(), "LOST roster, stale snapshot")
	# AC3: a HANGING hero (hp 0, lost=false) with Bleed is still bandaged.
	var hanging := _party()
	hanging[1]["hp"] = 0
	hanging[1]["lost"] = false
	var hang_visit := _open_party(PRICE, PRICE, hanging)
	_check(hang_visit.read_state().get("eligible") == ["rag_duelist", "warden"],
		"a HANGING (0 HP, not lost) bleeder stays eligible")
	var hang_before: Array = hang_visit.read_state()["heroes"]
	var hang_paid := hang_visit.choose_bandage("warden", NODE, hang_visit.read_state())
	var hang_after: Array = hang_paid.get("heroes", [])
	_check(hang_paid.get("ok") == true and hang_paid.get("charged_gold") == PRICE
		and hang_paid.get("gold") == 0 and hang_after.size() == 4,
		"the HANGING hero's bandage buys at the exact quote")
	if hang_after.size() == 4:
		var expected_hang: Dictionary = hang_before[1].duplicate(true)
		expected_hang["statuses"] = {}
		_check(hang_after[1] == expected_hang and hang_after[1]["hp"] == 0
			and hang_after[1]["lost"] == false
			and hang_after[0] == hang_before[0] and hang_after[2] == hang_before[2]
			and hang_after[3] == hang_before[3],
			"the HANGING hero keeps HP, fray, rank, lost flag and parts; peers unchanged")


func _row(hero_id: String, amount: int) -> Dictionary:
	return {"hero_id": hero_id, "bleed_before": amount, "bleed_removed": amount,
		"bleed_after": 0}


## The open quote forecasts each eligible doll's whole Bleed cure, read-only.
func _test_bleed_outcomes() -> void:
	var both: Array = [_row("rag_duelist", 3), _row("warden", 1)]
	# Affordable: exactly two rows in roster order, existing fields unchanged.
	var rich := _open(120, PRICE)
	var quote := rich.quote()
	_check(quote.get("bleed_outcomes") is Array and quote["bleed_outcomes"].size() == 2,
		"an affordable open quote reports exactly two Bleed rows")
	_check(quote.get("bleed_outcomes") == both,
		"rows are rag_duelist 3=>0 then warden 1=>0 in roster order")
	_check(quote.get("eligible") == ["rag_duelist", "warden"]
		and quote.get("choices") == ["buy_bandage", "leave"]
		and quote.get("price") == PRICE and quote.get("can_buy") == true
		and quote.get("blocked") == "",
		"the forecast leaves eligible IDs, decisions and price exact")
	for row in quote.get("bleed_outcomes", []):
		_check(row.keys() == ["hero_id", "bleed_before", "bleed_removed", "bleed_after"]
			and typeof(row["bleed_before"]) == TYPE_INT and row["bleed_after"] == 0
			and row["bleed_removed"] == row["bleed_before"],
			"each row has exactly the four keys with integer counts")
	# Short wallet: the same informative rows, but Buy stays unavailable.
	var poor_quote := _open(39, PRICE).quote()
	_check(poor_quote.get("bleed_outcomes") == both
		and poor_quote.get("can_buy") == false
		and poor_quote.get("blocked") == "not enough gold"
		and poor_quote.get("choices") == ["leave"]
		and poor_quote.get("eligible") == [],
		"a short wallet keeps the truthful rows, blocks Buy, offers only Leave and no target")
	# Clean roster, and a roster whose only bleeder is LOST: empty and Leave-only.
	var clean := _party()
	clean[0]["statuses"] = {"weak": 1}
	clean[1]["statuses"] = {}
	var clean_quote := _open_party(120, PRICE, clean).quote()
	_check(clean_quote.get("bleed_outcomes") is Array
		and clean_quote["bleed_outcomes"].is_empty()
		and clean_quote.get("choices") == ["leave"]
		and clean_quote.get("blocked") == "no bleeding heroes",
		"a clean roster reports no rows and only Leave")
	var only_lost := _party()
	only_lost[0]["lost"] = true
	only_lost[1]["statuses"] = {}
	var lost_quote := _open_party(120, PRICE, only_lost).quote()
	_check(lost_quote.get("bleed_outcomes") is Array
		and lost_quote["bleed_outcomes"].is_empty()
		and lost_quote.get("choices") == ["leave"],
		"a LOST-only bleeder reports no rows and only Leave")
	var one_lost := _party()
	one_lost[0]["lost"] = true
	var one_lost_quote := _open_party(120, PRICE, one_lost).quote()
	_check(one_lost_quote.get("bleed_outcomes") == [_row("warden", 1)],
		"a LOST bleeder is omitted while the living bleeder is forecast")
	# Negative, zero, float, string and bool Bleed never appear.
	var invalid_bleed := _party()
	invalid_bleed[0]["statuses"] = {"bleed": 0}
	invalid_bleed[1]["statuses"] = {"bleed": -2}
	invalid_bleed[2]["statuses"] = {"bleed": 1.5}
	invalid_bleed[3]["statuses"] = {"bleed": "3"}
	var invalid_quote := _open_party(120, PRICE, invalid_bleed).quote()
	_check(invalid_quote.get("bleed_outcomes") == []
		and invalid_quote.get("choices") == ["leave"],
		"zero, negative, float and string Bleed produce no rows")
	var bool_bleed := _party()
	bool_bleed[0]["statuses"] = {"bleed": true}
	bool_bleed[1]["statuses"] = {}
	_check(_open_party(120, PRICE, bool_bleed).quote().get("bleed_outcomes") == [],
		"a boolean Bleed produces no row")
	# Mixed roster: only the truly bleeding doll, even when unaffordable.
	var mixed := invalid_bleed.duplicate(true)
	mixed[2]["statuses"] = {"bleed": 2}
	_check(_open_party(PRICE - 1, PRICE, mixed).quote().get("bleed_outcomes")
		== [_row("seamstress", 2)],
		"a mixed roster forecasts only the valid positive integer Bleed")
	# Closed and invalid visits publish no projection or buy offer.
	var closed := _open(120, PRICE)
	closed.leave(NODE, closed.read_state())
	var closed_quote := closed.quote()
	_check(closed_quote.get("ok", true) == false and not closed_quote.has("bleed_outcomes")
		and not closed_quote.has("can_buy")
		and closed_quote.get("choices", ["x"]).is_empty(),
		"a consumed visit exposes no projection and no buy offer")
	var invalid_quote_closed := _open(120, 0).quote()
	_check(invalid_quote_closed.get("ok", true) == false
		and not invalid_quote_closed.has("bleed_outcomes")
		and invalid_quote_closed.get("choices", ["x"]).is_empty(),
		"an invalid visit exposes no projection and no buy offer")
	# Mutating the returned rows cannot change the service or the next quote.
	var party := _party()
	var visit := _open_party(120, PRICE, party)
	var state_before := visit.read_state()
	var quote_before := visit.quote()
	var mutable := visit.quote()
	mutable["bleed_outcomes"][0]["bleed_removed"] = 99
	mutable["bleed_outcomes"][0]["hero_id"] = "forged"
	mutable["bleed_outcomes"].append(_row("tinker", 5))
	mutable["bleed_outcomes"].clear()
	_check(visit.quote() == quote_before and visit.read_state() == state_before
		and visit.quote()["bleed_outcomes"] == both,
		"mutating returned rows leaves a fresh quote and read_state unchanged")
	_check(party == _party() and visit.is_open(),
		"quoting never changes the caller's source heroes or the open visit")
	# A real legal bandage still charges once and cures only the chosen doll.
	var paid := visit.choose_bandage("rag_duelist", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("charged_gold") == PRICE
		and paid.get("gold") == 120 - PRICE and visit.is_consumed()
		and paid["heroes"][0]["statuses"] == {"weak": 1}
		and paid["heroes"][1]["statuses"] == {"bleed": 1},
		"a lawful buy charges 40 once, drops Bleed, keeps Weak and the warden's Bleed")
	var after_quote := visit.quote()
	_check(after_quote.get("ok", true) == false and not after_quote.has("bleed_outcomes")
		and visit.choose_bandage("warden", NODE, visit.read_state()).get("ok", true) == false
		and visit.read_state()["gold"] == 120 - PRICE,
		"the consumed visit publishes no projection and refuses a replayed buy")
