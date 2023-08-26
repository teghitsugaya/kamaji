#!/bin/bash

cat << EOF | tee containerd.conf
overlay
br_netfilter
EOF

cat << EOF | tee 99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sudo apt update && sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sed -e "s#SystemdCgroup = false#SystemdCgroup = true#g" | sudo tee -a /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd
sudo chown -R root:root containerd.conf
sudo mv containerd.conf /etc/modules-load.d/containerd.conf
sudo modprobe overlay && sudo modprobe br_netfilter
sudo chown -R root:root 99-kubernetes-cri.conf 
sudo mv 99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf
sudo sysctl --system
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update
sudo apt install -y kubeadm=1.26.1-00 kubelet=1.26.1-00 kubectl=1.26.1-00 --allow-downgrades --allow-change-held-packages
sudo apt-mark hold kubelet kubeadm kubectl
