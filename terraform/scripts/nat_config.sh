#!/bin/sh

# Turns a machine into a NAT instance
# ref: https://www.theguild.nl/cost-saving-with-nat-instances/#the-ec2-instance
sysctl -w net.ipv4.ip_forward=1
/sbin/iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

#
# Prepare this machine to make changes to eks cluster thru ci.linaro.org
#

# Get awscli
apt update -y && apt install -y python3-pip git wget && su - ubuntu -c "pip3 install awscli"

# Get kubectl
kubectl_url="https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl"
kubectl_tmp=/tmp/kubectl
wget $kubectl_url -O $kubectl_tmp
chmod +x $kubectl_tmp && mv $kubectl_tmp /usr/local/bin/kubectl


# Clone this repo
su - ubuntu -c "git clone https://github.com/Linaro/qa-reports.linaro.org.git"

# Add ci.linaro.org's ssh key to the server
echo >> /home/ubuntu/.ssh/authorized_keys "\nssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCF4mb8LxHFT8MZFr1dnjzGx5LAfsuL9nqo7jSLVoVZUJSPf9eBDNE8TQOqtFl+Nf/b6NewX/MrUNraJnz/Qf0XRjX44gQXkeJ/Ggk/nXvDhRcmSHD+0g1e1SFA6RXqFAyot5vrKclakq+ibTzqRSnvfi4PLKvWICWThILBjBWosP5rM5grVMZWtn7ZYRYslgXO2tR7NnR6RUDnGUb5XDSl4JrH3VQRfk9LqBeILkWUayCSwFWKNOAaPy5qq+RIFRn/JV2jjgJZIhtm0a/8qILuloKBD19aAAV5vIO0V4ihEX/iuBWxI4vBYtVoCctVqPTH5styr2lhFW/IXNVIm55P"
