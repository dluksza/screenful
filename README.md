screenful
=========

screenful is an extension library for [Awesome WM](http://awesome.naquadah.org/) that enables it to automatically setup screen organization. It leverage from udev notification about drm change events and device specific EDID information.

When drm change event occurs, screenful is informed via awesome-client command. Then it discovers with output was connected and reads screen EDID. Next it reads lua configuration script and looks for configuration for this device. If it isn't available yet, it will add commented out template and run default configuration, otherwise it will execute specific configuration.

Since configuration file is also lua script you can do many things when screens are connected or disconnected. For example you can change default mplayer audio output when you are connecting HD TV set using HDMI; theoretically you can also reorganize yours windows/tags etc. When one of configuration options is missing ('connected' or 'disconnected') then default action will be launched.

Install
=======

98-screen-detect.rules - copy to /etc/udev/rules and execute with root privileges `udevadm control --reload-rules`
notify-awesome - copy to /lib/udev and add execution bit
screenful.lua - copy to ~/.config/awesome
screens_db.lua - copy to ~/.config/awesome

Add to yours rc.lua file fallowing require statements:
require("awful.remote")
require("screenful")

No you can connect additional screen. HDMI outputs are detected almost instantly in case of VGA outputs you need to wait cuple of seconds. Default configuration will clone LVDS1 output. Then you can edit ~/.config/awesome/screens_db.lua config file. At the end you will find commented out configuration template with screen EDID value. Both functions ('connected' and 'disconnected') should return xrandr options eg:

```
screens = {
    ['default'] = {
        ['connected'] = function (xrandrOutput)
	    return '--output ' .. xrandrOutput .. ' --auto --same-as LVDS1'
	end,
	['disconnected'] = function (xrandrOutput)
	    return '--output ' .. xrandrOutput .. ' --off'
	end
    }
    ['99999999999'] = {
        ['connected'] = function (xrandrOutput)
	    return '--output ' .. xrandrOutput .. ' --auto --above LVDS1'
	end,
    }
}
```

In this example, when screen with ID 99999999999 is connected to VGA1 output then screenful will execute command:

```
$ xrandr --output VGA1 --auto --above LVDS1
```

When it is disconnected, because 'disconnected' is not defined for this output, default disconnect action will be executed:

```
$ xrandr --output VGA1 --off
```

Known BUGS
=========

* when device is disconnected always default disconnect action is called

TODO
====

* setup proper screen organization on awesome boot
* support more then one card
* support conditional configuration based on connected devices/outputs and id's
