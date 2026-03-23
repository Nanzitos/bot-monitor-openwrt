include $(TOPDIR)/rules.mk

PKG_NAME:=sebastiana
PKG_VERSION:=1.0
PKG_RELEASE:=1

include $(INCLUDE_DIR)/package.mk

define Package/sebastiana
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Sebastiana Network Monitor
  DEPENDS:=+curl +jq
endef

define Package/sebastiana/description
 Sistema de monitoramento e automação via Telegram
endef

define Package/sebastiana/conffiles
/etc/sebastiana/config.env
/etc/sebastiana/mac_allowlist
endef

define Package/sebastiana/install
	$(INSTALL_DIR) $(1)/etc/sebastiana
	$(INSTALL_DATA) ./files/etc/sebastiana/config.env $(1)/etc/sebastiana/
	$(INSTALL_DATA) ./files/etc/sebastiana/mac_allowlist $(1)/etc/sebastiana/

	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) ./files/usr/bin/sebastiana-monitor $(1)/usr/bin/
	$(INSTALL_BIN) ./files/usr/bin/sebastiana-bot $(1)/usr/bin/

	$(INSTALL_DIR) $(1)/usr/lib/sebastiana
	$(INSTALL_DATA) ./files/usr/lib/sebastiana/* $(1)/usr/lib/sebastiana/

	$(INSTALL_DIR) $(1)/var/log/sebastiana

	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/etc/init.d/sebastiana $(1)/etc/init.d/
endef

$(eval $(call BuildPackage,sebastiana))
