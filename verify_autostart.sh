#!/bin/bash

# 验证Flask MySQL App自动启动配置

APP_NAME="flask-mysql-app"
APP_DIR="/opt/flask_mysql_app"

echo "=== 验证自动启动配置 ==="
echo "时间: $(date)"
echo ""

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    if [[ $1 == "OK" ]]; then
        echo -e "${GREEN}✓ OK${NC} - $2"
    elif [[ $1 == "WARN" ]]; then
        echo -e "${YELLOW}⚠ WARN${NC} - $2"
    else
        echo -e "${RED}✗ ERROR${NC} - $2"
    fi
}

# 1. 检查服务是否启用开机自启
echo "1. 开机自启配置:"
if systemctl is-enabled --quiet "$APP_NAME" 2>/dev/null; then
    print_status "OK" "服务已启用开机自启"
else
    print_status "ERROR" "服务未启用开机自启"
fi

# 2. 检查服务是否正在运行
echo ""
echo "2. 服务运行状态:"
if systemctl is-active --quiet "$APP_NAME" 2>/dev/null; then
    print_status "OK" "服务正在运行"
else
    print_status "ERROR" "服务未运行"
fi

# 3. 检查端口监听
echo ""
echo "3. 端口监听状态:"
if netstat -tlnp 2>/dev/null | grep :8000 > /dev/null; then
    print_status "OK" "8000端口正在监听"
    netstat -tlnp | grep :8000
else
    print_status "ERROR" "8000端口未监听"
fi

# 4. 检查应用文件
echo ""
echo "4. 应用文件检查:"
if [[ -f "$APP_DIR/flask_mysql.py" ]]; then
    print_status "OK" "主应用文件存在"
else
    print_status "ERROR" "主应用文件不存在"
fi

if [[ -d "$APP_DIR/templates" ]]; then
    print_status "OK" "模板目录存在"
else
    print_status "ERROR" "模板目录不存在"
fi

# 5. 检查虚拟环境
echo ""
echo "5. Python虚拟环境:"
if [[ -d "$APP_DIR/venv" ]]; then
    print_status "OK" "虚拟环境存在"
    if [[ -f "$APP_DIR/venv/bin/python" ]]; then
        print_status "OK" "Python解释器存在"
    else
        print_status "ERROR" "Python解释器不存在"
    fi
else
    print_status "ERROR" "虚拟环境不存在"
fi

# 6. 检查systemd服务文件
echo ""
echo "6. Systemd服务文件:"
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"
if [[ -f "$SERVICE_FILE" ]]; then
    print_status "OK" "服务文件存在"
    if grep -q "WantedBy=multi-user.target" "$SERVICE_FILE"; then
        print_status "OK" "服务配置正确"
    else
        print_status "WARN" "服务配置可能有问题"
    fi
else
    print_status "ERROR" "服务文件不存在"
fi

# 7. 检查最近的错误日志
echo ""
echo "7. 最近的错误日志:"
ERROR_LOGS=$(journalctl -u "$APP_NAME" --no-pager -n 10 --priority=err 2>/dev/null | wc -l)
if [[ $ERROR_LOGS -gt 0 ]]; then
    print_status "WARN" "发现 $ERROR_LOGS 条错误日志"
    journalctl -u "$APP_NAME" --no-pager -n 5 --priority=err
else
    print_status "OK" "最近无错误日志"
fi

# 8. 测试HTTP连接
echo ""
echo "8. HTTP连接测试:"
if curl -s --connect-timeout 5 http://localhost:8000 > /dev/null 2>&1; then
    print_status "OK" "本地HTTP连接正常"
else
    print_status "ERROR" "本地HTTP连接失败"
fi

# 9. 系统资源使用
echo ""
echo "9. 系统资源使用:"
if pgrep -f "flask_mysql.py" > /dev/null; then
    PID=$(pgrep -f "flask_mysql.py" | head -1)
    if [[ -n "$PID" ]]; then
        CPU=$(ps -p "$PID" -o %cpu --no-headers 2>/dev/null | tr -d ' ')
        MEM=$(ps -p "$PID" -o %mem --no-headers 2>/dev/null | tr -d ' ')
        print_status "OK" "进程PID: $PID, CPU: ${CPU}%, 内存: ${MEM}%"
    fi
else
    print_status "ERROR" "未找到Flask进程"
fi

# 10. 网络连接测试
echo ""
echo "10. 外网连接测试:"
if curl -s --connect-timeout 10 http://8.153.195.8:8000 > /dev/null 2>&1; then
    print_status "OK" "外网访问正常"
else
    print_status "WARN" "外网访问可能有问题（检查防火墙/安全组）"
fi

echo ""
echo "=== 验证完成 ==="
echo ""
echo "如果发现任何问题，请运行以下命令修复："
echo "  sudo systemctl daemon-reload"
echo "  sudo systemctl enable $APP_NAME"
echo "  sudo systemctl restart $APP_NAME"
echo ""
echo "查看详细日志："
echo "  journalctl -u $APP_NAME -f"