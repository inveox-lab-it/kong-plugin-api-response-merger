local helpers = require 'spec.helpers'
local cjson   = require 'cjson'

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
              keys_to_extend = {
                {
                  resource_id_path = '$.a.id',
                  resource_key = '$.a',
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
