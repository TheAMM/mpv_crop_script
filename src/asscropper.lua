local ASSCropper = {}
ASSCropper.__index = ASSCropper

setmetatable(ASSCropper, {
  __call = function (cls, ...) return cls.new(...) end
})

function ASSCropper.new(display_state)
  local self = setmetatable({}, ASSCropper)
  self.MOUSE_EVENT = mp.get_script_name() .. "_asscropper_mouse"

  self.display_state = display_state

  self.corner_size = 40
  self.corner_required_size = self.corner_size * 3

  self.default_options = {
    even_dimensions = false,
    draw_guides = false,
    draw_mouse = false,
    draw_help = true
  }
  self.options = default_options

  self.active = false

  self.mouse_screen = {x=0, y=0}
  self.mouse_video  = {x=0, y=0}

  self.current_crop = nil

  self.dragging = 0
  self.drag_start = {x=0, y=0}
  self.restrict_ratio = false

  local listeners = {
    {"mouse_move", function()  self:update_mouse_position() end },
    {"mouse_btn0", function(e) self:on_mouse("mouse_btn0", false) end, function(e) self:on_mouse("mouse_btn0", true) end},
    {"shift+mouse_btn0", function(e) self:on_mouse("mouse_btn0", false, true) end, function(e) self:on_mouse("mouse_btn0", true, true) end},
    {"c", function() self:key_event("CROSSHAIR") end },
    {"x", function() self:key_event("GUIDES") end },
    {"ENTER", function() self:key_event("ENTER") end },
    {"ESC", function() self:key_event("ESC") end }
  }
  mp.set_key_bindings(listeners, self.MOUSE_EVENT, "force")

  return self
end


function ASSCropper:enable_key_bindings()
  mp.enable_key_bindings(self.MOUSE_EVENT)
end

function ASSCropper:disable_key_bindings()
  mp.disable_key_bindings(self.MOUSE_EVENT)
end


function ASSCropper:finalize_crop()
  if self.current_crop ~= nil then
    local x1, x2 = self.current_crop[1].x, self.current_crop[2].x
    local y1, y2 = self.current_crop[1].y, self.current_crop[2].y

    self.current_crop.x, self.current_crop.y = x1, y1
    self.current_crop.w, self.current_crop.h = x2 - x1, y2 -y1

    self.current_crop.x1, self.current_crop.x2 = x1, x2
    self.current_crop.y1, self.current_crop.y2 = y1, y2
  end
end


function ASSCropper:key_event(name)
  if name == "ENTER" then
    self:stop_crop(false)

    self:finalize_crop()

    if self.callback_on_crop == nil then
      mp.set_osd_ass(0,0, "")
    else
      self.callback_on_crop(self.current_crop)
    end

  elseif name == "ESC" then
    self:stop_crop(true)

    if self.callback_on_cancel == nil then
      mp.set_osd_ass(0,0, "")
    else
      self.callback_on_cancel()
    end

  elseif name == "CROSSHAIR" then
    self.options.draw_mouse = not self.options.draw_mouse;
  elseif name == "GUIDES" then
    self.options.draw_guides = not self.options.draw_guides;
  end
end


function ASSCropper:start_crop(options, on_crop, on_cancel)
  -- Refresh display state
  self.display_state:recalculate_bounds(true)
  if self.display_state.video_ready then
    self.active = true

    self.options = {}

    for k, v in pairs(self.default_options) do
      self.options[k] = v
    end
    for k, v in pairs(options or {}) do
      self.options[k] = v
    end

    self.callback_on_crop = on_crop
    self.callback_on_cancel = on_cancel

    self.dragging = 0

    self:enable_key_bindings()
    self:update_mouse_position()
  end
end

function ASSCropper:stop_crop(clear)
  self.active = false

  self:disable_key_bindings()
  if clear then
    self.current_crop = nil
  end
end


function ASSCropper:on_tick()
  -- Unused, for debugging
  if self.active then
    self.display_state:recalculate_bounds()
    self:render()
  end
end


function ASSCropper:update_mouse_position()
  -- These are real on-screen coords.
  self.mouse_screen.x, self.mouse_screen.y = mp.get_mouse_pos()

  if self.display_state:recalculate_bounds() and self.display_state.video_ready then
    -- These are on-video coords.
    local mx, my = self.display_state:screen_to_video(self.mouse_screen.x, self.mouse_screen.y)
    self.mouse_video.x = mx
    self.mouse_video.y = my
  end

end


function ASSCropper:get_hitboxes(crop_box)
  crop_box = crop_box or self.current_crop
  if crop_box == nil then
    return nil
  end

  local x1, x2 = order_pair(crop_box[1].x, crop_box[2].x)
  local y1, y2 = order_pair(crop_box[1].y, crop_box[2].y)
  local w, h = math.abs(x2 - x1), math.abs(y2 - y1)

  -- Corner and required corner size in videospace pixels
  local videospace_corner_size = self.corner_size * self.display_state.scale_mult
  local videospace_required_size = self.corner_required_size * self.display_state.scale_mult

  local handles_outside = (math.min(w, h) <= videospace_required_size)

  local hitbox_bases = {
    { x1, y2, x1, y2 }, -- BL
    { x1, y2, x2, y2 }, -- B
    { x2, y2, x2, y2 }, -- BR

    { x1, y1, x1, y2 }, -- L
    { x1, y1, x2, y2 }, -- Center
    { x2, y1, x2, y2 }, -- R

    { x1, y1, x1, y1 }, -- TL
    { x1, y1, x2, y1 }, -- T
    { x2, y1, x2, y1 }  -- TR
  }

  local hitbox_mults
  if handles_outside then
    hitbox_mults = {
      {-1,  0,  0,  1},
      { 0,  0,  0,  1},
      { 0,  0,  1,  1},

      {-1,  0,  0,  0},
      { 0,  0,  0,  0},
      { 0,  0,  1,  0},

      {-1, -1,  0,  0},
      { 0, -1,  0,  0},
      { 0, -1,  1,  0}
    }

  else
    hitbox_mults = {
      { 0, -1,  1,  0},
      { 1, -1, -1,  0},
      {-1, -1,  0,  0},

      { 0,  1,  1, -1},
      { 1,  1, -1, -1},
      {-1,  1,  0, -1},

      { 0,  0,  1,  1},
      { 1,  0, -1,  1},
      {-1,  0,  0,  1}
    }
  end


  local hitboxes = {}
  for index, hitbox_base in ipairs(hitbox_bases) do
    local hitbox_mult = hitbox_mults[index]

    hitboxes[index] = {
      hitbox_base[1] + hitbox_mult[1] * videospace_corner_size,
      hitbox_base[2] + hitbox_mult[2] * videospace_corner_size,
      hitbox_base[3] + hitbox_mult[3] * videospace_corner_size,
      hitbox_base[4] + hitbox_mult[4] * videospace_corner_size
    }
  end
  -- Pseudobox to easily pass the original crop box
  hitboxes[10] = {x1, y1, x2, y2}

  return hitboxes
end


function ASSCropper:hit_test(hitboxes, position)
  if hitboxes == nil then
    return 0

  else
    local px, py = position.x, position.y

    for i = 1,9 do
      local hb = hitboxes[i]

      if (px >= hb[1] and px < hb[3]) and (py >= hb[2] and py < hb[4]) then
        return i
      end

    end
    -- No hits
    return 0
  end
end


function ASSCropper:on_mouse(button, mouse_down, shift_down)
  mouse_down = mouse_down or false
  shift_down = shift_down or false

  if button == "mouse_btn0" and self.active then

    local mouse_pos = {x=self.mouse_video.x, y=self.mouse_video.y}

    -- Helpers
    local xy_same = function(a, b) return a.x == b.x and a.y == b.y end
    local xy_distance = function(a, b)
      local dx = a.x - b.x
      local dy = a.y - b.y
      return math.sqrt( dx*dx + dy*dy )
    end
    --

    if mouse_down then -- Mouse pressed

      local bound_mouse_pos = {
        x = math.max(0, math.min(self.display_state.video.width, mouse_pos.x)),
        y = math.max(0, math.min(self.display_state.video.height, mouse_pos.y)),
      }

      if self.current_crop == nil then
        self.current_crop = { bound_mouse_pos, bound_mouse_pos }

        self.dragging = 3
        self.anchor_pos = {bound_mouse_pos.x, bound_mouse_pos.y}

        self.crop_ratio = 1
        self.drag_start = bound_mouse_pos

        local handle_pos = self:_get_anchor_positions()[hit]
        self.drag_offset = {0, 0}

        self.restrict_ratio = shift_down

      elseif self.dragging == 0 then
        -- Check if we drag from a handle
        local hitboxes = self:get_hitboxes()
        local hit = self:hit_test(hitboxes, mouse_pos)

        self.dragging = hit
        self.anchor_pos = self:_get_anchor_positions()[10 - hit]

        self.crop_ratio = (hitboxes[10][3] - hitboxes[10][1]) / (hitboxes[10][4] - hitboxes[10][2])
        self.drag_start = mouse_pos

        local handle_pos = self:_get_anchor_positions()[hit] or {mouse_pos.x, mouse_pos.y}
        self.drag_offset = { mouse_pos.x - handle_pos[1], mouse_pos.y - handle_pos[2]}

        self.restrict_ratio = shift_down

        -- Start a new drag if not on handle
        if self.dragging == 0 then
          self.current_crop = { bound_mouse_pos, bound_mouse_pos }
          self.crop_ratio = 1

          self.dragging = 3
          self.anchor_pos = {bound_mouse_pos.x, bound_mouse_pos.y}
          -- self.drag_start = mouse_pos
        end
      end

    else -- Mouse released

      if xy_same(self.current_crop[1], self.current_crop[2]) and xy_distance(self.current_crop[1], mouse_pos) < 5 then
        -- Mouse released after first click - ignore

      elseif self.dragging > 0 then
        -- Adjust current crop
        self.current_crop = self:offset_crop_by_drag()
        self.dragging = 0
      end
    end

  end
end


function ASSCropper:_get_anchor_positions()
  local x1, y1 = self.current_crop[1].x, self.current_crop[1].y
  local x2, y2 = self.current_crop[2].x, self.current_crop[2].y
  return {
    [1] = {x1, y2},
    [2] = {(x1+x2)/2, y2},
    [3] = {x2, y2},

    [4] = {x1, (y1+y2)/2},
    [5] = {(x1+x2)/2, (y1+y2)/2},
    [6] = {x2, (y1+y2)/2},

    [7] = {x1, y1},
    [8] = {(x1+x2)/2, y1},
    [9] = {x2, y1},
  }
end


function ASSCropper:offset_crop_by_drag()
  local vw, vh = self.display_state.video.width, self.display_state.video.height
  local mx, my = self.mouse_video.x, self.mouse_video.y

  local x1, x2 = self.current_crop[1].x, self.current_crop[2].x
  local y1, y2 = self.current_crop[1].y, self.current_crop[2].y

  local anchor_positions = self:_get_anchor_positions()

  local handle = self.dragging
  if self.dragging > 0 then
    local ax, ay = self.anchor_pos[1], self.anchor_pos[2]

    local ox, oy = self.drag_offset[1], self.drag_offset[2]

    local dx, dy = mx - ax - ox, my - ay - oy

    -- Select active corner
    if handle % 2 == 1 and handle ~= 5 then -- Change corners 4/6, 2/8
      handle = (mx - ox < ax) and 1 or 3
      handle = handle +  ( (my - oy < ay) and 6 or 0)
    else -- Change edges 1, 3, 7, 9
      if handle == 4 and mx - ox > ax then
        handle = 6
      elseif handle == 6 and mx - ox < ax then
        handle = 4
      elseif handle == 2 and my - oy < ay then
        handle = 8
      elseif handle == 8 and my - oy > ay then
        handle = 2
      end
    end

    -- Handle booleans for logic
    local h_bot = handle >= 1 and handle <= 3
    local h_top = handle >= 7 and handle <= 9
    local h_left = (handle - 1) % 3 == 0
    local h_right = handle % 3 == 0

    local h_horiz = handle == 4 or handle == 6
    local h_vert = handle == 2 or handle == 8

    -- Keep rect aspect ratio
    if self.restrict_ratio then
      local adx, ady = math.abs(dx), math.abs(dy)

      -- Fit rect to mouse
      local tmpy = adx / self.crop_ratio
      if tmpy < ady then
        adx = ady * self.crop_ratio
      else
        ady = tmpy
      end

      -- Figure out max size for corners, limit adx/ady
      local max_w, max_h = vw, vh

      if h_bot then
        max_h = vh - ay -- Max height is from anchor to video bottom
      elseif h_top then
        max_h = ay      -- Max height is from video bottom to anchor
      elseif h_horiz then
        -- Max height is closest edge * 2
        max_h = math.min(vh - ay, ay) * 2
      end

      if h_left then
        max_w = ax
      elseif h_right then
        max_w = vw - ax
      elseif h_vert then
        max_w = math.min(vw - ax, ax) * 2
      end

      -- Limit size to corners
      if handle ~= 5 then
        -- TODO this can be done tidier?

        -- If wider than max width, scale down
        if adx > max_w then
          adx = max_w
          ady = adx / self.crop_ratio
        end
        -- If taller than max height, scale down
        if ady > max_h then
          ady = max_h
          adx = ady * self.crop_ratio
        end
      end

      -- Hacky offsets
      if handle == 1 then
        dx = -adx
        dy = ady
      elseif handle == 2 then
          dx = adx
        dy = ady
      elseif handle == 3 then
        dx = adx
        dy = ady

      elseif handle == 4 then
        dx = -adx
          dy = ady
      elseif handle == 5 then
        -- pass
      elseif handle == 6 then
        dx = adx
          dy = ady

      elseif handle == 7 then
        dy = -ady
        dx = -adx
      elseif handle == 8 then
          dx = adx
        dy = -ady
      elseif handle == 9 then
        dx = adx
        dy = -ady
      end
    end

    -- Can this be done not-manually?
    -- Re-create the rect with some corners anchored etc
    if handle == 5 then
      -- Simply move the box around
      x1, x2 = x1+dx, x2+dx
      y1, y2 = y1+dy, y2+dy

    elseif handle == 1 then
      x1, x2 = ax + dx, ax
      y1, y2 = ay, ay+dy

    elseif handle == 2 then
      y1, y2 = ay, ay + dy

      if self.restrict_ratio then
        x1, x2 = ax - dx/2, ax + dx/2
      end

    elseif handle == 3 then
      x1, x2 = ax, ax + dx
      y1, y2 = ay, ay + dy

    elseif handle == 4 then
      x1, x2 = ax + dx, ax

      if self.restrict_ratio then
        y1, y2 = ay - dy/2, ay + dy/2
      end

    elseif handle == 6 then
      x1, x2 = ax, ax + dx

      if self.restrict_ratio then
        y1, y2 = ay - dy/2, ay + dy/2
      end


    elseif handle == 7 then
      x1, x2 = ax + dx, ax
      y1, y2 = ay + dy, ay

    elseif handle == 8 then
      y1, y2 = ay + dy, ay

      if self.restrict_ratio then
        x1, x2 = ax - dx/2, ax + dx/2
      end

    elseif handle == 9 then
      x1, x2 = ax, ax + dx
      y1, y2 = ay + dy, ay
    end


    if self.dragging == 5 then
      -- On moving the entire box, we have to figure out how much to "offset" every corner if we go over the edge
      local x_min = math.max(0, 0-x1)
      local y_min = math.max(0, 0-y1)

      local x_max = math.max(0, x2-vw)
      local y_max = math.max(0, y2-vh)

      x1 = x1 + x_min - x_max
      y1 = y1 + y_min - y_max
      x2 = x2 + x_min - x_max
      y2 = y2 + y_min - y_max
    elseif not self.restrict_ratio then
      -- This is already done for restricted ratios, hence the if

      -- Constrict the crop to video space
      -- Since one corner/edge is moved at a time, we can just minmax this
      x1, x2 = math.max(0, x1), math.min(vw, x2)
      y1, y2 = math.max(0, y1), math.min(vh, y2)
    end
  end -- /drag

  if self.dragging > 0 and self.options.even_dimensions then
    local w, h = x2 - x1, y2 - y1
    local even_w = w - (w % 2)
    local even_h = h - (h % 2)

    if handle == 1 or handle == 2 or handle == 3 then
      y2 = y1 + even_h
    elseif handle == 7 or handle == 8 or handle == 9 then
      y1 = y2 - even_h
    end
    if handle == 1 or handle == 4 or handle == 7 then
      x1 = x2 - even_w
    elseif handle == 3 or handle == 6 or handle == 9 then
      x2 = x1 + even_w
    end
  end

  local fx1, fx2 = order_pair(math.floor(x1), math.floor(x2))
  local fy1, fy2 = order_pair(math.floor(y1), math.floor(y2))

  -- msg.info(fx1, fy1, fx2, fy2, handle)

  return { {x=fx1, y=fy1}, {x=fx2, y=fy2} }, handle
end


function order_pair( a, b )
  if a < b then
    return a, b
  else
    return b, a
  end
end


function ASSCropper:render()
  -- For debugging
  local ass_txt = self:get_render_ass()

  local ds = self.display_state
  mp.set_osd_ass(ds.screen.width, ds.screen.height, ass_txt)
end


function ASSCropper:get_render_ass(dim_only)
  if not self.display_state.video_ready then
    msg.info("No video info on display_state")
    return ""
  end

  local dasldkjasjlda = string.format("{\\3a&HFF&\\3a&H%02X&\\3c&H%02X%02X%02X&\\bord1}", 128, 180, 180, 180)

  ass = assdraw.ass_new()
  if self.current_crop then
    local temp_crop, drawn_handle = self:offset_crop_by_drag()
    local v_hb = self:get_hitboxes(temp_crop)
    -- Map coords to screen
    local s_hb = {}
    for index, coords in pairs(v_hb) do
      local x1, y1 = self.display_state:video_to_screen(coords[1], coords[2])
      local x2, y2 = self.display_state:video_to_screen(coords[3], coords[4])
      s_hb[index] = {x1, y1, x2, y2}
    end

    -- Full crop
    local v_crop = v_hb[10] -- Video-space
    local s_crop = s_hb[10] -- Screen-space


    -- Inverse clipping for the crop box
    ass:new_event()
    ass:append(string.format("{\\iclip(%d,%d,%d,%d)}", s_crop[1], s_crop[2], s_crop[3], s_crop[4]))

    -- Dim overlay
    local format_dim = string.format("{\\bord0\\1a&H%02X&\\1c&H%02X%02X%02X&}", 160, 0, 0, 0)
    ass:pos(0,0)
    ass:draw_start()
    ass:append(format_dim)
    ass:rect_cw(0, 0, self.display_state.screen.width, self.display_state.screen.height)
    ass:draw_stop()

    if dim_only then -- Early out with just the dim outline
      return ass.text
    end

    if draw_text then
      -- Text on end
      ass:new_event()
      ass:pos(ce_x, ce_y)
      -- Text align
      local txt_a = ((ce_x > cs_x) and 3 or 1) + ((ce_y > cs_y) and 0 or 6)
      ass:an( txt_a )
      ass:append("{\\fs20\\shad0\\be0\\bord2}")
      ass:append(string.format("%dx%d", math.abs(ce_x-cs_x), math.abs(ce_y-cs_y)) )
    end


    local fmt_string = string.format("{\\1a&HFF&\\3a&H%02X&\\3c&H%02X%02X%02X&\\bord1}", 0, 180, 180, 180)
    local fmt_handle_hover = string.format("{\\1a&H%02X&\\3a&H%02X&\\3c&H%02X%02X%02X&\\bord0}", 230, 0, 180, 180, 180)
    local fmt_drag = string.format("{\\1a&H%02X&\\3a&H%02X&\\3c&H%02X%02X%02X&\\bord1}", 200, 0, 180, 180, 180)

    -- Main crop box
    ass:new_event()
    ass:pos(0,0)
    ass:append( fmt_string )
    ass:draw_start()
    ass:rect_cw(s_crop[1], s_crop[2], s_crop[3], s_crop[4])
    ass:draw_stop()

    -- Guide grid, 3x3
    if self.options.draw_guides then
      local w_3rd =  ( (s_crop[3] - s_crop[1]) / 3 )
      local h_3rd =  ( (s_crop[4] - s_crop[2]) / 3 )
      ass:new_event()
      ass:pos(0,0)
      ass:append( dasldkjasjlda )
      ass:draw_start()

      ass:move_to(s_crop[1] + w_3rd, s_crop[2])
      ass:line_to(s_crop[1] + w_3rd, s_crop[4])

      ass:move_to(s_crop[1] + w_3rd*2, s_crop[2])
      ass:line_to(s_crop[1] + w_3rd*2, s_crop[4])

      ass:move_to(s_crop[1], s_crop[2] + h_3rd)
      ass:line_to(s_crop[3], s_crop[2] + h_3rd)

      ass:move_to(s_crop[1], s_crop[2] + h_3rd*2)
      ass:line_to(s_crop[3], s_crop[2] + h_3rd*2)

      ass:draw_stop()
    end

    if self.dragging > 0 and drawn_handle ~= 5 then
      -- While dragging, draw only the dragging handle
      ass:new_event()
      ass:append( fmt_drag )
      ass:pos(0,0)
      ass:draw_start()
      ass:rect_cw(s_hb[drawn_handle][1], s_hb[drawn_handle][2], s_hb[drawn_handle][3], s_hb[drawn_handle][4])
      ass:draw_stop()
    elseif self.dragging == 0 then
      local hit_index = self:hit_test(s_hb, self.mouse_screen)
      if hit_index > 0 and hit_index ~= 5 then
        -- Hilight handle
        ass:new_event()
        ass:append( fmt_handle_hover )
        ass:pos(0,0)
        ass:draw_start()
        ass:rect_cw(s_hb[hit_index][1], s_hb[hit_index][2], s_hb[hit_index][3], s_hb[hit_index][4])
        ass:draw_stop()
      end

      ass:new_event()
      ass:pos(0,0)
      ass:append( fmt_string )
      ass:draw_start()

      -- Draw corner handles
      for k, v in pairs({1, 3, 7, 9}) do
        ass:rect_cw(s_hb[v][1], s_hb[v][2], s_hb[v][3], s_hb[v][4])
      end
      ass:draw_stop()
    end

    if true or draw_text then

      local br_pos = {s_crop[3] - 2, s_crop[4] + 2}
      local br_align = 9
      if br_pos[2] >= self.display_state.screen.height - 20 then
        br_pos[2] = br_pos[2] - 4
        br_align = 3
      end

      ass:new_event()
      ass:pos(unpack(br_pos))
      ass:an( br_align )
      ass:append("{\\fs20\\shad0\\be0\\bord2}")
      ass:append(string.format("%dx%d", v_crop[3] - v_crop[1], v_crop[4] - v_crop[2]) )

      local tl_pos = {s_crop[1] + 2, s_crop[2] - 2}
      local tl_align = 1
      if tl_pos[2] < 20 then
        tl_pos[2] = tl_pos[2] + 4
        tl_align = 7
      end

      ass:new_event()
      ass:pos(unpack(tl_pos))
      ass:an( tl_align )
      ass:append("{\\fs20\\shad0\\be0\\bord2}")
      ass:append(string.format("%d,%d", v_crop[1], v_crop[2]))
    end

    ass:draw_stop()
  end

  -- Crosshair for mouse
  if self.options.draw_mouse and not dim_only then
    ass:new_event()
    ass:pos(0,0)
    ass:append( dasldkjasjlda )
    ass:draw_start()

    ass:move_to(self.mouse_screen.x, 0)
    ass:line_to(self.mouse_screen.x, self.display_state.screen.height)

    ass:move_to(0, self.mouse_screen.y)
    ass:line_to(self.display_state.screen.width, self.mouse_screen.y)

    ass:draw_stop()
  end

  if self.options.draw_help and not dim_only then
    ass:new_event()
    ass:pos(self.display_state.screen.width - 5, 5)
    local text_align = 9
    ass:append( string.format("{\\fs%d\\an%d\\bord2}", 18, text_align) )

    local fmt_key = function( key, text ) return string.format("[{\\c&HBEBEBE&}%s{\\c} %s]", key:upper(), text) end

    local crosshair_txt = self.options.draw_mouse and "Hide" or "Show";
    local guide_txt = self.options.draw_guides and "Hide" or "Show";
    lines = {
      fmt_key("ENTER", "Accept crop") .. " " .. fmt_key("ESC", "Cancel crop"),
      fmt_key("C", crosshair_txt .. " crosshair") .. " " .. fmt_key("X", guide_txt .. " guides"),
      fmt_key("SHIFT-Drag", "Constrain ratio")
    }

    local full_line = nil
    for i, line in pairs(lines) do
      if line ~= nil then
        full_line = full_line and (full_line .. "\\N" .. line) or line
      end
    end
    ass:append(full_line)
  end

  return ass.text
end
