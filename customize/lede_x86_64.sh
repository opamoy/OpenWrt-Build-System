#!/bin/bash
#=================================================
# 自定义脚本修复版
# 强制锁定工作目录到项目根目录
#=================================================
cd "$(dirname "$0")/.." || { echo "无法进入项目目录"; exit 1; }

########################################## 添加额外包 ##########################################
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  echo "正在克隆仓库: $repourl (分支: $branch)"
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repouru || { echo "克隆失败: $repourl"; exit 1; }
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd "$repodir" || exit 1
  git sparse-checkout set "$@" || { echo "设置稀疏检出失败"; exit 1; }
  mkdir -p ../package/linpc
  mv -f "$@" ../package/linpc || { echo "移动文件失败"; ls -l; exit 1; }
  cd .. && rm -rf "$repodir"
}

# 创建目录并清理冲突包
mkdir -p package/linpc
rm -rf feeds/packages/net/mosdns
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata

# luci-theme-argone
git_sparse_clone main https://github.com/kenzok8/small-package luci-theme-argone luci-app-argone-config

# luci-app-store 依赖
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-lib-taskd luci-lib-xterm taskd

# 科学上网插件
git_sparse_clone master https://github.com/kiddin9/openwrt-packages luci-app-openclash luci-app-passwall luci-app-ssr-plus

# Netdata
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/linpc/luci-app-netdata
if [ -d "package/linpc/luci-app-netdata" ]; then
  sed -i 's/"status"/"system"/g' package/linpc/luci-app-netdata/luasrc/controller/*.lua
  sed -i 's/"status"/"system"/g' package/linpc/luci-app-netdata/luasrc/model/cgi/*.lua
  sed -i 's/admin\/status/admin\/system/g' package/linpc/luci-app-netdata/luasrc/view/netdata/*.htm
else
  echo "警告: luci-app-netdata 未成功克隆"
fi

# Mosdns
git_sparse_clone v5 https://github.com/sbwml/luci-app-mosdns luci-app-mosdns mosdns
rm -rf feeds/packages/utils/v2dat
rm -rf package/feeds/packages/v2dat
git_sparse_clone v5 https://github.com/sbwml/luci-app-mosdns v2dat

########################################## 系统设置 ##########################################
# 修改默认登录地址
CONFIG_GENERATE="package/base-files/files/bin/config_generate"
if [ -f "$CONFIG_GENERATE" ]; then
  sed -i 's/192.168.1.1/192.168.99.1/g' "$CONFIG_GENERATE"
else
  echo "错误: $CONFIG_GENERATE 不存在"
  exit 1
fi

# 修改默认密码
ZZZ_SETTINGS="package/lean/default-settings/files/zzz-default-settings"
if [ -f "$ZZZ_SETTINGS" ]; then
  sed -i 's/$1$eRZDGn.w$lAHe0nuYvaem61CpArhxV.//g' "$ZZZ_SETTINGS"
else
  echo "警告: $ZZZ_SETTINGS 不存在"
fi

# TTYD 免登录
TTYD_CONFIG="feeds/packages/utils/ttyd/files/ttyd.config"
if [ -f "$TTYD_CONFIG" ]; then
  sed -i 's|/bin/login|/bin/login -f root|g' "$TTYD_CONFIG"
else
  echo "警告: $TTYD_CONFIG 未找到"
fi

# 添加项目地址到状态页
INDEX_HTML="package/lean/autocore/files/x86/index.htm"
if [ -f "$INDEX_HTML" ]; then
  sed -i '/<tr><td width="33%"><%:CPU usage (%)%><\/td><td id="cpuusage">-<\/td><\/tr>/a <tr><td width="33%"><%:Github项目%><\/td><td><a href="https:\/\/github.com\/rnamoy\/OpenWrt-Build-System" target="_blank">Discuzamoy<\/a><\/td><\/tr>' "$INDEX_HTML"
else
  echo "警告: $INDEX_HTML 未找到"
fi

# 修改镜像源
DOWNLOAD_PL="scripts/download.pl"
if [ -f "$DOWNLOAD_PL" ]; then
  sed -i 's#mirror.iscas.ac.cn/kernel.org#mirrors.edge.kernel.org/pub#' "$DOWNLOAD_PL"
else
  echo "错误: $DOWNLOAD_PL 不存在"
  exit 1
fi

# 其他修复
mkdir -p feeds/packages/lang
rm -rf feeds/packages/lang/golang
git clone https://github.com/kenzok8/golang feeds/packages/lang/golang
chmod -R 755 feeds/packages/lang/golang

echo "所有自定义操作已完成"
