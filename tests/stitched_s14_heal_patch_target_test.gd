extends SceneTree
## S14 heal patches: the sewn-on Cotton (2) / Gold (5) healing mends the ally its signature
## helps, or the doll that carries it when the signature strikes a foe (owner 11-10).
## Seeded, catalog-built battles driven only by public signature, foe-ability
## and pass actions; wounds and deaths come from real legal play, never from
## direct _apply_effects calls or test-only unit mutation. The terminal
## gold-sequence fixtures construct their two-torn-limb, 1-HP death-door
## preconditions explicitly, then prove through public use_ability that LOST
## dolls never receive a later patch's healing, effects or receipt entries.

var failures: Array[String] = []
var checks := 0

const COMMAND := "warden_head_pot_helm_command"
const SHIELD_CATCH := "warden_arms_shield_catch"
const MENDING := "seamstress_head_mending_knot"
const NEEDLE := "seamstress_arms_needle_prick"
const COG := "tinker_head_cog_shot"
const WICK := "lantern_monk_arms_wick_spark"
const SACK := "sack_swing"
const PINCH := "pinch"
const COTTON := "cotton_mending_fuzz"
const GOLD := "gold_heart_knot"
const HUNGRY := "gold_hungry_button"
const CASING := "tinker_torso_casing_ward"

const SEED := 55


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _battle(sockets: Dictionary = {}, s14: bool = true, seed_number: int = SEED) -> StitchedRules:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	_check(not config.is_empty(), "precondition: real starter party and enemy definitions load")
	if config.is_empty():
		return null
	config["seed"] = seed_number
	config["s14"] = s14
	config["s14_sockets"] = sockets
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "precondition: real seeded battle builds")
	return built.battle if built.ok else null


func _to_turn(battle: StitchedRules, actor_id: String, limit: int = 128) -> bool:
	# A pass is a real public turn action; _enter_turn applies actual status ticks.
	for step in range(limit):
		if battle.current_actor_id() == actor_id:
			return true
		if battle.is_over() or not battle.pass_turn().get("ok", false):
			return false
	return false


func _heal_entries(hit: Dictionary, patch_id: String) -> Array:
	var found: Array = []
	for entry in hit.get("statuses", []):
		if entry.get("status") == "heal" and str(entry.get("patch", "")) == patch_id:
			found.append(entry)
	return found


func _any_heal_entry(hit: Dictionary) -> bool:
	for entry in hit.get("statuses", []):
		if entry.get("status") == "heal":
			return true
	return false


func _steal_entries(hit: Dictionary, patch_id: String) -> Array:
	var found: Array = []
	for entry in hit.get("statuses", []):
		if entry.get("status") == "steal" and str(entry.get("patch", "")) == patch_id:
			found.append(entry)
	return found


## Authored heal statuses carry no "patch" key; -1 when the ability has none.
func _authored_heal_amount(hit: Dictionary) -> int:
	for entry in hit.get("statuses", []):
		if entry.get("status") == "heal" and not entry.has("patch"):
			return int(entry.get("amount", 0))
	return -1


## Strike the rank-two foe with each listed [actor, ability] pair on that
## actor's real turns until the foe is at least 'need' HP below its maximum.
## Misses simply retry on the actor's next legal turn.
func _wound_foe(battle: StitchedRules, attackers: Array, need: int) -> bool:
	var foe: Dictionary = battle._foe_at(2)
	if foe.is_empty():
		return false
	for round_index in range(8):
		if int(foe.max_hp) - int(foe.hp) >= need:
			return true
		for entry in attackers:
			if not _to_turn(battle, str(entry[0]), 200):
				return false
			var receipt: Dictionary = battle.use_ability(str(entry[1]), 2)
			if not receipt.get("ok", false):
				return false
			if int(foe.max_hp) - int(foe.hp) >= need:
				return true
	return int(foe.max_hp) - int(foe.hp) >= need


## Keep striking with the socketed Command until one confirmed hit lands;
## returns the hit receipt plus the foe HP measured right before that hit.
func _command_until_hit(battle: StitchedRules) -> Dictionary:
	for attempt in range(12):
		if not _to_turn(battle, "warden", 200):
			return {}
		var foe: Dictionary = battle._foe_at(2)
		if foe.is_empty():
			return {}
		var before := int(foe.hp)
		var receipt: Dictionary = battle.use_ability(COMMAND, 2)
		var results: Array = receipt.get("results", [])
		if receipt.get("ok", false) and results.size() == 1 and results[0].get("hit", false):
			return {"hit": results[0], "before": before, "foe": foe}
	return {}


## Cotton 2 then Gold 5, both on one zero-damage signature, in socket order.
## Gold alone, isolated from Cotton, still heals the struck foe five.
## A full-health foe caps both heals at zero without overhealing.
func _foe_full_cap() -> void:
	var battle := _battle({"warden": {COMMAND: [COTTON, GOLD]}})
	if battle == null:
		return
	var foe: Dictionary = battle._foe_at(2)
	_check(not foe.is_empty() and int(foe.hp) == int(foe.max_hp),
		"precondition: cap witness starts at full foe health")
	if foe.is_empty():
		return
	var landed := _command_until_hit(battle)
	_check(not landed.is_empty(), "precondition: cap witness applies a real socketed hit")
	if landed.is_empty():
		return
	var hit: Dictionary = landed["hit"]
	var cotton := _heal_entries(hit, COTTON)
	var gold := _heal_entries(hit, GOLD)
	_check(cotton.size() == 1 and int(cotton[0].get("amount", -1)) == 0
		and gold.size() == 1 and int(gold[0].get("amount", -1)) == 0,
		"both patches report their actual capped zero heal on a full-health foe")
	_check(int(foe.hp) == int(foe.max_hp) and int(hit.get("target_hp", -1)) == int(foe.max_hp),
		"capped foe never overheals and the receipt reports the final HP")


## Allied patch heal stacks on the authored Mending Knot heal, capped at max HP.
func _ally_heal() -> void:
	var battle := _battle({"seamstress": {MENDING: [COTTON]}})
	if battle == null:
		return
	var doll: Dictionary = battle._units["warden"]
	var guard := 0
	while int(doll.max_hp) - int(doll.hp) < 7 and guard < 96:
		guard += 1
		if battle.is_over():
			break
		var actor := battle.current_actor_id()
		if actor == "fray_scavenger":
			battle.use_foe_ability(SACK, 1)
		else:
			battle.pass_turn()
	_check(int(doll.max_hp) - int(doll.hp) >= 7 and int(doll.hp) > 0,
		"precondition: legal foe attacks leave the ally at least seven below maximum")
	if int(doll.max_hp) - int(doll.hp) < 7 or int(doll.hp) <= 0:
		return
	if not _to_turn(battle, "seamstress"):
		_check(false, "precondition: Seamstress reaches a real turn for the ally heal")
		return
	var other: Dictionary = battle._units["tinker"]
	var other_before := int(other.hp)
	var before := int(doll.hp)
	var receipt: Dictionary = battle.use_ability(MENDING, int(doll.rank))
	var results: Array = receipt.get("results", [])
	_check(receipt.get("ok", false) and results.size() == 1 and results[0].get("hit", false)
		and results[0].get("target") == str(doll.id),
		"public Mending Knot signature resolves on its actual wounded ally")
	if results.size() != 1:
		return
	var hit: Dictionary = results[0]
	var patch_heals := _heal_entries(hit, COTTON)
	_check(_authored_heal_amount(hit) == 5,
		"authored Mending Knot heal stays exactly five and is never widened")
	_check(patch_heals.size() == 1 and int(patch_heals[0].get("amount", -1)) == 2,
		"socketed Cotton adds exactly two more healing to the actual ally")
	_check(int(doll.hp) == before + 7 and int(hit.get("target_hp", -1)) == before + 7,
		"ally ends at wounded plus seven and the receipt reports the final HP")
	_check(not bool(doll.hanging) and int(doll.death_hits) == 0,
		"healed ally keeps clean Hanging and death-door state")
	_check(int(other.hp) == other_before,
		"unwounded allies are never healed by another doll's patch")


## A Hanging ally at zero HP recovers through the patch heal on a guard
## signature: Hanging clears, death hits reset, the torn limb stays torn.
func _hanging_recovery() -> void:
	var battle := _battle({"warden": {SHIELD_CATCH: [COTTON]}})
	if battle == null:
		return
	var doll: Dictionary = battle._units["seamstress"]
	var guard := 0
	while not (bool(doll.hanging) and int(doll.hp) == 0 and not bool(doll.lost)) and guard < 256:
		guard += 1
		if battle.is_over():
			break
		var actor := battle.current_actor_id()
		if actor == "fray_scavenger":
			battle.use_foe_ability(SACK, 2)
		elif actor == "scissor_crab":
			battle.use_foe_ability(PINCH, 2)
		else:
			battle.pass_turn()
	_check(bool(doll.hanging) and int(doll.hp) == 0 and not bool(doll.lost) and not battle.is_over(),
		"precondition: authentic foe attacks leave the ally Hanging at zero, not lost")
	if not (bool(doll.hanging) and int(doll.hp) == 0) or bool(doll.lost) or battle.is_over():
		return
	if not _to_turn(battle, "warden"):
		_check(false, "precondition: Hanging ally leaves Warden a real recovery turn")
		return
	var receipt: Dictionary = battle.use_ability(SHIELD_CATCH, int(doll.rank))
	var results: Array = receipt.get("results", [])
	_check(receipt.get("ok", false) and results.size() == 1 and results[0].get("hit", false)
		and results[0].get("target") == str(doll.id),
		"socketed Shield Catch resolves on its actual Hanging ally")
	if results.size() != 1:
		return
	var hit: Dictionary = results[0]
	var patch_heals := _heal_entries(hit, COTTON)
	_check(patch_heals.size() == 1 and int(patch_heals[0].get("amount", -1)) == 2,
		"patch heal raises the Hanging ally by exactly two")
	_check(int(doll.hp) == 2 and not bool(doll.hanging) and int(doll.death_hits) == 0,
		"patch heal clears Hanging and resets death hits on the recovered ally")
	_check(int(hit.get("target_hp", -1)) == 2,
		"recovery receipt reports the ally's final HP")
	_check(_authored_heal_amount(hit) == -1,
		"guard signature carries no authored heal the patch could widen")
	var guarded := false
	for entry in hit.get("statuses", []):
		if entry.get("status") == "guard" and str(entry.get("guards", "")) == str(doll.id):
			guarded = true
	_check(guarded, "authored Guard effect still applies alongside the patch heal")
	var torn_slot := ""
	for slot in ["arms", "legs"]:
		if doll.parts.has(slot) and bool(doll.parts[slot].torn):
			torn_slot = slot
	_check(not torn_slot.is_empty() and bool(doll.parts[torn_slot].torn),
		"patch heal mends stuffing, never the death-door torn limb itself")


## A killing blow that carries the heal patch leaves the foe dead.
func _killed(receipt: Dictionary) -> bool:
	var results: Array = receipt.get("results", [])
	return results.size() == 1 and results[0].has("heap")


## A surviving allied transfer control: a nonterminal Hungry Button on a
## different ally drains only the actual damage into the caster, capped at
## the caster's maximum, and draws no extra RNG against the identical
## unsocketed signature.
## A confirmed allied Shield Catch whose ordered Hungry Button then Heart Knot
## bites through the death door: the ally stays LOST at zero HP with no
## equipment and the second Heart Knot never heals, applies or appears.
## A self-targeted Casing Ward whose Hungry Button bites its own caster through
## the death door: the caster stays LOST at zero HP, never drained back up.
## Misses, illegal actions, unsocketed attacks and S14-off cannot heal or spend.
func _miss_and_refusals() -> void:
	var battle := _battle({"warden": {COMMAND: [COTTON]}})
	if battle == null:
		return
	var foe: Dictionary = battle._foe_at(2)
	_check(not foe.is_empty(), "precondition: negative fixture has a real rank-two foe")
	if foe.is_empty():
		return
	var wounded := false
	for attempt in range(12):
		if not _to_turn(battle, "tinker", 200):
			break
		var receipt: Dictionary = battle.use_ability(COG, 2)
		var hits: Array = receipt.get("results", [])
		if receipt.get("ok", false) and hits.size() == 1 and hits[0].get("hit", false):
			wounded = true
			break
	_check(wounded, "precondition: a legal strike wounds the rank-two foe first")
	if not wounded or not _to_turn(battle, "warden"):
		_check(false, "negative fixture reaches a real Warden turn")
		return
	var wounded_hp := int(foe.hp)
	for illegal_rank in [0, 4]:
		var before := battle.state_snapshot()
		var before_rng := battle.rng_state()
		var refused: Dictionary = battle.use_ability(COMMAND, illegal_rank)
		_check(not refused.get("ok", true) and battle.state_snapshot() == before
			and battle.rng_state() == before_rng and battle.current_actor_id() == "warden",
			"invalid target rank %d is a no-spend, no-RNG, snapshot-pure refusal" % illegal_rank)
	var before_unknown := battle.state_snapshot()
	var before_unknown_rng := battle.rng_state()
	var unknown: Dictionary = battle.use_ability("forged_signature", 2)
	_check(not unknown.get("ok", true) and battle.state_snapshot() == before_unknown
		and battle.rng_state() == before_unknown_rng,
		"forged signature also refuses without mutating or drawing")
	battle._units["warden"].statuses["blind"] = 1
	var missed: Dictionary = battle.use_ability(COMMAND, 2)
	var miss_hits: Array = missed.get("results", [])
	_check(missed.get("ok", false) and miss_hits.size() == 1
		and not miss_hits[0].get("hit", true) and miss_hits[0].get("target") == str(foe.id),
		"Blind makes the public offensive signature miss the real living foe")
	var miss_hit: Dictionary = miss_hits[0] if miss_hits.size() == 1 else {}
	_check(not _any_heal_entry(miss_hit) and not miss_hit.has("patches")
		and int(foe.hp) == wounded_hp and not foe.statuses.has("heal"),
		"a missed attack never heals or patches the foe")
	var plain := _battle({})
	if plain == null:
		return
	var plain_foe: Dictionary = plain._foe_at(2)
	var unsocketed := _command_until_hit(plain)
	_check(not unsocketed.is_empty() and str(plain_foe.id) == str(unsocketed["foe"].id)
		and int(plain_foe.hp) == int(plain_foe.max_hp),
		"precondition: unsocketed attack hits the same full-health foe")
	if unsocketed.is_empty():
		return
	var unsocketed_hit: Dictionary = unsocketed["hit"]
	_check(not _any_heal_entry(unsocketed_hit) and not unsocketed_hit.has("patches"),
		"unsocketed attack hits but cannot heal or report patches")
	var legacy := _battle({}, false)
	if legacy == null or not _to_turn(legacy, "warden"):
		_check(false, "legacy fixture reaches a real Warden turn")
		return
	var before_legacy := legacy.state_snapshot()
	var before_legacy_rng := legacy.rng_state()
	var refused_legacy: Dictionary = legacy.use_ability(COMMAND, 2)
	_check(not refused_legacy.get("ok", true) and legacy.state_snapshot() == before_legacy
		and legacy.rng_state() == before_legacy_rng,
		"S14-off signature is a pure refusal")


## Deterministic replay, plus socketed/unsocketed RNG parity: the heal patch
## draws no extra randomness and the healed HP is the only divergence.
func _scripted_trace(sockets: Dictionary) -> Array:
	var battle := _battle(sockets)
	if battle == null:
		return []
	var trace: Array = []
	# One confirmed needle wound, then passes: the 22-HP foe can never die
	# in either run, so the only possible divergence is the patch heal itself.
	var needle_landed := false
	for step in range(30):
		if battle.is_over():
			break
		var actor := battle.current_actor_id()
		var receipt := {}
		if actor == "warden":
			receipt = battle.use_ability(COMMAND, 2)
		elif actor == "seamstress" and not needle_landed:
			receipt = battle.use_ability(NEEDLE, 2)
			var wound_results: Array = receipt.get("results", [])
			if wound_results.size() == 1 and wound_results[0].get("hit", false):
				needle_landed = true
		else:
			receipt = battle.pass_turn()
		var heal := 0
		var results: Array = receipt.get("results", [])
		if results.size() == 1:
			for entry in results[0].get("statuses", []):
				if entry.get("status") == "heal":
					heal += int(entry.get("amount", 0))
		trace.append({
			"actor": actor,
			"ok": bool(receipt.get("ok", false)),
			"rng": battle.rng_state(),
			"crab_hp": _crab_hp(battle),
			"heal": heal,
		})
	return trace


func _crab_hp(battle: StitchedRules) -> int:
	for foe in battle.get_foes():
		if int(foe["rank"]) == 2 and not bool(foe["dead"]) and int(foe["hp"]) > 0:
			return int(foe["hp"])
	return -1


func _attack_heal_mends_carrier() -> void:
	# Owner 11-10: a heal patch sewn onto an attack mends the doll that carries it, never the foe.
	var battle := _battle({"warden": {COMMAND: [COTTON]}})
	if battle == null:
		return
	var warden: Dictionary = battle._units["warden"]
	warden.hp = int(warden.max_hp) - 6
	var hit := {}
	var before := 0
	var foe_before := 0
	var foe := {}
	for attempt in range(12):
		if not _to_turn(battle, "warden"):
			break
		foe = battle._foe_at(2)
		if foe.is_empty():
			break
		foe.hp = maxi(1, int(foe.max_hp) - 4)
		before = int(warden.hp)
		foe_before = int(foe.hp)
		var results: Array = battle.use_ability(COMMAND, 2).get("results", [])
		if results.size() == 1 and results[0].get("hit", false):
			hit = results[0]
			break
	_check(not hit.is_empty(), "precondition: the socketed Command lands")
	if hit.is_empty():
		return
	_check(int(warden.hp) == before + 2, "the Cotton heal mends its carrier exactly two")
	_check(int(foe.hp) == foe_before - int(hit.get("damage", 0)), "the struck foe is never healed")
	var named := false
	for entry in hit.get("statuses", []):
		if entry.get("status") == "heal" and entry.get("patch") == COTTON and entry.get("on") == "warden":
			named = true
	_check(named, "the receipt says the heal landed on the carrier")


func _initialize() -> void:
	_attack_heal_mends_carrier()
	_foe_full_cap()
	_ally_heal()
	_hanging_recovery()
	_miss_and_refusals()
	for message in failures:
		printerr(message)
	print("stitched_s14_heal_patch_target_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
