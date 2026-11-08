extends SceneTree
## Sewing Circle ability unsew: authenticated detach of one sewn S14 patch, kept owned.

const NODE := "sewing_circle_3"
const HEROES := ["warden", "seamstress", "tinker", "lantern_monk"]
const CATCH := "warden_arms_shield_catch"
const KNOT := "seamstress_head_mending_knot"
const LINT := "cotton_red_lint"
const MARK := "wool_mark_thread"
const CHAIN := "gold_chain_thread"

var failures: Array[String] = []
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _initialize() -> void:
	_preconditions()
	_admission()
	_ac1_detach_keeps_item()
	_ac2_gold_pair()
	_visit_flow()
	_refusals()
	_detached_state_and_replay()
	for message in failures:
		printerr(message)
	print("run_stitched_sewing_ability_unsew_test: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _inventory() -> Array:
	var catalog: Dictionary = StitchedS14Abilities.patches().by_id
	var items: Array = []
	var uid := 11
	for id in [LINT, MARK, CHAIN]:
		items.append({"uid": uid, "id": id, "rarity": catalog[id].rarity})
		uid += 1
	return items


func _sockets() -> Dictionary:
	return {"warden": {CATCH: [13, 12]}, "seamstress": {KNOT: [11]}}


func _make() -> RunStitchedSewingAbilityUnsew:
	return RunStitchedSewingAbilityUnsew.new(NODE, HEROES.duplicate(), _inventory(), _sockets())


func _preconditions() -> void:
	var catalog := StitchedS14Abilities.patches()
	_check(not catalog.is_empty(), "authentic patch catalog loads")
	for id in [LINT, MARK, CHAIN]:
		_check(catalog.by_id.has(id), "catalog has " + id)
	_check(catalog.by_id[CHAIN].rarity == "gold" and catalog.by_id[MARK].rarity == "wool" and catalog.by_id[LINT].rarity == "cotton",
		"fixture rarities are authentic")
	_check(not StitchedS14Abilities.ability("warden", CATCH).is_empty(), "Warden Shield Catch exists")
	_check(StitchedS14Abilities.ability("seamstress", KNOT).get("target_side") == "ally", "Mending Knot is an ally signature")
	_check(StitchedS14Abilities.valid_loadout("warden", {CATCH: [CHAIN, MARK]}), "gold + wool is a valid fixture loadout")
	_check(StitchedS14Abilities.valid_loadout("seamstress", {KNOT: [LINT]}), "cotton on Mending Knot is valid")
	var service := _make()
	_check(service.read_state().get("ok") == true, "fixture is admitted")


func _admission() -> void:
	var bad := RunStitchedSewingAbilityUnsew
	_check(not bad.new("", HEROES, _inventory(), _sockets()).read_state().ok, "empty node refused")
	_check(not bad.new(" node ", HEROES, _inventory(), _sockets()).read_state().ok, "unnormalized node refused")
	_check(not bad.new(NODE, ["warden", "seamstress", "tinker"], _inventory(), _sockets()).read_state().ok, "three heroes refused")
	_check(not bad.new(NODE, ["warden", "warden", "tinker", "seamstress"], _inventory(), _sockets()).read_state().ok, "duplicate heroes refused")
	_check(not bad.new(NODE, ["warden", "seamstress", "tinker", "nobody"], _inventory(), _sockets()).read_state().ok, "unknown hero refused")
	var items := _inventory()
	items[0]["rarity"] = "gold"
	_check(not bad.new(NODE, HEROES, items, _sockets()).read_state().ok, "forged rarity refused")
	items = _inventory()
	items[1]["uid"] = 11
	_check(not bad.new(NODE, HEROES, items, _sockets()).read_state().ok, "duplicate uid refused")
	items = _inventory()
	items[1]["uid"] = 0
	_check(not bad.new(NODE, HEROES, items, {}).read_state().ok, "non-positive uid refused")
	items = _inventory()
	items[0]["id"] = "cotton_made_up"
	_check(not bad.new(NODE, HEROES, items, {}).read_state().ok, "unknown patch id refused")
	_check(not bad.new(NODE, HEROES, _inventory(), {"warden": {KNOT: [11]}}).read_state().ok, "foreign signature refused")
	_check(not bad.new(NODE, HEROES, _inventory(), {"warden": {CATCH: [99]}}).read_state().ok, "unowned socketed uid refused")
	_check(not bad.new(NODE, HEROES, _inventory(), {"warden": {CATCH: [11]}, "seamstress": {KNOT: [11]}}).read_state().ok, "uid sewn twice refused")
	_check(not bad.new(NODE, HEROES, _inventory(), {"warden": {CATCH: [11, 12]}}).read_state().ok, "two non-gold patches refused")
	_check(not bad.new(NODE, HEROES, _inventory(), {"warden": {CATCH: [13, 12, 11]}}).read_state().ok, "three sockets refused")


func _ac1_detach_keeps_item() -> void:
	var service := _make()
	var before := service.read_state()
	var receipt := service.unsew("seamstress", KNOT, 11, NODE, before)
	_check(receipt.get("ok") == true, "AC1 unsew succeeds")
	if receipt.get("ok") != true:
		return
	var after: Dictionary = receipt.state
	_check(after.sockets["seamstress"][KNOT] == [], "AC1 uid removed from Mending Knot")
	_check(after.sockets["warden"] == before.sockets["warden"], "AC1 other hero untouched")
	_check(after.inventory == before.inventory, "AC1 whole inventory retained")
	var kept := false
	for item in after.inventory:
		if item == {"uid": 11, "id": LINT, "rarity": "cotton"}:
			kept = true
	_check(kept, "AC1 same {uid,id,rarity} record still owned")
	_check(int(after.version) == int(before.version) + 1, "AC1 version advances once")
	_check(receipt.source_state == before and receipt.item == {"uid": 11, "id": LINT, "rarity": "cotton"}, "AC1 receipt carries before state and item")
	for key in after:
		_check(not str(key).contains("scrap") and not str(key).contains("gold") and not str(key).contains("rng"), "AC1 no wallet or RNG key " + str(key))
	_check(service.read_state() == after, "AC1 published state is authoritative")
	var resewn := false
	for hero in after.sockets:
		for ability in after.sockets[hero]:
			if 11 in after.sockets[hero][ability]:
				resewn = true
	_check(not resewn, "AC1 patch is not resocketed anywhere")


func _ac2_gold_pair() -> void:
	for pick in [[13, [12]], [12, [13]]]:
		var service := _make()
		var before := service.read_state()
		var receipt := service.unsew("warden", CATCH, int(pick[0]), NODE, before)
		_check(receipt.get("ok") == true, "AC2 unsew uid %d succeeds" % int(pick[0]))
		if receipt.get("ok") != true:
			continue
		var after: Dictionary = receipt.state
		_check(after.sockets["warden"][CATCH] == pick[1], "AC2 remaining uid kept unshifted")
		_check(after.sockets["seamstress"] == before.sockets["seamstress"], "AC2 other hero sockets untouched")
		_check(after.inventory == before.inventory, "AC2 inventory untouched")
		var ids: Array = []
		for uid in after.sockets["warden"][CATCH]:
			for item in after.inventory:
				if item.uid == uid:
					ids.append(item.id)
		_check(StitchedS14Abilities.valid_loadout("warden", {CATCH: ids}), "AC2 resulting loadout validates")
		_check(StitchedS14Abilities.socket_limit(ids) == (2 if CHAIN in ids else 1), "AC2 socket limit matches remaining rarity")


func _visit_flow() -> void:
	var service := _make()
	var first := service.unsew("warden", CATCH, 13, NODE, service.read_state())
	_check(first.get("ok") == true, "visit first unsew")
	var second := service.unsew("seamstress", KNOT, 11, NODE, first.get("state", {}))
	_check(second.get("ok") == true, "visit second different unsew")
	if first.get("ok") != true or second.get("ok") != true:
		return
	_check(int(second.state.version) > int(first.state.version), "visit version is monotonic")
	_check(second.state.sockets["warden"][CATCH] == [12] and second.state.sockets["seamstress"][KNOT] == [], "visit both bindings released")
	var left := service.leave(NODE, second.state)
	_check(left.get("ok") == true and left.state.open == false and int(left.state.version) > int(second.state.version), "leave closes the stop")
	_check(left.state.sockets == second.state.sockets and left.state.inventory == second.state.inventory, "leave changes no binding")
	var closed := service.read_state()
	_check(not service.unsew("warden", CATCH, 12, NODE, closed).ok, "closed visit refuses unsew")
	_check(not service.leave(NODE, closed).ok, "leave works once")
	_check(service.read_state() == closed, "closed state unchanged by refusals")


func _refuse(service: RunStitchedSewingAbilityUnsew, rng: RandomNumberGenerator, label: String, hero: Variant, ability: Variant, uid: Variant, node: Variant, expected: Variant) -> void:
	var state_before := service.read_state()
	var rng_before := rng.state
	var result := service.unsew(hero, ability, uid, node, expected)
	_check(result.get("ok") == false and not str(result.get("error", "")).is_empty(), label + " refused")
	_check(service.read_state() == state_before, label + " preserves state")
	_check(rng.state == rng_before, label + " leaves RNG sentinel untouched")


func _refusals() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	rng.randi()
	var state := service.read_state()
	_refuse(service, rng, "wrong node", "seamstress", KNOT, 11, "other_node", state)
	_refuse(service, rng, "non-string node", "seamstress", KNOT, 11, 5, state)
	var stale := state.duplicate(true)
	stale["version"] = 99
	_refuse(service, rng, "stale version", "seamstress", KNOT, 11, NODE, stale)
	var altered := state.duplicate(true)
	altered.sockets["warden"][CATCH] = [13]
	_refuse(service, rng, "altered snapshot", "seamstress", KNOT, 11, NODE, altered)
	var forged := state.duplicate(true)
	forged.inventory[0]["rarity"] = "gold"
	_refuse(service, rng, "forged inventory", "seamstress", KNOT, 11, NODE, forged)
	_refuse(service, rng, "non-dictionary state", "seamstress", KNOT, 11, NODE, "state")
	_refuse(service, rng, "unknown hero", "nobody", KNOT, 11, NODE, state)
	_refuse(service, rng, "hero outside the party", "scarecrow", KNOT, 11, NODE, state)
	_refuse(service, rng, "unknown ability", "seamstress", "seamstress_head_made_up", 11, NODE, state)
	_refuse(service, rng, "ability of another hero", "seamstress", CATCH, 11, NODE, state)
	_refuse(service, rng, "unknown uid", "seamstress", KNOT, 9999, NODE, state)
	_refuse(service, rng, "non-integer uid", "seamstress", KNOT, "11", NODE, state)
	_refuse(service, rng, "non-string hero", 7, KNOT, 11, NODE, state)
	_refuse(service, rng, "owned but not socketed there", "warden", "warden_head_pot_helm_command", 12, NODE, state)
	_refuse(service, rng, "uid bound to another doll", "warden", CATCH, 11, NODE, state)
	_refuse(service, rng, "uid on the right doll but another ability", "warden", "warden_legs_rim_toss", 12, NODE, state)
	var done := service.unsew("seamstress", KNOT, 11, NODE, state)
	_check(done.get("ok") == true, "refusal fixture unsews once")
	_refuse(service, rng, "repeated already-unsewn uid", "seamstress", KNOT, 11, NODE, done.get("state", {}))
	_refuse(service, rng, "stale state after success", "warden", CATCH, 12, NODE, state)
	var eligible := service.unsew("warden", CATCH, 12, NODE, done.get("state", {}))
	_check(eligible.get("ok") == true, "refusals consumed no other eligible action")


func _detached_state_and_replay() -> void:
	var service := _make()
	var receipt := service.unsew("warden", CATCH, 12, NODE, service.read_state())
	if receipt.get("ok") != true:
		_check(false, "replay fixture unsews")
		return
	var held := service.read_state()
	receipt.state.sockets["warden"][CATCH] = [999]
	receipt.state.inventory.clear()
	receipt.source_state.sockets.clear()
	var copy := service.read_state()
	copy.sockets["seamstress"][KNOT] = []
	copy.inventory.append({"uid": 77})
	copy.hero_ids.clear()
	_check(service.read_state() == held, "mutating receipts and copies never changes held state")
	_check(held.sockets["warden"][CATCH] == [13] and held.inventory.size() == 3, "held state is intact")
	var twin := _make()
	var twin_receipt := twin.unsew("warden", CATCH, 12, NODE, twin.read_state())
	_check(twin_receipt.get("ok") == true and twin.read_state() == held, "identical fixtures replay to identical snapshots")
	var source_inventory := _inventory()
	var source_sockets := _sockets()
	var isolated := RunStitchedSewingAbilityUnsew.new(NODE, HEROES.duplicate(), source_inventory, source_sockets)
	source_sockets["warden"][CATCH].clear()
	source_inventory.clear()
	_check(isolated.read_state().sockets["warden"][CATCH] == [13, 12] and isolated.read_state().inventory.size() == 3, "admitted data is detached from the caller")
