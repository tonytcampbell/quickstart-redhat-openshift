#! /bin/bash

if [ "${OCP_VERSION}" == "3.10" ]; then
    CURRENT_OP_FRAMEWORK_VERSION=https://github.com/operator-framework/operator-lifecycle-manager/archive/0.6.0.tar.gz
    curl  --retry 5  -Ls ${CURRENT_OP_FRAMEWORK_VERSION} -o operator-framework.tar.gz
    tar -zxf operator-framework.tar.gz
    sudo rm -rf /usr/share/opframework
    sudo mkdir -p /usr/share/opframework
    sudo mv operator-lifecycle-manager-*/* /usr/share/opframework/
    sudo kubectl apply -f /usr/share/opframework/deploy/upstream/manifests/0.4.0
fi