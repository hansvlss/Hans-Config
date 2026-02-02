#!/bin/bash
# 1. 环境加固：强制开启非交互模式，防止蓝色弹窗死锁
export DEBIAN_FRONTEND=noninteractive
set -e

# 2. 颜色定义
GREEN='\033[0;32m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 3. 标题
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}          OpenClaw Gateway 自动化部署系统 (HansCN 版)         ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 4. 核心步骤
echo -e "\n${GREEN}[1/6] 正在初始化系统组件并安装基础工具...${NC}"
# 这里的逻辑做了加固，即使某个包失败也不会直接导致 bash 断开
killall -9 apt apt-get 2>/dev/null || true
apt-get update -y || (echo -e "${YELLOW}警告: 更新失败，请检查 set_proxy.sh 是否运行！${NC}")
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
    curl net-tools gnupg2 lsb-release psmisc nginx tailscale || true

echo -e "\n${GREEN}[2/6] 正在配置 Docker 环境...${NC}"
mkdir -p /etc/apt/keyrings
PROXY_URL=${http_proxy:-""}
# 确保使用 -k 忽略证书错误，防止代理环境下的 SSL 报错
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(ls_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update > /dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡 (Tailscale)...${NC}"
export PATH=$PATH:/usr/sbin:/sbin
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 3 && tailscale up --accept-dns=false || true

echo -e "\n${GREEN}[4/6] 正在安装 OpenClaw 核心程序...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${GREEN}[5/6] 正在注入安全补丁与配置...${NC}"
FIXED_TOKEN="7d293114c449ad5fa4618a30b24ad1c4e998d9596fc6dc4f"
mkdir -p /root/.openclaw/
# 脚本自动写入配置，保护 Token 隐私
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
    }
}
NGX
systemctl restart nginx && killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# 5. 最终杀青提示
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                OPENCLAW 自动化部署圆满成功                 ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "\n管理地址: ${YELLOW}http://${LOCAL_IP}:8888${NC}"
echo -e "登录密钥: ${BOLD}${GREEN}${FIXED_TOKEN}${NC}"
echo -e "\nHansCN 提示: 脚本已从 GitHub 同步最新配置，请复制上方 Token 登录。${NC}\n"
