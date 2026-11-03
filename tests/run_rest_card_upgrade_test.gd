extends SceneTree
## Deterministic headless test for RunRestCardUpgrade (M04 Rest upgrade choice).
## The replacement ID "fixture_warden_strike_upgraded" is a transaction-test
## marker only: it is never an authored playable card and never enters combat.

const UPGRADED_ID := "fixture_warden_strike_upgraded"
const STRIKE_ID := "warden_strike"
const PRICK_ID := "seamstress_prick"
const RNG_SEED := 90210
const SERVICE_PATH := "res://scripts/run_rest_card_upgrade.gd"
const FORBIDDEN_SOURCE_TOKENS: Array[String] = [
	"randi", "randf", "seed(", "randomize", "RandomNumberGenerator",
	"res://scenes", ".tscn", "preload(",
	"CombatDeck", "CombatParty", "gold", "hp", "HP",
	"app.gd", "run_map", "run_rest_recovery",
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_frayed_debt_upgrades()
	_test_peddler_v3_upgrades()
	_test_authored_pool_upgrade_cases()
	_test_v3_seamstress_upgrades()
	_test_newer_hero_pool_upgrade_cases()
	_test_pool_mapping_and_membership_rejections()
	_test_pool_plus_in_stitched_upgrade_ledger()
	_test_real_mixed_upgrade_and_composite_rejection()
	_test_mixed_invalid_ledgers_and_isolation()
	_test_public_contract()
	_test_one_copy_replacement()
	_test_replay_identical_results()
	_test_second_use_rejected()
	_test_invalid_selections_leave_choice_available()
	_test_invalid_decks_and_mappings()
	_test_caller_container_isolation()
	_test_result_isolation()
	_test_non_selection_stays_open()
	_test_no_rng_consumption()
	_test_service_source_boundaries()
	_test_combat_deck_from_original_unaffected()
	_test_run_state_untouched()
	_test_list_authored_choices_plain_and_mixed()
	_test_starter_support_upgrade_pairs()
	_test_choice_map_integration_and_canonical_authoring()
	_test_list_authored_choices_negative_and_isolation()
	_finish()


func _test_v3_seamstress_upgrades() -> void:
	_check_v3_seamstress_upgrades(V3SeamstressPoolCards.new())
	_check_v3_seamstress_upgrades(V3SeamstressStarterCards.new())


func _check_v3_seamstress_upgrades(pool: Object) -> void:
	var ids: Array = pool.get_starting_deck() if pool is V3SeamstressStarterCards else pool.get_base_ids()
	_check(not ids.is_empty(), "V3 upgrade catalog loaded")
	for base_id in ids:
		var plus_id: String = pool.get_upgrade_id(base_id)
		var base: Dictionary = pool.get_definition(base_id)
		var plus: Dictionary = pool.get_definition(plus_id)
		var deck := [base_id, "warden_strike", base_id]
		var before := deck.duplicate()
		var projection := RunRestCardUpgrade.list_authored_choices(deck)
		_check(projection.ok and projection.permitted_upgrades.get(base_id) == plus_id
			and projection.choices.size() == 3, "V3 choices list both owned occurrences: " + base_id)
		var matches: Array = []
		for row in projection.choices:
			if row.source_id == base_id:
				matches.append(row.index)
				_check(row.owner == base.owner and row.effects == base.effects and row.plus_effects == plus.effects
					and row.cost == base.cost and row.plus_cost == plus.cost
					and row.plus_display_name == plus.display_name, "V3 exact choice metadata")
		_check(matches == [0, 2], "V3 choices preserve original occurrence indices")
		var visit := RunRestCardUpgrade.new(deck, projection.permitted_upgrades)
		_assert_rejected(visit, -1, deck, "V3 invalid index leaves visit open")
		var result := visit.choose_upgrade(2)
		_check(result.ok and result.deck == [base_id, "warden_strike", plus_id] and deck == before,
			"V3 upgrades only selected duplicate occurrence")
		_assert_rejected_while_used(visit, 0, deck, "V3 used upgrade visit")
		_check(RunRestCardUpgrade.list_authored_choices(result.deck).ok, "V3 upgraded deck reloads")
		_assert_rejected(RunRestCardUpgrade.new([plus_id], {plus_id: base_id}), 0, [plus_id],
			"V3 plus cannot be upgraded again or downgraded")
		for forged in [base_id + "_fake_plus", "seamstress_running_stitch_plus", "warden_iron_hem_plus"]:
			_assert_rejected(RunRestCardUpgrade.new(deck, {base_id: forged}), 2, deck,
				"V3 forged/cross-catalog plus mapping")
		_check(RunRestCardUpgrade.new(deck, projection.permitted_upgrades).choose_upgrade(2) == result,
			"V3 upgrade deterministic replay")


func _test_frayed_debt_upgrades() -> void:
	var curse := MpwFrayedDebt.CARD_ID
	var earned := _earned_mixed_ledger()
	if earned.get("ok") != true:
		return
	for mixed in [false, true]:
		var deck: Array = earned["deck"].duplicate() if mixed else _load_starter_deck()
		deck.append(curse)
		var registry: Variant = earned["descriptors"] if mixed else null
		var cursor: Variant = earned["next_stitch_id"] if mixed else null
		var before := deck.duplicate(true)
		var projection := RunRestCardUpgrade.list_authored_choices(deck, registry, cursor)
		_check(projection.get("ok") == true, "curse plain/mixed upgrade projection admitted")
		var permitted: Dictionary = projection.get("permitted_upgrades", {}).duplicate()
		_check(not permitted.has(curse) and permitted.get(STRIKE_ID) == "warden_strike_plus", "curse excluded while real upgrade available")
		for choice in projection.get("choices", []):
			_check(choice.get("source_id") != curse, "curse absent from authored choices")
		permitted[curse] = "warden_strike_plus"
		var visit := RunRestCardUpgrade.new(deck, permitted, registry, cursor)
		_assert_rejected(visit, deck.find(curse), deck, "forged curse upgrade is atomic")
		var result := visit.choose_upgrade(deck.find(STRIKE_ID))
		_check(result.get("ok") == true and result.get("deck", []).count(curse) == 1,
			"real upgrade succeeds after refused curse upgrade")
		var replay := RunRestCardUpgrade.new(deck, permitted, registry, cursor)
		_check(replay.choose_upgrade(deck.find(STRIKE_ID)) == result and deck == before, "curse upgrade seeded-independent replay and source isolation")
		_assert_rejected_while_used(visit, deck.find(STRIKE_ID), deck, "curse deck upgrade is single-use")
		var forged := deck.duplicate()
		forged[forged.find(curse)] = curse + "_plus"
		_check(RunRestCardUpgrade.list_authored_choices(forged, registry, cursor).get("ok") == false, "forged curse ID fails projection")


## Peddler-sold V3 Warden/Tinker printings: genuine upgrades, never rewards.
func _test_peddler_v3_upgrades() -> void:
	var warden := V3WardenPoolCards.new()
	var tinker := V3TinkerPoolCards.new()
	var families: Array = [
		[warden, warden.get_base_ids(), "warden"],
		[tinker, tinker.get_pool_card_ids(), "tinker"],
	]
	for family in families:
		var pool: Object = family[0]
		var ids: Array = family[1]
		_check(not ids.is_empty(), "V3 peddler catalog loaded: " + family[2])
		for base_id in ids:
			var plus_id: String = pool.get_upgrade_id(base_id)
			var base: Dictionary = pool.get_definition(base_id)
			var plus: Dictionary = pool.get_definition(plus_id)
			_check(not plus_id.is_empty() and not plus.is_empty() and base.owner == family[2],
				"V3 pair resolves from catalog: " + base_id)
			_check(RunPoolCardRewardOffers.resolve_reward_definition(base_id).is_empty(),
				"purchased V3 base is not a Fight reward: " + base_id)
			var deck := [base_id, STRIKE_ID, base_id, plus_id]
			var before := deck.duplicate()
			var projection := RunRestCardUpgrade.list_authored_choices(deck)
			_check(projection.ok and projection.permitted_upgrades.get(base_id) == plus_id,
				"V3 peddler base admitted: " + base_id)
			var offered: Array = []
			for row in projection.choices:
				if row.source_id == base_id:
					offered.append(row.index)
					_check(row.plus_id == plus_id and row.owner == base.owner
						and row.display_name == base.display_name and row.cost == base.cost
						and row.plus_cost == plus.cost and row.effects == base.effects
						and row.plus_effects == plus.effects, "V3 peddler exact metadata: " + base_id)
				_check(row.source_id != plus_id, "plus never offered again: " + plus_id)
			_check(offered == [0, 2], "V3 peddler duplicates keep indices: " + base_id)
			var visit := RunRestCardUpgrade.new(deck, projection.permitted_upgrades)
			_assert_rejected(visit, 3, deck, "already-plus V3 printing refused")
			_assert_rejected(visit, 99, deck, "V3 out-of-range index refused")
			var result := visit.choose_upgrade(2)
			_check(result.ok and result.deck == [base_id, STRIKE_ID, plus_id, plus_id]
				and result.original_id == base_id and result.upgraded_id == plus_id
				and deck == before, "V3 peddler upgrades one occurrence: " + base_id)
			_assert_rejected_while_used(visit, 0, deck, "V3 peddler visit single-use")
			# Fabricated and cross-owner/catalog mappings fail closed.
			var cross: String = "warden_strike_plus" if family[2] == "tinker" else "tinker_pop_shot_plus"
			var other_pool: Object = tinker if family[2] == "warden" else warden
			var other_ids: Array = other_pool.get_pool_card_ids() if family[2] == "warden" else other_pool.get_base_ids()
			var other_plus: String = other_pool.get_upgrade_id(other_ids[0])
			for forged in [base_id + "_fake_plus", cross, other_plus, base_id]:
				_assert_rejected(RunRestCardUpgrade.new(deck, {base_id: forged}), 0, deck,
					"V3 forged mapping refused: " + str(forged))
			_assert_rejected(RunRestCardUpgrade.new(deck, {plus_id: base_id}), 3, deck,
				"V3 plus cannot downgrade or re-upgrade")
		# A forged "_plus" ID is not a deck member.
		_check(RunRestCardUpgrade.list_authored_choices([ids[0] + "_fake_plus"]).ok == false,
			"fabricated V3 plus ID rejected from plain deck")
	# Witness numbers straight from the authored cards.
	var toss: Dictionary = warden.get_definition("warden_v3_shield_toss")
	var toss_plus: Dictionary = warden.get_definition("warden_v3_shield_toss_plus")
	_check(toss.cost == 1 and toss.from_positions == [1, 2] and toss.to_positions == [1, 2, 3]
		and toss_plus.effects.get("bonus_damage") == 3, "Shield Toss witness")
	var casing: Dictionary = tinker.get_definition("tinker_v3_brass_casing")
	var casing_plus: Dictionary = tinker.get_definition("tinker_v3_brass_casing_plus")
	_check(casing.effects == {"damage": 4, "combat_scrap_gain": 1}
		and casing_plus.effects == {"damage": 6, "combat_scrap_gain": 1}, "Brass Casing witness")
	# Stitched-ledger admission beside owned purchased bases.
	var stitcher := RunRestStitchCards.new([toss.id, casing.id, PRICK_ID, toss.id], {}, 3, 1)
	var stitched := stitcher.choose_stitch(0, 1, stitcher.get_snapshot())
	_check(stitched.get("ok", false) == true, "V3 Warden + Tinker stitch succeeds for ledger fixture")
	if stitched.get("ok", false):
		var ledger_projection := RunRestCardUpgrade.list_authored_choices(
			stitched.deck, stitched.descriptors, stitched.next_stitch_id)
		_check(ledger_projection.ok, "stitched ledger with purchased base admitted")
		var offered_ids: Array = []
		for row in ledger_projection.choices:
			offered_ids.append(row.source_id)
		_check(offered_ids.has(toss.id) and not offered_ids.has(stitched.stitched_id),
			"purchased base offered, stitched card not")
		var ledger_visit := RunRestCardUpgrade.new(stitched.deck, ledger_projection.permitted_upgrades,
			stitched.descriptors, stitched.next_stitch_id)
		var stitched_index: int = stitched.deck.find(stitched.stitched_id)
		_assert_rejected(ledger_visit, stitched_index, stitched.deck, "stitched card cannot upgrade")
		var base_index: int = stitched.deck.find(toss.id)
		var ledger_result := ledger_visit.choose_upgrade(base_index)
		_check(ledger_result.ok and ledger_result.deck[base_index] == toss_plus.id,
			"ledger upgrade of purchased base commits")


func _finish() -> void:
	if failures.is_empty():
		print("run_rest_card_upgrade_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_rest_card_upgrade_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_starter_deck() -> Array[String]:
	var file := FileAccess.open("res://data/cards/starter_deck.json", FileAccess.READ)
	_check(file != null, "starter_deck.json opens")
	var text := file.get_as_text() if file != null else ""
	if file != null:
		file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text) if text != "" else ERR_PARSE_ERROR
	var data = parser.data if parse_result == OK else []
	if not data is Array:
		return []
	var deck: Array[String] = []
	for item in data:
		if item is String:
			deck.append(item)
	return deck


func _strike_indices(deck: Array) -> Array[int]:
	var found: Array[int] = []
	for i in range(deck.size()):
		if deck[i] == STRIKE_ID:
			found.append(i)
	return found


func _first_non_strike(deck: Array) -> int:
	for i in range(deck.size()):
		if deck[i] != STRIKE_ID:
			return i
	return -1


func _fixture_mapping() -> Dictionary:
	return {STRIKE_ID: UPGRADED_ID}


func _expected_replaced(base: Array, index: int, value: String) -> Array:
	var expected: Array = base.duplicate()
	expected[index] = value
	return expected


## Content equality across typed/untyped arrays; 42 and "42" never compare equal.
func _decks_equal(a: Variant, b: Variant) -> bool:
	if not a is Array or not b is Array:
		return false
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true


func _is_ok(result: Variant) -> bool:
	return result is Dictionary and result.has("ok") and result["ok"] == true


## Rejects missing "ok" outright so a malformed result cannot pass vacuously.
func _is_rejected(result: Variant) -> bool:
	return result is Dictionary and result.has("ok") and result["ok"] == false


func _method_argument_count(service: Object, method: String) -> int:
	for entry in service.get_method_list():
		if typeof(entry) == TYPE_DICTIONARY and entry.get("name", "") == method:
			var args: Variant = entry.get("args", null)
			if args is Array:
				return args.size()
			return -1
	return -1


## Every rejection must return the full documented shape, an unchanged detached
## snapshot of the source deck, and leave an unused visit unconsumed.
func _assert_rejected(service: RunRestCardUpgrade, index: Variant, expected_deck: Variant, context: String) -> void:
	_assert_rejection(service, index, expected_deck, context, false)


## Rejection after the visit has already latched must keep the latch and still
## return the untouched original snapshot.
func _assert_rejected_while_used(service: RunRestCardUpgrade, index: Variant, expected_deck: Variant, context: String) -> void:
	_assert_rejection(service, index, expected_deck, context, true)


func _assert_rejection(service: RunRestCardUpgrade, index: Variant, expected_deck: Variant, context: String, expect_consumed: bool) -> void:
	var result: Variant = service.choose_upgrade(index)
	_check(result is Dictionary, context + ": result is a dictionary")
	if not result is Dictionary:
		return
	_check(result.has("ok") and result.has("deck") and result.has("original_id") and result.has("upgraded_id"),
		context + ": result carries the documented keys")
	_check(result.has("ok") and result["ok"] == false, context + ": selection rejected")
	_check(service.is_consumed() == expect_consumed,
		context + ": visit consumed state is %s" % str(expect_consumed))
	_check(result.has("deck") and _decks_equal(result["deck"], expected_deck),
		context + ": returns a detached unchanged source snapshot")
	_check(expected_deck is Array, context + ": snapshot expectation is a deck")


func _test_public_contract() -> void:
	var source := _load_starter_deck()
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	_check(service.has_method("choose_upgrade"), "public choose_upgrade method exists")
	_check(service.has_method("is_consumed"), "public is_consumed method exists")
	_check(not service.is_consumed(), "fresh visit starts unconsumed")
	_check(_method_argument_count(service, "choose_upgrade") == 1,
		"choose_upgrade takes exactly one argument (the index): no randomness or state arguments")
	_check(_method_argument_count(service, "is_consumed") == 0, "is_consumed takes no arguments")
	# Fail-closed default construction: empty deck is an invalid deck.
	_assert_rejected(RunRestCardUpgrade.new(), 0, [], "no-argument construction")
	_check(service.has_method("list_authored_choices"), "public list_authored_choices method exists")


func _test_one_copy_replacement() -> void:
	var source := _load_starter_deck()
	_check(source.size() >= 2, "real starter deck loaded nonempty")
	_check(source.has(STRIKE_ID), "authored deck contains Warden Strike")
	var catalog := StarterCards.new()
	# Every entry is an authored card held at its authored multiplicity
	# (read from the catalog, never a hardcoded deck total).
	var seen := {}
	for card_id in source:
		seen[card_id] = int(seen.get(card_id, 0)) + 1
	for card_id in seen:
		_check(catalog.has_card(card_id), "deck entry is an authored card: " + str(card_id))
		if catalog.has_card(card_id):
			_check(seen[card_id] == int(catalog.get_definition(card_id).get("starting_copies", -1)),
				"deck holds the authored copies of " + str(card_id))
	var strikes := _strike_indices(source)
	_check(strikes.size() >= 2, "both Warden Strike copies present at distinct indices")
	if strikes.size() < 2:
		return
	_check(strikes.size() == int(catalog.get_definition(STRIKE_ID).get("starting_copies", -1)),
		"deck holds exactly the catalog's Strike copies")
	_check(not catalog.has_card(UPGRADED_ID),
		"fixture replacement ID is not an authored playable card")
	_check(not source.has(UPGRADED_ID), "fixture replacement ID absent from the source deck")

	var source_copy := source.duplicate()
	var target: int = strikes[1]
	var other_strike: int = strikes[0]
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	var result: Variant = service.choose_upgrade(target)
	_check(result is Dictionary and result.has("ok") and result["ok"] == true,
		"second Strike copy upgrades successfully")
	if not result is Dictionary:
		return
	_check(result.has("original_id") and result["original_id"] == STRIKE_ID,
		"original ID of the selected copy identified")
	_check(result.has("upgraded_id") and result["upgraded_id"] == UPGRADED_ID,
		"mapped upgraded ID returned")
	var upgraded: Variant = result.get("deck", null)
	_check(upgraded is Array, "result carries a deck")
	if not upgraded is Array:
		return
	_check(upgraded.size() == source_copy.size(), "deck length preserved")
	_check(upgraded[target] == UPGRADED_ID, "the selected index alone carries the replacement ID")
	_check(upgraded[other_strike] == STRIKE_ID, "the other Strike copy remains the original ID")
	var differences := 0
	for i in range(source_copy.size()):
		if upgraded[i] != source_copy[i]:
			differences += 1
	_check(differences == 1, "exactly one position changed; all other copies and ordering preserved")
	_check(service.is_consumed(), "success latches the visit")
	_check(_decks_equal(source, source_copy), "caller source deck unchanged by the upgrade")


func _test_replay_identical_results() -> void:
	var deck_a := _load_starter_deck()
	var deck_b := _load_starter_deck()
	var strikes_a := _strike_indices(deck_a)
	var strikes_b := _strike_indices(deck_b)
	if strikes_a.size() < 2 or strikes_b.size() < 2:
		_check(false, "guard: both Strike copies available for replay")
		return
	_check(strikes_a == strikes_b, "fresh deck loads are deterministic")
	var service_a := RunRestCardUpgrade.new(deck_a, {"warden_strike": UPGRADED_ID})
	var service_b := RunRestCardUpgrade.new(deck_b, _fixture_mapping())
	var result_a: Variant = service_a.choose_upgrade(strikes_a[1])
	var result_b: Variant = service_b.choose_upgrade(strikes_b[1])
	_check(_is_ok(result_a), "replay instance A succeeds")
	_check(_is_ok(result_b), "replay instance B succeeds")
	_check(result_a == result_b, "fresh instance replays the entire result identically")
	_check(service_a.is_consumed() and service_b.is_consumed(),
		"both independent instances latch")


func _test_second_use_rejected() -> void:
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for second-use test")
		return
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	var first: Variant = service.choose_upgrade(strikes[1])
	_check(_is_ok(first), "first selection succeeds")
	# Replay of the very same index.
	_assert_rejected_while_used(service, strikes[1], source_copy, "replay of the first index")
	# Another Strike index.
	_assert_rejected_while_used(service, strikes[0], source_copy, "other Strike index after success")
	# A completely different card index.
	var non_strike := _first_non_strike(source)
	if non_strike >= 0:
		_assert_rejected_while_used(service, non_strike, source_copy, "unrelated index after success")
	_check(service.is_consumed(), "latch retained after every rejected second selection")
	_check(_decks_equal(source, source_copy),
		"rejected second selections never changed the source deck")
	# The failed results return the untouched source, never a replacement.
	for attempt in [
		service.choose_upgrade(strikes[1]),
		service.choose_upgrade(strikes[0]),
	]:
		_check(attempt is Dictionary and attempt.has("ok") and attempt["ok"] == false,
			"failed second selection reports rejection")
		_check(attempt is Dictionary and _decks_equal(attempt.get("deck", null), source_copy),
			"failed second selection returns the untouched source deck")


func _test_invalid_selections_leave_choice_available() -> void:
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for invalid-selection test")
		return
	var non_strike := _first_non_strike(source)
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	_assert_rejected(service, -1, source_copy, "negative index")
	_assert_rejected(service, source.size(), source_copy, "index at deck size")
	_assert_rejected(service, source.size() + 7, source_copy, "index beyond deck")
	_assert_rejected(service, "1", source_copy, "string index")
	_assert_rejected(service, 1.5, source_copy, "fractional index")
	_assert_rejected(service, null, source_copy, "null index")
	if non_strike >= 0:
		_assert_rejected(service, non_strike, source_copy, "index without a permitted mapping entry")
	# None of the rejections spent the visit: a legal selection still succeeds.
	var late: Variant = service.choose_upgrade(strikes[1])
	_check(_is_ok(late), "legal selection succeeds after every rejected selection")
	_check(service.is_consumed(), "eventual success latches the visit")
	_check(_decks_equal(late.get("deck", null), _expected_replaced(source_copy, strikes[1], UPGRADED_ID)),
		"late success performs exactly the single replacement")
	_check(_decks_equal(source, source_copy), "source deck unchanged across all rejected selections")


func _test_invalid_decks_and_mappings() -> void:
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for invalid-input test")
		return
	var strike_index: int = strikes[1]
	var non_strike := _first_non_strike(source)

	# Malformed initial decks: every attempt is rejected and never latches.
	var malformed_decks: Array = [
		[],
		["warden_strike", "unauthored_card_id_zzz"],
		["warden_strike", 42],
		["warden_strike", ""],
		["warden_strike", null],
		[42, "warden_strike"],
		[null, null],
	]
	for i in range(malformed_decks.size()):
		var bad: Variant = malformed_decks[i]
		var bad_snapshot: Variant = bad.duplicate(true)
		var bad_service := RunRestCardUpgrade.new(bad, _fixture_mapping())
		_assert_rejected(bad_service, 0, bad_snapshot, "malformed deck case %d" % i)
		_assert_rejected(bad_service, 1, bad_snapshot, "malformed deck case %d repeat" % i)
		_check(_decks_equal(bad, bad_snapshot), "malformed deck case %d never mutated" % i)

	# Non-array deck inputs yield no fabricated deck and never latch.
	for bad_input in [null, "warden_strike", 12]:
		var non_array_service := RunRestCardUpgrade.new(bad_input, _fixture_mapping())
		_assert_rejected(non_array_service, 0, [], "non-array deck input %s" % str(bad_input))

	# Mapping defects against a fully valid deck and index.
	var mapping_probes: Array = [
		["missing mapping entry", {}],
		["empty replacement ID", {STRIKE_ID: ""}],
		["identical replacement ID", {STRIKE_ID: STRIKE_ID}],
		["non-string replacement value", {STRIKE_ID: 42}],
		["nested non-string replacement value", {STRIKE_ID: {"id": UPGRADED_ID}}],
		["non-string mapping key", {123: UPGRADED_ID}],
		["mapping for a different card only", {PRICK_ID: "fixture_prick_upgraded"}],
	]
	for probe in mapping_probes:
		var context: String = probe[0]
		var probe_service := RunRestCardUpgrade.new(source, probe[1])
		_assert_rejected(probe_service, strike_index, source_copy, context)
		_check(_decks_equal(source, source_copy), context + ": source deck untouched")

	# Non-dictionary mappings are treated as having no permitted entries.
	for bad_mapping in ["not_a_mapping", [STRIKE_ID, UPGRADED_ID], 7]:
		var coerced_service := RunRestCardUpgrade.new(source, bad_mapping)
		_assert_rejected(coerced_service, strike_index, source_copy,
			"non-dictionary mapping %s" % str(bad_mapping))

	# A subset mapping still works: unmapped originals reject, mapped succeeds.
	var subset := RunRestCardUpgrade.new(source, _fixture_mapping())
	if non_strike >= 0:
		_assert_rejected(subset, non_strike, source_copy, "subset mapping rejects unmapped original")
	var subset_ok: Variant = subset.choose_upgrade(strike_index)
	_check(_is_ok(subset_ok), "subset mapping still permits its mapped entry")
	_check(_decks_equal(subset_ok.get("deck", null), _expected_replaced(source_copy, strike_index, UPGRADED_ID)),
		"subset mapping replacement is exact")


func _test_caller_container_isolation() -> void:
	# Mutating the caller's deck and mapping after construction must not change
	# eligibility or the snapshot.
	var mutable_deck := _load_starter_deck()
	var mutable_mapping := _fixture_mapping()
	var strikes := _strike_indices(mutable_deck)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for isolation test")
		return
	var target: int = strikes[1]
	var pristine_copy := mutable_deck.duplicate()
	var service := RunRestCardUpgrade.new(mutable_deck, mutable_mapping)
	mutable_deck[target] = "tinker_tune_up"
	mutable_deck.append("warden_brace")
	mutable_mapping[STRIKE_ID] = "tampered_replacement_id"
	mutable_mapping[PRICK_ID] = "fixture_prick_after_construction"
	mutable_mapping.clear()
	var result: Variant = service.choose_upgrade(target)
	_check(_is_ok(result), "deep-copied snapshot still upgrades after caller mutation")
	_check(result is Dictionary and result.has("original_id") and result["original_id"] == STRIKE_ID,
		"snapshot deck entry preserved despite caller edit")
	_check(result is Dictionary and result.has("upgraded_id") and result["upgraded_id"] == UPGRADED_ID,
		"snapshot mapping value preserved despite caller edit")
	_check(_decks_equal(result.get("deck", null), _expected_replaced(pristine_copy, target, UPGRADED_ID)),
		"result built from the pristine snapshot, not the mutated caller array")

	# Adding a mapping entry after construction cannot extend eligibility.
	var deck_two := _load_starter_deck()
	var strikes_two := _strike_indices(deck_two)
	var mapping_two := {}
	var service_two := RunRestCardUpgrade.new(deck_two, mapping_two)
	mapping_two[STRIKE_ID] = UPGRADED_ID
	if strikes_two.size() >= 2:
		_assert_rejected(service_two, strikes_two[1], deck_two,
			"mapping addition after construction does not extend eligibility")

	# Growing the caller deck after construction cannot extend the index range.
	var deck_three := _load_starter_deck()
	var deck_three_copy := deck_three.duplicate()
	var service_three := RunRestCardUpgrade.new(deck_three, _fixture_mapping())
	var former_size := deck_three.size()
	deck_three.append(STRIKE_ID)
	_assert_rejected(service_three, former_size, deck_three_copy,
		"deck growth after construction does not extend the index range")
	_check(deck_three.size() == former_size + 1, "caller deck keeps its own appended copy")
	_check(_decks_equal(deck_three.slice(0, former_size), deck_three_copy),
		"caller deck prefix untouched by the rejected selection")


func _test_result_isolation() -> void:
	# Failure snapshots are detached from each other, the service and the source.
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	var failure_a: Variant = service.choose_upgrade(-1)
	var failure_b: Variant = service.choose_upgrade(-2)
	var failure_c: Variant = service.choose_upgrade(-3)
	_check(_decks_equal(failure_a.get("deck", null), source_copy), "first failure snapshot correct")
	_check(_decks_equal(failure_b.get("deck", null), source_copy), "second failure snapshot correct")
	var deck_a: Variant = failure_a.get("deck", null)
	var deck_b: Variant = failure_b.get("deck", null)
	if deck_a is Array and deck_b is Array:
		deck_a.append("tampered_failure_result")
		_check(_decks_equal(deck_b, source_copy),
			"mutating one failure result leaves the other intact")
		_check(_decks_equal(failure_c.get("deck", null), source_copy),
			"a freshly fetched failure result is unaffected")
	_check(_decks_equal(source, source_copy), "caller source untouched by result mutation")

	# The success result is detached from the caller source and the latch.
	var source_two := _load_starter_deck()
	var source_two_copy := source_two.duplicate()
	var strikes := _strike_indices(source_two)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for result isolation test")
		return
	var service_two := RunRestCardUpgrade.new(source_two, _fixture_mapping())
	var success: Variant = service_two.choose_upgrade(strikes[1])
	_check(_is_ok(success), "isolation upgrade succeeds")
	var success_deck: Variant = success.get("deck", null)
	if success_deck is Array:
		success_deck[strikes[1]] = "tampered_success_result"
		success_deck.append("tampered_success_extra")
	_check(_decks_equal(source_two, source_two_copy),
		"mutating the returned success deck leaves the caller source intact")
	_check(service_two.is_consumed(), "latch cannot be cleared by mutating the returned deck")
	var post: Variant = service_two.choose_upgrade(strikes[1])
	_check(_is_rejected(post), "mutated result deck cannot enable a second selection")
	_check(_decks_equal(post.get("deck", null), source_two_copy),
		"post-success rejection still returns the original snapshot")

	# An independent instance's result is unaffected by the mutated result above.
	var service_three := RunRestCardUpgrade.new(source_two.duplicate(), _fixture_mapping())
	var success_three: Variant = service_three.choose_upgrade(strikes[1])
	_check(_decks_equal(success_three.get("deck", null),
		_expected_replaced(source_two_copy, strikes[1], UPGRADED_ID)),
		"independent instance result unaffected by another instance's mutated result")


func _test_non_selection_stays_open() -> void:
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var mapping := _fixture_mapping()
	var mapping_copy := mapping.duplicate()
	var service := RunRestCardUpgrade.new(source, mapping)
	# A visit may simply never be used (the player takes no upgrade action).
	_check(not service.is_consumed(), "unselected visit stays unconsumed")
	_check(_decks_equal(source, source_copy), "unselected visit leaves the source deck intact")
	_check(mapping == mapping_copy, "unselected visit leaves the caller mapping intact")
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for non-selection test")
		return
	# The choice remains available until it is actually used exactly once.
	var selected: Variant = service.choose_upgrade(strikes[0])
	_check(_is_ok(selected), "unselected visit still upgrades once when used")
	_check(service.is_consumed(), "single use latches the visit")
	_assert_rejected_while_used(service, strikes[1], source_copy, "non-selected visit used only once")


func _test_no_rng_consumption() -> void:
	var source := _load_starter_deck()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for RNG test")
		return
	var strike_index: int = strikes[1]

	# Same global RNG stream production code would use (lesson-proven pattern):
	# capture expected, reseed, run the service without reseeding, compare.
	seed(RNG_SEED)
	var expected_first := randi()
	var expected_second := randi()
	_check(expected_first != expected_second, "sanity: consecutive global draws differ")
	seed(RNG_SEED)
	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	var success: Variant = service.choose_upgrade(strike_index)
	_check(_is_ok(success), "upgrade under RNG probe succeeds")
	var rejected := RunRestCardUpgrade.new(source, _fixture_mapping())
	rejected.choose_upgrade(-1)
	rejected.choose_upgrade(source.size())
	var no_mapping := RunRestCardUpgrade.new(source, {})
	no_mapping.choose_upgrade(strike_index)
	var bad_deck := RunRestCardUpgrade.new([], _fixture_mapping())
	bad_deck.choose_upgrade(0)
	_check(randi() == expected_first,
		"construction, success and rejections consume no global RNG draw")

	# Sensitivity proof: a single injected draw shifts the observed value, so
	# the check above cannot pass vacuously if the service ever draws.
	seed(RNG_SEED)
	randi()
	_check(randi() == expected_second, "probe detects one injected global draw")

	# The public method takes no RNG argument (also asserted in the contract),
	# and the shipped service source uses no randomness at all.
	_check(_method_argument_count(service, "choose_upgrade") == 1,
		"choose_upgrade has no RNG parameter")


func _test_service_source_boundaries() -> void:
	var source_text := FileAccess.get_file_as_string(SERVICE_PATH)
	_check(not source_text.is_empty(), "service source is readable for boundary inspection")
	for token in FORBIDDEN_SOURCE_TOKENS:
		_check(not source_text.contains(token),
			"service keeps its scene-free boundary (absent token: " + token + ")")
	# The service is a scene-free RefCounted rule object.
	var service := RunRestCardUpgrade.new(_load_starter_deck(), _fixture_mapping())
	_check(service is RefCounted, "service is a RefCounted rule object, not a scene node")


func _test_combat_deck_from_original_unaffected() -> void:
	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for combat-deck test")
		return
	# Control combat deck built from the ORIGINAL deck before any upgrade.
	var control_rng := RandomNumberGenerator.new()
	control_rng.seed = 777
	var control := CombatDeck.new(source, control_rng)
	_check(control.start_turn(), "control combat deck starts a turn")
	_check(control.hand.size() == 5, "control deck draws the authored turn hand")

	var service := RunRestCardUpgrade.new(source, _fixture_mapping())
	var upgraded: Variant = service.choose_upgrade(strikes[1])
	_check(_is_ok(upgraded), "upgrade runs before the combat-deck comparison")
	_check(service.is_consumed(), "upgrade latches before the combat-deck comparison")

	# A fresh CombatDeck from the ORIGINAL deck is unaffected by the upgrade.
	var after_rng := RandomNumberGenerator.new()
	after_rng.seed = 777
	var fresh := CombatDeck.new(source, after_rng)
	_check(fresh.start_turn(), "fresh combat deck from the original deck starts a turn")
	_check(fresh.hand == control.hand,
		"same seed and unchanged original deck yield the same hand after the upgrade ran")
	var accounted := fresh.draw_pile.size() + fresh.hand.size() + fresh.discard_pile.size()
	_check(accounted == source.size(), "all original cards accounted for in combat piles")
	var fixture_seen := false
	for card_id in fresh.draw_pile:
		if card_id == UPGRADED_ID:
			fixture_seen = true
	for card_id in fresh.hand:
		if card_id == UPGRADED_ID:
			fixture_seen = true
	for card_id in fresh.discard_pile:
		if card_id == UPGRADED_ID:
			fixture_seen = true
	_check(not fixture_seen,
		"test-only upgraded ID never reaches combat (no combat init with it)")
	_check(_decks_equal(source, source_copy), "original deck data unchanged for combat")


func _test_run_state_untouched() -> void:
	# The upgrade service receives only a deck and a mapping; verify real run
	# data and scalars survive full success and rejection flows unchanged.
	var party_raw := FileAccess.get_file_as_string("res://data/heroes/starter_party.json")
	_check(not party_raw.is_empty(), "authored starter party is readable")
	var party: Variant = JSON.parse_string(party_raw)
	_check(party is Array and party.size() == 3, "starter party parses as three heroes")
	var party_copy: Variant = party.duplicate(true) if party is Array else null
	var session_gold := 57
	var map_position := 3

	var source := _load_starter_deck()
	var source_copy := source.duplicate()
	var strikes := _strike_indices(source)
	if strikes.size() < 2:
		_check(false, "guard: both Strike copies available for run-state test")
		return
	var success := RunRestCardUpgrade.new(source, _fixture_mapping())
	_check(_is_ok(success.choose_upgrade(strikes[1])), "run-state probe upgrade succeeds")
	var rejected := RunRestCardUpgrade.new(source, _fixture_mapping())
	rejected.choose_upgrade(-1)
	rejected.choose_upgrade(source.size())
	rejected.choose_upgrade("warden_strike")
	var empty := RunRestCardUpgrade.new([], _fixture_mapping())
	empty.choose_upgrade(0)

	if party is Array:
		_check(party == party_copy, "hero HP/status data untouched by upgrade flows")
	_check(session_gold == 57, "gold untouched by upgrade flows")
	_check(map_position == 3, "map position untouched by upgrade flows")
	_check(_decks_equal(source, source_copy), "run deck untouched by rejected flows")
	_check(success.is_consumed() and not rejected.is_consumed() and not empty.is_consumed(),
		"latch state matches exactly one successful selection")


## Real Rest stitch receipt, never a fabricated stitched name or descriptor.
func _earned_mixed_ledger() -> Dictionary:
	var starting := _load_starter_deck()
	var prick := starting.find(PRICK_ID)
	var pop := starting.find("tinker_pop_shot")
	_check(prick >= 0 and pop >= 0 and prick != pop, "mixed fixture uses real different-owner source indices")
	if prick < 0 or pop < 0 or prick == pop:
		return {}
	var stitch := RunRestStitchCards.new(starting, {}, 3)
	_check(stitch.is_valid(), "actual Rest stitch admits authored starter deck")
	var result := stitch.choose_stitch(prick, pop, stitch.get_snapshot())
	_check(result.get("ok") == true and stitch.is_consumed(), "real Rest stitches two ordinary copies for three scraps")
	_check(result.get("remaining_scraps") == 0 and result.get("next_stitch_id") == 2
		and result.get("stitched_id") == "stitched_000001", "authentic ledger and cursor")
	return result


func _test_real_mixed_upgrade_and_composite_rejection() -> void:
	var earned := _earned_mixed_ledger()
	if not earned.get("ok", false):
		return
	var ledger: Array = earned["deck"].duplicate(true)
	var registry: Dictionary = earned["descriptors"].duplicate(true)
	var cursor: int = earned["next_stitch_id"]
	var id: String = earned["stitched_id"]
	var desc: Dictionary = registry[id].duplicate(true)
	var strike_indices := _strike_indices(ledger)
	var stitched_index := ledger.find(id)
	_check(strike_indices.size() == 2 and stitched_index >= 0,
		"two independently upgradable Warden Strikes survive genuine stitch")
	_check(ledger.count(PRICK_ID) == 1 and ledger.count("tinker_pop_shot") == 1,
		"only one of each stitched half was consumed")
	_check(desc["half_ids"] == [PRICK_ID, "tinker_pop_shot"]
		and desc["owners"] == ["seamstress", "tinker"]
		and desc["cost"] == 2 and not desc["can_upgrade"] and not desc["can_stitch"],
		"authentic composite owns canonical halves and immutable restrictions")
	if strike_indices.size() != 2 or stitched_index < 0:
		return
	var mapping := {STRIKE_ID: "warden_strike_plus", id: "hostile_composite_plus"}
	var visit := RunRestCardUpgrade.new(ledger, mapping, registry, cursor)
	_assert_rejected(visit, stitched_index, ledger, "genuine composite cannot upgrade even with hostile mapping")
	_assert_rejected(visit, stitched_index, ledger, "repeat hostile composite attempt leaves visit open")
	_assert_rejected(visit, -1, ledger, "invalid index before legitimate mixed selection")
	var selected: int = strike_indices[1]
	var expected := _expected_replaced(ledger, selected, "warden_strike_plus")
	var result := visit.choose_upgrade(selected)
	_check(_is_ok(result) and visit.is_consumed(), "one legal ordinary copy can upgrade in a mixed ledger")
	_check(_decks_equal(result.get("deck"), expected) and result.get("original_id") == STRIKE_ID
		and result.get("upgraded_id") == "warden_strike_plus", "exact selected Strike and order changed")
	_check(result["deck"][strike_indices[0]] == STRIKE_ID and result["deck"][stitched_index] == id,
		"other Strike and composite retained in place")
	_check(_decks_equal(ledger, earned["deck"]) and registry == earned["descriptors"]
		and cursor == earned["next_stitch_id"] and registry[id] == desc,
		"upgrade cannot mutate original deck, descriptors, allocator or halves")
	_assert_rejected_while_used(visit, strike_indices[0], ledger, "mixed visit second ordinary selection")
	var fresh := RunRestStitchCards.new(result["deck"], registry, 3, cursor)
	_check(fresh.is_valid() and fresh.get_snapshot()["descriptors"][id] == desc
		and fresh.get_snapshot()["next_stitch_id"] == cursor, "stitched owner ledger survives successful upgrade")
	var replay := RunRestCardUpgrade.new(earned["deck"], mapping, earned["descriptors"], earned["next_stitch_id"])
	_check(replay.choose_upgrade(selected) == result, "independent mixed upgrade replays exactly")


func _test_mixed_invalid_ledgers_and_isolation() -> void:
	var earned := _earned_mixed_ledger()
	if not earned.get("ok", false):
		return
	var deck: Array = earned["deck"].duplicate(true)
	var descriptors: Dictionary = earned["descriptors"].duplicate(true)
	var cursor: int = earned["next_stitch_id"]
	var id: String = earned["stitched_id"]
	var strike: int = deck.find(STRIKE_ID)
	_check(strike >= 0 and deck.has(id), "malformed probes start from real mixed ownership")
	if strike < 0:
		return
	var altered_half := descriptors.duplicate(true)
	altered_half[id]["first_half"]["effects"]["damage"] = 1234
	var malformed_registry := descriptors.duplicate(true)
	malformed_registry[id] = ["not", "a", "descriptor"]
	var orphan_deck := deck.duplicate(true)
	orphan_deck.erase(id)
	var duplicate_deck := deck.duplicate(true)
	duplicate_deck.append(id)
	var unknown_deck := deck.duplicate(true)
	unknown_deck[deck.find(id)] = "stitched_777777"
	var alien_registry := descriptors.duplicate(true)
	alien_registry["stitched_000009"] = descriptors[id].duplicate(true)
	var probes := [
		{"name": "missing registry", "deck": deck, "registry": {}, "cursor": cursor},
		{"name": "null registry", "deck": deck, "registry": null, "cursor": cursor},
		{"name": "forged half", "deck": deck, "registry": altered_half, "cursor": cursor},
		{"name": "malformed descriptor", "deck": deck, "registry": malformed_registry, "cursor": cursor},
		{"name": "orphan descriptor", "deck": orphan_deck, "registry": descriptors, "cursor": cursor},
		{"name": "duplicate composite", "deck": duplicate_deck, "registry": descriptors, "cursor": cursor},
		{"name": "unknown stitched ID", "deck": unknown_deck, "registry": descriptors, "cursor": cursor},
		{"name": "extra descriptor", "deck": deck, "registry": alien_registry, "cursor": cursor},
		{"name": "stale cursor", "deck": deck, "registry": descriptors, "cursor": 1},
		{"name": "fractional cursor", "deck": deck, "registry": descriptors, "cursor": 2.5},
		{"name": "string cursor", "deck": deck, "registry": descriptors, "cursor": "2"},
		{"name": "invalid deck input", "deck": "not an array", "registry": descriptors, "cursor": cursor},
	]
	for probe in probes:
		var bad_deck: Variant = probe["deck"].duplicate(true) if probe["deck"] is Array else probe["deck"]
		var bad_registry: Variant = probe["registry"].duplicate(true) if probe["registry"] is Dictionary else probe["registry"]
		var before_deck: Variant = bad_deck.duplicate(true) if bad_deck is Array else bad_deck
		var before_registry: Variant = bad_registry.duplicate(true) if bad_registry is Dictionary else bad_registry
		var service := RunRestCardUpgrade.new(bad_deck, {STRIKE_ID: "warden_strike_plus"},
			bad_registry, probe["cursor"])
		var attempt := service.choose_upgrade(strike)
		_check(_is_rejected(attempt) and not service.is_consumed(),
			probe["name"] + " fails closed even when selected Strike is ordinary")
		_check(_decks_equal(attempt.get("deck"), before_deck if before_deck is Array else []),
			probe["name"] + " failure returns complete input deck without edits")
		_check(bad_deck == before_deck and bad_registry == before_registry,
			probe["name"] + " caller input unchanged")
		_check(_is_rejected(service.choose_upgrade(strike)) and not service.is_consumed(),
			probe["name"] + " repeated construction failure never latches")
	# A valid ledger is captured deeply, including the nested canonical half.
	var captured_deck := deck.duplicate(true)
	var captured_registry := descriptors.duplicate(true)
	var mapping := {STRIKE_ID: "warden_strike_plus"}
	var captured := RunRestCardUpgrade.new(deck, mapping, descriptors, cursor)
	deck[strike] = "tinker_tune_up"
	descriptors[id]["first_half"]["effects"]["damage"] = 555
	descriptors.clear()
	mapping[STRIKE_ID] = "malicious_after_construction"
	var accepted := captured.choose_upgrade(strike)
	_check(_is_ok(accepted) and _decks_equal(accepted["deck"],
		_expected_replaced(captured_deck, strike, "warden_strike_plus")),
		"post-construction mutation of deck, mapping or nested registry cannot alter captured visit")
	_check(captured_registry[id]["first_half"]["effects"]["damage"] == 3,
		"pristine nested descriptor snapshot retained")
	# Real ledger constructions, rejections and acceptance never draw RNG.
	seed(RNG_SEED)
	var expected_global := randi()
	seed(RNG_SEED)
	var untouched := RunRestCardUpgrade.new(captured_deck, {STRIKE_ID: "warden_strike_plus"},
		captured_registry, cursor)
	untouched.choose_upgrade(captured_deck.find(id))
	var success := untouched.choose_upgrade(strike)
	var invalid := RunRestCardUpgrade.new(captured_deck, {STRIKE_ID: "warden_strike_plus"}, {}, cursor)
	invalid.choose_upgrade(strike)
	_check(_is_ok(success) and not invalid.is_consumed() and randi() == expected_global,
		"all mixed construction, rejection and success paths leave global RNG stream unconsumed")

	# Even malformed nested inputs must not leak a writable reference through
	# detached failure returns (a second rejection must stay pristine).
	var malformed_nested: Array = [STRIKE_ID, {"id": "not_a_card", "parts": [PRICK_ID]}]
	var malformed_original := malformed_nested.duplicate(true)
	var nested_visit := RunRestCardUpgrade.new(malformed_nested, _fixture_mapping())
	var nested_rejected := nested_visit.choose_upgrade(0)
	_check(_is_rejected(nested_rejected) and not nested_visit.is_consumed(),
		"malformed nested plain input cannot upgrade an otherwise legal first Strike")
	nested_rejected["deck"][1]["parts"].append("tinker_pop_shot")
	var independent := nested_visit.choose_upgrade(0)
	_check(independent["deck"] == malformed_original and malformed_nested == malformed_original
		and not nested_visit.is_consumed(),
		"nested failure returns are deep detached from caller and subsequent rejection")


## Each example uses an actual earned copy, with another copy left in place.
## The cost/effect assertions use the authored definitions, not a combat proxy.
func _test_authored_pool_upgrade_cases() -> void:
	var examples := [
		{"base": "warden_iron_hem", "plus": "warden_iron_hem_plus", "owner": "warden",
			"cost": 2, "plus_cost": 1, "effects": {"block": 14}, "plus_effects": {"block": 14}},
		{"base": "seamstress_running_stitch", "plus": "seamstress_running_stitch_plus",
			"owner": "seamstress", "cost": 1, "plus_cost": 1,
			"effects": {"damage": 2, "bleed": 3}, "plus_effects": {"damage": 3, "bleed": 4}},
		{"base": "tinker_rivet_shot", "plus": "tinker_rivet_shot_plus", "owner": "tinker",
			"cost": 1, "plus_cost": 1, "effects": {"damage": 4, "exposed": 1},
			"plus_effects": {"damage": 6, "exposed": 1}},
	]
	for example in examples:
		var original_id: String = example["base"]
		var upgraded_id: String = example["plus"]
		var pool: Object
		match example["owner"]:
			"warden":
				pool = WardenPoolCards.new()
			"seamstress":
				pool = SeamstressPoolCards.new()
			"tinker":
				pool = TinkerPoolCards.new()
		var original: Dictionary = pool.get_definition(original_id)
		var upgraded: Dictionary = pool.get_definition(upgraded_id)
		_check(not original.is_empty() and not upgraded.is_empty(), original_id + ": both canonical definitions exist")
		if original.is_empty() or upgraded.is_empty():
			continue
		_check(original.get("owner") == example["owner"] and upgraded.get("owner") == example["owner"]
			and original.get("upgrade_id") == upgraded_id
			and pool.get_upgrade_id(original_id) == upgraded_id, original_id + ": original owns the real plus link")
		_check(original.get("cost") == example["cost"] and upgraded.get("cost") == example["plus_cost"]
			and original.get("effects") == example["effects"]
			and upgraded.get("effects") == example["plus_effects"], original_id + ": unchanged authored costs and effects")
		_check(original.get("from_positions") == ([2, 3] if example["owner"] == "tinker" else [1, 2, 3])
			and (original.get("to_positions") == [] if example["owner"] == "warden"
				else original.get("to_positions") == [1, 2, 3]),
			original_id + ": original hero and target positions are authored")
		var source := _load_starter_deck()
		source.insert(2, original_id)
		source.append("seamstress_running_stitch_plus")
		source.append(original_id)
		var pristine := source.duplicate(true)
		var target := source.size() - 1
		var other_copy := 2
		_check(source.count(original_id) == 2 and source[target] == original_id
			and source[other_copy] == original_id, original_id + ": two earned copies at distinct real indices")
		var mapping := {original_id: upgraded_id}
		var rng := RandomNumberGenerator.new()
		rng.seed = 1701
		var state := rng.state
		seed(RNG_SEED)
		var next_draw := randi()
		seed(RNG_SEED)
		var visit := RunRestCardUpgrade.new(source, mapping)
		_assert_rejected(visit, source.find("seamstress_running_stitch_plus"), pristine,
			original_id + ": preexisting pool plus cannot be upgraded")
		var success := visit.choose_upgrade(target)
		_check(_is_ok(success) and visit.is_consumed(), original_id + ": earned pool upgrade succeeds")
		_check(success.get("original_id") == original_id and success.get("upgraded_id") == upgraded_id,
			original_id + ": receipt identifies canonical pair")
		_check(_decks_equal(success.get("deck"), _expected_replaced(pristine, target, upgraded_id))
			and success["deck"][other_copy] == original_id
			and success["deck"].count("seamstress_running_stitch_plus") >= 1,
			original_id + ": only selected copy replaced; existing plus and order retained")
		_check(source == pristine and rng.state == state and randi() == next_draw,
			original_id + ": caller deck and RNG unchanged")
		_assert_rejected_while_used(visit, other_copy, pristine, original_id + ": second selection denied")
		var fresh := RunRestCardUpgrade.new(success["deck"], {upgraded_id: original_id})
		_assert_rejected(fresh, target, success["deck"], original_id + ": fresh visit cannot re-upgrade a plus")
		_check(not fresh.is_consumed(), original_id + ": rejected re-upgrade leaves visit open")


## The five newer v3 hero pools' authored base/+ pairs must project and upgrade
## through the same canonical Rest path as the three starter heroes (M04 fix).
## Expected costs and effects are copied from the shipped catalogs and then
## checked against the real catalog definitions and the projected choices.
func _test_newer_hero_pool_upgrade_cases() -> void:
	var pools := {
		"lantern_monk": LanternMonkPoolCards.new(),
		"rag_duelist": RagDuelistPoolCards.new(),
		"scarecrow": ScarecrowPoolCards.new(),
		"yarn_ranger": YarnRangerPoolCards.new(),
		"button_golem": ButtonGolemPoolCards.new(),
	}
	var examples := [
		{"base": "lantern_monk_moth_lure", "owner": "lantern_monk",
			"cost": 1, "plus_cost": 0,
			"effects": {"blind_next_attack": true, "draw": 1},
			"plus_effects": {"blind_next_attack": true, "draw": 1}},
		{"base": "rag_duelist_velvet_feint", "owner": "rag_duelist",
			"cost": 1, "plus_cost": 0,
			"effects": {"exposed": 1, "draw": 1},
			"plus_effects": {"exposed": 1, "draw": 1}},
		{"base": "scarecrow_pitchfork_prick", "owner": "scarecrow",
			"cost": 1, "plus_cost": 1,
			"effects": {"damage": 5, "bleed": 1},
			"plus_effects": {"damage": 7, "bleed": 2}},
		{"base": "yarn_ranger_needle_arrow", "owner": "yarn_ranger",
			"cost": 1, "plus_cost": 1,
			"effects": {"damage": 5, "unravel": 1},
			"plus_effects": {"damage": 7, "unravel": 2}},
		{"base": "button_golem_pop_button", "owner": "button_golem",
			"cost": 1, "plus_cost": 1,
			"effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 9,
				"buttons_popped_gain": 1},
			"plus_effects": {"require_owner_block": 5, "spend_owner_block": 5, "damage": 12,
				"buttons_popped_gain": 1}},
	]
	for example in examples:
		var original_id: String = example["base"]
		var owner: String = example["owner"]
		var pool: Object = pools[owner]
		var upgraded_id: String = original_id + "_plus"
		var original: Dictionary = pool.get_definition(original_id)
		var upgraded: Dictionary = pool.get_definition(upgraded_id)
		_check(not original.is_empty() and not upgraded.is_empty(),
			original_id + ": both canonical catalog definitions exist")
		_check(original.get("owner") == owner and upgraded.get("owner") == owner
			and original.get("upgrade_id") == upgraded_id
			and upgraded.get("upgrade_of", "") == original_id,
			original_id + ": catalog owns the exact authored base/plus link")
		_check(original.get("cost") == example["cost"]
			and upgraded.get("cost") == example["plus_cost"]
			and original.get("effects") == example["effects"]
			and upgraded.get("effects") == example["plus_effects"],
			original_id + ": authored costs and effects match the shipped catalog")
		if original.is_empty() or upgraded.is_empty():
			continue
		var source := _load_starter_deck()
		source.insert(2, original_id)
		source.append(original_id)
		var pristine := source.duplicate(true)
		var target: int = source.size() - 1
		var other_copy := 2
		_check(source.count(original_id) == 2 and source[target] == original_id
			and source[other_copy] == original_id,
			original_id + ": two earned copies at distinct real indices")
		var projection := RunRestCardUpgrade.list_authored_choices(source)
		_check(_is_ok(projection), original_id + ": newer-hero pool deck projects")
		var matched: Array = []
		for row_raw: Variant in projection.get("choices", []):
			var row: Dictionary = row_raw
			if row.get("source_id") == original_id:
				matched.append(row)
		_check(matched.size() == 2, original_id + ": both owned copies appear as choices")
		var permitted: Dictionary = projection.get("permitted_upgrades", {})
		_check(permitted.get(original_id) == upgraded_id,
			original_id + ": permitted map carries the exact authored plus ID")
		for row_raw: Variant in matched:
			var row: Dictionary = row_raw
			_check(row.get("index") in [2, target] and row.get("base_id") == original_id
				and row.get("plus_id") == upgraded_id and row.get("owner") == owner
				and row.get("cost") == example["cost"]
				and row.get("plus_cost") == example["plus_cost"]
				and row.get("effects") == example["effects"]
				and row.get("plus_effects") == example["plus_effects"],
				original_id + ": choice carries exact catalog owner, plus ID, cost and effects")
		_check(_decks_equal(source, pristine), original_id + ": projection never mutates the deck")
		# A forged or mismatched plus is refused while a genuine visit stays usable.
		for forged_plus in [original_id + "_plus_fake", "warden_iron_hem_plus"]:
			var forged := RunRestCardUpgrade.new(source, {original_id: forged_plus})
			_assert_rejected(forged, target, pristine,
				original_id + ": mismatched plus refused (" + forged_plus + ")")
			_check(not forged.is_consumed(),
				original_id + ": refused wrong plus leaves its visit unconsumed")
		seed(RNG_SEED)
		var next_draw := randi()
		seed(RNG_SEED)
		var visit := RunRestCardUpgrade.new(source, permitted)
		var success := visit.choose_upgrade(target)
		_check(_is_ok(success) and visit.is_consumed(), original_id + ": indexed upgrade succeeds")
		_check(success.get("original_id") == original_id and success.get("upgraded_id") == upgraded_id,
			original_id + ": receipt identifies the canonical newer-hero pair")
		_check(_decks_equal(success.get("deck"), _expected_replaced(pristine, target, upgraded_id))
			and success["deck"][other_copy] == original_id,
			original_id + ": exactly the selected index changed; other copy retained")
		_assert_rejected_while_used(visit, other_copy, pristine,
			original_id + ": second selection denied")
		var reupgrade := RunRestCardUpgrade.new(success["deck"], {upgraded_id: original_id})
		_assert_rejected(reupgrade, target, success["deck"],
			original_id + ": upgraded plus cannot be re-upgraded")
		_check(not reupgrade.is_consumed(), original_id + ": refused re-upgrade leaves visit open")
		_check(_decks_equal(source, pristine) and randi() == next_draw,
			original_id + ": caller deck and global RNG unchanged")


func _test_pool_mapping_and_membership_rejections() -> void:
	var deck := _load_starter_deck()
	deck.append_array(["warden_iron_hem", "tinker_rivet_shot", "seamstress_running_stitch_plus"])
	var warden_index := deck.find("warden_iron_hem")
	var tinker_index := deck.find("tinker_rivet_shot")
	_check(warden_index >= 0 and tinker_index >= 0, "mapping matrix owns both earned originals")
	if warden_index < 0 or tinker_index < 0:
		return
	var mappings := [
		{"warden_iron_hem": "warden_patch_guard_plus"}, # same owner, wrong pair
		{"warden_iron_hem": "tinker_rivet_shot_plus"}, # wrong hero
		{"warden_iron_hem": "warden_iron_hem"}, # base ID, not an upgrade
		{"warden_iron_hem": "warden_forged_hem_plus"}, # made-up plus
		{"warden_iron_hem": "seamstress_running_stitch_plus"}, # real other-owner plus
		{"warden_iron_hem": "warden_strike_plus"}, # starter plus is not a pool partner
	]
	for mapping in mappings:
		mapping["tinker_rivet_shot"] = "tinker_rivet_shot_plus"
		var visit := RunRestCardUpgrade.new(deck, mapping)
		_assert_rejected(visit, warden_index, deck, "wrong pool upgrade mapping " + str(mapping["warden_iron_hem"]))
		var success := visit.choose_upgrade(tinker_index)
		_check(_is_ok(success) and success["deck"][tinker_index] == "tinker_rivet_shot_plus"
			and visit.is_consumed(), "invalid pool mapping does not latch a later legal choice")
		_check(deck[warden_index] == "warden_iron_hem", "rejected mapping never alters caller deck")
	for forged in ["warden_forged_hem_plus", "tinker_rivet_shot_plus_fake", "seamstress_not_a_card_plus"]:
		var bad := deck.duplicate(true)
		bad.append(forged)
		var rejected := RunRestCardUpgrade.new(bad, {"warden_iron_hem": "warden_iron_hem_plus"})
		_assert_rejected(rejected, warden_index, bad, "forged plus deck member " + forged)
	var missing_mapping := RunRestCardUpgrade.new(deck, {})
	_assert_rejected(missing_mapping, warden_index, deck, "catalog membership does not grant a Rest upgrade")
	var reupgrade := RunRestCardUpgrade.new(deck,
		{"seamstress_running_stitch_plus": "seamstress_running_stitch_plus_plus"})
	_assert_rejected(reupgrade, deck.find("seamstress_running_stitch_plus"), deck,
		"already upgraded pool card is not an upgrade original")


func _test_pool_plus_in_stitched_upgrade_ledger() -> void:
	var stitched := _earned_mixed_ledger()
	if not stitched.get("ok", false):
		return
	var owned: Array = stitched["deck"].duplicate(true)
	owned.append_array(["warden_iron_hem_plus", "tinker_rivet_shot", "tinker_rivet_shot_plus"])
	var before := owned.duplicate(true)
	var descriptors: Dictionary = stitched["descriptors"].duplicate(true)
	var cursor: int = stitched["next_stitch_id"]
	var visit := RunRestCardUpgrade.new(owned, {"tinker_rivet_shot": "tinker_rivet_shot_plus"},
		descriptors, cursor)
	_assert_rejected(visit, owned.find("warden_iron_hem_plus"), before,
		"authentic composite ledger admits plus but never upgrades it")
	var selected := owned.find("tinker_rivet_shot")
	var result := visit.choose_upgrade(selected)
	_check(_is_ok(result) and visit.is_consumed(), "genuine stitched ledger upgrades earned Tinker instance")
	_check(result.get("deck") == _expected_replaced(before, selected, "tinker_rivet_shot_plus")
		and result["deck"].count("tinker_rivet_shot_plus") == 2,
		"stitched ledger retains duplicate plus cards and original ordering")
	_check(descriptors == stitched["descriptors"] and owned == before
		and cursor == stitched["next_stitch_id"], "caller composite ledger and cursor unchanged")
	var later := RunRestStitchCards.new(result["deck"], descriptors, 3, cursor)
	_check(later.is_valid() and later.get_snapshot()["descriptors"] == descriptors
		and later.get_snapshot()["next_stitch_id"] == cursor,
		"upgraded mixed ledger passes a new Rest stitch validator")


func _test_list_authored_choices_plain_and_mixed() -> void:
	var deck: Array[String] = _load_starter_deck()
	var hem_1: int = deck.size()
	deck.append("warden_iron_hem")
	var stitch_idx: int = deck.size()
	deck.append("seamstress_running_stitch")
	var rivet_idx: int = deck.size()
	deck.append("tinker_rivet_shot")
	var cannon_idx: int = deck.size()
	deck.append("tinker_bobbin_cannon")
	var hem_2: int = deck.size()
	deck.append("warden_iron_hem")
	deck.append("seamstress_running_stitch_plus")
	deck.append("warden_strike_plus")
	var snapshot: Array = deck.duplicate(true)

	var projection: Dictionary = RunRestCardUpgrade.list_authored_choices(deck)
	_check(_is_ok(projection), "plain deck list_authored_choices succeeds")
	_check(_decks_equal(deck, snapshot), "list_authored_choices never mutates input deck")

	var choices_raw: Variant = projection.get("choices")
	var permitted_raw: Variant = projection.get("permitted_upgrades")
	_check(choices_raw is Array, "projection returns choices array")
	_check(permitted_raw is Dictionary, "projection returns permitted_upgrades dictionary")
	if not (choices_raw is Array) or not (permitted_raw is Dictionary):
		return

	var choices: Array = choices_raw
	var permitted: Dictionary = permitted_raw

	var strikes: Array[int] = _strike_indices(deck)
	var found_strikes: Array[int] = []
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		if c.get("source_id") == STRIKE_ID:
			found_strikes.append(int(c.get("index", -1)))
			_check(c.get("plus_id") == "warden_strike_plus", "Strike plus ID matches authored")
			_check(c.get("owner") == "warden", "Strike owner is warden")
	_check(found_strikes == strikes, "each Strike copy has its own choice matching its deck index")

	var hem_indices: Array[int] = []
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		if c.get("source_id") == "warden_iron_hem":
			hem_indices.append(int(c.get("index", -1)))
			_check(c.get("plus_id") == "warden_iron_hem_plus", "Iron Hem plus ID is warden_iron_hem_plus")
			_check(c.get("owner") == "warden", "Iron Hem owner is warden")
	_check(hem_indices == [hem_1, hem_2], "duplicate Iron Hem bases appear at distinct indices")

	var stitch_found: bool = false
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		if c.get("source_id") == "seamstress_running_stitch":
			stitch_found = true
			_check(c.get("index") == stitch_idx, "Running Stitch at correct index")
			_check(c.get("plus_id") == "seamstress_running_stitch_plus", "Running Stitch plus ID is seamstress_running_stitch_plus")
			_check(c.get("owner") == "seamstress", "Running Stitch owner is seamstress")
	_check(stitch_found, "earned Running Stitch choice present")

	var rivet_found: bool = false
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		if c.get("source_id") == "tinker_rivet_shot":
			rivet_found = true
			_check(c.get("index") == rivet_idx, "Rivet Shot at correct index")
			_check(c.get("plus_id") == "tinker_rivet_shot_plus", "Rivet Shot plus ID is tinker_rivet_shot_plus")
			_check(c.get("owner") == "tinker", "Rivet Shot owner is tinker")
	_check(rivet_found, "earned Rivet Shot choice present")

	var cannon_found: bool = false
	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		if c.get("source_id") == "tinker_bobbin_cannon":
			cannon_found = true
			_check(c.get("index") == cannon_idx, "Bobbin Cannon at correct index")
			_check(c.get("plus_id") == "tinker_bobbin_cannon_plus", "Bobbin Cannon plus ID is tinker_bobbin_cannon_plus")
			_check(c.get("owner") == "tinker", "Bobbin Cannon owner is tinker")
	_check(cannon_found, "earned Bobbin Cannon choice present")

	for c_raw: Variant in choices:
		var c: Dictionary = c_raw
		var sid: String = str(c.get("source_id", ""))
		_check(sid != "seamstress_running_stitch_plus", "prior pool plus is never an upgrade choice")
		_check(sid != "warden_strike_plus", "prior starter plus is never an upgrade choice")
		_check(sid != "tinker_tune_up_plus",
			"already-upgraded starters remain ineligible: " + sid)

	_check(permitted.get(STRIKE_ID) == "warden_strike_plus", "permitted Strike maps to warden_strike_plus")
	_check(permitted.get("warden_iron_hem") == "warden_iron_hem_plus", "permitted Iron Hem maps to plus")
	_check(permitted.get("seamstress_running_stitch") == "seamstress_running_stitch_plus", "permitted Running Stitch maps to plus")
	_check(permitted.get("tinker_rivet_shot") == "tinker_rivet_shot_plus", "permitted Rivet Shot maps to plus")
	_check(permitted.get("tinker_bobbin_cannon") == "tinker_bobbin_cannon_plus", "permitted Bobbin Cannon maps to plus")
	_check(not permitted.has("seamstress_running_stitch_plus"), "permitted excludes pre-upgraded plus")
	_check(not permitted.has("warden_strike_plus"), "permitted excludes starter plus")
	_check(permitted.get("warden_brace") == "warden_brace_plus"
		and permitted.get("seamstress_mend") == "seamstress_mend_plus"
		and permitted.get("seamstress_stitch_up") == "seamstress_stitch_up_plus",
		"authored support upgrades included in genuine permitted map")
	_check(permitted.get("tinker_tune_up") == "tinker_tune_up_plus", "authored Tune Up is permitted")

	var earned: Dictionary = _earned_mixed_ledger()
	if not earned.get("ok", false):
		return
	var mixed_deck: Array = earned["deck"].duplicate(true)
	var registry: Dictionary = earned["descriptors"].duplicate(true)
	var cursor: int = earned["next_stitch_id"]
	var stitched_id: String = earned["stitched_id"]
	mixed_deck.append("warden_iron_hem")
	mixed_deck.append("seamstress_running_stitch")
	mixed_deck.append("tinker_rivet_shot")
	var mixed_snapshot: Array = mixed_deck.duplicate(true)
	var reg_snapshot: Dictionary = registry.duplicate(true)

	var mixed_proj: Dictionary = RunRestCardUpgrade.list_authored_choices(mixed_deck, registry, cursor)
	_check(_is_ok(mixed_proj), "mixed ledger list_authored_choices succeeds")
	_check(_decks_equal(mixed_deck, mixed_snapshot), "mixed deck untouched by list_authored_choices")
	_check(registry == reg_snapshot, "mixed descriptors untouched by list_authored_choices")

	var m_choices: Array = mixed_proj.get("choices", [])
	var m_permitted: Dictionary = mixed_proj.get("permitted_upgrades", {})
	_check(not m_permitted.has(stitched_id), "stitched composite is never in permitted_upgrades")
	for c_raw: Variant in m_choices:
		var c: Dictionary = c_raw
		_check(c.get("source_id") != stitched_id, "stitched card never appears in choices")
		_check(c.get("plus_id") != stitched_id, "stitched card never appears as plus")


func _test_choice_map_integration_and_canonical_authoring() -> void:
	var cases: Array = [
		{
			"base": "warden_iron_hem", "plus": "warden_iron_hem_plus", "owner": "warden",
			"cost": 2, "plus_cost": 1, "effects": {"block": 14}, "plus_effects": {"block": 14}
		},
		{
			"base": "seamstress_running_stitch", "plus": "seamstress_running_stitch_plus", "owner": "seamstress",
			"cost": 1, "plus_cost": 1, "effects": {"damage": 2, "bleed": 3}, "plus_effects": {"damage": 3, "bleed": 4}
		},
		{
			"base": "tinker_rivet_shot", "plus": "tinker_rivet_shot_plus", "owner": "tinker",
			"cost": 1, "plus_cost": 1, "effects": {"damage": 4, "exposed": 1}, "plus_effects": {"damage": 6, "exposed": 1}
		},
		{
			"base": "tinker_bobbin_cannon", "plus": "tinker_bobbin_cannon_plus", "owner": "tinker",
			"cost": 3, "plus_cost": 3, "effects": {"damage": 20}, "plus_effects": {"damage": 26}
		},
	]

	for tc_raw: Variant in cases:
		var tc: Dictionary = tc_raw
		var base_id: String = tc["base"]
		var plus_id: String = tc["plus"]
		var owner: String = tc["owner"]

		var stitched: Dictionary = _earned_mixed_ledger()
		if not stitched.get("ok", false):
			return
		var deck: Array = stitched["deck"].duplicate(true)
		var descriptors: Dictionary = stitched["descriptors"].duplicate(true)
		var cursor: int = stitched["next_stitch_id"]
		var comp_id: String = stitched["stitched_id"]

		var idx_first: int = deck.size()
		deck.append(base_id)
		deck.append(plus_id)
		var idx_second: int = deck.size()
		deck.append(base_id)
		var pristine_deck: Array = deck.duplicate(true)
		var pristine_desc: Dictionary = descriptors.duplicate(true)

		var proj: Dictionary = RunRestCardUpgrade.list_authored_choices(deck, descriptors, cursor)
		_check(_is_ok(proj), base_id + ": projection ok")
		var choices: Array = proj.get("choices", [])
		var permitted: Dictionary = proj.get("permitted_upgrades", {})

		var matched_choices: Array = []
		for c_raw: Variant in choices:
			var c: Dictionary = c_raw
			if c.get("source_id") == base_id:
				matched_choices.append(c)
				_check(c.get("plus_id") == plus_id, base_id + ": canonical plus ID matches")
				_check(c.get("owner") == owner, base_id + ": catalog owner matches")
				_check(c.get("cost") == tc["cost"], base_id + ": authored base cost matches")
				_check(c.get("plus_cost") == tc["plus_cost"], base_id + ": authored plus cost matches")
				_check(c.get("effects") == tc["effects"], base_id + ": authored base effects match")
				_check(c.get("plus_effects") == tc["plus_effects"], base_id + ": authored plus effects match")

		_check(matched_choices.size() == 2, base_id + ": both copies appear as choices")
		_check(matched_choices[0].get("index") == idx_first and matched_choices[1].get("index") == idx_second,
			base_id + ": choices record original indices")

		seed(RNG_SEED)
		var pre_rng: int = randi()
		seed(RNG_SEED)

		var visit: RunRestCardUpgrade = RunRestCardUpgrade.new(deck, permitted, descriptors, cursor)
		_check(not visit.is_consumed(), base_id + ": fresh visit starts unconsumed")

		var result: Dictionary = visit.choose_upgrade(idx_second)
		_check(_is_ok(result), base_id + ": choose_upgrade on second copy succeeds")
		_check(visit.is_consumed(), base_id + ": visit latches after single choice")
		_check(result.get("original_id") == base_id and result.get("upgraded_id") == plus_id,
			base_id + ": result IDs match")

		var res_deck: Array = result.get("deck", [])
		_check(res_deck[idx_second] == plus_id, base_id + ": chosen index upgraded to plus")
		_check(res_deck[idx_first] == base_id, base_id + ": unchosen duplicate copy remains base")
		_check(res_deck[deck.find(comp_id)] == comp_id, base_id + ": stitched composite unchanged")
		_check(_decks_equal(deck, pristine_deck), base_id + ": caller deck untouched")
		_check(descriptors == pristine_desc, base_id + ": caller descriptors untouched")

		_assert_rejected_while_used(visit, idx_first, pristine_deck, base_id + ": second selection denied")

		var unsupported_deck: Array = deck.duplicate(true)
		var unsupported: int = unsupported_deck.find("tinker_tune_up")
		if unsupported >= 0 and unsupported != idx_first and unsupported != idx_second:
			unsupported_deck[unsupported] = "tinker_tune_up_plus"
			var starter_attempt_visit: RunRestCardUpgrade = RunRestCardUpgrade.new(unsupported_deck, permitted, descriptors, cursor)
			_assert_rejected(starter_attempt_visit, unsupported, unsupported_deck,
				base_id + ": already-upgraded Tune Up cannot be upgraded with canonical map")

		_check(randi() == pre_rng, base_id + ": visit consumed zero RNG draws")


func _test_list_authored_choices_negative_and_isolation() -> void:
	var valid_deck: Array[String] = _load_starter_deck()
	var valid_copy: Array = valid_deck.duplicate(true)

	var bad_inputs: Array = [
		{"desc": "null deck", "deck": null, "reg": null, "cursor": null},
		{"desc": "empty deck", "deck": [], "reg": null, "cursor": null},
		{"desc": "string deck", "deck": "warden_strike", "reg": null, "cursor": null},
		{"desc": "integer deck", "deck": 42, "reg": null, "cursor": null},
		{"desc": "deck with integer element", "deck": [valid_deck[0], 42], "reg": null, "cursor": null},
		{"desc": "deck with empty string", "deck": [valid_deck[0], ""], "reg": null, "cursor": null},
		{"desc": "deck with null element", "deck": [valid_deck[0], null], "reg": null, "cursor": null},
		{"desc": "deck with unknown card ID", "deck": [valid_deck[0], "unauthored_card_xyz"], "reg": null, "cursor": null},
		{"desc": "deck with forged pool plus", "deck": [valid_deck[0], "warden_forged_hem_plus"], "reg": null, "cursor": null},
		{"desc": "forged Tune Up plus", "deck": [valid_deck[0], "tinker_tune_up_plus_forged"], "reg": null, "cursor": null},
		{"desc": "deck with fake tinker plus", "deck": [valid_deck[0], "tinker_rivet_shot_plus_fake"], "reg": null, "cursor": null},
		{"desc": "stitched card without descriptors", "deck": [valid_deck[0], "stitched_000001"], "reg": null, "cursor": null},
		{"desc": "stitched card with empty registry", "deck": [valid_deck[0], "stitched_000001"], "reg": {}, "cursor": 2},
		{"desc": "stitched card with stale cursor", "deck": [valid_deck[0], "stitched_000001"], "reg": {"stitched_000001": {}}, "cursor": 1},
		{"desc": "stitched card with float cursor", "deck": [valid_deck[0], "stitched_000001"], "reg": {}, "cursor": 2.5},
		{"desc": "stitched card with string cursor", "deck": [valid_deck[0], "stitched_000001"], "reg": {}, "cursor": "2"},
	]

	for bi_raw: Variant in bad_inputs:
		var bi: Dictionary = bi_raw
		var res: Dictionary = RunRestCardUpgrade.list_authored_choices(bi["deck"], bi["reg"], bi["cursor"])
		_check(_is_rejected(res), "negative test (" + str(bi["desc"]) + ") returns rejected")
		_check(res.get("choices") == [], "negative test (" + str(bi["desc"]) + ") returns empty choices")
		_check(res.get("permitted_upgrades") == {}, "negative test (" + str(bi["desc"]) + ") returns empty permitted_upgrades")

	var mutable_deck: Array = valid_deck.duplicate(true)
	mutable_deck.append("warden_iron_hem")
	var mutable_copy: Array = mutable_deck.duplicate(true)

	var proj_1: Dictionary = RunRestCardUpgrade.list_authored_choices(mutable_deck)
	_check(_is_ok(proj_1), "isolation base projection succeeds")
	mutable_deck.append("tinker_bobbin_cannon")
	mutable_deck[0] = "warden_brace"
	_check(proj_1.get("choices", []).size() >= 1, "projection retained independent choices")

	var choices_1: Array = proj_1.get("choices", [])
	choices_1.clear()
	choices_1.append({"tampered": true})
	var perm_1: Dictionary = proj_1.get("permitted_upgrades", {})
	perm_1.clear()
	perm_1["tampered"] = true

	var proj_2: Dictionary = RunRestCardUpgrade.list_authored_choices(mutable_copy)
	_check(_is_ok(proj_2), "second independent projection succeeds")
	_check(not proj_2.get("permitted_upgrades", {}).has("tampered"), "second projection has no tampered key")
	_check(proj_2.get("choices", []).size() >= 1, "second projection choices not cleared")

	var replay_a: Dictionary = RunRestCardUpgrade.list_authored_choices(valid_deck)
	var replay_b: Dictionary = RunRestCardUpgrade.list_authored_choices(valid_copy)
	_check(replay_a == replay_b, "list_authored_choices replays deterministically on identical input")

	seed(RNG_SEED)
	var exp_rng: int = randi()
	seed(RNG_SEED)
	RunRestCardUpgrade.list_authored_choices(valid_deck)
	RunRestCardUpgrade.list_authored_choices(null)
	RunRestCardUpgrade.list_authored_choices([])
	_check(randi() == exp_rng, "list_authored_choices leaves global RNG stream unconsumed")


## Every authored starter support pair is an indexed, catalog-backed choice,
## not an inferred suffix; both duplicates remain individually selectable.
func _test_starter_support_upgrade_pairs() -> void:
	var cases: Array = [
		{"base": "warden_shield_bash", "plus": "warden_shield_bash_plus", "owner": "warden",
			"name": "Shield Bash", "plus_name": "Shield Bash+", "effect": {"damage": 8, "weak": 1},
			"plus_effect": {"damage": 11, "weak": 1}, "positions": [1], "target": "enemy_single", "cost": 2, "to": [1]},
		{"base": "seamstress_prick", "plus": "seamstress_prick_plus", "owner": "seamstress",
			"name": "Prick", "plus_name": "Prick+", "effect": {"damage": 3, "bleed": 2},
			"plus_effect": {"damage": 4, "bleed": 3}, "positions": [1, 2, 3], "target": "enemy_single", "to": [1, 2, 3]},
		{"base": "tinker_pop_shot", "plus": "tinker_pop_shot_plus", "owner": "tinker",
			"name": "Pop Shot", "plus_name": "Pop Shot+", "effect": {"damage": 5},
			"plus_effect": {"damage": 7}, "positions": [2, 3], "target": "enemy_single", "to": [1, 2, 3]},
		{"base": "tinker_scrap_bomb", "plus": "tinker_scrap_bomb_plus", "owner": "tinker",
			"name": "Scrap Bomb", "plus_name": "Scrap Bomb+", "effect": {"damage": 4},
			"plus_effect": {"damage": 6}, "positions": [3], "target": "enemy_all", "cost": 2, "to": [1, 2, 3]},
		{"base": "warden_brace", "plus": "warden_brace_plus", "owner": "warden",
			"name": "Brace", "plus_name": "Brace+", "effect": {"block": 7},
			"plus_effect": {"block": 10}, "positions": [1, 2, 3], "target": "self"},
		{"base": "seamstress_mend", "plus": "seamstress_mend_plus", "owner": "seamstress",
			"name": "Mend", "plus_name": "Mend+", "effect": {"heal": 5},
			"plus_effect": {"heal": 7}, "positions": [2, 3], "target": "ally_single"},
		{"base": "tinker_tune_up", "plus": "tinker_tune_up_plus", "owner": "tinker",
			"name": "Tune Up", "plus_name": "Tune Up+", "effect": {"draw": 1},
			"plus_effect": {"draw": 2}, "positions": [1, 2, 3], "target": "none", "cost": 0},
		{"base": "seamstress_stitch_up", "plus": "seamstress_stitch_up_plus", "owner": "seamstress",
			"name": "Stitch Up", "plus_name": "Stitch Up+", "effect": {"block": 5},
			"plus_effect": {"block": 7}, "positions": [1, 2, 3], "target": "ally_single"},
	]
	var catalog := StarterCards.new()
	var earned := _earned_mixed_ledger()
	_check(earned.get("ok") == true, "support mixed fixture is a real stitched Rest receipt")
	for raw_case in cases:
		var tc: Dictionary = raw_case
		var base_id: String = tc["base"]
		var plus_id: String = tc["plus"]
		var base_def := catalog.get_definition(base_id)
		var plus_def := catalog.get_definition(plus_id)
		_check(base_def.get("id") == base_id and plus_def.get("id") == plus_id
			and base_def.get("owner") == tc["owner"] and plus_def.get("owner") == tc["owner"]
			and base_def.get("cost") == tc.get("cost", 1) and plus_def.get("cost") == tc.get("cost", 1)
			and base_def.get("from_positions") == tc["positions"]
			and plus_def.get("from_positions") == tc["positions"]
			and base_def.get("target_kind") == tc["target"]
			and plus_def.get("target_kind") == tc["target"]
			and base_def.get("to_positions") == tc.get("to", []) and plus_def.get("to_positions") == tc.get("to", [])
			and plus_def.get("starting_copies") == 0,
			base_id + ": both authored definitions have exact matching play shape")
		_check(base_def.get("effects") == tc["effect"]
			and plus_def.get("effects") == tc["plus_effect"],
			base_id + ": authored base and plus effects match the supported contract")
		var deck: Array = [base_id, plus_id, base_id, "tinker_tune_up_plus", "warden_strike_plus", "tinker_tune_up_plus"]
		var pristine: Array = deck.duplicate(true)
		var projection := RunRestCardUpgrade.list_authored_choices(deck)
		_check(_is_ok(projection), base_id + ": genuine plain mixed starter deck projects")
		var rows: Array = projection.get("choices", [])
		var permitted: Dictionary = projection.get("permitted_upgrades", {})
		var found: Array = []
		for raw_row in rows:
			var row: Dictionary = raw_row
			if row.get("source_id") != base_id:
				continue
			found.append(row.get("index"))
			_check(row.get("index") in [0, 2] and row.get("original_id") == base_id
				and row.get("base_id") == base_id and row.get("upgraded_id") == plus_id
				and row.get("plus_id") == plus_id and row.get("owner") == tc["owner"]
				and row.get("display_name") == tc["name"]
				and row.get("plus_display_name") == tc["plus_name"]
				and row.get("cost") == tc.get("cost", 1) and row.get("plus_cost") == tc.get("cost", 1)
				and row.get("effects") == tc["effect"] and row.get("plus_effects") == tc["plus_effect"],
				base_id + ": genuine per-copy canonical indexed metadata")
		_check(found == [0, 2] and permitted.get(base_id) == plus_id,
			base_id + ": both base copies and only genuine paired plus authorize upgrade")
		_check(not permitted.has(plus_id) and not permitted.has("tinker_tune_up_plus")
			and not permitted.has("warden_strike_plus"),
			base_id + ": already-plus starters remain unselectable")
		seed(RNG_SEED)
		var next_draw := randi()
		seed(RNG_SEED)
		var visit := RunRestCardUpgrade.new(deck, permitted)
		_assert_rejected(visit, 1, pristine, base_id + ": pre-upgraded copy rejected")
		_assert_rejected(visit, 3, pristine, base_id + ": already-plus Tune Up upgrade rejected")
		_assert_rejected(visit, 4, pristine, base_id + ": already-plus Strike upgrade rejected")
		var result := visit.choose_upgrade(2)
		_check(_is_ok(result) and visit.is_consumed() and result.get("original_id") == base_id
			and result.get("upgraded_id") == plus_id
			and result.get("deck") == [base_id, plus_id, plus_id, "tinker_tune_up_plus", "warden_strike_plus", "tinker_tune_up_plus"],
			base_id + ": only second copy upgraded once and existing plus stays untouched")
		_assert_rejected_while_used(visit, 0, pristine, base_id + ": no second Rest upgrade")
		_check(deck == pristine and randi() == next_draw, base_id + ": no caller mutation or global RNG")
		# A choice's nested effects are detached from the real catalog and another projection.
		for raw_row in rows:
			if raw_row.get("source_id") == base_id:
				raw_row["effects"]["tampered"] = 999
				raw_row["plus_effects"]["tampered"] = 999
		var repeat := RunRestCardUpgrade.list_authored_choices(deck)
		_check(repeat.get("permitted_upgrades") == permitted
			and repeat.get("choices", [])[0].get("effects") == tc["effect"]
			and catalog.get_definition(base_id).get("effects") == tc["effect"],
			base_id + ": detached nested metadata cannot poison catalog or later projections")
		if earned.get("ok") != true:
			continue
		var mixed: Array = earned["deck"].duplicate(true)
		var at_first := mixed.size()
		mixed.append(base_id)
		var at_second := mixed.size()
		mixed.append(base_id)
		mixed.append(plus_id)
		var registry: Dictionary = earned["descriptors"].duplicate(true)
		var cursor: int = earned["next_stitch_id"]
		var mixed_proj := RunRestCardUpgrade.list_authored_choices(mixed, registry, cursor)
		_check(_is_ok(mixed_proj) and not mixed_proj.get("permitted_upgrades", {}).has(earned["stitched_id"]),
			base_id + ": valid mixed ledger has inert genuine stitched composite")
		var support_indices: Array = []
		for raw_row in mixed_proj.get("choices", []):
			if raw_row.get("source_id") == base_id:
				support_indices.append(raw_row["index"])
			_check(raw_row.get("source_id") != earned["stitched_id"] and raw_row.get("source_id") != plus_id,
				base_id + ": stitched and plus cards excluded from mixed choices")
		_check(support_indices.has(at_first) and support_indices.has(at_second),
			base_id + ": mixed ledger exposes both appended real base indices")
		var mixed_visit := RunRestCardUpgrade.new(mixed, mixed_proj.get("permitted_upgrades", {}), registry, cursor)
		var mixed_result := mixed_visit.choose_upgrade(at_second)
		_check(_is_ok(mixed_result) and mixed_result.get("deck", [])[at_second] == plus_id
			and mixed_result.get("deck", [])[at_first] == base_id
			and mixed_result.get("deck", []).has(earned["stitched_id"])
			and registry == earned["descriptors"],
			base_id + ": upgrade preserves mixed stitch ledger and separate original")
