

local function nameLooksACLI(name)
    if type(name) ~= "string" then return false end
    local n = string.lower(name)
    return string.find(n, "acli", 1, true) ~= nil or string.find(n, "adonis", 1, true) ~= nil
end

local function registerModule8(FENTI_MODULE8_ENABLED)
    if not FENTI_MODULE8_ENABLED then return end
    local fentiModule8RFConn = nil
    local function fentiModule8StripFolder(folder, tag)
        if not folder then return end
        pcall(function()
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("LocalScript") and nameLooksACLI(obj.Name) then
                    pcall(function()
                        obj.Disabled = true
                        obj:Destroy()
                        print("[fenti M8] " .. tostring(tag) .. " removed: " .. tostring(obj.Name))
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
                        inst.Disabled = true
                        inst:Destroy()
                        print("[fenti M8] ReplicatedFirst late remove: " .. tostring(inst.Name))
                    end)
                end
            end)
        end)
    end
    local function fentiModule8Run(reason, quiet)
        if not FENTI_MODULE8_ENABLED then return end
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
            print("[fenti M8] ACLI strip OK (" .. tostring(reason or "?") .. ")")
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

local function destroyStrike()
    pcall(function()
        local strike = game:GetService("ReplicatedStorage"):FindFirstChild("Strike", true)
        if strike then strike:Destroy() end
    end)
end

local function setupStrikeWatch(RS, UIS, FENTI_MODULE8_ENABLED)
    if not RS or not UIS then return false end
    task.defer(function()
        destroyStrike()
        if FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("defer") end) end
    end)
    task.delay(8, function()
        destroyStrike()
        if FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("delay8+Strike") end) end
    end)
    pcall(function()
        RS.DescendantAdded:Connect(function(inst)
            if inst.Name == "Strike" then pcall(function() inst:Destroy() end) end
        end)
    end)
    pcall(function()
        UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Eight then
                if FENTI_MODULE8_ENABLED then pcall(function() _G.fentiModule8Run("key8") end) end
                destroyStrike()
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
    local _isWave = ctx._isWave
    local _fentiSkipACMonitoring = ctx._fentiSkipACMonitoring
    if not banLog or not RS or not Players or not player then return end

    if not _isWave then
        pcall(function()
            local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
            if ps then
                for _, s in ipairs(ps:GetDescendants()) do
                    if s:IsA("LocalScript") or s:IsA("ModuleScript") then
                        local name = s.Name:lower()
                        if name:find("acli") or name:find("adonis") or name:find("anticheat") or name:find("anti_cheat") then
                            banLog("AC-DETECT", "Found AC script: " .. s:GetFullName())
                        end
                    end
                end
            end
        end)
    else
        banLog("AC-DETECT", "Skipped PlayerScripts scan on this executor")
    end

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
            return
        end
        banLog("AC-INFO", "Found " .. #hits .. " ModuleScript(s) with underscore/long obfuscated names (may include TP / movers)")
        for i = 1, math.min(#hits, maxShow) do
            local h = hits[i]
            local short = #h.name > 28 and (h.name:sub(1, 28) .. "…") or h.name
            banLog("AC-INFO", "[" .. h.tag .. "] " .. short .. " → " .. h.path)
        end
        if #hits > maxShow then
            banLog("AC-INFO", "… +" .. (#hits - maxShow) .. " more not listed (see Studio Explorer)")
        end
    end)

    local _hookedAdonisDetectorFns = {}
    local function _hookAdonisDetectorFn(fn)
        if _hookedAdonisDetectorFns[fn] then return false end
        if not hookfunction or not newcclosure then return false end
        local ok = pcall(function()
            hookfunction(fn, newcclosure(function() return false end))
            _hookedAdonisDetectorFns[fn] = true
        end)
        return ok
    end

    local function _bypassAdonisInstanceDetectors()
        if _isWave then
            banLog("BYPASS", "Adonis GC bypass skipped on this executor")
            return
        end
        if not getgc or not hookfunction or not newcclosure then
            banLog("BYPASS", "Adonis GC bypass skipped (not available)")
            return
        end
        local ok, err = pcall(function()
            local gc = getgc(true)
            if not gc then return end
            local passHooks = 0
            for i = 1, math.min(#gc, 50000) do
                local v = gc[i]
                if type(v) == "table" then
                    local s, hasIdx = pcall(rawget, v, "indexInstance")
                    if s and hasIdx then
                        for _, a in pairs(v) do
                            if type(a) == "table" and type(a[2]) == "function" then
                                if _hookAdonisDetectorFn(a[2]) then
                                    passHooks = passHooks + 1
                                end
                            end
                        end
                    end
                end
            end
            if passHooks > 0 then
                _banLog._bypassHookCount = (_banLog._bypassHookCount or 0) + passHooks
                _banLog._bypassDone = true
                banLog("BYPASS", "Adonis detectors: +" .. passHooks .. " hook(s) (total " .. _banLog._bypassHookCount .. ") — silent aim namecall allowed")
                if _banLog._onBypassApplied then
                    pcall(_banLog._onBypassApplied)
                end
            end
        end)
        if not ok then banLog("BYPASS", "Adonis GC bypass error: " .. tostring(err)) end
    end
    task.delay(3, function() pcall(_bypassAdonisInstanceDetectors) end)
    task.delay(6, function() pcall(_bypassAdonisInstanceDetectors) end)
    task.delay(10, function() pcall(_bypassAdonisInstanceDetectors) end)
    task.delay(18, function() pcall(_bypassAdonisInstanceDetectors) end)

    if _fentiSkipACMonitoring then
        pcall(function() banLog("AC-INFO", "UUID remote + LogService monitors OFF (avoids remote/LogService spoofcheck on Volt & similar)") end)
    else
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
                        for i, v in ipairs(args) do argSummary[i] = typeof(v) .. ":" .. tostring(v):sub(1, 40) end
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
                end
            end)
            table.insert(activeConnections, logConn)
        end)
    end
end

return {
    registerModule8 = registerModule8,
    destroyStrike = destroyStrike,
    setupStrikeWatch = setupStrikeWatch,
    stripACLIInFolder = stripACLIInFolder,
    lateInit = lateInit,
}
