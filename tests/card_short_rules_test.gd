extends SceneTree
## Headless, scene-free regression for the terse sewn card face.
##
## The face keeps exact authored damage, Block, Thorns, heal, status and Unravel
## amounts and only names the Pinned, Guarding and Thorns keywords. The full
## mechanics (the different-owner +5, the Guard redirect, the Thorns return
## damage and their expiry) belong to CardKeywordGlossary's Help rows.
##
## Every record below is read from the shipped Warden/Tinker pools; the only
## hand-written records are the in-memory unknown/malformed probes, which must
## stay honest instead of inventing mechanics.

## The exact short face each shipped base/'+' record must print.
const FACE_CASES := [
	{"id": "warden_pinning_jab", "line": "Deal 4. Pin."},
	{"id": "warden_pinning_jab_plus", "line": "Deal 6. Pin."},
	{"id": "warden_draw_fire", "line": "Gain 6 Block. Guard."},
	{"id": "warden_draw_fire_plus", "line": "Gain 8 Block. Guard."},
	{"id": "warden_counter_stitch", "line": "Gain 5 Block. Gain 3 Thorns."},
	{"id": "warden_counter_stitch_plus", "line": "Gain 7 Block. Gain 4 Thorns."},
	{"id": "tinker_spring_trap", "line": "Deal 3. Pin."},
	{"id": "tinker_spring_trap_plus", "line": "Deal 4. Pin."},
]
## Prose that belongs to the Help glossary or the drawn pips, never to the face.
const HELP_ONLY_WORDS := ["+5", "until", "next turn", "different hero",
	"DIFFERENT hero", "redirect", "redirected", "expires", "From", "Target"]
const UNKNOWN_FALLBACK := "Other authored effects are not described."

var failures: Array[String] = []
var checks := 0
var warden := WardenPoolCards.new()
var tinker := TinkerPoolCards.new()


func _initialize() -> void:
	seed(4517)
	var expected_global := randi()
	seed(4517)
	_test_shipped_faces()
	_test_authored_amounts()
	_test_help_keeps_full_mechanics()
	_test_unknown_and_malformed_fallbacks()
	_check(randi() == expected_global, "short-line formatting draws no global RNG")
	for failure in failures:
		printerr(failure)
	print("card_short_rules_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


## The shipped definitions live in the Warden and Tinker pools only.
func _definition(card_id: String) -> Dictionary:
	if warden.has_card(card_id):
		return warden.get_definition(card_id)
	if tinker.has_card(card_id):
		return tinker.get_definition(card_id)
	return {}


func _effects(card_id: String) -> Dictionary:
	var raw: Variant = _definition(card_id).get("effects", {})
	return raw if raw is Dictionary else {}


func _test_shipped_faces() -> void:
	for entry in FACE_CASES:
		var card_id: String = str(entry["id"])
		var expected_line: String = str(entry["line"])
		var definition := _definition(card_id)
		_check(not definition.is_empty(), "shipped catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var original: Dictionary = definition.duplicate(true)
		var described: Dictionary = CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"face record is fully described, no fallback: " + card_id)
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		# Pinned keeps one keyword whether it is authored as a flag or a
		# nested descriptor, and never borrows the descriptor's bonus amount.
		if _effects(card_id).has("pinned"):
			_check(line.count("Pin") == 1 and not line.to_lower().contains("pin +"),
				"Pin is one bare keyword on the face: %s (%s)" % [card_id, line])
		_check(definition == original,
			"formatting never mutates the shipped record: " + card_id)


## The numbers printed on the face are exactly the authored ones, read from the
## same catalog record, so no amount is guessed or copied from another card.
func _test_authored_amounts() -> void:
	var cases := [
		["warden_pinning_jab", "Deal 4. Pin."],
		["warden_pinning_jab_plus", "Deal 6. Pin."],
		["tinker_spring_trap", "Deal 3. Pin."],
		["tinker_spring_trap_plus", "Deal 4. Pin."],
	]
	for pair in cases:
		var card_id: String = str(pair[0])
		var effects := _effects(card_id)
		var damage: int = int(effects.get("damage", -1))
		_check(damage > 0, "authored damage exists: " + card_id)
		_check(CardShortRules.line(_definition(card_id)) == str(pair[1])
			and str(pair[1]).begins_with("Deal %d. Pin." % damage),
			"face damage equals the authored amount: " + card_id)
	var block_cases := [
		["warden_draw_fire", "warden_draw_fire_plus"],
		["warden_counter_stitch", "warden_counter_stitch_plus"],
	]
	for ids in block_cases:
		var base_id: String = str(ids[0])
		var plus_id: String = str(ids[1])
		_check(int(_effects(plus_id).get("block", 0)) > int(_effects(base_id).get("block", 0)),
			"'+' really upgrades the authored Block: " + base_id)
		for card_id: String in [base_id, plus_id]:
			var block: int = int(_effects(card_id).get("block", -1))
			_check(CardShortRules.line(_definition(card_id)).contains(
				"Gain %d Block." % block),
				"face Block equals the authored amount: " + card_id)
	var thorns_cases := [
		["warden_counter_stitch", 3],
		["warden_counter_stitch_plus", 4],
	]
	for pair in thorns_cases:
		var card_id: String = str(pair[0])
		var authored: int = int(_effects(card_id).get("thorns", -1))
		_check(authored == int(pair[1]),
			"authored Thorns read from the catalog: " + card_id)
		_check(CardShortRules.line(_definition(card_id)).ends_with(
			"Gain %d Thorns." % authored),
			"face Thorns equals the authored amount: " + card_id)


func _keyword_rows(definition: Dictionary) -> Dictionary:
	var rows := {}
	for row: Dictionary in CardKeywordGlossary.describe(definition):
		rows[str(row.get("keyword", ""))] = str(row.get("explanation", ""))
	return rows


func _test_help_keeps_full_mechanics() -> void:
	# Both authored Pinned shapes keep the exact shared Help row.
	for card_id: String in ["warden_pinning_jab", "warden_pinning_jab_plus",
			"tinker_spring_trap", "tinker_spring_trap_plus"]:
		var pin_rows := _keyword_rows(_definition(card_id))
		_check(pin_rows.has("Pinned"), "Help explains Pinned: " + card_id)
		var explanation: String = str(pin_rows.get("Pinned", ""))
		_check(explanation.contains("next attack by a DIFFERENT hero adds +5 damage"),
			"Help keeps the different-owner +5: " + card_id)
		_check(explanation.contains("before Weak/Exposed"),
			"Help keeps the +5 timing before Weak/Exposed: " + card_id)
		_check(explanation.contains("consumes this pin"),
			"Help keeps the single consumption: " + card_id)
		_check(explanation.contains("The same hero cannot use it"),
			"Help keeps the same-hero exclusion: " + card_id)
	# Guard keeps its redirect target and its expiry.
	for card_id: String in ["warden_draw_fire", "warden_draw_fire_plus"]:
		var guard_rows := _keyword_rows(_definition(card_id))
		_check(guard_rows.has("Guarding"), "Help explains Guarding: " + card_id)
		var guard_text: String = str(guard_rows.get("Guarding", ""))
		_check(guard_text.contains("redirects attacks aimed at other heroes to Warden"),
			"Help keeps the Guard redirect: " + card_id)
		_check(guard_text.contains("until the next turn"),
			"Help keeps the Guard expiry: " + card_id)
		_check(CardShortRules.line(_definition(card_id)).contains("Guard.")
			and not CardShortRules.line(_definition(card_id)).contains("until"),
			"the face leaves the Guard duration to Help: " + card_id)
	# Thorns keeps its exact return damage and its expiry.
	for pair in [["warden_counter_stitch", 3], ["warden_counter_stitch_plus", 4]]:
		var card_id: String = str(pair[0])
		var authored: int = int(pair[1])
		var thorns_rows := _keyword_rows(_definition(card_id))
		_check(thorns_rows.has("Thorns %d" % authored),
			"Help explains Thorns %d: %s" % [authored, card_id])
		var thorns_text: String = str(thorns_rows.get("Thorns %d" % authored, ""))
		_check(thorns_text.contains("makes enemies that attack Warden take %d damage"
			% authored), "Help keeps the Thorns return damage: " + card_id)
		_check(thorns_text.contains("until the next turn"),
			"Help keeps the Thorns expiry: " + card_id)
		_check(not CardShortRules.line(_definition(card_id)).contains("until"),
			"the face leaves the Thorns duration to Help: " + card_id)


func _test_unknown_and_malformed_fallbacks() -> void:
	var mystery := {"id": "card_short_rules_probe", "target_kind": "enemy_single",
		"effects": {"damage": 2, "mystery_damage": 9}}
	var original := mystery.duplicate(true)
	var line := CardShortRules.line(mystery)
	_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
		"an unknown effect keeps the honest fallback: " + line)
	_check(CardShortRules.has_unknown(mystery)
		and bool(CardShortRules.describe(mystery).get("unknown", false)),
		"an unknown effect is reported, not described")
	_check(not line.contains("9") and not line.contains("mystery"),
		"the fallback invents no amount and leaks no raw key")
	_check(mystery == original, "the in-memory probe is never mutated")
	# A malformed Pinned descriptor is an undescribed effect, never a keyword
	# with an invented bonus.
	var bad_pin := {"id": "card_short_rules_bad_pin", "target_kind": "enemy_single",
		"effects": {"damage": 2, "pinned": {}}}
	var bad_pin_line := CardShortRules.line(bad_pin)
	_check(bad_pin_line == "Deal 2. " + UNKNOWN_FALLBACK,
		"an empty Pinned descriptor falls back honestly: " + bad_pin_line)
	_check(not bad_pin_line.contains("Pin"),
		"no Pin keyword is printed for a descriptor it cannot read")
	var bad_thorns := {"id": "card_short_rules_bad_thorns", "target_kind": "self",
		"effects": {"block": 5, "thorns": "3"}}
	var bad_thorns_line := CardShortRules.line(bad_thorns)
	_check(bad_thorns_line == "Gain 5 Block. " + UNKNOWN_FALLBACK,
		"an unreadable Thorns amount falls back honestly: " + bad_thorns_line)
	_check(not bad_thorns_line.contains("Thorns"),
		"no Thorns amount is invented from a string")
	# No shipped record may be mutated by reading an unreadable probe.
	var draw_fire := _definition("warden_draw_fire")
	var draw_fire_before := draw_fire.duplicate(true)
	CardShortRules.line(bad_thorns)
	_check(draw_fire == draw_fire_before,
		"a malformed probe cannot alter a shipped record")
