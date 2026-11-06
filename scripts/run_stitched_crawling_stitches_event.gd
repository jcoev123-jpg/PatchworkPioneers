class_name RunStitchedCrawlingStitchesEvent
extends RefCounted
## Scene-free helper for the Crawling Stitches Walk horror event (Design v4 STITCHED section 9b).
##
## Evaluates atmospheric cues (crawling stitches and button eyes at lead FRAY 100+)
## and the 25% two-step wrong-turn misdirection for an Unravelled rank-1 lead doll.
## Does not create RNG, draw randomness, mutate snapshots, or alter corridor state.

const HORROR_ID := "wandering_seams"
const HORROR_KIND := "stitches"
const HORROR_NAME := "Crawling Stitches"

const LEAD_RANK := 1
const FRAY_MIN := 0
const FRAY_MAX := 200
const FRAY_CUE_THRESHOLD := 100

const WRONG_TURN_EXTRA_STEPS := 2
const WRONG_TURN_CHANCE_PERCENT := 25
const PERCENTILE_MIN := 1
const PERCENTILE_MAX := 100

const UNRAVELLED_TRAITS := ["frantic", "hollow", "bitter", "reckless", "cowering"]
const VALID_RESOLVE_STATUSES := ["", "steadfast", "frantic", "hollow", "bitter", "reckless", "cowering"]

var _horror: Dictionary = {}
var _lead: Dictionary = {}


func _init(horror: Variant = null, lead: Variant = null) -> void:
	if horror is Dictionary:
		_horror = (horror as Dictionary).duplicate(true)
	if lead is Dictionary:
		_lead = (lead as Dictionary).duplicate(true)


static func is_canonical_horror(horror: Variant) -> bool:
	if typeof(horror) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = horror
	return str(d.get("id", "")) == HORROR_ID and str(d.get("kind", "")) == HORROR_KIND


static func is_unravelled(resolve_status: Variant) -> bool:
	if typeof(resolve_status) != TYPE_STRING:
		return false
	var trait_str := str(resolve_status)
	return trait_str in StitchedS1BEffects.RESOLVE_TRAITS


static func find_horror_by_id(horrors_data: Variant, target_id: String = HORROR_ID) -> Dictionary:
	if typeof(horrors_data) == TYPE_DICTIONARY:
		var d: Dictionary = horrors_data
		if d.has("horrors") and typeof(d["horrors"]) == TYPE_ARRAY:
			for item: Variant in d["horrors"]:
				if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == target_id:
					return (item as Dictionary).duplicate(true)
	elif typeof(horrors_data) == TYPE_ARRAY:
		for item: Variant in horrors_data:
			if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == target_id:
				return (item as Dictionary).duplicate(true)
	return {}


static func validate_horror(horror: Variant) -> Dictionary:
	if typeof(horror) != TYPE_DICTIONARY:
		return {"ok": false, "error": "horror record must be a Dictionary"}
	var d: Dictionary = horror
	if str(d.get("id", "")) != HORROR_ID:
		return {"ok": false, "error": "invalid horror id '%s', expected '%s'" % [str(d.get("id", "")), HORROR_ID]}
	if str(d.get("kind", "")) != HORROR_KIND:
		return {"ok": false, "error": "invalid horror kind '%s', expected '%s'" % [str(d.get("kind", "")), HORROR_KIND]}
	return {"ok": true, "error": ""}


static func validate_lead(lead: Variant) -> Dictionary:
	if typeof(lead) != TYPE_DICTIONARY:
		return {"ok": false, "error": "lead snapshot must be a Dictionary"}
	var d: Dictionary = lead
	var rank_val: Variant = d.get("rank")
	if typeof(rank_val) != TYPE_INT or int(rank_val) != LEAD_RANK:
		return {"ok": false, "error": "lead must be rank %d, got %s" % [LEAD_RANK, str(rank_val)]}
	var fray_val: Variant = d.get("fray")
	if typeof(fray_val) != TYPE_INT:
		return {"ok": false, "error": "lead fray must be an integer, got %s" % str(fray_val)}
	var fray_int := int(fray_val)
	if fray_int < FRAY_MIN or fray_int > FRAY_MAX:
		return {"ok": false, "error": "lead fray %d out of bounds (%d..%d)" % [fray_int, FRAY_MIN, FRAY_MAX]}
	var resolve_val: Variant = d.get("resolve", "")
	if resolve_val != null:
		if typeof(resolve_val) != TYPE_STRING:
			return {"ok": false, "error": "lead resolve must be a String"}
		var resolve_str := str(resolve_val)
		if not resolve_str in VALID_RESOLVE_STATUSES:
			return {"ok": false, "error": "lead resolve '%s' is not a recognized resolve trait" % resolve_str}
	return {"ok": true, "error": ""}


static func preview(horror: Variant, lead: Variant) -> Dictionary:
	var horror_check := validate_horror(horror)
	if not bool(horror_check.get("ok", false)):
		return _refusal(str(horror_check.get("error", "invalid horror")), horror, lead, false, false, false, 0)

	var lead_check := validate_lead(lead)
	if not bool(lead_check.get("ok", false)):
		return _refusal(str(lead_check.get("error", "invalid lead")), horror, lead, false, false, false, 0)

	var lead_dict: Dictionary = lead
	var fray := int(lead_dict.get("fray", 0))
	var resolve_str := str(lead_dict.get("resolve", "")) if lead_dict.has("resolve") and lead_dict.get("resolve") != null else ""
	var cue: bool = (fray >= FRAY_CUE_THRESHOLD)
	var unravelled: bool = is_unravelled(resolve_str)
	var eligible: bool = cue and unravelled

	return {
		"ok": true,
		"error": "",
		"horror_id": HORROR_ID,
		"horror_kind": HORROR_KIND,
		"lead_id": str(lead_dict.get("id", "")),
		"lead_rank": LEAD_RANK,
		"lead_fray": fray,
		"lead_resolve": resolve_str,
		"cue": cue,
		"cue_visible": cue,
		"eligible": eligible,
		"roll_eligible": eligible,
		"unravelled": unravelled,
		"extra_steps": 0,
	}


static func resolve(horror: Variant, lead: Variant, roll: Variant = null) -> Dictionary:
	var horror_check := validate_horror(horror)
	if not bool(horror_check.get("ok", false)):
		return _refusal(str(horror_check.get("error", "invalid horror")), horror, lead, false, false, false, 0)

	var lead_check := validate_lead(lead)
	if not bool(lead_check.get("ok", false)):
		return _refusal(str(lead_check.get("error", "invalid lead")), horror, lead, false, false, false, 0)

	var lead_dict: Dictionary = lead
	var fray := int(lead_dict.get("fray", 0))
	var resolve_str := str(lead_dict.get("resolve", "")) if lead_dict.has("resolve") and lead_dict.get("resolve") != null else ""
	var cue: bool = (fray >= FRAY_CUE_THRESHOLD)
	var unravelled: bool = is_unravelled(resolve_str)
	var eligible: bool = cue and unravelled

	if eligible:
		if roll == null:
			return _refusal("percentile roll required for eligible lead", horror, lead, cue, eligible, unravelled, 0)
		if typeof(roll) != TYPE_INT or int(roll) < PERCENTILE_MIN or int(roll) > PERCENTILE_MAX:
			return _refusal("out-of-range percentile for eligible roll: %s" % str(roll), horror, lead, cue, eligible, unravelled, 0)

		var roll_int := int(roll)
		var wrong_turn: bool = (roll_int >= 1 and roll_int <= WRONG_TURN_CHANCE_PERCENT)
		var extra_steps: int = WRONG_TURN_EXTRA_STEPS if wrong_turn else 0

		return {
			"ok": true,
			"error": "",
			"horror_id": HORROR_ID,
			"horror_kind": HORROR_KIND,
			"lead_id": str(lead_dict.get("id", "")),
			"lead_rank": LEAD_RANK,
			"lead_fray": fray,
			"lead_resolve": resolve_str,
			"cue": cue,
			"cue_visible": cue,
			"eligible": eligible,
			"roll_eligible": eligible,
			"unravelled": unravelled,
			"roll": roll_int,
			"wrong_turn": wrong_turn,
			"extra_steps": extra_steps,
		}
	else:
		if roll != null and (typeof(roll) != TYPE_INT or int(roll) < PERCENTILE_MIN or int(roll) > PERCENTILE_MAX):
			return _refusal("out-of-range percentile: %s" % str(roll), horror, lead, cue, eligible, unravelled, 0)

		var roll_int := int(roll) if typeof(roll) == TYPE_INT else 0
		return {
			"ok": true,
			"error": "",
			"horror_id": HORROR_ID,
			"horror_kind": HORROR_KIND,
			"lead_id": str(lead_dict.get("id", "")),
			"lead_rank": LEAD_RANK,
			"lead_fray": fray,
			"lead_resolve": resolve_str,
			"cue": cue,
			"cue_visible": cue,
			"eligible": false,
			"roll_eligible": false,
			"unravelled": unravelled,
			"roll": roll_int,
			"wrong_turn": false,
			"extra_steps": 0,
		}


static func resolve_wrong_turn(horror: Variant, lead: Variant, roll: Variant = null) -> Dictionary:
	return resolve(horror, lead, roll)


func preview_event(lead_override: Variant = null) -> Dictionary:
	var l: Variant = lead_override if lead_override != null else _lead
	return preview(_horror, l)


func resolve_event(roll: Variant = null, lead_override: Variant = null) -> Dictionary:
	var l: Variant = lead_override if lead_override != null else _lead
	return resolve(_horror, l, roll)


static func _refusal(
	error_message: String,
	horror: Variant,
	lead: Variant,
	cue: bool,
	eligible: bool,
	unravelled: bool,
	roll: int
) -> Dictionary:
	var horror_dict: Dictionary = horror if typeof(horror) == TYPE_DICTIONARY else {}
	var lead_dict: Dictionary = lead if typeof(lead) == TYPE_DICTIONARY else {}
	var lead_rank := int(lead_dict.get("rank", 0)) if (lead_dict.has("rank") and typeof(lead_dict.get("rank")) == TYPE_INT) else 0
	var lead_fray := int(lead_dict.get("fray", 0)) if (lead_dict.has("fray") and typeof(lead_dict.get("fray")) == TYPE_INT) else 0
	var lead_resolve := str(lead_dict.get("resolve", "")) if lead_dict.has("resolve") and lead_dict.get("resolve") != null else ""

	return {
		"ok": false,
		"error": error_message,
		"horror_id": str(horror_dict.get("id", "")),
		"horror_kind": str(horror_dict.get("kind", "")),
		"lead_id": str(lead_dict.get("id", "")),
		"lead_rank": lead_rank,
		"lead_fray": lead_fray,
		"lead_resolve": lead_resolve,
		"cue": cue,
		"cue_visible": cue,
		"eligible": eligible,
		"roll_eligible": eligible,
		"unravelled": unravelled,
		"roll": roll,
		"wrong_turn": false,
		"extra_steps": 0,
	}
