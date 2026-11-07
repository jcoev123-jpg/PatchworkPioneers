extends "res://tests/stitched_s6_full_run_test.gd"
## Exhaustive S6 stable-source conversion contract and one mounted Event witness.

const SOURCES := [
	"m04_events", "v3_roadside_events", "v3_candlelit_bargains",
	"v3_hero_choice_events", "v3_service_waystation_events",
	"s6_stitched_lantern_bobbin_ferry", "stitched_route_effects",
	"estate_sale", "needle_gate", "thimble_exchange",
]


func _run() -> void:
	var session := StitchedRunSession.start(234)
	_check(session != null and session.heroes.size() == 4, "valid authentic four-hero catalog inspection")
	if session == null:
		_done()
		return
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/events/stitched_s6_conversion_overrides.json"))
	_check(document is Dictionary and document.get("events") is Dictionary,
		"authored S6 non-wallet conversion overrides are present")
	if not document is Dictionary:
		_done()
		return
	var overrides: Dictionary = document.events
	var converted_count := 0
	var hero_count := 0
	var native_count := 0
	var special_count := 0
	for source in SOURCES:
		var catalog_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/events/" + source + ".json"))
		_check(catalog_document is Dictionary, source + " parses")
		if not catalog_document is Dictionary:
			continue
		var records: Variant = catalog_document.get("events", [catalog_document])
		_check(records is Array and not records.is_empty(), source + " has genuine records")
		if not records is Array:
			continue
		var seen: Dictionary = {}
		for record in records:
			if not record is Dictionary:
				_check(false, source + " record has schema")
				continue
			_check(not seen.has(record.id), "S6 Event IDs are unique within source " + source + ": " + str(record.id))
			seen[record.id] = true
			var converted: Dictionary = record if record.has("service_kind") else session._convert_event(record, overrides)
			_check(not converted.is_empty() and RunEventChoice.new(converted).is_valid(),
				"no valid parent Event/choice was silently discarded: " + str(record.id))
			if converted.is_empty():
				continue
			_check(converted.choices.size() == record.choices.size(),
				"every authored choice survives conversion " + str(record.id))
			if record.has("service_kind"):
				special_count += 1
				continue
			converted_count += 1
			if record.has("required_hero"):
				hero_count += 1
				var hero_gate: String = record.required_hero
				for choice in converted.choices:
					if choice.id in record.hero_choice_ids:
						_check(choice.stitched_effect.get("required_hero") == hero_gate,
							"authored hero-specific choice stays hero gated " + str(record.id))
					else:
						_check(not choice.stitched_effect.has("required_hero"),
							"ungated Leave remains possible " + str(record.id))
			if record.choices[0].has("stitched_effect"):
				native_count += 1
			for index in converted.choices.size():
				var before: Dictionary = record.choices[index]
				var after: Dictionary = converted.choices[index]
				if before.has("outcome"):
					for money in ["gold", "scraps"]:
						_check(after.stitched_effect.get(money, 0) ==
							session._event_amount(before.outcome.get(money, 0)),
							"original wallet delta preserved for " + str(record.id) + " / " + str(after.id))
				if record.id == "v3_mothlace_clock" and after.id == "wind_bell":
					_check(after.stitched_effect.candle == 3 and after.stitched_effect.scraps == 1,
						"explicit candle override merges without overwriting gold/scraps")
	_check(converted_count > 100 and hero_count > 0 and native_count > 0 and special_count > 0,
		"non-vacuous wallet, native, hero-gated and delegated Event coverage")
	var invalid := {"id": "invalid_extra", "title": "Malformed",
		"description": "An unsupported old mechanic",
		"choices": [{"id": "take", "text": "Take", "outcome": {"hp": -3}},
			{"id": "leave", "text": "Leave", "outcome": {"gold": 0, "scraps": 0}}]}
	var before_state := session.snapshot()
	_check(session._convert_event(invalid, overrides).is_empty()
		and session.snapshot() == before_state,
		"unknown legacy consequence fails closed without changing any Event/ledger/RNG")
	var bogus := invalid.duplicate(true)
	bogus.choices[0].outcome = {"gold": -4.5}
	_check(session._convert_event(bogus, overrides).is_empty(),
		"fractional authored wallet debit cannot be rounded into a purchase")

	# Smallest special Warden-event routability check outside the generic SOURCES list
	var vital_doc: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/v3_hero_vital_events.json"))
	_check(vital_doc is Dictionary and vital_doc.get("events") is Array, "v3_hero_vital_events parses")
	var warden_raw: Dictionary = {}
	if vital_doc is Dictionary and vital_doc.get("events") is Array:
		for ev in vital_doc.events:
			if ev is Dictionary and str(ev.get("id", "")) == "v3_warden_buckle_heart_ward":
				warden_raw = ev.duplicate(true)
				break
	_check(not warden_raw.is_empty() and RunEventChoice.new(warden_raw).is_valid(),
		"v3_warden_buckle_heart_ward exists and passes RunEventChoice schema check")
	_check(session._convert_event(warden_raw, overrides).is_empty(),
		"generic converter preserves fail-closed rejection on Warden hero-vital four-key outcome")

	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"
	var warden_session := StitchedRunSession.start(234)
	if warden_session != null:
		var target_node := ""
		for nid in warden_session.choices():
			if warden_session.map.get_node(nid).type == "Event":
				target_node = nid
				break
		if not target_node.is_empty():
			_check(warden_session.enter(target_node, warden_session.snapshot())
				and warden_session.phase == "visit"
				and warden_session.pending.event_id == "v3_warden_buckle_heart_ward"
				and warden_session._service is RunStitchedHeroVitalSeams
				and warden_session.visit_actions().size() == 3,
				"authentic Warden vitality crossroad admits into live Stitched Event and dispatches to RunStitchedHeroVitalSeams")

	var no_warden_session := StitchedRunSession.start(234, ["seamstress", "tinker", "lantern_monk", "rag_duelist"])
	if no_warden_session != null:
		var target_node := ""
		for nid in no_warden_session.choices():
			if no_warden_session.map.get_node(nid).type == "Event":
				target_node = nid
				break
		if not target_node.is_empty():
			_check(no_warden_session.enter(target_node, no_warden_session.snapshot())
				and no_warden_session.phase == "visit"
				and no_warden_session.pending.event_id != "v3_warden_buckle_heart_ward",
				"party without Warden never samples or offers v3_warden_buckle_heart_ward")
	StitchedRunSession.pinned_event_id = ""
	var app := await _new_run(234)
	var live: StitchedRunSession = app.stitched_run_session
	if live != null:
		var event_id := ""
		for node_id in live.choices():
			if live.map.get_node(node_id).type == "Event":
				event_id = node_id
				break
		_check(not event_id.is_empty() and _press_route(app, event_id)
			and live.phase == "visit" and live.pending.service == "Event",
			"real mounted route enters genuine seeded Event")
		if live.phase == "visit":
			var actions: Array = live.visit_actions()
			_check(not actions.is_empty() and actions.size() == app.stitched_run_buttons.size() - 2,
				"all quoted Event choices mounted as public focusable actions")
			var accepted := false
			for index in actions.size():
				var action: Dictionary = actions[index]
				if not action.enabled:
					continue
				var state := live.snapshot()
				var button: Button = app.stitched_run_buttons[index]
				_check(not button.disabled and button.is_visible_in_tree()
					and button.focus_mode == Control.FOCUS_ALL and button.get_meta("action_id") == action.id,
					"Event action is real mounted mouse/keyboard button")
				button.pressed.emit()
				accepted = live.snapshot() != state
				break
			_check(accepted and live.receipts.size() == 1 and live.is_consistent(),
				"one live Event commits exactly one receipt")
			var doc := StitchedRunSave.capture(live)
			var loaded := StitchedRunSave.restore(doc)
			_check(loaded != null and loaded.snapshot() == live.snapshot(),
				"Event wallet/action and RNG replay exactly under VERSION 1")
	app.free()
	await process_frame
	_done()


func _done() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s6_event_catalog_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
