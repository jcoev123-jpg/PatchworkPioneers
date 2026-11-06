extends SceneTree
## Deterministic headless coverage for the three gothic roadside object-trade
## stories appended to the shipped roadside pack
## (res://data/events/v3_roadside_events.json): the Brass-Ear Listening Post,
## the Bone-Bellows Portrait Booth and the Blacklace Thunder Drum.
##
## EXPECTED, FUNDED_FINAL, BOUNDARY_REFUSALS and ANCHORS are independent copies
## of the authored stories, deltas, funded settlement tables, boundary wallets
## and earlier anchors; they never read the production catalog or the selector
## back as their oracle. Only per-ID membership is asserted: no catalog total,
## no full ordered ID list and no fixed pool position, so peer batches can land
## in the same catalog without clashing.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"
const FUNDED := {"gold": 50, "scraps": 5}
const SCARCE := {"gold": 0, "scraps": 0}

const EXPECTED := {
	"v3_brass_ear_listening_post": {
		"title": "The Brass-Ear Listening Post",
		"description": "A plump moss-velvet listener sits beneath an ear trumpet as tall as a gate; its patched fabric earpiece gathers whispers from a moonlit quilt road while a single candle glows in the copper throat.",
		"choices": [
			{"id": "polish_ear_horn", "text": "Spend 2 scraps polishing the brass ear; earn 29 gold", "gold": 29, "scraps": -2},
			{"id": "buy_echo_thread", "text": "Pay 17 gold for two coils of echo thread (+2 scraps)", "gold": -17, "scraps": 2},
			{"id": "leave", "text": "Leave the giant brass ear listening to the night", "gold": 0, "scraps": 0},
		],
	},
	"v3_bone_bellows_portrait_booth": {
		"title": "The Bone-Bellows Portrait Booth",
		"description": "A button-eyed photographer unfolds a giant bone-cream camera bellows from an oxblood velvet booth; the round black lens holds four little sewn silhouettes instead of faces.",
		"choices": [
			{"id": "pose_for_portrait", "text": "Pose for a stitched portrait (earn 12 gold)", "gold": 12, "scraps": 0},
			{"id": "buy_shadow_plate", "text": "Pay 22 gold for three bundles of shadow-plate trim (+3 scraps)", "gold": -22, "scraps": 3},
			{"id": "leave", "text": "Let the velvet curtain close around the silent camera", "gold": 0, "scraps": 0},
		],
	},
	"v3_blacklace_thunder_drum": {
		"title": "The Blacklace Thunder Drum",
		"description": "A squat slate-felt drummer stands within a carriage-sized blacklace drum; great copper hoops are tied with fraying crimson thread, and each soft beat shakes loose a bundle of rivets.",
		"choices": [
			{"id": "salvage_loose_rivets", "text": "Gather the fallen copper rivets (+2 scraps)", "gold": 0, "scraps": 2},
			{"id": "reinforce_drum_rim", "text": "Spend 3 scraps repairing the drum rim (earn 37 gold)", "gold": 37, "scraps": -3},
			{"id": "leave", "text": "Walk on as the soft drumbeat fades behind the mist", "gold": 0, "scraps": 0},
		],
	},
}

## Independent funded {gold: 50, scraps: 5} settlement table: the exact final
## balance each authored choice must reach from a fresh unclaimed visit.
const FUNDED_FINAL := {
	"v3_brass_ear_listening_post": {
		"polish_ear_horn": {"gold": 79, "scraps": 3},
		"buy_echo_thread": {"gold": 33, "scraps": 7},
		"leave": {"gold": 50, "scraps": 5},
	},
	"v3_bone_bellows_portrait_booth": {
		"pose_for_portrait": {"gold": 62, "scraps": 5},
		"buy_shadow_plate": {"gold": 28, "scraps": 8},
		"leave": {"gold": 50, "scraps": 5},
	},
	"v3_blacklace_thunder_drum": {
		"salvage_loose_rivets": {"gold": 50, "scraps": 7},
		"reinforce_drum_rim": {"gold": 87, "scraps": 2},
		"leave": {"gold": 50, "scraps": 5},
	},
}

## One-unit-short boundary wallets for every priced choice: each must refuse
## without a claim, and the same visit must still settle its free Leave.
const BOUNDARY_REFUSALS := [
	{"event": "v3_brass_ear_listening_post", "choice": "polish_ear_horn", "wallet": {"gold": 50, "scraps": 1}},
	{"event": "v3_brass_ear_listening_post", "choice": "buy_echo_thread", "wallet": {"gold": 16, "scraps": 5}},
	{"event": "v3_bone_bellows_portrait_booth", "choice": "buy_shadow_plate", "wallet": {"gold": 21, "scraps": 5}},
	{"event": "v3_blacklace_thunder_drum", "choice": "reinforce_drum_rim", "wallet": {"gold": 50, "scraps": 2}},
]

## Independent per-ID seeds for the forced single-eligible selection replay.
## With one eligible ID the seed cannot pin a catalog position.
const SEEDS := {
	"v3_brass_ear_listening_post": 1181001,
	"v3_bone_bellows_portrait_booth": 1181002,
	"v3_blacklace_thunder_drum": 1181003,
}

## Earlier roadside anchors this additive batch must leave unchanged in the
## authored source, named independently of the selector, with their original
## titles and signed wallet deltas.
const ANCHORS := {
	"v3_mourning_keykeeper": {
		"title": "The Mourning Keykeeper",
		"description": "Beneath a cracked cabinet door, a round plum ragdoll bears a brass winding key larger than itself; candlelight catches the frayed lock tassels.",
		"choices": {
			"buy_key_thread": {"text": "Pay 21 gold for two coils of keyhole thread (+2 scraps)", "gold": -21, "scraps": 2},
			"reset_rusty_winder": {"text": "Spend 2 scraps resetting the giant key (earn 27 gold)", "gold": 27, "scraps": -2},
			"leave": {"text": "Leave the winding key to click in the dark", "gold": 0, "scraps": 0},
		},
	},
	"v3_measureworm_survey": {
		"title": "The Measureworm Survey",
		"description": "A plump tape-measure worm loops round a crooked bedpost, its button eyes counting every loose stitch on the ruler sewn along its back.",
		"choices": {
			"collect_tape_tail": {"text": "Gather a fallen tape tail (+1 scrap)", "gold": 0, "scraps": 1},
			"reline_measure_spool": {"text": "Spend 1 scrap repairing the ruler spool (earn 17 gold)", "gold": 17, "scraps": -1},
			"leave": {"text": "Let the measureworm finish its slow count", "gold": 0, "scraps": 0},
		},
	},
	"v3_velvet_mousetrap_stage": {
		"title": "The Velvet Mousetrap Stage",
		"description": "An enormous sprung brass mousetrap holds a tiny velvet-curtained stage; a rounded mouse doll raises a safety pin above its amber footlight.",
		"choices": {
			"buy_safety_silk": {"text": "Pay 28 gold for three bundles of safety silk (+3 scraps)", "gold": -28, "scraps": 3},
			"mend_trap_spring": {"text": "Spend 2 scraps mending the sprung hinge (earn 24 gold)", "gold": 24, "scraps": -2},
			"leave": {"text": "Leave the mouse doll under its little spotlight", "gold": 0, "scraps": 0},
		},
	},
}

var failures: Array[String] = []
var checks := 0
var source_document: Dictionary = {}
var source_snapshot: Dictionary = {}
var source_by_id: Dictionary = {}
var source_counts: Dictionary = {}

func _initialize() -> void:
	_load_source()
	if source_document.is_empty():
		_report()
		return
	_test_source_records()
	_test_anchor_records()
	_test_rotation_membership()
	_test_funded_wallet()
	_test_scarce_wallets()
	_test_boundary_refusals()
	_test_unknown_choice()
	_test_forced_selection()
	_check(source_document == source_snapshot, "the roadside source is unchanged by every flow")
	_report()

func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_stitched_ear_bellows_drum_wallet_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _load_source() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_roadside_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parsed := parser.parse(text)
	_check(parsed == OK, "v3_roadside_events.json parses through JSON")
	if parsed != OK:
		return
	_check(parser.data is Dictionary, "the roadside catalog is a JSON object")
	if not parser.data is Dictionary:
		return
	source_document = (parser.data as Dictionary).duplicate(true)
	var events: Variant = source_document.get("events")
	_check(events is Array, "the roadside catalog carries an events array")
	if not events is Array:
		source_document = {}
		return
	for record in events:
		if not record is Dictionary:
			continue
		var event_id: Variant = (record as Dictionary).get("id")
		if not event_id is String:
			continue
		source_counts[event_id] = int(source_counts.get(event_id, 0)) + 1
		if not source_by_id.has(event_id):
			source_by_id[event_id] = record
	source_snapshot = source_document.duplicate(true)

## AC1: each new record exists exactly once in the authored source with its
## verbatim story, exactly three uniquely identified choices, a third-position
## free Leave and the exact signed wallet deltas.
func _test_source_records() -> void:
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		_check(int(source_counts.get(event_id, 0)) == 1,
			"exactly one sourced record for " + event_id)
		if not source_by_id.has(event_id):
			continue
		_check_record_contract(source_by_id[event_id], event_id, contract, "source")
		var record: Dictionary = source_by_id[event_id]
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3 and (choices[2] as Dictionary).get("id") == "leave",
			"the third authored choice is the Leave: " + event_id)
		var leave_outcome: Dictionary = (choices[2] as Dictionary).get("outcome", {})
		_check(leave_outcome.get("gold") == 0 and leave_outcome.get("scraps") == 0,
			"the authored Leave outcome is exactly zero: " + event_id)
		var service := RunEventChoice.new(record)
		_check(service.is_valid() and not service.is_claimed(),
			"a fresh sourced selector validates: " + event_id)

## AC1: the named earlier anchors keep exactly one record each with their
## original titles and signed wallet outcomes.
func _test_anchor_records() -> void:
	for anchor_id in ANCHORS:
		var contract: Dictionary = ANCHORS[anchor_id]
		_check(int(source_counts.get(anchor_id, 0)) == 1,
			"exactly one sourced record for the anchor " + anchor_id)
		if not source_by_id.has(anchor_id):
			continue
		var record: Dictionary = source_by_id[anchor_id]
		_check(record.get("title") == contract["title"],
			"the anchor keeps its original title: " + anchor_id)
		_check(record.get("description") == contract["description"],
			"the anchor keeps its original description: " + anchor_id)
		var choices: Variant = record.get("choices")
		if not choices is Array:
			_check(false, "the anchor keeps its choices array: " + anchor_id)
			continue
		_check((choices as Array).size() == 3,
			"the anchor keeps its three original choices: " + anchor_id)
		var by_id := {}
		for choice in choices:
			if choice is Dictionary:
				by_id[(choice as Dictionary).get("id")] = choice
		for choice_id in contract["choices"]:
			_check(by_id.has(choice_id),
				"the anchor keeps its choice " + str(choice_id) + ": " + anchor_id)
			if not by_id.has(choice_id):
				continue
			var expected_outcome: Dictionary = contract["choices"][choice_id]
			var entry: Dictionary = by_id[choice_id]
			_check(entry.get("text") == expected_outcome["text"],
				"the anchor keeps its original choice text: " + anchor_id + " / " + str(choice_id))
			var outcome: Variant = entry.get("outcome")
			_check(outcome is Dictionary
				and (outcome as Dictionary).get("gold") == expected_outcome["gold"]
				and (outcome as Dictionary).get("scraps") == expected_outcome["scraps"],
				"the anchor keeps its original outcome: " + anchor_id + " / " + str(choice_id))

## AC4: the no-argument shipped rotation validates, admits each new record
## exactly once and keeps the named earlier anchors eligible.
func _test_rotation_membership() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1,
			"the eligible pool carries " + event_id + " exactly once")
	for anchor_id in ANCHORS:
		_check(ids.count(anchor_id) == 1,
			"the named earlier anchor stays eligible: " + anchor_id)

## AC2: funded previews and receipts agree with the independent settlement
## table on all nine authored choices, one fresh visit each; a settled choice
## cannot be replayed; results and inputs stay detached.
func _test_funded_wallet() -> void:
	var funded := FUNDED.duplicate(true)
	var funded_snapshot: Dictionary = funded.duplicate(true)
	var settlements := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var final_table: Dictionary = FUNDED_FINAL[event_id]
		_check(final_table.size() == 3,
			"the independent funded table covers three choices: " + event_id)
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			var after: Dictionary = final_table[choice_id]
			_check(after["gold"] == 50 + int(definition["gold"])
				and after["scraps"] == 5 + int(definition["scraps"]),
				"the independent funded table agrees with the authored deltas: " + event_id + " / " + choice_id)
			var service := RunEventChoice.new(record)
			var preview := service.preview_wallet_choices(funded)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview succeeds: " + event_id + " / " + choice_id)
			var row: Dictionary = _preview_map(preview).get(choice_id, {})
			_check(row.get("gold_delta") == definition["gold"]
				and row.get("scraps_delta") == definition["scraps"],
				"funded preview reports authored deltas: " + event_id + " / " + choice_id)
			_check(row.get("affordable") == true and row.get("wallet") == after,
				"funded preview forecasts the exact balance: " + event_id + " / " + choice_id)
			var receipt := service.choose_with_wallet(choice_id, funded)
			_check(receipt == {
				"ok": true, "event_id": event_id, "choice_id": choice_id, "wallet": after,
			}, "the claim settles the independent funded balance: " + event_id + " / " + choice_id)
			settlements += 1
			_check(service.is_claimed() and not service.is_valid(),
				"the claim latches and closes the visit: " + event_id + " / " + choice_id)
			var replay := service.choose_with_wallet(choice_id, funded)
			_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": funded},
				"the settled claim cannot be replayed: " + event_id + " / " + choice_id)
			_check(record == record_snapshot and funded == funded_snapshot,
				"a funded flow never mutates the record or its purse: " + event_id + " / " + choice_id)
	_check(settlements == 9, "every authored choice settles once when funded")
	_check(funded == funded_snapshot, "the caller wallet survives every settlement untouched")

## AC3: at an empty purse every priced choice is previewed unaffordable and
## refused without a claim or mutation, every free Leave settles without a
## balance change, the Portrait Booth's portrait earns 12 gold and the Thunder
## Drum's rivets earn 2 scraps.
func _test_scarce_wallets() -> void:
	var zero := SCARCE.duplicate(true)
	var zero_snapshot: Dictionary = zero.duplicate(true)
	var refusals := 0
	for event_id in EXPECTED:
		var contract: Dictionary = EXPECTED[event_id]
		var record: Dictionary = (source_by_id[event_id] as Dictionary).duplicate(true)
		var record_snapshot: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var rows: Dictionary = _preview_map(service.preview_wallet_choices(zero))
		for choice_def in contract["choices"]:
			var definition: Dictionary = choice_def
			var choice_id: String = definition["id"]
			if int(definition["gold"]) >= 0 and int(definition["scraps"]) >= 0:
				continue
			_check(rows.get(choice_id, {}).get("affordable") == false,
				"an empty purse cannot afford the debit: " + event_id + " / " + choice_id)
			var refused := service.choose_with_wallet(choice_id, zero)
			_check(refused == {"ok": false, "event_id": "", "choice_id": "", "wallet": zero},
				"an empty purse refuses the debit unchanged: " + event_id + " / " + choice_id)
			_check(service.is_valid() and not service.is_claimed(),
				"a refused debit keeps the visit open: " + event_id + " / " + choice_id)
			refusals += 1
		var leave_service := RunEventChoice.new(record)
		var leave_receipt := leave_service.choose_with_wallet("leave", zero)
		_check(leave_receipt == {
			"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": SCARCE,
		}, "an empty purse still settles its free Leave without a balance change: " + event_id)
		_check(leave_service.is_claimed() and not leave_service.is_valid()
			and leave_service.choose_with_wallet("leave", zero).get("ok") == false,
			"the empty-purse Leave cannot be replayed: " + event_id)
		_check(zero == zero_snapshot and record == record_snapshot,
			"no scarce flow mutates the purse or the record: " + event_id)
	_check(refusals == 4, "every priced debit is refused at an empty purse")
	var booth := RunEventChoice.new(source_by_id["v3_bone_bellows_portrait_booth"])
	var portrait := booth.choose_with_wallet("pose_for_portrait", SCARCE)
	_check(portrait == {
		"ok": true, "event_id": "v3_bone_bellows_portrait_booth",
		"choice_id": "pose_for_portrait", "wallet": {"gold": 12, "scraps": 0},
	}, "the free stitched portrait earns exactly 12 gold from an empty purse")
	var drum := RunEventChoice.new(source_by_id["v3_blacklace_thunder_drum"])
	var rivets := drum.choose_with_wallet("salvage_loose_rivets", SCARCE)
	_check(rivets == {
		"ok": true, "event_id": "v3_blacklace_thunder_drum",
		"choice_id": "salvage_loose_rivets", "wallet": {"gold": 0, "scraps": 2},
	}, "the free copper rivets settle to exactly two scraps from an empty purse")

## AC3: one unit short of every priced cost, the choice is refused without
## latching or spending, and the same visit still settles its free Leave.
func _test_boundary_refusals() -> void:
	for entry_def in BOUNDARY_REFUSALS:
		var entry: Dictionary = entry_def
		var event_id: String = entry["event"]
		var choice_id: String = entry["choice"]
		var purse: Dictionary = (entry["wallet"] as Dictionary).duplicate(true)
		var purse_snapshot: Dictionary = purse.duplicate(true)
		var service := RunEventChoice.new(source_by_id[event_id])
		var rows: Dictionary = _preview_map(service.preview_wallet_choices(purse))
		_check(rows.get(choice_id, {}).get("affordable") == false,
			"a one-unit-short purse previews the debit unaffordable: " + event_id + " / " + choice_id)
		var refused := service.choose_with_wallet(choice_id, purse)
		_check(refused == {"ok": false, "event_id": "", "choice_id": "", "wallet": purse},
			"a one-unit-short purse refuses the debit unchanged: " + event_id + " / " + choice_id)
		_check(service.is_valid() and not service.is_claimed(),
			"the failed boundary attempt does not latch: " + event_id + " / " + choice_id)
		var leave_receipt := service.choose_with_wallet("leave", purse)
		_check(leave_receipt == {
			"ok": true, "event_id": event_id, "choice_id": "leave", "wallet": purse,
		}, "Leave still succeeds after a boundary refusal: " + event_id + " / " + choice_id)
		_check(purse == purse_snapshot,
			"a boundary refusal and Leave never mutate the purse: " + event_id + " / " + choice_id)

## AC3: an unknown choice ID fails without claiming or spending, and the same
## visit still settles its free Leave exactly once.
func _test_unknown_choice() -> void:
	var funded := FUNDED.duplicate(true)
	for event_id in EXPECTED:
		var service := RunEventChoice.new(source_by_id[event_id])
		var forged := service.choose_with_wallet("forged_choice", funded)
		_check(forged == {"ok": false, "event_id": "", "choice_id": "", "wallet": funded},
			"an unknown choice ID is refused unchanged: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"an unknown choice ID keeps the visit open: " + event_id)
		var leave_receipt := service.choose_with_wallet("leave", funded)
		_check(leave_receipt == {
			"ok": true, "event_id": event_id, "choice_id": "leave",
			"wallet": FUNDED_FINAL[event_id]["leave"],
		}, "Leave still succeeds after a forged refusal: " + event_id)
		_check(service.is_claimed() and not service.is_valid()
			and service.choose_with_wallet("leave", funded).get("ok") == false,
			"the post-forged Leave claim latches once: " + event_id)
	_check(funded == FUNDED, "forged-ID flows never mutate the purse")

## AC4: with dynamic exclusions built from the CURRENT eligible ID list, each
## new record is selected alone through the real seeded selector on both the
## generic and the actionable route; two equal seeds replay the same result;
## the Brass-Ear event is not actionable at an empty purse while the two
## free-gain events are; and an exhausted pool rejects without consuming RNG.
func _test_forced_selection() -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped catalogs validate in the default selector")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > EXPECTED.size(),
		"the eligible pool holds more than this batch, so exclusions are meaningful")
	for event_id in EXPECTED:
		_check(ids.count(event_id) == 1, "the eligible pool carries " + event_id + " once")
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only " + event_id + " stays eligible")
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "forced selection succeeds: " + event_id)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "forced selection returns " + event_id)
		_check(selected == source_by_id[event_id],
			"the selection is the authentic authored record: " + event_id)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + event_id)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state,
			"identical seed and exclusions replay " + event_id)
		var action_rng := RandomNumberGenerator.new()
		action_rng.seed = seed_value
		var action_oracle := RandomNumberGenerator.new()
		action_oracle.seed = seed_value
		action_oracle.randi_range(0, 0)
		var actionable := rotation.select_actionable_event(action_rng, excluded, FUNDED)
		_check(actionable.get("ok") == true,
			"the funded wallet keeps " + event_id + " actionable")
		_check(actionable.get("event", {}).get("id") == event_id,
			"the forced actionable route returns " + event_id)
		_check(action_rng.state == action_oracle.state,
			"the forced actionable draw consumes exactly one range draw: " + event_id)
	# Empty-purse actionable filtering through the same dynamic exclusions.
	var brass_excluded: Array = ids.duplicate()
	brass_excluded.erase("v3_brass_ear_listening_post")
	var brass_guard := RandomNumberGenerator.new()
	brass_guard.seed = 292929
	var brass_state: int = brass_guard.state
	var brass_scarce := rotation.select_actionable_event(brass_guard, brass_excluded, SCARCE)
	_check(brass_scarce.get("ok") == false,
		"the Brass-Ear event is not actionable at an empty purse")
	_check(brass_guard.state == brass_state,
		"a non-actionable empty-purse event consumes no RNG")
	for free_gain_id in ["v3_bone_bellows_portrait_booth", "v3_blacklace_thunder_drum"]:
		var excluded: Array = ids.duplicate()
		excluded.erase(free_gain_id)
		var scarce_rng := RandomNumberGenerator.new()
		scarce_rng.seed = SEEDS[free_gain_id]
		var scarce_oracle := RandomNumberGenerator.new()
		scarce_oracle.seed = SEEDS[free_gain_id]
		scarce_oracle.randi_range(0, 0)
		var scarce_action := rotation.select_actionable_event(scarce_rng, excluded, SCARCE)
		_check(scarce_action.get("ok") == true
			and scarce_action.get("event", {}).get("id") == free_gain_id,
			"the empty purse keeps the free-gain event actionable: " + free_gain_id)
		_check(scarce_rng.state == scarce_oracle.state,
			"the empty-purse actionable draw consumes exactly one range draw: " + free_gain_id)
	# Excluding every current pool ID rejects without consuming RNG state.
	var guard := RandomNumberGenerator.new()
	guard.seed = 393939
	var guard_state: int = guard.state
	_check(rotation.select_event(guard, ids).get("ok") == false,
		"excluding every eligible event rejects the generic selection")
	_check(rotation.select_actionable_event(guard, ids, FUNDED).get("ok") == false,
		"excluding every eligible event rejects the actionable selection")
	_check(guard.state == guard_state,
		"an exhausted pool consumes no RNG on either route")

## Verbatim presentation, choice shape and signed deltas against the
## independent table. `origin` only labels failure messages.
func _check_record_contract(record: Variant, event_id: String, contract: Dictionary,
		origin: String) -> void:
	_check(record is Dictionary, "the " + origin + " record is an object: " + event_id)
	if not record is Dictionary:
		return
	var authored: Dictionary = record
	_check(authored.size() == 4 and authored.has("id") and authored.has("title")
		and authored.has("description") and authored.has("choices"),
		"exactly id/title/description/choices: " + origin + " / " + event_id)
	_check(authored.get("id") == event_id, "authored ID: " + origin + " / " + event_id)
	_check(authored.get("title") == contract["title"], "authored title: " + origin + " / " + event_id)
	_check(authored.get("description") == contract["description"],
		"authored description: " + origin + " / " + event_id)
	var choices: Variant = authored.get("choices")
	_check(choices is Array, "authored choices array: " + origin + " / " + event_id)
	if not choices is Array:
		return
	_check((choices as Array).size() == 3, "exactly three choices: " + origin + " / " + event_id)
	var by_id: Dictionary = {}
	for choice in (choices as Array):
		_check(choice is Dictionary, "every choice is an object: " + origin + " / " + event_id)
		if not choice is Dictionary:
			continue
		var entry: Dictionary = choice
		var choice_id: Variant = entry.get("id")
		_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
			"every choice has a nonblank string ID: " + origin + " / " + event_id)
		if not choice_id is String:
			continue
		_check(not by_id.has(choice_id),
			"choice IDs are distinct: " + origin + " / " + event_id + " / " + str(choice_id))
		by_id[choice_id] = entry
	_check(by_id.size() == 3, "three distinct choice IDs: " + origin + " / " + event_id)
	for choice_def in contract["choices"]:
		var definition: Dictionary = choice_def
		var choice_id: String = definition["id"]
		_check(by_id.has(choice_id),
			"authored choice present: " + origin + " / " + event_id + " / " + choice_id)
		if not by_id.has(choice_id):
			continue
		var entry: Dictionary = by_id[choice_id]
		_check(entry.size() == 3 and entry.has("id") and entry.has("text")
			and entry.has("outcome"),
			"exactly id/text/outcome: " + origin + " / " + event_id + " / " + choice_id)
		_check(entry.get("text") == definition["text"],
			"authored choice text: " + origin + " / " + event_id + " / " + choice_id)
		var outcome: Variant = entry.get("outcome")
		_check(outcome is Dictionary,
			"choice outcome is an object: " + origin + " / " + event_id + " / " + choice_id)
		if not outcome is Dictionary:
			continue
		var wallet_outcome: Dictionary = outcome
		_check(wallet_outcome.size() == 2 and wallet_outcome.has("gold")
			and wallet_outcome.has("scraps"),
			"exactly gold/scraps outcome keys: " + origin + " / " + event_id + " / " + choice_id)
		var gold_amount: Variant = _signed_amount(wallet_outcome.get("gold"))
		var scraps_amount: Variant = _signed_amount(wallet_outcome.get("scraps"))
		_check(gold_amount != null and scraps_amount != null,
			"whole-number outcome amounts: " + origin + " / " + event_id + " / " + choice_id)
		_check(gold_amount == definition["gold"] and scraps_amount == definition["scraps"],
			"authored signed outcome: " + origin + " / " + event_id + " / " + choice_id)

## The authored signed amount as an int, or null when the JSON value is not a
## finite whole number.
func _signed_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= 9007199254740992.0:
			return int(number)
	return null

func _preview_map(preview: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Variant = preview.get("choices")
	if not entries is Array:
		return out
	for entry in entries:
		if entry is Dictionary:
			out[entry["choice_id"]] = entry
	return out
