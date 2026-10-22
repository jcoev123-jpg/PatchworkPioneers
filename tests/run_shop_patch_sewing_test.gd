extends SceneTree

var failures: Array[String] = []
var checks := 0
const IDS := ["stitched_badge", "spare_spool", "quilted_coat"]
const PARTY_IDS := ["warden", "seamstress", "tinker"]
const DECK := ["warden_strike", "seamstress_prick", "tinker_pop_shot"]


func _initialize() -> void:
	_test_paid_empty_slot_and_other_offer()
	_test_replacement()
	_test_coat_and_genuine_tear()
	_test_rejections()
	_test_seeded_replay()
	if failures.is_empty():
		print("run_shop_patch_sewing_test: PASS (", checks, " checks)")
	else:
		for failure in failures:
			printerr(failure)
		print("run_shop_patch_sewing_test: FAIL (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)


func _json(path: String) -> Variant:
	var content := FileAccess.get_file_as_string(path)
	_check(not content.is_empty(), "read genuine resource " + path)
	return JSON.parse_string(content)


func _authored() -> Dictionary:
	var offers: Variant = _json("res://data/shop/initial_offers.json")
	var starters: Variant = _json("res://data/heroes/starter_party.json")
	var heads: Variant = _json("res://data/patches/initial_patch_slots.json")
	var attacks: Variant = _json("res://data/patches/m04_attack_patches.json")
	var coats: Variant = _json("res://data/patches/m04_coat_patches.json")
	if not (offers is Dictionary) or not (starters is Array) 			or not (heads is Array) or not (attacks is Array) or not (coats is Array):
		_check(false, "all authored data parsed into expected containers")
		return {}
	var candidates := {}
	for entry in offers.trinkets:
		_check(entry is Dictionary and not candidates.has(entry.id), "unique actual shop candidate")
		candidates[entry.id] = entry.price
	for id in IDS:
		_check(candidates.get(id) == 100, "named patch has real 100-gold candidate " + id)
	_check(offers.cards.size() >= 5, "authored stock provides five priced cards")
	var defs: Array = []
	var slot_ids := {}
	for source in [heads, attacks, coats]:
		for entry in source:
			_check(entry is Dictionary and not slot_ids.has(entry.id), "authored patch ID distinct")
			slot_ids[entry.id] = entry.slot
			defs.append({"id": entry.id, "slot": entry.slot})
	_check(slot_ids.get("stitched_badge") == "HEAD" 		and slot_ids.get("spare_spool") == "ARM" 		and slot_ids.get("quilted_coat") == "COAT" 		and slot_ids.get("button_eye") == "HEAD" 		and slot_ids.get("pincushion_arm") == "ARM",
		"all five named real wardrobe slots kept")
	var quilted_entry: Dictionary = {}
	for entry in coats:
		if entry is Dictionary and entry.get("id") == "quilted_coat":
			quilted_entry = entry
			break
	_check(quilted_entry.get("max_hp_bonus") == 6,
		"actual quilted coat grants only authored +6")
	var hp := {"warden": 40, "seamstress": 30, "tinker": 26}
	_check(starters.size() == 3, "three real starter heroes")
	for i in range(mini(3, starters.size())):
		_check(starters[i].get("id") == PARTY_IDS[i] 			and starters[i].get("max_hp") == hp[PARTY_IDS[i]],
			"authored named starting hero and max HP " + str(i))
	return {"offers": offers, "starters": starters, "definitions": defs, "coats": coats}


func _fixture(patch: String, gold: int = 200,
		button_eye: bool = false, requested_seed: int = 0) -> Dictionary:
	var data := _authored()
	if data.is_empty():
		return {}
	var owned: Array = ["button_eye"] if button_eye else []
	var chosen := {}
	var chosen_seed := requested_seed
	var rng := RandomNumberGenerator.new()
	# Search deterministic local seeds, not the global stream; only actual
	# RunShopStockOffers.generate may decide the two offered trinkets.
	for candidate_seed in range(1, 65):
		var try_seed: int = requested_seed if requested_seed > 0 else candidate_seed
		rng.seed = try_seed
		chosen = RunShopStockOffers.generate(rng, PARTY_IDS,
			data.offers.cards, data.offers.trinkets, owned)
		if chosen.get("ok") != true:
			break
		var ids := []
		for offer in chosen.trinkets:
			ids.append(offer.id)
		if ids.has(patch):
			chosen_seed = try_seed
			break
		if requested_seed > 0:
			break
		chosen = {}
	_check(chosen.get("ok") == true and chosen.trinkets.size() == 2
		and chosen.cards.size() == 5, "seeded real five-card/two-trinket shop built for " + patch)
	if chosen.get("ok") != true:
		return {}
	var offered_ids := []
	for entry in chosen.trinkets:
		offered_ids.append(entry.id)
	_check(offered_ids.has(patch), "selected patch actually stocked: " + patch)
	if not offered_ids.has(patch):
		return {}
	_check(IDS.has(offered_ids[0]) and IDS.has(offered_ids[1])
		and offered_ids[0] != offered_ids[1], "two distinct authored trinkets offered")
	var party_defs: Array = data.starters.duplicate(true)
	for entry in party_defs:
		entry["max_hp"] = int(entry["max_hp"])
	var party := CombatParty.new(party_defs)
	_check(party.is_valid(), "real CombatParty built from starter JSON")
	if not party.is_valid():
		return {}
	var heroes: Array = party.get_heroes()
	var torn := RunTornMending.new(heroes)
	var purchase := RunShopPurchases.new(PARTY_IDS, DECK, owned, gold,
		chosen.cards, chosen.trinkets)
	var deck: Array[String] = []
	deck.assign(DECK)
	var owned_typed: Array[String] = []
	owned_typed.assign(owned)
	var visit := RunShopVisit.new(deck, gold, 0, owned_typed)
	var opened := visit.open_visit("confirmed-shop")
	var wardrobe := RunPatchWardrobe.new(heroes, owned, data.definitions, 0,
		gold, DECK, chosen_seed, true)
	_check(torn.is_valid() and purchase.is_valid() and opened
		and wardrobe.is_valid(), "all four genuine ledger services initialized")
	if not (torn.is_valid() and purchase.is_valid() and opened and wardrobe.is_valid()):
		return {}
	if button_eye:
		var prior := wardrobe.sew("button_eye", "warden", "HEAD",
			"prior-eye", wardrobe.get_snapshot())
		_check(prior.ok and prior.receipt.scrap_delta == 0,
			"actual earlier Button Eye sewn using wardrobe")
	return {"shop": purchase, "visit": visit, "wardrobe": wardrobe,
		"torn": torn, "party": party, "rng": rng, "offers": chosen,
		"seed": chosen_seed, "coats": data.coats, "patch": patch}


func _act(f: Dictionary, patch: String, hero: String,
		slot: String, op: String, expected: Dictionary = {}) -> Dictionary:
	var p: RunShopPurchases = f.shop
	var v: RunShopVisit = f.visit
	var w: RunPatchWardrobe = f.wardrobe
	return RunShopPatchSewing.purchase_and_sew(p, v, w,
		expected.get("node", "confirmed-shop"), patch, hero, slot, op,
		expected.get("purchase", p.get_state()),
		expected.get("stock", p.get_stock()),
		expected.get("visit", v.get_state()),
		expected.get("wardrobe", w.get_snapshot()))


func _snapshot(f: Dictionary) -> Dictionary:
	return {"purchase": f.shop.get_state(), "stock": f.shop.get_stock(),
		"visit": f.visit.get_state(), "wardrobe": f.wardrobe.get_snapshot(),
		"torn": f.torn.read_state(), "actors": f.party.get_heroes(),
		"rng": f.rng.state}


func _deny(f: Dictionary, label: String, patch: String, hero: String,
		slot: String, op: String, overrides: Dictionary = {}) -> void:
	var before := _snapshot(f)
	var result := _act(f, patch, hero, slot, op, overrides)
	_check(result == {"ok": false}, label + " returns receipt-free rejection")
	_check(_snapshot(f) == before, label + " preserves all ledgers, actors, history and run RNG")
	_check(before.wardrobe.operation_ids == _snapshot(f).wardrobe.operation_ids,
		label + " rejection preserves operation claim history")


func _assert_coherent(f: Dictionary, bought: Dictionary, patch: String,
		wearer: String, slot: String, op: String, prior: Dictionary) -> void:
	var after := _snapshot(f)
	_check(bought.get("ok") == true and bought.has("purchase_receipt")
		and bought.has("sew_receipt"), "paid and free sew both return genuine receipts")
	if not bought.get("ok"):
		return
	_check(bought.purchase_receipt == {"kind": "trinket", "id": patch, "price": 100},
		"actual full paid receipt is trinket/patch/100")
	_check(bought.sew_receipt.operation_id == op
		and bought.sew_receipt.kind == "sew"
		and bought.sew_receipt.patch_id == patch
		and bought.sew_receipt.hero_id == wearer
		and bought.sew_receipt.slot == slot,
		"wardrobe's real sew receipt identifies action and wearer")
	_check(after.purchase.gold == prior.purchase.gold - 100
		and after.visit.gold == after.purchase.gold
		and after.wardrobe.gold == after.purchase.gold,
		"all three ledgers debit exactly once; free sewing is free")
	_check(after.purchase.deck == prior.purchase.deck
		and after.visit.deck == prior.visit.deck
		and after.wardrobe.cards == prior.wardrobe.cards
		and after.visit.prior_removals == prior.visit.prior_removals,
		"purchase changes no deck or removal count")
	_check(after.torn == prior.torn and after.actors == prior.actors
		and after.wardrobe.heroes == prior.wardrobe.heroes,
		"no hero HP, max HP, block, status or position mutation")
	_check(after.rng == prior.rng, "purchase/visit/sew use zero extra run RNG draws")
	_check(after.purchase.trinkets == after.visit.trinkets
		and after.wardrobe.owned == after.purchase.trinkets,
		"all paid and wardrobe inventories reconciled without duplication")
	_check(after.purchase.trinkets.count(patch) == 1
		and after.wardrobe.worn[wearer][slot] == patch,
		"bought patch owned once and sewn in declared slot")
	var sold := 0
	for listing in after.stock.trinkets:
		if listing.id == patch and listing.sold:
			sold += 1
	_check(sold == 1, "precisely one matching offered listing sold")
	_check(bought.purchase_state == after.purchase and bought.purchase_stock == after.stock
		and bought.visit_state == after.visit and bought.wardrobe_state == after.wardrobe,
		"detached response contains four exact committed snapshots")


func _test_paid_empty_slot_and_other_offer() -> void:
	_check(RunShopPatchSewing.new().has_method("purchase_and_sew"),
		"required coordinator public entry point exists")
	for pair in [["stitched_badge", "warden", "HEAD"],
			["spare_spool", "tinker", "ARM"]]:
		var f := _fixture(pair[0])
		if f.is_empty():
			continue
		var before := _snapshot(f)
		var result := _act(f, pair[0], pair[1], pair[2], "buy-" + pair[0])
		_assert_coherent(f, result, pair[0], pair[1], pair[2],
			"buy-" + pair[0], before)
		var after := _snapshot(f)
		_check(result.sew_receipt.displaced_id == ""
			and result.sew_receipt.scrap_delta == 0
			and after.wardrobe.scraps == 0
			and after.wardrobe.operation_ids == ["buy-" + pair[0]],
			"empty slot keeps zero scraps and records one operation")
		_check(after.visit.status == "available"
			and after.visit.shop_node_id == "confirmed-shop",
			"actual Shop visit remains open after purchase")
		_deny(f, "repeat paid purchase", pair[0], pair[1], pair[2], "second-attempt")
		_check(not f.shop.buy("trinket", pair[0]).ok,
			"underlying sold purchase cannot replay")
		_check(_snapshot(f) == after, "sold underlying buy remains unchanged")
		# A returned snapshot or receipt must not alias an underlying model.
		result.wardrobe_state.worn[pair[1]][pair[2]] = "forged"
		result.purchase_receipt.id = "forged"
		_check(_snapshot(f) == after, "nested returned state and receipt are detached")


func _test_replacement() -> void:
	var f := _fixture("stitched_badge", 200, true)
	if f.is_empty():
		return
	var prior := _snapshot(f)
	_check(prior.wardrobe.worn.warden.HEAD == "button_eye"
		and prior.wardrobe.owned == ["button_eye"] and prior.wardrobe.scraps == 0
		and prior.wardrobe.operation_ids == ["prior-eye"],
		"replacement starts with authentic worn Button Eye and original operation")
	var result := _act(f, "stitched_badge", "warden", "HEAD", "replace-head")
	_assert_coherent(f, result, "stitched_badge", "warden", "HEAD", "replace-head", prior)
	var after := _snapshot(f)
	_check(result.sew_receipt.displaced_id == "button_eye"
		and result.sew_receipt.scrap_delta == 1
		and after.wardrobe.scraps == 1
		and after.wardrobe.owned == ["stitched_badge"]
		and after.wardrobe.operation_ids == ["prior-eye", "replace-head"],
		"only displaced owned Button Eye destroyed for exactly one scrap")
	for hero in PARTY_IDS:
		for slot in ["HEAD", "ARM", "COAT"]:
			if hero == "warden" and slot == "HEAD":
				continue
			_check(after.wardrobe.worn[hero][slot] == prior.wardrobe.worn[hero][slot],
				"replacement keeps all other hero and slot assignments " + hero + slot)
	_check(after.rng == prior.rng and after.torn == prior.torn
		and after.actors == prior.actors, "replacement touches neither actors nor RNG")
	_check(not f.shop.settle_displaced_patch("button_eye", "stitched_badge",
		f.shop.get_state()) and not f.visit.settle_displaced_patch(
		"button_eye", "stitched_badge", f.visit.get_state())
		and _snapshot(f) == after,
		"old patch cannot be disposed twice by either supporting ledger")
	# A second different offered purchase must still reconcile against the
	# post-replacement inventory, rather than resurrecting the old patch.
	var other := ""
	for listing in f.shop.get_stock().trinkets:
		if listing.id != "stitched_badge":
			other = listing.id
	_check(other != "" and IDS.has(other), "second actual offered patch exists")
	var other_slot: String = {"spare_spool": "ARM", "quilted_coat": "COAT"}.get(other, "")
	var second := _act(f, other, "tinker", other_slot, "second-paid")
	_check(second.ok and second.purchase_receipt.price == 100
		and f.shop.get_state().gold == 0 and f.visit.get_state().gold == 0
		and f.wardrobe.get_snapshot().gold == 0,
		"later valid Shop action pays only its own second 100 gold")
	_check(f.shop.get_state().trinkets == f.visit.get_state().trinkets
		and f.shop.get_state().trinkets == f.wardrobe.get_snapshot().owned
		and not f.shop.get_state().trinkets.has("button_eye"),
		"subsequent paid action preserves all three post-replacement inventories")


func _test_coat_and_genuine_tear() -> void:
	var f := _fixture("quilted_coat")
	if f.is_empty():
		return
	var before := _snapshot(f)
	var result := _act(f, "quilted_coat", "seamstress", "COAT", "buy-coat")
	_assert_coherent(f, result, "quilted_coat", "seamstress", "COAT", "buy-coat", before)
	_check(result.sew_receipt.scrap_delta == 0 and f.wardrobe.get_snapshot().scraps == 0,
		"empty coat slot never mints scrap")
	var t: RunTornMending = f.torn
	var w: RunPatchWardrobe = f.wardrobe
	var living := RunPatchCoatRules.project_health(t.read_state(), w, f.coats)
	_check(living.ok and living.heroes[0].max_hp == 40
		and living.heroes[1].max_hp == 36 and living.heroes[1].hp == 30
		and living.heroes[2].max_hp == 26, "only living Seamstress projects +6, no heal")
	_check(RunPatchCoatRules.project_health(t.read_state(), w, f.coats) == living,
		"repeated projection does not stack bonus")
	var start: Array = t.read_state().heroes
	var end: Array = start.duplicate(true)
	end[1].hp = 0
	_check(t.observe_battle_end("real-fight", start, end).ok,
		"genuine battle result tears coat wearer")
	_check(not RunPatchCoatRules.project_health(t.read_state(), w, f.coats).ok,
		"stale wardrobe context fails closed before torn projection")
	var held := w.get_snapshot()
	_check(w.refresh_run_context(t.read_state().heroes, held.owned, held.scraps,
		held.gold, held.cards, held), "refresh genuine torn roster after battle")
	var torn_active := w.project_active(t.read_state())
	var torn_projection := RunPatchCoatRules.project_health(t.read_state(), w, f.coats)
	_check(torn_active.ok and torn_active.worn.seamstress.COAT == "quilted_coat"
		and torn_active.active.seamstress == []
		and torn_projection.ok and torn_projection.heroes[1].max_hp == 27
		and torn_projection.heroes[1].hp == 0,
		"torn Seamstress retains inactive assignment and base tear cap")
	_check(t.apply_rest("real-rest", t.read_state().heroes, true).ok,
		"genuine Rest revives wearer")
	held = w.get_snapshot()
	_check(w.refresh_run_context(t.read_state().heroes, held.owned, held.scraps,
		held.gold, held.cards, held), "refresh Rest revived roster")
	var revival := RunPatchCoatRules.project_health(t.read_state(), w, f.coats)
	_check(revival.ok and revival.heroes[1].max_hp == 33
		and revival.heroes[1].hp == t.read_state().heroes[1].hp
		and t.read_state().heroes[1].max_hp == 27
		and w.project_active(t.read_state()).active.seamstress == ["quilted_coat"],
		"Rest reactivates +6 without mutating base cap or healing by sewing")
	_check(w.get_snapshot().scraps == 0 and w.get_snapshot().gold == 100
		and w.get_snapshot().operation_ids == ["buy-coat"],
		"tear and Rest do not charge sewing or create operations")


func _test_rejections() -> void:
	seed(476109)
	var expected_global := randi()
	seed(476109)
	var f := _fixture("stitched_badge")
	if f.is_empty():
		return
	var offered := []
	for item in f.offers.trinkets:
		offered.append(item.id)
	var absent := ""
	for patch in IDS:
		if not offered.has(patch):
			absent = patch
	_check(absent != "" and IDS.has(absent), "genuine three-candidate Shop leaves a third offer absent")
	_deny(f, "unstocked real candidate", absent, "warden",
		{"stitched_badge": "HEAD", "spare_spool": "ARM", "quilted_coat": "COAT"}[absent], "retry",
		{"node": "confirmed-shop"})
	_deny(f, "wrong authored slot", "stitched_badge", "warden", "ARM", "retry")
	_deny(f, "foreign wearer", "stitched_badge", "outsider", "HEAD", "retry")
	_deny(f, "wrong Shop node", "stitched_badge", "warden", "HEAD", "retry",
		{"node": "foreign-shop"})
	var forged_purchase: Dictionary = f.shop.get_state()
	forged_purchase.gold += 1
	_deny(f, "forged purchase snapshot", "stitched_badge", "warden", "HEAD", "retry",
		{"purchase": forged_purchase})
	var forged_stock: Dictionary = f.shop.get_stock()
	forged_stock.trinkets[0].price += 1
	_deny(f, "forged offer/price snapshot", "stitched_badge", "warden", "HEAD", "retry",
		{"stock": forged_stock})
	var forged_visit: Dictionary = f.visit.get_state()
	forged_visit.gold -= 1
	_deny(f, "forged visit receipt context", "stitched_badge", "warden", "HEAD", "retry",
		{"visit": forged_visit})
	var forged_wardrobe: Dictionary = f.wardrobe.get_snapshot()
	forged_wardrobe.receipt = "old-or-forged"
	_deny(f, "stale wardrobe receipt", "stitched_badge", "warden", "HEAD", "retry",
		{"wardrobe": forged_wardrobe})
	_check(_act(f, "stitched_badge", "warden", "HEAD", "retry").ok,
		"single original ID remains usable after every rejected proposal")
	var committed := _snapshot(f)
	_deny(f, "already bought/owned and sold", "stitched_badge", "warden", "HEAD",
		"not-claimed")
	_check(_snapshot(f) == committed, "sold attempt does not add scrap or purchase")
	# Reusing a previously sewn operation ID must fail *before* buying stock.
	var reuse := _fixture("stitched_badge", 200, true)
	if not reuse.is_empty():
		_deny(reuse, "used wardrobe operation ID", "stitched_badge", "warden",
			"HEAD", "prior-eye")
		_check(_act(reuse, "stitched_badge", "warden", "HEAD", "fresh-eye").ok,
			"same paid proposal succeeds with a genuinely fresh operation ID")
	var poor := _fixture("stitched_badge", 99)
	if not poor.is_empty():
		_deny(poor, "insufficient actual 100 gold", "stitched_badge",
			"warden", "HEAD", "funds-retry")
		var funded := _fixture("stitched_badge", 200, false, poor.seed)
		_check(not funded.is_empty() and _act(funded, "stitched_badge",
			"warden", "HEAD", "funds-retry").ok,
			"rejected insufficient-funds operation ID still usable once funded")
	var closed := _fixture("stitched_badge")
	if not closed.is_empty():
		_check(closed.visit.close_visit(), "real Shop visit closed before proposal")
		_deny(closed, "closed confirmed Shop", "stitched_badge",
			"warden", "HEAD", "closed-retry")
		var reopen := _fixture("stitched_badge", 200, false, closed.seed)
		_check(_act(reopen, "stitched_badge", "warden", "HEAD",
			"closed-retry").ok, "fresh open Shop accepts previously rejected ID")
	var drift := _fixture("stitched_badge")
	if not drift.is_empty():
		_check(drift.shop.buy("card", drift.offers.cards[0].id).ok,
			"actual distinct card purchase diverges from visit and wardrobe")
		_deny(drift, "purchase vs visit/deck/gold mismatch",
			"stitched_badge", "warden", "HEAD", "drift-retry")
		var aligned := _fixture("stitched_badge", 200, false, drift.seed)
		_check(_act(aligned, "stitched_badge", "warden",
			"HEAD", "drift-retry").ok, "aligned complete ledgers accept rejected ID")
	var wardrobe_drift := _fixture("stitched_badge")
	if not wardrobe_drift.is_empty():
		var w: RunPatchWardrobe = wardrobe_drift.wardrobe
		var old := w.get_snapshot()
		_check(w.refresh_run_context(old.heroes, old.owned, old.scraps, 199,
			old.cards, old), "genuine wardrobe held gold can differ")
		_deny(wardrobe_drift, "wardrobe-vs-purchase gold mismatch",
			"stitched_badge", "warden", "HEAD", "wardrobe-retry")
		var reset := _fixture("stitched_badge", 200, false, wardrobe_drift.seed)
		_check(_act(reset, "stitched_badge", "warden",
			"HEAD", "wardrobe-retry").ok, "corrected wardrobe accepts rejected ID")
	_check(randi() == expected_global,
		"all coordinator paths preserve the same global RNG stream")


func _test_seeded_replay() -> void:
	var a := _fixture("quilted_coat")
	if a.is_empty():
		return
	var b := _fixture("quilted_coat", 200, false, a.seed)
	if b.is_empty():
		return
	_check(a.offers == b.offers and a.rng.state == b.rng.state,
		"two independent same-seed real stock choices and RNG states match")
	var first := _act(a, "quilted_coat", "tinker", "COAT", "same-choice")
	var second := _act(b, "quilted_coat", "tinker", "COAT", "same-choice")
	_check(first.ok and second.ok and first == second,
		"two independent complete paid purchase/sew receipts and snapshots replay")
	_check(_snapshot(a) == _snapshot(b),
		"all run ledgers, heroes, stock, scraps, history and RNG replay exactly")
