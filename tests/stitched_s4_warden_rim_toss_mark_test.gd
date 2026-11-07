extends SceneTree
## Warden Rim Toss: authentic equipped Mark survives one foe turn, allowing an
## equipped tier-II Rivet Pummel follow-up. All combat calls use the shipped
## StitchedParts catalog and StitchedRules.create/use_part/turn advancement.

const WARDEN_PATH := "res://data/parts/warden_parts.json"
const PREVIEW_PATH := "res://data/stitched/s2_preview.json"
const RIM := "warden_legs_rim_toss"
const PUMMEL := "warden_arms_rivet_pummel"
const WARDEN := "warden"
const FOE := "fray_scavenger"
const OTHER_FOES := ["scissor_crab", "moth_scribe"]
const SEED_LIMIT := 220
const RIM_DMG := [[5, 8], [6, 10], [8, 12]]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	var catalog := StitchedParts.load_catalog(WARDEN_PATH)
	_check(bool(catalog.get("ok", false)), "AC1: real Warden catalog loads")
	if bool(catalog.get("ok", false)):
		_test_catalog(catalog)
		_test_landed_tiers(catalog)
		_test_live_chain(catalog)
		_test_miss(catalog)
		_test_refusals(catalog)
	for message in failures:
		printerr(message)
	print("stitched_s4_warden_rim_toss_mark_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _read_preview() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW_PATH))
	if parsed is Dictionary:
		return parsed
	return {}


func _battle(catalog: Dictionary, seed_value: int, tier: int = 2,
		torn: bool = false, zero_prot: bool = false, warden_rank: int = 1) -> StitchedRules:
	var config := _read_preview()
	if config.is_empty():
		return null
	config["parts"].append_array(catalog["parts"])
	config["seed"] = seed_value
	var warden: Dictionary = config["heroes"][0]
	warden["parts"]["legs"] = {"id": RIM, "tier": tier, "torn": torn}
	warden["parts"]["arms"] = {"id": PUMMEL, "tier": 2, "torn": false}
	if warden_rank == 3:
		config["heroes"].remove_at(0)
		config["heroes"].insert(2, warden)
	if zero_prot:
		# One matched test-only value; the two foe copies keep everything else.
		config["foes"][0]["prot"] = 0
	var created := StitchedRules.create(config)
	if not bool(created.get("ok", false)):
		return null
	return created["battle"]


func _to(b: StitchedRules, id: String, limit: int = 32) -> bool:
	for step in range(limit):
		if b.is_over():
			return false
		if b.current_actor_id() == id:
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _to_foe_turn(b: StitchedRules) -> bool:
	for step in range(32):
		if b.is_over():
			return false
		if b.current_side() == "foe":
			return true
		if not bool(b.pass_turn().get("ok", false)):
			return false
	return false


func _result(receipt: Dictionary) -> Dictionary:
	var results: Array = receipt.get("results", [])
	if results.size() != 1 or not results[0] is Dictionary:
		return {}
	return results[0]


func _equipped(b: StitchedRules, tier: int) -> bool:
	var w := b.get_unit(WARDEN)
	return not w.is_empty() and int(w.get("rank", 0)) <= 2 \
		and int(w.get("hp", 0)) > 0 and b.get_heroes().size() == 4 \
		and b.get_foes().size() == 3 \
		and str(w["parts"]["legs"].get("id", "")) == RIM \
		and int(w["parts"]["legs"].get("tier", 0)) == tier \
		and not bool(w["parts"]["legs"]["torn"]) \
		and str(w["parts"]["arms"].get("id", "")) == PUMMEL \
		and int(w["parts"]["arms"].get("tier", 0)) == 2 \
		and not bool(w["parts"]["arms"]["torn"])


func _test_catalog(catalog: Dictionary) -> void:
	var by_id: Dictionary = catalog.get("by_id", {})
	_check(by_id.has(RIM) and by_id.has(PUMMEL), "AC1: both real Warden parts exist")
	if not by_id.has(RIM) or not by_id.has(PUMMEL):
		return
	var part: Dictionary = by_id[RIM]
	_check(str(part.get("name", "")) == "Rim Toss" and str(part.get("slot", "")) == "legs" \
		and str(part.get("owner", "")) == WARDEN \
		and part.get("stat", {}) == {"speed": 1, "dodge": 2},
		"AC1: Rim Toss retains identity, slot, owner and stats")
	var wording := str(part.get("text", ""))
	_check(wording.contains("Mark 2") and not wording.to_lower().contains("block") \
		and not wording.to_lower().contains("card"),
		"AC1: tooltip describes Mark 2 without retired card/Block terms")
	for tier in [1, 2, 3]:
		var ability := StitchedParts.ability_at_tier(part, tier)
		var label := "AC1: tier %d" % tier
		_check(bool(StitchedParts.validate_ability(ability).get("ok", false)),
			label + " is a valid ability")
		_check(ability.get("effects", {}) == {"mark": 2},
			label + " applies exactly Mark 2")
		_check(ability.get("dmg", []) == RIM_DMG[tier - 1] \
			and int(ability.get("acc", -1)) == 90 \
			and int(ability.get("crit", -1)) == 0,
			label + " preserves authored damage, ACC and crit")
		_check(ability.get("launch", []) == [1, 2] \
			and ability.get("target", []) == [1, 2, 3] \
			and int(ability.get("launch_mask", 0)) == StitchedParts.rank_mask([1, 2]) \
			and int(ability.get("target_mask", 0)) == StitchedParts.rank_mask([1, 2, 3]),
			label + " preserves launch and target ranks/masks")
		_check(str(ability.get("id", "")) == "legs_rim_toss_move" \
			and str(ability.get("name", "")) == "Rim Toss" \
			and str(ability.get("kind", "")) == "ranged" \
			and str(ability.get("target_side", "")) == "enemy" \
			and not bool(ability.get("multi", true)) \
			and int(ability.get("self_move", -1)) == 0 \
			and str(ability.get("move", "")) == "attack2",
			label + " preserves other authored ability fields")
		_check(StitchedParts.stat_at_tier(part, tier) == {"speed": 1, "dodge": 2},
			label + " preserves leg stats")
	var arms := StitchedParts.ability_at_tier(by_id[PUMMEL], 2)
	_check(int(arms.get("mark_damage", 0)) == 4 \
		and arms.get("effects", {}) == {"tangled": 2} \
		and arms.get("dmg", []) == [6, 9],
		"AC2: tier-II Rivet Pummel retains +4 Mark bonus and its normal effects")


## Landed hit at each tier, using a real worn part and actual RNG, never a
## manually planted Mark. Skip seeds whose post-action turn entry already ticked
## the chosen foe; they cannot evidence the immediate Mark-2 state.
func _tier_hit(catalog: Dictionary, tier: int) -> Dictionary:
	for seed_value in range(1, SEED_LIMIT):
		var b := _battle(catalog, seed_value, tier)
		if b == null or not _to(b, WARDEN) or not _equipped(b, tier):
			continue
		var before := b.get_unit(FOE)
		if int(before.get("hp", 0)) <= 0 or int(before.get("rank", 0)) != 1:
			continue
		var receipt := b.use_part(RIM, 1)
		var hit := _result(receipt)
		if not bool(receipt.get("ok", false)) or not bool(hit.get("hit", false)):
			continue
		if b.current_actor_id() == FOE:
			continue
		return {"battle": b, "before": before, "receipt": receipt,
			"hit": hit, "seed": seed_value}
	return {}


func _test_landed_tiers(catalog: Dictionary) -> void:
	for tier in [1, 2, 3]:
		var witness := _tier_hit(catalog, tier)
		var label := "AC1: genuine tier-%d Rim Toss" % tier
		_check(not witness.is_empty(), label + " has a seeded landed witness")
		if witness.is_empty():
			continue
		var b: StitchedRules = witness["battle"]
		var hit: Dictionary = witness["hit"]
		var before: Dictionary = witness["before"]
		var victim := b.get_unit(FOE)
		_check(_equipped(b, tier), label + " is equipped on a real 4v3 Warden")
		_check(str(witness["receipt"].get("part", "")) == RIM \
			and str(witness["receipt"].get("ability", "")) == "legs_rim_toss_move" \
			and str(hit.get("target", "")) == FOE \
			and int(hit.get("target_rank", 0)) == 1,
			label + " emits the expected part/ability/target receipt")
		_check(int(hit.get("roll", 101)) <= int(hit.get("hit_chance", 0)),
			label + " is a natural hit from seeded RNG")
		var mark_receipt := {}
		for entry in hit.get("statuses", []):
			if str(entry.get("status", "")) == "mark":
				mark_receipt = entry
		_check(int(mark_receipt.get("duration", 0)) == 2 \
			and int(victim["statuses"].get("mark", 0)) == 2,
			label + " leaves exactly Mark 2 in receipt and authoritative target")
		_check(int(victim["hp"]) == int(before["hp"]) - int(hit.get("damage", 0)) \
			and int(hit.get("damage", 0)) > 0,
			label + " deals real direct damage")


## Build two identical seeded real fights. Both must land the actual Rim Toss;
## only immediately before the Pummel is Mark erased from the control.
func _chain(catalog: Dictionary, seed_value: int) -> Dictionary:
	var marked := _battle(catalog, seed_value, 2, false, true)
	var control := _battle(catalog, seed_value, 2, false, true)
	if marked == null or control == null \
		or not _to(marked, WARDEN) or not _to(control, WARDEN) \
		or not _equipped(marked, 2) or not _equipped(control, 2):
		return {}
	var before := marked.get_unit(FOE)
	if int(before.get("hp", 0)) != 30 or int(before.get("prot", -1)) != 0 \
		or int(before.get("rank", 0)) != 1 or before != control.get_unit(FOE):
		return {}
	var prior_rng := marked.rng_state()
	if prior_rng != control.rng_state():
		return {}
	var toss := marked.use_part(RIM, 1)
	var twin_toss := control.use_part(RIM, 1)
	var landed := _result(toss)
	if toss != twin_toss or not bool(landed.get("hit", false)) \
		or marked.current_actor_id() == FOE:
		return {}
	var after_toss := marked.get_unit(FOE)
	if int(after_toss["statuses"].get("mark", 0)) != 2 \
		or after_toss != control.get_unit(FOE):
		return {}
	if not _to(marked, FOE) or not _to(control, FOE):
		return {}
	var first_foe := marked.get_unit(FOE)
	if int(first_foe["statuses"].get("mark", 0)) != 1 \
		or first_foe != control.get_unit(FOE):
		return {}
	var first_foe_rng := marked.rng_state()
	if first_foe_rng != control.rng_state():
		return {}
	var first_pass := marked.pass_turn()
	var twin_first_pass := control.pass_turn()
	if not bool(first_pass.get("ok", false)) or first_pass != twin_first_pass \
		or not _to(marked, WARDEN) or not _to(control, WARDEN):
		return {}
	var pre_pummel := marked.get_unit(FOE)
	if int(pre_pummel["statuses"].get("mark", 0)) != 1 \
		or pre_pummel != control.get_unit(FOE) \
		or int(pre_pummel["hp"]) <= 17 \
		or marked.rng_state() != control.rng_state():
		return {}
	var pummel_rng := marked.rng_state()
	control._units[FOE]["statuses"].erase("mark")
	var cleared := control.get_unit(FOE)
	var pummel := marked.use_part(PUMMEL, 1)
	var plain := control.use_part(PUMMEL, 1)
	var boosted := _result(pummel)
	var normal := _result(plain)
	if not bool(boosted.get("hit", false)) or not bool(normal.get("hit", false)):
		return {}
	if int(marked.get_unit(FOE)["statuses"].get("mark", 0)) != 1:
		return {}
	var after_pummel := marked.state_snapshot()
	if not _to(marked, FOE):
		return {}
	return {
		"seed": seed_value, "prior_rng": prior_rng, "first_foe_rng": first_foe_rng,
		"pummel_rng": pummel_rng, "before": before,
		"after_toss": after_toss, "first_foe": first_foe,
		"pre_pummel": pre_pummel, "cleared": cleared,
		"toss": toss, "first_pass": first_pass,
		"pummel": pummel, "plain": plain,
		"after_pummel": after_pummel,
		"boosted": boosted, "normal": normal,
		"after_second_foe": marked.get_unit(FOE),
		"final_snapshot": marked.state_snapshot(), "final_rng": marked.rng_state(),
		"control_snapshot": control.state_snapshot(), "control_rng": control.rng_state(),
	}


func _test_live_chain(catalog: Dictionary) -> void:
	var found := {}
	for seed_value in range(1, SEED_LIMIT):
		var trial := _chain(catalog, seed_value)
		if not trial.is_empty():
			found = trial
			break
	_check(not found.is_empty(),
		"AC2: an authentic hit/first foe turn/next legal tier-II pummel chain exists")
	if found.is_empty():
		return
	_check(int(found["after_toss"]["statuses"].get("mark", 0)) == 2,
		"AC2: a real hit leaves Mark 2 before the foe starts its turn")
	_check(int(found["first_foe"]["statuses"].get("mark", 0)) == 1 \
		and int(found["pre_pummel"]["statuses"].get("mark", 0)) == 1,
		"AC2: first natural foe turn ticks to Mark 1; Mark survives to Pummel")
	_check(int(found["cleared"]["statuses"].get("mark", 0)) == 0,
		"AC2: same-seed control has only Mark removed immediately before Pummel")
	var boosted: Dictionary = found["boosted"]
	var normal: Dictionary = found["normal"]
	_check(bool(found["pummel"].get("ok", false)) \
		and bool(found["plain"].get("ok", false)) \
		and str(found["pummel"].get("part", "")) == PUMMEL \
		and str(boosted.get("target", "")) == FOE \
		and str(normal.get("target", "")) == FOE,
		"AC2: both real tier-II Rivet Pummels execute on the same living foe")
	_check(bool(boosted.get("hit", false)) and bool(normal.get("hit", false)) \
		and int(boosted.get("roll", -1)) == int(normal.get("roll", -2)) \
		and bool(boosted.get("crit", false)) == bool(normal.get("crit", true)),
		"AC2: paired pummels share seeded hit and critical rolls")
	_check(int(boosted.get("damage", 0)) - int(normal.get("damage", 0)) == 4,
		"AC2: authentic Mark grants exactly +4 direct damage vs cleared same-seed control")
	_check(int(found["after_second_foe"]["statuses"].get("mark", 0)) == 0,
		"AC2: without refresh Mark expires on the foe's second natural turn start")
	for other_id in OTHER_FOES:
		var original := _battle(catalog, int(found["seed"]), 2, false, true)
		if original != null:
			_check(original.get_unit(other_id).get("prot", -1) \
				== _battle(catalog, int(found["seed"]), 2).get_unit(other_id).get("prot", -2),
				"AC2: other foe " + other_id + " retains authored PROT")
	var replay := _chain(catalog, int(found["seed"]))
	_check(not replay.is_empty() and replay == found,
		"AC3: equal-seed full chain replays receipts, natural turns, snapshots and RNG")


func _test_miss(catalog: Dictionary) -> void:
	var found := false
	for seed_value in range(1, SEED_LIMIT):
		var b := _battle(catalog, seed_value, 2)
		if b == null or not _to(b, WARDEN) or not _equipped(b, 2):
			continue
		var before := b.get_unit(FOE)
		if int(before.get("hp", 0)) <= 0:
			continue
		var receipt := b.use_part(RIM, 1)
		var miss := _result(receipt)
		if not bool(receipt.get("ok", false)) or miss.is_empty() \
			or bool(miss.get("hit", true)):
			continue
		_check(int(miss.get("roll", 0)) > int(miss.get("hit_chance", 100)) \
			and int(miss.get("damage", -1)) == 0 \
			and miss.get("statuses", []).is_empty(),
			"AC3: genuine missed Rim Toss records no damage or Mark")
		_check(int(b.get_unit(FOE)["hp"]) == int(before["hp"]) \
			and int(b.get_unit(FOE)["statuses"].get("mark", 0)) == 0,
			"AC3: missed Rim Toss leaves target HP and Mark untouched")
		found = true
		break
	_check(found, "AC3: bounded seeds find a real Rim Toss miss")


func _test_refusals(catalog: Dictionary) -> void:
	var b := _battle(catalog, 1, 2)
	_check(b != null and _to(b, WARDEN), "AC3: refusal witness reaches equipped Warden")
	if b == null or b.current_actor_id() != WARDEN:
		return
	var before := b.state_snapshot()
	var rng := b.rng_state()
	var bad_rank := b.use_part(RIM, 4)
	var out_of_range := b.use_part(RIM, 0)
	var unequipped := b.use_part("warden_legs_shield_toss", 1)
	_check(not bool(bad_rank.get("ok", true)) \
		and not bool(out_of_range.get("ok", true)) \
		and not bool(unequipped.get("ok", true)) \
		and before == b.state_snapshot() and rng == b.rng_state() \
		and b.current_actor_id() == WARDEN,
		"AC3: illegal rank and unequipped actions spend neither turn, state nor RNG")
	var torn := _battle(catalog, 1, 2, true)
	if torn != null and _to(torn, WARDEN):
		var torn_before := torn.state_snapshot()
		var torn_rng := torn.rng_state()
		_check(bool(torn.get_unit(WARDEN)["parts"]["legs"]["torn"]) \
			and not bool(torn.use_part(RIM, 1).get("ok", true)) \
			and torn.state_snapshot() == torn_before and torn.rng_state() == torn_rng,
			"AC3: torn genuine Rim Toss refuses without spending state or RNG")
	else:
		_check(false, "AC3: torn witness reaches Warden")
	var off := _battle(catalog, 1, 2)
	if off != null and _to_foe_turn(off):
		var off_before := off.state_snapshot()
		var off_rng := off.rng_state()
		var off_actor := off.current_actor_id()
		_check(not bool(off.use_part(RIM, 1).get("ok", true)) \
			and off_before == off.state_snapshot() and off_rng == off.rng_state() \
			and off.current_actor_id() == off_actor,
			"AC3: off-turn Rim Toss refuses without changing turn or RNG")
	else:
		_check(false, "AC3: off-turn witness reaches foe turn")
	var rank_three := _battle(catalog, 1, 2, false, false, 3)
	if rank_three != null and _to(rank_three, WARDEN):
		var rank_before := rank_three.state_snapshot()
		var rank_rng := rank_three.rng_state()
		_check(int(rank_three.get_unit(WARDEN)["rank"]) == 3 \
			and not bool(rank_three.use_part(RIM, 1).get("ok", true)) \
			and rank_before == rank_three.state_snapshot() \
			and rank_rng == rank_three.rng_state(),
			"AC3: illegal hero launch rank 3 spends nothing")
	else:
		_check(false, "AC3: wrong-launch witness reaches Warden")
