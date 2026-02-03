cat << 'EOF' > hans_init.sh && chmod +x hans_init.sh && ./hans_init.sh
#!/bin/bash
GREEN='\033[0;32m'
BOLD_GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${GREEN}==============================================================${NC}"
echo -e "${GREEN}           HansCN 2026 容器网络初始化 (智能检测版)            ${NC}"
echo -e "${GREEN}==============================================================${NC}"

# 1. 强制清理历史残留，确保检测环境纯净
rm -f /etc/apt/apt.conf.d/88proxy
unset http_proxy
unset https_proxy

# 2. 前置自动检测：利用系统底层探测 Google 443 端口
echo -e "${YELLOW}正在检测当前网络连通性...${NC}"
if timeout 2 bash -c "</dev/tcp/www.google.com/443" 2>/dev/null; then
    echo -e "${GREEN}[OK] 检测到当前环境已具备外网能力，无需手动配置。${NC}"
else
    # 3. 自动检测失败，才进入经典绿色交互区
    while true; do
        echo -e "${YELLOW}[!] 无法访问外网，请按照提示配置代理：${NC}"
        
        echo -ne "${BOLD_GREEN}请输入旁路由 IP (例如 192.168.1.30): ${NC}"
        read USER_IP
        [ -z "$USER_IP" ] && continue
        
        echo -ne "${BOLD_GREEN}请输入代理端口 [默认 7890]: ${NC}"
        read USER_PORT
        USER_PORT=${USER_PORT:-7890}

        # 验证旁路由物理连通性
        echo -e "${YELLOW}正在验证与旁路由 ${USER_IP}:${USER_PORT} 的物理连接...${NC}"
        if timeout 2 bash -c "</dev/tcp/${USER_IP}/${USER_PORT}" 2>/dev/null; then
            echo -e "${GREEN}[OK] 物理连接成功！正在注入配置并补全工具...${NC}"
            
            # 注入代理配置
            export http_proxy="http://${USER_IP}:${USER_PORT}"
            export https_proxy="http://${USER_IP}:${USER_PORT}"
            echo "Acquire::http::Proxy \"http://${USER_IP}:${USER_PORT}\";" > /etc/apt/apt.conf.d/88proxy
            
            # 安装 curl 并进行最终验证
            if apt-get update && apt-get install -y curl; then
                echo -e "${GREEN}[OK] curl 安装成功，执行最终 Google 验证...${NC}"
                if curl -I -x "http://${USER_IP}:${USER_PORT}" https://www.google.com --connect-timeout 5 > /dev/null 2>&1; then
                    echo -e "${GREEN}[OK] 验证通过！代理完全正常。${NC}"
                    break
                else
                    echo -e "${RED}[失败] 代理通了但无法访问 Google，请检查旁路由魔法配置！${NC}"
                fi
            fi
        else
            echo -e "${RED}[错误] 无法连接到 ${USER_IP}:${USER_PORT}，请检查 IP/端口！${NC}"
        fi
    done
fi

# 4. 衔接核心部署脚本
echo -e "\n${GREEN}正在获取 HansCN 核心安装程序...${NC}"
rm -f install.sh
# 确保此时 curl 已经存在
if ! command -v curl &> /dev/null; then apt-get update && apt-get install -y curl; fi
curl -sSL -k -H "Cache-Control: no-cache" "https://raw.githubusercontent.com/hansvlss/Hans-Config/main/OpenClaw/install.sh?$(date +%s)" -o install.sh
bash install.sh
EOF
