#!/bin/bash

# 快速部署脚本 - 适合已有环境的服务器

echo "=== 快速部署 Flask MySQL App ==="
echo "目标服务器: 8.153.195.8:8000"
echo ""

APP_DIR="/opt/flask_mysql_app"

# 创建应用目录
echo "1. 创建应用目录..."
mkdir -p $APP_DIR
cd $APP_DIR

# 创建虚拟环境
echo "2. 创建Python虚拟环境..."
python3 -m venv venv
source venv/bin/activate

# 安装依赖
echo "3. 安装依赖..."
pip install --upgrade pip
pip install flask flask-sqlalchemy pymysql python-dotenv

# 开放端口
echo "4. 配置防火墙..."
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-port=8000/tcp
    firewall-cmd --reload
elif command -v ufw &> /dev/null; then
    ufw allow 8000/tcp
fi

# 创建systemd服务
echo "5. 创建系统服务..."
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

echo "6. 重新加载systemd..."
systemctl daemon-reload

echo "7. 启动服务..."
systemctl start flask-mysql-app
systemctl enable flask-mysql-app

echo ""
echo "=== 部署完成 ==="
echo ""
echo "请将应用文件上传到: $APP_DIR"
echo "需要的文件:"
echo "  - flask_mysql.py"
echo "  - templates/ 目录"
echo ""
echo "上传文件后，重启服务:"
echo "  systemctl restart flask-mysql-app"
echo ""
echo "访问地址:"
echo "  http://8.153.195.8:8000"
echo ""
echo "查看服务状态:"
echo "  systemctl status flask-mysql-app"
echo "  journalctl -u flask-mysql-app -f"