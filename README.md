# bot-monitor-openwrt

Pacote OpenWrt que monitora a rede e automatiza ações via **Telegram** — bot de comandos, NAC por MAC (nftables), checagens de WAN/failover/IP/SSH/DDoS e speedtest por WAN.

## O que faz

- 🤖 **Bot Telegram** — comandos remotos com fluxo conversacional e autenticação
- 🛡 **NAC via MAC** — allowlist/blocklist aplicada com nftables na bridge
- 📡 **Checagens de rede** — WAN, failover, IP público, SSH, scan interno, DDoS, velocidade
- 🔄 **Auto-restart** — serviço gerido pelo procd (reinicia automaticamente se cair)

## Instalação rápida

Descarrega o `.ipk` na [última Release](https://github.com/Nanzitos/bot-monitor-openwrt/releases/latest) e instala no router:

```sh
opkg update
opkg install monitor_*.ipk
opkg install curl jsonfilter   # dependências adicionais
```

Edita `/etc/monitor/config.env` com os teus tokens Telegram e activa o serviço:

```sh
/etc/init.d/monitor enable
/etc/init.d/monitor start
```

## Dependências

| Pacote | Instalação |
|---|---|
| `netperf` | incluído como dependência do `.ipk` |
| `curl` | `opkg install curl` |
| `jsonfilter` | `opkg install jsonfilter` |
| `nft` | incluído no OpenWrt (nftables) |

## Documentação completa

→ **[Wiki do projecto](https://github.com/Nanzitos/bot-monitor-openwrt/wiki)**
