extends SceneTree
## S14 effect matrix: every validated signature ability (8 heroes x 4 slots) meets
## every authored ability patch through real seeded battle commands. Each
## socketed cast runs the same public schedule as an identical unsocketed
## baseline battle on the same seed: the hit, roll, damage and target identity
## must match, and the patched receipt must equal the baseline receipt plus
## exactly the patch's own entry. The struck recipient's real state (statuses,
## HP, rank, the actor's guard) is verified per patch effect from data, never
## from a hardcoded rank or effect table. Dedicated sections cover the chain
## successor contract (a dead successor never falls through to another foe),
## ordered gold sockets through the death door, the stop-on-dead socket rule,
## misses, mask/unavailable-target refusals, socket validation refusals and a
## run-owned socket replayed from its genuine journal. A final routed section
## rides real seeded runs through two genuine victories, a real Sewing Circle
## socket and a live S15 witness fight: guard, movement and harmful ally
## patches land on their real recipients through public turns, public misses
## mutate nothing, a fully public death-door drive loses a hero with its
## authored satchel and party-fray receipts, and the whole route replays
## exactly from the journal.

const SEED := 55
const ROSTER_B := ["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const CLEARABLE := ["bleed", "weak", "exposed", "tangled", "blind", "mark", "stun"]
const REQUIRED_PATCHES := [
	"cotton_red_lint", "cotton_guard_stitch", "cotton_mending_fuzz",
	"wool_mark_thread", "wool_hook_stitch", "wool_heel_knot", "wool_steady_hem",
	"silk_moth_veil", "silk_pin_prick", "silk_life_loop", "silk_clean_seam", "silk_mildew_spore",
	"gold_hungry_button", "gold_chain_thread", "gold_heart_knot",
]
const HUNGRY := "gold_hungry_button"
const GOLD_HEART := "gold_heart_knot"
const CHAIN := "gold_chain_thread"
const COMMAND := "warden_head_pot_helm_command"
const FEINT := "rag_duelist_torso_feint_stitch"
const LINT := "cotton_red_lint"
const HEEL_KNOT := "wool_heel_knot"

var failures: Array[String] = []
var checks := 0
var _patch_by_id := {}
var _config_cache := {}
var _baselines := {}


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_catalog_ids()
	_matrix()
	_miss_and_refusals()
	_create_refusals()
	_dead_successor_chain()
	_ordered_gold_terminal()
	_stop_on_dead()
	_run_owned_sockets()
	_live_run_matrix()
	_routed_resistance_witnesses()
	for message in failures:
		printerr(message)
	print("stitched_s14_effect_matrix_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _catalog_ids() -> void:
	var patches := StitchedS14Abilities.patches()
	_check(not patches.is_empty(), "the validated ability patch catalog loads")
	if patches.is_empty():
		return
	_patch_by_id = patches.by_id
	for patch_id in REQUIRED_PATCHES:
		_check(_patch_by_id.has(patch_id), "required patch " + str(patch_id) + " is in the catalog")
	var kits := StitchedS14Abilities.kits()
	_check(not kits.is_empty(), "the validated signature kit catalog loads")
	for hero_id in StitchedPartyAdmission.HERO_IDS:
		var kit: Dictionary = kits.get(hero_id, {})
		_check(kit.size() == StitchedParts.SLOTS.size(), str(hero_id) + " owns its four signature abilities")
		for slot in StitchedParts.SLOTS:
			var ability: Dictionary = kit.get(slot, {})
			_check(not ability.is_empty() and str(ability.get("target_side", "")) in StitchedParts.TARGET_SIDES,
				str(hero_id) + " " + str(slot) + " signature validates")


## ---------------------------------------------------------------- matrix ----

func _matrix() -> void:
	var kits := StitchedS14Abilities.kits()
	for hero_id in StitchedPartyAdmission.HERO_IDS:
		for slot in StitchedParts.SLOTS:
			var ability: Dictionary = kits[hero_id][slot]
			for patch_id in _patch_by_id:
				_matrix_combo(str(hero_id), ability, _patch_by_id[patch_id])


func _roster_for(hero_id: String) -> Array:
	for id in StitchedRunSession.DEFAULT_PICKS:
		if str(id) == hero_id:
			return StitchedRunSession.DEFAULT_PICKS
	return ROSTER_B


func _base_config(picks: Array) -> Dictionary:
	var key := "|".join(PackedStringArray(picks))
	if not _config_cache.has(key):
		var config := StitchedRunSession.starter_config(picks)
		_check(not config.is_empty(), "matrix roster " + key + " loads its authored starter fixture")
		if config.is_empty():
			return {}
		_config_cache[key] = config
	var config: Dictionary = _config_cache[key].duplicate(true)
	config["seed"] = SEED
	config["s14"] = true
	# The matrix's public casts must face the same transformed foes a floor-one
	# live Fight mounts; plain authored foe records have no S15 resistance.
	for foe in config["foes"]:
		StitchedDeeperSeams.apply(foe, 1, "Fight")
	return config


func _matrix_battle(picks: Array, sockets: Dictionary) -> StitchedRules:
	var config := _base_config(picks)
	if config.is_empty():
		return null
	config["s14_sockets"] = sockets
	var built := StitchedRules.create(config)
	if not built.ok or built.battle == null:
		_check(false, "matrix roster " + "|".join(PackedStringArray(picks)) + " builds its seeded battle")
		return null
	return built.battle


func _to_turn(battle: StitchedRules, actor_id: String, limit: int = 96) -> bool:
	for step in range(limit):
		if battle.current_actor_id() == actor_id:
			return true
		if battle.is_over() or not battle.pass_turn().get("ok", false):
			return false
	return false


func _position_actor(battle: StitchedRules, hero_id: String, label: String) -> bool:
	# The uniform, patch-independent schedule puts the actor on an interior
	# launch rank: Rag Duelist steps back to rank two, Button Golem steps forward
	# from its displaced rank four. Every other hero already sits inside its own
	# launch masks. Both moves are real public turn actions.
	var moves: Array = []
	if hero_id == "rag_duelist":
		moves = [1]
	elif hero_id == "button_golem":
		moves = [-1, -1]
	for direction in moves:
		if not _to_turn(battle, hero_id):
			_check(false, label + ": the actor reaches a real move turn")
			return false
		var moved: Dictionary = battle.move(direction)
		if not moved.get("ok", false):
			_check(false, label + ": the public rank move resolves")
			return false
	return true


func _unit_alive_at(battle: StitchedRules, absolute: String, rank: int) -> Dictionary:
	if absolute == "foe":
		var foe: Dictionary = battle._foe_at(rank)
		if not foe.is_empty() and not bool(foe.dead) and int(foe.hp) > 0:
			return foe
		return {}
	var hero: Dictionary = battle._hero_at(rank)
	if hero.is_empty() or bool(hero.get("lost", false)):
		return {}
	return hero


## The cast rank is discovered from the authored target list and the living
## occupants of that side, preferring an interior rank so movement patches stay
## observable. Self signatures always use the actor's own rank.
func _discover_rank(battle: StitchedRules, ability: Dictionary, actor: Dictionary) -> int:
	var side := str(ability.target_side)
	if side == "self":
		var own := int(actor.rank)
		if own in ability["target"]:
			return own
		return -1
	var absolute := "foe" if side == "enemy" else "hero"
	var interior := -1
	var fallback := -1
	for rank in ability["target"]:
		var occupied := not _unit_alive_at(battle, absolute, int(rank)).is_empty()
		if not occupied:
			continue
		if fallback < 0:
			fallback = int(rank)
		if interior < 0 and 1 < int(rank) and int(rank) < 4:
			interior = int(rank)
	return interior if interior > 0 else fallback


func _recipients(battle: StitchedRules, ability: Dictionary, cast_rank: int) -> Array:
	var absolute := "foe" if str(ability.target_side) == "enemy" else "hero"
	if not bool(ability.multi):
		var single := _unit_alive_at(battle, absolute, cast_rank)
		return [single] if not single.is_empty() else []
	var found: Array = []
	for rank in range(1, 5):
		if not StitchedParts.ranks_allowed(int(ability.target_mask), rank):
			continue
		var unit := _unit_alive_at(battle, absolute, rank)
		if not unit.is_empty():
			found.append(unit)
	return found


## Position, optionally wound the heal witness, then cast through public turns
## until every result confirms (bounded attempts; a multi-target signature gets
## one attempt because a partial attempt already commits patch effects).
func _matrix_cast(battle: StitchedRules, hero_id: String, ability: Dictionary, patch: Dictionary, label: String, wound: bool) -> Dictionary:
	if not _position_actor(battle, hero_id, label):
		return {}
	var actor: Dictionary = battle._units[hero_id]
	_check(StitchedParts.ranks_allowed(int(ability.launch_mask), int(actor.rank)),
		label + ": the actor's rank is inside the authored launch mask")
	var cast_rank := _discover_rank(battle, ability, actor)
	if cast_rank < 1:
		_check(false, label + ": the authored target list offers a living legal rank")
		return {}
	if wound and (str(patch.get("effect", "")) == "heal" or ability.effects.has("heal")):
		var patient := _unit_alive_at(battle, "foe" if str(ability.target_side) == "enemy" else "hero", cast_rank)
		if patient.is_empty():
			_check(false, label + ": the heal witness recipient exists")
			return {}
		patient.hp = int(patient.hp) - 7
		if int(patient.hp) <= 0:
			_check(false, label + ": the heal witness has at least eight HP to spare")
			return {}
	var cap := 6
	if bool(ability.multi):
		cap = 1
	if str(patch.get("effect", "")) == "steal":
		cap = mini(cap, 3)
	var attempts := 0
	var last := {}
	while attempts < cap:
		if not _to_turn(battle, hero_id):
			_check(false, label + ": the actor reaches a real turn")
			return {}
		var before := {}
		for unit in _recipients(battle, ability, cast_rank):
			before[str(unit.id)] = {"hp": int(unit.hp), "rank": int(unit.rank), "statuses": unit.statuses.duplicate()}
		var actor_before := {"hp": int(actor.hp), "statuses": actor.statuses.duplicate()}
		var old_round := battle._round
		var old_index := battle._turn_index
		var old_order: Array = battle._order.duplicate()
		var receipt: Dictionary = battle.use_ability(str(ability.id), cast_rank)
		if not receipt.get("ok", false):
			_check(false, label + ": the public signature cast resolves")
			return {}
		attempts += 1
		# Public use_ability enters the next turn before returning. Track exactly
		# whose start-of-turn clocks have already ticked after the patch landed.
		var ticked: Array = []
		var end_old := battle._turn_index + 1 if battle._round == old_round else old_order.size()
		for index in range(old_index + 1, mini(end_old, old_order.size())):
			ticked.append(str(old_order[index]))
		if battle._round != old_round:
			for index in range(mini(battle._turn_index + 1, battle._order.size())):
				ticked.append(str(battle._order[index]))
		var results: Array = receipt.get("results", [])
		# A chain patch rolls its own follow-up after the primary resolves, so the
		# cast confirms on the primary alone and the seeded schedule stays identical
		# to the unsocketed twin's.
		var confirmed := results.size() > 0
		if str(patch.get("effect", "")) == "chain":
			confirmed = bool(results[0].get("hit", false))
		else:
			for hit in results:
				confirmed = confirmed and bool(hit.get("hit", false))
		if confirmed:
			return {"results": results, "before": before, "actor_before": actor_before, "cast_rank": cast_rank,
				"ticked": ticked, "round": battle._round}
		last = {"results": results, "before": before, "actor_before": actor_before, "cast_rank": cast_rank,
			"ticked": ticked, "round": battle._round}
	if last.is_empty():
		return {}
	var any_hit := false
	for hit in last["results"]:
		any_hit = any_hit or bool(hit.get("hit", false))
	if not any_hit:
		_check(false, label + ": the seeded cast confirms at least one hit")
		return {}
	return last


func _baseline_record(hero_id: String, ability: Dictionary, patch: Dictionary, label: String) -> Dictionary:
	var cap := 6
	if bool(ability.multi):
		cap = 1
	if str(patch.get("effect", "")) == "steal":
		cap = mini(cap, 3)
	var key := str(ability.id) + "|" + str(cap) + "|" + str(ability.effects.has("heal") or str(patch.effect) == "heal")
	if _baselines.has(key):
		return _baselines[key]
	var battle := _matrix_battle(_roster_for(hero_id), {})
	if battle == null:
		return {}
	var run := _matrix_cast(battle, hero_id, ability, patch, label + " baseline", true)
	if run.is_empty():
		return {}
	var record := {"results": run["results"].duplicate(true), "rng": battle.rng_state(), "round": run["round"]}
	_baselines[key] = record
	return record


func _matrix_combo(hero_id: String, ability: Dictionary, patch: Dictionary) -> void:
	var label := hero_id + "/" + str(ability.id) + " + " + str(patch.id)
	var battle := _matrix_battle(_roster_for(hero_id), {hero_id: {str(ability.id): [str(patch.id)]}})
	if battle == null:
		return
	# Foes never act on their own in this harness, so their pre-cast ranks are
	# the original line-up the chain successor is chosen from.
	var original_ranks := {}
	for rank in range(1, 5):
		var foe := battle._foe_at(rank)
		if not foe.is_empty():
			original_ranks[str(foe.id)] = rank
	var run := _matrix_cast(battle, hero_id, ability, patch, label, true)
	if run.is_empty():
		return
	var base := _baseline_record(hero_id, ability, patch, label)
	if base.is_empty():
		return
	if str(patch.effect) == "chain":
		_assert_chain(hero_id, ability, run, base, battle, label, original_ranks)
	else:
		_assert_effects(hero_id, ability, patch, run, base, battle, label)


func _authored_value(hit: Dictionary, status_key: String) -> int:
	for entry in hit.get("statuses", []):
		if str(entry.get("status", "")) == status_key:
			return int(entry.get("duration", entry.get("amount", 0)))
	return 0


func _authored_guard(hit: Dictionary) -> int:
	for entry in hit.get("statuses", []):
		if str(entry.get("status", "")) == "guard":
			return int(entry.get("duration", 0))
	return 0


func _authored_heal(hit: Dictionary) -> int:
	for entry in hit.get("statuses", []):
		if str(entry.get("status", "")) == "heal" and not entry.has("patch"):
			return int(entry.get("amount", 0))
	return 0


func _entries_with_patch(hit: Dictionary, status_key: String, patch_id: String) -> Array:
	var found: Array = []
	for entry in hit.get("statuses", []):
		if str(entry.get("status", "")) == status_key and str(entry.get("patch", "")) == patch_id:
			found.append(entry)
	return found


func _effective_resist(unit: Dictionary, patch: Dictionary) -> int:
	if str(unit.get("side", "")) != "foe":
		return 0
	var effect := str(patch.get("effect", ""))
	var group := effect
	if effect in ["push", "pull"]:
		group = "move"
	elif effect in StitchedRules.RESIST_DEBUFFS:
		group = "debuff"
	elif not effect in StitchedRules.RESIST_KEYS:
		return 0
	return maxi(0, int(unit.get("resist", {}).get(group, 0))
		- int(StitchedRules.PATCH_PIERCE.get(str(patch.get("rarity", "")), 0)))


func _resisted_patch_entry(hit: Dictionary, patch: Dictionary, authored_count: int) -> Dictionary:
	var entries: Array = hit.get("statuses", [])
	# The signature itself can be resisted (including its own push/pull).
	# Never mistake that authored entry for the patch's separate d100 roll.
	if entries.size() <= authored_count:
		return {}
	var tail: Dictionary = entries.back()
	return tail if str(tail.get("status", "")) == str(patch.get("effect", "")) \
		and bool(tail.get("resisted", false)) else {}


func _assert_primary_identity(rp: Dictionary, rb: Dictionary, label: String) -> bool:
	var same: bool = (rp.get("hit", false) == rb.get("hit", false)
		and str(rp.get("target", "")) == str(rb.get("target", ""))
		and rp.get("crit", false) == rb.get("crit", false)
		and int(rp.get("damage", 0)) == int(rb.get("damage", 0))
		and int(rp.get("roll", -1)) == int(rb.get("roll", -1))
		and int(rp.get("hit_chance", -1)) == int(rb.get("hit_chance", -1)))
	_check(same, label + ": seeded hit, roll, damage and target identity match the unsocketed cast")
	return same


## Authored movement first (the baseline twin's shift), then the patch's own step,
## swapping inside the measured recipient set in result order.
func _simulate_patch_movement(results_p: Array, results_b: Array, before: Dictionary, order: Array, direction: int) -> Dictionary:
	var ranks := {}
	for id in before:
		ranks[str(id)] = int(before[id]["rank"])
	var expected := {}
	for index in order:
		var id := str(results_p[index].get("target", ""))
		var authored: Dictionary = results_b[index].get("shift", {})
		if bool(authored.get("ok", false)):
			ranks[id] = int(authored.to)
		var from := int(ranks[id])
		# The signature's own tangle pins the struck unit in place: the patch's step
		# is refused, never forced and never traded for a different victim.
		var pinned := _authored_value(results_b[index], "tangled") > 0
		var dest := from + direction
		if pinned or dest < 1 or dest > 4:
			expected[id] = {"ok": false, "final": from}
			continue
		var partner := ""
		for other in ranks:
			if str(other) != id and int(ranks[other]) == dest:
				partner = str(other)
		ranks[id] = dest
		if not partner.is_empty():
			ranks[partner] = from
		expected[id] = {"ok": true, "from": from, "to": dest, "final": dest}
	# Later hits may swap a recipient again. Check its final place after the
	# complete multi-target cast, not its intermediate rank after its own hit.
	for id in expected:
		expected[id]["final"] = int(ranks[id])
	return expected


func _assert_effects(hero_id: String, ability: Dictionary, patch: Dictionary, run: Dictionary, base: Dictionary, battle: StitchedRules, label: String) -> void:
	var results_p: Array = run["results"]
	var results_b: Array = base["results"]
	if results_p.size() != results_b.size():
		_check(false, label + ": the socketed cast resolves exactly the baseline's primary results")
		return
	var patch_id := str(patch.id)
	var effect := str(patch.effect)
	var amount := int(patch.amount)
	var witnessed := false
	var prior_patch_resist_draw := false
	var movement := {}
	if effect == "pull" or effect == "push":
		var order: Array = []
		for index in results_p.size():
			if bool(results_p[index].get("hit", false)):
				order.append(index)
		movement = _simulate_patch_movement(results_p, results_b, run["before"], order, 1 if effect == "push" else -1)
	for index in results_p.size():
		var rp: Dictionary = results_p[index]
		var rb: Dictionary = results_b[index]
		var original_rng_aligned := not prior_patch_resist_draw
		if original_rng_aligned:
			if not _assert_primary_identity(rp, rb, label):
				return
		else:
			# Earlier resistant multi-target hits spent their own S15 d100,
			# legitimately shifting subsequent attack rolls. Keep checking
			# public target order, hit arithmetic and real receipts instead.
			_check(str(rp.get("target", "")) == str(rb.get("target", ""))
				and int(rp.get("roll", 0)) >= 1 and int(rp.get("roll", 0)) <= 100
				and bool(rp.get("hit", false)) == (int(rp.get("roll", 101)) <= int(rp.get("hit_chance", 0))),
				label + ": later multi-target attack uses its real shifted RNG roll and legal recipient")
		if not bool(rp.get("hit", false)):
			continue
		if rp.get("patches", []) != [patch_id]:
			_check(false, label + ": the confirmed hit carries exactly its socketed patch id")
			continue
		if rb.has("patches"):
			_check(false, label + ": the unsocketed baseline hit never carries patch ids")
			continue
		witnessed = true
		var recipient: Dictionary = battle.get_unit(str(rp.target))
		if recipient.is_empty() or bool(recipient.get("dead", false)) or bool(recipient.get("lost", false)):
			_check(false, label + ": the struck recipient is still present")
			return
		var before: Dictionary = run["before"].get(str(rp.target), {})
		var actor: Dictionary = battle._units[hero_id]
		var target_id := str(recipient.id)
		var target_ticks: int = run["ticked"].count(target_id)
		var actor_ticks: int = run["ticked"].count(hero_id)
		var expected: Array = rb.get("statuses", []).duplicate(true)
		if not original_rng_aligned:
			# The only enemy multi signature is Scrap Bomb: its authored
			# Exposed independently rolls S15 debuff resistance before the patch.
			# Validate that real entry instead of transplanting the baseline's
			# different post-resistance random roll.
			expected.clear()
			var actual: Array = rp.get("statuses", [])
			var authored_entry: Dictionary = actual[0] if not actual.is_empty() else {}
			var real_resist := int(recipient.get("resist", {}).get("debuff", 0))
			_check(bool(ability.multi) and int(ability.effects.get("exposed", 0)) > 0
				and str(authored_entry.get("status", "")) == "exposed"
				and (bool(authored_entry.get("resisted", false))
					and real_resist > 0 and int(authored_entry.get("resist", -1)) == real_resist
					and int(authored_entry.get("roll", 0)) >= 1
					and int(authored_entry.get("roll", 101)) <= real_resist
					or not bool(authored_entry.get("resisted", false))
					and int(authored_entry.get("duration", 0)) == int(ability.effects.exposed)),
				label + ": later multi-target authored Exposed reflects the S15 foe's real debuff resist")
			if not authored_entry.is_empty():
				expected.append(authored_entry)
		var net_resist := _effective_resist(recipient, patch)
		var resisted := _resisted_patch_entry(rp, patch, expected.size())
		if not resisted.is_empty():
			_check(net_resist > 0 and int(resisted.get("resist", -1)) == net_resist
				and int(resisted.get("roll", 0)) >= 1 and int(resisted.get("roll", 101)) <= net_resist,
				label + ": the recorded resist roll is within the real foe's resist minus rarity pierce " + str([effect, net_resist, resisted, recipient.get("resist", {})]))
			_check(rp.get("statuses", []) == expected + [resisted],
				label + ": resisted patch appends its honest roll after the authored receipt " + str([rp.get("statuses", []), expected]))
			if effect in ["push", "pull"]:
				_check(rp.get("shift", {}) == rb.get("shift", {})
					and int(recipient.rank) == int(before.rank),
					label + ": the resisted movement does not shift its actual target " + str([rp.get("shift", {}), rb.get("shift", {}), recipient.rank, before.rank]))
			elif effect in ["bleed", "mark", "blind", "stun", "rot"]:
				var authored := maxi(int(before.statuses.get(effect, 0)), _authored_value(rb, effect))
				var target_tick := 0 if effect == "blind" else target_ticks
				_check(int(recipient.statuses.get(effect, 0)) == maxi(0, authored - target_tick),
					label + ": resisted patch leaves only the signature's authored status")
			prior_patch_resist_draw = true
			continue
		# The signature itself may have a resisted entry of the same name
		# (for example Heel Spin's own Push), even when the sewn patch lands.
		# The separate patch roll was distinguished by the authored entry count.
		match effect:
			"bleed", "mark", "blind", "stun":
				expected.append({"status": effect, "duration": amount})
				var prior := maxi(int(before.statuses.get(effect, 0)), _authored_value(rb, effect))
				_check(int(recipient.statuses.get(effect, 0)) == maxi(0, maxi(prior, amount) - (0 if effect == "blind" else target_ticks)),
					label + ": the " + effect + " patch rests on the struck recipient at its authored amount")
				var tick_bleed := maxi(prior, amount) if effect == "bleed" and target_ticks > 0 else 0
				var expected_hp := mini(int(recipient.max_hp), int(before.hp) - int(rp.get("damage", 0))
					+ _authored_heal(rp)) - tick_bleed
				_check(int(recipient.hp) == expected_hp,
					label + ": the " + effect + " patch never changes the struck recipient's HP")
			"rot":
				expected.append({"status": "rot", "duration": amount})
				var prior_rot := maxi(int(before.statuses.get("rot", 0)), _authored_value(rb, "rot"))
				_check(int(recipient.statuses.get("rot", 0)) == maxi(0, maxi(prior_rot, amount) - target_ticks),
					label + ": the rot patch rests on the struck recipient at its authored amount")
				if target_ticks == 0:
					_check(int(recipient.hp) == mini(int(recipient.max_hp), int(before.hp)
						- int(rp.get("damage", 0)) + _authored_heal(rp)),
						label + ": the rot patch never changes the struck recipient's HP on the hit")
			"guard":
				var expected_guard := maxi(maxi(int(run["actor_before"].statuses.get("guard", 0)), _authored_guard(rb)), amount)
				expected.append({"status": "guard", "duration": expected_guard, "guards": target_id})
				# Multi-target guard retargets on every confirmed recipient. The
				# final guard points to the last one, not every earlier hit.
				var last_guard_target := target_id
				for later in results_p:
					if bool(later.get("hit", false)):
						last_guard_target = str(later.get("target", ""))
				var remaining_guard := maxi(0, expected_guard - actor_ticks)
				_check(int(actor.statuses.get("guard", 0)) == remaining_guard
					and str(actor.get("guard_target", "")) == (last_guard_target if remaining_guard > 0 else ""),
					label + ": the guard patch guards the struck recipient from the actor")
			"regen":
				expected.append({"status": "regen", "duration": amount, "patch": patch_id})
				_check(int(recipient.statuses.get("regen", 0)) == maxi(0, amount - target_ticks),
					label + ": the regen patch rests on the struck recipient only")
			"cleanse":
				expected.append({"status": "cleanse", "patch": patch_id})
				for status_key in CLEARABLE:
					_check(int(recipient.statuses.get(status_key, 0)) == 0,
						label + ": the cleanse patch erases " + status_key + " from the struck recipient")
			"heal":
				var hp_mid := mini(int(recipient.max_hp), int(before.hp) - int(rp.get("damage", 0)) + _authored_heal(rp))
				var healed := mini(amount, int(recipient.max_hp) - hp_mid)
				expected.append({"status": "heal", "amount": healed, "patch": patch_id})
				_check(int(recipient.hp) == hp_mid + healed and int(rp.get("target_hp", -1)) == int(recipient.hp),
					label + ": the heal patch mends the struck recipient exactly, capped at maximum")
				if str(recipient.side) == "hero":
					_check(not bool(recipient.hanging) and int(recipient.get("death_hits", 0)) == 0,
						label + ": the healed recipient keeps clean hanging and death-door state")
			"steal":
				var mid := mini(int(recipient.max_hp), int(before.hp) - int(rp.get("damage", 0)) + _authored_heal(rp))
				var drained := mini(mid, amount)
				expected.append({"status": "steal", "amount": drained, "patch": patch_id})
				if target_id == hero_id:
					# A self-bite drains its own caster and pours the stuffing straight back:
					# the survivor nets zero, and the receipt reports the bitten HP.
					_check(int(recipient.hp) == mid and int(rp.get("target_hp", -1)) == mid - drained,
						label + ": the self-steal bites its own caster and reports the bitten HP")
				else:
					_check(int(recipient.hp) == mid - drained and int(rp.get("target_hp", -1)) == int(recipient.hp),
						label + ": the steal patch drains exactly its actual amount from the struck recipient")
					_check(int(actor.hp) == mini(int(actor.max_hp), int(run["actor_before"].hp) + drained),
						label + ": the steal patch restores the caster exactly what it drained, capped")
			"pull", "push":
				var step: Dictionary = movement.get(target_id, {})
				var shifted: Dictionary = rp.get("shift", {})
				if bool(step.get("ok", false)):
					_check(bool(shifted.get("ok", false)) and int(shifted.get("from", -1)) == int(step.from)
						and int(shifted.get("to", -1)) == int(step.to),
						label + ": the " + effect + " patch shift receipt reports the real single step")
				else:
					_check(not bool(shifted.get("ok", true)),
						label + ": a boundary " + effect + " is refused, never forced")
				_check(int(recipient.rank) == int(step.get("final", -1)),
					label + ": the " + effect + " patch moves the struck recipient exactly one rank")
		_check(rp.get("statuses", []) == expected,
			label + ": the patched receipt keeps every authored entry, then appends exactly the patch's own")
		prior_patch_resist_draw = prior_patch_resist_draw or net_resist > 0
	if not witnessed:
		_check(false, label + ": at least one confirmed hit receives the patch")
	# A patch against a genuinely resistant S15 foe rolls one extra d100
	# even when it lands. That draw is not an RNG leak: only effects with
	# zero effective resistance must preserve the unsocketed stream.
	var extra_resist_draw := false
	for hit in results_p:
		if bool(hit.get("hit", false)) and (hit.get("patches", []) as Array).has(patch_id):
			extra_resist_draw = extra_resist_draw or _effective_resist(
				battle.get_unit(str(hit.get("target", ""))), patch) > 0
	if not extra_resist_draw and (effect != "stun" or int(run["round"]) == int(base["round"])):
		_check(battle.rng_state() == int(base["rng"]),
			label + ": a patch without a resistance draw preserves the baseline RNG")


func _assert_chain(hero_id: String, ability: Dictionary, run: Dictionary, base: Dictionary, battle: StitchedRules, label: String, original_ranks: Dictionary) -> void:
	var results_p: Array = run["results"]
	var results_b: Array = base["results"]
	if str(ability.target_side) != "enemy" or bool(ability.multi):
		_check(results_p == results_b,
			label + ": the chain patch leaves a non-enemy or multi signature exactly unsocketed")
		for hit in results_p:
			_check(not bool(hit.get("chained", false)) and not hit.has("patches"),
				label + ": no result of a non-enemy or multi signature is chained or patch-marked")
		return
	var primary_id := str(results_p[0].get("target", ""))
	var anchor_rank := int(original_ranks.get(primary_id, -1))
	# The one documented successor: the originally next foe behind the anchor
	# whose original rank the authored mask still allows.
	var successor_id := ""
	for foe_id in original_ranks:
		var original_rank := int(original_ranks[foe_id])
		if original_rank > anchor_rank and str(foe_id) != primary_id \
				and StitchedParts.ranks_allowed(int(ability.target_mask), original_rank):
			successor_id = str(foe_id)
			break
	if successor_id.is_empty():
		_check(results_p == results_b,
			label + ": no eligible original successor means no chained hit at all")
		_check(battle.rng_state() == int(base["rng"]),
			label + ": a refused chain consumes no RNG beyond the unsocketed cast")
		return
	if results_p.size() != results_b.size() + 1:
		_check(false, label + ": the chain patch adds exactly one extra successor hit")
		return
	var primary_p: Dictionary = results_p[0]
	var primary_b: Dictionary = results_b[0]
	if not _assert_primary_identity(primary_p, primary_b, label):
		return
	_check(primary_p.get("statuses", []) == primary_b.get("statuses", [])
		and not primary_p.has("patches") and not bool(primary_p.get("chained", false)),
		label + ": the primary hit stays exactly the unsocketed primary")
	var chained: Dictionary = results_p[results_p.size() - 1]
	_check(bool(chained.get("chained", false)) and str(chained.get("target", "")) == successor_id,
		label + ": the extra hit is a flagged chain onto the originally next eligible foe")
	_check(not chained.has("patches"), label + ": the chain patch itself never marks a receipt")
	var successor: Dictionary = battle.get_unit(successor_id)
	_check(not successor.is_empty() and str(successor.side) == "foe" and int(successor.hp) > 0,
		label + ": the chained foe is real and still standing")
	if bool(chained.get("hit", false)):
		for status_key in ["bleed", "weak", "exposed", "mark", "blind", "stun", "tangled"]:
			var authored := _authored_value(primary_b, status_key)
			if authored > 0:
				var resisted_entry := {}
				for entry in chained.get("statuses", []):
					if str(entry.get("status", "")) == status_key and bool(entry.get("resisted", false)):
						resisted_entry = entry
				var resist_key: String = "debuff" if status_key in StitchedRules.RESIST_DEBUFFS else str(status_key)
				var real_resist := int(successor.get("resist", {}).get(resist_key, 0))
				_check((not resisted_entry.is_empty() and real_resist > 0
					and int(resisted_entry.get("resist", -1)) == real_resist
					and int(resisted_entry.get("roll", 0)) >= 1
					and int(resisted_entry.get("roll", 101)) <= real_resist)
					or (resisted_entry.is_empty() and int(successor.statuses.get(status_key, 0)) >= authored),
					label + ": the chained authored " + status_key + " lands or has an honest S15 resisted roll")
		var authored_move: Dictionary = primary_b.get("shift", {})
		if bool(authored_move.get("ok", false)):
			_check(chained.has("shift"), label + ": the chained hit carries the signature's authored movement too")


## --------------------------------------------------------- negative paths ----

func _miss_and_refusals() -> void:
	var battle := _matrix_battle(StitchedRunSession.DEFAULT_PICKS,
		{"warden": {COMMAND: [HUNGRY, HEEL_KNOT]}})
	if battle == null:
		return
	var foe: Dictionary = battle._foe_at(2)
	if foe.is_empty() or not _to_turn(battle, "warden"):
		_check(false, "miss fixture reaches a real Warden turn with a real rank-two foe")
		return
	battle._units["warden"].statuses["blind"] = 1
	var receipt: Dictionary = battle.use_ability(COMMAND, 2)
	var results: Array = receipt.get("results", [])
	_check(receipt.get("ok", false) and results.size() == 1 and not bool(results[0].get("hit", true))
		and str(results[0].get("target", "")) == str(foe.id),
		"the blinded socketed signature misses the real living foe")
	var miss: Dictionary = results[0] if results.size() == 1 else {}
	_check(not miss.has("patches") and not miss.has("shift")
		and battle.get_unit(str(foe.id)).rank == 2
		and int(battle.get_unit(str(foe.id)).hp) == int(foe.hp)
		and int(battle.get_unit(str(foe.id)).statuses.get("mark", 0)) == 0,
		"the miss never applies, moves or marks the foe through its sockets")
	for illegal_rank in [0, 4, -1]:
		if not _to_turn(battle, "warden"):
			_check(false, "rank-refusal fixture reaches a fresh Warden turn")
			return
		var before := battle.state_snapshot()
		var before_rng := battle.rng_state()
		var refused: Dictionary = battle.use_ability(COMMAND, illegal_rank)
		_check(not refused.get("ok", true) and battle.state_snapshot() == before
			and battle.rng_state() == before_rng,
			"the mask-illegal rank %d is a no-spend, no-RNG refusal" % illegal_rank)
	var fallen: Dictionary = battle._foe_at(3)
	if fallen.is_empty() or not _to_turn(battle, "warden"):
		_check(false, "unavailable-target fixture finds a live rank-three foe and a Warden turn")
		return
	var death := {}
	battle._damage_target(fallen, int(fallen.hp), death)
	if not death.has("heap"):
		_check(false, "unavailable-target fixture kills the rank-three foe for real")
		return
	# The fallen foe leaves a scrap heap behind: clear it too, so the rank holds
	# neither a living foe nor a heap, only an authentically empty rank.
	var wreck: Dictionary = battle._heap_at(3)
	if wreck.is_empty():
		_check(false, "unavailable-target fixture finds the fallen foe's scrap heap")
		return
	battle._damage_target(wreck, int(wreck.hp), death)
	if not death.has("heap_cleared"):
		_check(false, "unavailable-target fixture clears the scrap heap for real")
		return
	var prior := battle.state_snapshot()
	var prior_rng := battle.rng_state()
	_check(not battle.use_ability(COMMAND, 3).get("ok", true)
		and battle.state_snapshot() == prior and battle.rng_state() == prior_rng,
		"a mask-legal rank without a living target refuses atomically")
	if not _to_turn(battle, "warden"):
		_check(false, "forged-signature fixture reaches a fresh Warden turn")
		return
	var snap := battle.state_snapshot()
	_check(not battle.use_ability("forged_signature", 2).get("ok", true)
		and battle.state_snapshot() == snap,
		"the unknown signature id refuses without mutating state")


func _create_refusals() -> void:
	var forged := _base_config(StitchedRunSession.DEFAULT_PICKS)
	forged["s14_sockets"] = {"warden": {COMMAND: ["made_up_patch"]}}
	_check(not StitchedRules.create(forged).ok, "a forged patch id in battle sockets fails closed")
	var outside := _base_config(StitchedRunSession.DEFAULT_PICKS)
	outside["s14_sockets"] = {"missing_doll": {COMMAND: ["wool_mark_thread"]}}
	_check(not StitchedRules.create(outside).ok, "a socket owner outside the party fails closed")
	var over := _base_config(StitchedRunSession.DEFAULT_PICKS)
	over["s14_sockets"] = {"warden": {COMMAND: ["wool_mark_thread", LINT]}}
	_check(not StitchedRules.create(over).ok, "two non-gold patches exceed the socket limit")
	var legal := _base_config(StitchedRunSession.DEFAULT_PICKS)
	legal["s14_sockets"] = {"warden": {COMMAND: [CHAIN, "wool_mark_thread"]}}
	_check(StitchedRules.create(legal).ok, "a gold patch admits exactly one second socket")


## The documented chain contract: the successor is the originally next eligible
## foe. When that one foe is dead, the chain must not fall through to a different
## foe behind it.
func _dead_successor_chain() -> void:
	var battle := _matrix_battle(StitchedRunSession.DEFAULT_PICKS, {"warden": {COMMAND: [CHAIN]}})
	var plain := _matrix_battle(StitchedRunSession.DEFAULT_PICKS, {})
	if battle == null or plain == null:
		return
	var crab: Dictionary = battle._foe_at(2)
	var plain_crab: Dictionary = plain._foe_at(2)
	var death := {}
	var plain_death := {}
	battle._damage_target(crab, int(crab.hp), death)
	plain._damage_target(plain_crab, int(plain_crab.hp), plain_death)
	_check(death.has("heap") and plain_death.has("heap") and bool(crab.dead) and bool(plain_crab.dead),
		"dead-successor fixture: the originally next foe is really dead in both battles")
	var receipt := {}
	var plain_receipt := {}
	for attempt in 6:
		if not _to_turn(battle, "warden") or not _to_turn(plain, "warden"):
			_check(false, "dead-successor fixture reaches real Warden turns")
			return
		receipt = battle.use_ability(COMMAND, 1)
		plain_receipt = plain.use_ability(COMMAND, 1)
		var results: Array = receipt.get("results", [])
		if results.size() == 1 and bool(results[0].get("hit", false)):
			break
	var results: Array = receipt.get("results", [])
	var plain_results: Array = plain_receipt.get("results", [])
	if results.size() != 1 or plain_results.size() != 1:
		_check(false, "dead-successor fixture confirms the rank-one primary in both battles")
		return
	_check(bool(results[0].get("hit", false)) and not bool(results[0].get("chained", false)),
		"the socketed signature confirms its rank-one primary with no chained follow-up")
	_check(results[0].get("roll", -1) == plain_results[0].get("roll", -1)
		and results[0].get("damage", 0) == plain_results[0].get("damage", 0)
		and results[0].get("statuses", []) == plain_results[0].get("statuses", []),
		"the dead successor draws no extra hit roll or effect against the identical plain cast")
	_check(battle.rng_state() == plain.rng_state(),
		"a dead successor consumes exactly the unsocketed RNG stream")
	var moth: Dictionary = battle._foe_at(3)
	_check(not moth.is_empty() and int(battle.get_unit(str(moth.id)).hp) == int(moth.hp)
		and battle.get_unit(str(moth.id)).rank == 3
		and int(battle.get_unit(str(moth.id)).statuses.get("mark", 0)) == 0,
		"the dead successor's fall-through never strikes the rank-three foe")


## Ordered gold sockets on a death-door self signature. [Hungry, Heart] bites
## through the terminal door and the second heal never reaches the LOST doll;
## the reversed [Heart, Hungry] heals first, so the bite is survivable.
func _ordered_gold_terminal() -> void:
	for order in [[HUNGRY, GOLD_HEART], [GOLD_HEART, HUNGRY]]:
		var battle := _matrix_battle(ROSTER_B, {"rag_duelist": {FEINT: order}})
		if battle == null:
			return
		if not _to_turn(battle, "rag_duelist"):
			_check(false, "ordered gold fixture reaches a real Rag Duelist turn")
			return
		var doll: Dictionary = battle._units["rag_duelist"]
		doll.hp = 1
		doll.parts.arms.torn = true
		doll.parts.legs.torn = true
		doll.death_hits = 2
		battle._recompute_stats(doll)
		_check(int(doll.hp) == 1 and int(doll.death_hits) == 2 and not bool(doll.lost),
			"ordered gold precondition: two torn limbs at one HP, two door hits")
		var receipt: Dictionary = battle.use_ability(FEINT, int(doll.rank))
		var results: Array = receipt.get("results", [])
		if results.size() != 1 or not bool(results[0].get("hit", false)):
			_check(false, "ordered gold self signature resolves on its caster")
			return
		var hit: Dictionary = results[0]
		var dodge := false
		for entry in hit.get("statuses", []):
			if str(entry.get("status", "")) == "dodge":
				dodge = true
		_check(dodge, "the authored Feint Stitch dodge still stamps the receipt")
		if str(order[0]) == HUNGRY:
			var door: Dictionary = hit.get("death_door", {})
			_check(bool(hit.get("lost", false)) and int(door.get("hits", 0)) == 3
				and str(door.get("tear", {}).get("slot", "")) == "head",
				"the ordered Hungry Button bites through the terminal third door hit")
			_check(bool(doll.lost) and int(doll.hp) == 0 and doll.parts.is_empty(),
				"the LOST caster keeps zero HP and no equipment")
			_check(hit.get("patches", []) == [HUNGRY],
				"the receipt carries only the executed Hungry Button")
			_check(_entries_with_patch(hit, "heal", GOLD_HEART).is_empty()
				and _entries_with_patch(hit, "steal", HUNGRY).is_empty(),
				"the LOST doll never drains or heals through its own fall")
			_check(int(hit.get("target_hp", -1)) == 0,
				"the receipt reports the LOST caster's final zero HP")
		else:
			_check(not bool(doll.lost) and int(doll.hp) == 6 and not bool(doll.hanging)
				and int(doll.death_hits) == 0,
				"reversed Heart Knot heals the death-door doll before Hungry Button drains it")
			_check(hit.get("patches", []) == [GOLD_HEART, HUNGRY],
				"both ordered gold patches execute in their socket order")
			var healed := _entries_with_patch(hit, "heal", GOLD_HEART)
			var bitten := _entries_with_patch(hit, "steal", HUNGRY)
			_check(healed.size() == 1 and int(healed[0].get("amount", -1)) == 5,
				"the gold heal restores five before the bite lands")
			_check(bitten.size() == 1 and int(bitten[0].get("amount", -1)) == 3
				and int(hit.get("target_hp", -1)) == 3,
				"the second Hungry Button drains exactly three from the healed caster")


## Ordered sockets stop at a death: the killing steal leaves no room for the
## Cotton Lint behind it.
func _stop_on_dead() -> void:
	var battle := _matrix_battle(StitchedRunSession.DEFAULT_PICKS,
		{"warden": {COMMAND: [HUNGRY, LINT]}})
	if battle == null:
		return
	var crab: Dictionary = battle._foe_at(2)
	if crab.is_empty() or not _to_turn(battle, "warden"):
		_check(false, "stop-on-dead fixture reaches a real Warden turn with a real foe")
		return
	crab.hp = 3
	var receipt: Dictionary = battle.use_ability(COMMAND, 2)
	var results: Array = receipt.get("results", [])
	if results.size() != 1 or not bool(results[0].get("hit", false)):
		_check(false, "stop-on-dead fixture confirms its rank-two strike")
		return
	var hit: Dictionary = results[0]
	_check(bool(crab.dead) and int(battle.get_unit(str(crab.id)).hp) == 0 and hit.has("heap"),
		"the ordered Hungry Button's bite kills the three-HP foe and settles its heap")
	_check(hit.get("patches", []) == [HUNGRY],
		"no later patch in the order reaches the foe the steal just killed")
	_check(_entries_with_patch(hit, "bleed", LINT).is_empty()
		and battle.get_unit(str(crab.id)).statuses.is_empty(),
		"the skipped Cotton Lint never bleeds the dead foe")


## ----------------------------------------------- run-owned sockets, replay ----

func _first_choice_of_type(session: StitchedRunSession, kind: String) -> String:
	for id in session.choices():
		if str(session.map.get_node(id).type) == kind:
			return str(id)
	return ""


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


func _first_foe_rank(battle: StitchedRules) -> int:
	for rank in range(1, 4):
		if not battle._foe_at(rank).is_empty():
			return rank
	return -1


func _assert_live_patch(battle: StitchedRules, receipt: Dictionary, patch: Dictionary, label: String) -> void:
	var results: Array = receipt.get("results", [])
	if str(patch.effect) == "chain":
		# A chain patch never marks a receipt: its witness is the flagged extra
		# hit onto the originally next eligible foe, whenever one exists.
		var signed: Dictionary = StitchedS14Abilities.ability("warden", COMMAND)
		var mask := int(signed.get("target_mask", 0))
		var struck_rank := 0
		var chained_seen := false
		for entry in results:
			if bool(entry.get("chained", false)):
				chained_seen = true
			elif struck_rank == 0:
				struck_rank = int(battle.get_unit(str(entry.get("target", ""))).rank)
		var eligible := false
		for rank in range(struck_rank + 1, 5):
			if StitchedParts.ranks_allowed(mask, rank) and not battle._foe_at(rank).is_empty():
				eligible = true
		_check(chained_seen or not eligible,
			label + ": the live chain patch strikes the originally next eligible foe")
		return
	var witnessed := false
	for hit in results:
		if not bool(hit.get("hit", false)) or not hit.get("patches", []).has(str(patch.id)):
			continue
		witnessed = true
		var recipient: Dictionary = battle.get_unit(str(hit.target))
		var effect := str(patch.effect)
		var amount := int(patch.amount)
		# S15: a live foe may shrug off a patch its rarity does not pierce; the
		# receipt then names the roll under the resist and the foe stays put.
		var resisted := false
		for entry in hit.get("statuses", []):
			if str(entry.get("status", "")) == effect and bool(entry.get("resisted", false)):
				resisted = int(entry.get("roll", 101)) <= int(entry.get("resist", 0))
		if resisted:
			_check(str(recipient.side) == "foe" and not hit.has("shift"),
				label + ": the live " + effect + " resist is a foe's roll under its resist and moves no one")
			continue
		match effect:
			"bleed", "mark", "blind", "stun":
				_check(int(recipient.statuses.get(effect, 0)) >= amount,
					label + ": the live " + effect + " rests on the struck unit")
			"regen":
				_check(int(recipient.statuses.get("regen", 0)) == amount,
					label + ": the live regen rests on the struck unit")
			"guard":
				_check(int(battle._units["warden"].statuses.get("guard", 0)) >= amount,
					label + ": the live guard rests on the casting actor")
			"cleanse":
				var cleared := true
				for status_key in CLEARABLE:
					cleared = cleared and int(recipient.statuses.get(status_key, 0)) == 0
				_check(cleared, label + ": the live cleanse wipes the struck unit's debuffs")
			"heal", "steal":
				_check(int(hit.get("target_hp", -1)) == int(recipient.hp),
					label + ": the live " + effect + " reports the recipient's final HP")
			"pull", "push":
				var shifted: Dictionary = hit.get("shift", {})
				_check(shifted.has("ok") and int(recipient.rank) == int(shifted.get("to", shifted.get("from", int(recipient.rank)))),
					label + ": the live " + effect + " matches its shift receipt")
	if not witnessed:
		_check(false, label + ": at least one live hit carries the owned patch")


func _run_owned_sockets() -> void:
	var run: StitchedRunSession = null
	for seed_number in range(50):
		var session := StitchedRunSession.start(seed_number)
		if session == null:
			continue
		var route := true
		for step in 2:
			var fight := _first_choice_of_type(session, "Fight")
			if fight.is_empty() or not session.enter(fight, session.snapshot()):
				route = false
				break
			if not _play_to_victory(session) or not session.settle_battle(session.battle):
				route = false
				break
		if not route:
			continue
		var circle := _first_choice_of_type(session, "SewingCircle")
		if circle.is_empty() or not session.enter(circle, session.snapshot()):
			continue
		run = session
		break
	_check(run != null, "a seeded run reaches two real victories and then a Sewing Circle")
	if run == null:
		return
	var owned: Array = run.ability_inventory
	_check(owned.size() >= 2 and int(run.scraps) >= 2,
		"two real settled fights own two patches and pay for one socket")
	if owned.size() < 2 or int(run.scraps) < 2:
		return
	var chosen: Dictionary = owned[0]
	var patch: Dictionary = _patch_by_id.get(str(chosen.id), {})
	_check(not patch.is_empty(), "the run-owned patch is a real catalog patch")
	if patch.is_empty():
		return
	var before := run.snapshot()
	var forged := run.socket_ability(99999, "warden", COMMAND, 0, run.snapshot())
	var stale := run.snapshot()
	stale["scraps"] = int(stale.get("scraps", 0)) + 1
	var refused := run.socket_ability(int(chosen.uid), "warden", COMMAND, 0, stale)
	_check(not forged and not refused and before == run.snapshot(),
		"a forged uid and a stale socket request refuse without spending or mutating")
	_check(run.socket_ability(int(chosen.uid), "warden", COMMAND, 0, run.snapshot())
		and int(run.scraps) == int(before.get("scraps", 0)) - 2,
		"the run-owned patch sockets onto its signature for two real scraps")
	var projected: Dictionary = run._battle_sockets()
	_check(projected.get("warden", {}).get(COMMAND, []) == [str(chosen.id)],
		"the owned socket projects its patch id into the live fixed kit")
	_check(run.choose_visit("leave", [], run.snapshot()) and run.phase == "map",
		"leaving the Sewing Circle returns to the map")
	var fight := ""
	# The authored seeded route can interpose a Campfire or another visit
	# between a Sewing Circle and its next fight. Travel through real map
	# choices and real enabled visit actions rather than jumping nodes.
	for step in 16:
		for choice_id in run.choices():
			if str(run.map.get_node(choice_id).type) in ["Fight", "Elite", "Boss"]:
				fight = str(choice_id)
				break
		if not fight.is_empty():
			break
		var choices: Array = run.choices()
		if choices.is_empty() or not run.enter(str(choices[0]), run.snapshot()) or run.phase != "visit":
			break
		var left := false
		for action in run.visit_actions():
			if bool(action.enabled) and str(action.id) == "leave" and action.arguments.is_empty():
				left = run.choose_visit("leave", [], run.snapshot())
				break
		if not left:
			for action in run.visit_actions():
				if bool(action.enabled) and action.arguments.is_empty() and not str(action.id) in ["swap", "replace", "buy_patch"]:
					left = run.choose_visit(str(action.id), action.arguments, run.snapshot())
					if left:
						break
		if not left or run.phase != "map":
			break
	_check(not fight.is_empty() and run.enter(fight, run.snapshot()) and run.phase == "battle",
		"the run enters a real combat node carrying the socketed kit")
	if fight.is_empty() or run.phase != "battle":
		return
	var battle: StitchedRules = run.battle
	var sockets_seen: Dictionary = battle.state_snapshot().get("s14", {}).get("sockets", {})
	var only_owned: bool = sockets_seen.get("warden", {}).get(COMMAND, []) == [str(chosen.id)]
	for hero_key in sockets_seen:
		for socket_key in sockets_seen[hero_key]:
			if str(hero_key) != "warden" or str(socket_key) != COMMAND:
				only_owned = only_owned and sockets_seen[hero_key][socket_key].is_empty()
	_check(only_owned,
		"the live ranked battle carries the run-owned patch and no forged sockets")
	var cast := {}
	for attempt in 6:
		if not _to_turn(battle, "warden"):
			break
		var rank := _first_foe_rank(battle)
		if rank < 1:
			break
		var receipt: Dictionary = battle.use_ability(COMMAND, rank)
		if not receipt.get("ok", false):
			continue
		var results: Array = receipt.get("results", [])
		for hit in results:
			if bool(hit.get("hit", false)):
				cast = receipt
	if cast.is_empty():
		_check(false, "the socketed signature casts through the run's journaled battle")
		return
	_assert_live_patch(battle, cast, patch, "run-owned socket")
	var journal_socket := false
	var journal_battle := false
	for command in run.journal:
		if str(command.get("action", "")) == "socket":
			journal_socket = true
		if str(command.get("action", "")) == "battle" and str(command.get("method", "")) == "use_ability":
			journal_battle = true
	_check(journal_socket and journal_battle,
		"the owned socket and the live cast both entered the deterministic journal")
	var document := StitchedRunSave.capture(run)
	_check(not document.is_empty(), "the midbattle run captures an authenticated save")
	if document.is_empty():
		return
	var restored: StitchedRunSession = StitchedRunSave.restore(document)
	_check(restored != null and restored.snapshot() == run.snapshot(),
		"the genuine journal replays the owned socket and its battle commands exactly")

## ------------------------------------- live seeded run-opened fights ----

const LIVE_PLANS := [["enemy", "warden", "head"], ["ally", "tinker", "legs"], ["self", "tinker", "torso"]]
const LIVE_SEED_CAP := 45


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


## Every confirmed live hit carrying the patch records an honest S15 decision: a
## resisted roll inside the foe's rarity-pierced group resist, or a landed patch
## that beat that same roll. The flags drive the bounded seed search.
func _live_decision_coverage(battle: StitchedRules, patch: Dictionary, results: Array, coverage: Dictionary, label: String) -> void:
	var patch_id := str(patch.get("id", ""))
	var effect := str(patch.get("effect", ""))
	for hit in results:
		if not bool(hit.get("hit", false)) or hit.get("patches", []) != [patch_id]:
			continue
		var recipient: Dictionary = battle.get_unit(str(hit.get("target", "")))
		var net := _effective_resist(recipient, patch)
		var resisted_entry := {}
		for entry in hit.get("statuses", []):
			if str(entry.get("status", "")) == effect and bool(entry.get("resisted", false)):
				resisted_entry = entry
		if not resisted_entry.is_empty():
			var honest := net > 0 and int(resisted_entry.get("roll", 0)) >= 1 \
				and int(resisted_entry.get("roll", 101)) <= net \
				and int(resisted_entry.get("resist", -1)) == net
			coverage["resisted"] = bool(coverage["resisted"]) or honest
			_check(honest, label + ": the live resisted decision rolls inside the foe's rarity-pierced resist")
		elif net > 0:
			coverage["landed_resistant"] = true


## The living foe rank whose rarity-pierced resist for this patch sits closest to
## an even d100, so a short string of lawful casts meets both decision outcomes.
func _balanced_resist_rank(battle: StitchedRules, ability: Dictionary, patch: Dictionary) -> int:
	var best := -1
	var best_gap := 1000
	for rank in ability.get("target", []):
		if not StitchedParts.ranks_allowed(int(ability.get("target_mask", 0)), int(rank)):
			continue
		var foe := battle._foe_at(int(rank))
		if foe.is_empty() or bool(foe.dead) or int(foe.hp) <= 0:
			continue
		var net := _effective_resist(foe, patch)
		if net <= 0:
			continue
		var gap := absi(net - 50)
		if gap < best_gap:
			best_gap = gap
			best = int(rank)
	return best


## One live seeded run: two lawful victories pay the socket, the Sewing Circle sews
## the run-owned patch onto the plan's signature, and the next real fight witnesses
## it through public turns only. An aligned unsocketed twin (the same journal minus
## the socket commands) proves the patched cast equals the identical schedule's
## plain cast plus exactly the patch's own receipt, against live S15 foes.
func _live_run_attempt(plan: String, hero_id: String, slot: String, seed_number: int, coverage: Dictionary) -> bool:
	var session := StitchedRunSession.start(seed_number)
	if session == null:
		return false
	for step in 2:
		var fight := _travel_to(session, ["Fight"])
		if fight.is_empty() or session.phase != "battle":
			return false
		if not _play_to_victory(session) or not session.settle_battle(session.battle):
			return false
	if session.ability_inventory.is_empty() or session.scraps < StitchedRunSession.SEWING_COST:
		return false
	var circle := _travel_to(session, ["SewingCircle"])
	if circle.is_empty() or session.phase != "visit":
		return false
	var chosen: Dictionary = session.ability_inventory[0]
	var patch: Dictionary = _patch_by_id.get(str(chosen.get("id", "")), {})
	var signature: Dictionary = StitchedS14Abilities.kits().get(hero_id, {}).get(slot, {})
	if patch.is_empty() or signature.is_empty():
		return false
	var signature_id := str(signature.get("id", ""))
	var label := "live " + plan + " run seed " + str(seed_number)
	if not session.socket_ability(int(chosen.get("uid", 0)), hero_id, signature_id, 0, session.snapshot()):
		return false
	if not session.choose_visit("leave", [], session.snapshot()) or session.phase != "map":
		return false
	var witness := _travel_to(session, ["Fight", "Elite"])
	if witness.is_empty() or session.phase != "battle" or session.battle == null:
		return false
	var battle: StitchedRules = session.battle
	if bool(battle._units[hero_id].get("lost", false)):
		return false
	var journal := session.journal.duplicate(true)
	var twin := StitchedRunSession.start(seed_number)
	if twin == null:
		return false
	for command in journal:
		if command is Dictionary and command.get("action") == "socket":
			continue
		if not StitchedRunSave._replay(twin, command):
			_check(false, label + ": the lawful journal replays on a fresh same-seed session")
			return false
	if twin.phase != "battle" or twin.battle == null:
		_check(false, label + ": the twin opens the same witness battle")
		return false
	var twin_battle: StitchedRules = twin.battle
	_check(battle.rng_state() == twin_battle.rng_state() and session.rng.state == twin.rng.state,
		label + ": skipping only the socket keeps the unsocketed twin exactly RNG-aligned")
	var state_a := battle.state_snapshot()
	var state_b := twin_battle.state_snapshot()
	var sockets_a: Dictionary = state_a.get("s14", {}).get("sockets", {})
	var sockets_b: Dictionary = state_b.get("s14", {}).get("sockets", {})
	state_a.get("s14", {}).erase("sockets")
	state_b.get("s14", {}).erase("sockets")
	_check(state_a == state_b,
		label + ": the twin witness battle matches the live one except its sewn sockets")
	var chosen_id := str(chosen.get("id", ""))
	var only_live_socket: bool = sockets_a.get(hero_id, {}).get(signature_id, []) == [chosen_id]
	for hero_key in sockets_a:
		for socket_key in sockets_a[hero_key]:
			if str(hero_key) == hero_id and str(socket_key) == signature_id:
				continue
			if not (sockets_a[hero_key][socket_key] as Array).is_empty():
				only_live_socket = false
	for hero_key in sockets_b:
		for socket_key in sockets_b[hero_key]:
			if not (sockets_b[hero_key][socket_key] as Array).is_empty():
				only_live_socket = false
	_check(only_live_socket,
		label + ": only the live battle carries the run-owned socket")
	var original_ranks := {}
	for rank in range(1, 5):
		var foe := battle._foe_at(rank)
		if not foe.is_empty():
			original_ranks[str(foe.id)] = rank
	var run := _matrix_cast(battle, hero_id, signature, patch, label, false)
	if run.is_empty():
		return false
	var twin_run := _matrix_cast(twin_battle, hero_id, signature, patch, label + " twin", false)
	if twin_run.is_empty():
		return false
	var base := {"results": twin_run["results"].duplicate(true), "rng": twin_battle.rng_state(),
		"round": twin_run["round"]}
	if str(patch.get("effect", "")) == "chain":
		_assert_chain(hero_id, signature, run, base, battle, label, original_ranks)
	else:
		_assert_effects(hero_id, signature, patch, run, base, battle, label)
	coverage["sides"][plan] = true
	coverage["families"][str(patch.get("effect", ""))] = true
	coverage["twins"] = int(coverage["twins"]) + 1
	_live_decision_coverage(battle, patch, run["results"], coverage, label)
	var casts := 0
	while plan == "enemy" and casts < 12 and not battle.is_over() \
			and (not bool(coverage["resisted"]) or not bool(coverage["landed_resistant"])):
		casts += 1
		var rank := _balanced_resist_rank(battle, signature, patch)
		if rank < 1 or not _to_turn(battle, hero_id):
			break
		var receipt: Dictionary = battle.use_ability(signature_id, rank)
		if not receipt.get("ok", false):
			break
		_live_decision_coverage(battle, patch, receipt.get("results", []), coverage, label)
	var document := StitchedRunSave.capture(session)
	var restored: StitchedRunSession = null
	if not document.is_empty():
		restored = StitchedRunSave.restore(document)
	_check(restored != null and restored.snapshot() == session.snapshot() and session.is_consistent(),
		label + ": the genuine journal replays the whole socketed live run exactly")
	return true


## Live consequence matrix: seeded run-opened fights witness each target side's
## sewn patch on its actual recipient, with rarity-adjusted S15 resist decisions
## and replay determinism, all through public commands on real routes.
func _live_run_matrix() -> void:
	var coverage := {"sides": {}, "families": {}, "resisted": false, "landed_resistant": false, "twins": 0}
	var plan_index := 0
	var seed_number := -1
	while seed_number < LIVE_SEED_CAP:
		seed_number += 1
		var plan: Array = LIVE_PLANS[plan_index] if plan_index < LIVE_PLANS.size() else LIVE_PLANS[0]
		if _live_run_attempt(str(plan[0]), str(plan[1]), str(plan[2]), seed_number, coverage) \
				and plan_index < LIVE_PLANS.size():
			plan_index += 1
		if plan_index >= LIVE_PLANS.size() and bool(coverage["resisted"]) \
				and bool(coverage["landed_resistant"]):
			break
	_check(coverage["sides"].has("enemy") and coverage["sides"].has("ally") and coverage["sides"].has("self"),
		"live seeded runs witness sewn patch consequences on enemy, ally and self recipients")
	_check(bool(coverage["resisted"]) and bool(coverage["landed_resistant"]),
		"live S15 foes make honest resisted and landed-on-resistant decisions under the patch rarity's pierce")
	_check(int(coverage["twins"]) >= 3,
		"every live side is proven against its aligned unsocketed twin cast")
	_check(coverage["families"].size() >= 2,
		"the live runs witness at least two distinct patch effect families")


## --------------------------------------- routed resistance witnesses ----

const ROUTED_SEED_CAP := 90
const ROUTED_HARMFUL := ["bleed", "mark", "blind", "stun", "rot"]


## The still-unwitnessed family this run's genuinely owned patches can pay
## for: guard work goes to the warden's ally-side arms, movement to the
## warden's enemy-side head command, harmful effects to the tinker's legs.
func _routed_socket_choice(session: StitchedRunSession, coverage: Dictionary) -> Dictionary:
	for item in session.ability_inventory:
		var patch: Dictionary = _patch_by_id.get(str(item.get("id", "")), {})
		if patch.is_empty():
			continue
		var effect := str(patch.get("effect", ""))
		if effect == "guard" and not bool(coverage["guard"]):
			return {"item": item, "patch": patch, "hero": "warden", "slot": "arms"}
		# A successful movement witness is not enough when its one fight
		# supplied no genuine miss: keep sourcing socketed enemy-side casts
		# from later run-earned patch inventories until both are observed.
		if effect in ["pull", "push"] and (not bool(coverage["move"]) or not bool(coverage["miss"])):
			return {"item": item, "patch": patch, "hero": "warden", "slot": "head"}
		if effect in ROUTED_HARMFUL and not bool(coverage["harmful"]):
			return {"item": item, "patch": patch, "hero": "tinker", "slot": "legs"}
	return {}


## A public miss must change nothing: no patch ids, no shift, no status entries,
## and the missed target keeps its exact HP, rank and statuses.
func _routed_miss_purity(battle: StitchedRules, results: Array, before: Dictionary, coverage: Dictionary, label: String) -> void:
	for hit in results:
		if bool(hit.get("hit", true)):
			continue
		var missed_id := str(hit.get("target", ""))
		if not before.has(missed_id):
			continue
		var struck: Dictionary = battle.get_unit(missed_id)
		var snap: Dictionary = before[missed_id]
		var pure: bool = hit.get("patches", []) == [] and not hit.has("shift") and not hit.has("death_door") \
			and hit.get("statuses", []) == [] \
			and int(struck.get("hp", -1)) == int(snap.get("hp", -1)) \
			and int(struck.get("rank", -1)) == int(snap.get("rank", -1)) \
			and struck.get("statuses", {}) == snap.get("statuses", {})
		_check(pure, label + ": a routed public miss mutates nothing on the missed " + missed_id)
		coverage["miss"] = bool(coverage["miss"]) or pure


## A dedicated public miss witness: the same socketed signature keeps casting
## lawfully at the dodgiest living foe until one honest miss shows its pure,
## spend-free receipt. Every cast is the same public command the run uses.
func _routed_miss_hunt(battle: StitchedRules, hero_id: String, signature: Dictionary, coverage: Dictionary, label: String) -> void:
	if bool(coverage["miss"]) or battle.is_over():
		return
	if str(signature.get("target_side", "")) != "enemy":
		return
	if not battle._units.has(hero_id) or bool(battle._units[hero_id].get("lost", false)):
		return
	if not _position_actor(battle, hero_id, label):
		return
	var signature_id := str(signature.get("id", ""))
	var actor: Dictionary = battle._units[hero_id]
	for attempt in 24:
		if battle.is_over() or bool(coverage["miss"]):
			return
		if not _to_turn(battle, hero_id):
			return
		var best_rank := 0
		var best_dodge := -1
		for foe in battle.get_foes():
			if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
				continue
			var foe_rank := int(foe.get("rank", 0))
			if not StitchedParts.ranks_allowed(int(signature.get("target_mask", 0)), foe_rank):
				continue
			if battle._legal_targets(actor, signature, foe_rank).is_empty():
				continue
			var dodge := int(foe.get("dodge", 0)) + int(foe.get("dodge_buff", {}).get("amount", 0))
			if dodge > best_dodge:
				best_dodge = dodge
				best_rank = foe_rank
		if best_rank < 1:
			return
		var before := {}
		for unit in _recipients(battle, signature, best_rank):
			before[str(unit.get("id", ""))] = {
				"hp": int(unit.get("hp", 0)),
				"rank": int(unit.get("rank", 0)),
				"statuses": (unit.get("statuses", {}) as Dictionary).duplicate(true),
			}
		var receipt: Dictionary = battle.use_ability(signature_id, best_rank)
		if not receipt.get("ok", false):
			continue
		_routed_miss_purity(battle, receipt.get("results", []), before, coverage, label)


## Cast the socketed signature through public turns until one confirmed hit
## carries the sewn patch; honest S15 decisions and pure misses are recorded on
## the way. Returns the first carried receipt (empty when the search ran out).
func _routed_cast(battle: StitchedRules, hero_id: String, signature: Dictionary, patch: Dictionary, decisions: Dictionary, coverage: Dictionary, label: String) -> Dictionary:
	if not _position_actor(battle, hero_id, label):
		return {}
	var signature_id := str(signature.get("id", ""))
	var patch_id := str(patch.get("id", ""))
	var enemy_side := str(signature.get("target_side", "")) == "enemy"
	for attempt in 24:
		if battle.is_over():
			return {}
		if not _to_turn(battle, hero_id):
			return {}
		var actor: Dictionary = battle._units[hero_id]
		var rank := _balanced_resist_rank(battle, signature, patch) if enemy_side else _discover_rank(battle, signature, actor)
		if rank < 1:
			return {}
		var before := {}
		for unit in _recipients(battle, signature, rank):
			before[str(unit.get("id", ""))] = {
				"hp": int(unit.get("hp", 0)),
				"rank": int(unit.get("rank", 0)),
				"statuses": (unit.get("statuses", {}) as Dictionary).duplicate(true),
			}
		var receipt: Dictionary = battle.use_ability(signature_id, rank)
		if not receipt.get("ok", false):
			continue
		var results: Array = receipt.get("results", [])
		_routed_miss_purity(battle, results, before, coverage, label)
		_live_decision_coverage(battle, patch, results, decisions, label)
		for hit in results:
			if bool(hit.get("hit", false)) and hit.get("patches", []).has(patch_id):
				return receipt
	return {}


## Enemy-side casts keep spending lawful turns until the resistant foe has
## both shrugged the sewn patch off and worn it: honest decision coverage.
func _routed_decisions(battle: StitchedRules, hero_id: String, signature: Dictionary, patch: Dictionary, decisions: Dictionary, coverage: Dictionary, label: String) -> void:
	var signature_id := str(signature.get("id", ""))
	for attempt in 24:
		if battle.is_over() or (bool(decisions["resisted"]) and bool(decisions["landed_resistant"])):
			return
		if not _to_turn(battle, hero_id):
			return
		var rank := _balanced_resist_rank(battle, signature, patch)
		if rank < 1:
			return
		var before := {}
		for unit in _recipients(battle, signature, rank):
			before[str(unit.get("id", ""))] = {
				"hp": int(unit.get("hp", 0)),
				"rank": int(unit.get("rank", 0)),
				"statuses": (unit.get("statuses", {}) as Dictionary).duplicate(true),
			}
		var receipt: Dictionary = battle.use_ability(signature_id, rank)
		if not receipt.get("ok", false):
			continue
		var results: Array = receipt.get("results", [])
		_routed_miss_purity(battle, results, before, coverage, label)
		_live_decision_coverage(battle, patch, results, decisions, label)


## The harmful ally patch's bleed must actually tick on the sewn doll's own
## turn: exactly its count in damage, then one count down.
func _routed_harmful_tick(battle: StitchedRules, carried: Dictionary, patch: Dictionary, label: String) -> bool:
	if str(patch.get("effect", "")) != "bleed":
		return true
	var target_id := ""
	for hit in carried.get("results", []):
		if bool(hit.get("hit", false)) and hit.get("patches", []).has(str(patch.get("id", ""))):
			target_id = str(hit.get("target", ""))
			break
	if target_id.is_empty():
		return false
	var doll: Dictionary = battle.get_unit(target_id)
	if doll.is_empty() or bool(doll.get("lost", false)):
		return false
	var count := int(doll.get("statuses", {}).get("bleed", 0))
	var hp_before := int(doll.get("hp", 0))
	if count <= 0 or hp_before <= 0:
		return false
	# The doll's own turn ticks the bleed even when that turn is consumed by
	# a status or an unravelled mood, so watch the bleed count itself.
	var ticked := false
	for step in 128:
		if battle.is_over():
			break
		if int(battle.get_unit(target_id).get("statuses", {}).get("bleed", 0)) < count:
			ticked = true
			break
		if not battle.pass_turn().get("ok", false):
			break
	if not ticked:
		return false
	doll = battle.get_unit(target_id)
	var settled := int(doll.get("hp", -1)) == maxi(0, hp_before - count) \
		and int(doll.get("statuses", {}).get("bleed", 0)) == count - 1
	_check(settled, label + ": the harmful ally patch's bleed ticks on its doll's own turn")
	return settled


## A blow whose effects could muddy the fray accounting or tick outside a
## receipt: bleed and rot can zero the victim at its own turn, and fray can
## tip any doll over the resolve threshold mid-drive.
func _routed_blow_dirties(ability: Dictionary) -> bool:
	var effects: Dictionary = ability.get("effects", {})
	return int(effects.get("bleed", 0)) > 0 or int(effects.get("rot", 0)) > 0 \
		or int(effects.get("fray", 0)) > 0


## How many single-target damaging blows the living foes can lawfully land at
## one rank right now.
func _routed_blow_count(battle: StitchedRules, foe: Dictionary, hero_rank: int) -> int:
	if bool(foe.get("dead", false)) or int(foe.get("hp", 0)) <= 0:
		return 0
	var blows := 0
	for ability in foe.get("abilities", []):
		if int(ability.get("dmg", [0, 0])[1]) <= 0 or bool(ability.get("multi", false)):
			continue
		if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(foe.get("rank", 0))):
			continue
		if battle._legal_targets(foe, ability, hero_rank).is_empty():
			continue
		blows += 1
	return blows


## A fully public death-door drive: every foe turn spends one lawful damaging
## blow on one victim until the third door hit tears the head. No surgery, so
## the session stays consistent and the journal stays genuine. The fallen
## doll's satchel and every survivor's candle-scaled party fray are checked
## against the death door's authored rules.
func _routed_lost_witness(battle: StitchedRules, coverage: Dictionary, label: String) -> void:
	if battle.is_over():
		return
	var victim_id := ""
	var best_blows := -1
	for hero in battle.get_heroes():
		if bool(hero.get("lost", false)) or int(hero.get("hp", 0)) <= 0:
			continue
		var blows := 0
		for foe in battle.get_foes():
			blows += _routed_blow_count(battle, foe, int(hero.get("rank", 0)))
		if blows > best_blows:
			best_blows = blows
			victim_id = str(hero.get("id", ""))
	if victim_id.is_empty() or best_blows <= 0:
		return
	var worn: Array = []
	var victim: Dictionary = battle._units[victim_id]
	for slot in StitchedParts.SLOTS:
		if victim.get("parts", {}).has(slot):
			worn.append(str(victim["parts"][slot].get("id", "")))
	var fray_before := {}
	var resolve_empty := true
	for hero in battle.get_heroes():
		if bool(hero.get("lost", false)):
			continue
		fray_before[str(hero.get("id", ""))] = {"fray": int(hero.get("fray", 0)), "resolve": str(hero.get("resolve", ""))}
		resolve_empty = resolve_empty and str(hero.get("resolve", "")).is_empty()
	var door_frays: Array = []
	var dirty := false
	var lost_hit := {}
	var blows := 0
	var steps := 0
	while blows < 60 and steps < 600 and not battle.is_over():
		steps += 1
		var actor: Dictionary = battle.get_unit(battle.current_actor_id())
		if actor.is_empty():
			return
		if str(actor.get("side", "")) != "foe":
			if not battle.pass_turn().get("ok", false):
				return
			continue
		if bool(battle.get_unit(victim_id).get("lost", false)):
			return
		var victim_rank := int(battle._units[victim_id]["rank"])
		var blow := {}
		for ability in actor.get("abilities", []):
			if int(ability.get("dmg", [0, 0])[1]) <= 0 or bool(ability.get("multi", false)):
				continue
			if _routed_blow_dirties(ability):
				continue
			if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))):
				continue
			if battle._legal_targets(actor, ability, victim_rank).is_empty():
				continue
			blow = ability
			break
		if blow.is_empty():
			for ability in actor.get("abilities", []):
				if int(ability.get("dmg", [0, 0])[1]) <= 0 or bool(ability.get("multi", false)):
					continue
				if _routed_blow_dirties(ability):
					dirty = true
				if not StitchedParts.ranks_allowed(int(ability.get("launch_mask", 0)), int(actor.get("rank", 0))):
					continue
				if battle._legal_targets(actor, ability, victim_rank).is_empty():
					continue
				blow = ability
				break
		if blow.is_empty():
			if not battle.pass_turn().get("ok", false):
				return
			continue
		var covered := {}
		for hero_id in fray_before:
			covered[hero_id] = battle.eyes_covered(hero_id)
		var shielded := battle.candle_shielded()
		var candle_at_blow := battle.candle()
		var receipt: Dictionary = battle.use_foe_ability(str(blow.get("id", "")), victim_rank)
		if not receipt.get("ok", false):
			if not battle.pass_turn().get("ok", false):
				return
			continue
		blows += 1
		for hit in receipt.get("results", []):
			if not hit.has("death_door") or str(hit.get("target", "")) != victim_id:
				continue
			var door: Dictionary = hit.get("death_door", {})
			door_frays.append({
				"amount": 25 if bool(door.get("lost", false)) else 8,
				"candle": candle_at_blow,
				"covered": covered.duplicate(),
				"shielded": shielded,
				})
			if bool(hit.get("lost", false)):
				lost_hit = hit
		if not lost_hit.is_empty():
			break
	if lost_hit.is_empty():
		return
	var fallen: Dictionary = battle.get_unit(victim_id)
	var ok: bool = bool(fallen.get("lost", false)) and int(fallen.get("hp", -1)) == 0 \
		and fallen.get("statuses", {}).is_empty() and fallen.get("parts", {}).is_empty()
	_check(ok, label + ": the publicly lost doll leaves combat at zero HP, status-free and empty-handed")
	var door: Dictionary = lost_hit.get("death_door", {})
	var head := bool(lost_hit.get("lost", false)) and str(door.get("tear", {}).get("slot", "")) == "head" \
		and (int(door.get("hits", 0)) >= 3 or int(door.get("roll", 101)) <= (10 if int(door.get("hits", 0)) == 1 else 45))
	_check(head, label + ": the terminal blow tears the head under the authored death-door odds")
	ok = ok and head
	var stored: Array = lost_hit.get("satchel", {}).get("stored", [])
	_check(stored == worn, label + ": the lost doll's worn parts fill the satchel in stable slot order")
	ok = ok and stored == worn
	for hero_id in fray_before:
		if hero_id == victim_id:
			continue
		var survivor: Dictionary = battle.get_unit(hero_id)
		var expected := 0
		for event in door_frays:
			if bool(event.get("covered", {}).get(hero_id, false)):
				continue
			expected += int(event.get("amount", 0)) if bool(event.get("shielded", false)) \
				else StitchedS1BEffects.fray_gain(int(event.get("amount", 0)), int(event.get("candle", 0)))
		var before_fray := int(fray_before[hero_id].get("fray", 0))
		var after_fray := int(survivor.get("fray", 0))
		if resolve_empty and not dirty and before_fray + expected < StitchedRules.FRAY_RESOLVE:
			_check(after_fray == before_fray + expected,
				label + ": survivor " + hero_id + " gains exactly the candle-scaled party fray of every door hit")
			ok = ok and after_fray == before_fray + expected
		else:
			var moved := after_fray > before_fray or not str(survivor.get("resolve", "")).is_empty() \
				or after_fray >= 150 or expected == 0
			_check(moved, label + ": survivor " + hero_id + " answers the fallen doll with real party fray")
			ok = ok and moved
	coverage["lost"] = ok


## One routed resistance attempt: two real victories pay a genuine socket,
## the witness fight mounts the actual S15-transformed foes, the socketed
## signature casts through public turns, and the whole route replays exactly.
func _routed_attempt(seed_number: int, coverage: Dictionary) -> void:
	var session := StitchedRunSession.start(seed_number)
	if session == null:
		return
	for step in 2:
		var fight := _travel_to(session, ["Fight"])
		if fight.is_empty() or session.phase != "battle":
			return
		if not _play_to_victory(session) or not session.settle_battle(session.battle):
			return
	var choice := _routed_socket_choice(session, coverage)
	if choice.is_empty() or session.scraps < StitchedRunSession.SEWING_COST:
		return
	var item: Dictionary = choice.get("item", {})
	var patch: Dictionary = choice.get("patch", {})
	var hero_id := str(choice.get("hero", ""))
	var signature: Dictionary = StitchedS14Abilities.kits().get(hero_id, {}).get(str(choice.get("slot", "")), {})
	if item.is_empty() or patch.is_empty() or signature.is_empty():
		return
	var circle := _travel_to(session, ["SewingCircle"])
	if circle.is_empty() or session.phase != "visit":
		return
	var label := "routed " + str(patch.get("effect", "")) + " seed " + str(seed_number)
	if not session.socket_ability(int(item.get("uid", 0)), hero_id, str(signature.get("id", "")), 0, session.snapshot()):
		return
	if not session.choose_visit("leave", [], session.snapshot()) or session.phase != "map":
		return
	var witness := _travel_to(session, ["Fight", "Elite"])
	if witness.is_empty() or session.phase != "battle" or session.battle == null:
		return
	var battle: StitchedRules = session.battle
	if not battle._units.has(hero_id) or bool(battle._units[hero_id].get("lost", false)):
		return
	var catalog := StitchedEnemyCatalog.load_catalog()
	if bool(catalog.get("ok", false)):
		var canonical := true
		for live_foe in battle.get_foes():
			var authored: Dictionary = StitchedEnemyCatalog.foe_for(catalog, str(live_foe.get("id", "")))
			if authored.is_empty():
				canonical = false
				continue
			StitchedDeeperSeams.apply(authored, session.map.get_current_floor(), str(session.map.get_node(witness).type))
			var live_resist: Dictionary = live_foe.get("resist", {})
			var auth_resist: Dictionary = authored.get("resist", {})
			canonical = canonical and live_resist == auth_resist and not auth_resist.is_empty()
		_check(canonical and battle.get_foes().size() >= 2,
			label + ": the witness fight mounts its actual floor- and kind-transformed S15 foes")
	var decisions := {"resisted": false, "landed_resistant": false}
	var carried := _routed_cast(battle, hero_id, signature, patch, decisions, coverage, label)
	if carried.is_empty():
		return
	_assert_live_patch(battle, carried, patch, label)
	var effect := str(patch.get("effect", ""))
	# Probe the routed foe while its rank is still reachable; repeated
	# push/pull casts and the public LOST drive can exhaust those targets.
	if not bool(coverage["miss"]):
		_routed_miss_hunt(battle, hero_id, signature, coverage, label)
	if str(signature.get("target_side", "")) == "enemy":
		_routed_decisions(battle, hero_id, signature, patch, decisions, coverage, label)
	if effect == "guard" and hero_id == "warden":
		coverage["guard"] = true
	elif effect in ["pull", "push"]:
		coverage["move"] = bool(decisions["resisted"]) and bool(decisions["landed_resistant"])
	elif effect in ROUTED_HARMFUL:
		coverage["harmful"] = _routed_harmful_tick(battle, carried, patch, label)
	# Observe an honest miss while the routed fight still has living targets:
	# the public LOST drive below can legitimately end the battle.
	if not bool(coverage["miss"]):
		_routed_miss_hunt(battle, hero_id, signature, coverage, label)
	if effect in ["guard", "pull", "push"] and not bool(coverage["lost"]):
		_routed_lost_witness(battle, coverage, label)
	var document := StitchedRunSave.capture(session)
	if document.is_empty():
		return
	var restored: StitchedRunSession = StitchedRunSave.restore(document)
	var replayed := restored != null and restored.snapshot() == session.snapshot() and session.is_consistent()
	_check(replayed, label + ": the genuine journal replays the routed resistance run exactly")
	if replayed:
		coverage["replay"] = true


## Routed resistance coverage: seeded real runs prove the socketed families
## through public fights only - guard on the casting warden, movement with
## honest S15 resist decisions, harmful patches ticking on real allies, pure
## misses, a fully public LOST with its fray and satchel receipts, and exact
## journal replay.
func _routed_resistance_witnesses() -> void:
	var coverage := {"guard": false, "move": false, "harmful": false, "miss": false, "lost": false, "replay": false}
	for seed_number in range(ROUTED_SEED_CAP):
		var complete := true
		for key in coverage:
			complete = complete and bool(coverage[key])
		if complete:
			break
		_routed_attempt(seed_number, coverage)
	_check(bool(coverage["guard"]),
		"a routed run witnesses its sewn guard patch land on the casting warden")
	_check(bool(coverage["move"]),
		"a routed run witnesses its sewn movement patch with honest resisted and landed S15 decisions")
	_check(bool(coverage["harmful"]),
		"a routed run witnesses its sewn harmful patch bleed a real ally and tick on its turn")
	_check(bool(coverage["miss"]),
		"a routed public miss spends nothing and mutates nothing")
	_check(bool(coverage["lost"]),
		"a fully public death-door drive loses a hero with authored satchel and party-fray receipts")
	_check(bool(coverage["replay"]),
		"a routed resistance run replays exactly from its genuine journal")
