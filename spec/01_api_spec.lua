local helpers = require 'spec.helpers'

describe('Plugin: api-response-merger API', function()
  local admin_client
  setup(function()
    helpers.get_db_utils()
    assert(helpers.start_kong({
      plugins = "bundled, api-response-merger",
    }))

    admin_client = helpers.admin_client()
  end)
  teardown(function()
    if admin_client then
      admin_client:close()
    end

    helpers.stop_kong()
  end)

  it('plugin can\'t be configured with wrong spec', function()
    local res = assert(admin_client:send {
      method = 'POST',
      path = '/plugins',
      body = {
        name = 'api-response-merger'
      },
      headers = {
        ['content-type'] = 'application/json'
      }
    })
    assert.res_status(400, res)
  end)

  it('plugin can be configured full config', function()
    local res = assert(admin_client:send {
      method = 'POST',
      path = '/plugins',
      body = {
        name = 'api-response-merger',
        config = {
          upstream = {
            uri = 'http://upstream',
            host_header = 'upstream'
          },
          paths = {
            {
              path = '/v1/resources/.+',
              methods = {'GET'},
              resources_to_extend = {
                {
                  data_paths = {
                    {
                      path = '$.a',
                      id_path = '$.a.id'
                    }
                  },
                  allow_missing = true,
                  api = {
                    url = 'http://service-a/v1/a/',
                    id_key = 'a'
                  }
                }
              }

            },
            {
              path = '/v1/request/.+',
              methods = {'GET'},
              upstream = {
                uri = 'http://request-upstream',
                method = 'POST',
                host_header = 'request-upstream'
              },
              request = {
                overwrite_body = [[
                {
                  "x": {
                    "id": 123,
                  },
                  "y": "newVal"
                }
                ]],
                resources_to_extend = {
                  {
                    data_paths = {
                      {
                        path = '$.x',
                        id_path = '$.x.id'
                      }
                    },
                    api = {
                      url = 'http://service-a/v1/x/',
                      id_key = 'x'
                    }
                  }
                },
              },
              resources_to_extend = {
                {
                  data_paths = {
                    {
                      path = '$.a',
                      id_path = '$.a.id'
                    }
                  },
                  allow_missing = true,
                  api = {
                    url = 'http://service-a/v1/a/',
                    id_key = 'a'
                  }
                }
              }

            }
          }
        }
      },
      headers = {
        ['content-type'] = 'application/json'
      }
    })
    assert.res_status(201, res)
  end)

end)
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
