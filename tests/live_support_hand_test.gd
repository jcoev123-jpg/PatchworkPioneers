extends SceneTree

var failures: Array[String] = []
var checks := 0
var app
var presenter
var reference: CombatDeck
var reference_party: CombatParty
var reference_enemies: CombatEnemies
var reference_rng: RandomNumberGenerator
var service := CombatStarterSupportPlay.new()
var table_instance := 0
const POOL_FORMS := [
	"seamstress_darning", "seamstress_darning_plus",
	"seamstress_thimble_tea", "seamstress_thimble_tea_plus",
	"seamstress_field_mend", "seamstress_field_mend_plus",
]
## The committed sewn HUD art the real mounted battle must actually display. Every path is
## checked against the real loaded resource, never against a copied constant alone.
const HUD_ART := {
	"tray": "res://assets/paper/ui/hud_hand_tray.png",
	"draw": "res://assets/paper/ui/hud_draw_pile.png",
	"discard": "res://assets/paper/ui/hud_discard_pile.png",
	"energy": "res://assets/paper/ui/hud_energy.png",
	"end_turn": "res://assets/paper/ui/hud_end_turn.png",
}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _frames() -> void:
	await process_frame
	await process_frame


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _keyboard(code: Key) -> void:
	root.push_input(_key(code), true)
	root.push_input(_key(code, false), true)
	await _frames()


func _mouse(control: Control, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)
		if pressed:
			# A burst before deferred activation must still resolve just once.
			root.push_input(event, true)
	await _frames()


func _hover(control: Control) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	await _frames()


func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


func _snapshot(deck: CombatDeck, party: CombatParty, rng: RandomNumberGenerator) -> Array:
	return [deck.draw_pile.duplicate(), deck.hand.duplicate(), deck.discard_pile.duplicate(),
		deck.energy, deck.turn_active, party.get_heroes(), rng.seed, rng.state]


func _live() -> Array:
	return [_snapshot(app.deck, app.party, app.run_rng), app.enemy_attacks.duplicate(true),
		app.enemy_intents.get_intents(), app.intent_label.text, app.run_seed, app.enemies.get_enemies()]


func _visible() -> void:
	_check(app.enemies.get_enemies() == reference_enemies.get_enemies(), "all enemy HP and Block match independent reference")
	if "--inject-wrong-energy" in OS.get_cmdline_user_args() and is_instance_valid(presenter.energy_label):
		presenter.energy_label.text = "deliberately wrong"
	var ids: Array[String] = []
	for panel in app.hand_view.get_children():
		_check(panel is PanelContainer and panel.is_visible_in_tree(), "mounted hand panel")
		_check(panel.get_child_count() > 0 and panel.get_child(0) is Label, "first child remains Label")
		var id: String = panel.get_child(0).text
		ids.append(id)
		if id in presenter.SUPPORT_IDS:
			_check(panel.focus_mode == Control.FOCUS_ALL and panel.get_child_count() == 1 and not panel.get_child(0).visible,
				"support keeps focus and its original ID without overprinted hints")
			_check(panel.gui_input.get_connections().size() == 1, "exactly one input binding")
		else:
			var attack: bool = StarterCards.new().get_definition(id).get("target_kind") in ["enemy_single", "enemy_all"]
			_check(panel.focus_mode == Control.FOCUS_NONE and panel.gui_input.get_connections().size() == (1 if attack else 0),
				"other cards preserve focus; held attacks bind exactly one input handler")
	_check(ids == app.deck.hand, "mounted labels match entire authoritative hand")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [app.deck.draw_pile.size(), app.deck.discard_pile.size()],
		"mounted pile counts exact")
	_check(is_instance_valid(presenter.energy_label) and presenter.energy_label.is_visible_in_tree(), "energy mounted")
	if is_instance_valid(presenter.energy_label):
		_check(presenter.energy_label.text == "%d" % app.deck.energy, "visible energy exact")
		_check(presenter.energy_label.text.is_valid_int()
			and not presenter.energy_label.text.contains("Energy"),
			"spool shows the amount alone, never a wrapped Energy word")
	_check(is_instance_valid(presenter.energy_orb) and presenter.energy_label.get_parent() == presenter.energy_orb
		and presenter.energy_orb.is_visible_in_tree(), "energy belongs to the mounted drawn orb")
	_check(presenter.energy_orb.focus_mode == Control.FOCUS_NONE
		and presenter.energy_orb.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and presenter.energy_orb.gui_input.get_connections().is_empty(), "energy orb is inert")
	var orb: Control = presenter.energy_orb
	var disc: Rect2 = orb.disc_rect()
	_check(orb.custom_minimum_size == Vector2(76, 76) and orb.size.x >= 76.0 and orb.size.y >= 76.0,
		"energy control keeps its fixed size contract")
	_check(disc.size.x > 0.0 and disc.size.y > 0.0 and Rect2(Vector2.ZERO, orb.size).encloses(disc)
		and orb.size.y - disc.size.y >= 8.0,
		"drawn energy spool is inset inside its control instead of touching the footer edge")
	_check(orb.draw_count > 0 and orb.disc_radius() < minf(orb.size.x, orb.size.y) * 0.5,
		"energy fabric and radial stitches are drawn inside the control")
	_check(presenter.energy_label.get_minimum_size().x <= disc.size.x
		and presenter.energy_label.get_minimum_size().y <= disc.size.y,
		"the amount alone stays inside the inset disc without overflowing the spool")
	_check(root.get_visible_rect().encloses(Rect2(orb.get_global_rect().position + disc.position, disc.size)),
		"the whole energy disc clears the 1280x720 viewport edges")
	_check(not orb.get_global_rect().intersects(app.hand_view.get_global_rect())
		and not orb.get_global_rect().intersects(app.pile_label.get_global_rect())
		and not orb.get_global_rect().intersects(app.end_turn_button.get_global_rect()),
		"energy spool never obscures the hand, the piles or End Turn")
	_check(presenter.help_label.text == presenter.TABLE_HELP, "short table guidance exact outside card names")
	_check(presenter.TABLE_HELP.length() <= 8 and not presenter.TABLE_HELP.contains("Sewing table")
		and not presenter.TABLE_HELP.contains("Up/Down") and not presenter.TABLE_HELP.contains("\n"),
		"idle footer shows a tiny Help cue, never the long idle sentence")
	_check(presenter.help_label.size_flags_horizontal != Control.SIZE_EXPAND_FILL,
		"idle Help cue shrinks instead of consuming a stretch row")
	_check(presenter.help_label.focus_mode == Control.FOCUS_NONE
		and presenter.help_label.gui_input.get_connections().is_empty(),
		"Help cue adds no keyboard focus target or input handler")
	_check(presenter.help_label.has_theme_stylebox_override("normal")
		and presenter.help_label.get_child_count() == 1
		and presenter.help_label.get_child(0).mouse_filter == Control.MOUSE_FILTER_IGNORE
		and presenter.help_label.get_child(0).focus_mode == Control.FOCUS_NONE,
		"Help cue is a sewn patch whose stitch drawing is pointer and focus inert")
	_check(presenter.help_label.get_line_count() > 0
		and presenter.help_label.get_visible_line_count() == presenter.help_label.get_line_count(),
		"Help cue renders every line it wraps")
	_check(presenter.help_label.tooltip_text == presenter.TABLE_HELP_DETAIL
		and presenter.help_label.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"complete instructions stay reachable on a hoverable help label")
	_check(presenter.TABLE_HELP_DETAIL.contains("Click") and presenter.TABLE_HELP_DETAIL.contains("Enter / Space")
		and presenter.TABLE_HELP_DETAIL.contains("Up / Down") and presenter.TABLE_HELP_DETAIL.contains("Esc"),
		"tooltip keeps the complete mouse and keyboard instructions")
	_check(app.battle_view.find_children("SupportHandEnergyOrb", "Control", true, false).size() == 1
		and app.battle_view.find_children("SupportHandHelp", "Label", true, false).size() == 1
		and app.battle_view.find_children("SupportHandFooterSpring", "Control", true, false).size() == 1,
		"repeated sync leaves exactly one orb, help cue and inert spring")
	_table_checks("live sync")
	_hud_art_checks("live sync")
	for index in range(3):
		var hero: Dictionary = app.party.get_hero(index + 1)
		_check(app.hero_panels[index].get_child(0).text == "%d - %s\nHP: %d/%d | Block: %d%s" % [
			hero.position, hero.name, hero.hp, hero.max_hp, hero.block,
			"\nDOWNED" if hero.hp == 0 else ""], "visible hero HP/Block exact")


## One sewn felt table behind the real lower controls: mounted once, inert, and sized from
## the live orb, hand, pile row and End Turn rather than fixed pixel positions.
func _table_checks(stage: String) -> void:
	var mounted: Array = app.battle_view.find_children(presenter.TABLE_ID, "Control", true, false)
	_check(mounted.size() == 1, "exactly one stitched table backing: " + stage)
	if mounted.size() != 1:
		return
	var table: Control = mounted[0]
	_check(presenter.backing == table and table.get_parent() == app.battle_view
		and table.is_visible_in_tree(), "table is the mounted presenter control: " + stage)
	var column: Control = app.hand_view.get_parent() as Control
	_check(column != null and column.get_parent() == app.battle_view
		and table.get_index() < column.get_index(), "table draws behind every existing battle control: " + stage)
	_check(table.mouse_filter == Control.MOUSE_FILTER_IGNORE and table.focus_mode == Control.FOCUS_NONE
		and table.gui_input.get_connections().is_empty() and table.get_child_count() == 0,
		"table is pointer/focus inert and holds no display controls: " + stage)
	_check(app.hand_view.find_children(presenter.TABLE_ID, "Control", true, false).is_empty()
		and app.hand_view.get_child_count() == app.deck.hand.size(),
		"table never joins the hand container or changes its child count: " + stage)
	_check(table.band.size.x > 0.0 and table.band.size.y > 0.0
		and Rect2(Vector2.ZERO, table.size).encloses(table.band),
		"measured table stays inside the battle area: " + stage)
	_check(table.covers(app.pile_label) and table.covers(app.hand_view)
		and table.covers(presenter.energy_orb) and table.covers(presenter.help_label)
		and table.covers(app.end_turn_button), "table spans the piles, hand, orb, help and End Turn: " + stage)
	_check(not table.overlaps(app.hero_view), "table never covers the actor stage: " + stage)
	_check(table.draw_count > 0, "table actually drew its felt and stitches: " + stage)
	if table_instance == 0:
		table_instance = table.get_instance_id()
	else:
		_check(table.get_instance_id() == table_instance,
			"the same single table survives repeated frames, plays and turns: " + stage)


## One control's rect in the mounted table's own coordinates, for band/art geometry.
func _local_rect(control: Control) -> Rect2:
	var rect := control.get_global_rect()
	return Rect2(rect.position - presenter.backing.get_global_rect().position, rect.size)


## The authored HUD art must be the really resolved textures, placed from the live layout,
## while every existing count, focus target and press signal stays exactly as it was.
func _hud_art_checks(stage: String) -> void:
	for key in HUD_ART:
		_check(ResourceLoader.exists(HUD_ART[key], "Texture2D") and load(HUD_ART[key]) is Texture2D,
			"committed HUD art loads: " + HUD_ART[key])
	var table: Control = presenter.backing
	_check(is_instance_valid(table) and table.tray_texture is Texture2D
		and table.tray_art_path() == HUD_ART["tray"],
		"mounted table paints the committed hand tray: " + stage)
	if not is_instance_valid(table):
		return
	var hand := _local_rect(app.hand_view)
	_check(table.tray_rect.size.x > 0.0 and table.tray_rect.size.y > 0.0
		and table.band.encloses(table.tray_rect) and table.tray_rect.encloses(hand)
		and table.covers(app.hand_view),
		"hand tray fills the sewn band behind every mounted card: " + stage)
	var source: Rect2 = table.tray_source_rect()
	var pixels: Vector2 = table.tray_texture.get_size()
	_check(source.size.x > 0.0 and source.size.y > 0.0
		and Rect2(Vector2.ZERO, pixels).encloses(source)
		and absf(source.size.x / source.size.y - table.tray_rect.size.x / table.tray_rect.size.y) < 0.02,
		"tray picture keeps its own proportions inside the live cloth: " + stage)
	_check(table.tray_draw_count > 0 and table.draw_count > 0,
		"table actually painted the authored tray and its felt: " + stage)
	var orb: Control = presenter.energy_orb
	_check(orb.texture is Texture2D and orb.art_path() == HUD_ART["energy"] and orb.art_draw_count > 0,
		"energy spool paints the committed energy art inside its inset disc: " + stage)
	_check(Rect2(Vector2.ZERO, orb.size).encloses(orb.disc_rect())
		and orb.size.y - orb.disc_rect().size.y >= 8.0,
		"authored energy spool keeps the present inset disc contract: " + stage)
	_check(presenter.energy_label.text == "%d" % app.deck.energy
		and presenter.energy_label.get_theme_constant("outline_size") > 0
		and presenter.energy_label.get_minimum_size().x <= orb.disc_rect().size.x
		and presenter.energy_label.get_minimum_size().y <= orb.disc_rect().size.y
		and presenter.energy_label.is_visible_in_tree(),
		"the real energy number stays legible over the authored spool: " + stage)
	_pile_token_checks(stage)
	var button: Button = app.end_turn_button
	var face := button.get_theme_stylebox("normal") as StyleBoxTexture
	_check(face != null and face.texture is Texture2D
		and face.texture.resource_path == HUD_ART["end_turn"]
		and button.get_meta("hud_end_turn_art", "") == HUD_ART["end_turn"],
		"the original End Turn button displays its authored face: " + stage)
	_check(button.text == "End Turn" and button.pressed.get_connections().size() == 1
		and button.focus_mode == Control.FOCUS_ALL and not button.disabled
		and button.focus_next == button.get_path_to(app.return_button)
		and not button.focus_previous.is_empty()
		and button.get_node_or_null(button.focus_previous) is Button,
		"authored face never replaces the pressed signal, focus or Tab cycle: " + stage)
	_check(button.get_theme_stylebox("hover") is StyleBoxTexture
		and button.get_theme_stylebox("pressed") is StyleBoxTexture
		and button.get_theme_stylebox("disabled") is StyleBoxTexture,
		"hover, pressed and disabled keep the same authored icon: " + stage)
	_check(root.get_visible_rect().encloses(button.get_global_rect())
		and button.get_combined_minimum_size() == Vector2(240, 48)
		and root.get_visible_rect().encloses(app.pile_label.get_parent().get_global_rect()),
		"the authored face never grows the accepted End Turn control and stays inside 1280x720: " + stage)


## Both authored pile pictures sit beside the one existing count Label: no duplicated
## number, no pointer or keyboard target and no extra control anywhere.
func _pile_token_checks(stage: String) -> void:
	var row: Node = app.pile_label.get_parent()
	_check(row != null and is_instance_valid(presenter.draw_token)
		and is_instance_valid(presenter.discard_token),
		"both inert pile tokens are mounted beside the counts: " + stage)
	if row == null or not is_instance_valid(presenter.draw_token) \
			or not is_instance_valid(presenter.discard_token):
		return
	var draw_token: Control = presenter.draw_token
	var discard_token: Control = presenter.discard_token
	_check(row.find_children("SupportHandDrawPile", "Control", true, false).size() == 1
		and row.find_children("SupportHandDiscardPile", "Control", true, false).size() == 1,
		"exactly one draw and one discard token: " + stage)
	_check(draw_token.texture is Texture2D and draw_token.art_path() == HUD_ART["draw"]
		and discard_token.texture is Texture2D and discard_token.art_path() == HUD_ART["discard"],
		"pile tokens draw the committed draw and discard art: " + stage)
	_check(draw_token.get_index() == app.pile_label.get_index() - 1
		and discard_token.get_index() == app.pile_label.get_index() + 1,
		"tokens sit immediately beside the one existing pile label: " + stage)
	for token in [draw_token, discard_token]:
		_check(token.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and token.focus_mode == Control.FOCUS_NONE
			and token.gui_input.get_connections().is_empty()
			and not token is BaseButton and token.get_child_count() == 0,
			"pile token is pointer/focus inert and owns no control: " + stage)
		_check(token.art_rect().size.x > 0.0
			and Rect2(Vector2.ZERO, token.size).grow(0.5).encloses(token.art_rect()),
			"authored pile token keeps its picture inside its own box: " + stage)
		_check(token.draw_count > 0 and token.size.x >= 16.0 and token.size.y >= 16.0,
			"pile token really painted a readable picture: " + stage)
		_check(root.get_visible_rect().encloses(token.get_global_rect()),
			"pile token fits the 1280x720 viewport: " + stage)
	_check(draw_token.get_global_rect().end.x <= app.pile_label.get_global_rect().position.x
		and discard_token.get_global_rect().position.x >= app.pile_label.get_global_rect().end.x
		and not draw_token.get_global_rect().intersects(app.pile_label.get_global_rect())
		and not discard_token.get_global_rect().intersects(app.pile_label.get_global_rect()),
		"tokens flank the counts without covering a single digit: " + stage)
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
		app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and row.find_children("*", "Label", true, false).size() == 1,
		"the one existing pile Label keeps the exact current deck counts: " + stage)


## Real pointer hover over the compact cue: the complete instructions must be reachable from
## the mounted footer, not merely stored on an inert label.
func _help_hover_case(stage: String) -> void:
	await _hover(presenter.help_label)
	_check(root.gui_get_hovered_control() == presenter.help_label,
		"real pointer hover reaches the compact Help cue: " + stage)
	_check(presenter.help_label.tooltip_text == presenter.TABLE_HELP_DETAIL
		and presenter.help_label.tooltip_text.contains("Enter / Space"),
		"hovered Help cue exposes the complete sewing-table instructions: " + stage)
	_check(presenter.help_label.focus_mode == Control.FOCUS_NONE
		and not app.hand_view.is_ancestor_of(presenter.help_label),
		"hovering the cue adds no focus target and never enters the hand: " + stage)


## A real mounted-battle resize must re-measure the same sewn table and its authored tray,
## with no second backing and no duplicated HUD art.
func _resize_case() -> void:
	var before: Rect2 = presenter.backing.band
	var tray_before: Rect2 = presenter.backing.tray_rect
	var orb_id: int = presenter.energy_orb.get_instance_id()
	app.battle_view.size = Vector2(1024, 600)
	await _frames()
	_table_checks("resized battle area")
	_hud_art_checks("resized battle area")
	_check(presenter.backing.band != before and presenter.backing.band.size.y > 0.0,
		"table follows a live battle-area resize")
	_check(presenter.backing.tray_rect != tray_before and presenter.backing.tray_rect.size.x > 0.0
		and presenter.backing.band.encloses(presenter.backing.tray_rect),
		"authored hand tray follows the resized cloth instead of a fixed rect")
	_check(presenter.energy_orb.get_instance_id() == orb_id
		and presenter.energy_orb.art_path() == HUD_ART["energy"],
		"resize repaints the same authored spool without remounting it")
	app.battle_view.size = Vector2(1280, 720)
	await _frames()
	_table_checks("restored battle area")
	_hud_art_checks("restored battle area")


## Dropping the presenter and rebinding the same live battle mounts exactly one set of
## authored HUD nodes and repaints every committed image on them.
func _rebind_case() -> void:
	var table: Control = presenter.backing
	presenter._clear()
	_check(presenter.backing == null and presenter.energy_orb == null
		and presenter.draw_token == null and presenter.discard_token == null,
		"clearing the presenter drops every authored HUD node")
	await _frames()
	presenter._sync_battle()
	_check(is_instance_valid(presenter.backing) and presenter.backing != table
		and is_instance_valid(presenter.draw_token) and presenter.energy_orb.texture is Texture2D,
		"rebinding the live battle mounts one fresh authored HUD")
	_check(app.battle_view.find_children(presenter.TABLE_ID, "Control", true, false).size() == 1
		and app.battle_view.find_children("SupportHandEnergyOrb", "Control", true, false).size() == 1
		and app.find_children("SupportHandDrawPile", "Control", true, false).size() == 1
		and app.find_children("SupportHandDiscardPile", "Control", true, false).size() == 1,
		"rebinding never duplicates a tray, pile token or orb")
	_hud_art_checks("rebound presenter")
	# The intentional rebind replaces the table once; later checks track the new one.
	table_instance = presenter.backing.get_instance_id()
	_visible()


## Missing committed art must fall back to the drawn felt, spool, packet and theme button
## on the SAME mounted nodes, keeping counts, focus and the real turn transaction.
func _missing_art_case() -> void:
	var table: Control = presenter.backing
	var orb: Control = presenter.energy_orb
	var draw_token: Control = presenter.draw_token
	var discard_token: Control = presenter.discard_token
	var button: Button = app.end_turn_button
	var ids := [table.get_instance_id(), orb.get_instance_id(), draw_token.get_instance_id(),
		discard_token.get_instance_id(), button.get_instance_id()]
	var table_draws: int = table.draw_count
	var orb_draws: int = orb.draw_count
	var tray_draws: int = table.tray_draw_count
	var token_draws: int = draw_token.draw_count
	var counts: String = app.pile_label.text
	presenter.ui_art_root = "res://assets/paper/ui/absent/"
	presenter._sync_battle()
	await _frames()
	_check(table.tray_texture == null and orb.texture == null
		and draw_token.texture == null and discard_token.texture == null,
		"missing HUD art resolves to no texture instead of a broken one")
	_check(str(button.get_meta("hud_end_turn_art", "")) == ""
		and not button.has_theme_stylebox_override("normal"),
		"missing End Turn art restores the existing theme face")
	_check(presenter.backing == table and presenter.energy_orb == orb
		and presenter.draw_token == draw_token and presenter.discard_token == discard_token
		and app.end_turn_button == button
		and [table.get_instance_id(), orb.get_instance_id(), draw_token.get_instance_id(),
			discard_token.get_instance_id(), button.get_instance_id()] == ids,
		"missing art reuses the mounted nodes instead of mounting duplicates")
	_check(app.battle_view.find_children(presenter.TABLE_ID, "Control", true, false).size() == 1
		and app.battle_view.find_children("SupportHandEnergyOrb", "Control", true, false).size() == 1
		and app.find_children("SupportHandDrawPile", "Control", true, false).size() == 1
		and app.find_children("SupportHandDiscardPile", "Control", true, false).size() == 1,
		"the fallback leaves exactly one of each mounted HUD node")
	_check(table.draw_count > table_draws and orb.draw_count > orb_draws
		and draw_token.draw_count > token_draws and table.tray_draw_count == tray_draws,
		"drawn felt, spool and pile packet fallbacks are painted instead of the missing art")
	_check(app.pile_label.text == counts
		and presenter.energy_label.text == "%d" % app.deck.energy
		and button.pressed.get_connections().size() == 1
		and button.focus_mode == Control.FOCUS_ALL and button.text == "End Turn",
		"fallback keeps the exact counts, the focus and the original press signal")
	# The unchanged real button still resolves a full turn while the art is missing.
	_check(reference.end_turn(), "reference ends an art-free turn")
	_reference_enemy_phase()
	_check(reference.start_turn() and reference_party.start_player_turn(),
		"reference starts an art-free turn")
	await _mouse(button)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"End Turn keeps its real transaction while the authored art is missing")
	_check(app.pile_label.text == "Draw: %d | Discard: %d" % [
			app.deck.draw_pile.size(), app.deck.discard_pile.size()]
		and draw_token.texture == null and discard_token.texture == null
		and presenter.energy_label.text == "%d" % app.deck.energy,
		"post-turn counts stay authoritative and the tokens keep the fallback")
	presenter.ui_art_root = presenter.UI_ART_DIR
	presenter._sync_battle()
	await _frames()
	_check(table.tray_art_path() == HUD_ART["tray"] and orb.art_path() == HUD_ART["energy"]
		and draw_token.art_path() == HUD_ART["draw"]
		and discard_token.art_path() == HUD_ART["discard"]
		and button.get_meta("hud_end_turn_art", "") == HUD_ART["end_turn"],
		"restoring the art root repaints the committed HUD art on the same nodes")
	_hud_art_checks("restored art root")
	_visible()


func _panel(id: String) -> Control:
	for panel in app.hand_view.get_children():
		if panel.get_child(0).text == id:
			return panel
	return null


func _start(seed_value: int) -> bool:
	app.run_seed = seed_value
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty and app.party.is_valid() \
		and app.run_rng != null and is_instance_valid(app.battle_view)
	_check(ready, "real focused title button starts complete session")
	if not ready:
		return false
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	reference_rng = RandomNumberGenerator.new()
	reference_rng.seed = seed_value
	reference = CombatDeck.new(cards, reference_rng)
	reference.start_turn()
	reference_party = CombatParty.new(app._load_party_definitions())
	reference_enemies = CombatEnemies.new(app._load_enemy_definitions())
	CombatStartingBlock.new(reference_party).apply()
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"no support action before activation; independent opening matches")
	table_instance = 0
	_visible()
	return true


func _turn() -> void:
	_check(reference.end_turn(), "reference ends turn")
	_reference_enemy_phase()
	_check(reference.start_turn() and reference_party.start_player_turn(), "reference starts turn")
	await _mouse(app.end_turn_button)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"actual End Turn matches reference, including enemy damage and RNG")
	_visible()


func _reference_enemy_phase() -> void:
	for action in app.enemy_attacks:
		if reference_enemies.is_slain(action.enemy_position):
			continue
		if action.type == "attack":
			_check(CombatEnemyAttacks.new().execute_attacks(reference_party, [action]).ok, "reference enemy attack")
		else:
			_check(CombatEnemyBlocks.execute_blocks(reference_enemies, [action]).ok, "reference enemy Block")


func _play_card(id: String, keyboard: bool) -> void:
	var panel := _panel(id)
	_check(is_instance_valid(panel), "required held support found: " + id)
	if panel == null:
		return
	var intent_before: Array = [app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.intent_label.text]
	_check(service.play_card(reference, reference_party, id, 0), "independent service accepts " + id)
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_SPACE)
	else:
		await _mouse(panel)
	_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
		"mounted input matches complete service result: " + id)
	_check([app.enemy_attacks, app.enemy_intents.get_intents(), app.intent_label.text] == intent_before,
		"support leaves intent cadence unchanged")
	_visible()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real scene loads")
	if scene == null:
		_finish()
		return
	app = scene.instantiate()
	root.add_child(app)
	await _frames()
	presenter = app.get_node("LiveSupportHand")
	_check(app.deck == null and presenter._bindings.is_empty(), "title has no support bindings")
	# Find a deterministic opening with Brace, so it must stack atop the real passive.
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	var seed_value := -1
	for candidate in range(100):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if "warden_brace" in deck.hand:
			seed_value = candidate
			break
	_check(seed_value >= 0, "deterministic Brace opening exists")
	var trace: Array = []
	var previous_table := 0
	for session in range(2):
		if not await _start(seed_value):
			app.free()
			_finish()
			return
		var session_table: int = presenter.backing.get_instance_id() if is_instance_valid(presenter.backing) else 0
		_check(session_table != 0 and (session == 0 or session_table != previous_table),
			"each Return/start mounts one fresh table instead of a stale one")
		previous_table = session_table
		var before := _live()
		_fixture_start(app)
		presenter._sync_battle()
		presenter._sync_battle()
		_check(_live() == before, "duplicate start and sync never play")
		_visible()
		_table_checks("repeated presenter sync")
		await _help_hover_case("mounted session %d" % session)
		if session == 0:
			await _resize_case()
			await _rebind_case()
		for inert in app.hand_view.get_children():
			if inert.get_child(0).text not in presenter.SUPPORT_IDS:
				before = _live()
				var id: String = inert.get_child(0).text
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				presenter._on_card_input(click, inert, id, app.deck, app.party, app.battle_view)
				await _frames()
				_check(_live() == before, "support callback rejects every non-support ID: " + id)
				# Bomb now casts on left click; right click must still reject.
				await _mouse(inert, MOUSE_BUTTON_RIGHT if id == "tinker_scrap_bomb" else MOUSE_BUTTON_LEFT)
				_check(_live() == before, "unconfirmed single attack or right-click Bomb never spends")
		# Navigation from the existing button cycle reaches the support card row.
		app.end_turn_button.grab_focus()
		await _keyboard(KEY_UP)
		_check(app.hand_view.is_ancestor_of(root.gui_get_focus_owner()), "keyboard Up reaches support row")
		var brace := _panel("warden_brace")
		if brace == null:
			_check(false, "opening Brace mounted")
			break
		before = _live()
		await _mouse(brace, MOUSE_BUTTON_RIGHT)
		brace.grab_focus()
		root.push_input(_key(KEY_ENTER, true, true), true)
		await _frames()
		_check(_live() == before, "right click and key echo fail closed")
		_check(app.party.get_hero(1).block == 6, "real opening protection precedes Brace")
		await _play_card("warden_brace", false)
		_check(app.party.get_hero(1).block == 13 and app.deck.energy == 2, "Brace adds seven atop opening six and spends one")
		# Captured callback is stale after successful play, even if explicitly replayed.
		before = _live()
		presenter._activate(brace, "warden_brace", app.deck, app.party, app.battle_view)
		_check(_live() == before, "failed replay cannot charge a second time")
		var found := false
		for turn in range(12):
			if _panel("tinker_tune_up") != null:
				found = true
				break
			await _turn()
		_check(found, "Tune Up held across deterministic real turns")
		if found:
			_check(not app.deck.draw_pile.is_empty(), "normal Tune Up has a draw pile")
			await _play_card("tinker_tune_up", true)
		# Find Tune Up again, then drain the remaining draw pile via the real deck API
		# to exercise its seeded discard reshuffle through mounted input.
		found = false
		for turn in range(12):
			await _turn()
			if _panel("tinker_tune_up") != null:
				found = true
				break
		_check(found, "second held Tune Up found")
		if found:
			if app.deck.discard_pile.is_empty():
				var discard_id: String = ""
				for id in app.deck.hand:
					if id != "tinker_tune_up":
						discard_id = id
						break
				_check(not discard_id.is_empty() and app.deck.discard_played(discard_id)
					and reference.discard_played(discard_id), "real discard supplies reshuffle fixture")
			var count: int = app.deck.draw_pile.size()
			_check(app.deck.draw_extra(count) == reference.draw_extra(count), "draw fixture uses real deck API")
			app._refresh_hand()
			await _frames()
			_check(app.deck.draw_pile.is_empty() and not app.deck.discard_pile.is_empty(), "nonvacuous reshuffle preconditions")
			await _play_card("tinker_tune_up", false)
		var final := _live()
		if session == 0:
			trace = final
		else:
			_check(final == trace, "same-seed return/start replays complete state with no leaked callbacks")
		await _negative_cases()
		var closed_table: int = presenter.backing.get_instance_id() if is_instance_valid(presenter.backing) else 0
		_check(closed_table != 0 and closed_table == table_instance, "session kept its single table through play and turns")
		app.return_button.pressed.emit()
		_check(presenter._bindings.is_empty() and presenter._deck == null, "Return immediately disconnects session")
		_check(presenter.backing == null, "Return drops the table reference immediately")
		await _frames()
		_check(app.deck == null and presenter.energy_label == null and presenter.energy_orb == null
			and presenter.help_label == null and presenter.cancel_button == null, "title removes all support presentation")
		_check(app.find_children("SupportHandEnergyOrb", "Control", true, false).is_empty(), "Return leaves no orphan orb")
		_check(app.find_children("SupportHandHelp", "Label", true, false).is_empty()
			and app.find_children("SupportHandHelpStitch", "Control", true, false).is_empty()
			and app.find_children("SupportHandFooterSpring", "Control", true, false).is_empty()
			and presenter.footer_spring == null,
			"Return frees the Help cue, its stitches and the inert spring")
		_check(app.find_children(presenter.TABLE_ID, "Control", true, false).is_empty()
			and not is_instance_id_valid(closed_table), "Return frees the felt table instead of reusing it")
		_check(presenter.draw_token == null and presenter.discard_token == null
			and app.find_children("SupportHandDrawPile", "Control", true, false).is_empty()
			and app.find_children("SupportHandDiscardPile", "Control", true, false).is_empty(),
			"Return frees both inert pile tokens instead of leaving them on the title")
		table_instance = 0
	await _ally_cases()
	await _ally_move_cases()
	await _stale_restart(seed_value)
	await _pool_heal_cases()
	await _missing_art_session(seed_value)
	app.free()
	_finish()


## A fresh real session proves the authored art and its fallback on the mounted battle.
func _missing_art_session(seed_value: int) -> void:
	if not await _start(seed_value):
		return
	await _missing_art_case()
	app.return_button.pressed.emit()
	await _frames()
	_check(app.find_children("SupportHandDrawPile", "Control", true, false).is_empty()
		and app.find_children("SupportHandDiscardPile", "Control", true, false).is_empty()
		and presenter.draw_token == null and presenter.discard_token == null,
		"the art session returns to a title without pile tokens")


func _negative_cases() -> void:
	# Locate Brace using normal turns; no fixed hand fixture bypasses the live flow.
	for turn in range(12):
		if _panel("warden_brace") != null:
			break
		await _turn()
	var panel := _panel("warden_brace")
	_check(panel != null, "negative cases have a real held Brace")
	if panel == null:
		return
	var battle: Control = app.battle_view
	var deck: CombatDeck = app.deck
	var party: CombatParty = app.party
	var event := _key(KEY_ENTER)
	panel.grab_focus()
	var before := _live()
	presenter._on_card_input(null, panel, "warden_brace", deck, party, battle)
	presenter._on_card_input(event, panel, "seamstress_prick", deck, party, battle)
	var foreign := PanelContainer.new()
	root.add_child(foreign)
	presenter._on_card_input(event, foreign, "warden_brace", deck, party, battle)
	presenter._on_card_input(event, panel, "warden_brace", reference, party, battle)
	foreign.free()
	await _frames()
	_check(_live() == before, "null/foreign/wrong ID/wrong session inputs preserve complete state")
	battle.hide()
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "hidden battle cannot act")
	battle.show()
	panel.hide()
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "hidden panel cannot act")
	panel.show()
	deck.combat_state.energy = 0
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "zero energy cannot spend or mutate RNG/party/piles")
	deck.combat_state.energy = 3
	deck.combat_state.player_turn_active = false
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "inactive player turn cannot act")
	deck.combat_state.player_turn_active = true
	_check(party.apply_damage(1, 10000), "downed owner fixture applied")
	_check(party.is_downed(1), "owner really downed")
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "downed owner cannot act")
	_check(deck.discard_played("warden_brace"), "remove held copy for unavailable-card case")
	before = _live()
	await _mouse(panel)
	_check(_live() == before, "unavailable card on stale mounted panel cannot act")
	# Keep the old panel alive while detaching it, then restart the real app.
	app.hand_view.remove_child(panel)
	presenter._sync_battle()
	_check(panel.gui_input.get_connections().is_empty(), "detached panel disconnected")
	presenter._on_card_input(event, panel, "warden_brace", deck, party, battle)
	await _frames()
	_check(_live() == before, "detached input cannot mutate old session")
	panel.free()


func _stale_restart(seed_value: int) -> void:
	if not await _start(seed_value):
		return
	var panel := _panel("warden_brace")
	_check(panel != null, "stale callback has real mounted source")
	if panel == null:
		return
	var callback: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_state := _snapshot(old_deck, old_party, old_rng)
	# Queue input then Return before dispatch completes: the pending play is cancelled.
	panel.grab_focus()
	callback.call(_key(KEY_ENTER))
	app.return_button.pressed.emit()
	_check(panel.gui_input.get_connections().is_empty(), "Return disconnects still-live old panel")
	await _frames()
	_check(_snapshot(old_deck, old_party, old_rng) == old_state, "queued input cancelled on Return")
	if not await _start(seed_value):
		return
	var before := _live()
	callback.call(_key(KEY_ENTER))
	await _frames()
	_check(_live() == before and _snapshot(old_deck, old_party, old_rng) == old_state,
		"captured callback with freed controls cannot act in restarted session")
	# An intervening End Turn also invalidates a queued activation before it can spend.
	panel = _panel("warden_brace")
	_check(panel != null, "queued End Turn case has held Brace")
	if panel != null:
		panel.grab_focus()
		presenter._bindings[panel].call(_key(KEY_ENTER))
		_check(reference.end_turn(), "queued-turn reference ends")
		_reference_enemy_phase()
		_check(reference.start_turn() and reference_party.start_player_turn(), "queued-turn reference starts")
		app.end_turn_button.pressed.emit()
		await _frames()
		_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng),
			"queued old-turn activation cannot play into the new hand")
	app.return_button.pressed.emit()
	await _frames()


func _ally_start() -> bool:
	var cards: Array[String] = []
	cards.assign(JSON.parse_string(FileAccess.get_file_as_string(app.STARTER_DECK_PATH)))
	for candidate in range(1000):
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var deck := CombatDeck.new(cards, rng)
		deck.start_turn()
		if "seamstress_mend" in deck.hand and "seamstress_stitch_up" in deck.hand:
			return await _start(candidate)
	_check(false, "seeded opening contains both ally cards")
	return false


func _select_ally(id: String, keyboard: bool) -> bool:
	var panel := _panel(id)
	_check(is_instance_valid(panel), "real held ally card mounted: " + id)
	if panel == null:
		return false
	var before := _live()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(_live() == before, "pending ally choice never charges or changes rules")
	var choosing: bool = presenter._pending.get("choosing", false)
	_check(choosing and presenter.cancel_button.is_visible_in_tree(), "target mode and cancel visible")
	_check(presenter.help_label.text == "%s: choose a living ally | Esc: cancel" % StarterCards.new().get_definition(id).display_name,
		"exact targeting help separate from energy")
	_check(presenter.help_label.get_line_count() > 0
		and presenter.help_label.get_visible_line_count() == presenter.help_label.get_line_count(),
		"target prompt renders every wrapped line without clipping")
	_check(presenter.help_label.size_flags_horizontal == Control.SIZE_EXPAND_FILL
		and not presenter.footer_spring.visible,
		"target prompt expands to the available footer width while the idle cue shrinks")
	_check(presenter.energy_label.text == "%d" % app.deck.energy, "target mode retains authoritative orb energy")
	_check(root.get_visible_rect().encloses(presenter.cancel_button.get_global_rect()), "cancel fits 1280x720 viewport")
	for index in range(3):
		var hero: Control = app.hero_panels[index]
		var living: bool = not app.party.is_downed(index + 1)
		_check((hero.focus_mode == Control.FOCUS_ALL) == living, "only living ally focusable")
		_check(presenter._targets.has(hero) == living, "only living ally has input callback")
		if living:
			_check(hero.get_child_count() == 3 and hero.get_child(2) is Label
				and hero.get_child(2).is_visible_in_tree() and hero.get_child(2).text.contains("Choose ally")
				and hero.get_child(1).name.begins_with("HeroPuppet")
				and hero.get_child(1).mouse_filter == Control.MOUSE_FILTER_IGNORE, "visible hero target cue above inert puppet")
			_check(hero.has_theme_stylebox_override("focus"), "visible hero focus outline")
	return choosing


func _ally_return() -> void:
	# Negative hidden-battle input checks have finished; make cleanup reachable.
	app.battle_view.show()
	app.return_button.pressed.emit()
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "Return clears all target state immediately")
	await _frames()


func _ally_cases() -> void:
	# Every success begins at the real title with a seeded, unmodified starter hand.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for target in [1, 2, 3]:
			if not await _ally_start():
				return
			if id == "seamstress_mend" and target != 3:
				var damage := 9 if target == 1 else 2
				_check(app.party.apply_damage(target, damage) and reference_party.apply_damage(target, damage), "wounded ally fixture")
			if id == "seamstress_stitch_up":
				_check(app.party.gain_block(target, 3) and reference_party.gain_block(target, 3), "existing Block fixture")
			app._refresh_party()
			var old_energy: int = app.deck.energy
			var old_discard: int = app.deck.discard_pile.size()
			var old_hand: int = app.deck.hand.size()
			var old_hero: Dictionary = app.party.get_hero(target)
			var intent_before: Array = [app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(), app.intent_label.text]
			if await _select_ally(id, target != 1):
				var pending_before := _live()
				await _mouse(app.hero_panels[target - 1], MOUSE_BUTTON_RIGHT)
				app.hero_panels[target - 1].grab_focus()
				root.push_input(_key(KEY_ENTER, true, true), true)
				await _frames()
				_check(_live() == pending_before, "target right-click and key echo never resolve")
				app.hero_panels[0].grab_focus()
				_check(service.play_card(reference, reference_party, id, target), "reference accepts chosen living ally")
				var hero: Control = app.hero_panels[target - 1]
				if target == 1:
					await _mouse(hero)
				else:
					# Reach the hero using real focus navigation, then use both accept keys.
					for step in range(target - 1):
						await _keyboard(KEY_TAB)
					_check(hero.has_focus(), "Tab reaches chosen hero")
					var code := KEY_SPACE if target == 2 else KEY_ENTER
					root.push_input(_key(code), true)
					root.push_input(_key(code), true)
					root.push_input(_key(code, false), true)
					await _frames()
				_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng), "chosen ally matches authoritative effect; other heroes and RNG unchanged")
				_check(app.deck.energy == old_energy - 1 and app.deck.discard_pile.size() == old_discard + 1
					and app.deck.hand.size() == old_hand - 1 and app.deck.discard_pile.back() == id, "exact one-energy one-card charge")
				var updated: Dictionary = app.party.get_hero(target)
				if id == "seamstress_mend":
					_check(updated.hp == mini(old_hero.max_hp, old_hero.hp + 5), "Mend heals up to five including full HP")
				else:
					_check(updated.block == old_hero.block + 5, "Stitch stacks exactly five Block")
				_check([app.enemy_attacks, app.enemy_intents.get_intents(), app.intent_label.text] == intent_before, "ally play leaves intents unchanged")
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "success removes target handlers")
				_visible()
			await _ally_return()
	# Both cards share the same fail-closed interaction, including queued target callbacks.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for scenario in ["escape", "queued_cancel", "cancel", "downed_target", "downed_after", "downed_owner", "zero", "inactive", "hidden", "absent", "replace", "turn", "return", "stale", "switch", "detached", "foreign", "invalid_target"]:
			if not await _ally_start():
				return
			if scenario == "downed_target":
				_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "target truly downed")
			if not await _select_ally(id, false):
				await _ally_return()
				continue
			var hero: Control = app.hero_panels[1]
			var callback: Callable = presenter._targets[hero].callback
			var before := _live()
			if scenario == "escape":
				await _keyboard(KEY_ESCAPE)
			elif scenario == "queued_cancel":
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				root.push_input(_key(KEY_ESCAPE), true)
				root.push_input(_key(KEY_ESCAPE, false), true)
			elif scenario == "cancel":
				await _mouse(presenter.cancel_button)
			elif scenario == "downed_target":
				await _mouse(app.hero_panels[0])
			elif scenario == "foreign":
				var foreign := PanelContainer.new()
				root.add_child(foreign)
				presenter._on_target_input(_key(KEY_ENTER), foreign, 2, presenter._token)
				foreign.free()
			elif scenario == "invalid_target":
				hero.grab_focus()
				for position in [0, 1, 4]:
					presenter._on_target_input(_key(KEY_ENTER), hero, position, presenter._token)
			elif scenario == "turn":
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				await _turn()
				before = _live()
			elif scenario == "return":
				var old_deck: CombatDeck = app.deck
				var old_party: CombatParty = app.party
				var old_rng: RandomNumberGenerator = app.run_rng
				var old_state := _snapshot(old_deck, old_party, old_rng)
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
				await _ally_return()
				_check(_snapshot(old_deck, old_party, old_rng) == old_state, "queued target Return never spends")
				if not await _ally_start():
					return
				before = _live()
				callback.call(_key(KEY_ENTER))
			elif scenario == "stale":
				await _keyboard(KEY_ESCAPE)
				await _select_ally(id, true)
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			elif scenario == "switch":
				var other_id := "seamstress_stitch_up" if id == "seamstress_mend" else "seamstress_mend"
				await _select_ally(other_id, true)
				_check(presenter._pending.id == other_id, "only the newly selected card remains pending")
				hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			else:
				if scenario == "downed_owner":
					_check(app.party.apply_damage(2, 10000) and app.party.is_downed(2), "Seamstress truly downed")
				elif scenario == "downed_after":
					_check(app.party.apply_damage(1, 10000) and app.party.is_downed(1), "target downed during pending choice")
					hero = app.hero_panels[0]
					callback = presenter._targets[hero].callback
				elif scenario == "zero":
					app.deck.combat_state.energy = 0
				elif scenario == "inactive":
					app.deck.combat_state.player_turn_active = false
				elif scenario == "hidden":
					app.battle_view.hide()
				elif scenario == "absent":
					_check(app.deck.discard_played(id), "selected card actually removed")
				elif scenario == "replace":
					app._refresh_hand()
				elif scenario == "detached":
					var card: Control = _panel(id)
					app.hand_view.remove_child(card)
					presenter._sync_battle()
					card.free()
				before = _live()
				if hero.focus_mode == Control.FOCUS_ALL and hero.is_visible_in_tree():
					hero.grab_focus()
				callback.call(_key(KEY_ENTER))
			await _frames()
			_check(_live() == before, "ally rejection preserves full state: " + id + "/" + scenario)
			if scenario in ["escape", "queued_cancel", "cancel", "replace", "turn", "hidden", "downed_owner", "downed_after", "zero", "inactive", "absent", "detached"]:
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "cancellation removes queued work and target callbacks: " + scenario)
				_check(presenter.help_label.text == presenter.TABLE_HELP
					and presenter.help_label.size_flags_horizontal != Control.SIZE_EXPAND_FILL
					and presenter.footer_spring.visible,
					"cancellation restores the compact Help cue: " + scenario)
				if scenario == "escape":
					await _help_hover_case("after Esc cancellation")
				for panel in app.hero_panels:
					_check(panel.focus_mode == Control.FOCUS_NONE and panel.get_child_count() == 2
						and panel.get_child(1).name.begins_with("HeroPuppet")
						and panel.gui_input.get_connections().is_empty(), "cancel restores inert hero panels")
			await _ally_return()
	# Authored from-positions: Mend rejects front, accepts back; Stitch accepts front.
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for position in [1, 3]:
			if not await _ally_start():
				return
			var definitions: Array = app._load_party_definitions()
			var seamstress = definitions.pop_at(1)
			definitions.insert(position - 1, seamstress)
			app.party = CombatParty.new(definitions)
			reference_party = CombatParty.new(definitions)
			presenter._sync_battle()
			app._refresh_party()
			_check(app.party.get_hero(position).id == "seamstress", "actual owner at authored position fixture")
			# Settle the view after replacing the party, before checking input is inert.
			app._refresh_intents()
			_check(app.intent_label.text == "Intent: Enemy 1 -> Hero 1 (%s): 1 damage; Enemy 2: 1 Block" % app.party.get_hero(1).name,
				"reordered fixture announces the actual hero at the authored target")
			var before := _live()
			if id == "seamstress_mend" and position == 1:
				await _mouse(_panel(id))
				_check(_live() == before and presenter._pending.is_empty(), "front Mend rejects without target mode or spend")
			else:
				if await _select_ally(id, true):
					_check(service.play_card(reference, reference_party, id, position), "authored owner position accepted")
					await _mouse(app.hero_panels[position - 1])
					_check(_snapshot(app.deck, app.party, app.run_rng) == _snapshot(reference, reference_party, reference_rng), "authored position live play matches service")
			await _ally_return()


func _ally_move_cases() -> void:
	for id in ["seamstress_mend", "seamstress_stitch_up"]:
		for mode in ["queued", "unconfirmed_input", "unconfirmed_sync"]:
			for keyboard in [false, true]:
				if not await _ally_start():
					return
				# Distinct actor-owned state must travel with each proposed actor.
				for index in range(3):
					_check(app.party.apply_damage(index + 1, index + 3)
						and reference_party.apply_damage(index + 1, index + 3), "movement fixture wounds living heroes")
					_check(app.party.gain_block(index + 1, index + 2)
						and reference_party.gain_block(index + 1, index + 2), "movement fixture gives distinct Block")
					app.party._heroes[index]["statuses"] = {"weak": index + 1, "bleed": index + 2}
					reference_party._heroes[index]["statuses"] = {"weak": index + 1, "bleed": index + 2}
				app._refresh_party()
				if not await _select_ally(id, keyboard):
					await _ally_return()
					continue
				var hero: Control = app.hero_panels[1]
				var callback: Callable = presenter._targets[hero].callback
				var chosen: Dictionary = app.party.get_hero(2)
				_check(chosen.id == "seamstress" and chosen.hp > 0, "living slot-2 recipient really selected")
				hero.grab_focus()
				var event: InputEvent = _key(KEY_SPACE)
				if not keyboard:
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.pressed = true
					click.position = hero.get_global_rect().get_center()
					event = click
				if mode == "queued":
					# Real viewport dispatch queues resolution; install movement before yielding.
					root.push_input(event, true)
					_check(presenter._pending.get("queued", false), "target input actually queued before swap")
					_check(presenter._pending.target == {"position": 2, "hero_id": chosen.id}, "queued action retains actor and slot")
				var before_move := _live()
				var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, 1)
				_check(proposal.ok and proposal.heroes.size() == 3, "real adjacent preview accepts living slots 2/3")
				_check(_live() == before_move, "preview itself leaves complete live state unchanged")
				if not proposal.ok:
					await _ally_return()
					continue
				app.party._heroes.assign(proposal.heroes)
				var reference_proposal := CombatPositionSwaps.preview_adjacent_swap(reference_party, 2, 1)
				_check(reference_proposal.ok, "reference movement valid")
				reference_party._heroes.assign(reference_proposal.heroes)
				var expected_move := before_move.duplicate(true)
				expected_move[0][5] = proposal.heroes.duplicate(true)
				var after_move := _live()
				_check(after_move == expected_move, "only intentional roster swap changes state; actor HP/Block/statuses retained")
				_check(app.party.get_hero(2).id == "tinker" and app.party.get_hero(3).id == chosen.id,
					"slot 2 really has a different living occupant")
				if mode == "unconfirmed_sync":
					presenter._sync_battle()
				elif mode == "unconfirmed_input":
					# Exercise admission before the next presentation sync can cancel it.
					callback.call(event)
				await _frames()
				_check(_live() == after_move, "movement rejects old recipient without any transaction: " + id + "/" + mode)
				_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "movement clears pending choice and bindings")
				_check(not presenter.cancel_button.visible and _panel(id).has_focus(), "movement hides cancel and restores card focus")
				for panel in app.hero_panels:
					_check(panel.focus_mode == Control.FOCUS_NONE and not panel.has_focus()
						and panel.get_child_count() == 2 and panel.get_child(1).name.begins_with("HeroPuppet")
						and panel.gui_input.get_connections().is_empty()
						and not panel.has_theme_stylebox_override("focus")
						and panel.focus_next.is_empty() and panel.focus_previous.is_empty()
						and panel.focus_neighbor_bottom.is_empty(), "movement removes target cues, navigation and focus")
				callback.call(event)
				await _frames()
				_check(_live() == after_move, "captured pre-movement target callback stays inert")
				app._refresh_party()
				if await _select_ally(id, keyboard):
					# A fresh choice may target the new occupant at its current slot.
					var old_hero: Dictionary = app.party.get_hero(2)
					_check(service.play_card(reference, reference_party, id, 2), "service accepts newly chosen occupant")
					var expected := after_move.duplicate(true)
					expected[0] = _snapshot(reference, reference_party, reference_rng)
					if keyboard:
						app.hero_panels[0].grab_focus()
						await _keyboard(KEY_TAB)
						_check(hero.has_focus(), "Tab reaches moved slot-2 occupant")
						root.push_input(_key(KEY_SPACE), true)
						root.push_input(_key(KEY_SPACE), true)
						root.push_input(_key(KEY_SPACE, false), true)
						await _frames()
					else:
						await _mouse(hero)
					_check(_live() == expected, "fresh moved target matches one authoritative transaction and preserves all other state")
					_check(app.deck.energy == after_move[0][3] - 1
						and app.deck.hand.size() == after_move[0][1].size() - 1
						and app.deck.discard_pile.size() == after_move[0][2].size() + 1
						and app.deck.discard_pile.back() == id, "moved target charged and discarded exactly once")
					var updated: Dictionary = app.party.get_hero(2)
					_check(updated.id == old_hero.id and (updated.hp == mini(old_hero.max_hp, old_hero.hp + 5)
						if id == "seamstress_mend" else updated.block == old_hero.block + 5), "authored effect applies to new occupant")
					_check(presenter._pending.is_empty() and presenter._targets.is_empty(), "moved target success clears controls")
				await _ally_return()


## Complete mounted state: every pile, actor, intent and the injected run RNG.
func _pool_state() -> Array:
	return [app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.party.get_heroes(), app.enemies.get_enemies(),
		app.enemy_attacks.duplicate(true), app.enemy_intents.get_intents(),
		app.intent_label.text, app.run_rng.seed, app.run_rng.state,
		app.battle_result.get_outcome(), app.session_gold]


## Independent catalog-derived expectation: only the authored heal/Block changes.
func _pool_expected(before: Array, card_id: String, target: int) -> Array:
	var after: Array = before.duplicate(true)
	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	after[3] = int(after[3]) - int(definition.get("cost", -1))
	after[1].erase(card_id)
	after[2].append(card_id)
	var heal: int = int(effects.get("heal", 0))
	if definition.get("target_kind") == "party_all":
		for index in range(after[5].size()):
			var hero: Dictionary = after[5][index]
			if int(hero["hp"]) > 0:
				hero["hp"] = mini(int(hero["max_hp"]), int(hero["hp"]) + heal)
	else:
		var chosen: Dictionary = after[5][target - 1]
		chosen["hp"] = mini(int(chosen["max_hp"]), int(chosen["hp"]) + heal)
		chosen["block"] = int(chosen["block"]) + int(effects.get("block", 0))
	return after


func _pool_panel(card_id: String) -> Control:
	if not is_instance_valid(app.hand_view):
		return null
	for panel in app.hand_view.get_children():
		if panel.get_child_count() > 0 and panel.get_child(0) is Label \
				and panel.get_child(0).text == card_id:
			return panel
	return null


## Real standalone battle plus a real CombatDeck draw of the authored pool copy.
func _pool_start(card_id: String) -> bool:
	_check(app.deck == null, "title precedes the pool heal battle: " + card_id)
	app.run_seed = 4247
	_fixture_start(app)
	await _frames()
	var ready: bool = app.deck is CombatDeck and app.party is CombatParty \
		and app.enemies != null and app.battle_result != null and app.run_rng != null \
		and is_instance_valid(app.battle_view) and is_instance_valid(app.hand_view)
	_check(ready, "real standalone battle starts complete: " + card_id)
	if not ready:
		return false
	app.deck.draw_pile.append(card_id)
	_check(app.deck.draw_extra(1) == 1 and app.deck.hand.back() == card_id,
		"real CombatDeck draw supplies the authored copy: " + card_id)
	app._refresh_hand()
	await _frames()
	var panel := _pool_panel(card_id)
	_check(is_instance_valid(panel), "authored pool heal card is mounted: " + card_id)
	if panel == null:
		return false
	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	var facts: Dictionary = presenter._metadata.get_facts(panel)
	_check(facts.get("known") == true and facts.get("id") == card_id
		and facts.get("display_name") == definition.display_name
		and facts.get("cost") == definition.cost
		and facts.get("owner") == "seamstress",
		"mounted face shows the authored name, cost and owner: " + card_id)
	_check(presenter._heal_cards != null and presenter._is_heal_card(card_id)
		and presenter._is_actionable(card_id),
		"mounted presenter routes this authored ID to the pool heal resolver: " + card_id)
	_check(panel.focus_mode == Control.FOCUS_ALL
		and panel.gui_input.get_connections().size() == 1,
		"pool heal card has exactly one live input binding: " + card_id)
	return true


func _pool_return() -> void:
	if is_instance_valid(app.return_button):
		app.return_button.pressed.emit()
	await _frames()
	_check(app.deck == null and presenter._deck == null and presenter._heal_cards == null,
		"pool heal return releases every session binding")


func _pool_ally_case(card_id: String, target: int, keyboard: bool) -> void:
	if not await _pool_start(card_id):
		await _pool_return()
		return
	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	var panel := _pool_panel(card_id)
	_check(app.party.apply_damage(target, 14), "chosen ally is genuinely wounded: " + card_id)
	app._refresh_party()
	await _frames()
	var before := _pool_state()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	_check(_pool_state() == before, "arming an ally heal never pre-spends: " + card_id)
	_check(presenter._pending.get("choosing", false)
		and presenter.cancel_button.is_visible_in_tree(),
		"mounted heal opens real living-ally target mode: " + card_id)
	_check(presenter.help_label.text == "%s: choose a living ally | Esc: cancel" % definition.display_name,
		"target prompt names the authored card: " + card_id)
	var hero: Control = app.hero_panels[target - 1]
	if keyboard:
		app.hero_panels[0].grab_focus()
		for step in range(target - 1):
			await _keyboard(KEY_TAB)
		_check(hero.has_focus(), "Tab reaches the chosen living ally: " + card_id)
		root.push_input(_key(KEY_ENTER), true)
		root.push_input(_key(KEY_ENTER, false), true)
		await _frames()
	else:
		await _mouse(hero)
	var expected := _pool_expected(before, card_id, target)
	_check(_pool_state() == expected,
		"mounted heal matches catalog on party, piles, intents and RNG: " + card_id)
	var chosen: Dictionary = app.party.get_hero(target)
	var was: Dictionary = before[5][target - 1]
	_check(chosen.hp == mini(int(was.max_hp), int(was.hp) + int(effects.heal)),
		"exact authored heal amount: " + card_id)
	if effects.has("block"):
		_check(chosen.block == int(was.block) + int(effects.block),
			"exact authored Block amount: " + card_id)
	_check(app.deck.energy == int(before[3]) - int(definition.cost),
		"exact authored energy cost: " + card_id)
	_check(app.deck.discard_pile.back() == card_id
		and app.deck.discard_pile.count(card_id) == int(before[2].count(card_id)) + 1,
		"exactly one played copy discarded: " + card_id)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(),
		"mounted heal clears target state: " + card_id)
	await _pool_return()


func _pool_field_case(card_id: String, down_position: int, keyboard: bool) -> void:
	if not await _pool_start(card_id):
		await _pool_return()
		return
	var definition: Dictionary = SeamstressPoolCards.new().get_definition(card_id)
	var effects: Dictionary = definition.get("effects", {})
	_check(app.party.apply_damage(1, 10) and app.party.apply_damage(2, 10)
		and app.party.apply_damage(3, 10), "all living heroes are wounded before Field Mend")
	if down_position > 0:
		_check(app.party.apply_damage(down_position, 9999)
			and app.party.is_downed(down_position),
			"a genuinely downed hero is present for Field Mend")
	app._refresh_party()
	await _frames()
	var panel := _pool_panel(card_id)
	var before := _pool_state()
	if keyboard:
		panel.grab_focus()
		await _keyboard(KEY_ENTER)
	else:
		await _mouse(panel)
	var expected := _pool_expected(before, card_id, 0)
	_check(_pool_state() == expected,
		"Field Mend matches catalog on party, piles, intents and RNG: " + card_id)
	for index in range(3):
		var was: Dictionary = before[5][index]
		var now: Dictionary = app.party.get_hero(index + 1)
		if int(was.hp) == 0:
			_check(int(now.hp) == 0, "downed hero stays unchanged: " + card_id)
		else:
			_check(int(now.hp) == mini(int(was.max_hp), int(was.hp) + int(effects.heal)),
				"exact authored heal for every living hero: " + card_id)
	_check(app.deck.energy == int(before[3]) - int(definition.cost)
		and app.deck.discard_pile.back() == card_id
		and app.deck.discard_pile.count(card_id) == int(before[2].count(card_id)) + 1,
		"Field Mend spends exactly two energy and one copy: " + card_id)
	_check(presenter._pending.is_empty() and presenter._targets.is_empty(),
		"Field Mend needs no ally selection: " + card_id)
	await _pool_return()


func _pool_cancel_cases() -> void:
	for mode in ["escape", "queued_cancel", "cancel_button"]:
		if not await _pool_start("seamstress_thimble_tea"):
			await _pool_return()
			continue
		var panel := _pool_panel("seamstress_thimble_tea")
		await _mouse(panel)
		_check(presenter._pending.get("choosing", false),
			"cancel case really armed: " + mode)
		var hero: Control = app.hero_panels[2]
		var callback: Callable = presenter._targets[hero].callback
		if mode == "escape":
			await _keyboard(KEY_ESCAPE)
		elif mode == "queued_cancel":
			hero.grab_focus()
			callback.call(_key(KEY_ENTER))
			root.push_input(_key(KEY_ESCAPE), true)
			root.push_input(_key(KEY_ESCAPE, false), true)
			await _frames()
		else:
			await _mouse(presenter.cancel_button)
		var after := _pool_state()
		_check(presenter._pending.is_empty() and presenter._targets.is_empty()
			and not presenter.cancel_button.visible,
			"cancellation clears every target handler: " + mode)
		# The detached callback from this canceled choice can never commit later.
		callback.call(_key(KEY_ENTER))
		await _frames()
		_check(_pool_state() == after, "canceled target callback stays inert: " + mode)
		await _pool_return()


func _pool_rejection_cases() -> void:
	# Insufficient energy: otherwise a real held Darning.
	if not await _pool_start("seamstress_darning"):
		await _pool_return()
		return
	app.deck.combat_state.energy = 0
	var before := _pool_state()
	await _mouse(_pool_panel("seamstress_darning"))
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"insufficient energy rejects without target mode or spend")
	app.deck.combat_state.energy = 3
	# Absent copy: a stale mounted panel cannot act on a hand without it.
	var panel := _pool_panel("seamstress_darning")
	_check(app.deck.discard_played("seamstress_darning"), "held copy genuinely removed")
	before = _pool_state()
	await _mouse(panel)
	_check(_pool_state() == before, "absent copy rejects without spend")
	await _pool_return()

	# Downed target and then a downed owner.
	if not await _pool_start("seamstress_darning"):
		await _pool_return()
		return
	_check(app.party.apply_damage(3, 9999) and app.party.is_downed(3),
		"third ally genuinely downed")
	app._refresh_party()
	await _frames()
	await _mouse(_pool_panel("seamstress_darning"))
	_check(presenter._pending.get("choosing", false)
		and not presenter._targets.has(app.hero_panels[2])
		and app.hero_panels[2].focus_mode == Control.FOCUS_NONE,
		"downed ally is not offered as a target")
	before = _pool_state()
	presenter._on_target_input(_key(KEY_ENTER), app.hero_panels[2], 3, presenter._token)
	await _frames()
	_check(_pool_state() == before, "downed ally receipt cannot commit")
	await _keyboard(KEY_ESCAPE)
	_check(app.party.apply_damage(2, 9999) and app.party.is_downed(2),
		"Seamstress owner genuinely downed")
	app._refresh_party()
	await _frames()
	before = _pool_state()
	await _mouse(_pool_panel("seamstress_darning"))
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"downed owner cannot arm or spend")
	await _pool_return()

	# Authored source slot: Thimble Tea requires Seamstress in the middle or back.
	if not await _pool_start("seamstress_thimble_tea_plus"):
		await _pool_return()
		return
	var proposal := CombatPositionSwaps.preview_adjacent_swap(app.party, 2, -1)
	_check(proposal.ok and proposal.heroes[0].id == "seamstress",
		"production preview moves Seamstress to the front")
	app.party._heroes.assign(proposal.heroes)
	app._refresh_party()
	presenter._sync_battle()
	await _frames()
	before = _pool_state()
	await _mouse(_pool_panel("seamstress_thimble_tea_plus"))
	_check(_pool_state() == before and presenter._pending.is_empty(),
		"wrong owner slot rejects without spend")
	await _pool_return()

	# Hidden battle, hidden panel and foreign session objects.
	if not await _pool_start("seamstress_field_mend"):
		await _pool_return()
		return
	panel = _pool_panel("seamstress_field_mend")
	before = _pool_state()
	app.battle_view.hide()
	presenter._on_card_input(_press(), panel, "seamstress_field_mend",
		app.deck, app.party, app.battle_view)
	await _frames()
	_check(_pool_state() == before, "hidden battle rejects Field Mend")
	app.battle_view.show()
	panel.hide()
	presenter._on_card_input(_press(), panel, "seamstress_field_mend",
		app.deck, app.party, app.battle_view)
	await _frames()
	_check(_pool_state() == before, "hidden panel rejects Field Mend")
	panel.show()
	var foreign_party := CombatParty.new(app._load_party_definitions())
	presenter._on_card_input(null, panel, "seamstress_field_mend",
		app.deck, app.party, app.battle_view)
	presenter._on_card_input(_press(), panel, "seamstress_field_mend",
		app.deck, foreign_party, app.battle_view)
	presenter._on_card_input(_press(), panel, "seamstress_darning",
		app.deck, app.party, app.battle_view)
	await _frames()
	_check(_pool_state() == before,
		"null/foreign/wrong-ID input preserves every pool heal field")
	await _pool_return()


func _pool_stale_and_duplicate_cases() -> void:
	# Repeated zero-cost activation and a captured stale card callback.
	if not await _pool_start("seamstress_thimble_tea_plus"):
		await _pool_return()
		return
	var panel := _pool_panel("seamstress_thimble_tea_plus")
	var callback: Callable = presenter._bindings[panel]
	var before := _pool_state()
	await _mouse(panel)
	await _mouse(app.hero_panels[0])
	var expected := _pool_expected(before, "seamstress_thimble_tea_plus", 1)
	_check(_pool_state() == expected,
		"double mouse burst plays a zero-cost Tea+ only once")
	callback.call(_press())
	await _frames()
	_check(_pool_state() == expected and presenter._pending.is_empty(),
		"stale card callback cannot replay a zero-cost play")
	await _pool_return()

	# A callback captured in a released session cannot mutate the new battle.
	if not await _pool_start("seamstress_darning_plus"):
		await _pool_return()
		return
	panel = _pool_panel("seamstress_darning_plus")
	var stale: Callable = presenter._bindings[panel]
	var old_deck: CombatDeck = app.deck
	var old_party: CombatParty = app.party
	var old_rng: RandomNumberGenerator = app.run_rng
	var old_snapshot := _snapshot(old_deck, old_party, old_rng)
	await _pool_return()
	if not await _pool_start("seamstress_darning_plus"):
		return
	var current := _pool_state()
	stale.call(_press())
	await _frames()
	_check(_pool_state() == current and presenter._pending.is_empty(),
		"stale prior-session card callback cannot play")
	_check(_snapshot(old_deck, old_party, old_rng) == old_snapshot,
		"released prior session objects stay unchanged")
	await _pool_return()


func _pool_heal_cases() -> void:
	for card_id in POOL_FORMS:
		_check(SeamstressPoolCards.new().has_card(card_id),
			"required authored pool heal record present: " + card_id)
	# Alternate real mouse and keyboard input across base and '+' forms.
	await _pool_ally_case("seamstress_darning", 1, false)
	await _pool_ally_case("seamstress_darning_plus", 2, true)
	await _pool_ally_case("seamstress_thimble_tea", 3, false)
	await _pool_ally_case("seamstress_thimble_tea_plus", 1, true)
	await _pool_field_case("seamstress_field_mend", 3, false)
	await _pool_field_case("seamstress_field_mend_plus", 0, true)
	await _pool_cancel_cases()
	await _pool_rejection_cases()
	await _pool_stale_and_duplicate_cases()


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_support_hand_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
