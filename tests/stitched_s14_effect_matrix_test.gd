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
## run-owned socket replayed from its genuine journal.

const SEED := 55
const ROSTER_B := ["rag_duelist", "scarecrow", "yarn_ranger", "button_golem"]
const CLEARABLE := ["bleed", "weak", "exposed", "tangled", "blind", "mark", "stun"]
const REQUIRED_PATCHES := [
	"cotton_red_lint", "cotton_guard_stitch", "cotton_mending_fuzz",
	"wool_mark_thread", "wool_hook_stitch", "wool_heel_knot", "wool_steady_hem",
	"silk_moth_veil", "silk_pin_prick", "silk_life_loop", "silk_clean_seam",
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
		if not _assert_primary_identity(rp, rb, label):
			return
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
	if not witnessed:
		_check(false, label + ": at least one confirmed hit receives the patch")
	# Stun can skip the next target turn and trigger a new initiative round
	# earlier than the unsocketed twin; its primary hit/crit/damage rolls above
	# remain identical, but the post-cast round RNG need not match.
	if effect != "stun" or int(run["round"]) == int(base["round"]):
		_check(battle.rng_state() == int(base["rng"]),
			label + ": the socketed cast draws exactly the baseline's RNG")


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
				_check(int(successor.statuses.get(status_key, 0)) >= authored,
					label + ": the chained hit delivers the authored " + status_key + " to its foe")
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
	for illegal_rank in [0, 4]:
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
