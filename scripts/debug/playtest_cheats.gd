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
##   win                 win the open battle at once (rewards as usual)
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
const HELP := "run [seed] | floor N | walk [floorboards|walls|basket] | fight [normal|elite|boss] | win | event [id] | camp | shop | sewing | unpicker | stall | heal | candle N | fear N | gold N | scraps N"

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
	_pend(session, "Fight")
	if area != session.walk_area():
		# walk_area() follows the floor, so stand on a floor of the asked-for area.
		_floor(session, {"floorboards": 1, "walls": 6, "sewing_basket": 10}[area])
		_pend(session, "Fight")
	if not session._start_walk():
		session.pending.clear()
		return _done(session, "failed: the Walk needs four living dolls (try a new run)")
	session.phase = "walk"
	return _done(session, "walk in %s, a fight at its end" % area)


func _fight(session: StitchedRunSession, kind: String) -> String:
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
