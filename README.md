

# 银号有他USDT钱包说明
本钱包完全开源，无条件使用，无需联网，完全私密~~~~
做了一个官网：www.yinhao.me
## 开发初衷
- 1、赚的都是U，担心有一天有不测，对后事有个提前交代的而准备；
- 2、需要有一个比较隐秘的方式，把钱包分享给你想分享的人；钱包创建需要设置3个密码，这个密码可能只有你自己或者和你挂念的人才知道，为了防止密码丢失，本钱包也做了及其友好的密码提示，高度提升了对非相关人的隐秘性;
- 3、需要做一个放追踪隔离的钱包

出门在外/赚钱不易，为有家庭的、有孩子的、有想念的人做个备份；


# USDT Vault v0.2.0
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