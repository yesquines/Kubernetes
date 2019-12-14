
Configurando Cluster Kubernetes
===============================
Seguindo as boas práticas da utilização do Kubernetes, quando falamos de usa-lo em produção, é recomendado que seja criado um cluster de Kubernetes que irá contemplar máquinas **Masters**(que podem ficar em HA, por exemplo) e **Nodes**

Em suma são as máquinas **Masters** que vão gerenciar toda a arquitetura do Kubernetes.
Sendo que nos **Nodes** serão suportada das aplicações conteinerizadas.

No nosso caso, faremos a configuração de um Cluster **multi-master**. Ou seja teremos 3 Master que estarão em alta disponibilidade com HA Proxy

![MultiMaster](../images/multi_master1.png)

Porém para fazer a instalação do Ambiente Kubernetes teremos que seguir os seguintes passos nas máquinas criadas na nossa infraestrutura:

1. Instalar Docker;
2. Binários do K8S (kudeadm, kubectl, kubelet);
3. Desativar Swap;
4. Configurar o IPTables em Modo de Compatibilidade;
   - A partir do Debian 10 e CentOS 8 o IPTables foi alterado para **Nftable**;
5. Configurar Driver do CGroup;
6. Configurar o Kubelet;
7. Configurar o LoadBalancer entre as máquinas Masters;
8. Criar o arquivo de Configuração Principal.


Criando Infraestrutura
----------------------

Antes de iniciarmos a configuração do ambiente conforme os passos anteriores é necessário ter as máquinas virtuais já preparadas. Para isso vamos utilizar o **Vagrant**

![Vagant](../images/logo_vagrant.png)

o Vagrant é um ferramenta da Hashicorp que permite criar laboratórios baseados em um arquivo IaC (Infraestrutura como Código) chamado **Vagrantfile**

No Vagrantfile é determinado o **Provider**, ou seja, que tipo de software vai gerenciar as máquinas.
Por padrão, vamos utilizar o Virtualbox como provider, porém o Vagrant permite a utilização de outros Hypervisors e até mesmo da utilização do Docker.

Fora isso, também é possivel configurar uma forma de **Provision** que permite realizar configurações enquanto a máquina está sendo criada. Neste caso o Vagrant aceita, por exemplo, a utilização de Ansible, Shell, Puppet, entre outros.

> Projeto Vagrant: https://www.vagrantup.com/  
> Instalação do Vagrant: https://www.vagrantup.com/docs/installation/

Para podemos ver o Vagrantfile que será utilizado neste curso basta clicar aqui: [Vagrantfile](../Vagrantfile)

Para realizar a criação do ambiente, vamos criar um pasta e adicionar neste diretório o Vagrantfile:
```bash
mkdir k8s-541/
cd k8s-541/
wget link_vagrantfile
```

Com isso, de dentro do dirtório, podemos iniciar a criação das máquinas com o seguinte comando:
```bash
vagrant up
```

E após a criação podemos validar se todas as máquinas estão ativas:

```bash
vagrant status
```

E por fim, realizar o acesso as máquinas
```bash
vagrant ssh nome_maquina
vagrant ssh master1
```

**Comandos Comuns do Vagrant**:

Comandos     | Descrição
------------ |------------------
vagrant init| Gera o VagrantFile
vagrant box add <box> | Baixar imagem do sistema
vagrant box status    | Verificar o status dos boxes criados
vagrant up            | Cria/Liga as VMs baseado no VagrantFile
vagrant up --provision| Sobe a máquina com as alterações feitas no VagrantFile
vagrant provision     | Provisiona mudanças logicas nas VMs
vagrant status | Verifica se VM estão ativas ou não.
vagrant ssh 'vm'  | Acessa a VM
vagrant ssh 'vm' -c 'comando' | Executa comando via ssh
vagrant reload 'vm' | Reinicia a VM
vagrant halt  | Desliga as VMs


Instalação Manual
-----------------

Com as máquinas prontas é possivel seguir os passos criação do Ambiente Kubernetes multi-master:

#### Configuração dos MASTERS
As configurações de 1 a 6 serão realizadas nas 3 máquinas masters (master1, master2 e master3)

1. **Instalando o Docker**
  ```bash
  bash <<EOF
  apt-get update && apt-get install curl vim -y
  curl -fsSL https://get.docker.com | bash
  EOF
  ```

2. **Instalando Binários do Kubernetes**
  ```bash
  bash <<EOF
  apt-get install -y apt-transport-https
  curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
  EOF
  ```

3. **Desabilitando SWAP**
  ```bash
  bash <<EOF
  sed -Ei 's/(.*swap.*)/#\1/g' /etc/fstab
  swapoff -a
  EOF
  ```

4. **Configuranado IPTables para Modo de Compatibilidade**
  ```bash
  update-alternatives --set iptables /usr/sbin/iptables-legacy
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
  update-alternatives --set arptables /usr/sbin/arptables-legacy
  update-alternatives --set ebtables /usr/sbin/ebtables-legacy
  ```

5. **Configuração do Driver do CGroup**
  ```bash
  cat > /etc/docker/daemon.json <<EOF
  {
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "journald"
  }
  EOF
  systemctl restart docker
  ```
  > Kubernetes recomenda que configuração com systemd
  > https://kubernetes.io/docs/setup/production-environment/container-runtimes/

  Podemos validar se as configurações do CGroup para o Docker estão equivalentes a do Kubelet
  ```
  cat /var/lib/kubelet/kubeadm-flags.env
  docker system info | grep -i cgroup
  ```

6. **Configurando Kubelet**
      - master1
      ```bash
      echo "KUBELET_EXTRA_ARGS='--node-ip=200.100.50.100'" > /etc/default/kubelet
      ```
      - master2
      ```bash
      echo "KUBELET_EXTRA_ARGS='--node-ip=200.100.50.110'" > /etc/default/kubelet
      ```
      - master3
      ```bash
      echo "KUBELET_EXTRA_ARGS='--node-ip=200.100.50.120'" > /etc/default/kubelet
      ```
Essa configuração é necessária pois no Ambiente criado pelo Vagrant há duas interfaces de rede, dessa formar temos que especificar por qual rede o Kubernetes irá operar.

7. **Configuração do LoadBalancer**
  A configuração do LoadBalancer será na máquina **balancer-storage**.
  - Instalação do HAProxy
  ```bash
  apt-get install -y haproxy vim
  ```
  - Configuração do HAProxy
    ```bash
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
    bind 200.100.50.200:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

    backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server k8s-master-0 200.100.50.100:6443 check fall 3 rise 2
    server k8s-master-1 200.100.50.110:6443 check fall 3 rise 2
    server k8s-master-2 200.100.50.120:6443 check fall 3 rise 2
    EOF
    ```
    - Reinicio do Serviço
    ```bash
    systemctl restart haproxy
    ```

8. **Criando Arquivo de Configuração do Kubernetes**
  O **Master1** terá a responsabilidade de criar a configuração inicial com os certificados de acesso.
Nesse ponto o Master1 irá popular o etcd para que ele sirva de base para os outros masters.

  Para que seja possivel iniciar o cluster, precisavamos usar o comando **kubeadm** e para isso devemos criar um arquivo de configuração

  Neste arquivo identificamos qual máquina será o Loadbalancer, o endereço de rede utilizado no ambiente.

  - Arquivo: /root/kubeadm-config.yml
    ```bash
    cat > /root/kubeadm-config.yml <<EOF
    apiVersion: kubeadm.k8s.io/v1beta2
    kind: ClusterConfiguration
    kubernetesVersion: stable
    controlPlaneEndpoint: "200.100.50.200:6443"
    networking:
      podSubnet: "10.227.0.0/16"
    ---
    apiVersion: kubeadm.k8s.io/v1beta2
    kind: InitConfiguration
    localAPIEndpoint:
      advertiseAddress: "200.100.50.100"
      bindPort: 6443
    EOF
    ```

Inicializando o Cluster
-----------------------
Neste momento, utilizaremos de fato o kubeadm.
Podemos já fazer algumas validações como visualizar todas as imagens que são necessárias para ambiente Kubernetes
```bash
kubeadm config images list
```
Após isso podemos de fato iniciar o cluster utilizando o arquivo de configuração gerado no passo anterior.
```bash
kubeadm init --config /root/kubeadm-config.yml --upload-certs
```
> **A titulo de curiosidade**, caso tivessimos apenas um Master seria necessário executar apenas o comando abaixo:
```bash
kubeadm init --apiserver-advertise-address=200.100.50.100 --pod-network-cidr=200.100.50.0/24
```
> NÃO IREMOS EXECUTAR ESSE COMANDO

Após a inicilização do Cluster, seremos instruidos em relação a utilização arquivo de comunicação com o Kube Control e o Cluster
E também de como realizar o ingresso de outros Masters e outros Nodes no ambiente.
Ex:
```
Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of the control-plane node running the following command on each as root:

  kubeadm join 200.100.50.200:6443 --token 68pzp7.uqyatju1ycn9pu9u \
    --discovery-token-ca-cert-hash sha256:4569901991fc020319419c4d6da4bcfba34fcfbdaca964504aca88efc38c0a28 \
    --control-plane --certificate-key f3d6c4d4a0ec008e4846b7942b5a21d27cb86d6661fb1cb26f2f9f341ac46f47

Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
"kubeadm init phase upload-certs --upload-certs" to reload certs afterward.

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 200.100.50.200:6443 --token 68pzp7.uqyatju1ycn9pu9u \
    --discovery-token-ca-cert-hash sha256:4569901991fc020319419c4d6da4bcfba34fcfbdaca964504aca88efc38c0a28
```
Dessa saida iremos salvar o `kubeadm join` do Master e executa nos **master2** e **master3**
  * Configuranado o Arquivo de Comunicação.
    Neste arquivo é possivel identificar que seu conteúdo e baseado em Endereços e no Certificado CA do Usuário p/ Autenticação no ambiente.
    ```bash
    bash <<EOF
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    EOF
    ```
  * Realizando Join dos Masters (control-plane)
    - master2
    ```bash
      kubeadm join 200.100.50.200:6443 --token 68pzp7.uqyatju1ycn9pu9u \
    --discovery-token-ca-cert-hash sha256:4569901991fc020319419c4d6da4bcfba34fcfbdaca964504aca88efc38c0a28 \
    --control-plane --certificate-key f3d6c4d4a0ec008e4846b7942b5a21d27cb86d6661fb1cb26f2f9f341ac46f47 --apiserver-advertise-address=200.100.50.110
    ```
    - master3
    ```bash
      kubeadm join 200.100.50.200:6443 --token 68pzp7.uqyatju1ycn9pu9u \
    --discovery-token-ca-cert-hash sha256:4569901991fc020319419c4d6da4bcfba34fcfbdaca964504aca88efc38c0a28 \
    --control-plane --certificate-key f3d6c4d4a0ec008e4846b7942b5a21d27cb86d6661fb1cb26f2f9f341ac46f47 --apiserver-advertise-address=200.100.50.120
    ```
    > Este é apenas um exemplo já que os valores de chaves serão diferentes no seu ambiente
    > **OBS**: A utilização da flag _--apiserver-advertise-address=_ é devido a utilização de mais de uma interface de rede no ambiente do Vagrant.

  * Testando Configuração - Visualizando configurações do ambiente.
    ```bash
    kubeadm config view
    ```
    Verificando Nodes
    ```bash
    kubectl get node
    ```
    Neste primeiro momento as máquinas não ficarão **READY** e isso é devido a necessídade da configuração de um controlador de rede para o Kubernetes.
  > É possivel, em caso de necessidade, realizar o **Reset** das configurações do master ou nodes com o comando a seguir:
  ```bash
  kubeadm reset -f
  ```
  > NÃO IREMOS EXECUTAR ESSE COMANDO

Controlador de REDE
--------------------
Pelo fato do Kubernetes não tem um plugin de rede padrão precisamos fazer sua instalação para que seja possivel a comunicação dos componentes.

Há inúmeras opções de Plugins de redes que podem ser visualizadas com link abaixo:
https://kubernetes.io/docs/concepts/cluster-administration/networking/

### Projeto Cálico

![Projeto_Calico](../images/logo_calico.png)

No cluster do nosso laboratório vamos utilizar o Cálico para fazer o plugin de rede.
Basicamente, o cálico utiliza uma rede baseada em comunicação via BGP.

**Estrutura do Cálico**:
![Calico](../images/calico_infra.png)

> https://www.projectcalico.org/

* Configuração do Calico:
  - Baixando o YML de configuração do Cálico.
  ```bash
  wget https://docs.projectcalico.org/v3.8/manifests/calico.yaml
  ```
  - Alterando a rede utilizada de 192.168.0.0/16 para 10.227.0.0/16
  ```bash
  sed -i 's,192.168.0.0/16,10.227.0.0/16,g' /root/calico.yaml
  ```
  > 10.227.0.0/16 foi a rede configurada no nosso arquivo de configuração do cluster.
  - Implementando as configurações do Cálico
  ```bash
  kubectl apply -f /root/calico.yaml
  ```

Após o Kubernetes provisionar o Cálico já devemos conseguir visualizar todos os Masters prontos para utilização:
```bash
kubectl get node
```

---

Arquivos e Diretórios do Kubernetes
-----------------------------------
Dentro do ambiente do Kubernetes há arquivos e diretório importantes.
* Arquivos
  - **/etc/kubernetes/admin.conf**: Permite a gerencia do ambiente Kubernetes
  - **/etc/kubernetes/{controller-manager,kubelet,scheduler}.conf**: Identificações de cada componente dentro do ambiente.
  - **/var/lib/kubelet/config.yaml**: Configurações do Kubelet
  - **/var/lib/kubelet/kubeadm-flags.env**: Flags de inicilização do Kubelet
    - Para incluir argumentos extras para o Kubelet é usado o arquivo _/etc/default/kubelet_
* Diretórios
  - **/etc/kubernetes/manifests/**: Diretórios com YAMLs de configurações dos POD Estáticos.
  - **/etc/kubernetes/pki/**: Certificados TLS utilizados pelo Kubernetes
  - **/var/lib/kubelet/pki/**: Certificados TLS utilizados pelo Kubelet
  - **/var/lib/kubelet/pods/**: Referencia dos PODs

Taint e Tolerants
-----------------
Para que seja possivel a criação de PODs nos Nodes, o ambiente Kubernetes trabalha com regras de _Taint_ e _Tolerants_.

O **Taint** são marcações escritas no formato de chave e valor associadas ao Node ou Master. Essa marcações estão ligadas a regras de tolerancia associadas aos PODs que são chamadas de **Tolerants** que define se o Pod vai "tolerar" ou não algum tipo de Taint. Esse conjunto permite que o POD não seja criado em um Node inapropriado.

Para podermos enxergar isso minimamente, vamos tentar criar um pod simples nesse ambiente Multi Master:

* Criando o arquivo pod_simples.yml
  ```yml
  apiVersion: v1
  kind: Pod
  metadata:
    name: pod-simples
    labels:
      app: app-simples
  spec:
    containers:
      - name: app-simples
        image: hashicorp/http-echo
        args:
          - "-text=POD_SIMPLES"
          - "-listen=:80"
        ports:
        - containerPort: 80
  ```
  ```bash
  kubectl create -f pod_simples.yml
  kubectl describe pod pod-simples
  ```
  Ao tentar criar o pod, podemos ver que ele não conseguiu ser criado, já que nenhum das máquinas de estão como master tem Taint que são tolerados pelos PODs.
  Evento apresentado:
  ```
  Warning  FailedScheduling  <unknown>  default-scheduler  0/3 nodes are available: 3 node(s) had taints that the pod didn't tolerate.
  ```
  Podemos executar o describe em um dos master e vamos ver que há uma minha especificando um Taint:
  ```bash
  kubectl describe node master1
  ```
  Taint do Master1:
  ```
  Taints: node-role.kubernetes.io/master:NoSchedule
  ```
* Permitir Agendamento de PODs nas máquinas Masters
  Com isso, para que os PODs possam ser criados nesse ambiente há duas opções:
  - Retirar o Taint dos Masters
  - Ou criar, em cada Pod, Tolerants para o Taint dos Masters
  No nosso caso a melhor opção será fazer a retirada do Taint no Master.
  O comando **kubectl taint** permite que façamos a adição ou exclusão de Taint.
  - Sintaxe para adicionar um Taint
    ```bash
    kubecl taint node NOME_NODE chave=valor:efeito
    ```
    Os efeitos possiveis são:
    - **NoSchedule**: Pod não será Agendado no Node
    - **PreferNoSchedule**: Preferencialmente pod não será agendado, porém não é uma marcação obrigatória o sistema ainda tentará fazer o agendamento.
    - **NoExecute**: Evacua o POD do Node caso ele não tolere o Taint.
  - Excluindo o TAINT dos Masters
    Para excluir um Taint é necessário apenas a utilização de um **traço(-)**
 no final da sentença de chave=valor:efeito.
    Para que a exclusão do Taint alcançasse todos os nodes utilizamos a opção **--all**.
    ```bash
    kubectl taint node --all node-role.kubernetes.io/master-
    ```
    Nesse momento o POD já pode ser agendado em alguma das máquinas.
    ```bash
    kubectl get pod
    ```
    Agora o POD já está **running** em nosso ambiente.

Manipulação de Tokens
---------------------
Após o Cluster ser iniciado é possivel manipular os tokens para ingresso de nodes no ambiente.
Essa é uma prática interessante já que permite limitar o tempo de válidação do token, fazendo com que os token sejam utilizados somento quando há de fato um novo node para ser adicionado.
* Listar tokens disponiveis:
  ```bash
  kubeadm token list
  ```
* Criar token com ciclo de vida especifico.
  ```bash
  kubeadm token create --print-join-command --ttl 30m
  ```
  Após a criação do token temos como retorna exatamente o comando de seria utilizado para ingressar um node em nosso ambiente.
  Por exemplo:
  ```
  kubeadm join 200.100.50.100:6443 --token oe0dtl.n9v3pbvhha0nv1ty --discovery-token-ca-cert-hash sha256:2b99bb7d43d651a200a84b04996618333d668817b96bf0333e2c34b1bec1bada
  ```
  Como a utilização de um node no nosso ambiente pode acarretar em uma extrapolação de recurso, não iremos utiliza-lo em nenhuma máquina.
* Remover Tokens
  ```bash
  kubeadm token delete TOKEN
  ```

Backup do ETCD
--------------
Como o ETCD armazena todas as informações do cluster. É interessante executar os procedimentos de Backup.
O ETCD tem um binário chamado **etcdctl** que permite fazer o acesso externo ao ETCD e gerar o seu backup.

* Baixando o Binário do ETCD
  Para baixar o binário é necessário acessar o Projeto do ETCD no GitHub:
  https://github.com/etcd-io/etcd
  Acessar o Menu **Releases** e Baixar o arquivo etcd-VERSÃO-linux-amd64.tar.gz
  Por exemplo:
  ```bash
  wget https://github.com/etcd-io/etcd/releases/download/v3.3.18/etcd-v3.3.18-linux-amd64.tar.gz
  ```
* Descompatando o tar.gz
  ```bash
  tar -xf etcd-VERSÃO-linux-amd64.tar.gz
  ```

Após descompacta-lo vamos adicionar o binário em um diretório para que seja possivel executa-lo dentro do ambiente.
```bash
cd etcd-VERSÃO-linux-amd64/
mv etcdctl /usr/local/bin/
```
E após isso já é possivel executa-lo:
```bash
etcdctl --help
ETCDCTL_API=3 etcdctl --help
```
Para cada versão do ETCDCTL o binário retorna opções diferentes. Vamos utilizar a ultima versão, no caso, a **versão 3**
Com isso vamos exportar a variavel **ETCDCTL_API** para torna-la global:
```bash
export ETCDCTL_API=3
cd /etc/kubernetes/pki/etcd/
```
É necessário acessarmos a pastar _/etc/kubernetes/pki/etcd_ para facilitar a escrita do comando, já que para realizar a autenticação no **etcd** e ter acesso aos dados é necessário utilizar os certificados.
* Realizando o Backup
  ```bash
  etcdctl snapshot save --cacert ca.crt --cert server.crt --key server.key /root/etcd.db
  ```
* Validanado o Status do Arquivo
  ```bash
  etcdctl snapshot status --cacert ca.crt --cert server.crt --key server.key /root/etcd.db
  ```
Não iremos realizar o restore do Backup, porém se fosse necessário faze-lo é importante estar ciente da necessidade de um procedimento de Backup para o diretório **/etc/kubernetes**.
  - Exemplo do Comando de Restore:
  ```bash
  etcdctl snapshot restore --data-dir="/var/lib/etcd/" /root/etcd.db
  ```
---
