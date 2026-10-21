extends "res://tests/live_shop_continuation_test.gd"
## Mounted title -> Fight -> Shop -> map, using the real continuation fixture.


func _summary_state() -> Array:
	var carry: RunTornCarryover = app.party_carryover
	return [_continuation_state(), app.run_scraps, app.run_trinkets.duplicate(),
		carry.read_state(), carry.torn.read_state(),
		null if carry._wardrobe == null else carry._wardrobe.get_snapshot(),
		app.run_map.get_floors()]


func _activate_summary(control: Control, keyboard: bool) -> void:
	if keyboard:
		control.grab_focus()
		await _key(KEY_ENTER)
	else:
		await _click(control)


func _summary_text() -> Array:
	var readout: HBoxContainer = app.route_view.get_node("PatchWearerSummary")
	var texts := []
	for label in readout.get_children():
		_check(label is Label and label.is_visible_in_tree(), "actual visible read-only patch label")
		texts.append(label.text)
	return texts


func _assert_summary() -> Array:
	var carry: RunTornCarryover = app.party_carryover
	var oracle := RunPatchWearerSummary.summarize(carry._wardrobe, carry.torn.read_state())
	_check(oracle.ok and oracle.heroes.size() == 3, "real sources yield three wearer summaries")
	var texts := _summary_text()
	_check(texts.size() == 3, "one visible readout per hero")
	if not oracle.ok or texts.size() != 3:
		return texts
	for i in range(3):
		var hero: Dictionary = oracle.heroes[i]
		var expected := "%s - patches" % hero.id.capitalize()
		_check(hero.slots.size() == 3, "all three authoritative slots present")
		for slot in hero.slots:
			var value: String = "empty"
			if not slot.patch_id.is_empty():
				value = "%s (%s)" % [slot.patch_id, "active" if slot.active else "inactive"]
				if not slot.rules_text.is_empty():
					value += " - %s" % slot.rules_text
			expected += "\n%s: %s" % [slot.slot, value]
		_check(texts[i] == expected, "complete visible hero/slot/ID/activation/rules matches authority")
	return texts


func _reopen_summary() -> void:
	app._clear_route_view()
	app._present_connected_route(weakref(app.run_map))
	await _frames()


func _summary_bounds(control: Control) -> void:
	_check(Rect2(0, 0, 1280, 720).encloses(control.get_global_rect()), "complete map control fits viewport")
	if control is Label:
		_check(control.size.x >= control.get_minimum_size().x, "patch text is not clipped")
		_check(control.size.y >= control.get_minimum_size().y, "wrapped patch text has room to show every line")
	for child in control.get_children():
		if child is Control:
			_summary_bounds(child)


func _summary_negatives() -> void:
	var carry: RunTornCarryover = app.party_carryover
	var wardrobe: RunPatchWardrobe = carry._wardrobe
	var saved_hp: int = carry.torn._heroes[0].hp
	carry._wardrobe = null
	var before := _summary_state()
	await _reopen_summary()
	_check(_summary_text() == ["Patches unavailable - no wardrobe bound"], "owned patches without a bound wardrobe stay explicitly unavailable")
	_check(_summary_state() == before, "absent render preserves surviving models")
	carry._wardrobe = wardrobe
	var torn: RunTornMending = carry.torn
	carry.torn = null
	# Render just the readout: map/mend admission requires a non-null ledger.
	var old: HBoxContainer = app.route_view.get_node("PatchWearerSummary")
	old.free()
	app._present_route_patch_summary(carry)
	_check(_summary_text() == ["Patches unavailable - invalid source"], "missing ledger fails closed")
	carry.torn = torn
	wardrobe._valid = false
	before = _summary_state()
	await _reopen_summary()
	_check(_summary_text() == ["Patches unavailable - invalid source"], "present invalid wardrobe never looks empty or absent")
	_check(_summary_state() == before, "invalid wardrobe render changes no state")
	wardrobe._valid = true
	for kind in ["malformed", "contradictory"]:
		if kind == "malformed":
			torn._heroes[0].hp = -1
		else:
			torn._tear_counts.warden += 1
		before = _summary_state()
		await _reopen_summary()
		_check(_summary_text() == ["Patches unavailable - invalid source"], kind + " ledger is explicitly invalid")
		_check(_summary_state() == before, "invalid render changes no surviving state")
		if kind == "malformed":
			torn._heroes[0].hp = saved_hp
		else:
			torn._tear_counts.warden -= 1
	var saved_carry: RunTornCarryover = app.party_carryover
	app.party_carryover = null
	await _reopen_summary()
	_check(_summary_text() == ["Patches unavailable - no carryover"], "absent carryover is explicitly unavailable")
	app.party_carryover = saved_carry
	var saved_trinkets: Array[String] = app.run_trinkets.duplicate()
	app.run_trinkets.clear()
	carry._wardrobe = null
	torn._heroes[0].hp = -1
	before = _summary_state()
	await _reopen_summary()
	_check(_summary_text() == ["Patches unavailable - invalid source"], "malformed ledger with no patches never pretends empty")
	_check(_summary_state() == before, "invalid empty-patch render changes no state")
	torn._heroes[0].hp = saved_hp
	app.run_trinkets.assign(saved_trinkets)
	carry._wardrobe = wardrobe
	await _reopen_summary()
	_assert_summary()


## Discover genuine seeded stock through the mounted route, without pinning a seed.
func _coat_fixture() -> Dictionary:
	var first_seed := 1
	for attempt in range(32):
		var fixture := _continuation_fixture("Rest", first_seed)
		if fixture.is_empty() or not await _routed_win(fixture, true):
			return {}
		await _click(app.reward_buttons[3])
		await _click(app.continue_button)
		app.session_gold = 400
		await _click(_route_action(fixture.shop))
		var found := false
		for offer in app.shop_purchases.get_stock().trinkets:
			found = found or offer.id == "quilted_coat"
		await _click(app.shop_back_button)
		if found:
			return fixture
		first_seed = fixture.seed + 1
	return {}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.gui_embed_subwindows = true
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveAttackPreview")
	var fixture := _continuation_fixture("Rest")
	_check(not fixture.is_empty(), "real seeded Fight -> Shop -> Rest fixture exists")
	if not fixture.is_empty():
		for downed in [false, true]:
			var replay := []
			for keyboard in [false, true]:
				seed(108108)
				var global_next := randi()
				seed(108108)
				if not await _routed_win(fixture, downed):
					break
				await _activate_summary(app.reward_buttons[3], keyboard)
				await _activate_summary(app.continue_button, keyboard)
				_check(_summary_text() == ["No patches sewn"], "pre-Shop route has no invented ownership")
				app.session_gold = 400 # Funding only; stock, sewing and route are real.
				await _activate_summary(_route_action(fixture.shop), keyboard)
				_check(app.shop_patch_offers.item_count > 0 and not app.shop_patch_buy_button.disabled, "real Shop offers affordable patch")
				var slot_only := -1
				for index in range(app.shop_patch_offers.item_count):
					if app.shop_patch_offers.get_item_metadata(index) in ["stitched_badge", "spare_spool"]:
						slot_only = index
				_check(slot_only >= 0, "real stock contains a slot-only patch")
				if slot_only < 0:
					break
				app.shop_patch_offers.select(slot_only)
				app.shop_patch_offers.item_selected.emit(slot_only)
				var id: String = app.shop_patch_offers.get_item_metadata(slot_only)
				app.shop_patch_heroes.select(2)
				app.shop_patch_heroes.item_selected.emit(2)
				await _activate_summary(app.shop_patch_buy_button, keyboard)
				var carry: RunTornCarryover = app.party_carryover
				var wardrobe: RunPatchWardrobe = carry._wardrobe
				_check(wardrobe != null and wardrobe.get_snapshot().owned.has(id), "legal transaction owns sewn stock ID")
				var slot: String = wardrobe.get_snapshot().definitions[id]
				_check(wardrobe.get_snapshot().worn.tinker[slot] == id, "transaction sews exact slot on Tinker")
				await _activate_summary(app.shop_continue_button, keyboard)
				var before := _summary_state()
				var texts := _assert_summary()
				_check(str(texts).contains("%s: %s (%s)" % [slot, id, "inactive" if downed else "active"]), "genuinely downed wearer suppresses activation")
				var worn_rules := ""
				for hero in RunPatchWearerSummary.summarize(wardrobe, carry.torn.read_state()).heroes:
					for entry in hero.slots:
						if entry.patch_id == id:
							worn_rules = entry.rules_text
				_check(worn_rules.is_empty()
					and not str(texts).contains("%s: %s (%s) - " % [slot, id, "inactive" if downed else "active"]),
					"authored slot-only stock shows no fabricated rules text")
				for repeat in range(2):
					await _reopen_summary()
					_check(_assert_summary() == texts and _summary_state() == before, "reopen is identical and spends nothing across all ledgers/RNG")
				_summary_bounds(app.route_view)
				var trace := [texts, before]
				if keyboard:
					_check(trace == replay, "same-seed mouse/keyboard continuation agrees completely")
				else:
					replay = trace
				await _summary_negatives()
				await _activate_summary(_route_action(fixture.next), keyboard)
				_check(app.rest_view != null and app.run_map.get_current_node_id() == fixture.next, "existing next-route callback still works")
				await _activate_summary(app.rest_heal_button, keyboard)
				await _activate_summary(app.rest_continue_button, keyboard)
				_assert_summary()
				_check(not str(_summary_text()).contains("inactive"), "later visit refreshes healed wearer activation")
				_summary_bounds(app.route_view)
				await _activate_summary(app.route_back_button, keyboard)
				_check(randi() == global_next, "readout and continuation consume no global RNG")
	# Real seeded stock that genuinely offers the authored coat patch.
	var coat_fixture := await _coat_fixture()
	_check(not coat_fixture.is_empty(), "seeded real graph supports a coat-patch Shop")
	if not coat_fixture.is_empty():
		seed(108108)
		var global_next := randi()
		seed(108108)
		var coat_rules_visible := false
		if await _routed_win(coat_fixture, true):
			await _activate_summary(app.reward_buttons[3], false)
			await _activate_summary(app.continue_button, false)
			_check(_summary_text() == ["No patches sewn"], "legitimate pre-Shop coat run has no invented ownership")
			app.session_gold = 400 # Funding only; stock, sewing and route are real.
			await _activate_summary(_route_action(coat_fixture.shop), false)
			var stock: Array = app.shop_purchases.get_stock().trinkets
			var coat_index := -1
			for index in range(stock.size()):
				if stock[index].id == "quilted_coat":
					coat_index = index
			_check(coat_index >= 0 and app.shop_patch_offers.get_item_metadata(coat_index) == "quilted_coat",
				"seeded Shop stock genuinely lists the authored coat patch")
			if coat_index < 0:
				await _activate_summary(app.shop_back_button, false)
			else:
				app.shop_patch_offers.select(coat_index)
				app.shop_patch_offers.item_selected.emit(coat_index)
				app.shop_patch_heroes.select(2)
				app.shop_patch_heroes.item_selected.emit(2)
				await _activate_summary(app.shop_patch_buy_button, false)
				var carry: RunTornCarryover = app.party_carryover
				var wardrobe: RunPatchWardrobe = carry._wardrobe
				_check(wardrobe != null and wardrobe.get_snapshot().worn.tinker.COAT == "quilted_coat",
					"legal transaction sews the coat on Tinker's COAT slot")
				await _activate_summary(app.shop_continue_button, false)
				var before := _summary_state()
				var texts := _assert_summary()
				_check(texts.size() == 3 and str(texts[2]).contains("COAT: quilted_coat (inactive) - +6 maximum HP"),
					"sewn coat shows authoritative rules text for its downed wearer")
				for repeat in range(2):
					await _reopen_summary()
					_check(_assert_summary() == texts and _summary_state() == before,
						"coat readout reopens identically and spends nothing")
				_summary_bounds(app.route_view)
				coat_rules_visible = true
				await _activate_summary(app.route_back_button, false)
				_check(randi() == global_next, "coat readout consumes no global RNG")
		else:
			_check(false, "seeded coat battle is reachable through the real route")
		_check(coat_rules_visible, "mounted coat flow actually rendered the authoritative rules text")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_map_patch_summary_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
