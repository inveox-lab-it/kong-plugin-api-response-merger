local transformer = require 'kong.plugins.api-response-merger.transformer'
local path_replacer = require 'kong.plugins.api-response-merger.path_replacer'
local upstream_caller = require 'kong.plugins.api-response-merger.upstream_caller'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
local cjson = require('cjson.safe').new()

local is_json_body = transformer.is_json_body
local kong = kong
local ngx = ngx
local match = ngx.re.match
--local gsub = ngx.re.gsub
local log = kong.log

cjson.decode_array_with_array_mt(true)

local APIResponseMergerHandler = {}

local function interp(s, tab)
  return (s:gsub('($%b{})', function(w) return tab[w:sub(3, -2)] or w end))
end

local function contains(arr, search)
  for i = 1, #arr do
    if arr[i] == search then
      return true
    end
  end
  return false
end

local function build_request_body(original_request_body, request_builder, caller)
  local request_body = original_request_body;
  if request_builder then
    if request_builder.overwrite_body then
      local captures = {}
      if request_builder.overwrite_body then
        for capture, value in pairs(request_builder.captures) do
          captures[''..capture] = value
        end
      end
      request_body = interp(request_builder.overwrite_body, captures)
    end

    if request_builder.resources_to_extend ~= nil and #request_builder.resources_to_extend > 0 then
      local data = cjson.decode(request_body)
      if not data then
        return nil, "Cannot extend resources in non-json request"
      end
      local ok, result = transformer.transform_json_body(request_builder.resources_to_extend, data, caller)
      if not ok then
        return nil, "Cannot transform request: " .. (result.message or 'Unknown error')
      end
      request_body = cjson.encode(result)
    end
  end
  return request_body, nil
end

local function create_simple_error_response(message)
  local err_res = {
    message = message,
    status = 500,
    error = 'Resource fetch error',
    code = 'APIGatewayError'
  }

  return err_res
end

function APIResponseMergerHandler:access(conf)
  local request = kong.request
  local response = kong.response
  local req_path = request.get_path()
  local req_method = request.get_method()
  -- rewrite HEAD to GET to calculate correct content-length
  if req_method == 'HEAD' then
    req_method = 'GET'
  end

  local upstream = conf.upstream
  local matchingPath = nil
  local request_builder = nil
  if conf.paths then
    local paths = conf.paths
    for i = 1, #paths do
      local path = paths[i]
      local captures = match(req_path, path.path, 'io')
      if match(req_path, path.path, 'io') then
        if contains(path.methods, req_method) then
          matchingPath = path
          upstream = path.upstream or upstream
          request_builder = path.request
          if request_builder then
            request_builder.captures = captures
          end
          break
        end
      end
    end
  end
  local http_config = conf.http_config
  upstream.method = upstream.method or req_method

  local caller = upstream_caller.create_caller(http_config)

  local req_headers = request.get_headers()
  req_headers['host'] = upstream.host_header
  local request_body, err = build_request_body(request.get_raw_body(), request_builder, caller)
  if err then
    log.err('Error for upstream ', ' err: ' .. err)
    return response.exit(500, create_simple_error_response(err))
  end

  req_path = upstream.path or req_path
  local res, err = caller:call(upstream.uri .. (conf.upstream.path_prefix or '') .. req_path,
          request.get_raw_query(),
          request_body,
          upstream.method,
          req_headers
  )

  if not res then
    log.err('Invalid response from upstream ', upstream.uri .. req_path .. ' err: ' .. err)
    return response.exit(500, create_simple_error_response(err))
  end

  res.headers['Transfer-Encoding'] = nil
  if res.status > 499 then
    log.err('Invalid response from upstream  ', upstream.uri, ' sc: ', res.status)
    return response.exit(res.status, res.body, res.headers)
  end

  if matchingPath == nil then
    log.warn('No match', req_path)
    return response.exit(res.status, res.body, res.headers)
  end

  local resources_to_extend = matchingPath.resources_to_extend
  local data_path = matchingPath.upstream_data_path or '$'

  if resources_to_extend ~= nil and #resources_to_extend > 0 and is_json_body(res.headers['content-type']) then
    local data = cjson.decode(res.body)
    local data_to_transform = jp.query(data, data_path)

    if data_to_transform == nil or #data_to_transform ~= 1 then
      log.warn('No data to transform in path ', data_path)
      return response.exit(res.status, res.body, res.headers)
    end
    local ok, result = transformer.transform_json_body(resources_to_extend, data_to_transform[1], caller)
    if not ok then
      return response.exit(500, result)
    end

    if data_path == '$' then
      data = result
    else
      path_replacer.set_for_path(data_path, data, result)
    end

    local data_json = cjson.encode(data)
    return response.exit(res.status, data_json, res.headers)
  end
  response.exit(res.status, res.body, res.headers)
end

function APIResponseMergerHandler.init_worker()
  monitoring.init()
end

APIResponseMergerHandler.PRIORITY = -100
APIResponseMergerHandler.VERSION = '1.2.1'

return APIResponseMergerHandler

-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
