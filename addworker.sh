#!/bin/bash
echo ""
##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#kamaji parameters
export KAMAJI_NAMESPACE=default

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=kube-127
#Version = 1.27.0, 1.26.7, 1.25.12
export TENANT_VERSION=v1.27.0

#Worker Tenant parameters
#Version = 1.27.0, 1.26.7, 1.25.12
export WORKER_VERSION=1.27.0
export WORKER_FLAVOR=GP.2C4G
export AVAILABILITY_ZONE=AZ_Public01_DC3
export NETWORK=Public_Subnet02_DC3
export COUNT=2


kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
  
sleep 5  

echo "Create WORKER"

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

sleep 2

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - sudo apt install -y kubeadm=${WORKER_VERSION}-00 kubelet=${WORKER_VERSION}-00 kubectl=${WORKER_VERSION}-00 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - ${JOIN_CMD}
EOF


sleep 2

export OS_AUTH_URL=https://jktosp-horizon.dcloud.co.id/identity/v3/
export OS_PROJECT_ID=55e36960719f41159aca054a14d2ba03
export OS_PROJECT_NAME="Infra Kamaji"
export OS_USER_DOMAIN_NAME="Default"
if [ -z "$OS_USER_DOMAIN_NAME" ]; then unset OS_USER_DOMAIN_NAME; fi
export OS_PROJECT_DOMAIN_ID="default"
if [ -z "$OS_PROJECT_DOMAIN_ID" ]; then unset OS_PROJECT_DOMAIN_ID; fi
unset OS_TENANT_ID
unset OS_TENANT_NAME
export OS_USERNAME="teguh.imanto"
export OS_PASSWORD=D4t4c0mm@2023!!!
export OS_REGION_NAME="RegionOne"
if [ -z "$OS_REGION_NAME" ]; then unset OS_REGION_NAME; fi
export OS_INTERFACE=public
export OS_IDENTITY_API_VERSION=3

sleep 2

openstack server create --flavor ${WORKER_FLAVOR} --image "Worker Image Ubuntu 22.04" --network ${NETWORK} --security-group kamaji-rules --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --min ${COUNT} --max ${COUNT} --user-data script.sh "${TENANT_NAME}-${TENANT_VERSION}-worker" > /dev/null 2>&1

sleep 1m 1s

echo "Create WORKER SUCCESS"

echo ""
echo ""

sleep 1

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig cluster-info

echo ""
echo ""

echo "Node Cluster"
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Cluster is Ready !!!"
echo ""
echo "To Use your cluster = export KUBECONFIG=$PWD/${TENANT_NAME}.kubeconfig"
echo ""

rm -rf script.sh > /dev/null 2>&1
rm -rf addworker.sh > /dev/null 2>&1
