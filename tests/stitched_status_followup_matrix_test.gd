extends SceneTree
## Cross-ability, cross-side status clock contract. All effects arise from the
## canonical part / enemy loaders and StitchedRules' public combat commands.
## Seed searches select natural hit/order witnesses; they never plant statuses.

const PREVIEW := "res://data/stitched/s2_preview.json"
const SEAMSTRESS := "res://data/parts/seamstress_parts.json"
const DUELIST := "res://data/parts/rag_duelist_parts.json"
const SEED_MAX := 220
const WALK_LIMIT := 100
const ROWS := [
	{"name": "scarlet weak", "side": "hero", "part": "seamstress_scarlet_knot_hat",
		"ability": "scarlet_knot", "foes": ["spool_hexer", "ragling"],
		"target_rank": 1, "status": "weak", "duration": 2, "follow": "weak"},
	{"name": "feather exposed", "side": "hero", "part": "rag_duelist_head_feather_feint",
		"ability": "rag_duelist_head_feather_feint_move", "foes": ["spool_hexer", "ragling"],
		"target_rank": 1, "status": "exposed", "duration": 2, "follow": "incoming"},
	{"name": "bobbin mark", "side": "hero", "part": "seamstress_bobbin_snag_spools",
		"ability": "bobbin_snag", "foes": ["spool_hexer", "ragling"],
		"target_rank": 1, "status": "mark", "duration": 2, "follow": "incoming"},
	{"name": "bobbin tangled", "side": "hero", "part": "seamstress_bobbin_snag_spools",
		"ability": "bobbin_snag", "foes": ["spool_hexer", "ragling"],
		"target_rank": 1, "status": "tangled", "duration": 2, "follow": "incoming"},
	{"name": "needle bleed", "side": "hero", "part": "seamstress_thread_prick_needle",
		"ability": "thread_prick", "foes": ["spool_hexer", "ragling"],
		"target_rank": 1, "status": "bleed", "duration": 2, "follow": "bleed"},
	{"name": "leech weak", "side": "foe", "caster": "spool_leech",
		"ability": "drain_thread", "foes": ["spool_leech", "ragling"],
		"target_rank": 1, "status": "weak", "duration": 2, "follow": "weak"},
	{"name": "hexer exposed", "side": "foe", "caster": "spool_hexer",
		"ability": "spool_curse", "foes": ["spool_hexer", "zipper_hauler"],
		"target_rank": 1, "status": "exposed", "duration": 2, "follow": "incoming"},
	{"name": "hexer mark", "side": "foe", "caster": "spool_hexer",
		"ability": "thread_tag", "foes": ["spool_hexer", "spool_leech"],
		"target_rank": 2, "status": "mark", "duration": 3, "follow": "incoming"},
	{"name": "spindle tangled", "side": "foe", "caster": "spindle_ram",
		"ability": "yarn_hurl", "foes": ["spindle_ram", "ragling"],
		"target_rank": 1, "status": "tangled", "duration": 2, "follow": "move"},
	{"name": "bailiff bleed", "side": "foe", "caster": "scissor_bailiff",
		"ability": "bailiff_snip", "foes": ["scissor_bailiff", "ragling"],
		"target_rank": 1, "status": "bleed", "duration": 2, "follow": "bleed"},
]

var checks := 0
var failures: Array[String] = []
var _preview: Dictionary = {}
var _catalog: Dictionary = {}
var _parts: Array = []
var _by_id: Dictionary = {}


func _initialize() -> void:
	_preview = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	_catalog = StitchedEnemyCatalog.load_catalog()
	_check(not _preview.is_empty() and bool(_catalog.get("ok", false)),
		"canonical preview and enemy catalog load")
	if _preview.is_empty() or not bool(_catalog.get("ok", false)):
		_finish()
		return
	_parts = _preview["parts"].duplicate(true)
	_parts.append_array(_catalog["parts"].duplicate(true))
	for path in [SEAMSTRESS, DUELIST]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(parsed is Dictionary and parsed.get("parts", []) is Array,
			"canonical wearable catalog loads: " + path)
		if parsed is Dictionary:
			_parts.append_array(parsed.get("parts", []).duplicate(true))
	var validated := StitchedParts.build_catalog(_parts)
	_check(bool(validated.get("ok", false)), "all authentic parts normalize with rank masks")
	if not bool(validated.get("ok", false)):
		_finish()
		return
	_parts = validated["parts"]
	_by_id = validated["by_id"]
	for row in ROWS:
		_test_row(row)
	_test_hunt_and_ordinary_mark()
	_test_miss_and_rank_refusals()
	_test_dead_target()
	_finish()


func _check(condition: bool, note: String) -> void:
	checks += 1
	if not condition:
		failures.append(note)


func _finish() -> void:
	for message in failures:
		printerr(message)
	print("stitched_status_followup_matrix_test: ",
		"PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func _battle(seed_value: int, foes: Array, part_id: String = "") -> StitchedRules:
	var heroes: Array = _preview["heroes"].duplicate(true)
	if not part_id.is_empty():
		var part: Dictionary = _by_id.get(part_id, {})
		if part.is_empty():
			return null
		heroes[1]["parts"][str(part["slot"])] = part_id
	# An authentic marked-strike second ability, available on a distinct hero.
	heroes[3]["parts"]["arms"] = "seamstress_needle_rain_needle"
	var enemy_defs: Array = []
	for enemy_id in foes:
		var foe := StitchedEnemyCatalog.foe_for(_catalog, str(enemy_id))
		if foe.is_empty():
			return null
		enemy_defs.append(foe)
	var built := StitchedRules.create({
		"mode": "stitched", "seed": seed_value, "candle": 100,
		"heroes": heroes, "foes": enemy_defs, "parts": _parts,
	})
	return built["battle"] if bool(built.get("ok", false)) else null


func _id_at(battle: StitchedRules, side: String, rank: int) -> String:
	var units := battle.get_heroes() if side == "hero" else battle.get_foes()
	for unit in units:
		if int(unit["rank"]) == rank and not bool(unit["lost"]) and not bool(unit["dead"]):
			return str(unit["id"])
	return ""


func _ability(battle: StitchedRules, actor_id: String, ability_id: String) -> Dictionary:
	var actor := battle.get_unit(actor_id)
	if actor.is_empty():
		return {}
	if str(actor["side"]) == "foe":
		for entry in actor["abilities"]:
			if str(entry["id"]) == ability_id:
				return entry
		return {}
	for slot in actor["parts"]:
		var worn: Dictionary = actor["parts"][slot]
		var part: Dictionary = _by_id.get(str(worn["id"]), {})
		if part.is_empty() or bool(worn["torn"]):
			continue
		var ability := StitchedParts.ability_at_tier(part, int(worn["tier"]))
		if str(ability.get("id", "")) == ability_id:
			return ability
	return {}


func _perform(battle: StitchedRules, actor_id: String, ability_id: String,
		target_rank: int, trace: Array) -> Dictionary:
	var actor := battle.get_unit(actor_id)
	var receipt := battle.use_part(_part_for_ability(battle, actor_id, ability_id), target_rank) \
		if actor.get("side", "") == "hero" else battle.use_foe_ability(ability_id, target_rank)
	_capture(trace, battle, receipt)
	return receipt


func _part_for_ability(battle: StitchedRules, actor_id: String, ability_id: String) -> String:
	var actor := battle.get_unit(actor_id)
	for slot in actor.get("parts", {}):
		var worn: Dictionary = actor["parts"][slot]
		var part: Dictionary = _by_id.get(str(worn["id"]), {})
		if not part.is_empty() and str(StitchedParts.ability_at_tier(part, int(worn["tier"])).get("id", "")) == ability_id:
			return str(worn["id"])
	return ""


func _capture(trace: Array, battle: StitchedRules, receipt: Dictionary) -> void:
	trace.append({"receipt": receipt.duplicate(true), "snapshot": battle.state_snapshot()})


func _advance_to(battle: StitchedRules, wanted: String, trace: Array,
		max_round: int = 12) -> bool:
	for step in range(WALK_LIMIT):
		if battle == null or battle.is_over() or battle.round_number() > max_round:
			return false
		if battle.current_actor_id() == wanted:
			return true
		var passed := battle.pass_turn()
		if not bool(passed.get("ok", false)):
			return false
		_capture(trace, battle, passed)
	return false


func _result(receipt: Dictionary, target_id: String) -> Dictionary:
	for result in receipt.get("results", []):
		if str(result.get("target", "")) == target_id:
			return result
	return {}


func _receipt_has(result: Dictionary, status: String, duration: int) -> bool:
	for entry in result.get("statuses", []):
		if str(entry.get("status", "")) == status and int(entry.get("duration", -1)) == duration:
			return true
	return false


## Every damage comparison uses the actual ability, attacker, target, active statuses,
## and a possible real damage roll. It never substitutes a fake combat hit.
func _matches_damage(battle: StitchedRules, actor: Dictionary,
		ability: Dictionary, target: Dictionary, hit: Dictionary) -> bool:
	if not bool(hit.get("hit", false)) or int(ability.get("dmg", [0, 0])[1]) <= 0:
		return false
	var candidates: Array = []
	var bonus := int(actor.get("dmg_bonus", 0))
	if bool(hit.get("crit", false)):
		candidates.append(StitchedRules.crit_damage(int(ability["dmg"][1])) + bonus)
	else:
		for base in range(int(ability["dmg"][0]), int(ability["dmg"][1]) + 1):
			candidates.append(base + bonus)
	for raw in candidates:
		var base := int(raw)
		if str(actor["side"]) == "foe":
			base = StitchedS1BEffects.enemy_damage(base, battle.candle())
		elif str(actor.get("resolve", "")) == "steadfast":
			base = StitchedS1BEffects.steadfast_damage(base)
		var actual := StitchedRules.damage_after_modifiers(base, actor["statuses"],
			target["statuses"], int(target["statuses"].get("mark", 0)) > 0,
			int(ability.get("mark_damage", 0)), int(target["prot"]))
		if actual == int(hit["damage"]):
			return true
	return false


func _attack_candidate(battle: StitchedRules, target: Dictionary,
		need_mark_bonus: bool) -> Dictionary:
	var actor_id := battle.current_actor_id()
	var actor := battle.get_unit(actor_id)
	if actor.is_empty() or str(actor["side"]) == str(target["side"]):
		return {}
	var options: Array = []
	if str(actor["side"]) == "hero":
		if actor_id == "warden":
			options = ["shield_bash"]
		elif actor_id == "lantern_monk":
			options = ["needle_rain"]
	else:
		match actor_id:
			"spool_hexer":
				options = ["hex_bolt"]
			"spool_leech":
				options = ["leech_bite"]
			"zipper_hauler":
				options = ["hauler_slam"]
			"pincushion_matriarch":
				options = ["matriarch_burst"]
	for ability_id in options:
		var ability := _ability(battle, actor_id, ability_id)
		if ability.is_empty() or int(ability["dmg"][1]) <= 0:
			continue
		if need_mark_bonus and int(ability.get("mark_damage", 0)) <= 0:
			continue
		if not StitchedParts.ranks_allowed(int(ability["launch_mask"]), int(actor["rank"])):
			continue
		if battle._legal_targets(actor, ability, int(target["rank"])).is_empty():
			continue
		if not battle._self_move_gate(actor, ability).is_empty():
			continue
		return {"actor": actor_id, "ability": ability_id, "source": ability}
	return {}


func _attempt(row: Dictionary, seed_value: int) -> Dictionary:
	var caster_id := "seamstress" if str(row["side"]) == "hero" else str(row["caster"])
	var target_side := "foe" if str(row["side"]) == "hero" else "hero"
	var battle := _battle(seed_value, row["foes"], str(row.get("part", "")))
	if battle == null:
		return {}
	var trace: Array = []
	var target_id := _id_at(battle, target_side, int(row["target_rank"]))
	if target_id.is_empty() or battle.turn_order().find(target_id) >= battle.turn_order().find(caster_id):
		return {}
	if not _advance_to(battle, caster_id, trace, 1):
		return {}
	var actor := battle.get_unit(caster_id)
	var source := _ability(battle, caster_id, str(row["ability"]))
	if source.is_empty() or not StitchedParts.ranks_allowed(int(source["launch_mask"]), int(actor["rank"])) \
			or battle._legal_targets(actor, source, int(row["target_rank"])).is_empty():
		return {}
	# Wrong rank is refused before the first draw, including the full snapshot.
	var before_bad := battle.state_snapshot()
	var bad := _perform(battle, caster_id, str(row["ability"]), -1, trace)
	if bool(bad.get("ok", true)) or battle.state_snapshot() != before_bad:
		return {}
	var cast := _perform(battle, caster_id, str(row["ability"]), int(row["target_rank"]), trace)
	var hit := _result(cast, target_id)
	var duration := int(row["duration"])
	var status := str(row["status"])
	if not bool(cast.get("ok", false)) or not bool(hit.get("hit", false)) \
			or not _receipt_has(hit, status, duration):
		return {}
	if int(battle.get_unit(target_id)["statuses"].get(status, 0)) != duration:
		return {}
	var hp_before := int(battle.get_unit(target_id)["hp"])
	if not _advance_to(battle, target_id, trace):
		return {}
	var after_first := battle.get_unit(target_id)
	if int(after_first["statuses"].get(status, 0)) != duration - 1:
		return {}
	if status == "bleed" and int(after_first["hp"]) != hp_before - duration:
		return {}
	var follow: Dictionary = {}
	var follow_kind := str(row["follow"])
	if follow_kind == "move":
		var before_move := battle.state_snapshot()
		var move_bad := battle.move(1)
		if bool(move_bad.get("ok", true)) or battle.state_snapshot() != before_move:
			return {}
		follow = {"refusal": move_bad, "state": before_move}
		_capture(trace, battle, move_bad)
		var passed_tangled := battle.pass_turn()
		if not bool(passed_tangled.get("ok", false)):
			return {}
		_capture(trace, battle, passed_tangled)
	elif follow_kind == "weak":
		var candidate := _attack_candidate(battle,
			battle.get_unit(_id_at(battle, "hero" if target_side == "foe" else "foe", 1)), false)
		# A Weak target is the attacker: choose its own authored damaging action.
		var attack_id := "hex_bolt" if target_side == "foe" else "shield_bash"
		var opponent_id := _id_at(battle, "hero" if target_side == "foe" else "foe", 1)
		var attack_ability := _ability(battle, target_id, attack_id)
		if opponent_id.is_empty() or attack_ability.is_empty():
			return {}
		var target_before := battle.get_unit(opponent_id)
		var attack_before := battle.get_unit(target_id)
		var fired := _perform(battle, target_id, attack_id, 1, trace)
		var result := _result(fired, opponent_id)
		if not bool(result.get("hit", false)) or not _matches_damage(battle, attack_before,
				attack_ability, target_before, result):
			return {}
		follow = {"receipt": fired, "hit": result, "actor": attack_before,
			"target": target_before, "ability": attack_ability}
	elif follow_kind == "bleed":
		var passed_bleed := battle.pass_turn()
		if not bool(passed_bleed.get("ok", false)):
			return {}
		_capture(trace, battle, passed_bleed)
		follow = {"bleed": duration}
	else:
		# A different unit must spend a REAL attack while the target's status remains
		# positive. Search only before its next own start, never after expiration.
		var passed_first := battle.pass_turn()
		if not bool(passed_first.get("ok", false)):
			return {}
		_capture(trace, battle, passed_first)
		var found := false
		for step in range(WALK_LIMIT):
			if battle.is_over() or battle.current_actor_id() == target_id:
				break
			var target_before := battle.get_unit(target_id)
			var bonus_needed := status == "mark"
			var candidate := _attack_candidate(battle, target_before, bonus_needed)
			if not candidate.is_empty() and int(target_before["statuses"].get(status, 0)) > 0:
				var attack_before := battle.get_unit(str(candidate["actor"]))
				var fired := _perform(battle, str(candidate["actor"]),
					str(candidate["ability"]), int(target_before["rank"]), trace)
				var result := _result(fired, target_id)
				if bool(result.get("hit", false)) and _matches_damage(battle,
						attack_before, candidate["source"], target_before, result):
					follow = {"receipt": fired, "hit": result, "actor": attack_before,
						"target": target_before, "ability": candidate["source"]}
					found = true
					break
			else:
				var passed := battle.pass_turn()
				if not bool(passed.get("ok", false)):
					break
				_capture(trace, battle, passed)
		if not found:
			return {}
	# The affected unit must eventually lose the status on precisely its Nth start.
	for tick in range(2, duration + 1):
		if not _advance_to(battle, target_id, trace):
			return {}
		var current := battle.get_unit(target_id)
		if int(current["statuses"].get(status, 0)) != duration - tick:
			return {}
		if status == "bleed":
			var expected_hp := hp_before
			for n in range(duration, duration - tick, -1):
				expected_hp -= n
			if int(current["hp"]) != expected_hp:
				return {}
		if tick < duration:
			var passed := battle.pass_turn()
			if not bool(passed.get("ok", false)):
				return {}
			_capture(trace, battle, passed)
	if follow_kind == "move":
		var move_ok := battle.move(1)
		if not bool(move_ok.get("ok", false)):
			return {}
		_capture(trace, battle, move_ok)
		follow["moved"] = move_ok
	if status == "mark" and target_side == "hero":
		# The leech's authored Mark-bonus bite would hunt rank 2 while Mark
		# lives. After three genuine affected starts it must revert to rank 1.
		var expired_before := battle.state_snapshot()
		var rng_before := battle.rng_state()
		var expired_choice := StitchedFoeIntent.choose(battle, battle.get_unit("spool_leech"))
		if int(expired_choice.get("target_rank", 0)) != 1 \
				or expired_before != battle.state_snapshot() or rng_before != battle.rng_state():
			return {}
		follow["expired_intent"] = expired_choice
	return {"seed": seed_value, "trace": trace, "snapshot": battle.state_snapshot(),
		"rng": battle.rng_state(), "cast": cast, "target": target_id, "follow": follow,
		"status": status, "duration": duration}


func _test_row(row: Dictionary) -> void:
	var witness: Dictionary = {}
	for seed_value in range(1, SEED_MAX + 1):
		witness = _attempt(row, seed_value)
		if not witness.is_empty():
			break
	var label := str(row["name"])
	_check(not witness.is_empty(), "AC1/AC2: authentic 4v2 status/follow-up witness: " + label)
	if witness.is_empty():
		return
	_check(witness["cast"].get("results", []).size() >= 1 and not str(witness["target"]).is_empty(),
		"AC1: actual public receipt identifies target: " + label)
	_check(int(witness["duration"]) == int(row["duration"]),
		"AC1: authored duration and own-start ticks through expiry: " + label)
	var kind := str(row["follow"])
	if kind == "move":
		_check(not bool(witness["follow"]["refusal"].get("ok", true))
			and bool(witness["follow"]["moved"].get("ok", false)),
			"AC2/AC3: active Tangled refuses move; expired Tangled permits it")
	elif kind == "bleed":
		_check(int(witness["follow"]["bleed"]) == 2,
			"AC1: Bleed deals 2 then 1 directly on successive affected starts: " + label)
	else:
		var follow: Dictionary = witness["follow"]
		var ability: Dictionary = follow["ability"]
		var result: Dictionary = follow["hit"]
		_check(bool(result.get("hit", false)) and int(result.get("damage", -1)) >= 0,
			"AC2: legal active-status follow-up has a real hit: " + label)
		if str(row["status"]) == "mark":
			_check(int(ability.get("mark_damage", 0)) > 0,
				"AC2: only an authored Mark-bonus strike benefits: " + label)
		if str(row["status"]) == "weak":
			_check(int(follow["actor"]["statuses"].get("weak", 0)) > 0,
				"AC2: Weak was active on the real striking actor: " + label)
		else:
			_check(int(follow["target"]["statuses"].get(str(row["status"]), 0)) > 0,
				"AC2: status was active on the real defender: " + label)
	var replay := _attempt(row, int(witness["seed"]))
	_check(not replay.is_empty() and replay["trace"] == witness["trace"]
		and replay["snapshot"] == witness["snapshot"] and replay["rng"] == witness["rng"],
		"AC3: same-seed fresh public receipts, snapshots and RNG replay: " + label)


func _test_hunt_and_ordinary_mark() -> void:
	# A real rank-3 Hexer tags hero rank 2. Rank-2 Hauler then hits the
	# marked doll WITHOUT a bonus, followed by rank-1 Matriarch hunting her.
	var witnessed := false
	for seed_value in range(1, SEED_MAX + 1):
		var battle := _battle(seed_value, ["pincushion_matriarch", "zipper_hauler", "spool_hexer"])
		if battle == null:
			break
		var order := battle.turn_order()
		if order.find("spool_hexer") >= order.find("zipper_hauler") \
				or order.find("zipper_hauler") >= order.find("pincushion_matriarch"):
			continue
		var trace: Array = []
		if not _advance_to(battle, "spool_hexer", trace, 1):
			continue
		var tag := _perform(battle, "spool_hexer", "thread_tag", 2, trace)
		var tagged := _result(tag, "seamstress")
		if not bool(tagged.get("hit", false)) or not _receipt_has(tagged, "mark", 3):
			continue
		if not _advance_to(battle, "zipper_hauler", trace, 1):
			continue
		var ordinary_actor := battle.get_unit("zipper_hauler")
		var ordinary_target := battle.get_unit("seamstress")
		var ordinary_ability := _ability(battle, "zipper_hauler", "hauler_slam")
		if int(ordinary_target["statuses"].get("mark", 0)) <= 0:
			continue
		var ordinary := _perform(battle, "zipper_hauler", "hauler_slam", 2, trace)
		var ordinary_hit := _result(ordinary, "seamstress")
		if not bool(ordinary_hit.get("hit", false)):
			continue
		if not _advance_to(battle, "pincushion_matriarch", trace, 1):
			continue
		var mark := int(battle.get_unit("seamstress")["statuses"].get("mark", 0))
		var intent_before := battle.state_snapshot()
		var rng_before := battle.rng_state()
		var intent := StitchedFoeIntent.choose(battle, battle.get_unit("pincushion_matriarch"))
		var again := StitchedFoeIntent.choose(battle, battle.get_unit("pincushion_matriarch"))
		var forecast_unchanged := battle.state_snapshot() == intent_before and battle.rng_state() == rng_before
		if mark <= 0 or str(intent.get("ability_id", "")) != "matriarch_burst" \
				or int(intent.get("target_rank", 0)) != 2:
			continue
		var actor := battle.get_unit("pincushion_matriarch")
		var target := battle.get_unit("seamstress")
		var ability := _ability(battle, "pincushion_matriarch", "matriarch_burst")
		var burst := _perform(battle, "pincushion_matriarch", "matriarch_burst", 2, trace)
		var burst_hit := _result(burst, "seamstress")
		if not bool(burst_hit.get("hit", false)):
			continue
		witnessed = true
		_check(int(ordinary_ability.get("mark_damage", -1)) == 0
			and _matches_damage(battle, ordinary_actor, ordinary_ability, ordinary_target, ordinary_hit)
			and int(ordinary_target["statuses"].get("mark", 0)) > 0,
			"AC2: real Hauler strike against Marked doll has no unauthored bonus")
		_check(intent == again and forecast_unchanged and int(intent["target_rank"]) == 2
			and str(intent["target_side"]) == "hero"
			and intent["affected_ranks"] == [2]
			and int(intent["base_mark_damage"]) == 3,
			"AC2/AC3: read-only Mark-hunting intent selects real marked rank 2")
		_check(_matches_damage(battle, actor, ability, target, burst_hit)
			and int(target["statuses"].get("mark", 0)) > 0,
			"AC2: marked Burst adds only its authored bonus on the legal target")
		break
	_check(witnessed, "AC2: non-vacuous seeded 4v3 ordinary strike and Mark hunt")


func _test_miss_and_rank_refusals() -> void:
	var missed := false
	for seed_value in range(1, SEED_MAX + 1):
		var battle := _battle(seed_value, ["spool_hexer", "ragling"],
			"seamstress_scarlet_knot_hat")
		if battle == null:
			break
		var trace: Array = []
		if not _advance_to(battle, "seamstress", trace, 1):
			continue
		var before := battle.state_snapshot()
		var rng := battle.rng_state()
		var bad := battle.use_part("seamstress_scarlet_knot_hat", -1)
		var unauthored := battle.use_part("not_equipped", 1)
		_check(not bool(bad.get("ok", true)) and not bool(unauthored.get("ok", true))
			and before == battle.state_snapshot() and rng == battle.rng_state(),
			"AC3: illegal rank/unauthored command refuse without state/RNG spend")
		var target_id := _id_at(battle, "foe", 1)
		var receipt := battle.use_part("seamstress_scarlet_knot_hat", 1)
		var result := _result(receipt, target_id)
		if bool(receipt.get("ok", false)) and not bool(result.get("hit", true)):
			missed = true
			_check(result.get("statuses", []) == [] and int(result.get("damage", -1)) == 0
				and int(battle.get_unit(target_id)["statuses"].get("weak", 0)) == 0
				and int(battle.get_unit(target_id)["statuses"].get("bleed", 0)) == 0,
				"AC3: natural seeded miss grants neither Weak nor Bleed follow-up")
			break
	_check(missed, "AC3: non-vacuous real seeded status miss")


func _test_dead_target() -> void:
	var witnessed := false
	for seed_value in range(1, 25):
		var battle := _battle(seed_value, ["ragling", "spool_hexer"])
		if battle == null:
			break
		var trace: Array = []
		for step in range(WALK_LIMIT):
			if battle.is_over():
				break
			var unit := battle.get_unit("ragling")
			if bool(unit.get("dead", false)):
				break
			if battle.current_actor_id() == "warden":
				var hit := battle.use_part("warden_arm_shield_bash", 1)
				if not bool(hit.get("ok", false)):
					break
				_capture(trace, battle, hit)
			else:
				var passed := battle.pass_turn()
				if not bool(passed.get("ok", false)):
					break
				_capture(trace, battle, passed)
		if not bool(battle.get_unit("ragling").get("dead", false)) or battle.is_over():
			continue
		if not _advance_to(battle, "warden", trace):
			continue
		var defeated_before := battle.get_unit("ragling")
		var heap_before := battle.get_heaps()
		if not bool(defeated_before.get("dead", false)) or heap_before.is_empty():
			continue
		# The rank is NOT empty: a real scrap heap is an allowed combat target.
		# The dead foe itself must never receive a ghost hit or renewed statuses.
		var heap_attack := battle.use_part("warden_arm_shield_bash", 1)
		var hit := _result(heap_attack, "heap:ragling")
		if bool(heap_attack.get("ok", false)) and not hit.is_empty() \
				and str(hit.get("target_side", "")) == "heap" \
				and bool(battle.get_unit("ragling").get("dead", false)) \
				and battle.get_unit("ragling")["statuses"].is_empty():
			witnessed = true
			break
	_check(witnessed, "AC3: a publicly defeated foe is never hit or re-statused; its heap is the real legal target")
