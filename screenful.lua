----------------------------------------------------------------------------
---- @author dluksza &lt;dariusz@luksza.org&gt;
---- @copyright 2012 dluksza
------------------------------------------------------------------------------

-- Package envronment
local naughty = require('naughty')
local awful = require("awful")

local waitForEdid = 30
local card = 'card0'
local dev = '/sys/class/drm/'
local configPath = awful.util.getdir("config") .. "/screens_db.lua"

local outputMapping = {
	['DP-1'] = 'DP1',
	['DP-2'] = 'DP2',
	['VGA-1'] = 'VGA1',
	['LVDS-1'] = 'LVDS1',
	['HDMI-A-1'] = 'HDMI1',
	['HDMI-A-2'] = 'HDMI2',
	['eDP1'] = 'LVDS1'
}

local function log(text)
	naughty.notify({
		title = 'screenful debug',
		text = text,
		ontop = true,
		preset = naughty.config.presets.critical
	})
	local log = io.open('/tmp/log.txt', 'aw')
	log:write(text)
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
	local screenId = ''
	local edid = io.open(output .. '/edid', 'rb')
	local id = edid:read('*all')
	io.close(edid)
	local start = os.time()
	while emptyStr(id) and os.time() - start < waitForEdid do
		edid = io.open(output .. '/edid', 'rb')
		id = edid:read('*all')
		io.close(edid)
	end
	for i = 12, 17 do
		code = id:byte(i)
		if code then
			screenId = screenId .. code
		end
	end
	if emptyStr(id) then
		log('cannot read EDID after "' .. waitForEdid .. 's')
	end

	return screenId
end

local function getXrandrOutput(outputPath, outCard)
	local regex = dev .. outCard .. '/' .. outCard .. '[-]'
	local drmName = string.gsub(outputPath, regex, '')

	return outputMapping[drmName]
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

local function appendConfiguration(screenId)
	local file = io.open(configPath, 'a')

	file:write("--\t['" .. screenId .. "'] = {\n")
	file:write("--\t\t['connected'] = function ()\n")
	file:write("--\t\t\treturn nil\n")
	file:write("--\t\tend,\n")
	file:write("--\t\t['disconnected'] = function ()\n")
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
	require('screens_db')
	local xrandrOpts = ''
	local configuration = screens[screenId]
	if configuration then
		if configuration[action] then -- get xrandr options
			xrandrOpts = configuration[action](xrandrOut)
		end
	else -- configuration not found, append configuration template
		if tostring(screenId):len() ~= 0 and not hasConfigurationFor(screenId) then
			naughty.notify({text = 'Append new configuration for screen id: ' .. screenId})
			appendConfiguration(screenId)
		end
	end
	if xrandrOpts:len() == 0 then -- use default configuration if specific was not found
		xrandrOpts = screens['default'][action](xrandrOut)
	end
	setupScreen(xrandrOpts)
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
end

