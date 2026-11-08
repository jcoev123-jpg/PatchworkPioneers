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
	_move_sewn_gold_transfer()
	_move_sewn_variants()
	_move_sewn_refusals()
	_move_sewn_closed_and_replay()
	_swap_sewn_exchange()
	_swap_sewn_refusals()
	_swap_sewn_closed_and_replay()
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


const MOVE_KEYS := ["ok", "error", "action", "node_id", "uid", "item", "from_hero_id", "from_ability_id",
	"to_hero_id", "to_ability_id", "source_state", "state"]
const RIM := "warden_legs_rim_toss"
const TUNE := "tinker_legs_tune_up"


func _refuse_move(service: RunStitchedSewingAbilityUnsew, rng: RandomNumberGenerator, label: String, args: Array, node: Variant, expected: Variant) -> void:
	var state_before := service.read_state()
	var rng_before := rng.state
	var result := service.move_sewn(args[0], args[1], args[2], args[3], args[4], node, expected)
	_check(result.get("ok") == false and not str(result.get("error", "")).is_empty(), label + " move refused")
	_check(not result.has("action") and not result.has("source_state"), label + " move refusal carries no success receipt")
	_check(service.read_state() == state_before, label + " move preserves state")
	_check(rng.state == rng_before, label + " move leaves RNG sentinel untouched")


func _move_sewn_gold_transfer() -> void:
	var service := _make()
	var before := service.read_state()
	_check(before.sockets["warden"][CATCH] == [13, 12] and before.sockets["seamstress"][KNOT] == [11], "move AC1 fixture precondition")
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	rng.randi()
	var rng_before := rng.state
	var receipt := service.move_sewn("warden", CATCH, "seamstress", KNOT, 13, NODE, before)
	_check(receipt.get("ok") == true and receipt.get("error") == "" and receipt.get("action") == "move_sewn", "move AC1 gold transfer succeeds")
	if receipt.get("ok") != true:
		return
	for key in MOVE_KEYS:
		_check(receipt.has(key), "move AC1 receipt has " + key)
	_check(receipt.node_id == NODE and receipt.uid == 13, "move AC1 receipt names node and uid")
	_check(receipt.from_hero_id == "warden" and receipt.from_ability_id == CATCH and receipt.to_hero_id == "seamstress" and receipt.to_ability_id == KNOT, "move AC1 receipt names both signatures")
	_check(receipt.item == {"uid": 13, "id": CHAIN, "rarity": "gold"}, "move AC1 receipt carries the owned record")
	_check(receipt.source_sockets_before == [13, 12] and receipt.source_sockets_after == [12], "move AC1 receipt source before/after rows")
	_check(receipt.destination_sockets_before == [11] and receipt.destination_sockets_after == [11, 13], "move AC1 receipt destination before/after rows")
	_check(receipt.source_state == before, "move AC1 receipt source_state is the presented snapshot")
	var after: Dictionary = receipt.state
	_check(after.sockets["warden"][CATCH] == [12], "move AC1 source becomes [12]")
	_check(after.sockets["seamstress"][KNOT] == [11, 13], "move AC1 destination becomes [11, 13]")
	_check(StitchedS14Abilities.valid_loadout("warden", {CATCH: [MARK]}), "move AC1 source passes valid_loadout")
	_check(StitchedS14Abilities.valid_loadout("seamstress", {KNOT: [LINT, CHAIN]}), "move AC1 destination passes valid_loadout")
	_check(after.inventory == before.inventory and after.inventory == _inventory(), "move AC1 inventory exactly unchanged")
	_check(int(after.version) == int(before.version) + 1, "move AC1 version advances once")
	_check(after.open == true and service.read_state() == after, "move AC1 visit stays open and state is authoritative")
	_check(after.hero_ids == before.hero_ids and not after.sockets.has("tinker") and not after.sockets.has("lantern_monk"), "move AC1 no other doll gains sockets")
	_check(_bound_anywhere(after, 13) == 1 and _bound_anywhere(after, 12) == 1 and _bound_anywhere(after, 11) == 1, "move AC1 every uid is bound exactly once")
	_check(rng.state == rng_before, "move AC1 RNG sentinel untouched")
	for key in after:
		_check(not str(key).contains("scrap") and not str(key).contains("gold") and not str(key).contains("rng"), "move AC1 no wallet or RNG key " + str(key))
	# Receipts are detached from held state.
	var held := service.read_state()
	receipt.state.sockets["seamstress"][KNOT].append(999)
	receipt.source_state.sockets.clear()
	receipt.source_sockets_after.clear()
	receipt.destination_sockets_after.append(5)
	receipt.item["id"] = "forged"
	_check(service.read_state() == held, "move AC1 mutating the receipt never changes held state")
	# The next action chains off the receipt state: move the gold patch back.
	var back := service.move_sewn("seamstress", KNOT, "warden", CATCH, 13, NODE, held)
	_check(back.get("ok") == true and back.state.sockets["warden"][CATCH] == [12, 13] and back.state.sockets["seamstress"][KNOT] == [11], "move AC1 gold moves back legally")
	_check(back.get("ok") == true and int(back.state.version) == int(before.version) + 2, "move AC1 second move advances the version once more")
	# Identical fixtures replay identically.
	var twin := _make()
	var twin_receipt := twin.move_sewn("warden", CATCH, "seamstress", KNOT, 13, NODE, twin.read_state())
	_check(twin_receipt.get("ok") == true and twin.read_state() == held, "move AC1 identicalfixtures replay to identical snapshots")


func _move_sewn_variants() -> void:
	# Wool to an empty signature of another doll, and to another signature of the same doll.
	var service := _make()
	var start := service.read_state()
	var to_tinker := service.move_sewn("warden", CATCH, "tinker", TUNE, 12, NODE, start)
	_check(to_tinker.get("ok") == true, "move variant wool reaches a doll with no socket map")
	if to_tinker.get("ok") == true:
		_check(to_tinker.state.sockets["tinker"][TUNE] == [12] and to_tinker.state.sockets["warden"][CATCH] == [13], "move variant new hero map built and source keeps gold")
		_check(to_tinker.destination_sockets_before == [] and to_tinker.state.sockets["seamstress"] == start.sockets["seamstress"], "move variant leaves the other doll alone")
		_check(to_tinker.state.inventory == start.inventory, "move variant inventory unchanged")
	var same_doll := _make()
	var same_start := same_doll.read_state()
	var rim := same_doll.move_sewn("warden", CATCH, "warden", RIM, 12, NODE, same_start)
	_check(rim.get("ok") == true, "move variant same doll other signature succeeds")
	if rim.get("ok") == true:
		_check(rim.state.sockets["warden"][CATCH] == [13] and rim.state.sockets["warden"][RIM] == [12], "move variant same doll both rows updated")
		_check(int(rim.state.version) == int(same_start.version) + 1, "move variant same doll version advances once")
	var emptied := _make()
	var cotton := emptied.move_sewn("seamstress", KNOT, "tinker", TUNE, 11, NODE, emptied.read_state())
	_check(cotton.get("ok") == true and cotton.state.sockets["seamstress"][KNOT] == [] and cotton.state.sockets["tinker"][TUNE] == [11], "move variant emptying the source leaves an empty row")
	if cotton.get("ok") == true:
		_check(cotton.state.sockets["warden"] == start.sockets["warden"], "move variant untouched doll keeps its exact order")


func _move_sewn_refusals() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	rng.randi()
	var state := service.read_state()
	# AC2: two non-gold patches exceed one slot.
	_refuse_move(service, rng, "wool onto occupied cotton", ["warden", CATCH, "seamstress", KNOT, 12], NODE, state)
	_refuse_move(service, rng, "cotton onto gold plus wool", ["seamstress", KNOT, "warden", CATCH, 11], NODE, state)
	# Malformed or unowned uid and wrong ownership.
	_refuse_move(service, rng, "unknown uid", ["warden", CATCH, "seamstress", KNOT, 9999], NODE, state)
	_refuse_move(service, rng, "zero uid", ["warden", CATCH, "seamstress", KNOT, 0], NODE, state)
	_refuse_move(service, rng, "string uid", ["warden", CATCH, "seamstress", KNOT, "13"], NODE, state)
	_refuse_move(service, rng, "float uid", ["warden", CATCH, "seamstress", KNOT, 13.0], NODE, state)
	_refuse_move(service, rng, "null uid", ["warden", CATCH, "seamstress", KNOT, null], NODE, state)
	_refuse_move(service, rng, "incorrect source holder", ["seamstress", KNOT, "warden", RIM, 13], NODE, state)
	_refuse_move(service, rng, "right doll wrong source ability", ["warden", RIM, "seamstress", KNOT, 13], NODE, state)
	# Unknown or foreign signatures and heroes.
	_refuse_move(service, rng, "unknown destination ability", ["warden", CATCH, "seamstress", "seamstress_head_made_up", 13], NODE, state)
	_refuse_move(service, rng, "destination ability of another hero", ["warden", CATCH, "seamstress", CATCH, 13], NODE, state)
	_refuse_move(service, rng, "unknown source ability", ["warden", "warden_head_made_up", "seamstress", KNOT, 13], NODE, state)
	_refuse_move(service, rng, "unknown destination hero", ["warden", CATCH, "nobody", KNOT, 13], NODE, state)
	_refuse_move(service, rng, "destination hero outside the party", ["warden", CATCH, "scarecrow", "scarecrow_head_straw_gaze", 13], NODE, state)
	_refuse_move(service, rng, "source hero outside the party", ["scarecrow", "scarecrow_head_straw_gaze", "seamstress", KNOT, 13], NODE, state)
	_refuse_move(service, rng, "non-string hero", [7, CATCH, "seamstress", KNOT, 13], NODE, state)
	_refuse_move(service, rng, "non-string ability", ["warden", CATCH, "seamstress", 7, 13], NODE, state)
	# Same destination as source.
	_refuse_move(service, rng, "same signature", ["warden", CATCH, "warden", CATCH, 13], NODE, state)
	# Snapshot gate.
	_refuse_move(service, rng, "wrong node", ["warden", CATCH, "tinker", TUNE, 13], "other_node", state)
	_refuse_move(service, rng, "non-string node", ["warden", CATCH, "tinker", TUNE, 13], 5, state)
	var stale := state.duplicate(true)
	stale["version"] = 99
	_refuse_move(service, rng, "stale version", ["warden", CATCH, "tinker", TUNE, 13], NODE, stale)
	var altered := state.duplicate(true)
	altered.sockets["warden"][CATCH] = [13]
	_refuse_move(service, rng, "altered snapshot", ["warden", CATCH, "tinker", TUNE, 13], NODE, altered)
	var forged := state.duplicate(true)
	forged.inventory[0]["rarity"] = "gold"
	_refuse_move(service, rng, "forged inventory", ["warden", CATCH, "tinker", TUNE, 13], NODE, forged)
	_refuse_move(service, rng, "non-dictionary state", ["warden", CATCH, "tinker", TUNE, 13], NODE, "state")
	_refuse_move(service, rng, "null state", ["warden", CATCH, "tinker", TUNE, 13], NODE, null)
	_check(service.read_state() == state and state.inventory == _inventory(), "move refusals left held state and inventory untouched")
	# A legal move is still available after every refused attempt.
	var eligible := service.move_sewn("warden", CATCH, "seamstress", KNOT, 13, NODE, service.read_state())
	_check(eligible.get("ok") == true and int(eligible.state.version) == int(state.version) + 1, "move refusals consumed no eligible action")


func _move_sewn_closed_and_replay() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	rng.randi()
	var start := service.read_state()
	var done := service.move_sewn("warden", CATCH, "seamstress", KNOT, 13, NODE, start)
	_check(done.get("ok") == true, "move replay fixture moves once")
	if done.get("ok") != true:
		return
	# Replay of the same call with the old snapshot, and with the fresh one.
	_refuse_move(service, rng, "replay with the old snapshot", ["warden", CATCH, "seamstress", KNOT, 13], NODE, start)
	_refuse_move(service, rng, "replay with the fresh snapshot", ["warden", CATCH, "seamstress", KNOT, 13], NODE, done.state)
	# The uid now sits on the destination, so moving it from the old source is refused too.
	_refuse_move(service, rng, "stale source after success", ["warden", CATCH, "tinker", TUNE, 13], NODE, done.state)
	# Existing operations still work after a move.
	var out := service.unsew("seamstress", KNOT, 13, NODE, done.state)
	_check(out.get("ok") == true and out.state.sockets["seamstress"][KNOT] == [11], "move then unsew works on the new binding")
	if out.get("ok") != true:
		return
	var resew := service.sew("warden", CATCH, 13, NODE, out.state)
	_check(resew.get("ok") == true and resew.state.sockets["warden"][CATCH] == [12, 13], "move then sew works on the released patch")
	if resew.get("ok") != true:
		return
	var left := service.leave(NODE, resew.state)
	_check(left.get("ok") == true and left.state.open == false, "visit leaves after a move")
	var closed := service.read_state()
	_refuse_move(service, rng, "move after leave", ["warden", CATCH, "seamstress", KNOT, 13], NODE, closed)
	_refuse_move(service, rng, "move after leave with a legal target", ["warden", CATCH, "tinker", TUNE, 12], NODE, closed)
	_check(service.read_state() == closed and closed.inventory == _inventory(), "closed visit unchanged by move refusals")
	# A visit that was never admitted refuses moves as well.
	var bad := RunStitchedSewingAbilityUnsew.new("", HEROES.duplicate(), _inventory(), _sockets())
	var bad_result := bad.move_sewn("warden", CATCH, "seamstress", KNOT, 13, NODE, bad.read_state())
	_check(bad_result.get("ok") == false, "move refused by an unadmitted service")


const SWAP_KEYS := ["ok", "error", "action", "node_id", "hero_a_id", "ability_a_id", "uid_a", "item_a", "hero_b_id",
	"ability_b_id", "uid_b", "item_b", "sockets_a_before", "sockets_a_after", "sockets_b_before", "sockets_b_after",
	"source_state", "state"]


func _refuse_swap(service: RunStitchedSewingAbilityUnsew, rng: RandomNumberGenerator, label: String, args: Array, node: Variant, expected: Variant) -> void:
	var state_before := service.read_state()
	var rng_before := rng.state
	var result := service.swap_sewn(args[0], args[1], args[2], args[3], args[4], args[5], node, expected)
	_check(result.get("ok") == false and not str(result.get("error", "")).is_empty(), label + " swap refused")
	_check(not result.has("action") and not result.has("source_state"), label + " swap refusal carries no success receipt")
	_check(service.read_state() == state_before, label + " swap preserves state")
	_check(rng.state == rng_before, label + " swap leaves RNG sentinel untouched")


func _swap_sewn_exchange() -> void:
	var service := _make()
	var before := service.read_state()
	_check(before.sockets["warden"][CATCH] == [13, 12] and before.sockets["seamstress"][KNOT] == [11], "swap AC1 fixture precondition")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	rng.randi()
	var rng_before := rng.state
	var receipt := service.swap_sewn("warden", CATCH, 12, "seamstress", KNOT, 11, NODE, before)
	_check(receipt.get("ok") == true and receipt.get("error") == "" and receipt.get("action") == "swap_sewn", "swap AC1 wool and cotton exchange succeeds")
	if receipt.get("ok") != true:
		return
	for key in SWAP_KEYS:
		_check(receipt.has(key), "swap AC1 receipt has " + key)
	_check(receipt.node_id == NODE and receipt.uid_a == 12 and receipt.uid_b == 11, "swap AC1 receipt names node and uids")
	_check(receipt.hero_a_id == "warden" and receipt.ability_a_id == CATCH and receipt.hero_b_id == "seamstress" and receipt.ability_b_id == KNOT, "swap AC1 receipt names both endpoints")
	_check(receipt.item_a == {"uid": 12, "id": MARK, "rarity": "wool"} and receipt.item_b == {"uid": 11, "id": LINT, "rarity": "cotton"}, "swap AC1 receipt carries both owned records")
	_check(receipt.sockets_a_before == [13, 12] and receipt.sockets_a_after == [13, 11], "swap AC1 receipt first before/after rows")
	_check(receipt.sockets_b_before == [11] and receipt.sockets_b_after == [12], "swap AC1 receipt second before/after rows")
	_check(receipt.source_state == before, "swap AC1 receipt source_state is the presented snapshot")
	var after: Dictionary = receipt.state
	_check(after.sockets["warden"][CATCH] == [13, 11] and after.sockets["seamstress"][KNOT] == [12], "swap AC1 Warden [13,11] and Seamstress [12]")
	_check(StitchedS14Abilities.valid_loadout("warden", {CATCH: [CHAIN, LINT]}) and StitchedS14Abilities.valid_loadout("seamstress", {KNOT: [MARK]}), "swap AC1 both results pass valid_loadout")
	_check(after.inventory == before.inventory and after.inventory == _inventory(), "swap AC1 every inventory record stays owned and unchanged")
	_check(int(after.version) == int(before.version) + 1, "swap AC1 version advances once")
	_check(after.open == true and after.node_id == before.node_id and after.hero_ids == before.hero_ids, "swap AC1 unrelated fields unchanged")
	_check(not after.sockets.has("tinker") and not after.sockets.has("lantern_monk"), "swap AC1 no other doll gains sockets")
	_check(_bound_anywhere(after, 11) == 1 and _bound_anywhere(after, 12) == 1 and _bound_anywhere(after, 13) == 1, "swap AC1 every uid is bound exactly once")
	_check(service.read_state() == after, "swap AC1 published state is authoritative")
	_check(rng.state == rng_before, "swap AC1 RNG sentinel untouched")
	for key in after:
		_check(not str(key).contains("scrap") and not str(key).contains("gold") and not str(key).contains("rng"), "swap AC1 no wallet or RNG key " + str(key))
	# Receipts are detached from held state and from earlier snapshots.
	var held := service.read_state()
	receipt.state.sockets["warden"][CATCH].append(999)
	receipt.source_state.sockets.clear()
	receipt.sockets_a_after.clear()
	receipt.sockets_b_before.append(5)
	receipt.item_a["id"] = "forged"
	_check(service.read_state() == held and before.sockets["warden"][CATCH] == [13, 12], "swap AC1 mutating receipts never aliases held or earlier state")
	# The exchange can be undone by swapping the same uids back.
	var back := service.swap_sewn("warden", CATCH, 11, "seamstress", KNOT, 12, NODE, held)
	_check(back.get("ok") == true and back.state.sockets["warden"][CATCH] == [13, 12] and back.state.sockets["seamstress"][KNOT] == [11], "swap AC1 swapping back restores the bindings")
	_check(back.get("ok") == true and int(back.state.version) == int(before.version) + 2, "swap AC1 second swap advances the version once more")
	# Identical fixtures replay identically.
	var twin := _make()
	var twin_receipt := twin.swap_sewn("warden", CATCH, 12, "seamstress", KNOT, 11, NODE, twin.read_state())
	_check(twin_receipt.get("ok") == true and twin_receipt.state == held, "swap AC1 identical fixtures replay to identical snapshots")
	# Endpoint order does not matter.
	var reversed := _make()
	var reversed_receipt := reversed.swap_sewn("seamstress", KNOT, 11, "warden", CATCH, 12, NODE, reversed.read_state())
	_check(reversed_receipt.get("ok") == true and reversed_receipt.state == held, "swap AC1 reversed endpoints give the same state")
	# Gold may travel to a signature when the other patch can legally take its place.
	var gold_service := _make()
	var gold_state := gold_service.read_state()
	var parked := gold_service.move_sewn("warden", CATCH, "warden", RIM, 12, NODE, gold_state)
	_check(parked.get("ok") == true, "swap AC1 same-doll fixture parks wool on Rim Toss")
	if parked.get("ok") != true:
		return
	var same_doll := gold_service.swap_sewn("warden", CATCH, 13, "warden", RIM, 12, NODE, parked.state)
	_check(same_doll.get("ok") == true and same_doll.state.sockets["warden"][CATCH] == [12] and same_doll.state.sockets["warden"][RIM] == [13], "swap AC1 same doll exchange validates the full loadout once")
	_check(same_doll.get("ok") == true and int(same_doll.state.version) == int(parked.state.version) + 1 and same_doll.state.inventory == _inventory(), "swap AC1 same doll one version step and inventory kept")
	# Order is preserved aside from the two swapped positions, also on the destination of a gold row.
	var order := _make()
	var gold_row := order.swap_sewn("warden", CATCH, 13, "seamstress", KNOT, 11, NODE, order.read_state())
	_check(gold_row.get("ok") == false, "swap AC1 gold away to a one-socket cotton row is refused")


func _swap_sewn_refusals() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	rng.randi()
	var state := service.read_state()
	# AC2: the gold patch leaving Warden would leave two non-gold patches in one socket.
	_refuse_swap(service, rng, "gold away", ["warden", CATCH, 13, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "gold away reversed", ["seamstress", KNOT, 11, "warden", CATCH, 13], NODE, state)
	# Same location or identical uid.
	_refuse_swap(service, rng, "one location twice", ["warden", CATCH, 13, "warden", CATCH, 12], NODE, state)
	_refuse_swap(service, rng, "identical uid on one location", ["warden", CATCH, 13, "warden", CATCH, 13], NODE, state)
	_refuse_swap(service, rng, "identical uid on two locations", ["warden", CATCH, 12, "seamstress", KNOT, 12], NODE, state)
	# Unknown, unowned, malformed or wrongly bound uids.
	_refuse_swap(service, rng, "unknown uid", ["warden", CATCH, 12, "seamstress", KNOT, 9999], NODE, state)
	_refuse_swap(service, rng, "unknown first uid", ["warden", CATCH, 9999, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "zero uid", ["warden", CATCH, 0, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "string uid", ["warden", CATCH, "12", "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "float uid", ["warden", CATCH, 12, "seamstress", KNOT, 11.0], NODE, state)
	_refuse_swap(service, rng, "null uid", ["warden", CATCH, 12, "seamstress", KNOT, null], NODE, state)
	_refuse_swap(service, rng, "uid bound on the other signature", ["warden", CATCH, 11, "seamstress", KNOT, 12], NODE, state)
	_refuse_swap(service, rng, "right doll wrong ability", ["warden", RIM, 12, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "second uid on the wrong ability", ["warden", CATCH, 12, "seamstress", "seamstress_head_made_up", 11], NODE, state)
	# Bad hero or ability.
	_refuse_swap(service, rng, "unknown hero", ["nobody", CATCH, 12, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "second unknown hero", ["warden", CATCH, 12, "nobody", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "hero outside the party", ["warden", CATCH, 12, "scarecrow", "scarecrow_head_straw_gaze", 11], NODE, state)
	_refuse_swap(service, rng, "unknown ability", ["warden", "warden_head_made_up", 12, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "ability of another hero", ["warden", CATCH, 12, "seamstress", CATCH, 11], NODE, state)
	_refuse_swap(service, rng, "non-string hero", [7, CATCH, 12, "seamstress", KNOT, 11], NODE, state)
	_refuse_swap(service, rng, "non-string ability", ["warden", CATCH, 12, "seamstress", 7, 11], NODE, state)
	# Snapshot gate.
	_refuse_swap(service, rng, "wrong node", ["warden", CATCH, 12, "seamstress", KNOT, 11], "other_node", state)
	_refuse_swap(service, rng, "non-string node", ["warden", CATCH, 12, "seamstress", KNOT, 11], 5, state)
	var stale := state.duplicate(true)
	stale["version"] = 99
	_refuse_swap(service, rng, "stale version", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, stale)
	var altered := state.duplicate(true)
	altered.sockets["warden"][CATCH] = [13]
	_refuse_swap(service, rng, "forged sockets", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, altered)
	var forged := state.duplicate(true)
	forged.inventory[0]["rarity"] = "gold"
	_refuse_swap(service, rng, "forged inventory", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, forged)
	_refuse_swap(service, rng, "non-dictionary state", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, "state")
	_refuse_swap(service, rng, "null state", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, null)
	_check(service.read_state() == state and state.inventory == _inventory(), "swap refusals left held state and inventory untouched")
	# A legal exchange is still available after every refused attempt.
	var eligible := service.swap_sewn("warden", CATCH, 12, "seamstress", KNOT, 11, NODE, service.read_state())
	_check(eligible.get("ok") == true and int(eligible.state.version) == int(state.version) + 1, "swap refusals consumed no eligible action")


func _swap_sewn_closed_and_replay() -> void:
	var service := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	rng.randi()
	var start := service.read_state()
	var done := service.swap_sewn("warden", CATCH, 12, "seamstress", KNOT, 11, NODE, start)
	_check(done.get("ok") == true, "swap replay fixture exchanges once")
	if done.get("ok") != true:
		return
	_refuse_swap(service, rng, "replay with the old snapshot", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, start)
	_refuse_swap(service, rng, "replay with the fresh snapshot", ["warden", CATCH, 12, "seamstress", KNOT, 11], NODE, done.state)
	# Existing operations still work after a swap.
	var out := service.unsew("seamstress", KNOT, 12, NODE, done.state)
	_check(out.get("ok") == true and out.state.sockets["seamstress"][KNOT] == [], "swap then unsew works on the new binding")
	if out.get("ok") != true:
		return
	var resew := service.sew("seamstress", KNOT, 12, NODE, out.state)
	_check(resew.get("ok") == true and resew.state.sockets["seamstress"][KNOT] == [12], "swap then sew works on the released patch")
	if resew.get("ok") != true:
		return
	var left := service.leave(NODE, resew.state)
	_check(left.get("ok") == true and left.state.open == false, "visit leaves after a swap")
	var closed := service.read_state()
	_refuse_swap(service, rng, "swap after leave", ["warden", CATCH, 11, "seamstress", KNOT, 12], NODE, closed)
	_check(service.read_state() == closed and closed.inventory == _inventory(), "closed visit unchanged by swap refusals")
	var bad := RunStitchedSewingAbilityUnsew.new("", HEROES.duplicate(), _inventory(), _sockets())
	var bad_result := bad.swap_sewn("warden", CATCH, 12, "seamstress", KNOT, 11, NODE, bad.read_state())
	_check(bad_result.get("ok") == false, "swap refused by an unadmitted service")
