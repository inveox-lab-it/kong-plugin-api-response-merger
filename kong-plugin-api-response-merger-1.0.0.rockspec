package= "kong-plugin-api-response-merger"
version = "1.0.0"
description = {
  summary = "Kong plugin for merging respones from microservices",
  homepage = "http://github.com/inveox-lab-it/kong-plugin-api-response-merger",
  license = "MIT"
}
source = {
  url = "git://github.com/inveox-lab-it/kong-plugin-api-response-merger",
  tag = "1.0.00"
}
dependencies = {
    "resty.http",
    "cjson"
}
supported_platforms = {
  "linux", 
  "macosx"
}

local pluginName = package:match("^kong%-plugin%-(.+)$") 
build = {
    type = "builtin",
    modules = {
        ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
        ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
        ["kong.plugins."..pluginName..".body_transformer"] = "kong/plugins/"..pluginName.."/body_transformer.lua",
        ["kong.plugins."..pluginName..".jsonpath"] = "kong/plugins/"..pluginName.."/jsonpath.lua",
    }
}
