FROM nix-docker.registry.twcstorage.ru/base/redhat/ubi9-minimal:9.6@sha256:bb31756af74ea8e4ad046a80479e5aeea35fd01307a12d3ab9a5d92e8422b1f8

LABEL org.opencontainers.image.authors="wizardy.oni@gmail.com"

# Install prerequisites, jq
WORKDIR /etc/tools

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install openssl \
                                                git \
                                                tar \
                                                gzip \
                                                jq \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum \
    && jq --version \
    && groupadd -g 1000 jenkins \
    && useradd -u 1000 -g 1000 -m -d /home/jenkins/agent -s /bin/bash jenkins \
    && chown -R 1000:1000 /home/jenkins/agent

# Install buildkit
ARG BUILDKIT_VERSION=0.24.0
RUN curl -kLso buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz" \
    && tar -zxvf buildkit-v${BUILDKIT_VERSION}.linux-amd64.tar.gz \
    && install -o root -g root -m 0755 bin/buildctl /usr/local/bin/buildctl \
    && buildctl --version

# Install helm
ARG HELM_VERSION=3.19.0-linux-amd64
RUN curl -kLso helm-v${HELM_VERSION}.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}.tar.gz" \
    && tar -zxvf helm-v${HELM_VERSION}.tar.gz \
    && install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm \
    && helm version

# Install yq
ARG YQ_VERSION=4.47.2
RUN curl -kLso yq_linux_amd64.tar.gz "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz" \
    && tar -zxvf yq_linux_amd64.tar.gz \
    && install -o root -g root -m 0755 yq_linux_amd64 /usr/local/bin/yq \
    && yq --version

# Install hadolint
ARG HADOLINT_VERSION=2.14.0
RUN curl -kLso hadolint-linux-x86_64 "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-linux-x86_64" \
    && install -o root -g root -m 0755 hadolint-linux-x86_64 /usr/local/bin/hadolint \
    && hadolint --version \
    && rm -rf /etc/tools

ENV HOME=/home/jenkins/agent

USER jenkins
