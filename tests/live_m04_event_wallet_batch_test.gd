extends "res://tests/live_event_treasure_continuation_test.gd"
## Genuine seeded opening routes through all three specials to each generic Event.

const REQUIRED := ["button_trail", "loose_seam", "thimble_well", "frayed_signpost",
	"needle_gate", "quilting_bee", "estate_sale", "lantern_moth_clearing",
	"patchwork_ferry", "spool_clocktower", "ragpicker_cart", "quilt_bridge",
	"button_moon_festival"]
var gold_purchases := 0


func _fixtures() -> Dictionary:
	var found := {}
	var ids: Array = RunM04EventRotation.new().get_generic_event_ids()
	# Six consecutive Events are rare. Revalidate known genuine seeds first;
	# the bounded search remains a fallback when the generated route/pool changes.
	# Needle Gate's first matching seed lies beyond the old search ceiling.
	var hints := [2712, 10378, 16044, 36044, 41749, 41911, 44324,
		54601, 71433, 103089, 133047, 133487, 743907]
	for value in hints + range(1, 500000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		var path := _find_path(map, map.get_legal_choices(), ["Event", "Event", "Event", "Event", "Event", "Event"])
		if path.is_empty():
			continue
		var toll := RunNeedleToll.new({"heroes": CombatParty.new(app._load_party_definitions()).get_heroes(),
			"wallet": {"gold": 0, "scraps": 0}, "deck": app._load_starter_deck()}, rng)
		_check(toll.pay_toll("warden").ok, "fixture stages real paid toll draws")
		var event_id: String = ids[rng.randi_range(0, ids.size() - 1)]
		if not found.has(event_id):
			found[event_id] = {"seed": value, "path": path.slice(0, 5), "next": path[5]}
		var complete := true
		for required in REQUIRED:
			complete = complete and found.has(required)
		if complete:
			break
	return found


func _wallet() -> Dictionary:
	return {"gold": app.session_gold, "scraps": app.run_scraps}


func _other_ledgers() -> Array:
	return [app.run_deck.duplicate(), app.run_heroes.duplicate(true),
		app.run_trinkets.duplicate(), app.run_stitch_descriptors.duplicate(true),
		app.run_next_stitch_id, app.run_removal_count, app.party_carryover.read_state(),
		app.party_carryover.torn.read_state(), app.act_outcome.get_state(),
		app.run_map.get_floors(), app.run_rng.state]


func _wallet_state() -> Array:
	return [_wallet(), _other_ledgers(), app.run_map.get_route(),
		app._wallet_event_history.duplicate(), app.wallet_event_panel,
		app._placeholder_route.duplicate(), app.route_view,
		app.wallet_event_panel._committed_choice.duplicate(true)
			if is_instance_valid(app.wallet_event_panel) else {}]


func _reject_wallet(callback: Callable, label: String) -> void:
	var before := _wallet_state()
	if callback.is_valid():
		callback.call()
	_check(_wallet_state() == before, label + " preserves wallet, all ledgers, route and RNG")


func _reach(fixture: Dictionary, funded: bool = true) -> void:
	app.run_seed = fixture.seed
	await _click(app.start_button)
	_check(app.run_map != null and app.run_rng != null, "real title Start creates seeded run")
	for index in range(3):
		await _click(_route_action(fixture.path[index]))
		var panel: LiveEventChoicePanel = app.quiet_spool_panel if index == 0 \
			else (app.moth_panel if index == 1 else app.dye_vat_panel)
		_check(is_instance_valid(panel) and app.route_view == null, "special Event genuinely mounted and gates route")
		if not is_instance_valid(panel):
			return
		await _click(panel.get_choice_buttons()[(0 if funded else 1) if index == 0 \
			else (2 if index == 1 or not funded else 1)])
	_check(app._quiet_spool_completed and app._moth_completed and app._dye_vat_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"three authentic special receipts establish exact opening wallet")
	await _click(_route_action(fixture.path[3]))
	_check(is_instance_valid(app.needle_toll_panel), "fourth Event mounts the inserted toll")
	if not is_instance_valid(app.needle_toll_panel):
		return
	await _click(app.needle_toll_panel.get_choice_buttons()[0])
	_check(is_instance_valid(app.needle_toll_panel) and app._needle_toll_outcome.is_paid(),
		"paid toll preserves the wallet before generic affordability tests")
	if is_instance_valid(app.needle_toll_panel):
		await _click(app.needle_toll_panel.get_choice_buttons()[2])
	_check(app.needle_toll_panel == null and app._needle_toll_completed
		and _wallet() == {"gold": 0, "scraps": 2 if funded else 0},
		"Skip resumes routing with the exact original wallet including zero-wallet negatives")


func _return_title() -> void:
	if not is_instance_valid(app.route_view):
		app._return_to_title()
	else:
		await _click(app.route_back_button)
	await _frames()
	_check(app.run_map == null and app.wallet_event_panel == null
		and app._wallet_event_history.is_empty(), "title clears generic session and history")


func _named(fixture: Dictionary, event_id: String, keyboard: bool) -> Array:
	await _reach(fixture)
	var button := _route_action(fixture.path[4])
	var entry: Callable = button.pressed.get_connections()[0].callable
	var rng := RandomNumberGenerator.new()
	rng.state = app.run_rng.state
	var ids := RunM04EventRotation.new().get_generic_event_ids()
	var expected_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	var before: Array = _other_ledgers()
	await _click(button)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel) and app.route_view == null, "later Event mounts actual wallet panel")
	if not is_instance_valid(panel):
		return []
	var paper_style := panel.paper_panel.get_theme_stylebox("panel")
	if ResourceLoader.exists("res://assets/paper/ui/reward_panel.png", "Texture2D"):
		_check(paper_style is StyleBoxTexture, "real routed Event mounts sewn paper")
		if paper_style is StyleBoxTexture:
			_check(paper_style.texture != null and paper_style.texture.resource_path
				== "res://assets/paper/ui/reward_panel.png", "routed paper uses shipped reward fabric")
	else:
		_check(paper_style is StyleBoxFlat, "real routed Event retains flat fallback")
	var record := panel._selector.get_event()
	_check(record.id == event_id and record.id == expected_id and app.run_rng.state == rng.state
		and app._wallet_event_history == [event_id], "named Event uses exactly one deterministic draw: " + event_id)
	before[10] = rng.state
	_check(_other_ledgers() == before and _wallet() == {"gold": 0, "scraps": 2},
		"opening consumes only the selection draw")
	_check(panel._wallet_mode and panel._offered_wallet == _wallet()
		and panel.get_choice_buttons().size() == record.choices.size()
		and panel.title_label.text == record.title and panel.description_label.text == record.description,
		"mounted offering preserves actual authored title, story and choice count")
	# Live typography: the real app-mounted Event sews its dynamic caption and
	# number tags in the Theme's display face, while the story and tickets keep
	# the inherited body face and their exact authored/forecast text.
	var heading_face := "res://assets/fonts/LondrinaSolid-Regular.ttf"
	var body_face := "res://assets/fonts/PatrickHand-Regular.ttf"
	var caption := panel.choices_container.get_parent().get_node_or_null("WalletBalance") as Label
	_check(caption != null and caption.text == "Wallet  •  %d gold   /   %d scraps" % [_wallet()["gold"], _wallet()["scraps"]]
		and (caption.get_theme_font("font") as Font).resource_path == heading_face,
		"live wallet caption states exact balances in the display face")
	_check((panel.description_label.get_theme_font("font") as Font).resource_path == body_face
		and (panel.get_choice_buttons()[0].get_theme_font("font") as Font).resource_path == body_face,
		"live story and tickets keep the body face")
	for cue in panel.get_choice_cues():
		_check((cue.get_theme_font("font") as Font).resource_path == heading_face,
			"live sewn tag wears the display face")
	_reject_wallet(entry, "duplicate route input while panel open")
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	_reject_wallet(commit.bind({"ok": true, "event_id": event_id, "choice_id": "forged",
		"wallet": {"gold": 999, "scraps": 999}}), "forged signal before physical claim")
	var selected := -1
	for index in range(record.choices.size()):
		var choice: Dictionary = record.choices[index]
		var gold: int = int(choice.outcome.gold)
		var scraps: int = int(choice.outcome.scraps)
		var affordable := 0 + gold >= 0 and 2 + scraps >= 0
		var control: Button = panel.get_choice_buttons()[index]
		_check(control.disabled == not affordable and control.text.contains(choice.text), "authored affordability on visible ticket")
		if affordable:
			_check(control.tooltip_text.contains("After: %d gold | %d scraps" % [gold, 2 + scraps]),
				"visible forecast gives exact authored balance")
			if selected < 0 or scraps < 0:
				selected = index
	_check(selected >= 0, "named Event has a genuine affordable choice")
	if selected < 0:
		return []
	var chosen: Dictionary = record.choices[selected]
	var expected := {"gold": int(chosen.outcome.gold), "scraps": 2 + int(chosen.outcome.scraps)}
	var pressed: Callable = panel.get_choice_buttons()[selected].pressed.get_connections()[0].callable
	if keyboard:
		panel.get_choice_buttons()[selected].grab_focus()
		await _key(KEY_SPACE)
	else:
		await _click(panel.get_choice_buttons()[selected])
	_check(app.wallet_event_panel == null and is_instance_valid(app.route_view)
		and _wallet() == expected and _other_ledgers() == before,
		"physical choice publishes exact wallet once with all other ledgers unchanged: " + event_id)
	_check(not pressed.is_valid(), "disposed panel invalidates retained physical callback")
	_reject_wallet(pressed, "repeated physical choice")
	_reject_wallet(commit.bind({"ok": true, "event_id": event_id, "choice_id": chosen.id,
		"wallet": expected}), "replayed owner receipt")
	_reject_wallet(entry, "completed route replay")
	var result := [_wallet(), app.run_map.get_route(), str(app.run_rng.state), record, chosen.id]
	await _click(_route_action(fixture.next))
	_check(app.run_map.get_current_node_id() == fixture.next, "settlement admits genuine connected successor")
	var second: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(second), "successor mounts second generic wallet offering")
	if not is_instance_valid(second):
		return []
	var second_record := second._selector.get_event()
	var remaining := ids.duplicate()
	remaining.erase(event_id)
	var second_id: String = remaining[rng.randi_range(0, remaining.size() - 1)]
	_check(second_record.id == second_id and second_record.id != event_id
		and app._wallet_event_history == [event_id, second_id] and app.run_rng.state == rng.state,
		"next one-draw selection excludes actual visited generic history")
	var paid := -1
	for index in range(second_record.choices.size()):
		if not second.get_choice_buttons()[index].disabled and (paid < 0 \
			or int(second_record.choices[index].outcome.gold) < 0):
			paid = index
	_check(paid >= 0 and not second.get_choice_buttons()[paid].disabled,
		"authentic first sale funds the second choice")
	if paid < 0:
		return []
	var paid_choice: Dictionary = second_record.choices[paid]
	if int(paid_choice.outcome.gold) < 0:
		gold_purchases += 1
	var paid_wallet := {"gold": expected.gold + int(paid_choice.outcome.gold),
		"scraps": expected.scraps + int(paid_choice.outcome.scraps)}
	var paid_before := _other_ledgers()
	if keyboard:
		await _key(KEY_1 + paid)
	else:
		await _click(second.get_choice_buttons()[paid])
	_check(_wallet() == paid_wallet and _other_ledgers() == paid_before
		and app.wallet_event_panel == null and app.route_view != null,
		"second receipt applies exact authored delta to earned wallet once")
	result.append([second_record, paid_wallet, str(app.run_rng.state)])
	await _return_title()
	return result


func _failures(fixture: Dictionary) -> void:
	await _reach(fixture, false)
	var button := _route_action(fixture.path[4])
	var entry: Callable = button.pressed.get_connections()[0].callable
	var catalog_path: String = app.event_catalog_path
	app.event_catalog_path = "res://missing_event_catalog.json"
	_reject_wallet(entry, "missing catalog rejects without draw")
	app.event_catalog_path = catalog_path
	app.session_gold = -1
	_reject_wallet(entry, "failed wallet panel mount rolls back selection draw")
	app.session_gold = 0
	button.disabled = true
	_reject_wallet(entry, "disabled route")
	button.disabled = false
	await _click(button)
	var panel: LiveEventChoicePanel = app.wallet_event_panel
	_check(is_instance_valid(panel), "negative fixtures have actual mounted offering")
	if not is_instance_valid(panel):
		return
	var record := panel._selector.get_event()
	var denied := -1
	var allowed := -1
	for index in range(record.choices.size()):
		if panel.get_choice_buttons()[index].disabled:
			denied = index
		else:
			allowed = index
	_check(denied >= 0 and allowed >= 0, "zero wallet provides actual unaffordable and affordable choices")
	if denied < 0 or allowed < 0:
		return
	var denied_button: Button = panel.get_choice_buttons()[denied]
	var before := _wallet_state()
	await _click(denied_button)
	await _key(KEY_1 + denied)
	denied_button.pressed.emit()
	_check(_wallet_state() == before and not panel._selector.is_claimed(), "unaffordable mouse, keyboard and signal consume nothing")
	var commit: Callable = panel.wallet_choice_committed.get_connections()[0].callable
	var receipt := RunEventChoice.new(record).choose_with_wallet(record.choices[allowed].id, _wallet())
	_check(receipt.ok, "forgery test uses a real affordable authored receipt")
	# Even matching receipts cannot bypass physical panel ownership.
	_reject_wallet(commit.bind(receipt), "authentic-shaped receipt without panel claim")
	var original_map: RunMap = app.run_map
	var foreign := RunMap.new()
	var foreign_rng := RandomNumberGenerator.new()
	foreign_rng.seed = fixture.seed
	foreign.generate(foreign_rng)
	app.run_map = foreign
	_reject_wallet(commit.bind(receipt), "foreign map")
	app.run_map = original_map
	# Stage the panel's genuine claim while keeping owner publication disconnected,
	# then challenge the owner with forged balances, wrong routes and stale wallets.
	panel.wallet_choice_committed.disconnect(commit)
	await _click(panel.get_choice_buttons()[allowed])
	_check(panel._selector.is_claimed() and panel._committed_choice == receipt, "real callback produced exact pending receipt")
	app.run_map = foreign
	_reject_wallet(commit.bind(receipt), "foreign map after actual claim")
	app.run_map = original_map
	var forged := receipt.duplicate(true)
	forged.wallet.gold += 1
	_reject_wallet(commit.bind(forged), "forged wallet after actual claim")
	panel._committed_choice = forged.duplicate(true)
	_reject_wallet(commit.bind(forged), "forged panel receipt still fails authored wallet recomputation")
	panel._committed_choice = receipt.duplicate(true)
	var current: String = original_map.get_current_node_id()
	original_map._nodes[current].type = "Treasure"
	_reject_wallet(commit.bind(receipt), "wrong route type after actual claim")
	original_map._nodes[current].type = "Event"
	var route: Array = original_map._route.duplicate()
	original_map._route.pop_back()
	_reject_wallet(commit.bind(receipt), "stale route after actual claim")
	original_map._route.assign(route)
	app.run_scraps += 1
	_reject_wallet(commit.bind(receipt), "stale wallet after actual claim")
	app.run_scraps -= 1
	commit.call(receipt)
	_check(app.wallet_event_panel == null and _wallet() == receipt.wallet and app.route_view != null,
		"restored authentic pending receipt can settle once")
	_reject_wallet(commit.bind(receipt), "duplicate settled receipt")
	await _return_title()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	seed(227227)
	var global_next := randi()
	seed(227227)
	var fixtures := _fixtures()
	for id in REQUIRED:
		_check(fixtures.has(id), "bounded genuine seeded route exists for " + id)
		if not fixtures.has(id):
			continue
		var first := await _named(fixtures[id], id, false)
		var replay := await _named(fixtures[id], id, true)
		_check(not first.is_empty() and first == replay, "same seed mouse/keyboard replay matches exact Event, wallet, route and RNG")
	if fixtures.has("button_trail"):
		await _failures(fixtures.button_trail)
	_check(gold_purchases > 0, "real generic sales fund real gold-cost choices")
	_check(randi() == global_next, "all selection, choices and rejections preserve global RNG")
	app.free()
	await _frames()
	for failure in failures:
		printerr(failure)
	print("live_m04_event_wallet_batch_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
