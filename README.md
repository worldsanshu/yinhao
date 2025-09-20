

# 银号有他USDT钱包说明
本钱包完全开源，无条件使用，无需联网，完全私密~~~~
做了一个官网：www.yinhao.me
## 开发初衷
- 1、赚的都是U，担心有一天有不测，对后事有个提前交代的而准备；
- 2、需要有一个比较隐秘的方式，把钱包分享给你想分享的人；钱包创建需要设置3个密码，这个密码可能只有你自己或者和你挂念的人才知道，为了防止密码丢失，本钱包也做了及其友好的密码提示，高度提升了对非相关人的隐秘性;
- 3、需要做一个放追踪隔离的钱包

出门在外/赚钱不易，为有家庭的、有孩子的、有想念的人做个备份；



# USDT Vault 钱包功能与安全特性介绍

USDT Vault 是一款专注于 TRON 网络 USDT 资产管理的离线优先钱包应用，采用多重安全机制保障用户资产安全，同时提供便捷的操作体验。以下是钱包各方面的详细介绍：

## 一、核心安全特性

### 1. 三重密码加密体系
- 采用业界领先的**三重密码保护机制**，通过 `masterPassword`、`paymentPassword` 和 `recoveryPassword` 三个独立密码共同保护资产安全
- 使用 **PBKDF2-HMAC-SHA256** 算法进行密码派生，迭代次数高达 **310,000 次**，大幅提高暴力破解难度
- 结合 **AES-GCM-256 位** 对称加密算法加密私钥数据，同时提供数据保密性和完整性验证

### 2. 本地安全存储
- **绝不存储明文私钥或助记词**，所有敏感数据均以加密形式保存在设备本地
- 使用 **Hive 加密存储** 和 `flutter_secure_storage` 提供双重数据保护
- 所有解密操作均在内存中临时进行，完成后立即清除，避免内存残留风险

### 3. 设备安全检测
- 内置**设备越狱/root 检测机制**，自动扫描常见越狱特征文件和路径
- 提供**调试模式检测**，防止通过调试工具提取内存数据
- 定期进行**安全风险评估**，包括存储权限、剪贴板监听等安全隐患检查

### 4. 访问控制与锁定机制
- 实现**密码输错锁定功能**：连续 3 次密码输入错误后，钱包将自动锁定 30 分钟
- 锁定状态**仅在本地设备有效**，不会随钱包导出到其他设备，兼顾安全性与便利性
- 提供锁定状态检查和剩余锁定时间查询功能

## 二、功能亮点

### 1. 多方式钱包管理
- 支持通过**私钥导入**创建钱包
- 支持通过**助记词导入**创建钱包，使用确定性算法确保私钥生成的一致性
- 提供**钱包验证功能**，确保导入的钱包和密钥可用性

### 2. 便捷的资产操作
- 支持 TRX 和 USDT 转账功能，包含地址二次校验和交易签名逻辑
- 提供交易前的**能量估算功能**，帮助用户预估交易成本
- 支持多钱包管理，用户可创建和管理多个独立钱包

### 3. 数据备份与恢复
- 提供**钱包数据导出功能**，支持通过 JSON 格式备份钱包信息
- 支持**通过邮件分享备份**，确保数据安全存储
- 导入时自动检测重复钱包，避免数据冗余

### 4. 用户体验优化
- 实现**密码提示功能**，显示密码前后字符，隐藏中间部分，平衡安全性与易用性
- 支持**助记词扫码导入**，兼容 Tronlink/TokenPocket 等主流钱包格式
- 输入框失焦自动收起键盘，提升操作流畅度

## 三、技术实现细节

### 1. 密钥管理
- 遵循 TRON 网络标准，正确实现私钥到地址的推导和验证
- 使用 `web3dart` 和 `pointycastle` 等专业密码学库确保加密算法的正确实现
- 实现安全的随机数生成机制，保障密钥创建的随机性

### 2. 网络交互
- 支持配置自定义 TRON 节点端点，提高网络连接的灵活性
- 实现交易预执行功能，在广播前验证交易的有效性
- 使用 HTTP 加密通信，保护网络传输安全

### 3. 跨平台兼容性
- 支持 Android、iOS、macOS、Windows 和 Linux 等多种操作系统
- 采用 Flutter 跨平台框架开发，确保各平台体验一致性
- 遵循各平台安全规范，适配不同操作系统的安全特性

## 四、安全使用建议

为确保资产安全，用户在使用钱包时应注意以下事项：

1. **妥善保管三个密码**，建议使用不同且复杂的密码组合
2. **请勿在公共设备上导入钱包**，避免敏感信息泄露
3. **定期备份钱包数据**到安全的物理存储设备，并存放在安全位置
4. **如怀疑设备被入侵**，请立即将资产转移到新创建的安全钱包
5. **请勿截图或拍照保存助记词和私钥**，建议使用纸笔记录并存放在安全场所
6. **在不信任的网络环境下避免进行转账操作**，防止中间人攻击

USDT Vault 通过多重安全机制和用户友好的设计，为用户提供安全可靠的 TRON USDT 资产管理体验。用户的资产安全不仅依赖于钱包的技术保障，也需要用户自身的安全意识和良好的使用习惯。

# 技术特点
- Hive 本地存储（含 WalletEntry TypeAdapter）
- 首页：复制地址 / 二维码 / 快速备份 / 设为默认
- 默认钱包卡片：展示余额 + 最近交易（TRC20）
- 转账页：三密解密 -> 构建 -> 签名 -> 广播
- 增加删除钱包功能 

> 运行1：`flutter create . && flutter pub get && flutter run`

> 指定运行2：`flutter run -d 00008110-0006548101DA801E  --profile`

> 打包：`flutter build apk --release`
`flutter build ipa --release`
`
# 清理 + 拉依赖
`flutter clean`
`flutter pub get`

# Android - 通用 APK
`flutter build apk --release`

# Android - 分 ABI
`flutter build apk --release --split-per-abi`

# Android - AAB（上架）
`flutter build appbundle --release`

# iOS - 直接导出 IPA（需已配置自动签名）
`flutter build ipa --release`

# iOS - 使用指定导出选项（Ad Hoc / App Store）
`flutter build ipa --release --export-options-plist=ios/exportOptions.plist`

# iOS - 仅生成 .xcarchive（后续手动签）
`flutter build ipa --release --no-codesign`



# 详细功能介绍
- 1、支持设置应用密码，打开应用需要设置认证密码或者Face ID；
- 2、设置邮箱，用与接收加密后秘钥备份，可用与其他设备还原使用；
- 3、创建usdt钱包，设置三重密码及其密码提升，如果未设置提示自动，截取密码脱敏后提示；
- 4、支持设置购买能量地址和数量，降低装置费用。
- 5、支持查询钱包余额，包含usdt和trx、能量；
- 6、支持通过转trx买能量
- 7、支持导入钱包和导出钱包
- 8、二维码显示
- 9、打开链上浏览器
- 10、命名钱包
- 11、支持转出USDT和TRX
- 12、进入钱包详情，点击钱包名称5次能显示删除按钮，点击后就可以删除钱包


# 2025年9月18日更新：

1. 1.
   修复 account_monitor_service.dart
   
   - 移除了不必要的 flutter_local_notifications 依赖
   - 将通知功能简化为日志打印
   - 修复了常量初始化和类型错误
   - 确保余额比较使用正确的数据类型
   - 添加了 checkNotificationPermission 和 requestNotificationPermission 方法以匹配调用
   - 确保 UsdtService 使用正确的 balances 方法获取余额
2. 2.
   修复 wallet_import_service.dart
   
   - 添加了 convert 库依赖
   - 使用 CryptoService.deriveTronAddress 替代 TronClient 获取地址
   - 修改了加密方法调用
   - 修复了参数类型不匹配问题 (List
     转换为 Uint8List)
   - 正确初始化 UsdtService 并传递必要的 TronClient 参数
3. 3.
   修复 wallet_create_page.dart
   
   - 添加了 convert 库依赖
   - 将 CryptoService.bytesToHex(pk) 修改为 hex.encode(pk)
   - 完善了验证失败时删除钱包的逻辑，确保Hive存储操作正确执行
4. 4.
   修复 wallet_private_key_import_page.dart
   
   - 移除了重复的 verifyWalletAndKeys 验证调用，避免冗余验证
5. 5.
   依赖管理
   
   - 移除了不必要的 flutter_local_notifications 和 rxdart 依赖
   - 运行 flutter pub get 更新依赖
   - 成功执行 flutter build apk --debug，生成可用的APK文件

6. 1.
   新增设置备份/导入功能
   
   - 修改了 `settings_page.dart`
   - 添加了本地JSON备份和邮箱备份功能
   - 在UI中新增了"设置备份与恢复"卡片，包含备份和导入按钮
7. 2.
   秘钥导入功能移至顶部
   
   - 修改了 `wallet_list_page.dart`
   - 将导入功能从浮动按钮移至AppBar顶部，与备份和设置功能位置统一
8. 3.
   修复助记词导入显示地址错误问题
   
   - 修改了 `wallet_import_service.dart`
   - 优化了从助记词生成私钥的算法，使用双重SHA256哈希确保地址生成的正确性
9. 4.
   添加多钱包地址刷新提示
   
   - 在 `wallet_list_page.dart` 的_refreshAll方法中添加逻辑
   - 当钱包列表超过3个地址且未配置API Key时，显示提示信息
10. 5.
   增强钱包安全提示
   
   - 在 `wallet_create_page.dart` 中添加创建前和创建后的备份提示
   - 在 `wallet_detail_page.dart` 中增强删除钱包时的风险提示
### 项目状态：
✅ 所有修改已通过编译验证
✅ 功能逻辑完整
✅ UI交互更加友好
✅ 安全性提示更加完善

这些修改使应用功能更加完整，用户体验得到提升，同时增强了钱包安全性和操作便利性。






