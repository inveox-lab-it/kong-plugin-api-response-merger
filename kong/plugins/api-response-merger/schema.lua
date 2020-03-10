local api_type = {
  required = true,
  type = "record",
  fields = {
    { url = {
      type = "string",
      required = true
    }},
    { data_path = {
      type = "string",
      default = "$"
    }},
    { query_param_name = {
      type = "string",
      required = false
    }}, 
    { id_key = {
      type = "string"
    }}
  }
}

local keys_to_extend_type ={ 
  required = false,
  type = "array",
  default = {},
  elements = {
    type = "record",
    fields = {
      { resource_id_path = {
        required = true,
        type = "string"
      }},
      { resource_key = {
        required = true,
        type = "string"
      }},
      { api = api_type }
    }
  }
}

return {
  name = "api-response-merger",
  fields = {
    {config = {
      type = "record",
      fields = {
        { http_config = {
          type = "record",
          fields = {
            { connect_timeout = { default = 1000, type = "number" }},
            { send_timeout = { default = 6000, type = "number" }},
            { read_timeout = { default = 6000, type = "number" }},
            { keepalive_timeout = { default = 60, type = "number" }},
            { keepalive_pool_size = { default = 1000, type = "number" }},
          }
        }},
        { upstream = {
          type = "record",
          required = true,
          fields = {
            { host_header = { required = true, type = "string"}},
            { path_prefix = { required = false, type = "string"}},
            { uri = { required = true, type = "string" }},
          }
        }},
        { paths = {
          required = false,
          type = "array",
          elements = {
            type = "record",
            fields = {
              { path = { type = "string", default = "/" }},
              { upstream_data_path = { type = "string", default = "$" }},
              { keys_to_extend = keys_to_extend_type }
            }
          }
        }}
      }
    }}
  }
}
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
