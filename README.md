# Creator palettes

The pattern and marking colours your palettes add, and their coat presets, as choices in the cat maker, for
[wcmods](https://github.com/HexOffender/warrior-cats-mods) (Clan Mod Studio), the mod manager for *Warrior Cats: Clans
of the Forest*. Ten themed palettes and twelve coat presets come with it.

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

## Coat presets

The game's coats can't take new colours: each coat comes with nose, paw, whisker and ear colours the game
keeps in its code, and a coat it has none for crashes it. A palette's `coats` are presets instead, painted
on: a coat colour and, if it likes, nose, paws, whiskers and ears. The **Fur** picker shows them a palette
at a time, as the Pattern and Markings pickers show new colours.

- Choosing one keeps the cat on one of the game's coats, the preset's `like` (the save only ever holds
  that), and the cat wears the preset.
- The mod remembers which cat chose which preset, by the cat's name, in `creator-palettes-coats.json` in
  wcmods' folder for your files (`%LOCALAPPDATA%\WCMods`, beside your mods), and paints it on that cat in
  the forest, its cutscenes, the inventory, the HUD's picture, the main menu and the cat choice.
- With the mod off, or the palette gone, the cat wears its saved game coat: nothing to undo.
- Choosing one of the game's own coats in the picker takes the preset off.

The **Coat presets** palette that comes with it has twelve: Ash, Smoke, Cream, Fawn, Cinnamon, Chocolate,
Golden, Lilac, Silver, Midnight, Starlight and Ember, each saved as the game's coat nearest it. To make your
own, give a palette.json a `coats` section (wcmods' `docs/formats.md` has the format):

```json
{ "coats": { "Ash": { "fur": "#8f8a85", "nose": "#3d3533", "paws": "#4a4442", "ears": "#b39a98", "like": 11 } } }
```

## The palettes that come with it

The release has the ten themed palettes from [wcmods-examples](https://github.com/HexOffender/wcmods-examples),
each a mod of its own, and the Coat presets palette (on by default; the themed ones start off). Each adds its 25 pattern and 25 marking colours as new colours in slots of its own,
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

Coat presets:

- **Painted on, twice a second.** When the game sets a cat up (a new area, a menu opening) it shows the
  saved coat for a moment first.
- **The cat choice's small pictures** show a cat wearing a preset with its saved coat; the big cat beside
  them wears the preset. The game takes those pictures with one actor for every cat, and a preset painted
  on it would go onto the next cat with the same coat.
- **Parts a preset doesn't set** keep the game's colours: in the forest its saved coat's, in the cat maker
  the ones of the coat under the cursor.
- **By name.** Two of your cats with the same name (in different saves) share one. After a rank-up (a new
  suffix, the same prefix) your cat keeps its preset while it still has the preset's saved coat. Clan cats
  are never painted, even one with your cat's name.
- **Your cat only**: presets are for the cat you make. To colour clan cats, wcmods' `cats.json` has
  colours by name.
- **Needs a wcmods that knows `coats`** (newer than 0.3.0). With an older one, the Coat presets palette is
  skipped when you install, with an error ("unknown palette section 'coats'"), and the Fur picker shows
  no presets.

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
palettes/           the palettes that come with it, each mod.json and palette.json
  palette-*/        the ten themed ones, as wcmods-examples has them (made by wcmods' tools/make_palettes.py)
  palette-coat-presets/  the twelve coat presets, made here
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

Coat presets come from `WCModsPalettes` too (each palette's `coats`). In the Fur picker they're entries like
the new slots, but choosing one sets the cat's `FurColorIdx` to the preset's `like` and paints its `Fur
Color`, `Nose Color`, `Paws Color`, `Whiskers Color` and `Ears Color`. The cat maker's cat wears it until
your cat reaches the forest, where the preset is recorded under its name IDs (`PrefixNameId|SuffixNameId`).
Twice a second the script paints every cat whose name IDs have a record, gives the game's colours back to a
cat the game moves on to another cat (it doesn't always set them again itself), and takes the HUD's picture
again (`RT_UI_Portrait_Exploration`). Out of the forest, of the menus' picture actors
(`BP_UI_CatCustomActor_C`) only the cat choice's own cat (its `CatRef`) is painted.

To try a change: `python wcmods.py agent install --with path\to\creator-palettes --with path\to\palettes\palette-dark-forest`
in your wcmods folder installs a test build with both.

## Releasing

1. Raise `"version"` in `creator-palettes/mod.json`. A release that needs something new in wcmods (1.2.0's
   coat presets need the `coats` section) goes out after the wcmods release that has it, and its notes say so. After a game update, try it on the new build and add
   its number to `"game_builds"` (`python wcmods.py game build` shows it).
2. When the palettes change: `python tools/make_palettes.py --out ../wcmods-examples` in wcmods, then copy
   wcmods-examples' `palette-*` folders into `palettes/` (`palette-coat-presets` is this repo's own: keep it).
3. `python tools/pack.py` makes `dist/creator-palettes-<version>.zip`, with the mod and the palettes.
4. Make a GitHub release tagged `v<version>` with that .zip attached.
