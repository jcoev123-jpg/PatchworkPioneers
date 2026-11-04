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
		and quote.get("choices") == ["buy_bandage", "leave"],
		"the open quote offers exactly buy_bandage and leave at the quoted price")
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
	_check(poor.quote().get("ok") == true and poor.quote().get("price") == PRICE,
		"an unaffordable quote is still honestly disclosed")
	_reject(poor, "rag_duelist", NODE, poor_snap, "insufficient gold")
	var poor_left := poor.leave(NODE, poor_snap)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor.is_consumed(),
		"a refused buy preserves the later legal Leave")
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
