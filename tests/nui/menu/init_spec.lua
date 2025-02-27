local Menu = require("nui.menu")
local Text = require("nui.text")
local helper = require("tests.nui")
local spy = require("luassert.spy")

local eq, feedkeys, tbl_pick = helper.eq, helper.feedkeys, helper.tbl_pick

describe("nui.menu", function()
  local callbacks
  local popup_options

  before_each(function()
    callbacks = {
      on_change = function() end,
    }

    popup_options = {
      relative = "win",
      position = "50%",
    }
  end)

  describe("size", function()
    it("respects o.min_width", function()
      local min_width = 3

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        min_width = min_width,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_width(menu.winid), min_width)

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), {
        "A",
        " * ",
        "B",
      })
    end)

    it("respects o.max_width", function()
      local max_width = 6

      local items = {
        Menu.item("Item 1"),
        Menu.separator("*"),
        Menu.item("Item Number Two"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        max_width = max_width,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_width(menu.winid), max_width)

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), {
        "Item 1",
        " *    ",
        "Item …",
      })
    end)

    it("respects o.min_height", function()
      local min_height = 3

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        min_height = min_height,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_height(menu.winid), min_height)
    end)

    it("respects o.max_height", function()
      local max_height = 2

      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        max_height = max_height,
      })

      menu:mount()

      eq(vim.api.nvim_win_get_height(menu.winid), max_height)
    end)
  end)

  it("calls o.on_change item focus is changed", function()
    local on_change = spy.on(callbacks, "on_change")

    local lines = {
      Menu.item("Item 1", { id = 1 }),
      Menu.item("Item 2", { id = 2 }),
    }

    local menu = Menu(popup_options, {
      lines = lines,
      on_change = on_change,
    })

    menu:mount()

    -- initial focus
    assert.spy(on_change).called_with(lines[1], menu)
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[2], menu)
    on_change:clear()

    feedkeys("j", "x")
    assert.spy(on_change).called_with(lines[1], menu)
    on_change:clear()

    feedkeys("k", "x")
    assert.spy(on_change).called_with(lines[2], menu)
    on_change:clear()
  end)

  describe("item", function()
    it("is prepared using o.prepare_item if provided", function()
      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      local function prepare_item(item)
        return "-" .. item.text .. "-"
      end

      local menu = Menu(popup_options, {
        lines = items,
        prepare_item = prepare_item,
      })

      menu:mount()

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), vim.tbl_map(prepare_item, items))
    end)

    it("is prepared when o.prepare_item is not provided", function()
      local items = {
        Menu.item("A"),
        Menu.separator("*"),
        Menu.item("B"),
      }

      popup_options.border = "single"

      local menu = Menu(popup_options, {
        lines = items,
      })

      menu:mount()

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), {
        "A",
        "─*──",
        "B",
      })
    end)

    it("is skipped respecting o.should_skip_item if provided", function()
      local on_change = spy.on(callbacks, "on_change")

      local items = {
        Menu.item("-"),
        Menu.item("A", { id = 1 }),
        Menu.item("-"),
        Menu.item("B", { id = 2 }),
        Menu.item("-"),
      }

      local menu = Menu(popup_options, {
        lines = items,
        on_change = on_change,
        should_skip_item = function(item)
          return not item.id
        end,
      })

      menu:mount()

      assert.spy(on_change).called_with(items[2], menu)
      on_change:clear()

      feedkeys("j", "x")
      assert.spy(on_change).called_with(items[4], menu)
      on_change:clear()

      feedkeys("j", "x")
      assert.spy(on_change).called_with(items[2], menu)
      on_change:clear()
    end)

    it("supports NuiText", function()
      local hl_group = "NuiMenuTest"
      local text = "text"
      local items = {
        Menu.item(Text(text, hl_group)),
      }

      local menu = Menu(popup_options, {
        lines = items,
      })

      menu:mount()

      eq(vim.api.nvim_buf_get_lines(menu.bufnr, 0, -1, false), { text })

      local linenr = 1
      local line = vim.api.nvim_buf_get_lines(menu.bufnr, linenr - 1, linenr, false)[linenr]
      local byte_start = string.find(line, text)

      local extmarks = vim.api.nvim_buf_get_extmarks(menu.bufnr, menu.ns_id, linenr - 1, linenr, {
        details = true,
      })

      eq(type(byte_start), "number")

      eq(#extmarks, 1)
      eq(extmarks[1][2], linenr - 1)
      eq(extmarks[1][4].end_col - extmarks[1][3], #text)
      eq(tbl_pick(extmarks[1][4], { "end_row", "hl_group" }), {
        end_row = linenr - 1,
        hl_group = hl_group,
      })
    end)
  end)
end)
