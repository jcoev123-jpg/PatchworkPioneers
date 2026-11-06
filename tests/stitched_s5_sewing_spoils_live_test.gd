extends SceneTree
## S5: authentic title Roadblock victory -> displayed Sewing Circle -> next Fight Snip.
var failures: Array[String] = []
var checks := 0
const CLAW := "scissor_crab_claw_arm"
const SACK := "fray_scavenger_sack_arm"
const INK := "moth_scribe_inkbrush_arm"


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)


func _spawn() -> Node:
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	return app


func _no_wallet(app: Node) -> bool:
	return app.deck == null and app.run_map == null and app.run_rng == null \
		and app.session_gold == 0 and app.run_scraps == 0 and app.run_deck.is_empty()


func _admit(app: Node) -> StitchedBattleScreen:
	app._open_stitched_fight() # Explicit Roadblock regression entry.
	# Let the authored Roadblock's deferred focus settle, as real input does.
	await process_frame
	var offer: LiveEventChoicePanel = app.stitched_event_panel
	if offer == null or not offer.has_open_event() or offer.get_choice_buttons().size() != 3:
		return null
	offer.get_choice_buttons()[0].pressed.emit()
	await process_frame
	return app.stitched_fight_view


func _fight_to_victory(stage: StitchedBattleScreen) -> Dictionary:
	if stage == null or stage.battle == null:
		return {}
	var initial: Dictionary = stage.battle.state_snapshot()
	var steps := 0
	var abilities := 0
	# All damage, healing and enemy replies go through the mounted screen,
	# never through fixture HP edits, outcome assignment, or a mock service.
	for iteration in range(90):
		if stage.battle.is_over():
			break
		if stage.battle.current_side() != "hero":
			break
		var actor: Dictionary = stage.battle.get_unit(stage.battle.current_actor_id())
		var best_score := -10000
		var best_id := ""
		var best_rank := 0
		for slot in StitchedParts.SLOTS:
			if not stage._valid_part(actor, actor["parts"][slot]):
				continue
			var id := str(actor["parts"][slot]["id"])
			var definition: Dictionary = stage.parts.get(id, {})
			var skill: Dictionary = StitchedParts.ability_at_tier(
				definition, int(actor["parts"][slot]["tier"]))
			for rank in range(1, 5):
				var legal: Array = stage.battle._legal_targets(actor, skill, rank)
				if legal.is_empty():
					continue
				var side := str(legal[0]["side"])
				var score := -20
				if side == "foe":
					score = int(skill.get("dmg", [0, 0])[1]) * 4 + int(skill.get("dmg", [0, 0])[0])
					if str(skill.get("kind", "")) == "ranged":
						score += 1
					if rank == 1:
						score += 3
				elif str(skill.get("kind", "")) == "heal":
					var ally: Dictionary = stage._unit_at("hero", rank)
					var missing: int = int(ally.get("max_hp", 0)) - int(ally.get("hp", 0))
					if missing >= 8:
						score = 38 + missing
				if score > best_score:
					best_score = score
					best_id = id
					best_rank = rank
		var receipt: Dictionary
		if not best_id.is_empty():
			receipt = stage.submit_part(best_id, best_rank)
			if receipt.get("ok") == true and receipt.get("action") == "ability":
				abilities += 1
		else:
			receipt = stage.submit_pass()
		if receipt.get("ok") != true:
			break
		steps += 1
	return {"initial": initial, "steps": steps, "abilities": abilities,
		"outcome": stage.battle.outcome(), "state": stage.battle.state_snapshot(),
		"rng": stage.battle.rng_state(), "receipts": stage.receipts.duplicate(true)}


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var app := _spawn()
	await process_frame
	_check(_no_wallet(app) and app.stitched_preview_satchel.is_empty(),
		"the title begins without a virtual wallet or pre-awarded claw")
	var escape: StitchedBattleScreen = await _admit(app)
	_check(escape != null and escape.battle.is_valid() and app.stitched_sewing_panel == null,
		"a genuine Roadblock Fight is mounted before any spoils exist")
	if escape == null:
		_finish()
		return
	escape._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and app.stitched_sewing_visit == null \
		and app.title_view.is_visible_in_tree() and _no_wallet(app),
		"unwon Back produces no claw and restores title")
	var retreat: StitchedBattleScreen = await _admit(app)
	_check(retreat != null and retreat.battle.is_valid(), "a second authenticated Roadblock is available")
	if retreat == null:
		_finish()
		return
	for turn in range(100):
		if retreat.battle.is_over():
			break
		if retreat.battle.current_side() != "hero":
			break
		retreat._action_buttons["retreat"].pressed.emit()
	_check(retreat.battle.is_over() and retreat.battle.outcome() in ["retreated", "defeat"],
		"non-victory is terminal combat, not a fabricated outcome")
	retreat._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and app.stitched_sewing_panel == null \
		and _no_wallet(app), "terminal non-victory never mints a claw or opens the Circle")
	var stage: StitchedBattleScreen = await _admit(app)
	if stage == null:
		_check(false, "winner fight admitted through the real title")
		_finish()
		return
	var witness := _fight_to_victory(stage)
	_check(int(witness.get("steps", 0)) > 0 and int(witness.get("abilities", 0)) > 0 \
		and stage.battle.get_foes().size() == 3 and stage.battle.get_unit("scissor_crab").get("dead") == true \
		and stage.battle.get_unit("fray_scavenger").get("dead") == true \
		and stage.battle.get_unit("moth_scribe").get("dead") == true \
		and witness.get("outcome") == "victory",
		"mounted hero actions defeat all foes including Crab: " + str(witness.get("outcome", "")) + " / steps=" + str(witness.get("steps", 0)))
	if witness.get("outcome") != "victory":
		stage._action_buttons["exit"].pressed.emit()
		await process_frame
		_finish()
		return
	# A naturally earned post-battle service must also reject torn worn gear.
	# Force only this negative precondition on a real battle unit; combat
	# admission, kills, victory and all reward settlement remain live.
	var torn_hero := ""
	for hero in stage.battle.get_heroes():
		if not bool(hero.get("lost", false)):
			torn_hero = str(hero["id"])
			stage.battle._units[torn_hero]["parts"]["arms"]["torn"] = true
			break
	_check(not torn_hero.is_empty(), "a surviving real hero supplies the torn-gear witness")
	seed(820151)
	var expected_global := randi()
	seed(820151)
	var old_stage := stage
	stage._action_buttons["exit"].pressed.emit()
	var visit: RunStitchedSewingSwap = app.stitched_sewing_visit
	var panel: Control = app.stitched_sewing_panel
	_check(app.stitched_fight_view == null and old_stage.battle == null \
		and visit != null and panel != null and panel.is_visible_in_tree() \
		and not app.title_view.is_visible_in_tree(),
		"completed battle retires its authority before a gothic Sewing Circle is mounted")
	if panel == null or visit == null:
		_finish()
		return
	await process_frame
	var quote: Dictionary = visit.quote()
	_check(quote.get("ok") == true and quote.get("open") == true \
		and quote.get("satchel_count") == 3 and quote.get("satchel_max") == 6 \
		and quote["satchel"][0]["id"] == CLAW and quote["satchel"][0]["tier"] == 1 \
		and quote["satchel"][1]["id"] == SACK and quote["satchel"][1]["tier"] == 1 \
		and quote["satchel"][1]["slot"] == "arms" and not quote["satchel"][1]["torn"] \
		and quote["satchel"][2]["id"] == INK and quote["satchel"][2]["tier"] == 1 \
		and quote["satchel"][2]["slot"] == "arms" and not quote["satchel"][2]["torn"] \
		and not quote["satchel"][0]["torn"] and _no_wallet(app),
		"authentic claw, sack and inkbrush are earned in order in the six-slot satchel")
	var blocked_torn := false
	for hero_row in quote["heroes"]:
		if str(hero_row["hero_id"]) != torn_hero:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == "arms":
				blocked_torn = not bool(slot_row["can_swap"]) \
					and str(slot_row["blocked"]).contains("torn") \
					and slot_row["offers"].is_empty()
	_check(blocked_torn, "the real mounted Circle shows a torn arm as blocked, with no offered swap")
	var buttons: Array = panel.find_children("Swap_*", "Button", true, false)
	var offers_found := 0
	var sack_offers := 0
	var ink_offers := 0
	var winner_id := ""
	for hero_row in quote["heroes"]:
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) == "arms" and bool(slot_row["can_swap"]):
				for option in slot_row["offers"]:
					if option["part"]["id"] == CLAW:
						offers_found += 1
						if winner_id.is_empty():
							winner_id = str(hero_row["hero_id"])
					elif option["part"]["id"] == SACK:
						sack_offers += 1
					elif option["part"]["id"] == INK:
						ink_offers += 1
	_check(offers_found > 0 and sack_offers == offers_found and ink_offers == offers_found \
		and buttons.size() == offers_found + sack_offers + ink_offers and not winner_id.is_empty(),
		"the displayed choice buttons exactly match real compatible hero/arms quotes")
	var old_state: Dictionary = quote["state"].duplicate(true)
	var before_satchel: Array = app.stitched_preview_satchel.duplicate(true)
	_check(not app._stitched_sewing_swap(torn_hero, "arms", 0, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(winner_id, "legs", 0, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(winner_id, "arms", 9, old_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap("impostor", "arms", 0, old_state, weakref(panel)).get("ok") \
		and app.stitched_preview_satchel == before_satchel \
		and visit.read_state() == old_state and randi() == expected_global and _no_wallet(app),
		"forged hero, wrong slot, invalid index leave items, versions, RNG and wallet untouched")
	var old_button: Button = buttons[0]
	var selected_id := str(old_button.name).trim_prefix("Swap_").rsplit("_", true, 1)[0]
	var equipped_before: Array = app._stitched_floor_config()["heroes"].duplicate(true)
	old_button.pressed.emit()
	var committed: Dictionary = visit.read_state()
	_check(int(committed.get("version", 0)) == 1 and committed["satchel"].size() == 3 \
		and committed["satchel"][0]["id"] != CLAW and committed["satchel"][1]["id"] == SACK \
		and committed["satchel"][2]["id"] == INK \
		and app._stitched_gear_overrides.get(selected_id, {}).get("arms", {}).get("id") == CLAW \
		and app.stitched_preview_satchel == committed["satchel"] and _no_wallet(app),
		"visible Sewing Circle click commits once, replacing the old arms without spending")
	var changed_before := committed.duplicate(true)
	seed(340721)
	var replay_expected := randi()
	seed(340721)
	_check(not app._stitched_sewing_swap(selected_id, "arms", 0, old_state, weakref(panel)).get("ok") \
		and not visit.swap(selected_id, "arms", 0, "wrong-node", old_state).get("ok") \
		and not visit.swap(selected_id, "arms", 0, "s5_scissor_crab_sewing_circle", old_state).get("ok") \
		and visit.read_state() == changed_before \
		and app.stitched_preview_satchel == committed["satchel"] and randi() == replay_expected,
		"duplicate, stale and wrong-node commits are rejected without inventory mutation")
	# Test RNG rejection using a fresh known global seed (previous check read once).
	seed(559201)
	var rng_expected := randi()
	seed(559201)
	var fresh_state: Dictionary = visit.read_state()
	_check(not app._stitched_sewing_swap(selected_id, "torso", 0, fresh_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_leave(old_state, weakref(panel)).get("ok") \
		and visit.read_state() == fresh_state and randi() == rng_expected and _no_wallet(app),
		"wrong-slot and stale Leave fail closed without spending or RNG")
	var leave: Button = panel.get_node("SewingLeave")
	leave.pressed.emit()
	_check(app.stitched_sewing_panel == null and app.stitched_sewing_visit == null \
		and app.title_view.is_visible_in_tree() and app.stitched_preview_satchel.size() == 3,
		"mounted Leave closes the Circle exactly once and restores title")
	_check(not app._stitched_sewing_leave(fresh_state, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap(selected_id, "arms", 0, fresh_state, weakref(panel)).get("ok"),
		"stale callbacks cannot reopen or change equipment after Leave")
	await process_frame
	var next_config: Dictionary = app._stitched_floor_config()
	var expected_gear: Dictionary = {}
	for hero in equipped_before:
		if str(hero["id"]) == selected_id:
			expected_gear = hero["parts"]
	var selected_next: Dictionary = {}
	for hero in next_config["heroes"]:
		if str(hero["id"]) == selected_id:
			selected_next = hero["parts"]
	var gear_ok: bool = selected_next.get("arms", {}).get("id") == CLAW
	for slot in ["head", "torso", "legs"]:
		gear_ok = gear_ok and selected_next.get(slot) == expected_gear.get(slot)
	_check(gear_ok and next_config.get("seed") == 4982026 and next_config["foes"].size() == 3,
		"next title config carries only the exchanged arms, preserving other gear, foes and replay seed")
	var next: StitchedBattleScreen = await _admit(app)
	_check(next != null and next.battle.get_unit(selected_id).get("parts", {}).get("arms", {}).get("id") == CLAW,
		"next authenticated Roadblock Fight actually equips the carried claw")
	if next != null:
		var snip_ok := false
		for turn in range(45):
			if next.battle.is_over() or next.battle.current_side() != "hero":
				break
			if next.battle.current_actor_id() == selected_id and next.select_part("arms"):
				for key in next.legal_targets():
					if str(key).begins_with("foe_"):
						var before_count := next.receipts.size()
						var result: Dictionary = next.submit_target("foe", int(str(key).split("_")[1]))
						snip_ok = result.get("ok") == true and next.receipts.size() > before_count \
							and str(result.get("ability")) == "snip"
						break
			if snip_ok:
				break
			next.submit_pass()
		_check(snip_ok, "authored Snip executes through the mounted next Fight and emits a combat receipt")
		next._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_sewing_panel == null and _no_wallet(app),
		"non-victory second Fight adds no new drops or wallet")

	# At five carried spares, the deterministic claw has priority; the sack
	# cannot overfill the sixth slot or displace the existing five parts.
	var nearly_full: Array = []
	for index in range(RunStitchedSewingSwap.SATCHEL_CAP - 1):
		nearly_full.append({"id": CLAW, "slot": "arms", "tier": 1, "torn": false})
	app.stitched_preview_satchel = nearly_full.duplicate(true)
	var near_stage: StitchedBattleScreen = await _admit(app)
	_check(near_stage != null, "five-spare capacity witness admits live Roadblock")
	if near_stage != null:
		var near_witness: Dictionary = _fight_to_victory(near_stage)
		_check(near_witness.get("outcome") == "victory" \
			and near_stage.battle.get_unit("ragling").get("dead") == true,
			"five-spare witness really defeats follow-on Ragling before reward settlement")
		if near_witness.get("outcome") == "victory":
			seed(93172)
			var near_global := randi()
			seed(93172)
			near_stage._action_buttons["exit"].pressed.emit()
			var near_visit: RunStitchedSewingSwap = app.stitched_sewing_visit
			var near_expected: Array = nearly_full.duplicate(true)
			near_expected.append({"id": CLAW, "slot": "arms", "tier": 1, "torn": false})
			_check(near_visit != null and app.stitched_preview_satchel == near_expected \
				and app.stitched_preview_satchel.size() == RunStitchedSewingSwap.SATCHEL_CAP \
				and near_stage.battle == null and randi() == near_global and _no_wallet(app),
				"one remaining slot receives claw only: no sack overflow, wallet or global RNG")
			if near_visit != null:
				app.stitched_sewing_panel.get_node("SewingLeave").pressed.emit()
				_check(app.stitched_sewing_visit == null and app.title_view.is_visible_in_tree(),
					"near-full reward service closes after one authorized Leave")
		else:
			near_stage._action_buttons["exit"].pressed.emit()
	# A cap-state representing six previously earned parts receives no seventh
	# drop, even after another *real* mounted Scissor Crab victory.
	var full_satchel: Array = []
	for index in range(RunStitchedSewingSwap.SATCHEL_CAP):
		full_satchel.append({"id": CLAW, "slot": "arms", "tier": 1, "torn": false})
	app.stitched_preview_satchel = full_satchel.duplicate(true)
	var cap_stage: StitchedBattleScreen = await _admit(app)
	if cap_stage != null:
		var cap_witness: Dictionary = _fight_to_victory(cap_stage)
		_check(cap_witness.get("outcome") == "victory" and int(cap_witness.get("steps", 0)) > 0,
			"full-cap test still defeats Scissor Crab through an authenticated mounted Fight")
		if cap_witness.get("outcome") == "victory":
			seed(901721)
			var cap_rng := randi()
			seed(901721)
			cap_stage._action_buttons["exit"].pressed.emit()
			var cap_visit: RunStitchedSewingSwap = app.stitched_sewing_visit
			_check(cap_visit != null and app.stitched_preview_satchel == full_satchel \
				and cap_visit.quote().get("satchel_count") == RunStitchedSewingSwap.SATCHEL_CAP \
				and randi() == cap_rng and _no_wallet(app),
				"a full satchel prevents a seventh drop without RNG or wallet mutation")
			if cap_visit != null:
				var cap_panel: Control = app.stitched_sewing_panel
				cap_panel.get_node("SewingLeave").pressed.emit()
				_check(app.stitched_sewing_panel == null and app.title_view.is_visible_in_tree(),
					"full-cap Sewing Circle still Leaves cleanly")
		else:
			cap_stage._action_buttons["exit"].pressed.emit()
	else:
		_check(false, "full-cap Roadblock Fight admitted from real title")
	app.free()
	await process_frame
	await _run_sack_path()
	await _run_inkbrush_path()
	await _run_defeat_path()
	_finish()



func _run_sack_path() -> void:
	var catalog: Dictionary = StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
	var entry: Dictionary = catalog.get("by_id", {}).get(SACK, {})
	var tier1: Dictionary = StitchedParts.ability_at_tier(entry, 1) if not entry.is_empty() else {}
	var tier2: Dictionary = StitchedParts.ability_at_tier(entry, 2) if not entry.is_empty() else {}
	var tier3: Dictionary = StitchedParts.ability_at_tier(entry, 3) if not entry.is_empty() else {}
	_check(catalog.get("ok") == true and str(entry.get("slot", "")) == "arms" \
		and entry.get("owner") == "any" and entry.get("stat", {}).get("dmg") == 1 \
		and tier1.get("id") == "sack_sweep" and tier1.get("name") == "Sack Sweep" \
		and tier1.get("kind") == "melee" and tier1.get("launch") == [1, 2] \
		and tier1.get("target") == [1, 2] and tier1.get("acc") == 88 \
		and tier1.get("dmg") == [3, 5] and tier1.get("effects") == {"weak": 1} \
		and tier1.get("move") == "attack2" \
		and tier2.get("dmg") == [4, 6] and tier3.get("dmg") == [5, 7],
		"Scavenger part has schema-compliant, unique Sack Sweep and both valid tier upgrades")
	var app := _spawn()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and _no_wallet(app),
		"fresh sack path has no pre-awarded loot or wallet")
	var stage: StitchedBattleScreen = await _admit(app)
	if stage == null:
		_check(false, "sack path requires a mounted, authenticated Roadblock")
		app.free()
		await process_frame
		return
	var fight: Dictionary = _fight_to_victory(stage)
	_check(fight.get("outcome") == "victory" and int(fight.get("steps", 0)) > 0 \
		and stage.battle.get_unit("fray_scavenger").get("dead") == true \
		and stage.battle.get_unit("scissor_crab").get("dead") == true,
		"real Sack path defeats both trophy foes with mounted hero actions")
	if fight.get("outcome") != "victory":
		stage._action_buttons["exit"].pressed.emit()
		app.free()
		await process_frame
		return
	seed(785321)
	var reward_global := randi()
	seed(785321)
	stage._action_buttons["exit"].pressed.emit()
	var visit: RunStitchedSewingSwap = app.stitched_sewing_visit
	var panel: Control = app.stitched_sewing_panel
	_check(visit != null and panel != null and app.stitched_preview_satchel.size() == 3 \
		and app.stitched_preview_satchel[0]["id"] == CLAW \
		and app.stitched_preview_satchel[1]["id"] == SACK \
		and app.stitched_preview_satchel[2]["id"] == INK \
		and randi() == reward_global and _no_wallet(app),
		"real win earns one claw then one sack, with global RNG and wallet unchanged")
	if visit == null or panel == null:
		app.free()
		await process_frame
		return
	await process_frame
	var quote: Dictionary = visit.quote()
	var chosen := ""
	var index := -1
	for hero in quote.get("heroes", []):
		if not str(hero["hero_id"]) in ["warden", "seamstress"]:
			continue
		for slot in hero["slots"]:
			if slot["slot"] != "arms" or not bool(slot["can_swap"]):
				continue
			for offer in slot["offers"]:
				if offer["part"]["id"] == SACK and chosen.is_empty():
					chosen = str(hero["hero_id"])
					index = int(offer["satchel_index"])
	var button: Button = (panel.find_child("Swap_%s_%d" % [chosen, index], true, false) as Button) if index >= 0 else null
	_check(button != null and index == 1 and not chosen.is_empty(),
		"visible quoted sack exchange is available to a surviving front-launch hero")
	if button == null:
		panel.get_node("SewingLeave").pressed.emit()
		app.free()
		await process_frame
		return
	var stale: Dictionary = quote["state"].duplicate(true)
	seed(903221)
	var exchange_global := randi()
	seed(903221)
	button.pressed.emit()
	var swapped: Dictionary = visit.read_state()
	_check(swapped.get("version") == 1 and swapped.get("satchel", []).size() == 3 \
		and app._stitched_gear_overrides.get(chosen, {}).get("arms", {}).get("id") == SACK \
		and app.stitched_preview_satchel == swapped["satchel"] \
		and randi() == exchange_global and _no_wallet(app),
		"real sack button commits exactly one quoted arms exchange without cost")
	var before_replay: Array = app.stitched_preview_satchel.duplicate(true)
	seed(544411)
	var replay_global := randi()
	seed(544411)
	_check(not app._stitched_sewing_swap(chosen, "arms", index, stale, weakref(panel)).get("ok") \
		and not app._stitched_sewing_swap("impostor", "arms", index, stale, weakref(panel)).get("ok") \
		and not visit.swap(chosen, "arms", index, "forged-node", stale).get("ok") \
		and app.stitched_preview_satchel == before_replay \
		and visit.read_state() == swapped and randi() == replay_global and _no_wallet(app),
		"stale, duplicate and forged sack trades preserve authority, inventory, wallet and RNG")
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	var carried: Dictionary = app._stitched_floor_config()
	var equipped := false
	for hero in carried.get("heroes", []):
		if str(hero["id"]) == chosen:
			equipped = hero["parts"]["arms"]["id"] == SACK
	_check(equipped and carried.get("seed") == 4982026 \
		and app.stitched_sewing_visit == null and app.stitched_preview_satchel == before_replay,
		"Leave persists the real sack onto the next unchanged seeded Roadblock")
	var next: StitchedBattleScreen = await _admit(app)
	if next == null:
		_check(false, "carried sack must admit next mounted Roadblock")
		app.free()
		await process_frame
		return
	_check(next.battle.get_unit(chosen).get("parts", {}).get("arms", {}).get("id") == SACK,
		"next real combat controller equips the Scavenger trophy")
	var cast := false
	var weakened := false
	var rejected := false
	for turn in range(75):
		if next.battle.is_over() or next.battle.current_side() != "hero":
			break
		var actor_id: String = next.battle.current_actor_id()
		var actor: Dictionary = next.battle.get_unit(actor_id)
		if actor_id == chosen and int(actor.get("rank", -1)) in [1, 2] and next.select_part("arms"):
			var targets: Dictionary = next.legal_targets()
			var before_state: Dictionary = next.battle.state_snapshot()
			var before_rng: int = next.battle.rng_state()
			var before_receipts: int = next.receipts.size()
			var illegal: bool = not next.submit_target("foe", 4).get("ok") \
				and not next.submit_part(SACK, 3).get("ok") \
				and next.battle.state_snapshot() == before_state \
				and next.battle.rng_state() == before_rng \
				and next.receipts.size() == before_receipts
			rejected = rejected or illegal
			for target_key in targets:
				if not str(target_key) in ["foe_1", "foe_2"]:
					continue
				var result: Dictionary = next.submit_target("foe", int(str(target_key).split("_")[1]))
				if result.get("ok") == true and result.get("ability") == "sack_sweep" \
						and next.receipts.size() > before_receipts:
					cast = true
					for hit in result.get("results", []):
						if hit.get("hit") == true:
							for effect in hit.get("statuses", []):
								if effect.get("status") == "weak" and int(effect.get("duration", 0)) == 1:
									weakened = true
				break
			if weakened:
				break
		if next.battle.current_side() == "hero" and not next.battle.is_over():
			next.submit_pass()
	_check(rejected, "illegal rear-rank sack actions consume no turn, receipt or seeded RNG")
	_check(cast and weakened, "real next-fight Sack Sweep hits legal front foe and applies Weak 1")
	var before_exit: Array = app.stitched_preview_satchel.duplicate(true)
	next._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel == before_exit and app.stitched_sewing_panel == null \
		and _no_wallet(app), "unwon next Fight leaves sack and no-spend receipt unchanged")
	app.free()
	await process_frame


## A genuine Roadblock DEFEAT must never pay a trophy. Real mounted hero passes let the
## authored foes win the fight, then the real Back control retires it: no satchel entry,
## no Sewing Circle, no wallet and no global RNG draw.
func _run_defeat_path() -> void:
	var app := _spawn()
	await process_frame
	_check(app.stitched_preview_satchel.is_empty() and _no_wallet(app),
		"fresh defeat path starts without spoils or a wallet")
	var stage: StitchedBattleScreen = await _admit(app)
	if stage == null:
		_check(false, "defeat witness admits a real Roadblock from the title")
		app.free()
		await process_frame
		return
	var passes := 0
	for turn in range(220):
		if stage.battle.is_over() or stage.battle.current_side() != "hero":
			break
		var receipt: Dictionary = stage.submit_pass()
		if receipt.get("ok") != true:
			break
		passes += 1
	var lost_heroes := 0
	for hero in stage.battle.get_heroes():
		if bool(hero.get("lost", false)):
			lost_heroes += 1
	_check(passes > 0 and stage.battle.is_over() and stage.battle.outcome() == "defeat"
		and lost_heroes > 0,
		"mounted hero passes reach a genuine defeat with a lost hero")
	var satchel_before: Array = app.stitched_preview_satchel.duplicate(true)
	seed(661207)
	var expected_global := randi()
	seed(661207)
	stage._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel == satchel_before \
		and app.stitched_preview_satchel.is_empty() \
		and app.stitched_sewing_visit == null and app.stitched_sewing_panel == null \
		and app.title_view.is_visible_in_tree() and randi() == expected_global \
		and _no_wallet(app),
		"a genuine defeat pays no trophy, opens no Circle, and spends no RNG or wallet")
	app.free()
	await process_frame


## Independent Inkbrush Arm reward-to-mount witness (not a catalog-only check).
func _run_inkbrush_path() -> void:
	var catalog: Dictionary = StitchedParts.load_catalog("res://data/parts/enemy_parts.json")
	var ink: Dictionary = catalog.get("by_id", {}).get(INK, {})
	var first: Dictionary = StitchedParts.ability_at_tier(ink, 1) if not ink.is_empty() else {}
	var second: Dictionary = StitchedParts.ability_at_tier(ink, 2) if not ink.is_empty() else {}
	var third: Dictionary = StitchedParts.ability_at_tier(ink, 3) if not ink.is_empty() else {}
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/parts/enemy_parts.json"))
	var id_count := 0
	if raw is Dictionary:
		for part in raw.get("parts", []):
			if part is Dictionary and part.get("id") == INK:
				id_count += 1
	_check(catalog.get("ok") == true and id_count == 1 and ink.get("name") == "Inkbrush Arm"
		and ink.get("slot") == "arms" and ink.get("owner") == "any" and ink.get("stat") == {"dmg": 1}
		and first.get("id") == "ink_stroke" and first.get("name") == "Ink Stroke"
		and first.get("kind") == "ranged" and first.get("launch") == [2, 3, 4]
		and first.get("target") == [1, 2, 3] and first.get("target_side") == "enemy"
		and first.get("multi") == false and first.get("acc") == 88
		and first.get("dmg") == [3, 5] and first.get("crit") == 0
		and first.get("effects") == {"weak": 1} and first.get("self_move") == 0
		and first.get("move") == "attack2"
		and second.get("dmg") == [4, 6] and third.get("dmg") == [5, 7]
		and not StitchedParts.ranks_allowed(int(first.get("launch_mask", 0)), 1),
		"unique validated Ink Stroke has the authored range, weak effect, tiers and barred front launch")
	var app := _spawn()
	await process_frame
	_check(_no_wallet(app) and app.stitched_preview_satchel.is_empty(),
		"fresh Inkbrush route starts without virtual wallet, RNG or spoils")
	var stage: StitchedBattleScreen = await _admit(app)
	if stage == null:
		_check(false, "Inkbrush witness admits an authenticated Roadblock from the title")
		app.free()
		await process_frame
		return
	_check(stage.battle.is_valid() and stage.battle.get_foes().size() == 3
		and stage.battle.get_unit("moth_scribe").get("side") == "foe",
		"the real Roadblock contains the actual Moth Scribe")
	var witness: Dictionary = _fight_to_victory(stage)
	_check(witness.get("outcome") == "victory" and int(witness.get("abilities", 0)) > 0
		and stage.battle.get_unit("moth_scribe").get("dead") == true
		and int(stage.battle.get_unit("moth_scribe").get("hp", -1)) == 0,
		"mounted hero actions kill the Moth Scribe and win the authenticated fight")
	if witness.get("outcome") != "victory":
		stage._action_buttons["exit"].pressed.emit()
		app.free()
		await process_frame
		return
	seed(502117)
	var expected_global: int = randi()
	seed(502117)
	stage._action_buttons["exit"].pressed.emit()
	var visit: RunStitchedSewingSwap = app.stitched_sewing_visit
	var panel: Control = app.stitched_sewing_panel
	_check(visit != null and panel != null and stage.battle == null
		and app.stitched_fight_view == null
		and app.stitched_preview_satchel.size() == 3
		and app.stitched_preview_satchel[0]["id"] == CLAW
		and app.stitched_preview_satchel[1]["id"] == SACK
		and app.stitched_preview_satchel[2] == {"id": INK, "slot": "arms", "tier": 1, "torn": false}
		and randi() == expected_global and _no_wallet(app),
		"real win mints ordered claw, sack, Inkbrush once and spends neither RNG nor wallet")
	if visit == null or panel == null:
		app.free()
		await process_frame
		return
	await process_frame
	var quote: Dictionary = visit.quote()
	var chosen := ""
	var index := -1
	for hero_row in quote.get("heroes", []):
		if not str(hero_row["hero_id"]) in ["seamstress", "tinker", "lantern_monk"]:
			continue
		for slot_row in hero_row["slots"]:
			if str(slot_row["slot"]) != "arms" or not bool(slot_row["can_swap"]):
				continue
			for option in slot_row["offers"]:
				if option["part"]["id"] == INK and chosen.is_empty():
					chosen = str(hero_row["hero_id"])
					index = int(option["satchel_index"])
	var button: Button = (panel.find_child("Swap_%s_%d" % [chosen, index], true, false) as Button) if index >= 0 else null
	_check(quote.get("ok") == true and quote.get("satchel_count") == 3
		and button != null and index == 2 and not chosen.is_empty(),
		"real Circle offers the third trophy as a compatible arms button to a back-rank hero")
	if button == null:
		panel.get_node("SewingLeave").pressed.emit()
		app.free()
		await process_frame
		return
	var prior: Dictionary = visit.read_state()
	var prior_satchel: Array = app.stitched_preview_satchel.duplicate(true)
	seed(774123)
	var reject_rng: int = randi()
	seed(774123)
	_check(not app._stitched_sewing_swap("impostor", "arms", index, prior, weakref(panel)).get("ok")
		and not app._stitched_sewing_swap(chosen, "torso", index, prior, weakref(panel)).get("ok")
		and not app._stitched_sewing_swap(chosen, "arms", 9, prior, weakref(panel)).get("ok")
		and visit.read_state() == prior and app.stitched_preview_satchel == prior_satchel
		and randi() == reject_rng and _no_wallet(app),
		"forged, incompatible and unoffered inkbrush swaps reject without changes or RNG")
	button.pressed.emit()
	var swapped: Dictionary = visit.read_state()
	_check(int(swapped.get("version", 0)) == 1 and swapped.get("satchel", []).size() == 3
		and app.stitched_preview_satchel == swapped["satchel"]
		and app._stitched_gear_overrides.get(chosen, {}).get("arms", {}).get("id") == INK
		and _no_wallet(app), "quoted Inkbrush click atomically exchanges worn arms at zero cost")
	seed(714229)
	var stale_rng: int = randi()
	seed(714229)
	_check(not app._stitched_sewing_swap(chosen, "arms", index, prior, weakref(panel)).get("ok")
		and not visit.swap(chosen, "arms", index, "forged-node", prior).get("ok")
		and visit.read_state() == swapped and app.stitched_preview_satchel == swapped["satchel"]
		and randi() == stale_rng and _no_wallet(app),
		"stale and replayed Inkbrush quotes cannot duplicate parts or spend RNG")
	panel.get_node("SewingLeave").pressed.emit()
	await process_frame
	var carried: Dictionary = app._stitched_floor_config()
	var equipped := false
	for hero in carried.get("heroes", []):
		if str(hero["id"]) == chosen:
			equipped = hero["parts"]["arms"]["id"] == INK
	_check(equipped and app.stitched_sewing_visit == null
		and app.stitched_preview_satchel == swapped["satchel"]
		and carried.get("seed") == 4982026, "Leave carries Inkbrush into the next genuine title Fight")
	var next: StitchedBattleScreen = await _admit(app)
	if next == null:
		_check(false, "Inkbrush carries into the next mounted title Fight")
		app.free()
		await process_frame
		return
	_check(next.battle.is_valid() and next.battle.get_unit(chosen).get("parts", {}).get("arms", {}).get("id") == INK,
		"next real battle has the Inkbrush Arm equipped on its actual hero")
	var cast := false
	var weakened := false
	var illegal := false
	for turn in range(90):
		if next.battle.is_over() or next.battle.current_side() != "hero":
			break
		var actor_id: String = next.battle.current_actor_id()
		var actor: Dictionary = next.battle.get_unit(actor_id)
		if actor_id == chosen and int(actor.get("rank", -1)) in [2, 3, 4] and next.select_part("arms"):
			var targets: Dictionary = next.legal_targets()
			var before_state: Dictionary = next.battle.state_snapshot()
			var before_rng: int = next.battle.rng_state()
			var before_receipts: int = next.receipts.size()
			illegal = not next.submit_target("foe", 4).get("ok") \
				and not next.submit_part(INK, 4).get("ok") \
				and next.battle.state_snapshot() == before_state \
				and next.battle.rng_state() == before_rng \
				and next.receipts.size() == before_receipts
			for target_key in targets:
				if not str(target_key) in ["foe_1", "foe_2", "foe_3"]:
					continue
				var receipt_before := next.receipts.size()
				var result: Dictionary = next.submit_target("foe", int(str(target_key).split("_")[1]))
				if result.get("ok") == true and result.get("ability") == "ink_stroke" \
						and next.receipts.size() > receipt_before:
					cast = true
					for hit in result.get("results", []):
						if hit.get("hit") == true:
							for effect in hit.get("statuses", []):
								if effect.get("status") == "weak" and int(effect.get("duration", 0)) == 1:
									weakened = true
				break
			if weakened:
				break
		if next.battle.current_side() == "hero" and not next.battle.is_over():
			next.submit_pass()
	_check(illegal, "illegal fourth enemy rank cannot consume a turn, receipt or RNG")
	_check(cast and weakened, "a legal rear-rank Ink Stroke hits a live foe and receipts Weak 1")
	var before_exit: Array = app.stitched_preview_satchel.duplicate(true)
	next._action_buttons["exit"].pressed.emit()
	await process_frame
	_check(app.stitched_preview_satchel == before_exit and app.stitched_sewing_panel == null
		and _no_wallet(app), "unfinished next Fight cannot mint a duplicate Inkbrush")
	app.free()
	await process_frame

func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("stitched_s5_sewing_spoils_live_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
