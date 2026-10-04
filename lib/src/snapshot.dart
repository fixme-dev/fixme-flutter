// UI tree from the Element tree. Each widget the app's own code created (the inspector's "summary tree") becomes
// a UINode with its creation location (from WidgetInspectorService's debug data, which track-widget-creation
// fills in debug builds), exact global frame (RenderBox.localToGlobal), text and clipped state. Same shape as
// PointerProtocol.UISnapshot, so the Mac and the agent read Flutter trees like every other platform.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

import 'geometry.dart';

/// Is this creation file part of the app (not the Flutter SDK or a pub-cache package)?
bool isLocalFile(String file, {String? projectRoot}) {
  final path = file.startsWith('file://') ? Uri.parse(file).toFilePath() : file;
  // FIXME's own widgets (the Dart overlay) are never the app's, whether the package comes from pub, git or a path.
  if (path.contains('/fixme_flutter/lib/') || path.contains('/fixme_flutter-')) return false;
  if (projectRoot != null && projectRoot.isNotEmpty) return path.startsWith(projectRoot.endsWith('/') ? projectRoot : '$projectRoot/');
  return !(path.contains('/.pub-cache/') ||
      path.contains('/packages/flutter/lib/') ||
      path.contains('/packages/flutter_test/') ||
      path.contains('/bin/cache/') ||
      path.contains('/flutter/packages/') ||
      path.contains('/Pub/Cache/'));
}

/// `file:///path/to/app/lib/main.dart` → `lib/main.dart` when it is under the root.
String relativePath(String file, String? projectRoot) {
  var path = file.startsWith('file://') ? Uri.parse(file).toFilePath() : file;
  if (projectRoot != null && projectRoot.isNotEmpty) {
    final root = projectRoot.endsWith('/') ? projectRoot : '$projectRoot/';
    if (path.startsWith(root)) path = path.substring(root.length);
  } else {
    final i = path.lastIndexOf('/lib/');
    if (i >= 0) path = path.substring(i + 1);
  }
  return path;
}

/// Role for a widget type name (same table as the Mac's FlutterSnapshotBuilder).
String roleFor(String type, {bool hasTap = true, bool hasText = false, bool isLeaf = false}) {
  final base = type.split('<').first;
  const buttons = {
    'ElevatedButton', 'TextButton', 'OutlinedButton', 'FilledButton', 'IconButton', 'FloatingActionButton',
    'MaterialButton', 'RawMaterialButton', 'CupertinoButton', 'BackButton', 'CloseButton', 'PopupMenuButton',
    'DropdownButton', 'SegmentedButton', 'InkWell', 'InkResponse',
  };
  if (buttons.contains(base)) return 'button';
  if (base == 'GestureDetector') return hasTap ? 'button' : 'container';
  const text = {'Text', 'RichText', 'SelectableText'};
  if (text.contains(base)) return 'text';
  const fields = {'TextField', 'TextFormField', 'CupertinoTextField', 'EditableText', 'SearchBar'};
  if (fields.contains(base)) return 'textField';
  const images = {'Image', 'FadeInImage', 'Icon', 'CircleAvatar', 'RawImage'};
  if (images.contains(base)) return 'image';
  const lists = {'ListView', 'GridView', 'CustomScrollView', 'SingleChildScrollView', 'PageView', 'ReorderableListView'};
  if (lists.contains(base)) return 'list';
  const cells = {'ListTile', 'CheckboxListTile', 'SwitchListTile', 'RadioListTile', 'ExpansionTile', 'Card'};
  if (cells.contains(base)) return 'cell';
  const toggles = {'Switch', 'CupertinoSwitch', 'Checkbox', 'Radio'};
  if (toggles.contains(base)) return 'toggle';
  if (base == 'Slider' || base == 'CupertinoSlider') return 'slider';
  if (base == 'Scaffold' || base == 'CupertinoPageScaffold') return 'screen';
  return hasText && isLeaf ? 'text' : 'container';
}

/// The readable Key: ValueKey<String>('price') → "price", ValueKey<int>(3) → "3". Global keys are identities.
String? keyString(Key? key) {
  if (key is ValueKey) return '${key.value}';
  return null;
}

class _Built {
  _Built(this.node, this.frame);
  final Map<String, Object?> node;
  final FxRect frame;
}

/// Builds UISnapshot JSON for everything under `root` (usually the app's root element).
class SnapshotBuilder {
  /// `deadline` bounds the walk (a huge tree still answers in time): past it the walk stops descending and the root
  /// says `props.truncated`.
  SnapshotBuilder({this.projectRoot, this.screen, this.deadline});
  final String? projectRoot;
  final Size? screen;
  final Duration? deadline;
  int _counter = 0;
  static const String _group = 'fixme-snapshot';
  final Stopwatch _clock = Stopwatch();
  bool _truncated = false;

  /// This build records where each widget was created (`flutter run` and Xcode do; `flutter build ios --debug` does
  /// not). Without it no widget has a file and line, so the tree keeps only the widgets a person would name.
  bool _tracked = true;
  bool get creationTracked => _tracked;

  Map<String, Object?> build(Element root, {int t = 0}) {
    _counter = 0;
    final service = WidgetInspectorService.instance;
    _tracked = service.isWidgetCreationTracked();
    _truncated = false;
    _clock
      ..reset()
      ..start();
    final built = <_Built>[];
    try {
      _walk(root, service, built, hidden: false);
    } finally {
      // ignore: invalid_use_of_protected_member
      service.disposeGroup(_group);
    }
    final rootFrame = screen != null ? FxRect(0, 0, screen!.width, screen!.height) : built.fold(const FxRect(0, 0, 0, 0), (a, b) => a.union(b.frame));
    final rootNode = built.length == 1
        ? built.first.node
        : {
            'id': 'n${_counter++}',
            'type': 'FlutterView',
            'role': 'screen',
            'frame': rootFrame.toJson(),
            'visible': true,
            'props': {'frames': 'exact'},
            'children': [for (final b in built) b.node],
          };
    if (built.length == 1) (rootNode['props'] as Map<String, Object?>)['frames'] = 'exact';
    if (_truncated) (rootNode['props'] as Map<String, Object?>)['truncated'] = 'true';
    if (!_tracked) (rootNode['props'] as Map<String, Object?>)['creationTracking'] = 'off';
    _renumber(rootNode);
    return {
      't': t,
      'framework': 'flutter',
      'screen': {'width': rootFrame.width, 'height': rootFrame.height},
      'root': rootNode,
    };
  }

  /// Depth-first ids n0, n1, … (the Mac and agents rely on this order).
  void _renumber(Map<String, Object?> root) {
    var i = 0;
    void walk(Map<String, Object?> n) {
      n['id'] = 'n${i++}';
      for (final c in (n['children'] as List).cast<Map<String, Object?>>()) {
        walk(c);
      }
    }

    walk(root);
  }

  void _walk(Element e, WidgetInspectorService service, List<_Built> out, {required bool hidden}) {
    final w = e.widget;
    final isHidden = hidden || (w is Offstage && w.offstage) || (w is TickerMode && !w.enabled) || (w is Visibility && !w.visible);
    if (deadline != null && _clock.elapsed > deadline!) {
      _truncated = true;
      return;
    }
    final (String, int, int?)? loc = _tracked ? _creationLocation(e, service) : null;
    final bool keep = _tracked
        ? loc != null && isLocalFile(loc.$1, projectRoot: projectRoot)
        : _isNameable(w);
    if (!keep) {
      e.visitChildren((c) => _walk(c, service, out, hidden: isHidden));
      return;
    }
    final children = <_Built>[];
    e.visitChildren((c) => _walk(c, service, children, hidden: isHidden));
    final ro = e.renderObject;
    var frame = const FxRect(0, 0, 0, 0);
    String? paragraphText;
    var clipped = false;
    if (ro is RenderBox && ro.attached && ro.hasSize) {
      final p = ro.localToGlobal(Offset.zero);
      frame = FxRect(p.dx, p.dy, ro.size.width, ro.size.height);
      if (ro is RenderParagraph) {
        paragraphText = ro.text.toPlainText();
        clipped = ro.didExceedMaxLines;
      }
      if (!kReleaseMode && ro.toStringShort().contains('OVERFLOWING')) clipped = true;
    } else if (children.isNotEmpty) {
      frame = children.fold(const FxRect(0, 0, 0, 0), (a, b) => a.union(b.frame));
    }
    final type = w.runtimeType.toString();
    final text = _widgetText(w) ?? (children.isEmpty ? paragraphText : null);
    final role = roleFor(type, hasTap: _hasTap(w), hasText: text != null, isLeaf: children.isEmpty);
    final childNodes = [for (final c in children) c.node];
    String? label;
    if (role == 'button' || role == 'cell') label = _firstText(childNodes);
    if (w is Tooltip) label = w.message;
    final visible = !isHidden && (screen == null || frame.intersection(FxRect(0, 0, screen!.width, screen!.height)).area > 0);
    final id = 'n${_counter++}';
    final node = compact({
      'id': id,
      'type': type,
      'role': role,
      'label': label,
      'text': (role == 'text' || role == 'textField') ? text : null,
      'value': w is EditableText ? (w.obscureText ? '••••' : w.controller.text) : _fieldValue(e),
      'identifier': keyString(w.key),
      'frame': frame.toJson(),
      'visible': visible,
      'enabled': _enabled(w),
      'clipped': clipped ? true : null,
      'source': loc == null ? null : compact({'file': relativePath(loc.$1, projectRoot), 'line': loc.$2, 'column': loc.$3}),
      'props': <String, Object?>{if (clipped) 'overflow': ro is RenderParagraph ? 'text' : 'RenderFlex'},
      'children': childNodes,
    });
    out.add(_Built(node, frame));
  }

  /// (file, line, column) from the inspector's serialization of this element.
  (String, int, int?)? _creationLocation(Element e, WidgetInspectorService service) {
    try {
      final json = e.toDiagnosticsNode().toJsonMap(
            InspectorSerializationDelegate(service: service, groupName: _group, subtreeDepth: 0, includeProperties: false),
          );
      final loc = json['creationLocation'];
      if (loc is Map && loc['file'] is String && loc['line'] is int) {
        return (loc['file'] as String, loc['line'] as int, loc['column'] as int?);
      }
    } catch (_) {}
    return null;
  }

  /// Without creation tracking: a widget a person would name (text, buttons, fields, images, lists), not the plumbing.
  static bool _isNameable(Widget w) {
    final type = w.runtimeType.toString();
    if (type.startsWith('_')) return false;
    return roleFor(type, hasTap: _hasTap(w), hasText: _widgetText(w) != null, isLeaf: false) != 'container';
  }

  static String? _widgetText(Widget w) {
    if (w is Text) return w.data ?? w.textSpan?.toPlainText();
    if (w is RichText) return w.text.toPlainText();
    if (w is SelectableText) return w.data ?? w.textSpan?.toPlainText();
    return null;
  }

  static bool _hasTap(Widget w) {
    if (w is GestureDetector) return w.onTap != null || w.onTapDown != null || w.onTapUp != null || w.onLongPress != null;
    return true;
  }

  static bool? _enabled(Widget w) {
    if (w is ButtonStyleButton) return w.enabled;
    if (w is IconButton) return w.onPressed != null;
    return null;
  }

  static String? _fieldValue(Element e) {
    // TextField and friends: read the EditableText below (secure text hidden).
    final w = e.widget;
    if (w is! TextField) return null;
    String? out;
    void visit(Element c) {
      if (out != null) return;
      final cw = c.widget;
      if (cw is EditableText) {
        out = cw.obscureText ? '••••' : cw.controller.text;
        return;
      }
      c.visitChildren(visit);
    }

    e.visitChildren(visit);
    return out;
  }

  static String? _firstText(List<Map<String, Object?>> nodes) {
    for (final n in nodes) {
      final t = n['text'] ?? n['label'];
      if (t is String) return t;
      final inner = _firstText((n['children'] as List).cast<Map<String, Object?>>());
      if (inner != null) return inner;
    }
    return null;
  }
}

/// Ranked targets for a mark (same scoring as the Mac's FlutterTargets).
List<Map<String, Object?>> targetsFor(Map<String, Object?> snapshot, FxRect mark, {int limit = 5}) {
  final screen = snapshot['screen'] as Map;
  final screenArea = ((screen['width'] as num) * (screen['height'] as num)).toDouble().clamp(1, double.infinity);
  final scored = <(Map<String, Object?>, List<Map<String, Object?>>, double)>[];
  final root = snapshot['root'] as Map<String, Object?>;
  void walk(Map<String, Object?> n, List<Map<String, Object?>> ancestors) {
    final f = n['frame'] as Map;
    final r = FxRect((f['x'] as num).toDouble(), (f['y'] as num).toDouble(), (f['width'] as num).toDouble(), (f['height'] as num).toDouble());
    if (n != root && n['visible'] == true && r.area > 0) {
      final inter = r.intersection(mark).area;
      if (inter > 0) {
        final coverNode = inter / r.area, coverMark = inter / (mark.area < 1 ? 1 : mark.area);
        final meaningful = (n['text'] != null || n['label'] != null || n['identifier'] != null) ? 0.25 : 0.0;
        const interactive = {'button', 'text', 'textField', 'image', 'toggle', 'slider', 'cell'};
        final roleBonus = interactive.contains(n['role']) ? 0.08 : 0.0;
        final clippedBonus = n['clipped'] == true ? 0.07 : 0.0;
        final screenPenalty = r.area / screenArea > 0.6 ? 0.3 : 0.0;
        final s = 0.55 * coverNode + 0.25 * coverMark + meaningful + roleBonus + clippedBonus - screenPenalty;
        if (s > 0.3) scored.add((n, ancestors, s > 1 ? 1.0 : s));
      }
    }
    for (final c in (n['children'] as List).cast<Map<String, Object?>>()) {
      walk(c, [n, ...ancestors]);
    }
  }

  walk(root, []);
  double area(Map<String, Object?> n) => (((n['frame'] as Map)['width'] as num) * ((n['frame'] as Map)['height'] as num)).toDouble();
  scored.sort((a, b) => (b.$3 - a.$3).abs() > 0.0001 ? b.$3.compareTo(a.$3) : area(a.$1).compareTo(area(b.$1)));
  final out = <Map<String, Object?>>[];
  for (var i = 0; i < scored.length && i < limit; i++) {
    final (n, ancestors, s) = scored[i];
    final callSites = <Object?>[];
    for (final a in ancestors) {
      final src = a['source'];
      if (src != null && src.toString() != n['source'].toString() && !callSites.any((c) => c.toString() == src.toString())) callSites.add(src);
      if (callSites.length == 3) break;
    }
    out.add(compact({
      'rank': i + 1,
      'confidence': (s * 100).roundToDouble() / 100,
      'kind': 'flutter',
      'typeName': n['type'],
      'label': n['text'] ?? n['label'],
      'accessibilityId': n['identifier'],
      'frame': n['frame'],
      'ancestors': [for (final a in ancestors.take(8)) a['type']],
      'source': n['source'],
      'callSites': callSites,
    }));
  }
  return out;
}

/// The screen the person is looking at, named from a snapshot: the last visible Scaffold in the tree (a pushed route
/// is built after the one beneath it), named by the widget of the app that builds it (`PaywallScreen`), else by the
/// file it was created in (`paywall_screen`). Null when there is no Scaffold, for example an app on bare widgets.
String? screenNameOf(Map<String, Object?> snapshot) {
  final screen = snapshot['screen'];
  final area = screen is Map ? ((screen['width'] as num? ?? 0) * (screen['height'] as num? ?? 0)).toDouble() : 0.0;
  Map<String, Object?>? best, bestParent;
  void walk(Map<String, Object?> n, Map<String, Object?>? parent) {
    final f = n['frame'];
    if (n['role'] == 'screen' && n['visible'] == true && f is Map) {
      final a = ((f['width'] as num? ?? 0) * (f['height'] as num? ?? 0)).toDouble();
      if (area <= 0 || a >= area * 0.25) {
        best = n;
        bestParent = parent;
      }
    }
    for (final c in (n['children'] as List? ?? const []).cast<Map<String, Object?>>()) {
      walk(c, n);
    }
  }

  final root = snapshot['root'];
  if (root is Map<String, Object?>) walk(root, null);
  final b = best;
  if (b == null) return null;
  final p = bestParent;
  if (p != null && p['source'] is Map && p['type'] != 'FlutterView' && p['type'] != 'RootWidget') {
    final t = p['type'];
    if (t is String && !t.startsWith('_') && t != 'MaterialApp' && t != 'CupertinoApp' && t != 'Navigator') return t;
  }
  final src = b['source'];
  if (src is Map && src['file'] is String) {
    final base = (src['file'] as String).split('/').last;
    return base.endsWith('.dart') ? base.substring(0, base.length - 5) : base;
  }
  return null;
}
