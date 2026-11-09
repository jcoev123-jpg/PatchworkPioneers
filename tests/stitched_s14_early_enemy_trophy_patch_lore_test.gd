extends SceneTree
## S14 early enemy-trophy sewn-patch lore: the Fray Scavenger's Scavenger Sack Arm and the Button
## Guard's Button Buckler now read as the cloth patches a stitched doll wears.
##
## S14 retires part-granted moves in favour of the fixed signature kit plus separate ability-effect
## patches, so these two top-level texts must describe a sewn object: no attack, guard, rank,
## number, target or effect-tier promise. The drops themselves stay exactly as authored (only the
## "text" strings changed), so every stat, ability, effect, launch/target rank and tier override is
## compared against independent literals below. Records are selected by literal id, never by
## position, and no catalog total or ordered list is asserted. Nothing here reads a scene, rolls
## randomness or mutates state.

const CATALOG_PATH := "res://data/parts/enemy_parts.json"

const SACK_ID := "fray_scavenger_sack_arm"
const SACK_TEXT := "A torn burlap sack flap hangs from a ragged brown sleeve, held by rust-red cross-stitches and one dull brass button."
const SACK_OLD := "Sweep a front foe with scavenged scraps and leave them Weak."
const BUCKLER_ID := "button_guard_button_buckler"
const BUCKLER_TEXT := "A persimmon three-hole button buckler is sewn onto a deep-petrol torso patch, its mint Y-thread fastening caught by two dark cross-stitches."
const BUCKLER_OLD := "Catch a blow on a padded button buckler aimed at an ally."

## The two named trophies this copy change rewrites, keyed by literal id (never by index).
const TROPHIES := {
	SACK_ID: {
		"name": "Scavenger Sack Arm",
		"slot": "arms",
		"text": SACK_TEXT,
		"old": SACK_OLD,
		"motifs": ["burlap", "sack", "sleeve", "cross-stitches", "brass", "button"],
		"stat": {"dmg": 1},
		"ability": {
			"id": "sack_sweep", "name": "Sack Sweep", "kind": "melee",
			"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
			"acc": 88, "dmg": [3, 5], "crit": 0, "effects": {"weak": 1},
			"self_move": 0, "move": "attack2",
		},
		"tiers": {"2": {"ability": {"dmg": [4, 6]}}, "3": {"ability": {"dmg": [5, 7]}}},
	},
	BUCKLER_ID: {
		"name": "Button Buckler",
		"slot": "torso",
		"text": BUCKLER_TEXT,
		"old": BUCKLER_OLD,
		"motifs": ["persimmon", "three-hole", "button", "buckler", "deep-petrol", "torso",
			"patch", "mint", "y-thread", "cross-stitches"],
		"stat": {"prot": 7},
		"ability": {
			"id": "button_buckler", "name": "Button Buckler", "kind": "guard",
			"launch": [1, 2], "target": [1, 2, 3, 4], "target_side": "ally", "multi": false,
			"acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"guard": 2},
			"self_move": 0, "move": "guard",
		},
		"tiers": {
			"2": {"stat": {"prot": 8}, "ability": {"effects": {"guard": 3}}},
			"3": {"stat": {"prot": 9}, "ability": {"effects": {"guard": 4}}},
		},
	},
}

## The earlier named drops stay untouched; only their presence and authored values are read.
const EARLIER_DROPS := {
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
	"felt_bulwark_button_shield": {
		"name": "Button Shield Torso",
		"slot": "torso",
		"text": "Take the hits meant for one ally behind your shield.",
	},
}

## Whole-word retired combat/tier promises a worn patch description must never make.
const RETIRED_WORDS := [
	"foe", "foes", "enemy", "enemies", "ally", "allies", "rank", "ranks", "target", "targets",
	"damage", "weak", "guard", "attack", "attacks", "turn", "turns", "tier", "tiers", "card",
	"cards",
]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_check(_document_version() == 1, "the shipped enemy-parts catalog is version 1")
	var catalog := StitchedParts.load_catalog(CATALOG_PATH)
	var loaded := bool(catalog.get("ok", false))
	_check(loaded, "the real StitchedParts catalog loads: " + str(catalog.get("error", "")))
	if loaded:
		var by_id: Dictionary = catalog.get("by_id", {})
		for part_id in TROPHIES:
			_test_trophy(by_id, str(part_id))
		_test_earlier_drops(by_id)
	for old_text in [SACK_OLD, BUCKLER_OLD]:
		_check(_has_retired_word(str(old_text)),
			"the promise matcher detects the superseded sentence: " + str(old_text))
	if _failures.is_empty():
		print("stitched_s14_early_enemy_trophy_patch_lore_test: PASS (", _checks, " checks)")
	else:
		for failure in _failures:
			printerr(failure)
		print("stitched_s14_early_enemy_trophy_patch_lore_test: FAIL (", _failures.size(), " failures)")
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _document_version() -> int:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	if text.is_empty():
		return -1
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return -1
	var document: Dictionary = parsed
	var version: Variant = document.get("version", null)
	if not version is float and not version is int:
		return -1
	return int(version)


# ---------------------------------------------------------------- the two named trophies

func _test_trophy(by_id: Dictionary, part_id: String) -> void:
	var spec: Dictionary = TROPHIES[part_id]
	if not by_id.has(part_id):
		_check(false, part_id + ": the validated catalog still contains the trophy")
		return
	var part: Dictionary = by_id[part_id]
	var expected_slot := str(spec["slot"])
	_check(str(part.get("id", "")) == part_id
		and str(part.get("name", "")) == str(spec["name"])
		and str(part.get("slot", "")) == expected_slot
		and str(part.get("owner", "")) == "any",
		"%s: keeps its id, name, %s slot and any owner" % [part_id, expected_slot])

	# AC1/AC2: the worn-patch sentence, its physical motifs, and no retired combat promise.
	var text := str(part.get("text", ""))
	_check(text == str(spec["text"]), part_id + ": carries exactly the authored sewn-patch sentence")
	for motif in spec["motifs"]:
		_check(text.to_lower().contains(str(motif)),
			"%s: the patch description names %s" % [part_id, str(motif)])
	_check(not _has_retired_word(text),
		part_id + ": makes no ranked-combat, target or tier promise: " + text)
	_check(not _has_digit(text), part_id + ": carries no numeric digits: " + text)
	_check(text != str(spec["old"]),
		part_id + ": no longer reuses the retired S4 combat sentence")

	# AC3: the complete stat, ability and tier records are unchanged from the literals above.
	_check(part.get("stat", {}) == spec["stat"],
		"%s: stat is still exactly %s" % [part_id, str(spec["stat"])])
	_check(part.get("ability", {}) == _expected_ability(spec, 1),
		part_id + ": ability is still exactly the authored record")
	var tiers: Dictionary = part.get("tiers", {})
	for tier in [2, 3]:
		var key := str(tier)
		var expected := _expected_ability(spec, tier)
		_check(tiers.get(key, {}) == _expected_tier(spec, tier),
			"%s: tier %s override is still exactly the authored record" % [part_id, key])
		_check(StitchedParts.ability_at_tier(part, tier) == expected,
			"%s: the effective tier %s ability keeps the numeric ladder" % [part_id, key])
		_check(StitchedParts.stat_at_tier(part, tier) == _stat_at_tier(spec, tier),
			"%s: the effective tier %s stat keeps its ladder" % [part_id, key])
	_check(StitchedParts.ability_at_tier(part, 1) == _expected_ability(spec, 1),
		part_id + ": stitch tier 1 is still the authored base ability")
	_check(StitchedParts.stat_at_tier(part, 1) == spec["stat"],
		part_id + ": stitch tier 1 is still the authored base stat")
	_check(str(part["ability"].get("id", "")) == str(spec["ability"]["id"]),
		part_id + ": keeps the ability id " + str(spec["ability"]["id"]))

	# Fail-closed: the real record validates, blank copies are refused, the original never mutates.
	_check(bool(StitchedParts.validate_part(part).get("ok", false)),
		part_id + ": the loaded record passes StitchedParts.validate_part")
	var kept_text := text
	var kept_ability := JSON.stringify(part.get("ability", {}))
	for blank in ["", "   ", " \n\t "]:
		var broken: Dictionary = part.duplicate(true)
		broken["text"] = blank
		var result := StitchedParts.validate_part(broken)
		_check(not bool(result.get("ok", false)) and not str(result.get("error", "")).is_empty(),
			"%s: a copy with text %s is rejected fail-closed"
				% [part_id, JSON.stringify(blank)])
	_check(str(part.get("text", "")) == kept_text
		and JSON.stringify(part.get("ability", {})) == kept_ability,
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


# ---------------------------------------------------------------- unchanged earlier drops

func _test_earlier_drops(by_id: Dictionary) -> void:
	for part_id in EARLIER_DROPS:
		var spec: Dictionary = EARLIER_DROPS[part_id]
		_check(by_id.has(part_id), "the earlier named drop still exists: " + str(part_id))
		if not by_id.has(part_id):
			continue
		var part: Dictionary = by_id[part_id]
		_check(str(part.get("name", "")) == str(spec["name"])
			and str(part.get("slot", "")) == str(spec["slot"])
			and str(part.get("text", "")) == str(spec["text"]),
			"the earlier named drop stays unmodified: " + str(part_id))
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"the earlier named drop still validates: " + str(part_id))


# ---------------------------------------------------------------- whole-word matchers

## Whole-word match over lowercased ASCII letter runs, so a banned stem inside an ordinary word
## (such as "buckler") never trips the check by accident.
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
