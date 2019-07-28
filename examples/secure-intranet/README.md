# Secure Intranet Example

This example demonstrates a more complex Network Service, where we chain three passthrough and one ACL Filtering NS endpoints. It demonstrates how NSM allows for service composition (chaining). It involves a combination of kernel and memif mechanisms, as well as VPP enabled endpoints.

```

    +--------+      +---------------+      +---------------+      +---------------+      +------------+      +---------+
    |        |      |               |      |               |      |               |      |            |      |         |
    | Client +------> Passthrough 1 +------> Passthrough 2 +------> Passthrough 3 +------> ACL Filter +------> Gateway |
    |        |      |               |      |               |      |               |      |            |      |         |
    +--------+      +---------------+      +---------------+      +---------------+      +------------+      +---------+
```
