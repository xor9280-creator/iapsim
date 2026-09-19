TARGET := iphone:clang:latest:14.0
ARCHS = arm64
# Rootless jailbreak (Dopamine vb.) icin: make package THEOS_PACKAGE_SCHEME=rootless
INSTALL_TARGET_PROCESSES = OyunAdi

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = IAPSim
IAPSim_FILES = Tweak.x
IAPSim_CFLAGS = -fobjc-arc
IAPSim_FRAMEWORKS = StoreKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
