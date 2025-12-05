# Certbot Manager - SSL证书管理工具

**版本: v2.0.0** | **仓库: https://github.com/cookabc/certbot-manager**

一个轻量级、模块化的纯Shell脚本工具，用于简化Let's Encrypt SSL证书的申请、管理和续期。

## ✨ 功能特性

- 🔍 **系统检查**: 自动检测certbot和nginx安装状态
- 📋 **证书生成**: 快速创建SSL证书
- 🔧 **配置验证**: 检查nginx SSL配置是否正确
- ⏰ **自动续期**: 设置和管理证书自动续期（systemd/cron）
- 📝 **证书管理**: 列出、查看和管理已安装证书
- 🎨 **彩色界面**: 美观的彩色命令行界面
- 🔧 **跨平台**: 支持Linux/Ubuntu/CentOS/macOS
- 📦 **模块化设计**: 清晰的功能模块划分，便于维护和扩展
- ⚙️ **配置灵活**: 支持配置文件，方便用户自定义设置

## 🚀 快速开始

### 环境要求

- Linux/macOS系统
- Bash 4.0+
- sudo权限（证书操作需要）

### 安装和运行

#### 方法1: 克隆GitHub仓库（推荐）

```bash
# 克隆仓库
git clone git@github.com:cookabc/certbot-manager.git
cd certbot-manager

# 启动帮助（推荐）
./certbot-manager.sh help

# 或直接使用命令
./certbot-manager.sh status    # 检查系统状态
./certbot-manager.sh install   # 安装certbot
```

#### 方法2: 直接下载脚本

```bash
# 下载脚本和模块
git clone git@github.com:cookabc/certbot-manager.git
cd certbot-manager

# 或直接运行
./certbot-manager.sh status
```

## 📖 使用说明

### 命令行模式

```bash
# 基本操作
./certbot-manager.sh status           # 显示系统状态
./certbot-manager.sh list             # 列出已安装证书
./certbot-manager.sh install          # 安装certbot
./certbot-manager.sh create example.com  # 创建SSL证书
./certbot-manager.sh delete example.com  # 删除SSL证书
./certbot-manager.sh renew            # 手动续期证书
./certbot-manager.sh renew-setup      # 设置自动续期
./certbot-manager.sh nginx-check      # 检查nginx配置
./certbot-manager.sh help             # 显示帮助
./certbot-manager.sh version          # 显示版本信息
```

### 配置文件

1. 将 `config.example.conf` 复制为 `config.conf`
2. 根据需要修改配置选项
3. 配置文件支持全局设置，简化命令行操作

```bash
# 复制配置文件
cp config.example.conf config.conf

# 编辑配置文件
nano config.conf
```

## 📁 项目结构

```
certbot-manager/
├── certbot-manager.sh      # 主程序入口
├── config.example.conf     # 示例配置文件
├── README.md               # 项目文档
└── modules/                # 功能模块目录
    ├── base.sh             # 基础架构模块
    ├── system.sh           # 系统检查模块
    ├── certbot.sh          # Certbot管理模块
    ├── certificate.sh      # 证书管理模块
    └── renewal.sh          # 自动续期模块
```

## 🎯 功能详解

### 系统状态检查

自动检测并显示：
- ✅ Certbot安装状态和版本
- ✅ Nginx安装状态和配置检查
- ✅ 已安装证书数量
- ✅ 自动续期设置状态

```bash
./certbot-manager.sh status
```

### Certbot管理

支持多种安装方式：
- **apt**: Debian/Ubuntu系统
- **yum**: CentOS/RHEL系统
- **brew**: macOS系统
- **snap**: Ubuntu 18.04+系统

```bash
# 安装certbot
./certbot-manager.sh install

# 卸载certbot
./certbot-manager.sh uninstall
```

### SSL证书管理

支持两种证书创建模式：
- **Nginx模式**: 自动配置nginx SSL设置
- **Standalone模式**: 临时停止nginx进行验证

```bash
# 创建SSL证书
./certbot-manager.sh create example.com

# 列出已安装证书
./certbot-manager.sh list

# 手动续期所有证书
./certbot-manager.sh renew

# 删除证书
./certbot-manager.sh delete example.com
```

### 自动续期设置

智能选择最佳方案：
- **Systemd Timer**: 现代Linux系统的首选
- **Cron任务**: 传统系统的备用方案

```bash
# 设置自动续期
./certbot-manager.sh renew-setup
```

### Nginx配置检查

检查Nginx配置语法是否正确，并显示版本和配置文件位置。

```bash
# 检查nginx配置
./certbot-manager.sh nginx-check
```

## 🔧 高级功能

### 配置文件说明

配置文件支持以下节：
- `[certbot]`: Certbot相关配置
- `[nginx]`: Nginx相关配置
- `[renewal]`: 自动续期相关配置
- `[logging]`: 日志相关配置

### 系统服务配置

自动创建systemd服务：

```ini
# /etc/systemd/system/certbot.service
[Unit]
Description=Let's Encrypt renewal
[Service]
Type=oneshot
ExecStart=/usr/bin/certbot renew --post-hook "systemctl reload nginx"

# /etc/systemd/system/certbot.timer
[Unit]
Description=Run certbot twice daily
[Timer]
OnCalendar=*-*-* 00,12:00:00
RandomizedDelaySec=1h
Persistent=true
[Install]
WantedBy=timers.target
```

## 🔍 故障排除

### 常见问题

1. **权限不足**
   ```bash
   # 某些操作需要sudo权限
   sudo ./certbot-manager.sh install
   sudo ./certbot-manager.sh create example.com
   ```

2. **域名解析问题**
   ```bash
   # 检查域名是否正确解析到此服务器
   nslookup example.com
   dig example.com
   ```

3. **防火墙问题**
   ```bash
   # 确保HTTP(80)和HTTPS(443)端口开放
   sudo ufw allow 80
   sudo ufw allow 443
   ```

4. **Nginx配置错误**
   ```bash
   # 检查nginx配置语法
   ./certbot-manager.sh nginx-check
   ```

### 日志查看

```bash
# Certbot日志
sudo journalctl -u certbot
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Nginx日志
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

## 🔮 更新和升级

```bash
# 更新脚本（如果从git仓库克隆）
cd certbot-manager
git pull origin main

# 检查版本
./certbot-manager.sh version
```

## 🔗 相关链接

- **GitHub仓库**: https://github.com/cookabc/certbot-manager
- **问题反馈**: https://github.com/cookabc/certbot-manager/issues
- **Let's Encrypt官网**: https://letsencrypt.org/
- **Certbot文档**: https://certbot.eff.org/docs/

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交Issue和Pull Request来改进这个工具！

### 贡献方式

1. Fork 本项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

---

**注意**: 此工具仅用于防御性安全目的，请合法合规地使用SSL证书管理功能。