#!/bin/bash

# SWAP_SIZE_GB=2 && SWAPFILE=/swapfile && echo "[+] 创建 $SWAP_SIZE_GB GB 的 Swap 文件..." && (fallocate -l ${SWAP_SIZE_GB}G $SWAPFILE 2>/dev/null || dd if=/dev/zero of=$SWAPFILE bs=1M count=$(($SWAP_SIZE_GB * 1024))) && chmod 600 $SWAPFILE && mkswap $SWAPFILE && swapon $SWAPFILE && grep -q "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab && sysctl -w vm.swappiness=10 && grep -q "vm.swappiness" /etc/sysctl.conf || echo "vm.swappiness=10" >> /etc/sysctl.conf && echo "[✓] Swap 设置完成：" && swapon --show && free -h


# 设置 Swap 大小（单位 GB）
SWAP_SIZE_GB=2
SWAPFILE=/swapfile

echo "[+] 创建 $SWAP_SIZE_GB GB 的 Swap 文件..."

# 创建 Swap 文件
fallocate -l ${SWAP_SIZE_GB}G $SWAPFILE 2>/dev/null || dd if=/dev/zero of=$SWAPFILE bs=1M count=$(($SWAP_SIZE_GB * 1024))

# 设置权限
chmod 600 $SWAPFILE

# 格式化为 swap
mkswap $SWAPFILE

# 启用 swap
swapon $SWAPFILE

# 写入 /etc/fstab 以便开机自动挂载（避免重复写入）
if ! grep -q "$SWAPFILE" /etc/fstab; then
  echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
fi

# 设置 swappiness
sysctl -w vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
  echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

echo "[✓] Swap 设置完成："
swapon --show
free -h
