class_name StitchedTargetForecast
extends RefCounted
## Read-only presentation of an actual StitchedRules target set. No rolls or receipts.

static func for_rank(battle: StitchedRules, actor: Dictionary, ability: Dictionary, side: String, rank: int) -> Dictionary:
	if battle == null or not battle.is_valid() or battle.is_over():
		return {}
	if actor.is_empty() or str(actor.get("id", "")) != battle.current_actor_id() or str(actor.get("side", "")) != "hero":
		return {}
	if rank < 1 or rank > 4 or not side in ["hero", "foe"]:
		return {}
	if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))):
		return {}
	if not battle._self_move_gate(actor, ability).is_empty():
		return {}
	var targets: Array = battle._legal_targets(actor, ability, rank)
	if targets.is_empty():
		return {}
	# Multi actions can legally fan out to other ranks. The proposed rank itself
	# must still contain an actionable unit, not an empty seat or a scrap heap.
	var selected := battle._unit_at(side, rank)
	if selected.is_empty() or (side == "foe" and (bool(selected.get("dead", false)) or int(selected.get("hp", 0)) <= 0)):
		return {}
	var matches := false
	for target in targets:
		if str(target.get("id", "")) == str(selected.get("id", "")):
			matches = true
	if not matches:
		return {}

	var rows: Array[Dictionary] = []
	var fragments: Array[String] = []
	var tooltip_rows: Array[String] = []
	var attack := str(ability.get("target_side", "")) == "enemy"
	for target in targets:
		var entry := {
			"id": str(target.get("id", "")),
			"name": str(target.get("name", "")),
			"rank": int(target.get("rank", 0)),
			"side": str(target.get("side", "")),
			"hit": -1,
			"noncrit_min": 0,
			"noncrit_max": 0,
			"crit_chance": 0,
			"crit_damage": 0,
		}
		var target_name := "R%d %s" % [int(entry["rank"]), str(entry["name"])]
		var effect := _effects_label(ability.get("effects", {}))
		var summary := ""
		if attack:
			var chance := StitchedRules.hit_chance(
				int(ability.get("acc", 0)) + int(actor.get("acc", 0)),
				StitchedRules.effective_dodge(target),
				int(actor.get("miss_streak", 0))
			)
			entry["hit"] = chance
			var maximum := int(ability.get("dmg", [0, 0])[1])
			if maximum > 0:
				entry["noncrit_min"] = _noncrit_damage(actor, ability, target, int(ability["dmg"][0]))
				entry["noncrit_max"] = _noncrit_damage(actor, ability, target, maximum)
				entry["crit_chance"] = StitchedRules.CRIT_BASE + int(ability.get("crit", 0)) + int(actor.get("crit", 0))
				entry["crit_damage"] = _noncrit_damage(actor, ability, target, StitchedRules.crit_damage(maximum))
			summary = "%s HIT %d%% · NON-CRIT %d–%d" % [target_name, chance, int(entry["noncrit_min"]), int(entry["noncrit_max"])]
			if maximum > 0:
				summary += " · CRIT %d%%: %d (if hit)" % [int(entry["crit_chance"]), int(entry["crit_damage"])]
			if int(actor.get("statuses", {}).get("blind", 0)) > 0:
				summary += " · BLIND: next attack misses"
			if str(actor.get("resolve", "")) == "cowering" and str(ability.get("kind", "")) == "melee":
				summary += " · COWERING: 30% refusal"
			if not effect.is_empty():
				summary += " · on hit: " + effect
		else:
			summary = "%s NO HIT ROLL · NON-CRIT 0" % target_name
			if not effect.is_empty():
				summary += " · " + effect
			else:
				summary += " · " + str(ability.get("kind", "support")).to_upper()
		rows.append(entry)
		fragments.append(summary)
		tooltip_rows.append(summary)
	var name := str(ability.get("name", "Ability"))
	var heading := name + (" · MULTI %d TARGETS" % rows.size() if bool(ability.get("multi", false)) else "")
	return {
		"ability": name,
		"rank": rank,
		"side": side,
		"targets": rows.duplicate(true),
		"text": heading + " · " + " | ".join(fragments),
		"tooltip": heading + "\n" + "\n".join(tooltip_rows),
	}


static func _noncrit_damage(actor: Dictionary, ability: Dictionary, target: Dictionary, endpoint: int) -> int:
	var base := endpoint + int(actor.get("dmg_bonus", 0))
	if str(actor.get("resolve", "")) == "steadfast":
		base = StitchedS1BEffects.steadfast_damage(base)
	return StitchedRules.damage_after_modifiers(
		base, actor.get("statuses", {}), target.get("statuses", {}),
		int(target.get("statuses", {}).get("mark", 0)) > 0,
		int(ability.get("mark_damage", 0)), int(target.get("prot", 0))
	)


static func _effects_label(effects: Dictionary) -> String:
	var labels: Array[String] = []
	for key in effects:
		if str(key) == "duration":
			continue
		var value := int(effects[key])
		if str(key) == "dodge":
			labels.append("DODGE +%d / %d turns" % [value, int(effects.get("duration", 0))])
		elif str(key) == "heal":
			labels.append("HEAL +%d (HP capped)" % value)
		elif str(key) == "guard":
			labels.append("GUARD %d turns" % value)
		elif str(key) in ["push", "pull"]:
			labels.append(str(key).to_upper())
		else:
			labels.append("%s %s%d" % [str(key).to_upper(), "+" if str(key) == "fray" else "", value])
	return ", ".join(labels)
