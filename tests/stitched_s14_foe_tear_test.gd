extends SceneTree
## Playtest 11-09: the boss's Behemoth Maul ("tear") ripped the head off a 38-HP Warden on turn one and
## the doll vanished. Owner 11-08: in S14 limbs come off only at 0 HP, so a foe's tear above it opens a
## bleeding seam instead; at 0 HP the death-door hit alone decides the limb. Card fights keep the old tear.
var failures: Array[String] = []
var checks := 0


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _battle(seed_number: int, s14: bool) -> StitchedRules:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	config["seed"] = seed_number
	config["s14"] = s14
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "precondition: a seeded battle builds")
	return built.battle


func _foe(battle: StitchedRules) -> Dictionary:
	for id in battle._units:
		if str(battle._units[id].side) == "foe":
			return battle._units[id]
	return {}


func _torn(hero: Dictionary) -> Array:
	var torn: Array = []
	for slot in hero.parts:
		if bool(hero.parts[slot].torn):
			torn.append(slot)
	return torn


func _initialize() -> void:
	var maul := {"effects": {"tear": 1}}
	for seed_number in 30:
		var battle := _battle(seed_number, true)
		if battle == null:
			break
		var hero: Dictionary = battle._units["warden"]
		var receipt := {"statuses": []}
		battle._apply_effects(_foe(battle), hero, maul, receipt)
		_check(not hero.lost and _torn(hero).is_empty() and not receipt.has("tear"),
			"seed %d: a tear on a doll above 0 HP never takes a limb or the head" % seed_number)
		_check(int(hero.statuses.get("bleed", 0)) == 2 and receipt.statuses.any(func(s): return s.status == "bleed"),
			"seed %d: the torn seam bleeds instead" % seed_number)

	var hanging := _battle(5, true)
	if hanging != null:
		var hero: Dictionary = hanging._units["warden"]
		hero.hp = 0
		hero.hanging = true
		var receipt := {"statuses": []}
		hanging._apply_effects(_foe(hanging), hero, maul, receipt)
		_check(_torn(hero).is_empty() and not hero.lost and not receipt.has("tear"),
			"at 0 HP the tear adds no second limb on top of the death-door hit")

	var cards := _battle(5, false)
	if cards != null:
		var receipt := {"statuses": []}
		cards._apply_effects(_foe(cards), cards._units["warden"], maul, receipt)
		_check(bool(receipt.get("tear", {}).get("ok", false)), "card fights keep the old part tear")

	for failure in failures:
		printerr("FAIL: ", failure)
	print("stitched_s14_foe_tear_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
