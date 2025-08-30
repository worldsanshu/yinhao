import 'package:intl/intl.dart';
import 'tron_client.dart';

class UsdtService {
  static const defaultUsdtContract = 'TXLAQ63Xg1NAzckPwKHvzw7CSEmLMEqcdj';
  final TronClient client;
  UsdtService(this.client);

  Future<(String trx, String usdt)> balances(String base58) async {
    final trxWei = await client.getTrxBalance(base58);
    final usdt6 = await client.getTokenBalance(base58, defaultUsdtContract);
    final trx = NumberFormat('#,##0.000000').format(trxWei.toDouble() / 1e6);
    final usdt = NumberFormat('#,##0.000000').format(usdt6.toDouble() / 1e6);
    return (trx, usdt);
  }
}
