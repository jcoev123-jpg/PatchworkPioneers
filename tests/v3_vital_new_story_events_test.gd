extends SceneTree
## Deterministic headless test for the six appended V3-4 vitality story events
## (data/events/v3_vital_story_events.json) and the RunEventChoice vitality API.
## Independent expected dictionaries only; the JSON is loaded through FileAccess
## and located by ID, never by catalog size, position or full ordered list.

const VITAL_EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

# Independent authored expectations: choice rows are [id, text, gold, scraps, hp, max_hp].
const NEW_STORY_EVENTS := {
	"v3_wakeful_darning_house": {
		"title": "The Wakeful Darning House",
		"description": "A round button-eyed tailor keeps a bone-cream darning room lit until dawn, with warm quilts stacked at the door.",
		"choices": [
			["buy_warm_seam", "Pay 14 gold for a warm seam (+9 HP)", -14, 0, 9, 0],
			["unpick_old_hem", "Trade 2 max HP for 20 gold", 20, 0, 0, -2],
			["leave", "Leave the darning room asleep", 0, 0, 0, 0],
		],
	},
	"v3_silver_bobbin_oath": {
		"title": "The Silver Bobbin Oath",
		"description": "A little brass-eyed vowkeeper winds silver thread around a carved spool beneath an amber lamp.",
		"choices": [
			["pledge_thread", "Spend 2 scraps to gain 2 max HP and mend 3 HP", 0, -2, 3, 2],
			["sell_silver", "Sell one scrap of silver thread for 17 gold", 17, -1, 0, 0],
			["leave", "Keep your promises for another night", 0, 0, 0, 0],
		],
	},
	"v3_crowshade_hearth": {
		"title": "The Crowshade Hearth",
		"description": "Beneath a moss-green quilt awning, a plush crow tends a kettle on a tiny lantern stove.",
		"choices": [
			["offer_stuffing", "Give 5 HP of stuffing for 2 scraps", 0, 2, -5, 0],
			["buy_broth", "Pay 11 gold for a bowl of stitched broth (+7 HP)", -11, 0, 7, 0],
			["leave", "Leave the kettle simmering", 0, 0, 0, 0],
		],
	},
	"v3_briar_button_sentinel": {
		"title": "The Briar Button Sentinel",
		"description": "A stout velvet guardian guards a gate of blunt thorn-pins, one golden button shining in its chest.",
		"choices": [
			["press_button", "Lose 4 HP to gain 1 max HP and 1 scrap", 0, 1, -4, 1],
			["buy_pin", "Buy a lasting safety seam for 19 gold (+2 max HP)", -19, 0, 0, 2],
			["leave", "Pass the guardian without touching its pins", 0, 0, 0, 0],
		],
	},
	"v3_mossveil_patch_auditor": {
		"title": "The Mossveil Patch Auditor",
		"description": "A broad patch-covered doll stamps every seam in a midnight-teal ledger with a giant thimble.",
		"choices": [
			["trade_margin", "Give up 2 max HP for 28 gold", 28, 0, 0, -2],
			["reinforce_ledger", "Spend 2 scraps to restore 8 HP", 0, -2, 8, 0],
			["leave", "Close the ledger and go", 0, 0, 0, 0],
		],
	},
	"v3_velvet_moon_ward": {
		"title": "The Velvet Moon Ward",
		"description": "A rounded lantern-bearing ragdoll nurses a crescent quilt under a plum-coloured button moon.",
		"choices": [
			["share_oil", "Spend 1 scrap and lose 3 HP for 2 max HP", 0, -1, -3, 2],
			["hire_nurse", "Pay 18 gold to recover 9 HP", -18, 0, 9, 0],
			["leave", "Leave the moon ward in peace", 0, 0, 0, 0],
		],
	},
}

# Three named older anchors that must still exist unchanged.
const ANCHOR_IDS := ["v3_lantern_quilt_infirmary", "v3_button_heart_shrine", "v3_duskwoven_cocoon"]

# Independent expectations for the three anchor records (choice rows: [id, text, gold, scraps, hp, max_hp]).
const ANCHOR_EXPECTATIONS := {
	"v3_lantern_quilt_infirmary": {
		"title": "The Lantern-Quilt Infirmary",
		"description": "A round, button-eyed nurse hangs warm quilts beside a midnight-teal lantern.",
		"choices": [
			["buy_bandages", "Pay 12 gold to dress one hero's wounds (+8 HP)", -12, 0, 8, 0],
			["blood_receipt", "Donate 4 HP for a purse of 18 gold", 18, 0, -4, 0],
			["leave", "Leave the lantern burning", 0, 0, 0, 0],
		],
	},
	"v3_button_heart_shrine": {
		"title": "The Button-Heart Shrine",
		"description": "A moss-cloaked doll tends a beating brass button stitched into a chapel wall.",
		"choices": [
			["reinforce_heart", "Spend 2 scraps to sew a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
			["surrender_button", "Give up 2 max HP for 24 gold", 24, 0, 0, -2],
			["leave", "Let the little heart keep ticking", 0, 0, 0, 0],
		],
	},
	"v3_duskwoven_cocoon": {
		"title": "The Duskwoven Cocoon",
		"description": "An enormous quilted moth cocoon glows rose-gold beside the road.",
		"choices": [
			["rest_in_cocoon", "Spend 2 scraps; heal 7 HP and gain 1 max HP", 0, -2, 7, 1],
			["harvest_silk", "Take 24 gold in silk; lose 1 max HP", 24, 0, 0, -1],
			["leave", "Leave the cocoon untouched", 0, 0, 0, 0],
		],
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _is_integral_json_number(value: Variant, allow_negative: bool = false) -> bool:
	if typeof(value) == TYPE_INT:
		return allow_negative or int(value) >= 0
	if typeof(value) == TYPE_FLOAT:
		var num: float = value
		return (is_finite(num) and floor(num) == num
			and num <= RunEventChoice.MAX_SAFE_FLOAT_INT
			and num >= (-RunEventChoice.MAX_SAFE_FLOAT_INT if allow_negative else 0.0))
	return false


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _vital_state(gold: int, scraps: int, hp: int, max_hp: int) -> Dictionary:
	return {"gold": gold, "scraps": scraps, "hero": {"id": "warden", "hp": hp, "max_hp": max_hp}}


func _vital_state_is(state: Variant, gold: int, scraps: int, hp: int, max_hp: int) -> bool:
	if not state is Dictionary:
		return false
	var dict: Dictionary = state
	if dict.size() != 3 or not dict.get("hero") is Dictionary:
		return false
	var hero: Dictionary = dict["hero"]
	return (hero.size() == 3 and hero.get("id") == "warden"
		and typeof(dict.get("gold")) == TYPE_INT and int(dict["gold"]) == gold
		and typeof(dict.get("scraps")) == TYPE_INT and int(dict["scraps"]) == scraps
		and typeof(hero.get("hp")) == TYPE_INT and int(hero["hp"]) == hp
		and typeof(hero.get("max_hp")) == TYPE_INT and int(hero["max_hp"]) == max_hp)


func _matching(event_id: String) -> Array:
	return catalog.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


# Returns a deep copy of the catalog entry for the given ID, or {} if absent.
func _record(event_id: String) -> Dictionary:
	for entry in catalog:
		if entry is Dictionary and entry.get("id") == event_id:
			return (entry as Dictionary).duplicate(true)
	return {}


func _load_events(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "events file opens: " + path)
	if file == null:
		return []
	var parser := JSON.new()
	var parse_result := parser.parse(file.get_as_text())
	file.close()
	_check(parse_result == OK and parser.data is Dictionary and (parser.data as Dictionary).get("events") is Array,
		"events file parses to {events: [...]}: " + path)
	if parse_result != OK or not parser.data is Dictionary or not (parser.data as Dictionary).get("events") is Array:
		return []
	return (parser.data as Dictionary)["events"]


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _initialize() -> void:
	_load_vital_catalog()
	_test_new_story_data_fixture()
	_test_anchor_records_unchanged()
	_test_new_ids_unique()
	_test_vital_settlement_and_claims()
	_test_vital_unaffordable_then_leave()
	for failure in failures:
		printerr(failure)
	print("v3_vital_new_story_events_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _load_vital_catalog() -> void:
	catalog = _load_events(VITAL_EVENTS_PATH)
	_check(not catalog.is_empty(), "vital story catalog is non-empty")


func _test_new_story_data_fixture() -> void:
	# Every new event is present exactly once with exact title/description/choices/outcomes.
	for event_id in NEW_STORY_EVENTS:
		var matches := _matching(event_id)
		_check(matches.size() == 1, "exactly one authored new story event: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = NEW_STORY_EVENTS[event_id]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record has exact top-level keys: " + event_id)
		_check(record.get("title") == expected["title"], "new title exact: " + event_id)
		_check(record.get("description") == expected["description"], "new description exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "new record has three choices: " + event_id)
		if not choices is Array:
			continue
		var seen := {}
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary and choice.size() == 3 and choice.has("id")
				and choice.has("text") and choice.has("outcome"),
				"new choice has id/text/outcome keys: " + event_id)
			if choice is Dictionary and choice.get("id") is String:
				var cid: String = choice["id"]
				_check(not seen.has(cid), "new choice IDs are distinct: " + event_id + "/" + cid)
				seen[cid] = true
				by_id[cid] = choice
			if choice is Dictionary and choice.get("outcome") is Dictionary:
				var outcome: Dictionary = choice["outcome"]
				_check(outcome.size() == 4 and outcome.has("gold") and outcome.has("scraps")
					and outcome.has("hp") and outcome.has("max_hp"),
					"new outcome has exactly four keys: " + event_id + "/" + str(choice.get("id")))
		var wanted: Array = expected["choices"]
		_check(seen.size() == wanted.size(), "new choice count matches expected: " + event_id)
		for row in wanted:
			var tag: String = event_id + "/" + row[0]
			_check(by_id.has(row[0]), "new choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "new choice text exact: " + tag)
			if choice_dict.get("outcome") is Dictionary:
				var outcome: Dictionary = choice_dict["outcome"]
				var keys := ["gold", "scraps", "hp", "max_hp"]
				for i in range(4):
					var raw: Variant = outcome.get(keys[i])
					_check(_is_integral_json_number(raw, true) and int(raw) == int(row[2 + i]),
						"new outcome " + keys[i] + " exact: " + tag)
		# The six new records build valid selectors.
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(), "new record builds a valid selector: " + event_id)


func _test_anchor_records_unchanged() -> void:
	for anchor_id in ANCHOR_IDS:
		var matches := _matching(anchor_id)
		_check(matches.size() == 1, "anchor record still present once: " + anchor_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		var expected: Dictionary = ANCHOR_EXPECTATIONS[anchor_id]
		_check(record.get("title") == expected["title"], "anchor title unchanged: " + anchor_id)
		_check(record.get("description") == expected["description"], "anchor description unchanged: " + anchor_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3, "anchor has three choices: " + anchor_id)
		if not choices is Array:
			continue
		var by_id := {}
		for choice in choices:
			if choice is Dictionary and choice.get("id") is String:
				by_id[choice["id"]] = choice
		var wanted: Array = expected["choices"]
		_check(by_id.size() == wanted.size(), "anchor choice count unchanged: " + anchor_id)
		for row in wanted:
			var tag: String = anchor_id + "/" + row[0]
			_check(by_id.has(row[0]), "anchor choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "anchor choice text unchanged: " + tag)
			if choice_dict.get("outcome") is Dictionary:
				var outcome: Dictionary = choice_dict["outcome"]
				var keys := ["gold", "scraps", "hp", "max_hp"]
				for i in range(4):
					_check(_is_integral_json_number(outcome.get(keys[i]), true)
						and int(outcome.get(keys[i])) == int(row[2 + i]),
						"anchor outcome " + keys[i] + " unchanged: " + tag)


func _test_new_ids_unique() -> void:
	var all_ids: Array = []
	for entry in catalog:
		if entry is Dictionary and entry.get("id") is String:
			all_ids.append(entry["id"])
	var new_ids: Array = []
	for event_id in NEW_STORY_EVENTS:
		new_ids.append(event_id)
	_check(new_ids.size() == 6, "six new story event IDs expected")
	for event_id in new_ids:
		var count: int = 0
		for existing_id in all_ids:
			if existing_id == event_id:
				count += 1
		_check(count == 1, "new ID appears exactly once in catalog: " + str(event_id))
	# No duplicate IDs across the whole catalog.
	var seen := {}
	for cid in all_ids:
		_check(not seen.has(cid), "no duplicate event ID in catalog: " + str(cid))
		seen[cid] = true


func _test_vital_settlement_and_claims() -> void:
	# On a fresh selector per choice, call preview_vital_choices and choose_with_vitals
	# with funded snapshot {gold:40, scraps:4, hero:{id:"warden",hp:25,max_hp:40}}.
	# Leave branches leave the snapshot unchanged.
	for event_id in NEW_STORY_EVENTS:
		var expected: Dictionary = NEW_STORY_EVENTS[event_id]
		var rows: Array = expected["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			var g_delta: int = row[2]
			var s_delta: int = row[3]
			var hp_delta: int = row[4]
			var mhp_delta: int = row[5]
			var exp_gold: int = 40 + g_delta
			var exp_scraps: int = 4 + s_delta
			var exp_max: int = 40 + mhp_delta
			var exp_hp: int = min(25 + hp_delta, exp_max)

			var original_record: Dictionary = _record(event_id)
			var original_record_before: Dictionary = original_record.duplicate(true)
			var snapshot: Dictionary = _vital_state(40, 4, 25, 40)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var rng_expected := _rng_start(73000)

			# Preview on a fresh selector.
			var preview_service := RunEventChoice.new(original_record.duplicate(true))
			_check(preview_service.is_valid() and not preview_service.is_claimed(),
				"fresh preview selector valid before: " + tag)
			var preview := preview_service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"vital preview ok with three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(not entry.is_empty() and entry.size() == 7,
				"preview entry has seven keys: " + tag)
			_check(entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == g_delta
				and entry.get("scraps_delta") == s_delta
				and entry.get("hp_delta") == hp_delta
				and entry.get("max_hp_delta") == mhp_delta,
				"preview exact signed deltas: " + tag)
			_check(entry.get("affordable") == true and _vital_state_is(entry.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded preview projects exact state: " + tag)
			_check(snapshot == snapshot_before and original_record_before == _record(event_id),
				"vital preview does not mutate caller snapshot or catalog: " + tag)
			_check(preview_service.is_valid() and not preview_service.is_claimed()
				and preview_service.get_event() == original_record_before,
				"preview leaves selector unclaimed and snapshot intact: " + tag)

			# Commit on a fresh selector.
			var commit_record: Dictionary = _record(event_id)
			var commit_service := RunEventChoice.new(commit_record)
			var input: Dictionary = _vital_state(40, 4, 25, 40)
			var input_before: Dictionary = input.duplicate(true)
			var commit_result := commit_service.choose_with_vitals(choice_id, input)
			_check(commit_result.size() == 4 and commit_result.get("ok") == true
				and commit_result.get("event_id") == event_id and commit_result.get("choice_id") == choice_id
				and _vital_state_is(commit_result.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded commit exact state: " + tag)
			_check(commit_result.get("state") == entry.get("state"),
				"commit state matches preview forecast: " + tag)
			_check(input == input_before,
				"commit does not mutate caller snapshot: " + tag)
			_check(commit_record == original_record_before,
				"commit does not mutate caller record: " + tag)
			_check(commit_service.get_event() == original_record_before,
				"commit does not mutate selector snapshot: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"commit latches one claim and marks selector consumed: " + tag)

			# One-shot claim: replay is rejected.
			var replay_input: Dictionary = _vital_state(40, 4, 25, 40)
			var replay := commit_service.choose_with_vitals(choice_id, replay_input)
			_check(replay.size() == 4 and replay.get("ok") == false and replay.get("event_id") == ""
				and replay.get("choice_id") == "" and replay.get("state") == replay_input,
				"replay rejected with unchanged detached state: " + tag)
			_check(commit_service.is_claimed() and not commit_service.is_valid(),
				"replay does not consume a second claim: " + tag)

			# Legacy choose() and choose_with_wallet() also reject on a consumed visit.
			_check(commit_service.choose(choice_id).get("ok") == false,
				"legacy choose rejects on consumed visit: " + tag)
			_check(commit_service.choose_with_wallet(choice_id, {"gold": 40, "scraps": 4}).get("ok") == false,
				"legacy wallet commit rejects on consumed vitality visit: " + tag)

			# A different choice on the same consumed visit also rejects.
			var alt_id: String = "leave" if choice_id != "leave" else rows[0][0]
			if alt_id != choice_id:
				var alt_input: Dictionary = _vital_state(40, 4, 25, 40)
				var alt_replay := commit_service.choose_with_vitals(alt_id, alt_input)
				_check(alt_replay.get("ok") == false, "alternate choice rejected after claim: " + tag)

			_check(randi() == rng_expected, "preview and commit spend no global RNG: " + tag)

			# Detached returns: scribbling on the returned state must not affect
			# a subsequent receipt or the service's claim state.
			(commit_result["state"] as Dictionary)["gold"] = 999
			((entry["state"]) as Dictionary)["hero"]["hp"] = 999
			var replay2_input: Dictionary = _vital_state(40, 4, 25, 40)
			var replay2 := commit_service.choose_with_vitals(choice_id, replay2_input)
			_check(replay2.get("ok") == false
				and replay2.get("state") == replay2_input,
				"scribbled detached state does not leak into replay rejection: " + tag)


func _test_vital_unaffordable_then_leave() -> void:
	# Each new event has a genuinely unaffordable/dangerous branch that must
	# reject without consuming the visit, then free Leave must still be claimable.
	var cases := [
		{"event": "v3_wakeful_darning_house", "choice": "unpick_old_hem",
			"state": _vital_state(40, 4, 5, 10)},
		{"event": "v3_silver_bobbin_oath", "choice": "pledge_thread",
			"state": _vital_state(40, 1, 25, 40)},
		{"event": "v3_crowshade_hearth", "choice": "offer_stuffing",
			"state": _vital_state(40, 4, 5, 40)},
		{"event": "v3_briar_button_sentinel", "choice": "press_button",
			"state": _vital_state(40, 4, 4, 40)},
		{"event": "v3_mossveil_patch_auditor", "choice": "trade_margin",
			"state": _vital_state(40, 4, 5, 11)},
		{"event": "v3_velvet_moon_ward", "choice": "share_oil",
			"state": _vital_state(40, 4, 3, 40)},
	]
	for case_data in cases:
		var event_id: String = case_data["event"]
		var choice_id: String = case_data["choice"]
		var state: Dictionary = case_data["state"].duplicate(true)
		var original: Dictionary = state.duplicate(true)
		var tag: String = event_id + "/" + choice_id
		var record := _matching(event_id)
		_check(record.size() == 1, "unaffordable case has its record: " + event_id)
		if record.is_empty():
			continue
		var authored: Dictionary = record[0].duplicate(true)
		var authored_before: Dictionary = authored.duplicate(true)
		var service := RunEventChoice.new(authored)
		var rng_expected := _rng_start(73100)
		var preview := service.preview_vital_choices(state)
		var entry := _preview_choice(preview, choice_id)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id
			and not entry.is_empty() and entry.get("affordable") == false
			and entry.get("state") == original,
			"unaffordable branch forecast unavailable in preview: " + tag)
		var refusal := service.choose_with_vitals(choice_id, state)
		_check(refusal.size() == 4 and refusal.get("ok") == false and refusal.get("event_id") == ""
			and refusal.get("choice_id") == "" and refusal.get("state") == original,
			"unaffordable branch rejected with unchanged detached state: " + tag)
		_check(state == original and authored == authored_before and service.get_event() == authored_before
			and service.is_valid() and not service.is_claimed(),
			"unaffordable branch consumes no visit and leaves caller state: " + tag)
		(refusal["state"] as Dictionary)["gold"] = 999
		_check(state == original, "refusal state is detached from caller: " + tag)

		# Free Leave remains claimable on the SAME visit.
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"leave settles the visit after the refusal: " + tag)
		_check(randi() == rng_expected, "unaffordable refusal, leave and replay spend no RNG: " + tag)

		# Leave is one-shot; replay of the refusenik branch also fails.
		var replay := service.choose_with_vitals(choice_id, state)
		_check(replay.get("ok") == false and replay.get("state") == original
			and state == original,
			"post-leave replay rejects unchanged state: " + tag)

	# Additional unaffordable sampling: missing gold for buy_warm_seam, zero scraps for share_oil.
	var warm_matches := _matching("v3_wakeful_darning_house")
	_check(warm_matches.size() == 1, "buy_warm_seam event exists for gold-missing test")
	if warm_matches.size() == 1:
		var warm_record: Dictionary = warm_matches[0].duplicate(true)
		var warm_original: Dictionary = warm_record.duplicate(true)
		var buy_service := RunEventChoice.new(warm_record)
		var poor_gold: Dictionary = _vital_state(13, 4, 25, 40)
		var poor_gold_before: Dictionary = poor_gold.duplicate(true)
		var preview := buy_service.preview_vital_choices(poor_gold)
		var entry := _preview_choice(preview, "buy_warm_seam")
		_check(entry.get("affordable") == false
			and entry.get("state") == poor_gold_before,
			"buy_warm_seam unaffordable at 13 gold")
		var refusal := buy_service.choose_with_vitals("buy_warm_seam", poor_gold)
		_check(refusal.get("ok") == false and refusal.get("state") == poor_gold_before
			and poor_gold == poor_gold_before and buy_service.is_valid() and not buy_service.is_claimed(),
			"buy_warm_seam rejected at 13 gold without consuming visit")
		var leave := buy_service.choose_with_vitals("leave", poor_gold)
		_check(leave.get("ok") == true and leave.get("state") == poor_gold_before
			and warm_record == warm_original,
			"leave claimable after gold-missing rejection")

	var moon_matches := _matching("v3_velvet_moon_ward")
	_check(moon_matches.size() == 1, "share_oil event exists for zero-scraps test")
	if moon_matches.size() == 1:
		var moon_record: Dictionary = moon_matches[0].duplicate(true)
		var moon_original: Dictionary = moon_record.duplicate(true)
		var oil_service := RunEventChoice.new(moon_record)
		var zero_scraps: Dictionary = _vital_state(40, 0, 25, 40)
		var zero_before: Dictionary = zero_scraps.duplicate(true)
		var preview := oil_service.preview_vital_choices(zero_scraps)
		var entry := _preview_choice(preview, "share_oil")
		_check(entry.get("affordable") == false
			and entry.get("state") == zero_before,
			"share_oil unaffordable at 0 scraps")
		var refusal := oil_service.choose_with_vitals("share_oil", zero_scraps)
		_check(refusal.get("ok") == false and refusal.get("state") == zero_before
			and zero_scraps == zero_before and oil_service.is_valid() and not oil_service.is_claimed(),
			"share_oil rejected at 0 scraps without consuming visit")
		var leave := oil_service.choose_with_vitals("leave", zero_scraps)
		_check(leave.get("ok") == true and leave.get("state") == zero_before
			and moon_record == moon_original,
			"leave claimable after zero-scrap rejection")
