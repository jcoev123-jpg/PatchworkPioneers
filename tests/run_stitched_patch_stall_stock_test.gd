extends SceneTree
## Card-free Stitched Patch Stall sampler: deterministic three-offer stock from the
## Stitched-only patch source, driven through the real four-hero visit service.

const SOURCE := "res://data/shop/stitched_patch_offers.json"
const COAT_SOURCE := "res://data/patches/m04_coat_patches.json"
const COATS := {
	"quilted_coat": 6, "padded_vest": 4, "double_quilt_coat": 8, "scrap_lined_vest": 3,
	"wool_patch_cloak": 5, "chain_stitched_coat": 7, "reinforced_patchcoat": 9,
	"thick_felt_mantle": 10,
}
## Authored Stitched catalog quotes ordered by HP bonus: scrap vest 35, Padded Vest 75, Wool Patch Cloak 85,
## Quilted Coat 90, Chain-Stitched Coat 95, Double Quilt Coat 100, Patchcoat 105, Felt Mantle 110.
const EXPECTED_PRICE := {
	"quilted_coat": 90, "padded_vest": 75, "double_quilt_coat": 100, "scrap_lined_vest": 35,
	"wool_patch_cloak": 85, "chain_stitched_coat": 95, "reinforced_patchcoat": 105,
	"thick_felt_mantle": 110,
}
const PARTY := ["warden", "seamstress", "tinker", "yarn_ranger"]
const NODE := "patch_stall_node"

var _checks := 0
var _failures := []


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("run_stitched_patch_stall_stock_test: PASS (", _checks, " checks)")
		quit(0)
	else:
		for f in _failures:
			printerr("FAIL: ", f)
		print("run_stitched_patch_stall_stock_test: FAIL (", _checks, " checks)")
		quit(1)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _source_prices() -> Dictionary:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var prices := {}
	if document is Dictionary and document.get("trinkets") is Array:
		for item in document.trinkets:
			prices[item.id] = int(item.price)
	return prices


func _foreign_ids() -> Dictionary:
	# Card-era / rare / Heirloom / starter identities that must never be stocked.
	var blocked := {"stitched_badge": true, "spare_spool": true}
	for id in RunAuthoredPatchDefinitions.HEIRLOOM_IDS:
		blocked[id] = true
	for path in ["res://data/patches/mpw_synergy_patches.json",
			"res://data/patches/mpw_heirloom_patches.json",
			"res://data/patches/initial_patch_slots.json"]:
		var records: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if records is Array:
			for record in records:
				if record is Dictionary and record.get("id") is String:
					blocked[record.id] = true
	return blocked


func _others(excluded: Array) -> Array:
	var owned: Array = []
	var ids: Array = COATS.keys()
	ids.sort()
	for id in ids:
		if not excluded.has(id):
			owned.append(id)
	return owned


func _ids(offers: Array) -> Array:
	var ids: Array = []
	for offer in offers:
		ids.append(offer.id)
	return ids


func _run() -> void:
	var prices := _source_prices()
	var coat_records: Variant = JSON.parse_string(FileAccess.get_file_as_string(COAT_SOURCE))
	_check(coat_records is Array and not coat_records.is_empty(), "coat power source loads")
	var coat_slots := {}
	if coat_records is Array:
		for record in coat_records:
			coat_slots[record.id] = record.slot
	for id in COATS:
		_check(prices.has(id) and prices[id] == EXPECTED_PRICE[id],
			"named coat %s is authored at %d gold" % [id, EXPECTED_PRICE[id]])
		_check(coat_slots.get(id) == "COAT", "named coat %s is a COAT power" % id)
	_check(not prices.is_empty(), "Stitched patch source is non-empty")

	_check_membership_and_determinism(prices)
	_check_every_coat_eligible()
	_check_padded_vest_price()
	_check_scrap_vest_price()
	_check_wool_cloak_price()
	_check_mantle_price()
	_check_patchcoat_price()
	_check_scarce(["scrap_lined_vest"], "one")
	_check_scarce(["thick_felt_mantle", "padded_vest"], "two")
	_check_all_owned()
	_check_bad_inputs()
	_check_visit_failures()


## Padded Vest at its 75-gold quote: seeded witness stock, exact-gold buy, 74 refused, owned SOLD.
func _check_padded_vest_price() -> void:
	var prices := _source_prices()
	for id in EXPECTED_PRICE:
		_check(prices.get(id, -1) == EXPECTED_PRICE[id], "per-ID price unchanged/authored: " + id)
	_check(prices.get("padded_vest", -1) == 75, "padded_vest source row is exactly 75 gold")
	var witness_seed := -1
	var witness: Array = []
	for seed_value in range(1, 200):
		var probe := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(seed_value), [])
		if probe.get("ok") == true and _ids(probe.offers).has("padded_vest"):
			witness_seed = seed_value
			witness = probe.offers
			break
	_check(witness_seed > 0 and witness.size() == 3, "a deterministic seed stocks padded_vest")
	if witness_seed < 0:
		return
	_check(_ids(witness).count("padded_vest") == 1, "padded_vest is not duplicated in stock")
	for offer in witness:
		if offer.id == "padded_vest":
			_check(offer == {"id": "padded_vest", "price": 75}, "stocked padded_vest row quotes 75 gold")
	var again := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(witness_seed), [])
	_check(again.get("offers") == witness, "witness seed replays the same stock")

	var rich := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 75, witness)
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 74, witness)
	_check(rich.is_valid() and poor.is_valid(), "75-gold and 74-gold visits open")
	if not rich.is_valid() or not poor.is_valid():
		return
	for row in rich.quote().offers:
		if row.id == "padded_vest":
			_check(row.price == 75 and row.can_buy == true and row.sold == false,
				"padded_vest is buyable at 75 gold")
	for row in poor.quote().offers:
		if row.id == "padded_vest":
			_check(row.price == 75 and row.can_buy == false, "padded_vest is not buyable at 74 gold")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.buy_patch("padded_vest", poor_state.visit_id, poor_state.node_id, poor_state.snapshot).get("ok") != true
		and poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"74 gold cannot buy padded_vest and nothing is debited or granted")
	var state := rich.read_state()
	var bought := rich.buy_patch("padded_vest", state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true and bought.receipt == {"kind": "trinket", "id": "padded_vest", "price": 75}
		and bought.ledger.gold == 0 and bought.ledger.owned_patch_ids == ["padded_vest"],
		"75 gold buys padded_vest once for exactly 75")
	_check(rich.is_consumed() and rich.buy_patch("padded_vest", state.visit_id, state.node_id,
		state.snapshot).get("ok") != true, "replayed padded_vest buy refused")
	# Already owned: SOLD and disabled, no debit.
	var owned_visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), ["padded_vest"], 200, witness)
	_check(owned_visit.is_valid(), "owned-vest visit opens")
	if owned_visit.is_valid():
		var o_state := owned_visit.read_state()
		var found := false
		for row in owned_visit.quote().offers:
			if row.id == "padded_vest":
				found = true
				_check(row.sold == true and row.can_buy == false, "owned padded_vest is SOLD and disabled")
		_check(found, "owned padded_vest row remains visible as SOLD")
		_check(owned_visit.buy_patch("padded_vest", o_state.visit_id, o_state.node_id,
			o_state.snapshot).get("ok") != true and owned_visit.read_state() == o_state,
			"owned padded_vest cannot be bought again")


## Scrap-Lined Vest at its 35-gold quote: seeded witness stock, exact-gold buy, 34 refused, owned SOLD.
func _check_scrap_vest_price() -> void:
	var prices := _source_prices()
	_check(prices.get("scrap_lined_vest", -1) == 35, "scrap_lined_vest source row is exactly 35 gold")
	_check(prices.get("quilted_coat", -1) == 90 and prices.get("padded_vest", -1) == 75
		and prices.get("double_quilt_coat", -1) == 100 and prices.get("wool_patch_cloak", -1) == 85
		and prices.get("chain_stitched_coat", -1) == 95 and prices.get("reinforced_patchcoat", -1) == 105
		and prices.get("thick_felt_mantle", -1) == 110, "the other seven coat prices stay authored")
	var witness_seed := -1
	var witness: Array = []
	for seed_value in range(1, 300):
		var probe := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(seed_value), [])
		if probe.get("ok") == true and _ids(probe.offers).has("scrap_lined_vest"):
			witness_seed = seed_value
			witness = probe.offers
			break
	_check(witness_seed > 0 and witness.size() == 3, "a deterministic seed stocks scrap_lined_vest")
	if witness_seed < 0:
		return
	var distinct := {}
	for id in _ids(witness):
		distinct[id] = true
	_check(_ids(witness).count("scrap_lined_vest") == 1 and distinct.size() == 3
		and witness.has({"id": "scrap_lined_vest", "price": 35}),
		"scrap vest is stocked once as the 35-gold row among three distinct offers")
	_check(RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(witness_seed), []).get("offers") == witness,
		"scrap vest witness seed replays the same stock")

	var rich := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 35, witness)
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 34, witness)
	_check(rich.is_valid() and poor.is_valid(), "35-gold and 34-gold scrap vest visits open")
	if not rich.is_valid() or not poor.is_valid():
		return
	var rich_seen := false
	for row in rich.quote().offers:
		if row.id == "scrap_lined_vest":
			rich_seen = true
			_check(row.price == 35 and row.can_buy == true and row.sold == false,
				"scrap vest is buyable at 35 gold")
	_check(rich_seen, "35-gold quote shows the scrap vest row")
	var poor_seen := false
	for row in poor.quote().offers:
		if row.id == "scrap_lined_vest":
			poor_seen = true
			_check(row.price == 35 and row.can_buy == false, "scrap vest is not buyable at 34 gold")
	_check(poor_seen, "34-gold quote shows the scrap vest row")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.buy_patch("scrap_lined_vest", poor_state.visit_id, poor_state.node_id,
		poor_state.snapshot).get("ok") != true
		and poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"34 gold cannot buy the scrap vest and nothing is debited or granted")
	var left := poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(left.get("ok") == true and left.ledger.gold == 34 and left.ledger.owned_patch_ids == [],
		"refused 34-gold buy keeps the chance to Leave with wallet intact")
	var state := rich.read_state()
	var bought := rich.buy_patch("scrap_lined_vest", state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true
		and bought.receipt == {"kind": "trinket", "id": "scrap_lined_vest", "price": 35}
		and bought.ledger.gold == 0 and bought.ledger.owned_patch_ids == ["scrap_lined_vest"],
		"35 gold buys the scrap vest once for exactly 35 and leaves 0 gold")
	_check(rich.is_consumed() and rich.buy_patch("scrap_lined_vest", state.visit_id, state.node_id,
		state.snapshot).get("ok") != true, "replayed scrap vest buy refused")
	var owned_visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), ["scrap_lined_vest"], 200, witness)
	_check(owned_visit.is_valid(), "owned-scrap-vest visit opens")
	if owned_visit.is_valid():
		var o_state := owned_visit.read_state()
		var found := false
		for row in owned_visit.quote().offers:
			if row.id == "scrap_lined_vest":
				found = true
				_check(row.sold == true and row.can_buy == false, "owned scrap vest is SOLD and disabled")
		_check(found, "owned scrap vest row remains visible as SOLD")
		_check(owned_visit.buy_patch("scrap_lined_vest", o_state.visit_id, o_state.node_id,
			o_state.snapshot).get("ok") != true and owned_visit.read_state() == o_state,
			"owned scrap vest cannot be bought again")


## Wool Patch Cloak at its 85-gold quote: sole-unowned seeded stock, exact-gold buy, 84 refused, replay.
func _check_wool_cloak_price() -> void:
	var prices := _source_prices()
	_check(prices.get("wool_patch_cloak", -1) == 85, "wool_patch_cloak source row is exactly 85 gold")
	_check(prices.get("quilted_coat", -1) == 90 and prices.get("chain_stitched_coat", -1) == 95
		and prices.get("padded_vest", -1) == 75 and prices.get("double_quilt_coat", -1) == 100
		and prices.get("thick_felt_mantle", -1) == 110, "neighbouring coat prices stay authored")
	_check(prices.get("wool_patch_cloak", -1) < prices.get("quilted_coat", -1)
		and prices.get("quilted_coat", -1) < prices.get("chain_stitched_coat", -1)
		and prices.get("chain_stitched_coat", -1) < prices.get("double_quilt_coat", -1),
		"+5, +6, +7 and +8 coats climb in price")
	var owned := _others(["wool_patch_cloak"])
	var owned_snapshot := owned.duplicate(true)
	var stock := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(31), owned)
	_check(stock.get("ok") == true and stock.get("offers") is Array and stock.offers.size() == 3,
		"sole-unowned wool cloak stock samples three rows")
	if stock.get("ok") != true:
		return
	var offers: Array = stock.offers
	_check(_ids(offers).count("wool_patch_cloak") == 1
		and offers.has({"id": "wool_patch_cloak", "price": 85}),
		"stock includes wool_patch_cloak at 85 gold exactly once")
	var again := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(31), owned.duplicate(true))
	_check(again == stock, "wool cloak stock replays identically for the same seed and input")
	_check(owned == owned_snapshot, "wool cloak fixture owned list is not mutated")

	var rich := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 85, offers)
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 84, offers)
	_check(rich.is_valid() and poor.is_valid(), "85-gold and 84-gold wool cloak visits open")
	if not rich.is_valid() or not poor.is_valid():
		return
	var rich_row_seen := false
	for row in rich.quote().offers:
		if row.id == "wool_patch_cloak":
			rich_row_seen = true
			_check(row.price == 85 and row.can_buy == true and row.sold == false,
				"wool cloak is buyable at 85 gold")
	_check(rich_row_seen, "85-gold quote shows the wool cloak row")
	var poor_row_seen := false
	for row in poor.quote().offers:
		if row.id == "wool_patch_cloak":
			poor_row_seen = true
			_check(row.price == 85 and row.can_buy == false, "wool cloak is not buyable at 84 gold")
	_check(poor_row_seen, "84-gold quote shows the wool cloak row")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.buy_patch("wool_patch_cloak", poor_state.visit_id, poor_state.node_id,
		poor_state.snapshot).get("ok") != true
		and poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"84 gold cannot buy wool cloak and nothing is debited or granted")
	var left := poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(left.get("ok") == true and left.ledger.gold == 84,
		"refused 84-gold buy keeps the chance to Leave")

	var state := rich.read_state()
	var bought := rich.buy_patch("wool_patch_cloak", state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true
		and bought.receipt == {"kind": "trinket", "id": "wool_patch_cloak", "price": 85}
		and bought.ledger.gold == 0
		and bought.ledger.owned_patch_ids.count("wool_patch_cloak") == 1,
		"85 gold buys wool cloak once for exactly 85 and leaves 0 gold")
	_check(rich.is_consumed() and rich.buy_patch("wool_patch_cloak", state.visit_id, state.node_id,
		state.snapshot).get("ok") != true, "replayed wool cloak buy refused")
	_check(owned == owned_snapshot, "wool cloak visit left caller's owned IDs untouched")

	# Normal three-unowned stock: a seed that offers the cloak quotes it at 85 and replays.
	var witness_seed := -1
	var witness: Array = []
	for seed_value in range(1, 200):
		var probe := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(seed_value), [])
		if probe.get("ok") == true and _ids(probe.offers).has("wool_patch_cloak"):
			witness_seed = seed_value
			witness = probe.offers
			break
	_check(witness_seed > 0 and witness.has({"id": "wool_patch_cloak", "price": 85}),
		"a deterministic open-ledger seed stocks wool_patch_cloak at 85 gold")
	if witness_seed > 0:
		_check(RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(witness_seed), [])
			.get("offers") == witness, "open-ledger wool cloak witness seed replays")

	# Already owned: SOLD and disabled, no debit.
	var owned_visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(),
		owned + ["wool_patch_cloak"], 200, offers)
	_check(owned_visit.is_valid(), "owned wool cloak visit opens")
	if owned_visit.is_valid():
		var o_state := owned_visit.read_state()
		for row in owned_visit.quote().offers:
			if row.id == "wool_patch_cloak":
				_check(row.sold == true and row.can_buy == false, "owned wool cloak is SOLD and disabled")
		_check(owned_visit.buy_patch("wool_patch_cloak", o_state.visit_id, o_state.node_id,
			o_state.snapshot).get("ok") != true and owned_visit.read_state() == o_state,
			"owned wool cloak cannot be bought again")


## Thick Felt Mantle at its 110-gold quote: seeded witness stock, exact-gold buy, 109 refused, owned SOLD.
func _check_mantle_price() -> void:
	var prices := _source_prices()
	_check(prices.get("thick_felt_mantle", -1) == 110, "thick_felt_mantle source row is exactly 110 gold")
	_check(prices.get("wool_patch_cloak", -1) == 85 and prices.get("reinforced_patchcoat", -1) == 105
		and prices.get("padded_vest", -1) == 75, "wool cloak stays 85 and neighbours stay authored")
	var witness_seed := -1
	var witness: Array = []
	for seed_value in range(1, 300):
		var probe := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(seed_value), [])
		if probe.get("ok") == true and _ids(probe.offers).has("thick_felt_mantle"):
			witness_seed = seed_value
			witness = probe.offers
			break
	_check(witness_seed > 0 and witness.size() == 3, "a deterministic seed stocks thick_felt_mantle")
	if witness_seed < 0:
		return
	_check(_ids(witness).count("thick_felt_mantle") == 1 and witness.has({"id": "thick_felt_mantle", "price": 110}),
		"mantle is stocked once as the 110-gold row")
	var distinct := {}
	for id in _ids(witness):
		distinct[id] = true
	_check(distinct.size() == 3, "mantle stock rows are distinct")
	_check(RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(witness_seed), []).get("offers") == witness,
		"mantle witness seed replays the same stock")

	var rich := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 110, witness)
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 109, witness)
	_check(rich.is_valid() and poor.is_valid(), "110-gold and 109-gold mantle visits open")
	if not rich.is_valid() or not poor.is_valid():
		return
	var rich_seen := false
	for row in rich.quote().offers:
		if row.id == "thick_felt_mantle":
			rich_seen = true
			_check(row.price == 110 and row.can_buy == true and row.sold == false,
				"mantle is buyable at 110 gold")
	_check(rich_seen, "110-gold quote shows the mantle row")
	var poor_seen := false
	for row in poor.quote().offers:
		if row.id == "thick_felt_mantle":
			poor_seen = true
			_check(row.price == 110 and row.can_buy == false, "mantle is not buyable at 109 gold")
	_check(poor_seen, "109-gold quote shows the mantle row")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.buy_patch("thick_felt_mantle", poor_state.visit_id, poor_state.node_id,
		poor_state.snapshot).get("ok") != true
		and poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"109 gold cannot buy the mantle and nothing is debited or granted")
	var state := rich.read_state()
	var bought := rich.buy_patch("thick_felt_mantle", state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true
		and bought.receipt == {"kind": "trinket", "id": "thick_felt_mantle", "price": 110}
		and bought.ledger.gold == 0 and bought.ledger.owned_patch_ids == ["thick_felt_mantle"],
		"110 gold buys the mantle once for exactly 110 and leaves 0 gold")
	_check(rich.is_consumed() and rich.buy_patch("thick_felt_mantle", state.visit_id, state.node_id,
		state.snapshot).get("ok") != true, "replayed mantle buy refused")
	# Already owned: SOLD and disabled, no debit.
	var owned_visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), ["thick_felt_mantle"], 200, witness)
	_check(owned_visit.is_valid(), "owned-mantle visit opens")
	if owned_visit.is_valid():
		var o_state := owned_visit.read_state()
		var found := false
		for row in owned_visit.quote().offers:
			if row.id == "thick_felt_mantle":
				found = true
				_check(row.sold == true and row.can_buy == false, "owned mantle is SOLD and disabled")
		_check(found, "owned mantle row remains visible as SOLD")
		_check(owned_visit.buy_patch("thick_felt_mantle", o_state.visit_id, o_state.node_id,
			o_state.snapshot).get("ok") != true and owned_visit.read_state() == o_state,
			"owned mantle cannot be bought again")


## Reinforced Patchcoat at its 105-gold quote: seeded witness stock, exact-gold buy, 104 refused, owned SOLD.
func _check_patchcoat_price() -> void:
	var prices := _source_prices()
	_check(prices.get("reinforced_patchcoat", -1) == 105, "reinforced_patchcoat source row is exactly 105 gold")
	_check(prices.get("double_quilt_coat", -1) == 100 and prices.get("thick_felt_mantle", -1) == 110,
		"double_quilt_coat stays 100 and thick_felt_mantle stays 110")
	var witness_seed := -1
	var witness: Array = []
	for seed_value in range(1, 300):
		var probe := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(seed_value), [])
		if probe.get("ok") == true and _ids(probe.offers).has("reinforced_patchcoat"):
			witness_seed = seed_value
			witness = probe.offers
			break
	_check(witness_seed > 0 and witness.size() == 3, "a deterministic seed stocks reinforced_patchcoat")
	if witness_seed < 0:
		return
	_check(_ids(witness).count("reinforced_patchcoat") == 1
		and witness.has({"id": "reinforced_patchcoat", "price": 105}),
		"patchcoat is stocked once as the 105-gold row")
	_check(RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(witness_seed), []).get("offers") == witness,
		"patchcoat witness seed replays the same stock")
	var rich := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 105, witness)
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), [], 104, witness)
	_check(rich.is_valid() and poor.is_valid(), "105-gold and 104-gold patchcoat visits open")
	if not rich.is_valid() or not poor.is_valid():
		return
	var rich_seen := false
	for row in rich.quote().offers:
		if row.id == "reinforced_patchcoat":
			rich_seen = true
			_check(row.price == 105 and row.can_buy == true and row.sold == false,
				"patchcoat is buyable at 105 gold")
	_check(rich_seen, "105-gold quote shows the patchcoat row")
	var poor_seen := false
	for row in poor.quote().offers:
		if row.id == "reinforced_patchcoat":
			poor_seen = true
			_check(row.price == 105 and row.can_buy == false, "patchcoat is not buyable at 104 gold")
	_check(poor_seen, "104-gold quote shows the patchcoat row")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	_check(poor.buy_patch("reinforced_patchcoat", poor_state.visit_id, poor_state.node_id,
		poor_state.snapshot).get("ok") != true
		and poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"104 gold cannot buy the patchcoat and nothing is debited or granted")
	var state := rich.read_state()
	var bought := rich.buy_patch("reinforced_patchcoat", state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true
		and bought.receipt == {"kind": "trinket", "id": "reinforced_patchcoat", "price": 105}
		and bought.ledger.gold == 0 and bought.ledger.owned_patch_ids == ["reinforced_patchcoat"],
		"105 gold buys the patchcoat once for exactly 105 and leaves 0 gold")
	_check(rich.is_consumed() and rich.buy_patch("reinforced_patchcoat", state.visit_id, state.node_id,
		state.snapshot).get("ok") != true, "replayed patchcoat buy refused")
	var owned_visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), ["reinforced_patchcoat"], 200, witness)
	_check(owned_visit.is_valid(), "owned-patchcoat visit opens")
	if owned_visit.is_valid():
		var o_state := owned_visit.read_state()
		var found := false
		for row in owned_visit.quote().offers:
			if row.id == "reinforced_patchcoat":
				found = true
				_check(row.sold == true and row.can_buy == false, "owned patchcoat is SOLD and disabled")
		_check(found, "owned patchcoat row remains visible as SOLD")
		_check(owned_visit.buy_patch("reinforced_patchcoat", o_state.visit_id, o_state.node_id,
			o_state.snapshot).get("ok") != true and owned_visit.read_state() == o_state,
			"owned patchcoat cannot be bought again")


func _check_membership_and_determinism(prices: Dictionary) -> void:
	var blocked := _foreign_ids()
	for seed_value in [1, 7, 42, 1337, 90210]:
		var rng := _rng(seed_value)
		var before := rng.state
		var owned: Array = []
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
		_check(result.get("ok") == true and result.get("offers") is Array, "seed %d samples" % seed_value)
		if result.get("ok") != true:
			continue
		var offers: Array = result.offers
		_check(offers.size() == 3 and _ids(offers).size() == 3, "seed %d draws three rows" % seed_value)
		var seen := {}
		for offer in offers:
			_check(offer.size() == 2 and offer.get("id") is String and typeof(offer.get("price")) == TYPE_INT,
				"seed %d row is a strict id/price pair" % seed_value)
			_check(prices.has(offer.id) and offer.price == prices[offer.id] and offer.price > 0,
				"seed %d row %s carries its authored price" % [seed_value, offer.id])
			_check(not EXPECTED_PRICE.has(offer.id) or offer.price == EXPECTED_PRICE[offer.id],
				"seed %d row %s is quoted at its ID-specific coat price" % [seed_value, offer.id])
			_check(not blocked.has(offer.id), "seed %d row %s is not card-era/rare/Heirloom" % [seed_value, offer.id])
			_check(not seen.has(offer.id), "seed %d rows are distinct" % seed_value)
			seen[offer.id] = true
		_check(rng.state != before, "seed %d consumes the supplied RNG" % seed_value)
		_check(owned.is_empty(), "seed %d leaves the caller's owned IDs untouched" % seed_value)

		var rng_b := _rng(seed_value)
		var again := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_b, [])
		_check(again == result and rng_b.state == rng.state,
			"seed %d: equal seed and inputs give equal offers and final RNG state" % seed_value)

	var owned_a := ["quilted_coat", "padded_vest"]
	var owned_b := ["padded_vest", "quilted_coat"]
	var rng_a := _rng(555)
	var rng_c := _rng(555)
	var first := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_a, owned_a)
	var second := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_c, owned_b)
	_check(first.get("ok") == true and first == second and rng_a.state == rng_c.state,
		"owned-ID input order does not change offers or RNG use")
	if first.get("ok") == true:
		for id in _ids(first.offers):
			_check(not owned_a.has(id), "partial ledger keeps owned %s out of three-unowned stock" % id)
	_check(owned_a == ["quilted_coat", "padded_vest"], "owned input is not mutated by a sample")


func _check_every_coat_eligible() -> void:
	# Each named coat, when the only unowned one, is offered once at its authored price.
	for id in COATS:
		var owned := _others([id])
		var snapshot := owned.duplicate(true)
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(31), owned)
		_check(result.get("ok") == true, "%s remains eligible when unowned" % id)
		if result.get("ok") != true:
			continue
		_check(_ids(result.offers).count(id) == 1, "%s appears exactly once as the sole unowned coat" % id)
		for offer in result.offers:
			if offer.id == id:
				_check(offer.price == EXPECTED_PRICE[id],
					"%s is offered at its %d-gold quote" % [id, EXPECTED_PRICE[id]])
		_check(owned == snapshot, "%s fixture owned list is not mutated" % id)


func _check_scarce(unowned: Array, label: String) -> void:
	var owned := _others(unowned)
	var snapshot := owned.duplicate(true)
	var rng := _rng(2026)
	var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
	_check(result.get("ok") == true, "%s remaining coat(s): sampler succeeds" % label)
	if result.get("ok") != true:
		return
	var offers: Array = result.offers
	var ids := _ids(offers)
	_check(offers.size() == 3 and ids.size() == 3, "%s remaining: three rows" % label)
	var distinct := {}
	for id in ids:
		distinct[id] = true
	_check(distinct.size() == 3, "%s remaining: rows are distinct" % label)
	for id in unowned:
		_check(ids.count(id) == 1, "%s remaining: unowned %s appears once" % [label, id])
	for offer in offers:
		_check(offer.price == EXPECTED_PRICE[offer.id],
			"%s remaining: %s keeps its honest %d price" % [label, offer.id, EXPECTED_PRICE[offer.id]])
		if not unowned.has(offer.id):
			_check(owned.has(offer.id), "%s remaining: filler %s is truly owned" % [label, offer.id])
	_check(owned == snapshot, "%s remaining: caller's owned IDs not mutated" % label)

	var gold := 150
	var visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, gold, offers)
	_check(visit.is_valid(), "%s remaining: real four-hero visit opens" % label)
	if not visit.is_valid():
		return
	var state := visit.read_state()
	var quote := visit.quote()
	_check(quote.offers.size() == 3 and quote.decisions == ["buy_patch", "leave"],
		"%s remaining: quote shows three rows with buy and leave" % label)
	var buyable := 0
	for row in quote.offers:
		if unowned.has(row.id):
			buyable += 1
			_check(row.sold == false and row.can_buy == true and row.blocked == "",
				"%s remaining: unowned %s is buyable" % [label, row.id])
		else:
			_check(row.sold == true and row.can_buy == false and row.blocked == "already owned",
				"%s remaining: filler %s is SOLD and blocked" % [label, row.id])
	_check(buyable == unowned.size(), "%s remaining: only unowned rows are buyable" % label)

	# SOLD fillers cannot be bought and leave the visit untouched.
	for row in quote.offers:
		if not unowned.has(row.id):
			var refused := visit.buy_patch(row.id, state.visit_id, state.node_id, state.snapshot)
			_check(refused.get("ok") != true, "%s remaining: SOLD filler %s buy refused" % [label, row.id])
			_check(visit.read_state() == state and not visit.is_consumed(),
				"%s remaining: refused filler buy leaves visit available" % label)

	# One authentic purchase of the real unowned patch at its actual quote, exactly once.
	var target: String = unowned[0]
	var target_price := 0
	for row in quote.offers:
		if row.id == target:
			target_price = int(row.price)
	_check(target_price == EXPECTED_PRICE[target] and target_price <= gold,
		"%s remaining: target %s quote is its real %d price and affordable at %d gold"
		% [label, target, EXPECTED_PRICE[target], gold])
	var bought := visit.buy_patch(target, state.visit_id, state.node_id, state.snapshot)
	_check(bought.get("ok") == true and bought.decision == "buy_patch", "%s remaining: real purchase succeeds" % label)
	if bought.get("ok") == true:
		_check(bought.receipt == {"kind": "trinket", "id": target, "price": target_price},
			"%s remaining: receipt is the authentic %d-gold quote" % [label, target_price])
		_check(bought.ledger.gold == gold - target_price and bought.ledger.owned_patch_ids.count(target) == 1,
			"%s remaining: charged %d once and owns the patch once" % [label, target_price])
		_check(bought.ledger.party_ids == PARTY and not bought.ledger.has("deck"),
			"%s remaining: ledger is card-free with the four heroes" % label)
	_check(visit.is_consumed(), "%s remaining: visit consumed" % label)
	var closed_state := visit.read_state()
	_check(visit.buy_patch(target, state.visit_id, state.node_id, state.snapshot).get("ok") != true,
		"%s remaining: replayed buy refused" % label)
	_check(visit.leave(state.visit_id, state.node_id, state.snapshot).get("ok") != true,
		"%s remaining: leave after purchase refused" % label)
	_check(visit.quote().offers == [] and visit.quote().decisions == [] and visit.read_state() == closed_state,
		"%s remaining: consumed visit advertises nothing and stays inert" % label)
	_check(owned == snapshot, "%s remaining: visit left caller's owned IDs untouched" % label)


func _check_all_owned() -> void:
	var prices := _source_prices()
	var owned: Array = prices.keys()
	owned.sort()
	_check(owned.size() >= 3, "exhausted fixture owns at least three authored IDs")
	for id in COATS:
		_check(owned.has(id), "exhausted fixture owns named coat %s" % id)
	var blocked := _foreign_ids()
	var snapshot := owned.duplicate(true)
	var rng := _rng(99)
	var before := rng.state
	var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, owned)
	_check(result.get("ok") == true and result.get("offers") is Array,
		"all authored patches owned: SOLD-only stock is offered")
	_check(rng.state == before, "all-owned stock does not advance the RNG")
	_check(owned == snapshot, "all-owned stock does not mutate owned IDs")
	if result.get("ok") != true:
		return
	var offers: Array = result.offers
	_check(offers.size() == 3, "all-owned stock has three rows")
	var seen := {}
	for offer in offers:
		_check(offer is Dictionary and offer.size() == 2 and offer.get("id") is String
				and typeof(offer.get("price")) == TYPE_INT, "all-owned row is a strict id/price pair")
		if not offer is Dictionary or not offer.get("id") is String:
			continue
		_check(prices.has(offer.id) and offer.price == prices[offer.id] and offer.price > 0,
			"all-owned row %s keeps its authored price" % offer.id)
		_check(owned.has(offer.id), "all-owned row %s is genuinely owned" % offer.id)
		_check(not blocked.has(offer.id), "all-owned row %s is not card-era/rare/Heirloom" % offer.id)
		_check(not seen.has(offer.id), "all-owned rows are distinct")
		seen[offer.id] = true
	_check(seen.size() == 3, "all-owned rows are three distinct IDs")

	var rng_b := _rng(99)
	var again := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_b, owned.duplicate(true))
	_check(again == result and rng_b.state == before, "all-owned stock repeats identically with no RNG use")
	var reversed := owned.duplicate(true)
	reversed.reverse()
	_check(RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(5), reversed) == result,
		"all-owned stock is independent of ownership order and seed")

	# One-unowned control: still the shared sampler, still drawing RNG, buyable + SOLD fillers.
	var one_owned := owned.duplicate(true)
	var open_id: String = one_owned.pop_back()
	var rng_c := _rng(99)
	var before_c := rng_c.state
	var one := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng_c, one_owned)
	_check(one.get("ok") == true and _ids(one.offers).count(open_id) == 1,
		"one unowned patch is still offered buyable")
	_check(rng_c.state != before_c, "one-unowned sampling still consumes the RNG")

	for gold in [250, 0]:
		var visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, gold, offers)
		_check(visit.is_valid(), "all-owned visit opens at %d gold" % gold)
		if not visit.is_valid():
			continue
		var state := visit.read_state()
		var quote := visit.quote()
		_check(quote.offers.size() == 3 and quote.decisions == ["leave"],
			"all-owned quote at %d gold shows three rows and only Leave" % gold)
		for row in quote.offers:
			_check(row.sold == true and row.can_buy == false and row.blocked == "already owned",
				"all-owned row %s is SOLD and blocked at %d gold" % [row.id, gold])
		for row in quote.offers:
			var refused := visit.buy_patch(row.id, state.visit_id, state.node_id, state.snapshot)
			_check(refused.get("ok") != true, "owned %s buy refused at %d gold" % [row.id, gold])
			_check(visit.read_state() == state and visit.quote() == quote and not visit.is_consumed(),
				"refused owned buy leaves the %d-gold visit unchanged" % gold)
		var first_id: String = offers[0].id
		var bad_snapshot: Dictionary = state.snapshot.duplicate(true)
		bad_snapshot.gold = gold + 1
		_check(visit.leave("stale_visit", state.node_id, state.snapshot).get("ok") != true
			and visit.leave(state.visit_id, "other_node", state.snapshot).get("ok") != true
			and visit.leave(state.visit_id, state.node_id, bad_snapshot).get("ok") != true
			and visit.leave(state.visit_id, state.node_id, null).get("ok") != true,
			"stale, wrong-node and wrong-snapshot Leave refused at %d gold" % gold)
		_check(visit.read_state() == state and not visit.is_consumed(),
			"refused Leave attempts keep the %d-gold visit open" % gold)
		var left := visit.leave(state.visit_id, state.node_id, state.snapshot)
		_check(left.get("ok") == true and left.get("decision") == "leave",
			"authenticated Leave succeeds at %d gold" % gold)
		if left.get("ok") == true:
			_check(left.ledger.gold == gold and left.ledger.owned_patch_ids == owned
				and left.ledger.party_ids == PARTY, "Leave keeps wallet %d and ownership unchanged" % gold)
		_check(visit.is_consumed(), "Leave closes the %d-gold visit" % gold)
		_check(visit.leave(state.visit_id, state.node_id, state.snapshot).get("ok") != true
			and visit.buy_patch(first_id, state.visit_id, state.node_id, state.snapshot).get("ok") != true,
			"replayed Leave and buy refused at %d gold" % gold)
		_check(visit.quote().offers == [] and visit.quote().decisions == [],
			"closed all-owned visit advertises nothing at %d gold" % gold)
		_check(owned == snapshot, "all-owned visit left caller's owned IDs untouched")


func _check_bad_inputs() -> void:
	var bad_rngs: Array = [null, 5, "rng", {}, RefCounted.new()]
	for bad in bad_rngs:
		var owned := ["quilted_coat"]
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(bad, owned)
		_check(result == {"ok": false}, "bad RNG %s refused" % str(bad))
		_check(owned == ["quilted_coat"], "bad RNG leaves owned input untouched")

	var bad_owned: Array = [
		null, "quilted_coat", 7, {"id": "quilted_coat"},
		[1], [null], [""], ["   "], ["quilted_coat", 2], [["quilted_coat"]],
		["quilted_coat", "quilted_coat"], ["padded_vest", "quilted_coat", "padded_vest"],
	]
	for bad in bad_owned:
		var rng := _rng(808)
		var before := rng.state
		var copy: Variant = bad.duplicate(true) if (bad is Array or bad is Dictionary) else bad
		var result := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(rng, bad)
		_check(result == {"ok": false}, "bad owned input %s refused" % str(bad))
		_check(rng.state == before, "bad owned input %s does not consume RNG" % str(bad))
		_check(typeof(bad) == typeof(copy) and bad == copy, "bad owned input %s not mutated" % str(bad))


func _check_visit_failures() -> void:
	var owned := ["quilted_coat"]
	var sample := RunStitchedPeddlerStock.sample_stitched_patch_stall_offers(_rng(4), owned)
	_check(sample.get("ok") == true, "failure fixture samples")
	if sample.get("ok") != true:
		return
	var offers: Array = sample.offers
	var target: String = offers[0].id

	# Stale / wrong-node / wrong-snapshot / wrong-type purchases are inert.
	var visit := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 250, offers)
	_check(visit.is_valid(), "failure fixture visit opens")
	var state := visit.read_state()
	var quote := visit.quote()
	var bad_snapshot: Dictionary = state.snapshot.duplicate(true)
	bad_snapshot.gold = 9999
	var stale_snapshot: Dictionary = state.snapshot.duplicate(true)
	stale_snapshot.owned_patch_ids = []
	var attempts: Array = [
		["wrong visit id", target, "stale_visit", state.node_id, state.snapshot],
		["wrong node", target, state.visit_id, "other_node", state.snapshot],
		["inflated snapshot", target, state.visit_id, state.node_id, bad_snapshot],
		["stale snapshot", target, state.visit_id, state.node_id, stale_snapshot],
		["null snapshot", target, state.visit_id, state.node_id, null],
		["non-string patch", 5, state.visit_id, state.node_id, state.snapshot],
		["unoffered patch", "not_a_patch", state.visit_id, state.node_id, state.snapshot],
	]
	for attempt in attempts:
		var refused := visit.buy_patch(attempt[1], attempt[2], attempt[3], attempt[4])
		_check(refused.get("ok") != true, "%s purchase refused" % attempt[0])
		_check(visit.read_state() == state and visit.quote() == quote and not visit.is_consumed(),
			"%s purchase leaves the visit untouched" % attempt[0])
	# Another visit's identity never authorizes this one.
	var other := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 250, offers)
	_check(visit.buy_patch(target, other.read_state().visit_id, state.node_id, state.snapshot).get("ok") != true,
		"another visit's id cannot buy here")
	_check(visit.leave("stale_visit", state.node_id, state.snapshot).get("ok") != true
		and visit.leave(state.visit_id, "other_node", state.snapshot).get("ok") != true
		and visit.leave(state.visit_id, state.node_id, bad_snapshot).get("ok") != true,
		"stale, wrong-node and wrong-snapshot Leave refused")
	_check(visit.read_state() == state and not visit.is_consumed(), "refused Leave attempts leave the visit open")

	# Failed low-gold attempt (below the cheapest 70-gold coat), then free Leave and replay refusal.
	var poor := RunPatchStallVisit.open_stitched(NODE, PARTY.duplicate(), owned, 69, offers)
	_check(poor.is_valid(), "low-gold visit opens")
	var poor_state := poor.read_state()
	var poor_quote := poor.quote()
	var any_buyable := false
	for row in poor_quote.offers:
		any_buyable = any_buyable or row.can_buy
	_check(not any_buyable and poor_quote.decisions == ["leave"], "69 gold quotes no buyable row and only Leave")
	var short := poor.buy_patch(target, poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(short.get("ok") != true, "low-gold purchase refused")
	_check(poor.read_state() == poor_state and poor.quote() == poor_quote and not poor.is_consumed(),
		"failed low-gold attempt charges nothing and leaves the visit open")
	var left := poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot)
	_check(left.get("ok") == true and left.decision == "leave", "Leave is free at the Patch Stall")
	if left.get("ok") == true:
		_check(left.ledger.gold == 69 and left.ledger.owned_patch_ids == owned,
			"Leave keeps gold and owned patches unchanged")
	_check(poor.is_consumed(), "Leave closes the visit")
	_check(poor.leave(poor_state.visit_id, poor_state.node_id, poor_state.snapshot).get("ok") != true
		and poor.buy_patch(target, poor_state.visit_id, poor_state.node_id, poor_state.snapshot).get("ok") != true,
		"replayed Leave and buy after Leave refused")
	_check(poor.quote().offers == [] and owned == ["quilted_coat"], "closed visit is inert and owned input untouched")
