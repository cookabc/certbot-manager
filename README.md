# Certbot Manager - SSL证书管理工具

**版本: v1.1.0** | **仓库: https://github.com/cookabc/certbot-manager**

一个功能强大的纯Shell脚本工具，用于简化Let's Encrypt SSL证书的申请、管理和续期。

## ✨ 功能特性

- 🔍 **系统检查**: 自动检测certbot和nginx安装状态
- 📋 **证书生成**: 通过交互式界面创建SSL证书
- 🔧 **配置验证**: 检查nginx SSL配置是否正确
- ⏰ **自动续期**: 设置和管理证书自动续期（systemd/cron）
- 📝 **证书管理**: 列出、查看和管理已安装证书
- 🎨 **彩色界面**: 美观的彩色命令行界面
- 🔧 **跨平台**: 支持Linux/Ubuntu/CentOS/macOS

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

# 启动交互式菜单（推荐）
./certbot_manager.sh

# 或直接使用命令
./certbot_manager.sh status    # 检查系统状态
./certbot_manager.sh help      # 显示帮助
```

#### 方法2: 直接下载脚本

```bash
# 下载脚本
wget https://raw.githubusercontent.com/cookabc/certbot-manager/main/certbot_manager.sh
chmod +x certbot_manager.sh

# 启动交互式菜单
./certbot_manager.sh
```

## 📖 使用说明

### 命令行模式

```bash
# 基本操作
./certbot_manager.sh status           # 显示系统状态
./certbot_manager.sh list             # 列出已安装证书
./certbot_manager.sh install          # 安装certbot
./certbot_manager.sh create example.com  # 创建SSL证书
./certbot_manager.sh renew            # 手动续期证书
./certbot_manager.sh renew-setup      # 设置自动续期
./certbot_manager.sh nginx-check      # 检查nginx配置
./certbot_manager.sh interactive      # 交互式菜单
./certbot_manager.sh help            # 显示帮助
```

### 交互式菜单

启动交互式菜单，通过数字选择操作：

```bash
./certbot_manager.sh
```

菜单选项：
1. 显示系统状态
2. 列出已安装证书
3. 安装certbot
4. 创建SSL证书
5. 续期证书
6. 设置自动续期
7. 检查nginx配置
8. 帮助信息
9. 退出

## 🎯 功能详解

### 系统状态检查

自动检测并显示：
- ✅ Certbot安装状态和版本
- ✅ Nginx安装状态和配置检查
- ✅ 已安装证书数量
- ✅ 自动续期设置状态

### SSL证书创建

支持两种模式：
- **Nginx模式**: 自动配置nginx SSL设置
- **Standalone模式**: 临时停止nginx进行验证

### 自动续期设置

智能选择最佳方案：
- **Systemd Timer**: 现代Linux系统的首选
- **Cron任务**: 传统系统的备用方案

### 多平台支持

- **Ubuntu/Debian**: 使用apt包管理器
- **CentOS/RHEL**: 使用yum包管理器
- **macOS**: 使用Homebrew
- **其他系统**: 提供手动安装指导

## 📋 使用示例

### 快速开始流程

```bash
# 1. 检查系统状态
./certbot_manager.sh status

# 2. 安装certbot（如果未安装）
sudo ./certbot_manager.sh install

# 3. 创建SSL证书
./certbot_manager.sh create example.com

# 4. 设置自动续期
sudo ./certbot_manager.sh renew-setup

# 5. 验证安装
./certbot_manager.sh list
```

### 批量管理

```bash
# 检查所有证书状态
./certbot_manager.sh list

# 手动续期所有证书
sudo ./certbot_manager.sh renew

# 检查nginx配置
./certbot_manager.sh nginx-check
```

## 🔧 高级功能

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

### Cron任务配置

自动添加cron任务：

```bash
# 每天中午12点自动续期
0 12 * * * /usr/bin/certbot renew --quiet
```

## 🎨 界面预览

```
🔧 Certbot SSL证书管理工具 v1.0.0
==================================================

🎯 系统状态检查
==================================================
✅ Certbot: 已安装
   版本: certbot 2.6.0
✅ Nginx: 安装成功，配置正确
ℹ️ 已安装证书数量: 2
✅ 自动续期: 已设置

==================================================
请选择操作:
1) 显示系统状态
2) 列出已安装证书
3) 安装certbot
4) 创建SSL证书
5) 续期证书
6) 设置自动续期
7) 检查nginx配置
8) 帮助信息
9) 退出
```

## 🔍 故障排除

### 常见问题

1. **权限不足**
   ```bash
   # 某些操作需要sudo权限
   sudo ./certbot_manager.sh install
   sudo ./certbot_manager.sh create example.com
   ```

2. **域名解析问题**
   ```bash
   # 检查域名是否正确解析
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
   ./certbot_manager.sh nginx-check
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

# 重新下载脚本（如果直接下载）
wget https://raw.githubusercontent.com/cookabc/certbot-manager/main/certbot_manager.sh -O certbot_manager.sh

# 更新certbot
sudo apt update && sudo apt upgrade certbot  # Ubuntu/Debian
sudo yum update certbot                     # CentOS/RHEL
brew upgrade certbot                        # macOS
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