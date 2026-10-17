// Работа с GitHub через REST API: скачать мод, отправить изменения одним коммитом, следить за сборкой, скачать APK.
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'net.dart';

class GhError implements Exception {
  final int code;
  final String body;
  GhError(this.code, this.body);
  @override
  String toString() {
    if (code == 401) return 'GitHub не принял токен (401). Проверьте токен в разделе «Проект».';
    if (code == 403) return 'Нет прав (403). Токену нужен доступ Contents: Read and write и Actions: Read.';
    if (code == 404) return 'Не найдено (404). Проверьте владельца, репозиторий и ветку.';
    if (code == 409 || code == 422) return 'GitHub отклонил изменение ($code). Попробуйте ещё раз.';
    return 'Ошибка GitHub $code: ${body.length > 300 ? body.substring(0, 300) : body}';
  }
}

class GitHub {
  final String owner, repo, branch, token;
  /// Папка мода в репозитории.
  static const String prefix = 'flutter/assets/';
  final http.Client _c;
  GitHub(this.owner, this.repo, this.branch, this.token, {String? proxy}) : _c = makeClient(proxy);

  Map<String, String> get _h => {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'rubezh-editor',
      };

  Uri _u(String path, [Map<String, String>? q]) => Uri.https('api.github.com', '/repos/$owner/$repo$path', q);

  Future<dynamic> _get(String path, [Map<String, String>? q]) async {
    final r = await _c.get(_u(path, q), headers: _h);
    if (r.statusCode >= 300) throw GhError(r.statusCode, r.body);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  Future<dynamic> _send(String method, String path, Object body) async {
    final rq = http.Request(method, _u(path))
      ..headers.addAll({..._h, 'Content-Type': 'application/json'})
      ..body = jsonEncode(body);
    final r = await http.Response.fromStream(await _c.send(rq));
    if (r.statusCode >= 300) throw GhError(r.statusCode, r.body);
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// Проверка доступа: имя репозитория и есть ли право записи.
  Future<String> check() async {
    final j = await _get('');
    final push = (j['permissions']?['push'] ?? false) as bool;
    return '${j['full_name']} · ${push ? 'запись разрешена' : 'только чтение — отправка не получится'}';
  }

  Future<String> headSha() async => (await _get('/git/ref/heads/$branch'))['object']['sha'] as String;

  /// Файлы мода в репозитории: путь внутри assets/ («mod/…») → sha.
  Future<(String commit, String tree, Map<String, String> files)> remoteMod() async {
    final commit = await headSha();
    final c = await _get('/git/commits/$commit');
    final tree = c['tree']['sha'] as String;
    final t = await _get('/git/trees/$tree', {'recursive': '1'});
    final files = <String, String>{};
    for (final e in t['tree'] as List) {
      final path = e['path'] as String;
      if (e['type'] == 'blob' && path.startsWith('${prefix}mod/')) files[path.substring(prefix.length)] = e['sha'] as String;
    }
    return (commit, tree, files);
  }

  Future<Uint8List> blob(String sha) async {
    final j = await _get('/git/blobs/$sha');
    return base64Decode((j['content'] as String).replaceAll('\n', ''));
  }

  /// Один коммит: changes — путь внутри assets/ → новое содержимое (null — удалить файл).
  Future<String> commit(String baseCommit, String baseTree, Map<String, Uint8List?> changes, String message, {void Function(String)? progress}) async {
    final entries = <Map<String, dynamic>>[];
    int i = 0;
    for (final e in changes.entries) {
      i++;
      if (e.value == null) {
        entries.add({'path': '$prefix${e.key}', 'mode': '100644', 'type': 'blob', 'sha': null});
        continue;
      }
      progress?.call('Загрузка файлов: $i из ${changes.length} · ${e.key}');
      final b = await _send('POST', '/git/blobs', {'content': base64Encode(e.value!), 'encoding': 'base64'});
      entries.add({'path': '$prefix${e.key}', 'mode': '100644', 'type': 'blob', 'sha': b['sha']});
    }
    progress?.call('Создание коммита…');
    final tree = await _send('POST', '/git/trees', {'base_tree': baseTree, 'tree': entries});
    final c = await _send('POST', '/git/commits', {
      'message': message,
      'tree': tree['sha'],
      'parents': [baseCommit],
    });
    await _send('PATCH', '/git/refs/heads/$branch', {'sha': c['sha'], 'force': false});
    return c['sha'] as String;
  }

  /// Запуск сборки «Flutter» для коммита (null — ещё не появился).
  Future<Map<String, dynamic>?> buildRun(String sha) async {
    final j = await _get('/actions/runs', {'head_sha': sha, 'per_page': '20'});
    for (final r in j['workflow_runs'] as List) {
      if (r['name'] == 'Flutter') return r as Map<String, dynamic>;
    }
    return null;
  }

  /// APK из релиза apk-latest, если он собран из этого коммита.
  Future<Uint8List?> latestApk(String sha) async {
    final base = 'https://github.com/$owner/$repo/releases/download/apk-latest';
    final s = await _c.get(Uri.parse('$base/apk-sha.txt'), headers: {'User-Agent': 'rubezh-editor'});
    if (s.statusCode != 200 || s.body.trim() != sha) return null;
    final r = await _c.get(Uri.parse('$base/rubezh.apk'), headers: {'User-Agent': 'rubezh-editor'});
    return r.statusCode == 200 ? r.bodyBytes : null;
  }

  static String apkUrl(String owner, String repo) => 'https://github.com/$owner/$repo/releases/download/apk-latest/rubezh.apk';
}
