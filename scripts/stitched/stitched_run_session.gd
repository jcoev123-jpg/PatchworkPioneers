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
		if _s14:
			if current_side() != "hero":
				return {"ok": false}
			# Temporary old HUD bridge: part buttons dispatch the fixed ability at
			# the same limb slot, never the part's retired authored skill.
			var actor := _current_unit()
			for slot in StitchedParts.SLOTS:
				if actor.parts.has(slot) and actor.parts[slot].id == part_id:
					for candidate in actor.abilities:
						if candidate.slot == slot:
							return _remember(super.use_ability(candidate.id, rank), "use_part", [part_id, rank])
			return {"ok": false}
		return _remember(super.use_part(part_id, rank), "use_part", [part_id, rank])

	func use_ability(ability_id: String, rank: int) -> Dictionary:
		if not _admitted():
			return {"ok": false}
		return _remember(super.use_ability(ability_id, rank), "use_ability", [ability_id, rank])

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

	## S9a: Wren's fear always comes from the run, never from the caller.
	func use_hand_action(action_id: String, target_id: String = "", direction: int = 0, _fear: int = 0) -> Dictionary:
		if not _admitted():
			return {"ok": false}
		var session: StitchedRunSession = owner_session.get_ref()
		return _remember(super.use_hand_action(action_id, target_id, direction, session.kid_fear()),
			"use_hand_action", [action_id, target_id, direction])

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
const EVENT_OVERRIDES_PATH := "res://data/events/stitched_s6_conversion_overrides.json"

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
const VISIT_GREETINGS := {
	"Campfire": "A thimble of wax burns low between the floorboards. The dolls can rest, talk, or trade places.",
	"Peddler": "A peddler has spread a handkerchief of wares across the boards.",
	"PatchStall": "Scraps of cloth hang from a matchbox stall. Every patch has its price.",
	"Unpicker": "A thin figure with a seam ripper offers to unpick what the dark has sewn in.",
	"SewingCircle": "Old needles stand in a ring. Torn parts can be mended here, and lost dolls replaced.",
}
var _replacement_visit: RunStitchedSewingReplacement
var _kid_fear: StitchedKidFear
## S8f: with walks on, every non-boss node is reached through a seeded Walk on the run RNG.
## Its consequences wait in walk_carry until the next battle opens.
var walks_enabled := false
var walk: StitchedWalkRules
var walk_carry: Array = []
var walk_receipts: Array = []
## Debug-build playtest cheats only (scripts/debug/playtest_cheats.gd); empty in real play.
var cheat_event_id := ""
## S12 Wren's gifts: what sits in his (at most four) hand slots this run, the gifts this run
## may offer (set once by the app from the between-runs profile), the 1-of-3 offer waiting on
## the map (empty when none) and how many offers this run has drawn.
var gift_slots: Array = StitchedWrenGifts.basics()
var gift_pool: Array = StitchedWrenGifts.pool_for({})
var gift_offer: Array = []
var gift_offers_made := 0
## S14: unique run-owned ability patches, per-ability sockets and optional side doors.
var s14_enabled := true
var ability_inventory: Array = []
var ability_sockets: Dictionary = {}
var ability_serial := 0
var door_offer: Dictionary = {}
var door_history: Array = []
var underbed_taken := false
## Tests pin the drawn Event record for every session, so save/replay meets it too; the draw
## still spends its seeded roll. Empty in real play.
static var pinned_event_id := ""


static func start(seed_number: int, selected: Array = DEFAULT_PICKS, initial: Dictionary = {}, s14: bool = true) -> StitchedRunSession:
	var session := StitchedRunSession.new()
	var config := starter_config(selected)
	if config.is_empty():
		return null
	session.seed_value = seed_number
	session.s14_enabled = s14
	if s14 and (StitchedS14Abilities.kits().is_empty() or StitchedS14Abilities.patches().is_empty() \
			or StitchedS14SideDoors.catalog().is_empty()):
		return null
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


func kid_fear() -> int:
	return _kid_fear.get_fear()


func snapshot() -> Dictionary:
	return {"phase": phase, "heroes": heroes.duplicate(true), "satchel": satchel.duplicate(true),
		"patches": patches.duplicate(true), "pockets": pockets.duplicate(true),
		"gold": gold, "scraps": scraps, "candle": candle,
		"kid_fear": _kid_fear.state_snapshot(),
		"pending": pending.duplicate(true), "receipts": receipts.duplicate(true),
		"map": map.export_state() if map != null else {},
		"rng": rng.state if rng != null else 0,
		"battle": battle.state_snapshot() if battle != null else {},
		"walk": {"enabled": walks_enabled, "state": walk.snapshot() if walk != null else {},
			"carry": walk_carry.duplicate(true), "receipts": walk_receipts.duplicate(true)},
		"gifts": {"slots": gift_slots.duplicate(), "pool": gift_pool.duplicate(),
			"offer": gift_offer.duplicate(), "made": gift_offers_made},
		"s14": {"enabled": s14_enabled, "inventory": ability_inventory.duplicate(true),
			"sockets": ability_sockets.duplicate(true), "serial": ability_serial,
			"door_offer": door_offer.duplicate(true), "door_history": door_history.duplicate(true),
			"underbed_taken": underbed_taken}}


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
	var departing_node_id := map.get_current_node_id()
	var old_candle := candle
	if not map.choose_node(node_id):
		return false
	candle = maxi(0, candle - NODE_CANDLE_COST)
	pending = {"node_id": node_id, "kind": node.type, "service": node.type, "steps": []}
	if walks_enabled and node.type != "Boss" and _start_walk():
		phase = "walk"
	elif node.type in ["Fight", "Elite", "Boss"]:
		if not _open_battle(node.type):
			map.undo_choice(node_id, old_route)
			rng.state = old_rng
			candle = old_candle
			pending.clear()
			return false
		phase = "battle"
		_lose_strings_if_due()
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
	# A successful route entry implicitly declines the unclaimed offer at the departed node.
	# Do this after all entry failure paths; replay needs only the ordinary enter command.
	if not door_offer.is_empty() and str(door_offer.get("node_id", "")) == departing_node_id:
		_decline_door_offer()
	# Walking on past a gift offer leaves it behind.
	gift_offer.clear()
	journal.append({"action": "enter", "node_id": node_id})
	_seal()
	changed.emit()
	return true


## New runs opt in before their first step; a run never changes mode midway.
func enable_walks() -> bool:
	if phase != "map" or not journal.is_empty() or not is_consistent():
		return false
	walks_enabled = true
	_seal()
	return true


## S12: the app sets which gifts this run may offer, before the first step.
func set_gift_pool(ids: Array) -> bool:
	if phase != "map" or not journal.is_empty() or not is_consistent() or not StitchedWrenGifts.valid_pool(ids):
		return false
	gift_pool = ids.duplicate()
	_seal()
	return true


## S12: take one of the offered gifts (swap_out names the slot gift it replaces once all four
## slots are full) or leave them all with gift_id "". Kept for this run only.
func choose_gift(gift_id: String, swap_out: String, expected: Dictionary) -> bool:
	if phase != "map" or gift_offer.is_empty() or expected != snapshot() or not is_consistent():
		return false
	if not gift_id.is_empty():
		if not gift_id in gift_offer:
			return false
		if gift_slots.size() < StitchedWrenGifts.SLOTS:
			if not swap_out.is_empty():
				return false
			gift_slots.append(gift_id)
		else:
			var index := gift_slots.find(swap_out)
			if index < 0:
				return false
			gift_slots[index] = gift_id
	elif not swap_out.is_empty():
		return false
	gift_offer.clear()
	journal.append({"action": "gift", "id": gift_id, "swap": swap_out})
	_seal()
	changed.emit()
	return true


func _offer_gifts(elite: bool) -> void:
	gift_offer = StitchedWrenGifts.draw_offer(seed_value, gift_offers_made, gift_pool, gift_slots, elite)
	gift_offers_made += 1


## The Walk's corridor follows the house: floorboards, then walls, then the sewing basket.
func walk_area() -> String:
	var floor_number := map.get_current_floor()
	return "floorboards" if floor_number <= 4 else "walls" if floor_number <= 8 else "sewing_basket"


func _start_walk() -> bool:
	var living := _living_roster()
	if living.size() != 4:
		return false   # the Walk needs the whole party; a short party goes straight in
	var dolls: Array = []
	var carried_pockets := {}
	for hero in living:
		dolls.append({"id": hero.id, "name": hero.name, "rank": hero.position, "hp": hero.hp, "max_hp": hero.max_hp,
			"lost": false, "fray": int(hero.get("fray", 0)), "parts": hero.parts.duplicate(true)})
		carried_pockets[hero.id] = pockets.get(hero.id, []).duplicate()
	# The full set of horrors may be refused by authored data; fall back to fewer, never to a new draw.
	for horrors in [[true, true, true, true], [true, true, true, false], [false, false, false, false]]:
		walk = StitchedWalkRules.start(rng, walk_area(), dolls, carried_pockets, null,
			horrors[0], horrors[1], horrors[2], horrors[3])
		if walk != null:
			return true
	return false


func walk_act(command: Dictionary, expected: Dictionary) -> Dictionary:
	if phase != "walk" or walk == null or expected != snapshot() or not is_consistent():
		return {"ok": false, "error": "stale_session", "events": []}
	var receipt := walk.act(command, walk.snapshot())
	if receipt.get("ok") != true:
		return receipt
	journal.append({"action": "walk", "command": command.duplicate(true)})
	if walk.snapshot().phase == "complete" and not _finish_walk():
		phase = "invalid"
		return {"ok": false, "error": "walk_settle_failed", "events": []}
	_seal()
	changed.emit()
	return receipt


## Settle the finished Walk into the run: HP, pockets, torn parts and found parts now;
## fray, the mimic, cut threads and the Machine's toll at the next battle.
func _finish_walk() -> bool:
	var state := walk.snapshot()
	# Validate the whole trap claim before publishing any carry or settling dolls.
	# Only the placed instance can authenticate a Ragbag; loot shares its source.
	var bleeds: Array = []
	var claimed: Array = []
	for effect in state.pending:
		if effect.kind != "curio_trap" or effect.get("consumed") == true:
			continue
		var matches: Array = state.curios.filter(func(curio: Dictionary): return curio.instance == effect.get("source"))
		if matches.size() != 1 or not matches[0].get("resolved", false) or effect.get("source") in claimed:
			return false
		var projected := RunStitchedRagbagBleedEvent.project(effect, matches[0], state.dolls)
		if projected.get("ok") != true:
			return false
		bleeds.append(projected.carry.duplicate(true))
		claimed.append(effect.source)
	walk_carry.append_array(bleeds)
	if state.whirr == 100:
		var toll := walk.claim_machine_toll(state)
		if toll.ok:
			walk_carry.append({"kind": "machine", "extra_foes": toll.next_fight_extra_foes, "party_fray": toll.party_fray})
			state = walk.snapshot()
	# Consume only the detached saved receipt after the Walk's own claims.
	for effect in state.pending:
		if effect.kind == "curio_trap" and effect.get("source") in claimed:
			effect.consumed = true
	var cut: Array = []
	for effect in state.pending:
		if effect.consumed:
			continue
		match effect.kind:
			"mimic":
				walk_carry.append({"kind": "mimic"})
			"cut_thread":
				walk_carry.append({"kind": "cut", "target": effect.target})
				cut.append(effect.target)
			"curio_part":
				if satchel.size() < 6 and catalog.has(effect.effects.id):
					satchel.append({"id": effect.effects.id, "slot": catalog[effect.effects.id].slot,
						"tier": int(effect.effects.tier), "torn": false})
	for doll in state.dolls:
		for hero in heroes:
			if hero.id != doll.id:
				continue
			for slot in hero.parts:
				if doll.parts.get(slot) is Dictionary and doll.parts[slot].torn:
					hero.parts[slot].torn = true
			# Walk tears can remove an equipped max-HP bonus. Recompute the actual
			# worn-part cap before passing this survivor to the next battle.
			var maximum: int = hero.base_max_hp
			for worn in hero.parts.values():
				if not worn.torn:
					maximum += int(StitchedParts.stat_at_tier(catalog[worn.id], worn.tier).get("max_hp", 0))
			hero.max_hp = maximum
			hero.hp = mini(doll.hp, maximum)
			hero.hanging = hero.hp == 0 and not hero.lost
			if s14_enabled and hero.hp > 0:
				hero.death_hits = 0
			var gained: int = doll.fray - int(hero.get("fray", 0)) - (20 if doll.id in cut else 0)
			if gained > 0:
				walk_carry.append({"kind": "fray", "target": doll.id, "amount": gained})
		pockets[doll.id] = state.pockets[doll.id].duplicate()
	walk_receipts.append({"node_id": pending.node_id, "corridor": state.corridor.id, "whirr": state.whirr,
		"pending": state.pending.duplicate(true)})
	walk = null
	var node_type: String = pending.kind
	if node_type in ["Fight", "Elite"]:
		if not _open_battle(node_type):
			return false
		phase = "battle"
		_lose_strings_if_due()
		return true
	phase = "visit"
	return _open_visit({"Rest": "Campfire", "Shop": "Peddler", "Treasure": "Event"}.get(node_type, node_type))


## S14 owned-item records have unique serials. S13 worn patches and Button purchases
## stay in their existing, independent ledgers.
func _award_ability_patch(source: String, rarity: String = "") -> Dictionary:
	var patch := StitchedS14Abilities.draw_patch(rng, source, rarity)
	if patch.is_empty():
		return {}
	ability_serial += 1
	var item := {"uid": ability_serial, "id": patch.id, "rarity": patch.rarity}
	ability_inventory.append(item)
	return item.duplicate(true)


## The party material a successful Event choice can change. A free Leave, decline
## or escape leaves every value equal, so choose_visit can tell it apart from a
## genuinely consequential choice without hard-coding one exit id per Event.
## A receipt can also re-sew a living doll's base maximum HP (max_hp_delta)
## before this projection is compared, so both maximum-HP values are material:
## a max-HP-only seam still counts as a genuinely consequential choice. Wren's
## actual fear is material the same way: a fear-only Event choice is genuinely
## consequential, while a Leave or a clamped no-change outcome is not.
func _event_material_state() -> Dictionary:
	var row: Array = []
	for hero in heroes:
		row.append([str(hero.id), int(hero.hp), int(hero.base_max_hp), int(hero.max_hp),
			int(hero.fray), str(hero.resolve),
			bool(hero.lost), bool(hero.hanging), hero.parts.duplicate(true)])
	return {"gold": gold, "scraps": scraps, "candle": candle,
		"satchel": satchel.duplicate(true), "patches": patches.duplicate(true),
		"pockets": pockets.duplicate(true), "heroes": row, "wren_fear": kid_fear()}


func _battle_sockets() -> Dictionary:
	var loadout := {}
	for hero in heroes:
		if hero.lost:
			continue
		var owned := {}
		for ability_id in ability_sockets.get(hero.id, {}):
			var ids: Array = []
			for uid in ability_sockets[hero.id][ability_id]:
				for item in ability_inventory:
					if item.uid == uid:
						ids.append(item.id)
			owned[ability_id] = ids
		loadout[hero.id] = owned
	return loadout


## Authenticated Sewing Circle resewing; no item, money or RNG changes on a refusal.
## uid=0 removes replace_uid, otherwise swaps a found patch onto a fixed signature.
func socket_ability(uid: int, hero_id: String, ability_id: String, replace_uid: int, expected: Dictionary) -> bool:
	if not s14_enabled or phase != "visit" or str(pending.get("service", "")) != "SewingCircle" \
			or expected != snapshot() or not is_consistent() or (uid <= 0 and replace_uid <= 0) \
			or scraps < SEWING_COST or (uid > 0 and uid == replace_uid):
		return false
	var owner: Dictionary = {}
	for hero in heroes:
		if hero.id == hero_id and not hero.lost:
			owner = hero
	if owner.is_empty() or StitchedS14Abilities.ability(hero_id, ability_id).is_empty():
		return false
	var item_id := ""
	if uid > 0:
		for item in ability_inventory:
			if item.uid == uid:
				item_id = str(item.id)
		if item_id.is_empty():
			return false
	var proposed: Array = ability_sockets.get(hero_id, {}).get(ability_id, []).duplicate()
	if replace_uid > 0:
		if not replace_uid in proposed:
			return false
		proposed.erase(replace_uid)
	if uid > 0:
		for hero_key in ability_sockets:
			for key in ability_sockets[hero_key]:
				if uid in ability_sockets[hero_key][key] and uid != replace_uid:
					return false
		if uid in proposed:
			return false
		proposed.append(uid)
	var ids: Array = []
	for new_uid in proposed:
		var found := false
		for item in ability_inventory:
			if item.uid == new_uid:
				ids.append(item.id)
				found = true
		if not found:
			return false
	if proposed.size() > StitchedS14Abilities.socket_limit(ids):
		return false
	if not ability_sockets.has(hero_id):
		ability_sockets[hero_id] = {}
	if proposed.is_empty():
		ability_sockets[hero_id].erase(ability_id)
	else:
		ability_sockets[hero_id][ability_id] = proposed
	scraps -= SEWING_COST
	pending.steps.append({"action": "socket", "uid": uid, "hero": hero_id, "ability": ability_id,
		"replace": replace_uid, "scraps": scraps})
	journal.append({"action": "socket", "uid": uid, "hero": hero_id, "ability": ability_id,
		"replace": replace_uid})
	_open_visit("SewingCircle")
	_seal()
	changed.emit()
	return true


## The door offer is sealed by the completed node, not supplied by the caller. Boss
## victory remains terminal; the door is an optional side transaction, never another map step.
func choose_door(door_id: String, hero_id: String, expected: Dictionary) -> bool:
	if not s14_enabled or door_offer.is_empty() or not phase in ["map", "victory"] \
			or str(door_offer.get("node_id", "")) != map.get_current_node_id() \
			or not is_consistent() or expected != snapshot() or (door_id != "" and door_id != door_offer.id):
		return false
	if door_id == "":
		if hero_id != "":
			return false
		_decline_door_offer()
		journal.append({"action": "door", "id": "", "hero": ""})
		_seal()
		changed.emit()
		return true
	var source: Dictionary = StitchedS14SideDoors.catalog().get(door_id, {})
	if source.is_empty() or str(source.kind) != str(door_offer.kind) \
			or source.duplicate(true) != _door_record():
		return false
	if source.kind == "attic" and underbed_taken:
		return false
	var limb_slot := "legs" if door_id == "underbed_leg_trade" else "arms"
	var target: Dictionary = {}
	for hero in heroes:
		if hero.id == hero_id and not hero.lost:
			target = hero
	if source.cost != "none" or source.reward == "head_guard":
		if target.is_empty():
			return false
	elif not hero_id.is_empty():
		return false
	match str(source.cost):
		"max_hp":
			if int(target.base_max_hp) - int(source.amount) < 10:
				return false
		"limb":
			if not target.parts.has(limb_slot) or target.parts[limb_slot].torn:
				return false
		"fear":
			if source.amount != StitchedKidFear.LOST_FEAR_DELTA or kid_fear() + source.amount > 100:
				return false
		"none":
			pass
		_:
			return false
	if source.reward == "wren_gift":
		var available := gift_pool.filter(func(gift: Variant) -> bool: return not gift in gift_slots)
		if available.is_empty():
			return false
	if source.reward in ["silk_patch", "gold_patch"] and StitchedS14Abilities.patches().is_empty():
		return false
	# Everything above is a pure preflight. Commit the price and reward together.
	match str(source.cost):
		"max_hp":
			target.base_max_hp -= source.amount
			target.max_hp = maxi(10, int(target.max_hp) - int(source.amount))
			target.hp = mini(int(target.hp), int(target.max_hp))
		"limb":
			target.parts[limb_slot].torn = true
			var calc := StitchedRules.new()
			calc._parts = catalog
			calc._s14 = true
			calc._recompute_stats(target)
			target.hp = mini(int(target.hp), int(target.max_hp))
		"fear":
			_kid_fear.apply_observed_event({"kind": "lost"})
	var earned: Dictionary = {}
	match str(source.reward):
		"gold_patch", "silk_patch":
			earned = _award_ability_patch("boss" if source.reward == "gold_patch" else "elite",
				"gold" if source.reward == "gold_patch" else "silk")
		"wren_gift":
			var eligible: Array = gift_pool.filter(func(gift: Variant) -> bool: return not gift in gift_slots)
			eligible.sort()
			var chosen: String = eligible[rng.randi_range(0, eligible.size() - 1)]
			if gift_slots.size() == StitchedWrenGifts.SLOTS:
				gift_slots[0] = chosen
			else:
				gift_slots.append(chosen)
			earned = {"gift": chosen}
		"candle":
			candle = mini(100, candle + 25)
		"mend":
			for hero in heroes:
				if hero.lost:
					continue
				for slot in hero.parts:
					hero.parts[slot].torn = false
				var calc := StitchedRules.new()
				calc._parts = catalog
				calc._s14 = true
				calc._recompute_stats(hero)
		"head_guard":
			target.head_ward = true
	if source.kind == "underbed":
		underbed_taken = true
	door_history.append({"node_id": door_offer.node_id, "id": door_id,
		"hero": hero_id, "reward": earned.duplicate(true)})
	door_offer.clear()
	journal.append({"action": "door", "id": door_id, "hero": hero_id})
	_seal()
	changed.emit()
	return true


func _decline_door_offer() -> void:
	door_history.append({"id": "", "node_id": door_offer.node_id})
	door_offer.clear()


func _door_record() -> Dictionary:
	var entry := door_offer.duplicate(true)
	entry.erase("node_id")
	return entry


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
		if typeof(hero.statuses.get("bleed")) == TYPE_INT and hero.statuses.bleed > 0:
			record.statuses["bleed"] = hero.statuses.bleed
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
	# Later three-foe routes keep the primary and first escort. Only the final
	# Moth Scribe slot varies, using one draw from canonical normal-tier IDs.
	if map.get_current_floor() >= 3 and kind in ["Fight", "Elite"] and foes.size() == 3:
		var escort_pool: Array = []
		for id in enemies.order:
			if enemies.enemies[id].tier == StitchedEnemyCatalog.TIER_NORMAL \
					and id != "moth_scribe" and id != foes[0].id and id != foes[1].id:
				escort_pool.append(id)
		escort_pool.sort()
		if escort_pool.is_empty():
			return false
		foes[2] = StitchedEnemyCatalog.foe_for(enemies,
			escort_pool[rng.randi_range(0, escort_pool.size() - 1)])
	var hero_inputs := _hero_inputs()
	var cuts := {}
	var party_fray := 0
	var fray_gains: Array = []
	for carried in walk_carry:
		match carried.kind:
			"bleed":
				if carried.size() != 3 or not carried.get("target") is String \
						or typeof(carried.get("amount")) != TYPE_INT or carried.amount != 2:
					return false
				var found := false
				for hero in hero_inputs:
					if hero.id == carried.target and not hero.lost:
						hero.statuses["bleed"] = maxi(int(hero.statuses.get("bleed", 0)), carried.amount)
						found = true
				if not found:
					return false
			"machine":
				# The Machine's extra mouth is an ordinary foe picked in catalog order, so no draw is spent.
				for id in enemies.order:
					if foes.size() >= StitchedRules.MAX_FOES:
						break
					if enemies.enemies[id].tier == "normal" and not foes.any(func(foe: Dictionary): return foe.id == id):
						foes.append(StitchedEnemyCatalog.foe_for(enemies, id))
				party_fray += int(carried.party_fray)
			"cut":
				for index in hero_inputs.size():
					if hero_inputs[index].id == carried.target and not hero_inputs[index].lost:
						cuts[carried.target] = index + 1
						hero_inputs[index].fray = int(hero_inputs[index].fray) + 20
			"fray":
				fray_gains.append(carried)
	battle_config = {"mode": "stitched", "seed": seed_value, "run_rng": rng,
		"s14": s14_enabled, "s14_sockets": _battle_sockets() if s14_enabled else {},
		"heroes": hero_inputs, "foes": foes, "parts": catalog.values(), "candle": candle, "gifts": gift_slots.duplicate(),
		"title": "Floor %02d / %s" % [map.get_current_floor(), kind],
		"walk_mimic": walk_carry.any(func(carried: Dictionary): return carried.kind == "mimic"), "walk_cuts": cuts}
	var candidate := RankedBattle.new()
	if not candidate._setup(battle_config).is_empty():
		return false
	# Walk fray lands after setup so resolve and seam transitions follow the combat rules.
	for carried in fray_gains:
		if candidate._units.has(carried.target) and not candidate._units[carried.target].lost:
			candidate._change_fray(candidate._units[carried.target], int(carried.amount), false)
	if party_fray > 0:
		for hero in hero_inputs:
			if candidate._units.has(hero.id) and not candidate._units[hero.id].lost:
				candidate._change_fray(candidate._units[hero.id], party_fray, false)
	# S13: a foe's patch outside the doll's favoured slot never sits right.
	for hero in hero_inputs:
		var ill := StitchedSewnPatches.ill_fitting_fray(hero.id, hero.get("parts", {}))
		if ill > 0 and candidate._units.has(hero.id) and not candidate._units[hero.id].lost:
			candidate._change_fray(candidate._units[hero.id], ill, false)
	walk_carry.clear()
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
	_lose_strings_if_due()
	_seal()
	changed.emit()


## S9a fear 100: the first doll turn Wren meets skips itself and fear drops to 60. Runs
## after every recorded command and when a battle opens, so a replay repeats it exactly.
func _lose_strings_if_due() -> void:
	if battle == null or battle.is_over() or not _kid_fear.has_pending_lost_strings() or battle.current_side() != "hero":
		return
	if bool(battle.skip_lost_strings_turn().get("ok", false)):
		_kid_fear.consume_next_doll_turn()


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
				# S13: every patch a standing doll wore through the fight sits a little better.
				hero["patch_wear"] = {} if hero.lost else StitchedSewnPatches.wear_after_fight(
					hero.get("parts", {}), previous.get("patch_wear", {}))
				if not previous.lost and hero.lost:
					_kid_fear.apply_observed_event({"kind": "lost"})
	heroes = ending
	satchel = battle.satchel()
	var reward := {"gold": 0, "scraps": 0, "parts": []}
	if s14_enabled:
		reward["ability_patch"] = {}
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
	if outcome == "victory" and s14_enabled:
		var source := "boss" if pending.kind == "Boss" else "elite" if pending.kind == "Elite" else "fight"
		reward.ability_patch = _award_ability_patch(source)
		if pending.kind in ["Elite", "Boss"]:
			var leg_payer := false
			for settled_hero in heroes:
				if not settled_hero.lost and settled_hero.parts.has("legs") and not settled_hero.parts.legs.torn:
					leg_payer = true
					break
			door_offer = StitchedS14SideDoors.offer(rng, str(pending.kind), underbed_taken, leg_payer)
			if not door_offer.is_empty():
				door_offer["node_id"] = pending.node_id
	# Floor resolve and cut cleanup belongs to the rules authority.
	battle.end_floor()
	for hero in heroes:
		var settled := battle.get_unit(hero.id)
		hero.resolve = settled.resolve
	_normalize_formation()
	receipts.append({"node_id": pending.node_id, "kind": pending.kind, "outcome": outcome, "reward": reward})
	phase = "defeat" if outcome == "defeat" else "victory" if pending.kind == "Boss" and outcome == "victory" else "map"
	if phase == "map" and outcome == "victory":
		_offer_gifts(pending.kind == "Elite")
	pending.clear()
	battle = null
	battle_config.clear()
	var settled_command := {"action": "settle"}
	if s14_enabled:
		settled_command["ability_patch"] = reward.ability_patch
	journal.append(settled_command)
	_seal()
	changed.emit()
	return true


func _roster() -> Array:
	var result := heroes.duplicate(true)
	result.sort_custom(func(a: Dictionary, b: Dictionary): return a.rank < b.rank)
	for index in result.size():
		result[index].position = index + 1
	return result


func _hero_name(hero_id: String) -> String:
	for hero in heroes:
		if hero.id == hero_id:
			return str(hero.name)
	return hero_id.capitalize()


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


## The road stop's story as the player reads it: the event's own words, or the host's greeting.
func visit_story() -> String:
	if phase != "visit":
		return ""
	var service := str(pending.get("service", ""))
	if service == "Event" and str(_event_record.get("id", "")) == str(pending.get("event_id", "")):
		return str(_event_record.get("description", ""))
	return VISIT_GREETINGS.get(service, "Someone waits by the skirting board with something to offer.")


## S13: the part a road-stop choice is about, as {id, slot}, so the page can show its patch.
func visit_action_part(action: Dictionary) -> Dictionary:
	var arguments: Array = action.get("arguments", [])
	match str(action.get("id", "")):
		"mend", "upgrade":
			for hero in heroes:
				if arguments.size() >= 2 and hero.id == str(arguments[0]):
					return {"id": str(hero.parts[str(arguments[1])].id), "slot": str(arguments[1])}
		"swap", "double_stitch":
			if arguments.size() >= 3 and int(arguments[2]) < satchel.size():
				var spare: Dictionary = satchel[int(arguments[2])]
				return {"id": str(spare.id), "slot": str(spare.slot)}
		"buy_part":
			var id := str(pending.get("peddler_stock", {}).get("part", {}).get("id", ""))
			if catalog.has(id):
				return {"id": id, "slot": str(catalog[id].slot)}
	return {}


func _walk_supply_offers() -> Array:
	return [{"id": RunStitchedPeddlerWalkSupplies.STARCH, "price": PEDDLER_PRICE},
		{"id": RunStitchedPeddlerWalkSupplies.SPARE_SPOOL, "price": PEDDLER_PRICE}]


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
			_service = RunCampfireVisit.new(id, roster, RunCampfireVisit.STITCHED, candle, kid_fear())
			var state: Dictionary = _service.read_state()
			if state.get("ok") != true:
				return false
			for decision in state.get("quote", {}).get("choices", []):
				if decision == RunCampfireVisit.MEND and not roster.any(func(hero: Dictionary): return not hero.lost and hero.hp < hero.max_hp):
					continue
				# Wren's FEAR alone makes Tell Tales worth offering; only a LOST doll's FRAY does not.
				if decision == RunCampfireVisit.TELL_TALES and kid_fear() <= 0 \
						and not roster.any(func(hero: Dictionary): return not hero.lost and hero.fray > 0):
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
					# Owner 11-08: only a torn patch the party can pay for shows a Mend row.
					if worn.torn and scraps >= SEWING_COST:
						_offer("mend", "%s / Mend %s / %d scraps" % [hero.name, slot, SEWING_COST], true, [hero.id, slot])
					_offer("upgrade", "%s / Raise %s tier / %d scraps" % [hero.name, slot, SEWING_COST],
						upgrade.read_state().get("ok") == true and not worn.torn and worn.tier < 3 and scraps >= SEWING_COST, [hero.id, slot])
			_add_swaps(roster)
			_add_double_stitches(roster)
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
				_offer("bandage", "Bandage %s / %d gold" % [_hero_name(hero_id), PEDDLER_PRICE], true, [hero_id])
			# The canonical RNG samples only on first entry, never on a refresh or
			# a replayed receipt. Stock remains sealed with the pending node.
			if not pending.has("peddler_stock"):
				var sampled := RunStitchedPeddlerStock.sample(rng, catalog, patches, PEDDLER_PRICE)
				if sampled.get("ok") != true:
					return false
				pending["peddler_stock"] = {"part": sampled.part.duplicate(true),
					"patch": sampled.patch.duplicate(true)}
			var stock: Dictionary = pending.peddler_stock
			var part: Dictionary = stock.part
			var part_service := RunStitchedPeddlerPart.open_stitched(id, gold, satchel, catalog,
				str(part.id), int(part.price), int(part.tier))
			if not part_service.is_valid():
				return false
			_offer("buy_part", "%s / tier I / %d gold" % [str(catalog[part.id].name), part.price],
				gold >= int(part.price) and satchel.size() < RunStitchedPeddlerPart.SATCHEL_CAP)
			var patch: Dictionary = stock.patch
			if not patch.is_empty():
				var patch_service := RunStitchedPeddlerStock.open_stitched(id, gold, patches, patch)
				if not patch_service.is_valid():
					return false
				for hero in roster:
					for slot in range(2):
						_offer("buy_patch", "%s / %s / patch slot %d / %d gold" % [
							str(patch.id).capitalize(), hero.name, slot + 1, int(patch.price)],
							not hero.lost and gold >= int(patch.price), [patch.id, hero.id, slot])
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
			var dye := RunStitchedPeddlerDye.open_stitched(id, roster, pockets, gold, PEDDLER_PRICE)
			var dye_state := dye.read_state()
			if dye_state.get("ok") != true:
				return false
			var dye_quote := dye.quote()
			if dye_quote.get("ok") != true:
				return false
			for hero in roster:
				_offer("buy_dye", "Dye / %s / %d gold" % [hero.name, dye_quote.price],
					dye_quote.can_buy and hero.id in dye_quote.eligible, [hero.id])
			# Walk supplies need the full four-doll ledger; a short roster sells none.
			var supplies := RunStitchedPeddlerWalkSupplies.open_stitched(id, roster, pockets, gold,
				_walk_supply_offers())
			var supplies_quote := supplies.quote()
			if supplies_quote.get("ok") == true:
				for row in supplies_quote.offers:
					var is_starch: bool = row.id == RunStitchedPeddlerWalkSupplies.STARCH
					var label := "Starch" if is_starch else "Spare spool"
					var effect := "Guard next fight" if is_starch else "Fix snipped THREAD or save part from TUG"
					for hero in roster:
						_offer("buy_" + str(row.id), "%s / %s / %d gold / %s" % [label, hero.name, row.price, effect],
							row.can_buy and hero.id in supplies_quote.eligible, [hero.id])
			_offer("leave", "Leave Peddler")
		"Unpicker":
			_service = RunUnpickerVisit.open_stitched(id, roster, gold, CALM_PRICE, satchel, scraps, UNPICK_YIELD)
			if not _service.is_valid():
				return false
			# Labels only read the service's own quote: its relief rows and tiered spares.
			var unpicker_quote: Dictionary = _service.quote()
			for outcome in unpicker_quote.get("calm_outcomes", []):
				_offer("calm", "Calm %s / -%d FRAY / %d gold" % [
					_hero_name(str(outcome.hero_id)), int(outcome.fray_relief), CALM_PRICE], true, [outcome.hero_id])
			for spare in unpicker_quote.get("spares", []):
				var spare_name: String = str(catalog[spare.id].name) if catalog.has(spare.id) else str(spare.id)
				_offer("unpick", "Unpick %s (Tier %s) / +%d scraps" % [
					spare_name, ["I", "II", "III"][clampi(int(spare.tier), 1, 3) - 1], UNPICK_YIELD], true, [spare.index])
			_offer("leave", "Leave Unpicker")
		"Event":
			return _open_event()
		"PatchStall":
			# Cache the sampled stock in the pending node, including across reload.
			if not pending.has("stock"):
				var sampled := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, patches)
				if sampled.get("ok") != true:
					return false
				pending.stock = sampled.offers
			_service = RunPatchStallVisit.open_stitched(id, _party_ids(), patches, gold, pending.stock)
			if not _service.is_valid():
				return false
			# Every row's availability comes from the service quote, never a second rule here.
			for offer in _service.quote().get("offers", []):
				var price := int(offer.price)
				var status := "%d gold" % price
				if str(offer.get("blocked", "")) == "already owned":
					status = "SOLD / %d gold" % price
				elif not bool(offer.get("can_buy", false)):
					status = "%d gold / need %d more gold" % [price, maxi(0, price - gold)]
				for hero in roster:
					for slot in range(2):
						_offer("buy_patch", "%s / %s / slot %d / %s" % [str(offer.id).capitalize(), hero.name, slot + 1, status],
							bool(offer.get("can_buy", false)) and not hero.lost, [offer.id, hero.id, slot])
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
			_offer("swap", "%s / Sew on %s" % [hero.name, str(catalog.get(spare.id, {}).get("name", spare.id))],
				not hero.parts[spare.slot].torn, [hero.id, spare.slot, index])


## S13: a spare that matches a worn patch can be double-stitched over it, one tier higher
## than the better of the two; the spare is used up. Free, but only at a Sewing Circle.
func _add_double_stitches(roster: Array) -> void:
	for hero in roster:
		if hero.lost:
			continue
		for index in satchel.size():
			var spare: Dictionary = satchel[index]
			var worn: Dictionary = hero.parts.get(spare.slot, {})
			if str(worn.get("id", "")) == str(spare.id) and not bool(worn.get("torn", false)) 					and int(worn.get("tier", StitchedParts.MAX_TIER)) < StitchedParts.MAX_TIER:
				_offer("double_stitch", "%s / Double-stitch %s" % [hero.name, str(catalog.get(spare.id, {}).get("name", spare.id))],
					true, [hero.id, spare.slot, index])


func _double_stitch(hero_id: String, slot: String, index: int) -> Dictionary:
	if index < 0 or index >= satchel.size():
		return {"ok": false}
	var spare: Dictionary = satchel[index]
	for hero in heroes:
		if hero.id != hero_id or hero.lost or not hero.parts.has(slot):
			continue
		var worn: Dictionary = hero.parts[slot]
		if str(worn.id) != str(spare.id) or worn.torn or int(worn.tier) >= StitchedParts.MAX_TIER:
			return {"ok": false}
		var changed: Dictionary = hero.duplicate(true)
		changed.parts[slot].tier = mini(StitchedParts.MAX_TIER, maxi(int(worn.tier), int(spare.tier)) + 1)
		var left := satchel.duplicate(true)
		left.remove_at(index)
		return {"ok": true, "action": "double_stitch", "heroes": [changed], "satchel": left}
	return {"ok": false}


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
	var tell_tales_fear := false
	var event_before: Dictionary = _event_material_state() if kind == "Event" else {}
	match kind:
		"Campfire":
			if action_id == "swap":
				var visit := RunStitchedSewingSwap.new(id, _living_roster(), satchel, catalog)
				result = visit.swap(arguments[0], arguments[1], arguments[2], id, visit.read_state())
			else:
				var fear_before := kid_fear()
				result = _service.select(action_id, id, _service.read_state().heroes, candle, fear_before)
				if result.get("ok") == true:
					# The service's FEAR must agree with exactly one ledger event before anything commits.
					var fear_after := maxi(0, fear_before + StitchedKidFear.TELL_TALES_FEAR_DELTA) \
						if action_id == RunCampfireVisit.TELL_TALES else fear_before
					if typeof(result.get("fear")) != TYPE_INT or result.fear != fear_after:
						return false
					tell_tales_fear = action_id == RunCampfireVisit.TELL_TALES
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
				"double_stitch":
					result = _double_stitch(arguments[0], arguments[1], arguments[2])
				"leave":
					result = {"ok": true}
				"replace":
					result = _replacement(arguments[1], arguments[0])
		"Peddler":
			match action_id:
				"buy_starch", "buy_spare_spool":
					var visit := RunStitchedPeddlerWalkSupplies.open_stitched(id, _roster(), pockets, gold,
						_walk_supply_offers())
					result = visit.buy(action_id.trim_prefix("buy_"), arguments[0], id, visit.read_state())
				"buy_dye":
					var visit := RunStitchedPeddlerDye.open_stitched(id, _roster(), pockets, gold, PEDDLER_PRICE)
					result = visit.buy_dye(arguments[0], id, visit.read_state())
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
					var offered: Dictionary = pending.peddler_stock.part
					var visit := RunStitchedPeddlerPart.open_stitched(id, gold, satchel, catalog,
						str(offered.id), int(offered.price), int(offered.tier))
					result = visit.buy(id, visit.read_state())
				"buy_patch":
					var offered: Dictionary = pending.peddler_stock.patch
					if str(offered.get("id", "")) != str(arguments[0]):
						return false
					var visit := RunStitchedPeddlerStock.open_stitched(id, gold, patches, offered)
					result = visit.buy_patch(arguments[0], id, visit.read_state())
					if result.get("ok") == true:
						for hero in heroes:
							if hero.id == arguments[1] and not hero.lost and arguments[2] in [0, 1]:
								while hero.patches.size() < 2:
									hero.patches.append("")
								displaced_patch = str(hero.patches[arguments[2]])
								hero.patches[arguments[2]] = arguments[0]
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
	var event_patch: Dictionary = {}
	# A free Leave/decline/escape changes no party material, so it finds no patch.
	# Only a genuinely consequential Event choice can carry S14 loot.
	if s14_enabled and kind == "Event" and _event_material_state() != event_before:
		event_patch = _award_ability_patch("event")
	if tell_tales_fear:
		# The run ledger is the only writer of Wren's FEAR; it must land on the service's capped value.
		var relief := _kid_fear.apply_observed_event({"kind": "tell_tales"})
		if relief.get("ok") != true or relief.get("fear") != result.get("fear"):
			phase = "invalid"
			return false
	if displaced_patch != "":
		# The replaced patch is unpicked: it stops being owned and yields exactly 1 scrap.
		patches.erase(displaced_patch)
		scraps += 1
	pending.steps.append({"action": action_id, "arguments": arguments.duplicate(true),
		"gold": gold, "scraps": scraps, "candle": candle})
	if kind == "Campfire" and action_id == "swap":
		pending["swapped"] = true
	var visit_command := {"action": "visit", "id": action_id, "arguments": arguments.duplicate(true)}
	if not event_patch.is_empty():
		visit_command["ability_patch"] = event_patch
	journal.append(visit_command)
	if action_id == "swap" or (kind == "SewingCircle" and action_id in ["mend", "upgrade", "replace", "double_stitch"]):
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
		if kind == "Event":
			_offer_gifts(false)
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
	if result.has("max_hp_delta"):
		var target_id: String = str(result.get("target_hero_id", result.get("hero_id", "")))
		var max_delta: int = int(result.get("max_hp_delta", 0))
		for hero in heroes:
			if hero.id == target_id and not hero.lost:
				hero.base_max_hp += max_delta
	var hp_delta: int = int(result.get("hp_delta", 0))
	if hp_delta != 0 and result.has("target_hero_id"):
		var target_id: String = str(result.get("target_hero_id", result.get("hero_id", "")))
		var authority := StitchedRules.new()
		authority._valid = true
		authority._s14 = s14_enabled
		authority._rng = rng
		authority._parts = catalog
		authority._candle = candle
		authority._satchel = satchel.duplicate(true)
		for hero in heroes:
			authority._units[hero.id] = hero
		if authority._units.has(target_id) and not authority._units[target_id].lost:
			var target_unit: Dictionary = authority._units[target_id]
			if hp_delta < 0:
				authority._damage_target(target_unit, -hp_delta, {})
			else:
				target_unit.hp = mini(int(target_unit.max_hp), int(target_unit.hp) + hp_delta)
				target_unit.hanging = target_unit.hp == 0 and not target_unit.lost
				if s14_enabled and target_unit.hp > 0:
					target_unit.death_hits = 0
		satchel = authority.satchel()
	for hero in heroes:
		if hero.fray < StitchedRules.FRAY_RECOVER and hero.resolve in StitchedS1BEffects.RESOLVE_TRAITS:
			hero.resolve = ""
		hero.hanging = hero.hp == 0 and not hero.lost
		var maximum: int = hero.base_max_hp
		for worn in hero.parts.values():
			if not worn.torn:
				maximum += int(StitchedParts.stat_at_tier(catalog[worn.id], worn.tier).get("max_hp", 0))
		maximum = maxi(10, maximum)
		hero.max_hp = maximum
		hero.hp = mini(hero.hp, maximum)
		hero.hanging = hero.hp == 0 and not hero.lost
		if s14_enabled and hero.hp > 0:
			hero.death_hits = 0
		# A visit service can report a changed FRAY without the resolve trait the
		# battle rules attach at the threshold. Settle that crossing here through
		# the one seeded gate so the next battle never opens on an invalid doll.
		if hero.lost:
			continue
		if int(hero.fray) < StitchedRules.FRAY_RECOVER \
				and str(hero.resolve) in StitchedS1BEffects.RESOLVE_TRAITS:
			hero.resolve = ""
		elif int(hero.fray) >= StitchedRules.FRAY_RESOLVE and str(hero.resolve).is_empty():
			if StitchedS1BEffects.percent_roll_succeeds(rng.randi_range(1, 100), 25):
				hero.resolve = "steadfast"
				hero.fray = 45
			else:
				hero.resolve = StitchedS1BEffects.trait_for_roll(rng.randi_range(0, 4))


func _open_event() -> bool:
	# No record is dropped on conversion failure. The whole unentered node
	# refuses without consuming the route/RNG, rather than silently shrinking
	# a seeded Event pool or choosing a different Event.
	var override_document: Variant = JSON.parse_string(FileAccess.get_file_as_string(EVENT_OVERRIDES_PATH))
	if not override_document is Dictionary or not override_document.get("events") is Dictionary:
		return false
	var overrides: Dictionary = override_document.events
	var records: Array = []
	var seen_overrides: Dictionary = {}
	for path in ["res://data/events/m04_events.json", "res://data/events/v3_roadside_events.json",
		"res://data/events/v3_candlelit_bargains.json", "res://data/events/v3_hero_choice_events.json",
		"res://data/events/v3_service_waystation_events.json",
		"res://data/events/s6_stitched_lantern_bobbin_ferry.json", "res://data/events/stitched_route_effects.json",
		"res://data/events/estate_sale.json", "res://data/events/needle_gate.json", "res://data/events/thimble_exchange.json"]:
		var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not document is Dictionary:
			return false
		var source_records: Variant = document.get("events", [document])
		if not source_records is Array:
			return false
		for record in source_records:
			if not record is Dictionary:
				return false
			var converted: Dictionary = record.duplicate(true) if record.has("service_kind") else _convert_event(record, overrides)
			if converted.is_empty() or not RunEventChoice.new(converted).is_valid():
				return false
			if overrides.has(converted.id):
				seen_overrides[converted.id] = true
			# A hero-exclusive story is not drawn when its protagonist is
			# absent; the authored record remains fully validated above.
			if converted.has("required_hero") and not _party_ids().has(converted.required_hero):
				continue
			records.append(converted)
	for override_id in overrides:
		if not seen_overrides.has(override_id):
			return false
	var vital_document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/events/v3_hero_vital_events.json"))
	if not vital_document is Dictionary or not vital_document.get("events") is Array:
		return false
	var warden_record: Dictionary = {}
	for ev_raw: Variant in vital_document.events:
		if ev_raw is Dictionary and str(ev_raw.get("id", "")) == "v3_warden_buckle_heart_ward":
			warden_record = ev_raw.duplicate(true)
			break
	if warden_record.is_empty() or not RunEventChoice.new(warden_record).is_valid():
		return false
	var warden_eligible := false
	for hero in heroes:
		if hero.id == "warden" and not hero.lost:
			warden_eligible = true
			break
	if warden_eligible:
		records.append(warden_record)
	if records.is_empty():
		return false
	records.sort_custom(func(a: Dictionary, b: Dictionary): return a.id < b.id)
	_event_record = records[rng.randi_range(0, records.size() - 1)]
	for record in records:
		if record.id in [cheat_event_id, pinned_event_id] and not str(record.id).is_empty():
			_event_record = record
	pending["event_id"] = _event_record.id
	pending["title"] = _event_record.title
	var wallet := {"gold": gold, "scraps": scraps}
	var id: String = pending.node_id
	match _event_record.id:
		RunStitchedMothSacrificeEvent.EVENT_ID:
			_service = RunStitchedMothSacrificeEvent.open_stitched(id, satchel, scraps, catalog, _event_record)
		RunStitchedEmberglassCampfireEvent.EVENT_ID:
			_service = RunStitchedEmberglassCampfireEvent.new(_event_record.id, id, _roster(), candle, wallet)
		RunStitchedBriarCampfireEvent.EVENT_ID:
			_service = RunStitchedBriarCampfireEvent.new(_event_record.id, id, _roster(), candle, wallet)
		RunStitchedInkblackUnpickerEvent.EVENT_ID:
			_service = RunStitchedInkblackUnpickerEvent.new(_event_record.id, id, _roster(), satchel, wallet, CALM_PRICE, UNPICK_YIELD)
		"v3_threadmill_sewing_circle", "v3_moonlace_darning_parlor":
			_service = RunStitchedSewingWaystationEvent.new(_event_record.id, id, _roster(), satchel, wallet, catalog, SEWING_COST, SEWING_COST)
		"v3_warden_buckle_heart_ward":
			_service = RunStitchedHeroVitalSeams.open_stitched(id, _event_record, _roster(), wallet)
		_:
			_service = RunStitchedEventConsequence.new(_event_record)
	var quote: Dictionary = _service.preview(_event_snapshot(), catalog) if _service is RunStitchedEventConsequence else _service.preview_choices()
	if quote.get("ok") != true:
		return false
	if _service is RunStitchedMothSacrificeEvent:
		for index in satchel.size():
			var sacrifice: Dictionary = _service.preview_choices(index).choices[0]
			_offer(sacrifice.choice_id, "%s / spare %d / %s" % [
				sacrifice.text, index + 1, catalog[satchel[index].id].name], sacrifice.available, [index])
		if satchel.is_empty():
			_offer(quote.choices[0].choice_id, quote.choices[0].text + " / no spare parts", false)
		for choice in quote.choices.slice(1):
			_offer(choice.choice_id, choice.text, choice.available)
		return true
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


## JSON-decoded signed values may be whole floats, never truncated fractions
## or boolean values. This keeps a malformed authored wallet from turning into
## a valid free/cheap transaction.
func _event_amount(value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and floor(value) == value \
			and absf(value) <= 9007199254740992.0:
		return int(value)
	return null


func _convert_event(raw: Dictionary, overrides: Dictionary = {}) -> Dictionary:
	var record := raw.duplicate(true)
	if not record.get("choices") is Array or not record.get("id") is String:
		return {}
	var event_overrides: Variant = overrides.get(record.id, {})
	if not event_overrides is Dictionary:
		return {}
	var hero_gate: Variant = record.get("required_hero", "")
	var hero_choices: Variant = record.get("hero_choice_ids", [])
	if not hero_gate is String or not hero_choices is Array:
		return {}
	if not hero_gate.is_empty() and not hero_gate in StitchedPartyAdmission.HERO_IDS:
		return {}
	var choices_array: Array = []
	var observed: Dictionary = {}
	for choice in record.choices:
		if not choice is Dictionary or not choice.get("id") is String or not choice.get("text") is String:
			return {}
		observed[choice.id] = true
		var effect: Dictionary = {"target": "party", "candle": 0, "fray": 0}
		if choice.has("stitched_effect"):
			if not choice.stitched_effect is Dictionary:
				return {}
			effect = choice.stitched_effect.duplicate(true)
		else:
			var outcome: Variant = choice.get("outcome")
			if not outcome is Dictionary:
				return {}
			for key in outcome:
				# Extra legacy semantics must be explicitly translated, not
				# discarded or treated as wallet-only.
				if not key in ["gold", "scraps"]:
					return {}
				var amount: Variant = _event_amount(outcome[key])
				if amount == null:
					return {}
				effect[key] = amount
		# JSON decoding hands authored numbers back as whole floats, while the
		# Event service's Wren-fear contract is a native int: normalize the
		# fear delta here exactly like a part tier, failing the whole Event on
		# fractions or booleans rather than silently dropping the choice.
		if effect.has("fear"):
			var fear_amount: Variant = _event_amount(effect.get("fear"))
			if fear_amount == null:
				return {}
			effect["fear"] = fear_amount
		var authored: Variant = event_overrides.get(choice.id, {})
		if not authored is Dictionary:
			return {}
		for key in authored:
			# Never let an override silently change a legacy wallet outcome.
			if not key in ["target", "hero_id", "required_hero", "candle",
					"fray", "hp", "part", "min_fray", "require_full_candle",
					"required_candle_band", "required_candle_bands"]:
				return {}
			effect[key] = authored[key]
		if not hero_gate.is_empty() and choice.id in hero_choices:
			if effect.has("required_hero") and effect.required_hero != hero_gate:
				return {}
			effect["required_hero"] = hero_gate
		if effect.get("hero_id") == "$front":
			var living := _living_roster()
			if living.is_empty():
				return {}
			effect["hero_id"] = living[0].id
		if effect.has("part"):
			if not effect.part is Dictionary or not effect.part.has("tier"):
				return {}
			var tier: Variant = _event_amount(effect.part.tier)
			if tier == null:
				return {}
			effect.part.tier = tier
		choices_array.append({"id": choice.id, "text": choice.text, "stitched_effect": effect})
	# Stale/typoed overrides fail the Event rather than silently doing nothing.
	for choice_id in event_overrides:
		if not observed.has(choice_id):
			return {}
	for choice_id in hero_choices:
		if not observed.has(choice_id):
			return {}
	record.choices = choices_array
	return record


func _event_snapshot() -> Dictionary:
	var party: Array = []
	for hero in heroes:
		if not hero.lost:
			party.append({"id": hero.id, "fray": int(hero.fray)})
	return {"candle": candle, "party": party, "gold": gold, "scraps": scraps, "satchel_count": satchel.size(),
		"wren_fear": kid_fear()}


func _choose_event(choice_id: String, arguments: Array) -> Dictionary:
	if _service is RunStitchedMothSacrificeEvent:
		var index: Variant = null
		if choice_id == RunStitchedMothSacrificeEvent.CHOICE_SACRIFICE:
			if arguments.size() != 1 or not arguments[0] is int:
				return {"ok": false}
			index = arguments[0]
		elif not arguments.is_empty():
			return {"ok": false}
		var state: Dictionary = _service.read_state()
		if state.get("satchel") != satchel or state.get("scraps") != scraps \
				or state.get("node_id") != pending.node_id:
			return {"ok": false}
		var quote: Dictionary = _service.preview_choices(index)
		for choice in quote.get("choices", []):
			if choice.choice_id == choice_id and choice.available:
				return _service.choose(choice_id, index, pending.node_id, state)
		return {"ok": false}
	if not _service is RunStitchedEventConsequence:
		if _service is RunStitchedHeroVitalSeams and not arguments.is_empty():
			return {"ok": false}
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
		# S9a/S14: a fear-bearing Event choice settles through Wren's one run
		# ledger. Validate the receipt's projected fear first, then commit the
		# signed delta exactly once, before any other Event material settles.
		# Rejected and fear-free choices never reach the ledger.
		if result.has("fear") or result.has("fear_delta"):
			var fear_delta: Variant = result.get("fear_delta", null)
			var projected_fear: Variant = result.get("fear", null)
			if typeof(fear_delta) != TYPE_INT or typeof(projected_fear) != TYPE_INT \
					or clampi(kid_fear() + int(fear_delta), StitchedKidFear.FEAR_MIN,
						StitchedKidFear.FEAR_MAX) != int(projected_fear):
				return {"ok": false}
			var settled_fear: Dictionary = _kid_fear.apply_event_delta(int(fear_delta))
			if settled_fear.get("ok") != true or int(settled_fear.get("fear")) != int(projected_fear):
				return {"ok": false}
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
