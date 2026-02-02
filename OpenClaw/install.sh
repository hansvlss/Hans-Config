#!/bin/bash
set -e

# 1. 颜色与样式定义 (保持 HansCN 经典绿风格)
GREEN='\033[0;32m'
BOLD='\033[1m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 2. 部署标题
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}          OpenClaw Gateway 自动化部署系统 (HansCN 版)         ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 3. 核心安装步骤 [1/6 - 6/6]
echo -e "\n${GREEN}[1/6] 正在初始化系统组件并安装基础工具...${NC}"
killall -9 apt apt-get 2>/dev/null || true
apt-get update > /dev/null && apt-get install -y curl net-tools gnupg2 lsb-release psmisc nginx tailscale > /dev/null 2>&1

echo -e "\n${GREEN}[2/6] 正在配置 Docker 容器环境...${NC}"
mkdir -p /etc/apt/keyrings
# 探测当前是否已有代理环境变量
PROXY_URL=${http_proxy:-""}
curl -fsSL -k ${PROXY_URL:+ -x $PROXY_URL} https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(ls_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt-get update > /dev/null 2>&1
apt-get install -y docker-ce docker-ce-cli containerd.io > /dev/null 2>&1

# 如果存在代理，自动配置 Docker 代理加速
if [ -n "$PROXY_URL" ]; then
    mkdir -p /etc/systemd/system/docker.service.d
    cat <<CONF > /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$PROXY_URL"
Environment="HTTPS_PROXY=$PROXY_URL"
CONF
    systemctl daemon-reload && systemctl restart docker
fi

echo -e "\n${GREEN}[3/6] 正在激活 LXC 虚拟网卡设备 (Tailscale)...${NC}"
mkdir -p /var/run/tailscale /var/lib/tailscale
export PATH=$PATH:/usr/sbin:/sbin
nohup tailscaled --state=/var/lib/tailscale/tailscaled.state --socket=/var/run/tailscale/tailscaled.sock > /dev/null 2>&1 &
sleep 2 && tailscale up --accept-dns=false || true

echo -e "\n${GREEN}[4/6] 正在同步 OpenClaw 官方核心源码 (Git 模式)...${NC}"
export COREPACK_ENABLE_AUTO_PIN=0
curl -fsSL -k https://openclaw.ai/install.sh | bash -s -- --install-method git

echo -e "\n${GREEN}[5/6] 正在注入安全补丁与信任代理配置...${NC}"
# 隐私信息锁在脚本内部
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

echo -e "\n${GREEN}[6/6] 正在配置 Nginx 8888 端口转发隧道...${NC}"
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

# 启动服务并清理进程
killall -9 openclaw 2>/dev/null || true
nohup /root/.local/bin/openclaw gateway > /root/openclaw.log 2>&1 &

# 最终杀青界面
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n\n${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║                OPENCLAW 自动化部署圆满成功                 ║${NC}"
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BOLD}➤ 第一步：${NC}在浏览器打开地址: ${YELLOW}http://${LOCAL_IP}:8888${NC}"
echo -e "${BOLD}➤ 第二步：${NC}复制下方 Token 登录 Web 界面："
echo -e "${BOLD}${GREEN}------------------------------------------------------------${NC}"
echo -e "${BOLD}${YELLOW}${FIXED_TOKEN}${NC}"
echo -e "${BOLD}${GREEN}------------------------------------------------------------${NC}"

echo -e "\n${GREEN}HansCN 提醒: 请妥善保存上方 Token，这是你管理 OpenClaw 的唯一凭证！${NC}\n"
