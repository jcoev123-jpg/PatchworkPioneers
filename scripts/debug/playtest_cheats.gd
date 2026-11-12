extends Node
## PLAYTEST CHEATS: debug builds only. app.gd loads this file only when OS.is_debug_build(),
## so a release export never runs it; delete scripts/debug/ before the full game ships.
##
## Three ways in, all taking the same commands (";" between commands, ":" or " " inside one):
##   Web:      index.html?cheat=run;floor:6;walk:walls     or  window.ppCheat("fight elite")
##   Desktop:  Godot --path . -- --cheat=run;event:needle_gate
##   In game:  F10 opens a cheat line; type a command and press Enter (Esc closes it).
## Commands:
##   run [seed]          new Stitched run (walks on), party picker and intro skipped
##   floor N             go to the map just before floor N (1-12)
##   walk [area]         start a Walk now: floorboards, walls or basket (default: this floor's)
##   fight [kind]        open a battle now: normal, elite or boss
##   win | defeat        end the battle as a victory or a party defeat
##   hp WHO N            set a hero's/foe's HP (name, id, h1-h4 or f1-f4)
##   status WHO KIND N   give bleed, rot, stun or guard to a figure
##   summon              add one ordinary foe at rank 4 during a battle
##   patch ABILITY ID    attach a named ability patch to a signature, free
##   event [id]          open an event now (a random one without an id)
##   camp | shop | sewing | unpicker | stall    open that visit now
##   heal                full HP, no fray, no torn parts
##   candle N | fear N | gold N | scraps N
##   help                list the commands
## Every command prints one "CHEAT ..." line (and window.ppCheatLast on the Web).

const SEED := 548
const AREAS := {"floorboards": "floorboards", "walls": "walls", "basket": "sewing_basket", "sewing_basket": "sewing_basket"}
const FIGHTS := {"normal": "Fight", "fight": "Fight", "elite": "Elite", "boss": "Boss"}
const VISITS := {"camp": "Campfire", "shop": "Peddler", "sewing": "SewingCircle", "unpicker": "Unpicker", "stall": "PatchStall"}
const HELP := "run [seed] | floor N | walk [floorboards|walls|basket] | fight [normal|elite|boss] | win | defeat | hp WHO N | status WHO KIND N | summon | patch ABILITY ID | event [id] | camp | shop | sewing | unpicker | stall | heal | candle N | fear N | gold N | scraps N"

var app: Node
var last := ""
var _line: LineEdit
var _js_callback


func _ready() -> void:
	name = "PlaytestCheats"
	app = get_parent()
	var script := _startup_script()
	if not script.is_empty():
		await get_tree().process_frame
		await get_tree().process_frame
		run_script(script)
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(func(args: Array): run_script(str(args[0]) if not args.is_empty() else "help"))
		JavaScriptBridge.get_interface("window").ppCheat = _js_callback


func _startup_script() -> String:
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with("--cheat="):
			return arg.trim_prefix("--cheat=")
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search")
		if query is String:
			for field in query.trim_prefix("?").split("&"):
				var pair: PackedStringArray = field.split("=", true, 1)
				if pair[0] == "cheat" and pair.size() == 2:
					return pair[1].uri_decode()
	return ""


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_toggle_line()
		get_viewport().set_input_as_handled()


func _toggle_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
		_line = null
		return
	_line = LineEdit.new()
	_line.name = "CheatLine"
	_line.placeholder_text = "cheat: " + HELP
	_line.position = Vector2(8, 8)
	_line.size = Vector2(1264, 36)
	_line.z_index = 4096
	_line.top_level = true
	_line.text_submitted.connect(func(text: String):
		run_script(text)
		if is_instance_valid(_line):
			_line.placeholder_text = last
			_line.clear())
	_line.gui_input.connect(func(event: InputEvent):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_toggle_line())
	app.add_child(_line)
	_line.grab_focus()


## Runs each ";"-separated command in order and returns the last result line.
func run_script(script: String) -> String:
	for command in script.split(";", false):
		_say(run(command.strip_edges()))
	return last


func run(command: String) -> String:
	var words := command.replace(":", " ").split(" ", false)
	if words.is_empty():
		return "empty command"
	var verb := words[0].to_lower()
	var arg := words[1] if words.size() > 1 else ""
	var number := int(arg) if arg.is_valid_int() else -1
	if verb == "help":
		return HELP
	if verb == "run":
		return _new_run(number if number >= 0 else SEED)
	var session: StitchedRunSession = app.stitched_run_session
	if session == null:
		if _new_run(SEED).begins_with("failed"):
			return "failed: no run and a new one would not start"
		session = app.stitched_run_session
	match verb:
		"floor":
			return _floor(session, clampi(number, 1, RunMap.FLOOR_COUNT) if number > 0 else 1)
		"walk":
			return _walk(session, AREAS.get(arg.to_lower(), session.walk_area()) if not arg.is_empty() else session.walk_area())
		"fight":
			return _fight(session, FIGHTS.get(arg.to_lower(), "Fight"))
		"win":
			return _win(session)
		"defeat":
			return _defeat(session)
		"hp":
			return _hp(session, words)
		"status":
			return _status(session, words)
		"summon":
			return _summon(session)
		"patch":
			return _patch(session, words)
		"event":
			return _visit(session, "Event", arg)
		"heal":
			for hero in session.heroes:
				if hero.get("lost", false):
					continue
				hero.hp = hero.max_hp
				hero["fray"] = 0
				for slot in hero.parts:
					if hero.parts[slot] is Dictionary:
						hero.parts[slot].torn = false
			return _done(session, "party healed")
		"candle":
			session.candle = clampi(number, 0, 100)
			return _done(session, "candle %d" % session.candle)
		"fear":
			session._kid_fear.reset(clampi(number, 0, 100))
			return _done(session, "fear %d" % session.kid_fear())
		"gold":
			session.gold = maxi(0, number)
			# Visit quotes snapshot the wallet on entry. Requote the same stock so
			# an open Peddler or stall immediately reflects the cheat's new gold.
			var service_kind := str(session.pending.get("service", ""))
			if session.phase == "visit" and service_kind in ["Peddler", "PatchStall", "Unpicker"]:
				if not session._open_visit(service_kind):
					return "failed: could not refresh %s prices" % service_kind
			return _done(session, "gold %d" % session.gold)
		"scraps":
			session.scraps = maxi(0, number)
			return _done(session, "scraps %d" % session.scraps)
	if VISITS.has(verb):
		return _visit(session, VISITS[verb])
	return "unknown command '%s'; %s" % [verb, HELP]


func _say(text: String) -> void:
	last = text
	print("CHEAT ", text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.ppCheatLast = %s" % JSON.stringify(text))


func _close_views() -> void:
	if is_instance_valid(app.stitched_run_intro):
		app._dismiss_stitched_intro()
	app._clear_stitched_run_panel()
	for key in ["stitched_run_battle", "stitched_run_walk"]:
		var view: Node = app.get(key)
		if is_instance_valid(view):
			if view.get_parent() != null:
				view.get_parent().remove_child(view)
			view.queue_free()
		app.set(key, null)
	if is_instance_valid(app.title_view):
		app.title_view.hide()


func _new_run(seed_number: int) -> String:
	_close_views()
	if is_instance_valid(app.base_screen) and app.base_screen.get_parent() == app:
		app.base_screen.hide()
	var session := StitchedRunSession.start(seed_number, StitchedRunSession.DEFAULT_PICKS)
	if session == null or not session.enable_walks():
		return "failed: run would not start"
	app.stitched_run_session = session
	app._present_stitched_run()
	return "new run, seed %d, floor 1 map" % seed_number


## Back to a clean map page: no open battle, Walk or visit.
func _reset_to_map(session: StitchedRunSession) -> void:
	_close_views()
	session.battle = null
	session.battle_config.clear()
	session.walk = null
	session.walk_carry.clear()
	session.walk_arrival = {}
	session._arrival_walks.clear()
	session.pending.clear()
	session._service = null
	session._actions.clear()
	session.cheat_event_id = ""
	session.phase = "map"


func _floor(session: StitchedRunSession, floor_number: int) -> String:
	_reset_to_map(session)
	session.map._route.clear()
	while session.map.get_current_floor() < floor_number - 1:
		var legal := session.map.get_legal_choices()
		if legal.is_empty() or not session.map.choose_node(legal[0]):
			break
	return _done(session, "map before floor %d" % (session.map.get_current_floor() + 1))


## Enter a node of this kind as if chosen on the map: a node id for receipts, nothing drawn.
func _pend(session: StitchedRunSession, kind: String) -> void:
	_reset_to_map(session)
	var node_id := session.map.get_current_node_id()
	session.pending = {"node_id": node_id if not node_id.is_empty() else "cheat", "kind": kind, "service": kind, "steps": []}


func _walk(session: StitchedRunSession, area: String) -> String:
	if area != session.walk_area():
		# walk_area() follows the floor, so stand before a floor of the asked-for area.
		_floor(session, {"floorboards": 1, "walls": 6, "sewing_basket": 10}[area])
	# A floor shortcut leaves us before its next door. Enter that real floor
	# before opening the Walk, just as the fight shortcut does.
	var legal := session.map.get_legal_choices()
	if not legal.is_empty():
		session.map.choose_node(legal[0])
	_pend(session, "Fight")
	if not session._start_walk():
		session.pending.clear()
		return _done(session, "failed: the Walk needs four living dolls (try a new run)")
	session.phase = "walk"
	return _done(session, "walk in %s, a fight at its end" % area)


func _fight(session: StitchedRunSession, kind: String) -> String:
	if kind == "Boss" and session.map.get_current_floor() != RunMap.FLOOR_COUNT:
		# A won Boss ends the run as "ALL TWELVE FLOORS CLEARED"; stand it on the
		# twelfth floor so that recap can never claim fewer floors reached.
		_floor(session, RunMap.FLOOR_COUNT)
	# Only a map shortcut needs to pass through the next door. A running Walk,
	# visit or battle has already entered its floor; do not jump another one.
	if session.phase == "map":
		var legal := session.map.get_legal_choices()
		if not legal.is_empty():
			session.map.choose_node(legal[0])
	_pend(session, kind)
	if not session._open_battle(kind):
		session.pending.clear()
		return _done(session, "failed: %s battle would not open" % kind)
	session.phase = "battle"
	return _done(session, "%s battle" % kind)


func _win(session: StitchedRunSession) -> String:
	if session.phase != "battle" or session.battle == null:
		return "failed: no open battle (try fight first)"
	for unit in session.battle._units.values():
		if str(unit.get("side")) == "foe" and not bool(unit.get("dead", false)):
			session.battle._kill_foe(unit)
	session.battle._outcome = "victory"
	session._seal()
	var battle := session.battle
	_close_views()
	if not session.settle_battle(battle):
		return _done(session, "failed: the battle would not settle")
	return _done(session, "battle won")


func _battle_unit(battle: StitchedRules, who: String) -> Dictionary:
	var query := who.strip_edges().to_lower()
	for unit in battle._units.values():
		if str(unit.id).to_lower() == query or str(unit.name).to_lower() == query:
			return unit
	var seat := query.trim_prefix("hero").trim_prefix("foe")
	var side := "hero" if query.begins_with("hero") or query.begins_with("h") else "foe"
	if query.begins_with("hero") or query.begins_with("foe"):
		seat = query.trim_prefix("hero").trim_prefix("foe")
	elif query.begins_with("h") or query.begins_with("f"):
		seat = query.substr(1)
	else:
		return {}
	if not seat.is_valid_int() or int(seat) < 1 or int(seat) > 4:
		return {}
	for unit in battle._units.values():
		if str(unit.side) != side or int(unit.rank) != int(seat):
			continue
		if not bool(unit.get("dead", false)) and not bool(unit.get("lost", false)):
			return unit
	return {}


func _finish_cheat_battle(session: StitchedRunSession, message: String,
		receipt: Dictionary = {}) -> String:
	var battle: StitchedRules = session.battle
	if battle == null or not battle.is_over():
		return _done(session, message)
	var view: StitchedBattleScreen = app.stitched_run_battle
	if not receipt.is_empty() and is_instance_valid(view) and view.battle == battle:
		_record_cheat_receipt(session, message, receipt)
		_settle_after_hp_beat(session, battle, view)
		return message
	session._seal()
	_close_views()
	if not session.settle_battle(battle):
		return "failed: the finished battle would not settle"
	return _done(session, message)


## The final damage cue must finish on the mounted stage before App shows the recap.
func _settle_after_hp_beat(session: StitchedRunSession, battle: StitchedRules,
		view: StitchedBattleScreen) -> void:
	# The corridor consumes freshly recorded receipts on its next process frame.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(view) or app.stitched_run_battle != view:
		return
	var fight: StitchedCorridorFight = view.get_node_or_null("CorridorFight")
	if is_instance_valid(fight) and not view._motion_is_reduced():
		while is_instance_valid(fight) and fight._beats != null and fight._beats.is_running():
			await fight._beats.finished
			await get_tree().process_frame
	if is_instance_valid(view) and app.stitched_run_battle == view \
			and app.stitched_run_session == session and session.battle == battle and battle.is_over():
		view.exit_requested.emit()



## Keep the fight mounted so genuine rule effects can animate as held receipts.
func _record_cheat_receipt(session: StitchedRunSession, message: String, receipt: Dictionary) -> String:
	session.journal.append({"action": "cheat", "text": message})
	session._seal()
	var view: StitchedBattleScreen = app.stitched_run_battle
	if is_instance_valid(view) and view.battle == session.battle:
		view._record(receipt)
	else:
		_close_views()
		app._present_stitched_run()
	return message


func _defeat(session: StitchedRunSession) -> String:
	if session.phase == "battle" and session.battle != null and session.battle.is_over():
		return "failed: the battle has already ended"
	if session.phase != "battle" or session.battle == null:
		var opened := _fight(session, "Fight")
		if session.phase != "battle":
			return "failed: could not start defeat battle (%s)" % opened
	var battle: StitchedRules = session.battle
	for hero in battle._units_of_side("hero"):
		if not bool(hero.lost):
			battle._lose_hero(hero)
	battle._battle_finished()
	if battle.outcome() != "defeat":
		return "failed: party loss did not resolve"
	return _finish_cheat_battle(session, "party defeated")


func _hp(session: StitchedRunSession, words: PackedStringArray) -> String:
	if session.phase != "battle" or session.battle == null or session.battle.is_over() or words.size() < 3:
		return "failed: hp needs a running battle, WHO and integer N"
	if not words[words.size() - 1].is_valid_int():
		return "failed: hp needs a running battle, WHO and integer N"
	var who := " ".join(words.slice(1, words.size() - 1))
	var target := _battle_unit(session.battle, who)
	if target.is_empty() or target.get("dead", false) or target.get("lost", false):
		return "failed: no living figure '%s'" % who
	var value := int(words[words.size() - 1])
	if value < 0 or value > int(target.max_hp):
		return "failed: HP must be between 0 and %d" % int(target.max_hp)
	var before := int(target.hp)
	var result := {"target": str(target.id), "target_side": str(target.side),
		"hit": true, "damage": maxi(0, before - value), "statuses": []}
	if value < before:
		# Real rule damage performs Hanging, seam tears and foe-heap settlement.
		session.battle._damage_target(target, before - value, result)
	else:
		target.hp = value
		if value > before:
			result.statuses.append({"status": "heal", "amount": value - before, "on": str(target.id)})
		if str(target.side) == "hero" and value > 0:
			target.hanging = false
			target.death_hits = 0
	session.battle._battle_finished()
	var said := "%s hp %d" % [str(target.name), value]
	var receipt := {"ok": true, "action": "cheat_hp",
		"actor": str(target.id), "results": [result]}
	if session.battle.is_over():
		return _finish_cheat_battle(session, said, receipt)
	return _record_cheat_receipt(session, said, receipt)


func _status(session: StitchedRunSession, words: PackedStringArray) -> String:
	if session.phase != "battle" or session.battle == null or session.battle.is_over() or words.size() < 4:
		return "failed: status needs a running battle, WHO KIND N"
	if not words[words.size() - 1].is_valid_int():
		return "failed: status needs a running battle, WHO KIND N"
	var amount := int(words[words.size() - 1])
	var kind := words[words.size() - 2].to_lower()
	var who := " ".join(words.slice(1, words.size() - 2))
	if not kind in ["bleed", "rot", "stun", "guard"] or amount < 1 or amount > 99:
		return "failed: status accepts bleed, rot, stun or guard and N from 1 to 99"
	var target := _battle_unit(session.battle, who)
	if target.is_empty() or bool(target.get("dead", false)) or bool(target.get("lost", false)):
		return "failed: no living figure '%s'" % who
	var result := {"target": str(target.id), "target_side": str(target.side),
		"hit": true, "damage": 0, "statuses": []}
	# Apply the real effects handler; the figure itself is the debug source, so
	# foe resistance does not randomly refuse the playtest's requested condition.
	session.battle._apply_effects(target, target, {"effects": {kind: amount}}, result)
	if result.statuses.is_empty() or bool(result.statuses[0].get("refused", false)):
		return "failed: %s resisted %s" % [str(target.name), kind]
	return _record_cheat_receipt(session, "%s %s %d" % [str(target.name), kind, amount],
		{"ok": true, "action": "cheat_status", "actor": str(target.id), "results": [result]})


func _summon(session: StitchedRunSession) -> String:
	if session.phase != "battle" or session.battle == null or session.battle.is_over():
		return "failed: summon needs a running battle"
	var battle: StitchedRules = session.battle
	if battle._enemy_rank_taken(4) or battle._living_foes().size() >= 4:
		return "failed: no fourth foe seat available"
	var chosen := {}
	for id in session.enemies.order:
		if session.enemies.enemies[id].tier != StitchedEnemyCatalog.TIER_NORMAL or battle._units.has(id):
			continue
		chosen = StitchedEnemyCatalog.foe_for(session.enemies, id)
		break
	if chosen.is_empty():
		return "failed: no distinct ordinary foe is available"
	StitchedDeeperSeams.apply(chosen, session.map.get_current_floor(), "Fight")
	var arrival := battle.summon_foe(chosen)
	if not bool(arrival.get("ok", false)):
		return "failed: " + str(arrival.get("error", "summoned foe refused by rules"))
	# Keep the mounted fight alive: a scene rebuild used to drop the arrival
	# receipt before its fourth-seat spotlight or floating word could play.
	var said := "%s summoned at foe seat 4" % str(chosen.name)
	session.journal.append({"action": "cheat", "text": said})
	session._seal()
	var view: StitchedBattleScreen = app.stitched_run_battle
	if is_instance_valid(view) and view.battle == battle:
		view._record(arrival)
	else:
		_close_views()
		app._present_stitched_run()
	# The next natural round rolls the new foe's initiative, not this round.
	return said


func _patch(session: StitchedRunSession, words: PackedStringArray) -> String:
	if not session.s14_enabled or words.size() < 3:
		return "failed: patch needs ABILITY and patch ID"
	var patch_id := words[words.size() - 1].to_lower()
	var record: Dictionary = StitchedS14Abilities.patches().get("by_id", {}).get(patch_id, {})
	if record.is_empty():
		return "failed: unknown ability patch '%s'" % patch_id
	var query := " ".join(words.slice(1, words.size() - 1)).to_lower()
	var owner := ""
	var signature_id := ""
	for hero in session.heroes:
		if bool(hero.lost):
			continue
		for ability in StitchedS14Abilities.kits().get(str(hero.id), {}).values():
			if str(ability.id).to_lower() == query or str(ability.name).to_lower() == query:
				if not owner.is_empty():
					return "failed: ability name is ambiguous; use its id"
				owner = str(hero.id)
				signature_id = str(ability.id)
	if owner.is_empty():
		return "failed: unknown signature ability '%s'" % query
	session.ability_serial += 1
	var uid := session.ability_serial
	session.ability_inventory.append({"uid": uid, "id": patch_id, "rarity": str(record.rarity)})
	if not session.ability_sockets.has(owner):
		session.ability_sockets[owner] = {}
	# The cheat intentionally substitutes one socket; previous owned patches remain
	# loose in inventory for a later real Sewing Circle visit.
	session.ability_sockets[owner][signature_id] = [uid]
	var said := "%s sewn onto %s" % [str(record.name), signature_id]
	if session.phase == "battle" and session.battle != null:
		session.battle._s14_sockets = session._battle_sockets()
		session.battle_config["s14_sockets"] = session.battle._s14_sockets.duplicate(true)
		var view: StitchedBattleScreen = app.stitched_run_battle
		if is_instance_valid(view) and view.battle == session.battle:
			# Update the sewn badge without destroying the live target choice,
			# held spotlight or queued receipts on this mounted battle.
			session.journal.append({"action": "cheat", "text": said})
			session._seal()
			view._refresh()
			var fight: StitchedCorridorFight = view.get_node_or_null("CorridorFight")
			if is_instance_valid(fight):
				fight.refresh()
			return said
	return _done(session, said)


func _visit(session: StitchedRunSession, kind: String, event_id := "") -> String:
	_pend(session, kind)
	session.cheat_event_id = event_id
	var opened := session._open_visit(kind)
	session.cheat_event_id = ""
	if not opened:
		session.pending.clear()
		return _done(session, "failed: %s would not open" % kind)
	session.phase = "visit"
	if not event_id.is_empty() and session.pending.get("event_id", "") != event_id:
		return _done(session, "no event '%s'; opened '%s' instead" % [event_id, session.pending.get("event_id", "")])
	return _done(session, "%s visit%s" % [kind, " '%s'" % session.pending.get("event_id") if kind == "Event" else ""])


## Reseal the hand-edited session and show whatever phase it is now in.
func _done(session: StitchedRunSession, text: String) -> String:
	session.journal.append({"action": "cheat", "text": text})
	session._seal()
	_close_views()
	app._present_stitched_run()
	return text
