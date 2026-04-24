# Teste do pacote `monitor` com Docker (OpenWrt rootfs no PC)

Isto **não** é o mesmo que “OpenWrt a correr Docker no router”. Aqui o **PC** corre um contentor com **rootfs OpenWrt** para validar instalação, sintaxe e fluxos básicos dos scripts.

## Requisitos

- Docker (e, no Mac com Apple Silicon, emulação `linux/amd64` — já está no `docker-compose.yml`).
- Rede no **build** (para `opkg update` / instalar `curl` e `jsonfilter`).

## Build

Na **raiz do repositório**:

```sh
docker compose -f docker/docker-compose.yml build
```

Se a imagem predefinida (`ghcr.io/openwrt/rootfs:x86_64-main`) falhar, experimenta outra tag/arquitetura e passa no build:

```sh
docker compose -f docker/docker-compose.yml build --build-arg OPENWRT_IMAGE=openwrt/rootfs:x86_64-generic-main
```

(Ajusta o nome da tag conforme [openwrt/rootfs](https://hub.docker.com/r/openwrt/rootfs/tags) ou [ghcr.io/openwrt/rootfs](https://github.com/openwrt/docker/pkgs/container/rootfs).)

## Shell interativo

```sh
docker compose -f docker/docker-compose.yml run --rm openwrt-monitor-test
```

Dentro do contentor:

- Ficheiros do pacote em `/etc/monitor/`, `/usr/bin/network-monitor`, `/usr/bin/monitor-bot`, `/usr/lib/monitor/`.
- Validação rápida de sintaxe:
  ```sh
  sh -n /usr/bin/network-monitor && sh -n /usr/bin/monitor-bot && echo OK
  ```
- Para testar o **bot** de verdade, edita `/etc/monitor/config.env` (token, chat id, user id, `SECRET`) e corre `/usr/bin/monitor-bot` (precisa de **saída HTTPS** para `api.telegram.org`).

## `curl: not found` dentro do contentor

O bot e o Telegram usam **`curl`**. Na imagem OpenWrt instala-se com:

```sh
opkg update && opkg install curl jsonfilter ca-bundle
```

Se reconstruíste a imagem **sem** rede no `docker build`, o passo do `Dockerfile` que corre `opkg` pode ter falhado antes — volta a fazer `docker compose ... build` **com rede**. O `Dockerfile` atual exige que `curl` e `jsonfilter` existam após o `opkg` (o build falha em caso contrário).

**Nota:** em sistemas **Alpine** usa-se `apk add curl`, não `opkg`. Este projeto assume rootfs **OpenWrt**.

## Limitações (importante)

| No contentor | Realidade |
|--------------|-----------|
| `ubus`, UCI, interfaces `wan`/`wan2` | Podem não existir ou não refletir um router; `network-monitor` pode falhar ou alertar em partes que dependem de rede real. |
| `iw`, WiFi, VLANs `br-lan.*` | Normalmente **não** há rádio; checks WiFi/NAC são no máximo “não rebentam o shell”. |
| `logread`, firewall `MONITOR_DROP` | Ambiente mínimo; contagens podem ser zero. |
| Init `procd` completo | Não é igual ao boot no hardware; `/etc/init.d/monitor start` pode não ser representativo. |

Ou seja: Docker serve para **fumo** (instalação, sintaxe, dependências, Telegram com rede), não para substituir teste no **roteador** ou em **VM/QEMU** com OpenWrt completo.

## Script de cópia (espelho do Makefile)

`docker/install-from-files.sh` replica o que o `Makefile` instala. Podes usá-lo noutro root (chroot, outra imagem) com o mesmo critério.
