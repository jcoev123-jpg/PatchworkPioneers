class_name StitchedWalkCurios
extends RefCounted
## Authored S8d choices. Awards/traps are unconsumed descriptors for S8f, never
## wallet/map writes. Each instance owns its progress; only accepted choices roll.

static var _parts: Dictionary = {}

static func parts() -> Dictionary:
	if _parts.is_empty():
		for file in DirAccess.get_files_at("res://data/parts"):
			if file.ends_with(".json"):
				var catalog := StitchedParts.load_catalog("res://data/parts/" + file)
				if not catalog.ok:
					return {}
				_parts.merge(catalog.by_id)
	return _parts

static func whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high

static func keys(value: Dictionary, required: Array) -> bool:
	if value.size() != required.size():
		return false
	for key in required:
		if not value.has(key):
			return false
	return true

static func validate(record: Dictionary, items: Array) -> bool:
	if not keys(record, ["id", "name", "kind", "rules"]) or not record.rules is Dictionary:
		return false
	var r: Dictionary = record.rules
	var fields: Array
	match record.kind:
		"pincushion": fields = ["wake_chances", "fight_chance", "fray", "loot"]
		"dummy": fields = ["mimic_chance", "parts", "glass_heads"]
		"ragbag": fields = ["bleed_chance", "bleed", "loot"]
		"patterns": fields = ["marker"]
		"door": fields = ["needle_arms", "room_curios", "loot"]
		_: return false
	if not keys(r, fields):
		return false
	for field in r:
		match field:
			"fight_chance", "mimic_chance", "bleed_chance":
				if not whole(r[field], 0, 100): return false
			"fray", "bleed":
				if not whole(r[field], 1, 100): return false
			"marker":
				if not r[field] is String or r[field].strip_edges().is_empty(): return false
			"wake_chances":
				if not r[field] is Array or r[field].is_empty(): return false
				var previous := -1
				for chance in r[field]:
					if not whole(chance, 0, 100) or chance <= previous: return false
					previous = int(chance)
			"parts", "glass_heads", "needle_arms", "room_curios":
				if not r[field] is Array or r[field].is_empty(): return false
				var seen: Array = []
				for id in r[field]:
					if not id is String or id in seen: return false
					seen.append(id)
					if field == "room_curios": continue # Cross-references checked by WalkRules.
					if not parts().has(id): return false
					if field == "glass_heads" and parts()[id].slot != "head": return false
					if field == "needle_arms" and parts()[id].slot != "arms": return false
			"loot":
				if not r.loot is Array or r.loot.is_empty(): return false
				for loot in r.loot:
					if not loot is Dictionary or not keys(loot, ["kind", "id", "amount"]): return false
					if not whole(loot.amount, 1, 100): return false
					if loot.kind in ["gold", "scraps"]:
						if loot.id != loot.kind: return false
					elif loot.kind == "pocket_item":
						if not loot.id in items or loot.amount != 1: return false
					else: return false
	return true

static func valid_doll(doll: Dictionary) -> bool:
	if not doll.get("fray", 0) is int or doll.get("fray", 0) < 0:
		return false
	if not doll.get("parts", {}) is Dictionary: return false
	for slot in doll.get("parts", {}):
		var worn: Variant = doll.parts[slot]
		if worn is Dictionary:
			if not keys(worn, ["id", "tier", "torn"]) or not whole(worn.tier, 1, 3) or not worn.torn is bool:
				return false
		var id: Variant = worn.get("id") if worn is Dictionary else worn
		if not id is String or not parts().has(id) or parts()[id].slot != slot: return false
	return true

static func capable(doll: Dictionary, ids: Array, slot: String) -> bool:
	var worn: Variant = doll.get("parts", {}).get(slot, "")
	if worn is Dictionary:
		return not worn.torn and worn.id in ids
	return worn in ids

static func choices(curio: Dictionary, record: Dictionary, doll: Dictionary) -> Array:
	var result: Array = ["leave"]
	match record.kind:
		"pincushion": result.append("pull")
		"dummy":
			result.append("take")
			if not curio.has("mimic") and capable(doll, record.rules.glass_heads, "head"): result.append("inspect")
		"ragbag": result.append("reach")
		"patterns": result.append("read")
		"door":
			if capable(doll, record.rules.needle_arms, "arms"): result.append("unpick")
	return result

static func pending(state: Dictionary, curio: Dictionary, kind: String, effects: Dictionary, target: String = "") -> void:
	state.pending.append({"kind": kind, "source": curio.instance, "target": target,
		"consumed": false, "effects": effects.duplicate(true)})

static func protected_by_pins(state: Dictionary, curio: Dictionary) -> bool:
	for effect in state.pending:
		if effect.kind == "pins" and effect.target == curio.instance and not effect.consumed:
			effect.consumed = true
			return true
	return false

static func protected_by_dye(state: Dictionary, actor: String) -> bool:
	for effect in state.pending:
		if effect.kind == "dye" and effect.target == actor and effect.effects.get("skip_one_curio_trap", false):
			effect.effects.skip_one_curio_trap = false
			return true # Retain its separate next-fight effect.
	return false

static func protected(state: Dictionary, curio: Dictionary, actor: String, pins_only: bool = false) -> bool:
	if protected_by_pins(state, curio):
		return true
	if pins_only:
		return false
	return protected_by_dye(state, actor)

static func loot(state: Dictionary, curio: Dictionary, table: Array, rng: RandomNumberGenerator) -> void:
	pending(state, curio, "curio_loot", table[rng.randi_range(0, table.size() - 1)])

static func resolve(state: Dictionary, curio: Dictionary, record: Dictionary, choice: String,
		rng: RandomNumberGenerator, events: Array) -> void:
	var actor: String = state.viewpoint
	var r: Dictionary = record.rules
	curio.resolved = true
	if choice != "leave":
		match record.kind:
			"pincushion":
				var pulls: int = curio.get("pulls", 0)
				var wake: bool = rng.randi_range(1, 100) <= r.wake_chances[pulls]
				curio.pulls = pulls + 1
				if wake and not protected(state, curio, actor):
					if rng.randi_range(1, 100) <= r.fight_chance:
						pending(state, curio, "curio_fight", {"encounter": "awakened_pincushion"}, actor)
					else:
						for doll in state.dolls:
							if doll.id == actor: doll.fray = doll.get("fray", 0) + int(r.fray)
						pending(state, curio, "curio_fray", {"amount": int(r.fray), "already_applied": true}, actor)
				else:
					loot(state, curio, r.loot, rng)
					curio.resolved = curio.pulls >= r.wake_chances.size()
			"dummy":
				if not curio.has("mimic"): curio.mimic = rng.randi_range(1, 100) <= r.mimic_chance
				if choice == "inspect":
					curio.resolved = false
					events.append({"kind": "dummy_inspected", "source": curio.instance, "mimic": curio.mimic})
				elif curio.mimic and not protected(state, curio, actor):
					pending(state, curio, "curio_fight", {"encounter": "tailors_dummy_mimic"}, actor)
				else:
					pending(state, curio, "curio_part", {"id": r.parts[rng.randi_range(0, r.parts.size() - 1)], "tier": 1})
			"ragbag":
				if not protected(state, curio, actor, true):
					var bite: bool = rng.randi_range(1, 100) <= r.bleed_chance
					if bite and not protected_by_dye(state, actor):
						pending(state, curio, "curio_trap", {"status": "bleed", "amount": int(r.bleed)}, actor)
				loot(state, curio, r.loot, rng)
			"patterns": pending(state, curio, "secret_room", {"area": state.area, "marker": r.marker})
			"door":
				pending(state, curio, "side_room", {"area": state.area,
					"curio": r.room_curios[rng.randi_range(0, r.room_curios.size() - 1)]})
				loot(state, curio, r.loot, rng)
	events.append({"kind": "curio_choice", "source": curio.instance, "choice": choice, "resolved": curio.resolved})
