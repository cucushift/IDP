#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

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
