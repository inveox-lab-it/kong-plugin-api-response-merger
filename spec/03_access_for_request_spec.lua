local helpers = require "spec.helpers"
local cjson = require "cjson"

local function get_service_request(service)
  if service and service:alive() then
    local ok, ret = service:join()
    if not ok then
      return nil
    end
    return ret
  end
  return nil
end

local function http_server_with_body(port, body, sc)
  sc = sc or "200 OK"
  local threads = require "llthreads2.ex"
  local thread = threads.new({
    function(port, body, sc)
      local socket = require "socket"
      local server = assert(socket.tcp())
      assert(server:setoption('reuseaddr', true))
      local status = server:bind("*", port)
      while not status do
        status = server:bind("*", port)
      end
      assert(server:listen())
      server:settimeout(3)
      local client, err = server:accept()
      if err ~= nil then
        return
      end
      client:settimeout(3)

      local line
      line, err = client:receive()
      if err then
        print('error on read', err)
      end
      local method
      local method_ending, _ = string.find(line, ' ')
      if method_ending then
        method = string.sub(line, 1, method_ending - 1)
      end
      local request = ''
      local content_length = 0
      while line and line ~= ''  do
        local _, ending = string.find(line, 'content%-length:')
        if ending then
          content_length = tonumber(string.sub(line, ending + 2))
        end
        line, err = client:receive()
        if err then
          break
        end
      end
      if content_length > 0 then
        request = client:receive(content_length)
      end

      client:send("HTTP/1.1 " .. sc .. "\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: " .. #body .. "\r\n\r\n" .. body)
      client:close()
      server:close()
      return {
        method = method,
        request = request
      }
    end
  }, port, body, sc)

  return thread:start()
end

describe("Plugin: api-response-merger access for request", function()
  local proxy_client
  local service_a
  local upstream_port = 16566
  local service_a_port = 16666
  local service_b
  local service_b_port = 27777
  local service_c
  local service_c_port = 27778
  local upstream
  local upstream_body = { a = { id = 'resource_a_id' }, baz = "cux" }

  setup(function()
    local bp = helpers.get_db_utils(nil, {
      "routes",
      "services",
      "plugins",
    }, { "api-response-merger" })

    local service = bp.services:insert {
      host = helpers.mock_upstream_host,
      port = helpers.mock_upstream_port,
      protocol = helpers.mock_upstream_protocol,
    }

    bp.routes:insert {
      protocols = { "http" },
      hosts = { "service.test" },
      service = { id = service.id },
    }

    bp.plugins:insert {
      name = "api-response-merger",
      service = { id = service.id },
      config = {
        upstream = {
          uri = 'http://' .. helpers.mock_upstream_host .. ':' .. upstream_port,
          host_header = helpers.mock_upstream_host,
        },
        paths = {
          {
            path = '/pass_request',
            methods = { 'POST' },
            upstream_data_path = '$',
          },
          {
            path = '/change_request_method',
            methods = { 'PUT' },
            upstream_data_path = '$',
            upstream = {
              uri = 'http://' .. helpers.mock_upstream_host .. ':' .. upstream_port,
              method = 'POST',
              host_header = helpers.mock_upstream_host,
            },
          },
          {
            path = '/change_request_content',
            methods = { 'GET' },
            upstream_data_path = '$',
            upstream = {
              uri = 'http://' .. helpers.mock_upstream_host .. ':' .. upstream_port,
              method = 'POST',
              host_header = helpers.mock_upstream_host,
            },
            request = {
              overwrite_body = '{ "x" : 123 }'
            }
          },
          {
            path = '/change_request_with_templating/(.*)',
            methods = { 'GET' },
            upstream_data_path = '$',
            upstream = {
              uri = 'http://' .. helpers.mock_upstream_host .. ':' .. upstream_port,
              method = 'POST',
              host_header = helpers.mock_upstream_host,
            },
            request = {
              overwrite_body = '{ "x" : "${1}" }'
            }
          },
          {
            path = '/change_request_with_templating_with_naming/(?<id>.*)',
            methods = { 'GET' },
            upstream_data_path = '$',
            upstream = {
              uri = 'http://' .. helpers.mock_upstream_host .. ':' .. upstream_port,
              method = 'POST',
              host_header = helpers.mock_upstream_host,
            },
            request = {
              overwrite_body = '{ "x" : "${id}" }'
            }
          }
        }
      }
    }

    assert(helpers.start_kong {
      nginx_conf = "spec/fixtures/custom_nginx.template",
      plugins = "bundled,api-response-merger",
    })
    proxy_client = helpers.proxy_client()
  end)

  teardown(function()
    if proxy_client then
      proxy_client:close()
    end
    helpers.stop_kong()
  end)

  after_each(function()
    if upstream and upstream:alive() then
      upstream:join()
    end

    if service_a and service_a:alive() then
      service_a:join()
    end

    if service_b and service_b:alive() then
      service_b:join()
    end

    if service_c and service_c:alive() then
      service_c:join()
    end

    upstream = nil
    service_a = nil
    service_b = nil
    service_c = nil
    collectgarbage()
  end)

  it("should pass request", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body), "200 OK")
    helpers.wait_until(function()
      return upstream:alive()
    end, 3)
    local res = proxy_client:post("/pass_request", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    assert.res_status(200, res)

    local upstream_request = get_service_request(upstream)
    local req_json = cjson.decode(upstream_request.request)
    assert.same('POST', upstream_request.method)
    assert.same(upstream_body, req_json)
  end)

  it("should pass request and change request method", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body), "200 OK")
    helpers.wait_until(function()
      return upstream:alive()
    end, 3)
    local res = proxy_client:put("/change_request_method", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    assert.res_status(200, res)

    local upstream_request = get_service_request(upstream)
    local req_json = cjson.decode(upstream_request.request)
    assert.same('POST', upstream_request.method)
    assert.same(upstream_body, req_json)
  end)

  it("should change request content", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body), "200 OK")
    helpers.wait_until(function()
      return upstream:alive()
    end, 3)
    local res = proxy_client:get("/change_request_content", {
      headers = {
        host = "service.test"
      }
    })
    assert.res_status(200, res)

    local upstream_request = get_service_request(upstream)
    assert.same('POST', upstream_request.method)
    local req_json = cjson.decode(upstream_request.request)
    assert.same({ x = 123 }, req_json)
  end)

  it("should change request content with templating", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body), "200 OK")
    helpers.wait_until(function()
      return upstream:alive()
    end, 3)
    local res = proxy_client:get("/change_request_with_templating/1232-323-2", {
      headers = {
        host = "service.test"
      }
    })
    assert.res_status(200, res)

    local upstream_request = get_service_request(upstream)
    assert.same('POST', upstream_request.method)
    local req_json = cjson.decode(upstream_request.request)
    assert.same({ x = "1232-323-2" }, req_json)
  end)

  it("should change request content with templating with naming", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body), "200 OK")
    helpers.wait_until(function()
      return upstream:alive()
    end, 3)
    local res = proxy_client:get("/change_request_with_templating_with_naming/1232-323-2-123", {
      headers = {
        host = "service.test"
      }
    })
    assert.res_status(200, res)

    local upstream_request = get_service_request(upstream)
    assert.same('POST', upstream_request.method)
    local req_json = cjson.decode(upstream_request.request)
    assert.same({ x = "1232-323-2-123" }, req_json)
  end)

end)
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
