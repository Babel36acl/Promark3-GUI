# iCLASS/Picopass 页面文档

> 原始设计参考（PR #27 之前）。下文中文图示、示例和功能目标不等于当前实现或实卡
> 验证情况；新增/修改界面须使用 [中英文 ARB 与校验契约](localization.md)。
> 当前使用与支持范围见 [README](../README.md)。

## 1. 页面概述

### 1.1 功能目标
实现 iCLASS 和 Picopass 卡片的完整操作界面，包括信息读取、数据读写、密钥破解、卡片模拟等功能。

### 1.2 技术实现
- **文件**: `lib/ui/pages/hf_iclass_page.dart`
- **类名**: `HfIclassPage`
- **继承**: `StatefulWidget`
- **核心命令类**: `HfIclassCmd`

---

## 2. 页面结构

### 2.1 整体布局
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
│  │ [加载文件] [保存文件] [查看] [模拟]                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 组件结构

```dart
class HfIclassPage extends StatefulWidget {
  const HfIclassPage({super.key});
  @override
  State<HfIclassPage> createState() => _HfIclassPageState();
}

class _HfIclassPageState extends State<HfIclassPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  int _blockNumber = 0;
  String _key = '';
  String _blockData = '';
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
            Tab(text: '破解'),
            Tab(text: '模拟器'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
              _buildCrackTab(),
              _buildEmulatorTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 各个Tab的构建方法
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildCrackTab() { ... }
  Widget _buildEmulatorTab() { ... }
}
```

---

## 3. 功能实现

### 3.1 核心命令映射

| 按钮 | 命令 | 说明 |
|------|------|------|
| 获取信息 | `hf iclass info` | 读取卡片基本信息 |
| 读取卡片 | `hf iclass reader` | 读取卡片数据 |
| 转储卡片 | `hf iclass dump -f dump.iclass` | 转储整个卡片数据 |
| 读取块 | `hf iclass rdbl -b <block> [-k <key>]` | 读取指定块数据 |
| 写入块 | `hf iclass wrbl -b <block> -d <data> [-k <key>]` | 写入数据到指定块 |
| 检查密钥 | `hf iclass chk` | 检查默认密钥 |
| Loclass攻击 | `hf iclass loclass` | 执行离线破解 |
| 嗅探通信 | `hf iclass sniff` | 嗅探卡片通信 |
| 加载文件 | `hf iclass eload -f <file>` | 加载dump文件到模拟器 |
| 保存文件 | `hf iclass esave -f <file>` | 保存模拟器数据到文件 |
| 查看 | `hf iclass eview` | 查看模拟器当前状态 |
| 模拟 | `hf iclass sim` | 开始模拟卡片 |

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
              onPressed: () => _execute('hf iclass info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('获取信息'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass reader'),
              icon: const Icon(Icons.read_more),
              label: const Text('读取卡片'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass dump -f dump.iclass'),
              icon: const Icon(Icons.download),
              label: const Text('转储卡片'),
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
                items: List.generate(32, (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.toString()),
                )),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: TextEditingController(text: _key),
                onChanged: (value) => _key = value,
                decoration: const InputDecoration(
                  hintText: '16位十六进制密钥',
                  helperText: '例如: 0011223344556677',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(16),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final cmd = _key.isNotEmpty
                    ? 'hf iclass rdbl -b $_blockNumber -k $_key'
                    : 'hf iclass rdbl -b $_blockNumber';
                _execute(cmd);
              },
              child: const Text('读取'),
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
              onPressed: () {
                final cmd = _key.isNotEmpty
                    ? 'hf iclass wrbl -b $_blockNumber -d $_blockData -k $_key'
                    : 'hf iclass wrbl -b $_blockNumber -d $_blockData';
                _execute(cmd);
              },
              child: const Text('写入'),
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

### 3.4 破解标签

```dart
Widget _buildCrackTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass chk'),
              icon: const Icon(Icons.key),
              label: const Text('检查密钥'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass loclass'),
              icon: const Icon(Icons.lock_open),
              label: const Text('Loclass攻击'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass sniff'),
              icon: const Icon(Icons.radio),
              label: const Text('嗅探通信'),
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
                  allowedExtensions: ['iclass', 'bin', 'dump'],
                );
                if (result != null) {
                  _execute('hf iclass eload -f ${result.files.single.path}');
                }
              },
              icon: const Icon(Icons.file_open),
              label: const Text('加载文件'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass esave -f emulator.iclass'),
              icon: const Icon(Icons.save),
              label: const Text('保存文件'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass eview'),
              icon: const Icon(Icons.visibility),
              label: const Text('查看'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass sim'),
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

### 3.6 结果显示组件

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
- **文件选择**: 使用 `file_picker` 插件选择文件
- **密钥输入**: 支持可选的密钥输入

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
- [ ] 密钥输入可选功能正常

### 6.2 集成测试
- [ ] 页面能正常加载
- [ ] Tab切换正常
- [ ] 与其他页面无冲突
- [ ] 主题样式正确应用

### 6.3 边界测试
- [ ] 块号边界值 (0, 31)
- [ ] 数据长度边界值
- [ ] 密钥长度边界值
- [ ] 未连接设备时的提示
- [ ] 无密钥时的操作

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
- 支持所有 iCLASS 和 Picopass 卡片
- 命令兼容性自动继承自 PM3 客户端

---

## 9. 总结

iCLASS/Picopass 页面提供了完整的卡片操作功能，包括信息读取、数据读写、密钥破解、卡片模拟等。页面采用 Tab 布局，结构清晰，操作直观。通过集成 `HfIclassCmd` 命令类，实现了与 PM3 客户端的完全兼容，同时提供了友好的用户界面。

该页面的实现遵循了 Flutter 的最佳实践，使用了现代的 Material 3 设计，提供了良好的用户体验。