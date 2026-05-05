# Teste do pacote `monitor` com Docker (OpenWrt rootfs no PC)

Isto **não** é o mesmo que “OpenWrt a correr Docker no router”. Aqui o **PC** corre um contentor com **rootfs OpenWrt** para validar instalação, sintaxe e fluxos básicos dos scripts.

## Gerar `.ipk` no Docker (SDK real, não `openwrt/rootfs`)

A imagem **`ghcr.io/openwrt/rootfs:x86_64-main`** não serve para compilar pacotes para o teu router (ARM / filogic): não traz o **SDK** nem o toolchain certo.

Usa o fluxo **Ubuntu + SDK oficial** (`docker/Dockerfile.sdk`), por defeito **OpenWrt 24.10.5** + **mediatek/filogic** (ex.: Cudy WR3000 v1):

```sh
cd /caminho/para/bot-monitor-openwrt
make -f Makefile.ipk ipk
```

(equivalente a `mkdir -p ipk-out`, `docker compose ... build`, `docker compose ... run monitor-ipk`.)

O ficheiro fica em **`ipk-out/monitor.ipk`** (na raiz do repo). Copia para o router e `opkg install /tmp/monitor.ipk`.

No router, instala também **`curl`** e **`jsonfilter`** se ainda não existirem: `opkg install curl jsonfilter` (o `.ipk` do `monitor` não declara dependências no control file, para o build no Docker não compilar metade do sistema).

Para **outro target**, altera `SDK_URL` em `docker/docker-compose.ipk.yml` (ou `docker build --build-arg SDK_URL=... -f docker/Dockerfile.sdk .` com contexto na raiz do repo). O URL do `.tar.zst` está na pasta do target em [downloads.openwrt.org/releases](https://downloads.openwrt.org/releases/).

### `feeds update` / TLS / `feeds/base` em falta

Se vires `GnuTLS recv error` ou `feeds/base: No such file`, o `Dockerfile.sdk` já **redireciona os feeds para GitHub** e faz **até 5 tentativas**. Volta a correr `docker compose ... build` (rede estável ajuda). Em último caso, compila noutra rede ou numa máquina Linux fora do Docker.

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

- Ficheiros do pacote em `/etc/monitor/`, `/usr/bin/monitor-network`, `/usr/bin/monitor-bot`, `/usr/lib/monitor/` (inclui `checks.sh`).
- Validação rápida de sintaxe:
  ```sh
  sh -n /usr/bin/monitor-network && sh -n /usr/lib/monitor/checks.sh && sh -n /usr/bin/monitor-bot && echo OK
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
| `ubus`, UCI, interfaces `wan`/`wan2` | Podem não existir ou não refletir um router; `monitor-network` pode falhar ou alertar em partes que dependem de rede real. |
| `iw`, WiFi, VLANs `br-lan.*` | Normalmente **não** há rádio; checks WiFi/NAC são no máximo “não rebentam o shell”. |
| `logread`, firewall `MONITOR_DROP` | Ambiente mínimo; contagens podem ser zero. |
| Init `procd` completo | Não é igual ao boot no hardware; `/etc/init.d/monitor start` pode não ser representativo. |

Ou seja: Docker serve para **fumo** (instalação, sintaxe, dependências, Telegram com rede), não para substituir teste no **roteador** ou em **VM/QEMU** com OpenWrt completo.

## Script de cópia (espelho do Makefile)

`docker/install-from-files.sh` replica o que o `Makefile` instala. Podes usá-lo noutro root (chroot, outra imagem) com o mesmo critério.
