extends SceneTree
## S14 Warden arm sewn-patch lore: the two obsolete Warden arm-part move descriptions now read as
## short, player-readable descriptions of the cloth patches sewn onto the doll's arms.
##
## S14 retires part-granted actions in favour of fixed hero kits and separately found ability
## patches, so these two top-level texts must no longer promise Guard, a target rank, Mark,
## Tangled or any other combat effect. The worn parts still exist as limb identity and as S13
## sewn-on patches, so every id, name, slot, owner, stat, ability field and tier override in the
## version-1 catalog stays exactly as authored. Records are found by named id: this test never
## asserts a catalog total or an ordered id list, so other coders may append parts in parallel.
## Nothing here reads a scene, rolls randomness or mutates state.

const CATALOG_PATH := "res://data/parts/warden_parts.json"
const SHIELD := "warden_arms_shield_catch"
const RIVET := "warden_arms_rivet_pummel"
const SHIELD_TEXT := "A round bone-grey felt shield is sewn across the Warden's slate-blue sleeve with heavy rust-red loops."
const RIVET_TEXT := "Two dull brass rivets weight a slate-blue fist patch, their crooked stitches crossing a frayed bone-grey cuff."
## The retired body-part action instructions that must never come back.
const SHIELD_OLD := "Catch attacks directed at one allied doll with a sewn Guard."
const RIVET_OLD := "Double-fist a front foe, tangle its thread, and strike Marked seams harder."
## The six Warden parts this copy-only change must leave in place.
const OTHER_WARDEN_IDS := [
	"warden_head_pot_helm_bonk",
	"warden_head_helmet_rattle",
	"warden_torso_iron_challenge",
	"warden_torso_buckle_rebound",
	"warden_legs_rim_toss",
	"warden_legs_shield_toss",
]
## Any word that would still promise a card-era cost, a stitch tier, a target rank or a combat
## effect instead of describing the sewn patch. Compared as whole tokens, never as substrings.
const RETIRED_WORDS := [
	"guard", "guards", "target", "targets", "rank", "ranks", "attack", "attacks", "hit", "hits",
	"damage", "dmg", "mark", "marks", "marked", "tangled", "tangle", "tier", "tiers", "card",
	"cards", "block", "bleed", "crit", "ability", "abilities", "enemy", "enemies", "foe", "foes",
	"turn", "turns", "stun", "weak", "thorns", "riposte", "fray", "heal", "energy",
]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedParts.load_catalog(CATALOG_PATH)
	_check(bool(catalog.get("ok", false)),
		"AC3: shipped version-1 Warden parts catalog loads: " + str(catalog.get("error", "")))
	if not bool(catalog.get("ok", false)):
		_finish()
		return
	var by_id: Dictionary = catalog.get("by_id", {})
	_check(not by_id.is_empty(), "AC3: catalog exposes the by_id lookup the rules use")
	_test_part(
		by_id, SHIELD, "Shield Catch", SHIELD_TEXT, SHIELD_OLD, {"dmg": 1},
		{
			"id": "arms_shield_catch_move", "name": "Shield Catch", "kind": "guard",
			"launch": [1, 2], "target": [1, 2, 3, 4], "target_side": "ally", "multi": false,
			"acc": 100, "dmg": [0, 0], "crit": 0, "mark_damage": 0, "effects": {"guard": 2},
			"self_move": 0, "move": "guard",
		},
		{"2": {"effects": {"guard": 3}}, "3": {"effects": {"guard": 4}}},
		"AC1"
	)
	_test_part(
		by_id, RIVET, "Rivet Pummel", RIVET_TEXT, RIVET_OLD, {"dmg": 2},
		{
			"id": "arms_rivet_pummel_move", "name": "Rivet Pummel", "kind": "melee",
			"launch": [1, 2], "target": [1, 2], "target_side": "enemy", "multi": false,
			"acc": 90, "dmg": [5, 7], "crit": 0, "mark_damage": 3, "effects": {"tangled": 1},
			"self_move": 0, "move": "attack2",
		},
		{
			"2": {"dmg": [6, 9], "mark_damage": 4, "effects": {"tangled": 2}},
			"3": {"dmg": [8, 11], "acc": 95, "mark_damage": 5, "effects": {"tangled": 3}},
		},
		"AC2"
	)
	_test_other_warden_ids(by_id)
	_test_blank_text_rejected(by_id)
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s14_warden_arms_patch_lore_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _test_part(
	by_id: Dictionary,
	id: String,
	expected_name: String,
	expected_text: String,
	legacy_text: String,
	expected_stat: Dictionary,
	expected_ability: Dictionary,
	expected_tiers: Dictionary,
	label: String
) -> void:
	_check(by_id.has(id), label + ": named Warden arms part present: " + id)
	if not by_id.has(id):
		return
	var part: Dictionary = by_id[id]
	_check(str(part.get("id", "")) == id and str(part.get("name", "")) == expected_name
		and str(part.get("slot", "")) == "arms" and str(part.get("owner", "")) == "warden",
		"%s: %s keeps its id, name, arms slot and warden owner" % [label, id])
	_check_patch_copy(id, str(part.get("text", "")), expected_text, legacy_text, label)
	_check_stat(part, id, expected_stat, label)
	_check_ability(part, id, expected_ability, label)
	_check_tiers(part, id, expected_tiers, label)


## The authored sentence is compared exactly, the retired instructions are gone, and no word of the
## copy still reads as a tier, a rank, a target or a combat effect.
func _check_patch_copy(
	id: String, text: String, expected_text: String, legacy_text: String, label: String
) -> void:
	_check(text == expected_text, "%s: %s text is exactly the authored sewn-patch sentence" % [label, id])
	var lower := text.to_lower()
	_check(not lower.contains(legacy_text.to_lower()),
		"%s: %s text no longer repeats the retired part instruction" % [label, id])
	var tokens := _tokens(lower)
	_check(not tokens.is_empty(), "%s: %s text has readable words" % [label, id])
	for word in tokens:
		_check(not RETIRED_WORDS.has(str(word)),
			"%s: %s text does not mention the retired term '%s'" % [label, id, str(word)])
	var digits := 0
	for word in tokens:
		if str(word).is_valid_int():
			digits += 1
	_check(digits == 0, "%s: %s sewn-patch text carries no tier or rank numbers" % [label, id])


## Whole-word tokens of the copy, so a substring inside an ordinary word never trips a check.
func _tokens(text: String) -> Array:
	var regex := RegEx.new()
	if regex.compile("[^a-z0-9]+") != OK:
		return []
	return regex.sub(text, " ", true).split(" ", false)


func _check_stat(part: Dictionary, id: String, expected_stat: Dictionary, label: String) -> void:
	_check(part.get("stat", {}) == expected_stat,
		"%s: %s keeps its authored %s arms stat" % [label, id, str(expected_stat)])
	for tier in [1, 2, 3]:
		_check(StitchedParts.stat_at_tier(part, tier) == expected_stat,
			"%s: %s keeps its %s arms stat at stitch tier %d" % [label, id, str(expected_stat), tier])


func _check_ability(part: Dictionary, id: String, expected: Dictionary, label: String) -> void:
	var ability: Dictionary = part.get("ability", {})
	_check(not ability.is_empty() and not expected.is_empty(),
		"%s: %s still carries its authored ability dictionary" % [label, id])
	var valid := StitchedParts.validate_ability(ability)
	_check(bool(valid.get("ok", false)),
		"%s: %s ability validates: %s" % [label, id, str(valid.get("error", ""))])
	var mismatched: Array = []
	for field in expected:
		if not ability.has(field) or ability[field] != expected[field]:
			mismatched.append(str(field))
	_check(mismatched.is_empty(),
		"%s: %s ability keeps every authored field (mismatched: %s)" % [label, id, str(mismatched)])
	_check(str(ability.get("move", "")) in StitchedParts.MOVE_POSES,
		"%s: %s keeps a named move pose" % [label, id])


## Both named stitch tiers stay present with their authored overrides, tier 1 is still the base
## ability, and every effective tier ability still validates after the copy-only change.
func _check_tiers(part: Dictionary, id: String, expected_tiers: Dictionary, label: String) -> void:
	var base: Dictionary = part.get("ability", {})
	var tier_one := StitchedParts.ability_at_tier(part, 1)
	_check(tier_one == base, "%s: %s tier 1 ability is still the authored base ability" % [label, id])
	_check(bool(StitchedParts.validate_ability(tier_one).get("ok", false)),
		"%s: %s tier 1 ability validates" % [label, id])
	var tiers: Dictionary = part.get("tiers", {})
	for key in expected_tiers:
		_check(tiers.has(key), "%s: %s keeps its named tier '%s' override" % [label, id, str(key)])
		if not tiers.has(key):
			continue
		var override: Dictionary = tiers[key]
		_check(override.get("ability", {}) is Dictionary and not override["ability"].is_empty(),
			"%s: %s tier %s carries a nonempty ability override" % [label, id, str(key)])
		var effective := StitchedParts.ability_at_tier(part, int(key))
		var valid := StitchedParts.validate_ability(effective)
		_check(bool(valid.get("ok", false)),
			"%s: %s tier %s ability still validates: %s"
				% [label, id, str(key), str(valid.get("error", ""))])
		var mismatched: Array = []
		for field in expected_tiers[key]:
			if effective.get(field) != expected_tiers[key][field]:
				mismatched.append(str(field))
		_check(mismatched.is_empty(),
			"%s: %s tier %s keeps its authored override values (mismatched: %s)"
				% [label, id, str(key), str(mismatched)])


func _test_other_warden_ids(by_id: Dictionary) -> void:
	for id in OTHER_WARDEN_IDS:
		_check(by_id.has(id), "AC3: unchanged Warden part still present: " + id)
		if not by_id.has(id):
			continue
		var part: Dictionary = by_id[id]
		_check(str(part.get("owner", "")) == "warden" and str(part.get("slot", "")) in StitchedParts.SLOTS
			and not str(part.get("name", "")).is_empty() and not str(part.get("text", "")).is_empty(),
			"AC3: unchanged Warden part keeps its owner, slot, name and text: " + id)
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC3: unchanged Warden part still validates: " + id)


## Fail-closed coverage: a copy of a valid record whose text is blank must be refused, and the
## shipped record itself must stay untouched.
func _test_blank_text_rejected(by_id: Dictionary) -> void:
	for id in [SHIELD, RIVET]:
		_check(by_id.has(id), "AC3: fail-closed witness starts from the real " + id)
		if not by_id.has(id):
			continue
		var real: Dictionary = by_id[id]
		var kept_text := str(real.get("text", ""))
		_check(not real.is_empty() and not kept_text.is_empty(),
			"AC3: fail-closed witness " + id + " starts from a valid record")
		var blank: Dictionary = real.duplicate(true)
		blank["text"] = ""
		var rejected := StitchedParts.validate_part(blank)
		_check(not bool(rejected.get("ok", false)) and not str(rejected.get("error", "")).is_empty(),
			"AC3: a duplicate of %s with blank text is rejected fail-closed" % id)
		_check(str(real.get("text", "")) == kept_text and not kept_text.is_empty(),
			"AC3: the shipped " + id + " record is never mutated by the negative witness")
