class_name CombatQuiltBonus
extends RefCounted
## Scene-free receipt tracker. Only callers of successfully committed card plays
## may record an owner; stitched plays report each of their two owners afterward.

const HERO_IDS: Array[String] = ["warden", "seamstress", "tinker"]
const FELT_COLORS := {
	"warden": "#4a5d73",
	"seamstress": "#6e4f6b",
	"tinker": "#c49a3a",
}
const BLOCK_REWARD := 3

var _party: CombatParty
var _deck: CombatDeck
var _active := false
var _awarded := false
var _played: Dictionary = {}

# Opt-in Switchback Button transition tracking
var _switchback_active := false
var _switchback_wardrobe: Variant = null
var _switchback_torn: Variant = null
var _prev_owner: String = ""
var _switchback_consumed := false
var _receipt_ids: Dictionary = {}


func _init(party: CombatParty, deck: CombatDeck) -> void:
	_party = party
	_deck = deck
	_clear_progress()


## Call once immediately after a successful CombatDeck.start_turn().
func begin_player_turn() -> bool:
	if _active or not _bindings_valid() or not _deck.turn_active:
		return false
	_clear_progress()
	_awarded = false
	_active = true
	_reset_switchback()
	return true


## This never executes an attempted play: the caller supplies a committed owner.
## The currently living ID set is authoritative even after a swap or a downing.
func record_confirmed_play(owner_id: String) -> Dictionary:
	var rejected := {"ok": false, "triggered": false, "drawn": 0}
	if not _active or not _bindings_valid() or not _deck.turn_active:
		return rejected
	if not _played.has(owner_id):
		return rejected
	var living := _living_heroes()
	if living.is_empty():
		return rejected
	var owner_lives := false
	for hero in living:
		if hero["id"] == owner_id:
			owner_lives = true
			break
	if not owner_lives:
		return rejected
	if _awarded or _played[owner_id]:
		return {"ok": true, "triggered": false, "drawn": 0}

	# Preflight every recipient before changing any Block. A full Block
	# recipient must not cause a partially applied party-wide reward.
	var completes := true
	for hero in living:
		if hero["id"] != owner_id and not _played[hero["id"]]:
			completes = false
	if completes:
		for hero in living:
			var block = hero.get("block")
			if not block is int or block < 0 or block > CombatParty.MAX_INT - BLOCK_REWARD:
				return rejected

	_played[owner_id] = true
	if not completes:
		return {"ok": true, "triggered": false, "drawn": 0}
	for hero in living:
		_party.gain_block(hero["position"], BLOCK_REWARD)
	var drawn: int = _deck.draw_extra(1)
	_awarded = true
	return {"ok": true, "triggered": true, "drawn": drawn}


## Two-owner confirmation for a successfully committed stitched card. Both owners
## are credited as one boundary; never executes, charges or resolves the card.
func record_confirmed_stitched_play(first_owner_id: String, second_owner_id: String) -> Dictionary:
	var rejected := {"ok": false, "triggered": false, "drawn": 0}
	if not _active or not _bindings_valid() or not _deck.turn_active:
		return rejected
	if first_owner_id == second_owner_id:
		return rejected
	if not _played.has(first_owner_id) or not _played.has(second_owner_id):
		return rejected
	var living := _living_heroes()
	if living.is_empty():
		return rejected
	var first_lives := false
	var second_lives := false
	for hero in living:
		if hero["id"] == first_owner_id:
			first_lives = true
		if hero["id"] == second_owner_id:
			second_lives = true
	if not first_lives or not second_lives:
		return rejected
	if _awarded:
		return {"ok": true, "triggered": false, "drawn": 0}
	var mark_first: bool = not _played[first_owner_id]
	var mark_second: bool = not _played[second_owner_id]
	if not mark_first and not mark_second:
		return {"ok": true, "triggered": false, "drawn": 0}

	var completes := true
	for hero in living:
		var id: String = hero["id"]
		var will_be_played: bool = _played.get(id, false)
		if id == first_owner_id or id == second_owner_id:
			will_be_played = true
		if not will_be_played:
			completes = false
	if completes:
		for hero in living:
			var block = hero.get("block")
			if not block is int or block < 0 or block > CombatParty.MAX_INT - BLOCK_REWARD:
				return rejected

	if mark_first:
		_played[first_owner_id] = true
	if mark_second:
		_played[second_owner_id] = true
	if not completes:
		return {"ok": true, "triggered": false, "drawn": 0}
	for hero in living:
		_party.gain_block(hero["position"], BLOCK_REWARD)
	var drawn: int = _deck.draw_extra(1)
	_awarded = true
	return {"ok": true, "triggered": true, "drawn": drawn}


## Call after CombatDeck.end_turn(); do not close an active hand prematurely.
func end_player_turn() -> void:
	if _active and _deck != null and not _deck.turn_active:
		_active = false


## A fully detached read keyed by stable hero ID for the later felt-bar UI.
func get_patch_progress() -> Dictionary:
	var living_ids: Array[String] = []
	if _party != null and _party.is_valid():
		for hero in _party.get_heroes():
			if hero.get("hp", 0) > 0 and hero.get("id") in HERO_IDS:
				living_ids.append(hero["id"])
	var patches := {}
	for id in HERO_IDS:
		patches[id] = {
			"living": id in living_ids,
			"played": _played.get(id, false),
			"color": FELT_COLORS[id],
		}
	return {"active": _active, "awarded": _awarded, "patches": patches}


func _clear_progress() -> void:
	_played = {"warden": false, "seamstress": false, "tinker": false}


func _bindings_valid() -> bool:
	if _party == null or _deck == null or not is_instance_valid(_party) or not is_instance_valid(_deck):
		return false
	if not _party.is_valid() or _deck.combat_state == null or _deck._rng == null:
		return false
	var ids: Array[String] = []
	var heroes := _party.get_heroes()
	for index in range(CombatParty.PARTY_SIZE):
		var hero: Dictionary = heroes[index]
		var id = hero.get("id")
		if not id is String or not id in HERO_IDS or id in ids:
			return false
		if hero.get("position") != index + 1 or not hero.get("hp") is int:
			return false
		ids.append(id)
	return ids.size() == HERO_IDS.size()


func _living_heroes() -> Array[Dictionary]:
	var living: Array[Dictionary] = []
	for hero in _party.get_heroes():
		if hero["hp"] > 0:
			living.append(hero)
	return living


## The current living set is authoritative at the committed receipt boundary.
func _is_living_hero(hero_id: String) -> bool:
	if hero_id == "" or _party == null or not _party.is_valid():
		return false
	for hero in _living_heroes():
		if hero["id"] == hero_id:
			return true
	return false


## Opt-in Switchback Button transition tracking.
## Only activates when a valid wardrobe and torn state are supplied.
func enable_switchback(wardrobe: Variant, torn: Variant) -> bool:
	if wardrobe == null or torn == null or not is_instance_valid(wardrobe) or not is_instance_valid(torn):
		return false
	if typeof(wardrobe) != TYPE_OBJECT or not ("project_active" in wardrobe):
		return false
	if typeof(torn) != TYPE_OBJECT or not ("read_state" in torn) or not torn.is_valid():
		return false
	_switchback_active = true
	_switchback_wardrobe = wardrobe
	_switchback_torn = torn
	_prev_owner = ""
	_switchback_consumed = false
	_receipt_ids.clear()
	return true


func disable_switchback() -> void:
	_switchback_active = false
	_switchback_wardrobe = null
	_switchback_torn = null
	_prev_owner = ""
	_switchback_consumed = false
	_receipt_ids.clear()


func is_switchback_active() -> bool:
	return _switchback_active


func get_switchback_state() -> Dictionary:
	return {
		"active": _switchback_active,
		"consumed": _switchback_consumed,
		"prev_owner": _prev_owner,
		"receipts_observed": _receipt_ids.keys(),
	}


func observe_confirmed_play(receipt_id: String, owner_id: String) -> Dictionary:
	var rejected := {"ok": false, "triggered": false, "block_granted": 0}
	if not _switchback_active:
		return rejected
	if not _bindings_valid() or not _deck.turn_active:
		return rejected
	if receipt_id == null or receipt_id == "" or receipt_id != receipt_id.strip_edges():
		return rejected
	if owner_id == null or owner_id == "" or owner_id != owner_id.strip_edges():
		return rejected
	if not owner_id in HERO_IDS:
		return rejected
	# Deduplication: replayed receipt does not advance previous-owner or spend trigger.
	if _receipt_ids.has(receipt_id):
		return rejected
	# Check if the owner lives and the patch is worn and untorn.
	var eligible := _switchback_wearer_for(owner_id)
	if eligible:
		# The wearer's just-committed play must immediately follow a committed
		# play by a DIFFERENT hero who is still living now. A predecessor downed
		# by his own committed play (a 3 HP Overclock) or downed between the two
		# commits can never set the bonus up, so liveness is checked here at the
		# committed receipt boundary rather than when the predecessor played.
		if _prev_owner != "" and _prev_owner != owner_id and not _switchback_consumed \
				and _is_living_hero(_prev_owner):
			if not _party.gain_block(_hero_position_for(owner_id), 2):
				return rejected
			_switchback_consumed = true
			_receipt_ids[receipt_id] = true
			_prev_owner = owner_id
			return {"ok": true, "triggered": true, "block_granted": 2}
	# Even when not triggered, a valid receipt advances the previous-owner pointer.
	_receipt_ids[receipt_id] = true
	_prev_owner = owner_id
	return {"ok": true, "triggered": false, "block_granted": 0}


func observe_confirmed_stitched_play(first_receipt_id: String, first_owner_id: String,
		second_receipt_id: String, second_owner_id: String) -> Array[Dictionary]:
	# Ordered stitched halves: observe each in sequence independently.
	var first_result := observe_confirmed_play(first_receipt_id, first_owner_id)
	var second_result := observe_confirmed_play(second_receipt_id, second_owner_id)
	return [first_result, second_result]


func _switchback_wearer_for(owner_id: String) -> bool:
	if not _switchback_active or _switchback_wardrobe == null or _switchback_torn == null:
		return false
	var position := _hero_position_for(owner_id)
	if position == 0 or _party.is_downed(position):
		return false
	if not _switchback_torn.is_valid():
		return false
	var torn_state: Dictionary = _switchback_torn.read_state()
	if torn_state == null or typeof(torn_state) != TYPE_DICTIONARY:
		return false
	var projection: Dictionary = _switchback_wardrobe.project_active(torn_state)
	if projection == null or typeof(projection) != TYPE_DICTIONARY:
		return false
	if not projection.get("ok", false):
		return false
	var active: Dictionary = projection.get("active", {})
	if not active.has(owner_id):
		return false
	# The hero must have switchback_button in HEAD and be untorn (tear count == 0).
	var equipped: Array = active.get(owner_id, [])
	if not "switchback_button" in equipped:
		return false
	var tear_counts: Dictionary = torn_state.get("tear_counts", {})
	if tear_counts.get(owner_id, 0) != 0:
		return false
	# Additionally confirm the hero is living (project_active filters by hp > 0,
	# but we also check explicitly for safety).
	var heroes: Array = torn_state.get("heroes", [])
	for hero in heroes:
		if hero.get("id") == owner_id:
			return hero.get("hp", 0) > 0
	return false


func _hero_position_for(hero_id: String) -> int:
	if _party == null or not _party.is_valid():
		return 0
	var heroes := _party.get_heroes()
	for index in range(heroes.size()):
		if heroes[index].get("id") == hero_id:
			return index + 1
	return 0


func _reset_switchback() -> void:
	_prev_owner = ""
	_switchback_consumed = false
	_receipt_ids.clear()
