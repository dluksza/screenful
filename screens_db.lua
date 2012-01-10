screens = {
	['default'] = {
		['connected'] = function (xrandrOutput)
			return '--output ' .. xrandrOutput .. ' --auto --same-as LVDS1'
		end,
		['disconnected'] = function (xrandrOutput)
			return '--output ' .. xrandrOutput .. ' --off'
		end
	},
	['55250827610'] = {
		['connected'] = function (xrandrOutput)
			return '--output ' .. xrandrOutput .. ' --auto --above LVDS1'
		end,
		['disconnected'] = nil
	}
}

