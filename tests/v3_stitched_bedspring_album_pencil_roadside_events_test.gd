extends SceneTree
## Independent authored contracts and settlement oracles; no global pool count or index.
const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const ZERO := {"gold": 0, "scraps": 0}
const BED := "v3_squeaking_bedspring_bridge"
const ALBUM := "v3_forgotten_photograph_album"
const PENCIL := "v3_pencil_ferry_crossing"
const EXPECTED := {
	BED: {
		"id": BED, "title": "The Squeaking Bed-Spring Bridge",
		"description": "A towering brass bed spring hangs across a cracked nursery floorboard like a swaying bridge; a plump button-eyed porter coils thread around its rattling hooks in amber lamplight.",
		"choices": [
			{"id": "unhook_spare_coils", "text": "Gather two loose coils of stitching thread (+2 scraps)", "outcome": {"gold": 0, "scraps": 2}},
			{"id": "mend_spring_crossing", "text": "Spend 2 scraps fastening the spring bridge (earn 28 gold)", "outcome": {"gold": 28, "scraps": -2}},
			{"id": "leave", "text": "Let the spring swing over the dark crack", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	ALBUM: {
		"id": ALBUM, "title": "The Forgotten Photograph Album",
		"description": "An enormous accordion photograph album lies open across a stair landing, stitched portraits slipping from its velvet pockets; a tiny oxblood archivist offers brass clasps to help rebind its spine.",
		"choices": [
			{"id": "sell_lost_corners", "text": "Trade 1 scrap of album corners for 17 gold", "outcome": {"gold": 17, "scraps": -1}},
			{"id": "buy_spine_thread", "text": "Pay 19 gold for three bundles of spine thread (+3 scraps)", "outcome": {"gold": -19, "scraps": 3}},
			{"id": "leave", "text": "Fold the giant album shut without disturbing its portraits", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
	PENCIL: {
		"id": PENCIL, "title": "The Pencil-Ferry Crossing",
		"description": "A pencil longer than a bridge floats across a pool of spilled blue-black ink; a stubby moss-cloaked ferry keeper steers it with an oversized sewing needle under an amber candle.",
		"choices": [
			{"id": "gather_eraser_stitch", "text": "Gather a loose thread cuff around the pencil eraser (+1 scrap)", "outcome": {"gold": 0, "scraps": 1}},
			{"id": "buy_ferry_binding", "text": "Pay 15 gold for two bundles of pencil-ferry binding (+2 scraps)", "outcome": {"gold": -15, "scraps": 2}},
			{"id": "leave", "text": "Wait for the pencil ferry to drift downstream", "outcome": {"gold": 0, "scraps": 0}},
		],
	},
}
# Hardcoded balances from the brief, never computed from production outcomes.
const FINAL := {
	BED: {"unhook_spare_coils": {"gold": 50, "scraps": 7}, "mend_spring_crossing": {"gold": 78, "scraps": 3}, "leave": {"gold": 50, "scraps": 5}},
	ALBUM: {"sell_lost_corners": {"gold": 67, "scraps": 4}, "buy_spine_thread": {"gold": 31, "scraps": 8}, "leave": {"gold": 50, "scraps": 5}},
	PENCIL: {"gather_eraser_stitch": {"gold": 50, "scraps": 6}, "buy_ferry_binding": {"gold": 35, "scraps": 7}, "leave": {"gold": 50, "scraps": 5}},
}
const LOW := [
	[BED, "mend_spring_crossing", {"gold": 50, "scraps": 1}],
	[ALBUM, "sell_lost_corners", {"gold": 50, "scraps": 0}],
	[ALBUM, "buy_spine_thread", {"gold": 18, "scraps": 5}],
	[PENCIL, "buy_ferry_binding", {"gold": 14, "scraps": 5}],
]
# Original anchor story and complete choice lists, including their Leave outcomes.
const ANCHORS := {
	"v3_raincoat_bridge": ["The Raincoat Bridge", "A soaked quilt bridge stretching over a ravine.", [
		["salvage_hems", "Salvage loose hems (+1 scrap)", 0, 1],
		["trade_fare", "Trade fare for threads (-12 gold, +2 scraps)", -12, 2],
		["take_detour", "Take a detour (Leave)", 0, 0]]],
	"v3_bedpost_thimble_lift": ["The Bedpost Thimble Lift", "A stout button-eyed liftkeeper hauls a brass thimble up a giant bedpost on crossed red threads; the wooden rungs vanish into candlelit dark.", [
		["gather_pulley_shavings", "Collect brass pulley shavings (+2 scraps)", 0, 2],
		["oil_lift_pulley", "Offer 2 scraps to oil the thimble lift (gain 28 gold)", 28, -2],
		["leave", "Let the lift climb without you", 0, 0]]],
	"v3_moonlit_darning_egg": ["The Moonlit Darning Egg", "A house-sized bone-cream darning egg lies cracked on a black quilt ledge; a tiny button-eyed mender gathers silver thread from its split seam beneath one amber candle.", [
		["gather_egg_shell_stitches", "Collect stray silver stitches from the cracked egg (+2 scraps)", 0, 2],
		["resew_egg_crack", "Spend 2 scraps sealing the great egg seam (earn 28 gold)", 28, -2],
		["leave", "Leave the great egg beneath its pale quilt moon", 0, 0]]],
	"v3_velvet_curtain_pulley": ["The Velvet Curtain Pulley", "Across a high window ledge, a carriage-wide plum curtain hangs from a groaning brass pulley; a round moth-cloaked doll steadies its stitched rope in wavering candlelight.", [
		["buy_pulley_braid", "Pay 16 gold for three coils of curtain braid (+3 scraps)", -16, 3],
		["repair_curtain_guide", "Spend 1 scrap repairing the brass guide (earn 21 gold)", 21, -1],
		["leave", "Let the heavy curtain fall across the ledge", 0, 0]]],
	"v3_inkblack_hatpin_ladder": ["The Inkblack Hatpin Ladder", "Five towering silver hatpins lean against an inkblack wardrobe door; a squat moss-velvet ladder keeper lashes their heads together with oxblood yarn as the candle gutters.", [
		["salvage_hatpin_caps", "Gather a loose hatpin cap (+1 scrap)", 0, 1],
		["buy_ladder_lashing", "Pay 23 gold for four bundles of ladder lashing (+4 scraps)", -23, 4],
		["leave", "Leave the hatpin ladder rattling against the wardrobe", 0, 0]]],
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
	_forced_selection(rotation, ALBUM, ZERO, false)
	_forced_selection(rotation, BED, ZERO, true)
	_forced_selection(rotation, PENCIL, ZERO, true)
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
	rng.seed = 57408
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
	var cases := [[BED, "unhook_spare_coils", {"gold": 0, "scraps": 2}], [PENCIL, "gather_eraser_stitch", {"gold": 0, "scraps": 1}]]
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
	var album := RunEventChoice.new(records[ALBUM])
	var preview := album.preview_wallet_choices(ZERO)
	_check(preview.get("ok") == true and preview.get("choices", []).size() == 3, "zero-wallet album preview includes all options")
	_check(_row(preview, "sell_lost_corners").get("affordable") == false and _row(preview, "buy_spine_thread").get("affordable") == false, "both album trades unaffordable at zero")
	for row in preview.get("choices", []):
		_check(not row.get("affordable", false) or (row.get("gold_delta") == 0 and row.get("scraps_delta") == 0), "album has no affordable nonzero outcome")

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
	_forced_selection(rotation, ALBUM, FUNDED, true)
	var input: Dictionary = records[BED].duplicate(true)
	var service := RunEventChoice.new(input)
	input["choices"][0]["outcome"]["scraps"] = 999
	_check(service.get_event() == records[BED], "choice constructor detaches injected nested record")
	_check(service.choose_with_wallet("unhook_spare_coils", ZERO) == {"ok": true, "event_id": BED, "choice_id": "unhook_spare_coils", "wallet": {"gold": 0, "scraps": 2}}, "caller mutation cannot alter settlement")

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
	print("v3_stitched_bedspring_album_pencil_roadside_events_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
