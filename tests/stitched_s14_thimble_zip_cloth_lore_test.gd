extends SceneTree
## S14 foreign-trophy sewn-cloth lore: the Thimble Beetle's Thimble Shell and the Zipper Snake's
## Zip Teeth now read as the cloth patches a stitched doll actually wears.
##
## Design v4 S14 fixes a doll's four signature abilities, so equipped part cloth never grants an
## attack, guard or movement skill; S13 adds that foreign foe cloth may fray a doll outside its
## favoured slot. These two top-level "text" strings must therefore describe a sewn object (cloth,
## colour, seam, fastenings) with no ranked-combat, status or tier-number promise.
##
## Only the "text" strings changed, so every stat, ability, effect, launch/target rank and tier
## override of both drops is compared against independent literals copied from the source before
## the edit, and a malformed clone must still fail closed. Records are found by literal id, never
## by position, and no catalog total or ordered id list is asserted. Nothing here reads a scene,
## rolls randomness or mutates state.

const CATALOG_PATH := "res://data/parts/enemy_parts.json"

const THIMBLE_ID := "thimble_beetle_shell"
const THIMBLE_TEXT := "A dented pewter thimble curves over a charcoal quilted torso patch, fastened with stout moss-green cross-stitches and a small bone button."
const THIMBLE_OLD := "Guard an ally behind a dented thimble shell for three turns."
const ZIP_ID := "zipper_snake_zip_teeth"
const ZIP_TEXT := "Two crooked brass zipper teeth clasp a plum felt head patch, with a narrow bone-white seam and a loose oxblood thread knot."
const ZIP_OLD := "Bite a front foe with a row of zipper teeth and open a Bleed."

## The two named trophies this copy change rewrites, keyed by literal id (never by index).
const TROPHIES := {
	THIMBLE_ID: {
		"name": "Thimble Shell",
		"slot": "torso",
		"text": THIMBLE_TEXT,
		"old": THIMBLE_OLD,
		"motifs": ["dented", "pewter", "thimble", "charcoal", "quilted", "torso", "patch",
			"moss-green", "cross-stitches", "bone", "button"],
		"stat": {"prot": 10},
		"ability": {
			"id": "thimble_shell", "name": "Thimble Shell", "kind": "guard",
			"launch": [1, 2], "target": [1, 2, 3, 4], "target_side": "ally", "multi": false,
			"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"guard": 3},
			"self_move": 0, "move": "guard",
		},
		"tiers": {
			"2": {"stat": {"prot": 11}, "ability": {"effects": {"guard": 4}}},
			"3": {"stat": {"prot": 12}, "ability": {"effects": {"guard": 5}}},
		},
	},
	ZIP_ID: {
		"name": "Zip Teeth",
		"slot": "head",
		"text": ZIP_TEXT,
		"old": ZIP_OLD,
		"motifs": ["crooked", "brass", "zipper", "teeth", "plum", "felt", "head", "patch",
			"bone-white", "seam", "oxblood", "thread", "knot"],
		"stat": {"crit": 3},
		"ability": {
			"id": "zip_bite", "name": "Zip Bite", "kind": "melee",
			"launch": [1, 2], "target": [1], "target_side": "enemy", "multi": false,
			"acc": 88, "dmg": [3, 5], "crit": 0, "effects": {"bleed": 1},
			"self_move": 0, "move": "attack2",
		},
		"tiers": {
			"2": {"stat": {"crit": 4}, "ability": {"dmg": [4, 6]}},
			"3": {"stat": {"crit": 5}, "ability": {"dmg": [5, 7]}},
		},
	},
}

## Earlier S14 sewn-cloth trophies that must stay present and unmodified by this copy change.
const ANCHOR_DROPS := {
	"scissor_crab_claw_arm": {
		"name": "Scissor Claw",
		"slot": "arms",
		"text": "A dull pewter V-shaped scissor pincer is stitched across a cornflower-blue gingham sleeve, fixed by a marigold button and wine-brown thread.",
	},
	"moth_swarm_wings": {
		"name": "Tatter Wings",
		"slot": "legs",
		"text": "Notched parchment-gold moth wings spread across a petrol-teal boot patch, held by dusty-raspberry cross-stitches and a loose thread knot.",
	},
}

## Whole-word retired combat/tier promises a worn patch description must never make. "Stitched",
## "cross-stitches", "thread" and "button" stay allowed: they name the cloth itself.
const RETIRED_WORDS := [
	"foe", "foes", "enemy", "enemies", "ally", "allies", "rank", "ranks", "target", "targets",
	"damage", "weak", "guard", "attack", "attacks", "move", "moves", "turn", "turns", "tier",
	"tiers", "card", "cards", "bleed", "exposed", "thorns", "dodge", "heal",
]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var catalog := StitchedParts.load_catalog(CATALOG_PATH)
	var loaded := bool(catalog.get("ok", false))
	_check(loaded, "the real StitchedParts catalog loads: " + str(catalog.get("error", "")))
	if loaded:
		var by_id: Dictionary = catalog.get("by_id", {})
		for part_id in TROPHIES:
			_test_trophy(by_id, str(part_id))
		_test_anchor_drops(by_id)
		_test_descriptions_differ(by_id)
	for old_text in [THIMBLE_OLD, ZIP_OLD]:
		_check(_has_retired_word(str(old_text)),
			"the promise matcher detects the superseded sentence: " + str(old_text))
	if _failures.is_empty():
		print("stitched_s14_thimble_zip_cloth_lore_test: PASS (", _checks, " checks)")
	else:
		for failure in _failures:
			printerr(failure)
		print("stitched_s14_thimble_zip_cloth_lore_test: FAIL (", _failures.size(), " failures)")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# ---------------------------------------------------------------- the two named trophies

func _test_trophy(by_id: Dictionary, part_id: String) -> void:
	var spec: Dictionary = TROPHIES[part_id]
	if not by_id.has(part_id):
		_check(false, part_id + ": the validated catalog still contains the trophy")
		return
	var part: Dictionary = by_id[part_id]
	var expected_slot := str(spec["slot"])
	_check(str(part.get("id", "")) == part_id, part_id + ": keeps its literal id")
	_check(str(part.get("name", "")) == str(spec["name"]),
		part_id + ": is still named " + str(spec["name"]))
	_check(str(part.get("slot", "")) == expected_slot,
		part_id + ": still fills the " + expected_slot + " slot")
	_check(str(part.get("owner", "")) == "any",
		part_id + ": stays owner any, so any hero may wear the foreign cloth")

	# AC1: the worn-patch sentence, its physical motifs, and no retired move/status promise.
	var text := str(part.get("text", ""))
	_check(text == str(spec["text"]), part_id + ": carries exactly the authored sewn-cloth sentence")
	for motif in spec["motifs"]:
		_check(text.to_lower().contains(str(motif)),
			"%s: the patch description names %s" % [part_id, str(motif)])
	_check(not _has_retired_word(text),
		part_id + ": makes no ranked-combat, status or tier promise: " + text)
	_check(not _has_digit(text), part_id + ": carries no numeric digits: " + text)
	_check(text != str(spec["old"]),
		part_id + ": no longer reuses the retired S4 combat sentence")

	# AC2: the complete stat, ability and tier records are unchanged from the literals above.
	_check(part.get("stat", {}) == spec["stat"],
		"%s: stat is still exactly %s" % [part_id, str(spec["stat"])])
	_check(part.get("ability", {}) == _expected_ability(spec, 1),
		part_id + ": ability is still exactly the authored record")
	_check(str(_ability_of(part).get("id", "")) == str(spec["ability"]["id"]),
		part_id + ": keeps the legacy ability id " + str(spec["ability"]["id"]))
	var tiers: Dictionary = part.get("tiers", {})
	_check(tiers.size() == 2, part_id + ": still authors exactly the tier II and III overrides")
	for tier in [2, 3]:
		var key := str(tier)
		_check(tiers.get(key, {}) == _expected_tier(spec, tier),
			"%s: tier %s override is still exactly the authored record" % [part_id, key])
		_check(StitchedParts.ability_at_tier(part, tier) == _expected_ability(spec, tier),
			"%s: the effective tier %s ability keeps the numeric ladder" % [part_id, key])
		_check(StitchedParts.stat_at_tier(part, tier) == _stat_at_tier(spec, tier),
			"%s: the effective tier %s stat keeps its ladder" % [part_id, key])
	_check(StitchedParts.ability_at_tier(part, 1) == _expected_ability(spec, 1),
		part_id + ": stitch tier 1 is still the authored base ability")
	_check(StitchedParts.stat_at_tier(part, 1) == spec["stat"],
		part_id + ": stitch tier 1 is still the authored base stat")

	# AC3 fail-closed: the real record validates, malformed clones are refused, nothing mutates.
	_check(bool(StitchedParts.validate_part(part).get("ok", false)),
		part_id + ": the loaded record passes StitchedParts.validate_part")
	var kept := JSON.stringify(part)
	for blank in ["", "   ", " \n\t "]:
		var blanked: Dictionary = part.duplicate(true)
		blanked["text"] = blank
		var result := StitchedParts.validate_part(blanked)
		_check(not bool(result.get("ok", false)) and not str(result.get("error", "")).is_empty(),
			"%s: a clone with text %s is rejected fail-closed"
				% [part_id, JSON.stringify(blank)])
	var wrong_stat := "dmg" if expected_slot == "torso" else "prot"
	var stat_broken: Dictionary = part.duplicate(true)
	stat_broken["stat"][wrong_stat] = 1
	_check(not bool(StitchedParts.validate_part(stat_broken).get("ok", false)),
		"%s: a clone granting %s in the %s slot is rejected fail-closed"
			% [part_id, wrong_stat, expected_slot])
	var ability_broken: Dictionary = part.duplicate(true)
	ability_broken["ability"]["acc"] = 101
	_check(not bool(StitchedParts.validate_part(ability_broken).get("ok", false)),
		part_id + ": a clone with an illegal ability accuracy is rejected fail-closed")
	_check(JSON.stringify(part) == kept,
		part_id + ": the negative witnesses never mutate the loaded record")


## The validated shape of one ability at a stitch tier: authored fields plus the derived masks and
## the authored-default mark damage, so a missing or extra field fails the comparison.
func _expected_ability(spec: Dictionary, tier: int) -> Dictionary:
	var expected: Dictionary = spec["ability"].duplicate(true)
	if tier > 1:
		var tier_record: Dictionary = spec["tiers"].get(str(tier), {})
		var override: Dictionary = tier_record.get("ability", {})
		for field in override:
			expected[field] = override[field]
	expected["mark_damage"] = 0
	expected["launch_mask"] = StitchedParts.rank_mask(expected["launch"])
	expected["target_mask"] = StitchedParts.rank_mask(expected["target"])
	return expected


func _stat_at_tier(spec: Dictionary, tier: int) -> Dictionary:
	var stat: Dictionary = spec["stat"].duplicate(true)
	if tier > 1:
		var tier_record: Dictionary = spec["tiers"].get(str(tier), {})
		var override: Dictionary = tier_record.get("stat", {})
		for field in override:
			stat[field] = int(override[field])
	return stat


## The validated shape of one authored tier override: exactly the fields the literal record names.
func _expected_tier(spec: Dictionary, tier: int) -> Dictionary:
	var authored: Dictionary = spec["tiers"].get(str(tier), {})
	var record: Dictionary = {}
	if authored.has("stat"):
		record["stat"] = _stat_at_tier(spec, tier)
	if authored.has("ability"):
		record["ability"] = _expected_ability(spec, tier)
	return record


# ---------------------------------------------------------------- unchanged foreign trophies

## The S14 trophy slice already shipped for Scissor Crab and Moth Swarm is not deleted, reordered
## or reworded by this copy change. This is an id-presence anchor, never a catalog total.
func _test_anchor_drops(by_id: Dictionary) -> void:
	for part_id in ANCHOR_DROPS:
		var spec: Dictionary = ANCHOR_DROPS[part_id]
		_check(by_id.has(part_id), "the earlier sewn-cloth trophy is still present: " + str(part_id))
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		_check(str(part.get("name", "")) == str(spec["name"])
			and str(part.get("slot", "")) == str(spec["slot"])
			and str(part.get("text", "")) == str(spec["text"]),
			"the earlier sewn-cloth trophy stays unmodified: " + str(part_id))
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"the earlier sewn-cloth trophy still validates: " + str(part_id))


func _test_descriptions_differ(by_id: Dictionary) -> void:
	var thimble := _text_of(by_id, THIMBLE_ID)
	var zip := _text_of(by_id, ZIP_ID)
	_check(not thimble.is_empty() and not zip.is_empty() and thimble != zip,
		"the two rewritten patch descriptions are distinct authored sentences")


func _text_of(by_id: Dictionary, part_id: String) -> String:
	var part: Variant = by_id.get(part_id, {})
	if not part is Dictionary:
		return ""
	return str(part.get("text", ""))


# ---------------------------------------------------------------- record helpers

func _ability_of(part: Dictionary) -> Dictionary:
	var ability: Variant = part.get("ability")
	return ability if ability is Dictionary else {}


# ---------------------------------------------------------------- whole-word matchers

## Whole-word match over lowercased ASCII letter runs, so a banned stem inside an ordinary word
## (such as "button") never trips the check by accident.
func _has_retired_word(text: String) -> bool:
	var lower := text.to_lower()
	var current := ""
	for index in range(lower.length()):
		var code := lower.unicode_at(index)
		if code >= 97 and code <= 122:
			current += lower[index]
		elif not current.is_empty():
			if current in RETIRED_WORDS:
				return true
			current = ""
	if not current.is_empty() and current in RETIRED_WORDS:
		return true
	return false


func _has_digit(text: String) -> bool:
	for index in range(text.length()):
		var code := text.unicode_at(index)
		if code >= 48 and code <= 57:
			return true
	return false
