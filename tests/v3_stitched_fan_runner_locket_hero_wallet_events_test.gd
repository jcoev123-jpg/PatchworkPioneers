extends SceneTree
## Deterministic headless test for the three hero-gated doll-scale fan,
## stair-runner and locket wallet stories appended to
## data/events/v3_hero_choice_events.json:
## v3_seamstress_splintered_parlour_fan, v3_yarn_ranger_stair_runner_ravine
## and v3_button_golem_heart_locket_lift.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free four-hero
## party admission and RunEventChoice owns each visit's one-claim wallet
## receipt. Every lookup is by authored event/choice ID, never by catalog
## size, order or positional index; the shared catalog may be appended by
## parallel tasks.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## Canonical four-distinct-hero Stitched party containing all three required heroes.
const PARTY := ["warden", "seamstress", "yarn_ranger", "button_golem"]

## Valid four-hero rosters missing exactly one required hero.
const ABSENCE_PARTIES := {
	"v3_seamstress_splintered_parlour_fan": ["warden", "yarn_ranger", "button_golem", "tinker"],
	"v3_yarn_ranger_stair_runner_ravine": ["warden", "seamstress", "button_golem", "tinker"],
	"v3_button_golem_heart_locket_lift": ["warden", "seamstress", "yarn_ranger", "tinker"],
}

const START_GOLD := 40
const START_SCRAPS := 3

## Independent task-local expectation table copied from the authored brief;
## never read back from the production catalog.
const NEW_EVENTS := {
	"v3_seamstress_splintered_parlour_fan": {
		"title": "The Splintered Parlour Fan",
		"description": "A room-high folding fan blocks the doll-sized parlour path. The Seamstress raises her giant silver needle, drawing one red thread through its split velvet binding.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["mend_fan_ribs", "collect_fan_thread"],
		"choices": {
			"mend_fan_ribs": {"text": "Spend 2 scraps rejoining the great fan ribs (earn 28 gold)", "gold": 28, "scraps": -2},
			"collect_fan_thread": {"text": "Wind the loose crimson binding into two bundles (+2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Pass beneath the fan's broken velvet folds", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_stair_runner_ravine": {
		"title": "The Stair-Runner Ravine",
		"description": "A moss-green stair carpet has fallen into a steep doll-scale ravine. The Yarn Ranger's oversized bow and wool bolas catch a fraying tassel above the drop.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["gather_runner_knots", "retie_runner_edge"],
		"choices": {
			"gather_runner_knots": {"text": "Reel in two useful tassel knots (+2 scraps)", "gold": 0, "scraps": 2},
			"retie_runner_edge": {"text": "Spend 1 scrap fastening the carpet ledge (earn 24 gold)", "gold": 24, "scraps": -1},
			"leave": {"text": "Follow the skirting board away from the drop", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_heart_locket_lift": {
		"title": "The Heart-Locket Lift",
		"description": "A giant oxblood velvet heart locket hangs above a narrow floorboard crossing. The Button Golem wedges its round brass-button fists beneath the clasp while a tiny courier taps from inside.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["lift_locket_clasp", "buy_locket_rivets"],
		"choices": {
			"lift_locket_clasp": {"text": "Raise the heavy clasp and free the courier (earn 23 gold)", "gold": 23, "scraps": 0},
			"buy_locket_rivets": {"text": "Pay 18 gold for three loose brass fittings (+3 scraps)", "gold": -18, "scraps": 3},
			"leave": {"text": "Let the locked heart hang in the dark", "gold": 0, "scraps": 0},
		},
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_seamstress_mourning_veil_pulley",
	"v3_scarecrow_heirloom_seed_envelope"]

## Independent funded receipt literals for fresh {"gold": 40, "scraps": 3}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_seamstress_splintered_parlour_fan": {
		"mend_fan_ribs": [68, 1],
		"collect_fan_thread": [40, 5],
		"leave": [40, 3],
	},
	"v3_yarn_ranger_stair_runner_ravine": {
		"gather_runner_knots": [40, 5],
		"retie_runner_edge": [64, 2],
		"leave": [40, 3],
	},
	"v3_button_golem_heart_locket_lift": {
		"lift_locket_clasp": [63, 3],
		"buy_locket_rivets": [22, 6],
		"leave": [40, 3],
	},
}

## Priced choices an empty {"gold": 0, "scraps": 0} wallet cannot afford;
## each check starts on a FRESH visit.
const EMPTY_UNAFFORDABLE := [
	{"event_id": "v3_seamstress_splintered_parlour_fan", "choice_id": "mend_fan_ribs"},
	{"event_id": "v3_yarn_ranger_stair_runner_ravine", "choice_id": "retie_runner_edge"},
	{"event_id": "v3_button_golem_heart_locket_lift", "choice_id": "buy_locket_rivets"},
]

## Choices an empty wallet can still perform, with their settled balances.
const EMPTY_AFFORDABLE := {
	"v3_seamstress_splintered_parlour_fan": {"choice_id": "collect_fan_thread", "gold": 0, "scraps": 2},
	"v3_yarn_ranger_stair_runner_ravine": {"choice_id": "gather_runner_knots", "gold": 0, "scraps": 2},
	"v3_button_golem_heart_locket_lift": {"choice_id": "lift_locket_clasp", "gold": 23, "scraps": 0},
}

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
		_test_empty_wallet()
		_test_unknown_and_replay_rejections()
	_check(_read_events_text() == catalog_text and catalog_text != "",
		"authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_fan_runner_locket_hero_wallet_events_test: ",
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
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses survivor entry: " + event_id)
	for event_id in ABSENCE_PARTIES:
		var absence := RunV3HeroEventOffers.new(ABSENCE_PARTIES[event_id])
		_check(absence.is_valid(), "valid alternate four-hero party without the required hero admits a service: " + event_id)
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
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview reports ok with the exact event ID: " + label)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == true,
				"funded choice is affordable in preview: " + label)
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
			_check(visit.is_claimed() and not visit.is_valid(),
				"funded visit claimed exactly once: " + label)


func _test_empty_wallet() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "empty-wallet checks use a valid offers service")
	if not service.is_valid():
		return
	var zero := {"gold": 0, "scraps": 0}
	for branch in EMPTY_UNAFFORDABLE:
		var event_id: String = branch["event_id"]
		var choice_id: String = branch["choice_id"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the unaffordable branch: " + label)
		if visit == null:
			continue
		var wallet := {"gold": 0, "scraps": 0}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true, "empty-wallet preview still reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == false,
			"priced choice is unaffordable in preview on an empty wallet: " + label)
		_check(_wallet_exact_int(entry.get("wallet"), 0, 0),
			"unaffordable preview keeps the unchanged empty balance: " + label)
		var denied := visit.choose_with_wallet(choice_id, wallet)
		_check(
			denied.get("ok") == false
			and denied.get("event_id") == ""
			and denied.get("choice_id") == "",
			"empty-wallet priced choice fails closed with empty IDs: " + label
		)
		_check(_wallet_exact_int(denied.get("wallet"), 0, 0),
			"empty-wallet failure returns the unchanged wallet: " + label)
		_check(_wallet_exact_int(wallet, 0, 0) and wallet == wallet_before,
			"empty-wallet failure mutates no caller wallet: " + label)
		_check(not visit.is_claimed() and visit.is_valid(),
			"empty-wallet failure consumes no visit claim: " + label)
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(
			leave.get("ok") == true
			and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave",
			"Leave still succeeds on the same empty-wallet visit: " + label
		)
		_check(_wallet_exact_int(leave.get("wallet"), 0, 0),
			"empty-wallet Leave changes no wallet: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"empty-wallet Leave claims the visit exactly once: " + label)
	for event_id in EMPTY_AFFORDABLE:
		var wanted: Dictionary = EMPTY_AFFORDABLE[event_id]
		var choice_id: String = wanted["choice_id"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh empty-wallet visit: " + label)
		if visit == null:
			continue
		var preview := visit.preview_wallet_choices(zero)
		_check(preview.get("ok") == true, "empty-wallet preview reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == true,
			"free choice stays affordable with an empty wallet: " + label)
		var result := visit.choose_with_wallet(choice_id, zero)
		_check(
			result.get("ok") == true
			and result.get("event_id") == event_id
			and result.get("choice_id") == choice_id,
			"empty-wallet party still performs the free choice: " + label
		)
		_check(_wallet_exact_int(result.get("wallet"), int(wanted["gold"]), int(wanted["scraps"])),
			"free choice settles the exact empty-to-earned wallet: " + label)
		_check(_wallet_exact_int(zero, 0, 0), "free choice mutates no caller wallet: " + label)
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
