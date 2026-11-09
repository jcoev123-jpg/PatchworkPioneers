extends SceneTree
## Live S2 history: genuine seeded turns, no hand-made receipts or RNG draws.
const HISTORY := preload("res://scripts/stitched/stitched_battle_history.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures.append(note)

func _mount() -> Dictionary:
	var host := Control.new()
	host.name = "HistoryTestHost"
	host.size = Vector2(1280, 720)
	host.theme = load("res://themes/gothic_theme.tres")
	root.add_child(host)
	var data := StitchedBattleScreen.read_preview()
	_check(int(data.get("seed", -1)) == 4952026 and int(data.get("candle", -1)) == 78
		and data.get("heroes", []).size() == 4 and data.get("foes", []).size() == 3,
		"precondition: real four-hero/three-foe seeded 4952026, candle 78 preview")
	var screen := StitchedBattleScreen.new()
	_check(screen.begin(data), "real S2 battle session validates")
	host.add_child(screen)
	_check(screen.battle != null and screen.battle.is_valid()
		and screen.battle.get_heroes().size() == 4 and screen.battle.get_foes().size() == 3,
		"mounted battle has four heroes and three foes")
	return {"host": host, "screen": screen}

func _click(button: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame

func _state(screen: StitchedBattleScreen) -> Dictionary:
	return {"snapshot": screen.battle.state_snapshot(), "rng": screen.battle.rng_state(),
		"turn": screen.battle.turn_order(), "actor": screen.battle.current_actor_id(),
		"receipts": screen.receipts.duplicate(true), "last": screen.last_receipt.duplicate(true),
		"history": screen._history_entries.duplicate(true), "omitted": screen._history_omitted}

func _check_passive(screen: StitchedBattleScreen, baseline: Dictionary, note: String) -> void:
	_check(_state(screen) == baseline, note + ": read-only state/RNG/turn/actor/receipts/last/history")

func _test_fixture() -> void:
	var items: Array[Dictionary] = []
	for i in range(9):
		items.append({"text": "Accepted %d" % i, "actor_id": "actor%d" % i})
	var window: Dictionary = HISTORY.newest(items)
	_check(window["rows"].size() == 8 and int(window["omitted"]) == 1
		and window["rows"][0]["actor_id"] == "actor1"
		and window["rows"][7]["actor_id"] == "actor8"
		and items.size() == 9, "pure nine-entry fixture retains newest eight in order without mutating input")
	_check(HISTORY.entry({"ok": false, "action": "pass"}, "Doll", "", {}).is_empty(),
		"refused receipt has no presentable entry")
	var status := HISTORY.entry({"ok": true, "action": "ability", "actor": "doll",
		"ability": "burst", "results": [
			{"target": "x", "hit": false, "damage": 0},
			{"target": "y", "hit": true, "damage": 7},
			{"target": "z", "hit": true, "damage": 0}]},
		"Doll", "Thorn Burst", {"x": "Moth", "y": "Wisp", "z": "Shade"})
	_check(status["text"].contains("Thorn Burst") and status["targets"].size() == 3
		and status["text"].contains("Moth: MISS") and status["text"].contains("Wisp: HIT · 7 damage")
		and status["text"].contains("Shade: HIT · effect only (no damage)")
		and not status["text"].contains("0 damage"),
		"multi-target formatting distinguishes miss, actual damage and zero-damage effect")

func _test_status_receipts() -> void:
	# Producer-shaped status arrays: a blocked/resisted outcome is not an application,
	# and chained results remain separate targets in their actual receipt order.
	var receipt := {"ok": true, "action": "ability", "actor": "seamstress",
		"ability": "seamstress_head_mending_knot", "results": [
			{"target": "ally", "hit": true, "damage": 0, "statuses": [
				{"status": "heal", "amount": 3},
				{"status": "bleed", "duration": 2}]},
			{"target": "resistant", "hit": true, "damage": 4, "chained": true, "statuses": [
				{"status": "rot", "resisted": true, "roll": 17, "resist": 80},
				{"status": "bleed", "resisted": true, "roll": 13, "resist": 80},
				{"status": "stun", "refused": true}]},
			{"target": "marked", "hit": true, "damage": 0, "statuses": [
				{"status": "rot", "duration": 3},
				{"status": "regen", "duration": 2, "patch": "silk_life_loop"}]},
			{"target": "miss", "hit": false, "damage": 0, "statuses": []},
			{"target": "full", "hit": true, "damage": 0, "statuses": [
				{"status": "heal", "amount": 0, "patch": "gold_heart_knot"},
				{"status": "steal", "amount": 0, "patch": "gold_hungry_button"}]},
			{"target": "drained", "hit": true, "damage": 0, "statuses": [
				{"status": "steal", "amount": 2, "patch": "gold_hungry_button"}]}]}
	var names := {"ally": "Warden", "resistant": "Crab", "marked": "Moth",
		"miss": "Shade", "full": "Full Doll", "drained": "Threadling"}
	var unchanged := receipt.duplicate(true)
	var entry: Dictionary = HISTORY.entry(receipt, "Seamstress", "Mending Knot", names)
	var lines := str(entry.get("text", "")).split("\n", false)
	_check(receipt == unchanged and entry.get("targets", []).size() == 6,
		"presenting producer-shaped statuses leaves the receipt untouched and preserves six target rows")
	_check(lines.size() == 7, "each result, including chained follow-up, has its own ordered line")
	if lines.size() != 7:
		return
	_check(lines[0] == "Seamstress · Mending Knot"
		and lines[1].begins_with("→ Warden: HIT · effect only (no damage)")
		and lines[1].contains(" · MENDED · BLEED") and not lines[1].contains("RESISTED"),
		"applied authored healing and sewn bleed label the actual ally, in receipt order")
	_check(lines[2].begins_with("→ Crab: HIT · 4 damage")
		and lines[2].contains(" · resisted rot · resisted bleed · BLOCKED STUN")
		and not lines[2].contains(" · ROT") and not lines[2].contains(" · BLEED")
		and not lines[2].contains(" · STUN"),
		"resisted S15 effects and refused temporary stun remain unsuccessful on chained target")
	_check(lines[3].begins_with("→ Moth: HIT · effect only (no damage)")
		and lines[3].contains(" · ROT · REGEN")
		and not lines[3].contains("RESISTED") and not lines[3].contains("BLOCKED"),
		"applied rot/regen only appear on their own successful recipient")
	_check(lines[4] == "→ Shade: MISS",
		"missed target has no invented landed status")
	_check(lines[5] == "→ Full Doll: HIT · effect only (no damage)",
		"zero actual heal and zero actual steal never imply recovered stuffing")
	_check(lines[6].begins_with("→ Threadling: HIT · effect only (no damage)")
		and lines[6].contains(" · STUFFING STOLEN") and not lines[5].contains("STOLEN"),
		"positive stuffing steal is named only on the drained recipient")
	_check(not str(entry["text"]).contains("roll") and not str(entry["text"]).contains("80")
		and not str(entry["text"]).contains("17") and not str(entry["text"]).contains("13")
		and not str(entry["text"]).contains("%"),
		"history conceals resist odds and rolls while retaining existing damage text")


func _test_real_s14_ally_patch() -> void:
	const SEED := 55
	const MENDING := "seamstress_head_mending_knot"
	const LINT := "cotton_red_lint"
	var config := StitchedRunSession.starter_config(StitchedRunSession.DEFAULT_PICKS)
	_check(not config.is_empty() and config.get("heroes", []).size() == 4,
		"precondition: a real four-doll run starter config loads")
	if config.is_empty():
		return
	config["seed"] = SEED
	config["s14"] = true
	config["s14_sockets"] = {"seamstress": {MENDING: [LINT]}}
	var built: Dictionary = StitchedRules.create(config)
	_check(bool(built.get("ok", false)) and built.get("battle") != null,
		"precondition: seeded S14 battle accepts the legal cotton Mending Knot socket")
	if not bool(built.get("ok", false)) or built.get("battle") == null:
		return
	var battle: StitchedRules = built["battle"]
	var hero: Dictionary = battle.get_unit("seamstress")
	var ally: Dictionary = battle.get_unit("warden")
	_check(not hero.is_empty() and not ally.is_empty()
		and str(hero.get("side", "")) == "hero" and str(ally.get("side", "")) == "hero"
		and str(hero.get("id", "")) != str(ally.get("id", ""))
		and int(hero.get("rank", 0)) in [2, 3, 4] and int(ally.get("rank", 0)) in [1, 2, 3, 4],
		"precondition: real Seamstress launch rank and separate living allied Warden rank are legal")
	if hero.is_empty() or ally.is_empty():
		return
	var pass_ok := true
	for step in range(96):
		if battle.current_actor_id() == "seamstress" or battle.is_over():
			break
		if not bool(battle.pass_turn().get("ok", false)):
			pass_ok = false
			break
	_check(pass_ok and not battle.is_over() and battle.current_actor_id() == "seamstress",
		"public seeded pass-turn schedule reaches Seamstress's actual action")
	if not pass_ok or battle.is_over() or battle.current_actor_id() != "seamstress":
		return
	var receipt: Dictionary = battle.use_ability(MENDING, int(ally["rank"]))
	var results: Array = receipt.get("results", [])
	_check(bool(receipt.get("ok", false)) and str(receipt.get("action", "")) == "ability"
		and str(receipt.get("actor", "")) == "seamstress"
		and str(receipt.get("ability", "")) == MENDING and results.size() == 1,
		"precondition: genuine public Mending Knot cast yields one accepted ability result")
	if results.size() != 1 or not bool(receipt.get("ok", false)):
		return
	var hit: Dictionary = results[0]
	var saw_lint := false
	for status in hit.get("statuses", []):
		if status.get("status") == "bleed" and int(status.get("duration", 0)) == 2 \
				and not status.get("resisted", false) and not status.get("refused", false):
			saw_lint = true
	_check(bool(hit.get("hit", false)) and str(hit.get("target", "")) == str(ally["id"])
		and str(hit.get("target_side", "")) == "hero" and saw_lint
		and LINT in hit.get("patches", []),
		"seeded accepted allied cast actually lands the socketed cotton bleed")
	if not bool(hit.get("hit", false)) or not saw_lint:
		return
	var state_before := battle.state_snapshot()
	var rng_before := battle.rng_state()
	var turn_before := battle.turn_order()
	var actor_before := battle.current_actor_id()
	var receipt_before := receipt.duplicate(true)
	var ally_name := str(ally.get("name", ally["id"]))
	var shown: Dictionary = HISTORY.entry(receipt, "Seamstress", "Mending Knot",
		{str(ally["id"]): ally_name})
	_check(str(shown.get("text", "")).contains("Seamstress · Mending Knot")
		and str(shown.get("text", "")).contains("→ %s: HIT · effect only (no damage)" % ally_name)
		and str(shown.get("text", "")).contains(" · BLEED")
		and not str(shown.get("text", "")).contains("RESISTED BLEED"),
		"actual landed bleeding patch is named on the ally hit by Mending Knot")
	_check(shown.get("targets", []).size() == 1
		and str(shown["targets"][0]["id"]) == str(ally["id"])
		and str(shown["targets"][0]["name"]) == ally_name,
		"real receipt names actual allied target and preserves structured result identity")
	_check(receipt == receipt_before and battle.state_snapshot() == state_before
		and battle.rng_state() == rng_before and battle.turn_order() == turn_before
		and battle.current_actor_id() == actor_before,
		"pure receipt formatting leaves raw receipt, battle snapshot, RNG, order, actor unchanged")


func _test_ui(screen: StitchedBattleScreen) -> void:
	var opener: Button = screen._history_button
	var close: Button = screen._history_close_button
	var overlay: Control = screen._history_overlay
	var panel: NinePatchRect = overlay.get_node("HistoryFeltPanel")
	var scroll: ScrollContainer = screen._history_scroll
	var style := opener.get_theme_stylebox("normal") as StyleBoxTexture
	_check(opener.is_visible_in_tree() and opener.focus_mode == Control.FOCUS_ALL
		and style != null and style.texture == load("res://assets/paper/ui/reward_button.png")
		and panel.texture == load("res://assets/paper/ui/panel_felt.png")
		and panel.patch_margin_left >= 14 and panel.patch_margin_top >= 12
		and overlay.size == Vector2(1280, 720) and not overlay.visible
		and scroll.size.x >= 700 and scroll.size.y >= 350
		and scroll.get_global_rect().end.y <= 720,
		"history opener and scrollable overlay are mounted, visible/reachable, authored nine-slice chrome")
	_check(screen._part_buttons.size() == 4 and screen._target_buttons.size() == 8
		and screen._action_buttons.has("re_tie") and screen._action_buttons.has("retreat")
		and screen._action_buttons.has("help") and screen._action_buttons.has("reduce_motion")
		and screen._foe_tickets.size() == 4 and screen._labels.has("log"),
		"existing four part controls, eight targets, turn actions, intents, help and motion remain wired")
	var before := _state(screen)
	var rejected := screen.submit_target("foe", 4)
	var no_tie := screen.submit_re_tie()
	_check(not bool(rejected.get("ok", true)) and not bool(no_tie.get("ok", true)),
		"illegal target and intact-thread Re-tie remain refused")
	_check_passive(screen, before, "illegal actions do not populate or alter history")
	screen._action_buttons["pass"].grab_focus()
	await _click(opener)
	_check(overlay.is_visible_in_tree() and close.has_focus()
		and screen._history_open and screen._action_buttons["pass"].focus_mode == Control.FOCUS_NONE
		and scroll.is_visible_in_tree(), "real mouse opens modal and focuses Close, disables underlying combat focus")
	_check_passive(screen, before, "mouse opens passive history")
	await _click(screen._action_buttons["pass"])
	_check_passive(screen, before, "click behind overlay cannot trigger pass")
	await _key(KEY_ESCAPE)
	_check(not overlay.visible and not screen._history_open
		and screen._action_buttons["pass"].focus_mode == Control.FOCUS_ALL
		and (screen._history_button.has_focus() or screen._action_buttons["pass"].has_focus()),
		"Escape closes overlay, restores legal keyboard focus and action focus modes")
	_check_passive(screen, before, "Escape closes passive history")
	opener.grab_focus()
	await _key(KEY_ENTER)
	_check(overlay.visible and close.has_focus(), "keyboard Enter activates HISTORY")
	await _key(KEY_ENTER)
	_check(not overlay.visible and opener.has_focus(), "keyboard Enter activates Close and restores opener")
	await _click(opener)
	await _click(close)
	_check(not overlay.visible and opener.has_focus(), "mouse Close restores focus")
	_check_passive(screen, before, "mouse and keyboard modal navigation never consumes RNG or turn")

func _drive(screen: StitchedBattleScreen) -> void:
	# A real Wren free hand precedes the doll's turn and must be in history.
	_check(screen.battle.hand_action_open() and "shield_candle" in screen.battle.gift_slots(),
		"precondition: Wren has a live free Shield the Candle hand action")
	var hand := screen.submit_hand_action("shield_candle")
	_check(bool(hand.get("ok", false)) and str(hand.get("action", "")) == "hand"
		and str(hand.get("hand_action", "")) == "shield_candle"
		and str(screen._history_entries[-1]["text"]).contains("Wren"),
		"genuine Wren hand receipt receives its own named history row")
	# Make a genuine legal part attempt (all later turns use authentic Pass).
	var ability_done := false
	if not screen.battle.is_over() and screen.battle.current_side() == "hero":
		for slot in StitchedBattleScreen.SLOTS:
			if not screen.select_part(slot):
				continue
			var legal := screen.legal_targets()
			if legal.is_empty():
				continue
			var key := str(legal.keys()[0])
			var components := key.split("_")
			var accepted := screen.submit_target(str(components[0]), int(components[1]))
			ability_done = bool(accepted.get("ok", false))
			if ability_done:
				break
	_check(ability_done, "genuine worn-part ability commits through public target gate")
	# Foes act automatically between hero turns; no _record or raw receipt array calls.
	for turn in range(120):
		if screen.battle.is_over():
			break
		if screen.battle.current_side() != "hero":
			# Foe driver normally runs within _commit; never fake its receipts.
			break
		var accepted: Dictionary = {}
		var actor: Dictionary = screen.battle.get_unit(screen.battle.current_actor_id())
		# Try legal, damage-capable worn parts so the seeded fight can finish
		# naturally, rather than passing forever against living enemies.
		for slot in StitchedBattleScreen.SLOTS:
			var worn: Dictionary = actor.get("parts", {}).get(slot, {})
			var part: Dictionary = screen.parts.get(str(worn.get("id", "")), {})
			if part.is_empty():
				continue
			var ability: Dictionary = StitchedParts.ability_at_tier(part, int(worn.get("tier", 1)))
			var damage: Variant = ability.get("dmg", [])
			if str(ability.get("target_side", "")) != "enemy" or not damage is Array \
					or damage.size() != 2 or int(damage[1]) <= 0:
				continue
			if not screen.select_part(slot):
				continue
			for key in screen.legal_targets():
				if str(key).begins_with("foe_"):
					accepted = screen.submit_target("foe", int(str(key).get_slice("_", 1)))
					break
			if bool(accepted.get("ok", false)):
				break
		if accepted.is_empty():
			accepted = screen.submit_pass()
		_check(bool(accepted.get("ok", false)), "genuine hero action #%d accepted" % turn)
	_check(screen.receipts.size() >= 9, "non-vacuous fight produces nine or more committed hero/foe actions")
	_check(screen.battle.is_over(), "authentic seeded encounter reaches an outcome before post-battle history opens")
	_check(screen._history_entries.size() == mini(8, screen.receipts.size())
		and screen._history_omitted == maxi(0, screen.receipts.size() - 8)
		and screen._history_entries.size() <= HISTORY.LIMIT,
		"live presentation stores only eight latest and counts all older accepted actions")
	var saw_hero := false
	var saw_foe := false
	var saw_ability := false
	var saw_consecutive_foes := false
	var start := maxi(0, screen.receipts.size() - 8)
	for i in range(screen.receipts.size()):
		var receipt: Dictionary = screen.receipts[i]
		var actor_side := str(receipt.get("actor_side", ""))
		saw_hero = saw_hero or actor_side == "hero"
		saw_foe = saw_foe or actor_side == "foe"
		if i > 0 and actor_side == "foe" and str(screen.receipts[i - 1].get("actor_side", "")) == "foe":
			saw_consecutive_foes = true
		if i < start:
			continue
		var entry: Dictionary = screen._history_entries[i - start]
		_check(str(entry["actor_id"]) == str(receipt.get("actor", ""))
			and str(entry["action"]) == str(receipt.get("action", "")),
			"chronological recorded actor/action identity equals receipt #%d" % i)
		if str(receipt.get("action", "")) == "ability":
			saw_ability = true
			_check(not str(entry["ability_name"]).is_empty()
				and str(entry["text"]).contains(str(entry["ability_name"]))
				and entry["targets"].size() == receipt.get("results", []).size(),
				"ability has real named action and all affected target rows")
			for j in range(entry["targets"].size()):
				var actual: Dictionary = receipt["results"][j]
				var shown: Dictionary = entry["targets"][j]
				_check(str(shown["id"]) == str(actual["target"])
					and bool(shown["hit"]) == bool(actual["hit"])
					and int(shown["damage"]) == int(actual["damage"])
					and str(entry["text"]).contains(str(shown["name"])),
					"target #%d preserves resolved name/hit/miss/rolled damage" % j)
	_check(saw_hero and saw_foe and saw_consecutive_foes,
		"real battle includes hero, foe, and consecutive foe receipts (no fabricated turns)")
	_check(saw_ability or screen.receipts.any(func(r): return str(r.get("action", "")) == "ability"),
		"genuine ability result present in accepted receipt stream")
	await process_frame
	_check(screen._history_list.get_child_count() == screen._history_entries.size()
		and screen._history_older_label.text.contains(str(screen._history_omitted))
		and screen._history_list.get_combined_minimum_size().y > screen._history_scroll.size.y,
		"readable scroll retains every current summary and truthful omitted counter")
	for node in screen._history_list.get_children():
		var panel := node as NinePatchRect
		_check(panel != null and panel.texture == load("res://assets/paper/ui/panel_felt.png")
			and panel.custom_minimum_size.y >= 60 and panel.get_node("HistoryText").tooltip_text != "",
			"each scroll entry has authored felt and untruncated full text")
	# History must remain readable even when the authoritative battle is over.
	var before := _state(screen)
	await _click(screen._history_button)
	await process_frame
	_check(screen._history_scroll.get_v_scroll_bar().max_value > screen._history_scroll.size.y,
		"visible history scrolls eight authentic summaries without extending its viewport")
	screen._history_scroll.scroll_vertical = 80
	_check(screen._history_scroll.scroll_vertical > 0,
		"player can scroll through older visible action rows")
	_check(screen._history_overlay.visible and screen._history_close_button.has_focus(),
		"history remains openable after recorded turns and battle end")
	await _key(KEY_ESCAPE)
	_check_passive(screen, before, "post-action reading does not mutate fight outcome")

func _run() -> void:
	_test_fixture()
	_test_status_receipts()
	_test_real_s14_ally_patch()
	var first := _mount()
	await process_frame
	var screen: StitchedBattleScreen = first["screen"]
	if screen.battle != null and screen.battle.is_valid():
		await _test_ui(screen)
		await _drive(screen)
		var first_receipts := screen.receipts.duplicate(true)
		var first_history := screen._history_entries.duplicate(true)
		var first_omitted := screen._history_omitted
		var second := _mount()
		await process_frame
		var replay: StitchedBattleScreen = second["screen"]
		_check(replay._history_omitted == 0 and replay._history_entries.size() == replay.receipts.size(),
			"fresh mounted S2 has no history inherited from the other instance")
		if replay.battle != null and replay.battle.is_valid():
			await _drive(replay)
			_check(replay.receipts == first_receipts
				and replay._history_entries == first_history
				and replay._history_omitted == first_omitted,
				"same-seed public decisions replay the identical receipts and immutable display rows")
		second["host"].free()
		await process_frame
	first["host"].free()
	await process_frame
	for failure in failures:
		printerr(failure)
	print("stitched_s2_battle_history_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)
