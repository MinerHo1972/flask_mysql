#!/bin/bash

# Flask MySQL App 自动启动配置脚本
# 确保应用在服务器重启后自动运行

set -e

echo "=== Flask MySQL App 自动启动配置 ==="
echo "目标服务器: 8.153.195.8"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

APP_NAME="flask-mysql-app"
APP_DIR="/opt/flask_mysql_app"
SERVICE_FILE="/etc/systemd/system/${APP_NAME}.service"

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
    if [[ $EUID -ne 0 ]]; then
        print_error "请使用root用户或sudo权限执行此脚本"
        exit 1
    fi
}

# 检查应用目录
check_app_dir() {
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "应用目录不存在: $APP_DIR"
        print_info "请先运行部署脚本或手动创建应用目录"
        exit 1
    fi
}

# 检查Python虚拟环境
check_venv() {
    if [[ ! -d "$APP_DIR/venv" ]]; then
        print_error "Python虚拟环境不存在"
        print_info "创建虚拟环境..."
        cd "$APP_DIR"
        python3 -m venv venv
    fi
}

# 检查应用文件
check_app_files() {
    if [[ ! -f "$APP_DIR/flask_mysql.py" ]]; then
        print_error "应用文件不存在: flask_mysql.py"
        exit 1
    fi

    if [[ ! -d "$APP_DIR/templates" ]]; then
        print_error "模板目录不存在: templates/"
        exit 1
    fi
}

# 安装依赖
install_dependencies() {
    print_info "检查并安装依赖..."
    cd "$APP_DIR"
    source venv/bin/activate

    # 检查关键依赖
    python -c "import flask" 2>/dev/null || pip install flask
    python -c "import flask_sqlalchemy" 2>/dev/null || pip install flask-sqlalchemy
    python -c "import pymysql" 2>/dev/null || pip install pymysql
    python -c "import dotenv" 2>/dev/null || pip install python-dotenv

    print_info "依赖检查完成"
}

# 创建systemd服务文件
create_service_file() {
    print_info "创建systemd服务文件..."

    cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Flask MySQL Web App
Documentation=https://github.com/your-repo/flask-mysql-app
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/flask_mysql_app
Environment=PATH=/opt/flask_mysql_app/venv/bin
EnvironmentFile=/opt/flask_mysql_app/.env
ExecStart=/opt/flask_mysql_app/venv/bin/python flask_mysql.py
ExecReload=/bin/kill -HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=on-failure
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# 安全设置
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/flask_mysql_app /tmp

# 日志设置
StandardOutput=journal
StandardError=journal
SyslogIdentifier=flask-mysql-app

[Install]
WantedBy=multi-user.target
EOF

    print_info "服务文件创建完成: $SERVICE_FILE"
}

# 创建环境变量文件
create_env_file() {
    if [[ ! -f "$APP_DIR/.env" ]]; then
        print_info "创建环境变量文件..."
        cat > "$APP_DIR/.env" << 'EOF'
# Flask配置
SECRET_KEY=your-secret-key-change-this
FLASK_ENV=production
FLASK_DEBUG=0

# 数据库配置
DATABASE_URL=mysql+pymysql://minerho:P_ssw0rd@rm-uf6bbjfr09z01wl7jfo.mysql.rds.aliyuncs.com:3306/filelist

# 服务器配置
HOST=0.0.0.0
PORT=8000
EOF
        print_info "环境变量文件创建完成"
    else
        print_info "环境变量文件已存在"
    fi
}

# 设置文件权限
set_permissions() {
    print_info "设置文件权限..."
    chmod 755 "$APP_DIR"
    chmod 644 "$SERVICE_FILE"
    chmod -R 755 "$APP_DIR/templates"
    chmod 600 "$APP_DIR/.env" 2>/dev/null || true
    print_info "权限设置完成"
}

# 启用并启动服务
enable_and_start_service() {
    print_info "启用systemd服务..."

    # 重新加载systemd配置
    systemctl daemon-reload

    # 停止可能运行的服务
    systemctl stop "$APP_NAME" 2>/dev/null || true

    # 启用服务（开机自启）
    systemctl enable "$APP_NAME"

    # 启动服务
    systemctl start "$APP_NAME"

    # 等待服务启动
    sleep 3

    # 检查服务状态
    if systemctl is-active --quiet "$APP_NAME"; then
        print_info "服务启动成功！"
        print_info "当前状态: $(systemctl is-active "$APP_NAME")"
    else
        print_error "服务启动失败"
        print_info "查看详细状态: systemctl status $APP_NAME"
        print_info "查看日志: journalctl -u $APP_NAME -n 20"
        return 1
    fi
}

# 验证服务配置
verify_service() {
    print_info "验证服务配置..."

    # 检查服务是否启用
    if systemctl is-enabled --quiet "$APP_NAME"; then
        print_info "✓ 服务已启用开机自启"
    else
        print_error "✗ 服务未启用开机自启"
    fi

    # 检查服务是否正在运行
    if systemctl is-active --quiet "$APP_NAME"; then
        print_info "✓ 服务正在运行"
    else
        print_error "✗ 服务未运行"
    fi

    # 检查端口监听
    if netstat -tlnp | grep :8000 > /dev/null; then
        print_info "✓ 8000端口正在监听"
    else
        print_error "✗ 8000端口未监听"
    fi

    # 检查进程
    if pgrep -f "flask_mysql.py" > /dev/null; then
        print_info "✓ Flask进程正在运行"
    else
        print_error "✗ Flask进程未运行"
    fi
}

# 测试自动重启功能
test_autorestart() {
    print_warning "测试服务自动重启功能..."

    # 杀死进程
    pkill -f "flask_mysql.py"
    sleep 5

    # 检查是否自动重启
    if systemctl is-active --quiet "$APP_NAME"; then
        print_info "✓ 服务自动重启成功"
    else
        print_warning "服务未能自动重启，可能需要手动检查"
    fi
}

# 显示服务信息
show_service_info() {
    echo ""
    print_info "=== 服务配置完成 ==="
    echo ""
    echo "服务名称: $APP_NAME"
    echo "应用目录: $APP_DIR"
    echo "服务文件: $SERVICE_FILE"
    echo ""
    echo "常用命令:"
    echo "  查看状态: systemctl status $APP_NAME"
    echo "  启动服务: systemctl start $APP_NAME"
    echo "  停止服务: systemctl stop $APP_NAME"
    echo "  重启服务: systemctl restart $APP_NAME"
    echo "  查看日志: journalctl -u $APP_NAME -f"
    echo "  查看配置: systemctl show $APP_NAME"
    echo ""
    echo "访问地址:"
    echo "  http://8.153.195.8:8000"
    echo ""
    echo "重启服务器测试命令:"
    echo "  sudo reboot"
    echo ""
    echo "验证自动启动:"
    echo "  重启后检查: systemctl status $APP_NAME"
    echo ""
}

# 创建监控脚本
create_monitor_script() {
    print_info "创建服务监控脚本..."

    cat > "$APP_DIR/monitor.sh" << 'EOF'
#!/bin/bash

# 服务监控脚本
APP_NAME="flask-mysql-app"

echo "=== Flask MySQL App 服务监控 ==="
echo "时间: $(date)"
echo ""

# 检查服务状态
echo "1. 服务状态:"
systemctl is-active $APP_NAME
systemctl is-enabled $APP_NAME

echo ""

# 检查端口
echo "2. 端口监听:"
netstat -tlnp | grep :8000 || echo "8000端口未监听"

echo ""

# 检查进程
echo "3. 进程状态:"
ps aux | grep flask_mysql.py | grep -v grep || echo "Flask进程未运行"

echo ""

# 检查最近的日志
echo "4. 最近的日志:"
journalctl -u $APP_NAME --no-pager -n 5

echo ""

# 检查资源使用
echo "5. 资源使用:"
echo "CPU: $(ps aux | grep flask_mysql.py | grep -v grep | awk '{print $3}' | head -1)%"
echo "内存: $(ps aux | grep flask_mysql.py | grep -v grep | awk '{print $4}' | head -1)%"

echo ""
echo "=== 监控完成 ==="
EOF

    chmod +x "$APP_DIR/monitor.sh"
    print_info "监控脚本创建完成: $APP_DIR/monitor.sh"
}

# 主函数
main() {
    print_info "开始配置Flask MySQL App自动启动..."

    check_root
    check_app_dir
    check_venv
    check_app_files
    install_dependencies
    create_service_file
    create_env_file
    set_permissions
    enable_and_start_service
    verify_service

    read -p "是否测试自动重启功能？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        test_autorestart
        verify_service
    fi

    create_monitor_script
    show_service_info

    print_info "自动启动配置完成！"
    print_warning "建议重启服务器验证自动启动功能"
}

# 执行主函数
main "$@"