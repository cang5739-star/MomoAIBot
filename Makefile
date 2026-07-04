export TARGET := iphone:clang:15.0:13.0
export ARCHS = arm64 arm64e
export PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MomoAIBot
MomoAIBot_FILES = Tweak/Tweak.xm
MomoAIBot_CFLAGS = -fobjc-arc
MomoAIBot_FRAMEWORKS = UIKit Foundation
MomoAIBot_PRIVATE_FRAMEWORKS = 

include $(THEOS_MAKE_PATH)/tweak.mk

BUNDLE_NAME = MomoAIPrefs
MomoAIPrefs_FILES = Prefs/MomoAIPrefs.mm
MomoAIPrefs_CFLAGS = -fobjc-arc
MomoAIPrefs_FRAMEWORKS = UIKit Foundation
MomoAIPrefs_PRIVATE_FRAMEWORKS = Preferences
MomoAIPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk

after-install::
	install.exec "killall -9 SpringBoard" || true
