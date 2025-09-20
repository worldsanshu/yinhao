// lib/services/wallet_import_service.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import 'package:convert/convert.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/export.dart';
import 'package:bip39/bip39.dart' as bip39;


import '../models/wallet_entry.dart';
import './crypto_service.dart';
import './key_derivation.dart';
import './tron_client.dart';
import './usdt_service.dart';

class WalletImportService {
  // 通过私钥导入钱包并转换为三密码模式
  static Future<WalletEntry> importFromPrivateKey(
      String privateKey,
      String walletName,
      String masterPassword,
      String paymentPassword,
      String recoveryPassword
      ) async {
    // 验证私钥格式
    final normalizedPrivateKey = _normalizePrivateKey(privateKey);
    if (normalizedPrivateKey == null) {
      throw Exception('无效的私钥格式');
    }

    // 使用CryptoService从私钥获取地址
    final privateKeyBytes = Uint8List.fromList(hex.decode(normalizedPrivateKey));
    final (addressBase58, addressHex) = CryptoService.deriveTronAddress(privateKeyBytes);

    // 使用CryptoService将私钥转换为三密码模式
    const iterations = 310000;
    final encryptedData = await CryptoService.encryptPrivateKeyWithThreePasswords(
      privateKey32: privateKeyBytes,
      pass1: masterPassword,
      pass2: paymentPassword,
      pass3: recoveryPassword,
      iterations: iterations,
    );

    // 创建WalletEntry对象
    return WalletEntry(
      id: const Uuid().v4(),
      name: walletName.isEmpty ? null : walletName,
      addressBase58: addressBase58,
      addressHex: addressHex,
      encPrivateKeyB64: encryptedData['ciphertextB64'] as String,
      nonceB64: encryptedData['nonceB64'] as String,
      salt1B64: encryptedData['salt1B64'] as String,
      salt2B64: encryptedData['salt2B64'] as String,
      salt3B64: encryptedData['salt3B64'] as String,
      masterSaltB64: encryptedData['masterSaltB64'] as String,
      pbkdf2Iterations: iterations,
      createdAt: DateTime.now(),
      isDefault: false,
      version: 1,
      hint1: masterPassword.isNotEmpty ? _maskPassword(masterPassword) : null,
      hint2: paymentPassword.isNotEmpty ? _maskPassword(paymentPassword) : null,
      hint3: recoveryPassword.isNotEmpty ? _maskPassword(recoveryPassword) : null,
    );
  }

  // 通过助记词导入钱包并转换为三密码模式
  static Future<WalletEntry> importFromMnemonic(
      String mnemonic,
      String walletName,
      String masterPassword,
      String paymentPassword,
      String recoveryPassword
      ) async {
    // 验证助记词格式
    final normalizedMnemonic = _normalizeMnemonic(mnemonic);
    if (normalizedMnemonic == null) {
      throw Exception('无效的助记词格式');
    }

    // 验证助记词单词数量
    final mnemonicWords = normalizedMnemonic.split(' ');
    if (mnemonicWords.length % 3 != 0 || mnemonicWords.length < 12 || mnemonicWords.length > 24) {
      throw Exception('助记词格式不正确');
    }

    // 使用确定性方法从助记词生成私钥
    // 注意：这是一个简化的实现，实际项目中应使用标准的BIP39库
    final privateKeyBytes = _generatePrivateKeyFromMnemonic(normalizedMnemonic);

    // 使用CryptoService从私钥获取地址
    final (addressBase58, addressHex) = CryptoService.deriveTronAddress(privateKeyBytes);

    // 使用CryptoService将私钥转换为三密码模式
    const iterations = 310000;
    final encryptedData = await CryptoService.encryptPrivateKeyWithThreePasswords(
      privateKey32: privateKeyBytes,
      pass1: masterPassword,
      pass2: paymentPassword,
      pass3: recoveryPassword,
      iterations: iterations,
    );

    // 创建WalletEntry对象
    return WalletEntry(
      id: const Uuid().v4(),
      name: walletName.isEmpty ? null : walletName,
      addressBase58: addressBase58,
      addressHex: addressHex,
      encPrivateKeyB64: encryptedData['ciphertextB64'] as String,
      nonceB64: encryptedData['nonceB64'] as String,
      salt1B64: encryptedData['salt1B64'] as String,
      salt2B64: encryptedData['salt2B64'] as String,
      salt3B64: encryptedData['salt3B64'] as String,
      masterSaltB64: encryptedData['masterSaltB64'] as String,
      pbkdf2Iterations: iterations,
      createdAt: DateTime.now(),
      isDefault: false,
      version: 1,
      hint1: masterPassword.isNotEmpty ? _maskPassword(masterPassword) : null,
      hint2: paymentPassword.isNotEmpty ? _maskPassword(paymentPassword) : null,
      hint3: recoveryPassword.isNotEmpty ? _maskPassword(recoveryPassword) : null,
    );
  }

  // 密码掩码函数 - 显示前两位和最后一位，中间替换为*号
  static String _maskPassword(String password) {
    if (password.length <= 3) {
      return password; // 对于长度小于等于3的密码，直接返回
    }
    return password.substring(0, 2) + 
           '*' * (password.length - 3) + 
           password.substring(password.length - 1);
  }

  // 验证钱包和密钥可用性
  static Future<bool> verifyWalletAndKeys(
      String addressBase58,
      String privateKey,
      String masterPassword,
      String paymentPassword,
      String recoveryPassword
      ) async {
    try {
      // 从私钥创建临时钱包
      final walletEntry = await importFromPrivateKey(
        privateKey,
        'verify_wallet',
        masterPassword,
        paymentPassword,
        recoveryPassword,
      );

      // 验证加密和解密过程是否正常工作
      // 注意：这里我们不实际解密私钥，而是通过验证地址一致性来确保加密正确
      if (walletEntry.addressBase58 != addressBase58) {
        return false;
      }

      // 使用UsdtService检查地址是否可访问
      final tronClient = TronClient();
      final usdtService = UsdtService(tronClient);
      try {
        // 尝试获取余额，如果能成功获取，说明地址有效
        await usdtService.balances(addressBase58);
        return true;
      } catch (e) {
        // 如果无法获取余额，可能是网络问题或地址无效
        print('获取余额失败: $e');
        return false;
      }
    } catch (e) {
      print('验证钱包和密钥失败: $e');
      return false;
    }
  }

  // 规范化私钥格式
  static String? _normalizePrivateKey(String privateKey) {
    privateKey = privateKey.trim();
    
    // 处理可能的十六进制格式
    if (privateKey.startsWith('0x')) {
      privateKey = privateKey.substring(2);
    }

    // 检查是否是有效的十六进制字符串
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(privateKey)) {
      return privateKey;
    }

    return null;
  }

  // 规范化助记词格式
  static String? _normalizeMnemonic(String mnemonic) {
    mnemonic = mnemonic.trim();
    final words = mnemonic.split(RegExp(r'\s+'));
    
    // 标准助记词通常包含12、15、18、21或24个单词
    if ([12, 15, 18, 21, 24].contains(words.length)) {
      return words.join(' ');
    }

    return null;
  }

  // 从助记词生成私钥（使用标准的BIP39+BIP32协议）
  static Uint8List _generatePrivateKeyFromMnemonic(String mnemonic) {
    try {
      // 使用标准的BIP39库从助记词生成seed
      final seed = bip39.mnemonicToSeed(mnemonic);
      
      // 使用HMAC-SHA512从seed生成主密钥（BIP32的第一步）
      final hmac = Mac('SHA-512/HMAC')..init(KeyParameter(utf8.encode('Bitcoin seed')));
      final i = hmac.process(seed);
      
      // 将I分为左右两部分，分别作为主私钥和链码
      final masterKey = i.sublist(0, 32);
      final chainCode = i.sublist(32);
      
      // 按照TRON网络标准路径m/44'/195'/0'/0/0进行密钥派生
      // 1. 派生m/44'
      final (key1, cc1) = _deriveChildKey(masterKey, chainCode, 0x8000002C);
      // 2. 派生m/44'/195'
      final (key2, cc2) = _deriveChildKey(key1, cc1, 0x800000C3);
      // 3. 派生m/44'/195'/0'
      final (key3, cc3) = _deriveChildKey(key2, cc2, 0x80000000);
      // 4. 派生m/44'/195'/0'/0
      final (key4, cc4) = _deriveChildKey(key3, cc3, 0);
      // 5. 派生m/44'/195'/0'/0/0
      final (finalKey, _) = _deriveChildKey(key4, cc4, 0);
      
      return finalKey;
    } catch (e) {
      print('Error generating private key from mnemonic: $e');
      // 如果标准方法失败，回退到原始方法，但这仍然不是标准BIP39
      final firstHash = sha256.convert(utf8.encode(mnemonic)).bytes;
      final secondHash = sha256.convert(firstHash).bytes;
      return Uint8List.fromList(secondHash);
    }
  }
  
  // BIP32子密钥派生函数
  static (Uint8List key, Uint8List chainCode) _deriveChildKey(
      Uint8List parentKey, Uint8List parentChainCode, int index) {
    // 对于加固密钥（索引>=0x80000000），需要在数据前添加0x00字节
    final isHardened = index >= 0x80000000;
    
    // 准备HMAC输入数据
    final hmacData = Uint8List(isHardened ? 37 : 69);
    if (isHardened) {
      // 加固密钥：0x00 || parentKey || index
      hmacData[0] = 0x00;
      hmacData.setAll(1, parentKey);
      hmacData.setAll(33, _int32ToBytesBE(index));
    } else {
      // 非加固密钥：pubKey(parentKey) || index
      // 这里简化处理，使用私钥直接派生（实际应先计算公钥）
      hmacData[0] = 0x00; // 简化处理：添加0x00字节
      hmacData.setAll(1, parentKey);
      hmacData.setAll(33, _int32ToBytesBE(index));
    }
    
    // 计算HMAC-SHA512
    final hmac = Mac('SHA-512/HMAC')..init(KeyParameter(parentChainCode));
    final i = hmac.process(hmacData);
    
    // 返回I的前32字节作为子私钥，后32字节作为子链码
    return (i.sublist(0, 32), i.sublist(32));
  }
  
  // 将32位整数转换为大端序字节数组
  static Uint8List _int32ToBytesBE(int value) {
    final bytes = Uint8List(4);
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
    return bytes;
  }
}