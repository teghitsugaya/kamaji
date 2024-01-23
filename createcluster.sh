#!/bin/bash
echo ""

export rand=$(openssl rand -hex 3)

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=kube-${rand} #Tenant Name must be unique
export TENANT_VERSION=v1.29.1  #Version Available / Recomended = 1.29.1, 1.28.6, 1.27.10, 1.26.13

#worker Tenant parameters
#export WORKER_VERSION=1.27.0 #Version Available / Recomended = 1.27.0, 1.26.7, 1.25.12
export WORKER_FLAVOR=GP.1C2G
export AVAILABILITY_ZONE=AZ_Public01_DC2
export NETWORK=Public_Subnet02_DC2
export COUNT=3

#Proejct Tenant Parameters
. ~/cloud_development-openrc.sh

echo "Deploy Cluster Kubernetes"
echo "Cluster Name: ${TENANT_NAME}"
echo "Version: ${TENANT_VERSION}"
echo ""
echo ""
echo "Create Tenant Control Plane"
echo "Waiting..."

kubectl create -f - <<EOF > /dev/null 2>&1
apiVersion: kamaji.clastix.io/v1alpha1
kind: TenantControlPlane
metadata:
  name: ${TENANT_NAME}
  namespace: ${TENANT_NAMESPACE}
spec:
  dataStore: default
  controlPlane:
    deployment:
      replicas: 3
    service:
      serviceType: LoadBalancer
  kubernetes:
    version: ${TENANT_VERSION}
    kubelet:
      cgroupfs: systemd
  networkProfile:
    port: 6443
  addons:
    coreDNS: {}
    kubeProxy: {}
    konnectivity:
      server:
        port: 8132
        resources: {}
      agent: {}
EOF

while true; do
  STATUS=$(kubectl get tcp | grep ${TENANT_NAME} | awk '{print $3}')

case "$STATUS" in
    "Ready")
      echo "Create Tenant Control Plane SUCCESS"
      break
      ;;
    *)
  esac
done

kubectl get secrets -n ${TENANT_NAMESPACE} ${TENANT_NAME}-admin-kubeconfig -o json \
  | jq -r '.data["admin.conf"]' \
  | base64 --decode \
  > ${TENANT_NAME}.kubeconfig

echo ""
echo "Create WORKER"
echo "Waiting..."

JOIN_CMD=$(kubeadm --kubeconfig=${TENANT_NAME}.kubeconfig token create --print-join-command)

cat << EOF | tee script.sh > /dev/null 2>&1
#cloud-config
debug: True
runcmd:
 - sudo apt-get update
 - sudo apt install -y kubeadm=${TENANT_VERSION}-00 kubelet=${TENANT_VERSION}-00 kubectl=${TENANT_VERSION}-00 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - ${JOIN_CMD}
EOF

for i in $(seq 1 ${COUNT}); do
   export rand=$(openssl rand -hex 2)
   openstack server create --flavor ${WORKER_FLAVOR} --image "Worker Image Ubuntu 22.04" --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1
done

kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml > /dev/null 2>&1

while true; do  
  STATUS=$(kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get deploy -n kube-system | grep coredns | awk '{print $4}') #Mengambil parameter deployment coredns, kedepannya parameter yang diambil yaitu, pod (running), node (ready)
case "$STATUS" in
    "2")
      echo "Create WORKER SUCCESS"
      break
      ;;
    *)
  esac
done

sleep 2s

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
rm -rf createcluster.sh > /dev/null 2>&1
