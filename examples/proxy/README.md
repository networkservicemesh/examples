# HTTP reverse proxy example

The example proxy-nsc is an implementation of HTTP proxy as NS Client.
It can be use as an NS ingress proxy, where the proxy service is exposed as an
outside facing service. Upon HTTP connection request, the proxy will create
a new NS connection. The connection is configured by env variables as an usual
NS Client. The proxy will scan the HTTP request for headers of format:
    `NSM-<label>:<value>`
These would be transformed to NS Client request labels. The proxy itself always labels its
requests with `app=proxy`.

In this example we deploy three NGiNX Endpoints all implementing the `web-service`,
but all are labelled with differet `color=<color>`, where `color` is `red`, `green`
or `blue`.

The Network Service description is written in a way that the connection will be wired
depending on the `color` label in the connection request. In case there is no such label
or it referes to a different color, NSM will do a round robin on the selection of the endpoints.
Meaning that each request will result in establishing a conenction to a different NGiNX and
effectively showing a web page with different color.

```
                                                            +-------------+
                                                            |             |
                                                            | nginx-red   |
                                                       +---->             |
                                                       |    | app=nginx   |
                                                       |    | color=red   |
                                                       |    +-------------+
                                                       |
                       +------------+                  |    +-------------+
  GET / HTTP/1.1       |            |     app=proxy    |    |             |
  NSM+App: Red         |            |     color=red    |    | nginx-green |
+----------------------> Proxy NSC  +----------------------->             |
                       |            |                  |    | app=nginx   |
                       |            |                  |    | color=green |
                       +------------+                  |    +-------------+
                                                       |
                                                       |    +-------------+
                                                       |    |             |
                                                       |    | nginx-blue  |
                                                       +---->             |
                                                            | app=nginx   |
                                                            | color=blue  |
                                                            +-------------+
```