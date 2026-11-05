class_name StitchedPartActionCues
extends RefCounted
## Read-only wording for the active hero's worn, validated, tier-adjusted part.
## The caller owns all combat gates; this helper never selects or resolves actions.

const ROMAN := {1: "I", 2: "II", 3: "III"}


static func format_action(actor: Dictionary, slot: String, worn: Dictionary,
		by_id: Dictionary, usable: bool, lock_reason: String) -> Dictionary:
	var heading := slot.to_upper()
	var id := str(worn.get("id", ""))
	var tier := int(worn.get("tier", 1))
	var roman := str(ROMAN.get(tier, str(tier)))
	var part: Dictionary = by_id.get(id, {})
	if id.is_empty() or part.is_empty() or str(part.get("slot", "")) != slot:
		var missing := "Unfilled" if id.is_empty() else "Unknown worn part"
		var title := "%s · %s" % [heading, missing]
		var reason := lock_reason if not lock_reason.is_empty() else "No equipped ability"
		var full := "%s\n%s\nLOCKED: %s" % [title, "ID: " + id if not id.is_empty() else "No worn part", reason]
		return {"title": title, "digest": missing + " · LOCKED", "full": full,
			"usable": false, "part_id": id, "tier": tier}
	var ability := StitchedParts.ability_at_tier(part, tier)
	var stat := StitchedParts.stat_at_tier(part, tier)
	var title := ("%s %s · TORN · %s" if bool(worn.get("torn", false)) else "%s %s · %s") % [heading, roman, str(part["name"])]
	var stat_rows: Array[String] = []
	for key in StitchedParts.SLOT_STATS[slot]:
		if stat.has(key):
			stat_rows.append("%s %+d" % [str(key).to_upper(), int(stat[key])])
	var dmg: Array = ability.get("dmg", [0, 0])
	var effects: Dictionary = ability.get("effects", {})
	var effect_rows: Array[String] = []
	var effect_keys := effects.keys()
	effect_keys.sort()
	for key in effect_keys:
		effect_rows.append("%s %d" % [str(key).to_upper(), int(effects[key])])
	var move_step := int(ability.get("self_move", 0))
	var move_text := "toward front (-1)" if move_step == -1 else ("toward back (+1)" if move_step == 1 else "none (0)")
	var part_text := str(part.get("tiers", {}).get(str(tier), {}).get("text", part.get("text", "")))
	var rank := int(actor.get("rank", 0))
	var status := "READY" if usable else "LOCKED: " + (lock_reason if not lock_reason.is_empty() else "Unavailable")
	# One line in the mounted HUD. Detailed accuracy, crit and lock reasons stay
	# verbatim in full help; the digest keeps the current tier's actionable facts.
	var summary := effect_rows.duplicate()
	if int(dmg[1]) > 0:
		summary.push_front("DMG %d–%d" % [int(dmg[0]), int(dmg[1])])
	if int(ability.get("mark_damage", 0)) > 0:
		summary.append("MARK DMG +%d" % int(ability["mark_damage"]))
	if move_step != 0:
		summary.append("STEP FRONT" if move_step < 0 else "STEP BACK")
	var digest := "%s %s · %sLAUNCH R%s → %s R%s%s · %s" % [
		str(ability.get("name", "")), roman,
		", ".join(summary) + " · " if not summary.is_empty() else "",
		_ranks(ability.get("launch", [])), str(ability.get("target_side", "")).to_upper(),
		_ranks(ability.get("target", [])), " ALL" if bool(ability.get("multi", false)) else "",
		"READY" if usable else "LOCKED"]
	var full := "%s\nID: %s · Worn by: %s (rank %d)\nStitch stat: %s\n%s (%s) · ID: %s\n%s\nLaunch ranks: %s · Target: %s ranks %s\nMulti: %s · ACC: %d · Damage: %d–%d · Crit bonus: +%d\nEffects: %s · Mark damage: +%d\nSelf-move: %s · Pose: %s\n%s" % [
		title, id, str(actor.get("name", actor.get("id", ""))), rank,
		", ".join(stat_rows) if not stat_rows.is_empty() else "none",
		str(ability.get("name", "")), str(ability.get("kind", "")), str(ability.get("id", "")),
		part_text, _ranks(ability.get("launch", [])), str(ability.get("target_side", "")),
		_ranks(ability.get("target", [])), "yes" if bool(ability.get("multi", false)) else "no",
		int(ability.get("acc", 0)), int(dmg[0]), int(dmg[1]), int(ability.get("crit", 0)),
		", ".join(effect_rows) if not effect_rows.is_empty() else "none",
		int(ability.get("mark_damage", 0)), move_text, str(ability.get("move", "attack")), status]
	return {"title": title, "digest": digest, "full": full, "usable": usable,
		"part_id": id, "tier": tier}


static func _ranks(values: Array) -> String:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return ",".join(result)
