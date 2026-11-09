class_name StitchedWalkRules
extends RefCounted
## S8a scene-free authority. start borrows a caller-seeded RNG and commits its draws
## only after validating the complete catalogs, area, roster and pocket inventory.
## Dolls require id, rank (1..4), hp, max_hp and lost=false. Extra doll fields survive.
## Pockets map every doll id to an array of at most two item ids (duplicates allowed).
## snapshot returns detached state. act requires the entire expected snapshot and an
## exact command dictionary. Every command names its actor (the current viewpoint).
## Commands: forward/look_back {kind, actor}, switch {kind, actor, target},
## use_item {kind, actor, slot, target}, snip {kind, actor, target}. Item targets are dolls, except pins which
## target the current step's curio instance. Receipts report ok/error, events and
## the resulting snapshot. Rejected commands never spend items or draw randomness.
## S8d: curio {kind, actor, target: instance, choice}; curio_choices lists legal
## choices. Each accepted interaction costs 5 WHIRR. Curios occupy positions
## 0..steps-1, before the final forward exits. Awards/rooms/traps await S8f.
## Opt-in S8c schedules one possible mimic at start; SNIP adds 5 WHIRR. Wrong SNIP
## adds 20 fray and queues a cut until re-tied. Local pins/dye protection is spent
## by curio traps; this service never starts combat or settles run/map awards.
## S8e: default-off tug schedules one required resolution at a traversable step.
## Yield tears one random intact worn rear-doll part; torn_part descriptors retain
## its identity/tier for later mending. No equipped part means a harmless resolution.
## Default-off mannequins schedule a possible trailing witness after earlier opt-ins;
## three accepted LOOK BACK actions from its step queue one future rear encounter.

const ITEMS := ["thimble_tonic", "fresh_stuffing", "starch", "dye", "pins", "spare_spool"]
const CURIO_KINDS := ["pincushion", "dummy", "ragbag", "patterns", "door"]
const HORROR_KINDS := ["mimic", "machine", "stitches", "tug", "mannequins"]
const Curios = preload("res://scripts/stitched/walk/stitched_walk_curios.gd")

var _rng: RandomNumberGenerator
var _state: Dictionary = {}
var _curio_catalog: Dictionary = {}
## Owned by the Walk, so separate bridge instances cannot consume it twice.
var _battle_consumed := false


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
		catalogs: Variant = null, enable_mimic: bool = false, enable_tug: bool = false,
		enable_mannequins: bool = false, enable_stitches: bool = false) -> StitchedWalkRules:
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
	# Encounters occupy traversable positions, including the entrance and the
	# final position before the exit. The exit itself is never interactive.
	var free_steps: Array = range(0, int(corridor.steps))
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
	for record in catalogs.curios:
		service._curio_catalog[record.id] = record.duplicate(true)
	service._state = {"revision": 0, "phase": "walking", "area": area, "corridor": corridor,
		"step": 0, "curios": placed, "dolls": ranked, "pockets": pockets.duplicate(true),
		"viewpoint": ranked[0].id, "looking_back": false, "whirr": 0, "warning": false,
		"pending": [], "rng": trial.state}
	if enable_mimic:
		var authored: Dictionary = {}
		for horror in catalogs.horrors:
			if horror.id == "extra_thread_shadow" and horror.kind == "mimic":
				authored = horror
		if authored.is_empty() or service._doll(authored.id) >= 0:
			return null
		for doll in ranked:
			if not doll.get("fray", 0) is int or doll.get("fray", 0) < 0:
				return null
		var present := trial.randi_range(0, 1) == 1
		service._state.shadow = {"id": authored.id, "name": authored.name, "present": present,
			"step": trial.randi_range(0, int(corridor.steps) - 1),
			"disguise": ranked[trial.randi_range(1, 3)].id, "revealed": false, "snipped": false,
			"removed": false, "art_path": "res://assets/paper/walk/extra_thread_shadow.png"}
		service._state.rng = trial.state
	if enable_tug:
		var authored: Dictionary = {}
		for horror in catalogs.horrors:
			if horror.id == "thread_tug" and horror.kind == "tug":
				authored = horror
		if authored.is_empty() or service._doll(authored.id) >= 0:
			return null
		service._state.tug = {"id": authored.id, "name": authored.name,
			"step": trial.randi_range(0, int(corridor.steps) - 1), "resolved": false}
		service._state.rng = trial.state
	if enable_mannequins:
		var authored: Dictionary = {}
		for horror in catalogs.horrors:
			if horror.id == "following_forms" and horror.kind == "mannequins":
				authored = horror
		if authored.is_empty() or service._doll(authored.id) >= 0:
			return null
		service._state.mannequins = {"id": authored.id, "name": authored.name,
			"present": trial.randi_range(0, 1) == 1,
			"step": trial.randi_range(0, int(corridor.steps) - 1), "stage": 0}
		service._state.rng = trial.state
	if enable_stitches:
		var authored: Dictionary = RunStitchedCrawlingStitchesEvent.find_horror_by_id(catalogs.horrors, RunStitchedCrawlingStitchesEvent.HORROR_ID)
		if authored.is_empty() or service._doll(authored.id) >= 0:
			return null
		var preview := RunStitchedCrawlingStitchesEvent.preview(authored, ranked[0])
		if not bool(preview.get("ok", false)):
			return null
		var resolved: Dictionary
		if bool(preview.get("eligible", false)):
			var roll := trial.randi_range(1, 100)
			resolved = RunStitchedCrawlingStitchesEvent.resolve(authored, ranked[0], roll)
		else:
			resolved = RunStitchedCrawlingStitchesEvent.resolve(authored, ranked[0])
		if not bool(resolved.get("ok", false)):
			return null
		var stitches_state: Dictionary = resolved.duplicate(true)
		stitches_state["id"] = authored.id
		stitches_state["name"] = authored.name
		service._state.stitches = stitches_state
		if bool(stitches_state.get("wrong_turn", false)):
			service._state.corridor.steps = int(service._state.corridor.steps) + int(stitches_state.get("extra_steps", 2))
		service._state.rng = trial.state
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
			if not record is Dictionary:
				return false
			if group == "curios" and not Curios.validate(record, ITEMS):
				return false
			if group == "horrors" and not _keys(record, ["id", "name", "kind"]):
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
	for record in catalogs.curios:
		if record.kind == "door":
			for id in record.rules.room_curios:
				if not id in curio_ids or id == record.id:
					return false
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
		if not Curios.valid_doll(doll):
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
		"tug":
			if not tug_unresolved() or command.get("target") != _state.tug.id:
				return _receipt(false, "unavailable_tug")
			if command.get("choice") == "yield":
				if not _keys(command, ["kind", "actor", "target", "choice"]):
					return _receipt(false, "invalid_command")
			else:
				if not _keys(command, ["kind", "actor", "target", "choice", "slot"]) or not command.get("slot") is int:
					return _receipt(false, "invalid_command")
				var pocket: Array = _state.pockets[command.actor]
				if not command.choice in ["pins", "spare_spool"] or command.slot < 0 or command.slot >= pocket.size():
					return _receipt(false, "unavailable_item")
				if pocket[command.slot] != command.choice:
					return _receipt(false, "unavailable_item")
		"curio":
			if not _keys(command, ["kind", "actor", "target", "choice"]) or not _current_curio(command.get("target")):
				return _receipt(false, "invalid_curio")
			if not command.choice is String or not command.choice in curio_choices(command.target):
				return _receipt(false, "unavailable_choice")
		"snip":
			if not _keys(command, ["kind", "actor", "target"]) or not shadow_visible() or _state.shadow.snipped:
				return _receipt(false, "unavailable_snip")
			if command.target != _state.shadow.id and (_doll(command.target) < 0 or command.target == command.actor):
				return _receipt(false, "invalid_target")
		"forward", "look_back":
			if not _keys(command, ["kind", "actor"]):
				return _receipt(false, "invalid_command")
			if kind == "forward":
				if tug_unresolved():
					return _receipt(false, "unresolved_tug")
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
	# All validation precedes the first mutation; only accepted resolutions roll.
	var events: Array = []
	match kind:
		"tug":
			_state.tug.resolved = true
			if command.choice == "yield":
				_tear_rear_part(events)
			else:
				_state.pockets[command.actor].remove_at(command.slot)
				events.append({"kind": "tug_saved", "source": _state.tug.id,
					"actor": command.actor, "item": command.choice})
			_state.rng = _rng.state
		"curio":
			for curio in _state.curios:
				if curio.instance == command.target:
					Curios.resolve(_state, curio, _curio_catalog[curio.id], command.choice, _rng, events)
			_state.rng = _rng.state
		"snip":
			_state.shadow.snipped = true
			if command.target == _state.shadow.id:
				_state.shadow.removed = true
				events.append({"kind": "mimic_removed", "target": command.target})
			else:
				var doll: Dictionary = _state.dolls[_doll(command.target)]
				doll.fray = doll.get("fray", 0) + 20
				_state.pending.append({"kind": "cut_thread", "target": command.target,
					"source": _state.shadow.id, "consumed": false, "effects": {"until_re_tied": true}})
				events.append({"kind": "wrong_snip", "target": command.target, "fray": 20})
		"forward":
			_state.step += 1
			_state.looking_back = false
			if _state.step == int(_state.corridor.steps):
				_state.phase = "complete"
				if _state.has("shadow") and _state.shadow.present and not _state.shadow.removed:
					_state.pending.append({"kind": "mimic", "source": _state.shadow.id, "consumed": false,
						"effects": {"next_fight": true, "position": "party_back_rank", "round": 1,
							"sequence": ["attack", "flee"]}})
					events.append({"kind": "mimic_pending"})
		"look_back":
			_state.looking_back = true
			if mannequins_visible() and _state.mannequins.stage < 3:
				_state.mannequins.stage += 1
				events.append({"kind": "mannequins_stage", "source": _state.mannequins.id,
					"stage": _state.mannequins.stage})
				if _state.mannequins.stage == 3:
					_state.pending.append({"kind": "mannequins", "source": _state.mannequins.id,
						"consumed": false, "effects": {"next_fight": true,
							"position": "party_back_rank"}})
					events.append({"kind": "mannequins_pending", "source": _state.mannequins.id})
			if shadow_visible():
				_state.shadow.revealed = true
				events.append({"kind": "shadow_revealed", "shadow": _state.shadow.duplicate(true), "targets": snip_targets()})
		"switch":
			_state.viewpoint = command.target
			_state.looking_back = false
		"use_item":
			_state.pockets[command.actor].remove_at(command.slot)
			if effect.item in ["thimble_tonic", "fresh_stuffing"]:
				var doll: Dictionary = _state.dolls[_doll(effect.target)]
				var percent := 35 if effect.item == "fresh_stuffing" else 15
				# Whole HP rounds down, matching percentage healing in run visits.
				var base_heal := floori(doll.max_hp * percent / 100.0)
				# S15 Rot on the recipient halves the base heal (rounded down) before the
				# missing-HP cap. Rot is only read: it is never consumed or changed here.
				var statuses: Variant = doll.get("statuses")
				if statuses is Dictionary and int(statuses.get("rot", 0)) > 0:
					base_heal = floori(base_heal / 2.0)
				var healed := mini(doll.max_hp - doll.hp, base_heal)
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


## Presence marks the trailing witness; this service never spawns battle foes.
func mannequins_visible() -> bool:
	return _state.has("mannequins") and _state.phase == "walking" \
		and _state.mannequins.present and _state.step >= _state.mannequins.step


func shadow_visible() -> bool:
	return _state.has("shadow") and _state.phase == "walking" and _state.looking_back \
		and _state.shadow.present and not _state.shadow.removed and _state.step >= _state.shadow.step


## Tug commands: {kind: tug, actor, target: thread_tug, choice: yield}, or
## choice: pins/spare_spool with the actual actor's integer pocket slot.
func tug_unresolved() -> bool:
	return _state.has("tug") and _state.phase == "walking" \
		and _state.step == _state.tug.step and not _state.tug.resolved


func stitches_cue_visible() -> bool:
	return _state.has("stitches") and _state.phase == "walking" and bool(_state.stitches.get("cue", false))


func stitches_cue() -> bool:
	return _state.has("stitches") and bool(_state.stitches.get("cue", false))


func _tear_rear_part(events: Array) -> void:
	var rear: Dictionary = {}
	for doll in _state.dolls:
		if not doll.lost and (rear.is_empty() or doll.rank > rear.rank):
			rear = doll
	var slots: Array = []
	if not rear.is_empty():
		for slot in rear.get("parts", {}):
			var worn: Variant = rear.parts[slot]
			if not worn is Dictionary or not worn.torn:
				slots.append(slot)
	slots.sort()
	if slots.is_empty():
		events.append({"kind": "tug_no_part", "source": _state.tug.id})
		return
	var slot: String = slots[_rng.randi_range(0, slots.size() - 1)]
	var worn: Variant = rear.parts[slot]
	# String equipment IDs are genuine tier-one parts, also accepted by curios.
	if worn is String:
		worn = {"id": worn, "tier": 1, "torn": false}
		rear.parts[slot] = worn
	worn.torn = true
	var descriptor := {"kind": "torn_part", "source": _state.tug.id, "target": rear.id,
		"consumed": false, "effects": {"slot": slot, "part": worn.duplicate(true),
			"mendable": true, "already_applied": true}}
	_state.pending.append(descriptor)
	events.append({"kind": "tug_torn", "source": _state.tug.id, "target": rear.id,
		"slot": slot, "part": worn.duplicate(true)})


func snip_targets() -> Array:
	if not shadow_visible() or _state.shadow.snipped:
		return []
	var targets: Array = []
	for doll in _state.dolls:
		if doll.id != _state.viewpoint and not doll.lost:
			targets.append(doll.id)
	targets.append(_state.shadow.id)
	return targets


func _doll(id: Variant) -> int:
	for index in _state.dolls.size():
		if _state.dolls[index].id == id and not _state.dolls[index].lost:
			return index
	return -1


func _current_curio(id: Variant) -> bool:
	for curio in _state.curios:
		if curio.instance == id and curio.step == _state.step and not curio.get("resolved", false):
			return true
	return false


## Detached legal choices derived from the authoritative equipped part IDs.
func curio_choices(instance: String) -> Array:
	if _state.is_empty() or _state.phase != "walking" or not _current_curio(instance):
		return []
	for curio in _state.curios:
		if curio.instance == instance:
			return Curios.choices(curio, _curio_catalog[curio.id], _state.dolls[_doll(_state.viewpoint)])
	return []


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


## Claim the one-shot Machine horror toll once from a completed Walk.
## Preconditions: started real Walk, matching expected snapshot, matching RNG state,
## phase complete, WHIRR 100, exactly one authentic unconsumed Machine pending descriptor.
## Returns detached authoritative receipt for +1 foe in next fight and +10 fray per doll.
func claim_machine_toll(expected: Dictionary) -> Dictionary:
	if _state.is_empty() or _rng == null:
		return _claim_receipt(false, "not_started")
	if expected != _state or _rng.state != _state.get("rng"):
		return _claim_receipt(false, "stale_snapshot")
	if _state.get("phase") != "complete":
		return _claim_receipt(false, "walk_incomplete")
	if _state.get("whirr") != 100:
		return _claim_receipt(false, "whirr_below_100")
	var machine_descriptors: Array = []
	for effect in _state.get("pending", []):
		if effect is Dictionary and effect.get("kind") == "machine":
			machine_descriptors.append(effect)
	if machine_descriptors.size() != 1:
		return _claim_receipt(false, "invalid_machine_descriptor")
	var machine_effect: Dictionary = machine_descriptors[0]
	if machine_effect.get("consumed") != false:
		return _claim_receipt(false, "machine_already_consumed")
	var expected_effects := {"next_fight_extra_foes": 1, "party_fray": 10}
	if machine_effect.get("effects") != expected_effects:
		return _claim_receipt(false, "invalid_machine_effects")
	if not _keys(machine_effect, ["kind", "consumed", "effects"]):
		return _claim_receipt(false, "invalid_machine_descriptor")
	if not _state.get("dolls") is Array or _state.dolls.size() != 4:
		return _claim_receipt(false, "invalid_party")
	var targets: Array = []
	for doll in _state.dolls:
		if not doll is Dictionary or not _text(doll.get("id")) or doll.id in targets:
			return _claim_receipt(false, "invalid_party")
		targets.append(doll.id)
	machine_effect.consumed = true
	_state.revision += 1
	return _claim_receipt(true, "", targets)


## Claim the one-shot Mannequins horror encounter once from a completed Walk.
## Preconditions: started real Walk, matching expected snapshot, matching RNG state,
## phase complete, authored following_forms mannequin schedule present and at stage 3,
## exactly one authentic unconsumed Mannequins pending descriptor.
## Returns detached authoritative receipt for next fight back-rank encounter.
func claim_mannequins_encounter(expected: Dictionary) -> Dictionary:
	if _state.is_empty() or _rng == null:
		return _mannequins_receipt(false, "not_started")
	if expected != _state or _rng.state != _state.get("rng"):
		return _mannequins_receipt(false, "stale_snapshot")
	if _state.get("phase") != "complete":
		return _mannequins_receipt(false, "walk_incomplete")
	if not _state.has("mannequins") or not _state.mannequins is Dictionary:
		return _mannequins_receipt(false, "mannequins_not_scheduled")
	var mannequins: Dictionary = _state.mannequins
	if mannequins.get("id") != "following_forms":
		return _mannequins_receipt(false, "invalid_mannequins_schedule")
	if not mannequins.get("present", false):
		return _mannequins_receipt(false, "mannequins_not_present")
	if mannequins.get("stage") != 3:
		return _mannequins_receipt(false, "mannequins_stage_incomplete")
	if not _state.get("dolls") is Array or _state.dolls.size() != 4:
		return _mannequins_receipt(false, "invalid_party")
	var targets: Array = []
	for doll in _state.dolls:
		if not doll is Dictionary or not _text(doll.get("id")) or doll.id in targets:
			return _mannequins_receipt(false, "invalid_party")
		targets.append(doll.id)
	var mannequin_descriptors: Array = []
	for effect in _state.get("pending", []):
		if effect is Dictionary and effect.get("kind") == "mannequins":
			mannequin_descriptors.append(effect)
	if mannequin_descriptors.size() != 1:
		return _mannequins_receipt(false, "invalid_mannequins_descriptor")
	var mannequin_effect: Dictionary = mannequin_descriptors[0]
	if mannequin_effect.get("consumed") != false:
		return _mannequins_receipt(false, "mannequins_already_consumed")
	if mannequin_effect.get("source") != "following_forms":
		return _mannequins_receipt(false, "invalid_mannequins_source")
	var expected_effects := {"next_fight": true, "position": "party_back_rank"}
	if mannequin_effect.get("effects") != expected_effects:
		return _mannequins_receipt(false, "invalid_mannequins_effects")
	if not _keys(mannequin_effect, ["kind", "source", "consumed", "effects"]):
		return _mannequins_receipt(false, "invalid_mannequins_descriptor")
	mannequin_effect.consumed = true
	_state.revision += 1
	return _mannequins_receipt(true, "")


## Claim the one-shot Pincushion fray consequence once from a completed Walk.
## Preconditions: started real Walk, matching expected snapshot, matching RNG state,
## phase complete, scheduled curio pin_nest with matching instance, exactly one matching
## unconsumed curio_fray pending descriptor with authentic doll target and already-applied +15 fray.
## Returns detached authoritative receipt. Does not re-apply fray or draw RNG.
func claim_pincushion_fray(expected: Dictionary, curio_instance: String) -> Dictionary:
	if _state.is_empty() or _rng == null:
		return _pincushion_fray_receipt(false, "not_started")
	if expected != _state or _rng.state != _state.get("rng"):
		return _pincushion_fray_receipt(false, "stale_snapshot")
	if _state.get("phase") != "complete":
		return _pincushion_fray_receipt(false, "walk_incomplete")
	if not _text(curio_instance):
		return _pincushion_fray_receipt(false, "invalid_curio_instance")
	var found_curio: Dictionary = {}
	for curio in _state.get("curios", []):
		if curio is Dictionary and curio.get("instance") == curio_instance:
			found_curio = curio
			break
	if found_curio.is_empty():
		return _pincushion_fray_receipt(false, "curio_not_found")
	if found_curio.get("id") != "pin_nest":
		return _pincushion_fray_receipt(false, "curio_not_pincushion")
	var matching_fray: Array = []
	var already_consumed := false
	var has_conflict := false
	for effect in _state.get("pending", []):
		if not effect is Dictionary:
			continue
		if effect.get("source") == curio_instance:
			if effect.get("kind") == "curio_fray":
				if effect.get("consumed") == true:
					already_consumed = true
				matching_fray.append(effect)
			elif effect.get("kind") == "curio_fight":
				has_conflict = true
	if already_consumed:
		return _pincushion_fray_receipt(false, "already_consumed")
	if has_conflict:
		return _pincushion_fray_receipt(false, "conflicting_curio_descriptors")
	if matching_fray.is_empty():
		return _pincushion_fray_receipt(false, "no_pincushion_fray_outcome")
	if matching_fray.size() != 1:
		return _pincushion_fray_receipt(false, "duplicate_curio_fray_descriptor")
	var fray_desc: Dictionary = matching_fray[0]
	if fray_desc.get("consumed") != false:
		return _pincushion_fray_receipt(false, "already_consumed")
	if not _keys(fray_desc, ["kind", "source", "target", "consumed", "effects"]):
		return _pincushion_fray_receipt(false, "invalid_descriptor_shape")
	if fray_desc.get("effects") != {"amount": 15, "already_applied": true}:
		return _pincushion_fray_receipt(false, "invalid_curio_fray_effects")
	var target_id: Variant = fray_desc.get("target")
	if not _text(target_id):
		return _pincushion_fray_receipt(false, "invalid_target_doll")
	var doll_index := _doll(target_id)
	if doll_index < 0:
		return _pincushion_fray_receipt(false, "invalid_target_doll")
	var doll: Dictionary = _state.dolls[doll_index]
	if not doll.get("fray") is int or doll.fray < 15:
		return _pincushion_fray_receipt(false, "doll_fray_missing_consequence")
	fray_desc.consumed = true
	_state.revision += 1
	return _pincushion_fray_receipt(true, "", curio_instance, String(target_id))


func _pincushion_fray_receipt(ok: bool, error: String, source: String = "", target: String = "") -> Dictionary:
	var snap := snapshot()
	if not ok:
		return {
			"ok": false,
			"error": error,
			"reason": error,
			"kind": "curio_fray",
			"source": "",
			"target": "",
			"fray_delta": 0,
			"amount": 0,
			"fray": 0,
			"already_applied": false,
			"effects": {},
			"snapshot": snap,
		}
	return {
		"ok": true,
		"error": "",
		"reason": "",
		"kind": "curio_fray",
		"source": source,
		"target": target,
		"fray_delta": 15,
		"amount": 15,
		"fray": 15,
		"already_applied": true,
		"effects": {
			"amount": 15,
			"already_applied": true,
		},
		"snapshot": snap,
	}


func _claim_receipt(ok: bool, error: String, targets: Array = []) -> Dictionary:
	var snap := snapshot()
	if not ok:
		return {
			"ok": false,
			"error": error,
			"snapshot": snap,
			"source": "",
			"horror": "",
			"horror_id": "",
			"next_fight_extra_foes": 0,
			"extra_foes": 0,
			"reinforcements": 0,
			"party_fray": 0,
			"fray": 0,
			"targets": [],
			"dolls": [],
			"fray_targets": [],
			"effects": {},
		}
	var copied_targets := targets.duplicate(true)
	return {
		"ok": true,
		"error": "",
		"snapshot": snap,
		"source": "hungry_machine",
		"horror": "hungry_machine",
		"horror_id": "hungry_machine",
		"next_fight_extra_foes": 1,
		"extra_foes": 1,
		"reinforcements": 1,
		"party_fray": 10,
		"fray": 10,
		"targets": copied_targets,
		"dolls": copied_targets.duplicate(true),
		"fray_targets": copied_targets.duplicate(true),
		"effects": {
			"next_fight_extra_foes": 1,
			"party_fray": 10,
			"targets": copied_targets.duplicate(true),
		},
	}


func _mannequins_receipt(ok: bool, error: String) -> Dictionary:
	var snap := snapshot()
	if not ok:
		return {
			"ok": false,
			"error": error,
			"snapshot": snap,
			"kind": "mannequins",
			"source": "",
			"horror": "",
			"horror_id": "",
			"next_fight": false,
			"position": "",
			"effects": {},
		}
	return {
		"ok": true,
		"error": "",
		"snapshot": snap,
		"kind": "mannequins",
		"source": "following_forms",
		"horror": "following_forms",
		"horror_id": "following_forms",
		"next_fight": true,
		"position": "party_back_rank",
		"effects": {
			"next_fight": true,
			"position": "party_back_rank",
		},
	}
