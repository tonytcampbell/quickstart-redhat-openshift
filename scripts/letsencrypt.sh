#! /bin/bash

pip install virtualenv
virtualenv TLSVENV


source TLSVENV/bin/activate
pip install certbot
pip install --upgrade pip
pip install certbot-dns-route53

certbot certonly -d ${SUBDOMAIN_PREFIX}.opentry.me -d \*.${SUBDOMAIN_PREFIX}.opentry.me --dns-route53 --logs-dir /home/ec2-user/letsencrypt/log/ --config-dir /home/ec2-user/letsencrypt/config/ --work-dir /home/ec2-user/letsencrypt/work/ -m tonyc@redhat.com --agree-tos --non-interactive --server https://acme-v02.api.letsencrypt.org/directory
mkdir -p /home/ec2-user/certs/
cp /home/ec2-user/letsencrypt/config/live/${SUBDOMAIN_PREFIX}.opentry.me/{cert.pem,chain.pem,privkey.pem} /home/ec2-user/certs/

deactivate