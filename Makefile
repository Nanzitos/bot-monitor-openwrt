# Pacote OpenWrt (compilação no SDK). Para gerar ipk-out/monitor.ipk no PC com Docker:
#   make -f Makefile.ipk ipk
include $(TOPDIR)/rules.mk

PKG_NAME:=monitor
PKG_VERSION:=1.0
PKG_RELEASE:=8

include $(INCLUDE_DIR)/package.mk

define Package/monitor
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=OpenWrt Monitor (Telegram)
  # netperf: teste de velocidade (/check_velocidade); curl/jsonfilter continuam opcionais no .ipk
  # (evita drag pesado no SDK; no router: opkg install curl jsonfilter).
  DEPENDS:=+netperf
endef

define Package/monitor/description
 Monitoramento de rede e automação via Telegram.
 Requer: netperf (dependência; teste de velocidade por WAN). Instalar também: curl e jsonfilter (opkg install curl jsonfilter).
endef

define Package/monitor/conffiles
/etc/monitor/config.env
/etc/monitor/mac_allowlist
/etc/monitor/mac_blocklist
endef

define Package/monitor/postinst
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
mkdir -p /etc/crontabs
touch /etc/crontabs/root
grep -qF '/usr/bin/monitor-clear-logs' /etc/crontabs/root 2>/dev/null || \
	echo "0 14 * * * /usr/bin/monitor-clear-logs" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network tick' /etc/crontabs/root 2>/dev/null || \
	echo "*/5 * * * * /usr/bin/monitor-network tick" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network ssh' /etc/crontabs/root 2>/dev/null || \
	echo "*/10 * * * * /usr/bin/monitor-network ssh" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network scan' /etc/crontabs/root 2>/dev/null || \
	echo "0 */2 * * * /usr/bin/monitor-network scan" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network daily' /etc/crontabs/root 2>/dev/null || \
	echo "0 8 * * * /usr/bin/monitor-network daily" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network ddos' /etc/crontabs/root 2>/dev/null || \
	echo "*/15 * * * * /usr/bin/monitor-network ddos" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network portscan' /etc/crontabs/root 2>/dev/null || \
	echo "*/15 * * * * /usr/bin/monitor-network portscan" >> /etc/crontabs/root
grep -qF '/usr/bin/monitor-network speed' /etc/crontabs/root 2>/dev/null || \
	echo "*/30 * * * * /usr/bin/monitor-network speed" >> /etc/crontabs/root
[ -x /etc/init.d/cron ] && /etc/init.d/cron reload 2>/dev/null || true
exit 0
endef

define Package/monitor/prerm
#!/bin/sh
[ -n "$${IPKG_INSTROOT}" ] && exit 0
[ -f /etc/crontabs/root ] || exit 0
grep -v -e '/usr/bin/monitor-clear-logs' -e '/usr/bin/monitor-network' /etc/crontabs/root > /tmp/monitor-cron.tmp 2>/dev/null && \
	mv /tmp/monitor-cron.tmp /etc/crontabs/root
[ -x /etc/init.d/cron ] && /etc/init.d/cron reload 2>/dev/null || true
exit 0
endef

# Pacote só instala scripts (evita autotools / make no build_dir)
define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
	true
endef

define Build/Compile
	true
endef

define Package/monitor/install
	$(INSTALL_DIR) $(1)/etc/monitor
	$(INSTALL_DATA) ./files/etc/monitor/config.env $(1)/etc/monitor/
	$(INSTALL_DATA) ./files/etc/monitor/mac_allowlist $(1)/etc/monitor/
	$(INSTALL_DATA) ./files/etc/monitor/mac_blocklist $(1)/etc/monitor/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/monitor-network $(1)/usr/bin/
	ln -sf monitor-network $(1)/usr/bin/network-monitor
	$(INSTALL_BIN) ./files/usr/bin/monitor-bot $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/monitor-apply-mac-acl $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/monitor-clear-logs $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/monitor
	$(INSTALL_DATA) ./files/usr/lib/monitor/* $(1)/usr/lib/monitor/

	$(INSTALL_DIR) $(1)/var/log/monitor

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/monitor $(1)/etc/init.d/
endef

$(eval $(call BuildPackage,monitor))
