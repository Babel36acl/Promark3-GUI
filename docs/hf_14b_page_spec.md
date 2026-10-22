# HF 14443-B 页面文档

> 原始设计参考（PR #27 之前）。下文中文图示、示例和功能目标不等于当前实现或实卡
> 验证情况；新增/修改界面须使用 [中英文 ARB 与校验契约](localization.md)。
> 当前使用与支持范围见 [README](../README.md)。

## 1. 页面概述

### 1.1 功能目标
实现 ISO14443-B 协议卡片的完整操作界面，包括信息读取、数据读写、卡片模拟等功能。

### 1.2 技术实现
- **文件**: `lib/ui/pages/hf_14b_page.dart`
- **类名**: `Hf14bPage`
- **继承**: `StatefulWidget`
- **核心命令类**: `Hf14bCmd`

---

## 2. 页面结构

### 2.1 整体布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [信息] [读写] [模拟]                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 信息:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [读取器]  [标签信息]  [APDU]                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 读写:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ APDU命令: [________________] [发送]                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - 模拟:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [模拟卡片]                                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 组件结构

```dart
class Hf14bPage extends StatefulWidget {
  const Hf14bPage({super.key});
  @override
  State<Hf14bPage> createState() => _Hf14bPageState();
}

class _Hf14bPageState extends State<Hf14bPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  String _apdu = '';
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
            Tab(text: '模拟'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
              _buildSimTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 各个Tab的构建方法
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildSimTab() { ... }
}
```

---

## 3. 功能实现

### 3.1 核心命令映射

| 按钮 | 命令 | 说明 |
|------|------|------|
| 读取器 | `hf 14b reader` | 读取14443-B卡片 |
| 标签信息 | `hf 14b info` | 读取标签信息 |
| APDU | `hf 14b apdu` | 发送APDU命令 |
| 发送 | `hf 14b apdu -s <apdu>` | 发送指定APDU |
| 模拟卡片 | `hf 14b sim` | 模拟14443-B卡片 |

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
              onPressed: () => _execute('hf 14b reader'),
              icon: const Icon(Icons.read_more),
              label: const Text('读取器'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 14b info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('标签信息'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 14b apdu'),
              icon: const Icon(Icons.send),
              label: const Text('APDU'),
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
            const Text('APDU命令: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _apdu),
                onChanged: (value) => _apdu = value,
                decoration: const InputDecoration(
                  hintText: '十六进制APDU命令',
                  helperText: '例如: 00A4040000',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf 14b apdu -s $_apdu'),
              child: const Text('发送'),
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

### 3.4 模拟标签

```dart
Widget _buildSimTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _execute('hf 14b sim'),
          icon: const Icon(Icons.phone_android),
          label: const Text('模拟卡片'),
        ),
        const SizedBox(height: 16),
        _buildResultDisplay(),
      ],
    ),
  );
}
```

### 3.5 结果显示组件

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
- **输入验证**: 实时验证hex格式
- **加载状态**: 执行命令时显示 `CircularProgressIndicator`
- **结果显示**: 使用等宽字体显示命令输出

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
| `pm3gui` | 内部库 | - |

---

## 6. 测试计划

### 6.1 功能测试
- [ ] 所有按钮能正确发送命令
- [ ] 输入验证功能正常
- [ ] 结果显示正确

### 6.2 集成测试
- [ ] 页面能正常加载
- [ ] Tab切换正常
- [ ] 与其他页面无冲突
- [ ] 主题样式正确应用

### 6.3 边界测试
- [ ] APDU长度边界值
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
- 支持所有 ISO14443-B 协议卡片
- 命令兼容性自动继承自 PM3 客户端

---

## 9. 总结

HF 14443-B 页面提供了完整的卡片操作功能，包括信息读取、APDU通信、卡片模拟等。页面采用 Tab 布局，结构清晰，操作直观。通过集成 `Hf14bCmd` 命令类，实现了与 PM3 客户端的完全兼容，同时提供了友好的用户界面。

该页面的实现遵循了 Flutter 的最佳实践，使用了现代的 Material 3 设计，提供了良好的用户体验。
