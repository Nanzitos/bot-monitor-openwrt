# bot-monitor-openwrt

Repositório **Monitor**: monitoramento de rede e automação no roteador via **Telegram**, empacotado para OpenWrt (`.ipk`).

---

## Estrutura do repositório

O `Makefile` e a pasta `files/` ficam na **raiz** do projeto (árvore típica de pacote OpenWrt):

Documentação operacional: **[docs/servicos-e-logs.md](docs/servicos-e-logs.md)** (serviços, ficheiros de log, limpeza manual e cron às 14h).

```
.
├── Makefile              # pacote OpenWrt (SDK)
├── Makefile.ipk          # gera ipk-out/monitor.ipk no PC (Docker + SDK)
├── docs/
│   └── servicos-e-logs.md
└── files/
    ├── etc/
    │   ├── init.d/
    │   │   └── monitor
    │   └── monitor/
    │       ├── config.env
    │       ├── mac_allowlist
    │       └── mac_blocklist
    ├── usr/
    │   ├── bin/
    │   │   ├── monitor-network
    │   │   ├── monitor-bot
    │   │   ├── monitor-apply-mac-acl
    │   │   └── monitor-clear-logs
    │   └── lib/
    │       └── monitor/
    │           ├── checks.sh
    │           ├── speed_netperf.sh
    │           ├── configs.sh
    │           ├── mac_acl.sh
    │           ├── telegram.sh
    │           └── utils.sh
    └── var/
        └── log/
            └── monitor/
```

No roteador, em tempo de execução, também entram em uso diretórios como `/tmp/monitor` (estado; ver `STATE_DIR` em `config.env`) e `/var/log/monitor` (logs).

---

## Build e instalação

### No SDK OpenWrt (árvore de pacotes)

1. Copie este diretório para a árvore de pacotes do SDK ou buildroot OpenWrt (por exemplo `package/monitor/`), mantendo `Makefile` e `files/` como estão.
2. No diretório raiz do build OpenWrt, compile o pacote, por exemplo:
   - `make package/monitor/compile V=s`
3. Instale o `.ipk` gerado no roteador (`opkg install monitor_*.ipk`). O pacote declara dependência de **`netperf`** (usado em **`/check_velocidade`** / `monitor-network speed-notify`). Garanta também **`curl`** e **`jsonfilter`** (`opkg install curl jsonfilter`) — não entram como dependência automática do pacote (evitar arrastar builds pesados no SDK).

### `.ipk` no PC com Docker (repositório só com este pacote)

Na **raiz deste repositório**:

```sh
make -f Makefile.ipk ipk
```

(Sem argumentos, o alvo predefinido também é `ipk`.) O ficheiro fica em **`ipk-out/monitor.ipk`**. Requer Docker; o SDK-alvo predefinido está em `docker/docker-compose.ipk.yml` (ajuste `SDK_URL` para o teu router).

---

## Configuração

Edite `/etc/monitor/config.env` no dispositivo (valores de exemplo no repositório):

| Variável | Função |
|----------|--------|
| `TELEGRAM_TOKEN` | Token do bot |
| `TELEGRAM_CHAT_ID` | Chat autorizado |
| `TELEGRAM_USER_ID` | Usuário autorizado |
| `SECRET` | Confirmação de ações sensíveis |
| `ALLOWLIST` | Caminho da allowlist MAC (`/etc/monitor/mac_allowlist`) |
| `BLOCKLIST` | MAC bloqueados por nft (`/etc/monitor/mac_blocklist`) |
| `MAC_ENFORCE` | `1` = só MAC da allowlist na bridge (nft); `0` = só DROP explícitos da blocklist |
| `LAN_BRIDGE` | Interface bridge a filtrar (ex.: `br-lan`; ajustar ao teu AP/router) |
| `LOG_DIR` | Diretório de logs |
| `STATE_DIR` | Estado temporário (ex.: `/tmp/monitor`) |
| `DDOS_MAX_PER_IP` | (opcional) limiar conntrack por IP; ver `checks.sh` |
| `PORT_SPIKE_MIN` | (opcional) eventos `MONITOR_DROP` por porta no minuto |
| `SPEEDTEST_HOST`, `SPEEDTEST_DURATION`, `SPEEDTEST_STREAMS` | (opcional) servidor e parâmetros do teste netperf por WAN; ver comentários em `config.env` |

**Teste de velocidade (`/check_velocidade`):** usa o binário **`netperf`** com bind ao IP de cada WAN. O pacote **`monitor`** declara **`netperf`** como dependência OpenWrt; os scripts **não** executam `opkg install` automaticamente. Se `netperf` faltar, o Telegram mostra aviso com `opkg install netperf`.

**Allowlist / blocklist:** edita os ficheiros ou usa o Telegram — **`/adiciona_mac`** (só grava na allowlist + reaplica nft; **sem** reserva DHCP estático), **`/bloqueia_mac`** (allowlist → blocklist). O script **`/usr/bin/monitor-apply-mac-acl`** recria regras **nftables** (`bridge monitor_acl`). Exige **`nft`** no sistema.

**Deteção vs bloqueio:** ao detetar MAC fora da allowlist, o monitor envia **alerta HTML** e uma **mensagem** com **`/bloqueio_sim`** ou **`/bloqueio_nao`** (prazo **10 min**, configurável com **`BLOCK_PROMPT_SECS`**). Sem resposta → **bloqueio automático** na blocklist. **`/bloqueio_nao`** grava ignorar este ciclo; **`/bloqueia_mac`** continua disponível para bloqueio manual com senha.

**Firewall / scan interno:** o monitor procura a marca **`MONITOR_DROP`** nos logs. Se antes usavas `SEBASTIANA_DROP`, atualiza as regras iptables/nft para logar `MONITOR_DROP`.

---

## Serviço (init) e agendamento

O pacote instala `/etc/init.d/monitor`. No **`start`**: corre **`monitor-apply-mac-acl`** (regras nft de MAC) e depois o **`monitor-bot`**. As checagens de rede (`monitor-network`) vão pelo **cron** (ver [docs/servicos-e-logs.md](docs/servicos-e-logs.md)). O binário legado **`network-monitor`** é um symlink para `monitor-network`.

```sh
/etc/init.d/monitor enable
/etc/init.d/monitor start
```

---

## Tecnologias e ambiente

* OpenWrt
* Shell script (ash/sh)
* UCI (configuração do OpenWrt)
* dnsmasq (DHCP)
* mwan3 (failover WAN)
* Telegram Bot API (getUpdates + sendMessage)
* curl + jsonfilter
* netperf (dependência do pacote; teste de velocidade)

---

## Prompt IA

Bloco abaixo pode ser colado em ferramentas de IA ou em regras do projeto para manter contexto e padrões.

```
Você é um arquiteto de software especializado em sistemas embarcados, redes e OpenWrt.

Estou desenvolvendo um sistema chamado **Monitor** (pacote OpenWrt `monitor`), que roda em um roteador com OpenWrt e tem como objetivo:

* Monitoramento de rede (WAN, failover, IP público, latência)
* Segurança (detecção de dispositivos via MAC, NAC/allowlist)
* Automação via Telegram (bot com comandos remotos)
* Organização modular (libs, binários, config e logs)
* Empacotamento como pacote `.ipk` (Makefile OpenWrt neste repositório)

## Estrutura atual do projeto

O sistema segue esta organização:

/etc/monitor/
config.env
mac_allowlist
mac_blocklist

/etc/init.d/monitor

/usr/lib/monitor/
checks.sh
configs.sh
mac_acl.sh
telegram.sh
utils.sh

/usr/bin/
monitor-network
monitor-bot
monitor-apply-mac-acl

/var/log/monitor/

/tmp/monitor/   (estado; configurável via STATE_DIR)

## Tecnologias e ambiente

* OpenWrt
* Shell script (ash/sh)
* UCI (configuração do OpenWrt)
* dnsmasq (DHCP)
* mwan3 (failover WAN)
* Telegram Bot API (getUpdates + sendMessage)
* curl + jsonfilter
* netperf (dependência do pacote; teste de velocidade)

## Requisitos de segurança

* Validar sempre chat_id e user_id
* Nunca executar comandos arbitrários (sem eval)
* Uso de senha para confirmação de ações críticas
* Logs de auditoria
* Evitar exposição de credenciais

## Objetivo da sua atuação

Você deve atuar como um engenheiro sênior e me ajudar a:

1. Melhorar a arquitetura do sistema
2. Refatorar scripts para melhor organização e reaproveitamento
3. Criar novas funcionalidades seguras
4. Garantir boas práticas de OpenWrt e Linux embarcado
5. Manter e evoluir o empacotamento `.ipk`
6. Sugerir melhorias de performance e segurança
7. Evitar anti-patterns em shell script

## Regras importantes

* Sempre escrever código limpo e seguro
* Explicar brevemente o raciocínio técnico
* Evitar soluções frágeis ou “gambiarras”
* Priorizar compatibilidade com OpenWrt (BusyBox)
* Não usar dependências pesadas desnecessárias
* Sempre considerar limitações de hardware

## Exemplos de tarefas que você deve resolver

* Criar novos módulos (ex: IDS, scan de rede, bloqueio automático)
* Melhorar o bot do Telegram com comandos seguros
* Criar sistema de estado para interações (fluxo conversacional)
* Implementar allowlist por VLAN
* Criar CLI (ex: `monitor status`)
* Melhorar logging estruturado
* Refinar init.d (dependências, reinício, tratamento de erro)
* Validar e otimizar scripts existentes

## Forma de resposta

Sempre responda com:

1. Explicação objetiva
2. Código pronto para uso
3. Sugestões de melhoria (quando relevante)

---

Agora vou te enviar trechos do meu código ou pedir melhorias específicas. Analise e proponha soluções profissionais.
```
