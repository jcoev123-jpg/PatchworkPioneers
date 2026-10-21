class_name RunRestPatchResewOptions
extends RefCounted
## Read-only Rest option projector. Only the run owner can commit a choice.
## All accepted inputs must be current service snapshots, not UI claims.

const HERO_IDS := ["warden", "seamstress", "tinker"]
const SLOTS := ["HEAD", "ARM", "COAT"]


static func project(wardrobe: RunPatchWardrobe, torn: RunTornMending,
		exact_snapshot: Variant, rest_node_id: Variant) -> Dictionary:
	var denied := {"ok": false, "options": [], "scraps": 0, "rest_node_id": ""}
	if wardrobe == null or torn == null or not wardrobe.is_valid() or not torn.is_valid():
		return denied
	if typeof(exact_snapshot) != TYPE_DICTIONARY or not RunPatchWardrobe._id(rest_node_id):
		return denied
	var current := wardrobe.get_snapshot()
	if exact_snapshot != current or current.get("valid") != true:
		return denied
	if current.get("rest_id") != rest_node_id or not current.get("rest_ids", []).has(rest_node_id):
		return denied
	if typeof(current.get("scraps")) != TYPE_INT or current["scraps"] < 1:
		return denied
	var torn_state := torn.read_state()
	var heroes: Variant = torn_state.get("heroes")
	if torn_state.get("ok") != true or not RunPatchWardrobe._valid_roster(heroes, false):
		return denied
	if heroes != current.get("heroes"):
		return denied
	var worn: Variant = current.get("worn")
	var owned: Variant = current.get("owned")
	var definitions: Variant = current.get("definitions")
	if typeof(worn) != TYPE_DICTIONARY or worn.size() != 3 \
			or typeof(owned) != TYPE_ARRAY or typeof(definitions) != TYPE_DICTIONARY:
		return denied
	var active := wardrobe.project_active(torn_state)
	if active.get("ok") != true or active.get("worn") != worn:
		return denied
	var seen := {}
	for hero_id in HERO_IDS:
		if typeof(worn.get(hero_id)) != TYPE_DICTIONARY or worn[hero_id].size() != 3:
			return denied
		for slot in SLOTS:
			var id: Variant = worn[hero_id].get(slot)
			if typeof(id) != TYPE_STRING:
				return denied
			if id == "":
				continue
			if seen.has(id) or not owned.has(id) or definitions.get(id) != slot:
				return denied
			seen[id] = true
	var options := []
	for from_id in HERO_IDS:
		var from_alive: bool = _alive(heroes, from_id)
		for slot in SLOTS:
			var patch_id: String = worn[from_id][slot]
			if patch_id == "":
				continue
			for to_id in HERO_IDS:
				if to_id == from_id:
					continue
				var exchanged: String = worn[to_id][slot]
				options.append({
					"patch_id": patch_id, "from_hero": from_id, "to_hero": to_id,
					"slot": slot, "kind": "MOVE" if exchanged == "" else "SWAP",
					"exchanged_id": exchanged, "cost": 1,
					"source_active": from_alive,
					"destination_active": _alive(heroes, to_id),
					"exchanged_active": exchanged != "" and _alive(heroes, to_id)
				})
	return {"ok": true, "options": options.duplicate(true),
		"scraps": current["scraps"], "rest_node_id": rest_node_id}


static func _alive(heroes: Array, hero_id: String) -> bool:
	for hero in heroes:
		if hero["id"] == hero_id:
			return hero["hp"] > 0
	return false
