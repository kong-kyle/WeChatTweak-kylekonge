# WeChatTweak

[![GitHub](https://img.shields.io/badge/GitHub-black?logo=github&logoColor=white)](https://github.com/kong-kyle/WeChatTweak-kylekonge)
[![Telegram](https://img.shields.io/badge/Telegram-black?logo=telegram&logoColor=white)](https://t.me/wechattweak)
[![FAQ](https://img.shields.io/badge/FAQ-black?logo=googledocs&logoColor=white)](https://github.com/sunnyyoung/WeChatTweak/wiki/FAQ)
[![WeChat](https://img.shields.io/badge/WeChat-4.1.11-07C160)](https://github.com/kong-kyle/WeChatTweak-kylekonge)
[![Platform](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-111111?logo=apple&logoColor=white)](https://github.com/kong-kyle/WeChatTweak-kylekonge)

用于修改微信 macOS 客户端的命令行工具。

当前已适配微信 macOS **4.1.11**（内部版本 `269136`）。

## 功能

- 阻止消息撤回
- 阻止自动更新
- 客户端多开

## 环境要求

- Apple Silicon Mac（`arm64`）
- macOS 12 或更高版本
- 已安装微信 macOS 客户端

## 安装

```bash
brew install kong-kyle/tap/wechattweak
```

## 使用

请先完全退出微信，再执行 Patch：

```bash
# 执行 Patch，默认处理 /Applications/WeChat.app
wechattweak patch

# 查看当前版本和所有支持的内部版本
wechattweak versions
```

如果微信安装在其他位置，可以通过 `--app` 指定应用路径：

```bash
wechattweak patch --app "/path/to/WeChat.app"
```

## 支持版本

| 微信 macOS 版本 | 内部版本 | 状态 |
| --- | --- | --- |
| 4.1.11 | `269136` | 已适配 |

Patch 时程序会根据微信的内部版本匹配配置。微信升级后，如果提示 `Unsupported WeChat version`，请先运行 `wechattweak versions` 确认版本，再等待项目更新补丁配置。

## 更新

```bash
brew update
brew upgrade wechattweak
```

## 参考

- [微信 macOS 客户端无限多开功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-wu-xian-duo-kai-gong-neng-shi-jian/)
- [微信 macOS 客户端拦截撤回功能实践](https://blog.sunnyyoung.net/wei-xin-macos-ke-hu-duan-lan-jie-che-hui-gong-neng-shi-jian/)
- [让微信 macOS 客户端支持 Alfred](https://blog.sunnyyoung.net/rang-wei-xin-macos-ke-hu-duan-zhi-chi-alfred/)

## 贡献者

This project exists thanks to all the people who contribute.

[![Contributors](https://contrib.rocks/image?repo=kong-kyle/WeChatTweak-kylekonge)](https://github.com/kong-kyle/WeChatTweak-kylekonge/graphs/contributors)

## License

The [AGPL-3.0](LICENSE).
