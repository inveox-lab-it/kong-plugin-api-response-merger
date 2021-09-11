local body_transformer = require 'kong.plugins.api-response-merger.body_transformer'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
local common_plugin_status, common_plugin_headers = pcall(require, 'kong.plugins.common.headers')
local cjson = require('cjson.safe').new()
cjson.decode_array_with_array_mt(true)
local start_timer = monitoring.start_timer

local is_json_body = body_transformer.is_json_body
local kong = kong
local ngx = ngx
local http = require 'resty.http'
local match = ngx.re.match

local APIResponseMergerHandler = {}

local function contains(arr, search)
  for i = 1, #arr do
    if arr[i] == search then
      return true
    end
  end
  return false
end

function APIResponseMergerHandler:access(conf)
  local request = kong.request
  local response = kong.response
  local upstream = conf.upstream
  local http_config = conf.http_config

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local req_headers = request.get_headers()
  req_headers['host'] = upstream.host_header
  if common_plugin_status then
    local upstream_headers = common_plugin_headers.get_upstream_headers(request)
    for h, v in pairs(upstream_headers) do
      if req_headers[h] == nil then
        req_headers[h] = v
      end
    end
    req_headers['user-agent'] = upstream_headers['user-agent']
  end
  local req_method = request.get_method()
  -- rewrite HEAD to GET to calcaulate correct content-length
  if req_method == 'HEAD' then
    req_method = 'GET'
  end

  local req_path = request.get_path()
  local timer = start_timer(upstream.uri)
  local res, err = client:request_uri(upstream.uri .. (conf.upstream.path_prefix or '') .. req_path, {
    method = req_method,
    headers = req_headers,
    query = request.get_raw_query(),
    body = request.get_raw_body()
  })
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)
  timer:stop()

  if not res then
    kong.log.err('Invalid response from upstream ', upstream.uri .. req_path .. ' err: ' .. err)
    return response.exit(500, {message=err})
  end

  res.headers['Transfer-Encoding'] = nil
  if res.status > 499 then
    kong.log.err('Invalid response from upstream  ', upstream.uri, ' sc: ', res.status)
    return response.exit(res.status, res.body, res.headers)
  end

  if not conf.paths then
    return response.exit(res.status, res.body, res.headers)
  end

  local resources_to_extend = nil
  local data_path = '$'
  local paths = conf.paths
  for i = 1, #paths do
    local path = paths[i]
    if match(req_path, path.path, 'io') then
        if contains(path.methods, req_method) then
          resources_to_extend = path.resources_to_extend
          data_path = path.upstream_data_path
          break
        end
    end
  end
  if resources_to_extend ~= nil and is_json_body(res.headers['content-type']) then
    local data = cjson.decode(res.body)
    local data_to_transform = jp.query(data, data_path)

    if data_to_transform == nil or #data_to_transform ~= 1 then
      kong.log.warn('No data to transform in path ', data_path)
      return response.exit(res.status, res.body, res.headers)
    end
    local ok, result = body_transformer.transform_json_body(resources_to_extend, data_to_transform[1], http_config)
    if not ok then
      return response.exit(500, result)
    end


    if data_path == '$' then
      data = result
    else
      body_transformer.set_for_path({path = data_path} , data, result)
    end

    local data_json = cjson.encode(data)
    return response.exit(res.status, data_json, res.headers)
  else
    kong.log.warn('No match', req_path)
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
