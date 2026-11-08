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
