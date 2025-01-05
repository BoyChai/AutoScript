#!/bin/bash
# 判断比较简单，只提供参考，不建议直接用，请根据实际情况修改
hostname="compute3"
eth_name="ens33"
ip=`ip -4 addr show $eth_name | grep inet | awk '{ print $2 }' | cut -d'/' -f1`

set_chrony() {
    if ! rpm -q chrony > /dev/null 2>&1; then
        echo "[INSTALL]安装chrony中..."
        yum -y install chrony > /dev/null 2>&1
        if ! rpm -q chrony > /dev/null 2>&1; then
            echo "[ERROR]: Chrony安装失败"
            exit 1
        else
            echo "[INSTALL] Chrony 安装成功"
        fi
    else
        echo "[INSTALL] Chrony 已经安装"
    fi    
    cp /etc/chrony.conf{,.bak}
    cat << EOF > /etc/chrony.conf
server controller iburst                                                           
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF
    systemctl enable chronyd
    systemctl restart chronyd
}

install_base_package(){
    yum install -y centos-release-openstack-stein > /dev/null 2>&1
    cd /etc/yum.repos.d
    sed -i 's/mirrorlist=/#mirrorlist=/g' *.repo
    sed -i 's/#baseurl=/baseurl=/g' *.repo
    sed -i 's/mirror.centos.org/mirrors.aliyun.com/g' *.repo
    yum install python-openstackclient -y  > /dev/null 2>&1
}

install_nova() {
yum install -y openstack-nova-compute > /dev/null 2>&1
cp /etc/nova/nova.conf{,.bak}
egrep -v "^$|^#" /etc/nova/nova.conf.bak > /etc/nova/nova.conf
cat << EOF > /etc/nova/nova.conf
[DEFAULT]
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver
my_ip = $ip
enabled_apis = osapi_compute,metadata
transport_url = rabbit://openstack:RABBIT_PASS@controller
[api]
auth_strategy = keystone
[api_database]
[barbican]
[cache]
[cells]
[cinder]
[compute]
[conductor]
[console]
[consoleauth]
[cors]
[database]
[devices]
[ephemeral_storage_encryption]
[filter_scheduler]
[glance]
api_servers = http://controller:9292
[guestfs]
[healthcheck]
[hyperv]
[ironic]
[key_manager]
[keystone]
[keystone_authtoken]
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = NOVA_PASS
[libvirt]
hw_machine_type=x86_64=pc-i440fx-rhel7.2.0
[metrics]
[mks]
[neutron]
url = http://controller:9696
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = NEUTRON_PASS
[notifications]
[osapi_v21]
[oslo_concurrency]
lock_path = /var/lib/nova/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[pci]
[placement]
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = PLACEMENT_PASS
[placement_database]
[powervm]
[privsep]
[profiler]
[quota]
[rdp]
[remote_debug]
[scheduler]
[serial_console]
[service_user]
[spice]
[upgrade_levels]
[vault]
[vendordata_dynamic_auth]
[vmware]
[vnc]
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = \$my_ip
novncproxy_base_url = http://controller:6080/vnc_auto.html
[workarounds]
[wsgi]
[xenserver]
[xvp]
[zvm]
EOF
systemctl enable --now libvirtd.service openstack-nova-compute.service
}

install_neutron() {
    yum install -y openstack-neutron-linuxbridge ebtables ipset > /dev/null 2>&1
    cp /etc/neutron/neutron.conf{,.bak}
    cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini{,.bak}
    egrep -v "^$|^#" /etc/neutron/neutron.conf.bak > /etc/neutron/neutron.conf
    egrep -v "^$|^#" /etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
    cat << EOF > /etc/neutron/neutron.conf
[DEFAULT]
transport_url = rabbit://openstack:RABBIT_PASS@controller                          
auth_strategy = keystone
[cors]
[database]
[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = NEUTRON_PASS
[oslo_concurrency]
lock_path = /var/lib/neutron/tmp
[oslo_messaging_amqp]
[oslo_messaging_kafka]
[oslo_messaging_notifications]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[privsep]
[ssl]
EOF
    cat << EOF > /etc/neutron/plugins/ml2/linuxbridge_agent.ini
[DEFAULT]
[linux_bridge]                                                                
physical_interface_mappings = provider:ens33                
[vxlan]                                                                       
enable_vxlan = false                                                          
[securitygroup]                                                               
enable_security_group = true                                                  
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
EOF
    echo "br_netfilter" >> /etc/modules-load.d/bridge.conf
    modprobe br_netfilter
    echo "net.bridge.bridge-nf-call-iptables = 1 " > /etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-ip6tables = 1" > /etc/sysctl.conf
    sysctl -p
    systemctl enable --now neutron-linuxbridge-agent.service
}
# 检查
if [ -z "$eth_name" ] || [ -z "$ip" ]; then
    echo "ip获取失败，请检查网卡名字和ip"
    exit 1
fi

set_chrony
install_base_package
install_nova
install_neutron

echo "安装成功"