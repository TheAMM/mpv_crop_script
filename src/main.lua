function get_output_path(size)
    local filename = mp.get_property_native("filename")
    local playback_time = mp.get_property_native("playback-time")

    local substitution_data = {
      f = filename:match("^(.+)%..+$"),    -- Filename without extension
      X = filename:gsub("^(.+)%..+$", ""), -- Original extension

      D = size,
      p = format_time(playback_time, nil, 0),
      P = format_time(playback_time),

      x = script_options.output_format, -- Output extension
    }

    local output_path = nil
    local output_path_full = nil

    -- Figure out an unique filename
    local unique = 0
    while true do
      if unique == 0 then
        substitution_data.u = ""
        substitution_data.U = ""
      else
        substitution_data.u = "_" .. tostring(unique)
        substitution_data.U = " " .. tostring(unique)
      end

      -- Test if unique value is unique
      local test_path = substitute_values(script_options.output_template, substitution_data)
      -- test_path = test_path:gsub('[<>:"/\\|?*]', '') -- Safe filename
      local test_path = join_paths( output_directory, test_path )

      -- Check for existing files
      if not path_exists(test_path) then
        output_path = test_path
        substitution_data.D = "full"
        output_path_full = substitute_values(script_options.output_template, substitution_data)
        break -- Success!
      else
        unique = unique + 1 -- Try next one
      end
    end

    return output_path, output_path_full
end


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


function screenshot(crop)
  local size = round_dec(crop.w) .. "x" .. round_dec(crop.h)

  -- Bail on bad crop sizes
  if not (crop.w > 0 and crop.h > 0) then
    mp.osd_message("Bad crop (" .. size .. ")!")
    return
  end

  local output_path, fullsize_output_path = get_output_path(size)
  local out = mp.commandv("no-osd", "screenshot-to-file", fullsize_output_path)

  local crop_string = string.format("%d:%d:%d:%d", round_dec(crop.w), round_dec(crop.h), round_dec(crop.x), round_dec(crop.y))
  local cmd = {
    args = {
    "mpv", fullsize_output_path,
    "--vf=crop=" .. crop_string,
    "--frames=1", "--ovc=png",
    "-o", output_path
    }
  }

  utils.subprocess(cmd)
  if not script_options.keep_original then
    os.remove(fullsize_output_path)
  end
  msg.info("Crop finished:", output_path)
  mp.osd_message("Took screenshot (" .. size .. ")")
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
