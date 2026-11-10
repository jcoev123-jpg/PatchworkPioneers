extends "res://tests/stitched_s14_rules_gate_test.gd"
## A real seeded Elite victory offers a door; leaving it is a replayable decline.


func _initialize() -> void:
	_departure()
	_leg_trade()
	_leg_payer_provider()
	_all_torn_real_victory()
	for message in failures:
		printerr(message)
	print("stitched_s14_side_door_departure_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _departure() -> void:
	var original: StitchedRunSession
	var next_id := ""
	var combat_id := ""
	# Owner 11-10: the retired fear trade is suppressed after its weighted draw, so
	# fear-weighted picks now offer no door; the witness search needs a wider range.
	for seed_number in 400:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		var elite_id := ""
		for id in candidate.choices():
			if candidate.map.get_node(id).type == "Elite":
				elite_id = id
				break
		if elite_id.is_empty() or not candidate.enter(elite_id, candidate.snapshot()):
			continue
		if not _play_live_battle(candidate) or candidate.battle.outcome() != "victory" \
				or not candidate.settle_battle(candidate.battle) or candidate.door_offer.is_empty():
			continue
		for id in candidate.choices():
			if candidate.map.get_node(id).type in ["Fight", "Elite"]:
				combat_id = id
			if next_id.is_empty() or candidate.map.get_node(id).type not in ["Fight", "Elite", "Boss"]:
				next_id = id
		if not next_id.is_empty() and not combat_id.is_empty():
			original = candidate
			break
		next_id = ""
		combat_id = ""
	_check(original != null and not next_id.is_empty() and not combat_id.is_empty(),
		"seeded real Elite victory has a door offer and legal next route including combat")
	if original == null:
		return
	var offer: Dictionary = original.door_offer.duplicate(true)
	var departure_node: String = original.map.get_current_node_id()
	var prior: Dictionary = original.snapshot()
	var prior_journal: Array = original.journal.duplicate(true)
	var saved := StitchedRunSave.capture(original)
	_check(offer.get("node_id") == departure_node and not saved.is_empty()
		and original.phase == "map" and original.choices().has(next_id),
		"nonempty real Elite door belongs to the current node, with an offered legal departure")
	if saved.is_empty():
		return

	var stale := prior.duplicate(true)
	stale.gold += 1
	var invalid := not original.enter(next_id, stale) and not original.enter("forged_node", prior) \
		and not original.choose_door(str(offer.id), "", stale)
	_check(invalid and original.snapshot() == prior and original.journal == prior_journal
		and original.rng.state == prior.rng,
		"stale state, nonexistent route and stale claim preserve door, wallet, RNG and journal")

	# A genuinely failed _open_battle, after choose_node, must roll back without declining.
	var broken := StitchedRunSave.restore(saved)
	_check(broken != null and broken.choices().has(combat_id), "failed-entry witness restores a real combat route")
	if broken != null:
		broken.enemies = {"order": [], "enemies": {}}
		var failed_before := broken.snapshot()
		var failed_journal := broken.journal.duplicate(true)
		_check(not broken.enter(combat_id, failed_before) and broken.snapshot() == failed_before
			and broken.journal == failed_journal and broken.door_offer == offer
			and broken.rng.state == failed_before.rng and broken.is_consistent(),
			"failed combat setup rolls route, candle and pending state back with the side door intact")

	var explicit := StitchedRunSave.restore(saved)
	_check(explicit != null, "offered run can restore before an explicit decline")
	if explicit == null:
		return
	_check(explicit.choose_door("", "", explicit.snapshot())
		and explicit.door_offer.is_empty() and explicit.door_history.size() == 1
		and explicit.door_history[0] == {"id": "", "node_id": departure_node}
		and explicit.journal.back() == {"action": "door", "id": "", "hero": ""},
		"explicit decline records one canonical history entry")
	_check(explicit.enter(next_id, explicit.snapshot()), "explicit decline leaves the route usable")
	_check(original.enter(next_id, prior), "implicit departure successfully enters the next authentic node")
	var after := original.snapshot()
	_check(after.s14.door_offer.is_empty() and after.s14.door_history == [{"id": "", "node_id": departure_node}]
		and original.is_consistent() and original.journal.size() == prior_journal.size() + 1
		and original.journal.back() == {"action": "enter", "node_id": next_id},
		"implicit skip clears the offer, records exactly one decline and journals only enter")
	_check(after == explicit.snapshot() and original.rng.state == explicit.rng.state
		and original.gold == explicit.gold and original.scraps == explicit.scraps
		and original.candle == explicit.candle and original.heroes == explicit.heroes
		and original.ability_inventory == explicit.ability_inventory,
		"explicit decline plus entry and implicit skip plus entry have identical ledgers, resources and RNG")
	var refused_before := original.snapshot()
	var refused_journal := original.journal.duplicate(true)
	_check(not original.choose_door(str(offer.id), "", refused_before)
		and not original.choose_door("", "", refused_before)
		and original.snapshot() == refused_before and original.journal == refused_journal,
		"old door cannot be claimed or declined after departure, without new effects")
	var document := StitchedRunSave.capture(original)
	var replayed := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document)))
	_check(not document.is_empty() and replayed != null and replayed.snapshot() == after
		and replayed.journal == original.journal and replayed.rng.state == original.rng.state,
		"capture/restore replays only the implicit enter and reproduces full S14 state, journal and 64-bit RNG")
	var forged := document.duplicate(true)
	forged.state.s14.door_history.clear()
	forged.digest = StitchedRunSave._digest(forged)
	_check(StitchedRunSave.restore(forged) == null and original.snapshot() == after,
		"rehashed forged decline history is rejected without affecting the genuine run")

	# A successful claim BEFORE leaving never adds an implicit decline.
	var claimed := StitchedRunSave.restore(saved)
	var claim_hero := ""
	if claimed != null:
		if offer.cost != "none" or offer.reward == "head_guard":
			for hero in claimed.heroes:
				if hero.lost:
					continue
				if offer.cost == "max_hp" and int(hero.base_max_hp) - int(offer.amount) < 10:
					continue
				if offer.cost == "limb" and hero.parts.legs.torn:
					continue
				claim_hero = hero.id
				break
		var can_claim: bool = offer.cost == "none" or not claim_hero.is_empty()
		if offer.cost == "fear":
			can_claim = can_claim and claimed.kid_fear() + int(offer.amount) <= 100
		if can_claim:
			var accepted := claimed.choose_door(str(offer.id), claim_hero, claimed.snapshot())
			_check(accepted, "actual Elite side door claim is accepted before entering the next node")
			if accepted:
				var history := claimed.door_history.duplicate(true)
				var inventory := claimed.ability_inventory.duplicate(true)
				var claimed_journal_size := claimed.journal.size()
				_check(claimed.enter(next_id, claimed.snapshot()) and claimed.door_history == history
					and claimed.door_history.size() == 1 and claimed.door_offer.is_empty()
					and claimed.ability_inventory == inventory and claimed.journal.size() == claimed_journal_size + 1,
					"claimed door keeps its reward and history; next entry adds no duplicate decline")
				var claimed_saved := StitchedRunSave.capture(claimed)
				var claimed_replay := StitchedRunSave.restore(claimed_saved)
				_check(claimed_replay != null and claimed_replay.snapshot() == claimed.snapshot()
					and claimed_replay.journal == claimed.journal and claimed_replay.rng.state == claimed.rng.state,
					"claimed-door departure also replays with identical rewards, journal and RNG")

	_check(original.phase in ["visit", "battle", "walk"] and original.map.get_current_node_id() == next_id,
		"departed door does not block the real next encounter")
	if original.phase == "visit":
		var actions := original.visit_actions()
		var leave: Dictionary = {}
		for action in actions:
			if action.id == "leave" and action.enabled:
				leave = action
				break
		_check(not leave.is_empty(), "new visit is usable and offers its actual Leave action")
		if not leave.is_empty():
			_check(original.choose_visit(leave.id, leave.arguments, original.snapshot())
				and original.phase == "map" and original.is_consistent()
				and not original.choices().is_empty(),
				"the departed route can settle its next visit and progress again")
	elif original.phase == "battle":
		_check(original.battle != null and _play_live_battle(original) and original.battle.outcome() == "victory",
			"the next real ranked battle runs after the declined offer")
		if original.battle != null and original.battle.is_over():
			_check(original.settle_battle(original.battle) and original.is_consistent()
				and not original.choices().is_empty(),
				"the next ranked battle settles and exposes further legal routes")


## The leg bargain is reached from a seeded real Elite victory, never an
## injected offer. Both eligible and refused claims use the public transaction.
func _leg_trade() -> void:
	var session: StitchedRunSession
	var next_id := ""
	var hero_id := ""
	for seed_number in 300:
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		var elite_id := ""
		for id in candidate.choices():
			if candidate.map.get_node(id).type == "Elite":
				elite_id = id
				break
		if elite_id.is_empty() or not candidate.enter(elite_id, candidate.snapshot()):
			continue
		if not _play_live_battle(candidate) or candidate.battle.outcome() != "victory" \
				or not candidate.settle_battle(candidate.battle) \
				or str(candidate.door_offer.get("id", "")) != "underbed_leg_trade":
			continue
		var eligible := ""
		for hero in candidate.heroes:
			if not hero.lost and int(hero.hp) > 0 and hero.parts.has("legs") \
					and not hero.parts.legs.torn and not hero.parts.arms.torn:
				eligible = hero.id
				break
		if eligible.is_empty():
			continue
		var onward := ""
		for id in candidate.choices():
			onward = id
			break
		if onward.is_empty():
			continue
		session = candidate
		next_id = onward
		hero_id = eligible
		break
	_check(session != null and not next_id.is_empty() and not hero_id.is_empty(),
		"real seeded Elite victory offers the exact leg trade to a living doll with an onward route")
	if session == null:
		return
	var offer := session.door_offer.duplicate(true)
	var door_node := session.map.get_current_node_id()
	var hero_before: Dictionary = {}
	for hero in session.heroes:
		if hero.id == hero_id:
			hero_before = hero.duplicate(true)
			break
	_check(offer.get("id") == "underbed_leg_trade" and offer.get("cost") == "limb"
		and offer.get("reward") == "silk_patch" and offer.get("node_id") == door_node
		and session.phase == "map" and session.is_consistent()
		and not hero_before.is_empty() and not hero_before.lost and int(hero_before.hp) > 0
		and not hero_before.parts.legs.torn and not hero_before.parts.arms.torn,
		"authenticated underbed offer and live recipient start with both intact limbs")
	if hero_before.is_empty():
		return
	var saved := StitchedRunSave.capture(session)
	_check(not saved.is_empty(), "offered live leg bargain captures before any transaction")
	if saved.is_empty():
		return

	# An invalid claim must preserve the entire sealed offer, resources,
	# journal and run RNG, not merely refuse an inventory reward.
	_assert_leg_refusal(session, "forged_door", hero_id, session.snapshot(),
		"forged door id fails atomically")
	_assert_leg_refusal(session, "underbed_leg_trade", "missing_doll", session.snapshot(),
		"forged recipient fails atomically")
	var stale := session.snapshot()
	stale.gold += 1
	_assert_leg_refusal(session, "underbed_leg_trade", hero_id, stale,
		"stale expected state fails atomically")

	for blocked_case in ["torn_legs", "lost_doll", "wrong_node", "forged_offer"]:
		var refused := StitchedRunSave.restore(saved)
		_check(refused != null, blocked_case + " fixture restores from the actual offered run")
		if refused == null:
			continue
		var victim: Dictionary = {}
		for hero in refused.heroes:
			if hero.id == hero_id:
				victim = hero
				break
		_check(not victim.is_empty() and not victim.lost and not victim.parts.legs.torn,
			blocked_case + " fixture begins with an eligible live hero")
		if victim.is_empty():
			continue
		match blocked_case:
			"torn_legs":
				victim.parts.legs.torn = true
				var calc := StitchedRules.new()
				calc._parts = refused.catalog
				calc._s14 = true
				calc._recompute_stats(victim)
				victim.hp = mini(int(victim.hp), int(victim.max_hp))
			"lost_doll":
				victim.lost = true
				victim.hp = 0
			"wrong_node":
				refused.door_offer.node_id = "forged_node"
			"forged_offer":
				refused.door_offer.amount = 2
		refused._seal()
		_check(refused.is_consistent() and (blocked_case != "torn_legs" or victim.parts.legs.torn)
			and (blocked_case != "lost_doll" or victim.lost)
			and (blocked_case != "wrong_node" or refused.door_offer.node_id != door_node)
			and (blocked_case != "forged_offer" or refused.door_offer.amount != offer.amount),
			blocked_case + " controlled invalid precondition is sealed before the claim")
		_assert_leg_refusal(refused, "underbed_leg_trade", hero_id, refused.snapshot(),
			blocked_case + " rejects without spending, reseeding or consuming offer")

	# A previously torn arm is not this bargain's price or eligibility gate.
	var arm_torn := StitchedRunSave.restore(saved)
	_check(arm_torn != null, "torn-arm fixture restores from the real offer")
	if arm_torn != null:
		var arm_inventory_before := arm_torn.ability_inventory.size()
		var arm_victim: Dictionary = {}
		for hero in arm_torn.heroes:
			if hero.id == hero_id:
				arm_victim = hero
				break
		if not arm_victim.is_empty():
			arm_victim.parts.arms.torn = true
			var calc := StitchedRules.new()
			calc._parts = arm_torn.catalog
			calc._s14 = true
			calc._recompute_stats(arm_victim)
			arm_victim.hp = mini(int(arm_victim.hp), int(arm_victim.max_hp))
			arm_torn._seal()
		_check(not arm_victim.is_empty() and arm_torn.is_consistent()
			and arm_victim.parts.arms.torn and not arm_victim.parts.legs.torn,
			"controlled torn-arm fixture is valid and still has an intact leg")
		if not arm_victim.is_empty():
			_check(arm_torn.choose_door("underbed_leg_trade", hero_id, arm_torn.snapshot())
				and arm_victim.parts.arms.torn and arm_victim.parts.legs.torn
				and arm_torn.ability_inventory.size() == arm_inventory_before + 1
				and arm_torn.ability_inventory.back().rarity == "silk"
				and arm_torn.door_history.size() == 1 and arm_torn.underbed_taken,
				"an intact leg pays the real trade despite a pre-torn arm")

	var prior := session.snapshot()
	var prior_journal := session.journal.duplicate(true)
	var prior_rng := session.rng.state
	var prior_inventory_size := session.ability_inventory.size()
	var accepted := session.choose_door("underbed_leg_trade", hero_id, prior)
	_check(accepted, "authentic leg trade commits through public choose_door")
	if not accepted:
		return
	var paid: Dictionary = {}
	for hero in session.heroes:
		if hero.id == hero_id:
			paid = hero
			break
	var earned: Dictionary = session.door_history[0].get("reward", {}) if session.door_history.size() == 1 else {}
	_check(not paid.is_empty() and paid.parts.legs.torn
		and paid.parts.arms == hero_before.parts.arms and paid.base_max_hp == hero_before.base_max_hp
		and session.ability_inventory.size() == prior_inventory_size + 1
		and earned.get("rarity") == "silk" and earned == session.ability_inventory.back()
		and session.underbed_taken and session.door_history.size() == 1
		and session.door_history[0].id == "underbed_leg_trade"
		and session.door_history[0].hero == hero_id
		and session.door_offer.is_empty()
		and session.journal.size() == prior_journal.size() + 1
		and session.journal.back() == {"action": "door", "id": "underbed_leg_trade", "hero": hero_id}
		and session.is_consistent(),
		"paid trade tears only legs, grants one silk patch and journals exactly one underbed deal")
	if paid.is_empty():
		return
	var recomputed := paid.duplicate(true)
	var rules := StitchedRules.new()
	rules._parts = session.catalog
	rules._s14 = true
	rules._recompute_stats(recomputed)
	_check(paid.max_hp == recomputed.max_hp and paid.hp <= paid.max_hp
		and paid.dmg_bonus == recomputed.dmg_bonus,
		"paid limb injury immediately recomputes the real doll's combat stats")
	var committed := session.snapshot()
	_assert_leg_refusal(session, "underbed_leg_trade", hero_id, prior,
		"stale second payment cannot duplicate patch or history")
	_check(session.snapshot() == committed and session.rng.state == session.snapshot().rng,
		"spent trade remains sealed after rejected repeat")
	_check(session.choices().has(next_id) and session.enter(next_id, session.snapshot())
		and session.map.get_current_node_id() == next_id and session.is_consistent(),
		"paid leg bargain preserves legal onward entry without implicit decline")
	var after := session.snapshot()
	_check(after.s14.door_history.size() == 1 and after.s14.door_history[0].id == "underbed_leg_trade"
		and after.s14.inventory.size() == prior_inventory_size + 1
		and session.journal.back() == {"action": "enter", "node_id": next_id}
		and session.journal.size() == prior_journal.size() + 2,
		"onward entry keeps one leg payment and one reward with no duplicate underbed record")
	var document := StitchedRunSave.capture(session)
	var restored := StitchedRunSave.restore(bytes_to_var(var_to_bytes(document))) if not document.is_empty() else null
	_check(not document.is_empty() and restored != null and restored.snapshot() == after
		and restored.journal == session.journal and restored.rng.state == session.rng.state
		and restored.door_history.size() == 1 and restored.ability_inventory.size() == prior_inventory_size + 1,
		"paid leg, silk reward and onward visit or battle replay exactly with journal and RNG")


## The provider's leg-payer input: only the limb-cost Underbed deal leaves the pool, and every
## draw count, order and Attic/Elite rule is otherwise identical to the old behaviour.
func _leg_payer_provider() -> void:
	var seen_without := {}
	var seen_with := {}
	var identical := true
	var trajectory_same := true
	var attic_same := true
	var attic_seen := 0
	var elite_same := true
	var elite_admitted := 0

	for seed_number in 200:
		var base := RandomNumberGenerator.new()
		base.seed = seed_number
		var legacy := StitchedS14SideDoors.offer(base, "Boss", true)
		var yes := RandomNumberGenerator.new()
		yes.seed = seed_number
		var with_payer := StitchedS14SideDoors.offer(yes, "Boss", true, true)
		var replay := RandomNumberGenerator.new()
		replay.seed = seed_number
		var replayed := StitchedS14SideDoors.offer(replay, "Boss", true, true)
		var no := RandomNumberGenerator.new()
		no.seed = seed_number
		var without := StitchedS14SideDoors.offer(no, "Boss", true, false)
		identical = identical and legacy == with_payer and with_payer == replayed
		trajectory_same = trajectory_same and base.state == yes.state and yes.state == replay.state
		seen_with[str(with_payer.get("id", ""))] = true
		seen_without[str(without.get("id", ""))] = true

		# Attic path (underbed not yet taken): unaffected by the eligibility input.
		var a := RandomNumberGenerator.new()
		a.seed = seed_number
		var a_yes := StitchedS14SideDoors.offer(a, "Boss", false, true)
		var b := RandomNumberGenerator.new()
		b.seed = seed_number
		var b_no := StitchedS14SideDoors.offer(b, "Boss", false, false)
		if str(a_yes.get("kind", "")) == "attic":
			attic_seen += 1
			attic_same = attic_same and a_yes == b_no and a.state == b.state
		# Elite: the old 70% check is the first draw and is unchanged either way.
		var e := RandomNumberGenerator.new()
		e.seed = seed_number
		var e_yes := StitchedS14SideDoors.offer(e, "Elite", true, true)
		var f := RandomNumberGenerator.new()
		f.seed = seed_number
		var e_no := StitchedS14SideDoors.offer(f, "Elite", true, false)
		var check := RandomNumberGenerator.new()
		check.seed = seed_number
		var admitted := check.randi_range(1, 100) <= 70
		elite_same = elite_same and e_yes.is_empty() == (not admitted) and e_no.is_empty() == (not admitted)
		if admitted:
			elite_admitted += 1
			elite_same = elite_same and not e_no.is_empty() and str(e_no.get("id", "")) != "underbed_leg_trade"
	_check(identical and trajectory_same,
		"with a leg payer the offer and RNG trajectory equal the historical default, and replay identically")
	_check(seen_with.has("underbed_leg_trade") and seen_with.has("underbed_stuffing_trade")
		and seen_with.has("underbed_fear_trade"),
		"with a leg payer every Underbed deal, including the leg trade, stays reachable")
	_check(not seen_without.has("underbed_leg_trade") and seen_without.has("underbed_stuffing_trade")
		and seen_without.has("underbed_fear_trade"),
		"without a leg payer the leg trade is never offered while the other Underbed deals remain")
	_check(attic_seen > 0 and attic_same, "Attic offers and RNG are unaffected by leg eligibility")
	_check(elite_admitted > 0 and elite_same, "Elite 70% admission is unchanged and never offers an unpayable leg trade")

	# Per-ID catalog rows keep their costs and rewards.
	var doors := StitchedS14SideDoors.catalog()
	_check(doors.has("underbed_leg_trade") and doors.underbed_leg_trade.cost == "limb"
		and doors.underbed_leg_trade.amount == 1 and doors.underbed_leg_trade.reward == "silk_patch"
		and doors.underbed_stuffing_trade.cost == "max_hp" and doors.underbed_stuffing_trade.amount == 6
		and doors.underbed_stuffing_trade.reward == "gold_patch"
		and doors.underbed_fear_trade.cost == "fear" and doors.underbed_fear_trade.amount == 15
		and doors.underbed_fear_trade.reward == "wren_gift",
		"underbed rows keep their costs, amounts and reward IDs")
	_check(StitchedS14SideDoors.UNDERBED_WEIGHTS == {"gold_patch": 1, "silk_patch": 5, "wren_gift": 4},
		"original 1:5:4 weights are unchanged")


## Real seeded victorious Elite settlements with every doll's legs torn beforehand: the
## settled roster has no leg payer, so session.settle_battle never publishes the leg bargain.
func _all_torn_real_victory() -> void:
	var victories := 0
	var offers := 0
	var leg_offers := 0
	var roster_ok := true
	for seed_number in 80:
		if offers >= 2:
			break
		var candidate := StitchedRunSession.start(seed_number)
		if candidate == null:
			continue
		var elite_id := ""
		for id in candidate.choices():
			if candidate.map.get_node(id).type == "Elite":
				elite_id = id
				break
		if elite_id.is_empty():
			continue
		var calc := StitchedRules.new()
		calc._parts = candidate.catalog
		calc._s14 = true
		for hero in candidate.heroes:
			if hero.parts.has("legs"):
				hero.parts.legs.torn = true
			calc._recompute_stats(hero)
			hero.hp = mini(int(hero.hp), int(hero.max_hp))
		candidate._seal()
		if not candidate.is_consistent() or not candidate.enter(elite_id, candidate.snapshot()):
			continue
		if not _play_live_battle(candidate) or candidate.battle.outcome() != "victory" \
				or not candidate.settle_battle(candidate.battle):
			continue
		victories += 1
		for hero in candidate.heroes:
			if not hero.lost and hero.parts.has("legs") and not hero.parts.legs.torn:
				roster_ok = false
		if not candidate.door_offer.is_empty():
			offers += 1
			if str(candidate.door_offer.get("id", "")) == "underbed_leg_trade":
				leg_offers += 1
	_check(victories > 0 and roster_ok,
		"real victorious Elite settlements with torn legs have no leg payer in the settled roster")
	_check(leg_offers == 0, "no unpayable leg bargain is published after an all-torn real Elite victory")
	_check(offers > 0, "the all-torn real settlements still publish other legal side doors")


func _assert_leg_refusal(session: StitchedRunSession, door_id: String, hero_id: String,
		expected: Dictionary, label: String) -> void:
	var before := session.snapshot()
	var journal_before := session.journal.duplicate(true)
	var rng_before := session.rng.state
	_check(not session.choose_door(door_id, hero_id, expected)
		and session.snapshot() == before and session.journal == journal_before
		and session.rng.state == rng_before and session.is_consistent(),
		label)
