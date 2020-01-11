#!/bin/bash

#1. Instalando Docker
export DEBIAN_FRONTEND=noninteractive
apt-get update &> /dev/null && \
				apt-get install -y apt-transport-https curl vim nfs-common -qq &> /dev/null && \
				curl -fsSL https://get.docker.com | bash &> /dev/null && \
				echo "OK - 1. Instalando Docker e Dependencias"

#2. Preparando Repositório do Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - &> /dev/null && \
				echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list && \
				echo "OK - 2. Preparando Repositório do Kubernetes"

#3. Desabilitando SWAP
sed -Ei 's/(.*swap.*)/#\1/g' /etc/fstab && \
				swapoff -a && \
				echo "OK - 3. Desabilitando SWAP"


#4. Configuranado IPTables para Modo de Compatibilidade
update-alternatives --set iptables /usr/sbin/iptables-legacy &> /dev/null && \
				update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy &> /dev/null && \
				#update-alternatives --set arptables /usr/sbin/arptables-legacy 
				#update-alternatives --set ebtables /usr/sbin/ebtables-legacy 
				echo "OK - 4. Configuranado IPTables para Modo de Compatibilidade"
				
#5. Configuração do Driver do CGroup
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "journald"
}
EOF
systemctl restart docker && \
				echo "OK - 5. Configuração do Driver do CGroup"
