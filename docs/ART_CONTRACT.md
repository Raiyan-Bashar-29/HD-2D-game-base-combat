# The art contract

**This template ships a contract art must satisfy, never art.** Every system runs on the
procedural placeholders in `assets/placeholder/`, indefinitely, and a consuming game brings its
own. This document is what your art has to be shaped like for it to drop in without a code change.

Nothing here requires editing `src/`. If satisfying one of these seams seems to, that is a bug in
the seam.

---

## Character sprite sheets

### The grid

**Facings across, frames down, and the rows grouped into animation blocks.**

```
facings = 4, frames = 3, animations = 2, idle_row = 0, walk_row = 1

        col 0    col 1    col 2    col 3
row 0   idle.0   idle.0   idle.0   idle.0     <- animation 0 (idle), frame 0
row 1   idle.1   ...                          <- animation 0, frame 1
row 2   idle.2   ...                          <- animation 0, frame 2
row 3   walk.0   ...                          <- animation 1 (walk), frame 0
row 4   walk.1   ...
row 5   walk.2   ...
```

So the sheet is `facings` cells wide and `frames * animations` cells tall, and an animation is
addressed by **index**, not by its first row — move the walk block down and you do not recount.

`animations = 1` with every row field at `0` or `-1` is a single-cycle sheet: no separate idle
and no separate gaits. That
is legal, it is what this project shipped before the layout resource existed, and every such sheet
still works unchanged.

### The declaration

One `.tres` beside the texture:

```
[gd_resource type="Resource" script_class="SpriteSheetLayout" load_steps=2 format=3]

[ext_resource type="Script" path="res://src/content/art/sprite_sheet_layout.gd" id="1_layout"]

[resource]
script = ExtResource("1_layout")
facings = 8
frames = 4
animations = 4
cell_size = Vector2i(32, 48)
idle_row = 0
walk_row = 1
run_row = 2
sneak_row = -1
climb_row = -1
idle_break_row = 3
idle_break_after = 3.0
```

| Field | Means |
|---|---|
| `facings` | how many directions **the art** distinguishes. 1–32 |
| `frames` | cells down within one animation: the length of its cycle. 1–64 |
| `animations` | how many blocks are stacked down the sheet. 1–32 |
| `cell_size` | one cell in texture pixels |
| `idle_row` / `walk_row` | which block plays standing still, and which walking |
| `run_row` / `sneak_row` / `climb_row` | the other gaits. **-1 means "replay the walk block"** |
| `idle_break_row` / `idle_break_after` | the SECOND idle and how long standing starts it. **-1 and 0.0 mean "no second idle"** |

### A block per GAIT, and the ones you leave out

**Since 1.2.0 the block is chosen by what the character is DOING, not by whether it is moving.**
`SpriteSheetLayout.animation_for` takes a `GameEnums.MoveState`, so a sheet can carry a separate
cycle for each gait, and **every character in the game picks them up by asset swap with no code** —
the player and every NPC draw through the same `CharacterVisual`.

| Field | Means | Leave it at |
|---|---|---|
| `idle_row` | standing still | `0` |
| `walk_row` | walking | its own block if you have one |
| `run_row` | running | **`-1`** to replay the walk block |
| `sneak_row` | sneaking | **`-1`** to replay the walk block |
| `climb_row` | on an authored climb | **`-1`** to replay the walk block |

**`-1` means "replay the walk block", and it is the default for a reason.** A sheet that names none
of the three behaves exactly as every sheet did before 1.2.0, when `animation_for` took a boolean
and run and sneak had nowhere to go. So you can ship one walk cycle and add a run later by drawing
one and naming its row — nothing else changes, in your project or in the base.

**`0` would have been the wrong default.** Row 0 is a real row — normally the idle block — so a
default of `0` would have drawn a *standing* character for anything running, on every sheet that
had not been updated. `-1` is the only value that can mean "I have not drawn this".

**States with no gait of their own fall back to idle**, not to walk: `JUMP`, `FALL`, `SWIM`, `BUSY`
and `LOCKED`. There is no jumping and no swimming in this template; `BUSY` and `LOCKED` mean
something else is driving the character — a dialogue box, a cutscene — which looks like standing
there rather than walking on the spot.

**A row past the end of the sheet is a reported problem**, not a silent clamp. `problems()` names
the field — `names run_row row 9, past its 3 animation(s)` — because the draw call clamps to the
last block, so without the report a mis-typed row animates plausibly and wrongly. That is gotcha
38's shape: a number the loader kept and nobody checked.

**The cell size is declared, not divided out of the texture.** A sheet of the wrong size is then a
named problem — `expects a (256, 192) sheet; the texture is (240, 192)` — instead of every
character in the game being silently misplaced by a few pixels.

**A facing is not a column.** `GameEnums.Facing` has eight values because eight is how many
directions the *game* reasons about; `facings` is how many the *art* distinguishes. The two are
quantised separately from the same angle, and the sector width is derived — `TAU / facings` — so
there is no second place holding the number.

### A SECOND idle, and the thing that chooses it

**Since 5.3.0 a character does not have to stand in exactly one way.** Draw a second idle block —
a stretch, a glance around, a shifted weight — name its row, and say how long the character stands
before it plays:

```
idle_break_row = 3        # the block, addressed by INDEX like every other row
idle_break_after = 6.0    # seconds of UNBROKEN standing before it plays
```

**It plays once and hands back** to `idle_row`. So draw it as a self-contained gesture that starts
and ends in the same pose the idle block holds — if the first and last cells do not match your
idle, the hand-back will read as a snap.

**The gap you author is the gap a player sees.** The dwell restarts from the END of the break, not
from its start, so `idle_break_after = 6.0` means six seconds of standing between two fidgets
rather than six seconds minus however long your block takes to play.

**MOVING CANCELS IT IMMEDIATELY AND RESETS THE CLOCK.** A fidget is what a character does instead
of standing there, so a player who walks off mid-stretch gets the walk block on that same frame,
and then has to stand still all over again. Interrupted standing does not accumulate — a character
who paces will not fidget on a schedule you did not author.

**Why dwell time and not the weather, the hour, or the area.** Those were the other candidates, and
they are not available at this seam: `SpriteSheetLayout` may not touch an autoload, and
`CharacterVisual` is *told* a velocity and a state — it does not read the clock. Dwell is the one
trigger derivable from what the visual already has every frame. **You have not lost the others**: a
rain idle or a night idle is a `GameEnums.MoveState` your game pushes, or a different layout
resource you swap in, and neither needs a line of base code.

**Name both fields or neither**, and `problems()` will tell you if you name one:

| What you wrote | What it says |
|---|---|
| a row, no delay | `names idle break row 3 but never lets it start` |
| a delay, no row | `waits 6.0s for an idle break it names no row for` |
| the break AT `idle_row` | `breaks its idle to row 0, which is its idle block` |

All three draw exactly what your sheet drew before while looking configured, which is why they are
reported rather than tolerated — gotcha 38's shape three more times.

**A sheet that names neither is complete.** `-1` and `0.0` are the defaults, every sheet authored
before 5.3.0 has them, and such a character stands the way it always did. The shipped
`character_alt_layout.tres` deliberately names neither, so the default stays exercised on a layout
that names all five gaits.

### Wiring a sheet in

Two `ExtResource` paths on a `CharacterVisual` node, and nothing else:

```
[node name="Visual" type="Node3D" parent="."]
script = ExtResource("2_vis")
texture = ExtResource("3_tex")
layout = ExtResource("6_layout")
```

The layout is **per node**, not global: the player and each NPC may use different sheets with
different geometry in the same scene. Also on `CharacterVisual`, and independent of the sheet:
`pixel_size` (world scale), `walk_fps`, `reference_speed`, `ground_offset`.

**An unwired `layout` is legal and loud.** `CharacterVisual` falls back to 8×4 on a 32×48 cell and
warns, naming the node. That fallback exists so a node stays recognisable while the log says it is
unwired; nothing should rely on it.

### What the engine does with the sheet

`Sprite3D` is configured with `billboard = BILLBOARD_FIXED_Y` (upright, turns only around Y),
`alpha_cut = ALPHA_CUT_DISCARD` (so the sprite is opaque geometry that sorts by depth and casts a
real shadow), `texture_filter = NEAREST`, and `shaded = true` (so a character under a lantern is
actually lit). Those are the HD-2D look and they are not negotiable per sheet.

Practically, that means **your art needs hard alpha**, not soft edges: anything below the discard
threshold disappears rather than fading. Which is the correct trade for pixel art and the wrong
one for anything painted.

### Import settings

**You do not have to touch a `.import` file.** `project.godot` carries an `[importer_defaults]`
section, so a PNG dropped into this project imports correctly the first time:

```
[importer_defaults]

texture={
"detect_3d/compress_to": 0
}
```

Exactly one value is set, because exactly one was wrong by default. `detect_3d/compress_to=0`
disables the editor's *"this texture was used in 3D, so switch it to VRAM compression"* rewrite.
Every character sheet in an HD-2D game **is** used in 3D, through `Sprite3D`, so at the stock value
of `1` a re-import puts block artefacts through your pixel art — silently, and only in the picture.
The committed `.import` files carry `0` as well, so the hazard is closed for what is already here
and for whatever you import next. Everything else — `compress/mode=0` (lossless),
`mipmaps/generate=false`, `process/fix_alpha_border=true` — is already Godot's own default for a
2D texture and needs no help.

**This section is undocumented and does not appear in `--doctool`**, which is why the template went
five packages without one: the project rule is to check every name against the API dump, and for
this there is no dump to check. It is written on a **measurement** instead. A throwaway texture was
imported with stock defaults, the section was added, its `.import` was deleted, and
`--headless --import` regenerated it carrying the values set here — `detect_3d/compress_to` moved
`1 → 0` and a control value `mipmaps/generate` moved `false → true`. The key is the **importer's**
name (`texture`), the value is a Dictionary of param paths, and
`ProjectSettings.get_setting("importer_defaults/texture")` reads it back at runtime. A test asserts
that, and asserts every committed `.import` agrees, so an editor session that clears the section
fails the suite rather than a screenshot six months later.

### The two placeholders, and why one of them counts its own cells

- `character_placeholder.png` — 8 facings × 4 frames in **3** blocks (idle, walk, run),
  32×48 cells. 256×576. Each block wears a different cloth tint and the run leans forward,
  so which GAIT is drawn can be READ off a capture rather than guessed at — see the
  labelling note below, and gotcha 28 for why that matters.
- `character_alt.png` — 4 facings × 3 frames in **5** blocks (idle, walk, run, sneak, climb),
  24×40 cells. 96×600. It disagrees with the first on every number, and exists so the "swap a
  sheet, change no code" claim can be demonstrated rather than asserted. **It is also the only
  layout in the project that leaves no gait at `-1`**, so it is the only one that draws a sneak
  and a climb from rows of their own rather than from the walk block.

**Every cell of the alt sheet labels itself**, and the reason generalises to any art you make for
testing this seam. A day/night system that lights nothing is at least obviously wrong on screen; a
character drawn from the *wrong cell* still looks like a character — upright, lit, facing *some*
direction. So a capture of it cannot be judged, it has to be **read**. Each cell carries three
tallies: `column + 1` yellow pips down its left edge, `frame + 1` across its foot, and
`block + 1` **white** pips down its right edge. Two left pips, two foot pips and four right pips
on a purple crouching body is column 1, frame 1, block 3 — index `(3*3 + 1) * 4 + 1 = 41` — and no
amount of plausible pixel art fakes that number.

Two things about those tallies that cost an hour each, and both are in your way if you make a
sheet of your own. The foot tally sits at `cell.y - 7` and not at the very bottom, because a
sprite anchored by its feet has its last rows **occluded by the ground plane** and a tally drawn
there photographs short (gotcha 58). And nothing may overrun its cell: the generator's `_plot`
clips to the image rather than to the cell, so a stride that reaches past the bottom row draws a
stray limb above the head of the block below (gotcha 57). `character_swap_test.gd` asserts both.

### Performing the swap yourself

This is the whole of it, and it is worth doing once on your own sheet before you trust it:

```
# scenes/characters/player.tscn — two lines, and nothing else anywhere
[ext_resource type="Texture2D" path="res://assets/placeholder/character_alt.png" id="3_tex"]
[ext_resource type="Resource" path="res://assets/placeholder/character_alt_layout.tres" id="6_layout"]
```

Then photograph it, because `--headless` shades nothing:

```
godot_console --resolution 960x540 --quit-after 600 -- --new-game --time=13:00 --freeze-time \
    --gait-shots=<dir>
```

That drives the character through all five gaits through the real input path, writes a full frame
and an ×5 nearest-neighbour crop for each, and logs the block, column and cell decoded out of
`sprite.frame`. **Check that the log and the pips agree** — the number without the picture does
not prove it reached a screen, and the picture without the number does not prove it was the right
cell. T5.6 wrote its run to `user://shots/gaits/`; captures are not committed on this project, so
re-take them with the command above rather than looking for a PNG. Run it once on the default
sheet too: there, sneak and climb both draw block 1, because that sheet leaves their rows at
`-1`.

### Every facing is a different figure, and until T5.8 none of them was

Both sheets drew **one pose per gait, repeated across every column**. Measured over the figure
band, `character_placeholder.png`'s back view differed from its front by **0.7%** of a cell — the
two eyes and nothing else — and facings 2 and 3 were byte-identical; three of the alt sheet's four
columns differed only by their column tally. The facing CODE was correct the whole time, so a
system asserted at both ends was invisible on screen for five phases and the first observer was an
owner playing the game (gotcha 62).

**What a facing has to show, and it is the low bar rather than a style.** Front, three-quarter,
side and back should tell themselves apart at a glance. The placeholders do it with five poses:
the torso narrows and steps forward as the figure turns, the legs close into a front-to-back
stride, the hair wraps further round the head, the eyes go 2, 2, 1, 0, 0, a profile grows a nose
past the edge of the face and hides its far arm, and a back is drawn in its own shadow. **The west
half of each sheet is the east half mirrored** — that is what makes east differ from west by a
whole asymmetric figure rather than by which shoulder a mark sits on.

`tests/unit/sheet_facings_test.gd` holds the line: **every facing of a shipped sheet must differ
from every other by more than 5% of the cell**, same block and same frame, measured over the
figure with four columns ignored down each edge (the alt sheet's pip tallies live there and are
deliberately not mirrored). The floor was picked by measurement — the old sheets' best pair was
3.5% and the new sheets' worst is 7.5%. If you add your own sheets to that case, note that two
transparent pixels count as the same pixel: `process/fix_alpha_border` rewrites the RGB under
transparency at import, so an imported sheet is not the PNG (gotcha 63).

And photograph it, because the assertion only says the cells are DIFFERENT and not that the pose
matches the direction — no pixel test can say that:

```
godot_console --resolution 960x540 --quit-after 600 -- --new-game --time=13:00 \
    --freeze-time --facing-shots=<dir>
```

That walks the character north, east, south and west and writes a full frame, an ×5 crop and the
decoded column for each. On the base at T5.8 those were columns 4, 2, 0 and 6, reading as a back
with no face, a right profile, a front and the same profile mirrored.

Regenerate both sheets with `tools/gen_placeholders.gd`.

---

## The UI look

### One file

`assets/theme/ui_theme.tres`, wired as `gui/theme/custom` in `project.godot`. That setting is what
makes it resolve from **any** `Control` in the tree, including the HUD, which is drawn under
`UiRoot` and would be missed by handing the theme to the screen stack. No screen is ever handed a
theme.

A consuming game replaces this file, or points `gui/theme/custom` at its own. Setting
`default_font` here is how real type arrives when art stops being deferred. Nothing in `src/`
changes. A theme that sets one opts out of the template's fallback chain, and must give its font
its own fallbacks. The next section explains.

### The three-way split, and why it is not the obvious design

**A `Theme` resource has no variables.** Items are stored per type with no reference between them,
so the natural-looking design — where `TitleText` carries both its `font_size` and its
`font_color` — writes the accent colour into as many variations as use it, and "one edit restyles
every screen" becomes false the moment there are two.

So:

| Part | Carries | Read by a screen as |
|---|---|---|
| Type variations (`TitleText`, `MenuRow`, `DialogueText`, …) | **only** `font_size` — the one thing that genuinely differs by role | `control.theme_type_variation = &"TitleText"` |
| `UiPalette` | the four colours, once each: `text`, `accent`, `dim`, `solid` | `get_theme_color(&"accent", &"UiPalette")` |
| `UiMetrics` | the six insets and separations: `margin`, `side_margin`, `box_margin`, `separation`, `row_separation`, `tight_separation` | `get_theme_constant(&"margin", &"UiMetrics")` |

`dim` is translucent, for a panel over a live or frozen world; `solid` is opaque, for a panel with
nothing behind it that must also cover the HUD.

A test case fails if any styled screen writes a `Color(` or an `add_theme_font_size_override` back
down into itself. The look reached five files one reasonable line at a time once already, and
nothing but a check stops it going back.

### Restyling

Edit that one file. Six lines is a complete change of look: the palette's four colours, a metric,
a title size. This was demonstrated with captures before and after — the main menu and the
inventory screen both restyled, and the HUD clock followed without being mentioned.

### The five states of a row — closed at 4.2.0, and derived rather than authored

**Until 4.2.0 the theme set font sizes for `MenuRow` and `ChoiceRow` and no styleboxes at all, so
every menu row and every dialogue reply drew Godot's fallback panel** — invisible against the
shipped near-black palette, and immediately wrong against a light one. It was declared here for
four packages, on the reasoning that a stylebox has to be *designed* and the only palette to
design against was the placeholder one.

**`src/ui/root/ui_row_styles.gd` closes it without designing a colour.** It designs the
*relationship* between the five states and takes every colour from the palette:

| State | Is | Why |
|---|---|---|
| `normal` | `surface` | the new palette entry, and the only one this reads at rest |
| `hover` | `surface` toward `text` | **directional**: lightens a dark row, darkens a light one, from one expression |
| `pressed` | `surface` toward `accent` | a press is an act, so it takes a hue rather than another shade |
| `disabled` | `surface` at 35% alpha | the same row faded, not a different one |
| `focus` | `accent` ring, **no centre** | composes with whichever of the other four is under it |

`_mirrored` (right-to-left layouts) and `hover_pressed` are set to the same boxes, because left
unset they are the two ways back to the fallback bar from inside a fully styled menu.

**So restyling a row is still an edit to `ui_theme.tres` and nothing else.** Change
`UiPalette/colors/surface` and the four other palette entries; the five states follow, and so do
the font colours, which were the other half of the light-palette defect — an unset `font_color`
takes the fallback theme's near-white, which is invisible on a pale ground whatever the boxes do.

**Two ways out, both deliberate.** A variation that declares its own `styles/normal` is left
completely alone — a game that authored its own rows has already made this decision. And a
palette with no `surface` entry is left alone entirely, with one `WARN` at boot: there is nothing
to derive from, and inventing a surface would be the base picking a colour for you after all.
Deleting the `UiRowStyles` node from `game_root.tscn` is the third.

**What has NOT changed is that the base has no look.** `surface` is a placeholder like every
other colour in that palette. What 4.2.0 removed is not the need to choose one — it is the
possibility of choosing one and finding the rows ignored it.

### Fonts, and the fallback chain — T6.6

**Text in any script the base ships a font for renders, and does not depend on the player's OS.**
The engine's default font covers Latin, Greek and Cyrillic and nothing else. Before 5.11.0 a
Bengali or Chinese string reached the screen only if the player's OS supplied a font for it. That
worked on the machine it was written on: Windows carries Nirmala UI and YaHei, and the first
capture of this row showed no tofu at all. On a machine without those fonts every glyph was a box.
The capture with system fallback switched off showed exactly that.

| File | What it is |
|---|---|
| `assets/fonts/font_chain.tres` | a `FontVariation` with **no base font**, and `fallbacks = [Bengali, CJK]`, in that order |
| `assets/fonts/NotoSansBengali-Variable.ttf` | Noto Sans Bengali 3.011, unmodified, variable (`wght`, `wdth`), asked for weight 600 by the chain. 464 KB |
| `assets/fonts/NotoSansSC-SemiBold-subset.ttf` | Noto Sans SC 2.004, **subset and pinned at weight 600** by the recipe below. 2.8 MB, from 17.8 MB |
| `assets/fonts/*-OFL.txt` | each font's SIL Open Font License, beside it |

**No base font is deliberate.** Latin is still drawn by the engine's own font, so nothing that
rendered before moved. A glyph that font lacks is looked up in the fallbacks in order. The Bengali
font also carries Latin, and the order keeps it from winning that. **Weight 600 is also
deliberate:** the engine's default is Open Sans SemiBold, and the first capture at Regular drew
every Bengali line visibly lighter than the Latin beside it.

**Why the chain is its own file, and not a line in the theme.** This was measured, not chosen. The
project theme loads at engine start, before the first filesystem scan. On a fresh clone the fonts
are not imported yet, so a theme naming them printed `Parse Error: [ext_resource] referenced
non-existent resource` on the first `--import`. That is CI's rung 2, and it is also a consumer's
first open. So the theme names no font, and `UiRoot.install_font_chain()` puts the chain into the
project theme at boot. A `Label` already on screen picks it up.

**The rule a game meets:**

- **Keep the chain:** leave `default_font` unset in your theme. To add a script (Arabic, Hangul,
  Devanagari), append its font to `fallbacks` in `font_chain.tres`. Put it first if it shares code
  points with a link and must win them.
- **Bring your own type:** set `default_font` in your theme. `install_font_chain` then leaves it
  alone, and **your font needs its own `fallbacks`**, or Bengali and CJK return to depending on the
  player's OS.
- **Drop a script:** delete its font and its entry in the chain. `tests/unit/font_chain_test.gd`
  will name what went, because it asserts both links. Replacing that assertion is then a game's
  edit to a template test, the same way a stripped template deletes the demo.

**The CJK subset, and how to re-cut it.** Chinese from GB2312 (all 6,763 hanzi), Japanese from JIS
X 0208 level 1 (2,965 kanji) plus the first row of level 2 (94 more, because Shift-JIS lead
byte `0x98` holds both; 1,117 of the 3,059 are not in GB2312), all kana, CJK symbols and punctuation, and full/half-width forms:
8,392 code points and 9,227 glyphs, with every OpenType layout feature kept. **Hangul is not in
it.** Noto Sans SC is a Chinese-first design, so a game shipping Korean or Japanese as a primary
language should swap in Noto Sans KR or JP, cut the same way. The recipe, using fontTools 4.66:

```python
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools import subset
# cps = the code points above: decode every GB2312 pair in 0xB0-0xF7 x 0xA1-0xFE, every
# Shift-JIS pair in 0x88-0x98 x 0x40-0xFC, then add U+3000-30FF, U+31F0-31FF and U+FF00-FFEF.
font = instancer.instantiateVariableFont(TTFont("NotoSansSC[wght].ttf"), {"wght": 600}, updateFontNames=True)
options = subset.Options(); options.layout_features = ["*"]; options.name_IDs = ["*"]; options.notdef_outline = True
subsetter = subset.Subsetter(options); subsetter.populate(unicodes=cps); subsetter.subset(font)
font.save("NotoSansSC-SemiBold-subset.ttf")
```

The sources are `github.com/google/fonts`, `ofl/notosansbengali/` and `ofl/notosanssc/`. **The
licence allows the subset.** The OFL permits modified versions provided they do not use a Reserved
Font Name. The only one in Noto Sans SC's licence is `Source`, and the subset keeps the name Noto
Sans SC. **An export carries the licence without an `include_filter`,** because both fonts hold it
in their `name` table (IDs 13 and 14), which the OFL accepts as machine-readable metadata. A
credits screen naming them is a game's choice.

**What this does not do, stated so nobody looks for it.** It does not provide right-to-left
layout, which T6.0 deferred until a real game needs one. It does not provide a Bengali or CJK
LOCALE: `strings.csv` still has `en` and `en_XA`, and a game adds the column. It does not provide
plural forms, whose one real need T6.6 found and recorded as its own row.
---

---

## The look of an area

Three seams, and none of them is code. All three were opened by T3.2, and each was demonstrated
with a before/after windowed capture in which **one edit to one file** was the only difference.

### Shared materials

`assets/materials/` holds `StandardMaterial3D` resources that more than one area points at:

```
[node name="Mesh" type="MeshInstance3D" parent="Terrain/Dais"]
mesh = SubResource("mesh_pillar")
surface_material_override/0 = ExtResource("6_wood")
```

…where `6_wood` is `[ext_resource type="Material" path="res://assets/materials/wood.tres" …]`.
Edit that one file and every area using it changes. Drop your own `.tres` in that folder, or
replace the texture the shipped one names.

**Share a material when two areas genuinely want the same thing, and not before.** The template
ships exactly one, and the other five materials in the two demo areas are deliberately still
inline, because they are *not* duplicates: one area tiles stone at `uv1_scale (3, 3)` and the other
floors it at `(8, 8)` and walls it at `(6, 2)`. A tiling rate is a property of the surface it is
stretched over, not of the substance, so hoisting those would produce a shared file with a
per-area override on every user — the duplication with an extra indirection.

A test fails if **two areas declare the same material inline**, with `ExtResource` ids resolved to
paths so the comparison actually works. That is the defect this seam was built for: the two demo
areas each carried a byte-identical copy, invisible until someone read both files side by side.

Nothing in `src/` knows `assets/materials/` exists. A shared material is a scene-authoring
convention, not a system — no registry, no id, no directory scan.

**One thing that makes sharing safe**, and it was already true: `SurfaceWetness` *duplicates* every
material before it darkens it, so rain outdoors cannot leave an interior's floor wet on the far
side of an area change.

### The environment post stack

Every value in the HD-2D post stack — tonemap exposure, the seven glow numbers, depth fog,
volumetric fog, and the four expensive effects that are off — is an `@export` on the
`EnvironmentDriver` node in each area scene:

```
[node name="EnvironmentDriver" type="Node" parent="Environment"]
script = ExtResource("2_env")
follow_clock = true
volumetric_fog_density = 0.06
```

The defaults are exactly what the template shipped when these were literals, so an area that
leaves them alone renders identically. Per **area** rather than per project, because the driver
already lives in the area scene and its `Interior` group already varies that way: a game that
wants one look everywhere authors its areas from one copy, and a game that wants a bright market
and a smoky cellar has the seam without having asked for it.

What stays in code is the *structure* — which tonemapper, which fog mode, that ambient light comes
from a colour — because those are what the rest of the driver assumes rather than what an area
tunes. A test fails if a **number** is assigned to the environment anywhere in that file again.

The day/night keyframe table is a separate thing and is still a `const` in the driver. It is a
curve, not a look setting, and no seam has been claimed for it.

### Per-area camera framing

`HD2DCameraRig` has carried its framing as `@export`s since it was written; what was missing was
an area using them. Set them on the rig node in your area scene:

```
[node name="CameraRig" type="Node3D" parent="Camera"]
script = ExtResource("3_cam")
distance = 9.5
fov = 36.0
height_offset = 0.95
```

`distance`, `pitch_degrees`, `yaw_degrees`, `fov`, `height_offset`, `follow_lag`, `frame_bias`, and
the depth-of-field group. **A long lens from far away is most of the HD-2D look** — 25–30 degrees
at 12–16 metres — so treat the defaults as the house style and reframe where a space asks for it.
The demo's interior does: 36 degrees at 9.5 metres, because a room reads better close. Depth of
field is expressed *relative* to the target, so it follows a reframe without being retuned.

A test fails if a number is assigned to the camera or its attributes in the rig, and fails if **no
area authors its own framing** — a seam nothing uses is a seam nobody has tried.

---

## Button prompts

**Today a prompt names a button in WORDS, and that is complete, not a stub.** Since `5.7.0` the base
knows which device the player last used (`Actions.device()`, announced on
`Events.input_device_changed`), and the two prompts that name a button — the interact prompt and
the dialogue box's continue hint — ask `KeyBindings.text_for(action, pad)` for it: `[E]` on a
keyboard, the engine's name for the button on a pad. A rebind shows up there immediately, because
the words come from the binding and not from a string.

**An icon sheet replaces the words at exactly one seam, and it is `KeyBindings.text_for`.** Every
prompt that names a button goes through it, so an icon sheet is a lookup from the same two facts —
an action's binding and `Actions.device()` — to a cell, and nothing else in the UI has to learn that
icons exist. What it will need, so a sheet drawn now is not drawn twice:

- **One cell per physical button, not per action.** Rebinding moves an action to a different button;
  a cell drawn per action would be wrong the moment a player rebinds.
- **One sheet per pad family** — the south button is a cross on one pad and an A on another — so a
  sheet chooses its family from the connected pad's name, and a keyboard sheet is its own family.
- **The words stay as the fallback.** A button nobody drew a cell for must still be named, which is
  what `text_for` already does.

What does not exist yet, stated so nobody looks for it: the icon lookup itself, the per-family
choice, and a `RichTextLabel` prompt able to draw an image inline — the prompt is a `Label` today.
That work is a game's or a later row's, and none of it changes the seam above.

## What is deliberately not here

**No Git LFS, and this one is a refusal rather than an omission.** `.gitattributes` keeps the
`filter=lfs` line commented, and it should stay commented until you bring real art. Three reasons,
and the third is the one that decides it: LFS pointers for a 2 KB procedural placeholder are pure
overhead; enabling them puts the CI checkout on a dependency it does not currently declare
(`actions/checkout` needs `lfs: true`, and without it every PNG arrives as a text pointer and the
project fails to import); and **the template cannot verify the change it would be making** —
proving LFS works needs an LFS-enabled remote and a CI run against real binaries, neither of which
exists while art is deferred. A configuration nobody can test is exactly the change that looks
applied and does nothing, which is the failure this project is built to prevent. When you bring
art: uncomment the line, run `git lfs install`, and add `lfs: true` to the checkout step in
`.github/workflows/ladder.yml`.

**No audio assets.** The ambience bed runs on procedurally generated filtered noise, for the same
reason art is deferred.

## Read next

[`AUTHORING.md`](AUTHORING.md) · [`TESTING.md`](TESTING.md) · [`TEMPLATE.md`](TEMPLATE.md) ·
`src/content/art/sprite_sheet_layout.gd`, `assets/theme/ui_theme.tres` and
`assets/fonts/font_chain.tres` — all three headers are
written to be read by a consuming game, and go further than this document does.
