-- Creator palettes: the pattern and marking colours your palettes add (palette.json's slots from 25 up) as choices
-- in the cat maker's own colour picker, beside the game's.
--
-- The game's picker (WBP_GuiPopupColorPicker) shows its colours in a grid it fills itself, the base ones and the
-- bright extras, and never the slots a palette adds, though the game takes them anywhere else (palette.json
-- grows its colour tables when the game starts). So when the pattern or marking picker opens, this shows
-- them a palette at a time in the game's own grid: it starts on the game's own colours, and Left at the
-- grid's left edge or Right at its right edge shows the palette before or after (as wcmods lists them,
-- WCModsPalettes), its colours across the game's 20 swatches and a fifth row under them, made from the
-- game's own swatch (WBP_GuiColorGridItem), in the frame the game has for a five-row grid, with the palette's
-- name under the frame. Pointing at a colour shows it on the cat, as the game's do; Enter (A) chooses it.
-- The cat maker answers keys and the controller, not the mouse: Down from the grid's last row goes to the
-- new row, Up comes back.
-- A cat already wearing a new colour starts on it when the picker opens.
--
-- Choosing one sets the cat's colour slot where the cat maker keeps it (the picker's cat, CatRef: its
-- CustomData's Pattern01ColorIdx or Pattern02ColorIdx), so the cat you make keeps it, and paints it on
-- the cat maker's cat (its "Pattern Mask Color" or "Markings Mask Color"), which the game would otherwise
-- paint only from its own colours.
--
-- The Fur picker shows the palettes' coat presets the same way (palette.json "coats": coats can't take new
-- slots). A preset is painted on, the cat saved with one of the game's coats; the cats that chose one are
-- remembered by name and painted wherever they show (see "coats in play" below).
if not Game then
    MOD.log("WCModsGame didn't load, so there's no way to reach the cat maker")
    return
end

local UI = "/Game/Art/UXD/Blueprints/Controls/gui_customization/"
local PICKER = UI .. "WBP_GuiPopupColorPicker.WBP_GuiPopupColorPicker_C"
local SWATCH = UI .. "WBP_GuiColorGridItem.WBP_GuiColorGridItem_C"
local KINDS = {
    { name = "pattern", table = "PatternMaskColors", field = "Pattern01ColorIdx", param = "Pattern Mask Color" },
    { name = "marking", table = "MarkingMaskColors", field = "Pattern02ColorIdx", param = "Markings Mask Color" },
    -- Coats can't take new slots (the game crashes on a coat it has no nose, paw, whisker and ear colours for),
    -- so palettes give coat presets instead: painted on, the cat saved with one of the game's coats ("like").
    { name = "coat", table = "FurColors", field = "FurColorIdx", param = "Fur Color", presets = true },
}
local FIRST = 25          -- palette.json's first new slot
-- Which palette added which new slots (wcmods 0.4 and up writes it at install): { { name, pattern = {slots},
-- marking = {slots} } } in priority order. Without it the new colours are one list.
local okGroups, PALETTES = pcall(require, "WCModsPalettes")
if not okGroups or type(PALETTES) ~= "table" then PALETTES = nil end
local MAX_NEW = 5         -- one row in the game's five-row frame
local MESHES = { "SkelMeshComp", "FurSkelMeshComp", "TailSkelMeshComp", "EarSkelMeshComp" }
local SELECTED, NORMAL = 2, 1     -- EUIControlState
local PRESSED = 0                 -- the command's event: 0 pressed, 1 released

local function log(fmt, ...) MOD.log(fmt, ...) end
local function valid(o) return o ~= nil and type(o) == "userdata" and o.IsValid ~= nil and o:IsValid() end

local reported = {}
local function report(where, err)
    local key = where .. tostring(err)
    if reported[key] then return end
    reported[key] = true
    log("%s: %s", where, tostring(err))
end

-- ------------------------------------------------------------------------------------------------ colours
local function linear(v)
    v = v / 255
    return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
end

local function manager() return FindFirstOf("SwtAdventureGuiManager") end

-- Coat presets (palette.json "coats", which wcmods lists in WCModsPalettes): what each paints, by its id
-- ("<palette mod>/<name>"): { preset, name, like, colour (its coat), params = { ["Fur Color"] = ..., ... } }.
local PARAMS = { fur = "Fur Color", nose = "Nose Color", paws = "Paws Color", whiskers = "Whiskers Color",
                 ears = "Ears Color" }
local function hexLinear(h)
    local r, g, b = tostring(h):match("#?(%x%x)(%x%x)(%x%x)")
    if not r then return nil end
    return { R = linear(tonumber(r, 16)), G = linear(tonumber(g, 16)), B = linear(tonumber(b, 16)), A = 1 }
end
local PRESETS = {}
for _, g in ipairs(PALETTES or {}) do
    for _, c in ipairs(g.coats or {}) do
        local e = { preset = c.id, name = c.name, like = c.like, params = {} }
        for part, param in pairs(PARAMS) do
            if c[part] then e.params[param] = hexLinear(c[part]) end
        end
        e.colour = e.params["Fur Color"]
        if e.colour and type(e.like) == "number" then PRESETS[c.id] = e end
    end
end

-- The presets by palette, as byPalette() gives the new slots.
local function coatGroups()
    local out = {}
    for _, g in ipairs(PALETTES or {}) do
        local mine = {}
        for _, c in ipairs(g.coats or {}) do
            if PRESETS[c.id] then mine[#mine + 1] = PRESETS[c.id] end
        end
        if #mine > 0 then out[#out + 1] = { name = tostring(g.name or g.id or ""), entries = mine } end
    end
    return out
end

-- The colour of a slot in one of the GUI manager's tables, as a linear colour (the tables are sRGB bytes).
local function slotColour(kind, slot)
    local gm = manager()
    if not valid(gm) then return nil end
    local t = gm[kind.table]
    if slot >= t:GetArrayNum() then return nil end
    local c = t[slot + 1]
    return { R = linear(c.R), G = linear(c.G), B = linear(c.B), A = 1 }
end

local function close(a, b) return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01 end

-- The new slots a picker offers: { { slot, colour } } in slot order. palette.json lets several palettes add
-- slots, each its own numbers, so the table can have gaps (one palette's 25 to 27, another's 40); wcmods fills
-- a gap with a copy of one of the game's colours, so a slot that's exactly one of the game's 25 is left out
-- (it's either a gap or a colour the game's grid already has) unless wcmods lists it as a palette's. Where
-- two palettes set the same slot, wcmods
-- has already kept the one that wins (priority, then folder name).
local function newSlots(kind)
    local gm = manager()
    if not valid(gm) then return {} end
    local t = gm[kind.table]
    local n = t:GetArrayNum()
    local game = {}
    for i = 1, math.min(FIRST, n) do
        local c = t[i]
        game[c.R .. "," .. c.G .. "," .. c.B] = true
    end
    -- A slot a palette lists (WCModsPalettes) is its own colour even when it's the same as one of the game's.
    local listed = {}
    for _, g in ipairs(PALETTES or {}) do
        for _, slot in ipairs(g[kind.name] or {}) do listed[slot] = true end
    end
    local out = {}
    for slot = FIRST, n - 1 do
        local c = t[slot + 1]
        if listed[slot] or not game[c.R .. "," .. c.G .. "," .. c.B] then
            out[#out + 1] = { slot = slot, colour = { R = linear(c.R), G = linear(c.G), B = linear(c.B), A = 1 } }
        end
    end
    return out
end

-- The new colours by palette: { { name, entries } } in the palettes' order, each palette's in slot order; ones
-- no palette lists (an older wcmods, or slots it doesn't know) go last, unnamed.
local function byPalette(kind, entries)
    local at = {}
    for _, e in ipairs(entries) do at[e.slot] = e end
    local out, taken = {}, {}
    for _, g in ipairs(PALETTES or {}) do
        local mine = {}
        for _, slot in ipairs(g[kind.name] or {}) do
            if at[slot] and not taken[slot] then
                mine[#mine + 1] = at[slot]
                taken[slot] = true
            end
        end
        if #mine > 0 then out[#out + 1] = { name = tostring(g.name or g.id or ""), entries = mine } end
    end
    local rest = {}
    for _, e in ipairs(entries) do
        if not taken[e.slot] then rest[#rest + 1] = e end
    end
    if #rest > 0 then out[#out + 1] = { name = #out > 0 and "Other new colours" or nil, entries = rest } end
    return out
end

-- Which table a picker shows, from its first swatches' colours (the grid shows slots 0, 1, 2... in order):
-- pattern, marking, or nil (fur, eyes). Five, not one: a palette can give two tables the same first colour.
local function kindOf(grid)
    local n = math.min(grid.Items:GetArrayNum(), 5)
    for _, kind in ipairs(KINDS) do
        local same = true
        for i = 1, n do
            local ok, shown = pcall(function() return grid.Items[i].mcGuiColor.ColorAndOpacity end)
            local c = slotColour(kind, i - 1)
            if not (ok and shown and c and close(c, shown)) then
                same = false
                break
            end
        end
        if same then return kind end
    end
    return nil
end

-- A part's mesh with its model in: while the game sets a cat up (the cat choice loading its cats) a part can be
-- without one for a moment, and asking it for a material then crashes the game.
local function ready(mesh)
    if not valid(mesh) then return false end
    local ok, asset = pcall(function() return mesh.SkinnedAsset end)
    return ok and valid(asset)
end

-- Each of a cat's dynamic materials, on every part: the ones the game colours.
local function eachMaterial(comp, fn)
    for _, field in ipairs(MESHES) do
        local ok, mesh = pcall(function() return comp[field] end)
        if ok and ready(mesh) then
            for i = 0, mesh:GetNumMaterials() - 1 do
                local mat = mesh:GetMaterial(i)
                if valid(mat) and mat:GetClass():GetFName():ToString() == "MaterialInstanceDynamic" then fn(mat) end
            end
        end
    end
end

local function near(a, b)
    return math.abs(a.R - b.R) <= 0.002 and math.abs(a.G - b.G) <= 0.002 and math.abs(a.B - b.B) <= 0.002
end

-- Put colours on a cat's mesh component, as the game does from its own slots: { [parameter] = linear colour }.
-- With `onlyChanged`, only the ones that differ from what a material holds (for cats painted again and again);
-- how many it set.
local function paintComp(comp, params, onlyChanged)
    local set = 0
    eachMaterial(comp, function(mat)
        if onlyChanged then
            local todo, held = {}, {}
            mat.VectorParameterValues:ForEach(function(_, e)
                local v = e:get()
                local name = v.ParameterInfo.Name:ToString()
                held[name] = true
                if params[name] and not near(v.ParameterValue, params[name]) then todo[#todo + 1] = name end
            end)
            -- One the game never set on this material (the forest's cats have no ear colour of their own): set
            -- once, it's held from then on.
            for name in pairs(params) do
                if not held[name] then todo[#todo + 1] = name end
            end
            for _, name in ipairs(todo) do
                mat:SetVectorParameterValue(FName(name), params[name])
                set = set + 1
            end
        else
            for name, colour in pairs(params) do
                mat:SetVectorParameterValue(FName(name), colour)
                set = set + 1
            end
        end
    end)
    return set
end

-- A colour of a kind on the cat maker's cat; a new colour (a slot, or a coat preset with its nose, paws...).
local function paint(cat, kind, colour) return paintComp(cat.CustomizableMeshComponent, { [kind.param] = colour }) end
local function paintEntry(cat, kind, e)
    return paintComp(cat.CustomizableMeshComponent, e.params or { [kind.param] = e.colour })
end

-- Cats wearing a coat preset, by their mesh component's address: { id = the preset, orig = { [parameter] = the
-- colour the game had set } }. Some of the game's cats show one cat after another (the main menu's, the cat
-- maker's, the inventory's): when one moves on to a cat without a preset, the game's colours go back. The game
-- doesn't always set them again itself (not when the next cat has the same coat), so the preset would stay on.
local painted = {}

-- A cat's coat colours now (its first material's: the game sets the same on all).
local function coatColours(comp)
    local out = {}
    local mesh = comp.SkelMeshComp
    local mat = ready(mesh) and mesh:GetNumMaterials() > 0 and mesh:GetMaterial(0) or nil
    if valid(mat) then
        for _, param in pairs(PARAMS) do
            local c = mat:K2_GetVectorParameterValue(FName(param))
            out[param] = { R = c.R, G = c.G, B = c.B, A = c.A }
        end
    end
    return out
end

local function wear(comp, preset)
    local at = comp:GetAddress()
    if not (painted[at] and painted[at].id == preset.preset) then
        painted[at] = { id = preset.preset, orig = coatColours(comp) }
    end
    return paintComp(comp, preset.params, true)
end

-- The game's colours back on a cat that wore a preset, on the parts still showing it (any other, the game has
-- set since). How many it set.
local function unwear(comp)
    local at = comp:GetAddress()
    local p = painted[at]
    painted[at] = nil
    local was = p and PRESETS[p.id or ""]
    if not was then return 0 end
    local n = 0
    eachMaterial(comp, function(mat)
        for param, colour in pairs(was.params) do
            if p.orig[param] and near(mat:K2_GetVectorParameterValue(FName(param)), colour) then
                mat:SetVectorParameterValue(FName(param), p.orig[param])
                n = n + 1
            end
        end
    end)
    return n
end

-- ------------------------------------------------------------------------------------------------ the picker
local open = nil     -- the picker showing now: { popup, grid, kind, cat, swatches = { { w } }, views, view, active }
local seen = {}      -- pickers the game has made (it makes one each time)
local commands = nil -- the game's command numbers by name
local before = {}    -- each cat maker cat's colour slots while no picker shows, by its address and the kind's name
local coatOf = {}    -- the coat preset each cat maker cat wears, by its address
local pending = nil  -- the coat preset of the cat being made, to remember by its name once it's in the forest
local TEXT = "#f3e9c6"     -- the cat maker's cream

local function readCommands()
    local e = StaticFindObject("/Script/SwtEngine.ECommands")
    if not valid(e) then return nil end
    local byName = {}
    e:ForEachName(function(name, value) byName[(name:ToString():gsub("^ECommands::", ""))] = value end)
    return byName
end

-- A swatch shown as the one pointed at, or not: the game's focus events, then its state.
local function focus(w, on)
    pcall(function() if on then w:OnGotFocus() else w:OnLostFocus() end end)
    pcall(function() w:OnChangeState(on and SELECTED or NORMAL) end)
    -- The gold frame is its CanvasSelected, which the events above don't always swap back.
    pcall(function()
        w.CanvasSelected:SetVisibility(on and 0 or 2)       -- ESlateVisibility: Visible, Hidden
        w.CanvasNormal:SetVisibility(on and 2 or 0)
    end)
end

local function highlight(s, on) focus(s.w, on) end

-- What the picker shows, a view at a time: the game's own colours first, then each palette's, up to 25 a view
-- (the 5x5 grid: the game's 20 swatches, recoloured, and the new row under them); a palette of more takes as
-- many views as it needs.
local GRID = 25
local function makeViews(groups)
    local views = { { name = "The game's colours", game = true } }
    for _, g in ipairs(groups) do
        local count = math.ceil(#g.entries / GRID)
        for k = 1, count do
            local entries = {}
            for i = (k - 1) * GRID + 1, math.min(k * GRID, #g.entries) do entries[#entries + 1] = g.entries[i] end
            local name = g.name or "New colours"
            views[#views + 1] = { name = count > 1 and string.format("%s (%d)", name, k) or name, entries = entries }
        end
    end
    return views
end

local function view() return open.views[open.view] end

-- The new colour a cell shows in this view: the game's swatches 1 to count, then the new row's.
local function cellEntry(i)
    local v = view()
    return v.entries and v.entries[i] or nil
end

local function rowEntry(j) return cellEntry(open.count + j) end

-- Which of the game's swatches has the picker's focus (1 to count), or nil.
local function nativeIndex()
    local native = nil
    pcall(function() native = open.grid.GridNavigation.CurrentControl end)
    if not valid(native) then return nil end
    for i = 1, open.count do
        if open.grid.Items[i]:GetAddress() == native:GetAddress() then return i end
    end
    return nil
end

-- The label under the frame, in the picker's own grid: the view's name and place, and the way to the others.
local function makeLabel(grid, x, size)
    local t = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), grid, FName("None"))
    local placed = grid.mcGuiCanvasItems:AddChildToCanvas(t)
    placed:SetAutoSize(true)
    placed:SetAlignment({ X = 0.5, Y = 0 })
    placed:SetPosition({ X = x, Y = 0 })
    local f = t.Font
    t:SetFont({ FontObject = f.FontObject, TypefaceFontName = f.TypefaceFontName, Size = size,
                LetterSpacing = 0, SkewAmount = 0, bForceMonospaced = false, MonospacedWidth = 1 })
    local r, g, b = TEXT:match("#(%x%x)(%x%x)(%x%x)")
    t:SetColorAndOpacity({ SpecifiedColor = { R = linear(tonumber(r, 16)), G = linear(tonumber(g, 16)),
                                              B = linear(tonumber(b, 16)), A = 0.85 }, ColorUseRule = 0 })
    pcall(function() t:SetJustification(1) end)                -- centred
    t:SetVisibility(3)                                        -- HitTestInvisible
    return t, placed
end

-- Show a view: the game's swatches take its first 20 colours (or their own, in the game's view; a cell with
-- none is hidden), the new row the rest, and the frame has a fifth row only when the new row shows.
local function showView(v)
    open.view = v
    local here = view()
    for i = 1, open.count do
        local w, e = open.grid.Items[i], cellEntry(i)
        pcall(function()
            if here.game or e then
                w.mcGuiColor:SetColorAndOpacity(here.game and open.native[i] or e.colour)
                w:SetVisibility(open.nativeVis[i])
            else
                w:SetVisibility(2)                            -- Hidden: it keeps its place in the grid
            end
        end)
    end
    open.shown = 0
    for j, s in ipairs(open.swatches) do
        local e = rowEntry(j)
        if e then
            s.w.mcGuiColor:SetColorAndOpacity(e.colour)
            s.w:SetVisibility(4)                              -- SelfHitTestInvisible, as the game's swatches
            open.shown = j
        else
            s.w:SetVisibility(1)                              -- Collapsed
        end
    end
    local five = open.shown > 0
    pcall(function()
        open.popup.CanvasBackground1:SetVisibility(five and 2 or 4)
        open.popup.CanvasBackground2:SetVisibility(five and 4 or 2)
    end)
    if open.label then
        pcall(function()
            open.labelSlot:SetPosition({ X = open.labelX, Y = five and open.labelY5 or open.labelY4 })
            open.label:SetText(FText(string.format("%s   %d / %d\nLeft or Right at the edges for more colours",
                here.name, v, #open.views)))
        end)
    end
    open.paintFrames, open.lastFocus = 20, nil                -- the cat shows this view's colour again
end

-- The colour page's swatch for a kind (its button: Pattern, or Markings), as the cat maker shows the chosen colour.
local function showOnPage(kind, colour)
    for _, panel in ipairs(FindAllOf("WBP_GuiPanelCustomizationColors_C") or {}) do
        if valid(panel) and panel:IsVisible() then
            pcall(function()
                local option = kind.name == "pattern" and panel.mcGuiOptionPattern
                    or kind.name == "marking" and panel.mcGuiOptionMarkings or panel.mcGuiOptionFurColor
                option.mcGuiIcon:SetColorAndOpacity(colour)
            end)
        end
    end
end

-- One of the new row's swatches as the one pointed at (and on the cat), or none (nil): the grid's then.
local function setActive(j)
    if not open then return end
    if open.active == j then return end
    if open.active then highlight(open.swatches[open.active], false) end
    open.active = j
    local native = nil
    pcall(function() native = open.grid.GridNavigation.CurrentControl end)
    if j then
        if valid(native) then focus(native, false) end
        highlight(open.swatches[j], true)
        paintEntry(open.cat, open.kind, rowEntry(j))
    else
        if valid(native) then focus(native, true) end
        open.paintFrames, open.lastFocus = 20, nil
    end
end

local function choose(s)
    -- Once, and only on a picker that's still showing: a second Back would leave the cat maker.
    if not s or not open or open.chosen or not (valid(open.popup) and open.popup:IsVisible()) then return end
    open.chosen = true
    local cat, kind, popup = open.cat, open.kind, open.popup
    local function apply()
        if s.preset then
            -- A coat preset: the cat keeps one of the game's coats (what the save gets) and wears the preset.
            local comp = cat.CustomizableMeshComponent
            comp.CustomData[kind.field] = s.like
            coatOf[cat:GetAddress()] = s.preset
            pending = s.preset
            local at = comp:GetAddress()
            painted[at] = { id = s.preset, orig = painted[at] and painted[at].orig or {} }
        else
            cat.CustomizableMeshComponent.CustomData[kind.field] = s.slot
            before[cat:GetAddress() .. kind.name] = s.slot
        end
        paintEntry(cat, kind, s)
        showOnPage(kind, s.colour)
    end
    apply()
    -- Close the picker the game's way (Back), then set the slot again in case going back put the old one back.
    local pc = Game.controller()
    pcall(function()
        popup:OnListenCommand(commands.Button_Back, PRESSED, pc)
        popup:OnListenCommand(commands.Button_Back, 1, pc)
    end)
    Game.after(0.1, function() if valid(cat) then apply() end end)
    if s.preset then log("coat: %s (saved as the game's coat %d)", s.preset, s.like)
    else log("%s colour: slot %d", kind.name, s.slot) end
end

local function attach(popup)
    local grid = popup.mcGuiGrid
    local n = grid.Items:GetArrayNum()
    if n < 6 then return false end            -- not filled in yet
    local kind = kindOf(grid)
    if not kind then return true end          -- eyes: nothing to add
    local groups = kind.presets and coatGroups() or byPalette(kind, newSlots(kind))
    local total = 0
    for _, g in ipairs(groups) do total = total + #g.entries end
    if total == 0 then return true end
    local cls = Game.load(SWATCH)
    if not valid(cls) then
        report("the swatch", "the game has no " .. SWATCH)
        return true
    end
    -- The grid's spacing, from its own first swatches: right along a row, down to the next.
    local t1, t2 = grid.Items[1].RenderTransform.Translation, grid.Items[2].RenderTransform.Translation
    local cols = 1
    while cols < n and math.abs(grid.Items[cols + 1].RenderTransform.Translation.Y - t1.Y) < 1 do cols = cols + 1 end
    local below = grid.Items[cols + 1].RenderTransform.Translation
    local dx, dy = t2.X - t1.X, below.Y - t1.Y
    local rows = math.ceil(n / cols)
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local pc = Game.controller()
    local swatches = {}
    for k = 1, math.min(MAX_NEW, cols) do
        local w = lib:Create(pc, cls, pc)
        local placed = grid.mcGuiCanvasItems:AddChildToCanvas(w)
        pcall(function() placed:SetAutoSize(true) end)
        w:SetRenderTranslation({ X = t1.X + (k - 1) * dx, Y = t1.Y + rows * dy })
        swatches[#swatches + 1] = { w = w }
    end
    -- The game's own colours and how its swatches show, to put back in its view.
    local native, nativeVis = {}, {}
    for i = 1, n do
        local c = grid.Items[i].mcGuiColor.ColorAndOpacity
        native[i] = { R = c.R, G = c.G, B = c.B, A = c.A }
        nativeVis[i] = grid.Items[i]:GetVisibility()
    end
    open = { popup = popup, grid = grid, kind = kind, cat = popup.CatRef, swatches = swatches, active = nil,
             cols = cols, count = n, views = makeViews(groups), view = 1, shown = 0, native = native,
             nativeVis = nativeVis, paintFrames = 0 }
    local ok, label, slot = pcall(function()
        local width = dx * 0.8
        pcall(function() width = grid.Items[1]:GetDesiredSize().X end)
        open.labelX = t1.X + (math.ceil(cols / 2) - 1) * dx + width / 2
        -- Below the frame, whose edge comes a third of a row under its last row.
        open.labelY4, open.labelY5 = t1.Y + (rows + 0.4) * dy, t1.Y + (rows + 1.3) * dy
        return makeLabel(grid, open.labelX, dx * 0.18)
    end)
    if ok then open.label, open.labelSlot = label, slot else report("the label", label) end
    -- The cat's own coat colours, before the picker shows others on it, to put back if it leaves the cat maker
    -- wearing a preset (it's one of the menus' cats).
    pcall(function()
        local comp = open.cat.CustomizableMeshComponent
        local at = comp:GetAddress()
        if kind.presets and not (painted[at] and painted[at].id) then
            painted[at] = { orig = coatColours(comp) }
        end
    end)
    showView(1)
    log("%d new %s%s in the picker (%d palette%s)", total, kind.name, kind.presets and " preset" .. (total == 1 and "" or "s")
        or (" colour" .. (total == 1 and "" or "s")), #groups, #groups == 1 and "" or "s")
    -- A cat already wearing one of the new colours starts on its palette (and on it, when it's in the new row):
    -- the game can't show the slot, so it starts on its own first swatch. A moment later, once the game has.
    local cat = open.cat
    local was = nil
    if valid(cat) then
        if kind.presets then was = coatOf[cat:GetAddress()] else was = before[cat:GetAddress() .. kind.name] end
    end
    if was and (kind.presets or was >= FIRST) then
        Game.after(0.1, function()
            if not (open and valid(popup) and open.popup:GetAddress() == popup:GetAddress()) or open.active then
                return
            end
            for v, here in ipairs(open.views) do
                for i, e in ipairs(here.entries or {}) do
                    if (kind.presets and e.preset or e.slot) == was then
                        showView(v)
                        if i > open.count then setActive(i - open.count) end
                        return
                    end
                end
            end
        end)
    end
    return true
end

-- The pickers the game makes; each is looked at once it shows. The picker's class loads with the cat maker, so
-- until it can be followed (NotifyOnNewObject needs it loaded) it's looked for twice a second.
local following = false
local function add(p)
    local at = p:GetAddress()
    for _, s in ipairs(seen) do if valid(s.p) and s.p:GetAddress() == at then return end end
    seen[#seen + 1] = { p = p, done = false }
end
local function follow()
    if following then return end
    local ok = pcall(NotifyOnNewObject, PICKER, function(p) add(p) end)
    following = ok
end
Game.every(0.5, function()
    follow()
    if following then return end
    for _, p in ipairs(FindAllOf("WBP_GuiPopupColorPicker_C") or {}) do
        if valid(p) and p:IsVisible() then add(p) end
    end
end)

Game.onFrame(function()
    if open and not (valid(open.popup) and open.popup:IsVisible()) then open = nil end
    for i = #seen, 1, -1 do
        local s = seen[i]
        if not valid(s.p) then
            table.remove(seen, i)
        elseif not s.done and s.p:IsVisible() then
            local ok, done = pcall(attach, s.p)
            if not ok then
                report("adding the new colours", done)
                s.done = true
            else
                s.done = done
            end
        end
    end
    -- The colour the grid points at, on the cat: the game paints its own slot's when its focus moves, so for a
    -- moment after that (or a new view) this paints the view's colour over it.
    if not open or open.active or open.chosen then return end
    local idx = nativeIndex()
    if idx ~= open.lastFocus then open.lastFocus, open.paintFrames = idx, 20 end
    if idx and open.paintFrames > 0 then
        open.paintFrames = open.paintFrames - 1
        local e = cellEntry(idx)
        if view().game then pcall(paint, open.cat, open.kind, open.native[idx])
        elseif e then pcall(paintEntry, open.cat, open.kind, e) end
    end
end)

-- Keys and the controller: the picker hears commands. Left or Right at the grid's (or the row's) edges shows the
-- view before or after; in a palette's view, Enter chooses the palette's colour; the new row is this mod's.
local function onCommand(ctx, commandParam, eventParam)
    if not open or not commands then return end
    local screen = ctx:get()
    if not (valid(screen) and screen:GetAddress() == open.popup:GetAddress()) then return end
    local command, event = commandParam:get(), eventParam:get()
    local C = commands
    local up = command == C.Button_Up or command == C.Button_StickL_Up
    local down = command == C.Button_Down or command == C.Button_StickL_Down
    local left = command == C.Button_Left or command == C.Button_StickL_Left
    local right = command == C.Button_Right or command == C.Button_StickL_Right
    local confirm = command == C.Button_Confirm
    local function step() return left and (open.view - 2) % #open.views + 1 or open.view % #open.views + 1 end
    if open.active then
        if not (up or down or left or right or confirm) then return end
        commandParam:set(C.NoCommand)
        if event ~= PRESSED then return end
        if left and open.active > 1 then setActive(open.active - 1)
        elseif right and open.active < open.shown then setActive(open.active + 1)
        elseif left or right then
            -- Past either end of the row: the view before or after, in its row if it has one.
            highlight(open.swatches[open.active], false)
            open.active = nil
            showView(step())
            if open.shown > 0 then setActive(left and open.shown or 1) else setActive(nil) end
        elseif up then setActive(nil)
        elseif confirm then choose(rowEntry(open.active)) end
        return
    end
    if not (down or left or right or confirm) then return end
    local idx = nativeIndex()
    if not idx then return end
    local col = (idx - 1) % open.cols + 1
    if (left and col == 1) or (right and (col == open.cols or idx == open.count)) then
        commandParam:set(C.NoCommand)
        if event == PRESSED then showView(step()) end
    elseif down and idx > open.count - open.cols and open.shown > 0 then
        -- Down from the grid's last row goes to the new one, under the same column (or its last swatch).
        commandParam:set(C.NoCommand)
        if event == PRESSED then setActive(math.min(col, open.shown)) end
    elseif confirm and not view().game then
        commandParam:set(C.NoCommand)
        if event == PRESSED then choose(cellEntry(idx)) end
    elseif confirm and open.kind.presets and event == PRESSED then
        -- One of the game's own coats, chosen the game's way: the cat wears no preset now.
        coatOf[open.cat:GetAddress()] = nil
        pending = nil
        pcall(unwear, open.cat.CustomizableMeshComponent)
    end
end

-- ------------------------------------------------------------------------------------------------ coats in play
-- Which cats wear which coat preset: chosen in the cat maker, remembered by the cat's name IDs ("prefix|suffix")
-- in a file beside your mods (not in this mod's folder, so updating the mod keeps it), and painted on those cats
-- wherever they show: the forest, menus, portraits. The save only ever has the game's coat (the preset's "like"),
-- so without this mod a cat just wears that.
local RECORDS = nil
do
    local folder = MOD.folder and tostring(MOD.folder):gsub("\\", "/")
    local data = folder and folder:match("^(.*)/mods/[^/]+/?$")
    -- A mod installed from somewhere else (a folder being worked on): wcmods' own place for your files.
    if not data then
        local env = os.getenv("WCMODS_DATA") or (os.getenv("LOCALAPPDATA") and os.getenv("LOCALAPPDATA") .. "/WCMods")
        data = env and env:gsub("\\", "/")
    end
    if data then RECORDS = data .. "/creator-palettes-coats.json" end
end
local records = {}   -- name key -> coat preset id

local function loadRecords()
    if not RECORDS then return end
    -- The file, or (a save cut short between its two renames) the copy it was being replaced with.
    local f = io.open(RECORDS, "rb") or io.open(RECORDS .. ".tmp", "rb")
    if not f then return end
    local text = f:read("a")
    f:close()
    local ok, doc = pcall(Game.json.decode, text)
    if ok and type(doc) == "table" and type(doc.cats) == "table" then records = doc.cats end
end

local function saveRecords()
    if not RECORDS then return end
    local ok, text = pcall(Game.json.encode, { _help = "Creator palettes: the coat preset each cat chose in the cat "
                                                   .. "maker, by its name IDs (prefix|suffix).", cats = records })
    if not ok then return report("saving the coats", text) end
    local f = io.open(RECORDS .. ".tmp", "wb")
    if not f then return report("saving the coats", "can't write " .. RECORDS) end
    f:write(text, "\n")
    f:close()
    -- Windows can't rename onto a file: the old one steps aside first, so one of the three is always whole.
    os.remove(RECORDS .. ".old")
    os.rename(RECORDS, RECORDS .. ".old")
    if os.rename(RECORDS .. ".tmp", RECORDS) then os.remove(RECORDS .. ".old") end
end
loadRecords()

local function str(v)
    local ok, s = pcall(function() return v:ToString() end)
    return ok and s or tostring(v)
end
local function nameKey(comp)
    local d = comp.CustomData
    return str(d.PrefixNameId) .. "|" .. str(d.SuffixNameId)
end
local function prefixOf(key) return key:match("^([^|]*)|") or "" end
local function suffixOf(key) return key:match("|(.*)$") or "" end
-- A rank-up gives your cat a new suffix; a kit's or an apprentice's is where a cat starts, never one it moves to.
local STARTING = { _KIT = true, _PAW = true }

-- The menus' pictures of cats are taken by actors shared by every cat they show. The cat choice takes its small
-- pictures with one, one cat after another, natively, as they load, and shows the cat chosen with another (its
-- CatRef), live. A preset left on the first would go onto the next cat with the same coat (the game doesn't set
-- colours it thinks are there), so out of the forest only the cat choice's own cat is dressed, while it shows: a
-- cat wearing a preset has its saved coat in its small picture. In the forest one of them shows your cat in the
-- inventory, live, and one takes the HUD's picture, once: that one's picture is taken again once it wears your
-- coat (only that one: another's picture target can belong to another cat).
local PICTURE_ACTOR = "BP_UI_CatCustomActor_C"
local HUD_PICTURE = "RT_UI_Portrait_Exploration"
local ticks, retaken, choiceCat = 0, {}, nil   -- choiceCat: the cat choice's own cat's address, while it shows
local function retakeHud(owner)
    local cap = owner.CaptureComponent
    local target = valid(cap) and cap.TextureTarget
    if not (valid(target) and target:GetFName():ToString() == HUD_PICTURE) then return end
    local at = owner:GetAddress()
    if retaken[at] and ticks - retaken[at] < 4 then return end   -- at most every 2 seconds
    retaken[at] = ticks
    cap:CaptureScene()
end

-- Clan cats (and your mentor): records are your own cats', and another save's clan cat can have your cat's name.
local CLAN_CATS = { "/Script/SwtAdventure.SwtAdventureWalkingNPC", "/Script/Wrc.WrcMentorCharacter" }
local clanClasses = nil
local function isClanCat(owner)
    if not clanClasses then
        clanClasses = {}
        for _, path in ipairs(CLAN_CATS) do
            local cls = StaticFindObject(path)
            if valid(cls) then clanClasses[#clanClasses + 1] = cls end
        end
    end
    for _, cls in ipairs(clanClasses) do
        if owner:IsA(cls) then return true end
    end
    return false
end

-- What a cat should wear from here: the preset its name has, or none.
local function dress(comp, owner, inForest)
    local picture = valid(owner) and owner:GetClass():GetFName():ToString() == PICTURE_ACTOR
    local preset = PRESETS[records[nameKey(comp)] or ""]
    if picture and not inForest and owner:GetAddress() ~= choiceCat then preset = nil end
    if preset and inForest and not picture and valid(owner) and isClanCat(owner) then preset = nil end
    local n = 0
    if preset then
        n = wear(comp, preset)
    elseif painted[comp:GetAddress()] then
        n = unwear(comp)
    end
    if n > 0 and picture then retakeHud(owner) end
end

-- Twice a second. In the cat maker: keep its cat painted (the game paints the cat again from its own colours
-- when it sets it up: a new pattern, a new category), and note each cat's colours while no picker shows (a picker
-- shows its focused colour on the cat), for the picker to start on. In play: the cats that chose a coat preset.
local COAT = KINDS[3]
Game.every(0.5, function()
    ticks = ticks + 1
    local picking = open ~= nil
    for _, sn in ipairs(seen) do
        if valid(sn.p) and sn.p:IsVisible() then picking = true end
    end
    if not picking then
        for _, cat in ipairs(FindAllOf("BP_UI_CatCustomActor_C") or {}) do
            if valid(cat) then
                pcall(function()
                    local d = cat.CustomizableMeshComponent.CustomData
                    for _, kind in ipairs(KINDS) do
                        local slot = d[kind.field]
                        before[cat:GetAddress() .. kind.name] = slot
                        if not kind.presets and slot >= FIRST then
                            local c = slotColour(kind, slot)
                            if c then paint(cat, kind, c) end
                        end
                    end
                    local preset = pending and PRESETS[coatOf[cat:GetAddress()] or ""]
                    if preset then
                        paintEntry(cat, COAT, preset)
                        showOnPage(COAT, preset.colour)     -- the page shows the saved coat's otherwise
                    end
                end)
            end
        end
    end
    local function showing(screen)
        for _, m in ipairs(FindAllOf(screen) or {}) do
            if valid(m) and m:IsVisible() then return m end
        end
        return nil
    end
    local choice = (pending or next(records) ~= nil) and showing("WBP_GuiScreenSelectYourCat_C") or nil
    choiceCat = nil
    pcall(function()
        if choice and valid(choice.CatRef) then choiceCat = choice.CatRef:GetAddress() end
    end)
    -- Back at the main menu or the cat choice, the cat that was being made isn't coming: forget its preset, and
    -- take it off the cat maker's cat (the game uses that one for other cats' pictures).
    if pending then
        if choice or showing("WBP_GuiScreenMainMenu_C") then
            pending, coatOf = nil, {}
            for _, cat in ipairs(FindAllOf(PICTURE_ACTOR) or {}) do
                if valid(cat) then pcall(unwear, cat.CustomizableMeshComponent) end
            end
        end
    end
    if next(records) == nil and not pending then return end
    local here = {}
    local pawn = Game.player()
    local inForest = valid(pawn)
    for _, comp in ipairs(FindAllOf("SwtAdventureCustomizableMeshComponent") or {}) do
        if valid(comp) then
            local ok, why = pcall(function()
                local key = nameKey(comp)
                local owner = comp:GetOwner()
                if valid(pawn) and valid(owner) and owner:GetAddress() == pawn:GetAddress() then
                    -- Your cat in the forest. The one just made takes its preset under its name now that it has
                    -- one (it's wearing the preset's game coat, unless the game swapped a Feral Edition one).
                    local made = pending and PRESETS[pending]
                    if made and (comp.CustomData.FurColorIdx == made.like or made.like >= 20) then
                        records[key], pending, coatOf = made.preset, nil, {}
                        saveRecords()
                        log("your cat's coat: %s", made.preset)
                    end
                    -- After a rank-up its suffix changes and its prefix stays (and it still has the preset's coat).
                    if not records[key] and prefixOf(key) ~= "" and not STARTING[suffixOf(key)] then
                        for k, v in pairs(records) do
                            local was = PRESETS[v]
                            if k ~= key and prefixOf(k) == prefixOf(key)
                               and (not was or was.like >= 20 or comp.CustomData.FurColorIdx == was.like) then
                                records[key], records[k] = v, nil
                                saveRecords()
                                break
                            end
                        end
                    end
                end
                here[comp:GetAddress()] = true
                if not (pending and valid(owner) and coatOf[owner:GetAddress()]) then dress(comp, owner, inForest) end
            end)
            if not ok then report("painting a coat", why) end
        end
    end
    for at in pairs(painted) do
        if not here[at] then painted[at] = nil end      -- gone
    end
end)

commands = readCommands()
if not commands then
    log("couldn't read the game's commands, so the new colours can't be reached in the picker")
else
    local ok, err = pcall(RegisterHook, "/Script/SwtEngine.SwtScreen:OnListenCommand", function(ctx, c, e)
        local okCall, why = pcall(onCommand, ctx, c, e)
        if not okCall then report("a key in the picker", why) end
    end)
    if not ok then log("can't hear the picker's keys: %s", tostring(err)) end
end
follow()
MOD.log("ready: new pattern and marking colours and coat presets go in the cat maker's pickers")
