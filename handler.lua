local body_transformer = require "kong.plugins.response-transformer-inveox.body_transformer"
local header_transformer = require "kong.plugins.response-transformer.header_transformer"
local jp = require 'kong.plugins.response-transformer-inveox.jsonpath'
local cjson = require("cjson.safe").new()

local is_json_body = header_transformer.is_json_body
local concat = table.concat
local kong = kong
local ngx = ngx
local http = require 'resty.http'
local kong_log_warn = kong.log.warn
local kong_log_err = kong.log.err
local match = ngx.re.match

local ResponseTransformerHandler = {}


function ResponseTransformerHandler:access(conf)
    local request = kong.request
    local upstream = conf.upstream
    
    local client = http.new()
    client:set_timeouts(conf.connect_timeout, conf.send_timeout, conf.read_timeout)
    local req_headers = request.get_headers()
    req_headers['host'] = upstream.host_header

    local req_path = request.get_path()
    local res, err = client:request_uri(upstream.uri .. req_path, {
      method = request.get_method(),
      headers = req_headers,
      query = request.get_raw_query(),
      body = request.get_raw_body()
    })
    
    if not res then
      kong_log_err('Invalid response from ustrepm', upstream.uri .. req_path .. ' ' ..err)
      return kong.response.exit(500, {message=err})
    end

    if res.status ~= 200 then
      kong_log_err('Not 200 ' .. res.status .. " " .. " body: " .. res.body)
      return kong.response.exit(res.status, {message=res.body})
    end

  local keys_to_extend = nil
  local data_path = '$'
  for _, path in ipairs(conf.paths) do
    if match(req_path, path.path, 'io') then
        keys_to_extend = path.keys_to_extend
        data_path = path.data_path
        break
    end
  end

  if keys_to_extend ~= nil and is_json_body(res.headers['content-type']) then
      -- local body, err = res:read_body()
      --  res:read_trailers()
      -- if err then
      --   kong_log_err('error reading obud', err)
      --   return kong.response.exit(500, {message=err})
      -- end
      local data = cjson.decode(res.body)
      local data_to_transform = jp.query(data, data_path)
      local body_transformed = body_transformer.transform_json_body(client, keys_to_extend, data_to_transform[1])
      if data_path == '$' then
          data = body_transformed
      else 
        body_transformer.set_in_table(data_path, data, body_transformed)
      end
      local data_json = cjson.encode(data)
      local res_headers = res.headers
      res_headers['content-lenght'] = string.len(data_json)
      res_headers['Transfer-Encoding'] = nil
      return kong.response.exit(res.status, data_json, res_headers)
  else 
      kong_log_err('No match', req_path)
  end
  kong.response.exit(res.status, res.body, res.headers)
end


ResponseTransformerHandler.PRIORITY = 1300
ResponseTransformerHandler.VERSION = "1.0.0"


return ResponseTransformerHandler

