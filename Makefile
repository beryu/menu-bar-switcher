.PHONY: package release-dmg

DMG := MenuBarSwitcher.dmg
APP := build/MenuBarSwitcher.app
DMG_IDENTIFIER := jp.blk.MenuBarSwitcher.dmg

package:
	test -d "$(APP)"
	rm -f "$(DMG)"
	create-dmg \
		--volname "MenuBarSwitcher" \
		--app-drop-link 600 185 \
		--icon-size 100 \
		--icon "MenuBarSwitcher.app" 200 190 \
		--window-pos 200 120 \
		--window-size 800 400 \
		"$(DMG)" ./build

release-dmg:
	@test -n "$(SIGNING_IDENTITY)" || { echo 'Set SIGNING_IDENTITY to your Developer ID Application identity'; exit 1; }
	@test -n "$(NOTARY_PROFILE)" || { echo 'Set NOTARY_PROFILE to a notarytool keychain profile'; exit 1; }
	$(MAKE) package
	codesign --sign "$(SIGNING_IDENTITY)" --timestamp --identifier "$(DMG_IDENTIFIER)" "$(DMG)"
	codesign --verify --strict --verbose=2 "$(DMG)"
	xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG)"
	xcrun stapler validate "$(DMG)"
