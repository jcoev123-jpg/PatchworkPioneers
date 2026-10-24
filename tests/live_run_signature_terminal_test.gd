extends SceneTree
## The real App-owned terminal panel reads committed source ledgers, not mocks.
const APP_SCENE := "res://scenes/app.tscn"
const PANEL_SCENE := "res://scenes/run_terminal_result_panel.tscn"
const PARTY := "res://data/heroes/starter_party.json"
const FIGHT := "res://data/enemies/starter_enemies.json"
const BOSS := "res://data/enemies/boss.json"

var failures: Array[String] = []
var checks := 0
var returns := 0
var app: Variant
var panel: LiveRunTerminalResultPanel
var heroes: Array = []
var deck: Array[String] = []
var descriptors: Dictionary = {}
var cursor := 1
var wardrobe: RunPatchWardrobe


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)


func _defs(path: String) -> Array:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(data is Array and not data.is_empty(), "authored combat fixture exists: " + path)
	var records: Array = []
	if not data is Array:
		return records
	for entry in data:
		if not entry is Dictionary:
			continue
		var copy: Dictionary = entry.duplicate(true)
		copy["max_hp"] = int(copy.get("max_hp", 0))
		records.append(copy)
	return records


func _battle(path: String) -> Dictionary:
	var party := CombatParty.new(_defs(PARTY))
	var enemies := CombatEnemies.new(_defs(path))
	_check(party.is_valid() and enemies.is_valid() and not party.is_defeated()
		and not enemies.is_victorious(), "real battle actors start alive")
	var result := CombatBattleResult.new(party, enemies)
	_check(result.get_outcome() == CombatBattleResult.ACTIVE, "real battle starts active")
	return {"party": party, "enemies": enemies, "result": result}


func _path(map: RunMap, node: String) -> Array[String]:
	var info := map.get_node(node)
	if info.is_empty():
		return []
	if info.get("floor") == RunMap.FLOOR_COUNT:
		if info.get("type") == "Boss":
			return [node]
		return []
	for next_node in info.get("outgoing", []):
		var rest: Array[String] = _path(map, next_node)
		if not rest.is_empty():
			rest.push_front(node)
			return rest
	return []


func _context(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var map := RunMap.new()
	_check(map.generate(rng), "seeded real RunMap generated")
	return {"rng": rng, "map": map, "latch": RunActBattleOutcome.new(map)}


func _settle(ctx: Dictionary, fight: Dictionary, victory: bool) -> void:
	var latch: RunActBattleOutcome = ctx.latch
	_check(latch.begin_current_battle(fight.result), "actual selected fight begins")
	if victory:
		var enemies: CombatEnemies = fight.enemies
		for i in range(1, enemies.get_enemies().size() + 1):
			var hp: int = enemies.get_enemy(i).get("hp", 0)
			_check(hp > 0 and enemies.apply_damage(i, hp), "real enemy takes lethal damage")
		_check(enemies.is_victorious() and fight.result.evaluate() == CombatBattleResult.VICTORY,
			"CombatBattleResult witnesses victory")
	else:
		var party: CombatParty = fight.party
		for i in range(1, 4):
			var hp: int = party.get_hero(i).get("hp", 0)
			_check(hp > 0 and party.apply_damage(i, hp), "actual party member downed")
		_check(party.is_defeated() and fight.result.evaluate() == CombatBattleResult.DEFEAT,
			"CombatBattleResult witnesses defeat")
	_check(latch.settle_current_battle(), "witnessed battle settles in RunActBattleOutcome")


func _victory() -> Dictionary:
	var ctx := _context(5801)
	var map: RunMap = ctx.map
	var path: Array[String] = []
	for candidate in map.get_legal_choices():
		path = _path(map, candidate)
		if not path.is_empty():
			break
	_check(path.size() == RunMap.FLOOR_COUNT, "real connected Boss route selected")
	for id in path:
		_check(map.get_legal_choices().has(id) and map.choose_node(id), "legal routed node chosen")
		var kind: String = map.get_node(id).get("type")
		if kind in ["Fight", "Elite"]:
			_settle(ctx, _battle(FIGHT), true)
		elif kind == "Boss":
			_settle(ctx, _battle(BOSS), true)
	_check(map.is_complete() and ctx.latch.get_state().run_status == RunActBattleOutcome.VICTORY,
		"genuinely settled floor-12 Boss victory")
	return ctx


func _defeat() -> Dictionary:
	var ctx := _context(8722)
	var map: RunMap = ctx.map
	var opening := ""
	for id in map.get_legal_choices():
		if map.get_node(id).get("type") == "Fight":
			opening = id
			break
	_check(not opening.is_empty(), "seeded opening Fight available")
	if opening.is_empty():
		return ctx
	_check(map.choose_node(opening), "real Fight route selected")
	_settle(ctx, _battle(FIGHT), false)
	_check(ctx.latch.get_state().run_status == RunActBattleOutcome.DEFEAT,
		"genuine settled party defeat")
	return ctx


func _source(ctx: Dictionary) -> Dictionary:
	var out := {
		"deck": app.run_deck.duplicate(),
		"descriptors": app.run_stitch_descriptors.duplicate(true),
		"cursor": app.run_next_stitch_id,
		"heroes": app.run_heroes.duplicate(true),
		"trinkets": app.run_trinkets.duplicate(),
		"scraps": app.run_scraps,
		"gold": app.session_gold,
		"carryover": app.party_carryover.read_state(),
		"wardrobe": wardrobe.get_snapshot() if wardrobe != null else {},
		"map": ctx.map.get_floors(),
		"route": ctx.map.get_route(),
		"latch": ctx.latch.get_state(),
		"rng": ctx.rng.state,
	}
	return out


func _show(ctx: Dictionary, title: String, expected: Dictionary) -> void:
	var before := _source(ctx)
	_check(panel.get_parent() == app and app.get_script() == load("res://scripts/app.gd"),
		"presented panel has actual App script as parent")
	_check(ctx.latch.get_state().pending_node_id == ""
		and not ctx.latch.get_state().settled_node_ids.is_empty(),
		"terminal latch is witnessed and settled before opening")
	_check(panel.open_result(ctx.latch), title + " opens actual mounted view")
	_check(panel.title_label.text == title
		and panel.description_label.text == ("The final boss has fallen. The run is complete."
			if title == "Victory" else "The party has fallen. The run has ended."),
		"existing terminal title and sentence remain unchanged")
	_check(panel.return_button.text == "Return to Title" and not panel.return_button.disabled
		and panel.return_button.is_visible_in_tree(), "Return is still enabled and visible")
	_check(expected.get("ok") == true, "independent summary oracle validates staged ledger")
	if expected.get("ok") == true:
		var value: String = panel.summary_label.text
		_check(value.contains("Stitched: %d made · %d in deck" %
			[expected.stitched_created, expected.stitched_current]),
			"mounted counts match historical and current oracle")
		_check(value.contains("Patches worn: %d" % expected.worn_total),
			"mounted worn total matches oracle, not inventory size")
		var rows: PackedStringArray = value.split("\n")
		# Independent oracle line list: two counts, one optional craft recap of
		# the first two current stitched names, then the three hero rows.
		var expected_rows: Array[String] = [
			"Stitched: %d made · %d in deck" % [expected.stitched_created, expected.stitched_current],
			"Patches worn: %d" % expected.worn_total,
		]
		var stitched_ids: Array = expected.stitched_ids
		if not stitched_ids.is_empty():
			var names: Array[String] = []
			for index in range(mini(stitched_ids.size(), 2)):
				names.append(expected.descriptors[stitched_ids[index]].display_name)
			var craft := "Crafted: " + "  ·  ".join(names)
			if stitched_ids.size() > names.size():
				craft += " +%d more" % (stitched_ids.size() - names.size())
			expected_rows.append(craft)
		for i in range(3):
			var hero: Dictionary = expected.heroes[i]
			var parts: Array[String] = []
			for slot in ["HEAD", "ARM", "COAT"]:
				var id: String = hero.slots[slot]
				parts.append("%s %s" % [slot, id.capitalize() if not id.is_empty() else "-"])
			var hp: int = 40 if hero.hero_id == "warden" else (30 if hero.hero_id == "seamstress" else 26)
			expected_rows.append("%s %d/%d HP · %s" % [
				str(hero.hero_id).capitalize(), hp, hp, " · ".join(parts)])
		_check(rows.size() == expected_rows.size() + 1 and rows[0].begins_with("Battles resolved:"),
			"mounted signature has battles resolved count, two counts, one craft line per nonempty deck and three hero lines")
		if rows.size() == expected_rows.size() + 1 and rows[0].begins_with("Battles resolved:"):
			for i in range(expected_rows.size()):
				_check(rows[i + 1] == expected_rows[i],
					"actual signature line %d matches the independent oracle" % (i + 1))
	var cards: Array = expected.get("current_stitched_cards", [])
	_check(panel.stitched_section.visible == not cards.is_empty(),
		"detail section exists only for genuinely retained sewn cards")
	_check(panel.stitched_rows.get_child_count() == cards.size(),
		"every retained descriptor, not only two recap names, has one detail row")
	for i in range(cards.size()):
		var card: Dictionary = cards[i]
		var first: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[0])
		var second: Dictionary = RunRestStitchCards.resolve_card_definition(card.half_ids[1])
		_check(not first.is_empty() and not second.is_empty()
			and card.owners == [first.owner, second.owner]
			and first.owner != second.owner,
			"canonical retained halves have different, ordered hero owners")
		_check(card.cost == mini(3, maxi(first.cost, second.cost) + 1),
			"retained descriptor cost matches authored half costs")
		var row := panel.stitched_rows.get_child(i)
		var composite := row.get_node("CardInset/CardLines/Composite") as Label
		var halves := row.get_node("CardInset/CardLines/Halves") as Label
		_check(composite.text == "%s  ·  %d energy" % [card.display_name, card.cost],
			"mounted row shows exact composite name and energy cost in deck order")
		_check(halves.text == "1 · %s (%s)    →    2 · %s (%s)" % [
			first.display_name, str(first.owner).capitalize(),
			second.display_name, str(second.owner).capitalize()],
			"mounted row prints actual authored half names and matching owner order")
	panel.stitched_scroll.scroll_vertical = 9999
	_check(_source(ctx) == before, "opening and scrolling cannot change source, map, receipt or RNG")


func _stage() -> void:
	var party := CombatParty.new(_defs(PARTY))
	_check(party.is_valid(), "authored three-hero party")
	heroes = party.get_heroes()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	_check(raw is Array and raw.has("warden_strike")
		and raw.has("seamstress_prick") and raw.has("seamstress_mend")
		and raw.has("tinker_pop_shot"), "starter deck has all different-owner stitch halves")
	deck.assign(raw)
	var first := RunRestStitchCards.new(deck, {}, 6, 1)
	_check(first.is_valid(), "first Rest stitch ledger validates")
	var made: Dictionary = first.choose_stitch(deck.find("warden_strike"),
		deck.find("seamstress_prick"), first.get_snapshot())
	_check(made.get("ok") == true and made.get("remaining_scraps") == 3,
		"actual Rest stitch spends 3 scraps")
	_check(made.get("descriptor", {}).get("cost") == mini(3,
		maxi(StarterCards.new().get_definition("warden_strike").cost,
		StarterCards.new().get_definition("seamstress_prick").cost) + 1),
		"stitched card keeps exact capped half-cost rule")
	deck.assign(made.deck)
	descriptors = made.descriptors.duplicate(true)
	var second := RunRestStitchCards.new(deck, descriptors, 3, made.next_stitch_id)
	var made_again: Dictionary = second.choose_stitch(deck.find("seamstress_mend"),
		deck.find("tinker_pop_shot"), second.get_snapshot())
	_check(made_again.get("ok") == true and made_again.get("remaining_scraps") == 0,
		"second authentic different-owner stitch consumes its Rest choice")
	deck.assign(made_again.deck)
	descriptors = made_again.descriptors.duplicate(true)
	cursor = made_again.next_stitch_id
	_check(cursor == 3 and descriptors.size() == 2, "two distinct stitched cards persist")
	wardrobe = RunPatchWardrobe.new(heroes, ["button_eye", "stitched_badge",
		"pincushion_arm", "spare_spool", "quilted_coat"], [
		{"id": "button_eye", "slot": "HEAD"}, {"id": "stitched_badge", "slot": "HEAD"},
		{"id": "pincushion_arm", "slot": "ARM"}, {"id": "spare_spool", "slot": "ARM"},
		{"id": "quilted_coat", "slot": "COAT"}], 3, 100, deck, 5801)
	_check(wardrobe.is_valid(), "worn-patch wardrobe has authentic run context")
	for entry in [["button_eye", "warden", "HEAD"], ["pincushion_arm", "seamstress", "ARM"],
			["quilted_coat", "tinker", "COAT"]]:
		var sewn: Dictionary = wardrobe.sew(entry[0], entry[1], entry[2],
			"sew_" + entry[0], wardrobe.get_snapshot())
		_check(sewn.get("ok") == true, "sew actually commits worn patch " + entry[0])
	var carry := RunTornCarryover.new(heroes)
	_check(carry.is_valid(), "authentic RunTornCarryover valid")
	_check(carry.bind_wardrobe(wardrobe, carry.torn, wardrobe.get_snapshot()),
		"wardrobe bound by real carryover receipt")
	app.party_carryover = carry
	_publish()


func _publish() -> void:
	app.run_deck.assign(deck)
	app.run_stitch_descriptors = descriptors.duplicate(true)
	app.run_next_stitch_id = cursor
	app.run_heroes = heroes.duplicate(true)
	var snap: Dictionary = wardrobe.get_snapshot() if wardrobe != null else {}
	app.run_trinkets.assign(snap.get("owned", []))
	app.run_scraps = snap.get("scraps", 0)
	app.session_gold = snap.get("gold", 0)


func _remove_and_resew() -> void:
	var removed: Dictionary = RunShopCardRemoval.try_remove_with_stitch_ledger(
		deck, descriptors, cursor, 100, 0, "stitched_000001")
	_check(removed.get("ok") == true and removed.get("next_stitch_id") == 3
		and removed.get("gold") == 25, "authentic Shop retires composite, keeps historical cursor")
	deck.assign(removed.deck)
	descriptors = removed.descriptors.duplicate(true)
	_check(descriptors.size() == 1 and not deck.has("stitched_000001")
		and deck.has("stitched_000002"), "only surviving stitched card remains")
	_check(wardrobe.refresh_run_context(heroes, wardrobe.get_snapshot().owned,
		wardrobe.get_snapshot().scraps, removed.gold, deck, wardrobe.get_snapshot()),
		"wardrobe context refreshed after legitimate Shop removal")
	_check(wardrobe.start_rest("rest_resew", wardrobe.get_snapshot()).ok,
		"real Rest entered for re-sew")
	_check(wardrobe.re_sew("button_eye", "warden", "seamstress", "rest_resew",
		"resew_button", wardrobe.get_snapshot()).ok, "paid re-sew moves HEAD wearer")
	_check(wardrobe.end_rest("rest_resew", wardrobe.get_snapshot()).ok,
		"real Rest closed")
	var replaced: Dictionary = wardrobe.sew("stitched_badge", "seamstress",
		"HEAD", "replace_head", wardrobe.get_snapshot())
	_check(replaced.get("ok") == true and replaced.get("receipt", {}).get("displaced_id") == "button_eye",
		"sewing replacement displaces former patch")
	_check(not wardrobe.get_snapshot().owned.has("button_eye")
		and wardrobe.get_snapshot().owned.has("spare_spool"),
		"displaced removed from owned; unused owned patch remains")
	_publish()


func _stitch_again() -> void:
	var stitch := RunRestStitchCards.new(deck, descriptors, 3, cursor)
	_check(stitch.is_valid(), "post-Shop genuine Rest ledger validates")
	var receipt: Dictionary = stitch.choose_stitch(deck.find("warden_brace"),
		deck.find("tinker_scrap_bomb"), stitch.get_snapshot())
	_check(receipt.get("ok") == true and receipt.get("next_stitch_id") == 4,
		"fresh genuine Rest stitches two surviving different-owner halves")
	if receipt.get("ok") != true:
		return
	deck.assign(receipt.deck)
	descriptors = receipt.descriptors.duplicate(true)
	cursor = receipt.next_stitch_id
	var prior: Dictionary = wardrobe.get_snapshot()
	_check(wardrobe.refresh_run_context(heroes, prior.owned, prior.scraps,
		prior.gold, deck, prior), "wardrobe follows new authoritative stitched deck")
	_publish()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load(APP_SCENE) as PackedScene
	var terminal := load(PANEL_SCENE) as PackedScene
	_check(scene != null and terminal != null, "actual App and terminal scenes load")
	if scene == null or terminal == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	panel = terminal.instantiate() as LiveRunTerminalResultPanel
	app.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.return_to_title_requested.connect(func() -> void: returns += 1)
	await process_frame
	_check(not panel.visible and panel.summary_label.text.is_empty(), "initial view contains no summary")
	_stage()
	var win := _victory()
	var oracle: Dictionary = RunSignatureSummary.summarize(deck, descriptors, cursor, wardrobe)
	_show(win, "Victory", oracle)
	_check(oracle.stitched_created == 2 and oracle.stitched_current == 2
		and oracle.worn_total == 3, "non-vacuous stitched and worn positive preconditions")
	var old_generation: int = panel._generation
	var old_callback: Callable = panel.return_button.pressed.get_connections()[0].callable
	panel.return_button.pressed.emit()
	panel.return_button.pressed.emit()
	_check(returns == 1 and panel.return_button.disabled, "Return one-shot even under replay")
	panel.close_result()
	_check(panel.summary_label.text.is_empty() and not panel.stitched_section.visible
		and panel.stitched_rows.get_child_count() == 0,
		"closing clears signature and every stitched row")
	old_callback.call()
	_check(returns == 1, "stale prior callback cannot return again")
	_remove_and_resew()
	oracle = RunSignatureSummary.summarize(deck, descriptors, cursor, wardrobe)
	_check(oracle.ok and oracle.stitched_created == 2 and oracle.stitched_current == 1
		and oracle.worn_total == 3 and not oracle.worn_ids.has("button_eye")
		and not oracle.worn_ids.has("spare_spool"), "survivor and replaced-wear source oracle valid")
	_show(win, "Victory", oracle)
	_check(panel._generation > old_generation and returns == 1
		and not panel.return_button.disabled, "fresh open resets callback and Return state")
	panel.close_result()
	_stitch_again()
	oracle = RunSignatureSummary.summarize(deck, descriptors, cursor, wardrobe)
	_check(oracle.ok and oracle.stitched_created == 3 and oracle.stitched_current == 2
		and not oracle.stitched_ids.has("stitched_000001")
		and oracle.stitched_ids.has("stitched_000003"),
		"new authentic Rest stitch increments history and appears once after Shop")
	_show(win, "Victory", oracle)
	panel.close_result()
	var loss := _defeat()
	_show(loss, "Defeat", oracle)
	panel.return_button.grab_focus()
	await process_frame
	_check(panel.return_button.has_focus(), "Return reachable by keyboard focus")
	panel.return_button.pressed.emit()
	_check(returns == 2, "defeat Return remains one-shot")
	panel.close_result()
	# First-run wardrobe absence is projected read-only only from real live inputs.
	wardrobe = null
	app.party_carryover = RunTornCarryover.new(heroes)
	var initial: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/cards/starter_deck.json"))
	deck.assign(initial)
	descriptors.clear()
	cursor = 1
	app.run_deck.assign(deck)
	app.run_stitch_descriptors = {}
	app.run_next_stitch_id = 1
	app.run_trinkets.assign(["unpublished_patch"])
	app.run_scraps = 0
	app.session_gold = 0
	var before: Dictionary = _source(loss)
	_check(panel.open_result(loss.latch), "valid unsewn first run opens")
	_check(panel.summary_label.text.contains("Stitched: 0 made · 0 in deck")
		and panel.summary_label.text.contains("Patches worn: 0")
		and not panel.summary_label.text.contains("Summary unavailable")
		and not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0,
		"validated never-bound wardrobe reports zero worn, not owned inventory")
	_check(_source(loss) == before and app.party_carryover._wardrobe == null,
		"temporary first-run wardrobe is never bound or mutated")
	panel.close_result()
	# Invalid history must not be represented by a zero-count story.
	app.run_next_stitch_id = 0
	_check(panel.open_result(loss.latch)
		and panel.summary_label.text.ends_with("Summary unavailable"),
		"bad ledger cursor fails closed")
	panel.close_result()
	app.run_next_stitch_id = 1
	# Existing bound wardrobe must never be silently replaced when the live deck differs.
	wardrobe = RunPatchWardrobe.new(heroes, ["button_eye"],
		[{"id": "button_eye", "slot": "HEAD"}], 0, 0, deck, 5801)
	var binding: RunTornCarryover = app.party_carryover
	_check(binding.bind_wardrobe(wardrobe, binding.torn, wardrobe.get_snapshot()),
		"bound wardrobe is genuinely associated with current carryover")
	app.run_trinkets.assign(["button_eye"])
	app.run_deck.append("warden_strike")
	before = _source(loss)
	_check(panel.open_result(loss.latch)
		and panel.summary_label.text.ends_with("Summary unavailable"),
		"stale bound wardrobe fails closed rather than asserting zero worn")
	_check(panel.title_label.text == "Defeat" and panel.return_button.disabled
		and not panel.stitched_section.visible and panel.stitched_rows.get_child_count() == 0,
		"unavailable signature preserves outcome but disables Return and stale details")
	_check(_source(loss) == before, "unavailable presentation leaves all source state intact")
	panel.return_button.pressed.emit()
	_check(returns == 2, "unavailable source never authorizes Return")
	panel.close_result()
	_check(panel.summary_label.text.is_empty(), "new runs cannot inherit stale summary")
	_finish()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_run_signature_terminal_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
