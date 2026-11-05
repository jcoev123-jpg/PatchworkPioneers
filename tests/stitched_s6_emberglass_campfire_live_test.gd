extends "res://tests/stitched_s6_campfire_wick_live_test.gd"
## Real earned entry uses the existing legal battle and Circle driver.


func _event(choice: String, poor := false) -> Dictionary:
	var setup: Dictionary = await _prepare(-1, poor)
	var app: Node = setup["app"]
	_check(setup.get("survivors", []).size() == 4 and app._stitched_party_locked,
		"Event witness requires four actual survivors and authenticated Circle Leave")
	if setup.get("survivors", []).size() != 4:
		app.free()
		return {}
	var original := _resources(app)
	var earned_config: Dictionary = app._stitched_floor_config()
	_check(original["scraps"] == (0 if poor else 1),
		"real Circle Leave carries exactly the earned or legitimately spent scrap wallet")
	var retained_battle: StitchedRules = setup["battle"]
	_check(retained_battle.is_valid(), "seeded rules witness is valid")
	var held_rng := retained_battle.rng_state()
	_admission_refusals(app)
	app.stitched_preview_gold += 1
	var changed_wallet := _resources(app)
	_check(not app._open_stitched_campfire() and _resources(app) == changed_wallet,
		"wallet changed since Circle Leave cannot consume the earned ticket")
	app.stitched_preview_gold = original["gold"]
	app.stitched_campfire_button.pressed.emit()
	await process_frame
	var panel: Control = app.stitched_campfire_panel
	var event: RunStitchedEmberglassCampfireEvent = app.stitched_campfire_event
	_check(panel != null and event != null and app.stitched_campfire_visit == null,
		"one Campfire button mounts the real Emberglass admission adapter first")
	if panel == null or event == null:
		app.free()
		return {}
	var entered: Dictionary = original.duplicate(true)
	entered["candle"] = maxi(0, original["candle"] - 8)
	var state := event.read_state()
	var generation: int = app._stitched_campfire_generation
	var source: WeakRef = weakref(panel)
	var record := event.get_event()
	var heading: Label = panel.find_child("EmberglassHeading", true, false)
	_check(record["id"] == "v3_emberglass_campfire" and heading != null
		and heading.text.contains(record["title"]) and heading.text.contains(record["description"])
		and event.get_heroes() == app._stitched_campfire_authorized_roster
		and event.get_candle() == entered["candle"] and _resources(app) == entered,
		"authored story and ranked earned carry show after exactly one eight-candle admission")
	for index in record["choices"].size():
		var row: Dictionary = record["choices"][index]
		var button: Button = panel.find_child("Emberglass_" + str(row["id"]), true, false)
		var available: bool = not poor or row["id"] != "light_the_embers"
		_check(button != null and button.text == row["text"] and button.disabled == not available
			and button.focus_mode == (Control.FOCUS_ALL if available else Control.FOCUS_NONE),
			"authored choice has exact label and actionable keyboard state " + str(row["id"]))
	seed(53701)
	var global_next := randi()
	seed(53701)
	var forged := state.duplicate(true)
	forged["wallet"]["scraps"] += 1
	var refusals := [
		app._stitched_campfire_event_choose(choice, forged, source, generation),
		app._stitched_campfire_event_choose(choice, state, null, generation),
		app._stitched_campfire_event_choose(choice, state, source, generation - 1),
		app._stitched_campfire_event_choose("forged", state, source, generation),
	]
	for ledger in ["stitched_preview_gold", "stitched_preview_scraps", "stitched_roadblock_candle"]:
		var saved: int = app.get(ledger)
		app.set(ledger, saved + 1)
		refusals.append(app._stitched_campfire_event_choose(choice, state, source, generation))
		app.set(ledger, saved)
	var wrong_node := state.duplicate(true)
	wrong_node["node_id"] = "forged"
	refusals.append(app._stitched_campfire_event_choose(choice, wrong_node, source, generation))
	var rank_carry: Dictionary = app._stitched_rank_carry.duplicate(true)
	app._stitched_rank_carry[state["heroes"][0]["id"]] = 4
	refusals.append(app._stitched_campfire_event_choose(choice, state, source, generation))
	app._stitched_rank_carry = rank_carry
	var satchel: Array = app.stitched_preview_satchel.duplicate(true)
	app.stitched_preview_satchel.clear()
	refusals.append(app._stitched_campfire_event_choose(choice, state, source, generation))
	app.stitched_preview_satchel = satchel
	var hp: Dictionary = app._stitched_hp_carry.duplicate(true)
	app._stitched_hp_carry[state["heroes"][0]["id"]] -= 1
	refusals.append(app._stitched_campfire_event_choose(choice, state, source, generation))
	app._stitched_hp_carry = hp
	panel.hide()
	refusals.append(app._stitched_campfire_event_choose(choice, state, source, generation))
	panel.show()
	if poor:
		refusals.append(app._stitched_campfire_event_choose("light_the_embers", state, source, generation))
	_check(refusals.all(func(receipt): return receipt.get("ok") == false)
		and event.read_state() == state and _resources(app) == entered
		and retained_battle.rng_state() == held_rng and randi() == global_next
		and not app._open_stitched_unpicker() and not app._open_stitched_fight(),
		"forged, stale, hidden, ledger-mismatched and unavailable choices preserve carry and RNG")
	if choice == "light_the_embers":
		app.fail_campfire_mount = true
		var attempts: int = app.mount_attempts
		_check(not app._stitched_campfire_event_choose(choice, state, source, generation).get("ok")
			and app.mount_attempts == attempts + 1 and _resources(app) == entered
			and event.read_state() == state and app.stitched_campfire_panel == panel
			and app.stitched_campfire_visit == null and retained_battle.rng_state() == held_rng,
			"failed real inner-service mount preserves wallet, RNG and original Event choice")
		app.fail_campfire_mount = false
	var selected: Button = panel.find_child("Emberglass_" + choice, true, false)
	selected.pressed.emit()
	var settled := entered.duplicate(true)
	if choice == "light_the_embers":
		settled["scraps"] -= 1
	elif choice == "sell_cinders":
		settled["gold"] += 12
	_check(event.is_claimed() and _resources(app) == settled
		and retained_battle.rng_state() == held_rng,
		"one authenticated Event settlement has exact authored wallet and no second entry toll")
	_check(not app._stitched_campfire_event_choose(choice, state, source, generation).get("ok")
		and not event.choose(choice, NODE, state).get("ok") and _resources(app) == settled,
		"retained Event and mounted callback cannot replay a paid or alternate settlement")
	if choice == "light_the_embers":
		var inner: Control = app.stitched_campfire_panel
		_check(inner != null and inner != panel and app.stitched_campfire_visit != null
			and app._stitched_campfire_state["candle"] == entered["candle"],
			"paid receipt opens the existing real recovery service at already-charged candle")
		var wick: Button = inner.find_child("CampfireWick", true, false)
		_check(wick != null and not wick.disabled, "real paid service offers a useful Wick recovery")
		wick.pressed.emit()
		settled["candle"] = mini(100, entered["candle"] + 50)
	else:
		_check(app.stitched_campfire_panel == null and app.stitched_campfire_visit == null,
			"alternate Event closes without creating any inner recovery service")
	_check(_resources(app) == settled and not app._open_stitched_campfire()
		and not app._open_stitched_peddler() and not app._open_stitched_unpicker(),
		"settled stop cannot mint a second service")
	await process_frame
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle != null and next.battle.is_valid(),
		"Event settlement reaches the next actual Fight")
	if next != null:
		var mounted_hp := {}
		var mounted_fray := {}
		for hero in next.battle.get_heroes():
			mounted_hp[hero["id"]] = hero["hp"]
			mounted_fray[hero["id"]] = {"fray": hero["fray"], "resolve": hero["resolve"]}
		_check(mounted_hp == settled["hp"] and mounted_fray == settled["fray"]
			and next.config["candle"] == maxi(0, settled["candle"] - 8)
			and app.stitched_preview_gold == settled["gold"]
			and app.stitched_preview_scraps == settled["scraps"]
			and app.stitched_preview_satchel == settled["satchel"]
			and app._stitched_gear_overrides == settled["gear"]
			and app._stitched_bleed_carry == settled["bleed"]
			and next.config["heroes"].map(func(hero): return hero["parts"])
				== earned_config["heroes"].map(func(hero): return hero["parts"]),
			"next seeded Fight receives exact HP, FRAY, parts, wallet and ordinary Fight entry candle")
	var trace := {"entered": entered, "settled": settled,
		"rng": next.battle.rng_state() if next != null else -1}
	app.free()
	await process_frame
	return trace


func _actionless() -> void:
	var setup: Dictionary = await _prepare()
	var app: Node = setup["app"]
	var healthy: Array = app._stitched_campfire_authorized_roster.duplicate(true)
	_check(healthy.size() == 4, "actionless preview starts with an authentic complete survivor roster")
	for hero: Dictionary in healthy:
		hero["hp"] = hero["max_hp"]
		hero["fray"] = 0
	var event := RunStitchedEmberglassCampfireEvent.new(
		"v3_emberglass_campfire", NODE, healthy, 100, {"gold": 0, "scraps": 1})
	var state := event.read_state()
	_check(event.is_valid() and not event.has_useful_recovery(),
		"full HP, calm four-rank party at full candle has no useful recovery")
	var built: Dictionary = app._mount_stitched_campfire_event(event.quote(), 1)
	var panel: Control = built["panel"]
	app.add_child(panel)
	var paid: Button = panel.find_child("Emberglass_light_the_embers", true, false)
	_check(paid != null and paid.disabled and paid.focus_mode == Control.FOCUS_NONE
		and not event.choose("light_the_embers", NODE, state).get("ok")
		and event.read_state() == state,
		"same Event presentation disables an affordable actionless service without settlement")
	app.free()
	await process_frame


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var first := await _event("light_the_embers")
	var replay := await _event("light_the_embers")
	_check(not first.is_empty() and first == replay, "independent seeded earned routes replay identical carry and RNG")
	await _event("sell_cinders")
	await _event("leave")
	await _event("leave", true)
	await _actionless()
	for failure in failures:
		printerr(failure)
	print("stitched_s6_emberglass_campfire_live_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
