extends SceneTree
## Deterministic headless test for the three hero-gated doll-scale teacup,
## comb and saltcellar wallet stories appended to
## data/events/v3_hero_choice_events.json:
## v3_lantern_monk_porcelain_teacup_vigil, v3_rag_duelist_ivory_comb_balcony
## and v3_tinker_copper_saltcellar.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free four-hero
## party admission and RunEventChoice owns each visit's one-claim wallet
## receipt. Every lookup is by authored event/choice ID, never by catalog
## size, order or positional index; the shared catalog may be appended by
## parallel tasks.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## Canonical four-distinct-hero Stitched party containing all three required heroes.
const PARTY := ["lantern_monk", "rag_duelist", "tinker", "warden"]

## Valid four-hero rosters, each missing exactly one required hero.
const ABSENCE_PARTIES := {
	"v3_lantern_monk_porcelain_teacup_vigil": ["warden", "rag_duelist", "tinker", "seamstress"],
	"v3_rag_duelist_ivory_comb_balcony": ["warden", "lantern_monk", "tinker", "seamstress"],
	"v3_tinker_copper_saltcellar": ["warden", "lantern_monk", "rag_duelist", "seamstress"],
}

const START_GOLD := 40
const START_SCRAPS := 4

## Independent task-local expectation table copied from the authored brief;
## never read back from the production catalog.
const NEW_EVENTS := {
	"v3_lantern_monk_porcelain_teacup_vigil": {
		"title": "The Porcelain Teacup Vigil",
		"description": "A chipped bone-porcelain teacup stands taller than the dolls in a moonlit pantry. The Lantern Monk lifts his moth-ringed lamp through the handle while little felt pilgrims shelter beneath the saucer.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_saucer_pilgrims", "buy_wick_braids"],
		"choices": {
			"guide_saucer_pilgrims": {"text": "Guide the saucer pilgrims by lanternlight (earn 20 gold)", "gold": 20, "scraps": 0},
			"buy_wick_braids": {"text": "Pay 18 gold for three braided wick bundles (+3 scraps)", "gold": -18, "scraps": 3},
			"leave": {"text": "Leave the cup shining in the pantry", "gold": 0, "scraps": 0}},
	},
	"v3_rag_duelist_ivory_comb_balcony": {
		"title": "The Ivory Comb Balcony",
		"description": "An ivory comb bridges a crack between ancient floorboards, its teeth dropping into shadow. The Rag Duelist hooks a red velvet cape on one prong and tests the gap with a needle rapier.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["mend_comb_balcony", "gather_cape_tassels"],
		"choices": {
			"mend_comb_balcony": {"text": "Spend 2 scraps binding the comb's broken teeth (earn 27 gold)", "gold": 27, "scraps": -2},
			"gather_cape_tassels": {"text": "Collect loose velvet tassels from the comb (+2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Step away from the ivory teeth", "gold": 0, "scraps": 0}},
	},
	"v3_tinker_copper_saltcellar": {
		"title": "The Copper Saltcellar",
		"description": "A copper saltcellar as high as a watchtower blocks the abandoned dining-room road. The Tinker peers through crooked brass goggles at a jammed clockwork shaker and its scattered screws.",
		"required_hero": "tinker",
		"hero_choice_ids": ["clear_saltcellar_gears", "collect_shaker_screws"],
		"choices": {
			"clear_saltcellar_gears": {"text": "Spend 1 scrap clearing the shaker's gears (earn 25 gold)", "gold": 25, "scraps": -1},
			"collect_shaker_screws": {"text": "Recover two tiny screws from the saltcellar rim (+2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Let the shaker rattle in the dark", "gold": 0, "scraps": 0}},
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_seamstress_splintered_parlour_fan",
	"v3_yarn_ranger_stair_runner_ravine", "v3_button_golem_heart_locket_lift"]

## Independent funded receipt literals for fresh {"gold": 40, "scraps": 4}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_lantern_monk_porcelain_teacup_vigil": {
		"guide_saucer_pilgrims": [60, 4], "buy_wick_braids": [22, 7], "leave": [40, 4]},
	"v3_rag_duelist_ivory_comb_balcony": {
		"mend_comb_balcony": [67, 2], "gather_cape_tassels": [40, 6], "leave": [40, 4]},
	"v3_tinker_copper_saltcellar": {
		"clear_saltcellar_gears": [65, 3], "collect_shaker_screws": [40, 6], "leave": [40, 4]},
}

## Priced choices a starved wallet cannot afford; each check uses a FRESH visit.
const STARVED := [
	{"event_id": "v3_lantern_monk_porcelain_teacup_vigil", "choice_id": "buy_wick_braids", "gold": 17, "scraps": 4},
	{"event_id": "v3_rag_duelist_ivory_comb_balcony", "choice_id": "mend_comb_balcony", "gold": 40, "scraps": 1},
	{"event_id": "v3_tinker_copper_saltcellar", "choice_id": "clear_saltcellar_gears", "gold": 40, "scraps": 0},
]

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
		_test_starved_wallets()
		_test_unknown_and_replay_rejections()
	_check(_read_events_text() == catalog_text and catalog_text != "",
		"authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_teacup_comb_saltcellar_hero_wallet_test: ",
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
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT
		and is_finite(value as float) and floor(value as float) == (value as float))


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
		_check(record.size() == 6 and record.has("id") and record.has("title")
			and record.has("description") and record.has("required_hero")
			and record.has("hero_choice_ids") and record.has("choices"),
			"authored event has the exact six top-level fields: " + event_id)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		var expected_ids: Array = expected["hero_choice_ids"]
		_check(raw_hero_ids is Array and (raw_hero_ids as Array).size() == 2
			and (raw_hero_ids as Array).has(expected_ids[0])
			and (raw_hero_ids as Array).has(expected_ids[1])
			and not (raw_hero_ids as Array).has("leave"),
			"hero_choice_ids equals exactly the authored non-Leave pair: " + event_id)
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array and (raw_choices as Array).size() == 3,
			"exactly three authored choices: " + event_id)
		if not raw_choices is Array:
			continue
		var by_id := {}
		for choice in raw_choices:
			if choice is Dictionary:
				by_id[(choice as Dictionary).get("id")] = choice
		_check(by_id.size() == 3, "three distinct choice IDs: " + event_id)
		var wanted_choices: Dictionary = expected["choices"]
		for choice_id in wanted_choices:
			var wanted: Dictionary = wanted_choices[choice_id]
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + str(choice_id))
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			var outcome: Variant = choice_dict.get("outcome")
			_check(choice_dict.size() == 3 and choice_dict.get("text") == wanted["text"]
				and outcome is Dictionary and (outcome as Dictionary).size() == 2
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and _is_integral((outcome as Dictionary).get("gold"))
				and _is_integral((outcome as Dictionary).get("scraps"))
				and int((outcome as Dictionary).get("gold")) == int(wanted["gold"])
				and int((outcome as Dictionary).get("scraps")) == int(wanted["scraps"]),
				"exact authored choice text and signed integer outcome: " + event_id + "/" + str(choice_id))
		if by_id.has("leave"):
			var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
			_check(leave_outcome is Dictionary
				and int((leave_outcome as Dictionary).get("gold", 1)) == 0
				and int((leave_outcome as Dictionary).get("scraps", 1)) == 0,
				"Leave is the authored zero-delta choice: " + event_id)
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
		_check(visit != null and visit is RunEventChoice and visit.is_valid() and not visit.is_claimed()
			and visit.get_event().get("id") == event_id,
			"enter() opens a fresh genuine RunEventChoice visit: " + event_id)
		var survivor := service.enter_stitched_survivor(event_id, [])
		_check(survivor != null and survivor.is_valid() and not survivor.is_claimed()
			and survivor.get_event().get("id") == event_id,
			"enter_stitched_survivor() with no losses opens a fresh visit: " + event_id)
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses survivor entry: " + event_id)
	for event_id in ABSENCE_PARTIES:
		var absence := RunV3HeroEventOffers.new(ABSENCE_PARTIES[event_id])
		_check(absence.is_valid(),
			"valid alternate four-hero party without the required hero admits a service: " + event_id)
		if not absence.is_valid():
			continue
		_check(not _offer_id_set(absence).has(event_id),
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
			_check(visit != null and visit.is_valid(), "fresh visit for the funded receipt: " + label)
			if visit == null:
				continue
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview reports ok with the exact event ID: " + label)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == true
				and _wallet_exact_int(entry.get("wallet"), int(expected_wallet[0]), int(expected_wallet[1])),
				"funded preview projects the exact affordable wallet: " + label)
			var result := visit.choose_with_wallet(choice_id, wallet)
			_check(result.get("ok") == true and result.get("event_id") == event_id
				and result.get("choice_id") == str(choice_id)
				and _wallet_exact_int(result.get("wallet"), int(expected_wallet[0]), int(expected_wallet[1])),
				"funded receipt settles the exact wallet " + str(expected_wallet[0]) + "/" + str(expected_wallet[1]) + ": " + label)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
				"funded commit never mutates the caller wallet: " + label)
			_check(visit.is_claimed() and not visit.is_valid(),
				"funded visit claimed exactly once: " + label)


func _test_starved_wallets() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "starved-wallet checks use a valid offers service")
	if not service.is_valid():
		return
	for branch in STARVED:
		var event_id: String = branch["event_id"]
		var choice_id: String = branch["choice_id"]
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the starved branch: " + label)
		if visit == null:
			continue
		var wallet := {"gold": int(branch["gold"]), "scraps": int(branch["scraps"])}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true, "starved preview still reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == false
			and _wallet_exact_int(entry.get("wallet"), int(branch["gold"]), int(branch["scraps"])),
			"priced choice is unaffordable in preview with the unchanged balance: " + label)
		var denied := visit.choose_with_wallet(choice_id, wallet)
		_check(denied.get("ok") == false and denied.get("event_id") == "" and denied.get("choice_id") == ""
			and _wallet_exact_int(denied.get("wallet"), int(branch["gold"]), int(branch["scraps"])),
			"starved priced choice fails closed and returns the unchanged wallet: " + label)
		_check(_wallet_exact_int(wallet, int(branch["gold"]), int(branch["scraps"])) and wallet == wallet_before,
			"starved failure mutates no caller wallet: " + label)
		_check(not visit.is_claimed() and visit.is_valid(),
			"starved failure consumes no visit claim: " + label)
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave"
			and _wallet_exact_int(leave.get("wallet"), int(branch["gold"]), int(branch["scraps"])),
			"Leave still succeeds on the same starved visit with no wallet change: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"starved Leave claims the visit exactly once: " + label)


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
		_check(unknown.get("ok") == false and unknown.get("event_id") == "" and unknown.get("choice_id") == ""
			and _wallet_exact_int(unknown.get("wallet"), START_GOLD, START_SCRAPS)
			and not visit.is_claimed() and visit.is_valid(),
			"unknown choice fails closed, returns the unchanged wallet and consumes no claim: " + event_id)
		var first_choice: String = NEW_EVENTS[event_id]["hero_choice_ids"][0]
		var settled := visit.choose_with_wallet(first_choice, wallet)
		_check(settled.get("ok") == true and settled.get("event_id") == event_id
			and settled.get("choice_id") == first_choice and visit.is_claimed() and not visit.is_valid(),
			"authored choice still settles after an unknown rejection and latches the visit: " + event_id)
		var replay := visit.choose_with_wallet(first_choice, wallet)
		_check(replay.get("ok") == false and replay.get("event_id") == "" and replay.get("choice_id") == ""
			and _wallet_exact_int(replay.get("wallet"), START_GOLD, START_SCRAPS),
			"repeated claim fails closed and returns the unchanged wallet: " + event_id)
		_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before
			and visit.get_event() == original,
			"rejections and claims never mutate the caller wallet or the selector snapshot: " + event_id)
