##To Create Cluster

bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/createcluster.sh)


##To Add Worker

bash <(curl -s https://raw.githubusercontent.com/teghitsugaya/kamaji/main/addworker.sh)
               

##Delete Worker

- drain node
- cordon node
- kubectl delete nodes $(node_worker)
- openstack server delete $(node_worker)


