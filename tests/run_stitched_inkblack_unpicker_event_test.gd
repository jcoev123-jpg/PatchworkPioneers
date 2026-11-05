extends SceneTree

const Adapter = preload("res://scripts/run_stitched_inkblack_unpicker_event.gd")
const NODE := "event_inkblack_3"
const MAX_INT := 9223372036854775807
var _failures := 0
var _record: Dictionary = {}


func _initialize() -> void:
	var catalog := RunV3ServiceWaystationEventGate.load_shipped_catalog()
	for event: Dictionary in catalog.events:
		if event.id == Adapter.EVENT_ID:
			_record = event.duplicate(true)
	_check(not _record.is_empty(), "genuine named event exists")
	_check(_record.get("title") == "The Inkblack Unpicker Van", "authored title")
	var rng := RandomNumberGenerator.new()
	rng.seed = 535
	var rng_before := rng.state
	seed(535)
	var next_global_draw := randi()
	seed(535)
	_test_handoff()
	_test_boundaries()
	_test_authentication()
	_test_invalid_inputs()
	_check(rng.state == rng_before, "all branches draw no run RNG")
	_check(randi() == next_global_draw, "all branches draw no global RNG")
	if _failures == 0:
		print("Stitched Inkblack Unpicker event PASS")
	quit(0 if _failures == 0 else 1)


func _heroes() -> Array:
	var heroes: Array = []
	var ids := ["warden", "seamstress", "tinker", "lantern_monk"]
	var fray := [60, 0, 20, 0]
	for i in 4:
		heroes.append({"id": ids[i], "position": i + 1, "rank": i + 1,
			"fray": fray[i], "hp": 20, "max_hp": 20, "metadata": {"kept": true}})
	return heroes


func _spares() -> Array:
	return [{"id": "warden_head_pot_helm_bonk", "slot": "head", "tier": 1, "torn": false}]


func _open(gold: int, heroes: Variant = null, satchel: Array = [],
		scraps: int = 3, price: int = 20, scrap_yield: int = 2) -> RefCounted:
	if heroes == null:
		heroes = _heroes()
	return Adapter.new(_record, NODE, heroes, satchel,
		{"gold": gold, "scraps": scraps}, price, scrap_yield)


func _choice(visit: RefCounted, id: String) -> Dictionary:
	var preview: Dictionary = visit.preview_choices()
	_check(preview.get("ok", false), "preflight succeeds")
	_check(preview.get("choices", []).size() == 3, "three authored choices retained")
	for item: Dictionary in preview.get("choices", []):
		if item.choice_id == id:
			return item
	_check(false, "named choice exists " + id)
	return {}


func _test_handoff() -> void:
	var heroes := _heroes()
	var satchel := _spares()
	var wallet := {"gold": 40, "scraps": 3}
	var original := [heroes.duplicate(true), satchel.duplicate(true), wallet.duplicate(true)]
	var record := _record.duplicate(true)
	var visit = Adapter.new(record, NODE, heroes, satchel, wallet, 20, 2)
	_check(visit.is_valid(), "authentic visit opens")
	var source: Dictionary = visit.read_state()
	var hire := _choice(visit, "hire_unpicker")
	_check(hire.available and hire.wallet == {"gold": 30, "scraps": 3}, "only entrance toll projected")
	_check(hire.service_request == {"stop_type": "Unpicker"}, "typed handoff")
	var real := RunUnpickerVisit.open_stitched(NODE, source.heroes, hire.wallet.gold,
		source.quoted_calm_price, source.satchel, hire.wallet.scraps, source.quoted_scrap_yield)
	_check(real.is_valid() and real.quote().choices.has("calm_hero"), "real post-toll calm exists")
	_check(real.quote().choices.has("unpick_spare"), "real spare action exists")
	_check(visit.read_state() == source, "preflight is pure")
	# Constructor inputs and every nested public return are detached.
	heroes[0].metadata.kept = false
	satchel[0].tier = 3
	wallet.gold = 0
	record.title = "forged after opening"
	hire.wallet.gold = 0
	hire.service_request.stop_type = "Campfire"
	var exposed: Dictionary = visit.read_state()
	exposed.heroes[0].fray = 0
	exposed.satchel.clear()
	_check(visit.read_state() == source, "inputs and preview/state returns detached")
	var result: Dictionary = visit.choose("hire_unpicker", NODE, source)
	_check(result.ok and result.wallet == {"gold": 30, "scraps": 3}, "claim charges entrance alone")
	_check(result.service_request == {"stop_type": "Unpicker"}, "receipt matches preview")
	_check(result.state.heroes == original[0] and result.state.satchel == original[1], "no inner action effects")
	_check(result.source_state == source and result.state.version == 1, "source and version receipt")
	_check(heroes[0].fray == 60 and wallet.gold == 0 and satchel[0].tier == 3, "claim leaves caller inputs alone")
	var settled: Dictionary = visit.read_state()
	result.state.heroes[0].fray = 199
	result.source_state.wallet.gold = 999
	result.wallet.gold = 999
	result.service_request.clear()
	_check(visit.read_state() == settled, "receipt detached")
	_check(not visit.choose("hire_unpicker", NODE, source).ok, "replay denied")
	_check(not visit.leave(NODE, settled).ok and not visit.preview_choices().ok, "closed visit denies all reuse")


func _test_boundaries() -> void:
	for gold in [9, 10, 29, 30, 40]:
		for spare in [false, true]:
			for calm in [false, true]:
				var heroes := _heroes()
				if calm:
					for hero: Dictionary in heroes:
						hero.fray = 0
				var satchel: Array = _spares() if spare else []
				var visit = _open(gold, heroes, satchel)
				_check(visit.is_valid(), "boundary fixture valid")
				var source: Dictionary = visit.read_state()
				var hire := _choice(visit, "hire_unpicker")
				var useful: bool = gold >= 10 and (spare or (not calm and gold >= 30))
				_check(hire.available == useful, "post-toll availability at " + str([gold, spare, calm]))
				_check(hire.gold_delta == -10 and hire.scraps_delta == 0, "authored hire deltas")
				if gold >= 10:
					var real := RunUnpickerVisit.open_stitched(NODE, heroes, gold - 10, 20, satchel, 3, 2)
					_check(real.is_valid(), "prospective real visit valid")
					_check((real.quote().choices.size() > 1) == useful, "actual quote proves usefulness")
				var result: Dictionary = visit.choose("hire_unpicker", NODE, source)
				_check(result.ok == useful, "preview and claim agree")
				if useful:
					_check(result.wallet == {"gold": gold - 10, "scraps": 3}, "receipt pays only authored toll")
					_check(result.state.heroes == heroes and result.state.satchel == satchel, "hire preserves heroes and spares")
					_check(result.service_request == hire.service_request, "available preview matches handoff")
				if not useful:
					_check(result.service_request.is_empty() and hire.service_request.is_empty(), "refusal mints no service")
					_check(visit.read_state() == source, "refusal spends and consumes nothing")
					var sale := _choice(visit, "sell_trim")
					_check(sale.available and sale.gold_delta == 0 and sale.scraps_delta == 1, "authored sale retained")
					var sold: Dictionary = visit.choose("sell_trim", NODE, source)
					_check(sold.ok and sold.wallet == {"gold": gold, "scraps": 4}, "alternate sale after refused hire")
					_check(sold.service_request.is_empty() and sold.state.heroes == heroes and sold.state.satchel == satchel, "sale has no service or body effects")
					_check(not visit.choose("sell_trim", NODE, source).ok, "sale replay denied")
	var visit = _open(29)
	var source: Dictionary = visit.read_state()
	_check(not visit.choose("hire_unpicker", NODE, source).ok, "actionless hire refused before leave")
	var leave := _choice(visit, "leave")
	_check(leave.available and leave.gold_delta == 0 and leave.scraps_delta == 0, "leave retained")
	var result: Dictionary = visit.leave(NODE, source)
	_check(result.ok and result.wallet == source.wallet and result.service_request.is_empty(), "leave no-op wallet")
	_check(result.state.heroes == source.heroes and result.state.satchel == source.satchel, "leave preserves body state")
	# Caller quotes are authoritative, with no adapter-owned price or yield.
	_check(not _choice(_open(40, _heroes(), [], 3, 31, 7), "hire_unpicker").available, "custom calm quote used")
	_check(_choice(_open(10, _heroes(), _spares(), 3, 999, 7), "hire_unpicker").available, "custom spare quote used")


func _test_authentication() -> void:
	var visit = _open(40)
	var source: Dictionary = visit.read_state()
	for field in ["version", "node_id", "wallet", "heroes", "satchel", "quoted_calm_price", "quoted_scrap_yield", "event_id", "visit_id"]:
		var forged := source.duplicate(true)
		forged[field] = null
		var result: Dictionary = visit.choose("hire_unpicker", NODE, forged)
		_check(not result.ok and result.service_request.is_empty(), "altered snapshot denied " + field)
		_check(visit.read_state() == source, "failed auth pure")
	var typed := source.duplicate(true)
	typed.version = 0.0
	_check(not visit.choose("hire_unpicker", NODE, typed).ok, "numeric type forgery denied")
	_check(not visit.choose("hire_unpicker", "wrong", source).ok, "wrong actual node denied")
	_check(not visit.choose("hire_unpicker").ok, "missing expected state denied")
	_check(not visit.choose("hire_unpicker", NODE, _open(40).read_state()).ok, "other visit snapshot denied")
	for id in [null, 7, "", " hire_unpicker", "unknown"]:
		_check(not visit.choose(id, NODE, source).ok, "malformed choice denied")
	_check(visit.read_state() == source and visit.leave(NODE, source).ok, "lawful alternate remains after authentication refusals")


func _test_invalid_inputs() -> void:
	var heroes := _heroes()
	for mutation in ["duplicate_id", "duplicate_rank", "bad_fray", "missing_position", "rank_alias"]:
		var bad := heroes.duplicate(true)
		match mutation:
			"duplicate_id": bad[1].id = bad[0].id
			"duplicate_rank": bad[1].position = 1
			"bad_fray": bad[0].fray = 201
			"missing_position": bad[0].erase("position")
			"rank_alias": bad[0].rank = 2
		_check(not _open(40, bad).is_valid(), "malformed roster denied " + mutation)
	var forged := _record.duplicate(true)
	forged.choices[0].outcome.gold = 0
	var cases := [
		Adapter.new(forged, NODE, heroes, [], {"gold": 40, "scraps": 3}, 20, 2),
		Adapter.new(_record, " ", heroes, [], {"gold": 40, "scraps": 3}, 20, 2),
		Adapter.new(_record, NODE, heroes, [], {"gold": -1, "scraps": 3}, 20, 2),
		_open(40, heroes, [], 3, 0), _open(40, heroes, [], 3, 20, 0),
		_open(40, heroes, [{}]), _open(40, heroes, _spares(), MAX_INT - 1),
		_open(40, heroes, _spares() + _spares() + _spares() + _spares() + _spares() + _spares() + _spares()),
	]
	for visit in cases:
		_check(not visit.is_valid() and not visit.preview_choices().ok, "malformed input fails closed")
		var result: Dictionary = visit.choose("hire_unpicker", NODE, visit.read_state())
		_check(not result.ok and result.service_request.is_empty() and not visit.is_claimed(), "invalid visit cannot mint or consume")
	_check(heroes == _heroes(), "malformed preflight never mutates original roster")


func _check(value: bool, label: String) -> void:
	if not value:
		_failures += 1
		push_error(label)
