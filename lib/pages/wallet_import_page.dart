// lib/pages/wallet_import_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/wallet_entry.dart';

class WalletImportPage extends StatefulWidget {
  const WalletImportPage({super.key});

  @override
  State<WalletImportPage> createState() => _WalletImportPageState();
}

class _WalletImportPageState extends State<WalletImportPage> {
  final _input = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _busy = false;
  bool _overwrite = false; // 覆盖已存在的钱包（默认关闭：重复即跳过）

  final List<_ImportItem> _items = [];

  @override
  void dispose() {
    _input.dispose();
    for (final it in _items) {
      it.nameCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _items.isNotEmpty && !_busy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入钱包'),
        actions: [
          TextButton(
            onPressed: canSave ? _saveAll : null,
            child: Text(
              _busy ? '保存中...' : '保存(${_items.length})',
              style: TextStyle(
                color: canSave
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).disabledColor,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('将导出的 JSON 粘贴到下面（支持单条对象或数组）'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _input,
              minLines: 6,
              maxLines: 12,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: '{ "id": "...", "addressBase58": "...", ... }  或  [ {...}, {...} ]',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _parse,
                  icon: const Icon(Icons.search),
                  label: const Text('解析'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _clearPreview,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空预览'),
                ),
                const Spacer(),
                // 可选：覆盖已存在
                Row(
                  children: [
                    const Text('覆盖已存在'),
                    Switch(
                      value: _overwrite,
                      onChanged: (v) => setState(() => _overwrite = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              _blank()
            else
              ..._items.map((it) => _previewTile(it)).toList(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // —— UI: 空态
  Widget _blank() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: const Center(
        child: Text('暂无可导入条目'),
      ),
    );
  }

  // —— UI: 预览条目
  Widget _previewTile(_ImportItem it) {
    final e = it.entry;
    final hasName = (e.name?.trim().isNotEmpty ?? false);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.addressBase58,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: '移除此条',
                  onPressed: () {
                    setState(() => _items.remove(it));
                    it.nameCtrl.dispose();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ID: ${e.id}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: it.nameCtrl,
              decoration: const InputDecoration(
                labelText: '名称（可选）',
                border: OutlineInputBorder(),
                hintText: '给此钱包起个名字，方便识别',
              ),
              initialValue: null, // 用 controller，不要 initialValue
            ),
            if (!hasName) const SizedBox(height: 4),
            if (!hasName)
              const Text('提示：未设置名称时列表将显示地址',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  // —— 解析：支持对象/数组；解析阶段直接过滤重复
  Future<void> _parse() async {
    final raw = _input.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请先粘贴导出 JSON')));
      return;
    }

    setState(() => _busy = true);
    try {
      final List<Map<String, dynamic>> maps = _coerceToEntryMaps(raw);
      if (maps.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('未解析到任何钱包条目')));
        return;
      }

      // 已有数据索引
      final box = Hive.box('wallets');
      final existIds = <String>{};
      final exist58 = <String>{};
      final existHex = <String>{};
      for (final k in box.keys) {
        final cur = WalletEntry.tryFrom(box.get(k));
        if (cur == null) continue;
        existIds.add(cur.id);
        exist58.add(_norm58(cur.addressBase58));
        existHex.add(_normHex(cur.addressHex));
      }

      // 本次预览内索引
      final seenIds = <String>{};
      final seen58 = <String>{};
      final seenHex = <String>{};

      _clearPreview();

      int dup = 0, kept = 0;
      for (final m in maps) {
        final e = WalletEntry.fromJson(m);
        final id = e.id;
        final a58 = _norm58(e.addressBase58);
        final hex = _normHex(e.addressHex);

        final isDup = existIds.contains(id) ||
            exist58.contains(a58) ||
            existHex.contains(hex) ||
            seenIds.contains(id) ||
            seen58.contains(a58) ||
            seenHex.contains(hex);

        if (isDup) {
          dup++;
          continue;
        }

        _items.add(_ImportItem(
          entry: e,
          nameCtrl: TextEditingController(text: e.name ?? ''),
        ));
        seenIds.add(id);
        seen58.add(a58);
        seenHex.add(hex);
        kept++;
      }

      setState(() {});
      if (dup > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已过滤重复 $dup 条，待导入 $kept 条')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('解析失败：$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // —— 保存：再次保险去重；可选覆盖
  Future<void> _saveAll() async {
    if (_items.isEmpty) return;

    setState(() => _busy = true);
    try {
      final box = Hive.box('wallets');

      // 已存在索引
      final existIds = <String>{};
      final exist58 = <String>{};
      final existHex = <String>{};
      for (final k in box.keys) {
        final cur = WalletEntry.tryFrom(box.get(k));
        if (cur == null) continue;
        existIds.add(cur.id);
        exist58.add(_norm58(cur.addressBase58));
        existHex.add(_normHex(cur.addressHex));
      }

      // 本批次索引（防止本次重复）
      final batchIds = <String>{};
      final batch58 = <String>{};
      final batchHex = <String>{};

      int inserted = 0, updated = 0, skipped = 0;

      for (final it in _items) {
        var e = it.entry;

        // 应用名称编辑
        final name = it.nameCtrl.text.trim();
        e = e.copyWith(name: name.isEmpty ? null : name);

        final id = e.id;
        final a58 = _norm58(e.addressBase58);
        final hex = _normHex(e.addressHex);

        // 查找是否存在同地址/同 id 的旧记录
        String? dupKey; // 用旧条目的 id 作为 key
        WalletEntry? dup;
        for (final k in box.keys) {
          final cur = WalletEntry.tryFrom(box.get(k));
          if (cur == null) continue;
          final sameId = cur.id == id;
          final same58 = _norm58(cur.addressBase58) == a58;
          final sameHex = _normHex(cur.addressHex) == hex;
          if (sameId || same58 || sameHex) {
            dupKey = cur.id;
            dup = cur;
            break;
          }
        }

        final seenDup = exist58.contains(a58) ||
            existHex.contains(hex) ||
            batch58.contains(a58) ||
            batchHex.contains(hex) ||
            existIds.contains(id) ||
            batchIds.contains(id);

        if (dup != null || seenDup) {
          if (!_overwrite) {
            skipped++;
            continue;
          }
          // 覆盖合并（保留旧 isDefault / createdAt）
          final merged = (dup ?? e).copyWith(
            // 名称：保留旧值；若旧为空则用新值
            name: (dup?.name == null || dup!.name!.trim().isEmpty) ? e.name : dup!.name,
            encPrivateKeyB64: e.encPrivateKeyB64,
            nonceB64: e.nonceB64,
            salt1B64: e.salt1B64,
            salt2B64: e.salt2B64,
            salt3B64: e.salt3B64,
            masterSaltB64: e.masterSaltB64,
            pbkdf2Iterations: e.pbkdf2Iterations,
            // isDefault / createdAt 走 dup 的
          );
          await box.put(dupKey ?? e.id, merged.toJson());
          updated++;

          // 索引维护
          existIds.add(dupKey ?? e.id);
          batchIds.add(dupKey ?? e.id);
          exist58.add(a58);
          batch58.add(a58);
          existHex.add(hex);
          batchHex.add(hex);
          continue;
        }

        // 全新条目；若仅 id 撞车（极少见）则换新 id
        if (existIds.contains(id) || batchIds.contains(id)) {
          if (!exist58.contains(a58) &&
              !existHex.contains(hex) &&
              !batch58.contains(a58) &&
              !batchHex.contains(hex)) {
            e = e.copyWith(id: const Uuid().v4());
          } else {
            skipped++;
            continue;
          }
        }

        await box.put(e.id, e.toJson());
        inserted++;

        existIds.add(e.id);
        batchIds.add(e.id);
        exist58.add(a58);
        batch58.add(a58);
        existHex.add(hex);
        batchHex.add(hex);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入完成：新增 $inserted，更新 $updated，跳过 $skipped'),
        ),
      );
      Navigator.pop(context, inserted + updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // —— utils

  // 支持对象或数组，统一转为 List<Map>
  List<Map<String, dynamic>> _coerceToEntryMaps(String raw) {
    final decoded = jsonDecode(raw);

    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }

    if (decoded is Map) {
      return [Map<String, dynamic>.from(decoded)];
    }

    // 有些人会把多条 JSON 用换行拼起来，这里做个兜底
    final lines = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final res = <Map<String, dynamic>>[];
    for (final line in lines) {
      try {
        final m = jsonDecode(line);
        if (m is Map) res.add(Map<String, dynamic>.from(m));
      } catch (_) {}
    }
    return res;
  }

  // 规范化（比较用）
  String _norm58(String s) => s.trim();
  String _normHex(String s) =>
      s.replaceAll(RegExp(r'^0x', caseSensitive: false), '').toUpperCase().trim();

  void _clearPreview() {
    for (final it in _items) {
      it.nameCtrl.dispose();
    }
    _items.clear();
    setState(() {});
  }
}

class _ImportItem {
  _ImportItem({required this.entry, required this.nameCtrl});
  WalletEntry entry;
  final TextEditingController nameCtrl;
}
