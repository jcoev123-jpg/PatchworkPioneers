class_name StitchedTurnStatusCues
extends RefCounted
## Pure S5 presentation of public StitchedRules.get_unit() copies.
## No battle instance, random calls, combat methods or authored-data lookups.

const PART_SLOTS := ["head", "arms", "torso", "legs"]
const RESOLVE_CUES := {
	"steadfast": "STFD",
	"frantic": "FRNT",
	"hollow": "HOLL",
	"bitter": "BITR",
	"reckless": "RECK",
	"cowering": "COWR",
}
const RESOLVE_EFFECTS := {
	"steadfast": "Steadfast: +10% damage and party -2 fray/turn until floor end (fray drops to 45).",
	"frantic": "Unravelled: on 30% of turns use a random legal ability on a random legal target; clears under 50 fray.",
	"hollow": "Unravelled: on 30% of turns forced pass; clears under 50 fray.",
	"bitter": "Unravelled: +4 fray/turn to an adjacent ally; clears under 50 fray.",
	"reckless": "Unravelled: ignore Guard and step forward when possible; clears under 50 fray.",
	"cowering": "Unravelled: step backward when possible and refuse melee abilities on 30% of turns; clears under 50 fray.",
}
const BLIND_EXPLANATION := "Blind: next attack misses; consumed on that attack."
const TANGLED_EXPLANATION := "Tangled: cannot move or be moved by its side; attacks gain +2 damage."
const MARK_EXPLANATION := "Marked: mark-hunting abilities gain their authored bonus damage."
const STUN_EXPLANATION := "Stun: skip the next turn; then briefly resist another Stun."
const GUARD_EXPLANATION := "Guard: intercept hits aimed at a chosen ally while their thread is joined."
const STUN_RESIST_EXPLANATION := "Stun Resist: blocks another Stun until this unit's next turn begins."
const RIPOSTE_EXPLANATION := "Riposte: reaction damage retaliation on a confirmed hit by a surviving target, ignoring PROT."
const THORNS_EXPLANATION := "Thorns: reaction damage retaliation on a confirmed hit by a surviving target, ignoring PROT."
const WEAK_EXPLANATION := "Weak: outgoing direct attack damage -25% (rounded down)."
const EXPOSED_EXPLANATION := "Exposed: incoming direct attack damage +50% (rounded down)."
const COMBINED_WEAK_EXPOSED_EXPLANATION := "With Weak on the attacker and Exposed on the target, apply combined x9/8 once, rounded down before Tangled/PROT."


static func _number(value: Variant) -> bool:
	return value is int or value is float


static func _positive_count(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _has_valid_guard(unit: Dictionary) -> bool:
	if unit.get("side") != "hero":
		return false
	var statuses: Variant = unit.get("statuses")
	if not (statuses is Dictionary and _positive_count(statuses.get("guard"))):
		return false
	var target: Variant = unit.get("guard_target")
	if not (target is String and not str(target).strip_edges().is_empty()):
		target = statuses.get("guard_target")
	if not (target is String):
		return false
	var target_str := str(target).strip_edges()
	if target_str.is_empty():
		return false
	var unit_id: Variant = unit.get("id")
	if not (unit_id is String and not str(unit_id).strip_edges().is_empty()):
		return false
	if target_str == str(unit_id).strip_edges():
		return false
	return true


static func resolve_cue(unit: Dictionary) -> String:
	if unit.get("side") != "hero":
		return ""
	var resolve: Variant = unit.get("resolve")
	if resolve is String and RESOLVE_CUES.has(resolve):
		return str(RESOLVE_CUES[resolve])
	return ""


static func resolve_effect(unit: Dictionary) -> String:
	if unit.get("side") != "hero":
		return ""
	var resolve: Variant = unit.get("resolve")
	if resolve is String and RESOLVE_EFFECTS.has(resolve):
		return str(RESOLVE_EFFECTS[resolve])
	return ""


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
	var trait_cue := resolve_cue(unit)
	if not trait_cue.is_empty():
		return trait_cue
	if side == "hero" and _number(unit.get("fray")) and float(unit["fray"]) >= 100:
		return "FRAY"
	if statuses is Dictionary and _positive_count(statuses.get("bleed")):
		return "BLD"
	if _has_valid_guard(unit):
		return "GRD"
	if statuses is Dictionary and _positive_count(statuses.get("riposte")):
		return "RIP"
	if statuses is Dictionary and _positive_count(statuses.get("thorns")):
		return "THRN"
	if statuses is Dictionary and _positive_count(statuses.get("blind")):
		return "BLND"
	if statuses is Dictionary and _positive_count(statuses.get("tangled")):
		return "TNGL"
	if statuses is Dictionary and _positive_count(statuses.get("mark")):
		return "MARK"
	if statuses is Dictionary and _positive_count(statuses.get("weak")):
		return "WEAK"
	if statuses is Dictionary and _positive_count(statuses.get("exposed")):
		return "EXPD"
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
		if resolve is String and RESOLVE_EFFECTS.has(resolve):
			lines.append("Resolve: " + resolve)
			lines.append(str(RESOLVE_EFFECTS[resolve]))
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
		if _positive_count(raw.get("stun")):
			lines.append(STUN_EXPLANATION)
		if _positive_count(raw.get("guard")):
			lines.append(GUARD_EXPLANATION)
		if _positive_count(raw.get("stun_resist")):
			lines.append(STUN_RESIST_EXPLANATION)
		if _positive_count(raw.get("riposte")):
			lines.append(RIPOSTE_EXPLANATION)
		if _positive_count(raw.get("thorns")):
			lines.append(THORNS_EXPLANATION)
		if _positive_count(raw.get("blind")):
			lines.append(BLIND_EXPLANATION)
		if _positive_count(raw.get("tangled")):
			lines.append(TANGLED_EXPLANATION)
		if _positive_count(raw.get("mark")):
			lines.append(MARK_EXPLANATION)
		if _positive_count(raw.get("weak")):
			lines.append(WEAK_EXPLANATION)
		if _positive_count(raw.get("exposed")):
			lines.append(EXPOSED_EXPLANATION)
		if _positive_count(raw.get("weak")) and _positive_count(raw.get("exposed")):
			lines.append(COMBINED_WEAK_EXPOSED_EXPLANATION)
	return lines


static func tooltip(unit: Dictionary) -> String:
	return "\n".join(tooltip_lines(unit))
