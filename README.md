# Creator palettes

The pattern colours your palettes add, as choices in the cat maker, for [wcmods](https://github.com/HexOffender/warrior-cats-mods)
(Clan Mod Studio), the mod manager for *Warrior Cats: Clans of the Forest*.

A palette mod's `palette.json` can add pattern and marking colours past the game's 25 (slot 25 and up),
and the game takes them, but the cat maker's colour picker only ever shows its own. With this mod, the
Pattern picker on the cat maker's Colours page gets a fifth row under the game's colours, holding the new ones.

- **Down** from the game's bottom row moves into the new row, **Left** and **Right** move along it, **Up**
  goes back. On a controller, the D-pad or the left stick.
- Pointing at a colour shows it on the cat, as the game's do. **Enter** (A) chooses it; **Back** leaves
  the picker as before, and the cat keeps the colour it had.
- **More than five new colours** go on pages. Right past the row's last colour turns to the next page
  (round from the last to the first), Left past its first to the one before, and the page you're on
  (`2 / 3`) shows under the frame.
- A cat already wearing a new colour starts on it when the picker opens, on its page.
- The cat you make keeps the colour: it's saved as the cat's pattern colour slot, like the game's own.

## Several palettes

Every palette that's on adds to the same row, in slot order.

- **Two palettes setting the same slot:** wcmods keeps one (the higher priority, then the folder name
  that sorts last), and that's the colour the picker shows.
- **Gaps between slots** (one palette has 25 to 27, another 40): wcmods fills a gap with a copy of one of
  the game's colours, so the game never reads past the table. The picker leaves those out, and with
  them any new colour that's exactly one of the game's 25, since the game's grid already has it.

## Limits

- **Keys and a controller only.** The cat maker's menus don't answer the mouse, and the new row doesn't
  either.
- **Pattern colours only.** The cat maker has no colour picker for markings (the Markings category picks
  shapes), so new marking colours aren't offered there.
- **The colour belongs to the palette.** A cat made with one wears it while that palette is on.
- After **Up** from a cat's own new colour (when the picker opened on it), you land on the game's first
  colour, where the game put its own focus.

## Getting it

- Download `creator-palettes-<version>.zip` from [Releases](../../releases) and drop it on Clan Mod
  Studio's Mods page, or `python wcmods.py add creator-palettes-<version>.zip` in your wcmods folder.
- It's an in-game Lua script, so like any script it runs only with **mods that run code allowed**
  (Options, on Clan Mod Studio's Settings and repair page), and it needs the script loader (UE4SS,
  which Get set up installs). Then Apply to game (or press Play).
- It needs wcmods 0.2.0 or newer, and a palette mod with new pattern colours: on Clan Mod Studio's
  Palettes page, **Add a new pattern colour** makes one (it takes the next slot no other palette uses).

## How it's made

`creator-palettes/` is the mod as it goes in your mods folder:

```
creator-palettes/
  mod.json          its name, version and the game builds it was made for
  scripts/main.lua  the new row
```

The picker is the game's `WBP_GuiPopupColorPicker`. When one opens, the script reads its first five
swatches to tell which of the GUI manager's tables it shows (`PatternMaskColors`, `MarkingMaskColors`, or
neither: fur, eyes), makes swatches of the game's own kind (`WBP_GuiColorGridItem`) in the grid's canvas a
row under the last, and swaps the picker's four-row frame for the five-row one it has. The picker hears
keys and the controller as commands (`SwtScreen:OnListenCommand`); while a new swatch is the one pointed
at, the script answers them instead. Choosing sets the slot in the cat maker cat's `CustomData`
(`Pattern01ColorIdx`), and the preview is the cat's materials' `Pattern Mask Color`, painted as the game
paints its own.

To try a change: `python wcmods.py agent install --with path\to\creator-palettes --with path\to\a-palette-mod`
in your wcmods folder installs a test build with both.

## Releasing

1. Raise `"version"` in `creator-palettes/mod.json`. After a game update, try it on the new build and add
   its number to `"game_builds"` (`python wcmods.py game build` shows it).
2. `python tools/pack.py` makes `dist/creator-palettes-<version>.zip`.
3. Make a GitHub release tagged `v<version>` with that .zip attached.
