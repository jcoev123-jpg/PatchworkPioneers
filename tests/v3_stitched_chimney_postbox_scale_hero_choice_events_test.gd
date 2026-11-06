extends SceneTree
## Deterministic headless test for the three hero-gated doll-house wallet
## trades appended to data/events/v3_hero_choice_events.json:
## v3_scarecrow_ash_chimney_crow_nest, v3_yarn_ranger_midnight_postbox_spool
## and v3_button_golem_porcelain_button_scale.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free party
## admission for a genuine four-hero Stitched roster party and RunEventChoice
## owns each visit's one-claim wallet receipt. Every lookup is by authored
## event/choice ID, never by catalog size, catalog order or a positional index;
## the shared catalog may be appended by parallel tasks.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## A genuine Stitched four-hero party; every ID is a canonical roster hero.
const PARTY := ["scarecrow", "yarn_ranger", "button_golem", "warden"]
const SUBSTITUTE_HERO := "seamstress"

const START_GOLD := 60
const START_SCRAPS := 6

## Independent task-local expectation table copied from the authored brief;
## it is never read back from the production catalog.
const NEW_EVENTS := {
	"v3_scarecrow_ash_chimney_crow_nest": {
		"title": "The Ash-Chimney Crow Nest",
		"description": "A giant patched chimney rises from the floorboards; straw-paper crow nests fill its cracked flue while the Scarecrow's black companion taps a brass button inside the ash.",
		"required_hero": "scarecrow",
		"hero_choice_ids": ["send_crow_up_flue", "bind_cracked_damper"],
		"choices": {
			"send_crow_up_flue": {"text": "Send the crow after loose flue thread (gain 2 scraps)", "gold": 0, "scraps": 2},
			"bind_cracked_damper": {"text": "Spend 2 scraps binding the damper (earn 28 gold)", "gold": 28, "scraps": -2},
			"leave": {"text": "Leave the little nests undisturbed", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_midnight_postbox_spool": {
		"title": "The Midnight Postbox Spool",
		"description": "A towering brass letter box leans among woollen hedge walls; the Yarn Ranger's knotted bolas hold its spring flap open as candlelit envelopes tremble inside.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["buy_moonpost_braid", "rewind_postbox_flap"],
		"choices": {
			"buy_moonpost_braid": {"text": "Pay 18 gold for three bundles of moonpost braid (+3 scraps)", "gold": -18, "scraps": 3},
			"rewind_postbox_flap": {"text": "Spend 1 scrap rewinding the spring flap (earn 23 gold)", "gold": 23, "scraps": -1},
			"leave": {"text": "Let the sealed letters whisper to themselves", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_porcelain_button_scale": {
		"title": "The Porcelain Button Scale",
		"description": "A cracked bone-cream dinner plate hangs as the pan of an immense button scale; only the Button Golem's broad stuffed fists can steady its tarnished brass weights.",
		"required_hero": "button_golem",
		"hero_choice_ids": ["steady_brass_scale", "collect_cracked_scale_shanks"],
		"choices": {
			"steady_brass_scale": {"text": "Spend 2 scraps steadying the heavy scale (earn 30 gold)", "gold": 30, "scraps": -2},
			"collect_cracked_scale_shanks": {"text": "Gather fallen button shanks (+1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Let the porcelain pan settle in silence", "gold": 0, "scraps": 0},
		},
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_button_golem_staircase_carillon",
	"v3_yarn_ranger_moonbolas_windharp"]

## Independent funded receipt literals for fresh {"gold": 60, "scraps": 6}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_scarecrow_ash_chimney_crow_nest": {
		"send_crow_up_flue": [60, 8],
		"bind_cracked_damper": [88, 4],
		"leave": [60, 6],
	},
	"v3_yarn_ranger_midnight_postbox_spool": {
		"buy_moonpost_braid": [42, 9],
		"rewind_postbox_flap": [83, 5],
		"leave": [60, 6],
	},
	"v3_button_golem_porcelain_button_scale": {
		"steady_brass_scale": [90, 4],
		"collect_cracked_scale_shanks": [60, 7],
		"leave": [60, 6],
	},
}

## Starved fail-closed branches; each starts on a FRESH visit.
const STARVED_BRANCHES := [
	{"event_id": "v3_scarecrow_ash_chimney_crow_nest", "choice_id": "bind_cracked_damper", "gold": 60, "scraps": 1},
	{"event_id": "v3_yarn_ranger_midnight_postbox_spool", "choice_id": "buy_moonpost_braid", "gold": 17, "scraps": 6},
	{"event_id": "v3_yarn_ranger_midnight_postbox_spool", "choice_id": "rewind_postbox_flap", "gold": 60, "scraps": 0},
	{"event_id": "v3_button_golem_porcelain_button_scale", "choice_id": "steady_brass_scale", "gold": 60, "scraps": 1},
]

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []
var catalog_text := ""


func _initialize() -> void:
	_load_catalog()
	_test_authored_records()
	_test_party_admission()
	_test_funded_receipts()
	_test_starved_rejections()
	_test_unknown_and_replay_rejections()
	_check(catalog == catalog_snapshot, "shared event catalog unchanged across all test flows")
	var reloaded := _read_events_text()
	_check(reloaded != "" and reloaded == catalog_text, "authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_chimney_postbox_scale_hero_choice_events_test: ", "PASS" if passed else "FAIL", " (", checks, " checks)")
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
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "top level is a JSON object")
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("events")
	_check(list is Array, "top level has an events array")
	if not list is Array:
		return
	catalog = list
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
	var gold: Variant = dict.get("gold")
	var scraps: Variant = dict.get("scraps")
	return (
		typeof(gold) == TYPE_INT
		and typeof(scraps) == TYPE_INT
		and int(gold) == expected_gold
		and int(scraps) == expected_scraps
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
			"authored event has exact top-level keys: " + event_id
		)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array and (raw_hero_ids as Array).size() == 2,
			"hero_choice_ids lists exactly two choices: " + event_id)
		if raw_hero_ids is Array:
			var listed_ids: Array = raw_hero_ids
			var listed_set := {}
			for listed in listed_ids:
				_check(listed is String and not (listed as String).strip_edges().is_empty(),
					"hero_choice_ids entry is a nonblank string: " + event_id)
				if listed is String:
					_check(not listed_set.has(listed), "hero_choice_ids entries are distinct: " + event_id)
					listed_set[listed] = true
			var expected_ids: Array = expected["hero_choice_ids"]
			for wanted_id in expected_ids:
				_check(listed_set.has(wanted_id),
					"hero_choice_ids names its required choice: " + event_id + "/" + str(wanted_id))
			_check(not listed_set.has("leave"), "hero_choice_ids excludes the Leave choice: " + event_id)
			var expected_non_leave := {}
			for expected_choice_id in expected["choices"]:
				if expected_choice_id != "leave":
					expected_non_leave[expected_choice_id] = true
			_check(listed_set == expected_non_leave,
				"hero_choice_ids equals exactly the authored non-Leave choices: " + event_id)
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
			var choice_dict: Dictionary = choice
			var choice_id: Variant = choice_dict.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			_check(not by_id.has(choice_id), "distinct choice IDs: " + event_id)
			by_id[choice_id] = choice_dict
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
				"choice has exact id/text/outcome keys: " + event_id + "/" + str(choice_id)
			)
			_check(choice_dict.get("text") == wanted["text"],
				"exact authored choice text: " + event_id + "/" + str(choice_id))
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(
				raw_outcome is Dictionary
				and (raw_outcome as Dictionary).size() == 2
				and (raw_outcome as Dictionary).has("gold")
				and (raw_outcome as Dictionary).has("scraps"),
				"outcome has exact gold/scraps keys: " + event_id + "/" + str(choice_id)
			)
			if raw_outcome is Dictionary:
				var outcome: Dictionary = raw_outcome
				var raw_gold: Variant = outcome.get("gold")
				var raw_scraps: Variant = outcome.get("scraps")
				_check(_is_integral(raw_gold) and _is_integral(raw_scraps),
					"signed integer gold/scraps deltas: " + event_id + "/" + str(choice_id))
				if _is_integral(raw_gold) and _is_integral(raw_scraps):
					_check(
						int(raw_gold) == int(wanted["gold"]) and int(raw_scraps) == int(wanted["scraps"]),
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
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
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
			"enter() opens a fresh valid visit: " + event_id
		)
		if visit != null:
			_check(visit.get_event().get("id") == event_id,
				"entered visit carries the authored ID: " + event_id)
		var survivor := service.enter_stitched_survivor(event_id, [])
		_check(
			survivor != null and survivor is RunEventChoice and survivor.is_valid() and not survivor.is_claimed(),
			"enter_stitched_survivor() with no losses opens a fresh visit: " + event_id
		)
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		var refused := service.enter_stitched_survivor(event_id, [required_hero])
		_check(refused == null,
			"a LOST required hero refuses survivor entry: " + event_id)
	# Omitting one required hero (replaced by the seamstress) excludes only
	# that event; the other two new events remain party-eligible.
	for event_id in NEW_EVENTS:
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		var substitute: Array = []
		for hero in PARTY:
			substitute.append(SUBSTITUTE_HERO if hero == required_hero else hero)
		var reduced := RunV3HeroEventOffers.new(substitute)
		_check(reduced.is_valid(), "substitute four-hero party is a valid service: " + event_id)
		if not reduced.is_valid():
			continue
		var reduced_offers := _offer_id_set(reduced)
		_check(not reduced_offers.has(event_id),
			"omitting the required hero excludes its event: " + event_id)
		_check(reduced.enter(event_id) == null,
			"omitting the required hero refuses enter(): " + event_id)
		_check(reduced.enter_stitched_survivor(event_id, []) == null,
			"omitting the required hero refuses survivor entry: " + event_id)
		for other_id in NEW_EVENTS:
			if other_id != event_id:
				_check(reduced_offers.has(other_id),
					"substitute party still offers the other new event: " + other_id)


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
			var visit := service.enter(event_id)
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
		var visit := service.enter(event_id)
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
		_check(_wallet_exact_int(wallet, branch_gold, branch_scraps) and wallet == wallet_before,
			"starved Leave mutates no caller wallet: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"starved Leave claims the visit exactly once: " + label)


func _test_unknown_and_replay_rejections() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "unknown/replay rejections use a valid offers service")
	if not service.is_valid():
		return
	for event_id in NEW_EVENTS:
		var visit := service.enter(event_id)
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
		_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
			"unknown choice mutates no caller wallet: " + event_id)
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
			"repeated claim mutates no caller wallet: " + event_id)
		_check(visit.get_event() == original,
			"rejections and claims never mutate the selector snapshot: " + event_id)
