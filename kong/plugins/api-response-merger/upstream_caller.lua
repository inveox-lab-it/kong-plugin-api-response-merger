local kong = kong
local http = require 'resty.http'
local common_plugin_status, common_plugin_headers = pcall(require, 'kong.plugins.common.headers')
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
local start_timer = monitoring.start_timer

local caller = {}
local meta_caller = {__index = caller}

function caller.call(self, req_uri, req_query, body, method, req_headers)
  req_headers = req_headers or kong.request.get_headers()
  local client = http.new()
  client:set_timeouts(self.http_config.connect_timeout, self.http_config.send_timeout, self.http_config.read_timeout)
  local timer = start_timer(req_uri)
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
    headers = req_headers,
    method = method,
    body = body
  })
  -- put connection to pool / we don't close it
  client:set_keepalive(self.http_config.keepalive_timeout, self.http_config.keepalive_pool_size)
  timer:stop()
  return res, err
end

local function create_caller(http_config)
  return setmetatable({
    http_config = http_config
  }, meta_caller)
end


return {
  create_caller = create_caller
}