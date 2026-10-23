extends SceneTree
## Deterministic headless test for RunSeamstressPathChoice (D2-5 data slice).
## Parses the authored Seamstress Path JSON and the genuine twelve-copy starter
## deck, checks every per-ID field of both Paths, exercises both legal choices as
## detached proposed decks (12 -> 13 with exactly one Path card), and verifies
## fail-closed rejections (unknown/blank/non-string Path ID, duplicate claim, bad
## deck argument) with no RNG and no caller mutation.
## Data/service only: no live Heroes selection, combat effect or save claim.

const SOURCE_PATH := "res://data/heroes/seamstress_paths.json"
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

const PATH_IDS := ["bloodline", "unpicker"]
const PATH_CARD_IDS := ["seamstress_leech_stitch", "seamstress_fray"]

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
	_test_catalog_isolation()
	_test_bloodline_choice()
	_test_unpicker_choice()
	_test_no_stacking()
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
	print("run_seamstress_path_choice_test: ", "PASS" if failures.is_empty() else "FAIL",
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


func _count(ids: Array) -> Dictionary:
	var counts: Dictionary = {}
	for card_id in ids:
		counts[card_id] = int(counts.get(card_id, 0)) + 1
	return counts


func _path_by_id(list: Array, path_id: String) -> Dictionary:
	for entry in list:
		if entry is Dictionary and entry.get("id") == path_id:
			return entry
	return {}


func _test_source_file() -> void:
	var file := FileAccess.open(SOURCE_PATH, FileAccess.READ)
	_check(file != null, "seamstress_paths.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_check(not text.strip_edges().is_empty(), "seamstress_paths.json is non-empty")
	var parser := JSON.new()
	_check(parser.parse(text) == OK, "seamstress_paths.json parses through JSON")
	authored = parser.data if parser.data != null else null
	source_snapshot = authored.duplicate(true) if authored != null else null
	_check(authored is Array, "seamstress_paths.json top level is an array")
	if authored is Array:
		_check((authored as Array).size() == 2, "authored array holds exactly two Path records")
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
	if not authored is Array or not deck is Array:
		return
	var counts := _count(deck)
	_check(counts == EXPECTED_STARTER, "starter deck is exactly the documented twelve copies")
	_check((deck as Array).size() == 12, "starter deck holds twelve cards")
	var catalog := StarterCards.new()
	catalog_deck_snapshot = catalog.get_starting_deck()
	catalog_ids_snapshot = catalog.get_all_card_ids()
	_check(catalog_deck_snapshot == deck, "StarterCards starting deck matches starter_deck.json")
	_check(RunSeamstressPathChoice.load_authored_paths() == authored,
		"service loads the authored Path array")
	_check(RunSeamstressPathChoice.load_authored_starter_deck() == deck,
		"service loads the authored starter deck")


func _test_authored_records() -> void:
	if not authored is Array:
		return
	var list: Array = authored
	var bloodline := _path_by_id(list, "bloodline")
	var unpicker := _path_by_id(list, "unpicker")
	_check(not bloodline.is_empty(), "exactly one bloodline Path record")
	_check(not unpicker.is_empty(), "exactly one unpicker Path record")
	if not bloodline.is_empty():
		_check_bloodline(bloodline)
	if not unpicker.is_empty():
		_check_unpicker(unpicker)


func _check_bloodline(record: Dictionary) -> void:
	_check(record.get("display_name") == "Bloodline", "bloodline display name")
	var passive: Variant = record.get("passive")
	_check(passive is Dictionary, "bloodline passive is an object")
	if passive is Dictionary:
		var p: Dictionary = passive
		_check(p.get("id") == "seamstress_bleed_bonus", "bloodline passive ID is stable")
		_check(p.get("kind") == "bleed_bonus", "bloodline passive kind is bleed_bonus")
		_check(p.get("applies_to") == "seamstress", "bloodline passive applies to the Seamstress")
		_check(p.get("status") == "bleed", "bloodline passive adds Bleed")
		_check(int(p.get("value", 0)) == 1, "bloodline passive adds exactly +1 Bleed")
		_check(p.get("stacks") == false, "bloodline passive never stacks")
	var card: Variant = record.get("card")
	_check(card is Dictionary, "bloodline card is an object")
	if not card is Dictionary:
		return
	var c: Dictionary = card
	_check(c.get("id") == "seamstress_leech_stitch", "Leech Stitch namespaced card ID")
	_check(c.get("display_name") == "Leech Stitch", "Leech Stitch display name")
	_check(c.get("owner") == "seamstress", "Leech Stitch owner")
	_check(c.get("cost") == 1, "Leech Stitch costs 1")
	_check(_norm(c.get("from_positions")) == [1, 2, 3], "Leech Stitch playable from 1, 2 or 3")
	_check(c.get("target_kind") == "enemy_single", "Leech Stitch targets one enemy")
	_check(_norm(c.get("to_positions")) == [1, 2, 3], "Leech Stitch targets enemies 1, 2 or 3")
	var effects: Variant = c.get("effects")
	_check(effects is Dictionary, "Leech Stitch effects are an object")
	if effects is Dictionary:
		var e: Dictionary = effects
		_check(int(e.get("bleed", 0)) == 3, "Leech Stitch applies exactly Bleed 3")
		var heal: Variant = e.get("heal")
		_check(heal is Dictionary, "Leech Stitch heal descriptor is an object")
		if heal is Dictionary:
			var h: Dictionary = heal
			_check(int(h.get("amount", 0)) == 2, "Leech Stitch heals exactly 2")
			_check(h.get("target") == "weakest_living_ally",
				"Leech Stitch heals the weakest LIVING ally descriptor")
			_check(h.get("cap") == "missing_hp", "Leech Stitch heal is capped by missing HP")
	_check(c.get("illustration_path") == "res://assets/paper/cards/emblem_seamstress.png",
		"Leech Stitch falls back to the existing Seamstress emblem")


func _check_unpicker(record: Dictionary) -> void:
	_check(record.get("display_name") == "Unpicker", "unpicker display name")
	var passive: Variant = record.get("passive")
	_check(passive is Dictionary, "unpicker passive is an object")
	if passive is Dictionary:
		var p: Dictionary = passive
		_check(p.get("id") == "seamstress_bleed_adds_unravel", "unpicker passive ID is stable")
		_check(p.get("kind") == "bleed_adds_unravel", "unpicker passive kind is bleed_adds_unravel")
		_check(p.get("applies_to") == "seamstress", "unpicker passive applies to the Seamstress")
		_check(p.get("status") == "unravel", "unpicker passive adds Unravel")
		_check(int(p.get("value", 0)) == 2, "unpicker passive adds exactly +2 Unravel")
		_check(p.get("replaces") == "seamstress_bleed_bonus",
			"unpicker replaces the Bloodline +1 Bleed passive")
		_check(int(p.get("replaced_value", 0)) == 1,
			"unpicker records the replaced +1 Bleed value")
		_check(p.get("stacks") == false, "unpicker passive never stacks")
	var card: Variant = record.get("card")
	_check(card is Dictionary, "unpicker card is an object")
	if not card is Dictionary:
		return
	var c: Dictionary = card
	_check(c.get("id") == "seamstress_fray", "Fray namespaced card ID")
	_check(c.get("display_name") == "Fray", "Fray display name")
	_check(c.get("owner") == "seamstress", "Fray owner")
	_check(c.get("cost") == 1, "Fray costs 1")
	_check(_norm(c.get("from_positions")) == [1, 2, 3], "Fray playable from 1, 2 or 3")
	_check(c.get("target_kind") == "enemy_single", "Fray targets one enemy")
	_check(_norm(c.get("to_positions")) == [1, 2, 3], "Fray targets enemies 1, 2 or 3")
	_check(_norm(c.get("effects")) == {"unravel": 4, "bleed": 1},
		"Fray is exactly Unravel 4 and Bleed 1")
	_check(c.get("illustration_path") == "res://assets/paper/cards/emblem_seamstress.png",
		"Fray falls back to the existing Seamstress emblem")


func _test_catalog_isolation() -> void:
	var catalog := StarterCards.new()
	var pool := SeamstressPoolCards.new()
	for card_id: String in PATH_CARD_IDS:
		_check(not catalog.has_card(card_id), card_id + " is not a starter card")
		_check(not pool.has_card(card_id), card_id + " is not in the Seamstress reward pool")
		_check(not catalog.get_starting_deck().has(card_id), card_id + " is not in the starting deck")
		_check(not pool.get_all_card_ids().has(card_id), card_id + " is not a reward-eligible pool ID")
	_check(pool.get_base_ids().size() == 12, "Seamstress pool still has its twelve base cards")


func _test_bloodline_choice() -> void:
	var input: Array = (deck as Array).duplicate()
	var service := RunSeamstressPathChoice.new(authored, deck)
	_check(service.is_valid() and not service.is_claimed(),
		"fresh Bloodline projector is valid and unclaimed")
	_check(service.get_paths().size() == 2, "service exposes both authored Paths")
	_check(service.get_receipt().is_empty(), "no receipt exists before a choice")
	var receipt := service.choose("bloodline", input)
	_check(receipt.get("ok") == true, "bloodline choice succeeds")
	_check(receipt.get("owner") == "seamstress", "bloodline receipt keeps the Seamstress owner")
	_check(receipt.get("path_id") == "bloodline", "bloodline receipt names the bloodline Path")
	_check(receipt.get("display_name") == "Bloodline", "bloodline receipt display name")
	var passive: Dictionary = receipt.get("passive", {})
	_check(passive.get("id") == "seamstress_bleed_bonus", "bloodline receipt carries the +1 Bleed passive ID")
	_check(int(passive.get("value", 0)) == 1, "bloodline receipt passive value is +1")
	_check(passive.get("stacks") == false, "bloodline receipt passive never stacks")
	var card: Dictionary = receipt.get("card", {})
	_check(card.get("id") == "seamstress_leech_stitch", "bloodline receipt carries Leech Stitch")
	_check(card.get("cost") == 1 and _norm(card.get("from_positions")) == [1, 2, 3]
		and card.get("target_kind") == "enemy_single" and _norm(card.get("to_positions")) == [1, 2, 3],
		"Leech Stitch receipt card is 1 energy / from 1-3 / single enemy 1-3")
	_check(_norm(card.get("effects")) == {"bleed": 3,
		"heal": {"amount": 2, "target": "weakest_living_ally", "cap": "missing_hp"}},
		"Leech Stitch receipt keeps Bleed 3 and the heal descriptor")
	var proposed: Array = receipt.get("deck", [])
	_check(proposed.size() == 13, "bloodline proposed deck holds thirteen cards")
	_check(_count(proposed) == EXPECTED_STARTER.merged({"seamstress_leech_stitch": 1}, true),
		"bloodline proposed deck keeps all twelve starter copies plus exactly one Path card")
	_check(not proposed.has("seamstress_fray"), "bloodline proposed deck excludes Fray")
	_check(proposed.slice(0, 12) == deck,
		"bloodline proposed deck preserves the authored twelve-card order")
	_check(input == deck, "bloodline choice never mutates the caller's deck array")
	_check(service.is_claimed() and not service.is_valid(), "bloodline claim latches on the projector")
	_check(service.get_base_deck() == deck, "bloodline claim leaves the stored base deck unchanged")
	_check(service.get_receipt() == receipt, "stored receipt matches the returned receipt")


func _test_unpicker_choice() -> void:
	var input: Array = (deck as Array).duplicate()
	var service := RunSeamstressPathChoice.new(authored, deck)
	_check(service.is_valid() and not service.is_claimed(),
		"fresh Unpicker projector is valid and unclaimed")
	var receipt := service.choose("unpicker", input)
	_check(receipt.get("ok") == true, "unpicker choice succeeds")
	_check(receipt.get("path_id") == "unpicker", "unpicker receipt names the unpicker Path")
	var passive: Dictionary = receipt.get("passive", {})
	_check(passive.get("id") == "seamstress_bleed_adds_unravel",
		"unpicker receipt carries the +2 Unravel passive ID")
	_check(int(passive.get("value", 0)) == 2, "unpicker receipt passive value is +2 Unravel")
	_check(passive.get("replaces") == "seamstress_bleed_bonus",
		"unpicker receipt replaces the Bloodline passive")
	var card: Dictionary = receipt.get("card", {})
	_check(card.get("id") == "seamstress_fray", "unpicker receipt carries Fray")
	_check(card.get("cost") == 1 and _norm(card.get("from_positions")) == [1, 2, 3]
		and card.get("target_kind") == "enemy_single" and _norm(card.get("to_positions")) == [1, 2, 3],
		"Fray receipt card is 1 energy / from 1-3 / single enemy 1-3")
	_check(_norm(card.get("effects")) == {"unravel": 4, "bleed": 1},
		"Fray receipt keeps exactly Unravel 4 and Bleed 1")
	var proposed: Array = receipt.get("deck", [])
	_check(proposed.size() == 13, "unpicker proposed deck holds thirteen cards")
	_check(_count(proposed) == EXPECTED_STARTER.merged({"seamstress_fray": 1}, true),
		"unpicker proposed deck keeps all twelve starter copies plus exactly one Path card")
	_check(not proposed.has("seamstress_leech_stitch"), "unpicker proposed deck excludes Leech Stitch")
	_check(input == deck, "unpicker choice never mutates the caller's deck array")
	_check(service.is_claimed() and service.get_base_deck() == deck,
		"unpicker claim latches and leaves the stored base deck unchanged")


func _test_no_stacking() -> void:
	if not authored is Array:
		return
	var list: Array = authored
	var bloodline := _path_by_id(list, "bloodline")
	var unpicker := _path_by_id(list, "unpicker")
	var bloodline_passive: Dictionary = bloodline.get("passive", {})
	var unpicker_passive: Dictionary = unpicker.get("passive", {})
	_check(bloodline_passive.get("id") != unpicker_passive.get("id"),
		"Bloodline and Unpicker passives have distinct stable IDs")
	_check(bloodline_passive.get("status") != unpicker_passive.get("status"),
		"Bloodline adds Bleed while Unpicker adds Unravel")
	_check(bloodline_passive.get("stacks") == false and unpicker_passive.get("stacks") == false,
		"neither Path passive stacks")
	_check(unpicker_passive.get("replaces") == bloodline_passive.get("id"),
		"Unpicker explicitly replaces the Bloodline passive ID")
	_check(bloodline_passive.get("kind") != unpicker_passive.get("kind"),
		"Bloodline and Unpicker passives are different rules, never one combined passive")
	_check(int(bloodline_passive.get("value", 0)) == 1 and int(unpicker_passive.get("value", 0)) == 2,
		"each Path carries only its own authored value (+1 Bleed / +2 Unravel)")
	# Choosing either Path on separate services never yields both cards.
	var left := RunSeamstressPathChoice.new(authored, deck)
	var left_receipt := left.choose("bloodline")
	var right := RunSeamstressPathChoice.new(authored, deck)
	var right_receipt := right.choose("unpicker")
	var left_deck: Array = left_receipt.get("deck", [])
	var right_deck: Array = right_receipt.get("deck", [])
	_check(left_deck.has("seamstress_leech_stitch") and not left_deck.has("seamstress_fray"),
		"a Bloodline deck carries only Leech Stitch")
	_check(right_deck.has("seamstress_fray") and not right_deck.has("seamstress_leech_stitch"),
		"an Unpicker deck carries only Fray")
	_check(left_deck != right_deck, "the two Paths produce distinct proposed decks")


func _test_invalid_and_replay() -> void:
	var input: Array = (deck as Array).duplicate()
	var service := RunSeamstressPathChoice.new(authored, deck)
	var rng := _rng_start(91001)
	var rejected := service.choose("sentinel", input)
	_check(rejected.get("ok") == false, "unoffered Path is rejected")
	_check(rejected.get("path_id") == "" and rejected.get("owner") == "" and rejected.get("card") == {},
		"unoffered Path rejection carries empty identity and card")
	_check(rejected.get("deck") == deck, "unoffered Path rejection returns the unchanged base deck")
	_check(input == deck, "unoffered Path rejection never mutates the caller's deck")
	_check(service.is_valid() and not service.is_claimed(), "unoffered Path consumes no claim")
	_check(service.get_receipt().is_empty(), "unoffered Path writes no receipt")
	_check(service.choose("", input).get("ok") == false, "blank Path ID is rejected")
	_check(service.choose("   ", input).get("ok") == false, "whitespace Path ID is rejected")
	_check(service.choose(null, input).get("ok") == false, "null Path ID is rejected")
	_check(service.choose(1, input).get("ok") == false, "non-string Path ID is rejected")
	_check(service.choose("Bloodline", input).get("ok") == false, "case-mismatched Path ID is rejected")
	_check(service.is_valid() and not service.is_claimed(), "invalid attempts consume no claim")
	_check(service.get_base_deck() == deck, "invalid attempts leave the stored deck unchanged")
	_check(input == deck, "invalid attempts never mutate the caller's deck")
	_check(randi() == rng, "invalid attempts spend no global RNG")
	# The same selector then claims exactly once.
	var success := service.choose("bloodline", input)
	_check(success.get("ok") == true and (success.get("deck") as Array).size() == 13,
		"same selector recovers and claims once after rejected attempts")
	_check(service.is_claimed() and not service.is_valid(), "recovered claim latches exactly once")
	_check(service.get_receipt() == success, "recovered receipt is stored unchanged")
	# A duplicate claim cannot change the receipt, deck or eligibility.
	var replay := service.choose("unpicker", input)
	_check(replay.get("ok") == false, "second claim on a different Path is refused")
	_check(replay.get("path_id") == "" and replay.get("card") == {},
		"refused replay has empty identity and card")
	_check(replay.get("deck") == deck, "refused replay returns the unchanged base deck")
	_check(service.get_receipt() == success, "refused replay cannot change the stored receipt")
	_check(service.get_base_deck() == deck, "refused replay cannot change the stored deck")
	_check(input == deck, "refused replay never mutates the caller's deck")
	_check(service.choose("bloodline", input).get("ok") == false,
		"repeated claim of the same Path is refused")
	_check(service.is_claimed(), "refused replay keeps the claim latched")
	var replay_rng := _rng_start(91002)
	var replay_again := service.choose("bloodline", input)
	_check(replay_again.get("ok") == false, "further replay is refused")
	_check(service.get_receipt() == success, "further replay cannot change the stored receipt")
	_check(randi() == replay_rng, "recovered claim and replays spend no global RNG")
	# A brand-new projector with the same source is unaffected by the earlier claim.
	var fresh := RunSeamstressPathChoice.new(authored, deck)
	_check(fresh.is_valid() and not fresh.is_claimed(), "a new projector is independently unclaimed")
	_check(fresh.choose("unpicker").get("ok") == true, "a new projector can choose the other Path")
	# A null deck argument falls back to the stored base deck.
	var implicit := RunSeamstressPathChoice.new(authored, deck)
	var implicit_receipt := implicit.choose("bloodline")
	_check(implicit_receipt.get("ok") == true, "a null deck argument uses the stored base deck")
	_check((implicit_receipt.get("deck") as Array).size() == 13,
		"the implicit deck path still appends exactly one Path card")
	# An invalid deck argument fails closed without consuming the claim.
	var selector := RunSeamstressPathChoice.new(authored, deck)
	var short_deck: Array = (deck as Array).duplicate()
	short_deck.pop_back()
	var bad_deck := selector.choose("bloodline", short_deck)
	_check(bad_deck.get("ok") == false, "an eleven-card deck argument is rejected")
	_check(selector.is_valid() and not selector.is_claimed(),
		"an invalid deck argument consumes no claim")
	_check(short_deck.size() == 11, "an invalid deck argument is never mutated")
	_check(selector.choose("bloodline", deck).get("ok") == true,
		"the selector still accepts a legal deck after a rejected deck argument")


func _test_bad_source_inputs() -> void:
	if not authored is Array:
		return
	# Only one authored Path record.
	var one_path: Array = [(authored as Array)[0].duplicate(true)]
	_check_invalid_source(one_path, deck, "single Path record")
	# Duplicate Path IDs.
	var dup_paths: Array = (authored as Array).duplicate(true)
	dup_paths[1]["id"] = "bloodline"
	_check_invalid_source(dup_paths, deck, "duplicate Path IDs")
	# Unknown Path ID.
	var unknown_path: Array = (authored as Array).duplicate(true)
	unknown_path[0]["id"] = "sentinel"
	_check_invalid_source(unknown_path, deck, "unknown Path ID")
	# Card with the wrong owner.
	var wrong_card_owner: Array = (authored as Array).duplicate(true)
	wrong_card_owner[0]["card"]["owner"] = "warden"
	_check_invalid_source(wrong_card_owner, deck, "Path card with wrong owner")
	# Card ID colliding with a base starter copy.
	var colliding: Array = (authored as Array).duplicate(true)
	colliding[0]["card"]["id"] = "seamstress_prick"
	_check_invalid_source(colliding, deck, "Path card colliding with a starter card")
	# Card ID colliding with the normal reward pool.
	var pool_collision: Array = (authored as Array).duplicate(true)
	pool_collision[0]["card"]["id"] = "seamstress_unpick"
	_check_invalid_source(pool_collision, deck, "Path card colliding with a pool card")
	# Non-numeric passive amount.
	var bad_amount: Array = (authored as Array).duplicate(true)
	bad_amount[0]["passive"]["value"] = "one"
	_check_invalid_source(bad_amount, deck, "non-numeric passive amount")
	# Positions outside the three-slot line.
	var bad_positions: Array = (authored as Array).duplicate(true)
	bad_positions[1]["card"]["to_positions"] = [1, 4]
	_check_invalid_source(bad_positions, deck, "Path card target outside positions 1-3")
	# Semantically invalid but type-consistent rule values must also fail closed.
	var bleeding: Array = (authored as Array).duplicate(true)
	bleeding[0]["passive"]["value"] = 2
	_check_invalid_source(bleeding, deck, "Bloodline bonus changed to +2 Bleed")
	var stacking: Array = (authored as Array).duplicate(true)
	stacking[0]["passive"]["stacks"] = true
	_check_invalid_source(stacking, deck, "Bloodline stacking with its replacement")
	var not_replacing: Array = (authored as Array).duplicate(true)
	not_replacing[1]["passive"].erase("replaces")
	_check_invalid_source(not_replacing, deck, "Unpicker without a replaced passive")
	var wrong_replacement: Array = (authored as Array).duplicate(true)
	wrong_replacement[1]["passive"]["replaces"] = "some_other_passive"
	_check_invalid_source(wrong_replacement, deck, "Unpicker replacing the wrong passive")
	var fray_unravel: Array = (authored as Array).duplicate(true)
	fray_unravel[1]["card"]["effects"]["unravel"] = 5
	_check_invalid_source(fray_unravel, deck, "Fray Unravel changed to 5")
	var leech_bleed: Array = (authored as Array).duplicate(true)
	leech_bleed[0]["card"]["effects"]["bleed"] = 4
	_check_invalid_source(leech_bleed, deck, "Leech Stitch Bleed changed to 4")
	var leech_heal: Array = (authored as Array).duplicate(true)
	leech_heal[0]["card"]["effects"]["heal"]["amount"] = 3
	_check_invalid_source(leech_heal, deck, "Leech Stitch heal changed to 3")
	var leech_target: Array = (authored as Array).duplicate(true)
	leech_target[0]["card"]["effects"]["heal"]["target"] = "self"
	_check_invalid_source(leech_target, deck, "Leech Stitch heal target changed")
	var other_card_id: Array = (authored as Array).duplicate(true)
	other_card_id[1]["card"]["id"] = "seamstress_fraying"
	_check_invalid_source(other_card_id, deck, "Fray swapped for another seamstress_ card ID")
	var fray_cost: Array = (authored as Array).duplicate(true)
	fray_cost[1]["card"]["cost"] = 2
	_check_invalid_source(fray_cost, deck, "Fray cost changed to 2")
	var no_fallback: Array = (authored as Array).duplicate(true)
	no_fallback[0]["card"]["illustration_path"] = ""
	_check_invalid_source(no_fallback, deck, "Path card without an art fallback")
	# Source that is not an array at all.
	var not_array := RunSeamstressPathChoice.new({"paths": (authored as Array).duplicate(true)}, deck)
	_check(not not_array.is_valid() and not not_array.is_claimed(),
		"object instead of an authored array fails closed")
	_check(not_array.choose("bloodline").get("ok") == false, "failed projector refuses a choice")
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
	var path_in_deck: Array = (deck as Array).duplicate()
	path_in_deck.append("seamstress_fray")
	_check_invalid_source(authored, path_in_deck, "thirteen-card starter deck with a Path card")
	_check_invalid_source(authored, "not an array", "non-array starter deck")


func _check_invalid_source(source: Variant, source_deck: Variant, label: String) -> void:
	var service := RunSeamstressPathChoice.new(source, source_deck)
	_check(not service.is_valid() and not service.is_claimed(), label + " projector fails closed")
	_check(service.get_receipt().is_empty(), label + " projector holds no receipt")
	_check(service.get_paths().is_empty(), label + " projector exposes no Path records")
	var result := service.choose("bloodline")
	_check(result.get("ok") == false, label + " projector refuses a choice")
	_check(result.get("path_id") == "" and result.get("card") == {},
		label + " refusal returns empty identity and card")
	_check(not service.is_claimed(), label + " refusal cannot claim")


func _test_tampering_isolation() -> void:
	# Caller mutation of the input source and deck cannot reach the projector.
	var caller_source: Array = (authored as Array).duplicate(true)
	var caller_deck: Array = (deck as Array).duplicate()
	var service := RunSeamstressPathChoice.new(caller_source, caller_deck)
	_check(service.is_valid(), "fresh projector valid before caller tampering")
	caller_source[0]["card"]["effects"] = {"bleed": 999}
	caller_deck.clear()
	var receipt := service.choose("bloodline")
	_check(receipt.get("ok") == true, "caller tampering after construction does not break the claim")
	_check(int((receipt.get("card", {}) as Dictionary).get("effects", {}).get("bleed", 0)) == 3,
		"caller source tampering cannot change the stored card")
	_check((receipt.get("deck") as Array).size() == 13,
		"caller deck tampering cannot change the proposed deck")
	# Returned receipt and snapshots are detached from the projector.
	(receipt["card"] as Dictionary)["effects"] = {"bleed": 999}
	(receipt["deck"] as Array).clear()
	(receipt["passive"] as Dictionary)["value"] = 99
	receipt["ok"] = false
	var stored := service.get_receipt()
	_check(stored.get("ok") == true, "mutating a returned receipt cannot change the stored receipt")
	_check(int((stored.get("card", {}) as Dictionary).get("effects", {}).get("bleed", 0)) == 3,
		"mutating a returned receipt cannot change the stored card")
	_check((stored.get("deck") as Array).size() == 13,
		"mutating a returned receipt cannot change the stored deck")
	_check(int((stored.get("passive", {}) as Dictionary).get("value", 0)) == 1,
		"mutating a returned receipt cannot change the stored passive")
	var paths := service.get_paths()
	(paths[0]["card"] as Dictionary)["effects"] = {"bleed": 999}
	(paths[0] as Dictionary)["id"] = "tampered"
	_check(int((service.get_paths()[0]["card"] as Dictionary).get("effects", {}).get("bleed", 0)) == 3,
		"mutating returned Path records cannot change the stored source")
	_check(service.get_paths()[0]["id"] == "bloodline",
		"mutating returned Path IDs cannot change the stored source")
	_check(service.get_paths() != paths, "get_paths returns a fresh deep copy each call")
	# get_path lookup is detached too.
	var single := service.get_path("unpicker")
	_check(single.get("id") == "unpicker", "get_path finds the Unpicker record")
	(single["card"] as Dictionary)["effects"] = {"unravel": 99}
	_check(_norm(service.get_path("unpicker")["card"]["effects"]) == {"unravel": 4, "bleed": 1},
		"mutating a get_path result cannot change the stored source")
	_check(service.get_path("sentinel").is_empty(), "get_path returns empty for an unknown ID")
	# Mutating a returned base deck cannot change the stored deck.
	var base := service.get_base_deck()
	base.clear()
	_check(service.get_base_deck() == deck, "mutating a returned base deck cannot change the stored deck")
	var replay := service.choose("unpicker")
	_check(replay.get("ok") == false, "tampered projector still refuses a second claim")
	_check(replay.get("deck") == deck, "tampered refusal still returns the unchanged base deck")


func _test_no_rng() -> void:
	if not authored is Array:
		return
	var bloodline_rng := _rng_start(91200)
	var bloodline_service := RunSeamstressPathChoice.new(authored, deck)
	var bloodline_receipt := bloodline_service.choose("bloodline", deck)
	_check(bloodline_receipt.get("ok") == true, "bloodline choice succeeds inside the no-RNG window")
	_check(randi() == bloodline_rng, "the whole bloodline flow spends no global RNG")
	var unpicker_rng := _rng_start(91201)
	var unpicker_service := RunSeamstressPathChoice.new(authored, deck)
	var unpicker_receipt := unpicker_service.choose("unpicker", deck)
	_check(unpicker_receipt.get("ok") == true, "unpicker choice succeeds inside the no-RNG window")
	_check(randi() == unpicker_rng, "the whole unpicker flow spends no global RNG")
	# A seeded local RNG is untouched too.
	var local := RandomNumberGenerator.new()
	local.seed = 91202
	var state_before := local.state
	var service := RunSeamstressPathChoice.new(authored, deck)
	service.choose("nope")
	service.choose("bloodline")
	service.choose("unpicker")
	service.get_receipt()
	service.get_base_deck()
	service.get_paths()
	_check(local.state == state_before, "a seeded local RNG is untouched by the projector")
