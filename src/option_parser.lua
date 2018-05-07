local OptionParser = {}
OptionParser.__index = OptionParser

setmetatable(OptionParser, {
  __call = function (cls, ...) return cls.new(...) end
})

function OptionParser.new(identifier)
  local self = setmetatable({}, OptionParser)

  self.identifier = identifier
  self.config_file = self:_get_config_file(identifier)

  self.config_lines = {}
  self.OVERRIDE_START = "# Script-saved overrides below this line. Edits will be lost!"

  -- All the options contained, as a list
  self.options_list = {}
  -- All the options contained, as a table with keys
  self.options = {}

  --[[ Example option:
  {
    index = 1, -- Added automatically
    type  = "string",
    key   = "some_option",
    default = "default value",
    name  = "Some option",
    description  = "Describes the option",

    -- Current value
    value = "current value",
    -- Value loaded from .conf, or nil
    loaded = "current value"
  }
  ]]--


  -- Easy lookups
  self.values = setmetatable({}, {
    __index = function(t, name)
      local option = self.options[name]
      return option ~= nil and option.value or nil
    end,
    __newindex = function(t, name, value)
      local option = self.options[name]
      if option then
        option.value = value
      end
    end
  })

  self.defaults = setmetatable({}, {
    __index = function(t, name)
      local option = self.options[name]
      return option ~= nil and option.default or nil
    end
  })

  -- Hacky way to run after the script is initialized and options (hopefully) added
  mp.add_timeout(0, function()
    -- Handle a '--script-opts identifier-example-config=example.conf' to save an example config to a file
    local example_dump_filename = mp.get_opt(self.identifier .. "-example-config")
    if example_dump_filename then
      self:save_example_options(example_dump_filename)

      if mp.get_property_native("options/idle") then
        msg.info("Exiting.")
        mp.commandv("quit")
      end
    end
  end)

  return self
end

function OptionParser:add_option(key, default, description, pad_before)
  if self.options[key] ~= nil then
    -- Already exists!
    return nil
  end

  local option_index = #self.options_list + 1
  local option_type = type(default)

  local option = {
    index = option_index,
    type = option_type, key = key,
    default = default,
    -- name = name,
    description = description,
    pad_before = pad_before,

    value = default,
    loaded = nil
  }

  self.options_list[option_index] = option
  if key then
    self.options[key] = option
  end

  return option
end

function OptionParser:add_options(list_of_options)
  for i, option_args in ipairs(list_of_options) do
    self:add_option(unpack(option_args))
  end
end


function OptionParser:restore_defaults()
  for key, option in pairs(self.options) do
    option.value = option.default
  end
end

function OptionParser:_get_config_file(identifier)
  local config_filename = "script-opts/" .. identifier .. ".conf"
  local config_file = mp.find_config_file(config_filename)

  if not config_file then
    config_filename = "lua-settings/" .. identifier .. ".conf"
    config_file = mp.find_config_file(config_filename)

    if config_file then
      msg.warn("lua-settings/ is deprecated, use directory script-opts/")
    end
  end

  return config_file
end

function OptionParser:value_to_string(value)
  if type(value) == "boolean" then
    if value then value = "yes" else value = "no" end
  end
  return tostring(value)
end

function OptionParser:string_to_value(option_type, value)
  if option_type == "boolean" then
    if value == "yes" or value == "true" then
      value = true
    elseif value == "no" or value == "false" then
      value = false
    else
      -- can't parse as boolean
      value = nil
    end
  elseif option_type == "number" then
    value = tonumber(value)
    if value == nil then
      -- Can't parse as number
    end
  end
  return value
end

function OptionParser:_trim(text)
  return (text:gsub("^%s*(.-)%s*$", "%1"))
end

function OptionParser:load_options()
  if not self.config_file then return end
  local file = io.open(self.config_file, 'r')
  if not file then return end

  local override_reached = false
  local line_index = 1

  for line in file:lines() do
    if line == self.OVERRIDE_START then
      override_reached = true
    elseif line:find("#") == 1 then
      -- Skip comments
    else
      local key, value = line:match("^(..-)=(.+)$")
      if key then
        key = self:_trim(key)
        value = self:_trim(value)

        local option = self.options[key]
        if not option then
          msg.warn(("%s:%d ignoring unknown key '%s'"):format(self.config_file, line_index, key))
        else
          local parsed_value = self:string_to_value(option.type, value)

          if parsed_value == nil then
            msg.error(("%s:%d error parsing value '%s' for key '%s' (as %s)"):format(self.config_file, line_index, value, key, option.type))
          else
            option.value = parsed_value
            if not override_reached then
              option.loaded = parsed_value
            end
          end
        end
      end
    end

    if not override_reached then
      -- Store original lines
      self.config_lines[line_index] = line
    end

    line_index = line_index + 1
  end

  file:close()
end

function OptionParser:save_options()
  if not self.config_file then return end

  -- Check if we have overriden values
  local override_lines = {}
  for option_index, option in ipairs(self.options_list) do
    -- If value is different from default AND loaded value, store it in array
    if option.key and option.value ~= option.default and (option.loaded == nil or option.value ~= option.loaded) then
      table.insert(override_lines, ('%s=%s'):format(option.key, self:value_to_string(option.value)))
    end
  end

  -- Don't rewrite unless we have any reason to
  if #override_lines > 0 then
    local file = io.open(self.config_file, 'w')
    if not file then return end

    if #self.config_lines > 0 then
      -- Write original config lines
      for line_index, line in ipairs(self.config_lines) do
        file:write(line .. '\n')
      end

      -- Add a newline before the override comment if needed
      if self.config_lines[#self.config_lines] ~= '' then
        file:write('\n')
      end
    end

    file:write(self.OVERRIDE_START .. '\n')
    for override_line_index, override_line in ipairs(override_lines) do
      file:write(override_line .. '\n')
    end

    file:close()
  end

end

function OptionParser:get_default_config_lines()
  local example_config_lines = {}

  for option_index, option in ipairs(self.options_list) do
    if option.pad_before then
      table.insert(example_config_lines, '')
    end

    if option.description then
      for description_line in option.description:gmatch('[^\r\n]+') do
        table.insert(example_config_lines, ('# ' .. description_line))
      end
    end
    if option.key then
      table.insert(example_config_lines, ('%s=%s'):format(option.key, self:value_to_string(option.default)) )
    end
  end
  return example_config_lines
end

function OptionParser:explain_options()
  local example_config_lines = self:get_default_config_lines()
  msg.info(table.concat(example_config_lines, '\n'))
end

function OptionParser:save_example_options(filename)
  local file = io.open(filename, "w")
  if not file then
    msg.error("Unable to open file '" .. filename .. "' for writing")
  else
    local example_config_lines = self:get_default_config_lines()
    file:write(table.concat(example_config_lines, '\n'))
    file:close()
    msg.info("Wrote example config to file '" .. filename .. "'")
  end
end
