// lib/models/address_book.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

part 'address_book.g.dart';

@HiveType(typeId: 3) // 确保这个类型ID在项目中是唯一的
class AddressBookEntry {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String address;
  
  @HiveField(3)
  final String? memo;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime updatedAt;

  AddressBookEntry({
    required this.id,
    required this.name,
    required this.address,
    this.memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  AddressBookEntry copyWith({
    String? name,
    String? address,
    String? memo,
  }) {
    return AddressBookEntry(
      id: id,
      name: name ?? this.name,
      address: address ?? this.address,
      memo: memo ?? this.memo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory AddressBookEntry.fromJson(Map<String, dynamic> json) {
    return AddressBookEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      memo: json['memo'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() => jsonEncode(toJson());
}