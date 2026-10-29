extends TestCase
## The font fallback chain (T6.6): Bengali and CJK text is drawn by fonts the game ships, not by
## whatever fonts the player's OS happens to have.
##
## WHAT THIS CASE CANNOT DO, SAID FIRST. It cannot say the text LOOKS right: `--headless` shades
## nothing. The look was proved by a windowed capture with system fallback switched OFF on every
## font, before and after, and the DEVLOG entry has the command. The capture was needed because a
## Windows machine carries Nirmala UI and YaHei, so with system fallback on the "before" showed no
## tofu at all. That is the defect: a game that renders on the developer's machine and boxes on a
## player's.
##
## WHAT IT CAN DO IS MORE THAN AN ORDER CHECK. Shaping runs headless (HarfBuzz is not the
## rasteriser), so the case shapes real strings through the chain and asks WHICH FONT each glyph
## came from. And a conjunct is the proof that shaping happened, not merely lookup: ক্ষ is three
## code points and one glyph. Characters are written as code points so this file holds no
## player-facing literal.
##
## OWNS: the chain's order, what each link covers, the install rule, and that the theme names no
## font (the fresh-clone `Parse Error` this row found).
## MUST NOT: assert what text looks like, or name demo content.

const CHAIN_PATH: String = UiRoot.FONT_CHAIN_PATH
const THEME_PATH: String = "res://assets/theme/ui_theme.tres"
const BENGALI_PATH: String = "res://assets/fonts/NotoSansBengali-Variable.ttf"
const CJK_PATH: String = "res://assets/fonts/NotoSansSC-SemiBold-subset.ttf"
const LICENCES: Array[String] = [
	"res://assets/fonts/NotoSansBengali-OFL.txt",
	"res://assets/fonts/NotoSansSC-OFL.txt",
]
const SIZE: int = 32

## BENGALI KA, VIRAMA, SSA: the conjunct ক্ষ, one glyph when shaped.
const KSSA: Array[int] = [0x0995, 0x09CD, 0x09B7]
## Two hanzi, then two katakana: the subset carries both, because "CJK" is not only Chinese.
const HANZI: Array[int] = [0x73AB, 0x7470]
const KANA: Array[int] = [0x30D0, 0x30E9]
const LATIN: Array[int] = [0x61, 0x62, 0x63]

var _chain: FontVariation = null


func run() -> void:
	plan(25)
	_the_chain_names_bengali_then_cjk()
	_each_link_covers_its_script_and_the_engine_font_does_not()
	_shaping_takes_each_glyph_from_the_right_font()
	_the_theme_names_no_font()
	_the_install_rule()
	_each_font_has_its_licence_beside_it()


func _the_chain_names_bengali_then_cjk() -> void:
	_chain = load(CHAIN_PATH) as FontVariation
	equal("the chain is a FontVariation", _chain != null, true)
	if _chain == null:
		return
	# No base font: the engine's own Latin draws first, exactly as before the chain existed.
	equal("the chain has no base font, so Latin is unchanged", _chain.base_font == null, true)
	equal("the chain has two fallbacks", _chain.fallbacks.size(), 2)
	equal("fallback 0 is the Bengali font", _path_of(_chain.fallbacks[0]), BENGALI_PATH)
	equal("fallback 1 is the CJK subset", _path_of(_chain.fallbacks[1]), CJK_PATH)


func _each_link_covers_its_script_and_the_engine_font_does_not() -> void:
	if _chain == null or _chain.fallbacks.size() < 2:
		return
	var engine: Font = ThemeDB.fallback_font
	# The "before", as an assertion: without the chain, nothing bundled has these.
	equal("the engine font has no Bengali", engine.has_char(KSSA[0]), false)
	equal("the engine font has no hanzi", engine.has_char(HANZI[0]), false)
	equal("the Bengali link has Bengali", _chain.fallbacks[0].has_char(KSSA[0]), true)
	equal("the CJK link has hanzi", _chain.fallbacks[1].has_char(HANZI[0]), true)
	equal("the CJK link has kana", _chain.fallbacks[1].has_char(KANA[0]), true)


func _shaping_takes_each_glyph_from_the_right_font() -> void:
	if _chain == null or _chain.fallbacks.size() < 2:
		return
	var bengali: Array[RID] = _chain.fallbacks[0].get_rids()
	var cjk: Array[RID] = _chain.fallbacks[1].get_rids()
	var engine: Array[RID] = ThemeDB.fallback_font.get_rids()
	var kssa: Array[Dictionary] = _shape(KSSA)
	equal("the conjunct shapes to ONE glyph from three code points", kssa.size(), 1)
	equal("the conjunct comes from the Bengali font", _all_from(kssa, bengali), true)
	var hanzi: Array[Dictionary] = _shape(HANZI)
	equal("each hanzi is one glyph", hanzi.size(), HANZI.size())
	equal("the hanzi come from the CJK subset", _all_from(hanzi, cjk), true)
	equal("the kana come from the CJK subset", _all_from(_shape(KANA), cjk), true)
	# Order matters where fonts overlap: the Bengali font carries Latin too, and must not win it.
	equal("Latin still comes from the engine font", _all_from(_shape(LATIN), engine), true)


## The theme loads at engine start, before a fresh clone's first scan imports a font. A font
## named here printed `Parse Error: [ext_resource] referenced non-existent resource` on the first
## `--import`, which is CI's rung 2. Read from DISK, since UiRoot has installed the chain into the
## copy in memory.
func _the_theme_names_no_font() -> void:
	var text: String = FileAccess.get_file_as_string(THEME_PATH)
	equal("the theme file was read", text.is_empty(), false)
	equal("the theme names no font file", text.contains("FontFile"), false)
	equal("the theme sets no default font", text.contains("default_font ="), false)


func _the_install_rule() -> void:
	var fresh: Theme = Theme.new()
	equal("a theme without a font gets the chain", UiRoot.install_font_chain(fresh, CHAIN_PATH), true)
	equal("  and its default font is the chain", _path_of(fresh.default_font), CHAIN_PATH)
	# A game that set real type did it on purpose; the chain must not overwrite it.
	var own: Theme = Theme.new()
	var mine: FontVariation = FontVariation.new()
	own.default_font = mine
	UiRoot.install_font_chain(own, CHAIN_PATH)
	equal("a theme with its own font keeps it", own.default_font == mine, true)
	equal("no theme is not an error", UiRoot.install_font_chain(null, CHAIN_PATH), false)
	# A game that deleted the fonts draws as it did before the chain, and does not crash.
	var bare: Theme = Theme.new()
	UiRoot.install_font_chain(bare, "res://assets/fonts/absent.tres")
	equal("a missing chain leaves the theme without a font", bare.default_font == null, true)


func _each_font_has_its_licence_beside_it() -> void:
	var found: int = 0
	for path: String in LICENCES:
		if FileAccess.get_file_as_string(path).contains("SIL Open Font License"):
			found += 1
	equal("both fonts have their OFL beside them", found, LICENCES.size())


func _shape(code_points: Array[int]) -> Array[Dictionary]:
	var text: String = ""
	for code_point: int in code_points:
		text += String.chr(code_point)
	var line: TextLine = TextLine.new()
	line.add_string(text, _chain, SIZE)
	return TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())


func _all_from(glyphs: Array[Dictionary], rids: Array[RID]) -> bool:
	if glyphs.is_empty():
		return false
	for glyph: Dictionary in glyphs:
		var rid: Variant = glyph.get("font_rid")
		if not rid is RID or not rids.has(rid):
			return false
	return true


## A fallback may be a FontVariation over the file (the Bengali one is, to ask for weight 600),
## so the path is looked for through `base_font`.
func _path_of(font: Font) -> String:
	if font is FontVariation and (font as FontVariation).base_font != null:
		return _path_of((font as FontVariation).base_font)
	return font.resource_path if font != null else ""
