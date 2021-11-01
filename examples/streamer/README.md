# A video streaming example

The purpose of this example is to demonstrate how NSM can be used to develop a video streaming solution in the cloud. It relies on the `proxy` example and borrows its `proxy-nsc` to provide an NSM entry point where the HTTP request turns into 

```
```
                       +------------+                      +-------------+
  GET / HTTP/1.1       |            |                      |             |
  NSM-App: Source      |            |     app=source       |    Video    |
+----------------------> Proxy NSC  +---------------------->   Source    |
                       |            |                      |             |
                       |            |                      |             |
                       +------------+                      +-------------+
```

```
