class_name VillagePathPreview
extends RefCounted
## Read-only Quilt-village Path preview formatter (D2-5).
##
## The village is handed only {id, display_name, card_name} for each authored
## Path. This formatter resolves those against the genuine authored records the
## pre-run services expose - RunSeamstressPathChoice.new().get_paths() and
## RunTinkerPathChoice.new().get_offers() - and, only when the option's ID,
## displayed name and card name all match one complete record, describes that
## Path's PASSIVE and its one CARD (name, cost, positions, target, printed
## effect).
##
## It reads no scene, run, deck, currency, registry or RNG state and can never
## claim a Path: hover and keyboard focus here are presentation only. An
## unknown or mismatched option returns an empty dictionary and no invented
## rule, so callers keep their existing tooltip and hint behaviour.

const SEAMSTRESS := "seamstress"
const TINKER := "tinker"


## Preview of one presented Seamstress Path option, or {} when it is not exactly
## a genuine authored record.
static func seamstress(option: Variant) -> Dictionary:
	return _describe(SEAMSTRESS, option)


## Preview of one presented Tinker Path option, or {} when it is not exactly a
## genuine authored record.
static func tinker(option: Variant) -> Dictionary:
	return _describe(TINKER, option)


static func _describe(owner_id: String, option: Variant) -> Dictionary:
	if not option is Dictionary:
		return {}
	var record := _matching_record(owner_id, option)
	if record.is_empty():
		return {}
	var passive_value: Variant = record.get("passive")
	var card_value: Variant = record.get("card")
	if not passive_value is Dictionary or not card_value is Dictionary:
		return {}
	var passive: Dictionary = passive_value
	var card: Dictionary = card_value
	var path_id := String(record.get("id", ""))
	var passive_text := _passive_text(owner_id, path_id, passive)
	var card_text := _card_text(card)
	var hint := _hint_text(path_id, passive, card)
	if passive_text.is_empty() or card_text.is_empty() or hint.is_empty():
		return {}
	var display_name := String(record.get("display_name", ""))
	var card_name := String(card.get("display_name", ""))
	var owner_label := "Seamstress" if owner_id == SEAMSTRESS else "Tinker"
	return {
		"ok": true,
		"owner": owner_id,
		"path_id": path_id,
		"display_name": display_name,
		"card_name": card_name,
		"passive_text": passive_text,
		"card_text": card_text,
		"tooltip": "%s Path: %s\nPASSIVE: %s\nCARD: %s" % [
			owner_label, display_name, passive_text, card_text],
		"hint": hint,
	}


## The one authored record this option really is, or {} on any mismatch. A
## nonblank option that names an authored ID with another name (or a card name
## that record does not print) is refused rather than repaired.
static func _matching_record(owner_id: String, option: Dictionary) -> Dictionary:
	var path_id := String(option.get("id", ""))
	var display_name := String(option.get("display_name", ""))
	var card_name := String(option.get("card_name", ""))
	if path_id.strip_edges().is_empty() or display_name.strip_edges().is_empty() \
			or card_name.strip_edges().is_empty():
		return {}
	var records: Array = []
	if owner_id == SEAMSTRESS:
		records = RunSeamstressPathChoice.new().get_paths()
	elif owner_id == TINKER:
		records = RunTinkerPathChoice.new().get_offers()
	else:
		return {}
	for raw in records:
		if not raw is Dictionary:
			continue
		var record: Dictionary = raw
		if String(record.get("id", "")) != path_id:
			continue
		var card_value: Variant = record.get("card")
		if not card_value is Dictionary:
			return {}
		var card: Dictionary = card_value
		if String(record.get("display_name", "")) != display_name \
				or String(card.get("display_name", "")) != card_name:
			return {}
		return record.duplicate(true)
	return {}


## PASSIVE line: only the two authored Seamstress and two authored Tinker passive
## contracts are describable; every other shape returns "" and no preview.
static func _passive_text(owner_id: String, path_id: String, passive: Dictionary) -> String:
	if owner_id == SEAMSTRESS:
		if path_id == "bloodline" and String(passive.get("kind", "")) == "bleed_bonus" \
				and String(passive.get("status", "")) == "bleed" \
				and passive.get("stacks") == false and _int_equals(passive.get("value"), 1):
			return "Bleed +%d — her current passive, not another stack" \
				% _int_value(passive.get("value"))
		if path_id == "unpicker" and String(passive.get("kind", "")) == "bleed_adds_unravel" \
				and String(passive.get("status", "")) == "unravel" \
				and passive.get("stacks") == false \
				and String(passive.get("replaces", "")) == "seamstress_bleed_bonus" \
				and _int_equals(passive.get("replaced_value"), 1) \
				and _int_equals(passive.get("value"), 2):
			return "Replaces the Bleed +%d passive: cards that Bleed also add +%d Unravel" % [
				_int_value(passive.get("replaced_value")), _int_value(passive.get("value"))]
		return ""
	if path_id == "sharpshot" and _int_equals(passive.get("bonus_damage"), 3) \
			and String(passive.get("trigger", "")) == "first_successful_tinker_attack_each_player_turn":
		return "The first attack each player turn gets +%d damage (her existing passive)" \
			% _int_value(passive.get("bonus_damage"))
	if path_id == "clockwork" and _int_equals(passive.get("minimum_printed_cost"), 2) \
			and _int_equals(passive.get("discount"), 1) \
			and String(passive.get("trigger", "")) == "first_successful_tinker_card_with_printed_cost_at_least_2_each_player_turn":
		return "The first Tinker card with printed cost %d or more played each turn costs %d less" % [
			_int_value(passive.get("minimum_printed_cost")), _int_value(passive.get("discount"))]
	return ""


## CARD line with cost, positions, target and the printed effect, all read from
## the record. Effects this formatter does not know are never approximated.
static func _card_text(card: Dictionary) -> String:
	var card_name := String(card.get("display_name", ""))
	if card_name.strip_edges().is_empty() or _int_value(card.get("cost")) < 0:
		return ""
	var from_text := _positions_text(card.get("from_positions"), "from")
	var target_text := _target_text(card.get("target_kind"), card.get("to_positions"))
	var effects_value: Variant = card.get("effects")
	if from_text.is_empty() or target_text.is_empty() or not effects_value is Dictionary:
		return ""
	var effect_text := _effects_text(String(card.get("id", "")), effects_value)
	if effect_text.is_empty():
		return ""
	return "%s · cost %d energy · %s · %s · %s" % [
		card_name, _int_value(card.get("cost")), from_text, target_text, effect_text]


static func _effects_text(path_id: String, effects: Dictionary) -> String:
	if path_id == "seamstress_leech_stitch":
		var heal_value: Variant = effects.get("heal")
		if effects.size() != 2 or not _int_equals(effects.get("bleed"), 3) \
				or not heal_value is Dictionary:
			return ""
		var heal: Dictionary = heal_value
		if not _int_equals(heal.get("amount"), 2) \
				or String(heal.get("target", "")) != "weakest_living_ally" \
				or String(heal.get("cap", "")) != "missing_hp":
			return ""
		return "Bleed %d; heals the weakest living ally %d HP (up to its missing HP)" % [
			_int_value(effects.get("bleed")), _int_value(heal.get("amount"))]
	if path_id == "seamstress_fray":
		if effects.size() != 2 or not _int_equals(effects.get("unravel"), 4) \
				or not _int_equals(effects.get("bleed"), 1):
			return ""
		return "Unravel %d; Bleed %d (Unravel threshold 8 normal / 12 elite / 16 boss: an Unravelled enemy skips its next action)" % [
			_int_value(effects.get("unravel")), _int_value(effects.get("bleed"))]
	if path_id == "tinker_scope":
		if effects.size() != 2 or not _int_equals(effects.get("next_attack_damage_bonus"), 4) \
				or String(effects.get("expires", "")) != "end_of_player_turn":
			return ""
		return "the next attack this turn deals +%d damage" \
			% _int_value(effects.get("next_attack_damage_bonus"))
	if path_id == "tinker_wind_up":
		if effects.size() != 1 or not _int_equals(effects.get("next_turn_energy"), 1):
			return ""
		return "+%d energy next turn" % _int_value(effects.get("next_turn_energy"))
	return ""


## Short one-line preview for the board's existing hint label. Only authored,
## already-verified IDs reach here; the card name, cost and passive numbers are
## read from that record so the hint can never drift from it.
static func _hint_text(path_id: String, passive: Dictionary, card: Dictionary) -> String:
	var card_name := String(card.get("display_name", ""))
	var cost := _int_value(card.get("cost"))
	if card_name.strip_edges().is_empty() or cost < 0:
		return ""
	match path_id:
		"bloodline":
			return "Bleed +%d · %s (%d energy)" % [
				_int_value(passive.get("value")), card_name, cost]
		"unpicker":
			return "+%d Unravel when bleeding · %s (%d energy)" % [
				_int_value(passive.get("value")), card_name, cost]
		"sharpshot":
			return "First attack +%d · %s (%d energy)" % [
				_int_value(passive.get("bonus_damage")), card_name, cost]
		"clockwork":
			return "First cost-%d+ card -%d · %s (%d energy)" % [
				_int_value(passive.get("minimum_printed_cost")),
				_int_value(passive.get("discount")), card_name, cost]
	return ""


static func _target_text(kind_value: Variant, positions: Variant) -> String:
	if not kind_value is String:
		return ""
	var kind: String = kind_value
	if kind == "none":
		if positions is Array and (positions as Array).is_empty():
			return "no target"
		return ""
	if kind == "enemy_single":
		var list := _number_list_text(positions)
		return "target enemy " + list if not list.is_empty() else ""
	return ""


## "from positions 1-3", "from position 3"; only 1..3, no duplicates.
static func _positions_text(value: Variant, prefix: String) -> String:
	var list := _number_list_text(value)
	if list.is_empty():
		return ""
	var count := (value as Array).size()
	return "%s %s %s" % [prefix, "position" if count == 1 else "positions", list]


static func _number_list_text(value: Variant) -> String:
	if not value is Array:
		return ""
	var positions: Array = value
	if positions.is_empty():
		return ""
	var numbers: Array[int] = []
	for item in positions:
		if typeof(item) != TYPE_INT:
			return ""
		var number: int = item
		if number < 1 or number > 3 or numbers.has(number):
			return ""
		numbers.append(number)
	numbers.sort()
	if numbers.size() == 1:
		return str(numbers[0])
	if numbers[numbers.size() - 1] - numbers[0] == numbers.size() - 1:
		return "%d-%d" % [numbers[0], numbers[numbers.size() - 1]]
	var parts := PackedStringArray()
	for number in numbers:
		parts.append(str(number))
	return ", ".join(parts)


static func _int_equals(value: Variant, expected: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) == expected
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number and int(number) == expected
	return false


static func _int_value(value: Variant, fallback: int = -1) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
	return fallback
