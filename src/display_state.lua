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

  self.scale_mult = 1

  self.screen_ready = false
  self.video_ready = false
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
  local nx = (x - self.bounds.left) * self.scale_mult
  local ny = (y - self.bounds.top ) * self.scale_mult
  return nx, ny
end
-- Turns video-space XY to screen XY
function DisplayState:video_to_screen(x, y)
  local nx = (x / self.scale_mult) + self.bounds.left
  local ny = (y / self.scale_mult) + self.bounds.top

  return nx, ny
end

function DisplayState:recalculate_bounds(forced)
  -- OSD dimensions
  local screen_w, screen_h, screen_aspect = mp.get_osd_size()
  local screen_changed = false

  if (forced or self.screen.width ~= screen_w or self.screen.height ~= screen_h) then
    self.screen.width  = screen_w
    self.screen.height = screen_h
    self.screen.ratio  = screen_w / screen_h

    self.screen_ready = true
    screen_changed = true
  end

  -- Video dimensions
  local vw = mp.get_property_native("dwidth")
  local vh = mp.get_property_native("dheight")

  if (vw and vh) and (forced or (self.video.width ~= vw and self.video.height ~= vh) or screen_changed) then
    self.video.width  = vw
    self.video.height = vh
    self.video.ratio  = vw / vh

    self.scale.y = vh / self.screen.height
    self.scale.x = vw / self.screen.width

    -- Round down for a bit looser matching
    if round_dec(self.screen.ratio, 1) >= round_dec(self.video.ratio, 1) then -- Wide window
      local sw = self.screen.height * self.video.ratio -- The width of the video, on screen
      local left = (self.screen.width - sw) / 2
      self.bounds = {
        left  = left,
        top   = 0,
        right = left + sw,
        bot   = self.screen.height
      }
      self.scale_mult = self.scale.y
    else -- Tall window
      local sh = self.screen.width / self.video.ratio
      local top = (self.screen.height - sh) / 2
      self.bounds = {
        left  = 0,
        top   = top,
        right = self.screen.width,
        bot   = top + sh
      }
      self.scale_mult = self.scale.x
    end

    self.video_ready = true
  end

  return self.screen_ready
end
