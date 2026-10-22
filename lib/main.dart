/// PM3 图形界面应用入口
///
/// 该应用是一个基于 Flutter 的 Proxmark3 设备图形界面，提供以下功能：
/// - 设备连接与管理
/// - 终端命令执行
/// - 卡片数据查看与分析
/// - 转储文件管理与比较
/// - Mifare 卡片操作
/// - 低频卡片操作
/// - 设置管理
library;

import 'dart:ui' show AppExitResponse;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/ui/theme.dart';
import 'package:pm3gui/ui/home_page.dart';
import 'package:pm3gui/l10n/l10n.dart';
import 'package:pm3gui/l10n/app_locale_controller.dart';

/// 应用入口函数
///
/// 初始化应用并提供全局状态管理
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = AppLocaleController();
  await localeController.initialize();
  final appState = AppState();
  AppLifecycleListener(
    onExitRequested: () async {
      await appState.shutdown();
      await localeController.flush();
      return AppExitResponse.exit;
    },
  );
  runApp(
    ChangeNotifierProvider(
      create: (_) => appState,
      child: PM3GuiApp(localeController: localeController),
    ),
  );
}

/// 应用根组件
///
/// 负责应用的主题管理和页面导航
class PM3GuiApp extends StatefulWidget {
  const PM3GuiApp({super.key, this.localeController});

  final AppLocaleController? localeController;

  @override
  State<PM3GuiApp> createState() => _PM3GuiAppState();
}

class _PM3GuiAppState extends State<PM3GuiApp> {
  late final AppLocaleController _localeController;

  @override
  void initState() {
    super.initState();
    _localeController = widget.localeController ?? AppLocaleController();
    unawaited(_localeController.initialize());
  }

  @override
  void dispose() {
    if (widget.localeController == null) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _localeController,
      child: AnimatedBuilder(
        animation: _localeController,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => context.l10n.appTitle,
          locale: _localeController.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme(),
          builder: (context, child) {
            context.read<AppState>().updateLocalizations(context.l10n);
            return child!;
          },
          home: const HomePage(),
        ),
      ),
    );
  }
}
