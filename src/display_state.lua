local DisplayState = {}
DisplayState.__index = DisplayState

setmetatable(DisplayState, {
  __call = function (cls, ...) return cls.new(...) end
})

function DisplayState.new()
  local self = setmetatable({}, DisplayState)

  self:reset()

  return self
end

function DisplayState:reset()
  self.screen = {} -- Display (window, fullscreen) size
  self.video  = {} -- Video size
  self.scale  = {} -- video / screen
  self.bounds = {} -- Video rect within display

  self.screen_ready = false
  self.video_ready = false

  -- Stores internal display state (panscan, align, zoom etc)
  self.current_state = nil
end

function DisplayState:setup_events()
  mp.register_event("file-loaded", function() self:event_file_loaded() end)
end

function DisplayState:event_file_loaded()
  self:reset()
  self:recalculate_bounds(true)
end

-- Turns screen-space XY to video XY (can go negative)
function DisplayState:screen_to_video(x, y)
  local nx = (x - self.bounds.left) * self.scale.x
  local ny = (y - self.bounds.top ) * self.scale.y
  return nx, ny
end

-- Turns video-space XY to screen XY
function DisplayState:video_to_screen(x, y)
  local nx = (x / self.scale.x) + self.bounds.left
  local ny = (y / self.scale.y) + self.bounds.top
  return nx, ny
end

function DisplayState:_collect_display_state()
  local screen_w, screen_h, screen_aspect = mp.get_osd_size()

  local state = {
    screen_w = screen_w,
    screen_h = screen_h,
    screen_aspect = screen_aspect,

    video_w = mp.get_property_native("dwidth"),
    video_h = mp.get_property_native("dheight"),

    video_w_raw = mp.get_property_native("video-out-params/w"),
    video_h_raw = mp.get_property_native("video-out-params/h"),

    panscan = mp.get_property_native("panscan"),
    video_zoom = mp.get_property_native("video-zoom"),
    video_unscaled = mp.get_property_native("video-unscaled"),

    video_align_x = mp.get_property_native("video-align-x"),
    video_align_y = mp.get_property_native("video-align-y"),

    video_pan_x = mp.get_property_native("video-pan-x"),
    video_pan_y = mp.get_property_native("video-pan-y"),

    fullscreen = mp.get_property_native("fullscreen"),
    keepaspect = mp.get_property_native("keepaspect"),
    keepaspect_window = mp.get_property_native("keepaspect-window")
  }

  return state
end

function DisplayState:_state_changed(state)
  if self.current_state == nil then return true end

  for k in pairs(state) do
    if state[k] ~= self.current_state[k] then return true end
  end
  return false
end


function DisplayState:recalculate_bounds(forced)
  local new_state = self:_collect_display_state()
  if not (forced or self:_state_changed(new_state)) then
    -- Early out
    return self.screen_ready
  end
  self.current_state = new_state

  -- Store screen dimensions
  self.screen.width  = new_state.screen_w
  self.screen.height = new_state.screen_h
  self.screen.ratio  = new_state.screen_w / new_state.screen_h
  self.screen_ready = true

  -- Video dimensions
  if new_state.video_w and new_state.video_h then
    self.video.width  = new_state.video_w
    self.video.height = new_state.video_h
    self.video.ratio  = new_state.video_w / new_state.video_h

    -- This magic has been adapted from mpv's own video/out/aspect.c

    if new_state.keepaspect then
      local scaled_w, scaled_h = self:_aspect_calc_panscan(new_state)
      local video_left, video_right = self:_split_scaling(new_state.screen_w, scaled_w, new_state.video_zoom, new_state.video_align_x, new_state.video_pan_x)
      local video_top, video_bottom = self:_split_scaling(new_state.screen_h, scaled_h, new_state.video_zoom, new_state.video_align_y, new_state.video_pan_y)
      self.bounds = {
        left = video_left,
        right = video_right,

        top = video_top,
        bottom = video_bottom,

        width = video_right - video_left,
        height = video_bottom - video_top,
      }
    else
      self.bounds = {
        left = 0,
        top = 0,
        right = self.screen.width,
        bottom = self.screen.height,

        width = self.screen.width,
        height = self.screen.height,
      }
    end

    self.scale.x = new_state.video_w_raw / self.bounds.width
    self.scale.y = new_state.video_h_raw / self.bounds.height

    self.video_ready = true
  end

  return self.screen_ready
end


function DisplayState:_aspect_calc_panscan(state)
  -- From video/out/aspect.c
  local f_width = state.screen_w
  local f_height = (state.screen_w / state.video_w) * state.video_h

  if f_height > state.screen_h or f_height < state.video_h_raw then
    local tmp_w = (state.screen_h / state.video_h) * state.video_w
    if tmp_w <= state.screen_w then
      f_height = state.screen_h
      f_width = tmp_w
    end
  end

  local vo_panscan_area = state.screen_h - f_height

  local f_w = f_width / f_height
  local f_h = 1
  if (vo_panscan_area == 0) then
    vo_panscan_area = state.screen_w - f_width
    f_w = 1
    f_h = f_height / f_width
  end

  if state.video_unscaled then
    vo_panscan_area = 0
    if state.video_unscaled ~= "downscale-big" or ((state.video_w <= state.screen_w) and (state.video_h <= state.screen_h)) then
      f_width = state.video_w
      f_height = state.video_h
    end
  end

  local scaled_w = math.floor( f_width + vo_panscan_area * state.panscan * f_w )
  local scaled_h = math.floor( f_height + vo_panscan_area * state.panscan * f_h )
  return scaled_w, scaled_h
end

function DisplayState:_split_scaling(dst_size, scaled_src_size, zoom, align, pan)
  -- From video/out/aspect.c as well
  scaled_src_size = math.floor(scaled_src_size * 2^zoom)
  align = (align + 1) / 2

  local dst_start = (dst_size - scaled_src_size) * align + pan * scaled_src_size
  local dst_end = dst_start + scaled_src_size

  -- We don't actually want these - we want to go out of bounds!
  -- dst_start = math.max(0, dst_start)
  -- dst_end = math.min(dst_size, dst_end)

  return math.floor(dst_start), math.floor(dst_end)
end
