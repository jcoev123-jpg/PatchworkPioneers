extends SceneTree
## S15 Deeper Seams: foe resistances that sewn patch rarity pierces (gold always
## lands), the mildew Rot status, floor-depth foe scaling with a softer boss,
## and the text-only cues (tooltip RESIST line, history "resisted" suffix).
## Bounded routed runs then prove the layer live: run-entered fights mount the
## actual S15-transformed foes, a real rot attack mildews a doll through a
## public foe turn, and Wren's legal hand action rides the same battle without
## ever rolling a resist.

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
	_routed_fight_witnesses()
	_cues()
	_mildew_patch()
	_gold_contract()
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


## Gold's authored-effect contract, proven independently of the S14 harness:
## the pierce value is exactly one hundred (never merely "at least"), every
## gold patch authors an effect outside every keyed resist group, and a legal
## confirmed gold steal through public turns spends no RNG beyond the identical
## unsocketed twin cast while biting exactly its authored amount.
func _gold_contract() -> void:
	_check(int(StitchedRules.PATCH_PIERCE.gold) == 100,
		"the independent gold pierce contract is exactly one hundred")
	var patches := StitchedS14Abilities.patches()
	var button: Dictionary = patches.get("by_id", {}).get("gold_hungry_button", {})
	if button.is_empty():
		_check(false, "the gold steal patch loads from the catalog")
		return
	var amount := int(button.get("amount", 0))
	for patch_id in patches.by_id:
		var patch: Dictionary = patches.by_id[patch_id]
		if str(patch.get("rarity", "")) != "gold":
			continue
		var effect := str(patch.get("effect", ""))
		_check(not effect in StitchedRules.RESIST_KEYS and not effect in StitchedRules.RESIST_DEBUFFS
			and not effect in ["push", "pull"],
			"the gold patch " + str(patch_id) + " authors an effect no resist group can roll")
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	if config.is_empty():
		return
	config["seed"] = 61
	config["s14"] = true
	for foe in config["foes"]:
		StitchedDeeperSeams.apply(foe, 1, "Fight")
	var twin_config := config.duplicate(true)
	config["s14_sockets"] = {"warden": {"warden_head_pot_helm_command": ["gold_hungry_button"]}}
	var built := StitchedRules.create(config)
	var twin_built := StitchedRules.create(twin_config)
	_check(built.ok and built.battle != null and twin_built.ok and twin_built.battle != null,
		"the legal gold steal socket and its unsocketed twin battle build")
	if not built.ok or built.battle == null or not twin_built.ok or twin_built.battle == null:
		return
	var battle: StitchedRules = built.battle
	var twin: StitchedRules = twin_built.battle
	var foe: Dictionary = battle._foe_at(1)
	var warden: Dictionary = battle.get_unit("warden")
	_check(not foe.is_empty() and not warden.is_empty()
		and not foe.get("resist", {}).is_empty() and int(foe.get("hp", 0)) > amount,
		"the gold fixture faces the same transformed rank-one foe in both battles")
	if foe.is_empty() or int(foe.get("hp", 0)) <= amount:
		return
	# Direct probes on the live transformed foe: gold's authored effect keys
	# never roll a resist, whatever the foe's resist table says.
	for effect in ["heal", "steal", "chain"]:
		var state := battle.rng_state()
		_check(not battle._resisted(warden, foe, effect, {"pierce": 100}, _receipt())
			and battle.rng_state() == state,
			"the gold " + effect + " effect never rolls a resist on a resistant transformed foe")
	var witnessed := false
	for attempt in 12:
		if not _to_turn(battle, "warden") or not _to_turn(twin, "warden"):
			_check(false, "the gold contract fixture reaches real Warden turns in both battles")
			return
		_check(battle.rng_state() == twin.rng_state(),
			"the gold fixture twins stay RNG-aligned before every public cast")
		var before_hp := int(foe.get("hp", 0))
		var warden_hp := int(warden.get("hp", 0))
		var receipt: Dictionary = battle.use_ability("warden_head_pot_helm_command", 1)
		var twin_receipt: Dictionary = twin.use_ability("warden_head_pot_helm_command", 1)
		var results: Array = receipt.get("results", [])
		var twin_results: Array = twin_receipt.get("results", [])
		if results.size() != 1 or twin_results.size() != 1:
			_check(false, "the gold fixture casts resolve exactly one result in both battles")
			return
		var hit: Dictionary = results[0]
		var twin_hit: Dictionary = twin_results[0]
		_check(int(hit.get("roll", -1)) == int(twin_hit.get("roll", -1))
			and str(hit.get("target", "")) == str(twin_hit.get("target", ""))
			and bool(hit.get("hit", false)) == bool(twin_hit.get("hit", false)),
			"the gold steal keeps the cast identical to the unsocketed twin")
		if not bool(hit.get("hit", false)):
			_check(battle.rng_state() == twin.rng_state(),
				"a twin miss spends the identical single hit-roll draw")
			continue
		_check(hit.get("patches", []) == ["gold_hungry_button"],
			"the confirmed gold hit carries exactly its socketed patch id")
		_check(not twin_hit.has("patches"),
			"the unsocketed twin hit never carries the steal")
		_check(hit.get("statuses", []).size() == twin_hit.get("statuses", []).size() + 1,
			"the gold steal appends exactly one entry beyond the authored receipt")
		var stolen := {}
		for entry in hit.get("statuses", []):
			if str(entry.get("status", "")) == "steal" and str(entry.get("patch", "")) == "gold_hungry_button":
				stolen = entry
		var drained := mini(before_hp, amount)
		_check(not stolen.is_empty() and int(stolen.get("amount", -1)) == drained,
			"the gold steal entry reports the actual drained amount")
		_check(int(foe.get("hp", -1)) == before_hp - drained
			and int(hit.get("target_hp", -1)) == before_hp - drained,
			"the gold steal bites its actual target's HP")
		_check(int(warden.get("hp", -1)) == mini(int(warden.get("max_hp", 0)), warden_hp + drained),
			"the gold steal restores the caster exactly what it drained, capped")
		_check(battle.rng_state() == twin.rng_state(),
			"the legal confirmed gold steal spends no additional RNG beyond the unsocketed cast")
		witnessed = true
		break
	_check(witnessed, "a legal confirmed gold steal is witnessed through public turns")


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


## ---------------------------------------------- routed run-entered fights ----

const ROUTED_SEED_CAP := 90


## Real map travel: enter the first offered node of the wanted kinds, otherwise
## walk one lawful non-combat stop at a time through its own enabled actions.
func _travel_to(session: StitchedRunSession, kinds: Array) -> String:
	for step in 16:
		for choice_id in session.choices():
			if str(session.map.get_node(choice_id).type) in kinds:
				var target := str(choice_id)
				if session.enter(target, session.snapshot()) and session.phase in ["visit", "battle"]:
					return target
				return ""
		var next := ""
		for choice_id in session.choices():
			if not str(session.map.get_node(choice_id).type) in ["Fight", "Elite", "Boss"]:
				next = str(choice_id)
				break
		if next.is_empty() or not session.enter(next, session.snapshot()) or session.phase != "visit":
			return ""
		var left := false
		for action in session.visit_actions():
			if bool(action.enabled) and str(action.id) == "leave" and action.arguments.is_empty():
				left = session.choose_visit("leave", [], session.snapshot())
				break
		if not left:
			for action in session.visit_actions():
				if bool(action.enabled) and action.arguments.is_empty() and not str(action.id) in ["swap", "replace", "buy_patch"]:
					left = session.choose_visit(str(action.id), action.arguments, session.snapshot())
					if left:
						break
		if not left or session.phase != "map":
			return ""
	return ""


func _to_turn(battle: StitchedRules, actor_id: String, limit: int = 96) -> bool:
	for step in range(limit):
		if battle.current_actor_id() == actor_id:
				return true
		if battle.is_over() or not battle.pass_turn().get("ok", false):
			return false
	return false


func _play_to_victory(session: StitchedRunSession) -> bool:
	var battle: StitchedRules = session.battle
	for turn in 240:
		if battle.is_over():
			return battle.outcome() == "victory"
		var actor := battle.get_unit(battle.current_actor_id())
		if actor.is_empty():
			return false
		var best: Dictionary = {}
		var best_score := -10000
		for ability in actor.abilities:
			if not StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)):
				continue
			if not battle._self_move_gate(actor, ability).is_empty():
				continue
			if actor.side == "hero" and actor.parts.has(ability.slot) and actor.parts[ability.slot].torn:
				continue
			for rank in range(1, 5):
				if battle._legal_targets(actor, ability, rank).is_empty():
					continue
				var score := 1
				if ability.target_side == "enemy":
					score = 20 + int(ability.dmg[1]) * 5
				elif ability.effects.has("heal"):
					for ally in battle.get_heroes():
						if int(ally.rank) == rank and not ally.lost:
							score = 5 + int(ally.max_hp) - int(ally.hp)
				if score > best_score:
					best_score = score
					best = {"ability": ability.id, "rank": rank}
		var result: Dictionary = {}
		if best.is_empty():
			result = battle.pass_turn()
		elif actor.side == "hero":
			result = battle.use_ability(best.ability, best.rank)
		else:
			result = battle.use_foe_ability(best.ability, best.rank)
		if not result.get("ok", false):
			return false
	return battle.outcome() == "victory"


## The run-entered battle mounts the actual S15 foe records (resist tables
## included, never a plain fixture), and a live rot attack mildews a doll
## through a public foe turn before ticking on the doll's own turn.
func _routed_foe_witness(session: StitchedRunSession, node_id: String, coverage: Dictionary) -> void:
	var battle: StitchedRules = session.battle
	if battle == null:
		return
	var label := "routed battle seed " + str(session.seed_value)
	var catalog := StitchedEnemyCatalog.load_catalog()
	if bool(catalog.get("ok", false)):
		var canonical := true
		var resistant := 0
		for live_foe in battle.get_foes():
			var authored := StitchedEnemyCatalog.foe_for(catalog, str(live_foe.get("id", "")))
			if authored.is_empty():
				canonical = false
				continue
			StitchedDeeperSeams.apply(authored, session.map.get_current_floor(),
				str(session.map.get_node(node_id).type))
			var live_resist: Dictionary = live_foe.get("resist", {})
			var auth_resist: Dictionary = authored.get("resist", {})
			canonical = canonical and live_resist == auth_resist and not auth_resist.is_empty()
			resistant += 1
		_check(canonical and resistant >= 2,
			label + ": the run-entered battle carries its actual floor- and kind-transformed S15 foes")
		if canonical and resistant >= 2:
			coverage["foes"] = true
	if bool(coverage["rot"]):
		return
	for foe in battle.get_foes():
		if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
			continue
		for ability in foe.get("abilities", []):
			var mildew := int(ability.get("effects", {}).get("rot", 0))
			if mildew <= 0 or str(ability.get("target_side", "")) != "enemy":
				continue
			# Bleed or heal in the same blow shifts the tick arithmetic; witness
			# only the pure mildew attacks.
			var ability_effects: Dictionary = ability.get("effects", {})
			if ability_effects.has("bleed") or ability_effects.has("heal"):
				continue
			if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(foe.get("rank", 0))):
				continue
			var victim := {}
			var blow_max := int(ability.get("dmg", [0, 0])[1])
			for hero in battle.get_heroes():
				if not bool(hero.get("lost", false)) and int(hero.get("hp", 0)) > blow_max \
					and (victim.is_empty() or int(hero.get("hp", 0)) > int(victim.get("hp", 0))):
					victim = hero
			if victim.is_empty() or battle._legal_targets(foe, ability, int(victim.rank)).is_empty():
				continue
			if not _to_turn(battle, str(foe.get("id", ""))):
				return
			var victim_id := str(victim.get("id", ""))
			# Witness only a fresh, clean mildew: a doll already rotting, bleeding
			# or mending hides the authored count behind its own turn clocks.
			var clean_state := battle.get_unit(victim_id)
			var clean_status: Dictionary = clean_state.get("statuses", {})
			if bool(clean_state.get("lost", false)) or int(clean_state.get("hp", 0)) <= 0 \
				or int(clean_status.get("rot", 0)) > 0 or int(clean_status.get("bleed", 0)) > 0 \
				or int(clean_status.get("regen", 0)) > 0 \
				or not str(clean_state.get("resolve", "")).is_empty():
				continue
			var receipt := battle.use_foe_ability(str(ability.get("id", "")), int(victim.rank))
			var struck := battle.get_unit(victim_id)
			var landed := false
			var applied := 0
			var blow_result := {}
			for hit in receipt.get("results", []):
				if str(hit.get("target", "")) == victim_id and bool(hit.get("hit", false)):
					landed = true
					blow_result = hit
					for entry in hit.get("statuses", []):
						if str(entry.get("status", "")) == "rot":
							applied = maxi(applied, int(entry.get("duration", 0)))
			if not receipt.get("ok", false) or not landed:
				continue
			if bool(struck.get("lost", false)) or int(struck.get("hp", 0)) <= 0:
				continue
			var rot_now := int(struck.get("statuses", {}).get("rot", 0))
			# The struck doll's own turn, when it starts immediately after the
			# blow, ticks the fresh mildew once before this read; both the fresh
			# count and the honestly once-ticked count carry the receipt.
			var rested := applied == mildew and (rot_now == mildew or rot_now == maxi(0, mildew - 1))
			_check(rested,
				label + ": the live " + str(foe.get("id", "")) + " rot attack rests its authored mildew on the struck doll")
			if not rested:
				return
			# A doll unravelled by the blow's own fray (or an earlier mood)
			# acts on its own beyond the tick; only a settled doll is an exact
			# witness of the mildew clock.
			if not str(struck.get("resolve", "")).is_empty():
				continue
			var hp_at_blow := int(struck.get("hp", 0))
			if rot_now == maxi(0, mildew - 1):
				# The doll's own turn started immediately after the blow and
				# already ticked the fresh mildew down exactly once. The receipt's
				# target_hp is already the post-blow hp, never re-subtract the damage.
				var post_blow := int(blow_result.get("target_hp", 0))
				_check(post_blow > 0 and int(struck.get("hp", 0)) == post_blow - StitchedRules.ROT_TICK,
					label + ": the mildewed doll's own turn ticks the rot and counts it down")
				if post_blow > 0 and int(struck.get("hp", 0)) == post_blow - StitchedRules.ROT_TICK:
					coverage["rot"] = true
				return
			# The doll's own turn ticks the rot even when that turn is consumed
			# by a status or an unravelled mood, so watch the mildew count
			# itself rather than the turn pointer.
			var ticked := false
			for step in 128:
				if battle.is_over():
					break
				if int(battle.get_unit(victim_id).get("statuses", {}).get("rot", 0)) < mildew:
					ticked = true
					break
				if not battle.pass_turn().get("ok", false):
					break
			if not ticked:
				return
			struck = battle.get_unit(victim_id)
			if not str(struck.get("resolve", "")).is_empty():
				return
			_check(int(struck.get("hp", 0)) == maxi(0, hp_at_blow - StitchedRules.ROT_TICK) \
				and int(struck.get("statuses", {}).get("rot", 0)) == maxi(0, mildew - 1),
				label + ": the mildewed doll's own turn ticks the rot and counts it down")
			if int(struck.get("statuses", {}).get("rot", 0)) == maxi(0, mildew - 1) \
				and int(struck.get("hp", 0)) == maxi(0, hp_at_blow - StitchedRules.ROT_TICK):
				coverage["rot"] = true
			return


## Wren's legal foe-targeting gift rides the same run-entered battle: the
## effect lands through the public hand action and, with steady hands, never
## spends a draw on the resistant foe's resist table.
func _routed_wren_witness(session: StitchedRunSession, coverage: Dictionary, seed_number: int) -> void:
	var battle: StitchedRules = session.battle
	if battle == null or battle.is_over():
		return
	var label := "routed Wren hand seed " + str(seed_number)
	var gift_id := ""
	for slot_gift in session.gift_slots:
		var entry := StitchedWrenGifts.gift(str(slot_gift))
		if not entry.is_empty() and not bool(entry.get("basic", true)) and str(entry.get("target", "")) == "foe":
			gift_id = str(slot_gift)
			break
	if gift_id.is_empty():
		return
	var steady_hands := session.kid_fear() < StitchedKidFear.SHAKE_THRESHOLD
	if not steady_hands:
		return
	var group: String = str({"snip_string": "stun", "tug": "move", "shove": "move", "pinch": "debuff"}.get(gift_id, ""))
	var open := false
	for step in 96:
		if battle.is_over():
			return
		if battle.current_side() == "hero" and battle.hand_action_open():
			open = true
			break
		if not battle.pass_turn().get("ok", false):
			return
	if not open:
		return
	var target := ""
	for foe in battle.get_foes():
		if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
			continue
		if battle.hand_action_check(gift_id, str(foe.get("id", "")), 0) != "":
			continue
		if not str(group).is_empty() and int(foe.get("resist", {}).get(str(group), 0)) <= 0:
			continue
		target = str(foe.get("id", ""))
		break
	if target.is_empty():
		return
	var before_rng := battle.rng_state()
	var before_unit := battle.get_unit(target)
	var receipt := battle.use_hand_action(gift_id, target, 0)
	var after := battle.get_unit(target)
	var applied := false
	match gift_id:
		"snip_string":
			applied = int(after.get("statuses", {}).get("stun", 0)) == 1
		"tug", "shove":
			applied = bool(receipt.get("effect", {}).get("ok", false)) \
				and int(after.get("rank", -1)) == int(receipt.get("effect", {}).get("to", -2))
		"flick_button":
			applied = int(after.get("hp", -1)) == maxi(0, int(before_unit.get("hp", 0)) \
				- int(StitchedWrenGifts.gift(gift_id).get("damage", 4)))
		"pinch":
			applied = int(after.get("statuses", {}).get("weak", 0)) == int(StitchedWrenGifts.gift(gift_id).get("turns", 3))
	if not (receipt.get("ok", false) and applied):
		_check(false, label + ": the legal hand action lands its authored effect")
		return
	if steady_hands:
		_check(int(receipt.get("roll", -1)) == 0 and battle.rng_state() == before_rng,
			label + ": the hand action bypasses the resistant foe without any resist roll")
	var journaled := false
	for command in session.journal:
		if command is Dictionary and str(command.get("action", "")) == "battle" \
				and str(command.get("method", "")) == "use_hand_action":
			journaled = true
	_check(journaled, label + ": the routed hand action entered the deterministic journal")
	coverage["wren"] = journaled


## Bounded routed coverage across seeds: each attempt walks a real run to a
## real fight, wins it through public turns, takes a foe-targeting gift from
## the genuine post-victory offer and rides the next run-entered battle.
func _routed_fight_witnesses() -> void:
	var coverage := {"foes": false, "purity": false, "wren": false, "rot": false}
	for seed_number in range(ROUTED_SEED_CAP):
		if bool(coverage["foes"]) and bool(coverage["purity"]) and bool(coverage["wren"]) and bool(coverage["rot"]):
			break
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		var first := _travel_to(session, ["Fight"])
		if first.is_empty() or session.phase != "battle":
			continue
		_routed_foe_witness(session, first, coverage)
		if not _play_to_victory(session) or not session.settle_battle(session.battle):
			continue
		if not bool(coverage["purity"]) and not session.gift_offer.is_empty():
			var before := session.snapshot()
			var stale := before.duplicate(true)
			stale["candle"] = int(stale.get("candle", 0)) + 1
			if not session.choose_gift("forged_gift", "", before) and not session.choose_gift("", "steady", stale) \
					and session.snapshot() == before:
				coverage["purity"] = true
		var taken := ""
		if not session.gift_offer.is_empty():
			for offered in session.gift_offer:
				if str(StitchedWrenGifts.gift(str(offered)).get("target", "")) == "foe":
					taken = str(offered)
					break
			if not taken.is_empty():
				var swap := "steady" if session.gift_slots.has("steady") else str(session.gift_slots[0])
				if not session.choose_gift(taken, swap, session.snapshot()):
					taken = ""
		var second := _travel_to(session, ["Fight", "Elite"])
		if second.is_empty() or session.phase != "battle":
			continue
		_routed_foe_witness(session, second, coverage)
		if not taken.is_empty() and not bool(coverage["wren"]):
			_routed_wren_witness(session, coverage, seed_number)
	_check(bool(coverage["foes"]), "a real run-entered fight mounts its actual S15-transformed foes")
	_check(bool(coverage["purity"]), "forged and stale gift requests refuse without mutating the run")
	_check(bool(coverage["wren"]), "Wren's legal hand action rides a real run-entered battle without a resist roll")
	_check(bool(coverage["rot"]), "a real S15 foe rot attack mildews a doll through a public foe turn")
