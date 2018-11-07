#! /bin/bash

# Retrieve User AWS Credentials
sudo yum install jq -y
IAM_BASEURL=http://169.254.169.254/latest/meta-data/iam/security-credentials/
ROLE_NAME=$(curl ${IAM_BASEURL})
ROLE_DATA=$(curl ${IAM_BASEURL}/${ROLE_NAME})
read -r AWS_ACCESS_KEY AWS_SECRET_KEY <<<$(echo ${ROLE_DATA} | jq '[.AccessKeyId,.SecretAccessKey] | join(" ")' -r)

# Retrieve EFS File System ID
EFS_FILESYSTEM_ID=$(aws efs describe-file-systems --region ${AWS_REGION} --query "FileSystems[?Name==\`${SUBDOMAIN_PREFIX}\`].[FileSystemId]" --output text)

# Mount File System locally to create PV directory
sudo yum install -y nfs-utils
mkdir -p /home/ec2-user/efs
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_FILESYSTEM_ID}.efs.${AWS_REGION}.amazonaws.com:/ /home/ec2-user/efs
sudo mkdir -p /home/ec2-user/efs/data/persistentvolumes
sudo umount /home/ec2-user/efs

# Run ansible playbook for EFS provisioner setup
sudo bash -c "ansible-playbook -v -i /etc/ansible/hosts \
    /usr/share/ansible/openshift-ansible/playbooks/openshift-provisioners/config.yml \
-e openshift_provisioners_install_provisioners=True \
-e openshift_provisioners_efs=True \
-e openshift_provisioners_efs_fsid=${EFS_FILESYSTEM_ID} \
-e openshift_provisioners_efs_region=${AWS_REGION} \
-e openshift_provisioners_efs_path=/data/persistentvolumes \
-e openshift_provisioners_efs_aws_access_key_id=${AWS_ACCESS_KEY} \
-e openshift_provisioners_efs_aws_secret_access_key=${AWS_SECRET_KEY} > /var/log/integreatly_efs_configure.log"

# Create EFS Storageclass
aws s3 cp ${QS_S3URI}scripts/efs_storageclass.yml efs_storageclass.yml
sudo oc create -f efs_storageclass.yml

# Install Integreatly
MASTER_NODES=$(sudo oc get nodes | grep master | awk {'print $1'})
git clone --branch ${INTEGREATLY_RELEASE_VERSION} https://github.com/integr8ly/installation.git /tmp/integreatly
pushd /tmp/integreatly/evals
# Modify hosts file to set ssh user to root
perl -i -0pe "s/ec2-user/root/" inventories/hosts
# Modify hosts file to dynamically set master nodes
perl -i -0pe "s/\[master\]\n127.0.0.1\n/\[master\]\n$MASTER_NODES\n/" inventories/hosts
sudo bash -c "ansible-playbook -i inventories/hosts playbooks/install.yml > /var/log/integreatly_install.log"
popd

if [ "${OCP_VERSION}" == "3.10" ]; then
    CURRENT_OP_FRAMEWORK_VERSION=https://github.com/operator-framework/operator-lifecycle-manager/archive/0.6.0.tar.gz
    curl  --retry 5  -Ls ${CURRENT_OP_FRAMEWORK_VERSION} -o operator-framework.tar.gz
    tar -zxf operator-framework.tar.gz
    sudo rm -rf /usr/share/opframework
    sudo mkdir -p /usr/share/opframework
    sudo mv operator-lifecycle-manager-*/* /usr/share/opframework/
    sudo kubectl apply -f /usr/share/opframework/deploy/upstream/manifests/0.4.0
fi