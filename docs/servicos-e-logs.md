# Serviços, logs e limpeza automática

Este documento descreve o que o pacote **monitor** arranca no OpenWrt, onde escreve logs, como limpar manualmente e a rotação agendada.

## Serviços em execução

| Componente | Ficheiro | Função |
|--------------|----------|--------|
| **Init** | `/etc/init.d/monitor` | `start`: corre **`monitor-apply-mac-acl`** (nft MAC) e depois o **`monitor-bot`** em segundo plano. `stop`: `killall monitor-bot`. Ordem: `START=99`. |
| **ACL MAC (nft)** | `/usr/bin/monitor-apply-mac-acl` | Lê **`/etc/monitor/mac_allowlist`** e **`mac_blocklist`**, recria a tabela **`bridge monitor_acl`** (`/usr/lib/monitor/mac_acl.sh`). Chamado no boot e após `/adiciona_mac` / `/bloqueia_mac`. Requer **`nft`**. |
| **Monitor de rede** | `/usr/bin/monitor-network` | Checagens de rede (`checks.sh`). Invocado pelo **cron**; também manual ou Telegram (`/checks`, …). **`network-monitor`** = symlink. |
| **Bot Telegram** | `/usr/bin/monitor-bot` | Comandos: `/status`, `/checks`, checagens `/check_*`, **`/adiciona_mac`** (allowlist + nft, sem DHCP estático), **`/bloqueia_mac`** (blocklist + nft), `/nao_autorizados`, `/cancelar`, … |

Dependências em runtime: o `.ipk` do **monitor** declara **`netperf`** (teste de velocidade por WAN: Telegram **`/check_velocidade`**, `monitor-network speed-notify`). Os scripts **não** instalam pacotes via `opkg` sem consentimento. **`curl`** e **`jsonfilter`** continuam a ser instalados manualmente no router (`opkg install curl jsonfilter`). Para ACL MAC: **`nft`** (nftables).

## MAC allowlist, blocklist e deteção

| Ficheiro | Conteúdo |
|----------|----------|
| `/etc/monitor/mac_allowlist` | MAC autorizados (uma linha por MAC). |
| `/etc/monitor/mac_blocklist` | MAC com **DROP** em nft na bridge (ver `LAN_BRIDGE` / `MAC_ENFORCE` em `config.env`). |

- **`/adiciona_mac`**: adiciona à allowlist (com **SECRET**); remove o MAC da blocklist se lá estiver; **não** cria entrada DHCP/UCI.
- **`/bloqueia_mac`**: remove da allowlist e acrescenta à blocklist (com **SECRET**).

**Fluxo ao detetar MAC desconhecido:** alerta no Telegram + mensagem com **`/bloqueio_sim <mac>`** ou **`/bloqueio_nao <mac>`**. Prazo **10 min** (`BLOCK_PROMPT_SECS` em `config.env`); **sem resposta** → MAC vai para **`mac_blocklist`** e nft é reaplicado. **`/bloqueio_nao`** evita o bloqueio automático **neste ciclo** (ficheiro em `STATE_DIR/block_prompt_ignore`). **`/bloqueia_mac`** mantém bloqueio manual com senha.

Para gerar o `.ipk` só com este pacote no PC (Docker): na raiz do repo, **`make -f Makefile.ipk ipk`** → `ipk-out/monitor.ipk`.

Comandos úteis no router:

```sh
/etc/init.d/monitor status   # se o init script suportar; caso contrário use ps
ps | grep -E 'monitor-network|monitor-bot' | grep -v grep
/etc/init.d/monitor restart
```

## Ficheiros de log

Todos sob **`LOG_DIR`** (por defeito **`/var/log/monitor`**, configurável em `/etc/monitor/config.env`).

| Ficheiro | Origem |
|----------|--------|
| `monitor.log` | `monitor_log` (ex.: falhas `getUpdates` / Telegram). |
| `telegram_audit.log` | Ações do fluxo Telegram (cancelar, cadastro MAC, senha errada, etc.). |
| `telegram_send_errors.log` | Falhas ao enviar mensagem HTML (`send_message_html`). |

**Nota:** estes ficheiros **crescem com append**; o pacote não faz rotação por tamanho. Em muitos routers **`/var/log` é tmpfs** — logs muito grandes consomem **RAM**. A limpeza diária evita crescimento indefinido.

## Limpeza manual dos logs

```sh
/usr/bin/monitor-clear-logs
```

O comando **remove** cada um dos três ficheiros e **volta a criá-los vazios** com `touch` (equivalente a log novo). Respeita `LOG_DIR` definido em `config.env` quando aplicável.

## Crontab (limpeza de logs e `monitor-network`)

Na **instalação ou atualização** do pacote (`opkg install` / `opkg upgrade`), o **`postinst`** acrescenta linhas em **`/etc/crontabs/root`** (cada uma só se ainda não existir o mesmo comando):

| Agendamento | Comando |
|-------------|---------|
| Diário 14:00 | `/usr/bin/monitor-clear-logs` |
| A cada 5 min | `/usr/bin/monitor-network tick` (WAN, failover, IP público wan/wan2, MAC) |
| A cada 10 min | `/usr/bin/monitor-network ssh` (falhas SSH em `logread`) |
| A cada 2 h (minuto 0) | `/usr/bin/monitor-network scan` (`MONITOR_DROP` no último minuto) |
| Diário 08:00 | `/usr/bin/monitor-network daily` (relatório) |
| A cada 15 min | `/usr/bin/monitor-network ddos` (heurística `nf_conntrack`, se existir) |
| A cada 15 min | `/usr/bin/monitor-network portscan` (pico de porta em `MONITOR_DROP`) |
| A cada 30 min | `/usr/bin/monitor-network speed` (velocidade RX/TX no **log local**; sem alerta Telegram) |

Requisitos:

1. Serviço **`cron`** ativo (`/etc/init.d/cron enable` e `start`), típico em OpenWrt com **BusyBox crond**.
2. Ficheiro **`/etc/crontabs/root`**.

Após instalar, se o cron já estiver a correr:

```sh
/etc/init.d/cron reload
```

Na **desinstalação** (`opkg remove monitor`), o **`prerm`** remove as linhas que referem `monitor-clear-logs` e **`/usr/bin/monitor-network`** (outras entradas do crontab mantêm-se).

## Desinstalação / remoção manual da entrada cron

Se removeres o pacote com `opkg remove monitor`, o `prerm` trata do cron. Para remover só a linha à mão:

```sh
grep -v -e monitor-clear-logs -e '/usr/bin/monitor-network' /etc/crontabs/root > /tmp/root.cron && mv /tmp/root.cron /etc/crontabs/root
/etc/init.d/cron reload
```
