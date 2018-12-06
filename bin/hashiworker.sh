#!/bin/bash
set -e

apt-get -y update
apt-get -y install unzip

# Get variables
IP_ADDRESS=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)

# Install Java
curl -sSL https://github.com/AdoptOpenJDK/openjdk8-binaries/releases/download/jdk8u192-b12/OpenJDK8U-jre_x64_linux_openj9_8u192b12.tar.gz | tar -xz -C /opt/
ln -s /opt/jdk8u192-b12-jre/bin/java /usr/local/bin/java

# Install Nomad
curl -sSL https://releases.hashicorp.com/nomad/0.8.6/nomad_0.8.6_linux_amd64.zip > nomad.zip
unzip nomad.zip
mv nomad /usr/local/bin

mkdir -p /var/lib/nomad /etc/nomad
rm -rf nomad.zip


cat >/etc/nomad/client.hcl <<EOL
addresses {
    rpc  = "${IP_ADDRESS}"
    http = "${IP_ADDRESS}"
}
advertise {
    http = "${IP_ADDRESS}:4646"
    rpc  = "${IP_ADDRESS}:4647"
}
data_dir  = "/var/lib/nomad"
log_level = "DEBUG"
client {
    enabled = true
    servers = [
      "142.93.203.142"
    ]
    options {
        "driver.raw_exec.enable" = "1"
    }
}
EOL

cat >/etc/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs/
[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl enable nomad
systemctl start nomad

# Install Consul
curl -sSL https://releases.hashicorp.com/consul/1.4.0/consul_1.4.0_linux_amd64.zip > consul.zip
unzip consul.zip
mv consul /usr/local/bin/
rm -f consul.zip

mkdir -p /var/lib/consul

cat >/etc/systemd/system/consul.service <<EOL
[Unit]
Description=consul
Documentation=https://consul.io/docs/
[Service]
ExecStart=/usr/local/bin/consul agent \
  -data-dir=/var/lib/consul

ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOL

systemctl enable consul
systemctl start consul