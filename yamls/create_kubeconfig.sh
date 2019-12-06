#!/bin/bash
# configura o cluster
kubectl --kubeconfig 'kubeuser.conf' config set-cluster 'kubernetes' \
--server='https://200.100.50.100:6443' \
--certificate-authority '/etc/kubernetes/pki/ca.crt' \
--embed-certs
# configura o usuário
kubectl --kubeconfig 'kubeuser.conf' config set-credentials 'kubeuser' \
--client-key 'kubeuser.key' \
--client-certificate 'kubeuser.crt' \
--embed-certs
# configura o contexto (cluster + usuário)
kubectl --kubeconfig 'kubeuser.conf' config set-context 'default' \
--cluster 'kubernetes' \
--user 'kubeuser'
# configura o contexto padrão
kubectl --kubeconfig 'kubeuser.conf' config use-context 'default'
