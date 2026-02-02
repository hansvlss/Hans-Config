#!/bin/bash
set -e
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== HansCN 2026 OpenClaw LXC 全自动通关脚本 ===${NC}"

# --- [阶段一：环境初始化与智能探测] ---
check_network() {
    curl -I -s --connect-timeout 3 -m 5 https://github.com > /dev/null
}

if check_network; then
    echo -e "${GREEN}检测到当前环境已具备出海能力，跳过代理手动配置。${NC}"
    PROXY_URL=""
else
    echo -e "${YELLOW}检测到无法直连，进入代理配置模式...${NC}"
    read -p "请输入旁路由 IP (例如 192.168.1.30): " USER_IP
    [ -z "$USER_IP" ] && { echo -e "${RED}错误：必须输入 IP！${NC}"; exit 1; }
    read -p "请输入代理端口 [7890]: " USER_PORT
    USER_PORT=${USER_PORT:-7890}
    PROXY_URL="http://${USER_IP}:${USER_PORT}"
    export http_proxy="$PROXY_URL" https_proxy="$PROXY_URL"
fi

echo -e "${GREEN}[1/6] 正在安装基础工具...${NC}"
killall -9 apt apt-get 2>/dev/null || true
apt-get update > /dev/null 2>&1
apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx > /dev/null 2>&1

echo -e "${GREEN}[2/6] 正在配置 Docker 环境...${NC}"
mkdir -p /etc/apt/keyrings
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update > /dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

if [ -n "$PROXY_URL" ]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat <<CONF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
CONF
    systemctl daemon-reload && systemctl restart docker
fi

# --- [阶段二：OpenClaw 核心部署与绿灯补丁] ---
echo -e "${GREEN}[3/6] 正在激活 LXC 虚拟网卡设备...${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "${GREEN}[4/6] 正在通过 Git 模式安装 OpenClaw...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "${GREEN}[5/6] 正在注入安全补丁与信任代理...${NC}"
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

echo -e "${GREEN}[6/6] 正在配置 Nginx 8888 端口转发...${NC}"
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

# 启动服务
killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}=============================================="
echo -e "🎉  HansCN 终极合体脚本部署成功！"
echo -e "访问地址: http://${LOCAL_IP}:8888"
echo -e "您的 Token: ${FIXED_TOKEN}"
echo -e "==============================================${NC}"
