# PM3GUI 新功能页面开发规划文档

> 这是 PR #27 之前的原始功能设计参考，不是当前功能或平台完成情况。
> 中文布局/代码示例保留作设计说明；当前实现须使用 [Localization](localization.md)
> 规定的中英文资源、消息注入和校验行为，不能重新引入硬编码中文。
> 最新使用与支持范围见 [文档索引](README.md)。

## 1. 项目概述

### 1.1 目标
为PM3GUI添加新的功能页面，扩展对Proxmark3命令的覆盖范围，优先实现高频卡片（HF）和低频卡片（LF）中常用但未GUI化的功能。

### 1.2 设计原则
- **一致性**：新页面遵循现有页面的设计风格和代码模式
- **渐进式**：优先实现最常用的功能，逐步完善
- **可扩展性**：架构支持后续轻松添加更多协议支持

---

## 2. 新增功能页面规划

### 2.1 页面优先级排序

| 优先级 | 页面名称 | 协议 | 理由 |
|:------:|:--------:|:----:|:----:|
| P0 | **Mifare Ultralight/NTAG** | hf mfu | 最常见的高频卡之一，使用广泛 |
| P0 | **iCLASS/Picopass** | hf iclass | 门禁系统常用，需求量大 |
| P1 | **ISO15693** | hf 15 | 工业和图书馆标签常用 |
| P1 | **Mifare DESFire** | hf mfdes | 高级安全卡片 |
| P1 | **HID Prox** | lf hid | 最常见的低频门禁卡 |
| P2 | **FeliCa** | hf felica | 日本地区常用 |
| P2 | **Hitag** | lf hitag | 车钥匙等应用 |

---

## 3. 详细设计规格

### 3.1 Mifare Ultralight/NTAG 页面 (hf_mfu_page.dart)

#### 3.1.1 功能范围
基于 `HfMfuCmd` 类中定义的17个命令：
- `info()` - 标签信息
- `dump()` - 转储卡片数据
- `rdbl()` - 读取块
- `wrbl()` - 写入块
- `restore()` - 恢复卡片
- `view()` - 查看转储文件
- `wipe()` - 擦除卡片
- `ndefRead()` - 读取NDEF数据
- `keygen()` - 生成密钥
- `pwdgen()` - 生成密码
- `cauth()` - 认证
- `cchk()` - 检查密码
- `sim()` - 模拟卡片
- `eload()` - 加载到模拟器
- `esave()` - 保存模拟器数据
- `eview()` - 查看模拟器
- `setuid()` - 设置UID

#### 3.1.2 页面布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [信息] [读写] [NDEF] [模拟器] [工具]                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 信息:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [获取信息]  [转储卡片]  [擦除卡片]                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 读写:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 块号: [0-255 ▼]  [读取块]                              │   │
│  │ 数据: [________________] [写入块]                      │   │
│  │ 密码: [________________] [认证]                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - NDEF:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [读取NDEF]  结果显示区域...                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 4 - 模拟器:                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [加载文件] [保存到文件] [查看] [模拟]                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 5 - 工具:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [生成密钥] [生成密码] [设置UID]                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 3.1.3 关键实现细节
- 块号范围：0-255（NTAG216最大支持）
- 数据格式：8字节hex（16字符）
- 密码格式：4字节hex（8字符）
- UID格式：7字节hex（14字符）

---

### 3.2 iCLASS/Picopass 页面 (hf_iclass_page.dart)

#### 3.2.1 功能范围
基于 `HfIclassCmd` 类，优先实现核心功能：
- `info()` - 标签信息
- `reader()` - 读取器模式
- `dump()` - 转储卡片
- `rdbl()` - 读取块
- `wrbl()` - 写入块
- `restore()` - 恢复卡片
- `view()` - 查看转储
- `sniff()` - 嗅探
- `chk()` - 密钥检查
- `loclass()` - 离线破解
- `sim()` - 模拟
- `eload()/esave()/eview()` - 模拟器操作

#### 3.2.2 页面布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [信息] [读写] [破解] [模拟器]                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 信息:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [获取信息]  [读取卡片]  [转储卡片]                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 读写:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 块号: [0-31 ▼]  密钥: [________________] [读取]         │   │
│  │ 数据: [________________] [写入]                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - 破解:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [检查密钥]  [Loclass攻击]  [嗅探通信]                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 4 - 模拟器:                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [加载] [保存] [查看] [模拟]                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 3.2.3 关键实现细节
- 块号范围：0-31（iCLASS 2K）
- 密钥格式：8字节hex（16字符）
- 数据格式：8字节hex（16字符）

---

### 3.3 ISO15693 页面 (hf_15_page.dart)

#### 3.3.1 功能范围
基于 `Hf15Cmd` 类，实现核心功能：
- `reader()` - 读取器
- `info()` - 标签信息
- `dump()` - 转储
- `restore()` - 恢复
- `rdbl()` - 读取块
- `wrbl()` - 写入块
- `view()` - 查看转储
- `wipe()` - 擦除
- `sniff()` - 嗅探
- `sim()` - 模拟
- `findafi()` - 查找AFI
- `csetuid()` - 设置UID

#### 3.3.2 页面布局
类似Mifare页面结构，包含：
- 信息标签：读取、信息、转储
- 读写标签：块读写操作
- 工具标签：AFI查找、UID设置、模拟

---

### 3.4 Mifare DESFire 页面 (hf_mfdes_page.dart)

#### 3.4.1 功能范围
基于 `HfMfdesCmd` 类，实现基础功能：
- `info()` - 标签信息
- `detect()` - 检测
- `getuid()` - 获取UID
- `freemem()` - 空闲内存
- `chk()` - 密钥检查
- `auth()` - 认证
- `formatpicc()` - 格式化
- `getaids()` - 获取AID列表
- `lsapp()` - 列出应用
- `selectapp()` - 选择应用
- `dump()` - 转储
- `read()` - 读取文件
- `write()` - 写入文件

#### 3.4.2 页面布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [信息] [应用] [文件] [管理]                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 信息:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [检测] [信息] [UID] [空闲内存] [检查密钥]                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 应用:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [列出AID] [列出应用]                                   │   │
│  │ AID: [________] [选择应用]                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - 文件:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [列出文件] [转储应用]                                  │   │
│  │ FID: [____] [读取] [写入]                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 4 - 管理:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [认证] [格式化PICC]                                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

### 3.5 HID Prox 页面 (lf_hid_page.dart)

#### 3.5.1 功能范围
基于 `LfHidCmd` 类：
- `reader()` - 读取
- `demod()` - 解调
- `clone()` - 克隆
- `sim()` - 模拟
- `brute()` - 暴力破解

#### 3.5.2 页面布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [读取] [克隆/模拟] [破解]                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 读取:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [读取HID卡] [解调信号]                                  │   │
│  │ 结果显示区域...                                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 克隆/模拟:                                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 卡号数据: [________________]                           │   │
│  │ [克隆到T55xx] [模拟卡片]                                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - 破解:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ FC: [____] (可选)                                      │   │
│  │ [暴力破解]                                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. 技术实现规范

### 4.1 文件结构
```
lib/
├── ui/
│   ├── pages/
│   │   ├── hf_mfu_page.dart      # NEW: Ultralight/NTAG
│   │   ├── hf_iclass_page.dart   # NEW: iCLASS/Picopass
│   │   ├── hf_15_page.dart       # NEW: ISO15693
│   │   ├── hf_mfdes_page.dart    # NEW: DESFire
│   │   ├── lf_hid_page.dart      # NEW: HID Prox
│   │   └── ... (existing pages)
│   └── home_page.dart            # MODIFY: 添加导航项
├── services/
│   └── pm3_commands.dart         # EXISTING: 已包含所需命令
└── state/
    └── app_state.dart            # EXISTING: 无需修改
```

### 4.2 代码模式

每个新页面遵循以下模式：

```dart
/// 页面名称操作页
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_commands.dart';

class XxxPage extends StatefulWidget {
  const XxxPage({super.key});

  @override
  State<XxxPage> createState() => _XxxPageState();
}

class _XxxPageState extends State<XxxPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // ... 状态变量

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
    appState.sendCommand(cmd);
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
  // ... _buildTabX() 方法
}
```

### 4.3 导航集成

在 `home_page.dart` 中：

```dart
// 1. 导入新页面
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
// ...

// 2. 添加到 _pages 列表
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  MifarePage(),
  HfMfuPage(),        // NEW
  HfIclassPage(),     // NEW
  LfPage(),
  LfHidPage(),        // NEW
  SettingsPage(),
];

// 3. 添加到 _navItems 列表
static const _navItems = [
  _NavItem(Icons.usb, Icons.usb, '连接', '设备连接'),
  _NavItem(Icons.terminal, Icons.terminal, '终端', '交互终端'),
  _NavItem(Icons.file_open, Icons.file_open, 'Dump', '转储查看/编辑'),
  _NavItem(Icons.compare_arrows, Icons.compare_arrows, '对比', 'Dump 对比'),
  _NavItem(Icons.nfc, Icons.nfc, 'Mifare', 'Mifare Classic'),
  _NavItem(Icons.memory, Icons.memory, 'NTAG', 'Ultralight/NTAG'),  // NEW
  _NavItem(Icons.badge, Icons.badge, 'iCLASS', 'iCLASS/Picopass'),  // NEW
  _NavItem(Icons.radio, Icons.radio, '低频', 'LF 操作'),
  _NavItem(Icons.door_front_door_outlined, Icons.door_front_door_outlined, 
           'HID', 'HID Prox'),  // NEW
  _NavItem(Icons.settings, Icons.settings, '设置', '应用设置'),
];
```

---

## 5. UI/UX 设计规范

### 5.1 颜色使用
延续莫兰迪色系：
- 主色调：`#7E9AAB` (莫兰迪蓝)
- 成功/高频：`#8FA9A0` (莫兰迪绿)
- 警告/低频：`#BFA2A2` (莫兰迪玫瑰)
- 次要信息：`#A89F91` (莫兰迪暖灰)

### 5.2 组件规范
- **操作卡片**：使用 `Card` + `ListTile`，带图标和副标题
- **输入框**：使用 `TextFormField`，等宽字体显示hex数据
- **按钮**：主要操作用 `ElevatedButton`，次要操作用 `OutlinedButton`
- **分段按钮**：使用 `SegmentedButton` 进行选项切换

### 5.3 交互反馈
- 命令执行中显示加载指示器
- 结果显示在可滚动的卡片中
- 支持复制结果到剪贴板
- 危险操作（如擦除）需要确认对话框

---

## 6. 测试计划

### 6.1 功能测试
- [ ] 各页面Tab切换正常
- [ ] 所有按钮能正确发送命令
- [ ] 输入验证（hex格式、长度检查）
- [ ] 结果显示和复制功能
- [ ] 未连接设备时的提示

### 6.2 集成测试
- [ ] 新页面与侧边栏导航集成
- [ ] 主题切换正常
- [ ] 与现有页面共存无冲突

---

## 7. 附录

### 7.1 参考资源
- [pm3_commands.yaml](pm3_commands.yaml) - 命令映射参考
- [pm3_commands.dart](../lib/services/pm3_commands.dart) - 命令封装类
- [mifare_page.dart](../lib/ui/pages/mifare_page.dart) - 参考实现

### 7.2 命令快速参考

```bash
# Mifare Ultralight
hf mfu info
hf mfu dump -f <file>
hf mfu rdbl -b <block>
hf mfu wrbl -b <block> -d <data>
hf mfu ndefread

# iCLASS
hf iclass info
hf iclass dump -f <file>
hf iclass rdbl -b <block> [-k <key>]
hf iclass wrbl -b <block> -d <data> [-k <key>]

# ISO15693
hf 15 reader
hf 15 dump -f <file>
hf 15 rdbl -b <block>
hf 15 wrbl -b <block> -d <data>

# HID Prox
lf hid reader
lf hid clone -w <data>
lf hid sim -w <data>
```
