# Serviços, logs e limpeza automática

Este documento descreve o que o pacote **monitor** arranca no OpenWrt, onde escreve logs, como limpar manualmente e a rotação agendada.

## Serviços em execução

| Componente | Ficheiro | Função |
|--------------|----------|--------|
| **Init** | `/etc/init.d/monitor` | `start`: lança em segundo plano o **`monitor-bot`**. `stop`: `killall monitor-bot`. Ordem: `START=99`. |
| **Monitor de rede** | `/usr/bin/monitor-network` | Checagens de rede (módulos em `/usr/lib/monitor/checks.sh`). Em geral invocado pelo **cron**; também manual ou via Telegram (`/checks`, etc.). O nome `network-monitor` permanece como **symlink** para compatibilidade. |
| **Bot Telegram** | `/usr/bin/monitor-bot` | Long polling na API do Telegram, comandos (`/status`, `/checks`, `/check_rede`, `/check_ssh`, `/check_scan`, `/check_ddos`, `/check_portas`, `/check_velocidade`, `/adiciona_mac`, …) e fluxo de cadastro de MAC. |

Dependências em runtime (não vêm como dependência forçada do `.ipk`): **`curl`**, **`jsonfilter`**.

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
