extends SceneTree
## Design v4 Stitched Peddler Walk-supplies contract: two caller-quoted prepared
## offers (starch, spare_spool), a one-use buy into one doll's Walk pocket or a
## free Leave, guarded by the exact node and a visit-bound open snapshot, fully
## detached state and no RNG draws. Scene-free service test.

const NODE := "route-peddler-12"
const MODE := "stitched"
const STARCH_PRICE := 30
const SPOOL_PRICE := 45
const STARCH_TEXT := "Use during the Walk: this doll starts the next fight with Guard."
const SPOOL_TEXT := "Use during the Walk: repair a snipped thread or save a part from a Tug."

const RUN_SEED := 14
const SHOP_NODE := "f01_n3"
const ROUTE_PRICE := 10
## Deliberately fixture-funded wallet for the routed paid-purchase witnesses;
## explicitly NOT battle-earned gold.
const FIXTURE_GOLD := 40

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(828282)
	var next_draw := randi()
	seed(828282)
	_test_admission_and_isolation()
	_test_quotes()
	_test_effect_text()
	_test_purchases()
	_test_refusals()
	_test_leave()
	_test_routed_zero_gold_route()
	_test_routed_funded_purchases()
	_test_routed_disabled_offers()
	_check(randi() == next_draw,
		"open, quote, buys, Leaves and every refusal draw no global RNG")
	if failures.is_empty():
		print("run_stitched_peddler_walk_supplies_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_walk_supplies_test: FAIL (", failures.size(),
			" failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _party() -> Array:
	return [
		{"id": "rag_duelist", "rank": 1, "hp": 30, "fray": 12, "lost": false,
			"parts": {"blade": {"tier": 2}}},
		{"id": "warden", "rank": 2, "hp": 40, "fray": 0, "lost": false,
			"parts": {"shield": {"tier": 1}}},
		{"id": "seamstress", "rank": 3, "hp": 25, "fray": 5, "lost": false,
			"parts": {"needle": {"tier": 3}}},
		{"id": "tinker", "rank": 4, "hp": 28, "fray": 8, "lost": false,
			"parts": {"turret": {"tier": 1}}},
	]


## rag_duelist empty, warden one starch, seamstress two identical, tinker full.
func _pockets() -> Dictionary:
	return {
		"rag_duelist": [],
		"warden": ["starch"],
		"seamstress": ["dye", "dye"],
		"tinker": ["pins", "spare_spool"],
	}


## Deliberately different prices; spare_spool is listed first on purpose.
func _offers() -> Array:
	return [{"id": "spare_spool", "price": SPOOL_PRICE},
		{"id": "starch", "price": STARCH_PRICE}]


func _open(gold: Variant, offers: Variant = null, heroes: Variant = null,
		pockets: Variant = null, node: Variant = NODE) -> RunStitchedPeddlerWalkSupplies:
	if offers == null:
		offers = _offers()
	if heroes == null:
		heroes = _party()
	if pockets == null:
		pockets = _pockets()
	return RunStitchedPeddlerWalkSupplies.open_stitched(node, heroes, pockets, gold,
		offers)


func _reject(visit: RunStitchedPeddlerWalkSupplies, item: Variant, hero: Variant,
		node: Variant, snapshot: Variant, label: String) -> void:
	var before := visit.read_state()
	var result := visit.buy(item, hero, node, snapshot)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": no drift in dolls, pockets, wallet or status; visit still open")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


func _row(quote: Dictionary, id: String) -> Dictionary:
	for row in quote.get("offers", []):
		if row.get("id") == id:
			return row
	return {}


## AC1: valid and invalid admissions plus input/output isolation.
func _test_admission_and_isolation() -> void:
	var party := _party()
	var pockets := _pockets()
	var offers := _offers()
	var visit := RunStitchedPeddlerWalkSupplies.open_stitched(NODE, party, pockets,
		100, offers)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid node, party, pockets, wallet and two offers open the visit")
	party[0]["hp"] = 1
	pockets["rag_duelist"].append("dye")
	offers[0]["price"] = 1
	offers.clear()
	var state := visit.read_state()
	_check(state.get("ok") == true and state.get("mode") == MODE
		and state.get("node_id") == NODE and state.get("gold") == 100
		and state.get("status") == "open" and state.get("consumed") == false
		and str(state.get("visit_id")) != "",
		"read_state carries visit ID, node, mode, wallet, status and open flag")
	_check(state["heroes"][0]["hp"] == 30 and state["pockets"]["rag_duelist"] == []
		and state["offers"] == _offers(),
		"mutating the caller's input after opening cannot forge the state")
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote["offers"].size() == 2
		and quote["offers"][0]["id"] == "spare_spool"
		and quote["offers"][0]["price"] == SPOOL_PRICE
		and quote["offers"][1]["id"] == "starch"
		and quote["offers"][1]["price"] == STARCH_PRICE,
		"the quote shows exactly the two caller rows with exact prices, in input order")
	_check(quote.get("eligible") == ["rag_duelist", "warden"]
		and quote.get("choices").has("leave"),
		"eligible IDs follow party order and Leave is offered")
	state["gold"] = 99999
	state["pockets"]["tinker"].clear()
	state["offers"][0]["price"] = 1
	quote["offers"][1]["price"] = 1
	quote["eligible"].clear()
	var fresh := visit.read_state()
	_check(fresh["gold"] == 100 and fresh["pockets"]["tinker"].size() == 2
		and fresh["offers"] == _offers()
		and visit.quote()["offers"][1]["price"] == STARCH_PRICE
		and visit.quote()["eligible"].size() == 2,
		"mutating returned state or quote changes nothing in the service")
	var swapped := RunStitchedPeddlerWalkSupplies.open_stitched(NODE, _party(),
		_pockets(), 100, [{"id": "starch", "price": 7}, {"id": "spare_spool", "price": 9}])
	_check(swapped.is_valid() and swapped.quote()["offers"][0]["id"] == "starch"
		and _row(swapped.quote(), "spare_spool").get("price") == 9,
		"the offer lookup does not depend on row position")
	var bad_nodes: Array = ["", " ", " " + NODE, NODE + " ", null, 17]
	for node in bad_nodes:
		var bad := _open(100, null, null, null, node)
		_check(not bad.is_valid() and not bad.is_open() and not bad.is_consumed()
			and bad.read_state().get("ok") == false
			and bad.quote().get("ok", true) == false
			and bad.quote().get("choices", ["x"]).is_empty()
			and bad.buy("starch", "rag_duelist", NODE, {}).get("ok", true) == false
			and bad.leave(NODE, {}).get("ok", true) == false,
			"invalid node fails admission and stays inert: " + str(node))
	var bad_parties: Array = [[], _party().slice(0, 3), "no", 42,
		_party() + [{"id": "extra", "rank": 1, "lost": false}]]
	var dup := _party()
	dup[1]["id"] = "rag_duelist"
	bad_parties.append(dup)
	var blank := _party()
	blank[1]["id"] = "  "
	bad_parties.append(blank)
	var dup_rank := _party()
	dup_rank[3]["rank"] = 3
	bad_parties.append(dup_rank)
	var high_rank := _party()
	high_rank[3]["rank"] = 5
	bad_parties.append(high_rank)
	var float_rank := _party()
	float_rank[3]["rank"] = 4.0
	bad_parties.append(float_rank)
	var no_lost := _party()
	no_lost[2].erase("lost")
	bad_parties.append(no_lost)
	var string_lost := _party()
	string_lost[2]["lost"] = "false"
	bad_parties.append(string_lost)
	var non_dict := _party()
	non_dict[0] = "rag_duelist"
	bad_parties.append(non_dict)
	for bad_party in bad_parties:
		var bad := _open(100, null, bad_party)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed party fails admission: " + str(bad_party).substr(0, 50))
	var bad_ledgers: Array = ["no", 42, [], {}]
	var missing := _pockets()
	missing.erase("tinker")
	bad_ledgers.append(missing)
	var extra := _pockets()
	extra["ghost"] = []
	bad_ledgers.append(extra)
	var too_full := _pockets()
	too_full["rag_duelist"] = ["dye", "dye", "dye"]
	bad_ledgers.append(too_full)
	var bad_item := _pockets()
	bad_item["warden"] = ["cursed_ring"]
	bad_ledgers.append(bad_item)
	var int_item := _pockets()
	int_item["warden"] = [5]
	bad_ledgers.append(int_item)
	var not_array := _pockets()
	not_array["warden"] = "starch"
	bad_ledgers.append(not_array)
	for bad_ledger in bad_ledgers:
		var bad := _open(100, null, null, bad_ledger)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed pocket ledger fails admission: " + str(bad_ledger).substr(0, 50))
	for gold in [-1, 1.5, "100", null]:
		_check(not _open(gold).is_valid(), "invalid wallet fails admission: " + str(gold))
	var bad_offers: Array = [42, "no", [], _offers().slice(0, 1),
		_offers() + [{"id": "dye", "price": 5}],
		[{"id": "starch", "price": 5}, {"id": "starch", "price": 6}],
		[{"id": "starch", "price": 5}, {"id": "pins", "price": 6}],
		[{"id": "starch", "price": 5}, {"id": "spare_spool", "price": 0}],
		[{"id": "starch", "price": -5}, {"id": "spare_spool", "price": 6}],
		[{"id": "starch", "price": 5.5}, {"id": "spare_spool", "price": 6}],
		[{"id": "starch", "price": "5"}, {"id": "spare_spool", "price": 6}],
		[{"id": "starch"}, {"id": "spare_spool", "price": 6}],
		[{"price": 5}, {"id": "spare_spool", "price": 6}],
		["starch", "spare_spool"]]
	for bad_offer in bad_offers:
		_check(not _open(100, bad_offer).is_valid(),
			"malformed prepared offers fail admission: " + str(bad_offer).substr(0, 60))
	_check(_open(0).is_valid(), "a zero wallet with two positive quotes is a legal opening")
	var all_items := {"rag_duelist": ["thimble_tonic", "fresh_stuffing"],
		"warden": ["starch", "dye"], "seamstress": ["pins", "spare_spool"],
		"tinker": []}
	_check(_open(100, null, null, all_items).is_valid(),
		"every canonical item ID is a legal pocket entry")


func _assert_quote(visit: RunStitchedPeddlerWalkSupplies, starch_ok: bool,
		spool_ok: bool, eligible: Array, label: String) -> void:
	var before := visit.read_state()
	var quote := visit.quote()
	var starch := _row(quote, "starch")
	var spool := _row(quote, "spare_spool")
	_check(quote.get("ok") == true and starch.get("price") == STARCH_PRICE
		and spool.get("price") == SPOOL_PRICE
		and starch.get("can_buy") == starch_ok and spool.get("can_buy") == spool_ok
		and (starch.get("blocked") == "") == starch_ok
		and (spool.get("blocked") == "") == spool_ok
		and quote.get("eligible") == eligible and quote.get("node_id") == NODE
		and quote.get("mode") == MODE,
		label + ": both rows carry exact prices and honest buyability")
	_check(starch.get("effect_text") == STARCH_TEXT
		and spool.get("effect_text") == SPOOL_TEXT
		and starch.keys().size() == 5 and spool.keys().size() == 5,
		label + ": both rows keep their ID-keyed effect_text (one added field only) whatever the buyability")
	var choices: Array = quote.get("choices")
	_check(choices.has("leave") and choices.has("buy_starch") == starch_ok
		and choices.has("buy_spare_spool") == spool_ok
		and choices.size() == 1 + int(starch_ok) + int(spool_ok),
		label + ": free Leave is always offered and buys only when payable")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": quoting changes nothing")


## AC1/AC4: per-row affordability around each quote, and leave-only quotes.
func _test_quotes() -> void:
	var both := ["rag_duelist", "warden"]
	_assert_quote(_open(SPOOL_PRICE), true, true, both, "wallet equals the dearer quote")
	_assert_quote(_open(SPOOL_PRICE - 1), true, false, both,
		"one gold short of spare_spool only")
	_assert_quote(_open(STARCH_PRICE), true, false, both, "wallet equals the cheaper quote")
	_assert_quote(_open(STARCH_PRICE - 1), false, false, both,
		"one gold short of starch")
	_assert_quote(_open(0), false, false, both, "empty wallet")
	var full := {"rag_duelist": ["dye", "dye"], "warden": ["starch", "pins"],
		"seamstress": ["dye", "dye"], "tinker": ["pins", "spare_spool"]}
	_assert_quote(_open(500, null, null, full), false, false, [], "every pocket full")
	var lost_party := _party()
	lost_party[0]["lost"] = true
	lost_party[1]["lost"] = true
	_assert_quote(_open(500, null, lost_party), false, false, [],
		"open slots belong only to LOST dolls")
	var closed := _open(500)
	closed.leave(NODE, closed.read_state())
	var closed_quote := closed.quote()
	_check(closed_quote.get("ok", true) == false
		and closed_quote.get("choices", ["x"]).is_empty()
		and not closed_quote.has("offers"),
		"a closed visit quotes no choices")


## AC1/AC2: effect_text is keyed by offer ID, not row position, and leaves the
## rest of each row, the input order and the choices untouched.
func _test_effect_text() -> void:
	var orders: Array = [
		[{"id": "spare_spool", "price": SPOOL_PRICE}, {"id": "starch", "price": STARCH_PRICE}],
		[{"id": "starch", "price": STARCH_PRICE}, {"id": "spare_spool", "price": SPOOL_PRICE}]]
	for order in orders:
		var visit := _open(500, order)
		var quote := visit.quote()
		var rows: Array = quote.get("offers", [])
		var label := "order " + str(order[0]["id"]) + " first"
		_check(visit.is_open() and quote.get("ok") == true and rows.size() == 2
			and rows[0]["id"] == order[0]["id"] and rows[1]["id"] == order[1]["id"],
			label + ": the open quote keeps both rows in input order")
		_check(_row(quote, "starch").get("effect_text") == STARCH_TEXT
			and _row(quote, "spare_spool").get("effect_text") == SPOOL_TEXT,
			label + ": each row carries its own exact effect_text by ID")
		_check(_row(quote, "starch").get("price") == STARCH_PRICE
			and _row(quote, "spare_spool").get("price") == SPOOL_PRICE
			and _row(quote, "starch").get("can_buy") == true
			and _row(quote, "spare_spool").get("can_buy") == true
			and _row(quote, "starch").get("blocked") == ""
			and _row(quote, "spare_spool").get("blocked") == ""
			and quote.get("eligible") == ["rag_duelist", "warden"]
			and quote.get("choices") == ["buy_" + str(order[0]["id"]),
				"buy_" + str(order[1]["id"]), "leave"],
			label + ": prices, buyability, eligible IDs and choices are unchanged")
		_check(not visit.read_state()["offers"][0].has("effect_text"),
			label + ": the stored visit state gains no effect_text; only the quote does")
		quote["offers"][0]["effect_text"] = "forged"
		_check(_row(visit.quote(), str(order[0]["id"])).get("effect_text")
			== (STARCH_TEXT if order[0]["id"] == "starch" else SPOOL_TEXT),
			label + ": mutating a returned quote cannot change the service text")
	_check(STARCH_TEXT.length() < 80 and SPOOL_TEXT.length() < 80
		and not "price" in STARCH_TEXT.to_lower() and not "gold" in SPOOL_TEXT.to_lower(),
		"both sentences stay short and quote no price")
	# Blocked rows explain the item too, and a snapshot taken after a quote still buys.
	var poor := _open(0)
	_check(_row(poor.quote(), "starch").get("effect_text") == STARCH_TEXT
		and _row(poor.quote(), "spare_spool").get("effect_text") == SPOOL_TEXT
		and _row(poor.quote(), "starch").get("can_buy") == false,
		"a blocked row still explains the item")
	var asked := _open(100)
	asked.quote()
	_check(asked.buy("starch", "rag_duelist", NODE, asked.read_state()).get("ok") == true,
		"quoting with effect_text does not disturb the snapshot a buy requires")


## AC2: each item charges its own quote once and lands in one pocket only.
func _test_purchases() -> void:
	for item in ["starch", "spare_spool"]:
		var price := STARCH_PRICE if item == "starch" else SPOOL_PRICE
		var visit := _open(price)
		var before := visit.read_state()
		var paid := visit.buy(item, "warden", NODE, before)
		_check(paid.get("ok") == true and paid.get("decision") == "buy"
			and paid.get("item") == item and paid.get("hero_id") == "warden"
			and paid.get("price") == price and paid.get("charged_gold") == price
			and paid.get("gold_before") == price and paid.get("gold") == 0
			and paid.get("status") == "used" and paid.get("consumed") == true
			and paid.get("node_id") == NODE,
			item + ": a price-equal buy charges exactly its own quote")
		_check(paid.get("pocket_before") == ["starch"]
			and paid.get("pocket_after") == ["starch", item]
			and paid.get("pockets_before") == before["pockets"],
			item + ": receipt carries the buyer's before and after pockets "
			+ "(a duplicate of a held item stays within the cap)")
		var after: Dictionary = paid["pockets_after"]
		_check(after["warden"] == ["starch", item] and after["rag_duelist"] == []
			and after["seamstress"] == ["dye", "dye"]
			and after["tinker"] == ["pins", "spare_spool"],
			item + ": only the chosen pocket gained one entry; other pockets are untouched")
		_check(paid["heroes"] == before["heroes"],
			item + ": HP, fray, rank, lost flags and parts are untouched")
		var state := visit.read_state()
		_check(visit.is_consumed() and not visit.is_open() and state["gold"] == 0
			and state["pockets"] == after and state["status"] == "used"
			and state["purchased"] == item and state["offers"] == before["offers"],
			item + ": the consumed visit holds the new ledger and remaining wallet")
		_check(visit.quote().get("ok", true) == false
			and visit.quote().get("choices", ["x"]).is_empty(),
			item + ": a consumed visit offers no further actions")
		paid["pockets_after"]["tinker"].clear()
		paid["pocket_after"].clear()
		paid["heroes"][0]["hp"] = 1
		_check(visit.read_state() == state,
			item + ": mutating the receipt changes nothing in the service")
		var other := "spare_spool" if item == "starch" else "starch"
		_check(visit.buy(item, "rag_duelist", NODE, visit.read_state()).get("ok", true) == false
			and visit.buy(other, "rag_duelist", NODE, visit.read_state()).get("ok", true) == false
			and visit.leave(NODE, visit.read_state()).get("ok", true) == false
			and visit.read_state() == state,
			item + ": replayed buys, the other offer and a later Leave are refused, no second charge")
	# Wallet above the quote debits only the quote; the other offer is consumed too.
	var rich := _open(100)
	var rich_paid := rich.buy("starch", "rag_duelist", NODE, rich.read_state())
	_check(rich_paid.get("ok") == true and rich_paid.get("gold") == 100 - STARCH_PRICE
		and rich_paid.get("pocket_before") == [] and rich_paid.get("pocket_after") == ["starch"],
		"an empty pocket gains one starch and the wallet drops by only its quote")
	var rich_spool := _open(100)
	var spool_paid := rich_spool.buy("spare_spool", "rag_duelist", NODE,
		rich_spool.read_state())
	_check(spool_paid.get("ok") == true and spool_paid.get("gold") == 100 - SPOOL_PRICE
		and spool_paid.get("pocket_after") == ["spare_spool"]
		and rich_spool.buy("starch", "warden", NODE, rich_spool.read_state()).get("ok", true) == false,
		"buying spare_spool consumes the whole visit; starch is no longer purchasable")
	var twin_pockets := _pockets()
	twin_pockets["tinker"] = ["spare_spool"]
	var twin := _open(100, null, null, twin_pockets)
	var twin_paid := twin.buy("spare_spool", "tinker", NODE, twin.read_state())
	_check(twin_paid.get("ok") == true
		and twin_paid.get("pocket_after") == ["spare_spool", "spare_spool"],
		"two identical entries may coexist in one pocket")
	# The Walk keeps the effect and cost for use: purchase touches no heroes or WHIRR.
	_check(not rich_paid.has("whirr") and not rich_paid.has("effect"),
		"purchase carries no WHIRR cost and fires no item effect")
	_check(not rich_paid.has("effect_text") and not rich_paid.has("guard")
		and not rich_paid.has("next_fight") and not spool_paid.has("repair")
		and rich_paid["heroes"] == _party() and spool_paid["heroes"] == _party()
		and rich.read_state()["heroes"] == _party()
		and rich_spool.read_state()["heroes"] == _party(),
		"a sale applies no Walk or next-fight effect and leaves every doll's HP, fray and parts unchanged")
	var hero_leave := _open(100)
	hero_leave.leave(NODE, hero_leave.read_state())
	_check(hero_leave.read_state()["heroes"] == _party()
		and hero_leave.read_state()["gold"] == 100,
		"Leave leaves the dolls and the wallet unchanged")


## AC3: every real precondition refuses with no drift and keeps a legal buy/Leave.
func _test_refusals() -> void:
	var poor := _open(STARCH_PRICE - 1)
	var poor_snap := poor.read_state()
	_reject(poor, "starch", "rag_duelist", NODE, poor_snap, "one gold short of starch")
	_reject(poor, "spare_spool", "rag_duelist", NODE, poor_snap,
		"far short of spare_spool")
	var mid := _open(SPOOL_PRICE - 1)
	_reject(mid, "spare_spool", "rag_duelist", NODE, mid.read_state(),
		"enough for starch but one gold short of spare_spool")
	var mid_paid := mid.buy("starch", "rag_duelist", NODE, mid.read_state())
	_check(mid_paid.get("ok") == true and mid_paid.get("charged_gold") == STARCH_PRICE,
		"after an unaffordable refusal the affordable offer still buys")
	var visit := _open(300)
	var snap := visit.read_state()
	_reject(visit, "starch", "seamstress", NODE, snap, "full pocket (identical items)")
	_reject(visit, "spare_spool", "tinker", NODE, snap, "full pocket (mixed items)")
	_reject(visit, "starch", "nobody", NODE, snap, "unknown hero")
	_reject(visit, "starch", "", NODE, snap, "empty hero")
	_reject(visit, "starch", null, NODE, snap, "null hero")
	_reject(visit, "starch", 7, NODE, snap, "non-string hero")
	_reject(visit, "dye", "rag_duelist", NODE, snap, "non-offered canonical item")
	_reject(visit, "pins", "rag_duelist", NODE, snap, "pins is not for sale here")
	_reject(visit, "stitched_badge", "rag_duelist", NODE, snap, "unknown item")
	_reject(visit, "", "rag_duelist", NODE, snap, "empty item")
	_reject(visit, null, "rag_duelist", NODE, snap, "null item")
	_reject(visit, 3, "rag_duelist", NODE, snap, "non-string item")
	_reject(visit, "starch", "rag_duelist", "other-node", snap, "wrong node buy")
	_reject(visit, "starch", "rag_duelist", "", snap, "empty node buy")
	var wrong_leave := visit.leave("other-node", snap)
	_check(wrong_leave.get("ok", true) == false and visit.is_open(),
		"wrong node leave refuses without consuming")
	_reject(visit, "starch", "rag_duelist", NODE, {}, "omitted snapshot")
	_reject(visit, "starch", "rag_duelist", NODE, null, "null snapshot")
	_reject(visit, "starch", "rag_duelist", NODE, "no", "non-dictionary snapshot")
	for field in ["visit_id", "gold", "status", "mode", "node_id", "consumed",
			"eligible", "purchased"]:
		var stale := snap.duplicate(true)
		stale[field] = int(stale[field]) + 1 if field == "gold" else "wrong"
		_reject(visit, "starch", "rag_duelist", NODE, stale, "stale snapshot: " + field)
	var missing_key := snap.duplicate(true)
	missing_key.erase("pockets")
	_reject(visit, "starch", "rag_duelist", NODE, missing_key, "snapshot missing pockets")
	var forged_prices := snap.duplicate(true)
	forged_prices["offers"][1]["price"] = 1
	_reject(visit, "starch", "rag_duelist", NODE, forged_prices, "forged quoted price")
	var forged_pockets := snap.duplicate(true)
	forged_pockets["pockets"]["rag_duelist"] = ["dye"]
	_reject(visit, "starch", "rag_duelist", NODE, forged_pockets, "forged pocket snapshot")
	var forged_heroes := snap.duplicate(true)
	forged_heroes["heroes"][0]["lost"] = true
	_reject(visit, "starch", "rag_duelist", NODE, forged_heroes, "forged roster snapshot")
	# A second visit with an identical ledger must not accept the first's snapshot.
	var twin := _open(300)
	var twin_snap := twin.read_state()
	_check(twin_snap["visit_id"] != snap["visit_id"]
		and twin_snap["pockets"] == snap["pockets"] and twin_snap["gold"] == snap["gold"],
		"an identical-ledger visit still carries its own one-time visit ID")
	_reject(visit, "starch", "rag_duelist", NODE, twin_snap,
		"cross-visit identical-ledger snapshot")
	_reject(twin, "starch", "rag_duelist", NODE, snap, "cross-visit snapshot (reverse)")
	_check(visit.leave(NODE, twin_snap).get("ok", true) == false and visit.is_open()
		and twin.leave(NODE, snap).get("ok", true) == false and twin.is_open(),
		"a cross-visit snapshot cannot Leave either")
	_reject(visit, "starch", "rag_duelist", NODE, _open(301).read_state(),
		"another visit's differing snapshot")
	var lost_party := _party()
	lost_party[0]["lost"] = true
	var lost_visit := _open(300, null, lost_party)
	_reject(lost_visit, "starch", "rag_duelist", NODE, lost_visit.read_state(),
		"LOST doll with an empty pocket")
	var lost_paid := lost_visit.buy("spare_spool", "warden", NODE, lost_visit.read_state())
	_check(lost_paid.get("ok") == true and lost_paid["heroes"] == lost_party
		and lost_paid["pockets_after"]["rag_duelist"] == [],
		"the living doll buys once and the LOST doll stays untouched")
	var all_lost := _party()
	all_lost[0]["lost"] = true
	all_lost[1]["lost"] = true
	var blocked := _open(500, null, all_lost)
	var blocked_snap := blocked.read_state()
	for item in ["starch", "spare_spool"]:
		for target in ["rag_duelist", "warden", "seamstress", "tinker"]:
			_reject(blocked, item, target, NODE, blocked_snap,
				"no legal buyer: " + item + " for " + target)
	var paid := visit.buy("spare_spool", "rag_duelist", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 300 - SPOOL_PRICE
		and paid.get("pocket_after") == ["spare_spool"],
		"after every refusal the fresh exact choice still buys legally")
	_check(visit.is_consumed() and twin.read_state()["gold"] == 300 and twin.is_open(),
		"the cross-visit twin was never charged and stays open")


## AC4: Leave is free from buyable and leave-only quotes and closes exactly once.
func _test_leave() -> void:
	var leaving := _open(80)
	var left := leaving.leave(NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left.get("charged_gold") == 0 and left.get("gold") == 80
		and left.get("pockets") == _pockets() and left.get("heroes") == _party()
		and left.get("status") == "left" and left.get("consumed") == true,
		"Leave from a buyable quote consumes the visit without charge or pocket change")
	_check(leaving.is_consumed() and leaving.read_state()["gold"] == 80
		and leaving.read_state()["pockets"] == _pockets()
		and leaving.leave(NODE, leaving.read_state()).get("ok", true) == false
		and leaving.buy("starch", "rag_duelist", NODE, leaving.read_state()).get("ok", true) == false
		and leaving.quote().get("choices", ["x"]).is_empty(),
		"a left visit refuses Leave and buy and offers no actions")
	left["pockets"]["warden"].clear()
	_check(leaving.read_state()["pockets"]["warden"] == ["starch"],
		"mutating the Leave receipt changes nothing in the service")
	var poor := _open(STARCH_PRICE - 1)
	_reject(poor, "starch", "rag_duelist", NODE, poor.read_state(), "poor buy before Leave")
	var poor_left := poor.leave(NODE, poor.read_state())
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor_left.get("gold") == STARCH_PRICE - 1 and poor_left.get("pockets") == _pockets()
		and poor.is_consumed() and poor.leave(NODE, poor.read_state()).get("ok", true) == false,
		"a leave-only quote still leaves free after a blocked choice, once")
	var full := {"rag_duelist": ["dye", "dye"], "warden": ["starch", "pins"],
		"seamstress": ["dye", "dye"], "tinker": ["pins", "spare_spool"]}
	var full_visit := _open(500, null, null, full)
	var full_left := full_visit.leave(NODE, full_visit.read_state())
	_check(full_left.get("ok") == true and full_left.get("gold") == 500
		and full_left.get("pockets") == full and full_visit.is_consumed(),
		"a full-pocket visit with ample gold leaves free and keeps every pocket")
	# A refused action after a failed buy cannot be replayed once Leave closed it.
	var late := _open(100)
	var late_snap := late.read_state()
	_reject(late, "starch", "nobody", NODE, late_snap, "blocked choice before Leave")
	late.leave(NODE, late_snap)
	_check(late.buy("starch", "rag_duelist", NODE, late_snap).get("ok", true) == false
		and late.read_state()["gold"] == 100 and late.read_state()["status"] == "left",
		"the pre-Leave snapshot cannot buy after the visit is closed")
## --- Routed Stitched Peddler witness (S6 stop integration): the real
## StitchedRunSession mounts the combined Walk-supplies service at a seeded,
## connected Shop node entered through session.enter. ---


func _shop_action(actions: Array, id: String, arguments: Array) -> Dictionary:
	for action in actions:
		if action.id == id and action.arguments == arguments:
			return action
	return {}


func _enter_shop(session: StitchedRunSession, label: String) -> bool:
	_check(session != null and session.phase == "map", label + ": run is at the map phase")
	if session == null or session.phase != "map":
		return false
	_check(session.choices().has(SHOP_NODE) and session.map.get_node(SHOP_NODE).type == "Shop",
		label + ": pinned seed %d offers the legal opening Shop %s" % [RUN_SEED, SHOP_NODE])
	_check(session.enter(SHOP_NODE, session.snapshot()) and session.phase == "visit"
		and session.pending.service == "Peddler" and session.pending.node_id == SHOP_NODE
		and session.candle == 100 - StitchedRunSession.NODE_CANDLE_COST,
		label + ": authentic route entry mounts the real Peddler with the existing candle toll")
	return session.phase == "visit" and session.pending.service == "Peddler"


## AC1/AC3/AC4: zero-gold fresh route at the pinned Shop, including save/reload.
func _test_routed_zero_gold_route() -> void:
	var session := StitchedRunSession.start(RUN_SEED)
	_check(session != null and session.gold == 0 and session.heroes.size() == 4
		and session.pockets.size() == 4,
		"fresh route starts with four dolls, four pockets and the normal empty wallet")
	if not _enter_shop(session, "zero-gold route"):
		return
	var actions := session.visit_actions()
	_check(actions.filter(func(a): return a.id in ["buy_starch", "buy_spare_spool"]).size() == 8,
		"both Walk-supply offers are mounted exactly once per doll")
	for hero in session.heroes:
		for item in ["starch", "spare_spool"]:
			var action := _shop_action(actions, "buy_" + item, [hero.id])
			_check(not action.is_empty() and action.enabled == false
				and (str(StitchedRunSession.PEDDLER_PRICE) + " gold") in action.text
				and hero.name in action.text,
				"zero-gold route mounts a disabled buy_" + item + " for " + hero.id + " at the Peddler price")
	for id in ["buy_candle_stub", "buy_part", "buy_pins", "buy_thimble_tonic",
			"buy_fresh_stuffing", "buy_dye", "leave"]:
		_check(actions.any(func(a): return a.id == id),
			"zero-gold route retains the existing " + id + " action")
	_check(actions.any(func(a): return a.id == "leave" and a.enabled), "free Leave stays enabled")
	var before := session.snapshot()
	var journal := session.journal.duplicate(true)
	for hero in session.heroes:
		_check(not session.choose_visit("buy_starch", [hero.id], before)
			and not session.choose_visit("buy_spare_spool", [hero.id], before),
			"zero-gold starch/spool offers are refused for " + hero.id)
	var forged := before.duplicate(true)
	forged.gold = 999
	_check(not session.choose_visit("buy_starch", [session.heroes[0].id], forged),
		"a forged wallet snapshot cannot authorize a purchase")
	_check(not session.choose_visit("buy_starch", ["nobody"], before),
		"an incorrect action argument is refused")
	_check(not session.choose_visit("buy_dye_vat", [session.heroes[0].id], before),
		"an unoffered item is refused")
	_check(session.snapshot() == before and session.journal == journal,
		"every zero-gold refusal is atomic and RNG-neutral")
	var saved := StitchedRunSave.capture(session)
	_check(not saved.is_empty() and saved.version == StitchedRunSession.VERSION,
		"the pending legal Peddler node captures a VERSION 1 save")
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(saved)))
	_check(restored != null and restored.snapshot() == before,
		"restore replays the exact pending Peddler state, wallet, pockets and canonical RNG")
	if restored != null:
		_check(restored.visit_actions() == actions,
			"the restored visit mounts the identical starch/spool actions and 10-gold quotes")
		_check(not restored.choose_visit("buy_starch", [restored.heroes[0].id], restored.snapshot()),
			"the restored zero-gold visit still refuses the purchase")
	_check(session.choose_visit("leave", [], before) and session.phase == "map"
		and session.gold == 0 and session.pockets == before.pockets
		and session.rng.state == before.rng and session.map.export_state() == before.map,
		"free Leave closes the zero-gold Peddler without charge or RNG change")
	var left := session.snapshot()
	_check(not session.choose_visit("buy_starch", [session.heroes[0].id], before)
		and not session.choose_visit("leave", [], before) and session.snapshot() == left,
		"the consumed node refuses old-node and repeat-click decisions")
	var after_restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(StitchedRunSave.capture(session))))
	_check(after_restored != null and after_restored.snapshot() == left,
		"the left Peddler route still round-trips its sealed state")


## AC2: each item in its own fresh fixture-funded visit through choose_visit.
func _test_routed_funded_purchases() -> void:
	for item in ["starch", "spare_spool"]:
		var session := StitchedRunSession.start(RUN_SEED)
		# FIXTURE: a deliberately test-funded wallet, sealed before the authentic
		# route entry; explicitly NOT battle-earned gold.
		session.gold = FIXTURE_GOLD
		session._seal()
		if not _enter_shop(session, item + " funded visit"):
			continue
		var actions := session.visit_actions()
		for hero in session.heroes:
			var action := _shop_action(actions, "buy_" + item, [hero.id])
			_check(not action.is_empty() and action.enabled
				and (str(StitchedRunSession.PEDDLER_PRICE) + " gold") in action.text,
				item + ": the funded visit enables the offer for every doll " + hero.id)
		var hero_id: String = session.heroes[0].id
		var before := session.snapshot()
		var stale := before.duplicate(true)
		stale.gold = FIXTURE_GOLD - 1
		_check(not session.choose_visit("buy_" + item, [hero_id], stale)
			and session.snapshot() == before, item + ": a stale snapshot cannot authorize the purchase")
		var receipts_before := session.receipts.size()
		var journal_size := session.journal.size()
		_check(session.choose_visit("buy_" + item, [hero_id], before),
			item + ": choose_visit commits the purchase through the real service")
		var expected_pockets: Dictionary = before.pockets.duplicate(true)
		expected_pockets[hero_id] = [item]
		var after := session.snapshot()
		_check(session.phase == "map"
			and session.gold == FIXTURE_GOLD - StitchedRunSession.PEDDLER_PRICE
			and session.pockets == expected_pockets and session.heroes == before.heroes
			and after.rng == before.rng and after.map == before.map and after.candle == before.candle
			and after.walk == before.walk and session.pending.is_empty(),
			item + ": exactly 10 gold is charged once and one item is appended; heroes, candle, RNG and Walk are untouched")
		_check(session.receipts.size() == receipts_before + 1
			and session.receipts.back().decision == "buy_" + item
			and session.receipts.back().steps.size() == 1
			and session.journal.size() == journal_size + 1
			and session.journal.back() == {"action": "visit", "id": "buy_" + item, "arguments": [hero_id]},
			item + ": the visited node closes with exactly one receipt and one journal entry")
		_check(not session.choose_visit("buy_" + item, [hero_id], before)
			and not session.choose_visit("buy_starch" if item == "spare_spool" else "buy_spare_spool",
				[hero_id], after) and session.snapshot() == after,
			item + ": repeat clicks, the other offer and stale snapshots are refused after the close")


## AC3: a full pocket and a LOST doll disable exactly their own offers; Leave stays free.
func _test_routed_disabled_offers() -> void:
	var session := StitchedRunSession.start(RUN_SEED)
	session.gold = FIXTURE_GOLD
	# Fixture ledger: one full pocket and one LOST doll, sealed before entry.
	var full_id: String = session.heroes[0].id
	var lost_id: String = session.heroes[1].id
	session.pockets[full_id] = ["dye", "dye"]
	for hero in session.heroes:
		if hero.id == lost_id:
			hero.lost = true
	session._seal()
	if not _enter_shop(session, "disabled-offer route"):
		return
	var actions := session.visit_actions()
	for item in ["starch", "spare_spool"]:
		for hero in session.heroes:
			var action := _shop_action(actions, "buy_" + item, [hero.id])
			var expected: bool = hero.id != lost_id and hero.id != full_id
			_check(not action.is_empty() and action.enabled == expected,
				item + ": the offer for " + hero.id + " is enabled only for a living doll with a free slot")
	var before := session.snapshot()
	_check(not session.choose_visit("buy_starch", [full_id], before)
		and not session.choose_visit("buy_spare_spool", [lost_id], before)
		and session.snapshot() == before,
		"full-pocket and LOST-doll offers are refused without any change")
	var buyer: String = session.heroes[2].id
	_check(session.choose_visit("buy_starch", [buyer], before)
		and session.gold == FIXTURE_GOLD - StitchedRunSession.PEDDLER_PRICE
		and session.pockets[buyer] == ["starch"] and session.pockets[full_id] == ["dye", "dye"],
		"the eligible doll still buys starch once while the full/lost offers stay disabled")
	var poor := StitchedRunSession.start(RUN_SEED)
	if _enter_shop(poor, "leave-only route"):
		var poor_before := poor.snapshot()
		_check(poor.choose_visit("leave", [], poor_before) and poor.phase == "map"
			and poor.gold == 0 and poor.pockets == poor_before.pockets
			and poor.rng.state == poor_before.rng,
			"Leave still works without charge when purchases are unavailable")
