extends "res://tests/live_frayed_debt_parcel_route_test.gd"
## Temporary diagnostic: what do the re-presented route buttons carry?

func _check(ok: bool, message: String) -> void:
	if not ok:
		print("FAIL: ", message)
	super._check(ok, message)


func _install_stitched_fixture() -> void:
	super._install_stitched_fixture()
	print("installed: route_view=", app.route_view, " buttons=", app.route_buttons.size(),
		" connected=", app._connected_map, " can=", app._can_choose_connected_route())
	for button in app.route_buttons:
		print("  button ", button.get_meta("route_id", "?"), " kind=", button.get_meta("route_kind", "?"),
			" parent=", button.get_parent(), " in_view=", button.get_parent() == app.route_view,
			" disabled=", button.disabled, " visible=", button.is_visible_in_tree(),
			" ctx_equal=", button.get_meta("sewing_source", {}) == app._sewing_context())


func _run() -> void:
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _frames()
	var f := _parcel_fixture("Unpicker", true)
	print("fixture seed=", f.seed, " stitched=", f.stitched, " path=", f.path)
	await _reach(f)
	print("after reach current=", app.run_map.get_current_node_id(),
		" legal=", app.run_map.get_legal_choices())
	print("failures=", failures)
	app.free()
	await _frames()
	quit()
