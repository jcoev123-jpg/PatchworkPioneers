extends SceneTree
## Scene-free validation and detachment of all seven authored wardrobes.

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


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
	_check(not projected.is_empty(), "complete production projection validates")
	_check(projected == RunAuthoredPatchDefinitions.project_catalogs(catalogs)
		and projected == RunAuthoredPatchDefinitions.from_json_texts(texts),
		"disk, pure JSON and pure record entry points agree")
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
	}
	for id in required:
		var found: Array = projected.filter(func(entry): return entry.get("id") == id)
		_check(found.size() == 1 and found[0].get("slot") == required[id],
			"individual authored slot retained: " + id)
	for record in projected:
		_check(record is Dictionary and record.size() == 2
			and record.has("id") and record.has("slot"),
			"projection contains only detached id/slot fields")
	# In-place nested edits must not leak into fixture input or later reads.
	projected[0]["id"] = "corrupted"
	projected[0]["slot"] = "COAT"
	_check(catalogs == originals and RunAuthoredPatchDefinitions.load_definitions()
		== RunAuthoredPatchDefinitions.project_catalogs(originals),
		"projection mutations do not touch source records or future calls")
	var copy: Array = catalogs.duplicate(true)
	copy[3][0]["slot"] = "ARM"
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"known HEAD in wrong valid slot fails closed")
	copy = catalogs.duplicate(true)
	copy[4][0]["id"] = "bloodstitch_bonnet"
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"cross-catalog duplicate and removed known record fail closed")
	copy = catalogs.duplicate(true)
	copy[2][0]["slot"] = "SLEEVE"
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"unrecognized slot fails closed")
	copy = catalogs.duplicate(true)
	copy[5][0] = {"id": " ", "slot": "ARM"}
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"blank malformed ID fails closed")
	copy = catalogs.duplicate(true)
	copy[1].append({"id": "button_eye", "slot": "HEAD"})
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"duplicate within one catalog fails closed")
	copy = catalogs.duplicate(true)
	copy[6][0] = "not a record"
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"malformed record fails closed")
	copy = catalogs.duplicate(true)
	copy[0].pop_back()
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"missing required legacy record fails closed")
	copy = catalogs.duplicate(true)
	copy[4] = []
	_check(RunAuthoredPatchDefinitions.project_catalogs(copy).is_empty(),
		"empty source cannot return partially trusted projection")
	var bad_texts := texts.duplicate()
	bad_texts[3] = "[broken"
	_check(RunAuthoredPatchDefinitions.from_json_texts(bad_texts).is_empty(),
		"malformed JSON fails without partial output")
	bad_texts = texts.duplicate()
	bad_texts[4] = "{}"
	_check(RunAuthoredPatchDefinitions.from_json_texts(bad_texts).is_empty(),
		"valid non-array JSON fails closed")
	_check(catalogs == originals, "negative fixtures never altered original catalogs")
	for i in range(texts.size()):
		_check(FileAccess.get_file_as_string(RunAuthoredPatchDefinitions.CATALOG_PATHS[i])
			== texts[i], "unchanged original catalog resource: " + str(i))
	for error in failures:
		printerr(error)
	print("run_authored_patch_definitions_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
