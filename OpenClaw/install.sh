#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== HansCN 官方模式：全自动通关版 ===${NC}"
cat <<DNS > /etc/resolv.conf
nameserver 223.5.5.5
nameserver 8.8.8.8
DNS

# 3. 核心环境变量 (解决截图中的 Corepack 提问与 Git 超时)
export COREPACK_ENABLE_AUTO_PIN=0
git config --global http.postBuffer 524288000
git config --global core.compression 0

# 4. 运行官方安装程序 (使用浅克隆加速)
echo -e "${GREEN}[2/5]${NC} 启动官方安装脚本..."
# 先拉取脚本，修改其中 git clone 逻辑为 --depth 1 以防 EOF 报错
curl -fsSL -k -x "$PROXY_URL" https://openclaw.ai/install.sh > temp_install.sh
sed -i 's/git clone/git clone --depth 1/g' temp_install.sh 

bash temp_install.sh --install-method git || { echo "安装失败，请检查节点"; exit 1; }

# 5. 注入 8888 协议补丁
echo -e "${GREEN}[3/5]${NC} 正在注入 WebSocket 优化补丁..."
apt-get install -y caddy > /dev/null 2>&1 || true
cat <<CONF > Caddyfile
:8888 {
    reverse_proxy 127.0.0.1:18789 {
        header_up Connection "upgrade"
        header_up Upgrade "websocket"
    }
}
CONF
killall caddy 2>/dev/null || true
nohup caddy run --config Caddyfile > /dev/null 2>&1 &

# 6. 完成部署
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "\n${GREEN}==============================================${NC}"
echo -e "🎉 部署圆满成功！"
echo -e "----------------------------------------------"
echo -e "Web端配对地址: ${GREEN}ws://${LOCAL_IP}:8888${NC}"
echo -e "请进入目录授权: ${YELLOW}cd openclaw && node index.js pairing approve main --all${NC}"
echo -e "==============================================${NC}"
rm -f temp_install.sh
