local cjson = require('cjson.safe').new()
local utils = require 'kong.tools.utils'
local http = require 'resty.http'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
local common_plugin_status, common_plugin_headers = pcall(require, 'kong.plugins.common.headers')
local start_timer = monitoring.start_timer

local split = utils.split
local kong = kong -- luacheck: ignore

local find = string.find
local sub = ngx.re.sub --luacheck: ignore
local lower = string.lower
local spawn = ngx.thread.spawn -- luacheck: ignore
local wait = ngx.thread.wait -- luacheck: ignore
local insert = table.insert
local unpack = unpack or table.unpack --luacheck: ignore
local table_remove = table.remove

cjson.decode_array_with_array_mt(true)

local _M = {}

local function dump(o) --luacheck: ignore
  if type(o) == 'table' then
    local s = '{ '
    for k, v in pairs(o) do
      if type(k) ~= 'number' then
        k = '"' .. k .. '"'
      end
      s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
    end
    return s .. '} '
  else
    return tostring(o)
  end
end

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end

local function create_error_response(message, req_uri, status, body)
  local err_res = {
    message = message,
    status = 500,
    error = 'Resource fetch error',
    code = 'APIGatewayError',
    errors = { {
                 uri = req_uri,
                 status = status,
                 error = body
               } }
  }

  return err_res
end

local function get_by_nested_value(array, nested_key)
  if #nested_key > 1 then
    local head = table_remove(nested_key, 1)
    return get_by_nested_value(array[head], nested_key)
  end
  return array[nested_key[1]]
end

local function is_json_body(content_type)
  return content_type and find(lower(content_type), 'application/json', nil, true)
end
_M.is_json_body = is_json_body

local function get_external_resources_by_id(value, resource)
  local by_id = {}
  local config = resource.config
  local src_resource_name = config.api.id_key
  if src_resource_name ~= nil then
    if utils.is_array(value) then
      for _, v in pairs(value) do
        local id = get_by_nested_value(v, split(src_resource_name, '.'))
        if id == nil then
          kong.log.err('can not find id key ', src_resource_name, ' in response from ', config.api.url)
          return nil, 'can not find id key  for "' .. src_resource_name .. '" for ' .. config.api.url
        end
        by_id[id] = v
      end
    else
      local id = get_by_nested_value(value, split(src_resource_name, '.'))
      if id == nil then
        kong.log.err('can not find id key ', src_resource_name, ' in response from ', config.api.url)
        return nil, 'can not find id key  for "' .. src_resource_name .. '" for ' .. config.api.url
      end
      by_id[id] = value
    end
  else
    by_id['$'] = value
  end
  return by_id, nil
end

local function get_external_resource_id_key(data_path)
  local resource_id_path = data_path.id_path
  if resource_id_path == nil then
    return nil, nil
  end
  local parsed_resource_id_path, err = jp.parse(resource_id_path)
  if err ~= nil then
    kong.log.error("unable to parse ", resource_id_path, " error ", err)
    return nil, err
  end
  return parsed_resource_id_path[#parsed_resource_id_path], nil
end

local function get_external_id_and_resource_from_value(dest_resource, value, data_path, resource)
  if resource ~= nil then
    if data_path.resource_id_key ~= nil then
      return dest_resource[data_path.resource_id_key], value[dest_resource[data_path.resource_id_key]]
    else
      return '$', value['$']
    end
  else
    return '$', value
  end
end

local function set_for_path(data_path, upstream_body, value, resource)
  if value == nil then
    return nil, nil
  end

  local path = data_path.path
  local dest_resource_paths, err = jp.paths(upstream_body, path)
  if err ~= nil then
    kong.log.error("unable to find paths ", data_path.path, " error ", err)
    return false, err
  end

  --- if we are using json.path to set result
  local json_path_set = false
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
      local _id, _resource_data = get_external_id_and_resource_from_value(_dest_resource, value, data_path, resource)
      if _resource_data == nil then
        if resource == nil then
          kong.log.err('missing data for key "', _external_key_to_dest_resource)
          return false, 'missing data for key "' .. _external_key_to_dest_resource
        elseif resource.config.allow_missing == false then
          kong.log.err('missing data for key "', _external_key_to_dest_resource, '" (id missing ', resource.config.api.id_key, ' for: ', _id)
          return false, 'missing data for key "' .. _external_key_to_dest_resource .. '" (id missing ' .. resource.config.api.id_key .. '="' .. (_id or 'nil') .. '")'
        end
      end
      _parent_of_dest_resource[_external_key_to_dest_resource] = _resource_data
    end
  end

  if json_path_set == false then
    local _, _resource_data = get_external_id_and_resource_from_value(upstream_body, value, data_path, resource)
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
      if current ~= nil and current[path[i]] ~= nil then
        current = current[path[i]]
      end
    end

    if _resource_data ~= nil then
      current[path] = _resource_data
    end
  end

  return true, nil
end
_M.set_for_path = set_for_path

local function set_paths(data_paths, upstream_body, value, resource)
  if value == nil then
    return nil, nil
  end

  local external_resources_by_id, err = get_external_resources_by_id(value, resource)
  if err ~= nil then
    return false, err
  end

  for i = 1, #data_paths do
    local external_resource_id_key, err = get_external_resource_id_key(data_paths[i])
    if err ~= nil then
      return false, err
    end
    if external_resource_id_key ~= nil then
      data_paths[i].resource_id_key = external_resource_id_key
    end

    local _, err = set_for_path(data_paths[i], upstream_body, external_resources_by_id, resource)
    if err ~= nil then
      return false, err
    end
  end

  return true, nil
end

-- method used for calling services for given key
local function fetch(resource_index, resource_config, http_config)
  local config = resource_config.config
  local api = config.api
  local req_uri = api.url
  local api_query = split(req_uri, '?')
  local req_query = '?'
  if #api_query == 2 then
    req_query = '?' .. api_query[2] .. '&'
  end

  local ids_len = resource_config.ids_len
  local query_param_name = api.query_param_name
  if query_param_name ~= nil then
    local query_join = ''
    local ids = resource_config.ids
    for i = 1, ids_len do
      req_query = req_query .. query_join .. query_param_name .. '=' .. ids[i]
      query_join = '&'
    end
    req_query = req_query .. '&size=' .. (ids_len + 1)
    req_uri = req_uri .. req_query
  elseif ids_len == 1 then
    req_uri = req_uri .. resource_config.ids[1]
  end

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local timer = start_timer(req_uri)
  local req_headers = kong.request.get_headers()
  if common_plugin_status then
    local upstream_headers = common_plugin_headers.get_upstream_headers(kong.request)
    for h, v in pairs(upstream_headers) do
      if req_headers[h] == nil then
        req_headers[h] = v
      end
    end
    req_headers['user-agent'] = upstream_headers['user-agent']
  end
  local res, err = client:request_uri(req_uri, {
    query = req_query,
    headers = req_headers
  })
  -- put connection to pool / we don't close it
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)
  timer:stop()
  if not res then
    kong.log.err('Invalid response from upstream resource url: ', req_uri, ' err: ', err)
    return { nil, create_error_response('invalid response from resource', req_uri, 0, err) }
  end

  local resource_body_parsed = nil
  if is_json_body(res.headers['content-type']) then
    resource_body_parsed = read_json_body(res.body)
  end

  if res.status == 404 then
    kong.log.err('404 response from upstream resource url: ', req_uri, ' status: ', res.status, ' resource_index:', resource_index)
    return { { resource_index, nil }, create_error_response('can handle only responses with 200 sc', req_uri, res.status, resource_body_parsed or res.body) }
  end

  if res.status ~= 200 then
    kong.log.err('Wrong response from upstream resource url: ', req_uri, ' status:  ', res.status)
    return { nil, create_error_response('can handle only responses with 200 sc', req_uri, res.status, resource_body_parsed or res.body) }
  end

  if resource_body_parsed == nil then
    kong.log.err('Unable to parse response from ', req_uri)
    return { nil, create_error_response('unable to parse response', req_uri, res.status, res.body) }
  end

  local resource_body_query = jp.query(resource_body_parsed, api.data_path)
  if resource_body_query ~= nil and #resource_body_query == 1 then
    local resource_body = resource_body_query[1]
    setmetatable(resource_body, getmetatable(resource_body_parsed))
    return { { resource_index, resource_body }, nil }
  end

  kong.log.err('Invalid response from upstream resource ', resource_index, ' Multiple data data_len: ', resource_body_query)
  return { nil, create_error_response('can handle response', req_uri, res.status, resource_body_parsed) }
end

local function query_json(json_body, resource_data_paths, resource_index)
  if resource_data_paths == nil then
    return { {}, resource_index }
  end
  local ids = {}
  for i = 1, #resource_data_paths do
    if resource_data_paths[i].id_path ~= nil then
      local temp_ids, err = jp.query(json_body, resource_data_paths[i].id_path)
      if err ~= nil then
        return { {}, resource_index }
      end
      for j = 1, #temp_ids do
        insert(ids, temp_ids[j])
      end
    end
  end

  return { ids, resource_index }
end

function _M.transform_json_body(resources_to_extend, upstream_body, http_config)
  local resources = {}
  local threads_json_query = {}
  -- prepare threads to find ids to query resources
  for i = 1, #resources_to_extend do
    local v = resources_to_extend[i]
    resources[i] = {
      config = v
    }
    insert(threads_json_query, spawn(query_json, upstream_body, v.data_paths, i))
  end

  for i = 1, #threads_json_query do
    local ok, res = wait(threads_json_query[i])
    if not ok then
      kong.log.err('Threads wait err: ', res)
      return false, res
    end
    local ids, resource_index = unpack(res)
    -- if no resource ids found, skip the resource (if not adding allowed)
    local config = resources[resource_index].config
    if next(ids) == nil and config.add_missing == false then
      kong.log.warn('No resource ids found skip: ', resource_index)
      resources[resource_index] = nil
    else
      resources[resource_index].ids = ids
      resources[resource_index].ids_len = #ids
    end
  end

  -- prepare threads to call resources for data
  local threads = {}

  for resource_index, value in pairs(resources) do
    insert(threads, spawn(fetch, resource_index, value, http_config))
  end

  for i = 1, #threads do
    local ok, res = wait(threads[i])
    if not ok then
      kong.log.err('Threads wait err: ', res)
      return false, res
    end
    local result, err = unpack(res)
    if not result then
      return false, err
    end
    local resource_index, resource_body = unpack(result)
    local resource = resources[resource_index]
    local config = resource.config
    -- if response is an array we should use set_in_table_arr
    -- multiple resources

    if utils.is_array(upstream_body, 'fast') then
      local _, err = set_paths(resource.config.data_paths, upstream_body, resource_body, resource)
      if err ~= nil then
        kong.log.err('Unable to set result in array: ', resource_index, ' err: ', err)
        return false, create_error_response(err, config.api.url, 200, resource_body)
      end
    else
      if resource_body == nil and config.allow_missing == false then
        kong.log.err('Missing data for resource ', resource_index, ' api: ', config.api.url, ' res_body: nil')
        return false, err
      end
      local _, err = set_paths(resource.config.data_paths, upstream_body, resource_body, resource)
      if err ~= nil then
        kong.log.err('Unable to set result: ', resource_index, ' err: ', err)
        return false, create_error_response(err, config.api.url, 200, resource_body)
      end
    end
  end

  return true, upstream_body
end

return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
