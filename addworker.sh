#!/bin/bash
echo ""

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#tenant cluster parameters
export TENANT_NAMESPACE=default

#cluster name and version must same form exsiting cluster
#to see exsiting cluster, exceute this command !
   #kubectl get tcp -n default  | awk 'BEGIN { print "NAME VERSION" } NR > 1 { print $1, $2 }'

export TENANT_NAME=kube-11b4e8
export TENANT_VERSION=v1.26.7

#worker Tenant parameters
export WORKER_VERSION=1.26.7 #version must same form exsiting cluster version, #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12
export WORKER_FLAVOR=GP.1C2G
export AVAILABILITY_ZONE=AZ_Public01_DC2
export NETWORK=Public_Subnet02_DC2
export COUNT=4

#Proejct Tenant Parameters
. ~/cloud_development-openrc.sh

kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig
  
echo "Create WORKER"
echo "Waiting..."

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - sudo apt-get update
 - sudo apt install -y kubeadm=${WORKER_VERSION}-00 kubelet=${WORKER_VERSION}-00 kubectl=${WORKER_VERSION}-00 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - ${JOIN_CMD}
EOF

for i in $(seq 1 ${COUNT}); do
   export rand=$(openssl rand -hex 2)
   openstack server create --flavor ${WORKER_FLAVOR} --image "Worker Image Ubuntu 22.04" --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1
done

sleep 2m 1s

echo "Create WORKER SUCCESS"

sleep 2s

echo ""
echo ""
echo "Node Cluster"
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Node has been Added !!!"
echo ""
echo "To Use your cluster = export KUBECONFIG=$PWD/${TENANT_NAME}.kubeconfig"
echo ""

rm -rf script.sh > /dev/null 2>&1
rm -rf createcluster.sh > /dev/null 2>&1
