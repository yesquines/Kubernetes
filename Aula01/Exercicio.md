Exercicio
---------

1. Criar deploy do **REDIS** via YAML
   - Com um configMap do **redis.conf** com o seguinte conteúdo:
    ```txt
    requirepass 4linux
    bind 0.0.0.0
    save 10 1
    ```
   - Nome do Container: **redis**
   - Imagem do Container: **redis:alpine**
   - Command do Container: **redis-server /usr/local/etc/redis/redis.conf**
   - Porta no Container: **6379**
2. Criar um Service com ClusterIP para o Redis
   - Nome: **redis**
   - Porta Alvo: **6379**
3. Criar Deploy da Aplicação em PERL
   - Imagem do container: **hectorvido/dancer**
   - Com os seguintes Environments:
     - **REDIS_SERVER='redis'**
     - **REDIS_PORT='6379'**
     - **REDIS_PASSWORD='4linux'**
   - Porta no Container: **5000**
4. Criar um Service com NodePort para o PERL
   - O Service tem que direcionar o trafego para o Deploy da **aplicação em Perl**.
   - Nome: **perl**
   - Porta Alvo: **5000**
   - nodePort: **> 30000**
5. Criar um Ingress para o Dominio
   - **perl.192-168-99-100.nip.io**
