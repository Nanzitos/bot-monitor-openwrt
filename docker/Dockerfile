# Rootfs OpenWrt (x86_64) para testar scripts e layout do pacote no PC.
# Override: docker build --build-arg OPENWRT_IMAGE=... -f docker/Dockerfile .

ARG OPENWRT_IMAGE=ghcr.io/openwrt/rootfs:x86_64-main
FROM ${OPENWRT_IMAGE}

# Dependências do pacote (curl + jsonfilter). Requer rede no build; falha se faltar.
RUN apk update && \
    apk add curl jsonfilter ca-certificates && \
    command -v curl >/dev/null && \
    command -v jsonfilter >/dev/null

COPY files/ /tmp/monitor-pkg/files/
COPY docker/install-from-files.sh /tmp/monitor-pkg/install-from-files.sh

RUN chmod +x /tmp/monitor-pkg/install-from-files.sh && \
    /tmp/monitor-pkg/install-from-files.sh /tmp/monitor-pkg/files / && \
    rm -rf /tmp/monitor-pkg

WORKDIR /root

# Shell interativo para testes manuais
CMD ["/bin/sh"]
