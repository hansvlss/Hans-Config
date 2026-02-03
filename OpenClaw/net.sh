cat << 'EOF' > hans_init.sh && chmod +x hans_init.sh && ./hans_init.sh
#!/bin/bash

# --- 经典绿色加粗定义 ---
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}           HansCN 2026 容器网络预处理 (经典视觉版)            ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 定义验证函数：如果系统没 curl 就返回失败
check_google() {
    if ! command -v curl &> /dev/null; then return 1; fi
    curl -I -s --connect-timeout 3 https://www.google.com > /dev/null
    return $?
}

# 1. 启动时先自动验证一次
echo -e "${YELLOW}正在检测当前网络状态...${NC}"
if check_google; then
    echo -e "${GREEN}[OK] 检测到当前环境已具备外网能力，无需配置。${NC}"
else
    # 2. 自动验证失败，进入经典绿色交互区
    while true; do
        echo -e "${YELLOW}[!] 无法访问外网，请配置代理：${NC}"
        
        echo -ne "${BOLD_GREEN}请输入旁路由 IP (例如 192.168.1.30): ${NC}"
        read USER_IP
        if [ -z "$USER_IP" ]; then continue; fi

        echo -ne "${BOLD_GREEN}请输入代理端口 [默认 7890]: ${NC}"
        read USER_PORT
        USER_PORT=${USER_PORT:-7890}

        # 设置临时代理环境变量
        export http_proxy="http://${USER_IP}:${USER_PORT}"
        export https_proxy="http://${USER_IP}:${USER_PORT}"

        echo -e "\n${YELLOW}正在通过代理安装验证工具 (curl)...${NC}"
        
        # 先解决 curl 缺失问题
        if apt-get update -y && apt-get install -y curl; then
            echo -e "${GREEN}[OK] 工具补全成功，正在进行最终网络握手...${NC}"
            
            # 使用你要求的显式代理命令验证
            if curl -I -x "http://${USER_IP}:${USER_PORT}" https://www.google.com --connect-timeout 5 > /dev/null 2>&1; then
                echo -e "${GREEN}[OK] 验证通过！代理运行正常。${NC}"
                break
            else
                echo -e "${RED}[失败] 代理连接 Google 超时，请检查魔法开关！${NC}"
                unset http_proxy; unset https_proxy
            fi
        else
            echo -e "${RED}[失败] 无法通过该代理连接 Debian 源，请检查 IP 和端口！${NC}"
            unset http_proxy; unset https_proxy
        fi
EOFl -sSL -k -H "Cache-Control: no-cache" "https://raw.githubusercontent.com/hansvlss/Hans-Config/main/OpenClaw/install.sh?$(date +%s)" -o install.sh && ./install.sh
