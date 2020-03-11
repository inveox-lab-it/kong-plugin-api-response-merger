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
local unpack = unpack or table.unpack

cjson.decode_array_with_array_mt(true)

local _M = {}

local function read_json_body(body)
  if body then
    return cjson.decode(body)
  end
end

function _M.is_json_body(content_type)
  return content_type and find(lower(content_type), 'application/json', nil, true)
end

local function set_in_table_arr(path, table, value, src_resource_name, des_resource_id_key)
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
    local id = v[src_resource_name]
    by_id[id] = v
  end

  for _, v in pairs(current) do
    local id = jp.query(v, des_resource_id_key)[1]
    v[dest_resource_key] = by_id[id]
  end
end

local function set_in_table(path, table, value)
  path = sub(path, '\\$\\.', '')
  local paths = split(path, '.')
  local paths_len = #paths
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
  current[path] = value
  return current
end
_M.set_in_table = set_in_table

local function fetch(resource_key, resource_config, http_config)
  local req_query = '?'
  local config = resource_config.config
  local api = config.api
  local req_uri = api.url
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
  elseif ids_len == 1 then
    req_uri = req_uri .. resource_config.ids[1]
  end

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local timer = start_timer(req_uri)
  local res, err = client:request_uri(req_uri, {
    query = req_query,
    headers = kong.request.get_headers(),
  })
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)
  timer:stop()
  if not res then
    kong.log.err('Invalid response from upstream resource url: ', req_uri , ' err: ', err)
    return {false, err}
  end

  if res.status ~= 200 then
    kong.log.err('Wrong response from upstream resource url: ', req_uri, ' status:  ', res.status)
    return {false, 'invalid response from upstream, sc: ' .. res.status}
  end

  local resource_body_parsed = read_json_body(res.body)
  if resource_body_parsed == nil then
    kong.log.err('Unable to parse response from ',  req_uri)
    return { false, 'unable to parse resource body'}
  end

  local resource_body_query = jp.query(resource_body_parsed, api.data_path)
  if resource_body_query ~= nil and #resource_body_query == 1 then
    local resource_body = resource_body_query[1]
    setmetatable(resource_body, getmetatable(resource_body_parsed))
    return {true, {resource_key, resource_body}}
  end

  kong.log.err('Invalid response from upstream resource ', resource_key, ' Multiple data data_len: ', resource_body_query)
  return {false, 'something wrong'}
end

local function query_json(json_body, resource_path, resource_key)
  if resource_path == nil then
    return {{}, resource_key}
  end
  local ids = jp.query(json_body, resource_path)
  return {ids, resource_key}
end

function _M.transform_json_body(keys_to_extend, upstream_body, http_config)
  local resources = {}
  local threads_json_query = {}
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
    local status, result = unpack(res)
    if not status then
      return false, result
    end
    local resource_key, resource_body = unpack(result)
    local resource = resources[resource_key]
    local config = resource.config
    if config.api.query_param_name ~= nil then
      set_in_table_arr(resource_key, upstream_body, resource_body, config.api.id_key, config.resource_id_path)
    else
      set_in_table(resource_key, upstream_body, resource_body)
    end
  end

  return true, upstream_body
end

return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
