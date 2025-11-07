#!/bin/bash

###############################################################################
# MCSManager Linux AMD64 自动部署脚本
# 使用仓库: https://github.com/Kx501/MCSManager
###############################################################################

set -e  # 遇到错误立即退出

# 配置变量
REPO_URL="https://github.com/Kx501/MCSManager.git"
BUILD_DIR="/opt/mcsmanager-source"
DEPLOY_DIR="/opt/mcsmanager"
CURRENT_USER=$(whoami)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印信息函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查命令是否存在
check_command() {
    if ! command -v $1 &> /dev/null; then
        print_error "$1 未安装，请先安装 $1"
        exit 1
    fi
}

# 检查 Node.js 版本
check_nodejs() {
    if ! command -v node &> /dev/null; then
        print_error "未安装 Node.js"
        print_info "请先安装 Node.js 16.20.2 或更高版本（推荐 20.x LTS）"
        print_info "下载地址: https://nodejs.org/"
        exit 1
    fi
    
    NODE_VERSION=$(node -v | sed 's/v//')
    print_info "检测到 Node.js 版本: $NODE_VERSION"
    
    # 检查版本是否 >= 16.20.2
    REQUIRED_VERSION="16.20.2"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$NODE_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
        print_error "Node.js 版本过低，需要 16.20.2 或更高版本"
        exit 1
    fi
}

# 主函数
main() {
    print_info "=========================================="
    print_info "MCSManager Linux AMD64 自动部署脚本"
    print_info "=========================================="
    echo ""
    
    # 检查必需的命令
    print_info "检查必需的工具..."
    check_command git
    check_command wget
    check_command tar
    check_nodejs
    
    # 步骤 1: 检查仓库
    print_info "步骤 1/6: 检查仓库..."
    CURRENT_DIR=$(pwd)
    IS_MCSMANAGER_REPO=false
    REPO_PATH=""
    
    # 检查当前目录是否是 MCSManager 仓库
    if [ -d ".git" ] && [ -f "package.json" ] && [ -d "daemon" ] && [ -d "panel" ] && [ -d "frontend" ]; then
        print_info "检测到当前目录是 MCSManager 仓库: $CURRENT_DIR"
        IS_MCSMANAGER_REPO=true
        REPO_PATH="$CURRENT_DIR"
    # 检查当前目录下是否有 MCSManager 子目录
    elif [ -d "MCSManager/.git" ]; then
        print_info "检测到 MCSManager 仓库在子目录: $CURRENT_DIR/MCSManager"
        IS_MCSMANAGER_REPO=true
        REPO_PATH="$CURRENT_DIR/MCSManager"
    # 检查 BUILD_DIR 下是否有 MCSManager
    elif [ -d "$BUILD_DIR/MCSManager/.git" ]; then
        print_info "检测到 MCSManager 仓库在: $BUILD_DIR/MCSManager"
        IS_MCSMANAGER_REPO=true
        REPO_PATH="$BUILD_DIR/MCSManager"
    fi
    
    if [ "$IS_MCSMANAGER_REPO" = true ]; then
        # 使用现有仓库
        cd "$REPO_PATH"
        print_info "正在更新现有仓库..."
        git pull
        print_info "仓库位置: $(pwd)"
    else
        # 克隆新仓库
        print_info "未找到 MCSManager 仓库，正在克隆..."
        mkdir -p $BUILD_DIR
        cd $BUILD_DIR
        if [ ! -d "MCSManager" ]; then
            print_info "正在克隆仓库到: $BUILD_DIR/MCSManager"
            git clone $REPO_URL
        else
            print_info "目录已存在，正在更新..."
            cd MCSManager
            git pull
            cd ..
        fi
        cd MCSManager
        print_info "仓库位置: $(pwd)"
    fi
    echo ""
    
    # 步骤 2: 安装 npm 依赖
    print_info "步骤 2/6: 安装 npm 依赖..."
    chmod +x install-dependents.sh
    ./install-dependents.sh
    print_info "npm 依赖安装完成"
    echo ""
    
    # 步骤 3: 下载二进制依赖
    print_info "步骤 3/6: 下载 AMD64 二进制依赖..."
    mkdir -p daemon/lib
    cd daemon/lib
    
    print_info "正在下载文件压缩工具..."
    wget --show-progress https://github.com/MCSManager/Zip-Tools/releases/latest/download/file_zip_linux_x64 || {
        print_error "下载 file_zip_linux_x64 失败"
        exit 1
    }
    
    print_info "正在下载 7z 工具..."
    wget --show-progress https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z_linux_x64 || {
        print_error "下载 7z_linux_x64 失败"
        exit 1
    }
    
    print_info "正在下载许可证文件..."
    wget --show-progress https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z-extra-license.txt || {
        print_warn "下载 7z-extra-license.txt 失败（非必需）"
    }
    wget --show-progress https://github.com/MCSManager/Zip-Tools/releases/latest/download/7z-unix-license.txt || {
        print_warn "下载 7z-unix-license.txt 失败（非必需）"
    }
    
    print_info "正在下载 PTY 终端模拟器..."
    wget --show-progress https://github.com/MCSManager/PTY/releases/download/latest/pty_linux_x64 || {
        print_error "下载 pty_linux_x64 失败"
        exit 1
    }
    
    print_info "设置执行权限..."
    chmod +x file_zip_linux_x64 7z_linux_x64 pty_linux_x64 2>/dev/null || true
    
    cd ../..
    print_info "二进制依赖下载完成"
    echo ""
    
    # 步骤 4: 构建生产版本
    print_info "步骤 4/6: 构建生产版本..."
    print_warn "这可能需要几分钟时间，请耐心等待..."
    chmod +x build.sh
    ./build.sh
    
    if [ ! -d "production-code" ]; then
        print_error "构建失败，production-code 目录不存在"
        exit 1
    fi
    print_info "构建完成！"
    echo ""
    
    # 步骤 5: 部署到生产目录
    print_info "步骤 5/6: 部署到生产目录..."
    print_info "部署目录: $DEPLOY_DIR"
    
    # 如果目录已存在，询问是否备份
    if [ -d "$DEPLOY_DIR" ]; then
        BACKUP_DIR="${DEPLOY_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        print_warn "部署目录已存在，是否备份现有部署？(y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "正在备份到: $BACKUP_DIR"
            sudo cp -r $DEPLOY_DIR $BACKUP_DIR || {
                print_error "备份失败"
                exit 1
            }
            print_info "备份完成"
        fi
    fi
    
    # 创建部署目录
    sudo mkdir -p $DEPLOY_DIR
    sudo chown -R $CURRENT_USER:$CURRENT_USER $DEPLOY_DIR
    
    # 复制构建产物
    print_info "正在复制构建产物..."
    cp -r production-code/* $DEPLOY_DIR/
    
    # 复制启动脚本
    print_info "正在复制启动脚本..."
    cp prod-scripts/linux/* $DEPLOY_DIR/
    
    # 复制二进制依赖
    print_info "正在复制二进制依赖..."
    mkdir -p $DEPLOY_DIR/daemon/lib
    cp daemon/lib/* $DEPLOY_DIR/daemon/lib/ 2>/dev/null || true
    
    # 设置脚本权限
    chmod +x $DEPLOY_DIR/*.sh
    
    print_info "部署文件复制完成"
    echo ""
    
    # 步骤 6: 安装生产依赖
    print_info "步骤 6/6: 安装生产依赖..."
    cd $DEPLOY_DIR
    chmod +x install.sh
    ./install.sh
    print_info "生产依赖安装完成"
    echo ""
    
    # 完成
    print_info "=========================================="
    print_info "部署完成！"
    print_info "=========================================="
    echo ""
    print_info "部署目录: $DEPLOY_DIR"
    echo ""
    print_info "启动服务的方法："
    echo "  方法 1 - 安装为系统服务（推荐）："
    echo "    sudo chmod +x install-systemd.sh"
    echo "    sudo ./install-systemd.sh"
    echo "    sudo systemctl start mcsm-daemon mcsm-web"
    echo ""
    echo "  方法 2 - 使用两个终端："
    echo "    cd $DEPLOY_DIR"
    echo "    ./start-daemon.sh  # 终端 1"
    echo "    ./start-web.sh     # 终端 2"
    echo ""
    echo "  方法 3 - 使用 screen（后台运行）："
    echo "    screen -S mcsm-daemon -d -m bash -c 'cd $DEPLOY_DIR && ./start-daemon.sh'"
    echo "    screen -S mcsm-web -d -m bash -c 'cd $DEPLOY_DIR && ./start-web.sh'"
    echo ""
    print_info "访问面板: http://你的服务器IP:23333"
    print_info "默认守护进程端口: 24444"
    echo ""
}

# 执行主函数
main

