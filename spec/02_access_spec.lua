local helpers = require "spec.helpers"
local cjson = require "cjson"

local function http_server_with_body(port, body, sc)
  if sc == nil then
    sc = "200 OK"
  end
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
      while line and line ~= ''  do
        line, err = client:receive()
        if err then
          break
        end
      end
      client:send("HTTP/1.1 ".. sc .."\r\nConnection: close\r\nContent-Type: application/json\r\nContent-Length: " .. #body.. "\r\n\r\n"..body)
      client:close()
      server:close()
    end
  }, port, body, sc)

  return thread:start(false, false)
end

describe("Plugin: api-response-merger access", function()
  local proxy_client
  local service_a
  local upstream_port = 16566
  local service_a_port = 16666
  local service_b
  local service_b_port = 27777
  local service_c
  local service_c_port = 27778
  local upstream
  local upstream_body =  { a = { id = 'resource_a_id'}, baz = "cux" }

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
            path = '/status/.+',
            methods = {'POST'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$.a.id',
                    path = '$.a'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_a_port,
                  id_key = 'id'
                }
              }
            }
          },
          {
            path = '/single-array',
            methods = {'POST'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$.a.id',
                    path = '$.a'
                  }
                },
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
            resources_to_extend = {
              {
                data_paths = {
                  {
                    path = '$.add'
                  }
                },
                add_missing = true,
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                }
              }
            }
          },
          {
            path = '/array',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$..b.id',
                    path = '$..b'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                  query_param_name = 'ids',
                  id_key = 'cfg'
                }
              }
            }
          },
          {
            path = '/multidatapaths',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$..b.id',
                    path = '$..b'
                  },
                  {
                    id_path = '$..d.id',
                    path = '$..d'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                  query_param_name = 'ids',
                  id_key = 'cfg'
                }
              }
            }
          },
          {
            path = '/missing-single',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$.b.id',
                    path = '$.b'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                  id_key = 'cfg'
                }
              }
            }

          },
          {
            path = '/resource-id-missing',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$.d.id',
                    path = '$.d'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_c_port,
                  id_key = 'org.name'
                }
              }
            }

          },
          {
            path = '/nestedkeyarray',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$..c.xid',
                    path = '$..c',
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_c_port,
                  query_param_name = 'ids',
                  id_key = 'org.name'
                }
              }
            }
          },
          {
            path = '/array-in-object',
            methods = {'POST'},
            upstream_data_path= "$", -- intentinally like this
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$..f.id',
                    path = '$..f'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_a_port,
                  id_key = 'id',
                  query_param_name = 'ids'
                }
              },
              {
                data_paths = {
                  {
                    id_path = '$.a.id',
                    path = '$.a'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_b_port,
                  id_key = 'id'
                }
              }
            }
          },
          {
            path = '/allow-missing',
            methods = {'GET'},
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$..c.xid',
                    path = '$..c'
                  }
                },
                allow_missing = true,
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_c_port,
                  query_param_name = 'ids',
                  id_key = 'org.name'
                }
              }
            }
          },
          {
            path = '/different-upstream',
            methods = {'POST'},
            upstream = {
              uri = 'http://' .. helpers.mock_upstream_host .. ':' .. service_b_port,
              host_header = helpers.mock_upstream_host,
            },
            upstream_data_path = '$',
            resources_to_extend = {
              {
                data_paths = {
                  {
                    id_path = '$.a.id',
                    path = '$.a'
                  }
                },
                api = {
                  url = 'http://' .. helpers.mock_upstream_host ..':' .. service_a_port,
                  id_key = 'id'
                }
              }
            }
          },
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

  it("should merge response from two services, resource as array", function()
    service_a = http_server_with_body(service_a_port, '[{ "id": "resource_a_id", "value": "important"}]')
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    helpers.wait_until(function()
      return service_a:alive() and upstream:alive()
    end, 1)
    local res = proxy_client:post("/single-array", {
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

  it("should merge response from two services - no id #only", function()
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

  it("should handle 500 error response from upstream", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    service_b = http_server_with_body(service_b_port, '{ "cfg": "config-id", "something": "important"}', "500 Internal Server Error")
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
    local body = assert.res_status(500, res)
    local json = cjson.decode(body)
    local expected = {
      message = 'can handle only responses with 200 sc',
      code = 'APIGatewayError',
      error = 'Resource fetch error',
      status = 500,
      errors = {{
          error = { cfg = "config-id", something = "important"},
          status = 500,
          uri = 'http://127.0.0.1:27777'
        }}
      }
    assert.same(expected, json)
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

  it("should handle invalid json from resource", function()
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_body))
    service_b = http_server_with_body(service_b_port, '{ "cfg": config-id", "something": "important"}')
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
    local body = assert.res_status(500, res)
    local json = cjson.decode(body)
    local expected = {
      message = 'unable to parse response',
      code = 'APIGatewayError',
      error = 'Resource fetch error',
      status = 500,
      errors  = {{
          error = '{ "cfg": config-id", "something": "important"}',
          status = 200,
          uri = 'http://127.0.0.1:27777'
        }}
      }
    assert.same(expected, json)
  end)

  it("should handle empty array respopnse", function()
    local array = {{
     b = {}
    }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_b = http_server_with_body(service_b_port, '', '404 Not found')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)
    helpers.wait_until(function()
      return upstream:alive()
    end, 1)

    local res = proxy_client:get("/array", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)

    assert.same(array, json)
  end)

  it("should handle array response", function()
    local array = {{
      b = {
        id = 'cfg-id',
      },
      foo = 'bar'
    }, {
      b = {
        id = 'cfg-id-2',
      },
      foo = 'bar-sec'
    }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_b = http_server_with_body(service_b_port, '[{ "cfg": "cfg-id", "something": "important"}, {"cfg":"cfg-id-2", "dog": "cat"}]')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/array", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    local expected = {
      { b = {
          cfg = 'cfg-id',
          something = 'important'
        },
      foo = 'bar',
     }, {
      b = {
        cfg = 'cfg-id-2',
        dog = 'cat'
      },
      foo = 'bar-sec'
    }}
    assert.same(expected, json)
  end)

  it("should handle multi data path response", function()
    local array = {{
                     b = {
                       id = 'cfg-id',
                     },
                     foo = 'bar'
                   }, {
                     d = {
                       id = 'cfg-id-2',
                     },
                     foo = 'bar-sec'
                   }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_b = http_server_with_body(service_b_port, '[{ "cfg": "cfg-id", "something": "important"}, {"cfg":"cfg-id-2", "dog": "cat"}]')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/multidatapaths", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    local expected = {
      { b = {
        cfg = 'cfg-id',
        something = 'important'
      },
        foo = 'bar',
      }, {
        d = {
          cfg = 'cfg-id-2',
          dog = 'cat'
        },
        foo = 'bar-sec'
      }}
    assert.same(expected, json)
  end)

  it("should handle multi data path response - when some data_paths are missing", function()
    local array = {{
                     b = {
                       id = 'cfg-id',
                     },
                     foo = 'bar'
                   }, {
                     foo = 'bar-sec'
                   }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_b = http_server_with_body(service_b_port, '[{ "cfg": "cfg-id", "something": "important"}, {"cfg":"cfg-id-2", "dog": "cat"}]')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/multidatapaths", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    local expected = {
      { b = {
        cfg = 'cfg-id',
        something = 'important'
      },
        foo = 'bar',
      }, {
        foo = 'bar-sec'
      }}
    assert.same(expected, json)
  end)

  it("should handle array response with nested key", function()
    local array = {{
      c = {
        xid = 'cfg-id',
      },
      foo = 'bar'
    }, {
      c = {
        xid = 'cfg-id-2',
      },
      foo = 'bar-sec'
    }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_c = http_server_with_body(service_c_port, '[{ "org":{"name": "cfg-id"}, "something": "important"}, {"org":{"name":"cfg-id-2"}, "dog": "cat"}]')
    helpers.wait_until(function()
      return service_c:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/nestedkeyarray", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)

    local expected = {
      { c = {
          org = {
            name = 'cfg-id',
          },
        something = 'important'
      },
      foo = 'bar',
    }, {
      c = {
        org = {
          name = 'cfg-id-2',
        },
        dog = 'cat'
      },
      foo = 'bar-sec'
    }}
    assert.same(expected, json)
  end)

  it("should allow missing key if allowed by config", function()
    local array = {{
      d = {
        xid = 'cfg-ida',
      },
      foo = 'bar'
    }, {
      foo = 'bar-sec'
    }}
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_c = http_server_with_body(service_c_port, '[{ "org":{"name": "cfg-id"}, "something": "important"}, {"org":{"name":"cfg-id-2"}, "dog": "cat"}]')
    helpers.wait_until(function()
      return service_c:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/allow-missing", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)

    assert.same(array, json)
  end)

  it("should handle missing data in array and return error #only", function()
    local array = {{
      b = {
        id = 'cfg-id',
      },
      foo = 'bar'
    }, {
      b = {
        id = 'not-found',
      },
      foo = 'bar-sec'
    }}
    local service_b_res = '[{ "cfg": "cfg-id", "something": "important"}, {"cfg":"cfg-id-2", "dog": "cat"}]'
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_b = http_server_with_body(service_b_port, service_b_res)
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/array", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(500, res)
    local json = cjson.decode(body)
    local expected = {
      message = 'missing data for key "b" (missing for id: "not-found")',
      code = 'APIGatewayError',
      error = 'Resource fetch error',
      status = 500,
      errors = {{
          error = cjson.decode(service_b_res),
          status = 200,
          uri = 'http://127.0.0.1:27777'
        }}
    }
    assert.same(expected, json)
  end)

  it("should return data on resource id optional", function()
    local array = {
      d = {  id = 'cfg-id' },
      foo = 'bar-sec'
    }
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_c = http_server_with_body(service_c_port, '{ "org":{"name": "cfg-id"}, "something": "important"}')
    helpers.wait_until(function()
      return service_c:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/resource-id-missing", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)

    local expected = {
       d = {
        org = {
          name = 'cfg-id',
        },
        something = 'important'
      },
        foo = 'bar-sec',
      }
    assert.same(expected, json)
  end)

  it("should allow resource id optional key if allowed by config", function()
    local array = {
      d = nil,
      foo = 'bar-sec'
    }
    upstream = http_server_with_body(upstream_port, cjson.encode(array))
    service_c = http_server_with_body(service_c_port, '[{ "org":{"name": "cfg-id"}, "something": "important"}, {"org":{"name":"cfg-id-2"}, "dog": "cat"}]')
    helpers.wait_until(function()
      return service_c:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/resource-id-missing", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)

    assert.same(array, json)
  end)

  it("should handle missing data(404) for single data and return error", function()
    local data = {
      b = {
        id = 'not-found',
      },
      foo = 'bar-sec'
    }
    upstream = http_server_with_body(upstream_port, cjson.encode(data))
    service_b = http_server_with_body(service_b_port, '', '404 Not found')
    helpers.wait_until(function()
      return service_b:alive() and upstream:alive()
    end, 1)

    local res = proxy_client:get("/missing-single", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
    })
    local body = assert.res_status(500, res)
    local json = cjson.decode(body)
    local expected = {
      message = 'can handle only responses with 200 sc',
      code = 'APIGatewayError',
      error = 'Resource fetch error',
      status = 500,
      errors = {{
          status = 404,
          uri = 'http://127.0.0.1:27777not-found',
          error = ''
        }}
    }
    assert.same(expected, json)
  end)

  it("should handle invalid json from upstream - do nothing", function()
    local ups_body = 'f---====aa"'
    upstream = http_server_with_body(upstream_port, ups_body)
    helpers.wait_until(function()
      return upstream:alive()
    end, 1)

    local res = proxy_client:post("/just-add", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_body
    })
    local body = assert.res_status(200, res)
    assert.same(body,  ups_body)
  end)

  it("should merge response from two services, resource as nested array in object", function()
    local upstream_local_body =  { arr = {{f={id="a1"}}, {f={id="a2"}}}, c = "important",a = { id = 'resource_a_id'}, }
    upstream = http_server_with_body(upstream_port, cjson.encode(upstream_local_body))

    service_a = http_server_with_body(service_a_port, '[{ "id": "a1", "v": "one" }, { "id": "a2", "v": "two" } ]')
    service_b = http_server_with_body(service_b_port, '{ "id": "resource_a_id", "value": "important"}')

    helpers.wait_until(function()
      return service_a:alive() and upstream:alive() and service_b:alive()
    end, 1)
    local res = proxy_client:post("/array-in-object", {
      headers = {
        host = "service.test",
        ["Content-Type"] = "application/json",
      },
      body = upstream_local_body
    })
    local body = assert.res_status(200, res)
    local json = cjson.decode(body)
    assert.same(
            {
              arr = {
                { f = { id = "a1", v = "one" } },
                { f = { id = "a2", v = "two" } }
              },
              c = "important",
              a = { id = 'resource_a_id', value = "important" }
            },
            json
    )
  end)

  it("should merge response from two services from different than default upstream", function()
    service_a = http_server_with_body(service_a_port, '{ "id": "resource_a_id", "value": "important"}')
    service_b = http_server_with_body(service_b_port, cjson.encode(upstream_body))
    helpers.wait_until(function()
      return service_a:alive() and service_b:alive()
    end, 1)
    local res = proxy_client:post("/different-upstream", {
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
