#!/bin/bash
echo ""

export rand=$(openssl rand -hex 3)

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config
#export KUBECONFIG=~/.kube/kube-adminkamaji-dev
#export KUBECONFIG=~/kube-demo-managed-k8s

#tenant cluster parameters
export TENANT_NAMESPACE=kamaji-tcp
export TENANT_NAME=jbbk-tenant-cluster-${rand} #Tenant Name must be unique
export TENANT_VERSION=1.30.2

#Version Available
#1.30 = 1.30.1 1.30.2
#1.29 = 1.29.6, 1.29.7
#1.28 = 1.28.11, 1.28.12

#worker Tenant parameters
export WORKER_FLAVOR=GP.2C4G
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
  dataStore: kamaji-etcd
  controlPlane:
    deployment:
      replicas: 3
    service:
      serviceType: LoadBalancer
  kubernetes:
    version: v${TENANT_VERSION}
    kubelet:
      cgroupfs: systemd
      preferredAddressTypes:
      - ExternalIP
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
  STATUS=$(kubectl get tcp -n ${TENANT_NAMESPACE} | grep ${TENANT_NAME} | awk '{print $3}')

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
   #openstack server create --flavor ${WORKER_FLAVOR} --image "DKubes Worker v${TENANT_VERSION}" --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1 #perhatikan security group dan keypair (harus ada pada user yang memprovisioning)
   openstack server create --flavor GP.2C4G-amd --image "DKubes Worker v${TENANT_VERSION}"  --network ${NETWORK} --security-group allow-all --availability-zone ${AVAILABILITY_ZONE} --key-name remote-server --user-data script.sh "${TENANT_NAME}-worker-${rand}" > /dev/null 2>&1
done


#calico
#kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml > /dev/null 2>&1

#Flannel
#kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml > /dev/null 2>&1

#Canal
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.2/manifests/canal.yaml > /dev/null 2>&1

#cilium
#helm --kubeconfig=${TENANT_NAME}.kubeconfig repo add cilium https://helm.cilium.io/ > /dev/null 2>&1
#helm --kubeconfig=${TENANT_NAME}.kubeconfig install cilium cilium/cilium --version 1.15.3 --namespace kube-system > /dev/null 2>&1

#Weave
#kubectl --kubeconfig=${TENANT_NAME}.kubeconfig create -f ht‌tps://git.io/weave-kube  > /dev/null 2>&1


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

sleep 5s

#Deploy Metrics
helm --kubeconfig=${TENANT_NAME}.kubeconfig repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ > /dev/null 2>&1
helm --kubeconfig=${TENANT_NAME}.kubeconfig upgrade --install metrics-server metrics-server/metrics-server -n kube-system  > /dev/null 2>&1
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig -n kube-system patch deployment metrics-server --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["--secure-port=10250", "--cert-dir=/tmp", "--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname", "--kubelet-use-node-status-port", "--metric-resolution=15s", "--kubelet-insecure-tls"]}]' > /dev/null 2>&1


#Deploy Kubernetes-dashboard
helm --kubeconfig=${TENANT_NAME}.kubeconfig repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/ > /dev/null 2>&1
helm --kubeconfig=${TENANT_NAME}.kubeconfig upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard > /dev/null 2>&1
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig --namespace kubernetes-dashboard  patch svc kubernetes-dashboard-kong-proxy  -p '{"spec": {"type": "NodePort"}}' > /dev/null 2>&1
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig create clusterrolebinding dashaccess --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:default -n kubernetes-dashboard > /dev/null 2>&1


echo ""
echo ""
echo "Node Cluster"
kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get nodes
echo ""
echo ""

echo "Your Cluster is Ready !!!"
echo ""
echo "To Use your cluster via CLI = export KUBECONFIG=$PWD/${TENANT_NAME}.kubeconfig"
echo ""
echo ""

echo "Access via Kubernetes Dashboard"
echo ""
nodeport=$(kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get svc kubernetes-dashboard-kong-proxy -n kubernetes-dashboard --output=jsonpath='{.spec.ports[?(@.port==443)].nodePort}')
ipworker=$(kubectl --kubeconfig=${TENANT_NAME}.kubeconfig get node -o wide | awk 'NR==2 {print $6}')
echo "https://$ipworker:$nodeport"
echo ""
echo ""

echo "Access Kubernetes Dashboard using Bearer Token!!!"
echo ""
bearer_token=$(kubectl --kubeconfig=${TENANT_NAME}.kubeconfig -n kubernetes-dashboard create token default)
echo "kubectl -n kubernetes-dashboard create token default"
echo ""
echo "$bearer_token"
echo ""

rm -rf script.sh > /dev/null 2>&1
rm -rf createcluster.sh > /dev/null 2>&1
