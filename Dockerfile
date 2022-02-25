FROM quay.io/instrumentisto/rust:1.58.1 as builder
WORKDIR /usr/src/app
COPY ./  /usr/src/app

RUN cargo install --path .

FROM quay.io/fedora/fedora:35

RUN dnf update -y && dnf clean all

COPY --from=builder /usr/local/cargo/bin/configmap-controller /usr/local/bin/configmap-controller
ENTRYPOINT ["/usr/local/bin/configmap-controller"]
