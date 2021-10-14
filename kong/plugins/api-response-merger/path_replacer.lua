local kong = kong -- luacheck: ignore
local utils = require 'kong.tools.utils'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local sub = ngx.re.sub --luacheck: ignore
local split = utils.split

local _M = {}

local function get_resource_and_external_id_from_value(dest_resource, value, config)
    if config.resource_id_key ~= nil then
      return value[dest_resource[config.resource_id_key]], dest_resource[config.resource_id_key]
    else
      return value, nil
    end
end

function _M.set_for_path(path, upstream_body, value, config)
  if value == nil then
    return nil, nil
  end
  local without_config = config == nil
  config = config or {
    add_missing = false,
    allow_missing = false
  }

  local dest_resource_paths, err = jp.paths(upstream_body, path)
  if err ~= nil then
    kong.log.error("unable to find paths ", path, " error ", err)
    return false, err
  end

  --- if we are using json.path to set result
  local json_path_set = false
  if config.add_missing == false then
    json_path_set = true
  end
  for i, dest_resource_path in pairs(dest_resource_paths) do
    json_path_set = true
    local _dest_resource = upstream_body
    local _parent_of_dest_resource = _dest_resource
    local _external_key_to_dest_resource = nil
    for j, key_to_dest_resource in pairs(dest_resource_path) do
      if key_to_dest_resource == '$' then --luacheck: ignore
        -- just skip
      else
        -- print('key_to_dest_resource: ' .. key_to_dest_resource .. ', _dest_resource:' .. dump(_dest_resource))
        if type(key_to_dest_resource) == 'number' then
          key_to_dest_resource = key_to_dest_resource + 1
        end
        if j == #dest_resource_path then
          _parent_of_dest_resource = _dest_resource
        end
        _dest_resource = _dest_resource[key_to_dest_resource]
        _external_key_to_dest_resource = key_to_dest_resource
      end
    end

    if type(_dest_resource) == 'table' then
      local _resource_data, _id = get_resource_and_external_id_from_value(_dest_resource, value, config)
      if _resource_data == nil then
        if without_config then
          kong.log.err('missing data for key "', _external_key_to_dest_resource)
          return false, 'missing data for key "' .. _external_key_to_dest_resource
        elseif config.allow_missing == false then
          kong.log.err('missing data for key "', _external_key_to_dest_resource, '" (missing for id: "', _id, '"')
          return false, 'missing data for key "' .. _external_key_to_dest_resource .. '" (missing for id: "' .. (_id or 'nil') .. '")'
        end
      end
      _parent_of_dest_resource[_external_key_to_dest_resource] = _resource_data
    end
  end

  if json_path_set == false then
    local _resource_data, _ = get_resource_and_external_id_from_value(upstream_body, value, config)
    path = sub(path, '\\$\\.', '')
    local paths = split(path, '.')
    local paths_len = #paths
    if paths_len == 0 then
      upstream_body = _resource_data --luacheck: ignore
      return true, nil
    end

    if paths_len == 1 then
      upstream_body[path] = _resource_data
      return true, nil
    end

    local current = upstream_body[paths[1]]
    for i = 2, paths_len - 1 do
      if type(current) == 'table' and type(current[path[i]]) == 'table' then
        current = current[path[i]]
      end
    end

    if _resource_data ~= nil then
      current[path] = _resource_data
    end
  end

  return true, nil
end

return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80