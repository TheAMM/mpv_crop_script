local SCRIPT_NAME = "mpv_crop_script"

local SCRIPT_KEYBIND = "c"
local SCRIPT_HANDLER = "crop-screenshot"

--------------------
-- Script options --
--------------------

local script_options = OptionParser(SCRIPT_NAME)
local option_values = script_options.values

script_options:add_options({
  {nil, nil, "mpv_crop_script.lua options and default values"},
  {nil, nil, "Output options #", true},
  {"output_template", "${filename} ${#pos:%02h.%02m.%06.3s} ${!full:${crop_w}x${crop_h} ${%unique:%03d}}.png",
    "Directory to save (temporary) encode scripts in. Same default as with output_directory"},
  {"output_format", "png",
    "Format (encoder) to save final crops in"},
  {"create_directories", false,
    "Whether to create the directories in the final output path (defined by output_template)"},
  {"keep_original", false,
    "Keep the full-sized temporary screenshot as well"},

  {nil, nil, "Crop tool options #", true},
  {"overlay_transparency", 160,
    "Transparency (0 - opaque, 255 - transparent) of the dim overlay on the non-cropped area"},
  {"overlay_lightness", 0,
    "Ligthness (0 - black, 255 - white) of the dim overlay on the non-cropped area"},
  {"draw_mouse", false,
    "Draw the crop crosshair"},
  {"guide_type", "none",
    "Crop guide type. One of: none, grid, center"},
  {"color_invert", false,
    "Use black lines instead of white for the crop frame and crosshair"},
  {"auto_invert", false,
    "Try to check if video is light or dark upon opening crop tool, and invert the colors if necessary"},

  {nil, nil, "Misc options #", true},
  {"disable_keybind", false,
    "Disable the built-in keybind"}
})

-- Read user-given options, if any
script_options:load_options()
