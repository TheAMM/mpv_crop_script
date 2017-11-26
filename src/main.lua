function script_crop_toggle()
  if asscropper.active then
    asscropper:stop_crop(true)
  else
    local on_crop = function(crop)
      mp.set_osd_ass(0, 0, "")
      screenshot(crop)
    end
    local on_cancel = function()
      mp.osd_message("Crop canceled")
      mp.set_osd_ass(0, 0, "")
    end

    asscropper:start_crop(nil, on_crop, on_cancel)
    if not asscropper.active then
      mp.osd_message("No video to crop!", 2)
    end
  end
end


function on_tick_listener()
  if asscropper.active and display_state:recalculate_bounds() then
    mp.set_osd_ass(display_state.screen.width, display_state.screen.height, asscropper:get_render_ass())
  end
end


function expand_output_path(cropbox)
    local filename = mp.get_property_native("filename")
    local playback_time = mp.get_property_native("playback-time")

    local properties = {
      path = mp.get_property_native("path"), -- Original path

      filename = filename:match("^(.+)%..+$"), -- Filename without extension
      file_ext = filename:gsub("^(.+)%..+$", ""), -- Original extension with leading dot

      pos = mp.get_property_native("playback-time"),

      full = false,

      crop_w = cropbox.w,
      crop_h = cropbox.h,
      crop_x = cropbox.x,
      crop_y = cropbox.y,
      crop_x2 = cropbox.x2,
      crop_y2 = cropbox.y2,

      unique = 0,

      ext = script_options.output_format
    }
    local propex = PropertyExpander(MPVPropertySource(properties))


    local test_path = propex:expand(script_options.output_template)
    -- If the paths do not change when incrementing the unique, it's not used.
    -- Return early and avoid the endless loop
    properties.unique = 1
    if propex:expand(script_options.output_template) == test_path then
      properties.full = true
      local output_path_full = propex:expand(script_options.output_template)
      return test_path, output_path_full

    else
      -- Figure out an unique filename
      while true do
        test_path = propex:expand(script_options.output_template)

        -- Check if filename is free
        if not path_exists(test_path) then
          properties.full = true
          local output_path_full = propex:expand(script_options.output_template)
          return test_path, output_path_full
        else
          -- Try the next one
          properties.unique = properties.unique + 1
        end
      end
    end
end


function screenshot(crop)
  local size = round_dec(crop.w) .. "x" .. round_dec(crop.h)

  -- Bail on bad crop sizes
  if not (crop.w > 0 and crop.h > 0) then
    mp.osd_message("Bad crop (" .. size .. ")!")
    return
  end

  local output_path, output_path_full = expand_output_path(crop)

  -- Optionally create directories
  if script_options.create_directories then
    local paths = {}
    paths[1] = split_path(output_path)
    paths[2] = split_path(output_path_full)

    -- Check if we can read the paths
    for i, path in ipairs(paths) do
      local l, err = utils.readdir(path)
      if err then
        create_directories(path)
      end
    end
  end

  -- In case the full-size output path is identical to the crop path,
  -- crudely make it different
  if output_path_full == output_path then
    output_path_full = output_path_full .. "_full.png"
  end

  -- Temporarily lower the PNG compression
  local previous_png_compression = mp.get_property_native("screenshot-png-compression")
  mp.set_property_native("screenshot-png-compression", 0)
  -- Take the screenshot
  mp.commandv("raw", "no-osd", "screenshot-to-file", output_path_full)
  -- Return the previous value
  mp.set_property_native("screenshot-png-compression", previous_png_compression)

  if not path_exists(output_path_full) then
    msg.error("Failed to take screenshot: " .. output_path_full)
    mp.osd_message("Unable to save screenshot")
    return
  end

  local crop_string = string.format("%d:%d:%d:%d", crop.w, crop.h, crop.x, crop.y)
  local cmd = {
    args = {
    "mpv", output_path_full,
    "--vf=crop=" .. crop_string,
    "--frames=1", "--ovc=png",
    "-o", output_path
    }
  }

  local ret = utils.subprocess(cmd)

  if not script_options.keep_original then
    os.remove(output_path_full)
  end

  if ret.error or ret.status ~= 0 then
    mp.osd_message("Screenshot failed, see console for details")
    msg.error("Crop failed! Status: " .. tostring(ret.status))
    msg.error(ret.stdout)
  else
    msg.info("Crop finished:", output_path)
    mp.osd_message("Took screenshot (" .. size .. ")")
    end
end

----------------------
-- Instances, binds --
----------------------

display_state = DisplayState()
asscropper = ASSCropper(display_state)

mp.register_event("tick", on_tick_listener)

local used_keybind = SCRIPT_KEYBIND
-- Disable the default keybind if asked to
if script_options.disable_keybind then
  used_keybind = nil
end
mp.add_key_binding(used_keybind, SCRIPT_HANDLER, script_crop_toggle)
