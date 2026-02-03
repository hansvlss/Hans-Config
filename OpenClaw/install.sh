#!/bin/bash
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

clear
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}${WHITE}OpenClaw Gateway${NC} ${GREEN}自动化部署系统${NC} ${YELLOW}v2026 Pro${NC}        ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"

# 1. 诊断与代理注入
echo -e "${INFO} ${BOLD}系统诊断中...${NC}"
echo -e "  ➤ 代理状态: ${GREEN}${http_proxy:-"已继承本地设置"}${NC}"
if [ -n "$http_proxy" ]; then
    echo "Acquire::http::Proxy \"$http_proxy\";" > /etc/apt/apt.conf.d/88proxy
fi

# 2. 核心安装 (恢复滚动过程)
echo -e "\n${BOLD}${CYAN}Step 1/6: 基础工具同步 (滚动模式)${NC}"
killall -9 apt apt-get 2>/dev/null || true
apt-get update
apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx

echo -e "\n${BOLD}${CYAN}Step 2/6: Docker 引擎配置${NC}"
mkdir -p /etc/apt/keyrings
PROXY_URL=${http_proxy:-""}
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

echo -e "\n${BOLD}${CYAN}Step 3/6: LXC 虚拟网卡激活${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "\n${BOLD}${CYAN}Step 4/6: OpenClaw 核心部署${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${BOLD}${CYAN}Step 5/6: 安全补丁注入${NC}"
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

echo -e "\n${BOLD}${CYAN}Step 6/6: 网络服务路由${NC}"
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

# 3. 修正后的 IP 获取与最终展示
REAL_IP=$(hostname -I | awk '{for(i=1;i<=NF;i++) if($i != "127.0.0.1" && $i !~ /^172\./) {print $i; exit}}')

echo -e "\n${CYAN}--------------------------------------------------------------${NC}"
echo -e "${BOLD}${GREEN}        🎉 OPENCLAW 自动化部署圆满成功！${NC}"
echo -e "\n  ${BOLD}管理地址: ${NC}${YELLOW}http://${REAL_IP:-$HOSTNAME}:8888${NC}"
echo -e "  ${BOLD}登录密钥: ${NC}${BOLD}${WHITE}${FIXED_TOKEN}${NC}"
echo -e "\n${CYAN}  HansCN 提示: 部署已完成，请直接粘贴上方 Token 登录使用。${NC}"
echo -e "${CYAN}--------------------------------------------------------------${NC}"

rm -f /etc/apt/apt.conf.d/88proxy
rm -f $0
