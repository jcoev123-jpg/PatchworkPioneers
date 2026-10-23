class_name CardKeywordGlossary
extends RefCounted
## Read-only explanations for authored card effects. No run, scene or RNG state.
## The fixed order is independent of Dictionary insertion order.

const KEYWORD_ORDER := ["bleed", "weak", "exposed", "pinned", "unravel", "guarding", "thorns"]

static func describe(definition: Variant) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not definition is Dictionary:
		return lines
	var effects_value: Variant = (definition as Dictionary).get("effects", {})
	if not effects_value is Dictionary:
		return lines
	var effects: Dictionary = effects_value
	for key: String in KEYWORD_ORDER:
		if not effects.has(key):
			continue
		var raw: Variant = effects[key]
		var keyword := ""
		var explanation := ""
		if key in ["bleed", "weak", "exposed", "unravel", "thorns"]:
			if not raw is int or int(raw) <= 0:
				continue
			keyword = "%s %d" % [key.capitalize(), int(raw)]
		elif (key == "pinned" or key == "guarding") and ((raw is bool and raw) or (raw is Dictionary and not raw.is_empty())):
			keyword = key.capitalize()
		else:
			continue
		match key:
			"bleed":
				explanation = "At the end of the affected owner's turn, lose %d HP, then Bleed decreases by 1. An enemy Bleed tick also adds 1 Unravel." % int(raw)
			"weak":
				explanation = "For %d turn(s), the afflicted actor deals 25%% less attack damage. Damage rounds down (minimum 0)." % int(raw)
			"exposed":
				explanation = "For %d turn(s), the affected actor takes 50%% more attack damage. Damage rounds down (minimum 0)." % int(raw)
			"pinned":
				explanation = "The next attack by a DIFFERENT hero adds +5 damage before Weak/Exposed and consumes this pin. The same hero cannot use it. Re-pinning replaces the pin; it expires at combat end."
			"unravel":
				explanation = "Add %d to an enemy's Unravel gauge. Thresholds: normal 8, elite 12, boss 16. At threshold it becomes Unravelled and skips its NEXT action; the gauge resets to 0 and its threshold rises by 4 for this combat." % int(raw)
			"guarding":
				explanation = "Warden's Draw Fire (1 energy, from position 1) redirects attacks aimed at other heroes to Warden until the next turn."
			"thorns":
				explanation = "Warden's Counter-stitch (1 energy, from positions 1-2) makes enemies that attack Warden take %d damage until the next turn." % int(raw)
		lines.append({"keyword": keyword, "explanation": explanation})
	return lines
