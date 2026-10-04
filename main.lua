local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local VindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Skinny-yz/VVind-UI/refs/heads/main/src.lua"
))()
VindUI:PreloadIcons({ "Lucide", "Material" })

local Window = VindUI:CreateWindow({
    Title ="Ruleless Enchantment RSPY",
    Subtitle = "RE-RSPY  •  " .. (IS_MOBILE and "Mobile" or "PC"),
    Icon = "Lucide:radio",
    Size = IS_MOBILE and UDim2.fromOffset(420, 620) or UDim2.fromOffset(860, 660),
    MinSize = Vector2.new(340, 460),
    Draggable = true,
    Resizable = true,
    UseBlur = true,
    DefaultTab = "Remote Spy",
    ToggleKeybind = Enum.KeyCode.RightShift,
})

VindUI:Notify({
    Title = "Ruleless Enchantment RSPY",
    Text = "Loaded — toggle Enable Spy to start",
    Type = "info",
    Duration = 3,
})

local SpyTab = Window:AddTab({ Name = "Remote Spy", Icon = "Lucide:radio" })

local logs = {}
local selected = nil
local selectedIndex = 0
local blacklist = {}
local blocklist = {}
local prevTables = {}
local scheduled = {}
local toggle = false
local getnilrequired = false
local indent = 4
local topstr = ""
local bottomstr = ""
local spyRunning = false
local heartbeatConn = nil
local spyFilter = ""
local MAX_LOGS = 500

_G.SIMPLESPYCONFIG_MaxRemotes = MAX_LOGS

local gm = getrawmetatable(game)
local original = gm.__namecall
setreadonly(gm, false)

local remoteEvent = Instance.new("RemoteEvent")
local remoteFunction = Instance.new("RemoteFunction")
local originalEvent = remoteEvent.FireServer
local originalFunction = remoteFunction.InvokeServer

function v2s(v, l, p, n, vtv, i, pt, path, tables)
    if typeof(v) == "number" then
        if v == math.huge then return "math.huge" end
        return tostring(v)
    elseif typeof(v) == "boolean" then
        return tostring(v)
    elseif typeof(v) == "string" then
        return formatstr(v)
    elseif typeof(v) == "function" then
        return f2s(v)
    elseif typeof(v) == "table" then
        return t2s(v, l, p, n, vtv, i, pt, path, tables)
    elseif typeof(v) == "Instance" then
        return i2p(v)
    elseif typeof(v) == "userdata" then
        return "newproxy(true)"
    elseif type(v) == "userdata" then
        return u2s(v)
    else
        return "nil --[[" .. tostring(v) .. "]]"
    end
end

function v2v(t)
    topstr = ""
    bottomstr = ""
    getnilrequired = false
    local ret = ""
    local count = 1
    for i, v in pairs(t) do
        if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. i .. " = " .. v2s(v, nil, nil, i, true) .. "\n"
        elseif tostring(i):match("^[%a_]+[%w_]*$") then
            ret = ret .. "local " .. tostring(i):lower() .. "_" .. tostring(count) .. " = " .. v2s(v, nil, nil, tostring(i):lower() .. "_" .. tostring(count), true) .. "\n"
        else
            ret = ret .. "local " .. type(v) .. "_" .. tostring(count) .. " = " .. v2s(v, nil, nil, type(v) .. "_" .. tostring(count), true) .. "\n"
        end
        count = count + 1
    end
    if getnilrequired then
        topstr = "function getNil(name,class) for _,v in pairs(getnilinstances())do if v.ClassName==class and v.Name==name then return v;end end end\n" .. topstr
    end
    if #topstr > 0 then ret = topstr .. "\n" .. ret end
    if #bottomstr > 0 then ret = ret .. bottomstr end
    return ret
end

function t2s(t, l, p, n, vtv, i, pt, path, tables)
    for k, x in pairs(getrenv()) do
        local isgucci, gpath
        if rawequal(x, t) then
            isgucci, gpath = true, ""
        elseif type(x) == "table" then
            isgucci, gpath = v2p(t, x)
        end
        if isgucci then
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
                return k .. gpath
            else
                return "getrenv()[" .. v2s(k) .. "]" .. gpath
            end
        end
    end
    if not path then path = "" end
    if not l then l = 0; tables = {} end
    if not p then p = t end
    for _, v in pairs(tables) do
        if n and rawequal(v, t) then
            bottomstr = bottomstr .. "\n" .. tostring(n) .. tostring(path) .. " = " .. tostring(n) .. tostring(({v2p(v, p)})[2])
            return "{} --[[DUPLICATE]]"
        end
    end
    table.insert(tables, t)
    local s = "{"
    local size = 0
    l = l + indent
    for k, v in pairs(t) do
        size = size + 1
        if size > 500 then break end
        local currentPath = ""
        if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
            currentPath = "." .. k
        else
            currentPath = "[" .. v2s(k, nil, p, n, vtv, i, pt, path) .. "]"
        end
        s = s .. "\n" .. string.rep(" ", l) .. "[" .. v2s(k, l, p, n, vtv, k, t, path .. currentPath, tables) .. "] = " .. v2s(v, l, p, n, vtv, k, t, path .. currentPath, tables) .. ","
    end
    if #s > 1 then s = s:sub(1, #s - 1) end
    if size > 0 then s = s .. "\n" .. string.rep(" ", l - indent) end
    return s .. "}"
end

function f2s(f)
    for k, x in pairs(getgenv()) do
        local isgucci, gpath
        if rawequal(x, f) then
            isgucci, gpath = true, ""
        elseif type(x) == "table" then
            isgucci, gpath = v2p(f, x)
        end
        if isgucci then
            if type(k) == "string" and k:match("^[%a_]+[%w_]*$") then
                return k .. gpath
            else
                return "getgenv()[" .. v2s(k) .. "]" .. gpath
            end
        end
    end
    local isgucci, gpath = v2p(f, getgc())
    if isgucci then return "getgc()" .. gpath end
    if debug.getinfo(f).name:match("%w") then
        return "function()end --[[" .. debug.getinfo(f).name .. "]]"
    end
    return "function()end"
end

function i2p(i)
    local player = getplayer(i)
    local parent = i
    local out = ""
    if parent == nil then return "nil"
    elseif player then
        while true do
            if parent and parent == player.Character then
                if player == Players.LocalPlayer then
                    return 'game:GetService("Players").LocalPlayer.Character' .. out
                else
                    return i2p(player) .. ".Character" .. out
                end
            else
                if parent.Name:match("[%a_]+[%w+]*") ~= parent.Name then
                    out = '[' .. formatstr(parent.Name) .. ']' .. out
                else
                    out = "." .. parent.Name .. out
                end
            end
            parent = parent.Parent
        end
    elseif parent ~= game then
        while true do
            if parent and parent.Parent == game then
                if pcall(game.GetService, game, parent.ClassName) then
                    if parent.ClassName == "Workspace" then
                        return "workspace" .. out
                    else
                        return 'game:GetService("' .. parent.ClassName .. '")' .. out
                    end
                else
                    if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then
                        out = 'game[' .. formatstr(parent.Name) .. ']' .. out
                    else
                        out = "game." .. parent.Name .. out
                    end
                end
            elseif parent.Parent == nil then
                getnilrequired = true
                return 'getNil(' .. formatstr(parent.Name) .. ', "' .. parent.ClassName .. '")'
            elseif parent == Players.LocalPlayer then
                out = ".LocalPlayer" .. out
            else
                if parent.Name:match("[%a_]+[%w_]*") ~= parent.Name then
                    out = '[' .. formatstr(parent.Name) .. ']' .. out
                else
                    out = "." .. parent.Name .. out
                end
            end
            parent = parent.Parent
        end
    else
        return "game"
    end
end

function u2s(u)
    if typeof(u) == "TweenInfo" then
        return "TweenInfo.new(" .. tostring(u.Time) .. ", Enum.EasingStyle." .. tostring(u.EasingStyle) .. ", Enum.EasingDirection." .. tostring(u.EasingDirection) .. ", " .. tostring(u.RepeatCount) .. ", " .. tostring(u.Reverses) .. ", " .. tostring(u.DelayTime) .. ")"
    elseif typeof(u) == "Ray" then
        return "Ray.new(" .. u2s(u.Origin) .. ", " .. u2s(u.Direction) .. ")"
    elseif typeof(u) == "NumberSequence" then
        local ret = "NumberSequence.new("
        for i, v in pairs(u.KeyPoints) do
            ret = ret .. tostring(v)
            if i < #u.KeyPoints then ret = ret .. ", " end
        end
        return ret .. ")"
    elseif typeof(u) == "ColorSequence" then
        local ret = "ColorSequence.new("
        for i, v in pairs(u.KeyPoints) do
            ret = ret .. "Color3.new(" .. tostring(v) .. ")"
            if i < #u.KeyPoints then ret = ret .. ", " end
        end
        return ret .. ")"
    elseif typeof(u) == "BrickColor" then
        return "BrickColor.new(" .. tostring(u.Number) .. ")"
    elseif typeof(u) == "NumberRange" then
        return "NumberRange.new(" .. tostring(u.Min) .. ", " .. tostring(u.Max) .. ")"
    elseif typeof(u) == "EnumItem" then
        return tostring(u)
    elseif typeof(u) == "Enums" then
        return "Enum"
    elseif typeof(u) == "RBXScriptSignal" then
        return "nil --[[RBXScriptSignal]]"
    else
        return typeof(u) .. ".new(" .. tostring(u) .. ")"
    end
end

function getplayer(instance)
    for _, v in pairs(Players:GetPlayers()) do
        if v.Character and (instance:IsDescendantOf(v.Character) or instance == v.Character) then
            return v
        end
    end
end

function v2p(x, t, path, prev)
    if not path then path = "" end
    if not prev then prev = {} end
    if rawequal(x, t) then return true, "" end
    for i, v in pairs(t) do
        if rawequal(v, x) then
            if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                return true, (path .. "." .. i)
            else
                return true, (path .. "[" .. v2s(i) .. "]")
            end
        end
        if type(v) == "table" then
            for _, y in pairs(prev) do
                if rawequal(y, v) then return false, "" end
            end
            table.insert(prev, t)
            local found, p = v2p(x, v, path, prev)
            if found then
                if type(i) == "string" and i:match("^[%a_]+[%w_]*$") then
                    return true, "." .. i .. p
                else
                    return true, "[" .. v2s(i) .. "]" .. p
                end
            end
        end
    end
    return false, ""
end

function formatstr(s)
    if not pcall(function() for _, _ in utf8.graphemes(s) do end end) then
        return "\"" .. tobyte(s) .. "\""
    end
    local returns = {}
    local lastend = 0
    for f, l in utf8.graphemes(s) do
        if l > f then
            local char = "utf8.char(" .. table.concat({utf8.codepoint(s, f, l)}, ", ") .. ")"
            if lastend >= f then
                table.insert(returns, char)
            else
                table.insert(returns, "\"" .. handlespecials(s:sub(lastend, f - 1)) .. "\"")
                table.insert(returns, char)
            end
            lastend = l + 1
        end
    end
    if lastend <= #s then
        table.insert(returns, "\"" .. s:sub(lastend, #s) .. "\"")
    end
    return table.concat(returns, " .. ")
end

function tobyte(s)
    local news = ""
    for i = 1, #s do
        news = news .. "\\" .. s:sub(i, i):byte()
    end
    return news
end

function handlespecials(s, nested)
    if not nested then
        s = s:gsub("\\", "\\\\")
        s = s:gsub("\"", "\\\"")
    end
    if s:match("\n") then
        local pos, pos2 = s:find("\n")
        s = s:sub(0, pos - 1) .. "\\n" .. s:sub(pos2 + 1, s:len())
        return handlespecials(s, true)
    elseif s:match("\t") then
        local pos, pos2 = s:find("\t")
        s = s:sub(0, pos - 1) .. "\\t" .. s:sub(pos2 + 1, s:len())
        return handlespecials(s, true)
    else
        return s
    end
end

function genScript(remote, ...)
    prevTables = {}
    local gen = ""
    local args = {...}
    if #args > 0 then
        if not pcall(function()
            gen = v2v({args = args}) .. "\n"
        end) then
            gen = gen .. "-- TableToString failure!\nlocal args = {"
            if not pcall(function()
                for i, v in pairs(args) do
                    if type(i) ~= "Instance" and type(i) ~= "userdata" then
                        gen = gen .. "\n    [" .. tostring(i) .. "] = "
                    elseif type(i) == "string" then
                        gen = gen .. '\n    ["' .. tostring(i) .. '"] = '
                    end
                    if type(v) ~= "Instance" and type(v) ~= "userdata" then
                        gen = gen .. tostring(v)
                    elseif type(v) == "string" then
                        gen = gen .. '"' .. tostring(v) .. '"'
                    end
                end
                gen = gen .. "\n}\n\n"
            end) then
                gen = gen .. "}\n-- failure!"
            end
        end
        if not remote:IsDescendantOf(game) and not getnilrequired then
            gen = "function getNil(name,class) for _,v in pairs(getnilinstances())do if v.ClassName==class and v.Name==name then return v;end end end\n\n" .. gen
        end
        if remote:IsA("RemoteEvent") then
            gen = gen .. v2s(remote) .. ":FireServer(unpack(args))"
        elseif remote:IsA("RemoteFunction") then
            gen = gen .. v2s(remote) .. ":InvokeServer(unpack(args))"
        end
    else
        if remote:IsA("RemoteEvent") then
            gen = gen .. v2s(remote) .. ":FireServer()"
        elseif remote:IsA("RemoteFunction") then
            gen = gen .. v2s(remote) .. ":InvokeServer()"
        end
    end
    gen = "-- Script generated by SimpleSpy - credits to exx#9394\n\n" .. gen
    prevTables = {}
    return gen
end

function schedule(f, ...)
    table.insert(scheduled, {f, ...})
end

function taskscheduler()
    if not toggle then
        scheduled = {}
        return
    end
    if #scheduled > 1000 then table.remove(scheduled, #scheduled) end
    if #scheduled > 0 then
        local currentf = scheduled[1]
        table.remove(scheduled, 1)
        if type(currentf) == "table" and type(currentf[1]) == "function" then
            pcall(unpack(currentf))
        end
    end
end

local pushToUI = nil

function remoteHandler(isHookFn, methodName, remote, args, func)
    local functionInfoStr
    if islclosure(func) then
        local functionInfo = {}
        pcall(function() functionInfo.info = debug.getinfo(func) end)
        pcall(function() functionInfo.constants = debug.getconstants(func) end)
        pcall(function() functionInfoStr = v2v{functionInfo = functionInfo} end)
    end
    if methodName:lower() == "fireserver" and not (blacklist[remote] or blacklist[remote.Name]) then
        table.remove(args, 1)
        bindableHandler("event", remote.Name, genScript(remote, unpack(args)), remote, functionInfoStr, (blocklist[remote] or blocklist[remote.Name]))
    elseif methodName:lower() == "invokeserver" and not (blacklist[remote] or blacklist[remote.Name]) then
        table.remove(args, 1)
        bindableHandler("function", remote.Name, genScript(remote, unpack(args)), remote, functionInfoStr, (blocklist[remote] or blocklist[remote.Name]))
    end
end

function hookRemote(methodName, remote, ...)
    local args = {...}
    if typeof(remote) == "Instance" then
        local func = debug.getinfo(4).func
        schedule(remoteHandler, true, methodName, remote, args, func)
        if (blocklist[remote] or blocklist[remote.Name]) then return false end
    end
    return true
end

local newnamecall = newcclosure(function(...)
    local args = {...}
    local methodName = getnamecallmethod()
    local func = debug.getinfo(3).func
    coroutine.wrap(function()
        if methodName:lower() == "invokeserver" or methodName:lower() == "fireserver" and typeof(args[1]) == "Instance" then
            local remote = args[1]
            schedule(remoteHandler, false, methodName, remote, args, func)
        end
    end)()
    if args[1] and (methodName:lower() == "invokeserver" or methodName:lower() == "fireserver") and (blocklist[args[1]] or blocklist[args[1].Name]) then
        return nil
    else
        return original(...)
    end
end)

local newFireServer = newcclosure(function(...) if hookRemote("FireServer", ...) then return originalEvent(...) end end)
local newInvokeServer = newcclosure(function(...) if hookRemote("InvokeServer", ...) then return originalFunction(...) end end)

function toggleSpy()
    if not toggle then
        setreadonly(gm, false)
        if not original then
            original = gm.__namecall
            if not original then
                warn("SimpleSpy: namecall not found")
                return false
            end
        end
        gm.__namecall = newnamecall
        pcall(function()
            originalEvent = hookfunction(remoteEvent.FireServer, newFireServer)
            originalFunction = hookfunction(remoteFunction.InvokeServer, newInvokeServer)
        end)
        setreadonly(gm, true)
        return true
    else
        setreadonly(gm, false)
        gm.__namecall = original
        pcall(function()
            hookfunction(remoteEvent.FireServer, originalEvent)
            hookfunction(remoteFunction.InvokeServer, originalFunction)
        end)
        setreadonly(gm, true)
        return true
    end
end

function toggleSpyMethod()
    local ok = toggleSpy()
    if ok then toggle = not toggle end
    return ok
end

function bindableHandler(type_, name, genScript_, remote, functionInfo, blocked)
    pcall(function()
        if syn and syn.set_thread_identity then syn.set_thread_identity(7) end
    end)
    local entry = {
        Type = type_,
        Name = name,
        GenScript = genScript_,
        Remote = remote,
        Function = functionInfo,
        Blocked = blocked,
        Time = os.date("%H:%M:%S"),
    }
    if blocked then
        entry.GenScript = "-- BLOCKED BY SIMPLESPY\n\n" .. entry.GenScript
    end
    logs[#logs + 1] = entry
    if pushToUI then pcall(pushToUI, #logs) end
end

local SpyStatus = SpyTab:AddInfoGrid({
    Title = "Status",
    Columns = 3,
    Items = {
        { Label = "Spy",    Value = "Off" },
        { Label = "Logged", Value = "0" },
        { Label = "Queue",  Value = "0" },
    },
})

local RemoteTable = SpyTab:AddTable({
    Title = "Remote List",
    Description = "Every intercepted remote — most recent at top",
    Height = IS_MOBILE and 220 or 260,
    Columns = {
        { Key = "idx",    Label = "#",      Weight = 1 },
        { Key = "time",   Label = "Time",   Weight = 2 },
        { Key = "method", Label = "Method", Weight = 2 },
        { Key = "name",   Label = "Remote", Weight = 5 },
    },
    Rows = {},
})

local ScriptViewer = SpyTab:AddTextbox({
    Text = "Script Viewer",
    Description = "Full Lua script of the selected remote — copy with the button below",
    Icon = "Lucide:code",
    Placeholder = "Select a remote from the list...",
    Default = "",
    Height = IS_MOBILE and 180 or 220,
    Callback = function() end,
})

local SpyConsole = SpyTab:AddConsole({
    Height = IS_MOBILE and 100 or 120,
})

SpyConsole:Log("[Spy] Loaded — toggle Enable Spy to start listening", Enum.MessageType.MessageInfo)

local function refreshTable()
    local rows = {}
    for i = #logs, 1, -1 do
        local log = logs[i]
        rows[#rows + 1] = {
            idx    = i,
            time   = log.Time,
            method = log.Type == "event" and "Fire" or "Invoke",
            name   = log.Name,
        }
    end

    local sent = false
    if type(RemoteTable.SetRows) == "function" then
        if pcall(function() RemoteTable:SetRows(rows) end) then sent = true end
    end
    if not sent and type(RemoteTable.SetData) == "function" then
        if pcall(function() RemoteTable:SetData(rows) end) then sent = true end
    end
    if not sent and type(RemoteTable.Update) == "function" then
        if pcall(function() RemoteTable:Update(rows) end) then sent = true end
    end
    if not sent and type(RemoteTable.Refresh) == "function" then
        if pcall(function() RemoteTable:Refresh(rows) end) then sent = true end
    end
    if not sent then
        pcall(function() RemoteTable.Rows = rows end)
    end
end

local function tryHookRowClick()
    if RemoteTable.OnRowClick and type(RemoteTable.OnRowClick.Connect) == "function" then
        pcall(function()
            RemoteTable.OnRowClick:Connect(function(row)
                local idx = row and (row.idx or row._index)
                if idx and logs[idx] then
                    selected = logs[idx]
                    selectedIndex = idx
                    ScriptViewer:SetValue(selected.GenScript)
                    SpyConsole:Log("Selected #" .. idx .. " " .. selected.Name, Enum.MessageType.MessageInfo)
                end
            end)
        end)
        return true
    end
    if RemoteTable.RowClick and type(RemoteTable.RowClick.Connect) == "function" then
        pcall(function()
            RemoteTable.RowClick:Connect(function(row)
                local idx = row and (row.idx or row._index)
                if idx and logs[idx] then
                    selected = logs[idx]
                    selectedIndex = idx
                    ScriptViewer:SetValue(selected.GenScript)
                end
            end)
        end)
        return true
    end
    if RemoteTable.OnSelect and type(RemoteTable.OnSelect.Connect) == "function" then
        pcall(function()
            RemoteTable.OnSelect:Connect(function(row)
                local idx = row and (row.idx or row._index)
                if idx and logs[idx] then
                    selected = logs[idx]
                    selectedIndex = idx
                    ScriptViewer:SetValue(selected.GenScript)
                end
            end)
        end)
        return true
    end
    return false
end

tryHookRowClick()

local EMPTY_OPTION = "(no remotes yet)"

local RemoteDropdown = SpyTab:AddDropdown({
    Text = "Select Remote (fallback)",
    Description = "Use this if clicking the table doesn't work",
    Icon = "Lucide:list",
    Options = { EMPTY_OPTION },
    Default = EMPTY_OPTION,
    Callback = function(value)
        if value == EMPTY_OPTION then return end
        local n = tonumber(string.match(value, "^#(%d+)"))
        if n and logs[n] then
            selected = logs[n]
            selectedIndex = n
            ScriptViewer:SetValue(selected.GenScript)
            SpyConsole:Log("Selected #" .. n .. " " .. selected.Name, Enum.MessageType.MessageInfo)
        end
    end,
})

local function refreshDropdown()
    local opts = {}
    for i = #logs, 1, -1 do
        local log = logs[i]
        local tag = log.Type == "event" and "Fire" or "Invoke"
        opts[#opts + 1] = "#" .. i .. " | " .. tag .. " | " .. log.Name
    end
    if #opts == 0 then opts = { EMPTY_OPTION } end

    pcall(function()
        if RemoteDropdown.SetOptions then
            RemoteDropdown:SetOptions(opts)
        elseif RemoteDropdown.Refresh then
            RemoteDropdown:Refresh(opts)
        elseif RemoteDropdown.UpdateOptions then
            RemoteDropdown:UpdateOptions(opts)
        end
    end)
end

pushToUI = function(idx)
    local log = logs[idx]
    if not log then return end
    task.spawn(function()
        local prefix = log.Type == "event" and "[Fire] " or "[Invoke] "
        local color = log.Type == "event"
            and Enum.MessageType.MessageOutput
            or Enum.MessageType.MessageInfo
        pcall(function()
            SpyConsole:Log(prefix .. "#" .. idx .. " " .. log.Name, color)
            SpyStatus:SetValue("Logged", tostring(#logs))
        end)
    end)
end

task.spawn(function()
    local lastCount = 0
    while true do
        task.wait(0.4)
        if #logs ~= lastCount then
            lastCount = #logs
            refreshTable()
            refreshDropdown()
            pcall(function() SpyStatus:SetValue("Logged", tostring(#logs)) end)
        end
        pcall(function() SpyStatus:SetValue("Queue", tostring(#scheduled)) end)
    end
end)

SpyTab:AddToggle({
    Text = "Enable Spy",
    Description = "Start intercepting remote calls",
    Icon = "Lucide:radio",
    Flag = "spyEnabled",
    Default = false,
    Callback = function(v)
        if v and not spyRunning then
            local ok = toggleSpyMethod()
            if not ok then
                SpyConsole:Log("[Spy] Failed to install hook", Enum.MessageType.MessageError)
                return
            end
            spyRunning = true
            heartbeatConn = RunService.Heartbeat:Connect(taskscheduler)
            SpyConsole:Log("[Spy] Hook installed — listening", Enum.MessageType.MessageInfo)
            SpyStatus:SetValue("Spy", "Running")
        elseif not v and spyRunning then
            toggleSpyMethod()
            if heartbeatConn then heartbeatConn:Disconnect() heartbeatConn = nil end
            scheduled = {}
            spyRunning = false
            SpyConsole:Log("[Spy] Hook removed — stopped", Enum.MessageType.MessageWarning)
            SpyStatus:SetValue("Spy", "Off")
        end
    end,
})

SpyTab:AddTextbox({
    Text = "Filter",
    Description = "Only log remotes whose name contains this",
    Icon = "Lucide:filter",
    Placeholder = "e.g. Shoot, Update",
    Callback = function(text) spyFilter = text or "" end,
})

SpyTab:AddButton({
    Text = "Copy Selected Script",
    Description = "Copy the Lua script shown in the viewer",
    Icon = "Lucide:clipboard-copy",
    Callback = function()
        if selected and selected.GenScript then
            local ok = pcall(setclipboard, selected.GenScript)
            if ok then
                VindUI:Notify({ Title = "Copied", Text = selected.Name, Type = "success", Duration = 2 })
            else
                SpyConsole:Log(selected.GenScript, Enum.MessageType.MessageOutput)
                VindUI:Notify({ Title = "Clipboard unavailable", Text = "Printed to console", Type = "warning", Duration = 3 })
            end
        else
            VindUI:Notify({ Title = "Select a remote first", Type = "warning", Duration = 2 })
        end
    end,
})

SpyTab:AddButton({
    Text = "Run Selected Script",
    Description = "Execute the script in the viewer",
    Icon = "Lucide:play",
    Callback = function()
        if not selected or not selected.GenScript then
            VindUI:Notify({ Title = "Select a remote first", Type = "warning", Duration = 2 })
            return
        end
        local fn, err = loadstring(selected.GenScript)
        if not fn then
            VindUI:Notify({ Title = "Compile Error", Text = tostring(err):sub(1, 150), Type = "error", Duration = 4 })
            return
        end
        local ok, runErr = pcall(fn)
        VindUI:Notify({
            Title = ok and "Executed" or "Runtime Error",
            Text = ok and "Ran successfully" or tostring(runErr):sub(1, 150),
            Type = ok and "success" or "error",
            Duration = 3,
        })
    end,
})

SpyTab:AddButton({
    Text = "Blacklist Selected",
    Description = "Stop logging this remote",
    Icon = "Lucide:ban",
    Callback = function()
        if selected and selected.Remote then
            blacklist[selected.Remote] = true
            VindUI:Notify({ Title = "Blacklisted", Text = selected.Name, Type = "info", Duration = 2 })
        else
            VindUI:Notify({ Title = "Select a remote first", Type = "warning", Duration = 2 })
        end
    end,
})

SpyTab:AddButton({
    Text = "Clear Blacklist",
    Description = "Allow blacklisted remotes again",
    Icon = "Lucide:rotate-ccw",
    Callback = function()
        blacklist = {}
        VindUI:Notify({ Title = "Blacklist cleared", Type = "success", Duration = 2 })
    end,
})

SpyTab:AddButton({
    Text = "Clear All Logs",
    Description = "Delete every logged remote",
    Icon = "Lucide:trash-2",
    Callback = function()
        logs = {}
        selected = nil
        selectedIndex = 0
        ScriptViewer:SetValue("")
        SpyConsole:Clear()
        refreshTable()
        refreshDropdown()
        pcall(function() SpyStatus:SetValue("Logged", "0") end)
        VindUI:Notify({ Title = "Cleared", Type = "success", Duration = 2 })
    end,
})

do
    local parentGui = (pcall(gethui) and gethui()) or game:GetService("CoreGui")

    local fabGui = Instance.new("ScreenGui")
    fabGui.Name = "\0DevToolsFAB"
    fabGui.ResetOnSpawn = false
    fabGui.IgnoreGuiInset = true
    fabGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    fabGui.DisplayOrder = 9999
    fabGui.Parent = parentGui

    local FAB = Instance.new("TextButton")
    FAB.Name = "FAB"
    FAB.Size = UDim2.fromOffset(56, 56)
    FAB.Position = UDim2.new(1, -76, 0, 120)
    FAB.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    FAB.AutoButtonColor = false
    FAB.Text = ""
    FAB.BorderSizePixel = 0
    FAB.Parent = fabGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = FAB

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(50, 50, 55)
    stroke.Thickness = 1.5
    stroke.Parent = FAB

    local icon = Instance.new("TextLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(1, 0, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = ">_"
    icon.Font = Enum.Font.Code
    icon.TextSize = 22
    icon.TextColor3 = Color3.fromRGB(240, 240, 245)
    icon.TextXAlignment = Enum.TextXAlignment.Center
    icon.TextYAlignment = Enum.TextYAlignment.Center
    icon.Parent = FAB

    local dragging, dragStart, startPos
    FAB.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = FAB.Position
        end
    end)
    FAB.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
           or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            FAB.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    FAB.MouseEnter:Connect(function()
        TweenService:Create(FAB, TweenInfo.new(0.15),
            { BackgroundColor3 = Color3.fromRGB(30, 30, 35) }):Play()
        TweenService:Create(icon, TweenInfo.new(0.15),
            { TextColor3 = Color3.fromRGB(139, 92, 246) }):Play()
    end)
    FAB.MouseLeave:Connect(function()
        TweenService:Create(FAB, TweenInfo.new(0.15),
            { BackgroundColor3 = Color3.fromRGB(15, 15, 18) }):Play()
        TweenService:Create(icon, TweenInfo.new(0.15),
            { TextColor3 = Color3.fromRGB(240, 240, 245) }):Play()
    end)

    FAB.MouseButton1Click:Connect(function()
        if Window:IsOpen() then
            Window:Close()
        else
            Window:Open()
        end
    end)
end

print("[Remote Spy] Loaded — SimpleSpy core ready")
