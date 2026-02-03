cat << 'EOF' > hans_init.sh && chmod +x hans_init.sh && ./hans_init.sh
#!/bin/bash
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}           HansCN 2026 容器网络逻辑预处理 (严密版)            ${NC}"
echo -e "${GREEN}==============================================================${NC}"

echo -e "${YELLOW}正在检测原始网络连接...${NC}"
timeout 2 bash -c "</dev/tcp/www.google.com/443" 2>/dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] 原始网络已通畅，准备进入安装流程。${NC}"
else
    while true; do
        echo -e "${RED}[!] 无法直接访问外网，请配置代理以补全工具：${NC}"
        echo -ne "${BOLD_GREEN}请输入旁路由 IP (例如 192.168.1.30): ${NC}"
        read USER_IP
        [ -z "$USER_IP" ] && continue
        echo -ne "${BOLD_GREEN}请输入代理端口 [默认 7890]: ${NC}"
        read USER_PORT
        USER_PORT=${USER_PORT:-7890}

        export http_proxy="http://${USER_IP}:${USER_PORT}"
        export https_proxy="http://${USER_IP}:${USER_PORT}"

        echo -e "\n${YELLOW}正在通过代理安装验证工具 (curl)...${NC}"
        if apt-get update -y && apt-get install -y curl; then
            echo -e "${GREEN}[OK] 工具补全成功，正在执行最终代理验证...${NC}"
            if curl -I -x "http://${USER_IP}:${USER_PORT}" https://www.google.com --connect-timeout 5 > /dev/null 2>&1; then
                echo -e "${GREEN}[OK] 验证通过！代理完全正常。${NC}"
                break
            else
                echo -e "${RED}[失败] 代理可连软件源但无法访问 Google，请检查配置！${NC}"
                unset http_proxy; unset https_proxy
            fi
        else
            echo -e "${RED}[失败] 代理无法连接软件源，请检查 IP/端口！${NC}"
            unset http_proxy; unset https_proxy
        fi
    done
fi

echo -e "\n${GREEN}正在获取 HansCN 核心安装程序...${NC}"
rm -f install.sh
if ! command -v curl &> /dev/null; then apt-get update && apt-get install -y curl; fi
curl -sSL -k -H "Cache-Control: no-cache" "https://raw.githubusercontent.com/hansvlss/Hans-Config/main/OpenClaw/install.sh?$(date +%s)" -o install.sh
bash install.sh
EOF
