local helpers = require "spec.helpers"
local cjson = require "cjson"

local function http_server_with_body(port, body)
  local threads = require "llthreads2.ex"
  local thread = threads.new({
    function(port, body)
      local socket = require "socket"
      local server = assert(socket.tcp())
      assert(server:setoption('reuseaddr', true))
      assert(server:bind("*", port))
      assert(server:listen())
      local client = assert(server:accept())


      local lines = {}
      local line, err
      while #lines < 3 do
        line, err = client:receive()
        if err then
          break
        else
          table.insert(lines, line)
        end
      end

      -- client:send("HTTP/1.1 200 OK\r\nConnection: close\r\n\r\n dupa8")
      client:send("HTTP/1.1 200 OK\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: " .. #body.. "\r\n\r\n"..body)
      client:close()
      server:close()
      -- return body
    end
  }, port, body)

  return thread:start()
end


describe("Plugin: api-response-merger access", function()
  local proxy_client
  local service_a
  local upstream_port = 16566
  local service_a_port = 16666
  local service_b
  local service_b_port = 27777

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
    local upstream_body =  { a = { id = 'resource_a_id'}, baz = "cux" }
    local upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    print(upstream)
    local service_a = http_server_with_body(service_a_port, '{ "id": "resource_a_id", "value": "important"}')
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

  it("sends data immediately after a request", function()
    local upstream_body =  { a = { id = 'resource_a_id'}, baz = "cux" }
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
end)
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
