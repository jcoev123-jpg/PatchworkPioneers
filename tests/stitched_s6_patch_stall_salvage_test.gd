extends "res://tests/stitched_s6_followon_foes_live_test.gd"
## S6: replacing an occupied patch slot unpicks the displaced patch into +1 scrap.
## Seed 229's organic, journal-replayable walk funds two Patch Stall purchases;
## seed 0 opens a floor-one stall with an empty wallet for the refusal witness.

const SALVAGE_SEED := 229
const POOR_SEED := 0
const POOR_NODE := "f01_n1"
const MAX_FOE_STEPS := 28


func _run() -> void:
	_poor_stall_refusals()
	_salvage_walk()
	for message in failures:
		printerr(message)
	print("stitched_s6_patch_stall_salvage_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


## An empty wallet cannot buy, forge, replay or double-charge anything at a stall.
func _poor_stall_refusals() -> void:
	var session := StitchedRunSession.start(POOR_SEED)
	_check(session != null, "poor stall run starts")
	if session == null:
		return
	_check(session.gold == 0 and session.scraps == 0 and session.patches.is_empty(),
		"fresh poor run carries an empty wallet and no owned patches")
	_check(session.choices().has(POOR_NODE) and str(session.map.get_node(POOR_NODE).type) == "PatchStall",
		"seeded route offers a genuine floor-one Patch Stall")
	var before := session.snapshot()
	_check(not session.enter("forged", before) and session.snapshot() == before,
		"a forged route id cannot spend candle or draw RNG")
	_check(session.enter(POOR_NODE, session.snapshot()) and session.phase == "visit",
		"the authentic route enter opens the stall visit")
	var entered := session.snapshot()
	_check(not session.enter(POOR_NODE, before) and session.snapshot() == entered,
		"a stale route callback cannot enter the consumed stop twice")
	var actions := session.visit_actions()
	var stock: Array = session.pending.stock
	_check(stock.size() == 3, "the stall samples exactly three priced offers")
	var distinct := true
	var seen := []
	for offer in stock:
		distinct = distinct and int(offer.get("price", 0)) > 0 and not seen.has(str(offer.get("id", "")))
		seen.append(str(offer.get("id", "")))
	_check(distinct, "the three offers are distinct and positively priced")
	var buy_actions := []
	var leave_actions := 0
	for action in actions:
		if action.id == "buy_patch":
			buy_actions.append(action)
		elif action.id == "leave":
			leave_actions += 1
	_check(buy_actions.size() == stock.size() * session.heroes.size() * 2 and leave_actions == 1,
		"every offer is quoted for every hero in both slots beside exactly one Leave")
	for action in buy_actions:
		if action.enabled:
			_check(false, "a zero-gold wallet disables every quoted purchase")
			break
	var visit := session.snapshot()
	var target: Dictionary = buy_actions[0]
	var arguments: Array = target.get("arguments", [])
	_check(not session.choose_visit("buy_patch", ["forged_patch", arguments[1], arguments[2]], visit) and session.snapshot() == visit,
		"an unstocked offer cannot be bought")
	_check(not session.choose_visit("buy_patch", [arguments[0], "impostor", arguments[2]], visit) and session.snapshot() == visit,
		"a foreign hero cannot receive a stocked patch")
	_check(not session.choose_visit("buy_patch", [arguments[0], arguments[1], 7], visit) and session.snapshot() == visit,
		"an out-of-range slot cannot be sewn")
	_check(not session.choose_visit("buy_patch", arguments, visit) and session.snapshot() == visit,
		"insufficient gold refuses the authentic disabled purchase")
	var stale := visit.duplicate(true)
	stale.gold = int(stale.gold) + 1
	_check(not session.choose_visit("buy_patch", arguments, stale) and session.snapshot() == visit,
		"a stale expected snapshot cannot authorize a purchase")
	_check(not session.choose_visit("forged", [], visit) and session.snapshot() == visit,
		"an unknown service decision is inert")
	_check(session.choose_visit("leave", [], session.snapshot()) and session.phase == "map",
		"Leave closes the one-decision stall visit")
	var ended := session.snapshot()
	_check(session.receipts.size() == 1 and str(session.receipts[0].get("decision", "")) == "leave",
		"exactly one leave receipt is committed")
	_check(not session.choose_visit("leave", [], ended) and session.snapshot() == ended,
		"a replayed leave cannot duplicate the consumed stop")


## The organic walk: battles, events and stalls only through journal-replayable
## session decisions, until two genuine patch purchases have been made.
func _salvage_walk() -> void:
	var session := StitchedRunSession.start(SALVAGE_SEED)
	_check(session != null, "salvage run starts")
	if session == null:
		return
	var purchases := 0
	var first_node := ""
	for step in range(40):
		if purchases >= 2 or session.phase in ["victory", "defeat"]:
			break
		if session.phase == "map":
			var node_id := _pick_node(session, purchases)
			if node_id.is_empty() or not session.enter(node_id, session.snapshot()):
				_check(false, "the organic walk keeps entering authentic affordable nodes")
				break
		elif session.phase == "visit":
			var plan := {}
			if str(session.pending.service) == "PatchStall" and purchases < 2:
				plan = _stall_plan(session)
			if not plan.is_empty():
				if purchases == 0:
					first_node = str(plan.node_id)
				else:
					_check(str(plan.node_id) != first_node,
						"the second purchase happens at a later stall")
				if not _stall_purchase(session, plan, purchases + 1):
					break
				purchases += 1
			elif not _decide_visit(session, purchases).get("ok", false):
				_check(false, "the organic walk resolves every authentic visit")
				break
		elif session.phase == "battle":
			if not _fight(session):
				_check(false, "the organic walk wins its ranked battles")
				break
			if not session.settle_battle(session.battle):
				_check(false, "the settled battle receipt commits")
				break
	_check(purchases == 2, "the organic walk funds both Patch Stall purchases")
	if purchases == 2:
		var restored := StitchedRunSave.restore(StitchedRunSave.capture(session))
		_check(restored != null and restored.snapshot() == session.snapshot(),
			"the displaced-patch replacement survives an identical journal save/restore")


func _stall_purchase(session: StitchedRunSession, plan: Dictionary, index: int) -> bool:
	var visit := session.snapshot()
	var authored := _authored_price(str(plan.offer))
	_check(authored > 0 and int(plan.price) == authored,
		"the stall quotes the authored price for %s" % str(plan.offer))
	var arguments: Array = [str(plan.offer), str(plan.hero), int(plan.slot)]
	_check(not session.choose_visit("buy_patch", ["forged_patch", str(plan.hero), int(plan.slot)], visit) and session.snapshot() == visit,
		"an unstocked offer cannot be sewn at a funded stall")
	_check(not session.choose_visit("buy_patch", [str(plan.offer), "impostor", int(plan.slot)], visit) and session.snapshot() == visit,
		"a foreign hero cannot receive the stocked patch at a funded stall")
	_check(not session.choose_visit("buy_patch", [str(plan.offer), str(plan.hero), 7], visit) and session.snapshot() == visit,
		"an out-of-range slot cannot be sewn at a funded stall")
	var stale := visit.duplicate(true)
	stale.scraps = int(stale.scraps) + 5
	_check(not session.choose_visit("buy_patch", arguments, stale) and session.snapshot() == visit,
		"a stale expected snapshot cannot authorize a funded purchase")
	var hero_before := _snapshot_hero(visit, str(plan.hero))
	var displaced := _slot_value(hero_before, int(plan.slot))
	if index == 2:
		_check(not displaced.is_empty() and session.patches.has(displaced),
			"the second purchase displaces a genuinely owned patch")
		_check(not session.choose_visit("buy_patch", [displaced, str(plan.hero), int(plan.slot)], visit) and session.snapshot() == visit,
			"the already-owned displaced patch cannot be bought again")
	var before := session.snapshot()
	var others_before := _other_patches(before, str(plan.hero))
	var ok := session.choose_visit("buy_patch", arguments, session.snapshot())
	_check(ok, "the authenticated buy_patch commits at stall %s" % str(plan.node_id))
	if not ok:
		return false
	var after := session.snapshot()
	var hero_after := _snapshot_hero(after, str(plan.hero))
	_check(session.phase == "map", "the one-decision stall visit closes after the purchase")
	_check(session.gold == int(before.gold) - int(plan.price),
		"the wallet is charged exactly the quoted price")
	_check(hero_after.get("patches", []).size() == 2 and str(hero_after.get("patches", [])[int(plan.slot)]) == str(plan.offer),
		"the purchased patch is sewn onto the chosen slot")
	_check(str(hero_after.get("patches", [])[1 - int(plan.slot)]) == _slot_value(hero_before, 1 - int(plan.slot)),
		"the other patch slot is untouched")
	_check(_other_patches(after, str(plan.hero)) == others_before,
		"no other owner's patches change")
	_check(session.receipts.size() == before.get("receipts", []).size() + 1,
		"exactly one stall receipt is committed")
	var receipt: Dictionary = session.receipts[session.receipts.size() - 1]
	_check(str(receipt.get("kind", "")) == "PatchStall" and str(receipt.get("decision", "")) == "buy_patch",
		"the receipt witnesses the PatchStall buy_patch decision")
	var steps: Array = receipt.get("steps", [])
	var witness := steps.size() > 0
	if witness:
		var step: Dictionary = steps[steps.size() - 1]
		witness = str(step.get("action", "")) == "buy_patch" and (step.get("arguments", []) as Array) == arguments and int(step.get("gold", -1)) == session.gold and int(step.get("scraps", -1)) == session.scraps
	_check(witness, "the receipt step records the charged wallet and credited scraps")
	var replay := session.snapshot()
	_check(not session.choose_visit("buy_patch", arguments, replay) and session.snapshot() == replay,
		"a replayed purchase cannot be claimed twice")
	if index == 1:
		_check(before.get("patches", []).is_empty() and displaced.is_empty(),
			"the first purchase fills an empty slot with no prior ownership")
		_check(session.scraps == int(before.scraps), "an empty-slot fill credits no scrap")
		_check(session.patches.size() == 1 and session.patches.has(str(plan.offer)),
			"the equipped patch becomes the single owned patch")
	else:
		_check(before.get("patches", []).size() == 1 and before.get("patches", []).has(displaced),
			"the second purchase replaces the one owned patch")
		_check(session.patches.size() == 1 and session.patches.has(str(plan.offer)) and not session.patches.has(displaced),
			"the displaced patch is unpicked from global ownership")
		_check(session.scraps == int(before.scraps) + 1,
			"unpicking the displaced patch credits exactly one scrap")
	return true


func _authored_price(offer_id: String) -> int:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/shop/initial_offers.json"))
	if not document is Dictionary:
		return 0
	for trinket in document.get("trinkets", []):
		if str(trinket.get("id", "")) == offer_id:
			return int(trinket.get("price", 0))
	return 0


func _snapshot_hero(snapshot: Dictionary, hero_id: String) -> Dictionary:
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id", "")) == hero_id:
			return hero
	return {}


func _slot_value(hero: Dictionary, slot: int) -> String:
	var worn: Array = hero.get("patches", [])
	if slot < 0 or slot >= worn.size():
		return ""
	return str(worn[slot])


func _other_patches(snapshot: Dictionary, hero_id: String) -> Array:
	var result := []
	for hero in snapshot.get("heroes", []):
		if str(hero.get("id", "")) != hero_id:
			result.append((hero.get("patches", []) as Array).duplicate(true))
	return result


## --- Organic walk driver (session-level, headless, deterministic) ---

func _stall_plan(session: StitchedRunSession) -> Dictionary:
	var actions := session.visit_actions()
	var target := ""
	for hero in session.heroes:
		if not hero.lost:
			target = str(hero.id)
			break
	var candidates := []
	for action in actions:
		if action.id == "buy_patch" and action.enabled and int(action.arguments[2]) == 0:
			candidates.append(action)
	for action in candidates:
		if str(action.arguments[1]) == target:
			return _plan(session, action)
	if not candidates.is_empty():
		return _plan(session, candidates[0])
	return {}


func _plan(session: StitchedRunSession, action: Dictionary) -> Dictionary:
	var price := 0
	for offer in session.pending.stock:
		if str(offer.id) == str(action.arguments[0]):
			price = int(offer.price)
	return {"node_id": str(session.pending.node_id), "offer": str(action.arguments[0]),
		"hero": str(action.arguments[1]), "slot": int(action.arguments[2]), "price": price}


func _leave(session: StitchedRunSession) -> bool:
	for action in session.visit_actions():
		if action.id == "leave" and action.enabled:
			return session.choose_visit("leave", action.arguments, session.snapshot())
	return false


func _pick_node(session: StitchedRunSession, purchases: int) -> String:
	var choices := session.choices()
	var priority: Array = []
	if purchases < 2 and session.gold >= 100:
		priority = ["PatchStall", "Fight", "Elite", "Treasure", "Event", "Campfire", "Rest",
			"Shop", "SewingCircle", "Unpicker"]
	else:
		priority = ["Elite", "Fight", "Treasure", "Event", "Campfire", "Rest",
			"Shop", "SewingCircle", "Unpicker", "PatchStall"]
	for kind in priority:
		for id in choices:
			if session.map.get_node(id).type == kind:
				return id
	for id in choices:
		if session.map.get_node(id).type != "Boss":
			return id
	return ""


func _decide_visit(session: StitchedRunSession, purchases: int) -> Dictionary:
	var kind: String = str(session.pending.service)
	var actions := session.visit_actions()
	if kind == "PatchStall":
		if purchases < 2:
			var plan := _stall_plan(session)
			if not plan.is_empty():
				var arguments: Array = [plan.offer, plan.hero, plan.slot]
				return {"ok": session.choose_visit("buy_patch", arguments, session.snapshot())}
		return {"ok": _leave(session)}
	if kind == "Campfire":
		for preferred in ["mend", "tell_tales"]:
			for action in actions:
				if action.id == preferred and action.enabled:
					return {"ok": session.choose_visit(action.id, action.arguments, session.snapshot())}
	if kind == "SewingCircle":
		for action in actions:
			if action.id == "mend" and action.enabled and session.scraps >= StitchedRunSession.SEWING_COST:
				return {"ok": session.choose_visit(action.id, action.arguments, session.snapshot())}
	if kind == "Event":
		var chosen := _pick_event_action(session, actions)
		if not chosen.is_empty():
			return {"ok": session.choose_visit(str(chosen["id"]), chosen["arguments"], session.snapshot())}
	return {"ok": _leave(session)}


func _pick_event_action(session: StitchedRunSession, actions: Array) -> Dictionary:
	var record: Dictionary = session._event_record
	if record.is_empty() or record.has("service_kind"):
		return {}
	var best := {}
	var harmless := {}
	for action in actions:
		if not bool(action.get("enabled", false)) or not (action.get("arguments", []) as Array).is_empty():
			continue
		var effect := {}
		for authored in record.get("choices", []):
			if str(authored.get("id", "")) == str(action.get("id", "")):
				effect = authored.get("stitched_effect", {})
				break
		if typeof(effect) != TYPE_DICTIONARY or effect.is_empty():
			continue
		var gold := int(effect.get("gold", 0))
		var fray := int(effect.get("fray", 0))
		var candle := int(effect.get("candle", 0))
		var hp: Variant = effect.get("hp", null)
		var touches_hp := hp != null and not (typeof(hp) == TYPE_DICTIONARY and (hp as Dictionary).is_empty())
		if gold > 0 and fray == 0 and candle == 0 and not touches_hp and not effect.has("part"):
			return action
		if harmless.is_empty() and gold == 0 and fray == 0 and candle == 0 and not touches_hp and not effect.has("part"):
			harmless = action
	if not harmless.is_empty():
		return harmless
	for action in actions:
		if bool(action.get("enabled", false)) and (action.get("arguments", []) as Array).is_empty():
			return action
	return {}


func _fight(session: StitchedRunSession) -> bool:
	for turn in range(240):
		var battle = session.battle
		if battle == null or battle.is_over():
			break
		if battle.current_side() == "hero":
			if not _hero_command(session):
				return false
		_drive_foes(session)
	if session.battle == null or not session.battle.is_over():
		return false
	return session.battle.outcome() == "victory"


func _hero_command(session: StitchedRunSession) -> bool:
	var battle = session.battle
	if battle == null or battle.is_over() or battle.current_side() != "hero":
		return false
	var actor: Dictionary = battle.get_unit(battle.current_actor_id())
	var best_part := ""
	var best_rank := 0
	var best_score := -10000
	for slot in PART_SLOTS:
		var equipped: Dictionary = actor.get("parts", {}).get(slot, {})
		var part_id := str(equipped.get("id", ""))
		if part_id.is_empty() or bool(equipped.get("torn", false)) or not session.catalog.has(part_id):
			continue
		var ability: Dictionary = StitchedParts.ability_at_tier(session.catalog[part_id], int(equipped.get("tier", 1)))
		if ability.is_empty() or not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))):
			continue
		if not battle._self_move_gate(actor, ability).is_empty():
			continue
		for rank in range(1, 5):
			var targets: Array = battle._legal_targets(actor, ability, rank)
			if targets.is_empty():
				continue
			var score := -25
			var side := str(targets[0].get("side", ""))
			if side == "foe":
				score = int(ability.get("dmg", [0, 0])[1]) * 4 + int(ability.get("dmg", [0, 0])[0])
				if rank == 1:
					score += 3
			elif side == "hero" and str(ability.get("kind", "")) == "heal":
				var ally: Dictionary = targets[0]
				var missing := int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
				if missing >= 8:
					score = 38 + missing
			if score > best_score:
				best_score = score
				best_part = part_id
				best_rank = rank
	if best_part.is_empty():
		return bool(battle.pass_turn().get("ok", false))
	return bool(battle.use_part(best_part, best_rank).get("ok", false))


func _drive_foes(session: StitchedRunSession) -> void:
	var battle = session.battle
	var iterations := 0
	while battle != null and not battle.is_over() and battle.current_side() == "foe" and iterations < MAX_FOE_STEPS:
		iterations += 1
		var actor: Dictionary = battle.get_unit(battle.current_actor_id())
		var receipt: Dictionary = {}
		var choice: Dictionary = StitchedFoeIntent.choose(battle, actor)
		if not choice.is_empty() and not bool(choice["pass"]):
			receipt = battle.use_foe_ability(str(choice["ability_id"]), int(choice["target_rank"]))
		if not bool(receipt.get("ok", false)) and not choice.is_empty() and not bool(choice["pass"]):
			var authored: Array = actor.get("abilities", [])
			var offset := (battle.round_number() - 1) % maxi(1, authored.size())
			for step in range(authored.size()):
				var ability: Dictionary = authored[(offset + step) % authored.size()]
				if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])) or not battle._self_move_gate(actor, ability).is_empty():
					continue
				for rank in range(1, 5):
					if battle._legal_targets(actor, ability, rank).is_empty():
						continue
					receipt = battle.use_foe_ability(str(ability["id"]), rank)
					if bool(receipt.get("ok", false)):
						break
				if bool(receipt.get("ok", false)):
					break
		if not bool(receipt.get("ok", false)):
			receipt = battle.pass_turn()
		if not bool(receipt.get("ok", false)):
			break
