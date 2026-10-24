extends "res://tests/live_rest_route_entry_test.gd"
## Mounted route/combat/reward/Shop inputs; only funded gold/count are injected.


class RejectingMap extends RunMap:
	var attempts := 0
	func choose_node(_id: String) -> bool:
		attempts += 1
		return false


## Tokens the retired multi-line card block printed. The accepted concise reward
## faces never show them, so a Shop tile showing one has fallen back to old prose.
const RETIRED_RULES_TEXT: Array[String] = ["From:", "Target:", "Positions:",
	"front position", "middle position", "back position", "Pinned:", "\n"]
## Independent authored expectations for the cards every run owns at Shop entry:
## the exact short sentence and amount each face must print.
const STARTER_EFFECT_LINES := {
	"warden_strike": "Deal 6.",
	"warden_shield_bash": "Deal 8. Weak 1.",
	"warden_brace": "Gain 7 Block.",
	"seamstress_prick": "Deal 3. Bleed 2.",
	"seamstress_mend": "Heal a chosen ally 5 HP.",
	"seamstress_stitch_up": "Give a chosen ally 5 Block.",
	"tinker_pop_shot": "Deal 5.",
	"tinker_scrap_bomb": "Deal 4 to all.",
	"tinker_tune_up": "Draw 1 card.",
}


## The accepted reward face's rules line for one authored definition: the shared
## short renderer, with a stitched composite described by its own authored halves.
func _concise_rules(definition: Dictionary) -> String:
	if definition.is_empty():
		return "No authored description for this card."
	if definition.get("stitched_halves") is String:
		return "Stitched halves: %s" % definition["stitched_halves"]
	return CardShortRules.line(definition)


func _stock_oracle() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var ids: Array[String] = []
	for hero in app.run_heroes:
		ids.append(hero.id)
	var expected := RunShopStockOffers.generate(rng, ids, authored.cards, authored.trinkets, [])
	_check(expected.ok, "real authored pools produce oracle stock")
	for category in ["cards", "trinkets"]:
		for offer in expected[category]:
			offer.sold = false
	return {"stock": {"cards": expected.cards, "trinkets": expected.trinkets}, "state": rng.state}


func _fixture() -> Dictionary:
	for value in range(1, 1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		for id in map.get_legal_choices():
			if map.get_node(id).type != "Fight":
				continue
			var shop := false
			var unsupported := false
			for next in map.get_node(id).outgoing:
				shop = shop or map.get_node(next).type == "Shop"
				unsupported = unsupported or map.get_node(next).type not in ["Rest", "Shop", "Event", "Treasure"]
			if shop and unsupported:
				map.choose_node(id)
				var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
				if selected.get("encounter_id") == "starter_attacks":
					return {"seed": value, "fight": id}
	return {}


func _shop_state() -> Array:
	return [_persistent(), app.run_removal_count, app.shop_visit.get_state()]


## The one passive gallery scene child that mounts sewn tiles beside a visit.
func _visit_tiles():
	return app.get_node("LiveVisitCardTiles")


## Prose the retired multi-line card block printed; a tooltip showing one has
## fallen back to old wording instead of the precise catalog explanation.
const RETIRED_TOOLTIP_TEXT: Array[String] = ["From:", "Target:", "Positions:",
	"front position", "middle position", "back position", "PIPS:"]


## Independent, catalog-grounded hover oracle for one authored card. It reads
## only the authored definition plus the published on-hit and status-passive
## rules, and never calls the visit presenter that produced the tooltip.
func _tooltip_oracle(definition: Dictionary) -> Dictionary:
	var id: String = String(definition.get("id", ""))
	var owner: String = String(definition.get("owner", ""))
	var effects: Dictionary = definition.get("effects", {})
	var confirmed: Dictionary = CombatOnHitStatuses.new().status_for_confirmed_hit(id, true)
	var facts := {
		"header": "%s; %s; %d energy" % [String(definition.get("display_name", id)),
			owner.capitalize(), int(definition.get("cost", -1))],
		"source": "From " + _positions_oracle(definition.get("from_positions", [])),
		"target": _target_oracle(definition),
		"facts": [],
		"keywords": [],
	}
	if effects.has("damage"):
		facts.facts.append("deal %d damage" % int(effects["damage"]))
	if effects.has("block"):
		facts.facts.append("gain %d Block" % int(effects["block"]))
	if effects.has("block_all"):
		facts.facts.append("%d Block" % int(effects["block_all"]))
	if effects.has("other_ally_block"):
		facts.facts.append("%d Block" % int(effects["other_ally_block"]))
	if effects.has("heal") and effects["heal"] is int:
		facts.facts.append("heal %d HP" % int(effects["heal"]))
	if effects.has("draw"):
		facts.facts.append("draw %d card" % int(effects["draw"]))
	if effects.has("gain_energy"):
		facts.facts.append("gain %d energy" % int(effects["gain_energy"]))
	elif effects.has("energy"):
		facts.facts.append("gain %d energy" % int(effects["energy"]))
	if effects.has("exposed"):
		facts.facts.append("Exposed %d" % int(effects["exposed"]))
	if effects.has("weak"):
		facts.facts.append("%s Weak %d" % ["add" if confirmed.has("weak") else "apply",
			int(effects["weak"])])
	if effects.has("bleed"):
		if confirmed.has("bleed"):
			facts.facts.append("add Bleed %d" % int(confirmed["bleed"]))
		else:
			var applied: int = int(effects["bleed"]) \
				+ (1 if CombatSeamstressPoolBleed.SUPPORTED_IDS.has(id) else 0)
			facts.facts.append("Bleed %d" % applied)
	if effects.has("unravel"):
		facts.facts.append("add %d Unravel" % int(effects["unravel"]))
	if effects.has("bleed_multiplier"):
		facts.facts.append("double the target's current Bleed"
			if int(effects["bleed_multiplier"]) == 2
			else "Bleed by %d" % int(effects["bleed_multiplier"]))
	if effects.has("pinned"):
		facts.facts.append("Pin ")
		facts.keywords.append("PINNED:")
	if effects.has("unravel") or _unravel_conditional(effects):
		facts.keywords.append("UNRAVEL:")
	if effects.has("thorns"):
		facts.facts.append("%d Thorns" % int(effects["thorns"]))
	if effects.has("guarding"):
		facts.facts.append("Guard")
	var condition: Variant = effects.get("conditional_damage")
	if condition is Dictionary and (condition as Dictionary).get("damage") is int:
		facts.facts.append("deal %d damage instead" % int((condition as Dictionary)["damage"]))
	return facts


## Unravelled/half-gauge conditionals need the Unravel rules just as an Unravel N
## does; this mirrors the published glossary trigger, not the presenter.
func _unravel_conditional(effects: Dictionary) -> bool:
	var condition: Variant = effects.get("conditional_damage")
	if not (condition is Dictionary):
		return false
	var entries: Variant = (condition as Dictionary).get("conditions", [])
	if not (entries is Array):
		return false
	for entry in entries:
		if entry is Dictionary and (str((entry as Dictionary).get("status", "")) == "unravelled" \
				or (str((entry as Dictionary).get("gauge", "")) == "unravel" \
				and str((entry as Dictionary).get("comparison", "")) == "at_least_half")):
			return true
	return false


## Authored slots with the same contiguous-range wording the shared formatter
## publishes, computed from the catalog array rather than from the tooltip.
func _positions_oracle(positions: Array) -> String:
	if positions.is_empty():
		return "?"
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	for index in range(1, positions.size()):
		if int(positions[index]) != int(positions[index - 1]) + 1:
			return ",".join(values)
	if positions.size() > 1:
		return "%s–%s" % [values.front(), values.back()]
	return values.front()


## The authored recipient sentence for one target kind.
func _target_oracle(definition: Dictionary) -> String:
	var positions: Array = definition.get("to_positions", [])
	match str(definition.get("target_kind", "")):
		"enemy_single":
			return "To one selected enemy " + _positions_oracle(positions)
		"enemy_all":
			return "All enemies " + _positions_oracle(positions)
		"enemy_random":
			return "A random living enemy per hit (%s)" % _positions_oracle(positions)
		"self":
			return "Self"
		"ally_single":
			return "Choose one living ally"
		"party_all":
			return "All living heroes"
		"adjacent_ally":
			return "Swap with the living adjacent ally %s" % (
				"behind" if int(definition.get("direction", 0)) == 1 else "ahead")
		"none":
			return "No target"
	return ""


## AC1: one mounted tile's hover carries the complete authored record - name,
## owner, cost, source slots, target, exact effect numbers and keyword rules -
## without the hand-only PIPS legend or the retired prose.
func _check_card_tooltip(tile, definition: Dictionary, label: String) -> void:
	var tooltip: String = tile.tooltip_text if is_instance_valid(tile) else ""
	var facts := _tooltip_oracle(definition)
	var expected := "%s\n%s" % [facts.header, facts.source]
	if not String(facts.target).is_empty():
		expected += "\n" + String(facts.target)
	_check(tooltip.begins_with(expected),
		"%s tooltip opens with the authored name, owner, cost, source slots and target: %s"
			% [label, String(definition.get("id", ""))])
	_check(RETIRED_TOOLTIP_TEXT.all(func(token): return not tooltip.contains(token)),
		"%s tooltip drops the hand pip legend and the retired prose" % label)
	for fact in facts.facts:
		_check(tooltip.contains(String(fact)),
			"%s tooltip states the authored effect '%s'" % [label, String(fact)])
	for keyword in facts.keywords:
		_check(tooltip.contains(String(keyword)),
			"%s tooltip explains the authored keyword %s" % [label, String(keyword)])
	for keyword in ["PINNED:", "UNRAVEL:"]:
		if not facts.keywords.has(keyword):
			_check(not tooltip.contains(keyword),
				"%s tooltip invents no %s rule" % [label, keyword])


## AC2: an upgrade tile's hover carries both authored halves under Before/After
## headings, each with its own name, cost, source, target and effect numbers.
func _check_upgrade_tooltip(tile, base_definition: Dictionary, plus_definition: Dictionary) -> void:
	var tooltip: String = tile.tooltip_text if is_instance_valid(tile) else ""
	var before := _tooltip_oracle(base_definition)
	var after := _tooltip_oracle(plus_definition)
	var before_lead := "Before:\n%s\n%s" % [before.header, before.source]
	var after_lead := "\nAfter:\n%s\n%s" % [after.header, after.source]
	if not String(before.target).is_empty():
		before_lead += "\n" + String(before.target)
	if not String(after.target).is_empty():
		after_lead += "\n" + String(after.target)
	_check(tooltip.begins_with(before_lead) and tooltip.contains(after_lead),
		"upgrade tooltip opens with the authored Before then After name, cost, source and target")
	_check(RETIRED_TOOLTIP_TEXT.all(func(token): return not tooltip.contains(token))
		and tooltip.find("Before:") < tooltip.find("After:"),
		"upgrade tooltip keeps Before before After and drops the hand pip legend")
	var sections: PackedStringArray = tooltip.split("\nAfter:\n")
	_check(sections.size() == 2, "upgrade tooltip has exactly one Before and one After half")
	if sections.size() != 2:
		return
	var before_text: String = String(sections[0]).trim_prefix("Before:\n")
	var after_text: String = String(sections[1])
	for fact in before.facts:
		_check(before_text.contains(String(fact)),
			"Before half states its own authored effect '%s'" % String(fact))
	for fact in after.facts:
		_check(after_text.contains(String(fact)),
			"After half states its own authored effect '%s'" % String(fact))


## Real pointer hover over one tile: motion only, never a button event.
func _hover(control: Control) -> void:
	_check(is_instance_valid(control), "physical hover requires a mounted tile")
	if not is_instance_valid(control):
		return
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


## The first two owned copies a genuine stitch accepts: two authored, different
## owners, exactly as the Rest transaction requires.
func _stitch_indices(deck: Array) -> Array:
	for first in range(deck.size()):
		var first_definition: Dictionary = RunRestStitchCards.resolve_card_definition(String(deck[first]))
		if first_definition.is_empty():
			continue
		for second in range(first + 1, deck.size()):
			var second_definition: Dictionary = RunRestStitchCards.resolve_card_definition(String(deck[second]))
			if second_definition.is_empty() or second_definition.get("owner") == first_definition.get("owner"):
				continue
			return [first, second]
	return []


## AC1: a genuinely sewn owned copy explains its ordered authored halves in the
## Shop, with the composite's own name and cost and without the hand pip legend;
## a forged descriptor says details are unavailable instead of guessing. Every
## step reads only canonical run state and is restored afterwards.
func _check_stitched_removal_tooltip(gallery) -> void:
	var deck: Array = app.run_deck.duplicate()
	var descriptors: Dictionary = app.run_stitch_descriptors.duplicate(true)
	var next_id: int = app.run_next_stitch_id
	var pair := _stitch_indices(deck)
	_check(pair.size() == 2 and pair[0] < pair[1], "the owned deck holds two authored halves of different owners")
	if pair.size() != 2:
		return
	var ledger := RunRestStitchCards.new(deck, descriptors, RunRestStitchCards.SCRAP_COST, next_id)
	var made: Dictionary = ledger.choose_stitch(pair[0], pair[1], ledger.get_snapshot())
	_check(made.get("ok") == true and made.get("consumed_ids") == [deck[pair[0]], deck[pair[1]]],
		"genuine Rest stitch transaction produces an authentic composite")
	if made.get("ok") != true:
		return
	var stitched_id: String = String(made.get("stitched_id", ""))
	var descriptor: Dictionary = made.get("descriptor", {}).duplicate(true)
	app.run_deck.assign(made.get("deck", []))
	app.run_stitch_descriptors = made.get("descriptors", {}).duplicate(true)
	app.run_next_stitch_id = int(made.get("next_stitch_id", next_id))
	await _frames()
	await _frames()
	var row: int = app.run_deck.find(stitched_id)
	var tile = _tile_for("removal", row)
	_check(tile != null and row >= 0, "the sewn owned copy mounts its own removal tile")
	if tile != null:
		var tooltip: String = tile.tooltip_text
		var details: Dictionary = gallery.tile_details(tile)
		var first: Dictionary = RunRestStitchCards.resolve_card_definition(String(made["consumed_ids"][0]))
		var second: Dictionary = RunRestStitchCards.resolve_card_definition(String(made["consumed_ids"][1]))
		_check(details.tooltip == tooltip
			and tooltip.begins_with("%s; %d energy" % [String(descriptor.get("display_name", "")),
				int(descriptor.get("cost", 0))]),
			"sewn removal tooltip states the composite's authored name and cost")
		_check(tooltip.contains("1. %s; %s; %d energy" % [String(first.get("display_name", "")),
				String(first.get("owner", "")).capitalize(), int(first.get("cost", -1))])
			and tooltip.contains("\n2. %s; %s; %d energy" % [String(second.get("display_name", "")),
				String(second.get("owner", "")).capitalize(), int(second.get("cost", -1))])
			and tooltip.find("\n1. ") < tooltip.find("\n2. "),
			"sewn removal tooltip names its ordered authored halves")
		var first_rules := _tooltip_oracle(first)
		var second_rules := _tooltip_oracle(second)
		for fact in first_rules.facts:
			_check(tooltip.contains(String(fact)), "sewn first half keeps its authored effect '%s'" % fact)
		for fact in second_rules.facts:
			_check(tooltip.contains(String(fact)), "sewn second half keeps its authored effect '%s'" % fact)
		_check(RETIRED_TOOLTIP_TEXT.all(func(token): return not tooltip.contains(token))
			and not tooltip.contains(stitched_id),
			"sewn removal tooltip drops the hand pip legend and never prints a raw ID")
	var hover_before := _shop_state()
	await _hover(tile)
	_check(_shop_state() == hover_before, "hovering a sewn owned copy spends and advances nothing")
	# A forged descriptor no longer matches the canonical projection of its two
	# authored halves, so it must print the honest placeholder.
	var forged: Dictionary = app.run_stitch_descriptors.duplicate(true)
	forged[stitched_id]["display_name"] = "Forged Seam"
	app.run_stitch_descriptors = forged
	await _frames()
	await _frames()
	var forged_tile = _tile_for("removal", app.run_deck.find(stitched_id))
	_check(forged_tile != null and forged_tile.tooltip_text == LiveVisitCardTiles.DETAILS_UNAVAILABLE,
		"a forged stitched descriptor prints details unavailable instead of invented halves")
	app.run_deck.assign(deck)
	app.run_stitch_descriptors = descriptors
	app.run_next_stitch_id = next_id
	await _frames()
	await _frames()
	var restored = _tile_for("removal", 0)
	var restored_definition: Dictionary = RunRestStitchCards.resolve_card_definition(String(deck[0]))
	var restored_oracle := _tooltip_oracle(restored_definition)
	_check(restored != null and not restored_definition.is_empty()
		and restored.tooltip_text.begins_with("%s\n%s" % [restored_oracle.header, restored_oracle.source])
		and not restored.tooltip_text.contains("ordered halves")
		and not restored.tooltip_text.contains(stitched_id),
		"restoring the canonical deck replaces the stale sewn hover text")


## Every tile of one group currently painting the SELECTED cue.
func _selected_tiles(gallery, group: String) -> Array:
	var source: Array = gallery.offer_tiles() if group == "offer" \
		else (gallery.removal_tiles() if group == "removal" else gallery.upgrade_tiles())
	var result: Array = []
	for tile in source:
		if gallery.tile_details(tile).get("selected", false):
			result.append(tile)
	return result


## AC1/AC2: a real click and a real Enter move the one visible SELECTED cue
## between the canonical rows with no wallet, deck, map or RNG effect; the
## masked selectors keep their whole data contract without a dropdown row; and
## the shared face gives a long wrapped card a whole, unclipped tag.
func _check_selection_cue(gallery) -> void:
	var before := _shop_state()
	await _click_tile(_tile_for("offer", 3))
	_check(app.shop_offers.selected == 3 and _shop_state() == before,
		"real offer click selects the fourth listing with no run effect")
	_check(_selected_tiles(gallery, "offer") == [_tile_for("offer", 3)],
		"exactly the clicked offer tile shows the SELECTED cue")
	await _select_tile_by_key(_tile_for("offer", 0))
	_check(app.shop_offers.selected == 0 and _shop_state() == before,
		"real offer Enter selects the first listing with no run effect")
	_check(_selected_tiles(gallery, "offer") == [_tile_for("offer", 0)]
		and not gallery.tile_details(_tile_for("offer", 3)).selected,
		"moving selection clears the prior cue and marks only the new tile")
	var cue: Dictionary = gallery.build_card_face({
		"card_id": "warden_strike", "art_id": "warden_strike", "owner": "warden",
		"title": "Stitched Overlong Recursive Seamstress Repair Volley of the Warden's Twin Needles",
		"meta": "Deck card #12 • copy 3 of 4 • removal costs 100 gold",
		"effects": "Deal 6 damage to the front position and gain 7 Block.\nBefore: chosen ally heals 5 HP\nAfter: chosen ally heals 7 HP and gains 5 Block\nPinned: exhausts at end of turn"})
	root.add_child(cue["tile"])
	await _frames()
	# Let the probe face take its own readable minimum size, exactly as the
	# gallery lays it out, instead of forcing a box that would clip by design.
	var needed: Vector2 = cue["tile"].get_combined_minimum_size()
	cue["tile"].size = Vector2(maxf(520.0, needed.x), maxf(240.0, needed.y))
	await _frames()
	cue["selected_label"].visible = true
	await _frames()
	var tag: Control = cue["selected_label"]
	_check(tag.is_visible_in_tree() and tag.text == "SELECTED" and tag.size.x > 0.0 and tag.size.y > 0.0
		and cue["panel"].get_global_rect().encloses(tag.get_global_rect())
		and not tag.get_global_rect().intersects(cue["effects_label"].get_global_rect())
		and not tag.get_global_rect().intersects(cue["picture"].get_global_rect())
		and cue["title_label"].text.begins_with("Stitched Overlong")
		and cue["effects_label"].text.contains("Pinned: exhausts at end of turn"),
		"a long wrapped card keeps one whole SELECTED tag inside its sewn frame, clear of art, name and effects")
	cue["tile"].free()


func _tile_for(group: String, row: int):
	var gallery = _visit_tiles()
	var source: Array = gallery.offer_tiles() if group == "offer" \
		else (gallery.removal_tiles() if group == "removal" else gallery.upgrade_tiles())
	for tile in source:
		if gallery.tile_row(tile) == row:
			return tile
	return null


## Real pointer selection: the tile must be scrolled into the visible gallery
## first, exactly as a player reaches a lower card.
func _click_tile(tile) -> void:
	_check(tile != null, "physical tile click requires a mounted tile")
	if tile == null:
		return
	_visit_tiles().gallery_scroll().ensure_control_visible(tile)
	await _frames()
	await _click(tile)


## Real keyboard selection: focus the tile, then Enter activates it.
func _select_tile_by_key(tile) -> void:
	_check(tile != null, "keyboard tile selection requires a mounted tile")
	if tile == null:
		return
	tile.grab_focus()
	await _frames()
	_check(tile.has_focus(), "keyboard focus reaches the mounted tile")
	await _key(KEY_ENTER)


## AC2: the physical Shop visit displays its committed stall scene behind the same usable
## controls, with a cover crop and no pointer or keyboard capture.
func _check_shop_backdrop() -> int:
	var bed = app.visit_backdrop
	_check(is_instance_valid(bed) and bed.get_parent() == app
		and bed.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and bed.focus_mode == Control.FOCUS_NONE,
		"Shop visit mounts one inert full-screen art bed")
	if not is_instance_valid(bed):
		return 0
	var expected := "res://assets/paper/backgrounds/shop_stall.png"
	_check(VISIT_ART.visit_backdrop_path("Shop") == expected and bed.visit_kind == "Shop"
		and bed.has_image() == ResourceLoader.exists(expected)
		and (not bed.has_image() or bed.visit_texture.resource_path == expected),
		"Shop visit draws its own committed stall scene")
	_check(bed.get_index() < app.shop_view.get_index(),
		"Shop art bed is drawn behind the usable Shop controls")
	var view: Rect2 = bed.view_rect()
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and Rect2(Vector2.ZERO, app.size).is_equal_approx(view)
		and Rect2(0, 0, 1280, 720).encloses(bed.get_global_rect()),
		"Shop art bed fills the whole 1280x720 visit, not one control box")
	var drawn: Rect2 = bed.image_rect()
	var visible: Rect2 = bed.image_crop()
	var pixels: Vector2 = bed.texture_size()
	_check(bed.has_image() and drawn.encloses(view)
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y),
		"Shop stall scene covers the view without stretching")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= pixels.x + 0.01 and visible.end.y <= pixels.y + 0.01
		and is_equal_approx(visible.size.x * (drawn.size.x / pixels.x), view.size.x),
		"Shop stall scene crops only the centred window that fills the view")
	return bed.get_instance_id()


## The tile face is the reward card's own. Cover all three authored render
## priorities with a controlled synthetic ID: the card illustration, then the
## owner emblem, then the drawn paper patch, and never assume art is absent.
func _check_tile_art(gallery) -> void:
	var authored: Dictionary = gallery.build_card_face({
		"card_id": "warden_strike", "art_id": "warden_strike", "owner": "warden",
		"title": "Strike", "meta": "probe", "effects": "probe"})
	root.add_child(authored["tile"])
	authored["tile"].size = Vector2(520, 200)
	await _frames()
	_check(authored["picture"].has_picture()
		and authored["picture"].picture.resource_path == "res://assets/paper/cards/art/warden_strike.png",
		"a tile for an illustrated card reuses the reward card's authored picture")
	authored["tile"].free()
	var emblem: Dictionary = gallery.build_card_face({
		"card_id": "zz_synthetic_missing_art", "art_id": "zz_synthetic_missing_art", "owner": "warden",
		"title": "Synthetic probe", "meta": "probe", "effects": "probe"})
	root.add_child(emblem["tile"])
	emblem["tile"].size = Vector2(520, 200)
	await _frames()
	_check(emblem["picture"].has_picture()
		and emblem["picture"].picture.resource_path == "res://assets/paper/cards/emblem_warden.png",
		"a card without its own art falls back to the owning hero's stitched emblem")
	emblem["tile"].free()
	var drawn: Dictionary = gallery.build_card_face({
		"card_id": "zz_synthetic_missing_art", "art_id": "zz_synthetic_missing_art",
		"owner": "synthetic_owner", "title": "Synthetic probe", "meta": "probe", "effects": "probe"})
	root.add_child(drawn["tile"])
	drawn["tile"].size = Vector2(520, 200)
	await _frames()
	_check(not drawn["picture"].has_picture() and drawn["title_label"].text == "Synthetic probe"
		and drawn["tile"].get_global_rect().size.x > 0.0 and drawn["tile"].get_global_rect().size.y > 0.0,
		"a card with neither picture nor emblem still mounts the drawn paper fallback")
	drawn["tile"].free()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _fixture()
	_check(not fixture.is_empty(), "seeded real graph offers Shop and unsupported choices after starter Fight")
	if fixture.is_empty():
		_finish_shop()
		return
	var stale: Array[Callable] = []
	var replay: Array = []
	# Normal insufficient funds, funded mouse, funded keyboard with escalated quote,
	# and same-seed normal restart/skip.
	for session in range(4):
		seed(400040)
		var global_next := randi()
		seed(400040)
		if not await _routed_win(fixture, false):
			break
		if session != 1:
			await _click(app.reward_buttons[3])
		else:
			app.reward_buttons[0].grab_focus()
			await _key(KEY_ENTER)
		_check(app.fight_reward_claimed and is_instance_valid(app.continue_button), "reward claim/skip exposes live Continue")
		if not is_instance_valid(app.continue_button):
			break
		var before := _persistent()
		for callback in stale:
			callback.call()
		_check(_persistent() == before and app.shop_visit == null, "old visit callbacks cannot spend or reopen in fresh combat")
		await _click(app.continue_button)
		var shop: Button
		var shown: Array[String] = []
		before = _persistent()
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			var kind: String = app.run_map.get_node(id).type
			shown.append(id)
			_check(button.disabled == (kind not in ["Rest", "Shop", "Event", "Treasure", "Fight", "Elite", "Boss"]), "only supported connected controls enabled")
			if kind == "Shop":
				shop = button
			if button.disabled:
				await _click(button)
				button.grab_focus()
				await _key(KEY_ENTER)
				button.pressed.emit()
		_check(shown == app.run_map.get_legal_choices() and shop != null, "real connected Shop button is mounted")
		_check(_persistent() == before, "unsupported physical and retained signal input is inert")
		if shop == null:
			break
		var route_callback: Callable = shop.pressed.get_connections()[0].callable
		var back_callback: Callable = app.route_back_button.pressed.get_connections()[0].callable
		var prior: Array[String] = app.run_map.get_route()
		var id: String = shop.get_meta("route_id")
		var parent: String = app.run_map.get_current_node_id()
		var outgoing: Array = app.run_map._nodes[parent].outgoing.duplicate()
		app.run_map._nodes[parent].outgoing.erase(id)
		route_callback.call()
		_check(_persistent() == before and app.shop_view == null, "disconnected mounted Shop rejects before map commit")
		app.run_map._nodes[parent].outgoing = outgoing
		app._choose_shop_route(id, weakref(RunMap.new()), prior, shop)
		app._choose_shop_route("f12_n0", weakref(app.run_map), prior, shop)
		var empty_route: Array[String] = []
		app._choose_shop_route(id, weakref(app.run_map), empty_route, shop)
		shop.disabled = true
		route_callback.call()
		shop.disabled = false
		app.run_map._nodes[id].type = "Rest"
		route_callback.call()
		app.run_map._nodes[id].type = "Shop"
		_check(_persistent() == before and app.shop_visit == null, "wrong identity, ID, route, disabled button and node type reject")
		var saved_gold: int = app.session_gold
		app.session_gold = -1
		var invalid_before := _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null, "invalid ledger cannot commit a route choice")
		app.session_gold = saved_gold
		var saved_rng: RandomNumberGenerator = app.run_rng
		app.run_rng = null
		var missing_before := [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()]
		route_callback.call()
		_check(app.run_rng == null and app.shop_visit == null and app.shop_purchases == null
			and missing_before == [app.run_heroes, app.run_deck, app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()], "absent RNG rejects without partial entry")
		app.run_rng = saved_rng
		# Published roster drift now fails before entering another run node.
		var heroes: Array = app.run_heroes.duplicate(true)
		app.run_heroes[0].id = "unknown_shop_owner"
		_check(not app._can_choose_connected_route(), "published roster drift fails carryover admission")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null, "roster drift cannot advance route or consume RNG")
		# Align the held fixture too so the original stock rejection remains reachable.
		app.party_carryover._heroes[0].id = "unknown_shop_owner"
		_check(app._can_choose_connected_route(), "unknown catalog owner passes roster admission before stock rejection")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected stock leaves roster, deck, gold, route and RNG untouched")
		app.run_heroes = heroes
		app.party_carryover._heroes = heroes.duplicate(true)
		# Force choose_node to reject only after admission and valid generation.
		var original_map: RunMap = app.run_map
		var rejecting := RejectingMap.new()
		rejecting._nodes = original_map._nodes.duplicate(true)
		rejecting._floor_ids = original_map._floor_ids.duplicate(true)
		rejecting._route.assign(prior)
		rejecting._generation_revision = original_map.get_generation_revision()
		app.run_map = rejecting
		app._carryover_map = weakref(rejecting)
		app.act_outcome._map = rejecting
		app._connected_map = weakref(rejecting)
		app._reward_map = weakref(rejecting)
		invalid_before = _persistent()
		_check(not app._choose_shop_route(id, weakref(rejecting), prior, shop) and rejecting.attempts == 1,
			"valid generated stock reaches rejecting map choice")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"rejected map choice restores RNG and publishes no ledger or stock")
		app.run_map = original_map
		app._carryover_map = weakref(original_map)
		app.act_outcome._map = original_map
		app._connected_map = weakref(original_map)
		app._reward_map = weakref(original_map)
		# A connected whitespace node reaches open_visit, which rejects its ID.
		original_map._nodes[" "] = original_map._nodes[id].duplicate(true)
		original_map._nodes[parent].outgoing.append(" ")
		# Align the deliberately altered graph binding to reach visit rollback,
		# rather than failing the stale-battle guard before stock generation.
		app._carryover_floors = original_map.get_floors()
		shop.set_meta("route_id", " ")
		_check(app._can_choose_connected_route() and original_map.get_legal_choices().has(" ")
			and original_map.get_node(" ").type == "Shop" and _stock_oracle().stock.cards.size() == 5,
			"whitespace fixture admits connected Shop with valid generated stock before visit opening")
		invalid_before = _persistent()
		_check(not app._choose_shop_route(" ", weakref(original_map), prior, shop), "visit opening rejects whitespace ID")
		_check(_persistent() == invalid_before and app.shop_visit == null and app.shop_purchases == null,
			"failed visit opening rolls back committed map and generated RNG")
		original_map._nodes.erase(" ")
		original_map._nodes[parent].outgoing = outgoing
		app._carryover_floors = original_map.get_floors()
		shop.set_meta("route_id", id)
		if session in [1, 2]:
			app.session_gold = 200
			app.run_removal_count = 1 if session == 2 else 0
		if session == 2:
			shop.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(shop)
		_check(app.shop_view != null and app.shop_visit != null, "physical Shop entry mounts real ledger and view")
		if app.shop_view == null or app.shop_visit == null:
			break
		var bed_id: int = _check_shop_backdrop()
		var visit: RunShopVisit = app.shop_visit
		var state := visit.get_state()
		_check(app.run_map.get_route() == [fixture.fight, id] and state.visited_ids == [id]
			and state.shop_node_id == id and state.removal_available, "Shop records exact ID and route once")
		var price: int = 75 + 25 * app.run_removal_count
		_check(app.shop_label.text == "Gold: %d | Removal: %d gold" % [app.session_gold, price], "visible gold and authoritative escalating quote")
		_check(app.shop_cards.item_count == app.run_deck.size(), "compact OptionButton includes every owned copy")
		for index in range(app.run_deck.size()):
			_check(app.shop_cards.get_item_text(index) == app.run_deck[index], "owned ID order is visible")
		_check(app.shop_purchases.is_valid() and app.shop_offers.item_count == 5, "routed Shop includes valid card buying stock")
		for control in [app.shop_view, app.shop_label, app.shop_offers, app.shop_buy_button, app.shop_cards, app.shop_remove_button, app.shop_continue_button, app.shop_back_button]:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "Shop control fits 1280x720")
		var gallery = _visit_tiles()
		_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Shop",
			"real Shop mounts the passive visit card gallery")
		var panel: Control = gallery.gallery_panel()
		_check(is_instance_valid(panel) and panel.is_visible_in_tree()
			and Rect2(0, 0, 1280, 720).encloses(panel.get_global_rect())
			and is_instance_valid(gallery.gallery_scroll()),
			"scrollable Shop gallery fits inside 1280x720")
		_check(gallery.offer_tiles().size() == 5, "Shop gallery shows all five offer tiles")
		_check(gallery.removal_tiles().size() == app.run_deck.size(),
			"Shop gallery shows exactly one removal tile per owned occurrence")
		var scroll: ScrollContainer = gallery.gallery_scroll()
		var scroll_start: int = scroll.scroll_vertical
		scroll.ensure_control_visible(gallery.removal_tiles().back())
		await _frames()
		_check(scroll.scroll_vertical > scroll_start
			and Rect2(0, 0, 1280, 720).encloses(gallery.removal_tiles().back().get_global_rect()),
			"the scrollable gallery reaches a lower owned card inside 1280x720")
		for control in [app.shop_offers, app.shop_cards]:
			_check(control.is_visible_in_tree() and not control.disabled and control.modulate.a == 0.0
				and control.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and control.focus_mode == Control.FOCUS_NONE,
				"masked Shop dropdown keeps its validated contract but takes no pointer or focus")
		var layouts: Array = [gallery.masked_selector_layout("offer"),
			gallery.masked_selector_layout("removal")]
		for layout in layouts:
			_check(not layout.is_empty() and layout.original_custom_minimum.y >= 48.0
				and layout.masked_min_height <= LiveVisitCardTiles.MASKED_ROW_MIN_HEIGHT
				and layout.visible_in_tree and not layout.disabled and layout.item_count > 0
				and layout.selected >= 0 and layout.pointer_ignore and layout.focus_none,
				"masked Shop dropdown keeps its data contract but takes no left-column dropdown row")
		for button in [app.shop_buy_button, app.shop_remove_button,
				app.shop_continue_button, app.shop_back_button]:
			_check(button.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(button.get_global_rect())
				and not app.shop_offers.get_global_rect().intersects(button.get_global_rect())
				and not app.shop_cards.get_global_rect().intersects(button.get_global_rect()),
				"real Shop action stays readable and clear of the collapsed selector rows")
		if session == 0:
			app.shop_view.visible = false
			await _frames()
			_check(app.shop_offers.custom_minimum_size == Vector2(440, 48)
				and app.shop_offers.modulate.a == 1.0
				and app.shop_offers.focus_mode != Control.FOCUS_NONE
				and app.shop_offers.mouse_filter != Control.MOUSE_FILTER_IGNORE
				and app.shop_offers.get_combined_minimum_size().y >= 24.0,
				"tearing the gallery down restores the canonical Shop dropdown exactly")
			app.shop_view.visible = true
			await _frames()
			_check(gallery.is_gallery_mounted() and gallery.gallery_kind() == "Shop"
				and app.shop_offers.custom_minimum_size == Vector2.ZERO
				and app.shop_offers.modulate.a == 0.0,
				"a re-synced Shop visit masks and collapses its selectors again")
		var stock: Array = app.shop_purchases.get_stock().cards
		var keyword_offers := 0
		for index in range(gallery.offer_tiles().size()):
			var tile = gallery.offer_tiles()[index]
			var details: Dictionary = gallery.tile_details(tile)
			var listing: Dictionary = stock[index]
			var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(listing.id)
			_check(gallery.tile_row(tile) == index and details.card_id == listing.id
				and details.title == String(definition.get("display_name", listing.id))
				and details.meta.begins_with("%d gold" % int(listing.price)) and details.has_picture,
				"offer tile shows its authored name, quoted price and art/emblem")
			# The accepted reward face's own concise line, never the old block.
			_check(details.effects == _concise_rules(definition)
				and not details.effects.is_empty() and details.effects.ends_with(".")
				and RETIRED_RULES_TEXT.all(func(token): return not details.effects.contains(token)),
				"offer tile prints the accepted concise effect, not position prose: " + String(listing.id))
			# AC1: a genuine offer tile explains its full authored record on hover.
			_check(details.tooltip == tile.tooltip_text and not tile.tooltip_text.is_empty(),
				"offer tile exposes its hover explanation on the mounted tile button")
			_check_card_tooltip(tile, definition, "offer tile")
			var effects: Dictionary = definition.get("effects", {})
			if effects.has("pinned") or effects.has("unravel") or _unravel_conditional(effects):
				keyword_offers += 1
			if effects.has("pinned"):
				_check(tile.tooltip_text.contains("one pin per enemy")
					and tile.tooltip_text.contains("+5 damage BEFORE Weak/Exposed"),
					"pinned offer tooltip explains the published pin rule")
			if effects.has("unravel") or _unravel_conditional(effects):
				_check(tile.tooltip_text.contains("Unravel N adds N to that enemy's gauge"),
					"unravel offer tooltip explains the published gauge rule")
		# The seeded stock carries an authored status-keyword offer, so the
		# keyword handling is genuinely exercised instead of silently skipped.
		_check(keyword_offers > 0, "this Shop stock contains an authored status-keyword offer")
		for index in range(app.run_deck.size()):
			var tile = gallery.removal_tiles()[index]
			var details: Dictionary = gallery.tile_details(tile)
			var owned: String = app.run_deck[index]
			var definition: Dictionary = RunRestStitchCards.resolve_card_definition(owned)
			_check(gallery.tile_row(tile) == index and details.card_id == owned
				and details.title == String(definition.get("display_name", owned))
				and details.meta.begins_with("Deck card #%d" % (index + 1)),
				"removal tile carries the exact owned occurrence index and authored name")
			# A real owned copy prints the accepted concise wording, and the
			# independently authored sentence for that exact card ID.
			_check(details.effects == _concise_rules(definition)
				and not details.effects.is_empty() and details.effects.ends_with(".")
				and RETIRED_RULES_TEXT.all(func(token): return not details.effects.contains(token)),
				"removal tile prints the accepted concise rules wording, not position prose")
			if STARTER_EFFECT_LINES.has(owned):
				_check(details.effects == String(STARTER_EFFECT_LINES[owned]),
					"removal tile prints the exact authored short effect for " + owned)
			# AC1: the owned tile's hover is the same complete authored record.
			_check(details.tooltip == tile.tooltip_text and not tile.tooltip_text.is_empty(),
				"owned removal tile exposes its hover explanation on the mounted tile button")
			_check_card_tooltip(tile, definition, "owned removal tile")
		for known in ["warden_strike", "warden_brace", "seamstress_mend",
				"seamstress_stitch_up", "tinker_scrap_bomb", "tinker_tune_up"]:
			_check(app.run_deck.has(known) and STARTER_EFFECT_LINES.has(known),
				"exact concise expectation is exercised by an owned copy: " + known)
		# The mounted Shop faces keep their concise sentence readable inside the
		# sewn frame at 1280x720 (both a priced offer and an owned copy).
		for tile in [gallery.offer_tiles()[0], gallery.removal_tiles()[0]]:
			var face_panel: Control = tile.get_parent()
			var effects_label := face_panel.find_child("TileEffects", true, false) as Label
			_check(effects_label != null and effects_label.text == gallery.tile_details(tile).effects
				and effects_label.get_theme_font_size("font_size") >= 13
				and face_panel.get_global_rect().encloses(effects_label.get_global_rect()),
				"the concise effect stays legible inside its sewn Shop tile")
		before = _shop_state()
		var hover_selection: int = app.shop_offers.selected
		await _hover(gallery.offer_tiles()[0])
		gallery.gallery_scroll().ensure_control_visible(gallery.removal_tiles()[0])
		await _frames()
		await _hover(gallery.removal_tiles()[0])
		_check(_shop_state() == before and app.shop_offers.selected == hover_selection,
			"hovering Shop tiles explains them without selecting, spending or advancing")
		await _click_tile(_tile_for("offer", 2))
		_check(_shop_state() == before and app.shop_offers.selected == 2,
			"offer tile click selects that listing with zero ledger effect")
		await _select_tile_by_key(_tile_for("offer", 1))
		_check(_shop_state() == before and app.shop_offers.selected == 1,
			"offer tile keyboard selection has zero ledger effect")
		if session == 0:
			await _check_tile_art(gallery)
			await _check_selection_cue(gallery)
			await _check_stitched_removal_tooltip(gallery)
		before = _shop_state()
		route_callback.call()
		back_callback.call()
		_check(_shop_state() == before and app.shop_view.visible, "duplicate entry and stale route Back cannot mutate or close Shop")
		var remove_callback: Callable = app.shop_remove_button.pressed.get_connections()[0].callable
		var live_map: RunMap = app.run_map
		var other := RunMap.new()
		var other_rng := RandomNumberGenerator.new()
		other_rng.seed = fixture.seed
		other.generate(other_rng)
		_check(other.choose_node(fixture.fight) and other.choose_node(id), "replacement map has identical legal Shop route")
		app.run_map = other
		var wrong_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == wrong_before, "same-route replacement map cannot spend")
		app.run_map = live_map
		app._remove_at_shop(RunShopVisit.new(app.run_deck, app.session_gold, 0), app.shop_remove_button)
		app._remove_at_shop(visit, app.shop_back_button)
		app.session_gold += 1
		var changed_before := _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "gold mismatched with ledger cannot spend")
		app.session_gold -= 1
		app.run_removal_count += 1
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "count mismatched with ledger cannot spend")
		app.run_removal_count -= 1
		app.run_deck.append("warden_strike")
		changed_before = _shop_state()
		remove_callback.call()
		_check(_shop_state() == changed_before, "deck mismatched with ledger cannot spend")
		app.run_deck.pop_back()
		var selected: int = app.shop_cards.selected
		var original_id: String = app.shop_cards.get_item_text(selected)
		var different_id := ""
		for owned in app.run_deck:
			if owned != original_id:
				different_id = owned
				break
		_check(not different_id.is_empty(), "mismatched fixture is a different owned ID")
		for invalid in ["unknown_card", different_id]:
			app.shop_cards.set_item_text(selected, invalid)
			remove_callback.call()
			_check(_shop_state() == before, "unknown or mismatched owned ID cannot spend")
		app.shop_cards.set_item_text(selected, original_id)
		if session in [0, 3]:
			_check(app.session_gold < price, "natural victory gold cannot afford removal")
			await _click(app.shop_remove_button)
			app.shop_remove_button.grab_focus()
			await _key(KEY_ENTER)
			_check(_shop_state() == before and not app.shop_remove_button.disabled
				and app.shop_cards.selected == selected, "insufficient funds retain selection, state and available option")
			if session == 0:
				replay = before.duplicate(true)
			else:
				_check(before == replay, "same-seed restart reproduces complete combat, inventory, ledger, route and RNG")
		else:
			# Later duplicate: every owned occurrence has its own sewn tile.
			var duplicate_index := -1
			for index in range(1, app.run_deck.size()):
				if app.run_deck[index] == app.run_deck[0]:
					duplicate_index = index
			_check(duplicate_index > 0, "owned fixture contains duplicate copies")
			if duplicate_index < 0:
				break
			var duplicate_tile = _tile_for("removal", duplicate_index)
			before = _shop_state()
			if session == 1:
				await _click_tile(duplicate_tile)
			else:
				await _select_tile_by_key(duplicate_tile)
			_check(app.shop_cards.selected == duplicate_index,
				"physical tile input chooses the later duplicate occurrence")
			_check(_shop_state() == before, "choosing the later duplicate spends nothing")
			_check(gallery.tile_details(duplicate_tile).selected,
				"the chosen owned occurrence is visibly selected")
			var expected_deck: Array = app.run_deck.duplicate()
			expected_deck.remove_at(0)
			var gold: int = app.session_gold
			var count: int = app.run_removal_count
			if session == 1:
				await _click(app.shop_remove_button)
			else:
				duplicate_tile.grab_focus()
				var reach: int = gallery.removal_tiles().size() + 3
				for step in range(reach):
					if app.shop_remove_button.has_focus():
						break
					await _key(KEY_TAB)
				_check(app.shop_remove_button.has_focus(), "Tab reaches Remove from the owned-card tiles")
				await _key(KEY_ENTER)
			_check(app.run_deck == expected_deck and app.session_gold == gold - price
				and app.run_removal_count == count + 1, "funded input removes FIRST duplicate and charges exact quote once")
			_check(visit.get_state().deck == expected_deck and visit.get_state().gold == app.session_gold
				and visit.get_state().prior_removals == count + 1 and app.shop_remove_button.disabled,
				"run mirrors used ledger exactly and disables removal")
			await _frames()
			_check(gallery.removal_tiles().all(func(tile): return tile.disabled),
				"every owned-card tile disables with the spent Shop removal")
			var after := _shop_state()
			remove_callback.call()
			app.shop_remove_button.pressed.emit()
			await _click(app.shop_remove_button)
			_check(_shop_state() == after, "repeat mouse and retained callback cannot remove or charge twice")
			_check(after[0][0] == before[0][0] and after[0][3] == before[0][3]
				and after[0][4] == before[0][4], "removal preserves heroes, seeded RNG and route")
		var tile_callback: Callable = gallery.offer_tiles()[0].pressed.get_connections()[0].callable
		stale = [route_callback, back_callback, remove_callback, tile_callback,
			app.shop_continue_button.pressed.get_connections()[0].callable,
			app.shop_back_button.pressed.get_connections()[0].callable]
		if session % 2 == 0:
			app.shop_back_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(app.shop_back_button)
		_check(app.visit_backdrop == null and not is_instance_id_valid(bed_id),
			"Return releases the Shop art bed with its visit")
		for callback in stale:
			callback.call()
		_check(visit.get_state().status == "closed" and app.title_view.visible and app.shop_visit == null
			and app.shop_view == null and app.shop_cards == null and app.shop_remove_button == null
			and app.shop_back_button == null and app.run_map == null and app.run_deck.is_empty()
			and app.shop_continue_button == null
			and app.shop_purchases == null and app.shop_offers == null and app.shop_buy_button == null
			and app.session_gold == 0 and app.run_removal_count == 0, "skip/Return closes ledger, clears run and rejects stale inputs")
		_check(not gallery.is_gallery_mounted() and not is_instance_valid(gallery.gallery_panel())
			and gallery.offer_tiles().is_empty() and gallery.removal_tiles().is_empty()
			and gallery.gallery_kind() == "",
			"Return discards the Shop gallery, its tiles and its callbacks")
		_check(randi() == global_next, "complete physical route/Shop leaves global RNG untouched")
	_finish_shop()


func _finish_shop() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
