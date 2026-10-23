extends SceneTree
## Deterministic Rest stitch transactions and pure dual-owner hand-legality preview.

const PRICK := "seamstress_prick"
const POP := "tinker_pop_shot"
const BOMB := "tinker_scrap_bomb"
const STRIKE := "warden_strike"
const STRIKE_PLUS := "warden_strike_plus"
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_pool_plus_mixed_ledger_continuity()
	_test_original_transaction_and_rng()
	_test_eligibility_order_and_isolation()
	_test_negative_matrix_and_retry()
	_test_two_visits_upgrade_and_shop()
	_test_invalid_ledgers()
	_test_pool_base_cards_stitch()
	_test_pool_plus_cards_stitch_and_reload()
	_test_pool_negative_matrix()
	if failures.is_empty():
		print("run_rest_stitch_cards_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_rest_stitch_cards_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	_check(file != null, "open shipped JSON " + path)
	if file == null:
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	_check(data is Array, "shipped JSON array " + path)
	return data


func _deck() -> Array[String]:
	var content: Variant = _json("res://data/cards/starter_deck.json")
	var result: Array[String] = []
	if content is Array:
		for id in content:
			_check(id is String, "starting deck contains string-only IDs")
			if id is String:
				result.append(id)
	return result


func _party() -> Array[Dictionary]:
	var definitions: Variant = _json("res://data/heroes/starter_party.json")
	if not definitions is Array:
		return []
	for definition in definitions:
		if definition is Dictionary and typeof(definition.get("max_hp")) == TYPE_FLOAT:
			_check(definition["max_hp"] == floor(definition["max_hp"]), "shipped max_hp is integral")
			definition["max_hp"] = int(definition["max_hp"])
	var party := CombatParty.new(definitions)
	_check(party.is_valid(), "real CombatParty created from shipped hero definitions")
	return party.get_heroes()


func _index(deck: Array, card: String, nth: int = 0) -> int:
	var count := 0
	for i in range(deck.size()):
		if deck[i] == card:
			if count == nth:
				return i
			count += 1
	return -1


func _is_success(result: Variant) -> bool:
	return result is Dictionary and result.get("ok") == true


func _reject(service: RunRestStitchCards, a: Variant, b: Variant, expected: Variant, label: String) -> void:
	var before := service.get_snapshot()
	var used := service.is_consumed()
	var result := service.choose_stitch(a, b, expected)
	_check(result.get("ok", true) == false, label + " rejected")
	_check(service.get_snapshot() == before and service.is_consumed() == used, label + " entire ledger/latch unchanged")
	_check(result.get("deck") == before["deck"] and result.get("descriptors") == before["descriptors"]
		and result.get("remaining_scraps") == before["remaining_scraps"]
		and result.get("next_stitch_id") == before["next_stitch_id"]
		and result.get("receipt") == before["receipt"], label + " rejected receipt/state preserved")
	_check(result.get("stitched_id") == "" and result.get("consumed_ids") == []
		and result.get("consumed_indices") == [] and result.get("descriptor") == {},
		label + " creates no phantom stitched ID, consumption or descriptor")


func _test_original_transaction_and_rng() -> void:
	var source := _deck()
	var catalog := StarterCards.new()
	_check(source.size() >= 12, "real shared deck has starter instances")
	_check(source.count(PRICK) == 2 and source.count(POP) == 2, "real repeated Prick and Pop copies exist")
	_check(catalog.get_definition(PRICK).get("owner") == "seamstress"
		and catalog.get_definition(POP).get("owner") == "tinker", "real cross-owner pair")
	var a := _index(source, PRICK)
	var b := _index(source, POP)
	_check(a >= 0 and b >= 0 and a != b, "distinct real starter indices")
	if a < 0 or b < 0:
		return
	var before := source.duplicate()
	var visit := RunRestStitchCards.new(source, {}, 3)
	_check(visit.is_valid() and not visit.is_consumed(), "valid Rest visit ready")
	_check(visit.has_method("choose_stitch") and visit.has_method("preview_play") and visit.has_method("get_snapshot"), "public transaction and preview methods")
	var snapshot := visit.get_snapshot()
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 20261021
	var rng_state := local_rng.state
	seed(20261021)
	var global_next := randi()
	seed(20261021)
	var result := visit.choose_stitch(a, b, snapshot)
	_check(randi() == global_next and local_rng.state == rng_state, "no global or injected RNG draw")
	_check(_is_success(result) and visit.is_consumed(), "accepted Rest stitch consumes exactly one choice")
	if not _is_success(result):
		return
	_check(source == before and snapshot["deck"] == before, "caller deck and submitted snapshot untouched")
	_check(result["deck"].size() == before.size() - 1 and result["remaining_scraps"] == 0,
		"12-to-11 shared-deck transition and 3-to-0 scraps")
	var id: String = result["stitched_id"]
	_check(id == "stitched_000001" and result["next_stitch_id"] == 2,
		"first deterministic durable ID and advanced cursor")
	_check(result["deck"].count(id) == 1 and result["deck"].count(PRICK) == 1
		and result["deck"].count(POP) == 1, "exactly one copy of each consumed, one stitch inserted")
	var expected := before.duplicate()
	expected.remove_at(maxi(a, b))
	expected.remove_at(mini(a, b))
	expected.insert(mini(a, b), id)
	_check(result["deck"] == expected, "untouched survivors remain in original deck order")
	_check(result["consumed_indices"] == [a, b] and result["consumed_ids"] == [PRICK, POP],
		"receipt identifies ordered selected instances")
	_check(result["source_receipt"] == snapshot["receipt"] and result["receipt"] != snapshot["receipt"],
		"source receipt preserved; crafted ledger has new receipt")
	var desc: Dictionary = result["descriptors"][id].duplicate(true)
	_check(desc == result["descriptor"] and desc["display_name"] == "Prick / Pop Shot" and desc["cost"] == 2,
		"authored joined name, computed capped cost, registry receipt")
	_check(desc["half_ids"] == [PRICK, POP] and desc["owners"] == ["seamstress", "tinker"]
		and not desc["can_upgrade"] and not desc["can_stitch"], "halves and permanent nonupgrade/nonrestitch flags")
	_check(desc["first_half"] == catalog.get_definition(PRICK)
		and desc["second_half"] == catalog.get_definition(POP), "entire canonical definitions retained in order")
	_check(desc["first_half"]["effects"] == {"damage": 3, "bleed": 2}
		and desc["second_half"]["effects"] == {"damage": 5}, "authored effects unchanged; no passive applied")
	var rerun := RunRestStitchCards.new(before, {}, 3)
	var replay := rerun.choose_stitch(a, b, rerun.get_snapshot())
	_check(replay == result, "fresh independent run deterministically reproduces complete receipt")
	_reject(visit, a, b, snapshot, "second choice after successful visit")
	_check(visit.get_snapshot()["deck"] == result["deck"], "repeat rejection cannot undo committed card")
	result["descriptors"][id]["first_half"]["effects"]["damage"] = 999
	result["deck"].clear()
	result["descriptor"]["second_half"]["effects"]["damage"] = 777
	var intact := visit.get_snapshot()
	_check(intact["deck"] == expected and intact["descriptors"][id] == desc,
		"all returned receipt containers are deep detached")
	intact["descriptors"][id]["first_half"]["effects"]["damage"] = 500
	_check(visit.get_snapshot()["descriptors"][id]["first_half"]["effects"]["damage"] == 3,
		"two consecutive service reads are independently detached")


func _test_eligibility_order_and_isolation() -> void:
	var deck := _deck()
	var a := _index(deck, PRICK)
	var b := _index(deck, BOMB)
	_check(a >= 0 and b >= 0, "actual Prick and Scrap Bomb in shipped deck")
	if a < 0 or b < 0:
		return
	var visit := RunRestStitchCards.new(deck, {}, 3)
	var result := visit.choose_stitch(a, b, visit.get_snapshot())
	_check(_is_success(result), "Prick / Scrap Bomb crafted")
	if not _is_success(result):
		return
	var id: String = result["stitched_id"]
	_check(result["descriptor"]["cost"] == 3 and result["descriptor"]["display_name"] == "Prick / Scrap Bomb",
		"max(1,2)+1 capped at 3")
	var heroes := _party()
	if heroes.size() != 3:
		return
	_check(heroes[0]["id"] == "warden" and heroes[0]["position"] == 1 and heroes[0]["hp"] == 40
		and heroes[1]["id"] == "seamstress" and heroes[1]["position"] == 2 and heroes[1]["hp"] == 30
		and heroes[2]["id"] == "tinker" and heroes[2]["position"] == 3 and heroes[2]["hp"] == 26,
		"real party includes all three alive owners in authored slots")
	var original_heroes := heroes.duplicate(true)
	var initial := visit.get_snapshot()
	var legal := visit.preview_play(id, heroes)
	_check(legal.get("ok") == true and legal.get("cost") == 3, "two real living, positioned owners eligible")
	var catalog := StarterCards.new()
	_check(legal["first_half"] == catalog.get_definition(PRICK)
		and legal["second_half"] == catalog.get_definition(BOMB)
		and legal["halves"] == [catalog.get_definition(PRICK), catalog.get_definition(BOMB)],
		"ordered, independent exact authored halves with individual targets")
	_check(legal["first_half"]["target_kind"] == "enemy_single"
		and legal["second_half"]["target_kind"] == "enemy_all"
		and legal["second_half"]["from_positions"] == [3], "per-half targeting and from positions remain distinct")
	heroes[1]["position"] = 3
	heroes[2]["position"] = 2
	var moved := heroes.duplicate(true)
	var illegal := visit.preview_play(id, heroes)
	_check(illegal["ok"] == false and illegal["halves"] == [], "Tinker at 2 fails Scrap Bomb position 3 even though Prick is legal")
	_check(heroes == moved, "preview cannot correct or move actors")
	heroes = original_heroes.duplicate(true)
	for downed in [1, 2]:
		var fixture := heroes.duplicate(true)
		fixture[downed]["hp"] = 0
		var rejected := visit.preview_play(id, fixture)
		_check(rejected["ok"] == false and rejected["first_half"] == {} and rejected["second_half"] == {},
			"downed owner index %d prevents dual-owner play" % downed)
	var restored := visit.preview_play(id, heroes)
	_check(restored == legal, "restored real owner snapshots regain ordered eligibility")
	legal["first_half"]["effects"]["bleed"] = 999
	legal["halves"][1]["effects"]["damage"] = 999
	_check(visit.preview_play(id, heroes)["first_half"]["effects"]["bleed"] == 2
		and visit.preview_play(id, heroes)["second_half"]["effects"]["damage"] == 4,
		"preview definitions detached from owned registry and each other")
	_check(heroes == original_heroes and visit.get_snapshot() == initial,
		"all legality checks pure, no combat/party/deck/currency/receipt mutations")
	_check(not visit.preview_play("not_real", heroes)["ok"]
		and not visit.preview_play(id, [heroes[0]])["ok"], "unknown IDs and incomplete real roster fail closed")


func _test_negative_matrix_and_retry() -> void:
	var deck := _deck()
	var a := _index(deck, PRICK)
	var b := _index(deck, POP)
	var w1 := _index(deck, STRIKE)
	var w2 := _index(deck, STRIKE, 1)
	_check(a >= 0 and b >= 0 and w1 >= 0 and w2 >= 0 and w1 != w2,
		"negative matrix has two genuine Warden Strike copies")
	if a < 0 or b < 0 or w1 < 0 or w2 < 0:
		return
	var visit := RunRestStitchCards.new(deck, {}, 3)
	var receipt := visit.get_snapshot()
	for pair in [[a,a], [w1,w2], [-1,b], [a,deck.size()], [null,b], [1.5,b], ["0",b]]:
		_reject(visit, pair[0], pair[1], receipt, "bad pair " + str(pair))
	var wrong_deck := receipt.duplicate(true)
	wrong_deck["deck"][w1] = "warden_brace"
	_reject(visit, a, b, wrong_deck, "stale original deck")
	var wrong_registry := receipt.duplicate(true)
	wrong_registry["descriptors"]["stitched_999999"] = {}
	_reject(visit, a, b, wrong_registry, "stale descriptor ledger")
	var wrong_receipt := receipt.duplicate(true)
	wrong_receipt["receipt"] = "stale receipt"
	_reject(visit, a, b, wrong_receipt, "stale receipt token")
	var wrong_scraps := receipt.duplicate(true)
	wrong_scraps["remaining_scraps"] = 4
	_reject(visit, a, b, wrong_scraps, "stale currency")
	var wrong_cursor := receipt.duplicate(true)
	wrong_cursor["next_stitch_id"] = 9
	_reject(visit, a, b, wrong_cursor, "stale allocator cursor")
	_reject(visit, a, b, {}, "missing snapshot")
	_reject(visit, a, b, null, "null snapshot")
	var poor := RunRestStitchCards.new(deck, {}, 2)
	_reject(poor, a, b, poor.get_snapshot(), "insufficient scraps")
	_check(not poor.is_consumed(), "unaffordable visit remains open, never charged")
	for bad in [-1, -3, 0.5]:
		var invalid := RunRestStitchCards.new(deck, {}, bad)
		_check(not invalid.is_valid(), "negative or fractional currency invalid at construction")
		_reject(invalid, a, b, invalid.get_snapshot(), "invalid currency " + str(bad))
	var ok := visit.choose_stitch(a, b, receipt)
	_check(_is_success(ok) and ok["stitched_id"] == "stitched_000001" and ok["remaining_scraps"] == 0,
		"valid retry after ALL rejected attempts uses first ID and spends exactly three")
	if not _is_success(ok):
		return
	_reject(visit, w1, w2, receipt, "repeated submission in consumed visit")
	var next_visit := RunRestStitchCards.new(ok["deck"], ok["descriptors"], 4, ok["next_stitch_id"])
	_check(next_visit.is_valid(), "later visit can load an actual owned stitched descriptor")
	var stitched_index := _index(ok["deck"], ok["stitched_id"])
	_reject(next_visit, stitched_index, _index(ok["deck"], STRIKE), next_visit.get_snapshot(), "already stitched half")
	_check(next_visit.choose_stitch(_index(ok["deck"], STRIKE), _index(ok["deck"], POP), next_visit.get_snapshot())["ok"],
		"valid retry after already-stitched rejection remains possible")


func _test_two_visits_upgrade_and_shop() -> void:
	var deck := _deck()
	var strike := _index(deck, STRIKE)
	var pop := _index(deck, POP)
	if strike < 0 or pop < 0:
		_check(false, "authored Strike / Pop Shot present")
		return
	var upgraded := RunRestCardUpgrade.new(deck, {STRIKE: STRIKE_PLUS}).choose_upgrade(strike)
	_check(upgraded.get("ok") == true, "existing Rest upgrade turns one real Strike into Strike+ before stitch")
	if not _is_success(upgraded):
		return
	var run_deck: Array = upgraded["deck"]
	_check(run_deck[strike] == STRIKE_PLUS and run_deck.count(STRIKE) >= 1, "only selected Strike copy upgraded")
	var first := RunRestStitchCards.new(run_deck, {}, 6)
	var one := first.choose_stitch(strike, pop, first.get_snapshot())
	_check(_is_success(one), "first upgraded-half stitch succeeds")
	if not _is_success(one):
		return
	var id1: String = one["stitched_id"]
	var desc1: Dictionary = one["descriptor"]
	_check(desc1["display_name"] == "Strike+ / Pop Shot" and desc1["cost"] == 2
		and desc1["first_half"] == StarterCards.new().get_definition(STRIKE_PLUS)
		and desc1["first_half"]["effects"]["damage"] == 7, "upgraded half stored with complete authentic authored effect")
	var later := RunRestStitchCards.new(one["deck"], one["descriptors"], one["remaining_scraps"], one["next_stitch_id"])
	_check(later.is_valid(), "next Rest loads committed deck/descriptor/cursor")
	var one_again := later.get_snapshot()
	var two := later.choose_stitch(_index(one["deck"], PRICK), _index(one["deck"], POP), one_again)
	_check(_is_success(two), "second visit still has a cross-owner pair")
	if not _is_success(two):
		return
	var id2: String = two["stitched_id"]
	_check(id2 != id1 and two["descriptors"].size() == 2 and two["deck"].count(id1) == 1
		and two["deck"].count(id2) == 1 and two["remaining_scraps"] == 0, "unique IDs and surviving first stitched descriptor")
	var replay := RunRestStitchCards.new(one["deck"], one["descriptors"], 3, one["next_stitch_id"])
	_check(replay.choose_stitch(_index(one["deck"], PRICK), _index(one["deck"], POP), replay.get_snapshot())["stitched_id"] == id2,
		"second visit allocation reproducible")
	# Existing upgrade rejects stitched IDs rather than authoring an upgrade.
	var upgrading_composite := RunRestCardUpgrade.new(two["deck"], {id1: "forged_composite_plus"})
	_check(not upgrading_composite.choose_upgrade(_index(two["deck"], id1))["ok"],
		"existing Rest upgrader rejects stitched deck instead of upgrading a composite")
	var owned: Array[String] = []
	owned.assign(two["deck"])
	var removed := RunShopCardRemoval.try_remove(owned, 175, 0, id1)
	_check(removed["ok"] and removed["price"] == 75 and removed["gold"] == 100
		and removed["prior_removals"] == 1, "Shop preserves 75-gold first removal cost")
	_check(removed["deck"].size() == owned.size() - 1 and removed["deck"].count(id1) == 0
		and removed["deck"].count(id2) == 1 and owned.count(id1) == 1,
		"Shop removes the composite as precisely one ID, with another preserved")
	var second_remove := RunShopCardRemoval.try_remove(removed["deck"], removed["gold"], removed["prior_removals"], id2)
	_check(second_remove["ok"] and second_remove["price"] == 100 and second_remove["gold"] == 0
		and second_remove["deck"].count(id2) == 0, "existing Shop +25 pricing and whole stitched card removal")
	var third := RunRestStitchCards.new(two["deck"], two["descriptors"], 3, two["next_stitch_id"])
	_check(third.is_valid(), "owned descriptor registry survives multiple visits")
	var duplicate_deck: Array = _deck()
	var p1 := _index(duplicate_deck, PRICK)
	var t1 := _index(duplicate_deck, POP)
	var repeated_first := RunRestStitchCards.new(duplicate_deck, {}, 6)
	var pair1 := repeated_first.choose_stitch(p1, t1, repeated_first.get_snapshot())
	var repeated_second := RunRestStitchCards.new(pair1["deck"], pair1["descriptors"], 3, pair1["next_stitch_id"])
	var pair2 := repeated_second.choose_stitch(_index(pair1["deck"], PRICK), _index(pair1["deck"], POP), repeated_second.get_snapshot())
	_check(pair1["ok"] and pair2["ok"] and pair1["stitched_id"] != pair2["stitched_id"]
		and pair2["descriptors"][pair1["stitched_id"]]["half_ids"] == [PRICK, POP]
		and pair2["descriptors"][pair2["stitched_id"]]["half_ids"] == [PRICK, POP],
		"two identical ordered pairs still get independent durable entries")


func _test_invalid_ledgers() -> void:
	var deck := _deck()
	var a := _index(deck, PRICK)
	var b := _index(deck, POP)
	for bad_deck in [[], ["unknown_hero_card"], [PRICK, "fake_stitched_id"], [12, POP]]:
		var invalid := RunRestStitchCards.new(bad_deck, {}, 3)
		_check(not invalid.is_valid(), "unknown, missing or non-string catalog entry cannot initialize")
		_reject(invalid, 0, 1, invalid.get_snapshot(), "untrusted deck " + str(bad_deck))
	var invalid_registry := RunRestStitchCards.new([PRICK, "stitched_000001"], {}, 3, 2)
	_check(not invalid_registry.is_valid(), "stitched ID without registry is invalid")
	_reject(invalid_registry, 0, 1, invalid_registry.get_snapshot(), "fabricated composite without halves")
	var base := RunRestStitchCards.new(deck, {}, 3)
	var made := base.choose_stitch(a, b, base.get_snapshot())
	if not _is_success(made):
		_check(false, "fixture descriptor constructed from two actual cards")
		return
	var forged: Dictionary = made["descriptors"].duplicate(true)
	forged[made["stitched_id"]]["first_half"]["effects"]["damage"] = 999
	_check(not RunRestStitchCards.new(made["deck"], forged, 5, made["next_stitch_id"]).is_valid(),
		"forged half effect cannot be persisted as authored definition")
	var wrong_owner: Dictionary = made["descriptors"].duplicate(true)
	wrong_owner[made["stitched_id"]]["owners"] = ["warden", "tinker"]
	_check(not RunRestStitchCards.new(made["deck"], wrong_owner, 5, made["next_stitch_id"]).is_valid(),
		"forged owner data fails closed")
	_check(not RunRestStitchCards.new(made["deck"], made["descriptors"], 3, 1).is_valid(),
		"stale serial cursor cannot overwrite existing registry ID")
	var orphan: Array = made["deck"].duplicate()
	orphan.erase(made["stitched_id"])
	_check(not RunRestStitchCards.new(orphan, made["descriptors"], 3, made["next_stitch_id"]).is_valid(),
		"descriptor cannot silently remain as an unowned deck entry")


## A reward-base plus is a legal MEMBER of the persisted Rest/Shop ledger,
## and a legal stitched half when combined with another hero's card.
func _test_pool_plus_mixed_ledger_continuity() -> void:
	var original := _deck()
	var first_rest := RunRestStitchCards.new(original, {}, 3)
	_check(first_rest.is_valid(), "pool-plus fixture starts with valid real starter Rest")
	var first := first_rest.choose_stitch(_index(original, PRICK), _index(original, POP),
		first_rest.get_snapshot())
	_check(_is_success(first), "pool-plus fixture has an authentic first starter composite")
	if not _is_success(first):
		return
	var existing_id: String = first["stitched_id"]
	var owned: Array = first["deck"].duplicate(true)
	owned.append_array(["warden_iron_hem", "warden_iron_hem_plus",
		"seamstress_running_stitch_plus", "tinker_rivet_shot_plus"])
	var expected_owned := owned.duplicate(true)
	var descriptors: Dictionary = first["descriptors"].duplicate(true)
	var cursor: int = first["next_stitch_id"]
	var visit := RunRestStitchCards.new(owned, descriptors, 3, cursor)
	_check(visit.is_valid() and not visit.is_consumed(),
		"mixed pool base, three plus cards and genuine stitched descriptor admitted")
	if not visit.is_valid():
		return
	var opening := visit.get_snapshot()
	_check(opening["deck"] == expected_owned and opening["descriptors"] == descriptors
		and opening["next_stitch_id"] == 2 and opening["remaining_scraps"] == 3
		and not opening["receipt"].is_empty(), "mixed snapshot keeps order, registry, currency, cursor and receipt")
	var reloaded := RunRestStitchCards.new(opening["deck"], opening["descriptors"],
		opening["remaining_scraps"], opening["next_stitch_id"])
	_check(reloaded.is_valid() and reloaded.get_snapshot() == opening,
		"mixed ledger round-trips through fresh Rest with identical receipt")
	_check(owned == expected_owned and descriptors == first["descriptors"],
		"constructor and snapshot do not alter caller ownership")
	var warden_plus := _index(owned, "warden_iron_hem_plus")
	var seam_plus := _index(owned, "seamstress_running_stitch_plus")
	var tinker_plus := _index(owned, "tinker_rivet_shot_plus")
	var first_index := _index(owned, STRIKE)
	var second_index := _index(owned, "seamstress_mend")
	_check(warden_plus >= 0 and seam_plus >= 0 and tinker_plus >= 0
		and first_index >= 0 and second_index >= 0,
		"all genuine plus members and permitted starter halves have owned indices")
	if warden_plus < 0 or seam_plus < 0 or tinker_plus < 0 or first_index < 0 or second_index < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var rng_before := rng.state
	seed(2088)
	var global_expected := randi()
	seed(2088)

	# Same hero pool plus pair remains rejected
	_reject(visit, warden_plus, first_index, opening, "same hero pool plus pair rejected")

	# Replace old negative expectations with successful legal cross-hero + examples
	var cross_probe_1 := RunRestStitchCards.new(opening["deck"], opening["descriptors"],
		opening["remaining_scraps"], opening["next_stitch_id"])
	var res_plus_starter := cross_probe_1.choose_stitch(seam_plus, first_index, opening)
	_check(_is_success(res_plus_starter), "legal cross-hero pool plus with starter succeeds")
	_check(res_plus_starter["descriptor"]["display_name"] == "Running Stitch+ / Strike"
		and res_plus_starter["descriptor"]["cost"] == 2
		and res_plus_starter["descriptor"]["half_ids"] == ["seamstress_running_stitch_plus", STRIKE]
		and res_plus_starter["descriptor"]["owners"] == ["seamstress", "warden"]
		and not res_plus_starter["descriptor"]["can_upgrade"]
		and not res_plus_starter["descriptor"]["can_stitch"],
		"cross-hero pool plus with starter produces correct descriptor")

	var cross_probe_2 := RunRestStitchCards.new(opening["deck"], opening["descriptors"],
		opening["remaining_scraps"], opening["next_stitch_id"])
	var res_plus_plus := cross_probe_2.choose_stitch(seam_plus, tinker_plus, opening)
	_check(_is_success(res_plus_plus), "legal cross-hero pool plus pair succeeds")
	_check(res_plus_plus["descriptor"]["display_name"] == "Running Stitch+ / Rivet Shot+"
		and res_plus_plus["descriptor"]["cost"] == 2
		and res_plus_plus["descriptor"]["half_ids"] == ["seamstress_running_stitch_plus", "tinker_rivet_shot_plus"]
		and res_plus_plus["descriptor"]["owners"] == ["seamstress", "tinker"]
		and not res_plus_plus["descriptor"]["can_upgrade"]
		and not res_plus_plus["descriptor"]["can_stitch"],
		"cross-hero pool plus pair produces correct descriptor")

	_reject(visit, _index(owned, existing_id), first_index, opening,
		"existing composite is not stitchable half")
	_reject(visit, first_index, _index(owned, STRIKE, 1), opening, "same hero stitch pair")
	var poor := RunRestStitchCards.new(owned, descriptors, 2, cursor)
	_check(poor.is_valid(), "mixed ledger with insufficient scraps is otherwise valid")
	_reject(poor, first_index, second_index, poor.get_snapshot(), "mixed ledger insufficient scraps")
	var stale := opening.duplicate(true)
	stale["descriptors"][existing_id]["first_half"]["effects"]["damage"] = 500
	_reject(visit, first_index, second_index, stale, "mixed ledger forged stale descriptor receipt")
	var bad_registry := descriptors.duplicate(true)
	bad_registry[existing_id]["owners"] = ["warden", "warden"]
	_check(not RunRestStitchCards.new(owned, bad_registry, 3, cursor).is_valid(),
		"pool plus cannot excuse forged descriptor owners")
	var orphan := owned.duplicate(true)
	orphan.erase(existing_id)
	_check(not RunRestStitchCards.new(orphan, descriptors, 3, cursor).is_valid(),
		"pool plus cannot excuse orphaned descriptor")
	for forged in ["warden_iron_hem_plus_plus", "seamstress_unknown_plus", "tinker_rivet_shot_fake_plus"]:
		var bad := owned.duplicate(true)
		bad.append(forged)
		_check(not RunRestStitchCards.new(bad, descriptors, 3, cursor).is_valid(),
			"forged plus rejected as ordinary deck member: " + forged)
	var made := visit.choose_stitch(first_index, second_index, opening)
	_check(_is_success(made) and visit.is_consumed(), "valid starter halves stitch after pool-plus rejections")
	if not _is_success(made):
		return
	var new_id: String = made["stitched_id"]
	var expected := expected_owned.duplicate()
	expected.remove_at(maxi(first_index, second_index))
	expected.remove_at(mini(first_index, second_index))
	expected.insert(mini(first_index, second_index), new_id)
	_check(made["deck"] == expected and made["deck"].size() == expected_owned.size() - 1,
		"mixed-deck stitch alters exactly two chosen starter slots and preserves survivors")
	_check(made["consumed_indices"] == [first_index, second_index]
		and made["consumed_ids"] == [STRIKE, "seamstress_mend"],
		"mixed stitch receipt reports exact original instance indices and IDs")
	_check(made["remaining_scraps"] == 0 and made["next_stitch_id"] == 3
		and new_id == "stitched_000002" and made["descriptors"].size() == 2,
		"three scraps spent exactly once and allocator monotonically advanced")
	_check(made["descriptors"][existing_id] == descriptors[existing_id]
		and made["descriptor"]["first_half"] == StarterCards.new().get_definition(STRIKE)
		and made["descriptor"]["second_half"] == StarterCards.new().get_definition("seamstress_mend"),
		"both descriptors preserve canonical starter-only halves and original composite")
	for plus_id in ["warden_iron_hem_plus", "seamstress_running_stitch_plus", "tinker_rivet_shot_plus"]:
		_check(made["deck"].count(plus_id) == 1 and expected_owned.count(plus_id) == 1,
			"stitch leaves existing pool plus entry untouched: " + plus_id)
	_check(made["source_receipt"] == opening["receipt"] and made["receipt"] != opening["receipt"]
		and rng.state == rng_before and randi() == global_expected,
		"mixed stitch advances receipt without drawing injected or global RNG")
	_reject(visit, first_index, second_index, opening, "mixed stitch replay cannot spend again")
	var later := RunRestStitchCards.new(made["deck"], made["descriptors"], 6, made["next_stitch_id"])
	_check(later.is_valid() and later.get_snapshot()["deck"] == made["deck"]
		and later.get_snapshot()["descriptors"] == made["descriptors"]
		and later.get_snapshot()["next_stitch_id"] == 3, "mixed deck and both descriptors survive later Rest")
	var owned_shop_deck: Array[String] = []
	owned_shop_deck.assign(made["deck"])
	var shop := RunShopVisit.new(owned_shop_deck, 175, 0, [], made["descriptors"], made["next_stitch_id"])
	_check(shop.get_state()["valid"] and shop.open_visit("pool-plus-mixed-shop"),
		"real Shop visit accepts mixed plus and stitched ownership")
	var removed := shop.remove_card(existing_id)
	var after_remove: Array = made["deck"].duplicate()
	after_remove.erase(existing_id)
	var after_descriptors: Dictionary = made["descriptors"].duplicate(true)
	after_descriptors.erase(existing_id)
	_check(removed["ok"] and removed["price"] == 75 and removed["gold"] == 100
		and removed["prior_removals"] == 1 and removed["deck"] == after_remove
		and removed["descriptors"] == after_descriptors and removed["next_stitch_id"] == 3,
		"priced Shop composite removal retires only its owned descriptor")
	_check(shop.get_state()["deck"] == after_remove and shop.get_state()["descriptors"] == after_descriptors,
		"Shop commits mixed ledger without deleting pool plus cards")
	_check(shop.close_visit() and RunRestStitchCards.new(after_remove, after_descriptors, 3, 3).is_valid(),
		"paid Shop result and unchanged allocator survive another Rest visit")
	_check(owned == expected_owned and descriptors == first["descriptors"],
		"full mixed Rest to Shop chain leaves original caller ledgers detached")


func _test_pool_base_cards_stitch() -> void:
	# AC1: valid unconsumed Rest ledger, >= 3 scraps, two owned base pool cards from different heroes.
	# Original indices selected succeeds: each copy removed, composite at earlier index, 3 scraps spent once,
	# allocator advanced once, duplicate copy index behavior, exact before/after ledger, unchanged RNG.
	var deck: Array[String] = [
		"warden_hold_the_line",      # 0 (Warden base, cost 1)
		"seamstress_prick",          # 1 (Seamstress starter, cost 1)
		"tinker_pop_shot",           # 2 (Tinker starter, cost 1)
		"seamstress_running_stitch", # 3 (Seamstress base, cost 1)
		"warden_heavy_thimble",      # 4 (Warden base, cost 1)
		"tinker_rivet_shot",         # 5 (Tinker base, cost 1)
		"warden_hold_the_line",      # 6 (Warden base duplicate copy)
	]
	var initial_scraps := 5
	var visit := RunRestStitchCards.new(deck, {}, initial_scraps, 1)
	_check(visit.is_valid() and not visit.is_consumed(), "pool base Rest visit initialized valid")
	if not visit.is_valid():
		return
	var snapshot := visit.get_snapshot()

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 20261023
	var local_state := local_rng.state
	seed(20261023)
	var global_next := randi()
	seed(20261023)

	# Stitch duplicate copy at index 6 (Warden) with index 3 (Seamstress).
	# Earlier index is 3. Index 6 is removed; index 0 copy of warden_hold_the_line must remain intact!
	var result := visit.choose_stitch(6, 3, snapshot)
	_check(randi() == global_next and local_rng.state == local_state, "no global or local RNG draw during pool base stitch")
	_check(_is_success(result) and visit.is_consumed(), "pool base stitch succeeds and consumes visit")
	if not _is_success(result):
		return

	_check(result["remaining_scraps"] == 2, "exactly 3 scraps spent once (5 -> 2)")
	_check(result["next_stitch_id"] == 2 and result["stitched_id"] == "stitched_000001",
		"allocator monotonically advanced once")
	_check(result["consumed_indices"] == [6, 3] and result["consumed_ids"] == ["warden_hold_the_line", "seamstress_running_stitch"],
		"consumed indices and IDs recorded in receipt")

	# Expected deck after stitch:
	# Earlier index 3 replaced by stitched_000001; later index 6 removed.
	var expected_deck: Array[String] = [
		"warden_hold_the_line",
		"seamstress_prick",
		"tinker_pop_shot",
		"stitched_000001",
		"warden_heavy_thimble",
		"tinker_rivet_shot",
	]
	_check(result["deck"] == expected_deck, "exact before/after deck order matches survivor indices")
	_check(result["deck"].count("warden_hold_the_line") == 1,
		"unselected duplicate copy at index 0 remains intact in deck")

	var desc: Dictionary = result["descriptor"]
	var warden_def: Dictionary = WardenPoolCards.new().get_definition("warden_hold_the_line")
	var seam_def: Dictionary = SeamstressPoolCards.new().get_definition("seamstress_running_stitch")
	_check(desc["display_name"] == "Hold the Line / Running Stitch", "composite display name")
	_check(desc["cost"] == 2, "cost is min(3, max(1, 1)+1) = 2")
	_check(desc["owners"] == ["warden", "seamstress"], "owners in first/second order")
	_check(desc["half_ids"] == ["warden_hold_the_line", "seamstress_running_stitch"], "half IDs in first/second order")
	_check(desc["first_half"] == warden_def and desc["second_half"] == seam_def, "exact authored definitions stored")
	_check(desc["can_upgrade"] == false and desc["can_stitch"] == false, "can_upgrade=false and can_stitch=false")
	_check(desc["illustration_path"] == warden_def["illustration_path"], "illustration path from first half")

	# Subsequent Rest reload validates descriptor unchanged
	var reloaded := RunRestStitchCards.new(result["deck"], result["descriptors"], result["remaining_scraps"], result["next_stitch_id"])
	_check(reloaded.is_valid() and reloaded.get_snapshot() == visit.get_snapshot(),
		"reloaded Rest visit validates pool base descriptor unchanged")


func _test_pool_plus_cards_stitch_and_reload() -> void:
	# AC2: canonical earned pool + cards (e.g. seamstress_running_stitch_plus and tinker_rivet_shot_plus)
	# from different owners. Stores exact authored upgraded definitions in first/second order.
	# Cost: min(3, max(half costs)+1). can_upgrade=false, can_stitch=false.
	# Subsequent Rest reload validates descriptor unchanged. Prove by catalog-backed tests.
	var seam_plus_id := "seamstress_running_stitch_plus"
	var tinker_plus_id := "tinker_rivet_shot_plus"
	var warden_plus_id := "warden_pin_and_pound_plus"
	var seam_tea_plus_id := "seamstress_thimble_tea_plus"

	var seam_pool := SeamstressPoolCards.new()
	var tinker_pool := TinkerPoolCards.new()
	var warden_pool := WardenPoolCards.new()

	var seam_def := seam_pool.get_definition(seam_plus_id)
	var tinker_def := tinker_pool.get_definition(tinker_plus_id)
	var warden_def := warden_pool.get_definition(warden_plus_id)
	var tea_def := seam_pool.get_definition(seam_tea_plus_id)

	_check(not seam_def.is_empty() and not tinker_def.is_empty() and not warden_def.is_empty(),
		"catalog definitions exist for pool plus cards")
	_check(seam_def["cost"] == 1 and tinker_def["cost"] == 1 and warden_def["cost"] == 2 and tea_def["cost"] == 0,
		"authored costs verified against catalogs")

	# Case A: Seamstress first (cost 1), Tinker second (cost 1)
	var deck_a: Array[String] = [seam_plus_id, tinker_plus_id, "warden_strike"]
	var visit_a := RunRestStitchCards.new(deck_a, {}, 3, 1)
	_check(visit_a.is_valid(), "visit A with canonical plus cards is valid")
	var res_a := visit_a.choose_stitch(0, 1, visit_a.get_snapshot())
	_check(_is_success(res_a), "stitch Seamstress+ and Tinker+ succeeds")
	var desc_a: Dictionary = res_a["descriptor"]
	_check(desc_a["display_name"] == "Running Stitch+ / Rivet Shot+", "Case A display name")
	_check(desc_a["cost"] == 2, "Case A cost min(3, max(1,1)+1) = 2")
	_check(desc_a["owners"] == ["seamstress", "tinker"], "Case A owners in first/second order")
	_check(desc_a["half_ids"] == [seam_plus_id, tinker_plus_id], "Case A half IDs")
	_check(desc_a["first_half"] == seam_def, "Case A first half matches catalog upgraded definition")
	_check(desc_a["second_half"] == tinker_def, "Case A second half matches catalog upgraded definition")
	_check(desc_a["first_half"]["effects"] == {"damage": 3, "bleed": 4}, "Case A first half authored effects")
	_check(desc_a["second_half"]["effects"] == {"damage": 6, "exposed": 1}, "Case A second half authored effects")
	_check(desc_a["can_upgrade"] == false and desc_a["can_stitch"] == false, "Case A flags")
	_check(desc_a["illustration_path"] == seam_def["illustration_path"], "Case A illustration from first")

	# Case B: Reverse order: Tinker first (cost 1), Seamstress second (cost 1)
	var deck_b: Array[String] = [tinker_plus_id, seam_plus_id, "warden_strike"]
	var visit_b := RunRestStitchCards.new(deck_b, {}, 3, 1)
	var res_b := visit_b.choose_stitch(0, 1, visit_b.get_snapshot())
	_check(_is_success(res_b), "stitch Tinker+ and Seamstress+ succeeds in reverse order")
	var desc_b: Dictionary = res_b["descriptor"]
	_check(desc_b["display_name"] == "Rivet Shot+ / Running Stitch+", "Case B reverse display name")
	_check(desc_b["cost"] == 2, "Case B cost")
	_check(desc_b["owners"] == ["tinker", "seamstress"], "Case B owners in reverse order")
	_check(desc_b["half_ids"] == [tinker_plus_id, seam_plus_id], "Case B half IDs")
	_check(desc_b["first_half"] == tinker_def and desc_b["second_half"] == seam_def, "Case B exact halves")
	_check(desc_b["illustration_path"] == tinker_def["illustration_path"], "Case B illustration from first")

	# Case C: Cost capping test: Tinker (cost 1) + Warden Pin and Pound+ (cost 2)
	# max(1, 2) + 1 = 3, capped at 3
	var deck_c: Array[String] = [tinker_plus_id, warden_plus_id, "seamstress_prick"]
	var visit_c := RunRestStitchCards.new(deck_c, {}, 3, 1)
	var res_c := visit_c.choose_stitch(0, 1, visit_c.get_snapshot())
	_check(_is_success(res_c), "stitch Tinker+ and Warden+ succeeds")
	var desc_c: Dictionary = res_c["descriptor"]
	_check(desc_c["display_name"] == "Rivet Shot+ / Pin and Pound+", "Case C display name")
	_check(desc_c["cost"] == 3, "Case C cost min(3, max(1, 2)+1) = 3")
	_check(desc_c["second_half"]["effects"] == {"damage": 12, "hits": 2}, "Case C Warden+ authored hits effect")

	# Case D: Zero-cost test: Seamstress Thimble Tea+ (cost 0) + Tinker Rivet Shot+ (cost 1)
	# max(0, 1) + 1 = 2
	var deck_d: Array[String] = [seam_tea_plus_id, tinker_plus_id, "warden_strike"]
	var visit_d := RunRestStitchCards.new(deck_d, {}, 3, 1)
	var res_d := visit_d.choose_stitch(0, 1, visit_d.get_snapshot())
	_check(_is_success(res_d), "stitch 0-cost and 1-cost plus cards succeeds")
	_check(res_d["descriptor"]["cost"] == 2, "Case D cost min(3, max(0, 1)+1) = 2")

	# Reload test: subsequent Rest visits validate descriptor unchanged
	var reload_1 := RunRestStitchCards.new(res_a["deck"], res_a["descriptors"], 4, res_a["next_stitch_id"])
	_check(reload_1.is_valid(), "subsequent Rest reload 1 is valid")
	_check(reload_1.get_snapshot()["descriptors"] == res_a["descriptors"], "descriptor survives reload unchanged")

	# Perform a second stitch at the reloaded visit with remaining cards
	var deck_multi: Array[String] = [
		seam_plus_id, tinker_plus_id, warden_plus_id, "seamstress_mend", "tinker_pop_shot"
	]
	var visit_multi_1 := RunRestStitchCards.new(deck_multi, {}, 6, 1)
	var step1 := visit_multi_1.choose_stitch(0, 1, visit_multi_1.get_snapshot())
	_check(_is_success(step1), "multi-visit step 1 succeeds")
	var visit_multi_2 := RunRestStitchCards.new(step1["deck"], step1["descriptors"], step1["remaining_scraps"], step1["next_stitch_id"])
	_check(visit_multi_2.is_valid(), "multi-visit reload 2 is valid")
	# Now stitch warden_plus with seamstress_mend
	var w_idx := _index(step1["deck"], warden_plus_id)
	var m_idx := _index(step1["deck"], "seamstress_mend")
	var step2 := visit_multi_2.choose_stitch(w_idx, m_idx, visit_multi_2.get_snapshot())
	_check(_is_success(step2), "multi-visit step 2 succeeds")
	_check(step2["descriptors"].size() == 2, "two stitched descriptors coexist in registry")
	_check(step2["next_stitch_id"] == 3, "allocator cursor reached 3")

	var visit_multi_3 := RunRestStitchCards.new(step2["deck"], step2["descriptors"], 3, step2["next_stitch_id"])
	_check(visit_multi_3.is_valid(), "multi-visit reload 3 preserves both descriptors")
	_check(visit_multi_3.get_snapshot()["descriptors"].has("stitched_000001")
		and visit_multi_3.get_snapshot()["descriptors"].has("stitched_000002"),
		"both sequential stitched IDs preserved on reload")


func _test_pool_negative_matrix() -> void:
	# AC3: starter-only stitches remain unchanged, while same-owner, re-stitch,
	# counterfeit pool +, insufficient scraps, invalid indices and stale snapshots
	# still reject without deck, scraps, receipt, cursor or RNG mutation.
	var deck: Array[String] = [
		"warden_hold_the_line",          # 0 (Warden base)
		"warden_heavy_thimble",          # 1 (Warden base)
		"warden_iron_hem_plus",          # 2 (Warden plus)
		"seamstress_running_stitch",     # 3 (Seamstress base)
		"seamstress_running_stitch_plus",# 4 (Seamstress plus)
		"seamstress_thimble_tea_plus",   # 5 (Seamstress plus)
		"tinker_rivet_shot",             # 6 (Tinker base)
		"tinker_pop_shot",               # 7 (Tinker starter)
		"warden_strike",                 # 8 (Warden starter)
	]
	var visit := RunRestStitchCards.new(deck, {}, 3, 1)
	_check(visit.is_valid(), "negative matrix visit valid")
	var snap := visit.get_snapshot()

	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 334455
	var local_state := local_rng.state
	seed(334455)
	var global_next := randi()
	seed(334455)

	# 1. Same-owner rejections
	_reject(visit, 0, 1, snap, "same hero Warden base + Warden base")
	_reject(visit, 0, 2, snap, "same hero Warden base + Warden plus")
	_reject(visit, 0, 8, snap, "same hero Warden base + Warden starter")
	_reject(visit, 3, 4, snap, "same hero Seamstress base + Seamstress plus")
	_reject(visit, 4, 5, snap, "same hero Seamstress plus + Seamstress plus")
	_reject(visit, 6, 7, snap, "same hero Tinker base + Tinker starter")

	# 2. Invalid indices
	_reject(visit, -1, 3, snap, "negative first index")
	_reject(visit, 0, deck.size(), snap, "out of bounds second index")
	_reject(visit, 0, 0, snap, "identical index pair")
	_reject(visit, null, 3, snap, "null index")
	_reject(visit, 1.5, 3, snap, "float index")
	_reject(visit, "0", 3, snap, "string index")

	# 3. Stale snapshots
	var wrong_deck := snap.duplicate(true)
	wrong_deck["deck"][0] = "warden_bastion_quilt"
	_reject(visit, 0, 3, wrong_deck, "stale modified deck")
	var wrong_currency := snap.duplicate(true)
	wrong_currency["remaining_scraps"] = 99
	_reject(visit, 0, 3, wrong_currency, "stale currency")
	var wrong_cursor := snap.duplicate(true)
	wrong_cursor["next_stitch_id"] = 5
	_reject(visit, 0, 3, wrong_cursor, "stale cursor")
	var wrong_receipt := snap.duplicate(true)
	wrong_receipt["receipt"] = "tampered"
	_reject(visit, 0, 3, wrong_receipt, "stale receipt")

	# 4. Insufficient scraps
	var poor_0 := RunRestStitchCards.new(deck, {}, 0, 1)
	_reject(poor_0, 0, 3, poor_0.get_snapshot(), "0 scraps rejected")
	var poor_1 := RunRestStitchCards.new(deck, {}, 1, 1)
	_reject(poor_1, 0, 3, poor_1.get_snapshot(), "1 scrap rejected")
	var poor_2 := RunRestStitchCards.new(deck, {}, 2, 1)
	_reject(poor_2, 0, 3, poor_2.get_snapshot(), "2 scraps rejected")

	# Verify RNG was never touched by any of the rejections above
	_check(randi() == global_next and local_rng.state == local_state,
		"all negative rejections left global and local RNG untouched")

	# 5. Counterfeit pool + cards
	for counterfeit in [
		"warden_iron_hem_plus_plus",
		"seamstress_unknown_plus",
		"tinker_rivet_shot_fake_plus",
		"warden_fake_plus",
		"tinker_pop_shot_plus_fake"
	]:
		var bad_deck := deck.duplicate()
		bad_deck.append(counterfeit)
		var bad_visit := RunRestStitchCards.new(bad_deck, {}, 3, 1)
		_check(not bad_visit.is_valid(), "counterfeit pool plus rejected at creation: " + counterfeit)
		_reject(bad_visit, 0, bad_deck.size() - 1, bad_visit.get_snapshot(),
			"counterfeit plus reject: " + counterfeit)

	# 6. Re-stitch rejection
	# First perform a valid stitch
	var ok := visit.choose_stitch(0, 3, snap)
	_check(_is_success(ok), "valid stitch succeeds")
	var stitched_idx := _index(ok["deck"], ok["stitched_id"])
	_check(stitched_idx >= 0, "stitched card present in deck")
	var next_visit := RunRestStitchCards.new(ok["deck"], ok["descriptors"], 3, ok["next_stitch_id"])
	_check(next_visit.is_valid(), "next visit valid")
	var other_idx := _index(ok["deck"], "tinker_rivet_shot")
	_reject(next_visit, stitched_idx, other_idx, next_visit.get_snapshot(),
		"re-stitch of composite with pool card rejected")
	_reject(next_visit, other_idx, stitched_idx, next_visit.get_snapshot(),
		"re-stitch of pool card with composite rejected")

	# 7. Forged descriptors on reload
	var forged_desc: Dictionary = ok["descriptors"].duplicate(true)
	forged_desc[ok["stitched_id"]]["first_half"]["effects"]["block"] = 9999
	_check(not RunRestStitchCards.new(ok["deck"], forged_desc, 3, ok["next_stitch_id"]).is_valid(),
		"forged effect in descriptor fails reload")

	var forged_cost: Dictionary = ok["descriptors"].duplicate(true)
	forged_cost[ok["stitched_id"]]["cost"] = 0
	_check(not RunRestStitchCards.new(ok["deck"], forged_cost, 3, ok["next_stitch_id"]).is_valid(),
		"forged cost in descriptor fails reload")

	var forged_owners: Dictionary = ok["descriptors"].duplicate(true)
	forged_owners[ok["stitched_id"]]["owners"] = ["tinker", "tinker"]
	_check(not RunRestStitchCards.new(ok["deck"], forged_owners, 3, ok["next_stitch_id"]).is_valid(),
		"forged same owners in descriptor fails reload")

	var forged_half_id: Dictionary = ok["descriptors"].duplicate(true)
	forged_half_id[ok["stitched_id"]]["half_ids"] = ["warden_iron_hem_plus_plus", "seamstress_running_stitch"]
	_check(not RunRestStitchCards.new(ok["deck"], forged_half_id, 3, ok["next_stitch_id"]).is_valid(),
		"forged counterfeit half_id in descriptor fails reload")
