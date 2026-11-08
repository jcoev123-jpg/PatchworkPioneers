class_name StitchedPatchLesson
extends RefCounted
## S14 lesson formatter: turns the shipped fixed-signature ability catalogs into
## exactly two plain-language ability-patch examples for the Field Notes
## "Seams & retreat" page. Pure and read-only: no RNG, no mutation of the inputs,
## the catalog caches or any session state. Any missing or contradictory row
## fails closed to an empty array instead of making a claim.

const HEAL_HERO := "seamstress"
const HEAL_SLOT := "head"
const HEAL_ID := "seamstress_head_mending_knot"
const HEAL_NAME := "Mending Knot"
const HEAL_KIND := "heal"
const HEAL_SIDE := "ally"
const STRIKE_HERO := "warden"
const STRIKE_SLOT := "torso"
const STRIKE_ID := "warden_torso_iron_challenge"
const STRIKE_NAME := "Iron Challenge"
const STRIKE_KIND := "melee"
const STRIKE_SIDE := "enemy"
const BLEED_PATCH_ID := "cotton_red_lint"
const BLEED_PATCH_NAME := "Red Lint"
const BLEED_EFFECT := "bleed"
const MEND_PATCH_ID := "cotton_mending_fuzz"
const MEND_PATCH_NAME := "Mending Fuzz"
const MEND_EFFECT := "heal"
const PATCH_RARITY := "cotton"


## The two shipped examples, or [] when either source is missing, malformed or
## contradictory. Null sources read the live validated catalogs; injected sources
## are detached copies consulted only for this call and never mutated.
static func examples(kits_source: Variant = null, patches_source: Variant = null) -> Array[String]:
	var kits: Variant = kits_source if kits_source != null else StitchedS14Abilities.kits()
	var patches: Variant = patches_source if patches_source != null else StitchedS14Abilities.patches()
	var heal := _ability(kits, HEAL_HERO, HEAL_SLOT, HEAL_ID, HEAL_NAME, HEAL_KIND, HEAL_SIDE, "heal")
	if heal.is_empty():
		return []
	var strike := _ability(kits, STRIKE_HERO, STRIKE_SLOT, STRIKE_ID, STRIKE_NAME, STRIKE_KIND, STRIKE_SIDE, "")
	if strike.is_empty():
		return []
	var bleed := _patch(patches, BLEED_PATCH_ID, BLEED_PATCH_NAME, BLEED_EFFECT)
	if bleed.is_empty():
		return []
	var mend := _patch(patches, MEND_PATCH_ID, MEND_PATCH_NAME, MEND_EFFECT)
	if mend.is_empty():
		return []
	return [
		"PATCH EXAMPLE  |  %s + %s: the heal can also bleed the ally it heals." % [str(heal.name), str(bleed.name)],
		"PATCH EXAMPLE  |  %s + %s: the hostile hit can mend the foe it strikes if that foe survives." % [str(strike.name), str(mend.name)],
	]


static func _ability(kits: Variant, hero: String, slot: String, id: String, name: String, kind: String, side: String, effect_key: String) -> Dictionary:
	if not kits is Dictionary:
		return {}
	var group: Variant = kits.get(hero, {})
	if not group is Dictionary:
		return {}
	var ability: Variant = group.get(slot, {})
	if not ability is Dictionary:
		return {}
	if str(ability.get("id", "")) != id or str(ability.get("name", "")) != name:
		return {}
	if str(ability.get("kind", "")) != kind or str(ability.get("target_side", "")) != side:
		return {}
	var effects: Variant = ability.get("effects", {})
	if not effects is Dictionary or effects.is_empty():
		return {}
	for value in effects.values():
		if not _positive_int(value):
			return {}
	if not effect_key.is_empty() and not _positive_int(effects.get(effect_key, 0)):
		return {}
	return ability


static func _patch(patches: Variant, id: String, name: String, effect: String) -> Dictionary:
	if not patches is Dictionary:
		return {}
	var by_id: Variant = patches.get("by_id", {})
	if not by_id is Dictionary:
		return {}
	var record: Variant = by_id.get(id, {})
	if not record is Dictionary:
		return {}
	if str(record.get("id", "")) != id or str(record.get("name", "")) != name:
		return {}
	if str(record.get("rarity", "")) != PATCH_RARITY or str(record.get("effect", "")) != effect:
		return {}
	if not _positive_int(record.get("amount", 0)):
		return {}
	return record


static func _positive_int(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) > 0
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floor(value):
		return int(value) > 0
	return false
