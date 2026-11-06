extends SceneTree
## Deterministic headless test for the three hero-gated doll-house wallet
## stories appended to data/events/v3_hero_choice_events.json:
## v3_lantern_monk_belljar_moth_shelter, v3_rag_duelist_satin_glove_box
## and v3_tinker_biscuit_tin_gear_lift.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free four-hero
## party admission and RunEventChoice owns each visit's one-claim wallet
## receipt. Every lookup is by authored event/choice ID, never by catalog
## size, order or positional index; the shared catalog may be appended by
## parallel tasks.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## A genuine Stitched four-hero party; every ID is a canonical roster hero.
const PARTY := ["lantern_monk", "rag_duelist", "tinker", "warden"]
## A valid opposite four-hero party containing none of the required heroes.
const OPPOSITE_PARTY := ["seamstress", "scarecrow", "yarn_ranger", "button_golem"]

const START_GOLD := 50
const START_SCRAPS := 5

## Independent task-local expectation table copied from the authored brief;
## never read back from the production catalog.
const NEW_EVENTS := {
	"v3_lantern_monk_belljar_moth_shelter": {
		"title": "The Bell-Jar Moth Shelter",
		"description": "Beneath an inverted glass bell as high as a wardrobe, small stuffed moths crowd around a dying wick; the Lantern Monk lifts his glowing patchwork lantern and peers through the darkened glass.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["lift_bell_for_silk", "rewick_shelter_lamp"],
		"choices": {
			"lift_bell_for_silk": {"text": "Lift the bell with the lantern pole and gather loose silk (+2 scraps)", "gold": 0, "scraps": 2},
			"rewick_shelter_lamp": {"text": "Spend 2 scraps to rewick the keeper's lamp (earn 27 gold)", "gold": 27, "scraps": -2},
			"leave": {"text": "Let the moths sleep beneath their glass roof", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_satin_glove_box": {
		"title": "The Satin Glove Box",
		"description": "A gigantic oxblood satin glove hangs from a dresser hook over the doll-sized path; the Rag Duelist's needle rapier holds open its cuff while his patched cape flutters against a brass clasp.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["buy_satin_cord", "seal_glove_cuff"],
		"choices": {
			"buy_satin_cord": {"text": "Pay 15 gold for three bundles of satin cord (+3 scraps)", "gold": -15, "scraps": 3},
			"seal_glove_cuff": {"text": "Spend 1 scrap resealing the glove cuff (earn 22 gold)", "gold": 22, "scraps": -1},
			"leave": {"text": "Lower the cuff and bow to the silent glove", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_biscuit_tin_gear_lift": {
		"title": "The Biscuit-Tin Gear Lift",
		"description": "A dented biscuit tin towers over a narrow skirting-board trail; brass gears lift its heavy lid while the Tinker's mismatched goggles gleam above her overstuffed scrap backpack.",
		"required_hero": "tinker",
		"hero_choice_ids": ["collect_loose_gear_teeth", "repair_tin_ratchet"],
		"choices": {
			"collect_loose_gear_teeth": {"text": "Gather loose brass gear teeth from the sill (+1 scrap)", "gold": 0, "scraps": 1},
			"repair_tin_ratchet": {"text": "Spend 2 scraps repairing the lid ratchet (earn 30 gold)", "gold": 30, "scraps": -2},
			"leave": {"text": "Leave the great tin lid to rattle in the dark", "gold": 0, "scraps": 0},
		},
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_lantern_monk_moth_vigil", "v3_rag_duelist_needle_fair",
	"v3_tinker_clockwork_wagon", "v3_button_golem_porcelain_button_scale"]

## Independent funded receipt literals for fresh {"gold": 50, "scraps": 5}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_lantern_monk_belljar_moth_shelter": {
		"lift_bell_for_silk": [50, 7],
		"rewick_shelter_lamp": [77, 3],
		"leave": [50, 5],
	},
	"v3_rag_duelist_satin_glove_box": {
		"buy_satin_cord": [35, 8],
		"seal_glove_cuff": [72, 4],
		"leave": [50, 5],
	},
	"v3_tinker_biscuit_tin_gear_lift": {
		"collect_loose_gear_teeth": [50, 6],
		"repair_tin_ratchet": [80, 3],
		"leave": [50, 5],
	},
}

## Starved fail-closed branches; each starts on a FRESH visit.
const STARVED_BRANCHES := [
	{"event_id": "v3_lantern_monk_belljar_moth_shelter", "choice_id": "rewick_shelter_lamp", "gold": 50, "scraps": 1},
	{"event_id": "v3_rag_duelist_satin_glove_box", "choice_id": "buy_satin_cord", "gold": 14, "scraps": 5},
	{"event_id": "v3_rag_duelist_satin_glove_box", "choice_id": "seal_glove_cuff", "gold": 50, "scraps": 0},
	{"event_id": "v3_tinker_biscuit_tin_gear_lift", "choice_id": "repair_tin_ratchet", "gold": 50, "scraps": 1},
]

## Free choices a zero-wallet party can still perform, and the wholly priced
## Satin Glove event that must have no affordable non-Leave option.
const ZERO_WALLET_FREE := {
	"v3_lantern_monk_belljar_moth_shelter": {"choice_id": "lift_bell_for_silk", "gold": 0, "scraps": 2},
	"v3_tinker_biscuit_tin_gear_lift": {"choice_id": "collect_loose_gear_teeth", "gold": 0, "scraps": 1},
}

const SATIN_EVENT_ID := "v3_rag_duelist_satin_glove_box"
const SELECTION_DRAWS := 64
const SELECTION_SEED := 1793946348

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_text := ""


func _initialize() -> void:
	_load_catalog()
	if not catalog.is_empty():
		_test_authored_records()
		_test_party_admission()
		_test_funded_receipts()
		_test_starved_rejections()
		_test_zero_wallet_choices()
		_test_unknown_and_replay_rejections()
		_test_seeded_actionable_selection()
	_check(_read_events_text() == catalog_text and catalog_text != "",
		"authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_belljar_glovebox_biscuit_tin_hero_wallet_events_test: ",
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
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array and (raw_hero_ids as Array).size() == 2,
			"hero_choice_ids lists exactly two choices: " + event_id)
		var hero_set := {}
		if raw_hero_ids is Array:
			for listed in raw_hero_ids:
				_check(listed is String, "hero_choice_ids entry is a string: " + event_id)
				hero_set[listed] = true
			var expected_ids: Array = expected["hero_choice_ids"]
			_check(
				hero_set.size() == 2
				and hero_set.has(expected_ids[0])
				and hero_set.has(expected_ids[1])
				and not hero_set.has("leave"),
				"hero_choice_ids equals exactly the authored non-Leave pair: " + event_id
			)
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array and (raw_choices as Array).size() == 3,
			"exactly three authored choices: " + event_id)
		if not raw_choices is Array:
			continue
		var by_id := {}
		for choice in raw_choices:
			if not choice is Dictionary:
				_check(false, "every choice is an object: " + event_id)
				continue
			var choice_id: Variant = (choice as Dictionary).get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			_check(not by_id.has(choice_id), "distinct choice IDs: " + event_id)
			by_id[choice_id] = choice
		var wanted_choices: Dictionary = expected["choices"]
		_check(by_id.size() == wanted_choices.size(), "no unstated choice IDs: " + event_id)
		for choice_id in wanted_choices:
			var wanted: Dictionary = wanted_choices[choice_id]
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + str(choice_id))
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(
					choice_dict.size() == 3
					and choice_dict.has("id")
					and choice_dict.has("text")
					and choice_dict.has("outcome"),
					"choice has the exact id/text/outcome fields: " + event_id + "/" + str(choice_id)
				)
			_check(choice_dict.get("text") == wanted["text"],
					"exact authored choice text: " + event_id + "/" + str(choice_id))
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(
					raw_outcome is Dictionary
					and (raw_outcome as Dictionary).size() == 2
					and (raw_outcome as Dictionary).has("gold")
					and (raw_outcome as Dictionary).has("scraps"),
					"outcome has the exact gold/scraps fields: " + event_id + "/" + str(choice_id)
				)
			if raw_outcome is Dictionary:
				var outcome: Dictionary = raw_outcome
				_check(
					_is_integral(outcome.get("gold")) and _is_integral(outcome.get("scraps")),
					"signed integer gold/scraps deltas: " + event_id + "/" + str(choice_id)
				)
				_check(
					int(outcome.get("gold")) == int(wanted["gold"])
						and int(outcome.get("scraps")) == int(wanted["scraps"]),
					"exact authored gold/scraps delta: " + event_id + "/" + str(choice_id)
				)
			if by_id.has("leave"):
				var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
				_check(
					leave_outcome is Dictionary
					and int((leave_outcome as Dictionary).get("gold", 1)) == 0
					and int((leave_outcome as Dictionary).get("scraps", 1)) == 0,
					"Leave is the authored zero-delta choice: " + event_id
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
		_check(offered.has(event_id), "full party offers the new event: " + event_id)
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(
			visit != null and visit.is_valid() and not visit.is_claimed(),
			"enter_stitched_survivor() with no losses opens a fresh visit: " + event_id
		)
		if visit != null:
			_check(visit.get_event().get("id") == event_id,
				"entered visit carries the authored ID: " + event_id)
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses survivor entry: " + event_id)
	var opposite := RunV3HeroEventOffers.new(OPPOSITE_PARTY)
	_check(opposite.is_valid(), "opposite four-hero party is a valid service")
	if not opposite.is_valid():
		return
	var opposite_offers := _offer_id_set(opposite)
	for event_id in NEW_EVENTS:
		_check(not opposite_offers.has(event_id),
			"opposite party never offers the new event: " + event_id)
		_check(opposite.enter_stitched_survivor(event_id, []) == null,
			"opposite party refuses survivor entry: " + event_id)


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
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview reports ok with the exact event ID: " + label)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == true,
				"funded choice is affordable in preview: " + label)
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
			_check(visit.is_claimed() and not visit.is_valid(),
				"funded visit claimed exactly once: " + label)


func _test_starved_rejections() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "starved rejections use a valid offers service")
	if not service.is_valid():
		return
	for branch in STARVED_BRANCHES:
		var event_id: String = branch["event_id"]
		var choice_id: String = branch["choice_id"]
		var branch_gold: int = int(branch["gold"])
		var branch_scraps: int = int(branch["scraps"])
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the starved branch: " + label)
		if visit == null:
			continue
		var wallet := {"gold": branch_gold, "scraps": branch_scraps}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true, "starved preview still reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == false,
			"starved paid choice is unaffordable in preview: " + label)
		var denied := visit.choose_with_wallet(choice_id, wallet)
		_check(
			denied.get("ok") == false
			and denied.get("event_id") == ""
			and denied.get("choice_id") == "",
			"starved paid choice fails closed with empty IDs: " + label
		)
		_check(_wallet_exact_int(denied.get("wallet"), branch_gold, branch_scraps),
			"starved failure returns the unchanged wallet: " + label)
		_check(_wallet_exact_int(wallet, branch_gold, branch_scraps) and wallet == wallet_before,
			"starved failure changes no caller wallet: " + label)
		_check(not visit.is_claimed() and visit.is_valid(),
			"starved failure consumes no visit claim: " + label)
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(
			leave.get("ok") == true
			and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave",
			"Leave still succeeds on the same starved visit: " + label
		)
		_check(_wallet_exact_int(leave.get("wallet"), branch_gold, branch_scraps),
			"starved Leave changes no wallet: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"starved Leave claims the visit exactly once: " + label)


func _test_zero_wallet_choices() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "zero-wallet checks use a valid offers service")
	if not service.is_valid():
		return
	var zero := {"gold": 0, "scraps": 0}
	for event_id in ZERO_WALLET_FREE:
		var wanted: Dictionary = ZERO_WALLET_FREE[event_id]
		var choice_id: String = wanted["choice_id"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh zero-wallet visit: " + label)
		if visit == null:
			continue
		var preview := visit.preview_wallet_choices(zero)
		_check(preview.get("ok") == true, "zero-wallet preview reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == true,
			"free choice stays affordable with an empty wallet: " + label)
		var result := visit.choose_with_wallet(choice_id, zero)
		_check(
			result.get("ok") == true
			and result.get("event_id") == event_id
			and result.get("choice_id") == choice_id,
			"zero-wallet party still performs the free choice: " + label
		)
		_check(_wallet_exact_int(result.get("wallet"), int(wanted["gold"]), int(wanted["scraps"])),
			"free choice settles the exact empty-to-earned wallet: " + label)
		_check(_wallet_exact_int(zero, 0, 0), "free choice mutates no caller wallet: " + label)
	# The Satin Glove has no affordable non-Leave option for a zero wallet.
	var satin := service.enter_stitched_survivor(SATIN_EVENT_ID, [])
	_check(satin != null and satin.is_valid(), "fresh zero-wallet visit: " + SATIN_EVENT_ID)
	if satin == null:
		return
	var preview := satin.preview_wallet_choices(zero)
	_check(preview.get("ok") == true, "zero-wallet satin preview reports: " + SATIN_EVENT_ID)
	for priced_id in ["buy_satin_cord", "seal_glove_cuff"]:
		var priced := _preview_choice(preview, priced_id)
		_check(not priced.is_empty() and priced.get("affordable") == false,
			"priced satin choice is unaffordable on an empty wallet: " + SATIN_EVENT_ID + "/" + priced_id)
	var leave_entry := _preview_choice(preview, "leave")
	_check(not leave_entry.is_empty() and leave_entry.get("affordable") == true,
		"only Leave remains affordable on the satin event: " + SATIN_EVENT_ID)
	var denied := satin.choose_with_wallet("buy_satin_cord", zero)
	_check(
		denied.get("ok") == false
		and denied.get("event_id") == ""
		and denied.get("choice_id") == "",
		"zero-wallet priced satin choice fails closed: " + SATIN_EVENT_ID
	)
	_check(_wallet_exact_int(denied.get("wallet"), 0, 0),
		"zero-wallet satin failure returns the unchanged wallet: " + SATIN_EVENT_ID)
	_check(not satin.is_claimed() and satin.is_valid(),
		"zero-wallet satin failure consumes no visit claim: " + SATIN_EVENT_ID)


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


func _test_seeded_actionable_selection() -> void:
	var injected_events: Array = []
	for event_id in NEW_EVENTS:
		var matches := _matching(event_id)
		if matches.size() == 1:
			injected_events.append(matches[0])
	_check(injected_events.size() == 3,
		"the three canonical records are available for an injected subset")
	var service := RunV3HeroEventOffers.new(PARTY, {"events": injected_events})
	_check(service.is_valid(), "injected three-record subset admits a valid service")
	if not service.is_valid():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = SELECTION_SEED
	var zero := {"gold": 0, "scraps": 0}
	var seen := {}
	for draw in SELECTION_DRAWS:
		var selection := service.select_actionable_event_with_preview(rng, [], zero)
		_check(selection.get("ok") == true, "seeded actionable selection succeeds: draw " + str(draw))
		if not selection.get("ok", false):
			return
		var selected: Dictionary = selection.get("event")
		seen[selected.get("id")] = true
		var preview: Dictionary = selection.get("preview")
		_check(preview.get("event_id") == selected.get("id"),
			"selection preview carries the selected event: draw " + str(draw))
	_check(seen.has("v3_lantern_monk_belljar_moth_shelter"),
		"the free Bell-Jar story is possible with a zero wallet")
	_check(seen.has("v3_tinker_biscuit_tin_gear_lift"),
		"the free Biscuit-Tin story is possible with a zero wallet")
	_check(not seen.has(SATIN_EVENT_ID),
		"the wholly unaffordable Satin Glove is excluded from selection")
