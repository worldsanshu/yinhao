// lib/widgets/address_picker_sheet.dart

import 'package:flutter/material.dart';
import '../models/address_book.dart';
import '../services/address_book_service.dart';

class AddressPickerSheet extends StatefulWidget {
  const AddressPickerSheet({
    super.key,
    required this.onSelectAddress,
    this.onAddNewAddress,
  });

  final void Function(AddressBookEntry entry) onSelectAddress;
  final VoidCallback? onAddNewAddress;

  @override
  State<AddressPickerSheet> createState() => _AddressPickerSheetState();
}

class _AddressPickerSheetState extends State<AddressPickerSheet> {
  List<AddressBookEntry> _addresses = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() => _isLoading = true);
      final addresses = await AddressBookService.searchAddresses(_searchQuery);
      setState(() {
        _addresses = addresses;
        _isLoading = false;
      });
    } catch (e) {
      print('加载地址簿失败: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSearch(String query) async {
    setState(() {
      _searchQuery = query;
    });
    await _loadAddresses();
  }

  Widget _buildAddressItem(AddressBookEntry entry) {
    // 显示地址的前后部分，中间用省略号代替
    String formatAddress(String address) {
      if (address.length <= 10) return address;
      return '${address.substring(0, 5)}...${address.substring(address.length - 5)}';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(entry.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatAddress(entry.address)),
            if (entry.memo != null && entry.memo!.isNotEmpty)
              Text(
                '备注: ${entry.memo}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        onTap: () => widget.onSelectAddress(entry),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 头部
          Row(
            children: [
              Text(
                '选择收款地址',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索地址名称或地址',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant,
              ),
              onChanged: _handleSearch,
            ),
          ),

          // 添加新地址按钮
          if (widget.onAddNewAddress != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton.icon(
                onPressed: widget.onAddNewAddress,
                icon: const Icon(Icons.add),
                label: const Text('添加新地址'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // 地址列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _addresses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                            _searchQuery.isNotEmpty
                                ? [
                                    const Icon(Icons.search_off, size: 64),
                                    const SizedBox(height: 16),
                                    Text('未找到匹配的地址'),
                                  ]
                                : [
                                    const Icon(Icons.contact_mail, size: 64),
                                    const SizedBox(height: 16),
                                    Text('地址簿为空'),
                                    if (widget.onAddNewAddress != null)
                                      TextButton(
                                        onPressed: widget.onAddNewAddress,
                                        child: const Text('添加第一个地址'),
                                      ),
                                  ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) =>
                            _buildAddressItem(_addresses[index]),
                      ),
          ),
        ],
      ),
    );
  }
}