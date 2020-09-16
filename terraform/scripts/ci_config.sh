#!/bin/bash

# NOTE: keep `region us-east-1 and  name QAREPORTS_EKSCluster` in sync with shared/variables.tf with respective values of "cluster_name" and "region"
EKS_CLUSTER_NAME=QAREPORTS_EKSCluster
EKS_CLUSTER_REGION=us-east-1


# Endpoint settings
EP_USER=ubuntu
EP_DNS=ci-qa-reports.ctt.linaro.org
EP_TOKEN=$(openssl rand -hex 16)
EP_SERVER=ci_endpoint_server
EP_SERVER_SCRIPT=/home/ubuntu/qa-reports.linaro.org/terraform/scripts/$EP_SERVER.py
EP_WWW_DIR=/var/www/$EP_SERVER
EP_ADMIN_EMAIL=charles.oliveira@linaro.org


# Add certbot's repository for generating https certificates
add-apt-repository -y ppa:certbot/certbot


# Get a few requirements
apt update -qy && apt install -qy unzip libffi-dev python3-pip openssl wget git python-certbot-apache apache2 && su - $EP_USER -c "pip3 install flask requests"


# Install awscli
awscli=/tmp/awscliv2.zip
wget -q "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -O "$awscli"
chown $EP_USER:$EP_USER $awscli
su - $EP_USER -c "unzip -q $awscli && sudo ./aws/install"


# Get kubeconfig
su - $EP_USER -c "aws eks update-kubeconfig --region $EKS_CLUSTER_REGION --name $EKS_CLUSTER_NAME"


# Get kubectl
kubectl_url="https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl"
kubectl_tmp=/tmp/kubectl
wget -q $kubectl_url -O $kubectl_tmp
chmod +x $kubectl_tmp && mv $kubectl_tmp /usr/local/bin/kubectl


# Get a copy of qareports deploy scripts
su - $EP_USER -c "git clone https://github.com/linaro/qa-reports.linaro.org"


# Make the endpoint a service
cat > /etc/systemd/system/$EP_SERVER.service <<EOF
[Unit]
Description=Endpoint server to upgrade testing and staging environments

[Service]
User=$EP_USER
Group=$EP_USER
Restart=always
RestartSec=5
ExecStart=$EP_SERVER_SCRIPT $EP_TOKEN

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start $EP_SERVER
systemctl enable $EP_SERVER


# Configure apache virtual host
mkdir -p $EP_WWW_DIR && chown -R $EP_USER:$EP_USER $EP_WWW_DIR && chmod -R 755 $EP_WWW_DIR

cat > /etc/apache2/sites-available/$EP_SERVER.conf <<EOF
<VirtualHost *:80>
    ServerName $EP_DNS
    DocumentRoot $EP_WWW_DIR
    RewriteEngine On
    RewriteCond %{HTTPS}  !=on
    RewriteRule ^/?(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
EOF

cat > /etc/apache2/sites-available/$EP_SERVER-le-ssl.conf <<EOF
<VirtualHost *:443>
    ServerName $EP_DNS
    ServerAlias $EP_DNS
    DocumentRoot $EP_WWW_DIR
    RewriteEngine On
    ProxyPreserveHost On
    ProxyPass "/" http://127.0.0.1:5000/
    <Directory $EP_WWW_DIR>
        Options -Indexes
    </Directory>
    SSLCertificateFile /etc/letsencrypt/live/$EP_DNS/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/$EP_DNS/privkey.pem
    Include /etc/letsencrypt/options-ssl-apache.conf
</VirtualHost>

EOF

a2enmod rewrite
a2enmod proxy
a2enmod proxy_http
a2enmod proxy_balancer
a2enmod lbmethod_byrequests
a2ensite $EP_SERVER.conf
a2dissite 000-default.conf
systemctl restart apache2

certbot --non-interactive --agree-tos -m $EP_ADMIN_EMAIL --apache -d $EP_DNS
