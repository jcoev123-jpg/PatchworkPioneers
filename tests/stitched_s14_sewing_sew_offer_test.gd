extends SceneTree
## Owner 11-09: "the patches are things you can add on to the abilities, not abilities themselves".
## A real Sewing Circle offers to sew each loose ability patch onto a living doll's signature
## abilities, and choosing it binds exactly that patch for SEWING_COST scraps.

const HERO := "warden"
const ABILITY := "warden_arms_shield_catch"

var failures: Array[String] = []
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	var greeting: String = StitchedRunSession.VISIT_GREETINGS["SewingCircle"]
	_check(greeting.contains("patches onto a doll's abilities") and not greeting.contains("Torn parts"),
		"Sewing Circle describes sewing patches onto fixed abilities, not mending obsolete body-part abilities")
	var preview := RunV3StopChoiceProjection.stitched_stop_help_for("SewingCircle")
	_check(str(preview.get("lead", "")).contains("sew found patches onto fixed abilities")
		and str(preview.get("detail", "")).contains("signature ability")
		and str(preview.get("detail", "")).contains("unsew")
		and not str(preview.get("detail", "")).contains("body-part abilities"),
		"the map preview explains the real ability-patch sewing service")
	var run := _enter()
	_check(run != null, "a real seeded Sewing Circle is entered")
	if run != null:
		_flow(run)
	for message in failures:
		printerr(message)
	print("stitched_s14_sewing_sew_offer_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _enter() -> StitchedRunSession:
	for seed_number in 200:
		var run := StitchedRunSession.start(seed_number)
		if run == null:
			continue
		for id in run.choices():
			if run.map.get_node(id).type == "SewingCircle" and run.enter(id, run.snapshot()):
				return run if run.phase == "visit" else null
	return null


func _sews(run: StitchedRunSession) -> Array:
	return run.visit_actions().filter(func(action: Dictionary) -> bool: return action.id == "sew")


func _flow(run: StitchedRunSession) -> void:
	_check(_sews(run).is_empty(), "no sew rows while no ability patch is owned")
	var wool: Dictionary = run._award_ability_patch("elite", "wool")
	run.scraps = 4
	run._open_visit("SewingCircle")
	run._seal()
	var rows := _sews(run)
	var living := run.heroes.filter(func(hero: Dictionary) -> bool: return not hero.lost).size()
	_check(rows.size() == living * 4, "one sew row per living doll's signature ability (%d)" % rows.size())
	var row: Array = rows.filter(func(action: Dictionary) -> bool: return action.arguments == [int(wool.uid), HERO, ABILITY])
	_check(row.size() == 1 and str(row[0].text).contains("Sew ") and str(row[0].text).contains(" onto ")
		and row[0].enabled, "the Warden's Shield Catch row reads 'Sew <patch> onto <ability>'")
	_check(StitchedCorridorVisit.group_of(row[0], [HERO])[1] == HERO if row.size() == 1 else false,
		"the corridor visit gives the patch to a doll from the portraits")
	_check(run.visit_actions().back().id == "leave", "Leave still closes the list")
	_check(run.choose_visit("sew", [int(wool.uid), HERO, ABILITY], run.snapshot()), "the sew choice is accepted")
	_check(run.ability_sockets.get(HERO, {}).get(ABILITY, []) == [int(wool.uid)], "the patch is sewn onto that ability")
	_check(run.scraps == 4 - StitchedRunSession.SEWING_COST, "sewing costs SEWING_COST scraps")
	_check(_sews(run).is_empty(), "a sewn patch is no longer offered")
	_check(run.visit_actions().any(func(action: Dictionary) -> bool: return action.id == "unsew"),
		"the sewn patch can be unsewn")
	var poor: Dictionary = run._award_ability_patch("elite", "cotton")
	run.scraps = 1
	run._open_visit("SewingCircle")
	run._seal()
	_check(_sews(run).all(func(action: Dictionary) -> bool: return not action.enabled), "sewing needs the scraps")
	_check(not run.choose_visit("sew", [int(poor.uid), HERO, "warden_head_pot_helm_command"], run.snapshot()),
		"a disabled sew is refused")

