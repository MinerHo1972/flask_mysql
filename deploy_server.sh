#!/bin/bash

# 阿里云ECS服务器部署脚本
# 适用于CentOS/RHEL 7+ 和 Ubuntu/Debian 18+

set -e

echo "=== Flask MySQL Web App 部署脚本 ==="
echo "服务器IP: 8.153.195.8"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "检测到root用户，继续执行..."
    else
        print_error "请使用root用户或sudo权限执行此脚本"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
        print_info "检测到CentOS/RHEL系统"
    elif [[ -f /etc/debian_version ]]; then
        OS="ubuntu"
        print_info "检测到Ubuntu/Debian系统"
    else
        print_error "不支持的操作系统"
        exit 1
    fi
}

# 安装Python环境
install_python() {
    print_info "检查Python环境..."

    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 -V | awk '{print $2}')
        print_info "Python版本: $PYTHON_VERSION"
    else
        print_info "安装Python3..."
        if [[ $OS == "centos" ]]; then
            yum update -y
            yum install -y python3 python3-pip
        else
            apt update -y
            apt install -y python3 python3-pip python3-venv
        fi
    fi

    if command -v pip3 &> /dev/null; then
        print_info "pip3已安装"
    else
        print_error "pip3未找到，请手动安装"
        exit 1
    fi
}

# 创建应用目录
create_app_dir() {
    APP_DIR="/opt/flask_mysql_app"
    print_info "创建应用目录: $APP_DIR"

    mkdir -p $APP_DIR
    cd $APP_DIR

    print_info "当前工作目录: $(pwd)"
}

# 上传应用文件（需要手动操作）
upload_files() {
    print_warning "请将以下文件上传到服务器目录 $APP_DIR:"
    echo "- flask_mysql.py"
    echo "- requirements.txt"
    echo "- templates/ (整个目录)"
    echo ""
    echo "可以使用以下命令上传："
    echo "scp -r flask_mysql.py templates/ requirements.txt root@8.153.195.8:$APP_DIR/"
    echo ""
    read -p "文件上传完成后按Enter继续..."
}

# 安装Python依赖
install_dependencies() {
    print_info "安装Python依赖..."

    # 创建虚拟环境
    python3 -m venv venv
    source venv/bin/activate

    # 升级pip
    pip install --upgrade pip

    # 安装依赖
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
        print_info "依赖安装完成"
    else
        print_error "requirements.txt文件不存在"
        exit 1
    fi
}

# 配置防火墙
configure_firewall() {
    print_info "配置防火墙..."

    if [[ $OS == "centos" ]]; then
        # CentOS/RHEL
        if command -v firewall-cmd &> /dev/null; then
            print_info "开放8000端口..."
            firewall-cmd --permanent --add-port=8000/tcp
            firewall-cmd --reload
            print_info "防火墙配置完成"
        else
            print_warning "firewalld未安装，跳过防火墙配置"
        fi
    else
        # Ubuntu/Debian
        if command -v ufw &> /dev/null; then
            print_info "开放8000端口..."
            ufw allow 8000/tcp
            print_info "防火墙配置完成"
        else
            print_warning "ufw未安装，跳过防火墙配置"
        fi
    fi
}

# 创建systemd服务
create_systemd_service() {
    print_info "创建systemd服务..."

    cat > /etc/systemd/system/flask-mysql-app.service << EOF
[Unit]
Description=Flask MySQL Web App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
ExecStart=$APP_DIR/venv/bin/python flask_mysql.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    print_info "服务文件创建完成"
}

# 启动应用
start_app() {
    print_info "启动Flask应用..."

    # 重新加载systemd
    systemctl daemon-reload

    # 启动服务
    systemctl start flask-mysql-app

    # 设置开机自启
    systemctl enable flask-mysql-app

    # 检查服务状态
    sleep 3
    if systemctl is-active --quiet flask-mysql-app; then
        print_info "应用启动成功！"
        print_info "服务状态: $(systemctl is-active flask-mysql-app)"
    else
        print_error "应用启动失败"
        systemctl status flask-mysql-app
        exit 1
    fi
}

# 测试应用
test_app() {
    print_info "测试应用连接..."

    sleep 2

    # 本地测试
    if curl -s http://localhost:8000 > /dev/null; then
        print_info "本地测试成功"
    else
        print_error "本地测试失败"
    fi

    # 检查端口监听
    if netstat -tlnp | grep :8000 > /dev/null; then
        print_info "8000端口正在监听"
    else
        print_error "8000端口未监听"
    fi
}

# 显示部署信息
show_deployment_info() {
    echo ""
    print_info "=== 部署完成 ==="
    echo ""
    echo "应用访问地址:"
    echo "  本地访问: http://localhost:8000"
    echo "  外网访问: http://8.153.195.8:8000"
    echo ""
    echo "服务管理命令:"
    echo "  查看状态: systemctl status flask-mysql-app"
    echo "  启动服务: systemctl start flask-mysql-app"
    echo "  停止服务: systemctl stop flask-mysql-app"
    echo "  重启服务: systemctl restart flask-mysql-app"
    echo "  查看日志: journalctl -u flask-mysql-app -f"
    echo ""
    echo "应用目录: $APP_DIR"
    echo "日志位置: $APP_DIR/app.log"
    echo ""
}

# 主函数
main() {
    print_info "开始部署Flask MySQL Web App..."

    check_root
    detect_os
    install_python
    create_app_dir
    upload_files
    install_dependencies
    configure_firewall
    create_systemd_service
    start_app
    test_app
    show_deployment_info

    print_info "部署完成！"
}

# 执行主函数
main "$@"