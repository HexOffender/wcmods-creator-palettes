-- Creator palettes: the pattern and marking colours your palettes add (palette.json's slots from 25 up) as choices
-- in the cat maker's own colour picker, beside the game's.
--
-- The game's picker (WBP_GuiPopupColorPicker) shows its colours in a grid it fills itself, the base ones and the
-- bright extras, and never the slots a palette adds, though the game takes them anywhere else (palette.json
-- grows its colour tables when the game starts). So when the pattern or marking picker opens, this puts the
-- new ones in a row of their own under the game's, in the frame the game has for a five-row grid, made from
-- the game's own swatch (WBP_GuiColorGridItem). Pointing at one shows it on the cat, as the game's do;
-- Enter (A) on it chooses it. The cat maker answers keys and the controller, not the mouse: Down from the
-- game's last row goes to the new row, Left and Right move along it, and Up comes back. More new colours
-- than fit in the row go on pages: Right past the row's last turns to the next (round from the last page
-- to the first), Left past its first to the one before, and which page shows is written under the frame.
-- A cat already wearing a new colour starts on it when the picker opens.
--
-- Choosing one sets the cat's colour slot where the cat maker keeps it (the picker's cat, CatRef: its
-- CustomData's Pattern01ColorIdx or Pattern02ColorIdx), so the cat you make keeps it, and paints it on
-- the cat maker's cat (its "Pattern Mask Color" or "Markings Mask Color"), which the game would otherwise
-- paint only from its own colours.
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
}
local FIRST = 25          -- palette.json's first new slot
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
-- (it's either a gap or a colour the game's grid already has). Where two palettes set the same slot, wcmods
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
    local out = {}
    for slot = FIRST, n - 1 do
        local c = t[slot + 1]
        if not game[c.R .. "," .. c.G .. "," .. c.B] then
            out[#out + 1] = { slot = slot, colour = { R = linear(c.R), G = linear(c.G), B = linear(c.B), A = 1 } }
        end
    end
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

-- Put a colour on the cat maker's cat, on every part's materials, as the game does from its own slots.
local function paint(cat, kind, colour)
    local comp = cat.CustomizableMeshComponent
    for _, field in ipairs(MESHES) do
        local ok, mesh = pcall(function() return comp[field] end)
        if ok and valid(mesh) then
            for i = 0, mesh:GetNumMaterials() - 1 do
                local mat = mesh:GetMaterial(i)
                if valid(mat) and mat:GetClass():GetFName():ToString() == "MaterialInstanceDynamic" then
                    mat:SetVectorParameterValue(FName(kind.param), colour)
                end
            end
        end
    end
end

-- ------------------------------------------------------------------------------------------------ the picker
local open = nil     -- the picker showing now: { popup, grid, kind, cat, swatches = { { w } }, entries, page, active }
local seen = {}      -- pickers the game has made (it makes one each time)
local commands = nil -- the game's command numbers by name
local before = {}    -- each cat maker cat's colour slots while no picker shows, by its address and the kind's name
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

-- The new colour a swatch shows on the current page (more than fit in the row go on further pages).
local function entryAt(i)
    return open.entries[(open.page - 1) * #open.swatches + i]
end

local function pages() return math.ceil(#open.entries / #open.swatches) end

-- Show a page of the new colours in the row: each swatch takes one, and the ones left over on the last page hide.
local function showPage(p)
    open.page = p
    open.shown = 0
    for i, s in ipairs(open.swatches) do
        local e = entryAt(i)
        if e then
            s.w.mcGuiColor:SetColorAndOpacity(e.colour)
            s.w:SetVisibility(4)                              -- SelfHitTestInvisible, as the game's swatches
            open.shown = i
        else
            s.w:SetVisibility(1)                              -- Collapsed
        end
    end
    if open.counter then
        pcall(function() open.counter:SetText(FText(string.format("%d / %d", p, pages()))) end)
    end
end

-- The page counter under the frame, in the picker's own grid, when the new colours take more than one page.
local function makeCounter(grid, x, y, size)
    local t = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"), grid, FName("None"))
    local placed = grid.mcGuiCanvasItems:AddChildToCanvas(t)
    placed:SetAutoSize(true)
    placed:SetAlignment({ X = 0.5, Y = 0 })
    placed:SetPosition({ X = x, Y = y })
    local f = t.Font
    t:SetFont({ FontObject = f.FontObject, TypefaceFontName = f.TypefaceFontName, Size = size,
                LetterSpacing = 0, SkewAmount = 0, bForceMonospaced = false, MonospacedWidth = 1 })
    local r, g, b = TEXT:match("#(%x%x)(%x%x)(%x%x)")
    t:SetColorAndOpacity({ SpecifiedColor = { R = linear(tonumber(r, 16)), G = linear(tonumber(g, 16)),
                                              B = linear(tonumber(b, 16)), A = 0.85 }, ColorUseRule = 0 })
    t:SetVisibility(3)                                        -- HitTestInvisible
    return t
end

-- The colour page's swatch for a kind (its button: Pattern, or Markings), as the cat maker shows the chosen colour.
local function showOnPage(kind, colour)
    for _, panel in ipairs(FindAllOf("WBP_GuiPanelCustomizationColors_C") or {}) do
        if valid(panel) and panel:IsVisible() then
            pcall(function()
                local option = kind.name == "pattern" and panel.mcGuiOptionPattern or panel.mcGuiOptionMarkings
                option.mcGuiIcon:SetColorAndOpacity(colour)
            end)
        end
    end
end

-- Show one of the new swatches as chosen (and on the cat), or none (nil): the game's own then lights up again.
local function setActive(i)
    if not open then return end
    if open.active == i then return end
    if open.active then highlight(open.swatches[open.active], false) end
    open.active = i
    local native = nil
    pcall(function() native = open.grid.GridNavigation.CurrentControl end)
    if i then
        if valid(native) then focus(native, false) end
        highlight(open.swatches[i], true)
        paint(open.cat, open.kind, entryAt(i).colour)
    elseif valid(native) then
        focus(native, true)
        pcall(function() paint(open.cat, open.kind, native.mcGuiColor.ColorAndOpacity) end)
    end
end

local function choose(i)
    -- Once, and only on a picker that's still showing: a second Back would leave the cat maker.
    if not open or open.chosen or not (valid(open.popup) and open.popup:IsVisible()) then return end
    open.chosen = true
    local s = entryAt(i)
    local cat, kind, popup = open.cat, open.kind, open.popup
    local function apply()
        cat.CustomizableMeshComponent.CustomData[kind.field] = s.slot
        before[cat:GetAddress() .. kind.name] = s.slot
        paint(cat, kind, s.colour)
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
    log("%s colour: slot %d", kind.name, s.slot)
end

local function attach(popup)
    local grid = popup.mcGuiGrid
    local n = grid.Items:GetArrayNum()
    if n < 6 then return false end            -- not filled in yet
    local kind = kindOf(grid)
    if not kind then return true end          -- fur or eyes: nothing to add
    local entries = newSlots(kind)
    if #entries == 0 then return true end
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
    local row = math.ceil(n / cols)
    local lib = StaticFindObject("/Script/UMG.Default__WidgetBlueprintLibrary")
    local pc = Game.controller()
    local swatches = {}
    for k = 1, math.min(MAX_NEW, cols, #entries) do
        local w = lib:Create(pc, cls, pc)
        local placed = grid.mcGuiCanvasItems:AddChildToCanvas(w)
        pcall(function() placed:SetAutoSize(true) end)
        w:SetRenderTranslation({ X = t1.X + (k - 1) * dx, Y = t1.Y + row * dy })
        swatches[#swatches + 1] = { w = w }
    end
    -- The game's frame for five rows (it has one for a grid of 25), in place of the four-row one.
    pcall(function()
        popup.CanvasBackground1:SetVisibility(2)
        popup.CanvasBackground2:SetVisibility(4)
    end)
    open = { popup = popup, grid = grid, kind = kind, cat = popup.CatRef, swatches = swatches, active = nil,
             cols = cols, count = n, entries = entries, page = 1, shown = 0 }
    if pages() > 1 then
        -- Centred under the row's middle swatch, a little below the frame.
        local ok, made = pcall(function()
            local width = dx * 0.8
            pcall(function() width = grid.Items[1]:GetDesiredSize().X end)
            local mid = math.ceil(#swatches / 2)
            return makeCounter(grid, t1.X + (mid - 1) * dx + width / 2, t1.Y + (row + 1.15) * dy, dx * 0.2)
        end)
        if ok then open.counter = made else report("the page counter", made) end
    end
    showPage(1)
    log("%d new %s colour%s in the picker (%d page%s)", #entries, kind.name, #entries == 1 and "" or "s",
        pages(), pages() == 1 and "" or "s")
    -- A cat already wearing one of the new colours starts on it, on its page: the game can't show the slot,
    -- so it starts on its own first swatch (and shows that on the cat). A moment later, once the game has.
    local cat = open.cat
    local was = valid(cat) and before[cat:GetAddress() .. kind.name] or nil
    if was and was >= FIRST then
        Game.after(0.1, function()
            if not (open and valid(popup) and open.popup:GetAddress() == popup:GetAddress()) or open.active then
                return
            end
            for i, e in ipairs(open.entries) do
                if e.slot == was then
                    showPage(math.ceil(i / #open.swatches))
                    setActive((i - 1) % #open.swatches + 1)
                    return
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
end)

-- Keys and the controller: the picker hears commands; while a new swatch is chosen this answers them instead.
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
    if open.active then
        if not (up or down or left or right or confirm) then return end
        commandParam:set(C.NoCommand)
        if event ~= PRESSED then return end
        if left and open.active > 1 then setActive(open.active - 1)
        elseif right and open.active < open.shown then setActive(open.active + 1)
        elseif (left or right) and pages() > 1 then
            -- Past either end of the row: the previous or next page of new colours (round from the last to
            -- the first), on its last or first swatch.
            local p = left and (open.page - 2) % pages() + 1 or open.page % pages() + 1
            highlight(open.swatches[open.active], false)
            open.active = nil
            showPage(p)
            setActive(left and open.shown or 1)
        elseif up then setActive(nil)
        elseif confirm then choose(open.active) end
    elseif down then
        -- Down from the game's last row goes to the new one, under the same column (or its last swatch).
        local native, index = nil, nil
        pcall(function() native = open.grid.GridNavigation.CurrentControl end)
        if not valid(native) then return end
        for i = 1, open.count do
            if open.grid.Items[i]:GetAddress() == native:GetAddress() then index = i break end
        end
        if not index or index <= open.count - open.cols then return end
        commandParam:set(C.NoCommand)
        if event ~= PRESSED then return end
        setActive(math.min((index - 1) % open.cols + 1, open.shown))
    end
end

-- While the cat maker shows a cat with one of the new colours, keep it painted: the game paints the cat again
-- from its own colours when it sets it up (a new pattern, a new category). And note each cat's colours while
-- no picker shows (a picker shows its focused colour on the cat), for the picker to start on.
Game.every(0.5, function()
    if open then return end
    for _, s in ipairs(seen) do
        if valid(s.p) and s.p:IsVisible() then return end
    end
    for _, cat in ipairs(FindAllOf("BP_UI_CatCustomActor_C") or {}) do
        if valid(cat) then
            pcall(function()
                local d = cat.CustomizableMeshComponent.CustomData
                for _, kind in ipairs(KINDS) do
                    local slot = d[kind.field]
                    before[cat:GetAddress() .. kind.name] = slot
                    if slot >= FIRST then
                        local c = slotColour(kind, slot)
                        if c then paint(cat, kind, c) end
                    end
                end
            end)
        end
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
MOD.log("ready: new pattern and marking colours go in the cat maker's picker")
