# 4G EPC SPGW example

An example the leverages the OMEC's NGIC-RTC implementation of S-GW/P-GW. 

```
                                      +----------------+
                                      |                |
                                      |     SPGW+C     |
                                      |                |
                                      |                |
                                      |                |
                                      |                |
                      Control plane   +--------+-------+
                                               |
                                               | Sx
+------------------------------------------------------------------------------------+
                                               |
                                               |
  +----------------+   Data plane     +--------v-------+          +----------------+
  |                |                  |                |          |                |
  |                |                  |     SPGW+U     |          |     RTR        |
  |     eNB-sim    |           S1U    |                |    SGi   |                |
  |                +------------------>  10.60.3.0/24  +---------->  10.60.2.0/24  |
  |                |                  |                |          |                |
  |                |                  |                |          |                |
  +----------------+                  +----------------+          +----------------+

```

The NGIC is compiled with a SIMU_CP flag so no MME is needed.

References:
 * https://www.youtube.com/watch?v=fry7zmNmJ10
 * https://www.opennetworking.org/wp-content/uploads/2019/09/2pm-Saikrishna-Edupuganti-OMEC-in-a-Kubernetes-Orchestrated-Environment.pdf
 * https://github.com/omec-project/ngic-rtc/tree/master/deploy/k8s
 * https://github.com/opencord/helm-charts/tree/master/omec
 * https://www.slideshare.net/kentaroebisawa/using-gtp-on-linux-with-libgtpnl
