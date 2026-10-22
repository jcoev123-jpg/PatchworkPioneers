extends Node
## Presentation-only combat juice (VIS V5): committed HP/Block deltas for both teams.
##
## This listener never previews, resolves, recomputes or mutates combat. Once a real
## battle has mounted it snapshots the authoritative hero/enemy rosters by actor ID.
## A later *committed* HP or Block change (a resolved attack, an End Turn, a status
## tick the rules already applied) draws one short, pointer-inert float plus a hit
## flash at that actor's current presentation, falling back to the matching live
## combat meter. Nothing here awaits or gates input: fast mode only shortens the
## effects, and returning, a new battle, terminal teardown or a missing anchor
## presentation drops every cue and rebaselines instead of inventing one.

const NORMAL_SECONDS := 0.6
const FAST_SECONDS := 0.15
const HISTORY_LIMIT := 64
const FLOAT_WIDTH := 120.0
const FLOAT_HEIGHT := 26.0

var fast_animations := false
var fast_button: Button
var overlay: Control
## Every committed cue since this battle bound ({"side","position","id","hp","block",
## "anchor","fast","duration","text"}), oldest first; bounded, never fabricated.
var history: Array[Dictionary] = []
## Bumped once per battle binding, so a test or screenshot can prove a single rebind.
var bind_serial := 0
var bound := false

var _battle: Control
var _party: CombatParty
var _enemies: CombatEnemies
var _deck: CombatDeck
var _snapshot: Dictionary = {}
var _cues: Array[Dictionary] = []


func _process(_delta: float) -> void:
	_sync()


## Normal (<= 0.6 s) or fast (<= 0.15 s) presentation length; never gameplay timing.
func duration_seconds() -> float:
	return FAST_SECONDS if fast_animations else NORMAL_SECONDS


func set_fast(enabled: bool) -> void:
	fast_animations = enabled
	_sync_button()


func toggle_fast() -> void:
	set_fast(not fast_animations)


## One themed secondary action in the battle's sewn corner, beside the compact Return.
func attach_fast_button(actions: HBoxContainer) -> Button:
	if is_instance_valid(fast_button) and fast_button.get_parent() == actions:
		_sync_button()
		return fast_button
	var button := Button.new()
	button.name = "FastAnimationsButton"
	button.custom_minimum_size = Vector2(120, 40)
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "Fast animations: cues settle in %.2f s instead of %.1f s" % [
		FAST_SECONDS, NORMAL_SECONDS]
	button.pressed.connect(_on_fast_pressed)
	actions.add_child(button)
	fast_button = button
	_sync_button()
	return button


func _on_fast_pressed() -> void:
	toggle_fast()


func _sync_button() -> void:
	if not is_instance_valid(fast_button):
		fast_button = null
		return
	fast_button.text = "Fast: %s" % ("On" if fast_animations else "Off")


## True while a real, still-open battle is mounted with valid, matching models.
func _battle_ready(app) -> bool:
	return app != null and app.deck != null and app.party != null and app.enemies != null \
		and is_instance_valid(app.battle_view) and app.battle_view.is_visible_in_tree() \
		and app.party.is_valid() and app.enemies.is_valid() and not app._battle_closed


func _sync() -> void:
	var app = get_parent()
	if not _battle_ready(app):
		_teardown()
		return
	if _battle != app.battle_view or _party != app.party \
			or _enemies != app.enemies or _deck != app.deck:
		_teardown()
		_bind(app)
		return
	if not is_instance_valid(fast_button):
		fast_button = null
	if not is_instance_valid(overlay) or not overlay.is_inside_tree():
		_kill_cues()
		overlay = _make_overlay()
		_snapshot = _read(app)
		return
	if not _presentation_available(app):
		# No actor can be anchored at all: drop the cues and rebaseline, never guess.
		_kill_cues()
		_snapshot = _read(app)
		return
	var current := _read(app)
	_emit_deltas(app, current)
	_snapshot = current


func _bind(app) -> void:
	bind_serial += 1
	_battle = app.battle_view
	_party = app.party
	_enemies = app.enemies
	_deck = app.deck
	# Release the models with their battle, before a synchronous teardown can be observed.
	if is_instance_valid(_battle):
		_battle.tree_exiting.connect(_teardown, CONNECT_ONE_SHOT)
	overlay = _make_overlay()
	history.clear()
	# Mounting only baselines the current HP/Block; it never announces a change.
	_snapshot = _read(app)
	bound = true


## Title, terminal teardown or a replaced fight: no stale snapshot and no orphan cue.
func _teardown() -> void:
	_kill_cues()
	if is_instance_valid(_battle) and _battle.tree_exiting.is_connected(_teardown):
		_battle.tree_exiting.disconnect(_teardown)
	if is_instance_valid(overlay):
		# The reason for teardown may itself be a parent mid-remove; queue_free detaches.
		overlay.queue_free()
	overlay = null
	_battle = null
	_party = null
	_enemies = null
	_deck = null
	_snapshot = {}
	bound = false
	history.clear()
	if not is_instance_valid(fast_button):
		fast_button = null


func _make_overlay() -> Control:
	if is_instance_valid(overlay) and overlay.is_inside_tree():
		return overlay
	var app := get_parent()
	if app == null:
		return null
	var control := Control.new()
	control.name = "CombatJuiceOverlay"
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.focus_mode = Control.FOCUS_NONE
	app.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Draw above the battle presentation that was mounted before this listener.
	app.move_child(control, app.get_child_count() - 1)
	return control


## Authoritative copies only: {side:id -> position/hp/block}; malformed actors are skipped.
func _read(app) -> Dictionary:
	var snapshot := {}
	for hero in app.party.get_heroes():
		_store(snapshot, "hero", hero)
	for enemy in app.enemies.get_enemies():
		_store(snapshot, "enemy", enemy)
	return snapshot


func _store(snapshot: Dictionary, side: String, actor: Dictionary) -> void:
	var id = actor.get("id")
	var position = actor.get("position")
	var hp = actor.get("hp")
	var block = actor.get("block")
	if not id is String or id.is_empty() or not position is int or position < 1 \
			or not hp is int or hp < 0 or not block is int or block < 0:
		return
	snapshot[side + ":" + id] = {"side": side, "id": id, "position": position,
		"hp": hp, "block": block}


## One cue per actor whose committed HP or Block really changed since the last sync.
func _emit_deltas(app, current: Dictionary) -> void:
	for key in _snapshot:
		if not current.has(key):
			continue
		var before: Dictionary = _snapshot[key]
		var now: Dictionary = current[key]
		var hp_delta: int = int(now["hp"]) - int(before["hp"])
		var block_delta: int = int(now["block"]) - int(before["block"])
		if hp_delta == 0 and block_delta == 0:
			continue
		_spawn(app, now, hp_delta, block_delta)


func _spawn(app, actor: Dictionary, hp_delta: int, block_delta: int) -> void:
	if not is_instance_valid(overlay) or not overlay.is_inside_tree():
		return
	var side: String = actor["side"]
	var position: int = actor["position"]
	var anchor := _anchor(app, side, position)
	if anchor.is_empty():
		return
	var control: Control = anchor["control"]
	var source: String = anchor["source"]
	var rect := control.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var tint := _tint(hp_delta, block_delta)
	var duration := duration_seconds()
	var text := _float_text(hp_delta, block_delta)

	var flash := Panel.new()
	flash.name = "CombatJuiceFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(tint.r, tint.g, tint.b, 0.42)
	style.border_color = Color(tint.r, tint.g, tint.b, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	flash.add_theme_stylebox_override("panel", style)
	overlay.add_child(flash)
	flash.position = _to_overlay(rect.position)
	flash.size = rect.size

	var float_label := Label.new()
	float_label.name = "CombatJuiceFloat"
	float_label.text = text
	float_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	float_label.focus_mode = Control.FOCUS_NONE
	float_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	float_label.add_theme_font_size_override("font_size", 22)
	float_label.add_theme_color_override("font_color", tint)
	float_label.add_theme_constant_override("outline_size", 8)
	float_label.add_theme_color_override("font_outline_color", Color("1a1d20"))
	overlay.add_child(float_label)
	# Keep the whole delta readable: the drawn label may be wider than the nominal box.
	var minimum := float_label.get_combined_minimum_size()
	float_label.size = Vector2(maxf(FLOAT_WIDTH, minimum.x), maxf(FLOAT_HEIGHT, minimum.y))
	var origin := _to_overlay(rect.position)
	var float_y: float = origin.y - float_label.size.y + 4.0
	if float_y < 0.0:
		float_y = origin.y + 4.0
	float_label.position = Vector2(origin.x + rect.size.x * 0.5 - float_label.size.x * 0.5, float_y)

	var tween := float_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(float_label, "modulate:a", 0.0, duration)
	tween.tween_property(float_label, "position", float_label.position - Vector2(0, 22), duration)
	tween.tween_property(flash, "modulate:a", 0.0, duration)
	tween.finished.connect(_retire.bind(weakref(float_label), weakref(flash)))
	_cues.append({"float": float_label, "flash": flash, "tween": tween, "target": control})

	history.append({"side": side, "position": position, "id": actor["id"],
		"hp": hp_delta, "block": block_delta, "anchor": source,
		"fast": fast_animations, "duration": duration, "text": text})
	if history.size() > HISTORY_LIMIT:
		history = history.slice(history.size() - HISTORY_LIMIT)


func _float_text(hp_delta: int, block_delta: int) -> String:
	var parts: PackedStringArray = []
	if hp_delta < 0:
		parts.append("%d HP" % hp_delta)
	elif hp_delta > 0:
		parts.append("+%d HP" % hp_delta)
	if block_delta > 0:
		parts.append("Block +%d" % block_delta)
	elif block_delta < 0:
		parts.append("Block %d" % block_delta)
	return "  ".join(parts)


func _tint(hp_delta: int, block_delta: int) -> Color:
	if hp_delta < 0:
		return Color("d1746a")
	if hp_delta > 0:
		return Color("8dbb84")
	if block_delta > 0:
		return Color("c6aa76")
	return Color("ddab7f")


## Current actor presentation first, else the matching live combat meter.
func _anchor(app, side: String, position: int) -> Dictionary:
	var control := _presentation_anchor(app, side, position)
	if control != null:
		return {"control": control, "source": "presentation"}
	control = _meter_anchor(app, side, position)
	if control != null:
		return {"control": control, "source": "meter"}
	return {}


func _presentation_anchor(app, side: String, position: int) -> Control:
	if side == "hero":
		if position >= 1 and position <= app.hero_panels.size():
			var panel: Control = app.hero_panels[position - 1]
			if is_instance_valid(panel) and panel.is_visible_in_tree():
				return panel
		return null
	var roster = app.get_node_or_null("LiveEnemyRoster")
	if roster == null or not is_instance_valid(roster.panel):
		return null
	var puppet := roster.panel.find_child("EnemyPuppet%d" % position, true, false) as Control
	if is_instance_valid(puppet) and puppet.is_visible_in_tree():
		return puppet
	if position >= 1 and position <= roster._labels.size():
		var label: Label = roster._labels[position - 1]
		if is_instance_valid(label) and label.is_visible_in_tree():
			return label
	return null


func _meter_anchor(app, side: String, position: int) -> Control:
	var meters = app.get_node_or_null("LiveCombatMeters")
	if meters == null or not is_instance_valid(meters.row):
		return null
	var index: int = position - 1 if side == "hero" else CombatParty.PARTY_SIZE + position - 1
	if index < 0 or index >= meters.row.get_child_count():
		return null
	var meter := meters.row.get_child(index) as Control
	if is_instance_valid(meter) and meter.is_visible_in_tree():
		return meter
	return null


func _presentation_available(app) -> bool:
	return _presentation_anchor(app, "hero", 1) != null or _meter_anchor(app, "hero", 1) != null


func _to_overlay(point: Vector2) -> Vector2:
	if not is_instance_valid(overlay):
		return point
	return overlay.get_global_transform().affine_inverse() * point


func _retire(float_ref: WeakRef, flash_ref: WeakRef) -> void:
	var float_node = float_ref.get_ref()
	var flash_node = flash_ref.get_ref()
	for node in [float_node, flash_node]:
		if is_instance_valid(node):
			node.queue_free()
	# Compare identities: queue_free only invalidates them at the end of this frame.
	_cues = _cues.filter(func(entry: Dictionary) -> bool:
		return not _same_node(entry.get("float"), float_node) \
			and not _same_node(entry.get("flash"), flash_node))


func _same_node(a, b) -> bool:
	return is_instance_valid(a) and is_instance_valid(b) and a == b


func _kill_cues() -> void:
	for entry in _cues:
		var tween = entry.get("tween")
		if tween is Tween and tween.is_valid():
			tween.kill()
		for key in ["float", "flash"]:
			var node = entry.get(key)
			if is_instance_valid(node):
				node.queue_free()
	_cues.clear()


## Cue pairs still on screen (a killed or finished effect counts as zero).
func live_cues() -> int:
	var count := 0
	for entry in _cues:
		if is_instance_valid(entry.get("float")) or is_instance_valid(entry.get("flash")):
			count += 1
	return count
