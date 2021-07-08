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
