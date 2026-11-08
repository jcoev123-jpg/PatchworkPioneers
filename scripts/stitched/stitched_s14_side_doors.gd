class_name StitchedS14SideDoors
extends RefCounted
## A seeded optional side door, never an extra map node.

const PATH := "res://data/stitched/s14_side_doors.json"
const KINDS := ["underbed", "attic"]
const COSTS := ["none", "max_hp", "limb", "fear"]
const REWARDS := ["gold_patch", "silk_patch", "wren_gift", "candle", "mend", "head_guard"]
const UNDERBED_WEIGHTS := {
	"gold_patch": 1,
	"silk_patch": 5,
	"wren_gift": 4,
}
const ATTIC_REWARDS := ["candle", "mend", "head_guard"]

static func catalog(document: Variant = null) -> Dictionary:
	if document == null:
		document = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not document is Dictionary or document.size() != 1 or not document.get("doors") is Array:
		return {}
	var result := {}
	for row in document.doors:
		if not row is Dictionary or row.size() != 5 or not row.get("id") is String \
				or not row.get("kind") is String or not row.get("cost") is String \
				or not row.get("reward") is String or not StitchedParts._integral(row.get("amount")):
			return {}
		if row.id == "" or result.has(row.id) or not row.kind in KINDS \
				or not row.cost in COSTS or not row.reward in REWARDS \
				or row.amount < 0 or row.amount > 30:
			return {}
		if (row.kind == "attic") != (row.cost == "none"):
			return {}
		if row.kind == "underbed" and row.amount == 0:
			return {}
		# Kind-specific reward families, free Attic amount and one-limb price:
		# an Underbed deal must carry a weighted reward family, a free Attic record
		# must stay free with a free-family reward, and a limb price is one limb.
		if row.kind == "underbed" and not UNDERBED_WEIGHTS.has(row.reward):
			return {}
		if row.kind == "attic" and (not row.reward in ATTIC_REWARDS or row.amount != 0):
			return {}
		if row.cost == "limb" and row.amount != 1:
			return {}
		result[row.id] = row.duplicate(true)
	if result.values().filter(func(row: Dictionary) -> bool: return row.kind == "underbed").is_empty() \
			or result.values().filter(func(row: Dictionary) -> bool: return row.kind == "attic").is_empty():
		return {}
	return result


## leg_payer_available: whether any surviving doll could pay the leg bargain's price.
## stuffing_payer_available: whether any surviving doll could pay the max-hp stuffing price.
## fear_payer_available: whether Wren fear, living hero and an unequipped gift permit the fear trade.
## When false, unpayable Underbed deals leave the weighted pool; everything else is unchanged.
static func offer(rng: RandomNumberGenerator, kind: String, underbed_taken: bool,
		leg_payer_available: bool = true,
		stuffing_payer_available: bool = true,
		fear_payer_available: bool = true) -> Dictionary:
	var entries := catalog()
	if rng == null or entries.is_empty() or not kind in ["Elite", "Boss"]:
		return {}
	# Elite doors are occasional; every boss has a final choice. No separate floor.
	if kind == "Elite" and rng.randi_range(1, 100) > 70:
		return {}

	var underbed_choices: Array = []
	for entry in entries.values():
		if entry.kind == "underbed":
			if entry.cost == "limb" and not leg_payer_available:
				continue
			if entry.cost == "max_hp" and not stuffing_payer_available:
				continue
			if entry.cost == "fear" and not fear_payer_available:
				continue
			var weight: int = int(UNDERBED_WEIGHTS.get(entry.get("reward", ""), 0))
			for _i in weight:
				underbed_choices.append(entry.id)
	underbed_choices.sort()

	var attic_choices: Array = []
	if not underbed_taken:
		for entry in entries.values():
			if entry.kind == "attic":
				attic_choices.append(entry.id)
		attic_choices.sort()

	var side := ""
	if not underbed_choices.is_empty() and not attic_choices.is_empty():
		side = "underbed" if rng.randi_range(0, 1) == 0 else "attic"
	elif not underbed_choices.is_empty():
		side = "underbed"
	elif not attic_choices.is_empty():
		side = "attic"
	else:
		return {}

	var pool: Array = underbed_choices if side == "underbed" else attic_choices
	if pool.is_empty():
		return {}
	return entries[pool[rng.randi_range(0, pool.size() - 1)]].duplicate(true)
