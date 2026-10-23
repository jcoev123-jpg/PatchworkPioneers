extends Node
## Presentation-only combat juice (VIS V5): committed HP/Block deltas for both teams.
##
## This listener never previews, resolves, recomputes or mutates combat. Once a real
## battle has mounted it snapshots the authoritative hero/enemy rosters by actor ID.
## A later *committed* HP or Block change (a resolved attack, an End Turn, a status
## tick the rules already applied) draws one short, pointer-inert float plus a hit
## flash at that actor's current presentation, falling back to the matching live
## combat meter. A committed HP *loss* also makes only that actor's own visible,
## standing mounted puppet recoil; pure Block loss/reset and healing are not evidence
## of a hit, and nothing recoils for an uncommitted preview or a refused play.
## A committed held-card play whose single held copy really left the hand,
## whose authored record is an individually targeted enemy attack and whose only
## authoritative change was one enemy's HP/Block loss also lets that card's own living
## hero puppet perform one bounded attack-pose lunge. An area cast that happens to leave
## only one damaged recipient is never classified as a single hit.
## Nothing here awaits or gates input: fast mode only shortens the effects, and
## returning, a new battle, terminal teardown or a missing anchor presentation drops
## every cue and rebaselines instead of inventing one.

const NORMAL_SECONDS := 0.6
const FAST_SECONDS := 0.15
const HISTORY_LIMIT := 64
const FLIGHT_HISTORY_LIMIT := 64
const POSE_HISTORY_LIMIT := 64
const RECOIL_HISTORY_LIMIT := 64
const FLIGHT_SIZE := Vector2(126, 64)
const FLOAT_WIDTH := 120.0
const FLOAT_HEIGHT := 26.0

var fast_animations := false
var fast_button: Button
var overlay: Control
## Every committed cue since this battle bound ({"side","position","id","hp","block",
## "anchor","fast","duration","text"}), oldest first; bounded, never fabricated.
var history: Array[Dictionary] = []
## Separate bounded receipts for actually spawned, authoritative discard flights.
var flight_history: Array[Dictionary] = []
## Separate bounded receipts for genuinely committed card-attack lunges
## ({"side","position","id","card_id","target_position","target_id","hp","block",
## "anchor","fast","duration"}).
var pose_history: Array[Dictionary] = []
## Separate bounded receipts for recoils really started by a committed HP loss
## ({"side","position","id","hp","block","fast","duration"}).
var recoil_history: Array[Dictionary] = []
## Bumped once per battle binding, so a test or screenshot can prove a single rebind.
var bind_serial := 0
var bound := false

var _battle: Control
var _party: CombatParty
var _enemies: CombatEnemies
var _deck: CombatDeck
var _snapshot: Dictionary = {}
var _cues: Array[Dictionary] = []
var _flights: Array[Dictionary] = []
var _held_before: Array[String] = []
var _discard_before: Array[String] = []
var _draw_before: Array[String] = []
var _held_sources: Array[Dictionary] = []
## The authoritative turn boundary seen at the previous sync. A card play leaves it
## alone, while a resolved enemy phase advances it, so End Turn damage is never
## presented as a card attack.
var _phase_marker: Array = []


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
		_baseline_cards(app)
		_baseline_phase(app)
		return
	if not _presentation_available(app):
		# No actor can be anchored at all: drop the cues and rebaseline, never guess.
		_kill_cues()
		_snapshot = _read(app)
		_baseline_cards(app)
		_baseline_phase(app)
		return
	var current := _read(app)
	_emit_deltas(app, current)
	_emit_discard_flights(app)
	_emit_attack_pose(app, current)
	_snapshot = current
	_baseline_cards(app)
	_baseline_phase(app)


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
	flight_history.clear()
	pose_history.clear()
	recoil_history.clear()
	# Mounting only baselines the current HP/Block; it never announces a change.
	_snapshot = _read(app)
	_baseline_cards(app)
	_baseline_phase(app)
	bound = true


## Title, terminal teardown or a replaced fight: no stale snapshot and no orphan cue.
func _teardown() -> void:
	_kill_cues()
	# A closed or replaced battle never keeps a mounted actor mid-lunge or mid-shake.
	var app := get_parent()
	var roster = app.get_node_or_null("LiveEnemyRoster") if app != null else null
	if roster != null and is_instance_valid(roster) and roster.has_method("cancel_poses"):
		roster.cancel_poses()
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
	_held_before.clear()
	_discard_before.clear()
	_draw_before.clear()
	_held_sources.clear()
	_phase_marker.clear()
	bound = false
	history.clear()
	flight_history.clear()
	pose_history.clear()
	recoil_history.clear()
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


## One cue per actor whose committed HP or Block really changed since the last sync, plus
## one recoil for each of those actors that really lost HP.
func _emit_deltas(app, current: Dictionary) -> void:
	for change in _actor_changes(current):
		var hp_delta := int(change["hp"])
		# A committed HP loss is the only evidence of a hit: a pure Block loss or reset and
		# a heal are not, so they never shake an actor.
		if hp_delta < 0:
			_emit_recoil(app, change)
		_spawn(app, change, hp_delta, int(change["block"]))


## One committed HP loss makes only that actor's own visible, standing puppet recoil. The
## lookup is by authoritative side plus ID and fails closed on a stale, hidden, fallen or
## ambiguous binding, so presentation never shakes the wrong actor. It starts one bounded,
## delta-driven draw pose and never awaits, gates or consumes anything.
func _emit_recoil(app, hit: Dictionary) -> void:
	var roster = app.get_node_or_null("LiveEnemyRoster")
	if roster == null or not is_instance_valid(roster) or not roster.has_method("puppet_for"):
		return
	var puppet = roster.puppet_for(String(hit["side"]), String(hit["id"]))
	if not is_instance_valid(puppet):
		return
	if not puppet.trigger_recoil(duration_seconds()):
		return
	recoil_history.append({"side": String(hit["side"]), "position": int(hit["position"]),
		"id": String(hit["id"]), "hp": int(hit["hp"]), "block": int(hit["block"]),
		"fast": fast_animations, "duration": float(puppet.recoil_span)})
	if recoil_history.size() > RECOIL_HISTORY_LIMIT:
		recoil_history = recoil_history.slice(recoil_history.size() - RECOIL_HISTORY_LIMIT)


## Every authoritative actor whose HP or Block really changed since the last sync, with
## its exact deltas. Read-only: it never reorders, resolves or mutates combat.
func _actor_changes(current: Dictionary) -> Array[Dictionary]:
	var changed: Array[Dictionary] = []
	for key in _snapshot:
		if not current.has(key):
			continue
		var before: Dictionary = _snapshot[key]
		var now: Dictionary = current[key]
		var hp_delta: int = int(now["hp"]) - int(before["hp"])
		var block_delta: int = int(now["block"]) - int(before["block"])
		if hp_delta == 0 and block_delta == 0:
			continue
		changed.append({"side": now["side"], "position": now["position"], "id": now["id"],
			"hp": hp_delta, "block": block_delta})
	return changed


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
	for entry in _flights:
		var flight_tween = entry.get("tween")
		if flight_tween is Tween and flight_tween.is_valid():
			flight_tween.kill()
		var scrap = entry.get("scrap")
		if is_instance_valid(scrap):
			scrap.queue_free()
	_flights.clear()
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


## The deck is the sole authority. A snapshot of already mounted hand panels is
## kept before the normal app action clears/rebuilds them; duplicates retain
## separate panel identities and source rectangles. No signal or rules hook.
func _baseline_cards(app) -> void:
	_held_before.assign(app.deck.hand)
	_discard_before.assign(app.deck.discard_pile)
	_draw_before.assign(app.deck.draw_pile)
	_held_sources = _read_held_sources(app)


## The authoritative turn boundary of this battle: the enemy-phase counter plus whether
## a player turn is open. Only a resolved enemy phase advances it; a card play does not.
func _phase_key(app) -> Array:
	if app == null or app.enemy_intents == null or app.deck == null:
		return []
	return [int(app.enemy_intents._turn_index), bool(app.deck.turn_active)]


func _baseline_phase(app) -> void:
	_phase_marker = _phase_key(app)


## The exact held copies this sync really committed from the hand to the discard pile,
## keyed by card ID. A refill, reshuffle or deck-composition change is ambiguous and
## returns nothing, so no reward, shop or End Turn bookkeeping can look like a play.
func _committed_hand_loss(app) -> Dictionary:
	var before_draw := _card_counts(_draw_before)
	var after_draw := _card_counts(app.deck.draw_pile)
	# No refill/reshuffle and no deck composition change during an observed commit.
	for id in after_draw:
		if int(after_draw[id]) > int(before_draw.get(id, 0)):
			return {}
	var before_discard := _card_counts(_discard_before)
	var after_discard := _card_counts(app.deck.discard_pile)
	for id in before_discard:
		if int(after_discard.get(id, 0)) < int(before_discard[id]):
			return {}
	var before_hand := _card_counts(_held_before)
	var after_hand := _card_counts(app.deck.hand)
	var lost := {}
	for id in before_hand:
		var drawn: int = int(before_draw.get(id, 0)) - int(after_draw.get(id, 0))
		var committed: int = int(before_hand[id]) + drawn - int(after_hand.get(id, 0))
		var gained: int = int(after_discard.get(id, 0)) - int(before_discard.get(id, 0))
		if committed < 0 or committed > int(before_hand[id]) or committed > gained:
			return {}
		if committed > 0:
			lost[id] = committed
	return lost


## The one living hero who authored this committed card, matched by authoritative hero
## ID only. Unknown IDs, stitched halves with two owners, a downed owner or a duplicated
## owner resolve nothing, so no presentation invents a source position.
func _attack_source(card_id: String) -> Dictionary:
	if _party == null or card_id.is_empty():
		return {}
	var matches: Array[Dictionary] = []
	for hero in _party.get_heroes():
		var id = hero.get("id")
		if not id is String or id.is_empty() or not card_id.begins_with(id + "_"):
			continue
		matches.append(hero)
	if matches.size() != 1:
		return {}
	var hero: Dictionary = matches[0]
	var position = hero.get("position")
	if not position is int or position < 1 or _party.is_downed(position):
		return {}
	return hero


## The committed card's own current authored record, resolved by the mounted live hand's
## catalog/preview authority (the same one that admits and resolves this cast). An
## unknown, stitched, replaced or missing record returns empty, so presentation never
## classifies a card from a substitute table or from an actor-count guess.
func _authored_definition(app, card_id: String) -> Dictionary:
	if app == null or card_id.is_empty():
		return {}
	var preview = app.get_node_or_null("LiveAttackPreview")
	if preview == null or not is_instance_valid(preview) or not preview.has_method("_definition"):
		return {}
	var definition = preview._definition(card_id)
	if not definition is Dictionary:
		return {}
	return definition


## True only for an individually targeted enemy attack authored by this exact living
## hero: the enemy_single relation the mounted picker itself requires before offering a
## chosen target. An enemy_all/enemy_random record stays false no matter how many (or
## few) enemies its committed cast actually damaged.
func _is_single_target_attack(app, hero: Dictionary, card_id: String) -> bool:
	var definition := _authored_definition(app, card_id)
	if definition.get("id") != card_id:
		return false
	if String(definition.get("owner", "")) != String(hero.get("id", "")):
		return false
	if definition.get("target_kind") != "enemy_single":
		return false
	if not definition.get("effects") is Dictionary:
		return false
	var damage: Variant = definition["effects"].get("damage")
	return damage is int and int(damage) > 0


## One committed held enemy hit: exactly one held copy really left the hand for the
## discard, that copy's verified authored record is an individually targeted attack
## owned by the identified living hero, the only authoritative change in the same step
## was one enemy losing HP or Block, and no enemy phase resolved. Previews, rejected or
## repeated clicks, End Turn and status ticks, area or multi-actor effects, stitched
## casts and closed battles therefore never fabricate a pose.
func _emit_attack_pose(app, current: Dictionary) -> void:
	if _phase_key(app) != _phase_marker:
		return
	var lost := _committed_hand_loss(app)
	if lost.size() != 1:
		return
	var card_id := String(lost.keys()[0])
	if int(lost[card_id]) != 1:
		return
	var changes := _actor_changes(current)
	if changes.size() != 1:
		return
	var hit: Dictionary = changes[0]
	if String(hit["side"]) != "enemy":
		return
	if int(hit["hp"]) >= 0 and int(hit["block"]) >= 0:
		return
	var hero := _attack_source(card_id)
	if hero.is_empty():
		return
	# Never infer the card kind from the number of observed recipients: a real area
	# cast can legally damage exactly one surviving enemy. Fail closed unless the
	# committed card's own authored record is a single-target attack by this hero.
	if not _is_single_target_attack(app, hero, card_id):
		return
	var roster = app.get_node_or_null("LiveEnemyRoster")
	if roster == null or not roster.has_method("hero_puppet"):
		return
	var puppet = roster.hero_puppet(String(hero["id"]))
	if not is_instance_valid(puppet):
		return
	if not puppet.trigger_attack(duration_seconds()):
		return
	pose_history.append({"side": "hero", "position": int(hero["position"]),
		"id": String(hero["id"]), "card_id": card_id, "anchor": "presentation",
		"target_position": int(hit["position"]), "target_id": String(hit["id"]),
		"hp": int(hit["hp"]), "block": int(hit["block"]), "fast": fast_animations,
		"duration": float(puppet.attack_span)})
	if pose_history.size() > POSE_HISTORY_LIMIT:
		pose_history = pose_history.slice(pose_history.size() - POSE_HISTORY_LIMIT)


func _card_counts(cards: Array) -> Dictionary:
	var counts := {}
	for card in cards:
		var id := String(card)
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


func _read_held_sources(app) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if not is_instance_valid(app.hand_view) or not app.hand_view.is_visible_in_tree():
		return sources
	var counts := _card_counts(app.deck.hand)
	var found := {}
	for node in app.hand_view.get_children():
		var panel := node as Control
		if panel == null or not panel.is_visible_in_tree() or panel.get_child_count() < 1:
			continue
		var id_label := panel.get_child(0) as Label
		if id_label == null:
			continue
		var id: String = id_label.text
		if int(found.get(id, 0)) >= int(counts.get(id, 0)):
			continue
		var rect := panel.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		found[id] = int(found.get(id, 0)) + 1
		sources.append({"card_id": id, "panel_id": panel.get_instance_id(), "rect": rect})
	return sources


## A loss from the previous held multiset AND a gain to the real discard
## multiset are both mandatory. A pile reshuffle or replacement cannot be
## treated as a committed discard; uncertain transactions are dropped.
func _emit_discard_flights(app) -> void:
	var before_draw := _card_counts(_draw_before)
	var after_draw := _card_counts(app.deck.draw_pile)
	# No refill/reshuffle and no deck composition change during an observed flight.
	for id in after_draw:
		if int(after_draw[id]) > int(before_draw.get(id, 0)):
			return
	var before_discard := _card_counts(_discard_before)
	var after_discard := _card_counts(app.deck.discard_pile)
	for id in before_discard:
		if int(after_discard.get(id, 0)) < int(before_discard[id]):
			return
	var before_hand := _card_counts(_held_before)
	var after_hand := _card_counts(app.deck.hand)
	# A card genuinely left hand even when a same-ID draw replaced that copy:
	# previous held + actual draw-pile loss - current held = committed loss.
	for id in before_hand:
		var drawn: int = int(before_draw.get(id, 0)) - int(after_draw.get(id, 0))
		var committed: int = int(before_hand[id]) + drawn - int(after_hand.get(id, 0))
		if committed < 0 or committed > int(before_hand[id]):
			return
	var target := _discard_anchor(app)
	if target == null:
		return
	var used_sources := {}
	for source in _held_sources:
		var card_id: String = source["card_id"]
		var drawn: int = int(before_draw.get(card_id, 0)) - int(after_draw.get(card_id, 0))
		var lost: int = maxi(0, int(before_hand.get(card_id, 0)) + drawn - int(after_hand.get(card_id, 0)))
		var gained: int = maxi(0, int(after_discard.get(card_id, 0)) - int(before_discard.get(card_id, 0)))
		var allowance: int = mini(lost, gained)
		var already: int = int(used_sources.get(card_id, 0))
		if already >= allowance:
			continue
		if _spawn_discard_flight(source, target, card_id):
			used_sources[card_id] = already + 1


func _discard_anchor(app) -> Control:
	var label := app.pile_label as Control
	if not is_instance_valid(label) or not label.is_visible_in_tree():
		return null
	var rect := label.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return null
	return label


func _owner_color(id: String) -> Color:
	if id.begins_with("warden_"):
		return Color("#4a5d73")
	if id.begins_with("seamstress_"):
		return Color("#6e4f6b")
	if id.begins_with("tinker_"):
		return Color("#c49a3a")
	return Color("#6c6257")


func _spawn_discard_flight(source: Dictionary, target: Control, card_id: String) -> bool:
	if not is_instance_valid(overlay) or not overlay.is_inside_tree():
		return false
	var source_rect: Rect2 = source["rect"]
	var destination := target.get_global_rect()
	var start := _to_overlay(source_rect.get_center()) - FLIGHT_SIZE * 0.5
	# The discard count sits at the right end of the existing pile readout.
	var finish := _to_overlay(destination.position + Vector2(destination.size.x * 0.8,
		destination.size.y * 0.5)) - FLIGHT_SIZE * 0.5
	if start.distance_to(finish) < 12.0:
		return false
	var owner_tint := _owner_color(card_id)
	var scrap := Panel.new()
	scrap.name = "DiscardFlightScrap"
	scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrap.focus_mode = Control.FOCUS_NONE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("#ece0c8")
	paper.border_color = owner_tint
	paper.set_border_width_all(3)
	paper.set_corner_radius_all(3)
	scrap.add_theme_stylebox_override("panel", paper)
	overlay.add_child(scrap)
	scrap.size = FLIGHT_SIZE
	scrap.position = start
	scrap.pivot_offset = FLIGHT_SIZE * 0.5

	var owner_patch := ColorRect.new()
	owner_patch.name = "OwnerFelt"
	owner_patch.color = owner_tint
	owner_patch.position = Vector2(6, 10)
	owner_patch.size = Vector2(9, FLIGHT_SIZE.y - 20)
	owner_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	owner_patch.focus_mode = Control.FOCUS_NONE
	scrap.add_child(owner_patch)
	var title := Label.new()
	title.name = "FlightCardName"
	title.text = card_id.replace("_", " ").capitalize()
	title.position = Vector2(19, 12)
	title.size = Vector2(FLIGHT_SIZE.x - 25, FLIGHT_SIZE.y - 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color("#282525"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.focus_mode = Control.FOCUS_NONE
	scrap.add_child(title)
	# Short cross-stitches on both seams make this a sewn paper/felt scrap.
	for y in [0.0, FLIGHT_SIZE.y - 12.0]:
		var stitches := Label.new()
		stitches.name = "SeamStitches"
		stitches.text = "×  ×  ×  ×  ×  ×  ×"
		stitches.add_theme_font_size_override("font_size", 10)
		stitches.add_theme_color_override("font_color", Color("#51463d"))
		stitches.position = Vector2(12, y)
		stitches.size = Vector2(FLIGHT_SIZE.x - 24, 12)
		stitches.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stitches.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stitches.focus_mode = Control.FOCUS_NONE
		scrap.add_child(stitches)

	var duration := duration_seconds()
	var tween := scrap.create_tween()
	tween.set_parallel(true)
	tween.tween_property(scrap, "position", finish, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scrap, "scale", Vector2(0.35, 0.35), duration)
	tween.tween_property(scrap, "modulate:a", 0.0, duration)
	tween.finished.connect(_retire_flight.bind(weakref(scrap)))
	_flights.append({"scrap": scrap, "tween": tween, "target": target})
	flight_history.append({"card_id": card_id, "panel_id": source["panel_id"],
		"owner_color": owner_tint, "destination": "pile_label",
		"fast": fast_animations, "duration": duration})
	if flight_history.size() > FLIGHT_HISTORY_LIMIT:
		flight_history = flight_history.slice(flight_history.size() - FLIGHT_HISTORY_LIMIT)
	return true


func _retire_flight(ref: WeakRef) -> void:
	var scrap = ref.get_ref()
	if is_instance_valid(scrap):
		scrap.queue_free()
	_flights = _flights.filter(func(entry: Dictionary) -> bool:
		return not _same_node(entry.get("scrap"), scrap))


func live_flights() -> int:
	var count := 0
	for entry in _flights:
		if is_instance_valid(entry.get("scrap")):
			count += 1
	return count
