-- ============================================================================
--  TEK OPTIMIZER v4.3 (Steal a Brainrot)
--  Starts INSTANTLY on load (waits for game load, then resweeps streaming
--  content automatically) and shows the full load time.
--  Removes buildings (Craft, Shops, Wheel, Plaza),
--  hides walls / tunnel / signs / slabs (collision stays),
--  hides carpet brainrots + "Empty Base" bases only, strips textures
--  (hotbar icons stay visible), keeps colors. Optional GALAXY SKY.
--  Bases are NEVER destroyed, only hidden.
--  Quantum Cloner + "Swap with Clone" prompts are whitelisted.
--  A banner on top shows what was removed + load time.
--  The "TEK" mini button opens the settings.
--
--  HOW TO USE:
--    1. Join Steal a Brainrot (private server recommended)
--    2. Execute -> runs instantly + resweeps, banner shows result + load time
--    3. "TEK" mini button (top right) or RightShift = settings
--    4. Rejoin restores everything
--
--  NOTES:
--  - Hidden carpet brainrots can still be bought with E.
--  - Hand items keep their inventory icons; only 3D textures are stripped.
--  - Hidden empty bases reappear automatically once a brainrot moves in.
--  - Visuals only, on your client. Executors violate Roblox ToS (ban risk).
--    Best used on an alt account + private server.
-- ============================================================================

local loadStart = os.clock()

local CONFIG = {
    AutoRun    = true,  -- run instantly on load + auto resweep streaming content

    Buildings  = true,  -- Craft Machine, Shops, Crystal Wheel, Trade Plaza
    WallsSigns = true,  -- walls / tunnel / signs / slabs (always Hide, never Destroy)
    Textures   = true,  -- textures, particles, lights, world GUIs, shadows
    GalaxySky  = true,  -- galaxy night sky (stars + purple nebula). Off = bright day low-mode
    CarpetPets = true,  -- hide brainrots walking on the carpet (buying with E still works)
    EmptyBases = true,  -- hide ONLY bases with an "Empty" sign (always Hide, never Destroy)
    HeldItems  = true,  -- strip textures of hand + inventory items (icons stay visible)

    DeleteMode = "Destroy", -- "Destroy" | "Hide" (does NOT apply to bases/walls/signs: those are always Hide)
}

local GUI_NAME = "TekOptimizerGui"
local ACCENT = Color3.fromRGB(60, 220, 110)

local KEYWORDS = {
    craft = { "craft", "fuse", "cyber" },
    shop  = { "shop", "store", "coin", "kiosk" },
    robux = { "robux" },
    wheel = { "wheel", "spin", "crystal" },
    plaza = { "trade", "trading", "plaza", "trader" },
    wall  = { "wall", "walls", "barrier", "tunnel", "portal", "gate", "entrance", "entry", "fence", "divider", "border", "boundary", "perimeter", "outer", "surround", "beam", "pillar", "post", "pole", "sign", "board", "panel", "display", "screen", "slab", "monolith", "frame" },
}

-- ALWAYS KEEP: Quantum Cloner machine and its "Swap with Clone" prompt stay visible.
local KEEP_SUBSTR = { "quantum", "cloner", "clone", "swap" }

local PROTECTED_SUBSTR = {
    "base", "plot", "tycoon", "slot", "conveyor", "carpet", "belt",
    "spawn", "baseplate", "checkpoint",
}

local EXACT_TARGETS = {
    craft = { "CraftingMachine", "FuseMachine" },
    shop  = { "Shop", "ShopNPCRobuxIdle" },
    robux = { "RobuxShop", "ShopNPCRobuxIdle" },
    wheel = { "CrystalSpinWheel" },
    plaza = { "TradePlazaPortal" },
    wall  = {},
}

local SIGN_WORDS = { "live", "spawn", "guaranteed", "legendary", "mythic", "luck" }

local NEVER_DELETE = {
    ["lostraders"] = true,
    ["renderedmovinganimals"] = true,
    ["plots"] = true,
    ["map"] = true,
    ["road"] = true,
    ["roadpanel"] = true,
    ["terrain"] = true,
    ["spawnlocation"] = true,
    ["beehive"] = true,
}

-- ============================================================================
local Players   = game:GetService("Players")
local Lighting  = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local UIS       = game:GetService("UserInputService")
local Terrain   = Workspace:FindFirstChildOfClass("Terrain")

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Wait until the client finished loading (instant when already loaded),
-- otherwise the first sweep runs on an empty world.
pcall(function()
    if not game:IsLoaded() then game.Loaded:Wait() end
end)

local streamingOn = false
pcall(function() streamingOn = Workspace.StreamingEnabled end)

local deleted, stripped, guis = 0, 0, 0
local statusLabel = nil
local bannerBox, bannerStats = nil, nil
local bannerGen = 0

local function log(msg)
    print("[TEK] " .. tostring(msg))
end

local function setStatus(msg)
    log(msg)
    if statusLabel then
        pcall(function() statusLabel.Text = "Status: " .. tostring(msg) end)
    end
end

local function showBanner(stats, holdTime)
    bannerGen = bannerGen + 1
    local myGen = bannerGen
    if bannerBox then pcall(function() bannerBox.Visible = true end) end
    if bannerStats then pcall(function() bannerStats.Text = stats end) end
    task.spawn(function()
        task.wait(holdTime or 8)
        if myGen == bannerGen and bannerBox then
            pcall(function() bannerBox.Visible = false end)
        end
    end)
end

local function lower(s)
    local ok, res = pcall(function() return string.lower(s) end)
    return ok and res or ""
end

local function containsAny(haystack, list)
    for _, word in ipairs(list) do
        if string.find(haystack, word, 1, true) then
            return true, word
        end
    end
    return false
end

local function isKept(name)
    return containsAny(lower(name), KEEP_SUBSTR)
end

local function guiHasKeepText(gui)
    local found = false
    pcall(function()
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                local ok, txt = pcall(function() return d.Text end)
                if ok and txt and isKept(txt) then
                    found = true
                    break
                end
            end
        end
    end)
    return found
end

local function activeKeywords()
    local out = {}
    if CONFIG.Buildings then
        for _, w in ipairs(KEYWORDS.craft) do out[#out + 1] = w end
        for _, w in ipairs(KEYWORDS.shop)  do out[#out + 1] = w end
        for _, w in ipairs(KEYWORDS.robux) do out[#out + 1] = w end
        for _, w in ipairs(KEYWORDS.wheel) do out[#out + 1] = w end
        for _, w in ipairs(KEYWORDS.plaza) do out[#out + 1] = w end
    end
    if CONFIG.WallsSigns then for _, w in ipairs(KEYWORDS.wall) do out[#out + 1] = w end end
    return out
end

local function activeExact()
    local out = {}
    local function add(list) for _, n in ipairs(list) do out[lower(n)] = true end end
    if CONFIG.Buildings then
        add(EXACT_TARGETS.craft)
        add(EXACT_TARGETS.shop)
        add(EXACT_TARGETS.robux)
        add(EXACT_TARGETS.wheel)
        add(EXACT_TARGETS.plaza)
    end
    if CONFIG.WallsSigns then add(EXACT_TARGETS.wall) end
    return out
end

local function wallWordsNow()
    local out = {}
    if CONFIG.WallsSigns then for _, w in ipairs(KEYWORDS.wall) do out[#out + 1] = w end end
    return out
end

local function wallExactNow()
    local out = {}
    if CONFIG.WallsSigns then for _, n in ipairs(EXACT_TARGETS.wall) do out[lower(n)] = true end end
    return out
end

local function isWallTarget(inst)
    if wallExactNow()[lower(inst.Name)] then return true end
    local ww = wallWordsNow()
    if #ww == 0 then return false end
    return containsAny(lower(inst.Name), ww)
end

local function isProtected(inst)
    if inst.Name == GUI_NAME then return true end
    if NEVER_DELETE[lower(inst.Name)] then return true end
    if isKept(inst.Name) then return true end
    local char = LocalPlayer.Character
    if char and (inst == char or inst:IsDescendantOf(char)) then
        return true
    end
    if inst:IsA("Model") then
        if inst:FindFirstChildOfClass("Humanoid") then return true end
        if inst:FindFirstChild("HumanoidRootPart") then return true end
        if inst:FindFirstChildOfClass("Animator") then return true end
        if inst:FindFirstChildOfClass("AnimationController") then return true end
        if inst:FindFirstChild("Handle") then return true end
        if Players:GetPlayerFromCharacter(inst) then return true end
    end
    if inst:IsA("Humanoid") or inst:IsA("HumanoidDescription") then return true end
    if inst:IsDescendantOf(Players) then return true end
    local n = lower(inst.Name)
    for _, p in ipairs(PROTECTED_SUBSTR) do
        if string.find(n, p, 1, true) then return true end
    end
    local parent = inst.Parent
    if parent then
        local pn = lower(parent.Name)
        if NEVER_DELETE[pn] then return true end
        for _, p in ipairs(PROTECTED_SUBSTR) do
            if string.find(pn, p, 1, true) then return true end
        end
    end
    return false
end

local function shouldRemove(inst, removeWords)
    if isProtected(inst) then return false end
    local a = inst.Parent
    while a do
        local an = lower(a.Name)
        if an == "plots" or an == "bases" or an == "tycoons" then return false end
        a = a.Parent
    end
    local c = inst.ClassName
    if c ~= "Model" and c ~= "Folder" then return false end
    if activeExact()[lower(inst.Name)] then return true end
    if #removeWords == 0 then return false end
    return containsAny(lower(inst.Name), removeWords)
end

local function collectTargets(inst, depth, removeWords, out)
    if depth > 3 then return end
    local kids
    local ok = pcall(function() kids = inst:GetChildren() end)
    if not ok or not kids then return end
    for _, sub in ipairs(kids) do
        if shouldRemove(sub, removeWords) then
            out[#out + 1] = sub
        elseif (sub:IsA("Model") or sub:IsA("Folder")) and not isProtected(sub) then
            local an = lower(sub.Name)
            if an ~= "plots" and an ~= "bases" and an ~= "tycoons" and not NEVER_DELETE[an] then
                collectTargets(sub, depth + 1, removeWords, out)
            end
        end
    end
end

local function hideInstance(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.Transparency = 1
                d.CastShadow = false
                d.CanCollide = true
                d.Material = Enum.Material.SmoothPlastic
            end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 1 end)
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
            or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
            pcall(function() d.Enabled = false end)
        end
    end
end

local function removeInstance(inst)
    if CONFIG.DeleteMode == "Hide" and inst:IsA("Model") then
        pcall(hideInstance, inst)
        deleted = deleted + 1
    else
        pcall(function() inst:Destroy() end)
        deleted = deleted + 1
    end
end

local function applyRemoval(inst)
    if isWallTarget(inst) then
        log("Hiding wall: " .. inst:GetFullName())
        pcall(hideInstance, inst)
        deleted = deleted + 1
    else
        log("Removing: " .. inst:GetFullName())
        removeInstance(inst)
    end
end

local function inProtectedContainer(d)
    local a = d.Parent
    while a and a ~= Workspace do
        if a:IsA("Model") then
            if a:FindFirstChildOfClass("Humanoid") then return true end
            if a:FindFirstChildOfClass("Animator") then return true end
            if a:FindFirstChildOfClass("AnimationController") then return true end
            if Players:GetPlayerFromCharacter(a) then return true end
        end
        local an = lower(a.Name)
        if an == "plots" or an == "bases" or an == "tycoons"
            or an == "renderedmovinganimals" then return true end
        for _, p in ipairs(PROTECTED_SUBSTR) do
            if string.find(an, p, 1, true) then return true end
        end
        a = a.Parent
    end
    return false
end

local function isWallShapedFast(x, y, z)
    local minXZ = x < z and x or z
    local maxXZ = x > z and x or z
    if y >= 8 and maxXZ >= 25 and minXZ <= 6 then return true end
    if y >= 6 and x <= 10 and z <= 10 and minXZ <= 5 then return true end
    local d1, d2, d3 = x, y, z
    if d1 > d2 then d1, d2 = d2, d1 end
    if d2 > d3 then d2, d3 = d3, d2 end
    if d1 > d2 then d1, d2 = d2, d1 end
    if d3 >= 30 and d2 <= 8 then return true end
    if d3 >= 8 and d2 <= 4 then return true end
    return false
end

local hiddenPlots = {}
local plotOriginals = {}

local function hideBrainrot(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            pcall(function()
                d.Transparency = 1
                d.CastShadow = false
            end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            pcall(function() d.Transparency = 1 end)
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
            or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles")
            or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            pcall(function() d.Enabled = false end)
        elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
            pcall(function() d.Enabled = false end)
        end
    end
end

local function plotOwnedBySomeone(plot)
    local pn = lower(plot.Name)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.find(pn, lower(p.Name), 1, true) then return true end
        local dd = lower(p.DisplayName)
        if dd ~= "" and string.find(pn, dd, 1, true) then return true end
    end
    return false
end

local function plotSaysEmpty(plot)
    for _, d in ipairs(plot:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local ok, txt = pcall(function() return d.Text end)
            if ok and txt and string.find(lower(txt), "empty", 1, true) then
                return true
            end
        end
    end
    return false
end

local function hidePlot(plot)
    if hiddenPlots[plot] then return end
    local saved = {}
    for _, d in ipairs(plot:GetDescendants()) do
        if d:IsA("BasePart") then
            saved[#saved + 1] = { d, "Transparency", d.Transparency }
            pcall(function()
                d.Transparency = 1
                d.CastShadow = false
            end)
        elseif d:IsA("Decal") or d:IsA("Texture") then
            saved[#saved + 1] = { d, "Transparency", d.Transparency }
            pcall(function() d.Transparency = 1 end)
        elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
            saved[#saved + 1] = { d, "Enabled", d.Enabled }
            pcall(function() d.Enabled = false end)
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
            pcall(function() d.Enabled = false end)
        end
    end
    plotOriginals[plot] = saved
    hiddenPlots[plot] = true
end

local function unhidePlot(plot)
    if not hiddenPlots[plot] then return end
    hiddenPlots[plot] = nil
    local saved = plotOriginals[plot]
    plotOriginals[plot] = nil
    if saved then
        for _, rec in ipairs(saved) do
            pcall(function() rec[1][rec[2]] = rec[3] end)
        end
    end
    log("Base visible again: " .. plot.Name)
end

local function inPetOrBase(d)
    local a = d.Parent
    while a and a ~= Workspace do
        if a:IsA("Model") then
            if a:FindFirstChildOfClass("Humanoid") then return true end
            if a:FindFirstChildOfClass("Animator") then return true end
            if a:FindFirstChildOfClass("AnimationController") then return true end
            if Players:GetPlayerFromCharacter(a) then return true end
        end
        local an = lower(a.Name)
        if an == "plots" or an == "bases" or an == "tycoons"
            or an == "renderedmovinganimals" then return true end
        a = a.Parent
    end
    return false
end

local function hidePart(p)
    pcall(function()
        if p:IsA("BasePart") then
            p.Transparency = 1
            p.CastShadow = false
        elseif p:IsA("Decal") or p:IsA("Texture") then
            p.Transparency = 1
        elseif p:IsA("SurfaceGui") or p:IsA("BillboardGui") then
            p.Enabled = false
        elseif p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") then
            p.Enabled = false
        end
    end)
end

local function hideSignStructure(label)
    if inPetOrBase(label) then return 0 end
    if isKept(label.Text) then return 0 end
    local holder = label
    while holder and holder ~= Workspace and not holder:IsA("BasePart") do
        holder = holder.Parent
    end
    if not holder or holder == Workspace then
        pcall(function() label.Enabled = false end)
        return 1
    end
    local root = holder
    local a = holder.Parent
    while a and a ~= Workspace and a:IsA("Model") do
        local an = lower(a.Name)
        if NEVER_DELETE[an] then break end
        if a:FindFirstChildOfClass("Humanoid") then break end
        if Players:GetPlayerFromCharacter(a) then break end
        root = a
        a = a.Parent
    end
    if root ~= holder and not inPetOrBase(root) then
        local big = false
        pcall(function()
            if #root:GetDescendants() > 300 then big = true end
        end)
        if not big then
            local n = 0
            pcall(function() n = #root:GetDescendants() end)
            log("Hiding sign: " .. root:GetFullName())
            pcall(hideInstance, root)
            return n
        end
    end
    hidePart(holder)
    local count = 1
    local hp = nil
    pcall(function() hp = holder.Position end)
    local siblings = {}
    pcall(function()
        if holder.Parent then siblings = holder.Parent:GetChildren() end
    end)
    for _, sib in ipairs(siblings) do
        if sib ~= holder and sib:IsA("BasePart") then
            local s = sib.Size
            if s.Y >= 6 and s.X <= 3 and s.Z <= 3 and not inPetOrBase(sib) then
                local near = true
                if hp then
                    pcall(function()
                        local sp = sib.Position
                        local dx, dz = sp.X - hp.X, sp.Z - hp.Z
                        near = (dx * dx + dz * dz) <= 900
                    end)
                end
                if near then
                    hidePart(sib)
                    count = count + 1
                end
            end
        end
    end
    return count
end

local function removeSigns()
    local n = 0
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local ok, txt = pcall(function() return d.Text end)
            if ok and txt and not isKept(txt) and containsAny(lower(txt), SIGN_WORDS) then
                n = n + hideSignStructure(d)
            end
        end
    end
    return n
end

local function stripTool(tool)
    for _, d in ipairs(tool:GetDescendants()) do
        pcall(function()
            if d:IsA("MeshPart") then
                d.TextureID = ""
                d.Material = Enum.Material.SmoothPlastic
                d.CastShadow = false
            elseif d:IsA("SpecialMesh") then
                d.TextureId = ""
            elseif d:IsA("Decal") or d:IsA("Texture") then
                d:Destroy()
            elseif d:IsA("SurfaceAppearance") then
                d:Destroy()
            elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
                or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
                if CONFIG.Textures then d:Destroy() end
            elseif d:IsA("BasePart") and d.Name == "Handle" then
                d.Material = Enum.Material.SmoothPlastic
                d.CastShadow = false
                d.Reflectance = 0
            end
        end)
    end
end

local function stripHeldItems()
    if not CONFIG.HeldItems then return 0 end
    local n = 0
    local function scan(container)
        if not container then return end
        local kids
        local ok = pcall(function() kids = container:GetChildren() end)
        if not ok or not kids then return end
        for _, t in ipairs(kids) do
            if t:IsA("Tool") then
                stripTool(t)
                n = n + 1
            elseif t:IsA("Model") and not Players:GetPlayerFromCharacter(t)
                and not t:FindFirstChildOfClass("Humanoid") then
                stripTool(t)
                n = n + 1
            end
        end
    end
    scan(LocalPlayer.Character)
    pcall(function() scan(LocalPlayer:FindFirstChild("Backpack")) end)
    return n
end

local function hookHeldItems()
    pcall(function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            bp.ChildAdded:Connect(function(t)
                task.defer(function()
                    if CONFIG.HeldItems and (t:IsA("Tool") or t:IsA("Model")) then
                        stripTool(t)
                    end
                end)
            end)
        end
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            char.ChildAdded:Connect(function(t)
                task.defer(function()
                    if CONFIG.HeldItems and (t:IsA("Tool") or t:IsA("Model")) then
                        if t:IsA("Model") and (t:FindFirstChildOfClass("Humanoid")
                            or Players:GetPlayerFromCharacter(t)) then return end
                        stripTool(t)
                    end
                end)
            end)
        end
    end)
end

local function stripInstance(d)
    local changed = false
    local ok = pcall(function()
        if d:IsA("Decal") or d:IsA("Texture") then
            if CONFIG.Textures then d:Destroy() changed = true end
        elseif d:IsA("SurfaceAppearance") or d:IsA("MaterialVariant") then
            if CONFIG.Textures then d:Destroy() changed = true end
        elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic")
            or d:IsA("PantsGraphic") or d:IsA("BodyColors") then
            if CONFIG.Textures then d:Destroy() changed = true end
        elseif d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam")
            or d:IsA("Fire") or d:IsA("Smoke") or d:IsA("Sparkles") then
            if CONFIG.Textures then d:Destroy() changed = true end
        elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
            if CONFIG.Textures then d:Destroy() changed = true end
        elseif d:IsA("MeshPart") then
            if CONFIG.Textures then
                d.TextureID = ""
                d.Material = Enum.Material.SmoothPlastic
                d.CastShadow = false
                changed = true
            end
        elseif d:IsA("SpecialMesh") then
            if CONFIG.Textures then
                d.TextureId = ""
                changed = true
            end
        elseif d:IsA("BasePart") then
            d.CastShadow = false
            d.Reflectance = 0
            d.Material = Enum.Material.SmoothPlastic
            changed = true
        elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("Adornment") then
            if CONFIG.Textures and not isProtected(d) and not guiHasKeepText(d) then
                local an = d
                local keepUp = false
                while an and an ~= Workspace do
                    if isKept(an.Name) then keepUp = true break end
                    an = an.Parent
                end
                if not keepUp then
                    d:Destroy() changed = true
                end
            end
        elseif d:IsA("PostEffect") then
            d:Destroy() changed = true
        end
    end)
    return ok and changed
end

local function cleanPlayerGui(removeWords)
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, g in ipairs(pg:GetChildren()) do
        if g.Name ~= GUI_NAME and not isKept(g.Name) then
            local hit = containsAny(lower(g.Name), removeWords)
            if hit and (g:IsA("ScreenGui") or g:IsA("BillboardGui") or g:IsA("SurfaceGui") or g:IsA("Frame")) then
                pcall(function()
                    if g:IsA("ScreenGui") then g.Enabled = false else g:Destroy() end
                end)
                guis = guis + 1
            end
        end
    end
end

-- Galaxy sky: starry night + purple nebula (no external assets needed).
-- Everything is created/updated in code, so it can't break.
local function applyGalaxySky()
    if not CONFIG.GalaxySky then return end
    pcall(function()
        Lighting.ClockTime = 0 -- midnight so stars show
        Lighting.Brightness = 1
        Lighting.Ambient = Color3.fromRGB(42, 40, 75)
        Lighting.OutdoorAmbient = Color3.fromRGB(48, 42, 95)
        Lighting.FogColor = Color3.fromRGB(10, 8, 26)
        Lighting.FogEnd = 100000
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Parent = Lighting
        end
        sky.StarCount = 5000
        sky.CelestialBodiesShown = true
        for _, a in ipairs(Lighting:GetChildren()) do
            if a:IsA("Atmosphere") then a:Destroy() end
        end
        local at = Instance.new("Atmosphere")
        at.Density = 0.35
        at.Offset = 0.1
        at.Color = Color3.fromRGB(95, 75, 175)
        at.Decay = Color3.fromRGB(125, 70, 200)
        at.Glare = 0
        at.Haze = 3
        at.Parent = Lighting
        local bloom = Instance.new("BloomEffect")
        bloom.Intensity = 0.35
        bloom.Size = 24
        bloom.Threshold = 1
        bloom.Parent = Lighting
    end)
    log("Galaxy sky applied")
end

local function applyDayLow()
    if CONFIG.GalaxySky then return end
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.ExposureCompensation = 0
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("PostEffect") then fx:Destroy() end
        end
    end)
end

local function listMapNames()
    local names = {}
    for _, c in ipairs(Workspace:GetChildren()) do
        names[#names + 1] = c.ClassName .. " | " .. c.Name
    end
    table.sort(names)
    print("---- MAP TOP LEVEL ----")
    for _, n in ipairs(names) do print("MAP: " .. n) end
    print("---- END TOP LEVEL (" .. #names .. ") ----")
    local sub = 0
    for _, c in ipairs(Workspace:GetChildren()) do
        if c:IsA("Model") or c:IsA("Folder") then
            local kids = c:GetChildren()
            if #kids > 0 and #kids <= 60 then
                print("---- IN " .. c.Name .. " (" .. #kids .. ") ----")
                local kn = {}
                for _, k in ipairs(kids) do kn[#kn + 1] = k.ClassName .. " | " .. k.Name end
                table.sort(kn)
                for _, n in ipairs(kn) do print("SUB: " .. n) end
                sub = sub + 1
            end
        end
    end
    setStatus("Names printed to F9 console (MAP + SUB). Send exact wall names!")
end

local running = false
local function runOptimizer()
    if running then return end
    running = true
    deleted, stripped, guis = 0, 0, 0
    local REMOVE_WORDS = activeKeywords()
    setStatus("running...")

    do
        local targets = {}
        for _, child in ipairs(Workspace:GetChildren()) do
            if shouldRemove(child, REMOVE_WORDS) then
                targets[#targets + 1] = child
            elseif (child:IsA("Model") or child:IsA("Folder")) and not isProtected(child) then
                local an = lower(child.Name)
                if an ~= "plots" and an ~= "bases" and an ~= "tycoons" and not NEVER_DELETE[an] then
                    collectTargets(child, 1, REMOVE_WORDS, targets)
                end
            end
        end
        for _, t in ipairs(targets) do
            applyRemoval(t)
        end
    end

    local hiddenPets, hiddenBases = 0, 0
    if CONFIG.CarpetPets then
        local pen = Workspace:FindFirstChild("RenderedMovingAnimals")
        if pen then
            for _, pet in ipairs(pen:GetChildren()) do
                if pet:IsA("Model") and not Players:GetPlayerFromCharacter(pet) then
                    pcall(hideBrainrot, pet)
                    hiddenPets = hiddenPets + 1
                end
            end
        end
    end
    if CONFIG.EmptyBases then
        local plotList = {}
        local plotsFolder = Workspace:FindFirstChild("Plots")
        if plotsFolder then
            for _, pl in ipairs(plotsFolder:GetChildren()) do plotList[#plotList + 1] = pl end
        else
            for _, child in ipairs(Workspace:GetChildren()) do
                if child:IsA("Model") or child:IsA("Folder") then
                    local cn = lower(child.Name)
                    if cn == "plots" or cn == "bases" or cn == "tycoons" then
                        for _, pl in ipairs(child:GetChildren()) do plotList[#plotList + 1] = pl end
                    end
                end
            end
        end
        for _, pl in ipairs(plotList) do
            if not plotOwnedBySomeone(pl) then
                local char = LocalPlayer.Character
                local occupied = char and char:IsDescendantOf(pl)
                if not occupied and plotSaysEmpty(pl) then
                    log("Hiding empty base: " .. pl.Name)
                    pcall(hidePlot, pl)
                    hiddenBases = hiddenBases + 1
                end
            end
        end
    end

    -- Single pass: shape-hide + texture strip + sign collection in one loop.
    local sizedWalls, signsHidden = 0, 0
    if CONFIG.WallsSigns or CONFIG.Textures then
        local doShape = CONFIG.WallsSigns
        local doTex = CONFIG.Textures
        local char = LocalPlayer.Character
        local all = Workspace:GetDescendants()
        local signLabels = {}
        local count = #all
        for i = 1, count do
            local d = all[i]
            if d ~= char and not (char and d:IsDescendantOf(char)) then
                if d:IsA("BasePart") then
                    if doShape then
                        local s = d.Size
                        if isWallShapedFast(s.X, s.Y, s.Z) and not inProtectedContainer(d) then
                            local hid = false
                            pcall(function()
                                if d.Transparency < 1 then
                                    d.Transparency = 1
                                    d.CastShadow = false
                                    hid = true
                                end
                            end)
                            if hid then sizedWalls = sizedWalls + 1 end
                        end
                    end
                    if doTex then
                        if stripInstance(d) then stripped = stripped + 1 end
                    end
                elseif doShape and (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then
                    local ok, txt = pcall(function() return d.Text end)
                    if ok and txt and txt ~= "" and not isKept(txt) then
                        if containsAny(lower(txt), SIGN_WORDS) then
                            signLabels[#signLabels + 1] = d
                        end
                    end
                else
                    if doTex then
                        if stripInstance(d) then stripped = stripped + 1 end
                    end
                end
            end
            if i % 25000 == 0 then task.wait() end
        end
        if sizedWalls > 0 then log("Walls/deco hidden by shape: " .. sizedWalls) end
        for _, lbl in ipairs(signLabels) do
            signsHidden = signsHidden + hideSignStructure(lbl)
        end
        if signsHidden > 0 then log("Signs/boards hidden: " .. signsHidden) end
    end

    local itemsDone = 0
    if CONFIG.HeldItems then
        itemsDone = stripHeldItems()
        if itemsDone > 0 then log("Hand/inventory items stripped: " .. itemsDone) end
    end

    -- Lighting: galaxy sky OR bright day low-mode (post effects cleared first)
    pcall(function()
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("PostEffect") then fx:Destroy() end
        end
    end)
    if CONFIG.GalaxySky then
        applyGalaxySky()
    else
        applyDayLow()
    end
    pcall(function()
        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 0
            Terrain.Decoration = false
        end
    end)
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)

    pcall(cleanPlayerGui, REMOVE_WORDS)

    local loadTime = os.clock() - loadStart
    local msg = ("REMOVED -> %d objects | %d shaped | %d signs | %d carpet | %d bases | %d items | %d textures | %d guis | load time: %.1fs"):format(deleted, sizedWalls, signsHidden, hiddenPets, hiddenBases, itemsDone, stripped, guis, loadTime)
    setStatus("DONE! " .. msg)
    showBanner(msg, 12)
    running = false
end

-- Catch everything that (re)spawns late: streamed buildings AND streamed
-- wall parts / signs are hidden here too, not just stripped.
Workspace.DescendantAdded:Connect(function(d)
    task.defer(function()
        local char = LocalPlayer.Character
        if char and (d == char or d:IsDescendantOf(char)) then return end
        if d:IsA("Model") or d:IsA("Folder") then
            if shouldRemove(d, activeKeywords()) then
                applyRemoval(d)
                return
            end
            if CONFIG.CarpetPets and d:IsA("Model") then
                local pen = Workspace:FindFirstChild("RenderedMovingAnimals")
                if pen and d.Parent == pen and not Players:GetPlayerFromCharacter(d) then
                    hideBrainrot(d)
                    return
                end
            end
            if d:IsA("Model") and not Players:GetPlayerFromCharacter(d)
                and (d:FindFirstChildOfClass("Humanoid") or d:FindFirstChildOfClass("Animator")
                    or d:FindFirstChildOfClass("AnimationController")) then
                local a = d.Parent
                while a and a ~= Workspace do
                    if hiddenPlots[a] then unhidePlot(a) break end
                    a = a.Parent
                end
            end
        elseif CONFIG.WallsSigns and d:IsA("BasePart") then
            local s = d.Size
            if isWallShapedFast(s.X, s.Y, s.Z) and not inProtectedContainer(d) then
                hidePart(d)
            end
        elseif CONFIG.WallsSigns and (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) then
            local ok2, txt2 = pcall(function() return d.Text end)
            if ok2 and txt2 and txt2 ~= "" and not isKept(txt2) and containsAny(lower(txt2), SIGN_WORDS) then
                hideSignStructure(d)
            end
        end
        stripInstance(d)
    end)
end)
pcall(function()
    LocalPlayer:WaitForChild("PlayerGui", 5).ChildAdded:Connect(function(g)
        task.defer(function()
            if g.Name == GUI_NAME then return end
            if containsAny(lower(g.Name), activeKeywords()) and g:IsA("ScreenGui") then
                pcall(function() g.Enabled = false end)
            end
        end)
    end)
end)

pcall(function()
    hookHeldItems()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        hookHeldItems()
        if CONFIG.HeldItems then stripHeldItems() end
    end)
end)

-- ============================================================================
-- UI (top banner + mini button + settings window, starts hidden)
-- ============================================================================
local BG       = Color3.fromRGB(14, 17, 23)
local PANEL    = Color3.fromRGB(22, 27, 36)
local ROW_ON   = Color3.fromRGB(24, 122, 62)
local ROW_OFF  = Color3.fromRGB(122, 44, 44)
local ROW_IDLE = Color3.fromRGB(32, 39, 51)
local TXT      = Color3.fromRGB(235, 238, 245)
local DIM      = Color3.fromRGB(150, 158, 175)

local function round(inst, r)
    pcall(function()
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, r or 8)
        c.Parent = inst
    end)
end

local function buildGui()
    pcall(function()
        local old = LocalPlayer.PlayerGui:FindFirstChild(GUI_NAME)
        if old then old:Destroy() end
    end)
    pcall(function()
        local cg = game:GetService("CoreGui"):FindFirstChild(GUI_NAME)
        if cg then cg:Destroy() end
    end)

    local parent = nil
    pcall(function()
        if gethui then parent = gethui() end
    end)
    if not parent then
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        local canUse = false
        if ok and cg then
            pcall(function() cg:GetChildren() canUse = true end)
        end
        if canUse then parent = cg else parent = LocalPlayer:WaitForChild("PlayerGui") end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = false
    gui.Parent = parent

    bannerBox = Instance.new("Frame")
    bannerBox.Name = "Banner"
    bannerBox.Size = UDim2.fromOffset(460, 60)
    bannerBox.Position = UDim2.new(0.5, -230, 0, 12)
    bannerBox.BackgroundColor3 = Color3.fromRGB(12, 18, 14)
    bannerBox.BackgroundTransparency = 0.12
    bannerBox.BorderSizePixel = 0
    bannerBox.Visible = false
    bannerBox.Parent = gui
    pcall(function()
        round(bannerBox, 10)
        local s = Instance.new("UIStroke") s.Color = ACCENT s.Thickness = 2 s.Parent = bannerBox
    end)
    local bannerTitle = Instance.new("TextLabel")
    bannerTitle.Size = UDim2.new(1, 0, 0, 22)
    bannerTitle.Position = UDim2.new(0, 0, 0, 4)
    bannerTitle.BackgroundTransparency = 1
    bannerTitle.Text = "TEK OPTIMIZER"
    bannerTitle.Font = Enum.Font.GothamBlack
    bannerTitle.TextSize = 16
    bannerTitle.TextColor3 = Color3.fromRGB(110, 255, 150)
    bannerTitle.Parent = bannerBox
    bannerStats = Instance.new("TextLabel")
    bannerStats.Size = UDim2.new(1, -16, 0, 30)
    bannerStats.Position = UDim2.new(0, 8, 0, 26)
    bannerStats.BackgroundTransparency = 1
    bannerStats.Font = Enum.Font.Gotham
    bannerStats.TextSize = 12
    bannerStats.TextColor3 = TXT
    bannerStats.TextWrapped = true
    bannerStats.Text = ""
    bannerStats.Parent = bannerBox

    local mini = Instance.new("TextButton")
    mini.Name = "Mini"
    mini.Size = UDim2.fromOffset(56, 32)
    mini.Position = UDim2.new(1, -66, 0, 10)
    mini.BackgroundColor3 = Color3.fromRGB(90, 50, 220)
    mini.BorderSizePixel = 0
    mini.Text = "TEK"
    mini.Font = Enum.Font.GothamBlack
    mini.TextSize = 14
    mini.TextColor3 = Color3.fromRGB(255, 255, 255)
    mini.Parent = gui
    round(mini, 8)

    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.fromOffset(260, 420)
    main.Position = UDim2.new(1, -280, 0.5, -210)
    main.BackgroundColor3 = BG
    main.BorderSizePixel = 0
    main.Active = true
    main.Visible = false
    main.Parent = gui
    pcall(function()
        main.Draggable = true
        round(main, 10)
        local s = Instance.new("UIStroke") s.Color = ACCENT s.Thickness = 1 s.Transparency = 0.4 s.Parent = main
    end)

    mini.MouseButton1Click:Connect(function()
        main.Visible = not main.Visible
    end)

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -76, 0, 40)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "TEK OPTIMIZER"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 16
    title.TextColor3 = TXT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local ver = Instance.new("TextLabel")
    ver.Size = UDim2.fromOffset(40, 20)
    ver.Position = UDim2.new(0, 12, 0, 34)
    ver.BackgroundTransparency = 1
    ver.Text = "v4.3  •  STEAL A BRAINROT"
    ver.Font = Enum.Font.Gotham
    ver.TextSize = 11
    ver.TextColor3 = DIM
    ver.TextXAlignment = Enum.TextXAlignment.Left
    ver.Parent = main

    local dragging, dragStart, startPos = false, nil, nil
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, main.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.fromOffset(30, 28)
    minBtn.Position = UDim2.new(1, -66, 0, 8)
    minBtn.BackgroundColor3 = ROW_IDLE
    minBtn.BorderSizePixel = 0
    minBtn.Text = "-"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.TextColor3 = TXT
    minBtn.Parent = main
    round(minBtn, 6)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.fromOffset(30, 28)
    closeBtn.Position = UDim2.new(1, -34, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Parent = main
    round(closeBtn, 6)

    local content = Instance.new("ScrollingFrame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -64)
    content.Position = UDim2.new(0, 10, 0, 56)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.ScrollBarThickness = 3
    content.AutomaticCanvasSize = Enum.AutomaticSize.Y
    content.CanvasSize = UDim2.new(0, 0, 0, 0)
    content.ScrollingDirection = Enum.ScrollingDirection.Y
    content.Parent = main

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local function makeToggle(text, key, order)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.LayoutOrder = order
        b.BackgroundColor3 = CONFIG[key] and ROW_ON or ROW_OFF
        b.BorderSizePixel = 0
        b.Font = Enum.Font.GothamBold
        b.TextSize = 13
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.AutoButtonColor = true
        b.Parent = content
        round(b, 7)
        local function refresh()
            b.Text = (CONFIG[key] and "ON   •   " or "OFF   •   ") .. text
            b.BackgroundColor3 = CONFIG[key] and ROW_ON or ROW_OFF
        end
        b.MouseButton1Click:Connect(function()
            CONFIG[key] = not CONFIG[key]
            refresh()
        end)
        refresh()
        return b
    end

    makeToggle("Auto-run on load",  "AutoRun",    0)
    makeToggle("Buildings",          "Buildings",  1)
    makeToggle("Walls & signs",      "WallsSigns", 2)
    makeToggle("Textures & effects", "Textures",   3)
    makeToggle("Galaxy sky",         "GalaxySky",  4)
    makeToggle("Carpet brainrots",   "CarpetPets", 5)
    makeToggle("Empty bases",        "EmptyBases", 6)
    makeToggle("Hand & inventory",   "HeldItems",  7)

    local modeBtn = Instance.new("TextButton")
    modeBtn.Size = UDim2.new(1, 0, 0, 30)
    modeBtn.LayoutOrder = 8
    modeBtn.BackgroundColor3 = ROW_IDLE
    modeBtn.BorderSizePixel = 0
    modeBtn.Font = Enum.Font.GothamBold
    modeBtn.TextSize = 13
    modeBtn.TextColor3 = TXT
    modeBtn.Parent = content
    round(modeBtn, 7)
    local function refreshMode()
        modeBtn.Text = "Mode: " .. CONFIG.DeleteMode .. (CONFIG.DeleteMode == "Destroy" and "  (max FPS)" or "  (safe)")
    end
    modeBtn.MouseButton1Click:Connect(function()
        CONFIG.DeleteMode = (CONFIG.DeleteMode == "Destroy") and "Hide" or "Destroy"
        refreshMode()
    end)
    refreshMode()

    local runBtn = Instance.new("TextButton")
    runBtn.Size = UDim2.new(1, 0, 0, 42)
    runBtn.LayoutOrder = 9
    runBtn.BackgroundColor3 = Color3.fromRGB(24, 140, 70)
    runBtn.BorderSizePixel = 0
    runBtn.Font = Enum.Font.GothamBlack
    runBtn.TextSize = 17
    runBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    runBtn.Text = "OPTIMIZE"
    runBtn.Parent = content
    round(runBtn, 8)
    runBtn.MouseButton1Click:Connect(function()
        task.spawn(runOptimizer)
    end)

    local namesBtn = Instance.new("TextButton")
    namesBtn.Size = UDim2.new(1, 0, 0, 28)
    namesBtn.LayoutOrder = 10
    namesBtn.BackgroundColor3 = ROW_IDLE
    namesBtn.BorderSizePixel = 0
    namesBtn.Font = Enum.Font.Gotham
    namesBtn.TextSize = 12
    namesBtn.TextColor3 = DIM
    namesBtn.Text = "List map names (F9)"
    namesBtn.Parent = content
    round(namesBtn, 7)
    namesBtn.MouseButton1Click:Connect(function()
        task.spawn(listMapNames)
    end)

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, 0, 0, 32)
    statusLabel.LayoutOrder = 11
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextColor3 = Color3.fromRGB(140, 255, 170)
    statusLabel.TextWrapped = true
    statusLabel.Text = "Status: ready"
    statusLabel.Parent = content

    local collapsed = false
    minBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        content.Visible = not collapsed
        main.Size = collapsed and UDim2.fromOffset(260, 56) or UDim2.fromOffset(260, 420)
        minBtn.Text = collapsed and "+" or "-"
    end)
    closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
    end)

    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if gui and gui.Parent then
                main.Visible = not main.Visible
            end
        end
    end)

    return gui
end

buildGui()
log("TEK UI loaded (settings start hidden, mini button top right).")

-- Auto-run: instant first sweep, then background resweeps catch anything
-- that streamed in late (only when the game uses streaming).
if CONFIG.AutoRun then
    showBanner("TEK OPTIMIZER starting ...", 3)
    task.spawn(runOptimizer)
    if streamingOn then
        task.spawn(function()
            task.wait(6)
            if CONFIG.AutoRun then runOptimizer() end
            task.wait(12)
            if CONFIG.AutoRun then runOptimizer() end
        end)
    end
else
    showBanner("TEK OPTIMIZER ready (auto-run off, press TEK)", 6)
end
