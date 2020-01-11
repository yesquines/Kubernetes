#!/bin/bash

# Instalando Pacotes para o Loadbalancer e NFS
apt-get install -y haproxy vim nfs-kernel-server nfs-common -qq &> /dev/null && \
				echo "OK - Instalando Pacotes - Loadbalancer e NFS"

# Configurando HAProxy
cat > /etc/haproxy/haproxy.cfg <<EOF
global
user haproxy
group haproxy

defaults
mode http
log global
retries 2
timeout connect 3000ms
timeout server 5000ms
timeout client 5000ms

frontend kubernetes
bind 172.27.2.200:6443
option tcplog
mode tcp
default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
mode tcp
balance roundrobin
option tcp-check
server k8s-master-1 172.27.2.100:6443 check fall 3 rise 2
server k8s-master-2 172.27.2.110:6443 check fall 3 rise 2
server k8s-master-3 172.27.2.120:6443 check fall 3 rise 2
EOF
echo "OK - Configurado HAProxy"

# Configurando Pasta do NFS
mkdir -p /srv/v{1..4} && echo "OK - Configurada Pastas do NFS"
