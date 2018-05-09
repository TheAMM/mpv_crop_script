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
  {"output_template", "${filename} ${#pos:%02h.%02m.%06.3s} ${!full:${crop_w}x${crop_h} ${%unique:%03d}}.${ext}",
    "Filename output template. See README.md for property expansion documentation."},
  {nil, nil, [[Script-provided properties:
  filename    - filename without extension
  file_ext    - original extension without leading dot
  path        - original file path
  pos         - playback time
  ext         - output file extension without leading dot
  crop_w      - crop width
  crop_h      - crop height
  crop_x      - left
  crop_y      - top
  crop_x2     - right
  crop_y2     - bottom
  full        - boolean denoting a full (temporary) screenshot instead of crop
  is_image    - boolean denoting the source file is likely an image (zero duration and position)
  unique      - counter that will increase per each existing filename, until a unique name is found]]},

  {"output_format", "png",
    "Format (encoder) to save final crops in. For example, png, mjpeg, targa, bmp"},
  {"output_extension", "",
    "Output extension. Leave blank to try to choose from the encoder (if supported)"},

  {"create_directories", false,
    "Whether to create the directories in the final output path (defined by output_template)"},
  {"skip_screenshot_for_images", true,
    "If the current file is an image, skip taking a temporary screenshot and crop the image directly"},
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
  {"warn_about_template", true,
    "Warn about output_template missing ${ext}, to ensure the extension is not missing"},
  {"disable_keybind", false,
    "Disable the built-in keybind"}
})

-- Read user-given options, if any
script_options:load_options()
