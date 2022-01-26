local api_type = {
  required = true,
  type = "record",
  fields = {
    { url = {
      type = "string",
      required = true
    }},
    { host_header = {
      type = "string",
      required = false,
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

local data_paths_type = {
  required = false,
  type = "array",
  default = {},
  elements = {
    type = "record",
    fields = {
      { path = {
        required = true,
        type = "string"
      } },
      { id_path = {
        required = false,
        type = "string"
      } }
    }
  }
}

local resources_to_extend_type = {
  required = false,
  type = "array",
  default = {},
  elements = {
    type = "record",
    fields = {
      { data_paths = data_paths_type },
      { allow_missing = {
        required = false,
        type = "boolean",
        default = false
      }},
      { add_missing = {
        required = false,
        type = "boolean",
        default = false
      }},
      { api = api_type }
    }
  }
}

local request_builder = {
  required = false,
  type = "record",
  fields = {
    { overwrite_body = {
      type = "string",
      required = false
    }},
    { extend_with_auth_token = {
      required = false,
      type = "boolean",
      default = false
    }},
    { resources_to_extend = resources_to_extend_type }
  }
}

local upstream_fields = {
  { host_header = { required = true, type = "string"}},
  { path_prefix = { required = false, type = "string"}},
  { path = { required = false, type = "string"}},
  { uri = { required = true, type = "string" }},
  { method = { required = false, type = "string", one_of = {
    "GET",
    "POST",
    "PUT",
    "DELETE",
    "PATCH",
  } }},
}

local http_methods_arr_type = {
  type = "array",
  default = {"GET"},
  elements = {
    type = "string",
    one_of = {
      "GET",
      "POST",
      "PUT",
      "DELETE",
      "PATCH",
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
          fields = upstream_fields
        }},
        { paths = {
          required = false,
          type = "array",
          elements = {
            type = "record",
            fields = {
              { path = { type = "string", default = "/" }},
              { methods = http_methods_arr_type },
              { upstream = {
                type = "record",
                required = false,
                fields = upstream_fields
              }},
              { request = request_builder },
              { upstream_data_path = { type = "string", default = "$" }},
              { resources_to_extend = resources_to_extend_type }
            }
          }
        }}
      }
    }}
  }
}
-- vim: filetype=lua:expandtab:shiftwidth=2:tabstop=4:softtabstop=2:textwidth=80
