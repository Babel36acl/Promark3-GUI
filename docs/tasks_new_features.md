# PM3GUI 新功能页面开发任务分解

> 下文任务、工时和复选状态保留为 PR #27 之前的规划记录，不是当前待办或功能清单。
> 新开发以 [当前实现与路线](refactoring_plan.md)、
> [本地化指南](localization.md) 和 [贡献指南](../CONTRIBUTING.md) 为准；
> 页面示例中的中文需替换为 ARB 资源，命令/数据格式保持原样。

## 任务总览

将规划文档中的5个新页面分解为具体可执行的任务。

---

## Phase 1: 基础准备 (P0)

### 任务 1.1: 更新导航结构
**文件**: `lib/ui/home_page.dart`
**依赖**: 无
**工时**: 30分钟

**子任务**:
- [ ] 1.1.1 添加新页面导入语句（先使用占位符类）
- [ ] 1.1.2 更新 `_pages` 列表，添加5个新页面占位符
- [ ] 1.1.3 更新 `_navItems` 列表，添加5个新导航项
- [ ] 1.1.4 验证应用能正常编译运行

**代码变更预览**:
```dart
// 导入新页面
import 'package:pm3gui/ui/pages/hf_mfu_page.dart';
import 'package:pm3gui/ui/pages/hf_iclass_page.dart';
import 'package:pm3gui/ui/pages/hf_15_page.dart';
import 'package:pm3gui/ui/pages/hf_mfdes_page.dart';
import 'package:pm3gui/ui/pages/lf_hid_page.dart';

// _pages 列表
final _pages = const [
  ConnectionPage(),
  TerminalPage(),
  DumpViewerPage(),
  DumpComparePage(),
  MifarePage(),
  HfMfuPage(),        // NEW
  HfIclassPage(),     // NEW
  Hf15Page(),         // NEW
  LfPage(),
  LfHidPage(),        // NEW
  SettingsPage(),
];

// _navItems 列表
static const _navItems = [
  _NavItem(Icons.usb, Icons.usb, '连接', '设备连接'),
  _NavItem(Icons.terminal, Icons.terminal, '终端', '交互终端'),
  _NavItem(Icons.file_open, Icons.file_open, 'Dump', '转储查看/编辑'),
  _NavItem(Icons.compare_arrows, Icons.compare_arrows, '对比', 'Dump 对比'),
  _NavItem(Icons.nfc, Icons.nfc, 'Mifare', 'Mifare Classic'),
  _NavItem(Icons.memory, Icons.memory, 'NTAG', 'Ultralight/NTAG'),
  _NavItem(Icons.badge, Icons.badge, 'iCLASS', 'iCLASS/Picopass'),
  _NavItem(Icons.contactless, Icons.contactless, 'ISO15693', 'ISO15693'),
  _NavItem(Icons.radio, Icons.radio, '低频', 'LF 操作'),
  _NavItem(Icons.door_front_door_outlined, Icons.door_front_door_outlined, 
           'HID', 'HID Prox'),
  _NavItem(Icons.settings, Icons.settings, '设置', '应用设置'),
];
```

---

## Phase 2: Mifare Ultralight/NTAG 页面 (P0)

### 任务 2.1: 创建页面框架
**文件**: `lib/ui/pages/hf_mfu_page.dart`
**依赖**: 无
**工时**: 1小时

**子任务**:
- [ ] 2.1.1 创建文件基础结构（imports, class定义）
- [ ] 2.1.2 实现 TabController（5个标签）
- [ ] 2.1.3 实现 `_execute()` 基础方法
- [ ] 2.1.4 创建5个空的 `_buildXxx()` 方法

### 任务 2.2: 实现"信息"标签
**工时**: 1小时

**子任务**:
- [ ] 2.2.1 添加 [获取信息] 按钮 -> `HfMfuCmd.info()`
- [ ] 2.2.2 添加 [转储卡片] 按钮 -> `HfMfuCmd.dump()`
- [ ] 2.2.3 添加 [擦除卡片] 按钮（带确认对话框）-> `HfMfuCmd.wipe()`
- [ ] 2.2.4 添加结果显示区域

### 任务 2.3: 实现"读写"标签
**工时**: 1.5小时

**子任务**:
- [ ] 2.3.1 添加块号输入框（0-255范围验证）
- [ ] 2.3.2 添加 [读取块] 按钮 -> `HfMfuCmd.rdbl()`
- [ ] 2.3.3 添加数据输入框（16字符hex验证）
- [ ] 2.3.4 添加 [写入块] 按钮 -> `HfMfuCmd.wrbl()`
- [ ] 2.3.5 添加密码输入框（8字符hex）
- [ ] 2.3.6 添加 [认证] 按钮 -> `HfMfuCmd.cauth()`

### 任务 2.4: 实现"NDEF"标签
**工时**: 1小时

**子任务**:
- [ ] 2.4.1 添加 [读取NDEF] 按钮 -> `HfMfuCmd.ndefRead()`
- [ ] 2.4.2 添加NDEF结果显示区域（格式化显示）

### 任务 2.5: 实现"模拟器"标签
**工时**: 1小时

**子任务**:
- [ ] 2.5.1 添加文件选择功能
- [ ] 2.5.2 添加 [加载到模拟器] 按钮 -> `HfMfuCmd.eload()`
- [ ] 2.5.3 添加 [保存模拟器] 按钮 -> `HfMfuCmd.esave()`
- [ ] 2.5.4 添加 [查看模拟器] 按钮 -> `HfMfuCmd.eview()`
- [ ] 2.5.5 添加 [模拟卡片] 按钮 -> `HfMfuCmd.sim()`

### 任务 2.6: 实现"工具"标签
**工时**: 1小时

**子任务**:
- [ ] 2.6.1 添加 [生成密钥] 按钮 -> `HfMfuCmd.keygen()`
- [ ] 2.6.2 添加UID输入框（可选）
- [ ] 2.6.3 添加 [生成密码] 按钮 -> `HfMfuCmd.pwdgen()`
- [ ] 2.6.4 添加 [设置UID] 按钮 -> `HfMfuCmd.setuid()`

---

## Phase 3: iCLASS/Picopass 页面 (P0)

### 任务 3.1: 创建页面框架
**文件**: `lib/ui/pages/hf_iclass_page.dart`
**依赖**: 无
**工时**: 1小时

**子任务**:
- [ ] 3.1.1 创建文件基础结构
- [ ] 3.1.2 实现 TabController（4个标签）
- [ ] 3.1.3 实现 `_execute()` 基础方法

### 任务 3.2: 实现"信息"标签
**工时**: 1小时

**子任务**:
- [ ] 3.2.1 添加 [获取信息] 按钮 -> `HfIclassCmd.info()`
- [ ] 3.2.2 添加 [读取卡片] 按钮 -> `HfIclassCmd.reader()`
- [ ] 3.2.3 添加 [转储卡片] 按钮 -> `HfIclassCmd.dump()`

### 任务 3.3: 实现"读写"标签
**工时**: 1.5小时

**子任务**:
- [ ] 3.3.1 添加块号选择器（0-31）
- [ ] 3.3.2 添加密钥输入框（16字符hex，可选）
- [ ] 3.3.3 添加 [读取块] 按钮 -> `HfIclassCmd.rdbl()`
- [ ] 3.3.4 添加数据输入框（16字符hex）
- [ ] 3.3.5 添加 [写入块] 按钮 -> `HfIclassCmd.wrbl()`

### 任务 3.4: 实现"破解"标签
**工时**: 1小时

**子任务**:
- [ ] 3.4.1 添加 [检查密钥] 按钮 -> `HfIclassCmd.chk()`
- [ ] 3.4.2 添加 [Loclass攻击] 按钮 -> `HfIclassCmd.loclass()`
- [ ] 3.4.3 添加 [嗅探通信] 按钮 -> `HfIclassCmd.sniff()`

### 任务 3.5: 实现"模拟器"标签
**工时**: 1小时

**子任务**:
- [ ] 3.5.1 添加 [加载文件] 按钮 -> `HfIclassCmd.eload()`
- [ ] 3.5.2 添加 [保存文件] 按钮 -> `HfIclassCmd.esave()`
- [ ] 3.5.3 添加 [查看] 按钮 -> `HfIclassCmd.eview()`
- [ ] 3.5.4 添加 [模拟卡片] 按钮 -> `HfIclassCmd.sim()`

---

## Phase 4: ISO15693 页面 (P1)

### 任务 4.1: 创建页面框架
**文件**: `lib/ui/pages/hf_15_page.dart`
**依赖**: 无
**工时**: 1小时

**子任务**:
- [ ] 4.1.1 创建文件基础结构
- [ ] 4.1.2 实现 TabController（3个标签）
- [ ] 4.1.3 实现 `_execute()` 基础方法

### 任务 4.2: 实现"信息"标签
**工时**: 1小时

**子任务**:
- [ ] 4.2.1 添加 [读取器] 按钮 -> `Hf15Cmd.reader()`
- [ ] 4.2.2 添加 [标签信息] 按钮 -> `Hf15Cmd.info()`
- [ ] 4.2.3 添加 [转储卡片] 按钮 -> `Hf15Cmd.dump()`
- [ ] 4.2.4 添加 [擦除卡片] 按钮 -> `Hf15Cmd.wipe()`

### 任务 4.3: 实现"读写"标签
**工时**: 1小时

**子任务**:
- [ ] 4.3.1 添加块号输入框
- [ ] 4.3.2 添加 [读取块] 按钮 -> `Hf15Cmd.rdbl()`
- [ ] 4.3.3 添加数据输入框
- [ ] 4.3.4 添加 [写入块] 按钮 -> `Hf15Cmd.wrbl()`

### 任务 4.4: 实现"工具"标签
**工时**: 1小时

**子任务**:
- [ ] 4.4.1 添加 [查找AFI] 按钮 -> `Hf15Cmd.findafi()`
- [ ] 4.4.2 添加UID输入框
- [ ] 4.4.3 添加 [设置UID] 按钮 -> `Hf15Cmd.csetuid()`
- [ ] 4.4.4 添加 [模拟卡片] 按钮 -> `Hf15Cmd.sim()`
- [ ] 4.4.5 添加 [嗅探] 按钮 -> `Hf15Cmd.sniff()`

---

## Phase 5: Mifare DESFire 页面 (P1)

### 任务 5.1: 创建页面框架
**文件**: `lib/ui/pages/hf_mfdes_page.dart`
**依赖**: 无
**工时**: 1小时

**子任务**:
- [ ] 5.1.1 创建文件基础结构
- [ ] 5.1.2 实现 TabController（4个标签）
- [ ] 5.1.3 实现 `_execute()` 基础方法

### 任务 5.2: 实现"信息"标签
**工时**: 1小时

**子任务**:
- [ ] 5.2.1 添加 [检测] 按钮 -> `HfMfdesCmd.detect()`
- [ ] 5.2.2 添加 [信息] 按钮 -> `HfMfdesCmd.info()`
- [ ] 5.2.3 添加 [获取UID] 按钮 -> `HfMfdesCmd.getuid()`
- [ ] 5.2.4 添加 [空闲内存] 按钮 -> `HfMfdesCmd.freemem()`
- [ ] 5.2.5 添加 [检查密钥] 按钮 -> `HfMfdesCmd.chk()`

### 任务 5.3: 实现"应用"标签
**工时**: 1小时

**子任务**:
- [ ] 5.3.1 添加 [列出AID] 按钮 -> `HfMfdesCmd.getaids()`
- [ ] 5.3.2 添加 [列出应用] 按钮 -> `HfMfdesCmd.lsapp()`
- [ ] 5.3.3 添加AID输入框（6字符hex）
- [ ] 5.3.4 添加 [选择应用] 按钮 -> `HfMfdesCmd.selectapp()`

### 任务 5.4: 实现"文件"标签
**工时**: 1.5小时

**子任务**:
- [ ] 5.4.1 添加 [列出文件] 按钮 -> `HfMfdesCmd.getfileids()`
- [ ] 5.4.2 添加FID输入框
- [ ] 5.4.3 添加 [读取文件] 按钮 -> `HfMfdesCmd.read()`
- [ ] 5.4.4 添加数据输入框
- [ ] 5.4.5 添加 [写入文件] 按钮 -> `HfMfdesCmd.write()`
- [ ] 5.4.6 添加 [转储应用] 按钮 -> `HfMfdesCmd.dump()`

### 任务 5.5: 实现"管理"标签
**工时**: 1小时

**子任务**:
- [ ] 5.5.1 添加密钥号输入框
- [ ] 5.5.2 添加密钥输入框
- [ ] 5.5.3 添加算法选择（AES/DES）
- [ ] 5.5.4 添加 [认证] 按钮 -> `HfMfdesCmd.auth()`
- [ ] 5.5.5 添加 [格式化PICC] 按钮（带确认）-> `HfMfdesCmd.formatpicc()`

---

## Phase 6: HID Prox 页面 (P1)

### 任务 6.1: 创建页面框架
**文件**: `lib/ui/pages/lf_hid_page.dart`
**依赖**: 无
**工时**: 1小时

**子任务**:
- [ ] 6.1.1 创建文件基础结构
- [ ] 6.1.2 实现 TabController（3个标签）
- [ ] 6.1.3 实现 `_execute()` 基础方法

### 任务 6.2: 实现"读取"标签
**工时**: 1小时

**子任务**:
- [ ] 6.2.1 添加 [读取HID卡] 按钮 -> `LfHidCmd.reader()`
- [ ] 6.2.2 添加 [解调信号] 按钮 -> `LfHidCmd.demod()`
- [ ] 6.2.3 添加结果显示区域（解析FC/CN）

### 任务 6.3: 实现"克隆/模拟"标签
**工时**: 1小时

**子任务**:
- [ ] 6.3.1 添加卡号数据输入框（Wiegand格式）
- [ ] 6.3.2 添加 [克隆到T55xx] 按钮 -> `LfHidCmd.clone()`
- [ ] 6.3.3 添加 [模拟卡片] 按钮 -> `LfHidCmd.sim()`

### 任务 6.4: 实现"破解"标签
**工时**: 1小时

**子任务**:
- [ ] 6.4.1 添加FC输入框（可选）
- [ ] 6.4.2 添加 [暴力破解] 按钮 -> `LfHidCmd.brute()`

---

## Phase 7: 测试与优化

### 任务 7.1: 单元测试
**工时**: 2小时

**子任务**:
- [ ] 7.1.1 测试每个页面的Tab切换
- [ ] 7.1.2 测试所有按钮触发正确的命令
- [ ] 7.1.3 测试输入验证（hex格式、长度）
- [ ] 7.1.4 测试未连接设备时的提示

### 任务 7.2: 集成测试
**工时**: 1小时

**子任务**:
- [ ] 7.2.1 测试侧边栏导航正确切换页面
- [ ] 7.2.2 测试主题切换正常
- [ ] 7.2.3 测试与现有页面无冲突
- [ ] 7.2.4 测试应用启动和运行性能

### 任务 7.3: 代码优化
**工时**: 2小时

**子任务**:
- [ ] 7.3.1 提取公共组件（ActionCard, ResultDisplay等）
- [ ] 7.3.2 优化重复代码
- [ ] 7.3.3 添加必要的注释
- [ ] 7.3.4 运行 `flutter analyze` 检查问题

---

## 时间估算汇总

| Phase | 任务数 | 预估工时 | 实际工时 |
|:-----:|:------:|:--------:|:--------:|
| Phase 1: 基础准备 | 1 | 0.5h | - |
| Phase 2: MFU页面 | 6 | 6.5h | - |
| Phase 3: iCLASS页面 | 5 | 5.5h | - |
| Phase 4: ISO15693页面 | 4 | 4h | - |
| Phase 5: DESFire页面 | 5 | 5.5h | - |
| Phase 6: HID页面 | 4 | 4h | - |
| Phase 7: 测试优化 | 3 | 5h | - |
| **总计** | **28** | **31h** | - |

---

## 依赖关系图

```
Phase 1: 基础准备
    │
    ├───> Phase 2: MFU页面 ───┐
    │                         │
    ├───> Phase 3: iCLASS页面 ─┤
    │                          │
    ├───> Phase 4: ISO15693页面─┼───> Phase 7: 测试优化
    │                           │
    ├───> Phase 5: DESFire页面 ─┤
    │                           │
    └───> Phase 6: HID页面 ─────┘
```

**说明**: 
- Phase 2-6 可以并行开发
- Phase 7 必须在所有页面完成后进行
- 每个Phase内部的任务建议按顺序执行

---

## 风险与缓解

| 风险 | 可能性 | 影响 | 缓解措施 |
|:-----|:------:|:----:|:---------|
| 命令参数不匹配 | 中 | 高 | 参考pm3_commands.yaml和实际CLI测试 |
| 页面过多导致导航拥挤 | 中 | 中 | 考虑添加折叠菜单或分类 |
| 状态管理复杂化 | 低 | 中 | 保持每个页面独立状态，不增加全局状态 |
| 编译问题 | 低 | 高 | 每次修改后及时运行flutter analyze |
