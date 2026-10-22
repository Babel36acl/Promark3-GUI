/// Connection-guard wrapper.
///
/// Checks whether the device can accept a command without dispatching it.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/l10n/l10n.dart';

/// 只检查连接与忙状态；调用方先订阅输出，再发送一次命令。
bool ensurePm3Ready(BuildContext context) {
  final appState = context.read<AppState>();
  if (!appState.isConnected) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.pm3NotConnected)),
    );
    return false;
  }
  if (appState.connectionState.controller.isExecuting) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.pm3Busy)),
    );
    return false;
  }
  return true;
}
