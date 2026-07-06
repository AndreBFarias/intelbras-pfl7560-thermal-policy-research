# init.rc import /vendor/etc/init/hw/init.${ro.hardware}.rc
# vendor_init is forked from init early in the boot process.
# Has SELinux context u:r:vendor_init:s0 . , which is more restricted than the system init context.
# Can only access files/properties that are either vendor-specific or part of the stable system-vendor ABI.

#add chip rc
import /vendor/etc/init/hw/init.chipset.rc

on early-init
    # Shouldn't be necessary, but sdcard won't start without it. http://b/22568628.
    mkdir /mnt 0775 root system
    mount tmpfs tmpfs /mnt nodev noexec nosuid mode=0775,uid=0,gid=1000
    mount debugfs debugfs /sys/kernel/debug mode=0755
    setrlimit memlock 8388608 8388608

on init
    symlink /sdcard /mnt/sdcard
    mkdir /mnt/smb 0771 system system
    mkdir /mnt/drm 0770 system shell
    mkdir /mnt/nfsShare 0771 system system
    chmod 444 /proc/msp/otp
    chmod 444 /proc/msp/hdmirx

on fs
    mount_all /vendor/etc/fstab.${ro.hardware}

    # teecd access securestore
    chmod 777 /securestore
    restorecon_recursive /securestore

    # atv partition
    chown system system /atv
    chmod 771 /atv
    chmod 640 /proc/msp/pm_gpu
    # for newlink silent update
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh /data/local/nlsu/update_before_boot.sh
    # config model file, for newlink onebin
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh /vendor/bin/atv_config_update.sh
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh /vendor/bin/config_model.sh
    restorecon_recursive /atv

    # log partition
    chown root root /log
    chmod 755 /log
    restorecon_recursive /log

    mkdir /log/hilog 0755 root root

    # setprop vendor.insmod.ko 1

# on post-fs
on post-fs-data

    # config model file, for onebin
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/config_model.sh

    # FIXME create dtv data for vendor hal
    mkdir /data/vendor/dtvdata 0770 system system
    # Create the directories used by the Wireless subsystem
    # Copy wpa_supplicant config files to related dir
    chown root system /data/vendor/dtvdata/DATABASE
    chown root system /data/vendor/dtvdata/DATABASE_ATSC_R
    chown root system /data/vendor/dtvdata/DATABASE_ATSC
    chmod 0660 /data/vendor/dtvdata/DATABASE
    chmod 0660 /data/vendor/dtvdata/DATABASE_ATSC_R
    chmod 0660 /data/vendor/dtvdata/DATABASE_ATSC
    chmod 0777 /atv/bootvideo/bootanimation.zip
    chmod 0777 /atv/bootvideo/bootvideo.mp4
    chmod 0777 /atv/bootvideo/logo.jpg

    # patch for 浩博高 语音遥控器
    mkdir /data/vendor/HBG 0770 audioserver audioserver
    symlink /vendor/etc/remote.txt /data/vendor/HBG/remote.txt

    mkdir /data/vendor/wifi 0771 wifi wifi
    mkdir /data/vendor/wifi/wpa 0770 wifi wifi
    chown wifi wifi /data/vendor/wifi/wpa/wpa_supplicant.conf
    chown wifi wifi /data/vendor/wifi/wpa/p2p_supplicant.conf
    mkdir /data/vendor/wifi/wpa/sockets 0770 wifi wifi
    # Copy wificond config files to related dir
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/copy_wifi_config.sh

on boot
    # insmod tntfs drivers
    exec u:r:vendor_modprobe:s0 root root -- /vendor/bin/toybox_vendor insmod /vendor/lib64/modules/tntfs_hisilicon.ko
    # for compatibility in 32bit os
    exec u:r:vendor_modprobe:s0 root root -- /vendor/bin/toybox_vendor insmod /vendor/lib/modules/tntfs_hisilicon.ko

    chmod 660 /sys/class/rfkill/rfkill0/state
    chown system bluetooth /sys/class/rfkill/rfkill0/state
    # insmod bluetooth drivers
    #insmod  /vendor/lib64/modules/btusb.ko
    #insmod  /vendor/lib/modules/btusb.ko
    #insmod  /vendor/lib64/modules/btmtk_usb.ko
    #insmod  /vendor/lib/modules/btmtk_usb.ko
    insmod /vendor/lib/modules/aic_load_fw.ko aic_fw_path="vendor/firmware"
    insmod /vendor/lib/modules/skw_usb.ko
    insmod /vendor/lib/modules/skw_bootcoms.ko
    #insmod /vendor/lib/modules/skw.ko
    #insmod /vendor/lib/modules/aic_btusb.ko
    #chmod 0660 /dev/aicbt_dev
    #chown bluetooth net_bt_admin /dev/aicbt_dev
    start vendor.ir_user
    start vendor.virtualkeypad

    mkdir /dev/usb-ffs 0770 shell shell
    mkdir /dev/usb-ffs/adb 0770 shell shell
    mkdir /config/usb_gadget/g1 0770 shell shell
    mkdir /config/usb_gadget/g1/functions/ffs.adb
    mount functionfs adb /dev/usb-ffs/adb uid=2000,gid=2000
    #setprop persist.adb.tcp.port 5555
    #setprop service.adb.tcp.port 5555

    # Start essential services
    class_start main
    class_start late_start

    # drm
    mkdir /data/vendor/mediadrm 0770 media mediadrm
    mkdir /data/vendor/mediadrm/playready 0700 media mediadrm

    # keymaster
    mkdir /data/vendor/keymaster 0750 system system

    # widevine
    mkdir /data/vendor/widevine 0750 system system
    # playready
    mkdir /data/vendor/playready 0750 system system
    mkdir /securestore/playready 0700 media mediadrm
    chmod 600 /securestore/playready/bgroupcert.dat
    chmod 600 /securestore/playready/zgpriv_protected.dat
    chown media mediadrm /securestore/playready/bgroupcert.dat
    chown media mediadrm /securestore/playready/zgpriv_protected.dat
    chmod 700 /atv/hdcp
    chown system system /atv/hdcp
    chmod 400 /atv/hdcp/HDCP_LC_enc.dat
    chown system system /atv/hdcp/HDCP_LC_enc.dat
    chmod 777 /data/local

    #bluetooth log
    mkdir /data/vendor/bluetooth 0770 bluetooth bluetooth
# ko insmod
on property:sys.64bit.insmod.ko=1
   insmod  vendor/lib64/modules/tntfs_hisilicon.ko

on property:sys.32bit.insmod.ko=0
   insmod  vendor/lib/modules/tntfs_hisilicon.ko

on property:sys.sysctl.min_free_kbytes=*
    write /proc/sys/vm/min_free_kbytes ${sys.sysctl.min_free_kbytes}

service vendor.ir_user /vendor/bin/android_ir_user
    user root
    group system

# Add memcserver
service memcserver /vendor/bin/memcserver
    class main
    user root
    group root
    oneshot

service wpa_supplicant /vendor/bin/hw/wpa_supplicant \
    -O/data/vendor/wifi/wpa/sockets \
    -ip2p0 -Dnl80211 -c/data/vendor/wifi/wpa/p2p_supplicant.conf \
    -e/data/misc/wifi/entropy.bin -puse_p2p_group_interface=0 -N \
    -iwlan0 -Dnl80211 -c/data/vendor/wifi/wpa/wpa_supplicant.conf \
    -g@android:wpa_wlan0
    # we will start as root and wpa_supplicant will switch to user wifi
    # after setting up the capabilities required for WEXT
    # user wifi
    # group wifi inet keystore
    interface android.hardware.wifi.supplicant@1.0::ISupplicant default
    interface android.hardware.wifi.supplicant@1.1::ISupplicant default
    class main
    socket wpa_wlan0 dgram 660 wifi wifi
    disabled
    oneshot

service rtk_supplicant /vendor/bin/hw/rtk_supplicant \
    -O/data/vendor/wifi/wpa/sockets \
    -ip2p0 -Dnl80211 -c/data/vendor/wifi/wpa/p2p_supplicant.conf \
    -e/data/misc/wifi/entropy.bin -puse_p2p_group_interface=0 -N \
    -iwlan0 -Dnl80211 -c/data/vendor/wifi/wpa/wpa_supplicant.conf \
    -g@android:wpa_wlan0
    # we will start as root and wpa_supplicant will switch to user wifi
    # after setting up the capabilities required for WEXT
    # user wifi
    # group wifi inet keystore
    interface android.hardware.wifi.supplicant@1.0::ISupplicant default
    interface android.hardware.wifi.supplicant@1.1::ISupplicant default
    class main
    socket wpa_wlan0 dgram 660 wifi wifi
    disabled
    oneshot

service mtk_supplicant /vendor/bin/hw/wpa_supplicant \
    -O/data/vendor/wifi/wpa/sockets \
    -iwlan0 -Dnl80211 -c/data/vendor/wifi/wpa/wpa_supplicant.conf \
    -e/data/misc/wifi/entropy.bin -puse_p2p_group_interface=1  -N \
    -ip2p0 -Dnl80211 -c/data/vendor/wifi/wpa/p2p_supplicant.conf \
    -g@android:wpa_wlan0
    # we will start as root and wpa_supplicant will switch to user wifi
    # after setting up the capabilities required for WEXT
    # user wifi
    # group wifi inet keystore
    interface android.hardware.wifi.supplicant@1.0::ISupplicant default
    interface android.hardware.wifi.supplicant@1.1::ISupplicant default
    class main
    socket wpa_wlan0 dgram 660 wifi wifi
    disabled
    oneshot

service aic_supplicant /vendor/bin/hw/aic_supplicant \
    -O/data/vendor/wifi/wpa/sockets \
    -iwlan0 -Dnl80211 -c/data/vendor/wifi/wpa/wpa_supplicant.conf \
    -m/data/vendor/wifi/wpa/p2p_supplicant_aic.conf \
    -e/data/misc/wifi/entropy.bin -puse_p2p_group_interface=1p2p_device=1 \
    -g@android:wpa_wlan0
    # we will start as root and wpa_supplicant will switch to user wifi
    # after setting up the capabilities required for WEXT
    # user wifi
    # group wifi inet keystore
    interface android.hardware.wifi.supplicant@1.0::ISupplicant default
    interface android.hardware.wifi.supplicant@1.1::ISupplicant default
    class main
    socket wpa_wlan0 dgram 660 wifi wifi
    disabled
    oneshot

service skw_supplicant /vendor/bin/hw/skw_supplicant \
    -iwlan0 -Dnl80211 -c/data/vendor/wifi/wpa/wpa_supplicant.conf \
    -m/data/vendor/wifi/wpa/p2p_supplicant_aic.conf \
    -O/data/vendor/wifi/wpa/sockets \
    -e /data/misc/wifi/entropy.bin \
    -g@android:wpa_wlan0
    # we will start as root and wpa_supplicant will switch to user wifi
    # after setting up the capabilities required for WEXT
    # user wifi
    # group wifi inet keystore
    interface android.hardware.wifi.supplicant@1.0::ISupplicant default
    interface android.hardware.wifi.supplicant@1.1::ISupplicant default
    class main
    socket wpa_wlan0 dgram 660 wifi wifi
    disabled
    oneshot



#add for xiriservice
service xiriservice /system/bin/xiriservice
    disabled
    class main
    user root
    group root
    oneshot
    seclabel u:r:tee:s0
#end for xiriservice

service vendor.dhcpcd_eth0 /vendor/bin/dhcpcd -aABDKL
    class main
    disabled
    oneshot

service vendor.iprenew_eth0 /vendor/bin/dhcpcd -n
    class main
    disabled
    oneshot

service vendor.dhcpcd_eth1 /vendor/bin/dhcpcd -aABDKL
    class main
    disabled
    oneshot

service vendor.iprenew_eth1 /vendor/bin/dhcpcd -n
    class main
    disabled
    oneshot

# Add dhcpcd service
service vendor.dhcpcd_wlan0 /vendor/bin/dhcpcd -aABDKL
    class main
    disabled
    oneshot

service vendor.dhcpcd_p2p /vendor/bin/dhcpcd -aABDKL
    class main
    disabled
    oneshot

# Add dhcpcd-iprenew service
service vendor.iprenew_wlan0 /vendor/bin/dhcpcd -n
    class main
    disabled
    oneshot

service vendor.iprenew_p2p /vendor/bin/dhcpcd -n
    class main
    disabled
    oneshot

# add hiavplayer
service vendor.hiavplayer /vendor/bin/hiavplayer
  user system
  group root system

#add breathlight
service vendor.breathlight /vendor/bin/breathlight 2 3 5000
    class main
    user root
    group root
    oneshot
    disabled

on property:vendor.gpiopwm_breathlight=1
    start vendor.breathlight

service vendor.hiquickplay /vendor/bin/hiquickplay
    priority -20
    class core
    user system
    group system inet net_bt net_bt_admin net_bw_acct sdcard_r sdcard_rw media_rw
    ioprio rt 4
    oneshot

# service for virtual keypad
service vendor.virtualkeypad /vendor/bin/virtualkeypad
    class main
    user  root
    group root bluetooth

# Do not change user of teecd, because tee will check its uid when kernel startup.
# Run as root for secure storage and dev/tc_ns_client.
service vendor.teecd /vendor/bin/teecd
    class main
    user root
    group root
    seclabel u:r:tee:s0

service pqserver /vendor/bin/pqserver
    class main
    user root
    group root system audio graphics
    oneshot

service hipluginserver /vendor/bin/hipluginserver
    class main
    user root
    group root system
    oneshot

service cmdsrv /vendor/bin/cmdsrv 15 /data/local/cmdsrv
    class main
    user root
    group root
    oneshot

service hidraw /vendor/bin/vr_bee_hidraw_daemon
    class main
    user root
    group root

on property:vendor.newlink.is_auto_test=true
   exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh -c "echo hide  > /proc/msp/hifb0"

on property:vendor.newlink.is_auto_test=false
   exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh -c "echo show  > /proc/msp/hifb0"

on property:vendor.factory.auto_wakeup=1
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh -c "echo auto_wakeup 1 > /proc/msp/pm"

on property:sys.boot_completed=1
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh /data/local/nlsu/update_after_boot.sh
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh /vendor/bin/nl_usb_update.sh


service screenshot /system/bin/sh  /vendor/bin/nl_screenshot.sh
        user root
        group root system shell
        disabled
        oneshot
        seclabel u:r:init:s0

on property:vendor.nl.screenshot=1
    setprop vendor.nl.screenshot 0
    start screenshot

on property:vendor.nl.dropcaches=1
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh -c "echo 3 > /proc/sys/vm/drop_caches"
    exec u:r:vendor_shell:s0 root root -- /vendor/bin/sh -c "echo 3 > /proc/sys/vm/drop_caches"
    setprop vendor.nl.dropcaches 0