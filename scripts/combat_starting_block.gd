class_name CombatStartingBlock
extends RefCounted
## One-shot grant of the Warden's start-of-combat Block. Bound to a party on construction.

const BLOCK_AMOUNT := 6
const BULWARK_BLOCK_AMOUNT := 10
const WARDEN_ID := "warden"
const WARDEN_MAX_HP := 40
const BULWARK_PATH_ID := "bulwark"
const VANGUARD_PATH_ID := "vanguard"
const MAX_SAFE_FLOAT_INT := 9007199254740992.0

var _party: CombatParty = null
var _consumed: bool = false
var _path_receipt: Variant = null


func _init(party: CombatParty = null, path_receipt: Variant = null) -> void:
	_party = party
	_path_receipt = path_receipt


func set_path_receipt(path_receipt: Variant) -> void:
	_path_receipt = path_receipt


func get_path_receipt() -> Variant:
	if _path_receipt is Dictionary:
		return (_path_receipt as Dictionary).duplicate(true)
	return _path_receipt


func is_consumed() -> bool:
	return _consumed


func apply(path_receipt: Variant = null) -> bool:
	if _consumed:
		return false
	if path_receipt != null:
		_path_receipt = path_receipt
	var block_amount := _resolve_block_amount()
	if block_amount <= 0:
		return false
	if _party == null or not is_instance_valid(_party) or not _party.is_valid():
		return false
	# CombatParty.is_valid() only checks roster size. Validate the whole
	# formation before granting a uniquely authored Warden at his current slot.
	if not CombatStatusTurnBatch.new().tick_side("heroes", _party.get_heroes())["ok"]:
		return false
	var warden_position := 0
	for position in range(1, CombatParty.PARTY_SIZE + 1):
		var hero: Dictionary = _party.get_hero(position)
		if hero["id"] == WARDEN_ID:
			if warden_position != 0 or hero["max_hp"] != WARDEN_MAX_HP:
				return false
			warden_position = position
	if warden_position == 0 or _party.is_downed(warden_position):
		return false
	if not _party.gain_block(warden_position, block_amount):
		return false
	_consumed = true
	return true


func _resolve_block_amount() -> int:
	if _path_receipt == null:
		return BLOCK_AMOUNT
	if not _path_receipt is Dictionary:
		return -1
	var receipt: Dictionary = _normalize(_path_receipt)
	if receipt.get("ok") != true:
		return -1
	if receipt.get("owner") != WARDEN_ID:
		return -1
	var path_id: Variant = receipt.get("path_id")
	if not path_id is String:
		return -1
	var target_id: String = path_id
	if target_id != BULWARK_PATH_ID and target_id != VANGUARD_PATH_ID:
		return -1
	var choice := RunWardenPathChoice.new()
	if not choice.is_valid():
		return -1
	var expected_receipt: Dictionary = _normalize(choice.choose(target_id))
	if expected_receipt.get("ok") != true:
		return -1
	if not _exactly_equal(receipt, expected_receipt):
		return -1
	if target_id == BULWARK_PATH_ID:
		var passive: Dictionary = expected_receipt.get("passive", {})
		var amount: int = int(passive.get("starting_block", BULWARK_BLOCK_AMOUNT))
		if amount != BULWARK_BLOCK_AMOUNT:
			return -1
		return amount
	elif target_id == VANGUARD_PATH_ID:
		return BLOCK_AMOUNT
	return -1


static func _normalize(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number and absf(number) <= MAX_SAFE_FLOAT_INT:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_normalize(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _normalize(value[key])
		return out_dict
	return value


static func _exactly_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		var left_list: Array = a
		var right_list: Array = b
		if left_list.size() != right_list.size():
			return false
		for index in left_list.size():
			if not _exactly_equal(left_list[index], right_list[index]):
				return false
		return true
	if a is Dictionary:
		var left_dict: Dictionary = a
		var right_dict: Dictionary = b
		if left_dict.size() != right_dict.size():
			return false
		for key in left_dict:
			if not right_dict.has(key):
				return false
			if not _exactly_equal(left_dict[key], right_dict[key]):
				return false
		return true
	return a == b
