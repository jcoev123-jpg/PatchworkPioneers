extends "res://tests/stitched_s14_rules_gate_test.gd"
## A real seeded Elite victory offers a door; leaving it is a replayable decline.


func _initialize() -> void:
	_departure()
	for message in failures:
		printerr(message)
	print("stitched_s14_side_door_departure_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _departure() -> void:
	var original: StitchedRunSession
	var next_id := ""
	var combat_id := ""
	for seed_number in 120:
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
				if offer.cost == "limb" and hero.parts.arms.torn:
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
