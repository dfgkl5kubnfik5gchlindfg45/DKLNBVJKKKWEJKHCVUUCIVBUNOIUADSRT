-- fenti AC bypass (host on GitHub raw; inject via external loader or _G.FENTI_FETCH_AC_MODULE_URL in hub).
-- Tuning: _G.FENTI_SAFE_AC, FENTI_STRICT_MODE, FENTI_ENABLE_MODULE8, FENTI_ENABLE_ADONIS_GC, FENTI_FORCE_ADONIS_GC,
-- FENTI_TREE_DESTROY_PASS, FENTI_NIL_DESTROY_PASS, FENTI_AGGRESSIVE_INSTANCE_SWEEP, FENTI_M8_PERIOD_SEC, etc.
-- _G.FENTI_AC_SILENT = true — skip the one success print() (reduces console noise / string exposure).

local function _fentiC(...)
    return string.char(...)
end
-- Runtime-built tokens (string.char) — keeps sensitive instance/class names out of naive string dumps.
local _FN = {
    strike = _fentiC(115, 116, 114, 105, 107, 101),
    Strike = _fentiC(83, 116, 114, 105, 107, 101),
    dunderFunc = _fentiC(95, 95, 70, 85, 78, 67, 84, 73, 79, 78),
    ClientMover = _fentiC(67, 108, 105, 101, 110, 116, 77, 111, 118, 101, 114),
    OnHitEvent = _fentiC(79, 110, 72, 105, 116, 69, 118, 101, 110, 116),
    RemoteEvent = _fentiC(82, 101, 109, 111, 116, 101, 69, 118, 101, 110, 116),
    RemoteFunction = _fentiC(82, 101, 109, 111, 116, 101, 70, 117, 110, 99, 116, 105, 111, 110),
    UnreliableRemoteEvent = _fentiC(85, 110, 114, 101, 108, 105, 97, 98, 108, 101, 82, 101, 109, 111, 116, 101, 69, 118, 101, 110, 116),
}

local function fentiStrikeNameMatch(n)
    return type(n) == "string" and string.lower(n) == _FN.strike
end

local function _fentiM8NameLooksACLI(name)
    if type(name) ~= "string" then return false end
    local n = string.lower(name)
    return string.find(n, "acli", 1, true) ~= nil or string.find(n, "adonis", 1, true) ~= nil
end

local fentiModule8RFConn = nil
local FENTI_MODULE8_FLAG = false

local function fentiModule8StripFolder(folder, tag)
    if not folder then return end
    pcall(function()
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("LocalScript") and _fentiM8NameLooksACLI(obj.Name) then
                pcall(function()
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
            if inst:IsA("LocalScript") and _fentiM8NameLooksACLI(inst.Name) then
                pcall(function()
                    inst.Disabled = true
                    inst:Destroy()
                end)
            end
        end)
    end)
end

local function fentiModule8Run(reason, quiet)
    if not FENTI_MODULE8_FLAG then return end
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
end

local API = {}

function API.earlyPass()
    local Executor = (type(identifyexecutor) == "function" and identifyexecutor()) or "Unknown"
    if Executor ~= "Solara" and Executor ~= "Xeno" then
        local function Hook_Adonis(meta_defs)
            if type(meta_defs) ~= "table" then return end
            for _, tbl in pairs(meta_defs) do
                if type(tbl) == "table" then
                    for _, func in pairs(tbl) do
                        if type(func) == "function" and islclosure and newcclosure and hookfunction and islclosure(func) then
                            local dummy_func = newcclosure(function()
                                return pcall(coroutine.close, coroutine.running())
                            end)
                            pcall(hookfunction, func, dummy_func)
                        end
                    end
                end
            end
        end
        pcall(function()
            if type(getgc) ~= "function" then return end
            for _, v in getgc(true) do
                if
                    typeof(v) == "table"
                    and rawget(v, "indexInstance")
                    and rawget(v, "newindexInstance")
                    and rawget(v, "namecallInstance")
                    and type(rawget(v, "newindexInstance")) == "table"
                then
                    local ni = rawget(v, "newindexInstance")
                    if ni[1] == "kick" then
                        Hook_Adonis(v)
                    end
                end
            end
        end)
    end
    pcall(function()
        for _, v in pairs(game:GetDescendants()) do
            if v.Name == _FN.dunderFunc or v.Name == _FN.ClientMover or (type(v.Name) == "string" and v.Name:lower():match("adonis")) or v.Name == _FN.Strike or v.Name == _FN.OnHitEvent then
                v:Destroy()
            end
        end
    end)
    pcall(function()
        if type(getnilinstances) ~= "function" then return end
        for _, v in pairs(getnilinstances()) do
            if v:IsA(_FN.RemoteEvent) or v:IsA(_FN.RemoteFunction) or (type(v.Name) == "string" and string.find(v.Name, _FN.ClientMover, 1, true)) or v.Name == _FN.dunderFunc then
                v:Destroy()
            end
        end
    end)
    if rawget(_G, "FENTI_AC_SILENT") ~= true then
        print(_fentiC(91, 102, 101, 110, 116, 105, 93, 32, 66, 121, 112, 97, 115, 115, 32, 45, 32, 115, 117, 99, 99, 101, 115, 115))
    end
end

function API.registerModule8(enabled)
    FENTI_MODULE8_FLAG = enabled == true
    _G.fentiModule8Run = fentiModule8Run
    if FENTI_MODULE8_FLAG then
        pcall(function() fentiModule8Run("before IsLoaded") end)
        local m8Period = tonumber(rawget(_G, "FENTI_M8_PERIOD_SEC"))
        if not m8Period or m8Period < 8 then m8Period = 22 end
        task.spawn(function()
            while FENTI_MODULE8_FLAG and task.wait(m8Period) do
                pcall(function() fentiModule8Run("periodic", true) end)
            end
        end)
    end
end

function API.destroyStrike()
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local function zap(inst, why)
            if not inst or not inst.Parent then return end
            local msg = "remove " .. why .. " :: " .. inst:GetFullName() .. " (" .. inst.ClassName .. ")"
            if type(_G.fentiACLog) == "function" then pcall(_G.fentiACLog, "STRIKE", msg) end
            inst:Destroy()
        end
        for _, d in ipairs(RS:GetDescendants()) do
            if fentiStrikeNameMatch(d.Name) then pcall(zap, d, "sweep") end
        end
        local strike = RS:FindFirstChild(_FN.Strike, true)
        if strike then pcall(zap, strike, "find") end
    end)
end

function API.stripACLIInFolder(folder)
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

function API.setupStrikeWatch(RS, UIS, m8Enabled)
    local strikeDelaysBundled = { 0.5, 1, 1.5, 2.5, 4, 6, 8, 12, 15, 22, 30, 45, 60, 90 }
    if rawget(_G, "FENTI_SAFE_AC") == true then return true end
    task.defer(function()
        API.destroyStrike()
        if m8Enabled and type(_G.fentiModule8Run) == "function" then pcall(function() _G.fentiModule8Run("defer") end) end
    end)
    for _, t in ipairs(strikeDelaysBundled) do
        task.delay(t, function()
            API.destroyStrike()
            if t == 8 and m8Enabled and type(_G.fentiModule8Run) == "function" then pcall(function() _G.fentiModule8Run("delay8+" .. _FN.Strike) end) end
        end)
    end
    pcall(function()
        RS.ChildAdded:Connect(function(inst)
            if fentiStrikeNameMatch(inst.Name) then
                if type(_G.fentiACLog) == "function" then pcall(_G.fentiACLog, "STRIKE", "ChildAdded " .. inst:GetFullName()) end
                pcall(function() inst:Destroy() end)
            end
        end)
    end)
    pcall(function()
        RS.DescendantAdded:Connect(function(inst)
            if fentiStrikeNameMatch(inst.Name) then
                if type(_G.fentiACLog) == "function" then pcall(_G.fentiACLog, "STRIKE", "DescendantAdded " .. inst:GetFullName()) end
                pcall(function() inst:Destroy() end)
            end
        end)
    end)
    pcall(function()
        UIS.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if input.KeyCode == Enum.KeyCode.Eight then
                if type(_G.fentiACLog) == "function" then pcall(_G.fentiACLog, "STRIKE", "key 8 manual sweep") end
                if m8Enabled and type(_G.fentiModule8Run) == "function" then pcall(function() _G.fentiModule8Run("key8") end) end
                API.destroyStrike()
            end
        end)
    end)
    return true
end

function API.lateInit(ctx)
    local banLog = ctx.banLog
    local failLogWrite = ctx.failLogWrite
    local _banLog = ctx._banLog
    local activeConnections = ctx.activeConnections
    local RS = ctx.RS
    local Players = ctx.Players
    local player = ctx.player
    local _fentiSkipACMonitoring = ctx._fentiSkipACMonitoring

    local function fentiAggressiveInstanceSweep(pass)
        if rawget(_G, "FENTI_AGGRESSIVE_INSTANCE_SWEEP") ~= true then return end
        local function nameHit(n)
            if type(n) ~= "string" then return false end
            if n == _FN.dunderFunc or n == _FN.ClientMover or n == _FN.Strike or n == _FN.OnHitEvent then return true end
            local l = string.lower(n)
            if string.find(l, "adonis", 1, true) then return true end
            return false
        end
        local function zapRoot(root, tag)
            if not root then return end
            pcall(function()
                for _, v in ipairs(root:GetDescendants()) do
                    if nameHit(v.Name) then
                        pcall(function()
                            local full = v:GetFullName()
                            v:Destroy()
                            banLog("AC-SWEEP", "[" .. tostring(pass) .. "][" .. tag .. "] " .. full)
                        end)
                    end
                end
            end)
        end
        zapRoot(RS, "RS")
        pcall(function() zapRoot(game:GetService("ReplicatedFirst"), "RF") end)
        pcall(function() zapRoot(game:GetService("StarterGui"), "SG") end)
        pcall(function()
            local ps = player:FindFirstChild("PlayerScripts")
            if ps then zapRoot(ps, "PS") end
        end)
        if rawget(_G, "FENTI_AGGRESSIVE_SWEEP_WORKSPACE") == true then
            pcall(function() zapRoot(workspace, "WS") end)
        end
        if rawget(_G, "FENTI_NIL_DESTROY_PASS") == true and type(getnilinstances) == "function" then
            pcall(function()
                for _, v in pairs(getnilinstances()) do
                    if v:IsA(_FN.RemoteEvent) or v:IsA(_FN.RemoteFunction) then
                        local n = v.Name
                        if type(n) == "string" and (string.find(n, _FN.ClientMover, 1, true) or n == _FN.dunderFunc) then
                            pcall(function()
                                v:Destroy()
                                banLog("AC-SWEEP", "[" .. tostring(pass) .. "][nil] " .. n)
                            end)
                        end
                    end
                end
            end)
        end
    end

    task.defer(function()
        pcall(function() fentiAggressiveInstanceSweep("defer") end)
    end)
    for _, st in ipairs({ 1.5, 4, 8, 15 }) do
        task.delay(st, function()
            pcall(function() fentiAggressiveInstanceSweep("t" .. st) end)
        end)
    end

    local _fentiSafeAc = rawget(_G, "FENTI_SAFE_AC") == true
    local _fentiStrictPlace = rawget(_G, "FENTI_STRICT_MODE") == true

    task.defer(function()
        pcall(function()
            if _fentiSafeAc or _fentiStrictPlace or rawget(_G, "FENTI_NO_WORKING_DESTROY_PASS") == true then return end
            local nTree, nNil = 0, 0
            local treePass = rawget(_G, "FENTI_TREE_DESTROY_PASS") == true
            local nilPass = rawget(_G, "FENTI_NIL_DESTROY_PASS") == true
            if not treePass and not nilPass then
                failLogWrite("[AC-FULL] tree/nil destroy skipped (set FENTI_TREE_DESTROY_PASS / FENTI_NIL_DESTROY_PASS)")
                banLog("AC-WORKING", "no full tree/nil destroy unless opted in")
                return
            end
            if treePass then
                for _, v in ipairs(game:GetDescendants()) do
                    local nm = v.Name
                    if type(nm) == "string" then
                        local l = string.lower(nm)
                        local hit = nm == _FN.dunderFunc or nm == _FN.ClientMover or nm == _FN.Strike or nm == _FN.OnHitEvent
                            or string.find(l, "adonis", 1, true) ~= nil
                        if hit then
                            pcall(function()
                                local full = v:GetFullName()
                                v:Destroy()
                                nTree = nTree + 1
                                banLog("DESTROY-1", full)
                                failLogWrite("[DESTROY-1] " .. full)
                            end)
                        end
                    end
                end
            end
            if nilPass and typeof(getnilinstances) == "function" then
                for _, v in pairs(getnilinstances()) do
                    if v:IsA(_FN.RemoteEvent) or v:IsA(_FN.RemoteFunction) then
                        local nm = v.Name
                        if type(nm) == "string" and (nm == _FN.dunderFunc or string.find(nm, _FN.ClientMover, 1, true)) then
                            pcall(function()
                                v:Destroy()
                                nNil = nNil + 1
                                banLog("DESTROY-2", nm .. " (" .. v.ClassName .. ")")
                                failLogWrite("[DESTROY-2] " .. nm)
                            end)
                        end
                    end
                end
            end
            failLogWrite("[AC-FULL] descendant destroy n=" .. tostring(nTree))
            banLog("AC-WORKING", "destroy tree=" .. tostring(nTree) .. " nil=" .. tostring(nNil))
        end)
    end)

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
        banLog("AC-INFO", "Found " .. #hits .. " ModuleScript(s) with obfuscated-style names")
        for i = 1, math.min(#hits, maxShow) do
            local h = hits[i]
            local short = #h.name > 28 and (h.name:sub(1, 28) .. "…") or h.name
            banLog("AC-INFO", "[" .. h.tag .. "] " .. short .. " → " .. h.path)
        end
    end)

    local execLower = "unknown"
    pcall(function()
        if type(identifyexecutor) == "function" then
            local ok, r = pcall(identifyexecutor)
            if ok and type(r) == "string" and r ~= "" then execLower = string.lower(r) end
        end
    end)
    local _fentiAdonisGcExecutorSkip = string.find(execLower, "solara", 1, true) ~= nil
        or string.find(execLower, "xeno", 1, true) ~= nil
    local _fentiAdonisGcBypass = rawget(_G, "FENTI_ENABLE_ADONIS_GC") == true
        and (rawget(_G, "FENTI_FORCE_ADONIS_GC") == true or not _fentiAdonisGcExecutorSkip)
        and rawget(_G, "FENTI_STRICT_MODE") ~= true
        and rawget(_G, "FENTI_SKIP_ADONIS_GC") ~= true
        and rawget(_G, "FENTI_DISABLE_ADONIS_GC") ~= true

    local _hookedAdonisDetectorFns = {}
    local _fentiAdonisFnSeq = 0
    local function _hookAdonisDetectorFn(fn)
        if _hookedAdonisDetectorFns[fn] then return false end
        if not hookfunction or not newcclosure then return false end
        _fentiAdonisFnSeq = _fentiAdonisFnSeq + 1
        local idx = _fentiAdonisFnSeq
        local ok, herr = pcall(function()
            local dummy = newcclosure(function()
                return pcall(coroutine.close, coroutine.running())
            end)
            hookfunction(fn, dummy)
            _hookedAdonisDetectorFns[fn] = true
        end)
        if ok then
            banLog("BYPASS", "Adonis deep fn#" .. tostring(idx))
            failLogWrite("[BYPASS] Adonis deep fn#" .. tostring(idx))
        else
            banLog("BYPASS", "Adonis hook FAIL fn#" .. tostring(idx) .. " :: " .. tostring(herr))
        end
        return ok
    end
    local function _fentiHookAdonisKickTable(meta_defs)
        if type(meta_defs) ~= "table" then return 0 end
        local passHooks = 0
        for _, tbl in pairs(meta_defs) do
            if type(tbl) == "table" then
                for _, func in pairs(tbl) do
                    if type(func) == "function" then
                        local allow = false
                        if typeof(islclosure) == "function" then
                            local oks, isL = pcall(islclosure, func)
                            allow = oks and isL == true
                        else
                            allow = true
                        end
                        if allow and _hookAdonisDetectorFn(func) then
                            passHooks = passHooks + 1
                        end
                    end
                end
            end
        end
        return passHooks
    end
    local function _bypassAdonisInstanceDetectors(passLabel)
        if not getgc or not hookfunction or not newcclosure then
            banLog("BYPASS", "Adonis GC bypass skipped (not available)")
            return
        end
        local ok, err = pcall(function()
            local gc = getgc(true)
            if not gc then
                banLog("BYPASS", "Adonis pass " .. passLabel .. " — getgc() nil")
                return
            end
            local gcLen = #gc
            local kickTables = 0
            local passHooks = 0
            for i = 1, math.min(gcLen, 55000) do
                local v = gc[i]
                if type(v) == "table" then
                    local ni = rawget(v, "newindexInstance")
                    if rawget(v, "indexInstance")
                        and ni ~= nil
                        and rawget(v, "namecallInstance")
                        and type(ni) == "table"
                        and ni[1] == "kick"
                    then
                        kickTables = kickTables + 1
                        local h = _fentiHookAdonisKickTable(v)
                        passHooks = passHooks + h
                        if h > 0 then
                            banLog("BYPASS", "Adonis kick-table deep hook hooks=" .. tostring(h))
                        end
                    end
                end
            end
            banLog("BYPASS", "Adonis pass " .. passLabel .. " | gc=" .. gcLen .. " kickTables=" .. kickTables .. " hooks=" .. passHooks)
            if passHooks > 0 then
                _banLog._bypassHookCount = (_banLog._bypassHookCount or 0) + passHooks
                _banLog._bypassDone = true
                if _banLog._onBypassApplied then pcall(_banLog._onBypassApplied) end
            end
        end)
        if not ok then
            banLog("BYPASS", "Adonis GC bypass error [" .. passLabel .. "]: " .. tostring(err))
        end
    end
    local _fentiAdonisSchedule = (function()
        local t = rawget(_G, "FENTI_ADONIS_GC_SCHEDULE")
        if type(t) == "table" and #t > 0 then return t end
        return { 5, 16, 40, 75 }
    end)()
    if not _fentiAdonisGcBypass then
        pcall(function()
            banLog("AC-INFO", "Adonis getgc bypass OFF (enable FENTI_ENABLE_ADONIS_GC=true)")
        end)
    else
        for _adi, _ads in ipairs(_fentiAdonisSchedule) do
            task.delay(_ads, function() pcall(function() _bypassAdonisInstanceDetectors("t" .. _ads .. "s#" .. _adi) end) end)
        end
    end

    if _fentiSkipACMonitoring then
        pcall(function() banLog("AC-INFO", "UUID remote + LogService monitors OFF (spoofcheck-sensitive)") end)
        return
    end
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
            if isFullUuidName(d.Name) and (d:IsA(_FN.RemoteEvent) or d:IsA(_FN.UnreliableRemoteEvent)) then
                wireHeartbeatRemote(d)
                nFound = nFound + 1
            end
        end
        RS.DescendantAdded:Connect(function(inst)
            if not isFullUuidName(inst.Name) then return end
            if inst:IsA(_FN.RemoteEvent) or inst:IsA(_FN.UnreliableRemoteEvent) then
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
            failLogWrite("[AC-RAW] (" .. tostring(messageType.Name) .. ") " .. message:sub(1, 500))
            local function looksLikeGameAC(msgLower)
                if msgLower:find("undetected", 1, true) then return false end
                if msgLower:find("kicked", 1, true) or msgLower:find("kick you", 1, true) then return true end
                if msgLower:find("banned", 1, true) then return true end
                if msgLower:find("detected", 1, true) or msgLower:find("detection", 1, true) then return true end
                if msgLower:find("exploit", 1, true) or msgLower:find("cheat", 1, true) then return true end
                if msgLower:find("violation", 1, true) or msgLower:find("flagged", 1, true) then return true end
                return false
            end
            if looksLikeGameAC(lower) then
                local now = tick()
                if now - lastAlertTime < 2 then
                    alertCount = alertCount + 1
                    if alertCount > 3 then return end
                else
                    alertCount = 0
                end
                lastAlertTime = now
                banLog("AC-ALERT", message:sub(1, 200))
            end
        end)
        table.insert(activeConnections, logConn)
    end)
end

return API
