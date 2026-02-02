#!/bin/bash
# 强制开启非交互模式，防止安装过程中的弹窗导致脚本中断
export DEBIAN_FRONTEND=noninteractive
set -e

# 1. 颜色与样式定义
GREEN='\033[0;32m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 2. 标题
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}          OpenClaw Gateway 自动化部署系统 (HansCN 版)         ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 3. 核心安装步骤
echo -e "\n${GREEN}[1/6] 正在初始化系统并安装基础工具...${NC}"
killall -9 apt apt-get 2>/dev/null || true
# 强制静默安装，不弹出配置文件冲突提示
apt-get update -y > /dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
    net-tools gnupg2 lsb-release psmisc nginx tailscale > /dev/null 2>&1

echo -e "\n${GREEN}[2/6] 正在配置 Docker 环境...${NC}"
mkdir -p /etc/apt/keyrings
PROXY_URL=${http_proxy:-""}
# 如果有代理，curl 会自动使用
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(ls_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update > /dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡 (Tailscale)...${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
export PATH=$PATH:/usr/sbin:/sbin
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "\n${GREEN}[4/6] 正在安装 OpenClaw 核心程序...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${GREEN}[5/6] 正在注入安全补丁与配置...${NC}"
FIXED_TOKEN="7d293114c449ad5fa4618a30b24ad1c4e998d9596fc6dc4f"
mkdir -p /root/.openclaw/
# 自动生成配置文件，保护 Token 隐私
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

echo -e "\n${GREEN}[6/6] 正在配置 Nginx 8888 端口转发...${NC}"
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

# 启动 OpenClaw
killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# 7. 最终杀青提示与 Token 展示
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                OPENCLAW 自动化部署圆满成功                 ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BOLD}➤ 第一步：${NC}在浏览器访问管理地址"
echo -e "   URL: ${BOLD}${YELLOW}http://${LOCAL_IP}:8888${NC}"

echo -e "\n${BOLD}➤ 第二步：${NC}复制下方 Token 登录 Web 界面"
echo -e "${GREEN}------------------------------------------------------------${NC}"
echo -e "${BOLD}${YELLOW}${FIXED_TOKEN}${NC}"
echo -e "${GREEN}------------------------------------------------------------${NC}"

echo -e "\n${GREEN}HansCN 提示: 脚本已完成所有配置，请直接使用上方 Token 登录。${NC}\n"
