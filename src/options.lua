local SCRIPT_NAME = "mpv_crop_script"

local SCRIPT_KEYBIND = "c"
local SCRIPT_HANDLER = "crop-screenshot"

--------------------
-- Script options --
--------------------

local script_options = {
    output_format   = "png",
    output_template = "%f %p %D%U.%x", -- "Some video name 00.01.25.666 200x400 5.png"
    -- Possible keys:
    -- %f - Original filename without extension - "A.Video.2017"
    -- %X - Original extension - "mkv"
    -- %x - Output extension   - "png"
    -- %u - Unique - "", "_1", "_2", ...
    -- %U - Unique - "", " 1", " 2", ...
    -- %p - Current time - 00.03.50.423
    -- %P - Current time with decimals - 00.03.50
    -- %D - Crop size - 200x300, 123x450, full
    keep_original   = false
}

-- Read user-given options, if any
read_options(script_options, SCRIPT_NAME)
