# Flask MySQL Web App 部署指南

## 服务器信息
- **IP地址**: 8.153.195.8
- **端口**: 8000
- **访问地址**: http://8.153.195.8:8000

## 快速部署步骤

### 1. 连接到服务器
```bash
ssh root@8.153.195.8
```

### 2. 选择部署方式

#### 方式一：快速部署（推荐）
```bash
# 下载快速部署脚本
wget https://your-domain.com/quick_deploy.sh
# 或者直接复制脚本内容到服务器

# 给脚本执行权限
chmod +x quick_deploy.sh

# 执行部署
./quick_deploy.sh
```

#### 方式二：完整部署
```bash
# 下载完整部署脚本
wget https://your-domain.com/deploy_server.sh
chmod +x deploy_server.sh
./deploy_server.sh
```

### 3. 上传应用文件
部署脚本执行完成后，需要将应用文件上传到服务器：

```bash
# 在本地机器上执行（替换为正确的路径）
scp -r flask_mysql.py templates/ root@8.153.195.8:/opt/flask_mysql_app/

# 或者使用其他方式如：
# - FTP/SFTP工具
# - Git克隆
# - rsync
```

### 4. 重启服务
```bash
# 重启服务使新文件生效
systemctl restart flask-mysql-app

# 查看服务状态
systemctl status flask-mysql-app
```

## 手动部署步骤

如果自动脚本不工作，可以按以下步骤手动部署：

### 1. 安装Python环境
```bash
# CentOS/RHEL
yum update -y
yum install -y python3 python3-pip

# Ubuntu/Debian
apt update -y
apt install -y python3 python3-pip python3-venv
```

### 2. 创建应用目录
```bash
mkdir -p /opt/flask_mysql_app
cd /opt/flask_mysql_app
```

### 3. 创建虚拟环境
```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 4. 配置防火墙
```bash
# CentOS/RHEL
firewall-cmd --permanent --add-port=8000/tcp
firewall-cmd --reload

# Ubuntu/Debian
ufw allow 8000/tcp
```

### 5. 创建systemd服务
```bash
cat > /etc/systemd/system/flask-mysql-app.service << 'EOF'
[Unit]
Description=Flask MySQL Web App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/flask_mysql_app
Environment=PATH=/opt/flask_mysql_app/venv/bin
ExecStart=/opt/flask_mysql_app/venv/bin/python flask_mysql.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

### 6. 启动服务
```bash
systemctl daemon-reload
systemctl start flask-mysql-app
systemctl enable flask-mysql-app
```

## 服务管理命令

```bash
# 查看服务状态
systemctl status flask-mysql-app

# 启动服务
systemctl start flask-mysql-app

# 停止服务
systemctl stop flask-mysql-app

# 重启服务
systemctl restart flask-mysql-app

# 查看日志
journalctl -u flask-mysql-app -f

# 禁用开机自启
systemctl disable flask-mysql-app

# 启用开机自启
systemctl enable flask-mysql-app
```

## 验证部署

### 1. 检查端口监听
```bash
netstat -tlnp | grep :8000
```

### 2. 本地测试
```bash
curl http://localhost:8000
```

### 3. 检查进程
```bash
ps aux | grep flask_mysql.py
```

## 环境变量配置

如果需要配置环境变量，可以创建 `.env` 文件：

```bash
# 在应用目录下创建.env文件
cd /opt/flask_mysql_app
cat > .env << 'EOF'
DATABASE_URL=mysql+pymysql://username:password@hostname:3306/database_name
PORT=8000
EOF
```

## 故障排除

### 1. 端口被占用
```bash
# 查找占用8000端口的进程
lsof -i :8000
netstat -tlnp | grep :8000

# 杀死进程
kill -9 <PID>
```

### 2. 服务启动失败
```bash
# 查看详细日志
journalctl -u flask-mysql-app -n 50

# 手动测试
cd /opt/flask_mysql_app
source venv/bin/activate
python flask_mysql.py
```

### 3. 数据库连接问题
- 检查数据库地址、端口、用户名、密码是否正确
- 确保数据库服务器允许远程连接
- 检查网络安全组设置

### 4. 防火墙问题
```bash
# 检查防火墙状态
firewall-cmd --list-all  # CentOS
ufw status              # Ubuntu

# 检查安全组（阿里云控制台）
# 确保入方向规则允许8000端口
```

## 性能优化

### 1. 使用Gunicorn（推荐）
```bash
# 安装Gunicorn
pip install gunicorn

# 创建Gunicorn配置文件
cat > gunicorn.conf.py << 'EOF'
bind = "0.0.0.0:8000"
workers = 4
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2
max_requests = 1000
max_requests_jitter = 100
preload_app = True
EOF

# 更新systemd服务文件
# 将ExecStart改为:
# ExecStart=/opt/flask_mysql_app/venv/bin/gunicorn -c gunicorn.conf.py flask_mysql:app
```

### 2. 使用Nginx反向代理
```nginx
server {
    listen 80;
    server_name 8.153.195.8;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 安全建议

1. **使用HTTPS**: 配置SSL证书
2. **数据库安全**: 使用强密码，限制数据库访问权限
3. **定期更新**: 保持系统和依赖包最新
4. **日志监控**: 监控应用日志，及时发现异常
5. **备份数据**: 定期备份数据库

## 联系信息

如遇问题，请检查：
1. 服务器系统日志
2. 应用日志
3. 防火墙设置
4. 安全组配置（阿里云控制台）