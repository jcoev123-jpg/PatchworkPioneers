extends SceneTree
## Scene-free coverage of the separate, deliberately unrouted candlelit catalog.

const PATH := "res://data/events/v3_candlelit_bargains.json"
const EXPECTED := {
	"lantern_bobbin_ferry": {"title": "The Lantern Bobbin Ferry", "choices": {
		"buy_passage": [-12, 2], "ferry_parcels": [18, -1], "walk_bank": [0, 0]}},
	"thimble_star_reading": {"title": "The Thimble Star Reading", "choices": {
		"offer_thread": [16, -1], "gather_starlint": [0, 1], "pass_by": [0, 0]}},
	"moonpatch_archway": {"title": "The Moonpatch Archway", "choices": {
		"purchase_two_spools": [-15, 2], "sell_two_spools": [27, -2], "keep_walking": [0, 0]}},
	"blacklace_swap_table": {"title": "The Blacklace Swap Table", "choices": {
		"take_small_bundle": [-8, 1], "trade_own_bundle": [14, -1], "decline_trade": [0, 0]}},
	"crooked_marionette": {"title": "The Crooked Marionette", "choices": {
		"retie_strings": [30, -2], "gather_cuttings": [0, 1], "leave_puppet": [0, 0]}},
	"dusk_post_bobbin": {"title": "The Dusk Post Bobbin", "choices": {
		"send_letter": [-10, 1], "deliver_letters": [17, -1], "ignore_post": [0, 0]}},
}

## This batch: six appended candlelit cross-currency bargains. Choice rows are
## [id, text, gold, scraps] and are authored independently of the catalog, so a
## drifted or reworded record fails here even when its wallet deltas match.
const NEW_RECORDS := {
	"v3_bellglass_night_market": {
		"title": "The Bellglass Night Market",
		"description": "Round button-eyed merchants count glass bells beneath plum awnings, every bobbin lit by a single amber lantern.",
		"choices": [
			["buy_velvet_thread", "Pay 26 gold for three bundles of midnight thread (+3 scraps)", -26, 3],
			["trade_three_loops", "Trade three scrap bundles for 39 gold", 39, -3],
			["leave", "Leave the bellglass traders to their counting", 0, 0],
		],
	},
	"v3_crowlace_ticket_booth": {
		"title": "The Crowlace Ticket Booth",
		"description": "A stuffed crow in a gold-button waistcoat stamps crooked ferry tickets beside a black-lace window.",
		"choices": [
			["buy_night_pass", "Pay 18 gold for a pair of thread tickets (+2 scraps)", -18, 2],
			["sell_spare_ticket", "Exchange one spare scrap bundle for 15 gold", 15, -1],
			["leave", "Let the paper tickets flutter away", 0, 0],
		],
	},
	"v3_moonlit_pin_exchange": {
		"title": "The Moonlit Pin Exchange",
		"description": "A slate-blue puppet clerk opens a pin-lined drawer beneath a stitched button moon.",
		"choices": [
			["order_pin_roll", "Pay 34 gold for five rolled pin bundles (+5 scraps)", -34, 5],
			["redeem_spare_pins", "Turn two scrap bundles into 33 gold", 33, -2],
			["leave", "Close the pin drawer without trading", 0, 0],
		],
	},
	"v3_oxblood_patch_hall": {
		"title": "The Oxblood Patch Hall",
		"description": "Tiny velvet ragdolls hold a candlelit auction around an oxblood quilt sewn with brass-button seals.",
		"choices": [
			["buy_quilt_seam", "Spend 23 gold on three fine repair seams (+3 scraps)", -23, 3],
			["auction_old_patch", "Auction four scrap bundles for 51 gold", 51, -4],
			["leave", "Bow out before the next auction bell", 0, 0],
		],
	},
	"v3_bonecream_button_press": {
		"title": "The Bone-Cream Button Press",
		"description": "A squat stitched machinist works a giant button press under cream damask curtains.",
		"choices": [
			["buy_brass_mould", "Buy a mould offcut for 12 gold (+1 scrap)", -12, 1],
			["pawn_needle_wheel", "Pawn two scrap bundles for 22 gold", 22, -2],
			["leave", "Let the press fall silent", 0, 0],
		],
	},
	"v3_saffron_spool_trial": {
		"title": "The Saffron Spool Trial",
		"description": "A plump saffron-robed spool-keeper displays prize threads in a midnight-teal candlelit alcove.",
		"choices": [
			["buy_trial_thread", "Pay 40 gold for five prize-thread bundles (+5 scraps)", -40, 5],
			["sell_spool_braid", "Sell two scrap bundles for 31 gold", 31, -2],
			["leave", "Decline the spool-keeper's trial", 0, 0],
		],
	},
}

const FUNDED_WALLET := {"gold": 100, "scraps": 10}
const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
## Which short-resource refusal each Event actually exercised: {event_id: {kind: true}}.
var refused := {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _nonblank(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	_check(file != null, "catalog opens")
	if file != null:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		_check(error == OK, "catalog parses")
		if error == OK:
			var document: Variant = json.data
			_check(document is Dictionary and document.get("events") is Array, "events array exists")
			if document is Dictionary and document.get("events") is Array:
				_test_records(document.events)
	for failure in failures:
		printerr(failure)
	print("v3_candlelit_bargains_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _test_records(records: Array) -> void:
	var snapshot := records.duplicate(true)
	for id in EXPECTED:
		var matches: Array = records.filter(func(record): return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1, "required ID occurs exactly once: " + id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == EXPECTED[id].title and _nonblank(record.get("description")), "readable authored presentation: " + id)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(), "valid fresh selector: " + id)
		var choices: Variant = record.get("choices")
		_check(choices is Array, "choices array: " + id)
		if not choices is Array:
			continue
		_check(choices.size() >= 2 and choices.size() <= 3, "two or three choices: " + id)
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary, "choice record: " + id)
			if not choice is Dictionary:
				continue
			var choice_id: Variant = choice.get("id")
			_check(_nonblank(choice_id) and not seen.has(choice_id), "distinct nonblank choice ID: " + id)
			seen[choice_id] = true
			_check(_nonblank(choice.get("text")), "readable choice text: " + id)
			_check(EXPECTED[id].choices.has(choice_id), "known choice: " + id)
			if not EXPECTED[id].choices.has(choice_id):
				continue
			var delta: Array = EXPECTED[id].choices[choice_id]
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "wallet outcome: " + id)
			if outcome is Dictionary:
				_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"), "precisely wallet keys: " + id)
				for index in range(2):
					var value: Variant = outcome.get(["gold", "scraps"][index])
					# Godot JSON parses JSON integer tokens as floats; require exact integral values.
					_check((typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == delta[index], "exact integral delta: " + id + "/" + str(choice_id))
			_test_choice(record, choice_id, delta)
		for choice_id in EXPECTED[id].choices:
			_check(seen.has(choice_id), "required choice exists: " + id + "/" + choice_id)
	_test_new_records(records)
	_check(records == snapshot, "all authored inputs remain unchanged")


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


## Independent authored choice table for either catalog generation.
func _expected_choices(event_id: String) -> Dictionary:
	if EXPECTED.has(event_id):
		return EXPECTED[event_id].choices
	var table := {}
	if NEW_RECORDS.has(event_id):
		for row in NEW_RECORDS[event_id].choices:
			table[row[0]] = [row[2], row[3]]
	return table


func _free_exit_id(event_id: String) -> String:
	var table := _expected_choices(event_id)
	for candidate in table:
		if table[candidate] == [0, 0]:
			return candidate
	return ""


func _mark_refusal(event_id: String, kind: String) -> void:
	var kinds: Dictionary = refused.get(event_id, {})
	kinds[kind] = true
	refused[event_id] = kinds


## The six appended bargains: exact authored prose, exactly two signed wallet
## keys per outcome, then funded settlement, short-resource refusal and a fully
## empty wallet for every paid branch before the free Leave closes the visit.
func _test_new_records(records: Array) -> void:
	for id in NEW_RECORDS:
		var expected: Dictionary = NEW_RECORDS[id]
		var matches: Array = records.filter(func(record): return record is Dictionary and record.get("id") == id)
		_check(matches.size() == 1, "new ID occurs exactly once: " + id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record keeps only id/title/description/choices: " + id)
		_check(record.get("title") == expected.title, "new title exact: " + id)
		_check(record.get("description") == expected.description, "new description exact: " + id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "new record authors exactly three choices: " + id)
		if not choices is Array:
			continue
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary, "new choice record: " + id)
			if not choice is Dictionary:
				continue
			_check(choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"),
				"new choice keeps only id/text/outcome: " + id)
			var choice_id: Variant = choice.get("id")
			_check(_nonblank(choice_id) and not by_id.has(choice_id), "distinct nonblank new choice ID: " + id)
			if not choice_id is String:
				continue
			by_id[choice_id] = choice
		var wanted: Array = expected.choices
		_check(by_id.size() == wanted.size(), "new choice count matches the authored table: " + id)
		for row in wanted:
			var choice_id: String = row[0]
			var tag: String = id + "/" + choice_id
			_check(by_id.has(choice_id), "required new choice exists: " + tag)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(choice_dict.get("text") == row[1], "new choice text exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 2
				and outcome.has("gold") and outcome.has("scraps"),
				"new outcome carries precisely gold/scraps: " + tag)
			if outcome is Dictionary:
				for index in range(2):
					var value: Variant = outcome.get(["gold", "scraps"][index])
					# Godot JSON parses JSON integer tokens as floats; require exact integral values.
					_check((typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == row[2 + index],
						"new outcome exact signed delta: " + tag)
			var fresh := RunEventChoice.new(record)
			_check(fresh.is_valid() and not fresh.is_claimed(), "new record builds a valid fresh selector: " + tag)
			_test_choice(record, choice_id, [row[2], row[3]])
		_check(by_id.has("leave"), "new record offers a Leave choice: " + id)
		var kinds: Dictionary = refused.get(id, {})
		_check(kinds.get("gold", false) and kinds.get("scraps", false),
			"new Event refused both a gold-short and a scraps-short paid choice: " + id)
		_test_empty_wallet(record)


## A completely broke wallet: every paid branch refuses unchanged, and the same
## visit still settles its free Leave exactly once with every replay rejected.
func _test_empty_wallet(record: Dictionary) -> void:
	var selector := RunEventChoice.new(record)
	var empty := {"gold": 0, "scraps": 0}
	var before := empty.duplicate(true)
	var record_before := record.duplicate(true)
	for row in NEW_RECORDS[record.id].choices:
		var choice_id: String = row[0]
		if row[2] == 0 and row[3] == 0:
			continue
		var refusal := selector.choose_with_wallet(choice_id, empty)
		_check(refusal == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
			"empty wallet refuses paid choice: " + record.id + "/" + choice_id)
		_check(empty == before and record == record_before
			and selector.is_valid() and not selector.is_claimed(),
			"empty-wallet refusal preserves inputs and visit: " + record.id + "/" + choice_id)
		refusal.wallet.scraps += 999
		_check(empty == before, "empty-wallet refusal detached: " + record.id + "/" + choice_id)
	var leave := selector.choose_with_wallet("leave", empty)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": before}
		and selector.is_claimed() and not selector.is_valid(),
		"free Leave settles the empty-wallet visit once: " + record.id)
	var replay := selector.choose_with_wallet("leave", empty)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": before}
		and empty == before and record == record_before,
		"settled empty-wallet visit rejects Leave replay: " + record.id)
	_check(selector.preview_wallet_choices(empty) == DENIED_PREVIEW,
		"consumed visit refuses a second preview: " + record.id)


func _test_choice(record: Dictionary, choice_id: String, delta: Array) -> void:
	var tag: String = record.id + "/" + choice_id
	var expected_wallet := {"gold": 100 + delta[0], "scraps": 10 + delta[1]}
	var preview_service := RunEventChoice.new(record)
	var preview := preview_service.preview_wallet_choices(FUNDED_WALLET)
	_check(preview.get("ok") == true and preview.get("event_id") == record.id, "funded preview available: " + tag)
	var forecast := _preview_choice(preview, choice_id)
	_check(forecast.get("choice_id") == choice_id and forecast.get("gold_delta") == delta[0]
		and forecast.get("scraps_delta") == delta[1] and forecast.get("affordable") == true
		and forecast.get("wallet") == expected_wallet,
		"funded preview forecasts the exact receipt: " + tag)
	_check(preview_service.is_valid() and not preview_service.is_claimed(), "preview consumes no visit: " + tag)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 100, "scraps": 10}
	var original := record.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 259
	var rng_state := rng.state
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": expected_wallet}, "exact receipt: " + tag)
	_check(selector.is_claimed() and not selector.is_valid(), "success consumes visit: " + tag)
	_check(wallet == FUNDED_WALLET and record == original, "success preserves inputs: " + tag)
	_check(rng.state == rng_state, "success consumes no seeded RNG state: " + tag)
	var replay := selector.choose_with_wallet(choice_id, receipt.wallet)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": expected_wallet}, "replay rejects without another payment: " + tag)
	replay.wallet.gold += 999
	_check(receipt.wallet == expected_wallet, "replay wallet detached from committed result: " + tag)
	receipt.wallet.scraps += 999
	_check(wallet == FUNDED_WALLET and selector.get_event() == original, "success result detached from wallet and event: " + tag)
	if delta[0] < 0 or delta[1] < 0:
		_test_unfunded(record, choice_id, delta)


func _test_unfunded(record: Dictionary, choice_id: String, delta: Array) -> void:
	var tag: String = record.id + "/" + choice_id
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 0 if delta[0] < 0 else 100, "scraps": 0 if delta[1] < 0 else 10}
	var before := wallet.duplicate(true)
	var record_before := record.duplicate(true)
	var forecast := _preview_choice(selector.preview_wallet_choices(wallet), choice_id)
	_check(not forecast.is_empty() and forecast.get("affordable") == false
		and forecast.get("wallet") == before,
		"short wallet previews the debit unavailable: " + tag)
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before}, "unfunded debit rejects unchanged: " + tag)
	_check(wallet == before and record == record_before and selector.is_valid() and not selector.is_claimed(), "rejection preserves inputs and visit: " + tag)
	receipt.wallet.gold += 999
	_check(wallet == before, "rejection wallet detached: " + tag)
	if delta[0] < 0:
		_mark_refusal(record.id, "gold")
	if delta[1] < 0:
		_mark_refusal(record.id, "scraps")
	var exit_id := _free_exit_id(record.id)
	_check(not exit_id.is_empty(), "authored free exit exists")
	var exit_receipt := selector.choose_with_wallet(exit_id, wallet)
	_check(exit_receipt == {"ok": true, "event_id": record.id, "choice_id": exit_id, "wallet": before}
		and selector.is_claimed() and not selector.is_valid(), "same rejected selector permits free exit")
	_check(wallet == before and record == record_before, "free exit preserves inputs")
