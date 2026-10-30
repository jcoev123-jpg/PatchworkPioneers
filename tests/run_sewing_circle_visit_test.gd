extends SceneTree

const NODE := "sewing-circle-3"
const STRIKE := "warden_strike"
const PRICK := "seamstress_prick"
const POOL := "seamstress_running_stitch"
const V3_POOL := "lantern_monk_moth_lure"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	seed(263)
	var global_next := randi()
	seed(263)
	_test_choices_and_upgrades()
	_test_newer_hero_pool_upgrade()
	_test_stitches()
	_test_rejections()
	_test_invalid()
	_check(randi() == global_next, "all operations preserve global RNG")
	for failure in failures:
		printerr(failure)
	print("run_sewing_circle_visit_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _make(deck: Variant = [STRIKE, STRIKE, PRICK, POOL], scraps: Variant = 7,
		registry: Variant = {}, cursor: Variant = 1, node: Variant = NODE) -> RunSewingCircleVisit:
	return RunSewingCircleVisit.new(node, deck, registry, scraps, cursor)


func _upgrade(v: RunSewingCircleVisit, index: Variant, s: Dictionary) -> Dictionary:
	return v.choose_upgrade(index, s.visit_id, s.node_id, s)


func _stitch(v: RunSewingCircleVisit, a: Variant, b: Variant, s: Dictionary) -> Dictionary:
	return v.choose_stitch(a, b, s.visit_id, s.node_id, s)


func _leave(v: RunSewingCircleVisit, s: Dictionary) -> Dictionary:
	return v.leave(s.visit_id, s.node_id, s)


func _test_choices_and_upgrades() -> void:
	_check(not RunRestStitchCards.resolve_card_definition(POOL).is_empty(), "authentic pool fixture")
	for index in [1, 3]:
		var deck := [STRIKE, STRIKE, PRICK, POOL]
		var v := _make(deck)
		var s := v.read_state()
		_check(v.is_valid() and not v.is_consumed(), "valid open ledger")
		_check(v.quote().choices == ["upgrade", "stitch", "leave"], "three canonical decisions")
		var canonical := RunRestCardUpgrade.list_authored_choices(deck, {}, 1)
		_check(not canonical.choices.is_empty() and v.upgrade_options() == canonical.choices, "exact canonical upgrades")
		var options := v.upgrade_options()
		options[0].effects.clear()
		_check(v.upgrade_options() == canonical.choices, "detached upgrade options")
		deck.clear()
		_check(v.read_state() == s, "caller deck copied")
		var result := _upgrade(v, index, s)
		var expected: Array = s.deck.duplicate()
		expected[index] = canonical.permitted_upgrades[expected[index]]
		_check(result.get("ok", false) and result.deck == expected, "one indexed starter/pool upgrade")
		_check(result.remaining_scraps == 7 and result.descriptors == {} and result.next_stitch_id == 1
			and result.charged_scraps == 0, "upgrade preserves currency registry cursor")
		_check(result.source_snapshot == s and result.source_receipt == s.receipt and result.consumed, "complete bound receipt")
		var after := v.read_state()
		_check(not _stitch(v, 0, 2, s).ok and not _upgrade(v, 0, s).ok and not _leave(v, s).ok
			and v.read_state() == after and v.quote().choices.is_empty(), "all decisions reject after upgrade")
		result.deck.clear()
		result.source_snapshot.deck.clear()
		_check(v.read_state() == after, "detached success receipt")


## A genuine newer-hero (v3) reward-pool base must appear in the live visit's
## Upgrade choices and upgrade for free through the exact bound callback.
func _test_newer_hero_pool_upgrade() -> void:
	_check(not RunRestStitchCards.resolve_card_definition(V3_POOL).is_empty(),
		"authentic newer-hero pool fixture")
	var catalog := LanternMonkPoolCards.new()
	var base_def: Dictionary = catalog.get_definition(V3_POOL)
	var plus_id: String = String(base_def.get("upgrade_id", ""))
	var plus_def: Dictionary = catalog.get_definition(plus_id)
	_check(not base_def.is_empty() and not plus_def.is_empty()
		and base_def.get("owner") == "lantern_monk"
		and base_def.get("cost") == 1 and plus_def.get("cost") == 0,
		"authored Moth Lure pair carries the genuine 1-to-0 cost change")
	if plus_id.is_empty() or plus_def.is_empty():
		return
	var deck := [STRIKE, V3_POOL, PRICK, POOL]
	var v := _make(deck)
	var s := v.read_state()
	_check(v.is_valid() and not v.is_consumed(), "newer-hero pool visit opens")
	_check(v.quote().choices == ["upgrade", "stitch", "leave"],
		"newer-hero pool visit quotes all three decisions")
	var canonical := RunRestCardUpgrade.list_authored_choices(deck, {}, 1)
	_check(not canonical.choices.is_empty() and v.upgrade_options() == canonical.choices,
		"exact canonical upgrades include the newer-hero pool card")
	var matched: Array = []
	for offered in v.upgrade_options():
		if offered.source_id == V3_POOL:
			matched.append(offered)
	_check(matched.size() == 1, "exactly one owned newer-hero pool copy offered")
	if matched.size() != 1:
		return
	var option: Dictionary = matched[0]
	_check(option.index == 1 and option.plus_id == plus_id
		and option.owner == "lantern_monk" and option.cost == 1 and option.plus_cost == 0
		and option.effects == base_def.effects and option.plus_effects == plus_def.effects,
		"newer-hero upgrade choice carries exact catalog metadata")
	var result := _upgrade(v, 1, s)
	var expected: Array = s.deck.duplicate()
	expected[1] = plus_id
	_check(result.get("ok", false) and result.deck == expected,
		"only the indexed newer-hero pool card changes")
	_check(result.remaining_scraps == 7 and result.descriptors == {}
		and result.next_stitch_id == 1 and result.charged_scraps == 0,
		"upgrade is free and preserves the whole remaining ledger")
	_check(result.source_snapshot == s and result.source_receipt == s.receipt and result.consumed,
		"complete bound receipt for the newer-hero upgrade")
	var after := v.read_state()
	_check(not _stitch(v, 0, 2, s).ok and not _upgrade(v, 1, s).ok and not _leave(v, s).ok
		and v.read_state() == after and v.quote().choices.is_empty(),
		"consumed visit rejects duplicate and all later requests")
	var stale := s.duplicate(true)
	stale.remaining_scraps += 1
	_check(not _upgrade(v, 1, stale).ok and v.read_state() == after,
		"stale snapshot request fails after consumption")


func _test_stitches() -> void:
	for pair in [[2, 1], [3, 0]]:
		var v := _make()
		var s := v.read_state()
		var rest := RunRestStitchCards.new(s.deck, s.descriptors, s.remaining_scraps, s.next_stitch_id)
		var model := RunRestStitchPairOptions.new(rest, rest.get_snapshot())
		_check(not model.first_options().is_empty() and v.stitch_first_options() == model.first_options(), "exact first instances")
		_check(v.stitch_second_options(pair[0]) == model.second_options(pair[0]), "exact cross-owner partners")
		var preview := v.stitch_preview(pair[0], pair[1])
		_check(not preview.is_empty() and preview == model.preview(pair[0], pair[1]), "canonical ordered preview")
		preview.first_half.effects.clear()
		_check(v.stitch_preview(pair[0], pair[1]) == model.preview(pair[0], pair[1]), "detached preview")
		var expected := rest.choose_stitch(pair[0], pair[1], rest.get_snapshot())
		var result := _stitch(v, pair[0], pair[1], s)
		_check(result.ok and result.transaction == expected and result.deck == expected.deck
			and result.descriptors == expected.descriptors, "canonical starter/pool stitch commit")
		_check(result.deck.size() == s.deck.size() - 1 and result.remaining_scraps == 4
			and result.charged_scraps == 3 and result.next_stitch_id == 2, "exact stitch costs and cursor")
		_check(result.transaction.descriptor.half_ids == [s.deck[pair[0]], s.deck[pair[1]]], "selected half order preserved")
		var after := v.read_state()
		_check(not _stitch(v, pair[0], pair[1], s).ok and not _leave(v, s).ok
			and not _upgrade(v, 0, s).ok and v.read_state() == after, "stitch latches all decisions")
		var mixed := _make(result.deck, 4, result.descriptors, 2)
		var ms := mixed.read_state()
		var composite_index: int = ms.deck.find(expected.stitched_id)
		_check(mixed.is_valid() and composite_index >= 0, "authentic composite ledger admitted")
		var remaining := mixed.upgrade_options()
		_check(not remaining.is_empty(), "mixed ledger has a real surviving upgrade")
		var upgrade_visit := _make(ms.deck, 4, ms.descriptors, 2)
		var upgraded := _upgrade(upgrade_visit, remaining[0].index, upgrade_visit.read_state())
		_check(upgraded.ok and upgraded.descriptors == ms.descriptors
			and upgraded.remaining_scraps == 4 and upgraded.next_stitch_id == 2,
			"upgrade preserves existing authentic registry and cursor")
		var forged_registry: Dictionary = ms.descriptors.duplicate(true)
		forged_registry[expected.stitched_id].first_half.effects.clear()
		_check(not _make(ms.deck, 4, forged_registry, 2).is_valid(), "counterfeit nested half rejected at open")
		_check(not _make(ms.deck, 4, ms.descriptors, 1).is_valid(), "stale allocator rejected at open")
		for option in mixed.upgrade_options():
			_check(option.index != composite_index, "composite excluded from upgrades")
		for option in mixed.stitch_first_options():
			_check(option.index != composite_index, "composite excluded from stitching")
		_check(not _upgrade(mixed, composite_index, ms).ok and not _stitch(mixed, composite_index, 2, ms).ok
			and mixed.read_state() == ms, "composite rejections leave visit open")
		result.descriptors[expected.stitched_id].first_half.effects.clear()
		_check(v.read_state() == after and mixed.read_state() == ms, "nested registry copied at input and output")
		var leave := _leave(mixed, ms)
		_check(leave.ok and leave.deck == ms.deck and leave.descriptors == ms.descriptors
			and leave.remaining_scraps == 4 and leave.next_stitch_id == 2, "Leave preserves composite ledger")


func _test_rejections() -> void:
	var exact := _make([STRIKE, PRICK], 3)
	_check(_stitch(exact, 0, 1, exact.read_state()).remaining_scraps == 0, "exact three-scrap boundary")
	var same_owner := _make([STRIKE, STRIKE])
	_check(same_owner.is_valid() and same_owner.stitch_first_options().is_empty()
		and same_owner.stitch_second_options(0).is_empty(), "same-owner deck has no stitch selections")
	var v := _make()
	var s := v.read_state()
	for key in s:
		var stale := s.duplicate(true)
		match key:
			"deck": stale.deck.reverse()
			"descriptors": stale.descriptors["forged"] = {}
			"remaining_scraps": stale[key] += 1
			"next_stitch_id": stale[key] += 1
			"valid", "consumed": stale[key] = not stale[key]
			_: stale[key] += "tampered"
		_check(stale != s, "nonvacuous altered snapshot " + key)
		_check(not _upgrade(v, 0, stale).ok and not _stitch(v, 0, 2, stale).ok
			and not _leave(v, stale).ok and v.read_state() == s, "all actions reject altered " + key)
	for bad in [null, 1, "foreign"]:
		_check(not v.choose_upgrade(0, bad, NODE, s).ok and not v.choose_stitch(0, 2, s.visit_id, bad, s).ok
			and not v.leave(bad, NODE, s).ok and v.read_state() == s, "wrong visit/node rejects")
	var other := _make(s.deck, 7, {}, 1, "other-node")
	_check(not _upgrade(other, 0, s).ok and not other.is_consumed(), "cross-node callback rejects")
	var reopened := _make()
	_check(reopened.is_valid() and reopened.read_state().visit_id != s.visit_id
		and not _upgrade(reopened, 0, s).ok and not _stitch(reopened, 0, 2, s).ok
		and not _leave(reopened, s).ok and not reopened.is_consumed(), "identical later visit rejects old callbacks")
	for index in [null, "0", 0.0, -1, 99]:
		_check(not _upgrade(v, index, s).ok and not _stitch(v, index, 2, s).ok
			and not _stitch(v, 0, index, s).ok and v.read_state() == s, "invalid instance index rejects")
	_check(not _stitch(v, 0, 0, s).ok and not _stitch(v, 0, 1, s).ok and v.read_state() == s, "same-instance and same-owner reject")
	for scraps in [0, 2]:
		var poor := _make([STRIKE, PRICK], scraps)
		var ps := poor.read_state()
		_check(poor.is_valid() and poor.stitch_first_options().is_empty() and poor.stitch_preview(0, 1).is_empty(), "poor ledger opens without payable stitch")
		_check(not _stitch(poor, 0, 1, ps).ok and poor.read_state() == ps, "insufficient scraps preserve open ledger")
		_check(_upgrade(poor, 0, ps).ok, "failed stitch permits later free upgrade")
	var left := _leave(v, s)
	_check(left.ok and left.action == "leave" and left.charged_scraps == 0
		and left.deck == s.deck and left.remaining_scraps == s.remaining_scraps, "Leave spends nothing after failures")
	var after := v.read_state()
	_check(not _leave(v, s).ok and not _upgrade(v, 0, s).ok and not _stitch(v, 0, 2, s).ok
		and v.read_state() == after, "Leave latches once")
	var detached := _make()
	var original := detached.read_state()
	var state := detached.read_state()
	state.deck.clear()
	var first := detached.stitch_first_options()
	first[0].id = "forged"
	var second := detached.stitch_second_options(0)
	second.clear()
	var quote := detached.quote()
	quote.choices.clear()
	_check(detached.read_state() == original and not detached.stitch_second_options(0).is_empty()
		and detached.quote().choices.size() == 3, "state and all options detached")


func _test_invalid() -> void:
	for args in [[null, [STRIKE], {}, 3, 1], ["", [STRIKE], {}, 3, 1],
		[" padded ", [STRIKE], {}, 3, 1], [NODE, [], {}, 3, 1],
		[NODE, ["unknown"], {}, 3, 1], [NODE, [STRIKE], {}, -1, 1],
		[NODE, [STRIKE], {}, 3.0, 1], [NODE, [STRIKE], {}, 3, 0],
		[NODE, [STRIKE], {}, 3, 1.0], [NODE, [STRIKE], {"orphan": {}}, 3, 2],
		[NODE, ["stitched_000001"], {"stitched_000001": {}}, 3, 2]]:
		var v := RunSewingCircleVisit.new(args[0], args[1], args[2], args[3], args[4])
		_check(not v.is_valid() and not v.quote().ok and v.upgrade_options().is_empty()
			and v.stitch_first_options().is_empty() and not _leave(v, v.read_state()).ok, "malformed ledger/node fails closed")
