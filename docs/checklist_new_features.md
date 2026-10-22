# PM3GUI 新功能页面开发检查清单

> 下文 Phase 清单与原有勾选状态保留为 PR #27 之前的设计记录，不代表当前实现进度、
> SDK 要求或受支持平台。当前开发入口见 [文档索引](README.md) 和
> [Localization](localization.md)；不要直接复制旧示例中的硬编码中文。

## 当前新增页面的本地化验收（PR #27）

- [ ] 中英文 ARB 资源齐全，句子使用具名占位符，名词/动作等不同含义使用不同键。
- [ ] 标签、工具提示、校验、确认/危险提示、空状态和错误均使用当前界面语言。
- [ ] 临时校验模型继承当前语言；失败导入不改变原数据。
- [ ] 原始 PM3 命令、十六进制数据、协议标识和持久化字段不被翻译。
- [ ] 独立 Dart 工具不引入 Flutter 运行时依赖，实际 `dart run` 入口有回归覆盖。
- [ ] 语言目录查找/保存失败可在设置页看到，初始化仍可完成，后续保存可重试。
- [ ] 中英文的页面、对话框、默认/较小桌面窗口与文本放大均经过针对性检查。
- [ ] 修改后运行 `flutter gen-l10n`、资源完整性检查、静态分析和相关测试。
- [ ] 同步 Markdown/HTML 文档，并明确区分代码测试、Linux 构建和真实设备验证。

## 开发前检查

### 环境准备

- [x] Flutter SDK 3.24+ 已安装
- [x] 项目依赖已更新 (`flutter pub get`)
- [x] 现有代码无编译错误 (`flutter analyze`)
- [x] 应用能正常启动运行

### 代码审查

- [x] 已阅读 [pm3_commands.dart](../lib/services/pm3_commands.dart) 了解可用命令
- [x] 已阅读 [mifare_page.dart](../lib/ui/pages/mifare_page.dart) 了解代码模式
- [x] 已阅读 [home_page.dart](../lib/ui/home_page.dart) 了解导航结构

---

## Phase 1: 基础准备

### 任务 1.1: 更新导航结构

**文件**: `lib/ui/home_page.dart`

#### 导入语句

- [ ] 添加 `hf_mfu_page.dart` 导入
- [ ] 添加 `hf_iclass_page.dart` 导入
- [ ] 添加 `hf_15_page.dart` 导入
- [ ] 添加 `hf_mfdes_page.dart` 导入
- [ ] 添加 `lf_hid_page.dart` 导入

#### _pages 列表更新

- [ ] 在 `MifarePage()` 后添加 `HfMfuPage()`
- [ ] 添加 `HfIclassPage()`
- [ ] 添加 `Hf15Page()`
- [ ] 在 `LfPage()` 后添加 `LfHidPage()`

#### _navItems 列表更新

- [ ] 添加 NTAG 导航项 (Icons.memory)
- [ ] 添加 iCLASS 导航项 (Icons.badge)
- [ ] 添加 ISO15693 导航项 (Icons.contactless)
- [ ] 添加 HID 导航项 (Icons.door_front_door_outlined)

#### 验证

- [ ] `flutter analyze` 无错误
- [ ] 应用能正常编译
- [ ] 侧边栏显示所有新导航项

---

## Phase 2: Mifare Ultralight/NTAG 页面

### 文件: `lib/ui/pages/hf_mfu_page.dart`

#### 基础结构

- [ ] 文件头部包含 `library;` 声明
- [ ] 所有必要的 imports
- [ ] `HfMfuPage` StatefulWidget 类
- [ ] `_HfMfuPageState` 状态类
- [ ] `SingleTickerProviderStateMixin` 混入
- [ ] TabController 初始化和释放

#### Tab 结构 (5个标签)

- [ ] TabBar 包含5个 Tab
- [ ] TabBarView 包含5个对应页面
- [ ] 标签: 信息、读写、NDEF、模拟器、工具

#### "信息"标签

- [ ] [获取信息] 按钮 -> `HfMfuCmd.info()`
- [ ] [转储卡片] 按钮 -> `HfMfuCmd.dump()`
- [ ] [擦除卡片] 按钮 -> `HfMfuCmd.wipe()` (带确认对话框)
- [ ] 结果显示区域

#### "读写"标签

- [ ] 块号输入框 (0-255)
- [ ] [读取块] 按钮 -> `HfMfuCmd.rdbl()`
- [ ] 数据输入框 (16字符hex验证)
- [ ] [写入块] 按钮 -> `HfMfuCmd.wrbl()`
- [ ] 密码输入框 (8字符hex)
- [ ] [认证] 按钮 -> `HfMfuCmd.cauth()`

#### "NDEF"标签

- [ ] [读取NDEF] 按钮 -> `HfMfuCmd.ndefRead()`
- [ ] NDEF结果显示区域

#### "模拟器"标签

- [ ] 文件选择功能
- [ ] [加载到模拟器] -> `HfMfuCmd.eload()`
- [ ] [保存模拟器] -> `HfMfuCmd.esave()`
- [ ] [查看模拟器] -> `HfMfuCmd.eview()`
- [ ] [模拟卡片] -> `HfMfuCmd.sim()`

#### "工具"标签

- [ ] [生成密钥] -> `HfMfuCmd.keygen()`
- [ ] UID输入框 (可选)
- [ ] [生成密码] -> `HfMfuCmd.pwdgen()`
- [ ] [设置UID] -> `HfMfuCmd.setuid()`

#### 通用功能

- [ ] `_execute()` 方法检查连接状态
- [ ] 未连接时显示 SnackBar 提示
- [ ] 使用等宽字体显示hex数据
- [ ] 危险操作有确认对话框

---

## Phase 3: iCLASS/Picopass 页面

### 文件: `lib/ui/pages/hf_iclass_page.dart`

#### 基础结构

- [ ] 正确的 imports
- [ ] StatefulWidget 结构
- [ ] TabController (4个标签)

#### Tab 结构 (4个标签)

- [ ] 标签: 信息、读写、破解、模拟器

#### "信息"标签

- [ ] [获取信息] -> `HfIclassCmd.info()`
- [ ] [读取卡片] -> `HfIclassCmd.reader()`
- [ ] [转储卡片] -> `HfIclassCmd.dump()`

#### "读写"标签

- [ ] 块号选择器 (0-31)
- [ ] 密钥输入框 (16字符hex, 可选)
- [ ] [读取块] -> `HfIclassCmd.rdbl()`
- [ ] 数据输入框 (16字符hex)
- [ ] [写入块] -> `HfIclassCmd.wrbl()`

#### "破解"标签

- [ ] [检查密钥] -> `HfIclassCmd.chk()`
- [ ] [Loclass攻击] -> `HfIclassCmd.loclass()`
- [ ] [嗅探通信] -> `HfIclassCmd.sniff()`

#### "模拟器"标签

- [ ] [加载文件] -> `HfIclassCmd.eload()`
- [ ] [保存文件] -> `HfIclassCmd.esave()`
- [ ] [查看] -> `HfIclassCmd.eview()`
- [ ] [模拟卡片] -> `HfIclassCmd.sim()`

---

## Phase 4: ISO15693 页面

### 文件: `lib/ui/pages/hf_15_page.dart`

#### 基础结构

- [ ] 正确的 imports
- [ ] StatefulWidget 结构
- [ ] TabController (3个标签)

#### Tab 结构 (3个标签)

- [ ] 标签: 信息、读写、工具

#### "信息"标签

- [ ] [读取器] -> `Hf15Cmd.reader()`
- [ ] [标签信息] -> `Hf15Cmd.info()`
- [ ] [转储卡片] -> `Hf15Cmd.dump()`
- [ ] [擦除卡片] -> `Hf15Cmd.wipe()`

#### "读写"标签

- [ ] 块号输入框
- [ ] [读取块] -> `Hf15Cmd.rdbl()`
- [ ] 数据输入框
- [ ] [写入块] -> `Hf15Cmd.wrbl()`

#### "工具"标签

- [ ] [查找AFI] -> `Hf15Cmd.findafi()`
- [ ] UID输入框
- [ ] [设置UID] -> `Hf15Cmd.csetuid()`
- [ ] [模拟卡片] -> `Hf15Cmd.sim()`
- [ ] [嗅探] -> `Hf15Cmd.sniff()`

---

## Phase 5: Mifare DESFire 页面

### 文件: `lib/ui/pages/hf_mfdes_page.dart`

#### 基础结构

- [ ] 正确的 imports
- [ ] StatefulWidget 结构
- [ ] TabController (4个标签)

#### Tab 结构 (4个标签)

- [ ] 标签: 信息、应用、文件、管理

#### "信息"标签

- [ ] [检测] -> `HfMfdesCmd.detect()`
- [ ] [信息] -> `HfMfdesCmd.info()`
- [ ] [获取UID] -> `HfMfdesCmd.getuid()`
- [ ] [空闲内存] -> `HfMfdesCmd.freemem()`
- [ ] [检查密钥] -> `HfMfdesCmd.chk()`

#### "应用"标签

- [ ] [列出AID] -> `HfMfdesCmd.getaids()`
- [ ] [列出应用] -> `HfMfdesCmd.lsapp()`
- [ ] AID输入框 (6字符hex)
- [ ] [选择应用] -> `HfMfdesCmd.selectapp()`

#### "文件"标签

- [ ] [列出文件] -> `HfMfdesCmd.getfileids()`
- [ ] FID输入框
- [ ] [读取文件] -> `HfMfdesCmd.read()`
- [ ] 数据输入框
- [ ] [写入文件] -> `HfMfdesCmd.write()`
- [ ] [转储应用] -> `HfMfdesCmd.dump()`

#### "管理"标签

- [ ] 密钥号输入框
- [ ] 密钥输入框
- [ ] 算法选择 (AES/DES)
- [ ] [认证] -> `HfMfdesCmd.auth()`
- [ ] [格式化PICC] 按钮（带确认）-> `HfMfdesCmd.formatpicc()`

---

## Phase 6: HID Prox 页面

### 文件: `lib/ui/pages/lf_hid_page.dart`

#### 基础结构

- [ ] 正确的 imports
- [ ] StatefulWidget 结构
- [ ] TabController (3个标签)

#### Tab 结构 (3个标签)

- [ ] 标签: 读取、克隆/模拟、破解

#### "读取"标签

- [ ] [读取HID卡] -> `LfHidCmd.reader()`
- [ ] [解调信号] -> `LfHidCmd.demod()`
- [ ] 结果显示区域（解析FC/CN）

#### "克隆/模拟"标签

- [ ] 卡号数据输入框（Wiegand格式）
- [ ] [克隆到T55xx] -> `LfHidCmd.clone()`
- [ ] [模拟卡片] -> `LfHidCmd.sim()`

#### "破解"标签

- [ ] FC输入框（可选）
- [ ] [暴力破解] -> `LfHidCmd.brute()`

---

## Phase 7: 测试与优化

### 任务 7.1: 单元测试

- [ ] 测试每个页面的Tab切换
- [ ] 测试所有按钮触发正确的命令
- [ ] 测试输入验证（hex格式、长度）
- [ ] 测试未连接设备时的提示

### 任务 7.2: 集成测试

- [ ] 测试侧边栏导航正确切换页面
- [ ] 测试主题切换正常
- [ ] 测试与现有页面无冲突
- [ ] 测试应用启动和运行性能

### 任务 7.3: 代码优化

- [ ] 提取公共组件（ActionCard, ResultDisplay等）
- [ ] 优化重复代码
- [ ] 添加必要的注释
- [ ] 运行 `flutter analyze` 检查问题

---

## 配色更改检查清单

### 已完成的更改

#### 1. 主题文件更新 (`lib/ui/theme.dart`)

- [x] 切换到单模式主题
- [x] 使用深蓝色仪表盘配色方案
- [x] 移除 lightTheme() 方法
- [x] 重命名 darkTheme() 为 theme()
- [x] 更新所有颜色引用
- [x] 修复 deprecated `withOpacity` 方法

#### 2. 应用状态更新 (`lib/state/app_state.dart`)

- [x] 移除 `isDarkMode` 状态
- [x] 移除 `toggleTheme()` 方法

#### 3. 主应用更新 (`lib/main.dart`)

- [x] 更新主题引用为 `AppTheme.theme()`
- [x] 移除主题模式切换逻辑

#### 4. 主页面更新 (`lib/ui/home_page.dart`)

- [x] 移除主题切换按钮
- [x] 清理相关代码

#### 5. 设置页面更新 (`lib/ui/settings_page.dart`)

- [x] 移除主题设置选项

#### 6. 连接页面更新 (`lib/ui/pages/connection_page.dart`)

- [x] 导入新的主题文件
- [x] 替换所有莫兰迪颜色引用
- [x] 使用新的蓝色主题色彩

#### 7. 编译验证

- [x] `flutter analyze` 无错误
- [x] 应用能正常编译

### 配色方案

- **深蓝背景**: `#0F172A`
- **卡片色**: `#1E293B`
- **高亮蓝**: `#38BDF8`
- **辅助灰文**: `#94A3B8`
- **分隔线**: `#334155`
- **错误色**: `#F87171`

### 验证结果

- [x] 应用启动正常
- [x] 所有页面显示正确
- [x] 颜色风格统一
- [x] 无编译错误

---

## 总结

配色更改已完成，应用现在使用深蓝色仪表盘风格的单主题模式。所有相关文件已更新，编译验证通过。接下来可以开始实施新功能页面的开发。
