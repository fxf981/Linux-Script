#!/bin/bash

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请使用root用户或通过sudo运行此脚本。"
    exit 1
fi

# 交互式输入
read -p "请输入要放行的端口号 (默认: 2222): " PORT
PORT=${PORT:-2222}
read -p "请输入协议类型 [tcp/udp] (默认: tcp): " PROTOCOL
PROTOCOL=${PROTOCOL:-tcp}
PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')

# 检查端口和协议合法性
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "错误：端口号必须为1-65535之间的整数。"
    exit 1
fi
if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
    echo "错误：协议必须是 'tcp' 或 'udp'。"
    exit 1
fi

# 获取REJECT规则行号（调整优先级）
REJECT_LINE=$(iptables -L INPUT -n --line-numbers | grep -m 1 "REJECT" | awk '{print $1}')
if [ -n "$REJECT_LINE" ]; then
    INSERT_LINE=$((REJECT_LINE))
else
    INSERT_LINE=1
fi

# 放行IPv4
echo "放行 IPv4 -> ${PROTOCOL^^} 端口 $PORT..."
iptables -I INPUT "$INSERT_LINE" -p "$PROTOCOL" --dport "$PORT" -j ACCEPT

# 放行IPv6（如果ip6tables存在）
if command -v ip6tables &> /dev/null; then
    echo "放行 IPv6 -> ${PROTOCOL^^} 端口 $PORT..."
    ip6tables -I INPUT "$INSERT_LINE" -p "$PROTOCOL" --dport "$PORT" -j ACCEPT
else
    echo "警告：未找到 ip6tables，IPv6 规则未添加。"
fi

# 保存规则（持久化）
read -p "是否保存规则以便重启后生效？ [y/n] (默认: y): " SAVE
SAVE=${SAVE:-y}
if [[ "$SAVE" =~ ^[Yy]$ ]]; then
    echo "保存 iptables (IPv4) 规则..."
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables

    if command -v ip6tables &> /dev/null; then
        echo "保存 ip6tables (IPv6) 规则..."
        ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || ip6tables-save > /etc/sysconfig/ip6tables
    fi
fi

# 显示结果
echo -e "\n当前 IPv4 规则："
iptables -L INPUT -n --line-numbers | grep -P --color "($PORT|$PROTOCOL|REJECT)"

if command -v ip6tables &> /dev/null; then
    echo -e "\n当前 IPv6 规则："
    ip6tables -L INPUT -n --line-numbers | grep -P --color "($PORT|$PROTOCOL|REJECT)"
fi

echo -e "\n操作完成！"
exit 0