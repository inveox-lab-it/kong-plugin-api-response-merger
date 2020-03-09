local body_transformer = require 'kong.plugins.api-response-merger.body_transformer'
local jp = require 'kong.plugins.api-response-merger.jsonpath'
local cjson = require('cjson.safe').new()
cjson.decode_array_with_array_mt(true)

local is_json_body = body_transformer.is_json_body
local kong = kong
local ngx = ngx
local http = require 'resty.http'
local match = ngx.re.match

local APIResponseMergerHandler = {}

function APIResponseMergerHandler:access(conf)
  local request = kong.request
  local response = kong.response
  local upstream = conf.upstream
  local http_config = conf.http_config

  local client = http.new()
  client:set_timeouts(http_config.connect_timeout, http_config.send_timeout, http_config.read_timeout)
  local req_headers = request.get_headers()
  req_headers['host'] = upstream.host_header
  local req_method = request.get_method()
  -- rewrite HEAD to GET to calcaulate correct content-length
  if req_method == 'HEAD' then
    req_method = 'GET'
  end

  local req_path = request.get_path()
  local res, err = client:request_uri(upstream.uri .. req_path, {
    method = req_method,
    headers = req_headers,
    query = request.get_raw_query(),
    body = request.get_raw_body()
  })
  client:set_keepalive(http_config.keepalive_timeout, http_config.keepalive_pool_size)

  if not res then
    kong.log.err('Invalid response from upstream', upstream.uri .. req_path .. ' ' .. err)
    return response.exit(500, {message=err})
  end

  if res.status ~= 200 then
    kong.log.err('Not 200 ' .. res.status .. ' ' .. ' body: ' .. res.body)
    return response.exit(res.status, res.body, res.headers)
  end

  local keys_to_extend = nil
  local data_path = '$'
  for _, path in ipairs(conf.paths) do
    if match(req_path, path.path, 'io') then
      keys_to_extend = path.keys_to_extend
      data_path = path.upstream_data_path
      break
    end
  end

  if keys_to_extend ~= nil and is_json_body(res.headers['content-type']) then
    local data = cjson.decode(res.body)
    local data_to_transform = jp.query(data, data_path)
    if #data_to_transform ~= 1 then
      kong.log.warn('No data to transform in path ', data_path)
      return response.exit(res.status, res.body, res.headers)
    end

    local ok, result = body_transformer.transform_json_body(keys_to_extend, data_to_transform[1], http_config)
    if not ok then
      return response.exit(500, result)
    end
    if data_path == '$' then
      data = result
    else
      body_transformer.set_in_table(data_path, data, result)
    end
    local data_json = cjson.encode(data)
    local res_headers = res.headers
    res_headers['Transfer-Encoding'] = nil
    return response.exit(res.status, data_json, res_headers)
  else
    kong.log.warn('No match', req_path)
  end
  response.exit(res.status, res.body, res.headers)
end

APIResponseMergerHandler.PRIORITY = 1000
APIResponseMergerHandler.VERSION = '1.0.0'

return APIResponseMergerHandler

-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
