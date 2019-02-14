#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

echo -e "\033[44;37mPlease execute this script on the machine which contains kubeconfig file!\033[0m"
echo -n "please enter the kubeconfig absolute path ->"
read KC

datename=$(date +%Y%m%d-%H%M%S)

step(){
echo -e "\033[47;30m$1\033[0m"
}

checkreturn(){
if [ $? -ne 0 ]; then
echo -e "`date +%H:%M:%S` \033[31mThe step failed and you need to get the cluster status back manually e.g switch back to previous user!!! \033[0m"
exit 1
fi
}

if [ ! -f ${KC} ];then
echo -e "`date +%H:%M:%S` \033[31mThe kubeconfig file doesn't exit \033[0m"
exit 1
fi

step "Step 1: check whether oc client exits"
which "oc" > /dev/null
if [ $? -eq 0 ]
then
echo -e "`date +%H:%M:%S` \033[32m oc command is exist \033[0m"
else
echo -e "`date +%H:%M:%S` \033[31m oc command not exist,you should install the oc client on master \033[0m"
exit 1
fi

step "Step 2: switch to cluster-admin user"
CC=`oc config current-context --config="${KC}"`
oc login -u system:admin --config="${KC}" > /dev/null
checkreturn


step "Step 3: config 4.0 oauthconfig"

cluster_url="$(oc whoami --show-server | cut -f 2 -d ':' | cut -f 3 -d '/' | sed 's/-api././')"
hostname="o.apps.${cluster_url}"


if [ "${#hostname}" -ge 63 ]; then
  echo "cluster url ${cluster_url} is too long to use with lets encrypt"
  exit 1
fi


oc apply -fhttps://raw.githubusercontent.com/tnozicka/openshift-acme/master/deploy/letsencrypt-live/single-namespace/{role,serviceaccount,imagestream,deployment}.yaml -n openshift-authentication
oc create rolebinding openshift-acme --role=openshift-acme --serviceaccount=openshift-authentication:openshift-acme -n openshift-authentication --dry-run -o yaml | oc auth reconcile -f -


oc apply -f - <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    kubernetes.io/tls-acme: "true"
  name: openshift-authentication
  namespace: openshift-authentication
spec:
  host: ${hostname}
  port:
    targetPort: 6443
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: reencrypt
  to:
    kind: Service
    name: openshift-authentication
    weight: 100
  wildcardPolicy: None
EOF


oc patch authentication.operator cluster --type=merge -p "{\"spec\":{\"managementState\": \"Managed\"}}"


until
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3 &&
oc get --raw '/.well-known/oauth-authorization-server' | grep "${hostname}" && sleep 3
do
  echo "waiting for well-known"
  sleep 60
done


oc delete pods -n openshift-console --all --force --grace-period=0
oc delete pods -n openshift-monitoring --all --force --grace-period=0


oc apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: htpass-secret
  namespace: openshift-config
data:
  htpasswd: cG0xOiRhcHIxJEJ6N2guRDNsJDBJdWVKWmVKeC9iMzVVSDZMUGo1Vy4KcG0yOiRhcHIxJGtyZklKWVBiJE5sUjFoNUJhbFVUak1KOVc4RUlwYS4KcG0zOiRhcHIxJEVSWDAwbjhuJFdGNDZKMzgxTWNtaE5MZ0FLc2p6NTAKcG00OiRhcHIxJEdpWnBHc0xlJGVYdVJhb09jSWs4c20zNGhGSXBlYjAKcG01OiRhcHIxJFQzTDNSVGc3JFFWbHdKdkJXNVlCOFZrVXlpMFFidS4KcG02OiRhcHIxJFlSVkNjbnBGJEtzTWdxTkt2QmlBT3VleDNkOTE4LzAK
EOF


oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: htpassidp
    challenge: true
    login: true
    mappingMethod: claim
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret
EOF

sleep 30


step "Step 4: switch back to previous user"
oc config use-context ${CC} --config="${KC}"
checkreturn

echo -e "\033[32mAll Success\033[0m"
echo we have 6 users: pm{1,2,3,4,5,6}/redhat
