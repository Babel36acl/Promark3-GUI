# Mifare Ultralight/NTAG 页面文档

> 原始设计参考（PR #27 之前）。下文中文图示、示例和功能目标不等于当前实现或实卡
> 验证情况；新增/修改界面须使用 [中英文 ARB 与校验契约](localization.md)。
> 当前使用与支持范围见 [README](../README.md)。

## 1. 页面概述

### 1.1 功能目标
实现 Mifare Ultralight、NTAG 系列卡片的完整操作界面，包括信息读取、数据读写、NDEF 操作、卡片模拟等功能。

### 1.2 技术实现
- **文件**: `lib/ui/pages/hf_mfu_page.dart`
- **类名**: `HfMfuPage`
- **继承**: `StatefulWidget`
- **核心命令类**: `HfMfuCmd`

---

## 2. 页面结构

### 2.1 整体布局
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

### 2.2 组件结构

```dart
class HfMfuPage extends StatefulWidget {
  const HfMfuPage({super.key});
  @override
  State<HfMfuPage> createState() => _HfMfuPageState();
}

class _HfMfuPageState extends State<HfMfuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  int _blockNumber = 0;
  String _blockData = '';
  String _password = '';
  String _uid = '';
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 执行命令方法
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
            Tab(text: '信息'),
            Tab(text: '读写'),
            Tab(text: 'NDEF'),
            Tab(text: '模拟器'),
            Tab(text: '工具'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
              _buildNdefTab(),
              _buildEmulatorTab(),
              _buildToolsTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 各个Tab的构建方法
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildNdefTab() { ... }
  Widget _buildEmulatorTab() { ... }
  Widget _buildToolsTab() { ... }
}
```

---

## 3. 功能实现

### 3.1 核心命令映射

| 按钮 | 命令 | 说明 |
|------|------|------|
| 获取信息 | `hf mfu info` | 读取标签基本信息 |
| 转储卡片 | `hf mfu dump -f dump.mfu` | 转储整个卡片数据 |
| 擦除卡片 | `hf mfu wipe` | 擦除整个卡片 |
| 读取块 | `hf mfu rdbl -b <block>` | 读取指定块数据 |
| 写入块 | `hf mfu wrbl -b <block> -d <data>` | 写入数据到指定块 |
| 认证 | `hf mfu cauth -p <pwd>` | 使用密码认证 |
| 读取NDEF | `hf mfu ndefread` | 读取NDEF数据 |
| 加载到模拟器 | `hf mfu eload -f <file>` | 加载dump文件到模拟器 |
| 保存模拟器 | `hf mfu esave -f <file>` | 保存模拟器数据到文件 |
| 查看模拟器 | `hf mfu eview` | 查看模拟器当前状态 |
| 模拟卡片 | `hf mfu sim` | 开始模拟卡片 |
| 生成密钥 | `hf mfu keygen` | 生成默认密钥 |
| 生成密码 | `hf mfu pwdgen` | 生成默认密码 |
| 设置UID | `hf mfu setuid -u <uid>` | 设置卡片UID |

### 3.2 信息标签

```dart
Widget _buildInfoTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('获取信息'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu dump -f dump.mfu'),
              icon: const Icon(Icons.download),
              label: const Text('转储卡片'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认擦除'),
                    content: const Text('确定要擦除整个卡片吗？此操作不可恢复！'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _execute('hf mfu wipe');
                        },
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('擦除卡片'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF87171),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.3 读写标签

```dart
Widget _buildReadWriteTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('块号: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: DropdownButton<int>(
                value: _blockNumber,
                onChanged: (value) => setState(() => _blockNumber = value!),
                items: List.generate(256, (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.toString()),
                )),
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfu rdbl -b $_blockNumber'),
              child: const Text('读取块'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('数据: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _blockData),
                onChanged: (value) => _blockData = value,
                decoration: const InputDecoration(
                  hintText: '16位十六进制数据',
                  helperText: '例如: 0011223344556677',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(16),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfu wrbl -b $_blockNumber -d $_blockData'),
              child: const Text('写入块'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('密码: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _password),
                onChanged: (value) => _password = value,
                decoration: const InputDecoration(
                  hintText: '8位十六进制密码',
                  helperText: '例如: 00112233',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(8),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfu cauth -p $_password'),
              child: const Text('认证'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.4 NDEF标签

```dart
Widget _buildNdefTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _execute('hf mfu ndefread'),
          icon: const Icon(Icons.nfc),
          label: const Text('读取NDEF'),
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.5 模拟器标签

```dart
Widget _buildEmulatorTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  allowedExtensions: ['mfu', 'bin', 'dump'],
                );
                if (result != null) {
                  _execute('hf mfu eload -f ${result.files.single.path}');
                }
              },
              icon: const Icon(Icons.file_open),
              label: const Text('加载文件'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu esave -f emulator.mfu'),
              icon: const Icon(Icons.save),
              label: const Text('保存到文件'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu eview'),
              icon: const Icon(Icons.visibility),
              label: const Text('查看'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu sim'),
              icon: const Icon(Icons.phone_android),
              label: const Text('模拟'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.6 工具标签

```dart
Widget _buildToolsTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu keygen'),
              icon: const Icon(Icons.key),
              label: const Text('生成密钥'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu pwdgen'),
              icon: const Icon(Icons.lock),
              label: const Text('生成密码'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('设置UID'),
                    content: TextField(
                      controller: TextEditingController(text: _uid),
                      onChanged: (value) => _uid = value,
                      decoration: const InputDecoration(
                        hintText: '14位十六进制UID',
                        helperText: '例如: 0123456789ABC',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                        LengthLimitingTextInputFormatter(14),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _execute('hf mfu setuid -u $_uid');
                        },
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('设置UID'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.7 结果显示组件

```dart
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
```

---

## 4. UI/UX 设计

### 4.1 颜色使用
- **主色调**: `AppTheme.accentBlue` (#38BDF8)
- **背景色**: `AppTheme.darkBg` (#0F172A)
- **卡片色**: `AppTheme.darkSurface` (#1E293B)
- **文本色**: `AppTheme.auxiliaryGrey` (#94A3B8)
- **错误色**: `#F87171`

### 4.2 交互设计
- **按钮样式**: 使用 `ElevatedButton` 和 `OutlinedButton`
- **输入验证**: 实时验证hex格式和长度
- **加载状态**: 执行命令时显示 `CircularProgressIndicator`
- **结果显示**: 使用等宽字体显示命令输出
- **危险操作**: 擦除等危险操作需要确认对话框
- **文件选择**: 使用 `file_picker` 插件选择文件

### 4.3 响应式设计
- 适配不同屏幕尺寸
- 在小屏幕上自动调整布局
- 保持操作按钮的可点击区域

---

## 5. 依赖项

| 依赖 | 用途 | 版本 |
|------|------|------|
| `flutter` | 核心框架 | 3.24+ |
| `provider` | 状态管理 | ^6.0.0 |
| `file_picker` | 文件选择 | ^5.0.0 |
| `pm3gui` | 内部库 | - |

---

## 6. 测试计划

### 6.1 功能测试
- [ ] 所有按钮能正确发送命令
- [ ] 输入验证功能正常
- [ ] 结果显示正确
- [ ] 文件选择功能正常
- [ ] 危险操作确认对话框正常

### 6.2 集成测试
- [ ] 页面能正常加载
- [ ] Tab切换正常
- [ ] 与其他页面无冲突
- [ ] 主题样式正确应用

### 6.3 边界测试
- [ ] 块号边界值 (0, 255)
- [ ] 数据长度边界值
- [ ] 密码长度边界值
- [ ] UID长度边界值
- [ ] 未连接设备时的提示

---

## 7. 代码优化

### 7.1 性能优化
- 使用 `const` 构造器减少重建
- 优化状态更新，避免不必要的重绘
- 使用 `SingleTickerProviderStateMixin` 提高动画性能

### 7.2 代码质量
- 添加详细的注释
- 提取重复代码为单独方法
- 遵循 Dart 代码风格规范
- 确保错误处理完善

---

## 8. 兼容性

### 8.1 设备兼容性
- 支持所有运行 Flutter 的设备
- 适配手机、平板和桌面平台

### 8.2 Proxmark3 兼容性
- 支持 Iceman 固件
- 支持所有 Mifare Ultralight 和 NTAG 卡片
- 命令兼容性自动继承自 PM3 客户端

---

## 9. 总结

Mifare Ultralight/NTAG 页面提供了完整的卡片操作功能，包括信息读取、数据读写、NDEF 操作、卡片模拟等。页面采用 Tab 布局，结构清晰，操作直观。通过集成 `HfMfuCmd` 命令类，实现了与 PM3 客户端的完全兼容，同时提供了友好的用户界面。

该页面的实现遵循了 Flutter 的最佳实践，使用了现代的 Material 3 设计，提供了良好的用户体验。