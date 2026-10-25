extends SceneTree
## Deterministic headless test for the five hero-specific v3 roadside Events in
## data/events/v3_hero_choice_events.json.
##
## This catalog is authored data only: every event names its future party hero
## in `required_hero` and lists its two non-Leave hero choices in
## `hero_choice_ids`, but no live party filter is wired here. The existing
## one-use RunEventChoice only validates/settles the authored wallet choices, so
## these checks cover exact authored metadata and wallet receipts without
## asserting any party-aware eligibility.
##
## Lookups are by authored event/choice ID, never by catalog size, catalog order,
## a global ordered ID list or a positional event index.

const EVENTS_PATH := "res://data/events/v3_hero_choice_events.json"

const START_GOLD := 30
const START_SCRAPS := 3

## Independent task-local mapping of the five authored records. It is never read
## from the production catalog, so a missing field or a reworded choice is caught.
const EVENTS := {
	"v3_warden_shield_menders": {
		"title": "The Shield-Menders",
		"description": "At a shield repair queue, a huge patched shield props up the town gate.",
		"required_hero": "warden",
		"hero_choice_ids": ["hold_the_gate", "sell_spare_rivets"],
		"choices": {
			"hold_the_gate": {"text": "Stand watch by the giant shield (+2 scraps)", "gold": 0, "scraps": 2},
			"sell_spare_rivets": {"text": "Trade a spare shield rivet (spend 1 scrap; gain 17 gold)", "gold": 17, "scraps": -1},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_seamstress_thread_cart": {
		"title": "Scarlet Thread Cart",
		"description": "The seamstress finds a wagon knotted with red-thread pennants and giant needles.",
		"required_hero": "seamstress",
		"hero_choice_ids": ["sew_bunting", "buy_red_thread"],
		"choices": {
			"sew_bunting": {"text": "Sew the red pennant (spend 1 scrap; gain 18 gold)", "gold": 18, "scraps": -1},
			"buy_red_thread": {"text": "Buy a red-thread bundle (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_tinker_clockwork_wagon": {
		"title": "The Clockwork Wagon",
		"description": "A clockwork trader's wagon ticks under a load of crooked buttons and gears.",
		"required_hero": "tinker",
		"hero_choice_ids": ["recover_gears", "fix_ratchet"],
		"choices": {
			"recover_gears": {"text": "Gather the fallen gears (+1 scrap)", "gold": 0, "scraps": 1},
			"fix_ratchet": {"text": "Repair the wagon ratchet (spend 2 scraps; gain 28 gold)", "gold": 28, "scraps": -2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_lantern_monk_moth_vigil": {
		"title": "Moth Vigil",
		"description": "A warm patchwork lantern gathers moths beside a candlelit cloth shrine.",
		"required_hero": "lantern_monk",
		"hero_choice_ids": ["guide_moths", "buy_wax"],
		"choices": {
			"guide_moths": {"text": "Guide the moths by lantern light (+2 scraps)", "gold": 0, "scraps": 2},
			"buy_wax": {"text": "Buy lantern wax (spend 12 gold; gain 2 scraps)", "gold": -12, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_needle_fair": {
		"title": "The Needle Fair",
		"description": "A caped duelist holds a friendly fencing fair with a long thin needle rapier.",
		"required_hero": "rag_duelist",
		"hero_choice_ids": ["duel_for_purse", "trade_ribbon"],
		"choices": {
			"duel_for_purse": {"text": "Win the friendly fencing purse (+20 gold)", "gold": 20, "scraps": 0},
			"trade_ribbon": {"text": "Buy two red ribbon bundles (spend 10 gold; gain 2 scraps)", "gold": -10, "scraps": 2},
			"leave": {"text": "Leave without exchanging anything", "gold": 0, "scraps": 0},
		},
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_snapshot: Array = []


func _initialize() -> void:
	_test_catalog_content()
	_test_deep_copy_independence()
	_test_commit_matrix()
	_test_preview_forecasts()
	_test_priced_rejections_and_recovery()
	_test_unoffered_choice_ids()
	_test_hero_metadata()
	_test_fixed_seed_replay()
	_check(catalog == catalog_snapshot, "shared event catalog unchanged across all test flows")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_hero_choice_events_test: ", "PASS" if passed else "FAIL", " (", checks, " checks)")
	quit(0 if passed else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _expected(event_id: String) -> Dictionary:
	return EVENTS[event_id]


func _expected_choices(event_id: String) -> Dictionary:
	return (_expected(event_id)["choices"] as Dictionary)


func _choice_ids(record: Dictionary) -> Dictionary:
	var out := {}
	for choice in record.get("choices", []):
		if choice is Dictionary and choice.get("id") is String:
			out[choice.get("id")] = true
	return out


func _signed(choice_id: String, delta: Dictionary) -> String:
	return choice_id + "(" + str(int(delta["gold"])) + "g/" + str(int(delta["scraps"])) + "s)"


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


func _wallet_shape_ok(result: Dictionary) -> bool:
	return (
		result.size() == 4
		and result.has("ok")
		and result.has("event_id")
		and result.has("choice_id")
		and result.has("wallet")
		and result.get("wallet") is Dictionary
	)


func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return (
			is_finite(number)
			and floor(number) == number
			and number <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and number >= -RunEventChoice.MAX_SAFE_FLOAT_INT
		)
	return false


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _other_choice_id(expected_choices: Dictionary, choice_id: String) -> String:
	for candidate in expected_choices:
		var candidate_id: String = candidate
		if candidate_id != choice_id:
			return candidate_id
	return choice_id


func _test_catalog_content() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_hero_choice_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(text != "", "v3_hero_choice_events.json is non-empty")
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "v3_hero_choice_events.json parses through JSON")
	var data: Variant = parser.data if parse_result == OK else null
	_check(data is Dictionary, "top level is a JSON object")
	if not data is Dictionary:
		return
	var list: Variant = (data as Dictionary).get("events")
	_check(list is Array, "top level has an events array")
	if not list is Array:
		return
	_check(not (list as Array).is_empty(), "events array is non-empty")
	catalog = list
	catalog_snapshot = catalog.duplicate(true)
	for entry in catalog:
		_check(entry is Dictionary, "every event record is an object")
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored event record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = _expected(event_id)
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
		_check(record.get("id") == event_id, "authored id: " + event_id)
		_check(record.get("title") == expected["title"], "authored title: " + event_id)
		_check(record.get("description") == expected["description"], "authored description: " + event_id)
		_check(record.get("required_hero") == expected["required_hero"], "authored required_hero: " + event_id)
		var raw_hero: Variant = record.get("required_hero")
		_check(raw_hero is String and not (raw_hero as String).strip_edges().is_empty(),
			"required_hero is a nonblank string: " + event_id)

		# Event-level hero metadata: exactly the two authored non-Leave choices.
		var raw_hero_ids: Variant = record.get("hero_choice_ids")
		_check(raw_hero_ids is Array, "hero_choice_ids is an array: " + event_id)
		if raw_hero_ids is Array:
			var listed_ids: Array = raw_hero_ids
			_check(listed_ids.size() == 2, "hero_choice_ids lists exactly two choices: " + event_id)
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
			for expected_choice_id in _expected_choices(event_id):
				if expected_choice_id != "leave":
					expected_non_leave[expected_choice_id] = true
			_check(listed_set == expected_non_leave,
				"hero_choice_ids equals exactly the authored non-Leave choices: " + event_id)

		# Authored choices, keyed by ID (never by array position).
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array, "choices array present: " + event_id)
		if not raw_choices is Array:
			continue
		var choices: Array = raw_choices
		_check(choices.size() == 3, "exactly three authored choices: " + event_id)
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_dict: Dictionary = choice
			var choice_id: Variant = choice_dict.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"nonblank string choice ID: " + event_id)
			if not choice_id is String:
				continue
			_check(not by_id.has(choice_id), "distinct choice IDs: " + event_id)
			by_id[choice_id] = choice_dict
		var wanted_choices: Dictionary = _expected_choices(event_id)
		_check(by_id.size() == wanted_choices.size(), "no unstated choice IDs: " + event_id)
		for choice_id in wanted_choices:
			var wanted: Dictionary = wanted_choices[choice_id]
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + choice_id)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(
				choice_dict.size() == 3
				and choice_dict.has("id")
				and choice_dict.has("text")
				and choice_dict.has("outcome"),
				"choice has exact id/text/outcome keys: " + event_id + "/" + choice_id
			)
			_check(choice_dict.get("text") == wanted["text"],
				"exact authored choice text: " + event_id + "/" + choice_id)
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(raw_outcome is Dictionary, "choice outcome is an object: " + event_id + "/" + choice_id)
			if not raw_outcome is Dictionary:
				continue
			var outcome: Dictionary = raw_outcome
			_check(
				outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
				"outcome has exact gold/scraps keys: " + event_id + "/" + choice_id
			)
			var raw_gold: Variant = outcome.get("gold")
			var raw_scraps: Variant = outcome.get("scraps")
			_check(_is_integral(raw_gold) and _is_integral(raw_scraps),
				"outcome gold/scraps are integral: " + event_id + "/" + choice_id)
			if _is_integral(raw_gold) and _is_integral(raw_scraps):
				_check(
					int(raw_gold) == int(wanted["gold"]) and int(raw_scraps) == int(wanted["scraps"]),
					"exact authored gold/scraps delta " + _signed(str(choice_id), wanted)
						+ ": " + event_id + "/" + choice_id
				)
		if by_id.has("leave"):
			var leave_choice: Dictionary = by_id["leave"]
			var leave_outcome: Variant = leave_choice.get("outcome")
			_check(leave_outcome is Dictionary
				and int(leave_outcome.get("gold", 1)) == 0
				and int(leave_outcome.get("scraps", 1)) == 0,
				"Leave is the authored zero-delta choice: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.is_valid(), "authored record builds a valid selector: " + event_id)
		_check(not service.is_claimed(), "fresh selector is unclaimed: " + event_id)
		_check(service.get_event() == record, "selector keeps the authored hero metadata: " + event_id)


func _test_deep_copy_independence() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		if matches.size() != 1:
			continue
		var caller_record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = caller_record.duplicate(true)
		var service := RunEventChoice.new(caller_record)
		_check(service.is_valid() and not service.is_claimed(), "fresh selector for detach checks: " + event_id)
		var snapshot := service.get_event()
		_check(snapshot == original, "detached selector copy equals the authored input: " + event_id)
		snapshot["title"] = "mutated snapshot title"
		snapshot["required_hero"] = "mutated_hero"
		(snapshot["hero_choice_ids"] as Array).append("injected_choice")
		var snapshot_choices: Array = snapshot["choices"]
		var snapshot_first: Dictionary = snapshot_choices[0]
		snapshot_first["text"] = "mutated snapshot text"
		(snapshot_first["outcome"] as Dictionary)["gold"] = 5000
		_check(service.get_event() == original, "returned snapshot mutation stays isolated: " + event_id)
		caller_record["description"] = "mutated caller description"
		(caller_record["hero_choice_ids"] as Array).append("injected_choice")
		(caller_record["choices"] as Array).append(
			{"id": "sneaky", "text": "An appended caller choice", "outcome": {"gold": 0, "scraps": 0}})
		_check(service.get_event() == original, "caller mutation stays isolated from the selector: " + event_id)
		var live_matches := _matching(event_id)
		_check(live_matches.size() == 1 and live_matches[0] == original,
			"mutations never reach the shared catalog record: " + event_id)
		var result := service.choose_with_wallet("leave", {"gold": START_GOLD, "scraps": START_SCRAPS})
		_check(_wallet_shape_ok(result)
			and result.get("ok") == true
			and result.get("event_id") == event_id
			and result.get("choice_id") == "leave"
			and _wallet_exact_int(result.get("wallet"), START_GOLD, START_SCRAPS),
			"isolated selector still settles the untouched Leave choice: " + event_id)


func _test_commit_matrix() -> void:
	var case_index := 0
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "commit matrix has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var original: Dictionary = authored_record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		for choice_id in expected_choices:
			case_index += 1
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var caller_record: Dictionary = authored_record.duplicate(true)
			var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var local_rng := RandomNumberGenerator.new()
			local_rng.seed = 81000 + case_index
			var local_state: int = local_rng.state
			var expected_global := _rng_start(81000 + case_index)
			var service := RunEventChoice.new(caller_record)
			_check(service.is_valid() and not service.is_claimed(),
				"fresh valid selector before commit: " + label)
			var result := service.choose_with_wallet(choice_id, wallet)
			var expected_gold: int = START_GOLD + int(delta["gold"])
			var expected_scraps: int = START_SCRAPS + int(delta["scraps"])
			_check(_wallet_shape_ok(result), "commit returns the 4-key wallet shape: " + label)
			_check(result.get("ok") == true, "commit succeeds: " + label)
			_check(result.get("event_id") == event_id and result.get("choice_id") == choice_id,
				"commit returns exact event and choice IDs: " + label)
			_check(_wallet_exact_int(result.get("wallet"), expected_gold, expected_scraps),
				"commit settles the exact wallet " + str(START_GOLD) + "/" + str(START_SCRAPS)
					+ " -> " + str(expected_gold) + "/" + str(expected_scraps) + ": " + label)
			_check(_wallet_exact_int(wallet, START_GOLD, START_SCRAPS) and wallet == wallet_before,
				"commit never mutates the caller wallet: " + label)
			_check(caller_record == original, "commit never mutates the caller event: " + label)
			_check(service.get_event() == original, "commit never mutates the selector snapshot: " + label)
			_check(service.is_claimed() and not service.is_valid(),
				"commit latches exactly one claim: " + label)
			_check(service.preview_wallet_choices(wallet) == {"ok": false, "event_id": "", "choices": []},
				"a claimed selector offers no further preview: " + label)
			# Returned state is fully detached from the selector and later receipts.
			var returned_wallet: Dictionary = result["wallet"]
			returned_wallet["gold"] = 999
			returned_wallet["scraps"] = 999
			result["ok"] = false
			var replay_id := _other_choice_id(expected_choices, str(choice_id))
			var replay := service.choose_with_wallet(replay_id, {"gold": expected_gold, "scraps": expected_scraps})
			_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false,
				"a second choice after success is rejected: " + label)
			_check(replay.get("event_id") == "" and replay.get("choice_id") == "",
				"a rejected replay returns empty IDs: " + label)
			_check(_wallet_exact_int(replay.get("wallet"), expected_gold, expected_scraps),
				"a rejected replay returns a detached unchanged wallet: " + label)
			(replay["wallet"] as Dictionary)["gold"] = 0
			_check(service.is_claimed() and not service.is_valid() and service.get_event() == original,
				"replay attempts keep the claim latched and the snapshot intact: " + label)
			_check(local_rng.state == local_state and randi() == expected_global,
				"commit, detach and replay spend no RNG: " + label)


func _test_preview_forecasts() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "preview has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = 81100
		var local_state: int = local_rng.state
		var expected_global := _rng_start(81100)
		var service := RunEventChoice.new(record)
		var preview := service.preview_wallet_choices(wallet)
		_check(preview.size() == 3 and preview.get("ok") == true and preview.get("event_id") == event_id,
			"preview returns ok with the exact event ID: " + event_id)
		var entries: Array = preview.get("choices", [])
		_check(entries.size() == expected_choices.size(),
			"preview has one entry per authored choice: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var entry := _preview_choice(preview, str(choice_id))
			_check(not entry.is_empty(), "preview names the authored choice: " + label)
			_check(entry.size() == 5 and entry.get("choice_id") == choice_id,
				"preview entry has the exact 5-key shape: " + label)
			_check(typeof(entry.get("gold_delta")) == TYPE_INT
				and typeof(entry.get("scraps_delta")) == TYPE_INT
				and entry.get("gold_delta") == int(delta["gold"])
				and entry.get("scraps_delta") == int(delta["scraps"]),
				"preview shows the exact signed authored deltas: " + label)
			_check(entry.get("affordable") == true, "preview marks the funded choice affordable: " + label)
			_check(_wallet_exact_int(entry.get("wallet"),
				START_GOLD + int(delta["gold"]), START_SCRAPS + int(delta["scraps"])),
				"preview projects the exact funded wallet: " + label)
		_check(service.is_valid() and not service.is_claimed()
			and service.get_event() == original and record == original and wallet == wallet_before,
			"preview claims nothing and mutates no input: " + event_id)
		var again := service.preview_wallet_choices(wallet)
		_check(again == preview, "repeated preview is deterministic: " + event_id)
		# Mutating one preview entry must not leak into the selector or its siblings.
		var first_entry: Dictionary = entries[0]
		var first_id: String = first_entry["choice_id"]
		var sibling_id := _other_choice_id(expected_choices, first_id)
		var sibling_delta: Dictionary = expected_choices[sibling_id]
		(first_entry["wallet"] as Dictionary)["gold"] = -500
		first_entry["gold_delta"] = -500
		var sibling := _preview_choice(preview, sibling_id)
		_check(_wallet_exact_int(sibling.get("wallet"),
			START_GOLD + int(sibling_delta["gold"]), START_SCRAPS + int(sibling_delta["scraps"])),
			"preview wallets are detached from sibling entries: " + event_id)
		_check(service.preview_wallet_choices(wallet) == again
			and service.is_valid() and not service.is_claimed()
			and service.get_event() == original and wallet == wallet_before,
			"mutating preview results never reaches the selector: " + event_id)

		# Zero wallet: priced choices stay unaffordable with an unchanged forecast;
		# free/gain choices remain affordable and forecast only their own delta.
		var zero_wallet := {"gold": 0, "scraps": 0}
		var zero_preview := service.preview_wallet_choices(zero_wallet)
		_check(zero_preview.get("ok") == true and zero_preview.get("event_id") == event_id,
			"zero-wallet preview stays readable: " + event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var entry := _preview_choice(zero_preview, str(choice_id))
			_check(not entry.is_empty() and entry.get("affordable") == (not priced),
				"zero-wallet affordability matches the authored cost: " + event_id + "/" + str(choice_id))
			var projected_gold: int = 0 if priced else int(delta["gold"])
			var projected_scraps: int = 0 if priced else int(delta["scraps"])
			_check(_wallet_exact_int(entry.get("wallet"), projected_gold, projected_scraps),
				"zero-wallet forecast is unchanged for priced choices and exact for free ones: "
					+ event_id + "/" + str(choice_id))
		_check(service.preview_wallet_choices(null) == {"ok": false, "event_id": "", "choices": []}
			and service.is_valid() and not service.is_claimed(),
			"a malformed preview wallet fails closed without claiming: " + event_id)
		_check(randi() == expected_global and local_rng.state == local_state,
			"previews and detach probes spend no RNG: " + event_id)


func _test_priced_rejections_and_recovery() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "priced rejection has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var authored_record: Dictionary = matches[0]
		var original: Dictionary = authored_record.duplicate(true)
		var expected_choices: Dictionary = _expected_choices(event_id)
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var priced: bool = int(delta["gold"]) < 0 or int(delta["scraps"]) < 0
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var service := RunEventChoice.new(authored_record.duplicate(true))
			if not priced:
				var gain_wallet := {"gold": 0, "scraps": 0}
				var gain := service.choose_with_wallet(choice_id, gain_wallet)
				_check(_wallet_shape_ok(gain) and gain.get("ok") == true
					and gain.get("event_id") == event_id and gain.get("choice_id") == choice_id
					and _wallet_exact_int(gain.get("wallet"), int(delta["gold"]), int(delta["scraps"])),
					"a free/gain choice settles exactly from a zero wallet: " + label)
				_check(_wallet_exact_int(gain_wallet, 0, 0),
					"a free/gain choice leaves the zero caller wallet untouched: " + label)
				continue

			var zero_wallet := {"gold": 0, "scraps": 0}
			var zero_before: Dictionary = zero_wallet.duplicate(true)
			var expected_global := _rng_start(81200)
			var rejected := service.choose_with_wallet(choice_id, zero_wallet)
			_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
				"a priced choice is refused at a zero wallet: " + label)
			_check(rejected.get("event_id") == "" and rejected.get("choice_id") == "",
				"the zero-wallet refusal returns empty IDs: " + label)
			_check(_wallet_exact_int(rejected.get("wallet"), 0, 0),
				"the zero-wallet refusal returns a detached unchanged wallet: " + label)
			_check(_wallet_exact_int(zero_wallet, 0, 0) and zero_wallet == zero_before,
				"the zero-wallet refusal never mutates the caller wallet: " + label)
			_check(service.is_valid() and not service.is_claimed() and service.get_event() == original,
				"the zero-wallet refusal spends no claim and keeps the snapshot: " + label)
			(rejected["wallet"] as Dictionary)["gold"] = 999
			_check(_wallet_exact_int(zero_wallet, 0, 0),
				"mutating the refused wallet never reaches the caller: " + label)

			# The same visit recovers on the neutral Leave choice, with no partial spend.
			var recovered := service.choose_with_wallet("leave", zero_wallet)
			_check(_wallet_shape_ok(recovered) and recovered.get("ok") == true
				and recovered.get("event_id") == event_id and recovered.get("choice_id") == "leave",
				"Leave recovers on the SAME visit after the refusal: " + label)
			_check(_wallet_exact_int(recovered.get("wallet"), 0, 0),
				"the recovered Leave preserves the zero wallet: " + label)
			_check(_wallet_exact_int(zero_wallet, 0, 0) and zero_wallet == zero_before,
				"the recovered Leave leaves the caller wallet untouched: " + label)
			_check(service.is_claimed() and not service.is_valid() and service.get_event() == original,
				"the recovered Leave latches exactly one claim: " + label)
			var after := service.choose_with_wallet(choice_id, {"gold": START_GOLD, "scraps": START_SCRAPS})
			_check(_wallet_shape_ok(after) and after.get("ok", true) == false
				and after.get("event_id") == "" and after.get("choice_id") == ""
				and _wallet_exact_int(after.get("wallet"), START_GOLD, START_SCRAPS),
				"a post-recovery choice is rejected even once it becomes affordable: " + label)
			_check(service.is_claimed() and service.get_event() == original,
				"post-recovery rejection keeps the single claim latched: " + label)
			_check(randi() == expected_global,
				"refusal, recovery and replay spend no RNG: " + label)


func _test_unoffered_choice_ids() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected_choices: Dictionary = _expected_choices(event_id)
		_check(matches.size() == 1, "unoffered-ID case has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0].duplicate(true)
		var original: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
		var wallet_before: Dictionary = wallet.duplicate(true)
		var bad_ids: Array = ["", " ", "unoffered", "LEAVE", "leave ", " leave", null, 7, ["leave"], {"id": "leave"}]
		for offered_id in expected_choices:
			var offered_text: String = offered_id
			bad_ids.append(offered_text.to_upper())
			bad_ids.append(offered_text + " ")
			bad_ids.append(" " + offered_text)
		# Every choice ID authored only on another event is unoffered here.
		for other_event_id in EVENTS:
			for other_choice_id in _expected_choices(other_event_id):
				if expected_choices.has(other_choice_id):
					continue
				if not bad_ids.has(other_choice_id):
					bad_ids.append(other_choice_id)
		for bad_id in bad_ids:
			var expected_global := _rng_start(81300)
			var rejected := service.choose_with_wallet(bad_id, wallet)
			_check(_wallet_shape_ok(rejected) and rejected.get("ok", true) == false,
				"an unoffered choice ID is rejected: " + event_id + "/" + str(bad_id))
			_check(rejected.get("event_id") == "" and rejected.get("choice_id") == "",
				"an unoffered choice ID returns empty IDs: " + event_id + "/" + str(bad_id))
			_check(_wallet_exact_int(rejected.get("wallet"), START_GOLD, START_SCRAPS),
				"an unoffered choice ID preserves the detached wallet: " + event_id + "/" + str(bad_id))
			_check(service.is_valid() and not service.is_claimed()
				and service.get_event() == original and wallet == wallet_before,
				"an unoffered choice ID consumes no claim or input: " + event_id + "/" + str(bad_id))
			_check(randi() == expected_global,
				"an unoffered choice ID spends no RNG: " + event_id + "/" + str(bad_id))
		var claimed := service.choose_with_wallet("leave", wallet)
		_check(_wallet_shape_ok(claimed) and claimed.get("ok") == true
			and claimed.get("event_id") == event_id and claimed.get("choice_id") == "leave"
			and _wallet_exact_int(claimed.get("wallet"), START_GOLD, START_SCRAPS),
			"the offered Leave still claims once after every rejection: " + event_id)
		_check(service.is_claimed() and not service.is_valid(),
			"the recovered Leave latches exactly one claim: " + event_id)
		var replay := service.choose_with_wallet("leave", wallet)
		_check(_wallet_shape_ok(replay) and replay.get("ok", true) == false
			and _wallet_exact_int(replay.get("wallet"), START_GOLD, START_SCRAPS),
			"the recovered Leave cannot be replayed: " + event_id)


func _test_hero_metadata() -> void:
	var heroes := {}
	var hero_choice_ids := {}
	var hero_choice_count := 0
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected: Dictionary = _expected(event_id)
		_check(matches.size() == 1, "hero metadata case has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var hero: Variant = record.get("required_hero")
		_check(hero == expected["required_hero"], "required_hero matches the authored hero: " + event_id)
		if hero is String:
			_check(not heroes.has(hero), "each hero-specific event names a distinct hero: " + str(hero))
			heroes[hero] = true
		var listed: Variant = record.get("hero_choice_ids")
		if not listed is Array:
			continue
		var authored := _choice_ids(record)
		hero_choice_count += (listed as Array).size()
		for choice_id in listed:
			_check(choice_id is String and authored.has(choice_id),
				"hero_choice_ids only names authored choices: " + event_id + "/" + str(choice_id))
			_check(not hero_choice_ids.has(choice_id),
				"hero choice IDs are unique across the five events: " + str(choice_id))
			hero_choice_ids[choice_id] = true
	_check(hero_choice_count == 10,
		"the five events declare exactly ten hero-specific choices")
	_check(hero_choice_ids.size() == 10,
		"the ten hero-specific choice IDs are distinct")
	_check(heroes.size() == 5, "the five events name five distinct required heroes")
	for required_hero in ["warden", "seamstress", "tinker", "lantern_monk", "rag_duelist"]:
		_check(heroes.has(required_hero), "catalog names the required hero: " + required_hero)
	# The starter party keeps its three current heroes; these two stay future-only.
	var party_file := FileAccess.open("res://data/heroes/starter_party.json", FileAccess.READ)
	_check(party_file != null, "the starter party file still opens")
	if party_file != null:
		var party_text := party_file.get_as_text()
		party_file.close()
		var party_parser := JSON.new()
		_check(party_parser.parse(party_text) == OK, "the starter party file still parses")
		var party: Variant = party_parser.data
		_check(party is Array, "the starter party file is still an array")
		if party is Array:
			var party_ids := {}
			for entry in party:
				if entry is Dictionary and entry.get("id") is String:
					party_ids[entry.get("id")] = true
			for starter_id in ["warden", "seamstress", "tinker"]:
				_check(party_ids.has(starter_id), "the starter party still contains " + starter_id)


func _test_fixed_seed_replay() -> void:
	for event_id in EVENTS:
		var matches := _matching(event_id)
		var expected_choices: Dictionary = _expected_choices(event_id)
		_check(matches.size() == 1, "seeded replay has one authored record: " + event_id)
		if matches.size() != 1:
			continue
		for choice_id in expected_choices:
			var delta: Dictionary = expected_choices[choice_id]
			var label: String = event_id + "/" + _signed(str(choice_id), delta)
			var traces: Array = []
			for attempt in range(2):
				var local_rng := RandomNumberGenerator.new()
				local_rng.seed = 918273
				var initial_local_state: int = local_rng.state
				var expected_global := _rng_start(918273)
				var caller_record: Dictionary = matches[0].duplicate(true)
				var original_event: Dictionary = caller_record.duplicate(true)
				var wallet := {"gold": START_GOLD, "scraps": START_SCRAPS}
				var wallet_before: Dictionary = wallet.duplicate(true)
				var instance := RunEventChoice.new(caller_record)
				var preflight := instance.choose_with_wallet("not_a_choice", wallet)
				var preview := instance.preview_wallet_choices(wallet)
				var claim := instance.choose_with_wallet(choice_id, wallet)
				var replay := instance.choose_with_wallet(choice_id, claim.get("wallet", {}))
				_check(_wallet_shape_ok(preflight) and preflight.get("ok") == false
					and preflight.get("wallet") == wallet_before,
					"a forged choice before the claim preserves the wallet: " + label)
				_check(preview.get("ok") == true and preview.get("event_id") == event_id,
					"the seeded preview is readable before the claim: " + label)
				_check(_wallet_shape_ok(claim) and claim.get("ok") == true
					and claim.get("event_id") == event_id and claim.get("choice_id") == choice_id
					and _wallet_exact_int(claim.get("wallet"),
						START_GOLD + int(delta["gold"]), START_SCRAPS + int(delta["scraps"])),
					"the seeded claim settles its scripted delta: " + label)
				_check(_wallet_shape_ok(replay) and replay.get("ok") == false
					and replay.get("wallet") == claim.get("wallet")
					and instance.is_claimed() and not instance.is_valid(),
					"the seeded replay fails after exactly one claim: " + label)
				_check(wallet == wallet_before and caller_record == original_event
					and instance.get_event() == original_event,
					"the seeded trace preserves caller inputs and the snapshot: " + label)
				_check(local_rng.state == initial_local_state,
					"the seeded trace leaves the local RNG state untouched: " + label
						+ " attempt " + str(attempt))
				_check(randi() == expected_global,
					"the seeded trace leaves the global RNG stream untouched: " + label
						+ " attempt " + str(attempt))
				traces.append({
					"preview": preview,
					"preflight": preflight,
					"claim": claim,
					"replay": replay,
					"is_claimed": instance.is_claimed(),
					"is_valid": instance.is_valid(),
					"event": instance.get_event(),
				})
			_check(traces.size() == 2 and traces[0] == traces[1],
				"two independent seeded instances produce identical traces: " + label)
