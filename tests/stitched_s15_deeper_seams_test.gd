extends SceneTree
## S15 Deeper Seams: foe resistances that sewn patch rarity pierces (gold always
## lands), the mildew Rot status, floor-depth foe scaling with a softer boss,
## and the text-only cues (tooltip RESIST line, history "resisted" suffix).

var failures: Array[String] = []
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_resist_rolls()
	_resisted_status_never_attaches()
	_rot_ticks_and_heals()
	_catalog_resists()
	_real_foe_pierce_and_wren()
	_cues()
	_mildew_patch()
	_depth_scaling()
	for message in failures:
		printerr(message)
	print("stitched_s15_deeper_seams_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _battle(seed_number: int) -> StitchedRules:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	config["seed"] = seed_number
	config["s14"] = true
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "the starter party and foes construct a seeded battle")
	return built.battle


func _first(battle: StitchedRules, side: String) -> Dictionary:
	for id in battle._units:
		var unit: Dictionary = battle._units[id]
		if str(unit.get("side", "")) == side:
			return unit
	return {}


func _receipt() -> Dictionary:
	return {"statuses": []}


func _resist_rolls() -> void:
	var battle := _battle(15)
	if battle == null:
		return
	var hero := _first(battle, "hero")
	var foe := _first(battle, "foe")
	_check(not hero.is_empty() and not foe.is_empty(), "the battle holds a doll and a foe")
	foe["resist"] = {"stun": 90, "debuff": 90, "move": 90, "rot": 30}
	var state := battle._rng.state
	_check(not battle._resisted(hero, foe, "bleed", {}, _receipt()) and battle._rng.state == state,
		"an effect the foe has no resist for lands without spending a draw")
	_check(not battle._resisted(hero, foe, "stun", {"pierce": 100}, _receipt()) and battle._rng.state == state,
		"a gold patch (pierce 100) always lands without spending a draw")
	_check(not battle._resisted(hero, foe, "rot", {"pierce": 30}, _receipt()) and battle._rng.state == state,
		"silk pierce 30 cancels a 30 resist outright")
	_check(not battle._resisted(foe, hero, "stun", {}, _receipt()) and battle._rng.state == state,
		"foe attacks on dolls never roll a resist")
	_check(not battle._resisted(hero, foe, "heal", {}, _receipt())
		and not battle._resisted(hero, foe, "guard", {}, _receipt()) and battle._rng.state == state,
		"heal and guard are never resisted")
	for key in ["stun", "mark", "blind", "weak", "exposed", "tangled", "push", "pull"]:
		var resisted := 0
		var honest := true
		for attempt in 60:
			var receipt := _receipt()
			if battle._resisted(hero, foe, key, {}, receipt):
				resisted += 1
				var entry: Dictionary = receipt.statuses[0]
				honest = honest and entry.status == key and bool(entry.resisted) \
					and int(entry.roll) <= 90 and int(entry.resist) == 90
			else:
				honest = honest and receipt.statuses.is_empty()
		_check(resisted >= 40 and resisted < 60 and honest,
			"a 90 resist shrugs off most %s attempts and records each honest roll" % key)
	var wool := 0
	for attempt in 200:
		if battle._resisted(hero, foe, "stun", {"pierce": 15}, _receipt()):
			wool += 1
	_check(wool > 120 and wool < 185, "wool pierce 15 lowers a 90 stun resist to about 75")


func _resisted_status_never_attaches() -> void:
	var landed := false
	var refused := false
	for seed_number in range(1, 40):
		var battle := _battle(seed_number)
		if battle == null:
			return
		var hero := _first(battle, "hero")
		var foe := _first(battle, "foe")
		foe["resist"] = {"stun": 50}
		foe.statuses.erase("stun")
		var receipt := _receipt()
		battle._apply_effects(hero, foe, {"effects": {"stun": 1}}, receipt)
		var stunned := int(foe.statuses.get("stun", 0)) > 0
		var entry: Dictionary = receipt.statuses[0] if not receipt.statuses.is_empty() else {}
		if bool(entry.get("resisted", false)):
			refused = refused or not stunned
			_check(not stunned, "a resisted stun never attaches (seed %d)" % seed_number)
		else:
			landed = landed or stunned
			_check(stunned and int(entry.get("duration", 0)) == 1,
				"an unresisted stun attaches with its duration (seed %d)" % seed_number)
		if landed and refused:
			break
	_check(landed and refused, "a 50 stun resist both lands and refuses across seeds")
	# Push on a resistant foe: a resisted move leaves the foe in its rank.
	var moved := false
	var held := false
	for seed_number in range(1, 40):
		var battle := _battle(seed_number)
		var hero := _first(battle, "hero")
		var foe := _first(battle, "foe")
		foe["resist"] = {"move": 60}
		var rank := int(foe.rank)
		var receipt := _receipt()
		battle._apply_effects(hero, foe, {"effects": {"push": 1}}, receipt)
		if receipt.has("shift"):
			moved = true
		elif not receipt.statuses.is_empty() and bool(receipt.statuses[0].get("resisted", false)):
			held = held or int(foe.rank) == rank
		if moved and held:
			break
	_check(moved and held, "a 60 move resist both holds a foe in place and lets a push through")


func _rot_ticks_and_heals() -> void:
	var battle := _battle(7)
	if battle == null:
		return
	var foe := _first(battle, "foe")
	foe.hp = 10
	foe.statuses["rot"] = 2
	var died := battle._tick_turn_start(foe)
	_check(not died and int(foe.hp) == 8 and int(foe.statuses.get("rot", 0)) == 1,
		"rot deals 2 at the turn start and counts down one turn")
	battle._tick_turn_start(foe)
	_check(int(foe.hp) == 6 and not foe.statuses.has("rot"), "rot ends after its last tick")
	foe.prot = 80
	foe.statuses["rot"] = 1
	battle._tick_turn_start(foe)
	_check(int(foe.hp) == 4, "rot ignores PROT")
	foe.hp = 2
	foe.statuses["rot"] = 3
	_check(battle._tick_turn_start(foe) and int(foe.hp) == 0 and bool(foe.dead),
		"rot can finish a foe at its turn start")
	var hero := _first(battle, "hero")
	hero.hp = 4
	hero.statuses["rot"] = 2
	battle._tick_turn_start(hero)
	_check(int(hero.hp) == 2, "rot ticks on a doll too")
	_check(StitchedRules.rot_heal(hero, 7) == 3 and StitchedRules.rot_heal({"statuses": {}}, 7) == 7,
		"rot halves heals (rounded down) and only while it lasts")
	var receipt := _receipt()
	battle._apply_effects(hero, hero, {"effects": {"heal": 6}}, receipt)
	_check(int(hero.hp) == 5 and int(receipt.statuses[0].amount) == 3,
		"a heal on a rotting doll mends half and reports the actual amount")
	hero.statuses["regen"] = 1
	hero.statuses["rot"] = 1
	hero.hp = 5
	battle._tick_turn_start(hero)
	_check(int(hero.hp) == 4, "regen under rot mends 1 before the rot tick takes 2")


func _catalog_resists() -> void:
	var roster := StitchedEnemyCatalog.load_catalog()
	var seams := StitchedDeeperSeams.table()
	_check(bool(roster.get("ok", false)) and not seams.is_empty(), "the enemy catalog and the S15 table load")
	if not bool(roster.get("ok", false)) or seams.is_empty():
		return
	var every := true
	for id in roster.order:
		var authored := StitchedEnemyCatalog.foe_for(roster, id)
		every = every and not authored.has("resist")
		var live := authored.duplicate(true)
		StitchedDeeperSeams.apply(live, 1, "Fight")
		var resist: Dictionary = live.get("resist", {})
		every = every and not resist.is_empty()
		for key in resist:
			every = every and key in StitchedRules.RESIST_KEYS 				and int(resist[key]) > 0 and int(resist[key]) <= StitchedRules.RESIST_MAX
	_check(every, "every catalog foe gets a legal live resist table; authored records stay without one")
	for id in seams.resists:
		_check(roster.enemies.has(id), "resist table names canonical foe " + str(id))
	for id in seams.rot_attacks:
		var authored := StitchedEnemyCatalog.foe_for(roster, id)
		for ability_id in seams.rot_attacks[id]:
			_check(authored.get("abilities", []).any(func(ability: Dictionary):
				return ability.id == ability_id and ability.target_side == "enemy"),
				"rot attack %s/%s is a real enemy-targeted action" % [id, ability_id])
	var boss := StitchedEnemyCatalog.foe_for(roster, "patchwork_behemoth")
	var rag := StitchedEnemyCatalog.foe_for(roster, "ragling")
	StitchedDeeperSeams.apply(boss, RunMap.FLOOR_COUNT, "Boss")
	StitchedDeeperSeams.apply(rag, 1, "Fight")
	_check(int(boss.resist.stun) > int(rag.resist.stun) and int(boss.resist.move) > int(rag.resist.move),
		"the boss shrugs off stuns and shoves far more than a ragling")
	var moth := StitchedEnemyCatalog.foe_for(roster, "moth_swarm")
	StitchedDeeperSeams.apply(moth, 1, "Fight")
	_check(moth.abilities.any(func(ability: Dictionary): return int(ability.effects.get("rot", 0)) == 2),
		"the live moth swarm's dust carries rot 2")
	_check(int(moth.resist.rot) >= 60, "moths barely mind mildew")
	for bad in [{"resists": {"ragling": {"fire": 10}}, "rot_attacks": {}},
			{"resists": {"ragling": {"stun": 95}}, "rot_attacks": {}},
			{"resists": {"ragling": {"stun": -5}}, "rot_attacks": {}},
			{"resists": {"ragling": {"stun": "ten"}}, "rot_attacks": {}},
			{"resists": {}, "rot_attacks": {"moth_swarm": {"wing_dust": 9}}},
			{"resists": {}}]:
		_check(StitchedDeeperSeams.table(bad).is_empty(), "a malformed S15 table %s fails closed" % str(bad))
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	config["s14"] = true
	config.foes[0]["resist"] = {"stun": 120}
	_check(not StitchedRules.create(config).ok, "a battle refuses a foe whose resist is out of range")


func _cues() -> void:
	var lines := StitchedTurnStatusCues.tooltip_lines({"name": "Button Guard", "side": "foe",
		"rank": 1, "hp": 9, "max_hp": 12, "resist": {"stun": 40, "bleed": 50},
		"statuses": {"rot": 2}})
	var text := "\n".join(lines)
	_check("RESIST: stun 40%  bleed 50%" in text, "a foe tooltip lists its resists as plain text")
	_check(StitchedTurnStatusCues.ROT_EXPLANATION in text, "a rotting unit's tooltip explains rot")
	var doll := "\n".join(StitchedTurnStatusCues.tooltip_lines({"name": "Warden", "side": "hero",
		"hp": 9, "max_hp": 12, "resist": {"stun": 40}, "statuses": {}}))
	_check(not "RESIST" in doll, "dolls never show a resist line")
	var entry := StitchedBattleHistory.entry({"ok": true, "action": "ability", "actor": "warden",
		"ability": "warden_head_pot_helm_command", "results": [{"target": "button_guard", "hit": true,
		"damage": 3, "statuses": [{"status": "stun", "resisted": true, "roll": 12, "resist": 40}]}]},
		"Warden", "Pot-Helm Command", {"button_guard": "Button Guard"})
	_check("HIT · 3 damage · resisted stun" in str(entry.text), "battle history says when a foe resisted")


func _mildew_patch() -> void:
	var patches := StitchedS14Abilities.patches()
	var spore: Dictionary = patches.get("by_id", {}).get("silk_mildew_spore", {})
	_check(str(spore.get("rarity", "")) == "silk" and str(spore.get("effect", "")) == "rot"
		and int(spore.get("amount", 0)) == 3, "Mildew Spore is a validated silk rot patch")
	_check(int(StitchedRules.PATCH_PIERCE.cotton) == 0 and int(StitchedRules.PATCH_PIERCE.wool) == 15
		and int(StitchedRules.PATCH_PIERCE.silk) == 30 and int(StitchedRules.PATCH_PIERCE.gold) >= 100,
		"patch rarity sets pierce: cotton 0, wool 15, silk 30, gold always")


func _real_foe_pierce_and_wren() -> void:
	var catalog := StitchedEnemyCatalog.load_catalog()
	var patches := StitchedS14Abilities.patches()
	_check(bool(catalog.get("ok", false)) and not patches.is_empty(), "real catalog and patch family load")
	var seen := 0
	var resisted_seen := 0
	var landed_seen := 0
	var bypass_seen := false
	if not bool(catalog.get("ok", false)) or patches.is_empty():
		return
	for foe_id in catalog.order:
		var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
		var foe: Dictionary = StitchedEnemyCatalog.foe_for(catalog, str(foe_id))
		StitchedDeeperSeams.apply(foe, 1, "Fight")
		# The public battle requires two or three foes. Keep authentic distinct
		# escorts, transformed by S15 too, instead of building a one-foe fixture.
		var roster_foes: Array = [foe]
		for escort_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
			if str(escort_id) != str(foe_id) and roster_foes.size() < 3:
				var escort := StitchedEnemyCatalog.foe_for(catalog, str(escort_id))
				StitchedDeeperSeams.apply(escort, 1, "Fight")
				roster_foes.append(escort)
		config["foes"] = roster_foes
		config["seed"] = 55
		config["s14"] = true
		config["gifts"] = ["snip_string"]
		var built := StitchedRules.create(config)
		_check(built.ok and built.battle != null, "the canonical S15 foe mounts: " + str(foe_id))
		if not built.ok or built.battle == null:
			continue
		var battle: StitchedRules = built.battle
		var target: Dictionary = battle.get_unit(str(foe_id))
		var actor: Dictionary = battle.get_unit("warden")
		_check(not target.is_empty() and not actor.is_empty()
			and target.get("resist", {}) == foe.get("resist", {}),
			"the mounted foe retains its real S15 resist table: " + str(foe_id))
		for patch_id in patches.by_id:
			var patch: Dictionary = patches.by_id[patch_id]
			var effect := str(patch.effect)
			var group := effect
			if effect in ["push", "pull"]:
				group = "move"
			elif effect in StitchedRules.RESIST_DEBUFFS:
				group = "debuff"
			elif not effect in StitchedRules.RESIST_KEYS:
				continue
			var pierce := int(StitchedRules.PATCH_PIERCE.get(str(patch.rarity), 0))
			var net := maxi(0, int(target.resist.get(group, 0)) - pierce)
			var prior_rng := battle.rng_state()
			# Mirror the real next RNG draw before the command. Successful rolls
			# have no receipt entry, so this also proves their landing threshold.
			var oracle_rng := RandomNumberGenerator.new()
			oracle_rng.state = prior_rng
			var actual_roll := oracle_rng.randi_range(1, 100) if net > 0 else 0
			var before_status: Dictionary = target.statuses.duplicate(true)
			var receipt := {"statuses": []}
			var resisted := battle._resisted(actor, target, effect, {"pierce": pierce}, receipt)
			_check(resisted == (net > 0 and actual_roll <= net)
				and battle.rng_state() == oracle_rng.state,
				"the actual next roll and effective rarity-pierced resist determine this outcome")
			var entry: Dictionary = receipt.statuses[0] if not receipt.statuses.is_empty() else {}
			if net == 0:
				_check(not resisted and receipt.statuses.is_empty()
					and battle.rng_state() == prior_rng, "pierced effect costs no draw: " + str(patch_id))
			else:
				seen += 1
				_check(battle.rng_state() != prior_rng, "real positive resist spends one roll")
				if resisted:
					resisted_seen += 1
					_check(entry.get("status") == effect and bool(entry.get("resisted", false))
						and int(entry.get("resist", -1)) == net
						and int(entry.get("roll", 0)) >= 1 and int(entry.get("roll", 101)) == actual_roll and actual_roll <= net,
						"receipt roll respects real resist minus rarity pierce: " + str(patch_id))
				else:
					landed_seen += 1
					_check(receipt.statuses.is_empty() and actual_roll > net,
						"an actual roll above net resist lands without a refused entry")
			_check(target.statuses == before_status, "resistance probing never mutates target statuses")
		if not bypass_seen and int(target.resist.get("stun", 0)) > 0:
			var hand_rng := battle.rng_state()
			var hand := battle.use_hand_action("snip_string", str(foe_id), 0)
			_check(hand.get("ok", false)
				and int(battle.get_unit(str(foe_id)).get("statuses", {}).get("stun", 0)) == 1
				and hand.get("effect", {}).get("status") == "stun"
				and battle.rng_state() == hand_rng,
				"Wren Snip String bypasses a canonical resistant foe without rolling")
			bypass_seen = true
	_check(seen > 0 and resisted_seen > 0 and landed_seen > 0 and bypass_seen,
		"non-vacuous real-foe resistance, rarity and Wren witnesses")


func _depth_scaling() -> void:
	var roster := StitchedEnemyCatalog.load_catalog()
	var base := StitchedEnemyCatalog.foe_for(roster, "spool_stalker")
	var first := base.duplicate(true)
	StitchedDeeperSeams.depth_scale(first, 1, "Fight")
	_check(first == base, "floor 1 foes are unchanged")
	var deep := base.duplicate(true)
	StitchedDeeperSeams.depth_scale(deep, 7, "Fight")
	var depth := StitchedDeeperSeams.DEPTH_HP_PERCENT
	var bonus := 6 / StitchedDeeperSeams.DEPTH_DMG_FLOORS
	_check(depth > 0 and bonus > 0 and int(deep.max_hp) == int(base.max_hp) * (100 + 6 * depth) / 100,
		"floor 7 foes carry more stuffing, by DEPTH_HP_PERCENT per floor past the first")
	var raised := true
	for index in base.abilities.size():
		var was: Array = base.abilities[index].get("dmg", [0, 0])
		var now: Array = deep.abilities[index].get("dmg", [0, 0])
		if int(was[1]) > 0:
			raised = raised and int(now[0]) == int(was[0]) + bonus and int(now[1]) == int(was[1]) + bonus
		else:
			raised = raised and now == was
	_check(raised, "floor 7 attacks hit harder by one per DEPTH_DMG_FLOORS; non-damaging actions stay at 0")
	var elite := StitchedEnemyCatalog.foe_for(roster, "needle_marshal")
	var elite_deep := elite.duplicate(true)
	StitchedDeeperSeams.depth_scale(elite_deep, 10, "Elite")
	_check(int(elite_deep.max_hp) == int(elite.max_hp) * (100 + 9 * depth) / 100, "elites deepen with the floor too")
	var boss := StitchedEnemyCatalog.foe_for(roster, "patchwork_behemoth")
	var softer := boss.duplicate(true)
	StitchedDeeperSeams.depth_scale(softer, RunMap.FLOOR_COUNT, "Boss")
	_check(StitchedDeeperSeams.BOSS_HP_PERCENT < 100
		and int(softer.max_hp) == int(boss.max_hp) * StitchedDeeperSeams.BOSS_HP_PERCENT / 100,
		"the boss is a little softer")
	var trimmed: bool = StitchedDeeperSeams.BOSS_DMG_PERCENT < 100 and softer.abilities.size() == boss.abilities.size()
	for i in mini(softer.abilities.size(), boss.abilities.size()):
		var was: Array = boss.abilities[i].get("dmg", [0, 0])
		var now: Array = softer.abilities[i].get("dmg", [0, 0])
		if int(was[1]) > 0:
			trimmed = trimmed and int(now[0]) == StitchedDeeperSeams.boss_blow(int(was[0])) \
				and int(now[1]) == StitchedDeeperSeams.boss_blow(int(was[1])) and int(now[1]) < int(was[1])
		else:
			trimmed = trimmed and now == was
		trimmed = trimmed and softer.abilities[i].get("effects") == boss.abilities[i].get("effects")
	_check(trimmed, "the boss's blows are trimmed; its non-damaging actions and effects stay as authored")
	var escort := StitchedEnemyCatalog.foe_for(roster, "scissor_crab")
	var escort_boss := escort.duplicate(true)
	StitchedDeeperSeams.depth_scale(escort_boss, RunMap.FLOOR_COUNT, "Boss")
	_check(escort_boss == escort, "a boss's escort is not deepened")
