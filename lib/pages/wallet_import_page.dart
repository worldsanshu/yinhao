import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/wallet_entry.dart';

class WalletImportPage extends StatefulWidget {
  const WalletImportPage({super.key});

  @override
  State<WalletImportPage> createState() => _WalletImportPageState();
}

class _WalletImportPageState extends State<WalletImportPage> {
  final TextEditingController _input = TextEditingController();
  final List<_ImportItem> _items = [];
  bool _busy = false;

  @override
  void dispose() {
    for (final it in _items) {
      it.nameCtrl.dispose();
    }
    _input.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text?.trim().isEmpty ?? true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
      return;
    }
    _input.text = data!.text!.trim();
  }

  void _clearPreview() {
    for (final it in _items) it.nameCtrl.dispose();
    _items.clear();
    setState(() {});
  }

  Future<void> _parse() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先粘贴导出 JSON')));
      return;
    }
    setState(() => _busy = true);
    try {
      final List<Map<String, dynamic>> maps = _coerceToEntryMaps(raw);
      if (maps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未解析到任何钱包条目')));
        return;
      }
      _clearPreview();
      for (final m in maps) {
        final e = WalletEntry.fromJson(m);
        _items.add(_ImportItem(entry: e, nameCtrl: TextEditingController(text: e.name ?? '')));
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('解析失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 兼容三种输入：
  /// 1) [ {entry}, {entry} ] 纯数组
  /// 2) { "wallets": [ {entry}, ... ] } 包装对象
  /// 3) {entry} 单个
  /// 同时宽容 NDJSON（多行每行一个 JSON）
  List<Map<String, dynamic>> _coerceToEntryMaps(String s) {
    dynamic root;
    try {
      root = jsonDecode(s);
    } catch (_) {
      // 尝试 NDJSON
      final maps = <Map<String, dynamic>>[];
      for (final line in s.split('\n')) {
        final t = line.trim();
        if (t.isEmpty) continue;
        final v = jsonDecode(t);
        if (v is Map<String, dynamic>) maps.add(v);
      }
      return maps;
    }

    if (root is List) {
      return root.cast<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (root is Map) {
      final m = Map<String, dynamic>.from(root);
      if (m['wallets'] is List) {
        return (m['wallets'] as List)
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
      return [m]; // 单个 entry
    }
    return const [];
  }

  Future<void> _saveAll() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('没有可保存的条目')));
      return;
    }
    setState(() => _busy = true);
    try {
      final box = Hive.box('wallets');
      int saved = 0;

      for (final it in _items) {
        var e = it.entry;

        // 应用“名称/备注”修改
        final name = it.nameCtrl.text.trim();
        e = e.copyWith(name: name.isEmpty ? null : name);

        // 防止 id 冲突：若已存在同 id，则换一个新 id
        if (box.containsKey(e.id)) {
          e = e.copyWith(id: const Uuid().v4());
        }

        await box.put(e.id, e.toJson());
        saved++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已导入并保存 $saved 个钱包')));
      Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入钱包（支持重命名）'),
        actions: [
          IconButton(
            tooltip: '清空',
            onPressed: _busy ? null : () { _input.clear(); _clearPreview(); },
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _input,
              maxLines: 8,
              decoration: InputDecoration(
                labelText: '粘贴导出 JSON（可为单个条目或导出集合）',
                alignLabelWithHint: true,
                hintText: '粘贴以 T 开头地址、盐、密文等完整 JSON',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: '从剪贴板粘贴',
                  icon: const Icon(Icons.paste),
                  onPressed: _busy ? null : _pasteFromClipboard,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _parse,
                    icon: _busy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label: const Text('解析预览'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _items.isEmpty) ? null : _saveAll,
                    icon: const Icon(Icons.save),
                    label: Text('保存${_items.isEmpty ? '' : '（${_items.length}）'}'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _items.isEmpty
                ? const Center(child: Text('解析结果会显示在这里，可逐个修改“钱包名称/备注”后保存'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final it = _items[i];
                      final e = it.entry;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.addressBase58,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('v${e.version}', style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('创建时间：${e.createdAt}'),
                              const SizedBox(height: 12),
                              TextField(
                                controller: it.nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: '钱包名称/备注（可选）',
                                  hintText: '例如：常用账户/冷钱包/交易所划转',
                                  prefixIcon: Icon(Icons.edit),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('ID: ${e.id}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ImportItem {
  final WalletEntry entry;
  final TextEditingController nameCtrl;
  _ImportItem({required this.entry, required this.nameCtrl});
}
