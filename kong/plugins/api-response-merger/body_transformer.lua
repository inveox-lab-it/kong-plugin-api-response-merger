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

cjson.decode_array_with_array_mt(true)

local _M = {}

local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
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

local function is_json_body(content_type)
  return content_type and find(lower(content_type), 'application/json', nil, true)
end
_M.is_json_body = is_json_body

-- This method can handle depth 2 and mode
local function set_in_table_arr(path, upstream_body, value, src_resource_name, resource_id_path)
  -- kong.log.warn('🍣 path:', path, ', upstream_body:', dump(upstream_body), ', value:', dump(value), ', src_resource_name:', src_resource_name, ', resource_id_path:', resource_id_path)
  if value == nil then
    return true, nil
  end

  local dest_resource_paths = jp.paths(upstream_body, path)
  local parsed_resource_id_path = jp.parse(resource_id_path)
  local external_resource_id_key = parsed_resource_id_path[#parsed_resource_id_path]
  -- print('external_resource_id_key:' .. external_resource_id_key)

  local by_id = {}

  for _, v in pairs(value) do
    local id = v[src_resource_name]
    by_id[id] = v
  end

  for i, dest_resource_path in pairs(dest_resource_paths) do
    -- print(i .. ' ' .. dump(dest_resource_path))
    local _dest_resource = upstream_body
    local _parent_of_dest_resource = _dest_resource
    local _external_key_to_dest_resource = nil
    for j, key_to_dest_resource in pairs(dest_resource_path) do
      if key_to_dest_resource == '$' then
        -- just skip
      else
        -- print('key_to_dest_resource: ' .. key_to_dest_resource .. ', _dest_resource:' .. dump(_dest_resource))
        if type(key_to_dest_resource) == 'number' then key_to_dest_resource = key_to_dest_resource + 1 end
        if j == #dest_resource_path then _parent_of_dest_resource = _dest_resource end
        _dest_resource = _dest_resource[key_to_dest_resource]
        _external_key_to_dest_resource = key_to_dest_resource
      end
    end
    -- print('_dest_resource: ' .. dump(_dest_resource))
    -- print('_parent_of_dest_resource: ' .. dump(_parent_of_dest_resource))
    -- print('external_resource_id_key: ' .. dump(external_resource_id_key))
    local _id = _dest_resource[external_resource_id_key]
    -- print('_external_key_to_dest_resource: '.. _external_key_to_dest_resource)
    -- print('_id: '.._id)
    _parent_of_dest_resource[_external_key_to_dest_resource] = by_id[_id] 
  end 

  return true, nil
end

-- This method can handle depth 2 and more
local function set_in_table(path, upstream_body, value, resource_id_path)
  -- kong.log.warn('🍺 path:', path, ', upstream_body:', dump(upstream_body), ', value:', dump(value), ', resource_id_path:', resource_id_path)
  if value == nil then
    return
  end

  local dest_resource_paths = jp.paths(upstream_body, path)
  local parsed_resource_id_path = jp.parse(resource_id_path)
  local external_resource_id_key = parsed_resource_id_path[#parsed_resource_id_path]
  -- print('external_resource_id_key:' .. external_resource_id_key)

  for i, dest_resource_path in pairs(dest_resource_paths) do
    print(i .. ' ' .. dump(dest_resource_path))
    local _dest_resource = upstream_body
    local _parent_of_dest_resource = _dest_resource
    local _external_key_to_dest_resource = nil
    for j, key_to_dest_resource in pairs(dest_resource_path) do
      if key_to_dest_resource == '$' then
        -- just skip
      else
        -- print('key_to_dest_resource: ' .. key_to_dest_resource .. ', _dest_resource:' .. dump(_dest_resource))
        if type(key_to_dest_resource) == 'number' then key_to_dest_resource = key_to_dest_resource + 1 end
        if j == #dest_resource_path then _parent_of_dest_resource = _dest_resource end
        _dest_resource = _dest_resource[key_to_dest_resource]
        _external_key_to_dest_resource = key_to_dest_resource
      end
    end
    -- print('_dest_resource: ' .. dump(_dest_resource))
    -- print('_parent_of_dest_resource: ' .. dump(_parent_of_dest_resource))
    -- print('external_resource_id_key: ' .. dump(external_resource_id_key))
    -- print('_external_key_to_dest_resource: '.. _external_key_to_dest_resource)
    _parent_of_dest_resource[_external_key_to_dest_resource] = value
  end 
end
_M.set_in_table = set_in_table

-- method used for calling services for given key
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
    req_query = req_query .. '&filter[limit]=' .. ids_len
    req_uri = req_uri .. req_query
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
    kong.log.err('404 response from upstream resource url: ', req_uri, ' status:  ', res.status)
    return {{resource_key, nil}, nil}
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
  local ids = jp.query(json_body, resource_path)
  -- print('ids: ' .. dump(ids))
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
    -- if no resource_id_path found, skip the resource_key
    if next(ids) == nil then
      kong.log.warn('No resource_id_path found skip: ', resource_key)
      resources[resource_key] = nil
      goto continue
    end
    resources[resource_key].ids = ids
    resources[resource_key].ids_len = #ids
    ::continue::
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
    -- if user passed query_param_name we assume that we should query for
    -- multiple resources
    if config.api.query_param_name ~= nil then
      local ok, err = set_in_table_arr(resource_key, upstream_body, resource_body, config.api.id_key, config.resource_id_path)
      if not ok then
        return false, create_error_response(err, config.api.url, 200, resource_body)
      end
    else
      set_in_table(resource_key, upstream_body, resource_body, config.resource_id_path)
    end
  end

  return true, upstream_body
end

return _M
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
