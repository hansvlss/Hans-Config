cat << 'EOF' > hans_init.sh && chmod +x hans_init.sh && ./hans_init.sh
#!/bin/bash
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}           HansCN 2026 容器网络初始化 (版本校验版)            ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 1. 强制清理环境
rm -f /etc/apt/apt.conf.d/88proxy
rm -f install.sh
unset http_proxy
unset https_proxy

# 2. 自动检测外网
echo -e "${YELLOW}正在检测当前网络连通性...${NC}"
if timeout 2 bash -c "</dev/tcp/www.google.com/443" 2>/dev/null; then
    echo -e "${GREEN}[OK] 环境已具备外网能力。${NC}"
else
    # 3. 交互式代理配置
    while true; do
        echo -e "${YELLOW}[!] 无法访问外网，请输入旁路由配置：${NC}"
        echo -ne "${BOLD_GREEN}旁路由 IP: ${NC}"
        read USER_IP
        [ -z "$USER_IP" ] && continue
        echo -ne "${BOLD_GREEN}代理端口 [7890]: ${NC}"
        read USER_PORT
        USER_PORT=${USER_PORT:-7890}

        if timeout 2 bash -c "</dev/tcp/${USER_IP}/${USER_PORT}" 2>/dev/null; then
            PROXY_URL="http://${USER_IP}:${USER_PORT}"
            export http_proxy="${PROXY_URL}"
            export https_proxy="${PROXY_URL}"
            echo "Acquire::http::Proxy \"${PROXY_URL}\";" > /etc/apt/apt.conf.d/88proxy
            
            apt-get update > /dev/null 2>&1
            apt-get install -y curl ca-certificates > /dev/null 2>&1
            
            if curl -I -x "${PROXY_URL}" https://www.google.com --connect-timeout 5 > /dev/null 2>&1; then
                echo -e "${GREEN}[OK] 代理验证通过！${NC}"
                break
            fi
        fi
        echo -e "${RED}[错误] 代理不可用，请重新输入！${NC}"
    done
fi

# 4. 强制获取最新核心脚本 (物理破缓存)
echo -e "\n${GREEN}正在从 GitHub 同步最新 HansCN 核心程序...${NC}"

# 构造破缓存参数组合
CURL_PROXY_CMD=""
[ -n "$PROXY_URL" ] && CURL_PROXY_CMD="-x ${PROXY_URL}"

# 终极请求头：禁用所有缓存策略
curl -sSL -k ${CURL_PROXY_CMD} \
    -H "Pragma: no-cache" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "If-None-Match: \"\"" \
    "https://raw.githubusercontent.com/hansvlss/Hans-Config/main/OpenClaw/install.sh?t=$(date +%s%N)" \
    -o install.sh

# 5. 核心：版本指纹实时校验
if [ -s "install.sh" ]; then
    # 尝试从脚本前 10 行抓取 Hans_Version 关键字
    REMOTE_VER=$(grep -m 1 "Hans_Version" install.sh | awk -F': ' '{print $2}' | xargs)
    
    echo -e "${GREEN}--------------------------------------------------------------${NC}"
    echo -e "${BOLD_GREEN}成功获取远程脚本！${NC}"
    echo -e "${BOLD_GREEN}脚本快照版本: ${YELLOW}${REMOTE_VER:-"未标注版本 (请在源码添加 Hans_Version)"}${NC}"
    echo -e "${BOLD_GREEN}下载时间: ${NC}$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}--------------------------------------------------------------${NC}"
    
    chmod +x install.sh
    # 显式透传变量并执行
    http_proxy="${PROXY_URL}" https_proxy="${PROXY_URL}" bash install.sh
else
    echo -e "${RED}[失败] 脚本下载失败，请检查 GitHub 连通性！${NC}"
fi
EOF
