## [2.3.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.3.1...2.3.2) (2022-01-24)


### Bug Fixes

* **request:** [LIT03-1206] api url interpolation ([#19](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/issues/19)) ([54b6060](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/54b6060be6156970a2d8de8446017f1923aca11a))

## [2.3.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.3.0...2.3.1) (2021-12-15)


### Bug Fixes

* copy request headers ([149c310](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/149c3101ffd39de3527e42a05f1c1281f5726f92))

# [2.3.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.2.2...2.3.0) (2021-12-15)


### Features

* allow to overirde host_header in calls ([93d08bd](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/93d08bd8d90c37f5cce5ec09c0dc229cdb1cb487))

## [2.2.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.2.1...2.2.2) (2021-12-15)


### Bug Fixes

* explicte set host header when calling upstreams ([8462c36](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/8462c360e3b290d0b60713ac300467429039c760))

## [2.2.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.2.0...2.2.1) (2021-11-08)


### Bug Fixes

* handle nil in query params ([87bff07](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/87bff076e815d81d8578d31640582996aa50468f))

# [2.2.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.1.2...2.2.0) (2021-10-21)


### Features

* use unique ids query ([3024e30](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/3024e30f13c77886c20b2eba0b520e5713e0c399))

## [2.1.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.1.1...2.1.2) (2021-10-15)


### Bug Fixes

* **request:** [LIT03-1206] overwriting and building request (Scanning: Printing (BE)) - fix ([9f6e408](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/9f6e40855888002762c93a67648c98518939b90c))

## [2.1.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.1.0...2.1.1) (2021-10-15)


### Bug Fixes

* **request:** [LIT03-1206] overwriting and building request (Scanning: Printing (BE)) - fix ([d9b4fa3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/d9b4fa38efea4b6ed19bc4a5cdbae0dde2241cee))

# [2.1.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.0.1...2.1.0) (2021-10-14)


### Features

* **request:** [LIT03-1206] overwriting and building request (Scanning: Printing BE) ([2ff699f](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/2ff699f3ecf30f5c19b1d5ad579693b0e2306881))

## [2.0.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/2.0.0...2.0.1) (2021-09-13)


### Bug Fixes

* **multipaths:** [LIT03-1136] optimize calling the same endpoint for several json-paths in API merger - fix using alternative json path for more than of data_paths configuration ([c63f9bd](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/c63f9bd36a7f27d32a50518e35d8c1f7ea194f25))
* **multipaths:** [LIT03-1136] optimize calling the same endpoint for several json-paths in API merger - fix using alternative json path for more than of data_paths configuration ([38f1f41](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/38f1f4144f821919396e98e7f59d9052009d59b3))

# [2.0.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.13.0...2.0.0) (2021-09-13)


### Features

* **multipaths:** [LIT03-1136] optimize calling the same endpoint for several json-paths in API merger  BREAKING CHANGE: NEW CONFIG ([ac18a5b](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/ac18a5b6ad3a585287627f155cc65c41d1851223))


### BREAKING CHANGES

* **multipaths:** NEW CONFIG

* Update kong/plugins/api-response-merger/body_transformer.lua

Co-authored-by: Marcin Kaciuba <marcin.kaciuba@inveox.com>

* Update kong/plugins/api-response-merger/body_transformer.lua

Co-authored-by: Marcin Kaciuba <marcin.kaciuba@inveox.com>

Co-authored-by: Marcin Kaciuba <marcin.kaciuba@inveox.com>

# [1.13.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.12.0...1.13.0) (2021-09-06)


### Features

* **json_path:** [LIT03-1115] Correct response merger for empty responses ([56e16d7](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/56e16d70bbeb79c2e930b7ff4419b942c396ea15))

# [1.12.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.11.0...1.12.0) (2021-09-03)


### Features

* **json_path:** [LIT03-973] ISSUE - lab notes - field "modifiedBy" is returned as a list through the api gateway ([219104b](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/219104ba5871abca794a48bd91507e0377bc8958))
* **json_path:** [LIT03-973] ISSUE - lab notes - field "modifiedBy" is returned as a list through the api gateway ([a1b55cc](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/a1b55cc617908a2ab01223ba239af82ee9ad4303))
* **json_path:** [LIT03-973] ISSUE - lab notes - field "modifiedBy" is returned as a list through the api gateway - rework ([b7b5e4e](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/b7b5e4e31cee0d16966fdf483dc3a492f5b3e425))
* [LIT03-973] test reproducing issue ([18befed](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/18befed9cf02cc85eaf4780d90e60129e8a3497c))

# [1.11.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.10.3...1.11.0) (2021-08-19)


### Features

* reject only server errors ([6fc5e81](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/6fc5e8141a4d0c4aa135f33406e62a50d66eb664))

## [1.10.3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.10.2...1.10.3) (2021-08-19)


### Bug Fixes

* check if error is not nil when returning error response ([7358269](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/7358269894bda3ff1f6009776b38026a6aa36839))

## [1.10.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.10.1...1.10.2) (2021-08-19)


### Bug Fixes

* current can be nil ([7df6e31](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/7df6e31d40db9522d5063208430255a3c1108572))

## [1.10.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.10.0...1.10.1) (2021-08-19)


### Bug Fixes

* set_in_table resource can be nil ([f0582f3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/f0582f3d21562bba6ea12e0e83d63fe23bf011c4))

# [1.10.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.9.3...1.10.0) (2021-08-19)


### Bug Fixes

* Handle {'dest_resource': null} case. just skip. ([fbde846](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/fbde846a649692f1d1057e7c5724e53a8060fee2))
* handle no resource_id_path found case to avoid crash ([53cfaf1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/53cfaf13ee608b1f6eea2c3e5d170725ead7083b))


### Features

* replace size parameter with filter[limit] to adopt Loopback4 interface ([d8df249](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/d8df2496ef3db302439ad19904e6d1eebcb0791e))
* support more than 2 depth for set_in_table_arr() ([e1f0b92](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/e1f0b923b84c40baa1c8bfa9664e5500e5574799))

## [1.9.3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.9.2...1.9.3) (2021-07-23)


### Bug Fixes

* more info in log ([7fd5443](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/7fd544330ee302b50bba2db669fc94cf50c136ec))
* more info in log ([3cbfe8a](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/3cbfe8ad2c29ddcc9c469016f6fb584cd3e29bb1))

## [1.9.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.9.1...1.9.2) (2021-07-09)


### Bug Fixes

* fix api-gtw user-agent header ([b1917aa](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/b1917aa195b5baaf953b705f2416977389bc2fde))

## [1.9.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.9.0...1.9.1) (2021-07-08)


### Bug Fixes

* copy all headers ([3e01a9f](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/3e01a9f1fffe9182ec7b9d926358de7b4d71919e))
* update merger ([928c5bb](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/928c5bba05ad51c8706369c481ba91c25317d790))

# [1.9.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.8.1...1.9.0) (2021-07-08)


### Features

* rewrite method use req instead of table ([c756ecd](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/c756ecdc9b1a6a5907c8d4d8f79fc9c69109868e))

## [1.8.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.8.0...1.8.1) (2021-05-26)


### Bug Fixes

* **resource_id_optional:** [LIT03-585] BE: unable to retrieve DLO with null relatedLabId via api-gw ([76ab356](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/76ab356c43d1449dfcfeec1563b35a8fc586ae16))

# [1.8.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.7.2...1.8.0) (2021-05-25)


### Features

* **resource_id_optional:** [LIT03-585] BE: unable to retrieve DLO with null relatedLabId via api-gw ([#10](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/issues/10)) ([00ad1df](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/00ad1dfe8b4d5b9b558503145f0d23e3163e61a8))

## [1.7.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.7.1...1.7.2) (2021-04-30)


### Bug Fixes

* do not panic when id for resource is nil ([07933f9](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/07933f9c0337825e2a18f306ad6284688204cf2f))

## [1.7.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.7.0...1.7.1) (2021-04-26)


### Bug Fixes

* handle resource as nil in set_in_table ([c987eec](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/c987eec8d6cbbe9e42935919e4d9496a56586772))

# [1.7.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.8...1.7.0) (2021-04-26)


### Features

* handle search for array in for single upstream resource ([4e5a311](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/4e5a3111624aafe79550d9ccc9834e8f2cfb81be))

## [1.6.8](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.7...1.6.8) (2021-04-15)


### Bug Fixes

* change error message for single error ([6befbdd](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/6befbdd9c0613108497779e89007778580d8145a))

## [1.6.7](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.6...1.6.7) (2021-04-15)


### Bug Fixes

* handle missing data for single response ([f99d8b1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/f99d8b1bcadd24aa9bc65a018db668c60cf91afe))

## [1.6.6](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.5...1.6.6) (2021-04-15)


### Bug Fixes

* set default for allow_missing ([22aa529](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/22aa529cacb69d59db735172a07a772095048010))

## [1.6.5](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.4...1.6.5) (2021-04-14)


### Bug Fixes

* it should be if-else not if-if statment for jp.query nil result (is is late :() ([987492b](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/987492be257e4df9815f593da40bbb3cb5fb5cb1))

## [1.6.4](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.3...1.6.4) (2021-04-14)


### Bug Fixes

* it should be if-else not if-if statment for jp.query nil result ([2bc6744](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/2bc67443244eb26a4d42a809e45757c53f7c8b74))
* it should be if-else not if-if statment for jp.query nil result (lua) ([f7869ba](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/f7869ba4ebc6ddd563fbcaf559957ee9adb3a181))

## [1.6.3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.2...1.6.3) (2021-04-14)


### Bug Fixes

* handle json.path nil result ([c83497d](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/c83497de2482d8b6ffd3b747cdbb9b150463e91c))

## [1.6.2](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.1...1.6.2) (2021-04-14)


### Bug Fixes

* add more logs when data are missing ([cebe0c9](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/cebe0c9221720fb9e3be5f153b8f61393b61f2bd))

## [1.6.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.6.0...1.6.1) (2021-04-14)


### Bug Fixes

* handle id query returning nil ([3dbf436](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/3dbf4369991da0c77d0efa3a13f7eca1a32e4f23))

# [1.6.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.5.1...1.6.0) (2021-04-14)


### Features

* add flags which allows given key being missing ([34e15f3](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/34e15f3b6137d59184c884326b0f17c10b4da9ad))

## [1.5.1](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.5.0...1.5.1) (2021-04-14)


### Bug Fixes

* id can be nil ([158c2ac](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/158c2acb90d332b4625c26fd94133a337c64325c))

# [1.5.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.4.0...1.5.0) (2021-04-14)


### Features

* allow to pass query sting in API url ([ac0b9b9](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/ac0b9b9e7dddab90ad1288ba69f14369f7c70dd7))

# [1.4.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.3.0...1.4.0) (2021-04-14)


### Features

* add unique user-agent prefix for api-gateway requests ([37c68f8](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/37c68f8d73a81c72388b3995661eecf84093f111))

# [1.3.0](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/compare/1.2.2...1.3.0) (2021-04-14)


### Bug Fixes

* **ci:** fix lint stage [LIT03-512] ([1265bbb](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/1265bbb0873273788cb1fd2a3ce577774d9c925f))


### Features

* **nested_key_array:** [LIT03-512] BE - add merging receiving lab id in api gateway ([74383fa](https://github.com/inveox-lab-it/kong-plugin-api-response-merger/commit/74383faa608589335c3d00ed0483d6b18ca5da2d))
