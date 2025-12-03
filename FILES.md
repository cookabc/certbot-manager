# 项目文件说明

**版本: v1.1.0** | **仓库: https://github.com/cookabc/certbot-manager**

## 📁 核心文件

| 文件 | 说明 |
|------|------|
| `certbot_manager.sh` | 主要的Shell脚本工具，提供完整的SSL证书管理功能 |
| `README.md` | 详细的使用说明文档 |
| `FILES.md` | 本文件，项目结构说明 |

## 📦 项目结构

```
certbot-manager/
├── certbot_manager.sh    # 主脚本（510行，功能完整）
├── README.md            # 使用说明
└── FILES.md             # 文件说明
```

## 🚀 快速使用

```bash
# 给脚本添加执行权限
chmod +x certbot_manager.sh

# 启动交互式菜单
./certbot_manager.sh

# 或直接使用命令
./certbot_manager.sh status
./certbot_manager.sh help
```

## ✨ 脚本功能

### 🔍 系统检查
- Certbot安装状态和版本检测
- Nginx安装状态和配置验证
- 已安装证书数量统计
- 自动续期状态检查

### 📋 证书管理
- 列出所有已安装证书
- 显示证书详细信息（域名、到期时间、路径等）
- 支持sudo权限检查

### 🔧 安装和配置
- 多平台certbot自动安装（Ubuntu/Debian/CentOS/macOS）
- 智能选择安装方式
- Nginx插件自动配置

### ⏰ 自动续期
- Systemd timer自动设置（推荐）
- Cron任务备用方案
- 自动重载nginx配置

### 🎨 用户界面
- 彩色命令行界面
- 交互式菜单系统
- 详细的帮助和错误提示
- 支持命令行和交互式两种模式

## 🎯 使用方式

### 1. 命令行模式
```bash
./certbot_manager.sh status           # 系统状态
./certbot_manager.sh list             # 列出证书
./certbot_manager.sh install          # 安装certbot
./certbot_manager.sh create domain.com  # 创建证书
./certbot_manager.sh renew            # 续期证书
./certbot_manager.sh renew-setup      # 设置自动续期
./certbot_manager.sh nginx-check      # 检查nginx
./certbot_manager.sh help            # 帮助信息
```

### 2. 交互式模式
```bash
./certbot_manager.sh    # 默认启动交互式菜单
```

## 💡 技术特性

- **纯Shell实现**: 无需Python或其他依赖
- **跨平台支持**: Linux/macOS通用
- **权限管理**: 智能检测和提示sudo需求
- **错误处理**: 完善的错误检查和用户提示
- **彩色输出**: 美观的终端界面
- **模块化设计**: 函数化编程，易于维护

## 🔧 系统兼容性

### 支持的操作系统
- Ubuntu/Debian (apt)
- CentOS/RHEL (yum)
- macOS (Homebrew)
- 其他Linux发行版（提供手动安装指导）

### 支持的Web服务器
- Nginx（自动配置）
- Standalone模式（无Web服务器）

### 自动续期支持
- Systemd Timer（现代Linux）
- Cron任务（传统系统）

## 🎉 项目优势

1. **轻量级**: 单个Shell脚本，无外部依赖
2. **易部署**: 下载即可使用，无需安装
3. **功能完整**: 涵盖SSL证书全生命周期管理
4. **用户友好**: 彩色界面和详细提示
5. **安全可靠**: 完善的权限检查和错误处理

这个纯Shell版本比之前的Python版本更加简洁、轻量，同时保持了所有核心功能！