extends SceneTree
## Job 6: data-driven reactions are a presentation of receipts, not a rules roll.
var failures: Array[String] = []
var checks := 0


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "preview battle starts")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	_check(fight != null, "corridor fight mounts")
	await process_frame
	if fight == null:
		quit(1)
		return
	var hero: Dictionary = fight.battle.get_heroes()[0]
	var foe: Dictionary = fight.battle.get_foes()[0]
	var foe_key := "foe_%d" % int(foe.rank)
	var hero_key := "hero_%d" % int(hero.rank)
	var baseline := fight.battle.state_snapshot()
	var rng := fight.battle.rng_state()
	var receipts := screen.receipts.duplicate(true)
	var attack := {"actor": str(hero.id), "ability": "tinker_arms_scrap_bomb"}
	var normal := {"target": str(foe.id), "target_side": "foe", "hit": true,
		"crit": false, "damage": 3, "target_hp": 9, "statuses": []}
	var dodge := normal.duplicate(true)
	dodge.hit = false
	_check(fight._receipt_reaction_kind(attack, dodge) == "dodge", "a real miss demands dodge")
	var heavy := normal.duplicate(true)
	heavy.crit = true
	_check(fight._receipt_reaction_kind(attack, heavy) == "heavy", "a critical blow demands heavy")
	heavy.crit = false
	heavy.damage = 12
	_check(fight._receipt_reaction_kind(attack, heavy) == "heavy", "a forceful blow demands heavy")
	heavy.damage = 3
	heavy.target_hp = 0
	_check(fight._receipt_reaction_kind(attack, heavy) == "heavy", "a finishing hit demands heavy")
	var stunned := normal.duplicate(true)
	stunned.statuses = [{"status": "stun", "duration": 1}]
	_check(fight._receipt_reaction_kind(attack, stunned) == "stun", "applied stun leaves target slumped")
	stunned.statuses = [{"status": "stun", "refused": true}]
	_check(fight._receipt_reaction_kind(attack, stunned) == "heavy",
		"the bomb's heavy authored reaction remains when stun is refused")
	var bleeding := normal.duplicate(true)
	bleeding.statuses = [{"status": "bleed", "duration": 2}]
	_check(fight._receipt_reaction_kind(attack, bleeding) == "shudder", "bleed makes a target shudder")
	bleeding.statuses = [{"status": "rot", "duration": 2}]
	_check(fight._receipt_reaction_kind(attack, bleeding) == "shudder", "rot makes a target shudder")
	var healing := {"target": str(hero.id), "target_side": "hero", "hit": true,
		"damage": 0, "statuses": [{"status": "heal", "amount": 4}]}
	_check(fight._receipt_reaction_kind(attack, healing) == "brace", "helped ally braces")
	var ordinary := attack.duplicate(true)
	ordinary.ability = "seamstress_arms_needle_prick"
	_check(fight._receipt_reaction_kind(ordinary, normal) == "hit", "ordinary cut jerks back")
	_check(StitchedBattleScreen.ability_reaction("tinker_arms_scrap_bomb") == "heavy"
		and StitchedBattleScreen.ability_reaction("lantern_monk_torso_lamplight_wash") == "brace"
		and StitchedBattleScreen.ability_reaction("ink_flick") == "shudder",
		"authored ability metadata names impact, help and status reactions")
	var picture: Sprite3D = fight.stage.figure_nodes[foe_key]
	var idle: Texture2D = picture.get_meta("still")
	var receipt := attack.duplicate(true)
	receipt.results = [dodge]
	fight._apply_target_reactions(receipt)
	_check(fight._reaction_kinds.get(foe_key, "") == "dodge"
		and fight._miss_labels.has(foe_key) and fight._miss_labels[foe_key].visible
		and fight._miss_labels[foe_key].text == "MISS", "dodge shows MISS over the right figure")
	_check(fight._beat_input_shield.get_index() == fight.get_child_count() - 1,
		"MISS never steals the invisible input shield's topmost place")
	fight._clear_target_reactions()
	_check(picture.texture == idle and not fight._miss_labels[foe_key].visible
		and fight._reaction_kinds.is_empty(), "cleanup restores idle and hides MISS")
	receipt.results = [heavy]
	fight._apply_target_reactions(receipt)
	_check(fight._reaction_kinds.get(foe_key, "") == "heavy"
		and picture.texture != null and not fight._miss_labels[foe_key].visible,
		"critical or kill has a picture or standing fallback with no false MISS")
	fight._clear_target_reactions()
	receipt.results = [normal]
	fight._apply_target_reactions(receipt)
	_check(fight._reaction_kinds.get(foe_key, "") == "heavy",
		"ability-specific heavy reaction overrides ordinary damage")
	fight._clear_target_reactions()
	_check(fight.stage.figure_nodes[hero_key].texture != null, "the acting hero retains its picture")
	# A hovered foe's details must follow combat HP instead of freezing at entry.
	fight._hover(foe_key, true)
	var actual: Dictionary = fight.battle._units[str(foe.id)].duplicate(true)
	fight.battle._units[str(foe.id)]["hp"] = int(actual.hp) - 2
	fight.refresh()
	_check(fight.corner_map.foe_body.text.contains("Health %d / %d" % [int(actual.hp) - 2, int(actual.max_hp)]),
		"corner updates hovered foe HP after the rules change")
	fight.battle._units[str(foe.id)]["dead"] = true
	fight.refresh()
	_check(not fight.corner_map._foe_mode, "a defeated foe clears its stale hover card")
	fight.battle._units[str(foe.id)] = actual
	fight.refresh()
	fight._hover(foe_key, false)
	_check(fight.battle.state_snapshot() == baseline and fight.battle.rng_state() == rng
		and screen.receipts == receipts, "reacting and restoring consume no rules/RNG/receipts")
	screen.free()
	for fail in failures:
		printerr(fail)
	print("stitched_s11_reaction_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _initialize() -> void:
	_run.call_deferred()
