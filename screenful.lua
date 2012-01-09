local card = 'card0'
local dev = '/sys/class/drm/'

local outputMapping = {
	['DP-1'] = 'DP1',
	['DP-2'] = 'DP2',
	['VGA-1'] = 'VGA1',
	['LVDS-1'] = 'LVDS1',
	['HDMI-A-1'] = 'HDMI1',
	['HDMI-A-2'] = 'HDMI2'
}

local function log(text)
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

local function getScreenId(output)
	local screenId = ''
	local edid = io.open(output .. '/edid', 'rb')
	local id = edid:read('*all')
	for i = 12, 17 do
		code = id:byte(i)
		if code then
			screenId = screenId .. code
		end
	end

	return screenId
end

local function getXrandrOutput(outputPath, outCard)
	local regex = dev .. outCard .. '/' .. outCard .. '[-]'
	local drmName = string.gsub(outputPath, regex, '')
	log('getXrandrdOutput: ' .. tostring(drmName) .. ' | regex: ' .. regex .. '\n')
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

local function setupScreen(xrandrParams)
	os.execute('xrandr ' .. xrandrParams)
end

local function performConfiguredAction(screenId, action, parameters)
	require('screens_db')
	log('perform confiured action for ' .. screenId .. '\n')
	local configuration = screens[screenId]
	log(tostring(configuration))
	if configuration then
		if configuration[action] then
			log('performing action\n')
			configuration[action]()
		end
	end
end

local function disableOutput(out, changedCard)
	log('output disconnected ' .. out .. "\n")
	local xrandrOut = getXrandrOutput(out, changedCard)
	local screenId = getScreenId(out)
	performConfiguredAction(screenId, 'disconnect')
	setupScreen('--output ' .. xrandrOut .. ' --off')
end

local function enableOutput(out, changedCard)
	log('output connected' .. out .. "\n")
	local xrandrOut = getXrandrOutput(out, changedCard)
	local screenId = getScreenId(out)
	log('enable out: ' .. out .. ' screenId: ' .. tostring(screenId) .. '\n')
	performConfiguredAction(screenId, 'connected', { xrandrOut })
end

local cardDev = dev .. card
local outputs = connectedOutputs(cardDev, card)

function updateScreens(changedCard)
	log('screen being updated ' .. changedCard .. '\n')
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

