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
	_foe_push_pull()
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


## Seeded, real S14 signature dispatch. Check the *struck* unit's identity and
## rank, not just a successful ability receipt: swap/refusal never rolls again.
func _shift_battle(seed_number: int, picks: Array, sockets: Dictionary = {}) -> StitchedRules:
	var config := StitchedRunSession.starter_config(picks)
	_check(not config.is_empty(), "S14 movement fixture admits its real four-doll party")
	if config.is_empty():
		return null
	config["seed"] = seed_number
	config["s14"] = true
	config["s14_sockets"] = sockets
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "S14 movement fixture builds from authored kits and foes")
	return built.battle if built.ok else null


func _shift_turn(battle: StitchedRules, hero_id: String, ability_id: String, target_rank: int) -> Dictionary:
	# Preserve real use_ability validation/hit/receipts rather than calling _apply_effects.
	battle._order = [hero_id, "warden" if hero_id != "warden" else "seamstress"]
	battle._turn_index = 0
	return battle.use_ability(ability_id, target_rank)


func _shift_hit(receipt: Dictionary) -> Dictionary:
	if not receipt.get("ok", false) or receipt.get("results", []).size() != 1:
		return {}
	return receipt.results[0]


func _foe_push_pull() -> void:
	var picks := StitchedRunSession.DEFAULT_PICKS
	var push := _battle(83)
	if push == null:
		return
	var front: Dictionary = push._foe_at(1)
	var second: Dictionary = push._foe_at(2)
	_check(not front.is_empty() and not second.is_empty() and front.id != second.id,
		"Rim Toss precondition: distinct living foes occupy first and second ranks")
	if front.is_empty() or second.is_empty():
		return
	var pushed := _shift_hit(_shift_turn(push, "warden", "warden_legs_rim_toss", 1))
	var move: Dictionary = pushed.get("shift", {})
	_check(pushed.get("hit", false) and pushed.get("target") == front.id
		and move.get("ok", false) and move.get("from") == 1 and move.get("to") == 2
		and move.get("swapped") == second.id and push.get_unit(front.id).rank == 2
		and push.get_unit(second.id).rank == 1,
		"authored Rim Toss pushes the hit living foe and swaps an occupied foe rank")

	var scarecrow := _shift_battle(82, ["warden", "scarecrow", "tinker", "lantern_monk"])
	if scarecrow == null:
		return
	var pulled_foe: Dictionary = scarecrow._foe_at(2)
	var ahead: Dictionary = scarecrow._foe_at(1)
	_check(not pulled_foe.is_empty() and not ahead.is_empty(),
		"Startle Step precondition: living foes occupy first and second ranks")
	if pulled_foe.is_empty() or ahead.is_empty():
		return
	var pulled := _shift_hit(_shift_turn(scarecrow, "scarecrow", "scarecrow_legs_startle_step", 2))
	var pull: Dictionary = pulled.get("shift", {})
	_check(pulled.get("hit", false) and pulled.get("target") == pulled_foe.id
		and pull.get("ok", false) and pull.get("from") == 2 and pull.get("to") == 1
		and pull.get("swapped") == ahead.id and scarecrow.get_unit(pulled_foe.id).rank == 1
		and scarecrow.get_unit(ahead.id).rank == 2,
		"authored Startle Step pulls the hit living foe and swaps an occupied foe rank")

	# The same enemy-targeted *signature* gains one movement direction from
	# each socket; compare the no-socket RNG stream with the identical hit.
	for patch_id in ["wool_hook_stitch", "wool_heel_knot"]:
		var signed := {"warden": {"warden_head_pot_helm_command": [patch_id]}}
		var patched := _shift_battle(55, picks, signed)
		var baseline := _battle(55)
		if patched == null or baseline == null:
			return
		var direction := -1 if patch_id == "wool_hook_stitch" else 1
		var victim: Dictionary = patched._foe_at(2)
		var neighbor: Dictionary = patched._foe_at(2 + direction)
		_check(not victim.is_empty() and not neighbor.is_empty(),
			"socket precondition: two distinct living enemy ranks are present")
		if victim.is_empty() or neighbor.is_empty():
			return
		var before_rng := patched.rng_state()
		var baseline_before_rng := baseline.rng_state()
		var attached := _shift_hit(_shift_turn(patched, "warden", "warden_head_pot_helm_command", 2))
		var without := _shift_hit(_shift_turn(baseline, "warden", "warden_head_pot_helm_command", 2))
		var shifted: Dictionary = attached.get("shift", {})
		_check(attached.get("hit", false) and attached.get("target") == victim.id
			and shifted.get("ok", false) and shifted.get("from") == 2
			and shifted.get("to") == 2 + direction and shifted.get("swapped") == neighbor.id
			and patched.get_unit(victim.id).rank == 2 + direction
			and patched.get_unit(neighbor.id).rank == 2
			and patched.get_unit(victim.id).statuses.get("mark", 0) > 0,
			"enemy-targeted " + patch_id + " moves the struck foe without losing authored Mark")
		_check(before_rng == baseline_before_rng,
			"socketed and plain authored abilities start with identical seeded RNG")
		_check(without.get("hit", false) and not without.has("shift")
			and baseline.get_unit(victim.id).rank == 2
			and baseline.rng_state() == patched.rng_state(),
			"socket movement consumes no extra RNG compared with the same seeded signature hit")

	# An ally-targeted signature heals the actual allied recipient and the
	# same movement patches still shift that ally, not an opposing foe.
	for patch_id in ["wool_hook_stitch", "wool_heel_knot"]:
		var sockets := {"seamstress": {"seamstress_head_mending_knot": [patch_id]}}
		var ally := _shift_battle(24, picks, sockets)
		if ally == null:
			return
		var patient: Dictionary = ally._units["tinker"]
		patient.hp -= 7
		var before_hp := int(patient.hp)
		var original_foes := ally.get_foes()
		var direction := -1 if patch_id == "wool_hook_stitch" else 1
		var other: Dictionary = ally._hero_at(3 + direction)
		_check(not other.is_empty() and patient.rank == 3 and original_foes.size() == 3,
			"ally socket precondition: injured real ally and distinct swap neighbor exist")
		if other.is_empty() or original_foes.size() != 3:
			return
		var result := _shift_hit(_shift_turn(ally, "seamstress", "seamstress_head_mending_knot", 3))
		var shift: Dictionary = result.get("shift", {})
		_check(result.get("hit", false) and result.get("target") == "tinker"
			and shift.get("ok", false) and shift.get("swapped") == other.id
			and ally.get_unit("tinker").rank == 3 + direction
			and ally.get_unit(other.id).rank == 3 and ally.get_unit("tinker").hp > before_hp
			and ally.get_foes().all(func(foe: Dictionary) -> bool:
				return int(foe.rank) == int(original_foes.filter(func(old: Dictionary) -> bool:
					return old.id == foe.id)[0].rank)),
			"ally-targeted " + patch_id + " heals and shifts the ally, never the foe")

	# Blind guarantees a miss through the actual hit gate (not a fake
	# _apply_effects call); no authored or socket movement may follow.
	var miss := _shift_battle(55, picks,
		{"warden": {"warden_head_pot_helm_command": ["wool_heel_knot"]}})
	if miss == null:
		return
	var missed_foe: Dictionary = miss._foe_at(2)
	_check(not missed_foe.is_empty(), "miss precondition: struck foe exists")
	if missed_foe.is_empty():
		return
	miss._units["warden"].statuses["blind"] = 1
	var missed := _shift_hit(_shift_turn(miss, "warden", "warden_head_pot_helm_command", 2))
	_check(not missed.get("hit", true) and not missed.has("shift")
		and miss.get_unit(missed_foe.id).rank == 2
		and miss.get_unit(missed_foe.id).statuses.get("mark", 0) == 0,
		"blinded signature misses and socketed push does not move or Mark a foe")

	# A Tangled destination foe cannot be traded past, and a Tangled target
	# cannot move. Both are confirmed hits, not failed validations.
	for tangle_target in [false, true]:
		var tangled := _shift_battle(55, picks,
			{"warden": {"warden_head_pot_helm_command": ["wool_heel_knot"]}})
		if tangled == null:
			return
		var unit: Dictionary = tangled._foe_at(2 if tangle_target else 3)
		var source: Dictionary = tangled._foe_at(2)
		unit.statuses["tangled"] = 2
		var blocked := _shift_hit(_shift_turn(tangled, "warden", "warden_head_pot_helm_command", 2))
		_check(blocked.get("hit", false) and not blocked.get("shift", {}).get("ok", true)
			and tangled.get_unit(source.id).rank == 2 and tangled.get_unit(unit.id).rank == (2 if tangle_target else 3),
			"Tangled " + ("target" if tangle_target else "neighbor") + " blocks a confirmed push")

	var heaped := _shift_battle(55, picks,
		{"warden": {"warden_head_pot_helm_command": ["wool_heel_knot"]}})
	if heaped == null:
		return
	var heap_target: Dictionary = heaped._foe_at(2)
	var fallen: Dictionary = heaped._foe_at(3)
	var death := {}
	heaped._damage_target(fallen, int(fallen.hp), death)
	_check(death.has("heap") and not heaped._heap_at(3).is_empty()
		and not heap_target.is_empty(), "heap precondition: actual defeated foe leaves rank-three scrap")
	var heap_hit := _shift_hit(_shift_turn(heaped, "warden", "warden_head_pot_helm_command", 2))
	_check(heap_hit.get("hit", false) and not heap_hit.get("shift", {}).get("ok", true)
		and heaped.get_unit(heap_target.id).rank == 2 and not heaped._heap_at(3).is_empty(),
		"occupied scrap heap blocks a confirmed socket push")

	var boundary_pull := _shift_battle(55, picks,
		{"warden": {"warden_head_pot_helm_command": ["wool_hook_stitch"]}})
	if boundary_pull == null:
		return
	var first_foe: Dictionary = boundary_pull._foe_at(1)
	var pulled_edge := _shift_hit(_shift_turn(boundary_pull, "warden", "warden_head_pot_helm_command", 1))
	_check(pulled_edge.get("hit", false) and not pulled_edge.get("shift", {}).get("ok", true)
		and boundary_pull.get_unit(first_foe.id).rank == 1,
		"rank-one foe cannot be pulled across front boundary")
	var boundary_push := _shift_battle(55, picks,
		{"tinker": {"tinker_head_cog_shot": ["wool_heel_knot"]}})
	if boundary_push == null:
		return
	var back_foe: Dictionary = boundary_push._foe_at(3)
	var advance: Dictionary = boundary_push._gift_shift(back_foe, 1)
	_check(advance.get("ok", false) and back_foe.rank == 4 and boundary_push._foe_at(4).id == back_foe.id,
		"back boundary precondition: Wren's valid foe shift places a living foe in rank four")
	var pushed_edge := _shift_hit(_shift_turn(boundary_push, "tinker", "tinker_head_cog_shot", 4))
	_check(pushed_edge.get("hit", false) and not pushed_edge.get("shift", {}).get("ok", true)
		and boundary_push.get_unit(back_foe.id).rank == 4,
		"rank-four foe cannot be pushed beyond back boundary")

	var invalid := _shift_battle(55, picks)
	if invalid == null:
		return
	invalid._order = ["warden", "seamstress"]
	invalid._turn_index = 0
	var original := invalid.state_snapshot()
	var rng_before := invalid.rng_state()
	var forged := invalid.use_ability("not_a_signature", 2)
	_check(not forged.get("ok", true) and original == invalid.state_snapshot()
		and rng_before == invalid.rng_state(), "invalid signature never commits state or RNG")
	var outside := invalid.use_ability("warden_legs_rim_toss", 4)
	_check(not outside.get("ok", true) and original == invalid.state_snapshot()
		and rng_before == invalid.rng_state(), "illegal target mask never commits state or RNG")
