// lib/widgets/add_address_dialog.dart

import 'package:flutter/material.dart';
import '../models/address_book.dart';
import '../services/address_book_service.dart';
import 'dart:math';

class AddAddressDialog extends StatefulWidget {
  const AddAddressDialog({super.key});

  @override
  State<AddAddressDialog> createState() => _AddAddressDialogState();
}

class _AddAddressDialogState extends State<AddAddressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _memoController = TextEditingController();
  bool _isLoading = false;
  String? _addressError;

  // 验证地址格式
  bool _isValidAddress(String address) {
    // 简单检查：Tron地址以T开头，长度在25-50之间
    final regex = RegExp(r'^T[1-9A-HJ-NP-Za-km-z]{25,50}$');
    return regex.hasMatch(address);
  }

  Future<void> _validateAndAddAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final memo = _memoController.text.trim();

    // 检查地址是否已存在
    if (await AddressBookService.isAddressExists(address)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该地址已存在于地址簿中')),
        );
      }
      return;
    }

    try {
      setState(() => _isLoading = true);

      // 初始化地址簿服务
      await AddressBookService.init();
      
      // 添加到地址簿
      final newEntry = AddressBookEntry(
        id: _generateId(),
        name: name,
        address: address,
        memo: memo.isEmpty ? null : memo,
      );
      
      await AddressBookService.addAddress(
        name: name,
        address: address,
        memo: memo.isEmpty ? null : memo,
      );

      if (mounted) {
        // 返回结果给调用方
        Navigator.pop(context, newEntry);
      }
    } catch (e) {
      print('添加地址失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加地址失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // 生成唯一ID
  String _generateId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = screenSize.width * 0.8; // 对话框宽度为屏幕宽度的80%

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: theme.colorScheme.surface,
      elevation: 8,
      child: SizedBox(
        width: dialogWidth,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Text(
                  '添加收款地址',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                
                const SizedBox(height: 24),

                // 地址名称
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: '地址名称',
                    hintText: '例如：张三的钱包',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入地址名称';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 地址 - 改为多行显示
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Tron地址',
                    hintText: '以T开头的地址',
                    errorText: _addressError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入地址';
                    }
                    if (!_isValidAddress(value.trim())) {
                      return '请输入有效的Tron地址';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    if (_addressError != null) {
                      setState(() => _addressError = null);
                    }
                  },
                  keyboardType: TextInputType.multiline,
                  maxLines: 3, // 多行显示
                  textAlignVertical: TextAlignVertical.top,
                ),

                const SizedBox(height: 16),

                // 备注（可选）
                TextFormField(
                  controller: _memoController,
                  decoration: InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '添加一些备注信息，方便识别',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, 
                      vertical: 12
                    ),
                  ),
                  maxLines: 3, // 增加备注输入框的行数
                  textAlignVertical: TextAlignVertical.top,
                ),

                const SizedBox(height: 20),

                // 安全提示
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning, 
                        color: theme.colorScheme.error, 
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '请仔细核对地址，添加错误地址可能导致资产损失',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20, 
                          vertical: 10
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _isLoading ? null : _validateAndAddAddress,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24, 
                          vertical: 10
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('添加'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}