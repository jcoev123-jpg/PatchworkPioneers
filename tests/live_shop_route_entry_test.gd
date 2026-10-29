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
	"seamstress_mend": "Heal ally 5 HP.",
	"seamstress_stitch_up": "Ally gains 5 Block.",
	"tinker_pop_shot": "Deal 5.",
	"tinker_scrap_bomb": "Deal 4 to all.",
	"tinker_tune_up": "Draw 1.",
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
	var cards: Array = []
	var catalogs: Array = RunShopStockOffers._peddler_catalogs()
	for hero in app.run_heroes:
		var pool: Array = []
		for candidate in authored.cards:
			var found: Dictionary = RunShopStockOffers._find_card_definition(
				str(candidate.id), catalogs)
			var authored_owner: String = str(found.get("def", {}).get("owner", ""))
			if authored_owner == hero.id:
				pool.append(candidate.id)
		pool.sort()
		_check(not pool.is_empty(), "independent per-hero stock oracle has candidates")
		var chosen: String = pool[rng.randi_range(0, pool.size() - 1)]
		var quote: Dictionary = authored.cards.filter(func(c): return c.id == chosen)[0]
		cards.append({"id": chosen, "owner": hero.id, "price": int(quote.price), "sold": false})
	var patches: Array = []
	# The Peddler prices only authored POWER patches: the inert starter-slot
	# records shipped beside them are never a payable offer.
	var power_ids := {}
	for definition in RunAuthoredPatchDefinitions.load_power_definitions():
		if definition is Dictionary and definition.get("id") is String:
			power_ids[definition["id"]] = true
	for candidate in authored.trinkets:
		if power_ids.has(candidate.id) and not app.run_trinkets.has(candidate.id):
			patches.append(candidate.id)
	if patches.is_empty():
		for candidate in authored.trinkets:
			if power_ids.has(candidate.id):
				patches.append(candidate.id)
	patches.sort()
	_check(not patches.is_empty(), "independent patch oracle has authored power candidates")
	var tickets: Array[String] = []
	for patch_id in patches:
		for ticket in range(10 if patch_id in ["relay_bobbin", "hearth_lining"] else 100):
			tickets.append(patch_id)
	var chosen: String = tickets[rng.randi_range(0, tickets.size() - 1)]
	var quote: Dictionary = authored.trinkets.filter(func(c): return c.id == chosen)[0]
	return {"stock": {"cards": cards, "trinkets": [{"id": chosen,
		"price": int(quote.price), "sold": app.run_trinkets.has(chosen)}]}, "state": rng.state}


## Pick a reproducible genuine Shop RNG state for one mounted keyword-tooltip
## session. Other sessions keep the uninterrupted combat-to-Shop RNG sequence.
func _keyword_shop_state() -> int:
	var authored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	var owners: Array[String] = []
	for hero in app.run_heroes:
		owners.append(hero.id)
	for value in range(1, 256):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var opening_state: int = rng.state
		var result := RunShopStockOffers.generate(rng, owners, authored.cards, authored.trinkets, [])
		if not result.get("ok", false) or result.cards.size() != 5 or result.trinkets.size() != 2:
			continue
		if result.trinkets[0].id == result.trinkets[1].id:
			continue
		for offer in result.cards:
			var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(String(offer.id))
			var effects: Dictionary = definition.get("effects", {})
			if effects.has("pinned") or effects.has("unravel") or _unravel_conditional(effects):
				return opening_state
	return -1

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
	return [app._sewing_context(), app.act_outcome.get_state(),
		app.peddler_visit.read_state() if app.peddler_visit != null else {},
		app._peddler_wardrobe.get_snapshot() if app._peddler_wardrobe != null else {},
		app.peddler_receipt.duplicate(true), app._peddler_witnesses.duplicate(true)]


## The one passive gallery scene child that mounts sewn tiles beside a visit.
func _visit_tiles():
	return app.get_node("LiveVisitCardTiles")


## The master faces the shared theme gives body and heading labels.
const BODY_FACE_PATH := "res://assets/fonts/PatrickHand-Regular.ttf"
const HEADING_FACE_PATH := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## Developer wording the player-facing visit gallery must never show.
const RETIRED_GALLERY_TEXT: Array[String] = ["CARD GALLERY", "Select only",
	"own button", "commit"]
## The Shop gallery's neutral guidance, shown on a fresh visit and whenever the
## previous pick is no longer a live card-for-sale offer.
const SHOP_GALLERY_GUIDANCE := "Choose a card, then press Buy or Remove."


## The face a mounted label actually resolves, looking through the code-drawn
## arrow FontVariation to its own base font.
func _label_face_path(label: Label) -> String:
	if not is_instance_valid(label):
		return ""
	var font: Font = label.get_theme_font("font")
	while font is FontVariation and (font as FontVariation).base_font != null:
		font = (font as FontVariation).base_font
	return font.resource_path if font != null else ""


## Every player-facing string the mounted gallery currently shows, joined for
## wording audits of titles, hints, sections and empty states.
func _gallery_text(panel: Control) -> String:
	var texts := PackedStringArray()
	for node in panel.find_children("*", "Label", true, false):
		if node is Label and node.is_visible_in_tree():
			texts.append((node as Label).text)
	return "\n".join(texts)


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


## Real mounted direction-key traversal: focus only, scroll and sewn focus ink,
## no OptionButton signal, ledger action, route change or RNG draw.
func _check_shop_direction_keys(gallery) -> void:
	var offers: Array[Button] = gallery.offer_tiles()
	var owned: Array[Button] = gallery.removal_tiles()
	_check(gallery.is_gallery_mounted() and offers.size() >= 4 and owned.size() >= 4,
		"direction-key Shop fixture has both mounted multi-card groups")
	if offers.size() < 4 or owned.size() < 4:
		return
	var before := _shop_state()
	var selections := [app.shop_offers.selected, app.shop_cards.selected]
	var signals := [0, 0]
	app.shop_offers.item_selected.connect(func(_row: int): signals[0] += 1)
	app.shop_cards.item_selected.connect(func(_row: int): signals[1] += 1)
	var scroll: ScrollContainer = gallery.gallery_scroll()
	offers[0].grab_focus()
	await _frames()
	var stitch = offers[0].get_node_or_null("FocusStitch")
	_check(offers[0].has_focus() and stitch != null and stitch.is_stitching()
		and Rect2(Vector2.ZERO, offers[0].size).encloses(stitch.perimeter_rect()),
		"first mounted Shop tile paints its inset sewn keyboard focus perimeter")
	await _key(KEY_UP)
	_check(offers[0].has_focus(), "Up at first sale tile stays in its group")
	await _key(KEY_DOWN)
	_check(offers[1].has_focus(), "Down focuses next sale tile without selecting it")
	await _key(KEY_RIGHT)
	_check(owned[1].has_focus(), "Right moves to corresponding enabled removal row")
	await _key(KEY_DOWN)
	_check(owned[2].has_focus(), "Down focuses next removal tile")
	await _key(KEY_LEFT)
	_check(offers[2].has_focus(), "Left returns to the nearest corresponding sale row")
	await _key(KEY_LEFT)
	_check(offers[2].has_focus(), "Left at sale edge cannot escape into an action")
	await _key(KEY_RIGHT)
	_check(owned[2].has_focus(), "Right can cross the sections repeatedly")
	owned.back().grab_focus()
	await _frames()
	_check(scroll.scroll_vertical > 0
		and scroll.get_global_rect().encloses(owned.back().get_global_rect())
		and owned.back().get_node("FocusStitch").is_stitching(),
		"focusing the last owned card scrolls its whole sewn focus frame into view")
	await _key(KEY_DOWN)
	_check(owned.back().has_focus(), "Down at removal edge does not wrap or exit")
	await _key(KEY_LEFT)
	var corresponding: int = mini(owned.size() - 1, offers.size() - 1)
	_check(offers[corresponding].has_focus(),
		"Left from a deeper owned row chooses nearest enabled sale row")
	offers[0].grab_focus()
	app.shop_offers.set_item_disabled(1, true)
	await _frames()
	await _key(KEY_DOWN)
	_check(offers[2].has_focus() and offers[1].disabled,
		"Down skips a disabled sale row without selecting it")
	app.shop_offers.set_item_disabled(1, false)
	await _frames()
	_check(_shop_state() == before
		and [app.shop_offers.selected, app.shop_cards.selected] == selections
		and signals == [0, 0],
		"all arrows, edges and disabled skips preserve selectors, gold, deck, route and RNG")
	var target := offers[2]
	_check(target.has_focus() and not gallery.tile_details(target).selected,
		"keyboard focus and SELECTED ink are separate states")
	await _key(KEY_SPACE)
	_check(app.shop_offers.selected == 2 and signals == [1, 0]
		and _shop_state() == before and gallery.tile_details(target).selected,
		"Space selects focused Shop row exactly once via OptionButton with no payment")


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
	var backing := bed.get_node_or_null("ShopActionBacking") as Panel
	_check(backing != null and bed.find_children("ShopActionBacking", "Panel", true, false).size() == 1,
		"real Shop mounts exactly one named action rail backing")
	if backing != null:
		var rect := backing.get_global_rect()
		var rail: Rect2 = app.shop_view.get_global_rect()
		var surface := backing.get_theme_stylebox("panel") as StyleBoxFlat
		_check(surface != null and surface.draw_center and surface.bg_color.a == 1.0
			and surface.bg_color == app.get_theme_stylebox("panel", "PanelContainer").bg_color
			and backing.get_node_or_null("RailStitches") != null,
			"rail uses opaque installed felt style with the shell's stitched edge")
		_check(backing.is_visible_in_tree() and rect.is_equal_approx(rail.grow(10.0))
			and Rect2(0, 0, 1280, 720).encloses(rect),
			"compact backing follows the laid-out rail inside the viewport")
		for control in [app.shop_view.get_node("ShopTitle"), app.shop_label,
				app.shop_buy_button, app.shop_remove_button, app.shop_patch_preview,
				app.peddler_leave_button, app.shop_back_button]:
			_check(control.is_visible_in_tree() and rect.encloses(control.get_global_rect()),
				"opaque rail covers every exposed title, wallet, action and preview")
		var gallery: Control = _visit_tiles().gallery_panel()
		_check(is_instance_valid(gallery) and gallery.is_visible_in_tree()
			and not rect.intersects(gallery.get_global_rect()) and rect.size.x < 1280.0 * 0.65,
			"stall art and right gallery remain outside the compact rail backing")
		for decoration in [backing, backing.get_node("RailStitches")]:
			_check(decoration.mouse_filter == Control.MOUSE_FILTER_IGNORE
				and decoration.focus_mode == Control.FOCUS_NONE,
				"rail and stitches capture neither pointer nor keyboard focus")
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


## AC1/AC2: the mounted Shop gallery speaks in-world, names its Buy/Remove
## directions, wears the master heading face on every heading and keeps the
## body face readable for tile metadata and effects.
func _check_shop_gallery_labels(gallery) -> void:
	var panel: Control = gallery.gallery_panel()
	var title := panel.find_child("GalleryTitle", true, false) as Label
	var hint := panel.find_child("GalleryHint", true, false) as Label
	_check(title != null and title.is_visible_in_tree() and title.text == "Shop · Sewn cards",
		"mounted Shop gallery title names the Shop and its sewn cards")
	_check(title != null and title.theme_type_variation == "PatchHeading"
		and _label_face_path(title) == HEADING_FACE_PATH,
		"mounted Shop gallery title wears the master PatchHeading face")
	_check(hint != null and hint.is_visible_in_tree()
		and hint.text == SHOP_GALLERY_GUIDANCE
		and hint.text.contains("Buy") and hint.text.contains("Remove")
		and not hint.text.contains("gold")
		and _label_face_path(hint) == BODY_FACE_PATH,
		"mounted Shop gallery hint tells the player to choose a card and press Buy or Remove")
	var headings: Array = panel.find_children("GallerySectionHeading*", "Label", true, false)
	var heading_texts: Array[String] = []
	for node in headings:
		var label := node as Label
		heading_texts.append(label.text)
		_check(label.theme_type_variation == "PatchHeading"
			and _label_face_path(label) == HEADING_FACE_PATH
			and label.is_visible_in_tree(),
			"every Shop section heading wears the master PatchHeading face: " + label.text)
	_check(heading_texts == ["Cards for sale", "Remove a card"],
		"mounted Shop sections name both in-world actions")
	var section_hints: Array = panel.find_children("GallerySectionHint*", "Label", true, false)
	_check(section_hints.size() == 2
		and (section_hints[0] as Label).text.contains("Buy")
		and (section_hints[1] as Label).text.contains("Remove")
		and section_hints.all(func(node): return _label_face_path(node) == BODY_FACE_PATH),
		"mounted Shop section hints direct Buy and Remove in the body face")
	var shown := _gallery_text(panel)
	_check(RETIRED_GALLERY_TEXT.all(func(token): return not shown.contains(token)),
		"mounted Shop gallery drops developer wording from titles, hints and empty states")
	var all_tiles: Array = gallery.offer_tiles()
	all_tiles.append_array(gallery.removal_tiles())
	for tile in all_tiles:
		var face_panel: Control = tile.get_parent()
		var name_label := face_panel.find_child("TileName", true, false) as Label
		var meta_label := face_panel.find_child("TileMeta", true, false) as Label
		var effects_label := face_panel.find_child("TileEffects", true, false) as Label
		_check(name_label != null and name_label.theme_type_variation == "PatchHeading"
			and _label_face_path(name_label) == HEADING_FACE_PATH,
			"every Shop card name wears the master PatchHeading face")
		_check(meta_label != null and _label_face_path(meta_label) == BODY_FACE_PATH
			and meta_label.get_theme_font_size("font_size") >= 15
			and face_panel.get_global_rect().encloses(meta_label.get_global_rect()),
			"every Shop tile keeps its body-face metadata at 15 px or more")
		_check(effects_label != null and _label_face_path(effects_label) == BODY_FACE_PATH
			and effects_label.get_theme_font_size("font_size") >= 16
			and face_panel.get_global_rect().encloses(effects_label.get_global_rect()),
			"every Shop tile keeps its body-face effects at 16 px or more")


## The mounted sewn hint under the Shop title.
func _gallery_hint(gallery) -> Label:
	var panel: Control = gallery.gallery_panel()
	return panel.find_child("GalleryHint", true, false) as Label


## Independent wallet-consequence oracle for one published listing: the authored
## catalog name plus the visit's own quoted price and the run's current gold,
## formatted here rather than by the presenter that produced the hint.
func _offer_hint_oracle(listing: Dictionary, gold: int) -> String:
	var definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(String(listing.id))
	var card_name: String = String(definition.get("display_name", ""))
	var price: int = int(listing.price)
	if gold >= price:
		return card_name + " — " + str(price) + " gold; " + str(gold - price) \
			+ " gold left after Buy"
	return card_name + " — " + str(price) + " gold; you have " + str(gold) + ", " \
		+ str(price - gold) + " short"


## AC1/AC2/AC3: the sewn GalleryHint is a selection receipt for the real Shop.
## A click and a keyboard activation each name the picked sale card, its actual
## quoted price and the true wallet outcome while spending nothing; a removal
## pick and a fresh visit drop back to the neutral guidance. The genuine Buy
## commit is checked separately, after the inventory-facing checks.
func _check_offer_hint(gallery) -> void:
	var hint := _gallery_hint(gallery)
	_check(hint != null and hint.is_visible_in_tree() and _label_face_path(hint) == BODY_FACE_PATH
		and hint.get_theme_font_size("font_size") >= 15,
		"mounted Shop hint is a readable body-face label")
	if hint == null:
		return
	var stock: Array = app.shop_purchases.get_stock().cards
	var gold: int = app.session_gold
	_check(gallery.offer_tiles().size() == stock.size() and stock.size() == 5,
		"hint fixture compares every published listing against a mounted sale tile")
	_check(hint.text == SHOP_GALLERY_GUIDANCE,
		"a newly mounted Shop visit shows neutral guidance instead of a stale offer synopsis")
	var before := _shop_state()
	var persistent := _persistent()
	for index in range(stock.size()):
		var tile = _tile_for("offer", index)
		if index % 2 == 0:
			await _click_tile(tile)
		else:
			await _select_tile_by_key(tile)
		_check(app.shop_offers.selected == index and gallery.tile_details(tile).selected,
			"tile input selects the published sale row %d" % index)
		_check(hint.text == _offer_hint_oracle(stock[index], gold),
			"hint names row %d's authored card, quoted price and exact wallet outcome" % index)
		_check(_shop_state() == before and _persistent() == persistent,
			"selecting sale row %d changes no gold, deck, stock, route or RNG" % index)
	# A sold or otherwise non-offer row cannot keep a Buy synopsis alive.
	var removal_before := _shop_state()
	await _click_tile(_tile_for("removal", 0))
	_check(app.shop_cards.selected == 0 and _shop_state() == removal_before,
		"a real removal-tile pick selects that owned copy and spends nothing")
	_check(hint.text == SHOP_GALLERY_GUIDANCE
		and not hint.text.contains("left after Buy") and not hint.text.contains("short"),
		"a removal pick replaces the old Buy synopsis with the neutral Shop guidance")


## AC1/AC2/AC3: only the genuine Buy control settles a sale. Once it does, that
## sold listing loses its offer synopsis, disables, and cannot be revived by its
## old tile callback; gold, deck and the visit ledger move exactly once.
func _check_offer_purchase_hint(gallery) -> void:
	var hint := _gallery_hint(gallery)
	_check(hint != null, "the purchase check has a mounted Shop hint")
	if hint == null:
		return
	var stock: Array = app.shop_purchases.get_stock().cards
	var gold: int = app.session_gold
	var target := -1
	for index in range(stock.size()):
		if not stock[index].sold and gold >= int(stock[index].price):
			target = index
			break
	_check(target >= 0, "this session has an unsold listing the wallet can afford")
	if target < 0:
		return
	var purchased_tile = _tile_for("offer", target)
	_check(purchased_tile != null and not purchased_tile.disabled,
		"the affordable listing has an enabled sale tile")
	if purchased_tile == null:
		return
	await _click_tile(purchased_tile)
	_check(hint.text == _offer_hint_oracle(stock[target], gold),
		"the affordable selection previews its post-Buy wallet before any payment")
	var stale_tile_callback: Callable = purchased_tile.pressed.get_connections()[0].callable
	var visit: RunShopVisit = app.shop_visit
	var deck_before: Array = app.run_deck.duplicate()
	var stock_before: Array = app.shop_purchases.get_stock().cards.duplicate(true)
	var route_before: Array = app.run_map.get_route().duplicate()
	var rng_before: int = app.run_rng.state
	var card_id: String = String(stock[target].id)
	var price: int = int(stock[target].price)
	var expected_deck: Array = deck_before.duplicate()
	expected_deck.append(card_id)
	_check(not app.shop_buy_button.disabled, "an affordable selection leaves the existing Buy control enabled")
	await _click(app.shop_buy_button)
	_check(app.session_gold == gold - price and app.run_deck == expected_deck,
		"the existing Buy control alone charges the quoted price once and adds the card")
	_check(app.run_map.get_route() == route_before and app.run_rng.state == rng_before
		and visit.get_state().deck == app.run_deck and visit.get_state().gold == app.session_gold
		and app.shop_purchases.get_state().deck == app.run_deck,
		"the single purchase settles the visit ledger and leaves route and run RNG untouched")
	var stock_after: Array = app.shop_purchases.get_stock().cards
	_check(stock_after[target].sold and stock_before[target].sold == false
		and app.shop_offers.selected == target and app.shop_buy_button.disabled,
		"the settled listing is marked sold and its Buy control disables")
	_check(hint.text == SHOP_GALLERY_GUIDANCE,
		"a sold listing drops the old Buy synopsis back to neutral guidance")
	var sold_tile = _tile_for("offer", target)
	var sold_definition: Dictionary = RunPoolCardRewardOffers.resolve_reward_definition(card_id)
	_check(sold_tile != null and sold_tile.disabled
		and gallery.tile_details(sold_tile).title == String(sold_definition.get("display_name", card_id)),
		"the sold listing keeps its authored tile but disables it")
	if sold_tile == null:
		return
	sold_tile.pressed.emit()
	await _frames()
	_check(hint.text == SHOP_GALLERY_GUIDANCE and app.shop_offers.selected == target
		and app.session_gold == gold - price,
		"the sold tile cannot reselect itself or announce a second purchase")
	var after_buy := _shop_state()
	stale_tile_callback.call()
	await _frames()
	_check(_shop_state() == after_buy and hint.text == SHOP_GALLERY_GUIDANCE,
		"the pre-purchase tile callback cannot revive the sold synopsis or spend again")


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
	var retired_backing_id := 0
	# Normal insufficient funds, funded mouse, funded keyboard with escalated quote,
	# and same-seed normal restart/skip.
	for session in range(5):
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
			_retained_call(callback)
		_check(_persistent() == before and app.peddler_visit == null, "old visit callbacks cannot spend or reopen in fresh combat")
		await _click(app.continue_button)
		var shop: Button
		var shown: Array[String] = []
		before = _persistent()
		for button in app.route_buttons:
			var id: String = button.get_meta("route_id")
			var kind: String = app.run_map.get_node(id).type
			shown.append(id)
			_check(button.disabled == (kind not in ["Rest", "Shop", "Event", "Treasure", "SewingCircle", "Campfire", "PatchStall", "Fight", "Elite", "Boss"]), "only supported connected controls enabled")
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
		_check(_persistent() == before and app.peddler_visit == null, "wrong identity, ID, route, disabled button and node type reject")
		var saved_gold: int = app.session_gold
		app.session_gold = -1
		var invalid_before := _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.peddler_visit == null, "invalid ledger cannot commit a route choice")
		app.session_gold = saved_gold
		var saved_rng: RandomNumberGenerator = app.run_rng
		app.run_rng = null
		var missing_before := [app.run_heroes.duplicate(true), app.run_deck.duplicate(), app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()]
		route_callback.call()
		_check(app.run_rng == null and app.peddler_visit == null and app.shop_purchases == null
			and missing_before == [app.run_heroes, app.run_deck, app.session_gold,
			app.run_removal_count, app.run_map.get_floors(), app.run_map.get_route()], "absent RNG rejects without partial entry")
		app.run_rng = saved_rng
		# Published roster drift now fails before entering another run node.
		var heroes: Array = app.run_heroes.duplicate(true)
		app.run_heroes[0].id = "unknown_shop_owner"
		_check(not app._can_choose_connected_route(), "published roster drift fails carryover admission")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.peddler_visit == null, "roster drift cannot advance route or consume RNG")
		# Align the held fixture too so the original stock rejection remains reachable.
		app.party_carryover._heroes[0].id = "unknown_shop_owner"
		_check(app._can_choose_connected_route(), "unknown catalog owner passes roster admission before stock rejection")
		invalid_before = _persistent()
		route_callback.call()
		_check(_persistent() == invalid_before and app.peddler_visit == null and app.shop_purchases == null,
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
		_check(_persistent() == invalid_before and app.peddler_visit == null and app.shop_purchases == null,
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
			and original_map.get_node(" ").type == "Shop" and _stock_oracle().stock.cards.size() == 3,
			"whitespace fixture admits connected Shop with valid generated stock before visit opening")
		invalid_before = _persistent()
		_check(not app._choose_shop_route(" ", weakref(original_map), prior, shop), "visit opening rejects whitespace ID")
		_check(_persistent() == invalid_before and app.peddler_visit == null and app.shop_purchases == null,
			"failed visit opening rolls back committed map and generated RNG")
		original_map._nodes.erase(" ")
		original_map._nodes[parent].outgoing = outgoing
		app._carryover_floors = original_map.get_floors()
		shop.set_meta("route_id", id)
		if session in [1, 2]:
			app.session_gold = 200
		var oracle := _stock_oracle()
		if session == 2:
			shop.grab_focus()
			await _key(KEY_ENTER)
		else:
			await _click(shop)
		_check(app.peddler_visit != null and is_instance_valid(app.shop_view), "physical Shop opens authoritative Peddler")
		if app.peddler_visit == null or not is_instance_valid(app.shop_view):
			break
		var visit: RunPeddlerVisit = app.peddler_visit
		var bound := visit.read_state()
		_check(bound.stock == oracle.stock and app.run_rng.state == oracle.state,
			"three per-owner sorted draws and one sorted patch draw match independent oracle")
		_check(bound.state.deck == app.run_deck and bound.state.gold == app.session_gold
			and bound.node_id == id and bound.status == RunPeddlerVisit.OPEN,
			"one real node and complete inventory bind authentic service")
		_check(app.peddler_buttons.size() == 4 and app.shop_cards == null and app.shop_remove_button == null
			and app.shop_visit == null and app.shop_purchases == null,
			"four choices replace retired routed removal and duplicate purchase authorities")
		_check(app.shop_view is LivePeddlerPanel and app.shop_view._visit == visit
			and app.shop_view.intent_requested.get_connections().size() == 1,
			"one sewn panel binds the real visit and one controller intent bridge")
		var wearer_label := app.shop_view.get_node_or_null("PatchWearerLabel") as Label
		_check(wearer_label != null and wearer_label.is_visible_in_tree()
			and wearer_label.text == "Patch wearer"
			and wearer_label.get_theme_font_size("font_size") == 20
			and wearer_label.get_theme_color("font_color") == LivePeddlerPanel.CREAM
			and wearer_label.get_theme_font("font") == app.shop_view.get_theme_font("font"),
			"mounted selector has a readable label in the panel's sewn theme")
		_check(app.peddler_heroes.get_parent() == app.shop_view and app.peddler_heroes.item_count == 3,
			"wearer selector mounts the genuine three-member party")
		for i in range(app.peddler_heroes.item_count):
			_check(app.peddler_heroes.get_item_text(i) == String(app.run_heroes[i].id).capitalize()
				and app.peddler_heroes.get_item_metadata(i) == app.run_heroes[i].id,
				"wearer labels and metadata retain authentic party order and IDs")
		var controls: Array = app.peddler_buttons.slice(0, 3) + [app.peddler_heroes,
			app.peddler_buttons[3], app.peddler_leave_button]
		for control in controls:
			_check(control.is_visible_in_tree() and Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()),
				"each real choice fits viewport")
		var navigation_before := _shop_state()
		var enabled: Array = controls.filter(func(control): return not control.disabled)
		enabled[0].grab_focus()
		for control in enabled:
			_check(control.has_focus(), "Tab reaches every enabled Peddler action in displayed order")
			await _key(KEY_TAB)
		_check(enabled[0].has_focus() and _shop_state() == navigation_before,
			"Peddler focus wraps without spending or changing RNG")
		for i in range(4):
			var offer: Dictionary = (bound.stock.cards + bound.stock.trinkets)[i]
			var action: Button = app.peddler_buttons[i]
			var prefix: String = str(offer.owner).capitalize() if i < 3 else "PATCH"
			var expected := "%s  ·  %s  ·  %d gold" % [prefix,
				str(offer.id).replace("_", " ").capitalize(), offer.price]
			if offer.sold:
				expected += "  ·  SOLD"
			elif app.session_gold < offer.price:
				expected += "  ·  short %d" % (offer.price - app.session_gold)
			var display_ok := action.text == expected
			var expected_font := 20
			if i < 3:
				# The routed, real panel now prints the independent catalog's
				# name/energy/effect on two measured lines, preserving the
				# quoted price and the complete tooltip rather than a bare ID.
				expected_font = 20
				var found := RunShopStockOffers._find_card_definition(String(offer.id),
						RunShopStockOffers._peddler_catalogs())
				var definition: Dictionary = found.get("def", {})
				var described := CardShortRules.describe(definition)
				var lines := action.text.split("\n")
				var font := action.get_theme_font("font")
				display_ok = not definition.is_empty() and definition.get("id") == offer.id
				display_ok = display_ok and definition.get("owner") == offer.owner
				display_ok = display_ok and described.get("known") == true and lines.size() == 2
				if display_ok:
					var name := str(definition.get("display_name", "")).strip_edges()
					if name.is_empty():
						name = str(offer.id).replace("_", " ").capitalize()
					var gold_suffix := "  ·  %d gold" % int(offer.price)
					if offer.sold:
						gold_suffix += "  ·  SOLD"
					elif app.session_gold < offer.price:
						gold_suffix += "  ·  short %d" % (offer.price - app.session_gold)
					var start := prefix + "  ·  "
					var actual_name := lines[0].substr(start.length(),
							lines[0].length() - start.length() - gold_suffix.length())
					var rule := String(described.get("line", ""))
					var energy := "%d energy  ·  " % int(definition.get("cost", -1))
					var effect := lines[1].substr(energy.length()) if lines[1].begins_with(energy) else ""
					display_ok = lines[0].begins_with(start) and lines[0].ends_with(gold_suffix)
					display_ok = display_ok and (actual_name == name or
							(actual_name.ends_with(LivePeddlerPanel.ELLIPSIS) and
							name.begins_with(actual_name.trim_suffix(LivePeddlerPanel.ELLIPSIS).strip_edges())))
					display_ok = display_ok and not rule.is_empty() and lines[1].begins_with(energy)
					display_ok = display_ok and (effect == rule or
							(effect.ends_with(LivePeddlerPanel.ELLIPSIS) and
							effect.contains(rule.get_slice(" ", 0))))
					display_ok = display_ok and action.tooltip_text.contains(String(offer.id))
					display_ok = display_ok and action.tooltip_text.contains(rule)
					display_ok = display_ok and font != null and action.size == Vector2(822, 78)
					if font != null:
						for line in lines:
							display_ok = display_ok and font.get_string_size(line,
									HORIZONTAL_ALIGNMENT_LEFT, -1, expected_font).x <= action.size.x - 32
			else:
				# The patch also has two sewn lines now: the unchanged exact
				# quoted price, then the independently audited slot/power. Do
				# not compare the whole Button to the retired one-line caption.
				var slots := {}
				for record in RunAuthoredPatchDefinitions.load_power_definitions():
					if record is Dictionary and record.get("id") is String and record.get("slot") is String:
						slots[record["id"]] = record["slot"]
				var stall := LivePatchStallPanel.new()
				var trusted: Dictionary = stall._trusted_power_previews(slots)
				stall.free()
				var patch_lines := action.text.split("\n")
				var rule: Dictionary = trusted.get(str(offer.id), {})
				var slot: String = str(slots.get(str(offer.id), ""))
				display_ok = patch_lines.size() == 2 and not slot.is_empty() and not rule.is_empty()
				if display_ok:
					var header := slot + "  ·  "
					var displayed := patch_lines[1].trim_prefix(header)
					var short_rule: String = str(rule.get("short", ""))
					var font := action.get_theme_font("font")
					display_ok = patch_lines[0] == expected and patch_lines[1].begins_with(header)
					# A shortened row is allowed only when the complete audited
					# rule remains intact in this same button's tooltip.
					display_ok = display_ok and not short_rule.is_empty() and (
						displayed == short_rule or (displayed.ends_with(LivePeddlerPanel.ELLIPSIS)
						and short_rule.begins_with(displayed.trim_suffix(LivePeddlerPanel.ELLIPSIS).strip_edges())))
					display_ok = display_ok and (
						action.tooltip_text.contains(str(rule.get("full", "")))
						and action.tooltip_text.contains(str(offer.id)) and action.tooltip_text.contains(slot)
						and action.tooltip_text.contains("%d gold" % int(offer.price)))
					# The live wearer selector shares this row, leaving a narrower
					# action than the three full-width card buttons.
					display_ok = display_ok and font != null and action.size.y == 78 and action.size.x > 32
					if font != null:
						for line in patch_lines:
							display_ok = display_ok and font.get_string_size(line,
									HORIZONTAL_ALIGNMENT_LEFT, -1, expected_font).x <= action.size.x - 32
			_check(display_ok and not action.text.contains(str(offer.id))
				and not action.text.contains("_")
				and action.get_parent() == app.shop_view
				and action.get_meta("offer_id") == offer.id and action.pressed.get_connections().size() == 1
				and action.get_theme_font_size("font_size") == expected_font
				and action.disabled == (offer.sold or app.session_gold < offer.price),
				"each routed sewn choice displays authentic name, price, energy and ability (row %d; text=%s; expected=%s; display=%s)" % [i, action.text.replace("\n", " / "), expected, str(display_ok)])
		# The live mounted panel explains a real hovered offer from its own
		# authored record before the player spends anything. Read-only: the
		# ledger, visit and RNG stay exactly as the Shop left them.
		var live_offer: Dictionary = bound.stock.cards[0]
		var live_found := RunShopStockOffers._find_card_definition(String(live_offer.id),
				RunShopStockOffers._peddler_catalogs())
		var live_definition: Dictionary = live_found.get("def", {})
		var live_line := CardShortRules.line(live_definition)
		var live_caption: String = app.peddler_buttons[0].text
		await _hover(app.peddler_buttons[0])
		_check(not live_definition.is_empty() and not live_line.is_empty()
			and app.shop_view.status_label.text.contains(String(live_offer.id))
			and app.shop_view.status_label.text.contains(
				"%d energy" % int(live_definition.get("cost", -1)))
			and app.shop_view.status_label.text.contains(live_line)
			and app.peddler_buttons[0].text == live_caption
			and _shop_state() == navigation_before,
			"live mounted Peddler previews the hovered offer's authored ability without changing the shop")
		var leave: Callable = app.peddler_leave_button.pressed.get_connections()[0].callable
		var buys: Array[Callable] = []
		for action in app.peddler_buttons:
			buys.append(action.pressed.get_connections()[0].callable)
		await _peddler_rejections(buys + [leave])
		var unchanged := _shop_state()
		if session in [0, 3]:
			for callback in buys:
				callback.call()
			_check(_shop_state() == unchanged, "short wallet refuses every buy without RNG or ledger changes")
			if session == 0:
				replay = [bound, app.run_rng.state, app.run_deck.duplicate(), app.run_heroes.duplicate(true)]
			else:
				_check([bound, app.run_rng.state, app.run_deck, app.run_heroes] == replay, "same seed reproduces entire Peddler stock, wallet, party and RNG")
		var run_before: Dictionary = app._sewing_context()
		var panel: LivePeddlerPanel = app.shop_view
		var panel_ref: WeakRef = weakref(panel)
		var bridge: Callable = panel.intent_requested.get_connections()[0].callable
		var wardrobe: RunPatchWardrobe = app._peddler_wardrobe
		var wardrobe_before := wardrobe.get_snapshot()
		if session == 4:
			app._return_to_title()
			_check(not panel.is_inside_tree() and not panel.visible and panel._visit == null
				and panel.intent_requested.get_connections().is_empty() and panel._pending_intent.is_empty(),
				"title reset detaches an unconsumed panel and erases all submission authority")
			for callback in buys + [leave]:
				_retained_call(callback)
			bridge.call({"kind": "leave"})
			_check(app.peddler_visit == null and app.shop_view == null and app.run_map == null,
				"retained open-visit callbacks cannot resurrect Peddler at title")
			app._start_run()
			preload("res://tests/party_choice.gd").choose(app)
			var fresh := _shop_state()
			bridge.call({"kind": "leave"})
			for callback in buys + [leave]:
				_retained_call(callback)
			_check(_shop_state() == fresh and app.peddler_visit == null,
				"fresh run cannot inherit an unconsumed previous panel or submission")
			app._return_to_title()
			await _frames()
			_check(randi() == global_next, "open-panel title reset and fresh start preserve global RNG")
			continue
		if session == 1:
			var offer: Dictionary = bound.stock.cards[0]
			panel.intent_requested.disconnect(bridge)
			panel.intent_requested.connect(_tampered_peddler_submission.bind(bridge))
			panel.intent_requested.connect(bridge)
			_check(not app.peddler_buttons[0].disabled, "funded genuine card control is enabled")
			await _click(app.peddler_buttons[0])
			var expected_deck: Array = run_before.deck.duplicate()
			expected_deck.append(offer.id)
			_check(visit.is_consumed() and app.peddler_receipt.decision == "buy"
				and app.peddler_receipt.kind == "card" and app.peddler_receipt.id == offer.id
				and app.peddler_receipt.price == offer.price
				and app.session_gold == run_before.gold - offer.price and app.run_deck == expected_deck
				and visit.read_state().state == app.peddler_receipt.state
				and app.run_trinkets == run_before.patches and app.run_scraps == run_before.scraps,
				"physical card purchase commits once at exact quote with authoritative inventory receipt")
		elif session == 2:
			var offer: Dictionary = bound.stock.trinkets[0]
			_check(not app.peddler_buttons[3].disabled, "funded genuine patch control is enabled")
			app.peddler_heroes.grab_focus()
			await _key(KEY_ENTER)
			await _key(KEY_DOWN)
			await _key(KEY_ENTER)
			_check(app.peddler_heroes.selected == 1, "keyboard chooses the middle patch wearer")
			var owner: String = app.run_heroes[1].id
			var slot: String = wardrobe_before.definitions[offer.id]
			var displaced: String = wardrobe_before.worn[owner][slot]
			app.peddler_buttons[3].grab_focus()
			await _key(KEY_ENTER)
			var sewn := wardrobe.get_snapshot()
			var expected_owned: Array = run_before.patches.duplicate()
			expected_owned.append(offer.id)
			if displaced != "":
				expected_owned.erase(displaced)
			_check(visit.is_consumed() and app.peddler_receipt.decision == "buy"
				and app.peddler_receipt.kind == "trinket" and app.peddler_receipt.id == offer.id
				and app.peddler_receipt.price == offer.price
				and app.session_gold == run_before.gold - offer.price and app.run_deck == run_before.deck
				and app.run_trinkets == expected_owned and sewn.worn[owner][slot] == offer.id
				and app.run_scraps == run_before.scraps + (1 if displaced != "" else 0)
				and visit.read_state().state == app.peddler_receipt.state
				and app.peddler_receipt.state.trinkets == expected_owned,
				"physical keyboard patch purchase sews selected wearer and settles exact quote and displaced ownership")
			for other in run_before.heroes:
				if other.id != owner:
					_check(sewn.worn[other.id] == wardrobe_before.worn[other.id], "patch leaves other wearers unchanged")
		else:
			if session == 3:
				app.peddler_leave_button.grab_focus()
				await _key(KEY_ENTER)
			else:
				await _click(app.peddler_leave_button)
			_check(visit.read_state().status == RunPeddlerVisit.LEFT and app.peddler_receipt.decision == "leave"
				and app._sewing_context() == run_before, "mouse and keyboard Leave are free and preserve the entire run")
		_check(app.shop_view == null and app.visit_backdrop == null and panel_ref.get_ref() == null and app._can_choose_connected_route()
			and app._peddler_closed() and not app.route_buttons.is_empty()
			and app.run_rng.state == run_before.rng_state and app.run_map.get_route() == run_before.route,
			"every decision retires panel and art, witnesses the node and exposes legal continuation without RNG draws")
		if session in [1, 2]:
			_check(app.party_carryover._wardrobe == wardrobe
				and app.party_carryover.can_bind_wardrobe(wardrobe, app.party_carryover.torn, wardrobe.get_snapshot())
				and wardrobe.get_snapshot().gold == app.session_gold
				and wardrobe.get_snapshot().cards == app.run_deck
				and wardrobe.get_snapshot().owned == app.run_trinkets,
				"authoritative wardrobe and torn carryover match the committed live receipt")
		var after := _shop_state()
		bridge.call({"kind": "leave"})
		for callback in buys + [leave]:
			_retained_call(callback)
		_check(_shop_state() == after, "retained Buy and Leave reject after consumption")
		stale.assign(buys + [leave, bridge.bind({"kind": "leave"}), route_callback, back_callback])
		if session == 1:
			var next: Button
			for choice in app.route_buttons:
				if not choice.disabled:
					next = choice
					break
			_check(next != null, "settled purchase exposes an enabled genuine next-node action")
			if next != null:
				var next_id: String = next.get_meta("route_id")
				await _click(next)
				_check(app.run_map.get_current_node_id() == next_id and app.run_map.get_route().size() == prior.size() + 2,
					"physical next-node input advances the authentic route after purchase")
				var advanced := _shop_state()
				bridge.call({"kind": "leave"})
				_check(_shop_state() == advanced, "old Peddler bridge stays inert in the next node")
			app._return_to_title()
			await _frames()
		else:
			await _click(app.route_back_button)
		for callback in stale:
			_retained_call(callback)
		_check(app.title_view.visible and app.peddler_visit == null and app.shop_view == null
			and app._peddler_wardrobe == null and app._peddler_witnesses.is_empty()
			and app.run_map == null and app.run_deck.is_empty() and app.session_gold == 0,
			"title reset clears Peddler and witnesses; retired signals cannot revive it")
		_check(randi() == global_next, "Peddler entry, refusal, Leave and title reset preserve global RNG")
	_finish_shop()


func _retained_call(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
	else:
		_check(callback.get_object() == null, "freed panel callbacks have no surviving input receiver")


func _peddler_reject(callbacks: Array, label: String) -> void:
	var before := _shop_state()
	for callback in callbacks:
		callback.call()
	_check(_shop_state() == before and app.peddler_visit.is_open(), label + " rejects atomically and keeps Leave available")


func _peddler_rejections(callbacks: Array) -> void:
	var context: Dictionary = app._sewing_context()
	var map: RunMap = app.run_map
	var rng: RandomNumberGenerator = app.run_rng
	var carry = app.party_carryover
	var panel: LivePeddlerPanel = app.shop_view
	var bridge: Callable = panel.intent_requested.get_connections()[0].callable
	var bound: Dictionary = app.peddler_visit.read_state()
	var before := _shop_state()
	for offer in bound.stock.cards + bound.stock.trinkets + [{"id": "", "leave": true}]:
		var intent := {"node_id": bound.node_id, "kind": "leave" if offer.has("leave") else ("card" if offer.has("owner") else "trinket"),
			"expected_state": bound.state.duplicate(true), "expected_stock": bound.stock.duplicate(true)}
		if not offer.has("leave"):
			intent.id = offer.id
		bridge.call(intent)
		panel.intent_requested.emit(intent)
	_check(_shop_state() == before and not panel._submitted and panel._pending_intent.is_empty(),
		"direct connected-listener calls and forged signals cannot buy or Leave before genuine input")
	app.shop_view.hide()
	_peddler_reject(callbacks, "hidden source")
	app.shop_view.show()
	for action in app.peddler_buttons + [app.peddler_leave_button]:
		var disabled: bool = action.disabled
		action.disabled = true
		_peddler_reject([action.pressed.get_connections()[0].callable], "disabled source")
		action.disabled = disabled
	var action: Button = app.peddler_buttons[0]
	var text := action.text
	var id = action.get_meta("offer_id")
	action.text = "forged price"
	_peddler_reject([callbacks[0]], "forged quote")
	action.text = text
	for invalid in [null, 12, "unknown", app.peddler_visit.read_state().stock.cards[1].id]:
		action.set_meta("offer_id", invalid)
		_peddler_reject([callbacks[0]], "forged offer identity")
	action.set_meta("offer_id", id)
	app.session_gold += 1
	_peddler_reject(callbacks, "drifted wallet")
	app.session_gold -= 1
	app.run_removal_count += 1
	_peddler_reject(callbacks, "drifted removal history")
	app.run_removal_count -= 1
	app.run_deck.append("warden_strike")
	_peddler_reject(callbacks, "drifted ordered deck")
	app.run_deck.pop_back()
	app.run_scraps += 1
	_peddler_reject(callbacks, "drifted scraps")
	app.run_scraps -= 1
	app.run_heroes[0].hp -= 1
	_peddler_reject(callbacks, "drifted heroes")
	app.run_heroes = context.heroes.duplicate(true)
	app.run_rng = RandomNumberGenerator.new()
	app.run_rng.state = rng.state
	_peddler_reject(callbacks, "foreign same-state RNG")
	app.run_rng = rng
	app.party_carryover = RunTornCarryover.new(app.run_heroes)
	_peddler_reject(callbacks, "foreign carryover")
	app.party_carryover = carry
	var node: String = map.get_current_node_id()
	map._nodes[node].type = "Rest"
	_peddler_reject(callbacks, "wrong node type")
	map._nodes[node].type = "Shop"
	map._generation_revision += 1
	_peddler_reject(callbacks, "regenerated graph")
	map._generation_revision -= 1
	var route: Array[String] = map.get_route()
	map._route.pop_back()
	_peddler_reject(callbacks, "changed route")
	map._route.assign(route)
	var foreign := RunMap.new()
	var other_rng := RandomNumberGenerator.new()
	other_rng.seed = app.run_seed
	foreign.generate(other_rng)
	for chosen in route:
		_check(foreign.choose_node(chosen), "foreign map has same legal route")
	app.run_map = foreign
	_peddler_reject(callbacks, "foreign same-route map")
	app.run_map = map
	var w: RunPatchWardrobe = app._peddler_wardrobe
	var foreign_wardrobe := RunPatchWardrobe.new(app.run_heroes, app.run_trinkets,
		RunAuthoredPatchDefinitions.load_definitions(), app.run_scraps, app.session_gold,
		app.run_deck, app.run_seed, true)
	_check(foreign_wardrobe.get_snapshot() == w.get_snapshot(), "foreign wardrobe fixture has an identical authentic snapshot")
	app._peddler_wardrobe = foreign_wardrobe
	_peddler_reject(callbacks, "foreign same-snapshot wardrobe")
	app._peddler_wardrobe = w
	w._operations.append("foreign_operation")
	_peddler_reject(callbacks, "changed complete wardrobe history")
	w._operations.pop_back()
	app.peddler_heroes.set_item_metadata(0, "unknown")
	_peddler_reject(callbacks, "forged patch owner")
	app.peddler_heroes.set_item_metadata(0, app.run_heroes[0].id)
	_check(app._sewing_context() == context, "all negative fixtures restore authentic source")


func _tampered_peddler_submission(intent: Dictionary, bridge: Callable) -> void:
	var before := _shop_state()
	var variants: Array[Dictionary] = []
	var forged := intent.duplicate(true)
	forged.node_id = "wrong_node"
	variants.append(forged)
	forged = intent.duplicate(true)
	forged.id = app.peddler_visit.read_state().stock.cards[1].id
	variants.append(forged)
	forged = intent.duplicate(true)
	forged.expected_state.gold += 1
	variants.append(forged)
	forged = intent.duplicate(true)
	forged.expected_stock.cards[0].price = 1
	variants.append(forged)
	forged = intent.duplicate(true)
	forged.extra = true
	variants.append(forged)
	for proposal in variants:
		bridge.call(proposal)
		_check(_shop_state() == before and app.peddler_visit.is_open()
			and app.shop_view._pending_intent == intent,
			"tampered issued intent refuses without consuming the genuine unchanged submission")


func _finish_shop() -> void:
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_shop_route_entry_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
