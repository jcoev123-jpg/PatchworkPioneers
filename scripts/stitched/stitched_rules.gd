class_name StitchedRules
extends RefCounted
## Headless Design v4 "Stitched" combat rules core, build stage S1a (STITCHED_DESIGN.md).
##
## Owns the four-hero party, four enemy ranks, part abilities, statuses, scrap heaps,
## Hanging and retreat. Creation is independent of project settings.
##
## Determinism: every random draw comes from one RandomNumberGenerator seeded by the caller,
## so a fixed seed replays exactly. Illegal actions are validated before any state or RNG
## change and return {"ok": false, ...}; a successful action always spends the acting unit's
## turn. Draw order is documented at each roll site.
##
## Turn order (section 1): each living unit rolls SPEED + 1d8 at the start of the round;
## highest first, ties go to heroes before foes and then to the lower rank. A boss may have
## two turns in the round. Heaps and lost heroes never take turns.
##
## Statuses (section 3) tick at the start of the affected unit's turn: Bleed deals its
## count in direct HP damage (ignoring PROT), then every N-turn counter drops by one. Stun
## is special: the stunned unit's turn is skipped, the stun is consumed and it gains one
## turn of stun resist that refuses the next stun. Guard is a status on the guarding hero
## that redirects enemy hits aimed at the guarded ally. Mark only adds damage to abilities
## authored with mark_damage.
##
## S1b extends the same S1a session, validation, and seeded RNG with fray, resolve,
## torn seams, thread cuts and candle projections. No live run/UI wiring is needed.

const HERO_COUNT := 4
const MIN_FOES := 2
const MAX_FOES := 3
const MIN_RANK := 1
const MAX_RANK := 4
const D8 := 8
const HIT_MIN := 5
const HIT_MAX := 95
const MISS_STREAK_ACC := 5
const CRIT_BASE := 5
const CRIT_NUMERATOR := 3
const CRIT_DENOMINATOR := 2
const PROT_CAP := 80
const SEAM_HOLD_PERCENT := 67
const RETREAT_SUCCESS_PERCENT := 75
const RETREAT_FRAY_GAIN := 15
const CRIT_FRAY_RELIEF := 3
const SATCHEL_CAP := 6
const FRAY_MAX := 200
const FRAY_RESOLVE := 100
const FRAY_RECOVER := 50
const WALK_MIMIC_ID := "extra_thread_shadow"
const COUNTDOWN_KEYS := [
	"weak", "exposed", "tangled", "mark", "thorns", "riposte", "stun_resist", "guard",
]
## S12 Brush Off wipes these from one doll.
const GIFT_CLEARS := ["bleed", "tangled", "weak", "exposed"]

var _parts: Dictionary = {}
var _units: Dictionary = {}
var _heaps: Array = []
var _rng := RandomNumberGenerator.new()
var _round := 0
var _turn_index := 0
var _order: Array = []
var _outcome := "ongoing"
var _valid := false
## Set once at setup from the authored foes. A boss encounter keeps refusing retreat even
## after the boss itself is dead and only its minions still stand.
var _boss_encounter := false
var _candle := 100
var _opening: Dictionary = {}
var _thread_cuts: Dictionary = {}  # snipped hero id -> fixed rank boundary behind it
var _satchel: Array = []
var _turn_events: Array = []
## S9a Wren's hand: the round its one free action was spent, the round the candle is
## shielded, held doll id -> round, and every attempt's receipt (failures included).
var _hand_round := 0
var _shield_round := 0
var _held: Dictionary = {}
var _hand_receipts: Array = []
## S12 Wren's gifts: the (at most four) gifts in his slots this fight, once-per-fight gifts
## already spent, doll id -> round its eyes are covered, and whether the nightlight is on.
var _gifts: Array = StitchedKidHandActions.IDS.duplicate()
var _gifts_spent: Array = []
var _covered: Dictionary = {}
var _nightlight := false
## S14 signature actions are opt-in at battle creation (legacy S1 fixtures remain independent).
var _s14 := false
var _s14_sockets: Dictionary = {}


## Builds a stitched battle from authored data:
##   {"heroes": [4 hero definitions], "foes": [2-3 foe definitions],
##    "parts": [part entries], "seed": int, "mode": optional explicit "stitched"}
## Returns {"ok": true, "error": "", "battle": StitchedRules} or
## {"ok": false, "error": message, "battle": null}. Nothing is rolled or mutated on failure.
static func create(config: Dictionary) -> Dictionary:
	if config.has("mode"):
		var requested: Variant = config["mode"]
		if not requested is String or requested != "stitched":
			return {"ok": false, "error": "unknown combat mode: " + str(requested), "battle": null}
	var battle := StitchedRules.new()
	var error := battle._setup(config)
	if not error.is_empty():
		return {"ok": false, "error": error, "battle": null}
	return {"ok": true, "error": "", "battle": battle}


func is_valid() -> bool:
	return _valid


func round_number() -> int:
	return _round


func outcome() -> String:
	return _outcome


func is_over() -> bool:
	return _outcome != "ongoing"


## True when the fight was authored with a boss, whether or not it still lives.
func is_boss_encounter() -> bool:
	return _boss_encounter


func current_actor_id() -> String:
	if _outcome != "ongoing" or _turn_index < 0 or _turn_index >= _order.size():
		return ""
	return str(_order[_turn_index])


func current_side() -> String:
	var id := current_actor_id()
	if id.is_empty() or not _units.has(id):
		return ""
	return str(_units[id]["side"])


## The rolled order for the current round, unit ids in acting order (a boss appears twice).
func turn_order() -> Array:
	return _order.duplicate()


func rng_state() -> int:
	return int(_rng.state)


func get_unit(unit_id: String) -> Dictionary:
	if not _units.has(unit_id):
		return {}
	return _units[unit_id].duplicate(true)


func get_heroes() -> Array:
	return _units_of_side("hero")


func get_foes() -> Array:
	return _units_of_side("foe")


func get_heaps() -> Array:
	return _heaps.duplicate(true)


func candle() -> int:
	return _candle


func candle_band() -> Dictionary:
	return StitchedS1BEffects.candle_band(_candle)


func opening_strike() -> Dictionary:
	return _opening.duplicate(true)


func thread_cuts() -> Dictionary:
	return _thread_cuts.duplicate(true)


func satchel() -> Array:
	return _satchel.duplicate(true)


func turn_events() -> Array:
	return _turn_events.duplicate(true)


## No S6 map/shop hooks yet: explicit scene-free candle transitions.
func adjust_candle(source: String, amount: int = 0) -> Dictionary:
	if not _valid:
		return _reject("candle", "", "battle is not initialized")
	var step := amount
	match source:
		"node":
			if amount != 0 and amount != -8:
				return _reject("candle", "", "node entry burns exactly eight")
			step = -8
		"campfire":
			if amount != 0 and amount != 50:
				return _reject("candle", "", "wick trimming restores exactly fifty")
			step = 50
		"peddler":
			if amount != 0 and amount != 25:
				return _reject("candle", "", "a candle stub restores exactly twenty-five")
			step = 25
		"event":
			if amount == 0 or absi(amount) > 100:
				return _reject("candle", "", "event candle delta must be nonzero and within 100")
		_:
			return _reject("candle", "", "unknown candle source")
	var before := _candle
	_candle = clampi(_candle + step, 0, 100)
	return {"ok": true, "source": source, "before": before, "after": _candle, "band": candle_band()}


## Events, Campfire stories and Unpicker calm may change fray without spending a combat turn.
func apply_fray_event(hero_id: String, amount: int, source: String = "event") -> Dictionary:
	if not _valid or not _units.has(hero_id):
		return _reject("fray", hero_id, "unknown hero or uninitialized battle")
	var hero: Dictionary = _units[hero_id]
	if str(hero["side"]) != "hero" or bool(hero["lost"]):
		return _reject("fray", hero_id, "only a present hero can receive fray")
	if amount == 0 or absi(amount) > FRAY_MAX or not source in ["event", "campfire", "unpicker"]:
		return _reject("fray", hero_id, "invalid fray event")
	if source != "event" and amount > 0:
		return _reject("fray", hero_id, "recovery sources cannot add fray")
	return _change_fray(hero, amount)


## Direct elite tear is also available to authored Rip/Unpick actions.
func tear_part(hero_id: String) -> Dictionary:
	var gate := _require_side_turn("tear", "foe")
	if not gate.is_empty():
		return gate
	if not _units.has(hero_id) or str(_units[hero_id]["side"]) != "hero":
		return _reject("tear", hero_id, "unknown hero")
	return _tear_random(_units[hero_id])


## Sewing Circle eligibility is scene-free. Caller supplies its later-stage scrap price.
func mend_part(hero_id: String, slot: String, scraps: int, cost: int) -> Dictionary:
	if not _valid or _outcome == "ongoing":
		return _reject("mend", hero_id, "mending requires the end of a fight")
	if not _units.has(hero_id) or str(_units[hero_id]["side"]) != "hero":
		return _reject("mend", hero_id, "unknown hero")
	var hero: Dictionary = _units[hero_id]
	if bool(hero["lost"]) or not slot in StitchedParts.SLOTS or not hero["parts"].has(slot):
		return _reject("mend", hero_id, "no eligible equipped part")
	if not bool(hero["parts"][slot]["torn"]):
		return _reject("mend", hero_id, "part is not torn")
	if cost <= 0 or scraps < 0 or scraps < cost:
		return _reject("mend", hero_id, "insufficient scraps or invalid price")
	hero["parts"][slot]["torn"] = false
	_recompute_stats(hero)
	return {"ok": true, "action": "mend", "hero": hero_id, "slot": slot, "scraps_left": scraps - cost}


func end_floor() -> Dictionary:
	if not _valid or _outcome == "ongoing":
		return _reject("floor", "", "floor cannot end during battle")
	for hero in _units_of_side("hero"):
		if str(hero.get("resolve", "")) == "steadfast" and not bool(hero.get("lost", false)):
			hero["resolve"] = ""
			# Steadfast calms the party "until the floor ends", but a doll still
			# above the resolve threshold cannot leave it without a trait: settle
			# that crossing exactly as the normal 100-fray resolve check does.
			if int(hero.get("fray", 0)) >= FRAY_RESOLVE:
				if StitchedS1BEffects.percent_roll_succeeds(_rng.randi_range(1, 100), 25):
					hero["resolve"] = "steadfast"
					hero["fray"] = 45
				else:
					hero["resolve"] = StitchedS1BEffects.trait_for_roll(_rng.randi_range(0, 4))
	return {"ok": true, "action": "floor"}


## A cut is behind a rank 1-3 hero; only foes may snip as a standalone action.
func snip_thread(hero_id: String) -> Dictionary:
	var gate := _require_side_turn("snip", "foe")
	if not gate.is_empty():
		return gate
	if not _units.has(hero_id) or str(_units[hero_id]["side"]) != "hero":
		return _reject("snip", hero_id, "unknown hero")
	var receipt := _cut_behind(_units[hero_id])
	if bool(receipt["ok"]):
		_advance_turn()
	return receipt


func re_tie() -> Dictionary:
	var gate := _require_side_turn("re_tie", "hero")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	var id := str(actor["id"])
	if not _thread_cuts.has(id):
		return _reject("re_tie", id, "this hero's thread is not snipped")
	_thread_cuts.erase(id)
	_advance_turn()
	return {"ok": true, "action": "re_tie", "actor": id}


## Everything a replay needs: round, turn pointer, rolled order, every unit, the heaps and
## the RNG position. Two runs with the same seed and the same actions produce equal snapshots.
func state_snapshot() -> Dictionary:
	var units: Array = []
	for unit_id in _sorted_ids():
		units.append(_units[unit_id].duplicate(true))
	return {
		"round": _round,
		"turn_index": _turn_index,
		"order": _order.duplicate(),
		"outcome": _outcome,
		"rng_state": int(_rng.state),
		"units": units,
		"heaps": _heaps.duplicate(true),
		"candle": _candle,
		"opening": _opening.duplicate(true),
		"thread_cuts": _thread_cuts.duplicate(true),
		"satchel": _satchel.duplicate(true),
		"turn_events": _turn_events.duplicate(true),
		"s14": {"enabled": _s14, "sockets": _s14_sockets.duplicate(true)},
		"hand": {
			"round_used": _hand_round,
			"shield_round": _shield_round,
			"held": _held.duplicate(true),
			"receipts": _hand_receipts.duplicate(true),
			"gifts": _gifts.duplicate(),
			"spent": _gifts_spent.duplicate(),
			"covered": _covered.duplicate(true),
			"nightlight": _nightlight,
		},
	}


## S9a: true while Wren's one free hand action for this round is unspent and a doll has
## the turn (the action happens before that doll acts and never spends its turn).
func hand_action_open() -> bool:
	return _require_side_turn("hand", "hero").is_empty() and _hand_round != _round


func hand_receipts() -> Array:
	return _hand_receipts.duplicate(true)


func is_held(hero_id: String) -> bool:
	return int(_held.get(hero_id, 0)) == _round


func candle_shielded() -> bool:
	return _shield_round == _round or _nightlight


func gift_slots() -> Array:
	return _gifts.duplicate()


func gift_spent(gift_id: String) -> bool:
	return gift_id in _gifts_spent


func eyes_covered(hero_id: String) -> bool:
	return _covered.has(hero_id) and int(_covered[hero_id]) == _round


## Why a hand action would be refused right now ("" when legal); changes nothing. A doll
## gift takes a hero id, a foe gift a living foe id, and the rest no target; only Lift takes
## a direction.
func hand_action_check(action_id: String, target_id: String, direction: int) -> String:
	var gate := _require_side_turn("hand", "hero")
	if not gate.is_empty():
		return str(gate["error"])
	if _hand_round == _round:
		return "Wren's hand action is spent this round"
	var entry := StitchedWrenGifts.gift(action_id)
	if entry.is_empty() or not action_id in _gifts:
		return "unknown hand action " + action_id
	if action_id in _gifts_spent:
		return str(entry["name"]) + " is spent for this fight"
	if direction != 0 and action_id != "lift":
		return "only Lift takes a direction"
	match str(entry["target"]):
		"none":
			if not target_id.is_empty():
				return str(entry["name"]) + " takes no doll"
			if action_id == "blow_candle" and _candle >= 100:
				return "the candle already burns full"
			if action_id == "nightlight" and _nightlight:
				return "the nightlight is already on"
			return ""
		"foe":
			var foe: Dictionary = _units.get(target_id, {})
			if foe.is_empty() or str(foe["side"]) != "foe" or not _can_act(foe):
				return "pick one of the foes"
			return _foe_gift_check(action_id, foe)
	var hero: Dictionary = _units.get(target_id, {})
	if hero.is_empty() or str(hero["side"]) != "hero" or bool(hero["lost"]):
		return "pick one of Wren's dolls"
	match action_id:
		"lift":
			var plan := _shift_valid(hero, direction)
			if not bool(plan["ok"]):
				return "Lift is blocked: " + str(plan["reason"])
		"hug":
			if bool(hero["hanging"]) or int(hero["hp"]) <= 0 or int(hero["hp"]) >= int(hero["max_hp"]):
				return "that doll needs no hug"
		"knot":
			if not _thread_cuts.has(target_id):
				return "that doll's string is whole"
		"brush_off":
			var clings := false
			for key in GIFT_CLEARS:
				clings = clings or int(hero["statuses"].get(key, 0)) > 0
			if not clings:
				return "nothing clings to that doll"
		"quick_stitch":
			if _torn_slot(hero).is_empty():
				return "that doll has no torn part"
		"cover_eyes":
			if eyes_covered(target_id):
				return "that doll's eyes are already covered"
		"whisper":
			if bool(hero["hanging"]):
				return "that doll cannot take another turn"
	return ""


func _foe_gift_check(action_id: String, foe: Dictionary) -> String:
	match action_id:
		"snip_string":
			if int(foe["statuses"].get("stun", 0)) > 0 or int(foe["statuses"].get("stun_resist", 0)) > 0:
				return "that foe's strings are already slack"
		"tug", "shove":
			var plan := _gift_shift_valid(foe, -1 if action_id == "tug" else 1)
			if not bool(plan["ok"]):
				return "that foe cannot be moved: " + str(plan["reason"])
	return ""


func _torn_slot(hero: Dictionary) -> String:
	for slot in StitchedParts.SLOTS:
		if hero["parts"].has(slot) and bool(hero["parts"][slot].get("torn", false)):
			return slot
	return ""

func use_hand_action(action_id: String, target_id: String = "", direction: int = 0, fear: int = 0) -> Dictionary:
	var refusal := hand_action_check(action_id, target_id, direction)
	if not refusal.is_empty():
		return _reject("hand", target_id, refusal)
	var book := StitchedWrenGifts.catalog()
	if not bool(book.get("ok", false)):
		return _reject("hand", target_id, str(book.get("error", "gifts missing")))
	var receipt := {
		"ok": true,
		"action": "hand",
		"hand_action": action_id,
		"actor": target_id,
		"direction": direction,
		"round": _round,
		"fear": fear,
		"roll": 0,
		"failed": false,
	}
	_hand_round = _round
	if bool(book.by_id[action_id].get("once_per_fight", false)):
		_gifts_spent.append(action_id)
	if fear >= StitchedKidFear.SHAKE_THRESHOLD:
		receipt["roll"] = _rng.randi_range(1, 100)
		receipt["failed"] = int(receipt["roll"]) <= StitchedKidFear.HAND_FAILURE_CHANCE_PERCENT
	if not bool(receipt["failed"]):
		match action_id:
			"steady":
				receipt["effect"] = _change_fray(_units[target_id], int(book.by_id["steady"]["fray"]), false)
			"shield_candle":
				_shield_round = _round
			"hold_back":
				_held[target_id] = _round
			"lift":
				receipt["effect"] = _shift(_units[target_id], direction)
			_:
				receipt["effect"] = _resolve_gift(action_id, book.by_id[action_id], target_id)
	_hand_receipts.append(receipt.duplicate(true))
	_battle_finished()
	return receipt


## S12: one gift's effect, already checked legal. Never spends the doll's turn; may end the fight.
func _resolve_gift(action_id: String, entry: Dictionary, target_id: String) -> Dictionary:
	var unit: Dictionary = _units.get(target_id, {})
	var turns := int(entry.get("turns", 3))
	match action_id:
		"snip_string":
			unit["statuses"]["stun"] = 1
			return {"status": "stun"}
		"tip_over":
			unit["statuses"]["stun"] = maxi(1, int(unit["statuses"].get("stun", 0)))
			var fell: Dictionary = _shift(unit, 1) if bool(_shift_valid(unit, 1)["ok"]) else {}
			return {"status": "stun", "move": fell}
		"tug":
			return _gift_shift(unit, -1)
		"shove":
			return _gift_shift(unit, 1)
		"flick_button":
			var hit := {"damage": int(entry.get("damage", 4))}
			_damage_target(unit, int(hit["damage"]), hit)
			return hit
		"pinch", "point", "tangle_thread":
			var key: String = {"pinch": "weak", "point": "exposed", "tangle_thread": "tangled"}[action_id]
			unit["statuses"][key] = maxi(int(unit["statuses"].get(key, 0)), turns)
			return {"status": key, "duration": turns}
		"blow_candle":
			var lit := _candle
			_candle = clampi(_candle + int(entry.get("candle", 10)), 0, 100)
			return {"before": lit, "after": _candle}
		"nightlight":
			_nightlight = true
			return {"nightlight": true}
		"hug":
			var hp := int(unit["hp"])
			unit["hp"] = mini(int(unit["max_hp"]), hp + int(entry.get("heal", 6)))
			return {"before": hp, "after": int(unit["hp"])}
		"cover_eyes":
			_covered[target_id] = _round
			return {"covered": true}
		"knot":
			_thread_cuts.erase(target_id)
			return {"knotted": true}
		"brush_off":
			for key in GIFT_CLEARS:
				unit["statuses"].erase(key)
			return {"cleared": GIFT_CLEARS.duplicate()}
		"quick_stitch":
			var slot := _torn_slot(unit)
			unit["parts"][slot]["torn"] = false
			_recompute_stats(unit)
			return {"mended": slot}
		"lullaby":
			for hero in _units_of_side("hero"):
				if not bool(hero["lost"]):
					_change_fray(hero, int(entry.get("fray", -6)), false)
			return {"calmed": true}
		"whisper":
			_order.insert(_turn_index + 1, target_id)
			return {"again": true}
	return {}


## S9a fear 100, LOSING THE STRINGS: the doll whose turn it is loses it without acting.
## The session calls this once and then drops Wren's fear to 60.
func skip_lost_strings_turn() -> Dictionary:
	var gate := _require_side_turn("lost_strings", "hero")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	_turn_events.append({"actor": str(actor["id"]), "action": "lost_strings", "round": _round})
	_advance_turn()
	return {"ok": true, "action": "lost_strings", "actor": str(actor["id"])}


## A hero's turn: use one equipped, untorn part ability from a legal launch rank against a
## legal target rank. Validates everything (including rank masks and target presence) before
## the first RNG draw, then spends the turn.

## Four hero-specific signature abilities; sewn equipment changes stats, not action IDs.
func use_ability(ability_id: String, target_rank: int) -> Dictionary:
	var gate := _require_side_turn("ability", "hero")
	if not gate.is_empty():
		return gate
	if not _s14:
		return _reject("ability", current_actor_id(), "signature kit is not enabled")
	var actor := _current_unit()
	var ability: Dictionary = {}
	for candidate in actor.abilities:
		if candidate.id == ability_id:
			ability = candidate
			break
	if ability.is_empty():
		return _reject("ability", str(actor.id), "unknown signature ability")
	if actor.parts.has(ability.slot) and actor.parts[ability.slot].torn:
		return _reject("ability", str(actor.id), "the attached limb is torn")
	if not StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)):
		return _reject("ability", str(actor.id), "invalid launch rank")
	var targets := _legal_targets(actor, ability, target_rank)
	if targets.is_empty():
		return _reject("ability", str(actor.id), "illegal target rank or side")
	var blocked := _self_move_gate(actor, ability)
	if not blocked.is_empty():
		return blocked
	if str(actor.resolve) == "cowering" and ability.kind == "melee" \
			and StitchedS1BEffects.percent_roll_succeeds(_rng.randi_range(1, 100), 30):
		_advance_turn()
		return {"ok": true, "action": "refused", "actor": str(actor.id)}
	var result := _resolve_ability(actor, ability, targets, "")
	_advance_turn()
	return result


func use_part(part_id: String, target_rank: int) -> Dictionary:
	if _s14:
		return _reject("ability", current_actor_id(), "body-part abilities are retired")
	var gate := _require_side_turn("ability", "hero")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	var equipped := _equipment(actor, part_id)
	if equipped.is_empty():
		return _reject("ability", str(actor["id"]), "part is not equipped")
	if bool(equipped["torn"]):
		return _reject("ability", str(actor["id"]), "part is torn")
	var ability := StitchedParts.ability_at_tier(_parts[equipped["id"]], int(equipped["tier"]))
	if ability.is_empty():
		return _reject("ability", str(actor["id"]), "part has no ability")
	if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])):
		return _reject(
			"ability",
			str(actor["id"]),
			"part cannot launch from rank %d" % int(actor["rank"]),
		)
	var targets := _legal_targets(actor, ability, target_rank)
	if targets.is_empty():
		return _reject("ability", str(actor["id"]), "no legal target in rank %d" % target_rank)
	# A mandatory self_move step is part of the action: refuse before any roll or state change
	# rather than resolving the hit and then failing to move.
	var blocked := _self_move_gate(actor, ability)
	if not blocked.is_empty():
		return blocked
	# A Cowering refusal consumes its turn; validate targets and movement before rolling.
	if str(actor.get("resolve", "")) == "cowering" and str(ability["kind"]) == "melee":
		var refuse_roll := _rng.randi_range(1, 100)
		if StitchedS1BEffects.percent_roll_succeeds(refuse_roll, 30):
			_advance_turn()
			return {"ok": true, "action": "refused", "actor": str(actor["id"]), "roll": refuse_roll}
	var receipt := _resolve_ability(actor, ability, targets, part_id)
	_advance_turn()
	return receipt


## A foe's turn: use one of its authored actions. Same validation and turn spending as a hero.
func use_foe_ability(ability_id: String, target_rank: int) -> Dictionary:
	var gate := _require_side_turn("ability", "foe")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	var ability := _foe_ability(actor, ability_id)
	if bool(actor.get("walk_intruder", false)):
		var heroes := _units_of_side("hero").filter(func(hero: Dictionary) -> bool: return not hero.lost)
		if heroes.is_empty() or target_rank != int(heroes.back().rank):
			return _reject("ability", WALK_MIMIC_ID, "the ambush must target the back-rank doll")
	if ability.is_empty():
		return _reject("ability", str(actor["id"]), "the foe has no ability " + ability_id)
	if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])):
		return _reject(
			"ability",
			str(actor["id"]),
			"ability cannot launch from rank %d" % int(actor["rank"]),
		)
	var targets := _legal_targets(actor, ability, target_rank)
	if targets.is_empty():
		return _reject("ability", str(actor["id"]), "no legal target in rank %d" % target_rank)
	var blocked := _self_move_gate(actor, ability)
	if not blocked.is_empty():
		return blocked
	var receipt := _resolve_ability(actor, ability, targets, "")
	if bool(actor.get("walk_intruder", false)):
		# Flee even after a miss or lethal reaction. Never enter reward/heap accounting.
		receipt["fled"] = true
		_spend_dodge_turn(actor)
		_units.erase(WALK_MIMIC_ID)
		_order.remove_at(_turn_index)
		_enter_turn()
		return receipt
	_advance_turn()
	return receipt


## A hero's turn: swap with the adjacent ally in front (-1) or behind (1), or step into an
## empty rank left by a lost ally. Tangled heroes can neither move nor be swapped.
func move(direction: int) -> Dictionary:
	var gate := _require_side_turn("move", "hero")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	if _s14 and actor.parts.has("legs") and actor.parts.legs.torn:
		return _reject("move", str(actor.id), "torn legs cannot change rank")
	if int(actor["statuses"].get("tangled", 0)) > 0:
		return _reject("move", str(actor["id"]), "a tangled hero cannot move")
	if _thread_cuts.has(str(actor["id"])):
		return _reject("move", str(actor["id"]), "the snipped hero cannot move")
	if is_held(str(actor["id"])):
		return _reject("move", str(actor["id"]), "Wren is holding this doll back")
	if direction != -1 and direction != 1:
		return _reject("move", str(actor["id"]), "move is one rank forward (-1) or back (1)")
	var destination := int(actor["rank"]) + direction
	if destination < MIN_RANK or destination > MAX_RANK:
		return _reject("move", str(actor["id"]), "there is no rank %d" % destination)
	var other := _hero_at(destination)
	if not other.is_empty() and int(other["statuses"].get("tangled", 0)) > 0:
		return _reject("move", str(actor["id"]), "a tangled ally cannot be swapped")
	if _crosses_cut(int(actor["rank"]), destination) or (not other.is_empty() and _thread_cuts.has(str(other["id"]))):
		return _reject("move", str(actor["id"]), "thread cut blocks the swap")
	if not other.is_empty() and is_held(str(other["id"])):
		return _reject("move", str(actor["id"]), "Wren is holding that doll back")
	var from := int(actor["rank"])
	var swapped := ""
	if not other.is_empty():
		other["rank"] = from
		swapped = str(other["id"])
	actor["rank"] = destination
	_advance_turn()
	return {
		"ok": true,
		"action": "move",
		"actor": str(actor["id"]),
		"from": from,
		"to": destination,
		"swapped": swapped,
	}


## Any unit's turn: spend it without acting.
func pass_turn() -> Dictionary:
	var gate := _require_turn("pass")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	_advance_turn()
	return {
		"ok": true,
		"action": "pass",
		"actor": str(actor["id"]),
		"actor_side": str(actor["side"]),
	}


## The battle's Retreat button (section 2): only in a non-boss fight. 75% success ends the
## fight with no reward and +15 fray on every living hero; a failed try spends the current
## hero's turn. A boss encounter refuses for the whole fight, even once the boss is dead and
## only its minions remain (the boss identity is stored at setup, never re-derived from the
## living foes). It refuses before any RNG draw or state change.
func retreat() -> Dictionary:
	var gate := _require_side_turn("retreat", "hero")
	if not gate.is_empty():
		return gate
	var actor := _current_unit()
	if _boss_encounter:
		return _reject("retreat", str(actor["id"]), "a boss fight cannot be retreated")
	var roll := _rng.randi_range(1, 100)
	if retreat_succeeds(roll):
		_outcome = "retreated"
		for unit_id in _units:
			var unit: Dictionary = _units[unit_id]
			if str(unit["side"]) == "hero" and not bool(unit["lost"]):
				_change_fray(unit, RETREAT_FRAY_GAIN)
		_finish_cleanup()
		return {
			"ok": true,
			"action": "retreat",
			"actor": str(actor["id"]),
			"success": true,
			"roll": roll,
			"fray_gain": RETREAT_FRAY_GAIN,
			"reward": {},
		}
	_advance_turn()
	return {
		"ok": true,
		"action": "retreat",
		"actor": str(actor["id"]),
		"success": false,
		"roll": roll,
		"fray_gain": 0,
		"reward": {},
	}


## Hit chance for one attempt: ability ACC + attacker ACC - target DODGE, plus 5 per
## consecutive miss, clamped to 5..95.
static func hit_chance(accuracy: int, dodge: int, miss_streak: int) -> int:
	var chance := accuracy - dodge + MISS_STREAK_ACC * maxi(0, miss_streak)
	return clampi(chance, HIT_MIN, HIT_MAX)


## A crit deals 1.5x the ability's maximum range value (floored).
static func crit_damage(range_max: int) -> int:
	if range_max <= 0:
		return 0
	return int(range_max * CRIT_NUMERATOR / CRIT_DENOMINATOR)


## PROT is a percentage cut capped at 80%, applied to direct damage only.
static func apply_protection(damage: int, prot: int) -> int:
	if damage <= 0:
		return 0
	var capped := clampi(prot, 0, PROT_CAP)
	return damage - int(damage * capped / 100)


## Damage after mark, Weak/Exposed, Tangled and PROT, in the order GAME_DESIGN.md defines:
## the mark bonus is added first (like Pinned's +5), Weak and Exposed use the combined
## 3/4 and 3/2 fractions with one floor, Tangled adds its flat +2, then PROT cuts the rest.
static func damage_after_modifiers(
	base: int,
	attacker_statuses: Dictionary,
	defender_statuses: Dictionary,
	marked: bool,
	mark_damage: int,
	prot: int
) -> int:
	if base < 0:
		return 0
	var damage := base
	if marked and mark_damage > 0:
		damage += mark_damage
	var weak := int(attacker_statuses.get("weak", 0)) > 0
	var exposed := int(defender_statuses.get("exposed", 0)) > 0
	var numerator := 1
	var denominator := 1
	if weak and exposed:
		numerator = 9
		denominator = 8
	elif weak:
		numerator = 3
		denominator = 4
	elif exposed:
		numerator = 3
		denominator = 2
	if numerator != denominator:
		@warning_ignore("integer_division")
		var whole: int = damage / denominator
		@warning_ignore("integer_division")
		var partial: int = (damage % denominator) * numerator / denominator
		damage = whole * numerator + partial
	if damage > 0 and int(defender_statuses.get("tangled", 0)) > 0:
		damage += 2
	return apply_protection(damage, prot)


## A seam check holds on 1..67 and the hero is LOST on 68..100.
static func seam_holds(roll: int) -> bool:
	return roll >= 1 and roll <= SEAM_HOLD_PERCENT


## A retreat try succeeds on 1..75.
static func retreat_succeeds(roll: int) -> bool:
	return roll >= 1 and roll <= RETREAT_SUCCESS_PERCENT


## A defeated foe's scrap heap keeps one third of its max HP (floored, at least 1).
static func heap_hp_for(max_hp: int) -> int:
	if max_hp <= 0:
		return 0
	return maxi(1, int(max_hp / 3))


## Pure turn-order sort used by the round roll and by tests: highest total first, heroes
## before foes on a tie, then the lower rank, then the original sequence.
static func sort_turn_entries(entries: Array) -> Array:
	var sorted: Array = entries.duplicate(true)
	sorted.sort_custom(_order_before)
	return sorted


static func _order_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["total"]) != int(b["total"]):
		return int(a["total"]) > int(b["total"])
	if str(a["side"]) != str(b["side"]):
		return str(a["side"]) == "hero"
	if int(a["rank"]) != int(b["rank"]):
		return int(a["rank"]) < int(b["rank"])
	return int(a["seq"]) < int(b["seq"])


func _setup(config: Dictionary) -> String:
	var catalog := StitchedParts.build_catalog(config.get("parts", []))
	if not catalog["ok"]:
		return str(catalog["error"])
	_parts = catalog["by_id"]
	var seed_value: Variant = config.get("seed")
	if not _integral(seed_value):
		return "seed must be an integer"
	var heroes: Variant = config.get("heroes")
	if not heroes is Array or heroes.size() != HERO_COUNT:
		return "stitched mode needs exactly four heroes"
	var candle_value: Variant = config.get("candle", 100)
	if not _integral(candle_value) or int(candle_value) < 0 or int(candle_value) > 100:
		return "candle must be an integer from 0 to 100"
	_candle = int(candle_value)
	var foes: Variant = config.get("foes")
	if not foes is Array or foes.size() < MIN_FOES or foes.size() > MAX_FOES:
		return "stitched mode starts with two or three foes, never four"
	var enabled: Variant = config.get("s14", false)
	if not enabled is bool:
		return "invalid S14 mode"
	_s14 = enabled
	if _s14:
		if StitchedS14Abilities.kits().is_empty() or StitchedS14Abilities.patches().is_empty():
			return "invalid S14 catalogs"
		var sockets: Variant = config.get("s14_sockets", {})
		if not sockets is Dictionary:
			return "invalid S14 sockets"
		for hero_entry in heroes:
			if not hero_entry is Dictionary or not StitchedS14Abilities.valid_loadout(str(hero_entry.get("id", "")), sockets.get(str(hero_entry.get("id", "")), {})):
				return "invalid S14 hero sockets"
		for owner in sockets:
			if not heroes.any(func(h: Variant) -> bool: return h is Dictionary and h.get("id") == owner):
				return "S14 socket owner is outside the party"
		_s14_sockets = sockets.duplicate(true)
	var gifts: Variant = config.get("gifts", StitchedKidHandActions.IDS)
	if not gifts is Array or gifts.is_empty() or gifts.size() > StitchedWrenGifts.SLOTS:
		return "Wren carries one to four gifts"
	for id in gifts:
		if not id is String or not StitchedWrenGifts.is_gift(id) or gifts.count(id) != 1:
			return "unknown or repeated gift " + str(id)
	_gifts = gifts.duplicate()
	var mimic: Variant = config.get("walk_mimic", false)
	var cuts: Variant = config.get("walk_cuts", {})
	if not mimic is bool or not cuts is Dictionary:
		return "invalid Walk arrival options"
	var rank := 0
	for entry in heroes:
		rank += 1
		var carried: Variant = entry
		if entry is Dictionary and cuts.has(entry.get("id")):
			# The Walk already paid exactly +20, but defers combat resolve/seam
			# transitions. Validate its pre-SNIP state, then settle that same gain.
			if not entry.get("fray") is int or entry.fray < 20:
				return "Walk cut requires its paid SNIP fray"
			carried = entry.duplicate(true)
			carried.fray -= 20
		var built := _build_hero(carried, rank)
		if not built["ok"]:
			return str(built["error"])
		_units[str(built["unit"]["id"])] = built["unit"]
	# Check the Walk's pre-transition vitality before a paid fray gain can tear a
	# part and legitimately change maximum HP. No RNG has been borrowed yet.
	var vitality: Variant = config.get("walk_vitality", {})
	if not vitality is Dictionary:
		return "invalid Walk vitality"
	for id in vitality:
		if not _units.has(id) or not vitality[id] is int or vitality[id] != _units[id].max_hp:
			return "combat vitality does not match Walk"
	rank = 0
	for entry in foes:
		rank += 1
		var built := _build_foe(entry, rank)
		if not built["ok"]:
			return str(built["error"])
		_units[str(built["unit"]["id"])] = built["unit"]
		if bool(built["unit"]["is_boss"]):
			_boss_encounter = true
	for id in cuts:
		if not _units.has(id) or _units[id].side != "hero" or _units[id].lost \
				or not cuts[id] is int or cuts[id] != _units[id].rank:
			return "invalid Walk cut boundary"
	_thread_cuts = cuts.duplicate(true)
	if mimic:
		# Until a dedicated mimic profile is authored, reuse Rag Rake's existing
		# combat numbers. Only its special arrival/target masks differ.
		var enemy_catalog := StitchedEnemyCatalog.load_catalog()
		var intruder := StitchedEnemyCatalog.foe_for(enemy_catalog, "ragling")
		if intruder.is_empty():
			return "missing ambush combat profile"
		intruder.id = WALK_MIMIC_ID
		intruder.name = "One Doll Too Many"
		intruder.abilities = [intruder.abilities[0].duplicate(true)]
		intruder.abilities[0].launch = [1, 2, 3, 4]
		intruder.abilities[0].target = [1, 2, 3, 4]
		var built := _build_foe(intruder, MAX_RANK)
		if not built.ok:
			return str(built.error)
		built.unit["walk_intruder"] = true
		_units[WALK_MIMIC_ID] = built.unit
	_valid = true
	if config.get("run_rng") is RandomNumberGenerator:
		_rng = config["run_rng"]
	else:
		_rng = RandomNumberGenerator.new()
		_rng.seed = int(seed_value)
	for id in _thread_cuts.keys():
		_change_fray(_units[id], 20, false)
	_round = 0
	_outcome = "ongoing"
	_begin_round()
	_enter_turn()
	return ""


func _build_hero(entry: Variant, rank: int) -> Dictionary:
	if not entry is Dictionary:
		return {"ok": false, "error": "hero is not a dictionary", "unit": {}}
	var unit_id := _valid_text(entry.get("id"))
	if unit_id.is_empty():
		return {"ok": false, "error": "hero needs a nonempty id", "unit": {}}
	if _units.has(unit_id):
		return {"ok": false, "error": "duplicate unit id: " + unit_id, "unit": {}}
	var name := _valid_text(entry.get("name"))
	if name.is_empty():
		return {"ok": false, "error": "hero " + unit_id + " needs a name", "unit": {}}
	var max_hp := _positive_int(entry.get("max_hp"))
	if max_hp <= 0:
		return {"ok": false, "error": "hero " + unit_id + " needs positive max_hp", "unit": {}}
	var stats := {}
	for key in ["speed", "dodge", "acc", "prot"]:
		var value := _nonnegative_int(entry.get(key, 0))
		if value < 0:
			return {
				"ok": false,
				"error": "hero " + unit_id + " needs a nonnegative " + key,
				"unit": {},
			}
		stats[key] = value
	var equipped: Variant = entry.get("parts")
	if not equipped is Dictionary:
		return {
			"ok": false,
			"error": "hero " + unit_id + " needs four equipped slots",
			"unit": {},
		}
	# Optional carried statuses: only a positive integer Bleed is admitted, so a
	# malformed carry can never become free damage or a silent cure.
	var starting_statuses := {}
	var raw_statuses: Variant = entry.get("statuses", {})
	if not raw_statuses is Dictionary:
		return {
			"ok": false,
			"error": "hero " + unit_id + " statuses must be a dictionary",
			"unit": {},
		}
	for key in raw_statuses:
		if typeof(key) != TYPE_STRING or str(key) != "bleed":
			return {
				"ok": false,
				"error": "hero " + unit_id + " has an illegal starting status: " + str(key),
				"unit": {},
			}
		var amount: Variant = (raw_statuses as Dictionary)[key]
		if typeof(amount) != TYPE_INT or int(amount) <= 0:
			return {
				"ok": false,
				"error": "hero " + unit_id + " needs a positive integer bleed",
				"unit": {},
			}
		starting_statuses["bleed"] = int(amount)
	var carried_lost: Variant = entry.get("lost", false)
	if not carried_lost is bool or (carried_lost and (not equipped.is_empty() or typeof(entry.get("hp")) != TYPE_INT or int(entry["hp"]) != 0)):
		return {"ok": false, "error": "invalid carried lost state", "unit": {}}
	if not carried_lost and equipped.size() != StitchedParts.SLOTS.size():
		return {
			"ok": false,
			"error": "hero " + unit_id + " needs exactly four equipped slots",
			"unit": {},
		}
	var parts: Dictionary = {}
	for slot in StitchedParts.SLOTS:
		if carried_lost:
			break
		if not equipped.has(slot):
			return {
				"ok": false,
				"error": "hero " + unit_id + " is missing the " + slot + " slot",
				"unit": {},
			}
		var worn := _build_equipment(equipped[slot], slot, "hero " + unit_id)
		if not worn["ok"]:
			return {"ok": false, "error": str(worn["error"]), "unit": {}}
		parts[slot] = worn["equipment"]
	# Carry a settled FRAY state verbatim; never perform a setup-time resolve roll.
	var starting_fray: Variant = entry.get("fray", 0)
	var starting_resolve: Variant = entry.get("resolve", "")
	if typeof(starting_fray) != TYPE_INT or int(starting_fray) < 0 \
			or int(starting_fray) >= FRAY_MAX:
		return {"ok": false, "error": "hero " + unit_id + " has invalid starting fray", "unit": {}}
	if typeof(starting_resolve) != TYPE_STRING or not str(starting_resolve) in \
			(["", "steadfast"] + StitchedS1BEffects.RESOLVE_TRAITS):
		return {"ok": false, "error": "hero " + unit_id + " has invalid starting resolve", "unit": {}}
	if (str(starting_resolve) in StitchedS1BEffects.RESOLVE_TRAITS \
			and int(starting_fray) < FRAY_RECOVER) \
			or (str(starting_resolve).is_empty() and int(starting_fray) >= FRAY_RESOLVE):
		return {"ok": false, "error": "hero " + unit_id + " has inconsistent fray/resolve", "unit": {}}
	var unit := {
		"id": unit_id,
		"name": name,
		"side": "hero",
		"rank": rank,
		"base_max_hp": max_hp,
		"max_hp": 0,
		"hp": 0,
		"base_speed": stats["speed"],
		"speed": 0,
		"base_dodge": stats["dodge"],
		"dodge": 0,
		"base_acc": stats["acc"],
		"acc": 0,
		"base_prot": stats["prot"],
		"prot": 0,
		"crit": 0,
		"dmg_bonus": 0,
		"fray": int(starting_fray),
		"resolve": str(starting_resolve),
		"statuses": starting_statuses,
		"parts": parts,
		"abilities": [],
		"death_hits": 0,
		"head_ward": false,
		"is_boss": false,
		"turns_per_round": 1,
		"hanging": false,
		"lost": false,
		"dead": false,
		"miss_streak": 0,
		"guard_target": "",
		"dodge_buff": {},
		# S13: how many fights each worn patch has sat on this doll (the run session keeps it).
		"patch_wear": (entry.get("patch_wear") as Dictionary).duplicate(true) if entry.get("patch_wear") is Dictionary else {},
	}
	if _s14 and not carried_lost:
		var kit: Dictionary = StitchedS14Abilities.kits().get(unit_id, {})
		if kit.is_empty():
			return {"ok": false, "error": "hero has no S14 kit", "unit": {}}
		for slot in StitchedParts.SLOTS:
			unit.abilities.append(kit[slot].duplicate(true))
	var hits: Variant = entry.get("death_hits", 0)
	var ward: Variant = entry.get("head_ward", false)
	if typeof(hits) != TYPE_INT or hits < 0 or hits > 2 or not ward is bool:
		return {"ok": false, "error": "invalid death-door carry", "unit": {}}
	unit.death_hits = hits
	unit.head_ward = ward
	_recompute_stats(unit)
	# Optional carry is in actual HP after worn-part modifiers, never base HP.
	# Zero is an already-Hanging survivor; do not re-tear it or roll extra RNG.
	if entry.has("hp"):
		var starting_hp: Variant = entry["hp"]
		if typeof(starting_hp) != TYPE_INT or int(starting_hp) < 0 \
				or int(starting_hp) > int(unit["max_hp"]):
			return {"ok": false, "error": "hero " + unit_id + " has invalid starting hp", "unit": {}}
		unit["hp"] = int(starting_hp)
		unit["hanging"] = int(starting_hp) == 0
		if unit.hp > 0 and unit.death_hits != 0:
			return {"ok": false, "error": "healed hero retains death hits", "unit": {}}
	else:
		unit["hp"] = int(unit["max_hp"])
	if entry.has("lost"):
		if not entry["lost"] is bool or (entry["lost"] and unit["hp"] != 0):
			return {"ok": false, "error": "invalid carried lost state", "unit": {}}
		unit["lost"] = entry["lost"]
		unit["hanging"] = unit["hp"] == 0 and not unit["lost"]
	return {"ok": true, "error": "", "unit": unit}


func _build_foe(entry: Variant, rank: int) -> Dictionary:
	if not entry is Dictionary:
		return {"ok": false, "error": "foe is not a dictionary", "unit": {}}
	var unit_id := _valid_text(entry.get("id"))
	if unit_id.is_empty():
		return {"ok": false, "error": "foe needs a nonempty id", "unit": {}}
	if _units.has(unit_id):
		return {"ok": false, "error": "duplicate unit id: " + unit_id, "unit": {}}
	var name := _valid_text(entry.get("name"))
	if name.is_empty():
		return {"ok": false, "error": "foe " + unit_id + " needs a name", "unit": {}}
	var max_hp := _positive_int(entry.get("max_hp"))
	if max_hp <= 0:
		return {"ok": false, "error": "foe " + unit_id + " needs positive max_hp", "unit": {}}
	var stats := {}
	for key in ["speed", "dodge", "acc", "prot"]:
		var value := _nonnegative_int(entry.get(key, 0))
		if value < 0:
			return {"ok": false, "error": "foe " + unit_id + " needs a nonnegative " + key, "unit": {}}
		stats[key] = value
	var is_boss: Variant = entry.get("is_boss", false)
	if not is_boss is bool:
		return {"ok": false, "error": "foe " + unit_id + " is_boss must be a boolean", "unit": {}}
	var turns := _positive_int(entry.get("turns_per_round", 1))
	if turns < 1 or turns > 2:
		return {"ok": false, "error": "foe " + unit_id + " may take one or two turns", "unit": {}}
	# Only a boss may take the two-turn exception; an ordinary foe always acts once a round.
	if turns > 1 and not bool(is_boss):
		return {
			"ok": false,
			"error": "foe " + unit_id + " may only take two turns as a boss",
			"unit": {},
		}
	var authored: Variant = entry.get("abilities")
	if not authored is Array or authored.is_empty():
		return {"ok": false, "error": "foe " + unit_id + " needs at least one ability", "unit": {}}
	var abilities: Array = []
	var ability_ids: Array = []
	for ability_entry in authored:
		var result := StitchedParts.validate_ability(ability_entry, "foe " + unit_id + " ability")
		if not result["ok"]:
			return {"ok": false, "error": str(result["error"]), "unit": {}}
		var ability: Dictionary = result["ability"]
		var ability_id := str(ability["id"])
		if ability_id in ability_ids:
			return {
				"ok": false,
				"error": "foe " + unit_id + " repeats ability " + ability_id,
				"unit": {},
			}
		ability_ids.append(ability_id)
		abilities.append(ability)
	var unit := {
		"id": unit_id,
		"name": name,
		"side": "foe",
		"rank": rank,
		"base_max_hp": max_hp,
		"max_hp": max_hp,
		"hp": max_hp,
		"base_speed": stats["speed"],
		"speed": stats["speed"],
		"base_dodge": stats["dodge"],
		"dodge": stats["dodge"],
		"base_acc": stats["acc"],
		"acc": stats["acc"],
		"base_prot": stats["prot"],
		"prot": stats["prot"],
		"crit": 0,
		"dmg_bonus": 0,
		"fray": 0,
		"statuses": {},
		"parts": {},
		"abilities": abilities,
		"is_boss": bool(is_boss),
		"turns_per_round": turns,
		"hanging": false,
		"lost": false,
		"dead": false,
		"miss_streak": 0,
		"guard_target": "",
		"dodge_buff": {},
	}
	return {"ok": true, "error": "", "unit": unit}


func _build_equipment(value: Variant, slot: String, label: String) -> Dictionary:
	var worn: Dictionary = {}
	if value is String:
		worn = {"id": str(value), "tier": 1, "torn": false}
	elif value is Dictionary:
		var part_id := _valid_text(value.get("id"))
		if part_id.is_empty():
			return {"ok": false, "error": label + " " + slot + " needs a part id", "equipment": {}}
		var tier := _positive_int(value.get("tier", 1))
		if tier < StitchedParts.MIN_TIER or tier > StitchedParts.MAX_TIER:
			return {
				"ok": false,
				"error": "%s %s has an illegal tier" % [label, slot],
				"equipment": {},
			}
		var torn: Variant = value.get("torn", false)
		if not torn is bool:
			return {
				"ok": false,
				"error": label + " " + slot + " torn must be a boolean",
				"equipment": {},
			}
		worn = {"id": part_id, "tier": tier, "torn": bool(torn)}
	else:
		return {"ok": false, "error": label + " " + slot + " is not a part", "equipment": {}}
	if not _parts.has(worn["id"]):
		return {
			"ok": false,
			"error": label + " wears an unknown part: " + str(worn["id"]),
			"equipment": {},
		}
	var part: Dictionary = _parts[worn["id"]]
	if str(part["slot"]) != slot:
		return {
			"ok": false,
			"error": "%s %s cannot wear the %s part %s" % [label, slot, str(part["slot"]), worn["id"]],
			"equipment": {},
		}
	return {"ok": true, "error": "", "equipment": worn}


func _recompute_stats(unit: Dictionary) -> void:
	var totals := {"acc": 0, "crit": 0, "dmg": 0, "max_hp": 0, "prot": 0, "speed": 0, "dodge": 0}
	var parts: Dictionary = unit["parts"]
	for slot in parts:
		var worn: Dictionary = parts[slot]
		if bool(worn["torn"]):
			continue
		var stat := StitchedParts.stat_at_tier(_parts[worn["id"]], int(worn["tier"]))
		for key in stat:
			totals[key] = int(totals.get(key, 0)) + int(stat[key])
	# S13: thread sets and broken-in patches sit better, a hidden bonus the player never reads.
	if str(unit.get("side", "")) == "hero":
		var hidden := StitchedSewnPatches.hidden_bonus(str(unit["id"]), parts, unit.get("patch_wear", {}))
		for key in hidden:
			totals[key] = int(totals.get(key, 0)) + int(hidden[key])
	unit["acc"] = int(unit["base_acc"]) + int(totals["acc"])
	unit["crit"] = int(totals["crit"])
	# Arms grant damage: the equipped parts' dmg stat is a flat bonus on every direct attack.
	unit["dmg_bonus"] = int(totals["dmg"])
	if _s14 and parts.has("arms") and parts.arms.torn:
		unit["dmg_bonus"] -= 2
	unit["max_hp"] = int(unit["base_max_hp"]) + int(totals["max_hp"])
	unit["prot"] = int(unit["base_prot"]) + int(totals["prot"])
	unit["speed"] = int(unit["base_speed"]) + int(totals["speed"])
	if _s14 and parts.has("legs") and parts.legs.torn:
		unit["speed"] = maxi(0, int(unit["speed"]) - 2)
	unit["dodge"] = int(unit["base_dodge"]) + int(totals["dodge"])


## Temporary Dodge is separate from permanent gear totals and costs no RNG.
static func effective_dodge(unit: Dictionary) -> int:
	return int(unit.get("dodge", 0)) + int(unit.get("dodge_buff", {}).get("amount", 0))


func _spend_dodge_turn(unit: Dictionary) -> void:
	var buff: Dictionary = unit.get("dodge_buff", {})
	if buff.is_empty():
		return
	if bool(buff.get("skip", false)):
		buff["skip"] = false  # The self-cast turn does not eat its own protection.
		return
	buff["turns"] = int(buff["turns"]) - 1
	if int(buff["turns"]) <= 0:
		unit["dodge_buff"] = {}


func _begin_round() -> void:
	_round += 1
	_turn_index = 0
	if _round > 8:
		_party_fray("", 3)
	_order = _roll_order()
	if _round == 1:
		var band := candle_band()
		var side := str(band["opening_side"])
		var chance := int(band["opening_percent"])
		_opening = {"side": side, "chance": chance, "triggered": false, "roll": 0}
		if chance > 0:
			var roll := _rng.randi_range(1, 100)
			_opening["roll"] = roll
			if StitchedS1BEffects.percent_roll_succeeds(roll, chance):
				for index in range(_order.size()):
					if str(_units[_order[index]]["side"]) == side:
						var first: Variant = _order[index]
						_order.remove_at(index)
						_order.push_front(first)
						_opening["triggered"] = true
						break
		if _units.has(WALK_MIMIC_ID) and bool(_units[WALK_MIMIC_ID].get("walk_intruder", false)):
			_order.push_front(WALK_MIMIC_ID)


## Rolls SPEED + 1d8 for every living unit. Draw order is heroes by rank (1..4), then foes
## by rank (1..3), each unit exactly one draw; a boss is inserted once per turn it takes.
func _roll_order() -> Array:
	var entries: Array = []
	var sequence := 0
	for unit in _units_of_side("hero"):
		if bool(unit["lost"]):
			continue
		var total := int(unit["speed"]) + _rng.randi_range(1, D8)
		entries.append({
			"id": str(unit["id"]),
			"side": "hero",
			"rank": int(unit["rank"]),
			"total": total,
			"seq": sequence,
		})
		sequence += 1
	for unit in _units_of_side("foe"):
		if bool(unit.get("walk_intruder", false)):
			continue  # A first-round arrival, not a recurring initiative roll.
		if bool(unit["dead"]) or int(unit["hp"]) <= 0:
			continue
		var total := int(unit["speed"]) + _rng.randi_range(1, D8)
		for _turn in range(int(unit["turns_per_round"])):
			entries.append({
				"id": str(unit["id"]),
				"side": "foe",
				"rank": int(unit["rank"]),
				"total": total,
				"seq": sequence,
			})
			sequence += 1
	var sorted := sort_turn_entries(entries)
	var order: Array = []
	for entry in sorted:
		order.append(str(entry["id"]))
	return order


## Walks forward from the current turn pointer until a unit that can actually act is found.
## A stunned unit's turn is consumed here; a new round rolls a fresh order.
func _enter_turn() -> void:
	while true:
		if _battle_finished():
			return
		if _turn_index >= _order.size():
			_begin_round()
			continue
		var unit_id := str(_order[_turn_index])
		if not _units.has(unit_id):
			_turn_index += 1
			continue
		var unit: Dictionary = _units[unit_id]
		if not _can_act(unit):
			_turn_index += 1
			continue
		if _tick_turn_start(unit):
			_spend_dodge_turn(unit)
			_turn_index += 1
			continue
		if str(unit["side"]) == "hero" and _unravelled_turn(unit):
			_spend_dodge_turn(unit)
			_turn_index += 1
			continue
		# An unravelled ally's FRAY cascade can lose this acting doll during
		# its own start-of-turn effects. Never hand controls a LOST turn.
		if not _can_act(unit):
			_turn_index += 1
			continue
		# Relief belongs to an actionable Steadfast turn, never a Stun skip or
		# a Bleed-fatal start. This entry point runs once before the command.
		if str(unit["side"]) == "hero" and str(unit.get("resolve", "")) == "steadfast":
			for hero in _units_of_side("hero"):
				if not bool(hero["lost"]):
					_change_fray(hero, -2)
		return


## Start-of-turn status tick. Returns true when the turn is consumed (stun or bleed death).
func _tick_turn_start(unit: Dictionary) -> bool:
	var statuses: Dictionary = unit["statuses"]
	# A Hanging doll is still present at zero HP; LOST dolls and dead foes cannot tick.
	var regen_eligible := _can_act(unit) and (int(unit.hp) > 0 or (
		str(unit.side) == "hero" and int(unit.hp) == 0 and bool(unit.hanging)
	))
	if _s14 and regen_eligible and int(statuses.get("regen", 0)) > 0:
		unit.hp = mini(int(unit.max_hp), int(unit.hp) + 2)
		if str(unit.side) == "hero":
			if int(unit.hp) > 0:
				unit.hanging = false
			unit.death_hits = 0
		statuses.regen -= 1
		if statuses.regen <= 0:
			statuses.erase("regen")
	var stunned := int(statuses.get("stun", 0)) > 0
	if stunned:
		statuses["stun"] = int(statuses["stun"]) - 1
		if int(statuses["stun"]) <= 0:
			statuses.erase("stun")
	# Skipping an action does not skip Bleed or other start-of-turn clocks.
	var bleed := int(statuses.get("bleed", 0))
	if bleed > 0:
		statuses["bleed"] = bleed - 1
		if int(statuses["bleed"]) <= 0:
			statuses.erase("bleed")
		if int(unit["hp"]) > 0:
			unit["hp"] = maxi(0, int(unit["hp"]) - bleed)
			if int(unit["hp"]) == 0:
				_begin_hanging_or_death(unit)
				return true
	for key in COUNTDOWN_KEYS:
		if not statuses.has(key):
			continue
		statuses[key] = int(statuses[key]) - 1
		if int(statuses[key]) <= 0:
			statuses.erase(key)
			if key == "guard":
				unit["guard_target"] = ""
	# A fresh resist must come after old clocks tick, or it expires immediately.
	# Death/Hanging above exits before granting resistance to a fallen unit.
	if stunned and _can_act(unit) and int(unit["hp"]) > 0:
		statuses["stun_resist"] = 1
	return stunned


func _begin_hanging_or_death(unit: Dictionary) -> void:
	if str(unit["side"]) == "hero":
		_enter_hanging(unit)
		return
	_kill_foe(unit)


func _advance_turn() -> void:
	if _outcome != "ongoing":
		return
	_spend_dodge_turn(_current_unit())
	_turn_index += 1
	_enter_turn()


func _require_turn(action: String) -> Dictionary:
	if _outcome != "ongoing":
		return _reject(action, "", "the battle is over")
	if _order.is_empty() or _turn_index < 0 or _turn_index >= _order.size():
		return _reject(action, "", "no unit has the turn")
	var unit_id := str(_order[_turn_index])
	if not _units.has(unit_id):
		return _reject(action, unit_id, "the acting unit is missing")
	var unit: Dictionary = _units[unit_id]
	if bool(unit.get("walk_intruder", false)) and action != "ability":
		return _reject(action, unit_id, "the intruder must attack then flee")
	if not _can_act(unit):
		return _reject(action, unit_id, "the acting unit cannot act")
	return {}


func _require_side_turn(action: String, side: String) -> Dictionary:
	var gate := _require_turn(action)
	if not gate.is_empty():
		return gate
	var unit_id := str(_order[_turn_index])
	if str(_units[unit_id]["side"]) != side:
		return _reject(action, unit_id, "it is not a " + side + " turn")
	return {}


func _reject(action: String, actor: String, error: String) -> Dictionary:
	return {"ok": false, "action": action, "actor": actor, "error": error}


func _current_unit() -> Dictionary:
	return _units[str(_order[_turn_index])]


func _equipment(unit: Dictionary, part_id: String) -> Dictionary:
	var parts: Dictionary = unit.get("parts", {})
	for slot in parts:
		if str(parts[slot]["id"]) == part_id:
			return parts[slot]
	return {}


func _foe_ability(foe: Dictionary, ability_id: String) -> Dictionary:
	for ability in foe.get("abilities", []):
		if str(ability["id"]) == ability_id:
			return ability
	return {}


func _legal_targets(actor: Dictionary, ability: Dictionary, target_rank: int) -> Array:
	var targets: Array = []
	if target_rank < MIN_RANK or target_rank > MAX_RANK:
		return targets
	var mask := int(ability["target_mask"])
	if not StitchedParts.ranks_allowed(mask, target_rank):
		return targets
	var side := str(ability["target_side"])
	if side == "self":
		if target_rank == int(actor["rank"]):
			targets.append(actor)
		return targets
	# "enemy" and "ally" are relative to the acting unit: a hero's enemy is a foe and a
	# foe's enemy is a hero, so one authored ability works on either side of the fight.
	var absolute := str(actor["side"])
	if side == "enemy":
		absolute = "foe" if str(actor["side"]) == "hero" else "hero"
	if not bool(ability["multi"]):
		var single := _unit_at(absolute, target_rank)
		if not single.is_empty() and not _ally_thread_blocked(actor, ability, single):
			targets.append(single)
		return targets
	for rank in range(MIN_RANK, MAX_RANK + 1):
		if not StitchedParts.ranks_allowed(mask, rank):
			continue
		var unit := _unit_at(absolute, rank)
		if not unit.is_empty() and not _ally_thread_blocked(actor, ability, unit):
			targets.append(unit)
	return targets


func _resolve_ability(
	actor: Dictionary, ability: Dictionary, targets: Array, part_id: String
) -> Dictionary:
	var results: Array = []
	# Record identities before any hit or socketed push/pull changes foe ranks.
	# In particular, a multi-target ability must not chain back into its own
	# already-selected primary targets.
	var primary_ids: Dictionary = {}
	for target in targets:
		primary_ids[str(target.id)] = true
	var original_foes: Array = []
	var chain_enabled := false
	if _s14 and str(actor.side) == "hero" and str(ability.target_side) == "enemy":
		for rank in range(MIN_RANK, MAX_RANK + 1):
			var foe := _foe_at(rank)
			if not foe.is_empty():
				original_foes.append({"id": str(foe.id), "rank": rank})
		var attached: Array = _s14_sockets.get(str(actor.id), {}).get(str(ability.id), [])
		var catalog := StitchedS14Abilities.patches()
		for patch_id in attached:
			if str(catalog.by_id[patch_id].effect) == "chain":
				chain_enabled = true
				break
	var chain_anchor := ""
	for target in targets:
		if str(target["side"]) == "foe" and (bool(target["dead"]) or int(target["hp"]) <= 0):
			continue
		# A prior hit may have lost another hero through the shared FRAY cascade.
		if str(target["side"]) == "hero" and bool(target["lost"]):
			continue
		var hit_result := _resolve_single(actor, ability, target)
		results.append(hit_result)
		if _s14 and str(actor.side) == "hero" and hit_result.hit:
			_s14_apply_patches(actor, ability, hit_result)
			if chain_enabled and chain_anchor.is_empty():
				chain_anchor = str(target.id)
	# Resolve at most one extra hit after ALL primaries. The successor is the
	# originally next eligible foe, not the unit now in that rank after a swap.
	# If that successor died, moved out of range or disappeared, do not consume
	# another hit roll or fall through to a different foe.
	if not chain_anchor.is_empty():
		var anchor_rank := 0
		for entry in original_foes:
			if str(entry.id) == chain_anchor:
				anchor_rank = int(entry.rank)
				break
		for entry in original_foes:
			var original_rank := int(entry.rank)
			var next_id := str(entry.id)
			if original_rank <= anchor_rank or primary_ids.has(next_id) \
					or not StitchedParts.ranks_allowed(int(ability.target_mask), original_rank):
				continue
			var successor: Dictionary = _units.get(next_id, {})
			if not successor.is_empty() and not bool(successor.dead) and int(successor.hp) > 0 \
					and str(successor.side) == "foe" \
					and StitchedParts.ranks_allowed(int(ability.target_mask), int(successor.rank)):
				var current: Dictionary = _foe_at(int(successor.rank))
				if not current.is_empty() and str(current.id) == next_id:
					var chained := _resolve_single(actor, ability, successor)
					chained["chained"] = true
					results.append(chained)
					if chained.hit:
						_s14_apply_patches(actor, ability, chained)
			break
	var receipt := {
		"ok": true,
		"action": "ability",
		"actor": str(actor["id"]),
		"actor_side": str(actor["side"]),
		"ability": str(ability["id"]),
		"part": part_id,
		"results": results,
	}
	if results.size() == 1:
		receipt["target"] = str(results[0]["target"])
	var self_move := int(ability["self_move"])
	if self_move != 0 and _can_act(actor):
		receipt["self_move"] = _shift(actor, self_move)
	return receipt


func _s14_apply_patches(actor: Dictionary, ability: Dictionary, receipt: Dictionary) -> void:
	var target: Dictionary = _units.get(str(receipt.target), {})
	if target.is_empty() or target.get("dead", false) or target.get("lost", false):
		return
	var attached: Array = _s14_sockets.get(str(actor.id), {}).get(str(ability.id), [])
	var catalog := StitchedS14Abilities.patches()
	for patch_id in attached:
		var patch: Dictionary = catalog.by_id[patch_id]
		var effect: String = patch.effect
		var amount: int = int(patch.amount)
		if effect == "chain":
			continue
		if effect == "regen":
			target.statuses["regen"] = maxi(int(target.statuses.get("regen", 0)), amount)
			receipt.statuses.append({"status": "regen", "duration": amount, "patch": patch_id})
		elif effect == "cleanse":
			for key in ["bleed", "weak", "exposed", "tangled", "blind", "mark", "stun"]:
				target.statuses.erase(key)
			receipt.statuses.append({"status": "cleanse", "patch": patch_id})
		elif effect == "steal":
			# A gold steal on an ally heal harms that ally too: the patch always
			# affects the actual target, not just the opposing side. The drained
			# stuffing never restores a caster this same exchange just made dead
			# or LOST (a self-steal through the death door, or the shared fray
			# cascade of a dying target): the bite lands, the drain does not.
			if target.side in ["hero", "foe"]:
				var actual := mini(int(target.hp), amount)
				_damage_target(target, actual, receipt)
				if not actor.get("dead", false) and not actor.get("lost", false):
					actor.hp = mini(int(actor.max_hp), int(actor.hp) + actual)
					if actor.hp > 0:
						actor.hanging = false
						actor.death_hits = 0
					receipt.statuses.append({"status": "steal", "amount": actual, "patch": patch_id})
		elif effect == "heal":
			# The sewn-on Cotton/Gold healing mends the signature's actual surviving
			# target, hero or foe alike (cycle 626's target-side principle): a foe
			# struck by the carrying attack receives it too. Heal after the confirmed
			# hit, cap at max HP and report the actual amount; never widen authored
			# heal effects or resurrect the already killed (gated above).
			if target.side in ["hero", "foe"]:
				var before := int(target.hp)
				target.hp = mini(int(target.max_hp), before + amount)
				var healed := int(target.hp) - before
				if target.side == "hero" and int(target.hp) > 0:
					target.hanging = false
					target.death_hits = 0
				receipt.statuses.append({"status": "heal", "amount": healed, "patch": patch_id})
				receipt.target_hp = int(target.hp)
		else:
			_apply_effects(actor, target, {"effects": {effect: amount}}, receipt)
		receipt["patches"] = receipt.get("patches", []) + [patch_id]
		# Ordered sockets stop the moment a patch made the actual target dead or
		# LOST: no later patch in this same signature may heal, mark or follow up
		# on the doll that just left the fight, so the receipt stays truthful.
		if target.get("dead", false) or target.get("lost", false):
			break


func _resolve_single(actor: Dictionary, ability: Dictionary, target: Dictionary) -> Dictionary:
	var receipt := {
		"target": str(target["id"]),
		"target_side": str(target["side"]),
		"target_rank": int(target["rank"]),
		"hit": false,
		"crit": false,
		"damage": 0,
		"target_hp": int(target["hp"]),
		"seam": "",
		"hanging": false,
		"lost": false,
		"statuses": [],
	}
	if str(ability["target_side"]) != "enemy":
		_apply_effects(actor, target, ability, receipt)
		receipt["hit"] = true
		return receipt
	var aimed := target
	if str(aimed["side"]) == "hero":
		var guardian := _guardian_for(aimed)
		if not guardian.is_empty():
			aimed = guardian
			receipt["guarded_by"] = str(guardian["id"])
			receipt["target"] = str(guardian["id"])
			receipt["target_rank"] = int(guardian["rank"])
	_resolve_attack(actor, ability, aimed, receipt)
	return receipt


func _resolve_attack(
	actor: Dictionary, ability: Dictionary, target: Dictionary, receipt: Dictionary
) -> void:
	var actor_statuses: Dictionary = actor["statuses"]
	var blinded := int(actor_statuses.get("blind", 0)) > 0
	var foe_acc := int(candle_band()["enemy_acc"]) if str(actor["side"]) == "foe" else 0
	var chance := hit_chance(
		int(ability["acc"]) + int(actor["acc"]) + foe_acc,
		effective_dodge(target),
		int(actor["miss_streak"])
	)
	receipt["hit_chance"] = chance
	var hit := false
	if blinded:
		actor_statuses.erase("blind")
		receipt["blinded"] = true
	else:
		var roll := _rng.randi_range(1, 100)
		receipt["roll"] = roll
		hit = roll <= chance
	receipt["hit"] = hit
	if not hit:
		actor["miss_streak"] = int(actor["miss_streak"]) + 1
		return
	actor["miss_streak"] = 0
	var maximum := int(ability["dmg"][1])
	# A confirmed 0-damage hit (a pure debuff such as Mark) still applies its authored effects;
	# only the damage and crit rolls are skipped. The equipped arms' dmg stat is a flat bonus
	# added to the direct attack base (critical or not) before Weak/Exposed/Tangled/PROT.
	if maximum > 0:
		var critical := _rng.randi_range(1, 100) <= CRIT_BASE + int(ability["crit"]) + int(actor["crit"])
		receipt["crit"] = critical
		var base := 0
		if critical:
			base = crit_damage(maximum)
		else:
			base = _rng.randi_range(int(ability["dmg"][0]), maximum)
		base += int(actor.get("dmg_bonus", 0))
		if str(actor["side"]) == "foe":
			base = StitchedS1BEffects.enemy_damage(base, _candle)
		elif str(actor.get("resolve", "")) == "steadfast":
			base = StitchedS1BEffects.steadfast_damage(base)
		if critical and str(actor["side"]) == "hero":
			_change_fray(actor, -CRIT_FRAY_RELIEF)
			receipt["fray_relief"] = CRIT_FRAY_RELIEF
		var marked := int(target["statuses"].get("mark", 0)) > 0
		var damage := damage_after_modifiers(
			base,
			actor_statuses,
			target["statuses"],
			marked,
			int(ability["mark_damage"]),
			int(target.get("prot", 0))
		)
		receipt["damage"] = damage
		_damage_target(target, damage, receipt)
		if critical and str(actor["side"]) == "foe" and str(target["side"]) == "hero" and not bool(target["lost"]):
			receipt["enemy_crit_fray"] = _change_fray(target, 10)
		if str(actor["side"]) == "hero" and receipt.has("heap"):
			var kill_roll := _rng.randi_range(1, 100)
			receipt["kill_relief_roll"] = kill_roll
			if StitchedS1BEffects.percent_roll_succeeds(kill_roll, 50):
				_change_fray(actor, -3)
				receipt["kill_fray_relief"] = 3
	_apply_effects(actor, target, ability, receipt)
	# Thorns and Riposte are reaction damage: they answer a confirmed hit and ignore PROT.
	var thorns := int(target["statuses"].get("thorns", 0))
	if thorns > 0 and int(target["hp"]) > 0 and not bool(actor["dead"]) and not bool(actor["lost"]):
		_damage_attacker(actor, thorns, receipt, "thorns")
	var riposte := int(target["statuses"].get("riposte", 0))
	# A zero-HP Hanging hero is still present and can take a seam check;
	# only an actually DEAD foe or LOST doll stops the reaction chain.
	if riposte > 0 and int(target["hp"]) > 0 and not bool(actor["dead"]) and not bool(actor["lost"]):
		_damage_attacker(actor, riposte, receipt, "riposte")


func _apply_effects(
	actor: Dictionary, target: Dictionary, ability: Dictionary, receipt: Dictionary
) -> void:
	# Lethal direct damage has already settled death and cleared statuses. Never
	# reattach a debuff to the dead foe (or a lost doll) after that kill.
	if (str(target.get("side", "")) == "foe" and bool(target.get("dead", false))) \
			or (str(target.get("side", "")) == "hero" and bool(target.get("lost", false))):
		return
	var effects: Dictionary = ability["effects"]
	for key in effects:
		var value := int(effects[key])
		if key == "duration":
			continue  # Paired metadata only; never a status.
		if key == "dodge":
			if str(target["side"]) != "heap":
				target["dodge_buff"] = {
					"amount": value, "turns": int(effects["duration"]),
					"skip": str(actor["id"]) == str(target["id"]),
				}
				receipt["statuses"].append({"status": "dodge", "amount": value, "duration": int(effects["duration"])})
			continue
		if key == "fray":
			if str(actor["side"]) == "foe" and str(target["side"]) == "hero" and not bool(target["lost"]):
				receipt["fray_event"] = _change_fray(target, value)
			continue
		if key == "snip":
			if str(actor["side"]) == "foe" and str(target["side"]) == "hero":
				receipt["snip"] = _cut_behind(target)
			continue
		if key == "tear":
			if str(actor["side"]) == "foe" and str(target["side"]) == "hero":
				receipt["tear"] = _tear_random(target)
			continue
		if key == "push" or key == "pull":
			var direction := 1 if key == "push" else -1
			if str(target["side"]) == "hero":
				receipt["shift"] = _shift(target, direction)
			elif _s14 and str(target["side"]) == "foe":
				receipt["shift"] = _gift_shift(target, direction)
			continue
		if key == "heal":
			if str(target["side"]) == "hero" and not bool(target["lost"]):
				var before := int(target["hp"])
				target["hp"] = mini(int(target["max_hp"]), before + value)
				if int(target["hp"]) > 0:
					target["hanging"] = false
					if _s14:
						target["death_hits"] = 0
				receipt["statuses"].append({
					"status": "heal",
					"amount": int(target["hp"]) - before,
				})
			continue
		if key == "guard":
			actor["statuses"]["guard"] = maxi(int(actor["statuses"].get("guard", 0)), value)
			actor["guard_target"] = str(target["id"])
			receipt["statuses"].append({
				"status": "guard",
				"duration": int(actor["statuses"]["guard"]),
				"guards": str(target["id"]),
			})
			continue
		if str(target["side"]) == "heap":
			continue
		if key == "stun" and int(target["statuses"].get("stun_resist", 0)) > 0:
			receipt["statuses"].append({"status": "stun", "refused": true})
			continue
		target["statuses"][key] = maxi(int(target["statuses"].get(key, 0)), value)
		receipt["statuses"].append({"status": key, "duration": value})


func _damage_target(target: Dictionary, damage: int, receipt: Dictionary) -> void:
	var side := str(target["side"])
	if side == "heap":
		target["hp"] = maxi(0, int(target["hp"]) - damage)
		receipt["target_hp"] = int(target["hp"])
		if int(target["hp"]) == 0:
			_clear_heap(target)
			receipt["heap_cleared"] = true
		return
	var was_hanging := bool(target["hanging"])
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	receipt["target_hp"] = int(target["hp"])
	if side == "hero":
		if _s14 and damage <= 0:
			return
		if _s14 and damage > 0 and int(target.hp) == 0:
			var door := _death_door_hit(target)
			receipt["death_door"] = door
			receipt["tear"] = door.get("tear", {})
			receipt["hanging"] = not was_hanging
			receipt["lost"] = bool(target.lost)
			if target.lost:
				receipt["satchel"] = door.get("satchel", {})
			return
		if int(target["hp"]) == 0:
			if was_hanging:
				var seam_roll := _rng.randi_range(1, 100)
				receipt["seam_roll"] = seam_roll
				if seam_holds(seam_roll):
					receipt["seam"] = "hold"
				else:
					receipt["seam"] = "lost"
					receipt["lost"] = true
					receipt["satchel"] = _lose_hero(target)
			else:
				var hanging := _enter_hanging(target)
				receipt["hanging"] = true
				receipt["tear"] = hanging["torn"]
		return
	if int(target["hp"]) == 0 and not bool(target["dead"]):
		receipt["heap"] = _kill_foe(target)


func _damage_attacker(
	actor: Dictionary, amount: int, receipt: Dictionary, source: String
) -> void:
	receipt[source] = amount
	var was_hanging := bool(actor["hanging"])
	actor["hp"] = maxi(0, int(actor["hp"]) - amount)
	receipt["attacker_hp"] = int(actor["hp"])
	if str(actor["side"]) == "hero":
		if _s14 and amount > 0 and int(actor.hp) == 0:
			var door := _death_door_hit(actor)
			receipt["attacker_death_door"] = door
			receipt["attacker_tear"] = door.get("tear", {})
			receipt["attacker_lost"] = bool(actor.lost)
			return
		if int(actor["hp"]) == 0:
			if was_hanging:
				var seam_roll := _rng.randi_range(1, 100)
				receipt["attacker_seam_roll"] = seam_roll
				if seam_holds(seam_roll):
					receipt["attacker_seam"] = "hold"
				else:
					receipt["attacker_seam"] = "lost"
					receipt["attacker_lost"] = true
					receipt["attacker_satchel"] = _lose_hero(actor)
			else:
				receipt["attacker_hanging"] = true
				receipt["attacker_tear"] = _enter_hanging(actor)["torn"]
		return
	if int(actor["hp"]) == 0 and not bool(actor["dead"]):
		receipt["attacker_heap"] = _kill_foe(actor)


## Validity of a mandatory self_move step, checked without changing anything. A hero swaps
## with the ally in the destination rank, so that ally must not be Tangled either; a foe only
## steps into a rank with no living foe and no scrap heap. Used both to preflight an ability
## (before any action) and to perform the step itself.
func _shift_valid(unit: Dictionary, direction: int) -> Dictionary:
	var from := int(unit["rank"])
	var destination := from + direction
	if direction < -1 or direction > 1 or direction == 0:
		return {"ok": false, "reason": "there is no rank %d" % destination}
	if destination < MIN_RANK or destination > MAX_RANK:
		return {"ok": false, "reason": "there is no rank %d" % destination}
	if _s14 and str(unit.side) == "hero" and unit.parts.has("legs") and unit.parts.legs.torn:
		return {"ok": false, "reason": "torn legs cannot move"}
	if int(unit["statuses"].get("tangled", 0)) > 0:
		return {"ok": false, "reason": "tangled units cannot move"}
	if str(unit["side"]) == "hero" and (_thread_cuts.has(str(unit["id"])) or _crosses_cut(from, destination)):
		return {"ok": false, "reason": "thread cut blocks movement"}
	if str(unit["side"]) == "hero" and is_held(str(unit["id"])):
		return {"ok": false, "reason": "Wren is holding this doll back"}
	if str(unit["side"]) == "hero":
		var other := _hero_at(destination)
		if not other.is_empty() and is_held(str(other["id"])):
			return {"ok": false, "reason": "Wren is holding that doll back"}
		if _s14 and not other.is_empty() and other.parts.has("legs") and other.parts.legs.torn:
			return {"ok": false, "reason": "the other doll has torn legs"}
		if not other.is_empty() and int(other["statuses"].get("tangled", 0)) > 0:
			return {"ok": false, "reason": "a tangled ally cannot be swapped"}
		if not other.is_empty() and _thread_cuts.has(str(other["id"])):
			return {"ok": false, "reason": "snipped ally cannot be moved"}
		return {"ok": true, "reason": "", "destination": destination}
	if not _foe_at(destination).is_empty() or not _heap_at(destination).is_empty():
		return {"ok": false, "reason": "rank %d is taken" % destination}
	return {"ok": true, "reason": "", "destination": destination}


## Returns a refusal receipt when an ability's mandatory self_move step is impossible, so the
## action never resolves and the turn is not spent; {} when the step is legal.
func _self_move_gate(actor: Dictionary, ability: Dictionary) -> Dictionary:
	var direction := int(ability["self_move"])
	if direction == 0:
		return {}
	var plan := _shift_valid(actor, direction)
	if bool(plan["ok"]):
		return {}
	return _reject("ability", str(actor["id"]), "self move is blocked: " + str(plan["reason"]))


## Moves a unit one rank for a self_move ability; heroes swap with the ally in the way,
## foes only step into an empty rank. Tangled units refuse to be moved.
func _shift(unit: Dictionary, direction: int) -> Dictionary:
	var plan := _shift_valid(unit, direction)
	if not plan["ok"]:
		return {"ok": false, "reason": str(plan["reason"])}
	var destination := int(plan["destination"])
	var from := int(unit["rank"])
	var swapped := ""
	if str(unit["side"]) == "hero":
		var other := _hero_at(destination)
		if not other.is_empty():
			other["rank"] = from
			swapped = str(other["id"])
	unit["rank"] = destination
	return {"ok": true, "from": from, "to": destination, "swapped": swapped}


## Wren's Tug and Shove move a foe one rank by hand: unlike a foe's own step, it trades places
## with the foe in the way. A tangled foe on either end, or a scrap heap, blocks it.
func _gift_shift_valid(foe: Dictionary, direction: int) -> Dictionary:
	var destination := int(foe["rank"]) + direction
	if destination < MIN_RANK or destination > MAX_RANK:
		return {"ok": false, "reason": "there is no rank %d" % destination}
	if int(foe["statuses"].get("tangled", 0)) > 0:
		return {"ok": false, "reason": "tangled units cannot move"}
	var other := _foe_at(destination)
	if other.is_empty() and not _heap_at(destination).is_empty():
		return {"ok": false, "reason": "a scrap heap is in the way"}
	if not other.is_empty() and int(other["statuses"].get("tangled", 0)) > 0:
		return {"ok": false, "reason": "the foe in the way is tangled"}
	return {"ok": true, "reason": "", "destination": destination}


func _gift_shift(foe: Dictionary, direction: int) -> Dictionary:
	var plan := _gift_shift_valid(foe, direction)
	if not plan["ok"]:
		return {"ok": false, "reason": str(plan["reason"])}
	var destination := int(plan["destination"])
	var from := int(foe["rank"])
	var other := _foe_at(destination)
	var swapped := ""
	if not other.is_empty():
		other["rank"] = from
		swapped = str(other["id"])
	foe["rank"] = destination
	return {"ok": true, "from": from, "to": destination, "swapped": swapped}


func _guardian_for(target: Dictionary) -> Dictionary:
	if str(target["side"]) != "hero" or str(target.get("resolve", "")) == "reckless":
		return {}
	for unit_id in _units:
		var unit: Dictionary = _units[unit_id]
		if str(unit["side"]) != "hero" or str(unit["id"]) == str(target["id"]):
			continue
		if bool(unit["lost"]):
			continue
		if int(unit["statuses"].get("guard", 0)) <= 0:
			continue
		if str(unit.get("guard_target", "")) != str(target["id"]):
			continue
		if _crosses_cut(int(unit["rank"]), int(target["rank"])):
			continue
		return unit
	return {}


func _kill_foe(foe: Dictionary) -> Dictionary:
	foe["dead"] = true
	foe["hp"] = 0
	foe["hanging"] = false
	foe["statuses"] = {}
	if bool(foe.get("walk_intruder", false)):
		return {}  # Reactions cannot turn the fleeting arrival into loot or a heap.
	var heap_hp := heap_hp_for(int(foe["max_hp"]))
	var heap := {
		"id": "heap:" + str(foe["id"]),
		"side": "heap",
		"rank": int(foe["rank"]),
		"hp": heap_hp,
		"max_hp": heap_hp,
		"foe_id": str(foe["id"]),
		"statuses": {},
	}
	_heaps.append(heap)
	return {"rank": int(heap["rank"]), "hp": int(heap["hp"])}


func _clear_heap(heap: Dictionary) -> void:
	for index in range(_heaps.size() - 1, -1, -1):
		if str(_heaps[index]["id"]) == str(heap["id"]):
			_heaps.remove_at(index)
	_compact_foe_ranks()


## A cleared heap lets the foes behind it step forward, one rank per vacant gap. Only vacant
## ranks close up: a rank still holding an uncleared heap keeps blocking forward progress, so
## a foe behind a heap never jumps across it.
func _compact_foe_ranks() -> void:
	var moved := true
	while moved:
		moved = false
		for rank in range(MIN_RANK, MAX_RANK):
			if _enemy_rank_taken(rank):
				continue
			for behind in range(rank + 1, MAX_RANK + 1):
				if not _enemy_rank_taken(behind):
					continue
				var foe := _foe_at(behind)
				if foe.is_empty():
					break
				foe["rank"] = rank
				moved = true
				break


func _enemy_rank_taken(rank: int) -> bool:
	return not _foe_at(rank).is_empty() or not _heap_at(rank).is_empty()


func _unit_at(side: String, rank: int) -> Dictionary:
	if side == "foe":
		var foe := _foe_at(rank)
		if not foe.is_empty():
			return foe
		return _heap_at(rank)
	return _hero_at(rank)


func _hero_at(rank: int) -> Dictionary:
	for unit in _units_of_side("hero"):
		if int(unit["rank"]) == rank and not bool(unit["lost"]):
			return unit
	return {}


func _foe_at(rank: int) -> Dictionary:
	for unit in _units_of_side("foe"):
		if int(unit["rank"]) == rank and not bool(unit["dead"]) and int(unit["hp"]) > 0:
			return unit
	return {}


func _heap_at(rank: int) -> Dictionary:
	for heap in _heaps:
		if int(heap["rank"]) == rank:
			return heap
	return {}


func _units_of_side(side: String) -> Array:
	var units: Array = []
	for unit_id in _units:
		if str(_units[unit_id]["side"]) == side:
			units.append(_units[unit_id])
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["rank"]) < int(b["rank"]))
	return units


func _sorted_ids() -> Array:
	var ids: Array = []
	for unit in _units_of_side("hero"):
		ids.append(str(unit["id"]))
	for unit in _units_of_side("foe"):
		ids.append(str(unit["id"]))
	return ids


func _can_act(unit: Dictionary) -> bool:
	if str(unit["side"]) == "hero":
		return not bool(unit["lost"])
	return int(unit["hp"]) > 0 and not bool(unit["dead"])


func _living_foes() -> Array:
	var living: Array = []
	for unit in _units_of_side("foe"):
		if not bool(unit["dead"]) and int(unit["hp"]) > 0:
			living.append(unit)
	return living


func _battle_finished() -> bool:
	if _outcome != "ongoing":
		return true
	if _living_foes().is_empty():
		_outcome = "victory"
		_finish_cleanup()
		return true
	for unit in _units_of_side("hero"):
		if not bool(unit["lost"]):
			return false
	_outcome = "defeat"
	_finish_cleanup()
	return true


static func _integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	return typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value)


static func _positive_int(value: Variant) -> int:
	if not _integral(value):
		return -1
	return int(value)


static func _nonnegative_int(value: Variant) -> int:
	if not _integral(value) or int(value) < 0:
		return -1
	return int(value)


static func _valid_text(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var text: String = value
	if text.is_empty() or text != text.strip_edges():
		return ""
	return text


# ---------------------------------------------------------------- S1b fray, seams and thread

## All fray gains use the candle of this battle, clamp to 200, and are applied
## through the same seeded resolve gate. Recovery is never candle-multiplied.
func _change_fray(hero: Dictionary, amount: int, scale_by_candle: bool = true) -> Dictionary:
	if str(hero["side"]) != "hero" or bool(hero["lost"]):
		return _reject("fray", str(hero["id"]), "hero is lost or not a hero")
	var before := int(hero["fray"])
	var applied := StitchedS1BEffects.fray_gain(amount, _candle) if amount > 0 and scale_by_candle and not candle_shielded() else amount
	if applied > 0 and eyes_covered(str(hero["id"])):
		applied = 0
	hero["fray"] = clampi(before + applied, 0, FRAY_MAX)
	var transition := ""
	if int(hero["fray"]) >= FRAY_MAX:
		hero["fray"] = 150
		if bool(hero["hanging"]):
			_lose_hero(hero)
			transition = "lost"
		else:
			hero["hp"] = 0
			_enter_hanging(hero)
			transition = "hanging"
	elif int(hero["fray"]) < FRAY_RECOVER and str(hero.get("resolve", "")) in StitchedS1BEffects.RESOLVE_TRAITS:
		hero["resolve"] = ""
		transition = "recovered"
	elif before < FRAY_RESOLVE and int(hero["fray"]) >= FRAY_RESOLVE and str(hero.get("resolve", "")).is_empty():
		var roll := _rng.randi_range(1, 100)
		if StitchedS1BEffects.percent_roll_succeeds(roll, 25):
			hero["resolve"] = "steadfast"
			hero["fray"] = 45
			transition = "steadfast"
		else:
			hero["resolve"] = StitchedS1BEffects.trait_for_roll(_rng.randi_range(0, 4))
			transition = str(hero["resolve"])
	return {"ok": true, "action": "fray", "actor": str(hero["id"]), "before": before, "change": applied, "after": int(hero["fray"]), "transition": transition}


func _party_fray(except_id: String, amount: int) -> void:
	# A fallen ally frays the surviving witnesses, never the fallen doll itself.
	for hero in _units_of_side("hero"):
		if str(hero["id"]) != except_id and not bool(hero["lost"]):
			_change_fray(hero, amount)


## Entering Hanging tears precisely one random non-torso part, only on its first
## entry. The part remains equipped but torn (no stat/ability) until Sewing Circle.
func _enter_hanging(hero: Dictionary) -> Dictionary:
	if _s14:
		if hero.lost or hero.hanging:
			return _reject("hanging", str(hero.id), "doll already at death's door")
		return {"ok": true, "torn": _death_door_hit(hero).get("tear", {})}
	if bool(hero["lost"]) or bool(hero["hanging"]):
		return _reject("hanging", str(hero["id"]), "hero is already Hanging or lost")
	hero["hp"] = 0
	hero["hanging"] = true
	var tear := _tear_random(hero)
	_party_fray(str(hero["id"]), 8)
	return {"ok": true, "torn": tear}


## One limb on each damaging zero-HP hit: first head 10%, second 45%, third 100%.
## A head tear is terminal and uses the existing LOST/satchel/replacement machinery.
func _death_door_hit(hero: Dictionary) -> Dictionary:
	if hero.lost or hero.side != "hero":
		return {"ok": false}
	hero.hp = 0
	hero.hanging = true
	var hits := mini(3, int(hero.get("death_hits", 0)) + 1)
	hero.death_hits = mini(2, hits)
	var roll := 100 if hits >= 3 else _rng.randi_range(1, 100)
	var head := hits >= 3 or roll <= (10 if hits == 1 else 45)
	var options: Array = []
	for slot in ["arms", "legs"]:
		if hero.parts.has(slot) and not hero.parts[slot].torn:
			options.append(slot)
	if head and hero.get("head_ward", false) and hits < 3 and not options.is_empty():
		head = false
		hero.head_ward = false
	var slot := "head" if head or options.is_empty() else str(options[_rng.randi_range(0, options.size() - 1)])
	if slot == "head":
		if hero.parts.has("head"):
			hero.parts.head.torn = true
		var lost := _lose_hero(hero)
		return {"ok": true, "hits": hits, "roll": roll, "tear": {"slot": "head"}, "lost": true, "satchel": lost}
	hero.parts[slot].torn = true
	_recompute_stats(hero)
	_party_fray(str(hero.id), 8)
	return {"ok": true, "hits": hits, "roll": roll, "tear": {"slot": slot}, "lost": false}


func _tear_random(hero: Dictionary) -> Dictionary:
	if str(hero.get("side", "")) != "hero" or bool(hero.get("lost", false)):
		return _reject("tear", str(hero.get("id", "")), "hero is lost or not a hero")
	var eligible: Array = []
	for slot in ["head", "arms", "legs"]:
		if hero["parts"].has(slot) and not bool(hero["parts"][slot]["torn"]):
			eligible.append(slot)
	if eligible.is_empty():
		return _reject("tear", str(hero["id"]), "no untorn non-torso part")
	var slot := str(eligible[_rng.randi_range(0, eligible.size() - 1)])
	var part_id := str(hero.parts[slot].id)
	hero["parts"][slot]["torn"] = true
	if _s14 and slot == "head":
		_lose_hero(hero)
	else:
		_recompute_stats(hero)
	return {"ok": true, "action": "tear", "hero": str(hero.id), "slot": slot, "part": part_id}


## A lost doll leaves combat permanently and its equipped parts fill at most six
## satchel slots. Overflow is explicitly discarded in stable slot order.
func _lose_hero(hero: Dictionary) -> Dictionary:
	if bool(hero["lost"]):
		return _reject("lost", str(hero["id"]), "hero is already lost")
	hero["lost"] = true
	hero["hanging"] = false
	hero["hp"] = 0
	hero["statuses"] = {}
	hero["dodge_buff"] = {}
	_thread_cuts.erase(str(hero["id"]))
	var stored: Array = []
	var overflow: Array = []
	for slot in StitchedParts.SLOTS:
		if not hero["parts"].has(slot):
			continue
		var worn: Dictionary = hero["parts"][slot]
		var spare := worn.duplicate(true)
		spare["slot"] = slot
		if _satchel.size() < SATCHEL_CAP:
			_satchel.append(spare)
			stored.append(str(worn["id"]))
		else:
			overflow.append(str(worn["id"]))
	hero["parts"] = {}
	_party_fray(str(hero["id"]), 25)
	return {"ok": true, "stored": stored, "overflow": overflow}


func _cut_behind(hero: Dictionary) -> Dictionary:
	if str(hero.get("side", "")) != "hero" or bool(hero.get("lost", false)):
		return _reject("snip", str(hero.get("id", "")), "cannot snip this target")
	var id := str(hero["id"])
	if int(hero["rank"]) >= MAX_RANK or _thread_cuts.has(id):
		return _reject("snip", id, "no intact thread behind this hero")
	_thread_cuts[id] = int(hero["rank"])
	return {"ok": true, "action": "snip", "hero": id, "after_rank": int(hero["rank"])}


func _crosses_cut(a: int, b: int) -> bool:
	for rank in _thread_cuts.values():
		var boundary := int(rank)
		if (a <= boundary and b > boundary) or (b <= boundary and a > boundary):
			return true
	return false


func _finish_cleanup() -> void:
	_thread_cuts.clear()
	for unit in _units.values():
		unit["dodge_buff"] = {}


func _unravelled_turn(hero: Dictionary) -> bool:
	var mood := str(hero.get("resolve", ""))
	var id := str(hero["id"])
	match mood:
		"hollow":
			var roll := _rng.randi_range(1, 100)
			if StitchedS1BEffects.percent_roll_succeeds(roll, 30):
				_turn_events.append({"actor": id, "mood": mood, "action": "pass", "roll": roll})
				return true
		"bitter":
			var neighbor := _hero_at(int(hero["rank"]) - 1)
			if neighbor.is_empty():
				neighbor = _hero_at(int(hero["rank"]) + 1)
			if not neighbor.is_empty():
				var receipt := _change_fray(neighbor, 4)
				_turn_events.append({"actor": id, "mood": mood, "action": "fray", "target": str(neighbor["id"]), "receipt": receipt})
		"reckless", "cowering":
			var direction := -1 if mood == "reckless" else 1
			var plan := _shift_valid(hero, direction)
			if bool(plan["ok"]):
				var receipt := _shift(hero, direction)
				_turn_events.append({"actor": id, "mood": mood, "action": "move", "receipt": receipt})
				return true
		"frantic":
			var candidates: Array = []
			for slot in StitchedParts.SLOTS:
				if not hero["parts"].has(slot):
					continue
				var worn: Dictionary = hero["parts"][slot]
				if bool(worn["torn"]):
					continue
				var ability := StitchedParts.ability_at_tier(_parts[worn["id"]], int(worn["tier"]))
				if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(hero["rank"])):
					continue
				if not _self_move_gate(hero, ability).is_empty():
					continue
				for rank in range(MIN_RANK, MAX_RANK + 1):
					var targets := _legal_targets(hero, ability, rank)
					if not targets.is_empty():
						candidates.append({"ability": ability, "part": str(worn["id"]), "rank": rank})
			if not candidates.is_empty():
				var roll := _rng.randi_range(1, 100)
				if StitchedS1BEffects.percent_roll_succeeds(roll, 30):
					var candidate: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
					var results := _legal_targets(hero, candidate["ability"], int(candidate["rank"]))
					var receipt := _resolve_ability(hero, candidate["ability"], results, str(candidate["part"]))
					_turn_events.append({"actor": id, "mood": mood, "action": "ability", "roll": roll, "receipt": receipt})
					return true
	return false

func _ally_thread_blocked(actor: Dictionary, ability: Dictionary, target: Dictionary) -> bool:
	if str(ability["target_side"]) != "ally" or str(actor["side"]) != "hero":
		return false
	if str(ability["kind"]) in ["heal", "guard"] or ability["effects"].has("heal") or ability["effects"].has("guard"):
		return _crosses_cut(int(actor["rank"]), int(target["rank"]))
	return false
