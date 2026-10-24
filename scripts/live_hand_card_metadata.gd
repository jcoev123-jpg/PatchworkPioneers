extends RefCounted
## Read-only, per-panel CanvasItem decoration for the real shared combat hand.
## Never adds Controls, changes input/focus, or touches any combat model.

const WARDEN := Color("#4a5d73")
const SEAMSTRESS := Color("#6e4f6b")
const TINKER := Color("#c49a3a")
const CREAM := Color("#ece0c8")
const RUST := Color("#9e6f58")
const INK := Color("#3d3440")
## Every effect key this display formatter understands. Anything else stays
## undescribed and is flagged honestly instead of being interpreted as a number.
const KNOWN_EFFECT_KEYS := [
	"damage", "hits", "hit_count", "block", "other_ally_block", "block_all",
	"heal", "exposed", "weak", "bleed", "unravel", "bleed_multiplier", "pinned",
	"guarding", "thorns", "draw", "energy", "gain_energy", "self_hp_loss",
	"conditional_damage", "random_target_each_hit", "rng_source",
	"living_targets_only", "duration", "next_attack_damage_bonus",
	"next_turn_energy", "expires",
]
## Plain-text keyword reminders appended to the tooltip (never the card face)
## for authored cards that actually carry the mechanic. They explain only the
## published rule; no card is shown as automatically pinning or unravelling.
const PINNED_EXPLANATION := "PINNED: one pin per enemy, storing the hero who applied it. A DIFFERENT hero's next attack deals +5 damage BEFORE Weak/Exposed and consumes it once; same-hero attacks do not. A new pin replaces it; an unused pin lasts to combat end."
const UNRAVEL_EXPLANATION := "UNRAVEL: an Unravel N adds N to that enemy's gauge and each Bleed tick adds 1. At the normal 8 / elite 12 / boss 16 threshold the enemy becomes Unravelled and skips its next enemy action; the gauge then resets to 0 and its threshold rises by 4 for the rest of combat."
## The ready-made patchwork card art. Every load here is optional and cached:
## a missing file always leaves the drawn paper face exactly as it was.
const ART_DIR := "res://assets/paper/"
## Source corner size of the sewn card frames. Corners are redrawn at their own
## size while only the frame edges stretch, so the felt buttons and stitches
## keep their detail on a landscape hand panel.
const FRAME_SOURCE_EDGE := 34.0

var _catalog := StarterCards.new()
var _warden_pool := WardenPoolCards.new()
var _tinker_pool := TinkerPoolCards.new()
var _seamstress_pool := SeamstressPoolCards.new()
var _targeting := CombatAttackTargeting.new()
var _stitched_preview := CombatStitchedTargetPreview.new()
var _on_hit := CombatOnHitStatuses.new()
## Authored Seamstress Path card faces, keyed by card ID. Loaded once from the
## same validated record the run service uses and never mutated afterwards.
var _path_loaded := false
var _path_card_definitions: Dictionary = {}
var _path_passives: Dictionary = {}
var _path_names: Dictionary = {}
## Authored Tinker Path card faces, keyed by card ID, from the same validated
## offer set the run service uses.
var _tinker_path_loaded := false
var _tinker_path_cards: Dictionary = {}
## Authored Warden Path card faces, keyed by card ID, from the same validated
## offering set RunWardenPathChoice exposes. Display knowledge only: neither
## card joins a starter/reward catalog or a run deck from this lookup.
var _warden_path_loaded := false
var _warden_path_cards: Dictionary = {}
var _warden_path_passives: Dictionary = {}
var _warden_path_names: Dictionary = {}
# Key: the ACTUAL hand panel, value: original card ID, facts and signal Callables.
var _bindings: Dictionary = {}
var _app
# Key: art path, value: Texture2D or null. A negative entry is cached too, so a
# missing file is never probed twice.
var _textures: Dictionary = {}


func set_app(app) -> void:
	_app = app


func _ledger() -> RunRestStitchCards:
	return RunRestStitchCards.new(_app.run_deck, _app.run_stitch_descriptors,
		_app.run_scraps, _app.run_next_stitch_id)


## Authored display knowledge only. Starter and movement records keep priority,
## then every reward-pool record (base and '+' upgrade) is a verified catalog
## lookup. Whether a recognized card may be played is a separate live decision
## made by the mounted presenters (see _wired); an unknown ID stays unknown.
func _definition(card_id: String) -> Dictionary:
	_load_path_cards()
	_load_tinker_path_cards()
	_load_warden_path_cards()
	if _path_card_definitions.has(card_id):
		# Detached like every catalog lookup, so a caller can never alter the
		# authored Path record other panels read.
		return (_path_card_definitions[card_id] as Dictionary).duplicate(true)
	if _tinker_path_cards.has(card_id):
		return (_tinker_path_cards[card_id] as Dictionary).duplicate(true)
	if _warden_path_cards.has(card_id):
		return (_warden_path_cards[card_id] as Dictionary).duplicate(true)
	var move := M02PositionCards.new().get_definition(card_id)
	if not move.is_empty():
		return move
	var starter := _catalog.get_definition(card_id)
	if not starter.is_empty():
		return starter
	var warden_definition := _warden_pool.get_definition(card_id)
	if not warden_definition.is_empty():
		return warden_definition
	var seamstress_definition := _seamstress_pool.get_definition(card_id)
	if not seamstress_definition.is_empty():
		return seamstress_definition
	return _tinker_pool.get_definition(card_id)


## Public read-only lookup shared by the mounted hand admission checks.
func definition(card_id: String) -> Dictionary:
	return _definition(card_id)


## The two authored Path cards of the Seamstress record, in authored order. A
## record that does not validate contributes nothing, so the faces stay unknown
## and the mounted battle resolver alone can admit a Path card.
func _load_path_cards() -> void:
	if _path_loaded:
		return
	_path_loaded = true
	var choice := RunSeamstressPathChoice.new()
	if not choice.is_valid():
		return
	for path in choice.get_paths():
		if not path is Dictionary:
			continue
		var card: Variant = (path as Dictionary).get("card")
		var passive: Variant = (path as Dictionary).get("passive")
		if not card is Dictionary or not passive is Dictionary:
			continue
		var card_id: String = str((card as Dictionary).get("id", ""))
		if card_id.is_empty():
			continue
		_path_card_definitions[card_id] = (card as Dictionary).duplicate(true)
		_path_passives[card_id] = (passive as Dictionary).duplicate(true)
		_path_names[card_id] = str((path as Dictionary).get("display_name", ""))


## The extra amount an authored Path passive adds to its own card, e.g. Bleed
## 3 -> 4 for Bloodline or Unravel 4 -> 6 for Unpicker. Display only: the combat
## resolver owns the applied value.
func _path_passive_bonus(card_id: String, status: String) -> int:
	if not _path_passives.has(card_id):
		return 0
	var passive: Dictionary = _path_passives[card_id]
	if str(passive.get("status", "")) != status:
		return 0
	var value: Variant = passive.get("value")
	return int(value) if value is int else 0


func _path_name(card_id: String) -> String:
	return str(_path_names.get(card_id, ""))


## The two authored Tinker Path cards, loaded once from the same validated offer
## set. A record that does not validate contributes no face and no playability.
func _load_tinker_path_cards() -> void:
	if _tinker_path_loaded:
		return
	_tinker_path_loaded = true
	for path in RunTinkerPathChoice.new().get_offers():
		if not path is Dictionary:
			continue
		var card: Variant = (path as Dictionary).get("card")
		if not card is Dictionary:
			continue
		var card_id: String = str((card as Dictionary).get("id", ""))
		if card_id.is_empty():
			continue
		_tinker_path_cards[card_id] = (card as Dictionary).duplicate(true)


## The two authored Warden Path cards, loaded once from the same validated
## offering set the run service exposes. A record that does not validate
## contributes no face and no playability. Reading the offerings never claims a
## Path, so this lazy display cache leaves the run's single claim untouched.
func _load_warden_path_cards() -> void:
	if _warden_path_loaded:
		return
	_warden_path_loaded = true
	var choice := RunWardenPathChoice.new()
	if not choice.is_valid():
		return
	for path in choice.get_authored_paths():
		if not path is Dictionary:
			continue
		var card: Variant = (path as Dictionary).get("card")
		var passive: Variant = (path as Dictionary).get("passive")
		if not card is Dictionary or not passive is Dictionary:
			continue
		var card_id: String = str((card as Dictionary).get("id", ""))
		if card_id.is_empty():
			continue
		_warden_path_cards[card_id] = (card as Dictionary).duplicate(true)
		_warden_path_passives[card_id] = (passive as Dictionary).duplicate(true)
		_warden_path_names[card_id] = str((path as Dictionary).get("display_name", ""))


## One explanatory Path/passive line, kept separate from the card's own authored
## effects. Every number comes from the same validated record the battle
## resolver will use, and no extra live effect is claimed for a cast that has no
## mounted Warden resolver yet.
func _warden_path_help(card_id: String) -> String:
	if not _warden_path_cards.has(card_id):
		return ""
	var card: Dictionary = _warden_path_cards[card_id]
	var passive: Dictionary = _warden_path_passives.get(card_id, {})
	var path_name: String = str(_warden_path_names.get(card_id, ""))
	var raw_effects: Variant = card.get("effects", {})
	var effects: Dictionary = raw_effects if raw_effects is Dictionary else {}
	match str(passive.get("kind", "")):
		"replaces_starting_block":
			var base_block: int = int(passive.get("replaced_starting_block", 0))
			var path_block: int = int(passive.get("starting_block", 0))
			var cast_block: int = int(effects.get("block", 0))
			return ("PATH %s passive: the Warden opens combat with exactly %d Block, replacing the base %d instead of adding to it (not %d + %d, not %d). This card's own cast grants %d Block to the living Warden and never re-grants the opening Block."
				% [path_name, path_block, base_block, base_block, path_block,
					base_block + path_block, cast_block])
		"first_attack_per_turn_pins":
			var damage: int = int(effects.get("damage", 0))
			return ("PATH %s passive: pins only after the Warden's first CONFIRMED attack in each player turn, never every cast and never an unconfirmed preview. This card's own cast deals %d damage and pins a surviving target; a DIFFERENT hero's next attack on it adds +5 damage BEFORE Weak/Exposed and consumes the pin once (see PINNED)."
				% [path_name, damage])
	return ""


## Cached, optional texture load. A frame or hero emblem that is not on disk
## stays null, so the renderer keeps its drawn placeholder.
func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		var loaded: Texture2D = null
		if ResourceLoader.exists(path):
			loaded = load(path) as Texture2D
		_textures[path] = loaded
	return _textures.get(path)


## Only a final '+' suffix shares its base card's picture; longer IDs keep
## whatever authored art they own.
func _base_id(card_id: String) -> String:
	return card_id.trim_suffix("_plus")


## The optional sewn face for a card ID: its owner's felt frame and the picture
## on the upper face. An ordinary known card shows its own illustration; a pool
## card without one shows its owner's emblem. A stitched card has no single
## owner and an unknown ID has no facts, so both keep the drawn paper face.
func _face_assets(card_id: String) -> Dictionary:
	var authored: Dictionary = _definition(card_id)
	var owner: String = str(authored.get("owner", ""))
	var frame: Texture2D = null
	var picture: Texture2D = null
	if not authored.is_empty() and not owner.is_empty():
		frame = _texture(ART_DIR + "ui/card_frame_%s.png" % owner)
		# Authored records that name their own picture use it; every other card
		# keeps the existing art-then-emblem priority and its drawn fallback.
		var authored_picture: Variant = authored.get("illustration_path")
		if authored_picture is String and not (authored_picture as String).is_empty():
			picture = _texture(authored_picture)
		if picture == null:
			picture = _texture(ART_DIR + "cards/art/%s.png" % _base_id(card_id))
		if picture == null:
			picture = _texture(ART_DIR + "cards/emblem_%s.png" % owner)
	return {
		"frame": frame, "picture": picture,
		"frame_path": frame.resource_path if frame != null else "",
		"picture_path": picture.resource_path if picture != null else "",
	}


## Public read-only view of the sewn face for mounted checks.
func face_assets(card_id: String) -> Dictionary:
	return _face_assets(card_id)


func get_faces(panel: Control) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	return _bindings[panel].get("faces", {}).duplicate()


func base_effect_text(card_id: String) -> String:
	var definition: Dictionary = _definition(card_id)
	if definition.is_empty():
		return "Unknown card"
	var display_name: String = definition.get("display_name", card_id)
	var owner: String = definition.get("owner", "")
	var cost: int = int(definition.get("cost", -1))
	var from_text: String = describe(card_id).get("from_text", "From ?")
	var parts: Array[String] = ["%s; %s; %d energy" % [display_name, owner.capitalize(), cost], from_text]
	var target_text: String = _target_text(definition, true)
	if target_text == "No target":
		parts.append("No target")
	elif not target_text.is_empty() and target_text != "Unknown target":
		parts.append(target_text)
	var effect_parts: Array[String] = _effect_lines(card_id, definition, true)
	if not effect_parts.is_empty():
		parts.append("; ".join(effect_parts))
	# A Warden Path passive belongs to the Path, not to the card's own cast, so
	# its explanation is one separate line after the authored card effects.
	var path_help: String = _warden_path_help(card_id)
	if not path_help.is_empty():
		parts.append(path_help)
	for keyword_line in _keyword_lines(definition):
		parts.append(keyword_line)
	return "\n".join(parts)


## One catalog-derived target sentence for both the compact badge line and the
## precise tooltip. A target kind this formatter does not know stays "Unknown
## target" rather than guessing at legal recipients.
func _target_text(definition: Dictionary, precise: bool) -> String:
	var target_kind: String = str(definition.get("target_kind", ""))
	var to_positions: Array = definition.get("to_positions", [])
	var positions: String = _positions(to_positions)
	match target_kind:
		"enemy_single":
			return ("To one selected enemy " if precise else "To enemy ") + positions
		"enemy_all":
			return "All enemies " + positions
		"enemy_random":
			if precise:
				return "A random living enemy per hit (%s)" % positions
			return "Random enemy " + positions
		"self":
			return "Self"
		"ally_single":
			return "Choose one living ally" if precise else "Ally"
		"party_all":
			return "All living heroes"
		"adjacent_ally":
			var behind: bool = int(definition.get("direction", 0)) == 1
			if precise:
				return "Swap with the living adjacent ally %s" % ("behind" if behind else "ahead")
			return "Swap with ally " + ("behind" if behind else "ahead")
		"none":
			return "No target"
	return "Unknown target"


## The authored recipient phrase used by effect sentences; never a promise about
## a card whose target kind is unrecognized.
func _recipient(definition: Dictionary) -> String:
	match str(definition.get("target_kind", "")):
		"enemy_all":
			return "each living enemy"
		"enemy_random":
			return "the struck enemy"
		"party_all":
			return "each living hero"
		"ally_single":
			return "the chosen ally"
		"self":
			return "this hero"
	return "the target"


## Authored effect sentences, short on the card face and precise in the tooltip.
## No resolution is predicted: only catalog fields and the real confirmed-hit
## starter adapter are described, and any unrecognized effect key is flagged
## instead of being rendered as an invented value.
func _effect_lines(card_id: String, definition: Dictionary, precise: bool) -> Array[String]:
	var parts: Array[String] = []
	var raw_effects: Variant = definition.get("effects", {})
	var effects: Dictionary = raw_effects if raw_effects is Dictionary else {}
	var recipient: String = _recipient(definition)
	if definition.get("action_kind") == "adjacent_swap":
		parts.append("Swap with the living adjacent ally %s" % ("behind" if int(definition.get("direction", 0)) == 1 else "ahead"))
	if effects.has("damage"):
		var damage: int = int(effects["damage"])
		var hits: int = int(effects.get("hits", effects.get("hit_count", 1)))
		if precise:
			var line := "BASE deal %d damage" % damage
			if hits > 1:
				line += " in %d hits" % hits
			parts.append(line)
		else:
			var line := "%d dmg" % damage
			if hits > 1:
				line += " x%d" % hits
			parts.append(line)
	if bool(effects.get("random_target_each_hit", false)):
		parts.append("BASE each hit picks a random living enemy" if precise else "random each hit")
	if effects.has("block"):
		parts.append("BASE gain %d Block" % int(effects["block"]) if precise else "%d Block" % int(effects["block"]))
	# Hold the Line and Bastion Quilt pay other recipients too; never hide them.
	if effects.has("other_ally_block"):
		parts.append("BASE each other living ally gains %d Block" % int(effects["other_ally_block"])
			if precise else "%d Block to other allies" % int(effects["other_ally_block"]))
	if effects.has("block_all"):
		parts.append("BASE each living hero gains %d Block" % int(effects["block_all"])
			if precise else "%d Block to all heroes" % int(effects["block_all"]))
	if effects.has("heal"):
		var heal_value: Variant = effects["heal"]
		if heal_value is Dictionary:
			# Authored descriptor form: {amount, target, cap}.
			var heal: Dictionary = heal_value
			var heal_amount: int = int(heal.get("amount", 0))
			var heal_target: String = "the weakest living ally" \
				if str(heal.get("target", "")) == "weakest_living_ally" else recipient
			var capped: bool = str(heal.get("cap", "")) == "missing_hp"
			if precise:
				var heal_line := "BASE heal %d HP to %s" % [heal_amount, heal_target]
				if capped:
					heal_line += ", capped at missing HP"
				parts.append(heal_line)
			else:
				parts.append("heal %d%s" % [heal_amount,
					" (weakest, capped)" if capped else ""])
		else:
			parts.append("BASE heal %d HP, capped at max HP" % int(heal_value)
				if precise else "heal %d" % int(heal_value))
	if effects.has("exposed"):
		var exposed: int = int(effects["exposed"])
		if card_id in CombatAttackTargeting.SIGHT_GLASS_IDS:
			parts.append("Apply Exposed %d to the selected enemy" % exposed)
		elif precise:
			parts.append("BASE apply Exposed %d to %s" % [exposed, recipient])
		else:
			parts.append("Exposed %d" % exposed)
	# The starter adapter is the authority for starter confirmed-hit statuses;
	# an authored status it already covers is never counted twice.
	var confirmed: Dictionary = _on_hit.status_for_confirmed_hit(card_id, true)
	if effects.has("bleed") and not confirmed.has("bleed"):
		var authored_bleed: int = int(effects["bleed"])
		var passive_bleed: bool = CombatSeamstressPoolBleed.SUPPORTED_IDS.has(card_id)
		# A selected Path replaces the Seamstress passive on its own card only;
		# the applied amount still comes from the combat resolver.
		var path_bleed: int = _path_passive_bonus(card_id, "bleed")
		var applied_bleed: int = authored_bleed + (1 if passive_bleed else path_bleed)
		if precise:
			var bleed_line := "BASE apply Bleed %d to %s" % [applied_bleed, recipient]
			if passive_bleed:
				bleed_line += " (authored %d + Seamstress passive 1)" % authored_bleed
			elif path_bleed > 0:
				bleed_line += " (authored %d + %s passive %d)" % [authored_bleed,
					_path_name(card_id), path_bleed]
			parts.append(bleed_line)
		elif passive_bleed:
			parts.append("Bleed %d (%d+1)" % [applied_bleed, authored_bleed])
		elif path_bleed > 0:
			parts.append("Bleed %d (%d+%d)" % [applied_bleed, authored_bleed, path_bleed])
		else:
			parts.append("Bleed %d" % applied_bleed)
	if effects.has("weak") and not confirmed.has("weak"):
		parts.append("BASE apply Weak %d to %s" % [int(effects["weak"]), recipient]
			if precise else "Weak %d" % int(effects["weak"]))
	if effects.has("unravel"):
		var authored_unravel: int = int(effects["unravel"])
		var path_unravel: int = _path_passive_bonus(card_id, "unravel")
		var applied_unravel: int = authored_unravel + path_unravel
		if precise:
			var unravel_line := "BASE add %d Unravel to %s" % [applied_unravel, recipient]
			if path_unravel > 0:
				unravel_line += " (authored %d + %s passive %d)" % [authored_unravel,
					_path_name(card_id), path_unravel]
			parts.append(unravel_line)
		elif path_unravel > 0:
			parts.append("Unravel %d (%d+%d)" % [applied_unravel, authored_unravel, path_unravel])
		else:
			parts.append("Unravel %d" % applied_unravel)
	if effects.has("bleed_multiplier"):
		var multiplier: int = int(effects["bleed_multiplier"])
		if precise:
			parts.append("BASE double the target's current Bleed" if multiplier == 2
				else "BASE multiply the target's current Bleed by %d" % multiplier)
		else:
			parts.append("double Bleed" if multiplier == 2 else "x%d Bleed" % multiplier)
	if effects.has("pinned"):
		var pin_bonus := 5
		var pin_rule: Variant = effects["pinned"]
		if pin_rule is Dictionary and pin_rule.get("bonus_damage") is int:
			pin_bonus = int(pin_rule["bonus_damage"])
		parts.append("BASE Pin %s: a different hero's next attack gets +%d damage" % [recipient, pin_bonus]
			if precise else "Pin")
	if effects.has("guarding"):
		parts.append("BASE Guard: enemy attacks aimed at other living heroes are redirected to the living Warden until your next turn" if precise else "Guard")
	if effects.has("thorns"):
		parts.append("BASE gain %d Thorns: an enemy attacking Warden takes %d damage until your next turn" % [int(effects["thorns"]), int(effects["thorns"])]
			if precise else "Thorns %d" % int(effects["thorns"]))
	if effects.has("draw"):
		var draw_count: int = int(effects["draw"])
		parts.append("BASE draw %d card%s" % [draw_count, "" if draw_count == 1 else "s"]
			if precise else "draw %d" % draw_count)
	if effects.has("gain_energy"):
		parts.append("BASE gain %d energy" % int(effects["gain_energy"])
			if precise else "+%d energy" % int(effects["gain_energy"]))
	if effects.has("energy") and not effects.has("gain_energy"):
		parts.append("BASE gain %d energy" % int(effects["energy"])
			if precise else "+%d energy" % int(effects["energy"]))
	if effects.has("next_attack_damage_bonus"):
		var bonus: int = int(effects["next_attack_damage_bonus"])
		var timing: String = " this turn" \
			if str(effects.get("expires", "")) == "end_of_player_turn" else ""
		parts.append("BASE the next attack%s deals +%d damage" % [timing, bonus]
			if precise else "+%d next attack" % bonus)
	if effects.has("next_turn_energy"):
		var credit: int = int(effects["next_turn_energy"])
		parts.append("BASE gain %d energy on your next turn" % credit
			if precise else "+%d energy next turn" % credit)
	if effects.has("self_hp_loss"):
		parts.append("BASE self-damage %d" % int(effects["self_hp_loss"])
			if precise else "-%d HP" % int(effects["self_hp_loss"]))
	if effects.has("conditional_damage"):
		var condition: Variant = effects["conditional_damage"]
		if condition is Dictionary and condition.get("damage") is int:
			var empowered: int = int(condition["damage"])
			var clauses: Array[String] = _condition_clauses(condition)
			if precise:
				var condition_line := "BASE deal %d damage instead" % empowered
				if not clauses.is_empty():
					condition_line += " if " + _join_conditions(condition, clauses)
				parts.append(condition_line)
			else:
				var short_conditions := _short_conditions(condition)
				parts.append("%d dmg if %s" % [empowered, short_conditions] if not short_conditions.is_empty()
					else "%d conditional dmg" % empowered)
		else:
			parts.append("BASE an additional conditional damage effect" if precise else "conditional damage")
	if precise:
		for status in ["bleed", "weak"]:
			if not confirmed.has(status):
				continue
			var addition: int = int(confirmed[status])
			var rule := "ON CONFIRMED HIT add %s %d" % [status.capitalize(), addition]
			if status == "bleed" and str(definition.get("owner", "")) == "seamstress":
				var authored: int = int(effects.get("bleed", 0))
				rule += " (authored Bleed %d + Seamstress passive %d)" % [authored, addition - authored]
			parts.append(rule)
	else:
		for status in ["bleed", "weak"]:
			if confirmed.has(status):
				parts.append("%d %s on hit" % [int(confirmed[status]), status.capitalize()])
	for key in effects:
		if str(key) not in KNOWN_EFFECT_KEYS:
			parts.append("BASE another authored effect is not described" if precise else "other effects")
			break
	return parts


## The keyword glossary is driven only by authored effects, so an ordinary
## damage card never gains a pin or Unravel paragraph. Unravelled/half-gauge
## conditionals (Snip the Seam) need the Unravel rules just as an Unravel N does.
func _keyword_lines(definition: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var raw_effects: Variant = definition.get("effects", {})
	var effects: Dictionary = raw_effects if raw_effects is Dictionary else {}
	if effects.has("pinned"):
		lines.append(PINNED_EXPLANATION)
	if effects.has("unravel") or _has_unravel_conditional(effects):
		lines.append(UNRAVEL_EXPLANATION)
	return lines


func _has_unravel_conditional(effects: Dictionary) -> bool:
	var condition: Variant = effects.get("conditional_damage")
	if not condition is Dictionary:
		return false
	var authored: Variant = condition.get("conditions", [])
	if not authored is Array:
		return false
	for entry in authored:
		if not entry is Dictionary:
			continue
		if str(entry.get("status", "")) == "unravelled":
			return true
		if str(entry.get("gauge", "")) == "unravel" \
				and str(entry.get("comparison", "")) == "at_least_half":
			return true
	return false


## Readable clauses for the authored conditional-damage predicates. Unrecognized
## predicates contribute nothing rather than a guessed rule.
func _condition_clauses(condition: Dictionary) -> Array[String]:
	var clauses: Array[String] = []
	var authored: Variant = condition.get("conditions", [])
	if not authored is Array:
		return clauses
	for entry in authored:
		if not entry is Dictionary:
			continue
		if entry.has("status") and str(entry["status"]) == "unravelled":
			clauses.append("the target is Unravelled")
		elif entry.has("gauge") and str(entry["gauge"]) == "unravel" \
				and str(entry.get("comparison", "")) == "at_least_half":
			clauses.append("its Unravel gauge is at least half")
	return clauses


func _join_conditions(condition: Dictionary, clauses: Array[String]) -> String:
	var joiner := " or " if str(condition.get("operator", "or")) == "or" else " and "
	return joiner.join(clauses)


## Compact form of the same predicates for the narrow card-face rule line.
func _short_conditions(condition: Dictionary) -> String:
	var keys: Array[String] = []
	var authored: Variant = condition.get("conditions", [])
	if authored is Array:
		for entry in authored:
			if not entry is Dictionary:
				continue
			if entry.has("status") and str(entry["status"]) == "unravelled":
				keys.append("Unravelled")
			elif entry.has("gauge") and str(entry["gauge"]) == "unravel" \
					and str(entry.get("comparison", "")) == "at_least_half":
				keys.append("half gauge")
	# Authored conditions are alternatives today; the card line stays one short row.
	return "/".join(keys)


## The complete two-part tooltip for a stitched card. Each half is named from
## its authored catalog definition, so an upgraded half keeps its "+" name.
func stitched_tooltip(halves: Array) -> String:
	if halves.size() != 2:
		return ""
	return "1. " + base_effect_text(str(halves[0])) + "\n2. " + base_effect_text(str(halves[1]))


func describe(card_id: String) -> Dictionary:
	var definition: Dictionary = _definition(card_id)
	if _app != null and card_id.begins_with(RunRestStitchCards.ID_PREFIX):
		var ledger := _ledger()
		if ledger.is_valid() and ledger.get_snapshot() == _app._stitch_snapshot():
			definition = ledger.get_snapshot().descriptors.get(card_id, {})
			if not definition.is_empty():
				return {"id": card_id, "known": true, "owner": "", "owner_text": "Stitched",
					"display_name": str(definition.get("display_name", card_id)),
					"cost": definition.cost, "cost_text": "Cost %d" % definition.cost,
					"from_text": "Ordered halves", "target_text": "Independent targets",
					"rules": "Two ordered halves",
					"halves": definition.half_ids.duplicate()}
	if definition.is_empty():
		return {
			"id": card_id, "known": false, "owner": "", "owner_text": "Unknown",
			"display_name": "", "cost_text": "Cost ?", "from_text": "Rules unknown",
			"target_text": "", "rules": "", "cost": -1,
		}
	var owner: String = str(definition.get("owner", ""))
	var from_positions: Array = definition.get("from_positions", [])
	return {
		"id": card_id, "known": true, "owner": owner,
		"owner_text": owner.capitalize(),
		"display_name": str(definition.get("display_name", card_id)),
		"cost": int(definition.get("cost", -1)),
		"cost_text": "Cost %d" % int(definition.get("cost", -1)),
		"from_text": "From " + _positions(from_positions),
		"target_text": _target_text(definition, false),
		"rules": _rules(card_id),
	}


func _positions(positions: Array) -> String:
	if positions.is_empty():
		return "?"
	var values: Array[String] = []
	for position in positions:
		values.append(str(position))
	# Authored ranges are contiguous today, but do not claim holes are legal.
	var contiguous := true
	for index in range(1, positions.size()):
		if int(positions[index]) != int(positions[index - 1]) + 1:
			contiguous = false
	if contiguous and positions.size() > 1:
		return "%s–%s" % [values.front(), values.back()]
	return ",".join(values)


func sync(panels: Array[Node], hand: Array[String]) -> void:
	var current := {}
	for index in range(mini(panels.size(), hand.size())):
		var panel := panels[index] as Control
		if not is_instance_valid(panel) or panel.get_child_count() < 1:
			continue
		var label := panel.get_child(0) as Label
		# Both the hand order and the untouched FIRST label must agree.
		if label == null or label.text != hand[index]:
			continue
		current[panel] = true
		var card_id: String = label.text
		if _bindings.has(panel) and _bindings[panel]["id"] == card_id and _bindings[panel].facts == describe(card_id):
			_update_visual(panel)
			continue
		_unbind(panel)
		_bind(panel, card_id)
	for panel in _bindings.keys():
		if not is_instance_valid(panel) or not current.has(panel):
			_unbind(panel)


func _bind(panel: Control, card_id: String) -> void:
	var draw_callback := _draw_panel.bind(panel)
	var resize_callback := _resized.bind(panel)
	var exit_callback := _panel_exiting.bind(panel)
	var original_tooltip: String = ""
	if is_instance_valid(panel):
		original_tooltip = panel.tooltip_text
	_bindings[panel] = {
		"id": card_id, "facts": describe(card_id), "draw": draw_callback,
		"resize": resize_callback, "exit": exit_callback, "draw_count": 0,
		"original_tooltip": original_tooltip, "faces": _face_assets(card_id),
	}
	panel.get_child(0).hide()
	panel.tooltip_text = base_effect_text(card_id)
	var halves: Array = _bindings[panel].facts.get("halves", [])
	if halves.size() == 2:
		panel.tooltip_text = stitched_tooltip(halves)
	_update_visual(panel)
	panel.draw.connect(draw_callback)
	panel.resized.connect(resize_callback)
	panel.tree_exiting.connect(exit_callback)
	panel.queue_redraw()


func _resized(panel: Control) -> void:
	if _bindings.has(panel) and is_instance_valid(panel):
		panel.queue_redraw()


func _panel_exiting(panel: Control) -> void:
	_unbind(panel)


func _unbind(panel) -> void:
	if not _bindings.has(panel):
		return
	var binding: Dictionary = _bindings[panel]
	if is_instance_valid(panel):
		if panel.draw.is_connected(binding["draw"]):
			panel.draw.disconnect(binding["draw"])
		if panel.resized.is_connected(binding["resize"]):
			panel.resized.disconnect(binding["resize"])
		if panel.tree_exiting.is_connected(binding["exit"]):
			panel.tree_exiting.disconnect(binding["exit"])
		if panel.get_child_count() > 0:
			panel.get_child(0).show()
		# Restore original tooltip so unbind/rebind is clean.
		if binding.has("original_tooltip"):
			panel.tooltip_text = binding.get("original_tooltip", "")
	_bindings.erase(panel)


func clear() -> void:
	for panel in _bindings.keys():
		_unbind(panel)


func get_facts(panel: Control) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	return _bindings[panel]["facts"].duplicate(true)


func get_geometry(panel: Control) -> Dictionary:
	if not _bindings.has(panel) or not is_instance_valid(panel):
		return {}
	return card_layout(panel.size, _bindings[panel].get("faces", {}).get("frame") is Texture2D)


## Single source of truth for the drawn card. Mounted tests check these rects
## stay inside the real panel; the renderer draws exactly these regions.
## `framed` asks for the sewn felt face an ordinary known card gets when its
## owner's frame exists; stitched and unknown cards keep the drawn paper face.
func card_layout(size: Vector2, framed: bool = false) -> Dictionary:
	if size.x < 88.0 or size.y < 30.0:
		return {}
	var compact := size.y < 120.0
	var frame := Rect2(2, 2, size.x - 4, size.y - 4)
	if framed:
		var sewn := _sewn_layout(frame, compact)
		if not sewn.is_empty():
			return sewn
	var inset := 6.0
	var cost_side := 24.0 if compact else 30.0
	var cost := Rect2(size.x - inset - cost_side, inset, cost_side, cost_side)
	var stripe := Rect2(inset, inset + 2, 5, frame.size.y - (inset + 2) * 2)
	var text_x := stripe.end.x + 3.0
	var text_width := maxf(24.0, cost.position.x - text_x - 4.0)
	var owner := Rect2(text_x, inset + (2.0 if compact else 3.0), text_width, 12.0)
	var title := Rect2(text_x, owner.end.y + 1.0, text_width, 16.0 if compact else 20.0)
	var body_top := title.end.y + 2.0
	var body := Rect2(text_x, body_top, maxf(24.0, size.x - text_x - inset), frame.end.y - inset - body_top)
	# Both faces reserve one row per ordered half: the compact hand gets two short
	# sewn rows, taller panels keep the detailed three-line halves.
	var halves: Array[Rect2] = []
	var gap := 4.0 if compact else 6.0
	var each := floorf((body.size.y - gap) / 2.0)
	if each >= (20.0 if compact else 30.0):
		halves = [Rect2(body.position, Vector2(body.size.x, each)),
			Rect2(body.position + Vector2(0, each + gap), Vector2(body.size.x, each))]
	return {"compact": compact, "sewn": false, "border": 0.0, "frame": frame,
		"art": Rect2(), "stripe": stripe, "owner": owner, "cost": cost,
		"title": title, "footer": body, "rows": _text_rows(body), "halves": halves}


## The sewn face: the felt frame's border is kept clear, the illustration fills
## the upper face and the name, cost, pips and rules are refitted underneath it
## so the artwork can never cover them. Null when the panel is too small.
func _sewn_layout(frame: Rect2, compact: bool) -> Dictionary:
	# A thinner felt margin on a short panel leaves the rules room to stay legible;
	# only the stretchable frame edges change, the corners keep their detail.
	var border: float = clampf(roundf(minf(frame.size.x, frame.size.y) * (0.10 if compact else 0.115)), 10.0, 26.0)
	var interior := frame.grow(-border)
	if interior.size.x < 60.0 or interior.size.y < 44.0:
		return {}
	var cost_side := 22.0 if compact else 24.0
	var art := Rect2(interior.position,
		Vector2(interior.size.x, clampf(interior.size.y * (0.18 if compact else 0.38), 10.0, 52.0)))
	var seam := Rect2(interior.position.x, art.end.y, interior.size.x, 3.0)
	var cost := Rect2(interior.end.x - cost_side, seam.end.y + 1.0, cost_side, cost_side)
	var text_x: float = interior.position.x
	var text_width: float = maxf(24.0, cost.position.x - text_x - 4.0)
	var owner := Rect2(text_x, cost.position.y + 2.0, text_width, 8.0 if compact else 11.0)
	var title := Rect2(text_x, owner.end.y + 1.0, text_width, 11.0 if compact else 16.0)
	var footer_top: float = maxf(title.end.y, cost.end.y) + 2.0
	var footer := Rect2(text_x, footer_top, interior.size.x, interior.end.y - footer_top)
	if footer.size.y < 18.0:
		return {}
	return {"compact": compact, "sewn": true, "border": border, "frame": frame,
		"art": art, "stripe": seam, "owner": owner, "cost": cost, "title": title,
		"footer": footer, "rows": _text_rows(footer), "halves": []}


## The three text rows of an ordinary card face (source pips, target, rules).
## A roomy drawn face keeps the original three-line offsets; a refitted sewn
## face tiles its shorter block proportionally so the rows can neither overlap
## nor run past the card's lower edge.
func _text_rows(rect: Rect2) -> Dictionary:
	if rect.size.y >= 49.0:
		return {
			"from": Rect2(rect.position, Vector2(rect.size.x, 12.0)),
			"target": Rect2(rect.position.x, rect.position.y + 16.0, rect.size.x, 13.0),
			"rules": Rect2(rect.position.x, rect.position.y + 34.0, rect.size.x, 15.0),
		}
	var from_height: float = rect.size.y * 0.31
	var target_height: float = rect.size.y * 0.32
	var rules_top: float = rect.position.y + from_height + target_height
	return {
		"from": Rect2(rect.position, Vector2(rect.size.x, from_height)),
		"target": Rect2(rect.position.x, rect.position.y + from_height, rect.size.x, target_height),
		"rules": Rect2(rect.position.x, rules_top, rect.size.x, maxf(0.0, rect.end.y - rules_top)),
	}


func _owner_color(owner: String) -> Color:
	match owner:
		"warden":
			return WARDEN
		"seamstress":
			return SEAMSTRESS
		"tinker":
			return TINKER
	return INK


## Presentation-only view of what the current live state allows. Read by the
## renderer and by mounted tests; it never mutates a combat model.
func visual_state(panel) -> Dictionary:
	if not _bindings.has(panel):
		return {}
	var visual: Array = _bindings[panel].get("visual", [false, false, Vector2.ZERO, false])
	return {"playable": bool(visual[0]), "hovered": bool(visual[1]),
		"aim": visual[2] if visual[2] is Vector2 else Vector2.ZERO, "aiming": bool(visual[3])}


## A recognized catalog record is display knowledge, never play admission. Only a
## panel a live presenter has actually wired for play (its own gui_input handler on
## the real hand panel, with the untouched identity label agreeing) may be drawn as
## an enabled card. An unwired pool card keeps its honest face but stays dim.
func _wired(panel: Control, card_id: String) -> bool:
	if _app == null or not is_instance_valid(panel):
		return false
	var hand = _app.hand_view
	if hand == null or panel.get_parent() != hand:
		return false
	if panel.gui_input.get_connections().is_empty():
		return false
	if panel.get_child_count() < 1 or not panel.get_child(0) is Label:
		return false
	return (panel.get_child(0) as Label).text == card_id


func _update_visual(panel: Control) -> void:
	var playable := false
	var id: String = _bindings[panel].id
	_load_path_cards()
	_load_tinker_path_cards()
	_load_warden_path_cards()
	if _app != null and _app.deck != null and _app.party != null and _app.enemies != null \
			and _wired(panel, id):
		# The battle's one Tinker Path authority may already have discounted this
		# cast, which is a real price: the face must not dim an affordable card.
		var battle_preview = _app.get_node_or_null("LiveAttackPreview")
		var discount := 0
		if battle_preview != null and is_instance_valid(battle_preview) \
				and battle_preview.has_method("tinker_cost_discount"):
			discount = int(battle_preview.tinker_cost_discount(id))
		if _targeting.supports(id):
			# Starter, plain-strike, heavy and Sight Glass attacks share their own
			# read-only preview; no catalog record alone can claim a legal target.
			playable = bool(_targeting.get_preview(_app.deck, _app.party, _app.enemies, id, discount).get("playable", false))
		elif _path_card_definitions.has(id):
			# A Path card is enable-able only by the genuine battle-bound resolver
			# of the mounted routed fight, never by its authored face alone.
			var presenter = _app.get_node_or_null("LiveAttackPreview")
			playable = presenter != null and is_instance_valid(presenter) \
				and bool(presenter.path_preview(id).get("playable", false))
		elif _tinker_path_cards.has(id):
			# A Tinker Path card is enable-able only by this battle's one genuine
			# Path authority, never by its authored face alone.
			var tinker_presenter = _app.get_node_or_null("LiveAttackPreview")
			playable = tinker_presenter != null and is_instance_valid(tinker_presenter) \
				and bool(tinker_presenter.tinker_path_playable(id))
		elif _warden_path_cards.has(id):
			# No mounted Warden Path battle resolver exists yet. The authored face
			# stays readable but dim, and only a future genuine presenter that
			# exposes this exact positive admission method can ever enable a cast.
			var warden_presenter = _app.get_node_or_null("LiveAttackPreview")
			playable = warden_presenter != null and is_instance_valid(warden_presenter) \
				and warden_presenter.has_method("warden_path_playable") \
				and bool(warden_presenter.warden_path_playable(id))
		elif id.begins_with(RunRestStitchCards.ID_PREFIX):
			playable = bool(_stitched_preview.get_preview(_ledger(), _app._stitch_snapshot(), _app.deck, _app.party, _app.enemies, id).get("playable", false))
		elif id in M02PositionCards.IDS:
			var move := _definition(id)
			playable = _app.deck.turn_active and _app.deck.energy >= int(move.get("cost", -1)) \
				and _owner_position(move.get("owner", "")) in move.get("from_positions", []) \
				and CombatPositionSwaps.preview_adjacent_swap(_app.party, _owner_position(move.get("owner", "")), move.get("direction", 0)).get("ok", false)
		else:
			var support := _definition(id)
			var position := _owner_position(str(support.get("owner", "")))
			playable = not support.is_empty() and _app.deck.turn_active \
				and _app.deck.energy + discount >= int(support.get("cost", -1)) \
				and position in support.get("from_positions", []) and not _app.party.is_downed(position)
	var hovered := false
	var viewport := panel.get_viewport()
	if viewport != null:
		# The viewport's GUI hover is the same state that routes real mouse
		# motion (and is deterministic under a pushed event in tests).
		var under: Control = viewport.gui_get_hovered_control()
		hovered = under == panel or (under != null and panel.is_ancestor_of(under))
	var aiming := bool(panel.get_meta("aiming", false))
	var aim: Vector2 = panel.get_meta("aim_point", Vector2.ZERO) if aiming else Vector2.ZERO
	var visual := [playable, hovered, aim, aiming]
	panel.self_modulate = Color.WHITE if playable or _app == null else Color(0.72, 0.70, 0.68)
	panel.z_index = 3 if hovered or aiming else 0
	if _bindings[panel].get("visual", []) != visual:
		_bindings[panel].visual = visual
		panel.queue_redraw()


func _owner_position(owner: String) -> int:
	for hero in _app.party.get_heroes():
		if hero.id == owner:
			return hero.position
	return 0


func _fit(font: Font, value: String, available: float, preferred: int) -> int:
	var point_size := preferred
	while point_size > 8 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > available:
		point_size -= 1
	return point_size


func _font(panel: Control) -> Font:
	var font: Font = panel.get_theme_default_font()
	return font if font != null else ThemeDB.fallback_font


func _text(panel: Control, value: String, rect: Rect2, preferred: int, color: Color = INK) -> void:
	if value.is_empty() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var font := _font(panel)
	# A row never renders taller than the space the face gives it, so a refitted
	# compact row cannot bleed into the neighbouring line.
	var point_size := mini(_fit(font, value, rect.size.x, preferred), maxi(8, int(rect.size.y)))
	panel.draw_string(font, rect.position + Vector2(0, minf(float(point_size), rect.size.y)),
		value, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, point_size, color)


func _center_text(panel: Control, value: String, rect: Rect2, preferred: int) -> void:
	var font := _font(panel)
	var point_size := _fit(font, value, rect.size.x - 4.0, preferred)
	panel.draw_string(font, rect.position + Vector2(0, rect.size.y * 0.5 + float(point_size) * 0.36),
		value, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, point_size, INK)


## Human-readable rules from the authored effect fields plus the real
## confirmed-hit adapter; no resolved or promised value is invented.
func _rules(id: String) -> String:
	var definition: Dictionary = _definition(id)
	if definition.is_empty():
		return ""
	return ", ".join(_effect_lines(id, definition, false))


## Filled felt pips mark authored source slots; outlined squares mark authored
## legal target slots. Decoration only, never an input or rules authority.
func _draw_pips(panel: Control, facts: Dictionary, rect: Rect2) -> void:
	var definition := _definition(facts.get("id", ""))
	var from_positions: Array = definition.get("from_positions", [])
	var to_positions: Array = definition.get("to_positions", [])
	if from_positions.is_empty() and to_positions.is_empty():
		return
	var step := 7.0
	var radius := 2.0
	var x: float = rect.end.x - step * 5.0 - 4.0
	var y: float = rect.position.y + rect.size.y * 0.5
	for index in range(1, 4):
		var center := Vector2(x + step * (index - 1), y)
		if from_positions.has(index):
			panel.draw_circle(center, radius, _owner_color(facts.get("owner", "")))
		else:
			panel.draw_arc(center, radius, 0.0, TAU, 12, RUST, 1.0, true)
	for index in range(1, 4):
		var center := Vector2(x + step * (2 + index) + 5.0, y)
		if to_positions.has(index):
			panel.draw_rect(Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0), INK, true)
		else:
			panel.draw_rect(Rect2(center - Vector2(radius, radius), Vector2.ONE * radius * 2.0), RUST, false, 1.0)


## One authored half (or a whole ordinary card): owner colour, fitted name,
## source/target rules and effect line. Ordered halves pass a "1." prefix.
func _draw_half(panel: Control, id: String, rect: Rect2, order: String = "") -> void:
	var facts := describe(id)
	var definition := _definition(id)
	var owner_color := _owner_color(facts.get("owner", ""))
	var x: float = rect.position.x
	var width: float = rect.size.x
	if order.is_empty():
		var rows: Dictionary = _text_rows(rect)
		var from_row: Rect2 = rows["from"]
		_text(panel, facts.get("from_text", ""),
			Rect2(from_row.position, Vector2(from_row.size.x - 60.0, from_row.size.y)), 10, RUST)
		_draw_pips(panel, facts, from_row)
		_text(panel, facts.get("target_text", ""), rows["target"], 11)
		var rules := _rules(id)
		if not rules.is_empty():
			_text(panel, rules, rows["rules"], 12)
		return
	panel.draw_rect(Rect2(x - 3.0, rect.position.y + 1.0, 3, rect.size.y - 2.0), owner_color)
	_text(panel, order + definition.get("display_name", id), Rect2(x, rect.position.y, width, 14), 13)
	_text(panel, facts.get("owner_text", "") + " | " + facts.get("from_text", ""),
		Rect2(x, rect.position.y + 14.0, width - 44.0, 11), 9, owner_color)
	_draw_pips(panel, facts, Rect2(x, rect.position.y + 14.0, width, 11))
	var detail: String = facts.get("target_text", "")
	var rules := _rules(id)
	if not rules.is_empty():
		detail = rules if detail.is_empty() else "%s · %s" % [detail, rules]
	_text(panel, detail, Rect2(x, rect.position.y + 27.0, width, 12), 10)


## True only when both ledger halves are real authored definitions; an unknown
## half must fall back to the honest placeholder instead of invented rules.
func _halves_known(pair: Array) -> bool:
	if pair.size() != 2:
		return false
	return not _definition(str(pair[0])).is_empty() and not _definition(str(pair[1])).is_empty()


## One short sewn row of a compact stitched card: the authored half name in
## resolution order plus that half's own owner colour and label.
func _draw_sewn_half(panel: Control, id: String, rect: Rect2, order: int) -> void:
	var facts := describe(id)
	var definition := _definition(id)
	if definition.is_empty() or rect.size.y <= 12.0:
		return
	var owner_color := _owner_color(facts.get("owner", ""))
	panel.draw_rect(Rect2(rect.position.x - 3.0, rect.position.y + 1.0, 3.0, rect.size.y - 2.0), owner_color)
	_text(panel, "%d. %s" % [order, definition.get("display_name", id)],
		Rect2(rect.position, Vector2(rect.size.x, minf(14.0, rect.size.y))), 11)
	_text(panel, facts.get("owner_text", ""),
		Rect2(rect.position.x, rect.position.y + 12.0, rect.size.x, maxf(6.0, rect.size.y - 12.0)), 9, owner_color)


func _title(facts: Dictionary) -> String:
	var definition := _definition(facts.get("id", ""))
	if not definition.is_empty():
		return definition.get("display_name", facts.get("id", ""))
	var names: PackedStringArray = []
	for half in facts.get("halves", []):
		var authored := _definition(half)
		# A stale half contributes an honest placeholder, never its raw ID.
		names.append(authored.get("display_name", "Unknown half"))
	return " + ".join(names) if not names.is_empty() else "Unknown card"


## The sewn felt frame, drawn as nine slices: the corners keep the felt buttons
## and stitches at their authored size, only the edges stretch to the panel.
func _draw_frame_texture(panel: Control, texture: Texture2D, rect: Rect2, border: float) -> void:
	var source: Vector2 = texture.get_size()
	var edge: float = minf(FRAME_SOURCE_EDGE, minf(source.x, source.y) * 0.5 - 1.0)
	if edge <= 0.0:
		return
	var inset: float = clampf(border, 1.0, minf(rect.size.x, rect.size.y) * 0.5 - 1.0)
	var columns: Array = [
		[rect.position.x, inset, 0.0, edge],
		[rect.position.x + inset, rect.size.x - inset * 2.0, edge, source.x - edge * 2.0],
		[rect.end.x - inset, inset, source.x - edge, edge],
	]
	var rows: Array = [
		[rect.position.y, inset, 0.0, edge],
		[rect.position.y + inset, rect.size.y - inset * 2.0, edge, source.y - edge * 2.0],
		[rect.end.y - inset, inset, source.y - edge, edge],
	]
	for column in columns:
		for row in rows:
			panel.draw_texture_rect_region(texture,
				Rect2(column[0], row[0], column[1], row[1]),
				Rect2(column[2], row[2], column[3], row[3]))


## The card's own picture in the upper face, cropped to the band's aspect so the
## sewn illustration is never squashed. A seam of felt edges the patch.
func _draw_illustration(panel: Control, texture: Texture2D, rect: Rect2) -> void:
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var source := Rect2(Vector2.ZERO, texture.get_size())
	var band_aspect: float = rect.size.x / rect.size.y
	if source.size.x / source.size.y > band_aspect:
		var width: float = source.size.y * band_aspect
		source = Rect2(source.position + Vector2((source.size.x - width) * 0.5, 0), Vector2(width, source.size.y))
	else:
		var height: float = source.size.x / band_aspect
		source = Rect2(source.position + Vector2(0, (source.size.y - height) * 0.42), Vector2(source.size.x, height))
	panel.draw_texture_rect_region(texture, rect, source)
	panel.draw_rect(rect, RUST, false, 1.0)


func _draw_panel(panel: Control) -> void:
	if not _bindings.has(panel) or not is_instance_valid(panel):
		return
	var facts: Dictionary = _bindings[panel].facts
	var faces: Dictionary = _bindings[panel].get("faces", {})
	var visual := visual_state(panel)
	var layout := card_layout(panel.size, faces.get("frame") is Texture2D)
	if layout.is_empty():
		return
	# Hover (or an armed drag) lifts the drawn card and enlarges it around its
	# centre. Only the drawing transforms: the panel hitbox, layout and input
	# stay untouched.
	var raised: bool = visual["hovered"] or visual["aiming"]
	var grow := 1.04 if raised else 1.0
	var lift := -6.0 if visual["hovered"] else 0.0
	var centre: Vector2 = panel.size * 0.5
	panel.draw_set_transform(centre * (1.0 - grow) + Vector2(0, lift), 0.0, Vector2(grow, grow))
	var frame: Rect2 = layout["frame"]
	panel.draw_rect(frame, CREAM)
	var frame_texture: Texture2D = faces.get("frame")
	if frame_texture != null and bool(layout.get("sewn", false)):
		_draw_frame_texture(panel, frame_texture, frame, float(layout.get("border", 0.0)))
	else:
		panel.draw_rect(frame, RUST, false, 2.0)
		panel.draw_dashed_line(frame.position + Vector2(5, 5),
			Vector2(frame.end.x - 5.0, frame.position.y + 5.0), RUST, 1.0, 5.0)
		panel.draw_dashed_line(Vector2(frame.position.x + 5.0, frame.end.y - 5.0),
			frame.end - Vector2(5, 5), RUST, 1.0, 5.0)
	# The upper-face illustration always goes down before any text or the cost
	# coin, so the picture can never cover the rules it belongs to.
	_draw_illustration(panel, faces.get("picture"), layout["art"])
	panel.draw_rect(layout["stripe"], _owner_color(facts.get("owner", "")))
	var cost: Rect2 = layout["cost"]
	panel.draw_circle(cost.get_center(), cost.size.x * 0.5, TINKER)
	panel.draw_arc(cost.get_center(), cost.size.x * 0.5 - 1.5, 0.0, TAU, 24, CREAM, 1.5, true)
	_center_text(panel, str(facts.get("cost", -1)) if int(facts.get("cost", -1)) >= 0 else "?",
		cost, 14 if not layout["compact"] else 12)
	_text(panel, facts.get("owner_text", ""), layout["owner"], 11, _owner_color(facts.get("owner", "")))
	_text(panel, _title(facts), layout["title"], 15 if not layout["compact"] else 13)
	var halves: Array = layout["halves"]
	var pair: Array = facts.get("halves", [])
	if halves.size() == 2 and _halves_known(pair):
		for index in range(2):
			if layout["compact"]:
				_draw_sewn_half(panel, str(pair[index]), halves[index], index + 1)
			else:
				_draw_half(panel, str(pair[index]), halves[index], "%d. " % (index + 1))
		panel.draw_dashed_line(Vector2(halves[1].position.x, halves[0].end.y + 3.0),
			Vector2(halves[1].end.x, halves[0].end.y + 3.0), RUST, 1.0, 5.0)
	else:
		_draw_half(panel, _bindings[panel].id, layout["footer"])
	panel.draw_set_transform(Vector2.ZERO)
	if visual["aiming"]:
		var start := Vector2(panel.size.x * 0.5, 0)
		var end: Vector2 = panel.get_global_transform().affine_inverse() * visual["aim"]
		var direction := (end - start).normalized()
		if direction != Vector2.ZERO:
			panel.draw_line(start, end, TINKER, 3.0, true)
			panel.draw_colored_polygon(PackedVector2Array([end,
				end - direction.rotated(0.45) * 14.0, end - direction.rotated(-0.45) * 14.0]), TINKER)
	_bindings[panel].draw_count = int(_bindings[panel].draw_count) + 1
