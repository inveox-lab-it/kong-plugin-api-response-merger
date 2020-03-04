local cjson = require("cjson.safe").new()
local utils = require 'kong.tools.utils'
local jp = require 'kong.plugins.response-transformer-inveox.jsonpath'
local split = utils.split
local kong = kong
local kong_log_warn = kong.log.warn
local kong_log_err = kong.log.err

local find = string.find
local type = type
local sub = ngx.re.sub
local gsub = ngx.re.gsub
local match = string.match
local lower = string.lower


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
  kong_log_err('path before ', paths)
  path = sub(path, '\\$\\.\\.', '')
  path = sub(path, '\\$\\.', '')
  local paths = split(path, '.')
  local paths_len = #paths

  local current = table
  local by_id = {}
  local dest_resource_key = path
  kong_log_err('paths', paths)
  kong_log_err('path ', paths)
  if paths_len > 0 then
    dest_resource_key = paths[1]
  end
    


  for _, v in pairs(value) do
    local id = v[src_resource_name]
    by_id[id] = v
  end

  kong_log_err('path2', dest_resource_key)
  for _, v in pairs(current) do
    local id =  jp.query(v, des_resource_id_key)[1]
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

function _M.transform_json_body(client, keys_to_extend, buffered_data)
  local json_body = buffered_data
  local resources = {}
  for k, v in ipairs(keys_to_extend) do
    resources[v.resourceKey] =  {
      config = v,
      ids = jp.query(json_body, v.resourceIdKey)
    }
    kong_log_err('resources key ', v.resourceIdKey)
    kong_log_err('resources ', cjson.encode(resources))
  end

  for rK, rV in pairs(resources) do
    local req_query =  kong.request.get_raw_query()
    local config = rV.config
    local req_path = config.apiUrl
    if #rV.ids > 1 then
      local query_join = '&'
      if req_query == nil  or req_query == '' then
        req_query = '?'
        query_join = ''
      end
      for _, id in ipairs(rV.ids) do
        req_query = req_query .. query_join .. config.resourceName .. '=' .. id
        query_join = '&'
      end
    else
      req_path = req_path .. rV.ids[1]
    end
    local res, err = client:request_uri(req_path, {
      query = req_query,
      headers = kong.request.get_headers(),
    })
    if not res then
      kong_log_err('Invalid response from upstream resorce', req_path)
      return kong.response.exit(500, {message=err})
    end

    if res.status ~= 200 then
      kong_log_err('reqPath '.. req_path .. 'Not 200 ' .. res.status .. " " .. " body: " .. res.body)
      return kong.response.exit(res.status, {message=res.body})
    end

    local resource_body_parsed = read_json_body(res.body)
    
    local resource_body_query = jp.query(resource_body_parsed, config.responseDataPath)
    if #resource_body_query == 1 then
      local resource_body = resource_body_query[1]
      setmetatable(resource_body, getmetatable(resource_body_parsed))
      if is_json_path_array(rK) then
        set_in_table_arr(rK, json_body, resource_body, config.resourceName, config.resourceIdKey)
      else 
        set_in_table(rK, json_body, resource_body)
      end
    end
  end

  return json_body
end


return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
