#!/bin/bash
echo ""

export rand=$(openssl rand -hex 3)

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config

#tenant cluster parameters
export TENANT_NAMESPACE=default
export TENANT_NAME=jkt2-tenant-${rand} #Tenant Name must be unique
export TENANT_VERSION=1.29.0

#Version Available
#1.29 = 1.29.0, 1.29.1
#1.28 = 1.28.8, 1.28.7, 1.28.6, 1.28.5, 1.28.4, 1.28.3, 1.28.2, 1.28.1, 1.28.0 
#1.27 = #1.27.12, 1.27.11, 1.27.10, 1.27.9, 1.27.8, 1.27.7, 1.27.6, 1.27.5, 1.27.4, 1.27.3, 1.27.2, 1.27.1 

#worker Tenant parameters
export WORKER_FLAVOR=GP.1C2G
#export AVAILABILITY_ZONE=AZ_Public01_DC2
export AVAILABILITY_ZONE=AZ_Public01_JBBK
#export NETWORK=Public_Subnet02_DC2
export NETWORK=Public_Subnet01_JBBK
export COUNT=2

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
    version: v${TENANT_VERSION}
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
 - sudo apt install -y kubeadm=${TENANT_VERSION}-1.1 kubelet=${TENANT_VERSION}-1.1 kubectl=${TENANT_VERSION}-1.1 --allow-downgrades --allow-change-held-packages
 - sudo apt-mark hold kubelet kubeadm kubectl
 - ${JOIN_CMD}
EOF

for i in $(seq 1 ${COUNT}); do
   export rand=$(openssl rand -hex 2)   
   #openstack server create --flavor ${WORKER_FLAVOR} --image "DKubes Worker v1.1" --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1 #perhatikan security group dan keypair (harus ada pada user yang memprovisioning)
   openstack server create --flavor GP.2C4G-amd --image "DKubes Worker v1.1"  --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1
done


#calico
#kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml > /dev/null 2>&1

#cannal
#kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml > /dev/null 2>&1

#cilium
helm --kubeconfig=${TENANT_NAME}.kubeconfig apply repo add cilium https://helm.cilium.io/ > /dev/null 2>&1
helm --kubeconfig=${TENANT_NAME}.kubeconfig apply install cilium cilium/cilium --version 1.15.3 --namespace kube-system > /dev/null 2>&1

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
