Tipos de Instalação do Kubernetes
=================================

* **Manual**
* **Minikube**
* **Cloud**:
  - Google: GKE
  - Azure: AKS
  - AWS: EKS

Minikube
========
O Minikube é um Programa para gerenciamento de máquinas virtual que permite a manipulação do Kubernetes com todos os componentes já preparados. Porém, é necessário frisar que o Minikube é utilizado apenas em ambiente de Laboratório, ou seja, _jamais deve ser usado em produção_.

Para utilizar o Minikube é necessário o **kubectl** ou Kube Control para que seja possivel gerenciar o Kubernetes.

A instalação do Minikube e do Kube Control podem ser feitas conforme abaixo:

* Instalação do Kube Control:
```bash
bash << EOF
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubctl /usr/local/bin/
EOF
```

> Reference:  https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux

* Instalação do MiniKube
```bash
bash << EOF
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
mv minikube /usr/local/bin/
EOF
```

> Projeto MiniKube: https://github.com/kubernetes/minikube/releases

* Validando Versão do Minikube
  ```bash
  minikube version
  ```

* Verificando Opções Validas
  ```bash
  minikube help
  ```

* Iniciando o MiniKube
  Quando iniciarmos o Minikube será iniciado um pequeno ambiente Kubernetes:
  ```bash
  minikube start
  ```

Após a finalização da iniciliazação do Minikube, podemos iniciar as verificações básicas no cluster de Kubernetes:

Kubernetes - Comandos Iniciais
------------------------------

#### Coleta de Informações
Primeiramente vamos coletar alguns informações básicas do Cluster.
De inicio podemos ver o **cluster-info** com o seguinte comando:

```bash
kubectl cluster-info
```

A partir desse momento é importante entendermos como funciona a sintaxe de comandos do Kubernetes, já que ela está totalmente relacionada as interações com seus objetos.

Em sua maioria os comandos do Kubernetes funcionando com a informação de um **VERBO** (operação que será realizada) mais um **OBJETO** (componente do Kubernetes que receberá a ação) e caso necessário **FLAGS** (opções adicionais)

```bash
kubectl [VERB] [OBJECT] [NAME] [flags]
kubectl get node
```

Dessa forma, após listar os nodes é possivel adquirimos mais informações sobre um node especifico utilizando a operação **describe**

```bash
kubectl describe nodes [NAME_NODE]
```

Outra operação comum no Kubernetes é o **get**. Com ele é possivel listar os objetos criados no ambiente, por exemplo, ver quais são os **namespaces** criados:

```bash
kubectl get namespaces
```

Alguns objetos podem ser abreviados no comando do Kube Control, sendo assim a listagem de namespace poderia ser reduzida da seguinte maneira:

```bash
kubectl get ns
```

Dessa forma, assim como fizemos com os nodes, é possivel obter mais informações de um determinado namespace com o seguinte comando:

```bash
kubectl describe ns [NAME_NAMESPACE]
```

Com isso, podemos fazer pequenas avaliações para os principias objetos:
* Verificando Pods
  ```bash
  kubectl get pods
  ```
* Verificando Pods por Namespace
  ```bash
  kubectl get pods --namespace kube-system
  ```
  Há dois pontos de atenção nesse caso:
  - É possivel abreviar a opção `--namespace` por **-n**
  - E a saida desse comando irá apresentar os pods que mantém o sistem do Kubernete que, em suma, são os componentes necessário para o funcionamento Cluster.
* Verificando Deployment do NameSpace _kube-system_
  ```bash
  kubectl get deployments -n kube-system
  ```
* Verificando Service
  ```bash
  kubectl get svc -n kube-system
  ```
  Caso seja necessário obter um saida mais completa podemos usar a opção **-o** que permite estender o _output_ do comando para mais informações ou outros formatos de saída.
  ```bash
  kubectl get service -o yaml
  kubectl get deploy -o wide
  ```
  Por fim, é possivel também fazer a verificação dos objetos de todos os namespaces, como no exemplo abaixo:
  ```bash
  kubectl get pods -A
  kubectl get deploy --all-namespaces
  ```

Criando Objetos no Kubernetes
-----------------------------
De forma geral, quase todos os objetos no Kubernetes podem ser criados via linha de comando ou via arquivo YAML.

A criação via arquivo YAML é a mais comum de ser utilizada, principalmente pelo fato de ser possivel versionar as configurações.

Porém é interessante entender como criar alguns Objetos via linha de comando.
Isso é uma boa prática para entender seu funcionamento, além de, em alguns momentos, ajudar na criação dos arquivos YAML.

#### Criando POD
Com isso, para que a gente possa criar um Pod é necessário executar o seguinte comando:

```bash
kubectl run nginx --generator=run-pod/v1 --image nginx:alpine
```

Com o POD criado podemos executar comandos para validar o container criado e suas informações.

* Verificar Criação do POD
  ```bash
  kubectl get pod
  ```

Neste caso o nosso POD tem apenas um container que está utilizando a imagem _nginx:alpine_ e podemos manipular o container com o Kube Control.
* Execução de Comandos no Container
  ```bash
  kubectl exec -ti NAME_POD COMMANDS
  kubectl exec -ti nginx -- nginx -v
  ```
  Podemos perceber que o execução de comandos em um container no Kubernetes é realizado da mesma maneira de um ambiente Docker, sendo possível até acessar o container:
  ```bash
  kubectl exec -ti nginx sh
  ```
  Caso no POD exista mais de um container é possivel executar comandos ou acessar o container passando seu nome com a opção `--container` ou, sua opção _sort_, `-c` conforme a sintaxe abaixo:
  ```bash
  kubectl exec -c NAME_CONTAINER -ti NAME_POD COMMAND
  ```
* Validando Conexão ao NGINX
  Devido a utilização do Minikube, temos que executar os comandos no node diretamente por ele.
  Com isso, primeiro vamos identificar qual o IP do container
  ```bash
  kubectl get pod -o wide
  ```
  E após isso podemos realizar um requisão na porta 80 do container:
  ```bash
  minikube ssh curl IP_CONTAINER
  ```
* Vendo Logs do Container
  Após realizar a requisição no serviço web do container, podemos avaliar os logs gerados da seguinte maneira:
  ```bash
  kubectl logs NAME_POD
  ```
  Caso eu não queira mais manter esse pod, posso realizar sua exclusão com o seguinte comando
  ```bash
  kubectl delete pod NAME_POD
  ```
  É importante ressaltar que a exclusão dos objetos do Kubernetes segue a seguinte sintaxe:
  ```bash
  kubectl delete OBJECT NAME_OBJECT
  ```

#### Criando DEPLOYMENT
O Deploymente é o objeto de alto nível e também pode ser criado via _command line_.

* Criar Deployments
  ```bash
  kubectl create deploy httpd --image=httpd:alpine
  ```
  Após a criação do Deploy é possivel visualiza-lo utilizando o **get deploy**
  ```bash
  kubectl get deploy
  ```
  Como o deploy está inteiramente associado a um pod é possivel visualizar quantos pods forma criados com esse Deploy.
  ```bash
  kubect get pod
  ```
  Podemos ver que ele criou apenas um pod.
  O Deployment faz a gerencia tanto de Pod, Réplicas da aplicação e estratégia de aplicação.
  É possivel, mesmo criando o deploy via command line, ver como foram descritas as suas configurações:
  ```bash
  kubectl get deployment -o yaml
  ```
  Com isso, podemos validar que via command line o Deploy é criado com apenas uma réplica.
  Para que, sem um arquivo yaml, seja possivel aumentar a quantidade de replicas, podemos usar o seguinte comando:
  ```bash
  kubectl scale deploy NAME_DEPLOY --replicas=3
  ```
  Dessa forma, a aplicação será escalada 3 vezes utilizando o templante de pod baseado na imagem do Apache (httpd:alpine).
  Podemos confirmar o aumento das replicas da seguinte forma:
  ```bash
  kubectl get deploy
  kubectl get pod
  ```

**SERVICE**

Após realizar o _Deployment_ devemos começar a pensar em como vamos realizar o acesso da aplicação. Nesse momento é válido entender em qual estágio a aplicação está: Produção, Testes, Homologação, etc.

Já que para cada um dessas fases podem ser acessadas de maneiras diferentes dependendo da estrátégia da empresa.

Os tipos de Services que podemos usar são os seguintes:

Tipos de Services | Descrição
------------------|----------
ClusterIP | Expôem o Serviço para um IP Interno do Cluster
NodePort | Expõe o Serviço para cada IP dos Nodes e em uma Porta Estatica
LoadBalancer | Expôe o Serviço Externamente (Cria ClusterIP e NodePort Automaticamente)
ExternalName | Mapeia o Serviço para um DNS (Necessário o CoreDNS)
> Referência: https://kubernetes.io/docs/concepts/services-networking/service/

Neste primeiro momento, assim como os outros objetos, vamos realizar as configurações via command line.

* Criando Service para o Deploy
  Vamos utilizar o Deploy anterior para expor sua porta e podermos acessar a aplicação de dentro do cluster.
  ```bash
  kubectl expose deploy NAME_DEPLOY --port 80
  ```
  Neste caso, por padrão o service será criado com o tipo _ClusterIP_ e a porta 80 será exposta.
* Visualizando Service
  ```bash
  kubectl get services
  ```
* Acessando Aplicação.
  Para que seja possivel acessar a aplicação precisamos novamente do Minikube, já que o ClusterIP só funciona para IP Internos do Cluster.
  Com o seguinte comando, conseguimos acessar o cluster e executar um requisão no IP criado pelo Service:
  ```
  minikube ssh curl IP_SERVICE`
  ```

Dessa forma fazemos o acesso apenas de dentro do Cluster. Para que seja possivel o acesso externo podemos usar o tipo NodePort na criação do service.
* Deletando Service
  ```bash
  kubectl delete svc NAME_SERVICE
  ```
* Alterando Tipo do Service
  ```bash
  kubectl expose deploy NAME_DEPLOY --port 80 --type NodePort
  ```
* Verificando Service Criado com NodePort
  ```bash
  kubectl get svc
  ```
> Após configurar o Service como NodePort é liberada, para acesso, uma **porta maior que 30000** que será redirecionada para a porta 80 do container no POD.

Com o Service criado agora podemos acessar a aplicação pelo IP da máquina virtual. Para isso temos que saber qual o IP utilizado pelo Minikube
* Pegando IP do Minikube
  ```bash
  minikube ip
  ```
* Acessando Aplicação
  ```bash
  curl IP_MINIKUBE:PORT_NODEPORT
  curl 192.168.99.100:31000
  ```
  Sendo assim, agora é possivel realizar o acesso via qualquer Browser.
---
