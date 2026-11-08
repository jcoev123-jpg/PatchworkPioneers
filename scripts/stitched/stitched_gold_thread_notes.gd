class_name StitchedGoldThreadNotes
extends RefCounted
## Read-only S14 gold-thread lesson; both exact catalog records are required.
## No hero-kit reads, gameplay state, random rolls or mutation.

const HUNGRY_ID := "gold_hungry_button"
const HUNGRY_NAME := "Hungry Button"
const HEART_ID := "gold_heart_knot"
const HEART_NAME := "Heart Knot"


## Return the complete three-line lesson or nothing on contradictory sources.
## Null uses the live validated patch catalog; detached inputs remain untouched.
static func examples(patches_source: Variant = null) -> Array[String]:
	var patches: Variant = patches_source if patches_source != null else StitchedS14Abilities.patches()
	if not patches is Dictionary or patches.size() != 2:
		return []
	if not patches.get("by_id") is Dictionary or not patches.get("weights") is Dictionary:
		return []
	var heart := _gold(patches.by_id, HEART_ID, HEART_NAME, "heal", 5)
	var hungry := _gold(patches.by_id, HUNGRY_ID, HUNGRY_NAME, "steal", 3)
	if heart.is_empty() or hungry.is_empty():
		return []
	return [
		"GOLD THREAD  |  A gold patch opens a second socket; each patch follows the move's actual target.",
		"%s  |  A strike carrying this patch can mend the foe it hits, if that foe survives." % heart.name.to_upper(),
		"%s  |  On an ally-helping move, this patch can drain that ally; a surviving caster recovers what was drained." % hungry.name.to_upper(),
	]


static func _gold(by_id: Dictionary, id: String, patch_name: String, effect: String,
		amount: int) -> Dictionary:
	var record: Variant = by_id.get(id)
	if not record is Dictionary or record.size() != 5:
		return {}
	if not record.get("id") is String or record.id != id:
		return {}
	if not record.get("name") is String or record.name != patch_name:
		return {}
	if not record.get("rarity") is String or record.rarity != "gold":
		return {}
	if not record.get("effect") is String or record.effect != effect:
		return {}
	if not StitchedParts._integral(record.get("amount")) or record.amount != amount:
		return {}
	return record
