#!/bin/bash

usage() {
  echo "usage: $0 [OPTIONS]"
  echo ""
  echo "  MANDATORY OPTIONS:"
  echo ""
  echo "  --kconf_clus1=<kubeconfig>           set the kubeconfig for the first cluster"
  echo "  --kconf_clus2=<kubeconfig>           set the kubeconfig for the second cluster"
  echo ""
  echo "  Optional OPTIONS:"
  echo ""
  echo "  --nowait                   don't wait for user input prior to moving to next step"
  echo ""
}

for i in "$@"; do
    case $i in
        -h|--help)
            usage
            exit
            ;;
        --kconf_clus1=?*)
            KCONF_CLUS1=${i#*=}
            echo "setting KCONF_CLUS1=${KCONF_CLUS1}" 
            ;;
        --kconf_clus2=?*)
            KCONF_CLUS2=${i#*=}
            echo "setting KCONF_CLUS2=${KCONF_CLUS2}" 
            ;;
        --populate)
            POPULATE=true
            ;;
        --nowait)
            NOWAIT=true
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ -z ${KCONF_CLUS1} || -z ${KCONF_CLUS2} ]]; then
    echo "ERROR: One or more of kubeconfigs not set."
    usage
    exit 1
fi

kubectl wait -n default --kubeconfig ${KCONF_CLUS1} --timeout=150s --for condition=Ready -l app.kubernetes.io/name=mysql-master pod

kubectl wait -n default --kubeconfig ${KCONF_CLUS2} --timeout=150s --for condition=Ready -l app.kubernetes.io/name=mysql-slave pod


masterPod=$(kubectl get pods --kubeconfig ${KCONF_CLUS1} -l "app.kubernetes.io/name=mysql-master" -o jsonpath="{.items[0].metadata.name}")

if [[ "${POPULATE}" == "true" ]]; then
    echo "------Adding db demo and table to master in ${masterPod}------"

    kubectl exec --kubeconfig ${KCONF_CLUS1} -t ${masterPod} -c mysql-master -- bash -c "mysql -u root -ptest -e 'create database IF NOT EXISTS demo;'"
    kubectl exec --kubeconfig ${KCONF_CLUS1} -t ${masterPod} -c mysql-master -- bash -c "mysql -u root -ptest -D demo -e 'create table IF NOT EXISTS user(id int(10), name char(20));'"

    kubectl exec --kubeconfig ${KCONF_CLUS1} -t ${masterPod} -c mysql-master -- bash -c "mysql -u root -ptest -D demo -e 'insert into user values(100, \"user1\");'"
fi


sleep 30
echo "----Checking mysql-slave on ${KCONF_CLUS2}----"

slavePod=$(kubectl get pods --kubeconfig ${KCONF_CLUS2} -l "app.kubernetes.io/name=mysql-slave" -o jsonpath="{.items[0].metadata.name}")

echo "----Found mysql-slave ${slavePod} ----"

kubectl exec --kubeconfig ${KCONF_CLUS2} -t ${slavePod} -c mysql-slave -- bash -c "mysql -u root -ptest -e 'show databases;'"

echo "----Viewing DB 'demo' from mysql-slave ${slavePod} ----"
kubectl exec --kubeconfig ${KCONF_CLUS2} -t ${slavePod} -c mysql-slave -- bash -c "mysql -u root -ptest -D demo -e 'select * from user;'"
