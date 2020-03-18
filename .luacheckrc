std             = "ngx_lua"
unused_args     = false
redefined       = false
max_line_length = false


globals = {
  "_KONG",
  "kong",
  "ngxI",
}


not_globals = {
  "string.len",
  "table.getn",
}

exclude_files = {
 "kong/**/jsonpath.lua"
}

files["spec/**/*.lua"] = {
  std = "ngx_lua+busted",
}
