extends SceneTree
## Deterministic headless test for the three hero-gated doll-scale corridor wallet
## stories appended to data/events/v3_hero_choice_events.json:
## v3_lantern_monk_iron_snuffbox_vigil, v3_yarn_ranger_copper_speaking_tube and
## v3_rag_duelist_stopped_pocket_watch.
##
## Catalog data only: RunV3HeroEventOffers performs the scene-free four-hero
## party admission and RunEventChoice owns each visit's one-claim wallet
## receipt. Every lookup is by authored event/choice ID, never by catalog size,
## order or positional index; parallel tasks may append to this shared catalog.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

## Canonical four-distinct-hero Stitched party containing all three required heroes.
const PARTY := ["lantern_monk", "yarn_ranger", "rag_duelist", "warden"]

## Valid four-hero rosters missing exactly one required hero, each replacing it
## with tinker.
const ABSENCE_PARTIES := {
	"v3_lantern_monk_iron_snuffbox_vigil": ["tinker", "yarn_ranger", "rag_duelist", "warden"],
	"v3_yarn_ranger_copper_speaking_tube": ["lantern_monk", "tinker", "rag_duelist", "warden"],
	"v3_rag_duelist_stopped_pocket_watch": ["lantern_monk", "yarn_ranger", "tinker", "warden"],
}

const START_GOLD := 50
const START_SCRAPS := 5
const RNG_SEED := 7319

## Independent task-local expectation table copied from the authored brief;
## never read back from the production catalog.
const NEW_EVENTS := {
	"v3_lantern_monk_iron_snuffbox_vigil": {
		"title": "The Iron Snuffbox Vigil",
		"description": "An iron snuffbox as wide as a doorway stands ajar between two skirting boards. Inside, a small soot-cloth keeper shelters a dying amber wick; the Lantern Monk's great lantern catches tiny stitches moving around the hinge.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["refit_snuffbox_lid", "purchase_wick_bundle"],
		"choices": {
			"refit_snuffbox_lid": {"text": "Bind the lid with spare thread; take the keeper's gold", "gold": 28, "scraps": -2},
			"purchase_wick_bundle": {"text": "Buy the keeper's bundle of bright wicks", "gold": -17, "scraps": 3},
			"leave": {"text": "Leave the little light under its iron roof", "gold": 0, "scraps": 0},
		},
	},
	"v3_yarn_ranger_copper_speaking_tube": {
		"title": "The Copper Speaking Tube",
		"description": "An enormous dented speaking tube crosses a gap in the floorboards, its copper mouthpiece turned toward the dark. The Yarn Ranger loops yarn bolas round the joint while muffled button-eyed voices murmur from the far wall.",
		"required_hero": "yarn_ranger",
		"hero_choice_ids": ["rewind_tube_cord", "gather_tube_ferrules"],
		"choices": {
			"rewind_tube_cord": {"text": "Rebind the cracked tube; accept gold from the voices", "gold": 29, "scraps": -2},
			"gather_tube_ferrules": {"text": "Gather loose brass sleeves and thread", "gold": 0, "scraps": 2},
			"leave": {"text": "Let the whispers travel without an answer", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_stopped_pocket_watch": {
		"title": "The Stopped Pocket Watch",
		"description": "A giant silver pocket watch hangs over the narrow way like a locked moon. Its motionless hands trap a little caped watchmaker; the Rag Duelist raises a ragged sleeve to shield the spring as the lid trembles.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["buy_watch_springs", "salvage_watch_escapement"],
		"choices": {
			"buy_watch_springs": {"text": "Buy the freed watchmaker's spare springs", "gold": -19, "scraps": 3},
			"salvage_watch_escapement": {"text": "Unpin the escapement; collect the watchmaker's gold", "gold": 23, "scraps": -1},
			"leave": {"text": "Slip beneath the silent hands", "gold": 0, "scraps": 0},
		},
	},
}

## Named earlier anchors that must survive the append; presence only, never an
## ordered list or a catalog total.
const ANCHOR_IDS := ["v3_warden_shield_menders", "v3_seamstress_mourning_veil_pulley",
	"v3_button_golem_coat_hanger_bridge"]

## Independent funded receipt literals for fresh {"gold": 50, "scraps": 5}
## visits; never derived from the authored deltas above.
const FUNDED_RECEIPTS := {
	"v3_lantern_monk_iron_snuffbox_vigil": {
		"refit_snuffbox_lid": [78, 3],
		"purchase_wick_bundle": [33, 8],
		"leave": [50, 5],
	},
	"v3_yarn_ranger_copper_speaking_tube": {
		"rewind_tube_cord": [79, 3],
		"gather_tube_ferrules": [50, 7],
		"leave": [50, 5],
	},
	"v3_rag_duelist_stopped_pocket_watch": {
		"buy_watch_springs": [31, 8],
		"salvage_watch_escapement": [73, 4],
		"leave": [50, 5],
	},
}

## Priced choices a deliberately short wallet cannot fund; each check starts on
## a FRESH visit and must still be able to Leave afterwards.
const UNAFFORDABLE_VISITS := [
	{"event_id": "v3_lantern_monk_iron_snuffbox_vigil", "choice_id": "refit_snuffbox_lid", "gold": 50, "scraps": 1},
	{"event_id": "v3_lantern_monk_iron_snuffbox_vigil", "choice_id": "purchase_wick_bundle", "gold": 16, "scraps": 5},
	{"event_id": "v3_yarn_ranger_copper_speaking_tube", "choice_id": "rewind_tube_cord", "gold": 50, "scraps": 1},
	{"event_id": "v3_rag_duelist_stopped_pocket_watch", "choice_id": "buy_watch_springs", "gold": 18, "scraps": 5},
	{"event_id": "v3_rag_duelist_stopped_pocket_watch", "choice_id": "salvage_watch_escapement", "gold": 50, "scraps": 0},
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
		_test_unaffordable_visits()
		_test_unknown_and_replay_rejections()
		_test_global_rng_untouched()
	_check(_read_events_text() == catalog_text and catalog_text != "",
		"authored catalog file text unchanged after use")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_stitched_snuffbox_tube_watch_hero_choice_events_test: ",
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
		_check(matches.size() == 1, "exactly one authored event record (unique ID): " + event_id)
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
		_check(by_id.has("leave"), "authored Leave choice present: " + event_id)
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
		_check(offered.has(event_id), "full party offers the new event once: " + event_id)
		var visit := service.enter(event_id)
		_check(
			visit != null and visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
			"enter() opens a fresh unclaimed RunEventChoice visit: " + event_id
		)
		if visit != null:
			_check(visit.get_event().get("id") == event_id,
				"entered visit carries the authored ID: " + event_id)
		var survivor := service.enter_stitched_survivor(event_id, [])
		_check(
			survivor != null and survivor.is_valid() and not survivor.is_claimed(),
			"enter_stitched_survivor() with no losses opens a fresh unclaimed visit: " + event_id
		)
		if survivor != null:
			_check(survivor.get_event().get("id") == event_id,
				"survivor visit carries the authored ID: " + event_id)
		var required_hero: String = NEW_EVENTS[event_id]["required_hero"]
		_check(service.enter_stitched_survivor(event_id, [required_hero]) == null,
			"a LOST required hero refuses survivor entry: " + event_id)
		var unrelated_loss := _unrelated_lost_id(required_hero)
		var unrelated_visit := service.enter_stitched_survivor(event_id, [unrelated_loss])
		_check(
			unrelated_visit != null and unrelated_visit.is_valid() and not unrelated_visit.is_claimed(),
			"losing an unrelated party member still admits survivor entry (" + unrelated_loss + "): " + event_id
		)
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


func _unrelated_lost_id(required_hero: String) -> String:
	for hero_id in PARTY:
		if hero_id != required_hero:
			return hero_id
	return ""


func _test_funded_receipts() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "funded receipts use a valid offers service")
	if not service.is_valid():
		return
	for event_id in FUNDED_RECEIPTS:
		var receipts: Dictionary = FUNDED_RECEIPTS[event_id]
		var deltas: Dictionary = NEW_EVENTS[event_id]["choices"]
		for choice_id in receipts:
			var expected_wallet: Array = receipts[choice_id]
			var wanted_delta: Dictionary = deltas[choice_id]
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
				entry.get("gold_delta") == int(wanted_delta["gold"])
				and entry.get("scraps_delta") == int(wanted_delta["scraps"]),
				"funded preview lists the exact deltas: " + label
			)
			_check(
				_wallet_exact_int(entry.get("wallet"), int(expected_wallet[0]), int(expected_wallet[1])),
				"funded preview projects the exact wallet: " + label
			)
			_check(not visit.is_claimed() and visit.is_valid(),
				"preview never claims the funded visit: " + label)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
				"preview never mutates the caller wallet: " + label)
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


func _test_unaffordable_visits() -> void:
	var service := RunV3HeroEventOffers.new(PARTY)
	_check(service.is_valid(), "unaffordable checks use a valid offers service")
	if not service.is_valid():
		return
	for branch in UNAFFORDABLE_VISITS:
		var event_id: String = branch["event_id"]
		var choice_id: String = branch["choice_id"]
		var start_gold: int = int(branch["gold"])
		var start_scraps: int = int(branch["scraps"])
		var label: String = event_id + "/" + choice_id
		var visit := service.enter_stitched_survivor(event_id, [])
		_check(visit != null and visit.is_valid(), "fresh visit for the unaffordable branch: " + label)
		if visit == null:
			continue
		var wallet := {"gold": start_gold, "scraps": start_scraps}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var preview := visit.preview_wallet_choices(wallet)
		_check(preview.get("ok") == true, "short-wallet preview still reports: " + label)
		var entry := _preview_choice(preview, choice_id)
		_check(not entry.is_empty() and entry.get("affordable") == false,
			"priced choice is unaffordable in preview on the short wallet: " + label)
		_check(_wallet_exact_int(entry.get("wallet"), start_gold, start_scraps),
			"unaffordable preview keeps the unchanged balance: " + label)
		var denied := visit.choose_with_wallet(choice_id, wallet)
		_check(
			denied.get("ok") == false
			and denied.get("event_id") == ""
			and denied.get("choice_id") == "",
			"short-wallet priced choice fails closed with empty IDs: " + label
		)
		_check(_wallet_exact_int(denied.get("wallet"), start_gold, start_scraps),
			"short-wallet failure returns the unchanged wallet: " + label)
		_check(_wallet_exact_int(wallet, start_gold, start_scraps) and wallet == wallet_before,
			"short-wallet failure mutates no caller wallet: " + label)
		_check(not visit.is_claimed() and visit.is_valid(),
			"short-wallet failure consumes no visit claim: " + label)
		var leave := visit.choose_with_wallet("leave", wallet)
		_check(
			leave.get("ok") == true
			and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave",
			"free Leave still succeeds on the rejected visit: " + label
		)
		_check(_wallet_exact_int(leave.get("wallet"), start_gold, start_scraps),
			"rejected-visit Leave changes no wallet: " + label)
		_check(visit.is_claimed() and not visit.is_valid(),
			"rejected-visit Leave claims the visit exactly once: " + label)


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
		var hero_ids: Array = NEW_EVENTS[event_id]["hero_choice_ids"]
		var first_choice: String = hero_ids[0]
		var second_choice: String = hero_ids[1]
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
		var second := visit.choose_with_wallet(second_choice, wallet)
		_check(
			second.get("ok") == false
			and second.get("event_id") == ""
			and second.get("choice_id") == "",
			"a second different choice on the claimed visit fails closed: " + event_id
		)
		_check(_wallet_exact_int(second.get("wallet"), START_GOLD, START_SCRAPS),
			"second different choice returns the unchanged wallet: " + event_id)
		_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
			"rejections and claims never mutate the caller wallet: " + event_id)
		_check(visit.get_event() == original,
			"rejections and claims never mutate the selector snapshot: " + event_id)


## The wallet-only services must never draw from the global RNG: replaying the
## same deterministic preview/choose/leave series under one seed must leave the
## next global randi() value identical.
func _test_global_rng_untouched() -> void:
	seed(RNG_SEED)
	var baseline: int = randi()
	seed(RNG_SEED)
	var service := RunV3HeroEventOffers.new(PARTY)
	for event_id in NEW_EVENTS:
		var visit := service.enter_stitched_survivor(event_id, [])
		if visit == null:
			continue
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		visit.preview_wallet_choices(wallet)
		visit.choose_with_wallet("definitely_not_an_authored_choice", wallet)
		visit.choose_with_wallet("leave", wallet)
		visit.choose_with_wallet("leave", wallet)
		service.enter(event_id)
		service.enter_stitched_survivor(event_id, [])
	_check(randi() == baseline,
		"wallet preview/choose/enter series consumes no global RNG")
