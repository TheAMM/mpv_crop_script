local SCRIPT_NAME = "mpv_crop_script"

local SCRIPT_KEYBIND = "c"
local SCRIPT_HANDLER = "crop-screenshot"

--------------------
-- Script options --
--------------------

local script_options = {
    output_format   = "png",
    -- For the possible keys, see README.md and main.lua
    output_template = "${filename} ${#pos:%02h.%02m.%06.3s} ${!full:${crop_w}x${crop_h} ${%unique:%03d}}.png",
    create_directories = false,
    keep_original   = false,
    disable_keybind = false
}

-- Read user-given options, if any
read_options(script_options, SCRIPT_NAME)
