local Path = "ReplicatedFirst.LocalScript"

for _, Thread in getreg() do
    if typeof(Thread) ~= "thread" then continue end
    local Source = debug.info(Thread, 1, "s")
    if Source and Source == Path then
        coroutine.close(Thread)
    end
end

local Hook = function() end
for _, Func in getgc(false) do
    if typeof(Func) ~= "function" then continue end
    local Source = debug.info(Func, "s")
    if Source and Source == Path then
        hookfunction(Func, Hook)
    end
end
