class_name StitchedBedroomRecord
extends RefCounted
## What Wren's bedroom remembers between nights (S9d): how many nights have
## ended, the deepest floor any run reached, and how the last party came home.
## A plain dictionary so the room can be shown, saved and tested without a run.

const VERSION := 1
const FLOORS := 12


static func fresh() -> Dictionary:
	return {"version": VERSION, "nights": 0, "deepest": 0, "outcome": "", "dolls": {}}


## The record after one finished run. Only the dolls that went out change pose.
static func after_run(record: Dictionary, session: StitchedRunSession) -> Dictionary:
	var next := fresh() if not valid(record) else record.duplicate(true)
	if session == null or not session.phase in ["victory", "defeat"]:
		return next
	next.nights = int(next.nights) + 1
	next.deepest = clampi(maxi(int(next.deepest), session.map.get_current_floor()), 0, FLOORS)
	next.outcome = session.phase
	var dolls := {}
	for hero in session.heroes:
		dolls[str(hero.id)] = {"fray": int(hero.fray), "lost": bool(hero.lost),
			"hanging": not hero.lost and int(hero.hp) == 0}
	next.dolls = dolls
	return next


static func valid(raw: Variant) -> bool:
	if not raw is Dictionary or raw.get("version") != VERSION:
		return false
	for key in ["nights", "deepest"]:
		if typeof(raw.get(key)) not in [TYPE_INT, TYPE_FLOAT] or int(raw[key]) < 0:
			return false
	if not raw.get("outcome") in ["", "victory", "defeat"] or not raw.get("dolls") is Dictionary:
		return false
	for id in raw.dolls:
		var doll: Variant = raw.dolls[id]
		if not id in StitchedPartyAdmission.HERO_IDS or not doll is Dictionary \
				or typeof(doll.get("fray")) not in [TYPE_INT, TYPE_FLOAT] \
				or typeof(doll.get("lost")) != TYPE_BOOL or typeof(doll.get("hanging")) != TYPE_BOOL:
			return false
	return true


## A missing or unreadable file is a first night, never an error.
static func load_file(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return fresh()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fresh()
	var raw: Variant = JSON.parse_string(file.get_as_text())
	if not valid(raw):
		return fresh()
	var record: Dictionary = raw
	record.version = VERSION
	record.nights = int(record.nights)
	record.deepest = int(record.deepest)
	for id in record.dolls:
		record.dolls[id].fray = int(record.dolls[id].fray)
	return record


static func save_file(path: String, record: Dictionary) -> bool:
	if path.is_empty() or not valid(record):
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(record))
	return true
