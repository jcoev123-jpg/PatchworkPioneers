class_name CombatStartingBlock
extends RefCounted
## One-shot grant of the Warden's start-of-combat Block. Bound to a party on construction.

const BLOCK_AMOUNT := 6
const WARDEN_ID := "warden"
const WARDEN_MAX_HP := 40

var _party: CombatParty = null
var _consumed: bool = false


func _init(party: CombatParty = null) -> void:
	_party = party


func apply() -> bool:
	if _consumed:
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
	if not _party.gain_block(warden_position, BLOCK_AMOUNT):
		return false
	_consumed = true
	return true
