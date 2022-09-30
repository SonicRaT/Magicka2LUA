loadfile = ...

local req = require
local LIST = {}

local function replace(name, with)

        LIST[name] = function()
                local file = loadfile(with)
                assert(type(file) == "function", file)
                package.loaded[name] = file()
                return file()
        end
end

replace("scripts/game/boot/boot_common","codebase/boot_common.lua")
replace("foundation/scripts/boot/foundation_setup","codebase/foundation_setup.lua")

function require(name)

        if package.loaded[name] then
                return package.loaded[name]
        end

        if rawget(LIST, name) then
                return LIST[name]()
        end

        return req(name)
end