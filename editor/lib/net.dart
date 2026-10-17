// Сеть: системный прокси Windows (VPN-клиенты вроде Clash/Mihomo/v2rayN включают его), переменные окружения.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Прокси, включённый в Windows («Параметры → Сеть → Прокси»), или из HTTPS_PROXY. Формат «host:port»; null — нет.
Future<String?> systemProxy() async {
  try {
    return await _systemProxy();
  } catch (_) {
    return null;
  }
}

Future<String?> _systemProxy() async {
  String? norm(String? s) {
    if (s == null) return null;
    var v = s.trim();
    if (v.isEmpty) return null;
    // «http=127.0.0.1:7890;https=127.0.0.1:7890» → берём https, иначе первый
    if (v.contains('=')) {
      final parts = {for (final p in v.split(';')) if (p.contains('=')) p.split('=')[0].toLowerCase(): p.split('=')[1]};
      v = parts['https'] ?? parts['http'] ?? parts.values.first;
    }
    v = v.replaceFirst(RegExp(r'^[a-z]+://'), '').replaceAll(RegExp(r'/+$'), '');
    return v.isEmpty ? null : v;
  }

  for (final k in const ['HTTPS_PROXY', 'https_proxy', 'HTTP_PROXY', 'http_proxy', 'ALL_PROXY']) {
    final v = norm(Platform.environment[k]);
    if (v != null) return v;
  }
  if (!Platform.isWindows) return null;
  try {
    final r = await Process.run('reg', ['query', r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings']);
    final out = '${r.stdout}';
    final en = RegExp(r'ProxyEnable\s+REG_DWORD\s+0x(\d+)').firstMatch(out);
    if (en == null || en.group(1) == '0') return null;
    final srv = RegExp(r'ProxyServer\s+REG_SZ\s+(\S+)').firstMatch(out);
    return norm(srv?.group(1));
  } catch (_) {
    return null;
  }
}

/// HTTP-клиент: через прокси «host:port» или напрямую.
http.Client makeClient(String? proxy) {
  final hc = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final p = proxy?.trim();
  if (p != null && p.isNotEmpty) {
    hc.findProxy = (_) => 'PROXY $p';
  }
  return IOClient(hc);
}

/// Понятное описание сетевой ошибки.
String netHint(Object e) {
  final s = '$e';
  if (s.contains('SocketException') || s.contains('Connection refused') || s.contains('отклонил') || s.contains('timed out') || s.contains('HandshakeException')) {
    return 'Нет соединения с GitHub ($s).\n\nЕсли GitHub открывается только через VPN/прокси (Clash, Mihomo, v2rayN и т. п.), '
        'включите в нём «системный прокси» и нажмите «Определить» в поле «Прокси» выше — или впишите адрес вручную, например 127.0.0.1:7890. '
        'Либо включите в VPN-клиенте режим TUN.';
  }
  return s;
}
