class_name RunEventChoice
extends RefCounted
## One-visit authored M04 event choice service.
## Each instance holds a single authored event record; the first offered choice
## that validates is claimed exactly once and every later choice is rejected.
## No scene dependencies, no RNG use, and no outcome effects: a claim only
## commits the opaque authored choice ID (no healing, gold, card or trinket
## results). Like RunCardRewardChoice, a consumed instance reports
## is_valid() == false while is_claimed() stays true.

var _event: Dictionary = {}
var _valid: bool = false
var _claimed: bool = false


func _init(event_record: Variant = null) -> void:
	# Fail closed on anything that is not a Dictionary; never coerce types.
	if not event_record is Dictionary:
		return
	var copy: Dictionary = (event_record as Dictionary).duplicate(true)
	if not _is_nonblank_string(copy.get("id")):
		return
	if not _is_nonblank_string(copy.get("title")):
		return
	if not _is_nonblank_string(copy.get("description")):
		return
	var choices: Variant = copy.get("choices")
	if not choices is Array:
		return
	if (choices as Array).size() < 2 or (choices as Array).size() > 3:
		return
	var seen := {}
	for choice in choices:
		if not choice is Dictionary:
			return
		var choice_id: Variant = (choice as Dictionary).get("id")
		var text: Variant = (choice as Dictionary).get("text")
		if not _is_nonblank_string(choice_id) or not _is_nonblank_string(text):
			return
		if seen.has(choice_id):
			return
		seen[choice_id] = true
	_event = copy
	_valid = true


## True only while this offering is schema-valid and still unclaimed.
func is_valid() -> bool:
	return _valid and not _claimed


## True once a choice has been committed on this instance.
func is_claimed() -> bool:
	return _claimed


## A detached deep copy of the authored event; mutating it never reaches
## this instance or the caller's original record.
func get_event() -> Dictionary:
	return _event.duplicate(true)


## Attempts the single allowed claim.
## Returns exactly {"ok": bool, "event_id": String, "choice_id": String}.
## Rejections (invalid construction, blank/unoffered choice, replay) return
## ok=false with empty IDs and consume no claim, mutating no state.
func choose(choice_id: String) -> Dictionary:
	if not _valid or _claimed:
		return _rejection()
	if choice_id.strip_edges().is_empty():
		return _rejection()
	var choices: Array = _event.get("choices", [])
	for choice in choices:
		if choice is Dictionary and (choice as Dictionary).get("id") == choice_id:
			_claimed = true
			return {"ok": true, "event_id": _event.get("id", ""), "choice_id": choice_id}
	return _rejection()


func _rejection() -> Dictionary:
	return {"ok": false, "event_id": "", "choice_id": ""}


func _is_nonblank_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return not text.strip_edges().is_empty()
