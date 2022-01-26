# Kong API response merger

[![Build Status](https://travis-ci.org/inveox-lab-it/kong-plugin-api-response-merger.svg?branch=master)](https://travis-ci.org/inveox-lab-it/kong-plugin-api-response-merger)

## Synopsis

This plugin transforms the response body from upstream by adding additional fields or changing the existing one.

## Configuration for Kubernetes

Full config for kubernetes kong plugin

```yaml
apiVersion: configuration.konghq.com/v1
config:
  upstream:
    uri: http://upstream
    host_header: upstream
  paths:
    - path: /v1/data/[^/]+
      resources_to_extend:
        - data_paths:
            - path: "$.service-a"
              id_path: "$.service-a.id"
          api:
            url: "http://service-a/api/v1/data/"
            data_path: "$"
            id_key: email
        - data_paths:
            - id_path: "$.service-b.id"
              path: "$.service-b"
            - id_path: "$.service-b_2.id"
              path: "$.service-b_2"
          api:
            id_key: id
            url: "http://service-b/v1/data/"
            data_path: "$"
    - path: /v1/data
      upstream_data_path: "$.content"
      resources_to_extend:
        - data_paths:
            - path: "$.service-a"
              id_path: "$.service-a.id"
          api:
            url: "http://service-a/api/v1/data"
            data_path: "$.content"
            query_param_name: ids
            id_key: id
        - data_paths:
            - id_path: "$.service-b.id"
              path: "$.service-b"
          api:
            url: "http://service-b/api/v1/data"
            data_path: "$.content"
            query_param_name: ids
            id_key: id
    - path: /v1/data/(?<id>.*)/print
      methods:
        - GET
      upstream:
        uri: http://printing
        host_header: printing
        path: /data
        method: POST
      request:
        extend_with_auth_token: true
        overwrite_body: |-
            {
              "object": {
                "id": "${id}",
                "user": "${auth_token.ext.user.id}"
              }
            }
        resources_to_extend:
          - data_paths:
              - path: "$.object"
                id_path: "$.object.id"
            api:
                id_key: id
                url: "http://service-b/v1/data/"
                data_path: "$"
          - data_paths:
              - path: "$.configuration"
            add_missing: true,
            api:
              url: "http://service-a/v1/data/"
        
kind: KongPlugin
metadata:
  name: api-response-merger-upstream
  namespace: default
plugin: api-response-merger
```

## Use case

This paragraph will show how usage of this plugins looks like. We assume that there are 3 REST APIs which can be querd
using below example

We have upstream service that returns response with only ids of resources from service-a and service-b

```bash
$ curl -X GET http://upstream/v1/data/upstream-1
{
    "id": "uptream-1",
    "service-a": {
        "id": "a"
    },
    "service-b": {
        "id": "b"
    },
    "upstream-data": {
        "foo": "bar"
    }
}
```

Response from service-a

```bash
$ curl -X GET http://service-a/api/v1/data/data/a
{
    "id": "a",
    "data": {
        "text": "data from service a"
    }
}
```

Response from service-b

```bash
$ curl -X GET http://service-b/api/v1/data/b
{
    "id": "b",
    "data": {
        "text": "data from service b",
        "foo-b": "bar"
    }
}
```

This plugin will allow to change upstream response by extending it respone of data from service-a and service-b. See
example below

```bash
$ curl -X GET http://kong/v1/data/upstream-1
{
    "id": "upstream-1",
    "service-a": {
        "id": "a",
        "data": {
            "text": "data from service a"
        }
    },
    "service-b": {
        "id": "b",
        "data": {
            "text": "data from service b",
            "foo-b": "bar"
        }
    },
    "upstream-data": {
        "foo": "bar"
    }
}
```

## Configuration

### Enabling the plugin on a Service

Configure this plugin on a Service by making the following request:

```bash
$ curl -X POST http://kong:8001/services/{service}/plugins \
    --data "name=api-response-merger"
```

`service`: the `id` or `name` of the Service that this plugin configuration will target.

### Enabling the plugin on a Route

Configure this plugin on a Route with:

```bash
$ curl -X POST http://kong:8001/routes/{route_id}/plugins \
    --data "name=api-response-merger"
```

`route_id`: the `id` of the Route that this plugin configuration will target.

### Enabling the plugin on a Consumer

You can use the `http://localhost:8001/plugins` endpoint to enable this plugin on specific Consumers:

```bash
$ curl -X POST http://kong:8001/plugins \
    --data "name=api-response-merger" \
    --data "consumer_id={consumer_id}"
```

Where `consumer_id` is the `id` of the Consumer we want to associate with this plugin.

You can combine `consumer_id` and `service_id` in the same request, to furthermore narrow the scope of the plugin.

| form parameter                                                 | default             | description                                                                                                                                                                                        |
| ---                                                            | ---                 | ---                                                                                                                                                                                                |
| `name`                                                         |                     | The name of the plugin to use, in this case `request-transformer`
| `service_id`                                                   |                     | The id of the Service which this plugin will target.
| `route_id`                                                     |                     | The id of the Route which this plugin will target.
| `enabled`                                                      | `true`              | Whether this plugin will be applied.
| `consumer_id`                                                  |                     | The id of the Consumer which this plugin will target.
| `config.upstream.uri`                                          |                     | Base upstream uri
| `config.upstream.host_header`                                  |                     | Host header which should be passed to upstream
| `config.upstream.path`                                         |                     | Overwrites path to upstream
| `config.upstream.path_prefix`                                  |    ``               | Prefix for path to upstream
| `config.upstream.method`                                       |                     | Method used for upstream call (by default method from the request)
| `config.paths`                                                 |                     | List of paths on which plugin should merge response
| `config.paths[0].path`                                         |                     | Regular expression for path
| `config.paths[0].upstream`                                     |                     | Upstream configuration which overrides base upstream config (see config.upstream)
| `config.paths[0].upstream_data_path`                           |  `$`                | JSON path for data to transform
| `config.paths[0].resources_to_extend`                          |                     | List of resources to change/expand
| `config.paths[0].resources_to_extend[0].data_paths`            |                     | List of JSON paths to change - at least one required
| `config.paths[0].resources_to_extend[0].data_paths[0].path`    |                     | JSON path for key where to put response of resource upstream - path is required
| `config.paths[0].resources_to_extend[0].data_paths[0].id_path` |                     | JSON path for id of resource in upstream response
| `config.paths[0].resources_to_extend[0].api`                   |                     | Object with config for resource upstream
| `config.paths[0].resources_to_extend[0].api.url`               |                     | Adress for api from given resource can be retrieved, url can be interpolated with values from the body (response or request - currently transformed, e.g. for ```{ "object": {"id": "id_value" } } ``` the following expression can be used _${object.id}_ e.g. url = _http://resource-service/resources/${object.id}/other-resources_)
| `config.paths[0].resources_to_extend[0].api.data_path`         | `$`                 | JSON path for resource data
| `config.paths[0].resources_to_extend[0].api.query_param_name`  | nil                 | Query string parameter name when accessing multiple resources
| `config.paths[0].resources_to_extend[0].allow_missing`         | false               | Flag indicating if merger should returns error when resource is missing. Default false
| `config.paths[0].resources_to_extend[0].add_missing`           | false               | Flag indicating if merger should try adding the whole upstream body under the path if the id is missing
| `config.paths[0].request.overwrite_body`                       | nil                 | New request body used for the upstream. It is interpolated with the captures for the path mapping (named variables are supported, see https://github.com/openresty/lua-nginx-module#ngxrematch)
| `config.paths[0].request.resources_to_extend`                  | nil                 | List of resources to be changed/expanded (see details above)
| `config.paths[0].request.extend_with_auth_token`               | false               | Whether the auth token should be used for interpolation of request body - if true, it can be accessed by "auth_token" param, e.g. ```{ "object": {"user_id": "${auth_token.ent.user.id}" } } ```


