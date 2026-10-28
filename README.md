# Creator palettes

The pattern and marking colours your palettes add, as choices in the cat maker, for [wcmods](https://github.com/HexOffender/warrior-cats-mods)
(Clan Mod Studio), the mod manager for *Warrior Cats: Clans of the Forest*. Ten themed palettes come with it.

A palette mod's `palette.json` can add pattern and marking colours past the game's 25 (slot 25 and up),
and the game takes them, but the cat maker's colour picker only ever shows its own. With this mod, the
Pattern and Markings pickers on the cat maker's Colours page show them a palette at a time.

- The picker opens on **the game's own colours**, as before. **Right** at the grid's right edge (or
  **Left** at its left edge) shows the next (or the one before) palette: its colours fill the whole grid,
  with a fifth row under it for 25, and its name shows under the frame (`Dark Forest   8 / 11`). Keep
  going to see every palette and come round to the game's colours again.
- Move around the grid as usual; **Down** from its last row reaches the fifth row and **Up** comes back.
  On a controller, the D-pad or the left stick.
- Pointing at a colour shows it on the cat, as the game's do. **Enter** (A) chooses it; **Back** leaves
  the picker as before, and the cat keeps the colour it had.
- A cat already wearing a palette's colour opens on that palette.
- The cat you make keeps the colour: it's saved as the cat's pattern (or marking) colour slot, like the
  game's own.

## The palettes that come with it

The release has the ten themed palettes from [wcmods-examples](https://github.com/HexOffender/wcmods-examples),
each a mod of its own. Each adds its 25 pattern and 25 marking colours as new colours in slots of its own,
so all ten can be on at once and every one of their colours is a choice:

| Palette | New pattern and marking slots |
|---|---|
| ThunderClan Forest | 100-124 |
| RiverClan Waters | 125-149 |
| ShadowClan Night | 150-174 |
| WindClan Moor | 175-199 |
| SkyClan Sunset | 200-224 |
| StarClan Silverpelt | 225-249 |
| Dark Forest | 250-274 |
| Leaf-bare Frost | 275-299 |
| Pastel Kits | 300-324 |
| Vivid Clans | 325-349 |

Each also restyles the game's coat and eye colours (coats can't take new slots: the game crashes past
its 25). Only one palette's coats and eyes can show: with several on, the one with the highest priority,
then the folder name that sorts last, wins. Turn off the ones whose coats and eyes you don't want; their
pattern and marking colours go with them.

## Several palettes

Every palette that's on is a view of its own: the palettes in priority order, each one's colours in slot
order. One with more than 25 takes more than one view.

- **Two palettes setting the same slot:** wcmods keeps one (the higher priority, then the folder name
  that sorts last), and that's the colour the picker shows, under that palette.
- **Gaps between slots** (one palette has 25 to 27, another 40): wcmods fills a gap with a copy of one of
  the game's colours, so the game never reads past the table. The picker leaves those out.

## Limits

- **Keys and a controller only.** The cat maker's menus don't answer the mouse, and the new row doesn't
  either.
- **Markings** have a colour picker only on a cat with markings; choose a marking shape first.
- **The colour belongs to the palette.** A cat made with one wears it while that palette is on.
- After **Up** from a cat's own new colour (when the picker opened on it), you land on the game's first
  colour, where the game put its own focus.
- **Palette by palette** needs a wcmods newer than 0.3.0 (it lists the palettes for scripts: the
  `WCModsPalettes` module). With 0.3.0 all the new colours are one "New colours" palette, 25 to a view.

## Getting it

- Download `creator-palettes-<version>.zip` from [Releases](../../releases) and drop it on Clan Mod
  Studio's Mods page, or `python wcmods.py add creator-palettes-<version>.zip` in your wcmods folder. It
  adds the mod and the ten palettes (and updates them if you have them, keeping a backup).
- It's an in-game Lua script, so like any script it runs only with **mods that run code allowed**
  (Options, on Clan Mod Studio's Settings and repair page), and it needs the script loader (UE4SS,
  which Get set up installs). Then Apply to game (or press Play).
- It needs wcmods 0.2.0 or newer. Palettes of your own: on Clan Mod Studio's Palettes page, **Add a new
  pattern colour** makes one (it takes the next slot no other palette uses).

## How it's made

```
creator-palettes/   the mod as it goes in your mods folder
  mod.json          its name, version and the game builds it was made for
  scripts/main.lua  the new row
palettes/           the ten palettes, as wcmods-examples has them (made by wcmods' tools/make_palettes.py)
  palette-*/        mod.json and palette.json
```

The picker is the game's `WBP_GuiPopupColorPicker`. When one opens, the script reads its first five
swatches to tell which of the GUI manager's tables it shows (`PatternMaskColors`, `MarkingMaskColors`, or
neither: fur, eyes) and makes swatches of the game's own kind (`WBP_GuiColorGridItem`) in the grid's canvas a
row under the last. A palette's view recolours the game's swatches and that row (hiding the cells it has no
colour for) and swaps the picker's four-row frame for the five-row one it has; the game's view puts its
colours back. Which palette added which slots comes from wcmods' `WCModsPalettes` module. The picker hears keys and the controller as
commands (`SwtScreen:OnListenCommand`); while a new swatch is the one pointed at, the script answers them
instead. Choosing sets the slot in the cat maker cat's `CustomData` (`Pattern01ColorIdx` or
`Pattern02ColorIdx`), and the preview is the cat's materials' `Pattern Mask Color` or `Markings Mask
Color`, painted as the game paints its own.

To try a change: `python wcmods.py agent install --with path\to\creator-palettes --with path\to\palettes\palette-dark-forest`
in your wcmods folder installs a test build with both.

## Releasing

1. Raise `"version"` in `creator-palettes/mod.json`. After a game update, try it on the new build and add
   its number to `"game_builds"` (`python wcmods.py game build` shows it).
2. When the palettes change: `python tools/make_palettes.py --out ../wcmods-examples` in wcmods, then copy
   wcmods-examples' `palette-*` folders into `palettes/`.
3. `python tools/pack.py` makes `dist/creator-palettes-<version>.zip`, with the mod and the palettes.
4. Make a GitHub release tagged `v<version>` with that .zip attached.
