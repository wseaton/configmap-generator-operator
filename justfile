install-crd:
    oc apply -f manifests/configmapgenerator.crd.yaml

generate-olm-bundle: 
    opm alpha bundle generate --directory ${HOME}/git/configmap-controller-operator/ --package configmap-controller --channels alpha --default alpha  --output-dir my-output-manifest-dir

build-bundle-docker:
    podman build -t configmap-operator-manifest-bundle -f bundle.Dockerfile
    podman tag configmap-operator-manifest-bundle:latest quay.io/wseaton/configmap-operator-manifest-bundle:latest
    podman push quay.io/wseaton/configmap-operator-manifest-bundle:latest 

validate-bundle:
    opm alpha bundle validate --tag quay.io/wseaton/configmap-operator-manifest-bundle:latest --image-builder podman

install-operator:
    operator-sdk run bundle quay.io/wseaton/configmap-operator-manifest-bundle:latest


uninstall-operator:
    oc delete catalogsource configmap-controller-catalog -n default || true
    oc delete clusterserviceversion configmap-controller.v0.1.0 -n default || true
    oc delete subscriptions.operators.coreos.com configmap-controller-v0-1-0-sub -n default || true