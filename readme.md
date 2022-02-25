# ConfigMap Generator Operator

## ⚠️ WARNING ⚠️

This is a sample project for documenting what it takes to publish an Operator written in Rust via OLM (Operator Lifecycle Manager)! The operator implementation is a toy example, and not something you'd want on your cluster in production 🙂

## Tools Required

* `rustup` and `cargo` to do local rust development (of course!)
* `podman` or `docker` to build container images
* `opm` used to generate the operator bundle image, [download here](https://github.com/operator-framework/operator-registry/releases)
* `operator-sdk` as a development aid for quick testing, [install instructions](https://sdk.operatorframework.io/docs/installation/)

## Building the Operator itself

For the packaging of Rust code in containers you have a lot of options. The simplest (and most oft recommended) mechanism is to use a multi-stage build, with the rust builder image compiling the binary in `release` mode, and then copying that into a minimal linux container image of your choice. This has the advantage of very small container sizes, without bundling the build tools and/or dev dependencies into the final product.

For compatibility purposes I am using `fedora:35` as the final base image, as it ships with new versions of libraries that play nicer w/ nightly rust. In production you'd likely switch to something very minimal like alpine, rhel's ubi-micro, or something custom.

## ClusterServiceVersion

To give OLM instructions on how to install the operator, alongside describing some of its requirements and capabilities, we need to make a `ClusterServiceVersion` manifest.

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: ClusterServiceVersion
metadata:
  annotations:
  name: configmap-controller.v0.1.0
spec:
  description: This is an operator for generating configmaps.
  displayName: ConfigMap Controller
  keywords:
  - configmap
  - app
  maintainers:
  - email: me@wseaton.com
    name: Cool Guy Inc.
  maturity: alpha
  provider:
    name: my fancy team
    url: www.mycompany.com
  version: 0.1.0
  minKubeVersion: 1.20.0
```

This starts with basic information on what the operator is, version info, maintainer contacts, and the minimum version of Kubernetes that the operator supports.

```yaml
 install:
    # strategy indicates what type of deployment artifacts are used
    strategy: deployment
    # spec for the deployment strategy is a list of deployment specs and required permissions - similar to a pod template used in a deployment
    spec:
      permissions:
      - serviceAccountName: configmap-operator
        rules:
        - apiGroups:
          - ""
          resources:
          - configmaps
          verbs:
          - '*'
          # the rest of the rules
      # permissions required at the cluster scope
      clusterPermissions:
      - serviceAccountName: configmap-operator
        rules:
        - apiGroups:
          - ""
          resources:
          - serviceaccounts
          verbs:
          - '*'
        - apiGroups:
          - ""
          resources:
          - configmaps
          verbs:
          - '*'
        - apiGroups:
          - "nullable.se"
          resources:
          - configmapgenerators
          verbs:
          - '*'
          # the rest of the rules
```

Next we define the install strategy (in this case we are using a deployment), alongside the permissions that our operator service account needs at runtime.

```yaml
      deployments:
      - name: configmap-operator
        spec:
          replicas: 1
          selector:
            matchLabels:
                app.kubernetes.io/name: configmap-operator
          template:
            metadata:
              labels:
                app.kubernetes.io/name: configmap-operator
            spec: 
              serviceAccountName: configmap-operator
              containers:
              - name: operator-pod
                image: quay.io/wseaton/configmap-operator:v0.1.0
                imagePullPolicy: IfNotPresent
```

This section is all about laying how the resulting operator `Deployment` will look, with details around the controller pod itself. In this case we are going with a very simple single replica, one container image deployment.

The last sections have some extra optional metadata about dependent objects, which are useful for some of the dependency resolution features built into OLM. If your operator depends on a CRD provided by another operator, OLM will make an effort to install it via the `InstallPlan` that gets generated.

There is also a section on install modes, which on OpenShift gets translated into UI tooltips at install-time.

```yaml
  installModes:
  - supported: true
    type: OwnNamespace
  - supported: false
    type: SingleNamespace
  - supported: false
    type: MultiNamespace
  - supported: true
    type: AllNamespaces
  customresourcedefinitions:
    owned:
    # a list of CRDs that this operator owns
    # name is the metadata.name of the CRD (which is of the form <plural>.<group>)
    - name: configmapgenerators.nullable.se
      # version is the spec.versions[].name value defined in the CRD
      version: v1
      # kind is the CamelCased singular value defined in spec.names.kind of the CRD.
      kind: ConfigMapGenerator
      # human-friendly display name of the CRD for rendering in graphical consoles (optional)
      displayName: ConfigMap Generator
      # a short description of the CRDs purpose for rendering in graphical consoles (optional)
      description: Generates a config map based on some data. 
  nativeAPIs:
  - group: ""
    version: v1
    kind: ConfigMap
```

## Bundle

Once we have our CSV made, we can use the `opm alpha bundle generate` command to generate the rest of the files needed to make an [operator bundle](https://olm.operatorframework.io/docs/tasks/creating-operator-bundle/#contents-of-annotationsyaml-and-the-dockerfile). The operator bundle image is linked in `Catalogs`, with the eventual goal of making the operator installable by end users w/ other clusters. Since we are just trying to validate that our operator works and is packaged properly, we will skip the specifics of `Catalogs` for now.

## Dev Cluster Testing

The `operator-sdk` makes testing your operator on a dev cluster very easy once the bundle image has been built. While it's primarily meant to be used w/ golang based operators, the `operator-sdk run bundle` command actually doesn't care about the underlying operator implementation. If the metadata is correctly specified in your bundle it will generate the valid Subscription and CatalogSource source objects to install the operator into the currently active cluster in your `~/.kube/config`. This enables rapid testing without requiring publishing the operator to a real external catalog.

## Justfile

To wrap all of the above steps into an easy to follow guide, I've provided a `justfile` with some commands as a quickstart.

```sh
❯ just -l   
Available recipes:
    build-bundle-docker
    generate-olm-bundle
    install-crd
    install-operator
    uninstall-operator
    validate-bundle
```

A few variables will need to be replaced, like the registry you plan to push the image to, but it should serve as a decent starting template.
