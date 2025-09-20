// lib/services/address_book_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import '../models/address_book.dart';
import 'dart:math';

class AddressBookService {
  static const String _boxName = 'address_book';
  static Box<AddressBookEntry>? _box;

  // 初始化Hive盒子
  static Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<AddressBookEntry>(_boxName);
    }
  }

  // 生成唯一ID
  static String _generateId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // 添加新地址
  static Future<AddressBookEntry> addAddress({
    required String name,
    required String address,
    String? memo,
  }) async {
    await init();
    
    final entry = AddressBookEntry(
      id: _generateId(),
      name: name,
      address: address,
      memo: memo,
    );
    
    await _box!.put(entry.id, entry);
    return entry;
  }

  // 获取所有地址
  static Future<List<AddressBookEntry>> getAllAddresses() async {
    await init();
    
    // 按更新时间倒序排列
    final entries = _box!.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    return entries;
  }

  // 根据ID获取地址
  static Future<AddressBookEntry?> getAddressById(String id) async {
    await init();
    return _box!.get(id);
  }

  // 更新地址
  static Future<AddressBookEntry> updateAddress(
    String id,
    AddressBookEntry updatedEntry,
  ) async {
    await init();
    
    if (!_box!.containsKey(id)) {
      throw Exception('地址不存在');
    }
    
    await _box!.put(id, updatedEntry);
    return updatedEntry;
  }

  // 删除地址
  static Future<void> deleteAddress(String id) async {
    await init();
    if (_box!.containsKey(id)) {
      await _box!.delete(id);
    }
  }

  // 搜索地址（按名称或地址）
  static Future<List<AddressBookEntry>> searchAddresses(String query) async {
    if (query.isEmpty) {
      return getAllAddresses();
    }
    
    await init();
    final lowerQuery = query.toLowerCase();
    
    return _box!.values
        .where((entry) => 
            entry.name.toLowerCase().contains(lowerQuery) ||
            entry.address.toLowerCase().contains(lowerQuery))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  // 检查地址是否已存在
  static Future<bool> isAddressExists(String address) async {
    await init();
    return _box!.values.any((entry) => 
        entry.address.toLowerCase() == address.toLowerCase());
  }

  // 关闭盒子（通常在应用退出时调用）
  static Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
      _box = null;
    }
  }
}