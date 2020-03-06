local cjson = require("cjson.safe").new()
local utils = require 'kong.tools.utils'
local http = require 'resty.http'
local jp = require 'kong.plugins.response-transformer-inveox.jsonpath'
local split = utils.split
local kong = kong

local find = string.find
local type = type
local sub = ngx.re.sub
local lower = string.lower
local spawn = ngx.thread.spawn
local wait = ngx.thread.wait
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
  return content_type and find(lower(content_type), "application/json", nil, true)
end

local function is_json_path_array(str) 
  return find(str, '..', nil, true) or find(str, '[*]', nil, true )
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
  if path_len == 0 then
    table = vale
    return
  end

  if paths_len == 1 then
    table[path] = value
    return
  end

  local current = table[paths[1]]
  for i = 2, paths_len - 2 do
    current = current[path[i]]
  end
  current[path] = value
end
_M.set_in_table = set_in_table

local function fetch(rK, rV, json_body, http_config) 
  local req_query = '?'
  local config = rV.config
  local req_uri = config.apiUrl
  local ids_len = #rV.ids
  if ids_len  > 1 then
    local query_join = ''
    for _, id in ipairs(rV.ids) do
      req_query = req_query .. query_join .. config.apiResourceName .. '=' .. id
      query_join = '&'
    end
    req_query = req_query .. '&size=' .. (ids_len + 1)
  else
    req_uri = req_uri .. rV.ids[1]
  end

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local res, err = client:request_uri(req_uri, {
    query = req_query,
    headers = kong.request.get_headers(),
  })
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)
  if not res then
    kong.log.err('Invalid response from upstream resource ', req_path, ' ', err)
    return {false, err}
  end

  if res.status ~= 200 then
    kong.log.err('reqPath '.. req_path .. 'Not 200 ' .. res.status .. " " .. " body: " .. res.body)
    return {false, res.body}
  end

  local resource_body_parsed = read_json_body(res.body)
  
  local resource_body_query = jp.query(resource_body_parsed, config.responseDataPath)
  if #resource_body_query == 1 then
    local resource_body = resource_body_query[1]
    setmetatable(resource_body, getmetatable(resource_body_parsed))
    return {true, {rK, config, resource_body}}
  end
  return {false, 'something wrong'}
end

local function query_json(json_body, resource_path, resourceKey)
  local ids = jp.query(json_body, resource_path)
  return  {ids, resourceKey}
end

function _M.transform_json_body(keys_to_extend, buffered_data, http_config)
  local json_body = buffered_data
  local resources = {}
  local threadsJson = {}
  for k, v in ipairs(keys_to_extend) do
    resources[v.resourceKey] =  {
      config = v
    }
    insert(threadsJson, spawn(query_json, json_body, v.resourceIdKey, v.resourceKey))
  end

  for i = 1, #threadsJson do
    local ok, res = wait(threadsJson[i])
    if not ok then
      kong.log.err('Threads wait err', res)
      return false, res
    end
    local ids, resourceIdKey = unpack(res)
    resources[resourceIdKey]['ids'] = ids
  end

  local threads = {}

  for rK, rV in pairs(resources) do
    insert(threads, spawn(fetch, rK, rV, json_body, http_config))
  end

  for i = 1, #threads do
    local ok, res = wait(threads[i])
    if not ok then
      kong.log.err('Threads wait err', res)
      return false, res
    end
    local status, result = unpack(res)
    if not status then
      kong.log.err('Error in fetching', result)
      return false, result
    end
    local rK, config, resource_body = unpack(result)
    if is_json_path_array(rK) then
      set_in_table_arr(rK, json_body, resource_body, config.resourceName, config.resourceIdKey)
    else 
      set_in_table(rK, json_body, resource_body)
    end
  end

  return true, json_body
end


return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
