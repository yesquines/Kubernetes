# -*- mode: ruby -*-
# vi: set ft=ruby :

vms = {
  'master1' => {'memory' => '2048', 'cpus' => 2, 'ip' => '100'},
  'master2' => {'memory' => '2048', 'cpus' => 2, 'ip' => '110'},
  'master3' => {'memory' => '2048', 'cpus' => 2, 'ip' => '120'},
  'balancer-storage' => {'memory' => '512', 'cpus' => 1, 'ip' => '200'},
}

Vagrant.configure('2') do |config|

  config.vm.box = 'debian/buster64'
  config.vm.box_check_update = false
  
  vms.each do |name, conf|
    config.vm.define "#{name}" do |k|
      k.vm.hostname = "#{name}.k8s.com"
      k.vm.network 'private_network', ip: "172.27.2.#{conf['ip']}"
      k.vm.provider 'virtualbox' do |vb|
        vb.memory = conf['memory']
        vb.cpus = conf['cpus']
      end

    if "#{name}" != "balancer-storage"
      k.vm.provision "shell", path: "scripts/master.sh"
    else
      k.vm.provision "shell", path: "scripts/balancer.sh"
    end

    end
  end
end
