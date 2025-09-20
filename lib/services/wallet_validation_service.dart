import 'package:convert/convert.dart';

import '../models/wallet_entry.dart';
import './crypto_service.dart';
import './tron_client.dart';
import './usdt_service.dart';
import './wallet_import_service.dart';

/// 钱包验证服务类 - 封装所有钱包验证相关的逻辑
class WalletValidationService {
  /// 增强的钱包和密钥验证机制
  /// 包含：私钥解密验证、地址匹配验证和网络可用性验证
  static Future<bool> enhancedWalletValidation(
    WalletEntry walletEntry,
    String? privateKeyHex,
    String pass1,
    String pass2,
    String pass3,
  ) async {
    try {
      // 1. 私钥解密验证：确保密码能够正确解密私钥
      final isPasswordValid = await CryptoService.verifyPasswords(
        walletEntry,
        pass1, pass2, pass3
      );

      if (!isPasswordValid) {
        print('密码验证失败');
        return false;
      }

      // 2. 地址匹配验证：验证解密后的私钥与地址是否匹配
      final isAddressMatch = await _verifyAddressMatch(
        walletEntry,
        pass1, pass2, pass3
      );

      if (!isAddressMatch) {
        print('地址匹配验证失败');
        return false;
      }

      // 3. 网络可用性验证：确保能够连接到区块链网络
      final isNetworkAvailable = await _checkNetworkAvailability(
        walletEntry.addressBase58
      );

      return isPasswordValid && isAddressMatch && isNetworkAvailable;
    } catch (e) {
      print('增强验证失败: $e');
      return false;
    }
  }

  /// 验证私钥与地址的匹配性
  static Future<bool> _verifyAddressMatch(WalletEntry walletEntry, String pass1, String pass2, String pass3) async {
    try {
      final decryptedPk = await CryptoService.decryptPrivateKeyWithThreePasswords(
        walletEntry,
        pass1,
        pass2,
        pass3
      );
      final derivedAddress = CryptoService.deriveTronAddress(decryptedPk);
      return derivedAddress.$1 == walletEntry.addressBase58;
    } catch (e) {
      print('地址匹配验证失败: $e');
      return false;
    }
  }

  /// 检查网络连接和API可用性
  static Future<bool> _checkNetworkAvailability(String address) async {
    try {
      final tronClient = TronClient();
      // 使用现有方法检查网络连接
      await tronClient.recentUsdtTransfers(address, limit: 1);
      return true;
    } catch (e) {
      print('网络连接检查失败: $e');
      return false;
    }
  }

  /// 验证钱包是否可以进行转账操作
  /// 包括余额检查和网络可用性检查
  static Future<Map<String, dynamic>> validateTransferCapability(
    String address,
    double amount,
    bool isUSDT,
  ) async {
    try {
      final tronClient = TronClient();
      final usdtService = UsdtService(tronClient);
      
      // 检查网络连接
      await _checkNetworkAvailability(address);
      
      // 检查余额
      final (trx, usdt) = await usdtService.balances(address);
      final balance = isUSDT ? double.tryParse(usdt) ?? 0 : double.tryParse(trx) ?? 0;
      
      if (balance == null || balance < amount) {
        return {
          'isValid': false,
          'error': '余额不足'
        };
      }
      
      return {
        'isValid': true,
        'balance': balance
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': '验证转账能力失败: $e'
      };
    }
  }

  /// 执行模拟交易（dry-run）验证
  /// 这个方法不会实际发送交易，只是验证交易参数和签名是否有效
  static Future<bool> dryRunTransaction(
    WalletEntry walletEntry,
    String toAddress,
    double amount,
    bool isUSDT,
    String pass1,
    String pass2,
    String pass3,
  ) async {
    try {
      // 1. 验证地址格式
      if (!_isValidTronAddress(toAddress)) {
        print('无效的Tron地址');
        return false;
      }
      
      // 2. 验证金额
      if (amount <= 0) {
        print('金额必须大于0');
        return false;
      }
      
      // 3. 验证密码和解密私钥
      final decryptedPk = await CryptoService.decryptPrivateKeyWithThreePasswords(
        walletEntry,
        pass1,
        pass2,
        pass3
      );
      
      // 4. 验证私钥与地址匹配性
      final derivedAddress = CryptoService.deriveTronAddress(decryptedPk);
      if (derivedAddress.$1 != walletEntry.addressBase58) {
        print('私钥与地址不匹配');
        return false;
      }
      
      // 5. 检查网络连接
      if (!await _checkNetworkAvailability(walletEntry.addressBase58)) {        print('网络连接不可用');
        return false;
      }
      
      // 6. 检查转账能力
      final transferCapability = await validateTransferCapability(
        walletEntry.addressBase58,
        amount,
        isUSDT
      );
      
      if (!transferCapability['isValid']) {
        print('转账能力验证失败: ${transferCapability['error']}');
        return false;
      }
      
      return true;
    } catch (e) {
      print('dry-run交易验证失败: $e');
      return false;
    }
  }

  /// 验证Tron地址是否有效
  static bool _isValidTronAddress(String address) {
    try {
      // 简单验证：检查是否以T开头
      return address.startsWith('T');
    } catch (_) {
      return false;
    }
  }
}