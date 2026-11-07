extends SceneTree
## Mounted StitchedS5 foe-choice projection, using the SAME S2 public battle and live stage.
var checks := 0
var failures: Array[String] = []
var _pull_catalog: Dictionary = {}


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _mount(config: Dictionary = {}) -> Dictionary:
	var host := Control.new()
	host.name = "GothicFoeIntentHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var stage := StitchedBattleScreen.new()
	var data := config if not config.is_empty() else StitchedBattleScreen.read_preview()
	_check(stage.begin(data), "valid seeded battle starts through actual StitchedBattleScreen.begin")
	host.add_child(stage)
	return {"host": host, "stage": stage}


# Independent statement of the PRE-EXTRACTION live priority, not an echo of
# the production helper: same wraparound ability loop and first legal rank.
# A pulling enemy-target action alone scans the back rank first instead.
func _old_priority(battle: StitchedRules, actor: Dictionary) -> Dictionary:
	var abilities: Array = actor.get("abilities", [])
	var offset := (battle.round_number() - 1) % maxi(1, abilities.size())
	for step in range(abilities.size()):
		var ability: Dictionary = abilities[(offset + step) % abilities.size()]
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
			continue
		var scan_ranks: Array[int] = [1, 2, 3, 4]
		if str(ability.get("target_side", "")) == "enemy" and int(ability.get("effects", {}).get("pull", 0)) == 1:
			scan_ranks = [4, 3, 2, 1]
		for rank in scan_ranks:
			var targets := battle._legal_targets(actor, ability, rank)
			if not targets.is_empty():
				var affected: Array[int] = []
				for target in targets:
					if not affected.has(int(target["rank"])):
						affected.append(int(target["rank"]))
				affected.sort()
				return {"ability_id": str(ability["id"]), "target_rank": rank,
					"target_side": str(targets[0]["side"]), "affected_ranks": affected,
					"multi": bool(ability["multi"]), "ability_kind": str(ability.get("kind", ""))}
	return {"pass": true}


# ---------------------------------------------------------------- compact pull fixture

func _to(battle: StitchedRules, actor_id: String, minimum_round: int = 1) -> bool:
	for step in range(80):
		if battle.is_over():
			return false
		if battle.current_actor_id() == actor_id and battle.round_number() >= minimum_round:
			return true
		if not bool(battle.pass_turn().get("ok", false)):
			return false
	return false


func _hero_id_at(battle: StitchedRules, rank: int) -> String:
	for hero in battle.get_heroes():
		if int(hero["rank"]) == rank:
			return str(hero["id"])
	return ""


func _pull_config() -> Dictionary:
	var config: Dictionary = StitchedBattleScreen.read_preview()
	config["seed"] = 11
	config["candle"] = 100
	config["parts"].append_array(_pull_catalog["parts"].duplicate(true))
	config["foes"] = [
		StitchedEnemyCatalog.foe_for(_pull_catalog, "spool_snarekeeper"),
		StitchedEnemyCatalog.foe_for(_pull_catalog, "ragling"),
	]
	return config


func _pull_battle() -> StitchedRules:
	var built := StitchedRules.create(_pull_config())
	_check(bool(built.get("ok", false)), "compact pull fixture builds a real 4v2 battle")
	return built["battle"] if bool(built.get("ok", false)) else null


func _test_pull_fixture() -> void:
	_pull_catalog = StitchedEnemyCatalog.load_catalog()
	_check(bool(_pull_catalog.get("ok", false)), "compact pull fixture loads the real enemy catalog")
	if not bool(_pull_catalog.get("ok", false)):
		return
	var battle := _pull_battle()
	if battle == null:
		return
	var snake := "spool_snarekeeper"
	_check(_to(battle, snake), "compact pull fixture reaches the Snarekeeper's first turn")
	var opening := StitchedFoeIntent.choose(battle, battle.get_unit(snake))
	_check(str(opening.get("ability_id", "")) == "snare_lash"
		and int(opening.get("target_rank", 0)) == 1 and opening.get("affected_ranks") == [1],
		"non-pull Snare Lash keeps the original nearest-legal rank-1 order")
	_check(_to(battle, snake, 2), "compact pull fixture reaches round two's Snarekeeper turn")
	var state := battle.state_snapshot()
	var rng := battle.rng_state()
	var expected := _old_priority(battle, battle.get_unit(snake))
	var choice := StitchedFoeIntent.choose(battle, battle.get_unit(snake))
	_check(str(choice.get("ability_id", "")) == "spool_snare"
		and int(choice.get("target_rank", 0)) == 4 and choice.get("affected_ranks") == [4]
		and str(choice.get("target_side", "")) == "hero"
		and str(choice.get("ability_kind", "")) == "debuff"
		and not bool(choice.get("multi", true))
		and int(choice.get("base_acc", -1)) == 90
		and choice.get("base_damage") == [0, 0]
		and choice.get("base_effects") == {"pull": 1, "fray": 6},
		"Spool Snare hunts the deepest living rank 4 first")
	_check(choice.get("ability_id") == expected.get("ability_id")
		and int(choice.get("target_rank", 0)) == int(expected.get("target_rank", 0))
		and choice.get("affected_ranks") == expected.get("affected_ranks"),
		"independent pull-first comparator matches the real chooser")
	_check(battle.state_snapshot() == state and battle.rng_state() == rng,
		"pull intent projection never mutates state or consumes RNG")
	var fallback := _pull_battle()
	if fallback != null and _to(fallback, snake, 2):
		fallback._units[_hero_id_at(fallback, 4)]["lost"] = true
		fallback._units[_hero_id_at(fallback, 3)]["lost"] = true
		var near := StitchedFoeIntent.choose(fallback, fallback.get_unit(snake))
		_check(str(near.get("ability_id", "")) == "spool_snare"
			and int(near.get("target_rank", 0)) == 2 and near.get("affected_ranks") == [2],
			"lost rank 4 and 3 fall back to the next deepest legal rank 2, not a phantom")
		fallback._units[_hero_id_at(fallback, 2)]["lost"] = true
		var next := StitchedFoeIntent.choose(fallback, fallback.get_unit(snake))
		_check(str(next.get("ability_id", "")) == "snare_lash"
			and int(next.get("target_rank", 0)) == 1 and next.get("affected_ranks") == [1],
			"no legal pull target falls through to the normal next-ability rank-1 order")


func _kind_texture(kind: String) -> Texture2D:
	match kind:
		"melee", "ranged":
			return load("res://assets/paper/ui/intent_attack.png") as Texture2D
		"guard":
			return load("res://assets/paper/ui/intent_defend.png") as Texture2D
		"buff", "heal":
			return load("res://assets/paper/ui/intent_buff.png") as Texture2D
		"debuff":
			return load("res://assets/paper/ui/intent_debuff.png") as Texture2D
	return null


func _verify_base(intent: Dictionary, ability: Dictionary, ticket: StitchedFoeIntentPlate, note: String) -> void:
	var damage: Array = ability.get("dmg", [])
	var effects: Dictionary = ability.get("effects", {})
	var expected_damage := "BASE DMG %d–%d" % [int(damage[0]), int(damage[1])]
	_check(intent.get("base_damage", []) == damage
		and int(intent.get("base_acc", -1)) == int(ability["acc"])
		and int(intent.get("base_crit", -999)) == int(ability["crit"])
		and intent.get("base_effects", {}) == effects
		and ticket.tooltip_text.contains(expected_damage)
		and ticket.tooltip_text.contains("BASE ACC %d%%" % int(ability["acc"]))
		and ticket.tooltip_text.contains("BASE CRIT %+d" % int(ability["crit"]))
		and ticket.tooltip_text.contains("BASE EFFECTS"),
		"%s uses the exact selected authored BASE damage, ACC, crit and effects" % note)
	for key in effects:
		_check(ticket.tooltip_text.contains("%s %+d" % [str(key), int(effects[key])]),
			"%s reveals authored BASE effect %s" % [note, str(key)])
	_check(not ticket.secondary.text.contains("BASE"), "%s keeps base-stat terminology in disclosure" % note)
	if int(intent.get("base_mark_damage", 0)) > 0:
		_check(ticket.tooltip_text.contains("BONUS VS MARK +%d" % int(intent["base_mark_damage"])),
			"%s retains exact authored Mark bonus" % note)
	if int(damage[1]) <= 0:
		_check(not ticket.secondary.text.contains("DAMAGE") and ticket.tooltip_text.contains("BASE DMG 0–0"),
			"%s: zero-damage ability has no misleading damage threat caption" % note)
	elif ticket.secondary.text.contains("DAMAGE"):
		_check(str(intent.get("ability_kind", "")) in ["melee", "ranged"]
			and ticket.secondary.text.ends_with(" · %d–%d DAMAGE" % [int(damage[0]), int(damage[1])])
			and _caption_fits(ticket.secondary),
			"%s: optional authored damage caption is complete and pixel-fit" % note)


func _verify_target(intent: Dictionary, ticket: StitchedFoeIntentPlate, note: String) -> void:
	var ranks: Array[String] = []
	for rank in intent["affected_ranks"]:
		ranks.append(str(rank))
	var several := bool(intent["multi"]) or ranks.size() > 1
	var cue := ("HERO" if intent["target_side"] == "hero" else "FOE") \
		+ (" RANKS " if several else " RANK ") + ",".join(ranks)
	var damage: Array = intent["base_damage"]
	var candidate := cue + " · %d–%d DAMAGE" % [int(damage[0]), int(damage[1])]
	var label := ticket.secondary
	var font := label.get_theme_font("font")
	var fits := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x <= label.size.x
	var show_damage := str(intent["ability_kind"]) in ["melee", "ranged"] and int(damage[1]) > 0 and fits
	_check(label.text == (candidate if show_damage else cue)
		and not label.text.contains("…") and not label.text.contains("BASE")
		and label.get_theme_font_size("font_size") >= 18 and _caption_fits(label),
		"%s shows the complete ordinary-word side/ranks and only measured complete damage" % note)


func _verify_tickets(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var found := 0
	for rank in range(1, 5):
		var foe := stage._unit_at("foe", rank)
		var ticket: StitchedFoeIntentPlate = stage._foe_tickets[rank]
		var icon: TextureRect = ticket.get_node("IntentGlyph")
		if foe.is_empty():
			_check(not ticket.visible and not stage._foe_intents.has(rank)
				and ticket.foe_id.is_empty() and ticket.foe_rank == 0
				and ticket.ability_kind.is_empty() and icon.texture == null and not icon.visible
				and ticket.tooltip_text.is_empty(),
				"empty, fallen or heap rank %d has no misleading ticket or glyph" % rank)
			continue
		found += 1
		var expected := _old_priority(battle, foe)
		var intent := StitchedFoeIntent.choose(battle, foe)
		_check(ticket.visible and not intent.is_empty() and stage._foe_intents[rank] == intent,
			"live rank %d displays the authoritative, detached chooser" % rank)
		if expected.has("pass") or bool(intent.get("stun", false)):
			_check(bool(intent.get("pass", false)) or bool(intent.get("stun", false)),
				"unlaunchable foe rank %d shows PASS or STUN" % rank)
			_check(str(intent.get("ability_kind", "")) == "" and icon.texture == null
				and not icon.visible and ticket.ability_kind.is_empty()
				and int(intent.get("target_rank", -1)) == 0
				and intent.get("affected_ranks", [1]).is_empty()
				and not intent.has("base_damage") and not intent.has("base_effects")
				and not ticket.tooltip_text.contains("BASE"),
				"skipped rank %d has no kind, BASE threat, combat glyph or fake targets" % rank)
		else:
			_check(not bool(intent.get("pass", true)) and str(intent["ability_id"]) == str(expected["ability_id"])
				and int(intent["target_rank"]) == int(expected["target_rank"])
				and str(intent["target_side"]) == str(expected["target_side"])
				and intent["affected_ranks"] == expected["affected_ranks"]
				and bool(intent["multi"]) == bool(expected["multi"])
				and str(intent["ability_kind"]) == str(expected["ability_kind"]),
				"rank %d matches independent round-rotated legal choice, kind, target and all targets" % rank)
			var selected: Dictionary = {}
			var matches := 0
			for ability in foe.get("abilities", []):
				if str(ability["id"]) == str(intent["ability_id"]):
					selected = ability
					matches += 1
			_check(matches == 1 and not selected.is_empty()
				and str(intent["ability_kind"]) == str(selected.get("kind", ""))
				and ticket.ability_kind == str(selected.get("kind", ""))
				and icon.texture == _kind_texture(str(selected.get("kind", "")))
				and icon.visible == (_kind_texture(str(selected.get("kind", ""))) != null)
				and ticket.tooltip_text.contains(str(intent["ability_name"]))
				and ticket.tooltip_text.contains("Kind: " + str(intent["ability_kind"]).to_upper()),
				"rank %d icon and kind match exactly the selected legal authored ID" % rank)
			if matches == 1 and not selected.is_empty():
				_verify_base(intent, selected, ticket, "rank %d selected ability" % rank)
				_verify_target(intent, ticket, "live rank %d" % rank)
		_check(ticket.foe_id == str(foe["id"]) and ticket.foe_rank == rank and
			ticket.tooltip_text.contains(str(foe["name"])) and
			ticket.tooltip_text.contains("Current intent; may change if ranks or statuses change") and
			ticket.get_tooltip(Vector2(10, 10)).is_empty(),
			"foe rank %d names actual actor and provisionality" % rank)
	_check(found >= 2, "non-vacuous: mounted battle has at least two visible living foe tickets")


# Exercise the actual live preview's Fray Scavenger against the canonical enemy
# catalog, rather than inventing a Sack Swing projection for a detached label.
func _verify_sack_swing_live(stage: StitchedBattleScreen) -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	var canonical := StitchedEnemyCatalog.foe_for(catalog, "fray_scavenger")
	_check(bool(catalog.get("ok", false)) and not canonical.is_empty()
		and not canonical.get("abilities", []).is_empty(),
		"precondition: canonical Fray Scavenger and authored Sack Swing are loaded")
	if canonical.is_empty() or canonical.get("abilities", []).is_empty():
		return
	var actor: Dictionary = stage.battle._units.get("fray_scavenger", {})
	_check(not actor.is_empty(), "precondition: mounted real Fray Scavenger is alive")
	if actor.is_empty():
		return
	var rank := int(actor["rank"])
	_check(rank >= 1 and rank <= 4 and stage._foe_intents.has(rank),
		"precondition: actual Scavenger has a legal occupied foe rank and projected intent")
	if rank < 1 or rank > 4 or not stage._foe_intents.has(rank):
		return
	var ticket: StitchedFoeIntentPlate = stage._foe_tickets[rank]
	var title: Label = ticket.primary
	var target: Label = ticket.secondary
	var projected: Dictionary = stage._foe_intents[rank]
	var authored: Dictionary = canonical["abilities"][0]
	_check(str(authored.get("id", "")) == "sack_swing"
		and str(authored.get("name", "")) == "Sack Swing"
		and str(actor["abilities"][0]["id"]) == str(authored["id"])
		and str(actor["abilities"][0]["name"]) == str(authored["name"])
		and str(projected.get("ability_id", "")) == "sack_swing"
		and str(projected.get("ability_name", "")) == str(authored["name"]),
		"real live chooser projects the canonical authored Sack Swing, not a made-up fixture")
	var font: Font = title.get_theme_font("font")
	_check(font != null and title.size.x == 100.0 and title.size.y == 29.0
		and ticket.size == Vector2(140, 58) and ticket.texture == StitchedFoeIntentPlate.PLATE_TEXTURE
		and ticket.glyph.visible and ticket.glyph.texture == _kind_texture("melee"),
		"precondition: genuine 140px textured plate retains its glyph-aware 100px heading row")
	if font == null:
		return
	var expected_size := 24
	while expected_size > 16 and font.get_string_size(
			"SACK SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, expected_size).x > title.size.x:
		expected_size -= 1
	var pixels := title.get_theme_font_size("font_size")
	var glyph_rect := Rect2(ticket.glyph.position, ticket.glyph.size)
	var title_rect := Rect2(title.position, title.size)
	var target_rect := Rect2(target.position, target.size)
	_check(font.get_string_size("SACK SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x > title.size.x
		and font.get_string_size("SACK SWING", HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= title.size.x
		and title.text == "SACK SWING" and pixels == expected_size
		and pixels >= 16 and pixels < 24 and _caption_fits(title)
		and not glyph_rect.intersects(title_rect) and not title_rect.intersects(target_rect)
		and not glyph_rect.intersects(target_rect),
		"canonical Sack Swing renders completely at independently measured 16-23px without row collisions")
	_check(projected.get("target_side", "") == "hero"
		and int(projected.get("target_rank", 0)) == 1
		and projected.get("affected_ranks", []) == [1]
		and target.text.begins_with("HERO RANK 1") and _caption_fits(target)
		and ticket.tooltip_text.contains("Sack Swing")
		and ticket.tooltip_text.contains("Target: HERO rank 1")
		and ticket.tooltip_text.contains("fray +4"),
		"live Sack Swing retains exact legal hero rank and authored effect disclosure")
	var snapshot := stage.battle.state_snapshot()
	var rng := stage.battle.rng_state()
	var receipts := stage.receipts.duplicate(true)
	var original_name := str(actor["abilities"][0]["name"])
	actor["abilities"][0]["name"] = "Pin"
	stage._refresh()
	_check(title.text == "PIN" and title.get_theme_font_size("font_size") == 24
		and ticket.glyph.visible and target.text.begins_with("HERO RANK 1"),
		"short name starts at the full-size 24px heading with the correct attack and target")
	actor["abilities"][0]["name"] = original_name
	stage._refresh()
	_check(title.text == "SACK SWING" and title.get_theme_font_size("font_size") == expected_size
		and _caption_fits(title), "short-to-long refresh recalculates the full ordinary heading")
	var huge := "An Impossibly Long Sack Swing of Moonlit Thread and Rusty Needles"
	actor["abilities"][0]["name"] = huge
	stage._refresh()
	_check(title.get_theme_font_size("font_size") == 16 and title.text.ends_with("…")
		and _caption_fits(title) and ticket.tooltip_text.contains(huge)
		and ticket.tooltip_text.contains("Target: HERO rank 1")
		and ticket.tooltip_text.contains("BASE DMG 4–7")
		and ticket.tooltip_text.contains("fray +4"),
		"overlong authored heading ellipsizes only at 16px while retaining full ability, target and effects")
	ticket.mouse_entered.emit()
	_check(stage._intent_disclosure.visible
		and stage._intent_disclosure_label.text == ticket.tooltip_text
		and stage._intent_disclosure_label.text.contains(huge),
		"live hover disclosure reveals the complete overlong ability and base effects")
	ticket.mouse_exited.emit()
	ticket.grab_focus()
	_check(ticket.has_focus() and stage._intent_disclosure.visible
		and stage._intent_disclosure_label.text.contains(huge),
		"keyboard focus shows identical full overlong authored disclosure")
	stage._action_buttons["pass"].grab_focus()
	actor["abilities"][0]["name"] = "Pin"
	stage._refresh()
	_check(title.text == "PIN" and title.get_theme_font_size("font_size") == 24
		and not stage._intent_disclosure.visible and ticket.tooltip_text.contains("Pin")
		and not ticket.tooltip_text.contains(huge),
		"long-to-short resets 24px and does not retain stale name or disclosure")
	actor["abilities"][0]["name"] = original_name
	stage._refresh()
	_check(title.text == "SACK SWING" and title.get_theme_font_size("font_size") == expected_size
		and snapshot == stage.battle.state_snapshot()
		and rng == stage.battle.rng_state() and receipts == stage.receipts,
		"all real intent name, hover, focus and refresh transitions leave state, RNG and receipts untouched")


func _verify_kind_fixtures(host: Control) -> void:
	# The genuine opening three foes do not exercise every authored kind. Mount
	# one additional REAL ticket, transition it through every icon category,
	# then through legal MOVE/unknown and no-action states.
	var ticket := StitchedFoeIntentPlate.new()
	ticket.position = Vector2(450, 245)
	host.add_child(ticket)
	var intent := {
		"foe_id": "fixture_foe", "foe_name": "Fixture foe", "ability_id": "fixture",
		"ability_name": "Fixture maneuver", "ability_kind": "", "target_side": "hero",
		"target_rank": 2, "affected_ranks": [2], "multi": false,
		"pass": false, "stun": false,
		"base_acc": 88, "base_damage": [4, 7], "base_crit": 3,
		"base_effects": {"fray": 4}
	}
	_check(ticket.get_node("IntentGlyph") == ticket.glyph
		and ticket.glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and ticket.glyph.size.x >= 24 and ticket.glyph.size.y >= 24,
		"direct mounted ticket has a readable mouse-transparent IntentGlyph")
	var mapped := 0
	for kind in ["melee", "ranged", "guard", "buff", "heal", "debuff", "move", "unknown", ""]:
		intent["ability_kind"] = kind
		intent["ability_name"] = "Flutter Back" if kind == "move" else "Fixture maneuver"
		if kind in ["buff", "debuff", "heal", "guard"]:
			intent["base_damage"] = [0, 0]
			intent["base_effects"] = {"riposte": 1} if kind == "buff" else {"snip": 1}
		else:
			intent["base_damage"] = [4, 7]
			intent["base_effects"] = {"fray": 4}
		ticket.present_intent(intent, 1)
		var expected: Texture2D = _kind_texture(kind)
		_check(ticket.visible and ticket.foe_id == "fixture_foe"
			and ticket.ability_kind == kind and ticket.glyph.texture == expected
			and ticket.glyph.visible == (expected != null)
			and ticket.tooltip_text.contains(str(intent["ability_name"]))
			and (kind.is_empty() or ticket.tooltip_text.contains("Kind: " + kind.to_upper()))
			and ticket.secondary.text.begins_with("HERO RANK 2")
			and _caption_fits(ticket.primary) and _caption_fits(ticket.secondary),
			"mounted fixture kind '%s' has truthful icon and full legal ability/target disclosure" % kind)
		_verify_target(intent, ticket, "mounted kind " + kind)
		if expected != null:
			mapped += 1
		if kind in ["buff", "debuff", "heal", "guard"]:
			_check(not ticket.secondary.text.contains("BASE") and ticket.tooltip_text.contains("BASE DMG 0–0"),
				"non-damaging mounted %s never advertises direct attack damage" % kind)
		if kind == "move":
			_check(ticket.primary.text.begins_with("MOVE")
				and ticket.tooltip_text.contains("Flutter Back") and not ticket.glyph.visible
				and not ticket.secondary.text.contains("DAMAGE"),
				"MOVE is explicitly labelled without pretending to be an attack or buff")
	_check(mapped == 6, "six mapped authored ability kinds tested with exact shipped PNGs")
	# Every lawful rank subset, including gaps and all four ranks on both sides.
	intent["ability_kind"] = "melee"
	intent["base_damage"] = [4, 7]
	intent["base_mark_damage"] = 3
	for side in ["hero", "foe"]:
		intent["target_side"] = side
		for mask in range(1, 16):
			var ranks: Array[int] = []
			for rank in range(1, 5):
				if mask & (1 << (rank - 1)):
					ranks.append(rank)
			intent["affected_ranks"] = ranks
			intent["target_rank"] = ranks[0]
			for multi in [false, true]:
				intent["multi"] = multi
				ticket.present_intent(intent, 1)
				_verify_target(intent, ticket, "%s ranks %s multi %s" % [side, ranks, multi])
	# Exact measured boundaries exercise inclusion and omission without chopping numbers.
	intent["target_side"] = "hero"
	intent["affected_ranks"] = [2]
	intent["target_rank"] = 2
	intent["multi"] = false
	intent["base_damage"] = [123, 4567]
	var candidate := "HERO RANK 2 · 123–4567 DAMAGE"
	var width := ticket.secondary.get_theme_font("font").get_string_size(
		candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	for delta in [1, -1]:
		ticket.secondary.size.x = width + delta
		ticket.present_intent(intent, 1)
		_verify_target(intent, ticket, "damage boundary %d pixels" % delta)
		_check(ticket.secondary.text == (candidate if delta > 0 else "HERO RANK 2")
			and ticket.tooltip_text.contains("BASE DMG 123–4567")
			and ticket.tooltip_text.contains("BASE ACC 88%")
			and ticket.tooltip_text.contains("BASE CRIT +3")
			and ticket.tooltip_text.contains("fray +4")
			and ticket.tooltip_text.contains("BONUS VS MARK +3"),
			"width boundary keeps complete interval or target-only cue and all authored disclosure")
	for kind in ["move", "guard", "buff", "heal", "debuff", "unknown"]:
		intent["ability_kind"] = kind
		ticket.secondary.size.x = width + 1
		ticket.present_intent(intent, 1)
		_check(ticket.secondary.text == "HERO RANK 2"
			and ticket.tooltip_text.contains("BASE DMG 123–4567"),
			"%s with positive base numbers still cannot advertise an attack hit" % kind)
	intent["ability_kind"] = "melee"
	ticket.secondary.size.x = 134
	for missing in [{"target_side": "hero", "affected_ranks": []},
			{"target_side": "", "affected_ranks": [2]},
			{"target_side": "heap", "affected_ranks": [2]},
			{"target_side": "foe", "affected_ranks": [0, 2, 5]}]:
		intent.merge(missing, true)
		ticket.present_intent(intent, 1)
		_check(ticket.secondary.text == "NO TARGET" and not ticket.tooltip_text.contains("Target:")
			and ticket.tooltip_text.contains("No currently legal target")
			and ticket.tooltip_text.contains("BASE DMG 123–4567"),
			"missing or invalid side/ranks cannot fabricate a target or hit")
	for state in ["pass", "stun"]:
		intent["ability_kind"] = "melee" # malformed stale data must not paint a strike
		intent["pass"] = state == "pass"
		intent["stun"] = state == "stun"
		intent["target_rank"] = 0
		intent["target_side"] = ""
		intent["affected_ranks"] = []
		ticket.present_intent(intent, 1)
		_check(ticket.visible and ticket.ability_kind.is_empty()
			and ticket.glyph.texture == null and not ticket.glyph.visible
			and ticket.primary.text == state.to_upper()
			and ticket.primary.get_theme_font_size("font_size") == 24
			and ticket.secondary.text == "NO ACTION"
			and not ticket.tooltip_text.contains("Target:")
			and not ticket.tooltip_text.contains("Kind:")
			and not ticket.tooltip_text.contains("BASE")
			and ticket.tooltip_text.contains("Current intent; may change"),
			"%s clears previous threat and any fake legal action" % state.to_upper())
	ticket.clear_intent()
	_check(not ticket.visible and ticket.foe_id.is_empty() and ticket.foe_rank == 0
		and ticket.ability_kind.is_empty() and ticket.glyph.texture == null
		and not ticket.glyph.visible and ticket.primary.text.is_empty()
		and ticket.primary.get_theme_font_size("font_size") == 24
		and ticket.secondary.text.is_empty() and ticket.tooltip_text.is_empty(),
		"clear_intent wipes the mounted glyph, kind, label, target and disclosure")
	ticket.free()


func _caption_fits(label: Label) -> bool:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return false
	var pixels := label.get_theme_font_size("font_size")
	return "\n" not in label.text and label.clip_text and (
		font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x <= label.size.x + 0.5
		and font.get_height(pixels) <= label.size.y + 0.5)


func _check_geometry(stage: StitchedBattleScreen, expected_count: int = 3) -> void:
	var sewn: Texture2D = load("res://assets/paper/ui/hud_name_plate.png")
	_check(sewn != null and stage._foe_tickets.size() == 4
		and stage._foe_ticket_labels.size() == 4 and stage._foe_ticket_target_labels.size() == 4,
		"all four public foe-rank tickets retain authored NinePatch art and two separate labels")
	var earlier_rectangles: Array[Rect2] = []
	var header := Rect2(710, 105, 545, 30)
	var ribbon := stage._turn_ribbon.get_global_rect()
	var candle := stage._candle_meter.get_global_rect()
	var tray := Rect2(12, 557, 1256, 155)
	var painted_count := 0
	var figures: Dictionary = {}
	for rank in range(1, 5):
		var puppet: Control = stage._puppets["foe_" + str(rank)]
		if not puppet.visible:
			continue
		# Independently measure each actual painted pose in screen coordinates,
		# not the full-size transparent Puppet Control or production anchor cache.
		var art: Rect2 = puppet.posed_actor_rect()
		var painted := Rect2(puppet.get_global_transform() * art.position, art.size)
		figures[rank] = painted
		painted_count += 1
		_check(art.size.x > 0 and art.size.y >= 120.0 and art.size.y <= 290.0
			and painted.end.y <= 505.0 and painted.position.x >= 0.0
			and painted.end.x <= 1280.0,
			"rank %d really paints a fitted nonempty actor inside the live stage" % rank)
	for rank in range(1, 5):
		var ticket: StitchedFoeIntentPlate = stage._foe_tickets[rank]
		if not ticket.visible:
			_check(not figures.has(rank) and ticket.foe_id.is_empty(),
				"vacated rank %d has no orphaned visible intent" % rank)
			continue
		var rectangle := ticket.get_global_rect()
		var ability: Label = stage._foe_ticket_labels[rank]
		var target: Label = stage._foe_ticket_target_labels[rank]
		var glyph: TextureRect = ticket.get_node("IntentGlyph")
		var painted: Rect2 = figures.get(rank, Rect2())
		_check(painted.size.x > 0.0 and painted.size.y > 0.0
			and absf(rectangle.get_center().x - painted.get_center().x) <= 9.0
			and painted.position.y - rectangle.end.y >= 6.0
			and painted.position.y - rectangle.end.y <= 100.0,
			"rank %d is tightly anchored just above its OWN actual painted figure" % rank)
		_check(ticket.texture == sewn and stage._intent_disclosure.texture == sewn
			and ticket.self_modulate == Color("62464a")
			and ticket.patch_margin_left >= 16 and ticket.patch_margin_top >= 8
			and ticket.focus_mode == Control.FOCUS_ALL
			and rectangle.size.x >= 140 and rectangle.size.y <= 68
			and rectangle.position.x >= 0 and rectangle.end.x <= 1280
			and rectangle.position.y >= 140 and rectangle.end.y <= 505
			and not rectangle.intersects(header)
			and not rectangle.intersects(ribbon) and not rectangle.intersects(candle)
			and not rectangle.intersects(tray),
			"rank %d compact authored plaque stays in viewport, outside header, ribbon, candle and tray" % rank)
		for other in range(1, 5):
			_check(not rectangle.intersects(stage._foot_plates["foe_" + str(other)].get_global_rect()),
				"foe rank %d never covers a neighboring rank or HP/FRAY footplate %d" % [rank, other])
			if figures.has(other):
				_check(not rectangle.intersects(figures[other]),
					"foe rank %d does not occlude painted actor %d, including neighbors" % [rank, other])
		var glyph_rect := Rect2(glyph.position, glyph.size)
		var ability_rect := Rect2(ability.position, ability.size)
		var target_rect := Rect2(target.position, target.size)
		_check(ability.get_parent() == ticket and target.get_parent() == ticket
			and ability != target and ability.clip_text and target.clip_text
			and ability.get_theme_font_size("font_size") >= 16
			and ability.get_theme_font_size("font_size") <= 24
			and target.get_theme_font_size("font_size") >= 18
			and ability.size.x >= 100 and target.size.x >= 132
			and glyph.get_parent() == ticket and glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and glyph.size.x >= 26 and glyph.size.y >= 26
			and glyph_rect.position.x >= 0 and glyph_rect.position.y >= 0
			and glyph_rect.end.x <= ticket.size.x and glyph_rect.end.y <= ticket.size.y
			and not ability_rect.intersects(target_rect)
			and (not glyph.visible or not glyph_rect.intersects(ability_rect))
			and (not glyph.visible or not glyph_rect.intersects(target_rect))
			and ability_rect.position.x >= 0 and ability_rect.end.x <= ticket.size.x
			and ability_rect.position.y >= 0 and ability_rect.end.y <= ticket.size.y
			and target_rect.position.x >= 0 and target_rect.end.x <= ticket.size.x
			and target_rect.position.y >= 0 and target_rect.end.y <= ticket.size.y
			and ability.get_theme_color("font_color") == StitchedFoeIntentPlate.BONE
			and target.get_theme_color("font_color") == StitchedFoeIntentPlate.BRASS
			and _caption_fits(ability) and _caption_fits(target),
			"rank %d real 24/18px labels pixel-fit in separate rows without overlapping glyph" % rank)
		for earlier in earlier_rectangles:
			_check(not rectangle.intersects(earlier),
				"foe rank %d has no pairwise plaque collision across four physical ranks" % rank)
		earlier_rectangles.append(rectangle)
	_check(painted_count == expected_count,
		"non-vacuous geometry checks every posed occupied foe, including admitted fourth rank")
	var detail := stage._intent_disclosure.get_global_rect()
	_check(stage._intent_disclosure.self_modulate == Color("62464a")
		and detail.position == Vector2(22, 140) and detail.end.y <= 220
		and detail.end.x <= 660
		and stage._intent_disclosure_label.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		and stage._intent_disclosure_label.get_theme_color("font_color") == StitchedBattleScreen.PAPER,
		"full pointer/keyboard disclosure retains authored frame and hero-side air")
	for rank in range(1, 5):
		var hero: Control = stage._puppets["hero_" + str(rank)]
		var hero_rect: Rect2 = hero.posed_actor_rect()
		_check(not Rect2(hero.global_position + hero_rect.position, hero_rect.size).intersects(detail),
			"rank %d hero painted bounds clear independent full disclosure" % rank)
	_check(root.get_viewport().get_visible_rect().size == Vector2(1280, 720),
		"headless 1280x720 Gothic viewport has intended visual bounds")

# Commit only an actual hero Pass through the live screen. The automatic foe
# driver will resolve the imminent actor; compare its first receipt with the
# ticket read immediately BEFORE that pass.
func _verify_receipt(stage: StitchedBattleScreen) -> void:
	var battle := stage.battle
	var witnessed := false
	for step in range(15):
		if battle.is_over() or battle.current_side() != "hero":
			break
		var snapshot := battle.state_snapshot()
		var order: Array = snapshot["order"]
		var next_index := int(snapshot["turn_index"]) + 1
		var next_id := str(order[next_index]) if next_index < order.size() else ""
		var next_actor := battle.get_unit(next_id)
		var before := stage.receipts.size()
		var expected := StitchedFoeIntent.choose(battle, next_actor)
		var hero_result := stage.submit_pass()
		_check(bool(hero_result.get("ok", false)), "public hero Pass spends exactly a hero turn")
		if str(next_actor.get("side", "")) != "foe" or bool(expected.get("pass", true)):
			continue
		var actual: Dictionary = {}
		for i in range(before + 1, stage.receipts.size()):
			var item: Dictionary = stage.receipts[i]
			if str(item.get("actor", "")) == next_id:
				actual = item
				break
		_check(not actual.is_empty() and str(actual.get("action", "")) == "ability"
			and str(actual.get("ability", "")) == str(expected["ability_id"]),
			"unchanged pre-foe ticket matches actual next committed ability ID")
		if not actual.is_empty():
			var targets: Array[int] = []
			for result in actual.get("results", []):
				var target := battle.get_unit(str(result.get("target", "")))
				if not target.is_empty() and not targets.has(int(target["rank"])):
					targets.append(int(target["rank"]))
			targets.sort()
			_check(targets == expected["affected_ranks"]
				and (actual.get("results", []).size() >= 2 if bool(expected["multi"]) else actual.get("results", []).size() == 1),
				"automatic foe receipt resolves exact displayed single/all valid ranks")
		witnessed = true
		break
	_check(witnessed, "non-vacuous: committed a real hero Pass immediately before an ability foe turn")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var mounted := _mount()
	var host: Control = mounted["host"]
	var stage: StitchedBattleScreen = mounted["stage"]
	await process_frame
	var battle := stage.battle
	if battle == null:
		_check(false, "real S2 battle exists")
		host.free()
		_finish()
		return
	_check(host.theme != null and battle.is_valid()
		and battle.get_heroes().size() == 4 and battle.get_foes().size() == 3
		and battle.current_side() == "hero", "seeded 4v3 screen mounted in Gothic theme with a hero turn")
	_check_geometry(stage)
	_verify_tickets(stage)
	_verify_sack_swing_live(stage)
	_verify_kind_fixtures(host)
	_check(not stage._foe_tickets[4].visible, "initial fourth foe rank is empty, not a ghost ability")
	# Real pose changes re-anchor after an ordinary public refresh. Inspection
	# remains read-only even while the painted bounds move within their lanes.
	var idle_puppet: Control = stage._puppets["foe_1"]
	var pose_before: Vector2 = stage._foe_tickets[1].position
	var quiet_pose_state := battle.state_snapshot()
	var quiet_pose_rng := battle.rng_state()
	var quiet_pose_receipts := stage.receipts.duplicate(true)
	idle_puppet.idle_phase += 1.35
	stage._refresh()
	_check(stage._foe_tickets[1].position.distance_to(pose_before) > 0.1,
		"live painted idle pose causes a distinct plaque anchor without a fixed y band")
	_check_geometry(stage)
	_check(battle.state_snapshot() == quiet_pose_state
		and battle.rng_state() == quiet_pose_rng and stage.receipts == quiet_pose_receipts,
		"re-anchoring live posed pixels never spends turns, receipts or RNG")
	# Model the public post-summon board state without advancing combat: all
	# three original foes stay occupied while a distinct live fourth enters.
	var fourth: Dictionary = battle._units[str(battle.get_foes()[2]["id"])].duplicate(true)
	fourth["id"] = "ragling"
	fourth["name"] = "Ragling"
	fourth["rank"] = 4
	battle._units[fourth["id"]] = fourth
	stage._refresh()
	_check_geometry(stage, 4)
	_check(battle.get_foes().size() == 4 and stage._foe_tickets[3].visible
		and stage._foe_tickets[4].visible
		and stage._foe_tickets[4].foe_id == str(fourth["id"])
		and stage._foe_intents[4] == StitchedFoeIntent.choose(battle, battle.get_unit(str(fourth["id"])))
		and _caption_fits(stage._foe_ticket_labels[4])
		and stage._foe_tickets[4].glyph.texture == _kind_texture(
			str(stage._foe_intents[4].get("ability_kind", ""))),
		"post-admission fourth rank receives its own freshly chosen category icon")
	battle._units.erase(fourth["id"])
	stage._refresh()
	_check(battle.get_foes().size() == 3 and not stage._foe_tickets[4].visible
		and not stage._foe_intents.has(4),
		"admitted foe removal clears rank-four intent and disclosure authority")
	# Admission/reposition into the fourth rank is projected and then re-hidden.
	var arriving: Dictionary = battle._units[str(battle.get_foes()[2]["id"])]
	var original_rank := int(arriving["rank"])
	arriving["rank"] = 4
	stage._refresh()
	_check_geometry(stage, 3)
	_check(stage._foe_tickets[4].visible and not stage._foe_tickets[original_rank].visible
		and stage._foe_intents[4] == StitchedFoeIntent.choose(battle, battle.get_unit(str(arriving["id"])))
		and _caption_fits(stage._foe_ticket_labels[4])
		and stage._foe_tickets[4].glyph.texture == _kind_texture(
			str(stage._foe_intents[4].get("ability_kind", "")))
		and stage._foe_tickets[original_rank].glyph.texture == null,
		"fourth-rank arrival reprojects glyph and hides vacated rank's old category")
	arriving["rank"] = original_rank
	stage._refresh()
	_check(not stage._foe_tickets[4].visible and stage._foe_tickets[original_rank].visible
		and stage._foe_tickets[4].glyph.texture == null
		and stage._foe_tickets[4].ability_kind.is_empty(),
		"fourth-rank vacancy never retains a stale image or selected kind")
	var sample: Dictionary = battle.get_foes()[0]
	var sample_id := str(sample["id"])
	var sample_rank := int(sample["rank"])
	var actor: Dictionary = battle._units[sample_id]
	var original_units := battle._units.duplicate(true)
	var original_heaps := battle._heaps.duplicate(true)
	# A genuine live round advance changes the selected kind (melee -> buff)
	# and its image, then restores the round without spending combat turns.
	var opening := StitchedFoeIntent.choose(battle, actor)
	var opening_texture: Texture2D = stage._foe_tickets[sample_rank].glyph.texture
	battle._round += 1
	stage._refresh()
	var rotated := StitchedFoeIntent.choose(battle, actor)
	_check(str(opening.get("ability_id", "")) == str(actor["abilities"][0]["id"])
		and str(rotated.get("ability_id", "")) == str(actor["abilities"][1]["id"])
		and str(rotated.get("ability_kind", "")) == str(actor["abilities"][1]["kind"])
		and stage._foe_tickets[sample_rank].glyph.texture == _kind_texture(str(rotated["ability_kind"]))
		and opening_texture != stage._foe_tickets[sample_rank].glyph.texture
		and opening["base_damage"] == [4, 7] and opening["base_acc"] == 88
		and opening["base_crit"] == 3 and opening["base_effects"] == {"fray": 4}
		and rotated["base_damage"] == [0, 0] and rotated["base_acc"] == 100
		and rotated["base_crit"] == 0 and rotated["base_effects"] == {"riposte": 1},
		"round-rotated live ability changes from melee attack to buff glyph and BASE numbers")
	_verify_base(rotated, actor["abilities"][1], stage._foe_tickets[sample_rank], "real Rag Cloak")
	var rotated_ids: Dictionary = {}
	for foe in battle.get_foes():
		var projected := StitchedFoeIntent.choose(battle, foe)
		rotated_ids[str(projected.get("ability_id", ""))] = true
		if not bool(projected.get("pass", true)):
			var actual: Dictionary = {}
			for ability in foe["abilities"]:
				if ability["id"] == projected["ability_id"]:
					actual = ability
			if not actual.is_empty():
				_verify_base(projected, actual, stage._foe_tickets[int(foe["rank"])], "real rotated " + str(actual["name"]))
	_check(rotated_ids.has("rag_cloak") and rotated_ids.has("thread_snip"),
		"non-vacuous: rotated live roster includes Rag Cloak and Thread Snip")
	battle._round -= 1
	stage._refresh()
	_check(stage._foe_tickets[sample_rank].glyph.texture == opening_texture
		and stage._foe_tickets[sample_rank].secondary.text.begins_with("HERO RANK 1")
		and stage._foe_tickets[sample_rank].tooltip_text.contains("BASE DMG 4–7"),
		"return to earlier legal rotation restores attack glyph, readable target and exact damage disclosure")
	# A genuinely authored long name is kept in the complete disclosure but
	# safely ellipsized in the narrow visual caption; neither view spends a turn.
	var long_name := "A Long Tangle of Moonlit Needles and Unravelling Threads"
	var name_before := str(actor["abilities"][0]["name"])
	var quiet_state := battle.state_snapshot()
	var quiet_rng := battle.rng_state()
	var quiet_receipts := stage.receipts.duplicate(true)
	actor["abilities"][0]["name"] = long_name
	stage._refresh()
	var long_ticket: NinePatchRect = stage._foe_tickets[sample_rank]
	_check(long_ticket.tooltip_text.contains(long_name)
		and stage._foe_ticket_labels[sample_rank].text.ends_with("…")
		and _caption_fits(stage._foe_ticket_labels[sample_rank])
		and _caption_fits(stage._foe_ticket_target_labels[sample_rank]),
		"long authored move is completely disclosed and pixel-fit in its first row")
	long_ticket.mouse_entered.emit()
	_check(stage._intent_disclosure.visible
		and stage._intent_disclosure_label.text.contains(long_name)
		and stage._intent_disclosure_label.text == long_ticket.tooltip_text
		and stage._intent_disclosure_label.get_line_count()
			<= stage._intent_disclosure_label.get_visible_line_count(),
		"wrapped dark hover panel reveals entire long name without clipped lines")
	long_ticket.mouse_exited.emit()
	long_ticket.grab_focus()
	_check(long_ticket.has_focus() and stage._intent_disclosure.visible
		and stage._intent_disclosure_label.text.contains(long_name),
		"keyboard focus retains the complete long authored move and target detail")
	stage._action_buttons["pass"].grab_focus()
	actor["abilities"][0]["name"] = name_before
	stage._refresh()
	_check(quiet_state == battle.state_snapshot() and quiet_rng == battle.rng_state()
		and stage.receipts == quiet_receipts and not stage._intent_disclosure.visible,
		"long-name refresh and disclosure dismissal are read-only")
	var next_ability := StitchedFoeIntent.choose(battle, sample)
	if not bool(next_ability.get("pass", true)):
		next_ability["base_damage"][0] = 999
		next_ability["base_effects"]["fray"] = 999
		_check(StitchedFoeIntent.choose(battle, sample)["base_damage"][0] != 999
			and StitchedFoeIntent.choose(battle, sample)["base_effects"].get("fray", 0) != 999,
			"BASE damage/effects are detached from the current actor and later projections")
		next_ability["affected_ranks"].append(99)
		_check(not StitchedFoeIntent.choose(battle, sample)["affected_ranks"].has(99),
			"helper returns detached affected ranks, not battle state aliases")

	# The accepted hero-target forecast and the foe tickets coexist: inspecting
	# a foe intent never edits STATUS log, selected rank or the part projection.
	var chosen := false
	for slot in StitchedBattleScreen.SLOTS:
		if stage.select_part(slot):
			chosen = true
			break
	_check(chosen, "precondition: real acting hero has a usable sewn part")
	var preview_before := str(stage._labels["preview"].text)
	var log_before := str(stage._labels["log"].text)
	var selection_before := stage._selected_part
	var legal_before := stage.legal_targets()
	var state_before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var order_before := battle.turn_order()
	var receipts_before := stage.receipts.duplicate(true)
	var current_before := battle.current_actor_id()
	var round_before := battle.round_number()
	seed(5122026)
	var expected_global := randi()
	seed(5122026)
	for turn in range(3):
		stage._refresh()
		var ticket: NinePatchRect = stage._foe_tickets[sample_rank]
		ticket.mouse_entered.emit()
		_check(stage._intent_disclosure.visible and
			stage._intent_disclosure_label.text == ticket.tooltip_text and
			ticket.tooltip_text.contains(str(sample["name"])),
			"mouse hover reveals exact full authoritative foe/ability/target/warning")
		ticket.mouse_exited.emit()
		ticket.grab_focus()
		_check(ticket.has_focus() and stage._intent_disclosure.visible
			and stage._intent_disclosure_label.text == ticket.tooltip_text,
			"keyboard focus has the same full non-truncated disclosure as mouse tooltip")
		stage._action_buttons["pass"].grab_focus()
	_check(not stage._intent_disclosure.visible and stage._labels["preview"].text == preview_before
		and stage._labels["log"].text == log_before and stage._selected_part == selection_before
		and stage.legal_targets() == legal_before and stage.receipts == receipts_before,
		"intents leave selected part, target legality, target forecast and seat log untouched")
	var motion_before := stage.reduced_motion
	stage.set_reduced_motion(not motion_before)
	stage._refresh()
	stage.set_reduced_motion(motion_before)
	_check(battle.state_snapshot() == state_before and battle.rng_state() == rng_before
		and stage.receipts == receipts_before and battle.current_actor_id() == current_before,
		"reduced motion switch and repeated ticket refresh remain passive")
	_check(state_before == battle.state_snapshot() and rng_before == battle.rng_state()
		and order_before == battle.turn_order() and current_before == battle.current_actor_id()
		and round_before == battle.round_number() and randi() == expected_global,
		"refresh, hover and focus spend no local/global RNG, turn, action or combat state")

	# Rank/target changes reproject against the live legality authority.
	var hero_one: Dictionary = battle._units[str(battle.get_heroes()[0]["id"])]
	hero_one["lost"] = true
	stage._refresh()
	_check(int(stage._foe_intents[sample_rank]["target_rank"]) == 2
		and stage._foe_tickets[sample_rank].tooltip_text.contains("rank 2")
		and stage._foe_tickets[sample_rank].secondary.text.begins_with("HERO RANK 2"),
		"lost front hero makes first legal target rank 2, never a phantom rank 1")
	hero_one["lost"] = false
	# Original first ability is disabled: fall through to authored next ability.
	actor["abilities"][0]["launch_mask"] = 1 << 4
	stage._refresh()
	_check(str(stage._foe_intents[sample_rank]["ability_id"]) == str(actor["abilities"][1]["id"])
		and not bool(stage._foe_intents[sample_rank]["pass"])
		and str(stage._foe_intents[sample_rank]["ability_kind"]) == str(actor["abilities"][1]["kind"])
		and stage._foe_tickets[sample_rank].glyph.texture == _kind_texture(
			str(actor["abilities"][1]["kind"]))
		and stage._foe_tickets[sample_rank].glyph.texture != opening_texture
		and stage._foe_tickets[sample_rank].secondary.text.find("BASE") == -1
		and stage._foe_tickets[sample_rank].tooltip_text.contains("BASE DMG 0–0"),
		"blocked first ability falls back to next legal buff with zero-direct-damage readout")
	actor["abilities"][1]["launch_mask"] = 1 << 4
	stage._refresh()
	_check(bool(stage._foe_intents[sample_rank]["pass"])
		and stage._foe_tickets[sample_rank].get_node("IntentText").text == "PASS"
		and stage._foe_tickets[sample_rank].primary.get_theme_font_size("font_size") == 24
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("Target:")
		and str(stage._foe_intents[sample_rank]["ability_kind"]) == ""
		and stage._foe_tickets[sample_rank].glyph.texture == null
		and not stage._foe_tickets[sample_rank].glyph.visible
		and int(stage._foe_intents[sample_rank]["target_rank"]) == 0
		and not stage._foe_intents[sample_rank].has("base_damage")
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("BASE"),
		"all abilities blocked produces PASS without BASE threat, glyph, kind or illegal target")
	actor["abilities"] = original_units[sample_id]["abilities"].duplicate(true)
	actor["statuses"]["stun"] = 1
	stage._refresh()
	_check(bool(stage._foe_intents[sample_rank]["stun"])
		and stage._foe_tickets[sample_rank].get_node("IntentText").text == "STUN"
		and stage._foe_tickets[sample_rank].primary.get_theme_font_size("font_size") == 24
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("Target:")
		and str(stage._foe_intents[sample_rank]["ability_kind"]) == ""
		and stage._foe_tickets[sample_rank].glyph.texture == null
		and not stage._foe_tickets[sample_rank].glyph.visible
		and int(stage._foe_intents[sample_rank]["target_rank"]) == 0
		and not stage._foe_intents[sample_rank].has("base_damage")
		and not stage._foe_tickets[sample_rank].tooltip_text.contains("BASE"),
		"next-turn stun skip has no BASE damage, effect, glyph or legal target")
	actor["statuses"].erase("stun")
	# Reposition an existing foe and change its identity display name.
	var swap: Dictionary = battle._units[str(battle.get_foes()[2]["id"])]
	var other_rank := int(swap["rank"])
	swap["rank"] = sample_rank
	actor["rank"] = other_rank
	actor["name"] = "Repaired Foe"
	stage._refresh()
	_check(stage._foe_tickets[other_rank].visible
		and stage._foe_tickets[other_rank].tooltip_text.contains("Repaired Foe")
		and stage._foe_intents[other_rank]["foe_id"] == sample_id,
		"rank swap rebinds to new public name and position without stale labels")
	battle._round += 1
	stage._refresh()
	_verify_tickets(stage)
	_check(stage._foe_intents[other_rank] == StitchedFoeIntent.choose(battle, battle.get_unit(sample_id)),
		"round rotation recalculates from authored next ability, not a stored preview")
	battle._units = original_units.duplicate(true)
	battle._heaps = original_heaps.duplicate(true)
	stage._refresh()

	# Death and heap replacement hide tickets instead of targeting scrap.
	battle._units[sample_id]["dead"] = true
	battle._units[sample_id]["hp"] = 0
	battle._heaps.append({"id": "heap:test", "side": "heap", "rank": sample_rank,
		"hp": 5, "max_hp": 5, "foe_id": sample_id})
	stage._refresh()
	_check(not stage._foe_tickets[sample_rank].visible
		and StitchedFoeIntent.choose(battle, battle.get_unit(sample_id)).is_empty(),
		"dead foe replaced with scrap heap has no ticket or selectable intent")
	battle._units = original_units.duplicate(true)
	battle._heaps = original_heaps.duplicate(true)
	stage._refresh()
	battle._units[sample_id]["lost"] = true
	stage._refresh()
	_check(not stage._foe_tickets[sample_rank].visible and not stage._foe_intents.has(sample_rank)
		and stage._foe_tickets[sample_rank].foe_id.is_empty()
		and stage._foe_tickets[sample_rank].glyph.texture == null
		and stage._foe_tickets[sample_rank].ability_kind.is_empty(),
		"LOST foe leaves neither visible ticket, image nor stale identity")
	battle._units = original_units.duplicate(true)
	stage._refresh()
	_verify_receipt(stage)
	host.free()

	# Valid authored multi-target S2 variant, not a fake battle catalog.
	var multi_config: Dictionary = StitchedBattleScreen.read_preview().duplicate(true)
	for foe in multi_config["foes"]:
		for ability in foe["abilities"]:
			if str(ability["target_side"]) == "enemy":
				ability["multi"] = true
			elif str(ability["id"]) == "rag_cloak":
				ability["target_side"] = "ally"
				ability["multi"] = true
	var multi_mount := _mount(multi_config)
	var multi_host: Control = multi_mount["host"]
	var multi_stage: StitchedBattleScreen = multi_mount["stage"]
	await process_frame
	_verify_tickets(multi_stage)
	var multi_witness := 0
	for foe in multi_stage.battle.get_foes():
		var intent := StitchedFoeIntent.choose(multi_stage.battle, foe)
		if bool(intent.get("multi", false)):
			multi_witness += 1
			_check(intent["affected_ranks"].size() >= 2
				and multi_stage._foe_tickets[int(foe["rank"])].tooltip_text.contains("ALL legal HERO ranks")
				and multi_stage._foe_ticket_target_labels[int(foe["rank"])].text.begins_with("HERO RANKS ")
				and not multi_stage._foe_ticket_target_labels[int(foe["rank"])].text.contains("…")
				and _caption_fits(multi_stage._foe_ticket_target_labels[int(foe["rank"])]),
				"authored multi ability displays all living legal HERO ranks")
	_check(multi_witness >= 2, "non-vacuous: two or more seeded foes have real multi-target abilities")
	_verify_receipt(multi_stage)
	multi_stage.battle._round = 2
	multi_stage._refresh()
	_verify_tickets(multi_stage)
	var ally_intent: Dictionary = multi_stage._foe_intents[1]
	_check(ally_intent["ability_id"] == "rag_cloak" and ally_intent["target_side"] == "foe"
		and ally_intent["multi"] and ally_intent["affected_ranks"] == [1, 2]
		and multi_stage._foe_tickets[1].secondary.text == "FOE RANKS 1,2"
		and multi_stage._foe_tickets[1].tooltip_text.contains("ALL legal FOE ranks 1, 2")
		and multi_stage._foe_tickets[1].tooltip_text.contains("BASE DMG 0–0"),
		"mounted legal multi-foe buff names exact allied ranks without a fictitious attack")
	multi_host.free()
	_test_pull_fixture()
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_foe_intent_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
