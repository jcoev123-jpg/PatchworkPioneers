extends SceneTree
## Headless, scene-free regression for the terse sewn card face.
##
## The face keeps exact authored damage, Block, Thorns, heal, status and Unravel
## amounts and only names the Pinned, Guarding and Thorns keywords. The full
## mechanics (the different-owner +5, the Guard redirect, the Thorns return
## damage and their expiry) belong to CardKeywordGlossary's Help rows.
##
## Every record below is read from the shipped Warden/Tinker/Lantern Monk pools
## and the V3 Rag Duelist, Lantern Monk and Scarecrow catalogs; the only
## hand-written records are the in-memory unknown/malformed probes, which must
## stay honest instead of inventing mechanics. The six Rag Duelist variants plus
## the six authored one-shot Dodge records are read from their real catalogs;
## their effects are printed, not resolved. The eight Scarecrow Fear printings are
## read from the real starter and pool catalogs: the face names the keyword and
## the separate Weak, while Help owns the one-turn buff lock.

## The exact short face each shipped base/'+' record must print.
const FACE_CASES := [
	{"id": "warden_pinning_jab", "line": "Deal 4. Pin."},
	{"id": "warden_pinning_jab_plus", "line": "Deal 6. Pin."},
	{"id": "warden_draw_fire", "line": "Gain 6 Block. Guard."},
	{"id": "warden_draw_fire_plus", "line": "Gain 8 Block. Guard."},
	{"id": "warden_counter_stitch", "line": "Gain 5 Block. Gain 3 Thorns."},
	{"id": "warden_counter_stitch_plus", "line": "Gain 7 Block. Gain 4 Thorns."},
	{"id": "tinker_spring_trap", "line": "Deal 3. Pin."},
	{"id": "tinker_spring_trap_plus", "line": "Deal 4. Pin."},
]
## Prose that belongs to the Help glossary or the drawn pips, never to the face.
const HELP_ONLY_WORDS := ["+5", "until", "next turn", "different hero",
	"DIFFERENT hero", "redirect", "redirected", "expires", "From", "Target"]
const UNKNOWN_FALLBACK := "Other authored effects are not described."
## The six exact short faces of the V3 Rag Duelist reward descriptors. Looked up
## by named ID only, so no catalog total or ordered ID list is asserted here.
const RAG_FACE_CASES := [
	{"id": "rag_duelist_cape_guard", "line": "Gain 5 Block. Gain 3 Riposte."},
	{"id": "rag_duelist_cape_guard_plus", "line": "Gain 7 Block. Gain 4 Riposte."},
	{"id": "rag_duelist_duelist_reprise", "line": "Gain 5 Riposte."},
	{"id": "rag_duelist_duelist_reprise_plus", "line": "Gain 7 Riposte."},
	{"id": "rag_duelist_tattered_snare", "line": "Tangled 2."},
	{"id": "rag_duelist_tattered_snare_plus", "line": "Tangled 3."},
]
## The seven keyword rows that existed before Riposte and Tangled were appended.
const LEGACY_KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel",
	"guarding", "thorns"]
## The twelve Lantern Monk record variants that author a Blind: two starter and
## four reward-pool bases plus each real '+' variant. Looked up by named ID only,
## so no catalog total or ordered ID list is asserted here. Moth Cloud now names
## its authentic `exhaust: true` beside the Blind, so its face is fully described.
const LANTERN_MONK_FACE_CASES := [
	{"id": "lantern_monk_wick_spark", "target": "enemy_single",
		"line": "Deal 4. Blind."},
	{"id": "lantern_monk_wick_spark_plus", "target": "enemy_single",
		"line": "Deal 6. Blind."},
	{"id": "lantern_monk_moth_wink", "target": "enemy_single",
		"line": "Blind. Draw 1."},
	{"id": "lantern_monk_moth_wink_plus", "target": "enemy_single",
		"line": "Blind. Draw 1."},
	{"id": "lantern_monk_wick_flicker", "target": "enemy_single",
		"line": "Deal 4. Blind."},
	{"id": "lantern_monk_wick_flicker_plus", "target": "enemy_single",
		"line": "Deal 6. Blind."},
	{"id": "lantern_monk_moth_lure", "target": "enemy_single",
		"line": "Blind. Draw 1."},
	{"id": "lantern_monk_moth_lure_plus", "target": "enemy_single",
		"line": "Blind. Draw 1."},
	{"id": "lantern_monk_snuff_flame", "target": "enemy_single",
		"line": "Deal 3. Exposed 1. Blind."},
	{"id": "lantern_monk_snuff_flame_plus", "target": "enemy_single",
		"line": "Deal 4. Exposed 2. Blind."},
	{"id": "lantern_monk_moth_cloud", "target": "enemy_all",
		"line": "Blind to all. Exhaust."},
	{"id": "lantern_monk_moth_cloud_plus", "target": "enemy_all",
		"line": "Blind to all. Exhaust."},
]
## AC1: the six authored one-shot Dodge records, looked up by named ID in their
## real V3 catalog. The four Rag Duelist Cape cards keep their self recipient and
## print the bare one-shot clause; the two Lantern Monk Moth Shroud records keep
## their authored ally Block and join the same clause into one short sentence.
const DODGE_FACE_CASES := [
	{"catalog": "rag_duelist_starter", "id": "rag_duelist_cape_slip",
		"owner": "rag_duelist", "target": "self", "line": "Dodge the next attack."},
	{"catalog": "rag_duelist_starter", "id": "rag_duelist_cape_slip_plus",
		"owner": "rag_duelist", "target": "self", "line": "Dodge the next attack."},
	{"catalog": "rag_duelist_pool", "id": "rag_duelist_cape_flourish",
		"owner": "rag_duelist", "target": "self", "line": "Dodge the next attack."},
	{"catalog": "rag_duelist_pool", "id": "rag_duelist_cape_flourish_plus",
		"owner": "rag_duelist", "target": "self", "line": "Dodge the next attack."},
	{"catalog": "lantern_monk_pool", "id": "lantern_monk_moth_shroud",
		"owner": "lantern_monk", "target": "ally_single", "block": 6,
		"line": "Ally gains 6 Block and dodges the next attack."},
	{"catalog": "lantern_monk_pool", "id": "lantern_monk_moth_shroud_plus",
		"owner": "lantern_monk", "target": "ally_single", "block": 8,
		"line": "Ally gains 8 Block and dodges the next attack."},
]
## AC1/AC2: the eight authentic Scarecrow `cannot_buff_next_turn: true` printings,
## looked up by named ID in their real V3 catalogs (never a catalog total or an
## ordered ID list). The expected sentence is the authored Weak (and Harvest
## Fright's damage) followed by one Fear keyword for one enemy or every enemy.
const SCARECROW_FEAR_CASES := [
	{"catalog": "starter", "id": "scarecrow_sack_glare", "owner": "scarecrow",
		"cost": 1, "target": "enemy_single", "weak": 1, "damage": 0,
		"line": "Weak 1. Fear."},
	{"catalog": "starter", "id": "scarecrow_sack_glare_plus", "owner": "scarecrow",
		"cost": 1, "target": "enemy_single", "weak": 2, "damage": 0,
		"line": "Weak 2. Fear."},
	{"catalog": "pool", "id": "scarecrow_sack_grin", "owner": "scarecrow",
		"cost": 1, "target": "enemy_single", "weak": 1, "damage": 0,
		"line": "Weak 1. Fear."},
	{"catalog": "pool", "id": "scarecrow_sack_grin_plus", "owner": "scarecrow",
		"cost": 1, "target": "enemy_single", "weak": 2, "damage": 0,
		"line": "Weak 2. Fear."},
	{"catalog": "pool", "id": "scarecrow_crow_flock", "owner": "scarecrow",
		"cost": 2, "target": "enemy_all", "weak": 1, "damage": 0,
		"line": "Weak 1 to all. Fear to all."},
	{"catalog": "pool", "id": "scarecrow_crow_flock_plus", "owner": "scarecrow",
		"cost": 2, "target": "enemy_all", "weak": 2, "damage": 0,
		"line": "Weak 2 to all. Fear to all."},
	{"catalog": "pool", "id": "scarecrow_harvest_fright", "owner": "scarecrow",
		"cost": 3, "target": "enemy_all", "weak": 2, "damage": 4,
		"line": "Deal 4 to all. Weak 2 to all. Fear to all."},
	{"catalog": "pool", "id": "scarecrow_harvest_fright_plus", "owner": "scarecrow",
		"cost": 3, "target": "enemy_all", "weak": 3, "damage": 6,
		"line": "Deal 6 to all. Weak 3 to all. Fear to all."},
]
## AC1: the four authentic Scarecrow shoulder-crow printings (Crow Dive and Crow Peck,
## base and '+'), looked up by named ID in their real starter and pool catalogs
## (never a catalog total or an ordered ID list). The expected line names the backmost
## living enemy, states the authored damage, and prints the Pierce Block clause.
const SCARECROW_CROW_CASES := [
	{"catalog": "starter", "id": "scarecrow_crow_dive", "owner": "scarecrow",
		"cost": 1, "target": "enemy_back", "damage": 3,
		"line": "Deal 3 to the backmost living enemy. Pierce Block."},
	{"catalog": "starter", "id": "scarecrow_crow_dive_plus", "owner": "scarecrow",
		"cost": 1, "target": "enemy_back", "damage": 5,
		"line": "Deal 5 to the backmost living enemy. Pierce Block."},
	{"catalog": "pool", "id": "scarecrow_crow_peck", "owner": "scarecrow",
		"cost": 1, "target": "enemy_back", "damage": 4,
		"line": "Deal 4 to the backmost living enemy. Pierce Block."},
	{"catalog": "pool", "id": "scarecrow_crow_peck_plus", "owner": "scarecrow",
		"cost": 1, "target": "enemy_back", "damage": 6,
		"line": "Deal 6 to the backmost living enemy. Pierce Block."},
]
## AC1: the four authentic V3 Seamstress Tether printings (Tether Loop and Tether Stitch,
## base and '+'), looked up by named ID in their real starter and pool catalogs
## (never a catalog total or an ordered ID list). The expected line names the two living
## enemies and states the 50% echo rule.
const TETHER_CASES := [
	{"catalog": "starter", "id": "seamstress_v3_tether_loop", "owner": "seamstress",
		"cost": 2, "target": "enemy_pair", "share": 50,
		"line": "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."},
	{"catalog": "starter", "id": "seamstress_v3_tether_loop_plus", "owner": "seamstress",
		"cost": 1, "target": "enemy_pair", "share": 50,
		"line": "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."},
	{"catalog": "pool", "id": "seamstress_v3_tether_stitch", "owner": "seamstress",
		"cost": 2, "target": "enemy_pair", "share": 50,
		"line": "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."},
	{"catalog": "pool", "id": "seamstress_v3_tether_stitch_plus", "owner": "seamstress",
		"cost": 1, "target": "enemy_pair", "share": 50,
		"line": "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."},
]

## AC1/AC2: the 16 authentic V3 Warden shield, Guard and Taunt printings (8 pairs),
## looked up by named ID in V3WardenStarterCards and V3WardenPoolCards.
const WARDEN_V3_CASES := [
	{"catalog": "starter", "id": "warden_v3_shield_catch",
		"line": "Ally gains 4 Block. Guard.",
		"phrases": ["Ally gains 4 Block.", "Guard."],
		"keywords": ["Guard"], "guard": true, "taunt": false, "toss": false},
	{"catalog": "starter", "id": "warden_v3_shield_catch_plus",
		"line": "Ally gains 6 Block. Guard.",
		"phrases": ["Ally gains 6 Block.", "Guard."],
		"keywords": ["Guard"], "guard": true, "taunt": false, "toss": false},
	{"catalog": "pool", "id": "warden_v3_guard_stitch",
		"line": "Ally gains 5 Block. Guard.",
		"phrases": ["Ally gains 5 Block.", "Guard."],
		"keywords": ["Guard"], "guard": true, "taunt": false, "toss": false},
	{"catalog": "pool", "id": "warden_v3_guard_stitch_plus",
		"line": "Ally gains 7 Block. Guard.",
		"phrases": ["Ally gains 7 Block.", "Guard."],
		"keywords": ["Guard"], "guard": true, "taunt": false, "toss": false},
	{"catalog": "starter", "id": "warden_v3_rim_toss",
		"line": "Deal damage equal to current Block.",
		"phrases": ["Deal damage equal to current Block."],
		"keywords": ["Shield Toss"], "guard": false, "taunt": false, "toss": true},
	{"catalog": "starter", "id": "warden_v3_rim_toss_plus",
		"line": "Deal damage equal to current Block + 2.",
		"phrases": ["Deal damage equal to current Block + 2."],
		"keywords": ["Shield Toss"], "guard": false, "taunt": false, "toss": true},
	{"catalog": "pool", "id": "warden_v3_shield_toss",
		"line": "Deal damage equal to current Block.",
		"phrases": ["Deal damage equal to current Block."],
		"keywords": ["Shield Toss"], "guard": false, "taunt": false, "toss": true},
	{"catalog": "pool", "id": "warden_v3_shield_toss_plus",
		"line": "Deal damage equal to current Block + 3.",
		"phrases": ["Deal damage equal to current Block + 3."],
		"keywords": ["Shield Toss"], "guard": false, "taunt": false, "toss": true},
	{"catalog": "starter", "id": "warden_v3_iron_challenge",
		"line": "Gain 3 Block. Taunt.",
		"phrases": ["Gain 3 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "starter", "id": "warden_v3_iron_challenge_plus",
		"line": "Gain 5 Block. Taunt.",
		"phrases": ["Gain 5 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_iron_taunt",
		"line": "Gain 4 Block. Taunt.",
		"phrases": ["Gain 4 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_iron_taunt_plus",
		"line": "Gain 6 Block. Taunt.",
		"phrases": ["Gain 6 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_shieldwall_chorus",
		"line": "All allies gain 4 Block. Taunt.",
		"phrases": ["All allies gain 4 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_shieldwall_chorus_plus",
		"line": "All allies gain 6 Block. Taunt.",
		"phrases": ["All allies gain 6 Block.", "Taunt."],
		"keywords": ["Taunt"], "guard": false, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_final_bastion",
		"line": "Gain 12 Block. Guard. Taunt.",
		"phrases": ["Gain 12 Block.", "Guard.", "Taunt."],
		"keywords": ["Guard", "Taunt"], "guard": true, "taunt": true, "toss": false},
	{"catalog": "pool", "id": "warden_v3_final_bastion_plus",
		"line": "Gain 16 Block. Guard. Taunt.",
		"phrases": ["Gain 16 Block.", "Guard.", "Taunt."],
		"keywords": ["Guard", "Taunt"], "guard": true, "taunt": true, "toss": false},
]


## AC1/AC2: the 20 authentic V3 Tinker Combat Scrap printings (8 starter, 12 pool),
## looked up by named ID in V3TinkerStarterCards and V3TinkerPoolCards.
const TINKER_V3_CASES := [
	{"catalog": "starter", "id": "tinker_v3_cog_shot",
		"line": "Deal 5. Gain 1 Combat Scrap.",
		"phrases": ["Deal 5.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_cog_shot_plus",
		"line": "Deal 7. Gain 1 Combat Scrap.",
		"phrases": ["Deal 7.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_casing_ward",
		"line": "Gain 5 Block. Gain 1 Combat Scrap.",
		"phrases": ["Gain 5 Block.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_casing_ward_plus",
		"line": "Gain 7 Block. Gain 1 Combat Scrap.",
		"phrases": ["Gain 7 Block.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_scrap_bomb",
		"line": "Deal 4 to all. Gain 1 Combat Scrap.",
		"phrases": ["Deal 4 to all.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_scrap_bomb_plus",
		"line": "Deal 6 to all. Gain 1 Combat Scrap.",
		"phrases": ["Deal 6 to all.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_tune_up",
		"line": "Draw 1. Gain 1 Combat Scrap.",
		"phrases": ["Draw 1.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "starter", "id": "tinker_v3_tune_up_plus",
		"line": "Draw 2. Gain 1 Combat Scrap.",
		"phrases": ["Draw 2.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_brass_casing",
		"line": "Deal 4. Gain 1 Combat Scrap.",
		"phrases": ["Deal 4.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_brass_casing_plus",
		"line": "Deal 6. Gain 1 Combat Scrap.",
		"phrases": ["Deal 6.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_gear_brace",
		"line": "Gain 5 Block. Gain 1 Combat Scrap.",
		"phrases": ["Gain 5 Block.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_gear_brace_plus",
		"line": "Gain 7 Block. Gain 1 Combat Scrap.",
		"phrases": ["Gain 7 Block.", "Gain 1 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_spare_screws",
		"line": "Draw 1. Gain 2 Combat Scrap.",
		"phrases": ["Draw 1.", "Gain 2 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 2, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_spare_screws_plus",
		"line": "Draw 1. Gain 2 Combat Scrap.",
		"phrases": ["Draw 1.", "Gain 2 Combat Scrap."],
		"keywords": ["Combat Scrap"], "gain": 2, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_spring_clamp",
		"line": "Deal 3. Weak 1. Gain 1 Combat Scrap.",
		"phrases": ["Deal 3. Weak 1.", "Gain 1 Combat Scrap."],
		"keywords": ["Weak 1", "Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_spring_clamp_plus",
		"line": "Deal 4. Weak 1. Gain 1 Combat Scrap.",
		"phrases": ["Deal 4. Weak 1.", "Gain 1 Combat Scrap."],
		"keywords": ["Weak 1", "Combat Scrap"], "gain": 1, "is_spender": false},
	{"catalog": "pool", "id": "tinker_v3_overload",
		"line": "Deal 2. Spend all Combat Scrap for +3 damage per Scrap.",
		"phrases": ["Deal 2.", "Spend all Combat Scrap for +3 damage per Scrap."],
		"keywords": ["Combat Scrap"], "gain": 0, "is_spender": true},
	{"catalog": "pool", "id": "tinker_v3_overload_plus",
		"line": "Deal 3. Spend all Combat Scrap for +4 damage per Scrap.",
		"phrases": ["Deal 3.", "Spend all Combat Scrap for +4 damage per Scrap."],
		"keywords": ["Combat Scrap"], "gain": 0, "is_spender": true},
	{"catalog": "pool", "id": "tinker_v3_scrapstorm",
		"line": "Deal 3 to all. Spend up to 3 Combat Scrap for +1 per spent Scrap to each living enemy.",
		"phrases": ["Deal 3 to all.", "Spend up to 3 Combat Scrap for +1 per spent Scrap to each living enemy."],
		"keywords": ["Combat Scrap"], "gain": 0, "is_spender": true},
	{"catalog": "pool", "id": "tinker_v3_scrapstorm_plus",
		"line": "Deal 4 to all. Spend up to 3 Combat Scrap for +1 per spent Scrap to each living enemy.",
		"phrases": ["Deal 4 to all.", "Spend up to 3 Combat Scrap for +1 per spent Scrap to each living enemy."],
		"keywords": ["Combat Scrap"], "gain": 0, "is_spender": true},
]

var failures: Array[String] = []
var checks := 0
var warden := WardenPoolCards.new()
var tinker := TinkerPoolCards.new()
var rag_duelist := RagDuelistPoolCards.new()
var rag_duelist_starter := RagDuelistStarterCards.new()
var lantern_monk_starter := LanternMonkStarterCards.new()
var lantern_monk_pool := LanternMonkPoolCards.new()
var scarecrow_starter := ScarecrowStarterCards.new()
var scarecrow_pool := ScarecrowPoolCards.new()
var v3_seamstress_starter := V3SeamstressStarterCards.new()
var v3_seamstress_pool := V3SeamstressPoolCards.new()
var v3_warden_starter := V3WardenStarterCards.new()
var v3_warden_pool := V3WardenPoolCards.new()
var v3_tinker_starter := V3TinkerStarterCards.new()
var v3_tinker_pool := V3TinkerPoolCards.new()


func _initialize() -> void:
	seed(4517)
	var expected_global := randi()
	seed(4517)
	_test_shipped_faces()
	_test_authored_amounts()
	_test_help_keeps_full_mechanics()
	_test_unknown_and_malformed_fallbacks()
	_test_rag_duelist_faces()
	_test_rag_duelist_help()
	_test_rag_duelist_malformed()
	_test_lantern_monk_faces()
	_test_blind_malformed_fallbacks()
	_test_dodge_faces()
	_test_moth_cloud_exhaust()
	_test_dodge_and_exhaust_malformed()
	_test_dodge_help()
	_test_exhaust_help()
	_test_dodge_exhaust_negative()
	_test_scarecrow_fear_faces()
	_test_scarecrow_fear_help()
	_test_scarecrow_fear_negative()
	_test_scarecrow_crow_faces()
	_test_scarecrow_crow_help()
	_test_scarecrow_crow_negative()
	_test_seamstress_tether_faces()
	_test_seamstress_tether_help()
	_test_seamstress_tether_negative()
	_test_warden_v3_faces()
	_test_warden_v3_help()
	_test_warden_v3_negative()
	_test_tinker_v3_faces()
	_test_tinker_v3_help()
	_test_tinker_v3_negative()
	_check(randi() == expected_global, "short-line formatting draws no global RNG")
	for failure in failures:
		printerr(failure)
	print("card_short_rules_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


## The shipped definitions live in the Warden and Tinker pools only.
func _definition(card_id: String) -> Dictionary:
	if warden.has_card(card_id):
		return warden.get_definition(card_id)
	if tinker.has_card(card_id):
		return tinker.get_definition(card_id)
	return {}


func _effects(card_id: String) -> Dictionary:
	var raw: Variant = _definition(card_id).get("effects", {})
	return raw if raw is Dictionary else {}


func _test_shipped_faces() -> void:
	for entry in FACE_CASES:
		var card_id: String = str(entry["id"])
		var expected_line: String = str(entry["line"])
		var definition := _definition(card_id)
		_check(not definition.is_empty(), "shipped catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var described: Dictionary = CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"face record is fully described, no fallback: " + card_id)
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		# Pinned keeps one keyword whether it is authored as a flag or a
		# nested descriptor, and never borrows the descriptor's bonus amount.
		if _effects(card_id).has("pinned"):
			_check(line.count("Pin") == 1 and not line.to_lower().contains("pin +"),
				"Pin is one bare keyword on the face: %s (%s)" % [card_id, line])
		_check(definition == original,
			"formatting never mutates the shipped record: " + card_id)


## The numbers printed on the face are exactly the authored ones, read from the
## same catalog record, so no amount is guessed or copied from another card.
func _test_authored_amounts() -> void:
	var cases := [
		["warden_pinning_jab", "Deal 4. Pin."],
		["warden_pinning_jab_plus", "Deal 6. Pin."],
		["tinker_spring_trap", "Deal 3. Pin."],
		["tinker_spring_trap_plus", "Deal 4. Pin."],
	]
	for pair in cases:
		var card_id: String = str(pair[0])
		var effects := _effects(card_id)
		var damage: int = int(effects.get("damage", -1))
		_check(damage > 0, "authored damage exists: " + card_id)
		_check(CardShortRules.line(_definition(card_id)) == str(pair[1])
			and str(pair[1]).begins_with("Deal %d. Pin." % damage),
			"face damage equals the authored amount: " + card_id)
	var block_cases := [
		["warden_draw_fire", "warden_draw_fire_plus"],
		["warden_counter_stitch", "warden_counter_stitch_plus"],
	]
	for ids in block_cases:
		var base_id: String = str(ids[0])
		var plus_id: String = str(ids[1])
		_check(int(_effects(plus_id).get("block", 0)) > int(_effects(base_id).get("block", 0)),
			"'+' really upgrades the authored Block: " + base_id)
		for card_id: String in [base_id, plus_id]:
			var block: int = int(_effects(card_id).get("block", -1))
			_check(CardShortRules.line(_definition(card_id)).contains(
				"Gain %d Block." % block),
				"face Block equals the authored amount: " + card_id)
	var thorns_cases := [
		["warden_counter_stitch", 3],
		["warden_counter_stitch_plus", 4],
	]
	for pair in thorns_cases:
		var card_id: String = str(pair[0])
		var authored: int = int(_effects(card_id).get("thorns", -1))
		_check(authored == int(pair[1]),
			"authored Thorns read from the catalog: " + card_id)
		_check(CardShortRules.line(_definition(card_id)).ends_with(
			"Gain %d Thorns." % authored),
			"face Thorns equals the authored amount: " + card_id)


func _keyword_rows(definition: Dictionary) -> Dictionary:
	var rows := {}
	for row: Dictionary in CardKeywordGlossary.describe(definition):
		rows[str(row.get("keyword", ""))] = str(row.get("explanation", ""))
	return rows


## True when the glossary prints a row with exactly this keyword name. Used by
## the fail-closed negatives: an unrelated keyword row (such as Blind) may still
## appear, but the forbidden Dodge/Exhaust row must not.
func _has_keyword_row(definition: Dictionary, keyword: String) -> bool:
	for row: Dictionary in CardKeywordGlossary.describe(definition):
		if str(row.get("keyword", "")) == keyword:
			return true
	return false


func _test_help_keeps_full_mechanics() -> void:
	# Both authored Pinned shapes keep the exact shared Help row.
	for card_id: String in ["warden_pinning_jab", "warden_pinning_jab_plus",
			"tinker_spring_trap", "tinker_spring_trap_plus"]:
		var pin_rows := _keyword_rows(_definition(card_id))
		_check(pin_rows.has("Pinned"), "Help explains Pinned: " + card_id)
		var explanation: String = str(pin_rows.get("Pinned", ""))
		_check(explanation.contains("next attack by a DIFFERENT hero adds +5 damage"),
			"Help keeps the different-owner +5: " + card_id)
		_check(explanation.contains("before Weak/Exposed"),
			"Help keeps the +5 timing before Weak/Exposed: " + card_id)
		_check(explanation.contains("consumes this pin"),
			"Help keeps the single consumption: " + card_id)
		_check(explanation.contains("The same hero cannot use it"),
			"Help keeps the same-hero exclusion: " + card_id)
	# Guard keeps its redirect target and its expiry.
	for card_id: String in ["warden_draw_fire", "warden_draw_fire_plus"]:
		var guard_rows := _keyword_rows(_definition(card_id))
		_check(guard_rows.has("Guarding"), "Help explains Guarding: " + card_id)
		var guard_text: String = str(guard_rows.get("Guarding", ""))
		_check(guard_text.contains("redirects attacks aimed at other heroes to Warden"),
			"Help keeps the Guard redirect: " + card_id)
		_check(guard_text.contains("until the next turn"),
			"Help keeps the Guard expiry: " + card_id)
		_check(CardShortRules.line(_definition(card_id)).contains("Guard.")
			and not CardShortRules.line(_definition(card_id)).contains("until"),
			"the face leaves the Guard duration to Help: " + card_id)
	# Thorns keeps its exact return damage and its expiry.
	for pair in [["warden_counter_stitch", 3], ["warden_counter_stitch_plus", 4]]:
		var card_id: String = str(pair[0])
		var authored: int = int(pair[1])
		var thorns_rows := _keyword_rows(_definition(card_id))
		_check(thorns_rows.has("Thorns %d" % authored),
			"Help explains Thorns %d: %s" % [authored, card_id])
		var thorns_text: String = str(thorns_rows.get("Thorns %d" % authored, ""))
		_check(thorns_text.contains("takes %d damage" % authored),
			"Help keeps the Thorns return damage: " + card_id)
		_check(not thorns_text.contains("Warden") and not thorns_text.contains("Counter-stitch")
			and not thorns_text.contains("positions 1-2"),
			"Help Thorns is source-neutral: " + card_id)
		_check(thorns_text.contains("until the next turn"),
			"Help keeps the Thorns expiry: " + card_id)
		_check(not CardShortRules.line(_definition(card_id)).contains("until"),
			"the face leaves the Thorns duration to Help: " + card_id)


func _test_unknown_and_malformed_fallbacks() -> void:
	var mystery := {"id": "card_short_rules_probe", "target_kind": "enemy_single",
		"effects": {"damage": 2, "mystery_damage": 9}}
	var original := mystery.duplicate(true)
	var line := CardShortRules.line(mystery)
	_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
		"an unknown effect keeps the honest fallback: " + line)
	_check(CardShortRules.has_unknown(mystery)
		and bool(CardShortRules.describe(mystery).get("unknown", false)),
		"an unknown effect is reported, not described")
	_check(not line.contains("9") and not line.contains("mystery"),
		"the fallback invents no amount and leaks no raw key")
	_check(mystery == original, "the in-memory probe is never mutated")
	# A malformed Pinned descriptor is an undescribed effect, never a keyword
	# with an invented bonus.
	var bad_pin := {"id": "card_short_rules_bad_pin", "target_kind": "enemy_single",
		"effects": {"damage": 2, "pinned": {}}}
	var bad_pin_line := CardShortRules.line(bad_pin)
	_check(bad_pin_line == "Deal 2. " + UNKNOWN_FALLBACK,
		"an empty Pinned descriptor falls back honestly: " + bad_pin_line)
	_check(not bad_pin_line.contains("Pin"),
		"no Pin keyword is printed for a descriptor it cannot read")
	var bad_thorns := {"id": "card_short_rules_bad_thorns", "target_kind": "self",
		"effects": {"block": 5, "thorns": "3"}}
	var bad_thorns_line := CardShortRules.line(bad_thorns)
	_check(bad_thorns_line == "Gain 5 Block. " + UNKNOWN_FALLBACK,
		"an unreadable Thorns amount falls back honestly: " + bad_thorns_line)
	_check(not bad_thorns_line.contains("Thorns"),
		"no Thorns amount is invented from a string")
	# No shipped record may be mutated by reading an unreadable probe.
	var draw_fire := _definition("warden_draw_fire")
	var draw_fire_before := draw_fire.duplicate(true)
	CardShortRules.line(bad_thorns)
	_check(draw_fire == draw_fire_before,
		"a malformed probe cannot alter a shipped record")


## AC1: the six authored Rag Duelist descriptors print their exact terse face,
## read from the real V3 pool by named ID (never a catalog total or ID list).
## The record's own effects are checked first so the assertions cannot pass on
## an empty or unrelated definition.
func _test_rag_duelist_faces() -> void:
	for entry in RAG_FACE_CASES:
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Rag Duelist catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		var riposte := int(effects.get("riposte", effects.get("tangled", 0)))
		_check(riposte > 0 and (effects.get("riposte") is int or effects.get("tangled") is int),
			"authored positive Riposte/Tangled amount: " + card_id)
		if effects.has("riposte"):
			_check(effects.get("duration") is int and int(effects["duration"]) == 1,
				"authored Riposte duration is the one turn: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"face record is fully described, no fallback: " + card_id)
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(not line.to_lower().contains("turn"),
			"the face leaves the duration to Help: %s (%s)" % [card_id, line])
		_check(definition == before and rag_duelist.get_definition(card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(rag_duelist.get_definition(card_id)) == expected_line,
			"repeated formatting is identical: " + card_id)
	# The remaining authored entries are not silently reinterpreted: the ones that
	# only use understood keys keep a complete face (the Cape Flourish records are
	# proven with the one-shot Dodge fixtures), and the ones with a key this
	# formatter cannot read still say so instead of hiding it.
	for card_id: String in ["rag_duelist_needle_prick", "rag_duelist_needle_prick_plus",
			"rag_duelist_velvet_feint", "rag_duelist_velvet_feint_plus"]:
		var line := CardShortRules.line(rag_duelist.get_definition(card_id))
		_check(not line.is_empty() and not line.contains(UNKNOWN_FALLBACK),
			"a fully understood Rag Duelist entry keeps a complete face: %s (%s)" % [card_id, line])
		_check(not line.contains("Riposte") and not line.contains("Tangled"),
			"no Riposte/Tangled is invented for %s (%s)" % [card_id, line])
	for card_id: String in ["rag_duelist_needle_lunge", "rag_duelist_needle_lunge_plus",
			"rag_duelist_needle_barrage", "rag_duelist_needle_barrage_plus"]:
		var line := CardShortRules.line(rag_duelist.get_definition(card_id))
		_check(line.contains(UNKNOWN_FALLBACK),
			"an unsupported Rag Duelist key stays honestly undescribed: %s (%s)" % [card_id, line])
		_check(not line.contains("Riposte") and not line.contains("Tangled"),
			"an unsupported key never borrows Riposte/Tangled: %s (%s)" % [card_id, line])


## AC2: Help explains the authored positive amounts with the documented rules,
## in the fixed keyword order after the legacy seven rows, and stays truthful
## about where Riposte and Tangled status rules apply versus unfinished live wiring.
func _test_rag_duelist_help() -> void:
	var legacy_size := LEGACY_KEYWORD_ORDER.size()
	_check(CardKeywordGlossary.KEYWORD_ORDER.slice(0, legacy_size) == LEGACY_KEYWORD_ORDER
		and CardKeywordGlossary.KEYWORD_ORDER.size() == legacy_size + 4
		and CardKeywordGlossary.KEYWORD_ORDER.slice(legacy_size) == ["riposte", "tangled", "blind", "fear"],
		"Riposte, Tangled, Blind and Fear follow the seven legacy keyword rows: "
		+ str(CardKeywordGlossary.KEYWORD_ORDER))
	for pair in [["rag_duelist_cape_guard", 3], ["rag_duelist_cape_guard_plus", 4],
			["rag_duelist_duelist_reprise", 5], ["rag_duelist_duelist_reprise_plus", 7]]:
		var card_id := str(pair[0])
		var amount := int(pair[1])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Riposte catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		_check(int(definition.get("effects", {}).get("riposte", -1)) == amount,
			"authored Riposte amount is %d: %s" % [amount, card_id])
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and str(rows[0].get("keyword", "")) == "Riposte %d" % amount,
			"exactly one Riposte %d Help row: %s" % [amount, card_id])
		if rows.size() == 1:
			var text := str(rows[0].get("explanation", ""))
			_check(text.contains("the Rag Duelist is hit"),
				"Help states the counterhit trigger: " + card_id)
			_check(text.contains("strikes back for %d damage" % amount),
				"Help repeats the authored counterhit damage: " + card_id)
			_check(text.contains("one turn"), "Help states the one-turn duration: " + card_id)
			_check(not text.contains("combat does not yet apply Riposte"),
				"stale Riposte caveat is replaced: " + card_id)
			_check(text.contains("counterdamage, not a number of turns"),
				"Help states Riposte N is counterdamage, not turns: " + card_id)
			_check(text.contains("status rules apply"),
				"Help states the status rules apply Riposte: " + card_id)
			_check(not text.contains("always") and not text.contains("every confirmed hit"),
				"Help does not claim every hit triggers Riposte: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Help reads are identical: " + card_id)
		_check(definition == before and rag_duelist.get_definition(card_id) == before,
			"Help never mutates the catalog record: " + card_id)
		var detached := CardKeywordGlossary.describe(definition)
		if detached.size() == 1:
			detached[0]["keyword"] = "Tampered"
			detached[0]["explanation"] = "Tampered"
			var fresh := CardKeywordGlossary.describe(definition)
			_check(fresh.size() == 1 and str(fresh[0].get("keyword", "")) == "Riposte %d" % amount
				and definition == before,
				"Help rows are detached from the caller's record: " + card_id)
	for pair in [["rag_duelist_tattered_snare", 2], ["rag_duelist_tattered_snare_plus", 3]]:
		var card_id := str(pair[0])
		var turns := int(pair[1])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Tangled catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		_check(int(definition.get("effects", {}).get("tangled", -1)) == turns,
			"authored Tangled turns are %d: %s" % [turns, card_id])
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and str(rows[0].get("keyword", "")) == "Tangled %d" % turns,
			"exactly one Tangled %d Help row: %s" % [turns, card_id])
		if rows.size() == 1:
			var text := str(rows[0].get("explanation", ""))
			_check(text.contains("For %d turns" % turns),
				"Help repeats the authored Tangled turns: " + card_id)
			_check(text.contains("cannot move or be moved by its own side"),
				"Help states the movement restriction: " + card_id)
			_check(text.contains("attacks against it deal +2 damage"),
				"Help states the +2 attack vulnerability: " + card_id)
			_check(not text.contains("combat does not yet apply Tangled"),
				"stale Tangled caveat is replaced: " + card_id)
			_check(text.contains("once per positive-base"),
				"Help states +2 is once per positive-base attack: " + card_id)
			_check(text.contains("after Weak and Exposed"),
				"Help states +2 timing after Weak/Exposed rounding: " + card_id)
			_check(text.contains("regardless of the Tangled count"),
				"Help states +2 is regardless of Tangled count: " + card_id)
			_check(text.contains("Tangled decrements at owner-turn end"),
				"Help states Tangled decrements at owner-turn end: " + card_id)
			_check(text.contains("status rules apply"),
				"Help states the status rules apply Tangled: " + card_id)
			_check(not text.contains("always") and not text.contains("every movement"),
				"Help does not claim every movement route is wired: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Help reads are identical: " + card_id)
		_check(definition == before, "Help never mutates the catalog record: " + card_id)
	# A record that authors every legacy keyword plus the two new ones keeps every
	# legacy row first, in its established order, with the new rows last.
	var combined := {"id": "card_short_rules_order_probe", "target_kind": "enemy_single",
		"effects": {"tangled": 2, "thorns": 3, "riposte": 3, "duration": 1,
			"bleed": 1, "weak": 1, "exposed": 1, "pinned": true, "unravel": 2,
			"guarding": true}}
	var combined_before := combined.duplicate(true)
	var names: Array[String] = []
	for row: Dictionary in CardKeywordGlossary.describe(combined):
		names.append(str(row.get("keyword", "")))
	_check(names == ["Bleed 1", "Weak 1", "Exposed 1", "Pinned", "Unravel 2",
		"Guarding", "Thorns 3", "Riposte 3", "Tangled 2"],
		"legacy keyword rows keep their order and the new rows follow: " + str(names))
	_check(combined == combined_before, "the combined ordering probe is never mutated")


## AC3: malformed Riposte/Tangled amounts, a wrong Riposte duration and a truly
## unrecognized key never print an invented number and never fabricate Help.
func _test_rag_duelist_malformed() -> void:
	for value: Variant in [0, -3, "3", 3.5]:
		var probe := {"id": "card_short_rules_bad_riposte", "target_kind": "self",
			"effects": {"block": 5, "riposte": value, "duration": 1}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Gain 5 Block. " + UNKNOWN_FALLBACK,
			"a malformed Riposte %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Riposte"),
			"no Riposte keyword is invented for %s" % str(value))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Riposte Help row is invented for %s" % str(value))
		_check(probe == before, "the malformed Riposte probe is never mutated: " + str(value))
	var duration_probes := [
		["absent", "absent"], ["integer 2", 2], ["integer 0", 0], ["text", "1"],
		["float", 1.0],
	]
	for case in duration_probes:
		var effects := {"riposte": 3}
		if str(case[1]) != "absent":
			effects["duration"] = case[1]
		var probe := {"id": "card_short_rules_bad_riposte_duration",
			"target_kind": "self", "effects": effects}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == UNKNOWN_FALLBACK,
			"a Riposte with a %s duration falls back honestly: %s" % [str(case[0]), line])
		_check(not line.contains("Riposte"),
			"no Riposte keyword is printed for a %s duration" % str(case[0]))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Riposte Help row for a %s duration" % str(case[0]))
		_check(probe == before,
			"the %s duration probe is never mutated" % str(case[0]))
	for value: Variant in [0, -2, "2", 2.5]:
		var probe := {"id": "card_short_rules_bad_tangled", "target_kind": "enemy_single",
			"effects": {"damage": 2, "tangled": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
			"a malformed Tangled %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Tangled"),
			"no Tangled keyword is invented for %s" % str(value))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Tangled Help row is invented for %s" % str(value))
		_check(probe == before, "the malformed Tangled probe is never mutated: " + str(value))
	# A valid Riposte beside a key this formatter cannot read prints the face
	# fallback and adds only the row it genuinely understands.
	var mystery := {"id": "card_short_rules_mystery_status", "target_kind": "self",
		"effects": {"block": 5, "riposte": 3, "duration": 1, "mystery_status": 9}}
	var mystery_before := mystery.duplicate(true)
	var mystery_line := CardShortRules.line(mystery)
	_check(mystery_line == "Gain 5 Block. Gain 3 Riposte. " + UNKNOWN_FALLBACK,
		"an unrecognized key keeps the established face fallback: " + mystery_line)
	_check(not mystery_line.contains("9"),
		"the unrecognized key's amount never leaks onto the face")
	var mystery_rows := CardKeywordGlossary.describe(mystery)
	_check(mystery_rows.size() == 1
		and str(mystery_rows[0].get("keyword", "")) == "Riposte 3",
		"an unrecognized key adds no fabricated Help row")
	_check(mystery == mystery_before, "the mystery-key probe is never mutated")
	var snare := rag_duelist.get_definition("rag_duelist_tattered_snare")
	var snare_before := snare.duplicate(true)
	CardShortRules.line(mystery)
	CardKeywordGlossary.describe(mystery)
	_check(not snare.is_empty() and snare == snare_before,
		"malformed probes cannot alter a shipped Rag Duelist record")


func _lantern_monk_definition(card_id: String) -> Dictionary:
	if lantern_monk_starter.has_card(card_id):
		return lantern_monk_starter.get_definition(card_id)
	if lantern_monk_pool.has_card(card_id):
		return lantern_monk_pool.get_definition(card_id)
	return {}


## AC1/AC2: the shipped Lantern Monk records that author `blind: 1` or
## `blind_next_attack: true` print exactly one Blind clause on their real face.
## Each record's owner, target, authored amounts and strict Blind spelling are
## checked before the exact string, so an empty or unrelated record cannot pass.
## The effect descriptors are still data: this proves the face wording only.
func _test_lantern_monk_faces() -> void:
	for entry in LANTERN_MONK_FACE_CASES:
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition := _lantern_monk_definition(card_id)
		_check(not definition.is_empty(), "Lantern Monk catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "lantern_monk",
			"authored Lantern Monk owner: " + card_id)
		_check(str(definition.get("target_kind", "")) == str(entry["target"]),
			"authored target stays the named one: " + card_id)
		if lantern_monk_starter.has_card(card_id):
			_check(effects.get("blind") is int and int(effects["blind"]) == 1,
				"authored starter Blind is the integer one: " + card_id)
			_check(not effects.has("blind_next_attack"),
				"the starter record authors one Blind spelling: " + card_id)
		else:
			_check(effects.get("blind_next_attack") is bool
				and bool(effects["blind_next_attack"]),
				"authored pool Blind is the boolean true: " + card_id)
			_check(not effects.has("blind"),
				"the pool record authors one Blind spelling: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(CardShortRules.has_unknown(definition) == bool(entry.get("unknown", false)),
			"a valid Blind alone never triggers the fallback: " + card_id)
		_check(bool(described.get("unknown", false)) == bool(entry.get("unknown", false)),
			"fallback expectation follows the shipped record: %s (%s)" % [card_id, line])
		_check(line.count("Blind") == 1,
			"exactly one Blind clause: %s (%s)" % [card_id, line])
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		var blind_at := line.find("Blind")
		if effects.get("damage") is int:
			_check(line.begins_with("Deal %d." % int(effects["damage"])),
				"face damage equals the authored amount: " + card_id)
			_check(blind_at > line.find("Deal"),
				"Blind follows the damage clause: " + card_id)
		else:
			_check(not line.begins_with("Deal"),
				"a record with no authored damage prints none: " + card_id)
		if effects.get("exposed") is int:
			_check(line.contains("Exposed %d." % int(effects["exposed"])),
				"face Exposed equals the authored amount: " + card_id)
			_check(blind_at > line.find("Exposed"),
				"Blind follows the status clause: " + card_id)
		if effects.get("draw") is int:
			_check(line.contains("Draw %d." % int(effects["draw"])),
				"face Draw equals the authored amount: " + card_id)
			_check(blind_at < line.find("Draw"),
				"Blind precedes the Draw clause: " + card_id)
		if bool(entry.get("unknown", false)):
			_check(line.ends_with(UNKNOWN_FALLBACK),
				"the unsupported sibling keeps its fallback: " + card_id)
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(not line.to_lower().contains("turn"),
			"the face prints no Blind duration: %s (%s)" % [card_id, line])
		_check(CardShortRules.line(_lantern_monk_definition(card_id)) == expected_line,
			"repeated formatting is identical: " + card_id)
		_check(definition == before and _lantern_monk_definition(card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		var detached := _lantern_monk_definition(card_id)
		var detached_effects: Dictionary = detached.get("effects", {})
		detached_effects["blind"] = 0
		detached_effects["blind_next_attack"] = false
		_check(_lantern_monk_definition(card_id) == before,
			"catalog lookups stay detached from the formatter: " + card_id)


## AC3: only the two strict authored Blind spellings print, and only on an enemy
## recipient. Every other shape keeps the honest fallback, invents no keyword,
## never mutates its probe and never touches a shipped record.
func _test_blind_malformed_fallbacks() -> void:
	for value: Variant in [0, 2, "1", true, -1, 1.0]:
		var probe := {"id": "card_short_rules_bad_blind", "owner": "lantern_monk",
			"target_kind": "enemy_single", "effects": {"damage": 2, "blind": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
			"a malformed Blind %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Blind"), "no Blind is invented for %s" % str(value))
		_check(probe == before, "the malformed Blind probe is never mutated: " + str(value))
	for value: Variant in [false, 1, "true", 0]:
		var probe := {"id": "card_short_rules_bad_blind_next_attack",
			"owner": "lantern_monk", "target_kind": "enemy_single",
			"effects": {"damage": 2, "blind_next_attack": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
			"a malformed blind_next_attack %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Blind"),
			"no Blind is invented for blind_next_attack %s" % str(value))
		_check(probe == before,
			"the malformed next-attack probe is never mutated: " + str(value))
	# A strict payload on a self or ally recipient never borrows an enemy Blind.
	for target: String in ["self", "ally_single", "party_all"]:
		for effects: Dictionary in [{"blind": 1}, {"blind_next_attack": true}]:
			var probe := {"id": "card_short_rules_wrong_target",
				"owner": "lantern_monk", "target_kind": target, "effects": effects}
			var before := probe.duplicate(true)
			var line := CardShortRules.line(probe)
			_check(line == UNKNOWN_FALLBACK,
				"a Blind on %s falls back honestly: %s" % [target, line])
			_check(not line.contains("Blind"),
				"no Blind is printed for a %s recipient" % target)
			_check(probe == before, "the wrong-target probe is never mutated: " + target)
	# Both authored spellings at once are ambiguous, so neither is chosen.
	var both := {"id": "card_short_rules_both_blind", "owner": "lantern_monk",
		"target_kind": "enemy_single",
		"effects": {"damage": 2, "blind": 1, "blind_next_attack": true}}
	var both_before := both.duplicate(true)
	var both_line := CardShortRules.line(both)
	_check(both_line == "Deal 2. " + UNKNOWN_FALLBACK,
		"two conflicting Blind spellings fall back honestly: " + both_line)
	_check(not both_line.contains("Blind"), "no Blind is guessed from two spellings")
	_check(both == both_before, "the conflicting-spellings probe is never mutated")
	# A genuine Blind beside an unsupported sibling prints only the Blind and
	# keeps the honest fallback for the other effect.
	var sibling := {"id": "card_short_rules_blind_sibling", "owner": "lantern_monk",
		"target_kind": "enemy_single",
		"effects": {"blind": 1, "mystery_status": 9}}
	var sibling_before := sibling.duplicate(true)
	var sibling_line := CardShortRules.line(sibling)
	_check(sibling_line == "Blind. " + UNKNOWN_FALLBACK,
		"a valid Blind beside an unsupported sibling: " + sibling_line)
	_check(sibling_line.count("Blind") == 1 and not sibling_line.contains("9"),
		"the unsupported sibling invents no Blind and leaks no amount")
	_check(sibling == sibling_before, "the sibling probe is never mutated")
	# Formatting the malformed probes cannot reach into a shipped record.
	var snuff := lantern_monk_pool.get_definition("lantern_monk_snuff_flame")
	var snuff_before := snuff.duplicate(true)
	CardShortRules.line(both)
	CardShortRules.line(sibling)
	_check(not snuff.is_empty() and snuff == snuff_before,
		"malformed probes cannot alter a shipped Lantern Monk record")


## One detached record from the real V3 catalog named by the fixture.
func _authored_definition(catalog_id: String, card_id: String) -> Dictionary:
	match catalog_id:
		"rag_duelist_starter":
			return rag_duelist_starter.get_definition(card_id)
		"rag_duelist_pool":
			return rag_duelist.get_definition(card_id)
		"lantern_monk_pool":
			return lantern_monk_pool.get_definition(card_id)
	return {}


## AC1: the six authored one-shot Dodge records print their exact terse face,
## read from the real V3 catalogs by named ID (never a catalog total or ID list).
## Each record's owner, recipient and descriptor are checked first, so an empty
## or unrelated record cannot pass. The wording is proven to be a printed design
## statement only: it claims no live enemy attack is cancelled.
func _test_dodge_faces() -> void:
	for entry in DODGE_FACE_CASES:
		var catalog_id := str(entry["catalog"])
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition := _authored_definition(catalog_id, card_id)
		_check(not definition.is_empty(),
			"authored Dodge catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == str(entry["owner"]),
			"authored Dodge owner: " + card_id)
		_check(str(definition.get("target_kind", "")) == str(entry["target"]),
			"authored Dodge recipient: " + card_id)
		_check(effects.get("dodge_next_attack") is int
			and int(effects["dodge_next_attack"]) == 1,
			"authored Dodge is exactly the integer one: " + card_id)
		if effects.has("duration"):
			_check(effects["duration"] is int and int(effects["duration"]) == 1,
				"authored Dodge duration is the one-shot one: " + card_id)
		if entry.has("block"):
			_check(effects.get("block") is int
				and int(effects["block"]) == int(entry["block"]),
				"authored ally Block read from the catalog: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true))
			and not CardShortRules.has_unknown(definition),
			"a genuine Dodge needs no fallback: %s (%s)" % [card_id, line])
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		_check(line.count("Dodge") + line.count("dodges") == 1,
			"exactly one Dodge clause: %s (%s)" % [card_id, line])
		_check(not line.to_lower().contains("turn"),
			"the face invents no Dodge duration: %s (%s)" % [card_id, line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		var lowered := line.to_lower()
		_check(not lowered.contains("cancel") and not lowered.contains("miss")
			and not lowered.contains("pile") and not lowered.contains("discard"),
			"the face claims no live Dodge rule: %s (%s)" % [card_id, line])
		_check(definition == before
			and _authored_definition(catalog_id, card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(_authored_definition(catalog_id, card_id))
			== expected_line, "repeated formatting is identical: " + card_id)
		_check(CardShortRules.line(definition) == expected_line,
			"formatting the same record twice is identical: " + card_id)


## AC2: the two real Moth Cloud records keep their one-shot Blind phrase and now
## name their authentic `exhaust: true` honestly, yielding exactly
## "Blind to all. Exhaust." The face claims no live discard or exhaust pile: the
## sentence only prints the authored card descriptor.
func _test_moth_cloud_exhaust() -> void:
	for pair in [["lantern_monk_moth_cloud", 2], ["lantern_monk_moth_cloud_plus", 1]]:
		var card_id := str(pair[0])
		var definition := lantern_monk_pool.get_definition(card_id)
		_check(not definition.is_empty(),
			"Moth Cloud catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "lantern_monk",
			"authored Moth Cloud owner: " + card_id)
		_check(str(definition.get("target_kind", "")) == "enemy_all",
			"authored Moth Cloud target stays every enemy: " + card_id)
		_check(int(definition.get("cost", -1)) == int(pair[1]),
			"authored Moth Cloud cost: " + card_id)
		_check(effects.get("blind_next_attack") is bool
			and bool(effects["blind_next_attack"]),
			"authored Moth Cloud Blind is the boolean true: " + card_id)
		_check(effects.get("exhaust") is bool and bool(effects["exhaust"]),
			"authored Moth Cloud exhaust is the boolean true: " + card_id)
		var before := definition.duplicate(true)
		var line := CardShortRules.line(definition)
		_check(line == "Blind to all. Exhaust.",
			"short face for %s: got '%s'" % [card_id, line])
		_check(line.find("Blind") < line.find("Exhaust"),
			"Exhaust follows the Blind sentence: %s (%s)" % [card_id, line])
		_check(not line.contains(UNKNOWN_FALLBACK)
			and not CardShortRules.has_unknown(definition),
			"the authored exhaust key is now described honestly: " + card_id)
		var lowered := line.to_lower()
		_check(not lowered.contains("pile") and not lowered.contains("discard")
			and not lowered.contains("after use"),
			"the face claims no live exhaust transaction: %s (%s)" % [card_id, line])
		_check(definition == before
			and lantern_monk_pool.get_definition(card_id) == before,
			"formatting never mutates Moth Cloud: " + card_id)
		_check(CardShortRules.line(lantern_monk_pool.get_definition(card_id))
			== "Blind to all. Exhaust.", "repeated formatting is identical: " + card_id)


## AC3: every unsupported Dodge/Exhaust shape keeps the honest fallback. Adding
## the two keys to KNOWN_EFFECT_KEYS must not turn a malformed value or a wrong
## recipient into a valid effect, so each probe still reports unknown and prints
## no Dodge/Exhaust phrase. Nothing here promises a live evade or exhaust pile.
func _test_dodge_and_exhaust_malformed() -> void:
	# A genuine self Dodge is the positive control for every negative below.
	var genuine := {"id": "card_short_rules_dodge_control", "target_kind": "self",
		"effects": {"dodge_next_attack": 1}}
	_check(CardShortRules.line(genuine) == "Dodge the next attack.",
		"the duration-less self Dodge is the positive control")
	for value: Variant in [0, 2, -1, true, false, "1", 1.0]:
		var probe := {"id": "card_short_rules_bad_dodge", "target_kind": "self",
			"effects": {"dodge_next_attack": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == UNKNOWN_FALLBACK,
			"a malformed Dodge %s falls back honestly: %s" % [str(value), line])
		_check(not line.to_lower().contains("dodge"),
			"no Dodge phrase is invented for %s" % str(value))
		_check(bool(CardShortRules.describe(probe).get("unknown", false)),
			"a known key with an unsupported shape still reports unknown: " + str(value))
		_check(probe == before,
			"the malformed Dodge probe is never mutated: " + str(value))
	# A genuine integer one on the wrong recipient is not a self/ally Dodge.
	for target: String in ["enemy_single", "enemy_all", "enemy_random", "party_all"]:
		var probe := {"id": "card_short_rules_dodge_wrong_target",
			"target_kind": target, "effects": {"dodge_next_attack": 1}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == UNKNOWN_FALLBACK,
			"a Dodge on %s falls back honestly: %s" % [target, line])
		_check(not line.to_lower().contains("dodge"),
			"no Dodge phrase is printed for a %s recipient" % target)
		_check(probe == before,
			"the wrong-target Dodge probe is never mutated: " + target)
	# The optional duration must still be the authored one turn when present.
	for case in [["integer 2", 2], ["integer 0", 0], ["text", "1"],
			["float", 1.0], ["true", true]]:
		var probe := {"id": "card_short_rules_dodge_bad_duration",
			"target_kind": "self",
			"effects": {"dodge_next_attack": 1, "duration": case[1]}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == UNKNOWN_FALLBACK,
			"a Dodge with a %s duration falls back honestly: %s" % [str(case[0]), line])
		_check(not line.to_lower().contains("dodge"),
			"no Dodge phrase is printed for a %s duration" % str(case[0]))
		_check(probe == before,
			"the %s duration probe is never mutated" % str(case[0]))
	# Exhaust is only the boolean true, proven beside the real Moth Cloud context.
	for value: Variant in [0, 1, -1, false, "true", 1.0]:
		var probe := {"id": "card_short_rules_bad_exhaust", "owner": "lantern_monk",
			"target_kind": "enemy_all",
			"effects": {"blind_next_attack": true, "exhaust": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Blind to all. " + UNKNOWN_FALLBACK,
			"a malformed exhaust %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Exhaust"),
			"no Exhaust sentence is invented for %s" % str(value))
		_check(bool(CardShortRules.describe(probe).get("unknown", false)),
			"a known exhaust key with an unsupported value still reports unknown: "
			+ str(value))
		_check(probe == before,
			"the malformed exhaust probe is never mutated: " + str(value))
	# Two genuine descriptors print two short sentences, in the fixed order.
	var combined := {"id": "card_short_rules_dodge_exhaust_ok",
		"target_kind": "self",
		"effects": {"dodge_next_attack": 1, "duration": 1, "exhaust": true}}
	var combined_before := combined.duplicate(true)
	_check(CardShortRules.line(combined) == "Dodge the next attack. Exhaust.",
		"a genuine Dodge and Exhaust print two short sentences")
	_check(combined == combined_before, "the combined probe is never mutated")
	# Formatting the malformed probes cannot reach into a shipped record.
	var slip := rag_duelist_starter.get_definition("rag_duelist_cape_slip")
	var slip_before := slip.duplicate(true)
	var cloud := lantern_monk_pool.get_definition("lantern_monk_moth_cloud")
	var cloud_before := cloud.duplicate(true)
	CardShortRules.line(genuine)
	CardShortRules.line(combined)
	_check(not slip.is_empty() and slip == slip_before
		and rag_duelist_starter.get_definition("rag_duelist_cape_slip") == slip_before,
		"malformed probes cannot alter a shipped Cape Slip record")
	_check(not cloud.is_empty() and cloud == cloud_before
		and lantern_monk_pool.get_definition("lantern_monk_moth_cloud") == cloud_before,
		"malformed probes cannot alter a shipped Moth Cloud record")


## AC1: all six authored Dodge variants receive exactly one Dodge Help row that
## states the shipped one-shot rule: the next incoming attack HIT against the real
## living recipient misses once, Warden Guard redirection picks that recipient, a
## skipped or downed target keeps its own token, one of several multi-hits is
## avoided, and an unused Dodge expires at the hero's owner-turn end. The row must
## not claim live Dodge is unwired, nor that every hit or turn is negated.
func _test_dodge_help() -> void:
	var cases := [
		{"catalog": rag_duelist_starter, "id": "rag_duelist_cape_slip", "owner": "rag_duelist", "target": "self"},
		{"catalog": rag_duelist_starter, "id": "rag_duelist_cape_slip_plus", "owner": "rag_duelist", "target": "self"},
		{"catalog": rag_duelist, "id": "rag_duelist_cape_flourish", "owner": "rag_duelist", "target": "self"},
		{"catalog": rag_duelist, "id": "rag_duelist_cape_flourish_plus", "owner": "rag_duelist", "target": "self"},
		{"catalog": lantern_monk_pool, "id": "lantern_monk_moth_shroud", "owner": "lantern_monk", "target": "ally_single"},
		{"catalog": lantern_monk_pool, "id": "lantern_monk_moth_shroud_plus", "owner": "lantern_monk", "target": "ally_single"},
	]
	var shared_text := ""
	for case: Dictionary in cases:
		var catalog: Variant = case["catalog"]
		var card_id: String = str(case["id"])
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "Dodge Help catalog exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == str(case["owner"])
			and str(definition.get("target_kind", "")) == str(case["target"]),
			"Dodge owner/target: " + card_id)
		_check(effects.get("dodge_next_attack") is int
			and int(effects["dodge_next_attack"]) == 1,
			"authored Dodge descriptor: " + card_id)
		# Moth Shroud keeps its own authored ally Block beside the Dodge.
		if str(case["target"]) == "ally_single":
			var expected_block := 8 if card_id.ends_with("_plus") else 6
			_check(effects.get("block") is int
				and int(effects["block"]) == expected_block,
				"Moth Shroud keeps its authored ally Block %d: %s" % [expected_block, card_id])
		var rows := CardKeywordGlossary.describe(definition)
		var dodge_rows: Array[Dictionary] = []
		for row: Dictionary in rows:
			if str(row.get("keyword", "")) == "Dodge":
				dodge_rows.append(row)
		_check(dodge_rows.size() == 1,
			"exactly one Dodge Help row for %s (got %d)" % [card_id, dodge_rows.size()])
		if dodge_rows.size() == 1:
			var text: String = str(dodge_rows[0].get("explanation", ""))
			if shared_text.is_empty():
				shared_text = text
			_check(not shared_text.is_empty() and text == shared_text,
				"one canonical Dodge explanation serves every authored variant: " + card_id)
			_check(text.contains("next incoming attack HIT")
				and text.contains("misses once"),
				"Dodge Help states one next incoming attack HIT misses once: " + card_id)
			_check(text.contains("who actually receives it")
				and text.contains("that hero's Dodge is spent on it"),
				"Dodge Help spends the real recipient's token: " + card_id)
			_check(text.contains("one-shot") and text.contains("never a stack")
				and text.contains("never a number of turns"),
				"Dodge Help keeps the one-shot versus duration distinction: " + card_id)
			_check(text.contains("Warden Guard redirection decides who really receives")
				and text.contains("receiving hero's Dodge is the one spent"),
				"Dodge Help states Guard redirection selects the spent token: " + card_id)
			_check(text.contains("skipped or downed target keeps its own"),
				"Dodge Help keeps a bypassed hero's token armed: " + card_id)
			_check(text.contains("several separate hit attempts")
				and text.contains("one Dodge avoids one of those hits")
				and text.contains("not all of them"),
				"Dodge Help limits a Dodge to one of several multi-hits: " + card_id)
			_check(text.contains("expires at that hero's owner-turn end"),
				"Dodge Help states the owner-turn expiry of an unused token: " + card_id)
			_check(text.contains("Live combat already applies this")
				and text.contains("before any damage lands"),
				"Dodge Help states the shipped live attack consumption: " + card_id)
			_check(not text.contains("does not yet") and not text.contains("not yet apply")
				and not text.contains("design description only"),
				"Dodge Help drops the false unwired disclaimer: " + card_id)
			_check(not text.contains("avoids every hit") and not text.contains("all hits"),
				"Dodge Help never claims every multi-hit or turn is negated: " + card_id)
	_check(not shared_text.is_empty(), "the Dodge Help row was really inspected")


## AC2: both Moth Cloud variants keep Blind first, then exactly one Exhaust row.
func _test_exhaust_help() -> void:
	for pair in [["lantern_monk_moth_cloud", 2], ["lantern_monk_moth_cloud_plus", 1]]:
		var card_id := str(pair[0])
		var definition: Dictionary = lantern_monk_pool.get_definition(card_id)
		_check(not definition.is_empty(), "Moth Cloud catalog exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "lantern_monk"
			and str(definition.get("target_kind", "")) == "enemy_all",
			"Moth Cloud owner/target: " + card_id)
		_check(effects.get("blind_next_attack") is bool
			and bool(effects["blind_next_attack"]),
			"Moth Cloud has Blind: " + card_id)
		_check(effects.get("exhaust") is bool and bool(effects["exhaust"]),
			"Moth Cloud has Exhaust: " + card_id)
		var rows := CardKeywordGlossary.describe(definition)
		var names: Array[String] = []
		for row: Dictionary in rows:
			names.append(str(row.get("keyword", "")))
		# Blind (keyword row) must come first, then Exhaust (special row).
		_check(names.has("Blind"), "Moth Cloud has Blind keyword: " + card_id)
		_check(names.has("Exhaust"), "Moth Cloud has Exhaust special: " + card_id)
		if names.has("Blind") and names.has("Exhaust"):
			var blind_idx := names.find("Blind")
			var exhaust_idx := names.find("Exhaust")
			_check(blind_idx < exhaust_idx,
				"Blind comes before Exhaust for %s" % card_id)
		var exhaust_rows: Array[Dictionary] = []
		for row: Dictionary in rows:
			if str(row.get("keyword", "")) == "Exhaust":
				exhaust_rows.append(row)
		_check(exhaust_rows.size() == 1,
			"exactly one Exhaust Help row for %s" % card_id)
		if exhaust_rows.size() == 1:
			var text: String = str(exhaust_rows[0].get("explanation", ""))
			_check(text.contains("one-play removal") or text.contains("draw/discard cycle"),
				"Exhaust Help mentions removal cycle: " + card_id)
			_check(text.contains("not a normal discard") or text.contains("redrawn"),
				"Exhaust Help denies normal discard: " + card_id)
			_check(text.contains("design-only") or text.contains("live combat does not yet apply"),
				"Exhaust Help disclaims live combat: " + card_id)


## AC3: invalid, mis-owned, partial and forged descriptors never borrow
## a Dodge/Exhaust row; existing keyword/special order stays unchanged.
func _test_dodge_exhaust_negative() -> void:
	# Wrong ID / owner / target.
	var bad_id := {"id": "rag_duelist_fake", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(bad_id).is_empty(),
		"forged Dodge ID stays silent")
	var bad_owner := {"id": "rag_duelist_cape_slip", "owner": "seamstress",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(bad_owner).is_empty(),
		"mis-owned Dodge stays silent")
	var bad_target := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "enemy_single", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(bad_target).is_empty(),
		"wrong Dodge target stays silent")
	# Wrong descriptor values.
	var bad_value := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 0, "duration": 1}}
	_check(CardKeywordGlossary.describe(bad_value).is_empty(),
		"zero Dodge value stays silent")
	var bad_bool := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": true}}
	_check(CardKeywordGlossary.describe(bad_bool).is_empty(),
		"boolean Dodge value stays silent (missing duration)")
	var bad_text := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": "1"}}
	_check(CardKeywordGlossary.describe(bad_text).is_empty(),
		"text Dodge value stays silent")
	var bad_duration := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 2}}
	_check(CardKeywordGlossary.describe(bad_duration).is_empty(),
		"wrong Dodge duration stays silent")
	# Partial Rag records: correct ID/owner/target but missing/altered duration.
	var missing_duration := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(missing_duration).is_empty(),
		"Rag Dodge missing duration stays silent")
	# Partial Rag records: wrong cost for base/plus.
	var wrong_cost_base := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 0, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(wrong_cost_base).is_empty(),
		"Rag base Dodge wrong cost stays silent")
	var wrong_cost_plus := {"id": "rag_duelist_cape_slip_plus", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(wrong_cost_plus).is_empty(),
		"Rag plus Dodge wrong cost stays silent")
	# Partial Rag records: wrong from_positions.
	var wrong_from := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(wrong_from).is_empty(),
		"Rag Dodge wrong from_positions stays silent")
	# Partial Rag records: non-empty to_positions.
	var wrong_to := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [1],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(wrong_to).is_empty(),
		"Rag Dodge non-empty to_positions stays silent")
	# Rag Dodge with an extra effect flag.
	var extra_effect := {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1, "block": 3}}
	_check(CardKeywordGlossary.describe(extra_effect).is_empty(),
		"Rag Dodge with an extra effect stays silent")
	# Moth Shroud: missing block.
	var missing_block := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(missing_block).is_empty(),
		"Moth Shroud Dodge missing block stays silent")
	# Moth Shroud: wrong block value.
	var wrong_block := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 5, "dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(wrong_block).is_empty(),
		"Moth Shroud wrong block value stays silent")
	# Moth Shroud plus: wrong block value.
	var wrong_block_plus := {"id": "lantern_monk_moth_shroud_plus", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 7, "dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(wrong_block_plus).is_empty(),
		"Moth Shroud plus wrong block value stays silent")
	# Moth Shroud: wrong cost.
	var wrong_cost_shroud := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(wrong_cost_shroud).is_empty(),
		"Moth Shroud wrong cost stays silent")
	# Moth Shroud: wrong from_positions.
	var wrong_from_shroud := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(wrong_from_shroud).is_empty(),
		"Moth Shroud wrong from_positions stays silent")
	# Moth Shroud: non-empty to_positions.
	var wrong_to_shroud := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [1],
		"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": 1}}
	_check(CardKeywordGlossary.describe(wrong_to_shroud).is_empty(),
		"Moth Shroud non-empty to_positions stays silent")
	# Moth Shroud: extra effect flag.
	var extra_shroud := {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [],
		"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": 1, "duration": 1}}
	_check(CardKeywordGlossary.describe(extra_shroud).is_empty(),
		"Moth Shroud with an extra effect stays silent")
	# Partial Dodge records: each required authored field omitted in turn.
	var partial_dodges := [
		{"label": "Rag Dodge without cost",
			"record": {"id": "rag_duelist_cape_flourish", "owner": "rag_duelist",
				"from_positions": [1, 2, 3], "to_positions": [], "target_kind": "self",
				"effects": {"dodge_next_attack": 1, "duration": 1}}},
		{"label": "Rag Dodge without from_positions",
			"record": {"id": "rag_duelist_cape_flourish_plus", "owner": "rag_duelist",
				"cost": 0, "to_positions": [], "target_kind": "self",
				"effects": {"dodge_next_attack": 1, "duration": 1}}},
		{"label": "Rag Dodge without to_positions",
			"record": {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
				"cost": 1, "from_positions": [1, 2, 3], "target_kind": "self",
				"effects": {"dodge_next_attack": 1, "duration": 1}}},
		{"label": "Rag Dodge without target_kind",
			"record": {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
				"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
				"effects": {"dodge_next_attack": 1, "duration": 1}}},
		{"label": "Rag Dodge with float dodge count",
			"record": {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
				"cost": 1, "from_positions": [1, 2, 3], "to_positions": [],
				"target_kind": "self", "effects": {"dodge_next_attack": 1.0, "duration": 1}}},
		{"label": "Rag Dodge with float cost",
			"record": {"id": "rag_duelist_cape_slip", "owner": "rag_duelist",
				"cost": 1.0, "from_positions": [1, 2, 3], "to_positions": [],
				"target_kind": "self", "effects": {"dodge_next_attack": 1, "duration": 1}}},
		{"label": "Moth Shroud without dodge",
			"record": {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
				"cost": 1, "from_positions": [2, 3], "to_positions": [],
				"target_kind": "ally_single", "effects": {"block": 6}}},
		{"label": "Moth Shroud without cost",
			"record": {"id": "lantern_monk_moth_shroud_plus", "owner": "lantern_monk",
				"from_positions": [2, 3], "to_positions": [], "target_kind": "ally_single",
				"effects": {"block": 8, "dodge_next_attack": 1}}},
		{"label": "Moth Shroud without from_positions",
			"record": {"id": "lantern_monk_moth_shroud", "owner": "lantern_monk",
				"cost": 1, "to_positions": [], "target_kind": "ally_single",
				"effects": {"block": 6, "dodge_next_attack": 1}}},
		{"label": "Moth Shroud plus without to_positions",
			"record": {"id": "lantern_monk_moth_shroud_plus", "owner": "lantern_monk",
				"cost": 1, "from_positions": [2, 3], "target_kind": "ally_single",
				"effects": {"block": 8, "dodge_next_attack": 1}}},
		{"label": "Moth Shroud with StringName owner",
			"record": {"id": "lantern_monk_moth_shroud", "owner": &"lantern_monk",
				"cost": 1, "from_positions": [2, 3], "to_positions": [],
				"target_kind": "ally_single", "effects": {"block": 6, "dodge_next_attack": 1}}},
	]
	for entry: Dictionary in partial_dodges:
		var record: Dictionary = entry["record"]
		var before_record := record.duplicate(true)
		_check(not _has_keyword_row(record, "Dodge"), str(entry["label"]) + " stays silent")
		_check(record == before_record, str(entry["label"]) + " is never mutated")
	# Exhaust negatives.
	var bad_exhaust_false := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": false}}
	var bad_exhaust_false_rows := CardKeywordGlossary.describe(bad_exhaust_false)
	var bad_exhaust_false_has_exhaust := false
	for row: Dictionary in bad_exhaust_false_rows:
		if str(row.get("keyword", "")) == "Exhaust":
			bad_exhaust_false_has_exhaust = true
	_check(not bad_exhaust_false_has_exhaust, "false Exhaust stays silent")
	var bad_exhaust_missing_blind := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"exhaust": true}}
	_check(CardKeywordGlossary.describe(bad_exhaust_missing_blind).is_empty(),
		"missing Moth Cloud Blind stays silent")
	var bad_exhaust_text := {"id": "lantern_monk_moth_cloud_plus", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": "true"}}
	var bad_exhaust_text_rows := CardKeywordGlossary.describe(bad_exhaust_text)
	var bad_exhaust_text_has_exhaust := false
	for row: Dictionary in bad_exhaust_text_rows:
		if str(row.get("keyword", "")) == "Exhaust":
			bad_exhaust_text_has_exhaust = true
	_check(not bad_exhaust_text_has_exhaust, "text Exhaust value stays silent")
	# Moth Cloud: wrong cost for base/plus. Blind is valid, so no row should be empty;
	# instead, no Exhaust row is produced.
	var wrong_cost_cloud_base := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": true}}
	var wrong_cost_cloud_base_has_exhaust := false
	for row: Dictionary in CardKeywordGlossary.describe(wrong_cost_cloud_base):
		if str(row.get("keyword", "")) == "Exhaust":
			wrong_cost_cloud_base_has_exhaust = true
	_check(not wrong_cost_cloud_base_has_exhaust, "Moth Cloud base wrong cost stays silent")
	var wrong_cost_cloud_plus := {"id": "lantern_monk_moth_cloud_plus", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": true}}
	var wrong_cost_cloud_plus_has_exhaust := false
	for row: Dictionary in CardKeywordGlossary.describe(wrong_cost_cloud_plus):
		if str(row.get("keyword", "")) == "Exhaust":
			wrong_cost_cloud_plus_has_exhaust = true
	_check(not wrong_cost_cloud_plus_has_exhaust, "Moth Cloud plus wrong cost stays silent")
	# Moth Cloud: wrong from_positions.
	var wrong_from_cloud := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [1, 2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": true}}
	var wrong_from_cloud_has_exhaust := false
	for row: Dictionary in CardKeywordGlossary.describe(wrong_from_cloud):
		if str(row.get("keyword", "")) == "Exhaust":
			wrong_from_cloud_has_exhaust = true
	_check(not wrong_from_cloud_has_exhaust, "Moth Cloud wrong from_positions stays silent")
	# Moth Cloud: wrong to_positions.
	var wrong_to_cloud := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": true}}
	var wrong_to_cloud_has_exhaust := false
	for row: Dictionary in CardKeywordGlossary.describe(wrong_to_cloud):
		if str(row.get("keyword", "")) == "Exhaust":
			wrong_to_cloud_has_exhaust = true
	_check(not wrong_to_cloud_has_exhaust, "Moth Cloud wrong to_positions stays silent")
	# Moth Cloud: wrong target_kind. Using a non-enemy target, so Blind also fails.
	var bad_target_cloud := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "self", "effects": {"blind_next_attack": true, "exhaust": true}}
	_check(CardKeywordGlossary.describe(bad_target_cloud).is_empty(),
		"Moth Cloud wrong target stays silent")
	# Moth Cloud: extra effect flag.
	var extra_cloud := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "exhaust": true, "draw": 1}}
	var extra_cloud_has_exhaust := false
	for row: Dictionary in CardKeywordGlossary.describe(extra_cloud):
		if str(row.get("keyword", "")) == "Exhaust":
			extra_cloud_has_exhaust = true
	_check(not extra_cloud_has_exhaust, "Moth Cloud with an extra effect stays silent")
	# Moth Cloud: conflicting duplicate Blind spelling.
	var conflicting_blind := {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
		"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind_next_attack": true, "blind": 1, "exhaust": true}}
	_check(CardKeywordGlossary.describe(conflicting_blind).is_empty(),
		"Moth Cloud with conflicting Blind spelling stays silent")
	var conflicting_blind_plus := {"id": "lantern_monk_moth_cloud_plus", "owner": "lantern_monk",
		"cost": 1, "from_positions": [2, 3], "to_positions": [1, 2, 3],
		"target_kind": "enemy_all", "effects": {"blind": 1, "exhaust": true}}
	_check(not _has_keyword_row(conflicting_blind_plus, "Exhaust"),
		"Moth Cloud plus with only the count Blind spelling stays silent")
	# Partial Moth Cloud records: each required authored field omitted in turn.
	var partial_clouds := [
		{"label": "Moth Cloud without cost",
			"record": {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
				"from_positions": [2, 3], "to_positions": [1, 2, 3], "target_kind": "enemy_all",
				"effects": {"blind_next_attack": true, "exhaust": true}}},
		{"label": "Moth Cloud plus without from_positions",
			"record": {"id": "lantern_monk_moth_cloud_plus", "owner": "lantern_monk",
				"cost": 1, "to_positions": [1, 2, 3], "target_kind": "enemy_all",
				"effects": {"blind_next_attack": true, "exhaust": true}}},
		{"label": "Moth Cloud without to_positions",
			"record": {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
				"cost": 2, "from_positions": [2, 3], "target_kind": "enemy_all",
				"effects": {"blind_next_attack": true, "exhaust": true}}},
		{"label": "Moth Cloud without target_kind",
			"record": {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
				"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
				"effects": {"blind_next_attack": true, "exhaust": true}}},
		{"label": "Moth Cloud with StringName target",
			"record": {"id": "lantern_monk_moth_cloud", "owner": "lantern_monk",
				"cost": 2, "from_positions": [2, 3], "to_positions": [1, 2, 3],
				"target_kind": &"enemy_all",
				"effects": {"blind_next_attack": true, "exhaust": true}}},
		{"label": "Moth Cloud with extra Blind flag key",
			"record": {"id": "lantern_monk_moth_cloud_plus", "owner": "lantern_monk",
				"cost": 1, "from_positions": [2, 3], "to_positions": [1, 2, 3],
				"target_kind": "enemy_all",
				"effects": {"blind_next_attack": true, "exhaust": true, "blind": 1}}},
	]
	for entry: Dictionary in partial_clouds:
		var record: Dictionary = entry["record"]
		var before_record := record.duplicate(true)
		_check(not _has_keyword_row(record, "Exhaust"), str(entry["label"]) + " stays silent")
		_check(record == before_record, str(entry["label"]) + " is never mutated")
	# Existing special-rule order is preserved.
	_check(CardKeywordGlossary.SPECIAL_ORDER == ["conditional_damage", "random_hit",
		"energy_tradeoff", "bleed_doubling", "two_hits", "dodge", "exhaust"],
		"new special rules appended without reshuffling existing five")
	# Existing keyword rows unchanged.
	_check(CardKeywordGlossary.KEYWORD_ORDER == ["bleed", "weak", "exposed", "pinned",
		"unravel", "guarding", "thorns", "riposte", "tangled", "blind", "fear"],
		"keyword order unchanged")


## One detached record from the real Scarecrow catalogs named by a fixture.
func _scarecrow_definition(catalog_id: String, card_id: String) -> Dictionary:
	match catalog_id:
		"starter":
			return scarecrow_starter.get_definition(card_id)
		"pool":
			return scarecrow_pool.get_definition(card_id)
	return {}


## The same lookup without naming the catalog, for the base/'+' pair checks.
func _scarecrow_any_definition(card_id: String) -> Dictionary:
	if scarecrow_starter.has_card(card_id):
		return scarecrow_starter.get_definition(card_id)
	if scarecrow_pool.has_card(card_id):
		return scarecrow_pool.get_definition(card_id)
	return {}


## True when the shipped shared-hand area-action script dispatches this card ID in
## one of its authored family lists (read from the real script, never a stand-in).
func _live_area_handles(card_id: String) -> bool:
	var script: GDScript = load("res://scripts/live_area_attack_action.gd")
	if script == null:
		return false
	var constants := script.get_script_constant_map()
	for family in ["CROW_IDS", "HARVEST_IDS", "CROW_FLOCK_IDS"]:
		var ids: Variant = constants.get(family, [])
		if ids is Array and card_id in ids:
			return true
	return false


func _row_names(rows: Array[Dictionary]) -> Array[String]:
	var names: Array[String] = []
	for row: Dictionary in rows:
		names.append(str(row.get("keyword", "")))
	return names


func _rows_named(rows: Array[Dictionary], keyword: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for row: Dictionary in rows:
		if str(row.get("keyword", "")) == keyword:
			found.append(row)
	return found


## The one Fear Help explanation, or "" when the record earns no Fear row.
func _fear_text(definition: Dictionary) -> String:
	var rows := _rows_named(CardKeywordGlossary.describe(definition), "Fear")
	return str(rows[0].get("explanation", "")) if rows.size() == 1 else ""


## AC1: the eight authentic Scarecrow Fear printings show their authored Weak
## (and Harvest Fright's damage) with exactly one Fear keyword for one enemy or
## every enemy, and no generic unknown sentence. Read from the real starter and
## pool catalogs by named ID, never a catalog total or an ordered ID list.
func _test_scarecrow_fear_faces() -> void:
	for entry in SCARECROW_FEAR_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition := _scarecrow_definition(catalog, card_id)
		_check(not definition.is_empty(),
			"Scarecrow Fear catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "scarecrow",
			"authored Scarecrow owner: " + card_id)
		_check(int(definition.get("cost", -1)) == int(entry["cost"]),
			"authored Fear cost: " + card_id)
		_check(str(definition.get("target_kind", "")) == str(entry["target"]),
			"authored Fear recipient: " + card_id)
		_check(effects.get("cannot_buff_next_turn") is bool
			and bool(effects["cannot_buff_next_turn"]),
			"authored Fear flag is the boolean true: " + card_id)
		_check(effects.get("weak") is int
			and int(effects["weak"]) == int(entry["weak"]),
			"authored Weak read from the catalog: " + card_id)
		if int(entry["damage"]) > 0:
			_check(effects.get("damage") is int
				and int(effects["damage"]) == int(entry["damage"]),
				"authored Fear damage read from the catalog: " + card_id)
		else:
			_check(not effects.has("damage"),
				"a no-damage Fear card prints none: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true))
			and not CardShortRules.has_unknown(definition),
			"a genuine Fear needs no fallback: %s (%s)" % [card_id, line])
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		_check(line.count("Fear") == 1,
			"exactly one Fear keyword: %s (%s)" % [card_id, line])
		_check(line.count("Weak") == 1,
			"exactly one Weak clause: %s (%s)" % [card_id, line])
		_check(line.find("Weak") < line.find("Fear"),
			"Fear is printed after Weak: %s (%s)" % [card_id, line])
		if int(entry["damage"]) > 0:
			_check(line.begins_with("Deal %d" % int(entry["damage"]))
				and line.find("Deal") < line.find("Weak"),
				"the authored damage leads the face: %s (%s)" % [card_id, line])
		if str(entry["target"]) == "enemy_all":
			_check(line.contains("Fear to all."),
				"area Fear names every enemy: " + card_id)
		else:
			_check(not line.contains("to all") and line.ends_with("Fear."),
				"single-enemy Fear names one enemy only: " + card_id)
		_check(not line.to_lower().contains("turn")
			and not line.contains("buff") and not line.contains("25%"),
			"the face leaves the buff lock to Help: %s (%s)" % [card_id, line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(definition == before
			and _scarecrow_definition(catalog, card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(_scarecrow_definition(catalog, card_id))
			== expected_line, "repeated formatting is identical: " + card_id)


## AC2: Help explains Fear once per authentic record: the buff lock covers only
## the NEXT enemy turn and then expires, the separate Weak carries the authored
## stacks, and upgrades raise Weak rather than the lock. The keyword order keeps
## every existing row in place with Fear appended last.
## AC1: the same row never repeats the obsolete claim that the Scarecrow cannot
## be in a live party; it names the Scarecrow as one of the eight selectable
## heroes that may join any three-hero party, and truthfully says all eight Fear
## printings play from the shared hand: the single-target Sack Glare/Grin pair and
## the all-foe Crow Flock and Harvest Fright through their own area handler.
func _test_scarecrow_fear_help() -> void:
	var keyword_order := CardKeywordGlossary.KEYWORD_ORDER
	_check(keyword_order.count("fear") == 1
		and keyword_order[keyword_order.size() - 1] == "fear"
		and keyword_order.slice(0, keyword_order.size() - 1) == ["bleed", "weak",
			"exposed", "pinned", "unravel", "guarding", "thorns", "riposte",
			"tangled", "blind"],
		"Fear is one appended keyword row after the existing rows: "
		+ str(keyword_order))
	var shared_text := ""
	for entry in SCARECROW_FEAR_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var definition := _scarecrow_definition(catalog, card_id)
		_check(not definition.is_empty(), "Fear Help catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "scarecrow"
			and int(definition.get("cost", -1)) == int(entry["cost"])
			and str(definition.get("target_kind", "")) == str(entry["target"])
			and effects.get("cannot_buff_next_turn") is bool
			and bool(effects["cannot_buff_next_turn"]),
			"Fear Help only reads an authentic printing: " + card_id)
		_check(CardShortRules.is_authored_fear(definition),
			"the face and Help share one Fear authority: " + card_id)
		var expected_from: Array = [2, 3] if card_id.begins_with("scarecrow_crow_flock") \
			else [1, 2, 3]
		_check(Array(definition.get("from_positions", [])) == expected_from
			and Array(definition.get("to_positions", [])) == [1, 2, 3],
			"authored Fear hero and enemy positions match the Help: " + card_id)
		_check(_live_area_handles(card_id) == (str(entry["target"]) == "enemy_all"),
			"the live area-action path dispatches exactly the all-foe Fear cards: "
			+ card_id)
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == ["Weak %d" % int(entry["weak"]), "Fear"],
			"Help keeps the Weak row then one Fear row: %s (%s)"
			% [card_id, str(names)])
		var fear_rows := _rows_named(rows, "Fear")
		_check(fear_rows.size() == 1,
			"exactly one Fear Help row for %s (got %d)" % [card_id, fear_rows.size()])
		if fear_rows.size() == 1:
			var text := str(fear_rows[0].get("explanation", ""))
			if shared_text.is_empty():
				shared_text = text
			_check(text == shared_text,
				"one compact Fear row serves every authentic printing: " + card_id)
			_check(text.contains("cannot buff on its NEXT enemy turn"),
				"Fear Help states the next-turn buff lock: " + card_id)
			_check(text.contains("expires at the end of that turn")
				and text.contains("never covers a second turn"),
				"Fear Help states the one-turn expiry: " + card_id)
			_check(text.contains("never lengthen"),
				"Fear Help says upgrades never lengthen the lock: " + card_id)
			_check(text.contains("separate Weak") and text.contains("25%"),
				"Fear Help states Weak is an independent 25 percent reduction: "
				+ card_id)
			_check(text.contains("Sack Glare, Sack Grin and Crow Flock author "
				+ "Weak 1 on the base card and Weak 2 on the upgraded card"),
				"Fear Help states the authored Weak 1/2: " + card_id)
			_check(text.contains("Harvest Fright authors Weak 2 on the base card "
				+ "and Weak 3 on the upgraded card"),
				"Fear Help states Harvest Fright's Weak 2/3: " + card_id)
			_check(text.contains("adds no damage, Bleed or Blind"),
				"Fear Help is not extra damage, Bleed or Blind: " + card_id)
			_check(text.contains("All eight Fear printings are playable from the shared hand")
				and text.contains("apply this Fear lock in battle, base and '+' alike")
				and text.contains("Sack Glare and Sack Grin cost 1 energy from hero positions 1-3")
				and text.contains("target one living enemy in positions 1-3"),
				"Fear Help names the playable single-target sack families: " + card_id)
			_check(text.contains("Crow Flock costs 2 energy from hero positions 2-3")
				and text.contains("Harvest Fright costs 3 energy from hero positions 1-3")
				and text.contains("area cards played through the shared-hand area-card action"),
				"Fear Help names the live area families, costs and positions: " + card_id)
			_check(text.contains("Crow Flock applies Weak and Fear, with no damage, to every "
					+ "living enemy in slots 1-3")
				and text.contains("Harvest Fright first hits every living enemy in slots 1-3 "
					+ "for 4 damage (6 upgraded), then applies Weak and Fear only to the "
					+ "survivors"),
				"Fear Help states the all-foe effects and survivors-only Fear: " + card_id)
			_check(not text.contains("does not play them")
				and not text.contains("not yet applied")
				and not text.contains("not applied by that"),
				"Fear Help never claims the area families are unwired: " + card_id)
			_check(not text.contains("sack-card path")
				and not text.contains("sack handler"),
				"Fear Help does not imply the sack handler plays area cards: " + card_id)
			_check(not text.contains("no held card resolves Fear"),
				"Fear Help no longer denies every held Fear card: " + card_id)
			_check(not text.contains("not yet part of a live party")
				and not text.contains("not part of a live party")
				and not text.contains("not yet in a live party"),
				"Fear Help never calls the Scarecrow unavailable to a live party: "
				+ card_id)
			_check(text.contains("one of the eight selectable heroes")
				and text.contains("any three-hero party"),
				"Fear Help names the Scarecrow as a selectable party hero: "
				+ card_id)
			_check(not text.contains("buff lock for 2")
				and not text.contains("2 turns"),
				"Fear Help never turns the lock into a duration: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Fear Help reads are identical: " + card_id)
		_check(definition == before
			and _scarecrow_definition(catalog, card_id) == before,
			"Help never mutates the shipped Fear record: " + card_id)
		var detached := CardKeywordGlossary.describe(definition)
		if detached.size() == 2:
			detached[1]["keyword"] = "Tampered"
			detached[1]["explanation"] = "Tampered"
			_check(_row_names(CardKeywordGlossary.describe(definition))
				== ["Weak %d" % int(entry["weak"]), "Fear"],
				"Fear Help rows are detached from the caller's record: " + card_id)
	_check(not shared_text.is_empty(), "the Fear Help row was really inspected")
	# AC2: the shared explanation itself carries the corrected live-party fact
	# and names the playable sack and area families instead of denying any
	# held Fear card.
	_check(not CardKeywordGlossary.FEAR_EXPLANATION.contains("not yet part of a live party")
		and not CardKeywordGlossary.FEAR_EXPLANATION.contains("not part of a live party"),
		"the Fear explanation carries no unselectable-live-party claim")
	_check(not CardKeywordGlossary.FEAR_EXPLANATION.contains("no held card resolves Fear")
		and CardKeywordGlossary.FEAR_EXPLANATION.contains("Sack Glare and Sack Grin cost 1 energy")
		and CardKeywordGlossary.FEAR_EXPLANATION.contains("playable from the shared hand"),
		"the Fear explanation names the playable held sack variants")
	_check(CardKeywordGlossary.FEAR_EXPLANATION.contains("Crow Flock costs 2 energy")
		and CardKeywordGlossary.FEAR_EXPLANATION.contains("Harvest Fright costs 3 energy")
		and not CardKeywordGlossary.FEAR_EXPLANATION.contains("not yet applied"),
		"the Fear explanation names the live area families")
	# The base and '+' halves differ only in the authored Weak (and Harvest
	# Fright's damage): the one-turn lock is never the upgraded number.
	for pair in [["scarecrow_sack_glare", "scarecrow_sack_glare_plus"],
			["scarecrow_sack_grin", "scarecrow_sack_grin_plus"],
			["scarecrow_crow_flock", "scarecrow_crow_flock_plus"],
			["scarecrow_harvest_fright", "scarecrow_harvest_fright_plus"]]:
		var base_id := str(pair[0])
		var plus_id := str(pair[1])
		var base := _scarecrow_any_definition(base_id)
		var plus := _scarecrow_any_definition(plus_id)
		_check(not base.is_empty() and not plus.is_empty(),
			"both Fear variants exist: " + base_id)
		if base.is_empty() or plus.is_empty():
			continue
		var weak_base := int(base.get("effects", {}).get("weak", -1))
		var weak_plus := int(plus.get("effects", {}).get("weak", -1))
		_check(weak_plus == weak_base + 1 and weak_plus > 0,
			"the upgrade raises only the authored Weak: " + base_id)
		_check(not _fear_text(base).is_empty() and _fear_text(base) == _fear_text(plus),
			"the upgrade never changes the one-turn Fear rule: " + base_id)


## AC3: false, wrong-type and misplaced Fear flags, forged owner/ID, altered
## structure and unsupported companion effects never invent Fear on the face or in
## Help. The honest unknown fallback and the preexisting Blind/Dodge/Exhaust
## behaviour stay exactly as they were.
func _test_scarecrow_fear_negative() -> void:
	var glare := _scarecrow_definition("starter", "scarecrow_sack_glare")
	var fright := _scarecrow_definition("pool", "scarecrow_harvest_fright")
	_check(not glare.is_empty() and not fright.is_empty()
		and CardShortRules.line(glare) == "Weak 1. Fear."
		and CardShortRules.line(fright) == "Deal 4 to all. Weak 2 to all. Fear to all.",
		"the authentic Fear records are the positive controls")
	for case in [["boolean false", false], ["numeric one", 1], ["null", null],
			["text", "true"], ["float", 1.0]]:
		var probe := glare.duplicate(true)
		var probe_effects: Dictionary = probe["effects"]
		probe_effects["cannot_buff_next_turn"] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_fear(probe),
			"a %s Fear flag is not an authored Fear" % str(case[0]))
		var line := CardShortRules.line(probe)
		_check(not line.contains("Fear"),
			"no Fear keyword is invented for a %s flag: %s" % [str(case[0]), line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"a %s flag keeps the honest fallback: %s" % [str(case[0]), line])
		_check(not _has_keyword_row(probe, "Fear"),
			"no Fear Help row for a %s flag" % str(case[0]))
		_check(probe == before, "the %s flag probe is never mutated" % str(case[0]))
	for target: String in ["self", "ally_single", "party_all"]:
		var probe := glare.duplicate(true)
		probe["target_kind"] = target
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_fear(probe),
			"a true Fear flag on %s is not the authored enemy printing" % target)
		var line := CardShortRules.line(probe)
		_check(not line.contains("Fear"),
			"no Fear is printed for a %s recipient: %s" % [target, line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"a %s recipient keeps the honest fallback: %s" % [target, line])
		_check(not _has_keyword_row(probe, "Fear"),
			"no Fear Help row for a %s recipient" % target)
		_check(probe == before, "the %s recipient probe is never mutated" % target)
	for owner: Variant in ["warden", &"scarecrow", null]:
		var probe := glare.duplicate(true)
		probe["owner"] = owner
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_fear(probe)
			and not line.contains("Fear")
			and line.ends_with(UNKNOWN_FALLBACK)
			and not _has_keyword_row(probe, "Fear"),
			"a %s owner never borrows Fear: %s" % [str(owner), line])
		_check(probe == before, "the %s owner probe is never mutated" % str(owner))
	# Forged ID, altered structure and altered authored amounts.
	var structural := [
		["forged ID", "id", "scarecrow_forged_glare"],
		["wrong cost", "cost", 2],
	]
	for case in structural:
		var probe := glare.duplicate(true)
		probe[case[1]] = case[2]
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_fear(probe)
			and not line.contains("Fear") and line.ends_with(UNKNOWN_FALLBACK),
			"a %s never borrows Fear: %s" % [str(case[0]), line])
		_check(not _has_keyword_row(probe, "Fear"),
			"a %s adds no Fear Help row" % str(case[0]))
		_check(probe == before, "the %s probe is never mutated" % str(case[0]))
	for case in [["from_positions", [1, 2]], ["to_positions", [1, 2]],
			["from_positions", null], ["to_positions", null]]:
		var probe := glare.duplicate(true)
		probe[case[0]] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_fear(probe)
			and not CardShortRules.line(probe).contains("Fear")
			and not _has_keyword_row(probe, "Fear"),
			"a Fear record with %s %s stays silent"
			% [str(case[0]), str(case[1])])
		_check(probe == before,
			"the %s %s probe is never mutated" % [str(case[0]), str(case[1])])
	var wrong_weak := glare.duplicate(true)
	var wrong_weak_effects: Dictionary = wrong_weak["effects"]
	wrong_weak_effects["weak"] = 3
	var wrong_damage := fright.duplicate(true)
	var wrong_damage_effects: Dictionary = wrong_damage["effects"]
	wrong_damage_effects["damage"] = 5
	var missing_weak := glare.duplicate(true)
	var missing_weak_effects: Dictionary = missing_weak["effects"]
	missing_weak_effects.erase("weak")
	for probe: Dictionary in [wrong_weak, wrong_damage, missing_weak]:
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_fear(probe)
			and not line.contains("Fear") and line.ends_with(UNKNOWN_FALLBACK),
			"an altered authored amount never borrows Fear: " + line)
		_check(not _has_keyword_row(probe, "Fear"),
			"an altered authored amount adds no Fear Help row: " + line)
		_check(probe == before, "an altered amount probe is never mutated: " + line)
	# A genuine Fear beside an unsupported extra effect (or a supported extra
	# that the authentic printing does not author) keeps the honest fallback.
	for extra in [["unsupported", "mystery_status", 9, ""], ["supported", "draw", 1, "Draw 1."]]:
		var sibling := glare.duplicate(true)
		var sibling_effects: Dictionary = sibling["effects"]
		sibling_effects[str(extra[1])] = extra[2]
		var before := sibling.duplicate(true)
		var line := CardShortRules.line(sibling)
		_check(not CardShortRules.is_authored_fear(sibling)
			and not line.contains("Fear") and line.ends_with(UNKNOWN_FALLBACK),
			"a Fear sibling with an extra %s effect stays honest: %s"
			% [str(extra[0]), line])
		if str(extra[3]).is_empty():
			_check(not line.contains(str(extra[2])),
				"the extra %s effect's amount never leaks: %s" % [str(extra[0]), line])
		else:
			_check(not line.contains("Fear") and line.contains(str(extra[3])),
				"the extra %s effect prints only its own clause: %s"
				% [str(extra[0]), line])
		_check(not _has_keyword_row(sibling, "Fear"),
			"the extra %s effect adds no Fear Help row" % str(extra[0]))
		_check(sibling == before,
			"the extra %s effect probe is never mutated" % str(extra[0]))
	# The flag alone, without the authored printing, is still an honest unknown
	# rather than a quietly empty face.
	var bare := {"id": "scarecrow_sack_glare", "owner": "scarecrow", "cost": 1,
		"target_kind": "enemy_single", "from_positions": [1, 2, 3],
		"to_positions": [1, 2, 3], "effects": {"cannot_buff_next_turn": true}}
	_check(CardShortRules.has_unknown(bare)
		and CardShortRules.line(bare) == UNKNOWN_FALLBACK
		and not CardShortRules.is_authored_fear(bare),
		"a bare Fear flag stays honestly undescribed")
	# The existing keyword rows are untouched by the new flag.
	var cloud := lantern_monk_pool.get_definition("lantern_monk_moth_cloud")
	_check(CardShortRules.line(cloud) == "Blind to all. Exhaust."
		and _has_keyword_row(cloud, "Blind") and _has_keyword_row(cloud, "Exhaust")
		and not _has_keyword_row(cloud, "Fear"),
		"the existing Moth Cloud Blind/Exhaust Help is unchanged")
	var slip := rag_duelist_starter.get_definition("rag_duelist_cape_slip")
	_check(CardShortRules.line(slip) == "Dodge the next attack."
		and _has_keyword_row(slip, "Dodge") and not _has_keyword_row(slip, "Fear"),
		"the existing Cape Slip Dodge Help is unchanged")
	for entry in SCARECROW_FEAR_CASES:
		var card_id := str(entry["id"])
		var definition := _scarecrow_definition(str(entry["catalog"]), card_id)
		var names := _row_names(CardKeywordGlossary.describe(definition))
		_check(not definition.is_empty()
			and not names.has("Blind") and not names.has("Dodge")
			and not names.has("Exhaust"),
			"a genuine Fear card borrows no other keyword Help row: " + card_id)
	# Malformed probes cannot reach into the shipped catalogs.
	var glare_after := _scarecrow_definition("starter", "scarecrow_sack_glare")
	var fright_after := _scarecrow_definition("pool", "scarecrow_harvest_fright")
	_check(glare_after == glare and fright_after == fright
		and CardShortRules.line(glare_after) == "Weak 1. Fear.",
		"the malformed probes cannot alter the shipped Scarecrow records")


## AC1: the four authentic Scarecrow shoulder-crow printings show their authored damage
## (Crow Dive 3/5, Crow Peck 4/6), name the backmost living enemy, and say that the strike
## ignores Block ("Pierce Block."), with no generic unknown-effect warning.
func _test_scarecrow_crow_faces() -> void:
	for entry in SCARECROW_CROW_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition := _scarecrow_definition(catalog, card_id)
		_check(not definition.is_empty(),
			"Scarecrow crow catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "scarecrow",
			"authored Scarecrow owner: " + card_id)
		_check(int(definition.get("cost", -1)) == int(entry["cost"]),
			"authored crow cost: " + card_id)
		_check(str(definition.get("target_kind", "")) == str(entry["target"]),
			"authored crow recipient: " + card_id)
		_check(effects.get("ignore_block") is bool and bool(effects["ignore_block"]),
			"authored ignore_block flag is the boolean true: " + card_id)
		_check(effects.get("damage") is int
			and int(effects["damage"]) == int(entry["damage"]),
			"authored damage read from the catalog: " + card_id)
		_check(CardShortRules.is_authored_block_pierce(definition),
			"card short rules recognizes authentic crow definition: " + card_id)
		_check(CardShortRules.is_authored_crow(definition),
			"crow alias recognizes authentic crow definition: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true))
			and not CardShortRules.has_unknown(definition),
			"an authentic crow printing needs no fallback: %s (%s)" % [card_id, line])
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		_check(line.count("Pierce Block") == 1,
			"exactly one Pierce Block clause: %s (%s)" % [card_id, line])
		_check(line.contains("to the backmost living enemy"),
			"face names the backmost living enemy: %s (%s)" % [card_id, line])
		_check(line.begins_with("Deal %d" % int(entry["damage"])),
			"authored damage leads the face: %s (%s)" % [card_id, line])
		_check(line.find("Deal") < line.find("Pierce Block"),
			"Pierce Block follows damage: %s (%s)" % [card_id, line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(definition == before
			and _scarecrow_definition(catalog, card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(_scarecrow_definition(catalog, card_id))
			== expected_line, "repeated formatting is identical: " + card_id)


## AC2: Help explains the authentic shoulder crow strike once per record: the
## backmost LIVING enemy is selected, damage reduces HP without consuming Block,
## and Weak/Exposed/Tangled still adjust damage.
func _test_scarecrow_crow_help() -> void:
	var shared_text := ""
	for entry in SCARECROW_CROW_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var definition := _scarecrow_definition(catalog, card_id)
		_check(not definition.is_empty(), "Crow Help catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		_check(_live_area_handles(card_id)
			and Array(definition.get("from_positions", [])) == [1, 2, 3]
			and int(definition.get("cost", -1)) == 1,
			"the live area-action path plays the 1-energy crow card from 1-3: " + card_id)
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == ["Pierce Block"],
			"Help produces exactly one Pierce Block row: %s (%s)" % [card_id, str(names)])
		var crow_rows := _rows_named(rows, "Pierce Block")
		_check(crow_rows.size() == 1,
			"exactly one Pierce Block row for %s (got %d)" % [card_id, crow_rows.size()])
		if crow_rows.size() == 1:
			var text := str(crow_rows[0].get("explanation", ""))
			if shared_text.is_empty():
				shared_text = text
			_check(text == shared_text,
				"one compact Pierce Block row serves every authentic crow printing: " + card_id)
			_check(text.contains("backmost living enemy"),
				"Crow Help states backmost living enemy: " + card_id)
			_check(text.contains("HP") and text.contains("Block")
				and (text.contains("without consuming") or text.contains("without reducing")),
				"Crow Help explains HP reduction without consuming Block: " + card_id)
			_check(text.contains("Weak") and text.contains("Exposed") and text.contains("Tangled"),
				"Crow Help confirms Weak/Exposed/Tangled adjustments: " + card_id)
			_check(text.contains("Crow Dive (3 damage, 5 upgraded)")
				and text.contains("Crow Peck (4 damage, 6 upgraded)")
				and text.contains("cost 1 energy")
				and text.contains("hero positions 1-3")
				and text.contains("through the shared-hand area-card action")
				and text.contains("choose their target automatically"),
				"Crow Help states the real playable area-action path: " + card_id)
			_check(not text.contains("does not yet play")
				and not text.contains("authored card rule only")
				and not text.contains("not yet"),
				"Crow Help drops the obsolete unwired disclaimer: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Crow Help reads are identical: " + card_id)
		_check(definition == before
			and _scarecrow_definition(catalog, card_id) == before,
			"Help never mutates the shipped Crow record: " + card_id)
		var detached := CardKeywordGlossary.describe(definition)
		if detached.size() == 1:
			detached[0]["keyword"] = "Tampered"
			detached[0]["explanation"] = "Tampered"
			_check(_row_names(CardKeywordGlossary.describe(definition)) == ["Pierce Block"],
				"Crow Help rows are detached from caller mutations: " + card_id)
	_check(not shared_text.is_empty(), "the Pierce Block Help row was inspected")


## AC3: malformed or forged ignore_block records (wrong owner/ID/cost/recipient/positions,
## wrong damage, extra effect, non-boolean flag, broken upgrade link) do not borrow the
## Pierce Block face or Help wording; preserve honest unknown-effect fallback and immutability.
func _test_scarecrow_crow_negative() -> void:
	var dive := _scarecrow_definition("starter", "scarecrow_crow_dive")
	var peck := _scarecrow_definition("pool", "scarecrow_crow_peck")
	_check(not dive.is_empty() and not peck.is_empty()
		and CardShortRules.line(dive) == "Deal 3 to the backmost living enemy. Pierce Block."
		and CardShortRules.line(peck) == "Deal 4 to the backmost living enemy. Pierce Block.",
		"the authentic crow records are the positive controls")
	# Non-boolean / false / numeric / text ignore_block flags
	for case in [["boolean false", false], ["numeric one", 1], ["null", null],
			["text", "true"], ["float", 1.0]]:
		var probe := dive.duplicate(true)
		var probe_effects: Dictionary = probe["effects"]
		probe_effects["ignore_block"] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_block_pierce(probe),
			"a %s ignore_block flag is not an authored crow strike" % str(case[0]))
		var line := CardShortRules.line(probe)
		_check(not line.contains("Pierce Block"),
			"no Pierce Block clause is invented for a %s flag: %s" % [str(case[0]), line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"a %s flag keeps the honest fallback: %s" % [str(case[0]), line])
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"no Pierce Block Help row for a %s flag" % str(case[0]))
		_check(probe == before, "the %s flag probe is never mutated" % str(case[0]))
	# Wrong target_kind
	for target: String in ["enemy_single", "enemy_all", "enemy_random", "self", "ally_single", "party_all"]:
		var probe := dive.duplicate(true)
		probe["target_kind"] = target
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_block_pierce(probe),
			"a true ignore_block on %s is not an authored crow strike" % target)
		var line := CardShortRules.line(probe)
		_check(not line.contains("Pierce Block"),
			"no Pierce Block for a %s recipient: %s" % [target, line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"a %s recipient keeps the honest fallback: %s" % [target, line])
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"no Pierce Block Help row for a %s recipient" % target)
		_check(probe == before, "the %s recipient probe is never mutated" % target)
	# Wrong owner
	for owner: Variant in ["warden", "tinker", &"scarecrow", null]:
		var probe := dive.duplicate(true)
		probe["owner"] = owner
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_block_pierce(probe)
			and not line.contains("Pierce Block")
			and line.ends_with(UNKNOWN_FALLBACK)
			and not _has_keyword_row(probe, "Pierce Block"),
			"a %s owner never borrows Pierce Block: %s" % [str(owner), line])
		_check(probe == before, "the %s owner probe is never mutated" % str(owner))
	# Forged ID, wrong cost
	var structural := [
		["forged ID", "id", "scarecrow_crow_dive_forged"],
		["wrong cost", "cost", 2],
		["zero cost", "cost", 0],
	]
	for case in structural:
		var probe := dive.duplicate(true)
		probe[case[1]] = case[2]
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_block_pierce(probe)
			and not line.contains("Pierce Block") and line.ends_with(UNKNOWN_FALLBACK),
			"a %s never borrows Pierce Block: %s" % [str(case[0]), line])
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"a %s adds no Pierce Block Help row" % str(case[0]))
		_check(probe == before, "the %s probe is never mutated" % str(case[0]))
	# Wrong positions
	for case in [["from_positions", [1, 2]], ["to_positions", [1, 2]],
			["from_positions", [2, 3]], ["to_positions", [2, 3]],
			["from_positions", null], ["to_positions", null]]:
		var probe := dive.duplicate(true)
		probe[case[0]] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_block_pierce(probe)
			and not CardShortRules.line(probe).contains("Pierce Block")
			and not _has_keyword_row(probe, "Pierce Block"),
			"a crow record with %s %s stays silent" % [str(case[0]), str(case[1])])
		_check(probe == before,
			"the %s %s probe is never mutated" % [str(case[0]), str(case[1])])
	# Wrong damage
	var wrong_damage_dive := dive.duplicate(true)
	wrong_damage_dive["effects"]["damage"] = 4
	var wrong_damage_peck := peck.duplicate(true)
	wrong_damage_peck["effects"]["damage"] = 3
	var missing_damage := dive.duplicate(true)
	missing_damage["effects"].erase("damage")
	for probe: Dictionary in [wrong_damage_dive, wrong_damage_peck, missing_damage]:
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_block_pierce(probe)
			and not line.contains("Pierce Block") and line.ends_with(UNKNOWN_FALLBACK),
			"an altered damage amount never borrows Pierce Block: " + line)
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"an altered damage amount adds no Pierce Block Help row: " + line)
		_check(probe == before, "an altered damage probe is never mutated: " + line)
	# Extra effect keys (unsupported and supported)
	for extra in [["unsupported", "mystery_status", 9, ""], ["supported", "weak", 1, "Weak 1"]]:
		var sibling := dive.duplicate(true)
		var sibling_effects: Dictionary = sibling["effects"]
		sibling_effects[str(extra[1])] = extra[2]
		var before := sibling.duplicate(true)
		var line := CardShortRules.line(sibling)
		_check(not CardShortRules.is_authored_block_pierce(sibling)
			and not line.contains("Pierce Block") and line.ends_with(UNKNOWN_FALLBACK),
			"a crow sibling with extra %s effect stays honest: %s" % [str(extra[0]), line])
		_check(not _has_keyword_row(sibling, "Pierce Block"),
			"extra %s effect adds no Pierce Block Help row" % str(extra[0]))
		_check(sibling == before, "extra %s probe is never mutated" % str(extra[0]))
	# Broken base/+ upgrade relationships
	var broken_upgrade_base := dive.duplicate(true)
	broken_upgrade_base.erase("upgrade_id")
	var broken_upgrade_of_base := dive.duplicate(true)
	broken_upgrade_of_base["upgrade_of"] = "scarecrow_crow_peck"
	var broken_upgrade_plus := _scarecrow_definition("starter", "scarecrow_crow_dive_plus")
	var broken_upgrade_plus_missing := broken_upgrade_plus.duplicate(true)
	broken_upgrade_plus_missing.erase("upgrade_of")
	var broken_upgrade_plus_with_id := broken_upgrade_plus.duplicate(true)
	broken_upgrade_plus_with_id["upgrade_id"] = "scarecrow_crow_dive_plus_plus"
	for probe: Dictionary in [broken_upgrade_base, broken_upgrade_of_base,
			broken_upgrade_plus_missing, broken_upgrade_plus_with_id]:
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_block_pierce(probe)
			and not line.contains("Pierce Block") and line.ends_with(UNKNOWN_FALLBACK),
			"broken upgrade link never borrows Pierce Block: " + line)
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"broken upgrade link adds no Pierce Block Help row")
		_check(probe == before, "broken upgrade probe is never mutated")
	# Detached canonical field-set negative probes: deleted/changed display_name,
	# changed reward_eligible or rarity, extra top-level field, changed illustration,
	# or changed starting copies must all fail authentication and preserve fallback.
	var canonical_probes := [
		["deleted display_name on dive", dive.duplicate(true), "erase", "display_name", null],
		["changed display_name on dive", dive.duplicate(true), "set", "display_name", "Crow Strike"],
		["deleted display_name on peck", peck.duplicate(true), "erase", "display_name", null],
		["changed display_name on peck", peck.duplicate(true), "set", "display_name", "Peck"],
		["changed reward_eligible on dive", dive.duplicate(true), "set", "reward_eligible", true],
		["changed reward_eligible on peck", peck.duplicate(true), "set", "reward_eligible", false],
		["changed rarity on peck", peck.duplicate(true), "set", "rarity", "rare"],
		["deleted rarity on peck", peck.duplicate(true), "erase", "rarity", null],
		["extra rarity on dive", dive.duplicate(true), "set", "rarity", "common"],
		["extra top-level field on dive", dive.duplicate(true), "set", "unexpected_field", "forgery"],
		["extra top-level field on peck", peck.duplicate(true), "set", "forged_flag", true],
		["changed illustration_path on dive", dive.duplicate(true), "set", "illustration_path", "res://other.png"],
		["changed starting_copies on dive", dive.duplicate(true), "set", "starting_copies", 2],
		["changed starting_copies on peck", peck.duplicate(true), "set", "starting_copies", 1],
	]
	for case_def in canonical_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var action: String = str(case_def[2])
		var key: String = str(case_def[3])
		if action == "erase":
			probe.erase(key)
		else:
			probe[key] = case_def[4]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_block_pierce(probe),
			"%s fails is_authored_block_pierce" % label)
		_check(not CardShortRules.is_authored_crow(probe),
			"%s fails is_authored_crow" % label)
		_check(CardShortRules.has_unknown(probe),
			"%s reports has_unknown true" % label)
		var line := CardShortRules.line(probe)
		_check(not line.contains("Pierce Block"),
			"no Pierce Block on face for %s: %s" % [label, line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"honest unknown fallback on face for %s: %s" % [label, line])
		_check(not _has_keyword_row(probe, "Pierce Block"),
			"no Pierce Block Help row for %s" % label)
		_check(probe == before, "%s probe is never mutated" % label)
	# Shipped records are untouched
	var dive_after := _scarecrow_definition("starter", "scarecrow_crow_dive")
	var peck_after := _scarecrow_definition("pool", "scarecrow_crow_peck")
	_check(dive_after == dive and peck_after == peck
		and CardShortRules.line(dive_after) == "Deal 3 to the backmost living enemy. Pierce Block."
		and CardShortRules.line(peck_after) == "Deal 4 to the backmost living enemy. Pierce Block.",
		"malformed probes cannot alter shipped Scarecrow records")


## One detached record from the real V3 Seamstress catalogs named by a fixture.
func _seamstress_tether_definition(catalog: String, card_id: String) -> Dictionary:
	match catalog:
		"starter":
			return v3_seamstress_starter.get_definition(card_id)
		"pool":
			return v3_seamstress_pool.get_definition(card_id)
	return {}


## AC1: the four authentic V3 Seamstress Tether printings print their explicit
## 'two living enemies / 50% of later confirmed HP loss' rule with no unknown fallback
## and no instant damage printed.
func _test_seamstress_tether_faces() -> void:
	for entry in TETHER_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition := _seamstress_tether_definition(catalog, card_id)
		_check(not definition.is_empty(),
			"Seamstress Tether catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(str(definition.get("owner", "")) == "seamstress",
			"authored Seamstress owner: " + card_id)
		_check(int(definition.get("cost", -1)) == int(entry["cost"]),
			"authored Tether cost %d: %s" % [int(entry["cost"]), card_id])
		_check(str(definition.get("target_kind", "")) == "enemy_pair",
			"authored Tether target_kind is enemy_pair: " + card_id)
		_check(Array(definition.get("from_positions", [])) == [2, 3],
			"authored Tether from_positions is [2, 3]: " + card_id)
		_check(Array(definition.get("to_positions", [])) == [1, 2, 3],
			"authored Tether to_positions is [1, 2, 3]: " + card_id)
		_check(effects == {"tether_share_percent": 50},
			"authored Tether effects is exactly {tether_share_percent: 50}: " + card_id)
		_check(not effects.has("damage"),
			"Tether authors no direct damage rider: " + card_id)
		_check(CardShortRules.is_authored_tether(definition),
			"card short rules recognizes authentic Tether definition: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true))
			and not CardShortRules.has_unknown(definition),
			"an authentic Tether printing needs no fallback: %s (%s)" % [card_id, line])
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		_check(line.contains("Link 2 living enemies"),
			"face states two living enemies: %s (%s)" % [card_id, line])
		_check(line.contains("Echo 50% of a later confirmed hit's HP loss"),
			"face states 50%% later confirmed HP loss echo: %s (%s)" % [card_id, line])
		_check(not line.to_lower().contains("deal") and not line.to_lower().contains("damage"),
			"face claims no instant damage: %s (%s)" % [card_id, line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(definition == before
			and _seamstress_tether_definition(catalog, card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(_seamstress_tether_definition(catalog, card_id))
			== expected_line, "repeated formatting is identical: " + card_id)


## AC2: Help explains the authentic two-foe Tether link once per record: two distinct
## living targets, zero immediate damage, floor(50% of positive HP loss) echo on a later
## confirmed attack, secondary Block absorbing before HP, no echo on fully blocked hits,
## and non-recursive echo.
func _test_seamstress_tether_help() -> void:
	var shared_text := ""
	for entry in TETHER_CASES:
		var catalog := str(entry["catalog"])
		var card_id := str(entry["id"])
		var definition := _seamstress_tether_definition(catalog, card_id)
		_check(not definition.is_empty(), "Tether Help catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		var names := _row_names(rows)
		_check(names == ["Tether"],
			"Help produces exactly one Tether row: %s (%s)" % [card_id, str(names)])
		var tether_rows := _rows_named(rows, "Tether")
		_check(tether_rows.size() == 1,
			"exactly one Tether row for %s (got %d)" % [card_id, tether_rows.size()])
		if tether_rows.size() == 1:
			var text := str(tether_rows[0].get("explanation", ""))
			if shared_text.is_empty():
				shared_text = text
			_check(text == shared_text,
				"one compact Tether row serves every authentic Tether printing: " + card_id)
			_check(text.contains("two distinct living enemies"),
				"Tether Help states two distinct living enemies: " + card_id)
			_check(text.contains("zero immediate damage"),
				"Tether Help states zero immediate damage on play: " + card_id)
			_check(text.contains("later confirmed hit")
				and text.contains("positive HP loss")
				and (text.contains("50%") or text.contains("half"))
				and text.contains("rounded down"),
				"Tether Help explains floor-half positive HP loss on later confirmed hit: " + card_id)
			_check(text.contains("Block absorbing before HP")
				or (text.contains("Block") and text.contains("before HP")),
				"Tether Help explains partner Block absorbs before HP: " + card_id)
			_check(text.contains("wholly absorbed by Block")
				or text.contains("no echo"),
				"Tether Help explains wholly Block-absorbed hit causes no echo: " + card_id)
			_check(text.contains("not a separate card attack")
				and (text.contains("cannot trigger another echo") or text.contains("cannot spawn another echo")),
				"Tether Help explains non-recursive echo: " + card_id)
			_check(text.contains("authored rules helper")
				or text.contains("pure helper")
				or text.contains("Tether Stitch"),
				"Tether Help preserves helper scope without false live claims: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Tether Help reads are identical: " + card_id)
		_check(definition == before
			and _seamstress_tether_definition(catalog, card_id) == before,
			"Help never mutates the shipped Tether record: " + card_id)
		var detached := CardKeywordGlossary.describe(definition)
		if detached.size() == 1:
			detached[0]["keyword"] = "Tampered"
			detached[0]["explanation"] = "Tampered"
			_check(_row_names(CardKeywordGlossary.describe(definition)) == ["Tether"],
				"Tether Help rows are detached from caller mutations: " + card_id)
	_check(not shared_text.is_empty(), "the Tether Help row was inspected")


## AC3: malformed or forged tether_share_percent records (wrong owner/ID/cost/recipient/positions,
## wrong share percent, extra effect, non-int share, broken upgrade link, changed catalog fields)
## do not borrow the Tether face or Help wording; preserve honest unknown-effect fallback and immutability.
func _test_seamstress_tether_negative() -> void:
	var loop := _seamstress_tether_definition("starter", "seamstress_v3_tether_loop")
	var stitch := _seamstress_tether_definition("pool", "seamstress_v3_tether_stitch")
	_check(not loop.is_empty() and not stitch.is_empty()
		and CardShortRules.line(loop) == "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss."
		and CardShortRules.line(stitch) == "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss.",
		"the authentic Tether records are the positive controls")

	# Wrong tether_share_percent amounts and types
	for case in [["100 percent", 100], ["zero percent", 0], ["negative", -50],
			["text 50", "50"], ["float 50", 50.0], ["boolean true", true],
			["null", null]]:
		var probe := loop.duplicate(true)
		probe["effects"]["tether_share_percent"] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe),
			"a %s tether_share_percent is not an authored Tether card" % str(case[0]))
		var line := CardShortRules.line(probe)
		_check(not line.contains("Echo 50%") and not line.contains("Link 2 living enemies"),
			"no Tether clause on face for %s: %s" % [str(case[0]), line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"a %s keeps the honest fallback: %s" % [str(case[0]), line])
		_check(not _has_keyword_row(probe, "Tether"),
			"no Tether Help row for %s" % str(case[0]))
		_check(probe == before, "the %s probe is never mutated" % str(case[0]))

	# Wrong target_kind
	for target: String in ["enemy_single", "enemy_all", "enemy_random", "enemy_back", "self", "ally_single", "party_all"]:
		var probe := loop.duplicate(true)
		probe["target_kind"] = target
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe),
			"target_kind %s is not an authored Tether card" % target)
		var line := CardShortRules.line(probe)
		_check(not line.contains("Echo 50%") and not line.contains("Link 2 living enemies"),
			"no Tether on face for target %s: %s" % [target, line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"target %s keeps honest fallback: %s" % [target, line])
		_check(not _has_keyword_row(probe, "Tether"),
			"no Tether Help row for target %s" % target)
		_check(probe == before, "target %s probe is never mutated" % target)

	# Wrong owner
	for owner: Variant in ["warden", "tinker", &"seamstress", null, "button_golem"]:
		var probe := loop.duplicate(true)
		probe["owner"] = owner
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe)
			and not CardShortRules.line(probe).contains("Echo 50%")
			and CardShortRules.line(probe).ends_with(UNKNOWN_FALLBACK)
			and not _has_keyword_row(probe, "Tether"),
			"owner %s never borrows Tether: %s" % [str(owner), CardShortRules.line(probe)])
		_check(probe == before, "owner %s probe is never mutated" % str(owner))

	# Forged ID and wrong cost
	var structural := [
		["forged ID on loop", "id", "seamstress_v3_tether_loop_forged"],
		["forged ID on stitch", "id", "seamstress_v3_tether_stitch_forged"],
		["wrong cost on loop (1 instead of 2)", "cost", 1],
		["wrong cost on loop (0)", "cost", 0],
		["wrong cost on loop (3)", "cost", 3],
	]
	for case in structural:
		var probe := loop.duplicate(true)
		probe[case[1]] = case[2]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe)
			and not CardShortRules.line(probe).contains("Echo 50%")
			and CardShortRules.line(probe).ends_with(UNKNOWN_FALLBACK)
			and not _has_keyword_row(probe, "Tether"),
			"%s never borrows Tether" % str(case[0]))
		_check(probe == before, "%s probe is never mutated" % str(case[0]))

	# Wrong positions
	for case in [["from_positions", [1, 2, 3]], ["from_positions", [1]],
			["from_positions", null], ["to_positions", [1, 2]],
			["to_positions", []], ["to_positions", null]]:
		var probe := loop.duplicate(true)
		probe[case[0]] = case[1]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe)
			and not CardShortRules.line(probe).contains("Echo 50%")
			and CardShortRules.line(probe).ends_with(UNKNOWN_FALLBACK)
			and not _has_keyword_row(probe, "Tether"),
			"Tether record with %s %s stays silent" % [str(case[0]), str(case[1])])
		_check(probe == before, "probe is never mutated")

	# Extra effect keys (unsupported and supported)
	for extra in [["unsupported", "mystery_status", 9], ["supported damage", "damage", 4],
			["supported weak", "weak", 1]]:
		var sibling := loop.duplicate(true)
		sibling["effects"][str(extra[1])] = extra[2]
		var before := sibling.duplicate(true)
		var line := CardShortRules.line(sibling)
		_check(not CardShortRules.is_authored_tether(sibling)
			and not line.contains("Echo 50%")
			and line.ends_with(UNKNOWN_FALLBACK),
			"Tether sibling with extra %s effect stays honest: %s" % [str(extra[0]), line])
		_check(not _has_keyword_row(sibling, "Tether"),
			"extra %s effect adds no Tether Help row" % str(extra[0]))
		_check(sibling == before, "sibling probe is never mutated")

	# Broken upgrade relationships
	var loop_base_no_upgrade := loop.duplicate(true)
	loop_base_no_upgrade.erase("upgrade_id")
	var loop_base_with_upgrade_of := loop.duplicate(true)
	loop_base_with_upgrade_of["upgrade_of"] = "seamstress_v3_tether_stitch"
	var loop_plus := _seamstress_tether_definition("starter", "seamstress_v3_tether_loop_plus")
	var loop_plus_no_upgrade_of := loop_plus.duplicate(true)
	loop_plus_no_upgrade_of.erase("upgrade_of")
	var loop_plus_with_upgrade_id := loop_plus.duplicate(true)
	loop_plus_with_upgrade_id["upgrade_id"] = "seamstress_v3_tether_loop_plus_plus"
	for probe: Dictionary in [loop_base_no_upgrade, loop_base_with_upgrade_of,
			loop_plus_no_upgrade_of, loop_plus_with_upgrade_id]:
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(not CardShortRules.is_authored_tether(probe)
			and not line.contains("Echo 50%") and line.ends_with(UNKNOWN_FALLBACK),
			"broken upgrade link never borrows Tether: " + line)
		_check(not _has_keyword_row(probe, "Tether"),
			"broken upgrade link adds no Tether Help row")
		_check(probe == before, "broken upgrade probe is never mutated")

	# Detached canonical field-set negative probes
	var canonical_probes := [
		["deleted display_name on loop", loop.duplicate(true), "erase", "display_name", null],
		["changed display_name on loop", loop.duplicate(true), "set", "display_name", "Thread Link"],
		["deleted display_name on stitch", stitch.duplicate(true), "erase", "display_name", null],
		["changed display_name on stitch", stitch.duplicate(true), "set", "display_name", "Stitch"],
		["changed reward_eligible on loop", loop.duplicate(true), "set", "reward_eligible", true],
		["changed reward_eligible on stitch", stitch.duplicate(true), "set", "reward_eligible", false],
		["changed rarity on stitch", stitch.duplicate(true), "set", "rarity", "rare"],
		["deleted rarity on stitch", stitch.duplicate(true), "erase", "rarity", null],
		["extra rarity on loop", loop.duplicate(true), "set", "rarity", "common"],
		["extra top-level field on loop", loop.duplicate(true), "set", "unexpected_field", "forgery"],
		["extra top-level field on stitch", stitch.duplicate(true), "set", "forged_flag", true],
		["changed illustration_path on loop", loop.duplicate(true), "set", "illustration_path", "res://other.png"],
		["changed starting_copies on loop", loop.duplicate(true), "set", "starting_copies", 0],
		["changed starting_copies on stitch", stitch.duplicate(true), "set", "starting_copies", 1],
	]
	for case_def in canonical_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var action: String = str(case_def[2])
		var key: String = str(case_def[3])
		if action == "erase":
			probe.erase(key)
		else:
			probe[key] = case_def[4]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_tether(probe),
			"%s fails is_authored_tether" % label)
		_check(CardShortRules.has_unknown(probe),
			"%s reports has_unknown true" % label)
		var line := CardShortRules.line(probe)
		_check(not line.contains("Echo 50%") and not line.contains("Link 2 living enemies"),
			"no Tether on face for %s: %s" % [label, line])
		_check(line.ends_with(UNKNOWN_FALLBACK),
			"honest unknown fallback on face for %s: %s" % [label, line])
		_check(not _has_keyword_row(probe, "Tether"),
			"no Tether Help row for %s" % label)
		_check(probe == before, "%s probe is never mutated" % label)

	# Verify existing keyword rows are untouched
	var cloud := lantern_monk_pool.get_definition("lantern_monk_moth_cloud")
	_check(CardShortRules.line(cloud) == "Blind to all. Exhaust."
		and _has_keyword_row(cloud, "Blind") and _has_keyword_row(cloud, "Exhaust")
		and not _has_keyword_row(cloud, "Tether"),
		"existing Moth Cloud Blind/Exhaust Help has no Tether")
	var slip := rag_duelist_starter.get_definition("rag_duelist_cape_slip")
	_check(CardShortRules.line(slip) == "Dodge the next attack."
		and _has_keyword_row(slip, "Dodge") and not _has_keyword_row(slip, "Tether"),
		"existing Cape Slip Dodge Help has no Tether")
	var dive := scarecrow_starter.get_definition("scarecrow_crow_dive")
	_check(CardShortRules.line(dive) == "Deal 3 to the backmost living enemy. Pierce Block."
		and _has_keyword_row(dive, "Pierce Block") and not _has_keyword_row(dive, "Tether"),
		"existing Crow Dive Pierce Block Help has no Tether")

	# Shipped records are untouched
	var loop_after := _seamstress_tether_definition("starter", "seamstress_v3_tether_loop")
	var stitch_after := _seamstress_tether_definition("pool", "seamstress_v3_tether_stitch")
	_check(loop_after == loop and stitch_after == stitch
		and CardShortRules.line(loop_after) == "Link 2 living enemies. Echo 50% of a later confirmed hit's HP loss.",
		"malformed probes cannot alter shipped Seamstress Tether records")


func _warden_v3_definition(catalog: String, card_id: String) -> Dictionary:
	match catalog:
		"starter":
			return v3_warden_starter.get_definition(card_id)
		"pool":
			return v3_warden_pool.get_definition(card_id)
	return {}


func _test_warden_v3_faces() -> void:
	for entry in WARDEN_V3_CASES:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var expected_line: String = str(entry["line"])
		var expected_phrases: Array = entry["phrases"]
		var definition := _warden_v3_definition(catalog, card_id)
		_check(not definition.is_empty(), "Warden V3 record exists in %s: %s" % [catalog, card_id])
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var described: Dictionary = CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "Warden V3 face known: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"Warden V3 face fully described (no unknown): " + card_id)
		_check(not CardShortRules.has_unknown(definition),
			"has_unknown is false for authentic Warden V3 record: " + card_id)
		_check(line == expected_line,
			"Warden V3 line for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		_check(CardShortRules.line(definition) == expected_line,
			"CardShortRules.line direct match for: " + card_id)
		var actual_phrases: Array = described.get("phrases", [])
		_check(actual_phrases.size() == expected_phrases.size(),
			"Warden V3 phrases count for %s: got %d, want %d" % [card_id, actual_phrases.size(), expected_phrases.size()])
		for i in range(mini(actual_phrases.size(), expected_phrases.size())):
			_check(str(actual_phrases[i]) == str(expected_phrases[i]),
				"Warden V3 phrase %d for %s: got '%s', want '%s'" % [i, card_id, str(actual_phrases[i]), str(expected_phrases[i])])
		_check(CardShortRules.is_authored_v3_guard(definition) == bool(entry["guard"]),
			"is_authored_v3_guard match for " + card_id)
		_check(CardShortRules.is_authored_guard(definition) == bool(entry["guard"]),
			"is_authored_guard alias match for " + card_id)
		_check(CardShortRules.is_authored_v3_taunt(definition) == bool(entry["taunt"]),
			"is_authored_v3_taunt match for " + card_id)
		_check(CardShortRules.is_authored_taunt(definition) == bool(entry["taunt"]),
			"is_authored_taunt alias match for " + card_id)
		_check(CardShortRules.is_authored_v3_shield_toss(definition) == bool(entry["toss"]),
			"is_authored_v3_shield_toss match for " + card_id)
		_check(CardShortRules.is_authored_shield_toss(definition) == bool(entry["toss"]),
			"is_authored_shield_toss alias match for " + card_id)
		_check(definition == original, "Warden V3 record never mutated: " + card_id)


func _test_warden_v3_help() -> void:
	for entry in WARDEN_V3_CASES:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var expected_keywords: Array = entry["keywords"]
		var definition := _warden_v3_definition(catalog, card_id)
		var original: Dictionary = definition.duplicate(true)
		var rows: Array[Dictionary] = CardKeywordGlossary.describe(definition)
		_check(rows.size() == expected_keywords.size(),
			"Warden V3 Help rows count for %s: got %d, want %d" % [card_id, rows.size(), expected_keywords.size()])
		for i in range(mini(rows.size(), expected_keywords.size())):
			var row_kw := str(rows[i].get("keyword", ""))
			var exp_kw := str(expected_keywords[i])
			_check(row_kw == exp_kw,
				"Warden V3 Help row %d keyword for %s: got '%s', want '%s'" % [i, card_id, row_kw, exp_kw])
			var explanation := str(rows[i].get("explanation", ""))
			match exp_kw:
				"Guard":
					var is_bastion: bool = (card_id == "warden_v3_final_bastion" or card_id == "warden_v3_final_bastion_plus")
					if is_bastion:
						_check(explanation == CardKeywordGlossary.GUARD_UNIVERSAL_EXPLANATION,
							"Guard explanation matches GUARD_UNIVERSAL_EXPLANATION for " + card_id)
						_check(explanation.contains("universal") and explanation.contains("any other living ally"),
							"Bastion Guard explains universal protection for any other living ally: " + card_id)
						_check(not explanation.contains("chosen") and not explanation.contains("selected"),
							"Bastion Guard has no falsely chosen ally: " + card_id)
						_check(explanation.contains("Warden himself are not redirected"),
							"Bastion Guard explains hits on Warden are not redirected: " + card_id)
					else:
						_check(explanation == CardKeywordGlossary.GUARD_EXPLANATION,
							"Guard explanation matches GUARD_EXPLANATION for " + card_id)
						_check(explanation.contains("chosen") and explanation.contains("ally"),
							"Guard explains chosen ally for " + card_id)
						_check(explanation.contains("Warden himself") and explanation.contains("does not redirect"),
							"Guard explains self-selection exception for " + card_id)
					_check(explanation.contains("redirects") and explanation.contains("once"),
						"Guard explanation mentions redirection once for " + card_id)
					_check(explanation.contains("lasts until") and explanation.contains("eligible confirmed"),
						"Guard explanation states single interception lasts until confirmed hit for " + card_id)
					_check(explanation.contains("miss or non-attack"),
						"Guard explanation mentions miss or non-attack does not consume for " + card_id)
					_check(not explanation.contains("combat round") and not explanation.contains("round end")
						and not explanation.contains("expires"),
						"Guard explanation has no premature expiry for " + card_id)
					_check(explanation.contains("Block absorbs incoming damage before HP loss"),
						"Guard explanation states Block absorbs before HP for " + card_id)
				"Taunt":
					_check(explanation == CardKeywordGlossary.TAUNT_EXPLANATION,
						"Taunt explanation matches TAUNT_EXPLANATION for " + card_id)
					_check(explanation.contains("next enemy turn"),
						"Taunt explanation mentions next enemy turn")
				"Shield Toss":
					_check(explanation == CardKeywordGlossary.SHIELD_TOSS_EXPLANATION,
						"Shield Toss explanation matches SHIELD_TOSS_EXPLANATION for " + card_id)
					_check(explanation.contains("unspent") or explanation.contains("current Block"),
						"Shield Toss explanation mentions unspent current Block")
		# Assert detached results (mutating rows array doesn't affect subsequent calls)
		if not rows.is_empty():
			rows[0]["keyword"] = "TAMPERED"
			_check(CardKeywordGlossary.describe(definition)[0]["keyword"] != "TAMPERED",
				"glossary return dictionaries are detached for " + card_id)
		_check(definition == original, "Warden V3 record never mutated: " + card_id)

	# Dedicated verification for Final Bastion and Final Bastion+:
	# Exactly one Guard plus one Taunt row, independent semantics, no premature expiry, and no falsely chosen ally.
	for bastion_id: String in ["warden_v3_final_bastion", "warden_v3_final_bastion_plus"]:
		var def := _warden_v3_definition("pool", bastion_id)
		var b_rows: Array[Dictionary] = CardKeywordGlossary.describe(def)
		_check(b_rows.size() == 2, "Final Bastion has exactly two help rows: " + bastion_id)
		_check(str(b_rows[0].get("keyword", "")) == "Guard", "Final Bastion first row is Guard: " + bastion_id)
		_check(str(b_rows[1].get("keyword", "")) == "Taunt", "Final Bastion second row is Taunt: " + bastion_id)
		var guard_text := str(b_rows[0].get("explanation", ""))
		var taunt_text := str(b_rows[1].get("explanation", ""))
		_check(not guard_text.contains("chosen") and not guard_text.contains("selected"),
			"Bastion Guard row has no falsely chosen ally: " + bastion_id)
		_check(guard_text.contains("any other living ally") and guard_text.contains("universal"),
			"Bastion Guard row explains universal protection for any other living ally: " + bastion_id)
		_check(not guard_text.contains("combat round") and not guard_text.contains("round end")
			and not guard_text.contains("expires"),
			"Bastion Guard row has no premature combat round expiry: " + bastion_id)
		_check(guard_text.contains("lasts until") and guard_text.contains("eligible confirmed"),
			"Bastion Guard row asserts interception lasts until eligible confirmed hit: " + bastion_id)
		_check(guard_text.contains("miss or non-attack"),
			"Bastion Guard row asserts miss or non-attack never consumes: " + bastion_id)
		_check(not taunt_text.contains("chosen") and not taunt_text.contains("selected"),
			"Bastion Taunt row has no falsely chosen ally: " + bastion_id)
		_check(taunt_text.contains("next enemy turn"),
			"Bastion Taunt row explains next enemy turn: " + bastion_id)

	# Dedicated verification for Shield Catch and Guard Stitch (base and +):
	# Chosen-ally explanation, self-selection exception, and no premature expiry.
	for ally_guard_id: String in ["warden_v3_shield_catch", "warden_v3_shield_catch_plus",
			"warden_v3_guard_stitch", "warden_v3_guard_stitch_plus"]:
		var cat: String = "starter" if ally_guard_id.begins_with("warden_v3_shield_catch") else "pool"
		var def := _warden_v3_definition(cat, ally_guard_id)
		var g_rows: Array[Dictionary] = CardKeywordGlossary.describe(def)
		_check(g_rows.size() == 1, "Ally Guard card has exactly one help row: " + ally_guard_id)
		_check(str(g_rows[0].get("keyword", "")) == "Guard", "Ally Guard row is Guard: " + ally_guard_id)
		var text := str(g_rows[0].get("explanation", ""))
		_check(text.contains("chosen living ally"), "Ally Guard row explains chosen living ally: " + ally_guard_id)
		_check(text.contains("Warden himself") and text.contains("does not redirect"),
			"Ally Guard row explains self-selection exception: " + ally_guard_id)
		_check(not text.contains("combat round") and not text.contains("round end")
			and not text.contains("expires"),
			"Ally Guard row has no premature combat round expiry: " + ally_guard_id)
		_check(text.contains("lasts until") and text.contains("eligible confirmed"),
			"Ally Guard row asserts interception lasts until eligible confirmed hit: " + ally_guard_id)
		_check(text.contains("miss or non-attack"),
			"Ally Guard row asserts miss or non-attack never consumes: " + ally_guard_id)


func _test_warden_v3_negative() -> void:
	var catch := v3_warden_starter.get_definition("warden_v3_shield_catch")
	var rim := v3_warden_starter.get_definition("warden_v3_rim_toss")
	var challenge := v3_warden_starter.get_definition("warden_v3_iron_challenge")
	var toss := v3_warden_pool.get_definition("warden_v3_shield_toss")
	var stitch := v3_warden_pool.get_definition("warden_v3_guard_stitch")
	var taunt := v3_warden_pool.get_definition("warden_v3_iron_taunt")
	var chorus := v3_warden_pool.get_definition("warden_v3_shieldwall_chorus")
	var bastion := v3_warden_pool.get_definition("warden_v3_final_bastion")

	# 1. Non-dictionary inputs
	_check(not CardShortRules.is_authored_v3_guard(null), "guard null is false")
	_check(not CardShortRules.is_authored_v3_taunt(null), "taunt null is false")
	_check(not CardShortRules.is_authored_v3_shield_toss(null), "shield toss null is false")
	_check(not CardShortRules.is_authored_v3_guard({}), "guard empty is false")
	_check(not CardShortRules.is_authored_v3_taunt({}), "taunt empty is false")
	_check(not CardShortRules.is_authored_v3_shield_toss({}), "shield toss empty is false")
	_check(CardKeywordGlossary.describe(null).is_empty(), "glossary null produces no rows")
	_check(CardKeywordGlossary.describe({}).is_empty(), "glossary empty produces no rows")

	# 2. Forged flag types and values
	var flag_probes := [
		["guard_next_hit integer 1", catch.duplicate(true), "guard_next_hit", 1],
		["guard_next_hit false", catch.duplicate(true), "guard_next_hit", false],
		["guard_next_hit string", catch.duplicate(true), "guard_next_hit", "true"],
		["taunt_next_enemy_turn integer 1", challenge.duplicate(true), "taunt_next_enemy_turn", 1],
		["taunt_next_enemy_turn false", challenge.duplicate(true), "taunt_next_enemy_turn", false],
		["taunt_next_enemy_turn string", challenge.duplicate(true), "taunt_next_enemy_turn", "true"],
		["damage_equal_to_owner_block integer 1", rim.duplicate(true), "damage_equal_to_owner_block", 1],
		["damage_equal_to_owner_block false", rim.duplicate(true), "damage_equal_to_owner_block", false],
		["damage_equal_to_owner_block string", rim.duplicate(true), "damage_equal_to_owner_block", "true"],
	]
	for case_def in flag_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var key: String = str(case_def[2])
		(probe["effects"] as Dictionary)[key] = case_def[3]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_v3_guard(probe), "%s fails is_authored_v3_guard" % label)
		_check(not CardShortRules.is_authored_v3_taunt(probe), "%s fails is_authored_v3_taunt" % label)
		_check(not CardShortRules.is_authored_v3_shield_toss(probe), "%s fails is_authored_v3_shield_toss" % label)
		_check(CardShortRules.has_unknown(probe), "%s reports has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s ends with fallback: %s" % [label, line])
		_check(not _has_keyword_row(probe, "Guard") and not _has_keyword_row(probe, "Taunt")
			and not _has_keyword_row(probe, "Shield Toss"), "%s receives no V3 help row" % label)
		_check(probe == before, "%s probe not mutated" % label)

	# 3. Forged bonus damage on shield toss
	var toss_plus := v3_warden_pool.get_definition("warden_v3_shield_toss_plus")
	var bonus_probes := [
		["bonus_damage string", toss_plus.duplicate(true), "bonus_damage", "3"],
		["bonus_damage 0", toss_plus.duplicate(true), "bonus_damage", 0],
		["bonus_damage negative", toss_plus.duplicate(true), "bonus_damage", -2],
	]
	for case_def in bonus_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var key: String = str(case_def[2])
		(probe["effects"] as Dictionary)[key] = case_def[3]
		_check(not CardShortRules.is_authored_v3_shield_toss(probe), "%s fails is_authored_v3_shield_toss" % label)
		_check(CardShortRules.has_unknown(probe), "%s reports has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s ends with fallback" % label)
		_check(not _has_keyword_row(probe, "Shield Toss"), "%s receives no Shield Toss row" % label)

	# 4. Standalone bonus_damage without damage_equal_to_owner_block
	var forged_bonus := catch.duplicate(true)
	(forged_bonus["effects"] as Dictionary)["bonus_damage"] = 3
	_check(not CardShortRules.is_authored_v3_shield_toss(forged_bonus), "forged bonus fails shield toss")
	_check(CardShortRules.has_unknown(forged_bonus), "forged bonus has_unknown")

	# 5. Broken upgrade links
	var catch_no_up := catch.duplicate(true)
	catch_no_up.erase("upgrade_id")
	var catch_with_up_of := catch.duplicate(true)
	catch_with_up_of["upgrade_of"] = "warden_v3_shield_catch"
	var catch_plus := v3_warden_starter.get_definition("warden_v3_shield_catch_plus")
	var catch_plus_no_up_of := catch_plus.duplicate(true)
	catch_plus_no_up_of.erase("upgrade_of")
	var catch_plus_with_up_id := catch_plus.duplicate(true)
	catch_plus_with_up_id["upgrade_id"] = "warden_v3_shield_catch_plus_plus"
	var catch_mismatched_up := catch.duplicate(true)
	catch_mismatched_up["upgrade_id"] = "warden_v3_rim_toss_plus"

	for probe in [catch_no_up, catch_with_up_of, catch_plus_no_up_of, catch_plus_with_up_id, catch_mismatched_up]:
		_check(not CardShortRules.is_authored_v3_guard(probe), "broken upgrade link fails is_authored_v3_guard")
		_check(CardShortRules.has_unknown(probe), "broken upgrade link has_unknown")
		_check(not _has_keyword_row(probe, "Guard"), "broken upgrade link has no Guard row")

	# 6. Core metadata mutation probes
	var meta_probes := [
		["changed id", catch.duplicate(true), "id", "warden_v3_forged_guard"],
		["deleted id", catch.duplicate(true), "id", null],
		["non-string id", catch.duplicate(true), "id", 12345],
		["changed display_name", catch.duplicate(true), "display_name", "Fake Guard"],
		["deleted display_name", catch.duplicate(true), "display_name", null],
		["changed owner", catch.duplicate(true), "owner", "seamstress"],
		["changed cost", catch.duplicate(true), "cost", 0],
		["changed target_kind", catch.duplicate(true), "target_kind", "self"],
		["changed from_positions", catch.duplicate(true), "from_positions", [3]],
		["changed to_positions", rim.duplicate(true), "to_positions", [1]],
		["changed rarity", stitch.duplicate(true), "rarity", "rare"],
		["changed reward_eligible", stitch.duplicate(true), "reward_eligible", false],
		["changed starting_copies", catch.duplicate(true), "starting_copies", 0],
		["changed illustration_path", catch.duplicate(true), "illustration_path", "res://other.png"],
		["extra top-level field", catch.duplicate(true), "forgery", true],
		["extra effect weak", catch.duplicate(true), "effects", {"block": 4, "guard_next_hit": true, "weak": 1}],
		["extra effect damage", bastion.duplicate(true), "effects", {"block": 12, "guard_next_hit": true, "taunt_next_enemy_turn": true, "damage": 5}],
	]
	for case_def in meta_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var field: String = str(case_def[2])
		var val: Variant = case_def[3]
		if val == null:
			probe.erase(field)
		else:
			probe[field] = val
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_v3_guard(probe), "%s fails is_authored_v3_guard" % label)
		_check(not CardShortRules.is_authored_v3_taunt(probe), "%s fails is_authored_v3_taunt" % label)
		_check(not CardShortRules.is_authored_v3_shield_toss(probe), "%s fails is_authored_v3_shield_toss" % label)
		_check(CardShortRules.has_unknown(probe), "%s has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s face ends with fallback" % label)
		_check(not _has_keyword_row(probe, "Guard") and not _has_keyword_row(probe, "Taunt")
			and not _has_keyword_row(probe, "Shield Toss"), "%s receives no V3 help row" % label)
		_check(probe == before, "%s probe not mutated" % label)

	# 7. Unrelated cards do not borrow Guard, Taunt, or Shield Toss
	var draw_fire := warden.get_definition("warden_draw_fire")
	_check(CardShortRules.line(draw_fire) == "Gain 6 Block. Guard.", "legacy Draw Fire line preserved")
	_check(_has_keyword_row(draw_fire, "Guarding"), "legacy Draw Fire keeps Guarding row")
	_check(not _has_keyword_row(draw_fire, "Guard"), "legacy Draw Fire does not borrow V3 Guard")
	_check(not CardShortRules.is_authored_v3_guard(draw_fire), "legacy Draw Fire fails is_authored_v3_guard")

	var cloud := lantern_monk_pool.get_definition("lantern_monk_moth_cloud")
	_check(not _has_keyword_row(cloud, "Guard") and not _has_keyword_row(cloud, "Taunt")
		and not _has_keyword_row(cloud, "Shield Toss"), "Moth Cloud has no V3 Warden rows")

	var dive := scarecrow_starter.get_definition("scarecrow_crow_dive")
	_check(not _has_keyword_row(dive, "Guard") and not _has_keyword_row(dive, "Taunt")
		and not _has_keyword_row(dive, "Shield Toss"), "Crow Dive has no V3 Warden rows")

	var tether_card := v3_seamstress_starter.get_definition("seamstress_v3_tether_loop")
	_check(not _has_keyword_row(tether_card, "Guard") and not _has_keyword_row(tether_card, "Taunt")
		and not _has_keyword_row(tether_card, "Shield Toss"), "Tether Loop has no V3 Warden rows")



func _tinker_v3_definition(catalog: String, card_id: String) -> Dictionary:
	if catalog == "starter":
		return v3_tinker_starter.get_definition(card_id)
	return v3_tinker_pool.get_definition(card_id)


func _test_tinker_v3_faces() -> void:
	for entry in TINKER_V3_CASES:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var expected_line: String = str(entry["line"])
		var expected_phrases: Array = entry["phrases"]
		var definition := _tinker_v3_definition(catalog, card_id)
		_check(not definition.is_empty(), "Tinker V3 catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var described: Dictionary = CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is known: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"face record is fully described, no fallback: " + card_id)
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		var phrases: Array = described.get("phrases", [])
		_check(phrases.size() == expected_phrases.size(),
			"phrases count for %s: got %d, want %d" % [card_id, phrases.size(), expected_phrases.size()])
		for i in range(mini(phrases.size(), expected_phrases.size())):
			_check(str(phrases[i]) == str(expected_phrases[i]),
				"phrase %d for %s: got '%s', want '%s'" % [i, card_id, str(phrases[i]), str(expected_phrases[i])])
		_check(CardShortRules.line(definition) == expected_line,
			"CardShortRules.line matches for " + card_id)
		_check(CardShortRules.is_authored_v3_tinker_combat_scrap(definition),
			"is_authored_v3_tinker_combat_scrap match for " + card_id)
		_check(CardShortRules.is_authored_combat_scrap(definition),
			"is_authored_combat_scrap alias match for " + card_id)
		# Gain cards mention Combat Scrap once per cast (including Scrap Bomb)
		if not bool(entry["is_spender"]):
			var gain_amount: int = int(entry["gain"])
			_check(line.count("Combat Scrap") == 1,
				"Combat Scrap mentioned exactly once on face: " + card_id)
			_check(line.count("Gain") == (2 if (card_id.contains("ward") or card_id.contains("brace")) else 1),
				"Gain clause count correct: " + card_id)
			_check(line.contains("Gain %d Combat Scrap." % gain_amount),
				"gain clause amount correct: " + card_id)
			_check(not line.contains("wallet"), "face never mentions wallet: " + card_id)
		else:
			# Spenders print full spend rule without flat extra hit
			if card_id.begins_with("tinker_v3_overload"):
				_check(line.contains("Spend all Combat Scrap"),
					"Overload states 'Spend all Combat Scrap': " + card_id)
				var per_scrap := 4 if card_id.ends_with("_plus") else 3
				_check(line.contains("%d damage per Scrap" % per_scrap),
					"Overload states '%d damage per Scrap': " % per_scrap + card_id)
				var base_dmg := 3 if card_id.ends_with("_plus") else 2
				_check(line.begins_with("Deal %d." % base_dmg),
					"Overload base damage preserved: " + card_id)
			elif card_id.begins_with("tinker_v3_scrapstorm"):
				_check(line.contains("Spend up to 3 Combat Scrap"),
					"Scrapstorm states 'Spend up to 3 Combat Scrap': " + card_id)
				_check(line.contains("+1 per spent Scrap to each living enemy"),
					"Scrapstorm states '+1 per spent Scrap to each living enemy': " + card_id)
				var base_dmg := 4 if card_id.ends_with("_plus") else 3
				_check(line.begins_with("Deal %d to all." % base_dmg),
					"Scrapstorm base damage preserved: " + card_id)
		_check(definition == original, "Tinker V3 record never mutated: " + card_id)


func _test_tinker_v3_help() -> void:
	for entry in TINKER_V3_CASES:
		var catalog: String = str(entry["catalog"])
		var card_id: String = str(entry["id"])
		var expected_keywords: Array = entry["keywords"]
		var definition := _tinker_v3_definition(catalog, card_id)
		var original: Dictionary = definition.duplicate(true)
		var rows: Array[Dictionary] = CardKeywordGlossary.describe(definition)
		_check(rows.size() == expected_keywords.size(),
			"Tinker V3 Help rows count for %s: got %d, want %d" % [card_id, rows.size(), expected_keywords.size()])
		for i in range(mini(rows.size(), expected_keywords.size())):
			var row_kw := str(rows[i].get("keyword", ""))
			var exp_kw := str(expected_keywords[i])
			_check(row_kw == exp_kw,
				"Tinker V3 Help row %d keyword for %s: got '%s', want '%s'" % [i, card_id, row_kw, exp_kw])
			var explanation := str(rows[i].get("explanation", ""))
			if exp_kw == "Combat Scrap":
				_check(explanation == CardKeywordGlossary.COMBAT_SCRAP_EXPLANATION,
					"Combat Scrap explanation matches COMBAT_SCRAP_EXPLANATION for " + card_id)
				_check(explanation.contains("combat-local counter") or explanation.contains("during battle"),
					"Combat Scrap explanation mentions per-combat counter: " + card_id)
				_check(explanation.contains("wallet scraps") and explanation.contains("never"),
					"Combat Scrap explanation distinguishes from wallet scraps: " + card_id)
				_check(explanation.contains("Overload") and explanation.contains("all"),
					"Combat Scrap explanation explains Overload spends all: " + card_id)
				_check(explanation.contains("Scrapstorm") and explanation.contains("up to 3"),
					"Combat Scrap explanation explains Scrapstorm limit: " + card_id)
				_check(explanation.contains("retains") or explanation.contains("surplus"),
					"Combat Scrap explanation mentions retained surplus: " + card_id)
			elif exp_kw == "Weak 1":
				_check(explanation.contains("25% less attack damage"),
					"Spring Clamp retains Weak Help row: " + card_id)
		# Assert detached results (mutating rows array doesn't affect subsequent calls)
		if not rows.is_empty():
			rows[0]["keyword"] = "TAMPERED"
			_check(CardKeywordGlossary.describe(definition)[0]["keyword"] != "TAMPERED",
				"glossary return dictionaries are detached for " + card_id)
		_check(definition == original, "Tinker V3 record never mutated: " + card_id)


func _test_tinker_v3_negative() -> void:
	var shot := v3_tinker_starter.get_definition("tinker_v3_cog_shot")
	var ward := v3_tinker_starter.get_definition("tinker_v3_casing_ward")
	var bomb := v3_tinker_starter.get_definition("tinker_v3_scrap_bomb")
	var tune := v3_tinker_starter.get_definition("tinker_v3_tune_up")
	var brass := v3_tinker_pool.get_definition("tinker_v3_brass_casing")
	var gear := v3_tinker_pool.get_definition("tinker_v3_gear_brace")
	var screws := v3_tinker_pool.get_definition("tinker_v3_spare_screws")
	var clamp := v3_tinker_pool.get_definition("tinker_v3_spring_clamp")
	var overload := v3_tinker_pool.get_definition("tinker_v3_overload")
	var storm := v3_tinker_pool.get_definition("tinker_v3_scrapstorm")

	# 1. Non-dictionary inputs
	_check(not CardShortRules.is_authored_combat_scrap(null), "scrap null is false")
	_check(not CardShortRules.is_authored_combat_scrap({}), "scrap empty is false")
	_check(not CardShortRules.is_authored_v3_tinker_combat_scrap(null), "v3 tinker scrap null is false")
	_check(not CardShortRules.is_authored_v3_tinker_combat_scrap({}), "v3 tinker scrap empty is false")

	# 2. Forged flag / effect types and values
	var effect_probes := [
		["combat_scrap_gain 0", shot.duplicate(true), "combat_scrap_gain", 0],
		["combat_scrap_gain negative", shot.duplicate(true), "combat_scrap_gain", -1],
		["combat_scrap_gain string", shot.duplicate(true), "combat_scrap_gain", "1"],
		["combat_scrap_gain float", shot.duplicate(true), "combat_scrap_gain", 1.0],
		["combat_scrap_gain bool", shot.duplicate(true), "combat_scrap_gain", true],
		["damage_per_combat_scrap 0", overload.duplicate(true), "damage_per_combat_scrap", 0],
		["damage_per_combat_scrap negative", overload.duplicate(true), "damage_per_combat_scrap", -2],
		["damage_per_combat_scrap string", overload.duplicate(true), "damage_per_combat_scrap", "3"],
		["consume_all_combat_scrap false", overload.duplicate(true), "consume_all_combat_scrap", false],
		["consume_all_combat_scrap int 1", overload.duplicate(true), "consume_all_combat_scrap", 1],
		["consume_all_combat_scrap string", overload.duplicate(true), "consume_all_combat_scrap", "true"],
		["combat_scrap_spend_max 0", storm.duplicate(true), "combat_scrap_spend_max", 0],
		["combat_scrap_spend_max negative", storm.duplicate(true), "combat_scrap_spend_max", -1],
		["combat_scrap_spend_max string", storm.duplicate(true), "combat_scrap_spend_max", "3"],
		["bonus_damage_per_combat_scrap 0", storm.duplicate(true), "bonus_damage_per_combat_scrap", 0],
		["bonus_damage_per_combat_scrap negative", storm.duplicate(true), "bonus_damage_per_combat_scrap", -1],
		["bonus_damage_per_combat_scrap string", storm.duplicate(true), "bonus_damage_per_combat_scrap", "1"],
	]
	for case_def in effect_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var key: String = str(case_def[2])
		(probe["effects"] as Dictionary)[key] = case_def[3]
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_combat_scrap(probe), "%s fails is_authored_combat_scrap" % label)
		_check(CardShortRules.has_unknown(probe), "%s reports has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s ends with fallback: %s" % [label, line])
		_check(not _has_keyword_row(probe, "Combat Scrap"), "%s receives no Combat Scrap help row" % label)
		_check(probe == before, "%s probe not mutated" % label)

	# 3. Missing expected effect keys
	var missing_key_probes := [
		["overload missing damage_per_combat_scrap", overload.duplicate(true), "damage_per_combat_scrap"],
		["overload missing consume_all_combat_scrap", overload.duplicate(true), "consume_all_combat_scrap"],
		["storm missing combat_scrap_spend_max", storm.duplicate(true), "combat_scrap_spend_max"],
		["storm missing bonus_damage_per_combat_scrap", storm.duplicate(true), "bonus_damage_per_combat_scrap"],
	]
	for case_def in missing_key_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var key: String = str(case_def[2])
		(probe["effects"] as Dictionary).erase(key)
		_check(not CardShortRules.is_authored_combat_scrap(probe), "%s fails is_authored_combat_scrap" % label)
		_check(CardShortRules.has_unknown(probe), "%s reports has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s ends with fallback: %s" % [label, line])
		_check(not _has_keyword_row(probe, "Combat Scrap"), "%s receives no Combat Scrap help row" % label)

	# 4. Broken upgrade links
	var shot_no_up := shot.duplicate(true)
	shot_no_up.erase("upgrade_id")
	var shot_with_up_of := shot.duplicate(true)
	shot_with_up_of["upgrade_of"] = "tinker_v3_cog_shot"
	var shot_plus := v3_tinker_starter.get_definition("tinker_v3_cog_shot_plus")
	var shot_plus_no_up_of := shot_plus.duplicate(true)
	shot_plus_no_up_of.erase("upgrade_of")
	var shot_plus_with_up_id := shot_plus.duplicate(true)
	shot_plus_with_up_id["upgrade_id"] = "tinker_v3_cog_shot_plus_plus"
	var shot_mismatched_up := shot.duplicate(true)
	shot_mismatched_up["upgrade_id"] = "tinker_v3_casing_ward_plus"

	var overload_no_base := overload.duplicate(true)
	overload_no_base.erase("base_id")
	var overload_wrong_base := overload.duplicate(true)
	overload_wrong_base["base_id"] = "tinker_v3_scrapstorm"
	var overload_wrong_is_up := overload.duplicate(true)
	overload_wrong_is_up["is_upgrade"] = true
	var overload_plus := v3_tinker_pool.get_definition("tinker_v3_overload_plus")
	var overload_plus_wrong_is_up := overload_plus.duplicate(true)
	overload_plus_wrong_is_up["is_upgrade"] = false
	var overload_plus_wrong_up_id := overload_plus.duplicate(true)
	overload_plus_wrong_up_id["upgrade_id"] = "tinker_v3_scrapstorm_plus"

	var broken_links := [
		shot_no_up, shot_with_up_of, shot_plus_no_up_of, shot_plus_with_up_id, shot_mismatched_up,
		overload_no_base, overload_wrong_base, overload_wrong_is_up,
		overload_plus_wrong_is_up, overload_plus_wrong_up_id
	]
	for probe in broken_links:
		_check(not CardShortRules.is_authored_combat_scrap(probe), "broken upgrade link fails is_authored_combat_scrap")
		_check(CardShortRules.has_unknown(probe), "broken upgrade link has_unknown")
		_check(not _has_keyword_row(probe, "Combat Scrap"), "broken upgrade link has no Combat Scrap row")

	# 5. Core metadata mutation probes
	var meta_probes := [
		["changed id", shot.duplicate(true), "id", "tinker_v3_forged_shot"],
		["deleted id", shot.duplicate(true), "id", null],
		["non-string id", shot.duplicate(true), "id", 99999],
		["changed display_name", shot.duplicate(true), "display_name", "Forged Shot"],
		["deleted display_name", shot.duplicate(true), "display_name", null],
		["changed owner", shot.duplicate(true), "owner", "warden"],
		["changed cost", shot.duplicate(true), "cost", 0],
		["changed target_kind", shot.duplicate(true), "target_kind", "self"],
		["changed from_positions", shot.duplicate(true), "from_positions", [1]],
		["changed to_positions", shot.duplicate(true), "to_positions", [1]],
		["changed rarity", overload.duplicate(true), "rarity", "common"],
		["changed reward_eligible", shot.duplicate(true), "reward_eligible", true],
		["changed starting_copies", shot.duplicate(true), "starting_copies", 3],
		["changed illustration_path", shot.duplicate(true), "illustration_path", "res://other.png"],
		["extra top-level field", shot.duplicate(true), "counterfeit", true],
		["extra effect weak", shot.duplicate(true), "effects", {"damage": 5, "combat_scrap_gain": 1, "weak": 1}],
		["extra effect bleed", overload.duplicate(true), "effects", {"damage": 2, "damage_per_combat_scrap": 3, "consume_all_combat_scrap": true, "bleed": 2}],
	]
	for case_def in meta_probes:
		var label: String = str(case_def[0])
		var probe: Dictionary = case_def[1]
		var field: String = str(case_def[2])
		var val: Variant = case_def[3]
		if val == null:
			probe.erase(field)
		else:
			probe[field] = val
		var before := probe.duplicate(true)
		_check(not CardShortRules.is_authored_combat_scrap(probe), "%s fails is_authored_combat_scrap" % label)
		_check(CardShortRules.has_unknown(probe), "%s has_unknown" % label)
		var line := CardShortRules.line(probe)
		_check(line.ends_with(UNKNOWN_FALLBACK), "%s face ends with fallback" % label)
		_check(not _has_keyword_row(probe, "Combat Scrap"), "%s receives no Combat Scrap help row" % label)
		_check(probe == before, "%s probe not mutated" % label)

	# 6. Wind-up Turret and Jury-rig are NOT in this Combat Scrap text task and retain honest fallback
	var turret := v3_tinker_pool.get_definition("tinker_v3_wind_up_turret")
	_check(not CardShortRules.is_authored_combat_scrap(turret), "Wind-up Turret is not Combat Scrap")
	_check(CardShortRules.has_unknown(turret), "Wind-up Turret has_unknown")
	_check(CardShortRules.line(turret).ends_with(UNKNOWN_FALLBACK), "Wind-up Turret retains fallback: " + CardShortRules.line(turret))
	_check(not _has_keyword_row(turret, "Combat Scrap"), "Wind-up Turret receives no Combat Scrap row")

	var jury := v3_tinker_pool.get_definition("tinker_v3_jury_rig")
	_check(not CardShortRules.is_authored_combat_scrap(jury), "Jury-rig is not Combat Scrap")
	_check(CardShortRules.has_unknown(jury), "Jury-rig has_unknown")
	_check(CardShortRules.line(jury).ends_with(UNKNOWN_FALLBACK), "Jury-rig retains fallback: " + CardShortRules.line(jury))
	_check(not _has_keyword_row(jury, "Combat Scrap"), "Jury-rig receives no Combat Scrap row")

	# 7. Unrelated cards do not borrow Combat Scrap
	var draw_fire := warden.get_definition("warden_draw_fire")
	_check(not CardShortRules.is_authored_combat_scrap(draw_fire), "legacy Draw Fire is not Combat Scrap")
	_check(not _has_keyword_row(draw_fire, "Combat Scrap"), "legacy Draw Fire receives no Combat Scrap row")

	var cloud := lantern_monk_pool.get_definition("lantern_monk_moth_cloud")
	_check(not CardShortRules.is_authored_combat_scrap(cloud), "Moth Cloud is not Combat Scrap")
	_check(not _has_keyword_row(cloud, "Combat Scrap"), "Moth Cloud receives no Combat Scrap row")

	var dive := scarecrow_starter.get_definition("scarecrow_crow_dive")
	_check(not CardShortRules.is_authored_combat_scrap(dive), "Crow Dive is not Combat Scrap")
	_check(not _has_keyword_row(dive, "Combat Scrap"), "Crow Dive receives no Combat Scrap row")

	var tether_card := v3_seamstress_starter.get_definition("seamstress_v3_tether_loop")
	_check(not CardShortRules.is_authored_combat_scrap(tether_card), "Tether Loop is not Combat Scrap")
	_check(not _has_keyword_row(tether_card, "Combat Scrap"), "Tether Loop receives no Combat Scrap row")
