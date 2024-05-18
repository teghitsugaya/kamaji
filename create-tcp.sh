#!/bin/bash
echo ""

export rand=$(openssl rand -hex 3)

##export cluster admin kamaji
export KUBECONFIG=~/.kube/config
#export KUBECONFIG=~/jbbk-adminkamaji-production

#tenant cluster parameters
export TENANT_NAMESPACE=kamaji-tcp
export TENANT_NAME=jbbk-tenant-${rand} #Tenant Name must be unique
export TENANT_VERSION=1.29.1

#Version Available
#1.29 = 1.29.0, 1.29.1
#1.28 = 1.28.8, 1.28.7, 1.28.6, 1.28.5, 1.28.4, 1.28.3, 1.28.2, 1.28.1, 1.28.0 
#1.27 = #1.27.12, 1.27.11, 1.27.10, 1.27.9, 1.27.8, 1.27.7, 1.27.6, 1.27.5, 1.27.4, 1.27.3, 1.27.2, 1.27.1 

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
      - InternalIP
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
