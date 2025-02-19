local Line = require("nui.line")
local Text = require("nui.text")
local _ = require("nui.utils")._
local defaults = require("nui.utils").defaults
local is_type = require("nui.utils").is_type

local has_nvim_0_5_1 = vim.fn.has("nvim-0.5.1") == 1

local index_name = {
  "top_left",
  "top",
  "top_right",
  "right",
  "bottom_right",
  "bottom",
  "bottom_left",
  "left",
}

local function to_border_map(border)
  if not is_type("list", border) then
    error("invalid data")
  end

  -- fillup all 8 characters
  local count = vim.tbl_count(border)
  if count < 8 then
    for i = count + 1, 8 do
      local fallback_index = i % count
      border[i] = border[fallback_index == 0 and count or fallback_index]
    end
  end

  local named_border = {}

  for index, name in ipairs(index_name) do
    named_border[name] = border[index]
  end

  return named_border
end

local function to_border_list(named_border)
  if not is_type("map", named_border) then
    error("invalid data")
  end

  local border = {}

  for index, name in ipairs(index_name) do
    if is_type(named_border[name], "nil") then
      error(string.format("missing named border: %s", name))
    end

    border[index] = named_border[name]
  end

  return border
end

local function parse_padding(padding)
  if not padding then
    return nil
  end

  if is_type("map", padding) then
    return padding
  end

  local map = {}
  map.top = defaults(padding[1], 0)
  map.right = defaults(padding[2], map.top)
  map.bottom = defaults(padding[3], map.top)
  map.left = defaults(padding[4], map.right)
  return map
end

---@param edge "'top'" | "'bottom'"
---@param text? nil | string | table # string or NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
---@return table NuiLine
local function calculate_buf_edge_line(props, edge, text, align)
  local char, size = props.char, props.size

  local left_char = char[edge .. "_left"]
  local mid_char = char[edge]
  local right_char = char[edge .. "_right"]

  if left_char == "" then
    left_char = mid_char == "" and char["left"] or mid_char
  end

  if right_char == "" then
    right_char = mid_char == "" and char["right"] or mid_char
  end

  local left_text = Text(left_char)
  local right_text = Text(right_char)

  local max_width = size.width - left_text:width() - right_text:width()

  local content_text = Text(defaults(text, ""))
  if mid_char == "" then
    content_text:set(string.rep(" ", max_width))
  else
    content_text:set(_.truncate_text(content_text:content(), max_width))
  end

  local gap_length = max_width - content_text:width()

  local line = Line()

  line:append(left_text)
  _.align_line(defaults(align, "center"), line, content_text, mid_char, nil, gap_length)
  line:append(right_text)

  return line
end

---@return nil | table[] # NuiLine[]
local function calculate_buf_lines(props)
  local char, size, text = props.char, props.size, defaults(props.text, {})

  if is_type("string", char) then
    return nil
  end

  local left_text = Text(char.left)
  local right_text = Text(char.right)

  local gap_length = size.width - left_text:width() - right_text:width()

  local lines = {}

  table.insert(lines, calculate_buf_edge_line(props, "top", text.top, text.top_align))
  for _ = 1, size.height - 2 do
    table.insert(
      lines,
      Line({
        Text(left_text),
        Text(string.rep(" ", gap_length)),
        Text(right_text),
      })
    )
  end
  table.insert(lines, calculate_buf_edge_line(props, "bottom", text.bottom, text.bottom_align))

  return lines
end

local styles = {
  double = to_border_map({ "╔", "═", "╗", "║", "╝", "═", "╚", "║" }),
  none = "none",
  rounded = to_border_map({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" }),
  shadow = "shadow",
  single = to_border_map({ "┌", "─", "┐", "│", "┘", "─", "└", "│" }),
  solid = to_border_map({ "▛", "▀", "▜", "▐", "▟", "▄", "▙", "▌" }),
}

local function calculate_size(border)
  local size = vim.deepcopy(border.popup.popup_props.size)

  local char = border.border_props.char

  if is_type("map", char) then
    if char.top ~= "" then
      size.height = size.height + 1
    end

    if char.bottom ~= "" then
      size.height = size.height + 1
    end

    if char.left ~= "" then
      size.width = size.width + 1
    end

    if char.right ~= "" then
      size.width = size.width + 1
    end
  end

  local padding = border.border_props.padding

  if padding then
    if padding.top then
      size.height = size.height + padding.top
    end

    if padding.bottom then
      size.height = size.height + padding.bottom
    end

    if padding.left then
      size.width = size.width + padding.left
    end

    if padding.right then
      size.width = size.width + padding.right
    end
  end

  return size
end

local function calculate_position(border)
  local position = vim.deepcopy(border.popup.popup_state.position)
  return position
end

local function adjust_popup_win_config(border)
  local props = border.border_props

  if props.type ~= "complex" then
    return
  end

  local popup_position = {
    row = 0,
    col = 0,
  }

  local char = props.char

  if is_type("map", char) then
    if char.top ~= "" then
      popup_position.row = popup_position.row + 1
    end

    if char.left ~= "" then
      popup_position.col = popup_position.col + 1
    end
  end

  local padding = props.padding

  if padding then
    if padding.top then
      popup_position.row = popup_position.row + padding.top
    end

    if padding.left then
      popup_position.col = popup_position.col + padding.left
    end
  end

  local popup = border.popup

  if not has_nvim_0_5_1 then
    popup.win_config.row = props.position.row + popup_position.row
    popup.win_config.col = props.position.col + popup_position.col
    return
  end

  popup.win_config.relative = "win"
  popup.win_config.win = border.winid
  popup.win_config.bufpos = nil
  popup.win_config.row = popup_position.row
  popup.win_config.col = popup_position.col
end

local function init(class, popup, options)
  local self = setmetatable({}, class)

  self.popup = popup

  self.border_props = {
    type = "simple",
    style = defaults(options.style, "none"),
    highlight = defaults(options.highlight, "FloatBorder"),
    padding = parse_padding(options.padding),
    text = options.text,
  }

  local props = self.border_props

  local style = props.style

  if is_type("list", style) then
    props.char = to_border_map(style)
  elseif is_type("string", style) then
    if not styles[style] then
      error("invalid border style name")
    end

    props.char = vim.deepcopy(styles[style])
  end

  local is_borderless = is_type("string", props.char)

  if is_borderless then
    if props.text then
      error("text not supported for style:" .. props.char)
    end
  end

  if props.text or props.padding then
    props.type = "complex"
  end

  if props.type == "simple" then
    return self
  end

  self.win_config = {
    style = "minimal",
    border = "none",
    focusable = false,
    zindex = self.popup.win_config.zindex - 1,
  }

  local position_meta = popup.popup_state.position_meta
  self.win_config.relative = position_meta.relative
  self.win_config.win = position_meta.relative == "win" and position_meta.win or nil
  self.win_config.bufpos = position_meta.bufpos

  props.size = calculate_size(self)
  self.win_config.width = props.size.width
  self.win_config.height = props.size.height

  props.position = calculate_position(self)
  self.win_config.row = props.position.row
  self.win_config.col = props.position.col

  props._lines = calculate_buf_lines(props)

  if not string.match(props.highlight, ":") then
    props.highlight = "Normal:" .. props.highlight
  end

  return self
end

local Border = {
  super = nil,
  name = "Border",
}

function Border:init(popup, options)
  return init(self, popup, options)
end

function Border:_open_window()
  if self.winid or not self.bufnr then
    return
  end

  self.winid = vim.api.nvim_open_win(self.bufnr, false, self.win_config)
  assert(self.winid, "failed to create border window")

  vim.api.nvim_win_set_option(self.winid, "winhighlight", self.border_props.highlight)

  adjust_popup_win_config(self)

  vim.api.nvim_command("redraw")
end

function Border:_close_window()
  if not self.winid then
    return
  end

  if vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end

  self.winid = nil
end

function Border:mount()
  local popup = self.popup

  if not popup.popup_state.loading or popup.popup_state.mounted then
    return
  end

  local props = self.border_props

  if props.type == "simple" then
    return
  end

  self.bufnr = vim.api.nvim_create_buf(false, true)
  assert(self.bufnr, "failed to create border buffer")

  if props._lines then
    _.render_lines(props._lines, self.bufnr, popup.ns_id, 1, #props._lines)
  end

  self:_open_window()
end

function Border:unmount()
  local popup = self.popup

  if not popup.popup_state.loading or not popup.popup_state.mounted then
    return
  end

  local props = self.border_props

  if props.type == "simple" then
    return
  end

  if self.bufnr then
    if vim.api.nvim_buf_is_valid(self.bufnr) then
      vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end
    self.bufnr = nil
  end

  self:_close_window()
end

function Border:resize()
  local props = self.border_props

  if props.type ~= "complex" then
    return
  end

  props.size = calculate_size(self)
  self.win_config.width = props.size.width
  self.win_config.height = props.size.height

  props._lines = calculate_buf_lines(props)

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end

  if self.bufnr then
    if props._lines then
      _.render_lines(props._lines, self.bufnr, self.popup.ns_id, 1, #props._lines)
    end
  end

  vim.api.nvim_command("redraw")
end

function Border:reposition()
  local props = self.border_props

  if props.type ~= "complex" then
    return
  end

  local position_meta = self.popup.popup_state.position_meta
  self.win_config.relative = position_meta.relative
  self.win_config.win = position_meta.relative == "win" and position_meta.win or nil
  self.win_config.bufpos = position_meta.bufpos

  props.position = calculate_position(self)
  self.win_config.row = props.position.row
  self.win_config.col = props.position.col

  if self.winid then
    vim.api.nvim_win_set_config(self.winid, self.win_config)
  end

  adjust_popup_win_config(self)

  vim.api.nvim_command("redraw")
end

---@param edge "'top'" | "'bottom'"
---@param text? nil | string | table # string or NuiText
---@param align? nil | "'left'" | "'center'" | "'right'"
function Border:set_text(edge, text, align)
  local props = self.border_props

  if not props._lines or not props.text then
    return
  end

  props.text[edge] = text
  props.text[edge .. "_align"] = defaults(align, props.text[edge .. "_align"])

  local line = calculate_buf_edge_line(props, edge, props.text[edge], props.text[edge .. "_align"])

  local linenr = edge == "top" and 1 or #props._lines

  props._lines[linenr] = line
  line:render(self.bufnr, self.popup.ns_id, linenr)
end

function Border:get()
  local props = self.border_props

  if props.type ~= "simple" then
    return nil
  end

  if is_type("string", props.char) then
    return props.char
  end

  local char = {}

  for position, item in pairs(props.char) do
    char[position] = { item, props.highlight }
  end

  return to_border_list(char)
end

local BorderClass = setmetatable({
  __index = Border,
}, {
  __call = init,
  __index = Border,
})

return BorderClass
