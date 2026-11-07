extends SceneTree
## Deterministic headless regression for the four V3-4 fogbound gothic prop-story
## hero-choice Events appended to data/events/v3_hero_choice_events.json.
##
## Every expectation is keyed by authored event/choice ID against a task-local
## oracle table: no catalog total, no ordered full-ID list and no positional
## index is asserted, so parallel appends to the same shared catalog cannot
## invalidate this lane. Party admission is exercised through the real
## RunV3HeroEventOffers service and every wallet preview/settlement through the
## real RunEventChoice authority; the JSON file itself is never mutated.

const CATALOG_PATH := "res://data/events/v3_hero_choice_events.json"
const PARTY_A := ["yarn_ranger", "warden", "tinker"]
const PARTY_B := ["rag_duelist", "scarecrow", "button_golem"]
const FUNDED_GOLD := 40
const FUNDED_SCRAPS := 4

## The four authored records added by this task, transcribed independently of
## the production catalog so a missing field or reworded line is caught.
const EVENTS := {
	"v3_yarn_ranger_fogbell_loom": {
		"title": "The Fog-Bell Loom",
		"description": "A squat button-eyed bell keeper points to a brass bell snagged in moss-green wool; the Yarn Ranger's knitting-needle bow and teal bolas can reel down its rope.",
		"required_hero": "yarn_ranger",
		"props": ["knitting-needle", "bolas"],
		"hero_choice_ids": ["reel_fogbell_rope", "gather_fog_wool"],
		"choices": {
			"reel_fogbell_rope": {"text": "Reel down the fog bell (spend 2 scraps; gain 25 gold)", "gold": 25, "scraps": -2},
			"gather_fog_wool": {"text": "Gather loose teal wool knots (gain 2 scraps)", "gold": 0, "scraps": 2},
			"leave": {"text": "Leave the bell hidden in the mist", "gold": 0, "scraps": 0},
		},
	},
	"v3_rag_duelist_velvet_mirror": {
		"title": "The Velvet Mirror Duel",
		"description": "A plump velvet mirror puppet raises a needle rapier at the Rag Duelist; candlelight catches his tattered crimson cape and the puppet's gold-button eyepatch.",
		"required_hero": "rag_duelist",
		"props": ["needle rapier", "crimson cape"],
		"hero_choice_ids": ["parry_mirror_needle", "buy_mirror_cape_lace"],
		"choices": {
			"parry_mirror_needle": {"text": "Parry the mirror puppet's needle (gain 21 gold)", "gold": 21, "scraps": 0},
			"buy_mirror_cape_lace": {"text": "Buy fresh velvet cape lace (spend 17 gold; gain 3 scraps)", "gold": -17, "scraps": 3},
			"leave": {"text": "Bow to the puppet and leave", "gold": 0, "scraps": 0},
		},
	},
	"v3_scarecrow_crow_letter_post": {
		"title": "The Crow-Letter Post",
		"description": "A black crow carries red wax letters to a squat burlap postmaster; the Scarecrow's pitchfork holds the stitched mailbag above a pumpkin-lit desk.",
		"required_hero": "scarecrow",
		"props": ["pitchfork", "crow"],
		"hero_choice_ids": ["deliver_crow_letters", "gather_straw_seals"],
		"choices": {
			"deliver_crow_letters": {"text": "Deliver the crow's sealed letters (spend 1 scrap; gain 24 gold)", "gold": 24, "scraps": -1},
			"gather_straw_seals": {"text": "Collect discarded straw seals (gain 1 scrap)", "gold": 0, "scraps": 1},
			"leave": {"text": "Leave the letters unopened", "gold": 0, "scraps": 0},
		},
	},
	"v3_button_golem_midnight_button_clock": {
		"title": "The Midnight Button Clock",
		"description": "A great round midnight-teal clock has stopped between two huge brass buttons; the Button Golem's stacked button fists fit its missing hand-shaped crank.",
		"required_hero": "button_golem",
		"props": ["button fists", "crank"],
		"hero_choice_ids": ["turn_button_clock", "buy_clock_spring_thread"],
		"choices": {
			"turn_button_clock": {"text": "Turn the button clock's heavy crank (gain 26 gold)", "gold": 26, "scraps": 0},
			"buy_clock_spring_thread": {"text": "Buy spare clock spring thread (spend 19 gold; gain 3 scraps)", "gold": -19, "scraps": 3},
			"leave": {"text": "Let midnight wait another hour", "gold": 0, "scraps": 0},
		},
	},
}

## Named earlier records from the same shared catalog: this batch appends only,
## so these anchors must stay byte-identical in title and delta.
const EARLIER_ANCHORS := {
	"v3_yarn_ranger_bolas_mooring": {
		"title": "The Yarn-Bolas Mooring", "choice": "sell_spare_knitting_knots", "gold": 20, "scraps": -1,
	},
	"v3_rag_duelist_cape_windmill": {
		"title": "The Cape Windmill", "choice": "free_cape_blades", "gold": 24, "scraps": -1,
	},
	"v3_scarecrow_raven_orchard": {
		"title": "The Raven-Sewn Orchard", "choice": "trade_pitchfork_twine", "gold": 29, "scraps": -2,
	},
	"v3_button_golem_buttonlift": {
		"title": "The Buttonlift", "choice": "buy_brass_button_shanks", "gold": -17, "scraps": 3,
	},
}

var failures: Array[String] = []
var checks := 0
var catalog: Array = []
var catalog_before: Array = []


func _initialize() -> void:
	_load_catalog()
	_test_exact_records()
	_test_earlier_anchors()
	_test_hero_gates()
	_test_detached_offers()
	_test_funded_receipts()
	_test_unaffordable_choices()
	_check(catalog == catalog_before, "shared hero-choice catalog unchanged across all flows")
	var passed: bool = failures.is_empty()
	for failure in failures:
		printerr(failure)
	print("v3_fogbound_hero_prop_stories_test: ", "PASS" if passed else "FAIL", " (", checks, " checks)")
	quit(0 if passed else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _load_catalog() -> void:
	var file := FileAccess.open(CATALOG_PATH, FileAccess.READ)
	_check(file != null, "hero-choice catalog opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "hero-choice catalog parses as JSON")
	if parse_result != OK:
		return
	var data: Variant = parser.data
	_check(data is Dictionary and (data as Dictionary).get("events") is Array,
		"hero-choice catalog keeps its {events: [...]} root")
	if not data is Dictionary or not (data as Dictionary).get("events") is Array:
		return
	catalog = (data as Dictionary)["events"]
	catalog_before = catalog.duplicate(true)
	_check(not catalog.is_empty(), "hero-choice catalog is non-empty")


func _matches(event_id: String) -> Array:
	return catalog.filter(func(entry: Variant) -> bool:
		return entry is Dictionary and entry.get("id") == event_id)


func _offer(event_id: String, offers: Array) -> Dictionary:
	for record in offers:
		if record is Dictionary and record.get("id") == event_id:
			return record
	return {}


func _is_integral(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) == TYPE_FLOAT:
		var number: float = value
		return is_finite(number) and floor(number) == number \
			and absf(number) <= RunEventChoice.MAX_SAFE_FLOAT_INT
	return false


func _choice_entry(preview: Dictionary, choice_id: String) -> Dictionary:
	for entry in preview.get("choices", []):
		if entry is Dictionary and entry.get("choice_id") == choice_id:
			return entry
	return {}


func _other_choice(choices: Dictionary, choice_id: String) -> String:
	for candidate in choices:
		if candidate != choice_id:
			return candidate
	return choice_id


func _party_for(required_hero: String) -> Array:
	if PARTY_A.has(required_hero):
		return PARTY_A
	return PARTY_B


func _test_exact_records() -> void:
	for event_id in EVENTS:
		var spec: Dictionary = EVENTS[event_id]
		var matches := _matches(event_id)
		_check(matches.size() == 1, "exactly one authored record: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.size() == 6 and record.has("id") and record.has("title")
			and record.has("description") and record.has("required_hero")
			and record.has("hero_choice_ids") and record.has("choices"),
			"record has the six authored keys: " + event_id)
		_check(record.get("id") == event_id, "authored id: " + event_id)
		_check(record.get("title") == spec["title"], "authored title: " + event_id)
		_check(record.get("description") == spec["description"], "authored description: " + event_id)
		var description: String = str(record.get("description", ""))
		for prop in spec["props"]:
			_check(description.contains(str(prop)),
				"description features the hero prop '" + str(prop) + "': " + event_id)
		_check(record.get("required_hero") == spec["required_hero"], "authored required_hero: " + event_id)
		_check(record.get("hero_choice_ids") == spec["hero_choice_ids"],
			"hero_choice_ids lists exactly the two authored hero choices: " + event_id)
		_check(not (record.get("hero_choice_ids") as Array).has("leave"),
			"hero_choice_ids excludes Leave: " + event_id)
		var raw_choices: Variant = record.get("choices")
		_check(raw_choices is Array, "choices array present: " + event_id)
		if not raw_choices is Array:
			continue
		var choices: Array = raw_choices
		_check(choices.size() == 3, "exactly three authored choices: " + event_id)
		var by_id := {}
		for choice in choices:
			_check(choice is Dictionary, "every choice is an object: " + event_id)
			if not choice is Dictionary:
				continue
			var choice_dict: Dictionary = choice
			var choice_id: Variant = choice_dict.get("id")
			_check(choice_id is String and not (choice_id as String).strip_edges().is_empty(),
				"choice ID is a nonblank string: " + event_id)
			if not choice_id is String:
				continue
			_check(not by_id.has(choice_id), "choice IDs are unique: " + event_id)
			by_id[choice_id] = choice_dict
		var wanted_choices: Dictionary = spec["choices"]
		_check(by_id.size() == wanted_choices.size(), "no unstated choice IDs: " + event_id)
		for choice_id in wanted_choices:
			var wanted: Dictionary = wanted_choices[choice_id]
			_check(by_id.has(choice_id), "required choice present: " + event_id + "/" + choice_id)
			if not by_id.has(choice_id):
				continue
			var choice_dict: Dictionary = by_id[choice_id]
			_check(choice_dict.size() == 3 and choice_dict.has("id")
				and choice_dict.has("text") and choice_dict.has("outcome"),
				"choice has exactly id/text/outcome: " + event_id + "/" + choice_id)
			_check(choice_dict.get("text") == wanted["text"],
				"exact authored choice text: " + event_id + "/" + choice_id)
			var raw_outcome: Variant = choice_dict.get("outcome")
			_check(raw_outcome is Dictionary, "outcome is an object: " + event_id + "/" + choice_id)
			if not raw_outcome is Dictionary:
				continue
			var outcome: Dictionary = raw_outcome
			_check(outcome.size() == 2 and outcome.has("gold") and outcome.has("scraps"),
				"outcome has exactly gold/scraps: " + event_id + "/" + choice_id)
			var gold: Variant = outcome.get("gold")
			var scraps: Variant = outcome.get("scraps")
			_check(_is_integral(gold) and _is_integral(scraps),
				"outcome deltas are signed integers: " + event_id + "/" + choice_id)
			_check(int(gold) == int(wanted["gold"]) and int(scraps) == int(wanted["scraps"]),
				"exact authored gold/scraps delta: " + event_id + "/" + choice_id)
		var leave: Dictionary = by_id.get("leave", {})
		_check(not leave.is_empty(), "authored Leave choice exists: " + event_id)
		if not leave.is_empty():
			var leave_outcome: Dictionary = leave.get("outcome", {})
			_check(int(leave_outcome.get("gold", 1)) == 0 and int(leave_outcome.get("scraps", 1)) == 0,
				"Leave is the zero-delta choice: " + event_id)


func _test_earlier_anchors() -> void:
	for event_id in EARLIER_ANCHORS:
		var anchor: Dictionary = EARLIER_ANCHORS[event_id]
		var matches := _matches(event_id)
		_check(matches.size() == 1, "earlier record still present exactly once: " + event_id)
		if matches.size() != 1:
			continue
		var record: Dictionary = matches[0]
		_check(record.get("title") == anchor["title"], "earlier title unchanged: " + event_id)
		var found := false
		for choice in record.get("choices", []):
			if choice is Dictionary and choice.get("id") == anchor["choice"]:
				var outcome: Dictionary = choice.get("outcome", {})
				found = int(outcome.get("gold", 0)) == int(anchor["gold"]) \
					and int(outcome.get("scraps", 0)) == int(anchor["scraps"])
		_check(found, "earlier choice delta unchanged: " + event_id + "/" + str(anchor["choice"]))


func _test_hero_gates() -> void:
	var parties := [PARTY_A, PARTY_B]
	for party in parties:
		var service := RunV3HeroEventOffers.new(party)
		_check(service.is_valid(), "canonical party builds a valid offer service: " + str(party))
		if not service.is_valid():
			continue
		var offers: Array = service.get_offers()
		for event_id in EVENTS:
			var required_hero: String = EVENTS[event_id]["required_hero"]
			var eligible: bool = party.has(required_hero)
			var offer := _offer(event_id, offers)
			_check(not offer.is_empty() == eligible,
				"offer admits iff the required hero is in the party: " + event_id + str(party))
			var visit := service.enter(event_id)
			if not eligible:
				_check(visit == null, "absent hero denies entry: " + event_id + str(party))
				continue
			_check(visit is RunEventChoice and visit.is_valid() and not visit.is_claimed(),
				"present hero opens a real unclaimed visit: " + event_id + str(party))
			if visit == null:
				continue
			var authored := _matches(event_id)
			_check(authored.size() == 1 and visit.get_event() == authored[0],
				"visit carries the authentic authored snapshot: " + event_id + str(party))
		for bad_id in ["", "v3_fogbound_missing", "v3_lantern_monk_moth_vigil", 1, null]:
			_check(service.enter(bad_id) == null,
				"entry only accepts eligible authored IDs: " + str(bad_id))
	# Each new record is gated by exactly one of the two complementary parties.
	for event_id in EVENTS:
		var in_a: bool = PARTY_A.has(EVENTS[event_id]["required_hero"])
		var in_b: bool = PARTY_B.has(EVENTS[event_id]["required_hero"])
		_check(in_a != in_b, "record is admitted by exactly one complementary party: " + event_id)


func _test_detached_offers() -> void:
	var authored := {}
	for event_id in EVENTS:
		var matches := _matches(event_id)
		_check(matches.size() == 1, "detached-offer fixture has one authored record: " + event_id)
		if matches.size() == 1:
			authored[event_id] = matches[0].duplicate(true)
	for party in [PARTY_A, PARTY_B]:
		var service := RunV3HeroEventOffers.new(party)
		_check(service.is_valid(), "detached-offer service is valid: " + str(party))
		if not service.is_valid():
			continue
		for event_id in authored:
			if not party.has(EVENTS[event_id]["required_hero"]):
				continue
			var offer := _offer(event_id, service.get_offers())
			_check(not offer.is_empty(), "eligible offer is present: " + event_id + str(party))
			if offer.is_empty():
				continue
			offer["title"] = "mutated offer title"
			offer["required_hero"] = "mutated_hero"
			(offer["hero_choice_ids"] as Array).append("injected_choice")
			var offer_choices: Array = offer["choices"]
			(offer_choices[0]["outcome"] as Dictionary)["gold"] = 9999
			_check(_offer(event_id, service.get_offers()) == authored[event_id],
				"mutating a returned offer never reaches the service: " + event_id)
			_check(service.enter(event_id).get_event() == authored[event_id],
				"mutated offer never reaches a new visit: " + event_id)
			var live := _matches(event_id)
			_check(live.size() == 1 and live[0] == authored[event_id],
				"mutating a returned offer never reaches the catalog: " + event_id)


func _test_funded_receipts() -> void:
	for event_id in EVENTS:
		var spec: Dictionary = EVENTS[event_id]
		var party := _party_for(spec["required_hero"])
		var service := RunV3HeroEventOffers.new(party)
		_check(service.is_valid(), "funded matrix has a valid service: " + event_id)
		if not service.is_valid():
			continue
		var choices: Dictionary = spec["choices"]
		for choice_id in choices:
			var wanted: Dictionary = choices[choice_id]
			var label: String = event_id + "/" + str(choice_id)
			var visit := service.enter(event_id)
			_check(visit != null and visit.is_valid() and not visit.is_claimed(),
				"fresh funded visit: " + label)
			if visit == null:
				continue
			var wallet := {"gold": FUNDED_GOLD, "scraps": FUNDED_SCRAPS}
			var wallet_before: Dictionary = wallet.duplicate(true)
			var projected := {
				"gold": FUNDED_GOLD + int(wanted["gold"]),
				"scraps": FUNDED_SCRAPS + int(wanted["scraps"]),
			}
			var preview := visit.preview_wallet_choices(wallet)
			_check(preview.get("ok") == true and preview.get("event_id") == event_id,
				"funded preview is authentic: " + label)
			_check(_choice_entry(preview, choice_id) == {
				"choice_id": choice_id, "gold_delta": int(wanted["gold"]),
				"scraps_delta": int(wanted["scraps"]), "affordable": true, "wallet": projected,
			}, "funded preview quotes the exact authored delta: " + label)
			_check(wallet == wallet_before, "preview leaves the source wallet unchanged: " + label)
			var receipt := visit.choose_with_wallet(choice_id, wallet)
			_check(receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id,
				"wallet": projected}, "funded choice settles the exact wallet: " + label)
			_check(wallet == wallet_before, "settlement leaves the source wallet unchanged: " + label)
			_check(visit.is_claimed() and not visit.is_valid(), "settled visit latches its claim: " + label)
			_check(visit.preview_wallet_choices(projected) == {"ok": false, "event_id": "", "choices": []},
				"claimed visit refuses a second preview: " + label)
			_check(visit.choose_with_wallet(choice_id, projected) == {"ok": false, "event_id": "",
				"choice_id": "", "wallet": projected}, "claimed visit cannot replay its choice: " + label)
			_check(not visit.choose_with_wallet(_other_choice(choices, choice_id), projected)["ok"],
				"claimed visit cannot settle an alternate choice: " + label)


func _test_unaffordable_choices() -> void:
	for event_id in EVENTS:
		var spec: Dictionary = EVENTS[event_id]
		var party := _party_for(spec["required_hero"])
		var service := RunV3HeroEventOffers.new(party)
		_check(service.is_valid(), "affordability matrix has a valid service: " + event_id)
		if not service.is_valid():
			continue
		var choices: Dictionary = spec["choices"]
		for choice_id in choices:
			var wanted: Dictionary = choices[choice_id]
			var gold := int(wanted["gold"])
			var scraps := int(wanted["scraps"])
			var label: String = event_id + "/" + str(choice_id)
			var empty := {"gold": 0, "scraps": 0}
			if gold >= 0 and scraps >= 0:
				var free_visit := service.enter(event_id)
				_check(free_visit != null and free_visit.is_valid(), "fresh zero-wallet visit: " + label)
				if free_visit == null:
					continue
				var free_receipt := free_visit.choose_with_wallet(choice_id, empty)
				_check(free_receipt == {"ok": true, "event_id": event_id, "choice_id": choice_id,
					"wallet": {"gold": gold, "scraps": scraps}},
					"zero-wallet visit still takes a free choice: " + label)
				continue
			var visit := service.enter(event_id)
			_check(visit != null and visit.is_valid(), "fresh zero-wallet visit: " + label)
			if visit == null:
				continue
			var preview := visit.preview_wallet_choices(empty)
			var quote := _choice_entry(preview, choice_id)
			_check(quote.get("affordable") == false and quote.get("wallet") == empty,
				"empty wallet previews the cost as unaffordable: " + label)
			_check(visit.choose_with_wallet(choice_id, empty) == {"ok": false, "event_id": "",
				"choice_id": "", "wallet": empty},
				"empty wallet refuses the paid choice unchanged: " + label)
			_check(visit.is_valid() and not visit.is_claimed(),
				"unaffordable refusal consumes no claim: " + label)
			var short := {"gold": 0, "scraps": 0}
			if gold < 0:
				short = {"gold": -gold - 1, "scraps": 0}
			else:
				short = {"gold": 0, "scraps": -scraps - 1}
			var short_visit := service.enter(event_id)
			_check(short_visit != null and short_visit.is_valid(), "fresh one-short visit: " + label)
			if short_visit == null:
				continue
			_check(short_visit.choose_with_wallet(choice_id, short) == {"ok": false, "event_id": "",
				"choice_id": "", "wallet": short},
				"one-unit-short wallet is rejected unchanged: " + label)
			_check(not short_visit.is_claimed(), "one-short refusal consumes no claim: " + label)
			var leave_receipt := visit.choose_with_wallet("leave", empty)
			_check(leave_receipt == {"ok": true, "event_id": event_id, "choice_id": "leave",
				"wallet": empty} and visit.is_claimed(),
				"authored Leave still settles on the refused visit: " + label)
