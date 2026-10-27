extends SceneTree
## Deterministic headless regression for RunV3PartyAdmission. Oracles are read
## independently from the shipped JSON and catalogs; no catalog total is pinned.

const REJECTED := {"ok": false, "hero_ids": [], "party": [], "deck": []}
const LEGACY_HP := {"warden": 40, "seamstress": 30, "tinker": 26}
const V3_IDS := ["lantern_monk", "rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]

var failures: Array[String] = []
var checks := 0
var roster: Array = []
var legacy: Array = []


## Reproduces a shipped catalog, optionally with a tampered deck or definition.
class FakeCatalog:
	extends RefCounted
	var deck: Variant = []
	var definitions := {}

	func get_starting_deck() -> Variant:
		return deck.duplicate() if deck is Array else deck

	func get_definition(card_id: String) -> Dictionary:
		return definitions.get(card_id, {}).duplicate(true)


func _initialize() -> void:
	roster = _read("res://data/heroes/v3_party_roster.json")
	legacy = _read("res://data/heroes/starter_party.json")
	_check(roster.size() >= V3_IDS.size() and legacy.size() == 3, "shipped hero records load")
	_test_mixed_lineups()
	_test_tie_order()
	_test_original_trio()
	_test_detached_and_repeatable()
	_test_rejected_requests()
	_test_rejected_records()
	_test_rejected_catalogs()
	if failures.is_empty():
		print("run_v3_party_admission_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_v3_party_admission_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(yes: bool, description: String) -> void:
	checks += 1
	if not yes:
		failures.append(description)


func _read(path: String) -> Array:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Array:
		return []
	return parser.data


func _authored(id: String) -> Dictionary:
	for record in roster + legacy:
		if record.get("id") == id:
			return record
	return {}


## Independent position oracle: V3 default_position, legacy array index + 1.
func _position(id: String) -> int:
	for index in range(legacy.size()):
		if legacy[index].id == id:
			return index + 1
	return int(_authored(id).default_position)


## Insertion order by position; equal positions keep pick order.
func _expected_order(picks: Array) -> Array[String]:
	var order: Array[String] = []
	for id in picks:
		var at := order.size()
		while at > 0 and _position(order[at - 1]) > _position(id):
			at -= 1
		order.insert(at, id)
	return order


func _shipped(id: String) -> Object:
	if id in LEGACY_HP:
		return StarterCards.new()
	return load(_authored(id).starter_cards).new()


## The owner's base starters from its own catalog, independent of the admission code.
func _owner_starters(id: String) -> Array[String]:
	var catalog := _shipped(id)
	var cards: Array[String] = []
	for card in catalog.get_starting_deck():
		if catalog.get_definition(card).owner == id:
			cards.append(card)
	return cards


func _multiset(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		counts[card] = counts.get(card, 0) + 1
	return counts


func _fake(id: String) -> FakeCatalog:
	var shipped := _shipped(id)
	var fake := FakeCatalog.new()
	fake.deck = shipped.get_starting_deck()
	for card in shipped.get_all_card_ids():
		fake.definitions[card] = shipped.get_definition(card)
	return fake


func _rng_witness() -> int:
	seed(2603)
	return randi()


## Checks one accepted receipt against the independent oracles.
func _check_receipt(picks: Array, label: String) -> Dictionary:
	var request := picks.duplicate()
	seed(2603)
	var receipt := RunV3PartyAdmission.admit(request)
	var after_rng := randi()
	_check(after_rng == _rng_witness(), label + " consumes no global RNG")
	_check(request == picks, label + " leaves the request unchanged")
	_check(receipt.get("ok") == true, label + " is accepted")
	if receipt.get("ok") != true:
		return receipt
	var order := _expected_order(picks)
	_check(receipt.hero_ids == order, label + " orders heroes by default position, ties by pick order")
	var party := CombatParty.new(receipt.party)
	_check(party.is_valid(), label + " party is CombatParty-valid")
	if not party.is_valid():
		return receipt
	var heroes := party.get_heroes()
	var deck: Array = receipt.deck
	var cursor := 0
	for index in range(order.size()):
		var id: String = order[index]
		var authored := _authored(id)
		var record: Dictionary = receipt.party[index]
		var expected_hp: int = LEGACY_HP[id] if id in LEGACY_HP else int(authored.max_hp)
		_check(record.get("id") == id and record.get("max_hp") is int and record.get("max_hp") == expected_hp,
			label + " " + id + " keeps canonical int max HP")
		_check(heroes[index].get("id") == id and heroes[index].get("position") == index + 1
			and heroes[index].get("hp") == expected_hp, label + " " + id + " enters CombatParty at full HP")
		if id in LEGACY_HP:
			_check(not record.has("passive") and record.get("name") == authored.name
				and record.get("art_path") == authored.art_path, label + " " + id + " legacy record is as given")
		else:
			_check(record.get("passive") == authored.passive and record.get("default_position") == _position(id)
				and record.get("starter_cards") == authored.starter_cards,
				label + " " + id + " retains only its own authored passive")
		# Each owner's four starters are contiguous, in its catalog's own order.
		var own: Array = deck.slice(cursor, cursor + 4)
		cursor += 4
		var catalog := _shipped(id)
		_check(own == _owner_starters(id) and own.size() == 4, label + " " + id + " gets exactly its four base starters")
		for card in own:
			var definition: Dictionary = catalog.get_definition(card)
			_check(definition.get("owner") == id and not definition.has("upgrade_of")
				and not card.ends_with("_plus") and int(definition.get("starting_copies", 0)) > 0,
				label + " " + card + " is an authentic base starter of " + id)
	_check(deck.size() == cursor, label + " deck holds no other cards")
	var passives := {}
	for record in receipt.party:
		if record.has("passive"):
			passives[record.passive.id] = record.id
	for id in passives.values():
		_check(id in order, label + " passive identity belongs to a chosen hero")
	return receipt


func _test_mixed_lineups() -> void:
	var first := _check_receipt(["yarn_ranger", "lantern_monk", "button_golem"], "mixed A")
	var second := _check_receipt(["scarecrow", "tinker", "rag_duelist"], "mixed B")
	_check(first.get("hero_ids") != second.get("hero_ids"), "two lineups produce distinct rosters")
	_check(first.get("deck", []).size() == 12 and second.get("deck", []).size() == 12,
		"three heroes give twelve starters")
	# Every V3 hero is admissible somewhere; mixed lineups with legacy heroes too.
	_check_receipt(["warden", "seamstress", "lantern_monk"], "mixed C")
	_check_receipt(["button_golem", "rag_duelist", "yarn_ranger"], "mixed D")


func _test_tie_order() -> void:
	# Seamstress, Lantern Monk and Scarecrow share default position 2.
	for picks in [["scarecrow", "lantern_monk", "seamstress"], ["seamstress", "scarecrow", "lantern_monk"],
			["lantern_monk", "warden", "scarecrow"]]:
		var receipt := _check_receipt(picks, "tie " + str(picks))
		_check(receipt.get("hero_ids", []) == _expected_order(picks), "tie order is stable pick order")
	var a := RunV3PartyAdmission.admit(["rag_duelist", "button_golem", "tinker"])
	var b := RunV3PartyAdmission.admit(["button_golem", "rag_duelist", "tinker"])
	_check(a.get("hero_ids") == ["rag_duelist", "button_golem", "tinker"]
		and b.get("hero_ids") == ["button_golem", "rag_duelist", "tinker"], "position-1 ties keep pick order")


func _test_original_trio() -> void:
	var combined := StarterCards.new().get_starting_deck()
	for picks in [["warden", "seamstress", "tinker"], ["tinker", "warden", "seamstress"]]:
		var receipt := _check_receipt(picks, "original " + str(picks))
		_check(receipt.get("hero_ids", []) == ["warden", "seamstress", "tinker"], "original trio keeps 1-2-3 order")
		var hp := []
		for record in receipt.get("party", []):
			hp.append(record.max_hp)
		_check(hp == [40, 30, 26], "original trio keeps 40/30/26 HP")
		_check(_multiset(receipt.get("deck", [])) == _multiset(combined),
			"original trio deck is the original starter multiset")
	_check(StarterCards.new().get_starting_deck() == combined, "default combined starter deck is unaltered")
	var warden := _multiset(_owner_starters("warden"))
	_check(warden.get("warden_strike") == 2 and warden.size() == 3, "Warden keeps two Strikes among four starters")


func _test_detached_and_repeatable() -> void:
	var picks := ["scarecrow", "button_golem", "lantern_monk"]
	var first := RunV3PartyAdmission.admit(picks)
	var snapshot := first.duplicate(true)
	first.party[0].max_hp = 1
	first.party[1].passive.effects["weak_all_enemies"] = 9
	first.deck.append("warden_strike")
	first.hero_ids.clear()
	var second := RunV3PartyAdmission.admit(picks)
	_check(second == snapshot, "receipt mutation cannot reach later admissions")
	var request := picks.duplicate()
	var third := RunV3PartyAdmission.admit(request)
	request[0] = "warden"
	request.append("tinker")
	_check(third == snapshot, "request mutation after admission cannot reach the receipt")
	_check(_read("res://data/heroes/v3_party_roster.json") == roster, "shipped roster records are untouched")
	var catalog := _shipped("scarecrow")
	var card: String = _owner_starters("scarecrow")[0]
	var definition: Dictionary = catalog.get_definition(card)
	definition.cost = 99
	_check(RunV3PartyAdmission.admit(picks) == snapshot, "catalog lookup copies are not shared")
	var party := CombatParty.new(second.party)
	party.apply_damage(1, 5)
	_check(RunV3PartyAdmission.admit(picks) == snapshot, "combat mutation is detached from the receipt")
	seed(11)
	var repeat := RunV3PartyAdmission.admit(picks)
	var after := randi()
	seed(11)
	_check(repeat == snapshot and after == randi(), "repeat admission is identical and consumes no RNG")


func _check_rejects(request: Variant, fixture: Variant, label: String) -> void:
	var request_copy: Variant = request.duplicate(true) if request is Array or request is Dictionary else request
	var fixture_copy: Variant = fixture.duplicate(true) if fixture is Dictionary else fixture
	seed(2603)
	var receipt := RunV3PartyAdmission.admit(request, fixture)
	_check(randi() == _rng_witness(), label + " consumes no RNG")
	_check(receipt == REJECTED, label + " rejects with an empty receipt")
	_check(str(request) == str(request_copy), label + " leaves the request unchanged")
	if fixture is Dictionary:
		_check(fixture.keys() == fixture_copy.keys(), label + " leaves the fixture unchanged")
		for key in fixture:
			if fixture[key] is Array:
				_check(fixture[key] == fixture_copy[key], label + " leaves fixture " + key + " unchanged")


func _test_rejected_requests() -> void:
	var cases := [
		[null, "null request"], ["warden", "string request"], [{}, "dictionary request"],
		[[], "empty request"], [["warden", "seamstress"], "missing third hero"],
		[["warden", "seamstress", "tinker", "scarecrow"], "four heroes"],
		[["warden", "warden", "tinker"], "duplicate hero"],
		[["warden", "seamstress", "ragling"], "unknown hero"],
		[["warden", "seamstress", ""], "empty id"],
		[["warden", "seamstress", null], "null id"],
		[["warden", "seamstress", 3], "int id"],
		[["warden", "seamstress", &"tinker"], "StringName id"],
		[["Warden", "seamstress", "tinker"], "wrong-case id"],
		[["warden", "seamstress", ["tinker"]], "nested id"],
		[["warden", "seamstress", "tinker_plus"], "card id as hero"],
	]
	for entry in cases:
		_check_rejects(entry[0], null, entry[1])
	var picks := ["warden", "scarecrow", "yarn_ranger"]
	_check_rejects(picks, "roster", "non-dictionary fixture")
	_check_rejects(picks, {"roster": roster.duplicate(true), "extra": 1}, "unknown fixture key")


## Applies one change to a deep copy of the shipped records.
func _mutated(source: Array, index: int, field: String, value: Variant) -> Array:
	var copy := source.duplicate(true)
	if value == null:
		copy[index].erase(field)
	else:
		copy[index][field] = value
	return copy


func _test_rejected_records() -> void:
	var picks := ["warden", "scarecrow", "yarn_ranger"]
	# Positive controls: faithful copies and reordered V3 records are accepted unchanged.
	var faithful := RunV3PartyAdmission.admit(picks, {"roster": roster.duplicate(true), "legacy": legacy.duplicate(true)})
	_check(faithful == RunV3PartyAdmission.admit(picks), "faithful fixture records are accepted unchanged")
	var reversed := roster.duplicate(true)
	reversed.reverse()
	_check(RunV3PartyAdmission.admit(picks, {"roster": reversed}) == faithful, "V3 record order is irrelevant")
	var scarecrow := -1
	var monk := -1
	for index in range(roster.size()):
		if roster[index].id == "scarecrow":
			scarecrow = index
		if roster[index].id == "lantern_monk":
			monk = index
	_check(scarecrow >= 0 and monk >= 0, "fixture records located")
	var passive: Dictionary = roster[scarecrow].passive
	var cases := [
		[_mutated(roster, scarecrow, "max_hp", 34.5), "fractional HP"],
		[_mutated(roster, scarecrow, "max_hp", -34), "negative HP"],
		[_mutated(roster, scarecrow, "max_hp", 0), "zero HP"],
		[_mutated(roster, scarecrow, "max_hp", "34"), "string HP"],
		[_mutated(roster, scarecrow, "max_hp", INF), "infinite HP"],
		[_mutated(roster, scarecrow, "max_hp", 99), "non-canonical HP"],
		[_mutated(roster, scarecrow, "max_hp", null), "missing HP"],
		[_mutated(roster, scarecrow, "default_position", 4), "position 4"],
		[_mutated(roster, scarecrow, "default_position", 0), "position 0"],
		[_mutated(roster, scarecrow, "default_position", 2.5), "fractional position"],
		[_mutated(roster, scarecrow, "default_position", 1), "non-canonical position"],
		[_mutated(roster, scarecrow, "passive", null), "missing passive"],
		[_mutated(roster, scarecrow, "passive", "frightful"), "string passive"],
		[_mutated(roster, scarecrow, "passive", roster[monk].passive.duplicate(true)), "borrowed passive"],
		[_mutated(roster, scarecrow, "passive", passive.merged({"extra": 1})), "passive extra field"],
		[_mutated(roster, scarecrow, "passive", passive.merged({"id": ""}, true)), "passive empty id"],
		[_mutated(roster, scarecrow, "passive", passive.merged({"effects": {}}, true)), "passive no effects"],
		[_mutated(roster, scarecrow, "starter_cards", "res://data/cards/lantern_monk_starter_cards.gd"), "wrong catalog"],
		[_mutated(roster, scarecrow, "id", "ragling"), "unknown record id"],
		[_mutated(roster, scarecrow, "id", "lantern_monk"), "duplicate record id"],
		[_mutated(roster, scarecrow, "name", ""), "empty name"],
		[_mutated(roster, scarecrow, "extra", true), "extra record field"],
		[roster.slice(0, roster.size() - 1), "missing record"],
		[roster + [roster[0].duplicate(true)], "duplicated record"],
		[roster + ["scarecrow"], "non-dictionary record"],
	]
	for entry in cases:
		_check_rejects(picks, {"roster": entry[0]}, "roster " + entry[1])
	_check_rejects(picks, {"roster": {"records": roster}}, "dictionary roster")
	var swapped := legacy.duplicate(true)
	var first: Dictionary = swapped[0]
	swapped[0] = swapped[1]
	swapped[1] = first
	var legacy_cases := [
		[_mutated(legacy, 0, "max_hp", 41), "non-canonical Warden HP"],
		[_mutated(legacy, 2, "max_hp", 26.5), "fractional Tinker HP"],
		[_mutated(legacy, 1, "passive", {"id": "x", "text": "x", "trigger": "x", "effects": {"x": 1}}), "fabricated passive"],
		[_mutated(legacy, 1, "art_path", null), "missing art path"],
		[swapped, "reordered legacy positions"],
		[legacy.slice(0, 2), "missing legacy hero"],
	]
	for entry in legacy_cases:
		_check_rejects(picks, {"legacy": entry[0]}, "legacy " + entry[1])


func _test_rejected_catalogs() -> void:
	var picks := ["seamstress", "yarn_ranger", "button_golem"]
	var shipped := RunV3PartyAdmission.admit(picks)
	_check(RunV3PartyAdmission.admit(picks, {"catalogs": {"yarn_ranger": _fake("yarn_ranger"),
		"seamstress": _fake("seamstress")}}) == shipped, "faithful catalogs are accepted unchanged")
	var ranger: Array[String] = _owner_starters("yarn_ranger")
	var other: String = _owner_starters("button_golem")[0]
	var upgraded := _fake("yarn_ranger")
	upgraded.deck[0] = _shipped("yarn_ranger").get_upgrade_id(ranger[0])
	var foreign := _fake("yarn_ranger")
	foreign.deck[0] = other
	var short := _fake("yarn_ranger")
	short.deck.pop_back()
	var long := _fake("yarn_ranger")
	long.deck.append(ranger[0])
	var tampered := _fake("yarn_ranger")
	tampered.definitions[ranger[1]].cost = 0
	var spoofed := _fake("yarn_ranger")
	spoofed.definitions[ranger[2]].owner = "button_golem"
	var no_copies := _fake("yarn_ranger")
	no_copies.definitions[ranger[3]].starting_copies = 0
	var unknown := _fake("yarn_ranger")
	unknown.deck[0] = "yarn_ranger_missing"
	var broken := _fake("yarn_ranger")
	broken.deck = "deck"
	var reordered := _fake("yarn_ranger")
	reordered.deck.reverse()
	var cases := [
		[upgraded, "upgraded starter"], [foreign, "other-owner card"], [short, "three starters"],
		[long, "five starters"], [tampered, "tampered definition"], [spoofed, "spoofed owner"],
		[no_copies, "zero-copy starter"], [unknown, "unknown card"], [broken, "non-array deck"],
		[RefCounted.new(), "catalog without lookups"], [7, "non-object catalog"],
	]
	if ranger[0] != ranger[ranger.size() - 1]:
		cases.append([reordered, "reordered starters"])
	for entry in cases:
		_check_rejects(picks, {"catalogs": {"yarn_ranger": entry[0]}}, "catalog " + entry[1])
	var plus := _fake("seamstress")
	for index in range(plus.deck.size()):
		if plus.deck[index] == "seamstress_prick":
			plus.deck[index] = "seamstress_prick_plus"
			break
	var short_legacy := _fake("seamstress")
	short_legacy.deck.erase("seamstress_mend")
	_check_rejects(picks, {"catalogs": {"seamstress": plus}}, "legacy upgraded starter")
	_check_rejects(picks, {"catalogs": {"seamstress": short_legacy}}, "legacy missing starter")
	_check_rejects(picks, {"catalogs": []}, "array catalogs")
	_check(RunV3PartyAdmission.admit(picks) == shipped, "rejections leave later admissions unchanged")
