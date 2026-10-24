extends SceneTree
func _init():
	var s = load("res://scripts/combat_attack_cards.gd")
	if s == null:
		print("Failed to load combat_attack_cards.gd")
	else:
		print("Loaded combat_attack_cards.gd")
	var t = load("res://scripts/run_torn_mending.gd")
	if t == null:
		print("Failed to load run_torn_mending.gd")
	else:
		print("Loaded run_torn_mending.gd")
	quit()
