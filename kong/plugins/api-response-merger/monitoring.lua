local url_parser = require 'socket.url'
local prom_expo = require 'kong.plugins.prometheus-inveox.exporter'

local metrics = nil
local function init() 
  local prometheus = prom_expo.get_prometheus()
  if prometheus == nil then
      kong.log.warn('Prometheus plugin not enabled')
      return
  end
  metrics = {}
  metrics.upstream_response = prometheus:histogram('api_response_merger_request_times', 'histogram response time of endpoints', {'host'})
  metrics.upstream_response_gauge = prometheus:gauge('api_response_merger_request_time', 'response time of endpoints', {'host'})
end

local function report_time(url, time)
    if metrics == nil  then
        return
    end
    local host = url_parser.parse(url).host
    metrics.upstream_response:observe(time, {host})
    metrics.upstream_response_gauge:set(time, {host})
end

local function timer(url) 
    local start_time = nil
    local start_timer = function ()
        start_time = ngx.now()
    end

    local stop_timer = function () 
        local time = ngx.now() - start_time
        report_time(url, time)
    end

    return start_timer, stop_timer
end

return {
    timer = timer,
    init = init
}
