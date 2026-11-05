class_name StitchedWalkRules
extends RefCounted
## S8a scene-free authority. start borrows a caller-seeded RNG and commits its draws
## only after validating the complete catalogs, area, roster and pocket inventory.
## Dolls require id, rank (1..4), hp, max_hp and lost=false. Extra doll fields survive.
## Pockets map every doll id to an array of at most two item ids (duplicates allowed).
## snapshot returns detached state. act requires the entire expected snapshot and an
## exact command dictionary. Every command names its actor (the current viewpoint).
## Commands: forward/look_back {kind, actor}, switch {kind, actor, target},
## use_item {kind, actor, slot, target}. Item targets are dolls, except pins which
## target the current step's curio instance. Receipts report ok/error, events and
## the resulting snapshot. Rejected commands never spend items or draw randomness.
## Pending descriptors remain unconsumed for S8c-f. No battle/fray/curio resolution.

const ITEMS := ["thimble_tonic", "fresh_stuffing", "starch", "dye", "pins", "spare_spool"]
const CURIO_KINDS := ["pincushion", "dummy", "ragbag", "patterns", "door"]
const HORROR_KINDS := ["mimic", "machine", "stitches", "tug", "mannequins"]

var _rng: RandomNumberGenerator
var _state: Dictionary = {}


static func load_catalogs() -> Dictionary:
	var result := {}
	for key in ["corridors", "curios", "horrors"]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/walk/" + key + ".json"))
		if not parsed is Dictionary or parsed.keys() != [key] or not parsed[key] is Array:
			return {}
		result[key] = parsed[key]
	return result


## Optional catalogs support authored-data validation without touching run state.
## Failure returns null and preserves the supplied RNG and all caller-owned inputs.
static func start(random: RandomNumberGenerator, area: String, dolls: Array, pockets: Dictionary,
		catalogs: Variant = null) -> StitchedWalkRules:
	if catalogs == null:
		catalogs = load_catalogs()
	if random == null or not catalogs is Dictionary or not validate_catalogs(catalogs) or not _valid_party(dolls, pockets):
		return null
	var eligible: Array = []
	for corridor in catalogs.corridors:
		if corridor.area == area:
			eligible.append(corridor)
	if eligible.is_empty():
		return null
	var trial := RandomNumberGenerator.new()
	trial.state = random.state
	var corridor: Dictionary = eligible[trial.randi_range(0, eligible.size() - 1)].duplicate(true)
	var count := trial.randi_range(0, mini(2, corridor.curios.size()))
	var free_steps: Array = range(1, int(corridor.steps) + 1)
	var choices: Array = corridor.curios.duplicate()
	var placed: Array = []
	for index in count:
		var step_index := trial.randi_range(0, free_steps.size() - 1)
		var curio_index := trial.randi_range(0, choices.size() - 1)
		placed.append({"instance": "curio_" + str(index + 1), "id": choices[curio_index], "step": free_steps[step_index]})
		free_steps.remove_at(step_index)
		choices.remove_at(curio_index)
	var ranked := dolls.duplicate(true)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.rank < b.rank)
	var service := StitchedWalkRules.new()
	service._rng = random
	service._state = {"revision": 0, "phase": "walking", "area": area, "corridor": corridor,
		"step": 0, "curios": placed, "dolls": ranked, "pockets": pockets.duplicate(true),
		"viewpoint": ranked[0].id, "looking_back": false, "whirr": 0, "warning": false,
		"pending": [], "rng": trial.state}
	random.state = trial.state
	return service


static func validate_catalogs(catalogs: Dictionary) -> bool:
	if not _keys(catalogs, ["corridors", "curios", "horrors"]):
		return false
	for key in ["corridors", "curios", "horrors"]:
		if not catalogs[key] is Array or catalogs[key].is_empty():
			return false
	var curio_ids: Array = []
	for group in ["curios", "horrors"]:
		var ids: Array = []
		var kinds: Array = []
		for record in catalogs[group]:
			if not record is Dictionary or not _keys(record, ["id", "name", "kind"]):
				return false
			if not _text(record.id) or not _text(record.name) or record.id in ids:
				return false
			var allowed: Array = CURIO_KINDS if group == "curios" else HORROR_KINDS
			if not record.kind in allowed:
				return false
			ids.append(record.id)
			kinds.append(record.kind)
		for required in (CURIO_KINDS if group == "curios" else HORROR_KINDS):
			if not required in kinds:
				return false
		if group == "curios":
			curio_ids = ids
	var corridor_ids: Array = []
	for record in catalogs.corridors:
		if not record is Dictionary or not _keys(record, ["id", "name", "area", "steps", "curios"]):
			return false
		if not _text(record.id) or not _text(record.name) or not _text(record.area) or record.id in corridor_ids:
			return false
		if not _whole(record.steps) or record.steps < 3 or record.steps > 6 or not record.curios is Array:
			return false
		var seen: Array = []
		for id in record.curios:
			if not id in curio_ids or id in seen:
				return false
			seen.append(id)
		corridor_ids.append(record.id)
	return true


static func _valid_party(dolls: Array, pockets: Dictionary) -> bool:
	if dolls.size() != 4 or pockets.size() != 4:
		return false
	var ids: Array = []
	var ranks: Array = []
	for doll in dolls:
		if not doll is Dictionary:
			return false
		if not _text(doll.get("id")) or doll.id in ids or not doll.get("rank") is int:
			return false
		if doll.rank < 1 or doll.rank > 4 or doll.rank in ranks or not doll.get("lost") is bool or doll.lost:
			return false
		if not doll.get("hp") is int or not doll.get("max_hp") is int:
			return false
		if doll.hp < 0 or doll.max_hp <= 0 or doll.hp > doll.max_hp:
			return false
		if not pockets.get(doll.id) is Array or pockets[doll.id].size() > 2:
			return false
		for item in pockets[doll.id]:
			if not item in ITEMS:
				return false
		ids.append(doll.id)
		ranks.append(doll.rank)
	return true


static func _keys(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


func snapshot() -> Dictionary:
	return _state.duplicate(true)


func act(command: Dictionary, expected: Dictionary) -> Dictionary:
	if _state.is_empty() or _rng == null:
		return _receipt(false, "not_started")
	if expected != _state or _rng.state != _state.rng:
		return _receipt(false, "stale_snapshot")
	if _state.phase != "walking":
		return _receipt(false, "walk_complete")
	if command.get("actor") != _state.viewpoint or _doll(command.get("actor")) < 0:
		return _receipt(false, "invalid_actor")
	var kind: Variant = command.get("kind")
	var cost := 5
	var effect: Dictionary = {}
	match kind:
		"forward", "look_back":
			if not _keys(command, ["kind", "actor"]):
				return _receipt(false, "invalid_command")
			if kind == "forward":
				cost = 0
		"switch":
			if not _keys(command, ["kind", "actor", "target"]) or _doll(command.get("target")) < 0 or command.target == command.actor:
				return _receipt(false, "invalid_target")
		"use_item":
			if not _keys(command, ["kind", "actor", "slot", "target"]) or not command.get("slot") is int:
				return _receipt(false, "invalid_command")
			var pocket: Array = _state.pockets[command.actor]
			if command.slot < 0 or command.slot >= pocket.size():
				return _receipt(false, "unavailable_item")
			var item: String = pocket[command.slot]
			if item == "pins":
				if not _current_curio(command.target):
					return _receipt(false, "invalid_curio")
			elif _doll(command.target) < 0:
				return _receipt(false, "invalid_target")
			cost = 15 if item == "fresh_stuffing" else 5
			effect = {"item": item, "target": command.target}
		_:
			return _receipt(false, "invalid_command")
	# All validation precedes the first mutation. Actions require no RNG draws.
	var events: Array = []
	match kind:
		"forward":
			_state.step += 1
			_state.looking_back = false
			if _state.step == int(_state.corridor.steps):
				_state.phase = "complete"
		"look_back":
			_state.looking_back = true
		"switch":
			_state.viewpoint = command.target
			_state.looking_back = false
		"use_item":
			_state.pockets[command.actor].remove_at(command.slot)
			if effect.item in ["thimble_tonic", "fresh_stuffing"]:
				var doll: Dictionary = _state.dolls[_doll(effect.target)]
				var percent := 35 if effect.item == "fresh_stuffing" else 15
				# Whole HP rounds down, matching percentage healing in run visits.
				var healed := mini(doll.max_hp - doll.hp, floori(doll.max_hp * percent / 100.0))
				doll.hp += healed
				events.append({"kind": "heal", "target": effect.target, "amount": healed})
			else:
				var descriptor := {"kind": effect.item, "target": effect.target, "source": command.actor,
					"consumed": false, "effects": _future_effects(effect.item)}
				_state.pending.append(descriptor)
	_state.whirr = mini(100, _state.whirr + cost)
	if not _state.warning and _state.whirr >= 50:
		_state.warning = true
		events.append({"kind": "whirr_warning"})
	if _state.whirr == 100 and not _machine_pending():
		_state.pending.append({"kind": "machine", "consumed": false,
			"effects": {"next_fight_extra_foes": 1, "party_fray": 10}})
		events.append({"kind": "machine_pending"})
	_state.revision += 1
	return _receipt(true, "", events)


func _doll(id: Variant) -> int:
	for index in _state.dolls.size():
		if _state.dolls[index].id == id and not _state.dolls[index].lost:
			return index
	return -1


func _current_curio(id: Variant) -> bool:
	for curio in _state.curios:
		if curio.instance == id and curio.step == _state.step:
			return true
	return false


func _machine_pending() -> bool:
	for effect in _state.pending:
		if effect.kind == "machine":
			return true
	return false


static func _future_effects(item: String) -> Dictionary:
	match item:
		"starch": return {"next_fight_guard": true}
		"dye": return {"skip_next_fight_first_strike": true, "skip_one_curio_trap": true}
		"pins": return {"pin_shut": true}
		"spare_spool": return {"cancel_snip_or_save_tug_part": true}
	return {}


func _receipt(ok: bool, error: String, events: Array = []) -> Dictionary:
	return {"ok": ok, "error": error, "events": events.duplicate(true), "snapshot": snapshot()}
