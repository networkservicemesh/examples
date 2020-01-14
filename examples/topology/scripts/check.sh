kubectl exec $(kubectl get pod -l device=router5 -o name) -c router -- ping -c 1 192.0.2.1
kubectl exec $(kubectl get pod -l device=router5 -o name) -c router -- ping -c 1 192.0.2.2
kubectl exec $(kubectl get pod -l device=router5 -o name) -c router -- ping -c 1 192.0.2.3
kubectl exec $(kubectl get pod -l device=router5 -o name) -c router -- ping -c 1 192.0.2.4
kubectl exec $(kubectl get pod -l device=router5 -o name) -c router -- ping -c 1 192.0.2.5
