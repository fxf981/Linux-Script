#!/bin/bash

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "错误：请使用 root 用户或通过 sudo 运行此脚本。"
    exit 1
fi

# 交互式输入
read -p "请输入要放行的端口号 (默认: 2222): " PORT
PORT=${PORT:-2222}
read -p "请输入协议类型 [tcp/udp] (默认: tcp): " PROTOCOL
PROTOCOL=${PROTOCOL:-tcp}
PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')

# 校验端口和协议
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    echo "错误：端口号必须为 1~65535 之间的整数。"
    exit 1
fi
if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
    echo "错误：协议必须是 tcp 或 udp。"
    exit 1
fi

# 获取 IPv4 REJECT 插入位置
REJECT_LINE=$(iptables -L INPUT -n --line-numbers | grep -m 1 "REJECT" | awk '{print $1}')
INSERT_LINE=${REJECT_LINE:-1}

# 放行 IPv4
echo "放行 IPv4 -> ${PROTOCOL^^} 端口 $PORT..."
iptables -I INPUT "$INSERT_LINE" -p "$PROTOCOL" --dport "$PORT" -j ACCEPT

# 是否保存规则
read -p "是否保存规则以便重启后生效？ [y/n] (默认: y): " SAVE
SAVE=${SAVE:-y}
if [[ "$SAVE" =~ ^[Yy]$ ]]; then
    echo "保存 iptables (IPv4) 规则..."
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/sysconfig/iptables
fi

# 修改 sshd_config 添加端口（仅 tcp）
if [[ "$PROTOCOL" == "tcp" ]]; then
    if ! grep -q "^Port $PORT" /etc/ssh/sshd_config; then
        echo "添加 SSH 端口 $PORT 到 /etc/ssh/sshd_config..."
        echo "" >> /etc/ssh/sshd_config
        echo "Port $PORT" >> /etc/ssh/sshd_config
    else
        echo "SSH 配置中已包含 Port $PORT，无需修改。"
    fi
fi

# 重启 SSH 服务
read -p "是否现在重启 SSH 服务？[y/n] (默认: y): " RESTART_SSH
RESTART_SSH=${RESTART_SSH:-y}
if [[ "$RESTART_SSH" =~ ^[Yy]$ ]]; then
    if systemctl list-unit-files | grep -q sshd.service; then
        echo "正在重启 sshd..."
        systemctl restart sshd && echo "SSHD 重启完成。" || echo "SSHD 重启失败。"
    elif systemctl list-unit-files | grep -q ssh.service; then
        echo "正在重启 ssh..."
        systemctl restart ssh && echo "SSH 重启完成。" || echo "SSH 重启失败。"
    else
        echo "未检测到 SSH 服务，跳过重启。"
    fi
fi

# 显示当前规则
echo -e "\n当前 IPv4 规则："
iptables -L INPUT -n --line-numbers | grep -P --color "($PORT|$PROTOCOL|REJECT)"

# 检查监听状态
echo -e "\n正在检查端口监听状态："
ss -ntlp | grep ":$PORT" || echo "未监听端口 $PORT，请检查 SSH 配置或服务状态。"

echo -e "\n操作完成！"
exit 0
