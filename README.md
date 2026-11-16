# 知乎Pura · HarmonyOS

知乎Pura 是第三方知乎客户端，基于开源项目 [Zhihu++](https://github.com/zly2006/zhihu-plus-plus) 移植到 HarmonyOS，使用 ArkTS 和 ArkUI 开发。当前处于开发阶段。

## 已实现

- 首页推荐、关注动态、热榜和知乎日报。
- 搜索支持热搜、本机搜索历史，以及按内容类型、排序和时间筛选。
- 浏览问题、回答、文章、想法和用户主页。评论支持查看子评论，一级评论可按热度或时间排序。
- 登录后可在「我的 → 收藏夹」查看自己的收藏夹并打开收藏内容。
- 原生手机号验证码登录支持知乎的图形验证码和短信验证。原生扫码入口生成二维码并等待知乎 App 确认，遇到知乎安全验证时可单独处理后返回扫码。另支持 Cookie 登录。账号校验通过后保存登录状态。
- 本地屏蔽词和浏览历史。本机历史保留最近 200 条，登录后可查看知乎在线历史，两者均支持逐条删除。

收藏夹管理、通知和内容创作仍待移植。部分知乎接口需要登录或完成网页验证。

## 构建与运行

1. 安装 DevEco Studio 和 HarmonyOS 26.0.0 SDK。
2. 用 DevEco Studio 打开仓库根目录，选择 `default` 产品和 `default` 应用模块。
3. 连接 HarmonyOS 真机或启动兼容的模拟器。真机调试需要在本地配置签名。

也可在仓库根目录用 DevEco CLI 构建和运行：

```powershell
devecocli build
devecocli device list
devecocli run --module default
```

多个设备在线时，通过 `--device` 指定调试目标。签名、SDK 路径和设备设置按本机环境配置。

## 工程结构

- `AppScope/` 保存应用级配置与图标资源。
- `products/default/` 包含 ArkUI 页面、导航和应用入口。
- `common/` 包含知乎接口、会话、内容模型和本地存储。

## 许可证

本项目遵循 [GNU Affero General Public License v3.0](LICENSE)。原版 Zhihu++ 由 zly2006 和社区贡献者开发，原版版权归其作者所有。
