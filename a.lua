-- fenti external AC bundle — host as raw .lua; set FENTI_AC_MODULE_URL / _G.FENTI_AC_MODULE_URL in main.
-- _G.FENTI_STRICT_MODE=true before load: skip Adonis getgc/hookfunction passes (hub pairs with this).
--
-- THIS BUILD IS "FULL" BY DEFAULT (your snippet, cleaned up):
--   • game:GetDescendants() — destroy __FUNCTION, ClientMover, *adonis* (name), Strike, OnHitEvent
--   • getnilinstances() — destroy EVERY nil-parent RemoteEvent/RemoteFunction OR name ClientMover/__FUNCTION
--   • getgc(true) — Adonis marker tables where newindexInstance[1]=="kick" → deep hook all L-closures
--     (coroutine.close dummy). No narrow "return false" detector-only path.
-- Logging: print + _G.fentiACLog(cat, msg) once main assigns it.
--
-- API: registerModule8, destroyStrike, setupStrikeWatch, stripACLIInFolder, lateInit,
--      fullDescendantDestroy, fullNilDestroy (manual re-sweep)

local function acLog(cat, msg)
    msg = tostring(msg or ""):sub(1, 420)
    print("[fenti-ac] [" .. tostring(cat) .. "] " .. msg)
    local fn = rawget(_G, "fentiACLog")
    if type(fn) == "function" then
        pcall(fn, cat, msg)
    end
end

local function nameLooksACLI(name)
    if type(name) ~= "string" then return false end
    local n = string.lower(name)
    return string.find(n, "acli", 1, true) ~= nil or string.find(n, "adonis", 1, true) ~= nil
end

local function nameIsStrike(n)
    return type(n) == "string" and string.lower(n) == "strike"
end

--- Exact name rules from your descendant loop (adonis via lower():match("adonis")).
local function nameMatchesFullDestroy(inst)
    if not inst or type(inst.Name) ~= "string" then return false end
    local n = inst.Name
    if n == "__FUNCTION" or n == "ClientMover" or n == "Strike" or n == "OnHitEvent" then return true end
    local l = string.lower(n)
    if string.find(l, "adonis", 1, true) then return true end
    return false
end

--- Always runs — full game tree sweep.
local function fentiAcFullDescendantDestroy(banLog, failLogWrite)
    local removed = 0
    pcall(function()
        for _, v in pairs(game:GetDescendants()) do
            if nameMatchesFullDestroy(v) then
                pcall(function()
                    local full = v:GetFullName()
                    v:Destroy()
                    removed = removed + 1
                    acLog("DESTROY-1", full)
                    print("[fenti-ac] Destroyed anticheat 1 " .. full)
                    if failLogWrite then failLogWrite("[DESTROY-1] " .. full) end
                end)
            end
        end
    end)
    if banLog and removed > 0 then banLog("AC-FULL", "descendant destroy n=" .. tostring(removed)) end
    return removed
end

--- Always runs — matches your nil loop: ANY nil RemoteEvent/RemoteFunction OR those names.
local function fentiAcFullNilDestroy(banLog, failLogWrite)
    if type(getnilinstances) ~= "function" then return 0 end
    local removed = 0
    pcall(function()
        for _, v in pairs(getnilinstances()) do
            pcall(function()
                local n = v.Name
                local ns = type(n) == "string" and n or ""
                local hit = v:IsA("RemoteEvent")
                    or v:IsA("RemoteFunction")
                    or (ns ~= "" and ns:match("ClientMover") ~= nil)
                    or n == "__FUNCTION"
                if hit then
                    v:Destroy()
                    removed = removed + 1
                    acLog("DESTROY-2", tostring(n) .. " (" .. v.ClassName .. ")")
                    print("[fenti-ac] Destroyed anticheat 2 " .. tostring(n))
                    if failLogWrite then failLogWrite("[DESTROY-2] " .. tostring(n)) end
                end
            end)
        end
    end)
    if banLog and removed > 0 then banLog("AC-FULL", "nil destroy n=" .. tostring(removed)) end
    return removed
end

local function functionIsLClosure(fn)
    if type(fn) ~= "function" then return false end
    if type(islclosure) == "function" then
        local ok, isL = pcall(islclosure, fn)
        if ok then return isL == true end
    end
    return true
end

--- Deep hook every L-closure reachable from Adonis kick table (full graph).
local function hookAdonisKickTableDeep(metaTable, hookedFn, banLog, failLogWrite)
    if type(metaTable) ~= "table" or not hookfunction or not newcclosure then return 0 end
    local count = 0
    local seenT = {}
    local seenF = hookedFn
    local queue = { metaTable }
    while #queue > 0 do
        local t = table.remove(queue)
        if type(t) == "table" and not seenT[t] then
            seenT[t] = true
            for _, val in pairs(t) do
                local vt = type(val)
                if vt == "function" then
                    if not seenF[val] and functionIsLClosure(val) then
                        local ok = pcall(function()
                            hookfunction(val, newcclosure(function()
                                pcall(coroutine.close, coroutine.running())
                            end))
                        end)
                        if ok then
                            seenF[val] = true
                            count = count + 1
                            if failLogWrite then failLogWrite("[BYPASS] Adonis deep fn#" .. tostring(count)) end
                        elseif banLog then
                            banLog("BYPASS", "Adonis deep hook FAIL")
                        end
                    end
                elseif vt == "table" and not seenT[val] then
                    table.insert(queue, val)
                end
            end
        end
    end
    return count
end

local function destroyStrike()
    local RS = game:GetService("ReplicatedStorage")
    local removed = 0
    local function tryDestroy(inst, reason)
        if not inst or not inst.Parent then return end
        pcall(function()
            acLog("STRIKE", "remove " .. reason .. " :: " .. inst:GetFullName() .. " (" .. inst.ClassName .. ")")
            inst:Destroy()
            removed = removed + 1
        end)
    end
    pcall(function()
        for _, d in ipairs(RS:GetDescendants()) do
            if nameIsStrike(d.Name) then tryDestroy(d, "sweep") end
        end
        local s = RS:FindFirstChild("Strike", true)
        if s then tryDestroy(s, "find") end
    end)
    return removed
end

local function registerModule8(FENTI_MODULE8_ENABLED)
    if not FENTI_MODULE8_ENABLED then
        _G.fentiModule8Run = function() end
        return
    end
    local fentiModule8RFConn = nil
    local function fentiModule8StripFolder(folder, tag)
        if not folder then return end
        pcall(function()
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("LocalScript") and nameLooksACLI(obj.Name) then
                    pcall(function()
                        acLog("M8", "strip [" .. tostring(tag) .. "] " .. obj:GetFullName())
                        obj.Disabled = true
                        obj:Destroy()
                    end)
                end
            end
        end)
    end
    local function fentiModule8WatchReplicatedFirst()
        pcall(function()
            local rf = game:GetService("ReplicatedFirst")
            if fentiModule8RFConn then return end
            fentiModule8RFConn = rf.DescendantAdded:Connect(function(inst)
                if inst:IsA("LocalScript") and nameLooksACLI(inst.Name) then
                    pcall(function()
                        acLog("M8", "late RF remove " .. inst:GetFullName())
                        inst.Disabled = true
                        inst:Destroy()
                    end)
                end
            end)
        end)
    end
    local function fentiModule8Run(reason, quiet)
        if not FENTI_MODULE8_ENABLED then return end
        acLog("M8", "run start (" .. tostring(reason or "?") .. ")")
        pcall(function()
            fentiModule8StripFolder(game:GetService("ReplicatedFirst"), "ReplicatedFirst")
            fentiModule8StripFolder(game:GetService("StarterGui"), "StarterGui")
            local plr = game:GetService("Players").LocalPlayer
            if plr then
                local ps = plr:FindFirstChild("PlayerScripts")
                if ps then fentiModule8StripFolder(ps, "PlayerScripts") end
            end
            fentiModule8WatchReplicatedFirst()
        end)
        if not quiet then
            acLog("M8", "strip OK (" .. tostring(reason or "?") .. ")")
        end
    end
    _G.fentiModule8Run = fentiModule8Run
    pcall(function() fentiModule8Run("before IsLoaded") end)
    task.spawn(function()
        while FENTI_MODULE8_ENABLED and task.wait(5) do
            pcall(function() fentiModule8Run("periodic", true) end)
        end
    end)
end

local function setupStrikeWatch(RS, UIS, FENTI_MODULE8_ENABLED)
    if not RS or not UIS then return false end
    acLog("STRIKE", "setupStrikeWatch — RS + key8 + delayed sweeps")

    local function sweep()
        local n = destroyStrike()
        if n > 0 then acLog("STRIKE", "sweep removed " .. tostring(n)) end
    end

    task.defer(function()
        sweep()
        if FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("defer") end) end
    end)

    local strikeDelays = { 0.5, 1, 1.5, 2.5, 4, 6, 8, 12, 15, 22, 30, 45, 60, 90 }
    for _, t in ipairs(strikeDelays) do
        task.delay(t, function()
            sweep()
            if t == 8 and FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("delay8+Strike") end) end
        end)
    end

    pcall(function()
        RS.ChildAdded:Connect(function(inst)
            if nameIsStrike(inst.Name) then
                acLog("STRIKE", "ChildAdded hit → " .. inst:GetFullName())
                pcall(function() inst:Destroy() end)
            end
        end)
    end)
    pcall(function()
        RS.DescendantAdded:Connect(function(inst)
            if nameIsStrike(inst.Name) then
                acLog("STRIKE", "DescendantAdded hit → " .. inst:GetFullName())
                pcall(function() inst:Destroy() end)
            end
        end)
    end)

    pcall(function()
        UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Eight then
                acLog("STRIKE", "key 8 manual sweep")
                if FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("key8") end) end
                sweep()
            end
        end)
    end)

    return true
end

local function stripACLIInFolder(folder)
    if not folder then return end
    pcall(function()
        for _, d in ipairs(folder:GetDescendants()) do
            if d:IsA("LocalScript") then
                local ln = string.lower(d.Name)
                if string.find(ln, "acli", 1, true) or string.find(ln, "adonis", 1, true) then
                    pcall(function()
                        acLog("ACLI", "folder strip " .. d:GetFullName())
                        d.Disabled = true
                        d:Destroy()
                    end)
                end
            end
        end
    end)
end

local function lateInit(ctx)
    local banLog = ctx.banLog
    local failLogWrite = ctx.failLogWrite
    local _banLog = ctx._banLog
    local activeConnections = ctx.activeConnections
    local RS = ctx.RS
    local Players = ctx.Players
    local player = ctx.player
    local _fentiSkipACMonitoring = ctx._fentiSkipACMonitoring
    local acLogVerbose = ctx.acLogVerbose == true

    if not banLog or not RS or not Players or not player then
        acLog("AC-ERR", "lateInit missing ctx fields (banLog/RS/Players/player)")
        return
    end

    acLog("AC-INIT", "lateInit FULL destroy + Adonis deep | skipMon=" .. tostring(_fentiSkipACMonitoring))

    local function runFullSweeps()
        pcall(function() fentiAcFullDescendantDestroy(banLog, failLogWrite) end)
        pcall(function() fentiAcFullNilDestroy(banLog, failLogWrite) end)
    end

    task.defer(runFullSweeps)
    for _, td in ipairs({ 0.35, 0.8, 1.5, 2.5, 4, 6, 8, 12, 18, 25, 40, 60 }) do
        task.delay(td, runFullSweeps)
    end

    pcall(function()
        local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then
            local n = 0
            for _, s in ipairs(ps:GetDescendants()) do
                if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                    local name = s.Name:lower()
                    if name:find("acli") or name:find("adonis") or name:find("anticheat") or name:find("anti_cheat") then
                        banLog("AC-DETECT", "Found AC script: " .. s:GetFullName())
                        failLogWrite("[AC-DETECT] " .. s:GetFullName())
                        n = n + 1
                    end
                end
            end
            acLog("AC-SCAN", "PlayerScripts AC-like count=" .. tostring(n))
        end
    end)

    pcall(function()
        local remFolder = RS:FindFirstChild("Remotes")
        if remFolder then
            local suspicious = {}
            for _, r in ipairs(remFolder:GetChildren()) do
                if r.Name:match("^%x%x%x%x%x%x%x%x%-") then
                    table.insert(suspicious, r.Name:sub(1, 8) .. "... (" .. r.ClassName .. ")")
                end
            end
            if #suspicious > 0 then
                banLog("AC-INFO", "UUID remotes: " .. table.concat(suspicious, ", "))
                failLogWrite("[AC-INFO] UUID remotes n=" .. #suspicious)
            end
        end
    end)
    pcall(function()
        for _, ch in ipairs(RS:GetChildren()) do
            local n = ch.Name
            if type(n) == "string" and #n == 36 and n:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x$") then
                banLog("AC-INFO", "ReplicatedStorage UUID: " .. n:sub(1, 8) .. "... (" .. ch.ClassName .. ")")
            end
        end
    end)

    pcall(function()
        local function looksLikeObfuscatedModuleName(n)
            if type(n) ~= "string" or #n < 10 then return false end
            local _, u = n:gsub("_", "_")
            if u >= 6 then return true end
            if #n >= 40 and u >= 3 and n:match("^[%w_]+$") then return true end
            if #n >= 56 and n:match("^[%w_]+$") then return true end
            return false
        end
        local maxShow = 20
        local hits = {}
        local function collect(root, tag)
            if not root then return end
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("ModuleScript") and looksLikeObfuscatedModuleName(d.Name) then
                    table.insert(hits, { tag = tag, name = d.Name, path = d:GetFullName() })
                end
            end
        end
        collect(RS, "RS")
        pcall(function() collect(game:GetService("ReplicatedFirst"), "ReplicatedFirst") end)
        if #hits == 0 then
            banLog("AC-INFO", "No obfuscated-name ModuleScripts found under RS / ReplicatedFirst")
        else
            banLog("AC-INFO", "Found " .. #hits .. " ModuleScript(s) with underscore/long obfuscated names (may include TP / movers)")
            failLogWrite("[AC-INFO] obfuscated modules n=" .. #hits)
            for i = 1, math.min(#hits, maxShow) do
                local h = hits[i]
                local short = #h.name > 28 and (h.name:sub(1, 28) .. "…") or h.name
                banLog("AC-INFO", "[" .. h.tag .. "] " .. short .. " → " .. h.path)
            end
            if #hits > maxShow then
                banLog("AC-INFO", "… +" .. (#hits - maxShow) .. " more not listed (see Studio Explorer)")
            end
        end
    end)

    local hookedAdonisFns = {}

    local function bypassAdonisFull(passLabel)
        if not getgc or not hookfunction or not newcclosure then
            banLog("BYPASS", "Adonis getgc bypass skipped (not available)")
            return
        end
        local ok, err = pcall(function()
            local gc = getgc(true)
            if not gc then
                banLog("BYPASS", "Adonis pass " .. passLabel .. " — getgc() nil")
                return
            end
            local gcLen = #gc
            local tablesMatched = 0
            local passHooks = 0
            for i = 1, math.min(gcLen, 55000) do
                local v = gc[i]
                if type(v) == "table" then
                    local ni = rawget(v, "newindexInstance")
                    if rawget(v, "indexInstance")
                        and ni
                        and rawget(v, "namecallInstance")
                        and type(ni) == "table"
                        and ni[1] == "kick" then
                        tablesMatched = tablesMatched + 1
                        local n = hookAdonisKickTableDeep(v, hookedAdonisFns, banLog, failLogWrite)
                        passHooks = passHooks + n
                        acLog("BYPASS", "Adonis kick-table deep hook hooks=" .. tostring(n))
                        print("[fenti-ac] bypassed ac (deep) pass " .. passLabel)
                    end
                end
            end
            banLog("BYPASS", "Adonis pass " .. passLabel .. " | gc=" .. gcLen .. " kickTables=" .. tablesMatched .. " hooks=" .. passHooks)
            failLogWrite(string.format("[BYPASS] %s gc=%d kickTables=%d hooks=%d", passLabel, gcLen, tablesMatched, passHooks))
            if passHooks > 0 then
                _banLog._bypassHookCount = (_banLog._bypassHookCount or 0) + passHooks
                _banLog._bypassDone = true
                banLog("BYPASS", "Adonis total hooks=" .. _banLog._bypassHookCount)
                if _banLog._onBypassApplied then
                    pcall(_banLog._onBypassApplied)
                end
            end
        end)
        if not ok then
            banLog("BYPASS", "Adonis GC bypass error [" .. passLabel .. "]: " .. tostring(err))
            failLogWrite("[BYPASS] error " .. passLabel .. " " .. tostring(err))
        end
    end

    local adonisSchedule = { 2, 4, 7, 12, 18, 25, 35, 50, 70, 95 }
    if rawget(_G, "FENTI_SKIP_ADONIS_GC") == true or rawget(_G, "FENTI_STRICT_MODE") == true then
        pcall(function()
            banLog("AC-INFO", "Adonis getgc bypass OFF (" .. (rawget(_G, "FENTI_STRICT_MODE") == true and "FENTI_STRICT_MODE" or "FENTI_SKIP_ADONIS_GC") .. ")")
        end)
    else
        for i, sec in ipairs(adonisSchedule) do
            task.delay(sec, function() pcall(function() bypassAdonisFull("t" .. sec .. "s#" .. i) end) end)
        end
    end

    if _fentiSkipACMonitoring then
        pcall(function() banLog("AC-INFO", "UUID remote + LogService monitors OFF (spoofcheck-sensitive runtime)") end)
    else
        do
        pcall(function()
            local function isFullUuidName(n)
                return type(n) == "string" and #n == 36 and n:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x$")
            end
            local wired = {}
            local function wireHeartbeatRemote(r)
                if wired[r] then return end
                wired[r] = true
                banLog("AC-INFO", "Heartbeat watch: " .. r.ClassName .. " " .. r.Name:sub(1, 8) .. "... @ " .. r:GetFullName())
                local fireCount = 0
                r.OnClientEvent:Connect(function(...)
                    fireCount = fireCount + 1
                    if fireCount <= 5 or fireCount % 10 == 0 then
                        local args = { ... }
                        local argSummary = {}
                        for j, val in ipairs(args) do argSummary[j] = typeof(val) .. ":" .. tostring(val):sub(1, 40) end
                        banLog("AC-HEARTBEAT", r.Name:sub(1, 8) .. "... #" .. fireCount .. " " .. table.concat(argSummary, ", "))
                    end
                end)
            end
            local nFound = 0
            for _, d in ipairs(RS:GetDescendants()) do
                if isFullUuidName(d.Name) and (d:IsA("RemoteEvent") or d:IsA("UnreliableRemoteEvent")) then
                    wireHeartbeatRemote(d)
                    nFound = nFound + 1
                end
            end
            if nFound == 0 then
                banLog("AC-INFO", "No UUID RemoteEvents in ReplicatedStorage yet (will attach if one appears)")
            else
                banLog("AC-INFO", "Attached to " .. nFound .. " UUID remote(s); new ones under RS are auto-watched")
            end
            RS.DescendantAdded:Connect(function(inst)
                if not isFullUuidName(inst.Name) then return end
                if inst:IsA("RemoteEvent") or inst:IsA("UnreliableRemoteEvent") then
                    wireHeartbeatRemote(inst)
                end
            end)
        end)

        pcall(function()
            local lastAlertTime, alertCount = 0, 0
            local logConn
            logConn = game:GetService("LogService").MessageOut:Connect(function(message, messageType)
                if messageType ~= Enum.MessageType.MessageError and messageType ~= Enum.MessageType.MessageWarning then return end
                local lower = message:lower()
                if lower:find("fenti-log", 1, true) or lower:find("[fenti", 1, true) then return end
                if messageType == Enum.MessageType.MessageError then
                    failLogWrite("[SCRIPT_ERROR] " .. message:sub(1, 600))
                end
                if acLogVerbose then
                    failLogWrite("[AC-RAW] (" .. tostring(messageType.Name) .. ") " .. message:sub(1, 500))
                end
                local function looksLikeGameAC(msgLower)
                    if msgLower:find("undetected", 1, true) then return false end
                    if msgLower:find("kicked", 1, true) or msgLower:find("kick you", 1, true) or msgLower:find("being kicked", 1, true) or msgLower:find("removed for", 1, true) then return true end
                    if msgLower:find("banned", 1, true) or msgLower:find("ban hammer", 1, true) then return true end
                    if msgLower:find("detected", 1, true) or msgLower:find("detection", 1, true) then return true end
                    if msgLower:find("exploit", 1, true) or msgLower:find("exploiting", 1, true) then return true end
                    if msgLower:find("cheating", 1, true) or msgLower:find("cheater", 1, true) then return true end
                    if msgLower:find(" cheat", 1, true) or msgLower:find("cheat ", 1, true) then return true end
                    if msgLower:find("violation", 1, true) or msgLower:find("flagged", 1, true) then return true end
                    if msgLower:find("fairplay", 1, true) or msgLower:find("moderation", 1, true) then return true end
                    return false
                end
                if looksLikeGameAC(lower) then
                    local now = tick()
                    if now - lastAlertTime < 2 then
                        alertCount = alertCount + 1
                        if alertCount > 3 then return end
                    else
                        if alertCount > 3 then
                            table.insert(_banLog, "[" .. os.date("%H:%M:%S") .. "] [AC-ALERT] (suppressed " .. (alertCount - 3) .. " repeated alerts)")
                        end
                        alertCount = 0
                    end
                    lastAlertTime = now
                    banLog("AC-ALERT", message:sub(1, 200))
                    failLogWrite("[AC-ALERT] " .. message:sub(1, 400))
                end
            end)
            table.insert(activeConnections, logConn)
        end)
        end
    end

    acLog("AC-INIT", "lateInit done")
end

return {
    registerModule8 = registerModule8,
    destroyStrike = destroyStrike,
    setupStrikeWatch = setupStrikeWatch,
    stripACLIInFolder = stripACLIInFolder,
    lateInit = lateInit,
    fullDescendantDestroy = fentiAcFullDescendantDestroy,
    fullNilDestroy = fentiAcFullNilDestroy,
    -- backwards names for older hub refs
    aggressiveDestroy = fentiAcFullDescendantDestroy,
    nilRemoteSweep = fentiAcFullNilDestroy,
}
