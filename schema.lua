local keys_to_extend_type ={ 
     required = false,
     type = "array",
     default = {},
     elements = {
       type = "record",
       fields = {
           { resourceKey = {
               required = false,
               type = "string"
           }},
           { resourceIdKey = {
               required = false,
               type = "string"
           }},
           { resourceName = {
               required = false,
               type = "string"
           }},
           { responseDataPath = {
               required = false,
               type = "string"
           }},
           { apiUrl = {
               required = false,
               type = "string"
           }},
            { apiResourceName = {
                required = false,
                type = "string"
            }}
       }
     }
 }

return {
  name = "response-transformer-inveox",
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
                    { data_path  = { type = "string", default = "$" }},
                    { keys_to_extend = keys_to_extend_type }
                }
            }
         }}
    }
  }}
  }
}
