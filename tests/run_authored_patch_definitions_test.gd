extends SceneTree
## Scene-free validation and detachment of all eight authored wardrobes, plus
## the power-only subset reserved for future Shop and Elite stock.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _entries_for(records: Array, id: String) -> Array:
	return records.filter(func(entry): return entry is Dictionary and entry.get("id") == id)


func _has_one(records: Array, id: String, slot: String) -> bool:
	var found := _entries_for(records, id)
	return found.size() == 1 and found[0].get("slot") == slot


## Every negative fixture must fail closed on BOTH projections: the power-only
## accessor may not skip validating a catalog whose entries it later excludes.
func _rejected_everywhere(catalogs: Variant, label: String) -> void:
	_check(RunAuthoredPatchDefinitions.project_catalogs(catalogs).is_empty(),
		label + " (full projection fails closed)")
	_check(RunAuthoredPatchDefinitions.project_power_catalogs(catalogs).is_empty(),
		label + " (power candidates fail closed)")


func _run() -> void:
	var texts: Array = []
	var catalogs: Array = []
	for path in RunAuthoredPatchDefinitions.CATALOG_PATHS:
		var raw := FileAccess.get_file_as_string(path)
		_check(not raw.is_empty(), "shipped source exists: " + path)
		texts.append(raw)
		catalogs.append(JSON.parse_string(raw))
	var originals := catalogs.duplicate(true)
	var projected: Array = RunAuthoredPatchDefinitions.load_definitions()
	var power: Array = RunAuthoredPatchDefinitions.load_power_definitions()
	_check(not projected.is_empty(), "complete production projection validates")
	_check(not power.is_empty(), "power-only production projection validates")
	_check(projected == RunAuthoredPatchDefinitions.project_catalogs(catalogs)
		and projected == RunAuthoredPatchDefinitions.from_json_texts(texts),
		"disk, pure JSON and pure record entry points agree")
	_check(power == RunAuthoredPatchDefinitions.project_power_catalogs(catalogs)
		and power == RunAuthoredPatchDefinitions.power_definitions_from_json_texts(texts),
		"disk, pure JSON and pure record power entry points agree")
	_check(power == RunAuthoredPatchDefinitions.load_power_definitions(),
		"repeated power-only production calls are deterministic")

	# Full projection: every authored record, inert starter slots included.
	var required := {
		"stitched_badge": "HEAD", "spare_spool": "ARM",
		"button_eye": "HEAD", "switchback_button": "HEAD",
		"bloodstitch_bonnet": "HEAD", "button_glass_visor": "HEAD",
		"stern_seam_cap": "HEAD", "reinforced_browband": "HEAD",
		"pincushion_arm": "ARM", "hemguard_cuff": "ARM",
		"red_bobbin_cuff": "ARM", "loose_thread_glove": "ARM",
		"threadguard_wrap": "ARM", "frayfinder_mitt": "ARM",
		"quilted_coat": "COAT", "padded_vest": "COAT",
		"double_quilt_coat": "COAT", "scrap_lined_vest": "COAT",
		"wool_patch_cloak": "COAT", "chain_stitched_coat": "COAT",
		"reinforced_patchcoat": "COAT", "thick_felt_mantle": "COAT",
		"borrowed_button": "COAT",
		"relay_bobbin": "HEAD", "hearth_lining": "COAT",
	}
	for id in required:
		_check(_has_one(projected, id, required[id]),
			"individual authored slot retained: " + id)

	# Power-only projection: exactly the real wearer powers, never the inert
	# starter slots. Checked per ID, never by total or order.
	var inert := {"stitched_badge": "HEAD", "spare_spool": "ARM"}
	var power_required := {
		"button_eye": "HEAD", "switchback_button": "HEAD",
		"bloodstitch_bonnet": "HEAD", "button_glass_visor": "HEAD",
		"stern_seam_cap": "HEAD", "reinforced_browband": "HEAD",
		"pincushion_arm": "ARM", "hemguard_cuff": "ARM",
		"red_bobbin_cuff": "ARM", "loose_thread_glove": "ARM",
		"threadguard_wrap": "ARM", "frayfinder_mitt": "ARM",
		"quilted_coat": "COAT", "padded_vest": "COAT",
		"double_quilt_coat": "COAT", "scrap_lined_vest": "COAT",
		"wool_patch_cloak": "COAT", "chain_stitched_coat": "COAT",
		"reinforced_patchcoat": "COAT", "thick_felt_mantle": "COAT",
		"borrowed_button": "COAT",
		"relay_bobbin": "HEAD", "hearth_lining": "COAT",
	}
	for id in power_required:
		_check(_has_one(power, id, power_required[id]),
			"power-only authored slot retained: " + id)
	for id in inert:
		_check(_has_one(projected, id, inert[id]),
			"full projection still keeps inert starter slot: " + id)
		_check(_entries_for(power, id).is_empty(),
			"power-only candidates exclude inert starter slot: " + id)
	# No initial-catalog record leaks into power candidates, even when authored
	# later, and every power candidate also belongs to the full projection.
	var initial_ids := {}
	for record in catalogs[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX]:
		if record is Dictionary:
			initial_ids[record.get("id")] = true
	for record in power:
		_check(not initial_ids.has(record.get("id")),
			"no initial-catalog entry in power candidates: " + str(record.get("id")))
		_check(_has_one(projected, record.get("id"), record.get("slot")),
			"every power candidate is also in the full projection: " + str(record.get("id")))

	for record in projected:
		_check(record is Dictionary and record.size() == 2
			and record.has("id") and record.has("slot"),
			"projection contains only detached id/slot fields")
	for record in power:
		_check(record is Dictionary and record.size() == 2
			and record.has("id") and record.has("slot"),
			"power candidates contain only detached id/slot fields")

	# AC2: one newly authored real power is admitted, one newly authored
	# initial-catalog starter slot stays inert, and both remain in the full
	# projection. No exact list size or order is asserted.
	var fixture := catalogs.duplicate(true)
	fixture[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX].append(
		{"id": "fixture_inert_starter", "slot": "HEAD"})
	fixture[3].append({"id": "fixture_real_power", "slot": "HEAD"})
	var fixture_full := RunAuthoredPatchDefinitions.project_catalogs(fixture)
	var fixture_power := RunAuthoredPatchDefinitions.project_power_catalogs(fixture)
	_check(_has_one(fixture_full, "fixture_real_power", "HEAD"),
		"appended real power retained in the full projection")
	_check(_has_one(fixture_full, "fixture_inert_starter", "HEAD"),
		"appended starter slot retained in the full projection")
	_check(_has_one(fixture_power, "fixture_real_power", "HEAD"),
		"appended real power admitted to power candidates")
	_check(_entries_for(fixture_power, "fixture_inert_starter").is_empty(),
		"appended starter slot excluded from power candidates")
	_check(fixture_power == RunAuthoredPatchDefinitions.project_power_catalogs(fixture),
		"appended-fixture power candidates are deterministic")
	var fixture_texts: Array = []
	for entries in fixture:
		fixture_texts.append(JSON.stringify(entries))
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(fixture_texts)
		== fixture_power, "pure JSON power entry agrees on the appended fixture")

	# In-place nested edits must not leak into fixture input or later reads.
	projected[0]["id"] = "corrupted"
	projected[0]["slot"] = "COAT"
	_check(catalogs == originals and RunAuthoredPatchDefinitions.load_definitions()
		== RunAuthoredPatchDefinitions.project_catalogs(originals),
		"projection mutations do not touch source records or future calls")
	power[0]["id"] = "corrupted_power"
	power[0]["slot"] = "COAT"
	_check(catalogs == originals and RunAuthoredPatchDefinitions.load_power_definitions()
		== RunAuthoredPatchDefinitions.project_power_catalogs(originals),
		"power projection mutations do not touch source records or future calls")
	var power_again: Array = RunAuthoredPatchDefinitions.load_power_definitions()
	_check(power_again == RunAuthoredPatchDefinitions.project_power_catalogs(originals),
		"repeated power-only calls return an independent clean copy")
	power_again[0]["slot"] = "COAT"
	_check(RunAuthoredPatchDefinitions.load_power_definitions()
		== RunAuthoredPatchDefinitions.project_power_catalogs(originals),
		"mutating one power result never changes a later call")

	var copy: Array = catalogs.duplicate(true)
	copy[3][0]["slot"] = "ARM"
	_rejected_everywhere(copy, "known HEAD in wrong valid slot fails closed")
	copy = catalogs.duplicate(true)
	copy[4][0]["id"] = "bloodstitch_bonnet"
	_rejected_everywhere(copy, "cross-catalog duplicate and removed known record fail closed")
	copy = catalogs.duplicate(true)
	copy[2][0]["slot"] = "SLEEVE"
	_rejected_everywhere(copy, "unrecognized slot fails closed")
	copy = catalogs.duplicate(true)
	copy[5][0] = {"id": " ", "slot": "ARM"}
	_rejected_everywhere(copy, "blank malformed ID fails closed")
	copy = catalogs.duplicate(true)
	copy[1].append({"id": "button_eye", "slot": "HEAD"})
	_rejected_everywhere(copy, "duplicate within one catalog fails closed")
	copy = catalogs.duplicate(true)
	copy[6][0] = "not a record"
	_rejected_everywhere(copy, "malformed record fails closed")
	copy = catalogs.duplicate(true)
	copy[0].pop_back()
	_rejected_everywhere(copy, "missing required legacy record fails closed")
	copy = catalogs.duplicate(true)
	copy[4] = []
	_rejected_everywhere(copy, "empty source cannot return partially trusted projection")
	# Appended initial entries are validated before they are excluded, so a
	# malformed or duplicate starter still invalidates all power candidates.
	copy = catalogs.duplicate(true)
	copy[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX].append(
		{"id": "fixture_bad_starter", "slot": "SLEEVE"})
	_rejected_everywhere(copy, "appended malformed starter slot fails closed")
	copy = catalogs.duplicate(true)
	copy[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX].append(
		{"id": "stitched_badge", "slot": "HEAD"})
	_rejected_everywhere(copy, "appended duplicate starter fails closed")
	copy = catalogs.duplicate(true)
	copy[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX] = []
	_rejected_everywhere(copy, "empty starter catalog fails closed")
	copy = catalogs.duplicate(true)
	copy[5][0]["id"] = "stitched_badge"
	_rejected_everywhere(copy, "starter record duplicated into a power catalog fails closed")

	# P8 negative fixtures: missing, malformed, duplicate, wrong-slot.
	copy = catalogs.duplicate(true)
	copy[7] = []
	_rejected_everywhere(copy, "empty P8 catalog fails closed")
	copy = catalogs.duplicate(true)
	copy[7] = [{"id": "relay_bobbin", "slot": "COAT"}]
	_rejected_everywhere(copy, "P8 wrong slot for relay_bobbin fails closed")
	copy = catalogs.duplicate(true)
	copy[7] = [{"id": "hearth_lining", "slot": "HEAD"}]
	_rejected_everywhere(copy, "P8 wrong slot for hearth_lining fails closed")
	copy = catalogs.duplicate(true)
	copy[7].append({"id": "relay_bobbin", "slot": "HEAD"})
	_rejected_everywhere(copy, "P8 duplicate relay_bobbin fails closed")
	var bad_p8_texts := texts.duplicate()
	bad_p8_texts[7] = "[broken"
	_check(RunAuthoredPatchDefinitions.from_json_texts(bad_p8_texts).is_empty(),
		"malformed P8 JSON fails without partial output")
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_p8_texts).is_empty(),
		"malformed P8 JSON fails without partial power candidates")

	var bad_texts := texts.duplicate()
	bad_texts[3] = "[broken"
	_check(RunAuthoredPatchDefinitions.from_json_texts(bad_texts).is_empty(),
		"malformed JSON fails without partial output")
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_texts).is_empty(),
		"malformed JSON fails without partial power candidates")
	bad_texts = texts.duplicate()
	bad_texts[4] = "{}"
	_check(RunAuthoredPatchDefinitions.from_json_texts(bad_texts).is_empty(),
		"valid non-array JSON fails closed")
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_texts).is_empty(),
		"valid non-array JSON fails without partial power candidates")
	bad_texts = texts.duplicate()
	bad_texts[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX] = "[broken"
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_texts).is_empty(),
		"malformed starter JSON fails without partial power candidates")
	bad_texts = texts.duplicate()
	bad_texts[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX] = "{}"
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_texts).is_empty(),
		"non-array starter JSON fails without partial power candidates")
	bad_texts = texts.duplicate()
	bad_texts[RunAuthoredPatchDefinitions.INITIAL_CATALOG_INDEX] = "[]"
	_check(RunAuthoredPatchDefinitions.power_definitions_from_json_texts(bad_texts).is_empty(),
		"empty starter JSON fails without partial power candidates")
	_check(catalogs == originals, "negative fixtures never altered original catalogs")
	for i in range(texts.size()):
		_check(FileAccess.get_file_as_string(RunAuthoredPatchDefinitions.CATALOG_PATHS[i])
			== texts[i], "unchanged original catalog resource: " + str(i))
	for error in failures:
		printerr(error)
	print("run_authored_patch_definitions_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
