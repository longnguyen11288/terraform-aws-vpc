#!/bin/bash

AWS_KEY_ID=$1
AWS_ACCESS_KEY=$2
REGION=$3
VPC=$4
BOSH_SUBNET=$5
IPMASK=$6
CP_IP=$7
CF_SUBNET=$8

cd $HOME
sudo apt-get update
sudo apt-get install -y git vim-nox build-essential libxml2-dev libxslt-dev libmysqlclient-dev libpq-dev libsqlite3-dev git
curl -sSL https://get.rvm.io | bash -s stable
source /home/ubuntu/.rvm/scripts/rvm
rvm install ruby-2.1.3
rvm alias create default ruby-2.1.3

cat <<EOF > ~/.gemrc
gem: --no-document
EOF

cat <<EOF > ~/.fog
:default:
    :aws_access_key_id: $AWS_KEY_ID
    :aws_secret_access_key: $AWS_ACCESS_KEY
    :region: $REGION
EOF
gem install bundler
mkdir -p {bin,workspace/deployments,workspace/tools}
pushd workspace/deployments

mkdir bosh-bootstrap
pushd bosh-bootstrap
gem install bosh-bootstrap bosh_cli
cat <<EOF > settings.yml
---
provider:
  name: aws
  credentials:
    provider: AWS
    aws_access_key_id: $AWS_KEY_ID
    aws_secret_access_key: $AWS_ACCESS_KEY
  region: $REGION
address:
  vpc_id: $VPC
  subnet_id: $BOSH_SUBNET
  ip: ${IPMASK}.2.4
EOF

bosh-bootstrap deploy

bosh -n target https://10.50.2.4:25555
bosh login admin admin
popd

git clone http://github.com/cloudfoundry-community/cf-boshworkspace
pushd cf-boshworkspace
bundle install --path vendor/bundle
mkdir -p ssh
export CF_ELASTIC_IP=$CF_IP
export SUBNET_ID=$CF_SUBNET
export DIRECTOR_UUID=$(bundle exec bosh status | grep UUID | awk '{print $2}')
for VAR in CF_ELASTIC_IP SUBNET_ID DIRECTOR_UUID
do
  eval REP=\$$VAR
  perl -pi -e "s/$VAR/$REP/g" deployments/cf-aws-vpc.yml
done
bundle exec bosh upload release https://community-shared-boshreleases.s3.amazonaws.com/boshrelease-cf-189.tgz
bundle exec bosh deployment cf-aws-vpc
bundle exec bosh prepare deployment
popd


# Needed for microbosh/firstbosh/micro_bosh.yml:
# Elastic IP
# IP on Microbosh Subnet
# IP of DNS Server
# SUBNET ID of Microbosh Subnet
# Availability Zone
# Access Key ID
# Secret Access Key
# Default key name (can standardize on 'bosh')
# Default security group (can standardize on 'bosh')
# Region