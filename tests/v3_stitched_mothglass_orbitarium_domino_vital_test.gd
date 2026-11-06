extends SceneTree
## Authored data and real scene-free gate contract; no live-route claim.

const PATH := "res://data/events/v3_hero_vital_events.json"
const PARTY := ["lantern_monk", "scarecrow", "button_golem", "warden"]
const ANCHORS := ["v3_lantern_monk_thimble_moon_vigil", "v3_scarecrow_bone_chime_bellbridge", "v3_button_golem_starwheel_dumbwaiter"]
## Each choice row: id, exact text, independent deltas, independent funded result.
const SPECS := [
	{
		"id": "v3_lantern_monk_mothglass_projector", "hero": "lantern_monk",
		"title": "The Mothglass Shadow Projector",
		"description": "A house-high projector of smoky glass casts huge stitched moth shadows across plum curtains; the Lantern Monk lifts a warm pole lantern to steady its trembling bone-white lens.",
		"choices": [
			["steady_mothglass_lens", "Pay 14 gold to warm the shadow lens (heal 8 HP)", [-14, 0, 8, 0], [46, 6, 26, 30]],
			["gather_hot_glass_threads", "Salvage glowing mothglass thread (lose 5 HP; gain 2 scraps)", [0, 2, -5, 0], [60, 8, 13, 30]],
			["leave", "Let the moth shadows flutter behind the curtain", [0, 0, 0, 0], [60, 6, 18, 30]],
		],
	},
	{
		"id": "v3_scarecrow_straw_orbitarium", "hero": "scarecrow",
		"title": "The Straw-Orbitarium",
		"description": "A crooked toy planetarium spins on a pitchfork axle above black shingles; the Scarecrow's shoulder crow tugs loose a stitched star as a giant straw moon tilts toward the road.",
		"choices": [
			["stitch_straw_moon", "Spend 2 scraps to bind a lasting moon seam (+2 max HP)", [0, -2, 0, 2], [60, 4, 18, 32]],
			["pluck_orbit_wires", "Pull the sharp orbit wires (lose 6 HP; earn 25 gold)", [25, 0, -6, 0], [85, 6, 12, 30]],
			["leave", "Leave the straw moon turning in the dark", [0, 0, 0, 0], [60, 6, 18, 30]],
		],
	},
	{
		"id": "v3_button_golem_domino_threshold", "hero": "button_golem",
		"title": "The Domino Threshold",
		"description": "Bone-cream fabric dominoes tower over a narrow hallway; the Button Golem's broad brass-button fists brace the first piece while oxblood cross-stitches pull taut along the falling line.",
		"choices": [
			["bind_domino_brace", "Spend 2 scraps to stitch the button brace (heal 7 HP; gain 1 max HP)", [0, -2, 7, 1], [60, 4, 25, 31]],
			["pry_brass_button_pip", "Pry loose a brass button pip (lose 2 max HP; gain 27 gold)", [27, 0, 0, -2], [87, 6, 18, 28]],
			["leave", "Let the dominoes stand in uneasy silence", [0, 0, 0, 0], [60, 6, 18, 30]],
		],
	},
]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var source := FileAccess.get_file_as_string(PATH)
	var catalog: Variant = JSON.parse_string(source)
	_check(catalog is Dictionary and catalog.keys() == ["events"] and catalog.events is Array, "catalog root shape")
	if not catalog is Dictionary or not catalog.get("events") is Array:
		_finish()
		return
	var original: Dictionary = catalog.duplicate(true)
	for anchor: String in ANCHORS:
		_check(_records(catalog.events, anchor).size() == 1, "prior anchor: " + anchor)
	var gate := RunV3HeroVitalEventGate.new(PARTY)
	_check(gate.is_valid(), "real four-hero gate accepts shipped catalog")
	for spec: Dictionary in SPECS:
		var found := _records(catalog.events, spec.id)
		_check(found.size() == 1, "unique new event: " + spec.id)
		if found.size() != 1:
			continue
		_test_record(found[0], spec)
		_test_admission(gate, found[0], spec)
		_test_funded(gate, spec)
		_test_refusals(gate, spec, _snap(spec.hero, [0, 0, 1, 10]), [spec.choices[0][0], spec.choices[1][0]])
		_test_selection(gate, spec)
	_test_refusals(gate, SPECS[0], _snap("lantern_monk", [60, 6, 30, 30]), ["steady_mothglass_lens"])
	_check(catalog == original and FileAccess.get_file_as_string(PATH) == source, "catalog stays unchanged")
	_finish()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _finish() -> void:
	for failure: String in failures:
		printerr(failure)
	print("v3_stitched_mothglass_orbitarium_domino_vital_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _records(events: Array, id: String) -> Array:
	return events.filter(func(record: Variant) -> bool: return record is Dictionary and record.get("id") == id)


func _snap(hero: String, values: Array = [60, 6, 18, 30]) -> Dictionary:
	return {"gold": values[0], "scraps": values[1], "hero": {"id": hero, "hp": values[2], "max_hp": values[3]}}


func _entry(preview: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in preview.get("choices", []):
		if entry.get("choice_id") == id:
			return entry
	return {}


func _test_record(record: Dictionary, spec: Dictionary) -> void:
	_check(record.size() == 5 and record.get("id") == spec.id and record.get("title") == spec.title
		and record.get("description") == spec.description and record.get("required_hero") == spec.hero
		and record.get("choices") is Array, "exact authored event fields: " + spec.id)
	var choices: Array = record.get("choices", [])
	_check(choices.size() == 3, "three ordered choices: " + spec.id)
	var seen := {}
	for i: int in range(mini(choices.size(), 3)):
		var choice: Dictionary = choices[i]
		var row: Array = spec.choices[i]
		_check(choice.size() == 3 and choice.get("id") == row[0] and choice.get("text") == row[1]
			and choice.get("outcome") is Dictionary, "exact choice fields/order: " + row[0])
		_check(not seen.has(choice.get("id")), "unique choice: " + row[0])
		seen[choice.get("id")] = true
		var outcome: Dictionary = choice.get("outcome", {})
		_check(outcome.size() == 4, "four outcome keys: " + row[0])
		var keys := ["gold", "scraps", "hp", "max_hp"]
		for j: int in range(4):
			var value: Variant = outcome.get(keys[j])
			# Godot JSON parses integer tokens as whole-valued floats.
			_check((value is int or value is float) and is_finite(float(value))
				and float(value) == floor(float(value)) and value == row[2][j], "integer authored delta: " + row[0] + "/" + keys[j])


func _test_admission(gate: RunV3HeroVitalEventGate, record: Dictionary, spec: Dictionary) -> void:
	_check(_records(gate.get_offers(), spec.id) == [record], "authentic offer exactly once: " + spec.id)
	var base := _snap(spec.hero)
	var visit := gate.enter(record, base)
	_check(visit != null and visit.is_valid() and not visit.is_claimed(), "authentic record opens: " + spec.id)
	_check(gate.enter(spec.id, _snap(spec.hero, [60, 6, 0, 30])) == null, "zero HP refuses: " + spec.id)
	_check(gate.enter(spec.id, _snap("warden")) == null, "mismatched hero refuses: " + spec.id)
	var absent_party: Array = PARTY.duplicate()
	absent_party[absent_party.find(spec.hero)] = "tinker"
	var absent := RunV3HeroVitalEventGate.new(absent_party)
	_check(absent.is_valid() and _records(absent.get_offers(), spec.id).is_empty()
		and absent.enter(spec.id, base) == null, "absent required hero refuses: " + spec.id)
	var forged := record.duplicate(true)
	forged.title += " forged"
	_check(gate.enter(forged, base) == null and gate.enter("unknown_event", base) == null
		and not gate.is_claimed(), "forged/unknown event refuses without claim: " + spec.id)
	if visit != null:
		var detached := visit.get_event()
		detached.title = "changed"
		base.hero.hp = 1
		_check(visit.get_event() == record and visit.get_snapshot() == _snap(spec.hero), "bound inputs and getters detach")


func _test_funded(gate: RunV3HeroVitalEventGate, spec: Dictionary) -> void:
	for row: Array in spec.choices:
		var base := _snap(spec.hero)
		var original := base.duplicate(true)
		var visit := gate.enter(spec.id, base)
		_check(visit != null, "fresh funded visit: " + row[0])
		if visit == null:
			continue
		_check(visit.get_choice_service() is RunEventChoice, "real underlying choice service")
		var preview := visit.preview_vital_choices()
		var entry := _entry(preview, row[0])
		var expected := _snap(spec.hero, row[3])
		_check(preview.get("ok") == true and preview.get("event_id") == spec.id and preview.get("choices", []).size() == 3
			and entry == {"choice_id": row[0], "gold_delta": row[2][0], "scraps_delta": row[2][1],
			"hp_delta": row[2][2], "max_hp_delta": row[2][3], "affordable": true, "state": expected}, "independent preview: " + row[0])
		_check(not visit.choose_with_vitals("unknown_choice").get("ok", true) and visit.is_valid()
			and not visit.is_claimed() and visit.get_snapshot() == original, "unknown choice leaves visit intact")
		entry.get("state", {}).get("hero", {})["hp"] = 1
		_check(visit.get_snapshot() == original, "preview result detaches")
		var receipt := visit.choose_with_vitals(row[0])
		_check(receipt == {"ok": true, "event_id": spec.id, "choice_id": row[0], "state": expected}
			and visit.is_claimed() and visit.get_choice_service().is_claimed() and not visit.is_valid(), "independent receipt and latch: " + row[0])
		for alternate: Array in spec.choices:
			_check(not visit.choose_with_vitals(alternate[0]).get("ok", true)
				and visit.get_snapshot() == expected, "replay/alternate refuses: " + alternate[0])
		receipt.get("state", {}).get("hero", {})["hp"] = 1
		_check(visit.get_snapshot() == expected and base == original, "receipt and supplied snapshot detach")


func _test_refusals(gate: RunV3HeroVitalEventGate, spec: Dictionary, base: Dictionary, ids: Array) -> void:
	var original := base.duplicate(true)
	var visit := gate.enter(spec.id, base)
	_check(visit != null, "refusal visit opens: " + spec.id)
	if visit == null:
		return
	for id: String in ids:
		var preview := visit.preview_vital_choices()
		var entry := _entry(preview, id)
		_check(preview.get("ok") == true and entry.get("affordable") == false and entry.get("state") == original, "unaffordable preview: " + id)
		var denied := visit.choose_with_vitals(id)
		_check(denied.get("ok") == false and denied.get("state") == original and visit.get_snapshot() == original
			and visit.is_valid() and not visit.is_claimed() and not visit.get_choice_service().is_claimed() and base == original, "no spend or latch: " + id)
	_check(_entry(visit.preview_vital_choices(), "leave").get("affordable") == true, "Leave remains affordable")
	var leave := visit.choose_with_vitals("leave")
	_check(leave.get("ok") == true and leave.get("state") == original and visit.is_claimed() and base == original, "same visit free Leave")


func _test_selection(gate: RunV3HeroVitalEventGate, spec: Dictionary) -> void:
	var excluded: Array = []
	var exhausted: Array = []
	for offer: Dictionary in gate.get_offers():
		exhausted.append(offer.id)
		if offer.id != spec.id:
			excluded.append(offer.id)
	var heroes: Array = []
	for hero: String in PARTY:
		heroes.append({"id": hero, "hp": 18, "max_hp": 30})
	var wallet := {"gold": 60, "scraps": 6}
	var original := [wallet.duplicate(true), heroes.duplicate(true), excluded.duplicate()]
	var rng := RandomNumberGenerator.new()
	var oracle := RandomNumberGenerator.new()
	rng.seed = 556
	oracle.seed = 556
	oracle.randi_range(0, 0)
	var selected := gate.select_party_actionable_event(rng, excluded, wallet, heroes)
	_check(selected.get("ok") == true and selected.get("event", {}).get("id") == spec.id and rng.state == oracle.state, "isolated selection consumes one draw: " + spec.id)
	var replay := RandomNumberGenerator.new()
	replay.seed = 556
	_check(gate.select_party_actionable_event(replay, excluded, wallet, heroes) == selected and replay.state == rng.state, "seed replay")
	var before := rng.state
	_check(gate.select_party_actionable_event(rng, exhausted, wallet, heroes).get("ok") == false and rng.state == before, "exhausted consumes no RNG")
	_check([wallet, heroes, excluded] == original, "selector inputs unchanged")
	var selected_visit := gate.enter(selected.get("event"), _snap(spec.hero))
	_check(selected_visit != null and selected_visit.is_valid(), "selected authentic record admits")
