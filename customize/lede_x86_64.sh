#!/bin/bash
set -eo pipefail
shopt -s nullglob

#=================================================
# 增强版稀疏克隆函数
# 参数：<分支> <仓库URL> [目录1 目录2 ...]
#=================================================
git_sparse_clone() {
    local branch="$1"
    local repo="$2"
    shift 2

    echo "🔄 正在克隆仓库: $repo (分支: $branch)"
    
    # 生成随机临时目录名
    local temp_dir=$(mktemp -d -p . tmp.clone.XXXXXXXXXX)
    
    git clone --depth=1 \
        --branch "$branch" \
        --filter=blob:none \
        --sparse \
        "$repo" "$temp_dir" || {
        echo "❌ 克隆失败: $repo"
        rm -rf "$temp_dir"
        return 1
    }

    (
        cd "$temp_dir"
        [ $# -gt 0 ] && git sparse-checkout set "$@"
        mkdir -p ../package/linpc
        for item in "$@"; do
            if [ -e "$item" ]; then
                mv -v "$item" ../../package/linpc/
            else
                echo "⚠️  警告: 路径 $item 不存在于仓库中"
            fi
        done
    )

    rm -rf "$temp_dir"
}

#=================================================
# 主程序开始
#=================================================
cd "$(dirname "$0")/../lede" || exit 1

echo "📂 当前工作目录: $(pwd)"
echo "🕒 开始时间: $(date)"

# 清理冲突组件
declare -a conflict_dirs=(
    "feeds/packages/net/mosdns"
    "feeds/luci/applications/luci-app-mosdns"
    "feeds/luci/applications/luci-app-netdata"
)
for dir in "${conflict_dirs[@]}"; do
    [ -d "$dir" ] && rm -rf "$dir" && echo "🗑️  已清理: $dir"
done

# 克隆必要组件
declare -A package_sources=(
    ["small-package"]="main,https://github.com/kenzok8/small-package,luci-theme-argone luci-app-argone-config"
    ["openwrt-pkgs"]="master,https://github.com/kiddin9/openwrt-packages,luci-lib-taskd luci-lib-xterm taskd"
    ["passwall"]="master,https://github.com/kiddin9/openwrt-packages,luci-app-openclash luci-app-passwall luci-app-ssr-plus"
)

for key in "${!package_sources[@]}"; do
    IFS=',' read -r branch url paths <<< "${package_sources[$key]}"
    git_sparse_clone "$branch" "$url" $paths
done

# 特殊组件处理
echo "🔧 安装特殊组件..."
git clone --depth 1 https://github.com/Jason6111/luci-app-netdata package/linpc/luci-app-netdata

#=================================================
# 系统配置修改
#=================================================
apply_patch() {
    local file="$1"
    local pattern="$2"
    local replacement="$3"

    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file"; then
            sed -i "s|$pattern|$replacement|g" "$file"
            echo "✅ 已修改: $file"
        else
            echo "⚠️  未找到匹配模式: $file -> $pattern"
        fi
    else
        echo "❌ 文件不存在: $file"
    fi
}

# 应用所有修改
declare -A config_mods=(
    ["package/base-files/files/bin/config_generate"]="192.168.1.1/192.168.99.1"
    ["feeds/packages/utils/ttyd/files/ttyd.config"]="/bin/login/-f root"
    ["package/lean/autocore/files/x86/index.htm"]="<%:CPU usage (%)%>/<%:Github项目%>"
    ["scripts/download.pl"]="mirror.iscas.ac.cn\/kernel.org/mirrors.edge.kernel.org\/pub"
)

for file in "${!config_mods[@]}"; do
    IFS='/' read -r pattern replacement <<< "${config_mods[$file]}"
    apply_patch "$file" "$pattern" "$replacement"
done

# 版本信息修改
version_file="package/lean/default-settings/files/zzz-default-settings"
if [ -f "$version_file" ]; then
    build_date=$(date +"%y.%m.%d")
    sed -i "s|DISTRIB_REVISION='.*'|DISTRIB_REVISION='R${build_date} by OpenWrtBuilder'|" "$version_file"
    echo "🔄 已更新版本信息"
else
    echo "❌ 版本文件不存在: $version_file"
fi

echo "✅ 所有自定义操作已完成"
echo "🕒 结束时间: $(date)"
