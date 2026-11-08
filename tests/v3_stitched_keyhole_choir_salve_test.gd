extends SceneTree
## Deterministic headless SceneTree test for the Keyhole Choir S6 Stitched Event tradeoff.
## Verifies AC1 (catalog contract), AC2 (candle 80/92, 4 vs 3 active dolls, +7 fray, +5 HP, RNG/snapshot purity),
## and AC3 (candle 100 refusal, Leave availability, double-claim rejection, unchanged negative choices).

const CATALOGUE_PATH := "res://data/events/stitched_route_effects.json"
const EVENT_ID := "v3_keyhole_choir"
const FOUR_HERO_IDS := ["warden", "seamstress", "tinker", "lantern_monk"]

var checks: int = 0
var failures: Array[String] = []


func _initialize() -> void:
	var event_record: Dictionary = _load_event_from_catalog(EVENT_ID)
	if event_record.is_empty():
		_check(false, "Could not load " + EVENT_ID + " from " + CATALOGUE_PATH)
		_finish()
		return

	_test_catalogue_ac1(event_record)
	_test_preview_and_choose_candle_ac2(event_record)
	_test_three_active_heroes_ac2(event_record)
	_test_detachment_purity_and_rng_ac2(event_record)
	_test_candle_100_refusal_and_leave_ac3(event_record)
	_test_double_claim_rejection_ac3(event_record)
	_test_unchanged_negative_choices_ac3(event_record)
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("v3_stitched_keyhole_choir_salve_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: ", failure)
		print("v3_stitched_keyhole_choir_salve_test: FAIL (", failures.size(), " failures, ", checks, " checks)")
		quit(1)


func _load_event_from_catalog(target_id: String) -> Dictionary:
	var file := FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	_check(file != null, "Catalog file opens: " + CATALOGUE_PATH)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var err := parser.parse(text)
	_check(err == OK, "Catalog parses as JSON")
	if err != OK or not parser.data is Dictionary:
		return {}
	var doc: Dictionary = parser.data
	var events: Variant = doc.get("events")
	if not events is Array:
		return {}
	for rec in events:
		if rec is Dictionary and (rec as Dictionary).get("id") == target_id:
			var res: Dictionary = (rec as Dictionary).duplicate(true)
			for ch in res.get("choices", []):
				if ch is Dictionary and ch.has("stitched_effect") and ch["stitched_effect"] is Dictionary:
					var eff: Dictionary = ch["stitched_effect"]
					for k in ["candle", "fray", "hp", "scraps", "gold", "fear"]:
						if eff.has(k) and eff[k] is float:
							eff[k] = int(eff[k])
			return res
	return {}


func _find_choice(event_record: Dictionary, choice_id: String) -> Dictionary:
	for c in event_record.get("choices", []):
		if c is Dictionary and (c as Dictionary).get("id") == choice_id:
			return c
	return {}


func _find_preview_entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and (entry as Dictionary).get("choice_id") == choice_id:
			return entry
	return {}


## AC1: Given shipped v3_keyhole_choir, follow_humming has target="party", candle=16, fray=7, hp=5,
## require_candle_room_or_wound=true, and only its text is qualitatively changed; buy_silence and leave,
## other records stay unchanged. The new catalogue test checks by ID.
func _test_catalogue_ac1(event_record: Dictionary) -> void:
	_check(event_record.get("id") == EVENT_ID, "AC1: Event ID matches " + EVENT_ID)
	_check(event_record.get("title") == "The Keyhole Choir", "AC1: Event title matches")
	_check(event_record.get("description") == "A brass keyhole towers above the doll-sized skirting board. Three round, button-eyed singers sway behind its dark throat, and their humming makes the candle flame bow toward the door.",
		"AC1: Event description matches authored text")

	var choices: Array = event_record.get("choices", [])
	_check(choices.size() == 3, "AC1: Event has exactly 3 choices")

	var follow := _find_choice(event_record, "follow_humming")
	_check(not follow.is_empty(), "AC1: follow_humming choice present")
	_check(follow.get("text") == "Follow the warm humming; mend the dolls, kindle the wick, fray their seams",
		"AC1: follow_humming text is qualitatively changed with no numeric exposition")
	var follow_effect: Dictionary = follow.get("stitched_effect", {})
	_check(follow_effect.get("target") == "party", "AC1: follow_humming target is party")
	_check(int(follow_effect.get("candle", 0)) == 16, "AC1: follow_humming candle is 16")
	_check(int(follow_effect.get("fray", 0)) == 7, "AC1: follow_humming fray is 7")
	_check(int(follow_effect.get("hp", 0)) == 5, "AC1: follow_humming hp is 5")
	_check(follow_effect.get("require_candle_room_or_wound") == true, "AC1: follow_humming require_candle_room_or_wound is true")
	_check(follow_effect.size() == 5, "AC1: follow_humming has exactly 5 effect keys")

	var buy := _find_choice(event_record, "buy_silence")
	_check(not buy.is_empty(), "AC1: buy_silence choice present")
	_check(buy.get("text") == "Spend scraps to quiet Wren and ease the dolls' fray",
		"AC1: buy_silence authored text updated")
	var buy_effect: Dictionary = buy.get("stitched_effect", {})
	_check(buy_effect.get("target") == "party", "AC1: buy_silence target is party")
	_check(int(buy_effect.get("candle", -1)) == 0, "AC1: buy_silence candle is 0")
	_check(int(buy_effect.get("fray", 0)) == -12, "AC1: buy_silence fray is -12")
	_check(int(buy_effect.get("scraps", 0)) == -2, "AC1: buy_silence scraps is -2")
	_check(int(buy_effect.get("fear", 0)) == -8, "AC1: buy_silence fear is -8")
	_check(buy_effect.get("require_fray_or_fear") == true, "AC1: buy_silence require_fray_or_fear is true")
	_check(buy_effect.size() == 6, "AC1: buy_silence has exactly 6 effect keys")

	var leave := _find_choice(event_record, "leave")
	_check(not leave.is_empty(), "AC1: leave choice present")
	_check(leave.get("text") == "Leave the little choir singing behind the door",
		"AC1: leave authored text retained")
	var leave_effect: Dictionary = leave.get("stitched_effect", {})
	_check(leave_effect.get("target") == "party", "AC1: leave target is party")
	_check(int(leave_effect.get("candle", -1)) == 0, "AC1: leave candle is 0")
	_check(int(leave_effect.get("fray", -1)) == 0, "AC1: leave fray is 0")
	_check(leave_effect.size() == 3, "AC1: leave has exactly 3 effect keys")


## AC2: Given four live canonical IDs, candle 80 or 92, the service's preview and accepted choose
## produce projected candle 96 or 100 plus exactly +7 raw fray and +5 raw HP for each active recipient;
## a non-LOST three-person snapshot excludes the absent LOST fourth.
func _test_preview_and_choose_candle_ac2(event_record: Dictionary) -> void:
	var four_party: Array = [
		{"id": "warden", "fray": 20},
		{"id": "seamstress", "fray": 30},
		{"id": "tinker", "fray": 40},
		{"id": "lantern_monk", "fray": 50},
	]

	# --- Candle 80 -> expected candle 96 ---
	var snap_80 := {"candle": 80, "party": four_party.duplicate(true), "scraps": 4}
	var service_80 := RunStitchedEventConsequence.new(event_record)
	_check(service_80.is_valid() and not service_80.is_claimed(), "AC2: Service opens valid and unclaimed (candle 80)")
	var prev_80 := service_80.preview(snap_80)
	_check(prev_80.get("ok") == true and prev_80.get("event_id") == EVENT_ID, "AC2: preview ok for candle 80")
	_check(prev_80.get("candle") == 80, "AC2: preview reports base candle 80")

	var entry_80 := _find_preview_entry(prev_80, "follow_humming")
	_check(entry_80.get("available") == true, "AC2: follow_humming available at candle 80")
	_check(entry_80.get("candle") == 96, "AC2: preview candle 80 + 16 = 96")
	_check(entry_80.get("candle_delta") == 16, "AC2: preview candle_delta is 16")
	_check(entry_80.get("fray_delta") == 7, "AC2: preview fray_delta is 7")
	_check(entry_80.get("hp_delta") == 5, "AC2: preview hp_delta is 5")

	var expected_fray_4 := {"warden": 7, "seamstress": 7, "tinker": 7, "lantern_monk": 7}
	var expected_hp_4 := {"warden": 5, "seamstress": 5, "tinker": 5, "lantern_monk": 5}
	_check(entry_80.get("fray") == expected_fray_4, "AC2: preview fray intent +7 for all 4 canonical heroes")
	_check(entry_80.get("hp") == expected_hp_4, "AC2: preview hp intent +5 for all 4 canonical heroes")

	var receipt_80: Dictionary = service_80.choose("follow_humming", snap_80)
	_check(receipt_80.get("ok") == true, "AC2: choose follow_humming succeeds at candle 80")
	_check(receipt_80.get("event_id") == EVENT_ID and receipt_80.get("choice_id") == "follow_humming",
		"AC2: receipt identifies event and choice")
	_check(receipt_80.get("target") == "party" and receipt_80.get("hero_id") == "", "AC2: receipt target is party")
	_check(receipt_80.get("candle") == 96, "AC2: receipt candle is 96")
	_check(receipt_80.get("fray") == expected_fray_4, "AC2: receipt fray intent is +7 for each of 4 heroes")
	_check(receipt_80.get("hp_delta") == 5, "AC2: receipt hp_delta is 5")
	_check(receipt_80.get("hp") == expected_hp_4, "AC2: receipt hp intent is +5 for each of 4 heroes")
	_check(service_80.is_claimed() and not service_80.is_valid(), "AC2: claim latches visit")

	# --- Candle 92 -> expected candle 100 (clamped) ---
	var snap_92 := {"candle": 92, "party": four_party.duplicate(true), "scraps": 4}
	var service_92 := RunStitchedEventConsequence.new(event_record)
	var prev_92 := service_92.preview(snap_92)
	var entry_92 := _find_preview_entry(prev_92, "follow_humming")
	_check(entry_92.get("available") == true, "AC2: follow_humming available at candle 92")
	_check(entry_92.get("candle") == 100, "AC2: preview candle 92 + 16 clamped to 100")
	_check(entry_92.get("fray") == expected_fray_4, "AC2: preview candle 92 fray intent +7 for all 4")
	_check(entry_92.get("hp") == expected_hp_4, "AC2: preview candle 92 hp intent +5 for all 4")

	var receipt_92: Dictionary = service_92.choose("follow_humming", snap_92)
	_check(receipt_92.get("ok") == true, "AC2: choose follow_humming succeeds at candle 92")
	_check(receipt_92.get("candle") == 100, "AC2: receipt candle 92 + 16 clamped to 100")
	_check(receipt_92.get("fray") == expected_fray_4, "AC2: receipt candle 92 fray intent +7 for all 4")
	_check(receipt_92.get("hp") == expected_hp_4, "AC2: receipt candle 92 hp intent +5 for all 4")


## AC2: Non-LOST three-person snapshot excludes the absent LOST fourth.
## Tests both:
## 1) Presentation of only the three active dolls in the snapshot party array.
## 2) Presentation of 4 dolls with the 4th marked lost: true.
func _test_three_active_heroes_ac2(event_record: Dictionary) -> void:
	# 1. Three active members present (fourth lantern_monk absent from snapshot)
	var three_party := [
		{"id": "warden", "fray": 15},
		{"id": "seamstress", "fray": 25},
		{"id": "tinker", "fray": 35},
	]
	var snap_three := {"candle": 80, "party": three_party.duplicate(true), "scraps": 4}
	var service_three := RunStitchedEventConsequence.new(event_record)
	var prev_three := service_three.preview(snap_three)
	var entry_three := _find_preview_entry(prev_three, "follow_humming")
	_check(entry_three.get("available") == true, "AC2: follow_humming available for 3-doll party")

	var expected_fray_3 := {"warden": 7, "seamstress": 7, "tinker": 7}
	var expected_hp_3 := {"warden": 5, "seamstress": 5, "tinker": 5}
	_check(entry_three.get("fray") == expected_fray_3, "AC2: preview fray targets only 3 active heroes")
	_check(entry_three.get("hp") == expected_hp_3, "AC2: preview hp targets only 3 active heroes")
	_check(not (entry_three.get("hp") as Dictionary).has("lantern_monk"),
		"AC2: preview hp excludes absent fourth lantern_monk")

	var receipt_three: Dictionary = service_three.choose("follow_humming", snap_three)
	_check(receipt_three.get("ok") == true, "AC2: choose succeeds for 3-doll party")
	_check(receipt_three.get("candle") == 96, "AC2: receipt candle 96 for 3-doll party")
	_check(receipt_three.get("fray") == expected_fray_3, "AC2: receipt fray targets only 3 active heroes")
	_check(receipt_three.get("hp") == expected_hp_3, "AC2: receipt hp targets only 3 active heroes")
	_check(not (receipt_three.get("hp") as Dictionary).has("lantern_monk"),
		"AC2: receipt hp excludes absent fourth lantern_monk")
	_check(not (receipt_three.get("fray") as Dictionary).has("lantern_monk"),
		"AC2: receipt fray excludes absent fourth lantern_monk")

	# 2. Four dolls in party array where the fourth is marked lost: true
	var party_with_lost := [
		{"id": "warden", "fray": 15},
		{"id": "seamstress", "fray": 25},
		{"id": "tinker", "fray": 35},
		{"id": "lantern_monk", "fray": 45, "lost": true},
	]
	var snap_with_lost := {"candle": 80, "party": party_with_lost.duplicate(true), "scraps": 4}
	var service_lost := RunStitchedEventConsequence.new(event_record)
	var prev_lost := service_lost.preview(snap_with_lost)
	var entry_lost := _find_preview_entry(prev_lost, "follow_humming")
	_check(entry_lost.get("available") == true, "AC2: follow_humming available with lost doll in party")
	_check(entry_lost.get("hp") == expected_hp_3, "AC2: preview hp excludes lost doll")
	_check(entry_lost.get("fray") == expected_fray_3, "AC2: preview fray excludes lost doll")

	var receipt_lost: Dictionary = service_lost.choose("follow_humming", snap_with_lost)
	_check(receipt_lost.get("ok") == true, "AC2: choose succeeds with lost doll in party")
	_check(receipt_lost.get("hp") == expected_hp_3, "AC2: receipt hp excludes lost doll")
	_check(receipt_lost.get("fray") == expected_fray_3, "AC2: receipt fray excludes lost doll")


## AC2: Tests inspect actual service receipts, deep-copy purity and seeded RNG state.
func _test_detachment_purity_and_rng_ac2(event_record: Dictionary) -> void:
	var original_party: Array = [
		{"id": "warden", "fray": 20},
		{"id": "seamstress", "fray": 30},
		{"id": "tinker", "fray": 40},
		{"id": "lantern_monk", "fray": 50},
	]
	var snap := {"candle": 80, "party": original_party.duplicate(true), "scraps": 4}
	var snap_copy := snap.duplicate(true)

	# Seed RNG and record state
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654321
	var initial_state := rng.state

	seed(123456789)
	var global_rng_val1 := randi()
	seed(123456789)

	var service := RunStitchedEventConsequence.new(event_record)
	var preview := service.preview(snap)
	_check(snap == snap_copy, "AC2: Caller snapshot unmutated by preview")

	# Mutate returned preview to prove detachment
	preview["candle"] = 0
	preview["choices"][0]["candle"] = -999
	preview["choices"][0]["hp"]["warden"] = 9999
	var preview2 := service.preview(snap)
	_check(preview2["candle"] == 80, "AC2: Mutating preview does not alias subsequent preview candle")
	var entry2 := _find_preview_entry(preview2, "follow_humming")
	_check(entry2["candle"] == 96, "AC2: Mutating preview does not alias choice candle")
	_check(entry2["hp"]["warden"] == 5, "AC2: Mutating preview does not alias choice hp intent")

	# Choose and verify caller snapshot remains untouched
	var receipt := service.choose("follow_humming", snap)
	_check(snap == snap_copy, "AC2: Caller snapshot unmutated by choose")

	# Mutate returned receipt to prove detachment
	receipt["candle"] = 0
	receipt["hp"]["warden"] = 8888
	_check(snap["candle"] == 80, "AC2: Mutating receipt does not reach caller snapshot candle")
	_check(snap["party"][0]["fray"] == 20, "AC2: Mutating receipt does not reach caller snapshot fray")

	# Verify RNG did not advance
	var global_rng_val2 := randi()
	_check(global_rng_val1 == global_rng_val2, "AC2: Global RNG state was unconsumed by service calls")
	_check(rng.state == initial_state, "AC2: Seeded RNG guard unconsumed by service calls")


## AC3: Given candle 100, follow_humming refuses without consuming visit, balance or RNG;
## Leave can still claim. Test this refusal, double-claim rejection and existing
## RunStitchedEventConsequence regression. Preserve all negative coverage.
func _test_candle_100_refusal_and_leave_ac3(event_record: Dictionary) -> void:
	var party: Array = [
		{"id": "warden", "fray": 20},
		{"id": "seamstress", "fray": 30},
		{"id": "tinker", "fray": 40},
		{"id": "lantern_monk", "fray": 50},
	]
	var snap_100 := {"candle": 100, "party": party.duplicate(true), "scraps": 4}
	var snap_100_before := snap_100.duplicate(true)

	seed(5551212)
	var expected_rng := randi()
	seed(5551212)

	var service := RunStitchedEventConsequence.new(event_record)
	var prev := service.preview(snap_100)
	var follow_entry := _find_preview_entry(prev, "follow_humming")
	_check(follow_entry.get("available") == false, "AC3: follow_humming unavailable at candle 100")
	_check(follow_entry.get("candle") == 100, "AC3: unavailable follow_humming reports base candle 100")
	_check(follow_entry.get("fray") == {}, "AC3: unavailable follow_humming projects empty fray")
	_check(follow_entry.get("hp") == {}, "AC3: unavailable follow_humming projects empty hp")
	_check(follow_entry.get("candle_delta") == 16, "AC3: unavailable follow_humming reports authored candle_delta 16")
	_check(follow_entry.get("fray_delta") == 7, "AC3: unavailable follow_humming reports authored fray_delta 7")
	_check(follow_entry.get("hp_delta") == 5, "AC3: unavailable follow_humming reports authored hp_delta 5")

	var leave_entry := _find_preview_entry(prev, "leave")
	_check(leave_entry.get("available") == true, "AC3: Leave available at candle 100")
	_check(leave_entry.get("candle") == 100, "AC3: Leave projects candle 100")

	# Attempt follow_humming at candle 100: must refuse
	var refusal: Dictionary = service.choose("follow_humming", snap_100)
	_check(refusal.get("ok") == false, "AC3: follow_humming refused at candle 100")
	_check(refusal.get("candle") == 100, "AC3: refusal retains base candle 100")
	_check(refusal.get("event_id") == "", "AC3: refusal event_id is empty")
	_check(refusal.get("choice_id") == "", "AC3: refusal choice_id is empty")
	_check(refusal.get("fray") == {}, "AC3: refusal fray is empty")

	_check(service.is_valid() and not service.is_claimed(), "AC3: refusal does not consume visit or latch claim")
	_check(snap_100 == snap_100_before, "AC3: refusal mutates no caller snapshot or balance")
	_check(randi() == expected_rng, "AC3: refusal draws no RNG")

	# Leave can still claim on the same visit
	var leave_receipt: Dictionary = service.choose("leave", snap_100)
	_check(leave_receipt.get("ok") == true, "AC3: Leave succeeds on the same visit after refusal")
	_check(leave_receipt.get("choice_id") == "leave", "AC3: Leave receipt choice_id is leave")
	_check(leave_receipt.get("candle") == 100, "AC3: Leave receipt candle is 100")
	_check(leave_receipt.get("fray") == {}, "AC3: Leave receipt fray is empty")
	_check(service.is_claimed() and not service.is_valid(), "AC3: Leave claim latches visit")


## AC3: Test double-claim rejection
func _test_double_claim_rejection_ac3(event_record: Dictionary) -> void:
	var party: Array = [
		{"id": "warden", "fray": 20},
		{"id": "seamstress", "fray": 30},
		{"id": "tinker", "fray": 40},
		{"id": "lantern_monk", "fray": 50},
	]
	var snap := {"candle": 80, "party": party.duplicate(true), "scraps": 4}
	var service := RunStitchedEventConsequence.new(event_record)
	var first_claim: Dictionary = service.choose("follow_humming", snap)
	_check(first_claim.get("ok") == true, "AC3: First claim succeeds")
	_check(service.is_claimed(), "AC3: Service is marked claimed")

	# Second claim on same choice must fail
	var replay_same: Dictionary = service.choose("follow_humming", snap)
	_check(replay_same.get("ok") == false, "AC3: Replay of same choice rejected")
	_check(replay_same.get("candle") == 80, "AC3: Rejection reports base candle")

	# Second claim on different choice must fail
	var replay_diff: Dictionary = service.choose("leave", snap)
	_check(replay_diff.get("ok") == false, "AC3: Second claim on different choice rejected")

	var replay_buy: Dictionary = service.choose("buy_silence", snap)
	_check(replay_buy.get("ok") == false, "AC3: Second claim on buy_silence rejected")

	# Preview denied on claimed visit
	var prev_after := service.preview(snap)
	_check(prev_after.get("ok") == false and prev_after.get("choices", []).is_empty(),
		"AC3: Preview denied once visit is claimed")


## AC3: Unchanged negative choices (buy_silence gates and leave)
func _test_unchanged_negative_choices_ac3(event_record: Dictionary) -> void:
	# 1. buy_silence when all dolls at fray 0 and wren_fear is 0 (require_fray_or_fear gate fails)
	var snap_calm := {
		"candle": 80,
		"scraps": 4,
		"wren_fear": 0,
		"party": [
			{"id": "warden", "fray": 0},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "lantern_monk", "fray": 0},
		],
	}
	var svc_calm := RunStitchedEventConsequence.new(event_record)
	var prev_calm := svc_calm.preview(snap_calm)
	var buy_calm := _find_preview_entry(prev_calm, "buy_silence")
	_check(buy_calm.get("available") == false, "AC3: buy_silence unavailable when all fray is 0 and wren_fear is 0")
	var ref_calm := svc_calm.choose("buy_silence", snap_calm)
	_check(ref_calm.get("ok") == false, "AC3: buy_silence choose refused when all fray is 0 and wren_fear is 0")
	_check(svc_calm.is_valid() and not svc_calm.is_claimed(), "AC3: require_fray_or_fear refusal does not latch claim")

	# 2. buy_silence when scraps < 2 (underfunded)
	var snap_low_scraps := {
		"candle": 80,
		"scraps": 1,
		"wren_fear": 20,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "lantern_monk", "fray": 0},
		],
	}
	var svc_low := RunStitchedEventConsequence.new(event_record)
	var prev_low := svc_low.preview(snap_low_scraps)
	var buy_low := _find_preview_entry(prev_low, "buy_silence")
	_check(buy_low.get("available") == false, "AC3: buy_silence unavailable when scraps < 2")
	var ref_low := svc_low.choose("buy_silence", snap_low_scraps)
	_check(ref_low.get("ok") == false, "AC3: buy_silence choose refused when scraps < 2")
	_check(svc_low.is_valid() and not svc_low.is_claimed(), "AC3: underfunded refusal does not latch claim")

	# 3. buy_silence when funded and living fray >= 1: succeeds with -2 scraps and -12 fray and -8 fear
	var snap_funded := {
		"candle": 80,
		"scraps": 3,
		"wren_fear": 20,
		"party": [
			{"id": "warden", "fray": 10},
			{"id": "seamstress", "fray": 0},
			{"id": "tinker", "fray": 0},
			{"id": "lantern_monk", "fray": 0},
		],
	}
	var svc_funded := RunStitchedEventConsequence.new(event_record)
	var prev_funded := svc_funded.preview(snap_funded)
	var buy_funded := _find_preview_entry(prev_funded, "buy_silence")
	_check(buy_funded.get("available") == true, "AC3: buy_silence available when funded and fray >= 1")
	var rec_funded := svc_funded.choose("buy_silence", snap_funded)
	_check(rec_funded.get("ok") == true, "AC3: buy_silence succeeds when funded and fray >= 1")
	_check(rec_funded.get("scraps") == 1 and rec_funded.get("scraps_delta") == -2, "AC3: buy_silence scraps delta -2")
	_check(rec_funded.get("fray") == {"warden": -12, "seamstress": -12, "tinker": -12, "lantern_monk": -12},
		"AC3: buy_silence fray intent -12 each")
	_check(rec_funded.get("fear") == 12 and rec_funded.get("fear_delta") == -8, "AC3: buy_silence fear 20 - 8 = 12")
	_check(not rec_funded.has("hp"), "AC3: buy_silence has no hp intent")
	_check(rec_funded.get("candle") == 80, "AC3: buy_silence candle unchanged at 80")
