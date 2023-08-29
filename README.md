Prequisites
  To Running The script for Create a clusters, Workstation must be:
   - Installed Kubeadm Package
   - Installed Kubectl Package
   - Installed Openstack client Package
   - Have to comunicate to Public API URL Openstack Cluster via 
   - have a Kubeconfig Admin Kamaji Cluster
   - have a Keystone Tenant Project Openstack 
   
To Create Cluster
  Edit the parameters, and execute
    bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/createcluster.sh)

To Add Worker
  To Add the Worker, cluster name and version must same form exsiting cluster,
  To see exsiting cluster, exceute this command !
    kubectl get tcp -n default  | awk 'BEGIN { print "NAME VERSION" } NR > 1 { print $1, $2 }'
  
  Edit the parameters, and execute  
    bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/addworker.sh)
               
Delete Worker
  - drain node
  - cordon node
  - kubectl delete nodes $(node_worker)
  - openstack server delete $(node_worker)
