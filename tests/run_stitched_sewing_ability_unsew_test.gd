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
	_sew_resew_same_signature()
	_sew_move_to_ally_signature()
	_sew_gold_capacity()
	_sew_refusals()
	_sew_after_leave()
	_sew_receipts_and_replay()
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


const RECEIPT_KEYS := ["ok", "error", "action", "node_id", "hero_id", "ability_id", "uid", "item",
	"sockets_before", "sockets_after", "source_state", "state"]


func _bound_anywhere(state: Dictionary, uid: int) -> int:
	var count := 0
	for hero in state.sockets:
		for ability in state.sockets[hero]:
			count += (state.sockets[hero][ability] as Array).count(uid)
	return count


func _refuse_sew(service: RunStitchedSewingAbilityUnsew, rng: RandomNumberGenerator, label: String, hero: Variant, ability: Variant, uid: Variant, node: Variant, expected: Variant) -> void:
	var state_before := service.read_state()
	var rng_before := rng.state
	var result := service.sew(hero, ability, uid, node, expected)
	_check(result.get("ok") == false and not str(result.get("error", "")).is_empty(), label + " sew refused")
	_check(not result.has("action") and not result.has("sockets_after"), label + " refusal carries no success receipt")
	_check(service.read_state() == state_before, label + " sew preserves state")
	_check(rng.state == rng_before, label + " sew leaves RNG sentinel untouched")


func _sew_resew_same_signature() -> void:
	var service := _make()
	var start := service.read_state()
	_check(not start.sockets.has("tinker"), "sew fixture starts without a Tinker socket map")
	var out := service.unsew("seamstress", KNOT, 11, NODE, start)
	_check(out.get("ok") == true, "sew AC1 detach succeeds")
	if out.get("ok") != true:
		return
	var released: Dictionary = out.state
	_check(_bound_anywhere(released, 11) == 0, "sew AC1 released uid is unbound before resewing")
	var receipt := service.sew("seamstress", KNOT, 11, NODE, released)
	_check(receipt.get("ok") == true and receipt.get("error") == "" and receipt.get("action") == "sew", "sew AC1 resew to same signature succeeds")
	if receipt.get("ok") != true:
		return
	for key in RECEIPT_KEYS:
		_check(receipt.has(key), "sew AC1 receipt has " + key)
	_check(receipt.node_id == NODE and receipt.hero_id == "seamstress" and receipt.ability_id == KNOT and receipt.uid == 11, "sew AC1 receipt names the binding")
	_check(receipt.item == {"uid": 11, "id": LINT, "rarity": "cotton"}, "sew AC1 receipt carries the owned record")
	_check(receipt.sockets_before == [] and receipt.sockets_after == [11], "sew AC1 receipt before/after sockets")
	_check(receipt.source_state == released, "sew AC1 receipt source is the presented snapshot")
	var after: Dictionary = receipt.state
	_check(after.sockets == start.sockets, "sew AC1 detach then resew restores the original bindings")
	_check(after.inventory == _inventory() and after.inventory == start.inventory, "sew AC1 complete inventory unchanged")
	_check(int(after.version) == int(released.version) + 1 and int(after.version) == int(start.version) + 2, "sew AC1 exactly one version step per mutation")
	_check(service.read_state() == after, "sew AC1 published state is authoritative")
	for key in after:
		_check(not str(key).contains("scrap") and not str(key).contains("gold") and not str(key).contains("rng"), "sew AC1 no wallet or RNG key " + str(key))


func _sew_move_to_ally_signature() -> void:
	var catalog: Dictionary = StitchedS14Abilities.patches().by_id
	var tune_up := "tinker_legs_tune_up"
	_check(StitchedS14Abilities.ability("tinker", tune_up).get("target_side") == "ally", "sew AC2 Tune Up is an ally-targeting heal signature")
	_check(catalog[LINT].effect == "bleed", "sew AC2 Red Lint is a harmful Bleed patch")
	var service := _make()
	var start := service.read_state()
	var out := service.unsew("seamstress", KNOT, 11, NODE, start)
	if out.get("ok") != true:
		_check(false, "sew AC2 detach succeeds")
		return
	var receipt := service.sew("tinker", tune_up, 11, NODE, out.state)
	_check(receipt.get("ok") == true, "sew AC2 released uid moves to another hero's signature")
	if receipt.get("ok") != true:
		return
	var after: Dictionary = receipt.state
	_check(after.sockets["tinker"][tune_up] == [11], "sew AC2 first sew builds the missing hero/ability map")
	_check(receipt.sockets_before == [] and receipt.sockets_after == [11], "sew AC2 receipt before/after for a new map")
	_check(after.sockets["seamstress"][KNOT] == [] and after.sockets["warden"] == start.sockets["warden"], "sew AC2 only that binding moved")
	_check(_bound_anywhere(after, 11) == 1, "sew AC2 uid is bound exactly once")
	_check(after.inventory == start.inventory, "sew AC2 inventory unchanged")
	_check(StitchedS14Abilities.valid_loadout("tinker", {tune_up: [LINT]}), "sew AC2 real rule accepts cotton on Tune Up")
	_check(catalog[str(receipt.item.id)].effect == "bleed", "sew AC2 authored patch keeps its harmful effect on an ally signature")
	var lantern := service.sew("lantern_monk", "lantern_monk_legs_pole_shelter", 11, NODE, after)
	_check(lantern.get("ok") == false, "sew AC2 the same uid cannot be bound twice")
	var back := service.unsew("tinker", tune_up, 11, NODE, service.read_state())
	_check(back.get("ok") == true and back.state.sockets["tinker"][tune_up] == [], "sew AC2 moved binding can be released again")


func _sew_gold_capacity() -> void:
	var service := _make()
	var state := service.read_state()
	for step in [["warden", CATCH, 12], ["warden", CATCH, 13], ["seamstress", KNOT, 11]]:
		var out := service.unsew(step[0], step[1], int(step[2]), NODE, state)
		if out.get("ok") != true:
			_check(false, "sew AC2 gold fixture unsew %d" % int(step[2]))
			return
		state = out.state
	_check(state.sockets["warden"][CATCH] == [] and _bound_anywhere(state, 11) + _bound_anywhere(state, 12) + _bound_anywhere(state, 13) == 0, "sew AC2 gold fixture has everything released")
	var wool := service.sew("warden", CATCH, 12, NODE, state)
	_check(wool.get("ok") == true, "sew AC2 first non-gold patch fits")
	if wool.get("ok") != true:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	rng.randi()
	_refuse_sew(service, rng, "second non-gold patch", "warden", CATCH, 11, NODE, wool.state)
	_check(not StitchedS14Abilities.valid_loadout("warden", {CATCH: [LINT, MARK]}), "sew AC2 real rule refuses two non-gold patches")
	var gold := service.sew("warden", CATCH, 13, NODE, wool.state)
	_check(gold.get("ok") == true and gold.state.sockets["warden"][CATCH] == [12, 13], "sew AC2 gold plus one other patch is legal")
	if gold.get("ok") != true:
		return
	_check(gold.sockets_before == [12] and gold.sockets_after == [12, 13], "sew AC2 gold receipt before/after sockets")
	_check(StitchedS14Abilities.valid_loadout("warden", {CATCH: [MARK, CHAIN]}) and StitchedS14Abilities.socket_limit([MARK, CHAIN]) == 2, "sew AC2 real rule allows gold capacity of two")
	_refuse_sew(service, rng, "third patch", "warden", CATCH, 11, NODE, gold.state)
	_check(not StitchedS14Abilities.valid_loadout("warden", {CATCH: [MARK, CHAIN, LINT]}), "sew AC2 real rule refuses a third patch")
	# Gold may also arrive first, then one other patch.
	var other := _make()
	var st := other.read_state()
	for step in [["warden", CATCH, 12], ["warden", CATCH, 13]]:
		var released := other.unsew(step[0], step[1], int(step[2]), NODE, st)
		if released.get("ok") != true:
			_check(false, "sew AC2 gold-first fixture unsew")
			return
		st = released.state
	var gold_first := other.sew("warden", CATCH, 13, NODE, st)
	var then_wool := other.sew("warden", CATCH, 12, NODE, gold_first.get("state", {}))
	_check(gold_first.get("ok") == true and then_wool.get("ok") == true and then_wool.state.sockets["warden"][CATCH] == [13, 12], "sew AC2 gold first then another patch is legal")


func _sew_refusals() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	rng.randi()
	var state := service.read_state()
	var done := service.unsew("seamstress", KNOT, 11, NODE, state)
	_check(done.get("ok") == true, "sew refusal fixture releases uid 11")
	if done.get("ok") != true:
		return
	var open: Dictionary = done.state
	# Already-bound uids: same signature, another signature, another hero.
	_refuse_sew(service, rng, "bound uid on the same signature", "warden", CATCH, 13, NODE, open)
	_refuse_sew(service, rng, "bound uid on another signature", "warden", "warden_legs_rim_toss", 13, NODE, open)
	_refuse_sew(service, rng, "bound uid on another hero", "tinker", "tinker_legs_tune_up", 12, NODE, open)
	_refuse_sew(service, rng, "bound uid on another hero's other signature", "seamstress", KNOT, 13, NODE, open)
	# Unknown or malformed uids.
	_refuse_sew(service, rng, "unknown uid", "seamstress", KNOT, 9999, NODE, open)
	_refuse_sew(service, rng, "zero uid", "seamstress", KNOT, 0, NODE, open)
	_refuse_sew(service, rng, "negative uid", "seamstress", KNOT, -11, NODE, open)
	_refuse_sew(service, rng, "string uid", "seamstress", KNOT, "11", NODE, open)
	_refuse_sew(service, rng, "float uid", "seamstress", KNOT, 11.0, NODE, open)
	_refuse_sew(service, rng, "null uid", "seamstress", KNOT, null, NODE, open)
	# Signatures and heroes.
	_refuse_sew(service, rng, "unknown ability", "seamstress", "seamstress_head_made_up", 11, NODE, open)
	_refuse_sew(service, rng, "ability of another hero", "seamstress", CATCH, 11, NODE, open)
	_refuse_sew(service, rng, "unknown hero", "nobody", KNOT, 11, NODE, open)
	_refuse_sew(service, rng, "real hero outside the party", "scarecrow", "scarecrow_head_straw_gaze", 11, NODE, open)
	_refuse_sew(service, rng, "non-string hero", 7, KNOT, 11, NODE, open)
	_refuse_sew(service, rng, "non-string ability", "seamstress", 7, 11, NODE, open)
	# Over-cap: the released cotton uid cannot become a third patch on gold + wool.
	_refuse_sew(service, rng, "over-cap socket", "warden", CATCH, 11, NODE, open)
	# Snapshot gate.
	_refuse_sew(service, rng, "wrong node", "seamstress", KNOT, 11, "other_node", open)
	_refuse_sew(service, rng, "non-string node", "seamstress", KNOT, 11, 5, open)
	var stale := open.duplicate(true)
	stale["version"] = 99
	_refuse_sew(service, rng, "stale version", "seamstress", KNOT, 11, NODE, stale)
	_refuse_sew(service, rng, "snapshot from before the unsew", "seamstress", KNOT, 11, NODE, state)
	var altered := open.duplicate(true)
	altered.sockets["warden"][CATCH] = [13]
	_refuse_sew(service, rng, "altered snapshot", "seamstress", KNOT, 11, NODE, altered)
	var forged := open.duplicate(true)
	forged.inventory[0]["rarity"] = "gold"
	_refuse_sew(service, rng, "forged inventory", "seamstress", KNOT, 11, NODE, forged)
	_refuse_sew(service, rng, "non-dictionary state", "seamstress", KNOT, 11, NODE, "state")
	_refuse_sew(service, rng, "null state", "seamstress", KNOT, 11, NODE, null)
	var eligible := service.sew("seamstress", KNOT, 11, NODE, service.read_state())
	_check(eligible.get("ok") == true, "sew refusals consumed no eligible action")
	_check(eligible.get("state", {}).get("inventory", []) == _inventory(), "sew refusals never touched the inventory")


func _sew_after_leave() -> void:
	var service := _make()
	var out := service.unsew("seamstress", KNOT, 11, NODE, service.read_state())
	if out.get("ok") != true:
		_check(false, "sew leave fixture unsews")
		return
	var left := service.leave(NODE, out.state)
	_check(left.get("ok") == true, "sew leave fixture leaves")
	var closed := service.read_state()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	rng.randi()
	_refuse_sew(service, rng, "operation after leave", "seamstress", KNOT, 11, NODE, closed)
	_check(not service.unsew("warden", CATCH, 13, NODE, closed).ok and not service.leave(NODE, closed).ok, "sew leave still refuses unsew and a second leave")
	_check(service.read_state() == closed and closed.sockets["seamstress"][KNOT] == [], "sew leave keeps the closed bindings")


func _sew_receipts_and_replay() -> void:
	var service := _make()
	var start := service.read_state()
	var out := service.unsew("seamstress", KNOT, 11, NODE, start)
	if out.get("ok") != true:
		_check(false, "sew replay fixture unsews")
		return
	var receipt := service.sew("tinker", "tinker_legs_tune_up", 11, NODE, out.state)
	if receipt.get("ok") != true:
		_check(false, "sew replay fixture sews")
		return
	var held := service.read_state()
	receipt.state.sockets["tinker"]["tinker_legs_tune_up"].append(999)
	receipt.state.inventory.clear()
	receipt.source_state.sockets.clear()
	receipt.sockets_after.clear()
	receipt.sockets_before.append(5)
	receipt.item["id"] = "forged"
	out.state.sockets.clear()
	_check(service.read_state() == held, "sew mutating receipts never changes held state")
	_check(held.sockets["tinker"]["tinker_legs_tune_up"] == [11] and held.inventory == _inventory(), "sew held state is intact")
	var copy := service.read_state()
	copy.sockets["tinker"]["tinker_legs_tune_up"].clear()
	_check(service.read_state() == held, "sew read_state copies are detached")

	var twin := _make()
	var twin_out := twin.unsew("seamstress", KNOT, 11, NODE, twin.read_state())
	var twin_sew := twin.sew("tinker", "tinker_legs_tune_up", 11, NODE, twin_out.get("state", {}))
	_check(twin_sew.get("ok") == true and twin.read_state() == held, "sew identical fixtures replay to identical snapshots")

	# Full legal sequence: unsew -> sew -> unsew -> leave, then every later mutation refuses.
	var seq := _make()
	var s0 := seq.read_state()
	var r1 := seq.unsew("seamstress", KNOT, 11, NODE, s0)
	var r2 := seq.sew("seamstress", KNOT, 11, NODE, r1.get("state", {}))
	var r3 := seq.unsew("seamstress", KNOT, 11, NODE, r2.get("state", {}))
	var r4 := seq.leave(NODE, r3.get("state", {}))
	_check(r1.get("ok") == true and r2.get("ok") == true and r3.get("ok") == true and r4.get("ok") == true, "sew sequence unsew-sew-unsew-leave succeeds")
	if not (r1.get("ok") == true and r2.get("ok") == true and r3.get("ok") == true and r4.get("ok") == true):
		return
	_check(int(r4.state.version) == int(s0.version) + 4, "sew sequence advances the version once per step")
	_check(r2.state.sockets["seamstress"][KNOT] == [11] and r3.state.sockets["seamstress"][KNOT] == [], "sew sequence bindings follow each step")
	_check(r4.state.inventory == s0.inventory, "sew sequence keeps the inventory")
	var seq_twin := _make()
	var t1 := seq_twin.unsew("seamstress", KNOT, 11, NODE, seq_twin.read_state())
	var t2 := seq_twin.sew("seamstress", KNOT, 11, NODE, t1.get("state", {}))
	var t3 := seq_twin.unsew("seamstress", KNOT, 11, NODE, t2.get("state", {}))
	var t4 := seq_twin.leave(NODE, t3.get("state", {}))
	_check(t4.get("state") == r4.state and t2.get("state") == r2.state, "sew sequence replays identically")
	var final := seq.read_state()
	_check(not seq.sew("seamstress", KNOT, 11, NODE, final).ok and not seq.unsew("warden", CATCH, 13, NODE, final).ok and not seq.leave(NODE, final).ok, "sew sequence refuses all later mutations")
	_check(seq.read_state() == final, "sew sequence closed state unchanged by refusals")
