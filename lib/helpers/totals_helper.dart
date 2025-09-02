// lib/helpers/totals_helper.dart
import '../services/tron_client.dart';
import '../services/usdt_service.dart';

class TotalsResult {
  final double usdt;
  final double trx;
  const TotalsResult({required this.usdt, required this.trx});
}

/// 汇总所有地址的 USDT(TRC20) 和 TRX —— 直接网络取数，避免缓存导致的显示为 0。
class TotalsHelper {
  /// [base58Addresses]：地址列表（Base58）
  /// [endpoint]：TRON 节点（默认 Trongrid 主网）
  static Future<TotalsResult> fetchTotals(
    List<String> base58Addresses, {
    String endpoint = 'https://api.trongrid.io',
  }) async {
    final client = TronClient(endpoint: endpoint);
    final svc = UsdtService(client);

    double sumUsdt = 0.0;
    double sumTrx = 0.0;

    for (final addr in base58Addresses) {
      try {
        final (trxStr, usdtStr) = await svc.balances(addr);
        sumUsdt += double.tryParse(usdtStr) ?? 0.0;
        sumTrx  += double.tryParse(trxStr) ?? 0.0;
      } catch (_) {
        // 单个地址异常不影响总结果
      }
    }

    // 固定 6 位小数，避免浮点误差抖动
    return TotalsResult(
      usdt: double.parse(sumUsdt.toStringAsFixed(6)),
      trx:  double.parse(sumTrx.toStringAsFixed(6)),
    );
  }
}
