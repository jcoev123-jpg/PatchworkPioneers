class_name StitchedCorridorVisit
extends Control
## Owner 11-09: a road stop is a little shop on the corridor floor, seen through the doll's own
## eyes. Whoever keeps it waits ahead; what it offers lies on the floorboards like the dolls do,
## and its words show only on the thing being looked at. A thing more than one doll could take
## is picked up first, then given to a doll from a row of round portraits; walking on is the
## stitched arrow past the keeper (or Up). Presentation only: the host makes and wires every
## choice button, and this page places and dresses them where they are made.

const CHROME := preload("res://scripts/stitched/stitched_battle_chrome.gd")
## Half-size felt: its pillow border fits a 44/42/62/60 nine-slice, so the rounds sit inside its stitching.
const FELT := preload("res://assets/paper/ui/panel_felt_slim.png")
const FELT_MARGINS := [44, 42, 62, 60]
const ICONS := "res://assets/paper/stitched/icons/"
const BONE := Color("f0ddc0")
const LIT := Color(1.45, 1.25, 1.0)
const DIM := Color(0.42, 0.4, 0.44)
const KEEPER_HEIGHT := 1.45
const ITEM_HEIGHT := 0.42
const DOLL_HEIGHT := 0.9
const PER_ROW := 5
const FIRST_ROW := 1.9
const ROW_GAP := 0.8
const ROW_HALF := 1.1
const ARROW_LENGTH := 1.2
const ARROW_TILT := 0.45
const ARROW_X := [0.95, -0.95, 0.0]
const ROUND := 84.0
const OPTION := 62.0
const TRAY_TOP := 62.0
const STORY_RECT := Rect2(140, 646, 1000, 56)
## The picture lying on the floor for each kind of choice; the first that exists is used.
const ITEM_ART := {
	"leave": ["floor_arrow"],
	"buy_candle_stub": ["item_candle", ICONS + "candle_bright.png"],
	"bandage": ["item_bandage"],
	"buy_pins": ["item_pins"],
	"buy_thimble_tonic": ["item_tonic"],
	"buy_fresh_stuffing": ["item_stuffing"],
	"buy_dye": ["item_dye"],
	"buy_starch": ["item_starch"],
	"buy_spare_spool": ["item_spool"],
	"buy_patch": ["item_patch"],
	"mend": ["item_needle"],
	"upgrade": ["item_gold_thread"],
	"unsew": ["item_ripper"],
	"sew": ["item_needle"],
	"calm": ["item_sachet"],
	"unpick": ["item_ripper"],
}
## Event choices have only words; a few telling words pick what lies on the floor.
const WORD_ART := [
	[["walk on", "walk out", "leave", "move on","back away", "long road", "keep going", "go around", "ignore"], "floor_arrow"],
	[["gold", "coin"], "item_coins"],
	[["scrap", "thread", "bundle", "offcut"], "item_bundle"],
	[["candle", "wick"], "item_candle"],
	[["rest", "sleep", "nap"], "item_pillow"],
	[["button"], "item_buttons"],
]
## Every currently authored Event choice with these IDs is a no-effect departure.
## Keep reward choices such as watch_bell and turn_button_clock as actual objects.
const EXIT_ID_PREFIXES := ["leave_", "walk_", "pass_", "ignore_", "close_", "skip_", "decline_"]
const FALLBACK := ["item_parcel", "item_bundle", ICONS + "satchel.png"]

var stage: StitchedCorridorStage
var heading: Label
var story: Label
## One entry per thing on the floor: {key, art, tall, arrow, actions, heroes, by_hero, words}.
var groups: Array = []
## Per group: the Button on the floor (a lone choice's own button, else the opener).
var floor_buttons: Array[Button] = []
## Per group with more than one choice: its tray of round portraits (always in the tree).
var trays: Dictionary = {}
var open_group := -1
var _story_words := ""
var _buttons: Array[Button] = []
var _homes: Array = []
var _party: Dictionary = {}
var _pictures: Array = []
var _keeper: Texture2D
var _navigation: Array[Button] = []
## Only the Garden's unavailable rose-ribbon trade is omitted from the floor.
## Other events (notably Moth sacrifice) retain disabled, inspectable controls.
var _event_visit := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_ensure_parts()
	resized.connect(_place_items)


func _ensure_parts() -> void:
	if stage != null:
		return
	stage = StitchedCorridorStage.new()
	add_child(stage)
	move_child(stage, 0)
	heading = _label("StitchedPageHeading", 22, CHROME.BONE)
	heading.position = Vector2(28, 14)
	heading.size = Vector2(1000, 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(heading)
	story = _label("RouteOrVisitStory", 19, Color("e8d6b8"))
	story.position = STORY_RECT.position
	story.size = STORY_RECT.size
	story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	story.max_lines_visible = 2
	add_child(story)


func _label(title: String, font_size: int, tone: Color) -> Label:
	var label := Label.new()
	label.name = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tone)
	label.add_theme_color_override("font_outline_color", Color("140c0e"))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The corridor where the walk stopped, seen with the doll's eye; the keeper waits ahead.
func present(area_name: String, band_name: String, title: String, words: String, keeper_keys: Array = []) -> void:
	_ensure_parts()
	_event_visit = keeper_keys.has("stop_event")
	stage.build(area_name, 2)
	stage.set_candle(band_name)
	heading.text = title
	_story_words = words
	story.text = words
	_keeper = null
	for key in keeper_keys:
		_keeper = StitchedCorridorStage.art(str(key))
		if _keeper != null:
			break
	var glow := OmniLight3D.new()
	glow.name = "StopGlow"
	glow.light_color = Color(1.0, 0.72, 0.45)
	glow.light_energy = 0.9
	glow.omni_range = 3.6
	stage.figures.add_child(glow)


## Which floor thing a choice belongs to, and the doll it is for ("" when it is for no doll):
## the choice's id with the arguments before the doll. A spare part is one thing however it is sewn.
static func group_of(action: Dictionary, hero_ids: Array) -> Array:
	var id := str(action.get("id", ""))
	var arguments: Array = action.get("arguments", [])
	if id in ["swap", "double_stitch"] and arguments.size() >= 3:
		return ["spare|%d" % int(arguments[2]), str(arguments[0])]
	var key: Array[String] = [id]
	for argument in arguments:
		if hero_ids.has(str(argument)):
			return ["|".join(key), str(argument)]
		key.append(str(argument))
	return ["|".join(key), ""]


## Groups the choices into floor things and returns, per choice, the node its button is made in.
## `party` is [{id, name}] in rank order; `pictures` holds each choice's own part picture or "".
func lay_out(actions: Array, party: Array, pictures: Array) -> Array:
	groups.clear()
	trays.clear()
	_party.clear()
	_pictures = pictures
	var hero_ids: Array = []
	for hero in party:
		hero_ids.append(str(hero.id))
		_party[str(hero.id)] = hero
	var by_key := {}
	var spot: Array = []
	for index in actions.size():
		var found := group_of(actions[index], hero_ids)
		if not by_key.has(found[0]):
			by_key[found[0]] = groups.size()
			groups.append({"key": found[0], "actions": [], "heroes": [], "by_hero": {}})
		var group: Dictionary = groups[by_key[found[0]]]
		group.actions.append(index)
		if not group.by_hero.has(found[1]):
			group.heroes.append(found[1])
			group.by_hero[found[1]] = []
		group.by_hero[found[1]].append(index)
		spot.append([by_key[found[0]], found[1]])
	_homes.clear()
	for number in groups.size():
		var group: Dictionary = groups[number]
		var first: Dictionary = actions[group.actions[0]]
		group.words = _group_words(group, actions)
		group.available = false
		for index in group.actions:
			if actions[index].get("enabled", true):
				group.available = true
		group.art = _group_art(group, actions, pictures)
		group.arrow = _is_arrow(str(first.id), str(first.text))
		group.tall = str(first.id) == "replace"
		if group.actions.size() > 1:
			trays[number] = _tray(number)
	for index in actions.size():
		var number: int = spot[index][0]
		_homes.append(self if groups[number].actions.size() == 1 else trays[number].get_node("Column_%d" % groups[number].heroes.find(spot[index][1])))
	_lay_floor(actions)
	return _homes


func _is_arrow(id: String, text: String) -> bool:
	if id in ["leave", "turn_away", "escape"]:
		return true
	for prefix in EXIT_ID_PREFIXES:
		if id.begins_with(prefix):
			return true
	var lower:= text.to_lower()
	for word in WORD_ART[0][0]:
		if lower.contains(word):
			return true
	return false


## The words a thing says when looked at: the words all of its choices share, dolls left out
## ("Wren / Mend head / 3 scraps" and "Wren / Mend arms / 3 scraps" say "Mend · 3 scraps").
func _group_words(group: Dictionary, actions: Array) -> String:
	var lists: Array = []
	for index in group.actions:
		lists.append(_without_dolls(str(actions[index].text)))
	var shared: Array = []
	for slot in lists[0].size():
		var kept: Array = []
		for word in str(lists[0][slot]).split(" "):
			if lists.all(func(other): return slot < other.size() and str(other[slot]).split(" ").has(word)):
				kept.append(word)
		# A word that only joins to a dropped name ("Sew Red Lint onto <ability>") must not dangle.
		while not kept.is_empty() and str(kept.back()).to_lower() in ["onto", "on", "from", "to"]:
			kept.pop_back()
		if not kept.is_empty():
			shared.append(" ".join(kept))
	return " · ".join(shared if not shared.is_empty() else lists[0])


func _without_dolls(text: String) -> Array:
	var parts: Array = []
	for part in text.split(" / "):
		for hero in _party.values():
			part = part.replace(str(hero.get("name", "")), "") if not str(hero.get("name", "")).is_empty() else part
		part = " ".join(Array(part.split(" ", false)))
		if not part.is_empty():
			parts.append(part)
	return parts


func _group_art(group: Dictionary, actions: Array, pictures: Array) -> Texture2D:
	var first: Dictionary = actions[group.actions[0]]
	# An exit is the road arrow even when its prose mentions coins, threads or
	# no navigation words at all. Do not substitute a parcel for an exit.
	if _is_arrow(str(first.id), str(first.text)):
		var arrow_art := _picture("floor_arrow")
		if arrow_art != null:
			return arrow_art
	if str(first.id) == "replace" and not first.get("arguments", []).is_empty():
		var doll := StitchedCorridorStage.hero_art(str(first.arguments[0]))
		if doll != null:
			return doll
	# A thing that brings its own picture (a felt patch to sew on) lies there as itself.
	var given := str(first.get("floor_art", ""))
	if not given.is_empty() and _picture(given) != null:
		return _picture(given)
	# One part for the whole thing (a spare, a part to unpick): that part's own patch.
	var own := str(pictures[group.actions[0]])
	for index in group.actions:
		if str(pictures[index]) != own:
			own = ""
	var keys: Array = []
	if not own.is_empty():
		keys.append(own)
	keys.append_array(ITEM_ART.get(str(first.id), []))
	var lower := str(first.text).to_lower()
	for row in WORD_ART:
		for word in row[0]:
			if lower.contains(word):
				keys.append(row[1])
	if not str(pictures[group.actions[0]]).is_empty():
		keys.append(str(pictures[group.actions[0]]))
	keys.append_array(FALLBACK)
	for key in keys:
		var art := _picture(str(key))
		if art != null:
			return art
	return null


static func _picture(key: String) -> Texture2D:
	if key.begins_with("res://"):
		return load(key) as Texture2D if ResourceLoader.exists(key) else null
	return StitchedCorridorStage.art(key)


## Do not hide arbitrary disabled Event choices: they must survive Save/Reload
## with their quoted controls, especially the empty Moth's sacrifice and fumigate.
## The Garden's empty-wallet ribbon offer alone is a misleading coin pile.
func _hide_unavailable_offer(group: Dictionary) -> bool:
	return _event_visit and not bool(group.available) and str(group.key) == "sell_rose_ribbon"


## Puts every thing on the floor: arrows past the keeper, the rest in rows nearest first.
func _lay_floor(actions: Array) -> void:
	var things: Array = []
	var arrows: Array = []
	for number in groups.size():
		if _hide_unavailable_offer(groups[number]):
			continue
		(arrows if groups[number].arrow else things).append(number)
	var rows := maxi(1, ceili(things.size() / float(PER_ROW)))
	var keeper_distance := maxf(3.6, FIRST_ROW + rows * ROW_GAP + 0.5)
	if _keeper != null:
		stage.place("keeper", _keeper, stage.ahead_point(keeper_distance), KEEPER_HEIGHT)
	stage.figures.get_node("StopGlow").position = stage.ahead_point(keeper_distance - 0.8) + Vector3(0, 1.2, 0.3)
	for slot in things.size():
		var number: int = things[slot]
		var row := slot / PER_ROW
		var in_row := mini(PER_ROW, things.size() - row * PER_ROW)
		var x := 0.0 if in_row == 1 else lerpf(-ROW_HALF, ROW_HALF, float(slot % PER_ROW) / float(in_row - 1))
		stage.place(_thing_id(number), groups[number].art, stage.ahead_point(FIRST_ROW + row * ROW_GAP, x),
			DOLL_HEIGHT if groups[number].tall else ITEM_HEIGHT)
	for slot in arrows.size():
		var x: float = ARROW_X[slot % ARROW_X.size()]
		stage.place_flat(_thing_id(arrows[slot]), groups[arrows[slot]].art,
			stage.ahead_point(keeper_distance - 0.3, x), ARROW_LENGTH, 0.0, ARROW_TILT)
	for number in groups.size():
		_shade(number, false)


func _thing_id(number: int) -> String:
	return "thing_%d" % number


## A tray of round portraits along the top: one column per doll, the doll's own face first and
## then, when the doll has more than one way to take the thing, each way as a small round patch.
func _tray(number: int) -> Control:
	var group: Dictionary = groups[number]
	var tray := Control.new()
	tray.name = "Tray_%d" % number
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tray)
	var felt := NinePatchRect.new()
	felt.name = "Felt"
	felt.texture = FELT
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		felt.set_patch_margin(side, FELT_MARGINS[side])
	felt.modulate.a = 0.86
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(felt)
	var x: float = FELT_MARGINS[SIDE_LEFT] + 4.0
	var tallest := ROUND
	for column_index in group.heroes.size():
		var hero: String = group.heroes[column_index]
		var count: int = group.by_hero[hero].size()
		var column := Control.new()
		column.name = "Column_%d" % column_index
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var wide := maxf(ROUND, count * (OPTION + 6.0)) if count > 1 else ROUND
		column.position = Vector2(x, FELT_MARGINS[SIDE_TOP] + 4.0)
		column.size = Vector2(wide, ROUND + (OPTION + 8.0 if count > 1 else 0.0))
		tallest = maxf(tallest, column.size.y)
		tray.add_child(column)
		if count > 1:
			var face := _round_art(_bust(hero, group.art), Vector2((wide - ROUND) / 2.0, 0), ROUND)
			face.name = "Face"
			column.add_child(face)
		x += wide + 18.0
	# Playtest 11-09: at 24px margins the bottom row of rounds sat on the felt's border.
	var width: float = x - 18.0 + FELT_MARGINS[SIDE_RIGHT] + 4.0
	tray.position = Vector2(roundf((1280.0 - width) / 2.0), TRAY_TOP)
	tray.size = Vector2(width, FELT_MARGINS[SIDE_TOP] + 4.0 + tallest + FELT_MARGINS[SIDE_BOTTOM] + 4.0)
	felt.size = tray.size
	_show_tray(tray, false)
	return tray


## A round picture: the art cut to a circle with a thin outline, nothing behind it.
func _round_art(texture: Texture2D, where: Vector2, side: float) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	# The size comes after the expand mode, or the art keeps its picture's own size.
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.position = where
	art.size = Vector2(side, side)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.material = StitchedCorridorFight.round_material(side)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


## The top of a doll's picture, its face; the thing itself when the choice is for no doll.
func _bust(hero: String, otherwise: Texture2D) -> Texture2D:
	var art := StitchedCorridorStage.hero_art(hero) if not hero.is_empty() else null
	if art == null:
		return otherwise
	var bust := AtlasTexture.new()
	bust.atlas = art
	var side := minf(art.get_width(), art.get_height() * 0.55)
	bust.region = Rect2((art.get_width() - side) / 2.0, 0, side, side)
	return bust


## Dresses the host's choice buttons where lay_out put them; the floor buttons for things
## with several choices are this page's own openers, never choices themselves.
func dress(buttons: Array[Button]) -> void:
	_buttons = buttons
	floor_buttons.clear()
	for number in groups.size():
		var group: Dictionary = groups[number]
		var button: Button
		if group.actions.size() == 1:
			button = buttons[group.actions[0]]
		else:
			button = Button.new()
			button.name = "Pick_%d" % number
			button.text = str(group.words)
			add_child(button)
			button.pressed.connect(func(): toggle(number))
		_plain(button)
		button.visible = not _hide_unavailable_offer(group)
		button.set_meta("thing", number)
		button.mouse_entered.connect(func(): _look(number, true))
		button.mouse_exited.connect(func(): _look(number, false))
		button.focus_entered.connect(func(): _look(number, true))
		button.focus_exited.connect(func(): _look(number, false))
		floor_buttons.append(button)
		if group.actions.size() > 1:
			_dress_tray(number)
	_place_items()
	_place_items.call_deferred()


## A floor button shows nothing of its own: the thing on the floor is what is seen and lit.
func _plain(button: Button) -> void:
	for face in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(face, StyleBoxEmpty.new())
	for tone in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_disabled_color", "font_hover_pressed_color", "font_outline_color"]:
		button.add_theme_color_override(tone, Color(0, 0, 0, 0))
	button.add_theme_constant_override("outline_size", 0)
	button.clip_text = true
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.icon = null
	button.custom_minimum_size = Vector2.ZERO
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _dress_tray(number: int) -> void:
	var group: Dictionary = groups[number]
	for column_index in group.heroes.size():
		var hero: String = group.heroes[column_index]
		var choices: Array = group.by_hero[hero]
		for option in choices.size():
			var index: int = choices[option]
			var button := _buttons[index]
			_plain(button)
			var side := ROUND if choices.size() == 1 else OPTION
			button.position = Vector2(0, 0) if choices.size() == 1 else Vector2(option * (OPTION + 6.0), ROUND + 8.0)
			button.size = Vector2(side, side)
			var face := _round_art(_bust(hero, group.art) if choices.size() == 1 else _option_art(number, index), Vector2.ZERO, side)
			face.name = "Round"
			button.add_child(face)
			button.mouse_entered.connect(func(): _say(_words(index)))
			button.mouse_exited.connect(func(): _say(""))
			button.focus_entered.connect(func(): _say(_words(index)))
			button.focus_exited.connect(func(): _say(""))
			_shade_option(button, false)
			button.mouse_entered.connect(func(): _shade_option(button, true))
			button.mouse_exited.connect(func(): _shade_option(button, false))
			button.focus_entered.connect(func(): _shade_option(button, true))
			button.focus_exited.connect(func(): _shade_option(button, false))
	_show_tray(trays[number], false)


## Each way to take a thing shows its own part when it has one; a double stitch wears the
## double-stitched border over the spare.
func _option_art(number: int, index: int) -> Texture2D:
	var picture := str(_pictures[index]) if index < _pictures.size() else ""
	var art := _picture(picture) if not picture.is_empty() else null
	return art if art != null else groups[number].art


func _shade_option(button: Button, lit: bool) -> void:
	var face := button.get_node_or_null("Round") as TextureRect
	if face != null:
		face.modulate = DIM if button.disabled else (LIT if lit else Color.WHITE)


func _words(index: int) -> String:
	return str(_buttons[index].text).replace(" / ", " · ")


## The floor buttons cover what the eye sees of their things; a lone arrow keeps a fair size.
func _place_items() -> void:
	for number in floor_buttons.size():
		var button := floor_buttons[number]
		if not is_instance_valid(button) or not button.visible:
			continue
		var seen := stage.screen_rect(_thing_id(number))
		var middle: Variant = stage.screen_point(_thing_id(number))
		if seen.size.x < 4.0 and middle != null:
			seen = Rect2(middle - Vector2(40, 60), Vector2(80, 60))
		if seen.size.x < 4.0:
			seen = Rect2(600 + number * 4, 560, 80, 60)
		var least := Vector2(110, 72) if groups[number].arrow else Vector2(56, 56)
		seen = seen.grow(10)
		if seen.size.x < least.x:
			seen = seen.grow_individual((least.x - seen.size.x) / 2.0, 0, (least.x - seen.size.x) / 2.0, 0)
		if seen.size.y < least.y:
			seen = seen.grow_individual(0, least.y - seen.size.y, 0, 0)
		button.position = seen.position
		button.size = seen.size
	for number in floor_buttons.size():
		if is_instance_valid(floor_buttons[number]) and floor_buttons[number].visible and groups[number].arrow:
			_clear_arrow_overlap(floor_buttons[number])


## The leave arrow's box is tall and can lie beside wares with no gap. Trim it
## with a small cursor-clearance margin, keeping at least a 30px usable target.
func _clear_arrow_overlap(arrow: Button) -> void:
	# Keep each available rectangle until every ware has been considered. A
	# greedy cut can leave a later ware blocking the arrow even when a clear
	# corner of its original picture remains usable.
	var available: Array[Rect2] = [Rect2(arrow.position, arrow.size)]
	for other in floor_buttons:
		if other == arrow or not is_instance_valid(other) or not other.visible:
			continue
		var blocked := Rect2(other.position, other.size).grow(4.0)
		var next: Array[Rect2] = []
		for space in available:
			var hit := space.intersection(blocked)
			if not hit.has_area():
				next.append(space)
				continue
			var cuts: Array[Rect2] = [
				Rect2(space.position, Vector2(hit.position.x - space.position.x, space.size.y)),
				Rect2(Vector2(hit.end.x, space.position.y), Vector2(space.end.x - hit.end.x, space.size.y)),
				Rect2(space.position, Vector2(space.size.x, hit.position.y - space.position.y)),
				Rect2(Vector2(space.position.x, hit.end.y), Vector2(space.size.x, space.end.y - hit.end.y)),
			]
			for cut in cuts:
				if cut.size.x >= 30.0 and cut.size.y >= 30.0:
					next.append(cut)
		available = next
	var best := Rect2()
	for space in available:
		if space.get_area() > best.get_area():
			best = space
	if best.has_area():
		arrow.position = best.position
		arrow.size = best.size


## Opens a thing's tray of dolls, or closes it again; only one tray is open at a time.
func toggle(number: int) -> void:
	var opening := open_group != number
	if open_group >= 0 and trays.has(open_group):
		_show_tray(trays[open_group], false)
		_shade(open_group, false)
	open_group = number if opening else -1
	if opening and trays.has(number):
		_show_tray(trays[number], true)
		_shade(number, true)
		_say(str(groups[number].words))
		for button in _tray_buttons(trays[number]):
			if not button.disabled:
				button.grab_focus()
				break
	_wire_focus()


## Opens the tray a choice lies in (a doll's round), so it can be seen and focused.
func reveal(button: Button) -> void:
	for number in trays:
		if trays[number].is_ancestor_of(button) and open_group != number:
			toggle(number)


func close_tray() -> void:
	if open_group >= 0:
		var number := open_group
		toggle(number)
		if number < floor_buttons.size():
			floor_buttons[number].grab_focus()


## A closed tray stays in the tree but is hidden from hit-testing, assistive tools and focus.
func _show_tray(tray: Control, shown: bool) -> void:
	tray.visible = shown
	tray.modulate.a = 1.0 if shown else 0.0
	for button in _tray_buttons(tray):
		button.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_ALL if shown else Control.FOCUS_NONE


func _tray_buttons(tray: Control) -> Array[Button]:
	var found: Array[Button] = []
	for column in tray.get_children():
		for child in column.get_children():
			if child is Button:
				found.append(child)
	return found


func _look(number: int, lit: bool) -> void:
	_shade(number, lit or number == open_group)
	if not lit:
		_say("")
	elif groups[number].actions.size() > 1:
		_say(str(groups[number].words))
	else:
		_say(_words(groups[number].actions[0]))


## The caption says what is looked at, else the stop's own story.
func _say(words: String) -> void:
	story.text = words if not words.is_empty() else (str(groups[open_group].words) if open_group >= 0 else _story_words)


func _shade(number: int, lit: bool) -> void:
	var figure: Sprite3D = stage.figure_nodes.get(_thing_id(number))
	if figure == null:
		return
	var usable := false
	for index in groups[number].actions:
		if index < _buttons.size() and not _buttons[index].disabled:
			usable = true
	figure.modulate = (LIT if lit else Color.WHITE) if usable or _buttons.is_empty() else DIM


## Tab walks the floor things, then the open tray, then the save buttons; the first thing has focus.
func wire_focus(navigation: Array[Button]) -> void:
	_navigation = navigation
	_wire_focus()
	for button in floor_buttons:
		if not button.disabled:
			button.grab_focus()
			# The first choice takes focus on arrival; the strip keeps the stop's own words.
			_say("")
			return


func _wire_focus() -> void:
	var chain: Array[Button] = []
	for button in floor_buttons:
		if is_instance_valid(button) and not button.disabled:
			chain.append(button)
	if open_group >= 0 and trays.has(open_group):
		for button in _tray_buttons(trays[open_group]):
			if not button.disabled:
				chain.append(button)
	for button in _navigation:
		if is_instance_valid(button) and not button.disabled:
			chain.append(button)
	for index in chain.size():
		chain[index].focus_next = chain[index].get_path_to(chain[(index + 1) % chain.size()])
		chain[index].focus_previous = chain[index].get_path_to(chain[(index - 1 + chain.size()) % chain.size()])


## The walking keys work here too: Up (or W) walks on by the arrow, Esc puts a thing back down.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_UP, KEY_W:
			for number in groups.size():
				var button := floor_buttons[number] if number < floor_buttons.size() else null
				if groups[number].arrow and button != null and not button.disabled and groups[number].actions.size() == 1:
					get_viewport().set_input_as_handled()
					button.pressed.emit()
					return
		KEY_ESCAPE:
			if open_group >= 0:
				get_viewport().set_input_as_handled()
				close_tray()


## A click on the bare corridor puts an opened thing back down.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and open_group >= 0:
		close_tray()
		accept_event()
