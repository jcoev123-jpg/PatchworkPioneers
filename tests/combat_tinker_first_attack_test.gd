extends SceneTree

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_test_api_and_class()
	_test_fresh_preview_no_consume()
	_test_consume_once()
	_test_play_orders()
	_test_inert_and_unknown_ids()
	_test_failed_attempt_leaves_bonus()
	_test_repeated_commit()
	_test_turn_reset()
	_test_instance_isolation()
	_test_catalog_classification()
	for failure in failures:
		printerr(failure)
	print("combat_tinker_first_attack_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _eligible(card_id: String) -> bool:
	if card_id.is_empty():
		return false
	var catalog := StarterCards.new()
	var def: Dictionary = catalog.get_definition(card_id)
	if def.is_empty() or def.get("id") != card_id:
		return false
	if def.get("owner") != "tinker":
		return false
	var target_kind := str(def.get("target_kind", ""))
	if target_kind != "enemy_single" and target_kind != "enemy_all":
		return false
	var effects = def.get("effects")
	if not (effects is Dictionary):
		return false
	var damage = effects.get("damage")
	return (damage is int) and int(damage) >= 0


func _test_api_and_class() -> void:
	var helper := CombatTinkerFirstAttack.new()
	_check(helper is RefCounted, "helper extends RefCounted")
	_check(helper.has_method("start_player_turn"), "start_player_turn exists")
	_check(helper.has_method("bonus_for_attack"), "bonus_for_attack exists")
	_check(helper.has_method("record_successful_attack"), "record_successful_attack exists")
	_check(helper.bonus_for_attack("") == 0, "empty id previews 0")
	_check(not helper.record_successful_attack(""), "empty id commit returns false")


func _test_fresh_preview_no_consume() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	var catalog := StarterCards.new()
	for card_id in ["tinker_pop_shot", "tinker_scrap_bomb"]:
		_check(catalog.has_card(card_id), "catalog has " + card_id)
		var def: Dictionary = catalog.get_definition(card_id)
		_check(def.get("owner") == "tinker", card_id + " owner is tinker")
		for i in range(6):
			_check(helper.bonus_for_attack(card_id) == 3,
				card_id + " previews 3 on repeat " + str(i))
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3,
		"repeated previews do not consume pop shot")
	_check(helper.bonus_for_attack("tinker_scrap_bomb") == 3,
		"repeated previews do not consume scrap bomb")


func _test_consume_once() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3, "preview before commit")
	_check(helper.record_successful_attack("tinker_pop_shot"), "commit returns true")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 0, "after commit pop shot 0")
	_check(helper.bonus_for_attack("tinker_scrap_bomb") == 0, "after commit scrap bomb 0")
	_check(not helper.record_successful_attack("tinker_scrap_bomb"),
		"second commit returns false")


func _test_play_orders() -> void:
	# Other owners before Tinker must not consume the bonus.
	for other_id in ["warden_strike", "warden_shield_bash", "seamstress_prick"]:
		var helper := CombatTinkerFirstAttack.new()
		helper.start_player_turn()
		_check(not helper.record_successful_attack(other_id),
			other_id + " commit returns false")
		_check(helper.bonus_for_attack("tinker_pop_shot") == 3,
			other_id + " preceding Tinker does not consume")
		_check(helper.record_successful_attack("tinker_pop_shot"),
			"Tinker commit after " + other_id + " succeeds")
		_check(helper.bonus_for_attack("tinker_pop_shot") == 0,
			"bonus consumed after Tinker commit")

	# Tinker first, then other-owner commit attempts stay inert and bonus stays spent.
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	_check(helper.record_successful_attack("tinker_scrap_bomb"),
		"Tinker first commit succeeds")
	for other_id in ["warden_strike", "seamstress_prick"]:
		_check(not helper.record_successful_attack(other_id),
			other_id + " commit after Tinker returns false")
		_check(helper.bonus_for_attack("tinker_pop_shot") == 0,
			"bonus stays spent after other-owner attempt")


func _test_inert_and_unknown_ids() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	var inert_ids := ["tinker_tune_up", "warden_strike", "warden_brace",
		"warden_shield_bash", "seamstress_prick", "seamstress_mend",
		"seamstress_stitch_up", "unknown_card", ""]
	for card_id in inert_ids:
		_check(helper.bonus_for_attack(card_id) == 0,
			card_id + " is not an eligible attack preview")
		_check(not helper.record_successful_attack(card_id),
			card_id + " commit returns false")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3,
		"inert/unknown commits leave future Tinker bonus intact")


func _test_failed_attempt_leaves_bonus() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	# An unsuccessful play never calls record; bonus remains available.
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3, "before failed attempt")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3, "failed attempt does not consume")
	_check(helper.record_successful_attack("tinker_pop_shot"),
		"genuine later commit succeeds")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 0, "consumed after genuine commit")


func _test_repeated_commit() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	_check(helper.record_successful_attack("tinker_pop_shot"), "first commit true")
	_check(not helper.record_successful_attack("tinker_pop_shot"), "repeat same card false")
	_check(not helper.record_successful_attack("tinker_scrap_bomb"), "other Tinker attack after spend false")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 0, "bonus remains spent")
	_check(helper.bonus_for_attack("tinker_scrap_bomb") == 0, "bonus remains spent")


func _test_turn_reset() -> void:
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	_check(helper.record_successful_attack("tinker_pop_shot"), "consume bonus")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 0, "bonus spent before reset")
	helper.start_player_turn()
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3, "reset restores pop shot")
	_check(helper.bonus_for_attack("tinker_scrap_bomb") == 3, "reset restores scrap bomb")
	helper.start_player_turn()
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3, "repeated reset keeps bonus")


func _test_instance_isolation() -> void:
	var a := CombatTinkerFirstAttack.new()
	var b := CombatTinkerFirstAttack.new()
	a.start_player_turn()
	b.start_player_turn()
	_check(a.record_successful_attack("tinker_pop_shot"), "a commits")
	_check(a.bonus_for_attack("tinker_pop_shot") == 0, "a spent")
	_check(b.bonus_for_attack("tinker_pop_shot") == 3, "b unaffected")
	_check(b.record_successful_attack("tinker_scrap_bomb"), "b commits")
	_check(a.bonus_for_attack("tinker_scrap_bomb") == 0, "a still spent")
	_check(b.bonus_for_attack("tinker_pop_shot") == 0, "b spent")


func _test_catalog_classification() -> void:
	var catalog := StarterCards.new()
	var helper := CombatTinkerFirstAttack.new()
	helper.start_player_turn()
	# Preview every catalog card without mutating bonus state; eligible ones 3, others 0.
	for card_id in catalog.get_all_card_ids():
		var expected := 3 if _eligible(card_id) else 0
		_check(helper.bonus_for_attack(card_id) == expected,
			"catalog preview classification for " + card_id)
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3,
		"classification previews did not consume bonus")
	# Non-eligible commits are inert.
	for card_id in catalog.get_all_card_ids():
		if not _eligible(card_id):
			_check(not helper.record_successful_attack(card_id),
				"non-eligible commit returns false: " + card_id)
	_check(helper.bonus_for_attack("tinker_pop_shot") == 3,
		"non-eligible commits did not consume bonus")
	# A genuine eligible commit spends once.
	_check(helper.record_successful_attack("tinker_pop_shot"),
		"eligible commit succeeds")
	_check(helper.bonus_for_attack("tinker_pop_shot") == 0,
		"eligible commit spends bonus")