#!/bin/bash
#=================================================
# 自定义脚本修复版
#=================================================
##########################################添加额外包##########################################

# Git稀疏克隆函数修复
function git_sparse_clone() {
 branch="$1" repourl="$2" && shift 2
 git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
 repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
 cd $repodir && git sparse-checkout set $@
 mv -f $@ package/linpc  # 修复路径：移除 "../"
 cd .. && rm -rf $repodir
}

# 创建目录
mkdir -p package/linpc

# 移除冲突包
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata

#luci-theme-argone
git_sparse_clone main https://github.com/kenzok8/small-package luci-theme-argone
git_sparse_clone main https://github.com/kenzok8/small-package luci-app-argone-config

#luci-app-store依赖
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-lib-taskd
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-lib-xterm
git_sparse_clone master https://github.com/kiddin9/openwrt-packages taskd

#科学上网插件
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-app-openclash
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-app-passwall
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-app-ssr-plus

#Netdata
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/linpc/luci-app-netdata
sed -i 's/"status"/"system"/g' package/linpc/luci-app-netdata/luasrc/controller/*.lua
sed -i 's/"status"/"system"/g' package/linpc/luci-app-netdata/luasrc/model/cgi/*.lua
sed -i 's/admin\/status/admin\/system/g' package/linpc/luci-app-netdata/luasrc/view/netdata/*.htm

#mosdns
git_sparse_clone v5 https://github.com/sbwml/luci-app-mosdns luci-app-mosdns
git_sparse_clone v5 https://github.com/sbwml/luci-app-mosdns mosdns
rm -rf feeds/packages/utils/v2dat
rm -rf package/feeds/packages/v2dat
git_sparse_clone v5 https://github.com/sbwml/luci-app-mosdns v2dat

#luci-app-autotimeset
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-app-autotimeset

########依赖包########
git_sparse_clone master https://github.com/kiddin9/openwrt-packages brook
git_sparse_clone master https://github.com/kiddin9/openwrt-packages chinadns-ng
# ... 其他依赖包克隆保持不变 ...

##########################################其他设置##########################################

# 修改默认登录地址
sed -i 's/192.168.1.1/192.168.99.1/g' package/base-files/files/bin/config_generate

# 修改默认登录密码
sed -i 's/$1$eRZDGn.w$lAHe0nuYvaem61CpArhxV.//g' package/lean/default-settings/files/zzz-default-settings

# TTYD 免登录
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 添加项目地址
sed -i '/<tr><td width="33%"><%:CPU usage (%)%><\/td><td id="cpuusage">-<\/td><\/tr>/a <tr><td width="33%"><%:Github项目%><\/td><td><a href="https:\/\/github.com\/rnamoy\/OpenWrt-Build-System" target="_blank">Discuzamoy<\/a><\/td><\/tr>' package/lean/autocore/files/x86/index.htm

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改镜像源
sed -i 's#mirror.iscas.ac.cn/kernel.org#mirrors.edge.kernel.org/pub#' scripts/download.pl

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Linpc/g" package/lean/default-settings/files/zzz-default-settings

# 删除无效opkg源
sed -i '/exit 0/i sed -i "/kiddin9/d" /etc/opkg/distfeeds.conf' package/lean/default-settings/files/zzz-default-settings
sed -i '/exit 0/i sed -i "/kenzo/d" /etc/opkg/distfeeds.conf' package/lean/default-settings/files/zzz-default-settings
sed -i '/exit 0/i sed -i "/small/d" /etc/opkg/distfeeds.conf' package/lean/default-settings/files/zzz-default-settings

# 删除多余文件
sed -i '/exit 0/i\rm -f /etc/config/adguardhome\nrm -f /etc/init.d/adguardhome' package/lean/default-settings/files/zzz-default-settings

# 修复Makefile路径
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}

# 修复golang版本
mkdir -p feeds/packages/lang
rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang
chmod -R 777 feeds/packages/lang/golang
