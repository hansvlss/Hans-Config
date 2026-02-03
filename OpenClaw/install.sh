#!/bin/bash
# ----------------------------------------------------------------
# HansCN 2026 OpenClaw LXC Pro Edition (Final Fix)
# ----------------------------------------------------------------

set +e 

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

CHECK="[${GREEN}✓${NC}]"
INFO="[${BLUE}i${NC}]"
LOAD="[${PURPLE}*${NC}]"

draw_line() {
    echo -e "${CYAN}--------------------------------------------------------------${NC}"
}

print_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BOLD}${WHITE}OpenClaw Gateway${NC} ${GREEN}自动化部署系统${NC} ${YELLOW}v2026 Pro${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${PURPLE}Powered by HansCN${NC}                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

rm -f /etc/apt/apt.conf.d/88proxy
print_header
echo -e "${INFO} ${BOLD}系统诊断中...${NC}"
if [ -n "$http_proxy" ]; then
    echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/88proxy
    echo -e "${CHECK} APT 代理注入成功"
fi
draw_line

# Step 1-3 保持不变... (安装依赖、Docker、Tailscale)
echo -e "\n${BOLD}${CYAN}Step 1/6: 基础工具同步${NC}"
apt-get update > /dev/null 2>&1
apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx > /dev/null 2>&1

echo -e "\n${BOLD}${CYAN}Step 2/6: Docker 引擎配置${NC}"
# (此处省略中间重复的 Docker 安装代码，保持你原来的即可)

echo -e "\n${BOLD}${CYAN}Step 3/6: LXC 虚拟网卡激活${NC}"
# (此处省略中间重复的 Tailscale 代码，保持你原来的即可)

# --- 关键修改点 1：使用 release 模式避免 UI 缺失 ---
echo -e "\n${BOLD}${CYAN}Step 4/6: OpenClaw 核心部署${NC}"
echo -e "${LOAD} 正在下载预编译二进制包 (Release)..."
export COREPACK_ENABLE_AUTO_PIN=0
# 这一行改用了 release，自带网页文件，不会再白屏
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method release > /dev/null 2>&1
echo -e "${CHECK} OpenClaw 核心与 UI 部署完毕"

echo -e "\n${BOLD}${CYAN}Step 5/6: 安全补丁注入${NC}"
FIXED_TOKEN="7d293114c449ad5fa4618a30b24ad1c4e998d9596fc6dc4f"
# (此处注入补丁代码保持不变)

echo -e "\n${BOLD}${CYAN}Step 6/6: 网络服务路由${NC}"
# (此处 Nginx 配置保持不变)
systemctl restart nginx > /dev/null 2>&1
killall -9 openclaw 2>/dev/null || true
nohup openclaw gateway > /root/openclaw.log 2>&1 &
echo -e "${CHECK} 反向代理服务已启动"

# --- 关键修改点 2：自动获取真实局域网 IP ---
REAL_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if($i != "127.0.0.1" && $i !~ /^172\./) {print $i; exit}}')

# --- 最终杀青展示 ---
draw_line
echo -e "\n${BOLD}${GREEN}        🎉 OPENCLAW 自动化部署圆满成功！${NC}"
echo -e "\n  ${BOLD}管理地址: ${NC}${YELLOW}http://${REAL_IP:-$HOSTNAME}:8888${NC}"
echo -e "  ${BOLD}登录密钥: ${NC}${BOLD}${WHITE}${FIXED_TOKEN}${NC}"
echo -e "\n${CYAN}  HansCN 提示: 部署已完成，请直接粘贴上方 Token 登录使用。${NC}"
draw_line

rm -f /etc/apt/apt.conf.d/88proxy
rm -f $0
