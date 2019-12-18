Ciclo de Vida e Estratégias de Deploy
======================================

Nesta aula vamos tratar do ciclo de vida da aplicação e como podemos gerenciar os deploys realizados no Kubernetes.

Os tópicos abordados serão
* Estratégias de Deploy e Rollback da Aplicação
* DaemonSet
* AutoScale
* Liveness

Estratégias de Deploy e Rollback da Aplicação
---------------------------------------------

Quando criamos um deploy é possivel trabalhar com algumas opções de para garantir que a aplicação tenha o menor _Downtime_(Tempo de Inatividade) possivel ou que as atuazações ocorram de maneira adequada.

De maneira geral um deploy tem duas estrategias possiveis:
* **RollingUpdate**: Que permite a atualização parcial da aplicação. Neste caso não há inatividade da aplicação, já que uma porcentagem é atualizada primeiro e apenas após essa porcentagem ficar estavel que a segunda parcela seria atualizada.
* **Recreate**: Neste caso a estratégia e simplemente apagar a aplicação antiga e recriar o ambiente já com a atualização da aplicação. Neste caso há o Downtime já que todo o ambiente é atualizado de uma vez.

É Possivel também realizar o registro de estados da aplicação, sendo assim qualquer alteração seria mapeada pelo ambiente do Kubernetes e com isso seria possivel voltar para versões estaveis em caso de problemas na aplicação. Essa é a definição do **Rollback**

Com isso vamos criar um Deploy, simples e analisar o seu comportamento baseados nas estratégias de deploy e nas formas de registrar as alterações e fazer rollback delas.

* Estratégia - RollingUpdate (**deploy-nginx.yml**)
  ```yml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: deploy-nginx
    labels:
      app: deploy
  spec:
    replicas: 5
    selector:
      matchLabels:
        app: pod-nginx
    strategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 2
        maxUnavailable: 3
    template:
      metadata:
        labels:
          app: pod-nginx
      spec:
        containers:
        - name: nginx
          image: nginx:alpine
          ports:
          - containerPort: 80
  ```
  É possivel identificar que agora temos uma estratégia de deploy bem definda baseadas nas seguintes opções:
  * **strategy**: Inicia as configurações de estratégia.
    - **type**: Tipo da estratégia. RollingUpdate ou Recreate
    - **rollingUpdate**: Inicia a configuração da estratégia RollingUpdate.
      - **maxSurge**: Máximo de máquinas ativas durante a atualização.
      - **maxUnavailable**: Máximo de máquinas desativada para serem atualizadas.
      > Pode ser usado números interos ou porcentagem para definição da atualização.

  Para aplicar a criação do Deploy usaremos a opção **--record** que irá armazenar a mudança realizada também chamada de "_revision_". Sendo assim, criamos um pequeno histórico de atualizações.
  ```bash
  kubectl create -f deploy-nginx.yml --record
  ```
  Para visualizar o historicos de mudança podemos usar o seguinte comando:
  ```bash
  kubectl rollout history deployment deploy-nginx
  ```
  Com isso podemos realizar uma mudança em nosso deploy:
  ```bash
  kubectl set image deployment/deploy-nginx nginx=httpd:alpine --record
  kubectl rollout status deployment deploy-nginx
  ```
  Com isso o comando `kubectl rollout status` permite avaliar as mudanças das replicas do nosso deploy.

  E após o fim das mudanças, teremos uma segunda alteração listada no nosso _history_ de deploy:
  ```bash
  kubectl rollout history deployment deploy-nginx
  ```
  Com isso podemos voltar a configuração do qual utilizava a imagem do nginx:alpine nos containers dos Pods:
  ```bash
  kubectl rollout undo deployment deploy-nginx --to-revision=1 && \
  kubectl rollout status deployment deploy-nginx
  ```
  Dessa forma podemos ver todas as replicar foram alteradas para voltar a utilizar a imagem do nginx:
  ```bash
  kubectl describe deploy deploy-nginx
  ```

* Estratégia - Recreate  
  Para testar a estratégia de Recreate vamos fazer a alteração no deploy-nginx.

  Vamos alterar o o arquivo **deploy-nginx.yml** e deixa-lo com o seguinte conteúdo:
  ```yml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: deploy-nginx
    labels:
      app: deploy
  spec:
    replicas: 5
    selector:
      matchLabels:
        app: pod-nginx
    strategy:
      type: Recreate
    template:
      metadata:
        labels:
          app: pod-nginx
      spec:
        containers:
        - name: nginx
          image: nginx:alpine
          ports:
          - containerPort: 80
    ```
    Neste caso temos agora a estratégia como Recreate, ou seja, a cada atualização todos os pods ativos serão recriados.

    Para realizar esse teste vamos fazer um rollback para a imagem do httpd:alpine e ver a mudança com o comando watch
  ```bash
  kubectl rollout history deployment deploy-nginx
  kubectl rollout undo deployment deploy-nginx --to-revision=4 && \
  watch -n0 kubectl get pod -l app=pod-nginx
  ```
  > Atenção a versão do _revision_, já que o número 4 pode ser uma versão diferente no seu ambiente.

DaemonSet
---------
O DaemonSet é um outra forma de estratégia de deploy. Neste caso a aplicação será adicionada em todos os Nodes do ambiente.

Dessa forma podemos validar a sua ação criando o arquivo **daemonset-busybox.yml**:
```yml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: daemonset
spec:
  selector:
    matchLabels:
      app: busybox
  template:
    metadata:
      labels:
        app: busybox
    spec:
      containers:
      - name: busybox
        image: busybox
        imagePullPolicy: IfNotPresent
        tty: true
```
```bash
kubectl create -f daemonset-busybox.yml
```
Conseguimos ver que a estrutura do DaemontSet é bem semelhante a de um Deployment, sendo a grande diferença o fato de ser criado Pods em cada Node.

Podemos validar a criação em cada node com o seguinte comando:
```bash
kubectl get pod -l app=busybox -o wide
```

Não iremos repetir os testes, mas o DaemonSet também aceita estratégia de deploy. Porém ao invés da palavra _strategy_ é usado **updateStrategy** abaixo dessa opção a sintaxe para utilizar o RollingUpdate ou o Recreate é a mesma que o deploy.

StatefulSet
-----------
O StatefulSet é um metodo de deploy que implanta aplicações com estado. Para cada POD do Stateful há uma identificação única. O Objetivo do Statefulset é garantir a exclusividade e ordem dos Pods.

Antes de criar o StatefulSet, vamos deixar preparado um StorageClass e dois PV(PersistentVolumes), já que não temos um provider para gerar os volumes dinamicamente.

O primeiro arquivo é o sc-statefulset.yml
```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: counter
provisioner: kubernetes.io/no-provisioner
```
E logo em seguida criaremos o PV apontando para o StorageClass criado no passo anterior. O conteúdo do arquivo pv-statefulset.yml é o seguinte:
```yml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv03-nfs
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  storageClassName: counter
  nfs:
    server: 200.100.50.200
    path: "/srv/v3"
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv04-nfs
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  storageClassName: counter
  nfs:
    server: 200.100.50.200
    path: "/srv/v4"
```
E por fim, vamos criar o arquivo statefulset.yml para criar uma aplicação baseada em Estados.
```yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: counter
spec:
  serviceName: "counter-app"
  selector:
    matchLabels:
      app: counter
  replicas: 2
  template:
    metadata:
      labels:
        app: counter
    spec:
      containers:
      - name: counter
        image: "kahootali/counter:1.0"
        volumeMounts:
        - name: counter-vol
          mountPath: /app/
  volumeClaimTemplates:
  - metadata:
      name: counter-vol
    spec:
      accessModes: ["ReadWriteMany"]
      resources:
        requests:
          storage: 256Mi
      storageClassName: counter
```
É interessante perceber que o StatefulSet trabalho com uma gama maior de recursos, já que é possivel, por exemplo, passar a ele um template de PersistentVolumeClaim que irá, na maioria das vezes, requerer o volume de um StorageClass.
```bash
kubectl create -f statefulset.yml
kubectl get pod -l app=counter
```
Podemos ver que o nome dos PODs seguem um padrão: `NOME_STATEFULSET-INTEIRO`.

No nosso caso, como criamos duas replicas, teremos **counter-0** e **counter-1**. Esse padrão se estende para outros objetivos criados a partir do StatefulSet, como por exemplo os volumes que vão seguir o padrão `NOME_STATEFULSET-VOL-NOME_POD`, por exemplo: **counter-vol-counter-0**

Lembrando que as estrátegias de deploy também valem para o StatefulSet usando o parametro **updateStrategy** assim como o DaemonSet.

AutoScale
---------
É interessante, sempre que falamos em aplicação, de conseguir manter-la com alta disponibilidade independete da quantidade de requisão.

Para esse tipo de situação uma das soluções é criar o AutoScale da Aplicação. Sendo possivel scalar horizontalmente a aplicação e, consequentemente, suprir a demandas de requisições.

No ambiente Kubernetes, é utilizado o HPA (Horizontal Pod AutoScaler). Com isso, para que HPA funcione plenamente é necessário a instalação do **Metric Server**

O Metric-Server é o responsável por conseguir coletar os dados de utilização dos Nodes e Pods do Kubernetes, permitindo a utilização de um Deployment para que possa acionar o HPA e escalar a aplicação.

![Diagram_HPA](../images/horizontal-pod-autoscaler.svg)

Com isso, vamos realizar a configuração do Metric-Server:
> Projeto: https://github.com/kubernetes-incubator/metrics-server.git

1. Realizar o Clone do Metric-server:
  ```bash
  git clone https://github.com/kubernetes-incubator/metrics-server.git
  ```
2. Alterar configurações do arquivo **metrics-server/deploy/1.8+/metrics-server-deployment.yaml**
  ```bash
  args:
  - --kubelet-preferred-address-types=InternalIP
  - --kubelet-insecure-tls
  - --cert-dir=/tmp
  - --secure-port=4443
  securityContext:
    readOnlyRootFilesystem: false
  ```
3. Instalar o Metric-Server
  ```bash
  kubectl create -f metrics-server/deploy/1.8+/
  ```
4. Validar Coleta de Métricas:
  ```bash
  kubectl top node
  kubectl top pod
  ```

Após a configuração do Métric-Server, podemos criar um deployment para testar o AutoScale.  
* Criando Deployment - deploy-hpa.yml
  ```yml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    labels:
      app: nginx
    name: nginx
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: nginx
    template:
      metadata:
        labels:
          app: nginx
      spec:
        containers:
        - image: nginx:alpine
          name: nginx
          ports:
          - containerPort: 80
          resources:
            limits:
              cpu: 250m
              memory: 110Mi
            requests:
              cpu: 200m
              memory: 100Mi
  ```
  É necessário entender que para o AutoScale funcionar é preciso definir os Limites e Requisições de CPU e Memoria do Deploy.
  ```bash
  kubectl create -f deploy-hpa
  ```

* Criando HPA:
  ```bash
  kubectl autoscale deployment nginx --cpu-percent=50 --min 2 --max 15
  ```
  Neste caso definimos que no minimos teremos 2 pods e no máximo 15 e que haverá o autoscale quando o total de utilização de CPU for igual ou maior de 50%.
  ```bash
  kubectl get hpa
  ```
  Pode levar um tempo para que a opção **Targets** apareça **0%/50%**.

* Testando HPA.
  Para gerar requisições no deploy, mas realizar um teste simples de stress utilizando o Apache Benchmark:
  ```
  apt-get install apache2-utils -y
  ```
  Pegue o IP de um dos Pod do Deploy:
  ```bash
  kubectl get pod -l app=nginx -o wide
  ```
  E adicione como URL no teste do AB:
  ```
  ab -k -n 100000000 -c 100 http://10.227.136.11/
  ```
  Por fim monitore em uma aba ou janela a aparte o HPA:
  ```bash
  watch -n0 'kubectl get hpa ; kubectl get pod -l app=nginx'
  ```

Liveness
--------
Para que seja possivel validar que a aplicação está realmente sendo executada como deveria é possivel criar um **Health Checks** no Pod.

Dentro do Kubernetes temos duas formas de realizar essa validação:

* **Liveness**: Essa forma é a mais simples, já que é simplesmente a checagem da "saúde" da aplicação.
* **Readiness**: O Readiness trabalho igual ao Liveness, porém o seu diferencial é o fato de que se o HeathCheck falhar ele não irá permitir que o Pod receba requisição.

Na Aula iremos tester o **Liveness**.

Com isso, vamos criar um arquivo chamado **liveness.yml** com o seguinte conteúdo:
```yml
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: k8s.gcr.io/liveness
    args:
    - /server
    livenessProbe:
      httpGet:
        path: /healthz
        port: 8080
        httpHeaders:
        - name: Custom-Header
          value: Awesome
      initialDelaySeconds: 3
      periodSeconds: 3
```
```bash
kubectl create -f liveness.yml
```
Neste caso estamos utilizando um Imagem da propria Documentação do Kubernetes que nos primeiros 10s irá retornar _status code_ 200, ou seja a aplicação estará rodando, porém após os 10 segundos o Liveness só receberá o _status code_ 500, ou seja uma falha na aplicação.

Dessa forma, a aplicação ficará reiniciando a cada falha no Liveness.
```bash
kubectl get pod liveness-http
```

---
