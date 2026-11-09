extends SceneTree
## Design v4 Stitched Peddler fresh-stuffing visit contract: the opt-in
## quoted-gold one-use buy (append one literal "fresh_stuffing" to one doll's
## Walk pocket, no healing, no WHIRR) or free Leave, guarded by the exact node and
## a complete open state, fully detached and RNG-neutral. Scene-free service test.

const NODE := "route-peddler-fs-4"
const MODE := "stitched"
## Sample fixture quote ONLY; the game owns no fresh-stuffing price yet.
const SAMPLE_QUOTE := 13
const ITEM := "fresh_stuffing"
## Exact advisory text the open quote must carry (explanation, never authority).
const EFFECT := "Use during the Walk: heal 35% HP; costs 15 WHIRR (5 to use plus 10 extra)."

var failures: Array[String] = []
var checks := 0
var rng := RandomNumberGenerator.new()


func _initialize() -> void:
	rng.seed = 424242
	var rng_state := rng.state
	seed(424242)
	var next_draw := randi()
	seed(424242)
	_test_admission_and_isolation()
	_test_quotes()
	_test_purchase_and_leave()
	_test_refusals()
	_test_lost_and_full()
	_test_cross_visit_identity()
	_check(randi() == next_draw,
		"open, quote, buys, Leaves and every refusal draw no global RNG")
	_check(rng.state == rng_state, "the seeded RandomNumberGenerator never advanced")
	if failures.is_empty():
		print("run_stitched_peddler_fresh_stuffing_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_fresh_stuffing_test: FAIL (", failures.size(),
			" failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


## rag_duelist is at 0 HP but NOT lost (Hanging by a Thread).
func _party() -> Array:
	return [
		{"id": "rag_duelist", "rank": 1, "hp": 0, "fray": 12, "lost": false,
			"parts": {"blade": {"tier": 2, "meta": {"kills": 3}}}},
		{"id": "warden", "rank": 2, "hp": 40, "fray": 0, "lost": false,
			"parts": {"shield": {"tier": 1}}},
		{"id": "seamstress", "rank": 3, "hp": 25, "fray": 5, "lost": false,
			"parts": {"needle": {"tier": 3}}},
		{"id": "tinker", "rank": 4, "hp": 28, "fray": 8, "lost": false,
			"parts": {"turret": {"tier": 1}}},
	]


## rag_duelist empty, warden one starch, seamstress and tinker full.
func _pockets() -> Dictionary:
	return {
		"rag_duelist": [],
		"warden": ["starch"],
		"seamstress": ["dye", "dye"],
		"tinker": ["pins", "spare_spool"],
	}


func _open(gold: Variant, price: Variant = SAMPLE_QUOTE, node: Variant = NODE,
		dolls: Variant = null, pockets: Variant = null) -> RunStitchedPeddlerFreshStuffing:
	if dolls == null:
		dolls = _party()
	if pockets == null:
		pockets = _pockets()
	return RunStitchedPeddlerFreshStuffing.open_stitched(node, dolls, pockets, gold,
		price)


func _reject(visit: RunStitchedPeddlerFreshStuffing, doll: Variant, node: Variant,
		state: Variant, label: String) -> void:
	var before := visit.read_state()
	var result := visit.buy_fresh_stuffing(doll, node, state)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": no drift in dolls, pockets, wallet or status; visit still open")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


func _test_admission_and_isolation() -> void:
	var party := _party()
	var pockets := _pockets()
	var visit := RunStitchedPeddlerFreshStuffing.open_stitched(NODE, party, pockets,
		100, SAMPLE_QUOTE)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid node, dolls, pockets, wallet and quote open the visit")
	party[0]["hp"] = 1
	pockets["rag_duelist"].append("dye")
	pockets["warden"].clear()
	var state := visit.read_state()
	_check(state.get("ok") == true and state.get("mode") == MODE
		and state.get("node_id") == NODE and state.get("gold") == 100
		and state.get("price") == SAMPLE_QUOTE and state.get("status") == "open"
		and state.get("consumed") == false,
		"read_state carries node, mode, wallet, quote, status and open flag")
	_check(state["heroes"][0]["hp"] == 0 and state["pockets"]["rag_duelist"] == []
		and state["pockets"]["warden"] == ["starch"],
		"mutating the caller's input after opening cannot forge the state")
	_check(state.get("eligible") == ["rag_duelist", "warden"],
		"HP-0 not-LOST doll and the starch doll are eligible; full pockets are not")
	var quote := visit.quote()
	state["gold"] = 99999
	state["pockets"]["tinker"].clear()
	state["heroes"][1]["hp"] = 1
	quote["price"] = 1
	quote["eligible"].clear()
	var fresh := visit.read_state()
	_check(fresh["gold"] == 100 and fresh["pockets"]["tinker"].size() == 2
		and fresh["heroes"][1]["hp"] == 40 and visit.quote()["price"] == SAMPLE_QUOTE
		and visit.quote()["eligible"].size() == 2,
		"mutating returned state or quote changes nothing in the service")
	var bad_nodes: Array = ["", " ", " " + NODE, NODE + " ", null, 17]
	for node in bad_nodes:
		var bad := _open(100, SAMPLE_QUOTE, node)
		_check(not bad.is_valid() and not bad.is_open() and not bad.is_consumed()
			and bad.read_state().get("ok") == false
			and bad.quote().get("ok", true) == false
			and bad.quote().get("choices", ["x"]).is_empty()
			and bad.buy_fresh_stuffing("rag_duelist", NODE, {}).get("ok", true) == false
			and bad.leave(NODE, {}).get("ok", true) == false,
			"invalid node fails admission and stays inert: " + str(node))
	var bad_parties: Array = [[], _party().slice(0, 3), "no", null,
		_party() + [{"id": "extra", "rank": 1, "lost": false}]]
	var dup := _party()
	dup[1]["id"] = "rag_duelist"
	bad_parties.append(dup)
	var blank := _party()
	blank[1]["id"] = "  "
	bad_parties.append(blank)
	var empty_id := _party()
	empty_id[1]["id"] = ""
	bad_parties.append(empty_id)
	var int_id := _party()
	int_id[1]["id"] = 7
	bad_parties.append(int_id)
	var dup_rank := _party()
	dup_rank[3]["rank"] = 3
	bad_parties.append(dup_rank)
	var high_rank := _party()
	high_rank[3]["rank"] = 5
	bad_parties.append(high_rank)
	var zero_rank := _party()
	zero_rank[3]["rank"] = 0
	bad_parties.append(zero_rank)
	var float_rank := _party()
	float_rank[3]["rank"] = 4.0
	bad_parties.append(float_rank)
	var no_lost := _party()
	no_lost[2].erase("lost")
	bad_parties.append(no_lost)
	var string_lost := _party()
	string_lost[2]["lost"] = "false"
	bad_parties.append(string_lost)
	var int_lost := _party()
	int_lost[2]["lost"] = 0
	bad_parties.append(int_lost)
	var non_dict := _party()
	non_dict[0] = "rag_duelist"
	bad_parties.append(non_dict)
	for bad_party in bad_parties:
		var bad := RunStitchedPeddlerFreshStuffing.open_stitched(NODE, bad_party,
			_pockets(), 100, SAMPLE_QUOTE)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed party fails admission: " + str(bad_party).substr(0, 50))
	var bad_ledgers: Array = ["no", null, [], {}]
	var missing := _pockets()
	missing.erase("tinker")
	bad_ledgers.append(missing)
	var extra := _pockets()
	extra["ghost"] = []
	bad_ledgers.append(extra)
	var swapped := _pockets()
	swapped.erase("tinker")
	swapped["ghost"] = []
	bad_ledgers.append(swapped)
	var too_full := _pockets()
	too_full["rag_duelist"] = ["dye", "dye", "dye"]
	bad_ledgers.append(too_full)
	var bad_item := _pockets()
	bad_item["warden"] = ["cursed_ring"]
	bad_ledgers.append(bad_item)
	var int_item := _pockets()
	int_item["warden"] = [5]
	bad_ledgers.append(int_item)
	var null_item := _pockets()
	null_item["warden"] = [null]
	bad_ledgers.append(null_item)
	var not_array := _pockets()
	not_array["warden"] = "starch"
	bad_ledgers.append(not_array)
	var dict_pocket := _pockets()
	dict_pocket["warden"] = {"starch": 1}
	bad_ledgers.append(dict_pocket)
	var int_key := {"rag_duelist": [], "warden": [], "seamstress": [], 4: []}
	bad_ledgers.append(int_key)
	for bad_ledger in bad_ledgers:
		var bad := RunStitchedPeddlerFreshStuffing.open_stitched(NODE, _party(),
			bad_ledger, 100, SAMPLE_QUOTE)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed pocket ledger fails admission: " + str(bad_ledger).substr(0, 50))
	for gold in [-1, 1.5, "100", null]:
		_check(not _open(gold).is_valid(), "invalid wallet fails admission: " + str(gold))
	for price in [0, -5, 13.5, "13", null]:
		_check(not _open(100, price).is_valid(),
			"invalid quote fails admission: " + str(price))
	_check(_open(0, 1).is_valid() and _open(0, SAMPLE_QUOTE).is_valid(),
		"a zero wallet with a positive quote is a legal opening")
	var all_items := {"rag_duelist": ["thimble_tonic", "fresh_stuffing"],
		"warden": ["starch", "dye"], "seamstress": ["pins", "spare_spool"],
		"tinker": []}
	_check(_open(100, SAMPLE_QUOTE, NODE, null, all_items).is_valid(),
		"every legal pocket item ID, including fresh_stuffing, is admitted")


func _assert_quote(visit: RunStitchedPeddlerFreshStuffing, gold: int, choices: Array,
		can_buy: bool, blocked: String, eligible: Array, label: String) -> void:
	var before := visit.read_state()
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("choices") == choices
		and quote.get("can_buy") == can_buy and quote.get("blocked") == blocked
		and quote.get("price") == SAMPLE_QUOTE and quote.get("gold") == gold
		and quote.get("eligible") == eligible and quote.get("item") == ITEM
		and quote.get("node_id") == NODE and quote.get("mode") == MODE,
		label + ": choices, can_buy, blocked, price and eligible IDs are honest")
	_check(quote.get("choices").has("leave"), label + ": free Leave is always offered")
	var text: Variant = quote.get("effect_text")
	_check(typeof(text) == TYPE_STRING and text == EFFECT
		and RunStitchedPeddlerFreshStuffing.EFFECT_TEXT == EFFECT,
		label + ": exactly one constant effect_text on the open quote")
	_check(str(text).contains("Walk") and str(text).contains("35% HP")
		and str(text).contains("15 WHIRR") and str(text).contains("10 extra")
		and str(text).contains("5 to use"),
		label + ": effect_text names Walk use, 35% HP, 15 WHIRR, 5 plus 10 extra")
	_check(quote.keys().count("effect_text") == 1 and not before.has("effect_text"),
		label + ": effect_text is a quote-only key, not in read_state")
	var scribbled := visit.quote()
	scribbled["effect_text"] = "free healing"
	scribbled["choices"].clear()
	_check(visit.quote() == quote and visit.quote().get("effect_text") == EFFECT,
		label + ": mutating a returned quote cannot alter the next fresh quote")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": quoting changes nothing")


func _test_quotes() -> void:
	var both := ["rag_duelist", "warden"]
	_assert_quote(_open(SAMPLE_QUOTE), SAMPLE_QUOTE,
		["buy_fresh_stuffing", "leave"], true, "", both, "quote-equal wallet")
	_assert_quote(_open(500), 500, ["buy_fresh_stuffing", "leave"], true, "", both,
		"ample gold")
	_assert_quote(_open(SAMPLE_QUOTE - 1), SAMPLE_QUOTE - 1, ["leave"], false,
		"not enough gold", [], "one gold short offers no false Buy")
	_assert_quote(_open(0), 0, ["leave"], false, "not enough gold", [],
		"empty wallet")
	var full := {"rag_duelist": ["dye", "dye"], "warden": ["starch", "pins"],
		"seamstress": ["dye", "dye"], "tinker": ["pins", "spare_spool"]}
	_assert_quote(_open(500, SAMPLE_QUOTE, NODE, null, full), 500, ["leave"], false,
		"no doll can carry fresh stuffing", [], "every pocket full")
	var one_slot := _pockets()
	one_slot["rag_duelist"] = ["pins", "pins"]
	one_slot["warden"] = ["pins", "dye"]
	one_slot["seamstress"] = ["thimble_tonic"]
	_assert_quote(_open(500, SAMPLE_QUOTE, NODE, null, one_slot), 500,
		["buy_fresh_stuffing", "leave"], true, "", ["seamstress"],
		"mixed pockets with one open position")
	var closed := _open(500)
	closed.leave(NODE, closed.read_state())
	var closed_quote := closed.quote()
	_check(closed_quote.get("ok", true) == false
		and closed_quote.get("choices", ["x"]).is_empty()
		and not closed_quote.has("can_buy"),
		"a closed visit quotes no choices and no purchase")
	_check(not closed_quote.has("effect_text"),
		"a left visit's quote carries no effect_text")
	var bought := _open(500)
	bought.buy_fresh_stuffing("warden", NODE, bought.read_state())
	var bought_quote := bought.quote()
	_check(bought_quote.get("ok", true) == false
		and bought_quote.get("choices", ["x"]).is_empty()
		and not bought_quote.has("effect_text") and not bought_quote.has("can_buy"),
		"a bought visit's quote carries no effect_text and no actionable choice")
	var invalid_quote := _open(500, SAMPLE_QUOTE, "").quote()
	_check(invalid_quote.get("ok", true) == false
		and invalid_quote.get("choices", ["x"]).is_empty()
		and not invalid_quote.has("effect_text"),
		"an invalid visit's quote carries no effect_text")
	var bad_price_quote := _open(500, 0).quote()
	_check(bad_price_quote.get("ok", true) == false
		and not bad_price_quote.has("effect_text"),
		"a visit with an invalid quote price carries no effect_text")
	var lone := _open(500, SAMPLE_QUOTE, NODE, null, one_slot)
	var lone_quote := lone.quote()
	_check(lone_quote.get("effect_text") == EFFECT
		and lone_quote.get("eligible") == ["seamstress"]
		and lone_quote.get("choices") == ["buy_fresh_stuffing", "leave"],
		"one-eligible-doll quote explains the use and lists only that buyer")


func _test_purchase_and_leave() -> void:
	var visit := _open(SAMPLE_QUOTE)
	var before := visit.read_state()
	var paid := visit.buy_fresh_stuffing("warden", NODE, before)
	_check(paid.get("ok") == true and paid.get("decision") == "buy_fresh_stuffing"
		and paid.get("node_id") == NODE and paid.get("doll_id") == "warden"
		and paid.get("item") == ITEM and paid.get("price") == SAMPLE_QUOTE
		and paid.get("charged_gold") == SAMPLE_QUOTE and paid.get("gold") == 0
		and paid.get("status") == "used" and paid.get("consumed") == true,
		"a quote-equal buy charges exactly the quote and empties the wallet")
	_check(paid.get("pocket_before") == ["starch"]
		and paid.get("pocket_after") == ["starch", ITEM]
		and paid.get("pockets_before") == before["pockets"],
		"the receipt carries the buyer's before and after pockets")
	var after: Dictionary = paid["pockets_after"]
	_check(after["warden"] == ["starch", ITEM] and after["rag_duelist"] == []
		and after["seamstress"] == ["dye", "dye"]
		and after["tinker"] == ["pins", "spare_spool"],
		"only the selected doll's pocket gained one fresh_stuffing")
	_check(paid["heroes"] == before["heroes"] and paid["heroes"] == _party(),
		"HP, fray, rank, lost flags and parts are untouched: no healing, no WHIRR")
	_check(not paid.has("effect_text") and not before.has("effect_text")
		and not paid.has("whirr") and not paid.has("healed")
		and paid["pockets_after"]["warden"].count(ITEM) == 1
		and paid["pockets_after"]["warden"].count(EFFECT) == 0,
		"the advisory text is no receipt field and no pocket or inventory entry")
	_check(paid["gold"] == before["gold"] - paid["charged_gold"]
		and paid["charged_gold"] == before["price"],
		"gold is charged exactly once at the quoted price")
	var state := visit.read_state()
	_check(visit.is_consumed() and not visit.is_open() and state["gold"] == 0
		and state["pockets"] == after and state["heroes"] == before["heroes"]
		and state["status"] == "used",
		"the consumed visit holds the new ledger, remaining wallet and used status")
	_check(visit.quote().get("ok", true) == false
		and visit.quote().get("choices", ["x"]).is_empty(),
		"the consumed visit offers no further choices")
	paid["pockets_after"]["tinker"].clear()
	paid["pocket_after"].clear()
	paid["pockets_before"]["warden"].clear()
	paid["heroes"][0]["hp"] = 99
	var again_state := visit.read_state()
	_check(again_state["pockets"]["warden"] == ["starch", ITEM]
		and again_state["pockets"]["tinker"].size() == 2
		and again_state["heroes"][0]["hp"] == 0,
		"mutating the receipt changes nothing in the service")
	var replay := visit.buy_fresh_stuffing("rag_duelist", NODE, visit.read_state())
	_check(replay.get("ok", true) == false and visit.read_state() == again_state
		and visit.leave(NODE, visit.read_state()).get("ok", true) == false
		and visit.read_state() == again_state,
		"a second buy or a later Leave is refused with no second charge")
	var rich := _open(100)
	var rich_paid := rich.buy_fresh_stuffing("rag_duelist", NODE, rich.read_state())
	_check(rich_paid.get("ok") == true and rich_paid.get("gold") == 100 - SAMPLE_QUOTE
		and rich_paid.get("charged_gold") == SAMPLE_QUOTE
		and rich_paid.get("pocket_before") == []
		and rich_paid.get("pocket_after") == [ITEM]
		and rich_paid["heroes"][0]["hp"] == 0 and rich_paid["heroes"][0]["lost"] == false,
		"an empty pocket gains one fresh_stuffing; the HP-0 doll is not healed")
	var twin_pockets := _pockets()
	twin_pockets["tinker"] = [ITEM]
	var twin := _open(100, SAMPLE_QUOTE, NODE, null, twin_pockets)
	var twin_paid := twin.buy_fresh_stuffing("tinker", NODE, twin.read_state())
	_check(twin_paid.get("ok") == true
		and twin_paid.get("pocket_after") == [ITEM, ITEM],
		"two identical fresh_stuffing entries are legal")
	var leaving := _open(80)
	var left := leaving.leave(NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left.get("charged_gold") == 0 and left.get("gold") == 80
		and left.get("pockets") == _pockets()
		and left.get("heroes") == _party(),
		"Leave consumes the visit once without charging or changing pockets")
	_check(not left.has("effect_text") and not leaving.read_state().has("effect_text")
		and not leaving.quote().has("effect_text"),
		"after Leave no effect text leaks into the receipt, state or a later quote")
	_check(leaving.is_consumed() and leaving.read_state()["gold"] == 80
		and leaving.read_state()["pockets"] == _pockets()
		and leaving.leave(NODE, leaving.read_state()).get("ok", true) == false
		and leaving.buy_fresh_stuffing("rag_duelist", NODE,
			leaving.read_state()).get("ok", true) == false,
		"a left visit refuses both Leave and buy afterwards")
	left["pockets"]["warden"].clear()
	_check(leaving.read_state()["pockets"]["warden"] == ["starch"],
		"mutating the Leave receipt changes nothing in the service")


func _test_refusals() -> void:
	var poor := _open(SAMPLE_QUOTE - 1)
	var poor_state := poor.read_state()
	_reject(poor, "rag_duelist", NODE, poor_state, "one gold short")
	var forged := poor.quote().duplicate(true)
	forged["choices"] = ["buy_fresh_stuffing", "leave"]
	forged["can_buy"] = true
	forged["blocked"] = ""
	_reject(poor, "rag_duelist", NODE, forged, "falsified unaffordable quote")
	_reject(poor, "rag_duelist", NODE, _open(500).quote(), "replayed affordable quote")
	var poor_quote := poor.quote()
	_check(poor_quote.get("effect_text") == EFFECT and poor_quote.get("choices") == ["leave"]
		and poor_quote.get("can_buy") == false and poor_quote.get("eligible") == [],
		"after refusals the unaffordable quote still explains the use but offers only Leave")
	var with_text := poor_state.duplicate(true)
	with_text["effect_text"] = EFFECT
	_reject(poor, "rag_duelist", NODE, with_text, "state padded with effect_text")
	var poor_left := poor.leave(NODE, poor_state)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor_left.get("gold") == SAMPLE_QUOTE - 1 and poor.is_consumed(),
		"a refused buy preserves the later legal no-charge Leave")
	var visit := _open(300)
	var snap := visit.read_state()
	_reject(visit, "seamstress", NODE, snap, "full pocket (identical items)")
	_reject(visit, "tinker", NODE, snap, "full pocket (mixed items)")
	_reject(visit, "nobody", NODE, snap, "foreign doll")
	_reject(visit, "", NODE, snap, "empty doll ID")
	_reject(visit, null, NODE, snap, "null doll ID")
	_reject(visit, 7, NODE, snap, "non-string doll ID")
	_reject(visit, "rag_duelist", "other-node", snap, "wrong node buy")
	var wrong_leave := visit.leave("other-node", snap)
	_check(wrong_leave.get("ok", true) == false and visit.is_open(),
		"wrong node leave refuses without consuming")
	_reject(visit, "rag_duelist", "", snap, "empty node buy")
	_reject(visit, "rag_duelist", NODE, {}, "omitted state")
	_reject(visit, "rag_duelist", NODE, null, "null state")
	_reject(visit, "rag_duelist", NODE, "no", "non-dictionary state")
	for field in ["gold", "price", "status", "mode", "node_id", "consumed", "eligible"]:
		var stale := snap.duplicate(true)
		stale[field] = int(stale[field]) + 1 if field == "gold" or field == "price" \
			else "wrong"
		_reject(visit, "rag_duelist", NODE, stale, "stale state: " + field)
	var missing_key := snap.duplicate(true)
	missing_key.erase("pockets")
	_reject(visit, "rag_duelist", NODE, missing_key, "state missing pockets")
	var forged_pockets := snap.duplicate(true)
	forged_pockets["pockets"]["rag_duelist"] = ["dye"]
	_reject(visit, "rag_duelist", NODE, forged_pockets, "forged pocket state")
	var forged_dolls := snap.duplicate(true)
	forged_dolls["heroes"][0]["lost"] = true
	_reject(visit, "rag_duelist", NODE, forged_dolls, "forged roster state")
	_reject(visit, "rag_duelist", NODE, _open(301).read_state(),
		"another visit's differing state")
	_check(visit.leave(NODE, forged_pockets).get("ok", true) == false
		and visit.is_open(), "a forged state cannot Leave either")
	var paid := visit.buy_fresh_stuffing("rag_duelist", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 300 - SAMPLE_QUOTE
		and paid.get("pocket_after") == [ITEM],
		"after every refusal the fresh exact state still buys legally")


func _test_lost_and_full() -> void:
	var one_lost := _party()
	one_lost[0]["lost"] = true
	var visit := _open(300, SAMPLE_QUOTE, NODE, one_lost)
	_check(visit.read_state().get("eligible") == ["warden"],
		"a LOST doll with an empty pocket is not eligible")
	_assert_quote(visit, 300, ["buy_fresh_stuffing", "leave"], true, "", ["warden"],
		"one LOST doll, one eligible doll")
	var snap := visit.read_state()
	_reject(visit, "rag_duelist", NODE, snap, "LOST doll buy with ample gold")
	_check(visit.read_state()["pockets"]["rag_duelist"] == []
		and visit.read_state()["gold"] == 300,
		"the refused LOST-doll buy spent no gold and filled no pocket")
	var paid := visit.buy_fresh_stuffing("warden", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid["heroes"] == one_lost
		and paid["pockets_after"]["rag_duelist"] == [],
		"the living doll buys once and the LOST doll is untouched")
	var blocked_lost := _party()
	blocked_lost[0]["lost"] = true
	blocked_lost[1]["lost"] = true
	var blocked := _open(300, SAMPLE_QUOTE, NODE, blocked_lost)
	_assert_quote(blocked, 300, ["leave"], false, "no doll can carry fresh stuffing",
		[], "open positions belong only to LOST dolls")
	var blocked_snap := blocked.read_state()
	for target in ["rag_duelist", "warden", "seamstress", "tinker"]:
		_reject(blocked, target, NODE, blocked_snap, "no legal buyer: " + target)
	var blocked_forged := blocked.quote().duplicate(true)
	blocked_forged["choices"] = ["buy_fresh_stuffing", "leave"]
	blocked_forged["can_buy"] = true
	_reject(blocked, "rag_duelist", NODE, blocked_forged, "falsified blocked quote")
	var blocked_left := blocked.leave(NODE, blocked_snap)
	_check(blocked_left.get("ok") == true and blocked_left.get("charged_gold") == 0
		and blocked_left.get("gold") == 300 and blocked.is_consumed()
		and blocked_left.get("pockets") == _pockets(),
		"a visit with no legal buyer still permits the free Leave")


## Two separately opened, economically identical visits at the SAME node must
## never honour each other's snapshots (stale cross-visit intent).
func _test_cross_visit_identity() -> void:
	var first := _open(100)
	var first_snap := first.read_state()
	var second := _open(100)
	var second_snap := second.read_state()
	var first_id: Variant = first_snap.get("visit_id")
	var second_id: Variant = second_snap.get("visit_id")
	_check(typeof(first_id) == TYPE_STRING and typeof(second_id) == TYPE_STRING
		and not str(first_id).is_empty() and not str(second_id).is_empty()
		and first_id != second_id,
		"two openings with identical inputs get nonempty, distinct visit IDs")
	var stripped_first := first_snap.duplicate(true)
	var stripped_second := second_snap.duplicate(true)
	stripped_first.erase("visit_id")
	stripped_second.erase("visit_id")
	_check(stripped_first == stripped_second and first.quote() == second.quote()
		and first_snap["eligible"] == ["rag_duelist", "warden"]
		and second_snap["eligible"] == ["rag_duelist", "warden"]
		and second_snap["heroes"] == _party() and second_snap["pockets"] == _pockets()
		and second_snap["gold"] == 100 and second_snap["price"] == SAMPLE_QUOTE,
		"the visits differ only by visit_id; eligibility, quote and data are unchanged")
	_check(first.read_state() == first_snap and second.read_state() == second_snap,
		"the ID is stable across repeated reads of one visit")
	# Old snapshot on the new visit: Buy refused, no drift.
	_reject(second, "rag_duelist", NODE, first_snap, "stale cross-visit snapshot buy")
	_reject(second, "warden", NODE, first_snap, "stale cross-visit snapshot buy (warden)")
	var stale_leave := second.leave(NODE, first_snap)
	_check(stale_leave.get("ok", true) == false and stale_leave.get("charged_gold", 1) == 0
		and second.is_open() and not second.is_consumed()
		and second.read_state() == second_snap and second.quote().get("can_buy") == true,
		"a stale cross-visit snapshot cannot Leave; the new visit stays open and unchanged")
	_check(first.is_open() and first.read_state() == first_snap,
		"refusals on the new visit never touch the older visit")
	# The same-visit snapshot still authorizes a legal purchase.
	var paid := second.buy_fresh_stuffing("rag_duelist", NODE, second_snap)
	_check(paid.get("ok") == true and paid.get("doll_id") == "rag_duelist"
		and paid.get("charged_gold") == SAMPLE_QUOTE and paid.get("gold") == 100 - SAMPLE_QUOTE
		and paid.get("gold") == 87 and paid.get("pocket_before") == []
		and paid.get("pocket_after") == [ITEM]
		and paid["pockets_after"]["warden"] == ["starch"]
		and paid["heroes"] == _party(),
		"the new visit's own snapshot buys exactly one fresh_stuffing for 13 gold")
	_check(second.is_consumed() and second.read_state()["gold"] == 87
		and second.buy_fresh_stuffing("warden", NODE, second.read_state()).get("ok", true) == false
		and second.read_state()["gold"] == 87,
		"the new visit is consumed and a repeat buy is refused with no second charge")
	_check(first.is_open() and not first.is_consumed() and first.read_state() == first_snap
		and first.read_state()["gold"] == 100,
		"buying on the second visit does not consume or alter the first")
	# Old snapshots stay inert on a used visit and on a Leave-closed visit.
	var used_state := second.read_state()
	_check(second.leave(NODE, first_snap).get("ok", true) == false
		and second.read_state() == used_state,
		"the consumed visit refuses the old snapshot's Leave as well")
	# The first visit still works with its own snapshot, including Leave.
	var first_left := first.leave(NODE, first_snap)
	_check(first_left.get("ok") == true and first_left.get("charged_gold") == 0
		and first_left.get("gold") == 100 and first.is_consumed(),
		"the first visit still leaves legally with its own snapshot")
	# A third opening gets yet another ID.
	var third := _open(100)
	var third_id: Variant = third.read_state().get("visit_id")
	_check(not str(third_id).is_empty() and third_id != first_id and third_id != second_id,
		"reopening again issues a third distinct visit ID")
	_reject(third, "rag_duelist", NODE, first_snap, "first snapshot on third visit")
	_reject(third, "rag_duelist", NODE, second_snap, "second snapshot on third visit")
	var third_left := third.leave(NODE, second_snap)
	_check(third_left.get("ok", true) == false and third.is_open(),
		"an older snapshot cannot Leave the third visit")
	# Forged or blank IDs fail on a visit of the same economic state.
	var forged := third.read_state().duplicate(true)
	forged["visit_id"] = ""
	_reject(third, "rag_duelist", NODE, forged, "blank visit_id")
	forged["visit_id"] = 7
	_reject(third, "rag_duelist", NODE, forged, "non-string visit_id")
	var no_id := third.read_state().duplicate(true)
	no_id.erase("visit_id")
	_reject(third, "rag_duelist", NODE, no_id, "snapshot missing visit_id")
	# Invalid admissions expose an empty ID and never authorize anything.
	var invalid := _open(100, SAMPLE_QUOTE, "")
	_check(invalid.read_state().get("visit_id", "x") == ""
		and invalid.read_state().get("ok") == false,
		"an invalid visit exposes an empty visit_id")
	var legal := third.buy_fresh_stuffing("rag_duelist", NODE, third.read_state())
	_check(legal.get("ok") == true and legal.get("gold") == 87,
		"after every refusal the third visit's own snapshot still buys legally")
