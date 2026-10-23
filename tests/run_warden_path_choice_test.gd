extends SceneTree
## Deterministic headless test for RunWardenPathChoice (D2-5 / M06 data slice).
## Parses the authored Warden Path source, checks every per-ID field of both
## Paths, exercises both legal choices as detached proposed decks, and verifies
## fail-closed rejections (invalid path, replay, bad deck, tampering) with no RNG.
## Data/service only: no live Heroes selection, combat effect or save claim.

const SOURCE_PATH := "res://data/heroes/warden_paths.json"
const STARTER_DECK_PATH := "res://data/cards/starter_deck.json"

const EXPECTED_STARTER := {
	"warden_strike": 2,
	"warden_brace": 1,
	"warden_shield_bash": 1,
	"seamstress_prick": 2,
	"seamstress_mend": 1,
	"seamstress_stitch_up": 1,
	"tinker_pop_shot": 2,
	"tinker_scrap_bomb": 1,
	"tinker_tune_up": 1,
}

var failures: Array[String] = []
var checks := 0
var authored: Variant = null
var source_snapshot: Variant = null
var deck: Variant = null
var deck_snapshot: Variant = null
var catalog_deck_snapshot: Array[String] = []
var catalog_ids_snapshot: Array[String] = []


func _initialize() -> void:
	_test_source_file()
	_test_authored_records()
	_test_starter_catalog_unchanged()
	_test_bulwark_choice()
	_test_vanguard_choice()
	_test_invalid_and_replay()
	_test_bad_source_inputs()
	_test_tampering_isolation()
	_test_no_rng()
	_check(authored == source_snapshot, "authored source file unchanged across all flows")
	_check(deck == deck_snapshot, "starter deck file unchanged across all flows")
	var catalog := StarterCards.new()
	_check(catalog.get_starting_deck() == catalog_deck_snapshot,
		"StarterCards starting deck unchanged across all flows")
	_check(catalog.get_all_card_ids() == catalog_ids_snapshot,
		"StarterCards catalog IDs unchanged across all flows")
	for failure in failures:
		printerr(failure)
	print("run_warden_path_choice_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


## JSON numbers parse as floats; normalize so nested container comparisons are exact.
func _norm(value: Variant) -> Variant:
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		if is_finite(number) and floor(number) == number:
			return int(number)
		return value
	if value is Array:
		var out_list: Array = []
		for item in value:
			out_list.append(_norm(item))
		return out_list
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _norm(value[key])
		return out_dict
	return value


func _rng_start(value: int) -> int:
	seed(value)
	var expected := randi()
	seed(value)
	return expected


func _matches(list: Variant, key: String, value: String) -> Array:
	var out: Array = []
	if not list is Array:
		return out
	for entry in list:
		if entry is Dictionary and entry.get(key) == value:
			out.append(entry)
	return out


func _count(ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id in ids:
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts


func _test_source_file() -> void:
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	_check(file != null, "warden_paths.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), "warden_paths.json is non-empty")
	var parser := JSON.new()
	_check(parser.parse(text) == OK, "warden_paths.json parses through JSON")
	authored = parser.data if parser.data != null else null
	source_snapshot = authored.duplicate(true) if authored != null else null
	_check(authored is Dictionary, "warden_paths.json top level is an object")
	var deck_file := FileAccess.open(STARTER_DECK_PATH, FileAccess.READ)
	_check(deck_file != null, "starter_deck.json opens through FileAccess")
	if deck_file == null:
		return
	var deck_text := deck_file.get_as_text()
	deck_file.close()
	var deck_parser := JSON.new()
	_check(deck_parser.parse(deck_text) == OK, "starter_deck.json parses through JSON")
	deck = deck_parser.data if deck_parser.data != null else null
	deck_snapshot = deck.duplicate(true) if deck != null else null
	_check(deck is Array, "starter_deck.json top level is an array")
	if not authored is Dictionary or not deck is Array:
		return
	# The genuine authored twelve-copy starter deck, exactly as documented.
	var counts := _count(deck)
	_check(counts == EXPECTED_STARTER, "starter deck is exactly the documented twelve copies")
	_check((deck as Array).size() == 12, "starter deck holds twelve cards")
	var catalog := StarterCards.new()
	catalog_deck_snapshot = catalog.get_starting_deck()
	catalog_ids_snapshot = catalog.get_all_card_ids()
	_check(catalog_deck_snapshot == deck, "StarterCards starting deck matches starter_deck.json")
	_check(not catalog.has_card("warden_bulwark_brace"), "Bulwark Brace is not in the starter catalog")
	_check(not catalog.has_card("warden_lance_pin"), "Lance Pin is not in the starter catalog")
	# Service loads both authored files through its own static readers.
	_check(RunWardenPathChoice.load_authored_record() == authored, "service loads the authored Path record")
	_check(RunWardenPathChoice.load_authored_starter_deck() == deck, "service loads the authored starter deck")


func _test_authored_records() -> void:
	if not authored is Dictionary:
		return
	var record: Dictionary = authored
	_check(record.get("id") == "warden", "authored owner is warden")
	_check(record.get("display_name") == "Warden", "authored owner display name")
	_check(record.get("max_hp") == 40, "authored Warden max HP is 40")
	var base_passive: Variant = record.get("base_passive")
	_check(base_passive is Dictionary, "authored base passive is an object")
	if base_passive is Dictionary:
		_check((base_passive as Dictionary).get("kind") == "starting_block", "base passive kind is starting_block")
		_check((base_passive as Dictionary).get("starting_block") == 6, "base passive grants 6 Block")
	var palette: Variant = record.get("palette")
	_check(palette is Dictionary, "authored palette is an object")
	if palette is Dictionary:
		_check((palette as Dictionary).get("slate_blue") == "#4a5d73", "palette slate blue")
		_check((palette as Dictionary).get("bone") == "#d9cfb8", "palette bone")
		_check((palette as Dictionary).get("rust") == "#a4552f", "palette rust")
	var paths: Variant = record.get("paths")
	_check(paths is Array and (paths as Array).size() == 2, "exactly two authored Warden Paths")
	if not paths is Array:
		return
	var bulwark := _matches(paths, "id", "bulwark")
	var vanguard := _matches(paths, "id", "vanguard")
	_check(bulwark.size() == 1, "exactly one bulwark Path record")
	_check(vanguard.size() == 1, "exactly one vanguard Path record")
	if bulwark.size() == 1:
		_check_path_bulwark(bulwark[0])
	if vanguard.size() == 1:
		_check_path_vanguard(vanguard[0])


func _check_path_bulwark(record: Dictionary) -> void:
	_check(record.get("display_name") == "Bulwark", "bulwark display name")
	var passive: Variant = record.get("passive")
	_check(passive is Dictionary, "bulwark passive is an object")
	if passive is Dictionary:
		var p: Dictionary = passive
		_check(p.get("kind") == "replaces_starting_block", "bulwark passive replaces starting Block")
		_check(p.get("replaced_kind") == "starting_block", "bulwark replaces the starting_block passive")
		_check(p.get("replaced_starting_block") == 6, "bulwark replaces exactly the base 6 Block")
		_check(p.get("starting_block") == 10, "bulwark grants exactly 10 Block")
		_check(p.get("stacks") == false, "bulwark Block never stacks with the base 6")
		_check(int(p.get("starting_block", 0)) != 16, "bulwark is never 16 Block")
	var card: Variant = record.get("card")
	_check(card is Dictionary, "bulwark card is an object")
	if not card is Dictionary:
		return
	var c: Dictionary = card
	_check(c.get("id") == "warden_bulwark_brace", "Bulwark Brace namespaced card ID")
	_check(c.get("display_name") == "Bulwark Brace", "Bulwark Brace display name")
	_check(c.get("owner") == "warden", "Bulwark Brace owner")
	_check(c.get("cost") == 1, "Bulwark Brace costs 1")
	_check(_norm(c.get("from_positions")) == [1, 2, 3], "Bulwark Brace playable from 1, 2 or 3")
	_check(c.get("target_kind") == "self", "Bulwark Brace targets self")
	_check(_norm(c.get("to_positions")) == [], "Bulwark Brace has no enemy positions")
	_check(_norm(c.get("effects")) == {"block": 9}, "Bulwark Brace is exactly 9 Block")
	_check(c.get("illustration_path") == "res://assets/paper/cards/warden_bulwark_brace.png",
		"Bulwark Brace keeps a future art path")


func _check_path_vanguard(record: Dictionary) -> void:
	_check(record.get("display_name") == "Vanguard", "vanguard display name")
	var passive: Variant = record.get("passive")
	_check(passive is Dictionary, "vanguard passive is an object")
	if passive is Dictionary:
		var p: Dictionary = passive
		_check(p.get("kind") == "first_attack_per_turn_pins", "vanguard passive is first-attack-pins")
		_check(p.get("applies_to") == "warden", "vanguard passive applies to the Warden")
		_check(p.get("trigger") == "first_confirmed_attack_each_player_turn",
			"vanguard triggers on the first confirmed attack each player turn")
		_check(p.get("once_per_turn") == true, "vanguard pins once per turn, not every attack")
		_check(p.get("status") == "pinned", "vanguard applies Pinned")
	var card: Variant = record.get("card")
	_check(card is Dictionary, "vanguard card is an object")
	if not card is Dictionary:
		return
	var c: Dictionary = card
	_check(c.get("id") == "warden_lance_pin", "Lance Pin namespaced card ID")
	_check(c.get("display_name") == "Lance Pin", "Lance Pin display name")
	_check(c.get("owner") == "warden", "Lance Pin owner")
	_check(c.get("cost") == 1, "Lance Pin costs 1")
	_check(_norm(c.get("from_positions")) == [1], "Lance Pin is playable only from position 1")
	_check(c.get("target_kind") == "enemy_single", "Lance Pin targets one enemy")
	_check(_norm(c.get("to_positions")) == [1, 2], "Lance Pin targets enemies in position 1 or 2")
	var effects: Variant = c.get("effects")
	_check(effects is Dictionary and (effects as Dictionary).get("damage") == 6,
		"Lance Pin deals exactly 6 damage")
	_check(effects is Dictionary and (effects as Dictionary).get("pinned") == true,
		"Lance Pin applies Pinned")
	_check(c.get("illustration_path") == "res://assets/paper/cards/warden_lance_pin.png",
		"Lance Pin keeps a future art path")


func _test_starter_catalog_unchanged() -> void:
	var catalog := StarterCards.new()
	_check(catalog.get_starting_deck() == catalog_deck_snapshot, "StarterCards deck still fresh-copied")
	_check(catalog.get_definition("warden_brace").get("effects") == {"block": 7},
		"starter Brace is still 7 Block")
	_check(catalog.get_definition("warden_brace").get("starting_copies") == 1,
		"starter Brace still has one copy")
	_check(not catalog.has_card("warden_bulwark_brace"), "Bulwark Brace is not yet a starter card")
	_check(not catalog.has_card("warden_lance_pin"), "Lance Pin is not yet a starter card")


func _test_bulwark_choice() -> void:
	var service := RunWardenPathChoice.new(authored, deck)
	_check(service.is_valid() and not service.is_claimed(), "fresh Bulwark projector is valid and unclaimed")
	_check(service.get_authored_paths().size() == 2, "projector exposes both authored Paths")
	_check(service.get_receipt().is_empty(), "no receipt exists before a choice")
	var receipt := service.choose("bulwark")
	_check(receipt.get("ok") == true, "bulwark choice succeeds")
	_check(receipt.get("owner") == "warden", "bulwark receipt keeps the Warden owner")
	_check(receipt.get("path_id") == "bulwark", "bulwark receipt names the bulwark Path")
	_check(receipt.get("display_name") == "Bulwark", "bulwark receipt display name")
	var passive: Dictionary = receipt.get("passive", {})
	_check(passive.get("starting_block") == 10 and passive.get("replaced_starting_block") == 6,
		"bulwark receipt grants 10 Block instead of 6")
	_check(passive.get("stacks") == false, "bulwark receipt never stacks to 16")
	var card: Dictionary = receipt.get("card", {})
	_check(card.get("id") == "warden_bulwark_brace", "bulwark receipt carries Bulwark Brace")
	_check(card.get("cost") == 1 and card.get("from_positions") == [1, 2, 3]
		and card.get("target_kind") == "self" and card.get("effects") == {"block": 9},
		"bulwark receipt card is 1 energy / from 1-3 / self 9 Block")
	var proposed: Array = receipt.get("starter_deck", [])
	_check(proposed.size() == 13, "bulwark proposed deck holds thirteen cards")
	_check(_count(proposed) == EXPECTED_STARTER.merged({"warden_bulwark_brace": 1}, true),
		"bulwark proposed deck keeps all twelve starter copies plus exactly one Path card")
	_check(not proposed.has("warden_lance_pin"), "bulwark proposed deck excludes Lance Pin")
	_check(proposed.slice(0, 12) == deck, "bulwark proposed deck preserves the authored twelve-card order")
	_check(service.is_claimed() and not service.is_valid(), "bulwark claim latches on the projector")
	_check(service.get_base_deck() == deck, "bulwark claim leaves the stored base deck unchanged")
	_check(service.get_receipt() == receipt, "stored receipt matches the returned receipt")


func _test_vanguard_choice() -> void:
	var service := RunWardenPathChoice.new(authored, deck)
	_check(service.is_valid() and not service.is_claimed(), "fresh Vanguard projector is valid and unclaimed")
	var receipt := service.choose("vanguard")
	_check(receipt.get("ok") == true, "vanguard choice succeeds")
	_check(receipt.get("path_id") == "vanguard", "vanguard receipt names the vanguard Path")
	var passive: Dictionary = receipt.get("passive", {})
	_check(passive.get("kind") == "first_attack_per_turn_pins"
		and passive.get("trigger") == "first_confirmed_attack_each_player_turn"
		and passive.get("once_per_turn") == true and passive.get("status") == "pinned",
		"vanguard receipt pins only the first confirmed attack each turn")
	var card: Dictionary = receipt.get("card", {})
	_check(card.get("id") == "warden_lance_pin", "vanguard receipt carries Lance Pin")
	_check(card.get("cost") == 1 and card.get("from_positions") == [1]
		and card.get("to_positions") == [1, 2],
		"Lance Pin is 1 energy from position 1 to enemies 1-2")
	_check(card.get("effects") == {"damage": 6, "pinned": true},
		"Lance Pin deals 6 damage and applies Pinned")
	var proposed: Array = receipt.get("starter_deck", [])
	_check(proposed.size() == 13, "vanguard proposed deck holds thirteen cards")
	_check(_count(proposed) == EXPECTED_STARTER.merged({"warden_lance_pin": 1}, true),
		"vanguard proposed deck keeps all twelve starter copies plus exactly one Path card")
	_check(not proposed.has("warden_bulwark_brace"), "vanguard proposed deck excludes Bulwark Brace")
	_check(service.is_claimed() and service.get_base_deck() == deck,
		"vanguard claim latches and leaves the stored base deck unchanged")
	# Both receipts never apply both Paths.
	var bulwark_service := RunWardenPathChoice.new(authored, deck)
	var bulwark_receipt := bulwark_service.choose("bulwark")
	_check(bulwark_receipt.get("starter_deck") != receipt.get("starter_deck"),
		"bulwark and vanguard produce distinct proposed decks")
	var vanguard_path_card: String = (receipt.get("card", {}) as Dictionary).get("id", "")
	var bulwark_path_card: String = (bulwark_receipt.get("card", {}) as Dictionary).get("id", "")
	_check(vanguard_path_card == "warden_lance_pin" and bulwark_path_card == "warden_bulwark_brace"
		and vanguard_path_card != bulwark_path_card,
		"each Path receipt carries only its own mutually exclusive card")


func _test_invalid_and_replay() -> void:
	# Failure before a successful retry: unoffered and non-string Path IDs.
	var service := RunWardenPathChoice.new(authored, deck)
	var rng := _rng_start(81001)
	var rejected := service.choose("sentinel")
	_check(rejected.get("ok") == false, "unoffered Path is rejected")
	_check(rejected.get("path_id") == "" and rejected.get("owner") == "" and rejected.get("card") == {},
		"unoffered Path rejection carries empty identity and card")
	_check(rejected.get("starter_deck") == deck, "unoffered Path rejection returns the unchanged base deck")
	_check(service.is_valid() and not service.is_claimed(), "unoffered Path consumes no claim")
	_check(service.get_receipt().is_empty(), "unoffered Path writes no receipt")
	_check(service.choose("").get("ok") == false, "blank Path ID is rejected")
	_check(service.choose(null).get("ok") == false, "null Path ID is rejected")
	_check(service.choose(1).get("ok") == false, "non-string Path ID is rejected")
	_check(service.choose("Bulwark").get("ok") == false, "case-mismatched Path ID is rejected")
	_check(service.is_valid() and not service.is_claimed(), "invalid attempts consume no claim")
	_check(service.get_base_deck() == deck, "invalid attempts leave the stored deck unchanged")
	_check(randi() == rng, "invalid attempts spend no global RNG")
	# Same selector then claims exactly once.
	var success := service.choose("bulwark")
	_check(success.get("ok") == true and (success.get("starter_deck") as Array).size() == 13,
		"same selector recovers and claims once after rejected attempts")
	_check(service.is_claimed() and not service.is_valid(), "recovered claim latches exactly once")
	_check(service.get_receipt() == success, "recovered receipt is stored unchanged")
	# Duplicate success refusal cannot change receipt, deck or eligibility.
	var replay := service.choose("vanguard")
	_check(replay.get("ok") == false, "second claim on a different Path is refused")
	_check(replay.get("path_id") == "" and replay.get("card") == {}, "refused replay has empty identity and card")
	_check(replay.get("starter_deck") == deck, "refused replay returns the unchanged base deck")
	_check(service.get_receipt() == success, "refused replay cannot change the stored receipt")
	_check(service.get_base_deck() == deck, "refused replay cannot change the stored deck")
	_check(service.choose("bulwark").get("ok") == false, "repeated claim of the same Path is refused")
	_check(service.is_claimed(), "refused replay keeps the claim latched")
	var replay_rng := _rng_start(81002)
	var replay_again := service.choose("bulwark")
	_check(replay_again.get("ok") == false, "further replay is refused")
	_check(service.get_receipt() == success, "further replay cannot change the stored receipt")
	_check(randi() == replay_rng, "recovered claim and replays spend no global RNG")
	# A brand-new projector with the same source is unaffected by the earlier claim.
	var fresh := RunWardenPathChoice.new(authored, deck)
	_check(fresh.is_valid() and not fresh.is_claimed(), "a new projector is independently unclaimed")
	_check(fresh.choose("vanguard").get("ok") == true, "a new projector can choose the other Path")


func _test_bad_source_inputs() -> void:
	if not authored is Dictionary:
		return
	# Wrong hero owner.
	var wrong_owner: Dictionary = authored.duplicate(true)
	wrong_owner["id"] = "seamstress"
	_check_invalid_source(wrong_owner, deck, "wrong hero owner")
	# Wrong base max HP is not the failure we test; remove the Paths array.
	var no_paths: Dictionary = authored.duplicate(true)
	no_paths["paths"] = []
	_check_invalid_source(no_paths, deck, "empty Paths array")
	# Only one authored Path record.
	var one_path: Dictionary = authored.duplicate(true)
	one_path["paths"] = [(authored["paths"] as Array)[0].duplicate(true)]
	_check_invalid_source(one_path, deck, "single Path record")
	# Duplicate Path IDs.
	var dup_paths: Dictionary = authored.duplicate(true)
	var dup_list: Array = (authored["paths"] as Array).duplicate(true)
	dup_list[1]["id"] = "bulwark"
	dup_paths["paths"] = dup_list
	_check_invalid_source(dup_paths, deck, "duplicate Path IDs")
	# Unknown Path ID.
	var unknown_path: Dictionary = authored.duplicate(true)
	var unknown_list: Array = (authored["paths"] as Array).duplicate(true)
	unknown_list[0]["id"] = "sentinel"
	unknown_path["paths"] = unknown_list
	_check_invalid_source(unknown_path, deck, "unknown Path ID")
	# Card with the wrong owner.
	var wrong_card_owner: Dictionary = authored.duplicate(true)
	var owner_list: Array = (authored["paths"] as Array).duplicate(true)
	owner_list[0]["card"]["owner"] = "tinker"
	wrong_card_owner["paths"] = owner_list
	_check_invalid_source(wrong_card_owner, deck, "Path card with wrong owner")
	# Card ID colliding with a base starter copy.
	var colliding: Dictionary = authored.duplicate(true)
	var collision_list: Array = (authored["paths"] as Array).duplicate(true)
	collision_list[0]["card"]["id"] = "warden_strike"
	colliding["paths"] = collision_list
	_check_invalid_source(colliding, deck, "Path card colliding with a starter card")
	# Non-numeric passive amount.
	var bad_amount: Dictionary = authored.duplicate(true)
	var amount_list: Array = (authored["paths"] as Array).duplicate(true)
	amount_list[0]["passive"]["starting_block"] = "ten"
	bad_amount["paths"] = amount_list
	_check_invalid_source(bad_amount, deck, "non-numeric passive amount")
	# Positions outside the three-slot line.
	var bad_positions: Dictionary = authored.duplicate(true)
	var positions_list: Array = (authored["paths"] as Array).duplicate(true)
	positions_list[1]["card"]["to_positions"] = [1, 4]
	bad_positions["paths"] = positions_list
	_check_invalid_source(bad_positions, deck, "Path card target outside positions 1-3")
	# Source that is not an object at all.
	var not_object := RunWardenPathChoice.new("not a record", deck)
	_check(not not_object.is_valid() and not not_object.is_claimed(),
		"non-object authored source fails closed")
	_check(not_object.choose("bulwark").get("ok") == false,
		"failed projector refuses a choice")
	# Bad starter decks.
	var short_deck: Array = (deck as Array).duplicate()
	short_deck.pop_back()
	_check_invalid_source(authored, short_deck, "eleven-card starter deck")
	var unknown_card: Array = (deck as Array).duplicate()
	unknown_card[0] = "not_a_card"
	_check_invalid_source(authored, unknown_card, "starter deck with an unknown card")
	var wrong_multiplicity: Array = (deck as Array).duplicate()
	wrong_multiplicity[2] = "warden_strike"
	_check_invalid_source(authored, wrong_multiplicity, "starter deck with wrong multiplicities")
	var extra_copy: Array = (deck as Array).duplicate()
	extra_copy.append("warden_strike")
	_check_invalid_source(authored, extra_copy, "starter deck with thirteen base copies")
	var substituted: Array = (deck as Array).duplicate()
	substituted[2] = "seamstress_prick"
	_check_invalid_source(authored, substituted, "starter deck with a substituted copy count")
	var plus_card: Array = (deck as Array).duplicate()
	plus_card[0] = "warden_strike_plus"
	_check_invalid_source(authored, plus_card, "starter deck with a non-starting upgrade card")
	_check_invalid_source(authored, "not an array", "non-array starter deck")
	_check_invalid_source(authored, {"deck": (deck as Array).duplicate()}, "object instead of starter deck")
	_check_invalid_source([1, 2, 3], deck, "array instead of authored source")


func _check_invalid_source(source: Variant, source_deck: Variant, label: String) -> void:
	var service := RunWardenPathChoice.new(source, source_deck)
	_check(not service.is_valid() and not service.is_claimed(), label + " projector fails closed")
	_check(service.get_receipt().is_empty(), label + " projector holds no receipt")
	var result := service.choose("bulwark")
	_check(result.get("ok") == false, label + " projector refuses a choice")
	_check((result.get("starter_deck") as Array).is_empty(), label + " refusal returns an empty proposed deck")
	_check(result.get("path_id") == "" and result.get("card") == {},
		label + " refusal returns empty identity and card")
	_check(not service.is_claimed(), label + " refusal cannot claim")


func _test_tampering_isolation() -> void:
	# Caller mutation of the input source and deck cannot reach the projector.
	var caller_source: Dictionary = (authored as Dictionary).duplicate(true)
	var caller_deck: Array = (deck as Array).duplicate()
	var service := RunWardenPathChoice.new(caller_source, caller_deck)
	_check(service.is_valid(), "fresh projector valid before caller tampering")
	caller_source["id"] = "tampered_owner"
	(caller_source["paths"] as Array)[0]["card"]["effects"] = {"block": 999}
	caller_deck.clear()
	var receipt := service.choose("bulwark")
	_check(receipt.get("ok") == true, "caller tampering after construction does not break the claim")
	_check((receipt.get("card", {}) as Dictionary).get("effects") == {"block": 9},
		"caller source tampering cannot change the stored card")
	_check((receipt.get("starter_deck") as Array).size() == 13,
		"caller deck tampering cannot change the proposed deck")
	# Returned receipt and snapshots are detached from the projector.
	(receipt["card"] as Dictionary)["effects"] = {"block": 999}
	(receipt["starter_deck"] as Array).clear()
	receipt["ok"] = false
	var stored := service.get_receipt()
	_check(stored.get("ok") == true, "mutating a returned receipt cannot change the stored receipt")
	_check((stored.get("card", {}) as Dictionary).get("effects") == {"block": 9},
		"mutating a returned receipt cannot change the stored card")
	_check((stored.get("starter_deck") as Array).size() == 13,
		"mutating a returned receipt cannot change the stored deck")
	var paths := service.get_authored_paths()
	(paths[0]["card"] as Dictionary)["effects"] = {"block": 999}
	(paths[0] as Dictionary)["id"] = "tampered"
	_check((service.get_authored_paths()[0]["card"] as Dictionary).get("effects") == {"block": 9},
		"mutating returned Path records cannot change the stored source")
	_check(service.get_authored_paths()[0]["id"] == "bulwark",
		"mutating returned Path IDs cannot change the stored source")
	# Mutating a returned base deck cannot change the stored deck.
	var base := service.get_base_deck()
	base.clear()
	_check(service.get_base_deck() == deck, "mutating a returned base deck cannot change the stored deck")
	var replay := service.choose("vanguard")
	_check(replay.get("ok") == false, "tampered projector still refuses a second claim")
	_check(replay.get("starter_deck") == deck, "tampered refusal still returns the unchanged base deck")


func _test_no_rng() -> void:
	if not authored is Dictionary:
		return
	var bulwark_rng := _rng_start(81200)
	var bulwark_service := RunWardenPathChoice.new(authored, deck)
	var bulwark_receipt := bulwark_service.choose("bulwark")
	_check(bulwark_receipt.get("ok") == true, "bulwark choice succeeds inside the no-RNG window")
	_check(randi() == bulwark_rng, "the whole bulwark flow spends no global RNG")
	var vanguard_rng := _rng_start(81201)
	var vanguard_service := RunWardenPathChoice.new(authored, deck)
	var vanguard_receipt := vanguard_service.choose("vanguard")
	_check(vanguard_receipt.get("ok") == true, "vanguard choice succeeds inside the no-RNG window")
	_check(randi() == vanguard_rng, "the whole vanguard flow spends no global RNG")
	# A seeded local RNG is untouched too.
	var local := RandomNumberGenerator.new()
	local.seed = 81202
	var state_before := local.state
	var service := RunWardenPathChoice.new(authored, deck)
	service.choose("nope")
	service.choose("bulwark")
	service.choose("vanguard")
	service.get_receipt()
	service.get_base_deck()
	service.get_authored_paths()
	_check(local.state == state_before, "a seeded local RNG is untouched by the projector")
