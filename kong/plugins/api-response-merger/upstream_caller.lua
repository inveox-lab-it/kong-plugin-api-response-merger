local kong = kong
local http = require 'resty.http'
local common_plugin_status, common_plugin_headers = pcall(require, 'kong.plugins.common.headers')
local monitoring = require 'kong.plugins.api-response-merger.monitoring'
local start_timer = monitoring.start_timer
local cjson = require('cjson.safe').new()
local url = require "socket.url"

local caller = {}
local meta_caller = {__index = caller}
local parsed_urls_cache = {}

-- Parse host url.
-- @param `url` host url
-- @return `parsed_url` a table with host details:
-- scheme, host, port, path, query, userinfo
local function parse_url(host_url)
  local parsed_url = parsed_urls_cache[host_url]

  if parsed_url then
    return parsed_url
  end

  parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == "http" then
      parsed_url.port = 80
    elseif parsed_url.scheme == "https" then
      parsed_url.port = 443
    end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end

  parsed_urls_cache[host_url] = parsed_url

  return parsed_url
end


local function modify_request_headers_based_on_request_body(req_headers, request_body)
  if request_body and cjson.decode(request_body) then
    req_headers["content-type"] = "application/json"
  end
  req_headers['content-length'] = #(request_body or '')
end

function caller.call(self, req_uri, req_query, body, method, req_headers)
  req_headers = req_headers or kong.request.get_headers()
  method = method or 'GET'
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
  modify_request_headers_based_on_request_body(req_headers, body)
  -- when using istio sidecar host header have to be passed explicite
  if req_headers['host'] == nil then
    local parsed_url = parse_url(req_uri)
    local host = parsed_url.host
    req_headers['host'] = host
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