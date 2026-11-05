extends SceneTree
## Scene-free contract coverage for the three appended Stitched midnight
## object-trade roadside stories in the shared roadside catalog. The authored
## JSON is parsed directly, every new record is checked against its authored
## prose and wallet table, and all settlement, refusal and fail-closed paths
## run through the real RunEventChoice service on independent fresh
## selectors. The default RunM04EventRotation admits every new ID, a forced
## exclusion selection returns the verbatim record on exactly one range draw,
## and rejected or exhausted requests consume no RNG. A replicated
## gold/scraps-only Stitched conversion is proven through
## RunStitchedEventConsequence. The catalog's total size and global order are
## deliberately never asserted.

const PATH := "res://data/events/v3_roadside_events.json"
const FUNDED_WALLET := {"gold": 60, "scraps": 6}

## Earlier roadside anchors whose authored content must stay unchanged; a
## shared catalog grows in parallel, so only named-ID content is asserted.
const ANCHOR_RECORDS := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": [
			["salvage_hems", "Salvage loose hems (+1 scrap)", 0, 1],
			["trade_fare", "Trade fare for threads (-12 gold, +2 scraps)", -12, 2],
			["take_detour", "Take a detour (Leave)", 0, 0],
		],
	},
	"v3_thimble_raincollector": {
		"title": "The Thimble Rain-Collector",
		"description": "A squat plum-cloth rainkeeper balances an inverted brass thimble above a gutter of black-glass buttons; candlelit drops ring into its rim.",
		"choices": [
			["collect_gutter_offcuts", "Collect loose rain-washed gutter thread (+1 scrap)", 0, 1],
			["mend_thimble_gutter", "Spend 2 scraps mending the thimble gutter (gain 26 gold)", 26, -2],
			["leave", "Follow the rain beyond the thimble roof", 0, 0],
		],
	},
	"v3_button_glass_windowmaker": {
		"title": "The Button-Glass Windowmaker",
		"description": "A plump bone-cream mitten puppet hauls huge stained-glass buttons up an iron window frame; one ruby thread binds the cracked panes.",
		"choices": [
			["buy_window_cord", "Pay 26 gold for four coils of window-mending cord (+4 scraps)", -26, 4],
			["patch_broken_pane", "Spend 1 scrap patching a button-glass pane (earn 17 gold)", 17, -1],
			["leave", "Leave the crimson window glowing in the fog", 0, 0],
		],
	},
}

## Choice rows are [id, text, gold, scraps, settled {gold, scraps}] where the
## settled balance comes from the funded {gold: 60, scraps: 6} wallet.
## gold_short/scraps_short are [paid choice ID, wallet that must refuse it,
## recover choice ID, settled recover wallet]; the measureworm prices no gold
## branch, so its gold_short is omitted and its scrap refusal is followed by
## the collect_tape_tail gain.
const NEW_RECORDS := {
	"v3_mourning_keykeeper": {
		"title": "The Mourning Keykeeper",
		"description": "Beneath a cracked cabinet door, a round plum ragdoll bears a brass winding key larger than itself; candlelight catches the frayed lock tassels.",
		"choices": [
			["buy_key_thread", "Pay 21 gold for two coils of keyhole thread (+2 scraps)", -21, 2, {"gold": 39, "scraps": 8}],
			["reset_rusty_winder", "Spend 2 scraps resetting the giant key (earn 27 gold)", 27, -2, {"gold": 87, "scraps": 4}],
			["leave", "Leave the winding key to click in the dark", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_key_thread", {"gold": 20, "scraps": 6}, "leave", {"gold": 20, "scraps": 6}],
		"scraps_short": ["reset_rusty_winder", {"gold": 60, "scraps": 1}, "leave", {"gold": 60, "scraps": 1}],
	},
	"v3_measureworm_survey": {
		"title": "The Measureworm Survey",
		"description": "A plump tape-measure worm loops round a crooked bedpost, its button eyes counting every loose stitch on the ruler sewn along its back.",
		"choices": [
			["collect_tape_tail", "Gather a fallen tape tail (+1 scrap)", 0, 1, {"gold": 60, "scraps": 7}],
			["reline_measure_spool", "Spend 1 scrap repairing the ruler spool (earn 17 gold)", 17, -1, {"gold": 77, "scraps": 5}],
			["leave", "Let the measureworm finish its slow count", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"scraps_short": ["reline_measure_spool", {"gold": 60, "scraps": 0}, "collect_tape_tail", {"gold": 60, "scraps": 1}],
	},
	"v3_velvet_mousetrap_stage": {
		"title": "The Velvet Mousetrap Stage",
		"description": "An enormous sprung brass mousetrap holds a tiny velvet-curtained stage; a rounded mouse doll raises a safety pin above its amber footlight.",
		"choices": [
			["buy_safety_silk", "Pay 28 gold for three bundles of safety silk (+3 scraps)", -28, 3, {"gold": 32, "scraps": 9}],
			["mend_trap_spring", "Spend 2 scraps mending the sprung hinge (earn 24 gold)", 24, -2, {"gold": 84, "scraps": 4}],
			["leave", "Leave the mouse doll under its little spotlight", 0, 0, {"gold": 60, "scraps": 6}],
		],
		"gold_short": ["buy_safety_silk", {"gold": 27, "scraps": 6}, "leave", {"gold": 27, "scraps": 6}],
		"scraps_short": ["mend_trap_spring", {"gold": 60, "scraps": 1}, "leave", {"gold": 60, "scraps": 1}],
	},
}

## Independent per-ID seeds for the forced single-eligible selection replay.
## With one eligible ID the seed cannot pin a catalog position.
const SEEDS := {
	"v3_mourning_keykeeper": 1020291,
	"v3_measureworm_survey": 1020292,
	"v3_velvet_mousetrap_stage": 1020293,
}

const DENIED_PREVIEW := {"ok": false, "event_id": "", "choices": []}

var failures: Array[String] = []
var checks := 0
## Which fail-closed kind each new Event actually exercised: {event_id: {kind: true}}.
var exercised := {}


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _nonblank(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


## Godot JSON parses integer tokens as floats; require exact integral values.
func _integral_exact(value: Variant, wanted: int) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and value == wanted


func _initialize() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	_check(file != null, "catalog opens")
	if file != null:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		_check(error == OK, "catalog parses")
		if error == OK:
			var document: Variant = json.data
			_check(document is Dictionary and document.get("events") is Array, "events array exists")
			if document is Dictionary and document.get("events") is Array:
				var records: Array = document.events
				var snapshot: Array = records.duplicate(true)
				var by_id := {}
				for record in records:
					if record is Dictionary and (record as Dictionary).get("id") is String:
						by_id[(record as Dictionary).get("id")] = record
				_test_anchors(records)
				for event_id in NEW_RECORDS:
					_test_new_record(records, event_id)
				_test_rotation(by_id)
				_test_stitched_conversion(by_id)
				_check(records == snapshot, "all authored inputs remain unchanged")
	for failure in failures:
		printerr(failure)
	print("v3_stitched_midnight_object_roadside_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _find(records: Array, event_id: String) -> Array:
	return records.filter(func(record): return record is Dictionary and record.get("id") == event_id)


func _test_anchors(records: Array) -> void:
	for event_id in ANCHOR_RECORDS:
		var expected: Dictionary = ANCHOR_RECORDS[event_id]
		var matches: Array = _find(records, event_id)
		_check(matches.size() == 1, "anchor ID occurs exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == expected.title, "anchor title unchanged: " + event_id)
		_check(record.get("description") == expected.description, "anchor description unchanged: " + event_id)
		var choices: Array = record.get("choices", [])
		_check(choices.size() == expected.choices.size(), "anchor choice count unchanged: " + event_id)
		var by_id := {}
		for choice in choices:
			if choice is Dictionary:
				by_id[choice.get("id")] = choice
		for row in expected.choices:
			var choice_id: String = row[0]
			var tag: String = event_id + "/" + choice_id
			_check(by_id.has(choice_id), "anchor choice present: " + tag)
			if not by_id.has(choice_id):
				continue
			var choice: Dictionary = by_id[choice_id]
			_check(choice.get("text") == row[1], "anchor choice text unchanged: " + tag)
			var outcome: Dictionary = choice.get("outcome", {})
			_check(outcome.size() == 2 and _integral_exact(outcome.get("gold"), row[2])
				and _integral_exact(outcome.get("scraps"), row[3]),
				"anchor outcome unchanged: " + tag)
		var selector := RunEventChoice.new(record)
		_check(selector.is_valid() and not selector.is_claimed(),
			"anchor builds a valid fresh selector: " + event_id)


func _test_new_record(records: Array, event_id: String) -> void:
	var expected: Dictionary = NEW_RECORDS[event_id]
	var tag: String = event_id
	var matches: Array = _find(records, event_id)
	_check(matches.size() == 1, "new ID occurs exactly once: " + tag)
	if matches.size() != 1:
		return
	var record: Dictionary = matches[0]
	_check(record.size() == 4 and record.has("id") and record.has("title")
		and record.has("description") and record.has("choices"),
		"new record keeps only id/title/description/choices: " + tag)
	_check(record.get("title") == expected.title, "new title exact: " + tag)
	_check(record.get("description") == expected.description, "new description exact: " + tag)
	var choices: Variant = record.get("choices")
	_check(choices is Array and (choices as Array).size() == 3, "new record authors exactly three choices: " + tag)
	if not choices is Array:
		return
	var by_id := {}
	for choice in choices:
		_check(choice is Dictionary, "new choice record: " + tag)
		if not choice is Dictionary:
			continue
		var raw_choice: Dictionary = choice
		_check(raw_choice.size() == 3 and raw_choice.has("id") and raw_choice.has("text")
			and raw_choice.has("outcome"), "new choice keeps only id/text/outcome: " + tag)
		var raw_id: Variant = raw_choice.get("id")
		_check(_nonblank(raw_id) and not by_id.has(raw_id), "distinct nonblank new choice ID: " + tag)
		if raw_id is String:
			by_id[raw_id] = raw_choice
	var wanted: Array = expected.choices
	_check(by_id.size() == wanted.size(), "new choice count matches the authored table: " + tag)
	for row in wanted:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		_check(by_id.has(choice_id), "required new choice exists: " + choice_tag)
		if not by_id.has(choice_id):
			continue
		var choice: Dictionary = by_id[choice_id]
		_check(choice.get("text") == row[1], "new choice text exact: " + choice_tag)
		var outcome: Variant = choice.get("outcome")
		_check(outcome is Dictionary and (outcome as Dictionary).size() == 2
			and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps"),
			"new outcome carries precisely gold/scraps: " + choice_tag)
		if outcome is Dictionary:
			_check(_integral_exact((outcome as Dictionary).get("gold"), row[2])
				and _integral_exact((outcome as Dictionary).get("scraps"), row[3]),
				"new outcome exact signed deltas: " + choice_tag)
	_check(by_id.has("leave"), "new record offers a Leave choice: " + tag)
	if by_id.has("leave"):
		var leave_outcome: Variant = (by_id["leave"] as Dictionary).get("outcome")
		_check(leave_outcome is Dictionary
			and _integral_exact((leave_outcome as Dictionary).get("gold"), 0)
			and _integral_exact((leave_outcome as Dictionary).get("scraps"), 0),
			"Leave is free: " + tag)
	_test_preview_and_settlements(record, expected)
	if expected.has("gold_short"):
		_test_short_refusal(record, expected.gold_short, "gold-short")
	_test_short_refusal(record, expected.scraps_short, "scraps-short")
	_test_unknown_choice(record)
	_test_repeated_claim(record, expected)
	var kinds: Dictionary = exercised.get(event_id, {})
	var needed := ["scraps-short", "unknown", "repeated"]
	if expected.has("gold_short"):
		needed.append("gold-short")
	for kind in needed:
		_check(kinds.get(kind, false), "new Event exercised fail-closed witness " + kind + ": " + tag)


func _preview_entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


## Funded preview plus one fresh committing selector per authored branch, each
## settling independently from the same {gold: 60, scraps: 6} wallet.
func _test_preview_and_settlements(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	_check(selector.is_valid() and not selector.is_claimed(), "valid fresh selector: " + tag)
	var preview := selector.preview_wallet_choices(FUNDED_WALLET)
	_check(preview.get("ok") == true and preview.get("event_id") == record.id, "funded preview available: " + tag)
	_check(selector.is_valid() and not selector.is_claimed(), "preview consumes no visit: " + tag)
	var entries: Variant = preview.get("choices")
	_check(entries is Array and (entries as Array).size() == expected.choices.size(),
		"preview covers every authored choice: " + tag)
	for row in expected.choices:
		var choice_id: String = row[0]
		var choice_tag: String = tag + "/" + choice_id
		var forecast := _preview_entry(preview, choice_id)
		_check(not forecast.is_empty() and forecast.get("gold_delta") == row[2]
			and forecast.get("scraps_delta") == row[3] and forecast.get("affordable") == true
			and forecast.get("wallet") == row[4],
			"funded preview forecasts the exact balance: " + choice_tag)
		var branch := RunEventChoice.new(record)
		var wallet := {"gold": 60, "scraps": 6}
		var receipt := branch.choose_with_wallet(choice_id, wallet)
		_check(receipt == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": row[4]},
			"fresh selector settles the exact independent balance: " + choice_tag)
		_check(branch.is_claimed() and not branch.is_valid(),
			"success claims the visit exactly once: " + choice_tag)
		_check(wallet == FUNDED_WALLET and record == original,
			"settlement preserves caller wallet and event data: " + choice_tag)
	_check(selector.get_event() == original, "service event detached and unchanged: " + tag)


## One short-resource witness: the paid choice is unaffordable, the refusal
## keeps the wallet, the record and the unclaimed visit intact, and the free
## Leave (or the measureworm's collect_tape_tail gain) still settles that
## same visit.
func _test_short_refusal(record: Dictionary, witness: Array, kind: String) -> void:
	var choice_id: String = witness[0]
	var wallet: Dictionary = (witness[1] as Dictionary).duplicate(true)
	var recover_id: String = witness[2]
	var recover_wallet: Dictionary = witness[3]
	var before: Dictionary = wallet.duplicate(true)
	var original: Dictionary = record.duplicate(true)
	var tag: String = record.id + "/" + choice_id + "/" + kind
	var selector := RunEventChoice.new(record)
	var forecast := _preview_entry(selector.preview_wallet_choices(wallet), choice_id)
	_check(not forecast.is_empty() and forecast.get("affordable") == false
		and forecast.get("wallet") == before,
		kind + " wallet previews the paid choice unavailable: " + tag)
	var receipt := selector.choose_with_wallet(choice_id, wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		kind + " wallet refuses the paid choice unchanged: " + tag)
	_check(wallet == before and record == original and selector.is_valid() and not selector.is_claimed(),
		kind + " refusal preserves inputs and leaves the visit unclaimed: " + tag)
	receipt.wallet.gold += 999
	_check(wallet == before, kind + " refusal wallet detached: " + tag)
	var recover := selector.choose_with_wallet(recover_id, wallet)
	_check(recover == {"ok": true, "event_id": record.id, "choice_id": recover_id, "wallet": recover_wallet}
		and selector.is_claimed() and not selector.is_valid(),
		"the still-legal choice settles the refused visit: " + tag)
	_check(wallet == before and record == original, "the legal recovery preserves inputs: " + tag)
	_mark_exercised(record.id, kind)


## An unknown choice ID denies without spending, claiming or changing anything,
## and the free Leave remains usable on that same unclaimed visit.
func _test_unknown_choice(record: Dictionary) -> void:
	var tag: String = record.id
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 60, "scraps": 6}
	var before := wallet.duplicate(true)
	var receipt := selector.choose_with_wallet("no_such_roadside_choice", wallet)
	_check(receipt == {"ok": false, "event_id": "", "choice_id": "", "wallet": before},
		"unknown choice ID denies the visit: " + tag)
	_check(wallet == before and record == original and selector.is_valid() and not selector.is_claimed(),
		"unknown-ID denial preserves inputs and leaves the visit unclaimed: " + tag)
	var leave := selector.choose_with_wallet("leave", wallet)
	_check(leave == {"ok": true, "event_id": record.id, "choice_id": "leave", "wallet": before},
		"free Leave remains usable after an unknown-ID denial: " + tag)
	_check(wallet == before and record == original, "free Leave preserves inputs after denial: " + tag)
	_mark_exercised(record.id, "unknown")


## A settled visit denies every repeated claim with the same wallet and exactly
## one claim latched; the service supplies the fail-closed behavior.
func _test_repeated_claim(record: Dictionary, expected: Dictionary) -> void:
	var tag: String = record.id
	var row: Array = expected.choices[0]
	var choice_id: String = row[0]
	var original: Dictionary = record.duplicate(true)
	var selector := RunEventChoice.new(record)
	var wallet := {"gold": 60, "scraps": 6}
	var first := selector.choose_with_wallet(choice_id, wallet)
	_check(first == {"ok": true, "event_id": record.id, "choice_id": choice_id, "wallet": row[4]},
		"repeated-claim visit settles once: " + tag)
	var settled: Dictionary = first.wallet.duplicate(true)
	var replay := selector.choose_with_wallet(choice_id, settled)
	_check(replay == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
		"repeated claim denies without another settlement: " + tag)
	var leave := selector.choose_with_wallet("leave", settled)
	_check(leave == {"ok": false, "event_id": "", "choice_id": "", "wallet": settled},
		"claimed visit denies every later choice: " + tag)
	_check(selector.is_claimed() and not selector.is_valid() and settled == row[4]
		and wallet == FUNDED_WALLET and record == original,
		"repeated-claim denial leaves the same wallet and exactly one claim: " + tag)
	_check(selector.preview_wallet_choices(settled) == DENIED_PREVIEW,
		"claimed visit refuses a second preview: " + tag)
	_mark_exercised(record.id, "repeated")


## The default merged selector admits every new ID; excluding every other
## offered ID forces one seeded selection that returns the verbatim authored
## record on exactly one range draw, and invalid or exhausted requests refuse
## before consuming any RNG state.
func _test_rotation(by_id: Dictionary) -> void:
	var rotation := RunM04EventRotation.new()
	_check(rotation.is_catalog_valid(), "the default selector validates the merged catalogs")
	if not rotation.is_catalog_valid():
		return
	var ids: Array = rotation.get_generic_event_ids()
	_check(ids.size() > NEW_RECORDS.size(),
		"the default pool holds more than the new batch, so exclusions are meaningful")
	for event_id in NEW_RECORDS:
		var tag: String = event_id
		_check(ids.count(event_id) == 1, "the default selector admits the new ID exactly once: " + tag)
		var source: Dictionary = by_id.get(event_id, {})
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		_check(not excluded.has(event_id) and excluded.size() == ids.size() - 1,
			"only the named new tale stays eligible: " + tag)
		var seed_value: int = SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var picked := rotation.select_event(rng, excluded)
		_check(picked.get("ok") == true, "the forced selection succeeds: " + tag)
		var selected: Dictionary = picked.get("event", {})
		_check(selected.get("id") == event_id, "the forced selection is the named tale: " + tag)
		_check(selected == source, "the forced selection is the authentic authored record: " + tag)
		_check(rng.state == oracle.state, "a forced selection consumes exactly one range draw: " + tag)
		var replay_rng := RandomNumberGenerator.new()
		replay_rng.seed = seed_value
		var replay := rotation.select_event(replay_rng, excluded)
		_check(replay.get("ok") == true and replay.get("event") == selected
			and replay_rng.state == rng.state, "the same seed and exclusions replay " + tag)
	# Rejections must consume no RNG state: a non-RNG caller, malformed
	# exclusions and an exhausted pool all refuse before any draw.
	var guard := RandomNumberGenerator.new()
	guard.seed = 1020290
	var guard_state: int = guard.state
	_check(rotation.select_event(null).get("ok") == false, "a non-RNG caller is refused")
	_check(rotation.select_event("not-a-generator").get("ok") == false, "a non-RNG value is refused")
	_check(rotation.select_event(guard, "not-an-array").get("ok") == false,
		"malformed exclusions are refused")
	_check(rotation.select_event(guard, [""]).get("ok") == false, "a blank exclusion entry is refused")
	_check(guard.state == guard_state, "malformed requests consume no RNG draw")
	var exhausted: Array = ids.duplicate()
	_check(rotation.select_event(guard, exhausted).get("ok") == false,
		"an exhausted pool refuses the request")
	_check(guard.state == guard_state, "the exhausted refusal consumes no RNG draw")


## Replicates the session's documented gold/scraps-only conversion (a
## {gold, scraps} wallet outcome becomes a party stitched_effect with zero
## candle and fray) and proves the converted records express only the
## already-supported gold/scraps effects through RunStitchedEventConsequence.
func _test_stitched_conversion(by_id: Dictionary) -> void:
	var snapshot := {"candle": 50, "party": [{"id": "warden", "fray": 0}], "gold": 60, "scraps": 6}
	for event_id in NEW_RECORDS:
		var tag: String = event_id
		var source: Dictionary = by_id.get(event_id, {})
		_check(not source.is_empty(), "the converted record has a source: " + tag)
		if source.is_empty():
			continue
		var converted := source.duplicate(true)
		var choices_array: Array = []
		var wallet_only := true
		for choice in converted.get("choices", []):
			var outcome: Dictionary = choice.get("outcome", {})
			for key in outcome:
				if key != "gold" and key != "scraps":
					wallet_only = false
			choices_array.append({"id": choice.id, "text": choice.text,
				"stitched_effect": {"target": "party", "candle": 0, "fray": 0,
					"gold": int(outcome.get("gold", 0)), "scraps": int(outcome.get("scraps", 0))}})
		_check(wallet_only, "every authored outcome is gold/scraps-only: " + tag)
		converted.choices = choices_array
		var service := RunStitchedEventConsequence.new(converted)
		_check(service.is_valid() and not service.is_claimed(),
			"the converted record builds a valid fresh Stitched consequence: " + tag)
		var preview := service.preview(snapshot)
		_check(preview.get("ok") == true and preview.get("event_id") == event_id,
			"the converted record previews against a live snapshot: " + tag)
		var rows := {}
		for entry in preview.get("choices", []):
			rows[entry.get("choice_id")] = entry
		_check(rows.size() == NEW_RECORDS[event_id].choices.size(),
			"the converted preview lists every authored choice: " + tag)
		for row in NEW_RECORDS[event_id].choices:
			var choice_id: String = row[0]
			var choice_tag: String = tag + "/" + choice_id
			var entry: Dictionary = rows.get(choice_id, {})
			_check(not entry.is_empty(), "the converted preview keeps its choice slot: " + choice_tag)
			if entry.is_empty():
				continue
			_check(entry.get("target") == "party" and entry.get("candle_delta") == 0
				and entry.get("fray_delta") == 0 and entry.get("fray", {}) == {},
				"the converted effect carries no candle or fray intent: " + choice_tag)
			_check(entry.get("gold_delta") == row[2] and entry.get("scraps_delta") == row[3],
				"the converted effect reports the authored deltas: " + choice_tag)
			_check(entry.get("available") == true and entry.get("gold") == row[4].get("gold")
				and entry.get("scraps") == row[4].get("scraps"),
				"the converted effect projects the funded balances: " + choice_tag)
			_check(not entry.has("part") and not entry.has("hp_delta"),
				"the converted effect awards no part or hp: " + choice_tag)
		# One committed conversion settles only the gold/scraps effects.
		var first: Array = NEW_RECORDS[event_id].choices[0]
		var receipt := service.choose(first[0], snapshot)
		_check(receipt.get("ok") == true and receipt.get("event_id") == event_id
			and receipt.get("choice_id") == first[0],
			"the converted claim settles once: " + tag)
		_check(receipt.get("target") == "party" and receipt.get("hero_id", "") == ""
			and receipt.get("candle") == 50 and receipt.get("fray", {}) == {},
			"the converted receipt touches no candle, fray or hero: " + tag)
		_check(receipt.get("gold_delta") == first[2] and receipt.get("scraps_delta") == first[3]
			and receipt.get("gold") == first[4].get("gold") and receipt.get("scraps") == first[4].get("scraps"),
			"the converted receipt settles the exact gold/scraps balances: " + tag)
		_check(not receipt.has("part") and not receipt.has("hp_delta"),
			"the converted receipt awards no part or hp: " + tag)
		_check(service.is_claimed() and not service.is_valid(),
			"the converted claim latches the visit exactly once: " + tag)


func _mark_exercised(event_id: String, kind: String) -> void:
	var kinds: Dictionary = exercised.get(event_id, {})
	kinds[kind] = true
	exercised[event_id] = kinds
