#!/usr/bin/env bash

set -e

# Turn colors in this script off by setting the NO_COLOR variable in your
# environment to any value:

NO_COLOR=${NO_COLOR:-""}
if [ -z "$NO_COLOR" ]; then
  header=$'\e[1;33m'
  reset=$'\e[0m'
else
  header=''
  reset=''
fi


while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -u|--user)
    user="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--password)
    password="$2"
    shift # past argument
    shift # past value
    ;;
    -url|--url)
    tempUrl="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--namespace)
    namespace="$2"
    shift # past argument
    shift # past value
    ;;
esac
done

function header_text {
  echo "$header$*$reset"
}

header_text "Starting Knative test-drive on OpenShift!"

echo "User as $user"
echo "URL as $tempUrl"
echo "namespace as $namespace"
echo "Password as $password"



header_text "Logging in as $user"
# oc login -u system:admin  #Local cluster login 
echo "Running Command oc login --insecure-skip-tls-verify=true $tempUrl -u $user -p $password"
oc login --insecure-skip-tls-verify=true $tempUrl -u $user -p $password
header_text "Setting up $namespace namespace"
oc project $namespace
oc adm policy add-scc-to-user privileged -z default -n $namespace
oc label namespace $namespace istio-injection=enabled --overwrite

header_text "Setting up security policy for istio"
oc adm policy add-scc-to-user anyuid -z istio-ingress-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z default -n istio-system
oc adm policy add-scc-to-user anyuid -z prometheus -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-egressgateway-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-citadel-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-ingressgateway-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-cleanup-old-ca-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-mixer-post-install-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-mixer-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-pilot-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-sidecar-injector-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istio-galley-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z cluster-local-gateway-service-account -n istio-system
oc adm policy add-cluster-role-to-user cluster-admin -z istio-galley-service-account -n istio-system



header_text "Installing istio"



# https://istio.io/docs/setup/kubernetes/install/kubernetes/
# https://istio.io/docs/setup/kubernetes/download/
# https://github.com/istio/istio/tree/master/install/kubernetes/helm/istio-init/files


###### Commented ######
# curl -L https://raw.githubusercontent.com/banzaicloud/istio-operator/release-1.1/config/crds/istio_v1beta1_remoteistio.yaml \
#   | sed 's/LoadBalancer/NodePort/' \
#   | oc apply --filename - 


# curl -L https://raw.githubusercontent.com/banzaicloud/istio-operator/release-1.1/config/crds/istio_v1beta1_istio.yaml \
#   | sed 's/LoadBalancer/NodePort/' \
#   | oc apply --filename - 



##### Commented ######
curl -L https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/helm/istio-init/files/crd-10.yaml \
	| oc apply --filename - 

curl -L https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/helm/istio-init/files/crd-11.yaml \
	| oc apply --filename - 

curl -L https://raw.githubusercontent.com/istio/istio/master/install/kubernetes/helm/istio-init/files/crd-12.yaml \
	| oc apply --filename -   
##### Commented-- ######

curl -L https://github.com/knative/serving/releases/download/v0.5.2/istio.yaml  \
  | oc apply --filename -



header_text "Waiting for istio to become ready"
sleep 5; while echo && oc get pods -n istio-system | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done

#######################----##########################


oc get cm istio-sidecar-injector -n istio-system -oyaml  \
| sed -e 's/securityContext:/securityContext:\\n      privileged: true/' \
| oc replace -f -




# if getenforce | grep -q Disabled
# then
#     echo "SELinux is disabled, no need to restart the pod"
# else
#     echo "SELinux is enabled, restarting sidecar-injector pod"
#     oc delete pod -n istio-system -l istio=sidecar-injector
# fi

###########################---####################


header_text "Setting up security policy for knative"
oc adm policy add-scc-to-user anyuid -z build-controller -n knative-build
oc adm policy add-scc-to-user anyuid -z controller -n knative-serving
oc adm policy add-scc-to-user anyuid -z autoscaler -n knative-serving
oc adm policy add-scc-to-user anyuid -z kube-state-metrics -n knative-monitoring
oc adm policy add-scc-to-user anyuid -z node-exporter -n knative-monitoring
oc adm policy add-scc-to-user anyuid -z prometheus-system -n knative-monitoring
oc adm policy add-cluster-role-to-user cluster-admin -z build-controller -n knative-build
oc adm policy add-cluster-role-to-user cluster-admin -z controller -n knative-serving

header_text "Installing Knative"

########################################
curl -L https://github.com/knative/serving/releases/download/v0.6.0/serving.yaml  \
  | oc apply --filename -


########################################

header_text "Waiting for Knative to become ready"
sleep 5; while echo && oc get pods -n knative-serving | grep -v -E "(Running|Completed|STATUS)"; do sleep 5; done
 