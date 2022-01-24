local utils = require 'kong.tools.utils'
local cjson = require('cjson.safe').new()

local split = utils.split
local table_remove = table.remove

local M = {}

local function get_by_nested_value(table, nested_key)
  if not table or type(table) ~= 'table' then
    return nil
  end
  if #nested_key > 1 then
    local head = table_remove(nested_key, 1)
    return get_by_nested_value(table[head], nested_key)
  end
  return table[nested_key[1]]
end

local function get_value_from_table(table, path)
  return get_by_nested_value(table, split(path, '.'))
end

function M.interpolate(string, table)
    return (string:gsub('($%b{})',
            function(w) return get_value_from_table(table, w:sub(3, -2)) or w end))
end

function M.interpolate_with_body(string, body, table)
  table = table or {}

  table['body'] = body
  local body_obj
  if type(body) == 'table' then
    body_obj = body
  elseif body then
    body_obj = cjson.decode(body)
  end
  if body_obj then
    for h, v in pairs(body_obj) do
      table[h] = v
    end
  end

  return M.interpolate(string, table)
end

return M