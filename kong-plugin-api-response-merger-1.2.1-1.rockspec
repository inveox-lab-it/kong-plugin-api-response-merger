package= "kong-plugin-api-response-merger"
version = "1.2.1-1"
description = {
  summary = "Kong plugin for merging responses from microservices",
  homepage = "http://github.com/inveox-lab-it/kong-plugin-api-response-merger",
  license = "MIT"
}
source = {
  url = "git://github.com/inveox-lab-it/kong-plugin-api-response-merger",
  tag = "1.2.1"
}
dependencies = {}
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
        ["kong.plugins."..pluginName..".path_replacer"] = "kong/plugins/"..pluginName.."/path_replacer.lua",
        ["kong.plugins."..pluginName..".interpolator"] = "kong/plugins/"..pluginName.."/interpolator.lua",
        ["kong.plugins."..pluginName..".transformer"] = "kong/plugins/"..pluginName.."/transformer.lua",
        ["kong.plugins."..pluginName..".upstream_caller"] = "kong/plugins/"..pluginName.."/upstream_caller.lua",
        ["kong.plugins."..pluginName..".jsonpath"] = "kong/plugins/"..pluginName.."/jsonpath.lua",
        ["kong.plugins."..pluginName..".monitoring"] = "kong/plugins/"..pluginName.."/monitoring.lua",
    }
}
