# HTTP reverse proxy example

The example proxy-nsc is an implementation of HTTP proxy as NS Client.
It can be use as an NS ingress proxy, where the proxy service is exposed as an
outside facing service. Upon HTTP connection request, the proxy will create
a new NS connection. The connection is configured by env variables as an usual
NS Client. The proxy will scan the HTTP request for headers of format:
    `NSM-<label>:<value>`
These would be transformed to NS Client request labels.

```
                       +------------+                      +-------------+
  GET / HTTP/1.1       |            |                      |             |
  NSM-App: Firewall    |            |     app=firewall     |             |
+----------------------> Proxy NSC  +----------------------> NS Endpoint |
                       |            |                      |             |
                       |            |                      |             |
                       +------------+                      +-------------+
```