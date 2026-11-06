class_name StitchedRunSession
extends RefCounted
## The run owns every ledger, node receipt and random draw. Views borrow its battle.

signal changed

class RankedBattle extends StitchedRules:
	signal command_used(command: Dictionary)
	var owner_session: WeakRef

	func _admitted() -> bool:
		var session: StitchedRunSession = owner_session.get_ref() if owner_session != null else null
		return session != null and session.battle == self and session.phase == "battle" and session.is_consistent()

	func use_part(part_id: String, rank: int) -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.use_part(part_id, rank), "use_part", [part_id, rank])

	func use_foe_ability(ability_id: String, rank: int) -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.use_foe_ability(ability_id, rank), "use_foe_ability", [ability_id, rank])

	func move(direction: int) -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.move(direction), "move", [direction])

	func pass_turn() -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.pass_turn(), "pass_turn", [])

	func re_tie() -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.re_tie(), "re_tie", [])

	func retreat() -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.retreat(), "retreat", [])

	func _remember(result: Dictionary, method: String, arguments: Array) -> Dictionary:
		if result.get("ok") == true:
			command_used.emit({"action": "battle", "method": method, "arguments": arguments})
		return result

const VERSION := 1
const NODE_CANDLE_COST := 8
const SEWING_COST := 2
const PEDDLER_PRICE := 10
const CALM_PRICE := 75
const UNPICK_YIELD := 2
const DEFAULT_PICKS := ["warden", "seamstress", "tinker", "lantern_monk"]

var map: RunMap
var rng: RandomNumberGenerator
var battle: RankedBattle
var battle_config: Dictionary = {}
var heroes: Array = []
var satchel: Array = []
var patches: Array = []
var pockets: Dictionary = {}
var gold := 0
var scraps := 0
var candle := 100
var phase := "invalid"
var pending: Dictionary = {}
var receipts: Array = []
var journal: Array = []
var picks: Array = []
var seed_value := 0
var catalog: Dictionary = {}
var enemies: Dictionary = {}
var _initial: Dictionary = {}
var _sealed: Dictionary = {}
var _service: RefCounted
var _actions: Array = []
var _event_record: Dictionary = {}
var _replacement_visit: RunStitchedSewingReplacement
var _kid_fear: StitchedKidFear


static func start(seed_number: int, selected: Array = DEFAULT_PICKS, initial: Dictionary = {}) -> StitchedRunSession:
	var session := StitchedRunSession.new()
	var config := starter_config(selected)
	if config.is_empty():
		return null
	session.seed_value = seed_number
	session.picks = selected.duplicate()
	session.catalog = StitchedParts.build_catalog(config.parts).by_id
	session.enemies = StitchedEnemyCatalog.load_catalog()
	session.heroes = config.heroes.duplicate(true)
	# Resolve actual maximum HP once, before publishing the first route.
	var probe := StitchedRules.new()
	probe._parts = session.catalog
	session.heroes = []
	for index in config.heroes.size():
		var built := probe._build_hero(config.heroes[index], index + 1)
		if built.get("ok") != true:
			return null
		session.heroes.append(built.unit)
	for hero in session.heroes:
		hero["position"] = hero.rank
		hero["patches"] = []
		session.pockets[hero.id] = []
	session.rng = RandomNumberGenerator.new()
	session.rng.seed = seed_number
	session.map = RunMap.new()
	if initial.is_empty():
		if not session.map.generate(session.rng):
			return null
	else:
		if initial.size() != 2 or not initial.get("rng") is int or not session.map.restore_state(initial.get("map")):
			return null
		if not session.map.get_route().is_empty():
			return null
		session.rng.state = initial.rng
	session.phase = "map"
	session._kid_fear = StitchedKidFear.new()
	session._initial = {"map": session.map.export_state(), "rng": session.rng.state}
	session._seal()
	return session


func snapshot() -> Dictionary:
	return {"phase": phase, "heroes": heroes.duplicate(true), "satchel": satchel.duplicate(true),
		"patches": patches.duplicate(true), "pockets": pockets.duplicate(true),
		"gold": gold, "scraps": scraps, "candle": candle,
		"kid_fear": _kid_fear.state_snapshot(),
		"pending": pending.duplicate(true), "receipts": receipts.duplicate(true),
		"map": map.export_state() if map != null else {},
		"rng": rng.state if rng != null else 0,
		"battle": battle.state_snapshot() if battle != null else {}}


func _seal() -> void:
	_sealed = snapshot()


func is_consistent() -> bool:
	return phase != "invalid" and snapshot() == _sealed


func choices() -> Array:
	return map.get_legal_choices() if phase == "map" and is_consistent() else []


func enter(node_id: String, expected: Dictionary) -> bool:
	if phase != "map" or expected != snapshot() or not is_consistent() or not choices().has(node_id):
		return false
	var node := map.get_node(node_id)
	var old_rng := rng.state
	var old_route := map.get_route()
	var old_candle := candle
	if not map.choose_node(node_id):
		return false
	candle = maxi(0, candle - NODE_CANDLE_COST)
	pending = {"node_id": node_id, "kind": node.type, "service": node.type, "steps": []}
	if node.type in ["Fight", "Elite", "Boss"]:
		if not _open_battle(node.type):
			map.undo_choice(node_id, old_route)
			rng.state = old_rng
			candle = old_candle
			pending.clear()
			return false
		phase = "battle"
	else:
		phase = "visit"
		var kind: String = {"Rest": "Campfire", "Shop": "Peddler", "Treasure": "Event"}.get(node.type, node.type)
		if not _open_visit(kind):
			map.undo_choice(node_id, old_route)
			rng.state = old_rng
			candle = old_candle
			pending.clear()
			phase = "map"
			return false
	journal.append({"action": "enter", "node_id": node_id})
	_seal()
	changed.emit()
	return true


func _hero_inputs() -> Array:
	var result: Array = []
	var ordered := heroes.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary): return a.rank < b.rank)
	for hero in ordered:
		var record: Dictionary = hero.duplicate(true)
		record.max_hp = hero.base_max_hp
		record.speed = hero.base_speed
		record.dodge = hero.base_dodge
		record.acc = hero.base_acc
		record.prot = hero.base_prot
		record.statuses = {}
		if int(hero.statuses.get("bleed", 0)) > 0:
			record.statuses["bleed"] = int(hero.statuses.bleed)
		result.append(record)
	return result


func _open_battle(kind: String) -> bool:
	var foes: Array = []
	var tier: String = {"Fight": "normal", "Elite": "elite", "Boss": "boss"}[kind]
	var candidates: Array = []
	for id in enemies.order:
		if enemies.enemies[id].tier == tier:
			candidates.append(id)
	candidates.sort()
	if candidates.is_empty():
		return false
	var chosen: String = candidates[rng.randi_range(0, candidates.size() - 1)]
	foes.append(StitchedEnemyCatalog.foe_for(enemies, chosen))
	# A boss occupies its authored ranks and is accompanied by one ordinary foe.
	for id in ["scissor_crab", "moth_scribe"]:
		if foes.size() == 2 and kind == "Boss":
			break
		if id != chosen:
			foes.append(StitchedEnemyCatalog.foe_for(enemies, id))
	battle_config = {"mode": "stitched", "seed": seed_value, "run_rng": rng,
		"heroes": _hero_inputs(), "foes": foes, "parts": catalog.values(), "candle": candle,
		"title": "Floor %02d / %s" % [map.get_current_floor(), kind]}
	var candidate := RankedBattle.new()
	if not candidate._setup(battle_config).is_empty():
		return false
	var opening_spares := candidate.satchel()
	candidate._satchel = satchel.duplicate(true)
	for spare in opening_spares:
		if candidate._satchel.size() < 6:
			candidate._satchel.append(spare)
	battle = candidate
	battle.owner_session = weakref(self)
	battle.command_used.connect(_record_battle)
	return true


func _record_battle(command: Dictionary) -> void:
	journal.append(command.duplicate(true))
	_seal()
	changed.emit()


func settle_battle(expected_battle: StitchedRules) -> bool:
	if phase != "battle" or battle == null or expected_battle != battle or not is_consistent() or not battle.is_over():
		return false
	var outcome := battle.outcome()
	var ending := battle.get_heroes()
	for hero in ending:
		hero["position"] = hero.rank
		for previous in heroes:
			if previous.id == hero.id:
				hero["patches"] = previous.get("patches", []).duplicate()
				if not previous.lost and hero.lost:
					_kid_fear.apply_observed_event({"kind": "lost"})
	heroes = ending
	satchel = battle.satchel()
	var reward := {"gold": 0, "scraps": 0, "parts": []}
	if outcome == "victory":
		var elite: bool = pending.kind != "Fight"
		reward.gold = rng.randi_range(RunVictoryGold.ELITE_MIN if elite else RunVictoryGold.NORMAL_MIN,
			RunVictoryGold.ELITE_MAX if elite else RunVictoryGold.NORMAL_MAX)
		reward.scraps = 1
		var bonus: int = StitchedS1BEffects.candle_band(candle).loot_percent
		reward.gold = StitchedS1BEffects.increased(reward.gold, bonus)
		reward.scraps = StitchedS1BEffects.increased(reward.scraps, bonus)
		gold += reward.gold
		scraps += reward.scraps
		var defeated := battle.get_foes()
		if elite or rng.randi_range(0, 1) == 1:
			var drop: Dictionary = catalog[StitchedEnemyCatalog.trophy_for(enemies, defeated[0].id)]
			var spare := {"id": drop.id, "slot": drop.slot, "tier": 2 if pending.kind == "Boss" else 1, "torn": false}
			if satchel.size() < 6:
				satchel.append(spare)
				reward.parts.append(spare.duplicate(true))
	# Floor resolve and cut cleanup belongs to the rules authority.
	battle.end_floor()
	for hero in heroes:
		var settled := battle.get_unit(hero.id)
		hero.resolve = settled.resolve
	_normalize_formation()
	receipts.append({"node_id": pending.node_id, "kind": pending.kind, "outcome": outcome, "reward": reward})
	phase = "defeat" if outcome == "defeat" else "victory" if pending.kind == "Boss" and outcome == "victory" else "map"
	pending.clear()
	battle = null
	battle_config.clear()
	journal.append({"action": "settle"})
	_seal()
	changed.emit()
	return true


func _roster() -> Array:
	var result := heroes.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.rank < b.rank)
	for index in result.size():
		result[index].position = index + 1
	return result


func _living_roster() -> Array:
	return _roster().filter(func(hero: Dictionary): return not hero.lost)


func _normalize_formation() -> void:
	var occupied: Array = []
	for hero in heroes:
		if not hero.lost:
			occupied.append(hero.rank)
	for hero in heroes:
		if hero.lost:
			for rank in range(1, 5):
				if not rank in occupied:
					hero.rank = rank
					occupied.append(rank)
					break
		hero.position = hero.rank


func _replacement_candidates() -> Array:
	var candidates: Array = []
	var probe := StitchedRules.new()
	probe._parts = catalog
	for hero_id in StitchedPartyAdmission.HERO_IDS:
		if hero_id in _party_ids():
			continue
		var selected := _party_ids()
		selected[0] = hero_id
		var config := starter_config(selected)
		if config.is_empty():
			return []
		for entry in config.heroes:
			if entry.id != hero_id:
				continue
			var built := probe._build_hero(entry, 1)
			if built.get("ok") != true:
				return []
			var candidate: Dictionary = built.unit
			candidate.erase("rank")
			candidate.erase("lost")
			candidate["patches"] = []
			candidates.append(candidate)
	return candidates


func _replacement(lost_id: String, candidate_id: String) -> Dictionary:
	if _replacement_visit == null or pending.get("replaced", false):
		return {"ok": false}
	var source := _replacement_visit.read_state()
	if source.get("party") != heroes or source.get("node_id") != pending.node_id:
		return {"ok": false}
	var receipt := _replacement_visit.replace(lost_id, candidate_id, pending.node_id, source)
	if receipt.get("ok") != true or receipt.get("source_state") != source \
			or receipt.get("state") != _replacement_visit.read_state():
		return {"ok": false}
	return receipt


func visit_actions() -> Array:
	return _actions.duplicate(true) if phase == "visit" and is_consistent() else []


func _offer(id: String, text: String, enabled: bool = true, arguments: Array = []) -> void:
	_actions.append({"id": id, "text": text, "enabled": enabled, "arguments": arguments})


func _open_visit(kind: String) -> bool:
	pending.service = kind
	_actions.clear()
	_service = null
	_replacement_visit = null
	var id: String = pending.node_id
	var roster := _roster()
	match kind:
		"Campfire":
			_service = RunCampfireVisit.new(id, roster, RunCampfireVisit.STITCHED, candle)
			var state: Dictionary = _service.read_state()
			if state.get("ok") != true:
				return false
			for decision in state.get("quote", {}).get("choices", []):
				if decision == RunCampfireVisit.MEND and not roster.any(func(hero: Dictionary): return not hero.lost and hero.hp < hero.max_hp):
					continue
				if decision == RunCampfireVisit.TELL_TALES and not roster.any(func(hero: Dictionary): return not hero.lost and hero.fray > 0):
					continue
				_offer(decision, str(decision).replace("_", " ").capitalize())
			if not pending.get("swapped", false):
				_add_swaps(roster)
		"SewingCircle":
			var mend := RunStitchedSewingMend.new(id, _living_roster(), scraps, SEWING_COST, catalog)
			var upgrade := RunStitchedSewingUpgrade.new(id, _living_roster(), scraps, SEWING_COST, catalog)
			# Upgrade needs four equipped dolls. A LOST doll must still reach replacement.
			if mend.read_state().get("ok") != true:
				return false
			for hero in roster:
				if hero.lost:
					continue
				for slot in StitchedParts.SLOTS:
					var worn: Dictionary = hero.parts[slot]
					_offer("mend", "%s / Mend %s / %d scraps" % [hero.name, slot, SEWING_COST],
						not hero.lost and worn.torn and scraps >= SEWING_COST, [hero.id, slot])
					_offer("upgrade", "%s / Raise %s tier / %d scraps" % [hero.name, slot, SEWING_COST],
						upgrade.read_state().get("ok") == true and not worn.torn and worn.tier < 3 and scraps >= SEWING_COST, [hero.id, slot])
			_add_swaps(roster)
			if not pending.get("replaced", false):
				_replacement_visit = RunStitchedSewingReplacement.new(id, heroes, _replacement_candidates(), catalog)
				var quote := _replacement_visit.quote()
				if quote.get("ok") != true:
					return false
				for lost in quote.lost:
					for candidate in quote.candidates:
						_offer("replace", "Stitch %s into rank %d" % [candidate.name, lost.rank], true,
							[candidate.candidate_id, lost.hero_id])
			_offer("leave", "Leave Sewing Circle")
		"Peddler":
			_service = RunPeddlerVisit.open_stitched_candle(id, candle, gold, PEDDLER_PRICE)
			_offer("buy_candle_stub", "Candle stub / %d gold" % PEDDLER_PRICE, gold >= PEDDLER_PRICE and candle < 100)
			var bandage := RunStitchedPeddlerBandage.open_stitched(id, roster, gold, PEDDLER_PRICE)
			for hero_id in bandage.quote().get("eligible", []):
				_offer("bandage", "Bandage %s / %d gold" % [hero_id, PEDDLER_PRICE], true, [hero_id])
			var stock := RunStitchedPeddlerPart.open_stitched(id, gold, satchel, catalog,
				"scissor_crab_claw_arm", PEDDLER_PRICE)
			if stock.is_valid():
				_offer("buy_part", "Spare claw / %d gold" % PEDDLER_PRICE, gold >= PEDDLER_PRICE and satchel.size() < 6)
			var pins := RunStitchedPeddlerPins.open_stitched(id, roster, pockets, gold, PEDDLER_PRICE)
			var quote := pins.quote()
			if quote.get("ok") != true:
				return false
			for hero in roster:
				_offer("buy_pins", "Pins / %s / %d gold" % [hero.name, quote.price],
					quote.can_buy and hero.id in quote.eligible, [hero.id])
			var tonic := RunStitchedPeddlerTonic.open_stitched(id, roster, pockets, gold, PEDDLER_PRICE)
			var tonic_quote := tonic.quote()
			if tonic_quote.get("ok") != true:
				return false
			for hero in roster:
				_offer("buy_thimble_tonic", "Thimble tonic / %s / %d gold" % [hero.name, tonic_quote.price],
					tonic_quote.can_buy and hero.id in tonic_quote.eligible, [hero.id])
			var stuffing := RunStitchedPeddlerFreshStuffing.open_stitched(id, roster, pockets, gold, PEDDLER_PRICE)
			var stuffing_quote := stuffing.quote()
			if stuffing_quote.get("ok") != true:
				return false
			for hero in roster:
				_offer("buy_fresh_stuffing", "Fresh stuffing / %s / %d gold" % [hero.name, stuffing_quote.price],
					stuffing_quote.can_buy and hero.id in stuffing_quote.eligible, [hero.id])
			_offer("leave", "Leave Peddler")
		"Unpicker":
			_service = RunUnpickerVisit.open_stitched(id, roster, gold, CALM_PRICE, satchel, scraps, UNPICK_YIELD)
			if not _service.is_valid():
				return false
			for hero_id in _service.quote().get("hero_ids", []):
				_offer("calm", "Calm %s / %d gold" % [hero_id, CALM_PRICE], true, [hero_id])
			for index in satchel.size():
				_offer("unpick", "Unpick %s / +%d scraps" % [satchel[index].id, UNPICK_YIELD], true, [index])
			_offer("leave", "Leave Unpicker")
		"Event":
			return _open_event()
		"PatchStall":
			# Cache the sampled stock in the pending node, including across reload.
			if not pending.has("stock"):
				var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
				if not authored is Dictionary:
					return false
				var sampled := RunShopPurchases.sample_patch_stall_offers(rng, authored.get("trinkets"), patches)
				if sampled.get("ok") != true:
					return false
				pending.stock = sampled.offers
			_service = RunPatchStallVisit.open_stitched(id, _party_ids(), patches, gold, pending.stock)
			if not _service.is_valid():
				return false
			for offer in _service.quote().get("offers", []):
				for hero in roster:
					for slot in range(2):
						_offer("buy_patch", "%s / %s / slot %d / %d gold" % [offer.id, hero.name, slot + 1, offer.price],
							not hero.lost and gold >= offer.price, [offer.id, hero.id, slot])
			_offer("leave", "Leave Patch Stall")
		_:
			return false
	return not _actions.is_empty()


func _party_ids() -> Array:
	var ids: Array = []
	for hero in heroes:
		ids.append(hero.id)
	return ids


func _add_swaps(roster: Array) -> void:
	for hero in roster:
		if hero.lost:
			continue
		for index in satchel.size():
			var spare: Dictionary = satchel[index]
			_offer("swap", "%s / Sew on %s" % [hero.name, spare.id],
				not hero.parts[spare.slot].torn, [hero.id, spare.slot, index])


func choose_visit(action_id: String, arguments: Array, expected: Dictionary) -> bool:
	if phase != "visit" or not is_consistent() or expected != snapshot():
		return false
	var found := false
	for offered in _actions:
		if offered.id == action_id and offered.arguments == arguments and offered.enabled:
			found = true
	if not found:
		return false
	var id: String = pending.node_id
	var result: Dictionary = {}
	var kind: String = pending.service
	var displaced_patch := ""
	match kind:
		"Campfire":
			if action_id == "swap":
				var visit := RunStitchedSewingSwap.new(id, _living_roster(), satchel, catalog)
				result = visit.swap(arguments[0], arguments[1], arguments[2], id, visit.read_state())
			else:
				result = _service.select(action_id, id, _service.read_state().heroes, candle)
		"SewingCircle":
			match action_id:
				"swap":
					var visit := RunStitchedSewingSwap.new(id, _living_roster(), satchel, catalog)
					result = visit.swap(arguments[0], arguments[1], arguments[2], id, visit.read_state())
				"mend":
					var visit := RunStitchedSewingMend.new(id, _living_roster(), scraps, SEWING_COST, catalog)
					result = visit.mend(arguments[0], arguments[1], id, visit.read_state())
				"upgrade":
					var visit := RunStitchedSewingUpgrade.new(id, _living_roster(), scraps, SEWING_COST, catalog)
					result = visit.upgrade(arguments[0], arguments[1], id, visit.read_state())
				"leave":
					result = {"ok": true}
				"replace":
					result = _replacement(arguments[1], arguments[0])
		"Peddler":
			match action_id:
				"buy_fresh_stuffing":
					var visit := RunStitchedPeddlerFreshStuffing.open_stitched(id, _roster(), pockets, gold, PEDDLER_PRICE)
					result = visit.buy_fresh_stuffing(arguments[0], id, visit.read_state())
				"buy_thimble_tonic":
					var visit := RunStitchedPeddlerTonic.open_stitched(id, _roster(), pockets, gold, PEDDLER_PRICE)
					result = visit.buy(arguments[0], id, visit.read_state())
				"buy_pins":
					var visit := RunStitchedPeddlerPins.open_stitched(id, _roster(), pockets, gold, PEDDLER_PRICE)
					result = visit.buy_pins(arguments[0], id, visit.read_state())
				"bandage":
					var visit := RunStitchedPeddlerBandage.open_stitched(id, _roster(), gold, PEDDLER_PRICE)
					result = visit.choose_bandage(arguments[0], id, visit.read_state())
				"buy_part":
					var visit := RunStitchedPeddlerPart.open_stitched(id, gold, satchel, catalog, "scissor_crab_claw_arm", PEDDLER_PRICE)
					result = visit.buy(id, visit.read_state())
				_:
					result = _service.select_stitched(action_id, id, _service.read_state())
		"Unpicker":
			var state: Dictionary = _service.read_state()
			match action_id:
				"calm":
					result = _service.calm_hero(arguments[0], state.visit_id, id, state)
				"unpick":
					result = _service.unpick_spare(arguments[0], state.visit_id, id, state)
				"leave":
					result = _service.leave(state.visit_id, id, state)
		"Event":
			result = _choose_event(action_id, arguments)
		"PatchStall":
			var state: Dictionary = _service.read_state()
			if action_id == "leave":
				result = _service.leave(state.visit_id, id, state.snapshot)
			else:
				result = _service.buy_patch(arguments[0], state.visit_id, id, state.snapshot)
				if result.get("ok") == true:
					for hero in heroes:
						if hero.id == arguments[1]:
							while hero.patches.size() < 2:
								hero.patches.append("")
							displaced_patch = str(hero.patches[arguments[2]])
							hero.patches[arguments[2]] = arguments[0]
	if result.get("ok") != true:
		return false
	_apply_receipt(result)
	if displaced_patch != "":
		# The replaced patch is unpicked: it stops being owned and yields exactly 1 scrap.
		patches.erase(displaced_patch)
		scraps += 1
	pending.steps.append({"action": action_id, "arguments": arguments.duplicate(true),
		"gold": gold, "scraps": scraps, "candle": candle})
	if kind == "Campfire" and action_id == "swap":
		pending["swapped"] = true
	journal.append({"action": "visit", "id": action_id, "arguments": arguments.duplicate(true)})
	if action_id == "swap" or (kind == "SewingCircle" and action_id in ["mend", "upgrade", "replace"]):
		_open_visit(kind)
	elif not result.get("service_request", {}).is_empty():
		_open_visit(result.service_request.stop_type)
	else:
		receipts.append({"node_id": id, "kind": pending.kind, "decision": action_id,
			"event_id": pending.get("event_id", ""), "steps": pending.steps.duplicate(true)})
		pending.clear()
		_service = null
		_actions.clear()
		phase = "map"
	var alive := false
	for hero in heroes:
		alive = alive or not hero.lost
	if not alive:
		phase = "defeat"
	_normalize_formation()
	_seal()
	changed.emit()
	return true


func _apply_receipt(result: Dictionary) -> void:
	if result.get("action") == "replace":
		# Accept the authenticated service's single changed slot, without replaying
		# loss, moving gear, healing survivors or recomputing their state.
		heroes[result.party_index] = result.hero_after.duplicate(true)
		heroes[result.party_index]["position"] = result.rank
		pockets.erase(result.lost_id)
		pockets[result.candidate_id] = []
		pending["replaced"] = true
		return
	if result.has("pockets_after") or result.has("pockets"):
		gold = result.gold
		pockets = result.get("pockets_after", result.get("pockets", {})).duplicate(true)
		return
	var lost: Dictionary = {}
	for hero in heroes:
		if hero.lost:
			lost[hero.id] = hero.duplicate(true)
	var state: Dictionary = result.get("state", {})
	var incoming: Array = result.get("heroes", state.get("heroes", []))
	for changed_hero in incoming:
		for index in heroes.size():
			if heroes[index].id == changed_hero.id:
				heroes[index] = changed_hero.duplicate(true)
	for key in ["gold", "scraps", "candle", "satchel"]:
		if result.has(key):
			set(key, result[key].duplicate(true) if result[key] is Array else result[key])
		elif state.has(key):
			set(key, state[key].duplicate(true) if state[key] is Array else state[key])
	if result.has("scraps_after"):
		scraps = result.scraps_after
	if result.has("wallet"):
		gold = result.wallet.gold
		scraps = result.wallet.scraps
	if result.has("ledger"):
		gold = result.ledger.gold
		patches = result.ledger.owned_patch_ids.duplicate()
	for index in heroes.size():
		if lost.has(heroes[index].id):
			heroes[index] = lost[heroes[index].id]
	for hero in heroes:
		if hero.fray < StitchedRules.FRAY_RECOVER and hero.resolve in StitchedS1BEffects.RESOLVE_TRAITS:
			hero.resolve = ""
		hero.hanging = hero.hp == 0 and not hero.lost
		var maximum: int = hero.base_max_hp
		for worn in hero.parts.values():
			if not worn.torn:
				maximum += int(StitchedParts.stat_at_tier(catalog[worn.id], worn.tier).get("max_hp", 0))
		hero.max_hp = maximum
		hero.hp = mini(hero.hp, maximum)


func _open_event() -> bool:
	var records: Array = []
	for path in ["res://data/events/m04_events.json", "res://data/events/v3_roadside_events.json",
		"res://data/events/v3_candlelit_bargains.json", "res://data/events/v3_service_waystation_events.json",
		"res://data/events/s6_stitched_lantern_bobbin_ferry.json", "res://data/events/stitched_route_effects.json",
		"res://data/events/estate_sale.json", "res://data/events/needle_gate.json", "res://data/events/thimble_exchange.json"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not document is Dictionary:
			return false
		for record in document.get("events", [document]):
			var converted: Dictionary = record if record.has("service_kind") else _convert_event(record)
			if not converted.is_empty():
				records.append(converted)
	if records.is_empty():
		return false
	records.sort_custom(func(a: Dictionary, b: Dictionary): return a.id < b.id)
	_event_record = records[rng.randi_range(0, records.size() - 1)]
	pending["event_id"] = _event_record.id
	pending["title"] = _event_record.title
	var wallet := {"gold": gold, "scraps": scraps}
	var id: String = pending.node_id
	match _event_record.id:
		RunStitchedEmberglassCampfireEvent.EVENT_ID:
			_service = RunStitchedEmberglassCampfireEvent.new(_event_record.id, id, _roster(), candle, wallet)
		RunStitchedBriarCampfireEvent.EVENT_ID:
			_service = RunStitchedBriarCampfireEvent.new(_event_record.id, id, _roster(), candle, wallet)
		RunStitchedInkblackUnpickerEvent.EVENT_ID:
			_service = RunStitchedInkblackUnpickerEvent.new(_event_record.id, id, _roster(), satchel, wallet, CALM_PRICE, UNPICK_YIELD)
		"v3_threadmill_sewing_circle", "v3_moonlace_darning_parlor":
			_service = RunStitchedSewingWaystationEvent.new(_event_record.id, id, _roster(), satchel, wallet, catalog, SEWING_COST, SEWING_COST)
		_:
			_service = RunStitchedEventConsequence.new(_event_record)
	var quote: Dictionary = _service.preview(_event_snapshot(), catalog) if _service is RunStitchedEventConsequence else _service.preview_choices()
	if quote.get("ok") != true:
		return false
	for choice in quote.get("choices", []):
		var text: String = choice.choice_id
		for authored in _event_record.choices:
			if authored.id == choice.choice_id:
				text = authored.text
		var special: String = _event_record.get("actions", {}).get(choice.choice_id, "")
		if special == "unpick":
			for index in satchel.size():
				_offer(choice.choice_id, text + " / " + satchel[index].id, true, [index])
			if satchel.is_empty():
				_offer(choice.choice_id, text + " / no spare parts", false)
		elif special == "upgrade":
			for hero in _living_roster():
				for slot in StitchedParts.SLOTS:
					var worn: Dictionary = hero.parts[slot]
					_offer(choice.choice_id, text + " / " + hero.name + " / " + slot,
						scraps >= int(_event_record.upgrade_cost) and not worn.torn and worn.tier < 3, [hero.id, slot])
		else:
			var enabled: bool = choice.get("available", choice.get("affordable", false))
			var minimum: int = int(_event_record.get("choice_requirements", {}).get(choice.choice_id, {}).get("minimum_hp", 0))
			if minimum > 0:
				enabled = enabled and int(_living_roster()[0].hp) >= minimum
			_offer(choice.choice_id, text, enabled)
	return not _actions.is_empty()


func _convert_event(raw: Dictionary) -> Dictionary:
	var record := raw.duplicate(true)
	var choices_array: Array = []
	for choice in record.get("choices", []):
		if choice.has("stitched_effect"):
			var converted: Dictionary = choice.duplicate(true)
			if converted.stitched_effect.get("hero_id") == "$front":
				converted.stitched_effect.hero_id = _living_roster()[0].id
			if converted.stitched_effect.has("part"):
				converted.stitched_effect.part.tier = int(converted.stitched_effect.part.tier)
			choices_array.append(converted)
			continue
		var outcome: Dictionary = choice.get("outcome", {})
		for key in outcome:
			if not key in ["gold", "scraps"]:
				return {}
		choices_array.append({"id": choice.id, "text": choice.text,
			"stitched_effect": {"target": "party", "candle": 0, "fray": 0,
				"gold": int(outcome.get("gold", 0)), "scraps": int(outcome.get("scraps", 0))}})
	record.choices = choices_array
	return record


func _event_snapshot() -> Dictionary:
	var party: Array = []
	for hero in heroes:
		if not hero.lost:
			party.append({"id": hero.id, "fray": int(hero.fray)})
	return {"candle": candle, "party": party, "gold": gold, "scraps": scraps, "satchel_count": satchel.size()}


func _choose_event(choice_id: String, arguments: Array) -> Dictionary:
	if not _service is RunStitchedEventConsequence:
		return _service.choose(choice_id, pending.node_id, _service.read_state())
	match _event_record.get("actions", {}).get(choice_id, ""):
		"unpick":
			var visit := RunUnpickerVisit.open_stitched(pending.node_id, _roster(), gold, CALM_PRICE, satchel, scraps, UNPICK_YIELD)
			var state := visit.read_state()
			return visit.unpick_spare(arguments[0], state.visit_id, pending.node_id, state)
		"upgrade":
			var visit := RunStitchedSewingUpgrade.new(pending.node_id, _living_roster(), scraps, int(_event_record.upgrade_cost), catalog)
			return visit.upgrade(arguments[0], arguments[1], pending.node_id, visit.read_state())
	var result: Dictionary = _service.choose(choice_id, _event_snapshot(), catalog)
	if result.get("ok") == true:
		if result.has("part"):
			var part: Dictionary = result.part.duplicate(true)
			part["slot"] = catalog[part.id].slot
			part["torn"] = false
			satchel.append(part)
		# Apply intents through the same seeded fray and seam rules as combat.
		var authority := StitchedRules.new()
		authority._valid = true
		authority._rng = rng
		authority._parts = catalog
		authority._candle = candle
		authority._satchel = satchel.duplicate(true)
		for hero in heroes:
			authority._units[hero.id] = hero
		for hero_id in result.get("fray", {}):
			authority.apply_fray_event(hero_id, int(result.fray[hero_id]))
		for hero_id in result.get("hp", {}):
			var hero: Dictionary = authority._units[hero_id]
			var delta: int = int(result.hp[hero_id])
			if delta < 0:
				authority._damage_target(hero, -delta, {})
			else:
				hero.hp = mini(hero.max_hp, hero.hp + delta)
				hero.hanging = hero.hp == 0 and not hero.lost
		satchel = authority.satchel()
	return result

static func starter_config(picks: Array) -> Dictionary:
	var party := StitchedPartyAdmission.admit(picks)
	if party.get("ok") != true:
		return {}
	var preview := StitchedBattleScreen.read_preview()
	if not preview.get("heroes") is Array or preview["heroes"].size() != 4 \
			or not preview.get("foes") is Array or preview["foes"].size() != 3 \
			or not preview.get("parts") is Array:
		return {}
	var roster := StitchedEnemyCatalog.load_catalog()
	if not bool(roster.get("ok", false)):
		return {}
	var owner_catalogs: Dictionary = {}
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		var loaded := StitchedParts.load_catalog("res://data/parts/%s_parts.json" % owner_id)
		if not bool(loaded.get("ok", false)):
			return {}
		owner_catalogs[owner_id] = loaded
	var foes: Array = []
	for foe_id in ["fray_scavenger", "scissor_crab", "moth_scribe"]:
		foes.append(StitchedEnemyCatalog.foe_for(roster, foe_id))
	var generic: Array = []
	for entry in preview["parts"]:
		if not entry is Dictionary:
			return {}
		if str(entry.get("owner", "")) == "any":
			generic.append(entry)
	var definitions: Array = []
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		for part in owner_catalogs[owner_id]["parts"]:
			if str(part.get("owner", "")) != owner_id:
				return {}
			definitions.append(part)
	definitions.append_array(generic)
	definitions.append_array(roster["parts"])
	# This combined validation also excludes duplicated IDs across all sources.
	var catalog := StitchedParts.build_catalog(definitions)
	if not bool(catalog.get("ok", false)):
		return {}
	# Keep the four existing explicitly authored starter loadouts unchanged.
	var starters := {
		"warden": {
			"head": "warden_head_pot_helm_bonk",
			"arms": "warden_arms_shield_catch",
			"torso": "warden_torso_iron_challenge",
			"legs": "warden_legs_rim_toss",
		},
		"seamstress": {
			"head": "seamstress_mending_knot_hat",
			"arms": "seamstress_thread_prick_needle",
			"torso": "seamstress_shielding_hem_coat",
			"legs": "seamstress_tether_loop_spools",
		},
		"tinker": {
			"head": "tinker_head_cog_shot",
			"arms": "tinker_arms_scrap_bomb",
			"torso": "tinker_torso_casing_ward",
			"legs": "tinker_legs_tune_up",
		},
		"lantern_monk": {
			"head": "lantern_monk_head_moth_wink",
			"arms": "lantern_monk_arms_wick_spark",
			"torso": "lantern_monk_torso_lamplight_wash",
			"legs": "lantern_monk_legs_pole_shelter",
		},
	}
	# New heroes wear the FIRST authored part in each slot, never a generic
	# prototype and never an inferred skill or upgrade.
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		if starters.has(owner_id):
			continue
		var first: Dictionary = {}
		for part in owner_catalogs[owner_id]["parts"]:
			var slot := str(part.get("slot", ""))
			if slot in StitchedParts.SLOTS and not first.has(slot):
				first[slot] = str(part.get("id", ""))
		if first.size() != StitchedParts.SLOTS.size():
			return {}
		starters[owner_id] = first
	for owner_id in StitchedPartyAdmission.HERO_IDS:
		for slot in StitchedParts.SLOTS:
			var part_id: String = starters[owner_id][slot]
			var part: Dictionary = catalog["by_id"].get(part_id, {})
			if part.is_empty() or str(part.get("owner", "")) != owner_id \
					or str(part.get("slot", "")) != slot \
					or StitchedParts.ability_at_tier(part, 1).is_empty() \
					or StitchedParts.validate_ability(StitchedParts.ability_at_tier(part, 1)).get("ok") != true:
				return {}
	var config := preview.duplicate(true)
	var selected_heroes: Array = []
	for index in range(4):
		var identity: Dictionary = party["heroes"][index]
		var source: Variant = preview["heroes"][index]
		if not source is Dictionary or not source.get("parts") is Dictionary \
				or identity.get("rank") != index + 1:
			return {}
		var hero: Dictionary = source.duplicate(true)
		hero["id"] = identity["id"]
		hero["name"] = identity["name"]
		hero["max_hp"] = identity["max_hp"]
		hero["rank"] = identity["rank"]
		var worn: Dictionary = {}
		for slot in StitchedParts.SLOTS:
			worn[slot] = {"id": starters[identity["id"]][slot], "tier": 1, "torn": false}
		hero["parts"] = worn
		selected_heroes.append(hero)
	config["heroes"] = selected_heroes
	config["parts"] = catalog["parts"]
	config["foes"] = foes
	config["mode"] = "stitched"
	return config
