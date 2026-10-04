// The answer to the native helper's "what do you know about these circles?" (the framework bridge contract, version 1:
// Packages/fixme-react-native/DEVELOPMENT.md, "Native bridge contract").
//
// Request (native to Dart), JSON:
//   { id, ticketId, kind: "mark"|"clip", captureAt: <ms since 1970 the ticket's times are relative to>, windowMs,
//     screen: {width, height}, marks: [{points: [{x,y}], bounds: {x,y,width,height}, note?}],
//     viewFrame?: {x,y,width,height} }            (viewFrame is added by this package's iOS plugin: see below)
// Answer (Dart to native), JSON, every key optional, in the ticket's own shapes (docs/PROTOCOL.md):
//   { framework: "flutter", targets: [Target], console: [LogLine], timeline: [Event], state: {k: v},
//     viewTree?: string, screen?: {name?, route?}, uiSnapshot?: UISnapshot }
// Times (`t`) are milliseconds relative to `captureAt`.
//
// Coordinates. Marks and `screen` are in the app window's points, which are Flutter's logical pixels. When the Flutter
// view does not start at the window's origin (a split view, an iPad window, Flutter inside a native screen) the plugin
// adds `viewFrame`, the view's frame in the window; marks are moved into the view before the widgets are matched and
// every frame in the answer is moved back, so the answer is in the window's space like everything else the native
// helper reports.
//
// Pure: it is given the snapshot, console and timeline, so it is tested without a device.

import 'dart:convert';

import 'geometry.dart';
import 'snapshot.dart';

const int _maxConsole = 300;
const int _maxTimeline = 200;
const int _targetsPerMark = 4;
const int _defaultWindowMs = 30000;

/// The window offset of the Flutter view carried by the request (zero when absent).
({double x, double y}) viewOffset(Map<String, Object?> request) {
  final f = request['viewFrame'];
  if (f is! Map) return (x: 0, y: 0);
  final x = f['x'], y = f['y'];
  return (x: x is num ? x.toDouble() : 0, y: y is num ? y.toDouble() : 0);
}

/// The marks of a request as boxes in the Flutter view's own coordinates.
List<FxRect> markBoxes(Map<String, Object?> request) {
  final o = viewOffset(request);
  final out = <FxRect>[];
  final marks = request['marks'];
  if (marks is! List) return out;
  for (final m in marks) {
    if (m is! Map) continue;
    final b = m['bounds'];
    FxRect? box;
    if (b is Map && b['width'] is num && b['height'] is num) {
      box = FxRect((b['x'] as num? ?? 0).toDouble() - o.x, (b['y'] as num? ?? 0).toDouble() - o.y, (b['width'] as num).toDouble(), (b['height'] as num).toDouble());
    } else if (m['points'] is List) {
      final pts = [
        for (final p in m['points'] as List)
          if (p is Map && p['x'] is num && p['y'] is num) FxPoint((p['x'] as num).toDouble() - o.x, (p['y'] as num).toDouble() - o.y),
      ];
      if (pts.isNotEmpty) box = FxRect.bounding(pts);
    }
    if (box != null) out.add(box);
  }
  return out;
}

/// Ranked widgets for every circle: the best few of each, interleaved by rank, one entry per widget.
List<Map<String, Object?>> targetsForMarks(Map<String, Object?> snapshot, List<FxRect> marks) {
  final perMark = [for (final m in marks) targetsFor(snapshot, m, limit: _targetsPerMark)];
  final seen = <String>{};
  final out = <Map<String, Object?>>[];
  for (var rank = 0; rank < _targetsPerMark; rank++) {
    for (final list in perMark) {
      if (rank >= list.length) continue;
      final t = list[rank];
      final key = '${t['typeName']}|${t['source']}|${t['frame']}';
      if (seen.add(key)) out.add(t);
    }
  }
  return [for (var i = 0; i < out.length; i++) {...out[i], 'rank': i + 1}];
}

Object? _shifted(Object? node, double dx, double dy) {
  if (dx == 0 && dy == 0) return node;
  if (node is List) return [for (final n in node) _shifted(n, dx, dy)];
  if (node is! Map) return node;
  final out = <String, Object?>{};
  node.forEach((k, v) {
    if (k == 'frame' && v is Map && v['x'] is num && v['y'] is num) {
      out[k as String] = {...v, 'x': (v['x'] as num) + dx, 'y': (v['y'] as num) + dy};
    } else if (v is Map || v is List) {
      out[k as String] = _shifted(v, dx, dy);
    } else {
      out[k as String] = v;
    }
  });
  return out;
}

/// `console` / `timeline` ring entries (epoch ms, entry) as ticket lines inside the window, `t` relative to the capture.
List<Map<String, Object?>> relativeEntries(List<(int, Map<String, Object?>)> entries, int captureAt, int windowMs, int limit) {
  final from = captureAt - (windowMs > 0 ? windowMs : _defaultWindowMs);
  final lines = [
    for (final (at, m) in entries)
      if (at >= from && at <= captureAt + 1000) {'t': at - captureAt, ...m},
  ];
  return lines.length > limit ? lines.sublist(lines.length - limit) : lines;
}

/// A readable outline of the app's own widgets with their source lines, for the ticket's `viewTree`.
String viewTreeOutline(Map<String, Object?> snapshot, {int maxLines = 160, int maxDepth = 14}) {
  final root = snapshot['root'];
  if (root is! Map<String, Object?>) return '';
  final lines = <String>[];
  void walk(Map<String, Object?> n, int depth) {
    if (lines.length >= maxLines || depth > maxDepth) return;
    final text = n['text'] ?? n['label'];
    final src = n['source'];
    final where = src is Map && src['file'] != null ? '  ${src['file']}:${src['line']}' : '';
    final shown = text is String && text.isNotEmpty ? ' "${text.length > 40 ? '${text.substring(0, 40)}…' : text}"' : '';
    lines.add('${'  ' * depth}<${n['type']}>$shown$where');
    for (final c in (n['children'] as List? ?? const []).cast<Map<String, Object?>>()) {
      walk(c, depth + 1);
    }
  }

  walk(root, 0);
  if (lines.length >= maxLines) lines.add('…');
  return lines.join('\n');
}

/// The JSON answer for one request.
String buildEnrichmentJson({
  required Map<String, Object?> request,
  required Map<String, Object?>? snapshot,
  required List<(int, Map<String, Object?>)> console,
  required List<(int, Map<String, Object?>)> timeline,
  Map<String, String> state = const {},
  String? screenName,
  String? route,
}) =>
    jsonEncode(buildEnrichment(request: request, snapshot: snapshot, console: console, timeline: timeline, state: state, screenName: screenName, route: route));

Map<String, Object?> buildEnrichment({
  required Map<String, Object?> request,
  required Map<String, Object?>? snapshot,
  required List<(int, Map<String, Object?>)> console,
  required List<(int, Map<String, Object?>)> timeline,
  Map<String, String> state = const {},
  String? screenName,
  String? route,
}) {
  final captureAt = request['captureAt'] is num ? (request['captureAt'] as num).round() : DateTime.now().millisecondsSinceEpoch;
  final windowMs = request['windowMs'] is num ? (request['windowMs'] as num).round() : 0;
  final o = viewOffset(request);
  final isClip = request['kind'] == 'clip';

  final targets = snapshot == null || isClip ? const <Map<String, Object?>>[] : targetsForMarks(snapshot, markBoxes(request));
  final screenInfo = compact({'name': screenName, 'route': route});
  return compact({
    'framework': 'flutter',
    'targets': _shifted(targets, o.x, o.y),
    'console': relativeEntries(console, captureAt, windowMs, _maxConsole),
    'timeline': relativeEntries(timeline, captureAt, windowMs, _maxTimeline),
    'state': state,
    'viewTree': snapshot == null ? null : viewTreeOutline(snapshot),
    'screen': screenInfo.isEmpty ? null : screenInfo,
    'uiSnapshot': snapshot == null ? null : _shifted({...snapshot, 't': 0}, o.x, o.y),
  });
}
