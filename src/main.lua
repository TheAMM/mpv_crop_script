local last_mask = nil

function script_crop_toggle()
  if assmasker.active then
    return
  elseif asscropper.active then
    asscropper:stop_crop(true)
  else
    local on_crop = function(crop)
      mp.set_osd_ass(0, 0, "")
      screenshot_crop_or_mask(crop, false)
    end
    local on_cancel = function()
      mp.osd_message("Crop canceled")
      mp.set_osd_ass(0, 0, "")
    end

    local crop_options = {
      guide_type = ({none=0, grid=1, center=2})[option_values.guide_type],
      draw_mouse = option_values.draw_mouse,
      color_invert = option_values.color_invert,
      auto_invert = option_values.auto_invert
    }
    asscropper:start_crop(crop_options, on_crop, on_cancel)
    if not asscropper.active then
      mp.osd_message("No video to crop!", 2)
    end
  end
end


function script_mask_toggle()
  if asscropper.active then
    return
  elseif assmasker.active then
    mp.set_osd_ass(0, 0, "")
    assmasker:stop_masking()
  else
    local on_mask = function(mask)
      last_mask = mask
      mp.set_osd_ass(0, 0, "")
      if mask then
        screenshot_crop_or_mask(mask, true)
      end
    end
    local on_cancel = function()
      last_mask = nil
      mp.osd_message("Mask canceled")
      mp.set_osd_ass(0, 0, "")
    end

    assmasker:start_masking(on_mask, on_cancel, last_mask)
    if not assmasker.active then
      mp.osd_message("No video to mask!", 2)
    end
  end
end


local next_tick_time = nil
function on_tick_listener()
  local now = mp.get_time()
  if next_tick_time == nil or now >= next_tick_time then
    if asscropper.active and display_state:recalculate_bounds() then
      mp.set_osd_ass(display_state.screen.width, display_state.screen.height, asscropper:get_render_ass())
    elseif assmasker.active and display_state:recalculate_bounds() then
      mp.set_osd_ass(display_state.screen.width, display_state.screen.height, assmasker:get_render_ass())
    end
    next_tick_time = now + (1/60)
  end
end


function expand_output_path(cropbox)
    local filename = mp.get_property_native("filename")
    local playback_time = mp.get_property_native("playback-time")
    local estimated_frame_count = mp.get_property_native("estimated-frame-count")

    local filename_without_ext, extension = filename:match("^(.+)%.(.-)$")

    local properties = {
      path = mp.get_property_native("path"), -- Original path

      filename = filename_without_ext or filename, -- Filename without extension (or filename if no dots
      file_ext = extension or "",                  -- Original extension without leading dot (or empty string)

      pos = mp.get_property_native("playback-time"),

      full = false,
      is_image = (estimated_frame_count <= 1 and playback_time == 0),

      crop_w = cropbox.w,
      crop_h = cropbox.h,
      crop_x = cropbox.x,
      crop_y = cropbox.y,
      crop_x2 = cropbox.x2,
      crop_y2 = cropbox.y2,

      unique = 0,

      ext = option_values.output_extension
    }
    local propex = PropertyExpander(MPVPropertySource(properties))


    local test_path = propex:expand(option_values.output_template)
    -- If the paths do not change when incrementing the unique, it's not used.
    -- Return early and avoid the endless loop
    properties.unique = 1
    if propex:expand(option_values.output_template) == test_path then
      properties.full = true
      local temporary_screenshot_path = propex:expand(option_values.output_template)
      return test_path, temporary_screenshot_path

    else
      -- Figure out an unique filename
      while true do
        test_path = propex:expand(option_values.output_template)

        -- Check if filename is free
        if not path_exists(test_path) then
          properties.full = true
          local temporary_screenshot_path = propex:expand(option_values.output_template)
          return test_path, temporary_screenshot_path
        else
          -- Try the next one
          properties.unique = properties.unique + 1
        end
      end
    end
end


function screenshot_crop_or_mask(crop_or_mask, is_mask)
  local cropbox = nil

  if not is_mask then
    cropbox = crop_or_mask
  else
    local constrain = function(min, v, max) return math.max(min, math.min(max, math.floor(v))) end

    -- Mask has no areas differing from canvas
    if not crop_or_mask.min_x then
      mp.osd_message("Bad mask (no masked areas!)")
      return
    end

    cropbox = {
      x  = constrain(0, crop_or_mask.min_x_blur, display_state.video.width),
      y  = constrain(0, crop_or_mask.min_y_blur, display_state.video.height),
      x2 = constrain(0, crop_or_mask.max_x_blur, display_state.video.width),
      y2 = constrain(0, crop_or_mask.max_y_blur, display_state.video.height)
    }
    cropbox.w = cropbox.x2 - cropbox.x
    cropbox.h = cropbox.y2 - cropbox.y
  end

  local size = round_dec(cropbox.w) .. "x" .. round_dec(cropbox.h)

  -- Bail on bad crops/masks. Simple check, but better than none
  if not (cropbox.w > 0 and cropbox.h > 0) then
    mp.osd_message("Bad crop (" .. size .. ")!")
    return
  end

  local output_path, temporary_screenshot_path = expand_output_path(cropbox)

  -- Optionally create directories
  if option_values.create_directories then
    local paths = {}
    paths[1] = path_utils.dirname(output_path)
    paths[2] = path_utils.dirname(temporary_screenshot_path)

    -- Check if we can read the paths
    for i, path in ipairs(paths) do
      local l, err = utils.readdir(path)
      if err then
        create_directories(path)
      end
    end
  end

  local playback_time = mp.get_property_native("playback-time")
  local estimated_frame_count = mp.get_property_native("estimated-frame-count")

  local input_path = nil

  if option_values.skip_screenshot_for_images and estimated_frame_count <= 1 and playback_time == 0 then
    -- Seems to be an image (or at least static file)
    input_path = mp.get_property_native("path")
    temporary_screenshot_path = nil
  else
    -- Not an image, take a temporary screenshot

    -- In case the full-size output path is identical to the crop path,
    -- crudely make it different
    if temporary_screenshot_path == output_path then
      temporary_screenshot_path = temporary_screenshot_path .. "_full.png"
    end

    -- Temporarily lower the PNG compression
    local previous_png_compression = mp.get_property_native("screenshot-png-compression")
    mp.set_property_native("screenshot-png-compression", 0)
    -- Take the screenshot
    mp.commandv("raw", "no-osd", "screenshot-to-file", temporary_screenshot_path)
    -- Return the previous value
    mp.set_property_native("screenshot-png-compression", previous_png_compression)

    if not path_exists(temporary_screenshot_path) then
      msg.error("Failed to take screenshot: " .. temporary_screenshot_path)
      mp.osd_message("Unable to save screenshot")
      return
    end

    input_path = temporary_screenshot_path
  end

  local mask_path = ("%s_mask.png"):format(
    temporary_screenshot_path or path_utils.expanduser(('~~temp/mpv_crop_script_%d'):format(os.time()))
  )

  if is_mask then
    local video_params = mp.get_property_native('video-params')
    if crop_or_mask.inverted then
      cropbox = {x=0, y=0, w=video_params.w, h=video_params.h}
    end
    crop_or_mask:render_to_file(video_params.w, video_params.h, mask_path)
  end

  local cmd = {
    args = {
    "mpv", input_path,
    "--no-config",
    ("--vf=crop=%d:%d:%d:%d"):format(cropbox.w, cropbox.h, cropbox.x, cropbox.y),
    "--frames=1",
    "--ovc=" .. option_values.output_format,
    "-o", output_path
    }
  }

  if is_mask then
    cmd.args[#cmd.args+1] = ("--lavfi-complex=movie='%s':loop=0 [a]; [vid1][a] alphamerge, format=rgba [vo]"):format(
      mask_path:gsub('\\', '\\\\'):gsub(':', '\\:')
    )
  end

  msg.debug("Processing screenshot: ", utils.to_string(cmd.args))
  local ret = utils.subprocess(cmd)

  if is_mask then
    os.remove(mask_path)
  end

  if not option_values.keep_original and temporary_screenshot_path then
    os.remove(temporary_screenshot_path)
  end

  if ret.error or ret.status ~= 0 then
    mp.osd_message("Screenshot failed, see console for details")
    msg.error("Crop failed! mpv exit code: " .. tostring(ret.status))
    msg.error("mpv stdout:")
    msg.error(ret.stdout)
  else
    msg.info("Crop finished!")
    mp.osd_message("Screenshot taken:\n" .. path_utils.basename(output_path))
    end
end


----------------------
-- Instances, binds --
----------------------

-- Sanity-check output_template
if option_values.warn_about_template and not option_values.output_template:find('%${ext}') then
  msg.warn("Output template missing ${ext}! If this is desired, set warn_about_template=yes in config!")
end

-- Short list of extensions for encoders
local ENCODER_EXTENSION_MAP = {
  png      = "png",
  mjpeg    = "jpg",
  targa    = "tga",
  tiff     = "tiff",
  gif      = "gif", -- please don't
  bmp      = "bmp",
  jpegls   = "jpg",
  ljpeg    = "jpg",
  jpeg2000 = "jp2",
}
-- Pick an extension if one was not provided
if option_values.output_extension == "" then
  local extension = ENCODER_EXTENSION_MAP[option_values.output_format]
  if not extension then
    msg.error("Unrecognized output format '" .. option_values.output_format .. "', unable to pick an extension! Bailing!")
    mp.osd_message("mpv_crop_script was unable to choose an extension, check your config", 3)
  end
  option_values.output_extension = extension
end


display_state = DisplayState()
asscropper = ASSCropper(display_state)
asscropper.overlay_transparency = option_values.overlay_transparency
asscropper.overlay_lightness = option_values.overlay_lightness

assmasker = ASSMasker(display_state)

assmasker.tick_callback  = on_tick_listener
asscropper.tick_callback = on_tick_listener
mp.register_event("tick", on_tick_listener)

local used_crop_bind = SCRIPT_CROP_KEYBIND
local used_mask_bind = SCRIPT_MASK_KEYBIND

-- Disable the default keybind if asked to
if option_values.disable_keybind then
  used_crop_bind = nil
  used_mask_bind = nil
end

mp.add_key_binding(used_crop_bind, SCRIPT_CROP, script_crop_toggle)
mp.add_key_binding(used_mask_bind, SCRIPT_MASK, script_mask_toggle)
