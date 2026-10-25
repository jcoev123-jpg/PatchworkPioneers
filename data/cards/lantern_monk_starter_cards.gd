class_name LanternMonkStarterCards
extends RefCounted
## V3-1 authored starter data for Lantern Monk: four base cards and one "+" upgrade each.
## Data only. This catalog does not build a live party, add cards to the active three-hero
## starting deck, appear in rewards, or execute combat effects. A later wiring task owns that.
## The four bases are the hero's look signatures: Wick Spark, Moth Wink, Lamplight Wash and
## Pole Shelter (a lantern flash that Blinds, moths that Blind and draw, a whole-party
## lamplight wash that heals and cleanses, and a sheltering pole that Blocks and cleanses).
## The accepted Lantern Monk reward pool is a separate catalog and is deliberately not
## referenced here.

## Internal definition schema (one entry per base and per upgraded card):
## {
##   id: String,
##   display_name: String,
##   owner: "lantern_monk",
##   cost: int,
##   from_positions: Array[int],
##   target_kind: String,  # "enemy_single", "ally_single" or "party_all"
##   to_positions: Array[int],
##   effects: Dictionary,
##   illustration_path: String,
##   starting_copies: int,
##   reward_eligible: bool,
##   upgrade_id: String   # base only; upgraded records carry upgrade_of instead
## }
##
## Effect descriptors are printed intent, not live resolution:
##   blind: 1        the affected enemy's NEXT attack misses, then the Blind is spent.
##   cleanse_debuff: 1  remove one present Bleed, Weak or Exposed from the target;
##                      it never invents a status the target does not have.
##   heal: N         each living ally heals N, capped at that ally's max HP; no resurrection.

const OWNER = "lantern_monk"

const _BASE_SPECS = [
	{"slug": "wick_spark", "name": "Wick Spark", "cost": 1, "plus_cost": 1,
		"from": [2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"damage": 4, "blind": 1},
		"plus_effects": {"damage": 6, "blind": 1}},
	{"slug": "moth_wink", "name": "Moth Wink", "cost": 1, "plus_cost": 0,
		"from": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3],
		"effects": {"blind": 1, "draw": 1},
		"plus_effects": {"blind": 1, "draw": 1}},
	{"slug": "lamplight_wash", "name": "Lamplight Wash", "cost": 2, "plus_cost": 2,
		"from": [2, 3], "target": "party_all", "to": [],
		"effects": {"heal": 2, "cleanse_debuff": 1},
		"plus_effects": {"heal": 3, "cleanse_debuff": 1}},
	{"slug": "pole_shelter", "name": "Pole Shelter", "cost": 1, "plus_cost": 1,
		"from": [1, 2, 3], "target": "ally_single", "to": [],
		"effects": {"block": 5, "cleanse_debuff": 1},
		"plus_effects": {"block": 7, "cleanse_debuff": 1}},
]

var _definitions: Dictionary = {}
var _base_ids: Array[String] = []


func _init() -> void:
	for spec: Dictionary in _BASE_SPECS:
		var base_id: String = "lantern_monk_" + str(spec["slug"])
		var plus_id: String = base_id + "_plus"
		_base_ids.append(base_id)
		_definitions[base_id] = _make_definition(spec, base_id, plus_id, false)
		_definitions[plus_id] = _make_definition(spec, base_id, plus_id, true)


func _make_definition(spec: Dictionary, base_id: String, plus_id: String,
		upgraded: bool) -> Dictionary:
	var from_positions: Array[int] = []
	for position in spec["from"]:
		from_positions.append(int(position))
	var to_positions: Array[int] = []
	for position in spec["to"]:
		to_positions.append(int(position))
	var definition: Dictionary = {
		"id": plus_id if upgraded else base_id,
		"display_name": str(spec["name"]) + ("+" if upgraded else ""),
		"owner": OWNER,
		"cost": int(spec["plus_cost"] if upgraded else spec["cost"]),
		"from_positions": from_positions,
		"target_kind": str(spec["target"]),
		"to_positions": to_positions,
		"effects": (spec["plus_effects"] if upgraded else spec["effects"]).duplicate(true),
		"illustration_path": "res://assets/paper/cards/" + base_id + ".png",
		"starting_copies": 0 if upgraded else 1,
		"reward_eligible": false,
	}
	if upgraded:
		definition["upgrade_of"] = base_id
	else:
		definition["upgrade_id"] = plus_id
	return definition


## Lookups return detached records, including effects and both position arrays.
func get_definition(card_id: Variant) -> Dictionary:
	if typeof(card_id) != TYPE_STRING:
		return {}
	var id: String = card_id
	if not _definitions.has(id):
		return {}
	return _definitions[id].duplicate(true)


func has_card(card_id: Variant) -> bool:
	if typeof(card_id) != TYPE_STRING:
		return false
	var id: String = card_id
	return _definitions.has(id)


func get_all_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _definitions:
		ids.append(id)
	return ids


## The four dedicated Lantern Monk base starters, in authored order. Not the active three-hero deck.
func get_starter_ids() -> Array[String]:
	return _base_ids.duplicate()


## Future starting-deck projection for this hero alone: one copy per base starter, no upgrades.
## This is a local membership contract, never the shared Warden/Seamstress/Tinker deck.
func get_starting_deck() -> Array[String]:
	var deck: Array[String] = []
	for base_id: String in _base_ids:
		var copies: int = int(_definitions[base_id].get("starting_copies", 0))
		for _copy in range(copies):
			deck.append(base_id)
	return deck


## Returns the "+" card ID for a base starter; upgraded, unknown and non-string IDs return "".
func get_upgrade_id(card_id: Variant) -> String:
	if typeof(card_id) != TYPE_STRING:
		return ""
	var id: String = card_id
	if not _definitions.has(id):
		return ""
	return str(_definitions[id].get("upgrade_id", ""))
