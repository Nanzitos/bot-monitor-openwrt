# Serviços, logs e limpeza automática

Este documento descreve o que o pacote **monitor** arranca no OpenWrt, onde escreve logs, como limpar manualmente e a rotação agendada.

## Serviços em execução

| Componente | Ficheiro | Função |
|--------------|----------|--------|
| **Init** | `/etc/init.d/monitor` | `start`: lança em segundo plano o `network-monitor` e o `monitor-bot`. `stop`: envia sinal a esses processos (`killall`). Ordem de arranque: `START=99`. |
| **Monitor de rede** | `/usr/bin/network-monitor` | Lê estado WAN/WAN2, failover, IP público (ipify), vizinhos ARP vs allowlist, padrões em `logread` (SSH, `MONITOR_DROP`), relatório diário; envia alertas via Telegram (HTML). |
| **Bot Telegram** | `/usr/bin/monitor-bot` | Long polling na API do Telegram, comandos (`/status`, `/adiciona_mac`, etc.) e fluxo de cadastro de MAC. |

Dependências em runtime (não vêm como dependência forçada do `.ipk`): **`curl`**, **`jsonfilter`**.

Comandos úteis no router:

```sh
/etc/init.d/monitor status   # se o init script suportar; caso contrário use ps
ps | grep -E 'network-monitor|monitor-bot' | grep -v grep
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

## Limpeza automática (todos os dias às 14:00)

Na **instalação ou atualização** do pacote (`opkg install` / `opkg upgrade`), o script **`postinst`** regista uma linha no crontab do **root**:

```text
0 14 * * * /usr/bin/monitor-clear-logs
```

Requisitos:

1. Serviço **`cron`** ativo (`/etc/init.d/cron enable` e `start`), típico em OpenWrt com **BusyBox crond**.
2. Ficheiro **`/etc/crontabs/root`** — o `postinst` só acrescenta a linha se ainda não existir uma referência a `monitor-clear-logs`.

Após instalar, se o cron já estiver a correr:

```sh
/etc/init.d/cron reload
```

Na **desinstalação** (`opkg remove monitor`), o **`prerm`** remove essa linha do crontab do root (outras linhas mantêm-se).

## Desinstalação / remoção manual da entrada cron

Se removeres o pacote com `opkg remove monitor`, o `prerm` trata do cron. Para remover só a linha à mão:

```sh
grep -v monitor-clear-logs /etc/crontabs/root > /tmp/root.cron && mv /tmp/root.cron /etc/crontabs/root
/etc/init.d/cron reload
```
