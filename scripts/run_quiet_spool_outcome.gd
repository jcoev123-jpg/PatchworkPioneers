class_name RunQuietSpoolOutcome
extends RefCounted

const EVENT_ID: String = "quiet_spool"
const CHOICE_WATCH: String = "watch"
const CHOICE_IGNORE: String = "ignore"
const WATCH_SCRAP_GAIN: int = 1
const IGNORE_SCRAP_GAIN: int = 0

var _consumed: bool = false


func is_consumed() -> bool:
	return _consumed


func choose(event_id: Variant, choice_id: Variant, current_scraps: Variant) -> Dictionary:
	var fallback_scraps: int = int(current_scraps) if typeof(current_scraps) == TYPE_INT else 0
	if _consumed:
		return _rejected_receipt(fallback_scraps)
	if typeof(event_id) != TYPE_STRING or typeof(choice_id) != TYPE_STRING or typeof(current_scraps) != TYPE_INT:
		return _rejected_receipt(fallback_scraps)
	var scraps_value: int = int(current_scraps)
	if scraps_value < 0:
		return _rejected_receipt(scraps_value)
	var event_key: String = String(event_id)
	if event_key != EVENT_ID:
		return _rejected_receipt(scraps_value)
	var choice_key: String = String(choice_id)
	var scrap_delta: int = 0
	if choice_key == CHOICE_WATCH:
		scrap_delta = WATCH_SCRAP_GAIN
	elif choice_key == CHOICE_IGNORE:
		scrap_delta = IGNORE_SCRAP_GAIN
	else:
		return _rejected_receipt(scraps_value)

	_consumed = true
	return {
		"ok": true,
		"event_id": EVENT_ID,
		"choice_id": choice_key,
		"scraps": scraps_value + scrap_delta,
	}


func _rejected_receipt(scraps_value: int) -> Dictionary:
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"scraps": scraps_value,
	}
