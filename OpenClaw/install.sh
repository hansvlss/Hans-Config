#!/bin/bash
# ----------------------------------------------------------------
# HansCN 2026 OpenClaw (滚动安装版 - 恢复进度显示)
# ----------------------------------------------------------------

set +e 

# 1. 颜色与标题
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}OpenClaw Gateway${NC} ${GREEN}自动化部署系统${NC} ${YELLOW}v2026 Pro${NC}        ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

# 2. 诊断信息
echo -e "${YELLOW}➤ 代理状态: ${http_proxy:-"未设置"}${NC}"
FREE_MEM=$(free -m | awk '/^Mem:/{print $4}')
echo -e "${YELLOW}➤ 剩余内存: ${FREE_MEM}MB${NC}\n"

# 3. 强制锁定 APT 代理
if [ -n "$http_proxy" ]; then
    echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/88proxy
fi

# --------------------------------------------------------------
# 核心步骤 (删除了 > /dev/null，你会看到所有滚动代码)
# --------------------------------------------------------------

echo -e "${GREEN}[1/6] 正在安装基础工具 (请查看下方滚动进度)...${NC}"
killall -9 apt apt-get 2>/dev/null || true
apt-get update
apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx

echo -e "\n${GREEN}[2/6] 正在配置 Docker 环境...${NC}"
mkdir -p /etc/apt/keyrings
PROXY_URL=${http_proxy:-""}
# 使用 -k 忽略证书
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

if [ -n "$PROXY_URL" ]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat <<CONF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
CONF
    systemctl daemon-reload && systemctl restart docker
fi

echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡设备...${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "\n${GREEN}[4/6] 正在安装 OpenClaw 核心...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${GREEN}[5/6] 正在注入安全补丁...${NC}"
FIXED_TOKEN="7d293114c449ad5fa4618a30b24ad1c4e998d9596fc6dc4f"
mkdir -p /root/.openclaw/
cat > /root/.openclaw/openclaw.json <<JSON
{
  "gateway": {
    "mode": "local",
    "bind": "tailnet",
    "trustedProxies": ["127.0.0.1"],
    "auth": { "token": "$FIXED_TOKEN" },
    "controlUi": { "allowInsecureAuth": true }
  }
}
JSON

echo -e "\n${GREEN}[6/6] 正在配置 Nginx 转发...${NC}"
cat > /etc/nginx/sites-enabled/default <<NGX
server {
    listen 8888;
    location / {
        proxy_pass http://127.0.0.1:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
NGX
systemctl restart nginx
killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# --- 最终杀青展示 ---
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}--------------------------------------------------------------${NC}"
echo -e "${BOLD}${GREEN}        🎉 OPENCLAW 自动化部署圆满成功！${NC}"
echo -e "\n  管理地址: ${YELLOW}http://${LOCAL_IP}:8888${NC}"
echo -e "  登录密钥: ${BOLD}${GREEN}${FIXED_TOKEN}${NC}"
echo -e "\n${CYAN}HansCN 提示: 部署已完成，请直接粘贴上方 Token 登录使用。${NC}"
echo -e "${GREEN}--------------------------------------------------------------${NC}"

# 清理
rm -f /etc/apt/apt.conf.d/88proxy
rm -f $0
