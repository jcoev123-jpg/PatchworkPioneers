class_name StitchedPartyKitHints
extends RefCounted
## Pure S14 roster tooltip projection; incomplete or malformed kits make no claim.

const SIDE_LABELS := {"enemy": "Foe", "ally": "Ally", "self": "Self"}


## Inject a detached kits() dictionary for deterministic tests; null reads the
## authoritative validated catalog. No catalog or picker state is mutated.
static func tooltip(hero_id: String, kits_source: Variant = null) -> String:
	if not hero_id in StitchedPartyAdmission.HERO_IDS:
		return ""
	var catalog: Variant = StitchedS14Abilities.kits() if kits_source == null else kits_source
	if not catalog is Dictionary or not catalog.get(hero_id) is Dictionary:
		return ""
	var kit: Dictionary = catalog[hero_id]
	if kit.size() != StitchedParts.SLOTS.size():
		return ""
	var lines: Array[String] = []
	var seen_ids := {}
	var seen_names := {}
	for slot in StitchedParts.SLOTS:
		var raw: Variant = kit.get(slot)
		if not raw is Dictionary or raw.get("slot") != slot:
			return ""
		var ability: Dictionary = raw.duplicate(true)
		ability.erase("slot")
		var validated := StitchedParts.validate_ability(ability)
		if validated.get("ok") != true:
			return ""
		var record: Dictionary = validated["ability"]
		var id: String = record["id"]
		var name: String = record["name"]
		var side: String = record["target_side"]
		if seen_ids.has(id) or seen_names.has(name) or not SIDE_LABELS.has(side):
			return ""
		seen_ids[id] = true
		seen_names[name] = true
		lines.append("%s · %s · %s%s" % [name,
			SIDE_LABELS[side], _effect_summary(record), _target_reach(record)])
	return "\n".join(lines)


## Stable positional possibilities from the *validated* fixed signature.
## These ranks say nothing about occupancy, hit chance or live target legality.
static func _target_reach(ability: Dictionary) -> String:
	if ability["target_side"] == "self":
		return " · This doll only"
	var ranks: Array = ability["target"]
	var positions := ""
	if ranks == [1, 2]:
		positions = "front pair"
	elif ranks == [2, 3, 4]:
		positions = "back three"
	elif ranks == [1, 2, 3, 4]:
		positions = "any rank"
	else:
		var labels := {1: "frontmost", 2: "second", 3: "third", 4: "rearmost"}
		var words: Array[String] = []
		for rank in ranks:
			words.append(labels[rank])
		positions = ", ".join(words)
	return " · May reach %s: %s" % [
		"foes" if ability["target_side"] == "enemy" else "allies", positions]


## Only describe the validated bare signature, never a socketed patch or a
## forecast. Slot/side/identity validation happens before any line is returned.
## Effect ordering follows the shared validator's key set, not JSON key order.
static func _effect_summary(ability: Dictionary) -> String:
	var actions: Array[String] = []
	if ability["dmg"][1] > 0:
		actions.append("strike")
	var effects: Dictionary = ability["effects"]
	for key in StitchedParts.EFFECT_KEYS:
		if key == "duration" or not effects.has(key):
			continue
		var verb := ""
		match key:
			"mark": verb = "mark"
			"guard": verb = "guard"
			"heal": verb = "mend"
			"weak": verb = "weaken"
			"exposed": verb = "expose"
			"bleed": verb = "bleed"
			"tangled": verb = "tangle"
			"blind": verb = "blind"
			"stun": verb = "stun"
			"thorns": verb = "return harm"
			"push": verb = "push back"
			"pull": verb = "pull forward"
			"dodge": verb = "evade"
			"riposte": verb = "counterattack"
			_: verb = "apply " + key.replace("_", " ")
		actions.append(verb)
	var phrase := "use this move"
	if actions.size() == 1:
		phrase = actions[0]
	elif actions.size() > 1:
		phrase = ", ".join(actions.slice(0, actions.size() - 1)) + " and " + actions[-1]
	if ability["multi"]:
		match ability["target_side"]:
			"enemy": phrase += " several eligible foes"
			"ally": phrase += " several eligible allies"
			_: phrase += " across eligible targets"
	return "Can " + phrase

## A complete, independently admitted four-doll lineup gets one authenticated
## launch-only boolean per fixed S14 slot. A forged or partial catalog yields no
## fit claims for *any* hero; target legality is deliberately not inferred.
## Structure: hero id -> {"rank": 1..4, "slots": {slot: bool}}.
static func opening_launch_fit(picks: Variant, kits_source: Variant = null) -> Dictionary:
	var receipt := StitchedPartyAdmission.admit(picks)
	if receipt.get("ok") != true:
		return {}
	var ordered: Variant = receipt.get("hero_ids")
	var heroes: Variant = receipt.get("heroes")
	if not ordered is Array or ordered.size() != StitchedPartyAdmission.RANK_COUNT \
			or not heroes is Array or heroes.size() != ordered.size():
		return {}
	var authentic := StitchedS14Abilities.kits()
	var source: Variant = authentic if kits_source == null else kits_source
	if authentic.is_empty() or not source is Dictionary:
		return {}
	var fit := {}
	var seen_moves := {}
	for index in ordered.size():
		var hero_id: Variant = ordered[index]
		var hero: Variant = heroes[index]
		if not hero_id is String or not hero is Dictionary or hero.get("id") != hero_id \
				or hero.get("rank") != index + 1 or not hero.get("name") is String:
			return {}
		var kit: Variant = source.get(hero_id)
		var canonical: Variant = authentic.get(hero_id)
		if not kit is Dictionary or not canonical is Dictionary \
				or kit.size() != StitchedParts.SLOTS.size():
			return {}
		var seen_names := {}
		var slots := {}
		for slot in StitchedParts.SLOTS:
			var entry: Variant = kit.get(slot)
			# Equality to the validated shipped kit prevents valid-looking but
			# substituted names, ids, sides or launch ranks claiming authority.
			if not entry is Dictionary or entry.get("slot") != slot \
					or entry != canonical.get(slot) or not entry.get("launch") is Array:
				return {}
			var raw: Dictionary = entry.duplicate(true)
			raw.erase("slot")
			var checked := StitchedParts.validate_ability(raw)
			if checked.get("ok") != true:
				return {}
			var ability: Dictionary = checked["ability"]
			var move_id: String = ability["id"]
			var move_name: String = ability["name"]
			if seen_moves.has(move_id) or seen_names.has(move_name) \
					or not SIDE_LABELS.has(ability["target_side"]):
				return {}
			seen_moves[move_id] = true
			seen_names[move_name] = true
			for rank in entry["launch"]:
				if not rank is int:
					return {}
			slots[slot] = (index + 1 in ability["launch"])
		fit[hero_id] = {"rank": index + 1, "slots": slots}
	return fit


## Only opening launch ranks are projected: targets and mutable battle state are
## deliberately not considered. A missing/forged signature silences *all* advice.
## One validated authority supplies both the native Set out advisory and tile cues.
## Each result contains the admitted hero's id, name and canonical 1-based rank.
static func opening_rank_stranded(picks: Variant, kits_source: Variant = null) -> Array[Dictionary]:
	var stranded: Array[Dictionary] = []
	var receipt := StitchedPartyAdmission.admit(picks)
	if receipt.get("ok") != true:
		return []
	var ordered: Variant = receipt.get("hero_ids")
	var heroes: Variant = receipt.get("heroes")
	if not ordered is Array or ordered.size() != StitchedPartyAdmission.RANK_COUNT \
			or not heroes is Array or heroes.size() != ordered.size():
		return []
	var source: Variant = StitchedS14Abilities.kits() if kits_source == null else kits_source
	if not source is Dictionary:
		return []
	var catalog: Dictionary = source.duplicate(true)
	var seen_move_ids := {}
	for index in ordered.size():
		var id: Variant = ordered[index]
		var hero: Variant = heroes[index]
		if not id is String or not hero is Dictionary or hero.get("id") != id \
				or hero.get("rank") != index + 1 or not hero.get("name") is String:
			return []
		var kit: Variant = catalog.get(id)
		if not kit is Dictionary or kit.size() != StitchedParts.SLOTS.size():
			return []
		var can_launch := false
		var seen_names := {}
		for slot in StitchedParts.SLOTS:
			var entry: Variant = kit.get(slot)
			if not entry is Dictionary or entry.get("slot") != slot:
				return []
			var raw: Dictionary = entry.duplicate(true)
			raw.erase("slot")
			var checked := StitchedParts.validate_ability(raw)
			if checked.get("ok") != true:
				return []
			var ability: Dictionary = checked["ability"]
			var move_id: String = ability["id"]
			var move_name: String = ability["name"]
			if seen_move_ids.has(move_id) or seen_names.has(move_name):
				return []
			seen_move_ids[move_id] = true
			seen_names[move_name] = true
			# Authored launch must be a real integer array, never a coerced rank
			# or an already-derived mask from a different battle state.
			if not entry.get("launch") is Array:
				return []
			for rank in entry["launch"]:
				if not rank is int:
					return []
			if index + 1 in ability["launch"]:
				can_launch = true
		if not can_launch:
			stranded.append({"id": id, "name": hero["name"], "rank": index + 1})
	return stranded


## Maintain the original exact Set out wording, including Move/Pass availability.
static func opening_rank_advisory(picks: Variant, kits_source: Variant = null) -> String:
	var stranded: Array[String] = []
	for hero in opening_rank_stranded(picks, kits_source):
		stranded.append("%s at rank %d" % [hero["name"], hero["rank"]])
	if stranded.is_empty():
		return ""
	return "Opening rank warning: %s cannot launch any signature moves. Move or Pass is still possible." % ", ".join(stranded)
