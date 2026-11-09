extends SceneTree
## Owner 11-09: "the patches are things you can add on to the abilities, not abilities themselves".
## A live S14 corridor fight shows each hero's signature abilities on the bar, the ability patches
## sewn onto them as small badges named in the hover text, and a click fires use_ability.
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, why: String) -> void:
	checks += 1
	if not ok:
		failures.append(why)


func _run() -> void:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	_check(not config.is_empty(), "precondition: real starter party loads")
	if config.is_empty():
		_finish()
		return
	config["seed"] = 1109
	config["s14"] = true
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(config), "precondition: S14 battle starts")
	var battle := screen.battle
	for step in 64:
		if battle.get_heroes().any(func(h): return str(h.id) == battle.current_actor_id()):
			break
		battle.pass_turn()
	var actor_id := battle.current_actor_id()
	var actor: Dictionary = battle._units.get(actor_id, {})
	_check(str(actor.get("side", "")) == "hero" and not actor.get("abilities", []).is_empty(),
		"precondition: a hero with a signature kit acts")
	var by_id: Dictionary = StitchedS14Abilities.patches().get("by_id", {})
	var patch_id := str(by_id.keys()[0])
	var patch_name := str(by_id[patch_id].name)
	var socketed := ""
	for ability in actor.get("abilities", []):
		if screen.valid_slot(actor, str(ability.slot)):
			socketed = str(ability.id)
			break
	_check(not socketed.is_empty(), "precondition: the actor has a usable kit ability")
	battle._s14_sockets = {actor_id: {socketed: [patch_id]}}
	root.add_child(screen)
	await process_frame
	var fight := StitchedCorridorFight.attach(screen, "walls")
	await process_frame
	fight.refresh()
	for ability in actor.abilities:
		var button: TextureButton = fight.part_buttons.get(str(ability.slot))
		_check(button != null and button.tooltip_text.begins_with(str(ability.name)),
			"%s button names the kit ability %s" % [ability.slot, ability.name])
		var sewn: bool = str(ability.id) == socketed
		_check(button != null and button.tooltip_text.contains("Sewn on: " + patch_name) == sewn,
			"%s hover text lists only patches sewn onto it" % ability.slot)
		if sewn and ResourceLoader.exists(StitchedCorridorFight.SEWN_ART + patch_id + ".png"):
			_check((button.get_node("Sewn_0") as TextureRect).texture != null, "the sewn patch shows as a badge")
		_check(not button.tooltip_text.to_lower().contains("patch:"), "no ability is called a patch")
		var stand_in: Label = button.get_node("Slot") if button != null else null
		_check(stand_in != null and not stand_in.text in StitchedCorridorFight.SLOT_NAMES.values()
			and (not stand_in.visible or stand_in.text == str(ability.name)),
			"%s button never shows a body-part word; without a picture it shows the ability's name" % ability.slot)
	var slot :=screen.ability_slot(actor, socketed)
	var receipt := fight.choose_part(slot)
	if str(receipt.get("pending", "")) == slot:
		var targets := screen.legal_targets()
		var key: String = targets.keys()[0]
		receipt = fight.click_figure(key.get_slice("_", 0), int(key.get_slice("_", 1)))
	_check(bool(receipt.get("ok", false)) and str(receipt.get("ability", "")) == socketed,
		"clicking the kit ability fires use_ability (%s)" % str(receipt))
	_finish()


func _finish() -> void:
	if failures.is_empty():
		print("PASS stitched_s14_corridor_kit_bar_test (%d checks)" % checks)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL stitched_s14_corridor_kit_bar_test %d/%d" % [failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
