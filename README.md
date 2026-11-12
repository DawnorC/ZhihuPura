# 知乎Pura · HarmonyOS

知乎Pura 是第三方知乎客户端，基于开源项目 [Zhihu++](https://github.com/zly2006/zhihu-plus-plus) 移植到 HarmonyOS，使用 ArkTS 和 ArkUI 开发。当前处于开发阶段。

## 已实现

- 首页推荐、关注动态、热榜、知乎日报和搜索。
- 浏览问题、回答、文章、想法、评论与子评论，以及用户主页。
- 在应用内登录知乎并恢复上次登录状态。
- 本地屏蔽词和浏览历史。历史保留最近 200 条，支持重新打开与逐条删除。

收藏夹、通知和内容创作仍待移植。部分知乎接口需要登录或完成网页验证。

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
