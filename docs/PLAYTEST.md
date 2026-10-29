# Playtest script

**What this is:** a play-through of the demo, about 30 minutes, that exercises every
player-facing system the base ships. Each step says what to do and what should happen. Tick it,
or write what happened instead. **Anything that surprised you is a finding, even if it is not
"broken".** A default that feels wrong is a defect too (`SYSTEMS_INVENTORY.md`, "Commonly
forgotten" #8).

**Who runs it:**
- the owner, on a real machine, with a gamepad if one is available;
- or, from a cloud session, a step can be photographed instead. Name the step, and the session
  runs the windowed capture under `xvfb-run` (`.claude/agent-notes.md`) with the debug flags
  `dev_capture.gd` documents. A capture can show a frame, but it cannot judge feel, so steps
  marked *(feel)* need a human.

**Launch:** open the project in Godot 4.7.2 and press Play, or run the editor binary with no
arguments. Use a **fresh** run: delete `user://` saves and settings first, so the first-run
defaults are what you see. On Windows, `%APPDATA%\Godot\app_userdata\<project name>`.

**Default controls** (`src/systems/input/actions.gd`; all rebindable):

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | WASD / arrows | left stick / d-pad |
| Run (hold) | Shift | LB |
| Sneak | Ctrl | L3 |
| Interact | E / Enter | A |
| Cycle interact target | Tab | RB |
| Cancel | Esc | B |
| Inventory / journal / map | I / J / M | Y / Back / — |
| Pause | Esc | Start |
| Debug console / freecam / perf / screenshot | F1 / F2 / F3 / F12 | — |

---

## 1. First run and the main menu

- [ ] The game opens on the main menu, with no error dialog and no frozen frame first.
- [ ] *(feel)* **First-run defaults (#8), judged before opening settings:**
  - [ ] music, ambience and effects volume are comfortable (defaults 0.9 master, 0.8 music);
  - [ ] the window mode is right for you (default: windowed);
  - [ ] the tilt-shift depth of field and bloom look good rather than blurry.
- [ ] Mouse, keyboard and gamepad can all move through the menu.

## 2. New game: the Rose Courtyard

- [ ] **New Game** fades into the courtyard. The area name is shown, and the clock and phase
  appear in the corner.
- [ ] *(feel)* Walk, run (hold Shift) and sneak. Speeds feel distinct, and the character faces
  the way it moves in all 8 directions.
- [ ] *(feel)* The camera follows smoothly. Zoom in and out if bound.
- [ ] Walking into walls, the dais riser and props never gets you stuck.

## 3. Things you can touch

- [ ] **Weathered Notice:** interact. Its text shows and closes cleanly.
- [ ] **Wicker Chest:** open it, and the contents go to your inventory with a notification.
- [ ] **Rose Key** pickup: it disappears from the world and appears in the inventory (I),
  under Key Items.
- [ ] **Iron Lever:** pull it ("heavy clack"), then pull it back. The **North Gate** responds.
- [ ] **Trellis Ladder:** climb it.
- [ ] Stand near two interactables. Tab / RB cycles the prompt between them.
- [ ] The interaction prompt shows **the key for the device you last touched**. Switch from
  keyboard to gamepad mid-play and the prompt changes.

## 4. The Garden-Keeper

- [ ] The keeper moves around on a schedule. Over time they never walk into a wall or freeze
  in place.
- [ ] **Talk** to them. The first greeting is "You are the first face…". Talk again and it is
  "Back again…".
- [ ] Pick each menu choice (who, the north gate, leave).
- [ ] Dialogue: **skip** reveals the whole line. With *auto-advance* switched on in settings,
  lines advance on their own.
- [ ] **Path actions:** *Scrutinise* (The Keeper's Hands) gives its line. *Barter* (The Keeper's
  Basket) either succeeds (petals) or fails ("moves it to their other arm"), and a stranger is
  refused.

## 5. The errand

- [ ] The journal (J) shows **The Keeper's Errand** and its steps.
- [ ] Unlock the north gate, stand on the dais, and gather three rose petals. Each step ticks
  off as it happens, with a notification, and the quest completes.

## 6. Two areas

- [ ] **Hall Door:** you enter **Lantern Hall** with a fade, at the right spot, facing the
  right way.
- [ ] The Brass Plaque reads correctly. The Iron Coffer opens.
- [ ] The **Brass Lantern** opens the **Shadowed Arch**. Without it, the arch is "pitch dark".
- [ ] **Courtyard Door:** back to the courtyard. Everything you changed (lever, chest, pickups)
  is still changed.

## 7. Time and weather

- [ ] **Stone Bench:** rest. Time passes, and the message says "1 hour" or "N hours" correctly,
  never "0 hours".
- [ ] *(feel)* Dusk and night actually look different (lighting and shadows), and lanterns
  read well.
- [ ] Weather changes over time, rain for example, and is visible and audible. *(If it stays
  clear for a long session, note it.)*
- [ ] The keeper is somewhere sensible for the hour.

## 8. Save and load

- [ ] Pause (Esc / Start), then save to an **empty** slot. The slot shows the area name and
  time.
- [ ] Save over that **occupied** slot. A confirmation is asked first.
- [ ] Quit to the main menu. **Continue** or **Load** puts you back exactly: position, time,
  inventory, the quest step and the gate state.
- [ ] With autosave on (the default), autosave happens on its occasions, and *Continue
  (autosave)* works.

## 9. Settings and controls

- [ ] Every setting changes something you can see or hear immediately, and survives a
  restart.
- [ ] **Controls:** rebind Interact to another key. The prompt shows the new key, and the old
  key no longer works.
- [ ] Reset to defaults works.
- [ ] *Pause on focus loss* off (default): alt-tab and nothing pauses, and no key is stuck
  "held" when you come back. On: alt-tab pauses.
- [ ] Accessibility: text scale, reduce motion and high-contrast prompts each visibly do
  something.

## 10. Language

- [ ] The pseudo-locale `en_XA` (`[~~text~~]`) shows every string wrapped. A line that is
  **not** wrapped is a hard-coded string, and that is a finding.
- [ ] Bengali and CJK text renders as glyphs, not boxes (tofu). The demo ships no
  translation, so this is a capture step: `--locale=` plus a test string. Ask a cloud session
  for it.

## 11. Debug tools (a developer's, not a player's)

- [ ] F1 console, F2 freecam, F3 performance overlay and F12 screenshot each work, and each
  can be closed.

---

## Reporting what you found

One finding per entry. Use this shape, which is all a session needs to start a row:

```
Step:      (e.g. 8, "Load puts you back exactly")
Did:       what you pressed / where you stood
Expected:  what the step says
Got:       what happened instead
Evidence:  screenshot (F12) or a short clip; the save slot if it's a save bug
Feel?:     yes if it's a "this feels wrong" rather than "this is broken"
```

**Each finding becomes a `T7.n` row** on `WORK_PACKAGES.md`, fixed one package at a time,
each red first and merged before the next. Findings about feel, such as speeds, volumes or
camera, are defects too. A game on this base can copy this file as its own playtest script and
replace the demo's names.
