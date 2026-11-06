class_name StitchedWrenLines
extends RefCounted
## S9c (design v4 section 9c): Wren's own words, authored in data/kid/wren_lines.json. A line is
## picked from the doll's id, never from the run's RNG, so text never changes a seeded run.

const PATH := "res://data/kid/wren_lines.json"

static var _book: Dictionary = {}


static func book() -> Dictionary:
	if _book.is_empty() and FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary and parsed.get("version") == 1:
			_book = parsed
	return _book


static func intro() -> Dictionary:
	return book().get("intro", {})


## What Wren says when a doll is lost; the same doll always draws the same line.
static func doll_lost(doll_id: String, doll_name: String) -> String:
	var lines: Array = book().get("doll_lost", [])
	if lines.is_empty():
		return ""
	var line: String = lines[absi(hash(doll_id)) % lines.size()]
	return line.replace("%s", doll_name)


## The One Doll Too Many clue, told as Wren counting his four dolls.
static func mimic(eye_profile: String = "") -> String:
	return str(book().get("mimic_eyes", {}).get(eye_profile, book().get("mimic", "")))
