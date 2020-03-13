local url_parser = require 'socket.url'
-- FIXME: this should be changed after
-- https://github.com/Kong/kong-plugin-prometheus/pull/78 will be merged or
-- rejected
local status, prom_expo = pcall(require, 'kong.plugins.prometheus-inveox.exporter')

local metrics = nil
local function init() 
  if not status then
    return
  end
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

local timer = {}
local meta_timer = {__index = timer}
function timer.stop(self)
  local time = ngx.now() - self.start_time
  report_time(self.url, time)
end

local function start_timer(url) 
  return setmetatable({
    start_time = ngx.now(),
    url = url
  }, meta_timer)
end

return {
  start_timer = start_timer,
  init = init
}
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
