extends SceneTree
## Independent authored contracts and settlement oracles; no global pool count or index.
## Pepper-mill, nutcracker and sugar-tongs roadside bargains: the three records are
## looked up by ID in the production catalog, checked verbatim, then driven through
## the shipped RunEventChoice for funded, refused, zero-wallet and injected flows.
const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const ZERO := {"gold": 0, "scraps": 0}
const PEPPER := "v3_pepper_mill_stairwell"
const NUTCRACKER := "v3_nutcracker_ward"
const TONGS := "v3_sugar_tongs_span"
const EXPECTED := {
	PEPPER: {
		"id": PEPPER, "title": "The Pepper-Mill Stairwell",
		"description": "A towering brass pepper mill stands open on a candlelit landing, its stepped grinder spiralling upward like a stairwell; a plump button-eyed miller doll winds the great crank, raining amber peppercorn dust onto the dolls below.",
		"choices": [
			{"id": "buy_copper_grind", "text": "Pay 18 gold for three bundles of copper-ground thread (+3 scraps)", "outcome": {"gold": -18, "scraps": 3}},
			{"id": "oil_crank_spindle", "text": "Spend 1 scrap oiling the crank spindle (earn 21 gold)", "outcome": {"gold": 21, "scraps": -1}},
			{"id": "leave", "text": "Leave the pepper mill to its slow grinding", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	NUTCRACKER: {
		"id": NUTCRACKER, "title": "The Nutcracker Ward",
		"description": "A wardrobe-tall oxblood nutcracker doll stands sentry over a shelf of splinted ragdoll patients, cracking candle-warm walnuts with its brass jaws onto a moss-velvet counter.",
		"choices": [
			{"id": "salvage_shell_stitch", "text": "Gather two shells of walnut stitching (+2 scraps)", "outcome": {"gold": 0, "scraps": 2}},
			{"id": "brace_nutcracker_jaws", "text": "Spend 2 scraps bracing the nutcracker's aching jaws (earn 29 gold)", "outcome": {"gold": 29, "scraps": -2}},
			{"id": "leave", "text": "Leave the ward to its quiet cracking", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	TONGS: {
		"id": TONGS, "title": "The Sugar-Tongs Span",
		"description": "Two silver sugar tongs lie clasped tip to tip across a dark gap between table ledges, forming a narrow span; a round button-eyed sweetkeeper tests their cold hinge by amber candlelight.",
		"choices": [
			{"id": "gather_tong_thread", "text": "Gather a loose thread from the tongs' silver hinge (+1 scrap)", "outcome": {"gold": 0, "scraps": 1}},
			{"id": "buy_pincer_bindings", "text": "Pay 14 gold for two bundles of pincer binding (+2 scraps)", "outcome": {"gold": -14, "scraps": 2}},
			{"id": "leave", "text": "Leave the sugar-tong span to its cold shadow", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}
# Hardcoded balances from the brief, never computed from production outcomes.
const FINAL := {
	PEPPER: {"buy_copper_grind": {"gold": 32, "scraps": 8}, "oil_crank_spindle": {"gold": 71, "scraps": 4}, "leave": {"gold": 50, "scraps": 5}},
	NUTCRACKER: {"salvage_shell_stitch": {"gold": 50, "scraps": 7}, "brace_nutcracker_jaws": {"gold": 79, "scraps": 3}, "leave": {"gold": 50, "scraps": 5}},
	TONGS: {"gather_tong_thread": {"gold": 50, "scraps": 6}, "buy_pincer_bindings": {"gold": 36, "scraps": 7}, "leave": {"gold": 50, "scraps": 5}},
}
const LOW := [
	[PEPPER, "buy_copper_grind", {"gold": 17, "scraps": 5}],
	[PEPPER, "oil_crank_spindle", {"gold": 50, "scraps": 0}],
	[NUTCRACKER, "brace_nutcracker_jaws", {"gold": 50, "scraps": 1}],
	[TONGS, "buy_pincer_bindings", {"gold": 13, "scraps": 5}],
]
# Earlier named anchor stories and complete choice lists, including their Leave outcomes.
const ANCHORS := {
	"v3_raincoat_bridge": ["The Raincoat Bridge", "A soaked quilt bridge stretching over a ravine.", [
		["salvage_hems", "Salvage loose hems (+1 scrap)", 0, 1],
		["trade_fare", "Trade fare for threads (-12 gold, +2 scraps)", -12, 2],
		["take_detour", "Take a detour (Leave)", 0, 0]]],
	"v3_squeaking_bedspring_bridge": ["The Squeaking Bed-Spring Bridge", "A towering brass bed spring hangs across a cracked nursery floorboard like a swaying bridge; a plump button-eyed porter coils thread around its rattling hooks in amber lamplight.", [
		["unhook_spare_coils", "Gather two loose coils of stitching thread (+2 scraps)", 0, 2],
		["mend_spring_crossing", "Spend 2 scraps fastening the spring bridge (earn 28 gold)", 28, -2],
		["leave", "Let the spring swing over the dark crack", 0, 0]]],
	"v3_forgotten_photograph_album": ["The Forgotten Photograph Album", "An enormous accordion photograph album lies open across a stair landing, stitched portraits slipping from its velvet pockets; a tiny oxblood archivist offers brass clasps to help rebind its spine.", [
		["sell_lost_corners", "Trade 1 scrap of album corners for 17 gold", 17, -1],
		["buy_spine_thread", "Pay 19 gold for three bundles of spine thread (+3 scraps)", -19, 3],
		["leave", "Fold the giant album shut without disturbing its portraits", 0, 0]]],
	"v3_pencil_ferry_crossing": ["The Pencil-Ferry Crossing", "A pencil longer than a bridge floats across a pool of spilled blue-black ink; a stubby moss-cloaked ferry keeper steers it with an oversized sewing needle under an amber candle.", [
		["gather_eraser_stitch", "Gather a loose thread cuff around the pencil eraser (+1 scrap)", 0, 1],
		["buy_ferry_binding", "Pay 15 gold for two bundles of pencil-ferry binding (+2 scraps)", -15, 2],
		["leave", "Wait for the pencil ferry to drift downstream", 0, 0]]],
}

var failures: Array[String] = []
var checks := 0
var document: Dictionary = {}
var records: Dictionary = {}

func _initialize() -> void:
	document = _read(PATH)
	var snapshot := document.duplicate(true)
	var events: Variant = document.get("events")
	_check(events is Array, "source has an events array")
	if not events is Array:
		_finish()
		return
	for event_id in EXPECTED.keys() + ANCHORS.keys():
		var matches: Array = events.filter(func(row): return row is Dictionary and row.get("id") == event_id)
		_check(matches.size() == 1, "source ID occurs exactly once: " + event_id)
		if matches.size() == 1:
			records[event_id] = matches[0]
	if records.size() != EXPECTED.size() + ANCHORS.size():
		_finish()
		return
	_test_records()
	_test_rotation()
	_test_funded()
	_test_refusals()
	_test_zero()
	_test_injected()
	_check(document == snapshot, "all flows preserve source document")
	_finish()

func _test_records() -> void:
	for event_id in EXPECTED:
		var record: Dictionary = records[event_id]
		_check(_same_authored(record, EXPECTED[event_id]), "exact four-field authored contract: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and choices.size() == 3, "three authored options: " + event_id)
		if not choices is Array:
			continue
		var seen := {}
		for choice in choices:
			_check(choice is Dictionary, "choice is an object")
			if not choice is Dictionary:
				continue
			_check(choice.size() == 3 and choice.has("id") and choice.has("text") and choice.has("outcome"), "exact choice fields")
			_check(not seen.has(choice.get("id")), "distinct choice ID")
			seen[choice.get("id")] = true
			var outcome: Variant = choice.get("outcome")
			_check(outcome is Dictionary, "wallet outcome object")
			if outcome is Dictionary:
				_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"), "exact wallet keys")
				_check(_whole(outcome.get("gold")) and _whole(outcome.get("scraps")), "signed integer amounts (JSON numbers may parse as floats)")
	for event_id in EXPECTED:
		var third: Variant = records[event_id].get("choices")
		if third is Array and (third as Array).size() == 3:
			var leave_choice: Dictionary = (third as Array)[2]
			_check(leave_choice.get("id") == "leave" and _same_authored(leave_choice.get("outcome"), {"gold": 0, "scraps": 0}), "third option is a zero Leave: " + event_id)
	for event_id in ANCHORS:
		var anchor: Array = ANCHORS[event_id]
		var choices := []
		for option in anchor[2]:
			choices.append({"id": option[0], "text": option[1], "outcome": {"gold": option[2], "scraps": option[3]}})
		_check(_same_authored(records[event_id], {"id": event_id, "title": anchor[0], "description": anchor[1], "choices": choices}), "complete original anchor preserved: " + event_id)

func _test_rotation() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "default real catalog validates")
	if not rotation.is_catalog_valid():
		return
	var ids := rotation.get_generic_event_ids()
	var listing := rotation.get_generic_events()
	_check(not ids.is_empty() and not listing.is_empty(), "default generic pool is populated")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "default membership exactly once: " + event_id)
		var matches := listing.filter(func(row): return row.get("id") == event_id)
		_check(matches.size() == 1 and matches[0] == records[event_id], "default serves authentic source: " + event_id)
		_forced_selection(rotation, event_id, FUNDED, true)
	for event_id in ANCHORS:
		_check(ids.count(event_id) == 1, "anchor remains in default pool: " + event_id)
	_forced_selection(rotation, PEPPER, ZERO, false)
	_forced_selection(rotation, NUTCRACKER, ZERO, true)
	_forced_selection(rotation, TONGS, ZERO, true)
	listing.clear()
	ids.clear()
	_check(not rotation.get_generic_event_ids().is_empty() and not rotation.get_generic_events().is_empty(), "returned listings are detached")

func _forced_selection(rotation: RunM04EventRotation, event_id: String, initial: Dictionary, actionable: bool) -> void:
	var excluded := rotation.get_generic_event_ids()
	_check(excluded.count(event_id) == 1, "target exists before constructing exclusions")
	excluded.erase(event_id) # Derive all exclusions dynamically, erase only our target.
	var before := excluded.duplicate(true)
	var wallet := initial.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 61803
	var state := rng.state
	var picked := rotation.select_actionable_event(rng, excluded, wallet)
	if actionable:
		_check(picked == {"ok": true, "event": records[event_id]}, "seeded single-eligible authentic selection: " + event_id)
		if picked.get("event") is Dictionary and not picked["event"].is_empty():
			picked["event"]["choices"][0]["outcome"]["gold"] = 999
			_check(rotation.select_actionable_event(rng, excluded, wallet) == {"ok": true, "event": records[event_id]}, "selected nested data is detached")
	else:
		_check(picked == {"ok": false, "event": {}}, "Leave alone is not actionable: " + event_id)
		_check(rng.state == state, "empty actionable pool does not draw RNG")
	_check(excluded == before and wallet == initial, "selection preserves exclusions and wallet")

func _test_funded() -> void:
	var settled := 0
	for event_id in EXPECTED:
		for choice in EXPECTED[event_id]["choices"]:
			var choice_id: String = choice["id"]
			var record: Dictionary = records[event_id].duplicate(true)
			var original := record.duplicate(true)
			var wallet := FUNDED.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(), "fresh funded visit validates")
			var preview := service.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id and preview.get("choices", []).size() == 3, "complete funded preview")
			for option in EXPECTED[event_id]["choices"]:
				_check(_row(preview, option["id"]) == {"choice_id": option["id"], "gold_delta": option["outcome"]["gold"], "scraps_delta": option["outcome"]["scraps"], "affordable": true, "wallet": FINAL[event_id][option["id"]]}, "exact funded preview deltas and independent projection")
			# Mutating public nested returns cannot alter the service or input.
			var exposed := service.get_event()
			exposed["choices"][0]["outcome"]["gold"] = 999
			preview["choices"][0]["wallet"]["gold"] = 999
			_check(service.get_event() == original and service.preview_wallet_choices(wallet)["choices"][0]["wallet"] == FINAL[event_id][EXPECTED[event_id]["choices"][0]["id"]], "event and preview returns are detached")
			var receipt := service.choose_with_wallet(choice_id, wallet)
			_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": FINAL[event_id][choice_id]}, "exact independent funded receipt")
			_check(service.is_claimed() and not service.is_valid(), "successful claim closes visit")
			_check(service.choose_with_wallet(choice_id, wallet) == _denied(wallet), "replay rejected unchanged")
			receipt["wallet"]["gold"] = 999
			_check(wallet == FUNDED and record == original, "funded flow and receipt preserve inputs")
			settled += 1
	_check(settled == 9, "all nine funded options exercised on fresh visits")

func _test_refusals() -> void:
	for case in LOW:
		_refusal(case[0], case[1], case[2], true)
	for event_id in EXPECTED:
		_refusal(event_id, "forged_unknown_choice", FUNDED, false)

func _refusal(event_id: String, choice_id: String, initial: Dictionary, priced: bool) -> void:
	var record: Dictionary = records[event_id].duplicate(true)
	var original := record.duplicate(true)
	var wallet := initial.duplicate(true)
	var service := RunEventChoice.new(record)
	_check(service.is_valid() and not service.is_claimed(), "fresh refusal visit validates")
	if priced:
		var preview := service.preview_wallet_choices(wallet)
		var row := _row(preview, choice_id)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id, "denied preview remains visible")
		_check(not row.is_empty() and row.get("affordable") == false and row.get("wallet") == initial, "one-unit-short choice visible, unaffordable, unchanged projection")
	_check(service.choose_with_wallet(choice_id, wallet) == _denied(initial), "failed choice refuses exact unchanged wallet")
	_check(service.is_valid() and not service.is_claimed(), "failure leaves visit unclaimed")
	_check(service.choose_with_wallet("leave", wallet) == {"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": initial}, "Leave succeeds after failed spending or unknown choice")
	_check(service.is_claimed() and not service.is_valid(), "subsequent Leave claims once")
	_check(wallet == initial and record == original, "refusal and subsequent Leave preserve inputs")

func _test_zero() -> void:
	var cases := [[NUTCRACKER, "salvage_shell_stitch", {"gold": 0, "scraps": 2}], [TONGS, "gather_tong_thread", {"gold": 0, "scraps": 1}]]
	for event_id in EXPECTED:
		cases.append([event_id, "leave", {"gold": 0, "scraps": 0}])
	for case in cases:
		var wallet := ZERO.duplicate(true)
		var service := RunEventChoice.new(records[case[0]])
		_check(service.is_valid(), "fresh zero-wallet visit validates")
		var preview := service.preview_wallet_choices(wallet)
		var row := _row(preview, case[1])
		_check(row.get("affordable") == true and row.get("wallet") == case[2], "zero-wallet free projection")
		_check(service.choose_with_wallet(case[1], wallet) == {"ok": true, "event_id": case[0], "choice_id": case[1], "wallet": case[2]}, "exact zero-wallet settlement")
		_check(service.is_claimed() and not service.is_valid() and wallet == ZERO, "zero-wallet claim latches without input mutation")
	var pepper := RunEventChoice.new(records[PEPPER])
	var preview := pepper.preview_wallet_choices(ZERO)
	_check(preview.get("ok") == true and preview.get("choices", []).size() == 3, "zero-wallet pepper preview includes all options")
	_check(_row(preview, "buy_copper_grind").get("affordable") == false and _row(preview, "oil_crank_spindle").get("affordable") == false, "both pepper trades unaffordable at zero")
	for row in preview.get("choices", []):
		_check(not row.get("affordable", false) or (row.get("gold_delta") == 0 and row.get("scraps_delta") == 0), "pepper has no affordable nonzero outcome")

func _test_injected() -> void:
	var base := _read("res://data/events/m04_events.json")
	_check(base.get("events") is Array, "real M04 source available for valid injection")
	if not base.get("events") is Array:
		return
	var injected := {"events": base["events"].duplicate(true)}
	for event_id in EXPECTED:
		injected["events"].append(records[event_id].duplicate(true))
	var original := injected.duplicate(true)
	var rotation := RunM04EventRotation.new(injected)
	_check(rotation.is_catalog_valid(), "real injected catalog validates")
	if not rotation.is_catalog_valid():
		return
	for event_id in EXPECTED:
		_forced_selection(rotation, event_id, FUNDED, true)
	_check(injected == original, "injected document unmodified by construction and selections")
	injected["events"].clear()
	_forced_selection(rotation, NUTCRACKER, FUNDED, true)
	var input: Dictionary = records[TONGS].duplicate(true)
	var service := RunEventChoice.new(input)
	input["choices"][0]["outcome"]["scraps"] = 999
	_check(service.get_event() == records[TONGS], "choice constructor detaches injected nested record")
	_check(service.choose_with_wallet("gather_tong_thread", ZERO) == {"ok": true, "event_id": TONGS, "choice_id": "gather_tong_thread", "wallet": {"gold": 0, "scraps": 1}}, "caller mutation cannot alter settlement")

func _row(preview: Dictionary, choice_id: String) -> Dictionary:
	var rows: Array = preview.get("choices", [])
	var matches := rows.filter(func(row): return row is Dictionary and row.get("choice_id") == choice_id)
	_check(matches.size() == 1, "preview choice occurs exactly once: " + choice_id)
	return matches[0] if matches.size() == 1 else {}

func _denied(wallet: Dictionary) -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": "", "wallet": wallet}

func _whole(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value)

# JSON parses all numbers as floats; compare exact keys/text/order while allowing
# only finite whole-number equivalents of the independent integer literals.
func _same_authored(actual: Variant, expected: Variant) -> bool:
	if expected is Dictionary:
		if not actual is Dictionary or actual.size() != expected.size():
			return false
		for key in expected:
			if not actual.has(key) or not _same_authored(actual[key], expected[key]):
				return false
		return true
	if expected is Array:
		if not actual is Array or actual.size() != expected.size():
			return false
		for index in expected.size():
			if not _same_authored(actual[index], expected[index]):
				return false
		return true
	if typeof(expected) == TYPE_INT:
		return _whole(actual) and actual == expected
	return typeof(actual) == typeof(expected) and actual == expected

func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "FileAccess opens " + path)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	_check(error == OK and parser.data is Dictionary, "JSON object parses: " + path)
	return parser.data if error == OK and parser.data is Dictionary else {}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_peppermill_nutcracker_tongs_roadside_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
