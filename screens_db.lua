screens = {
	['default'] = {
		['connected'] = function ()
		end,
		['disconnected'] = function ()
		end
	}
	['55250827610'] = {
		['connected'] = function ()
			os.execute("xrandr --output HDMI1 --auto --above LVDS1")
		end,
		['disconnected'] = nil
	},
}
