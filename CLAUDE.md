# CLAUDE.md — Monitor (bot-monitor-openwrt)

## O que é este projeto

Pacote OpenWrt `.ipk` que corre num router e oferece:
- **Bot Telegram** (`monitor-bot`) — polling getUpdates, fluxo conversacional com estado em ficheiros
- **Checagens de rede** (`monitor-network`) — cron e/ou Telegram
- **NAC via MAC** (`mac_acl.sh`) — allowlist/blocklist via nftables na bridge
- **Build** via Docker + SDK OpenWrt oficial

**Este projeto é crítico — corre em produção num router.**

## Arquitetura: ficheiros-chave

| Ficheiro | Papel |
|---|---|
| `files/etc/monitor/config.env` | Tokens Telegram, caminhos, limiares |
| `files/etc/init.d/monitor` | Init procd: aplica nft + sobe bot com auto-restart |
| `files/usr/bin/monitor-bot` | Loop principal Telegram (long-polling) |
| `files/usr/bin/monitor-network` | Entry-point cron: `tick`, `ssh`, `scan`, `ddos`, `speed`, etc. |
| `files/usr/lib/monitor/checks.sh` | Toda a lógica de checagem de rede |
| `files/usr/lib/monitor/mac_acl.sh` | nftables MAC (blocklist + enforce opcional) |
| `files/usr/lib/monitor/telegram.sh` | `send_message`, `send_message_html`, `get_updates` |
| `files/usr/lib/monitor/speed_netperf.sh` | Speedtest netperf por WAN |
| `Makefile` | Pacote OpenWrt; incrementar `PKG_RELEASE` a cada mudança |
| `docker/Dockerfile.sdk` | Build cross-compile; feeds update separado do COPY → SDK em cache |
| `.github/workflows/build.yml` | CI: artefacto em PR; GitHub Release em tag `v*` |

## Regras de desenvolvimento — OBRIGATÓRIAS

### Shell / BusyBox / ash

1. `#!/bin/sh` sempre — nunca `#!/bin/bash`. O ambiente é BusyBox ash.
2. Sem arrays bash (`arr=(...)`) — usar ficheiros temporários ou variáveis simples.
3. Sem `[[...]]` — usar `[...]` ou `case`.
4. Sem `local` — vars em funções são globais em ash; prefixar vars internas com `_`.
5. Usar `. ficheiro` — nunca `source`.
6. `printf` em vez de `echo -e` — não portável no BusyBox.
7. `grep -qxF` para match exacto de linha (MACs, paths).
8. `|| true` onde falha esperada é aceitável.

### Segurança

1. Validar sempre `CHAT` e `SENDER` antes de processar qualquer comando.
2. Nunca usar `eval`.
3. Confirmar acções críticas com `SECRET` (adicionar/bloquear MAC).
4. Validar formato MAC: `grep -qE '^([0-9a-f]{2}:){5}[0-9a-f]{2}$'`.
5. Não logar o conteúdo de `config.env` (contém tokens).

### Estado e ficheiros

- `STATE_DIR=/tmp/monitor` — RAM, limpa no reboot (correcto por design).
- `LOG_DIR=/var/log/monitor` — pode ser tmpfs; limpeza cron às 14h.
- Nunca assumir que um ficheiro de estado existe — verificar com `[ -f ... ]`.

### nftables (mac_acl.sh)

- Sempre `nft delete table bridge monitor_acl` antes de recriar.
- Verificar `command -v nft` antes de qualquer operação nft.
- Família `bridge` — requer kernel com bridge netfilter.

## Build

```sh
# Local (Docker):
make -f Makefile.ipk ipk
# → ipk-out/monitor.ipk

# CI: push de tag vX.Y.Z → GitHub Actions cria Release com .ipk
```

## Versionamento

- `PKG_VERSION=1.0` — raramente muda
- `PKG_RELEASE` em `Makefile` — incrementar a cada mudança que gera novo .ipk
- Tags git: `v1.0.<PKG_RELEASE>` (ex: `v1.0.9`)

## Dependências runtime (router)

| Pacote | Para quê |
|---|---|
| `netperf` | `/check_velocidade` — dependência declarada no .ipk |
| `curl` | Telegram API, ipify — `opkg install curl` |
| `jsonfilter` | JSON ubus/Telegram — `opkg install jsonfilter` |
| `nft` | MAC ACL na bridge |

## Como colaborar com a IA — regras para o assistente

1. **Ajudar o humano a entender e a pensar** — não fazer tudo sozinho; explicar o raciocínio.
2. **Objectivo e assertivo** — sem ideias não validadas pelo utilizador.
3. **Propor antes de implementar** — para mudanças não triviais, descrever o quê e o porquê antes de agir.
4. **Zero especulação** — só implementar o que foi pedido e confirmado.
5. **Sempre testar mentalmente no BusyBox** — toda a sintaxe deve funcionar em ash.
6. **Sem comentários desnecessários** — código bem nomeado dispensa explicações inline.
7. **Sem abstrações prematuras** — três linhas similares são melhor do que uma abstracção duvidosa.
8. **Projecto crítico** — qualquer mudança deve funcionar correctamente sem falhas.
