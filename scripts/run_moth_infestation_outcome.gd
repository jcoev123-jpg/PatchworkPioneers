class_name RunMothInfestationOutcome
extends RefCounted
## Scene-free one-visit Moth Infestation transaction. A single authored event
## choice is committed at most once per instance. The complete run deck ledger
## (deck, stitched descriptors, allocator cursor and scraps) is validated through
## RunRestStitchCards before any sacrifice, fumigation or escape is applied.
## No RNG, combat, gold, draw/discard piles or unrelated run state are touched.

const EVENT_ID := "moth_infestation"
const CHOICE_SACRIFICE := "sacrifice_card"
const CHOICE_FUMIGATE := "fumigate"
const CHOICE_ESCAPE := "escape"
const SACRIFICE_SCRAP_GAIN := 2
const FUMIGATE_SCRAP_COST := 1
const MAX_INT := 9223372036854775807

var _consumed: bool = false
var _valid: bool = false
var _deck: Array[String] = []
var _descriptors: Dictionary = {}
var _next_stitch_id: int = 1
var _scraps: int = 0
var _has_ledger: bool = false


func _init(deck_ids: Variant = null, descriptors: Variant = null,
		next_stitch_id: Variant = null, scraps: Variant = null) -> void:
	if deck_ids == null and descriptors == null and next_stitch_id == null and scraps == null:
		_valid = false
		_has_ledger = false
		return
	var cursor: Variant = next_stitch_id
	var scrap_value: Variant = scraps
	var descriptor_value: Variant = descriptors
	if not _ledger_is_valid(deck_ids, descriptor_value, cursor, scrap_value):
		_valid = false
		_has_ledger = false
		_deck.clear()
		_descriptors.clear()
		return
	_deck = _deep_copy_deck(deck_ids)
	_descriptors = (descriptor_value as Dictionary).duplicate(true)
	_next_stitch_id = cursor
	_scraps = scrap_value
	_valid = true
	_has_ledger = true


func is_valid() -> bool:
	return _valid and not _consumed


func is_consumed() -> bool:
	return _consumed


## Detached authored choice/ordinary-occurrence forecast for this visit only.
## A claimed or malformed ledger never produces actionable menu entries.
func preview_choices() -> Dictionary:
	if not is_valid() or not _has_ledger:
		return {"ok": false, "event_id": "", "choices": [], "sacrifice_cards": []}
	return RunMothInfestationChoiceOptions.build(
		_deck.duplicate(), _descriptors.duplicate(true), _scraps,
		MAX_INT, SACRIFICE_SCRAP_GAIN, FUMIGATE_SCRAP_COST)


func has_ledger() -> bool:
	return _has_ledger


func get_deck() -> Array[String]:
	return _deck.duplicate()


func get_descriptors() -> Dictionary:
	return _descriptors.duplicate(true)


func get_next_stitch_id() -> int:
	return _next_stitch_id


func get_scraps() -> int:
	return _scraps


func choose(a: Variant = null, b: Variant = null, c: Variant = null,
		d: Variant = null, e: Variant = null, f: Variant = null,
		g: Variant = null) -> Dictionary:
	return _choose_with_args([a, b, c, d, e, f, g])


func choose_outcome(a: Variant = null, b: Variant = null, c: Variant = null,
		d: Variant = null, e: Variant = null, f: Variant = null,
		g: Variant = null) -> Dictionary:
	return _choose_with_args([a, b, c, d, e, f, g])


func resolve(a: Variant = null, b: Variant = null, c: Variant = null,
		d: Variant = null, e: Variant = null, f: Variant = null,
		g: Variant = null) -> Dictionary:
	return _choose_with_args([a, b, c, d, e, f, g])


func apply(a: Variant = null, b: Variant = null, c: Variant = null,
		d: Variant = null, e: Variant = null, f: Variant = null,
		g: Variant = null) -> Dictionary:
	return _choose_with_args([a, b, c, d, e, f, g])


func commit(a: Variant = null, b: Variant = null, c: Variant = null,
		d: Variant = null, e: Variant = null, f: Variant = null,
		g: Variant = null) -> Dictionary:
	return _choose_with_args([a, b, c, d, e, f, g])


func _choose_with_args(args: Array) -> Dictionary:
	var deck_input: Variant = null
	var descriptors_input: Variant = null
	var cursor_input: Variant = null
	var scraps_input: Variant = null
	var event_id: Variant = null
	var choice_id: Variant = null
	var selected_index: Variant = null

	# Ledger-first calling convention:
	# choose(deck, descriptors, cursor, scraps, event_id, choice_id, selected_index)
	if args.size() >= 1 and args[0] is Array:
		deck_input = args[0]
		descriptors_input = args[1] if args.size() > 1 else null
		cursor_input = args[2] if args.size() > 2 else null
		scraps_input = args[3] if args.size() > 3 else null
		event_id = args[4] if args.size() > 4 else null
		choice_id = args[5] if args.size() > 5 else null
		selected_index = args[6] if args.size() > 6 else null
	elif args.size() >= 1 and args[0] is String:
		# Event-first calling convention:
		# choose(event_id, choice_id, selected_index, deck?, descriptors?, cursor?, scraps?)
		event_id = args[0]
		choice_id = args[1] if args.size() > 1 else null
		selected_index = args[2] if args.size() > 2 else null
		if args.size() > 3 and args[3] is Array:
			deck_input = args[3]
			descriptors_input = args[4] if args.size() > 4 else null
			cursor_input = args[5] if args.size() > 5 else null
			scraps_input = args[6] if args.size() > 6 else null
		else:
			# Stored ledger.
			if _has_ledger:
				deck_input = _deck.duplicate()
				descriptors_input = _descriptors.duplicate(true)
				cursor_input = _next_stitch_id
				scraps_input = _scraps
	else:
		# Fall back to stored ledger when no explicit ledger was supplied.
		if _has_ledger:
			deck_input = _deck.duplicate()
			descriptors_input = _descriptors.duplicate(true)
			cursor_input = _next_stitch_id
			scraps_input = _scraps
			event_id = args[0]
			choice_id = args[1] if args.size() > 1 else null
			selected_index = args[2] if args.size() > 2 else null

	if deck_input == null:
		if _has_ledger:
			deck_input = _deck.duplicate()
			descriptors_input = _descriptors.duplicate(true)
			cursor_input = _next_stitch_id
			scraps_input = _scraps
		else:
			deck_input = []
			descriptors_input = {} if descriptors_input == null else descriptors_input
			cursor_input = 1 if cursor_input == null else cursor_input
			scraps_input = 0 if scraps_input == null else scraps_input

	# Work on deep copies so caller inputs are never mutated.
	var deck_copy: Array[String] = _deep_copy_deck(deck_input)

	if descriptors_input == null or cursor_input == null or scraps_input == null:
		return _rejection(deck_copy, {}, 0, 0)
	var descriptor_copy: Dictionary = {}
	if descriptors_input is Dictionary:
		descriptor_copy = (descriptors_input as Dictionary).duplicate(true)
	else:
		return _rejection(deck_copy, descriptors_input if descriptors_input is Dictionary else {},
				cursor_input, scraps_input)

	var cursor_value: int = 0
	var cursor_ok := typeof(cursor_input) == TYPE_INT
	if cursor_ok:
		cursor_value = cursor_input
	var scraps_value: int = 0
	var scraps_ok := typeof(scraps_input) == TYPE_INT
	if scraps_ok:
		scraps_value = scraps_input

	# Validate complete genuine run ledger.
	if not _ledger_is_valid(deck_copy, descriptor_copy, cursor_input, scraps_input):
		return _rejection(deck_copy, descriptor_copy, cursor_input, scraps_input)

	# Repeated claim guard.
	if _consumed:
		return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)

	# Validate event and choice.
	if typeof(event_id) != TYPE_STRING or String(event_id) != EVENT_ID:
		return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
	if typeof(choice_id) != TYPE_STRING:
		return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
	var choice: String = String(choice_id)
	if choice != CHOICE_SACRIFICE and choice != CHOICE_FUMIGATE and choice != CHOICE_ESCAPE:
		return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)

	# Apply the chosen branch.
	var next_deck: Array[String] = deck_copy.duplicate()
	var next_descriptors: Dictionary = descriptor_copy.duplicate(true)
	var next_cursor: int = cursor_value
	var next_scraps: int = scraps_value

	if choice == CHOICE_SACRIFICE:
		if typeof(selected_index) != TYPE_INT:
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		var index: int = selected_index
		if index < 0 or index >= next_deck.size():
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		var card_id: String = next_deck[index]
		if not _is_removable_ordinary(card_id, descriptor_copy):
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		if next_scraps > MAX_INT - SACRIFICE_SCRAP_GAIN:
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		next_deck.remove_at(index)
		next_scraps += SACRIFICE_SCRAP_GAIN
	elif choice == CHOICE_FUMIGATE:
		if scraps_value < FUMIGATE_SCRAP_COST:
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		if scraps_value - FUMIGATE_SCRAP_COST < 0:
			return _rejection(deck_copy, descriptor_copy, cursor_value, scraps_value)
		next_scraps = scraps_value - FUMIGATE_SCRAP_COST
	elif choice == CHOICE_ESCAPE:
		next_scraps = scraps_value

	# Commit.
	_consumed = true
	if _has_ledger:
		_deck = next_deck.duplicate()
		_descriptors = next_descriptors.duplicate(true)
		_next_stitch_id = next_cursor
		_scraps = next_scraps
		_valid = true

	var result := {
		"ok": true,
		"event_id": EVENT_ID,
		"choice_id": choice,
		"deck": next_deck.duplicate(),
		"descriptors": next_descriptors.duplicate(true),
		"next_stitch_id": next_cursor,
		"cursor": next_cursor,
		"scraps": next_scraps,
		"remaining_scraps": next_scraps,
	}
	return result


func _rejection(deck: Array[String], descriptors: Dictionary, cursor: Variant, scraps: Variant) -> Dictionary:
	var cursor_value: int = 0
	if typeof(cursor) == TYPE_INT:
		cursor_value = cursor
	var scraps_value: int = 0
	if typeof(scraps) == TYPE_INT:
		scraps_value = scraps
	var descriptor_copy: Dictionary = {}
	if descriptors is Dictionary:
		descriptor_copy = (descriptors as Dictionary).duplicate(true)
	return {
		"ok": false,
		"event_id": "",
		"choice_id": "",
		"deck": deck.duplicate(),
		"descriptors": descriptor_copy,
		"next_stitch_id": cursor_value,
		"cursor": cursor_value,
		"scraps": scraps_value,
		"remaining_scraps": scraps_value,
	}


func _ledger_is_valid(deck_ids: Variant, descriptors: Variant, cursor: Variant, scraps: Variant) -> bool:
	if typeof(deck_ids) != TYPE_ARRAY:
		return false
	var deck: Array = deck_ids
	if deck.is_empty():
		return false
	for entry in deck:
		if typeof(entry) != TYPE_STRING:
			return false
		var card_id: String = entry
		if card_id.is_empty():
			return false
	if typeof(descriptors) != TYPE_DICTIONARY:
		return false
	if typeof(cursor) != TYPE_INT:
		return false
	var cursor_value: int = cursor
	if cursor_value < 1 or cursor_value >= MAX_INT:
		return false
	if typeof(scraps) != TYPE_INT:
		return false
	var scraps_value: int = scraps
	if scraps_value < 0:
		return false
	var ledger := RunRestStitchCards.new(deck, (descriptors as Dictionary).duplicate(true), scraps_value, cursor_value)
	return ledger.is_valid()


func _deep_copy_deck(source: Variant) -> Array[String]:
	var result: Array[String] = []
	if source is Array:
		for entry in source:
			if entry is String:
				result.append(String(entry))
	return result


func _is_removable_ordinary(card_id: String, descriptors: Dictionary) -> bool:
	if card_id.is_empty():
		return false
	if descriptors.has(card_id):
		return false
	if card_id.begins_with("stitched_"):
		return false
	var definition: Dictionary = RunRestStitchCards.resolve_card_definition(card_id)
	return not definition.is_empty()