extends SceneTree
## D2-5 pure Tinker Path preflight/commit/turn-boundary tests.

var failures: Array[String] = []
var checks: int = 0


func _initialize() -> void:
	_test_invalid_and_wrong_owner()
	_test_sharpshot_sequence()
	_test_sharpshot_scope()
	_test_clockwork_discount()
	_test_wind_up()
	for failure in failures:
		printerr(failure)
	print("combat_tinker_path_rules_test: ", "PASS" if failures.is_empty() else "FAIL",
		" (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _quote(rules: CombatTinkerPathRules, card: String, pos: int = 3,
		hp: int = 26, energy: int = 3) -> Dictionary:
	return rules.preview(card, pos, hp, energy)


func _commit(rules: CombatTinkerPathRules, card: String, pos: int = 3,
		hp: int = 26, energy: int = 3, success: bool = true) -> Dictionary:
	return rules.commit_successful(card, pos, hp, energy, success)


func _test_invalid_and_wrong_owner() -> void:
	for id in ["", "other", "tinker_scope", "warden"]:
		var invalid := CombatTinkerPathRules.new(id)
		_check(not invalid.is_valid_path() and not invalid.start_player_turn(),
			"unknown path fails closed: " + id)
		_check(not _quote(invalid, "tinker_pop_shot").get("ok", false) and
			not _commit(invalid, "tinker_pop_shot").get("ok", false),
			"unknown path cannot project or commit")
		_check(invalid.take_next_turn_energy_bonus() == 0, "invalid path has no energy")
	for path in ["sharpshot", "clockwork"]:
		var rules := CombatTinkerPathRules.new(path)
		_check(rules.is_valid_path(), path + " is a valid selected Path")
		_check(not _quote(rules, "tinker_pop_shot").get("ok", false),
			"must open player turn before action")
		_check(rules.start_player_turn() and not rules.start_player_turn(),
			"turn opening idempotent")
		for card in ["warden_strike", "seamstress_prick", "warden_shield_bash",
				"seamstress_mend", "", "unknown", "tinker_wind_up"
				if path == "sharpshot" else "tinker_scope"]:
			_check(not _quote(rules, card).get("ok", false) and
				not _commit(rules, card).get("ok", false),
				path + " cannot affect other owners/unchosen Path/unknown: " + card)
		for pos in [0, 1, 4]:
			_check(not _quote(rules, "tinker_pop_shot", pos).get("ok", false)
				and not _commit(rules, "tinker_pop_shot", pos).get("ok", false),
				"illegal source position refused")
		for hp in [0, -2]:
			_check(not _quote(rules, "tinker_pop_shot", 3, hp).get("ok", false)
				and not _commit(rules, "tinker_pop_shot", 3, hp).get("ok", false),
				"downed Tinker refused")
		_check(not _quote(rules, "tinker_pop_shot", 3, 26, 0).get("ok", false),
			"insufficient energy cannot preview")
		_check(not _commit(rules, "tinker_pop_shot", 3, 26, 0).get("ok", false),
			"insufficient energy cannot commit")
		_check(rules.end_player_turn() and not rules.end_player_turn(),
			"turn closure idempotent")
		_check(not _commit(rules, "tinker_pop_shot").get("ok", false),
			"end-of-turn commit refused")


func _test_sharpshot_sequence() -> void:
	var rules := CombatTinkerPathRules.new("sharpshot")
	_check(rules.start_player_turn(), "Sharpshot turn opens")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
		"first attack preview +3")
	for n in range(3):
		_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
			"repeat preview never consumes bonus")
	_check(not _commit(rules, "tinker_pop_shot", 3, 26, 3, false).get("ok", false),
		"failed play never triggers bonus")
	_check(_quote(rules, "tinker_tune_up").get("ok", false) and
		_commit(rules, "tinker_tune_up").get("ok", false),
		"nonattack Tune Up playable")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
		"nonattack cannot consume first attack")
	var success: Dictionary = _commit(rules, "tinker_pop_shot")
	_check(success.get("ok") and success.get("damage_bonus") == 3 and
		success.get("cost") == 1 and success.get("discount") == 0,
		"first successful attack receives exactly +3 and native cost")
	_check(_quote(rules, "tinker_scrap_bomb").get("damage_bonus") == 0 and
		_commit(rules, "tinker_scrap_bomb").get("damage_bonus") == 0,
		"later multi-target attack gets no bonus")
	_check(_quote(rules, "tinker_long_barrel").get("damage_bonus") == 0,
		"pool attack also cannot duplicate bonus")
	_check(rules.end_player_turn() and rules.start_player_turn(), "next turn opened")
	_check(_quote(rules, "tinker_scrap_bomb").get("damage_bonus") == 3,
		"next player turn restores +3")
	_check(_commit(rules, "tinker_ricochet", 3, 26, 3).get("damage_bonus") == 3,
		"authored random-target Tinker damage attack consumes +3")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 0,
		"pool attack consumed shared first attack")


func _test_sharpshot_scope() -> void:
	var rules := CombatTinkerPathRules.new("sharpshot")
	rules.start_player_turn()
	for pos in [1, 2, 4]:
		_check(not _quote(rules, "tinker_scope", pos).get("ok", false) and
			not _commit(rules, "tinker_scope", pos).get("ok", false),
			"Scope legal only from 3")
	_check(not _commit(rules, "tinker_scope", 3, 0).get("ok", false),
		"downed hero cannot Scope")
	var pre: Dictionary = _quote(rules, "tinker_scope", 3, 26, 0)
	_check(pre.get("ok") and pre.get("cost") == 0 and
		pre.get("discount") == 0 and pre.get("arms_scope"),
		"Scope costs zero and needs no enemy target")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
		"Scope preview alone does not arm")
	_check(not _commit(rules, "tinker_scope", 3, 26, 0, false).get("ok", false)
		and _quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
		"failed Scope commit never arms")
	_check(_commit(rules, "tinker_scope", 3, 26, 0).get("ok", false),
		"successful Scope arms once")
	_check(_quote(rules, "tinker_tune_up").get("damage_bonus") == 0,
		"nonattack doesn't receive Scope")
	_check(_commit(rules, "tinker_tune_up").get("ok", false),
		"nonattack doesn't use Scope")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 7 and
		_quote(rules, "tinker_pop_shot").get("sharpshot_bonus") == 3 and
		_quote(rules, "tinker_pop_shot").get("scope_bonus") == 4,
		"Scope +4 and Sharpshot +3 stack on first attack")
	_check(not _commit(rules, "tinker_pop_shot", 3, 26, 0).get("ok", false),
		"insufficient-energy attack cannot consume Scope")
	_check(not _commit(rules, "tinker_pop_shot", 3, 26, 3, false).get("ok", false)
		and _quote(rules, "tinker_scrap_bomb").get("damage_bonus") == 7,
		"external failed attack preserves both boosts")
	_check(_commit(rules, "tinker_scrap_bomb").get("damage_bonus") == 7,
		"first successful attack consumes both and applies +7 once")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 0,
		"Scope boost and first attack exhausted")
	_check(_commit(rules, "tinker_scope", 3, 26, 0).get("ok", false)
		and _quote(rules, "tinker_long_barrel").get("damage_bonus") == 4,
		"later Scope arms +4 after first-attack passive spent")
	_check(_commit(rules, "tinker_long_barrel").get("damage_bonus") == 4 and
		_quote(rules, "tinker_pop_shot").get("damage_bonus") == 0,
		"later Scope consumed only once")
	_check(_commit(rules, "tinker_scope", 3, 26, 0).get("ok", false),
		"unused end-of-turn Scope can arm")
	_check(rules.end_player_turn() and rules.start_player_turn(),
		"next turn clears pending Scope")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 3,
		"unused Scope expired at prior turn end")


func _test_clockwork_discount() -> void:
	var rules := CombatTinkerPathRules.new("clockwork")
	rules.start_player_turn()
	_check(_quote(rules, "tinker_tune_up", 3, 26, 0).get("cost") == 0 and
		_quote(rules, "tinker_tune_up").get("discount") == 0,
		"printed cost 0 stays zero")
	_check(_commit(rules, "tinker_tune_up", 3, 26, 0).get("ok", false),
		"zero-cost Tinker card commits")
	_check(_quote(rules, "tinker_pop_shot", 2).get("cost") == 1 and
		_commit(rules, "tinker_pop_shot", 2).get("discount") == 0,
		"printed cost 1 never spends Clockwork trigger")
	_check(_quote(rules, "tinker_pop_shot").get("damage_bonus") == 0,
		"Clockwork never gives Sharpshot +3")
	_check(_quote(rules, "tinker_scrap_bomb", 3, 26, 1).get("cost") == 1 and
		_quote(rules, "tinker_scrap_bomb").get("printed_cost") == 2 and
		_quote(rules, "tinker_scrap_bomb").get("discount") == 1,
		"printed cost 2 previews as 1, even with only 1 energy")
	_check(not _commit(rules, "tinker_scrap_bomb", 3, 26, 1, false).get("ok", false),
		"failed discounted attempt must not spend discount")
	_check(_quote(rules, "tinker_bobbin_cannon", 3, 26, 2).get("cost") == 2,
		"printed cost 3 previews as 2 before discount spent")
	_check(not _commit(rules, "tinker_bobbin_cannon", 3, 26, 1).get("ok", false),
		"insufficient discounted cost rejects without consuming")
	_check(_quote(rules, "tinker_scrap_bomb", 3, 26, 1).get("discount") == 1,
		"failed expensive commit preserves discount")
	_check(_commit(rules, "tinker_scrap_bomb", 3, 26, 1).get("discount") == 1,
		"first expensive successful Tinker card claims discount")
	_check(_quote(rules, "tinker_long_barrel", 3, 26, 2).get("cost") == 2 and
		_quote(rules, "tinker_long_barrel", 3, 26, 2).get("discount") == 0,
		"subsequent printed-cost-2 card full price")
	_check(_quote(rules, "tinker_bobbin_cannon", 3, 26, 2).get("ok") == false,
		"subsequent printed cost 3 no longer affordable with 2")
	_check(_quote(rules, "tinker_bobbin_cannon", 3, 26, 3).get("cost") == 3,
		"subsequent printed cost 3 stays 3")
	_check(rules.end_player_turn() and rules.start_player_turn(),
		"Clockwork resets on next player turn")
	_check(_quote(rules, "tinker_bobbin_cannon", 3, 26, 2).get("discount") == 1 and
		_commit(rules, "tinker_bobbin_cannon", 3, 26, 2).get("cost") == 2,
		"printed cost 3 card gets new turn discount")
	_check(_quote(rules, "tinker_scrap_bomb", 3, 26, 2).get("discount") == 0,
		"second expensive play doesn't double discount")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"Clockwork cost passive creates no free energy")
	_check(_quote(rules, "tinker_scope").get("ok") == false,
		"Clockwork never accesses Sharpshot's Path card")


func _test_wind_up() -> void:
	var rules := CombatTinkerPathRules.new("clockwork")
	rules.start_player_turn()
	_check(rules.take_next_turn_energy_bonus() == 0, "no initial energy credit")
	for pos in [1, 0, 4]:
		_check(not _quote(rules, "tinker_wind_up", pos).get("ok", false)
			and not _commit(rules, "tinker_wind_up", pos).get("ok", false),
			"Wind-up rejects wrong position")
	_check(not _commit(rules, "tinker_wind_up", 2, 0).get("ok", false),
		"Wind-up rejects downed Tinker")
	_check(not _quote(rules, "tinker_wind_up", 2, 26, 0).get("ok", false)
		and not _commit(rules, "tinker_wind_up", 2, 26, 0).get("ok", false),
		"Wind-up cannot spend insufficient energy")
	_check(not _commit(rules, "tinker_wind_up", 2, 26, 1, false).get("ok", false),
		"failed Wind-up does not queue energy")
	_check(_quote(rules, "tinker_wind_up", 2, 26, 1).get("cost") == 1 and
		_quote(rules, "tinker_wind_up", 3, 26, 1).get("next_turn_energy") == 1,
		"Wind-up legal both 2 and 3, costs 1, queues one next turn")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"previews/failed attempts do not create current-turn energy")
	_check(_commit(rules, "tinker_wind_up", 2, 26, 1).get("next_turn_energy") == 1,
		"successful Wind-up from position 2 schedules exactly one")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"pending Wind-up cannot be claimed immediately")
	_check(not rules.start_player_turn(), "duplicate start cannot accelerate Wind-up")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"duplicate start still cannot pay Wind-up")
	_check(rules.end_player_turn(), "Wind-up player turn ends")
	_check(rules.take_next_turn_energy_bonus() == 0,
		"credit not claimable between player turns")
	_check(rules.start_player_turn(), "next player turn starts")
	_check(rules.take_next_turn_energy_bonus() == 1 and
		rules.take_next_turn_energy_bonus() == 0,
		"next-turn Wind-up bonus credited exactly once")
	_check(_commit(rules, "tinker_wind_up", 3, 26, 1).get("ok", false),
		"Wind-up can be replayed on a subsequent turn at position 3")
	rules.end_player_turn()
	rules.start_player_turn()
	_check(rules.take_next_turn_energy_bonus() == 1 and
		rules.take_next_turn_energy_bonus() == 0,
		"subsequent successful Wind-up credits following turn only")
	rules.end_player_turn()
	rules.start_player_turn()
	_check(rules.take_next_turn_energy_bonus() == 0,
		"credit never repeats on a later turn")
