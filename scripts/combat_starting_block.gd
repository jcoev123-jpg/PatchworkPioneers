class_name CombatStartingBlock
extends RefCounted
## One-shot grant of the Warden's start-of-combat Block. Bound to a party on construction.

const BLOCK_AMOUNT := 6
const WARDEN_ID := "warden"
const WARDEN_POSITION := 1

var _party: CombatParty = null
var _consumed: bool = false


func _init(party: CombatParty = null) -> void:
	_party = party


func apply() -> bool:
	if _consumed:
		return false
	if _party == null or not is_instance_valid(_party) or not _party.is_valid():
		return false
	var hero: Dictionary = _party.get_hero(WARDEN_POSITION)
	if hero.is_empty():
		return false
	if hero.get("id") != WARDEN_ID:
		return false
	if _party.is_downed(WARDEN_POSITION):
		return false
	if not _party.gain_block(WARDEN_POSITION, BLOCK_AMOUNT):
		return false
	_consumed = true
	return true
