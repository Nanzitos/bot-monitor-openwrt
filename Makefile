include $(TOPDIR)/rules.mk

PKG_NAME:=monitor
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/monitor
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=OpenWrt Monitor (Telegram)
  DEPENDS:=+curl +jsonfilter
endef

define Package/monitor/description
 Monitoramento de rede e automação via Telegram
endef

define Package/monitor/conffiles
/etc/monitor/config.env
/etc/monitor/mac_allowlist
endef

define Package/monitor/install
	$(INSTALL_DIR) $(1)/etc/monitor
	$(INSTALL_DATA) ./files/etc/monitor/config.env $(1)/etc/monitor/
	$(INSTALL_DATA) ./files/etc/monitor/mac_allowlist $(1)/etc/monitor/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/network-monitor $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/monitor-bot $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/monitor
	$(INSTALL_DATA) ./files/usr/lib/monitor/* $(1)/usr/lib/monitor/

	$(INSTALL_DIR) $(1)/var/log/monitor

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/monitor $(1)/etc/init.d/
endef

$(eval $(call BuildPackage,monitor))
