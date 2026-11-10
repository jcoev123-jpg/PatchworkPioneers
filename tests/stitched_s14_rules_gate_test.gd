extends SceneTree
## S14 complete headless gate: authored kits, patches, death-door, doors and replay.

var failures: Array[String] = []
var checks := 0

## Test-only bounded Event service fixture: one authenticated choice whose only
## consequence is a living doll's lasting maximum-HP change, with the wallet and
## every other party value untouched. The shipped Event catalog has no
## max-HP-only outcome, so this minimal service isolates that material case
## while the session's real choose_visit/_apply_receipt path stays in charge.
class MaxHpOnlyEventService extends RefCounted:
	var _node_id := ""
	var _choice_id := ""
	var _wallet := {}
	var _claimed := false

	func _init(node_id: String, choice_id: String, wallet: Dictionary) -> void:
		_node_id = node_id
		_choice_id = choice_id
		_wallet = wallet.duplicate(true)

	func read_state() -> Dictionary:
		return {"ok": true, "node_id": _node_id, "choice_id": _choice_id,
			"claimed": _claimed, "wallet": _wallet.duplicate(true)}

	func choose(choice_id: String, expected_node_id: String, expected_state: Dictionary) -> Dictionary:
		if _claimed or choice_id != _choice_id or expected_node_id != _node_id \
				or expected_state != read_state():
			return {"ok": false}
		_claimed = true
		return {"ok": true, "node_id": _node_id, "choice_id": choice_id,
			"target_hero_id": "warden", "max_hp_delta": 3, "hp_delta": 0,
			"wallet": _wallet.duplicate(true)}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_catalogs()
	_combat()
	_foe_push_pull()
	_chain_thread()
	_death_door()
	_doors()
	_event_max_hp_patch()
	_event_fear_patch()
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
	## The first file-backed reads in this process are public results too: forged
	## nested kit effects, patch effects and source weights in them, and in warm
	## re-reads, can never reach the cached authored catalog.
	var head: Dictionary = kits.warden.head
	var expected_mark: Variant = head.effects.mark
	var expected_effect: String = patches.by_id.cotton_red_lint.effect
	var expected_fight: Array = patches.weights.fight.duplicate()
	head.effects["mark"] = 99
	patches.by_id.cotton_red_lint.effect = "steal"
	patches.weights.fight[0] = 100
	var rekit := StitchedS14Abilities.kits()
	var repatch := StitchedS14Abilities.patches()
	_check(rekit.warden.head.effects.mark == expected_mark and rekit.warden.head != head,
		"first kits() read mutations never leak into a fresh read")
	_check(repatch.by_id.cotton_red_lint.effect == expected_effect
		and repatch.weights.fight == expected_fight
		and repatch.by_id.cotton_red_lint != patches.by_id.cotton_red_lint,
		"first patches() read mutations never leak into a fresh read")
	rekit.warden.head.effects["mark"] = 77
	repatch.by_id.cotton_red_lint.effect = "blind"
	repatch.weights.fight[1] = 100
	var third_kit := StitchedS14Abilities.kits()
	var third_patch := StitchedS14Abilities.patches()
	_check(third_kit.warden.head.effects.mark == expected_mark
		and third_kit.warden.head != rekit.warden.head,
		"warm kits() read mutations never leak into a third read")
	_check(third_patch.by_id.cotton_red_lint.effect == expected_effect
		and third_patch.weights.fight == expected_fight
		and third_patch.by_id.cotton_red_lint != repatch.by_id.cotton_red_lint,
		"warm patches() read mutations never leak into a third read")
	var command := StitchedS14Abilities.ability("warden", "warden_head_pot_helm_command")
	_check(not command.is_empty() and command.effects.mark == expected_mark,
		"ability() still serves the authored head command after mutation attempts")
	_check(StitchedS14Abilities.socket_limit(["gold_chain_thread", "wool_mark_thread"]) == 2
		and StitchedS14Abilities.socket_limit(["cotton_red_lint", "wool_mark_thread"]) == 1,
		"legal socket limits still follow the authored catalog after mutation attempts")
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 8123
	var draws_a: Array = []
	for index in 5:
		draws_a.append(StitchedS14Abilities.draw_patch(rng_a, "fight"))
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 8123
	var draws_b: Array = []
	for index in 5:
		draws_b.append(StitchedS14Abilities.draw_patch(rng_b, "fight"))
	_check(draws_a == draws_b and rng_a.state == rng_b.state,
		"same-seed patch draws stay authored with no extra RNG consumption")
	kits = StitchedS14Abilities.kits()
	patches = StitchedS14Abilities.patches()
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
	# Owner 11-10: a harmful patch on a heal goes to the front foe, never the healed ally.
	_check(battle.get_unit("warden").hp > int(target.max_hp) - 9
		and not battle.get_unit("warden").statuses.has("bleed")
		and int(battle._living_foes()[0].statuses.get("bleed", 0)) > 0,
		"harmful bleed patch on HEAL spares the healed ally and bleeds the front foe")
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


func _event_node_id(run: StitchedRunSession) -> String:
	for id in run.choices():
		if run.map.get_node(id).type == "Event":
			return id
	return ""


## S14: a successful Event whose only changed party material is a living doll's
## base/effective maximum HP is a genuinely consequential choice and carries the
## seeded event-source ability patch; a neutral Leave or a refused request never
## does. The visit is a real pinned authenticated route Event.
func _event_max_hp_patch() -> void:
	var seeds: Array = [234]
	for seed_number in 80:
		seeds.append(seed_number)
	var found := -1
	for seed_number in seeds:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		if not _event_node_id(candidate).is_empty():
			found = seed_number
			break
	_check(found >= 0, "seeded route exposes an Event node for the S14 material gate")
	if found < 0:
		return
	StitchedRunSession.pinned_event_id = "v3_warden_buckle_heart_ward"
	_event_max_hp_live(found)
	_event_max_hp_positive(found)
	_event_max_hp_negative(found)
	StitchedRunSession.pinned_event_id = ""


## The shipped warden crossroad itself: its authored lasting max-HP rivet
## trade is material through the real vital-seam service on the live route, and
## the whole changed run replays from an authenticated save.
func _event_max_hp_live(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "live pinned Event session starts")
		return
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "live pinned Event visit mounts the warden crossroad")
		return
	_check(run.pending.service == "Event" and run._service is RunStitchedHeroVitalSeams
		and run.pending.event_id == "v3_warden_buckle_heart_ward",
		"authenticated Event visit serves the real seam service")
	var warden := {}
	var gold_before := run.gold
	for hero in run.heroes:
		if str(hero.id) == "warden":
			warden = hero
	if warden.is_empty() or bool(warden.lost):
		_check(false, "living Warden doll carries the authored rivet trade")
		return
	var base_before := int(warden.base_max_hp)
	var max_before := int(warden.max_hp)
	_check(run.choose_visit("sell_rivets", [], run.snapshot()),
		"authored max-HP rivet trade commits through the public visit path")
	var seam := {}
	for hero in run.heroes:
		if str(hero.id) == "warden":
			seam = hero
	_check(int(seam.base_max_hp) == base_before - 2 and int(seam.max_hp) == max_before - 2
		and run.gold == gold_before + 24,
		"authored rivet trade lowers the living doll's maximum HP for gold")
	_check(run.ability_inventory.size() == 1 and run.journal.back().has("ability_patch"),
		"live material Event choice awards exactly one ability patch")
	var document := StitchedRunSave.capture(run)
	var restored := StitchedRunSave.restore(document)
	_check(not document.is_empty() and restored != null
		and restored.snapshot() == run.snapshot(),
		"changed Event result replays with identical max HP, patch, serial, journal and RNG")


## A max-HP-only consequence (no wallet, HP, fray or part change) grants exactly
## one catalog-valid event-source patch with a new inventory serial and stamps
## the journal. The replay roundtrip is proven in _event_max_hp_live on the
## authored seam, because restore replays journal commands through the real
## services, which a test-only fixture cannot reproduce by design.
func _event_max_hp_positive(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "max-HP-only Event session starts")
		return
	run.scraps = 5
	run._seal()
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "max-HP-only Event visit mounts")
		return
	var warden := {}
	for hero in run.heroes:
		if str(hero.id) == "warden":
			warden = hero
	if warden.is_empty() or bool(warden.lost):
		_check(false, "living Warden doll carries the max-HP-only seam")
		return
	var base_before := int(warden.base_max_hp)
	var max_before := int(warden.max_hp)
	var hp_before := int(warden.hp)
	var rng_before := run.rng.state
	# The offered action stays the mounted authored one; the bounded fixture
	# service resolves it with a wallet-untouched +3 maximum-HP receipt.
	run._service = MaxHpOnlyEventService.new(node_id, "reinforce_shield_seam",
		{"gold": run.gold, "scraps": run.scraps})
	var before := run.snapshot()
	_check(run.choose_visit("reinforce_shield_seam", [], before),
		"max-HP-only Event choice commits through the public visit path")
	var seam := {}
	for hero in run.heroes:
		if str(hero.id) == "warden":
			seam = hero
	_check(int(seam.base_max_hp) == base_before + 3 and int(seam.max_hp) == max_before + 3
		and int(seam.hp) == hp_before
		and run.gold == before.gold and run.scraps == before.scraps,
		"the committed consequence changes only the living doll's maximum HP")
	_check(run.ability_inventory.size() == 1 and run.ability_serial == 1
		and int(run.ability_inventory[0].uid) == 1,
		"max-HP-only Event material grants exactly one patch with a new serial")
	var patches := StitchedS14Abilities.patches()
	_check(patches.by_id.has(run.ability_inventory[0].id)
		and run.ability_inventory[0].rarity in StitchedS14Abilities.RARITIES,
		"the event-source reward is a catalog-valid ability patch")
	var command: Dictionary = run.journal.back()
	_check(str(command.get("action", "")) == "visit"
		and command.get("ability_patch", {}) == run.ability_inventory[0],
		"the reward rides the committed visit journal entry")
	_check(run.receipts.size() == 1 and run.receipts[0].decision == "reinforce_shield_seam"
		and run.receipts[0].event_id == "v3_warden_buckle_heart_ward",
		"the committed Event leaves its node receipt")
	_check(run.rng.state != rng_before, "the reward consumed the run's seeded reward RNG")
	_check(run.is_consistent(),
		"max-HP-only Event result leaves the run sealed and consistent")


## A truly neutral Leave and stale or forged requests grant nothing and spend
## no reward RNG: inventory, serial, journal, wallet and sealed state survive.
func _event_max_hp_negative(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "neutral Event session starts")
		return
	var stale := run.snapshot()
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "neutral Event visit mounts for refusal checks")
		return
	var sealed := run.snapshot()
	var rng_before := run.rng.state
	var journal_size := run.journal.size()
	_check(not run.choose_visit("leave", [], stale),
		"stale expected snapshot is refused before any Event work")
	_check(not run.choose_visit("forged_choice", [], sealed)
		and not run.choose_visit("leave", ["bogus"], sealed),
		"unoffered or argument-forged Event choices are refused")
	_check(sealed == run.snapshot() and rng_before == run.rng.state
		and run.ability_inventory.is_empty() and run.ability_serial == 0
		and run.journal.size() == journal_size,
		"refused Event requests change no inventory, serial, journal, wallet or RNG")
	_check(run.choose_visit("leave", [], sealed),
		"neutral Leave commits through the public visit path")
	_check(run.ability_inventory.is_empty() and run.ability_serial == 0
		and run.gold == sealed.gold and run.scraps == sealed.scraps
		and run.rng.state == rng_before
		and not run.journal.back().has("ability_patch"),
		"neutral Leave grants no patch, spends no reward RNG and keeps the wallet")


## S14/S9a: an authenticated fear-bearing Event choice is genuinely consequential
## material. It settles Wren's fear through the run's one ledger exactly once and
## carries the seeded event-source ability patch, while a Leave, a clamped
## no-change outcome or any refused request grants nothing and draws no reward
## RNG. The visit is the real pinned authenticated Keyhole Choir.
func _event_fear_patch() -> void:
	var seeds: Array = [234]
	for seed_number in 80:
		seeds.append(seed_number)
	var found := -1
	for seed_number in seeds:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		if not _event_node_id(candidate).is_empty():
			found = seed_number
			break
	_check(found >= 0, "seeded route exposes an Event node for the S14 fear gate")
	if found < 0:
		return
	StitchedRunSession.pinned_event_id = "v3_keyhole_choir"
	_event_fear_live(found)
	_event_fear_only_patch(found)
	_event_fear_negative(found)
	_event_fear_replay(found)
	StitchedRunSession.pinned_event_id = ""


## The shipped Keyhole Choir itself: its authored buy_silence bargain quiets
## Wren from 20 to 12, eases every living doll's fray by the authored 12, spends
## its two scraps and earns the event patch, all through the real service on the
## live route. Save/replay is proven separately in _event_fear_replay, because a
## replay rebuilds the run from its journal alone and cannot reproduce the
## test-authored opening fear/fray state (the same reason _event_max_hp_positive
## keeps its own fixture out of the roundtrip).
func _event_fear_live(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "live pinned choir session starts")
		return
	run.scraps = 2
	run._kid_fear.reset(20)
	for hero in run.heroes:
		hero.fray = 20
	run._seal()
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "live pinned choir visit mounts the Keyhole Choir")
		return
	_check(run.pending.service == "Event" and run._service is RunStitchedEventConsequence
		and run.pending.event_id == "v3_keyhole_choir",
		"authenticated choir visit serves the real Event consequence service")
	var offered_silence := false
	for offered in run.visit_actions():
		if offered.id == "buy_silence":
			offered_silence = bool(offered.enabled)
	_check(offered_silence, "authored buy_silence bargain is offered and enabled")
	var sequence_before: int = run._kid_fear.get_sequence()
	var rng_before := run.rng.state
	var snapshot_before := run.snapshot()
	_check(run.choose_visit("buy_silence", [], snapshot_before),
		"authored buy_silence commits through the public visit path")
	_check(run.kid_fear() == 12 and run._kid_fear.get_sequence() == sequence_before + 1,
		"authored choir silence quiets Wren from 20 to 12 through one ledger step")
	_check(run.scraps == 0, "authored choir silence spends its two scraps")
	for hero in run.heroes:
		if not hero.lost:
			_check(int(hero.fray) == 8, "authored choir silence eases every living doll's fray by 12")
	_check(run.ability_inventory.size() == 1 and run.ability_serial == 1
		and int(run.ability_inventory[0].uid) == 1
		and run.journal.back().has("ability_patch"),
		"live fear-bearing Event choice awards exactly one ability patch")
	var patches := StitchedS14Abilities.patches()
	_check(patches.by_id.has(run.ability_inventory[0].id)
		and run.ability_inventory[0].rarity in StitchedS14Abilities.RARITIES,
		"the live fear-driven reward is a catalog-valid ability patch")
	_check(run.rng.state != rng_before, "the live fear-driven reward consumed the run's seeded reward RNG")
	_check(run.receipts.size() == 1 and run.receipts[0].decision == "buy_silence"
		and run.receipts[0].event_id == "v3_keyhole_choir",
		"the committed choir silence leaves its node receipt")
	_check(run.phase == "map" and run.is_consistent(),
		"the concluded choir visit returns sealed to the map")


## A fear-only consequence (no wallet, HP, fray or part change) grants exactly
## one catalog-valid event-source patch with a new inventory serial and stamps
## the journal; a pending Lose the Strings interruption survives the relief, and
## a clamped no-change outcome grants nothing and draws no reward RNG. The
## mounted choir keeps offering its real actions; only the service is swapped
## for a real RunStitchedEventConsequence carrying a minimal validated record,
## because the shipped catalog has no fear-only outcome.
func _event_fear_only_patch(seed_number: int) -> void:
	var record := {
		"id": "v3_hush_the_hum_fixture",
		"title": "Hush the Hum",
		"description": "A test-only fear bargain keeping the real service contract.",
		"choices": [
			{"id": "buy_silence", "text": "Hush the humming (quiet Wren)",
				"stitched_effect": {"target": "party", "candle": 0, "fray": 0, "fear": -6}},
			{"id": "leave", "text": "Leave the humming behind",
				"stitched_effect": {"target": "party", "candle": 0, "fray": 0}},
		],
	}
	_check(RunStitchedEventConsequence.new(record).is_valid(),
		"fear-only fixture record passes the real Event envelope validation")
	# 1. Fear-only material change carries the patch.
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "fear-only Event session starts")
		return
	run.scraps = 5
	run._kid_fear.reset(30)
	run._seal()
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "fear-only Event visit mounts")
		return
	run._service = RunStitchedEventConsequence.new(record)
	var before := run.snapshot()
	var rng_before := run.rng.state
	var sequence_before: int = run._kid_fear.get_sequence()
	var fray_before: Array = []
	for hero in run.heroes:
		fray_before.append(int(hero.fray))
	_check(run.choose_visit("buy_silence", [], before),
		"fear-only Event choice commits through the public visit path")
	_check(run.kid_fear() == 24 and run._kid_fear.get_sequence() == sequence_before + 1
		and run.scraps == before.scraps and run.gold == before.gold
		and run.candle == before.candle,
		"the committed consequence changes only Wren's fear through one ledger step")
	for index in run.heroes.size():
		_check(int(run.heroes[index].fray) == fray_before[index],
			"the committed fear-only consequence leaves every doll's fray untouched")
	_check(run.ability_inventory.size() == 1 and run.ability_serial == 1
		and int(run.ability_inventory[0].uid) == 1,
		"fear-only Event material grants exactly one patch with a new serial")
	var patches := StitchedS14Abilities.patches()
	_check(patches.by_id.has(run.ability_inventory[0].id)
		and run.ability_inventory[0].rarity in StitchedS14Abilities.RARITIES,
		"the fear-only reward is a catalog-valid ability patch")
	var command: Dictionary = run.journal.back()
	_check(str(command.get("action", "")) == "visit"
		and command.get("ability_patch", {}) == run.ability_inventory[0],
		"the fear-only reward rides the committed visit journal entry")
	_check(run.rng.state != rng_before, "the fear-only reward consumed the run's seeded reward RNG")
	_check(run.is_consistent(), "fear-only Event result leaves the run sealed and consistent")

	# 2. A pending Lose the Strings interruption survives fear relief.
	var shaken := StitchedRunSession.start(seed_number)
	if shaken == null:
		_check(false, "pending-interruption choir session starts")
		return
	shaken.scraps = 5
	shaken._kid_fear.reset(100)
	shaken._seal()
	node_id = _event_node_id(shaken)
	if not shaken.enter(node_id, shaken.snapshot()) or shaken.phase != "visit":
		_check(false, "pending-interruption choir visit mounts")
		return
	shaken._service = RunStitchedEventConsequence.new(record)
	_check(shaken.choose_visit("buy_silence", [], shaken.snapshot()),
		"fear relief commits while the interruption is pending")
	_check(shaken.kid_fear() == 94 and shaken._kid_fear.has_pending_lost_strings()
		and shaken.ability_inventory.size() == 1,
		"fear relief below 100 never cancels the pending interruption and still earns the patch")

	# 3. A clamped no-change outcome grants nothing and draws no reward RNG.
	var calm := StitchedRunSession.start(seed_number)
	if calm == null:
		_check(false, "clamped no-change choir session starts")
		return
	calm.scraps = 5
	calm._kid_fear.reset(0)
	for hero in calm.heroes:
		hero.fray = 1
	calm._seal()
	node_id = _event_node_id(calm)
	if not calm.enter(node_id, calm.snapshot()) or calm.phase != "visit":
		_check(false, "clamped no-change choir visit mounts")
		return
	calm._service = RunStitchedEventConsequence.new(record)
	var calm_before: Dictionary = calm.snapshot()
	var calm_rng := calm.rng.state
	var calm_sequence: int = calm._kid_fear.get_sequence()
	var calm_journal := calm.journal.size()
	_check(calm.choose_visit("buy_silence", [], calm_before),
		"clamped no-change Event choice still commits")
	_check(calm.kid_fear() == 0 and calm._kid_fear.get_sequence() == calm_sequence + 1,
		"the clamped fear floor advances the ledger without changing fear")
	_check(calm.ability_inventory.is_empty() and calm.ability_serial == 0
		and calm.journal.size() == calm_journal + 1
		and not calm.journal.back().has("ability_patch")
		and calm.scraps == calm_before.scraps and calm.rng.state == calm_rng,
		"a clamped no-change Event outcome grants no patch and draws no reward RNG")
	_check(calm.is_consistent(), "the clamped no-change Event result stays sealed and consistent")


## Underfunded, stale and forged choir requests change nothing: Wren's ledger,
## the wallet, the patch inventory, the journal and the reward RNG all survive.
## A neutral Leave grants nothing, and a consequential fear-free choice keeps
## its authored behaviour without ever touching the fear ledger.
func _event_fear_negative(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "refusal choir session starts")
		return
	var stale := run.snapshot()
	run.scraps = 1
	run._kid_fear.reset(20)
	run._seal()
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "refusal choir visit mounts for refusal checks")
		return
	var sealed := run.snapshot()
	var rng_before := run.rng.state
	var journal_size := run.journal.size()
	var ledger_before: Dictionary = run._kid_fear.state_snapshot()
	var silence_offered := false
	var underfunded := false
	for offered in run.visit_actions():
		if offered.id == "buy_silence":
			silence_offered = true
			underfunded = not bool(offered.enabled)
	_check(silence_offered and underfunded, "the underfunded choir bargain is offered but disabled")
	_check(not run.choose_visit("buy_silence", [], sealed),
		"the underfunded choir choice is refused")
	_check(not run.choose_visit("buy_silence", [], stale),
		"stale expected snapshot is refused before any Event work")
	_check(not run.choose_visit("forged_choice", [], sealed)
		and not run.choose_visit("leave", ["bogus"], sealed),
		"unoffered or argument-forged choir choices are refused")
	_check(sealed == run.snapshot() and rng_before == run.rng.state
		and run.ability_inventory.is_empty() and run.ability_serial == 0
		and run.journal.size() == journal_size
		and run._kid_fear.state_snapshot() == ledger_before,
		"refused choir requests change no ledger, wallet, inventory, journal or RNG")
	_check(run.choose_visit("leave", [], sealed),
		"neutral choir Leave commits through the public visit path")
	_check(run.kid_fear() == 20 and run._kid_fear.get_sequence() == int(ledger_before["sequence"])
		and run.ability_inventory.is_empty() and run.ability_serial == 0
		and run.scraps == sealed.scraps and run.rng.state == rng_before
		and not run.journal.back().has("ability_patch"),
		"neutral choir Leave keeps the fear ledger and grants no patch or RNG spend")

	# A consequential fear-free choice keeps its authored behaviour and never
	# touches Wren's ledger.
	var humming := StitchedRunSession.start(seed_number)
	if humming == null:
		_check(false, "fear-free choir session starts")
		return
	humming.candle = 40
	humming.scraps = 5
	humming._kid_fear.reset(20)
	humming._seal()
	node_id = _event_node_id(humming)
	if not humming.enter(node_id, humming.snapshot()) or humming.phase != "visit":
		_check(false, "fear-free choir visit mounts")
		return
	var ledger_free: Dictionary = humming._kid_fear.state_snapshot()
	_check(humming.choose_visit("follow_humming", [], humming.snapshot()),
		"fear-free choir choice commits through the public visit path")
	_check(humming.kid_fear() == 20
		and humming._kid_fear.state_snapshot() == ledger_free,
		"the fear-free choir choice never touches Wren's fear ledger")
	_check(humming.ability_inventory.size() == 1,
		"the fear-free consequential choice still earns its event patch")


## Authenticated save/replay around the Event: the whole compared snapshot
## carries Wren's fear ledger, the patch inventory and serial, the journal and
## the RNG, and a re-digested fear forgery fails closed. The replay rebuilds a
## run from its journal alone, so the roundtrip rides the real pure-command
## route (the mounted choir's own Leave) rather than test-authored fear state;
## the visit command replays through the same choose_visit/_choose_event path
## the fear settlement lives in.
func _event_fear_replay(seed_number: int) -> void:
	var run := StitchedRunSession.start(seed_number)
	if run == null:
		_check(false, "replay choir session starts")
		return
	var node_id := _event_node_id(run)
	if not run.enter(node_id, run.snapshot()) or run.phase != "visit":
		_check(false, "replay choir visit mounts")
		return
	_check(run.choose_visit("leave", [], run.snapshot()),
		"pure-command choir Leave commits for the save/replay roundtrip")
	var settled := run.snapshot()
	var document := StitchedRunSave.capture(run)
	var restored := StitchedRunSave.restore(document)
	_check(not document.is_empty() and restored != null
		and restored.snapshot() == settled and restored.is_consistent(),
		"authenticated Event save/replay reproduces ledger, inventory, serial, journal and RNG")
	var corrupt := document.duplicate(true)
	corrupt.state.kid_fear.fear = 12
	corrupt.digest = StitchedRunSave._digest(corrupt)
	_check(StitchedRunSave.restore(corrupt) == null and run.snapshot() == settled,
		"rehashed fear ledger forgery fails closed")


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
				if offered.cost == "limb" and hero.parts.legs.torn:
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
			and ally.get_unit("tinker").rank == 3 and ally.get_unit(other.id).rank == 3 + direction
			and ally.get_unit("tinker").hp > before_hp,
			"ally-targeted " + patch_id + " heals the ally and never drags it about")

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


## Chain Thread is a second phase of a real hero action, not one jump per
## primary target; movement cannot change the original successor identity.
func _chain_thread() -> void:
	var bomb_sockets := {"tinker": {"tinker_arms_scrap_bomb": ["gold_chain_thread"]}}
	var bomb := _battle(55, bomb_sockets)
	var plain := _battle(55)
	if bomb == null or plain == null:
		return
	var foes := bomb.get_foes()
	_check(foes.size() >= 2 and foes.all(func(foe: Dictionary) -> bool:
		return not foe.dead and int(foe.hp) > 0), "chain bomb has multiple real living foes")
	if foes.size() < 2:
		return
	var gold_result := _shift_turn(bomb, "tinker", "tinker_arms_scrap_bomb", 2)
	var plain_result := _shift_turn(plain, "tinker", "tinker_arms_scrap_bomb", 2)
	var seen := {}
	for hit in gold_result.get("results", []):
		seen[hit.target] = int(seen.get(hit.target, 0)) + 1
		_check(not hit.get("chained", false) and hit.statuses.filter(func(s: Dictionary) -> bool:
			return s.get("status") == "exposed").size() <= 1,
			"each bomb primary has no duplicate chain or Exposed stamp")
	_check(gold_result.get("ok", false) and plain_result.get("ok", false)
		and gold_result.results == plain_result.results and gold_result.results.size() == foes.size()
		and seen.size() == foes.size() and seen.values().all(func(count: int) -> bool: return count == 1)
		and bomb.current_actor_id() == "warden",
		"gold multi-hit bomb has exactly one unmodified base result per foe and spends one action")
	for foe in foes:
		_check(bomb.get_unit(foe.id).hp == plain.get_unit(foe.id).hp
			and bomb.get_unit(foe.id).statuses == plain.get_unit(foe.id).statuses,
			"chain bomb does not double damage or reapply primary status to " + str(foe.id))
	_check(bomb.rng_state() == plain.rng_state(),
		"gold multi-hit bomb draws exactly the same RNG as unsocketed Scrap Bomb")

	for movement in ["", "wool_heel_knot", "wool_hook_stitch"]:
		var ids := ["gold_chain_thread"]
		if not movement.is_empty():
			ids.append(movement)
		var sockets := {"warden": {"warden_head_pot_helm_command": ids}}
		var battle := _battle(55, sockets)
		if battle == null:
			return
		var first := battle._foe_at(2)
		var successor := battle._foe_at(3)
		var prior_front := battle._foe_at(1)
		_check(not first.is_empty() and not successor.is_empty() and first.id != successor.id,
			"chain single-target precondition: real distinct living adjacent foes")
		if first.is_empty() or successor.is_empty():
			return
		var result := _shift_turn(battle, "warden", "warden_head_pot_helm_command", 2)
		_check(result.get("ok", false) and result.results.size() == 2
			and result.results[0].target == first.id and result.results[0].hit
			and result.results[1].target == successor.id and result.results[1].get("chained", false)
			and result.results[1].hit and battle.current_actor_id() == "seamstress",
			"gold chain " + movement + " follows just the originally adjacent distinct foe")
		_check(battle.get_unit(first.id).statuses.get("mark", 0) > 0
			and battle.get_unit(successor.id).statuses.get("mark", 0) > 0,
			"authored Mark lands on both successful hits with " + movement)
		if not movement.is_empty() and result.results.size() == 2:
			_check(result.results[1].get("shift", {}).get("ok", false),
				"second successful Chain Thread hit retains its movement patch " + movement)
			_check(result.results[0].get("shift", {}).get("swapped") ==
				(str(successor.id) if movement == "wool_heel_knot" else str(prior_front.id)),
				"socket movement actually fires before chain selection " + movement)

	var paired_sockets := {"warden": {"warden_head_pot_helm_command":
		["gold_chain_thread", "wool_heel_knot"]}}
	var original := _battle(55, paired_sockets)
	var replay := _battle(55, paired_sockets)
	if original == null or replay == null:
		return
	var first_cast := _shift_turn(original, "warden", "warden_head_pot_helm_command", 2)
	var second_cast := _shift_turn(replay, "warden", "warden_head_pot_helm_command", 2)
	_check(first_cast == second_cast and original.state_snapshot() == replay.state_snapshot()
		and original.rng_state() == replay.rng_state(),
		"equal-seed chain plus movement replay preserves receipts, full state and RNG")

	var chain_only := {"warden": {"warden_head_pot_helm_command": ["gold_chain_thread"]}}
	for scenario in ["miss", "no_successor", "rank_mask"]:
		var chained := _battle(55, chain_only)
		var baseline := _battle(55)
		if chained == null or baseline == null:
			return
		var rank := 2
		if scenario == "miss":
			chained._units["warden"].statuses["blind"] = 1
			baseline._units["warden"].statuses["blind"] = 1
		elif scenario == "no_successor":
			for instance in [chained, baseline]:
				var last: Dictionary = instance._foe_at(3)
				_check(not last.is_empty(), "real last foe exists before lethal no-successor setup")
				if not last.is_empty():
					instance._damage_target(last, int(last.hp), {})
		else:
			# Move the originally next foe out to rank four, beyond Pot Helm's
			# authored target mask, before selecting the rank-two primary.
			for instance in [chained, baseline]:
				var last: Dictionary = instance._foe_at(3)
				_check(not last.is_empty(), "rank-mask setup has a real back foe")
				if not last.is_empty():
					var moved: Dictionary = instance._gift_shift(last, 1)
					_check(moved.get("ok", false) and int(last.rank) == 4,
						"authentic shift makes next foe rank-ineligible")
		var with_chain := _shift_turn(chained, "warden", "warden_head_pot_helm_command", rank)
		var without := _shift_turn(baseline, "warden", "warden_head_pot_helm_command", rank)
		_check(with_chain.get("ok", false) and without.get("ok", false)
			and with_chain.results.size() == 1 and with_chain.results == without.results
			and chained.rng_state() == baseline.rng_state(),
			"chain " + scenario + " adds no hit or extra RNG")
		if scenario == "miss":
			_check(not with_chain.results[0].hit and not with_chain.results[0].has("chained"),
				"blind primary miss cannot launch chain")

	var invalid := _config(55)
	invalid.s14_sockets = {"warden": {"warden_head_pot_helm_command":
		["gold_chain_thread", "made_up_patch"]}}
	_check(not StitchedRules.create(invalid).ok, "unknown socket still fails closed")
	var masked := _battle(55, chain_only)
	if masked != null:
		masked._order = ["warden", "seamstress"]
		masked._turn_index = 0
		var before := masked.state_snapshot()
		_check(not masked.use_ability("warden_head_pot_helm_command", 4).ok
			and before == masked.state_snapshot(), "illegal chain target mask refuses without state or RNG")
