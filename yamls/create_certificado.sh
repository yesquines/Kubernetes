#!/bin/bash
openssl genrsa -out kubeuser.key 2048 && \
openssl req -new -key kubeuser.key -out kubeuser.csr -config csr.conf && \
openssl x509 -req -in kubeuser.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out kubeuser.crt -days 365 -extensions v3_ext -extfile csr.conf
