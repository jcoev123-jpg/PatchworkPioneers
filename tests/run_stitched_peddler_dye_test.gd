extends SceneTree
## Design v4 Stitched Peddler dye visit contract: the opt-in quoted-gold
## one-use buy-dye (append one "dye" to one doll's Walk pocket) or free Leave
## decision, guarded by the exact node and a complete open snapshot, fully
## detached state and no RNG draws. Scene-free service test. The dye's Walk
## effect is out of scope and never exercised here.

const NODE := "route-peddler-9"
const MODE := "stitched"
const PRICE := 35

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(616161)
	var next_draw := randi()
	seed(616161)
	_test_admission_and_isolation()
	_test_quotes()
	_test_effect_text_forecast()
	_test_purchase_and_leave()
	_test_refusals()
	_test_lost_and_full()
	_check(randi() == next_draw,
		"dye open, quote, buys, Leaves and every refusal draw no global RNG")
	if failures.is_empty():
		print("run_stitched_peddler_dye_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_stitched_peddler_dye_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _party() -> Array:
	return [
		{"id": "rag_duelist", "rank": 1, "hp": 30, "fray": 12, "lost": false,
			"parts": {"blade": {"tier": 2, "meta": {"kills": 3}}}},
		{"id": "warden", "rank": 2, "hp": 40, "fray": 0, "lost": false,
			"parts": {"shield": {"tier": 1}}},
		{"id": "seamstress", "rank": 3, "hp": 25, "fray": 5, "lost": false,
			"parts": {"needle": {"tier": 3}}},
		{"id": "tinker", "rank": 4, "hp": 28, "fray": 8, "lost": false,
			"parts": {"turret": {"tier": 1}}},
	]


## rag_duelist empty, warden one item, seamstress two identical, tinker full mixed.
func _pockets() -> Dictionary:
	return {
		"rag_duelist": [],
		"warden": ["starch"],
		"seamstress": ["dye", "dye"],
		"tinker": ["pins", "spare_spool"],
	}


func _open(gold: Variant, price: Variant = PRICE, node: Variant = NODE,
		heroes: Variant = null, pockets: Variant = null) -> RunStitchedPeddlerDye:
	if heroes == null:
		heroes = _party()
	if pockets == null:
		pockets = _pockets()
	return RunStitchedPeddlerDye.open_stitched(node, heroes, pockets, gold, price)


func _reject(visit: RunStitchedPeddlerDye, hero: Variant, node: Variant,
		snapshot: Variant, label: String) -> void:
	var before := visit.read_state()
	_check(before.get("ok") == true and visit.is_open(),
		label + ": precondition, the visit is a genuine open one")
	var result := visit.buy_dye(hero, node, snapshot)
	_check(result.get("ok", true) == false, label + ": refused")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": no drift in dolls, pockets, wallet or status; visit still open")
	_check(result.get("decision", "x") == "" and result.get("charged_gold", 1) == 0,
		label + ": no phantom decision or charge")


## AC1: valid and invalid admissions plus input/output isolation.
func _test_admission_and_isolation() -> void:
	var party := _party()
	var pockets := _pockets()
	var visit := RunStitchedPeddlerDye.open_stitched(NODE, party, pockets, 100, PRICE)
	_check(visit.is_valid() and visit.is_open() and not visit.is_consumed(),
		"valid node, party, pockets, wallet and quote open the visit")
	party[0]["hp"] = 1
	pockets["rag_duelist"].append("dye")
	pockets["warden"].clear()
	var state := visit.read_state()
	_check(state.get("ok") == true and state.get("mode") == MODE
		and state.get("node_id") == NODE and state.get("gold") == 100
		and state.get("price") == PRICE and state.get("status") == "open"
		and state.get("consumed") == false,
		"read_state carries node, mode, wallet, quote, status and open flag")
	_check(state["heroes"][0]["hp"] == 30 and state["pockets"]["rag_duelist"] == []
		and state["pockets"]["warden"] == ["starch"],
		"mutating the caller's input after opening cannot forge the state")
	_check(state.get("eligible") == ["rag_duelist", "warden"],
		"eligible IDs are non-lost dolls with a free slot, in party order")
	var quote := visit.quote()
	state["gold"] = 99999
	state["pockets"]["tinker"].clear()
	state["heroes"][1]["hp"] = 1
	quote["price"] = 1
	quote["eligible"].clear()
	var fresh := visit.read_state()
	_check(fresh["gold"] == 100 and fresh["pockets"]["tinker"].size() == 2
		and fresh["heroes"][1]["hp"] == 40 and visit.quote()["price"] == PRICE
		and visit.quote()["eligible"] == ["rag_duelist", "warden"],
		"mutating returned state or quote changes nothing in the service")
	var bad_nodes: Array = ["", " ", " " + NODE, NODE + " ", null, 17]
	for node in bad_nodes:
		var bad := _open(100, PRICE, node)
		_check(not bad.is_valid() and not bad.is_open() and not bad.is_consumed()
			and bad.read_state().get("ok") == false
			and bad.quote().get("ok", true) == false
			and bad.quote().get("choices", ["x"]).is_empty()
			and bad.buy_dye("rag_duelist", NODE, {}).get("ok", true) == false
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
	var non_dict := _party()
	non_dict[0] = "rag_duelist"
	bad_parties.append(non_dict)
	for bad_party in bad_parties:
		var bad := RunStitchedPeddlerDye.open_stitched(NODE, bad_party, _pockets(),
			100, PRICE)
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
		var bad := RunStitchedPeddlerDye.open_stitched(NODE, _party(), bad_ledger,
			100, PRICE)
		_check(not bad.is_valid() and bad.read_state().get("ok") == false
			and bad.quote().get("choices", ["x"]).is_empty(),
			"malformed pocket ledger fails admission: " + str(bad_ledger).substr(0, 50))
	for gold in [-1, 1.5, "100", null]:
		_check(not _open(gold).is_valid(), "invalid wallet fails admission: " + str(gold))
	for price in [0, -5, 35.5, "35", null]:
		_check(not _open(100, price).is_valid(),
			"invalid quote fails admission: " + str(price))
	_check(_open(0, 1).is_valid() and _open(0, PRICE).is_valid(),
		"a zero wallet with a positive quote is a legal opening")
	_check(_open(100, 1).quote().get("price") == 1
		and _open(100, 977).quote().get("price") == 977,
		"any positive integer quote is carried as given, no fixed price")
	var all_items := {"rag_duelist": ["thimble_tonic", "fresh_stuffing"],
		"warden": ["starch", "dye"], "seamstress": ["pins", "spare_spool"],
		"tinker": []}
	_check(_open(100, PRICE, NODE, null, all_items).is_valid(),
		"every allowed item ID is a legal pocket entry")


func _assert_quote(visit: RunStitchedPeddlerDye, gold: int, choices: Array,
		can_buy: bool, blocked: String, eligible: Array, label: String) -> void:
	var before := visit.read_state()
	var quote := visit.quote()
	_check(quote.get("ok") == true and quote.get("choices") == choices
		and quote.get("can_buy") == can_buy and quote.get("blocked") == blocked
		and quote.get("price") == PRICE and quote.get("gold") == gold
		and quote.get("eligible") == eligible and quote.get("item") == "dye"
		and quote.get("node_id") == NODE and quote.get("mode") == MODE,
		label + ": choices, can_buy, blocked, price and eligible IDs are honest")
	_check(quote.get("choices").has("leave"), label + ": free Leave is always offered")
	var text = quote.get("effect_text")
	_check(typeof(text) == TYPE_STRING and not String(text).is_empty(),
		label + ": quote carries a nonempty effect_text")
	var lowered := String(text).to_lower()
	_check(lowered.contains("walk") and lowered.contains("next fight")
		and lowered.contains("first strike") and lowered.contains("1 curio trap"),
		label + ": effect_text ties Walk use, next fight, first strike and one curio trap")
	_check(quote.keys().size() == 11 and not quote.has("effect"),
		label + ": only the one effect_text key was added to the quote")
	_check(visit.read_state() == before and visit.is_open(),
		label + ": quoting changes nothing")


## AC1: Buy is quoted only when payable and a doll has room; Leave always.
func _test_quotes() -> void:
	var both := ["rag_duelist", "warden"]
	_assert_quote(_open(PRICE), PRICE, ["buy_dye", "leave"], true, "", both,
		"price-equal wallet")
	_assert_quote(_open(500), 500, ["buy_dye", "leave"], true, "", both,
		"ample gold")
	_assert_quote(_open(PRICE - 1), PRICE - 1, ["leave"], false, "not enough gold",
		both, "one gold short")
	_assert_quote(_open(0), 0, ["leave"], false, "not enough gold", both,
		"empty wallet")
	var full := {"rag_duelist": ["dye", "dye"], "warden": ["starch", "pins"],
		"seamstress": ["dye", "dye"], "tinker": ["pins", "spare_spool"]}
	_assert_quote(_open(500, PRICE, NODE, null, full), 500, ["leave"], false,
		"no doll can carry dye", [], "every pocket full")
	_assert_quote(_open(0, PRICE, NODE, null, full), 0, ["leave"], false,
		"no doll can carry dye", [], "full pockets and broke")
	var one_slot := _pockets()
	one_slot["rag_duelist"] = ["pins", "pins"]
	one_slot["warden"] = ["pins", "dye"]
	one_slot["seamstress"] = ["thimble_tonic"]
	_assert_quote(_open(500, PRICE, NODE, null, one_slot), 500, ["buy_dye", "leave"],
		true, "", ["seamstress"], "mixed pockets with one open slot")
	var closed := _open(500)
	closed.leave(NODE, closed.read_state())
	var closed_quote := closed.quote()
	_check(closed_quote.get("ok", true) == false
		and closed_quote.get("choices", ["x"]).is_empty()
		and not closed_quote.has("can_buy"),
		"a closed visit quotes no choices and no purchase")


## AC1-AC3: the effect_text mirrors the real Walk dye flags, is identical on
## affordable, poor and full quotes, is detached, and a buy applies no effect.
func _test_effect_text_forecast() -> void:
	var flags := StitchedWalkRules._future_effects("dye")
	_check(flags == {"skip_next_fight_first_strike": true, "skip_one_curio_trap": true},
		"the real Walk dye effects are exactly the two established true flags")
	var full := {"rag_duelist": ["dye", "dye"], "warden": ["starch", "pins"],
		"seamstress": ["dye", "dye"], "tinker": ["pins", "spare_spool"]}
	var rich := _open(500)
	var poor := _open(0)
	var packed := _open(500, PRICE, NODE, null, full)
	var rich_quote := rich.quote()
	var expected_text: String = rich_quote.get("effect_text", "")
	_check(not expected_text.is_empty(), "precondition: the affordable quote has effect_text")
	for visit in [poor, packed]:
		var other: Dictionary = visit.quote()
		_check(other.get("effect_text") == expected_text and other.get("price") == PRICE
			and other.get("can_buy") == false and other.get("choices") == ["leave"]
			and other.get("blocked") != "",
			"poor and full-pocket quotes keep the same text, price and Leave-only choices")
	_check(rich_quote.get("can_buy") == true and rich_quote.get("choices") == ["buy_dye", "leave"]
		and rich_quote.get("blocked") == "",
		"the affordable quote still offers Buy and Leave with no blocked reason")
	# No invented guaranteed benefit: the text is conditional on later use.
	_check(expected_text.begins_with("Use during the Walk"),
		"the text states the benefit applies only when the dye is used in the Walk")
	# Detachment: mutating a returned quote changes nothing afterwards.
	var state_before := rich.read_state()
	rich_quote["effect_text"] = "free dye now"
	rich_quote["price"] = 1
	rich_quote["choices"].clear()
	_check(rich.quote().get("effect_text") == expected_text and rich.quote().get("price") == PRICE
		and rich.quote().get("choices") == ["buy_dye", "leave"]
		and rich.read_state() == state_before and rich.is_open(),
		"mutating a returned quote changes neither the next quote nor read_state")
	# A buy only appends the item string; no Walk effect is applied or reported.
	var paid := rich.buy_dye("warden", NODE, rich.read_state())
	_check(paid.get("ok") == true and paid.get("charged_gold") == PRICE
		and paid.get("pocket_after") == ["starch", "dye"]
		and not paid.has("effect_text") and not paid.has("effects")
		and not paid.has("skip_next_fight_first_strike")
		and not paid.has("skip_one_curio_trap"),
		"a buy charges once, appends one dye string and applies no future effect")
	_check(rich.quote().get("ok", true) == false and rich.quote().get("choices", ["x"]).is_empty()
		and not rich.quote().has("effect_text"),
		"a consumed visit quotes nothing, including no effect_text")
	var left := _open(500)
	left.leave(NODE, left.read_state())
	_check(not left.quote().has("effect_text") and not _open(300, 0).quote().has("effect_text"),
		"closed and invalid visits carry no effect_text")


## AC2: an exact-snapshot buy appends one dye to one pocket only, charges the
## quote once, returns a detached before/after receipt and consumes the visit.
func _test_purchase_and_leave() -> void:
	var visit := _open(PRICE)
	var before := visit.read_state()
	_check(before.get("ok") == true and before["pockets"]["warden"] == ["starch"],
		"precondition: the buyer starts with exactly one pocket item")
	var paid := visit.buy_dye("warden", NODE, before)
	_check(paid.get("ok") == true and paid.get("decision") == "buy_dye"
		and paid.get("node_id") == NODE and paid.get("hero_id") == "warden"
		and paid.get("item") == "dye" and paid.get("price") == PRICE
		and paid.get("charged_gold") == PRICE and paid.get("gold") == 0
		and paid.get("status") == "used" and paid.get("consumed") == true,
		"a price-equal buy charges exactly the quote and empties the wallet")
	_check(paid.get("pocket_before") == ["starch"]
		and paid.get("pocket_after") == ["starch", "dye"]
		and paid.get("pockets_before") == before["pockets"],
		"the receipt carries the buyer's before and after pockets")
	var after: Dictionary = paid["pockets_after"]
	_check(after["warden"] == ["starch", "dye"] and after["rag_duelist"] == []
		and after["seamstress"] == ["dye", "dye"]
		and after["tinker"] == ["pins", "spare_spool"],
		"only the selected doll's pocket gained one dye; the rest are unchanged")
	_check(paid["heroes"] == before["heroes"] and paid["heroes"] == _party(),
		"HP, fray, rank, lost flags and parts are untouched")
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
	paid["heroes"][0]["hp"] = 1
	var again_state := visit.read_state()
	_check(again_state["pockets"]["warden"] == ["starch", "dye"]
		and again_state["pockets"]["tinker"].size() == 2
		and again_state["heroes"][0]["hp"] == 30,
		"mutating the receipt changes nothing in the service")
	var replay := visit.buy_dye("rag_duelist", NODE, visit.read_state())
	_check(replay.get("ok", true) == false and visit.read_state() == again_state
		and visit.leave(NODE, visit.read_state()).get("ok", true) == false
		and visit.read_state() == again_state,
		"a second buy or a later Leave is refused with no second charge")
	var replay_same := visit.buy_dye("warden", NODE, before)
	_check(replay_same.get("ok", true) == false and visit.read_state() == again_state,
		"replaying the original open snapshot after the purchase is refused")
	# Empty pocket, wallet above the price.
	var rich := _open(100)
	var rich_paid := rich.buy_dye("rag_duelist", NODE, rich.read_state())
	_check(rich_paid.get("ok") == true and rich_paid.get("gold") == 100 - PRICE
		and rich_paid.get("charged_gold") == PRICE
		and rich_paid.get("pocket_before") == []
		and rich_paid.get("pocket_after") == ["dye"],
		"an empty pocket gains a single dye and the wallet drops by the quote")
	# A non-default quote is charged exactly.
	var odd := _open(500, 123)
	var odd_paid := odd.buy_dye("warden", NODE, odd.read_state())
	_check(odd_paid.get("ok") == true and odd_paid.get("charged_gold") == 123
		and odd_paid.get("gold") == 377 and odd.read_state()["gold"] == 377,
		"the caller-supplied quote, not a fixed price, is charged exactly once")
	# Dye for a doll already holding dye is a legal second copy.
	var twin_pockets := _pockets()
	twin_pockets["tinker"] = ["dye"]
	var twin := _open(100, PRICE, NODE, null, twin_pockets)
	var twin_paid := twin.buy_dye("tinker", NODE, twin.read_state())
	_check(twin_paid.get("ok") == true
		and twin_paid.get("pocket_after") == ["dye", "dye"],
		"two identical dye entries are legal")
	# Free Leave.
	var leaving := _open(80)
	var left := leaving.leave(NODE, leaving.read_state())
	_check(left.get("ok") == true and left.get("decision") == "leave"
		and left.get("charged_gold") == 0 and left.get("gold") == 80
		and left.get("pockets") == _pockets()
		and left.get("heroes") == _party(),
		"Leave consumes the visit once without charging or changing pockets")
	_check(leaving.is_consumed() and leaving.read_state()["gold"] == 80
		and leaving.read_state()["pockets"] == _pockets()
		and leaving.leave(NODE, leaving.read_state()).get("ok", true) == false
		and leaving.buy_dye("rag_duelist", NODE,
			leaving.read_state()).get("ok", true) == false,
		"a left visit refuses both Leave and buy afterwards")
	left["pockets"]["warden"].clear()
	_check(leaving.read_state()["pockets"]["warden"] == ["starch"],
		"mutating the Leave receipt changes nothing in the service")


## AC3: wrong or full hero, low gold, wrong node, stale or forged snapshot all
## refuse with no mutation and keep the free Leave available.
func _test_refusals() -> void:
	var poor := _open(PRICE - 1)
	var poor_snap := poor.read_state()
	_reject(poor, "rag_duelist", NODE, poor_snap, "one gold short")
	var forged := poor.quote().duplicate(true)
	forged["choices"] = ["buy_dye", "leave"]
	forged["can_buy"] = true
	forged["blocked"] = ""
	_reject(poor, "rag_duelist", NODE, forged, "falsified unaffordable quote")
	_reject(poor, "rag_duelist", NODE, _open(500).quote(), "replayed affordable quote")
	var poor_left := poor.leave(NODE, poor_snap)
	_check(poor_left.get("ok") == true and poor_left.get("charged_gold") == 0
		and poor_left.get("gold") == PRICE - 1 and poor.is_consumed(),
		"a refused buy preserves the later legal no-charge Leave")
	var visit := _open(300)
	var snap := visit.read_state()
	_reject(visit, "seamstress", NODE, snap, "full pocket (identical items)")
	_reject(visit, "tinker", NODE, snap, "full pocket (mixed items)")
	_reject(visit, "nobody", NODE, snap, "unknown hero")
	_reject(visit, "", NODE, snap, "empty hero")
	_reject(visit, null, NODE, snap, "null hero")
	_reject(visit, 7, NODE, snap, "non-string hero")
	_reject(visit, "rag_duelist", "other-node", snap, "wrong node buy")
	var wrong_leave := visit.leave("other-node", snap)
	_check(wrong_leave.get("ok", true) == false and visit.is_open(),
		"wrong node leave refuses without consuming")
	_reject(visit, "rag_duelist", "", snap, "empty node buy")
	_reject(visit, "rag_duelist", null, snap, "null node buy")
	_reject(visit, "rag_duelist", NODE, {}, "omitted snapshot")
	_reject(visit, "rag_duelist", NODE, null, "null snapshot")
	_reject(visit, "rag_duelist", NODE, "no", "non-dictionary snapshot")
	for field in ["gold", "price", "status", "mode", "node_id", "consumed", "eligible"]:
		var stale := snap.duplicate(true)
		stale[field] = int(stale[field]) + 1 if field == "gold" or field == "price" \
			else "wrong"
		_reject(visit, "rag_duelist", NODE, stale, "stale snapshot: " + field)
	var missing_key := snap.duplicate(true)
	missing_key.erase("pockets")
	_reject(visit, "rag_duelist", NODE, missing_key, "snapshot missing pockets")
	var forged_pockets := snap.duplicate(true)
	forged_pockets["pockets"]["rag_duelist"] = ["dye"]
	_reject(visit, "rag_duelist", NODE, forged_pockets, "forged pocket snapshot")
	var forged_heroes := snap.duplicate(true)
	forged_heroes["heroes"][0]["lost"] = true
	_reject(visit, "rag_duelist", NODE, forged_heroes, "forged roster snapshot")
	_reject(visit, "rag_duelist", NODE, _open(301).read_state(),
		"another visit's differing snapshot")
	_check(visit.leave(NODE, forged_pockets).get("ok", true) == false
		and visit.is_open(), "a forged snapshot cannot Leave either")
	var paid := visit.buy_dye("rag_duelist", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid.get("gold") == 300 - PRICE
		and paid.get("pocket_after") == ["dye"],
		"after every refusal the fresh exact choice still buys legally")
	# A refused buy on an invalid visit never opens it.
	var invalid := _open(300, 0)
	var invalid_result := invalid.buy_dye("rag_duelist", NODE, invalid.read_state())
	_check(not invalid.is_valid() and invalid_result.get("ok", true) == false,
		"an invalid visit refuses even its own state as a snapshot")


## AC1/AC3: a lost doll is never a buyer; full pockets and lost dolls alone
## leave only the free Leave.
func _test_lost_and_full() -> void:
	var one_lost := _party()
	one_lost[0]["lost"] = true
	var visit := _open(300, PRICE, NODE, one_lost)
	_check(visit.read_state().get("eligible") == ["warden"],
		"a lost doll with an empty pocket is not eligible")
	_assert_quote(visit, 300, ["buy_dye", "leave"], true, "", ["warden"],
		"one lost doll, one eligible doll")
	var snap := visit.read_state()
	_reject(visit, "rag_duelist", NODE, snap, "lost doll buy with ample gold")
	_check(visit.read_state()["pockets"]["rag_duelist"] == []
		and visit.read_state()["gold"] == 300,
		"the refused lost-doll buy spent no gold and filled no pocket")
	var paid := visit.buy_dye("warden", NODE, visit.read_state())
	_check(paid.get("ok") == true and paid["heroes"] == one_lost
		and paid["pockets_after"]["rag_duelist"] == [],
		"the living doll buys once and the lost doll is untouched")
	# Full-or-LOST roster beside one eligible doll: only the eligible ID is quoted.
	var mixed := _party()
	mixed[0]["lost"] = true
	var mixed_pockets := _pockets()
	mixed_pockets["warden"] = ["starch", "pins"]
	mixed_pockets["tinker"] = ["pins"]
	var mixed_visit := _open(PRICE, PRICE, NODE, mixed, mixed_pockets)
	_assert_quote(mixed_visit, PRICE, ["buy_dye", "leave"], true, "", ["tinker"],
		"lost, full and eligible dolls together")
	var mixed_snap := mixed_visit.read_state()
	for target in ["rag_duelist", "warden", "seamstress"]:
		_reject(mixed_visit, target, NODE, mixed_snap, "ineligible buyer: " + target)
	var mixed_paid := mixed_visit.buy_dye("tinker", NODE, mixed_visit.read_state())
	_check(mixed_paid.get("ok") == true and mixed_paid.get("gold") == 0
		and mixed_paid["pockets_after"]["tinker"] == ["pins", "dye"]
		and mixed_paid["pockets_after"]["warden"] == ["starch", "pins"]
		and mixed_paid["pockets_after"]["rag_duelist"] == []
		and mixed_paid["heroes"] == mixed,
		"the one eligible doll buys and every other pocket and doll is unchanged")
	# Every doll with a slot is lost; every other pocket is full.
	var blocked_lost := _party()
	blocked_lost[0]["lost"] = true
	blocked_lost[1]["lost"] = true
	var blocked := _open(300, PRICE, NODE, blocked_lost)
	_assert_quote(blocked, 300, ["leave"], false, "no doll can carry dye", [],
		"open slots belong only to lost dolls")
	var blocked_snap := blocked.read_state()
	for target in ["rag_duelist", "warden", "seamstress", "tinker"]:
		_reject(blocked, target, NODE, blocked_snap, "no legal buyer: " + target)
	var blocked_forged := blocked.quote().duplicate(true)
	blocked_forged["choices"] = ["buy_dye", "leave"]
	blocked_forged["can_buy"] = true
	_reject(blocked, "rag_duelist", NODE, blocked_forged, "falsified blocked quote")
	var blocked_left := blocked.leave(NODE, blocked_snap)
	_check(blocked_left.get("ok") == true and blocked_left.get("charged_gold") == 0
		and blocked_left.get("gold") == 300 and blocked.is_consumed()
		and blocked_left.get("pockets") == _pockets(),
		"a visit with no legal buyer still permits the free Leave")
