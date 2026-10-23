extends SceneTree
## Deterministic headless tests for the M04 Dye Vat one-visit event transaction.

const EVENT_PATH := "res://data/events/dye_vat.json"
const SPOOL := "tinker_spool_launcher"
const SPOOL_PLUS := "tinker_spool_launcher_plus"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_authored_event_json()
	_test_immerse_upgrades_exactly_one_card()
	_test_skim_and_leave()
	_test_rejections_are_retryable()
	_test_invalid_ledgers_fail_closed()
	if failures.is_empty():
		print("run_dye_vat_outcome_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_dye_vat_outcome_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "open " + path)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return data


func _event() -> Dictionary:
	var data: Variant = _json(EVENT_PATH)
	_check(data is Dictionary, "dye_vat.json parses as an object")
	return data if data is Dictionary else {}


func _deck() -> Array:
	var data: Variant = _json("res://data/cards/starter_deck.json")
	_check(data is Array, "starter deck parses")
	return (data as Array).duplicate() if data is Array else []


func _index(deck: Array, card: String) -> int:
	for i in range(deck.size()):
		if deck[i] == card:
			return i
	return -1


## A real mixed ledger: one genuine stitched composite plus one appended pool base.
func _mixed_ledger() -> Dictionary:
	var base := _deck()
	var stitch := RunRestStitchCards.new(base, {}, 3)
	var a := _index(base, "seamstress_prick")
	var b := _index(base, "tinker_pop_shot")
	_check(a >= 0 and b >= 0 and a != b, "real cross-owner starter pair exists")
	var stitched: Dictionary = stitch.choose_stitch(a, b, stitch.get_snapshot())
	_check(stitched.get("ok") == true, "genuine stitched ledger built")
	var deck: Array = (stitched["deck"] as Array).duplicate()
	deck.append(SPOOL)
	return {
		"deck": deck,
		"descriptors": (stitched["descriptors"] as Dictionary).duplicate(true),
		"next": int(stitched["next_stitch_id"]),
		"scraps": 3,
		"stitched_id": String(stitched["stitched_id"]),
	}


func _fresh(ledger: Dictionary) -> RunDyeVatOutcome:
	return RunDyeVatOutcome.new(ledger["deck"], ledger["descriptors"], ledger["scraps"], ledger["next"], _event())


func _test_authored_event_json() -> void:
	var event := _event()
	_check(String(event.get("id", "")) == "dye_vat", "event id is dye_vat")
	_check(String(event.get("title", "")) == "The Dye Vat", "event title is The Dye Vat")
	_check(not String(event.get("description", "")).strip_edges().is_empty(), "description is authored")
	var choices: Array = event.get("choices", []) if event.get("choices") is Array else []
	_check(choices.size() == 3, "dye_vat has exactly three choices")
	var rates := {}
	for choice in choices:
		_check(choice is Dictionary, "each choice is an object")
		if not choice is Dictionary:
			continue
		_check(typeof(choice.get("text")) == TYPE_STRING and not String(choice["text"]).strip_edges().is_empty(), "choice text authored")
		var outcome: Dictionary = choice.get("outcome", {}) if choice.get("outcome") is Dictionary else {}
		_check(int(outcome.get("gold", -1)) == 0, "choice gold rate is 0")
		rates[String(choice.get("id", ""))] = int(outcome.get("scraps", 99))
	_check(rates.has("immerse") and rates["immerse"] == -3, "immerse costs 3 scraps")
	_check(rates.has("skim_dye") and rates["skim_dye"] == 1, "skim_dye gains 1 scrap")
	_check(rates.has("leave") and rates["leave"] == 0, "leave changes nothing")
	# The shared generic event service keeps its gold/scraps-only wallet schema.
	var generic := RunEventChoice.new(event)
	_check(generic.is_valid(), "generic RunEventChoice accepts the authored event schema")
	var wallet: Dictionary = generic.choose_with_wallet("skim_dye", {"gold": 0, "scraps": 0})
	_check(wallet.get("ok") == true and int(wallet["wallet"]["scraps"]) == 1, "generic wallet settlement still works")


func _test_immerse_upgrades_exactly_one_card() -> void:
	var tinker := TinkerPoolCards.new()
	var base_def: Dictionary = tinker.get_definition(SPOOL)
	var plus_def: Dictionary = tinker.get_definition(SPOOL_PLUS)
	_check(int(base_def.get("effects", {}).get("damage", 0)) == 3, "authored base deals 3 damage")
	_check(int(base_def.get("effects", {}).get("unravel", 0)) == 3, "authored base applies 3 Unravel")
	_check(int(plus_def.get("effects", {}).get("damage", 0)) == 4, "authored plus deals 4 damage")
	_check(int(plus_def.get("effects", {}).get("unravel", 0)) == 4, "authored plus applies 4 Unravel")
	_check(String(base_def.get("upgrade_id", "")) == SPOOL_PLUS, "catalog link base -> plus")
	_check(String(plus_def.get("base_id", "")) == SPOOL, "catalog link plus -> base")

	var ledger := _mixed_ledger()
	var deck_before: Array = (ledger["deck"] as Array).duplicate()
	var descriptors_before: Dictionary = (ledger["descriptors"] as Dictionary).duplicate(true)
	var spool_index := _index(ledger["deck"], SPOOL)
	_check(spool_index >= 0, "pool base is present in the mixed deck")
	var visit := _fresh(ledger)
	_check(visit.is_valid() and not visit.is_claimed(), "valid visit ready")
	var result: Dictionary = visit.choose("dye_vat", "immerse", spool_index)
	_check(result.get("ok") == true, "immerse accepted: %s" % str(result))
	var next_deck: Array = result.get("deck", [])
	_check(next_deck.size() == deck_before.size(), "deck size unchanged")
	for i in range(deck_before.size()):
		if i == spool_index:
			_check(next_deck[i] == SPOOL_PLUS, "selected occurrence became the exact authored plus")
		else:
			_check(next_deck[i] == deck_before[i], "other card at %d unchanged" % i)
	_check(String(next_deck[spool_index]) == tinker.get_upgrade_id(SPOOL), "upgrade ID equals catalog upgrade_id")
	_check(RunRestStitchCards.is_authored_pool_plus(String(next_deck[spool_index])), "resulting plus is authored")
	var upgraded_def: Dictionary = RunRestStitchCards.resolve_card_definition(String(next_deck[spool_index]))
	_check(int(upgraded_def.get("effects", {}).get("damage", 0)) == 4, "upgraded damage is authored 4")
	_check(int(upgraded_def.get("effects", {}).get("unravel", 0)) == 4, "upgraded Unravel is authored 4")
	_check(int(result.get("scraps", -1)) == 0, "immerse spent exactly 3 scraps")
	_check(int(result.get("spent_scraps", -1)) == 3, "spent receipt is 3")
	_check(result.get("selected_index") == spool_index, "receipt records the selected index")
	_check(String(result.get("replaced_card_id", "")) == SPOOL, "receipt records the replaced ID")
	_check(String(result.get("upgrade_card_id", "")) == SPOOL_PLUS, "receipt records the upgrade ID")
	_check(result.get("descriptors") == descriptors_before, "stitched descriptors unchanged")
	_check(int(result.get("next_stitch_id", -1)) == int(ledger["next"]), "allocator cursor unchanged")
	_check(next_deck.has(String(ledger["stitched_id"])), "genuine stitched card survives")
	_check(ledger["deck"] == deck_before and ledger["descriptors"] == descriptors_before, "caller inputs untouched")
	_check(visit.is_claimed() and not visit.is_valid(), "valid claim latches the visit")
	var replay: Dictionary = visit.choose("dye_vat", "immerse", spool_index)
	_check(replay.get("ok") == false, "duplicate claim rejected")
	_check(replay.get("deck") == deck_before, "duplicate claim proposes no upgrade")
	_check(int(replay.get("scraps", -1)) == 3, "duplicate claim spends nothing")


func _test_skim_and_leave() -> void:
	var skim_ledger := _mixed_ledger()
	var skim_deck: Array = (skim_ledger["deck"] as Array).duplicate()
	var skim := _fresh(skim_ledger)
	var skim_result: Dictionary = skim.choose("dye_vat", "skim_dye")
	_check(skim_result.get("ok") == true, "skim_dye accepted")
	_check(int(skim_result.get("scraps", -1)) == 4, "skim_dye adds exactly 1 scrap")
	_check(int(skim_result.get("earned_scraps", -1)) == 1, "skim_dye receipt records the gain")
	_check(skim_result.get("deck") == skim_deck, "skim_dye does not touch the deck")
	_check(skim_result.get("descriptors") == skim_ledger["descriptors"], "skim_dye leaves descriptors alone")
	_check(int(skim_result.get("next_stitch_id", -1)) == int(skim_ledger["next"]), "skim_dye leaves cursor alone")
	_check(skim.is_claimed(), "skim_dye consumes the visit")
	_check(skim.choose("dye_vat", "skim_dye").get("ok") == false, "second skim_dye rejected")

	var leave_ledger := _mixed_ledger()
	var leave_deck: Array = (leave_ledger["deck"] as Array).duplicate()
	var leave := _fresh(leave_ledger)
	var leave_result: Dictionary = leave.choose("dye_vat", "leave")
	_check(leave_result.get("ok") == true, "leave accepted")
	_check(int(leave_result.get("scraps", -1)) == 3, "leave changes no scraps")
	_check(leave_result.get("deck") == leave_deck, "leave changes no cards")
	_check(leave.get_snapshot()["deck"] == leave_deck, "leave leaves the visit ledger identical")
	_check(leave.is_claimed(), "leave consumes the visit")
	_check(leave.choose("dye_vat", "leave").get("ok") == false, "second leave rejected")


func _test_rejections_are_retryable() -> void:
	var ledger := _mixed_ledger()
	(ledger["deck"] as Array).append(SPOOL_PLUS)
	var deck_before: Array = (ledger["deck"] as Array).duplicate()
	var descriptors_before: Dictionary = (ledger["descriptors"] as Dictionary).duplicate(true)
	var spool_index := _index(ledger["deck"], SPOOL)
	var plus_index := _index(ledger["deck"], SPOOL_PLUS)
	var starter_index := _index(ledger["deck"], "warden_strike")
	var stitched_index := _index(ledger["deck"], String(ledger["stitched_id"]))
	_check(spool_index >= 0 and plus_index >= 0, "pool base and an already-plus card present")
	_check(starter_index >= 0, "starter card present")
	_check(stitched_index >= 0, "stitched card present")

	seed(20261023)
	var expected_draw: int = randi()
	seed(20261023)

	var visit := _fresh(ledger)
	_check(visit.is_valid(), "rejection visit starts valid")
	var cases: Array[Dictionary] = [
		{"label": "already-plus", "event": "dye_vat", "choice": "immerse", "index": plus_index},
		{"label": "starter", "event": "dye_vat", "choice": "immerse", "index": starter_index},
		{"label": "stitched", "event": "dye_vat", "choice": "immerse", "index": stitched_index},
		{"label": "index too low", "event": "dye_vat", "choice": "immerse", "index": -1},
		{"label": "index too high", "event": "dye_vat", "choice": "immerse", "index": ledger["deck"].size()},
		{"label": "non-int index", "event": "dye_vat", "choice": "immerse", "index": "0"},
		{"label": "missing index", "event": "dye_vat", "choice": "immerse", "index": null},
		{"label": "unknown choice", "event": "dye_vat", "choice": "dip", "index": spool_index},
		{"label": "wrong event", "event": "quiet_spool", "choice": "immerse", "index": spool_index},
		{"label": "blank event", "event": "", "choice": "immerse", "index": spool_index},
		{"label": "event case", "event": "Dye_Vat", "choice": "immerse", "index": spool_index},
		{"label": "choice case", "event": "dye_vat", "choice": "Immerse", "index": spool_index},
	]
	for case_entry: Dictionary in cases:
		var rejected: Dictionary = visit.choose(case_entry["event"], case_entry["choice"], case_entry["index"])
		_check(rejected.get("ok") == false, "rejected: %s" % case_entry["label"])
		_check(rejected.get("deck") == deck_before, "%s proposes no deck change" % case_entry["label"])
		_check(rejected.get("descriptors") == descriptors_before, "%s proposes no descriptor change" % case_entry["label"])
		_check(int(rejected.get("scraps", -1)) == 3, "%s spends nothing" % case_entry["label"])
		_check(String(rejected.get("upgrade_card_id", "x")) == "", "%s creates no upgrade ID" % case_entry["label"])
		_check(not visit.is_claimed(), "%s leaves the visit usable" % case_entry["label"])
	_check(ledger["deck"] == deck_before and ledger["descriptors"] == descriptors_before, "rejections never mutate inputs")

	# Below-cost visits: 2 scraps cannot immerse, and the failure stays retryable for skim.
	var poor := _mixed_ledger()
	poor["scraps"] = 2
	var poor_visit := _fresh(poor)
	var poor_result: Dictionary = poor_visit.choose("dye_vat", "immerse", _index(poor["deck"], SPOOL))
	_check(poor_result.get("ok") == false, "immerse with 2 scraps rejected")
	_check(poor_result.get("deck") == poor["deck"], "insufficient scraps proposes no upgrade")
	_check(int(poor_result.get("scraps", -1)) == 2, "insufficient scraps spends nothing")
	_check(not poor_visit.is_claimed(), "insufficient scraps leaves the visit usable")
	var poor_skim: Dictionary = poor_visit.choose("dye_vat", "skim_dye")
	_check(poor_skim.get("ok") == true and int(poor_skim.get("scraps", -1)) == 3, "same visit still allows a legal skim")
	_check(poor_visit.choose("dye_vat", "immerse", _index(poor["deck"], SPOOL)).get("ok") == false, "no second claim after skim")

	# A rejected-first visit still accepts the real upgrade afterwards.
	var recovered: Dictionary = visit.choose("dye_vat", "immerse", spool_index)
	_check(recovered.get("ok") == true, "valid immerse works after rejections")
	_check(int(recovered.get("scraps", -1)) == 0, "recovered immerse spends 3")
	_check(visit.choose("dye_vat", "leave").get("ok") == false, "claim is single after recovery")

	_check(randi() == expected_draw, "Dye Vat never advances the global RNG stream")


func _test_invalid_ledgers_fail_closed() -> void:
	var ledger := _mixed_ledger()
	# Counterfeit descriptor.
	var bad_descriptors: Dictionary = (ledger["descriptors"] as Dictionary).duplicate(true)
	var stitched_id := String(ledger["stitched_id"])
	var descriptor: Dictionary = (bad_descriptors[stitched_id] as Dictionary).duplicate(true)
	descriptor["cost"] = 0
	bad_descriptors[stitched_id] = descriptor
	var visit := RunDyeVatOutcome.new(ledger["deck"], bad_descriptors, 3, ledger["next"], _event())
	_check(not visit.is_valid(), "counterfeit descriptor ledger invalid")
	_check(visit.choose("dye_vat", "skim_dye").get("ok") == false, "invalid ledger rejects every choice")
	_check((visit.get_snapshot()["deck"] as Array).is_empty(), "invalid ledger holds no deck state")

	# Unknown card (guessed suffix) in the deck.
	var bad_deck: Array = (ledger["deck"] as Array).duplicate()
	bad_deck.append("tinker_spool_launcher_plus_fake")
	var unknown_visit := RunDyeVatOutcome.new(bad_deck, ledger["descriptors"], 3, ledger["next"], _event())
	_check(not unknown_visit.is_valid(), "guessed suffix / counterfeit card makes the ledger invalid")
	_check(unknown_visit.choose("dye_vat", "leave").get("ok") == false, "counterfeit deck rejects leave")

	# Missing cursor serial for a registered stitched card.
	var bad_cursor := RunDyeVatOutcome.new(ledger["deck"], ledger["descriptors"], 3, 1, _event())
	_check(not bad_cursor.is_valid(), "stale allocator cursor rejected")

	# Event record with a retuned rate or the wrong ID.
	var event := _event()
	var retuned: Dictionary = event.duplicate(true)
	(retuned["choices"] as Array)[0]["outcome"]["scraps"] = -2
	var retuned_visit := RunDyeVatOutcome.new(ledger["deck"], ledger["descriptors"], 3, ledger["next"], retuned)
	_check(not retuned_visit.is_valid(), "retuned event rates rejected")
	var other_event := RunDyeVatOutcome.new(ledger["deck"], ledger["descriptors"], 3, ledger["next"], {"id": "other"})
	_check(not other_event.is_valid(), "wrong event record rejected")

	# The shipped file loads when no record is supplied.
	var shipped := RunDyeVatOutcome.new(ledger["deck"], ledger["descriptors"], 3, ledger["next"])
	_check(shipped.is_valid(), "shipped dye_vat JSON loads by default")
