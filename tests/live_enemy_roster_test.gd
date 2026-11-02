extends SceneTree

const STARTER_ORACLE := preload("res://tests/starter_fight_oracle.gd")

var failures: Array[String] = []
var checks := 0
const SOURCE := "res://data/enemies/starter_enemies.json"
const FIXTURE := "user://live_enemy_roster_invalid.json"
const ROSTER_ART := preload("res://scripts/live_enemy_roster.gd")

class CountingMoveCatalog extends LiveMovePoseCatalog:
	var reads := 0
	func _read_manifest() -> Variant:
		reads += 1
		return super._read_manifest()
	func _art_available(_path: String) -> bool:
		return false # Exercise missing authored textures without changing any art files.

## The shipped display face every pinned actor name wears, independent of the view.
const HEADING_FONT := "res://assets/fonts/LondrinaSolid-Regular.ttf"
## Authored battle scene per admitted route kind; selection must never come from screen text.
const BACKDROP_ART := {
	"Fight": "res://assets/paper/backgrounds/battle_meadow.png",
	"Elite": "res://assets/paper/backgrounds/battle_ruins.png",
	"Boss": "res://assets/paper/backgrounds/battle_boss.png",
}
## Supplied owner art by authoritative ID; the view must never choose these by name or slot.
const IDLE_ART := {
	"warden": "res://assets/paper/heroes/warden.png",
	"seamstress": "res://assets/paper/heroes/seamstress.png",
	"tinker": "res://assets/paper/heroes/tinker.png",
	"ragling": "res://assets/paper/enemies/ragling.png",
	"ragling_guard": "res://assets/paper/enemies/ragling_guard.png",
	"fray_scavenger": "res://assets/paper/enemies/fray_scavenger.png",
	"button_guard": "res://assets/paper/enemies/button_guard.png",
	"spool_stalker": "res://assets/paper/enemies/spool_stalker.png",
	"seam_ripper": "res://assets/paper/enemies/seam_ripper.png",
	"needle_marshal": "res://assets/paper/enemies/needle_marshal.png",
	"spool_hexer": "res://assets/paper/enemies/spool_hexer.png",
	"felt_bulwark": "res://assets/paper/enemies/felt_bulwark.png",
	"moth_scribe": "res://assets/paper/enemies/moth_scribe.png",
	"pin_skitter": "res://assets/paper/enemies/pin_skitter.png",
	"thread_biter": "res://assets/paper/enemies/thread_biter.png",
	"patchwork_behemoth": "res://assets/paper/boss/patchwork_behemoth.png",
}
## The four authored M05 normals now have distinct shipped idle/attack pairs, with
## identity-specific sewn fallback for missing textures. These exact names, HP values,
## target policies and strongest weighted attacks are pinned here, never read from the view.
const M05_NORMALS := {
	"felt_bulwark": {"name": "Felt Bulwark", "max_hp": 18, "target": "front",
		"attack": {"amount": 5, "weight": 3}},
	"moth_scribe": {"name": "Moth Scribe", "max_hp": 14, "target": "exposed",
		"attack": {"amount": 5, "weight": 3}},
	"pin_skitter": {"name": "Pin Skitter", "max_hp": 13, "target": "random",
		"attack": {"amount": 5, "weight": 4}},
	"thread_biter": {"name": "Thread Biter", "max_hp": 15, "target": "lowest_living_hp",
		"attack": {"amount": 5, "weight": 3}},
}


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _input_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
		await process_frame


func _input_mouse(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
		await process_frame


## Sewn badge caption for one authoritative announcement; the three authored
## Guard alternatives (Block 5, right shove, Attack 6) all keep their own text.
func _badge_caption(action: Dictionary) -> String:
	var rank := {1: "Front", 2: "Middle", 3: "Back"}
	var target := int(action.get("target_position", 0))
	match String(action.get("type", "")):
		"attack":
			return "Hit %d: %s" % [int(action.get("amount", 0)), rank.get(target, "")]
		"block":
			return "Block +%d" % int(action.get("amount", 0))
		"shove":
			return "Shove %s %s" % [rank.get(target, ""),
				"back" if int(action.get("direction", 0)) == 1 else "forward"]
	return ""


func _snapshot(app) -> Array:	return [app.party.get_heroes(), app.deck.draw_pile.duplicate(), app.deck.hand.duplicate(),
		app.deck.discard_pile.duplicate(), app.deck.energy, app.deck.turn_active,
		app.run_rng.state, app.enemy_intents.get_intents(), app.enemies.get_enemies()]


## Every mounted puppet must show the supplied idle art of the authoritative ID currently in its
## slot, keep the paired attack resource unused, and preserve proportional placement.
func _assert_actor_art(app, presenter) -> void:
	var paths: Array[String] = []
	for puppet in presenter._puppets:
		var definition: Dictionary = app.party.get_hero(puppet.slot) if puppet.facing > 0.0 \
			else presenter.enemies.get_enemy(puppet.slot)
		var actor_id: String = definition.get("id") if definition.get("id") is String else ""
		_check(not actor_id.is_empty() and puppet.actor_id == actor_id,
			"puppet binds the authoritative actor ID in its slot, never a name or slot number")
		if actor_id.is_empty() or not IDLE_ART.has(actor_id):
			continue
		var idle_path: String = IDLE_ART[actor_id]
		var attack_path: String = idle_path.trim_suffix(".png") + "_attack.png"
		var texture: Texture2D = puppet.current_texture()
		_check(texture != null and texture.resource_path == idle_path,
			"mounted actor renders its own supplied idle image: " + actor_id)
		_check(puppet.attack_texture != null and puppet.attack_texture.resource_path == attack_path,
			"mounted actor keeps its own paired attack-pose image for committed plays")
		_check(texture != null and not paths.has(texture.resource_path),
			"actors never share another actor's image: " + actor_id)
		paths.append(texture.resource_path if texture != null else "")
		var rect: Rect2 = puppet.image_rect()
		_check(texture != null and rect.size.x > 0.0 and rect.size.y >= 40.0,
			"supplied art is readable at battle size: " + actor_id)
		_check(texture != null and is_equal_approx(rect.size.x / rect.size.y,
			float(texture.get_width()) / float(texture.get_height())),
			"supplied art keeps its own proportions: " + actor_id)
		_check(rect.position.x >= 0.0 and rect.position.y >= 0.0 \
			and rect.end.x <= puppet.size.x + 0.01 and rect.end.y <= puppet.size.y + 0.01,
			"supplied art stays inside its input-inert control: " + actor_id)
	# Resolver coverage for IDs that are not in this battle, including the distinct Guard Ragling.
	for actor_id in ["needle_marshal", "spool_hexer", "patchwork_behemoth", "ragling_guard"]:
		var resolved: Dictionary = ROSTER_ART.art_paths(actor_id)
		_check(resolved.get("idle") == IDLE_ART[actor_id]
			and resolved.get("attack") == IDLE_ART[actor_id].trim_suffix(".png") + "_attack.png",
			"authoritative ID resolver maps idle and attack paths: " + actor_id)
		var art: Dictionary = presenter.art_for(actor_id)
		_check(art.get("idle") is Texture2D and art.idle.resource_path == resolved.idle
			and art.get("attack") is Texture2D and art.attack.resource_path == resolved.attack,
			"resolved Elite/Boss art loads both poses: " + actor_id)
		# The authored Elite/Boss texture goes through the same mounting/draw geometry as a
		# starter actor: bottom on the one foot line, with its contact shadow. Presentation
		# is restored immediately, so the live battle keeps its own actor art.
		var host = presenter._puppets[0]
		var saved_id: String = host.actor_id
		var saved_idle: Texture2D = host.idle_texture
		var saved_attack: Texture2D = host.attack_texture
		host.bind_actor(actor_id, art)
		_check(host.image_rect().size.y > 0.0
			and absf(host.actor_rest_bottom() - host.foot_line()) <= 0.01
			and host.contact_shadow_rect().size.x > 0.0,
			"authored Elite/Boss art rests on the shared foot line with a contact shadow: " + actor_id)
		host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
	_check(IDLE_ART["ragling"] != IDLE_ART["ragling_guard"],
		"Guard Ragling has its own supplied image, not the base ragling")
	var fabricated := "fabricated_unknown_actor"
	_check(ROSTER_ART.art_paths(fabricated).is_empty() and presenter.art_for(fabricated).is_empty(),
		"a fabricated actor ID resolves no art and stays on the drawn fallback")
	_check(ROSTER_ART._load_art_texture("res://assets/paper/enemies/fabricated_missing.png") == null
		and ROSTER_ART._load_art_texture("") == null,
		"missing or empty art paths load no texture and cannot crash presentation")



## The five v3 IDs are presentation-only; no claim they can be admitted by the picker.
## These names are semantic silhouette parts, not palette/slot aliases.
const V3_HERO_PROPS := {
	"lantern_monk": ["round_robe", "lantern_pole", "sewn_lantern", "first_moth", "second_moth"],
	"rag_duelist": ["tattered_cape", "wide_hat_brim", "hat_feather", "needle_rapier"],
	"scarecrow": ["sack_head", "head_straw", "shoulder_crow", "pitchfork_tines"],
	"yarn_ranger": ["left_hood_ear", "right_hood_ear", "upper_bow_needle", "hip_yarn_bola"],
	"button_golem": ["broad_button_body", "upper_button", "tiny_head", "left_button_fist", "right_button_fist"],
}
const V3_HERO_TONES := {
	"lantern_monk": {"saffron": "e0a53a", "monk_plum": "6b3f6e", "monk_cream": "f1e6c8"},
	"rag_duelist": {"crimson": "b5323a", "duelist_black": "2a2326", "gold": "d7b14a"},
	"scarecrow": {"burlap": "b88f5a", "pumpkin": "d9752b", "denim": "3f5f8a"},
	"yarn_ranger": {"moss": "5d7a3a", "teal": "2f7a7a", "wool": "efe9dc"},
	"button_golem": {"walnut": "7a5236", "brass": "c49a3a", "golem_slate": "55606e"},
}


## Exercise actual mounted Puppet (no PNG prerequisite); verify canonical paths separately
## from optional loaded textures, and inject a real texture to prove image priority.
func _v3_hero_fallbacks(app, presenter) -> void:
	_check(presenter._puppets.size() >= CombatParty.PARTY_SIZE
		and app.party != null and app.deck != null and app.run_rng != null,
		"a legitimate mounted live stage has three hero actors and gameplay authorities")
	if presenter._puppets.size() < CombatParty.PARTY_SIZE:
		return
	var host = presenter._puppets[0]
	var other = presenter._puppets[1]
	var third = presenter._puppets[2]
	var saved := []
	for puppet in [host, other, third]:
		saved.append({"id": puppet.actor_id, "idle": puppet.idle_texture,
			"attack": puppet.attack_texture, "phase": puppet.idle_phase})
	var state: Array = _snapshot(app)
	var targets: Array = [host.get_global_rect(), other.get_global_rect(), third.get_global_rect()]
	var tags: Array = []
	for tag in presenter._hero_tags:
		tags.append([tag.text, tag.get_global_rect()])
	var signatures := {}
	var body_widths := {}
	for actor_id in V3_HERO_PROPS:
		var paths: Dictionary = ROSTER_ART.art_paths(actor_id)
		var prefix: String = "res://assets/paper/heroes/%s" % actor_id
		_check(paths.get("idle") == prefix + ".png"
			and paths.get("attack") == prefix + "_attack.png",
			"canonical new hero idle/attack art paths follow authoritative ID: " + actor_id)
		var loaded: Dictionary = presenter.art_for(actor_id)
		_check((loaded.get("idle") == null or loaded.get("idle") is Texture2D)
			and (loaded.get("attack") == null or loaded.get("attack") is Texture2D),
			"optional future resources remain guarded without asserting their absence: " + actor_id)
		host.bind_actor(actor_id, {})
		var shapes: Array[Dictionary] = host.fallback_silhouettes()
		var signature: Array[String] = []
		var tones := {}
		var inside := not shapes.is_empty()
		for shape in shapes:
			var name := String(shape.get("part", ""))
			var tone := String(shape.get("tone", ""))
			var points: PackedVector2Array = shape.get("points", PackedVector2Array())
			signature.append(name)
			tones[tone] = true
			inside = inside and not name.is_empty() and points.size() >= 3
			inside = inside and host.NAMED_TONES.has(tone)
			for point in points:
				inside = inside and host.FALLBACK_EXTENTS.grow(0.01).has_point(point)
			if name == "broad_button_body" or name == "round_robe" or name == "lean_coat" \
					or name == "stuffed_shirt" or name == "ranger_tunic":
				var min_x := 1000.0
				var max_x := -1000.0
				for point in points:
					min_x = minf(min_x, point.x)
					max_x = maxf(max_x, point.x)
				body_widths[actor_id] = max_x - min_x
		_check(host.actor_id == actor_id and host.fallback_kind == actor_id
			and ROSTER_ART.fallback_kind_for(actor_id) == actor_id
			and host.current_texture() == null and host.pose_texture() == null
			and not host.posed_fallback_rect().is_equal_approx(Rect2()),
			"no-texture binding draws this hero's own nonempty procedural puppet: " + actor_id)
		_check(inside, "named silhouette shapes fit exact fallback extents with valid tones: " + actor_id)
		for prop in V3_HERO_PROPS[actor_id]:
			_check(signature.has(prop), "recognisable silhouette prop " + prop + " for " + actor_id)
		for tone in V3_HERO_TONES[actor_id]:
			_check(tones.has(tone) and host.fallback_tone(tone) == Color(V3_HERO_TONES[actor_id][tone]),
				"named v3 palette shade is exact and used in geometry: " + actor_id + "/" + tone)
		signatures[actor_id] = shapes
		for alternate in [other, third]:
			alternate.bind_actor(actor_id, {})
			_check(alternate.slot != host.slot and alternate.fallback_kind == actor_id
				and alternate.fallback_silhouettes() == shapes,
				"hero identity and every semantic shape are slot-independent: " + actor_id)
	var ids := V3_HERO_PROPS.keys()
	for left in range(ids.size()):
		for right in range(left + 1, ids.size()):
			_check(signatures[ids[left]] != signatures[ids[right]],
				"five newcomer puppets have independently recognisable silhouettes")
	_check(body_widths.has("button_golem") and body_widths.size() == ids.size(),
		"all five have measurable authored torso silhouettes")
	if body_widths.size() == ids.size():
		for actor_id in ids:
			if actor_id != "button_golem":
				_check(body_widths["button_golem"] > body_widths[actor_id],
					"button golem is visibly the broadest torso versus " + actor_id)
	# A synthetic legitimate Texture2D wins over the procedurally drawn silhouette.
	var image := Image.create(12, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var injected: ImageTexture = ImageTexture.create_from_image(image)
	host.bind_actor("lantern_monk", {"idle": injected, "attack": injected})
	_check(host.current_texture() == injected and host.pose_texture() == injected
		and host.posed_image_rect().has_area() and host.image_rect().has_area(),
		"provided Texture2D overrides the hero fallback on the live stage")
	# An authored idle loop strip is cut into square frames and only replaces the still at rest.
	var loop_art: Dictionary = presenter.art_for("seamstress")
	var strip := loop_art.get("idle_loop") as Texture2D
	_check(strip != null and strip.get_width() == strip.get_height() * 13
		and ROSTER_ART.art_paths("seamstress").get("idle_loop") == "res://assets/paper/heroes/seamstress_idle.png",
		"the Seamstress idle loop strip resolves by authoritative ID as thirteen square frames")
	host.bind_actor("seamstress", loop_art)
	host.idle_phase = 0.0
	var first_frame: Texture2D = host.idle_frame(host.pose_texture())
	host.idle_phase = 0.25
	var later_frame: Texture2D = host.idle_frame(host.pose_texture())
	_check(host.idle_frames.size() == 13 and host.current_texture() == loop_art.idle
		and host.pose_texture() == loop_art.idle and first_frame is AtlasTexture
		and later_frame is AtlasTexture and first_frame != later_frame,
		"a standing hero paints its idle loop while placement still uses the still image")
	_check(loop_art.get("attack") is Texture2D,
		"the dark Seamstress has an authored held attack pose")
	_check(host.idle_frame(loop_art.attack) == loop_art.attack,
		"the committed attack pose is never replaced by a loop frame")
	# Even a valid optional swing strip cannot override the authored attack still.
	_check(ROSTER_ART.art_paths("seamstress").get("attack_loop") == "res://assets/paper/heroes/seamstress_attack_anim.png",
		"the attack swing strip path follows the authoritative ID")
	var swing_image := Image.create(40, 8, false, Image.FORMAT_RGBA8)
	var swing: ImageTexture = ImageTexture.create_from_image(swing_image)
	host.bind_actor("seamstress", {"idle": loop_art.idle, "attack": loop_art.attack,
		"idle_loop": strip, "attack_loop": swing})
	_check(host.attack_frames.size() == 5 and host.idle_frame(loop_art.attack) == loop_art.attack,
		"five-frame swing fixture is valid and the resting attack still is available")
	_check(host.trigger_attack(0.4), "mounted Seamstress accepts the bounded attack")
	for remaining in [0.4, 0.2, 0.0001]:
		host.attack_remaining = remaining
		_check(host.attacking() and host.pose_texture() == loop_art.attack
			and host.idle_frame(host.pose_texture()) == loop_art.attack,
			"Seamstress holds the authored still at attack start, peak and near completion")
	host.cancel_attack()
	host.bind_actor("seamstress", loop_art)
	var still_rect: Rect2 = host.image_rect()
	var painted: Rect2 = host.painted_rect(later_frame, loop_art.idle, still_rect)
	_check(is_equal_approx(painted.end.y, still_rect.end.y)
		and is_equal_approx(painted.size.y / later_frame.get_height(), still_rect.size.y / loop_art.idle.get_height()),
		"loop frames stand on the still's foot line at the still's pixel scale")
	host.bind_actor("fabricated_v3_hero", {})
	_check(host.fallback_kind == host.FALLBACK_KIND_GENERIC
		and host.fallback_silhouettes().is_empty() and host.current_texture() == null
		and ROSTER_ART.art_paths("fabricated_v3_hero").is_empty(),
		"unrecognized actor IDs fail closed to the generic fallback, not a v3 hero")
	for index in range(3):
		var puppet = [host, other, third][index]
		puppet.bind_actor(saved[index].id,
			{"idle": saved[index].idle, "attack": saved[index].attack})
		puppet.idle_phase = saved[index].phase
		_check(puppet.actor_id == app.party.get_hero(puppet.slot).get("id"),
			"restored live Puppet exactly follows original authoritative party ID")
	var after_tags := []
	for tag in presenter._hero_tags:
		after_tags.append([tag.text, tag.get_global_rect()])
	_check(_snapshot(app) == state and after_tags == tags
		and [host.get_global_rect(), other.get_global_rect(), third.get_global_rect()] == targets,
		"all v3 presentation-only art checks leave combat, RNG, tags and targets untouched")


## Black or oversized optional strips may never cover a transparent mounted hero.
## Prove the authored resources are present before exercising the synthetic cases.
func _idle_strip_safety(app, presenter) -> void:
	var warden = presenter.hero_puppet("warden")
	var tinker = presenter.hero_puppet("tinker")
	var seamstress = presenter.hero_puppet("seamstress")
	_check(warden != null and tinker != null and seamstress != null
		and app.party != null and app.deck != null and app.run_rng != null,
		"all three authoritative heroes and gameplay services exist on the real battle stage")
	if warden == null or tinker == null or seamstress == null:
		return
	var before: Array = _snapshot(app)
	var original: Dictionary = presenter.art_for("warden")
	var original_phase: float = warden.idle_phase
	var actor_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		actor_rects.append(puppet.get_global_rect())
	var tag_views: Array = []
	for label in presenter._hero_tags + presenter._labels:
		tag_views.append([label.text, label.get_global_rect()])
	var badge_views: Array = []
	for badge in presenter._badges:
		badge_views.append([badge.readable_text, badge.get_global_rect()])
	var input_rects := [app.hand_view.get_global_rect(), app.end_turn_button.get_global_rect(),
		app.return_button.get_global_rect(), presenter.panel.get_global_rect()]
	for hero in [warden, tinker]:
		var art: Dictionary = presenter.art_for(hero.actor_id)
		var still := art.get("idle") as Texture2D
		var strip := art.get("idle_loop") as Texture2D
		_check(still != null and strip != null and still.get_image() != null
			and strip.get_image() != null
			and ROSTER_ART.Puppet._clear_cell_margin(still.get_image(), 0,
				still.get_width(), still.get_height())
			and strip.get_width() <= ROSTER_ART.Puppet.LOOP_ATLAS_MAX_WIDTH,
			"the imported transparent Warden/Tinker still and Web-safe strip actually exist: " + hero.actor_id)
		_check(hero.current_texture() == still and not hero.idle_frames.is_empty()
			and hero.idle_frame(hero.pose_texture()) is AtlasTexture and hero.posed_image_rect().has_area(),
			"the mounted Warden/Tinker play their Web-safe idle strip: " + hero.actor_id)
	var seam_art: Dictionary = presenter.art_for("seamstress")
	_check(seam_art.get("idle") is Texture2D and seam_art.get("idle_loop") is Texture2D
		and seamstress.idle_frames.size() == 13
		and seamstress.idle_frame(seamstress.pose_texture()) is AtlasTexture,
		"the real mounted Seamstress retains all thirteen transparent idle frames")
	var still_image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	still_image.fill(Color.TRANSPARENT)
	still_image.fill_rect(Rect2i(5, 3, 6, 12), Color("b38e6f"))
	var still := ImageTexture.create_from_image(still_image)
	var black_image := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	black_image.fill(Color.BLACK)
	black_image.set_pixel(7, 7, Color.WHITE)
	var black_strip := ImageTexture.create_from_image(black_image)
	warden.bind_actor("warden", {"idle": still, "attack": still, "idle_loop": black_strip})
	_check(warden.idle_frames.is_empty() and warden.current_texture() == still
		and warden.idle_frame(warden.pose_texture()) == still
		and warden.posed_image_rect().has_area(),
		"opaque-black square-cell strip fails closed to the loaded still, not a drawn fallback")
	var mixed_image := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	mixed_image.fill(Color.TRANSPARENT)
	mixed_image.fill_rect(Rect2i(16, 0, 16, 16), Color.BLACK)
	var mixed_strip := ImageTexture.create_from_image(mixed_image)
	warden.bind_actor("warden", {"idle": still, "idle_loop": mixed_strip})
	_check(warden.idle_frames.is_empty() and warden.idle_frame(still) == still,
		"one opaque-black frame rejects the whole optional strip, including its good cells")
	var malformed_image := Image.create(35, 16, false, Image.FORMAT_RGBA8)
	malformed_image.fill(Color.TRANSPARENT)
	warden.bind_actor("warden", {"idle": still,
		"idle_loop": ImageTexture.create_from_image(malformed_image)})
	_check(warden.idle_frames.is_empty() and warden.idle_frame(still) == still,
		"non-square-cell art also fails closed to the still")
	var clear_image := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	clear_image.fill(Color.TRANSPARENT)
	for index in range(3):
		clear_image.fill_rect(Rect2i(index * 16 + 5, 3, 6, 12),
			Color(0.3 + index * 0.2, 0.4, 0.6, 1.0))
	var clear_strip := ImageTexture.create_from_image(clear_image)
	warden.bind_actor("warden", {"idle": still, "attack": still,
		"idle_loop": clear_strip, "attack_loop": clear_strip})
	warden.idle_phase = 0.0
	var first: Texture2D = warden.idle_frame(warden.pose_texture())
	warden._process(0.1)
	var later: Texture2D = warden.idle_frame(warden.pose_texture())
	_check(warden.idle_frames.size() == 3 and first is AtlasTexture
		and later is AtlasTexture and first != later and warden.current_texture() == still,
		"valid transparent synthetic strip advances through painted idle frames on live delta")
	_check(warden.attack_frames.size() == 3 and warden.trigger_attack(0.4),
		"valid three-frame swing fixture accompanies an accepted mounted attack")
	for remaining in [0.4, 0.2, 0.0001]:
		warden.attack_remaining = remaining
		_check(warden.attacking() and warden.pose_texture() == still
			and warden.idle_frame(warden.pose_texture()) == still,
			"Warden holds the authored still even when idle and attack textures are identical")
	warden.cancel_attack()
	# Synthetic wide and tall poses preserve source-pixel scale, rather than fitting
	# themselves into the idle rectangle. All surrounding mounted bounds are checked below.
	for dimensions in [Vector2i(48, 16), Vector2i(16, 32)]:
		var pose_image := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
		var pose := ImageTexture.create_from_image(pose_image)
		warden.bind_actor("warden", {"idle": still, "attack": pose, "attack_loop": clear_strip})
		var idle_rect: Rect2 = warden.image_rect()
		_check(idle_rect.has_area() and warden.trigger_attack(0.4),
			"synthetic proportion witness has fitted idle art and an accepted attack")
		for remaining in [0.4, 0.2, 0.0001]:
			warden.attack_remaining = remaining
			var pose_rect: Rect2 = warden.pose_rect(warden.pose_texture())
			_check(warden.idle_frame(warden.pose_texture()) == pose
				and is_equal_approx(pose_rect.size.x / idle_rect.size.x, dimensions.x / 16.0)
				and is_equal_approx(pose_rect.size.y / idle_rect.size.y, dimensions.y / 16.0)
				and is_equal_approx(pose_rect.get_center().x, idle_rect.get_center().x)
				and is_equal_approx(pose_rect.end.y, idle_rect.end.y),
				"wide/tall attack holds idle pixel scale, aspect ratio and bottom-centred foot line")
		warden.cancel_attack()
	warden.bind_actor("warden", {"idle": still, "attack": still, "idle_loop": clear_strip})
	warden.fallen = true
	_check(warden.idle_frame(warden.pose_texture()) == still,
		"KO skips idle animation and preserves the fallen still pose")
	warden.fallen = false
	warden.bind_actor("warden", {"idle_loop": clear_strip})
	_check(warden.current_texture() == null and warden.idle_frames.is_empty()
		and warden.posed_fallback_rect().has_area(),
		"missing still prevents optional animation and retains the generic drawn fallback")
	warden.bind_actor("warden", original)
	warden.idle_phase = original_phase
	_check(warden.current_texture() == original.get("idle") and not warden.idle_frames.is_empty()
		and warden.actor_id == "warden", "live Warden binding restores its own valid still")
	var restored_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		restored_rects.append(puppet.get_global_rect())
	var restored_tags: Array = []
	for label in presenter._hero_tags + presenter._labels:
		restored_tags.append([label.text, label.get_global_rect()])
	var restored_badges: Array = []
	for badge in presenter._badges:
		restored_badges.append([badge.readable_text, badge.get_global_rect()])
	_check(_snapshot(app) == before and restored_rects == actor_rects
		and restored_tags == tag_views and restored_badges == badge_views
		and input_rects == [app.hand_view.get_global_rect(),
			app.end_turn_button.get_global_rect(), app.return_button.get_global_rect(),
			presenter.panel.get_global_rect()],
		"unsafe and valid frame checks never move hit targets, tags, inputs or seeded gameplay")


## The source of one indented Puppet method, up to the next method, for draw-path inspection.
func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var body := source.substr(start)
	return body.left(body.find("\n\tfunc "))


## The source of one top-level script method, up to the next method, for draw-path checks.
func _method_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var body := source.substr(start)
	return body.left(body.find("\nfunc "))


## The routed Fight stage advances by the admitted node's own integer floor: meadow 1-3,
## woods 4-6, marsh 7-9, peaks 10-11. A standalone battle (no map, no floor) keeps the
## meadow, while an invalid floor or missing file keeps the drawn quilt.
func _fight_areas(app, presenter, backdrop) -> void:
	var expected := {
		"Meadow": "res://assets/paper/backgrounds/battle_meadow.png",
		"Woods": "res://assets/paper/backgrounds/battle_woods.png",
		"Marsh": "res://assets/paper/backgrounds/battle_marsh.png",
		"Peaks": "res://assets/paper/backgrounds/battle_peaks.png",
	}
	var bands := [["Meadow", 1, 3], ["Woods", 4, 6], ["Marsh", 7, 9], ["Peaks", 10, 11]]
	var installed: Dictionary = {}
	for band in bands:
		var area_name: String = band[0]
		for floor_number in range(int(band[1]), int(band[2]) + 1):
			_check(ROSTER_ART.fight_area_name(floor_number) == area_name
				and ROSTER_ART.fight_backdrop_path(floor_number) == expected[area_name]
				and ROSTER_ART.stage_backdrop_path("Fight", floor_number) == expected[area_name],
				"routed Fight floor %d selects the %s area" % [floor_number, area_name])
		_check(ResourceLoader.exists(expected[area_name]),
			"the committed %s landscape really loads" % area_name)
		var loaded: Texture2D = presenter.stage_texture(expected[area_name])
		_check(loaded != null and loaded.resource_path == expected[area_name]
			and not installed.has(loaded.resource_path),
			"the %s area loads its own distinct committed texture" % area_name)
		installed[expected[area_name]] = true
	_check(installed.size() == expected.size(), "all four authored landscapes are distinct")
	# Standalone: no run map and no floor, so the normal meadow stage stays.
	_check(ROSTER_ART.stage_backdrop_path("Fight", ROSTER_ART.STANDALONE_FLOOR) == expected["Meadow"]
		and app.run_map == null and backdrop.battle_kind == "Fight"
		and backdrop.stage_texture.resource_path == expected["Meadow"],
		"a standalone battle keeps the meadow without any run map")
	# Invalid or absent data selects nothing and keeps the quilt, never another area.
	for floor_number in [ROSTER_ART.INVALID_FLOOR, 12, 13, 99]:
		_check(ROSTER_ART.fight_area_name(floor_number) == ""
			and ROSTER_ART.fight_backdrop_path(floor_number) == ""
			and ROSTER_ART.stage_backdrop_path("Fight", floor_number) == "",
			"floor %d has no Fight area and keeps the quilt" % floor_number)
	_check(ROSTER_ART.stage_backdrop_path("Fight", ROSTER_ART.INVALID_FLOOR) == ""
		and presenter.stage_texture(ROSTER_ART.fight_backdrop_path(ROSTER_ART.INVALID_FLOOR)) == null
		and presenter.stage_texture("res://assets/paper/backgrounds/fabricated_missing_area.png") == null
		and presenter.stage_texture("") == null,
		"invalid floors and missing area files load nothing and cannot crash")
	# Kind identity is retained: Elite and Boss keep their own scenes on every floor.
	for kind in ["Elite", "Boss"]:
		for floor_number in [1, 5, 8, 11, 12]:
			_check(ROSTER_ART.stage_backdrop_path(kind, floor_number) == BACKDROP_ART[kind],
				kind + " keeps its own scene on floor %d" % floor_number)
	# A new Fight on another floor is a new stage selection, not the same kind.
	_check(ROSTER_ART.stage_key("Fight", 1) != ROSTER_ART.stage_key("Fight", 4)
		and ROSTER_ART.stage_key("Fight", 4) != ROSTER_ART.stage_key("Fight", 7)
		and ROSTER_ART.stage_key("Fight", 7) != ROSTER_ART.stage_key("Fight", 10)
		and ROSTER_ART.stage_key("Fight", 10) == ROSTER_ART.stage_key("Fight", 10)
		and ROSTER_ART.stage_key("Elite", 5) != ROSTER_ART.stage_key("Fight", 5),
		"the stage selection key carries the area floor, not only the kind")


## Grounding: whichever artwork an actor draws rests its bottom edge on one shared foot
## line above the pinned tag, with a fixed soft contact shadow and a dark rim drawn behind
## it. Both are draw calls inside the input-inert puppet, so names, target rectangles and
## intent badges keep working and no combat model or RNG is touched.
func _staging(app, presenter) -> void:
	_check(is_instance_valid(presenter.backdrop) and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"staging assertions run on every actual mounted actor")
	if not is_instance_valid(presenter.backdrop) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var shadow_body := _function_body(source, "func _draw_contact_shadow(")
	var rim_body := _function_body(source, "func _draw_silhouette(")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(shadow_body.contains("contact_shadow_rect()") and shadow_body.contains("oval_points(")
		and shadow_body.contains("draw_colored_polygon("),
		"source draws the contact shadow as soft ovals from its fixed rest-pose rectangle")
	_check(rim_body.contains("idle_transform(") and rim_body.contains("RIM_INK")
		and rim_body.contains("draw_texture_rect(") and rim_body.contains("_draw_fallback_shapes(true)"),
		"source draws one dark rim copy behind both supplied art and the drawn fallback")
	_check(not shadow_body.contains("add_child") and not rim_body.contains("add_child")
		and not shadow_body.contains("Control.new") and not rim_body.contains("Control.new"),
		"the shadow and rim are drawn, never mounted as extra controls")
	_check(puppet_draw.find("_draw_contact_shadow()") >= 0
		and puppet_draw.find("_draw_silhouette()") >= 0
		and puppet_draw.find("_draw_actor(") >= 0
		and puppet_draw.find("_draw_fallback()") >= 0
		and puppet_draw.find("_draw_tag()") >= 0
		and puppet_draw.find("_draw_contact_shadow()") < puppet_draw.find("_draw_silhouette()")
		and puppet_draw.find("_draw_silhouette()") < puppet_draw.find("_draw_actor(")
		and puppet_draw.find("_draw_silhouette()") < puppet_draw.find("_draw_fallback()")
		and puppet_draw.find("_draw_actor(") < puppet_draw.find("_draw_tag()")
		and puppet_draw.find("_draw_fallback()") < puppet_draw.find("_draw_tag()"),
		"source draw order is contact shadow, dark rim, actor artwork, then the pinned tag")
	var screen_feet: Array[float] = []
	for puppet in presenter._puppets:
		var band: Rect2 = puppet.art_band()
		var tag_band: Rect2 = puppet.tag_band()
		_check(band.size.y > 0.0 and tag_band.size.y > 0.0
			and puppet.foot_line() > band.position.y
			and puppet.foot_line() < band.end.y + 0.01
			and tag_band.position.y >= band.end.y - 0.01,
			"the shared foot line sits above the pinned name/HP tag inside the art band: " + puppet.name)
		_check(puppet.art_inset() >= puppet.IDLE_BOB_PIXELS
			and is_equal_approx(puppet.foot_line(), band.end.y - puppet.art_inset()),
			"the foot line keeps the bob/breathing safety inset clear of the tag band: " + puppet.name)
		_check(absf(puppet.actor_rest_bottom() - puppet.foot_line()) <= 0.01,
			"whichever artwork is bound, its bottom edge rests on the foot line: " + puppet.name)
		screen_feet.append(puppet.get_global_rect().position.y + puppet.actor_rest_bottom())
		var shadow: Rect2 = puppet.contact_shadow_rect()
		_check(shadow.size.x > 0.0 and shadow.size.y > 0.0
			and band.grow(0.01).encloses(shadow)
			and is_equal_approx(shadow.get_center().x, puppet.size.x * 0.5)
			and not shadow.intersects(puppet.tag_band().grow(-0.01)),
			"each actor has one soft oval contact shadow on its foot line, clear of its tag: " + puppet.name)
		puppet.idle_phase = 0.0
		var rest_shadow := shadow
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		puppet._process(0.37)
		puppet._process(0.41)
		_check(puppet.contact_shadow_rect() == rest_shadow,
			"the contact shadow stays exactly still while the artwork breathes and bobs: " + puppet.name)
		_check(rest_pose.size.y > 0.0 and puppet.posed_actor_rect() != rest_pose,
			"real frame deltas still move the grounded artwork: " + puppet.name)
		puppet.idle_phase = 0.0
	var first: float = screen_feet[0]
	var spread := 0.0
	for value in screen_feet:
		spread = maxf(spread, absf(value - first))
	_check(spread <= 0.51,
		"every mounted hero and enemy stands on the same 1280x720 screen foot line")
	var hem: Rect2 = presenter.backdrop.hem_rect()
	var hem_global_y: float = presenter.backdrop.get_global_rect().position.y + hem.position.y
	_check(hem.size.y > 0.0 and hem_global_y > first
		and hem_global_y - first <= presenter.STAGE_TAG_HEIGHT + 16.0,
		"that common foot line is just above the stitched quilt hem, under the pinned tags")
	_check(_snapshot(app) == before,
		"grounding, contact shadow and rim reads change no combat state or RNG")


## VIS V5 attack pose: each living mounted actor owns one short, bounded lunge in its own
## facing direction with its authored `_attack` image when that image exists (the same
## idle art or the drawn puppet when it does not), then returns exactly to idle. The pose
## lives only in the drawn transform, so target rectangles, pinned names, intent badges,
## the hand and the action row stay put and no HP, deck, energy, turn, intent or RNG value
## moves. A fallen actor and a detached puppet never start one.
func _stage_focus(app, presenter) -> void:
	var stage = presenter.backdrop
	var hero: Control
	var enemy: Control
	for actor in presenter._puppets:
		if not actor.fallen and actor.is_visible_in_tree():
			if actor.facing > 0.0:
				hero = actor
			else:
				enemy = actor
	_check(is_instance_valid(stage) and is_instance_valid(hero) and is_instance_valid(enemy),
		"focus lifecycle uses real standing mounted puppets")
	if not is_instance_valid(stage) or not is_instance_valid(hero) or not is_instance_valid(enemy):
		return
	var state := _snapshot(app)
	var serial: int = stage.focus_serial
	_check(not presenter.focus_hit("missing", enemy.actor_id, false)
		and stage.focus_zoom() == 1.0 and stage.focus_serial == serial,
		"unbound attacker cannot create a focus")
	_check(not presenter.focus_hit(hero.actor_id, "missing", false)
		and stage.focus_serial == serial, "unbound target cannot create a focus")
	_check(presenter.focus_hit(hero.actor_id, enemy.actor_id, true), "real anchors admit a fast focus")
	stage.advance_focus(0.15 * 0.15 / 0.85)
	_check(is_equal_approx(stage.focus_zoom(), 1.30), "fast focus reaches the same authored zoom")
	stage.advance_focus(0.15 * 0.50 / 0.85)
	_check(is_equal_approx(stage.focus_zoom(), 1.30), "fast focus retains the compressed hold")
	stage.advance_focus(0.15 * 0.20 / 0.85)
	_check(stage.focus_zoom() == 1.0 and stage.focus_transform() == Transform2D.IDENTITY,
		"fast focus ends exactly within 0.15 seconds")
	_check(presenter.focus_hit(hero.actor_id, enemy.actor_id, false), "missing-anchor test starts a real focus")
	enemy.hide()
	stage.advance_focus(0.0)
	_check(stage.focus_zoom() == 1.0 and stage.focus_anchors.is_empty(),
		"a disappearing anchor immediately retires the visual focus")
	enemy.show()
	_check(presenter.focus_hit(hero.actor_id, enemy.actor_id, false), "rebind test starts a real focus")
	var identity: String = enemy.actor_id
	enemy.actor_id = "rebound"
	stage.advance_focus(0.0)
	_check(stage.focus_zoom() == 1.0, "an actor identity replacement cannot retain focus")
	enemy.actor_id = identity
	_check(presenter.focus_hit(hero.actor_id, enemy.actor_id, false), "teardown test starts a real focus")
	presenter.cancel_poses()
	_check(stage.focus_transform() == Transform2D.IDENTITY and stage.focus_anchors.is_empty(),
		"teardown cancels focus exactly")
	_check(presenter.focus_hit(hero.actor_id, enemy.actor_id, false), "motion-setting test starts a real focus")
	var previous: Variant = ProjectSettings.get_setting("accessibility/reduced_motion", false)
	ProjectSettings.set_setting("accessibility/reduced_motion", true)
	stage.advance_focus(0.0)
	_check(stage.focus_zoom() == 1.0 and stage.focus_anchors.is_empty(),
		"enabling reduced motion immediately cancels an active focus")
	ProjectSettings.set_setting("accessibility/reduced_motion", previous)
	_check(_snapshot(app) == state, "focus lifecycle never changes authoritative state or seeded RNG")


func _attack_pose(app, presenter) -> void:
	_stage_focus(app, presenter)
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"attack-pose checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var puppet_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		puppet_rects.append(puppet.get_global_rect())
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	var control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var living: Array = []
	for puppet in presenter._puppets:
		if not puppet.fallen:
			living.append(puppet)
	_check(not living.is_empty(), "the live battle mounts at least one standing actor")
	for puppet in living:
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_shape(), 0.0)
			and is_equal_approx(puppet.attack_lunge(), 0.0)
			and puppet.pose_texture() == puppet.current_texture(),
			"a standing actor starts at plain idle before any committed hit: " + puppet.name)
		_check(not puppet.trigger_attack(0.0) and not puppet.trigger_attack(-0.5)
			and not puppet.attacking(), "a zero or negative pose span never starts a lunge: " + puppet.name)
		_check(puppet.trigger_attack(30.0) and puppet.attacking()
			and puppet.attack_span <= puppet.ATTACK_MAX_SECONDS,
			"one committed pose is bounded to the approved span: " + puppet.name)
		puppet.cancel_attack()
		_check(not puppet.attacking() and puppet.pose_texture() == puppet.current_texture()
			and puppet.posed_actor_rect() == (puppet.posed_image_rect()
				if puppet.current_texture() != null else puppet.posed_fallback_rect()),
			"cancelling the pose returns the actor exactly to its idle drawing: " + puppet.name)
		var phase: float = puppet.idle_phase
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		var idle_texture: Texture2D = puppet.current_texture()
		var attack_texture: Texture2D = puppet.attack_texture
		_check(puppet.trigger_attack(0.6) and puppet.attacking(),
			"a committed hit starts exactly one attack pose: " + puppet.name)
		if attack_texture != null:
			_check(puppet.pose_texture() == attack_texture
				and puppet.pose_texture().resource_path == idle_texture.resource_path.trim_suffix(".png") + "_attack.png",
				"the pose draws this actor's own authored attack image: " + puppet.name)
		else:
			_check(puppet.pose_texture() == idle_texture,
				"an actor without attack art keeps its idle drawing during the pose: " + puppet.name)
		puppet._process(puppet.attack_span * 0.5)
		var peak: Rect2 = puppet.posed_actor_rect()
		var pose: Transform2D = puppet.idle_transform(Vector2.ZERO, 1.0)
		_check(puppet.attacking() and is_equal_approx(puppet.attack_shape(), 1.0)
			and puppet.attack_lunge() * puppet.facing >= 4.0,
			"the pose lunges toward the other lineup in this actor's own facing: " + puppet.name)
		_check(is_equal_approx(pose.x.x, puppet.facing * puppet.attack_stretch())
			and is_equal_approx(pose.y.y, puppet.idle_breath() * puppet.attack_squash())
			and puppet.attack_stretch() > 1.0 and puppet.attack_squash() < 1.0,
			"the drawn pose adds paper stretch and squash to the lunge: " + puppet.name)
		_check((peak.get_center().x - rest_pose.get_center().x) * puppet.facing
			>= absf(puppet.attack_lunge()) - 0.01,
			"the lunge moves only the drawn artwork, not the actor control: " + puppet.name)
		_check(puppet.get_global_rect() == puppet_rects[presenter._puppets.find(puppet)],
			"the complete actor target rectangle never moves during a pose: " + puppet.name)
		puppet._process(puppet.ATTACK_MAX_SECONDS)
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_span, 0.0)
			and puppet.pose_texture() == idle_texture,
			"the pose ends by itself within 0.6 s and returns to idle art: " + puppet.name)
		puppet.idle_phase = phase
		_check(puppet.posed_actor_rect() == rest_pose,
			"after the pose the actor stands exactly where it did before: " + puppet.name)
		puppet._process(0.1)
		_check(not puppet.attacking() and is_equal_approx(puppet.attack_shape(), 0.0),
			"a settled pose never replays on later frames: " + puppet.name)
		puppet.idle_phase = phase
	# An actor whose authored attack image is missing keeps its supplied idle art and
	# still performs the same bounded lunge.
	var host = living[0]
	var saved_attack: Texture2D = host.attack_texture
	var host_phase: float = host.idle_phase
	host.attack_texture = null
	var host_rest: Rect2 = host.posed_actor_rect()
	_check(host.trigger_attack(0.6) and host.pose_texture() == host.current_texture(),
		"a supplied actor missing only its attack image poses with its idle art")
	host._process(host.attack_span * 0.5)
	_check(host.posed_actor_rect() != host_rest and host.attack_lunge() * host.facing >= 4.0,
		"the missing-attack-image pose still lunges the drawn artwork")
	host.cancel_attack()
	host.attack_texture = saved_attack
	host.idle_phase = host_phase
	# The drawn puppet (no supplied art at all) owns the same pose.
	var saved_id: String = host.actor_id
	var saved_idle: Texture2D = host.idle_texture
	host.bind_actor("fabricated_pose_actor", {})
	var drawn_rest: Rect2 = host.posed_fallback_rect()
	_check(host.current_texture() == null and host.pose_texture() == null
		and host.trigger_attack(0.6) and host.attacking(),
		"an actor with no supplied art at all still performs the drawn attack pose")
	host._process(host.attack_span * 0.5)
	_check(host.posed_fallback_rect() != drawn_rest and host.attack_lunge() * host.facing >= 4.0,
		"the drawn fallback puppet lunges exactly like a supplied image")
	host.cancel_attack()
	host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
	host.idle_phase = host_phase
	# Source inspection: the realistic pose is real draw work, with no tween, timer or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var pose_body := _function_body(source, "func trigger_attack(")
	var advance_body := _function_body(source, "func advance_attack(")
	var actor_body := _function_body(source, "func _draw_actor(")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(pose_body.contains("attack_span = clampf(") and pose_body.contains("ATTACK_MAX_SECONDS")
		and pose_body.contains("if fallen")
		and advance_body.contains("attack_remaining = maxf(") and advance_body.contains("cancel_attack()")
		and not pose_body.contains("create_tween") and not advance_body.contains("create_tween")
		and not pose_body.contains("Timer.new") and not advance_body.contains("Timer.new")
		and not pose_body.contains("randi(") and not advance_body.contains("randf("),
		"the pose is a bounded delta-driven state, never a tween, timer or RNG draw")
	_check(puppet_draw.contains("pose_texture()") and actor_body.contains("pose_rect(")
		and actor_body.contains("idle_transform(")
		and actor_body.find("idle_transform(") < actor_body.find("draw_texture_rect("),
		"the actor draw path uses the pose image and the one shared pose transform")
	# Every mounted control keeps its exact place, caption and target.
	var after_puppets: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_puppets.append(puppet.get_global_rect())
	_check(after_puppets == puppet_rects,
		"no actor target rectangle moves during any pose")
	var after_tags: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tags.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tags.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tags == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text during poses")
	var after_badges: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badges.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badges == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption during poses")
	var after_controls: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_controls.append(control.get_global_rect())
	_check(after_controls == control_rects,
		"hand, actions and the enemy roster panel stay put during poses")
	_check(_snapshot(app) == before,
		"a committed attack pose changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the attack pose creates no tween that outlives the frame")

## Committed-hit recoil: one short, bounded, damped horizontal wobble of the drawn artwork
## only. It combines with a committed lunge, works for missing art, settles exactly back to
## idle, cancels on a rebind or a fall, and never moves a target, a pinned name, an intent
## badge or an action control.
func _recoil(app, presenter) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"recoil checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var puppet_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		puppet_rects.append(puppet.get_global_rect())
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	var control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var standing: Array = []
	for puppet in presenter._puppets:
		if not puppet.fallen:
			standing.append(puppet)
	_check(not standing.is_empty(), "the live battle mounts at least one standing actor for recoil")
	for puppet in standing:
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_shape(), 0.0)
			and is_equal_approx(puppet.recoil_pixels(), 0.0),
			"a standing actor starts at rest with no recoil: " + puppet.name)
		_check(not puppet.trigger_recoil(0.0) and not puppet.trigger_recoil(-0.5)
			and not puppet.recoiling(),
			"a zero or negative recoil span never starts a shake: " + puppet.name)
		_check(puppet.trigger_recoil(30.0) and puppet.recoiling()
			and puppet.recoil_span <= puppet.RECOIL_MAX_SECONDS,
			"one committed HP loss starts a recoil bounded to the approved span: " + puppet.name)
		puppet.cancel_recoil()
		var phase: float = puppet.idle_phase
		var rest_pose: Rect2 = puppet.posed_actor_rect()
		var idle_texture: Texture2D = puppet.current_texture()
		_check(not puppet.recoiling() and puppet.posed_actor_rect() == rest_pose,
			"cancelling a recoil returns the actor exactly to its idle drawing: " + puppet.name)
		_check(puppet.trigger_recoil(0.6) and puppet.recoiling() and not puppet.attacking(),
			"a committed HP loss starts exactly one recoil: " + puppet.name)
		puppet._process(puppet.recoil_span * 0.25)
		var peak: Rect2 = puppet.posed_actor_rect()
		var expected: float = -puppet.facing * puppet.recoil_back_pixels() * 0.75
		_check(puppet.recoiling() and absf(puppet.recoil_pixels() - expected) <= 0.01
			and absf(puppet.recoil_pixels()) >= 1.5,
			"the recoil shoves the drawn artwork by its own bounded amplitude: " + puppet.name)
		_check(absf(peak.get_center().x - rest_pose.get_center().x) >= 1.5
			and (peak.get_center().x - rest_pose.get_center().x) * puppet.facing < 0.0,
			"the recoil is kicked away from this actor's own facing: " + puppet.name)
		_check(puppet.pose_texture() == idle_texture,
			"a recoil alone draws the actor's own idle artwork: " + puppet.name)
		_check(puppet.get_global_rect() == puppet_rects[presenter._puppets.find(puppet)],
			"the complete actor target rectangle never moves during a recoil: " + puppet.name)
		# It combines with a committed lunge instead of replacing or cancelling it.
		_check(puppet.trigger_attack(0.6) and puppet.attacking() and puppet.recoiling(),
			"a recoil can overlap an active committed lunge: " + puppet.name)
		puppet._process(puppet.ATTACK_MAX_SECONDS / 2.0)
		var combined: Transform2D = puppet.idle_transform(Vector2.ZERO, 1.0)
		_check(puppet.attacking() and puppet.recoiling()
			and is_equal_approx(combined.origin.x, puppet.attack_lunge() + puppet.recoil_pixels())
			and absf(puppet.attack_lunge()) >= 1.0 and absf(puppet.recoil_pixels()) >= 0.5,
			"the shared drawing transform carries the lunge and the recoil together: " + puppet.name)
		puppet._process(puppet.RECOIL_MAX_SECONDS)
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_span, 0.0)
			and is_equal_approx(puppet.recoil_pixels(), 0.0),
			"the recoil ends by itself within 0.6 s: " + puppet.name)
		puppet.cancel_attack()
		puppet.idle_phase = phase
		_check(puppet.posed_actor_rect() == rest_pose,
			"a settled recoil puts the artwork back exactly where it rested: " + puppet.name)
		puppet._process(0.1)
		_check(not puppet.recoiling() and is_equal_approx(puppet.recoil_shape(), 0.0),
			"a settled recoil never replays on later frames: " + puppet.name)
		puppet.idle_phase = phase
	# The drawn fallback (no supplied art at all) recoils exactly like supplied art.
	var host = standing[0]
	var host_phase: float = host.idle_phase
	var saved_id: String = host.actor_id
	var saved_idle: Texture2D = host.idle_texture
	var saved_attack: Texture2D = host.attack_texture
	host.bind_actor("fabricated_recoil_actor", {})
	_check(host.current_texture() == null and not host.recoiling(),
		"an actor without supplied art starts settled and unshaken")
	var drawn_rest: Rect2 = host.posed_fallback_rect()
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"an actor with no supplied art at all still performs the drawn recoil")
	host._process(host.recoil_span * 0.25)
	var drawn_peak: Rect2 = host.posed_fallback_rect()
	_check(drawn_peak != drawn_rest and absf(drawn_peak.get_center().x - drawn_rest.get_center().x) >= 1.5
		and (drawn_peak.get_center().x - drawn_rest.get_center().x) * host.facing < 0.0,
		"the drawn fallback puppet recoils exactly like a supplied image")
	host._process(host.RECOIL_MAX_SECONDS)
	host.idle_phase = host_phase
	_check(not host.recoiling() and host.posed_fallback_rect() == drawn_rest,
		"the drawn fallback settles exactly back to its rest pose")
	# A rebind drops a recoil in flight, so one actor never finishes another's shake.
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"a live recoil is in flight before the rebind")
	host.bind_actor(saved_id, {"idle": saved_idle, "attack": saved_attack})
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0)
		and host.actor_id == saved_id,
		"rebinding a different actor ID cancels the recoil in flight")
	host.idle_phase = host_phase
	# Presentation teardown settles every recoil immediately.
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"a live recoil is in flight before presentation teardown")
	presenter.cancel_poses()
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0),
		"presentation teardown settles every recoil immediately")
	host.idle_phase = host_phase
	# A fallen actor neither starts nor keeps a recoil.
	var saved_fallen: bool = host.fallen
	host.fallen = true
	_check(not host.trigger_recoil(0.6) and not host.recoiling(),
		"a fallen actor never starts a hit recoil")
	host.fallen = false
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"the same actor starts a recoil again once it stands")
	host.fallen = true
	host._process(0.1)
	_check(not host.recoiling() and is_equal_approx(host.recoil_pixels(), 0.0),
		"falling mid-recoil cancels it instead of leaving a stale shake")
	host.fallen = saved_fallen
	host.idle_phase = host_phase
	# Mounted lookup by side plus authoritative ID; anything else fails closed.
	var hero_host = presenter._puppets[0]
	var enemy_host = presenter._puppets[CombatParty.PARTY_SIZE]
	_check(not hero_host.actor_id.is_empty() and not enemy_host.actor_id.is_empty()
		and hero_host.actor_id != enemy_host.actor_id,
		"the live battle binds distinct authoritative hero and enemy IDs")
	_check(presenter.puppet_for("hero", hero_host.actor_id) == hero_host
		and presenter.puppet_for("enemy", enemy_host.actor_id) == enemy_host,
		"the mounted lookup resolves each side's own puppet by authoritative ID")
	_check(presenter.puppet_for("enemy", hero_host.actor_id) == null
		and presenter.puppet_for("hero", enemy_host.actor_id) == null
		and presenter.puppet_for("bogus", hero_host.actor_id) == null
		and presenter.puppet_for("hero", "") == null
		and presenter.puppet_for("hero", "fabricated_missing_actor") == null,
		"the mounted lookup fails closed for the wrong side, an unknown side and a stale ID")
	_check(presenter.hero_puppet(hero_host.actor_id) == hero_host
		and presenter.hero_puppet(enemy_host.actor_id) == null,
		"the existing hero lookup keeps its fail-closed identity")
	var duplicate = presenter._puppets[1]
	var duplicate_id: String = duplicate.actor_id
	duplicate.actor_id = hero_host.actor_id
	_check(presenter.puppet_for("hero", hero_host.actor_id) == null
		and presenter.hero_puppet(hero_host.actor_id) == null,
		"an ambiguous duplicate binding resolves no puppet instead of picking one")
	duplicate.actor_id = duplicate_id
	_check(presenter.puppet_for("hero", hero_host.actor_id) == hero_host,
		"restoring the binding restores the same mounted lookup")
	enemy_host.fallen = true
	_check(presenter.puppet_for("enemy", enemy_host.actor_id) == null,
		"a fallen actor's puppet is never resolved for a hit reaction")
	enemy_host.fallen = false
	# Source inspection: a bounded delta-driven draw pose, never a tween, timer or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var trigger_body := _function_body(source, "func trigger_recoil(")
	var advance_body := _function_body(source, "func advance_recoil(")
	var transform_body := _function_body(source, "func idle_transform(")
	var bind_body := _function_body(source, "func bind_actor(")
	var cancel_body := _function_body(source, "func cancel_poses() -> void:")
	_check(trigger_body.contains("recoil_span = clampf(") and trigger_body.contains("RECOIL_MAX_SECONDS")
		and trigger_body.contains("if fallen")
		and advance_body.contains("recoil_remaining = maxf(") and advance_body.contains("cancel_recoil()")
		and not trigger_body.contains("create_tween") and not advance_body.contains("create_tween")
		and not trigger_body.contains("Timer.new") and not advance_body.contains("Timer.new")
		and not trigger_body.contains("randi(") and not advance_body.contains("randf("),
		"the recoil is a bounded delta-driven state, never a tween, timer or RNG draw")
	_check(transform_body.contains("attack_lunge() + recoil_pixels()")
		and not transform_body.contains("position =") and not transform_body.contains("offset_"),
		"the one shared draw transform carries the recoil and never moves the Control")
	_check(bind_body.contains("cancel_recoil()") and cancel_body.contains("puppet.cancel_recoil()"),
		"a rebind and presentation teardown both drop a recoil in flight")
	# Every mounted control keeps its exact place, caption and target.
	var after_puppets: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_puppets.append(puppet.get_global_rect())
	_check(after_puppets == puppet_rects, "no actor target rectangle moves during any recoil")
	var after_tags: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tags.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tags.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tags == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text during recoils")
	var after_badges: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badges.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badges == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption during recoils")
	var after_controls: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_controls.append(control.get_global_rect())
	_check(after_controls == control_rects,
		"hand, actions and the enemy roster panel stay put during recoils")
	_check(_snapshot(app) == before,
		"a committed hit recoil changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the hit recoil creates no tween that outlives the frame")


## VIS V5 fall settle: a witnessed living-to-zero HP transition eases only that actor's
## drawn artwork from upright into the existing still fallen pose. `fallen` stays
## authoritative at once, every control, pinned name, intent badge and target rectangle
## keeps its exact place, and no combat value, deck, energy, intent or run RNG moves.
func _fall_settle(app, presenter) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty(),
		"fall settle checks run on every actual mounted actor")
	if not is_instance_valid(presenter.panel) or presenter.enemies == null or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var host = null
	for puppet in presenter._puppets:
		if puppet.facing < 0.0 and not puppet.fallen and not puppet.actor_id.is_empty():
			host = puppet
			break
	_check(host != null, "a living enemy puppet is mounted for the fall settle")
	if host == null:
		return
	var control_rect: Rect2 = host.get_global_rect()
	var label: Label = host.get_child(0) as Label
	var tag_rect: Rect2 = label.get_global_rect() if is_instance_valid(label) else Rect2()
	var tag_text: String = label.text if is_instance_valid(label) else ""
	var rest: Rect2 = host.posed_actor_rect()
	_check(not host.fallen and not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), 0.0) and is_equal_approx(host.fall_shape(), 1.0),
		"a standing actor is upright with no fall settle in flight")
	_check(not host.settle_fall(0.0) and not host.settle_fall(-0.5) and not host.settling_fall(),
		"a zero or negative fall span never starts a settle")
	# The transition itself: fallen is authoritative immediately, and the drawn tilt starts
	# upright so the artwork really eases into the existing fallen pose.
	var phase: float = host.idle_phase
	host.fallen = true
	_check(not host.trigger_attack(0.6) and not host.attacking()
		and not host.trigger_recoil(0.6) and not host.recoiling(),
		"a fallen actor rejects a committed pose and a hit recoil at once")
	_check(host.settle_fall(30.0) and host.settling_fall()
		and host.fall_span <= host.FALL_MAX_SECONDS and host.fall_span > 0.0,
		"one witnessed fall starts a settle bounded to the approved span")
	_check(is_equal_approx(host.fall_shape(), 0.0) and is_equal_approx(host.fallen_tilt(), 0.0)
		and host.posed_actor_rect().get_center().distance_to(rest.get_center()) <= 2.0,
		"the settling artwork starts upright, where the standing actor rested")
	var tilts: Array[float] = [0.0]
	for step in range(4):
		host._process(host.fall_span * 0.25 if step == 0 else 0.1)
		tilts.append(host.fallen_tilt())
		_check(host.posed_actor_rect().size.x > 0.0 and host.posed_actor_rect().size.y > 0.0,
			"the settling fall keeps drawing the actor's own artwork: " + host.name)
		_check(host.get_global_rect() == control_rect,
			"the settling fall never moves the actor target: " + host.name)
	var grew := true
	for index in range(1, tilts.size()):
		if absf(tilts[index]) <= absf(tilts[index - 1]) or absf(tilts[index]) > host.FALL_TILT + 0.001:
			grew = false
	_check(grew, "the drawn tilt eases monotonically into the existing fallen tilt")
	host._process(host.FALL_MAX_SECONDS)
	var settled: Rect2 = host.posed_actor_rect()
	_check(not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing)
		and is_equal_approx(host.idle_bob(), 0.0),
		"the settled fall matches the existing still fallen tilt exactly")
	host._process(0.5)
	_check(host.posed_actor_rect() == settled and is_equal_approx(host.idle_phase, phase),
		"a settled fall leaves the artwork perfectly still with no idle motion")
	_check(is_instance_valid(label) and label.get_global_rect() == tag_rect
		and label.text == tag_text and label.is_visible_in_tree(),
		"the pinned name keeps its exact place and text through the fall: " + host.name)
	# The mounted lookup used for targeting keeps its fail-closed fallen rule, while the
	# fall reaction may still address exactly this actor by its own side and ID.
	_check(presenter.puppet_for("enemy", host.actor_id) == null
		and presenter.hero_puppet(host.actor_id) == null,
		"a fallen actor is still never resolved for targeting")
	_check(presenter.presented_puppet("enemy", host.actor_id) == host,
		"presentation still resolves exactly the fallen actor its own hit left mounted")
	_check(presenter.presented_puppet("hero", host.actor_id) == null
		and presenter.presented_puppet("bogus", host.actor_id) == null
		and presenter.presented_puppet("enemy", "") == null
		and presenter.presented_puppet("enemy", "fabricated_missing_actor") == null,
		"the presentation lookup fails closed for the wrong side, an unknown side and a stale ID")
	_check(presenter.presented_puppet("enemy", host.actor_id) == host
		and presenter.settle_fall("enemy", host.actor_id, 0.6) and host.settling_fall(),
		"the fall reaction and the presentation lookup agree on the same fallen puppet")
	_check(not presenter.settle_fall("hero", host.actor_id, 0.6)
		and not presenter.settle_fall("bogus", host.actor_id, 0.6)
		and not presenter.settle_fall("enemy", "", 0.6)
		and not presenter.settle_fall("enemy", "fabricated_missing_actor", 0.6),
		"the fall lookup fails closed for the wrong side, an unknown side and a stale ID")
	var duplicate = null
	for puppet in presenter._puppets:
		if puppet != host and is_equal_approx(puppet.facing, host.facing):
			duplicate = puppet
			break
	_check(duplicate != null, "a second puppet of the same side exists for the ambiguous binding")
	if duplicate != null:
		var duplicate_id: String = duplicate.actor_id
		duplicate.actor_id = host.actor_id
		_check(not presenter.settle_fall("enemy", host.actor_id, 0.6)
			and presenter.presented_puppet("enemy", host.actor_id) == null,
			"an ambiguous duplicate binding settles and presents no puppet")
		duplicate.actor_id = duplicate_id
	host.cancel_fall()
	_check(not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing),
		"cancelling a settle leaves the existing still fallen pose")
	# Standing up drops the settle at once and the artwork is upright again.
	host.fallen = false
	host._process(0.1)
	_check(not host.settling_fall() and is_equal_approx(host.fallen_tilt(), 0.0),
		"a revived actor drops the fall settle and draws upright")
	host.idle_phase = phase
	# Rebind: a fresh actor ID never inherits another actor's settle.
	host.fallen = true
	_check(host.settle_fall(0.6) and host.settling_fall(),
		"a live fall settle is in flight before the rebind")
	host.bind_actor("fabricated_fall_actor", {})
	_check(not host.settling_fall(),
		"rebinding a different actor ID cancels the settle in flight")
	host.fallen = false
	host.bind_actor(String(presenter.enemies.get_enemy(host.slot).get("id")),
		presenter.art_for(String(presenter.enemies.get_enemy(host.slot).get("id"))))
	host.idle_phase = phase
	_check(is_equal_approx(host.fallen_tilt(), 0.0) and host.posed_actor_rect() != Rect2(),
		"the restored standing actor draws its own idle pose again")
	# Source inspection: the tilt is interpolated inside the one shared draw transform, with
	# no tween, timer, RNG or Control movement, and the fall is a bounded delta-driven state.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var transform_body := _function_body(source, "func idle_transform(")
	var fall_body := _function_body(source, "func advance_fall(")
	var tilt_body := _function_body(source, "func fallen_tilt(")
	var settle_body := _function_body(source, "func settle_fall(")
	_check(transform_body.contains("fallen_tilt()")
		and transform_body.contains("attack_lunge() + recoil_pixels()")
		and not transform_body.contains("position =") and not transform_body.contains("offset_"),
		"the one shared draw transform carries the settled fall and never moves the Control")
	_check(settle_body.contains("fall_span = clampf(") and settle_body.contains("FALL_MAX_SECONDS")
		and fall_body.contains("fall_remaining = maxf(") and fall_body.contains("cancel_fall()")
		and tilt_body.contains("-FALL_TILT * facing * fall_shape()"),
		"the fall is a bounded, delta-driven, facing-correct drawing state")
	_check(not settle_body.contains("create_tween") and not fall_body.contains("create_tween")
		and not settle_body.contains("Timer.new") and not fall_body.contains("Timer.new")
		and not settle_body.contains("randi(") and not fall_body.contains("randf(")
		and not transform_body.contains("create_tween"),
		"the fall settle draws no tween, timer or RNG")
	_check(_snapshot(app) == before,
		"the fall settle changes no HP/Block, deck, energy, turn, intent or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"the fall settle creates no tween that outlives the frame")


## Idle presentation: every living actor advances its own subtle bob and breathing pose
## inside its art band, while target rectangles, pinned names, intent badges, controls,
## combat state and RNG stay exactly as they were.
func _idle_motion(app, presenter, expect_fallback: bool = false) -> void:
	_check(is_instance_valid(presenter.panel) and presenter.enemies != null
		and not presenter._puppets.is_empty()
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
		"idle pose exercise runs on every actual mounted hero and enemy")
	if not is_instance_valid(presenter.panel) or presenter.enemies == null or presenter._puppets.is_empty():
		return
	var before: Array = _snapshot(app)
	var tweens: int = get_processed_tweens().size()
	var hit_rects: Array[Rect2] = []
	var tag_rects: Array[Rect2] = []
	var tag_texts: Array[String] = []
	var badge_rects: Array[Rect2] = []
	var badge_texts: Array[String] = []
	var control_rects: Array[Rect2] = []
	for puppet in presenter._puppets:
		hit_rects.append(puppet.get_global_rect())
	for tag in presenter._hero_tags:
		tag_rects.append(tag.get_global_rect())
		tag_texts.append(tag.text)
	for label in presenter._labels:
		tag_rects.append(label.get_global_rect())
		tag_texts.append(label.text)
	for badge in presenter._badges:
		badge_rects.append(badge.get_global_rect())
		badge_texts.append(badge.readable_text)
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		control_rects.append(control.get_global_rect())
	var standing: Array = []
	for puppet in presenter._puppets:
		puppet.idle_phase = 0.0
		_check(puppet.is_processing(), "mounted puppet runs its idle frame tick: " + puppet.name)
		_check(puppet.find_children("*", "Timer", true, false).is_empty(),
			"idle motion schedules no timer under the actor: " + puppet.name)
		if not puppet.fallen:
			standing.append(puppet)
	_check(standing.size() == presenter._puppets.size(),
		"idle pose exercise starts with every mounted actor standing")
	if standing.is_empty():
		return
	# Stable distinct phases: no two actors bob or breathe in step.
	for first in range(standing.size()):
		for second in range(first + 1, standing.size()):
			_check(not is_equal_approx(standing[first].idle_offset(), standing[second].idle_offset())
				and not is_equal_approx(standing[first].idle_bob(), standing[second].idle_bob()),
				"each actor keeps its own deterministic idle phase")
	var fallback_seen := false
	for puppet in standing:
		var band: Rect2 = puppet.art_band()
		var inset: float = puppet.art_safety_inset()
		_check(band.size.y > 0.0 and inset >= puppet.IDLE_BOB_PIXELS,
			"art band reserves room for the bob and breathing swell: " + puppet.name)
		var low := 0.0
		var high := 0.0
		var breath_low := 1.0
		var breath_high := 1.0
		var height_low := 0.0
		var height_high := 0.0
		var first_pose := Rect2()
		var moved := false
		puppet.idle_phase = 0.0
		# Six seconds of real 0.2 s frames covers a whole bob and breathing cycle.
		for step in range(31):
			var bob: float = puppet.idle_bob()
			var breath: float = puppet.idle_breath()
			low = minf(low, bob)
			high = maxf(high, bob)
			breath_low = minf(breath_low, breath)
			breath_high = maxf(breath_high, breath)
			var posed: Rect2 = puppet.posed_actor_rect()
			_check(posed.size.x > 0.0 and posed.size.y > 0.0 and band.grow(-0.5).encloses(posed),
				"animated artwork stays wholly inside its art band with a safety inset: " + puppet.name)
			_check(absf(bob) <= puppet.IDLE_BOB_PIXELS + 0.001
				and absf(breath - 1.0) <= puppet.IDLE_BREATHE + 0.001,
				"idle pose stays a couple of pixels and about one percent: " + puppet.name)
			if step == 0:
				first_pose = posed
				height_low = posed.size.y
				height_high = posed.size.y
			else:
				height_low = minf(height_low, posed.size.y)
				height_high = maxf(height_high, posed.size.y)
				if absf(posed.position.y - first_pose.position.y) > 0.5:
					moved = true
			puppet._process(0.2)
		_check(high - low >= 2.0 and high - low <= 3.0
			and high >= puppet.IDLE_BOB_PIXELS * 0.9 and low <= -puppet.IDLE_BOB_PIXELS * 0.9,
			"living actor bobs two to three pixels above and below its rest pose: " + puppet.name)
		_check(breath_high - 1.0 >= 0.009 and 1.0 - breath_low >= 0.009,
			"living actor breathes about one percent in both directions: " + puppet.name)
		_check(height_high - height_low >= 1.0,
			"breathing visibly changes the drawn artwork height: " + puppet.name)
		_check(moved, "real frame deltas advance the drawn pose: " + puppet.name)
		var phase: float = puppet.idle_phase
		puppet._process(0.25)
		_check(is_equal_approx(puppet.idle_phase, phase + 0.25),
			"idle phase advances by the real delta: " + puppet.name)
		if puppet.current_texture() == null:
			fallback_seen = true
			_check(puppet.posed_image_rect() == Rect2() and puppet.posed_fallback_rect().size.y > 0.0,
				"missing art advances the drawn fallback pose: " + puppet.name)
		else:
			_check(puppet.posed_image_rect().size.y > 0.0
				and puppet.posed_actor_rect().is_equal_approx(puppet.posed_image_rect()),
				"supplied art draw path uses the same shared pose: " + puppet.name)
	var actual_fallback := false
	for puppet in presenter._puppets:
		actual_fallback = actual_fallback or puppet.current_texture() == null
	_check(fallback_seen == actual_fallback,
		"the drawn fallback animates exactly for the actors actually lacking art")
	for puppet in presenter._puppets:
		puppet._process(0.4)
	var after_hit: Array[Rect2] = []
	for puppet in presenter._puppets:
		after_hit.append(puppet.get_global_rect())
	_check(after_hit == hit_rects, "idle art never moves an actor's complete target rectangle")
	var after_tag_rects: Array[Rect2] = []
	var after_tag_texts: Array[String] = []
	for tag in presenter._hero_tags:
		after_tag_rects.append(tag.get_global_rect())
		after_tag_texts.append(tag.text)
	for label in presenter._labels:
		after_tag_rects.append(label.get_global_rect())
		after_tag_texts.append(label.text)
	_check(after_tag_rects == tag_rects and after_tag_texts == tag_texts,
		"pinned hero and enemy names keep their exact place and text while art moves")
	var after_badge_rects: Array[Rect2] = []
	var after_badge_texts: Array[String] = []
	for badge in presenter._badges:
		after_badge_rects.append(badge.get_global_rect())
		after_badge_texts.append(badge.readable_text)
	_check(after_badge_rects == badge_rects and after_badge_texts == badge_texts,
		"intent badges keep their exact place and caption while art moves")
	var after_control_rects: Array[Rect2] = []
	for control in [app.end_turn_button, app.return_button, app.hand_view, presenter.panel]:
		after_control_rects.append(control.get_global_rect())
	_check(after_control_rects == control_rects,
		"hand, actions and the enemy roster panel stay put while art moves")
	_check(_snapshot(app) == before,
		"idle presentation changes no HP/Block, deck, energy, turn, intents or run RNG")
	_check(get_processed_tweens().size() == tweens,
		"idle motion creates no tween that outlives the frame")
	# Source inspection: both draw paths really apply the pose, with no timers or RNG.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var actor_body := _function_body(source, "func _draw_actor(")
	var fallback_body := _function_body(source, "func _draw_fallback(")
	_check(actor_body.contains("idle_transform(") and fallback_body.contains("idle_transform(")
		and actor_body.find("idle_transform(") < actor_body.find("draw_texture_rect("),
		"source applies the idle pose before drawing both the texture and the fallback")
	_check(source.contains("func _process(delta: float) -> void:") and source.contains("advance_idle(delta)")
		and source.contains("idle_phase += delta") and not source.contains("create_tween")
		and not source.contains("Timer.new") and not source.contains("randi(")
		and not source.contains("randf("),
		"idle animation advances a per-instance delta phase without tweens, timers or RNG")


## A downed or slain actor is authoritative at once: the existing tilt and tint, no idle
## motion and every attack/recoil rejection. Only the one bounded settling of the drawn
## artwork may run; it must end exactly at the existing still fallen pose and every target
## rectangle must stay fixed.
func _fallen_stillness(puppets: Array) -> void:
	for puppet in puppets:
		_check(puppet.fallen, "fallen stillness runs on a genuinely downed/slain actor: " + puppet.name)
		if not puppet.fallen:
			continue
		var phase: float = puppet.idle_phase
		var control_rect: Rect2 = puppet.get_global_rect()
		var immediate: Rect2 = puppet.posed_actor_rect()
		_check(not puppet.trigger_attack(0.6) and not puppet.attacking()
			and puppet.posed_actor_rect() == immediate,
			"a fallen actor never starts a committed attack pose: " + puppet.name)
		_check(not puppet.trigger_recoil(0.6) and not puppet.recoiling()
			and puppet.posed_actor_rect() == immediate,
			"a fallen actor never starts a hit recoil: " + puppet.name)
		_check(puppet.fall_span <= puppet.FALL_MAX_SECONDS,
			"a fall settle is bounded to the approved span: " + puppet.name)
		puppet._process(puppet.FALL_MAX_SECONDS)
		var pose: Rect2 = puppet.posed_actor_rect()
		_check(not puppet.settling_fall()
			and is_equal_approx(puppet.fallen_tilt(),
				0.0 if not puppet.death_frames.is_empty() else -puppet.FALL_TILT * puppet.facing),
			"a settled fall ends exactly at the existing still fallen tilt: " + puppet.name)
		puppet._process(0.5)
		_check(is_equal_approx(puppet.idle_phase, phase),
			"fallen actor stops advancing its idle phase: " + puppet.name)
		_check(is_equal_approx(puppet.idle_bob(), 0.0) and is_equal_approx(puppet.idle_breath(), 1.0),
			"fallen actor keeps no bob or breathing: " + puppet.name)
		_check(puppet.posed_actor_rect() == pose,
			"fallen actor's drawn artwork stays perfectly still: " + puppet.name)
		puppet._process(1.0)
		_check(puppet.posed_actor_rect() == pose and is_equal_approx(puppet.idle_phase, phase),
			"further frame deltas leave the fallen actor motionless: " + puppet.name)
		_check(puppet.get_global_rect() == control_rect,
			"falling never moves the actor's own control or target rectangle: " + puppet.name)
		_check(not puppet.trigger_attack(0.6) and not puppet.attacking()
			and puppet.posed_actor_rect() == pose,
			"a fallen actor never starts a committed attack pose: " + puppet.name)
		_check(not puppet.trigger_recoil(0.6) and not puppet.recoiling()
			and puppet.posed_actor_rect() == pose,
			"a fallen actor never starts a hit recoil: " + puppet.name)


## A freshly mounted battle builds new puppets that start their idle phase at rest.
func _at_rest(puppets: Array) -> bool:
	if puppets.is_empty():
		return false
	for puppet in puppets:
		if not is_instance_valid(puppet) or not is_equal_approx(puppet.idle_phase, 0.0):
			return false
	return true


## Cycle 183: the mounted intent caption is a dark sewn plaque with high-contrast cream ink
## at a bounded, fitted size, and a target-policy cue stays its own readable ticket beside
## it. The real mounted two-enemy battle proves the attack and Block tags the player sees,
## then the same mounted badge proves a long debuff and a long shove beside a real policy,
## with committed icon art and its sewn fallback still visible. Every transition is
## presentation only: authoritative text, amount, target, icons and all combat/RNG state
## stay exactly as announced.
func _caption_legibility(app, presenter) -> void:
	_check(presenter.enemies != null and app.deck != null and presenter._badges.size() == 2,
		"caption legibility checks run on the real mounted two-enemy battle")
	if presenter.enemies == null or app.deck == null or presenter._badges.size() != 2:
		return
	var before := _snapshot(app)
	var styles: Array[String] = []
	for mounted in presenter._badges:
		styles.append(mounted.icon_mode)
	_check(styles.size() == 2 and styles[0] == "attack"
		and styles[1] == String(STARTER_ORACLE.guard_action(
			app.enemy_intents.get_intents()).get("type", "")),
		"the mounted battle really announces its authored intents")
	for badge in presenter._badges:
		# The attack and Block tags the player reads: dark backing, cream ink and the
		# theme's own body size instead of the old floating 14 px caption.
		_check(badge.caption_font_size() == LiveEnemyIntentBadge.CAPTION_MAX_FONT
			and badge.caption_font_size() > 14,
			"mounted %s caption uses the larger bounded body size" % badge.icon_mode)
		_check(_caption_fits(badge),
			"mounted %s caption fits inside its badge without clipping" % badge.icon_mode)
		_check(badge.caption_ink() == LiveEnemyIntentBadge.CAPTION_INK
			and badge.caption_ink() != LiveEnemyIntentBadge.MUTED
			and _contrast(badge.caption_ink(), LiveEnemyIntentBadge.CAPTION_FILL) >= 7.0,
			"mounted %s caption ink is high-contrast cream on the dark plaque" % badge.icon_mode)
		var plaque: Rect2 = badge.caption_rect()
		_check(plaque.size.x > 0.0 and plaque.size.y > 0.0
			and plaque.position.x > badge.patch_rect().end.x
			and not plaque.intersects(badge.icon_rect())
			and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(plaque),
			"the dark caption plaque sits beside the sewn patch inside the same badge")
		_check(badge.policy_cue.is_empty() and badge.policy_rect() == Rect2()
			and badge.policy_text_rect() == Rect2(),
			"an unbound live schedule paints no invented policy ticket")
	var badge = presenter._badges[0]
	# A long authoritative debuff beside a real front policy: the caption steps down only as
	# far as the bounded floor and never runs under the policy ticket.
	var long_debuff := {"type": "debuff", "amount": 2, "status": "exposed", "target_position": 2}
	var original := long_debuff.duplicate(true)
	badge.show_intent(long_debuff, false, false, "front")
	_check(badge.readable_text == "Exposed 2 → 2" and badge.amount == 2
		and badge.target_position == 2 and badge.intent_type == "debuff"
		and badge.policy_cue == "Front" and long_debuff == original,
		"a long debuff keeps its exact amount and destination beside its target policy")
	_check(badge.tooltip_text == "Exposed 2 to Hero 2 (middle) — for 2 turns, +50% incoming attack damage; damage is rounded down, minimum 0.\nTarget policy (FRONT): picks the front living hero.",
		"debuff with front policy explains exposed rule, hero target and front policy")
	_check(_caption_fits(badge)
		and badge.caption_font_size() >= LiveEnemyIntentBadge.CAPTION_MIN_FONT
		and _contrast(badge.caption_ink(), LiveEnemyIntentBadge.CAPTION_FILL) >= 7.0,
		"the long debuff caption is bounded, fitted and readable on the dark plaque")
	var tag: Rect2 = badge.policy_rect()
	var text: Rect2 = badge.caption_text_rect()
	_check(tag.size.x > 0.0 and tag.size.y > 0.0
		and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(tag)
		and not text.intersects(tag) and tag.grow(0.01).encloses(badge.policy_text_rect())
		and _contrast(LiveEnemyIntentBadge.POLICY_INK, LiveEnemyIntentBadge.POLICY_FILL) >= 4.5,
		"the target policy keeps its own readable ticket, clear of the caption text")
	_check(_badge_icon_fits(badge, "res://assets/paper/ui/intent_debuff.png")
		and badge.caption_rect().position.x > badge.patch_rect().end.x,
		"the long debuff caption keeps its committed icon art visible beside it")
	# A long shove caption with the longest targeting cue: still inside the same band.
	badge.show_intent({"type": "shove", "amount": 0, "target_position": 3,
		"direction": -1}, false, false, "lowest_living_hp")
	_check(badge.readable_text == "Shove 3 forward" and badge.icon_mode == "shove"
		and badge.target_position == 3 and badge.policy_cue == "Aim low HP"
		and _caption_fits(badge) and _badge_icon_fits(badge, ""),
		"a long shove caption fits beside its aiming ticket and keeps the sewn glyph")
	_check(badge.tooltip_text == "Push front Hero 3 (back).\nTarget policy (AIM LOW HP): aims at the living hero with the lowest current HP.",
		"shove with lowest_living_hp policy explains push front, hero target and current-HP aiming")
	# Unavailable icon art: the real missing-image fallback still paints the same readable
	# caption, plaque, policy ticket and sewn glyph from the same authoritative text.
	var saved_root: String = badge.icon_root
	badge.icon_root = "res://assets/paper/ui/absent/"
	badge.show_intent(long_debuff, false, false, "exposed")
	_check(badge.icon_texture == null and _badge_icon_fits(badge, "")
		and badge.readable_text == "Exposed 2 → 2" and badge.amount == 2
		and badge.target_position == 2 and badge.policy_cue == "Exposed"
		and _caption_fits(badge) and badge.policy_text_rect() != Rect2(),
		"unavailable icon art keeps the readable caption, plaque and policy ticket")
	_check(badge.tooltip_text == "Exposed 2 to Hero 2 (middle) — for 2 turns, +50% incoming attack damage; damage is rounded down, minimum 0.\nTarget policy (EXPOSED): prioritises an Exposed living hero.",
		"debuff with exposed policy explains exposed rule, hero target and exposed policy")
	var atk_random := {"type": "attack", "amount": 7, "target_position": 1}
	badge.show_intent(atk_random, false, false, "random")
	_check(badge.tooltip_text == "7 damage aimed at Hero 1 (front).\nTarget policy (RANDOM): uses the run-seeded target choice.",
		"attack with random policy explains damage, hero target and random policy")
	badge.show_intent(atk_random, false, false, "")
	_check(badge.tooltip_text == "7 damage aimed at Hero 1 (front).",
		"targeted attack without policy includes no policy text")
	badge.show_intent(atk_random, false, false, "front")
	_check(badge.tooltip_text.contains("Target policy (FRONT)"), "policy present before unravel")
	badge.show_intent(atk_random, false, true, "front")
	_check(badge.tooltip_text == "Unravelled: next action is skipped.",
		"unravelled suppresses attack and policy tooltip")
	badge.show_intent(atk_random, true, false, "front")
	_check(badge.tooltip_text == "Slain: no action.",
		"slain suppresses attack and policy tooltip")
	badge.show_intent(atk_random, false, false, "front")
	_check(badge.tooltip_text == "7 damage aimed at Hero 1 (front).\nTarget policy (FRONT): picks the front living hero.",
		"fresh intent cleanly restores attack and policy tooltip")
	badge.icon_root = saved_root
	_check(_snapshot(app) == before,
		"every caption, plaque and policy transition is presentation only")
	presenter._refresh()
	_check(_snapshot(app) == before and presenter._badges[0].readable_text == "Hit 5: Front"
		and presenter._badges[0].policy_cue.is_empty()
		and _caption_fits(presenter._badges[0]) and _caption_fits(presenter._badges[1]),
		"a refresh restores the real announcements with fitted captions")
	# Source inspection: the plaque is painted beneath the fitted caption, never floating ink.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_intent_badge.gd")
	var draw_body := _method_body(source, "func _draw() -> void:")
	var caption_body := _method_body(source, "func _draw_caption() -> void:")
	var fit_body := _method_body(source, "func caption_font_size() -> int:")
	var floor_body := _method_body(source, "func caption_floor_font() -> int:")
	var compact_body := _method_body(source, "func compact_caption_forms() -> Array[String]:")
	_check(draw_body.contains("_draw_caption()")
		and caption_body.find("draw_colored_polygon(") >= 0
		and caption_body.find("CAPTION_FILL") >= 0
		and caption_body.find("draw_colored_polygon(") < caption_body.find("draw_string(")
		and caption_body.contains("caption_ink()") and caption_body.contains("POLICY_FILL"),
		"source paints the dark plaque under the cream caption and the separate policy ticket")
	_check(fit_body.contains("CAPTION_MAX_FONT") and fit_body.contains("caption_floor_font()")
		and fit_body.contains("get_string_size(") and not fit_body.contains("-1, 14")
		and floor_body.contains("CAPTION_MIN_FONT") and floor_body.contains("COMPACT_MIN_FONT")
		and compact_body.contains("Hit %d → %d") and compact_body.contains("Shove %d %s"),
		"source fits the caption with the real theme font between its compact and full floors")
	_check(source.contains("func caption_ink() -> Color:")
		and source.contains("func caption_rect() -> Rect2:")
		and not source.contains("MUTED if icon_mode in [\"slain\", \"none\"] else CREAM"),
		"source replaced the low-contrast floating caption with the backed one")


## The authored front policy's living target, read from the real party.
func _front_target(app) -> int:
	for index in range(CombatParty.PARTY_SIZE):
		if app.party.get_hero(index + 1).hp > 0:
			return index + 1
	return 1


## One channel of relative luminance, for a real ink-to-backing contrast measurement.
func _channel(value: float) -> float:
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


func _contrast(first: Color, second: Color) -> float:
	var high: float = maxf(_luminance(first), _luminance(second))
	var low: float = minf(_luminance(first), _luminance(second))
	return (high + 0.05) / (low + 0.05)


## The committed art (or its sewn-glyph fallback) stays visible beside the caption.
func _badge_icon_fits(badge, path: String) -> bool:
	var drawn: Rect2 = badge.icon_texture_rect()
	if path.is_empty():
		return badge.icon_texture == null and drawn == Rect2()
	if badge.icon_texture == null or badge.icon_art_path() != path:
		return false
	var pixels := Vector2(badge.icon_texture.get_width(), badge.icon_texture.get_height())
	return pixels.x > 0.0 and pixels.y > 0.0 \
		and drawn.size.x > 0.0 and drawn.size.y > 0.0 \
		and is_equal_approx(drawn.size.x / drawn.size.y, pixels.x / pixels.y) \
		and badge.icon_rect().grow(0.01).encloses(drawn) \
		and badge.patch_rect().grow(0.01).encloses(drawn)


## The compact form the badge really displays beside its targeting ticket: the first authored
## form that measures inside the room left at the 14 px action floor, else the tight form.
## Measured with the theme body face, independently of the badge's own compact-form method.
func _fitted_compact(badge, spaced: String, tight: String) -> String:
	var font: Font = badge.get_theme_default_font()
	var room: float = badge.caption_text_area().size.x
	if font != null and room > 0.0 and font.get_string_size(spaced,
			HORIZONTAL_ALIGNMENT_LEFT, -1, LiveEnemyIntentBadge.COMPACT_MIN_FONT).x <= room:
		return spaced
	return tight


## The mounted caption really fits: its painted text measures inside the caption room at the
## badge's own fitted size, inside the dark plaque, clear of the separate policy ticket and
## wholly inside the badge. The oracle uses the badge's effective Font (display face or body
## face, whichever it really paints with); sizes stay inside the bounded range.
func _caption_fits(badge) -> bool:
	var font: Font = badge.caption_font()
	if font == null or badge.readable_text.is_empty():
		return false
	var size_px: int = badge.caption_font_size()
	var text: Rect2 = badge.caption_text_rect()
	var plaque: Rect2 = badge.caption_rect()
	return size_px >= LiveEnemyIntentBadge.CAPTION_MIN_FONT \
		and size_px <= LiveEnemyIntentBadge.CAPTION_MAX_FONT \
		and text.size.x > 0.0 and text.size.y > 0.0 \
		and is_equal_approx(text.size.x, font.get_string_size(badge.readable_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x) \
		and badge.caption_text_area().grow(0.01).encloses(text) \
		and plaque.grow(0.01).encloses(text) \
		and Rect2(Vector2.ZERO, badge.size).grow(0.01).encloses(plaque) \
		and not text.intersects(badge.policy_rect())


func _assert_badges(app, presenter, expected_target: int = -1, expected_amount: int = 5) -> void:
	if not is_instance_valid(presenter.panel) or presenter.enemies == null:
		_check(false, "badge assertions require a mounted real battle")
		return
	var roster: Array[Dictionary] = presenter.enemies.get_enemies()
	var intents: Array[Dictionary] = app.enemy_intents.get_intents()
	var by_position := {}
	for action in intents:
		by_position[action["enemy_position"]] = action
	var mounted: Array[Node] = presenter.panel.find_children("EnemyIntent*", "Control", true, false)
	_check(mounted.size() == roster.size() and presenter._badges.size() == roster.size(),
		"exactly one mounted intent badge per source roster position")
	if mounted.size() != roster.size() or presenter._badges.size() != roster.size():
		return
	var meters: Array[CombatActorMeter] = []
	for candidate in app.find_children("*", "VBoxContainer", true, false):
		if candidate is CombatActorMeter:
			meters.append(candidate)
	_check(meters.size() == 5, "all three hero and two enemy HP/Block meters remain mounted")
	var positions: Array[int] = []
	var modes: Array[String] = []
	for badge in presenter._badges:
		_check(badge is LiveEnemyIntentBadge and badge in mounted and badge.is_visible_in_tree(),
			"live badge is the drawn Control mounted under the battle roster")
		var position: int = badge.source_position
		positions.append(position)
		_check(position >= 1 and position <= roster.size() and
			roster[position - 1].position == position, "badge source_position matches its enemy")
		if position >= 1 and position <= roster.size():
			var source = presenter._puppets[CombatParty.PARTY_SIZE + position - 1]
			_check(badge.get_parent() == source and source.actor_id == roster[position - 1].id
				and presenter._admitted_ids[position - 1] == source.actor_id,
				"visible ticket is mounted on its actual admitted enemy ID, not a neighboring source")
		_check(by_position.has(position), "authoritative scheduler supplies this enemy position")
		if not by_position.has(position):
			continue
		var announced: Dictionary = by_position[position]
		_check(badge.mouse_filter == Control.MOUSE_FILTER_PASS,
			"drawn badge and text use safe hover filter without intercepting pointer events")
		_check(badge.focus_mode == Control.FOCUS_NONE and not badge.tooltip_text.is_empty(),
			"badge stays focus inert and has informative tooltip")
		_check(not badge.readable_text.is_empty() and _caption_fits(badge),
			"drawn readable intent fits its dark caption plaque inside the badge")
		var rect: Rect2 = badge.get_global_rect()
		_ticket_at_rest(badge)
		var drawn: Rect2 = Rect2(rect.position + badge.patch_rect().position, badge.patch_rect().size)
		_check(rect.size.x >= 192 and rect.size.y >= badge.custom_minimum_size.y - 0.01
			and Rect2(0, 0, 1280, 720).encloses(rect), "badge has visible area within the viewport")
		# The control follows resting artwork, and the drawn patch is
		# complete below the viewport's upper edge, so no stitch is sliced off.
		_check(drawn.position.y >= 8.0 and drawn.end.y <= rect.end.y + 0.01
			and Rect2(0, 0, 1280, 720).encloses(drawn),
			"badge's drawn paper patch sits inside the viewport with a safe top margin")
		_check(not rect.intersects(app.end_turn_button.get_global_rect()) and
			not rect.intersects(app.return_button.get_global_rect()) and
			not rect.intersects(app.hand_view.get_global_rect()),
			"roster intent badge does not cover hand or battle controls")
		_check(badge.caption_rect().position.x > badge.patch_rect().end.x
			and rect.encloses(Rect2(rect.position + badge.caption_text_rect().position,
				badge.caption_text_rect().size)),
			"badge's drawn caption area has adequate width beside the sewn patch")
		for meter in meters:
			_check(not rect.intersects(meter.get_global_rect()), "intent badge does not cover HP/Block meter")
		if app.enemies.is_slain(position):
			_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN" and
				badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0,
				"slain enemy has muted SLAIN icon and no active announced action")
		else:
			var kind: String = announced["type"]
			var amount: int = announced["amount"]
			var target: int = announced.get("target_position", 0)
			var message := _badge_caption(announced)
			_check(badge.icon_mode == kind and badge.intent_type == kind and badge.amount == amount and
				badge.target_position == target and badge.readable_text == message,
				"badge mode, text, damage/Block and target equal authoritative copied intent")
			if position == 1 and expected_target != -1:
				_check(kind == "attack" and amount == expected_amount and target == expected_target and
					badge.readable_text == "Hit %d: %s" % [expected_amount, {1: "Front", 2: "Middle", 3: "Back"}[expected_target]],
					"ragling next announced target follows real End Turn scheduler")
			if position == 2:
				var body := announced.duplicate(true)
				body.erase("enemy_position")
				_check(CombatEnemyIntents.valid_action(body),
					"living Guard announces one complete executable action, never accumulated Block")
		modes.append(badge.icon_mode)
	_check(positions == [1, 2], "two unique badges preserve authored enemy source positions")
	if not app.enemies.is_slain(1):
		_check("attack" in modes and LiveEnemyIntentBadge.icon_path_for("attack")
			!= LiveEnemyIntentBadge.icon_path_for("block"),
			"attack spear and Block shield use visibly distinct modes")
	var before: Array = _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == before, "badge refresh does not mutate HP/Block, deck, energy, turn, intents or run RNG")
	seed(92741)
	var next_global: int = randi()
	seed(92741)
	presenter._refresh()
	_check(randi() == next_global, "badge refresh consumes no global RNG")


func _visible(app, presenter) -> void:
	_check(presenter.enemies is CombatEnemies, "real battle has CombatEnemies")
	_check(is_instance_valid(presenter.panel), "enemy panel exists")
	if presenter.enemies == null or not is_instance_valid(presenter.panel):
		return
	_check(presenter.enemies.is_valid(), "roster valid")
	_check(presenter.enemies == app.enemies, "app and presenter share the identical authoritative model")
	var guard: Dictionary = app.enemies.get_enemy(2)
	_check(guard.get("id") == "ragling_guard" and guard.get("name") == "Guard Ragling"
		and guard.get("hp") == 12 and guard.get("max_hp") == 12 and guard.get("block") == 0,
		"authored position-two Guard Ragling starts at 12 HP and zero Block")
	_check(app.intent_label.text == STARTER_ORACLE.intent_text(
		app.enemy_intents.get_intents(), ["Warden", "Seamstress", "Tinker"]),
		"real start announces both authored intents")
	var ragling := presenter.enemies.get_enemy(1) as Dictionary
	_check(ragling.get("id") == "ragling" and ragling.get("position") == 1 and
		ragling.get("hp") == 12 and ragling.get("max_hp") == 12 and ragling.get("block") == 0,
		"authored position-one ragling is living at 12/12 HP and zero Block")
	_check(not presenter.enemies.is_slain(1), "ragling living")
	_check(presenter.panel.is_visible_in_tree() and app.battle_view.is_ancestor_of(presenter.panel),
		"enemy panel visibly mounted inside battle")
	var labels: Array[Label] = presenter._labels
	_check(labels.size() == presenter.enemies.get_enemies().size(), "every roster entry has one pinned name tag")
	_check(presenter.panel.find_children("EnemyState*", "Label", true, false).size() == labels.size(),
		"pinned tags stay the only Labels under the enemy roster")
	_check(not labels.is_empty(), "enemy text exists")
	if not labels.is_empty():
		_check(labels[0].is_visible_in_tree() and labels[0].text == "Ragling",
			"pinned tag names the ragling without a long slot sentence")
		var rect: Rect2 = labels[0].get_global_rect()
		_check(rect.size.x > 0 and rect.size.y > 0 and Rect2(0, 0, 1280, 720).encloses(rect),
			"enemy name tag fits target viewport")
	_check(labels.size() >= 2, "Guard tag exists")
	if labels.size() >= 2:
		_check(labels[1].is_visible_in_tree() and labels[1].text == "Guard Ragling",
			"pinned tag names the Guard without a long slot sentence")
		_check(Rect2(0, 0, 1280, 720).encloses(labels[1].get_global_rect()), "Guard tag fits target viewport")
	_name_tags(app, presenter)
	_backdrop(app, presenter)
	_assert_badges(app, presenter, 1)
	_check(not app.intent_label.visible and not app.intent_label.text.is_empty(), "redundant legacy sentence is hidden while authoritative source remains")
	_check(presenter._puppets.size() == 3 + presenter.enemies.get_enemies().size(), "one presenter puppet for every actual actor")
	for puppet in presenter._puppets:
		_check(is_instance_valid(puppet) and puppet.is_visible_in_tree() and puppet.mouse_filter == Control.MOUSE_FILTER_IGNORE and puppet.focus_mode == Control.FOCUS_NONE, "mounted puppet is visible and input inert")
		_check(puppet.facing == (1.0 if puppet.name.begins_with("Hero") else -1.0), "actor puppet faces inward")
	_assert_actor_art(app, presenter)
	_staging(app, presenter)
	_idle_motion(app, presenter)
	_attack_pose(app, presenter)
	_recoil(app, presenter)
	_fall_settle(app, presenter)
	_check(app.end_turn_button.is_visible_in_tree() and app.return_button.is_visible_in_tree(),
		"real battle actions stay visible")
	_check(Rect2(0, 0, 1280, 720).encloses(app.return_button.get_global_rect()), "return action fits viewport")
	_check(app.end_turn_button.focus_next == app.end_turn_button.get_path_to(app.return_button),
		"keyboard action navigation retained")
	_check(app.end_turn_button.focus_mode != Control.FOCUS_NONE and
		app.return_button.focus_mode != Control.FOCUS_NONE and
		app.end_turn_button.mouse_filter != Control.MOUSE_FILTER_IGNORE and
		app.return_button.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		"keyboard and pointer controls still receive input")
	_geometry(app, presenter)


## The visible lettering of one mounted name tag: the effective font and size the control
## really prints with, measured independently through the TextServer.
func _tag_print_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	if font == null:
		return INF
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		label.get_theme_font_size("font_size")).x


## Small pinned name tags: the authoritative short name sewn in the shipped PatchHeading
## display face, input inert, below the art band and clear of the meter row and the
## intent badges. The lettering is measured with the effective font, at the readable 18 px
## VIS body size and inside the 26 px felt band, so a wider display face cannot clip silently.
func _name_tags(app, presenter) -> void:
	var theme: Theme = app.theme
	_check(theme != null and theme.is_type_variation("PatchHeading", "Label")
		and theme.get_font("font", "PatchHeading") is Font
		and (theme.get_font("font", "PatchHeading") as Font).resource_path == HEADING_FONT,
		"the mounted battle inherits the shipped PatchHeading Londrina display face")
	_check(ROSTER_ART.NAME_TAG_VARIATION == "PatchHeading",
		"both tag builders select the master PatchHeading variation by name")
	_check(presenter._hero_tags.size() == app.hero_panels.size(),
		"every mounted hero puppet carries one pinned name tag")
	var enemies: Array[Dictionary] = presenter.enemies.get_enemies()
	var troops: Array = presenter._puppets.slice(CombatParty.PARTY_SIZE)
	_check(troops.size() == enemies.size() and presenter._labels.size() == enemies.size(),
		"one pinned tag per mounted enemy puppet")
	for index in range(mini(troops.size(), presenter._labels.size())):
		var puppet = troops[index]
		var label: Label = presenter._labels[index]
		var name: String = enemies[index].get("name", "")
		_check(not name.is_empty() and label.text == name,
			"enemy tag is exactly the authoritative short name: " + name)
		_check(label.theme_type_variation == "PatchHeading"
			and label.name == "EnemyState%d" % int(enemies[index].get("position", 0)),
			"enemy tag keeps its stable name and wears the sewn display lettering: " + name)
		var tag_font: Font = label.get_theme_font("font")
		var tag_size: int = label.get_theme_font_size("font_size")
		_check(tag_font != null and tag_font.resource_path == HEADING_FONT and tag_size == 18,
			"enemy tag resolves PatchHeading Londrina Solid Regular at the readable 18 px size: " + name)
		_check(label.max_lines_visible == 1 and not label.text.contains("\n")
			and label.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM
			and label.get_theme_constant("outline_size") == 6,
			"enemy tag stays one line of high-contrast felt lettering: " + name)
		_check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE and label.focus_mode == Control.FOCUS_NONE,
			"enemy tag stays input inert while the actor keeps its own hit target")
		_check(label.get_global_rect().position.is_equal_approx(puppet.get_global_rect().position)
			and label.get_global_rect().size.is_equal_approx(puppet.get_global_rect().size),
			"enemy tag keeps the complete enemy hit rectangle")
		_check(puppet.tag_band().size.y > 0.0
			and puppet.tag_band().end.y <= puppet.size.y + 0.01
			and puppet.art_band().end.y <= puppet.tag_band().position.y + 0.01,
			"enemy art band stops above the pinned name tag")
		# The existing fit expectation, now measured with the face that really prints: the
		# display name must fit both the whole actor column and the sewn felt tag inside it.
		var printed: float = _tag_print_width(label, name)
		_check(printed > 0.0 and printed <= puppet.size.x - 16.0,
			"heading-lettered enemy tag fits its column without clipping: " + name)
		_check(printed <= puppet.tag_band().size.x - 20.0,
			"heading-lettered enemy tag stays on its sewn felt tag: " + name)
		_check(tag_font.get_height(tag_size) <= puppet.tag_band().size.y + 0.01,
			"the display face keeps the enemy name inside the 26 px pinned band: " + name)
		_check(label.get_global_rect().end.y - tag_font.get_height(tag_size)
			>= puppet.get_global_rect().position.y + puppet.tag_band().position.y - 0.01,
			"the bottom-aligned heading text really lands inside the enemy tag band: " + name)
		if index < presenter._badges.size():
			var tag_band_global := Rect2(puppet.get_global_rect().position + puppet.tag_band().position,
				puppet.tag_band().size)
			_check(not tag_band_global.intersects(presenter._badges[index].get_global_rect()),
				"enemy pinned tag band stays clear of its intent badge")
	for index in range(presenter._hero_tags.size()):
		var tag: Label = presenter._hero_tags[index]
		var puppet = presenter._puppets[index]
		var hero: Dictionary = app.party.get_hero(index + 1)
		var hero_name: String = hero.get("name", "") if hero.get("name") is String else ""
		_check(tag.is_visible_in_tree() and not hero_name.is_empty() and tag.text == hero_name,
			"hero tag is exactly the authoritative short name")
		_check(tag.theme_type_variation == "PatchHeading"
			and tag.name == "HeroNameTag%d" % (index + 1),
			"hero tag keeps its stable name and wears the sewn display lettering: " + hero_name)
		var tag_font: Font = tag.get_theme_font("font")
		var tag_size: int = tag.get_theme_font_size("font_size")
		_check(tag_font != null and tag_font.resource_path == HEADING_FONT and tag_size == 18,
			"hero tag resolves PatchHeading Londrina Solid Regular at the readable 18 px size: " + hero_name)
		_check(tag.max_lines_visible == 1 and not tag.text.contains("\n")
			and tag.get_theme_constant("outline_size") == 6,
			"hero tag stays one line of high-contrast felt lettering: " + hero_name)
		_check(tag.mouse_filter == Control.MOUSE_FILTER_IGNORE and tag.focus_mode == Control.FOCUS_NONE,
			"hero tag stays input inert")
		_check(tag.get_global_rect().size.y > 0.0
			and puppet.get_global_rect().encloses(tag.get_global_rect())
			and puppet.art_band().end.y <= puppet.tag_band().position.y + 0.01,
			"hero tag sits inside its actor below the stand-in art")
		_check(is_equal_approx(tag.get_global_rect().size.y, presenter.STAGE_TAG_HEIGHT),
			"hero tag keeps the 26 px pinned band height: " + hero_name)
		var printed: float = _tag_print_width(tag, hero_name)
		_check(printed > 0.0 and printed <= puppet.size.x - 16.0,
			"heading-lettered hero tag fits its column without clipping: " + hero_name)
		_check(printed <= puppet.tag_band().size.x - 20.0,
			"heading-lettered hero tag stays on its sewn felt tag: " + hero_name)
		_check(tag_font.get_height(tag_size) <= presenter.STAGE_TAG_HEIGHT + 0.01,
			"the display face keeps the hero name inside the 26 px pinned band: " + hero_name)
	# Source inspection: both the hero builder and the separate enemy label path select the
	# one shipped variation instead of relying on the body face.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var hero_builder := _method_body(source, "func _make_name_tag(")
	var mount := _method_body(source, "func _sync_battle(")
	_check(hero_builder.contains("theme_type_variation = NAME_TAG_VARIATION")
		and mount.contains("label.theme_type_variation = NAME_TAG_VARIATION"),
		"source sews the display variation into the hero tag builder and the enemy tag path")
	_check(hero_builder.count("theme_type_variation") == 1
		and mount.count("theme_type_variation") == 1,
		"neither tag path overrides the inherited variation with a second assignment")
	_check(ROSTER_ART.NAME_TAG_FONT_SIZE == 18, "the pinned name size is the 18 px VIS body floor")
	_check(hero_builder.contains('add_theme_font_size_override("font_size", NAME_TAG_FONT_SIZE)')
		and mount.contains('add_theme_font_size_override("font_size", NAME_TAG_FONT_SIZE)'),
		"source applies the one 18 px name size in both the hero tag builder and the enemy tag path")
	var meters = app.get_node("LiveCombatMeters")
	if is_instance_valid(meters.row) and not presenter._labels.is_empty():
		_check(not presenter._labels[0].get_global_rect().intersects(meters.row.get_global_rect()),
			"pinned actor tags stay clear of the HP/Block/status meter row")


## One battle stage: the authored paper scene of this fight covers the whole battle view,
## and the complete drawn quilt with its ground hem remains whenever no image is available.
func _backdrop(app, presenter) -> void:
	var backdrop = presenter.backdrop
	_check(is_instance_valid(backdrop) and backdrop.name == "BattleStageBackdrop"
		and is_instance_valid(presenter._battle) and backdrop.get_parent() == presenter._battle
		and backdrop.get_index() == 0,
		"one stage backdrop owns the battle view behind both lineups")
	if not is_instance_valid(backdrop):
		return
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop.focus_mode == Control.FOCUS_NONE,
		"battle backdrop never takes pointer or keyboard input")
	# Selection: exactly one authored scene per admitted route kind, none for anything else.
	_check(ROSTER_ART.backdrop_path("Fight") == BACKDROP_ART["Fight"]
		and ROSTER_ART.backdrop_path("Elite") == BACKDROP_ART["Elite"]
		and ROSTER_ART.backdrop_path("Boss") == BACKDROP_ART["Boss"],
		"each battle kind selects only its own authored backdrop")
	_check(ROSTER_ART.backdrop_path("Rest") == "" and ROSTER_ART.backdrop_path("") == ""
		and ROSTER_ART.backdrop_path("Unknown") == "" and ROSTER_ART.backdrop_path("fight") == "",
		"unknown or malformed battle kinds select no backdrop")
	_check(app.run_map == null and backdrop.battle_kind == "Fight",
		"standalone battle selects the normal Fight backdrop")
	_fight_areas(app, presenter, backdrop)
	var fight_path: String = BACKDROP_ART["Fight"]
	_check(backdrop.has_image() == ResourceLoader.exists(fight_path),
		"the mounted Fight image is shown only when the authored file is present")
	if backdrop.has_image():
		_check(backdrop.stage_texture.resource_path == fight_path,
			"the mounted Fight stage draws its own authored image")
	_ground_wash(presenter, backdrop, backdrop.has_image())
	_cover(app, presenter, backdrop)
	# The same stage is used by every admitted kind, so the authored Elite and Boss scenes
	# take the same wash, frame and cover geometry when they are installed.
	for kind in ["Elite", "Boss"]:
		backdrop.bind_battle(kind, presenter.backdrop_texture(kind))
		_check(backdrop.battle_kind == kind
			and backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART[kind]),
			"the mounted stage admits the " + kind + " scene only when it is present")
		if backdrop.has_image():
			var typed_cover: Rect2 = backdrop.image_rect()
			_check(typed_cover.encloses(backdrop.view_rect())
				and is_equal_approx(typed_cover.size.x / typed_cover.size.y,
					backdrop.texture_size().x / backdrop.texture_size().y),
				"the " + kind + " scene keeps its cover-crop geometry on the live stage")
		_ground_wash(presenter, backdrop, backdrop.has_image())
	backdrop.bind_battle("Fight", presenter.backdrop_texture("Fight"))
	_check(backdrop.battle_kind == "Fight",
		"the live battle restores its own Fight scene after the typed scene check")
	_fallback(app, presenter, backdrop)


## The stage is laid in under the actors: about one fifth of dark over whichever ground was
## painted, then a soft edge vignette. Both live in the backdrop's own draw pass, behind
## every actor, ribbon, badge and hand card, and never tint them.
func _ground_wash(presenter, backdrop, image_ground: bool) -> void:
	var ground: Rect2 = backdrop.view_rect() if image_ground else backdrop.quilt_cloth()
	_check(ground.size.x > 0.0 and ground.size.y > 0.0
		and backdrop.dim_rect().is_equal_approx(ground),
		"the whole painted ground, not one actor box, receives the dim wash")
	var wash: Color = backdrop.dim_color()
	_check(is_equal_approx(wash.a, 0.2) and wash.r < 0.2 and wash.g < 0.2 and wash.b < 0.2,
		"both the authored scene and the drawn quilt fallback are dimmed by about one fifth")
	var bands: Array[Rect2] = backdrop.vignette_rects()
	_check(bands.size() == presenter.STAGE_VIGNETTE_STEPS * 4,
		"the vignette builds one soft band per edge step")
	var area: Rect2 = ground.grow(0.01)
	for band in bands:
		_check(band.size.x > 0.0 and band.size.y > 0.0 and area.encloses(band),
			"every vignette band stays inside the dimmed ground")
	_check(backdrop.vignette_alpha(0) > backdrop.vignette_alpha(presenter.STAGE_VIGNETTE_STEPS - 1)
		and backdrop.vignette_alpha(presenter.STAGE_VIGNETTE_STEPS - 1) > 0.0,
		"the vignette is darkest at the rim and still fades softly toward the middle")
	var center: Vector2 = ground.get_center()
	var covers_center := false
	for band in bands:
		if band.has_point(center):
			covers_center = true
	_check(not covers_center, "vignette bands leave the middle of the stage clear for the actors")
	_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and backdrop.focus_mode == Control.FOCUS_NONE and backdrop.get_index() == 0,
		"the wash and vignette live in the input-inert stage behind every battle control")


## Cover geometry: one image fills the whole battle view without stretching, and the
## source it crops is only the centred window that window can show.
func _cover(app, presenter, backdrop) -> void:
	var view: Rect2 = backdrop.view_rect()
	var global_view := Rect2(backdrop.get_global_rect().position + view.position, view.size)
	_check(view.size.x > 0.0 and view.size.y > 0.0
		and global_view.is_equal_approx(app.battle_view.get_global_rect()),
		"the backdrop fills the whole battle view, not one actor box")
	_check(Rect2(0, 0, 1280, 720).is_equal_approx(global_view),
		"the battle view fills the 1280x720 screen edge to edge")
	for control in [app.hero_view, presenter.panel, app.hand_view, app.end_turn_button]:
		_check(global_view.encloses(control.get_global_rect()),
			"one stage image spans lineups, meters, hand and actions: " + control.name)
	var column: Node = app.hand_view
	while column.get_parent() != app.battle_view:
		column = column.get_parent()
	_check(backdrop.get_index() == 0 and column.get_index() > 0,
		"the stage is drawn before every battle control and the free hand")
	var meters = app.get_node_or_null("LiveCombatMeters")
	_check(column.get_index() > backdrop.get_index() and column.is_ancestor_of(app.hero_view)
		and is_instance_valid(meters) and is_instance_valid(meters.row)
		and global_view.encloses(meters.row.get_global_rect())
		and global_view.encloses(presenter._badges[0].get_global_rect()),
		"actor targets, HP ribbons and intent badges all draw above the same one stage")
	# Pure cover math, independent of whether the authored files are installed.
	var square_view := Rect2(0, 0, 1280, 720)
	var square_cover: Rect2 = ROSTER_ART.cover_rect(square_view, Vector2(1000, 1000))
	var square_crop: Rect2 = ROSTER_ART.crop_rect(square_view, Vector2(1000, 1000))
	_check(square_cover.encloses(square_view)
		and is_equal_approx(square_cover.size.x / square_cover.size.y, 1.0),
		"cover math fills the view without stretching a square image")
	_check(square_crop.size.x <= 1000.0 and square_crop.size.y <= 1000.0
		and square_crop.position.x >= 0.0 and square_crop.position.y >= 0.0
		and square_crop.end.x <= 1000.01 and square_crop.end.y <= 1000.01
		and is_equal_approx(square_crop.size.x / square_crop.size.y, 1280.0 / 720.0),
		"cover crops only a centred window that keeps the view's proportions")
	var wide_cover: Rect2 = ROSTER_ART.cover_rect(square_view, Vector2(2000, 500))
	var wide_crop: Rect2 = ROSTER_ART.crop_rect(square_view, Vector2(2000, 500))
	_check(wide_cover.encloses(square_view)
		and is_equal_approx(wide_cover.size.x / wide_cover.size.y, 4.0)
		and wide_crop.size.x <= 2000.01 and wide_crop.size.y <= 500.01
		and wide_crop.end.x <= 2000.01 and wide_crop.end.y <= 500.01,
		"a wide image also covers the view by cropping instead of distorting")
	_check(ROSTER_ART.cover_rect(Rect2(), Vector2(10, 10)) == Rect2()
		and ROSTER_ART.crop_rect(Rect2(0, 0, 10, 10), Vector2.ZERO) == Rect2(),
		"an empty view or texture draws no cover image")
	if not backdrop.has_image():
		return
	var texture_size: Vector2 = backdrop.texture_size()
	var drawn: Rect2 = backdrop.image_rect()
	var visible: Rect2 = backdrop.image_crop()
	_check(drawn.encloses(view) and is_equal_approx(drawn.size.x / drawn.size.y,
		texture_size.x / texture_size.y),
		"the mounted image covers the battle view at its own proportions")
	_check(visible.position.x >= 0.0 and visible.position.y >= 0.0
		and visible.end.x <= texture_size.x + 0.01 and visible.end.y <= texture_size.y + 0.01,
		"the mounted image crops inside its own texture")
	var scale: float = drawn.size.x / texture_size.x
	_check(is_equal_approx(visible.size.x * scale, view.size.x)
		and is_equal_approx(visible.size.y * scale, view.size.y),
		"the cropped window is drawn exactly over the whole battle view")
	var hem: Rect2 = backdrop.hem_rect()
	_check(hem.size.x > 0.0 and is_equal_approx(hem.size.y, presenter.STAGE_HEM_HEIGHT)
		and Rect2(0, 0, 1280, 720).encloses(
			Rect2(backdrop.get_global_rect().position + hem.position, hem.size)),
		"the quiet ground hem stays above the image inside 1280x720")


## Unknown kinds and missing files keep the complete drawn quilt and its sewn hem; the
## whole fallback is inspected on the real mounted stage and then restored.
func _fallback(app, presenter, backdrop) -> void:
	var before: Array = _snapshot(app)
	backdrop.bind_battle("Unknown", presenter.backdrop_texture("Unknown"))
	_check(not backdrop.has_image() and backdrop.image_rect() == Rect2()
		and backdrop.image_crop() == Rect2(),
		"an unknown battle kind leaves no image and no cover draw")
	_ground_wash(presenter, backdrop, false)
	_check(presenter.backdrop_texture("Unknown") == null and presenter.backdrop_texture("") == null
		and ROSTER_ART._load_art_texture("res://assets/paper/backgrounds/fabricated_missing.png") == null
		and ROSTER_ART._load_art_texture("") == null,
		"missing, fabricated or empty backdrop paths load nothing and cannot crash")
	var global_row: Rect2 = presenter.battle_row.get_global_rect()
	var row: Rect2 = Rect2(global_row.position - backdrop.get_global_rect().position, global_row.size)
	var cloth: Rect2 = backdrop.quilt_cloth()
	var patches: Array[Rect2] = backdrop.quilt_rects()
	var columns: int = presenter.STAGE_QUILT_COLUMNS.size() - 1
	var rows: int = presenter.STAGE_QUILT_ROWS.size() - 1
	_check(columns >= 2 and rows >= 1 and patches.size() == columns * rows,
		"the fallback is one continuous field of shared patches")
	_check(cloth.size.y > 0.0 and is_equal_approx(cloth.position.x, row.position.x)
		and is_equal_approx(cloth.size.x, row.size.x),
		"fallback cloth spans the whole actor row edge to edge")
	var covered := 0.0
	for index in range(patches.size()):
		var patch: Rect2 = patches[index]
		covered += patch.get_area()
		_check(patch.size.x > 0.0 and patch.size.y > 0.0 and cloth.encloses(patch),
			"fallback quilt patch is a real axis-aligned piece inside the cloth")
		if index % columns < columns - 1:
			var right: Rect2 = patches[index + 1]
			_check(is_equal_approx(patch.end.x, right.position.x)
				and is_equal_approx(patch.position.y, right.position.y)
				and is_equal_approx(patch.size.y, right.size.y),
				"neighbouring fallback patches share an unbroken vertical seam")
		if index + columns < patches.size():
			var below: Rect2 = patches[index + columns]
			_check(is_equal_approx(patch.end.y, below.position.y)
				and is_equal_approx(patch.position.x, below.position.x)
				and is_equal_approx(patch.size.x, below.size.x),
				"stacked fallback patches share an unbroken horizontal seam")
	_check(is_equal_approx(covered, cloth.get_area()),
		"fallback patches tile the cloth with no gap or overlap")
	var seams: Array[PackedVector2Array] = backdrop.quilt_seams()
	_check(seams.size() == maxi(0, columns - 1) + maxi(0, rows - 1),
		"every internal fallback patch edge is stitched exactly once")
	var stitched := cloth.grow(0.01)
	for seam in seams:
		_check(seam.size() == 2 and stitched.has_point(seam[0]) and stitched.has_point(seam[1]),
			"fallback quilt seam stays inside the continuous cloth")
	var hem: Rect2 = backdrop.hem_rect()
	_check(hem.size.x > 0.0 and is_equal_approx(hem.size.y, presenter.STAGE_HEM_HEIGHT)
		and is_equal_approx(cloth.end.y, hem.position.y)
		and is_equal_approx(hem.end.y, row.end.y),
		"exactly one stitched hem grounds the fallback quilt")
	_check(Rect2(0, 0, 1280, 720).encloses(
		Rect2(backdrop.get_global_rect().position + hem.position, hem.size)),
		"the fallback hem stays inside 1280x720")
	_check(_snapshot(app) == before,
		"backdrop selection, fallback and cover calculation change no combat state or RNG")
	# Source inspection: both branches exist and the quiet hem is drawn above either one.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var stage_source := source.substr(source.find("class StageBackdrop extends Control:"))
	var draw_body := stage_source.substr(stage_source.find("func _draw() -> void:"))
	draw_body = draw_body.left(draw_body.find("\n\tfunc "))
	_check(draw_body.find("_draw_backdrop_image()") >= 0
		and draw_body.find("_draw_quilt()") >= 0
		and draw_body.find("_draw_backdrop_image()") < draw_body.find("_draw_ground_hem()")
		and draw_body.find("_draw_quilt()") < draw_body.find("_draw_ground_hem()"),
		"source draws the stage scene or the fallback quilt first and the quiet hem above it")
	_check(source.contains("draw_texture_rect_region(stage_texture, view_rect(), image_crop())"),
		"source cover-draws the authored image into the whole battle view")
	_check(not source.contains("STAGE_PATCHES") and not source.contains("func _patch(")
		and source.contains("func quilt_rects()") and source.contains("func quilt_seams()")
		and source.contains("func _draw_ground_hem()"),
		"source keeps one quilt instead of tilted trapezoids and one shared hem")
	# Ordering: the painted ground is laid in before the hem, and the actor pass never
	# applies the stage wash, so only the backdrop is tinted.
	_check(draw_body.find("_draw_backdrop_image()") >= 0
		and draw_body.find("_draw_quilt()") >= 0
		and draw_body.find("_draw_dim()") > draw_body.find("_draw_backdrop_image()")
		and draw_body.find("_draw_dim()") > draw_body.find("_draw_quilt()")
		and draw_body.find("_draw_vignette()") > draw_body.find("_draw_dim()")
		and draw_body.find("_draw_ground_hem()") > draw_body.find("_draw_vignette()"),
		"source dims and vignettes the painted ground before the hem and every actor")
	var puppet_draw := _function_body(source, "func _draw() -> void:")
	_check(not puppet_draw.contains("_draw_dim") and not puppet_draw.contains("vignette"),
		"the actor draw pass never applies the stage wash or vignette to itself")
	backdrop.bind_battle("Fight", presenter.backdrop_texture("Fight"))
	_check(backdrop.battle_kind == "Fight"
		and backdrop.has_image() == ResourceLoader.exists(BACKDROP_ART["Fight"]),
		"the live battle restores its own backdrop after the fallback check")
	_ground_wash(presenter, backdrop, backdrop.has_image())


func _geometry(app, presenter) -> void:
	_check(is_instance_valid(presenter.battle_row), "horizontal battle wrapper exists")
	if not is_instance_valid(presenter.battle_row):
		return
	var left: Rect2 = app.hero_view.get_global_rect()
	var right: Rect2 = presenter.panel.get_global_rect()
	_check(app.hero_view.get_parent() == presenter.battle_row and
		presenter.panel.get_parent() == presenter.battle_row and
		presenter.battle_row.get_child_count() == 2,
		"same app-owned hero row and original enemy panel are the two sides")
	_check(left.end.x <= right.position.x and not left.intersects(right) and
		is_equal_approx(left.position.y, right.position.y), "heroes left and enemies right share one horizontal row")
	_check(app.hero_panels.size() == 3 and presenter._labels.size() == 2, "five original actor slots exist")
	var controls: Array[Control] = [app.hero_view, presenter.panel, app.hand_view,
		app.end_turn_button, app.return_button, app.pile_label]
	for index in range(app.hero_panels.size()):
		var slot: PanelContainer = app.hero_panels[index]
		_check(slot.get_parent() == app.hero_view and slot.get_index() == index and
			slot.get_child(0).text.begins_with("%d - %s" % [index + 1, app.party.get_hero(index + 1).name]),
			"hero slot retains authoritative ordered identity")
		controls.append(slot)
		_check(not slot.get_child(0).visible, "legacy hero HP/Block source is hidden, not duplicated")
	for label in presenter._labels:
		controls.append(label)
	for control in controls:
		var rect := control.get_global_rect()
		_check(control.is_visible_in_tree() and rect.size.x > 0 and rect.size.y > 0 and
			Rect2(0, 0, 1280, 720).encloses(rect), "bounded visible battle control: " + control.name)
		if control is Label:
			_check(control.get_minimum_size().x <= rect.size.x, "actor and intent text has readable width")
	for lower in [app.hand_view, app.end_turn_button, app.return_button]:
		_check(presenter.battle_row.get_global_rect().end.y <= lower.get_global_rect().position.y,
			"actor sides stay above usable hand and actions")


## Global measurements of the actual mounted draw and input geometry, including the
## rotated cards. A local foot constant alone cannot prove where the parent put it.
func _meadow_layout(app, presenter, near_meadow: bool = true) -> void:
	var viewport := Rect2(0, 0, 1280, 720)
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._puppets.size() == 3 + app.enemies.get_enemies().size()
		and is_instance_valid(meters) and meters.get_child_count() == presenter._puppets.size(),
		"global geometry has real actors and one authoritative ribbon per actor")
	if not is_instance_valid(meters) or presenter._puppets.is_empty():
		return
	var bottoms: Array[float] = []
	var regions: Array[Control] = [app.hand_view, app.pile_label.get_parent(),
		app.end_turn_button, app.action_corner, app.get_node("LiveSupportHand").energy_orb]
	for puppet in presenter._puppets:
		var art: Rect2 = puppet.get_global_transform() * puppet.rest_drawn_rect()
		var shadow: Rect2 = puppet.get_global_transform() * puppet.contact_shadow_rect()
		_check(art.has_area() and viewport.encloses(art) and viewport.encloses(shadow)
			and absf(art.end.y - shadow.get_center().y) <= shadow.size.y,
			"real art or fallback is grounded on its fixed global shadow: " + puppet.name)
		bottoms.append(art.end.y)
		if near_meadow:
			_check(art.end.y >= 395.0 and art.end.y <= 440.0,
				"mounted idle feet reach the near meadow: " + puppet.name + " at " + str(art.end.y))
		for badge in presenter._badges:
			_check(not art.intersects(badge.get_global_rect()), "intent tags never obscure actor artwork")
		for meter in meters.get_children():
			_check(not art.intersects(meter.get_global_rect()), "ribbons never obscure actor artwork")
	_check(bottoms.max() - bottoms.min() <= 0.02, "both live lineups share one measured screen foot line")
	for meter in meters.get_children():
		regions.append(meter)
	for label in [app.enemy_buff_forecast_label, app.combo_cue,
			app.get_node("LiveAttackPreview").cue]:
		if is_instance_valid(label) and label.is_visible_in_tree():
			regions.append(label)
	for index in range(regions.size()):
		var rect := regions[index].get_global_rect()
		_check(regions[index].is_visible_in_tree() and rect.has_area() and viewport.encloses(rect),
			"active lower control fits viewport: " + regions[index].name)
		for other in range(index):
			_check(not rect.intersects(regions[other].get_global_rect()),
				"separate readable regions: " + regions[index].name + "/" + regions[other].name)
	_check(app.hand_view.get_child_count() == app.deck.hand.size() and not app.deck.hand.is_empty(),
		"mounted hand geometry checks real held cards")
	for card in app.hand_view.get_children():
		_check(card.size.y >= 160.0, "every held face preserves the full stitched height")
		var bounds: Rect2 = card.get_global_transform() * Rect2(Vector2.ZERO, card.size)
		_check(viewport.encloses(bounds), "rotated held card fits viewport")
		for region in regions:
			if region != app.hand_view:
				_check(not bounds.intersects(region.get_global_rect()),
					"rotated card clears " + region.name)
	var table = app.get_node("LiveSupportHand").backing
	var column: Node = app.hero_view
	while column.get_parent() != app.battle_view:
		column = column.get_parent()
	_check(is_instance_valid(table) and table.get_index() < column.get_index(),
		"existing table stays behind all nested lower controls")


func _expanded_meadow_layout(scene: PackedScene) -> void:
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	for frame in range(6):
		await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_check(app.deck != null and app.deck.hand.size() == 5 and presenter._puppets.size() == 5,
		"expanded layout begins with a real five-card Fight and three heroes")
	if app.deck == null or presenter._puppets.size() != 5:
		app.free()
		return
	_meadow_layout(app, presenter)
	var host = presenter._puppets.back()
	var saved_id: String = host.actor_id
	var saved_art := {"idle": host.idle_texture, "attack": host.attack_texture}
	var ticket: LiveEnemyIntentBadge = presenter._badges.back()
	var binding_before := _snapshot(app)
	var target_before: Rect2 = presenter._labels.back().get_global_rect()
	var ticket_tops: Array[float] = []
	for actor_id in ["missing_layout_art", "needle_marshal", "spool_hexer", "patchwork_behemoth"]:
		host.bind_actor(actor_id, presenter.art_for(actor_id))
		_check((host.current_texture() == null) == (actor_id == "missing_layout_art"),
			"alternate mounted geometry really exercises missing art and Elite/Boss textures")
		presenter._place_intent_ticket(host, ticket)
		_ticket_at_rest(ticket)
		ticket_tops.append(ticket.position.y)
		_meadow_layout(app, presenter)
	_check(ticket_tops.max() - ticket_tops.min() > 1.0,
		"different resting Fight/Elite/Boss artwork seats tickets at different heights")
	host.bind_actor(saved_id, saved_art)
	presenter._place_intent_ticket(host, ticket)
	_check(_snapshot(app) == binding_before and presenter._labels.back().get_global_rect() == target_before,
		"art-bound ticket replacement preserves real combat, announcements, RNG and target region")
	# Source inspection: a seat is measured from resting artwork only, so a committed lunge,
	# a recoil, a fall or any other transient pose can never drag the ticket with it.
	var seat := _method_body(FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd"),
		"func _place_intent_ticket(")
	_check(seat.contains("rest_drawn_rect()") and seat.contains("clampf(")
		and seat.contains("badge.size =") and not seat.contains("posed_")
		and not seat.contains("pose_texture") and not seat.contains("idle_bob")
		and not seat.contains("create_tween") and not seat.contains("randi("),
		"tickets are seated from resting artwork inside their own source, never from a pose")
	root.size = Vector2i(1280, 760)
	for frame in range(6):
		await process_frame
	for badge in presenter._badges:
		_ticket_at_rest(badge)
	root.size = Vector2i(1280, 720)
	for frame in range(6):
		await process_frame
	for badge in presenter._badges:
		_ticket_at_rest(badge)
	_check(_snapshot(app) == binding_before and presenter._labels.back().get_global_rect() == target_before,
		"real viewport relayout restores targets and preserves combat and seeded RNG")
	for hero in app.party._heroes:
		hero["statuses"] = {"bleed": 2, "weak": 2, "exposed": 2}
		_check(app.party.gain_block(hero.position, 4), "expanded hero has real Block")
	for enemy in app.enemies.get_enemies():
		_check(app.enemies.apply_statuses({enemy.position: {"bleed": 2, "weak": 2, "exposed": 2}})
			and app.enemies.gain_block(enemy.position, 4), "expanded enemy has real Block and three statuses")
	var before := _snapshot(app)
	for frame in range(6):
		await process_frame
	_check(app.enemy_buff_forecast_label.is_visible_in_tree()
		== (not LiveEnemyBuffForecast.new().forecast(app.party, app.enemies,
			app.enemy_intents.get_intents()).is_empty()),
		"real enemy intent expands or clears the buff forecast exactly")
	if String(STARTER_ORACLE.guard_action(app.enemy_intents.get_intents()).get("type", "")) == "block":
		_check(app.enemy_buff_forecast_label.is_visible_in_tree()
			and not app.enemy_buff_forecast_label.text.is_empty(),
			"real Guard Block intent expands the buff forecast")
	var chips := 0
	for meter in app.get_node("LiveCombatMeters").row.get_children():
		for button in meter.find_child("StatusButtons", true, false).get_children():
			if button.is_visible_in_tree():
				chips += 1
	_check(chips == 15, "all five actors really display their three status controls")
	_meadow_layout(app, presenter)
	await _input_key(KEY_P)
	var cue = app.get_node("LiveAttackPreview").cue
	_check(is_instance_valid(cue) and cue.is_visible_in_tree() and not cue.text.is_empty(),
		"real keyboard hand selection mounts an expanded attack forecast")
	_meadow_layout(app, presenter, false)
	await _input_key(KEY_ESCAPE)
	_check(_snapshot(app) == before, "expanded layout and keyboard forecasts spend no resources or RNG")
	app.return_button.pressed.emit()
	await process_frame
	_fixture_start(app)
	for frame in range(6):
		await process_frame
	_meadow_layout(app, presenter)
	app.return_button.pressed.emit()
	app.free()


func _mouse_attack(app, reference, presenter) -> void:
	var chosen: Control
	var target := 0
	var card_id := ""
	for card in app.hand_view.get_children():
		var id: String = card.get_child(0).text
		var preview := CombatAttackTargeting.new().get_preview(app.deck, app.party, app.enemies, id)
		if preview.playable and preview.requires_selection and not preview.target_positions.is_empty():
			chosen = card
			target = preview.target_positions.back()
			card_id = id
			break
	_check(chosen != null and target > 0, "real seeded hand supplies a playable targeted attack")
	if chosen == null or target == 0:
		return
	var owner: String = StarterCards.new().get_definition(card_id).get("owner", "")
	var target_id: String = app.enemies.get_enemy(target)["id"]
	_check(presenter.focus_hit(owner, target_id, false), "input test starts focus on actual mounted actors")
	presenter.backdrop.advance_focus(0.15)
	_check(is_equal_approx(presenter.backdrop.focus_zoom(), 1.30), "mouse targeting runs during full stage focus")
	var before := _snapshot(app)
	await _input_mouse(chosen)
	_check(_snapshot(app) == before, "mouse card selection alone changes no combat state")
	await _input_mouse(presenter._labels[target - 1])
	var result := CombatAttackCards.new().play_attack(reference.deck, reference.party, reference.enemies, card_id, target)
	_check(result.ok and _snapshot(app) != before, "mouse enemy selection commits a real attack")
	_check(_snapshot(app) == _snapshot(reference), "mouse attack preserves complete reference HP/Block, piles, energy and RNG")


## Exercise the actual app-mounted puppet plaques; the test only seeds CombatEnemies
## records and never substitutes a mocked presenter or changes any status rules.
func _status_ribbons(app, presenter) -> void:
	var originals: Array = _snapshot(app)
	var record: Dictionary = app.enemies.get_enemy(1)
	_check(record.get("hp", 0) > 0 and record.get("position") == 1
		and presenter.enemies == app.enemies and presenter._status_tags.size() == 2,
		"status coverage starts with a living authoritative enemy and two mounted plaques")
	if record.get("hp", 0) <= 0 or presenter._status_tags.size() != 2:
		return
	var plaque: PanelContainer = presenter._status_tags[0]
	var other: PanelContainer = presenter._status_tags[1]
	_check(plaque.get_parent() == presenter._puppets[3]
		and plaque.name == "EnemyStatuses1" and other.name == "EnemyStatuses2"
		and not plaque.visible and not other.visible,
		"empty statuses mount one hidden plaque per actual enemy puppet")
	var source: Dictionary = app.enemies._enemies[0]
	source["statuses"] = {"bleed": 2, "weak": 3, "exposed": 4, "tangled": 5, "riposte": 7}
	var before: Array = _snapshot(app)
	presenter._refresh()
	var face := plaque.get_node("Caption") as Label
	var lines: String = face.text
	var help: String = plaque.tooltip_text
	for entry in ["Bleed 2", "Weak 3", "Exposed 4", "Tangled 5", "Riposte 7"]:
		_check(lines.contains(entry) and help.contains(entry),
			"mounted enemy plaque visibly names and explains exactly " + entry)
	_check(plaque.is_visible_in_tree() and not other.visible
		and plaque.get_parent() == presenter._puppets[3]
		and presenter._thorns_tags[0].name == "EnemyThorns1",
		"all five statuses belong to source one and stay separate from Thorns")
	for meaning in ["Bleed 2: deals 2 direct HP loss at owner-turn end", "decreases by 1",
			"outgoing attack damage is reduced by 25%",
			"incoming attack damage increases by 50%",
			"cannot move or be moved by its own side", "adds +2",
			"positive base damage", "Riposte 7: returns 7 counterdamage on each confirmed hit",
			"expires at this owner's turn end", "7 is damage, not turn duration"]:
		_check(help.contains(meaning), "mounted hover explains shipped rule: " + meaning)
	_check(plaque.mouse_filter == Control.MOUSE_FILTER_PASS
		and plaque.focus_mode == Control.FOCUS_NONE
		and face.mouse_filter == Control.MOUSE_FILTER_IGNORE
		and face.focus_mode == Control.FOCUS_NONE,
		"status plaque allows nonblocking hover and takes no keyboard focus")
	var viewport := Rect2(0, 0, 1280, 720)
	var face_rect := plaque.get_global_rect()
	var tag_rect: Rect2 = presenter._labels[0].get_global_rect()
	var art_band: Rect2 = presenter._puppets[3].art_band()
	var art_rect: Rect2 = presenter._puppets[3].get_global_transform() * presenter._puppets[3].rest_drawn_rect()
	_check(not face_rect.intersects(art_rect), "status plaque clears its puppet artwork")
	_check(viewport.encloses(face_rect) and face_rect.has_area()
		and face_rect.size.x <= art_band.size.x and face_rect.size.y <= art_band.size.y
		and not face_rect.intersects(presenter._badges[0].get_global_rect())
		and not face_rect.intersects(presenter._thorns_tags[0].get_global_rect())
		and not face_rect.intersects(Rect2(tag_rect.position + presenter._puppets[3].tag_band().position,
			presenter._puppets[3].tag_band().size)),
		"stitched status plaque is bounded and clear of its intent, Thorns and name hem")
	# The shipped Thorns hazard stays separately tagged when statuses are also active.
	source["thorns"] = 4
	presenter._refresh()
	var thorns: PanelContainer = presenter._thorns_tags[0]
	_check(thorns.visible and (thorns.get_node("Caption") as Button).text == "Thorns 4"
		and plaque.visible and not plaque.get_global_rect().intersects(thorns.get_global_rect())
		and not plaque.get_global_rect().intersects(art_rect),
		"simultaneous Thorns and status plaques stay separate from each other and the art")
	source.erase("thorns")
	presenter._refresh()
	for repeat in range(4):
		presenter._refresh()
	_check(_snapshot(app) == before and face.text == lines and plaque.tooltip_text == help,
		"repeated live reads leave deck, party, enemy, intents and RNG unchanged")
	await _input_mouse(plaque)
	_check(_snapshot(app) == before,
		"pointer over a status plaque cannot spend a card, move a target or mutate combat")
	source["statuses"] = {"bleed": 0, "weak": 1, "exposed": 0, "tangled": 2,
		"riposte": 0, "unrecognized": 9, "extra": -4}
	presenter._refresh()
	_check(plaque.visible and face.text.contains("Weak 1") and face.text.contains("Tangled 2")
		and not face.text.contains("Bleed") and not face.text.contains("Exposed")
		and not face.text.contains("Riposte") and not face.text.contains("unrecognized")
		and not plaque.tooltip_text.contains("Riposte"),
		"live positive-to-zero expiry and unknown keys disappear without invented cues")
	for bad in [null, 3, "bleed", {"bleed": 0, "weak": -1,
			"tangled": 1.5, "exposed": "2", "riposte": true, "strange": 4}]:
		source["statuses"] = bad
		presenter._refresh()
		_check(not plaque.visible and face.text.is_empty() and plaque.tooltip_text.is_empty(),
			"absent, non-dictionary and bad optional status metadata is silent")
	source.erase("statuses")
	presenter._refresh()
	_check(not plaque.visible and not other.visible,
		"removing optional statuses hides the whole status view")
	source["statuses"] = {"bleed": 3}
	presenter._refresh()
	_check(plaque.visible and face.text == "Bleed 3", "fresh value reappears immediately")
	_check(app.enemies.apply_damage(1, 999), "real CombatEnemies damage slays ribbon owner")
	presenter._refresh()
	_check(app.enemies.is_slain(1) and not plaque.visible and face.text.is_empty()
		and plaque.tooltip_text.is_empty(), "slain source removes its status immediately")
	# Restore the authentic fight before the fixture's deterministic reference trace.
	source["hp"] = record["hp"]
	source.erase("statuses")
	_check(_snapshot(app) == originals, "test restores unchanged authoritative battle after its status cases")
	var old_id: int = plaque.get_instance_id()
	presenter._clear()
	_check(presenter._status_tags.is_empty(), "battle teardown detaches every status control")
	presenter._sync_battle()
	await process_frame
	_check(not is_instance_id_valid(old_id) and presenter._status_tags.size() == 2
		and not presenter._status_tags[0].visible and not presenter._status_tags[1].visible
		and presenter.panel.find_children("EnemyStatuses*", "PanelContainer", true, false).size() == 2
		and _snapshot(app) == originals,
		"fresh battle mount owns one clean plaque per slot, with no stale labels or game mutation")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene := load("res://scenes/app.tscn") as PackedScene
	_check(scene != null, "real app scene loads")
	if scene == null:
		_finish()
		return
	var app = scene.instantiate()
	var reference = scene.instantiate()
	var reference_presenter = reference.get_node("LiveEnemyRoster")
	reference.remove_child(reference_presenter)
	reference_presenter.free()
	root.add_child(reference)
	root.add_child(app)
	await process_frame
	var presenter = app.get_node_or_null("LiveEnemyRoster")
	_check(presenter != null and is_instance_valid(app.start_button), "scene presenter and real Start Run exist")
	if presenter == null or not is_instance_valid(app.start_button):
		app.free()
		reference.free()
		_finish()
		return
	_check(app.start_button.is_visible_in_tree() and not app.start_button.disabled and
		presenter.enemies == null and presenter.panel == null, "title is actionable without premature roster")
	var first_trace: Array = []
	for session in range(2):
		_fixture_start(app)
		_fixture_start(reference)
		await process_frame
		await process_frame
		_check(app.deck is CombatDeck and app.party is CombatParty and app.run_rng != null,
			"real Start Run constructs deck, party and RNG")
		if app.deck == null or app.party == null or app.run_rng == null:
			break
		if "--inject-missing-control" in OS.get_cmdline_user_args():
			presenter.panel.free()
		if "--inject-wrong-value" in OS.get_cmdline_user_args():
			presenter.enemies.apply_damage(1, 1)
		_visible(app, presenter)
		if not failures.is_empty():
			app.free()
			reference.free()
			_finish()
			return
		if session == 0:
			await _status_ribbons(app, presenter)
			_idle_strip_safety(app, presenter)
			_v3_hero_fallbacks(app, presenter)
			_caption_legibility(app, presenter)
		var tick_phase: float = presenter._puppets[0].idle_phase
		await process_frame
		await process_frame
		_check(presenter._puppets[0].idle_phase > tick_phase,
			"mounted idle loop advances from the real frame delta of its own actor")
		var heroes = app.hero_view
		var hero_slots: Array = app.hero_panels.duplicate()
		var original_parent = presenter._hero_parent
		var old_row_id: int = presenter.battle_row.get_instance_id()
		var old_panel_id: int = presenter.panel.get_instance_id()
		var old_puppet_ids: Array[int] = []
		for puppet in presenter._puppets:
			old_puppet_ids.append(puppet.get_instance_id())
		presenter._clear()
		_check(is_instance_valid(heroes) and heroes.get_parent() == original_parent and
			app.hero_panels == hero_slots, "explicit clear restores same app-owned heroes and slots")
		_check(presenter._puppets.is_empty(), "clear releases every animated puppet")
		presenter._sync_battle()
		_check(_at_rest(presenter._puppets),
			"a fresh mount builds new puppets whose idle phase starts at rest")
		await process_frame
		await process_frame
		var stale_puppets := 0
		for id in old_puppet_ids:
			if is_instance_id_valid(id):
				stale_puppets += 1
		_check(stale_puppets == 0, "remount leaves no stale animated puppet behind")
		_check(not is_instance_id_valid(old_row_id) and not is_instance_id_valid(old_panel_id),
			"clear/remount frees temporary wrapper and panel")
		_check(app.hero_view == heroes and app.hero_panels == hero_slots, "remount retains hero node identities")
		_geometry(app, presenter)
		var state_before_repair := _snapshot(app)
		presenter.panel.free()
		presenter._refresh()
		presenter._sync_battle()
		await process_frame
		await process_frame
		_check(app.hero_view == heroes and app.hero_panels == hero_slots and
			_snapshot(app) == state_before_repair, "destroyed enemy panel remount preserves app heroes and full combat state")
		_geometry(app, presenter)
		var roster_ref: WeakRef = weakref(presenter.enemies)
		var row_id: int = presenter.battle_row.get_instance_id()
		var panel_id: int = presenter.panel.get_instance_id() if is_instance_valid(presenter.panel) else 0
		var backdrop_id: int = presenter.backdrop.get_instance_id() if is_instance_valid(presenter.backdrop) else 0
		var before := _snapshot(app)
		var puppet_ids: Array[int] = []
		for puppet in presenter._puppets:
			puppet_ids.append(puppet.get_instance_id())
		_fixture_start(app)
		await process_frame
		_check(presenter.enemies == roster_ref.get_ref() and is_instance_valid(presenter.panel) and
			presenter.panel.get_instance_id() == panel_id, "duplicate Start Run retains same roster and panel")
		var same_puppets: bool = presenter._puppets.size() == puppet_ids.size()
		for index in range(mini(presenter._puppets.size(), puppet_ids.size())):
			same_puppets = same_puppets and presenter._puppets[index].get_instance_id() == puppet_ids[index]
		_check(same_puppets and presenter._puppets.size() == CombatParty.PARTY_SIZE + presenter.enemies.get_enemies().size(),
			"duplicate Start Run keeps one animated puppet per actual actor, with no duplicate")
		_check(app.battle_view.find_children("EnemyRosterPanel", "PanelContainer", true, false).size() == 1,
			"exactly one presenter panel per battle")
		_check(presenter._badges.size() == 2, "duplicate Start Run cannot add intent badges")
		_check(presenter._status_tags.size() == 2 and not presenter._status_tags[0].visible,
			"duplicate Start Run cannot add or resurrect status plaques")
		_check(backdrop_id != 0 and is_instance_valid(presenter.backdrop)
			and presenter.backdrop.get_instance_id() == backdrop_id
			and app.battle_view.find_children("BattleStageBackdrop", "Control", true, false).size() == 1,
			"duplicate Start Run retains exactly one battle backdrop")
		_check(presenter.battle_row.get_instance_id() == row_id and
			app.battle_view.find_children("BattleActorSides", "HBoxContainer", true, false).size() == 1,
			"duplicate Start retains exactly one horizontal wrapper")
		_check(_snapshot(app) == before, "duplicate Start Run preserves all gameplay state")
		var trace: Array = []
		# Blocks the Guard really announced and kept; hero cards never damage the
		# roster in this presentation timeline.
		var guard_blocks := 0
		for turn in range(12):
			# Keep the long presentation/replay timeline alive after Ragling's +4 damage.
			_check(app.party.gain_block(1, 4) and reference.party.gain_block(1, 4),
				"both real parties receive identical mitigation for the stronger Ragling")
			_check(_snapshot(app) == _snapshot(reference), "presenter leaves hero/deck/energy/RNG trace intact")
			_check(presenter.enemies == app.enemies and app.enemies.get_enemies() == reference.enemies.get_enemies(),
				"observed roster matches battle without presenter")
			_check(app.enemies.get_enemy(1).hp == 12 and app.enemies.get_enemy(2).hp == 12
				and app.enemies.get_enemy(1).block == 0
				and app.enemies.get_enemy(2).block == guard_blocks,
				"only the announced enemy actions change the live roster")
			_assert_badges(app, presenter, _front_target(app))
			trace.append([_snapshot(app), presenter.enemies.get_enemies() if presenter.enemies != null else []])
			var announced_guard := STARTER_ORACLE.guard_action(app.enemy_intents.get_intents())
			if announced_guard.get("type") == "block":
				guard_blocks += int(announced_guard.get("amount", 0))
			_check(app.deck.try_spend_energy(2) and reference.deck.try_spend_energy(2), "real shared energy spend")
			if turn == 0:
				await _input_mouse(app.end_turn_button)
			elif turn == 1:
				app.end_turn_button.grab_focus()
				await _input_key(KEY_ENTER)
			else:
				app.end_turn_button.pressed.emit()
			reference.end_turn_button.pressed.emit()
			await process_frame
			_assert_badges(app, presenter, _front_target(app))
			_check(_snapshot(app) == _snapshot(reference),
				"real pointer/keyboard End Turn matches same exact reference state")
		await _mouse_attack(app, reference, presenter)
		_geometry(app, presenter)
		var announced_before_death: Array[Dictionary] = app.enemy_intents.get_intents()
		var guard_before_death: Dictionary = app.enemies.get_enemy(2)
		_check(app.enemies.apply_damage(1, 100), "real CombatEnemies.apply_damage slays only ragling")
		presenter._refresh()
		_check(app.enemies.is_slain(1) and not app.enemies.is_slain(2) and
			app.enemies.get_enemy(2) == guard_before_death and
			app.enemy_intents.get_intents() == announced_before_death,
			"slaying ragling leaves guard and the schedule intact")
		_assert_badges(app, presenter)
		var slain_puppets: Array = []
		for puppet in presenter._puppets:
			if puppet.facing < 0.0 and puppet.slot == 1:
				slain_puppets.append(puppet)
		_check(slain_puppets.size() == 1 and slain_puppets[0].fallen,
			"the slain ragling's own puppet reflects genuine fallen state")
		_fallen_stillness(slain_puppets)
		_check(app.enemies.apply_damage(2, 100), "final enemy damage exercises terminal layout")
		await process_frame
		await process_frame
		_check(app.battle_result.get_outcome() == CombatBattleResult.VICTORY and
			app.reward_buttons.size() == 4, "terminal geometry uses real victory and reward controls")
		_geometry(app, presenter)
		_assert_badges(app, presenter)
		if session == 0:
			first_trace = trace
		else:
			_check(trace == first_trace, "fresh same-seed session reproduces roster and full gameplay trace")
		reference.return_button.pressed.emit()
		app.return_button.pressed.emit()
		_check(presenter.enemies == null and presenter.panel == null and roster_ref.get_ref() == null and
			presenter._badges.is_empty() and presenter._status_tags.is_empty(),
			"Return immediately releases roster, panel, badges and statuses")
		_check(presenter._puppets.is_empty(), "Return removes every animated puppet with no surviving idle loop")
		await process_frame
		_check(not is_instance_id_valid(panel_id), "old panel freed")
		_check(not is_instance_id_valid(row_id) and not is_instance_valid(heroes) and
			presenter.battle_row == null, "Return frees old wrapper and app-owned battle with no orphan heroes")
		presenter._refresh()
		_check(presenter._badges.is_empty() and presenter.panel == null,
			"no-session refresh cannot resummon stale callbacks or badges")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "title and keyboard focus restored")
	await _bound_skip_badges(app, presenter)
	await _invalid_sources(app, reference, presenter)
	# A valid multi-entry source proves the whole list is parsed, without fixing catalog totals.
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify([{"id": "first", "name": "First", "max_hp": 3, "art_path": "unused",
		"intent": {"target": "front", "actions": [{"type": "attack", "amount": 1, "weight": 1}]}},
		{"id": "second", "name": "Second", "max_hp": 7, "art_path": "unused",
		"intent": {"target": "front", "actions": [{"type": "block", "amount": 1, "weight": 1}]}}]))
	file.close()
	app.starter_enemies_path = FIXTURE
	_fixture_start(app)
	await process_frame
	_check(presenter.enemies != null and presenter.enemies.get_enemy(2).get("id") == "second",
		"complete valid list creates later enemy")
	_check(is_instance_valid(presenter.panel) and presenter._labels.size() == 2 and
		presenter._badges.size() == 2 and
		presenter.panel.find_children("EnemyState*", "Label", true, false).size() == 2,
		"multi-entry fixture mounts both original labels and both drawn intent badges")
	_check(presenter.enemies.get_enemy(1).get("id") == "first"
		and presenter.enemies.get_enemy(2).get("id") == "second",
		"fabricated IDs are the authoritative actors of this mounted fixture")
	var fallback: Array = presenter._puppets.slice(3)
	_check(fallback.size() == 2, "fabricated-ID battle mounts one puppet per enemy")
	for index in range(fallback.size()):
		var puppet = fallback[index]
		_check(puppet.actor_id == presenter.enemies.get_enemy(index + 1).get("id")
			and puppet.idle_texture == null and puppet.attack_texture == null
			and puppet.image_rect() == Rect2(),
			"an unknown mounted actor ID falls back to the drawn puppet without textures")
	_assert_badges(app, presenter, 1, 1)
	_staging(app, presenter)
	_idle_motion(app, presenter, true)
	_attack_pose(app, presenter)
	_fall_settle(app, presenter)
	app.return_button.pressed.emit()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	await process_frame
	app.starter_enemies_path = SOURCE
	await _typed_stage(app, presenter)
	await _m05_fallbacks(app, presenter)
	await _expanded_meadow_layout(scene)
	await _mounted_plaque_reflow(scene)
	await _survival_ribbons(scene)
	await _four_capacity_ribbons(scene)
	await _mounted_fourth_wasp(scene)
	await _mounted_move_names(scene)
	for mode in [[3, 2], [3, 3], [4, 3], [4, 4]]:
		await _mounted_summon_help(scene, mode[0], mode[1])
	app.free()
	reference.free()
	_finish()


## Pending Unravel replaces only the readout, never the intent scheduler or
## input target. The original-slot authority is bound to this actual app flow.
func _bound_skip_badges(app, presenter) -> void:
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.round_flow != null and app.round_flow._started and app.enemies.get_enemies().size() == 2
		and presenter._badges.size() == 2, "mounted original enemy slots exist before Unravel intent exercise")
	if app.round_flow == null or presenter._badges.size() != 2:
		return
	var service := CombatUnravel.new()
	_check(service.bind_roster(app.enemies, {1: "normal", 2: "normal"}),
		"active battle service binds original positions, not presented names")
	app.round_flow._unravel = service
	var announced: Array[Dictionary] = app.enemy_intents.get_intents()
	var initial_state := _snapshot(app)
	presenter._refresh()
	_check(_snapshot(app) == initial_state and presenter._badges[0].icon_mode == "attack"
		and presenter._badges[1].icon_mode == String(
			STARTER_ORACLE.guard_action(announced).get("type", "")),
		"zero-gauge sourced original announcements keep their exact badge modes")
	_check(service.apply_unravel(app.enemies, 1, 3) and service.apply_unravel(app.enemies, 1, 5)
		and service.get_snapshot(1).skip_pending, "genuinely roster-bound threshold queues one pending skip")
	presenter._refresh()
	var badge = presenter._badges[0]
	_check(badge.readable_text == "UNRAVELLED" and badge.icon_mode == "unravelled"
		and badge.intent_type == "" and badge.amount == 0 and badge.target_position == 0,
		"scheduled attack/target is suppressed only in pending skip presentation")
	var guard_announced := STARTER_ORACLE.guard_action(announced)
	_check(presenter._badges[1].icon_mode == String(guard_announced.get("type", ""))
		and presenter._badges[1].intent_type == String(guard_announced.get("type", ""))
		and presenter._badges[1].amount == int(guard_announced.get("amount", 0))
		and not presenter._badges[1].readable_text.is_empty()
		and presenter._badges[1].readable_text != "NO ACTION",
		"unskipped second source retains its real authored intent")
	var pending_model := _snapshot(app)
	for step in range(5):
		presenter._refresh()
	_check(_snapshot(app) == pending_model and app.enemy_intents.get_intents() == announced
		and service.get_snapshot(1).skip_pending,
		"five UI reads cannot consume the pending skip, mutate intents, decks, HP or RNG")
	_check(badge.mouse_filter == Control.MOUSE_FILTER_PASS and badge.focus_mode == Control.FOCUS_NONE,
		"the Unravelled mark cannot steal mouse or keyboard target input")
	_check(badge.tooltip_text == "Unravelled: next action is skipped.",
		"unravelled badge tooltip explains next action is skipped")
	await _input_mouse(badge)
	_check(_snapshot(app) == pending_model and service.get_snapshot(1).skip_pending,
		"actual pointer clicking the skip badge cannot play a card or consume the skip")
	var foreign := CombatUnravel.new()
	_check(foreign.bind_roster(CombatEnemies.new(app.enemies.get_enemies()),
		{1: "elite", 2: "boss"}), "mismatched roster is genuinely independently bound")
	app.round_flow._unravel = foreign
	presenter._refresh()
	_check(badge.icon_mode == "attack" and badge.readable_text == "Hit 5: Front",
		"roster-mismatched pending authority falls back to unchanged scheduler intent")
	app.round_flow._unravel = null
	presenter._refresh()
	_check(badge.icon_mode == "attack" and badge.readable_text == "Hit 5: Front",
		"missing authority preserves ordinary attack instead of stale UNRAVELLED")
	app.round_flow._unravel = service
	presenter._refresh()
	_check(badge.icon_mode == "unravelled", "restoring exact roster authority restores skip cue")
	app.end_turn_button.pressed.emit()
	await process_frame
	await process_frame
	presenter._refresh()
	_check(not service.get_snapshot(1).skip_pending and service.get_snapshot(1).threshold == 12
		and badge.icon_mode == "attack" and badge.readable_text.begins_with("Hit ")
		and app.enemy_intents._turn_index == 1
		and app.enemy_attacks == app.enemy_intents.get_intents(),
		"real End Turn consumes pending original slot once and badge re-announces the scheduler")
	_check(app.enemies.apply_damage(1, 999) and app.enemies.is_slain(1),
		"slain slot is an actual CombatEnemies transaction")
	_check(service.apply_unravel(app.enemies, 1, 8) == false,
		"service cannot charge an already slain original enemy")
	presenter._refresh()
	_check(badge.icon_mode == "slain" and badge.readable_text == "SLAIN",
		"slain precedence overrides all pending/announced action marks")
	var badge_id: int = badge.get_instance_id()
	app.return_button.pressed.emit()
	await process_frame
	_check(not is_instance_id_valid(badge_id) and presenter._badges.is_empty()
		and presenter.panel == null, "Return destroys badge so a new fight cannot inherit skip")


func _three_enemy_fixture() -> Dictionary:
	for value in range(1, 1025):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		map.generate(rng)
		var opening_rng: int = rng.state
		for id in map.get_legal_choices():
			if map.get_node(id).get("type") != "Fight":
				continue
			rng.state = opening_rng
			if not map.choose_node(id):
				continue
			var selected := RunAuthoredBattleEntry.new().entry_current_battle(map, rng, RunFightEncounterSelection.new())
			map.undo_choice(id, [])
			if selected.get("success", false) and selected["enemies"].get_enemies().size() == 3:
				return {"seed": value, "fight": id, "encounter": selected["encounter_id"]}
	return {}


func _typed_stage(app, presenter) -> void:
	var fixture := _three_enemy_fixture()
	_check(not fixture.is_empty(), "live seeded Fight rotation includes an authentic three-enemy roster")
	if fixture.is_empty():
		return
	app.run_seed = fixture.seed
	app.start_button.pressed.emit()
	preload("res://tests/party_choice.gd").choose(app)
	await process_frame
	var route_button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == fixture.fight:
			route_button = candidate
			break
	_check(route_button != null and not route_button.disabled, "three-enemy Fight has a real enabled route control")
	if route_button == null:
		return
	route_button.pressed.emit()
	await process_frame
	await process_frame
	_check(app.enemies != null and app.enemies.get_enemies().size() == 3,
		"seeded production Fight exercises three typed enemies, not the standalone fixture")
	if app.enemies == null or app.enemies.get_enemies().size() != 3:
		return
	var route_kind: String = app.run_map.get_node(app.run_map.get_current_node_id()).get("type", "")
	var route_floor: int = int(app.run_map.get_node(app.run_map.get_current_node_id()).get("floor", 0))
	var stage_path: String = ROSTER_ART.stage_backdrop_path(route_kind, route_floor)
	_check(route_kind == "Fight" and is_instance_valid(presenter.backdrop)
		and presenter.backdrop.battle_kind == route_kind
		and stage_path == ROSTER_ART.fight_backdrop_path(route_floor)
		and presenter.backdrop.has_image() == ResourceLoader.exists(stage_path)
		and presenter.backdrop.stage_texture.resource_path == stage_path,
		"the seeded routed fight takes its backdrop from its real admitted floor")
	# The same one stage refreshes its scene when a new Fight is admitted on another
	# area floor, instead of comparing only the unchanged kind.
	var stage_id: int = presenter.backdrop.get_instance_id()
	var installed: Array[String] = []
	for floor_number in [4, 7, 10, 1]:
		app.run_map._nodes[app.run_map.get_current_node_id()].floor = floor_number
		presenter._sync_battle()
		var path: String = ROSTER_ART.fight_backdrop_path(floor_number)
		installed.append(path)
		_check(presenter.backdrop.get_instance_id() == stage_id
			and presenter.backdrop.battle_kind == "Fight"
			and presenter.backdrop.has_image() == ResourceLoader.exists(path)
			and presenter.backdrop.stage_texture.resource_path == path,
			"admitted floor %d refreshes the one Fight stage to its own area" % floor_number)
	app.run_map._nodes[app.run_map.get_current_node_id()].floor = route_floor
	presenter._sync_battle()
	_check(presenter.backdrop.get_instance_id() == stage_id
		and presenter.backdrop.stage_texture.resource_path == stage_path,
		"restoring the admitted floor returns the same stage to its own scene")
	_check(installed.size() == 4 and installed[0] != installed[1] and installed[1] != installed[2]
		and installed[2] != installed[3] and installed[3] == stage_path,
		"woods, marsh, peaks and its own meadow were really installed in turn")
	var before := _snapshot(app)
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._puppets.size() == 6 and presenter._labels.size() == 3
		and meters.get_child_count() == 6, "mounted typed path has every puppet, target and real meter")
	_assert_actor_art(app, presenter)
	_staging(app, presenter)
	_idle_motion(app, presenter)
	_attack_pose(app, presenter)
	_recoil(app, presenter)
	_fall_settle(app, presenter)
	var actions: Array = app.enemy_intents.get_intents()
	for index in range(3):
		var actor: Dictionary = app.enemies.get_enemy(index + 1)
		var badge = presenter._badges[index]
		var action: Dictionary = actions[index]
		_check(presenter._labels[index].text == String(actor.get("name", ""))
			and badge.source_position == actor.position and badge.intent_type == action.type
			and badge.amount == action.amount and badge.target_position == action.get("target_position", 0),
			"typed identity and complete authoritative intent survive mounted presentation")
		_check(Rect2(0, 0, 1280, 720).encloses(presenter._labels[index].get_global_rect())
			and _caption_fits(badge),
			"real typed name and short intent are readable inside the stage")
	# Exercise every distinct symbol and exact destination on a real mounted canvas.
	var badge = presenter._badges[0]
	for action in [{"type": "attack", "amount": 7, "target_position": 3},
		{"type": "block", "amount": 4}, {"type": "buff", "amount": 5},
		{"type": "debuff", "status": "exposed", "amount": 2, "target_position": 1},
		{"type": "shove", "amount": 0, "direction": -1, "target_position": 2}]:
		var original: Dictionary = action.duplicate(true)
		badge.show_intent(action, false)
		_check(badge.icon_mode == action.type and badge.intent_type == action.type
			and badge.amount == action.amount and badge.target_position == action.get("target_position", 0)
			and action == original, "all intent symbols preserve exact copied kind, amount and destination")
		_check(_caption_fits(badge),
			"each intent caption fits the three-enemy stage")
	presenter._refresh()
	_check(_snapshot(app) == before, "typed repeated refresh and every badge kind preserve all models and RNG")
	_policy_cue_cases(app, presenter)
	_check(app.party.apply_damage(1, 999) and app.enemies.apply_damage(2, 999), "typed fallen rendering has real downed and slain actors")
	presenter._refresh()
	_check(presenter._puppets[0].fallen and presenter._puppets[4].fallen
		and presenter._badges[1].icon_mode == "slain", "typed hero and enemy puppets reflect actual fallen state")
	_fallen_stillness([presenter._puppets[0], presenter._puppets[4]])
	_assert_actor_art(app, presenter)
	app.return_button.pressed.emit()
	await process_frame
	_check(presenter._puppets.is_empty() and presenter._badges.is_empty() and presenter.battle_row == null,
		"routed Return clears every typed puppet and badge")


## The authentic battle records of every catalog, read through the same production parser
## battles use. Never a test fixture and never the presenter's own resolution.
func _m05_records() -> Dictionary:
	var records := {}
	for path in RunAuthoredBattleEntry.CATALOG_PATHS:
		for record in RunTypedBattleRoster._parse_catalog_text(
				FileAccess.get_file_as_string(path)):
			records[String(record.get("id", ""))] = record
	return records


## Every production Fight alternative whose whole roster is an M05 normal.
func _m05_pairs(pool: Dictionary) -> Array:
	var pairs: Array = []
	var fight = pool.get("Fight")
	if not fight is Dictionary:
		return pairs
	for encounter_id in fight:
		var entry = fight[encounter_id]
		if not entry is Dictionary or not entry.get("enemy_ids") is Array:
			continue
		var ids: Array = entry["enemy_ids"]
		var all_m05 := not ids.is_empty()
		for actor_id in ids:
			all_m05 = all_m05 and M05_NORMALS.has(actor_id)
		if all_m05:
			pairs.append(ids)
	return pairs


## Find a real first-floor Fight whose independent shrinking-array draws actually
## admit the requested M05 actor; the named encounter only owns the schedule.
func _m05_pair_seed(pool: Dictionary, target_id: String) -> Dictionary:
	var fight = pool.get("Fight")
	if not fight is Dictionary or fight.is_empty():
		return {}
	var ids: Array = fight.keys()
	ids.sort()
	for seed_value in range(1, 701):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for node_id in map.get_legal_choices():
			if map.get_node(node_id).get("type") != "Fight" or not map.choose_node(node_id):
				continue
			var picked: String = ids[rng.randi_range(0, ids.size() - 1)]
			var entry = fight.get(picked)
			if not entry is Dictionary or not entry.get("enemy_ids") is Array:
				continue
			var group: Array = preload("res://tests/floor_band_oracle.gd").group(
				map.get_current_floor(), entry.enemy_ids.size(), rng)
			if group.has(target_id):
				return {"seed": seed_value, "node": node_id, "group": group,
					"encounter": picked, "selection_rng": rng.state}
	return {}


## Mount one band-selected Fight through real title, map and route controls,
## prove the selected M05 actor draws its own imported art without mutating play,
## then return to the title with the exact admitted roster IDs.
func _mount_m05_pair(app, presenter, pool: Dictionary, target_id: String) -> Array:
	var admitted: Array[String] = []
	var seed_info := _m05_pair_seed(pool, target_id)
	_check(not seed_info.is_empty(),
		"a seeded production Fight really draws M05 normal " + target_id)
	if seed_info.is_empty():
		return admitted
	app.run_seed = int(seed_info.seed)
	app.route_button.pressed.emit()
	await process_frame
	var route_button: Button = null
	for candidate in app.route_buttons:
		if candidate.get_meta("route_id") == seed_info.node:
			route_button = candidate
			break
	_check(route_button != null and not route_button.disabled,
		"the routed M05 Fight is reachable by its own map control " + target_id)
	if route_button == null:
		if is_instance_valid(app.route_back_button):
			app.route_back_button.pressed.emit()
			await process_frame
		return admitted
	route_button.pressed.emit()
	for frame in range(3):
		await process_frame
	if app.enemies != null:
		for enemy in app.enemies.get_enemies():
			admitted.append(String(enemy.get("id")))
	_check(admitted == seed_info.group and admitted.has(target_id)
		and app.encounter_id == seed_info.encounter and presenter.enemies == app.enemies
		and presenter._puppets.size() == CombatParty.PARTY_SIZE + admitted.size(),
		"the real routed Fight mounts the independent band-selected group with " + target_id)
	if admitted != seed_info.group or app.enemies == null or presenter.enemies != app.enemies:
		if app.deck != null:
			app.return_button.pressed.emit()
			await process_frame
		return admitted
	var before: Array = _snapshot(app)
	for index in range(admitted.size()):
		var actor_id: String = admitted[index]
		if not M05_NORMALS.has(actor_id):
			continue
		var expected: Dictionary = M05_NORMALS[actor_id]
		var actor: Dictionary = app.enemies.get_enemy(index + 1)
		var puppet = presenter._puppets[CombatParty.PARTY_SIZE + index]
		_check(actor.get("id") == actor_id and actor.get("position") == index + 1
			and actor.get("name") == expected.name and actor.get("max_hp") == expected.max_hp
			and actor.get("hp") == expected.max_hp and actor.get("block") == 0
			and actor.get("intent", {}).get("target") == expected.target,
			"the mounted M05 enemy keeps its authentic live record: " + actor_id)
		var expected_idle: String = IDLE_ART[actor_id]
		var expected_attack: String = expected_idle.trim_suffix(".png") + "_attack.png"
		var loaded: Dictionary = presenter.art_for(actor_id)
		_check(puppet.actor_id == actor_id and puppet.fallback_kind == actor_id
			and puppet.current_texture() is Texture2D and puppet.attack_texture is Texture2D
			and puppet.current_texture() == loaded.get("idle")
			and puppet.attack_texture == loaded.get("attack")
			and puppet.current_texture().resource_path == expected_idle
			and puppet.attack_texture.resource_path == expected_attack
			and puppet.image_rect().size.y > 0.0,
			"the mounted M05 enemy draws its own imported idle and stores its paired attack: " + actor_id)
		var idle_pose: Rect2 = puppet.posed_image_rect()
		_check(puppet.pose_texture() == puppet.current_texture()
			and puppet.trigger_attack(0.6) and puppet.attacking()
			and puppet.pose_texture() == puppet.attack_texture
			and puppet.pose_texture().resource_path == expected_attack,
			"the mounted M05 enemy selects only its matching attack PNG during a committed pose: " + actor_id)
		puppet._process(puppet.attack_span * 0.5)
		_check(puppet.posed_image_rect() != idle_pose and puppet.attack_lunge() * puppet.facing >= 4.0
			and absf(puppet.actor_rest_bottom() - puppet.foot_line()) <= 0.01,
			"the imported M05 attack lunges without moving its grounded rest feet: " + actor_id)
		puppet.cancel_attack()
		_check(puppet.pose_texture() == puppet.current_texture(),
			"the imported M05 enemy restores its own idle texture after the pose: " + actor_id)
		_check(presenter._labels[index].text == expected.name,
			"its pinned stage name is the authentic enemy name: " + actor_id)
		var shapes: Array = puppet.fallback_silhouettes()
		var inside := not shapes.is_empty()
		for part in shapes:
			var points := PackedVector2Array(part.get("points", PackedVector2Array()))
			inside = inside and points.size() >= 3
			for point in points:
				inside = inside and puppet.FALLBACK_EXTENTS.grow(0.01).has_point(point)
		_check(inside, "its sewn silhouette is real and stays inside the puppet's extents: " + actor_id)
		_check(puppet.actor_rest_bottom() >= puppet.art_band().position.y
			and puppet.contact_shadow_rect().size.x > 0.0
			and puppet.foot_line() < puppet.tag_band().position.y + 0.01,
			"the same foot line, contact shadow and pinned tag stay unchanged: " + actor_id)
	_check(presenter._puppets[CombatParty.PARTY_SIZE].fallback_silhouettes()
		!= presenter._puppets[CombatParty.PARTY_SIZE + 1].fallback_silhouettes(),
		"the two distinct band-selected actors keep distinct sewn silhouettes")
	# The identity fallback keeps the same bounded lunge, recoil and fall as any actor.
	var host = presenter._puppets[CombatParty.PARTY_SIZE + admitted.find(target_id)]
	# Explicit missing-art injection: exercise the named silhouette even though the
	# shipped routed Fight correctly mounts an imported Texture2D for this same ID.
	host.bind_actor(target_id, {})
	_check(host.current_texture() == null and host.attack_texture == null
		and host.fallback_kind == target_id and host.image_rect() == Rect2(),
		"forced-empty M05 art selects its identity-specific drawn fallback: " + target_id)
	var phase: float = host.idle_phase
	var rest: Rect2 = host.posed_fallback_rect()
	_check(host.trigger_attack(0.6) and host.attacking() and host.pose_texture() == null,
		"a fallback-only M05 actor still performs its committed lunge")
	host._process(host.attack_span * 0.5)
	_check(host.posed_fallback_rect() != rest and host.attack_lunge() * host.facing >= 4.0,
		"its lunge really moves the drawn artwork")
	host.cancel_attack()
	host.idle_phase = phase
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"a fallback-only M05 actor still recoils from a committed hit")
	host._process(host.recoil_span * 0.25)
	_check(absf(host.recoil_pixels()) >= 1.5,
		"its recoil really shakes the drawn artwork")
	host._process(host.RECOIL_MAX_SECONDS)
	host.idle_phase = phase
	var fallen: bool = host.fallen
	host.fallen = true
	_check(host.settle_fall(0.6) and host.settling_fall(),
		"a fallback-only M05 actor still eases into its fallen pose")
	host._process(host.FALL_MAX_SECONDS)
	_check(not host.settling_fall()
		and is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing),
		"its settled fall is the same still fallen tilt as every actor")
	host.fallen = fallen
	host._process(0.1)
	host.idle_phase = phase
	host.bind_actor(target_id, presenter.art_for(target_id))
	_check(host.current_texture() is Texture2D and host.attack_texture is Texture2D,
		"the routed M05 puppet restores both imported poses after forced fallback: " + target_id)
	presenter._refresh()
	_check(_snapshot(app) == before,
		"mounting and drawing M05 imported art and forced fallback changes no HP, deck, energy, intents or RNG")
	app.return_button.pressed.emit()
	await process_frame
	_check(presenter.enemies == null and presenter._puppets.is_empty(),
		"leaving the M05 battle releases its roster and every mounted puppet")
	return admitted


## The four authored M05 normals must mount their imported idle/attack image pairs in
## real routed Fights; each exact ID also retains its sewn silhouette when art is forced
## empty, and fabricated IDs keep the generic fallback. Presentation only.
## Take only legal connected Fight edges; no map graph, roster or run RNG is forged.
## A genuine route of connected Fights reaches the band where Felt Bulwark belongs.
func _next_fight_chain(map: RunMap, origin: String, remaining: int) -> Array:
	if remaining == 0:
		return []
	for node_id in map.get_node(origin).get("outgoing", []):
		if map.get_node(node_id).get("type") != "Fight":
			continue
		var tail: Array = _next_fight_chain(map, node_id, remaining - 1)
		if tail.size() == remaining - 1:
			return [node_id] + tail
	return []


func _band_m05_seed(first_seed: int, target_floor: int) -> Dictionary:
	if target_floor < 1:
		return {}
	for value in range(first_seed, 30000):
		var rng := RandomNumberGenerator.new()
		rng.seed = value
		var map := RunMap.new()
		if not map.generate(rng):
			continue
		for first in map.get_legal_choices():
			if map.get_node(first).get("type") != "Fight":
				continue
			var tail := _next_fight_chain(map, first, target_floor - 1)
			if tail.size() == target_floor - 1:
				return {"seed": value, "nodes": [first] + tail}
	return {}


## Felt Bulwark's own live floor band, read from the shared authored catalog
## split instead of pinning one floor: ordinary normals are a shared catalog, so
## another accepted enemy can legitimately move a record between bands.
func _felt_bulwark_floor() -> int:
	var oracle := preload("res://tests/floor_band_oracle.gd")
	for key in oracle.bands():
		if oracle.bands()[key].has("felt_bulwark"):
			return int(String(key).split("-")[0])
	return 0


## Drive real title, node controls, Fight wins and Skip/Continue until Felt
## Bulwark's own band floor, and check its imported poses on the actual mounted stage.
func _band_felt_bulwark(app, presenter, first_seed: int = 1, attempts: int = 0) -> void:
	var target_floor := _felt_bulwark_floor()
	_check(target_floor >= 1 and target_floor <= 11,
		"Felt Bulwark belongs to one legal normal floor band")
	if target_floor < 1:
		return
	var seed_info := _band_m05_seed(first_seed, target_floor)
	var found := false
	_check(not seed_info.is_empty() and seed_info.get("nodes", []).size() == target_floor,
		"a seed has %d genuinely connected Fight choices through floor %d" % [target_floor, target_floor])
	if seed_info.is_empty():
		return
	app.run_seed = int(seed_info.seed)
	app.route_button.pressed.emit()
	await process_frame
	var reached := true
	for floor_index in range(target_floor):
		var node_id: String = seed_info.nodes[floor_index]
		var route_control: Button = null
		for candidate in app.route_buttons:
			if candidate.get_meta("route_id", "") == node_id:
				route_control = candidate
				break
		_check(route_control != null and not route_control.disabled
			and app.run_map.get_legal_choices().has(node_id),
			"each connected Fight is a real mounted legal route action at floor %d" % (floor_index + 1))
		if route_control == null:
			reached = false
			break
		route_control.pressed.emit()
		for frame in range(3):
			await process_frame
		_check(app.enemies != null and app.run_map.get_current_floor() == floor_index + 1
			and app.encounter_id.length() > 0,
			"real Fight entry admits authoritative actors and typed schedule at floor %d" % (floor_index + 1))
		if app.enemies == null:
			reached = false
			break
		if floor_index == target_floor - 1:
			break
		# Victory fixture uses authentic CombatEnemies damage APIs, not an
		# injected Fight group, outcome or test-only selector.
		for enemy in app.enemies.get_enemies():
			_check(app.enemies.apply_damage(enemy.position, 9999),
				"living source is slain through the real combat actor model")
		app._observe_battle_result()
		await process_frame
		_check(app.reward_buttons.size() == 4
			and app.reward_buttons[3].is_visible_in_tree(),
			"real Fight victory exposes the actual Skip reward control")
		app.reward_buttons[3].pressed.emit()
		await process_frame
		app.continue_button.pressed.emit()
		await process_frame
	if reached and app.enemies != null and app.run_map.get_current_floor() == target_floor:
		var current_ids: Array = app.enemies.get_enemies().map(
			func(record): return record.id)
		var records: Dictionary = preload("res://tests/floor_band_oracle.gd").records()
		_check(preload("res://tests/floor_band_oracle.gd").legal_group(current_ids, target_floor),
			"floor-%d mounted actors are distinct members of the authored band" % target_floor)
		_check(current_ids.size() == app.enemy_intents._definitions.size()
			and presenter._puppets.size() == CombatParty.PARTY_SIZE + current_ids.size(),
			"floor-%d group preserves its independent typed encounter arity and mounted controls" % target_floor)
		# Test every actually selected actor's authentic record. Felt Bulwark
		# has its own imported poses on its actual mounted routed-Fight stage.
		for i in range(current_ids.size()):
			var record: Dictionary = app.enemies.get_enemy(i + 1)
			var authored: Dictionary = records[current_ids[i]]
			_check(record.id == authored.id and record.max_hp == int(
				RunNormalAttackFloorScaling.scale_normal_max_hp(int(authored.max_hp), target_floor).max_hp)
				and record.name == authored.name and record.position == i + 1
				and record.hp == int(RunNormalAttackFloorScaling.scale_normal_max_hp(
					int(authored.max_hp), target_floor).max_hp),
				"band actor keeps authenticated catalog stats and source slot: " + str(record) + " versus " + str(authored))
			if current_ids[i] == "felt_bulwark":
				var host = presenter._puppets[CombatParty.PARTY_SIZE + i]
				var before := _snapshot(app)
				var bulwark_idle: String = IDLE_ART["felt_bulwark"]
				var bulwark_attack: String = bulwark_idle.trim_suffix(".png") + "_attack.png"
				_check(host.actor_id == "felt_bulwark"
					and host.fallback_kind == "felt_bulwark"
					and host.current_texture() is Texture2D
					and host.attack_texture is Texture2D
					and host.current_texture().resource_path == bulwark_idle
					and host.attack_texture.resource_path == bulwark_attack
					and presenter._labels[i].text == authored.name
					and host.image_rect().size.y > 0.0
					and absf(host.actor_rest_bottom() - host.foot_line()) <= 0.01
					and host.contact_shadow_rect().size.x > 0.0,
					"genuinely mounted Felt Bulwark wears its imported idle, grounded feet and pinned label")
				_check(host.pose_texture() == host.current_texture()
					and host.trigger_attack(0.6) and host.attacking()
					and host.pose_texture() == host.attack_texture
					and host.pose_texture().resource_path == bulwark_attack,
					"genuinely mounted Felt Bulwark selects its matching attack sprite")
				host.cancel_attack()
				_check(host.pose_texture() == host.current_texture(),
					"Felt Bulwark returns to its own idle sprite after the committed pose")
				# The imported path has priority, but missing art still uses the same
				# named shape and bounded animations; restore the mounted art afterward.
				host.bind_actor("felt_bulwark", {})
				_check(host.current_texture() == null and host.attack_texture == null
					and not host.fallback_silhouettes().is_empty(),
					"forced missing Felt Bulwark art retains its sewn identity")
				_check(host.trigger_attack(0.6) and host.attacking()
					and host.pose_texture() == null,
					"Felt Bulwark's missing-art puppet keeps its bounded fallback attack")
				host.cancel_attack()
				_check(host.trigger_recoil(0.6) and host.recoiling(),
					"Felt Bulwark puppet keeps its bounded fallback recoil")
				host.cancel_recoil()
				var prior_fallen: bool = host.fallen
				host.fallen = true
				_check(host.settle_fall(0.6), "Felt Bulwark puppet keeps its bounded fall settle")
				host.cancel_fall()
				host.fallen = prior_fallen
				host.bind_actor("felt_bulwark", presenter.art_for("felt_bulwark"))
				_check(host.current_texture() is Texture2D and host.attack_texture is Texture2D,
					"Felt Bulwark's mounted art returns after the missing-art exercise")
				_check(_snapshot(app) == before,
					"Felt Bulwark sprite and fallback animation change no battle, deck or RNG state")
		found = current_ids.has("felt_bulwark")
	if app.deck != null:
		app.return_button.pressed.emit()
		await process_frame
	if not found:
		if attempts < 20:
			await _band_felt_bulwark(app, presenter, int(seed_info.seed) + 1, attempts + 1)
		else:
			_check(false, "bounded distinct seeded connected band Fights mount Felt Bulwark")
	else:
		_check(found, "authentic routed band group includes and mounts Felt Bulwark")


func _m05_fallbacks(app, presenter) -> void:
	var records := _m05_records()
	for actor_id in M05_NORMALS:
		var expected: Dictionary = M05_NORMALS[actor_id]
		_check(records.has(actor_id), "the authentic M05 normal exists in the catalogs: " + actor_id)
		if not records.has(actor_id):
			continue
		var record: Dictionary = records[actor_id]
		var intent: Dictionary = record.get("intent", {})
		var attack := {}
		for action in intent.get("actions", []):
			if action.get("type") == "attack":
				attack = action
		_check(record.get("name") == expected.name and record.get("max_hp") == expected.max_hp
			and record.get("art_path") == "res://assets/paper/enemies/%s.png" % actor_id,
			"the M05 normal keeps its exact authored name, HP and art path: " + actor_id)
		_check(intent.get("target") == expected.target
			and int(attack.get("amount", -1)) == int(expected.attack.amount)
			and int(attack.get("weight", -1)) == int(expected.attack.weight),
			"the M05 normal keeps its exact policy and weighted attack: " + actor_id)
		var idle_path: String = IDLE_ART[actor_id]
		var attack_path: String = idle_path.trim_suffix(".png") + "_attack.png"
		var paths: Dictionary = ROSTER_ART.art_paths(actor_id)
		var loaded: Dictionary = presenter.art_for(actor_id)
		_check(ROSTER_ART.fallback_kind_for(actor_id) == actor_id
			and paths.get("idle") == idle_path and paths.get("attack") == attack_path
			and ResourceLoader.exists(idle_path, "Texture2D")
			and ResourceLoader.exists(attack_path, "Texture2D")
			and loaded.get("idle") is Texture2D and loaded.get("attack") is Texture2D
			and loaded.idle.resource_path == idle_path
			and loaded.attack.resource_path == attack_path
			and loaded.idle != loaded.attack,
			"each M05 ID resolves two distinct imported Texture2D poses and retains its fallback kind: " + actor_id)
	# Live reachability: real seeded routed Fights really mount every M05 normal.
	var pool = JSON.parse_string(FileAccess.get_file_as_string(RunAuthoredBattleEntry.POOLS_PATH))
	_check(pool is Dictionary and pool.get("Fight") is Dictionary,
		"the production Fight pool parses for the live M05 fallback check")
	var mounted := {}
	if pool is Dictionary and pool.get("Fight") is Dictionary:
		_check(_m05_pairs(pool).size() >= 2,
			"both published M05 schedule aliases remain independently registered")
		for actor_id in M05_NORMALS:
			if not preload("res://tests/floor_band_oracle.gd").band_ids(1).has(actor_id):
				continue
			var admitted: Array = await _mount_m05_pair(app, presenter, pool, actor_id)
			if admitted.has(actor_id):
				mounted[actor_id] = true
	await _band_felt_bulwark(app, presenter)
	for actor_id in M05_NORMALS:
		if preload("res://tests/floor_band_oracle.gd").band_ids(1).has(actor_id):
			_check(mounted.has(actor_id),
				"the low-band M05 normal really appears in a genuine routed battle: " + actor_id)
	# One mounted slot, rebound through the real IDs and then a fabricated one.
	_fixture_start(app)
	await process_frame
	var host = presenter._puppets[0] if not presenter._puppets.is_empty() else null
	_check(host != null and presenter.enemies != null,
		"a real mounted battle supplies the slot for the M05 rebind")
	if host == null:
		return
	var before: Array = _snapshot(app)
	var saved_id: String = host.actor_id
	var saved_art := {"idle": host.idle_texture, "attack": host.attack_texture}
	var saved_phase: float = host.idle_phase
	var variants := {}
	for actor_id in M05_NORMALS:
		var loaded: Dictionary = presenter.art_for(actor_id)
		host.bind_actor(actor_id, loaded)
		_check(host.actor_id == actor_id and host.current_texture() is Texture2D
			and host.attack_texture is Texture2D
			and host.current_texture() == loaded.get("idle")
			and host.attack_texture == loaded.get("attack")
			and host.pose_texture() == host.current_texture(),
			"rebinding a mounted puppet to M05 ID loads only its distinct idle/attack pair: " + actor_id)
		_check(host.trigger_attack(0.6) and host.attacking()
			and host.pose_texture() == loaded.get("attack"),
			"rebinding an M05 ID lets its committed pose use only its own attack sprite: " + actor_id)
		host.cancel_attack()
		host.bind_actor(actor_id, {})
		variants[actor_id] = host.fallback_silhouettes()
		_check(host.fallback_kind == actor_id and host.current_texture() == null
			and host.attack_texture == null and host.image_rect() == Rect2()
			and not variants[actor_id].is_empty(),
			"forcing empty art for M05 ID binds its own non-empty sewn silhouette: " + actor_id)
	var ids: Array = M05_NORMALS.keys()
	var distinct := true
	for left in range(ids.size()):
		for right in range(left + 1, ids.size()):
			distinct = distinct and variants[ids[left]] != variants[ids[right]]
	_check(distinct, "all four M05 fallbacks draw different silhouettes and props")
	# Identity, not slot position: the same ID in another slot draws the same variant.
	host.bind_actor("moth_scribe", {})
	var other = presenter._puppets[1]
	var other_id: String = other.actor_id
	var other_phase: float = other.idle_phase
	other.bind_actor("moth_scribe", {})
	_check(host.slot != other.slot and host.fallback_kind == other.fallback_kind
		and host.fallback_silhouettes() == other.fallback_silhouettes(),
		"the same M05 ID keeps its variant in any stage slot")
	other.bind_actor(other_id, presenter.art_for(other_id))
	other.idle_phase = other_phase
	# Rebind two real IDs in one slot, then a fabricated one.
	host.bind_actor("felt_bulwark", {})
	var first_shapes: Array = host.fallback_silhouettes()
	host.bind_actor("thread_biter", {})
	var second_shapes: Array = host.fallback_silhouettes()
	_check(host.fallback_kind == "thread_biter" and second_shapes != first_shapes,
		"rebinding one slot to another M05 normal draws a different variant")
	var fabricated := "fabricated_m05_fallback"
	host.bind_actor(fabricated, presenter.art_for(fabricated))
	_check(host.fallback_kind == ROSTER_ART.fallback_kind_for(fabricated)
		and host.fallback_kind != "felt_bulwark" and host.fallback_kind != "thread_biter"
		and host.fallback_silhouettes().is_empty() and host.current_texture() == null,
		"a fabricated ID keeps the original generic drawn fallback")
	# The bounded lunge, recoil and fall stay active on the identity-specific puppet.
	host.bind_actor("felt_bulwark", {})
	var rest: Rect2 = host.posed_fallback_rect()
	_check(host.trigger_attack(0.6) and host.attacking() and host.pose_texture() == null,
		"the M05 fallback puppet still performs a committed lunge")
	host._process(host.attack_span * 0.5)
	_check(host.attacking() and host.posed_fallback_rect() != rest,
		"the M05 fallback lunge really moves its drawn artwork")
	host.cancel_attack()
	host.idle_phase = saved_phase
	_check(host.trigger_recoil(0.6) and host.recoiling(),
		"the M05 fallback puppet still recoils from a committed hit")
	host._process(host.recoil_span * 0.25)
	_check(absf(host.recoil_pixels()) >= 1.5,
		"the M05 fallback recoil really shakes its drawn artwork")
	host._process(host.RECOIL_MAX_SECONDS)
	host.idle_phase = saved_phase
	host.fallen = true
	_check(host.settle_fall(0.6) and host.settling_fall(),
		"the M05 fallback puppet still eases into its fallen pose")
	host._process(host.FALL_MAX_SECONDS)
	_check(is_equal_approx(host.fallen_tilt(), -host.FALL_TILT * host.facing),
		"the M05 fallback settles exactly at the existing fallen tilt")
	host.fallen = false
	host._process(0.1)
	host.idle_phase = saved_phase
	# Rim and paint choose the one identity-specific shape list from the same entry point.
	var source := FileAccess.get_file_as_string("res://scripts/live_enemy_roster.gd")
	var shape_body := _function_body(source, "func _draw_fallback_shapes(")
	var named_body := _function_body(source, "func _draw_named_fallback_shapes(")
	var fallback_body := _function_body(source, "func _draw_fallback(")
	var rim_body := _function_body(source, "func _draw_silhouette(")
	_check(fallback_body.contains("_draw_fallback_shapes(false)")
		and rim_body.contains("_draw_fallback_shapes(true)")
		and shape_body.contains("_draw_named_fallback_shapes(silhouette)")
		and named_body.contains("fallback_silhouettes()") and named_body.contains("RIM_INK"),
		"the filled puppet and its dark rim draw the one identity-specific shape list")
	_check(shape_body.find("_draw_named_fallback_shapes(silhouette)")
		< shape_body.find("Color(\"ecdfbd\")"),
		"the identity dispatch precedes the generic body, so a named ID never mixes both")
	host.bind_actor(saved_id, saved_art)
	host.idle_phase = saved_phase
	_check(host.actor_id == saved_id
		and host.fallback_kind == ROSTER_ART.fallback_kind_for(saved_id)
		and host.current_texture() == saved_art.idle,
		"rebinding the slot restores the original actor exactly")
	_check(_snapshot(app) == before,
		"every M05 fallback rebind and pose changes no party, deck, energy, intents or RNG")
	app.return_button.pressed.emit()
	await process_frame


## Real mounted seeded fight, swapping only test fixture metadata to bind four
## fresh, deterministic authored policies to the same original enemy slots.
func _policy_cue_cases(app, presenter) -> void:
	var old_intents: CombatEnemyIntents = app.enemy_intents
	var flow: CombatRoundFlow = app.round_flow
	var old_unravel: CombatUnravel = flow._unravel
	var old_roster: Array[Dictionary] = app.enemies.get_enemies()
	var old_rng: int = app.run_rng.state
	var before: Array = _snapshot(app)
	_check(old_intents != null and old_intents.is_bound() and old_roster.size() == 3
		and presenter._badges.size() == 3 and flow._started
		and presenter._bound_unravel(app) != null,
		"seeded live-policy fixture has bound scheduler, original slots and gauge")
	if not old_intents.is_bound() or old_roster.size() != 3 or presenter._bound_unravel(app) == null:
		return
	var patterns: Array = old_intents._definitions.duplicate(true)
	var types := [
		{"type": "attack", "amount": 4},
		{"type": "debuff", "amount": 2, "status": "exposed"},
		{"type": "shove", "amount": 0, "direction": 1},
		{"type": "attack", "amount": 5},
	]
	for policy_index in range(CombatEnemyIntents.TARGET_POLICIES.size()):
		var policy: String = CombatEnemyIntents.TARGET_POLICIES[policy_index]
		var first: Dictionary = types[policy_index].duplicate(true)
		first["weight"] = 1
		var extras := [
			{"type": "block", "amount": 2, "weight": 1},
			{"type": "buff", "amount": 2, "weight": 1},
		]
		app.enemies._enemies[0]["intent"] = {"target": policy, "actions": [first]}
		for index in range(1, 3):
			app.enemies._enemies[index]["intent"] = {"target": "front", "actions": [extras[index - 1]]}
		var schedule := CombatEnemyIntents.new(patterns)
		_check(schedule.bind_battle(app.enemies, app.party, app.run_rng),
			"test-authored %s schedule binds to the actual mounted roster and run RNG" % policy)
		if not schedule.is_bound():
			continue
		app.enemy_intents = schedule
		flow._intents = schedule
		flow._battle_intents = schedule
		var cached: Array[Dictionary] = schedule.get_intents()
		var state: int = app.run_rng.state
		presenter._refresh()
		for position in range(1, 4):
			var badge = presenter._badges[position - 1]
			var action: Dictionary = cached[position - 1]
			var expected_policy := CombatEnemyIntents.policy_for(app.enemies, position)
			var target: int = action.get("target_position", 0)
			var original_caption := ""
			var compact_caption := ""
			var tight_caption := ""
			match action.type:
				"attack":
					original_caption = "Hit %d: %s" % [action.amount, {1: "Front", 2: "Middle", 3: "Back"}.get(target, "")]
					compact_caption = "Hit %d → %d" % [action.amount, target]
					tight_caption = "Hit %d→%d" % [action.amount, target]
				"block": original_caption = "Block +%d" % action.amount
				"buff": original_caption = "Buff +%d Block" % action.amount
				"debuff":
					original_caption = "%s %d: %s" % [action.status.capitalize(), action.amount, {1: "Front", 2: "Middle", 3: "Back"}[target]]
					compact_caption = "%s %d → %d" % [action.status.capitalize(), action.amount, target]
					tight_caption = "%s %d→%d" % [action.status.capitalize(), action.amount, target]
				"shove":
					original_caption = "Shove %s %s" % [{1: "Front", 2: "Middle", 3: "Back"}[target], "back" if action.direction == 1 else "forward"]
					compact_caption = "Shove %d %s" % [target, "back" if action.direction == 1 else "forward"]
					tight_caption = "Shove %d %s" % [target, "back" if action.direction == 1 else "fwd"]
			var expected_cue: String = {"front": "Front", "lowest_living_hp": "Aim low HP", "exposed": "Exposed", "random": "Random"}.get(expected_policy, "") \
				if action.type in ["attack", "debuff", "shove"] else ""
			# The displayed compact form is the first one that measures inside the room left
			# beside the widened aiming ticket, measured here with the same body face at the
			# 14 px action floor; the tight form is the measured fallback.
			var expected_caption: String = original_caption if expected_cue.is_empty() \
				else _fitted_compact(badge, compact_caption, tight_caption)
			_check(badge.policy_cue == expected_cue and badge.readable_text == expected_caption
				and badge.intent_type == action.type and badge.amount == action.amount
				and badge.target_position == target and badge.source_position == position
				and _caption_fits(badge),
				"%s action preserves exact caption/target and policy_for original slot %d" % [policy, position])
			var policy_descs := {
				"front": "picks the front living hero",
				"lowest_living_hp": "aims at the living hero with the lowest current HP",
				"exposed": "prioritises an Exposed living hero",
				"random": "uses the run-seeded target choice"
			}
			if action.type in ["attack", "debuff", "shove"]:
				_check(badge.tooltip_text.contains(LiveEnemyIntentBadge.hero_target_label(target))
					and badge.tooltip_text.contains("Target policy (%s): %s." % [expected_cue.to_upper(), policy_descs[expected_policy]]),
					"targeted action tooltip explains target and policy for original slot %d" % position)
				if expected_policy == "lowest_living_hp":
					# AC1: the acting enemy is at full health here, so the aiming ticket can
					# only describe whom that enemy is going to hit: the living hero with the
					# lowest current HP, read independently from the real party.
					var acting: Dictionary = app.enemies.get_enemy(position)
					var lowest: int = 0
					for hero_position in range(1, CombatParty.PARTY_SIZE + 1):
						var hero: Dictionary = app.party.get_hero(hero_position)
						if hero.get("hp", 0) <= 0:
							continue
						if lowest == 0 or hero.get("hp", 0) < app.party.get_hero(lowest).get("hp", 0):
							lowest = hero_position
					_check(acting.get("hp") == acting.get("max_hp")
						and badge.policy_cue == "Aim low HP"
						and badge.tooltip_text.contains(
							"aims at the living hero with the lowest current HP")
						and target == lowest and lowest != 0,
						"full-health enemy shows Aim low HP for the lowest-current-HP hero, not its own health")
			else:
				_check(badge.tooltip_text.contains("Block on the acting enemy")
					and not badge.tooltip_text.contains("Target policy"),
					"block/buff action tooltip shows no policy for original slot %d" % position)
		for repeat in range(4):
			presenter._refresh()
		_check(schedule.get_intents() == cached and app.run_rng.state == state,
			"repeated policy read is cache/RNG-inert for %s" % policy)
		if policy_index == 0:
			var skip := CombatUnravel.new()
			_check(skip.bind_roster(app.enemies, {1: "normal", 2: "normal", 3: "normal"})
				and skip.apply_unravel(app.enemies, 1, 8), "fixture binds an authentic pending skip")
			flow._unravel = skip
			presenter._refresh()
			_check(presenter._badges[0].policy_cue.is_empty()
				and presenter._badges[0].readable_text == "UNRAVELLED",
				"pending skip suppresses both real policy and action")
			_check(presenter._badges[0].tooltip_text == "Unravelled: next action is skipped.",
				"pending skip tooltip suppresses policy and previous action")
			flow._unravel = old_unravel
			presenter._refresh()
			_check(presenter._badges[0].policy_cue == "Front", "cleared skip restores authored policy")
			_check(app.enemies.apply_damage(1, 999), "test fixture slays actual original enemy")
			presenter._refresh()
			_check(presenter._badges[0].policy_cue.is_empty()
				and presenter._badges[0].readable_text == "SLAIN",
				"slain cue overrides bound policy")
			_check(presenter._badges[0].tooltip_text == "Slain: no action.",
				"slain tooltip overrides bound policy")
			app.enemies._enemies.assign(old_roster.duplicate(true))
			app.enemies._enemies[0]["intent"] = {"target": "front", "actions": [first]}
			presenter._refresh()
			_check(presenter._badges[0].policy_cue == "Front", "restored living source has cue")
			_check(presenter._badges[0].tooltip_text.contains("Target policy (FRONT)"),
				"restored living source restores policy in tooltip")
	# An unbound legacy schedule and a missing authority never invent a policy.
	var legacy := CombatEnemyIntents.new(patterns)
	app.enemy_intents = legacy
	flow._intents = legacy
	flow._battle_intents = legacy
	presenter._refresh()
	_check(presenter._badges[0].policy_cue.is_empty(), "unbound fixture has no target-policy cue")
	app.enemy_intents = null
	presenter._refresh()
	_check(presenter._badges[0].policy_cue.is_empty(), "missing scheduler cannot retain a stale cue")
	app.enemies._enemies.assign(old_roster.duplicate(true))
	app.enemy_intents = old_intents
	flow._intents = old_intents
	flow._battle_intents = old_intents
	flow._unravel = old_unravel
	app.run_rng.state = old_rng
	presenter._refresh()
	_check(_snapshot(app) == before and app.enemy_intents == old_intents,
		"policy fixture restores HP, Block, statuses, deck, energy, original cached schedule and RNG")


func _invalid_sources(app, reference, presenter) -> void:
	var valid := {"id": "valid", "name": "Valid", "max_hp": 12, "art_path": "unused"}
	var fixtures: Array[String] = ["{", "{}", "[]", "[null]", "[1]", "[{}]", JSON.stringify([valid, valid])]
	for field in valid:
		var missing := valid.duplicate()
		missing.erase(field)
		fixtures.append(JSON.stringify([valid, missing]))
	for hp in [null, true, "12", 0, -1, 0.5, 12.5, 1e30]:
		var bad := valid.duplicate()
		bad.id = "later"
		bad.max_hp = hp
		fixtures.append(JSON.stringify([valid, bad]))
	for id in [null, true, 1, ""]:
		var bad := valid.duplicate()
		bad.id = id
		fixtures.append(JSON.stringify([valid, bad]))
	fixtures.append(JSON.stringify([valid, {"id": "b", "max_hp": 1, "name": "B", "art_path": "unused"},
		{"id": "c", "max_hp": 1, "name": "C", "art_path": "unused"},
		{"id": "d", "max_hp": 1, "name": "D", "art_path": "unused"}]))
	# Missing path first, then malformed files, all through the actual player path.
	var paths: Array[String] = ["user://missing_roster_directory/enemies.json"]
	for fixture in fixtures:
		paths.append(FIXTURE)
	for index in range(paths.size()):
		if index > 0:
			var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
			_check(file != null, "external negative fixture opens")
			if file == null:
				continue
			file.store_string(fixtures[index - 1])
			file.close()
		app.starter_enemies_path = paths[index]
		_fixture_start(reference)
		app.start_button.grab_focus()
		_fixture_start(app)
		await process_frame
		await process_frame
		_check(app.deck == null and app.party == null and app.run_rng == null and app.enemies == null,
			"bad roster rejects every run object atomically")
		_check(presenter.enemies == null and presenter.panel == null and presenter._badges.is_empty() and
			app.battle_view == null and presenter.battle_row == null,
			"invalid complete source creates no partial roster, wrapper, panel or badges")
		presenter._refresh()
		_check(presenter._badges.is_empty() and presenter.panel == null,
			"failed Start has no stale cue callback")
		_check(app.title_view.is_visible_in_tree() and app.start_button.has_focus(), "invalid roster retains actionable title")
		app._end_turn()
		_check(app.deck == null and app.party == null and app.enemies == null, "invalid roster End Turn remains inert")
		# Correcting the source permits a fresh start, with no leaked state from rejection.
		app.starter_enemies_path = SOURCE
		_fixture_start(app)
		await process_frame
		await process_frame
		_check(app.deck != null and app.enemies != null and presenter.enemies == app.enemies,
			"corrected source starts complete shared model")
		if app.deck != null and app.enemies != null:
			_check(_snapshot(app) == _snapshot(reference), "rejected source cannot leak hero, enemy, deck, energy or RNG state")
			app.end_turn_button.pressed.emit()
			reference.end_turn_button.pressed.emit()
			_check(_snapshot(app) == _snapshot(reference), "corrected run End Turn matches clean reference")
		reference.return_button.pressed.emit()
		app.return_button.pressed.emit()
		_check(presenter.enemies == null and presenter.panel == null and presenter._badges.is_empty(),
			"invalid battle teardown also clears all intent cues")
		await process_frame


func _ticket_at_rest(badge: LiveEnemyIntentBadge) -> void:
	var puppet = badge.get_parent()
	_check(puppet is ROSTER_ART.Puppet and puppet.slot == badge.source_position,
		"ticket is mounted on its authoritative source puppet")
	if not puppet is ROSTER_ART.Puppet:
		return
	var art: Rect2 = puppet.rest_drawn_rect()
	var rect: Rect2 = badge.get_rect()
	var safety: float = puppet.art_safety_inset()
	var gap: float = art.position.y - rect.end.y
	var expected_gap: float = maxf(ROSTER_ART.INTENT_ART_CLEARANCE, safety)
	# Measured from the real mounted badge's bottom to its own resting art's top:
	# bob and breathing fit in a narrow 4-6px seam, without the old rim-sized lift.
	_check(gap >= safety - 0.05 and gap >= ROSTER_ART.INTENT_ART_CLEARANCE - 0.05
		and gap <= 6.0 and absf(gap - expected_gap) <= 0.05,
		"mounted intent has a small bob-safe seam directly above its own resting artwork")
	var slot_top: float = maxf(0.0, ROSTER_ART.STAGE_INTENT_SAFE_MARGIN - puppet.global_position.y)
	var expected_y: float = art.position.y - expected_gap - rect.size.y
	var centred: bool = is_equal_approx(rect.get_center().x, art.get_center().x)
	var flush: bool = is_equal_approx(rect.position.x, 0.0) \
		or is_equal_approx(rect.end.x, puppet.size.x)
	_check(badge.is_visible_in_tree() and art.has_area()
		and is_equal_approx(rect.position.y, expected_y)
		and rect.end.y <= art.position.y + 0.01
		and (centred or flush)
		and Rect2(Vector2.ZERO, puppet.size).grow(0.01).encloses(rect)
		and puppet.get_viewport_rect().encloses(badge.get_global_rect())
		and Rect2(Vector2.ZERO, badge.size).encloses(badge.patch_rect()),
		"complete sewn ticket sits above resting art within its source and viewport")


## Check the actual mounted rectangles, including the visible viewport intersection.
func _plaque_bounds(app, presenter) -> void:
	var meters = app.get_node("LiveCombatMeters").row
	_check(presenter._badges.size() == 2 and meters.get_child_count() == 5,
		"plaque geometry has two real enemies and their mounted HP meters")
	for index in range(2):
		var puppet = presenter._puppets[3 + index]
		var neighbor = presenter._puppets[4 - index]
		var slot: Rect2 = puppet.get_global_rect().intersection(puppet.get_viewport_rect())
		var name_rect: Rect2 = puppet.get_global_transform() * puppet.tag_band()
		var occupied: Array[Rect2] = []
		for plaque in [presenter._badges[index], presenter._thorns_tags[index], presenter._status_tags[index]]:
			if not plaque.is_visible_in_tree():
				continue
			var local: Rect2 = plaque.get_rect()
			var world: Rect2 = plaque.get_global_rect()
			_check(world.has_area() and slot.grow(0.01).encloses(world)
				and (puppet.get_global_transform() * local).is_equal_approx(world)
				and not world.intersects(neighbor.get_global_rect())
				and not world.intersects(puppet.get_global_transform() * puppet.rest_drawn_rect())
				and not world.intersects(name_rect)
				and not world.intersects(meters.get_child(3 + index).get_global_rect()),
				"visible plaque belongs to its current source in local/global space, clear of neighbor/name/HP")
			for previous in occupied:
				_check(not world.intersects(previous), "all visible source plaques are mutually separate")
			occupied.append(world)


func _mounted_plaque_reflow(scene: PackedScene) -> void:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/m04_elites.json"))
	var records: Array = []
	for id in ["spool_leech", "pincushion_matriarch"]:
		for record in catalog:
			if record.id == id:
				records.append(record)
	_check(records.size() == 2 and records[0].get("drain") == true
		and records[1].get("thorns", 0) > 0, "fixture loads genuine Drain and Thorns actors")
	if records.size() != 2:
		return
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	file.close()
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.starter_enemies_path = FIXTURE
	app.run_seed = 101
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_check(app.enemies != null and app.round_flow != null and presenter._badges.size() == 2,
		"seeded fixture admitted real models and two mounted source actors")
	if app.enemies == null or app.round_flow == null or presenter._badges.size() != 2:
		app.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
		return
	var gauge := CombatUnravel.new()
	_check(gauge.bind_roster(app.enemies, {1: "elite", 2: "elite"}),
		"mounted fixture binds the real roster's optional Unravel service")
	app.round_flow._unravel = gauge
	presenter._refresh()
	_check(app.enemies != null and presenter._badges.size() == 2
		and presenter._bound_unravel(app) != null and app.enemy_intents.is_bound(),
		"real seeded app battle authenticates both source puppets, flow and scheduler")
	if presenter._bound_unravel(app) == null or not app.enemy_intents.is_bound():
		app.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
		return
	_check(app.enemies.apply_statuses({1: {"weak": 2}, 2: {"bleed": 3}}),
		"real roster accepts current status updates")
	# Exercise all three plaques on one actor, as a contact/status layout stress case.
	app.enemies._enemies[0]["thorns"] = 4
	presenter._refresh()
	var before: Array = _snapshot(app)
	var status: PanelContainer = presenter._status_tags[0]
	var badge: LiveEnemyIntentBadge = presenter._badges[0]
	_check(status.visible and presenter._status_tags[1].visible
		and presenter._thorns_tags[0].visible and app.enemies.get_enemy(2).get("thorns", 0) > 0
		and badge.visible and not badge.policy_cue.is_empty()
		and status.tooltip_text.contains(LiveEnemyIntentBadge.CONTACT_HELP.drain)
		and (status.get_node("Caption") as Label).text.contains("Drain")
		and badge.tooltip_text.contains("Target policy (AIM LOW HP)"),
		"mounted Drain/status, policy help and all three source plaques are actually visible beside a hazard actor")
	_plaque_bounds(app, presenter)
	var puppet = presenter._puppets[3]
	var original_size: Vector2 = puppet.size
	var original_target: Rect2 = presenter._labels[0].get_global_rect()
	# Synchronous Control resize exercises the real signal before a container settles again.
	var original_minimum: Vector2 = puppet.custom_minimum_size
	puppet.custom_minimum_size = Vector2.ZERO
	puppet.size = Vector2(original_size.x, 65)
	_check(badge.visible and not status.visible and not presenter._thorns_tags[0].visible,
		"shrunken source retains the available safe intent but hides nonfitting secondary plaques")
	_plaque_bounds(app, presenter)
	# The actor can still draw in a narrow slot, but its 192px sewn ticket cannot:
	# hiding it is safer than crossing into the neighboring enemy's column.
	puppet.size = Vector2(170, original_size.y)
	_check(puppet.rest_drawn_rect().has_area() and not badge.visible,
		"under-width mounted actor keeps artwork but fails closed on an unplaceable intent")
	puppet.size = original_size
	puppet.custom_minimum_size = original_minimum
	_check(badge.visible and status.visible and presenter._thorns_tags[0].visible
		and presenter._labels[0].get_global_rect().is_equal_approx(original_target),
		"resize signal restores both plaques and unchanged full-actor target area")
	_plaque_bounds(app, presenter)
	root.size = Vector2i(1100, 680)
	await process_frame
	await process_frame
	_plaque_bounds(app, presenter)
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	_check(status.visible and badge.visible and _snapshot(app) == before,
		"viewport shrink/restore changes no party/enemy/card/deck/turn/cache/RNG state")
	_plaque_bounds(app, presenter)
	var old_action: Dictionary = app.enemy_intents.get_intents()[0]
	_check(app.enemies.apply_statuses({1: {"weak": 1, "exposed": 3}}),
		"authentic status counts update through the live model")
	for turn in range(12):
		_check(app.enemy_intents.advance_turn(), "authentic weighted scheduler advances cached intent")
		if app.enemy_intents.get_intents()[0] != old_action:
			break
	_check(app.enemy_intents.get_intents()[0] != old_action,
		"updated intent fixture really differs from its previous cached action")
	presenter._refresh()
	var current: Array = _snapshot(app)
	_check(status.tooltip_text.contains("Exposed 3") and not status.tooltip_text.contains("Weak 2")
		and badge.intent_type == app.enemy_intents.get_intents()[0].type,
		"fresh authentic status and action replace old caption/help before reflow")
	_plaque_bounds(app, presenter)
	presenter._refresh()
	_check(_snapshot(app) == current, "reflow of updated content is state-inert")
	var old_ids := [status.get_instance_id(), badge.get_instance_id()]
	app.return_button.pressed.emit()
	app.starter_enemies_path = SOURCE
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(not is_instance_id_valid(old_ids[0]) and not is_instance_id_valid(old_ids[1])
		and presenter.enemies == app.enemies and presenter._status_tags.size() == 2,
		"different real roster frees all old Drain and policy presentation nodes")
	for plaque in presenter._status_tags:
		_check(not plaque.visible and plaque.tooltip_text.is_empty()
			and (plaque.get_node("Caption") as Label).text.is_empty(),
			"rebound starter actors retain no stale status/contact caption or help")
	for ticket in presenter._badges:
		_check(not ticket.tooltip_text.contains("AIM LOW HP") and not ticket.tooltip_text.contains("Drain"),
			"replacement intent has no previous actor's policy or passive help")
	_plaque_bounds(app, presenter)
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
	await process_frame


## V3 survival ribbons use genuine shipped actor definitions inside the real app scene.
## No fake badge, fabricated receipt or direct edits to the presenter's cue fields.
func _survival_records() -> Dictionary:
	var records: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	var found := {}
	for record in records:
		if record.get("id") in ["razor_ribbon_wraith", "quilt_termite",
				"fray_scavenger", "button_guard"]:
			found[record["id"]] = record.duplicate(true)
	return found


func _survival_plaque_bounds(presenter) -> void:
	for index in range(presenter._status_tags.size()):
		var plaque: PanelContainer = presenter._status_tags[index]
		if not plaque.is_visible_in_tree():
			continue
		var puppet = presenter._puppets[CombatParty.PARTY_SIZE + index]
		var world: Rect2 = plaque.get_global_rect()
		_check(world.has_area() and Rect2(0, 0, 1280, 720).encloses(world)
			and puppet.get_global_rect().grow(0.01).encloses(world)
			and not world.intersects(presenter._badges[index].get_global_rect())
			and not world.intersects(puppet.get_global_transform() * puppet.tag_band()),
			"survival plaque fits the mounted actor and 1280x720 stage without covering intent/name")
		for other in presenter._status_tags:
			if other != plaque and other.is_visible_in_tree():
				_check(not world.intersects(other.get_global_rect()),
					"survival plaques never overlap another actor's warning")


## One genuine shipped actor record by ID from the same catalog the live run uses.
func _authored_enemy(id: String) -> Dictionary:
	var records: Array = RunTypedBattleRoster._parse_catalog_text(
		FileAccess.get_file_as_string("res://data/enemies/run_enemies.json"))
	for record in records:
		if record is Dictionary and record.get("id") == id:
			return record.duplicate(true)
	return {}


## Inert legacy schedule slots: bind_battle replaces them with each roster's own
## authored weighted spec, so only the genuine slot count matters here.
func _inert_patterns(count: int) -> Array:
	var specs: Array = []
	for position in range(1, count + 1):
		specs.append({"enemy_position": position,
			"pattern": [{"type": "block", "amount": 0}]})
	return specs


## Binds one real roster to the mounted app battle exactly as a live admission does,
## so the presenter, its plaques and the app's post-card boundary all read it.
func _mount_roster(app, app_presenter, roster: CombatEnemies) -> bool:
	var intents := CombatEnemyIntents.new(_inert_patterns(roster.get_enemies().size()))
	if not intents.bind_battle(roster, app.party, app.run_rng):
		return false
	var result := CombatBattleResult.new(app.party, roster)
	var flow := CombatRoundFlow.new(app.deck, app.party, roster, intents, result)
	app.enemies = roster
	app.enemy_intents = intents
	app.battle_result = result
	app.round_flow = flow
	app.enemy_attacks = intents.get_intents()
	app_presenter._sync_battle()
	return app_presenter.enemies == roster


func _survival_ribbons(scene: PackedScene) -> void:
	var authored := _survival_records()
	_check(authored.has("razor_ribbon_wraith") and authored.has("quilt_termite")
		and authored.has("fray_scavenger") and authored.has("button_guard")
		and authored["razor_ribbon_wraith"].get("max_hp") == 27
		and authored["razor_ribbon_wraith"].get("revive_once") == true
		and authored["quilt_termite"].get("max_hp") == 26
		and authored["quilt_termite"].get("split_on_death") is bool
		and authored["quilt_termite"].get("split_on_death") == true,
		"V3 ribbons start from real typed Wraith and Termite catalog records")
	if authored.size() != 4:
		return
	var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
	_check(file != null, "authentic ribbon fixture can be staged for the app's real Start Run")
	if file == null:
		return
	file.store_string(JSON.stringify([authored["razor_ribbon_wraith"],
		authored["quilt_termite"]]))
	file.close()
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.starter_enemies_path = FIXTURE
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_check(app.enemies != null and app.round_flow != null and app.enemy_intents.is_bound()
		and presenter.enemies == app.enemies and presenter._status_tags.size() == 2
		and presenter._puppets.size() == 5
		and presenter._puppets[3].actor_id == "razor_ribbon_wraith"
		and presenter._puppets[4].actor_id == CombatEnemies.TERMITE_ID,
		"live app Start Run mounts exactly the two typed actors with bound combat")
	if app.enemies == null or presenter._status_tags.size() != 2:
		app.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))
		return
	var wraith: PanelContainer = presenter._status_tags[0]
	var termite: PanelContainer = presenter._status_tags[1]
	var wraith_label := wraith.get_node("Caption") as Label
	var termite_label := termite.get_node("Caption") as Label
	var before: Array = _snapshot(app)
	presenter._refresh()
	_check(wraith.is_visible_in_tree() and wraith_label.text == "Revive ready"
		and wraith.tooltip_text.contains("first lethal HP loss")
		and wraith.tooltip_text.contains("14 HP")
		and wraith.tooltip_text.contains("Only once")
		and termite.is_visible_in_tree() and termite_label.text == "Splits if room"
		and termite.tooltip_text.contains("confirmed paid-card lethal hit")
		and termite.tooltip_text.contains("slot is available")
		and termite.tooltip_text.contains("fewer than 3 foes")
		and not termite.tooltip_text.contains("fewer than 4 foes")
		and termite.tooltip_text.contains("13-HP Half Quilt Termites")
		and termite.tooltip_text.contains("Bleed and the enemy phase do not trigger"),
		"ready Wraith and conditional Termite display exact source-owned captions and help")
	_survival_plaque_bounds(presenter)
	for repeat in range(3):
		presenter._refresh()
	_check(_snapshot(app) == before and presenter._badges.size() == 2,
		"survival preview changes no HP, cards, turn, intent, party or run RNG")
	var first: Dictionary = app.enemies._enemies[0]
	var second: Dictionary = app.enemies._enemies[1]
	first["statuses"] = {"weak": 2}
	second["statuses"] = {"bleed": 1}
	presenter._refresh()
	_check(wraith_label.text.contains("Weak 2") and wraith_label.text.contains("Revive ready")
		and termite_label.text.contains("Bleed 1") and termite_label.text.contains("Splits if room")
		and presenter._badges[0].source_position == 1,
		"existing statuses and intent badges coexist with both survival cues")
	first.erase("statuses")
	second.erase("statuses")
	for invalid in ["yes", 1, null]:
		first["revive_once"] = invalid
		second["split_on_death"] = invalid
		presenter._refresh()
		_check(not wraith.visible and not termite.visible
			and wraith.tooltip_text.is_empty() and termite.tooltip_text.is_empty(),
			"malformed nonboolean revival/split flags cannot produce trait warnings")
	first["revive_once"] = true
	second["split_on_death"] = true
	first["id"] = "foreign_wraith"
	second["id"] = "foreign_termite"
	presenter._refresh()
	_check(not wraith.visible and not termite.visible,
		"foreign actor IDs at occupied slots cannot borrow an old actor's trait")
	first["id"] = "razor_ribbon_wraith"
	second["id"] = "quilt_termite"
	second["chew_block_on_attack"] = false
	presenter._refresh()
	_check(wraith_label.text == "Revive ready" and not termite.visible,
		"unsupported Termite metadata fails closed without suppressing genuine Wraith")
	second["chew_block_on_attack"] = true
	first["revived"] = "invalid"
	presenter._refresh()
	_check(not wraith.visible and termite_label.text == "Splits if room",
		"invalid revival latch is not guessed or coalesced into a ready state")
	first.erase("revived")
	presenter._refresh()
	_check(_snapshot(app) == before and wraith_label.text == "Revive ready",
		"invalid flags are restored without changing the authentic live battle")
	_check(app.enemies.apply_damage(1, 27), "authoritative first lethal hits the 27-HP Wraith")
	var revived: Dictionary = app.enemies.get_enemy(1)
	presenter._refresh()
	_check(revived.get("hp") == 14 and revived.get("revived") == true
		and not app.enemies.is_slain(1) and wraith_label.text == "Revive spent"
		and wraith.tooltip_text.contains("next lethal HP loss is final")
		and not wraith.tooltip_text.contains("first lethal HP loss"),
		"genuine first lethal latches revival and next refresh replaces ready with spent")
	_check(app.enemies.apply_damage(1, 14) and app.enemies.is_slain(1),
		"authoritative second lethal finally slays the same Wraith")
	presenter._refresh()
	_check(not wraith.visible and wraith_label.text.is_empty() and wraith.tooltip_text.is_empty(),
		"slain Wraith emits no living revival claim")
	_check(app.enemies.apply_damage(2, 26) and app.enemies.is_slain(2),
		"authoritative 26-HP Termite receives a lethal hit")
	presenter._refresh()
	_check(not termite.visible and termite_label.text.is_empty(),
		"lethal damage alone has no living split warning or fabricated offspring")
	var stage: Dictionary = app.enemies.stage_split_on_death(2)
	_check(stage == {"ok": true, "split": true, "positions": [2, 3]}
		and app.enemies.get_enemies().size() == 3
		and app.enemies.get_enemy(2).get("id") == CombatEnemies.HALF_LEFT_ID
		and app.enemies.get_enemy(3).get("id") == CombatEnemies.HALF_RIGHT_ID
		and app.enemies.get_enemy(2).get("hp") == 13
		and app.enemies.get_enemy(3).get("hp") == 13,
		"explicit post-paid-card staging replaces the parent with real 13-HP half actors")
	presenter._sync_battle()
	await process_frame
	presenter._refresh()
	_check(presenter._status_tags.size() == 3
		and presenter._puppets[4].actor_id == CombatEnemies.HALF_LEFT_ID
		and presenter._puppets[5].actor_id == CombatEnemies.HALF_RIGHT_ID,
		"growing actual roster remounts one plaque per split child")
	for plaque in presenter._status_tags:
		var text: String = (plaque.get_node("Caption") as Label).text
		_check(not text.contains("Splits if room") and not text.contains("Revive")
			and not plaque.tooltip_text.contains("paid-card lethal"),
			"half-Termites and the slain Wraith inherit no survival cue")
	app.return_button.pressed.emit()
	await process_frame
	app.free()
	# A full roster never makes the same paid-card split promise or stages a fourth.
	file = FileAccess.open(FIXTURE, FileAccess.WRITE)
	file.store_string(JSON.stringify([authored["quilt_termite"], authored["fray_scavenger"]]))
	file.close()
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	app.starter_enemies_path = FIXTURE
	_fixture_start(app)
	await process_frame
	await process_frame
	presenter = app.get_node("LiveEnemyRoster")
	# The standalone two-slot schedule cannot admit a third position. Present a
	# genuine three-actor CombatEnemies model in the already-mounted battle instead.
	# The source-of-truth model still owns capacity, lethal damage and staging.
	var full_roster := CombatEnemies.new([authored["quilt_termite"],
		authored["fray_scavenger"], authored["button_guard"]])
	_check(full_roster.is_valid() and full_roster.get_enemies().size() == 3,
		"three authentic definitions create a legal authoritative full roster")
	app.enemies = full_roster
	presenter._sync_battle()
	await process_frame
	_check(app.enemies != null and app.enemies.get_enemies().size() == CombatEnemies.MAX_ENEMIES
		and presenter._status_tags.size() == CombatEnemies.MAX_ENEMIES
		and presenter._puppets[3].actor_id == CombatEnemies.TERMITE_ID,
		"full-roster boundary is the real mounted three-foe Termite fight")
	if app.enemies != null and presenter._status_tags.size() == CombatEnemies.MAX_ENEMIES:
		var full: PanelContainer = presenter._status_tags[0]
		presenter._refresh()
		_check(not full.visible and full.tooltip_text.is_empty()
			and not (full.get_node("Caption") as Label).text.contains("Splits"),
			"three occupied slots never promise a new Termite")
		_check(app.enemies.apply_damage(1, 26), "real full-roster Termite is slain")
		var all_before: Array[Dictionary] = app.enemies.get_enemies()
		_check(app.enemies.stage_split_on_death(1) == {"ok": true, "split": false}
			and app.enemies.get_enemies() == all_before,
			"explicit split contract cannot publish a fourth foe after full-roster lethal")
		presenter._refresh()
		_check(not full.visible and full.tooltip_text.is_empty(),
			"slain full-roster source never keeps a stale warning")
	app.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE))


## Find a deterministic, legal weighted choice from shipped specs. Never assign
## _cache or call show_intent in place of the live bound scheduler.
func _intent_witness_seed(roster: CombatEnemies, party: CombatParty,
		source: int, kind: String) -> int:
	var slots: Array[Dictionary] = []
	for actor in roster.get_enemies():
		var slot := CombatEnemyIntents._weighted_slot(int(actor.position), actor.get("intent"))
		_check(not slot.is_empty(), "weighted witness has a normalized shipped actor spec")
		if slot.is_empty():
			return -1
		slots.append(slot)
	for candidate in range(1, 1025):
		var random := RandomNumberGenerator.new()
		random.seed = candidate
		var drawn: Array[Dictionary] = CombatEnemyIntents._draw_batch(slots, party, random)
		if drawn.size() == slots.size() and drawn[source - 1].get("type") == kind:
			return candidate
	_check(false, "a seeded authentic weighted selection can produce " + kind)
	return -1


## Source four is bound through the very same app and public roster sync as a
## normal fight; the fourth action is selected by a real weighted draw.
func _mounted_fourth_wasp(scene: PackedScene) -> void:
	var ids := ["fray_scavenger", "button_guard", "spool_stalker", "needle_wasp"]
	var definitions: Array = []
	for id in ids:
		var authored := _authored_enemy(id)
		_check(not authored.is_empty(), "source-four fixture finds shipped enemy " + id)
		if authored.is_empty():
			return
		definitions.append(authored)
	var roster := CombatEnemies.new(definitions, CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(roster.is_valid() and roster.get_capacity() == 4
		and roster.get_enemies().size() == 4 and roster.get_enemy(4).id == "needle_wasp",
		"AC1 precondition: a genuine distinct four-actor roster has Wasp in position four")
	if not roster.is_valid():
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.party != null and app.run_rng != null and app.party.is_valid(),
		"AC1 precondition: real Start Run supplies a valid live hero party and seeded RNG")
	if app.party == null or app.run_rng == null:
		app.free()
		return
	var candidate := _intent_witness_seed(roster, app.party, 4, "attack")
	if candidate < 1:
		app.free()
		return
	app.run_rng.seed = candidate
	var presenter = app.get_node("LiveEnemyRoster")
	_check(_mount_roster(app, presenter, roster), "AC1 precondition: actual app binds real weighted four-source combat")
	await process_frame
	await process_frame
	var announcements: Array[Dictionary] = app.enemy_intents.get_intents()
	_check(announcements.size() == 4 and announcements[3].get("enemy_position") == 4
		and announcements[3].get("type") == "attack"
		and announcements[3].get("amount") == 8 and announcements[3].get("hits") == 2
		and announcements[3].get("target_position") in [1, 2, 3],
		"AC1 precondition: actual seeded scheduler publishes Wasp's authored A-2 with a real hero target")
	_check(presenter.enemies == roster and presenter._badges.size() == 4
		and presenter._puppets.size() == 7
		and presenter._puppets[6].actor_id == "needle_wasp",
		"AC1 precondition: player-facing stage mounts fourth Wasp puppet and its fourth badge")
	if announcements.size() != 4 or presenter._badges.size() != 4:
		app.free()
		return
	var action: Dictionary = announcements[3]
	var badge: LiveEnemyIntentBadge = presenter._badges[3]
	var hero: int = int(action.get("target_position", 0))
	var output: Array = [badge.readable_text, badge.tooltip_text, badge.hit_count,
		badge.hit_damage, badge.target_position, badge.policy_cue]
	_check(LiveEnemyIntentBadge.is_two_hit_attack(action)
		and badge.source_position == 4 and badge.intent_type == "attack"
		and badge.amount == 8 and badge.hit_count == 2 and badge.hit_damage == 4
		and badge.target_position == hero and badge.policy_cue == "Aim low HP"
		and badge.readable_text in badge.compact_caption_forms()
		and badge.readable_text.contains("8") and badge.readable_text.contains("A-2"),
		"AC1: mounted genuine fourth Wasp reads as eight power, two four-point hits at real target: " + str(output))
	_check(badge.tooltip_text.contains("8A-2: two hits")
		and badge.tooltip_text.contains("4 + 4 base damage")
		and badge.tooltip_text.contains(LiveEnemyIntentBadge.hero_target_label(hero))
		and badge.tooltip_text.contains("Target policy (AIM LOW HP)")
		and badge.tooltip_text.contains("independently"),
		"AC1: real fourth-slot hover names both packets, actual hero and low-HP policy: " + badge.tooltip_text)
	var before: Array = _snapshot(app)
	for repeat in range(4):
		presenter._refresh()
		_check([badge.readable_text, badge.tooltip_text, badge.hit_count, badge.hit_damage,
			badge.target_position, badge.policy_cue] == output and _snapshot(app) == before,
			"AC1: replayed mounted Wasp refresh leaves combat, run RNG and exact badge unchanged")
	# Neither skip nor a slain source may continue announcing damage.
	_check(roster.apply_damage(4, 22) and roster.is_slain(4),
		"AC2 precondition: fourth authentic Wasp can be slain in authoritative roster")
	presenter._refresh()
	_check(badge.readable_text == "SLAIN" and badge.hit_count == 1
		and not badge.tooltip_text.contains("two hits"),
		"AC2: slain fourth source clears its real two-hit cue")
	app.free()
	await process_frame


## A source-owned Moth's weighted Summon must tell the truth in each legal
## capacity, both with a vacancy and when the last slot is already occupied.
func _mounted_summon_help(scene: PackedScene, capacity: int, count: int) -> void:
	var ids := ["moth_swarm", "fray_scavenger", "button_guard", "spool_stalker"]
	var definitions: Array = []
	for index in range(count):
		var authored := _authored_enemy(ids[index])
		_check(not authored.is_empty(), "summon fixture finds shipped actor " + ids[index])
		if authored.is_empty():
			return
		definitions.append(authored)
	var roster := CombatEnemies.new(definitions, capacity)
	_check(roster.is_valid() and roster.get_capacity() == capacity
		and roster.get_enemies().size() == count
		and CombatEnemies.authentic_broodling_mother(roster.get_enemy(1), 1),
		"AC3 precondition: mounted summon source is real Moth with valid capacity")
	if not roster.is_valid():
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	await process_frame
	await process_frame
	if app.party == null or app.run_rng == null:
		_check(false, "AC3 precondition: actual game supplies party and RNG")
		app.free()
		return
	var candidate := _intent_witness_seed(roster, app.party, 1, "summon")
	if candidate < 1:
		app.free()
		return
	app.run_rng.seed = candidate
	var presenter = app.get_node("LiveEnemyRoster")
	_check(_mount_roster(app, presenter, roster),
		"AC3 precondition: real app binds Moth's weighted Summon")
	await process_frame
	await process_frame
	var actions: Array[Dictionary] = app.enemy_intents.get_intents()
	_check(actions.size() == count and actions[0].get("type") == "summon"
		and actions[0].get("enemy_position") == 1
		and presenter._badges.size() == count,
		"AC3 precondition: live weighted scheduler selected actual source-one Summon")
	if presenter._badges.size() != count or actions.size() != count:
		app.free()
		return
	var badge: LiveEnemyIntentBadge = presenter._badges[0]
	var can_birth := count < capacity
	_check(badge.readable_text == "Summon Broodling"
		and badge.tooltip_text.contains("maximum %d enemies" % capacity)
		and badge.tooltip_text.contains("8 HP")
		and badge.tooltip_text.contains("5")
		and badge.tooltip_text.contains("birth turn")
		and badge.tooltip_text.contains("following turn")
		and badge.tooltip_text.contains("will be born") == can_birth
		and badge.tooltip_text.contains("no Broodling is born") == not can_birth,
		"AC3: authentic %d-of-%d Summon hover truthfully describes vacancy and later attack: %s" % [
			count, capacity, badge.tooltip_text])
	var tip := badge.tooltip_text
	var before := _snapshot(app)
	for repeat in range(3):
		presenter._refresh()
	_check(badge.tooltip_text == tip and _snapshot(app) == before
		and roster.get_enemies().size() == count
		and not roster.get_enemy(1).has(CombatEnemies.BROODLING_LATCH),
		"AC3: repeated Summon tooltip viewing spends no latch, HP or RNG and is replayable")
	app.free()
	await process_frame


## A bound four-capacity fight is the only Termite battle that may still promise a
## split. The real mounted plaque, the app's own post-card boundary and the genuine
## model split into slot four are exercised here, alongside every fail-closed refusal.
func _four_capacity_ribbons(scene: PackedScene) -> void:
	var authored := _survival_records()
	var extra := _authored_enemy("spool_stalker")
	_check(authored.has("quilt_termite") and authored.has("fray_scavenger")
		and authored.has("button_guard") and not extra.is_empty()
		and int(extra.get("max_hp", 0)) > 0,
		"four-capacity ribbons start from genuine shipped actor records")
	if not (authored.has("quilt_termite") and authored.has("fray_scavenger")
			and authored.has("button_guard")) or extra.is_empty():
		return
	var witness := CombatEnemies.new([authored["fray_scavenger"],
		authored["quilt_termite"], authored["button_guard"]],
		CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(witness.is_valid() and witness.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and witness.get_enemies().size() == 3
		and witness.get_enemy(2).get("id") == CombatEnemies.TERMITE_ID,
		"AC1 precondition: three authentic actors bind a legal four-capacity roster")
	if not witness.is_valid():
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	await process_frame
	await process_frame
	var presenter = app.get_node("LiveEnemyRoster")
	_check(_mount_roster(app, presenter, witness), "AC1 precondition: the real app battle binds the roster")
	await process_frame
	await process_frame
	presenter._refresh()
	_check(app.enemies == witness and presenter.enemies == witness
		and presenter._status_tags.size() == 3 and presenter._puppets.size() == 6,
		"AC1 precondition: the mounted battle shows all three authentic actors")
	if app.enemies != witness or presenter._status_tags.size() != 3:
		app.free()
		return
	var termite: PanelContainer = presenter._status_tags[1]
	var caption := termite.get_node("Caption") as Label
	_check(termite.is_visible_in_tree() and caption.text == "Splits if room"
		and termite.tooltip_text.contains("fewer than 4 foes")
		and not termite.tooltip_text.contains("fewer than 3 foes")
		and termite.tooltip_text.contains("13-HP Half Quilt Termites"),
		"AC1: the three-of-four living Termite promises the real fourth slot")
	_survival_plaque_bounds(presenter)
	var before: Array = _snapshot(app)
	var outcome_before: String = app.battle_result.get_outcome()
	for repeat in range(3):
		presenter._refresh()
	_check(_snapshot(app) == before and app.battle_result.get_outcome() == outcome_before
		and witness.get_enemies().size() == 3,
		"AC3: repeated four-capacity refresh keeps actors, turn, deck, RNG and outcome")
	witness._capacity = CombatEnemies.OPT_IN_MAX_ENEMIES + 1
	presenter._refresh()
	_check(not termite.visible and termite.tooltip_text.is_empty(),
		"AC2: a forged capacity above the legal limit promises no split")
	witness._capacity = CombatEnemies.OPT_IN_MAX_ENEMIES
	var live = app.enemies
	app.enemies = CombatEnemies.new([extra])
	presenter._refresh()
	_check(not termite.visible and termite.tooltip_text.is_empty(),
		"AC2: a stale binding never keeps another battle's split promise")
	app.enemies = live
	presenter._refresh()
	_check(termite.is_visible_in_tree() and caption.text == "Splits if room",
		"AC1: restoring the same bound battle restores its genuine warning")
	var roster_before := witness.get_enemies()
	_check(witness.apply_damage(2, 26) and witness.is_slain(2),
		"AC1 precondition: the four-capacity Termite takes a lethal paid-card hit")
	presenter._refresh()
	_check(not termite.visible and termite.tooltip_text.is_empty(),
		"AC2: a slain Termite displays no split warning")
	_check(app._note_card_damage(witness, roster_before),
		"AC1 precondition: the real post-card boundary records the authentic lethal")
	_check(app._observe_battle_result()
		and witness.get_enemies().size() == 4
		and witness.get_enemy(2).get("id") == CombatEnemies.HALF_LEFT_ID
		and witness.get_enemy(4).get("id") == CombatEnemies.HALF_RIGHT_ID
		and witness.get_enemy(2).get("hp") == 13 and witness.get_enemy(4).get("hp") == 13,
		"AC1: the real app boundary fills slot four with both half-Termites")
	await process_frame
	await process_frame
	presenter._refresh()
	_check(presenter._status_tags.size() == 4 and presenter._puppets.size() == 7
		and presenter._puppets[3].actor_id == "fray_scavenger"
		and presenter._puppets[4].actor_id == CombatEnemies.HALF_LEFT_ID
		and presenter._puppets[5].actor_id == "button_guard"
		and presenter._puppets[6].actor_id == CombatEnemies.HALF_RIGHT_ID,
		"AC1: the genuine fourth-slot split remounts one plaque and puppet per actor")
	for plaque in presenter._status_tags:
		var text: String = (plaque.get_node("Caption") as Label).text
		_check(not text.contains("Splits if room") and not text.contains("Revive")
			and not plaque.tooltip_text.contains("paid-card lethal"),
			"AC1: the split halves inherit no survival cue")
	app.free()
	await process_frame
	# Four genuine actors in a four-capacity roster can never promise or stage a split.
	var full := CombatEnemies.new([authored["quilt_termite"], authored["fray_scavenger"],
		authored["button_guard"], extra], CombatEnemies.OPT_IN_MAX_ENEMIES)
	_check(full.is_valid() and full.get_capacity() == CombatEnemies.OPT_IN_MAX_ENEMIES
		and full.get_enemies().size() == 4,
		"AC2 precondition: four authentic actors really fill a four-capacity roster")
	if not full.is_valid():
		return
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	await process_frame
	await process_frame
	presenter = app.get_node("LiveEnemyRoster")
	_check(_mount_roster(app, presenter, full), "AC2 precondition: the real app battle binds the full roster")
	await process_frame
	await process_frame
	presenter._refresh()
	_check(app.enemies == full and presenter._status_tags.size() == 4
		and presenter._puppets.size() == 7,
		"AC2 precondition: the mounted battle shows all four authentic actors")
	if app.enemies != full or presenter._status_tags.size() != 4:
		app.free()
		return
	var full_termite: PanelContainer = presenter._status_tags[0]
	_check(not full_termite.is_visible_in_tree() and full_termite.tooltip_text.is_empty(),
		"AC2: four occupied slots at capacity four never promise a split")
	_check(full.apply_damage(1, 26)
		and full.stage_split_on_death(1) == {"ok": true, "split": false}
		and full.get_enemies().size() == 4 and full.is_slain(1),
		"AC2: the full four-capacity roster refuses the split after genuine lethal")
	presenter._refresh()
	_check(not full_termite.visible and full_termite.tooltip_text.is_empty(),
		"AC2: the slain full-roster Termite keeps no stale warning")
	app.free()
	await process_frame


func _mounted_move_names(scene: PackedScene) -> void:
	var definition := _authored_enemy("thread_biter")
	_check(not definition.is_empty() and definition.get("max_hp") == 15,
		"move-name precondition: genuine shipped Thread Biter record exists")
	if definition.is_empty():
		return
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	_fixture_start(app)
	await process_frame
	await process_frame
	_check(app.party != null and app.run_rng != null and app.party.is_valid(),
		"move-name precondition: mounted real battle supplies party and seeded RNG")
	if app.party == null or app.run_rng == null:
		app.free()
		return
	var presenter = app.get_node("LiveEnemyRoster")
	var prior_catalog: LiveMovePoseCatalog
	for kind in ["attack", "block"]:
		var roster := CombatEnemies.new([definition])
		_check(roster.is_valid() and roster.get_enemy(1).id == "thread_biter",
			"move-name precondition: authentic living roster is valid")
		var seed_value := _intent_witness_seed(roster, app.party, 1, kind)
		if seed_value < 1:
			continue
		app.run_rng.seed = seed_value
		_check(_mount_roster(app, presenter, roster), "move-name precondition: real scheduler binds authored " + kind)
		await process_frame
		await process_frame
		var actions: Array[Dictionary] = app.enemy_intents.get_intents()
		_check(actions.size() == 1 and actions[0].get("type") == kind
			and actions[0].get("enemy_position") == 1 and presenter._badges.size() == 1,
			"move-name precondition: actual cached announcement and mounted badge exist")
		if actions.size() != 1 or presenter._badges.size() != 1:
			continue
		var badge: LiveEnemyIntentBadge = presenter._badges[0]
		var title := "Lint Spit" if kind == "attack" else "Fraying Coil"
		_check(presenter._move_catalog != prior_catalog and presenter._move_catalog._loaded
			and badge.move_name == title and badge.tooltip_text.ends_with("\nMove: " + title),
			"live rebind owns a fresh loaded catalog and the actual authored move: " + badge.tooltip_text)
		prior_catalog = presenter._move_catalog
		# Compare against the authoritative detailed renderer, with identical context.
		var expected := LiveEnemyIntentBadge.new()
		expected.show_intent(actions[0], false)
		# This fixture has no started round-flow service, so no policy/contact extras.
		_check(badge.tooltip_text == expected.tooltip_text + "\nMove: " + title
			and badge.amount == (5 if kind == "attack" else 2)
			and badge.target_position == actions[0].get("target_position", 0),
			"move label preserves exact detailed action, damage and target help")
		expected.free()
		var catalog := CountingMoveCatalog.new()
		presenter._move_catalog = catalog
		var before := _snapshot(app)
		var tip := badge.tooltip_text
		var geometry := [badge.position, badge.size, badge.mouse_filter, badge.focus_mode]
		for repeat in range(4):
			presenter._sync_battle()
			presenter._refresh()
			_check(badge.move_name == title and badge.tooltip_text == tip
				and _snapshot(app) == before and presenter._move_catalog == catalog
				and [badge.position, badge.size, badge.mouse_filter, badge.focus_mode] == geometry,
				"refresh is exact, single-name, geometry-stable and combat/RNG-neutral without named art")
		_check(catalog.reads == 1, "mounted catalog reads authored manifest once across repeated refreshes")
		var schedule = app.enemy_intents
		app.enemy_intents = CombatEnemyIntents.new(_inert_patterns(1))
		presenter._refresh()
		_check(badge.move_name.is_empty() and not badge.tooltip_text.contains("Move:"),
			"unbound announcement cannot borrow preceding move name")
		app.enemy_intents = schedule
		app.enemies = CombatEnemies.new([definition])
		presenter._refresh()
		_check(badge.move_name.is_empty() and not badge.tooltip_text.contains("Move:"),
			"replaced authoritative roster clears previous move")
		app.enemies = roster
		roster._enemies[0]["id"] = "unknown_move_source"
		presenter._refresh()
		_check(badge.move_name.is_empty() and not badge.tooltip_text.contains("Move:"),
			"replaced actor identity cannot borrow an admitted source's move")
		roster._enemies[0]["id"] = "thread_biter"
		presenter._refresh()
		_check(badge.move_name == title, "restored exact binding recovers current move")
		var skip := CombatUnravel.new()
		_check(skip.bind_roster(roster, {1: "normal"}) and skip.apply_unravel(roster, 1, 8),
			"move-name precondition: real Unravel service has pending skip")
		var flow = app.round_flow
		flow._started = true
		flow._battle_deck = app.deck
		flow._battle_party = app.party
		flow._battle_enemies = roster
		flow._battle_intents = schedule
		flow._battle_result = app.battle_result
		flow._unravel = skip
		presenter._refresh()
		_check(badge.readable_text == "UNRAVELLED" and badge.move_name.is_empty()
			and not badge.tooltip_text.contains("Move:"), "pending genuine skip clears authored name")
		_check(skip.consume_action_skip(roster, 1), "real skip can be consumed")
		presenter._refresh()
		_check(badge.move_name == title, "cleared skip restores current authored move")
		if kind == "attack":
			_check(badge.policy_cue == "Aim low HP"
				and badge.tooltip_text.contains("5 damage aimed at " + LiveEnemyIntentBadge.hero_target_label(badge.target_position))
				and badge.tooltip_text.contains("Target policy (AIM LOW HP): aims at the living hero with the lowest current HP.")
				and badge.tooltip_text.contains("Passive (not the announced action)")
				and badge.tooltip_text.ends_with("\nMove: Lint Spit"),
				"authenticated flow preserves full damage, policy and passive help before authored move")
		app._battle_closed = true
		presenter._refresh()
		_check(badge.move_name.is_empty() and not badge.tooltip_text.contains("Move:"),
			"closed battle clears preceding move name")
		app._battle_closed = false
		_check(roster.apply_damage(1, 999) and roster.is_slain(1), "real source takes lethal damage")
		presenter._refresh()
		_check(badge.move_name.is_empty() and badge.tooltip_text == "Slain: no action.",
			"slain source clears move and detailed action")
	# A genuine uncovered base attack must not be inferred from its attack2 pose.
	for id in ["fray_scavenger", "unknown_move_source"]:
		var record := _authored_enemy("fray_scavenger") if id == "fray_scavenger" else definition.duplicate(true)
		record["id"] = id
		var roster := CombatEnemies.new([record])
		app.run_rng.seed = _intent_witness_seed(roster, app.party, 1, "attack")
		_check(_mount_roster(app, presenter, roster), "negative move witness binds real weighted scheduler: " + id)
		presenter._refresh()
		_check(app.enemy_intents.get_intents()[0].get("type") == "attack"
			and presenter._badges[0].intent_type == "attack"
			and presenter._badges[0].move_name.is_empty()
			and not presenter._badges[0].tooltip_text.contains("Move:"),
			"uncovered action or unknown admitted ID never fabricates a move: " + id)
	app.free()
	await process_frame


func _finish() -> void:
	for failure in failures:
		printerr(failure)
	print("live_enemy_roster_test: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


## Standalone M01 admission; seeded title input is covered by live_seeded_opening_route_test.
func _fixture_start(target) -> void:
	if target.deck != null:
		target.start_button.pressed.emit()
		preload("res://tests/party_choice.gd").choose(target)
		return
	var started: bool = target._start_battle()
	_check(started == (target.deck != null), "standalone fixture reports admission consistently")
