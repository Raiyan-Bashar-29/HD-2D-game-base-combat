extends TestCase
## A COUNT THAT REACHES A STRING PICKS ITS PLURAL FORM.
##
## WHY THIS CASE EXISTS
## `RestPoint` put `{hours}` = `floori(minutes / 60)` into one localization key, so a rest under
## two hours read "1 hours slip past", and one under an hour read "0 hours" - after the clock had
## moved. T6.6's `tr_n` check found it. It was the only count in the base with a noun beside it:
## `x{count}`, `{have} / {need}` and `{percent}%` carry none, and a noun is what a count agrees
## with. English has two forms; Bengali and Chinese have one; Polish and Arabic have more, so
## the choice is the engine's `translate_plural` against the locale's rule, never an `if n == 1`.
##
## HOW THE LINE IS READ
## The toast is rendered here exactly as `notification_toast.gd` `_show_next()` renders it,
## `tr(key).format(args)`, from what `RestPoint` actually emitted. So the assertion is the text a
## player would read, and it held on the old code as well, which is how it was proved red.
##
## THE FIXTURE TRANSLATION is built here, not read from the CSV: `tests/` may not name a demo
## key (`check_boundary.gd`). The CSV half is a lint over every row that uses `{hours}`, which is
## `RestPoint`'s placeholder and not content, so it finds nothing in a stripped template and the
## plan is computed from the rows it finds.
##
## OWNS: that a rest's toast agrees with its count, and that every `{hours}` row has a plural form.
## MUST NOT: assert the wording of any row, or the plural rule of any locale but English.

const CSV: String = "res://localization/strings.csv"
const PLURAL_COLUMN: String = "?plural"
const PLACEHOLDER: String = "{hours}"
const KEY: String = "fixture.rest_point.rested"
const PLAIN_KEY: String = "fixture.rest_point.rested_plain"
const ONE: String = "{hours} hour slips past."
const OTHER: String = "{hours} hours slip past."

## Each entry is [key, has a plural column value, has a continuation row].
var _rows: Array[Array] = []
var _toasts: Array[String] = []
var _previous_locale: String = ""
var _fixture: Translation = null


func run() -> void:
	_gather()
	plan(9 + _rows.size() * 3)
	_install_fixture()
	var bench: RestPoint = _make_bench()
	Events.notify_requested.connect(_on_notify)
	_rests_read_as_a_player_reads_them(bench)
	bench.rested_key = ""
	_toasts.clear()
	bench.attempt(null)
	equal("a rest with no rested_key raises no toast", _toasts.size(), 0)
	Events.notify_requested.disconnect(_on_notify)
	bench.free()
	_remove_fixture()
	_every_hours_row_has_a_plural_form()


func _rests_read_as_a_player_reads_them(bench: RestPoint) -> void:
	equal("one hour is singular", _rest(bench, 19, 0), "1 hour slips past.")
	equal("two hours are plural", _rest(bench, 18, 0), "2 hours slip past.")
	equal("half an hour reads as one hour, not zero", _rest(bench, 19, 30), "1 hour slips past.")
	equal("one minute still reads as one hour", _rest(bench, 19, 59), "1 hour slips past.")
	equal("ninety minutes round to two", _rest(bench, 18, 30), "2 hours slip past.")
	equal("eighty-nine minutes round to one", _rest(bench, 18, 31), "1 hour slips past.")
	equal("a night's sleep is plural", _rest(bench, 7, 0), "13 hours slip past.")
	# A game's existing row with no plural column still gets its count: translate_plural on a
	# plain message returns that message for any n.
	bench.rested_key = PLAIN_KEY
	equal("a plain row still carries the count", _rest(bench, 17, 0), "3 hours slip past.")


## Rest from `hour`:`minute` to the bench's 20:00 and return the one toast it raised.
func _rest(bench: RestPoint, hour: int, minute: int) -> String:
	_toasts.clear()
	Clock.set_time(1, hour, minute)
	bench.attempt(null)
	return "" if _toasts.size() != 1 else _toasts[0]


## notification_toast.gd `_show_next()`, verbatim.
func _on_notify(key: String, _seconds: float, args: Dictionary) -> void:
	_toasts.append(tr(key).format(args))


func _install_fixture() -> void:
	_previous_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_fixture = Translation.new()
	_fixture.locale = "en"
	_fixture.add_plural_message(KEY, PackedStringArray([ONE, OTHER]))
	_fixture.add_message(PLAIN_KEY, OTHER)
	TranslationServer.add_translation(_fixture)


func _remove_fixture() -> void:
	TranslationServer.remove_translation(_fixture)
	_fixture = null
	TranslationServer.set_locale(_previous_locale)


func _make_bench() -> RestPoint:
	var bench: RestPoint = build("res://scenes/objects/rest_point.tscn") as RestPoint
	bench.label_key = "fixture.rest_point.label"
	bench.target_hour = 20
	bench.rested_key = KEY
	attach(bench)
	return bench


## A `{hours}` row must name a plural key in the importer's `?plural` column and be followed by
## a row with an empty key, which is where the importer reads the second form from. And the
## imported translation must then answer differently for one and for two.
func _every_hours_row_has_a_plural_form() -> void:
	for row: Array in _rows:
		var key: String = row[0]
		equal("%s names a plural key in %s" % [key, PLURAL_COLUMN], row[1], true)
		equal("%s is followed by its second form" % key, row[2], true)
		# A missing form comes back as the key itself, which also differs from the singular, so
		# neither answer may be the key. A plant that deleted the second form passed without this.
		var one: String = TranslationServer.translate_plural(key, key, 1)
		var two: String = TranslationServer.translate_plural(key, key, 2)
		equal("%s has two translated forms that differ" % key,
				one != two and one != key and two != key, true)


func _gather() -> void:
	var file: FileAccess = FileAccess.open(CSV, FileAccess.READ)
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	var plural: int = header.find(PLURAL_COLUMN)
	var pending: Array = []
	while not file.eof_reached():
		var line: PackedStringArray = file.get_csv_line()
		if line.size() < 2:
			continue
		if not pending.is_empty():
			pending[2] = line[0] == ""
			_rows.append(pending)
			pending = []
		if line[0] == "" or not ",".join(line).contains(PLACEHOLDER):
			continue
		pending = [line[0], plural >= 0 and plural < line.size() and line[plural] != "", false]
	if not pending.is_empty():
		_rows.append(pending)
	file.close()
