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
		lines.append("%s — %s · %s" % [slot.capitalize(), name, SIDE_LABELS[side]])
	return "\n".join(lines)


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
