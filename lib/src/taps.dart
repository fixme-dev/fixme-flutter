// Names what a tap landed on, for the ticket's timeline: `Tapped TextButton "Unlock Rituals Pro"`.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'snapshot.dart' show roleFor;

/// Where the climb stops: past these a tap is on the page, not on a control (a Material control is dozens of elements deep).
const Set<String> _pageBoundaries = {'Scaffold', 'AppBar', 'Navigator', 'MaterialApp', 'CupertinoApp', 'WidgetsApp'};

/// "Tapped TextButton "Unlock Rituals Pro"" for the deepest widget under the tap that a person would name (a button, a
/// field, a switch, a list tile, else the text they hit), or null when the tap landed on nothing nameable. Debug builds
/// only: it reads `RenderObject.debugCreator`, which release builds do not have.
String? describeTap(HitTestResult result) {
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    // Climb from the thing hit: a named control (TextButton, TextField, Switch, ListTile) wins as soon as it is met; the
    // generic tap catchers it is built from (InkWell, GestureDetector) are only the fallback, then a bare Text.
    Element? control, tapCatcher, text;
    var depth = 0;
    bool visit(Element e) {
      final type = e.widget.runtimeType.toString();
      if (_pageBoundaries.contains(type)) return true;
      if (!type.startsWith('_')) {
        final role = roleFor(type, hasTap: true);
        if (role == 'text') {
          text ??= e;
        } else if (role == 'button' && (type == 'InkWell' || type == 'InkResponse' || type == 'GestureDetector')) {
          tapCatcher ??= e;
        } else if (role != 'container' && role != 'image' && role != 'list' && role != 'screen') {
          control = e;
          return true;
        }
      }
      return ++depth > 160;
    }

    if (!visit(creator.element)) creator.element.visitAncestorElements((e) => !visit(e));
    final named = control ?? tapCatcher ?? text;
    if (named == null) continue;
    final type = named.widget.runtimeType.toString();
    final label = _firstText(named);
    return label == null ? 'Tapped $type' : 'Tapped $type "${label.length > 60 ? '${label.substring(0, 60)}…' : label}"';
  }
  return null;
}

/// The first string a Text under `e` shows, a few levels down.
String? _firstText(Element e) {
  String? out;
  void visit(Element c, int depth) {
    if (out != null || depth > 80) return;
    final w = c.widget;
    if (w is Text) {
      final t = w.data ?? w.textSpan?.toPlainText();
      if (t != null && t.trim().isNotEmpty) {
        out = t.trim();
        return;
      }
    }
    c.visitChildren((x) => visit(x, depth + 1));
  }

  visit(e, 0);
  return out;
}
