# USDT Vault - Full Bundle with Main (2025-08-30)

**这是包含入口 `lib/main.dart` 的完整包**。集成后即可编译运行：
- 首启设置应用密码 + Face ID
- 钱包列表/创建/详情/转账（USDT & TRX）
- Hive 数据存储（使用 `Hive.box('wallets')`，无需 TypeAdapter）

## 集成步骤
1. 合并 `PUBSPEC_SNIPPET.yaml` 到项目 `pubspec.yaml`（若已有同名依赖，保留更高版本）。
2. 将 `lib/` 目录**全量覆盖**你的项目 `lib/`。
3. iOS 将 `IOS_Infoplist_SNIPPET.xml` 放入 `ios/Runner/Info.plist` 的 `<dict>` 内。
4. 运行：
   ```bash
   flutter clean
   flutter pub get
   cd ios && pod install --repo-update && cd ..
   flutter run -d <设备ID>
   ```
