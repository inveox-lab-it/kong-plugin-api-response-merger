local helpers = require "spec.helpers"
local cjson = require "cjson"
local socket = require "socket"

local function http_server_with_body(port, body)
  local threads = require "llthreads2.ex"
  local thread = threads.new({
    function(port, body)
      local socket = require "socket"
      local cjson = require "cjson"
      local server = assert(socket.tcp())
      assert(server:setoption('reuseaddr', true))
      local status = server:bind("*", port)
      while not status do
          status = server:bind("*", port)
      end
      assert(server:listen())
      server:settimeout(4)
      local client, err = server:accept()
      if err ~= nil then
        return
      end
      client:settimeout(3)

      local lines = {}
      local line, err
      line, err = client:receive()
      while line and line ~= ''  do
        line, err = client:receive()
        if err then
          break
        end
      end
      client:send("HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: " .. #body.. "\r\n\r\n"..body)
      client:close()
      server:close()
    end
  }, port, body)

  return thread:start(false, false)
end



describe("Plugin: api-response-merger access", function()
  local proxy_client
  local service_a
  local upstream_port = 16566
  local service_a_port = 16666
  local service_b
  local service_b_port = 27777
  local upstream
  local upstream_body =  { a = { id = 'resource_a_id'}, baz = "cux" }

  setup(function()
    local bp = helpers.get_db_utils(strategy, {
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
            path = '/status/.+',
            methods = {'POST'},
            upstream_data_path = '$',
            keys_to_extend = {
              {
                resource_id_path = '$.a.id',
                resource_key = '$.a',
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_a_port,
                  id_key = 'id'
                }
              }
            }

          },
          {
            path = '/just-add',
            upstream_data_path = '$',
            methods = {'POST'},
            keys_to_extend = {
              {
                resource_key = '$.add',
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                }
              }
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

      upstream = nil
      service_a = nil
      service_b = nil
      collectgarbage()
  end)

  before_each(function()
  end)

  it("should merge response from two services", function()
    service_a = http_server_with_body(service_a_port, '{ "id": "resource_a_id", "value": "important"}')
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    helpers.wait_until(function()
      return service_a:alive() and upstream:alive()
    end, 1)
    local res = proxy_client:post("/status/200", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    assert.same({ a = { id = 'resource_a_id', value = 'important'}, baz = "cux" }, json)
  end)
  
  it("should do nothing when path do not match", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    service_a = http_server_with_body(service_a_port, '{ "id": "resource_a_id", "value": "important"}')
    helpers.wait_until(function()
      return service_a:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:post("/200", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    assert.same({ a = { id = 'resource_a_id'}, baz = "cux" }, json)
  end)
  
  it("should merge response from two services - no id", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    service_b = http_server_with_body(service_b_port, '{ "cfg": "config-id", "something": "important"}')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:post("/just-add", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    assert.same({ a = { id = 'resource_a_id' }, baz = "cux" , add = { cfg = "config-id", something = "important" }}, json)
  end)
  
end)
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
