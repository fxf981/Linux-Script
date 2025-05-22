#!/bin/bash

# 检查是否为root用户
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请使用root用户或通过sudo运行此脚本。"
    exit 1
fi

# 交互式输入端口和协议
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

# 获取当前REJECT规则的行号（如果有）
REJECT_LINE=$(iptables -L INPUT -n --line-numbers | grep -m 1 "REJECT" | awk '{print $1}')
if [ -n "$REJECT_LINE" ]; then
    echo "检测到 REJECT 规则在行号 $REJECT_LINE，将优先插入 ACCEPT 规则..."
    INSERT_LINE=$((REJECT_LINE))
else
    INSERT_LINE=1  # 如果没有REJECT规则，插入到第一行
fi

# 插入规则到正确位置
echo "正在放行 ${PROTOCOL^^} 端口 $PORT（插入到 INPUT 链第 $INSERT_LINE 行）..."
iptables -I INPUT "$INSERT_LINE" -p "$PROTOCOL" --dport "$PORT" -j ACCEPT
if [ $? -ne 0 ]; then
    echo "错误：插入规则失败！"
    exit 1
fi

# 删除可能重复的旧规则（避免冲突）
OLD_RULES=$(iptables -L INPUT -n --line-numbers | grep -w "$PORT" | grep -v "$INSERT_LINE" | awk '{print $1}' | sort -nr)
for line in $OLD_RULES; do
    iptables -D INPUT "$line"
    echo "已删除重复的旧规则（行号 $line）。"
done

# 保存规则
read -p "是否保存规则以便重启后生效？ [y/n] (默认: y): " SAVE
SAVE=${SAVE:-y}
if [[ "$SAVE" =~ ^[Yy]$ ]]; then
    echo "正在保存iptables规则..."
    if [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4
    else
        iptables-save > /etc/sysconfig/iptables
    fi
    echo "规则已持久化。"
fi

# 验证结果
echo -e "\n当前 INPUT 链规则："
iptables -L INPUT -n --line-numbers | grep -P --color "($PORT|$PROTOCOL|REJECT)"
echo -e "\n状态：${PROTOCOL^^} 端口 $PORT 已放行！"

exit 0