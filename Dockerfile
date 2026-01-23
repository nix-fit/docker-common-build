FROM moby/buildkit:v0.27.0-rootless AS buildkit
FROM ghcr.io/hadolint/hadolint:v2.14.0 AS hadolint
FROM --platform=${BUILDPLATFORM} nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715 AS tools

# Install tools on native platform https://github.com/tonistiigi/binfmt/issues/285 https://github.com/moby/buildkit/issues/6475
WORKDIR /etc/tools

# hadolint ignore=DL3002
USER root

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install openssl \
                                                git \
                                                tar \
                                                gzip \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

ARG TARGETOS
ARG TARGETARCH

# Install helm
ARG HELM_VERSION=3.19.0-${TARGETOS}-${TARGETARCH}
RUN curl -kLso helm-v${HELM_VERSION}.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}.tar.gz" \
    && tar -zxvf helm-v${HELM_VERSION}.tar.gz --no-same-owner --no-same-permissions \
    && mv ${TARGETOS}-${TARGETARCH}/helm helm \
    && rm -rf helm-v${HELM_VERSION}.tar.gz

# Install yq
ARG YQ_VERSION=4.47.2
RUN curl -kLso yq_${TARGETOS}_${TARGETARCH}.tar.gz "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${TARGETOS}_${TARGETARCH}.tar.gz" \
    && tar -zxvf yq_${TARGETOS}_${TARGETARCH}.tar.gz --no-same-owner --no-same-permissions \
    && mv yq_${TARGETOS}_${TARGETARCH} yq \
    && rm -rf yq_${TARGETOS}_${TARGETARCH}.tar.gz

FROM nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715

LABEL org.opencontainers.image.authors="wizardy.oni@gmail.com,nex1gen@yandex.ru"

# Install other tools
WORKDIR /etc/tools

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install openssl \
                                                git \
                                                tar \
                                                gzip \
                                                jq \
                                                skopeo \
                                                crun \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum \
    && jq --version \
    && skopeo --version \
    && groupadd -g 1000 jenkins \
    && useradd -u 1000 -g 1000 -m -d /home/jenkins/agent -s /bin/bash jenkins \
    && chown -R 1000:1000 /home/jenkins/agent

# Install buildkit
COPY --from=buildkit /usr/bin/buildctl /usr/local/bin/buildctl
COPY --from=buildkit /usr/bin/buildkitd /usr/local/bin/buildkitd
COPY --from=buildkit /usr/bin/buildkit-qemu-* /usr/local/bin/
COPY --from=buildkit /usr/bin/rootlesskit /usr/local/bin/rootlesskit
RUN buildctl --version \
    && buildkitd --version \
    && rootlesskit --version

# Install hadolint
COPY --from=hadolint /bin/hadolint /usr/local/bin/hadolint
RUN hadolint --version \
    && rm -rf /etc/tools

# Install helm, yq
COPY --from=tools /etc/tools/helm /usr/local/bin/helm
COPY --from=tools /etc/tools/yq /usr/local/bin/yq
RUN helm version \
    && yq --version

ENV HOME=/home/jenkins/agent \
    XDG_RUNTIME_DIR=/home/jenkins/agent/.local/xdg \
    BUILDKIT_HOST=unix:///home/jenkins/agent/buildkit/buildkitd.sock

USER jenkins
