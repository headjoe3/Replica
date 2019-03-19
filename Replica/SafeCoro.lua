-- https://github.com/roblox-ts/roblox-ts/pull/249#issuecomment-464405155
-- This implements coroutine functions with continuation, so that things like module requiring do not break.

local Signal = require(script.Parent.Signal)

local YieldPayload = {}
local ResumeSignal = Signal.new()

local SafeCoro = {}

function SafeCoro.Running()
    return coroutine.running()
end

function SafeCoro.Resume(thread, ...)
    ResumeSignal:Fire(thread, {...})
    
    local returns = YieldPayload[thread]
    YieldPayload[thread] = nil
    
    if returns ~= nil then
        return unpack(returns)
    end
end

function SafeCoro.Yield(...)
    local thread = coroutine.running()
    YieldPayload[thread] = { ... }
    
    while true do
        local resumedThread, returns = ResumeSignal:Wait()
        if resumedThread == thread then
            return unpack(returns)
        end
    end
end

return SafeCoro