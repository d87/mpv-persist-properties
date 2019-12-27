local utils = require "mp.utils"
local msg = require "mp.msg"

local opts = {
    properties = "volume,sub-scale",
}
(require 'mp.options').read_options(opts)

local CONFIG_ROOT = (os.getenv('APPDATA') or os.getenv('HOME')..'/.config')..'/mpv/'
local PCONFIG = CONFIG_ROOT..'persistent_config.json';

local function split(input)
    local ret = {}
    for str in string.gmatch(input, "([^,]+)") do
        table.insert(ret, str)
    end
    return ret
end
local persisted_properties = split(opts.properties)

local print = function(...)
    -- return msg.log("info", ...)
end

-- print("Config Root is "..CONFIG_ROOT)

local isInitialized = false

local properties

local function load_config(file)
    local f = io.open(file, "r")
    if f then
        local jsonString = f:read()
        f:close()

        local props = utils.parse_json(jsonString)
        if props then
            return props
        end
    end
    return {}
end

local function save_config(file, properties)
    local serialized_props = utils.format_json(properties)

    local f = io.open(file, 'w+')
    if f then
        f:write(serialized_props)
        f:close()
    else
        msg.log("error", string.format("Couldn't open file: %s", file))
    end
end

local save_timer = nil
local got_unsaved_changed = false

local function onInitialLoad()
    properties = load_config(PCONFIG)

    for name, value in pairs(properties) do
        mp.set_property_number(name, value)
    end

    for i, property in ipairs(persisted_properties) do
        local property_type = nil
        mp.observe_property(property, property_type, function(name)
            if isInitialized then
                local value = mp.get_property_native(name)
                -- print(string.format("%s changed to %s at %s", name, value,  os.time()))

                properties[name] = value

                if save_timer then
                    save_timer:kill()
                    save_timer:resume()
                    got_unsaved_changed = true
                else
                    save_timer = mp.add_timeout(5, function()
                        save_config(PCONFIG, properties)
                        got_unsaved_changed = false
                    end)
                end
            end
        end)
    end

    mp.unregister_event(onInitialLoad)
    isInitialized = true
end

mp.register_event("file-loaded", onInitialLoad)
mp.register_event("end-file", function()
    if got_unsaved_changed then
        save_config(PCONFIG, properties)
    end
end)

