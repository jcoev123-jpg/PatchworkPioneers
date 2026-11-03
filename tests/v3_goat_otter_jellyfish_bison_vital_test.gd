extends SceneTree
## Deterministic headless test for the four creature-and-giant-prop gothic
## roadside vitality stories appended to data/events/v3_vital_story_events.json,
## and for their admission to the shipped RunV3VitalEventRotation pool.
##
## The catalog is loaded through FileAccess and every assertion is per-ID: no
## catalog total, positional index or frozen ordered ID list is asserted,
## because other lanes append to the same catalog in parallel. The table below
## is an independent copy of the authored brief and never generated from the
## catalog under test.

const EVENTS_PATH := "res://data/events/v3_vital_story_events.json"

## Funded living-hero snapshot used to prove preview/commit agreement.
const FUNDED_GOLD := 60
const FUNDED_SCRAPS := 6
const FUNDED_HP := 20
const FUNDED_MAX_HP := 40

## Poor snapshot: no currency, and 1/10 HP leaves no margin for any paid,
## self-harming or max-HP-paying branch, so every non-Leave choice fails closed.
const POOR_GOLD := 0
const POOR_SCRAPS := 0
const POOR_HP := 1
const POOR_MAX_HP := 10

## Authored order, so the funded receipts below pair by choice position.
const NEW_EVENT_IDS := [
	"v3_ashen_goat_lantern_horns",
	"v3_garnet_otter_quilt_raft",
	"v3_inkblue_jellyfish_belljar",
	"v3_bonecream_bison_banner",
]

## Independent authored expectations for the four new records.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
const NEW_EVENTS := {
	"v3_ashen_goat_lantern_horns": {
		"title": "The Ashen Goat's Lantern Horns",
		"description": "A plump slate-grey goat ragdoll balances two enormous curled felt horns threaded with amber lanterns; candlelit stitches gleam above its mismatched button eyes.",
		"choices": [
			["polish_horn_wicks", "Pay 13 gold and 1 scrap to mend the lantern seams (heal 6 HP; gain 1 max HP)", -13, -1, 6, 1],
			["unlace_horn_bells", "Unlace the heavy horn bells (lose 4 HP; gain 21 gold)", 21, 0, -4, 0],
			["leave", "Let the goat keep its lantern vigil", 0, 0, 0, 0],
		],
	},
	"v3_garnet_otter_quilt_raft": {
		"title": "The Garnet Otter's Quilt Raft",
		"description": "A round garnet-cloth otter pilots a house-sized folded quilt across an ink-dark canal, its stout paddle tied with pale running stitches beneath a mustard lantern.",
		"choices": [
			["sew_raft_hem", "Spend 2 scraps on a lasting raft seam (+3 max HP)", 0, -2, 0, 3],
			["paddle_for_fare", "Paddle through the freezing canal (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Watch the quilt raft drift into the fog", 0, 0, 0, 0],
		],
	},
	"v3_inkblue_jellyfish_belljar": {
		"title": "The Ink-Blue Jellyfish Bell Jar",
		"description": "A round ink-blue jellyfish doll bobs inside a house-sized cracked glass bell jar, its short quilted ribbons glowing beneath a ring of candle-warmed lace.",
		"choices": [
			["buy_glass_balm", "Pay 16 gold for warm bell-jar balm (heal 10 HP)", -16, 0, 10, 0],
			["donate_glass_seam", "Give up 2 lasting heart seams for the glass keeper (lose 2 max HP; gain 26 gold)", 26, 0, 0, -2],
			["leave", "Let the jellyfish dim its lace lanterns", 0, 0, 0, 0],
		],
	},
	"v3_bonecream_bison_banner": {
		"title": "The Bone-Cream Bison Banner",
		"description": "A squat bone-cream bison ragdoll braces an enormous moth-eaten oxblood banner on a stitched pole, its heavy padded horns haloed by a single brass lantern.",
		"choices": [
			["reweave_bison_standard", "Spend 3 scraps reweaving the great banner (+4 max HP)", 0, -3, 0, 4],
			["pawn_banner_lining", "Pawn three lasting banner seams (lose 3 max HP; gain 35 gold)", 35, 0, 0, -3],
			["leave", "Leave the bison guarding its faded standard", 0, 0, 0, 0],
		],
	},
}

## Literal funded receipts from the brief, in authored choice order:
## [gold, scraps, hp, max_hp]. The oracle is copied, never derived.
const FUNDED_RECEIPTS := {
	"v3_ashen_goat_lantern_horns": [
		[47, 5, 26, 41],
		[81, 6, 16, 40],
		[60, 6, 20, 40],
	],
	"v3_garnet_otter_quilt_raft": [
		[60, 4, 20, 43],
		[60, 8, 15, 40],
		[60, 6, 20, 40],
	],
	"v3_inkblue_jellyfish_belljar": [
		[44, 6, 30, 40],
		[86, 6, 20, 38],
		[60, 6, 20, 40],
	],
	"v3_bonecream_bison_banner": [
		[60, 3, 20, 44],
		[95, 6, 20, 37],
		[60, 6, 20, 40],
	],
}

## One fresh seeded generator per new ID for the rotation membership proof.
const ROTATION_SEEDS := {
	"v3_ashen_goat_lantern_horns": 482801,
	"v3_garnet_otter_quilt_raft": 482802,
	"v3_inkblue_jellyfish_belljar": 482803,
	"v3_bonecream_bison_banner": 482804,
}

## Independent copies of the two named earlier anchors that must stay intact.
## Choice rows are [id, text, gold, scraps, hp, max_hp].
const ANCHOR_RECORDS := {
	"v3_brass_toad_hourglass": {
		"title": "The Brass Toad Hourglass",
		"description": "A squat moss-green toad puppet braces a cracked brass hourglass larger than its head; black sand drips through a blanket of silver stitches.",
		"choices": [
			["reset_heart_sand", "Spend 2 scraps to reset a lasting heart seam (+3 max HP)", 0, -2, 0, 3],
			["carry_hourglass", "Carry the heavy hourglass through briars (lose 5 HP; gain 2 scraps)", 0, 2, -5, 0],
			["leave", "Let the black sand fall in silence", 0, 0, 0, 0],
		],
	},
	"v3_sable_cat_needle_telescope": {
		"title": "The Sable Cat Needle Telescope",
		"description": "A round black-velvet cat doll peers through a silver needle telescope bolted to a giant thread spool; the moon shines on its mismatched button eyes.",
		"choices": [
			["focus_moon_seam", "Pay 19 gold and 1 scrap to focus a moon seam (heal 4 HP; gain 2 max HP)", -19, -1, 4, 2],
			["haul_glass_lenses", "Haul the heavy telescope lenses (lose 6 HP; gain 3 scraps)", 0, 3, -6, 0],
			["leave", "Let the cat watch the misty moon", 0, 0, 0, 0],
		],
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []


func _initialize() -> void:
	catalog = _load_catalog()
	if catalog.is_empty():
		_report()
		return
	_test_new_event_data()
	_test_anchors_preserved()
	_test_ids_unique()
	_test_funded_previews_and_claims()
	_test_unfunded_refusals_then_leave()
	_test_rotation_admission()
	_report()


func _report() -> void:
	for failure in failures:
		printerr(failure)
	print("v3_goat_otter_jellyfish_bison_vital_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_catalog() -> Array:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "the vitality catalog opens through FileAccess")
	if file == null:
		return []
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	_check(parsed == OK and parser.data is Dictionary
		and (parser.data as Dictionary).get("events") is Array,
		"the vitality catalog parses to {events: [...]}")
	if parsed != OK or not parser.data is Dictionary \
		or not (parser.data as Dictionary).get("events") is Array:
		return []
	var events: Array = (parser.data as Dictionary)["events"]
	_check(not events.is_empty(), "the vitality catalog carries authored records")
	return events


func _matching(listing: Array, event_id: String) -> Array:
	return listing.filter(func(entry) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _record(event_id: String) -> Dictionary:
	var found := _matching(catalog, event_id)
	if found.size() != 1:
		return {}
	return (found[0] as Dictionary).duplicate(true)


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


func _is_integral_amount(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number \
			and absf(number) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


func _preview_choice(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


## Seeds the global RNG and returns the next draw on an identical fresh seed,
## so a later randi() call proves no global draw happened in between.
func _global_rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _test_new_event_data() -> void:
	for event_id in NEW_EVENT_IDS:
		var expected: Dictionary = NEW_EVENTS[event_id]
		var found := _matching(catalog, event_id)
		_check(found.size() == 1, "exactly one authored new record: " + event_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		_check(record.size() == 4 and record.has("id") and record.has("title")
			and record.has("description") and record.has("choices"),
			"new record carries exactly id/title/description/choices: " + event_id)
		_check(record.get("id") == event_id, "new record ID is exact: " + event_id)
		_check(record.get("title") == expected["title"], "new title is exact: " + event_id)
		_check(record.get("description") == expected["description"],
			"new description is exact: " + event_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"new record carries exactly three choices: " + event_id)
		if not choices is Array:
			continue
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary and (choice as Dictionary).size() == 3
				and (choice as Dictionary).has("id") and (choice as Dictionary).has("text")
				and (choice as Dictionary).has("outcome"),
				"new choice carries exactly id/text/outcome: " + event_id)
			if not choice is Dictionary or not (choice as Dictionary).get("id") is String:
				continue
			var choice_id: String = choice["id"]
			_check(not by_id.has(choice_id),
				"new choice IDs are distinct: " + event_id + "/" + choice_id)
			by_id[choice_id] = choice
			var outcome: Variant = (choice as Dictionary).get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4
				and (outcome as Dictionary).has("gold") and (outcome as Dictionary).has("scraps")
				and (outcome as Dictionary).has("hp") and (outcome as Dictionary).has("max_hp"),
				"new outcome carries exactly four keys: " + event_id + "/" + choice_id)
			if outcome is Dictionary:
				for key in ["gold", "scraps", "hp", "max_hp"]:
					_check(_is_integral_amount((outcome as Dictionary).get(key)),
						"new outcome amount is integral: " + event_id + "/" + choice_id + "/" + key)
		var rows: Array = expected["choices"]
		_check(by_id.size() == rows.size(), "new choice count matches the spec: " + event_id)
		for row in rows:
			var tag: String = event_id + "/" + str(row[0])
			_check(by_id.has(row[0]), "authored choice present: " + tag)
			if not by_id.has(row[0]):
				continue
			var choice_dict: Dictionary = by_id[row[0]]
			_check(choice_dict.get("text") == row[1], "choice text is exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			if not outcome is Dictionary:
				continue
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = (outcome as Dictionary).get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"choice outcome " + keys[i] + " is exact: " + tag)
		var service := RunEventChoice.new(record.duplicate(true))
		_check(service.is_valid() and not service.is_claimed(),
			"new record is presentable to RunEventChoice: " + event_id)


func _test_anchors_preserved() -> void:
	for anchor_id in ANCHOR_RECORDS:
		var found := _matching(catalog, anchor_id)
		_check(found.size() == 1, "anchor record still present exactly once: " + anchor_id)
		if found.size() != 1:
			continue
		var record: Dictionary = found[0]
		var expected: Dictionary = ANCHOR_RECORDS[anchor_id]
		_check(record.get("title") == expected["title"], "anchor title is exact: " + anchor_id)
		_check(record.get("description") == expected["description"],
			"anchor description is exact: " + anchor_id)
		var choices: Variant = record.get("choices")
		_check(choices is Array and (choices as Array).size() == 3,
			"anchor keeps three authored choices: " + anchor_id)
		if not choices is Array:
			continue
		var by_id: Dictionary = {}
		for choice in choices:
			if choice is Dictionary and choice.get("id") is String:
				by_id[choice["id"]] = choice
		var rows: Array = expected["choices"]
		for row in rows:
			var choice_id: String = row[0]
			var tag: String = anchor_id + "/" + choice_id
			_check(by_id.has(choice_id), "anchor choice present: " + tag)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(choice_dict.get("text") == row[1], "anchor choice text exact: " + tag)
			var outcome: Variant = choice_dict.get("outcome")
			_check(outcome is Dictionary and (outcome as Dictionary).size() == 4,
				"anchor outcome has exactly four keys: " + tag)
			if not outcome is Dictionary:
				continue
			var outcome_dict: Dictionary = outcome
			var keys := ["gold", "scraps", "hp", "max_hp"]
			for i in range(4):
				var raw: Variant = outcome_dict.get(keys[i])
				_check(_is_integral_amount(raw) and int(raw) == int(row[2 + i]),
					"anchor outcome " + keys[i] + " exact: " + tag)


func _test_ids_unique() -> void:
	var seen := {}
	for entry in catalog:
		if not entry is Dictionary or not (entry as Dictionary).get("id") is String:
			continue
		var event_id: String = entry["id"]
		_check(not seen.has(event_id), "no duplicate event ID in catalog: " + event_id)
		seen[event_id] = true
	for event_id in NEW_EVENT_IDS:
		_check(seen.has(event_id), "new event ID is present in the catalog: " + event_id)
	for anchor_id in ANCHOR_RECORDS:
		_check(seen.has(anchor_id), "anchor event ID is present in the catalog: " + anchor_id)


func _test_funded_previews_and_claims() -> void:
	# Every authored choice is previewed and then claimed on a fresh one-visit
	# service from the funded snapshot; the receipt must match the independently
	# copied expectation and its own forecast, the caller snapshot and the
	# catalog record must stay untouched, and exactly one claim may be latched.
	# No global RNG draw may happen in any flow.
	for event_id in NEW_EVENT_IDS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		var receipts: Array = FUNDED_RECEIPTS[event_id]
		_check(receipts.size() == rows.size(),
			"funded receipt table covers every authored branch: " + event_id)
		for i in range(rows.size()):
			var row: Array = rows[i]
			var choice_id: String = row[0]
			var gold_delta: int = int(row[2])
			var scraps_delta: int = int(row[3])
			var hp_delta: int = int(row[4])
			var max_delta: int = int(row[5])
			var receipt_row: Array = receipts[i] if i < receipts.size() else []
			var tag: String = event_id + "/" + choice_id
			_check(receipt_row.size() == 4, "funded receipt row is complete: " + tag)
			if receipt_row.size() != 4:
				continue
			var exp_gold: int = int(receipt_row[0])
			var exp_scraps: int = int(receipt_row[1])
			var exp_hp: int = int(receipt_row[2])
			var exp_max: int = int(receipt_row[3])
			var record := _record(event_id)
			_check(not record.is_empty(), "funded case has its authored record: " + tag)
			if record.is_empty():
				continue
			var record_before: Dictionary = record.duplicate(true)
			var snapshot := _vital_state(FUNDED_GOLD, FUNDED_SCRAPS, FUNDED_HP, FUNDED_MAX_HP)
			var snapshot_before: Dictionary = snapshot.duplicate(true)
			var service := RunEventChoice.new(record)
			_check(service.is_valid() and not service.is_claimed(),
				"fresh funded visit is open: " + tag)
			var rng_guard := _global_rng_start(83017)
			var preview := service.preview_vital_choices(snapshot)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id
				and (preview.get("choices") as Array).size() == 3,
				"funded preview lists all three choices: " + tag)
			var entry := _preview_choice(preview, choice_id)
			_check(entry.size() == 7, "funded preview entry has seven fields: " + tag)
			_check(entry.get("choice_id") == choice_id
				and entry.get("gold_delta") == gold_delta
				and entry.get("scraps_delta") == scraps_delta
				and entry.get("hp_delta") == hp_delta
				and entry.get("max_hp_delta") == max_delta,
				"funded preview reports the exact signed deltas: " + tag)
			_check(entry.get("affordable") == true
				and _vital_state_is(entry.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded preview projects the exact authored state: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"funded preview mutates nothing and stays unclaimed: " + tag)
			if choice_id == "leave":
				_check(entry.get("state") == snapshot_before,
					"free Leave previews an unchanged snapshot: " + tag)
				_check(gold_delta == 0 and scraps_delta == 0 and hp_delta == 0 and max_delta == 0,
					"free Leave carries four zero deltas: " + tag)
			var receipt := service.choose_with_vitals(choice_id, snapshot)
			_check(receipt.size() == 4 and receipt.get("ok") == true
				and receipt.get("event_id") == event_id and receipt.get("choice_id") == choice_id,
				"funded claim names the authored event and choice: " + tag)
			_check(_vital_state_is(receipt.get("state"), exp_gold, exp_scraps, exp_hp, exp_max),
				"funded claim settles the exact authored state: " + tag)
			_check(receipt.get("state") == entry.get("state"),
				"funded claim matches its preview forecast: " + tag)
			_check(snapshot == snapshot_before and record == record_before
				and service.get_event() == record_before,
				"funded claim leaves caller snapshot and catalog detached: " + tag)
			_check(randi() == rng_guard, "funded preview and claim consume no RNG draw: " + tag)
			_check(service.is_claimed() and not service.is_valid(),
				"funded claim latches exactly one visit: " + tag)
			var replay := service.choose_with_vitals(choice_id, snapshot)
			_check(replay.size() == 4 and replay.get("ok") == false
				and replay.get("event_id") == "" and replay.get("choice_id") == ""
				and replay.get("state") == snapshot_before and snapshot == snapshot_before,
				"funded spent visit rejects the replay unchanged: " + tag)
			_check(service.is_claimed(), "replay consumes no second claim: " + tag)


func _test_unfunded_refusals_then_leave() -> void:
	# With an empty wallet and a 1/10 hero every non-Leave branch is either
	# unpaid or lethal / below the max-HP floor, so both must forecast
	# unaffordable and refuse without latching; the free Leave then settles,
	# and unknown or replayed choice IDs are still refused.
	for event_id in NEW_EVENT_IDS:
		var rows: Array = NEW_EVENTS[event_id]["choices"]
		var state := _vital_state(POOR_GOLD, POOR_SCRAPS, POOR_HP, POOR_MAX_HP)
		var original: Dictionary = state.duplicate(true)
		var record := _record(event_id)
		_check(not record.is_empty(), "poor case has its authored record: " + event_id)
		if record.is_empty():
			continue
		var record_before: Dictionary = record.duplicate(true)
		var service := RunEventChoice.new(record)
		var rng_guard := _global_rng_start(84019)
		var meaningful := 0
		for row in rows:
			var choice_id: String = row[0]
			if choice_id == "leave":
				continue
			meaningful += 1
			var tag: String = event_id + "/" + choice_id
			var preview := service.preview_vital_choices(state)
			var entry := _preview_choice(preview, choice_id)
			_check(preview.get("ok") == true and not entry.is_empty()
				and entry.get("affordable") == false and entry.get("state") == original,
				"poor branch forecasts unaffordable with an unchanged state: " + tag)
			var refusal := service.choose_with_vitals(choice_id, state)
			_check(refusal.size() == 4 and refusal.get("ok") == false
				and refusal.get("event_id") == "" and refusal.get("choice_id") == ""
				and refusal.get("state") == original,
				"poor branch refuses with an unchanged detached state: " + tag)
			_check(state == original and record == record_before
				and service.is_valid() and not service.is_claimed(),
				"poor refusal consumes no visit and mutates nothing: " + tag)
		_check(meaningful == 2, "new event has two meaningful branches: " + event_id)
		var unknown := service.choose_with_vitals("not_an_authored_choice", state)
		_check(unknown.size() == 4 and unknown.get("ok") == false
			and unknown.get("event_id") == "" and unknown.get("choice_id") == ""
			and unknown.get("state") == original and state == original,
			"unknown choice ID refuses on the still-open visit: " + event_id)
		_check(service.is_valid() and not service.is_claimed(),
			"unknown choice ID consumes no visit: " + event_id)
		var leave := service.choose_with_vitals("leave", state)
		_check(leave.get("ok") == true and leave.get("event_id") == event_id
			and leave.get("choice_id") == "leave" and leave.get("state") == original
			and service.is_claimed() and not service.is_valid(),
			"free Leave still settles the visit after the refusals: " + event_id)
		var leave_replay := service.choose_with_vitals("leave", state)
		_check(leave_replay.get("ok") == false and leave_replay.get("state") == original
			and state == original and record == record_before,
			"settled poor visit rejects a repeated Leave: " + event_id)
		var branch_replay := service.choose_with_vitals(rows[0][0], state)
		_check(branch_replay.get("ok") == false and branch_replay.get("state") == original
			and state == original,
			"settled poor visit rejects a paid-branch replay: " + event_id)
		_check(randi() == rng_guard, "poor refusals and Leave consume no RNG draw: " + event_id)


func _test_rotation_admission() -> void:
	var rotation := RunV3VitalEventRotation.new()
	_check(rotation.is_catalog_valid(), "the shipped vitality rotation validates")
	var listing: Array = rotation.get_vital_events()
	var ids: Array = rotation.get_vital_event_ids()
	var listing_before: Array = listing.duplicate(true)
	var ids_before: Array = ids.duplicate()
	_check(not ids.is_empty(), "the vitality rotation offers a non-empty pool")
	for event_id in NEW_EVENT_IDS:
		var tag: String = "rotation " + event_id
		var authored := _record(event_id)
		_check(not authored.is_empty(), "rotation case has its authored record: " + tag)
		_check(ids.count(event_id) == 1, "new ID is eligible exactly once: " + tag)
		var offered := _matching(listing, event_id)
		_check(offered.size() == 1, "new ID is offered exactly once: " + tag)
		if offered.size() == 1 and not authored.is_empty():
			_check(offered[0] == authored,
				"offered new record matches the authored source: " + tag)
		# Exclusions are built from the current dynamic ID list, and only the
		# target is removed, so other lanes' entries never leak into the oracle.
		var excluded: Array = ids.duplicate()
		excluded.erase(event_id)
		var excluded_before: Array = excluded.duplicate()
		var seed_value: int = ROTATION_SEEDS[event_id]
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		oracle.randi_range(0, 0)
		var result := rotation.select_event(rng, excluded)
		_check(result.get("ok") == true
			and (result.get("event") as Dictionary).get("id") == event_id,
			"new ID is selected when every other ID is excluded: " + tag)
		_check(result.get("event") == authored,
			"forced selection returns the authored new record: " + tag)
		_check(rng.state == oracle.state,
			"forced selection consumes exactly one range draw: " + tag)
		_check(excluded == excluded_before,
			"forced selection leaves the caller exclusions unchanged: " + tag)
		var replay := RandomNumberGenerator.new()
		replay.seed = seed_value
		var again := rotation.select_event(replay, excluded)
		_check(again == result and replay.state == rng.state,
			"a same-seed replay repeats the forced selection: " + tag)
		_check(excluded == excluded_before,
			"the replayed selection leaves the caller exclusions unchanged: " + tag)
		# The returned record is detached: mutating it cannot reach the pool.
		var pool_hit := _matching(rotation.get_vital_events(), event_id)
		_check(pool_hit.size() == 1, "the pool still offers the ID once: " + tag)
		if pool_hit.size() == 1:
			var detached: Dictionary = result.get("event")
			detached["title"] = "mutated by a caller"
			_check((pool_hit[0] as Dictionary).get("title") == authored.get("title"),
				"mutating a selected record never reaches the pool: " + tag)
	for anchor_id in ANCHOR_RECORDS:
		_check(ids.has(anchor_id), "an older named record is still offered: " + anchor_id)
	var exhausted_rng := RandomNumberGenerator.new()
	exhausted_rng.seed = 482900
	var exhausted_before := exhausted_rng.state
	var exhausted := rotation.select_event(exhausted_rng, ids)
	_check(exhausted.get("ok") == false and (exhausted.get("event") as Dictionary).is_empty(),
		"an exhausted pool rejects selection")
	_check(exhausted_rng.state == exhausted_before,
		"an exhausted selection consumes no RNG draw")
	var invalid_rng := RandomNumberGenerator.new()
	invalid_rng.seed = 482901
	var invalid_before := invalid_rng.state
	var invalid := rotation.select_event(invalid_rng, [NEW_EVENT_IDS[0], 3])
	_check(invalid.get("ok") == false and (invalid.get("event") as Dictionary).is_empty(),
		"malformed exclusions reject selection")
	_check(invalid_rng.state == invalid_before,
		"a malformed exclusion request consumes no RNG draw")
	var blank_rng := RandomNumberGenerator.new()
	blank_rng.seed = 482902
	var blank_before := blank_rng.state
	var blank := rotation.select_event(blank_rng, ["  "])
	_check(blank.get("ok") == false and (blank.get("event") as Dictionary).is_empty(),
		"a blank exclusion ID rejects selection")
	_check(blank_rng.state == blank_before,
		"a blank exclusion ID consumes no RNG draw")
	_check(rotation.get_vital_events() == listing_before,
		"every rotation flow leaves the shipped pool unchanged")
	_check(rotation.get_vital_event_ids() == ids_before,
		"every rotation flow leaves the shipped ID order unchanged")
