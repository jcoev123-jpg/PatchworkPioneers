extends SceneTree
## Deterministic headless test for the four hero-gated doll-scale ironing-board,
## needle-threader, watering-can and coal-scuttle wallet stories appended to
## data/events/v3_hero_choice_events.json:
## v3_warden_ironing_board_barricade, v3_seamstress_silver_needle_threader,
## v3_tinker_watering_can_engine and v3_scarecrow_coal_scuttle_roost.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free four-hero
## party admission and RunEventChoice owns each visit's one-claim wallet
## receipt. Every lookup is by authored event/choice ID, never by catalog
## size, order or positional index; the shared catalog may be appended by
## parallel tasks.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## Canonical four-distinct-hero Stitched party containing all four required heroes.
const PARTY := ["warden", "seamstress", "tinker", "scarecrow"]

## Valid four-hero rosters missing exactly the event's required hero, each
## replaced by lantern_monk in a different valid party.
const ABSENCE_PARTIES := {
	"v3_warden_ironing_board_barricade": ["lantern_monk", "seamstress", "tinker", "scarecrow"],
	"v3_seamstress_silver_needle_threader": ["warden", "lantern_monk", "tinker", "scarecrow"],
	"v3_tinker_watering_can_engine": ["warden", "seamstress", "lantern_monk", "scarecrow"],
	"v3_scarecrow_coal_scuttle_roost": ["warden", "seamstress", "tinker", "lantern_monk"],
}

const START_GOLD := 45
const START_SCRAPS := 4

## Independent task-local expectation table copied from the authored brief;
## never read back from the production catalog.
const NEW_EVENTS := {
	"v3_warden_ironing_board_barricade": {
		"title": "The Ironing-Board Barricade",
		"description": "An enormous collapsed ironing board wedges across the candlelit hall, its black iron legs grinding against floorboards. The Warden braces his round slate patch shield beneath its falling hinge while small doll couriers wait on the far side.",
		"required_hero": "warden",
		"hero_choice_ids": ["brace_iron_hinge", "salvage_board_tacks"],
		"choices": [
			{"id": "brace_iron_hinge", "text": "Spend 2 scraps bracing the great iron hinge (earn 29 gold)", "gold": 29, "scraps": -2},
			{"id": "salvage_board_tacks", "text": "Gather two useful brass tacks from the board (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "leave", "text": "Leave the couriers waiting beside the creaking hinge", "gold": 0, "scraps": 0},
		],
	},
	"v3_seamstress_silver_needle_threader": {
		"title": "The Silver Needle Threader",
		"description": "A wire-loop needle threader hangs like a silver doorway between two velvet curtains. The Seamstress lifts her giant needle and guides scarlet thread through its trembling eye as a small patchmaker watches from behind the folds.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["repair_threader_loop", "buy_eyeloop_wire"],
		"choices": [
			{"id": "repair_threader_loop", "text": "Spend 1 scrap mending the bent wire loop (earn 23 gold)", "gold": 23, "scraps": -1},
			{"id": "buy_eyeloop_wire", "text": "Pay 15 gold for three coils of fine threader wire (+3 scraps)", "gold": -15, "scraps": 3},
			{"id": "leave", "text": "Let the silver doorway sway in the draft", "gold": 0, "scraps": 0},
		],
	},
	"v3_tinker_watering_can_engine": {
		"title": "The Watering-Can Engine",
		"description": "A vast midnight-teal watering can leaks warm copper drops into a doll-sized greenhouse lane. The Tinker crouches beneath its dented spout, goggles bright as her scrap backpack's little gears catch the falling drops.",
		"required_hero": "tinker",
		"hero_choice_ids": ["seal_can_spout", "gather_spout_springs"],
		"choices": [
			{"id": "seal_can_spout", "text": "Spend 2 scraps sealing the spout's gears (earn 31 gold)", "gold": 31, "scraps": -2},
			{"id": "gather_spout_springs", "text": "Collect a spare spring from the watering-can rim (+1 scrap)", "gold": 0, "scraps": 1},
			{"id": "leave", "text": "Pass under the dripping spout without disturbing it", "gold": 0, "scraps": 0},
		],
	},
	"v3_scarecrow_coal_scuttle_roost": {
		"title": "The Coal-Scuttle Roost",
		"description": "A house-sized coal scuttle lies open beside the skirting board, its iron mouth dark as a cave. The Scarecrow's black crow taps at loose brass rivets while his pitchfork props up a sackcloth nest above the ash.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["lift_scuttle_latch", "gather_ash_thread"],
		"choices": [
			{"id": "lift_scuttle_latch", "text": "Spend 1 scrap lifting the iron latch for the nest (earn 25 gold)", "gold": 25, "scraps": -1},
			{"id": "gather_ash_thread", "text": "Wind two clean strands from the ash-dusted nest (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "leave", "text": "Leave the crow watching the coal-dark mouth", "gold": 0, "scraps": 0},
		],
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_seamstress_splintered_parlour_fan",
	"v3_tinker_copper_saltcellar"]

## Independent funded receipt literals for fresh {"gold": 45, "scraps": 4}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_warden_ironing_board_barricade": {
		"brace_iron_hinge": [74, 2],
		"salvage_board_tacks": [45, 6],
		"leave": [45, 4],
	},
	"v3_seamstress_silver_needle_threader": {
		"repair_threader_loop": [68, 3],
		"buy_eyeloop_wire": [30, 7],
		"leave": [45, 4],
	},
	"v3_tinker_watering_can_engine": {
		"seal_can_spout": [76, 2],
		"gather_spout_springs": [45, 5],
		"leave": [45, 4],
	},
	"v3_scarecrow_coal_scuttle_roost": {
		"lift_scuttle_latch": [70, 3],
		"gather_ash_thread": [45, 6],
		"leave": [45, 4],
	},
}

## Choices whose exact charge a just-short wallet cannot afford; each witness
## is a FRESH visit that must keep its wallet and still allow Leave.
const INSUFFICIENT_WALLETS := [
	{"event_id": "v3_warden_ironing_board_barricade", "choice_id": "brace_iron_hinge", "gold": 45, "scraps": 1},
	{"event_id": "v3_seamstress_silver_needle_threader", "choice_id": "repair_threader_loop", "gold": 45, "scraps": 0},
	{"event_id": "v3_seamstress_silver_needle_threader", "choice_id": "buy_eyeloop_wire", "gold": 14, "scraps": 4},
	{"event_id": "v3_tinker_watering_can_engine", "choice_id": "seal_can_spout", "gold": 45, "scraps": 1},
	{"event_id": "v3_scarecrow_coal_scuttle_roost", "choice_id": "lift_scuttle_latch", "gold": 45, "scraps": 0},
]

## Free non-Leave salvage a fresh {"gold": 0, "scraps": 0} visit can still take,
## with its independently authored settled balance.
const EMPTY_SALVAGE := {
	"v3_warden_ironing_board_barricade": {"choice_id": "salvage_board_tacks", "gold": 0, "scraps": 2},
	"v3_tinker_watering_can_engine": {"choice_id": "gather_spout_springs", "gold": 0, "scraps": 1},
	"v3_scarecrow_coal_scuttle_roost": {"choice_id": "gather_ash_thread", "gold": 0, "scraps": 2},
}

## The Seamstress event has no free non-Leave choice: both are priced.
const SEAMSTRESS_PRICED := ["repair_threader_loop", "buy_eyeloop_wire"]

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []
var catalog_text := ""


func _initialize() -> void:
	_load_catalog()
	if not catalog.is_empty():
		_test_authored_records()
		_test_party_admission()
		_test_funded_receipts()
		_test_insufficient_wallets()
		_test_empty_wallet()
		_test_unknown_and_replay_rejections()
		_check(catalog == catalog_snapshot, "parsed catalog stays unmodified after every claim")
	_check(_read_events_text() == catalog_text and catalog_text != "",
		"authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_ironing_threader_watering_scuttle_hero_events_test: ",
		"PASS" if passed else "FAIL", " (", checks, " checks)")
	quit(0 if passed else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _read_events_text() -> String:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _load_catalog() -> void:
	catalog_text = _read_events_text()
	_check(catalog_text != "", "v3_hero_choice_events.json opens non-empty through FileAccess")
	if catalog_text == "":
		return
	var parser := JSON.new()
	var parse_result := parser.parse(catalog_text)
	_check(parse_result == OK, "v3_hero_choice_events.json parses through JSON")
	if parse_result != OK:
		return
	var data: Variant = parser.data
	_check(data is Dictionary and (data as Dictionary).get("events") is Array,
		"top level is an object with an events array")
	if data is Dictionary and (data as Dictionary).get("events") is Array:
		catalog = (data as Dictionary)["events"]
		catalog_snapshot = catalog.duplicate(true)


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number
	return false


func _wallet_exact_int(wallet: Variant, expected_gold: int, expected_scraps: int) -> bool:
	if not wallet is Dictionary:
		return false
	var dict: Dictionary = wallet
	if dict.size() != 2 or not dict.has("gold") or not dict.has("scraps"):
		return false
	return (
		typeof(dict.get("gold")) == TYPE_INT
		and typeof(dict.get("scraps")) == TYPE_INT
		and int(dict.get("gold")) == expected_gold
		and int(dict.get("scraps")) == expected_scraps
	)


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _offer_id_set(service: RunV3HeroEventOffers) -> Dictionary:
	var ids := {}
	for offer in service.get_offers():
		if offer is Dictionary and (offer as Dictionary).get("id") is String:
			ids[(offer as Dictionary).get("id")] = true
	return ids


func _test_authored_records() -> void:
	for event_id in NEW_EVENTS:
		var expected: Dictionary = NEW_EVENTS[event_id]
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored event record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(
			record.size() == 6
			and record.has("id")
			and record.has("title")
			and record.has("description")
			and record.has("required_hero")
			and record.has("hero_choice_ids")
			and record.has("choices"),
			"authored event has the exact six top-level fields: " + event_id
		)
		_check(record.get("id") == event_id, "authored event keeps its exact ID: " + event_id)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array and raw_hero_ids == expected["hero_choice_ids"],
			"hero_choice_ids is exactly the authored non-Leave pair in order: " + event_id)
		if raw_hero_ids is Array:
			_check(not (raw_hero_ids as Array).has("leave"),
				"hero_choice_ids never lists Leave: " + event_id)
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array and (raw_choices as Array).size() == 3,
			"exactly three authored choices: " + event_id)
		if not raw_choices is Array:
			continue
		var wanted_choices: Array = expected["choices"]
		var authored_order: Array = []
		for choice in raw_choices:
			if not choice is Dictionary:
				_check(false, "every choice is an object: " + event_id)
				continue
			var choice_id: Variant = (choice as Dictionary).get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			_check(not authored_order.has(choice_id), "distinct choice IDs: " + event_id)
			authored_order.append(choice_id)
		var wanted_order: Array = []
		for wanted in wanted_choices:
			wanted_order.append((wanted as Dictionary)["id"])
		_check(authored_order == wanted_order,
			"choices are authored in the brief's order: " + event_id)
		for wanted in wanted_choices:
			var wanted_choice: Dictionary = wanted
			var choice_id: String = wanted_choice["id"]
			var choice_dict: Dictionary = {}
			for candidate in raw_choices:
				if candidate is Dictionary and (candidate as Dictionary).get("id") == choice_id:
					choice_dict = candidate
			_check(not choice_dict.is_empty(), "required choice present: " + event_id + "/" + choice_id)
			if choice_dict.is_empty():
				continue
			_check(
				choice_dict.size() == 3
				and choice_dict.has("id")
				and choice_dict.has("text")
				and choice_dict.has("outcome"),
				"choice has the exact id/text/outcome fields: " + event_id + "/" + choice_id
			)
			_check(choice_dict.get("text") == wanted_choice["text"],
				"exact authored choice text: " + event_id + "/" + choice_id)
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(
				raw_outcome is Dictionary
				and (raw_outcome as Dictionary).size() == 2
				and (raw_outcome as Dictionary).has("gold")
				and (raw_outcome as Dictionary).has("scraps"),
				"outcome has the exact gold/scraps fields: " + event_id + "/" + choice_id
			)
			if raw_outcome is Dictionary:
				var outcome: Dictionary = raw_outcome
				_check(
					_is_integral(outcome.get("gold")) and _is_integral(outcome.get("scraps")),
					"signed integer gold/scraps deltas: " + event_id + "/" + choice_id
				)
				_check(
					int(outcome.get("gold")) == int(wanted_choice["gold"])
					and int(outcome.get("scraps")) == int(wanted_choice["scraps"]),
					"exact authored gold/scraps delta: " + event_id + "/" + choice_id
				)
		var last_choice: Variant = (raw_choices as Array).back()
		if last_choice is Dictionary:
			var leave_outcome: Variant = (last_choice as Dictionary).get("outcome")
			_check(
				(last_choice as Dictionary).get("id") == "leave"
				and leave_outcome is Dictionary
				and int((leave_outcome as Dictionary).get("gold", 1)) == 0
				and int((leave_outcome as Dictionary).get("scraps", 1)) == 0,
				"Leave is the last authored zero-delta choice: " + event_id
			)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(),
			"authored record builds a valid fresh selector: " + event_id)
	for anchor_id in ANCHOR_IDS:
		_check(_matching(anchor_id).size() == 1,
			"earlier anchor still present exactly once: " + anchor_id)


func _test_party_admission() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "four-hero roster party admits a valid offers service")
	if not service.is_valid():
		return
	var offered := _offer_id_set(service)
	for event_id in NEW_EVENTS:
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		_check(offered.has(event_id), "full party offers the new event: " + event_id)
		var visit := service.enter(event_id)
		_check(
			visit != null and visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
			"enter() opens a fresh genuine RunEventChoice visit: " + event_id
		)
		if visit != null:
			_check(visit.get_event().get("id") == event_id,
				"entered visit carries the authored ID: " + event_id)
		var survivor := service.enter_stitched_survivor(event_id, [])
		_check(
			survivor != null and survivor.is_valid() and not survivor.is_claimed(),
			"enter_stitched_survivor() with no losses opens a fresh visit: " + event_id
		)
		if survivor != null:
			_check(survivor.get_event().get("id") == event_id,
				"survivor visit carries the authored ID: " + event_id)
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses survivor entry: " + event_id)
	for event_id in ABSENCE_PARTIES:
		var absence := RunV3HeroEventOffers.new(ABSENCE_PARTIES[event_id])
		_check(absence.is_valid(),
			"valid alternate four-hero party without the required hero admits a service: " + event_id)
		if not absence.is_valid():
			continue
		var absence_offers := _offer_id_set(absence)
		_check(not absence_offers.has(event_id),
			"party without the required hero never offers the new event: " + event_id)
		_check(absence.enter(event_id) == null,
			"party without the required hero refuses entry: " + event_id)
		_check(absence.enter_stitched_survivor(event_id, []) == null,
			"party without the required hero refuses survivor entry: " + event_id)


func _test_funded_receipts() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "funded receipts use a valid offers service")
	if not service.is_valid():
		return
	for event_id in FUNDED_RECEIPTS:
		var receipts: Dictionary = FUNDED_RECEIPTS[event_id]
		for choice_id in receipts:
			var expected_wallet: Array = receipts[choice_id]
			var label: String = event_id + "/" + str(choice_id)
			var visit := service.enter_stitched_survivor(event_id, [])
			_check(visit != null and visit.is_valid(),
				"fresh visit for the funded receipt: " + label)
			if visit == null:
				continue
			var original: Dictionary = visit.get_event()
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview reports ok with the exact event ID: " + label)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == true,
				"funded choice is affordable in preview: " + label)
			var wanted_choice: Dictionary = _expected_choice(event_id, str(choice_id))
			_check(not wanted_choice.is_empty(),
				"funded receipt names an authored choice: " + label)
			if wanted_choice.is_empty():
				continue
			_check(
				_is_integral(entry.get("gold_delta"))
				and _is_integral(entry.get("scraps_delta"))
				and int(entry.get("gold_delta")) == int(wanted_choice["gold"])
				and int(entry.get("scraps_delta")) == int(wanted_choice["scraps"]),
				"funded preview reports the exact authored delta: " + label
			)
			_check(
				_wallet_exact_int(entry.get("wallet"), int(expected_wallet[0]), int(expected_wallet[1])),
				"funded preview projects the exact wallet: " + label
			)
			var result := visit.choose_with_wallet(choice_id, wallet)
			_check(
				result.get("ok") == true
				and result.get("event_id") == event_id
				and result.get("choice_id") == str(choice_id),
				"funded choice commits with exact IDs: " + label
			)
			_check(
				_wallet_exact_int(result.get("wallet"), int(expected_wallet[0]), int(expected_wallet[1])),
				"funded receipt settles the exact wallet " + str(expected_wallet[0]) + "/" + str(expected_wallet[1]) + ": " + label
			)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
				"funded commit never mutates the caller wallet: " + label)
			_check(visit.get_event() == original,
				"funded commit never mutates the visit snapshot: " + label)
			_check(visit.is_claimed() and not visit.is_valid(),
				"funded visit claimed exactly once: " + label)
			var replay := visit.choose_with_wallet(choice_id, wallet)
			_check(
				replay.get("ok") == false
				and replay.get("event_id") == ""
				and replay.get("choice_id") == "",
				"repeated funded claim fails closed with empty IDs: " + label
			)
			_check(_wallet_exact_int(replay.get("wallet"), START_GOLD, START_SCRAPS),
				"repeated funded claim returns the unchanged wallet: " + label)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS),
				"repeated claim never mutates the caller wallet: " + label)


func _expected_choice(event_id: String, choice_id: String) -> Dictionary:
	for wanted in NEW_EVENTS[event_id]["choices"]:
		if (wanted as Dictionary).get("id") == choice_id:
			return wanted
	return {}


func _test_insufficient_wallets() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "insufficient-cost witnesses use a valid offers service")
	if not service.is_valid():
		return
	for witness in INSUFFICIENT_WALLETS:
		var event_id: String = witness["event_id"]
		var choice_id: String = witness["choice_id"]
		var start_gold: int = witness["gold"]
		var start_scraps: int = witness["scraps"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the just-short wallet: " + label)
		if visit == null:
			continue
		var wallet := {"gold": start_gold, "scraps": start_scraps}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true, "just-short preview still reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == false,
			"just-short wallet marks the choice unaffordable: " + label)
		_check(_wallet_exact_int(entry.get("wallet"), start_gold, start_scraps),
			"unaffordable preview keeps the unchanged balance: " + label)
		var denied := visit.choose_with_wallet(choice_id, wallet)
		_check(
			denied.get("ok") == false
			and denied.get("event_id") == ""
			and denied.get("choice_id") == "",
			"just-short claim fails closed with empty IDs: " + label
		)
		_check(_wallet_exact_int(denied.get("wallet"), start_gold, start_scraps),
			"just-short failure returns the unchanged wallet: " + label)
		_check(_wallet_exact_int(wallet, start_gold, start_scraps) and wallet == wallet_before,
			"just-short failure mutates no caller wallet: " + label)
		_check(not visit.is_claimed() and visit.is_valid(),
			"just-short failure consumes no visit claim: " + label)
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(
			leave.get("ok") == true
			and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave",
			"Leave still succeeds on the same just-short visit: " + label
		)
		_check(_wallet_exact_int(leave.get("wallet"), start_gold, start_scraps),
			"just-short Leave changes no wallet: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"just-short Leave claims the visit exactly once: " + label)


func _test_empty_wallet() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "empty-wallet checks use a valid offers service")
	if not service.is_valid():
		return
	var zero := {"gold": 0, "scraps": 0}
	for event_id in EMPTY_SALVAGE:
		var wanted: Dictionary = EMPTY_SALVAGE[event_id]
		var choice_id: String = wanted["choice_id"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh empty-wallet salvage visit: " + label)
		if visit == null:
			continue
		var preview := visit.preview_wallet_choices(zero)
		_check(preview.get("ok") == true, "empty-wallet preview reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == true,
			"free salvage stays affordable with an empty wallet: " + label)
		_check(_wallet_exact_int(entry.get("wallet"), int(wanted["gold"]), int(wanted["scraps"])),
			"free salvage preview projects its exact balance: " + label)
		var result := visit.choose_with_wallet(choice_id, zero)
		_check(
			result.get("ok") == true
			and result.get("event_id") == event_id
			and result.get("choice_id") == choice_id,
			"empty-wallet party still performs the free salvage: " + label
		)
		_check(_wallet_exact_int(result.get("wallet"), int(wanted["gold"]), int(wanted["scraps"])),
			"free salvage settles the exact empty-to-earned wallet: " + label)
		_check(_wallet_exact_int(zero, 0, 0), "free salvage mutates no caller wallet: " + label)
	# The Seamstress event has no free non-Leave option.
	var seamstress_id := "v3_seamstress_silver_needle_threader"
	var seamstress_visit := service.enter_stitched_survivor(seamstress_id, [])
	_check(seamstress_visit != null and seamstress_visit.is_valid(),
		"fresh empty-wallet Seamstress visit")
	if seamstress_visit != null:
		var seamstress_preview := seamstress_visit.preview_wallet_choices(zero)
		_check(seamstress_preview.get("ok") == true, "empty-wallet Seamstress preview reports")
		for choice_id in SEAMSTRESS_PRICED:
			var entry := _preview_choice(seamstress_preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == false,
				"Seamstress has no free non-Leave option: " + str(choice_id))
			_check(_wallet_exact_int(entry.get("wallet"), 0, 0),
				"unaffordable Seamstress preview keeps the empty balance: " + str(choice_id))
			var denied := seamstress_visit.choose_with_wallet(choice_id, zero)
			_check(
				denied.get("ok") == false
				and denied.get("event_id") == ""
				and denied.get("choice_id") == "",
				"empty-wallet Seamstress priced choice fails closed: " + str(choice_id)
			)
			_check(_wallet_exact_int(denied.get("wallet"), 0, 0),
				"empty-wallet Seamstress failure returns the empty wallet: " + str(choice_id))
			_check(_wallet_exact_int(zero, 0, 0),
				"empty-wallet Seamstress failure mutates no caller wallet: " + str(choice_id))
		_check(not seamstress_visit.is_claimed() and seamstress_visit.is_valid(),
			"empty-wallet Seamstress failures consume no visit claim")
		var seamstress_leave := seamstress_visit.choose_with_wallet("leave", zero)
		_check(
			seamstress_leave.get("ok") == true
			and seamstress_leave.get("event_id") == seamstress_id
			and seamstress_leave.get("choice_id") == "leave",
			"empty-wallet Seamstress Leave still succeeds"
		)
		_check(_wallet_exact_int(seamstress_leave.get("wallet"), 0, 0),
			"empty-wallet Seamstress Leave changes no wallet")
	# A fresh Leave must stay affordable on an empty wallet for every new event.
	for event_id in NEW_EVENTS:
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh zero-wallet Leave visit: " + event_id)
		if visit == null:
			continue
		var preview := visit.preview_wallet_choices(zero)
		_check(preview.get("ok") == true, "zero-wallet preview reports: " + event_id)
		var leave_entry := _preview_choice(preview, "leave")
		_check(not leave_entry.is_empty() and leave_entry.get("affordable") == true,
			"fresh Leave stays affordable on an empty wallet: " + event_id)
		var leave := visit.choose_with_wallet("leave", zero)
		_check(
			leave.get("ok") == true
			and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave",
			"zero-wallet Leave succeeds: " + event_id
		)
		_check(_wallet_exact_int(leave.get("wallet"), 0, 0),
			"zero-wallet Leave costs nothing: " + event_id)
		_check(_wallet_exact_int(zero, 0, 0),
			"zero-wallet Leave mutates no caller wallet: " + event_id)
		_check(visit.is_claimed() and not visit.is_valid(),
			"zero-wallet Leave claims exactly once: " + event_id)


func _test_unknown_and_replay_rejections() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "unknown/replay rejections use a valid offers service")
	if not service.is_valid():
		return
	for event_id in NEW_EVENTS:
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the unknown-choice check: " + event_id)
		if visit == null:
			continue
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var original: Dictionary = visit.get_event()
		var unknown := visit.choose_with_wallet("definitely_not_an_authored_choice", wallet)
		_check(
			unknown.get("ok") == false
			and unknown.get("event_id") == ""
			and unknown.get("choice_id") == "",
			"unknown choice fails closed with empty IDs: " + event_id
		)
		_check(_wallet_exact_int(unknown.get("wallet"), START_GOLD, START_SCRAPS),
			"unknown choice returns the unchanged wallet: " + event_id)
		_check(not visit.is_claimed() and visit.is_valid(),
			"unknown choice consumes no visit claim: " + event_id)
		var first_choice: String = NEW_EVENTS[event_id]["hero_choice_ids"][0]
		var settled := visit.choose_with_wallet(first_choice, wallet)
		_check(
			settled.get("ok") == true
			and settled.get("event_id") == event_id
			and settled.get("choice_id") == first_choice,
			"authored choice still settles after an unknown rejection: " + event_id
		)
		_check(visit.is_claimed() and not visit.is_valid(),
			"successful claim latches the visit exactly once: " + event_id)
		var replay := visit.choose_with_wallet(first_choice, wallet)
		_check(
			replay.get("ok") == false
			and replay.get("event_id") == ""
			and replay.get("choice_id") == "",
			"repeated claim fails closed with empty IDs: " + event_id
		)
		_check(_wallet_exact_int(replay.get("wallet"), START_GOLD, START_SCRAPS),
			"repeated claim returns the unchanged wallet: " + event_id)
		_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
			"rejections and claims never mutate the caller wallet: " + event_id)
		_check(visit.get_event() == original,
			"rejections and claims never mutate the selector snapshot: " + event_id)
