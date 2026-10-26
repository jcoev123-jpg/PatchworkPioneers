extends SceneTree
## Real scene, real ordered hand, and a read-only CanvasItem presenter.
## Failures collect and exit nonzero; no model fixture replaces the live app.

const HAND_SCRIPT := "res://scripts/live_hand_card_metadata.gd"
const ART_DIR := "res://assets/paper/"
const CARD_FACTS := {
	"warden_strike": ["warden", 1, [1, 2], "enemy_single", [1, 2]],
	"warden_brace": ["warden", 1, [1, 2, 3], "self", []],
	"warden_shield_bash": ["warden", 2, [1], "enemy_single", [1]],
	"seamstress_prick": ["seamstress", 1, [1, 2, 3], "enemy_single", [1, 2, 3]],
	"seamstress_mend": ["seamstress", 1, [2, 3], "ally_single", []],
	"seamstress_stitch_up": ["seamstress", 1, [1, 2, 3], "ally_single", []],
	"tinker_pop_shot": ["tinker", 1, [2, 3], "enemy_single", [1, 2, 3]],
	"tinker_scrap_bomb": ["tinker", 2, [3], "enemy_all", [1, 2, 3]],
	"tinker_tune_up": ["tinker", 0, [1, 2, 3], "none", []],
}
const TARGET_LINES := {
	"enemy_single": "To enemy ", "enemy_all": "All enemies ",
	"self": "Self", "ally_single": "Ally", "none": "No target",
}
const SUPPORT_IDS := ["warden_brace", "tinker_tune_up", "seamstress_mend", "seamstress_stitch_up"]
const PINNED_FACTS := [
	"PINNED: one pin per enemy",
	"storing the hero who applied it",
	"DIFFERENT hero's next attack",
	"+5 damage",
	"BEFORE Weak/Exposed",
	"consumes it once",
	"same-hero attacks do not",
	"A new pin replaces it",
	"lasts to combat end",
]
const UNRAVEL_FACTS := [
	"UNRAVEL:",
	"Unravel N adds N",
	"each Bleed tick adds 1",
	"normal 8 / elite 12 / boss 16",
	"becomes Unravelled",
	"skips its next enemy action",
	"resets to 0",
	"threshold rises by 4",
	"rest of combat",
]
## The three combat status rules the held-card Help must explain. N stands for
## the applied stack, never a raw catalog amount: the Seamstress passive, a Path
## bonus or an on-hit adapter may change what the resolver really applies.
const BLEED_FACTS := [
	"BLEED:",
	"at the end of the affected owner's turn",
	"loses N HP",
	"then N decreases by 1",
	"enemy Bleed tick also adds 1 Unravel",
	"Damage rounds down, minimum 0",
]
const WEAK_FACTS := [
	"WEAK:",
	"for N turns",
	"deals 25% less attack damage",
	"Damage rounds down, minimum 0",
]
const EXPOSED_FACTS := [
	"EXPOSED:",
	"for N turns",
	"takes 50% more attack damage",
	"Damage rounds down, minimum 0",
]
## Genuine authored base/+ cards read through the real metadata lookup. The
## third column is the catalog amount Help must never restate as the rule.
const STATUS_CASES := [
	["seamstress_prick", "bleed", 2],
	["seamstress_prick_plus", "bleed", 3],
	["warden_shield_bash", "weak", 1],
	["warden_shield_bash_plus", "weak", 1],
	["tinker_rivet_shot", "exposed", 1],
	["tinker_rivet_shot_plus", "exposed", 1],
	["seamstress_red_thread", "bleed", 6],
	["seamstress_red_thread_plus", "bleed", 8],
	["seamstress_hemorrhage_hem", "bleed_multiplier", 2],
	["seamstress_hemorrhage_hem_plus", "bleed_multiplier", 2],
]
## The exact short combat sentence each mounted face must draw, written out
## independently of the presenter: amounts, hit counts, block, healing, draw,
## energy/HP, statuses and the one/all/random recipient wording. Offensive
## effects read as compact clauses ("Deal 4. Exposed 1.", "Deal 3 to all.",
## "Deal 2 x3, random."), and support keeps compact recipient clauses.
const SHORT_LINES := {
	"warden_strike": "Deal 6.",
	"warden_strike_plus": "Deal 7.",
	"warden_brace": "Gain 7 Block.",
	"warden_brace_plus": "Gain 10 Block.",
	"warden_shield_bash": "Deal 8. Weak 1.",
	"warden_shield_bash_plus": "Deal 11. Weak 1.",
	"seamstress_prick": "Deal 3. Bleed 3.",
	"seamstress_prick_plus": "Deal 4. Bleed 3.",
	"seamstress_mend": "Heal ally 5 HP.",
	"seamstress_mend_plus": "Heal ally 7 HP.",
	"seamstress_stitch_up": "Ally gains 5 Block.",
	"seamstress_stitch_up_plus": "Ally gains 7 Block.",
	"tinker_pop_shot": "Deal 5.",
	"tinker_scrap_bomb": "Deal 4 to all.",
	"tinker_tune_up": "Draw 1.",
	"warden_hold_the_line": "Gain 5 Block. Other allies gain 2 Block.",
	"warden_hold_the_line_plus": "Gain 7 Block. Other allies gain 3 Block.",
	"warden_pinning_jab": "Deal 4. Pin.",
	"warden_draw_fire": "Gain 6 Block. Guard.",
	"warden_counter_stitch": "Gain 5 Block. Gain 3 Thorns.",
	"warden_seam_breaker": "Deal 7. Unravel 4.",
	"warden_pin_and_pound": "Deal 9 x2.",
	"warden_bastion_quilt": "All allies gain 10 Block.",
	"seamstress_running_stitch": "Deal 2. Bleed 4.",
	"seamstress_darning": "Heal ally 4 HP and grant 3 Block.",
	"seamstress_darning_plus": "Heal ally 6 HP and grant 4 Block.",
	"seamstress_snag": "Weak 1. Unravel 3.",
	"seamstress_hemorrhage_hem": "Double Bleed.",
	"seamstress_unpick": "Unravel 5.",
	"seamstress_blanket_stitch": "Bleed 3 to all.",
	"seamstress_field_mend": "Heal all allies 4 HP.",
	"seamstress_field_mend_plus": "Heal all allies 6 HP.",
	"seamstress_red_thread": "Exposed 1, Bleed 7.",
	"seamstress_tailors_trance": "Draw 2. Gain 1 energy.",
	"seamstress_tailors_trance_plus": "Draw 3. Gain 1 energy.",
	"tinker_rivet_shot": "Deal 4. Exposed 1.",
	"tinker_spring_trap": "Deal 3. Pin.",
	"tinker_spring_trap_plus": "Deal 4. Pin.",
	"tinker_scatter_bolts": "Deal 3 to all.",
	"tinker_spare_parts": "Gain 3 Block. Draw 1.",
	"tinker_spare_parts_plus": "Gain 4 Block. Draw 1.",
	"tinker_long_barrel": "Deal 12.",
	"tinker_spool_launcher": "Deal 3. Unravel 3.",
	"tinker_overclock": "Gain 1 energy. Lose 3 HP.",
	"tinker_overclock_plus": "Gain 1 energy. Lose 3 HP.",
	"tinker_shrapnel_seam": "Deal 5 to all. Unravel 2 to all.",
	"tinker_sight_glass": "Exposed 2. Draw 1.",
	"tinker_ricochet": "Deal 4 x3, random.",
	"tinker_bobbin_cannon": "Deal 20.",
	"tinker_snip_the_seam": "Deal 5, or 15 if Unravelled or half gauge.",
}
## The same line read from the authored record alone, for the cards whose printed
## amount comes from a published passive or confirmed-hit adapter. Proves the
## formatter itself never adds a bonus or infers a combat result.
const AUTHORED_LINES := {
	"seamstress_prick": "Deal 3. Bleed 2.",
	"seamstress_running_stitch": "Deal 2. Bleed 3.",
	"seamstress_running_stitch_plus": "Deal 3. Bleed 4.",
	"seamstress_blanket_stitch": "Bleed 2 to all.",
	"seamstress_blanket_stitch_plus": "Bleed 3 to all.",
	"seamstress_red_thread": "Exposed 1, Bleed 6.",
	"seamstress_red_thread_plus": "Exposed 1, Bleed 8.",
}
## The owner's three compact examples, formatted from authored-shaped records so
## the exact wording is checked even before an equal catalog card exists.
const OWNER_EXAMPLES := [
	{"target_kind": "enemy_single", "effects": {"damage": 4, "exposed": 1},
		"line": "Deal 4. Exposed 1."},
	{"target_kind": "enemy_all", "effects": {"damage": 3},
		"line": "Deal 3 to all."},
	{"target_kind": "enemy_random", "effects": {"damage": 2, "hit_count": 3,
		"random_target_each_hit": true}, "line": "Deal 2 x3, random."},
]
## Words the drawn face must never print: the precise from/target rows, the
## recipient adjective and the reward panel's old position wording.
const FACE_BANNED_WORDS := ["From", "Target", "living", "pick 1", "front", "middle", "back"]


var failures: Array[String] = []
var checks := 0
var saw_compact := false
var saw_tall := false
var app
var presenter
var catalog := StarterCards.new()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _occurrences(text: String, needle: String) -> int:
	return text.count(needle)


func _authored_number(metadata, card_id: String, key: String) -> int:
	var effects: Dictionary = metadata.definition(card_id).get("effects", {})
	return int(effects.get(key, -1))


func _authored_conditional_damage(metadata, card_id: String) -> int:
	var effects: Dictionary = metadata.definition(card_id).get("effects", {})
	var condition: Variant = effects.get("conditional_damage")
	return int(condition.get("damage", -1)) if condition is Dictionary else -1


## True only for a genuine positive authored status amount. A bleeding card may
## carry it directly or through the doubling multiplier descriptor.
func _authored_status(definition: Dictionary, status: String) -> bool:
	var raw_effects: Variant = definition.get("effects", {})
	if not raw_effects is Dictionary:
		return false
	var effects: Dictionary = raw_effects
	if status == "bleed":
		return _positive_effect(effects, "bleed") or _positive_effect(effects, "bleed_multiplier")
	return _positive_effect(effects, status)


func _positive_effect(effects: Dictionary, key: String) -> bool:
	var value: Variant = effects.get(key)
	return value is int and int(value) > 0


func _status_prefix(status: String) -> String:
	return "BLEED:" if status == "bleed_multiplier" else status.to_upper() + ":"


func _status_facts(status: String) -> Array:
	match status:
		"bleed", "bleed_multiplier":
			return BLEED_FACTS
		"weak":
			return WEAK_FACTS
		"exposed":
			return EXPOSED_FACTS
	return []


## The one Help line that begins with a status prefix, for amount assertions.
func _line_starting(text: String, prefix: String) -> String:
	for line in text.split("\n"):
		if line.begins_with(prefix):
			return line
	return ""


## Every keyword card keeps the ordinary header, source range and enemy target
## that were already printed before the appended explanation.
func _assert_keyword_frame(text: String, definition: Dictionary, label: String) -> void:
	var lines := text.split("\n")
	var header := "%s; %s; %d energy" % [str(definition.get("display_name", "")),
		str(definition.get("owner", "")).capitalize(), int(definition.get("cost", -1))]
	_check(lines.has(header), "keyword card keeps exact cost header: " + label)
	_check(lines.has("From " + _expected_positions(definition.get("from_positions", []))),
		"keyword card keeps exact source positions: " + label)
	_check(lines.has("To one selected enemy " + _expected_positions(definition.get("to_positions", []))),
		"keyword card keeps exact enemy target: " + label)


func _frames() -> void:
	await process_frame
	await process_frame


func _snapshot() -> Array:
	return [
		app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.intent_label.text, app.run_rng.seed, app.run_rng.state, app.run_seed,
	]


func _expected_positions(positions: Array) -> String:
	if positions.size() == 1:
		return str(positions[0])
	if positions.size() > 1:
		return "%s–%s" % [positions[0], positions.back()]
	return "?"


## The same recipient-slot sentence the tooltip's pip legend must state.
func _tooltip_target_slots(definition: Dictionary) -> String:
	var positions: Array = definition.get("to_positions", [])
	if not positions.is_empty():
		return _expected_positions(positions)
	match str(definition.get("target_kind", "")):
		"ally_single":
			return "any hero slot"
		"party_all":
			return "every hero"
		"self":
			return "this hero"
		"adjacent_ally":
			return "the adjacent hero"
	return "no target"


## Every authored ID of the four shared card catalogs, read from their own
## enumerators so a new pool entry can never be silently skipped.
func _all_catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.append_array(StarterCards.new().get_all_card_ids())
	ids.append_array(WardenPoolCards.new().get_all_card_ids())
	ids.append_array(SeamstressPoolCards.new().get_all_card_ids())
	for base_id in TinkerPoolCards.new().get_pool_card_ids():
		ids.append(base_id)
		ids.append(base_id + "_plus")
	return ids


## One deterministic, read-only formatter produces every face line: exact authored
## amounts, hit counts, all/random markers, energy/HP and an honest fallback for a
## field it cannot read. Nothing here plays a card, spends a resource, mutates a
## record or draws from the seeded run RNG.
func _formatter_check(metadata) -> void:
	var formatter = load("res://scripts/card_short_rules.gd")
	_check(formatter != null, "shared card short formatter loads")
	if formatter == null:
		return
	var before := _snapshot()
	seed(4517)
	var expected_global := randi()
	seed(4517)
	var seen := 0
	for card_id in SHORT_LINES:
		var definition: Dictionary = metadata.definition(card_id)
		_check(not definition.is_empty(), "terse-line catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var authored: Dictionary = definition.duplicate(true)
		var described: Dictionary = formatter.describe(definition)
		_check(described.get("known") == true and not bool(described.get("unknown", true)),
			"formatter reads the validated authored record: " + card_id)
		_check(definition == authored, "formatter never mutates its input record: " + card_id)
		var face: String = metadata.short_line(card_id)
		_check(face == str(SHORT_LINES[card_id]),
			"exact terse face line for %s: got '%s'" % [card_id, face])
		_check(face.ends_with(".") and not face.contains("·"),
			"face line is complete short sentences: " + card_id)
		for banned in FACE_BANNED_WORDS:
			_check(not face.contains(banned),
				"face line prints no '%s': %s" % [banned, card_id])
		seen += 1
	# The formatter itself never adds a published passive: the presenter supplies
	# that applied amount from the same validated record.
	for card_id in SHORT_LINES:
		var definition: Dictionary = metadata.definition(card_id)
		if definition.is_empty():
			continue
		var authored_line: String = formatter.line(definition)
		if AUTHORED_LINES.has(card_id):
			_check(authored_line == str(AUTHORED_LINES[card_id]),
				"authored-only line for %s: got '%s'" % [card_id, authored_line])
		else:
			_check(authored_line == str(SHORT_LINES[card_id]),
				"formatter and presenter agree for %s: got '%s'" % [card_id, authored_line])
	_check(seen >= CARD_FACTS.size(), "every required starter face was formatted")
	# Repeated calls are identical, and a caller mutating a returned phrase array
	# can never leak into the next description.
	var bomb: Dictionary = metadata.definition("tinker_scrap_bomb")
	var first: Dictionary = formatter.describe(bomb)
	(first["phrases"] as Array).append("SENTINEL")
	var second: Dictionary = formatter.describe(bomb)
	var third: Dictionary = formatter.describe(bomb)
	_check(not (second["phrases"] as Array).has("SENTINEL") and second == third,
		"formatter results are detached and deterministic")
	_check(String(first["line"]) == String(third["line"]),
		"repeated formatting returns the same line")
	# All-area, per-hit-random and repeated hits stay visibly distinct sentences.
	var bomb_line: String = formatter.line(bomb)
	var ricochet_line: String = formatter.line(metadata.definition("tinker_ricochet"))
	var pound_line: String = formatter.line(metadata.definition("warden_pin_and_pound"))
	_check(bomb_line == "Deal 4 to all."
		and ricochet_line == "Deal 4 x3, random."
		and pound_line == "Deal 9 x2.",
		"area, per-hit-random and repeated hits keep distinct sentences")
	_check(bomb_line.contains("to all") and not bomb_line.contains("random"),
		"an area cast names every enemy, never one random pick")
	_check(ricochet_line.contains("x3, random") and not ricochet_line.contains("to all"),
		"a per-hit random cast says so instead of claiming an area")
	_check(pound_line.contains("x2") and not pound_line.contains("to all")
		and not pound_line.contains("random"),
		"a repeated single-target hit claims no area or random cast")
	# The owner's three compact examples, formatted from authored-shaped records.
	for example in OWNER_EXAMPLES:
		var probe := {"id": "probe_owner_example", "target_kind": example["target_kind"],
			"effects": (example["effects"] as Dictionary).duplicate(true)}
		var probed: Dictionary = formatter.describe(probe)
		_check(probed.get("known") == true and not bool(probed.get("unknown", true))
			and str(probed.get("line", "")) == str(example["line"]),
			"owner compact example: '%s' -> '%s'" % [str(example["line"]),
				str(probed.get("line", ""))])
		_check(probe["effects"] == example["effects"],
			"compact example formatting mutates no authored record")
	# Conditional, Pin, Unravel and status-only cards keep their real amounts and
	# distinctions in the shorter phrases.
	_check(formatter.line(metadata.definition("tinker_snip_the_seam"))
		== "Deal 5, or 15 if Unravelled or half gauge.",
		"conditional damage keeps both authored amounts and its trigger")
	_check(formatter.line(metadata.definition("tinker_spring_trap")) == "Deal 3. Pin."
		and formatter.line(metadata.definition("warden_pinning_jab")) == "Deal 4. Pin."
		and not formatter.line(metadata.definition("tinker_spring_trap")).contains("+5"),
		"Pin names the keyword on the face and leaves its bonus to the Help glossary")
	_check(formatter.line(metadata.definition("warden_seam_breaker")) == "Deal 7. Unravel 4."
		and formatter.line(metadata.definition("seamstress_unpick")) == "Unravel 5.",
		"Unravel keeps its authored gauge amount")
	_check(formatter.line(metadata.definition("seamstress_snag")) == "Weak 1. Unravel 3."
		and formatter.line(metadata.definition("seamstress_red_thread")) == "Exposed 1, Bleed 6.",
		"status-only attacks stay statuses, never an invented damage clause")
	# An authored field the formatter cannot read is reported honestly instead of
	# being rendered as an invented number.
	var mystery := {"id": "probe_mystery_card", "target_kind": "enemy_single",
		"effects": {"damage": 2, "mystery_damage": 9}}
	var mystery_line: String = formatter.line(mystery)
	_check(mystery_line == ("Deal 2. Other authored effects are not described."),
		"unknown effect field falls back honestly: " + mystery_line)
	_check(formatter.has_unknown(mystery)
		and not formatter.has_unknown(metadata.definition("warden_strike")),
		"unknown-field detection only fires for unrecognized authoring")
	_check(not mystery_line.contains("9") and not mystery_line.contains("mystery"),
		"unknown field never prints an invented amount or its raw key")
	_check(formatter.line({"effects": {"damage": "6"}})
		== "Other authored effects are not described.",
		"an unreadable authored amount is reported, never printed")
	for effects in [{"block": "5"}, {"draw": "2"}, {"energy": "1"},
			{"heal": {"amount": "4", "target": "weakest_living_ally"}}]:
		_check(formatter.line({"target_kind": "ally_single", "effects": effects})
			== "Other authored effects are not described.",
			"malformed support amount keeps honest fallback: " + str(effects))
	_check(formatter.line({"target_kind": "enemy_single", "effects": {
		"heal": {"amount": 3, "target": "weakest_living_ally", "cap": "missing_hp"}}})
		== "Heal weakest ally 3 HP (up to missing HP).",
		"descriptor heal keeps its own recipient and missing-HP cap")
	_check(formatter.line({"action_kind": "adjacent_swap", "effects": {}})
		== "Swap with adjacent ally.", "movement stays adjacent and concise")
	_check(formatter.line({}) == "" and formatter.describe({}).get("known") == false,
		"an empty record is not a known card")
	_check(formatter.line(null) == "" and formatter.describe([]).get("known") == false,
		"a non-dictionary record is not a known card")
	# Every authored catalog record keeps a readable terse line, not just the
	# required starter nine.
	var catalog_ids := _all_catalog_ids()
	_check(not catalog_ids.is_empty(), "the shared catalogs enumerate authored cards")
	for card_id in catalog_ids:
		var line: String = metadata.short_line(card_id)
		_check(not line.is_empty(), "every authored card keeps a terse face line: " + card_id)
		_check(line.ends_with(".") and line.substr(0, 1) == line.substr(0, 1).to_upper()
			and not line.contains("·"),
			"every authored face is a complete short sentence: " + card_id + " (" + line + ")")
		for banned in FACE_BANNED_WORDS:
			_check(not line.contains(banned),
				"no '%s' on the face line: %s" % [banned, card_id])
	_check(randi() == expected_global, "the short formatter draws no global RNG")
	_check(_snapshot() == before, "short-line formatting mutates no live model")


## The compact target badge text for a validated Warden Path record.
func _warden_target_line(card: Dictionary) -> String:
	match str(card.get("target_kind", "")):
		"self":
			return "Self"
		"enemy_single":
			return "To enemy " + _expected_positions(card.get("to_positions", []))
	return "Unknown target"


## The precise tooltip target line for a validated Warden Path record.
func _warden_tooltip_target_line(card: Dictionary) -> String:
	match str(card.get("target_kind", "")):
		"self":
			return "Self"
		"enemy_single":
			return "To one selected enemy " + _expected_positions(card.get("to_positions", []))
	return "Unknown target"


## The picture the real loader must pick for a Warden Path record: its authored
## illustration, then its own card art, then the owner emblem. Read from the
## actual files so the test never assumes an optional PNG is absent.
func _expected_warden_picture(card: Dictionary) -> String:
	var authored := str(card.get("illustration_path", ""))
	if not authored.is_empty() and ResourceLoader.exists(authored):
		return authored
	var own := ART_DIR + "cards/art/%s.png" % str(card.get("id", ""))
	if ResourceLoader.exists(own):
		return own
	var emblem := ART_DIR + "cards/emblem_%s.png" % str(card.get("owner", ""))
	if ResourceLoader.exists(emblem):
		return emblem
	return ""


func _catalog_facts() -> void:
	for card_id in CARD_FACTS:
		var authored: Array = CARD_FACTS[card_id]
		var definition: Dictionary = catalog.get_definition(card_id)
		_check(not definition.is_empty(), "required catalog entry exists: " + card_id)
		if definition.is_empty():
			continue
		_check(definition.get("owner") == authored[0], "catalog owner exact: " + card_id)
		_check(definition.get("cost") == authored[1], "catalog cost exact: " + card_id)
		_check(definition.get("from_positions") == authored[2], "catalog source positions exact: " + card_id)
		_check(definition.get("target_kind") == authored[3], "catalog target kind exact: " + card_id)
		_check(definition.get("to_positions") == authored[4], "catalog destination exact: " + card_id)


func _panels() -> Array[Node]:
	return app.hand_view.get_children() if is_instance_valid(app.hand_view) else []


## The sewn face of an ordinary known starter card: its owner's felt frame, its
## own committed picture in the upper face, and every rules row, pip and the
## cost coin clear of that picture.
func _assert_sewn_face(metadata, panel: Control, card_id: String, definition: Dictionary,
		geometry: Dictionary) -> void:
	var owner: String = str(definition.get("owner", ""))
	_check(owner in ["warden", "seamstress", "tinker"],
		"held starter card really has a sewn owner: " + card_id)
	var frame_path: String = ART_DIR + "ui/card_frame_%s.png" % owner
	var art_path: String = ART_DIR + "cards/art/%s.png" % card_id
	var faces: Dictionary = metadata.get_faces(panel)
	var frame: Variant = faces.get("frame")
	var picture: Variant = faces.get("picture")
	_check(frame is Texture2D and faces.get("frame_path") == frame_path,
		"mounted panel wears its owner's sewn frame: " + card_id)
	_check(picture is Texture2D and faces.get("picture_path") == art_path,
		"mounted panel shows its own committed picture: " + card_id)
	_check(ResourceLoader.exists(frame_path) and ResourceLoader.exists(art_path),
		"both named sewn assets are real loadable files: " + card_id)
	_check(frame is Texture2D and frame.get_width() > 0 and frame.get_height() > 0
		and picture is Texture2D and picture.get_width() > 0 and picture.get_height() > 0,
		"sewn textures really loaded their pixels: " + card_id)
	_check(geometry.get("sewn") == true, "real panel measures the sewn face: " + card_id)
	var bounds := Rect2(Vector2.ZERO, panel.size)
	var art: Rect2 = geometry.get("art", Rect2())
	var owner_rect: Rect2 = geometry["owner"]
	var cost: Rect2 = geometry["cost"]
	var title: Rect2 = geometry["title"]
	var footer: Rect2 = geometry["footer"]
	_check(art.size.x > 0.0 and art.size.y > 0.0 and bounds.encloses(art),
		"illustration band has real area inside the card: " + card_id)
	_check(art.end.y <= cost.position.y and art.end.y <= footer.position.y,
		"illustration sits in the upper face above the cost and the rules: " + card_id)
	for pair in [["owner tag", owner_rect], ["cost coin", cost], ["name", title], ["rules", footer]]:
		_check(not art.intersects(pair[1]), "artwork never covers the %s: %s" % [pair[0], card_id])
	var rows: Dictionary = geometry.get("rows", {})
	_check(rows.size() == 3, "rules face reserves source, target and rule rows: " + card_id)
	if rows.size() != 3:
		return
	var source: Rect2 = rows["from"]
	var target: Rect2 = rows["target"]
	var rules: Rect2 = rows["rules"]
	_check(footer.encloses(source) and footer.encloses(target) and footer.encloses(rules),
		"every text row stays inside the lower rules block: " + card_id)
	_check(source.size.y > 0.0 and target.size.y > 0.0 and rules.size.y > 0.0,
		"each text row keeps real drawn height: " + card_id)
	_check(source.end.y <= target.position.y and target.end.y <= rules.position.y,
		"source and target text rows never overlap: " + card_id)
	_check(source.size.y >= 8.0 and target.size.y >= 8.0 and rules.size.y >= 8.0,
		"every refitted text row still has room for its font: " + card_id)


## Assert the actual bound painter facts and rects, not a parallel layout
## implementation. Every ordered half keeps its own authentic catalog slots.
func _assert_stitched_face(metadata, panel: Control, stitched_id: String, pair: Array) -> void:
	var facts: Dictionary = metadata.get_facts(panel)
	var faces: Dictionary = metadata.get_faces(panel)
	var geometry: Dictionary = metadata.get_geometry(panel)
	var halves: Array = faces.get("halves", [])
	var rows: Array = geometry.get("halves", [])
	var details: Array = geometry.get("half_details", [])
	_check(bool(facts.get("known", false)) and facts.get("id") == stitched_id
		and facts.get("owner") == "" and facts.get("owner_text") == "Stitched"
		and facts.get("halves") == pair,
		"mounted stitched facts keep two ordered halves, never a whole owner")
	var first: Dictionary = metadata.definition(str(pair[0]))
	var second: Dictionary = metadata.definition(str(pair[1]))
	_check(not first.is_empty() and not second.is_empty()
		and first.get("owner") != second.get("owner"), "stitched assertion has real different owners")
	_check(int(facts.get("cost", -1)) == mini(3, maxi(
		int(first.get("cost", -1)), int(second.get("cost", -1))) + 1),
		"stitched face has the one genuine capped composite cost")
	_check(faces.get("frame") == null and faces.get("picture") == null
		and faces.get("frame_path") == "" and faces.get("picture_path") == "",
		"whole stitched card does not borrow a sole-owner frame or picture")
	_check(halves.size() == 2 and rows.size() == 2 and details.size() == 2,
		"both ordered sewn art/pip records and drawn rows exist in the mounted panel")
	if halves.size() != 2 or details.size() != 2 or rows.size() != 2:
		return
	var bounds := Rect2(Vector2.ZERO, panel.size)
	for index in range(2):
		var id: String = str(pair[index])
		var definition: Dictionary = metadata.definition(id)
		var expected: Dictionary = metadata.face_assets(id)
		var face: Dictionary = halves[index]
		var detail: Dictionary = details[index]
		var region: Rect2 = rows[index]
		_check(face.get("id") == id and face.get("owner") == definition.get("owner")
			and face.get("colour") == metadata._owner_color(str(definition.get("owner", ""))),
			"sewn half %d has its own ordered ID and owner swatch" % (index + 1))
		_check(face.get("frame_path") == expected.get("frame_path")
			and face.get("picture_path") == expected.get("picture_path")
			and face.get("frame") == expected.get("frame")
			and face.get("picture") == expected.get("picture"),
			"sewn half %d resolves only its own cached authored art/emblem/frame" % (index + 1))
		_check(face.get("frame") is Texture2D and face.get("picture") is Texture2D,
			"sewn half %d uses its available existing image files" % (index + 1))
		_check(face.get("from_positions") == definition.get("from_positions", [])
			and face.get("to_positions") == definition.get("to_positions", [])
			and detail.get("from_positions") == definition.get("from_positions", [])
			and detail.get("to_positions") == definition.get("to_positions", []),
			"half %d paints independent authored source/target pip data" % (index + 1))
		var art: Rect2 = detail["art"]
		var name: Rect2 = detail["name"]
		var effect: Rect2 = detail["effect"]
		var pips: Rect2 = detail["pips"]
		_check(bounds.encloses(region) and region.encloses(art) and region.encloses(name)
			and region.encloses(effect) and region.encloses(pips),
			"half %d image/name/effect/pips all fit within its mounted row" % (index + 1))
		_check(art.size.x > 0 and art.size.y > 0 and name.size.x >= 80.0
			and effect.size.x >= 120.0 and effect.size.y >= 8.0
			and pips.size.x >= 45.0 and pips.size.y >= 8.0,
			"half %d keeps readable text and an independent six-pip cell" % (index + 1))
		_check(not art.intersects(name) and not art.intersects(effect)
			and not art.intersects(pips) and not pips.intersects(name)
			and not pips.intersects(effect),
			"half %d picture and source/target pips cannot cover its name/effect" % (index + 1))
		_check(metadata.short_line(id) != "" and not definition.get("display_name", "").is_empty(),
			"half %d has an authored printed name/effect" % (index + 1))
	_check(not rows[0].intersects(rows[1]) and geometry["cost"] is Rect2
		and bounds.encloses(geometry["cost"])
		and not geometry["cost"].intersects(rows[0])
		and not geometry["cost"].intersects(rows[1]),
		"stitched face retains one clear shared cost coin outside both halves")
	var tooltip: String = panel.tooltip_text
	var authored_halves: String = "1. " + metadata.base_effect_text(str(pair[0])) \
		+ "\n2. " + metadata.base_effect_text(str(pair[1]))
	var shared_note := tooltip.substr(authored_halves.length()) if tooltip.begins_with(authored_halves) else ""
	_check(tooltip.begins_with(authored_halves)
		and shared_note.begins_with("\nSTITCHED: %d energy total" % int(facts.get("cost", -1)))
		and shared_note.count("\nSTITCHED:") == 1
		and shared_note.contains("pay energy and discard the composite ONCE")
		and shared_note.contains("Both owners must be alive")
		and shared_note.contains("independent legal targets"),
		"mounted hover tooltip keeps both full numbered halves then the one authentic shared rule")
	_check(tooltip.find("1. " + str(first.get("display_name", ""))) == 0
		and tooltip.find("\n2. " + str(second.get("display_name", ""))) > 0,
		"mounted hover tooltip preserves authentic half order")
	# Each half's status rules appear once, in its own numbered half, in order;
	# the drawn face keeps both unchanged short lines and no long rule.
	var numbered_halves := tooltip.split("\n2. ")
	_check(numbered_halves.size() == 2, "stitched tooltip still splits into two numbered halves")
	if numbered_halves.size() == 2:
		for index in range(2):
			var half_id: String = str(pair[index])
			var half_definition: Dictionary = metadata.definition(half_id)
			var segment: String = str(numbered_halves[index])
			for status in ["bleed", "weak", "exposed"]:
				var expected: int = 1 if _authored_status(half_definition, status) else 0
				_check(_occurrences(segment, _status_prefix(status)) == expected,
					"stitched half %d carries %s rules exactly when authored" % [index + 1, status])
	var face_rules: String = str(facts.get("rules", ""))
	_check(face_rules == "1. %s · 2. %s"
		% [metadata.short_line(str(pair[0])), metadata.short_line(str(pair[1]))],
		"mounted stitched face keeps both unchanged short lines")
	_check(not face_rules.contains("BLEED:") and not face_rules.contains("WEAK:")
		and not face_rules.contains("EXPOSED:"),
		"mounted stitched face prints no long status rule")
	_check(int(metadata._bindings[panel].get("draw_count", 0)) > 0,
		"real stitched panel actually received CanvasItem draw callbacks")


## Texture resolution is grounded in authored catalogs: base/+ reuse,
## emblem fallback, and no sole-owner assets for unknown stitched IDs.
func _art_resolution_check() -> void:
	var metadata = load(HAND_SCRIPT).new()
	_check(metadata != null, "shared hand metadata script loads for texture resolution")
	if metadata == null:
		return
	var plus_id := "warden_strike_plus"
	var plus: Dictionary = metadata.definition(plus_id)
	_check(not plus.is_empty() and str(plus.get("display_name", "")).ends_with("+"),
		"chosen upgrade really is a recognized '+' card: " + plus_id)
	var plus_faces: Dictionary = metadata.face_assets(plus_id)
	var base_faces: Dictionary = metadata.face_assets("warden_strike")
	_check(plus_faces.get("picture_path") == ART_DIR + "cards/art/warden_strike.png",
		"recognized '+' resolves the base card's committed picture: " + plus_id)
	_check(plus_faces.get("frame_path") == ART_DIR + "ui/card_frame_warden.png",
		"recognized '+' keeps its owner's sewn frame: " + plus_id)
	_check(plus_faces.get("picture") is Texture2D and plus_faces.get("picture") == base_faces.get("picture"),
		"the base and its '+' share the one cached base picture")
	_check(ResourceLoader.exists(str(plus_faces.get("picture_path"))),
		"resolved base picture really exists on disk")
	# Only a final '_plus' is stripped, and every authored upgrade resolves.
	for entry in [["warden_brace_plus", "warden_brace"], ["seamstress_mend_plus", "seamstress_mend"],
			["seamstress_stitch_up_plus", "seamstress_stitch_up"]]:
		var upgraded: Dictionary = metadata.face_assets(str(entry[0]))
		_check(upgraded.get("picture_path") == ART_DIR + "cards/art/%s.png" % str(entry[1]),
			"recognized upgrade strips only its final _plus: " + str(entry[0]))
	# Known pool cards have no bespoke picture: they show their owner's emblem.
	for entry in [["warden_hold_the_line", "warden"], ["seamstress_needle_pin", "seamstress"],
			["tinker_ricochet", "tinker"]]:
		var card_id := str(entry[0])
		var owner := str(entry[1])
		var definition: Dictionary = metadata.definition(card_id)
		_check(not definition.is_empty() and str(definition.get("owner", "")) == owner,
			"chosen pool card is a known authored record: " + card_id)
		var faces: Dictionary = metadata.face_assets(card_id)
		_check(faces.get("frame_path") == ART_DIR + "ui/card_frame_%s.png" % owner,
			"pool card keeps its owner's sewn frame: " + card_id)
		_check(faces.get("picture_path") == ART_DIR + "cards/emblem_%s.png" % owner,
			"pool card without a bespoke picture falls back to the owner emblem: " + card_id)
		_check(ResourceLoader.exists(str(faces.get("picture_path"))),
			"owner emblem really exists on disk: " + card_id)
	# Ordinary starter art is resolved through the same, cached loader.
	var strike_faces: Dictionary = metadata.face_assets("warden_strike")
	var cached: Variant = metadata._textures.get(str(strike_faces.get("picture_path")))
	_check(metadata._textures.has(str(strike_faces.get("picture_path")))
		and cached == strike_faces.get("picture") and strike_faces.get("picture") is Texture2D,
		"resolved picture is loaded once and cached by its path")
	# Stitched and unknown IDs never borrow a single owner's felt or picture.
	var stitched: Dictionary = metadata.face_assets(RunRestStitchCards.ID_PREFIX + "1")
	_check(stitched.get("frame") == null and stitched.get("picture") == null
		and str(stitched.get("frame_path", "x")) == "",
		"stitched ID keeps the drawn halves face with no false owner")
	var unknown: Dictionary = metadata.face_assets("unreleased_card")
	_check(unknown.get("frame") == null and unknown.get("picture") == null,
		"unknown ID borrows no sewn face at all")
	var first_owner := str(metadata.definition("warden_brace").get("owner", ""))
	var second_owner := str(metadata.definition("seamstress_mend").get("owner", ""))
	_check(first_owner != second_owner
		and metadata._owner_color(first_owner) != metadata._owner_color(second_owner)
		and metadata._owner_color(first_owner) != metadata.INK
		and metadata._owner_color(second_owner) != metadata.INK,
		"both stitched halves keep distinct honest owner colours")
	# The drawn two-half face is still exactly what a stitched card measures.
	var plain: Dictionary = metadata.card_layout(Vector2(230.0, 160.0), false)
	var plain_rows: Array = plain.get("halves", [])
	var plain_art: Rect2 = plain.get("art", Rect2())
	_check(plain.get("sewn") == false and plain_rows.size() == 2
		and plain_rows[0].size.y >= 30.0 and plain_rows[1].size.y >= 30.0
		and plain_rows[0].end.y <= plain_rows[1].position.y
		and plain_art.size.x == 0.0,
		"stitched card face keeps two ordered, non-overlapping sewn rows and no picture band")
	var sewn: Dictionary = metadata.card_layout(Vector2(230.0, 160.0), true)
	var sewn_rows: Array = sewn.get("halves", [])
	var sewn_art: Rect2 = sewn.get("art", Rect2())
	_check(bool(sewn.get("sewn", false)) and sewn_rows.is_empty() and sewn_art.size.y > 0.0,
		"only an ordinary owned card measures the single sewn face with its picture band")


## The renderer paints the frame and picture before any text or the cost coin, so
## the artwork can never obscure what it belongs to, and it names only the
## ready-made asset paths.
func _source_check() -> void:
	var file := FileAccess.open(HAND_SCRIPT, FileAccess.READ)
	_check(file != null, "shared hand metadata source readable")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	for marker in ["\"ui/card_frame_%s.png\"", "\"cards/art/%s.png\"", "\"cards/emblem_%s.png\""]:
		_check(text.contains(marker), "renderer resolves the ready-made asset: " + marker)
	_check(text.contains("trim_suffix(\"_plus\")"), "only a final _plus suffix is stripped for art")
	var draw_start := text.find("func _draw_panel(")
	_check(draw_start >= 0, "renderer defines its panel drawing")
	if draw_start < 0:
		return
	var following := text.find("\nfunc ", draw_start + 1)
	var draw := text.substr(draw_start, text.length() - draw_start if following < 0 else following - draw_start)
	var art_at := draw.find("_draw_illustration(")
	var cost_at := draw.find("panel.draw_circle(cost.get_center()")
	var owner_at := draw.find("facts.get(\"owner_text\"")
	_check(art_at >= 0, "panel drawing paints the illustration")
	_check(cost_at > art_at and owner_at > art_at,
		"the picture is painted before the cost coin and owner text it must never cover")
	# The drawn faces print the pips and the terse authored line, never the
	# precise from/target rows (those stay in the hover tooltip).
	for name in ["_draw_half", "_draw_sewn_half"]:
		var body := _function_body(text, name)
		_check(not body.is_empty(), "renderer defines " + name)
		_check(not body.contains("from_text") and not body.contains("target_text"),
			"%s prints no from/target row" % name)
		_check(body.contains("_rules("), name + " prints the terse formatter line")
	_check(_function_body(text, "_draw_half").contains("_draw_pips("),
		"the ordinary sewn face still paints its legality pips")
	var pips := _function_body(text, "_draw_pips")
	_check(pips.count("range(1, 4)") == 2 and pips.contains("draw_circle")
		and pips.contains("draw_rect"),
		"the face paints three source circles and three target squares")
	_check(pips.contains("draw_dashed_line") and pips.contains("\"enemy_all\""),
		"all-enemy target squares are threaded together on the face")
	_check(_function_body(text, "base_effect_text").contains("_pip_legend("),
		"the hover tooltip explains the pips and their legal slots")
	_check(text.contains("CardShortRules.line("),
		"the drawn face line comes from the shared short formatter")
	_check(text.contains('"PatchHeading"'), "renderer references master PatchHeading font variation")
	_check(text.contains("func name_font(") and text.contains("func body_font("),
		"renderer exposes name_font and body_font helpers")
	_check(text.contains("_name_font(panel)"), "renderer routes name font selection through _name_font")
	var draw_half_src := _function_body(text, "_draw_half")
	_check(draw_half_src.contains("_name_font(panel)"), "_draw_half draws half name with _name_font")
	var draw_sewn_half_src := _function_body(text, "_draw_sewn_half")
	_check(draw_sewn_half_src.contains("_name_font(panel)"), "_draw_sewn_half draws compact half name with _name_font")
	var draw_panel_src := _function_body(text, "_draw_panel")
	_check(draw_panel_src.contains("_name_font(panel)"), "_draw_panel draws card title with _name_font")


## The exact source of one GDScript function, for presentation-only assertions.
func _function_body(text: String, name: String) -> String:
	var start := text.find("func " + name + "(")
	if start < 0:
		return ""
	var next := text.find("\nfunc ", start + 1)
	return text.substr(start, text.length() - start if next < 0 else next - start)


func _validate_display(observed: Dictionary) -> void:
	_check(app.deck is CombatDeck and app.battle_view != null and app.hand_view != null,
		"authoritative run and mounted battle/hand exist")
	if app.deck == null or app.hand_view == null:
		return
	var panels := _panels()
	_check(panels.size() == app.deck.hand.size(), "exact live hand count")
	_check(panels.size() > 0, "nonvacuous current card panels")
	var metadata = presenter._metadata
	_check(metadata._bindings.size() == panels.size(), "one drawing binding per current panel")
	var ids: Array[String] = []
	var initial_display := observed.is_empty()
	for index in range(panels.size()):
		var panel := panels[index] as Control
		_check(panel != null and panel is PanelContainer and panel.is_visible_in_tree(),
			"actual visible PanelContainer")
		if panel == null or panel.get_child_count() == 0:
			_check(false, "panel's original Label exists")
			continue
		var original := panel.get_child(0) as Label
		_check(original != null and not original.is_visible_in_tree(), "identity child retained but raw ID never rendered")
		if original == null:
			continue
		var card_id: String = original.text
		ids.append(card_id)
		observed[card_id] = true
		_check(index < app.deck.hand.size() and card_id == app.deck.hand[index],
			"original unchanged ID text equals ordered deck.hand")
		var support: bool = card_id in SUPPORT_IDS
		_check(panel.get_child_count() == 1,
			"each panel retains only its original ID Label; help lives outside the hand")
		if support:
			_check(presenter.help_label.text == presenter.TABLE_HELP,
				"shared visible support action hint survives outside card names")
			_check(panel.tooltip_text.begins_with("Click or focus and press Enter / Space to play"), "support hint preserved")
			_check(panel.tooltip_text.contains("BASE"), "support tooltip includes base effect detail")
		var attack: bool = catalog.get_definition(card_id).get("target_kind") in ["enemy_single", "enemy_all"]
		_check(panel.gui_input.get_connections().size() == (1 if support or attack else 0),
			"exactly one handler for support or held attack; remaining inert cards have none")
		_check(panel.focus_mode == (Control.FOCUS_ALL if support else Control.FOCUS_NONE),
			"support focusability and inert non-support focus preserved")
		_check(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "card remains mouse hit-testable")
		_check(metadata._bindings.has(panel), "presenter keyed by actual live panel instance")
		if not metadata._bindings.has(panel):
			continue
		var binding: Dictionary = metadata._bindings[panel]
		_check(binding["id"] == card_id, "presenter keyed by unchanged original card ID")
		_check(panel.draw.get_connections().size() == 1
			and panel.draw.is_connected(binding["draw"]), "one exact CanvasItem draw callback")
		_check(panel.resized.get_connections().size() == 1
			and panel.tree_exiting.is_connected(binding["exit"]),
			"one resize/exit cleanup callback")
		_check(binding["draw_count"] > 0, "CanvasItem actually drew paper details")
		var expected: Array = CARD_FACTS.get(card_id, [])
		_check(not expected.is_empty(), "drawn held ID is a required catalog card")
		if expected.is_empty():
			continue
		var facts: Dictionary = metadata.get_facts(panel)
		var definition := catalog.get_definition(card_id)
		_check(facts.get("known") == true and facts.get("id") == card_id,
			"badge is from actual present catalog ID")
		_check(facts.get("owner") == definition.owner and facts.get("owner_text") == definition.owner.capitalize(),
			"owner badge matches unmodified catalog")
		_check(facts.get("cost") == definition.cost and facts.get("cost_text") == "Cost %d" % definition.cost,
			"cost badge matches unmodified catalog")
		_check(facts.get("from_text") == "From " + _expected_positions(definition.from_positions),
			"authored source positions printed")
		var target_line: String = TARGET_LINES[definition.target_kind]
		if definition.target_kind in ["enemy_single", "enemy_all"]:
			target_line += _expected_positions(definition.to_positions)
		_check(facts.get("target_text") == target_line, "authored enemy/ally/self/no-target line printed")
		# The drawn face is the terse formatter line, never a from/target sentence.
		var expected_short: String = str(SHORT_LINES.get(card_id, ""))
		_check(not expected_short.is_empty() and facts.get("rules") == expected_short,
			"mounted face draws the exact terse authored line: " + card_id)
		for banned in FACE_BANNED_WORDS:
			_check(not str(facts.get("rules", "")).contains(banned),
				"mounted face prints no '%s': %s" % [banned, card_id])
		# Tooltip verifies the base effect text for every held card.
		var tooltip_text := panel.tooltip_text
		var tooltip_lines := tooltip_text.split("\n")
		var header_line := "%s; %s; %d energy" % [definition.display_name, definition.owner.capitalize(), definition.cost]
		_check(tooltip_lines.has(header_line), "tooltip exact header line: " + card_id)
		var from_line := "From " + _expected_positions(definition.from_positions)
		_check(tooltip_lines.has(from_line), "tooltip exact from line: " + card_id)
		var tooltip_target_line := ""
		match definition.target_kind:
			"enemy_single":
				tooltip_target_line = "To one selected enemy"
				if not definition.to_positions.is_empty():
					tooltip_target_line += " " + _expected_positions(definition.to_positions)
			"enemy_all":
				tooltip_target_line = "All enemies"
				if not definition.to_positions.is_empty():
					tooltip_target_line += " " + _expected_positions(definition.to_positions)
			"self":
				tooltip_target_line = "Self"
			"ally_single":
				tooltip_target_line = "Choose one living ally"
			"none":
				tooltip_target_line = "No target"
		_check(tooltip_lines.has(tooltip_target_line), "tooltip exact target line: " + card_id)
		# The hover tooltip is the one place that spells the painted pips out.
		var target_slot_phrase: String
		if definition.to_positions.is_empty():
			target_slot_phrase = "no target square is filled (%s)" % _tooltip_target_slots(definition)
		else:
			target_slot_phrase = "■ filled = a legal target slot (%s)" % _tooltip_target_slots(definition)
		_check(tooltip_text.contains("PIPS: ● filled = a slot this hero may play from (%s)"
			% _expected_positions(definition.from_positions))
			and tooltip_text.contains(target_slot_phrase),
			"tooltip explains the six pips and their exact legal slots: " + card_id)
		if definition.target_kind == "enemy_all":
			_check(tooltip_text.contains("the thread stitches every enemy square (ALL = all of them)"),
				"tooltip explains the all-enemy stitch: " + card_id)
		_check(tooltip_text.contains("BASE"), "tooltip states base effect: " + card_id)
		# Exact per-required-ID tooltip assertions for the nine authored cards.
		if card_id == "warden_strike":
			_check(tooltip_text.contains("BASE deal 6 damage"), "exact strike damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1\u20132"), "exact strike target: " + card_id)
		elif card_id == "warden_brace":
			_check(tooltip_text.contains("BASE gain 7 Block"), "exact brace block: " + card_id)
			_check(tooltip_text.contains("Self"), "exact brace target: " + card_id)
		elif card_id == "warden_shield_bash":
			_check(tooltip_text.contains("BASE deal 8 damage"), "exact bash damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1"), "exact bash target: " + card_id)
			_check(tooltip_lines.has("BASE deal 8 damage; ON CONFIRMED HIT add Weak 1"),
				"Shield Bash exact authored confirmed-hit Weak rule, not generic status")
			_check(_occurrences(tooltip_text, "WEAK:") == 1
				and tooltip_text.contains(metadata.WEAK_EXPLANATION)
				and _occurrences(tooltip_text, "BLEED:") == 0
				and _occurrences(tooltip_text, "EXPOSED:") == 0,
				"live Shield Bash Help explains exactly its authored Weak rule")
		elif card_id == "seamstress_prick":
			_check(tooltip_text.contains("BASE deal 3 damage"), "exact prick damage: " + card_id)
			_check(tooltip_lines.has("BASE deal 3 damage; ON CONFIRMED HIT add Bleed 3 (authored Bleed 2 + Seamstress passive 1)"),
				"Prick exact confirmed-hit stack derives authored 2 plus passive 1")
			_check(tooltip_text.contains("To one selected enemy 1\u20133"), "exact prick target: " + card_id)
			_check(_occurrences(tooltip_text, "BLEED:") == 1
				and tooltip_text.contains(metadata.BLEED_EXPLANATION)
				and _occurrences(tooltip_text, "WEAK:") == 0
				and _occurrences(tooltip_text, "EXPOSED:") == 0,
				"live Prick Help explains exactly its passive-adjusted Bleed rule")
			_check(_line_starting(tooltip_text, "BLEED:").contains("loses N HP")
				and not _line_starting(tooltip_text, "BLEED:").contains("lose 3 HP"),
				"live Prick Bleed rule stays generic, never claiming the applied 3")
		elif card_id == "seamstress_mend":
			_check(tooltip_text.contains("BASE heal 5 HP, capped at max HP"), "exact mend heal with cap: " + card_id)
			_check(tooltip_text.contains("Choose one living ally"), "exact mend living ally: " + card_id)
		elif card_id == "seamstress_stitch_up":
			_check(tooltip_text.contains("BASE gain 5 Block"), "exact stitch block: " + card_id)
			_check(tooltip_text.contains("Choose one living ally"), "exact stitch living ally: " + card_id)
		elif card_id == "tinker_pop_shot":
			_check(tooltip_text.contains("BASE deal 5 damage"), "exact pop shot damage: " + card_id)
			_check(tooltip_text.contains("To one selected enemy 1\u20133"), "exact pop shot target: " + card_id)
		elif card_id == "tinker_scrap_bomb":
			_check(tooltip_text.contains("BASE deal 4 damage"), "exact scrap bomb damage: " + card_id)
			_check(tooltip_text.contains("All enemies 1\u20133"), "exact scrap bomb all-enemies target: " + card_id)
		elif card_id == "tinker_tune_up":
			_check(tooltip_text.contains("BASE draw 1 card"), "exact tune draw: " + card_id)
			_check(tooltip_text.contains("No target"), "exact tune no target: " + card_id)
		if card_id in ["warden_strike", "tinker_pop_shot", "tinker_scrap_bomb"]:
			_check(not tooltip_text.contains("ON CONFIRMED HIT") and not tooltip_text.contains("Bleed")
				and not tooltip_text.contains("Weak"), "neutral attack never claims a debuff: " + card_id)
		# Support cards: exact instruction plus appended effect detail.
		if card_id in SUPPORT_IDS:
			_check(tooltip_text.begins_with("Click or focus and press Enter / Space to play"), "support exact instruction preserved: " + card_id)
			_check(tooltip_text.contains("BASE"), "support tooltip contains base effect: " + card_id)
			if card_id == "warden_brace":
				_check(tooltip_text.contains("BASE gain 7 Block"), "support brace effect exact: " + card_id)
			elif card_id == "tinker_tune_up":
				_check(tooltip_text.contains("BASE draw 1 card"), "support tune effect exact: " + card_id)
			elif card_id == "seamstress_mend":
				_check(tooltip_text.contains("BASE heal 5 HP, capped at max HP"), "support mend effect exact: " + card_id)
			elif card_id == "seamstress_stitch_up":
				_check(tooltip_text.contains("BASE gain 5 Block"), "support stitch effect exact: " + card_id)
		var geometry: Dictionary = metadata.get_geometry(panel)
		if not geometry.is_empty():
			if geometry["compact"]:
				saw_compact = true
			else:
				saw_tall = true
		_check(not geometry.is_empty() and panel.size.x >= 88 and panel.size.y >= 30,
			"actual compact or tall panel fits its measured badge geometry")
		var bounds := Rect2(Vector2.ZERO, panel.size)
		for key in ["owner", "cost", "footer"]:
			if geometry.has(key):
				var rect: Rect2 = geometry[key]
				_check(rect.size.x > 0 and rect.size.y > 0 and bounds.encloses(rect),
					"all %s paper/felt drawing stays inside live panel" % key)
			else:
				_check(false, "required badge geometry exists: " + key)
		if not geometry.is_empty():
			_check(geometry["owner"].end.x < geometry["cost"].position.x,
				"owner and cost patches do not overlap")
			_check(geometry["footer"].position.y > geometry["owner"].end.y,
				"lower rules do not overlap owner tag")
			_assert_sewn_face(metadata, panel, card_id, definition, geometry)
		_check(root.get_visible_rect().encloses(panel.get_global_rect()),
			"whole card remains within the 1280x720 viewport")
	_check(ids == app.deck.hand, "all current panel IDs exactly follow deck.hand")
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree(),
		"End Turn and Return remain accessible")
	_check(app.end_turn_button.focus_mode == Control.FOCUS_ALL
		and app.return_button.focus_mode == Control.FOCUS_ALL,
		"End Turn/Return keyboard activation remains available")
	_check(is_instance_valid(presenter.energy_label) and
		presenter.energy_label.text == "%d" % app.deck.energy,
		"energy/action controls remain visible and authoritative")


func _refresh_preserves_everything(observed: Dictionary) -> void:
	var before := _snapshot()
	var panels := _panels()
	var old_draws := {}
	var original_rects := {}
	for panel in panels:
		old_draws[panel] = presenter._metadata._bindings[panel]["draw_count"]
		original_rects[panel] = panel.get_global_rect()
	presenter._sync_battle()
	presenter._sync_battle()
	presenter._sync_battle()
	await _frames()
	_check(_snapshot() == before, "repeated UI-only synchronization preserves full battle, intents and RNG")
	for panel in panels:
		_check(presenter._metadata._bindings.has(panel)
			and presenter._metadata._bindings[panel]["draw_count"] == old_draws[panel],
			"unchanged facts and geometry never queue redundant redraws")
		_check(panel.get_global_rect() == original_rects[panel], "decoration preserves original card hitbox")
	# Byte-for-byte tooltip stability across repeated sync.
	for panel in panels:
		var original_tooltip: String = panel.tooltip_text
		presenter._sync_battle()
		await _frames()
		_check(is_instance_valid(panel) and panel.tooltip_text == original_tooltip,
			"repeated sync preserves tooltip byte-for-byte: " + (panel.get_child(0).text if panel.get_child_count() > 0 else "?"))
	_validate_display(observed)


func _click(panel: Control) -> void:
	var location := panel.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = location
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = location
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


## Mounted V4 feedback: live dimming, hover lift and the aiming arrow all come
## from real state and stay presentation-only (models and hitboxes unchanged).
func _visual_feedback() -> void:
	var before := _snapshot()
	var panels := _panels()
	var playable: Control = null
	var energy: int = app.deck.energy
	for panel in panels:
		var state: Dictionary = presenter._metadata.visual_state(panel)
		_check(not state.is_empty() and not state["aiming"] and state["aim"] == Vector2.ZERO,
			"idle panel reports a complete non-aiming presentation state")
		if state["playable"]:
			playable = panel
	_check(playable != null, "opening hand exposes at least one live-playable card")
	if playable == null:
		return
	_check(playable.self_modulate.is_equal_approx(Color.WHITE), "playable card is drawn at full colour")
	# Real energy loss dims every now-unaffordable card, then restores.
	app.deck.combat_state.energy = 0
	presenter._sync_battle()
	await _frames()
	for panel in panels:
		_check(not presenter._metadata.visual_state(panel)["playable"]
			and not panel.self_modulate.is_equal_approx(Color.WHITE),
			"unaffordable card is visibly dimmed")
	app.deck.combat_state.energy = energy
	presenter._sync_battle()
	await _frames()
	_check(presenter._metadata.visual_state(playable)["playable"]
		and playable.self_modulate.is_equal_approx(Color.WHITE), "restored energy clears the dim")
	# Physical hover raises the drawn card without resizing its real hitbox.
	var hitbox: Rect2 = playable.get_global_rect()
	var draws: int = presenter._metadata._bindings[playable]["draw_count"]
	var motion := InputEventMouseMotion.new()
	motion.position = hitbox.get_center()
	root.push_input(motion, true)
	await _frames()
	var hovered: Dictionary = presenter._metadata.visual_state(playable)
	_check(hovered["hovered"] and playable.z_index == 3, "physical hover raises the drawn card")
	_check(presenter._metadata._bindings[playable]["draw_count"] > draws, "hover queues a fresh paper draw")
	_check(playable.size == hitbox.size and root.get_visible_rect().encloses(playable.get_global_rect()),
		"hover lift changes only the drawing, never the card size or viewport fit")
	motion = InputEventMouseMotion.new()
	motion.position = Vector2(root.size.x - 2, 2)
	root.push_input(motion, true)
	await _frames()
	_check(not presenter._metadata.visual_state(playable)["hovered"] and playable.z_index == 0,
		"leaving the card drops it back")
	# A real press arms an attack; the drag arrow follows the pointer until Esc.
	var attack: Control = null
	for panel in panels:
		if panel.get_child(0).text in CombatAttackTargeting.ATTACK_IDS \
			and presenter._metadata.visual_state(panel)["playable"]:
			attack = panel
			break
	if attack == null:
		_check(_snapshot() == before, "feedback-only pass leaves every model intact")
		return
	var attacks = app.get_node("LiveAttackPreview")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	attacks._bindings[attack].input.call(press)
	_check(attacks._armed == attack and attacks._dragging, "mouse press arms the real attack card")
	var roster = app.get_node("LiveEnemyRoster")
	var aim: Vector2 = roster._labels[0].get_global_rect().get_center() \
		if not roster._labels.is_empty() else Vector2(640, 500)
	motion = InputEventMouseMotion.new()
	motion.position = aim
	root.push_input(motion, true)
	await _frames()
	var aiming: Dictionary = presenter._metadata.visual_state(attack)
	_check(aiming["aiming"] and aiming["aim"] == aim, "armed drag tracks the pointer for the aim arrow")
	_check(attack.z_index == 3, "aiming card stays above its neighbours")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	await _frames()
	_check(not presenter._metadata.visual_state(attack)["aiming"] and attack.z_index == 0,
		"Escape cancels the arrow without casting")
	_check(attacks._armed == null and attacks._choices.is_empty(), "Escape leaves no armed attack or half choice")
	_check(_snapshot() == before, "dimming hover and cancelled aim never touch any model")


func _find(card_id: String) -> Control:
	for panel in _panels():
		if panel.get_child(0).text == card_id:
			return panel
	return null


func _start() -> bool:
	app.run_seed = 42
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.run_rng != null 		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view)
	_check(ready, "real Start Run creates complete seeded M01 battle")
	if not ready:
		return false
	_check(app.run_seed == 42, "live run preserves requested fixed seed 42")
	_check(app.deck.hand.size() == 5 and app.hand_view.get_child_count() == 5, "Start Run draws exactly five real panels")
	return true


func _play_support(card_id: String, observed: Dictionary) -> bool:
	var panel := _find(card_id)
	if panel == null:
		return false
	# This is a real play, not a fake deck consumption.
	var before := _snapshot()
	var original_hand: Array = app.deck.hand.duplicate()
	var old_bindings := _panels()
	await _click(panel)
	if app.deck.hand == original_hand:
		_check(_snapshot() == before, "unplayable support never mutates battle")
		return false
	_check(app.deck.hand.size() == original_hand.size() - (0 if card_id == "tinker_tune_up" else 1),
		"valid support consumes one card; Tune Up draws one replacement")
	_check(card_id in app.deck.discard_pile, "played support moved to discard")
	for previous in old_bindings:
		if is_instance_valid(previous):
			_check(not presenter._metadata._bindings.has(previous),
				"replaced panels are disconnected after support play")
	_validate_display(observed)
	return true


## AC1/AC3: every genuine authored status card explains its rule in the hover
## Help, directly and on its mounted bound panel, with a generic N so a passive
## or Path adjustment can never contradict it. Neutral and unknown cards invent
## no status, and the existing Pinned/Unravel rows stay only where authored.
func _status_help(metadata) -> void:
	var before := _snapshot()
	seed(6203)
	var expected_global := randi()
	seed(6203)
	var catalog_ids := _all_catalog_ids()
	_check(not catalog_ids.is_empty(), "status Help check has real shared catalog IDs")
	# 1. Direct Help for every authored status base/+ card.
	for entry in STATUS_CASES:
		var card_id: String = str(entry[0])
		var status: String = str(entry[1])
		var definition: Dictionary = metadata.definition(card_id)
		_check(not definition.is_empty(), "status catalog card exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		_check(effects.get(status) is int and int(effects[status]) == int(entry[2]),
			"status is genuinely authored at its catalog amount: " + card_id)
		var text: String = metadata.base_effect_text(card_id)
		var prefix := _status_prefix(status)
		_check(_occurrences(text, prefix) == 1,
			"exactly one %s rule row: %s" % [prefix, card_id])
		for fact in _status_facts(status):
			_check(text.contains(fact), "%s explains %s" % [card_id, fact])
		var rule_line := _line_starting(text, prefix)
		_check(not rule_line.is_empty() and rule_line.contains("N"),
			"status rule keeps the generic N: " + card_id)
		# Help never restates an applied amount as the generic tick/penalty.
		var authored: int = int(entry[2])
		for amount_phrase in ["lose %d HP" % authored, "Bleed %d" % authored,
				"Weak %d" % authored, "Exposed %d" % authored]:
			_check(not rule_line.contains(amount_phrase),
				"generic Help never claims the raw amount '%s': %s" % [amount_phrase, card_id])
		# The short face keeps its exact authored line and never grows the rule.
		var face: String = metadata.short_line(card_id)
		_check(not face.contains(prefix) and not face.contains("\n"),
			"status rule stays off the short card face: " + card_id)
		if SHORT_LINES.has(card_id):
			_check(face == str(SHORT_LINES[card_id]),
				"status card keeps its exact terse face line: " + card_id)
		var facts: Dictionary = metadata.describe(card_id)
		_check(facts.get("rules") == face and not str(facts.get("rules", "")).contains(prefix),
			"Help rule stays separate from the drawn face facts: " + card_id)
		_check(facts.get("cost") == int(definition.get("cost", -1))
			and facts.get("owner_text") == str(definition.get("owner", "")).capitalize(),
			"status Help leaves cost and owner labels unchanged: " + card_id)
		# The pip legend, source row and target pips stay exactly as authored.
		_check(text.contains("PIPS: ● filled = a slot this hero may play from (%s)"
			% _expected_positions(definition.get("from_positions", []))),
			"status Help keeps the exact source pips: " + card_id)
		_check(text.contains("From " + _expected_positions(definition.get("from_positions", []))),
			"status Help keeps the exact source row: " + card_id)
		if (definition.get("to_positions", []) as Array).is_empty():
			_check(text.contains("no target square is filled (%s)" % _tooltip_target_slots(definition)),
				"status Help keeps the exact empty target pips: " + card_id)
		else:
			_check(text.contains("■ filled = a legal target slot (%s)" % _tooltip_target_slots(definition)),
				"status Help keeps the exact target pips: " + card_id)
	# Hemorrhage Hem doubles existing Bleed: it may explain the Bleed tick but must
	# never claim a fresh application of the stacks it multiplies.
	var hem_text: String = metadata.base_effect_text("seamstress_hemorrhage_hem")
	_check(hem_text.contains("BASE double the target's current Bleed")
		and _occurrences(hem_text, "BLEED:") == 1,
		"doubling card explains Bleed once next to its doubling effect")
	_check(not hem_text.contains("BASE apply Bleed")
		and not hem_text.contains("ON CONFIRMED HIT add Bleed"),
		"doubling card never claims a fresh Bleed application")
	# 2. Every shared catalog card: a status row exists exactly when authored, so
	# neutral cards invent none and Pinned/Unravel-only cards stay clean.
	for card_id in catalog_ids:
		var definition: Dictionary = metadata.definition(card_id)
		if definition.is_empty():
			continue
		var text: String = metadata.base_effect_text(card_id)
		for status in ["bleed", "weak", "exposed"]:
			var expected: int = 1 if _authored_status(definition, status) else 0
			_check(_occurrences(text, _status_prefix(status)) == expected,
				"%s Help carries %s rules exactly when authored" % [card_id, status])
		var effects: Dictionary = definition.get("effects", {})
		var pinned_authored: bool = effects.has("pinned")
		_check(text.contains("PINNED:") == pinned_authored,
			"Pinned Help stays only where authored: " + card_id)
		var unravel_authored: bool = effects.has("unravel") \
			or (effects.get("conditional_damage") is Dictionary \
				and metadata._has_unravel_conditional(effects))
		_check(text.contains("UNRAVEL:") == unravel_authored,
			"Unravel Help stays only where authored: " + card_id)
	# Explicit neutral and unknown negatives, including Strike and Brace.
	for neutral_id in ["warden_strike", "warden_strike_plus", "warden_brace",
			"warden_brace_plus", "tinker_long_barrel", "unreleased_card"]:
		var neutral_text: String = metadata.base_effect_text(neutral_id)
		for status in ["bleed", "weak", "exposed"]:
			_check(_occurrences(neutral_text, _status_prefix(status)) == 0,
				"neutral/unknown card invents no %s rule: %s" % [status, neutral_id])
		_check(not neutral_text.contains("Bleed") and not neutral_text.contains("Weak")
			and not neutral_text.contains("Exposed"),
			"neutral/unknown card names no status: " + neutral_id)
	_check(metadata.base_effect_text("unreleased_card") == "Unknown card",
		"unknown status Help remains the exact placeholder")
	# A card that authors Weak and Unravel carries both, and no other status.
	var snag: String = metadata.base_effect_text("seamstress_snag")
	_check(_occurrences(snag, "WEAK:") == 1 and _occurrences(snag, "UNRAVEL:") == 1
		and _occurrences(snag, "BLEED:") == 0 and _occurrences(snag, "EXPOSED:") == 0,
		"Weak + Unravel card explains both authored rules and no other status")
	# 3. The same Help through a real mounted, bound hand panel for Prick, Shield
	# Bash and Rivet Shot, base and upgraded.
	var probe_metadata = load(HAND_SCRIPT).new()
	_check(probe_metadata != null, "mounted status Help presenter loads")
	if probe_metadata != null:
		probe_metadata.set_app(app)
		for entry in STATUS_CASES:
			var card_id: String = str(entry[0])
			if not card_id.begins_with("seamstress_prick") \
					and not card_id.begins_with("warden_shield_bash") \
					and not card_id.begins_with("tinker_rivet_shot"):
				continue
			var probe := PanelContainer.new()
			probe.custom_minimum_size = Vector2(150, 96)
			var label := Label.new()
			label.text = card_id
			probe.add_child(label)
			app.hand_view.add_child(probe)
			await _frames()
			var panels: Array[Node] = [probe]
			var hand: Array[String] = [card_id]
			probe_metadata.sync(panels, hand)
			await _frames()
			_check(probe_metadata._bindings.has(probe)
				and probe_metadata._bindings[probe]["id"] == card_id,
				"mounted status card binds its exact Help: " + card_id)
			_check(probe.tooltip_text == metadata.base_effect_text(card_id),
				"mounted tooltip is the exact authored status Help: " + card_id)
			_check(_occurrences(probe.tooltip_text, _status_prefix(str(entry[1]))) == 1,
				"mounted tooltip explains its status once: " + card_id)
			_check(probe_metadata.get_facts(probe).get("rules") == metadata.short_line(card_id),
				"mounted status card keeps its unchanged short face: " + card_id)
			_check(int(probe_metadata._bindings[probe].get("draw_count", 0)) > 0,
				"mounted status card really drew its paper face: " + card_id)
			probe_metadata.clear()
			probe.free()
			await _frames()
		_check(probe_metadata._bindings.is_empty(), "mounted status probes release cleanly")
	_check(_snapshot() == before, "status Help formatting mutates no live model")
	_check(randi() == expected_global, "status Help formatting draws no global RNG")


## The tooltip formatter teaches only authored Pinned/Unravel rules. Each shared
## catalog value is read through the real metadata lookup, never a fixture copy.
func _keyword_explanations(metadata) -> void:
	var before := _snapshot()
	var pinned_cases := [
		["warden_pinning_jab", "warden_pinning_jab_plus", 4, 6],
		["seamstress_needle_pin", "seamstress_needle_pin_plus", 3, 4],
		["tinker_spring_trap", "tinker_spring_trap_plus", 3, 4],
	]
	for entry in pinned_cases:
		var base_id: String = str(entry[0])
		var plus_id: String = str(entry[1])
		var base_definition: Dictionary = metadata.definition(base_id)
		var plus_definition: Dictionary = metadata.definition(plus_id)
		_check(not base_definition.is_empty() and not plus_definition.is_empty(),
			"Pinned catalog and upgrade exist: " + base_id)
		var base_effects: Dictionary = base_definition.get("effects", {})
		var plus_effects: Dictionary = plus_definition.get("effects", {})
		_check(base_effects.has("pinned") and plus_effects.has("pinned"),
			"Pinned catalogs really author pinned on base and +: " + base_id)
		_check(int(base_effects.get("damage", -1)) == int(entry[2])
			and int(plus_effects.get("damage", -1)) == int(entry[3]),
			"Pinned base/+ damage comes from the catalogs: " + base_id)
		for pair in [[base_id, base_definition, entry[2]], [plus_id, plus_definition, entry[3]]]:
			var card_id: String = str(pair[0])
			var definition: Dictionary = pair[1]
			var expected_damage: int = int(pair[2])
			var text: String = metadata.base_effect_text(card_id)
			_check(_occurrences(text, "PINNED:") == 1, "one Pinned glossary: " + card_id)
			_check(not text.contains("UNRAVEL:"), "Pinned card gains no Unravel glossary: " + card_id)
			_check(text.contains("BASE deal %d damage" % expected_damage),
				"Pinned card keeps its exact authored damage: " + card_id)
			_check(text.contains("BASE Pin the target"), "Pinned card keeps its base pin effect: " + card_id)
			_check(not text.contains("every attack"), "Pinned card never claims every attack pins: " + card_id)
			for fact in PINNED_FACTS:
				_check(text.contains(fact), "%s explains %s" % [card_id, fact])
			_assert_keyword_frame(text, definition, card_id)
	var unravel_cases := [
		["warden_seam_breaker", "warden_seam_breaker_plus"],
		["seamstress_snag", "seamstress_snag_plus"],
		["seamstress_unpick", "seamstress_unpick_plus"],
		["tinker_spool_launcher", "tinker_spool_launcher_plus"],
		["tinker_snip_the_seam", "tinker_snip_the_seam_plus"],
	]
	var guarding_cases := [
		["warden_draw_fire", "warden_draw_fire_plus", 6, 8],
	]
	for g_entry in guarding_cases:
		var base_id: String = str(g_entry[0])
		var plus_id: String = str(g_entry[1])
		var base_definition: Dictionary = metadata.definition(base_id)
		var plus_definition: Dictionary = metadata.definition(plus_id)
		_check(not base_definition.is_empty() and not plus_definition.is_empty(),
			"Guarding catalog and upgrade exist: " + base_id)
		var base_effects: Dictionary = base_definition.get("effects", {})
		var plus_effects: Dictionary = plus_definition.get("effects", {})
		_check(base_effects.has("guarding") and plus_effects.has("guarding"),
			"Guarding catalogs really author guarding on base and +: " + base_id)
		_check(int(base_effects.get("block", -1)) == int(g_entry[2])
			and int(plus_effects.get("block", -1)) == int(g_entry[3]),
			"Guarding base/+ block comes from the catalogs: " + base_id)
		for pair in [[base_id, base_definition, g_entry[2]], [plus_id, plus_definition, g_entry[3]]]:
			var card_id: String = str(pair[0])
			var definition: Dictionary = pair[1]
			var expected_block: int = int(pair[2])
			var text: String = metadata.base_effect_text(card_id)
			_check(text.contains("BASE gain %d Block" % expected_block),
				"Guarding card keeps its exact authored block: " + card_id)
			_check(text.contains("BASE Guard: enemy attacks aimed at other living heroes are redirected to the living Warden until your next turn"),
				"Guarding card explains precise redirect mechanics: " + card_id)
			var lines := text.split("\n")
			var header := "%s; %s; %d energy" % [str(definition.get("display_name", "")),
				str(definition.get("owner", "")).capitalize(), int(definition.get("cost", -1))]
			_check(lines.has(header), "Guarding card keeps exact cost header: " + card_id)
			_check(lines.has("Self"), "Guarding card targets self: " + card_id)

	var thorns_cases := [
		["warden_counter_stitch", "warden_counter_stitch_plus", 5, 7, 3, 4],
	]
	for t_entry in thorns_cases:
		var base_id: String = str(t_entry[0])
		var plus_id: String = str(t_entry[1])
		var base_definition: Dictionary = metadata.definition(base_id)
		var plus_definition: Dictionary = metadata.definition(plus_id)
		_check(not base_definition.is_empty() and not plus_definition.is_empty(),
			"Thorns catalog and upgrade exist: " + base_id)
		var base_effects: Dictionary = base_definition.get("effects", {})
		var plus_effects: Dictionary = plus_definition.get("effects", {})
		_check(base_effects.has("thorns") and plus_effects.has("thorns"),
			"Thorns catalogs really author thorns on base and +: " + base_id)
		_check(int(base_effects.get("block", -1)) == int(t_entry[2])
			and int(plus_effects.get("block", -1)) == int(t_entry[3]),
			"Thorns base/+ block comes from the catalogs: " + base_id)
		_check(int(base_effects.get("thorns", -1)) == int(t_entry[4])
			and int(plus_effects.get("thorns", -1)) == int(t_entry[5]),
			"Thorns base/+ amounts come from the catalogs: " + base_id)
		for pair in [[base_id, base_definition, t_entry[2], t_entry[4]], [plus_id, plus_definition, t_entry[3], t_entry[5]]]:
			var card_id: String = str(pair[0])
			var definition: Dictionary = pair[1]
			var expected_block: int = int(pair[2])
			var expected_thorns: int = int(pair[3])
			var text: String = metadata.base_effect_text(card_id)
			_check(text.contains("BASE gain %d Block" % expected_block),
				"Thorns card keeps its exact authored block: " + card_id)
			_check(text.contains("BASE gain %d Thorns: an enemy attacking Warden takes %d damage until your next turn" % [expected_thorns, expected_thorns]),
				"Thorns card explains precise retaliation mechanics: " + card_id)
			var lines := text.split("\n")
			var header := "%s; %s; %d energy" % [str(definition.get("display_name", "")),
				str(definition.get("owner", "")).capitalize(), int(definition.get("cost", -1))]
			_check(lines.has(header), "Thorns card keeps exact cost header: " + card_id)
			_check(lines.has("Self"), "Thorns card targets self: " + card_id)
	for entry in unravel_cases:
		var base_id: String = str(entry[0])
		var plus_id: String = str(entry[1])
		var base_definition: Dictionary = metadata.definition(base_id)
		var plus_definition: Dictionary = metadata.definition(plus_id)
		_check(not base_definition.is_empty() and not plus_definition.is_empty(),
			"Unravel catalog and upgrade exist: " + base_id)
		var base_effects: Dictionary = base_definition.get("effects", {})
		var plus_effects: Dictionary = plus_definition.get("effects", {})
		_check(base_effects.has("unravel") or base_effects.has("conditional_damage"),
			"Unravel catalog really authors the mechanic: " + base_id)
		_check(plus_effects.has("unravel") or plus_effects.has("conditional_damage"),
			"Unravel upgrade really authors the mechanic: " + plus_id)
		for pair in [[base_id, base_definition], [plus_id, plus_definition]]:
			var card_id: String = str(pair[0])
			var definition: Dictionary = pair[1]
			var effects: Dictionary = definition.get("effects", {})
			var text: String = metadata.base_effect_text(card_id)
			_check(_occurrences(text, "UNRAVEL:") == 1, "one Unravel glossary: " + card_id)
			_check(not text.contains("PINNED:"), "Unravel card gains no Pinned glossary: " + card_id)
			for fact in UNRAVEL_FACTS:
				_check(text.contains(fact), "%s explains %s" % [card_id, fact])
			_assert_keyword_frame(text, definition, card_id)
			if effects.has("unravel"):
				_check(text.contains("BASE add %d Unravel" % int(effects["unravel"])),
					"Unravel card keeps its exact authored addition: " + card_id)
				_check(not text.contains("instead if"),
					"plain Unravel card invents no conditional damage: " + card_id)
			else:
				var condition: Variant = effects.get("conditional_damage")
				var base_damage: int = int(effects.get("damage", -1))
				var empowered: int = int(condition.get("damage", -1)) if condition is Dictionary else -1
				_check(text.contains("BASE deal %d damage; BASE deal %d damage instead if the target is Unravelled or its Unravel gauge is at least half" % [base_damage, empowered]),
					"Snip keeps its exact base/empowered half-gauge wording: " + card_id)
	# + variants read their own catalog numbers; upgrades do not all add one.
	_check(_authored_number(metadata, "warden_seam_breaker", "unravel") == 4
		and _authored_number(metadata, "warden_seam_breaker_plus", "unravel") == 6
		and _authored_number(metadata, "warden_seam_breaker_plus", "damage") == 10,
		"Seam Breaker+ keeps its catalog 10 damage / 6 Unravel")
	_check(metadata.base_effect_text("warden_seam_breaker").contains("BASE deal 7 damage; BASE add 4 Unravel to the target")
		and metadata.base_effect_text("warden_seam_breaker_plus").contains("BASE deal 10 damage; BASE add 6 Unravel to the target"),
		"Seam Breaker base and + show their own damage and Unravel lines")
	_check(_authored_number(metadata, "seamstress_snag", "unravel") == 3
		and _authored_number(metadata, "seamstress_snag_plus", "unravel") == 4
		and _authored_number(metadata, "seamstress_snag_plus", "weak") == 1,
		"Snag+ keeps its catalog 4 Unravel and unchanged Weak 1")
	_check(metadata.base_effect_text("seamstress_snag").contains("BASE apply Weak 1 to the target")
		and metadata.base_effect_text("seamstress_snag").contains("BASE add 3 Unravel to the target")
		and metadata.base_effect_text("seamstress_snag_plus").contains("BASE apply Weak 1 to the target")
		and metadata.base_effect_text("seamstress_snag_plus").contains("BASE add 4 Unravel to the target"),
		"Snag base and + keep authored Weak and Unravel additions")
	_check(_authored_number(metadata, "seamstress_unpick", "unravel") == 5
		and _authored_number(metadata, "seamstress_unpick_plus", "unravel") == 7,
		"Unpick+ keeps its catalog 7 Unravel")
	_check(metadata.base_effect_text("seamstress_unpick").contains("BASE add 5 Unravel to the target")
		and metadata.base_effect_text("seamstress_unpick_plus").contains("BASE add 7 Unravel to the target"),
		"Unpick base and + show their own Unravel lines")
	_check(_authored_number(metadata, "tinker_spool_launcher", "unravel") == 3
		and _authored_number(metadata, "tinker_spool_launcher", "damage") == 3
		and _authored_number(metadata, "tinker_spool_launcher_plus", "unravel") == 4
		and _authored_number(metadata, "tinker_spool_launcher_plus", "damage") == 4,
		"Spool Launcher+ keeps its catalog 4 damage / 4 Unravel")
	_check(metadata.base_effect_text("tinker_spool_launcher").contains("BASE deal 3 damage; BASE add 3 Unravel to the target")
		and metadata.base_effect_text("tinker_spool_launcher_plus").contains("BASE deal 4 damage; BASE add 4 Unravel to the target"),
		"Spool Launcher base and + show their own damage and Unravel lines")
	_check(_authored_number(metadata, "tinker_snip_the_seam", "damage") == 5
		and _authored_conditional_damage(metadata, "tinker_snip_the_seam") == 15
		and _authored_number(metadata, "tinker_snip_the_seam_plus", "damage") == 7
		and _authored_conditional_damage(metadata, "tinker_snip_the_seam_plus") == 20,
		"Snip the Seam+ keeps its catalog 7/20 conditional numbers")
	_check(metadata.base_effect_text("tinker_snip_the_seam").contains("BASE deal 5 damage; BASE deal 15 damage instead if the target is Unravelled or its Unravel gauge is at least half")
		and metadata.base_effect_text("tinker_snip_the_seam_plus").contains("BASE deal 7 damage; BASE deal 20 damage instead if the target is Unravelled or its Unravel gauge is at least half"),
		"Snip base and + keep the 5-or-15 / 7-or-20 half-threshold wording")
	# Stitched tooltips inherit each half's own glossary in numbered order.
	var pinned_first: String = metadata.stitched_tooltip(["warden_pinning_jab", "tinker_spool_launcher"])
	var halves := pinned_first.split("\n2. ")
	_check(halves.size() == 2 and pinned_first.find("1. ") < pinned_first.find("\n2. "),
		"stitched tooltip keeps two numbered halves in order")
	if halves.size() == 2:
		_check(halves[0].begins_with("1. Pinning Jab; Warden; 1 energy")
			and halves[0].contains("PINNED:") and not halves[0].contains("UNRAVEL:"),
			"Pinned-first stitched half carries only the Pinned glossary")
		_check(halves[1].begins_with("Spool Launcher; Tinker; 1 energy")
			and halves[1].contains("UNRAVEL:") and not halves[1].contains("PINNED:"),
			"Unravel-second stitched half carries only the Unravel glossary")
	var unravel_first: String = metadata.stitched_tooltip(["tinker_spool_launcher", "warden_pinning_jab"])
	var reversed_halves := unravel_first.split("\n2. ")
	_check(reversed_halves.size() == 2, "reversed stitched tooltip keeps two numbered halves")
	if reversed_halves.size() == 2:
		_check(reversed_halves[0].begins_with("1. Spool Launcher; Tinker; 1 energy")
			and reversed_halves[0].contains("UNRAVEL:") and not reversed_halves[0].contains("PINNED:"),
			"reversed order puts the Unravel glossary in the first half")
		_check(reversed_halves[1].begins_with("Pinning Jab; Warden; 1 energy")
			and reversed_halves[1].contains("PINNED:") and not reversed_halves[1].contains("UNRAVEL:"),
			"reversed order puts the Pinned glossary in the second half")
	# Only canonical two-owner ordinary halves earn a shared price/readiness
	# note, after the unchanged numbered descriptions and keyword glossary.
	_check(not RunRestStitchCards.resolve_card_definition("warden_pinning_jab").is_empty()
		and not RunRestStitchCards.resolve_card_definition("tinker_spool_launcher").is_empty(),
		"stitched Help test halves are authentic Rest-stitch definitions")
	_check(_occurrences(pinned_first, "STITCHED:") == 1
		and pinned_first.find("\nSTITCHED:") > pinned_first.find("UNRAVEL:"),
		"one shared stitch rule follows both authored numbered halves")
	_check(pinned_first.contains("STITCHED: 2 energy total (higher half cost + 1, capped at 3)")
		and pinned_first.contains("pay energy and discard the composite ONCE"),
		"two 1-energy halves cost 2 energy, paid and discarded once")
	for rule in ["Both owners must be alive", "each in their own legal FROM position",
			"Resolve half 1, then half 2", "independent legal targets",
			"each owner's own passive", "+ halves keep their upgrades",
			"cannot be stitched again or upgraded"]:
		_check(pinned_first.contains(rule), "canonical stitch explains: " + rule)
	_check(pinned_first.contains("BASE deal 4 damage; BASE Pin the target")
		and pinned_first.contains("BASE deal 3 damage; BASE add 3 Unravel to the target")
		and pinned_first.find("PINNED:") < pinned_first.find("UNRAVEL:"),
		"ordered ordinary halves retain exact authored damage/status and glossary sequence")
	_check(unravel_first.contains("STITCHED: 2 energy total")
		and unravel_first.find("UNRAVEL:") < unravel_first.find("PINNED:")
		and unravel_first.find("\nSTITCHED:") > unravel_first.find("PINNED:"),
		"reversing the halves preserves the 2-cost rule and reverses glossary order")
	var no_pips: String = metadata.stitched_tooltip(
		["warden_pinning_jab", "tinker_spool_launcher"], false)
	_check(no_pips.begins_with("1. Pinning Jab; Warden; 1 energy")
		and no_pips.contains("\n2. Spool Launcher; Tinker; 1 energy")
		and not no_pips.contains("PIPS:") and no_pips.contains("STITCHED: 2 energy total"),
		"Shop/Rest pip-free stitched Help retains the same shared rules")
	var upgraded: String = metadata.stitched_tooltip(
		["warden_pinning_jab_plus", "tinker_spool_launcher_plus"])
	_check(upgraded.begins_with("1. Pinning Jab+; Warden; 1 energy")
		and upgraded.contains("\n2. Spool Launcher+; Tinker; 1 energy")
		and upgraded.contains("BASE deal 6 damage; BASE Pin the target")
		and upgraded.contains("BASE deal 4 damage; BASE add 4 Unravel to the target"),
		"each upgraded + half keeps its own catalog name, damage and status")
	_check(upgraded.contains("STITCHED: 2 energy total")
		and upgraded.find("PINNED:") < upgraded.find("UNRAVEL:")
		and upgraded.find("UNRAVEL:") < upgraded.find("\nSTITCHED:"),
		"upgraded stitched halves preserve one cost and ordered keyword explanations")
	var heavy: String = metadata.stitched_tooltip(
		["warden_heavy_thimble", "tinker_spare_parts"])
	var heavy_reversed: String = metadata.stitched_tooltip(
		["tinker_spare_parts", "warden_heavy_thimble"])
	_check(heavy.begins_with("1. Heavy Thimble; Warden; 2 energy")
		and heavy.contains("\n2. Spare Parts; Tinker; 0 energy")
		and heavy.contains("BASE deal 11 damage")
		and heavy.contains("BASE gain 3 Block") and heavy.contains("BASE draw 1"),
		"2+0 half pair preserves Warden's attack then Tinker's support")
	_check(heavy.contains("STITCHED: 3 energy total")
		and heavy_reversed.contains("STITCHED: 3 energy total")
		and heavy_reversed.begins_with("1. Spare Parts; Tinker; 0 energy")
		and heavy_reversed.contains("\n2. Heavy Thimble; Warden; 2 energy"),
		"higher half cost yields 3 in both orders, with ordered support/attack text")
	_check(heavy.find("\nSTITCHED:") > heavy.find("\n2. Spare Parts")
		and heavy_reversed.find("\nSTITCHED:") > heavy_reversed.find("\n2. Heavy Thimble"),
		"shared note follows the second half for both legal orders")
	var capped: String = metadata.stitched_tooltip(
		["warden_bastion_quilt", "tinker_spare_parts"])
	_check(capped.begins_with("1. Bastion Quilt; Warden; 3 energy")
		and capped.contains("\n2. Spare Parts; Tinker; 0 energy")
		and capped.contains("STITCHED: 3 energy total")
		and not capped.contains("STITCHED: 4 energy total"),
		"3+0 canonical halves respect the composite cost cap of 3")
	# These are formatter inputs, not ledger-authenticated stitched receipts.
	# Even a Path card known to the display lookup is not a legal Rest half.
	_check(not metadata.definition("warden_lance_pin").is_empty()
		and RunRestStitchCards.resolve_card_definition("warden_lance_pin").is_empty(),
		"Path-only Warden display card is known but not Rest-stitchable")
	var invalid_pairs := [
		[[], "empty"], [["warden_pinning_jab"], "one half"],
		[["warden_pinning_jab", "tinker_spool_launcher", "tinker_spare_parts"], "three halves"],
		[["warden_pinning_jab", "warden_heavy_thimble"], "same owner"],
		[["warden_lance_pin", "tinker_spool_launcher"], "Path-only half"],
		[["warden_pinning_jab", "counterfeit_tinker_id"], "unknown ID"],
		[["warden_pinning_jab", {"id": "tinker_spool_launcher", "owner": "tinker", "cost": 0}], "counterfeit record"],
		[["warden_pinning_jab", "stitched_000001"], "pre-stitched half"],
	]
	for invalid in invalid_pairs:
		var invalid_text: String = metadata.stitched_tooltip(invalid[0])
		_check(not invalid_text.contains("STITCHED:") and not invalid_text.contains("energy total"),
			"invalid %s cannot gain authoritative composite rules or price" % invalid[1])
		if invalid[1] in ["unknown ID", "counterfeit record", "pre-stitched half"]:
			_check(invalid_text.contains("\n2. Unknown card"),
				"invalid %s preserves honest unknown-half placeholder" % invalid[1])
			_check(not invalid_text.contains("counterfeit_tinker_id")
				and not invalid_text.contains("stitched_000001")
				and not invalid_text.contains('"id":'),
				"invalid %s leaks no raw counterfeit ID" % invalid[1])
	_check(metadata.stitched_tooltip([]).is_empty()
		and metadata.stitched_tooltip(["warden_pinning_jab"]).is_empty()
		and metadata.stitched_tooltip(["warden_pinning_jab", "tinker_spool_launcher",
			"tinker_spare_parts"]).is_empty(),
		"wrong cardinality retains the existing empty fallback")
	# A plain damage card and an unknown ID stay free of invented keywords.
	var neutral: String = metadata.base_effect_text("tinker_long_barrel")
	_check(_occurrences(neutral, "PINNED:") == 0 and _occurrences(neutral, "UNRAVEL:") == 0,
		"ordinary damage card gains neither keyword glossary")
	_check(_authored_number(metadata, "tinker_long_barrel", "damage") == 12
		and neutral.contains("BASE deal 12 damage"),
		"ordinary damage card keeps its exact authored damage")
	_check(metadata.base_effect_text("unreleased_card") == "Unknown card",
		"unknown ID stays the exact 'Unknown card' placeholder")
	_check(_snapshot() == before, "keyword tooltip formatting mutates no live model")


## The two genuine authored Warden Path records: metadata recognizes exactly the
## validated offering set (name, owner, 1 cost, FROM/TO, effects and an optional
## sewn face) and prints the Path passive separately from the card's own effects.
## No recognition here may ever add a claim, a cast, a card to a deck or a pin.
func _warden_path_presentation() -> void:
	var metadata = load(HAND_SCRIPT).new()
	_check(metadata != null, "shared hand metadata loads for Warden Path faces")
	if metadata == null:
		return
	var before := _snapshot()
	var cases := [
		["bulwark", "warden_bulwark_brace"],
		["vanguard", "warden_lance_pin"],
	]
	var receipts := {}
	for entry in cases:
		var path_id: String = str(entry[0])
		var expected_card_id: String = str(entry[1])
		var choice := RunWardenPathChoice.new()
		_check(choice.is_valid(), "authored Warden Path record validates: " + path_id)
		if not choice.is_valid():
			continue
		var receipt: Dictionary = choice.choose(path_id)
		_check(bool(receipt.get("ok", false)), "genuine Warden Path choice succeeds: " + path_id)
		if not receipt.get("ok", false):
			continue
		var card: Dictionary = receipt["card"]
		var passive: Dictionary = receipt["passive"]
		var card_id: String = str(card.get("id", ""))
		_check(card_id == expected_card_id, "receipt carries the authored Path card: " + path_id)
		receipts[card_id] = receipt
		var definition: Dictionary = metadata.definition(card_id)
		_check(definition == card, "detached definition exactly matches the validated record: " + card_id)
		if definition.is_empty():
			continue
		# Mutating a nested value in a returned copy proves the catalog is detached.
		if definition.get("effects") is Dictionary:
			(definition["effects"] as Dictionary)["block"] = 99
			(definition["effects"] as Dictionary)["damage"] = 99
		_check(metadata.definition(card_id) == card, "recognized Warden Path definition is detached: " + card_id)
		var facts: Dictionary = metadata.describe(card_id)
		_check(facts.get("known") == true and facts.get("id") == card_id,
			"Warden Path card is a known authored face: " + card_id)
		_check(facts.get("owner") == "warden" and facts.get("owner_text") == "Warden",
			"Warden Path card keeps the Warden owner: " + card_id)
		_check(facts.get("display_name") == str(card.get("display_name", "")),
			"Warden Path face prints the authored name: " + card_id)
		_check(facts.get("cost") == 1 and facts.get("cost_text") == "Cost 1",
			"Warden Path card prints its authored 1 cost: " + card_id)
		_check(facts.get("from_text") == "From " + _expected_positions(card.get("from_positions", [])),
			"Warden Path face prints its authored FROM range: " + card_id)
		_check(facts.get("target_text") == _warden_target_line(card),
			"Warden Path face prints its authored target: " + card_id)
		var text: String = metadata.base_effect_text(card_id)
		var lines := text.split("\n")
		_check(not text.contains("Unknown card"), "recognized Warden Path card is never unknown: " + card_id)
		_check(lines.has("%s; Warden; %d energy" % [str(card.get("display_name", "")),
			int(card.get("cost", -1))]), "Warden Path tooltip keeps the exact cost header: " + card_id)
		_check(lines.has("From " + _expected_positions(card.get("from_positions", []))),
			"Warden Path tooltip keeps the exact source range: " + card_id)
		_check(lines.has(_warden_tooltip_target_line(card)),
			"Warden Path tooltip keeps the exact target line: " + card_id)
		_check(not catalog.get_all_card_ids().has(card_id),
			"Warden Path card is never appended to the starter catalog: " + card_id)
		_check(WardenPoolCards.new().get_definition(card_id).is_empty(),
			"Warden Path card is never added to the Warden reward pool: " + card_id)
		_check(not choice.get_base_deck().has(card_id),
			"Warden Path recognition never mutates the base starter deck: " + card_id)
		if path_id == "bulwark":
			_check(str(passive.get("kind", "")) == "replaces_starting_block"
				and int(passive.get("replaced_starting_block", 0)) == 6
				and int(passive.get("starting_block", 0)) == 10,
				"Bulwark receipt replaces opening Block 6 with exactly 10")
			_check(int((card.get("effects") as Dictionary).get("block", 0)) == 9,
				"Bulwark Brace authored cast grants exactly 9 Block")
			var path_line := ("PATH Bulwark passive: the Warden opens combat with exactly 10 Block, "
				+ "replacing the base 6 instead of adding to it (not 6 + 10, not 16). "
				+ "This card's own cast grants 9 Block to the living Warden and never re-grants the opening Block.")
			_check(lines.has(path_line),
				"Bulwark help separates the 10 opening Block from Brace's own 9 Block")
			_check(lines.has("BASE gain 9 Block"),
				"Bulwark Brace keeps its own 9 Block card-effect row")
			_check(_occurrences(text, "16") == 1 and text.contains("not 16"),
				"Bulwark help explicitly rejects a 6 + 10 = 16 opening total")
			_check(not text.contains("gain 10 Block") and not text.contains("BASE gain 10"),
				"Bulwark help never grants the 10 opening Block on a card play")
			_check(not path_line.contains("BASE"),
				"Bulwark Path/passive line is not a card-effect transaction")
		else:
			_check(str(passive.get("kind", "")) == "first_attack_per_turn_pins"
				and str(passive.get("trigger", "")) == "first_confirmed_attack_each_player_turn"
				and bool(passive.get("once_per_turn", false))
				and str(passive.get("status", "")) == "pinned"
				and str(passive.get("applies_to", "")) == "warden",
				"Vanguard receipt pins after one confirmed Warden attack per turn")
			var effects: Dictionary = card.get("effects", {})
			_check(int(effects.get("damage", 0)) == 6 and bool(effects.get("pinned", false)),
				"Lance Pin authored cast is 6 damage and a pin")
			var path_line := ("PATH Vanguard passive: pins only after the Warden's first CONFIRMED "
				+ "attack in each player turn, never every cast and never an unconfirmed preview. "
				+ "This card's own cast deals 6 damage and pins a surviving target; a DIFFERENT "
				+ "hero's next attack on it adds +5 damage BEFORE Weak/Exposed and consumes the pin once (see PINNED).")
			_check(lines.has(path_line),
				"Vanguard help separates the per-turn passive from Lance Pin's own cast")
			_check(lines.has("BASE deal 6 damage; BASE Pin the target: a different hero's next attack gets +5 damage"),
				"Lance Pin keeps its own 6 damage and +5 pin effect row")
			_check(text.contains("DIFFERENT hero's next attack on it adds +5 damage BEFORE Weak/Exposed"),
				"Lance Pin help names the different-owner +5 ordering explicitly")
			_check(_occurrences(text, "PINNED:") == 1 and text.contains("PINNED: one pin per enemy"),
				"Lance Pin reuses the existing Pinned glossary exactly once")
			_check(not text.contains("deal 11 damage") and not text.contains("deal 7 damage")
				and not text.contains("BASE deal %d damage" % (6 + 5)),
				"Lance Pin never folds the cross-owner +5 into an extra damage transaction")
			_check(not path_line.contains("BASE"),
				"Vanguard Path/passive line is not a card-effect transaction")
		var faces: Dictionary = metadata.face_assets(card_id)
		var expected_picture := _expected_warden_picture(card)
		_check(faces.get("frame_path") == ART_DIR + "ui/card_frame_warden.png",
			"Warden Path face wears the Warden felt frame: " + card_id)
		_check(faces.get("picture_path") == expected_picture,
			"Warden Path picture follows authored-then-art-then-emblem priority: " + card_id)
		_check((expected_picture.is_empty()) == (faces.get("picture") == null),
			"Warden Path picture is optional and never invented: " + card_id)
		if faces.get("frame") is Texture2D:
			_check((faces["frame"] as Texture2D).get_width() > 0
				and (faces["frame"] as Texture2D).get_height() > 0,
				"Warden Path felt frame really loaded its pixels: " + card_id)
	_check(receipts.size() == 2, "both authored Warden Path cards were really exercised")
	_check(_snapshot() == before, "Warden Path display lookups mutate no live model")
	if receipts.size() != 2:
		return
	# A missing authored illustration keeps the drawn face fallback: the owner
	# emblem still resolves, and with no owner art at all the renderer keeps the
	# paper face instead of inventing a file. The probe IDs are synthetic so no
	# assertion depends on a future optional PNG.
	var fallback = load(HAND_SCRIPT).new()
	var unillustrated: Dictionary = (receipts["warden_bulwark_brace"]["card"] as Dictionary).duplicate(true)
	unillustrated["id"] = "warden_probe_unillustrated"
	unillustrated["illustration_path"] = "res://assets/paper/cards/warden_probe_unillustrated_missing.png"
	fallback._warden_path_loaded = true
	fallback._warden_path_cards[unillustrated["id"]] = unillustrated
	fallback._warden_path_passives[unillustrated["id"]] = \
		(receipts["warden_bulwark_brace"]["passive"] as Dictionary).duplicate(true)
	fallback._warden_path_names[unillustrated["id"]] = "Bulwark"
	var unillustrated_faces: Dictionary = fallback.face_assets("warden_probe_unillustrated")
	_check(unillustrated_faces.get("picture_path") == ART_DIR + "cards/emblem_warden.png",
		"missing Warden Path illustration keeps the owner-emblem fallback")
	_check(unillustrated_faces.get("frame") is Texture2D,
		"missing Warden Path illustration keeps the sewn Warden frame")
	var bare: Dictionary = unillustrated.duplicate(true)
	bare["id"] = "warden_probe_unsewn"
	bare["owner"] = "probe_unsewn_owner"
	fallback._warden_path_cards[bare["id"]] = bare
	var bare_faces: Dictionary = fallback.face_assets("warden_probe_unsewn")
	_check(bare_faces.get("frame") == null and bare_faces.get("picture") == null,
		"missing Warden Path face art borrows no felt frame or picture")
	var bare_layout: Dictionary = fallback.card_layout(Vector2(230.0, 160.0),
		bare_faces.get("frame") is Texture2D)
	_check(not bool(bare_layout.get("sewn", true))
		and (bare_layout.get("art", Rect2()) as Rect2).size == Vector2.ZERO,
		"missing Warden Path face art keeps the drawn paper face")
	# A mounted, labeled Warden Path panel with a real GUI signal still stays
	# readable-but-nonplayable: metadata alone may never enable, target or commit
	# a cast, and no model or seeded RNG may change.
	var probe_metadata = load(HAND_SCRIPT).new()
	probe_metadata.set_app(app)
	var probe := PanelContainer.new()
	probe.custom_minimum_size = Vector2(150, 96)
	var probe_label := Label.new()
	probe_label.text = "warden_lance_pin"
	probe.add_child(probe_label)
	app.hand_view.add_child(probe)
	await _frames()
	var mounted_before := _snapshot()
	var no_op := func(_event: InputEvent) -> void: pass
	probe.gui_input.connect(no_op)
	var probe_panels: Array[Node] = [probe]
	var probe_hand: Array[String] = ["warden_lance_pin"]
	probe_metadata.sync(probe_panels, probe_hand)
	await _frames()
	_check(probe_metadata._bindings.has(probe), "mounted Warden Path panel binds its authored face")
	_check(probe_metadata.get_faces(probe).get("frame_path") == ART_DIR + "ui/card_frame_warden.png",
		"mounted Warden Path panel really wears the Warden felt frame")
	_check(probe.tooltip_text.contains("PATH Vanguard passive")
		and probe.tooltip_text.contains("BASE deal 6 damage"),
		"mounted Warden Path tooltip carries both the Path and card rows")
	var attacks = app.get_node_or_null("LiveAttackPreview")
	_check(attacks != null and attacks.has_method("warden_path_playable")
		and app.run_warden_path_receipt.is_empty() and not attacks.warden_path_playable("warden_lance_pin"),
		"an unselected Warden battle resolver refuses the probe card")
	_check(not bool(probe_metadata.visual_state(probe).get("playable", true)),
		"absent Warden battle resolver never enables the mounted face")
	_check(not probe.self_modulate.is_equal_approx(Color.WHITE),
		"absent Warden battle resolver leaves the mounted face dim")
	_check(probe.focus_mode == Control.FOCUS_NONE,
		"a Warden Path tooltip adds no keyboard commit")
	_check(probe.gui_input.get_connections().size() == 1,
		"metadata never attaches a targeting handler to a Warden Path face")
	await _click(probe)
	_check(probe_metadata._bindings.has(probe)
		and not bool(probe_metadata.visual_state(probe).get("playable", true))
		and probe.tooltip_text.contains("PATH Vanguard passive"),
		"a click on the illustrated face offers no Warden Path cast")
	_check(_snapshot() == mounted_before,
		"Warden Path face recognition never changes hand, deck, party, enemies or seeded RNG")
	_check(attacks != null and attacks._armed == null and attacks._choices.is_empty(),
		"no mounted Warden Path card arms an attack or half choice")
	probe_metadata.clear()
	probe.free()
	await _frames()
	_check(probe_metadata._bindings.is_empty(), "Warden Path mounted face releases cleanly")
	_validate_display({})
	_check(_snapshot() == before, "the whole Warden Path presentation pass changes no model")


func _unknown_check() -> void:
	var metadata = load("res://scripts/live_hand_card_metadata.gd").new()
	var unknown: Dictionary = metadata.describe("unreleased_card")
	_check(catalog.get_definition("unreleased_card").is_empty(), "unknown catalog lookup really empty")
	_check(not unknown["known"] and unknown["owner"] == "" and unknown["cost"] == -1
		and unknown["owner_text"] == "Unknown" and unknown["cost_text"] == "Cost ?",
		"unknown ID claims no invented owner or numeric energy")
	var foreign := PanelContainer.new()
	foreign.custom_minimum_size = Vector2(150, 96)
	var label := Label.new()
	label.text = "unreleased_card"
	foreign.add_child(label)
	root.add_child(foreign)
	await _frames()
	var before := _snapshot()
	var panels: Array[Node] = [foreign]
	var hand: Array[String] = ["unreleased_card"]
	metadata.sync(panels, hand)
	await _frames()
	_check(metadata._bindings.size() == 1 and metadata.get_facts(foreign) == unknown,
		"unknown ID draws only an honest placeholder")
	# An unknown ID shows neither a borrowed felt frame nor invented card art.
	var unknown_faces: Dictionary = metadata.get_faces(foreign)
	_check(unknown_faces.get("frame") == null and unknown_faces.get("picture") == null,
		"unknown mounted panel wears no borrowed sewn face")
	var unknown_geometry: Dictionary = metadata.get_geometry(foreign)
	var unknown_art: Rect2 = unknown_geometry.get("art", Rect2())
	_check(not bool(unknown_geometry.get("sewn", true)) and unknown_art.size == Vector2.ZERO,
		"unknown face keeps the drawn paper layout with no illustration band")
	# Unknown tooltip must not invent any quantity.
	var unknown_tooltip := foreign.tooltip_text
	_check(unknown_tooltip == "Unknown card", "unknown tooltip is honest 'Unknown card': got '" + unknown_tooltip + "'")
	_check(not unknown_tooltip.contains("damage") and not unknown_tooltip.contains("Block")
		and not unknown_tooltip.contains("heal") and not unknown_tooltip.contains("draw")
		and not unknown_tooltip.contains("energy") and not unknown_tooltip.contains("cost"),
		"unknown tooltip invents no effect numbers")
	_check(label.text == "unreleased_card" and foreign.get_child_count() == 1
		and foreign.gui_input.get_connections().is_empty(),
		"unknown panel leaves label and input inert")
	metadata.sync(panels, hand)
	_check(foreign.draw.get_connections().size() == 1, "unknown repeat bind idempotent")
	var absent: Array[String] = ["no_longer_in_hand"]
	metadata.sync(panels, absent)
	_check(metadata._bindings.is_empty() and foreign.draw.get_connections().is_empty(),
		"absent/incorrect ID immediately releases drawing callback")
	_check(foreign.tooltip_text == "" and not foreign.tooltip_text.contains("BASE")
		and not foreign.tooltip_text.contains("damage") and not foreign.tooltip_text.contains("Block"),
		"absent sync restores empty pre-bind tooltip with no stale effect words")
	metadata.sync(panels, hand)
	_check(metadata._bindings.size() == 1 and foreign.tooltip_text == "Unknown card",
		"rebind to unknown restores exact unknown tooltip")
	metadata.clear()
	_check(metadata._bindings.is_empty() and foreign.draw.get_connections().is_empty(),
		"explicit clear releases unknown panel")
	_check(foreign.tooltip_text == "" and not foreign.tooltip_text.contains("BASE")
		and not foreign.tooltip_text.contains("damage") and not foreign.tooltip_text.contains("Block"),
		"clear restores empty pre-bind tooltip with no stale effect words")
	# Same-panel valid-ID rebind: old effect text must be replaced, not duplicated.
	var rebind_panel := PanelContainer.new()
	rebind_panel.custom_minimum_size = Vector2(150, 96)
	var real_label := Label.new()
	real_label.text = "warden_brace"
	rebind_panel.add_child(real_label)
	root.add_child(rebind_panel)
	await _frames()
	var rebind_panels: Array[Node] = [rebind_panel]
	var rebind_hand: Array[String] = ["warden_brace"]
	metadata.sync(rebind_panels, rebind_hand)
	await _frames()
	_check(metadata._bindings.has(rebind_panel), "valid rebind creates binding")
	var brace_tooltip := rebind_panel.tooltip_text
	_check(brace_tooltip.contains("BASE gain 7 Block") and brace_tooltip.contains("Self"),
		"valid rebind tooltip shows exact brace effect and target")
	# The compact mounted face keeps the artwork too, with the rules, pips and
	# cost coin refitted below it instead of being covered by it.
	var compact_geometry: Dictionary = metadata.get_geometry(rebind_panel)
	_check(bool(compact_geometry.get("compact", false)) and bool(compact_geometry.get("sewn", false)),
		"compact mounted panel measures the compact sewn face")
	if not compact_geometry.is_empty() and compact_geometry.has("art"):
		var compact_bounds := Rect2(Vector2.ZERO, rebind_panel.size)
		var compact_art: Rect2 = compact_geometry["art"]
		_check(compact_art.size.x > 0.0 and compact_art.size.y > 0.0
			and compact_bounds.encloses(compact_art), "compact card still shows its picture band")
		_check(compact_art.end.y <= compact_geometry["footer"].position.y
			and compact_art.end.y <= compact_geometry["cost"].position.y
			and not compact_art.intersects(compact_geometry["footer"])
			and not compact_art.intersects(compact_geometry["cost"])
			and not compact_art.intersects(compact_geometry["title"]),
			"compact artwork stays clear of the rules, name and cost")
		var compact_rows: Dictionary = compact_geometry.get("rows", {})
		var compact_footer: Rect2 = compact_geometry["footer"]
		_check(compact_rows.size() == 3
			and compact_footer.encloses(compact_rows["from"])
			and compact_footer.encloses(compact_rows["target"])
			and compact_footer.encloses(compact_rows["rules"])
			and compact_rows["from"].end.y <= compact_rows["target"].position.y
			and compact_rows["target"].end.y <= compact_rows["rules"].position.y,
			"compact source, target and rule rows sit in order without overlap")
		_check(compact_bounds.encloses(compact_geometry["owner"])
			and compact_bounds.encloses(compact_geometry["cost"])
			and compact_geometry["owner"].end.x < compact_geometry["cost"].position.x,
			"compact owner tag and cost coin stay apart inside the card")
	# Replace with another real card on the same panel.
	real_label.text = "tinker_tune_up"
	rebind_hand = ["tinker_tune_up"]
	metadata.sync(rebind_panels, rebind_hand)
	await _frames()
	var tune_tooltip := rebind_panel.tooltip_text
	_check(tune_tooltip.contains("BASE draw 1 card") and tune_tooltip.contains("No target"),
		"rebind replaces tooltip with exact tune effect and target")
	_check(not tune_tooltip.contains("BASE gain 7 Block"),
		"rebind removes old brace effect text; no stale wording remains")
	metadata.clear()
	rebind_panel.free()
	foreign.free()
	_check(_snapshot() == before, "unknown/mismatched catalog view cannot touch any live model")


## Typography AC1/AC2: card titles and stitched halves select the master PatchHeading
## variation (Londrina Solid Regular), while body/rules/owner/tooltips retain Patrick Hand.
func _typography_check() -> void:
	var master_theme: Theme = load("res://assets/fonts/patchwork_theme.tres")
	_check(master_theme != null, "master Patchwork theme resource loads")
	if master_theme == null:
		return
	_check(master_theme.has_font("font", "PatchHeading"),
		"master Theme defines PatchHeading font variation")
	var master_heading: Font = master_theme.get_font("font", "PatchHeading")
	var master_body: Font = master_theme.default_font
	_check(master_heading != null and master_heading.resource_path.ends_with("LondrinaSolid-Regular.ttf"),
		"master PatchHeading resolves Londrina Solid Regular font")
	_check(master_body != null and master_body.resource_path.ends_with("PatrickHand-Regular.ttf"),
		"master Theme default font resolves Patrick Hand")
	_check(master_heading != master_body,
		"heading font and body font are distinct resources")

	var metadata = presenter._metadata
	var panels := _panels()
	_check(panels.size() > 0, "active hand panels present for typography inspection")
	# 1. Known starter cards currently held in the real battle hand.
	for panel in panels:
		if not is_instance_valid(panel) or panel.get_child_count() == 0:
			continue
		var card_id: String = panel.get_child(0).text
		_check(metadata.name_font(panel) == master_heading,
			"held card title selects PatchHeading Londrina Solid: " + card_id)
		_check(metadata.body_font(panel) == master_body,
			"held card body text retains default Patrick Hand: " + card_id)
		var facts: Dictionary = metadata.get_facts(panel)
		_check(metadata.definition(card_id).get("display_name") == facts.get("display_name"),
			"authored display_name preserved byte-for-byte: " + card_id)

	# 2. Probes for starter/base, pool and '+' cards mounted in app.hand_view.
	var probe_metadata = load(HAND_SCRIPT).new()
	probe_metadata.set_app(app)
	var test_card_ids := [
		"warden_strike", "warden_strike_plus",
		"seamstress_prick", "seamstress_prick_plus",
		"tinker_pop_shot", "tinker_pop_shot_plus",
		"warden_hold_the_line", "tinker_ricochet", "seamstress_needle_pin"
	]
	for test_id in test_card_ids:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(150, 96)
		var l := Label.new()
		l.text = test_id
		p.add_child(l)
		app.hand_view.add_child(p)
		await _frames()
		var p_panels: Array[Node] = [p]
		var p_hand: Array[String] = [test_id]
		probe_metadata.sync(p_panels, p_hand)
		await _frames()
		_check(probe_metadata.name_font(p) == master_heading,
			"mounted panel for %s selects PatchHeading Londrina Solid" % test_id)
		_check(probe_metadata.body_font(p) == master_body,
			"mounted panel for %s retains Patrick Hand body font" % test_id)
		var definition: Dictionary = probe_metadata.definition(test_id)
		_check(not definition.is_empty(), "test definition found: " + test_id)
		_check(probe_metadata.describe(test_id).get("display_name") == definition.get("display_name"),
			"display name unchanged for %s: %s" % [test_id, definition.get("display_name")])
		probe_metadata.clear()
		p.free()
		await _frames()

	# 3. Genuine stitched composite with two different-owner halves in tall and compact faces.
	var original_deck: Array[String] = app.run_deck.duplicate()
	var original_descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var original_scraps: int = app.run_scraps
	var original_next_id: int = app.run_next_stitch_id
	var battle_before: Array = _snapshot()
	seed(44719)
	var untouched_global := randi()
	seed(44719)

	var stitch_pair := ["warden_shield_bash", "seamstress_prick"]
	var stitch_first: Dictionary = metadata.definition(stitch_pair[0])
	var stitch_second: Dictionary = metadata.definition(stitch_pair[1])
	_check(stitch_first.get("owner") != stitch_second.get("owner"),
		"stitched card half owners differ: %s vs %s" % [stitch_first.get("owner"), stitch_second.get("owner")])

	var ledger := RunRestStitchCards.new(stitch_pair.duplicate(), {}, 3, 1)
	_check(ledger.is_valid(), "synthetic Rest stitch ledger is valid")
	var stitch_receipt := ledger.choose_stitch(0, 1, ledger.get_snapshot())
	_check(bool(stitch_receipt.get("ok", false)), "choose_stitch succeeds")
	var stitch_id: String = str(stitch_receipt.get("stitched_id", ""))
	_check(stitch_id.begins_with(RunRestStitchCards.ID_PREFIX), "stitched ID starts with prefix")

	var st_deck: Array[String] = [stitch_id]
	app.run_deck = st_deck
	app.run_stitch_descriptors = ledger.get_snapshot().descriptors.duplicate(true)
	app.run_scraps = ledger.get_snapshot().remaining_scraps
	app.run_next_stitch_id = ledger.get_snapshot().next_stitch_id

	# 3a. Tall stitched card
	var tall_panel := PanelContainer.new()
	tall_panel.theme = master_theme
	tall_panel.size = Vector2(230, 160)
	var tall_label := Label.new()
	tall_label.text = stitch_id
	tall_panel.add_child(tall_label)
	root.add_child(tall_panel)
	await _frames()
	var tall_panels: Array[Node] = [tall_panel]
	var tall_hand: Array[String] = [stitch_id]
	probe_metadata.sync(tall_panels, tall_hand)
	await _frames()
	var tall_geo: Dictionary = probe_metadata.get_geometry(tall_panel)
	_check(not tall_geo.get("compact", true), "tall stitched panel is not compact")
	_check((tall_geo.get("halves", []) as Array).size() == 2, "tall stitched panel has two half rects")
	_check(probe_metadata.name_font(tall_panel) == master_heading,
		"tall stitched panel title selects PatchHeading")
	_check(probe_metadata.half_name_font(tall_panel) == master_heading,
		"tall stitched halves select PatchHeading")
	_check(probe_metadata.body_font(tall_panel) == master_body,
		"tall stitched body text retains Patrick Hand")
	_assert_stitched_face(probe_metadata, tall_panel, stitch_id, stitch_pair)

	# 3b. Compact stitched card
	var compact_panel := PanelContainer.new()
	compact_panel.theme = master_theme
	compact_panel.size = Vector2(230, 96)
	var compact_label := Label.new()
	compact_label.text = stitch_id
	compact_panel.add_child(compact_label)
	root.add_child(compact_panel)
	await _frames()
	var compact_panels: Array[Node] = [compact_panel]
	var compact_hand: Array[String] = [stitch_id]
	probe_metadata.sync(compact_panels, compact_hand)
	await _frames()
	var compact_geo: Dictionary = probe_metadata.get_geometry(compact_panel)
	_check(compact_geo.get("compact", false) == true, "compact stitched panel measures compact")
	_check((compact_geo.get("halves", []) as Array).size() == 2, "compact stitched panel has two half rects")
	_check(probe_metadata.name_font(compact_panel) == master_heading,
		"compact stitched panel title selects PatchHeading")
	_check(probe_metadata.half_name_font(compact_panel) == master_heading,
		"compact stitched halves select PatchHeading")
	_check(probe_metadata.body_font(compact_panel) == master_body,
		"compact stitched body text retains Patrick Hand")
	_assert_stitched_face(probe_metadata, compact_panel, stitch_id, stitch_pair)

	probe_metadata.clear()
	tall_panel.free()
	compact_panel.free()
	await _frames()

	# A second authentic stitch brings in Tinker's distinct mustard cue and
	# exercises the same two textures and pip sets in reversed owner order.
	var tinker_pair := ["tinker_scrap_bomb", "warden_brace"]
	var second_ledger := RunRestStitchCards.new(tinker_pair.duplicate(), {}, 3, 1)
	_check(second_ledger.is_valid(), "Tinker + Warden stitch ledger is valid")
	var second_receipt := second_ledger.choose_stitch(0, 1, second_ledger.get_snapshot())
	_check(bool(second_receipt.get("ok", false)), "Tinker + Warden stitch commits")
	var second_id: String = str(second_receipt.get("stitched_id", ""))
	var second_deck: Array[String] = [second_id]
	app.run_deck = second_deck
	app.run_stitch_descriptors = second_ledger.get_snapshot().descriptors.duplicate(true)
	app.run_scraps = second_ledger.get_snapshot().remaining_scraps
	app.run_next_stitch_id = second_ledger.get_snapshot().next_stitch_id
	for panel_size in [Vector2(230, 160), Vector2(230, 96)]:
		var other := PanelContainer.new()
		other.theme = master_theme
		other.size = panel_size
		var other_label := Label.new()
		other_label.text = second_id
		other.add_child(other_label)
		root.add_child(other)
		await _frames()
		var other_panels: Array[Node] = [other]
		var other_hand: Array[String] = [second_id]
		probe_metadata.sync(other_panels, other_hand)
		await _frames()
		_assert_stitched_face(probe_metadata, other, second_id, tinker_pair)
		probe_metadata.clear()
		other.free()
		await _frames()

	# Optional missing images fail visibly to the authored colour, not to a
	# different half's illustration. Simulate an unavailable cached Warden
	# picture and emblem while retaining the real stitch descriptor.
	var missing_art = load(HAND_SCRIPT).new()
	missing_art.set_app(app)
	missing_art._textures[ART_DIR + "cards/art/warden_brace.png"] = null
	missing_art._textures[ART_DIR + "cards/emblem_warden.png"] = null
	var partial_images: Dictionary = missing_art.face_assets(second_id)
	var actual_halves: Array = partial_images.get("halves", [])
	_check(actual_halves.size() == 2, "missing-texture probe retains two real owner halves")
	if actual_halves.size() == 2:
		_check(actual_halves[0].get("owner") == "tinker"
			and actual_halves[0].get("picture") is Texture2D
			and actual_halves[1].get("owner") == "warden"
			and actual_halves[1].get("picture") == null
			and actual_halves[1].get("picture_path") == ""
			and actual_halves[1].get("colour") == missing_art.WARDEN,
			"missing Warden art stays its own colour with no borrowed Tinker image")
	var fallback_panel := PanelContainer.new()
	fallback_panel.theme = master_theme
	fallback_panel.size = Vector2(230, 96)
	var fallback_label := Label.new()
	fallback_label.text = second_id
	fallback_panel.add_child(fallback_label)
	root.add_child(fallback_panel)
	await _frames()
	var fallback_panels: Array[Node] = [fallback_panel]
	var fallback_hand: Array[String] = [second_id]
	missing_art.sync(fallback_panels, fallback_hand)
	await _frames()
	var bound_fallback: Array = missing_art.get_faces(fallback_panel).get("halves", [])
	_check(bound_fallback.size() == 2 and bound_fallback[1].get("picture") == null
		and (missing_art.get_geometry(fallback_panel).get("half_details", []) as Array).size() == 2
		and int(missing_art._bindings[fallback_panel].get("draw_count", 0)) > 0,
		"missing optional picture retains drawn two-owner compact geometry and tint fallback")
	_check(fallback_panel.tooltip_text == missing_art.stitched_tooltip(tinker_pair),
		"missing picture never loses the full numbered authored tooltip")
	missing_art.clear()
	fallback_panel.free()
	await _frames()

	app.run_deck = original_deck
	app.run_stitch_descriptors = original_descriptors
	app.run_scraps = original_scraps
	app.run_next_stitch_id = original_next_id
	await _frames()
	_check(app.run_deck == original_deck and app.run_stitch_descriptors == original_descriptors
		and app.run_scraps == original_scraps and app.run_next_stitch_id == original_next_id
		and _snapshot() == battle_before,
		"mounted dual-owner image, geometry, tooltips and rebinds mutate no run or combat state")
	_check(randi() == untouched_global,
		"two-owner stitched presentation draws no global RNG")

	# 4. Unknown/missing halves remain honest placeholders.
	var partial_facts := {
		"id": "stitched_test_partial",
		"halves": ["warden_strike", "missing_unknown_half"]
	}
	var partial_title: String = metadata._title(partial_facts)
	_check(partial_title.contains("Unknown half"), "partial halves produce honest placeholder: " + partial_title)
	_check(not metadata._halves_known(partial_facts["halves"]), "unknown half pair is not recognized as halves_known")

	# 5. Standalone test panel without theme resolves gracefully.
	var standalone := PanelContainer.new()
	standalone.theme = Theme.new()
	var un_themed_font: Font = metadata.name_font(standalone)
	_check(un_themed_font != null, "unthemed standalone panel resolves name font gracefully")
	standalone.free()
	await _frames()


## Both earned Spring versions must be enabled only by the mounted battle's
## real target preflight, never by their catalog face alone.
func _spring_face_states() -> void:
	if not await _start():
		return
	var metadata = presenter._metadata
	for id in ["tinker_spring_trap", "tinker_spring_trap_plus"]:
		app.deck.draw_pile.append(id)
		_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == id,
			"metadata Spring copy drawn by actual CombatDeck: " + id)
		app._refresh_hand()
		await _frames()
		var panel := _find(id)
		_check(panel != null and metadata._bindings.has(panel),
			"real Spring hand face mounted and decorated: " + id)
		if panel == null:
			continue
		var read_before := _snapshot()
		metadata._update_visual(panel)
		_check(metadata.visual_state(panel).get("playable", false)
			and panel.self_modulate.is_equal_approx(Color.WHITE),
			"legal living target and energy enable Spring face: " + id)
		_check(metadata.short_line(id) == SHORT_LINES[id]
			and panel.tooltip_text.contains("BASE Pin the target")
			and _occurrences(panel.tooltip_text, "PINNED:") == 1,
			"Spring short rule and Pinned Help remain exact: " + id)
		_check(_snapshot() == read_before, "Spring face read does not mutate battle: " + id)
		app.deck.combat_state.energy = 0
		metadata._update_visual(panel)
		_check(not metadata.visual_state(panel).get("playable", true)
			and not panel.self_modulate.is_equal_approx(Color.WHITE),
			"no energy dims mounted Spring face: " + id)
		app.deck.combat_state.energy = 3
		metadata._update_visual(panel)
		_check(metadata.visual_state(panel).get("playable", false),
			"restored energy restores legal Spring face: " + id)
	for index in range(1, app.enemies.get_enemies().size() + 1):
		if not app.enemies.is_slain(index):
			_check(app.enemies.apply_damage(index, 10000), "remove legal Spring target %d" % index)
	_check(app.enemies.is_victorious(), "Spring face no-target precondition is real")
	for id in ["tinker_spring_trap", "tinker_spring_trap_plus"]:
		var panel := _find(id)
		_check(panel != null, "Spring remains mounted for no-target face check: " + id)
		if panel == null:
			continue
		metadata._update_visual(panel)
		_check(not metadata.visual_state(panel).get("playable", true)
			and not panel.self_modulate.is_equal_approx(Color.WHITE),
			"no living legal enemy dims both Spring faces")
	app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null, "Spring metadata battle returns to title cleanly")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var pop_meta = load(HAND_SCRIPT).new()
	var pop_damage := {"button_golem_starter_loose_pop": 9, "button_golem_starter_loose_pop_plus": 11,
		"button_golem_pop_button": 9, "button_golem_pop_button_plus": 12}
	for id in pop_damage:
		var facts: Dictionary = pop_meta.describe(id)
		_check(facts.known and facts.owner_text == "Button Golem" and facts.cost == 1,
			"Pop metadata authentic owner and cost: " + id)
		_check(pop_meta.definition(id).from_positions == [1, 2] and pop_meta.definition(id).to_positions == [1, 2]
			and pop_meta.short_line(id) == "Spend 5 own Block; deal %d; pop 1 button." % pop_damage[id],
			"Pop exact slots, Block payment and printing damage: " + id)
	_check(not pop_meta.describe("button_golem_pop_button_plus_plus").known, "spoofed Pop metadata fails closed")
	_catalog_facts()
	_art_resolution_check()
	_source_check()
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene exists")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node_or_null("LiveSupportHand")
	_check(presenter != null and app.deck == null, "mounted hand lifecycle starts in title")
	if presenter == null:
		app.free()
		_finish()
		return
	_check(presenter._metadata._bindings.is_empty(), "no title-time decoration binds")
	var first_trace: Array = []
	for session in range(2):
		if not await _start():
			break
		var observed := {}
		var session_trace: Array = []
		var deck_ref = app.deck
		var before_duplicate := _snapshot()
		app._start_run()
		presenter._sync_battle()
		_check(app.deck == deck_ref and _snapshot() == before_duplicate,
			"duplicate Start Run does not replace or alter session")
		_validate_display(observed)
		if session == 0:
			_keyword_explanations(presenter._metadata)
			_formatter_check(presenter._metadata)
			await _status_help(presenter._metadata)
			await _warden_path_presentation()
			await _typography_check()
		await _visual_feedback()
		# Compare the same global RNG stream, not a separately seeded RNG instance.
		seed(8459)
		var next_global := randi()
		seed(8459)
		await _refresh_preserves_everything(observed)
		_check(randi() == next_global, "presentation does not draw from global RNG")
		var played_brace := false
		var played_tune := false
		for turn in range(14):
			session_trace.append([app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
				app.deck.discard_pile.duplicate()])
			if not played_brace and _find("warden_brace") != null:
				played_brace = await _play_support("warden_brace", observed)
			if not played_tune and _find("tinker_tune_up") != null:
				played_tune = await _play_support("tinker_tune_up", observed)
			_validate_display(observed)
			await _refresh_preserves_everything(observed)
			if turn < 13:
				var old_panels := _panels()
				app.end_turn_button.pressed.emit()
				await _frames()
				_check(app.deck != null and app.deck.turn_active, "legal End Turn opens next hand")
				if app.deck == null or app.hand_view == null:
					break
				for old in old_panels:
					if is_instance_valid(old):
						_check(not presenter._metadata._bindings.has(old),
							"End Turn removes stale panel drawing callback")
				_validate_display(observed)
		for card_id in CARD_FACTS:
			_check(observed.has(card_id), "all nine authored IDs were actually held: " + card_id)
		_check(played_brace and played_tune,
			"real eligible Brace and zero-energy Tune Up both played and refreshed")
		if session == 0:
			first_trace = session_trace
			await _unknown_check()
		else:
			_check(session_trace == first_trace, "two fixed-seed real-session hand/pile traces match")
		var old_panels := _panels()
		app.return_button.pressed.emit()
		_check(presenter._metadata._bindings.is_empty(), "Return immediately clears all metadata refs")
		for old in old_panels:
			if is_instance_valid(old):
				_check(old.draw.get_connections().is_empty(), "Return disconnects old draw callbacks")
				var pre_bind_tooltip: String = old.tooltip_text
				_check(not pre_bind_tooltip.contains("BASE deal") and not pre_bind_tooltip.contains("BASE gain")
					and not pre_bind_tooltip.contains("BASE heal") and not pre_bind_tooltip.contains("BASE draw"),
					"Return clears stale base-effect tooltip words: " + (old.get_child(0).text if old.get_child_count() > 0 else "?"))
		await _frames()
		_check(app.deck == null and app.battle_view == null,
			"Return to Title released run and battle")
		_check(presenter._metadata._bindings.is_empty() and app.start_button.has_focus(),
			"Title remains focusable and no stale panel survives")
	await _spring_face_states()
	app.free()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_hand_card_metadata_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
