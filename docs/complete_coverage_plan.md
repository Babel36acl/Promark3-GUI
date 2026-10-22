# PM3GUI 完整覆盖率提升计划

> 此文件保留 PR #27 之前的覆盖率规划；下文协议计数、待添加页面与阶段状态
> 是原规划记录，不是当前完成清单。PR #27 新增的是中英文界面与本地化流程，
> 不据此声称增加或验证协议能力。当前范围见 [README](../README.md)、
> [实现现状](refactoring_plan.md) 和 [本地化指南](localization.md)。

## 1. 原规划时的覆盖率分析

### 1.1 已覆盖协议（7个）
- HF Mifare Classic
- HF 14443-A
- LF 通用
- LF EM4x
- LF T55xx
- HW 硬件

### 1.2 新增文档协议（5个）
- HF Mifare Ultralight/NTAG
- HF iCLASS/Picopass
- HF ISO15693
- HF Mifare DESFire
- LF HID Prox

### 1.3 待添加协议（15个）

#### 高频 (HF) - 6个
| 协议 | 命令数 | 优先级 | 常用场景 |
|------|--------|--------|----------|
| 14443-B | 9 | P1 | 标准B型卡 |
| FeliCa | 8 | P2 | 日本交通卡 |
| Legic | 7 | P2 | 门禁系统 |
| SEOS | 3 | P3 | 高安全门禁 |
| EMV | 15 | P1 | 银行卡/支付 |
| FIDO | 3 | P3 | 安全认证 |

#### 低频 (LF) - 8个
| 协议 | 命令数 | 优先级 | 常用场景 |
|------|--------|--------|----------|
| AWID | 3 | P2 | 门禁卡 |
| Indala | 3 | P2 | 门禁卡 |
| Hitag | 7 | P1 | 车钥匙 |
| IO | 3 | P2 | 门禁卡 |
| Pyramid | 2 | P3 | 门禁卡 |
| Keri | 2 | P3 | 门禁卡 |
| FDXB | 2 | P3 | 动物标签 |
| EM4x05/4x50/4x70 | 12 | P2 | 特殊应用 |

#### 其他 - 4个
| 协议 | 命令数 | 优先级 | 说明 |
|------|--------|--------|------|
| Data | 30+ | P2 | 数据分析 |
| Trace | 4 | P2 | 跟踪分析 |
| NFC | 5 | P2 | NFC解码 |
| Script | 2 | P3 | 脚本执行 |

---

## 2. 完整页面列表（27个协议）

### 高频页面 (13个)
1. **hf_mfu_page.dart** - Mifare Ultralight/NTAG ✅
2. **hf_mfdes_page.dart** - Mifare DESFire ✅
3. **hf_iclass_page.dart** - iCLASS/Picopass ✅
4. **hf_15_page.dart** - ISO15693 ✅
5. **hf_14b_page.dart** - 14443-B 📋
6. **hf_felica_page.dart** - FeliCa 📋
7. **hf_legic_page.dart** - Legic 📋
8. **hf_seos_page.dart** - SEOS 📋
9. **hf_emv_page.dart** - EMV 📋
10. **hf_fido_page.dart** - FIDO 📋
11. **hf_mf_page.dart** - Mifare Classic (已有)
12. **hf_14a_page.dart** - 14443-A (已有)
13. **hf_sniff_page.dart** - 通用嗅探 📋

### 低频页面 (9个)
1. **lf_hid_page.dart** - HID Prox ✅
2. **lf_awid_page.dart** - AWID 📋
3. **lf_indala_page.dart** - Indala 📋
4. **lf_hitag_page.dart** - Hitag 📋
5. **lf_io_page.dart** - IO Prox 📋
6. **lf_pyramid_page.dart** - Pyramid 📋
7. **lf_keri_page.dart** - Keri 📋
8. **lf_fdxb_page.dart** - FDXB 📋
9. **lf_em4x_page.dart** - EM4x 系列 (已有)

### 工具页面 (5个)
1. **data_page.dart** - 数据分析 📋
2. **trace_page.dart** - 跟踪分析 📋
3. **nfc_page.dart** - NFC解码 📋
4. **script_page.dart** - 脚本执行 📋
5. **hw_page.dart** - 硬件信息 (已有)

---

## 3. 统一页面模板

所有新页面遵循统一的代码结构：

```dart
/// [Protocol] 操作页面
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';
import 'package:pm3gui/ui/theme.dart';

class [Protocol]Page extends StatefulWidget {
  const [Protocol]Page({super.key});

  @override
  State<[Protocol]Page> createState() => _[Protocol]PageState();
}

class _[Protocol]PageState extends State<[Protocol]Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: N, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _execute(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未连接 PM3')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    appState.sendCommand(cmd).then((_) {
      setState(() {
        _isLoading = false;
        _result = appState.terminalOutput.last;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '标签1'),
            Tab(text: '标签2'),
            // ...
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1(),
              _buildTab2(),
              // ...
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultDisplay() {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Text(
                    _result.isEmpty ? '执行命令查看结果' : _result,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
```

---

## 4. 导航结构更新

### 4.1 侧边栏分组

建议将侧边栏按协议类型分组：

```
📁 高频 (HF)
  ├── Mifare Classic
  ├── Mifare Ultralight
  ├── Mifare DESFire
  ├── iCLASS
  ├── ISO15693
  ├── 14443-B
  ├── FeliCa
  ├── Legic
  ├── SEOS
  ├── EMV
  └── FIDO

📁 低频 (LF)
  ├── EM4x
  ├── T55xx
  ├── HID Prox
  ├── AWID
  ├── Indala
  ├── Hitag
  ├── IO Prox
  ├── Pyramid
  ├── Keri
  └── FDXB

📁 工具
  ├── 数据分析
  ├── 跟踪分析
  ├── NFC解码
  └── 脚本执行
```

### 4.2 home_page.dart 更新

```dart
// 导入所有新页面
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_14b_page.dart';
import 'package:pm3gui/ui/pages/hf_felica_page.dart';
import 'package:pm3gui/ui/pages/hf_legic_page.dart';
import 'package:pm3gui/ui/pages/hf_seos_page.dart';
import 'package:pm3gui/ui/pages/hf_emv_page.dart';
import 'package:pm3gui/ui/pages/hf_fido_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';
import 'package:pm3gui/ui/pages/lf_awid_page.dart';
import 'package:pm3gui/ui/pages/lf_indala_page.dart';
import 'package:pm3gui/ui/pages/lf_hitag_page.dart';
import 'package:pm3gui/ui/pages/lf_io_page.dart';
import 'package:pm3gui/ui/pages/lf_pyramid_page.dart';
import 'package:pm3gui/ui/pages/lf_keri_page.dart';
import 'package:pm3gui/ui/pages/lf_fdxb_page.dart';
import 'package:pm3gui/ui/pages/data_page.dart';
import 'package:pm3gui/ui/pages/trace_page.dart';
import 'package:pm3gui/ui/pages/nfc_page.dart';
import 'package:pm3gui/ui/pages/script_page.dart';

// _pages 列表
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  // HF 页面
  MifarePage(),
  HfMfuPage(),
  HfMfdesPage(),
  HfIclassPage(),
  Hf15Page(),
  Hf14bPage(),
  HfFelicaPage(),
  HfLegicPage(),
  HfSeosPage(),
  HfEmvPage(),
  HfFidoPage(),
  // LF 页面
  LfPage(),
  LfHidPage(),
  LfAwidPage(),
  LfIndalaPage(),
  LfHitagPage(),
  LfIoPage(),
  LfPyramidPage(),
  LfKeriPage(),
  LfFdxbPage(),
  // 工具页面
  DataPage(),
  TracePage(),
  NfcPage(),
  ScriptPage(),
  SettingsPage(),
];
```

---

## 5. 覆盖率提升预测

### 5.1 添加所有页面后的覆盖率

| 指标 | 当前 | 添加后 | 提升 |
|:-----|:----:|:------:|:----:|
| **协议族总数** | 27 | 27 | - |
| **已覆盖协议族** | 7 | **27** | **+20** |
| **协议族覆盖率** | **26%** | **100%** | **+74%** |
| **GUI封装命令数** | 43 | **~200** | **+157** |
| **通过终端可访问** | 100% | 100% | - |

### 5.2 各协议覆盖情况

添加所有页面后，27个协议族将全部覆盖：

- ✅ **高频 (HF)** - 13个协议全部覆盖
- ✅ **低频 (LF)** - 9个协议全部覆盖
- ✅ **工具** - 5个类别全部覆盖

---

## 6. 实施建议

### 6.1 分批实施

建议按优先级分三批实施：

**第一批 (P0-P1)** - 核心功能
- HF: Ultralight, DESFire, iCLASS, ISO15693, 14443-B, EMV
- LF: HID Prox, Hitag
- 工具: Data, Trace

**第二批 (P2)** - 常用功能
- HF: FeliCa, Legic
- LF: AWID, Indala, IO, EM4x05/4x50/4x70
- 工具: NFC

**第三批 (P3)** - 特殊功能
- HF: SEOS, FIDO
- LF: Pyramid, Keri, FDXB
- 工具: Script

### 6.2 代码复用

建议提取公共组件：

```dart
// lib/ui/components/
├── action_button.dart      // 通用操作按钮
├── hex_input_field.dart    // 十六进制输入框
├── result_display.dart     // 结果显示区域
├── file_selector.dart      // 文件选择器
├── tab_page_scaffold.dart  // Tab页面脚手架
└── command_executor.dart   // 命令执行器
```

### 6.3 测试策略

1. **单元测试** - 每个页面独立测试
2. **集成测试** - 页面间导航和状态共享
3. **命令测试** - 验证所有命令正确发送
4. **UI测试** - 验证界面显示和交互

---

## 7. 总结

通过添加20个新页面，PM3GUI的覆盖率将从 **26%** 提升到 **100%**，实现对所有27个协议族的完整GUI支持。

### 关键收益
- **100% 协议覆盖** - 所有常用卡片类型都有GUI支持
- **统一用户体验** - 所有页面遵循相同的设计模式
- **零维护成本** - 命令兼容性自动继承自PM3客户端
- **可扩展架构** - 易于添加新的协议支持

### 文档清单
- ✅ `hf_mfu_page_spec.md` - Mifare Ultralight/NTAG
- ✅ `hf_mfdes_page_spec.md` - Mifare DESFire
- ✅ `hf_iclass_page_spec.md` - iCLASS/Picopass
- ✅ `hf_15_page_spec.md` - ISO15693
- ✅ `lf_hid_page_spec.md` - HID Prox
- ✅ `hf_14b_page_spec.md` - 14443-B
- 📋 其他15个协议文档待生成

### 下一步行动
1. 根据本文档生成剩余15个协议的详细文档
2. 提取公共组件，建立组件库
3. 按优先级分批实现页面
4. 建立完整的测试套件
5. 更新用户文档和教程
