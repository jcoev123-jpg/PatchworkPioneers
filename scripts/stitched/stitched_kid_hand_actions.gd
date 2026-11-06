class_name StitchedKidHandActions
extends RefCounted
## Design v4 S9a: Wren's four free hand actions (data/kid/hand_actions.json).
##
## The catalog is data; StitchedRules owns every effect, the round budget and the seeded
## shaky-hands roll (StitchedRules.use_hand_action). This helper loads and validates the
## catalog and lists the legal choices for a battle without changing it.

const PATH := "res://data/kid/hand_actions.json"
const IDS := ["steady", "shield_candle", "hold_back", "lift"]

static var _cache: Dictionary = {}


## {"ok": true, "by_id": {id: action}, "order": [ids]} or {"ok": false, "error": ...}.
static func catalog() -> Dictionary:
	if _cache.is_empty():
		_cache = _load(PATH)
	return _cache.duplicate(true)


static func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "missing " + path}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return validate(parsed)


static func validate(document: Variant) -> Dictionary:
	if not document is Dictionary or not document.get("actions") is Array:
		return {"ok": false, "error": "hand actions need an actions array"}
	var by_id := {}
	var order: Array = []
	for entry in document.actions:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String \
				or not entry.get("text") is String or not entry.get("target") in ["doll", "none"]:
			return {"ok": false, "error": "malformed hand action"}
		if not entry.id in IDS or by_id.has(entry.id):
			return {"ok": false, "error": "unknown or repeated hand action " + str(entry.id)}
		if entry.id == "steady" and (not entry.get("fray") is float and not entry.get("fray") is int or int(entry.fray) >= 0):
			return {"ok": false, "error": "Steady needs a negative fray amount"}
		by_id[entry.id] = entry.duplicate(true)
		order.append(entry.id)
	if order.size() != IDS.size():
		return {"ok": false, "error": "Wren has exactly four hand actions"}
	return {"ok": true, "by_id": by_id, "order": order}


## Every legal [action, target hero id, direction] the battle accepts right now, in catalog
## order, heroes by rank. Empty when the round's hand action is spent or a doll has acted.
static func choices(rules: StitchedRules) -> Array:
	var out: Array = []
	var book := catalog()
	if not bool(book.get("ok", false)) or not rules.hand_action_open():
		return out
	for id in book.order:
		if book.by_id[id].target == "none":
			if rules.hand_action_check(id, "", 0).is_empty():
				out.append({"action": id, "target": "", "direction": 0})
			continue
		for hero in rules.get_heroes():
			for direction in ([-1, 1] if id == "lift" else [0]):
				if rules.hand_action_check(id, str(hero.id), direction).is_empty():
					out.append({"action": id, "target": str(hero.id), "direction": direction})
	return out
