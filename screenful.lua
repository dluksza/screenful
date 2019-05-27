----------------------------------------------------------------------------
---- @author dluksza &lt;dariusz@luksza.org&gt;
---- @copyright 2012 dluksza
------------------------------------------------------------------------------

-- Package envronment
local naughty = require('naughty')
local awful = require("awful")
local screen = require("awful.screen")
local io = require("io")
local os = require("os")
local awesome = awesome
require('screens_db')

local card = 'card0'
local dev = '/sys/class/drm/'
local configPath = awful.util.getdir("config") .. "/screens_db.lua"

local function log(text)
	naughty.notify({
		title = 'screenful debug',
		text = text,
		ontop = true,
		preset = naughty.config.presets.critical
	})
	local log = io.open('/tmp/awesomewm-widget-screenful.error.log', 'a+')
	log:write(text .. "\n")
	log:flush()
	log:close()
end

local function isOutputConnected(path)
	local status = io.open(path .. '/status', 'r')
	local value = status:read('*all')

	return 'connected\n' == value
end

local function connectedOutputs(path, card)
	local result = {}
	local outputs = io.popen('ls -1 -d ' .. path .. '/' .. card .. '-*')
	while true do
		local output = outputs:read('*line')
		if not output then break end
		if isOutputConnected(output) then
			result[output] = true
		end
	end

	return result
end

local function emptyStr(str)
	return str == nil or str == ''
end

local function getScreenId(output)
	local screenId = nil

    if isOutputConnected(output) then
		screenId = ''
		os.execute("udevadm settle")
		local edid = io.open(output .. '/edid', 'rb')
		local id = edid:read('*all')
        io.close(edid)
		if emptyStr(id) then
			log('cannot read EDID from ' .. output .. '/edid')
			return false
        end
        for i = 12, 17 do
            code = id:byte(i)
            if code then
                screenId = screenId .. code
            end
        end
    end
	return screenId
end

local function getXrandrOutput(outputPath, outCard)
	local regex = dev .. outCard .. '/' .. outCard .. '[-]'
	local drmName = string.gsub(outputPath, regex, '')

	if outputMapping[drmName] then
		return outputMapping[drmName]
	end

	return drmName
end

local function mergeTables(table1, table2)
	local result = {}
	for k,v in pairs(table1) do
		result[k] = v
	end
	for k,v in pairs(table2) do
		result[k] = v
	end

	return result
end

local function hasConfigurationFor(screenId)
	local file = io.open(configPath, 'r')
	local conf = file:read('*all')
	file:close()

	return string.find(conf, "['\"]" .. screenId .. "['\"]")
end

local function appendConfiguration(screenId, xrandrOut)
	local file = io.open(configPath, 'a')

	file:write("--\t['" .. screenId .. "'] = { -- " .. xrandrOut .. "\n")
	file:write("--\t\t['connected'] = function (xrandrOutput)\n")
	file:write("--\t\t\tif xrandrOutput ~= defaultOutput then\n")
	file:write("--\t\t\t\treturn '--output ' .. xrandrOutput .. ' --auto --same-as ' .. defaultOutput\n")
	file:write("--\t\t\tend\n")
	file:write("--\t\t\treturn nil\n")
	file:write("--\t\tend,\n")
	file:write("--\t\t['disconnected'] = function (xrandrOutput)\n")
	file:write("--\t\t\tif xrandrOutput ~= defaultOutput then\n")
	file:write("--\t\t\treturn '--output ' .. xrandrOutput .. ' --off --output ' .. defaultOutput .. ' --auto'\n")
	file:write("--\t\t\tend\n")
	file:write("--\t\t\treturn nil\n")
	file:write("--\t\tend\n")
	file:write("--\t}\n")
	file:flush()
	file:close()
end

local function setupScreen(xrandrParams)
	os.execute('xrandr ' .. xrandrParams)
end

local function performConfiguredAction(screenId, action, xrandrOut)
	local xrandrOpts = ''
    if screenId then
        local configuration = screens[screenId]
        if configuration then
            if configuration[action] then -- get xrandr options
                xrandrOpts = configuration[action](xrandrOut)
            end
        else -- configuration not found, append configuration template
            if tostring(screenId):len() ~= 0 and not hasConfigurationFor(screenId) then
                naughty.notify({text = 'Append new configuration for screen id: ' .. screenId})
                appendConfiguration(screenId, xrandrOut)
            end
        end
    end

    if xrandrOpts:len() == 0 then -- use default configuration if specific was not found
        xrandrOpts = screens['default'][action](xrandrOut)
    end
    if xrandrOpts then
        setupScreen(xrandrOpts)
    end
end

local function disableOutput(out, changedCard)
	local xrandrOut = getXrandrOutput(out, changedCard)
	local screenId = getScreenId(out)
    performConfiguredAction(screenId, 'disconnected', xrandrOut)
    naughty.notify({ text='Output ' .. xrandrOut .. ' disconnected' })
end

local function enableOutput(out, changedCard)
	local xrandrOut = getXrandrOutput(out, changedCard)
	local screenId = getScreenId(out)
    performConfiguredAction(screenId, 'connected', xrandrOut)
end

local cardDev = dev .. card
local outputs = connectedOutputs(cardDev, card)

function updateScreens(changedCard)
	local newCardDev = dev .. changedCard
	local newOutputs = connectedOutputs(newCardDev, changedCard)
	local mergedOutputs = mergeTables(outputs, newOutputs)

	for out in pairs(mergedOutputs) do
		if not outputs[out] then -- connected
			enableOutput(out, changedCard)
		elseif not newOutputs[out] then -- disconnected
			disableOutput(out, changedCard)
		end
	end
	outputs = newOutputs

    -- reinit awesome
    awesome.restart()
end

