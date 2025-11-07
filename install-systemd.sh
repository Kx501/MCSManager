#!/bin/bash

###############################################################################
# MCSManager Systemd 服务安装脚本
# 用于将 MCSManager 安装为系统服务
###############################################################################

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "请使用 sudo 运行此脚本"
        exit 1
    fi
}

# 检查部署目录是否存在
check_deploy_dir() {
    DEPLOY_DIR="/opt/mcsmanager"
    if [ ! -d "$DEPLOY_DIR" ]; then
        print_error "部署目录不存在: $DEPLOY_DIR"
        print_info "请先运行 deploy-linux-amd64.sh 进行部署"
        exit 1
    fi
    
    if [ ! -f "$DEPLOY_DIR/daemon/app.js" ]; then
        print_error "守护进程文件不存在: $DEPLOY_DIR/daemon/app.js"
        exit 1
    fi
    
    if [ ! -f "$DEPLOY_DIR/web/app.js" ]; then
        print_error "Web 面板文件不存在: $DEPLOY_DIR/web/app.js"
        exit 1
    fi
}

# 获取运行用户
get_service_user() {
    # 获取部署目录的所有者
    DEPLOY_DIR="/opt/mcsmanager"
    SERVICE_USER=$(stat -c '%U' "$DEPLOY_DIR" 2>/dev/null || echo "")
    
    if [ -z "$SERVICE_USER" ] || [ "$SERVICE_USER" == "root" ]; then
        # 如果没有找到合适的用户，询问用户
        print_warn "无法自动检测运行用户，请手动输入"
        read -p "请输入运行服务的用户名（默认: $(whoami)）: " input_user
        SERVICE_USER=${input_user:-$(whoami)}
    fi
    
    # 检查用户是否存在
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_error "用户不存在: $SERVICE_USER"
        exit 1
    fi
    
    print_info "服务运行用户: $SERVICE_USER"
}

# 检查 Node.js 路径
get_node_path() {
    if command -v node &> /dev/null; then
        NODE_PATH=$(which node)
        print_info "检测到 Node.js 路径: $NODE_PATH"
    else
        print_error "未找到 Node.js，请先安装 Node.js"
        exit 1
    fi
}

# 安装服务
install_service() {
    SERVICE_USER=$1
    NODE_PATH=$2
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    print_info "正在安装 systemd 服务..."
    
    # 复制服务文件
    DAEMON_SERVICE="/etc/systemd/system/mcsm-daemon.service"
    WEB_SERVICE="/etc/systemd/system/mcsm-web.service"
    
    # 获取用户组
    SERVICE_GROUP=$(id -gn "$SERVICE_USER")
    
    # 创建守护进程服务文件
    print_info "创建守护进程服务..."
    sed "s|USER_PLACEHOLDER|$SERVICE_USER|g" "$SCRIPT_DIR/systemd/mcsm-daemon.service" | \
    sed "s|GROUP_PLACEHOLDER|$SERVICE_GROUP|g" | \
    sed "s|/usr/bin/node|$NODE_PATH|g" > "$DAEMON_SERVICE"
    
    # 创建 Web 服务文件
    print_info "创建 Web 面板服务..."
    sed "s|USER_PLACEHOLDER|$SERVICE_USER|g" "$SCRIPT_DIR/systemd/mcsm-web.service" | \
    sed "s|GROUP_PLACEHOLDER|$SERVICE_GROUP|g" | \
    sed "s|/usr/bin/node|$NODE_PATH|g" > "$WEB_SERVICE"
    
    # 设置权限
    chmod 644 "$DAEMON_SERVICE"
    chmod 644 "$WEB_SERVICE"
    
    # 设置部署目录权限
    DEPLOY_DIR="/opt/mcsmanager"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$DEPLOY_DIR"
    
    # 重新加载 systemd
    print_info "重新加载 systemd..."
    systemctl daemon-reload
    
    # 启用服务（开机自启）
    print_info "启用服务（开机自启）..."
    systemctl enable mcsm-daemon.service
    systemctl enable mcsm-web.service
    
    print_info "服务安装完成！"
    echo ""
    print_info "服务管理命令："
    echo "  启动服务:"
    echo "    sudo systemctl start mcsm-daemon"
    echo "    sudo systemctl start mcsm-web"
    echo ""
    echo "  停止服务:"
    echo "    sudo systemctl stop mcsm-daemon"
    echo "    sudo systemctl stop mcsm-web"
    echo ""
    echo "  查看状态:"
    echo "    sudo systemctl status mcsm-daemon"
    echo "    sudo systemctl status mcsm-web"
    echo ""
    echo "  查看日志:"
    echo "    sudo journalctl -u mcsm-daemon -f"
    echo "    sudo journalctl -u mcsm-web -f"
    echo ""
    print_warn "服务已启用但尚未启动，请使用以下命令启动："
    echo "  sudo systemctl start mcsm-daemon mcsm-web"
}

# 主函数
main() {
    print_info "=========================================="
    print_info "MCSManager Systemd 服务安装"
    print_info "=========================================="
    echo ""
    
    check_root
    check_deploy_dir
    get_service_user
    get_node_path
    
    echo ""
    print_warn "即将安装以下服务："
    print_info "  - mcsm-daemon.service (守护进程)"
    print_info "  - mcsm-web.service (Web 面板)"
    print_info "  运行用户: $SERVICE_USER"
    print_info "  Node.js 路径: $NODE_PATH"
    echo ""
    
    read -p "确认安装？(y/n): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "已取消安装"
        exit 0
    fi
    
    install_service "$SERVICE_USER" "$NODE_PATH"
    
    print_info "=========================================="
    print_info "安装完成！"
    print_info "=========================================="
}

main

