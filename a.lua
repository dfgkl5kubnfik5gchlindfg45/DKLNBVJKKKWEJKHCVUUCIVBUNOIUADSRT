local BypassEnabled = true 
local AnticheatData = { Disabled = false, Name = "N/A" }

local function Notify(title, text)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 5
        })
    end)
end

local Adonis = {
    Name = "Adonis",
    Threads = {}
}

function Adonis.Detect()
    if not getreg or not getgc or not debug.info then return false end
    local found = false
    for _, thread in getreg() do
        if typeof(thread) == "thread" and coroutine.status(thread) ~= "dead" then
            local success, source = pcall(function() return debug.info(thread, 1, "s") end)
            if success and source and (source:find(".Core.Anti") or source:find(".Plugins.Anti_Cheat")) then
                table.insert(Adonis.Threads, thread)
                found = true
            end
        end
    end
    return found
end

function Adonis.Bypass()
    for _, thread in Adonis.Threads do pcall(task.cancel, thread) end
    local hookedCount = 0
    for _, obj in getgc(true) do
        if typeof(obj) == "table" then
            if typeof(rawget(obj, "Detected")) == "function" and rawget(obj, "RLocked") ~= nil then
                for _, func in pairs(obj) do
                    if typeof(func) == "function" then
                        local success = pcall(function()
                            hookfunction(func, function(...) return task.wait(9e9) end)
                        end)
                        if success then hookedCount = hookedCount + 1 end
                    end
                end
            end
        end
    end
    for _, thread in Adonis.Threads do
        if coroutine.status(thread) ~= "dead" then return false end
    end
    return hookedCount > 0
end

if BypassEnabled then
    if Adonis.Detect() then
        Notify("nigerian mud hut employee", "Adonis anti-cheat detected sending idf to disable")
        
        task.wait(1) 
        
        if Adonis.Bypass() then
            AnticheatData.Name = Adonis.Name
            AnticheatData.Disabled = true
            Notify("hooked nigga remote disabling now")
        else
            game.Players.LocalPlayer:Kick("\n[FENTI]\nFailed to bypass.\n game closed to prevent ban.")
            return
        end
    end
end
