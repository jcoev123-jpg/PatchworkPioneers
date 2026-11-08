extends SceneTree
## S14 Life Loop: a confirmed socket hit heals its actual recipient at its own turn start.
## These are seeded, catalog-built battles driven by public signature/pass actions.

var failures: Array[String] = []
var checks := 0
const COMMAND := "warden_head_pot_helm_command"
const MENDING := "seamstress_head_mending_knot"
const LOOP := "silk_life_loop"


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)


func _initialize() -> void:
	_foe_ticks()
	_foe_cap()
	_ally_control()
	_miss_and_refusals()
	_missing_target_refusal()
	_without_socket()
	_s14_disabled()
	for message in failures:
		printerr(message)
	print("stitched_s14_life_loop_foe_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _battle(s14: bool = true, sockets: Dictionary = {}) -> StitchedRules:
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	_check(not config.is_empty(), "precondition: real starter party and enemy definitions load")
	if config.is_empty():
		return null
	config["seed"] = 55
	config["s14"] = s14
	config["s14_sockets"] = sockets
	var built := StitchedRules.create(config)
	_check(built.ok and built.battle != null, "precondition: real seeded battle builds")
	return built.battle if built.ok else null


func _to_turn(battle: StitchedRules, actor_id: String) -> bool:
	# A pass is a real public turn action; _enter_turn applies actual status ticks.
	for step in range(64):
		if battle.current_actor_id() == actor_id:
			return true
		if battle.is_over() or not battle.pass_turn().get("ok", false):
			return false
	return false


func _loop_sockets() -> Dictionary:
	return {"warden": {COMMAND: [LOOP]}}


func _foe_ticks() -> void:
	var battle := _battle(true, _loop_sockets())
	if battle == null:
		return
	var foe: Dictionary = battle._foe_at(2)
	_check(not foe.is_empty() and foe.side == "foe" and int(foe.max_hp) >= 7,
		"precondition: a living rank-two authored foe has room for both heals")
	if foe.is_empty() or int(foe.max_hp) < 7 or not _to_turn(battle, "warden"):
		_check(false, "precondition: Warden gets an actual actionable turn")
		return
	foe.hp = int(foe.max_hp) - 6
	var wounded := int(foe.hp)
	var others := {}
	for other in battle.get_foes():
		if str(other.id) != str(foe.id):
			others[str(other.id)] = int(other.hp)
	_check(others.size() > 0, "precondition: at least one other foe stays unpatched")
	var attack := battle.use_ability(COMMAND, 2)
	var hits: Array = attack.get("results", [])
	_check(attack.get("ok", false) and hits.size() == 1, "public signature dispatch returns a real struck target")
	if hits.size() != 1:
		return
	var hit: Dictionary = hits[0]
	var socket_receipt := false
	for effect in hit.get("statuses", []):
		if effect.get("status") == "regen" and effect.get("duration") == 2 and effect.get("patch") == LOOP:
			socket_receipt = true
	_check(hit.get("hit", false) and hit.get("target") == foe.id and socket_receipt,
		"confirmed zero-damage Pot Helm Command hits the intended foe and sockets two regen ticks")
	_check(_to_turn(battle, str(foe.id)), "precondition: actual victim turn is reached through public passes")
	_check(int(foe.hp) == wounded + 2 and int(foe.statuses.get("regen", 0)) == 1,
		"first foe turn restores exactly 2 HP and retains one regen tick")
	_check(battle.current_actor_id() == str(foe.id), "first heal occurs on the recipient's own turn")
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(foe.id)),
		"precondition: victim completes its turn and receives a second natural turn")
	_check(int(foe.hp) == wounded + 4 and not foe.statuses.has("regen"),
		"second foe turn restores exactly 2 HP then expires regen")
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(foe.id)),
		"precondition: same foe has a third real turn")
	_check(int(foe.hp) == wounded + 4 and not foe.statuses.has("regen"),
		"expired regen never heals a third time")
	var isolated := true
	for id in others:
		var other: Dictionary = battle.get_unit(str(id))
		isolated = isolated and int(other.hp) == int(others[id]) and not other.statuses.has("regen")
	_check(isolated, "patch does not heal or apply regen to any other foe")
	_check(not foe.has("death_hits") and not foe.has("head_ward"),
		"foe never acquires hero-only death-door state")


func _foe_cap() -> void:
	var battle := _battle(true, _loop_sockets())
	if battle == null or not _to_turn(battle, "warden"):
		_check(false, "cap fixture reaches a living Warden turn")
		return
	var foe: Dictionary = battle._foe_at(2)
	_check(not foe.is_empty() and int(foe.hp) == int(foe.max_hp),
		"precondition: cap witness begins at full foe health")
	if foe.is_empty():
		return
	foe.hp = int(foe.max_hp) - 1
	var receipt := battle.use_ability(COMMAND, 2)
	var results: Array = receipt.get("results", [])
	_check(receipt.get("ok", false) and results.size() == 1 and results[0].get("hit", false),
		"cap witness applies a real socketed hit")
	if results.size() != 1 or not results[0].get("hit", false):
		return
	_check(_to_turn(battle, str(foe.id)) and int(foe.hp) == int(foe.max_hp)
		and int(foe.statuses.get("regen", 0)) == 1,
		"first tick caps at maximum HP instead of overhealing")
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(foe.id))
		and int(foe.hp) == int(foe.max_hp) and not foe.statuses.has("regen"),
		"second tick expires at full HP without overhealing or adding hero keys")
	_check(not foe.has("death_hits") and not foe.has("head_ward"),
		"capped foe still has no hero death-door keys")


func _ally_control() -> void:
	var battle := _battle(true, {"seamstress": {MENDING: [LOOP]}})
	if battle == null or not _to_turn(battle, "seamstress"):
		_check(false, "ally control reaches a real Seamstress turn")
		return
	var ally: Dictionary = battle._units["tinker"]
	_check(ally.side == "hero" and int(ally.max_hp) >= 11 and int(ally.hp) > 0,
		"precondition: target is a living allied doll with sufficient vitality")
	if int(ally.max_hp) < 11:
		return
	ally.hp = int(ally.max_hp) - 10
	var heal := battle.use_ability(MENDING, int(ally.rank))
	var results: Array = heal.get("results", [])
	_check(heal.get("ok", false) and results.size() == 1
		and results[0].get("hit", false) and results[0].get("target") == ally.id,
		"ally control heals its actual hero target through a public signature")
	_check(int(ally.statuses.get("regen", 0)) >= 1,
		"Life Loop from a friendly signature attaches regeneration to its ally")
	_check(_to_turn(battle, str(ally.id)) and int(ally.statuses.get("regen", 0)) == 1,
		"ally's first natural turn ticks Life Loop")
	ally.death_hits = 2
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(ally.id)),
		"ally control reaches a second natural turn")
	_check(int(ally.death_hits) == 0 and not ally.statuses.has("regen"),
		"ally-only death-hit reset happens on regen; two turns exhaust its duration")


func _miss_and_refusals() -> void:
	var battle := _battle(true, _loop_sockets())
	if battle == null or not _to_turn(battle, "warden"):
		_check(false, "negative controls reach a real Warden turn")
		return
	var foe: Dictionary = battle._foe_at(2)
	_check(not foe.is_empty() and int(foe.hp) > 4, "precondition: miss victim is alive and woundable")
	if foe.is_empty() or int(foe.hp) <= 4:
		return
	foe.hp -= 4
	var wounded := int(foe.hp)
	for illegal_rank in [0, 4]:
		var before := battle.state_snapshot()
		var before_rng := battle.rng_state()
		var refused := battle.use_ability(COMMAND, illegal_rank)
		_check(not refused.get("ok", true) and battle.state_snapshot() == before
			and battle.rng_state() == before_rng and battle.current_actor_id() == "warden",
			"invalid target rank %d is a no-spend, no-RNG, snapshot-pure refusal" % illegal_rank)
	var before_unknown := battle.state_snapshot()
	var before_unknown_rng := battle.rng_state()
	var unknown := battle.use_ability("forged_signature", 2)
	_check(not unknown.get("ok", true) and battle.state_snapshot() == before_unknown
		and battle.rng_state() == before_unknown_rng,
		"forged signature also refuses without mutating or drawing")
	battle._units["warden"].statuses["blind"] = 1
	var missed := battle.use_ability(COMMAND, 2)
	var results: Array = missed.get("results", [])
	_check(missed.get("ok", false) and results.size() == 1
		and not results[0].get("hit", true) and results[0].get("target") == foe.id,
		"Blind makes the public offensive signature miss a real living foe")
	_check(not foe.statuses.has("regen"), "miss never installs Life Loop")
	_check(_to_turn(battle, str(foe.id)) and int(foe.hp) == wounded
		and not foe.statuses.has("regen"), "a missed foe's next turn cannot heal")
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(foe.id))
		and int(foe.hp) == wounded, "a missed foe's second turn cannot heal")


func _without_socket() -> void:
	var battle := _battle(true)
	if battle == null or not _to_turn(battle, "warden"):
		_check(false, "unsocketed fixture reaches a real Warden turn")
		return
	var foe: Dictionary = battle._foe_at(2)
	if foe.is_empty():
		_check(false, "unsocketed fixture has a real foe")
		return
	foe.hp -= 4
	var wounded := int(foe.hp)
	var result := battle.use_ability(COMMAND, 2)
	var hits: Array = result.get("results", [])
	_check(result.get("ok", false) and hits.size() == 1 and hits[0].get("hit", false)
		and not foe.statuses.has("regen"), "unsocketed offensive hit does not create regen")
	_check(_to_turn(battle, str(foe.id)) and int(foe.hp) == wounded
		and not foe.statuses.has("regen"), "unsocketed foe's turn never heals")


func _s14_disabled() -> void:
	var battle := _battle(false)
	if battle == null or not _to_turn(battle, "warden"):
		_check(false, "legacy rules fixture reaches a real Warden turn")
		return
	var foe: Dictionary = battle._foe_at(2)
	if foe.is_empty():
		_check(false, "legacy fixture has a real foe")
		return
	foe.hp -= 4
	var wounded := int(foe.hp)
	var before := battle.state_snapshot()
	var before_rng := battle.rng_state()
	var refused := battle.use_ability(COMMAND, 2)
	_check(not refused.get("ok", true) and battle.state_snapshot() == before
		and battle.rng_state() == before_rng, "S14-off signature is a pure refusal")
	# A synthetic status verifies S14-off bypass without modifying combat algorithms.
	foe.statuses["regen"] = 2
	_check(_to_turn(battle, str(foe.id)) and int(foe.hp) == wounded
		and int(foe.statuses.get("regen", 0)) == 2,
		"S14-off foe turn leaves regen and health untouched")
	_check(battle.pass_turn().get("ok", false) and _to_turn(battle, str(foe.id))
		and int(foe.hp) == wounded and int(foe.statuses.get("regen", 0)) == 2,
		"S14-off second turn still does not tick unsupported regen")


func _missing_target_refusal() -> void:
	var battle := _battle(true, _loop_sockets())
	if battle == null or not _to_turn(battle, "warden"):
		_check(false, "absent-target fixture reaches a real Warden turn")
		return
	var former: Dictionary = battle._foe_at(3)
	_check(not former.is_empty() and int(former.hp) > 0,
		"precondition: rank three initially contains a living foe")
	if former.is_empty():
		return
	var death := {}
	battle._damage_target(former, int(former.hp), death)
	var heap: Dictionary = battle._heap_at(3)
	_check(death.has("heap") and not heap.is_empty(),
		"precondition: the defeated foe leaves a real scrap heap")
	if heap.is_empty():
		return
	battle._clear_heap(heap)
	_check(battle._unit_at("foe", 3).is_empty(),
		"precondition: clearing rank-three scrap leaves no foe OR heap target")
	if not battle._unit_at("foe", 3).is_empty():
		return
	var before := battle.state_snapshot()
	var before_rng := battle.rng_state()
	var refused := battle.use_ability(COMMAND, 3)
	_check(not refused.get("ok", true) and battle.state_snapshot() == before
		and battle.rng_state() == before_rng and battle.current_actor_id() == "warden",
		"legal-mask but absent foe target refuses without healing, spending a turn or RNG")
