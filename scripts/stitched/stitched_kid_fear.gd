class_name StitchedKidFear
extends RefCounted
## Pure Design v4 S9a Wren Fear status ledger and lost-strings turn rules.
##
## Manages Wren's fear meter (0..100), shaky-hands threshold (fear >= 50),
## caller-percentile hand action failure checks, event-based fear delta ledger,
## and the one-turn Lose the Strings interruption queued at fear 100.
##
## Pure RefCounted service: no scene tree, no global or seeded RNG,
## no random draws, and no mutation of caller-owned inputs.

const FEAR_MIN := 0
const FEAR_MAX := 100
const SHAKE_THRESHOLD := 50
const LOSE_STRINGS_THRESHOLD := 100
const RESET_FEAR_AFTER_LOST_STRINGS := 60
const HAND_FAILURE_CHANCE_PERCENT := 25

const FRAY_GAIN_FEAR_THRESHOLD := 10
const FRAY_GAIN_FEAR_DELTA := 2
const HANGING_FEAR_DELTA := 5
const LOST_FEAR_DELTA := 15
const STEADFAST_FEAR_DELTA := -10
const FIGHT_WON_FEAR_DELTA := -10
const TELL_TALES_FEAR_DELTA := -15

const CANDLE_ROUND_FEAR_DELTAS := {
	"bright": 0,
	"dim": 0,
	"gloom": 1,
	"dark": 2,
	"snuffed": 3,
}

var _fear: int = 0
var _pending_lost_strings: bool = false
var _sequence: int = 0
var _valid: bool = true


## Static factory creating an instance with bounded initial fear (default 0).
static func create(initial_fear: Variant = 0) -> Dictionary:
	if initial_fear != null:
		if typeof(initial_fear) != TYPE_INT:
			return {"ok": false, "error": "initial fear must be an integer 0..100", "sequence": 0}
		var f := int(initial_fear)
		if f < FEAR_MIN or f > FEAR_MAX:
			return {"ok": false, "error": "initial fear %d out of bounds (%d..%d)" % [f, FEAR_MIN, FEAR_MAX], "sequence": 0}
	var inst := StitchedKidFear.new(initial_fear)
	if not inst.is_valid():
		return {"ok": false, "error": "failed to initialize kid fear", "sequence": 0}
	return {
		"ok": true,
		"instance": inst,
		"service": inst,
		"fear_service": inst,
		"kid_fear": inst,
		"state": inst.state_snapshot(),
		"sequence": inst.get_sequence(),
	}


func _init(initial_fear: Variant = 0) -> void:
	if initial_fear == null:
		_fear = 0
		_valid = true
		return
	if typeof(initial_fear) != TYPE_INT:
		_valid = false
		_fear = 0
		return
	var f := int(initial_fear)
	if f < FEAR_MIN or f > FEAR_MAX:
		_valid = false
		_fear = 0
		return
	_fear = f
	_valid = true
	if _fear >= LOSE_STRINGS_THRESHOLD:
		_pending_lost_strings = true


## Re-initializes fear to a bounded value, preserving instance.
func reset(initial_fear: Variant = 0) -> Dictionary:
	if not _valid:
		return {"ok": false, "error": "invalid service instance", "sequence": _sequence, "fear": _fear}
	if initial_fear != null:
		if typeof(initial_fear) != TYPE_INT:
			return {"ok": false, "error": "initial fear must be an integer 0..100", "sequence": _sequence, "fear": _fear}
		var f := int(initial_fear)
		if f < FEAR_MIN or f > FEAR_MAX:
			return {"ok": false, "error": "initial fear %d out of bounds (%d..%d)" % [f, FEAR_MIN, FEAR_MAX], "sequence": _sequence, "fear": _fear}
		_fear = f
	else:
		_fear = 0
	_pending_lost_strings = (_fear >= LOSE_STRINGS_THRESHOLD)
	_sequence += 1
	return {
		"ok": true,
		"fear": _fear,
		"shake": is_shaking(),
		"pending_lost_strings": _pending_lost_strings,
		"sequence": _sequence,
		"state": state_snapshot(),
	}


func is_valid() -> bool:
	return _valid


func get_fear() -> int:
	return _fear


func fear() -> int:
	return _fear


func is_shaking() -> bool:
	return _fear >= SHAKE_THRESHOLD


func shake() -> bool:
	return is_shaking()


func has_pending_lost_strings() -> bool:
	return _pending_lost_strings


func pending_lost_strings() -> bool:
	return _pending_lost_strings


func get_sequence() -> int:
	return _sequence


func sequence() -> int:
	return _sequence


## Detached snapshot of current fear state.
func state_snapshot() -> Dictionary:
	return {
		"fear": _fear,
		"shake": is_shaking(),
		"pending_lost_strings": _pending_lost_strings,
		"sequence": _sequence,
	}.duplicate(true)


func read_state() -> Dictionary:
	return state_snapshot()


func get_state() -> Dictionary:
	return state_snapshot()


## Pure caller-percentile hand action failure check.
## Never touches RNG, never mutates state, and does not execute hand actions.
func check_hand_failure(percentile_roll: Variant) -> Dictionary:
	if not _valid:
		return {"ok": false, "error": "invalid service instance", "sequence": _sequence, "failed": false, "shake": false}
	if typeof(percentile_roll) != TYPE_INT:
		return {"ok": false, "error": "percentile roll must be an integer 1..100", "sequence": _sequence, "failed": false, "shake": is_shaking()}
	var roll := int(percentile_roll)
	if roll < 1 or roll > 100:
		return {"ok": false, "error": "percentile roll %d out of bounds (1..100)" % roll, "sequence": _sequence, "failed": false, "shake": is_shaking()}

	var shaking := is_shaking()
	var failed := shaking and (roll >= 1 and roll <= HAND_FAILURE_CHANCE_PERCENT)
	return {
		"ok": true,
		"shake": shaking,
		"roll": roll,
		"failed": failed,
		"fear": _fear,
		"sequence": _sequence,
	}


func check_hand_action(percentile_roll: Variant) -> Dictionary:
	return check_hand_failure(percentile_roll)


func hand_action_fails(percentile_roll: Variant) -> bool:
	var receipt := check_hand_failure(percentile_roll)
	return bool(receipt.get("failed", false))


## Applies an already-resolved doll event with an optional stale-snapshot guard.
## Atomically updates fear (0..100) and queues Lose the Strings when fear hits 100.
func apply_observed_event(event: Variant, expected_snapshot: Variant = null) -> Dictionary:
	if not _valid:
		return {"ok": false, "error": "invalid service instance", "sequence": _sequence, "fear": _fear}
	var stale_check := _check_stale_snapshot(expected_snapshot)
	if not stale_check["ok"]:
		return stale_check

	if typeof(event) != TYPE_DICTIONARY:
		return {"ok": false, "error": "event must be a Dictionary", "sequence": _sequence, "fear": _fear}

	var d: Dictionary = event
	var eval_result := _evaluate_event_delta(d)
	if not eval_result["ok"]:
		return {
			"ok": false,
			"error": eval_result["error"],
			"sequence": _sequence,
			"fear": _fear,
		}

	var delta: int = int(eval_result["delta"])
	var kind: String = str(eval_result["kind"])
	var before_fear := _fear
	var new_fear: int = clampi(before_fear + delta, FEAR_MIN, FEAR_MAX)

	var queued_interruption := false
	if new_fear >= LOSE_STRINGS_THRESHOLD:
		if not _pending_lost_strings:
			_pending_lost_strings = true
			queued_interruption = true

	_fear = new_fear
	_sequence += 1

	return {
		"ok": true,
		"kind": kind,
		"event": kind,
		"delta": delta,
		"before_fear": before_fear,
		"after_fear": _fear,
		"fear": _fear,
		"shake": is_shaking(),
		"pending_lost_strings": _pending_lost_strings,
		"interruption_queued": queued_interruption,
		"sequence": _sequence,
	}.duplicate(true)


func apply_event(event: Variant, expected_snapshot: Variant = null) -> Dictionary:
	return apply_observed_event(event, expected_snapshot)


## Applies a signed Event-choice fear delta exactly once: the result is clamped
## to 0..100, the ledger sequence advances, and reaching 100 queues the Lose the
## Strings interruption. A previously pending interruption is never cancelled,
## and fear dropping below 100 never clears one. Campfire Tell Tales keeps its
## own authored event path; this method never re-derives authored kinds.
func apply_event_delta(delta: Variant, expected_snapshot: Variant = null) -> Dictionary:
	if not _valid:
		return {"ok": false, "error": "invalid service instance", "sequence": _sequence, "fear": _fear}
	var stale_check := _check_stale_snapshot(expected_snapshot)
	if not stale_check["ok"]:
		return stale_check
	if typeof(delta) != TYPE_INT:
		return {"ok": false, "error": "event fear delta must be a native integer", "sequence": _sequence, "fear": _fear}
	var before_fear := _fear
	var new_fear: int = clampi(before_fear + int(delta), FEAR_MIN, FEAR_MAX)
	var queued_interruption := false
	if new_fear >= LOSE_STRINGS_THRESHOLD and not _pending_lost_strings:
		_pending_lost_strings = true
		queued_interruption = true
	_fear = new_fear
	_sequence += 1
	return {
		"ok": true,
		"kind": "event_delta",
		"event": "event_delta",
		"delta": int(delta),
		"before_fear": before_fear,
		"after_fear": _fear,
		"fear": _fear,
		"shake": is_shaking(),
		"pending_lost_strings": _pending_lost_strings,
		"interruption_queued": queued_interruption,
		"sequence": _sequence,
	}.duplicate(true)


func apply_choice_delta(delta: Variant, expected_snapshot: Variant = null) -> Dictionary:
	return apply_event_delta(delta, expected_snapshot)


## Consumes the pending Lose the Strings interruption on doll-turn admission.
## Skips exactly one doll turn, resets fear to 60, and clears the pending interruption.
## Fails atomically if no interruption is pending.
func consume_next_doll_turn(expected_snapshot: Variant = null) -> Dictionary:
	if not _valid:
		return {"ok": false, "error": "invalid service instance", "sequence": _sequence, "fear": _fear, "skip_turn": false}
	var stale_check := _check_stale_snapshot(expected_snapshot)
	if not stale_check["ok"]:
		return stale_check

	if not _pending_lost_strings:
		return {
			"ok": false,
			"error": "no pending lost-strings interruption",
			"skip_turn": false,
			"fear": _fear,
			"pending_lost_strings": false,
			"sequence": _sequence,
		}

	var before_fear := _fear
	_pending_lost_strings = false
	_fear = RESET_FEAR_AFTER_LOST_STRINGS
	_sequence += 1

	return {
		"ok": true,
		"skip_turn": true,
		"interruption": "lose_the_strings",
		"event": "lose_the_strings",
		"action": "lose_the_strings",
		"before_fear": before_fear,
		"after_fear": _fear,
		"fear": _fear,
		"shake": is_shaking(),
		"pending_lost_strings": false,
		"sequence": _sequence,
	}.duplicate(true)


func consume_lost_strings(expected_snapshot: Variant = null) -> Dictionary:
	return consume_next_doll_turn(expected_snapshot)


func admit_doll_turn(expected_snapshot: Variant = null) -> Dictionary:
	return consume_next_doll_turn(expected_snapshot)


func _check_stale_snapshot(expected_snapshot: Variant) -> Dictionary:
	if expected_snapshot == null:
		return {"ok": true}
	if typeof(expected_snapshot) == TYPE_INT:
		if int(expected_snapshot) != _sequence:
			return {
				"ok": false,
				"error": "stale snapshot: sequence mismatch (expected %d, got %d)" % [int(expected_snapshot), _sequence],
				"sequence": _sequence,
				"fear": _fear,
			}
		return {"ok": true}
	if typeof(expected_snapshot) == TYPE_DICTIONARY:
		var d: Dictionary = expected_snapshot
		if d.has("sequence"):
			if typeof(d["sequence"]) != TYPE_INT or int(d["sequence"]) != _sequence:
				return {
					"ok": false,
					"error": "stale snapshot: sequence mismatch",
					"sequence": _sequence,
					"fear": _fear,
				}
		if d.has("fear"):
			if typeof(d["fear"]) != TYPE_INT or int(d["fear"]) != _fear:
				return {
					"ok": false,
					"error": "stale snapshot: fear mismatch",
					"sequence": _sequence,
					"fear": _fear,
				}
		return {"ok": true}
	return {
		"ok": false,
		"error": "invalid expected snapshot type",
		"sequence": _sequence,
		"fear": _fear,
	}


func _evaluate_event_delta(event: Dictionary) -> Dictionary:
	var kind_raw: Variant = event.get("kind", event.get("event", event.get("action", event.get("type", null))))
	if kind_raw == null and event.has("transition"):
		kind_raw = event["transition"]
	if kind_raw == null:
		return {"ok": false, "error": "missing event kind"}
	if typeof(kind_raw) != TYPE_STRING:
		return {"ok": false, "error": "invalid event kind type (expected string)"}

	var kind_str := str(kind_raw).to_lower().strip_edges()
	if kind_str.is_empty():
		return {"ok": false, "error": "event kind cannot be empty"}

	match kind_str:
		"fray", "fray_gain", "doll_fray", "gain_fray":
			var amount_val: Variant = null
			for key: String in ["amount", "change", "gain", "fray", "fray_gain"]:
				if event.has(key):
					amount_val = event[key]
					break
			if amount_val == null:
				return {"ok": false, "error": "fray event missing amount/change"}
			if typeof(amount_val) != TYPE_INT:
				return {"ok": false, "error": "fray gain amount must be an integer"}
			var amount := int(amount_val)
			if amount < 0:
				return {"ok": false, "error": "fray gain amount cannot be negative (%d)" % amount}
			var delta := FRAY_GAIN_FEAR_DELTA if amount >= FRAY_GAIN_FEAR_THRESHOLD else 0
			return {"ok": true, "kind": "fray_gain", "delta": delta}

		"hanging", "enter_hanging", "hanging_by_a_thread":
			return {"ok": true, "kind": "hanging", "delta": HANGING_FEAR_DELTA}

		"lost", "doll_lost", "hero_lost":
			return {"ok": true, "kind": "lost", "delta": LOST_FEAR_DELTA}

		"round", "round_completed", "completed_round", "round_end", "end_round":
			var band_name := ""
			if event.has("band"):
				var band_val: Variant = event["band"]
				if typeof(band_val) == TYPE_STRING:
					band_name = str(band_val).to_lower().strip_edges()
				elif typeof(band_val) == TYPE_DICTIONARY:
					band_name = str(band_val.get("name", "")).to_lower().strip_edges()
				else:
					return {"ok": false, "error": "invalid candle band payload"}
			elif event.has("candle"):
				var candle_val: Variant = event["candle"]
				if typeof(candle_val) != TYPE_INT:
					return {"ok": false, "error": "candle value must be an integer"}
				var c := int(candle_val)
				if c < 0 or c > 100:
					return {"ok": false, "error": "candle value %d out of bounds (0..100)" % c}
				var band_info := StitchedS1BEffects.candle_band(c)
				band_name = str(band_info.get("name", "")).to_lower().strip_edges()
			else:
				return {"ok": false, "error": "round completed event requires 'band' or 'candle'"}

			if not CANDLE_ROUND_FEAR_DELTAS.has(band_name):
				return {"ok": false, "error": "unknown candle band '%s'" % band_name}
			return {"ok": true, "kind": "round_completed", "delta": int(CANDLE_ROUND_FEAR_DELTAS[band_name])}

		"steadfast", "doll_steadfast", "turn_steadfast":
			return {"ok": true, "kind": "steadfast", "delta": STEADFAST_FEAR_DELTA}

		"fight_won", "won_fight", "battle_won", "victory", "win_fight":
			return {"ok": true, "kind": "fight_won", "delta": FIGHT_WON_FEAR_DELTA}

		"tell_tales", "campfire_tell_tales", "campfire", "tell_tale":
			return {"ok": true, "kind": "tell_tales", "delta": TELL_TALES_FEAR_DELTA}

		_:
			return {"ok": false, "error": "unknown event kind '%s'" % kind_str}
