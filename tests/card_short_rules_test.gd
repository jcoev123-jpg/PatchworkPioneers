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
## stay honest instead of inventing mechanics. The six Rag Duelist variants are
## read from their real V3 pool; their status effects are printed, not resolved.

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
## The six exact short faces of the V3 Rag Duelist reward descriptors. Looked up
## by named ID only, so no catalog total or ordered ID list is asserted here.
const RAG_FACE_CASES := [
	{"id": "rag_duelist_cape_guard", "line": "Gain 5 Block. Gain 3 Riposte."},
	{"id": "rag_duelist_cape_guard_plus", "line": "Gain 7 Block. Gain 4 Riposte."},
	{"id": "rag_duelist_duelist_reprise", "line": "Gain 5 Riposte."},
	{"id": "rag_duelist_duelist_reprise_plus", "line": "Gain 7 Riposte."},
	{"id": "rag_duelist_tattered_snare", "line": "Tangled 2."},
	{"id": "rag_duelist_tattered_snare_plus", "line": "Tangled 3."},
]
## The seven keyword rows that existed before Riposte and Tangled were appended.
const LEGACY_KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel",
	"guarding", "thorns"]

var failures: Array[String] = []
var checks := 0
var warden := WardenPoolCards.new()
var tinker := TinkerPoolCards.new()
var rag_duelist := RagDuelistPoolCards.new()


func _initialize() -> void:
	seed(4517)
	var expected_global := randi()
	seed(4517)
	_test_shipped_faces()
	_test_authored_amounts()
	_test_help_keeps_full_mechanics()
	_test_unknown_and_malformed_fallbacks()
	_test_rag_duelist_faces()
	_test_rag_duelist_help()
	_test_rag_duelist_malformed()
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


## AC1: the six authored Rag Duelist descriptors print their exact terse face,
## read from the real V3 pool by named ID (never a catalog total or ID list).
## The record's own effects are checked first so the assertions cannot pass on
## an empty or unrelated definition.
func _test_rag_duelist_faces() -> void:
	for entry in RAG_FACE_CASES:
		var card_id := str(entry["id"])
		var expected_line := str(entry["line"])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Rag Duelist catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		var effects: Dictionary = definition.get("effects", {})
		var riposte := int(effects.get("riposte", effects.get("tangled", 0)))
		_check(riposte > 0 and (effects.get("riposte") is int or effects.get("tangled") is int),
			"authored positive Riposte/Tangled amount: " + card_id)
		if effects.has("riposte"):
			_check(effects.get("duration") is int and int(effects["duration"]) == 1,
				"authored Riposte duration is the one turn: " + card_id)
		var before := definition.duplicate(true)
		var described := CardShortRules.describe(definition)
		var line := str(described.get("line", ""))
		_check(described.get("known") == true, "face record is described: " + card_id)
		_check(not bool(described.get("unknown", true)),
			"face record is fully described, no fallback: " + card_id)
		_check(line == expected_line,
			"short face for %s: got '%s', want '%s'" % [card_id, line, expected_line])
		for word in HELP_ONLY_WORDS:
			_check(not line.contains(word),
				"face omits Help-only wording '%s': %s (%s)" % [word, card_id, line])
		_check(not line.to_lower().contains("turn"),
			"the face leaves the duration to Help: %s (%s)" % [card_id, line])
		_check(definition == before and rag_duelist.get_definition(card_id) == before,
			"formatting never mutates the shipped record: " + card_id)
		_check(CardShortRules.line(rag_duelist.get_definition(card_id)) == expected_line,
			"repeated formatting is identical: " + card_id)
	# The five other authored entries are not silently reinterpreted: the two that
	# only use understood keys keep a complete face, and the three with a key this
	# formatter cannot read still say so instead of hiding it.
	for card_id: String in ["rag_duelist_needle_prick", "rag_duelist_needle_prick_plus",
			"rag_duelist_velvet_feint", "rag_duelist_velvet_feint_plus"]:
		var line := CardShortRules.line(rag_duelist.get_definition(card_id))
		_check(not line.is_empty() and not line.contains(UNKNOWN_FALLBACK),
			"a fully understood Rag Duelist entry keeps a complete face: %s (%s)" % [card_id, line])
		_check(not line.contains("Riposte") and not line.contains("Tangled"),
			"no Riposte/Tangled is invented for %s (%s)" % [card_id, line])
	for card_id: String in ["rag_duelist_needle_lunge", "rag_duelist_needle_lunge_plus",
			"rag_duelist_cape_flourish", "rag_duelist_cape_flourish_plus",
			"rag_duelist_needle_barrage", "rag_duelist_needle_barrage_plus"]:
		var line := CardShortRules.line(rag_duelist.get_definition(card_id))
		_check(line.contains(UNKNOWN_FALLBACK),
			"an unsupported Rag Duelist key stays honestly undescribed: %s (%s)" % [card_id, line])
		_check(not line.contains("Riposte") and not line.contains("Tangled"),
			"an unsupported key never borrows Riposte/Tangled: %s (%s)" % [card_id, line])


## AC2: Help explains the authored positive amounts with the documented rules,
## in the fixed keyword order after the legacy seven rows, and stays truthful
## about the effects not being wired into combat yet.
func _test_rag_duelist_help() -> void:
	var legacy_size := LEGACY_KEYWORD_ORDER.size()
	_check(CardKeywordGlossary.KEYWORD_ORDER.slice(0, legacy_size) == LEGACY_KEYWORD_ORDER
		and CardKeywordGlossary.KEYWORD_ORDER.size() == legacy_size + 2
		and CardKeywordGlossary.KEYWORD_ORDER.slice(legacy_size) == ["riposte", "tangled"],
		"Riposte and Tangled follow the seven legacy keyword rows: "
		+ str(CardKeywordGlossary.KEYWORD_ORDER))
	for pair in [["rag_duelist_cape_guard", 3], ["rag_duelist_cape_guard_plus", 4],
			["rag_duelist_duelist_reprise", 5], ["rag_duelist_duelist_reprise_plus", 7]]:
		var card_id := str(pair[0])
		var amount := int(pair[1])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Riposte catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		_check(int(definition.get("effects", {}).get("riposte", -1)) == amount,
			"authored Riposte amount is %d: %s" % [amount, card_id])
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and str(rows[0].get("keyword", "")) == "Riposte %d" % amount,
			"exactly one Riposte %d Help row: %s" % [amount, card_id])
		if rows.size() == 1:
			var text := str(rows[0].get("explanation", ""))
			_check(text.contains("the Rag Duelist is hit"),
				"Help states the counterhit trigger: " + card_id)
			_check(text.contains("strikes back for %d damage" % amount),
				"Help repeats the authored counterhit damage: " + card_id)
			_check(text.contains("one turn"), "Help states the one-turn duration: " + card_id)
			_check(text.contains("combat does not yet apply Riposte"),
				"Help makes no live-play claim: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Help reads are identical: " + card_id)
		_check(definition == before and rag_duelist.get_definition(card_id) == before,
			"Help never mutates the catalog record: " + card_id)
		var detached := CardKeywordGlossary.describe(definition)
		if detached.size() == 1:
			detached[0]["keyword"] = "Tampered"
			detached[0]["explanation"] = "Tampered"
			var fresh := CardKeywordGlossary.describe(definition)
			_check(fresh.size() == 1 and str(fresh[0].get("keyword", "")) == "Riposte %d" % amount
				and definition == before,
				"Help rows are detached from the caller's record: " + card_id)
	for pair in [["rag_duelist_tattered_snare", 2], ["rag_duelist_tattered_snare_plus", 3]]:
		var card_id := str(pair[0])
		var turns := int(pair[1])
		var definition: Dictionary = rag_duelist.get_definition(card_id)
		_check(not definition.is_empty(), "Tangled catalog record exists: " + card_id)
		if definition.is_empty():
			continue
		_check(int(definition.get("effects", {}).get("tangled", -1)) == turns,
			"authored Tangled turns are %d: %s" % [turns, card_id])
		var before := definition.duplicate(true)
		var rows := CardKeywordGlossary.describe(definition)
		_check(rows.size() == 1 and str(rows[0].get("keyword", "")) == "Tangled %d" % turns,
			"exactly one Tangled %d Help row: %s" % [turns, card_id])
		if rows.size() == 1:
			var text := str(rows[0].get("explanation", ""))
			_check(text.contains("For %d turns" % turns),
				"Help repeats the authored Tangled turns: " + card_id)
			_check(text.contains("cannot move or be moved by its own side"),
				"Help states the movement restriction: " + card_id)
			_check(text.contains("attacks against it deal +2 damage"),
				"Help states the +2 attack vulnerability: " + card_id)
			_check(text.contains("combat does not yet apply Tangled"),
				"Help makes no live-play claim: " + card_id)
		_check(CardKeywordGlossary.describe(definition) == rows,
			"repeated Help reads are identical: " + card_id)
		_check(definition == before, "Help never mutates the catalog record: " + card_id)
	# A record that authors every legacy keyword plus the two new ones keeps every
	# legacy row first, in its established order, with the new rows last.
	var combined := {"id": "card_short_rules_order_probe", "target_kind": "enemy_single",
		"effects": {"tangled": 2, "thorns": 3, "riposte": 3, "duration": 1,
			"bleed": 1, "weak": 1, "exposed": 1, "pinned": true, "unravel": 2,
			"guarding": true}}
	var combined_before := combined.duplicate(true)
	var names: Array[String] = []
	for row: Dictionary in CardKeywordGlossary.describe(combined):
		names.append(str(row.get("keyword", "")))
	_check(names == ["Bleed 1", "Weak 1", "Exposed 1", "Pinned", "Unravel 2",
		"Guarding", "Thorns 3", "Riposte 3", "Tangled 2"],
		"legacy keyword rows keep their order and the new rows follow: " + str(names))
	_check(combined == combined_before, "the combined ordering probe is never mutated")


## AC3: malformed Riposte/Tangled amounts, a wrong Riposte duration and a truly
## unrecognized key never print an invented number and never fabricate Help.
func _test_rag_duelist_malformed() -> void:
	for value: Variant in [0, -3, "3", 3.5]:
		var probe := {"id": "card_short_rules_bad_riposte", "target_kind": "self",
			"effects": {"block": 5, "riposte": value, "duration": 1}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Gain 5 Block. " + UNKNOWN_FALLBACK,
			"a malformed Riposte %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Riposte"),
			"no Riposte keyword is invented for %s" % str(value))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Riposte Help row is invented for %s" % str(value))
		_check(probe == before, "the malformed Riposte probe is never mutated: " + str(value))
	var duration_probes := [
		["absent", "absent"], ["integer 2", 2], ["integer 0", 0], ["text", "1"],
		["float", 1.0],
	]
	for case in duration_probes:
		var effects := {"riposte": 3}
		if str(case[1]) != "absent":
			effects["duration"] = case[1]
		var probe := {"id": "card_short_rules_bad_riposte_duration",
			"target_kind": "self", "effects": effects}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == UNKNOWN_FALLBACK,
			"a Riposte with a %s duration falls back honestly: %s" % [str(case[0]), line])
		_check(not line.contains("Riposte"),
			"no Riposte keyword is printed for a %s duration" % str(case[0]))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Riposte Help row for a %s duration" % str(case[0]))
		_check(probe == before,
			"the %s duration probe is never mutated" % str(case[0]))
	for value: Variant in [0, -2, "2", 2.5]:
		var probe := {"id": "card_short_rules_bad_tangled", "target_kind": "enemy_single",
			"effects": {"damage": 2, "tangled": value}}
		var before := probe.duplicate(true)
		var line := CardShortRules.line(probe)
		_check(line == "Deal 2. " + UNKNOWN_FALLBACK,
			"a malformed Tangled %s falls back honestly: %s" % [str(value), line])
		_check(not line.contains("Tangled"),
			"no Tangled keyword is invented for %s" % str(value))
		_check(CardKeywordGlossary.describe(probe).is_empty(),
			"no Tangled Help row is invented for %s" % str(value))
		_check(probe == before, "the malformed Tangled probe is never mutated: " + str(value))
	# A valid Riposte beside a key this formatter cannot read prints the face
	# fallback and adds only the row it genuinely understands.
	var mystery := {"id": "card_short_rules_mystery_status", "target_kind": "self",
		"effects": {"block": 5, "riposte": 3, "duration": 1, "mystery_status": 9}}
	var mystery_before := mystery.duplicate(true)
	var mystery_line := CardShortRules.line(mystery)
	_check(mystery_line == "Gain 5 Block. Gain 3 Riposte. " + UNKNOWN_FALLBACK,
		"an unrecognized key keeps the established face fallback: " + mystery_line)
	_check(not mystery_line.contains("9"),
		"the unrecognized key's amount never leaks onto the face")
	var mystery_rows := CardKeywordGlossary.describe(mystery)
	_check(mystery_rows.size() == 1
		and str(mystery_rows[0].get("keyword", "")) == "Riposte 3",
		"an unrecognized key adds no fabricated Help row")
	_check(mystery == mystery_before, "the mystery-key probe is never mutated")
	var snare := rag_duelist.get_definition("rag_duelist_tattered_snare")
	var snare_before := snare.duplicate(true)
	CardShortRules.line(mystery)
	CardKeywordGlossary.describe(mystery)
	_check(not snare.is_empty() and snare == snare_before,
		"malformed probes cannot alter a shipped Rag Duelist record")

