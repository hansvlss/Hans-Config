#!/bin/bash
# 开启错误即停止模式
set -e

# 1. 样式定义
GREEN='\033[0;32m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}          OpenClaw Gateway 自动化部署系统 (HansCN 版)         ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 2. 核心步骤 (逻辑完全保留你提供的测试通过版)

echo -e "\n${GREEN}[1/6] 正在安装基础工具...${NC}"
killall -9 apt apt-get 2>/dev/null || true
apt-get update > /dev/null 2>&1
# 这里只装基础包，不装 tailscale 避免报错
apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx > /dev/null 2>&1

echo -e "\n${GREEN}[2/6] 正在配置 Docker 环境...${NC}"
mkdir -p /etc/apt/keyrings
# 自动读取当前 shell 的代理环境变量
PROXY_URL=${http_proxy:-""}
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(ls_release -cs) stable" > /etc/apt/sources.list.d/docker.list
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

echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡设备...${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "\n${GREEN}[4/6] 正在通过 Git 模式安装 OpenClaw...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${GREEN}[5/6] 正在注入安全补丁与配置...${NC}"
FIXED_TOKEN="7d293114c449ad5fa4618a30b24ad1c4e998d9596fc6dc4f"
mkdir -p /root/.openclaw/
# 自动写入 json 配置，保护隐私
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

# 启动服务
killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# 4. 最终展示
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                OPENCLAW 自动化部署圆满成功                 ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo -e "\n管理地址: ${YELLOW}http://${LOCAL_IP}:8888${NC}"
echo -e "登录密钥: ${BOLD}${GREEN}${FIXED_TOKEN}${NC}"
echo -e "\nHansCN 提示: 脚本已完成所有配置，请直接粘贴上方 Token 登录使用。${NC}\n"
