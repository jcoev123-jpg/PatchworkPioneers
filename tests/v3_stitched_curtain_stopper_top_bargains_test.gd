extends SceneTree
## Scene-free contract coverage for the three appended doll-scale Stitched
## candlelit wallet stories: the curtain-weight bell, the glass-stopper beacon
## and the spinning-top watch. The authored JSON is parsed directly, every new
## record is checked against its exact prose and wallet table, and funded
## settlement, preview, refusal, detachment and RNG neutrality run through the
## real RunEventChoice service on independent fresh selectors. The shared
## catalog's total size and global order are deliberately never asserted.

const PATH := "res://data/events/v3_candlelit_bargains.json"
const FUNDED_WALLET := {"gold": 60, "scraps": 6}
const EMPTY_WALLET := {"gold": 0, "scraps": 0}
const RNG_SEED := 6048
const RNG_DRAWS := 4

## Earlier records from this same catalog that must remain present, unchanged
## and still construct a valid selector. Their full prose is intentionally not
## re-asserted here: this test only proves the shared catalog was not replaced.
const ANCHOR_IDS := [
	"lantern_bobbin_ferry",
	"v3_bellglass_night_market",
	"v3_bonecream_clothespin_turnpike",
	"v3_rust_funnel_forge",
]

## Choice rows are [id, text, gold, scraps, settled {gold, scraps}] where the
## settled balance comes independently from the funded {gold: 60, scraps: 6}
## wallet. gold_short/scraps_short are [paid choice ID, wallet that must refuse].
const NEW_RECORDS := {
	"v3_curtain_weight_bell": {
		"title": "The Curtain-Weight Bell",
		"description": "A tarnished curtain weight hangs above the floorboard seam like a chapel bell. A round button-eyed watchdoll braces its frayed chain, while one amber candle throws a swinging shadow over the crossing.",
		"choices": [
			["buy_chain_thread", "Pay 21 gold for two chain-thread bundles (+2 scraps)", -21, 2, {"gold": 39, "scraps": 8}],
			["steady_weight_chain", "Spend 2 scraps steadying the great weight (earn 31 gold)", 31, -2, {"gold": 91, "scraps": 4}],
			["leave", "Pass beneath the weight while its shadow swings", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_chain_thread", {"gold": 20, "scraps": 6}],
		"scraps_short": ["steady_weight_chain", {"gold": 60, "scraps": 1}],
	},
	"v3_glass_stopper_beacon": {
		"title": "The Glass-Stopper Beacon",
		"description": "An immense blue glass bottle stopper crowns a tiny stitched lighthouse built inside the wall. Its plump moss-cloth keeper wraps the glowing wick in thread as a cold reflection sweeps the passage.",
		"choices": [
			["purchase_prism_wraps", "Pay 29 gold for three prism-bound seam wraps (+3 scraps)", -29, 3, {"gold": 31, "scraps": 9}],
			["rebind_beacon_wick", "Spend 1 scrap rebinding the lighthouse wick (earn 17 gold)", 17, -1, {"gold": 77, "scraps": 5}],
			["leave", "Leave the little keeper watching the dark wall", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["purchase_prism_wraps", {"gold": 28, "scraps": 6}],
		"scraps_short": ["rebind_beacon_wick", {"gold": 60, "scraps": 0}],
	},
	"v3_spinning_top_watch": {
		"title": "The Spinning-Top Watch",
		"description": "An enormous painted wooden spinning top teeters between two skirting boards, turning its stitched pennants into a blurred warning. A stout plum-velvet watchdoll grips the loose axle under a small lantern.",
		"choices": [
			["buy_axle_threads", "Pay 16 gold for two axle-thread bundles (+2 scraps)", -16, 2, {"gold": 44, "scraps": 8}],
			["tie_top_axle", "Spend 3 scraps tying the wobbling axle (earn 42 gold)", 42, -3, {"gold": 102, "scraps": 3}],
			["leave", "Walk away before the great top falls silent", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_axle_threads", {"gold": 15, "scraps": 6}],
		"scraps_short": ["tie_top_axle", {"gold": 60, "scraps": 2}],
	},
}

var failures: Array[String] = []
var checks := 0
## Which fail-closed kind each new Event actually exercised: {event_id: {kind: true}}.
var exercised := {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _nonblank(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


## Godot JSON parses integer tokens as floats; require exact integral values.
func _integral_exact(value: Variant, wanted: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == wanted


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
				var records: Array = document.events
				var snapshot: Array = records.duplicate(true)
				_test_anchors(records)
				for event_id in NEW_RECORDS:
					_test_new_record(records, event_id)
				_check(records == snapshot, "all authored inputs remain unchanged")
	for failure in failures:
		printerr(failure)
	print("v3_stitched_curtain_stopper_top_bargains_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _find(records: Array, event_id: String) -> Array:
	return records.filter(func(record): return record is Dictionary and record.get("id") == event_id)


## Earlier exemplars must still be present exactly once and still build the real
## service; their data is owned by their own lane and is not re-asserted here.
func _test_anchors(records: Array) -> void:
	for event_id in ANCHOR_IDS:
		var matches: Array = _find(records, event_id)
		_check(matches.size() == 1, "anchor ID occurs exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(),
			"anchor builds a valid fresh selector: " + event_id)


## Verifies one record keeps only id/title/description/choices and that every
## authored choice row matches exactly. Returns {choice_id: choice} for reuse.
func _test_choice_table(record: Dictionary, expected: Dictionary, tag: String) -> Dictionary:
	_check(record.size() == 4 and record.has("id") and record.has("title")
		and record.has("description") and record.has("choices"),
		"record keeps only id/title/description/choices: " + tag)
	_check(record.get("title") == expected.title, "title exact: " + tag)
	_check(record.get("description") == expected.description, "description exact: " + tag)
	var choices: Variant = record.get("choices")
	_check(choices is Array and (choices as Array).size() == 3, "record authors exactly three choices: " + tag)
	if not choices is Array:
		return {}
	var by_id := {}
	for choice in choices:
		_check(choice is Dictionary, "choice record: " + tag)
		if not choice is Dictionary:
			continue
		var raw_choice: Dictionary = choice
		_check(raw_choice.size() == 3 and raw_choice.has("id") and raw_choice.has("text")
			and raw_choice.has("outcome"), "choice keeps only id/text/outcome: " + tag)
		var raw_id: Variant = raw_choice.get("id")
		_check(_nonblank(raw_id) and not by_id.has(raw_id), "distinct nonblank choice ID: " + tag)
		if raw_id is String:
			by_id[raw_id] = raw_choice
	var wanted: Array = expected.choices
	_check(by_id.size() == wanted.size(), "choice count matches the authored table: " + tag)
	for row in wanted:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		_check(by_id.has(choice_id), "required choice exists: " + choice_tag)
		if not by_id.has(choice_id):
			continue
		var choice: Dictionary = by_id[choice_id]
		_check(choice.get("text") == row[1], "choice text exact: " + choice_tag)
		var outcome: Variant = choice.get("outcome")
		_check(outcome is Dictionary and (outcome as Dictionary).size() == 2
			and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps"),
			"outcome carries precisely gold/scraps: " + choice_tag)
		if outcome is Dictionary:
			_check(_integral_exact((outcome as Dictionary).get("gold"), row[2])
				and _integral_exact((outcome as Dictionary).get("scraps"), row[3]),
				"outcome exact signed deltas: " + choice_tag)
	return by_id


func _test_new_record(records: Array, event_id: String) -> void:
	var expected: Dictionary = NEW_RECORDS[event_id]
	var tag: String = event_id
	var matches: Array = _find(records, event_id)
	_check(matches.size() == 1, "new ID occurs exactly once: " + tag)
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	var by_id := _test_choice_table(record, expected, tag)
	_check(by_id.has("leave"), "new record offers a Leave choice: " + tag)
	if by_id.has("leave"):
		var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
		_check(leave_outcome is Dictionary
			and _integral_exact((leave_outcome as Dictionary).get("gold"), 0)
			and _integral_exact((leave_outcome as Dictionary).get("scraps"), 0),
			"Leave is free: " + tag)
	var selector := RunEventChoice.new(record)
	_check(selector.is_valid() and not selector.is_claimed(), "valid fresh selector: " + tag)
	_test_funded_branches(record, expected)
	_test_short_refusal(record, expected.gold_short, "gold-short")
	_test_short_refusal(record, expected.scraps_short, "scraps-short")
	_test_empty_wallet(record, expected)
	_test_rng_neutrality(record)
	var kinds: Dictionary = exercised.get(event_id, {})
	for kind in ["gold-short", "scraps-short", "empty-wallet", "repeated"]:
		_check(kinds.get(kind, false), "new Event exercised fail-closed witness " + kind + ": " + tag)


func _preview_entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


## Funded preview plus one fresh committing selector per authored branch, each
## settling independently from the same {gold: 60, scraps: 6} wallet; every
## branch is replayed and crossed on its claimed selector.
func _test_funded_branches(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var preview := selector.preview_wallet_choices(FUNDED_WALLET)
	_check(preview.get("ok") == true and preview.get("event_id") == record.id, "funded preview available: " + tag)
	_check(selector.is_valid() and not selector.is_claimed(), "preview consumes no visit: " + tag)
	var entries: Variant = preview.get("choices")
	_check(entries is Array and (entries as Array).size() == expected.choices.size(),
		"preview covers every authored choice: " + tag)
	var choice_ids: Array = []
	for row in expected.choices:
		choice_ids.append(row[0])
	for row in expected.choices:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		var forecast := _preview_entry(preview, choice_id)
		_check(not forecast.is_empty() and forecast.get("choice_id") == choice_id
			and forecast.get("gold_delta") == row[2]
			and forecast.get("scraps_delta") == row[3] and forecast.get("affordable") == true
			and forecast.get("wallet") == row[4],
			"funded preview forecasts the exact balance: " + choice_tag)
		var branch := RunEventChoice.new(record)
		var wallet := FUNDED_WALLET.duplicate(true)
		var receipt := branch.choose_with_wallet(choice_id, wallet)
		_check(receipt == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": row[4]},
			"fresh selector settles the exact independent balance: " + choice_tag)
		_check(branch.is_claimed() and not branch.is_valid(),
			"success claims the visit exactly once: " + choice_tag)
		_check(wallet == FUNDED_WALLET and record == original,
			"settlement preserves caller wallet and event data: " + choice_tag)
		receipt.wallet.gold += 999
		_check(wallet == FUNDED_WALLET, "settled wallet is detached: " + choice_tag)
		var settled: Dictionary = (row[4] as Dictionary).duplicate(true)
		var replay := branch.choose_with_wallet(choice_id, settled)
		_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": row[4]},
			"replay of the settled branch is refused: " + choice_tag)
		_check(branch.is_claimed() and settled == row[4],
			"replay leaves one claim and the passed wallet unchanged: " + choice_tag)
		var other_id: String = ""
		for candidate in choice_ids:
			if candidate != choice_id:
				other_id = candidate
				break
		var crossed: Dictionary = (row[4] as Dictionary).duplicate(true)
		var second := branch.choose_with_wallet(other_id, crossed)
		_check(second == {"ok": false, "event_id": "", "choice_id": "", "wallet": row[4]},
			"different second choice on the settled selector is refused: " + choice_tag)
		_check(branch.is_claimed() and crossed == row[4] and wallet == FUNDED_WALLET,
			"crossed choice leaves one claim and both wallets unchanged: " + choice_tag)
		_mark_exercised(record.id, "repeated")
	_check(selector.get_event() == original, "service event detached and unchanged: " + tag)
	_check(record == original, "catalog record unchanged after funded previews: " + tag)


## One short-resource witness: the paid choice is unaffordable, the refusal
## keeps the wallet, the record and the unclaimed visit intact, and the free
## Leave settles that same visit exactly once.
func _test_short_refusal(record: Dictionary, witness: Array, kind: String) -> void:
	var choice_id: String = witness[0]
	var wallet: Dictionary = (witness[1] as Dictionary).duplicate(true)
	var before: Dictionary = wallet.duplicate(true)
	var original: Dictionary = record.duplicate(true)
	var tag: String = record.id + "/" + choice_id + "/" + kind
	var selector := RunEventChoice.new(record)
	var forecast := _preview_entry(selector.preview_wallet_choices(wallet), choice_id)
	_check(not forecast.is_empty() and forecast.get("choice_id") == choice_id
		and forecast.get("affordable") == false
		and forecast.get("wallet") == before,
		kind + " wallet previews the paid choice unavailable: " + tag)
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		kind + " wallet refuses the paid choice unchanged: " + tag)
	_check(wallet == before and record == original and selector.is_valid() and not selector.is_claimed(),
		kind + " refusal preserves inputs and leaves the visit unclaimed: " + tag)
	receipt.wallet.gold += 999
	_check(wallet == before, kind + " refusal wallet detached: " + tag)
	var leave := selector.choose_with_wallet("leave", wallet)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": before}
		and selector.is_claimed() and not selector.is_valid(),
		"free Leave still settles the refused visit: " + tag)
	var replay := selector.choose_with_wallet("leave", wallet)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": before}
		and selector.is_claimed(),
		"second Leave replay is refused: " + tag)
	_check(wallet == before and record == original, "free Leave preserves inputs: " + tag)
	_mark_exercised(record.id, kind)


## An empty wallet must refuse both paid branches and an unknown choice without
## claiming or spending, while its free Leave settles once and replays fail.
func _test_empty_wallet(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := EMPTY_WALLET.duplicate(true)
	for row in expected.choices:
		var choice_id: String = row[0]
		if choice_id == "leave":
			continue
		var receipt := selector.choose_with_wallet(choice_id, wallet)
		_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": EMPTY_WALLET},
			"empty wallet refuses paid branch: " + tag + "/" + choice_id)
		_check(selector.is_valid() and not selector.is_claimed() and wallet == EMPTY_WALLET,
			"empty-wallet refusal leaves the visit unclaimed: " + tag + "/" + choice_id)
	var unknown := selector.choose_with_wallet("not_an_offered_choice", wallet)
	_check(unknown == {"ok": false, "event_id": "", "choice_id": "", "wallet": EMPTY_WALLET},
		"unknown choice ID is refused: " + tag)
	_check(selector.is_valid() and not selector.is_claimed() and wallet == EMPTY_WALLET,
		"unknown choice ID consumes no visit: " + tag)
	var leave := selector.choose_with_wallet("leave", wallet)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": EMPTY_WALLET}
		and selector.is_claimed() and not selector.is_valid(),
		"empty wallet settles the free Leave once: " + tag)
	var replay := selector.choose_with_wallet("leave", wallet)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": EMPTY_WALLET}
		and selector.is_claimed(),
		"empty wallet refuses the second Leave: " + tag)
	_check(wallet == EMPTY_WALLET and record == original, "empty-wallet visit preserves inputs: " + tag)
	_mark_exercised(record.id, "empty-wallet")


## Two RandomNumberGenerators seeded 6048 with the same four draws must stay in
## lockstep while the real service previews, refuses and settles.
func _test_rng_neutrality(record: Dictionary) -> void:
	var tag: String = record.id
	var probe := RandomNumberGenerator.new()
	probe.seed = RNG_SEED
	for _i in RNG_DRAWS:
		probe.randi()
	var control := RandomNumberGenerator.new()
	control.seed = RNG_SEED
	for _i in RNG_DRAWS:
		control.randi()
	_check(probe.state == control.state, "rng seeds start identical: " + tag)
	var before: int = probe.state
	var control_before: int = control.state
	var selector := RunEventChoice.new(record)
	var preview := selector.preview_wallet_choices(FUNDED_WALLET)
	var refusal := selector.choose_with_wallet("not_an_offered_choice", EMPTY_WALLET)
	var receipt := selector.choose_with_wallet("leave", FUNDED_WALLET)
	_check(preview.get("ok") == true and refusal.get("ok") == false and receipt.get("ok") == true,
		"rng witness previews, refuses and settles: " + tag)
	var after: int = probe.state
	var reseeded := RandomNumberGenerator.new()
	reseeded.seed = RNG_SEED
	for _i in RNG_DRAWS:
		reseeded.randi()
	_check(before == after and after == control.state and control.state == control_before
		and after == reseeded.state,
		"event preview, refusal and settlement leave the run RNG state identical: " + tag)


func _mark_exercised(event_id: String, kind: String) -> void:
	var kinds: Dictionary = exercised.get(event_id, {})
	kinds[kind] = true
	exercised[event_id] = kinds
