#!/bin/bash

echo "=== 阿里云ECS部署指南 ==="
echo ""

echo "1. 检查Python环境"
python3 --version || echo "请安装Python 3.6+"
pip3 --version || echo "请安装pip3"

echo ""
echo "2. 安装依赖"
pip3 install flask flask-sqlalchemy pymysql python-dotenv

echo ""
echo "3. 检查防火墙状态"
# CentOS/RHEL
if command -v firewall-cmd &> /dev/null; then
    echo "使用firewalld管理防火墙"
    sudo firewall-cmd --list-ports
    echo "开放8000端口:"
    sudo firewall-cmd --permanent --add-port=8000/tcp
    sudo firewall-cmd --reload
fi

# Ubuntu/Debian
if command -v ufw &> /dev/null; then
    echo "使用ufw管理防火墙"
    sudo ufw status
    echo "开放8000端口:"
    sudo ufw allow 8000/tcp
fi

echo ""
echo "4. 检查端口监听状态"
echo "检查8000端口是否被占用:"
netstat -tlnp | grep :8000 || echo "8000端口空闲"

echo ""
echo "5. 启动应用"
echo "方式1: 直接启动"
echo "python3 flask_mysql.py"

echo ""
echo "方式2: 后台启动"
echo "nohup python3 flask_mysql.py > app.log 2>&1 &"

echo ""
echo "方式3: 使用systemd服务"
echo "创建 /etc/systemd/system/flask-app.service 文件"
echo "内容如下:"
echo "[Unit]
Description=Flask Web App
After=network.target

[Service]
User=root
WorkingDirectory=/path/to/your/app
ExecStart=/usr/bin/python3 /path/to/your/app/flask_mysql.py
Restart=always

[Install]
WantedBy=multi-user.target"

echo ""
echo "6. 检查服务状态"
echo "sudo systemctl status flask-app"
echo "sudo systemctl start flask-app"
echo "sudo systemctl enable flask-app"

echo ""
echo "7. 测试连接"
echo "本地测试: curl http://localhost:8000"
echo "外部测试: curl http://8.153.195.8:8000"