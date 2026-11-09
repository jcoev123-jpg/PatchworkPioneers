extends SceneTree
## S4 Lantern Monk: private eight-part contract in real seeded S2 4v3 rules combat.
const CATALOG_PATH := "res://data/parts/lantern_monk_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const S14_ABILITIES_PATH := "res://data/stitched/s14_hero_abilities.json"
const STARTERS := {
	"head": "lantern_monk_head_moth_wink",
	"arms": "lantern_monk_arms_wick_spark",
	"torso": "lantern_monk_torso_lamplight_wash",
	"legs": "lantern_monk_legs_pole_shelter",
}
const ALTERNATES := {
	"head": "lantern_monk_head_moth_cloud",
	"arms": "lantern_monk_arms_snuff_flame",
	"torso": "lantern_monk_torso_vigil_ring",
	"legs": "lantern_monk_legs_moth_shroud",
}
const IDS := [
	"lantern_monk_head_moth_wink", "lantern_monk_arms_wick_spark",
	"lantern_monk_torso_lamplight_wash", "lantern_monk_legs_pole_shelter",
	"lantern_monk_head_moth_cloud", "lantern_monk_arms_snuff_flame",
	"lantern_monk_torso_vigil_ring", "lantern_monk_legs_moth_shroud",
]
## S14 sewn-cloth copy: the two leg patches describe the fabric art the player sees, not the
## retired S4 part-granted combat move. Both tier text overrides repeat the Pole Shelter sentence.
const POLE_SHELTER_COPY := "A little robed doll huddles under a slanted cloth shelter beside a hanging lantern, sewn in dark stitches on cream fabric."
const MOTH_SHROUD_COPY := "A button-eyed doll curls inside swirling cloth strips while tiny moths flutter above it on a deep plum sewn patch."
## S14 sewn-cloth copy: the two arm patches describe the stitched cloth the player sees, never the
## retired S4 part-granted Blind/Expose attack. The Monk's real signatures live in
## data/stitched/s14_hero_abilities.json, so these top-level texts stay pure appearance.
const WICK_SPARK_COPY := "A narrow saffron wick is stitched across the Monk's plum sleeve cuff, with a soot-dark tip bound in cream thread."
const SNUFF_FLAME_COPY := "A cream lantern-shade flap folds over the Monk's other plum sleeve, its scorched hem edged in small saffron cross-stitches."
## S14 sewn-cloth copy: the alternate head and torso patches describe the stitched cloth the
## player sees, never the retired S4 part-granted Blind/Heal/Dodge move. The Monk's real
## signatures live in data/stitched/s14_hero_abilities.json, so these top-level texts stay
## pure appearance.
const MOTH_CLOUD_COPY := "A cluster of plum felt moths swirls across a saffron head patch, with cream wing tips secured by dark cross-stitches."
const VIGIL_RING_COPY := "A cream-stitched halo circles a tiny lantern on the Monk's plum quilted chest, with saffron cloth rays tucked beneath its seams."
## S14 sewn-cloth copy: the two starter patches describe the literal stitched fabric the player
## sees, never the retired nested S4 part-granted ability. The Monk's real signatures live in
## data/stitched/s14_hero_abilities.json, so these top-level texts stay pure appearance.
const MOTH_WINK_COPY := "A small cream button eye sits in a soot-dark saffron felt brow, with one plum moth tacked beside it in uneven cross-stitches."
const LAMPLIGHT_WASH_COPY := "A frayed saffron felt strip crosses the Monk's plum quilted chest, held by cream running stitches beneath a small tarnished lantern clasp."
## The obsolete vague sentences this lane replaced: positive witnesses that the new physical-cue
## checks really reject prose that names no tangible sewn piece.
const OLD_MOTH_WINK_COPY := "Moths gather beside the Monk's lantern-lit button eye, stirring with each blink."
const OLD_LAMPLIGHT_WASH_COPY := "Lamplight pools over the Monk's quilted robe and warms the stitches along its seams."
## Whole words that would turn this appearance copy back into an obsolete combat promise. `\b`
## word boundaries keep "stitched" or "hem" from tripping a shorter token such as "hit".
const FORBIDDEN_COPY_PATTERN := "\\b(ability|skill|rank|ranks|target|foe|enemy|ally|cast|attack|hit|damage|blind|expose|exposed|weak|bleed|stun|heal|guard|dodge|tier|tiers|turn|turns|duration|move|effect|chance|bonus)\\b"
## The two obsolete sentences this lane replaced: positive witnesses that the matcher bites.
const OLD_WICK_SPARK_PROMISE := "Singe one foe in ranks 1-3: Blind it; stitched tiers II/III also Expose a seam for 1/2 turns."
const OLD_SNUFF_FLAME_PROMISE := "Snuff a foe's light with a stinging flame; Blind and Expose the target."
const OLD_MOTH_CLOUD_PROMISE := "Loose a cloud of moths, even from the rear rank; attempt Blind independently on each living foe in ranks one to four."
const OLD_VIGIL_RING_PROMISE := "A ring of lanternlight heals all living allies and shelters each with temporary Dodge."
## The parts this task must leave frozen: base ability shape, slot stat and label.
## Lamplight Wash and Moth Cloud are the two rear-rank parts and have their own contracts.
const FROZEN_PARTS := {
	"lantern_monk_head_moth_wink": {
		"name": "Mothlit Brow Patch", "launch": [1, 2, 3, 4], "target": [1, 2, 3], "side": "enemy",
		"multi": false, "acc": 90, "dmg": [0, 0], "effects": {"blind": 1}, "move": "skill",
		"stat": {"acc": 3},
	},
	"lantern_monk_arms_wick_spark": {
		"name": "Ember-Wick Cuff", "launch": [2, 3, 4], "target": [1, 2, 3], "side": "enemy",
		"multi": false, "acc": 91, "dmg": [4, 6], "effects": {"blind": 1}, "move": "attack2",
		"stat": {"dmg": 1},
	},
	"lantern_monk_legs_pole_shelter": {
		"name": "Pole Shelter", "launch": [1, 2, 3], "target": [1, 2, 3, 4], "side": "ally",
		"multi": false, "acc": 100, "dmg": [0, 0], "effects": {"guard": 2}, "move": "guard",
		"stat": {"speed": 1, "dodge": 3},
	},
	"lantern_monk_arms_snuff_flame": {
		"name": "Snuff-Shade Sleeve", "launch": [2, 3], "target": [1, 2, 3], "side": "enemy",
		"multi": false, "acc": 90, "dmg": [3, 5], "effects": {"blind": 1, "exposed": 1},
		"move": "attack", "stat": {"dmg": 2},
	},
	"lantern_monk_torso_vigil_ring": {
		"name": "Vigil Ring", "launch": [2, 3], "target": [1, 2, 3, 4], "side": "ally",
		"multi": true, "acc": 100, "dmg": [0, 0],
		"effects": {"heal": 4, "dodge": 4, "duration": 1}, "move": "skill",
		"stat": {"max_hp": 5, "prot": 6},
	},
	"lantern_monk_legs_moth_shroud": {
		"name": "Moth Shroud", "launch": [2, 3, 4], "target": [1, 2, 3, 4], "side": "ally",
		"multi": false, "acc": 100, "dmg": [0, 0], "effects": {"dodge": 10, "duration": 2},
		"move": "guard", "stat": {"speed": 1, "dodge": 4},
	},
}
## Authored tier-II/III override fields for those unchanged parts.
const FROZEN_TIERS := {
	"lantern_monk_head_moth_wink": {
		"2": {"acc": 94},
		"3": {"acc": 100, "effects": {"blind": 1, "exposed": 1}},
	},
	"lantern_monk_arms_wick_spark": {
		"2": {"dmg": [5, 8], "effects": {"blind": 1, "exposed": 1}},
		"3": {"dmg": [7, 10], "acc": 95, "effects": {"blind": 1, "exposed": 2}},
	},
	"lantern_monk_legs_pole_shelter": {
		"2": {"effects": {"guard": 3}},
		"3": {"effects": {"guard": 4}, "launch": [1, 2, 3, 4]},
	},
	"lantern_monk_arms_snuff_flame": {
		"2": {"dmg": [4, 6], "effects": {"blind": 1, "exposed": 2}},
		"3": {"dmg": [5, 8], "effects": {"blind": 1, "exposed": 3}},
	},
	"lantern_monk_torso_vigil_ring": {
		"2": {"effects": {"heal": 5, "dodge": 6, "duration": 1}},
		"3": {"effects": {"heal": 7, "dodge": 8, "duration": 1}},
	},
	"lantern_monk_legs_moth_shroud": {
		"2": {"effects": {"dodge": 14, "duration": 2}},
		"3": {"effects": {"dodge": 18, "duration": 2}},
	},
}
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_patch_copy()
	_test_moth_wink_patch_label()
	_test_arm_patch_copy()
	_test_head_torso_patch_copy()
	_test_leg_patch_copy()
	_test_lamplight_wash_launch()
	_test_wick_spark_launch()
	_test_moth_cloud_fourth_rank()
	_test_each_tier()
	_test_multi_blind()
	_test_blind_next_attack()
	_test_real_healing()
	_test_rank4_lamplight_heal(2, 500600, 60, 3, "tier II")
	_test_rank4_lamplight_heal(3, 500700, 60, 5, "tier III")
	_test_rank4_moth_cloud(1, 500950, 30, "tier I")
	_test_rank4_moth_cloud(2, 500990, 30, "tier II")
	_test_rank4_moth_cloud(3, 501030, 30, "tier III")
	_test_rank4_wick_spark(1, 500030, 60)
	_test_wick_spark_exposed_seam(1, 500030, 90, 0)
	_test_wick_spark_exposed_seam(2, 500030, 90, 1)
	_test_wick_spark_exposed_seam(3, 500030, 90, 2)
	_test_wick_spark_miss_no_seam(1, 500030, 90)
	_test_wick_spark_miss_no_seam(2, 500030, 90)
	_test_wick_spark_miss_no_seam(3, 500030, 90)
	_test_moth_wink_rank4(1, 501680, 20)
	_test_moth_wink_rank4(2, 501700, 20)
	_test_moth_wink_rank4(3, 501720, 20)
	_test_rank4_moth_shroud(1, 501560, 40, 10, "tier I")
	_test_rank4_moth_shroud(2, 501600, 40, 14, "tier II")
	_test_rank4_moth_shroud(3, 501640, 40, 18, "tier III")
	_test_moth_shroud_rejections()
	_test_pole_shelter_rear_launch()
	_test_pole_shelter_tier_text()
	_test_rank4_pole_shelter()
	_test_pole_shelter_rejections()
	_test_rank2_moth_cloud_replay()
	_test_guard_and_shroud()
	_test_rejection_no_spend()
	_test_rank4_launch_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_lantern_monk_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


## Moth Wink may launch from all four hero ranks; Wick Spark and Moth Shroud may launch from
## hero rank 4 but not rank 1. Pole Shelter reaches hero rank 4 only through its authored
## tier-III launch override: its base, tier I and tier II lists stay frozen at ranks 1-3.
## Every other frozen part stays limited to its authored ranks. Used for the base ability and
## every stitch tier's effective mask.
func _rank4_launch_contract(id: String, mask: int, tier: int = 1) -> bool:
	if id == STARTERS["head"]:
		return StitchedParts.ranks_allowed(mask, 1) and StitchedParts.ranks_allowed(mask, 2) \
			and StitchedParts.ranks_allowed(mask, 3) and StitchedParts.ranks_allowed(mask, 4)
	if id == STARTERS["legs"] and tier == 3:
		return StitchedParts.ranks_allowed(mask, 1) and StitchedParts.ranks_allowed(mask, 2) \
			and StitchedParts.ranks_allowed(mask, 3) and StitchedParts.ranks_allowed(mask, 4)
	if id == STARTERS["arms"] or id == ALTERNATES["legs"]:
		return StitchedParts.ranks_allowed(mask, 2) and StitchedParts.ranks_allowed(mask, 3) \
			and StitchedParts.ranks_allowed(mask, 4) and not StitchedParts.ranks_allowed(mask, 1)
	return not StitchedParts.ranks_allowed(mask, 4)


## S2's shipped fixture is NOT modified: the same four existing heroes are re-ordered in
## memory so Lantern Monk occupies legal launch rank 2, and he gets actual gear. With
## monk_rank4 the original preview order is kept, which puts him in hero rank 4.
func _config(
	selected: String = "", tier: int = 1, seed_value: int = 500040, monk_rank4: bool = false
) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "shipped S2 4v3 fixture is a dictionary")
		return {}
	var catalog := _catalog()
	if not bool(catalog.get("ok", false)):
		_check(false, "Lantern Monk catalog validates: " + str(catalog.get("error", "")))
		return {}
	var config: Dictionary = parsed
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var monk: Dictionary = config["heroes"].pop_back()
	_check(str(monk.get("id", "")) == "lantern_monk", "real S2 fourth hero is Lantern Monk")
	var monk_index := 1
	if monk_rank4:
		config["heroes"].append(monk)
		monk_index = config["heroes"].size() - 1
	else:
		config["heroes"].insert(1, monk)
	var gear: Dictionary = {}
	for slot in STARTERS:
		var part_id: String = STARTERS[slot]
		if not selected.is_empty() and catalog["by_id"].has(selected) and str(catalog["by_id"][selected]["slot"]) == slot:
			part_id = selected
		gear[slot] = {"id": part_id, "tier": tier}
	config["heroes"][monk_index]["parts"] = gear
	return config


func _battle(
	selected: String = "", tier: int = 1, seed_value: int = 500040, monk_rank4: bool = false
) -> StitchedRules:
	var config := _config(selected, tier, seed_value, monk_rank4)
	if config.is_empty():
		return null
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "real seeded Lantern Monk creation: " + str(created.get("error", "")))
	if not bool(created.get("ok", false)):
		return null
	var b: StitchedRules = created["battle"]
	var expected_rank := 4 if monk_rank4 else 2
	_check(b.get_heroes().size() == 4 and b.get_foes().size() == 3 and int(b.get_unit("lantern_monk").get("rank", -1)) == expected_rank,
		"real four-hero/three-foe S2 battle, Lantern Monk in rank %d" % expected_rank)
	_check(b.get_unit("lantern_monk").get("parts", {}).size() == 4,
		"real Lantern Monk has four actually equipped slots")
	return b


func _to(b: StitchedRules, actor_id: String, limit: int = 55) -> bool:
	for step in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == actor_id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _test_catalog() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: StitchedParts validates real Lantern Monk JSON")
	if not bool(cat.get("ok", false)):
		return
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	var seen: Dictionary = {}
	var seen_moves: Dictionary = {}
	for id in IDS:
		_check(cat["by_id"].has(id), "AC1: required named part present: " + id)
	for part in cat["parts"]:
		var id := str(part["id"])
		_check(not seen.has(id) and id in IDS and str(part["owner"]) == "lantern_monk",
			"AC1: unique exclusively Lantern Monk-owned part " + id)
		seen[id] = true
		var slot: String = str(part["slot"])
		if counts.has(slot):
			counts[slot] += 1
		_check(str(part["ability"]["id"]).begins_with("lantern_monk_") and not seen_moves.has(str(part["ability"]["id"])),
			"AC1: one unique native ability per " + id)
		seen_moves[str(part["ability"]["id"])] = true
		var ab: Dictionary = part["ability"]
		_check(str(ab["move"]) in StitchedParts.MOVE_POSES
			and int(ab["launch_mask"]) == StitchedParts.rank_mask(ab["launch"])
			and int(ab["target_mask"]) == StitchedParts.rank_mask(ab["target"])
			and int(ab["launch_mask"]) != 0 and int(ab["target_mask"]) != 0,
			"AC1: named existing pose and valid launch/target rank masks " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: explicit stitch tier II and III for " + id)
		for tier in [1, 2, 3]:
			var a := StitchedParts.ability_at_tier(part, tier)
			var s := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(a).get("ok", false)),
				"AC1: tier %d ability validates %s" % [tier, id])
			_check(not s.is_empty(), "AC1: slot-compatible tier %d stat %s" % [tier, id])
			_check(tier == 1 or a != ab, "AC1: tier %d has numeric progression %s" % [tier, id])
			for key in s:
				_check(str(key) in StitchedParts.SLOT_STATS[slot], "AC1: slot-valid stat at every tier")
			for retired in ["draw", "block", "cost", "energy", "exhaust", "cleanse_debuff"]:
				_check(not a.has(retired) and not a["effects"].has(retired), "AC1: no unimplemented card effect " + retired)
	for slot in counts:
		_check(int(counts[slot]) == 2, "AC1: exactly two Lantern Monk parts in " + slot)
		_check(str(cat["by_id"][STARTERS[slot]]["slot"]) == slot
			and str(cat["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: four named starters plus four alternative names in matching slots")
	_check(bool(cat["by_id"][ALTERNATES["head"]]["ability"]["multi"])
		and cat["by_id"][ALTERNATES["head"]]["ability"]["target"] == [1, 2, 3, 4],
		"AC1: Moth Cloud is authoritative multi-target Blind reaching a possible summoned rank 4")
	for id in [STARTERS["torso"], ALTERNATES["torso"]]:
		_check(bool(cat["by_id"][id]["ability"]["multi"]) and str(cat["by_id"][id]["ability"]["target_side"]) == "ally",
			"AC1: whole-party lantern healing uses native multi targeting")
	_check(cat["by_id"][ALTERNATES["legs"]]["ability"]["effects"].has("duration"),
		"AC1: temporary Moth Shroud Dodge has bounded duration")
	for id in IDS:
		var malformed: Dictionary = cat["by_id"][id].duplicate(true)
		malformed["tiers"]["4"] = {"ability": {"acc": 99}}
		_check(not bool(StitchedParts.validate_part(malformed).get("ok", false)),
			"AC3: illegal tier IV rejects every catalog part")
	var bad_dodge: Dictionary = cat["by_id"][ALTERNATES["legs"]].duplicate(true)
	bad_dodge["tiers"]["2"]["ability"]["effects"] = {"dodge": 5}
	_check(not bool(StitchedParts.validate_part(bad_dodge).get("ok", false)),
		"AC3: tier-II Dodge without paired duration rejects")
	var bad_mask: Dictionary = cat["by_id"][ALTERNATES["head"]].duplicate(true)
	bad_mask["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(bad_mask).get("ok", false)),
		"AC3: out-of-bounds target rank rejects")


## S13/S14 starter patch identity copy: the two named starter patches now describe the sewn
## patch the player sees instead of advertising a retired part-granted ability. Both texts are
## compared by named ID (never list position), each keeps its literal fabric motifs, and neither
## field may keep a card-era or receipt phrase, a whole-word combat/tier promise or a digit. The
## old vague sentences are kept only as positive witnesses that these cue checks reject them.
func _test_patch_copy() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog available for the named patch copy checks")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		"lantern_monk_head_moth_wink": {
			"name": "Mothlit Brow Patch", "slot": "head", "text": MOTH_WINK_COPY,
			"motifs": ["cream button eye", "saffron felt", "plum moth", "cross-stitches"],
			"old": OLD_MOTH_WINK_COPY,
		},
		"lantern_monk_torso_lamplight_wash": {
			"name": "Lamplight Wash", "slot": "torso", "text": LAMPLIGHT_WASH_COPY,
			"motifs": ["saffron felt", "plum quilted chest", "cream running stitches", "lantern clasp"],
			"old": OLD_LAMPLIGHT_WASH_COPY,
		},
	}
	var forbidden := RegEx.new()
	_check(forbidden.compile(FORBIDDEN_COPY_PATTERN) == OK,
		"AC2: the whole-word combat-promise pattern compiles for the starter patch copy")
	_check(forbidden.search("heal one ally for two turns") != null,
		"AC2: the matcher really rejects an obsolete heal/ally/turn sentence")
	var digits := RegEx.new()
	_check(digits.compile("\\d") == OK, "AC2: the numeric-digit pattern compiles for starter patch copy")
	_check(digits.search("heal 4 for 2 turns") != null,
		"AC2: the digit matcher really detects numeric combat values")
	var obsolete := ["card draw", "heal receipt"]
	var seen_texts: Dictionary = {}
	for id in expected:
		var want: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: named starter patch record present: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["id"]) == id and str(part["name"]) == str(want["name"])
			and str(part["owner"]) == "lantern_monk" and str(part["slot"]) == str(want["slot"]),
			"AC1: starter patch keeps its id, name, owner and %s slot: %s" % [str(want["slot"]), id])
		var text := str(part["text"])
		_check(text == str(want["text"]),
			"AC1: starter patch base copy is exactly the authored cloth sentence: " + id)
		seen_texts[text] = true
		var low := text.to_lower()
		for motif in want["motifs"]:
			_check(low.contains(str(motif)),
				"AC1: starter patch copy names the sewn motif '%s': %s" % [str(motif), id])
		_check(forbidden.search(low) == null,
			"AC2: starter patch copy promises no combat word: " + id)
		_check(digits.search(text) == null,
			"AC2: starter patch copy carries no numeric combat digits: " + id)
		for phrase in obsolete:
			_check(not low.contains(str(phrase)),
				"AC1: starter patch copy drops the obsolete phrase '%s': %s" % [str(phrase), id])
		# Positive witness: the obsolete sentence must fail every new physical-cue check.
		var old_low := str(want["old"]).to_lower()
		var old_cues := 0
		for motif in want["motifs"]:
			if old_low.contains(str(motif)):
				old_cues += 1
		_check(old_cues == 0,
			"AC2: the obsolete vague sentence fails every new physical-cue check: " + id)
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC1: starter patch validates with its sewn-cloth description: " + id)
		var blanked: Dictionary = part.duplicate(true)
		blanked["text"] = ""
		_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
			"AC3: a blank starter patch base text still fails closed: " + id)
		var spaces: Dictionary = part.duplicate(true)
		spaces["text"] = "   "
		_check(not bool(StitchedParts.validate_part(spaces).get("ok", false)),
			"AC3: a whitespace-only starter patch base text still fails closed: " + id)
		_check(str(cat["by_id"][id]["text"]) == str(want["text"]),
			"AC3: deep-copy validation never mutates the shipped starter patch: " + id)
	_check(seen_texts.size() == 2,
		"AC2: the two starter patches describe visually distinct sewn cloth")
	# Lamplight Wash stays a felt strip on the chest, not the cream-stitched halo of Vigil Ring.
	var torso_text := str(cat["by_id"][STARTERS["torso"]]["text"])
	var vigil_text := str(cat["by_id"][ALTERNATES["torso"]]["text"])
	_check(torso_text != vigil_text and not torso_text.to_lower().contains("halo")
		and vigil_text.to_lower().contains("halo"),
		"AC2: Lamplight Wash stays a felt strip, distinct from the halo-shaped Vigil Ring patch")
	# The nested S4 stat/ability/tier data stays exact for validation and regressions, though it
	# is retired as a live part-granted move; the fixed S14 signatures are separate records.
	var frozen := {
		STARTERS["head"]: {
			"stat": {"acc": 3},
			"ability": {
				"id": "lantern_monk_head_moth_wink_move", "name": "Moth Wink", "kind": "debuff",
				"launch": [1, 2, 3, 4], "target": [1, 2, 3], "side": "enemy", "multi": false,
				"acc": 90, "dmg": [0, 0], "crit": 0, "effects": {"blind": 1}, "self_move": 0,
				"move": "skill",
			},
			"tiers": {
				1: {"acc": 90, "effects": {"blind": 1}},
				2: {"acc": 94, "effects": {"blind": 1}},
				3: {"acc": 100, "effects": {"blind": 1, "exposed": 1}},
			},
		},
		STARTERS["torso"]: {
			"stat": {"max_hp": 6, "prot": 4},
			"ability": {
				"id": "lantern_monk_torso_lamplight_wash_move", "name": "Lamplight Wash",
				"kind": "heal", "launch": [2, 3, 4], "target": [1, 2, 3, 4], "side": "ally",
				"multi": true, "acc": 100, "dmg": [0, 0], "crit": 0, "effects": {"heal": 2},
				"self_move": 0, "move": "skill",
			},
			"tiers": {1: {"heal": 2}, 2: {"heal": 3}, 3: {"heal": 5}},
		},
	}
	for id in frozen:
		var want: Dictionary = frozen[id]
		var part: Dictionary = cat["by_id"].get(id, {})
		_check(not part.is_empty(),
			"AC3: named starter record present for its frozen base data: " + id)
		if part.is_empty():
			continue
		var ab: Dictionary = part["ability"]
		var want_ab: Dictionary = want["ability"]
		_check(part["stat"] == want["stat"]
			and str(ab["id"]) == str(want_ab["id"]) and str(ab["name"]) == str(want_ab["name"])
			and str(ab["kind"]) == str(want_ab["kind"])
			and ab["launch"] == want_ab["launch"] and ab["target"] == want_ab["target"]
			and str(ab["target_side"]) == str(want_ab["side"])
			and bool(ab["multi"]) == bool(want_ab["multi"])
			and int(ab["acc"]) == int(want_ab["acc"]) and ab["dmg"] == want_ab["dmg"]
			and int(ab["crit"]) == int(want_ab["crit"]) and ab["effects"] == want_ab["effects"]
			and int(ab["self_move"]) == int(want_ab["self_move"])
			and str(ab["move"]) == str(want_ab["move"]),
			"AC3: starter record keeps its exact base stat and nested S4 ability: " + id)
		for tier in [1, 2, 3]:
			var tiered := StitchedParts.ability_at_tier(part, tier)
			var want_tier: Dictionary = want["tiers"][tier]
			var acc_ok := not want_tier.has("acc") or int(tiered["acc"]) == int(want_tier["acc"])
			var effects_ok := true
			if want_tier.has("effects"):
				effects_ok = tiered["effects"] == want_tier["effects"]
			elif want_tier.has("heal"):
				effects_ok = int(tiered["effects"].get("heal", 0)) == int(want_tier["heal"]) \
					and tiered["effects"].size() == 1
			_check(acc_ok and effects_ok,
				"AC3: starter record keeps its exact tier %d override: %s" % [tier, id])
	# The six other named Lantern Monk parts stay reachable and valid, matched by ID rather than
	# by catalog total or list order (parallel lanes can extend shared catalogs).
	for id in IDS:
		if id == STARTERS["head"] or id == STARTERS["torso"]:
			continue
		_check(cat["by_id"].has(id) and bool(StitchedParts.validate_part(cat["by_id"][id]).get("ok", false)),
			"AC3: the six other named Lantern Monk parts stay accessible and valid: " + id)


## S14: the starter head is a worn cloth patch, so its top-level inventory label names the
## decorated brow ("Mothlit Brow Patch") instead of the fixed signature move the same ID still
## carries in the separate S14 hero-ability catalog. Both catalogs are looked up by named
## fields, never list position: the part keeps its old ID, head slot, owner, +3 ACC stat and
## exact moth/button-eye sentence, its legacy nested ability stays "Moth Wink", and the real
## S14 signature keeps its own "Moth Wink" name and mechanics untouched.
func _test_moth_wink_patch_label() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog available for the named Moth Wink patch label")
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"].get("lantern_monk_head_moth_wink", {})
	_check(not part.is_empty(), "AC1: the named Lantern Monk starter head record is present")
	if part.is_empty():
		return
	_check(str(part["name"]) == "Mothlit Brow Patch"
		and str(part["id"]) == "lantern_monk_head_moth_wink"
		and str(part["slot"]) == "head" and str(part["owner"]) == "lantern_monk"
		and part["stat"] == {"acc": 3}
		and str(part["text"]) == MOTH_WINK_COPY,
		"AC1: the head patch is labelled Mothlit Brow Patch with its old ID, slot, owner, stat and copy")
	_check(str(part["ability"]["id"]) == "lantern_monk_head_moth_wink_move"
		and str(part["ability"]["name"]) == "Moth Wink",
		"AC2: the nested legacy part ability keeps its own Moth Wink id and name")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(S14_ABILITIES_PATH))
	_check(parsed is Dictionary and parsed.get("abilities") is Array,
		"AC3: the real S14 hero-ability catalog parses with an abilities array")
	if not parsed is Dictionary or not parsed.get("abilities") is Array:
		return
	var signature: Dictionary = {}
	for entry in parsed["abilities"]:
		if entry is Dictionary and str(entry.get("hero", "")) == "lantern_monk" \
				and str(entry.get("slot", "")) == "head" \
				and str(entry.get("id", "")) == "lantern_monk_head_moth_wink":
			signature = entry
			break
	_check(not signature.is_empty(),
		"AC3: the fixed Lantern Monk head signature is present by hero, slot and id")
	if signature.is_empty():
		return
	# JSON numbers parse as floats, so the rank lists and Blind amount are compared as ints.
	var launch_ranks: Array = []
	for rank in signature.get("launch", []):
		launch_ranks.append(int(rank))
	var target_ranks: Array = []
	for rank in signature.get("target", []):
		target_ranks.append(int(rank))
	var dmg: Array = signature.get("dmg", [])
	var effects: Dictionary = signature.get("effects", {})
	_check(str(signature["name"]) == "Moth Wink" and str(signature["name"]) != str(part["name"])
		and str(signature["kind"]) == "debuff" and str(signature["target_side"]) == "enemy"
		and launch_ranks == [2, 3, 4] and target_ranks == [1, 2, 3, 4]
		and int(signature.get("acc", -1)) == 90
		and dmg.size() == 2 and int(dmg[0]) == 0 and int(dmg[1]) == 0
		and effects.size() == 1 and int(effects.get("blind", 0)) == 1
		and str(signature["move"]) == "attack",
		"AC3: the fixed S14 Moth Wink stays distinct with enemy Blind 1, ranks, ACC 90 and attack pose")


## S14 arm patch identity copy: both Lantern Monk arm patches describe the sewn cloth the player
## actually sees, never the retired part-granted Blind/Expose attack. Every text is looked up by
## named ID (never list position) and must stay free of rank/target/tier/damage/turn/numeric
## promises, while the frozen S4 ability data keeps the real mechanics.
func _test_arm_patch_copy() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog available for the named arm patch copy checks")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		STARTERS["arms"]: {
			"name": "Ember-Wick Cuff",
			"ability_name": "Wick Spark",
			"text": WICK_SPARK_COPY,
			"motif": "wick",
			"other_motif": "lantern-shade",
		},
		ALTERNATES["arms"]: {
			"name": "Snuff-Shade Sleeve",
			"ability_name": "Snuff Flame",
			"text": SNUFF_FLAME_COPY,
			"motif": "lantern-shade",
			"other_motif": "wick",
		},
	}
	var forbidden := RegEx.new()
	_check(forbidden.compile(FORBIDDEN_COPY_PATTERN) == OK,
		"AC2: the whole-word combat-promise pattern compiles")
	_check(forbidden.search(OLD_WICK_SPARK_PROMISE.to_lower()) != null,
		"AC2: the matcher really detects the old Wick Spark combat sentence")
	_check(forbidden.search(OLD_SNUFF_FLAME_PROMISE.to_lower()) != null,
		"AC2: the matcher really detects the old Snuff Flame combat sentence")
	var digits := RegEx.new()
	_check(digits.compile("\\d") == OK, "AC2: the numeric-digit pattern compiles")
	_check(digits.search(OLD_WICK_SPARK_PROMISE) != null,
		"AC2: the digit matcher really detects the old '1/2 turns' numbers")
	var seen_texts: Dictionary = {}
	for id in expected:
		var want: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: named arm patch record present: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["id"]) == id and str(part["name"]) == str(want["name"])
			and str(part["owner"]) == "lantern_monk" and str(part["slot"]) == "arms",
			"AC1: arm patch keeps its id, name, owner and arms slot: " + id)
		_check(str(part["ability"]["name"]) == str(want["ability_name"])
			and str(part["name"]) != str(part["ability"]["name"]),
			"AC2: worn arm label differs from its unchanged nested S4 ability name: " + id)
		_check(bool(StitchedParts.validate_part(part).get("ok", false)),
			"AC1: shipped arm patch validates with its sewn-cloth description: " + id)
		var text := str(part["text"])
		_check(text == str(want["text"]),
			"AC1: arm patch base copy is exactly the authored cloth sentence: " + id)
		seen_texts[text] = true
		var low := text.to_lower()
		_check(low.contains("sleeve") and (low.contains("stitch") or low.contains("thread")),
			"AC1: arm patch copy names a stitched sleeve: " + id)
		_check(low.contains("saffron") and low.contains("plum") and low.contains("cream"),
			"AC1: arm patch copy keeps the saffron/plum/cream linen hues: " + id)
		_check(low.contains(str(want["motif"])) and not low.contains(str(want["other_motif"])),
			"AC1: arm patch copy keeps its own wick-versus-lantern-shade motif: " + id)
		_check(forbidden.search(low) == null,
			"AC2: arm patch copy promises no combat word: " + id)
		_check(digits.search(text) == null,
			"AC2: arm patch copy carries no numeric combat digits: " + id)
		var blanked: Dictionary = part.duplicate(true)
		blanked["text"] = ""
		_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
			"AC3: a blank arm patch base text still fails closed: " + id)
		var spaces: Dictionary = part.duplicate(true)
		spaces["text"] = "   "
		_check(not bool(StitchedParts.validate_part(spaces).get("ok", false)),
			"AC3: a whitespace-only arm patch base text still fails closed: " + id)
		_check(str(cat["by_id"][id]["text"]) == str(want["text"]),
			"AC3: deep-copy validation never mutates the shipped arm patch: " + id)
	_check(seen_texts.size() == 2,
		"AC2: the two arm patches describe visually distinct sewn cloth")
	# The fixed S14 signature keeps its own combat name; only the worn label changed.
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(S14_ABILITIES_PATH))
	_check(parsed is Dictionary and parsed.get("abilities") is Array,
		"AC2: the real S14 hero-ability catalog parses for the arms signature")
	if parsed is Dictionary and parsed.get("abilities") is Array:
		var signature: Dictionary = {}
		for entry in parsed["abilities"]:
			if entry is Dictionary and str(entry.get("hero", "")) == "lantern_monk" \
					and str(entry.get("slot", "")) == "arms" \
					and str(entry.get("id", "")) == STARTERS["arms"]:
				signature = entry
				break
		_check(not signature.is_empty() and str(signature.get("name", "")) == "Wick Spark",
			"AC2: the fixed S14 arms signature stays named Wick Spark")


## S14 head/torso patch identity copy: the alternate head and torso patches describe the sewn
## cloth the player actually sees, never the retired part-granted Blind/Heal/Dodge move. Every
## text is looked up by named ID (never list position) and must stay free of rank/target/tier/
## damage/turn promises, while the frozen S4 ability data keeps the real mechanics.
func _test_head_torso_patch_copy() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog available for the named head/torso patch copy checks")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		ALTERNATES["head"]: {
			"name": "Moth Cloud", "slot": "head", "text": MOTH_CLOUD_COPY,
			"motifs": ["moths", "saffron", "cross-stitches"],
		},
		ALTERNATES["torso"]: {
			"name": "Vigil Ring", "slot": "torso", "text": VIGIL_RING_COPY,
			"motifs": ["halo", "lantern", "plum", "chest"],
		},
	}
	var forbidden := RegEx.new()
	_check(forbidden.compile(FORBIDDEN_COPY_PATTERN) == OK,
		"AC2: the whole-word combat-promise pattern compiles for head/torso copy")
	_check(forbidden.search(OLD_MOTH_CLOUD_PROMISE.to_lower()) != null,
		"AC2: the matcher really detects the old Moth Cloud combat sentence")
	_check(forbidden.search(OLD_VIGIL_RING_PROMISE.to_lower()) != null,
		"AC2: the matcher really detects the old Vigil Ring combat sentence")
	var digits := RegEx.new()
	_check(digits.compile("\\d") == OK, "AC2: the numeric-digit pattern compiles for head/torso copy")
	_check(digits.search("ranks 1-4 for 2 turns") != null,
		"AC2: the digit matcher really detects numeric combat values")
	var seen_texts: Dictionary = {}
	for id in expected:
		var want: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: named head/torso patch record present: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["id"]) == id and str(part["name"]) == str(want["name"])
			and str(part["owner"]) == "lantern_monk" and str(part["slot"]) == str(want["slot"]),
			"AC1: patch keeps its id, name, owner and %s slot: %s" % [str(want["slot"]), id])
		var text := str(part["text"])
		_check(text == str(want["text"]),
			"AC1: patch base copy is exactly the authored cloth sentence: " + id)
		seen_texts[text] = true
		var low := text.to_lower()
		for motif in want["motifs"]:
			_check(low.contains(str(motif)),
				"AC1: patch copy names the sewn motif '%s': %s" % [str(motif), id])
		_check(forbidden.search(low) == null,
			"AC2: patch copy promises no combat word: " + id)
		_check(digits.search(text) == null,
			"AC2: patch copy carries no numeric combat digits: " + id)
		var blanked: Dictionary = part.duplicate(true)
		blanked["text"] = ""
		_check(not bool(StitchedParts.validate_part(blanked).get("ok", false)),
			"AC3: a blank patch base text still fails closed: " + id)
		var spaces: Dictionary = part.duplicate(true)
		spaces["text"] = "   "
		_check(not bool(StitchedParts.validate_part(spaces).get("ok", false)),
			"AC3: a whitespace-only patch base text still fails closed: " + id)
		_check(str(cat["by_id"][id]["text"]) == str(want["text"]),
			"AC3: deep-copy validation never mutates the shipped patch: " + id)
	_check(seen_texts.size() == 2,
		"AC2: the two head/torso patches describe visually distinct sewn cloth")


## S14 leg patch identity copy: both Lantern Monk leg patches describe the sewn cloth art the
## player actually sees, never a retired part-granted combat move. Every player-facing string is
## looked up by named ID (never list position) and must stay free of Guard/Dodge/rank/target
## promises, while the authored tier ability data keeps the real S4 mechanics.
func _test_leg_patch_copy() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog available for the named leg patch copy checks")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		STARTERS["legs"]: {
			"name": "Pole Shelter", "stat": {"speed": 1, "dodge": 3},
			"text": POLE_SHELTER_COPY,
			"nouns": ["robed doll", "cloth shelter", "lantern", "cream"],
		},
		ALTERNATES["legs"]: {
			"name": "Moth Shroud", "stat": {"speed": 1, "dodge": 4},
			"text": MOTH_SHROUD_COPY,
			"nouns": ["button-eyed", "cloth", "moths", "plum"],
		},
	}
	var forbidden := RegEx.new()
	_check(forbidden.compile("\\b(guard|dodge|heal|attack|enemy|ally|target|rank|turn|damage|duration|card|tier)\\b") == OK,
		"AC3: combat-promise word pattern compiles")
	_check(forbidden.search("guard one ally for two turns") != null,
		"AC3: the combat-promise pattern really rejects an old Guard sentence")
	for id in expected:
		var want: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: named leg patch record present: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["name"]) == str(want["name"]) and str(part["owner"]) == "lantern_monk"
			and str(part["slot"]) == "legs" and part["stat"] == want["stat"],
			"AC1: leg patch keeps its name, owner, legs slot and stat: " + id)
		var text := str(part["text"])
		_check(text == str(want["text"]),
			"AC1: leg patch base copy is exactly the authored cloth sentence: " + id)
		for noun in want["nouns"]:
			_check(text.to_lower().contains(str(noun)),
				"AC1: leg patch copy names the icon motif '%s': %s" % [str(noun), id])
		var fields := {id + " base": text}
		var tiers: Dictionary = part.get("tiers", {})
		for tier in ["2", "3"]:
			if tiers.has(tier) and tiers[tier].has("text"):
				fields[id + " tier " + tier] = str(tiers[tier]["text"])
		for label in fields:
			_check(forbidden.search(str(fields[label]).to_lower()) == null,
				"AC3: no combat-promise word in %s: %s" % [str(label), str(fields[label])])
		var blank: Dictionary = part.duplicate(true)
		blank["text"] = ""
		_check(not bool(StitchedParts.validate_part(blank).get("ok", false)),
			"AC3: a blank leg patch base text still fails closed: " + id)
	var pole: Dictionary = cat["by_id"][STARTERS["legs"]]
	var pole_tiers: Dictionary = pole.get("tiers", {})
	for tier in ["2", "3"]:
		_check(pole_tiers.has(tier) and pole_tiers[tier].has("text")
			and str(pole_tiers[tier]["text"]) == POLE_SHELTER_COPY,
			"AC1: Pole Shelter tier %s text is the same neutral cloth sentence" % tier)
		var blank_tier: Dictionary = pole.duplicate(true)
		blank_tier["tiers"][tier]["text"] = ""
		_check(not bool(StitchedParts.validate_part(blank_tier).get("ok", false)),
			"AC3: a blank Pole Shelter tier %s text still fails closed" % tier)


## The starter torso launches from hero ranks 2-4 with an all-ally multi heal. Every field,
## tier override, label and stat in the eight-part file stays frozen except the authored
## rank-4 launches of Moth Wink, Wick Spark and Moth Shroud.
func _test_lamplight_wash_launch() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog with Lamplight Wash's fourth launch rank validates")
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][STARTERS["torso"]]
	var ability: Dictionary = part["ability"]
	var launch_mask := StitchedParts.rank_mask([2, 3, 4])
	var full_mask := StitchedParts.ALL_RANKS_MASK
	_check(launch_mask != 0 and launch_mask != full_mask and not StitchedParts.ranks_allowed(launch_mask, 1),
		"AC1: hero ranks 2-4 derive a launch mask that still excludes rank 1")
	_check(str(part["id"]) == "lantern_monk_torso_lamplight_wash"
		and str(part["name"]) == "Lamplight Wash" and str(part["slot"]) == "torso"
		and str(part["owner"]) == "lantern_monk" and part["stat"] == {"max_hp": 6, "prot": 4},
		"AC1: Lamplight Wash keeps its name, torso slot, owner and +6 HP/+4 PROT stat")
	_check(str(ability["id"]) == "lantern_monk_torso_lamplight_wash_move"
		and str(ability["name"]) == "Lamplight Wash" and str(ability["kind"]) == "heal"
		and ability["launch"] == [2, 3, 4] and int(ability["launch_mask"]) == launch_mask
		and ability["target"] == [1, 2, 3, 4] and int(ability["target_mask"]) == full_mask
		and str(ability["target_side"]) == "ally" and bool(ability["multi"])
		and int(ability["acc"]) == 100 and ability["dmg"] == [0, 0] and int(ability["crit"]) == 0
		and int(ability["mark_damage"]) == 0 and ability["effects"] == {"heal": 2}
		and int(ability["self_move"]) == 0 and str(ability["move"]) == "skill",
		"AC1: Lamplight Wash is a multi ally heal launched from [2,3,4] with heal 2 and its skill pose")
	var expected_heal := {1: 2, 2: 3, 3: 5}
	for tier in [1, 2, 3]:
		var tiered := StitchedParts.ability_at_tier(part, tier)
		var valid := StitchedParts.validate_ability(tiered)
		_check(bool(valid.get("ok", false)), "AC1: Lamplight Wash tier %d ability validates" % tier)
		if not bool(valid.get("ok", false)):
			continue
		var checked: Dictionary = valid["ability"]
		_check(checked["launch"] == [2, 3, 4] and int(checked["launch_mask"]) == launch_mask
			and checked["target"] == [1, 2, 3, 4] and int(checked["target_mask"]) == full_mask
			and str(checked["target_side"]) == "ally" and bool(checked["multi"])
			and int(checked["acc"]) == 100 and checked["dmg"] == [0, 0]
			and int(checked["effects"].get("heal", 0)) == int(expected_heal[tier]),
			"AC1: Lamplight Wash tier %d keeps launch 2-4, all four ally ranks and heal %d"
				% [tier, int(expected_heal[tier])])
		_check(StitchedParts.stat_at_tier(part, tier) == {"max_hp": 6, "prot": 4},
			"AC1: Lamplight Wash tier %d keeps its authored slot stat" % tier)
		for rank in [2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC1: Lamplight Wash tier %d may launch from hero rank %d" % [tier, rank])
		_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), 1),
			"AC1: Lamplight Wash tier %d is still forbidden from hero rank 1" % tier)
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Lamplight Wash tier %d reaches ally rank %d" % [tier, rank])
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank)
				and not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Lamplight Wash tier %d never allows rank %d" % [tier, rank])
	_check(ability["launch"] == [2, 3, 4] and ability["target"] == [1, 2, 3, 4]
		and int(ability["effects"]["heal"]) == 2,
		"AC3: tier reads never replace Lamplight Wash's base ability in memory")
	# The six other untouched parts stay byte-for-byte equivalent in rules terms, including
	# their base launch masks: Wick Spark and Moth Shroud gain rank 4, and Pole Shelter gains
	# it only at tier III through its authored launch override (base and tier II stay 1-3).
	for id in FROZEN_PARTS:
		var frozen: Dictionary = FROZEN_PARTS[id]
		var other: Dictionary = cat["by_id"][id]
		var other_ability: Dictionary = other["ability"]
		_check(str(other["name"]) == str(frozen["name"]) and other["stat"] == frozen["stat"]
			and other_ability["launch"] == frozen["launch"]
			and int(other_ability["launch_mask"]) == StitchedParts.rank_mask(frozen["launch"])
			and other_ability["target"] == frozen["target"]
			and int(other_ability["target_mask"]) == StitchedParts.rank_mask(frozen["target"])
			and str(other_ability["target_side"]) == str(frozen["side"])
			and bool(other_ability["multi"]) == bool(frozen["multi"])
			and int(other_ability["acc"]) == int(frozen["acc"])
			and other_ability["dmg"] == frozen["dmg"]
			and other_ability["effects"] == frozen["effects"]
			and str(other_ability["move"]) == str(frozen["move"]),
			"AC1: frozen base part unchanged: " + id)
		_check(_rank4_launch_contract(id, int(other_ability["launch_mask"])),
			"AC1: only Moth Wink, Wick Spark and Moth Shroud gain rank-4 launch at base tier: " + id)
		for tier in [1, 2, 3]:
			var tier_ability := StitchedParts.ability_at_tier(other, tier)
			var expected := {
				"acc": int(frozen["acc"]),
				"dmg": frozen["dmg"],
				"effects": frozen["effects"],
				"self_move": 0,
			}
			var expected_launch: Array = frozen["launch"]
			if tier > 1:
				var overrides: Dictionary = FROZEN_TIERS[id][str(tier)]
				for key in overrides:
					expected[key] = overrides[key]
				if overrides.has("launch"):
					expected_launch = overrides["launch"]
			_check(int(tier_ability["acc"]) == int(expected["acc"])
				and tier_ability["dmg"] == expected["dmg"]
				and tier_ability["effects"] == expected["effects"]
				and int(tier_ability["self_move"]) == int(expected["self_move"]),
				"AC1: frozen %s tier %d keeps its authored override values" % [id, tier])
			_check(tier_ability["launch"] == expected_launch
				and int(tier_ability["launch_mask"]) == StitchedParts.rank_mask(expected_launch)
				and _rank4_launch_contract(id, int(tier_ability["launch_mask"]), tier),
				"AC1: rank-4 launch stays gated by the authored mask at base and each tier: %s tier %d"
					% [id, tier])
			_check(tier_ability["target"] == frozen["target"]
				and int(tier_ability["target_mask"]) == StitchedParts.rank_mask(frozen["target"])
				and str(tier_ability["target_side"]) == str(frozen["side"])
				and bool(tier_ability["multi"]) == bool(frozen["multi"]),
				"AC1: frozen %s tier %d keeps its authored target ranks and side" % [id, tier])
			_check(StitchedParts.stat_at_tier(other, tier) == frozen["stat"],
				"AC1: frozen %s tier %d keeps its slot stat" % [id, tier])


## S4 completion: the starter arms' authored launch list gains hero rank 4 so the rear-ranked
## monk can fling Wick Spark at one front-rank foe. Its target list stays enemy ranks 1-3 and
## it stays a single-target Blind hit: the fourth rank is a legal place to cast from, never a
## fourth starting enemy. Every tier inherits the new base launch unchanged.
func _test_wick_spark_launch() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog with Wick Spark's rank-4 launch validates")
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][STARTERS["arms"]]
	var ability: Dictionary = part["ability"]
	var rear_launch := [2, 3, 4]
	var launch_mask := StitchedParts.rank_mask(rear_launch)
	var target_mask := StitchedParts.rank_mask([1, 2, 3])
	_check(launch_mask != 0 and launch_mask != StitchedParts.ALL_RANKS_MASK
		and launch_mask != target_mask,
		"AC1: Wick Spark ranks 2-4 derive a launch mask that still excludes rank 1")
	_check(str(part["id"]) == "lantern_monk_arms_wick_spark"
		and str(part["name"]) == "Ember-Wick Cuff" and str(part["slot"]) == "arms"
		and str(part["owner"]) == "lantern_monk" and part["stat"] == {"dmg": 1},
		"AC1: the worn cuff keeps its id, arms slot, owner and +1 damage stat")
	_check(str(ability["id"]) == "lantern_monk_arms_wick_spark_move"
		and str(ability["name"]) == "Wick Spark" and str(ability["kind"]) == "ranged"
		and ability["launch"] == rear_launch and int(ability["launch_mask"]) == launch_mask
		and ability["target"] == [1, 2, 3] and int(ability["target_mask"]) == target_mask
		and str(ability["target_side"]) == "enemy" and not bool(ability["multi"])
		and int(ability["acc"]) == 91 and ability["dmg"] == [4, 6]
		and int(ability["crit"]) == 0 and int(ability["mark_damage"]) == 0
		and ability["effects"] == {"blind": 1} and int(ability["self_move"]) == 0
		and str(ability["move"]) == "attack2",
		"AC1: Wick Spark launches from [2,3,4], hits one enemy rank 1-3 and keeps its fuel values")
	# S14 sewn-cloth copy: the arm patch names the stitched cloth, never a Blind/Exposed promise.
	_check(str(part["text"]) == WICK_SPARK_COPY,
		"AC1: Wick Spark's text is the authored sewn-cloth sentence, not a combat promise")
	for rank in [2, 3, 4]:
		_check(StitchedParts.ranks_allowed(launch_mask, rank),
			"AC1: Wick Spark may launch from hero rank %d" % rank)
	for rank in [0, 1, 5]:
		_check(not StitchedParts.ranks_allowed(launch_mask, rank),
			"AC1: Wick Spark never launches from rank %d" % rank)
	for rank in [0, 4, 5]:
		_check(not StitchedParts.ranks_allowed(target_mask, rank),
			"AC1: Wick Spark never targets rank %d" % rank)
	for rank in [1, 2, 3]:
		_check(StitchedParts.ranks_allowed(target_mask, rank),
			"AC1: Wick Spark reaches enemy rank %d" % rank)
	_check(not StitchedParts.ranks_allowed(target_mask, 4),
		"AC1: Wick Spark's target list stays exactly enemy ranks 1-3, never a rank-4 opener")
	var expected_acc := {1: 91, 2: 91, 3: 95}
	var expected_dmg := {1: [4, 6], 2: [5, 8], 3: [7, 10]}
	var expected_effects := {
		1: {"blind": 1},
		2: {"blind": 1, "exposed": 1},
		3: {"blind": 1, "exposed": 2},
	}
	for tier in [1, 2, 3]:
		var tiered := StitchedParts.ability_at_tier(part, tier)
		var valid := StitchedParts.validate_ability(tiered)
		_check(bool(valid.get("ok", false)), "AC1: Wick Spark tier %d ability validates" % tier)
		if not bool(valid.get("ok", false)):
			continue
		var checked: Dictionary = valid["ability"]
		_check(checked["launch"] == rear_launch
			and int(checked["launch_mask"]) == launch_mask,
			"AC1: Wick Spark tier %d inherits the new base launch [2,3,4]" % tier)
		for rank in [2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC1: Wick Spark tier %d may launch from hero rank %d" % [tier, rank])
		for rank in [0, 1, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC1: Wick Spark tier %d never launches from rank %d" % [tier, rank])
		_check(checked["target"] == [1, 2, 3]
			and int(checked["target_mask"]) == target_mask
			and str(checked["target_side"]) == "enemy" and not bool(checked["multi"]),
			"AC1: Wick Spark tier %d keeps its single enemy target mask 1-3" % tier)
		for rank in [1, 2, 3]:
			_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Wick Spark tier %d still reaches enemy rank %d" % [tier, rank])
		for rank in [0, 4, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Wick Spark tier %d never targets enemy rank %d" % [tier, rank])
		_check(checked["effects"] == expected_effects[tier],
			"AC1: Wick Spark tier %d effects are exactly %s" % [tier, str(expected_effects[tier])])
		_check(int(checked["acc"]) == int(expected_acc[tier])
			and checked["dmg"] == expected_dmg[tier]
			and int(checked["effects"].get("blind", 0)) == 1
			and int(checked["crit"]) == 0
			and int(checked["mark_damage"]) == 0 and str(checked["move"]) == "attack2",
			"AC1: Wick Spark tier %d keeps its ACC, damage, Blind and attack2 pose" % tier)
		_check(StitchedParts.stat_at_tier(part, tier) == {"dmg": 1},
			"AC1: Wick Spark tier %d keeps its authored slot stat" % tier)
	_check(ability["launch"] == rear_launch and ability["target"] == [1, 2, 3]
		and int(ability["acc"]) == 91 and ability["dmg"] == [4, 6]
		and ability["effects"] == {"blind": 1},
		"AC1: tier reads never replace Wick Spark's base fields in memory")
	for bad_launch in [[2, 3, 4, 4], [2, 3, 4, 5], [0, 2, 3, 4]]:
		var copy: Dictionary = part.duplicate(true)
		copy["ability"]["launch"] = bad_launch
		_check(not bool(StitchedParts.validate_part(copy).get("ok", false)),
			"AC3: copied Wick Spark launch %s still fails validation" % str(bad_launch))
	var wrong_side: Dictionary = part.duplicate(true)
	wrong_side["ability"]["target_side"] = "allies"
	_check(not bool(StitchedParts.validate_part(wrong_side).get("ok", false)),
		"AC3: copied Wick Spark with an unknown target side still fails validation")


## S4 completion: Moth Cloud's base launch list gains hero rank 4, so the Monk's alternate
## head can Blind the enemy line from the rear; its target list still reaches enemy rank 4,
## which Design v4 only creates by summon or split. The shipped S2 4v3 fixture keeps its
## three real starting foes, so the extra target rank is proven through data rules, never by
## inventing a fourth opening enemy.
func _test_moth_cloud_fourth_rank() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog with Moth Cloud's rank-4 launch and target validates")
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][ALTERNATES["head"]]
	var rear_launch := [2, 3, 4]
	var launch_mask := StitchedParts.rank_mask(rear_launch)
	var full_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	_check(full_mask == StitchedParts.ALL_RANKS_MASK and full_mask != 0,
		"AC1: ranks 1-4 derive the complete four-rank mask")
	_check(launch_mask != 0 and launch_mask != full_mask and launch_mask == StitchedParts.rank_mask([2, 3, 4])
		and not StitchedParts.ranks_allowed(launch_mask, 1),
		"AC1: hero ranks 2-4 derive a launch mask that still excludes rank 1")
	_check(str(part["id"]) == "lantern_monk_head_moth_cloud" and str(part["name"]) == "Moth Cloud"
		and str(part["slot"]) == "head"
		and str(part["owner"]) == "lantern_monk" and part["stat"] == {"crit": 3},
		"AC1: named Moth Cloud keeps its owner, head slot and crit stat")
	_check(str(part["ability"]["id"]) == "lantern_monk_head_moth_cloud_move"
		and str(part["ability"]["name"]) == "Moth Cloud"
		and str(part["ability"]["kind"]) == "debuff"
		and part["ability"]["launch"] == rear_launch
		and int(part["ability"]["launch_mask"]) == launch_mask
		and part["ability"]["target"] == [1, 2, 3, 4]
		and int(part["ability"]["target_mask"]) == full_mask
		and str(part["ability"]["target_side"]) == "enemy" and bool(part["ability"]["multi"])
		and int(part["ability"]["acc"]) == 90 and part["ability"]["dmg"] == [0, 0]
		and int(part["ability"]["crit"]) == 0 and int(part["ability"]["mark_damage"]) == 0
		and part["ability"]["effects"] == {"blind": 1} and int(part["ability"]["self_move"]) == 0
		and str(part["ability"]["move"]) == "skill",
		"AC1: Moth Cloud launches from [2,3,4] with enemy multi Blind, ACC 90 and its skill pose")
	_check(str(part["text"]) == MOTH_CLOUD_COPY,
		"AC1: Moth Cloud's base text is the authored sewn-cloth sentence, not a combat promise")
	var expected_acc := {1: 90, 2: 95, 3: 100}
	var expected_effects := {1: {"blind": 1}, 2: {"blind": 1}, 3: {"blind": 1, "exposed": 1}}
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var valid := StitchedParts.validate_ability(ability)
		_check(bool(valid.get("ok", false)), "AC2: Moth Cloud tier %d ability validates" % tier)
		if not bool(valid.get("ok", false)):
			continue
		var checked: Dictionary = valid["ability"]
		_check(int(checked["acc"]) == int(expected_acc[tier])
			and checked["effects"] == expected_effects[tier],
			"AC2: Moth Cloud tier %d keeps its authored ACC and Blind/Exposed values" % tier)
		_check(bool(checked["multi"]) and str(checked["target_side"]) == "enemy"
			and str(checked["move"]) == "skill" and checked["dmg"] == [0, 0]
			and checked["launch"] == rear_launch
			and int(checked["launch_mask"]) == launch_mask,
			"AC2: Moth Cloud tier %d stays a multi enemy ability launched from ranks 2-4" % tier)
		for rank in [2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC2: Moth Cloud tier %d may launch from hero rank %d" % [tier, rank])
		_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), 1),
			"AC2: Moth Cloud tier %d is still forbidden from hero rank 1" % tier)
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC2: Moth Cloud tier %d never allows hero rank %d" % [tier, rank])
		_check(int(checked["target_mask"]) == full_mask,
			"AC2: Moth Cloud tier %d target mask is exactly ranks 1-4" % tier)
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC2: Moth Cloud tier %d includes enemy rank %d" % [tier, rank])
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC2: Moth Cloud tier %d excludes enemy rank %d" % [tier, rank])
		_check(StitchedParts.stat_at_tier(part, tier) == {"crit": 3},
			"AC2: Moth Cloud tier %d keeps its authored crit stat" % tier)
	_check(part["ability"]["launch"] == rear_launch and part["ability"]["target"] == [1, 2, 3, 4]
		and int(part["ability"]["acc"]) == 90 and part["ability"]["effects"] == {"blind": 1},
		"AC2: tier reads never replace Moth Cloud's base fields in memory")
	var off_rank: Dictionary = part.duplicate(true)
	off_rank["ability"]["target"] = [1, 2, 3, 4, 5]
	_check(not bool(StitchedParts.validate_part(off_rank).get("ok", false)),
		"AC3: Moth Cloud with target rank 5 fails closed")
	var repeated: Dictionary = part.duplicate(true)
	repeated["ability"]["target"] = [1, 2, 3, 4, 4]
	_check(not bool(StitchedParts.validate_part(repeated).get("ok", false)),
		"AC3: Moth Cloud with a duplicated rank 4 fails closed")
	for bad_launch in [[2, 3, 4, 4], [2, 3, 4, 5], [0, 2, 3, 4]]:
		var copy: Dictionary = part.duplicate(true)
		copy["ability"]["launch"] = bad_launch
		_check(not bool(StitchedParts.validate_part(copy).get("ok", false)),
			"AC3: copied Moth Cloud launch %s still fails validation" % str(bad_launch))


func _test_each_tier() -> void:
	var hits: Dictionary = {}
	for id in IDS:
		hits[id] = 0
		for tier in [1, 2, 3]:
			var b := _battle(id, tier, 500041 + tier)
			if b == null or not _to(b, "lantern_monk"):
				_check(false, "AC2: scheduled Lantern Monk turn for %s tier %d" % [id, tier])
				continue
			var part: Dictionary = _catalog()["by_id"][id]
			var ability: Dictionary = StitchedParts.ability_at_tier(part, tier)
			var before := b.state_snapshot()
			var result := b.use_part(id, 1)
			_check(bool(result.get("ok", false)) and str(result.get("part", "")) == id
				and str(result.get("actor", "")) == "lantern_monk"
				and str(result.get("ability", "")) == str(ability["id"]),
				"AC2: actual equipped part executes from legal rank at tier %d: %s" % [tier, id])
			if not bool(result.get("ok", false)):
				continue
			var receipts: Array = result.get("results", [])
			_check(not receipts.is_empty() and before != b.state_snapshot(),
				"AC2: real battle state and nonempty target receipts for " + id)
			if bool(ability["multi"]):
				var expected_count := 3 if str(ability["target_side"]) == "enemy" else 4
				var targets: Dictionary = {}
				for receipt in receipts:
					targets[str(receipt["target"])] = true
				_check(receipts.size() == expected_count and targets.size() == expected_count,
					"AC2: native multi resolves all real targets once for " + id)
			else:
				_check(receipts.size() == 1, "AC2: non-multi ability resolves exactly one target for " + id)
			for receipt in receipts:
				if bool(receipt.get("hit", false)):
					hits[id] += 1
					for effect in ability["effects"]:
						if str(effect) == "duration":
							continue
						_check(receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == str(effect)),
							"AC2: actual landed effect %s appears in receipt for %s" % [effect, id])
					if str(ability["target_side"]) == "enemy":
						_check(int(b.get_unit(str(receipt["target"]))["statuses"].get("blind", 0)) > 0,
							"AC2: Blind lives on enemy battle state following the hit " + id)
			if id == ALTERNATES["legs"]:
				_check(int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0,
					"AC2: targeted Moth Shroud creates actual temporary Dodge on rank-1 ally")
			if id == STARTERS["legs"]:
				_check(str(b.get_unit("lantern_monk")["guard_target"]) == "warden",
					"AC2: Pole Shelter assigns the actual Guard target")
	for id in IDS:
		_check(int(hits[id]) > 0, "AC2: nonvacuous tier I-III hit/effect witness for " + id)


func _test_multi_blind() -> void:
	var witness := false
	for seed_value in range(500130, 500160):
		var b := _battle(ALTERNATES["head"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var cast := b.use_part(ALTERNATES["head"], 1)
		if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
			continue
		var affected := 0
		var seen: Dictionary = {}
		for receipt in cast["results"]:
			seen[str(receipt["target"])] = true
			if int(b.get_unit(str(receipt["target"]))["statuses"].get("blind", 0)) > 0:
				affected += 1
		witness = seen.has("fray_scavenger") and seen.has("scissor_crab") and seen.has("moth_scribe") and affected == 3
		if witness:
			break
	_check(witness, "AC2: real Moth Cloud Blinds all three distinct living foes via multi receipts")



func _test_blind_next_attack() -> void:
	var witnessed := false
	for seed_value in range(500380, 500420):
		var b := _battle(STARTERS["head"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var blink := b.use_part(STARTERS["head"], 1)
		if not bool(blink.get("ok", false)) or blink.get("results", []).is_empty():
			continue
		if not bool(blink["results"][0].get("hit", false)):
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var before := int(b.get_unit("warden")["hp"])
		var strike := b.use_foe_ability("sack_swing", 1)
		if not bool(strike.get("ok", false)) or strike.get("results", []).is_empty():
			continue
		var receipt: Dictionary = strike["results"][0]
		witnessed = bool(receipt.get("blinded", false)) and not bool(receipt.get("hit", true))
		witnessed = witnessed and not receipt.has("roll") and int(b.get_unit("warden")["hp"]) == before
		witnessed = witnessed and not b.get_unit("fray_scavenger")["statuses"].has("blind")
		if witnessed:
			break
	_check(witnessed, "AC2: real Blind survives target's turn start, cancels its next attack without hit roll, then is consumed")


func _test_real_healing() -> void:
	for id in [STARTERS["torso"], ALTERNATES["torso"]]:
		var witnessed := false
		for seed_value in range(500200, 500245):
			var b := _battle(id, 2, seed_value)
			if b == null or not _to(b, "fray_scavenger"):
				continue
			var before := int(b.get_unit("warden")["hp"])
			var strike := b.use_foe_ability("sack_swing", 1)
			var wounded := int(b.get_unit("warden")["hp"])
			if not bool(strike.get("ok", false)) or wounded >= before or not _to(b, "lantern_monk"):
				continue
			var other_hp := int(b.get_unit("seamstress")["hp"])
			var heal := b.use_part(id, 1)
			var after := int(b.get_unit("warden")["hp"])
			if not bool(heal.get("ok", false)) or heal.get("results", []).size() != 4:
				continue
			var restored_receipt := false
			for receipt in heal["results"]:
				if str(receipt["target"]) == "warden":
					restored_receipt = receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "heal" and int(s.get("amount", 0)) > 0)
			witnessed = after > wounded and restored_receipt
			witnessed = witnessed and int(b.get_unit("seamstress")["hp"]) == other_hp
			if id == ALTERNATES["torso"]:
				witnessed = witnessed and int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0
				witnessed = witnessed and heal["results"][0]["statuses"].any(func(s): return str(s.get("status", "")) == "dodge")
			if witnessed:
				break
		_check(witnessed, "AC2: genuine foe wound is restored by four-target %s with real heal/defence receipts" % id)


## A real seeded 4v3 battle in the shipped preview order (Lantern Monk in hero rank 4) with
## the starter Lamplight Wash genuinely equipped in his torso. The Fray Scavenger's own attack
## opens a real wound; then the Monk's scheduled turn heals exactly one receipt per living
## allied rank at his stitch tier. A bounded seed list supplies the authentic hit.
func _test_rank4_lamplight_heal(
	tier: int, seed_start: int, seed_count: int, expected_heal: int, label: String
) -> void:
	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle("", tier, seed_value, true)
		if b == null:
			continue
		if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var strike := b.use_foe_ability("sack_swing", 1)
		if not bool(strike.get("ok", false)) or strike.get("results", []).is_empty():
			continue
		if not bool(strike["results"][0].get("hit", false)):
			continue
		var wounded := str(strike["results"][0].get("target", ""))
		if wounded.is_empty() or bool(b.get_unit(wounded).get("lost", false)):
			continue
		if not _to(b, "lantern_monk"):
			continue
		if int(b.get_unit("lantern_monk")["rank"]) != 4:
			continue
		if int(b.get_unit(wounded)["hp"]) >= int(b.get_unit(wounded)["max_hp"]):
			continue
		var living := {}
		for hero in b.get_heroes():
			if not bool(hero["lost"]):
				living[str(hero["id"])] = {
					"hp": int(hero["hp"]),
					"max_hp": int(hero["max_hp"]),
					"rank": int(hero["rank"]),
				}
		if living.size() != 4 or not living.has(wounded):
			continue
		var before := b.state_snapshot()
		var heal := b.use_part(STARTERS["torso"], 1)
		if not bool(heal.get("ok", false)):
			continue
		witnessed = true
		var after := b.state_snapshot()
		var receipts: Array = heal.get("results", [])
		var targets := {}
		for receipt in receipts:
			targets[str(receipt["target"])] = true
		_check(str(heal.get("action", "")) == "ability"
			and str(heal.get("actor", "")) == "lantern_monk"
			and str(heal.get("part", "")) == STARTERS["torso"]
			and str(heal.get("ability", "")) == "lantern_monk_torso_lamplight_wash_move",
			"%s: hero rank 4 Lamplight Wash runs as the equipped Monk torso part (seed %d)"
				% [label, seed_value])
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"%s: the acting Monk really stands in hero rank 4 (seed %d)" % [label, seed_value])
		_check(receipts.size() == 4 and targets.size() == 4
			and targets.has(wounded) and targets.keys().all(func(id): return living.has(str(id))),
			"%s: exactly one ally heal receipt per living allied rank 1-4 (seed %d)"
				% [label, seed_value])
		var all_correct := true
		for receipt in receipts:
			var id := str(receipt["target"])
			if not living.has(id):
				all_correct = false
				continue
			var healed_by := int(b.get_unit(id)["hp"]) - int(living[id]["hp"])
			var cap := int(living[id]["max_hp"]) - int(living[id]["hp"])
			var expected := mini(expected_heal, cap)
			var heal_status := false
			for status in receipt.get("statuses", []):
				if str(status.get("status", "")) == "heal" and int(status.get("amount", -1)) == expected:
					heal_status = true
			all_correct = all_correct and bool(receipt.get("hit", false)) \
				and healed_by == expected and heal_status
		_check(all_correct,
			"%s: every living ally is mended by exactly %d HP up to its max (seed %d)"
				% [label, expected_heal, seed_value])
		var wounded_gain := int(b.get_unit(wounded)["hp"]) - int(living[wounded]["hp"])
		_check(wounded_gain == mini(expected_heal, int(living[wounded]["max_hp"]) - int(living[wounded]["hp"]))
			and wounded_gain > 0,
			"%s: the real foe wound is genuinely restored on the wounded ally (seed %d)"
				% [label, seed_value])
		var advanced := int(after["round"]) > int(before["round"]) \
			or (int(after["round"]) == int(before["round"]) and int(after["turn_index"]) > int(before["turn_index"]))
		_check(advanced and after != before,
			"%s: the heal spends the Monk's genuine turn and changes real battle state (seed %d)"
				% [label, seed_value])
		break
	_check(witnessed, "%s: a real seeded rank-4 Lamplight Wash heals the wounded four-hero party" % label)


## A real seeded 4v3 battle in the shipped preview order (Lantern Monk in hero rank 4) with
## Moth Cloud genuinely equipped in his head. On his scheduled turn the authored multi-target
## ability actually launches from the rear rank and resolves every living foe separately, with
## Blind carried in both the receipt and battle state on hits. The same seed and the same
## action replay to an identical receipt, snapshot and RNG position.
func _test_rank4_moth_cloud(tier: int, seed_start: int, seed_count: int, label: String) -> void:
	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle(ALTERNATES["head"], tier, seed_value, true)
		if b == null:
			continue
		if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var living: Dictionary = {}
		for foe in b.get_foes():
			if not bool(foe["lost"]):
				living[str(foe["id"])] = int(foe["hp"])
		if living.size() != 3:
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(ALTERNATES["head"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 3:
			continue
		var targets: Dictionary = {}
		var hits := 0
		var blinding_hits := 0
		for receipt in receipts:
			var target := str(receipt["target"])
			targets[target] = true
			if not bool(receipt.get("hit", false)):
				continue
			hits += 1
			var receipt_blind: bool = receipt.get("statuses", []).any(
				func(status): return str(status.get("status", "")) == "blind"
			)
			if receipt_blind and int(b.get_unit(target)["statuses"].get("blind", 0)) > 0:
				blinding_hits += 1
		if hits < 1 or blinding_hits != hits:
			continue
		if targets.size() != 3 or not targets.keys().all(func(id): return living.has(str(id))):
			continue
		witnessed = true
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "lantern_monk"
			and str(cast.get("part", "")) == ALTERNATES["head"]
			and str(cast.get("ability", "")) == "lantern_monk_head_moth_cloud_move",
			"%s: hero rank 4 Moth Cloud runs as the equipped Monk head part (seed %d)"
				% [label, seed_value])
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"%s: the acting Monk really looses the cloud from hero rank 4 (seed %d)"
				% [label, seed_value])
		_check(receipts.size() == 3 and targets.size() == 3,
			"%s: one distinct foe result per living enemy rank 1-3 (seed %d)"
				% [label, seed_value])
		_check(hits > 0 and blinding_hits == hits,
			"%s: every landed moth cloud hit carries a real Blind status (seed %d)"
				% [label, seed_value])
		var after := b.state_snapshot()
		var advanced := int(after["round"]) > int(before["round"]) \
			or (int(after["round"]) == int(before["round"]) and int(after["turn_index"]) > int(before["turn_index"]))
		_check(advanced and after != before,
			"%s: the cast spends the Monk's genuine turn and changes real battle state (seed %d)"
				% [label, seed_value])
		var replay := _battle(ALTERNATES["head"], tier, seed_value, true)
		if replay == null or not _to(replay, "lantern_monk"):
			_check(false, "%s: same-seed replay reached the Monk's turn (seed %d)" % [label, seed_value])
		else:
			var replayed := replay.use_part(ALTERNATES["head"], 1)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"%s: same-seed rank-4 Moth Cloud replays receipt, snapshot and RNG (seed %d)"
					% [label, seed_value])
		break
	_check(witnessed, "%s: a real seeded rank-4 Moth Cloud Blinds the living enemy line" % label)


## A real seeded 4v3 battle in the shipped preview order (Lantern Monk in hero rank 4) with
## the starter Wick Spark genuinely equipped in his arms. On his scheduled turn the authored
## ranged spark launches from the rear rank at the living rank-1 foe, deals real HP damage and
## carries Blind in the receipt and battle state. A miss only consumes the turn, so a bounded
## seed list supplies the confirmed witness; the same seed replays identically.
func _test_rank4_wick_spark(tier: int, seed_start: int, seed_count: int) -> void:
	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle("", tier, seed_value, true)
		if b == null:
			continue
		if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var monk := b.get_unit("lantern_monk")
		if str(monk["parts"]["arms"]["id"]) != STARTERS["arms"]:
			continue
		var foe_before := b.get_unit("fray_scavenger")
		if foe_before.is_empty() or int(foe_before.get("rank", -1)) != 1 \
				or bool(foe_before.get("dead", false)) or int(foe_before["hp"]) <= 0:
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(STARTERS["arms"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 1:
			continue
		var receipt: Dictionary = receipts[0]
		if not bool(receipt.get("hit", false)) or str(receipt.get("target", "")) != "fray_scavenger" \
				or str(receipt.get("target_side", "")) != "foe" or int(receipt.get("target_rank", -1)) != 1:
			continue  # a legal missile may still miss; keep searching for a genuine hit
		var receipt_blind: bool = receipt.get("statuses", []).any(
			func(status): return str(status.get("status", "")) == "blind"
		)
		if not receipt_blind:
			continue
		var foe_after := b.get_unit("fray_scavenger")
		var lost_hp := int(foe_before["hp"]) - int(foe_after["hp"])
		if lost_hp <= 0 or bool(foe_after.get("dead", false)) \
				or int(foe_after["statuses"].get("blind", 0)) <= 0:
			continue
		witnessed = true
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "lantern_monk"
			and str(cast.get("part", "")) == STARTERS["arms"]
			and str(cast.get("ability", "")) == "lantern_monk_arms_wick_spark_move",
			"AC2: hero rank 4 Wick Spark runs as the equipped Monk arms part (seed %d)" % seed_value)
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"AC2: the acting Monk really flings the spark from hero rank 4 (seed %d)" % seed_value)
		_check(receipts.size() == 1 and int(receipt["damage"]) == lost_hp
			and int(receipt["target_hp"]) == int(foe_after["hp"]),
			"AC2: one enemy receipt carries the real damage dealt to the living rank-1 foe (seed %d)"
				% seed_value)
		_check(receipt.get("statuses", []).any(
				func(status): return str(status.get("status", "")) == "blind")
			and int(foe_after["statuses"].get("blind", 0)) > 0,
			"AC2: the landed spark Blinds the foe in both the receipt and actual battle state (seed %d)"
				% seed_value)
		var after := b.state_snapshot()
		var advanced_once := (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) == int(before["turn_index"]) + 1) \
			or int(after["round"]) == int(before["round"]) + 1
		_check(advanced_once and after != before,
			"AC2: the rank-4 cast advances exactly one turn and changes real battle state (seed %d)"
				% seed_value)
		var replay := _battle("", tier, seed_value, true)
		if replay == null or not _to(replay, "lantern_monk"):
			_check(false, "AC2: same-seed rank-4 Wick Spark replay reached the Monk's turn (seed %d)"
				% seed_value)
		else:
			var replayed := replay.use_part(STARTERS["arms"], 1)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"AC2: same-seed rank-4 Wick Spark replays receipt, snapshot and RNG (seed %d)"
					% seed_value)
		break
	_check(witnessed,
		"AC2: a real seeded rank-4 Wick Spark damages and Blinds the living rank-1 foe")


## S4 upgrade: upgraded Wick Spark still Blinds the foe it lands on and now also Exposes a
## seam. A real seeded 4v3 battle with the Monk in hero rank 2 casts the actually equipped arms
## part at the living rank-1 foe. A genuine hit must leave Blind 1 plus Exposed 1 at tier II or
## Exposed 2 at tier III on that same foe; tier I remains a Blind-only witness. The same seed
## and action replay to identical receipt, snapshot and RNG position.
func _test_wick_spark_exposed_seam(
	tier: int, seed_start: int, seed_count: int, expected_exposed: int
) -> void:
	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle(STARTERS["arms"], tier, seed_value)
		if b == null:
			continue
		if str(b.get_unit("lantern_monk")["parts"]["arms"]["id"]) != STARTERS["arms"]:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var foe_before := b.get_unit("fray_scavenger")
		if foe_before.is_empty() or int(foe_before.get("rank", -1)) != 1 \
				or bool(foe_before.get("dead", false)) or int(foe_before["hp"]) <= 0:
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(STARTERS["arms"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 1:
			continue
		var receipt: Dictionary = receipts[0]
		if not bool(receipt.get("hit", false)) or str(receipt.get("target", "")) != "fray_scavenger":
			continue  # a legal spark may still miss; keep searching for a genuine hit
		var statuses: Array = receipt.get("statuses", [])
		var receipt_blind := statuses.any(
			func(status): return str(status.get("status", "")) == "blind" \
				and int(status.get("duration", 0)) == 1)
		var receipt_exposed := statuses.filter(
			func(status): return str(status.get("status", "")) == "exposed")
		if not receipt_blind:
			continue
		if expected_exposed == 0:
			if not receipt_exposed.is_empty():
				continue
		elif receipt_exposed.size() != 1 \
				or int(receipt_exposed[0].get("duration", 0)) != expected_exposed:
			continue
		var foe_after := b.get_unit("fray_scavenger")
		if int(foe_after["statuses"].get("blind", 0)) != 1:
			continue
		if int(foe_after["statuses"].get("exposed", 0)) != expected_exposed:
			continue
		if int(foe_after["hp"]) >= int(foe_before["hp"]):
			continue
		witnessed = true
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "lantern_monk"
			and str(cast.get("part", "")) == STARTERS["arms"]
			and str(cast.get("ability", "")) == "lantern_monk_arms_wick_spark_move",
			"AC2: hero rank 2 Wick Spark tier %d runs as the equipped Monk arms part (seed %d)"
				% [tier, seed_value])
		_check(str(receipt.get("target_side", "")) == "foe"
			and int(receipt.get("target_rank", -1)) == 1,
			"AC2: Wick Spark tier %d lands on exactly one living rank-1 foe (seed %d)"
				% [tier, seed_value])
		_check(receipt_blind and (expected_exposed == 0 or receipt_exposed.size() == 1),
			"AC2: Wick Spark tier %d receipt carries Blind 1%s (seed %d)"
				% [tier, " and Exposed %d" % expected_exposed if expected_exposed > 0 else "", seed_value])
		_check(int(foe_after["statuses"].get("blind", 0)) == 1
			and int(foe_after["statuses"].get("exposed", 0)) == expected_exposed
			and (expected_exposed > 0 or not foe_after["statuses"].has("exposed")),
			"AC2: the real foe immediately holds Blind 1%s after the landed spark (tier %d, seed %d)"
				% [" and Exposed %d" % expected_exposed if expected_exposed > 0 else "", tier, seed_value])
		var after := b.state_snapshot()
		var advanced_once := (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) == int(before["turn_index"]) + 1) \
			or int(after["round"]) == int(before["round"]) + 1
		_check(advanced_once and after != before,
			"AC2: the upgraded spark spends exactly one turn and changes real battle state (tier %d, seed %d)"
				% [tier, seed_value])
		var replay := _battle(STARTERS["arms"], tier, seed_value)
		if replay == null or not _to(replay, "lantern_monk"):
			_check(false, "AC2: same-seed Wick Spark tier %d replay reached the Monk's turn (seed %d)"
				% [tier, seed_value])
		else:
			var replayed := replay.use_part(STARTERS["arms"], 1)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"AC2: same-seed Wick Spark tier %d replays receipt, snapshot and RNG (seed %d)"
					% [tier, seed_value])
		break
	_check(witnessed,
		"AC2: a real seeded rank-2 Wick Spark tier %d lands Blind 1 with Exposed %d"
			% [tier, expected_exposed])


## AC3: a legal Wick Spark cast that misses still spends the turn but applies neither Blind nor
## the upgraded Exposed seam. A bounded seed window supplies a genuine miss from the real part.
func _test_wick_spark_miss_no_seam(tier: int, seed_start: int, seed_count: int) -> void:
	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle(STARTERS["arms"], tier, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		if str(b.get_unit("lantern_monk")["parts"]["arms"]["id"]) != STARTERS["arms"]:
			continue
		var foe_before := b.get_unit("fray_scavenger")
		if foe_before.is_empty() or int(foe_before.get("rank", -1)) != 1 \
				or bool(foe_before.get("dead", false)) or int(foe_before["hp"]) <= 0:
			continue
		var prior_blind := int(foe_before["statuses"].get("blind", 0))
		var prior_exposed := int(foe_before["statuses"].get("exposed", 0))
		if prior_blind > 0 or prior_exposed > 0:
			continue  # keep searching for a clean miss witness with no prior seam status
		var before := b.state_snapshot()
		var cast := b.use_part(STARTERS["arms"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 1 or str(receipts[0].get("target", "")) != "fray_scavenger":
			continue
		var receipt: Dictionary = receipts[0]
		if bool(receipt.get("hit", true)):
			continue  # keep searching for a genuine miss
		witnessed = true
		var foe_after := b.get_unit("fray_scavenger")
		_check(not receipt.get("statuses", []).any(func(status):
				return str(status.get("status", "")) in ["blind", "exposed"]),
			"AC3: a missed Wick Spark tier %d receipt carries no Blind or Exposed (seed %d)"
				% [tier, seed_value])
		_check(not foe_after["statuses"].has("blind")
			and not foe_after["statuses"].has("exposed"),
			"AC3: a missed Wick Spark tier %d leaves no Blind or Exposed on the foe (seed %d)"
				% [tier, seed_value])
		_check(int(foe_after["hp"]) == int(foe_before["hp"]),
			"AC3: the missed spark deals no damage to the living rank-1 foe (seed %d)" % seed_value)
		var after := b.state_snapshot()
		var advanced_once := (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) == int(before["turn_index"]) + 1) \
			or int(after["round"]) == int(before["round"]) + 1
		_check(advanced_once and after != before,
			"AC3: the missed spark spends exactly one turn without status gain (tier %d, seed %d)"
				% [tier, seed_value])
		break
	_check(witnessed, "AC3: a real seeded Wick Spark tier %d miss applies neither status" % tier)


## S4 completion: Moth Wink's authored launch list gains hero rank 4, so the starter head can
## Blind one foe from the rear of a four-doll party. Its target list stays exactly enemy ranks
## 1-3 (Moth Cloud remains the multi-foe rank-4 alternate), and its single-target "skill" pose,
## slot stat and tier ACC/statuses are otherwise unchanged. A real seeded 4v3 preview with the
## Monk in rank 4 proves the equipped head casts and lands Blind (plus Exposed at tier III);
## illegal ranks still refuse without spending the turn, state or seeded RNG.
func _test_moth_wink_rank4(tier: int, seed_start: int, seed_count: int) -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog with Moth Wink's rank-4 launch validates (tier %d)" % tier)
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][STARTERS["head"]]
	var full_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	var target_mask := StitchedParts.rank_mask([1, 2, 3])
	var expected_acc := {1: 90, 2: 94, 3: 100}
	_check(full_mask == StitchedParts.ALL_RANKS_MASK and full_mask != 0,
		"AC1: ranks 1-4 derive the complete four-rank mask for Moth Wink")
	_check(str(part["id"]) == "lantern_monk_head_moth_wink"
		and str(part["name"]) == "Mothlit Brow Patch"
		and str(part["slot"]) == "head" and str(part["owner"]) == "lantern_monk"
		and part["stat"] == {"acc": 3}
		and str(part["text"]) == MOTH_WINK_COPY,
		"AC1: Mothlit Brow Patch keeps its head slot, owner, +3 ACC stat and short patch copy")
	var ability := StitchedParts.ability_at_tier(part, tier)
	var valid := StitchedParts.validate_ability(ability)
	_check(bool(valid.get("ok", false)), "AC1: Moth Wink tier %d ability validates" % tier)
	if not bool(valid.get("ok", false)):
		return
	var checked: Dictionary = valid["ability"]
	_check(checked["launch"] == [1, 2, 3, 4]
		and int(checked["launch_mask"]) == full_mask,
		"AC1: Moth Wink tier %d launches from exactly hero ranks 1-4" % tier)
	for rank in [1, 2, 3, 4]:
		_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
			"AC1: Moth Wink tier %d may launch from hero rank %d" % [tier, rank])
	for rank in [0, 5]:
		_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
			"AC1: Moth Wink tier %d never allows hero rank %d" % [tier, rank])
	_check(checked["target"] == [1, 2, 3]
		and int(checked["target_mask"]) == target_mask
		and str(checked["target_side"]) == "enemy" and not bool(checked["multi"]),
		"AC1: Moth Wink tier %d stays a single enemy target over ranks 1-3" % tier)
	for rank in [1, 2, 3]:
		_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
			"AC1: Moth Wink tier %d still targets enemy rank %d" % [tier, rank])
	for rank in [0, 4, 5]:
		_check(not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
			"AC1: Moth Wink tier %d never targets rank %d" % [tier, rank])
	_check(int(checked["acc"]) == int(expected_acc[tier])
		and int(checked["effects"].get("blind", 0)) == 1
		and int(checked["effects"].get("exposed", 0)) == (1 if tier == 3 else 0)
		and checked["dmg"] == [0, 0] and int(checked["crit"]) == 0
		and int(checked["self_move"]) == 0 and str(checked["move"]) == "skill",
		"AC1: Moth Wink tier %d keeps ACC %d, Blind 1%s and its skill pose"
			% [tier, int(expected_acc[tier]), " and Exposed 1" if tier == 3 else ""])
	_check(StitchedParts.stat_at_tier(part, tier) == {"acc": 3},
		"AC1: Moth Wink tier %d keeps its authored slot stat" % tier)

	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle(STARTERS["head"], tier, seed_value, true)
		if b == null:
			continue
		if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
			continue
		if str(b.get_unit("lantern_monk")["parts"]["head"]["id"]) != STARTERS["head"]:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var living: Dictionary = {}
		for foe in b.get_foes():
			if not bool(foe["lost"]) and int(foe["hp"]) > 0:
				living[str(foe["id"])] = int(foe["rank"])
		if living.size() != 3 or not living.values().has(1):
			continue
		var target_id := ""
		for foe_id in living:
			if int(living[foe_id]) == 1:
				target_id = str(foe_id)
				break
		if target_id.is_empty():
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(STARTERS["head"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 1:
			continue
		var receipt: Dictionary = receipts[0]
		if not bool(receipt.get("hit", false)) or str(receipt.get("target", "")) != target_id:
			continue  # a legal cast may still miss; keep searching for a genuine hit
		if str(receipt.get("target_side", "")) != "foe" or int(receipt.get("target_rank", -1)) != 1:
			continue
		var foe_after := b.get_unit(target_id)
		if not receipt.get("statuses", []).any(
				func(status): return str(status.get("status", "")) == "blind"):
			continue
		if int(foe_after["statuses"].get("blind", 0)) != 1:
			continue
		if tier == 3:
			if not receipt.get("statuses", []).any(
					func(status): return str(status.get("status", "")) == "exposed"):
				continue
			if int(foe_after["statuses"].get("exposed", 0)) != 1:
				continue
		witnessed = true
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "lantern_monk"
			and str(cast.get("part", "")) == STARTERS["head"]
			and str(cast.get("ability", "")) == "lantern_monk_head_moth_wink_move",
			"AC2: hero rank 4 Moth Wink runs as the equipped Monk head part (tier %d, seed %d)"
				% [tier, seed_value])
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"AC2: the acting Monk really winks from hero rank 4 (tier %d, seed %d)"
				% [tier, seed_value])
		_check(receipts.size() == 1 and str(receipt.get("target_side", "")) == "foe"
			and int(receipt.get("target_rank", -1)) == 1 and living.has(target_id),
			"AC2: exactly one living rank-1 foe is blinded, never a rank-4 target (tier %d, seed %d)"
				% [tier, seed_value])
		_check(int(foe_after["statuses"].get("blind", 0)) == 1
			and (tier != 3 or int(foe_after["statuses"].get("exposed", 0)) == 1),
			"AC2: the landed wink leaves Blind 1%s on the real foe (tier %d, seed %d)"
				% [", Exposed 1" if tier == 3 else "", tier, seed_value])
		var after := b.state_snapshot()
		var advanced_once := (int(after["round"]) == int(before["round"])
				and int(after["turn_index"]) == int(before["turn_index"]) + 1) \
			or int(after["round"]) == int(before["round"]) + 1
		_check(advanced_once and after != before,
			"AC2: the rank-4 wink spends exactly one turn and changes real battle state (tier %d, seed %d)"
				% [tier, seed_value])
		var replay := _battle(STARTERS["head"], tier, seed_value, true)
		if replay == null or not _to(replay, "lantern_monk"):
			_check(false, "AC2: same-seed rank-4 Moth Wink replay reached the Monk's turn (tier %d, seed %d)"
				% [tier, seed_value])
		else:
			var replayed := replay.use_part(STARTERS["head"], 1)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"AC2: same-seed rank-4 Moth Wink replays receipt, snapshot and RNG (tier %d, seed %d)"
					% [tier, seed_value])
		break
	_check(witnessed,
		"AC2: a real seeded rank-4 Moth Wink Blinds the living rank-1 foe (tier %d)" % tier)

	var reject_b := _battle(STARTERS["head"], tier, seed_start, true)
	if reject_b == null or not _to(reject_b, "lantern_monk"):
		_check(false, "AC3: Moth Wink rejection witness receives a real scheduled turn (tier %d)" % tier)
	else:
		_check(int(reject_b.get_unit("lantern_monk")["rank"]) == 4
			and str(reject_b.get_unit("lantern_monk")["parts"]["head"]["id"]) == STARTERS["head"],
			"AC3: Moth Wink rejection witness really stands in hero rank 4 with it equipped (tier %d)" % tier)
		_reject_without_spend(reject_b, STARTERS["head"], 4, "Moth Wink target rank 4 outside its 1-3 list")
		_reject_without_spend(reject_b, STARTERS["head"], 0, "Moth Wink out-of-range target rank 0")
		_reject_without_spend(reject_b, STARTERS["head"], 5, "Moth Wink out-of-range target rank 5")


## S4 completion: Moth Shroud's base launch list gains hero rank 4, so the Monk's alternate
## legs can shelter one ally from the rear rank. Its target list already reaches allied ranks
## 1-4; tier II/III only raise the Dodge amount and inherit the new base launch. A real seeded
## 4v3 preview with the Monk in rank 4 proves the authored part casts on the rank-1 Warden.
func _test_rank4_moth_shroud(
	tier: int, seed_start: int, seed_count: int, expected_dodge: int, label: String
) -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "%s: catalog with Moth Shroud's rank-4 launch validates" % label)
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][ALTERNATES["legs"]]
	var rear_launch := [2, 3, 4]
	var launch_mask := StitchedParts.rank_mask(rear_launch)
	var full_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	_check(launch_mask != 0 and launch_mask != full_mask
		and launch_mask == (StitchedParts.ALL_RANKS_MASK & ~(1 << 1))
		and not StitchedParts.ranks_allowed(launch_mask, 1),
		"%s: hero ranks 2-4 derive a launch mask that still excludes rank 1" % label)
	_check(str(part["id"]) == "lantern_monk_legs_moth_shroud"
		and str(part["name"]) == "Moth Shroud" and str(part["slot"]) == "legs"
		and str(part["owner"]) == "lantern_monk" and part["stat"] == {"speed": 1, "dodge": 4},
		"%s: Moth Shroud keeps its name, legs slot, owner and +1 SPEED/+4 DODGE stat" % label)
	var ability := StitchedParts.ability_at_tier(part, tier)
	var valid := StitchedParts.validate_ability(ability)
	_check(bool(valid.get("ok", false)), "%s: Moth Shroud tier %d ability validates" % [label, tier])
	if not bool(valid.get("ok", false)):
		return
	var checked: Dictionary = valid["ability"]
	_check(str(checked["id"]) == "lantern_monk_legs_moth_shroud_move"
		and str(checked["name"]) == "Moth Shroud" and str(checked["kind"]) == "buff"
		and checked["launch"] == rear_launch and int(checked["launch_mask"]) == launch_mask
		and checked["target"] == [1, 2, 3, 4] and int(checked["target_mask"]) == full_mask
		and str(checked["target_side"]) == "ally" and not bool(checked["multi"])
		and int(checked["acc"]) == 100 and checked["dmg"] == [0, 0] and int(checked["crit"]) == 0
		and int(checked["mark_damage"]) == 0
		and int(checked["effects"].get("dodge", 0)) == expected_dodge
		and int(checked["effects"].get("duration", 0)) == 2
		and int(checked["self_move"]) == 0 and str(checked["move"]) == "guard",
		"%s: Moth Shroud tier %d launches from [2,3,4] at one ally with Dodge %d for two turns"
			% [label, tier, expected_dodge])
	for rank in [2, 3, 4]:
		_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
			"%s: Moth Shroud tier %d may launch from hero rank %d" % [label, tier, rank])
	for rank in [0, 1, 5]:
		_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
			"%s: Moth Shroud tier %d never launches from rank %d" % [label, tier, rank])
	for rank in [1, 2, 3, 4]:
		_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
			"%s: Moth Shroud tier %d reaches allied rank %d" % [label, tier, rank])
	for rank in [0, 5]:
		_check(not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
			"%s: Moth Shroud tier %d never targets rank %d" % [label, tier, rank])
	_check(StitchedParts.stat_at_tier(part, tier) == {"speed": 1, "dodge": 4},
		"%s: Moth Shroud tier %d keeps its authored slot stat" % [label, tier])
	_check(str(part["text"]) == MOTH_SHROUD_COPY,
		"%s: Moth Shroud describes its sewn plum moth patch, not a combat move" % label)
	_check(part["ability"]["launch"] == rear_launch and part["ability"]["target"] == [1, 2, 3, 4]
		and int(part["ability"]["effects"]["dodge"]) == 10,
		"%s: tier reads never replace Moth Shroud's base fields in memory" % label)

	var witnessed := false
	for seed_value in range(seed_start, seed_start + seed_count):
		var b := _battle(ALTERNATES["legs"], tier, seed_value, true)
		if b == null:
			continue
		if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
			continue
		if str(b.get_unit("lantern_monk")["parts"]["legs"]["id"]) != ALTERNATES["legs"]:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var warden_before := b.get_unit("warden")
		if warden_before.is_empty() or int(warden_before.get("rank", -1)) != 1 \
				or bool(warden_before.get("lost", false)) or int(warden_before["hp"]) <= 0:
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(ALTERNATES["legs"], 1)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 1 or str(receipts[0].get("target", "")) != "warden":
			continue
		var receipt: Dictionary = receipts[0]
		if not bool(receipt.get("hit", false)):
			continue
		var warden_after := b.get_unit("warden")
		var buff: Dictionary = warden_after.get("dodge_buff", {})
		if int(buff.get("amount", 0)) != expected_dodge or int(buff.get("turns", 0)) != 2:
			continue
		witnessed = true
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "lantern_monk"
			and str(cast.get("part", "")) == ALTERNATES["legs"]
			and str(cast.get("ability", "")) == "lantern_monk_legs_moth_shroud_move",
			"%s: hero rank 4 Moth Shroud runs as the equipped Monk legs part (seed %d)"
				% [label, seed_value])
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"%s: the acting Monk really stands in hero rank 4 (seed %d)" % [label, seed_value])
		_check(receipts.size() == 1 and str(receipt.get("target_side", "")) == "hero"
			and int(receipt.get("target_rank", -1)) == 1,
			"%s: exactly one genuine rank-1 ally receipt (seed %d)" % [label, seed_value])
		_check(int(StitchedRules.effective_dodge(warden_after))
			== int(StitchedRules.effective_dodge(warden_before)) + expected_dodge
			and int(warden_after["hp"]) == int(warden_before["hp"])
			and int(receipt.get("damage", -1)) == 0
			and int(warden_after["rank"]) == int(warden_before["rank"]),
			"%s: the Warden really gains Dodge %d with no damage or movement (seed %d)"
				% [label, expected_dodge, seed_value])
		_check(receipt.get("statuses", []).any(func(status): return str(status.get("status", "")) == "dodge" and int(status.get("amount", 0)) == expected_dodge and int(status.get("duration", 0)) == 2),
			"%s: the receipt carries the bounded Dodge status (seed %d)" % [label, seed_value])
		var after := b.state_snapshot()
		var advanced := int(after["round"]) > int(before["round"]) \
			or (int(after["round"]) == int(before["round"]) and int(after["turn_index"]) > int(before["turn_index"]))
		_check(advanced and after != before and b.current_actor_id() != "lantern_monk",
			"%s: the cast spends the Monk's genuine turn and changes real battle state (seed %d)"
				% [label, seed_value])
		var replay := _battle(ALTERNATES["legs"], tier, seed_value, true)
		if replay == null or not _to(replay, "lantern_monk"):
			_check(false, "%s: same-seed replay reached the Monk's turn (seed %d)" % [label, seed_value])
		else:
			var replayed := replay.use_part(ALTERNATES["legs"], 1)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"%s: same-seed rank-4 Moth Shroud replays receipt, snapshot and RNG (seed %d)"
					% [label, seed_value])
		break
	_check(witnessed, "%s: a real seeded rank-4 Moth Shroud shelters the rank-1 Warden" % label)


## AC3: now that Moth Shroud may launch from the rear rank, a genuine rank-1 Monk still refuses
## it, out-of-range ally ranks refuse, and unequipped, torn, stale and malformed copies fail
## closed without spending a turn, changing battle state or advancing seeded RNG.
func _test_moth_shroud_rejections() -> void:
	var b := _battle(ALTERNATES["legs"], 1, 501520, true)
	if b == null or not _to(b, "lantern_monk"):
		_check(false, "AC3: Moth Shroud rejection witness receives a real scheduled turn")
	else:
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4
			and str(b.get_unit("lantern_monk")["parts"]["legs"]["id"]) == ALTERNATES["legs"],
			"AC3: Moth Shroud rejection witness really stands in hero rank 4 with it equipped")
		_reject_without_spend(b, ALTERNATES["legs"], 0, "Moth Shroud out-of-range ally rank 0")
		_reject_without_spend(b, ALTERNATES["legs"], 5, "Moth Shroud out-of-range ally rank 5")
		var cast := b.use_part(ALTERNATES["legs"], 1)
		_check(bool(cast.get("ok", false)) and cast.get("results", []).size() == 1,
			"AC3: the same rank-4 Monk legally casts Moth Shroud once")
		_reject_without_spend(b, ALTERNATES["legs"], 1, "stale off-turn Moth Shroud")

	var plain := _battle("", 1, 501521, true)
	if plain == null or not _to(plain, "lantern_monk"):
		_check(false, "AC3: unequipped Moth Shroud witness receives a real scheduled turn")
	else:
		_check(str(plain.get_unit("lantern_monk")["parts"]["legs"]["id"]) == STARTERS["legs"],
			"AC3: the unequipped witness really has Pole Shelter in the legs slot")
		_reject_without_spend(plain, ALTERNATES["legs"], 1, "unequipped Moth Shroud")

	var torn_config := _config(ALTERNATES["legs"], 1, 501522, true)
	torn_config["heroes"][3]["parts"]["legs"] = {"id": ALTERNATES["legs"], "tier": 1, "torn": true}
	var torn_created := StitchedRules.create(torn_config)
	_check(bool(torn_created.get("ok", false)), "AC3: a real torn Moth Shroud enters a rank-4 battle")
	if bool(torn_created.get("ok", false)):
		var torn: StitchedRules = torn_created["battle"]
		if _to(torn, "lantern_monk"):
			_reject_without_spend(torn, ALTERNATES["legs"], 1, "torn Moth Shroud")
		else:
			_check(false, "AC3: torn Moth Shroud witness receives a real turn")

	var front_config := _config(ALTERNATES["legs"], 1, 501523)
	var monk: Dictionary = front_config["heroes"].pop_at(1)
	front_config["heroes"].insert(0, monk)
	var front_created := StitchedRules.create(front_config)
	_check(bool(front_created.get("ok", false)), "AC3: a real rank-1 Moth Shroud loadout enters battle")
	if bool(front_created.get("ok", false)):
		var front: StitchedRules = front_created["battle"]
		_check(int(front.get_unit("lantern_monk")["rank"]) == 1,
			"AC3: rank-1 Moth Shroud witness really stands in hero rank 1")
		if _to(front, "lantern_monk"):
			_check(str(front.get_unit("lantern_monk")["parts"]["legs"]["id"]) == ALTERNATES["legs"],
				"AC3: the rank-1 witness really has Moth Shroud equipped")
			_reject_without_spend(front, ALTERNATES["legs"], 2, "Moth Shroud forbidden from hero rank 1")
		else:
			_check(false, "AC3: rank-1 Moth Shroud witness receives a real turn")

	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC3: catalog available for copied Moth Shroud validator checks")
	if not bool(cat.get("ok", false)):
		return
	var source: Dictionary = cat["by_id"][ALTERNATES["legs"]]
	for bad_launch in [[2, 3, 4, 4], [2, 3, 4, 5], [0, 2, 3, 4]]:
		var copy: Dictionary = source.duplicate(true)
		copy["ability"]["launch"] = bad_launch
		_check(not bool(StitchedParts.validate_part(copy).get("ok", false)),
			"AC3: copied Moth Shroud launch %s still fails validation" % str(bad_launch))
	var wrong_target: Dictionary = source.duplicate(true)
	wrong_target["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(wrong_target).get("ok", false)),
		"AC3: copied Moth Shroud with ally rank 5 still fails validation")


## AC1: Pole Shelter's authored base launch stays [1,2,3] for tiers I/II, and only the tier-III
## ability override adds hero rank 4. Every tier keeps the same ally target list, single-target
## Guard amount, ACC/damage/crit fields and legs stat, so the rear-rank entitlement is data only.
func _test_pole_shelter_rear_launch() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: catalog with tier-III Pole Shelter rear launch validates")
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][STARTERS["legs"]]
	var base_launch := [1, 2, 3]
	var rear_launch := [1, 2, 3, 4]
	var base_mask := StitchedParts.rank_mask(base_launch)
	var full_mask := StitchedParts.rank_mask(rear_launch)
	var target_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	_check(full_mask == StitchedParts.ALL_RANKS_MASK and base_mask != full_mask
		and not StitchedParts.ranks_allowed(base_mask, 4),
		"AC1: Pole Shelter's base/tier-I mask excludes rank 4 while ranks 1-4 form the full mask")
	_check(str(part["id"]) == "lantern_monk_legs_pole_shelter"
		and str(part["name"]) == "Pole Shelter" and str(part["slot"]) == "legs"
		and str(part["owner"]) == "lantern_monk"
		and str(part["ability"]["id"]) == "lantern_monk_legs_pole_shelter_move"
		and part["stat"] == {"speed": 1, "dodge": 3},
		"AC1: Pole Shelter keeps its id, name, legs slot, owner, ability id and +1 SPEED/+3 DODGE stat")
	_check(str(part["text"]) == POLE_SHELTER_COPY,
		"AC1: Pole Shelter describes its sewn cream shelter patch, not a combat move")
	var expected_guard := {1: 2, 2: 3, 3: 4}
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var valid := StitchedParts.validate_ability(ability)
		_check(bool(valid.get("ok", false)), "AC1: Pole Shelter tier %d ability validates" % tier)
		if not bool(valid.get("ok", false)):
			continue
		var checked: Dictionary = valid["ability"]
		var expected_launch: Array = rear_launch if tier == 3 else base_launch
		var expected_mask: int = full_mask if tier == 3 else base_mask
		_check(checked["launch"] == expected_launch
			and int(checked["launch_mask"]) == expected_mask,
			"AC1: Pole Shelter tier %d launches from exactly %s" % [tier, str(expected_launch)])
		for rank in [1, 2, 3]:
			_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank),
				"AC1: Pole Shelter tier %d may launch from hero rank %d" % [tier, rank])
		_check(StitchedParts.ranks_allowed(int(checked["launch_mask"]), 4) == (tier == 3),
			"AC1: Pole Shelter tier %d %s launch from hero rank 4"
				% [tier, "may" if tier == 3 else "may not"])
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(checked["launch_mask"]), rank)
				and not StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Pole Shelter tier %d never allows rank %d" % [tier, rank])
		_check(checked["target"] == [1, 2, 3, 4] and int(checked["target_mask"]) == target_mask
			and str(checked["target_side"]) == "ally" and not bool(checked["multi"]),
			"AC1: Pole Shelter tier %d still Guards one ally in ranks 1-4" % tier)
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(checked["target_mask"]), rank),
				"AC1: Pole Shelter tier %d reaches ally rank %d" % [tier, rank])
		_check(str(checked["kind"]) == "guard" and checked["dmg"] == [0, 0]
			and int(checked["acc"]) == 100 and int(checked["crit"]) == 0
			and int(checked["mark_damage"]) == 0 and int(checked["self_move"]) == 0
			and str(checked["move"]) == "guard"
			and int(checked["effects"].get("guard", 0)) == int(expected_guard[tier]),
			"AC1: Pole Shelter tier %d keeps ACC 100, no damage/crit, Guard %d and its guard pose"
				% [tier, int(expected_guard[tier])])
		_check(StitchedParts.stat_at_tier(part, tier) == {"speed": 1, "dodge": 3},
			"AC1: Pole Shelter tier %d keeps its authored legs stat" % tier)
	_check(part["ability"]["launch"] == base_launch
		and int(part["ability"]["launch_mask"]) == base_mask
		and part["ability"]["target"] == [1, 2, 3, 4]
		and int(part["ability"]["effects"]["guard"]) == 2,
		"AC1: tier reads never replace Pole Shelter's frozen base ability in memory")
	var bad_launch: Dictionary = part.duplicate(true)
	bad_launch["tiers"]["3"]["ability"]["launch"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(bad_launch).get("ok", false)),
		"AC3: a tier-III Pole Shelter override with rank 5 still fails validation")


## AC1/AC2: both of Pole Shelter's authored tier text overrides now repeat the same neutral
## sewn-cloth sentence as its base record: S14 keeps the legacy Guard numbers as compatibility
## data, never as player promises. The numeric ability is untouched: Guard 2/3/4, the launch
## masks [1,2,3]/[1,2,3]/[1,2,3,4] and the ally target ranks 1-4 for a single guarded ally.
func _test_pole_shelter_tier_text() -> void:
	var cat := StitchedParts.load_catalog(CATALOG_PATH)
	_check(bool(cat.get("ok", false)),
		"AC1: catalog with Pole Shelter tier text validates: " + str(cat.get("error", "")))
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"].get(STARTERS["legs"], {})
	_check(not part.is_empty() and str(part.get("name", "")) == "Pole Shelter"
		and str(part.get("slot", "")) == "legs" and str(part.get("owner", "")) == "lantern_monk",
		"AC1: the loaded catalog still holds the existing Lantern Monk legs Pole Shelter record")
	if part.is_empty():
		return
	var base_text := str(part.get("text", ""))
	_check(base_text == POLE_SHELTER_COPY,
		"AC1: tier-I base text is the neutral sewn-shelter description")
	var tiers: Dictionary = part.get("tiers", {})
	var expected_guard := {1: 2, 2: 3, 3: 4}
	var expected_launch := {1: [1, 2, 3], 2: [1, 2, 3], 3: [1, 2, 3, 4]}
	var target_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	var forbidden := RegEx.new()
	_check(forbidden.compile("\\b(guard|dodge|heal|attack|enemy|ally|target|rank|turn|damage|duration|card|tier)\\b") == OK,
		"AC3: combat-promise word pattern compiles for Pole Shelter text")
	_check(forbidden.search("wrap one ally in a fluttering shroud") != null,
		"AC3: the combat-promise pattern really rejects the old ally-shroud sentence")
	for tier in [1, 2, 3]:
		# Same fallback the schema and the shipped inspectors/cues use: the base text for
		# tier I, and an authored per-tier "text" override when one exists.
		var effective := base_text
		if tier > 1:
			_check(tiers.has(str(tier)) and tiers[str(tier)].has("text"),
				"AC1: Pole Shelter tier %d carries an authored text override" % tier)
			effective = str(tiers.get(str(tier), {}).get("text", base_text))
		_check(effective == POLE_SHELTER_COPY,
			"AC1: Pole Shelter tier %d effective text is the neutral cloth sentence: %s"
				% [tier, effective])
		_check(forbidden.search(effective.to_lower()) == null,
			"AC3: Pole Shelter tier %d text promises no combat outcome" % tier)
		var ability := StitchedParts.ability_at_tier(part, tier)
		var valid := StitchedParts.validate_ability(ability)
		_check(bool(valid.get("ok", false)),
			"AC2: Pole Shelter tier %d effective ability validates" % tier)
		if not bool(valid.get("ok", false)):
			continue
		var checked: Dictionary = valid["ability"]
		_check(int(checked["effects"].get("guard", 0)) == int(expected_guard[tier])
			and checked["effects"].size() == 1 and checked["effects"].has("guard"),
			"AC2: Pole Shelter tier %d grants Guard %d and no extra PROT/Heal/Block effect"
				% [tier, int(expected_guard[tier])])
		_check(checked["launch"] == expected_launch[tier]
			and int(checked["launch_mask"]) == StitchedParts.rank_mask(expected_launch[tier])
			and StitchedParts.ranks_allowed(int(checked["launch_mask"]), 4) == (tier == 3),
			"AC2: Pole Shelter tier %d launches from exactly %s"
				% [tier, str(expected_launch[tier])])
		_check(checked["target"] == [1, 2, 3, 4]
			and int(checked["target_mask"]) == target_mask
			and str(checked["target_side"]) == "ally" and not bool(checked["multi"]),
			"AC2: Pole Shelter tier %d still redirects blows for one ally in ranks 1-4" % tier)
	_check(int(part["ability"]["effects"]["guard"]) == 2
		and part["ability"]["launch"] == [1, 2, 3]
		and part["ability"]["target"] == [1, 2, 3, 4],
		"AC2: tier text reads never replace Pole Shelter's base ability in memory")
	var blank_text: Dictionary = part.duplicate(true)
	blank_text["tiers"]["2"]["text"] = ""
	_check(not bool(StitchedParts.validate_part(blank_text).get("ok", false)),
		"AC3: an empty tier-II Pole Shelter text still fails closed")
	var stray_field: Dictionary = part.duplicate(true)
	stray_field["tiers"]["3"]["targets"] = 2
	_check(not bool(StitchedParts.validate_part(stray_field).get("ok", false)),
		"AC3: a tier override that invents an extra guarded-target field still fails closed")


## One real seeded S2 preview fight with tier-III Pole Shelter equipped on the rank-4 Monk:
## advance to his scheduled turn, Guard the living rank-1 Warden, then advance to the real
## Fray Scavenger turn and swing at rank 1. Returns the genuine receipts and snapshots so the
## caller can demand an authentic interception and repeat the whole sequence on the same seed.
func _rank4_pole_shelter_trace(seed_value: int) -> Dictionary:
	var b := _battle(STARTERS["legs"], 3, seed_value, true)
	if b == null:
		return {}
	if int(b.get_unit("lantern_monk").get("rank", -1)) != 4:
		return {}
	var legs: Dictionary = b.get_unit("lantern_monk").get("parts", {}).get("legs", {})
	if str(legs.get("id", "")) != STARTERS["legs"] or int(legs.get("tier", 0)) != 3:
		return {}
	var warden := b.get_unit("warden")
	if warden.is_empty() or int(warden.get("rank", -1)) != 1 \
			or bool(warden.get("lost", false)) or int(warden["hp"]) <= 0:
		return {}
	if not _to(b, "lantern_monk"):
		return {}
	var before_guard := b.state_snapshot()
	var guard := b.use_part(STARTERS["legs"], 1)
	if not bool(guard.get("ok", false)):
		return {}
	var monk := b.get_unit("lantern_monk")
	var monk_rank := int(monk["rank"])
	var guard_status := int(monk["statuses"].get("guard", 0))
	var guard_target := str(monk.get("guard_target", ""))
	if guard_target != "warden":
		return {}
	var after_guard := b.state_snapshot()
	if not _to(b, "fray_scavenger"):
		return {}
	var warden_now := b.get_unit("warden")
	if warden_now.is_empty() or int(warden_now.get("rank", -1)) != 1 \
			or bool(warden_now.get("lost", false)) or int(warden_now["hp"]) <= 0:
		return {}
	var scavenger := b.get_unit("fray_scavenger")
	if scavenger.is_empty() or bool(scavenger.get("dead", false)) or int(scavenger["hp"]) <= 0:
		return {}
	var warden_before := int(warden_now["hp"])
	var monk_before := int(b.get_unit("lantern_monk")["hp"])
	var strike := b.use_foe_ability("sack_swing", 1)
	return {
		"battle": b,
		"guard": guard,
		"strike": strike,
		"before_guard": before_guard,
		"after_guard": after_guard,
		"warden_before": warden_before,
		"monk_before": monk_before,
		"monk_rank": monk_rank,
		"guard_status": guard_status,
		"guard_target": guard_target,
		"after": b.state_snapshot(),
		"rng": b.rng_state(),
	}


## AC2: a real seeded S2 4v3 fight in the shipped preview order (Lantern Monk in hero rank 4)
## with tier-III Pole Shelter actually equipped. The Monk's scheduled turn Guards the living
## rank-1 Warden and spends exactly one turn. On the Fray Scavenger's real next turn a genuine
## sack_swing at rank 1 is redirected to the Monk: the receipt names the guardian and the
## Warden takes none of that blow. The same seed and actions replay receipts, state and RNG.
func _test_rank4_pole_shelter() -> void:
	var witnessed := false
	for seed_value in range(500840, 500880):
		var trace := _rank4_pole_shelter_trace(seed_value)
		if trace.is_empty():
			continue
		var guard: Dictionary = trace["guard"]
		var strike: Dictionary = trace["strike"]
		var receipts: Array = strike.get("results", [])
		if not bool(strike.get("ok", false)) or receipts.size() != 1:
			continue
		var receipt: Dictionary = receipts[0]
		if not bool(receipt.get("hit", false)) \
				or str(receipt.get("guarded_by", "")) != "lantern_monk":
			continue
		if str(receipt.get("target", "")) != "lantern_monk" \
				or str(receipt.get("target_side", "")) != "hero" \
				or int(receipt.get("target_rank", -1)) != 4:
			continue
		witnessed = true
		var b: StitchedRules = trace["battle"]
		_check(str(guard.get("action", "")) == "ability"
			and str(guard.get("actor", "")) == "lantern_monk"
			and str(guard.get("part", "")) == STARTERS["legs"]
			and str(guard.get("ability", "")) == "lantern_monk_legs_pole_shelter_move",
			"AC2: hero rank 4 tier-III Pole Shelter runs as the equipped Monk legs part (seed %d)"
				% seed_value)
		_check(int(trace["monk_rank"]) == 4 and int(trace["guard_status"]) == 4
			and str(trace["guard_target"]) == "warden",
			"AC2: the cast assigns living Warden at ally rank 1 with Guard 4 (seed %d)" % seed_value)
		var after_guard: Dictionary = trace["after_guard"]
		var before_guard: Dictionary = trace["before_guard"]
		var advanced_once := (int(after_guard["round"]) == int(before_guard["round"])
				and int(after_guard["turn_index"]) == int(before_guard["turn_index"]) + 1) \
			or int(after_guard["round"]) == int(before_guard["round"]) + 1
		_check(advanced_once and after_guard != before_guard,
			"AC2: the rank-4 Guard spends exactly one Monk turn and changes real battle state (seed %d)"
				% seed_value)
		_check(str(strike.get("action", "")) == "ability"
			and str(strike.get("actor", "")) == "fray_scavenger"
			and str(strike.get("ability", "")) == "sack_swing",
			"AC2: the Fray Scavenger's real sack_swing aims at rank 1 (seed %d)" % seed_value)
		_check(int(receipt.get("damage", -1))
				== int(trace["monk_before"]) - int(receipt.get("target_hp", -2)),
			"AC2: the authentic hit's damage lands on the guardian's real HP (seed %d)" % seed_value)
		_check(int(b.get_unit("warden")["hp"]) == int(trace["warden_before"])
			and int(b.get_unit("warden")["rank"]) == 1
			and not bool(b.get_unit("warden")["lost"]),
			"AC2: the Warden takes none of the redirected blow and keeps rank 1 (seed %d)" % seed_value)
		var replay := _rank4_pole_shelter_trace(seed_value)
		_check(not replay.is_empty() and replay["guard"] == guard and replay["strike"] == strike
			and replay["after"] == trace["after"] and int(replay["rng"]) == int(trace["rng"]),
			"AC2: same-seed real Guard-follow-up replay matches receipts, final state and RNG (seed %d)"
				% seed_value)
		break
	_check(witnessed,
		"AC2: a real seeded rank-4 tier-III Pole Shelter Guards Warden and intercepts sack_swing")


## AC3: tier I/II Pole Shelter stays illegal from hero rank 4, and the new tier-III rank-4
## entitlement still fails closed for out-of-range ally ranks, unequipped, torn and stale
## actions. Every refusal leaves the actor, snapshot and seeded RNG untouched.
func _test_pole_shelter_rejections() -> void:
	for tier in [1, 2]:
		var b := _battle(STARTERS["legs"], tier, 500760 + tier, true)
		if b == null or not _to(b, "lantern_monk"):
			_check(false, "AC3: tier %d Pole Shelter rank-4 witness receives a real scheduled turn" % tier)
			continue
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4
			and str(b.get_unit("lantern_monk")["parts"]["legs"]["id"]) == STARTERS["legs"]
			and int(b.get_unit("lantern_monk")["parts"]["legs"].get("tier", 0)) == tier,
			"AC3: tier %d Pole Shelter witness really stands in hero rank 4" % tier)
		_reject_without_spend(b, STARTERS["legs"], 1,
			"Pole Shelter tier %d forbidden from hero rank 4" % tier)
	var legal := _battle(STARTERS["legs"], 3, 500763, true)
	if legal == null or not _to(legal, "lantern_monk"):
		_check(false, "AC3: tier-III Pole Shelter rejection witness receives a real scheduled turn")
	else:
		_check(int(legal.get_unit("lantern_monk")["rank"]) == 4
			and str(legal.get_unit("lantern_monk")["parts"]["legs"]["id"]) == STARTERS["legs"],
			"AC3: tier-III rejection witness really stands in hero rank 4 with Pole Shelter")
		_reject_without_spend(legal, STARTERS["legs"], 0, "Pole Shelter out-of-range ally rank 0")
		_reject_without_spend(legal, STARTERS["legs"], 5, "Pole Shelter out-of-range ally rank 5")
		var cast := legal.use_part(STARTERS["legs"], 1)
		_check(bool(cast.get("ok", false))
			and str(legal.get_unit("lantern_monk")["guard_target"]) == "warden",
			"AC3: the same rank-4 Monk legally Guards the rank-1 Warden once")
		_reject_without_spend(legal, STARTERS["legs"], 1, "stale off-turn tier-III Pole Shelter")
	var other := _battle(ALTERNATES["legs"], 3, 500764, true)
	if other == null or not _to(other, "lantern_monk"):
		_check(false, "AC3: unequipped Pole Shelter witness receives a real scheduled turn")
	else:
		_check(str(other.get_unit("lantern_monk")["parts"]["legs"]["id"]) == ALTERNATES["legs"],
			"AC3: the unequipped witness really has Moth Shroud in the legs slot")
		_reject_without_spend(other, STARTERS["legs"], 1, "unequipped tier-III Pole Shelter")
	var torn_config := _config(STARTERS["legs"], 3, 500765, true)
	torn_config["heroes"][3]["parts"]["legs"] = {"id": STARTERS["legs"], "tier": 3, "torn": true}
	var torn_created := StitchedRules.create(torn_config)
	_check(bool(torn_created.get("ok", false)),
		"AC3: a real torn tier-III Pole Shelter enters a rank-4 battle")
	if bool(torn_created.get("ok", false)):
		var torn: StitchedRules = torn_created["battle"]
		if _to(torn, "lantern_monk"):
			_reject_without_spend(torn, STARTERS["legs"], 1, "torn tier-III Pole Shelter")
		else:
			_check(false, "AC3: torn tier-III Pole Shelter witness receives a real turn")


## Rank 2 stays a legal launch rank after the data change, and the identical seed and action
## reproduce the same receipt, snapshot and RNG position.
func _test_rank2_moth_cloud_replay() -> void:
	var witnessed := false
	for seed_value in range(500132, 500160):
		var b := _battle(ALTERNATES["head"], 1, seed_value)
		if b == null or int(b.get_unit("lantern_monk").get("rank", -1)) != 2:
			continue
		if not _to(b, "lantern_monk"):
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(ALTERNATES["head"], 1)
		if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
			continue
		var replay := _battle(ALTERNATES["head"], 1, seed_value)
		if replay == null or not _to(replay, "lantern_monk"):
			continue
		var replayed := replay.use_part(ALTERNATES["head"], 1)
		witnessed = replayed == cast and replay.state_snapshot() == b.state_snapshot() \
			and replay.rng_state() == b.rng_state() and b.state_snapshot() != before
		if not witnessed:
			continue
		_check(str(cast.get("ability", "")) == "lantern_monk_head_moth_cloud_move"
			and cast.get("results", []).size() == 3,
			"AC2: hero rank 2 Moth Cloud still resolves all three living foes (seed %d)" % seed_value)
		break
	_check(witnessed, "AC2: rank-2 Moth Cloud use and same-seed replay stay deterministic")


func _test_guard_and_shroud() -> void:
	var guard_witness := false
	for seed_value in range(500301, 500336):
		var b := _battle(STARTERS["legs"], 1, seed_value)
		if b == null or not _to(b, "lantern_monk"):
			continue
		var cast := b.use_part(STARTERS["legs"], 1)
		if not bool(cast.get("ok", false)) or str(b.get_unit("lantern_monk")["guard_target"]) != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var strike := b.use_foe_ability("sack_swing", 1)
		guard_witness = bool(strike.get("ok", false)) and strike.get("results", []).size() == 1 \
			and str(strike["results"][0].get("guarded_by", "")) == "lantern_monk"
		if guard_witness:
			break
	_check(guard_witness, "AC2: real enemy attack on Warden is intercepted by Pole Shelter guardian")
	var buff := _battle(ALTERNATES["legs"], 2, 500365)
	if buff != null and _to(buff, "lantern_monk"):
		var original := int(buff.get_unit("warden")["dodge"])
		var cast := buff.use_part(ALTERNATES["legs"], 1)
		_check(bool(cast.get("ok", false)) and int(StitchedRules.effective_dodge(buff.get_unit("warden"))) > original
			and int(buff.get_unit("warden")["dodge_buff"].get("turns", 0)) == 2,
			"AC2: Moth Shroud gives an actual bounded Dodge modifier to one real ally")


func _test_rejection_no_spend() -> void:
	var config := _config()
	if config.is_empty():
		return
	config["heroes"][1]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: head cannot equip to arms slot")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: invalid tier IV rejects at battle creation")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": "lantern_monk_head_missing", "tier": 1}
	_check(not bool(StitchedRules.create(config).get("ok", false)), "AC3: non-catalog gear rejects")
	config = _config()
	config["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 1, "torn": true}
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "AC3: a real torn Lantern Monk can enter battle")
	if bool(created.get("ok", false)):
		var torn: StitchedRules = created["battle"]
		if _to(torn, "lantern_monk"):
			_reject_without_spend(torn, STARTERS["head"], 1, "torn part")
		else:
			_check(false, "AC3: torn part witness receives a real scheduled turn")
	var b := _battle()
	if b == null or not _to(b, "lantern_monk"):
		_check(false, "AC3: illegal-action witness receives a real turn")
		return
	for action in [[STARTERS["head"], 4], [STARTERS["arms"], 4], [STARTERS["legs"], 0], ["missing_part", 1]]:
		_reject_without_spend(b, str(action[0]), int(action[1]), "illegal target/side/rank or unequipped part")
	var legal := b.use_part(STARTERS["head"], 1)
	_check(bool(legal.get("ok", false)), "AC3: a lawful action actually consumes the Monk turn")
	if bool(legal.get("ok", false)):
		_reject_without_spend(b, STARTERS["arms"], 1, "stale off-turn")
	var back := _config()
	if back.is_empty():
		return
	# Same four real heroes, only the Monk moved to the front rank in the copied fixture:
	# Wick Spark's authored launch starts at rank 2, so a genuine rank-1 Monk must refuse it.
	var monk: Dictionary = back["heroes"].pop_at(1)
	back["heroes"].insert(0, monk)
	var back_result := StitchedRules.create(back)
	_check(bool(back_result.get("ok", false)), "AC3: a real rank-1 Monk loadout enters battle")
	if bool(back_result.get("ok", false)):
		var front: StitchedRules = back_result["battle"]
		_check(int(front.get_unit("lantern_monk")["rank"]) == 1,
			"AC3: rank-1 Wick Spark rejection witness really stands in hero rank 1")
		if _to(front, "lantern_monk"):
			_check(str(front.get_unit("lantern_monk")["parts"]["arms"]["id"]) == STARTERS["arms"],
				"AC3: the rank-1 witness really has Wick Spark equipped")
			_reject_without_spend(front, STARTERS["arms"], 1, "Wick Spark forbidden from hero rank 1")
		else:
			_check(false, "AC3: rank-1 Wick Spark witness has a scheduled turn")


## AC3 at rank 4: Wick Spark now legally launches from rank 4, so its obsolete rank-4
## refusal is replaced by a genuine rank-1 Monk refusing it; both rear-rank parts stay
## illegal from rank 1, and copied malformed launch/target arrays still fail the existing
## validator with no turn, state or RNG spend. The rank-4 successes live in
## _test_rank4_wick_spark and _test_rank4_moth_cloud.
func _test_rank4_launch_rejections() -> void:
	var b := _battle("", 1, 500820, true)
	if b == null or not _to(b, "lantern_monk"):
		_check(false, "AC3: rank-4 rejection witness receives a real scheduled turn")
	else:
		_check(int(b.get_unit("lantern_monk")["rank"]) == 4,
			"AC3: rejection witness really stands in hero rank 4")
		_reject_without_spend(b, ALTERNATES["torso"], 1, "unequipped torso part")
		_reject_without_spend(b, STARTERS["torso"], 0, "out-of-range target rank 0")
		_reject_without_spend(b, STARTERS["torso"], 5, "out-of-range target rank 5")
		var healed := b.use_part(STARTERS["torso"], 1)
		_check(bool(healed.get("ok", false)) and healed.get("results", []).size() == 4,
			"AC3: the same rank-4 Monk spends the turn on the legal torso heal")

	var config := _config(ALTERNATES["head"], 1, 500822, true)
	var monk: Dictionary = config["heroes"].pop_back()
	config["heroes"].insert(0, monk)
	var created := StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "AC3: a real rank-1 Moth Cloud loadout enters battle")
	if bool(created.get("ok", false)):
		var front: StitchedRules = created["battle"]
		_check(int(front.get_unit("lantern_monk")["rank"]) == 1,
			"AC3: rank-1 witness really stands in hero rank 1")
		if _to(front, "lantern_monk"):
			_check(str(front.get_unit("lantern_monk")["parts"]["head"]["id"]) == ALTERNATES["head"],
				"AC3: the rank-1 witness really has Moth Cloud equipped")
			_reject_without_spend(front, ALTERNATES["head"], 1, "Moth Cloud forbidden from hero rank 1")
			_reject_without_spend(front, STARTERS["torso"], 1, "Lamplight Wash forbidden from hero rank 1")
			_reject_without_spend(front, STARTERS["arms"], 1, "Wick Spark forbidden from hero rank 1")
		else:
			_check(false, "AC3: rank-1 Moth Cloud witness receives a real turn")

	config = _config("", 1, 500823, true)
	config["heroes"][3]["parts"]["torso"] = {"id": STARTERS["torso"], "tier": 1, "torn": true}
	created = StitchedRules.create(config)
	_check(bool(created.get("ok", false)), "AC3: a real torn Lamplight Wash enters a rank-4 battle")
	if bool(created.get("ok", false)):
		var torn: StitchedRules = created["battle"]
		if _to(torn, "lantern_monk"):
			_reject_without_spend(torn, STARTERS["torso"], 1, "torn Lamplight Wash")
		else:
			_check(false, "AC3: torn Lamplight Wash witness receives a real turn")

	var stale := _battle("", 1, 500824, true)
	if stale == null or not _to(stale, "fray_scavenger"):
		_check(false, "AC3: off-turn Lamplight Wash witness receives a real foe turn")
	else:
		_reject_without_spend(stale, STARTERS["torso"], 1, "stale off-turn Lamplight Wash")

	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC3: catalog available for copied-part validator checks")
	if not bool(cat.get("ok", false)):
		return
	var source: Dictionary = cat["by_id"][STARTERS["torso"]]
	for bad_launch in [[2, 3, 4, 4], [2, 3, 4, 5], [0, 2, 3, 4]]:
		var copy: Dictionary = source.duplicate(true)
		copy["ability"]["launch"] = bad_launch
		_check(not bool(StitchedParts.validate_part(copy).get("ok", false)),
			"AC3: copied Lamplight Wash launch %s still fails validation" % str(bad_launch))
	var wrong_side: Dictionary = source.duplicate(true)
	wrong_side["ability"]["target_side"] = "allies"
	_check(not bool(StitchedParts.validate_part(wrong_side).get("ok", false)),
		"AC3: copied Lamplight Wash with an unknown target side still fails validation")
	var wrong_target: Dictionary = source.duplicate(true)
	wrong_target["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(wrong_target).get("ok", false)),
		"AC3: copied Lamplight Wash with target rank 5 still fails validation")


func _reject_without_spend(b: StitchedRules, id: String, rank: int, label: String) -> void:
	var turn := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var receipt := b.use_part(id, rank)
	_check(not bool(receipt.get("ok", false)) and str(receipt.get("error", "")) != ""
		and b.current_actor_id() == turn and b.state_snapshot() == snapshot and b.rng_state() == rng,
		"AC3: " + label + " rejects without any turn, state or RNG spend")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2], [STARTERS["torso"], 1], [STARTERS["legs"], 1]]:
		if not _to(b, "lantern_monk"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(500919)
	var second := _trace(500919)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: identical seeds and real four-part action sequence replay receipts, snapshot and RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: each replayed equipped-part action succeeds")
