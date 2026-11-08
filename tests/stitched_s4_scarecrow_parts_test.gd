extends SceneTree
## S4 Scarecrow: eight independent Stitched parts tested against real seeded S2 4v3 rules.
## The shipped preview is read-only: rank 2 is replaced only in memory.
const CATALOG_PATH := "res://data/parts/scarecrow_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const STARTERS := {
	"head": "scarecrow_head_sack_glare",
	"arms": "scarecrow_arms_fork_jab",
	"torso": "scarecrow_torso_straw_padding",
	"legs": "scarecrow_legs_crow_dive",
}
const ALTERNATES := {
	"head": "scarecrow_head_crow_flock",
	"arms": "scarecrow_arms_harvest_fright",
	"torso": "scarecrow_torso_straw_wrap",
	"legs": "scarecrow_legs_crow_peck",
}
const IDS := [
	"scarecrow_head_sack_glare", "scarecrow_arms_fork_jab",
	"scarecrow_torso_straw_padding", "scarecrow_legs_crow_dive",
	"scarecrow_head_crow_flock", "scarecrow_arms_harvest_fright",
	"scarecrow_torso_straw_wrap", "scarecrow_legs_crow_peck",
]
const ENEMY_IDS := ["fray_scavenger", "scissor_crab", "moth_scribe"]
const OTHER_HERO_IDS := ["warden", "tinker", "lantern_monk"]
## The two shoulder-crow legs attacks: base authored values, and the tier II/III overrides.
## Both may launch from hero rank 4. Crow Peck reaches enemy rank 4 at every tier; Crow Dive
## reaches enemy ranks 1-3 at tier I and all four enemy ranks once upgraded to tier II/III.
## Every other value here must stay untouched.
const CROW_LEGS := {
	"scarecrow_legs_crow_dive": {
		"name": "Crow Dive",
		"stat": {"speed": 2},
		"ability_id": "scarecrow_legs_crow_dive_move",
		"target": [1, 2, 3],
		"acc": 91,
		"dmg": [3, 5],
		"crit": 3,
		"effects": {},
		"move": "attack2",
		"mark_damage": 3,
		"tier2": {"dmg": [4, 7], "mark_damage": 4, "effects": {}, "target": [1, 2, 3, 4]},
		"tier3": {"dmg": [6, 9], "mark_damage": 6, "effects": {}, "target": [1, 2, 3, 4]},
	},
	"scarecrow_legs_crow_peck": {
		"name": "Crow Peck",
		"stat": {"dodge": 5},
		"ability_id": "scarecrow_legs_crow_peck_move",
		"target": [1, 2, 3, 4],
		"acc": 92,
		"dmg": [4, 6],
		"crit": 3,
		"effects": {"mark": 2},
		"move": "attack",
		"mark_damage": 3,
		"tier2": {"dmg": [5, 8], "mark_damage": 5, "effects": {"mark": 2}},
		"tier3": {"dmg": [7, 10], "mark_damage": 7, "effects": {"mark": 3}},
	},
}
## Seven of the eight Scarecrow parts must keep their authored base records; the only data
## changes are the tier-III target overrides on Sack Glare and Harvest Fright plus the tier-II/
## tier-III stat ladders on the two head parts. Crow Dive, Crow Peck and Crow Flock are pinned
## by CROW_LEGS and _test_leg_rank4_data, so this table pins the remaining siblings.
const SIBLING_PARTS := {
	"scarecrow_arms_fork_jab": {
		"slot": "arms", "stat": {"dmg": 1}, "launch": [1, 2], "target": [1, 2],
		"target_side": "enemy", "multi": false, "acc": 93, "dmg": [4, 6], "crit": 3,
		"effects": {"bleed": 1}, "move": "attack",
	},
	"scarecrow_torso_straw_padding": {
		"slot": "torso", "stat": {"max_hp": 6, "prot": 3}, "launch": [1, 2, 3],
		"target": [1, 2, 3, 4], "target_side": "ally", "multi": false, "acc": 100,
		"dmg": [0, 0], "crit": 0, "effects": {"guard": 2}, "move": "guard",
	},
	"scarecrow_arms_harvest_fright": {
		"slot": "arms", "stat": {"dmg": 2}, "launch": [1, 2, 3], "target": [1, 2, 3],
		"target_side": "enemy", "multi": true, "acc": 88, "dmg": [2, 4], "crit": 0,
		"effects": {"weak": 2}, "move": "attack2",
	},
	"scarecrow_torso_straw_wrap": {
		"slot": "torso", "stat": {"max_hp": 5, "prot": 4}, "launch": [1, 2, 3],
		"target": [1, 2, 3, 4], "target_side": "ally", "multi": false, "acc": 100,
		"dmg": [0, 0], "crit": 0, "effects": {"dodge": 6, "duration": 2}, "move": "guard",
	},
}
## S14: the two starter pieces are worn cloth patches, so their base copy describes sewn burlap,
## denim, straw and thread only. The retired part-granted combat text is no longer advertised.
const SACK_GLARE_TEXT := "A burlap brow patch creases above the Scarecrow's crooked stitched grin, " \
	+ "held by pumpkin-orange thread."
const FORK_JAB_TEXT := "A denim cuff binds the pitchfork arm, with loose straw tucked beneath thick " \
	+ "orange running stitches."
## S14: the two crow legs parts are worn cloth patches too. Their base copy names only the sewn
## feathers, denim, straw and thread a player sees; the retired part-granted attacks are no
## longer advertised.
const CROW_DIVE_PATCH_TEXT := "A long black crow feather is sewn diagonally across a frayed denim " \
	+ "shin with bright pumpkin-orange thread."
const CROW_PECK_PATCH_TEXT := "Three short black feathers fan across a straw-stuffed denim knee, " \
	+ "held by uneven pumpkin-orange cross-stitches."
## The exact sentences the two crow legs parts used to advertise as part-cast attacks.
const CROW_DIVE_OLD_TEXT := "Send the shoulder crow at enemy ranks 1-3; marked foes take extra " \
	+ "damage. Upgraded, it reaches rank 4."
const CROW_PECK_OLD_TEXT := "Peck a chosen foe and Mark it; already Marked targets take extra damage."
const PATCH_FORBIDDEN_WORDS := [
	"foe", "enemy", "attack", "hit", "damage", "rank", "tier", "mark", "weak", "bleed",
	"stun", "guard", "heal", "turn", "target", "ability",
]
const HARVEST_FRIGHT_TEXT := "Strike each foe in enemy ranks 1-3 with a terrifying crow harvest, " \
	+ "leaving Weak on hits; at stitch tier III it also reaches rank 4."
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_catalog()
	_test_starter_patch_appearance_text()
	_test_crow_leg_patch_appearance_text()
	_test_each_tier()
	_test_area_and_effects()
	_test_guard_and_dodge()
	_test_mark_damage()
	_test_leg_rank4_data()
	_test_sack_glare_rank4_data()
	_test_rank4_crows()
	_test_rank4_crow_flock()
	_test_crow_flock_mark_survives_for_dive()
	_test_crow_flock_tier1_weak_reply()
	_test_sack_glare_tier1_weak_reply()
	_test_sack_glare_rank4()
	_test_harvest_fright_rank4_data()
	_test_harvest_fright_rank4()
	_test_rejections()
	_test_replay()
	for failure in failures:
		printerr(failure)
	print("stitched_s4_scarecrow_parts_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _catalog() -> Dictionary:
	return StitchedParts.load_catalog(CATALOG_PATH)


func _config(selected: String = "", tier: int = 1, seed_value: int = 501041) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if not parsed is Dictionary:
		_check(false, "real shipped four-hero S2 preview must parse")
		return {}
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		_check(false, "Scarecrow catalog validates: " + str(cat.get("error", "")))
		return {}
	var config: Dictionary = parsed
	_check(str(config["heroes"][1]["id"]) == "seamstress", "rank-2 preview hero is the only replacement")
	var gear: Dictionary = {}
	for slot in STARTERS:
		var id: String = STARTERS[slot]
		if not selected.is_empty() and cat["by_id"].has(selected) and str(cat["by_id"][selected]["slot"]) == slot:
			id = selected
		gear[slot] = {"id": id, "tier": tier}
	config["heroes"][1] = {
		"id": "scarecrow", "name": "Scarecrow", "max_hp": 32, "speed": 6,
		"dodge": 7, "acc": 6, "prot": 0, "parts": gear,
	}
	config["parts"].append_array(cat["parts"])
	config["seed"] = seed_value
	return config


func _battle(selected: String = "", tier: int = 1, seed_value: int = 501041) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var built := StitchedRules.create(config)
	_check(bool(built.get("ok", false)), "AC2: real S2 rules setup: " + str(built.get("error", "")))
	if not bool(built.get("ok", false)):
		return null
	var b: StitchedRules = built["battle"]
	var heroes: Array = b.get_heroes()
	var foes: Array = b.get_foes()
	_check(heroes.size() == 4 and foes.size() == 3 and int(b.get_unit("scarecrow").get("rank", -1)) == 2,
		"AC2: four actual heroes, three actual foes, Scarecrow at legal rank 2")
	for id in OTHER_HERO_IDS:
		_check(not b.get_unit(id).is_empty(), "AC2: other shipped preview hero retained: " + id)
	for id in ENEMY_IDS:
		_check(not b.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
	_check(b.get_unit("scarecrow").get("parts", {}).size() == 4,
		"AC2: Scarecrow starts with four fully equipped parts")
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
	_check(bool(cat.get("ok", false)), "AC1: real JSON validates through StitchedParts")
	if not bool(cat.get("ok", false)):
		return
	var seen: Dictionary = {}
	var abilities: Dictionary = {}
	var counts := {"head": 0, "arms": 0, "torso": 0, "legs": 0}
	for id in IDS:
		_check(cat["by_id"].has(id), "AC1: required part exists: " + id)
	for part in cat["parts"]:
		var id := str(part["id"])
		var slot := str(part["slot"])
		_check(id in IDS and not seen.has(id) and str(part["owner"]) == "scarecrow",
			"AC1: unique Scarecrow-owned source-inspired part " + id)
		seen[id] = true
		if counts.has(slot):
			counts[slot] += 1
		_check(str(part["ability"]["id"]).begins_with("scarecrow_")
			and not abilities.has(str(part["ability"]["id"])),
			"AC1: independent unique ability for " + id)
		abilities[str(part["ability"]["id"])] = true
		var base: Dictionary = part["ability"]
		_check(str(base["move"]) in StitchedParts.MOVE_POSES
			and int(base["launch_mask"]) == StitchedParts.rank_mask(base["launch"])
			and int(base["target_mask"]) == StitchedParts.rank_mask(base["target"])
			and int(base["launch_mask"]) != 0 and int(base["target_mask"]) != 0,
			"AC1: legal launch/target masks and existing animation pose for " + id)
		_check(part["tiers"].has("2") and part["tiers"].has("3"),
			"AC1: both higher stitch tiers authored for " + id)
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var stat := StitchedParts.stat_at_tier(part, tier)
			_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
				"AC1: tier %d validates for %s" % [tier, id])
			_check(not stat.is_empty(), "AC1: slot stat present at tier %d %s" % [tier, id])
			for key in stat:
				_check(str(key) in StitchedParts.SLOT_STATS[slot],
					"AC1: each tier stat is legal for " + slot)
			if id == STARTERS["head"] and tier == 2:
				_check(ability == base,
					"AC1: Sack Glare tier II intentionally matches the now-Weak-2 tier-I ability")
			elif id == ALTERNATES["head"] and tier == 2:
				_check(ability == base,
					"AC1: Crow Flock tiers I and II intentionally share Weak 2/Mark 2")
			else:
				_check(tier == 1 or ability != base,
					"AC1: tier %d improves a native ability for %s" % [tier, id])
			for key in ["draw", "block", "cost", "cannot_buff_next_turn", "ignore_block", "max_hp_loss", "pull_forward"]:
				_check(not ability.has(key) and not ability["effects"].has(key),
					"AC1: no unsupported retired card effect " + key + " on " + id)
		var malformed: Dictionary = part.duplicate(true)
		malformed["tiers"]["4"] = {"ability": {"acc": 99}}
		_check(not bool(StitchedParts.validate_part(malformed).get("ok", false)),
			"AC3: illegal tier IV override fails closed for " + id)
	for slot in counts:
		_check(int(counts[slot]) == 2, "AC1: exactly two Scarecrow " + slot + " options")
		_check(str(cat["by_id"][STARTERS[slot]]["slot"]) == slot and
			str(cat["by_id"][ALTERNATES[slot]]["slot"]) == slot,
			"AC1: four named starters and four named alternates slot correctly")
	var crowd_targets := {
		ALTERNATES["head"]: [1, 2, 3, 4],
		ALTERNATES["arms"]: [1, 2, 3],
	}
	for id in crowd_targets:
		_check(bool(cat["by_id"][id]["ability"]["multi"])
			and cat["by_id"][id]["ability"]["target"] == crowd_targets[id]
			and int(cat["by_id"][id]["ability"]["target_mask"])
				== StitchedParts.rank_mask(crowd_targets[id])
			and str(cat["by_id"][id]["ability"]["target_side"]) == "enemy",
			"AC1: crowd move hits its authored foe ranks with native multi " + id)
	_check(int(cat["by_id"][STARTERS["legs"]]["ability"]["mark_damage"]) > 0
		and int(cat["by_id"][ALTERNATES["legs"]]["ability"]["mark_damage"]) > 0,
		"AC1: crow moves use implemented mark_damage, not ignore_block")
	var crow_dive: Dictionary = cat["by_id"][STARTERS["legs"]]
	var dive_tier1 := StitchedParts.ability_at_tier(crow_dive, 1)
	_check(dive_tier1["target"] == [1, 2, 3]
		and dive_tier1["launch"] == [1, 2, 3, 4]
		and not StitchedParts.ranks_allowed(int(dive_tier1["target_mask"]), 4)
		and not StitchedParts.ranks_allowed(int(dive_tier1["target_mask"]), 0)
		and not StitchedParts.ranks_allowed(int(dive_tier1["target_mask"]), 5),
		"AC1: Crow Dive tier I targets enemy ranks 1-3 and never 0, 4 or 5")
	for dive_tier in [2, 3]:
		var dive := StitchedParts.ability_at_tier(crow_dive, dive_tier)
		_check(dive["target"] == [1, 2, 3, 4]
			and int(dive["target_mask"]) == StitchedParts.ALL_RANKS_MASK
			and StitchedParts.ranks_allowed(int(dive["target_mask"]), 4)
			and not StitchedParts.ranks_allowed(int(dive["target_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(dive["target_mask"]), 5),
			"AC1: Crow Dive tier %d reaches enemy rank 4 but never 0 or 5" % dive_tier)
	_check(cat["by_id"][ALTERNATES["torso"]]["ability"]["effects"].has("duration"),
		"AC1: Straw Wrap has paired duration for temporary Dodge")
	var invalid_dodge: Dictionary = cat["by_id"][ALTERNATES["torso"]].duplicate(true)
	invalid_dodge["tiers"]["2"]["ability"]["effects"] = {"dodge": 9}
	_check(not bool(StitchedParts.validate_part(invalid_dodge).get("ok", false)),
		"AC3: Dodge without duration rejects even in a tier override")
	var invalid_rank: Dictionary = cat["by_id"][ALTERNATES["arms"]].duplicate(true)
	invalid_rank["ability"]["target"] = [1, 2, 3, 5]
	_check(not bool(StitchedParts.validate_part(invalid_rank).get("ok", false)),
		"AC3: out-of-bounds target rank rejects at validation")
	var duplicate_launch: Dictionary = cat["by_id"][STARTERS["legs"]].duplicate(true)
	duplicate_launch["ability"]["launch"] = [1, 2, 3, 4, 4]
	_check(not bool(StitchedParts.validate_part(duplicate_launch).get("ok", false)),
		"AC3: duplicate launch rank rejects on a crow legs part copy")
	var duplicate_target: Dictionary = cat["by_id"][ALTERNATES["legs"]].duplicate(true)
	duplicate_target["ability"]["target"] = [1, 2, 2, 3]
	_check(not bool(StitchedParts.validate_part(duplicate_target).get("ok", false)),
		"AC3: duplicate target rank rejects on a crow legs part copy")
	var out_of_range_launch: Dictionary = cat["by_id"][STARTERS["legs"]].duplicate(true)
	out_of_range_launch["ability"]["launch"] = [1, 2, 3, 4, 5]
	_check(not bool(StitchedParts.validate_part(out_of_range_launch).get("ok", false)),
		"AC3: out-of-bounds launch rank rejects on a crow legs part copy")
	var out_of_range_target: Dictionary = cat["by_id"][ALTERNATES["legs"]].duplicate(true)
	out_of_range_target["ability"]["target"] = [1, 2, 3, 4, 5]
	_check(not bool(StitchedParts.validate_part(out_of_range_target).get("ok", false)),
		"AC3: out-of-bounds target rank rejects on a crow legs part copy")


## AC1/AC2: the S14 starters stay the same head and arms parts — same IDs, names, owner and
## slots — while their base copy now describes the sewn cloth patch a player sees. Neither
## sentence may advertise a retired part-granted ability, status, target, rank, damage or
## stitch-tier mechanic.
func _test_starter_patch_appearance_text() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: Scarecrow catalog loads for the starter patch copy")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		STARTERS["head"]: {"name": "Sack Glare", "slot": "head", "text": SACK_GLARE_TEXT},
		STARTERS["arms"]: {"name": "Fork Jab", "slot": "arms", "text": FORK_JAB_TEXT},
	}
	# The exact sentences the two starters used to advertise as part-cast moves.
	var old_sentences := [
		"A sack-faced glare Weakens and Marks a foe in enemy ranks 1-3; "
			+ "at stitch tier III it reaches rank 4.",
		"Jab a front foe with the pitchfork, leaving a Bleed.",
	]
	for id in expected:
		var spec: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: starter patch keeps its named ID: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["slot"]) == str(spec["slot"]) and str(part["owner"]) == "scarecrow"
			and str(part["name"]) == str(spec["name"]),
			"AC1: starter patch keeps its slot, Scarecrow owner and name: " + id)
		var text := str(part.get("text", ""))
		_check(not text.is_empty(), "AC2: starter patch base copy is nonempty: " + id)
		_check(text == str(spec["text"]),
			"AC1: starter patch base copy is the exact sewn-cloth sentence: " + id)
		_check(not (text in old_sentences),
			"AC2: starter patch no longer carries a retired part-action sentence: " + id)
		var lowered := text.to_lower()
		for word in PATCH_FORBIDDEN_WORDS:
			_check(not lowered.contains(word),
				"AC2: starter patch copy never advertises retired '%s': %s" % [word, id])
		# Fail-closed: the shipped catalog still refuses a patch copy with blank text.
		var blank: Dictionary = part.duplicate(true)
		blank["text"] = ""
		_check(not bool(StitchedParts.validate_part(blank).get("ok", false)),
			"AC3: a duplicate of %s with blank patch text is rejected fail-closed" % id)


## AC1/AC2: both crow legs parts keep their IDs, names, owner and legs slot, while their base
## copy now describes the sewn feather patch a player actually sees. Neither sentence may
## advertise a retired part-granted attack, status, target, rank, damage or stitch-tier
## mechanic, and each patch still fails closed when its description is blanked.
func _test_crow_leg_patch_appearance_text() -> void:
	var cat := _catalog()
	_check(bool(cat.get("ok", false)), "AC1: Scarecrow catalog loads for the crow legs patch copy")
	if not bool(cat.get("ok", false)):
		return
	var expected := {
		STARTERS["legs"]: {
			"name": "Crow Dive", "slot": "legs",
			"text": CROW_DIVE_PATCH_TEXT, "old": CROW_DIVE_OLD_TEXT,
		},
		ALTERNATES["legs"]: {
			"name": "Crow Peck", "slot": "legs",
			"text": CROW_PECK_PATCH_TEXT, "old": CROW_PECK_OLD_TEXT,
		},
	}
	for id in expected:
		var spec: Dictionary = expected[id]
		_check(cat["by_id"].has(id), "AC1: crow legs patch keeps its named ID: " + id)
		if not cat["by_id"].has(id):
			continue
		var part: Dictionary = cat["by_id"][id]
		_check(str(part["slot"]) == str(spec["slot"]) and str(part["owner"]) == "scarecrow"
			and str(part["name"]) == str(spec["name"]),
			"AC1: crow legs patch keeps its slot, Scarecrow owner and name: " + id)
		var text := str(part.get("text", ""))
		_check(not text.is_empty(), "AC2: crow legs patch base copy is nonempty: " + id)
		_check(text == str(spec["text"]),
			"AC1: crow legs patch base copy is the exact sewn-cloth sentence: " + id)
		_check(text != str(spec["old"]) and not text.contains(str(spec["old"])),
			"AC2: crow legs patch no longer carries its retired part-action sentence: " + id)
		var lowered := text.to_lower()
		for word in PATCH_FORBIDDEN_WORDS:
			_check(not lowered.contains(word),
				"AC2: crow legs patch copy never advertises retired '%s': %s" % [word, id])
		# Fail-closed: the shipped catalog still refuses a patch copy with blank text.
		var blank: Dictionary = part.duplicate(true)
		blank["text"] = ""
		_check(not bool(StitchedParts.validate_part(blank).get("ok", false)),
			"AC3: a duplicate of %s with blank patch text is rejected fail-closed" % id)
	_check(CROW_DIVE_OLD_TEXT != CROW_DIVE_PATCH_TEXT,
		"AC2: the retired Crow Dive attack sentence genuinely differs from its patch copy")
	_check(CROW_PECK_OLD_TEXT != CROW_PECK_PATCH_TEXT,
		"AC2: the retired Crow Peck attack sentence genuinely differs from its patch copy")


func _test_each_tier() -> void:
	var hit_witness: Dictionary = {}
	var damage_witness: Dictionary = {}
	for id in IDS:
		hit_witness[id] = 0
		damage_witness[id] = 0
		for tier in [1, 2, 3]:
			var b := _battle(id, tier, 501042 + tier)
			if b == null:
				continue
			_check(_to(b, "scarecrow"), "AC2: Scarecrow has actual scheduled turn for %s tier %d" % [id, tier])
			if b.current_actor_id() != "scarecrow":
				continue
			var ability: Dictionary = StitchedParts.ability_at_tier(_catalog()["by_id"][id], tier)
			var before := b.state_snapshot()
			var cast := b.use_part(id, 1)
			_check(bool(cast.get("ok", false)) and str(cast.get("actor", "")) == "scarecrow"
				and str(cast.get("part", "")) == id and str(cast.get("ability", "")) == str(ability["id"]),
				"AC2: equipped %s tier %d executes from actual rank 2" % [id, tier])
			if not bool(cast.get("ok", false)):
				continue
			var receipts: Array = cast.get("results", [])
			_check(not receipts.is_empty() and b.state_snapshot() != before,
				"AC2: authoritative state and receipt changed for " + id)
			var expected_count := 3 if bool(ability["multi"]) else 1
			var targets: Dictionary = {}
			for receipt in receipts:
				targets[str(receipt["target"])] = true
			_check(receipts.size() == expected_count and targets.size() == expected_count,
				"AC2: every target resolves once in %s" % id)
			for receipt in receipts:
				if not bool(receipt.get("hit", false)):
					continue
				hit_witness[id] += 1
				if str(ability["target_side"]) == "enemy":
					_check(str(receipt["target_side"]) == "foe", "AC2: attack receipt targets a real foe")
					if int(receipt.get("damage", 0)) > 0:
						damage_witness[id] += 1
					for key in ability["effects"]:
						if key == "duration":
							continue
						_check(receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == str(key)),
							"AC2: landed native " + str(key) + " appears in authoritative receipt for " + id)
						# _advance_turn can immediately tick a tier-I one-turn status when that
						# struck foe becomes the next actor; tier II+ must still persist.
						if tier > 1:
							_check(int(b.get_unit(str(receipt["target"]))["statuses"].get(key, 0)) > 0,
								"AC2: tier II/III native " + str(key) + " persists in real foe state for " + id)
				elif id == STARTERS["torso"]:
					_check(str(receipt["target"]) == "warden"
						and str(b.get_unit("scarecrow")["guard_target"]) == "warden"
						and receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "guard"),
						"AC2: Guard targets actual Warden and appears in authoritative receipt")
				elif id == ALTERNATES["torso"]:
					_check(str(receipt["target"]) == "warden"
						and int(b.get_unit("warden")["dodge_buff"].get("amount", 0)) > 0
						and receipt.get("statuses", []).any(func(s): return str(s.get("status", "")) == "dodge"),
						"AC2: temporary Dodge exists on real ally and in receipt")
	for id in IDS:
		_check(int(hit_witness[id]) > 0, "AC2: nonvacuous hit/status witness across three tiers for " + id)
	for id in [STARTERS["arms"], STARTERS["legs"], ALTERNATES["arms"], ALTERNATES["legs"]]:
		_check(int(damage_witness[id]) > 0, "AC2: nonvacuous actual enemy damage for " + id)


func _test_area_and_effects() -> void:
	for id in [ALTERNATES["head"], ALTERNATES["arms"]]:
		var witnessed := false
		for seed_value in range(501100, 501140):
			var b := _battle(id, 2, seed_value)
			if b == null or not _to(b, "scarecrow"):
				continue
			var cast := b.use_part(id, 1)
			if not bool(cast.get("ok", false)) or cast.get("results", []).size() != 3:
				continue
			var distinct: Dictionary = {}
			var landed := 0
			for receipt in cast["results"]:
				var target_id := str(receipt["target"])
				distinct[target_id] = true
				if bool(receipt.get("hit", false)) and int(b.get_unit(target_id)["statuses"].get("weak", 0)) > 0:
					landed += 1
			witnessed = distinct.has("fray_scavenger") and distinct.has("scissor_crab") and distinct.has("moth_scribe") and landed == 3
			if witnessed:
				break
		_check(witnessed, "AC2: seeded %s Weakens three distinct actual foes in one area cast" % id)
	var bleed := false
	for seed_value in range(501141, 501170):
		var b := _battle(STARTERS["arms"], 1, seed_value)
		if b == null or not _to(b, "scarecrow"):
			continue
		var before := int(b.get_unit("fray_scavenger")["hp"])
		var jab := b.use_part(STARTERS["arms"], 1)
		if bool(jab.get("ok", false)) and jab.get("results", []).size() == 1:
			var hit: Dictionary = jab["results"][0]
			bleed = bool(hit.get("hit", false)) and int(hit.get("damage", 0)) > 0
			bleed = bleed and int(b.get_unit("fray_scavenger")["hp"]) < before
			bleed = bleed and int(b.get_unit("fray_scavenger")["statuses"].get("bleed", 0)) > 0
			bleed = bleed and hit.get("statuses", []).any(func(s): return str(s.get("status", "")) == "bleed")
			if bleed:
				break
	_check(bleed, "AC2: genuine Fork Jab deals foe HP damage and applies Bleed in state and receipt")


func _test_guard_and_dodge() -> void:
	var guarded := false
	for seed_value in range(501180, 501220):
		var b := _battle(STARTERS["torso"], 2, seed_value)
		if b == null or not _to(b, "scarecrow"):
			continue
		var cast := b.use_part(STARTERS["torso"], 1)
		if not bool(cast.get("ok", false)) or str(b.get_unit("scarecrow")["guard_target"]) != "warden":
			continue
		if not _to(b, "fray_scavenger"):
			continue
		var attack := b.use_foe_ability("sack_swing", 1)
		if bool(attack.get("ok", false)) and attack.get("results", []).size() == 1:
			guarded = str(attack["results"][0].get("guarded_by", "")) == "scarecrow"
			if guarded:
				break
	_check(guarded, "AC2: foe strike on Warden redirects to Scarecrow's actual Guard")
	var dodge := _battle(ALTERNATES["torso"], 2, 501221)
	if dodge != null and _to(dodge, "scarecrow"):
		var before := int(StitchedRules.effective_dodge(dodge.get_unit("warden")))
		var cast := dodge.use_part(ALTERNATES["torso"], 1)
		var after := dodge.get_unit("warden")
		_check(bool(cast.get("ok", false)) and after.get("dodge_buff", {}).get("amount", 0) == 8
			and int(after["dodge_buff"].get("turns", 0)) == 2
			and int(StitchedRules.effective_dodge(after)) > before
			and cast.get("results", []).size() == 1
			and cast["results"][0].get("statuses", []).any(func(s): return str(s.get("status", "")) == "dodge"),
			"AC2: tier-II Straw Wrap grants bounded temporary Dodge with receipt to real Warden")


func _test_mark_damage() -> void:
	for crow_part in [STARTERS["legs"], ALTERNATES["legs"]]:
		var witnessed := false
		for seed_value in range(501230, 501300):
			var marked := _battle(crow_part, 1, seed_value)
			var plain := _battle(crow_part, 1, seed_value)
			if marked == null or plain == null or not _to(marked, "scarecrow") or not _to(plain, "scarecrow"):
				continue
			var mark_cast := marked.use_part(STARTERS["head"], 1)
			var twin_cast := plain.use_part(STARTERS["head"], 1)
			if mark_cast != twin_cast or not bool(mark_cast.get("ok", false)) or mark_cast.get("results", []).is_empty():
				continue
			if not bool(mark_cast["results"][0].get("hit", false)):
				continue
			plain._units["fray_scavenger"]["statuses"].erase("mark")
			if not _to(marked, "scarecrow") or not _to(plain, "scarecrow"):
				continue
			if int(marked.get_unit("fray_scavenger")["statuses"].get("mark", 0)) <= 0:
				continue
			if marked.rng_state() != plain.rng_state():
				continue
			var enhanced := marked.use_part(crow_part, 1)
			var normal := plain.use_part(crow_part, 1)
			if not bool(enhanced.get("ok", false)) or not bool(normal.get("ok", false)):
				continue
			if enhanced.get("results", []).is_empty() or normal.get("results", []).is_empty():
				continue
			if bool(enhanced["results"][0].get("hit", false)) and bool(normal["results"][0].get("hit", false)):
				witnessed = int(enhanced["results"][0]["damage"]) > int(normal["results"][0]["damage"])
				witnessed = witnessed and marked.rng_state() == plain.rng_state()
				if witnessed:
					break
		_check(witnessed, "AC2: actual Sack Glare Mark adds damage to %s at matched RNG" % crow_part)


## AC1/AC3 data contract: both crow legs abilities may launch from allied ranks 1-4 at every
## tier. Crow Peck reaches enemy rank 4 at every tier while Crow Dive reaches it only from
## stitch tier II onward; tier I keeps its authored enemy ranks 1-3. Crow Flock's alternate
## head launches from hero ranks 2-4 and reaches all four enemy ranks. Every other authored
## value stays unchanged.
func _test_leg_rank4_data() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var unchanged_launches := {
		"scarecrow_head_sack_glare": [1, 2, 3],
		"scarecrow_arms_fork_jab": [1, 2],
		"scarecrow_torso_straw_padding": [1, 2, 3],
		"scarecrow_arms_harvest_fright": [1, 2, 3],
		"scarecrow_torso_straw_wrap": [1, 2, 3],
	}
	for id in unchanged_launches:
		_check(cat["by_id"][id]["ability"]["launch"] == unchanged_launches[id],
			"AC1: five other Scarecrow parts keep their authored launch: " + id)
	# Crow Flock already reaches enemy rank 4; its launch, multi semantics and pose
	# stay fixed while tier-I Weak alone now lasts through the foe's next strike.
	var flock: Dictionary = cat["by_id"][ALTERNATES["head"]]
	var flock_launch := [2, 3, 4]
	var flock_launch_mask := StitchedParts.rank_mask(flock_launch)
	var flock_target := [1, 2, 3, 4]
	var flock_target_mask := StitchedParts.rank_mask(flock_target)
	_check(str(flock["name"]) == "Crow Flock" and str(flock["slot"]) == "head"
		and str(flock["owner"]) == "scarecrow" and flock["stat"] == {"crit": 4},
		"AC1: Crow Flock keeps its head slot, owner and crit stat")
	_check(str(flock["ability"]["id"]) == "scarecrow_head_crow_flock_move"
		and str(flock["ability"]["name"]) == "Crow Flock"
		and str(flock["ability"]["kind"]) == "debuff"
		and str(flock["ability"]["target_side"]) == "enemy"
		and bool(flock["ability"]["multi"])
		and int(flock["ability"]["acc"]) == 90 and flock["ability"]["dmg"] == [0, 0]
		and int(flock["ability"]["crit"]) == 0 and int(flock["ability"]["mark_damage"]) == 0
		and int(flock["ability"]["self_move"]) == 0 and str(flock["ability"]["move"]) == "skill",
		"AC1: Crow Flock keeps its authored multi enemy debuff, ACC and skill pose")
	_check(flock["ability"]["launch"] == flock_launch
		and int(flock["ability"]["launch_mask"]) == flock_launch_mask,
		"AC1: Crow Flock base launch is exactly hero ranks 2-4")
	_check(flock["ability"]["target"] == flock_target
		and int(flock["ability"]["target_mask"]) == flock_target_mask
		and flock_target_mask == StitchedParts.ALL_RANKS_MASK,
		"AC1: Crow Flock base target is exactly all four enemy ranks")
	_check(str(flock["text"]) == "Call crows across foe ranks one to four; Weak and Mark each struck foe.",
		"AC1: Crow Flock text states its four-foe reach")
	for flock_tier in [1, 2, 3]:
		var flock_ability := StitchedParts.ability_at_tier(flock, flock_tier)
		_check(bool(StitchedParts.validate_ability(flock_ability).get("ok", false)),
			"AC1: Crow Flock tier %d validates" % flock_tier)
		_check(flock_ability["launch"] == flock_launch
			and int(flock_ability["launch_mask"]) == flock_launch_mask,
			"AC1: Crow Flock tier %d launches from hero ranks 2-4" % flock_tier)
		for rank in [2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(flock_ability["launch_mask"]), rank),
				"AC1: Crow Flock tier %d may launch from hero rank %d" % [flock_tier, rank])
		for rank in [0, 1, 5]:
			_check(not StitchedParts.ranks_allowed(int(flock_ability["launch_mask"]), rank),
				"AC1: Crow Flock tier %d never launches from hero rank %d" % [flock_tier, rank])
		_check(flock_ability["target"] == flock_target
			and int(flock_ability["target_mask"]) == flock_target_mask
			and flock_target_mask == StitchedParts.ALL_RANKS_MASK,
			"AC1: Crow Flock tier %d keeps all four enemy ranks" % flock_tier)
		for rank in [1, 2, 3, 4]:
			_check(StitchedParts.ranks_allowed(int(flock_ability["target_mask"]), rank),
				"AC1: Crow Flock tier %d reaches enemy rank %d" % [flock_tier, rank])
		for rank in [0, 5]:
			_check(not StitchedParts.ranks_allowed(int(flock_ability["target_mask"]), rank),
				"AC1: Crow Flock tier %d excludes enemy rank %d" % [flock_tier, rank])
		var expected_weak := 2 if flock_tier < 3 else 3
		var expected_mark: int = 2 if flock_tier < 3 else 3
		var expected_crit: int = 3 + flock_tier
		_check(flock_ability["effects"] == {"weak": expected_weak, "mark": expected_mark},
			"AC1: Crow Flock tier %d keeps Weak %d and Mark %d"
				% [flock_tier, expected_weak, expected_mark])
		_check(StitchedParts.stat_at_tier(flock, flock_tier) == {"crit": expected_crit}
			and expected_crit == {1: 4, 2: 5, 3: 6}[flock_tier],
			"AC1: Crow Flock tier %d grants its exact crit stat %d"
				% [flock_tier, expected_crit])
		_check(flock["stat"] == {"crit": 4},
			"AC1: Crow Flock tier-%d read leaves the base crit stat untouched" % flock_tier)
	_check(flock["ability"]["launch"] == flock_launch
		and flock["ability"]["effects"] == {"weak": 2, "mark": 2},
		"AC1: tier reads never replace Crow Flock's base launch or potency")
	var full_mask := StitchedParts.rank_mask([1, 2, 3, 4])
	_check(full_mask == StitchedParts.ALL_RANKS_MASK,
		"AC1: allied ranks 1-4 form the full launch mask")
	for id in CROW_LEGS:
		var part: Dictionary = cat["by_id"][id]
		var spec: Dictionary = CROW_LEGS[id]
		var base: Dictionary = part["ability"]
		var target_ranks: Array = spec["target"]
		var target_mask := StitchedParts.rank_mask(target_ranks)
		_check(str(part["slot"]) == "legs" and str(part["owner"]) == "scarecrow"
			and part["stat"] == spec["stat"],
			"AC1: " + id + " keeps its legs slot, owner and stat")
		_check(str(base["id"]) == str(spec["ability_id"]) and str(base["name"]) == str(spec["name"])
			and str(base["kind"]) == "ranged" and str(base["target_side"]) == "enemy"
			and not bool(base["multi"]),
			"AC1: " + id + " keeps its ability id, name and ranged single-target shape")
		_check(int(base["acc"]) == int(spec["acc"]) and base["dmg"] == spec["dmg"]
			and int(base["crit"]) == int(spec["crit"]) and base["effects"] == spec["effects"]
			and int(base["mark_damage"]) == int(spec["mark_damage"])
			and str(base["move"]) == str(spec["move"]) and int(base["self_move"]) == 0,
			"AC1: " + id + " keeps its ACC, damage, crit, Mark, mark_damage and pose")
		_check(base["launch"] == [1, 2, 3, 4] and int(base["launch_mask"]) == full_mask,
			"AC1: " + id + " base launch adds only hero rank 4")
		_check(base["target"] == target_ranks and int(base["target_mask"]) == target_mask,
			"AC1: " + id + " base target matches its authored enemy ranks")
		for tier in [1, 2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var tier_ranks: Array = target_ranks
			if tier > 1 and spec["tier" + str(tier)].has("target"):
				tier_ranks = spec["tier" + str(tier)]["target"]
			var tier_mask := StitchedParts.rank_mask(tier_ranks)
			_check(ability["launch"] == [1, 2, 3, 4] and int(ability["launch_mask"]) == full_mask,
				"AC1: %s tier %d keeps the base launch array with rank 4" % [id, tier])
			for rank in [1, 2, 3, 4]:
				_check(StitchedParts.ranks_allowed(int(ability["launch_mask"]), rank),
					"AC2: %s tier %d may launch from hero rank %d" % [id, tier, rank])
			_check(not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 0)
				and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 5),
				"AC1: %s tier %d launch mask excludes ranks 0 and 5" % [id, tier])
			_check(ability["target"] == tier_ranks and int(ability["target_mask"]) == tier_mask,
				"AC1: %s tier %d resolves its authored enemy target ranks" % [id, tier])
			for rank in [1, 2, 3, 4]:
				_check(StitchedParts.ranks_allowed(int(ability["target_mask"]), rank)
					== (rank in tier_ranks),
					"AC1: %s tier %d enemy target rank %d matches its authored mask" % [id, tier, rank])
			_check(not StitchedParts.ranks_allowed(int(ability["target_mask"]), 0)
				and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 5),
				"AC1: %s tier %d target mask excludes ranks 0 and 5" % [id, tier])
			if id == ALTERNATES["legs"]:
				_check(ability["target"] == [1, 2, 3, 4]
					and int(ability["target_mask"]) == StitchedParts.ALL_RANKS_MASK,
					"AC1: Crow Peck tier %d resolves all four enemy ranks" % tier)
			elif tier == 1:
				_check(ability["target"] == [1, 2, 3] and tier_mask == StitchedParts.rank_mask([1, 2, 3])
					and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 4),
					"AC1: Crow Dive tier I still targets enemy ranks 1-3 only")
			else:
				_check(ability["target"] == [1, 2, 3, 4]
					and int(ability["target_mask"]) == StitchedParts.ALL_RANKS_MASK
					and StitchedParts.ranks_allowed(int(ability["target_mask"]), 4),
					"AC1: Crow Dive tier %d reaches enemy rank 4" % tier)
		_check(str(cat["by_id"][STARTERS["legs"]]["text"]) == CROW_DIVE_PATCH_TEXT,
			"AC1: Crow Dive base copy is its exact sewn feather patch sentence, not an attack")
		for tier in [2, 3]:
			var ability := StitchedParts.ability_at_tier(part, tier)
			var tier_spec: Dictionary = spec["tier" + str(tier)]
			_check(ability["dmg"] == tier_spec["dmg"]
				and int(ability["mark_damage"]) == int(tier_spec["mark_damage"])
				and ability["effects"] == tier_spec["effects"],
				"AC1: %s tier %d keeps its authored damage, mark_damage and effects" % [id, tier])


## AC1: Sack Glare's base Weak now lasts through the next foe attack (2), matching
## tier II's Weak 2/Mark 2. Tier III stays Weak 3/Mark 3 and alone adds enemy rank 4.
## All other fields and the seven sibling parts remain pinned below.
func _test_sack_glare_rank4_data() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][STARTERS["head"]]
	var base: Dictionary = part["ability"]
	_check(str(part["name"]) == "Sack Glare" and str(part["slot"]) == "head"
		and str(part["owner"]) == "scarecrow" and part["stat"] == {"acc": 4},
		"AC1: Sack Glare keeps its head slot, owner and acc stat")
	_check(str(base["id"]) == "scarecrow_head_sack_glare_move"
		and str(base["name"]) == "Sack Glare" and str(base["kind"]) == "debuff"
		and str(base["target_side"]) == "enemy" and not bool(base["multi"])
		and int(base["acc"]) == 92 and base["dmg"] == [0, 0] and int(base["crit"]) == 0
		and int(base["self_move"]) == 0 and str(base["move"]) == "skill",
		"AC1: Sack Glare keeps its authored single-target enemy debuff, ACC and skill pose")
	var front_mask := StitchedParts.rank_mask([1, 2, 3])
	_check(front_mask == 0b1110 and front_mask != StitchedParts.ALL_RANKS_MASK,
		"AC1: enemy ranks 1-3 form a mask that excludes rank 4")
	_check(base["target"] == [1, 2, 3] and int(base["target_mask"]) == front_mask
		and StitchedParts.ranks_allowed(int(base["target_mask"]), 3)
		and not StitchedParts.ranks_allowed(int(base["target_mask"]), 4),
		"AC1: Sack Glare base target stays enemy ranks 1-3")
	for tier in [1, 2]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			"AC1: Sack Glare tier %d resolves as a validated ability" % tier)
		_check(ability["target"] == [1, 2, 3]
			and int(ability["target_mask"]) == front_mask
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 1)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 2)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 3)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 4)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 5),
			"AC1: Sack Glare tier %d still targets enemy ranks 1-3 only" % tier)
		_check(ability["launch"] == [1, 2, 3]
			and int(ability["launch_mask"]) == front_mask
			and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 4),
			"AC1: Sack Glare tier %d keeps its hero rank 1-3 launch" % tier)
		_check(ability["effects"] == {"weak": 2, "mark": 2},
			"AC1: Sack Glare tier %d keeps its authored Weak and Mark" % tier)
		_check(str(ability["kind"]) == "debuff" and not bool(ability["multi"])
			and int(ability["acc"]) == 92 and ability["dmg"] == [0, 0]
			and int(ability["crit"]) == 0 and str(ability["move"]) == "skill",
			"AC1: Sack Glare tier %d keeps its single-target accuracy, damage and pose" % tier)
	for tier in [1, 2, 3]:
		var expected_acc: int = 3 + tier
		_check(StitchedParts.stat_at_tier(part, tier) == {"acc": expected_acc}
			and expected_acc == {1: 4, 2: 5, 3: 6}[tier],
			"AC1: Sack Glare tier %d grants its exact acc stat %d" % [tier, expected_acc])
		_check(part["stat"] == {"acc": 4},
			"AC1: Sack Glare tier-%d read leaves the base acc stat untouched" % tier)
	_check(part["tiers"]["2"]["ability"].get("effects") == {"weak": 2, "mark": 2},
		"AC1: the tier-II override keeps Weak 2/Mark 2")
	# The loaded catalog normalises every tier into a full merged ability, so the authored
	# override shape itself is checked against the raw JSON: only tier III gains a target list.
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var raw_part: Dictionary = {}
	if raw is Dictionary and raw.get("parts") is Array:
		for entry in raw["parts"]:
			if entry is Dictionary and str(entry.get("id", "")) == STARTERS["head"]:
				raw_part = entry
	_check(not raw_part.is_empty(), "AC1: the raw Sack Glare JSON entry is readable")
	if not raw_part.is_empty():
		var raw_tiers: Dictionary = raw_part.get("tiers", {})
		var raw_tier2: Dictionary = raw_tiers.get("2", {}).get("ability", {})
		var raw_tier3: Dictionary = raw_tiers.get("3", {}).get("ability", {})
		_check(_int_ranks(raw_part["ability"]["target"]) == [1, 2, 3],
			"AC1: the authored base ability keeps enemy ranks 1-3")
		_check(not raw_tier2.has("target")
			and raw_tier2.keys().size() == 1 and raw_tier2.has("effects"),
			"AC1: the authored tier-II override adds no target reach")
		_check(_int_ranks(raw_tier3.get("target")) == [1, 2, 3, 4]
			and _int_effects(raw_tier3.get("effects")) == {"weak": 3, "mark": 3}
			and raw_tier3.keys().size() == 2,
			"AC1: the authored tier-III override adds only the enemy rank 1-4 target list")
	var tier3: Dictionary = StitchedParts.ability_at_tier(part, 3)
	_check(part["tiers"]["3"]["ability"]["target"] == [1, 2, 3, 4],
		"AC1: only the tier-III override authors the enemy rank 1-4 target list")
	_check(bool(StitchedParts.validate_ability(tier3).get("ok", false)),
		"AC1: Sack Glare tier III resolves as a validated ability")
	_check(tier3["target"] == [1, 2, 3, 4]
		and int(tier3["target_mask"]) == StitchedParts.ALL_RANKS_MASK
		and StitchedParts.ranks_allowed(int(tier3["target_mask"]), 4)
		and StitchedParts.ranks_allowed(int(tier3["target_mask"]), 1)
		and not StitchedParts.ranks_allowed(int(tier3["target_mask"]), 0)
		and not StitchedParts.ranks_allowed(int(tier3["target_mask"]), 5),
		"AC1: Sack Glare tier III targets enemy ranks 1-4 and never 0 or 5")
	_check(tier3["launch"] == [1, 2, 3] and int(tier3["launch_mask"]) == front_mask
		and not StitchedParts.ranks_allowed(int(tier3["launch_mask"]), 4),
		"AC1: Sack Glare tier III still launches only from hero ranks 1-3")
	_check(tier3["effects"] == {"weak": 3, "mark": 3},
		"AC1: Sack Glare tier III keeps Weak 3 and Mark 3")
	_check(str(tier3["kind"]) == "debuff" and not bool(tier3["multi"])
		and int(tier3["acc"]) == 92 and tier3["dmg"] == [0, 0]
		and int(tier3["crit"]) == 0 and str(tier3["move"]) == "skill",
		"AC1: Sack Glare tier III keeps its single-target accuracy, zero damage and pose")
	_check(base["target"] == [1, 2, 3] and base["effects"] == {"weak": 2, "mark": 2}
		and int(base["target_mask"]) == front_mask,
		"AC1: tier reads never replace Sack Glare's authored base reach or potency")
	_check(str(part["text"]) == SACK_GLARE_TEXT,
		"AC1: Sack Glare base copy describes its sewn burlap brow patch, not the retired cast")
	for id in SIBLING_PARTS:
		var sibling: Dictionary = cat["by_id"][id]
		var spec: Dictionary = SIBLING_PARTS[id]
		var sibling_base: Dictionary = sibling["ability"]
		_check(str(sibling["slot"]) == str(spec["slot"]) and sibling["stat"] == spec["stat"],
			"AC1: seven sibling parts keep slot and stat: " + id)
		for key in ["launch", "target", "target_side", "multi", "acc", "dmg", "crit", "effects", "move"]:
			_check(sibling_base[key] == spec[key],
				"AC1: seven sibling parts keep authored %s: %s" % [str(key), id])


## The shipped preview with only an in-memory rank swap: Scarecrow leaves index 1 and appends
## behind the three preview companions, so he genuinely stands in allied rank 4.
func _rank4_config(selected: String = "", tier: int = 1, seed_value: int = 501041) -> Dictionary:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return {}
	var scarecrow: Dictionary = config["heroes"].pop_at(1)
	config["heroes"].append(scarecrow)
	return config


func _rank4_battle(selected: String, tier: int, seed_value: int) -> StitchedRules:
	var config := _rank4_config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var built := StitchedRules.create(config)
	if not bool(built.get("ok", false)):
		return null
	return built["battle"]


## The shipped 4v3 battle stays exactly as authored; only the already-existing third foe,
## the Moth Scribe, moves to enemy rank 4 in test memory. Rank 3 is left empty and no
## fourth foe is introduced. Scarecrow keeps his real rank-2 preview slot; the selected
## part and tier let other abilities reuse the same authentic fixture.
func _rank4_foe_battle(
	seed_value: int,
	selected: String = ALTERNATES["legs"],
	tier: int = 1
) -> StitchedRules:
	var config := _config(selected, tier, seed_value)
	if config.is_empty():
		return null
	var built := StitchedRules.create(config)
	if not bool(built.get("ok", false)):
		return null
	var b: StitchedRules = built["battle"]
	if b.get_foes().size() != 3 or b.get_unit("moth_scribe").is_empty():
		return null
	b._units["moth_scribe"]["rank"] = 4
	return b


## AC2/AC3: each crow legs ability fires from Scarecrow's real rank-4 turn against the real
## rank-1 foe. A vacant enemy rank 4 still rejects for both; with the existing Moth Scribe
## moved there, Crow Peck lands at every tier while Crow Dive lands only once upgraded to
## tiers II/III.
func _test_rank4_crows() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	for leg_id in [STARTERS["legs"], ALTERNATES["legs"]]:
		var ability: Dictionary = StitchedParts.ability_at_tier(cat["by_id"][leg_id], 1)
		var setup := _rank4_battle(leg_id, 1, 501300)
		_check(setup != null, "AC2: genuine rank-4 battle builds for " + leg_id)
		if setup != null:
			var heroes: Array = setup.get_heroes()
			var foes: Array = setup.get_foes()
			_check(heroes.size() == 4 and foes.size() == 3,
				"AC2: rank-4 witness keeps four real heroes and the three S2 foes")
			var scarecrow := setup.get_unit("scarecrow")
			_check(int(scarecrow.get("rank", -1)) == 4
				and str(scarecrow.get("parts", {}).get("legs", {}).get("id", "")) == leg_id,
				"AC2: Scarecrow actually stands in rank 4 wearing " + leg_id)
			_check(int(setup.get_unit("warden")["rank"]) == 1
				and int(setup.get_unit("tinker")["rank"]) == 2
				and int(setup.get_unit("lantern_monk")["rank"]) == 3,
				"AC2: the three preview companions keep their relative rank order")
			for id in ENEMY_IDS:
				_check(not setup.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
			if _to(setup, "scarecrow"):
				for bad_rank in [0, 4, 5]:
					_reject_without_spend(setup, leg_id, bad_rank,
						"%s rejects enemy rank %d without a legal target" % [leg_id, bad_rank])
			else:
				_check(false, "AC3: rank-4 target rejection receives an actual Scarecrow turn")
		var witnessed := false
		var landed := false
		for seed_value in range(501300, 501380):
			var b := _rank4_battle(leg_id, 1, seed_value)
			if b == null or not _to(b, "scarecrow"):
				continue
			if int(b.get_unit("scarecrow")["rank"]) != 4:
				continue
			var before := b.state_snapshot()
			var foe_before := b.get_unit("fray_scavenger")
			var cast := b.use_part(leg_id, 1)
			if not bool(cast.get("ok", false)):
				continue
			var receipts: Array = cast.get("results", [])
			if receipts.is_empty():
				continue
			if not witnessed:
				witnessed = true
				var after := b.state_snapshot()
				_check(str(cast.get("actor", "")) == "scarecrow"
					and str(cast.get("part", "")) == leg_id
					and str(cast.get("ability", "")) == str(ability["id"]),
					"AC2: " + leg_id + " executes from the actual rank-4 turn")
				_check(receipts.size() == 1 and str(receipts[0]["target"]) == "fray_scavenger"
					and str(receipts[0]["target_side"]) == "foe"
					and int(receipts[0]["target_rank"]) == 1
					and int(foe_before.get("hp", 0)) > 0,
					"AC2: " + leg_id + " resolves one receipt on the real living rank-1 foe")
				_check(int(after["round"]) != int(before["round"])
					or int(after["turn_index"]) != int(before["turn_index"]),
					"AC2: " + leg_id + " actually spends Scarecrow's turn")
			if bool(receipts[0].get("hit", false)) and int(receipts[0].get("damage", 0)) > 0:
				if leg_id == ALTERNATES["legs"]:
					landed = receipts[0].get("statuses", []).any(
						func(s): return str(s.get("status", "")) == "mark")
					landed = landed and int(b.get_unit("fray_scavenger")["statuses"].get("mark", 0)) > 0
				else:
					landed = true
			if witnessed and landed:
				break
		_check(witnessed, "AC2: bounded fixed-seed rank-4 cast witness for " + leg_id)
		_check(landed, "AC2: bounded fixed-seed landed rank-4 hit witness for " + leg_id)

	# AC2: real 4v3 fixture, then the existing third foe (Moth Scribe) moves to enemy rank 4.
	var foe_witnessed := false
	var foe_landed := false
	var structure_checked := false
	var replay_seed := -1
	var replay_cast: Dictionary = {}
	var replay_snapshot: Dictionary = {}
	var replay_rng := -1
	for seed_value in range(501400, 501460):
		var b := _rank4_foe_battle(seed_value)
		if b == null or not _to(b, "scarecrow"):
			continue
		if not structure_checked:
			structure_checked = true
			var foes: Array = b.get_foes()
			_check(foes.size() == 3,
				"AC2: rank-4 foe witness keeps exactly three initial foes")
			_check(int(b.get_unit("moth_scribe")["rank"]) == 4
				and int(b.get_unit("fray_scavenger")["rank"]) == 1
				and int(b.get_unit("scissor_crab")["rank"]) == 2,
				"AC2: the existing Moth Scribe stands alone in enemy rank 4")
			_check(foes.all(func(foe): return int(foe["rank"]) != 3),
				"AC2: moving the Moth Scribe leaves enemy rank 3 empty")
		var before := b.state_snapshot()
		var cast := b.use_part(ALTERNATES["legs"], 4)
		var receipts: Array = cast.get("results", [])
		if not bool(cast.get("ok", false)) or receipts.size() != 1:
			continue
		if str(receipts[0]["target"]) != "moth_scribe" or int(receipts[0]["target_rank"]) != 4:
			continue
		if not foe_witnessed:
			foe_witnessed = true
			var after := b.state_snapshot()
			_check(str(cast.get("actor", "")) == "scarecrow"
				and str(cast.get("part", "")) == ALTERNATES["legs"]
				and str(receipts[0]["target_side"]) == "foe",
				"AC2: Crow Peck at rank 4 returns exactly one receipt for the rank-4 foe")
			_check(int(after["round"]) != int(before["round"])
				or int(after["turn_index"]) != int(before["turn_index"]),
				"AC2: rank-4 Crow Peck actually spends Scarecrow's turn")
			_reject_without_spend(b, ALTERNATES["legs"], 4,
				"replayed rank-4 Crow Peck after the turn is spent")
		if bool(receipts[0].get("hit", false)) and int(receipts[0].get("damage", 0)) > 0:
			var marked: bool = receipts[0].get("statuses", []).any(
				func(s): return str(s.get("status", "")) == "mark")
			marked = marked and int(b.get_unit("moth_scribe")["statuses"].get("mark", 0)) > 0
			if marked:
				foe_landed = true
				replay_seed = seed_value
				replay_cast = cast.duplicate(true)
				replay_snapshot = b.state_snapshot()
				replay_rng = b.rng_state()
		if foe_witnessed and foe_landed:
			break
	_check(foe_witnessed, "AC2: bounded fixed-seed rank-4 Crow Peck cast witness")
	_check(foe_landed, "AC2: bounded fixed-seed Crow Peck damages and Marks the rank-4 foe")
	if replay_seed >= 0:
		var replay := _rank4_foe_battle(replay_seed)
		var replayed := {}
		if replay != null and _to(replay, "scarecrow"):
			replayed = replay.use_part(ALTERNATES["legs"], 4)
		_check(not replayed.is_empty() and replayed == replay_cast
			and replay.state_snapshot() == replay_snapshot and replay.rng_state() == replay_rng,
			"AC2: same rank-4 input and seed replay identical receipt, snapshot and RNG")

	# AC1/AC2, the task goal: upgraded Crow Dive reaches the occupied rear rank. Tier I must
	# still refuse that same real rank-4 target; tiers II and III each resolve exactly one
	# genuine hit on the living Moth Scribe. The empty rear rank on the unaltered preview
	# fails closed at every tier, and a landed tier-II/III seed replays from a fresh fixture.
	var crow_dive: Dictionary = cat["by_id"][STARTERS["legs"]]
	var dive_tier1 := StitchedParts.ability_at_tier(crow_dive, 1)
	_check(dive_tier1["target"] == [1, 2, 3]
		and not StitchedParts.ranks_allowed(int(dive_tier1["target_mask"]), 4),
		"AC1: Crow Dive tier I target rank 4 is still illegal")
	var tier_one_setup := _rank4_foe_battle(501600, STARTERS["legs"], 1)
	_check(tier_one_setup != null, "AC2: genuine occupied-rank-4 Crow Dive tier-I battle builds")
	if tier_one_setup != null:
		var tier_one_foes: Array = tier_one_setup.get_foes()
		_check(tier_one_foes.size() == 3
			and int(tier_one_setup.get_unit("moth_scribe")["rank"]) == 4
			and int(tier_one_setup.get_unit("fray_scavenger")["rank"]) == 1
			and int(tier_one_setup.get_unit("scissor_crab")["rank"]) == 2
			and tier_one_foes.all(func(foe): return int(foe["rank"]) != 3),
			"AC2: Crow Dive witness keeps three real foes with only the Moth Scribe at rank 4")
		if _to(tier_one_setup, "scarecrow"):
			_reject_without_spend(tier_one_setup, STARTERS["legs"], 4,
				"Crow Dive tier I rejects the occupied enemy rank 4")
		else:
			_check(false, "AC2: Crow Dive tier-I rejection receives a real Scarecrow turn")
	# An empty enemy rank 4 on the unaltered preview still fails closed, even once the tier-II
	# and tier-III target masks allow rank 4.
	for tier in [1, 2, 3]:
		var empty := _battle(STARTERS["legs"], tier, 501610 + tier)
		_check(empty != null, "AC2: unaltered three-foe preview builds for Crow Dive tier %d" % tier)
		if empty == null:
			continue
		_check(empty.get_foes().all(func(foe): return int(foe["rank"]) != 4),
			"AC2: unaltered preview leaves enemy rank 4 genuinely empty at tier %d" % tier)
		if _to(empty, "scarecrow"):
			_reject_without_spend(empty, STARTERS["legs"], 4,
				"Crow Dive tier %d rejects the empty enemy rank 4" % tier)
		else:
			_check(false, "AC2: empty-rank-4 Crow Dive tier %d receives a real turn" % tier)
	for tier in [2, 3]:
		var dive_ability := StitchedParts.ability_at_tier(crow_dive, tier)
		_check(dive_ability["target"] == [1, 2, 3, 4]
			and StitchedParts.ranks_allowed(int(dive_ability["target_mask"]), 4),
			"AC1: Crow Dive tier %d target mask permits enemy rank 4" % tier)
		var witnessed := false
		var landed := false
		var accepted_seed := -1
		var accepted_cast: Dictionary = {}
		var accepted_snapshot: Dictionary = {}
		var accepted_rng := -1
		for seed_value in range(501620 + (tier - 2) * 120, 501740 + (tier - 2) * 120):
			var b := _rank4_foe_battle(seed_value, STARTERS["legs"], tier)
			if b == null or not _to(b, "scarecrow"):
				continue
			var before := b.state_snapshot()
			var scribe_before := b.get_unit("moth_scribe")
			var cast := b.use_part(STARTERS["legs"], 4)
			if not bool(cast.get("ok", false)):
				continue
			var receipts: Array = cast.get("results", [])
			if receipts.size() != 1:
				continue
			var hit: Dictionary = receipts[0]
			if str(hit.get("target", "")) != "moth_scribe" or int(hit.get("target_rank", 0)) != 4:
				continue
			if str(hit.get("target_side", "")) != "foe" or int(scribe_before.get("hp", 0)) <= 0:
				continue
			if not witnessed:
				witnessed = true
				var after := b.state_snapshot()
				_check(str(cast.get("action", "")) == "ability"
					and str(cast.get("actor", "")) == "scarecrow"
					and str(cast.get("part", "")) == STARTERS["legs"]
					and str(cast.get("ability", "")) == str(dive_ability["id"]),
					"AC2: Crow Dive tier %d executes as the real equipped Scarecrow legs" % tier)
				_check(b.get_foes().size() == 3
					and b.get_foes().all(func(foe): return int(foe["rank"]) != 3),
					"AC2: Crow Dive tier %d keeps exactly three foes and no rank-3 phantom" % tier)
				_check(int(after["round"]) != int(before["round"])
					or int(after["turn_index"]) != int(before["turn_index"]),
					"AC2: Crow Dive tier %d spends Scarecrow's real turn" % tier)
			if bool(hit.get("hit", false)) and int(hit.get("damage", 0)) > 0 \
				and int(b.get_unit("moth_scribe")["hp"]) < int(scribe_before["hp"]):
				landed = true
				accepted_seed = seed_value
				accepted_cast = cast.duplicate(true)
				accepted_snapshot = b.state_snapshot()
				accepted_rng = b.rng_state()
			if witnessed and landed:
				break
		_check(witnessed, "AC2: bounded fixed-seed Crow Dive tier %d rank-4 cast witness" % tier)
		_check(landed, "AC2: bounded fixed-seed Crow Dive tier %d damages the living rank-4 foe" % tier)
		if accepted_seed >= 0:
			var replay := _rank4_foe_battle(accepted_seed, STARTERS["legs"], tier)
			var replayed := {}
			if replay != null and _to(replay, "scarecrow"):
				replayed = replay.use_part(STARTERS["legs"], 4)
			_check(not replayed.is_empty() and replayed == accepted_cast
				and replay.state_snapshot() == accepted_snapshot
				and replay.rng_state() == accepted_rng,
				"AC2: Crow Dive tier %d replays the same receipt, snapshot and RNG" % tier)


## AC2, the task goal: the real three-foe S2 preview with only the already-present Moth Scribe
## moved to occupied foe rank 4 (its old rank 3 left vacant). On Scarecrow's real scheduled
## turn Crow Flock is selected at rank 4 and resolves one genuine receipt for each living foe
## at ranks 1, 2 and 4. Every landed tier-II hit carries native Weak 2 and Mark 2 in the
## receipt and in the foe's battle state; the same seed and action replay to an identical
## receipt, snapshot and RNG position.
func _test_rank4_crow_flock() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var ability := StitchedParts.ability_at_tier(cat["by_id"][ALTERNATES["head"]], 2)
	var setup := _rank4_foe_battle(501500, ALTERNATES["head"], 2)
	_check(setup != null, "AC2: genuine occupied-rank-4 Crow Flock battle builds")
	if setup != null:
		var heroes: Array = setup.get_heroes()
		var foes: Array = setup.get_foes()
		_check(heroes.size() == 4 and foes.size() == 3,
			"AC2: occupied-rank-4 witness keeps four real heroes and the three S2 foes")
		var scarecrow := setup.get_unit("scarecrow")
		_check(int(scarecrow.get("rank", -1)) == 2
			and str(scarecrow.get("parts", {}).get("head", {}).get("id", "")) == ALTERNATES["head"],
			"AC2: Scarecrow keeps his real preview rank wearing Crow Flock")
		_check(int(setup.get_unit("moth_scribe")["rank"]) == 4
			and int(setup.get_unit("fray_scavenger")["rank"]) == 1
			and int(setup.get_unit("scissor_crab")["rank"]) == 2,
			"AC2: only the existing Moth Scribe moves to occupied foe rank 4")
		_check(foes.all(func(foe): return int(foe["rank"]) != 3),
			"AC2: the Moth Scribe's former enemy rank 3 stays vacant")
		for id in ENEMY_IDS:
			_check(not setup.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
	var witnessed := false
	for seed_value in range(501500, 501580):
		var b := _rank4_foe_battle(seed_value, ALTERNATES["head"], 2)
		if b == null or not _to(b, "scarecrow"):
			continue
		if str(b.get_unit("scarecrow")["parts"]["head"]["id"]) != ALTERNATES["head"]:
			continue
		var before := b.state_snapshot()
		var cast := b.use_part(ALTERNATES["head"], 4)
		if not bool(cast.get("ok", false)):
			continue
		var receipts: Array = cast.get("results", [])
		if receipts.size() != 3:
			continue
		var targets: Dictionary = {}
		var ranks: Dictionary = {}
		var sides_ok := true
		var landed := 0
		var status_hits := 0
		for receipt in receipts:
			var target := str(receipt["target"])
			targets[target] = true
			ranks[int(receipt.get("target_rank", 0))] = target
			sides_ok = sides_ok and str(receipt.get("target_side", "")) == "foe"
			if not bool(receipt.get("hit", false)):
				continue
			landed += 1
			var statuses: Array = receipt.get("statuses", [])
			var state_statuses: Dictionary = b.get_unit(target)["statuses"]
			if _status_amount(statuses, "weak") == 2 and _status_amount(statuses, "mark") == 2 \
				and int(state_statuses.get("weak", 0)) > 0 \
				and int(state_statuses.get("mark", 0)) > 0:
				status_hits += 1
		if not sides_ok or landed != 3 or status_hits != landed:
			continue
		if targets.size() != 3 or not targets.has("fray_scavenger") \
			or not targets.has("scissor_crab") or not targets.has("moth_scribe"):
			continue
		if ranks.size() != 3 or not ranks.has(1) or not ranks.has(2) or not ranks.has(4) \
			or ranks.has(3):
			continue
		if str(ranks[1]) != "fray_scavenger" or str(ranks[2]) != "scissor_crab" \
			or str(ranks[4]) != "moth_scribe":
			continue
		witnessed = true
		var after := b.state_snapshot()
		_check(str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "scarecrow"
			and str(cast.get("part", "")) == ALTERNATES["head"]
			and str(cast.get("ability", "")) == str(ability["id"]),
			"AC2: Crow Flock runs as the equipped Scarecrow head at target rank 4 (seed %d)"
				% seed_value)
		_check(int(b.get_unit("scarecrow")["rank"]) == 2,
			"AC2: the acting Scarecrow keeps his real preview rank 2 (seed %d)" % seed_value)
		_check(receipts.size() == 3 and targets.size() == 3 and ranks.size() == 3
			and ranks.has(1) and ranks.has(2) and ranks.has(4) and not ranks.has(3),
			"AC2: one distinct foe receipt each at enemy ranks 1, 2 and 4, never rank 3 (seed %d)"
				% seed_value)
		_check(landed == 3 and status_hits == landed,
			"AC2: all three landed tier-II hits carry Weak 2 and Mark 2 in receipt and state (seed %d)"
				% seed_value)
		var advanced := int(after["round"]) > int(before["round"]) \
			or (int(after["round"]) == int(before["round"]) \
				and int(after["turn_index"]) > int(before["turn_index"]))
		_check(advanced and after != before,
			"AC2: the cast spends Scarecrow's genuine turn and changes real battle state (seed %d)"
				% seed_value)
		var replay := _rank4_foe_battle(seed_value, ALTERNATES["head"], 2)
		if replay == null or not _to(replay, "scarecrow"):
			_check(false, "AC2: same-seed occupied-rank-4 replay reached Scarecrow's turn (seed %d)"
				% seed_value)
		else:
			var replayed := replay.use_part(ALTERNATES["head"], 4)
			_check(replayed == cast and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"AC2: same-seed occupied-rank-4 Crow Flock replays receipt, snapshot and RNG (seed %d)"
					% seed_value)
		break
	_check(witnessed,
		"AC2: a real seeded rank-4 Crow Flock Weakens and Marks every living foe at ranks 1, 2 and 4")


## AC2/AC3: genuine 4v3 Crow Flock tier-I cast, including a miss, followed by the
## living Fray Scavenger's real Sack Swing. Two identical seeds are advanced through
## the same turns; only Weak is erased in the control after its start-of-turn tick.
## Return nothing unless the cast, landed attack and subsequent expiry all occurred.
func _crow_flock_tier1_reply_trial(seed_value: int) -> Dictionary:
	var weakened := _rank4_foe_battle(seed_value, ALTERNATES["head"], 1)
	var control := _rank4_foe_battle(seed_value, ALTERNATES["head"], 1)
	if weakened == null or control == null \
		or not _to(weakened, "scarecrow") or not _to(control, "scarecrow"):
		return {}
	if weakened.state_snapshot() != control.state_snapshot() \
		or weakened.current_actor_id() != "scarecrow":
		return {}
	var before := weakened.state_snapshot()
	var original_foes: Dictionary = {}
	var expected_ranks := {"fray_scavenger": 1, "scissor_crab": 2, "moth_scribe": 4}
	if weakened.get_heroes().size() != 4 or weakened.get_foes().size() != 3 \
		or int(weakened.get_unit("scarecrow").get("rank", -1)) != 2:
		return {}
	for id in ENEMY_IDS:
		var foe := weakened.get_unit(id)
		if foe.is_empty() or int(foe.get("hp", 0)) <= 0 \
			or int(foe.get("rank", 0)) != int(expected_ranks[id]) \
			or int(foe["statuses"].get("weak", 0)) != 0 \
			or int(foe["statuses"].get("mark", 0)) != 0:
			return {}
		original_foes[id] = foe
	var cast := weakened.use_part(ALTERNATES["head"], 4)
	var control_cast := control.use_part(ALTERNATES["head"], 4)
	var after_cast := weakened.state_snapshot()
	if not bool(cast.get("ok", false)) or cast != control_cast \
		or after_cast != control.state_snapshot() \
		or weakened.rng_state() != control.rng_state() \
		or cast.get("results", []).size() != 3 \
		or str(cast.get("actor", "")) != "scarecrow" \
		or str(cast.get("part", "")) != ALTERNATES["head"] \
		or str(cast.get("ability", "")) != "scarecrow_head_crow_flock_move" \
		or before == after_cast:
		return {}
	var received: Dictionary = {}
	var landed_count := 0
	var missed_count := 0
	var scavenger_hit := false
	for receipt in cast["results"]:
		var id := str(receipt.get("target", ""))
		if not original_foes.has(id) or received.has(id) \
			or str(receipt.get("target_side", "")) != "foe" \
			or int(receipt.get("target_rank", 0)) != int(expected_ranks[id]) \
			or int(receipt.get("damage", -1)) != 0 \
			or int(receipt.get("target_hp", -1)) != int(original_foes[id]["hp"]) \
			or int(weakened.get_unit(id)["hp"]) != int(original_foes[id]["hp"]):
			return {}
		received[id] = true
		var statuses: Array = receipt.get("statuses", [])
		var foe_now: Dictionary = weakened.get_unit(id)
		if bool(receipt.get("hit", false)):
			landed_count += 1
			if _status_amount(statuses, "weak") != 2 \
				or _status_amount(statuses, "mark") != 2 \
				or int(foe_now["statuses"].get("weak", 0)) < 1 \
				or int(foe_now["statuses"].get("weak", 0)) > 2:
				return {}
			if id == "fray_scavenger":
				scavenger_hit = true
		else:
			missed_count += 1
			if not statuses.is_empty() or int(foe_now["statuses"].get("weak", 0)) != 0 \
				or int(foe_now["statuses"].get("mark", 0)) != 0:
				return {}
	if received.size() != 3 or landed_count < 1 or missed_count < 1 \
		or not scavenger_hit:
		return {}
	if not _to(weakened, "fray_scavenger") or not _to(control, "fray_scavenger"):
		return {}
	var attacking_foe := weakened.get_unit("fray_scavenger")
	var hero_before := weakened.get_unit("scarecrow")
	if int(attacking_foe.get("hp", 0)) <= 0 \
		or int(attacking_foe["statuses"].get("weak", 0)) != 1 \
		or int(hero_before.get("hp", 0)) <= 0 \
		or hero_before != control.get_unit("scarecrow") \
		or weakened.state_snapshot() != control.state_snapshot():
		return {}
	var rng_before := weakened.rng_state()
	var expected_control := weakened.state_snapshot()
	for unit in expected_control["units"]:
		if str(unit["id"]) == "fray_scavenger":
			unit["statuses"].erase("weak")
	# Only this status is cleared, after the genuine start-of-turn countdown.
	control._units["fray_scavenger"]["statuses"].erase("weak")
	if control.state_snapshot() != expected_control \
		or rng_before != control.rng_state():
		return {}
	var reduced := weakened.use_foe_ability("sack_swing", 2)
	var normal := control.use_foe_ability("sack_swing", 2)
	if not bool(reduced.get("ok", false)) or not bool(normal.get("ok", false)) \
		or str(reduced.get("actor", "")) != "fray_scavenger" \
		or str(normal.get("actor", "")) != "fray_scavenger" \
		or reduced.get("results", []).size() != 1 or normal.get("results", []).size() != 1:
		return {}
	var weak_hit: Dictionary = reduced["results"][0]
	var plain_hit: Dictionary = normal["results"][0]
	if not bool(weak_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)) \
		or str(weak_hit.get("target", "")) != "scarecrow" \
		or str(plain_hit.get("target", "")) != "scarecrow" \
		or int(weak_hit.get("roll", -1)) != int(plain_hit.get("roll", -2)) \
		or bool(weak_hit.get("crit", false)) != bool(plain_hit.get("crit", false)) \
		or int(weak_hit.get("damage", 0)) <= 0 \
		or int(weak_hit["damage"]) >= int(plain_hit.get("damage", 0)) \
		or int(weak_hit.get("target_hp", -1)) != int(hero_before["hp"]) - int(weak_hit["damage"]) \
		or int(plain_hit.get("target_hp", -1)) != int(hero_before["hp"]) - int(plain_hit["damage"]) \
		or int(weakened.get_unit("scarecrow")["hp"]) != int(weak_hit["target_hp"]) \
		or int(control.get_unit("scarecrow")["hp"]) != int(plain_hit["target_hp"]) \
		or weakened.rng_state() != control.rng_state():
		return {}
	var after_weak_reply := weakened.state_snapshot()
	var after_plain_reply := control.state_snapshot()
	if not _to(weakened, "fray_scavenger") or not _to(control, "fray_scavenger"):
		return {}
	if int(weakened.get_unit("fray_scavenger")["statuses"].get("weak", 0)) != 0 \
		or weakened.get_unit("fray_scavenger")["statuses"].has("weak") \
		or int(weakened.get_unit("fray_scavenger").get("hp", 0)) <= 0 \
		or weakened.rng_state() != control.rng_state():
		return {}
	return {
		"seed": seed_value, "cast": cast, "cast_state": after_cast,
		"cast_rng": int(after_cast["rng_state"]), "before_attack_weak": 1,
		"missed": missed_count, "landed": landed_count, "distinct": received.size(),
		"weak_reply": reduced, "plain_reply": normal,
		"weak_damage": int(weak_hit["damage"]), "normal_damage": int(plain_hit["damage"]),
		"hero_hp_before": int(hero_before["hp"]),
		"weak_hp_after": int(weak_hit["target_hp"]),
		"plain_hp_after": int(plain_hit["target_hp"]),
		"after_weak_reply": after_weak_reply, "after_plain_reply": after_plain_reply,
		"expired": int(weakened.get_unit("fray_scavenger")["statuses"].get("weak", 0)),
		"after_expiry": weakened.state_snapshot(), "after_expiry_rng": weakened.rng_state(),
		"control_after_expiry": control.state_snapshot(), "control_rng": control.rng_state(),
	}


## AC2: two genuine S2 4v3 turns, with the same Flock and real foe reply.
## The twins diverge only when the control's Mark is erased after the rank-one
## foe's first natural countdown; no status rules or hit rolls are stubbed.
func _crow_flock_mark_dive_trial(seed_value: int) -> Dictionary:
	var marked := _rank4_foe_battle(seed_value, ALTERNATES["head"], 1)
	var cleared := _rank4_foe_battle(seed_value, ALTERNATES["head"], 1)
	if marked == null or cleared == null \
		or not _to(marked, "scarecrow") or not _to(cleared, "scarecrow"):
		return {}
	if marked.state_snapshot() != cleared.state_snapshot() \
		or marked.get_heroes().size() != 4 or marked.get_foes().size() != 3 \
		or marked.current_actor_id() != "scarecrow" \
		or str(marked.get_unit("scarecrow")["parts"]["head"]["id"]) != ALTERNATES["head"] \
		or str(marked.get_unit("scarecrow")["parts"]["legs"]["id"]) != STARTERS["legs"]:
		return {}
	var start := marked.state_snapshot()
	var flock := marked.use_part(ALTERNATES["head"], 1)
	var twin_flock := cleared.use_part(ALTERNATES["head"], 1)
	if not bool(flock.get("ok", false)) or flock != twin_flock \
		or flock.get("results", []).size() != 3 \
		or marked.state_snapshot() != cleared.state_snapshot() \
		or marked.rng_state() != cleared.rng_state() \
		or marked.state_snapshot() == start:
		return {}
	var rank_one_hit: Dictionary = {}
	var target_ids: Dictionary = {}
	for receipt in flock["results"]:
		var target_id := str(receipt.get("target", ""))
		if target_ids.has(target_id) or not target_id in ENEMY_IDS:
			return {}
		target_ids[target_id] = true
		if target_id == "fray_scavenger":
			rank_one_hit = receipt
	if target_ids.size() != 3 or rank_one_hit.is_empty() \
		or not bool(rank_one_hit.get("hit", false)) \
		or int(rank_one_hit.get("target_rank", 0)) != 1 \
		or _status_amount(rank_one_hit.get("statuses", []), "mark") != 2 \
		or _status_amount(rank_one_hit.get("statuses", []), "weak") != 2 \
		or int(marked.get_unit("fray_scavenger")["statuses"].get("mark", 0)) != 2:
		return {}
	if not _to(marked, "fray_scavenger") or not _to(cleared, "fray_scavenger"):
		return {}
	var foe_first: Dictionary = marked.get_unit("fray_scavenger")
	if int(foe_first.get("hp", 0)) <= 0 \
		or int(foe_first["statuses"].get("mark", 0)) != 1 \
		or int(foe_first["statuses"].get("weak", 0)) != 1 \
		or marked.state_snapshot() != cleared.state_snapshot() \
		or marked.rng_state() != cleared.rng_state():
		return {}
	var expected_control := marked.state_snapshot()
	for unit in expected_control["units"]:
		if str(unit["id"]) == "fray_scavenger":
			unit["statuses"].erase("mark")
	# The only intervention: remove Mark after the first genuine foe-turn tick.
	cleared._units["fray_scavenger"]["statuses"].erase("mark")
	if cleared.state_snapshot() != expected_control \
		or marked.rng_state() != cleared.rng_state():
		return {}
	var reply := marked.use_foe_ability("sack_swing", 2)
	var twin_reply := cleared.use_foe_ability("sack_swing", 2)
	if not bool(reply.get("ok", false)) or reply != twin_reply \
		or str(reply.get("actor", "")) != "fray_scavenger" \
		or reply.get("results", []).size() != 1 \
		or marked.rng_state() != cleared.rng_state():
		return {}
	if not _to(marked, "scarecrow") or not _to(cleared, "scarecrow"):
		return {}
	var foe_before := marked.get_unit("fray_scavenger")
	var twin_before := cleared.get_unit("fray_scavenger")
	var hero_before := marked.get_unit("scarecrow")
	if foe_before.is_empty() or twin_before.is_empty() or hero_before.is_empty() \
		or int(foe_before.get("hp", 0)) <= 10 \
		or int(hero_before.get("hp", 0)) <= 0 \
		or int(foe_before["statuses"].get("mark", 0)) != 1 \
		or int(twin_before["statuses"].get("mark", 0)) != 0 \
		or int(foe_before["hp"]) != int(twin_before["hp"]) \
		or marked.rng_state() != cleared.rng_state():
		return {}
	var dive := marked.use_part(STARTERS["legs"], 1)
	var twin_dive := cleared.use_part(STARTERS["legs"], 1)
	if not bool(dive.get("ok", false)) or not bool(twin_dive.get("ok", false)) \
		or str(dive.get("actor", "")) != "scarecrow" \
		or str(dive.get("ability", "")) != "scarecrow_legs_crow_dive_move" \
		or dive.get("results", []).size() != 1 or twin_dive.get("results", []).size() != 1:
		return {}
	var hit: Dictionary = dive["results"][0]
	var plain_hit: Dictionary = twin_dive["results"][0]
	var bonus := int(StitchedParts.ability_at_tier(_catalog()["by_id"][STARTERS["legs"]], 1)["mark_damage"])
	if not bool(hit.get("hit", false)) or not bool(plain_hit.get("hit", false)) \
		or str(hit.get("target", "")) != "fray_scavenger" \
		or str(plain_hit.get("target", "")) != "fray_scavenger" \
		or int(hit.get("roll", -1)) != int(plain_hit.get("roll", -2)) \
		or bool(hit.get("crit", false)) != bool(plain_hit.get("crit", false)) \
		or int(hit.get("damage", 0)) != int(plain_hit.get("damage", 0)) + bonus \
		or bonus <= 0 \
		or int(hit.get("target_hp", -1)) != int(foe_before["hp"]) - int(hit["damage"]) \
		or int(plain_hit.get("target_hp", -1)) != int(twin_before["hp"]) - int(plain_hit["damage"]) \
		or int(marked.get_unit("fray_scavenger")["hp"]) != int(hit["target_hp"]) \
		or int(cleared.get_unit("fray_scavenger")["hp"]) != int(plain_hit["target_hp"]) \
		or marked.rng_state() != cleared.rng_state():
		return {}
	var dive_rng := marked.rng_state()
	if not _to(marked, "fray_scavenger") or not _to(cleared, "fray_scavenger"):
		return {}
	var expired_foe := marked.get_unit("fray_scavenger")
	if expired_foe.is_empty() or int(expired_foe.get("hp", 0)) <= 0 \
		or expired_foe["statuses"].has("mark") \
		or int(expired_foe["statuses"].get("mark", 0)) != 0 \
		or marked.rng_state() != cleared.rng_state():
		return {}
	return {
		"seed": seed_value, "flock": flock, "reply": reply,
		"first_turn_mark": 1, "bonus": bonus,
		"dive": dive, "control_dive": twin_dive,
		"before_hp": int(foe_before["hp"]),
		"marked_hp": int(hit["target_hp"]), "plain_hp": int(plain_hit["target_hp"]),
		"marked_damage": int(hit["damage"]), "plain_damage": int(plain_hit["damage"]),
		"dive_rng": dive_rng, "expiry_rng": marked.rng_state(),
		"expired_mark": int(expired_foe["statuses"].get("mark", 0)),
	}


func _test_crow_flock_mark_survives_for_dive() -> void:
	var witness: Dictionary = {}
	for seed_value in range(501500, 501900):
		witness = _crow_flock_mark_dive_trial(seed_value)
		if not witness.is_empty():
			break
	_check(not witness.is_empty(),
		"AC2: bounded fixed-seed authentic 4v3 Flock survives rank-one foe turn for legal Crow Dive")
	if witness.is_empty():
		return
	_check(int(witness["first_turn_mark"]) == 1 and int(witness["expired_mark"]) == 0,
		"AC2: Mark 2 ticks to 1 on first foe start and naturally expires at second without reapplication")
	_check(int(witness["marked_damage"]) == int(witness["plain_damage"]) + int(witness["bonus"]) \
		and int(witness["marked_hp"]) == int(witness["before_hp"]) - int(witness["marked_damage"]) \
		and int(witness["plain_hp"]) == int(witness["before_hp"]) - int(witness["plain_damage"]),
		"AC2: same hit/crit RNG yields exactly Crow Dive mark_damage extra real HP loss")
	var replay := _crow_flock_mark_dive_trial(int(witness["seed"]))
	_check(not replay.is_empty() and replay == witness,
		"AC3: equal-seed real-turn Flock, foe attack, Dive, countdown and RNG all replay")


func _test_crow_flock_tier1_weak_reply() -> void:
	var witness: Dictionary = {}
	for seed_value in range(501500, 501900):
		witness = _crow_flock_tier1_reply_trial(seed_value)
		if not witness.is_empty():
			break
	_check(not witness.is_empty(),
		"AC2/AC3: bounded fixed-seed tier-I Crow Flock lands on a living foe, misses another, and weakens its next real strike")
	if witness.is_empty():
		return
	_check(int(witness["distinct"]) == 3 and int(witness["landed"]) > 0 \
		and int(witness["missed"]) > 0,
		"AC2/AC3: all three authentic living foes get one receipt, with both landed and missed targets")
	_check(int(witness["before_attack_weak"]) == 1 and int(witness["expired"]) == 0,
		"AC2: Weak 2 counts to 1 at the foe's next turn, then expires at the following turn without reapplication")
	_check(int(witness["weak_damage"]) > 0 and int(witness["weak_damage"]) < int(witness["normal_damage"]) \
		and int(witness["weak_hp_after"]) == int(witness["hero_hp_before"]) - int(witness["weak_damage"]) \
		and int(witness["plain_hp_after"]) == int(witness["hero_hp_before"]) - int(witness["normal_damage"]),
		"AC2: equal-seed landed Sack Swing uses Weak for less actual HP damage than the sole-Weak-cleared control")
	var replay := _crow_flock_tier1_reply_trial(int(witness["seed"]))
	_check(not replay.is_empty() and replay == witness,
		"AC3: repeated seed and identical actions reproduce tier-I casts, misses, foe replies, state and RNG exactly")


## AC2/AC3: the shipped 4v3 preview with only the existing Moth Scribe moved to
## rank 4. Tier-III Sack Glare lands Weak 3/Mark 3; invalid launches, empty ranks,
## a seeded miss, turn spending and identical-seed replay remain covered.
func _test_sack_glare_rank4() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var ability := StitchedParts.ability_at_tier(cat["by_id"][STARTERS["head"]], 3)
	var setup := _rank4_foe_battle(501700, STARTERS["head"], 3)
	_check(setup != null, "AC2: genuine occupied-rank-4 Sack Glare battle builds")
	if setup != null:
		var heroes: Array = setup.get_heroes()
		var foes: Array = setup.get_foes()
		_check(heroes.size() == 4 and foes.size() == 3,
			"AC2: occupied-rank-4 Sack Glare keeps four real heroes and the three S2 foes")
		var scarecrow := setup.get_unit("scarecrow")
		_check(int(scarecrow.get("rank", -1)) == 2
			and str(scarecrow.get("parts", {}).get("head", {}).get("id", "")) == STARTERS["head"]
			and int(scarecrow.get("parts", {}).get("head", {}).get("tier", 0)) == 3,
			"AC2: Scarecrow keeps his real rank 2 wearing tier-III Sack Glare")
		_check(int(setup.get_unit("moth_scribe")["rank"]) == 4
			and int(setup.get_unit("fray_scavenger")["rank"]) == 1
			and int(setup.get_unit("scissor_crab")["rank"]) == 2,
			"AC2: only the existing Moth Scribe moves to occupied enemy rank 4")
		_check(foes.all(func(foe): return int(foe["rank"]) != 3),
			"AC2: the Moth Scribe's former enemy rank 3 stays vacant")
		for id in ENEMY_IDS:
			_check(not setup.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
	var b := _rank4_foe_battle(501700, STARTERS["head"], 3)
	if b == null or not _to(b, "scarecrow"):
		_check(false, "AC2: tier-III Sack Glare rank-4 witness receives Scarecrow's actual turn")
	else:
		var before := b.state_snapshot()
		var scribe_before := b.get_unit("moth_scribe")
		var scavenger_before := b.get_unit("fray_scavenger")
		var crab_before := b.get_unit("scissor_crab")
		var cast := b.use_part(STARTERS["head"], 4)
		var after := b.state_snapshot()
		var receipts: Array = cast.get("results", [])
		_check(bool(cast.get("ok", false)) and str(cast.get("action", "")) == "ability"
			and str(cast.get("actor", "")) == "scarecrow"
			and str(cast.get("part", "")) == STARTERS["head"]
			and str(cast.get("ability", "")) == str(ability["id"]),
			"AC2: tier-III Sack Glare runs as the equipped Scarecrow head at target rank 4")
		_check(receipts.size() == 1 and str(cast.get("target", "")) == "moth_scribe"
			and str(receipts[0].get("target", "")) == "moth_scribe"
			and str(receipts[0].get("target_side", "")) == "foe"
			and int(receipts[0].get("target_rank", 0)) == 4,
			"AC2: the rank-4 cast resolves exactly one receipt on the real Moth Scribe")
		if receipts.size() == 1:
			var hit: Dictionary = receipts[0]
			_check(bool(hit.get("hit", false)),
				"AC2: the chosen seed lands the tier-III rank-4 Sack Glare (seed 501700)")
			_check(int(hit.get("damage", -1)) == 0
				and int(hit.get("target_hp", -1)) == int(scribe_before.get("hp", 0))
				and int(b.get_unit("moth_scribe")["hp"]) == int(scribe_before.get("hp", 0)),
				"AC2: the pure debuff deals no direct damage to the Moth Scribe")
			_check(_status_amount(hit.get("statuses", []), "weak") == 3
				and _status_amount(hit.get("statuses", []), "mark") == 3,
				"AC2: the hit receipt carries the full authored Weak 3 and Mark 3")
			# The struck foe may start its own turn before control returns, so a countdown-ticked
			# 2 is as legitimate as an untouched 3; only the receipt must show the authored 3.
			var scribe_after := b.get_unit("moth_scribe")
			var weak_state := int(scribe_after["statuses"].get("weak", 0))
			var mark_state := int(scribe_after["statuses"].get("mark", 0))
			_check(weak_state >= 2 and weak_state <= 3 and mark_state >= 2 and mark_state <= 3,
				"AC2: the Moth Scribe keeps its landed Weak and Mark in real battle state")
			_check(b.get_unit("fray_scavenger") == scavenger_before
				and b.get_unit("scissor_crab") == crab_before,
				"AC2: the other two foes stay completely unchanged")
			_check(int(after["round"]) != int(before["round"])
				or int(after["turn_index"]) != int(before["turn_index"]),
				"AC2: the legal rank-4 cast spends Scarecrow's genuine turn")
			var replay := _rank4_foe_battle(501700, STARTERS["head"], 3)
			var replayed := {}
			if replay != null and _to(replay, "scarecrow"):
				replayed = replay.use_part(STARTERS["head"], 4)
			_check(not replayed.is_empty() and replayed == cast
				and replay.state_snapshot() == after
				and replay.rng_state() == int(after["rng_state"]),
				"AC2: the same seed and action replay receipt, snapshot and RNG exactly")
	# AC3: the unchanged front-three tiers refuse the now-occupied enemy rank 4, and the
	# tier-III mask still refuses a vacant one, without spending Scarecrow's turn.
	for tier in [1, 2]:
		var front := _rank4_foe_battle(501800, STARTERS["head"], tier)
		_check(front != null, "AC3: genuine occupied-rank-4 tier-%d Sack Glare battle builds" % tier)
		if front == null:
			continue
		_check(int(front.get_unit("moth_scribe")["rank"]) == 4
			and int(front.get_unit("scarecrow")["rank"]) == 2,
			"AC3: tier-%d witness keeps a real rank-4 foe and a rank-2 Scarecrow" % tier)
		if _to(front, "scarecrow"):
			_reject_without_spend(front, STARTERS["head"], 4,
				"Sack Glare tier %d rejects the occupied enemy rank 4" % tier)
		else:
			_check(false, "AC3: Sack Glare tier-%d rejection receives a real Scarecrow turn" % tier)
	var empty := _battle(STARTERS["head"], 3, 501840)
	_check(empty != null, "AC3: unaltered three-foe preview builds for tier-III Sack Glare")
	if empty != null:
		_check(empty.get_foes().all(func(foe): return int(foe["rank"]) != 4),
			"AC3: unaltered preview leaves enemy rank 4 genuinely vacant")
		if _to(empty, "scarecrow"):
			_reject_without_spend(empty, STARTERS["head"], 4,
				"Sack Glare tier III rejects the vacant enemy rank 4")
		else:
			_check(false, "AC3: vacant-rank-4 rejection receives a real Scarecrow turn")
	var vanguard := _rank4_battle(STARTERS["head"], 3, 501880)
	_check(vanguard != null, "AC3: genuine rank-4 Scarecrow battle builds for Sack Glare")
	if vanguard != null:
		_check(int(vanguard.get_unit("scarecrow")["rank"]) == 4,
			"AC3: the rank-4 launch witness really stands in hero rank 4")
		if _to(vanguard, "scarecrow"):
			_reject_without_spend(vanguard, STARTERS["head"], 1,
				"Sack Glare tier III cannot launch from hero rank 4")
		else:
			_check(false, "AC3: rank-4 launch gate receives an actual scheduled turn")
	# AC3: a seeded miss at the same tier-III rank-4 cast applies neither Weak nor Mark.
	var miss := _rank4_foe_battle(501910, STARTERS["head"], 3)
	if miss == null or not _to(miss, "scarecrow"):
		_check(false, "AC3: seeded Sack Glare miss witness receives a real Scarecrow turn")
	else:
		var miss_before := miss.state_snapshot()
		var miss_scribe := miss.get_unit("moth_scribe")
		var miss_cast := miss.use_part(STARTERS["head"], 4)
		var miss_after := miss.state_snapshot()
		var miss_receipts: Array = miss_cast.get("results", [])
		_check(bool(miss_cast.get("ok", false)) and miss_receipts.size() == 1
			and str(miss_receipts[0].get("target", "")) == "moth_scribe"
			and int(miss_receipts[0].get("target_rank", 0)) == 4,
			"AC3: the seeded rank-4 Sack Glare still resolves one Moth Scribe receipt")
		if miss_receipts.size() == 1:
			var miss_hit: Dictionary = miss_receipts[0]
			_check(not bool(miss_hit.get("hit", false)),
				"AC3: the chosen seed genuinely misses (seed 501910)")
			_check(miss_hit.get("statuses", []).is_empty()
				and miss.get_unit("moth_scribe")["statuses"].get("weak", 0) == 0
				and miss.get_unit("moth_scribe")["statuses"].get("mark", 0) == 0,
				"AC3: a seeded miss applies neither Weak nor Mark in receipt or state")
			_check(int(miss_hit.get("damage", -1)) == 0
				and int(miss.get_unit("moth_scribe")["hp"]) == int(miss_scribe.get("hp", 0)),
				"AC3: a seeded miss deals no damage to the Moth Scribe")
			_check(int(miss_after["round"]) != int(miss_before["round"])
				or int(miss_after["turn_index"]) != int(miss_before["turn_index"]),
				"AC3: the legal but missing cast still spends Scarecrow's turn")


## AC1, the task goal: only the authored stitch tier-III override widens the alternate arms
## crow sweep to the rear enemy rank 4. Tiers I and II keep enemy ranks 1-3, and launch, pose,
## accuracy, crit, self_move and the damage/Weak ladder stay exactly as authored.
func _test_harvest_fright_rank4_data() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var part: Dictionary = cat["by_id"][ALTERNATES["arms"]]
	var base: Dictionary = part["ability"]
	_check(str(part["name"]) == "Harvest Fright" and str(part["slot"]) == "arms"
		and str(part["owner"]) == "scarecrow" and part["stat"] == {"dmg": 2},
		"AC1: Harvest Fright keeps its arms slot, owner and dmg +2 stat")
	_check(str(base["id"]) == "scarecrow_arms_harvest_fright_move"
		and str(base["name"]) == "Harvest Fright" and str(base["kind"]) == "ranged"
		and str(base["target_side"]) == "enemy" and bool(base["multi"])
		and int(base["acc"]) == 88 and base["dmg"] == [2, 4] and int(base["crit"]) == 0
		and base["effects"] == {"weak": 2} and int(base["self_move"]) == 0
		and str(base["move"]) == "attack2",
		"AC1: Harvest Fright keeps its multi enemy ranged ability, ACC and attack2 pose")
	var front_mask := StitchedParts.rank_mask([1, 2, 3])
	_check(front_mask != StitchedParts.ALL_RANKS_MASK,
		"AC1: enemy ranks 1-3 form a mask that excludes rank 4")
	_check(base["target"] == [1, 2, 3] and int(base["target_mask"]) == front_mask
		and not StitchedParts.ranks_allowed(int(base["target_mask"]), 4),
		"AC1: Harvest Fright base target stays enemy ranks 1-3")
	var expected_dmg := {1: [2, 4], 2: [3, 5], 3: [4, 7]}
	var expected_weak := {1: 2, 2: 3, 3: 4}
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			"AC1: Harvest Fright tier %d resolves as a validated ability" % tier)
		_check(ability["launch"] == [1, 2, 3] and int(ability["launch_mask"]) == front_mask
			and not StitchedParts.ranks_allowed(int(ability["launch_mask"]), 4),
			"AC1: Harvest Fright tier %d still launches from hero ranks 1-3" % tier)
		_check(ability["dmg"] == expected_dmg[tier]
			and ability["effects"] == {"weak": expected_weak[tier]},
			"AC1: Harvest Fright tier %d keeps its authored damage and Weak" % tier)
		_check(str(ability["target_side"]) == "enemy" and bool(ability["multi"])
			and str(ability["move"]) == "attack2" and int(ability["acc"]) == 88
			and int(ability["crit"]) == 0 and int(ability["self_move"]) == 0,
			"AC1: Harvest Fright tier %d keeps its multi enemy shape, ACC, crit and pose" % tier)
		var expected_ranks: Array = [1, 2, 3] if tier < 3 else [1, 2, 3, 4]
		var expected_mask := StitchedParts.rank_mask(expected_ranks)
		_check(ability["target"] == expected_ranks
			and int(ability["target_mask"]) == expected_mask
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 1)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 2)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 3)
			and StitchedParts.ranks_allowed(int(ability["target_mask"]), 4) == (tier == 3)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 0)
			and not StitchedParts.ranks_allowed(int(ability["target_mask"]), 5),
			"AC1: Harvest Fright tier %d targets %s and never rank 0 or 5"
				% [tier, str(expected_ranks)])
		if tier == 3:
			_check(int(ability["target_mask"]) == StitchedParts.ALL_RANKS_MASK,
				"AC1: tier-III Harvest Fright uses the full enemy rank mask")
	# The loaded catalog normalises each tier into a full merged ability, so the authored
	# override shape is checked against the raw JSON: only tier III gains a target list.
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var raw_part: Dictionary = {}
	if raw is Dictionary and raw.get("parts") is Array:
		for entry in raw["parts"]:
			if entry is Dictionary and str(entry.get("id", "")) == ALTERNATES["arms"]:
				raw_part = entry
	_check(not raw_part.is_empty(), "AC1: the raw Harvest Fright JSON entry is readable")
	if not raw_part.is_empty():
		var raw_tiers: Dictionary = raw_part.get("tiers", {})
		var raw_tier2: Dictionary = raw_tiers.get("2", {}).get("ability", {})
		var raw_tier3: Dictionary = raw_tiers.get("3", {}).get("ability", {})
		_check(_int_ranks(raw_part["ability"]["target"]) == [1, 2, 3],
			"AC1: the authored Harvest Fright base ability keeps enemy ranks 1-3")
		_check(not raw_tier2.has("target")
			and _int_ranks(raw_tier2.get("dmg")) == [3, 5]
			and _int_effects(raw_tier2.get("effects")) == {"weak": 3}
			and raw_tier2.keys().size() == 2,
			"AC1: the authored tier-II override only raises damage and Weak")
		_check(_int_ranks(raw_tier3.get("target")) == [1, 2, 3, 4]
			and _int_ranks(raw_tier3.get("dmg")) == [4, 7]
			and _int_effects(raw_tier3.get("effects")) == {"weak": 4}
			and raw_tier3.keys().size() == 3,
			"AC1: the authored tier-III override adds only the enemy rank 1-4 target list")
	_check(str(part["text"]) == HARVEST_FRIGHT_TEXT,
		"AC1: Harvest Fright text states its front-three reach and the tier-III rank-four reach")
	var text := str(part["text"]).to_lower()
	_check(text.contains("tier iii") and text.contains("rank 4")
		and text.contains("ranks 1-3") and text.contains("on hits"),
		"AC1: Harvest Fright text credits rank 4 only to tier III and Weak only to landed hits")


## AC2/AC3, the task goal: the real three-foe S2 preview with only the already-present Moth
## Scribe moved to occupied foe rank 4 (its old rank 3 left vacant). Scarecrow keeps his real
## rank-2 slot wearing the alternate arms. Tiers I and II cannot select rank 4 and their legal
## front cast leaves the rear Moth Scribe untouched; tier III aimed at rank 4 resolves one
## receipt for each living rank 1, 2 and 4 and, on a bounded seed, lands damaging Weak 4 on the
## Moth Scribe. Illegal ranks and a rank-4 launch fail closed without spending anything.
func _test_harvest_fright_rank4() -> void:
	var cat := _catalog()
	if not bool(cat.get("ok", false)):
		return
	var ability := StitchedParts.ability_at_tier(cat["by_id"][ALTERNATES["arms"]], 3)
	_check(bool(StitchedParts.validate_ability(ability).get("ok", false))
		and ability["target"] == [1, 2, 3, 4],
		"AC1: the equipped tier-III Harvest Fright reaches enemy rank 4")
	var setup := _rank4_foe_battle(501950, ALTERNATES["arms"], 3)
	_check(setup != null, "AC2: genuine occupied-rank-4 Harvest Fright battle builds")
	if setup != null:
		var heroes: Array = setup.get_heroes()
		var foes: Array = setup.get_foes()
		_check(heroes.size() == 4 and foes.size() == 3,
			"AC2: Harvest Fright witness keeps four real heroes and the three S2 foes")
		var scarecrow := setup.get_unit("scarecrow")
		_check(int(scarecrow.get("rank", -1)) == 2
			and str(scarecrow.get("parts", {}).get("arms", {}).get("id", "")) == ALTERNATES["arms"]
			and int(scarecrow.get("parts", {}).get("arms", {}).get("tier", 0)) == 3,
			"AC2: Scarecrow keeps his real rank 2 wearing tier-III Harvest Fright")
		_check(int(setup.get_unit("moth_scribe")["rank"]) == 4
			and int(setup.get_unit("fray_scavenger")["rank"]) == 1
			and int(setup.get_unit("scissor_crab")["rank"]) == 2,
			"AC2: only the existing Moth Scribe moves to occupied enemy rank 4")
		_check(foes.all(func(foe): return int(foe["rank"]) != 3),
			"AC2: the Moth Scribe's former enemy rank 3 stays vacant")
		for id in ENEMY_IDS:
			_check(not setup.get_unit(id).is_empty(), "AC2: actual shipped foe retained: " + id)
	# Tiers I and II keep the authored front-three reach: the occupied rear rank refuses with no
	# turn, state or RNG spend, and a legal rank-1 cast strikes only the living ranks 1 and 2.
	for tier in [1, 2]:
		var front := _rank4_foe_battle(501951 + tier, ALTERNATES["arms"], tier)
		_check(front != null, "AC3: genuine occupied-rank-4 tier-%d Harvest Fright builds" % tier)
		if front == null:
			continue
		_check(int(front.get_unit("moth_scribe")["rank"]) == 4
			and int(front.get_unit("scarecrow")["rank"]) == 2,
			"AC3: tier-%d witness keeps a real rank-4 foe and a rank-2 Scarecrow" % tier)
		if not _to(front, "scarecrow"):
			_check(false, "AC3: Harvest Fright tier-%d rejection receives a real Scarecrow turn" % tier)
			continue
		var rear_before := front.get_unit("moth_scribe").duplicate(true)
		_reject_without_spend(front, ALTERNATES["arms"], 4,
			"Harvest Fright tier %d rejects the occupied enemy rank 4" % tier)
		var before := front.state_snapshot()
		var cast := front.use_part(ALTERNATES["arms"], 1)
		var receipts: Array = cast.get("results", [])
		var ranks: Array = []
		for receipt in receipts:
			ranks.append(int(receipt.get("target_rank", 0)))
		_check(bool(cast.get("ok", false)) and receipts.size() == 2 and ranks == [1, 2],
			"AC3: tier-%d Harvest Fright aimed at rank 1 strikes only the real foes in ranks 1 and 2"
				% tier)
		_check(front.get_unit("moth_scribe")["hp"] == rear_before["hp"]
			and front.get_unit("moth_scribe")["statuses"] == rear_before["statuses"],
			"AC3: tier-%d Harvest Fright leaves the occupied rear foe untouched" % tier)
		var after := front.state_snapshot()
		_check(int(after["round"]) != int(before["round"])
			or int(after["turn_index"]) != int(before["turn_index"]),
			"AC3: the legal tier-%d front cast spends Scarecrow's genuine turn" % tier)
	# A real tier-III Scarecrow turn refuses out-of-range ranks 0 and 5 atomically, then the
	# accepted rank-4 cast ends the turn so every repeat is off turn.
	var near := _rank4_foe_battle(501959, ALTERNATES["arms"], 3)
	if near == null or not _to(near, "scarecrow"):
		_check(false, "AC3: tier-III Harvest Fright rejection witness receives a real turn")
	else:
		for bad_rank in [0, 5]:
			_reject_without_spend(near, ALTERNATES["arms"], bad_rank,
				"Harvest Fright rejects enemy rank %d" % bad_rank)
		var near_cast := near.use_part(ALTERNATES["arms"], 4)
		_check(bool(near_cast.get("ok", false)) and near_cast.get("results", []).size() == 3,
			"AC3: the accepted tier-III rank-4 aim still resolves its three living foes")
		_reject_without_spend(near, ALTERNATES["arms"], 4,
			"replayed Harvest Fright after the turn is spent")
	var witnessed := false
	var landed := false
	var witness_seed := -1
	var witness_cast: Dictionary = {}
	var witness_snapshot: Dictionary = {}
	var witness_rng := -1
	for seed_value in range(501960, 502060):
		var b := _rank4_foe_battle(seed_value, ALTERNATES["arms"], 3)
		if b == null or not _to(b, "scarecrow"):
			continue
		if str(b.get_unit("scarecrow")["parts"]["arms"]["id"]) != ALTERNATES["arms"]:
			continue
		var before := b.state_snapshot()
		var scribe_before := b.get_unit("moth_scribe")
		var cast := b.use_part(ALTERNATES["arms"], 4)
		var after := b.state_snapshot()
		var receipts: Array = cast.get("results", [])
		if not bool(cast.get("ok", false)) or receipts.size() != 3:
			continue
		var ranks: Array = []
		var targets: Dictionary = {}
		var sides_ok := true
		for receipt in receipts:
			ranks.append(int(receipt.get("target_rank", 0)))
			targets[str(receipt.get("target", ""))] = true
			sides_ok = sides_ok and str(receipt.get("target_side", "")) == "foe"
		if not sides_ok or ranks != [1, 2, 4] or targets.size() != 3 \
			or not targets.has("fray_scavenger") or not targets.has("scissor_crab") \
			or not targets.has("moth_scribe"):
			continue
		if not witnessed:
			witnessed = true
			_check(str(cast.get("action", "")) == "ability"
				and str(cast.get("actor", "")) == "scarecrow"
				and str(cast.get("part", "")) == ALTERNATES["arms"]
				and str(cast.get("ability", "")) == str(ability["id"]),
				"AC2: tier-III Harvest Fright runs as the equipped Scarecrow arms (seed %d)"
					% seed_value)
			_check(receipts.size() == 3 and ranks == [1, 2, 4]
				and b.get_foes().size() == 3
				and b.get_foes().all(func(foe): return int(foe["rank"]) != 3),
				"AC2: one distinct foe receipt each at enemy ranks 1, 2 and 4, never rank 3 (seed %d)"
					% seed_value)
			_check(int(after["round"]) != int(before["round"])
				or int(after["turn_index"]) != int(before["turn_index"]),
				"AC2: the legal rank-4 cast spends Scarecrow's genuine turn (seed %d)" % seed_value)
		for receipt in receipts:
			if str(receipt.get("target", "")) != "moth_scribe":
				continue
			if bool(receipt.get("hit", false)) and int(receipt.get("damage", 0)) > 0 \
				and _status_amount(receipt.get("statuses", []), "weak") == 4 \
				and int(b.get_unit("moth_scribe")["hp"]) < int(scribe_before["hp"]) \
				and int(b.get_unit("moth_scribe")["statuses"].get("weak", 0)) > 0:
				landed = true
				witness_seed = seed_value
				witness_cast = cast.duplicate(true)
				witness_snapshot = after
				witness_rng = b.rng_state()
		if witnessed and landed:
			break
	_check(witnessed,
		"AC2: a bounded real seed sweeps tier-III Harvest Fright across living ranks 1, 2 and 4")
	_check(landed,
		"AC2: a bounded real seed lands damaging Weak 4 on the rear Moth Scribe")
	if witness_seed >= 0:
		var replay := _rank4_foe_battle(witness_seed, ALTERNATES["arms"], 3)
		var replayed := {}
		if replay != null and _to(replay, "scarecrow"):
			replayed = replay.use_part(ALTERNATES["arms"], 4)
		_check(not replayed.is_empty() and replayed == witness_cast
			and replay.state_snapshot() == witness_snapshot
			and replay.rng_state() == witness_rng,
			"AC2: same seed and rank-4 aim replay receipt, snapshot and RNG exactly")
	# The widened reach never widens the launch ranks: the same tier-III ability cannot launch
	# from an in-memory hero rank 4, and that refusal spends no turn, state or RNG.
	var vanguard := _rank4_battle(ALTERNATES["arms"], 3, 502061)
	_check(vanguard != null, "AC3: genuine rank-4 Scarecrow battle builds for Harvest Fright")
	if vanguard != null:
		_check(int(vanguard.get_unit("scarecrow")["rank"]) == 4
			and str(vanguard.get_unit("scarecrow")["parts"]["arms"]["id"]) == ALTERNATES["arms"],
			"AC3: the rank-4 launch witness really stands in hero rank 4 with Harvest Fright")
		if _to(vanguard, "scarecrow"):
			_reject_without_spend(vanguard, ALTERNATES["arms"], 1,
				"tier-III Harvest Fright cannot launch from hero rank 4")
		else:
			_check(false, "AC3: rank-4 launch gate receives an actual scheduled turn")


## Raw JSON numbers parse as floats, so authored override values are compared as ints.
func _int_ranks(value: Variant) -> Array:
	var ranks: Array = []
	if not value is Array:
		return ranks
	for item in value:
		ranks.append(int(item))
	return ranks


func _int_effects(value: Variant) -> Dictionary:
	var effects := {}
	if not value is Dictionary:
		return effects
	for key in value:
		effects[str(key)] = int(value[key])
	return effects


func _status_amount(statuses: Array, key: String) -> int:
	for status in statuses:
		if str(status.get("status", "")) == key:
			return int(status.get("duration", 0))
	return 0


func _reject_without_spend(b: StitchedRules, id: String, rank: int, label: String) -> void:
	var actor := b.current_actor_id()
	var snapshot := b.state_snapshot()
	var rng := b.rng_state()
	var result := b.use_part(id, rank)
	_check(not bool(result.get("ok", false)) and str(result.get("error", "")) != ""
		and b.current_actor_id() == actor and b.state_snapshot() == snapshot and b.rng_state() == rng,
		"AC3: " + label + " rejects with unchanged actor, state and RNG")


func _test_rejections() -> void:
	var bad := _config()
	if bad.is_empty():
		return
	bad["heroes"][1]["parts"]["arms"] = {"id": STARTERS["head"], "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: mismatched head in arms slot rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": STARTERS["head"], "tier": 4}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: invalid tier IV rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["head"] = {"id": "scarecrow_head_missing", "tier": 1}
	_check(not bool(StitchedRules.create(bad).get("ok", false)),
		"AC3: unknown part rejected at battle creation")
	bad = _config()
	bad["heroes"][1]["parts"]["arms"] = {"id": STARTERS["arms"], "tier": 1, "torn": true}
	var torn_built := StitchedRules.create(bad)
	_check(bool(torn_built.get("ok", false)), "AC3: torn Scarecrow equipment permitted at setup")
	if bool(torn_built.get("ok", false)):
		var torn: StitchedRules = torn_built["battle"]
		if _to(torn, "scarecrow"):
			_reject_without_spend(torn, STARTERS["arms"], 1, "torn part")
		else:
			_check(false, "AC3: torn part has actual turn witness")
	var b := _battle()
	if b == null or not _to(b, "scarecrow"):
		_check(false, "AC3: invalid-action witness has an actual turn")
		return
	for action in [[STARTERS["arms"], 3], [STARTERS["head"], 4], [STARTERS["torso"], 0], [ALTERNATES["arms"], 1], ["scarecrow_missing", 1]]:
		_reject_without_spend(b, str(action[0]), int(action[1]),
			"illegal enemy target rank / ally side target / unequipped part " + str(action))
	var played := b.use_part(STARTERS["head"], 1)
	_check(bool(played.get("ok", false)), "AC3: legal Scarecrow action actually spends turn")
	if bool(played.get("ok", false)):
		_reject_without_spend(b, STARTERS["arms"], 1, "wrong active side / off-turn Scarecrow action")
	# Crow Flock's authored reach is now all four enemy ranks: from a legal rank-2 launch,
	# out-of-range ranks 0/5 still refuse without spending the turn, while a legal but vacant
	# enemy rank 4 resolves only the three living foes at ranks 1-3 with no phantom result.
	var flock := _battle(ALTERNATES["head"])
	if flock == null or not _to(flock, "scarecrow"):
		_check(false, "AC3: Crow Flock target rejection witness receives an actual turn")
	else:
		for bad_rank in [0, 5]:
			_reject_without_spend(flock, ALTERNATES["head"], bad_rank,
				"Crow Flock rejects enemy rank %d" % bad_rank)
		var before := flock.state_snapshot()
		var flock_cast := flock.use_part(ALTERNATES["head"], 4)
		var results: Array = flock_cast.get("results", [])
		var result_ranks: Dictionary = {}
		var ghost := false
		for receipt in results:
			var target_rank := int(receipt.get("target_rank", 0))
			result_ranks[target_rank] = str(receipt["target"])
			ghost = ghost or target_rank == 4
		var after := flock.state_snapshot()
		_check(bool(flock_cast.get("ok", false)) and results.size() == 3
			and result_ranks.size() == 3 and result_ranks.has(1)
			and result_ranks.has(2) and result_ranks.has(3) and not ghost,
			"AC3: vacant selected enemy rank 4 resolves only the three living ranks 1-3")
		_check(int(after["round"]) != int(before["round"])
			or int(after["turn_index"]) != int(before["turn_index"]),
			"AC3: the legal empty-rank-4 Crow Flock cast spends Scarecrow's turn")
		_reject_without_spend(flock, ALTERNATES["head"], 4,
			"replayed Crow Flock after the turn is spent")
	# The real remaining preview heroes are kept; only an in-memory rearrangement moves
	# Scarecrow's entry to the front, so he genuinely stands in hero rank 1, where Crow
	# Flock may not launch even against a living rank-1 foe.
	var front := _config(ALTERNATES["head"])
	if front.is_empty():
		return
	var scarecrow: Dictionary = front["heroes"].pop_at(1)
	front["heroes"].insert(0, scarecrow)
	var built := StitchedRules.create(front)
	_check(bool(built.get("ok", false)), "AC3: genuine rank-1 Scarecrow party is a valid 4v3 battle")
	if bool(built.get("ok", false)):
		var vanguard: StitchedRules = built["battle"]
		_check(int(vanguard.get_unit("scarecrow")["rank"]) == 1,
			"AC3: rank-1 witness really stands in hero rank 1")
		if _to(vanguard, "scarecrow"):
			_check(str(vanguard.get_unit("scarecrow")["parts"]["head"]["id"]) == ALTERNATES["head"],
				"AC3: the rank-1 witness really has Crow Flock equipped")
			_reject_without_spend(vanguard, ALTERNATES["head"], 1,
				"Crow Flock forbidden from hero rank 1")
		else:
			_check(false, "AC3: rank-1 launch gate receives an actual scheduled turn")


func _trace(seed_value: int) -> Dictionary:
	var b := _battle("", 2, seed_value)
	if b == null:
		return {}
	var receipts: Array = []
	for action in [[STARTERS["head"], 1], [STARTERS["arms"], 2], [STARTERS["torso"], 1], [STARTERS["legs"], 1]]:
		if not _to(b, "scarecrow"):
			break
		receipts.append(b.use_part(str(action[0]), int(action[1])))
	return {"receipts": receipts, "snapshot": b.state_snapshot(), "rng": b.rng_state()}


func _test_replay() -> void:
	var first := _trace(501919)
	var second := _trace(501919)
	_check(not first.is_empty() and first == second and first.get("receipts", []).size() == 4,
		"AC3: equal seeded four-part traces replay exact receipts, battle state and RNG")
	for receipt in first.get("receipts", []):
		_check(bool(receipt.get("ok", false)), "AC3: every replayed action actually executes")


## AC2/AC3: real unmodified S2 4v3 battle, with starter Sack Glare worn at tier I.
## The only difference from the matched-seed control is clearing Weak on the
## rank-1 Fray Scavenger AFTER its genuine turn-start countdown to one.
func _sack_glare_tier1_reply_trial(seed_value: int) -> Dictionary:
	var weakened := _battle(STARTERS["head"], 1, seed_value)
	var control := _battle(STARTERS["head"], 1, seed_value)
	if weakened == null or control == null \
		or not _to(weakened, "scarecrow") or not _to(control, "scarecrow"):
		return {}
	if weakened.get_heroes().size() != 4 or weakened.get_foes().size() != 3 \
		or weakened.current_actor_id() != "scarecrow" \
		or weakened.state_snapshot() != control.state_snapshot() \
		or weakened.rng_state() != control.rng_state():
		return {}
	var actor := weakened.get_unit("scarecrow")
	var foe_before := weakened.get_unit("fray_scavenger")
	if int(actor.get("rank", 0)) != 2 \
		or str(actor.get("parts", {}).get("head", {}).get("id", "")) != STARTERS["head"] \
		or int(actor.get("parts", {}).get("head", {}).get("tier", 0)) != 1 \
		or int(foe_before.get("rank", 0)) != 1 or int(foe_before.get("hp", 0)) <= 0 \
		or int(foe_before.get("statuses", {}).get("weak", 0)) != 0 \
		or int(foe_before.get("statuses", {}).get("mark", 0)) != 0:
		return {}
	var before := weakened.state_snapshot()
	var cast := weakened.use_part(STARTERS["head"], 1)
	var control_cast := control.use_part(STARTERS["head"], 1)
	var after_cast := weakened.state_snapshot()
	var receipts: Array = cast.get("results", [])
	if not bool(cast.get("ok", false)) or cast != control_cast \
		or receipts.size() != 1 or after_cast == before \
		or after_cast != control.state_snapshot() \
		or weakened.rng_state() != control.rng_state() \
		or str(cast.get("actor", "")) != "scarecrow" \
		or str(cast.get("part", "")) != STARTERS["head"] \
		or str(cast.get("ability", "")) != "scarecrow_head_sack_glare_move":
		return {}
	var hit: Dictionary = receipts[0]
	if not bool(hit.get("hit", false)) or str(hit.get("target", "")) != "fray_scavenger" \
		or int(hit.get("target_rank", 0)) != 1 \
		or str(hit.get("target_side", "")) != "foe" \
		or int(hit.get("damage", -1)) != 0 \
		or int(hit.get("target_hp", -1)) != int(foe_before["hp"]) \
		or int(weakened.get_unit("fray_scavenger")["hp"]) != int(foe_before["hp"]) \
		or _status_amount(hit.get("statuses", []), "weak") != 2 \
		or _status_amount(hit.get("statuses", []), "mark") != 2:
		return {}
	if not _to(weakened, "fray_scavenger") or not _to(control, "fray_scavenger"):
		return {}
	var actual_foe := weakened.get_unit("fray_scavenger")
	var hero_before := weakened.get_unit("scarecrow")
	if weakened.current_actor_id() != "fray_scavenger" \
		or int(actual_foe.get("rank", 0)) != 1 \
		or int(actual_foe.get("hp", 0)) <= 0 \
		or int(actual_foe["statuses"].get("weak", 0)) != 1 \
		or int(actual_foe["statuses"].get("mark", 0)) < 1 \
		or int(hero_before.get("hp", 0)) <= 0 \
		or hero_before != control.get_unit("scarecrow") \
		or weakened.state_snapshot() != control.state_snapshot():
		return {}
	var expected_control := weakened.state_snapshot()
	for unit in expected_control["units"]:
		if str(unit["id"]) == "fray_scavenger":
			unit["statuses"].erase("weak")
	var rng_before := weakened.rng_state()
	control._units["fray_scavenger"]["statuses"].erase("weak")
	if control.state_snapshot() != expected_control \
		or rng_before != control.rng_state():
		return {}
	var weak_reply := weakened.use_foe_ability("sack_swing", 2)
	var plain_reply := control.use_foe_ability("sack_swing", 2)
	if not bool(weak_reply.get("ok", false)) or not bool(plain_reply.get("ok", false)) \
		or str(weak_reply.get("actor", "")) != "fray_scavenger" \
		or str(plain_reply.get("actor", "")) != "fray_scavenger" \
		or weak_reply.get("results", []).size() != 1 \
		or plain_reply.get("results", []).size() != 1:
		return {}
	var weak_hit: Dictionary = weak_reply["results"][0]
	var plain_hit: Dictionary = plain_reply["results"][0]
	if not bool(weak_hit.get("hit", false)) or not bool(plain_hit.get("hit", false)) \
		or str(weak_hit.get("target", "")) != "scarecrow" \
		or str(plain_hit.get("target", "")) != "scarecrow" \
		or int(weak_hit.get("roll", -1)) != int(plain_hit.get("roll", -2)) \
		or bool(weak_hit.get("crit", false)) != bool(plain_hit.get("crit", false)) \
		or int(weak_hit.get("damage", 0)) <= 0 \
		or int(weak_hit["damage"]) >= int(plain_hit.get("damage", 0)) \
		or int(weak_hit.get("target_hp", -1)) != int(hero_before["hp"]) - int(weak_hit["damage"]) \
		or int(plain_hit.get("target_hp", -1)) != int(hero_before["hp"]) - int(plain_hit["damage"]) \
		or int(weakened.get_unit("scarecrow")["hp"]) != int(weak_hit["target_hp"]) \
		or int(control.get_unit("scarecrow")["hp"]) != int(plain_hit["target_hp"]) \
		or weakened.rng_state() != control.rng_state():
		return {}
	var after_reply := weakened.state_snapshot()
	if not _to(weakened, "fray_scavenger") or not _to(control, "fray_scavenger"):
		return {}
	if int(weakened.get_unit("fray_scavenger")["statuses"].get("weak", 0)) != 0 \
		or weakened.get_unit("fray_scavenger")["statuses"].has("weak") \
		or int(weakened.get_unit("fray_scavenger").get("hp", 0)) <= 0 \
		or weakened.rng_state() != control.rng_state():
		return {}
	return {
		"seed": seed_value, "cast": cast, "cast_state": after_cast,
		"cast_rng": int(after_cast["rng_state"]), "weak_at_attack": 1,
		"weak_reply": weak_reply, "plain_reply": plain_reply,
		"weak_damage": int(weak_hit["damage"]), "plain_damage": int(plain_hit["damage"]),
		"hero_hp_before": int(hero_before["hp"]),
		"after_reply": after_reply, "expired": true,
		"after_expiry": weakened.state_snapshot(), "after_expiry_rng": weakened.rng_state(),
		"control_after_expiry": control.state_snapshot(), "control_rng": control.rng_state(),
	}


func _test_sack_glare_tier1_weak_reply() -> void:
	var witness: Dictionary = {}
	for seed_value in range(501500, 501900):
		witness = _sack_glare_tier1_reply_trial(seed_value)
		if not witness.is_empty():
			break
	_check(not witness.is_empty(),
		"AC2: a seeded real 4v3 tier-I Sack Glare lowers the next landed Fray Scavenger Sack Swing")
	if not witness.is_empty():
		_check(int(witness["weak_at_attack"]) == 1 and bool(witness["expired"]),
			"AC2: Weak 2 ticks to 1 for the real rank-1 foe attack and expires by its next turn")
		_check(int(witness["weak_damage"]) > 0 and int(witness["weak_damage"]) < int(witness["plain_damage"]),
			"AC2: same-roll, same-crit landed Sack Swing loses actual HP damage only with Weak")
		var replay := _sack_glare_tier1_reply_trial(int(witness["seed"]))
		_check(not replay.is_empty() and replay == witness,
			"AC3: tier-I Sack Glare, foe reply, expiry, receipts, state and RNG replay identically")
	var miss_witness := false
	for seed_value in range(501900, 502100):
		var b := _battle(STARTERS["head"], 1, seed_value)
		var replay := _battle(STARTERS["head"], 1, seed_value)
		if b == null or replay == null or not _to(b, "scarecrow") or not _to(replay, "scarecrow"):
			continue
		if int(b.get_unit("fray_scavenger").get("hp", 0)) <= 0 \
			or int(b.get_unit("fray_scavenger").get("rank", 0)) != 1 \
			or b.state_snapshot() != replay.state_snapshot():
			continue
		var before := b.get_unit("fray_scavenger")
		var cast := b.use_part(STARTERS["head"], 1)
		var cast_replay := replay.use_part(STARTERS["head"], 1)
		var receipts: Array = cast.get("results", [])
		if not bool(cast.get("ok", false)) or receipts.size() != 1 \
			or bool(receipts[0].get("hit", true)):
			continue
		var missed: Dictionary = receipts[0]
		miss_witness = str(missed.get("target", "")) == "fray_scavenger" \
			and int(missed.get("damage", -1)) == 0 \
			and missed.get("statuses", []).is_empty() \
			and int(b.get_unit("fray_scavenger")["statuses"].get("weak", 0)) == 0 \
			and int(b.get_unit("fray_scavenger")["statuses"].get("mark", 0)) == 0 \
			and int(b.get_unit("fray_scavenger")["hp"]) == int(before["hp"]) \
			and cast == cast_replay \
			and b.state_snapshot() == replay.state_snapshot() \
			and b.rng_state() == replay.rng_state()
		if miss_witness:
			break
	_check(miss_witness,
		"AC3: a genuine tier-I rank-1 miss applies neither status and replays receipt, state and RNG")
