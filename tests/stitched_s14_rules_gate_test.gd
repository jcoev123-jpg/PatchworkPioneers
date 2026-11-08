extends SceneTree
## S14 complete headless gate: authored kits, patches, death-door, doors and replay.

var failures: Array[String] = []
var checks := 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_catalogs()
	_combat()
	_death_door()
	_doors()
	_sewing_circle_sockets()
	_live_elite_side_door()
	_session_replay()
	for message in failures:
		printerr(message)
	print("stitched_s14_rules_gate_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _config(seed_number: int) -> Dictionary:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	config["seed"] = seed_number
	config["s14"] = true
	return config


func _battle(seed_number: int, sockets: Dictionary = {}) -> StitchedRules:
	var config := _config(seed_number)
	config["s14_sockets"] = sockets
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "real starter equipment and fixed kits construct a seeded battle")
	return built.battle


func _catalogs() -> void:
	var kits := StitchedS14Abilities.kits()
	var patches := StitchedS14Abilities.patches()
	var doors := StitchedS14SideDoors.catalog()
	_check(kits.size() == StitchedPartyAdmission.HERO_IDS.size(), "all eight fixed hero kits exist")
	var abilities := {}
	for hero_id in StitchedPartyAdmission.HERO_IDS:
		var kit: Dictionary = kits.get(hero_id, {})
		_check(kit.size() == 4, hero_id + " has four signature abilities")
		for slot in StitchedParts.SLOTS:
			var skill: Dictionary = kit.get(slot, {})
			_check(not skill.is_empty() and skill.get("target_side") in StitchedParts.TARGET_SIDES \
				and StitchedParts.ranks_allowed(int(skill.get("launch_mask", 0)), int(skill.get("launch", [0])[0])) \
				and StitchedParts.ranks_allowed(int(skill.get("target_mask", 0)), int(skill.get("target", [0])[0])),
				hero_id + " " + slot + " validates rank and target masks")
			_check(not abilities.has(skill.get("id")), hero_id + " signature id unique")
			abilities[skill.get("id")] = true
	_check(patches.size() == 2 and doors.size() >= 4, "ability patch and side-door catalogs validate")
	var corrupted := {"patches": [{"id": "evil", "name": "Evil", "rarity": "silk",
		"effect": "teleport", "amount": 1}], "weights": patches.weights.duplicate(true)}
	_check(StitchedS14Abilities.patches(corrupted).is_empty(), "unknown patch effects fail closed")
	var invalid_kit := {"abilities": []}
	_check(StitchedS14Abilities.kits(invalid_kit).is_empty(), "missing hero kits fail closed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 38170
	var counts := {}
	for source in StitchedS14Abilities.SOURCES:
		counts[source] = {"cotton": 0, "wool": 0, "silk": 0, "gold": 0}
		for index in 1600:
			var patch := StitchedS14Abilities.draw_patch(rng, source)
			_check(patch.get("rarity") in StitchedS14Abilities.RARITIES
				and patches.by_id.has(patch.get("id", "")), "seeded patch belongs to the validated tier")
			counts[source][patch.rarity] += 1
	_check(counts.fight.gold == 0 and counts.boss.gold > counts.elite.gold
		and counts.elite.silk > counts.fight.silk
		and counts.event.cotton > counts.event.silk,
		"legal rarity frequencies favor silk/gold on Elite and Boss")
	var before := rng.state
	_check(StitchedS14Abilities.draw_patch(rng, "forged").is_empty() and before == rng.state,
		"invalid rarity source never draws RNG")
	_check(StitchedS14Abilities.socket_limit(["gold_chain_thread", "wool_mark_thread"]) == 2
		and StitchedS14Abilities.socket_limit(["cotton_red_lint", "wool_mark_thread"]) == 1,
		"gold socket exception is validated")


func _combat() -> void:
	var sockets := {"seamstress": {"seamstress_head_mending_knot": ["cotton_red_lint"]}}
	var battle := _battle(83, sockets)
	if battle == null:
		return
	_check(battle.get_unit("seamstress").abilities.size() == 4,
		"fixed kit is live in actual battle setup")
	var actor: Dictionary = battle._units["seamstress"]
	var target: Dictionary = battle._units["warden"]
	target.hp -= 9
	battle._order = ["seamstress", "warden"]
	battle._turn_index = 0
	var before := battle.state_snapshot()
	var failed := battle.use_ability("not_a_skill", 1)
	_check(not failed.ok and before == battle.state_snapshot(),
		"forged signature ability does not spend turn or RNG")
	var result := battle.use_ability("seamstress_head_mending_knot", 1)
	_check(result.ok and result.results.size() == 1 and result.results[0].hit,
		"signature heal actually resolves on a non-null ally target")
	_check(battle.get_unit("warden").hp > int(target.max_hp) - 9
		and result.results[0].statuses.any(func(status: Dictionary) -> bool:
			return status.get("status") == "bleed" and status.get("duration") == 2)
		and battle.get_unit("warden").statuses.get("bleed", 0) > 0,
		"harmful bleed patch on HEAL bleeds the healed ally")
	var clean := _battle(83)
	if clean == null:
		return
	clean._units["warden"].hp -= 9
	clean._order = ["seamstress", "warden"]
	clean._turn_index = 0
	var unpatched := clean.use_ability("seamstress_head_mending_knot", 1)
	_check(unpatched.ok and clean.get_unit("warden").statuses.get("bleed", 0) == 0,
		"the same fixed heal without socket does not bleed")
	var wrong := _config(83)
	wrong.s14_sockets = {"seamstress": {"seamstress_head_mending_knot": ["made_up_patch"]}}
	_check(not StitchedRules.create(wrong).ok, "forged battle patch loadout fails before RNG")
	_check(not battle.use_part("warden_arms_shield_catch", 1).ok,
		"part attacks are retired in S14 rules")


func _death_door() -> void:
	var witness := false
	for seed_number in 40:
		var battle := _battle(seed_number)
		if battle == null:
			return
		var hero: Dictionary = battle._units["warden"]
		hero.hp = 1
		var receipt := {}
		battle._damage_target(hero, 4, receipt)
		if hero.lost:
			_check(receipt.death_door.tear.slot == "head", "an early fatal head tear is explicit")
			continue
		witness = true
		var first: String = str(receipt.death_door.tear.slot)
		_check(first in ["arms", "legs"] and hero.death_hits == 1 and hero.hp == 0
			and hero.parts[first].torn, "first direct zero-HP hit tears an actual limb")
		var penalty := battle.get_unit("warden")
		if first == "arms":
			_check(int(penalty.dmg_bonus) < 8, "torn arm weakens strikes")
		else:
			_check(not battle._shift_valid(hero, 1).ok, "torn leg refuses rank change")
		battle._apply_effects(battle._units["seamstress"], hero, {"effects": {"heal": 3}},
			{"statuses": []})
		_check(hero.hp > 0 and hero.death_hits == 0 and hero.parts[first].torn,
			"healing resets hit counter but not the torn limb")
		hero.hp = 0
		hero.hanging = true
		var second := battle._death_door_hit(hero)
		if hero.lost:
			_check(second.tear.slot == "head", "second death hit can tear the head")
			break
		var third := battle._death_door_hit(hero)
		_check(third.tear.slot == "head" and hero.lost and hero.parts.is_empty()
			and battle.satchel().size() > 0, "third hit guarantees LOST and preserves replacement satchel")
		break
	_check(witness, "seeded death-door witness reaches torn limb and next hit")
	var candidate := _battle(71)
	if candidate == null:
		return
	candidate._units["warden"].parts.arms.torn = true
	candidate._recompute_stats(candidate._units["warden"])
	var saved: Dictionary = candidate.get_unit("warden")
	var next_config := _config(72)
	next_config.heroes[0]["hp"] = 0
	next_config.heroes[0]["death_hits"] = 1
	next_config.heroes[0]["parts"]["arms"]["torn"] = true
	var carried := StitchedRules.create(next_config)
	_check(carried.ok and carried.battle.get_unit("warden").death_hits == 1
		and carried.battle.get_unit("warden").parts.arms.torn,
		"cross-fight carry preserves torn arm and death-hit counter")
	_check(saved.parts.arms.torn, "torn part persists in read-only battle snapshot")


func _doors() -> void:
	var doors := StitchedS14SideDoors.catalog()
	var rng := RandomNumberGenerator.new()
	rng.seed = 118
	var opened := 0
	for index in 100:
		var offered := StitchedS14SideDoors.offer(rng, "Elite", false)
		if not offered.is_empty():
			opened += 1
			_check(doors.has(offered.id), "seeded elite door is an authored side offer")
	_check(opened > 0 and opened < 100, "elite door appears occasionally, not on every fight")
	var rng_before := rng.state
	_check(StitchedS14SideDoors.offer(rng, "Fight", false).is_empty() and rng_before == rng.state,
		"ordinary Fight cannot create a door or consume RNG")
	var run := StitchedRunSession.start(14)
	_check(run != null and run.is_consistent(), "real run exposes the side-door ledger")
	if run == null:
		return
	var offered: Dictionary = doors["underbed_stuffing_trade"].duplicate(true)
	offered.node_id = run.map.get_current_node_id()
	run.phase = "map"
	run.door_offer = offered
	run._seal()
	var prior := run.snapshot()
	_check(not run.choose_door("underbed_stuffing_trade", "missing_doll", prior)
		and prior == run.snapshot(), "forged door recipient fails without spend")
	var victim: Dictionary = run.heroes[0]
	_check(run.choose_door("underbed_stuffing_trade", victim.id, prior)
		and run.underbed_taken and run.ability_inventory.size() == 1
		and run.ability_inventory[0].rarity == "gold",
		"paid under-bed door atomically reduces stuffing and awards gold-tier patch")
	var after := run.snapshot()
	_check(not run.choose_door("underbed_stuffing_trade", victim.id, prior)
		and run.snapshot() == after, "single-use door rejects stale double-spend")
	run.door_offer = doors["attic_waxlight"].duplicate(true)
	run.door_offer.node_id = run.map.get_current_node_id()
	run._seal()
	var barred := run.snapshot()
	_check(not run.choose_door("attic_waxlight", "", barred)
		and barred == run.snapshot(), "under-bed deal permanently bars attic blessing")


func _play_live_battle(session: StitchedRunSession) -> bool:
	var battle: StitchedRules = session.battle
	for turn in 220:
		if battle.is_over():
			return true
		var actor := battle.get_unit(battle.current_actor_id())
		if actor.is_empty():
			return false
		var best: Dictionary = {}
		var best_score := -10000
		for ability in actor.abilities:
			if not StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)):
				continue
			if actor.side == "hero" and actor.parts.has(ability.slot) and actor.parts[ability.slot].torn:
				continue
			for rank in range(1, 5):
				if battle._legal_targets(actor, ability, rank).is_empty() \
						or not battle._self_move_gate(actor, ability).is_empty():
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
	return battle.is_over()


func _sewing_circle_sockets() -> void:
	var run: StitchedRunSession
	var circle_id := ""
	for seed_number in 60:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		for id in candidate.choices():
			if candidate.map.get_node(id).type == "SewingCircle":
				run = candidate
				circle_id = id
				break
		if not circle_id.is_empty():
			break
	_check(run != null and not circle_id.is_empty(), "map offers real Sewing Circle")
	if run == null:
		return
	_check(run.enter(circle_id, run.snapshot()) and run.pending.service == "SewingCircle",
		"real Sewing Circle accepts S14 socket commands")
	if run.phase != "visit":
		return
	var initial := run.snapshot()
	_check(not run.socket_ability(1, "warden", "warden_arms_shield_catch", 0, initial)
		and initial == run.snapshot(), "unowned patch cannot be socketed for free")
	# Exercise the authenticated service with a bounded injected wallet/owned
	# item fixture; no fabricated service or nullable callback is used.
	var gold := run._award_ability_patch("elite", "gold")
	var wool := run._award_ability_patch("elite", "wool")
	var cotton := run._award_ability_patch("fight", "cotton")
	run.scraps = 6
	run._open_visit("SewingCircle")
	run._seal()
	var before := run.snapshot()
	_check(run.socket_ability(gold.uid, "warden", "warden_arms_shield_catch", 0, before)
		and run.scraps == 4, "owned gold patch costs Sewing Circle scraps")
	var after := run.snapshot()
	_check(not run.socket_ability(gold.uid, "warden", "warden_arms_shield_catch", 0, before)
		and after == run.snapshot(), "stale socket request cannot double charge")
	_check(run.socket_ability(wool.uid, "warden", "warden_arms_shield_catch", 0, run.snapshot())
		and run.ability_sockets.warden["warden_arms_shield_catch"].size() == 2,
		"gold socket permits a second patch")
	var full := run.snapshot()
	_check(not run.socket_ability(cotton.uid, "warden", "warden_arms_shield_catch", 0, full)
		and full == run.snapshot(), "third socket refuses without spending")
	_check(run.socket_ability(cotton.uid, "warden", "warden_arms_shield_catch",
		wool.uid, full), "rethread replaces an owned patch atomically")
	_check(run._battle_sockets().warden["warden_arms_shield_catch"].size() == 2,
		"owned socket IDs project into live fixed kit")
	_check(not run.socket_ability(wool.uid, "missing_doll", "warden_arms_shield_catch", 0,
		run.snapshot()), "missing hero cannot borrow an owned patch")


func _live_elite_side_door() -> void:
	# Never fabricate an offer: choose an actual opening Elite and settle it.
	var witness := false
	for seed_number in 80:
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		var elite_id := ""
		for id in session.choices():
			if session.map.get_node(id).type == "Elite":
				elite_id = id
				break
		if elite_id.is_empty() or not session.enter(elite_id, session.snapshot()):
			continue
		if not _play_live_battle(session) or session.battle.outcome() != "victory":
			continue
		if not session.settle_battle(session.battle) or session.door_offer.is_empty():
			continue
		var offered: Dictionary = session.door_offer.duplicate(true)
		var hero_id := ""
		if offered.cost != "none" or offered.reward == "head_guard":
			for hero in session.heroes:
				if hero.lost:
					continue
				if offered.cost == "max_hp" and int(hero.base_max_hp) - int(offered.amount) < 10:
					continue
				if offered.cost == "limb" and hero.parts.arms.torn:
					continue
				hero_id = hero.id
				break
			if hero_id.is_empty():
				continue
		var prior := session.snapshot()
		var before_rng := session.rng.state
		_check(not session.choose_door("fake_door", hero_id, prior)
			and session.snapshot() == prior and session.rng.state == before_rng,
			"live forged door choice preserves RNG and inventory")
		if not session.choose_door(str(offered.id), hero_id, prior):
			continue
		witness = true
		var committed := session.snapshot()
		_check(session.door_offer.is_empty() and session.door_history.size() == 1,
			"real Elite victory permits one authenticated side door")
		_check(not session.choose_door(str(offered.id), hero_id, prior)
			and session.snapshot() == committed, "live spent door refuses double transaction")
		var saved := StitchedRunSave.capture(session)
		_check(not saved.is_empty() and session.journal.back().action == "door",
			"real Elite transaction enters deterministic journal")
		var restored := StitchedRunSave.restore(saved)
		_check(restored != null and restored.snapshot() == committed,
			"real Elite and door purchase roundtrip through replay")
		break
	_check(witness, "seeded authentic Elite has a won battle and an offered door")


func _session_replay() -> void:
	var session := StitchedRunSession.start(42)
	if session == null:
		_check(false, "S14 start loads validated catalog")
		return
	var original := session.snapshot()
	var document := StitchedRunSave.capture(session)
	_check(not document.is_empty(), "S14 state has authenticated save")
	var restored := StitchedRunSave.restore(document)
	_check(restored != null and restored.snapshot() == original,
		"seeded S14 run starts with exact save/replay")
	var corrupt := document.duplicate(true)
	corrupt.state.s14.serial = 444
	corrupt.digest = StitchedRunSave._digest(corrupt)
	_check(StitchedRunSave.restore(corrupt) == null and session.snapshot() == original,
		"rehashed inventory counter forgery fails closed")
	_check(not session.socket_ability(27, "warden", "warden_arms_shield_catch", 0,
		session.snapshot()) and session.snapshot() == original,
		"socket outside real Sewing Circle is no-spend/no-RNG refusal")
	var historical := StitchedRunSession.start(42, StitchedRunSession.DEFAULT_PICKS, {}, false)
	var old_document := StitchedRunSave.capture(historical)
	old_document.state.erase("s14")
	for hero in old_document.state.heroes:
		hero.erase("death_hits")
		hero.erase("head_ward")
	old_document.digest = StitchedRunSave._digest(old_document)
	var migrated := StitchedRunSave.restore(old_document)
	_check(migrated != null and migrated.snapshot() == historical.snapshot(),
		"pre-S14 serialized hero schema migrates from authenticated legacy journal")
	var picked := ""
	for id in session.choices():
		if session.map.get_node(id).type == "Fight":
			picked = id
			break
	_check(not picked.is_empty(), "route has a non-null Fight choice for S14 live setup")
	if picked.is_empty():
		return
	_check(session.enter(picked, session.snapshot()) and session.phase == "battle"
		and session.battle._s14 and session.battle.get_unit("warden").abilities.size() == 4,
		"actual run Fight passes signature kits and session RNG into live ranked battle")
	var live_before := session.snapshot()
	var refused := session.battle.use_ability("made_up", 1)
	_check(not refused.ok and session.snapshot() == live_before,
		"forged routed battle method is no-RNG no-journal refusal")
	var mid := StitchedRunSave.restore(StitchedRunSave.capture(session))
	_check(mid != null and mid.snapshot() == session.snapshot(),
		"live S14 midbattle snapshot replays from authentic map journal")
