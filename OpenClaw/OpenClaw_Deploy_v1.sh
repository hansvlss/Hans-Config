#!/bin/bash
# REAL_INSTALL_SCRIPT_V1
echo "===================================================="
echo "          HansCN 2026 核心安装程序 (v1)             "
echo "===================================================="
apt-get update && apt-get install -y curl git jq
echo "容器基础环境已就绪！"
