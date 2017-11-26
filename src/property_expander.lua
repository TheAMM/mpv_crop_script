local PropertyExpander = {}
PropertyExpander.__index = PropertyExpander

setmetatable(PropertyExpander, {
  __call = function (cls, ...) return cls.new(...) end
})

function PropertyExpander.new(property_source)
  local self = setmetatable({}, PropertyExpander)
  self.sentinel = {}

  -- property_source is a table which defines the following functions:
  -- get_raw_property(name, def) - returns a raw property or def
  -- get_property(name) - returns a string
  -- get_property_osd(name) - returns an OSD formatted string (whatever that'll mean)
  self.property_source = property_source
  return self
end


-- Formats seconds to H:M:S based on a %h-%m-%s format
function PropertyExpander:_format_time(seconds, time_format)
  -- In case "seconds" is not a number, give it back
  if type(seconds) ~= "number" then
    return seconds
  end

  time_format = time_format or "%02h.%02m.%02.3s"

  local types = { h='d', m='d', s='f', S='f', M='d' }
  local values = {
    h=math.floor(seconds / 3600),
    m=math.floor(seconds / 60),
    s=(seconds % 60),
    S=seconds,
    M=math.floor((seconds % 1)*1000)
  }

  local substitutor = function(sub_format, char)
    local v = values[char]
    local t = types[char]
    if t == nil then return nil end

    sub_format = '%' .. sub_format .. types[char]
    return v and sub_format:format(v) or nil
  end

  return time_format:gsub('%%([%-%+ #0]*%d*.?%d*)([%a%%])', substitutor)
end

-- Format a date
function PropertyExpander:_format_date(seconds, date_format)
  -- In case "seconds" is not nil or a number, give it back
  if type(seconds) ~= "number" and type(seconds) ~= "nil" then
    return seconds
  end

  --[[
    As stated by Lua docs:
    %a  abbreviated weekday name (e.g., Wed)
    %A  full weekday name (e.g., Wednesday)
    %b  abbreviated month name (e.g., Sep)
    %B  full month name (e.g., September)
    %c  date and time (e.g., 09/16/98 23:48:10)
    %d  day of the month (16) [01-31]
    %H  hour, using a 24-hour clock (23) [00-23]
    %I  hour, using a 12-hour clock (11) [01-12]
    %M  minute (48) [00-59]
    %m  month (09) [01-12]
    %p  either "am" or "pm" (pm)
    %S  second (10) [00-61]
    %w  weekday (3) [0-6 = Sunday-Saturday]
    %x  date (e.g., 09/16/98)
    %X  time (e.g., 23:48:10)
    %Y  full year (1998)
    %y  two-digit year (98) [00-99]
    %%  the character `%´
  ]]--
  date_format = date_format or "%Y-%m-%d %H-%M-%S"
  return os.date(date_format, seconds)
end


function PropertyExpander:expand(format_string)
  local substitutor = function(match)
    local command, inner = match:sub(3, -2):match('^([%?!~^%%#&]?)(.+)$')
    local colon_index = inner:find(':')

    local property_name = inner
    local secondary = ""
    local has_colon = colon_index and true or false

    if colon_index then
      property_name = inner:sub(1, colon_index-1)
      secondary = inner:sub(colon_index+1, -1)
    end


    local raw_property_value = self.property_source:get_raw_property(property_name, self.sentinel)
    local property_exists = raw_property_value ~= self.sentinel

    if command == '' then
      -- Return the property value if it's not nil, else the (expanded) secondary
      return property_exists and self.property_source:get_property(property_name) or self:expand(secondary)


    elseif command == '?' then
      -- Return (expanded) secondary if property is truthy (sentinel is falsey)
      if not isempty(raw_property_value) then return self:expand(secondary) else return '' end

    elseif command == '!' then
      -- Return (expanded) secondary if property is falsey
      if isempty(raw_property_value) then return self:expand(secondary) else return '' end


    elseif command == '^' then
      -- Return (expanded) secondary if property does not exist
      return not property_exists and self:expand(secondary) or ""


    elseif command == '%' then
      -- Return the value formatted using the secondary string
      return secondary:format(raw_property_value)

    elseif command == '#' then
      -- Format a number to HMS
      return self:_format_time(raw_property_value, has_colon and secondary or nil)

    elseif command == '&' then
      -- Format a date
      return self:_format_date(nil, has_colon and secondary or nil)


    elseif command == '@' then
      -- Format the value for OSD - mostly useful for latching onto mpv's properties
      return property_exists and self.property_source:get_property_osd(property_name) or self:expand(secondary)
    end

  end

  -- Lua patterns are generally a pain, but %b is comfy!
  return format_string:gsub('%$%b{}', substitutor)
end


local MPVPropertySource = {}
MPVPropertySource.__index = MPVPropertySource

setmetatable(MPVPropertySource, {
  __call = function (cls, ...) return cls.new(...) end
})

function MPVPropertySource.new(values)
  local self = setmetatable({}, MPVPropertySource)
  self.values = values

  return self
end

function MPVPropertySource:get_raw_property(name, default)
  if name:find('mpv/') ~= nil then
    return mp.get_property_native(name:sub(5), default)
  end
  local v = self.values[name]
  if v ~= nil then return v else return default end
end

function MPVPropertySource:get_property(name, default)
  if name:find('mpv/') ~= nil then
    return mp.get_property(name:sub(5), default)
  end
  local v = self.values[name]
  if v ~= nil then return tostring(v) else return default end
end

function MPVPropertySource:get_property_osd(name, default)
  if name:find('mpv/') ~= nil then
    return mp.get_property_osd(name:sub(5), default)
  end
  local v = self.values[name]
  if v ~= nil then return tostring(v) else return default end
end
