class_name StitchedTurnStatusCues
extends RefCounted
## Pure S5 presentation of public StitchedRules.get_unit() copies.
## No battle instance, random calls, combat methods or authored-data lookups.

const PART_SLOTS := ["head", "arms", "torso", "legs"]


static func _number(value: Variant) -> bool:
	return value is int or value is float


static func _positive_count(value: Variant) -> bool:
	return value is int and int(value) > 0


static func torn_slots(unit: Dictionary) -> PackedStringArray:
	var slots := PackedStringArray()
	var raw: Variant = unit.get("parts")
	if not raw is Dictionary:
		return slots
	for slot in PART_SLOTS:
		var part: Variant = raw.get(slot)
		if part is Dictionary and part.get("torn") is bool and part["torn"]:
			slots.append(slot.capitalize())
	return slots


static func cue(unit: Dictionary) -> String:
	var side: Variant = unit.get("side")
	if unit.get("hanging") is bool and unit["hanging"]:
		return "SEAM"
	var statuses: Variant = unit.get("statuses")
	if statuses is Dictionary and _positive_count(statuses.get("stun")):
		return "STUN"
	if not torn_slots(unit).is_empty():
		return "TORN"
	if side == "hero" and _number(unit.get("fray")) and float(unit["fray"]) >= 100:
		return "FRAY"
	if side == "hero":
		return "HERO"
	if side == "foe":
		return "FOE"
	return ""


static func tooltip_lines(unit: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	var name: Variant = unit.get("name")
	if name is String and not name.is_empty():
		lines.append(name)
	elif unit.get("id") is String and not unit["id"].is_empty():
		lines.append(unit["id"])

	var side: Variant = unit.get("side")
	if side == "hero" or side == "foe":
		var header := "Hero" if side == "hero" else "Foe"
		if _number(unit.get("rank")):
			header += " rank %d" % int(unit["rank"])
		lines.append(header)

	if _number(unit.get("hp")) and _number(unit.get("max_hp")):
		lines.append("HP: %s / %s" % [str(unit["hp"]), str(unit["max_hp"])])
	var stats := PackedStringArray()
	for key in ["speed", "dodge", "prot"]:
		if _number(unit.get(key)):
			stats.append("%s: %s" % [key.to_upper(), str(unit[key])])
	if not stats.is_empty():
		lines.append("   ".join(stats))

	if side == "hero":
		if _number(unit.get("fray")):
			lines.append("FRAY: %s / 200" % str(unit["fray"]))
		var resolve: Variant = unit.get("resolve")
		if resolve is String and not resolve.is_empty():
			lines.append("Resolve: " + resolve)
		var torn := torn_slots(unit)
		if not torn.is_empty():
			lines.append("Torn parts: " + ", ".join(torn))
		if unit.get("hanging") is bool and unit["hanging"]:
			lines.append("Hanging by a Thread: another hit has 67% seam hold / 33% hero lost.")

	var raw: Variant = unit.get("statuses")
	if raw is Dictionary:
		var keys := PackedStringArray()
		for key in raw.keys():
			if key is String and _positive_count(raw[key]):
				keys.append(key)
		keys.sort()
		if not keys.is_empty():
			var active := PackedStringArray()
			for key in keys:
				active.append("%s %d" % [key, int(raw[key])])
			lines.append("Statuses: " + ", ".join(active))
	return lines


static func tooltip(unit: Dictionary) -> String:
	return "\n".join(tooltip_lines(unit))
