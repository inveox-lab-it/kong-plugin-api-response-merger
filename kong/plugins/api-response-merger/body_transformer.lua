local cjson = require('cjson.safe').new()
local utils = require 'kong.tools.utils'
local http = require 'resty.http'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
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

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end

local function create_error_response(message, req_uri, status, body)
  local err_res = {
    message  = message,
    status = 500,
    error = 'Resource fetch error',
    code = 'APIGatewayError',
    errors = {{
      uri = req_uri,
      status = status,
      error = body
    }}
  }

  return err_res
end

local function get_by_nested_value(array, nested_key)
  if #nested_key > 1 then
    local head = table_remove(nested_key,1)
    return get_by_nested_value(array[head], nested_key)
  end
  return array[nested_key[1]]
end

local function is_json_body(content_type)
  return content_type and find(lower(content_type), 'application/json', nil, true)
end
_M.is_json_body = is_json_body

-- FIXME:? this method will handle only depth 1
local function set_in_table_arr(path, table, value, config )
  if value == nil then
    return true, nil
  end

  local src_resource_name = config.api.id_key
  local des_resource_id_key = config.resource_id_path
  path = sub(path, '\\$\\.\\.', '')
  path = sub(path, '\\$\\.', '')
  local paths = split(path, '.')
  local paths_len = #paths

  local current = table
  local by_id = {}
  local dest_resource_key = path
  if paths_len > 0 then
    dest_resource_key = paths[1]
  end

  for _, v in pairs(value) do
    local id = get_by_nested_value(v, split(src_resource_name, '.'))
    if id == nil then
      kong.log.err('can not find id key ', src_resource_name, ' in response from ',  config.api.url)
      return false, 'can not find id key  for "' .. src_resource_name  .. '" for ' .. config.api.url
    end
    by_id[id] = v
  end

  for _, v in pairs(current) do
    local id_json_query, err = jp.query(v, des_resource_id_key)
    if err ~= nil and config.allow_missing == true then
      return true, nil
    elseif err ~= nil and config.allow_missing == false then
      kong.log.err('missing data for key "', dest_resource_key ,' (id is nil; missing ', src_resource_name, 'err: ', err)
      return false, 'missing data for key "' .. dest_resource_key ..'" (id is nil; missing ' .. src_resource_name  .. '")'
    end
    local id = id_json_query[1]
    local src_data = by_id[id]
    if src_data == nil and config.allow_missing == false  then
      kong.log.err('missing data for key "', dest_resource_key ,' (id missing ', src_resource_name, ' for: ', id)
      return false, 'missing data for key "' .. dest_resource_key ..'" (id missing ' .. src_resource_name .. '="' .. (id or 'nil') .. '")'
    end

    v[dest_resource_key] = src_data
  end
  return true, nil
end

-- This method "should" handle depth 2 and more - not tested
local function set_in_table(path, table, value, resource)
  path = sub(path, '\\$\\.', '')
  local paths = split(path, '.')
  local paths_len = #paths
  if resource ~= nil and resource.config.search_in_array and utils.is_array(value) then
    local config = resource.config
    if resource.ids_len == 1 then
      local src_resource_name = config.api.id_key
      local by_id = {}

      for _, v in pairs(value) do
        local id = get_by_nested_value(v, split(src_resource_name, '.'))
        by_id[id] = v
      end
      local resource_val = by_id[resource.ids[1]]
      if resource_val ~= nil then
        value = resource_val
      else
        kong.log.warn('missing value for ', path, ' id ', config.ids[1])
      end
    elseif resource.ids_len > 1 then
      kong.log.warn('something strang happend multiple resources to set in response ', path)
    end
  end

  if paths_len == 0 then
    table = value
    return table
  end

  if paths_len == 1 then
    table[path] = value
    return table
  end

  local current = table[paths[1]]
  for i = 2, paths_len - 1 do
    current = current[path[i]]
  end

  if value ~= nil then
    current[path] = value
  end
  return current
end
_M.set_in_table = set_in_table

-- method used for calling services for given key
local function fetch(resource_key, resource_config, http_config)
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
  elseif config.resource_id_optional == true and ids_len == 0 then
    kong.log.err('resource id missing - upstream not called')
    return {{resource_key, nil}, create_error_response('resource id missing - upstream not called', '' , '', '')}
  end

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local timer = start_timer(req_uri)
  local req_headers = kong.request.get_headers()
  req_headers['user-agent'] = 'lua api-gateway/' .. req_headers['user-agent']
  local res, err = client:request_uri(req_uri, {
    query = req_query,
    headers = req_headers
  })
  -- put connection to pool / we don't close it
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)
  timer:stop()
  if not res then
    kong.log.err('Invalid response from upstream resource url: ', req_uri , ' err: ', err)
    return {nil, create_error_response('invalid response from resource', req_uri, 0, err)}
  end

  local resource_body_parsed = nil
  if is_json_body(res.headers['content-type']) then
    resource_body_parsed = read_json_body(res.body)
  end

  if res.status == 404 then
    kong.log.err('404 response from upstream resource url: ', req_uri, ' status: ', res.status, ' resource_key:', resource_key)
    return {{resource_key, nil}, create_error_response('can handle only responses with 200 sc', req_uri, res.status, resource_body_parsed or res.body)}
  end

  if res.status ~= 200 then
    kong.log.err('Wrong response from upstream resource url: ', req_uri, ' status:  ', res.status)
    return {nil, create_error_response('can handle only responses with 200 sc', req_uri, res.status, resource_body_parsed or res.body)}
  end

  if resource_body_parsed == nil then
    kong.log.err('Unable to parse response from ',  req_uri)
    return { nil, create_error_response('unable to parse response', req_uri, res.status, res.body) }
  end

  local resource_body_query = jp.query(resource_body_parsed, api.data_path)
  if resource_body_query ~= nil and #resource_body_query == 1 then
    local resource_body = resource_body_query[1]
    setmetatable(resource_body, getmetatable(resource_body_parsed))
    return {{resource_key, resource_body}, nil}
  end

  kong.log.err('Invalid response from upstream resource ', resource_key, ' Multiple data data_len: ', resource_body_query)
  return {nil, create_error_response('can handle response', req_uri, res.status, resource_body_parsed)}
end

local function query_json(json_body, resource_path, resource_key)
  if resource_path == nil then
    return {{}, resource_key}
  end
  local ids, err = jp.query(json_body, resource_path)
  if err ~= nil then
    return {{}, resource_key}
  end
  return {ids, resource_key}
end

function _M.transform_json_body(keys_to_extend, upstream_body, http_config)
  local resources = {}
  local threads_json_query = {}
  -- prepare threads to find ids to query resources
  for i = 1, #keys_to_extend do
    local v = keys_to_extend[i]
    resources[v.resource_key] =  {
      config = v
    }
    insert(threads_json_query, spawn(query_json, upstream_body, v.resource_id_path, v.resource_key))
  end

  for i = 1, #threads_json_query do
    local ok, res = wait(threads_json_query[i])
    if not ok then
      kong.log.err('Threads wait err: ', res)
      return false, res
    end
    local ids, resource_key = unpack(res)
    resources[resource_key].ids = ids
    resources[resource_key].ids_len = #ids
  end

  -- prepare threads to call resources for data
  local threads = {}

  for resource_key, value in pairs(resources) do
    insert(threads, spawn(fetch, resource_key, value, http_config))
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
    local resource_key, resource_body = unpack(result)
    local resource = resources[resource_key]
    local config = resource.config
    -- if response is an array we should use set_in_table_arr
    -- multiple resources

    if resource_body == nil and config.resource_id_optional == true then
      kong.log.warn('Resource id is missing and it is allowed by config. return upstream body', resource_key, ' api: ', config.api.url, ' res_body: nil')
      return true, upstream_body
    end

    if utils.is_array(upstream_body, 'fast') then
      local ok, err = set_in_table_arr(resource_key, upstream_body, resource_body, config)
      if not ok then
        return false, create_error_response(err, config.api.url, 200, resource_body)
      end
    else
      if resource_body == nil and config.allow_missing == false then
        kong.log.err('Missing data for resource ', resource_key, ' api: ', config.api.url, ' res_body: nil')
        return false, err
      end
      set_in_table(resource_key, upstream_body, resource_body, resource)
    end
  end

  return true, upstream_body
end

return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
