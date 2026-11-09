extends SceneTree
## Owner 11-09: every hero and enemy ability shows its own pose picture, never one it shares.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _kit_poses(side: String, actor: String, ids: Array) -> void:
	var seen := {}
	for ability_id in ids:
		var path := StitchedBattleScreen.ability_pose_path(side, actor, str(ability_id))
		_check(not path.is_empty(), "%s %s has its own pose picture" % [actor, ability_id])
		_check(not seen.has(path), "%s %s does not share %s's pose" % [actor, ability_id, seen.get(path, "")])
		seen[path] = ability_id


## In a corridor fight the round icons carry no words; the move name comes up on hover, and a
## used ability shows its own pose.
func _fight_checks() -> void:
	root.size = Vector2i(1280, 720)
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(StitchedBattleScreen.read_preview()), "precondition: preview battle starts")
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	await process_frame
	var named := 0
	for slot in fight.part_buttons:
		var button: TextureButton = fight.part_buttons[slot]
		var move_label: Label = button.get_node("Move")
		_check(not move_label.is_visible_in_tree(), slot + " shows no move name under its icon")
		if not move_label.text.is_empty():
			named += 1
			_check(button.tooltip_text.begins_with(move_label.text), slot + " hover starts with its move name: " + button.tooltip_text)
	_check(named > 0, "the acting doll's moves are named on hover")
	var posed := 0
	for unit in screen.battle.get_heroes() + screen.battle.get_foes():
		var ability_ids: Array = []
		for ability in unit.get("abilities", []):
			ability_ids.append(str(ability.id))
		for worn in unit.get("parts", {}).values():
			ability_ids.append(str(StitchedParts.ability_at_tier(screen.parts.get(str(worn.id), {}), int(worn.get("tier", 1))).get("id", "")))
		for ability_id in ability_ids:
			var own := StitchedBattleScreen.ability_pose_path(str(unit.side), str(unit.id), ability_id)
			if not own.is_empty():
				posed += 1
				var shown := fight._receipt_pose_texture(str(unit.id), ability_id)
				_check(shown != null and shown.resource_path == own, "%s %s shows its own pose in the corridor" % [unit.id, ability_id])
	_check(posed > 0, "the preview fight uses abilities with their own poses")

	# Who did what stays off the screen; the move name flashes up only while it is used.
	var foe: Dictionary = screen.battle.get_foes()[0]
	var move_name := str(foe.abilities[0].name)
	screen._notice = "%s · Ability\n%s\n→ Warden: 9 damage\nWren hugs his dolls close.\nRound 1 · Ongoing" % [foe.name, move_name]
	fight.refresh()
	_check(not fight.log_label.text.contains(move_name) and not fight.log_label.text.contains("damage")
		and fight.log_label.text.contains("Wren hugs"), "only Wren's words stay on the fight line: " + fight.log_label.text)
	_check(not fight.move_banner.visible, "no move name shows at rest")
	fight._show_move_name(move_name)
	_check(fight.move_banner.visible and fight.move_banner.text == move_name, "the move name shows while it is used")
	fight._cancel_beats()
	_check(not fight.move_banner.visible, "the move name goes when the move ends")
	# Hovering a unit lists its moveset.
	for key in fight.hits:
		if not fight.hits[key].visible:
			continue
		var unit: Dictionary = screen._unit_at(key.get_slice("_", 0), int(key.get_slice("_", 1)))
		var tip: String = fight.hits[key].tooltip_text
		_check(tip.contains("Moves: "), key + " hover lists its moveset: " + tip)
		for ability in unit.get("abilities", []):
			_check(tip.contains(str(ability.name)), "%s hover names %s" % [key, ability.name])
	# Owner 11-09: a thrown thing leaves the hand as its own picture and the hit effect bursts on the target.
	var bomb := StitchedBattleScreen.ability_fx("tinker_arms_scrap_bomb")
	_check(bomb.has("object") and bomb.has("fx"), "the scrap bomb has its own thrown picture and hit effect: " + str(bomb))
	var hero: Dictionary = screen.battle.get_heroes()[0]
	var target: Dictionary = screen.battle.get_foes()[0]
	fight._throw_and_strike({"actor": hero.id, "ability": "tinker_arms_scrap_bomb", "results": [{"target": target.id, "hit": true}]})
	_check(fight._flying.size() == 2, "the bomb flies and its blast waits at the target: %d pictures" % fight._flying.size())
	var shown := fight._flying.map(func(sprite): return sprite.texture.resource_path)
	_check(bomb.get("object") in shown and bomb.get("fx") in shown, "the flying pictures are the bomb and its blast: " + str(shown))
	_check(fight._flying.all(func(sprite): return sprite.is_inside_tree() and not sprite.flip_h), "a hero's throw flies right, unflipped")
	fight._throw_and_strike({"actor": target.id, "ability": "lint_spit", "results": [{"target": hero.id, "hit": true}]})
	_check(fight._flying.size() == 4 and fight._flying[2].flip_h, "a foe's spit flies the other way")
	fight._cancel_beats()
	_check(fight._flying.is_empty(), "cutting a beat short clears everything in flight")
	fight._throw_and_strike({"actor": hero.id, "ability": "tinker_arms_scrap_bomb", "results": [{"target": target.id, "hit": false}]})
	_check(fight._flying.size() == 1, "a miss throws the bomb but shows no blast")
	fight._cancel_beats()
	screen.queue_free()
	await process_frame


func _run() -> void:
	var heroes := {}
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StitchedS14Abilities.HERO_PATH))
	for ability in document.abilities:
		heroes.get_or_add(str(ability.hero), []).append(ability.id)
	_check(heroes.size() == 8, "all eight heroes have kits")
	for hero in heroes:
		_kit_poses("hero", hero, heroes[hero])

	var catalog := StitchedEnemyCatalog.load_catalog()
	_check(bool(catalog.get("ok", false)), "the enemy catalog loads")
	var foes: Dictionary = catalog.get("foes", {})
	_check(foes.size() >= 37, "every foe is checked")
	for foe_id in foes:
		var ids: Array = []
		for ability in StitchedEnemyCatalog.foe_for(catalog, foe_id).abilities:
			ids.append(ability.id)
		if catalog.get("phase_two", {}).has(foe_id):
			for ability in StitchedEnemyCatalog.foe_for(catalog, foe_id, StitchedEnemyCatalog.PHASE_TWO).abilities:
				ids.append(ability.id)
		_kit_poses("foe", foe_id, ids)

	# Every thrown picture and hit effect the manifest names loads.
	var fx_doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(StitchedBattleScreen.ABILITY_FX_PATH))
	_check(fx_doc.get("abilities", {}).size() >= 100, "most abilities show a hit effect")
	for ability_id in fx_doc.get("abilities", {}):
		var art := StitchedBattleScreen.ability_fx(str(ability_id))
		_check(art.size() == fx_doc.abilities[ability_id].size(), "%s's thrown picture and hit effect load: %s" % [ability_id, art])

	await _fight_checks()

	# An ability with no picture of its own still shows its move pose.
	_check(StitchedBattleScreen.ability_pose_path("hero", "warden", "not_an_ability").is_empty(), "an unknown ability has no own pose")

	print("stitched_ability_poses_test: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for failure in failures:
		print("FAIL: ", failure)
	quit(0 if failures.is_empty() else 1)
