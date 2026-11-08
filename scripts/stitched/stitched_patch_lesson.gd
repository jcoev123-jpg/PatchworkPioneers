class_name StitchedPatchLesson
extends RefCounted
## S14 lesson formatter: turns validated, detached signature-ability and
## ability-patch catalogs into four plain-language Field Notes examples.
## Read-only and RNG-free; any missing or contradictory row fails closed.

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
const WARD_HERO := "tinker"
const WARD_SLOT := "torso"
const WARD_ID := "tinker_torso_casing_ward"
const WARD_NAME := "Casing Ward"
const WARD_KIND := "buff"
const WARD_SIDE := "self"
const WASH_HERO := "lantern_monk"
const WASH_SLOT := "torso"
const WASH_ID := "lantern_monk_torso_lamplight_wash"
const WASH_NAME := "Lamplight Wash"
const WASH_KIND := "heal"
const WASH_SIDE := "ally"
const BLEED_PATCH_ID := "cotton_red_lint"
const BLEED_PATCH_NAME := "Red Lint"
const BLEED_EFFECT := "bleed"
const MEND_PATCH_ID := "cotton_mending_fuzz"
const MEND_PATCH_NAME := "Mending Fuzz"
const MEND_EFFECT := "heal"
const PIN_PATCH_ID := "silk_pin_prick"
const PIN_PATCH_NAME := "Pin Prick"
const PIN_EFFECT := "stun"
const LOOP_PATCH_ID := "silk_life_loop"
const LOOP_PATCH_NAME := "Life Loop"
const LOOP_EFFECT := "regen"
const COTTON := "cotton"
const SILK := "silk"


## All four source-checked examples, or [] if any one required row is invalid.
## Null reads detached validated catalogs; injected dictionaries are never mutated.
static func examples(kits_source: Variant = null, patches_source: Variant = null) -> Array[String]:
	var kits: Variant = kits_source if kits_source != null else StitchedS14Abilities.kits()
	var patches: Variant = patches_source if patches_source != null else StitchedS14Abilities.patches()
	var heal := _ability(kits, HEAL_HERO, HEAL_SLOT, HEAL_ID, HEAL_NAME, HEAL_KIND, HEAL_SIDE, "heal")
	if heal.is_empty():
		return []
	var strike := _ability(kits, STRIKE_HERO, STRIKE_SLOT, STRIKE_ID, STRIKE_NAME, STRIKE_KIND, STRIKE_SIDE, "weak")
	if strike.is_empty():
		return []
	var ward := _ability(kits, WARD_HERO, WARD_SLOT, WARD_ID, WARD_NAME, WARD_KIND, WARD_SIDE, "thorns", "skill")
	if ward.is_empty():
		return []
	var wash := _ability(kits, WASH_HERO, WASH_SLOT, WASH_ID, WASH_NAME, WASH_KIND, WASH_SIDE, "heal", "skill", true)
	if wash.is_empty():
		return []
	var bleed := _patch(patches, BLEED_PATCH_ID, BLEED_PATCH_NAME, COTTON, BLEED_EFFECT)
	if bleed.is_empty():
		return []
	var mend := _patch(patches, MEND_PATCH_ID, MEND_PATCH_NAME, COTTON, MEND_EFFECT)
	if mend.is_empty():
		return []
	var pin := _patch(patches, PIN_PATCH_ID, PIN_PATCH_NAME, SILK, PIN_EFFECT)
	if pin.is_empty():
		return []
	var loop := _patch(patches, LOOP_PATCH_ID, LOOP_PATCH_NAME, SILK, LOOP_EFFECT)
	if loop.is_empty():
		return []
	return [
		"PATCH EXAMPLE  |  %s + %s: the heal can also bleed the ally it heals." % [str(heal.name), str(bleed.name)],
		"PATCH EXAMPLE  |  %s + %s: the hostile hit can mend the foe it strikes if that foe survives." % [str(strike.name), str(mend.name)],
		"PATCH EXAMPLE  |  %s + %s: a self ward can also stun Tinker." % [str(ward.name), str(pin.name)],
		"PATCH EXAMPLE  |  %s + %s: each ally healed can also gain regeneration." % [str(wash.name), str(loop.name)],
	]


static func _ability(kits: Variant, hero: String, slot: String, id: String, name: String,
		kind: String, side: String, effect_key: String, move: String = "",
		require_multi: bool = false) -> Dictionary:
	if not kits is Dictionary:
		return {}
	var group: Variant = kits.get(hero, {})
	if not group is Dictionary:
		return {}
	var ability: Variant = group.get(slot, {})
	if not ability is Dictionary:
		return {}
	if str(ability.get("id", "")) != id or str(ability.get("name", "")) != name or str(ability.get("slot", "")) != slot:
		return {}
	if str(ability.get("kind", "")) != kind or str(ability.get("target_side", "")) != side:
		return {}
	if not move.is_empty() and str(ability.get("move", "")) != move:
		return {}
	if require_multi and (not ability.get("multi") is bool or ability.get("multi") != true):
		return {}
	var effects: Variant = ability.get("effects", {})
	if not effects is Dictionary or effects.is_empty():
		return {}
	for value in effects.values():
		if not _positive_int(value):
			return {}
	if not _positive_int(effects.get(effect_key, 0)):
		return {}
	return ability


static func _patch(patches: Variant, id: String, name: String, rarity: String,
		effect: String) -> Dictionary:
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
	if str(record.get("rarity", "")) != rarity or str(record.get("effect", "")) != effect:
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
