# Kong API response merger

## Synopsis

This plugin transforms the response body from upstream and can extend it by adding additional fields.

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

| form parameter                                    | default             | description                                                                                                                                                                                        |
| ---                                               | ---                 | ---                                                                                                                                                                                                |
| `name`                                            |                     | The name of the plugin to use, in this case `request-transformer`
| `service_id`                                      |                     | The id of the Service which this plugin will target.
| `route_id`                                        |                     | The id of the Route which this plugin will target.
| `enabled`                                         | `true`              | Whether this plugin will be applied.
| `consumer_id`                                     |                     | The id of the Consumer which this plugin will target.
| `config.upstream.uri`                             |                     | Base upstream uri 
| `config.upstream.host_header`                     |                     | Host header which should be passed to upstream 
| `config.upstream.path_prefix`                     |    ``               | Prefix for path to upstream
| `config.paths`                                     |                     | List of paths on which plugin should merge response 
| `config.paths[0].path`                             |                     | Regular expression for path 
| `config.paths[0].upstream_data_path`               |  `$`                | JSON path for data to transform 
| `config.paths[0].keys_to_extend`                   |                     | List of JSON keys to change 
| `config.paths[0.keys_to_extend[0].resource_id_path`|                     | JSON path for id of resource in upstream respone 
| `config.paths[0.keys_to_extend[0].resource_key`    |                     | JSON path for key where to put response of resource upstream 
| `config.paths[0.keys_to_extend[0].api`             |                     | Object with config for resource upstream 
| `config.paths[0.keys_to_extend[0].api.url`         |                     | Adress for api from given resource can be retrived
| `config.paths[0.keys_to_extend[0].api.data_path`   | `$`                 | JSON path for resource data 
| `config.paths[0.keys_to_extend[0].api.query_param_name`   | nil               | Query string parameter name when accessing multiple resources 


## Configuration for Kubernetes
Full config for kubernetes kong plugin

```yaml
apiVersion: configuration.konghq.com/v1
config:
    upstream:
        uri: http://upstream
        host_header: upstream
    paths:
        - path: /v1/data/.+
          keys_to_extend:
            - resource_id_path: "$.service-a.id"
              resource_key: "$.service-a"
              api:
                url: "http://service-a/api/v1/data/"
                data_path: "$"
                id_key: email
            - resource_id_path: "$.service-b.id"
              resource_key: "$.service-b"
              api:
                id_key: id
                url: "http://service-b/v1/data/"
                data_path: "$"
        - path: /v1/data
          upstream_data_path: "$.content"
          keys_to_extend:
            - resource_key: "$..service-a"
              resource_id_path: "$..service-a.id"
              api:
                url: "http://service-a/api/v1/data"
                data_path: "$.content"
                query_param_name: ids
                id_key: id
            - resource_key: "$..service-b"
              resource_id_path: "$..service-b.id"
              api:
                url: "http://service-b/api/v1/data"
                data_path: "$.content"
                query_param_name: ids
                id_key: id
kind: KongPlugin
metadata:
  name: api-response-merger-upstream
  namespace: default
plugin: api-response-merger
```

## Use case 

This paragraph will show how usage of this plugins looks like. We assume that there are 3 REST APIs which can be querd using below example

We have ipstream service that returns response with only ids of resources from service-a and service-b
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
$ curl -X GET http://service-b/api/v1/data/data/b
{
    "id": "b",
    "data": {
        "text": "data from service b",
        "foo-b": "bar"
    }
}
```

This plugin will allow to change upstream respone by extending it respone of data from service-a and service-b. See example below

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

