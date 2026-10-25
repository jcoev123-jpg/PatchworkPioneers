extends SceneTree
## Deterministic headless test for V3-4 roadside event pack.

const EVENTS_PATH := "res://data/events/v3_roadside_events.json"

const EXPECTED := {
	"v3_raincoat_bridge": {
		"title": "The Raincoat Bridge",
		"description": "A soaked quilt bridge stretching over a ravine.",
		"choices": ["salvage_hems", "trade_fare", "take_detour"],
		"outcomes": {
			"salvage_hems": {"gold": 0, "scraps": 1},
			"trade_fare": {"gold": -12, "scraps": 2},
			"take_detour": {"gold": 0, "scraps": 0}
		}
	},
	"v3_puppet_box_office": {
		"title": "The Puppet Box Office",
		"description": "Rag puppets wait under a patchwork theatre awning.",
		"choices": ["perform", "restring", "applaud"],
		"outcomes": {
			"perform": {"gold": 9, "scraps": 0},
			"restring": {"gold": 24, "scraps": -2},
			"applaud": {"gold": 0, "scraps": 0}
		}
	},
	"v3_mismatched_mittens": {
		"title": "The Mismatched Mittens",
		"description": "A merchant untangling sewn pairs of mismatched mittens.",
		"choices": ["untangle", "trade_copper", "sell_pair"],
		"outcomes": {
			"untangle": {"gold": 0, "scraps": 1},
			"trade_copper": {"gold": -15, "scraps": 2},
			"sell_pair": {"gold": 18, "scraps": -1}
		}
	},
	"v3_coil_and_crow": {
		"title": "The Coil and Crow",
		"description": "A crow guarding a copper-coloured thread wheel.",
		"choices": ["chase_crow", "buy_coil", "back_away"],
		"outcomes": {
			"chase_crow": {"gold": 6, "scraps": 0},
			"buy_coil": {"gold": -20, "scraps": 3},
			"back_away": {"gold": 0, "scraps": 0}
		}
	},
	"v3_patchwork_lighthouse": {
		"title": "The Patchwork Lighthouse",
		"description": "Fabric fog gathers around a dim stitched beacon.",
		"choices": ["gather_threads", "repair_beacon", "pass_by"],
		"outcomes": {
			"gather_threads": {"gold": 0, "scraps": 1},
			"repair_beacon": {"gold": 26, "scraps": -2},
			"pass_by": {"gold": 0, "scraps": 0}
		}
	},
	"v3_button_orchard": {
		"title": "The Button Orchard",
		"description": "Brass buttons hang heavily on felt branches.",
		"choices": ["pick_buttons", "ribbon_trade", "sell_harvest"],
		"outcomes": {
			"pick_buttons": {"gold": 0, "scraps": 1},
			"ribbon_trade": {"gold": -14, "scraps": 2},
			"sell_harvest": {"gold": 20, "scraps": -1}
		}
	}
}

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run_tests()
	if failures.is_empty():
		print("v3_roadside_events_test: PASS (", checks, " checks)")
		quit(0)
	else:
		for failure in failures:
			printerr(failure)
		print("v3_roadside_events_test: FAIL (", checks, " checks)")
		quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _run_tests() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	_check(file != null, "v3_roadside_events.json opens through FileAccess")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	var parse_result := parser.parse(text)
	_check(parse_result == OK, "v3_roadside_events.json parses through JSON")
	if parse_result != OK:
		return
	
	var data: Dictionary = parser.data
	var events: Array = data.get("events", [])
	
	var parsed_events := {}
	for entry in events:
		if entry is Dictionary and entry.has("id"):
			parsed_events[entry["id"]] = entry
	
	_check(parsed_events.size() == 6, "Parsing yields six distinct event records")
	
	for expected_id in EXPECTED:
		_check(parsed_events.has(expected_id), "Found expected ID: " + expected_id)
		if not parsed_events.has(expected_id):
			continue
		
		var record: Dictionary = parsed_events[expected_id]
		var expected: Dictionary = EXPECTED[expected_id]
		
		var title: String = expected["title"]
		_check(record.get("title", "") != "", "Matches non-blank title: " + expected_id)
		_check(record.get("description", "") != "", "Matches non-blank description: " + expected_id)
		
		var choices: Array = record.get("choices", [])
		_check(choices.size() == 3, "Has exactly 3 choices: " + expected_id)
		
		var choice_ids := []
		for choice in choices:
			choice_ids.append(choice.get("id"))
			_check(choice.get("text", "") != "", "Choice text is nonblank: " + choice.get("id", ""))
			var outcome: Dictionary = choice.get("outcome", {})
			_check(outcome.has("gold") and outcome.has("scraps"), "Outcome has gold and scraps: " + choice.get("id", ""))
			
			var expected_outcome: Dictionary = expected["outcomes"][choice["id"]]
			_check(int(outcome["gold"]) == expected_outcome["gold"] and int(outcome["scraps"]) == expected_outcome["scraps"], 
				"Matches expected outcome for: " + expected_id + " -> " + choice["id"])
		
		for cid in expected["choices"]:
			_check(cid in choice_ids, "Expected choice ID is present: " + expected_id + " -> " + cid)
			
		# Test with wallet {gold: 100, scraps: 5} (sufficient funds)
		var test_wallet := {"gold": 100, "scraps": 5}
		var service_preview := RunEventChoice.new(record)
		var previews: Dictionary = service_preview.preview_wallet_choices(test_wallet)
		_check(previews.get("ok", false), "Preview successful for: " + expected_id)
		
		for choice in choices:
			var cid: String = choice["id"]
			var outcome: Dictionary = choice["outcome"]
			
			# Preview check
			var is_affordable := false
			for p in previews.get("choices", []):
				if p.get("choice_id") == cid:
					is_affordable = p.get("affordable", false)
					break
			_check(is_affordable, "Choice should be affordable with 100 gold, 5 scraps: " + cid)
			
			var service_commit := RunEventChoice.new(record)
			var original_record := record.duplicate(true)
			var commit_result := service_commit.choose_with_wallet(cid, test_wallet.duplicate(true))
			_check(commit_result.get("ok", false), "Commit successful for: " + cid)
			
			var new_wallet: Dictionary = commit_result.get("wallet", {})
			var expected_gold: int = 100 + int(outcome["gold"])
			var expected_scraps: int = 5 + int(outcome["scraps"])
			_check(int(new_wallet["gold"]) == expected_gold and int(new_wallet["scraps"]) == expected_scraps, "Wallet exact match for: " + cid)
			_check(service_commit.is_claimed(), "Service is claimed after commit")
			
			var second_commit := service_commit.choose_with_wallet(cid, new_wallet)
			_check(not second_commit.get("ok", true), "Second commit rejected for: " + cid)
			_check(service_commit.get_event() == original_record, "Original record deeply unchanged")

		# Test with wallet {gold: 0, scraps: 0}
		var zero_wallet := {"gold": 0, "scraps": 0}
		var service_zero := RunEventChoice.new(record)
		var previews_zero: Dictionary = service_zero.preview_wallet_choices(zero_wallet)
		for choice in choices:
			var cid: String = choice["id"]
			var outcome: Dictionary = choice["outcome"]
			var requires_payment: bool = outcome["gold"] < 0 or outcome["scraps"] < 0
			
			var is_affordable := true
			for p in previews_zero.get("choices", []):
				if p.get("choice_id") == cid:
					is_affordable = p.get("affordable", true)
					break
			
			if requires_payment:
				_check(not is_affordable, "Choice requires payment and is unaffordable at zero: " + cid)
				var service_fail := RunEventChoice.new(record)
				var fail_result := service_fail.choose_with_wallet(cid, zero_wallet)
				_check(not fail_result.get("ok", true), "Commit rejected for insufficient funds: " + cid)
				_check(not service_fail.is_claimed(), "Claim not consumed on failed commit: " + cid)
				
				# After failure, free choices should still work
				var free_cid := ""
				var expected_free_gold := 0
				var expected_free_scraps := 0
				for c in choices:
					if c["outcome"]["gold"] >= 0 and c["outcome"]["scraps"] >= 0:
						free_cid = c["id"]
						expected_free_gold = int(c["outcome"]["gold"])
						expected_free_scraps = int(c["outcome"]["scraps"])
						break
				
				if free_cid != "":
					var recover_result := service_fail.choose_with_wallet(free_cid, zero_wallet)
					_check(recover_result.get("ok", false), "Recovered and committed free choice: " + free_cid)
					_check(service_fail.is_claimed(), "Service now claimed")
					var rec_wallet: Dictionary = recover_result.get("wallet", {})
					_check(int(rec_wallet["gold"]) == expected_free_gold and int(rec_wallet["scraps"]) == expected_free_scraps, "Wallet updated correctly on free choice")
			else:
				_check(is_affordable, "Free choice is affordable at zero: " + cid)
