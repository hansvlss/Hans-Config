#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
# 即使报错也不要立刻退出，方便我们完成所有关键配置
set +e 

GREEN='\033[0;32m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}          OpenClaw Gateway 自动化部署系统 (HansCN 版)         ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 1. 基础工具安装 (拆分安装，确保 gpg 优先)
echo -e "\n${GREEN}[1/6] 正在安装基础依赖...${NC}"
apt-get update -y > /dev/null 2>&1
apt-get install -y curl gnupg2 ca-certificates lsb-release psmisc nginx > /dev/null 2>&1

# 2. Docker 与 Tailscale 源配置
echo -e "\n${GREEN}[2/6] 正在同步 Docker 与 Tailscale 仓库...${NC}"
mkdir -p /etc/apt/keyrings
PROXY_URL=${http_proxy:-""}

# 安装 Docker 密钥
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

# 安装 Tailscale 密钥与源
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).noarmor.gpg > /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://pkgs.tailscale.com/stable/debian/$(lsb_release -cs).tailscale-keyring.list > /etc/apt/sources.list.d/tailscale.list

# 更新源并安装剩余核心包
apt-get update -y > /dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io tailscale > /dev/null 2>&1

# 3. 激活虚拟网卡
echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡 (Tailscale)...${NC}"
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

# 4. OpenClaw 安装
echo -e "\n${GREEN}[4/6] 正在安装 OpenClaw 核心...${NC}"
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

# 5. 配置文件 (Hans 专属 Token)
echo -e "\n${GREEN}[5/6] 正在注入安全配置...${NC}"
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

# 6. Nginx 配置
echo -e "\n${GREEN}[6/6] 正在配置端口转发...${NC}"
cat > /etc/nginx/sites-enabled/default <<NGX
server {
    listen 8888;
    location / {
        proxy_pass http://127.0.0.1:18789;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
NGX
systemctl restart nginx && killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# 最终展示
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${BOLD}${GREEN}=============================================="
echo -e "🎉  部署成功！地址: http://${LOCAL_IP}:8888"
echo -e "登录密钥: ${YELLOW}${FIXED_TOKEN}${NC}"
echo -e "==============================================${NC}"
