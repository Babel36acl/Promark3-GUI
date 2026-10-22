# Mifare DESFire 页面文档

> 原始设计参考（PR #27 之前）。下文中文图示、示例和功能目标不等于当前实现或实卡
> 验证情况；新增/修改界面须使用 [中英文 ARB 与校验契约](localization.md)。
> 当前使用与支持范围见 [README](../README.md)。
>
> 当前“应用”选项卡使用 `desfireApplicationsTab`，英文为 **Applications**；
> 编辑器的 **Apply** 动作保留 `messageApply`。两者不能因中文相同而合并。

## 1. 页面概述

### 1.1 功能目标
实现 Mifare DESFire 卡片的完整操作界面，包括信息读取、应用管理、文件操作、认证等功能。

### 1.2 技术实现
- **文件**: `lib/ui/pages/hf_mfdes_page.dart`
- **类名**: `HfMfdesPage`
- **继承**: `StatefulWidget`
- **核心命令类**: `HfMfdesCmd`

---

## 2. 页面结构

### 2.1 整体布局
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [信息] [应用] [文件] [管理]                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - 信息:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [检测]  [信息]  [获取UID]  [空闲内存]  [检查密钥]          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 2 - 应用:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [列出AID]  [列出应用]                                   │   │
│  │ AID: [________] [选择应用]                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 3 - 文件:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ [列出文件]  [转储应用]                                  │   │
│  │ FID: [____] [读取] [写入]                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  Tab 4 - 管理:                                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 密钥号: [0-15 ▼]  算法: [AES/DES ▼]                 │   │
│  │ 密钥: [________________] [认证]                      │   │
│  │ [格式化PICC]                                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 组件结构

```dart
class HfMfdesPage extends StatefulWidget {
  const HfMfdesPage({super.key});
  @override
  State<HfMfdesPage> createState() => _HfMfdesPageState();
}

class _HfMfdesPageState extends State<HfMfdesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 状态变量
  String _aid = '';
  int _fid = 0;
  String _key = '';
  int _keyNumber = 0;
  String _algorithm = 'AES';
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
            Tab(text: '应用'),
            Tab(text: '文件'),
            Tab(text: '管理'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildAppTab(),
              _buildFileTab(),
              _buildManageTab(),
            ],
          ),
        ),
      ],
    );
  }
  
  // 各个Tab的构建方法
  Widget _buildInfoTab() { ... }
  Widget _buildAppTab() { ... }
  Widget _buildFileTab() { ... }
  Widget _buildManageTab() { ... }
}
```

---

## 3. 功能实现

### 3.1 核心命令映射

| 按钮 | 命令 | 说明 |
|------|------|------|
| 检测 | `hf mfdes detect` | 检测 DESFire 卡片 |
| 信息 | `hf mfdes info` | 读取卡片基本信息 |
| 获取UID | `hf mfdes getuid` | 获取卡片UID |
| 空闲内存 | `hf mfdes freemem` | 查看空闲内存 |
| 检查密钥 | `hf mfdes chk` | 检查默认密钥 |
| 列出AID | `hf mfdes getaids` | 列出所有应用AID |
| 列出应用 | `hf mfdes lsapp` | 列出当前应用 |
| 选择应用 | `hf mfdes selectapp -a <aid>` | 选择指定应用 |
| 列出文件 | `hf mfdes getfileids` | 列出当前应用的文件 |
| 转储应用 | `hf mfdes dump` | 转储当前应用数据 |
| 读取文件 | `hf mfdes read -f <fid>` | 读取指定文件 |
| 写入文件 | `hf mfdes write -f <fid> -d <data>` | 写入数据到指定文件 |
| 认证 | `hf mfdes auth -k <key> -a <algo>` | 使用指定算法认证 |
| 格式化PICC | `hf mfdes formatpicc` | 格式化整个卡片 |

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
              onPressed: () => _execute('hf mfdes detect'),
              icon: const Icon(Icons.search),
              label: const Text('检测'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('信息'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes getuid'),
              icon: const Icon(Icons.credit_card),
              label: const Text('获取UID'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes freemem'),
              icon: const Icon(Icons.storage),
              label: const Text('空闲内存'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes chk'),
              icon: const Icon(Icons.key),
              label: const Text('检查密钥'),
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

### 3.3 应用标签

```dart
Widget _buildAppTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes getaids'),
              icon: const Icon(Icons.list),
              label: const Text('列出AID'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes lsapp'),
              icon: const Icon(Icons.apps),
              label: const Text('列出应用'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('AID: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _aid),
                onChanged: (value) => _aid = value,
                decoration: const InputDecoration(
                  hintText: '6位十六进制AID',
                  helperText: '例如: 000000',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfdes selectapp -a $_aid'),
              child: const Text('选择应用'),
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

### 3.4 文件标签

```dart
Widget _buildFileTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes getfileids'),
              icon: const Icon(Icons.file_copy),
              label: const Text('列出文件'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes dump'),
              icon: const Icon(Icons.download),
              label: const Text('转储应用'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('FID: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: DropdownButton<int>(
                value: _fid,
                onChanged: (value) => setState(() => _fid = value!),
                items: List.generate(16, (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.toString()),
                )),
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfdes read -f $_fid'),
              child: const Text('读取'),
            ),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    String data = '';
                    return AlertDialog(
                      title: const Text('写入文件'),
                      content: TextField(
                        onChanged: (value) => data = value,
                        decoration: const InputDecoration(
                          hintText: '十六进制数据',
                          helperText: '例如: 00112233',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
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
                            _execute('hf mfdes write -f $_fid -d $data');
                          },
                          child: const Text('确认'),
                        ),
                      ],
                    );
                  },
                );
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

### 3.5 管理标签

```dart
Widget _buildManageTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('密钥号: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: DropdownButton<int>(
                value: _keyNumber,
                onChanged: (value) => setState(() => _keyNumber = value!),
                items: List.generate(16, (i) => DropdownMenuItem(
                  value: i,
                  child: Text(i.toString()),
                )),
              ),
            ),
            const SizedBox(width: 12),
            const Text('算法: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: DropdownButton<String>(
                value: _algorithm,
                onChanged: (value) => setState(() => _algorithm = value!),
                items: const [
                  DropdownMenuItem(value: 'AES', child: Text('AES')),
                  DropdownMenuItem(value: 'DES', child: Text('DES')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('密钥: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _key),
                onChanged: (value) => _key = value,
                decoration: const InputDecoration(
                  hintText: '32位十六进制密钥 (AES)',
                  helperText: '例如: 00112233445566778899AABBCCDDEEFF',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfdes auth -k $_key -a $_algorithm'),
              child: const Text('认证'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('确认格式化'),
                content: const Text('确定要格式化整个卡片吗？此操作不可恢复！'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _execute('hf mfdes formatpicc');
                    },
                    child: const Text('确认'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.format_shapes),
          label: const Text('格式化PICC'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF87171),
          ),
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
- **危险操作**: 格式化等危险操作需要确认对话框
- **算法选择**: 支持 AES 和 DES 算法切换

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
- [ ] 危险操作确认对话框正常
- [ ] 算法选择功能正常

### 6.2 集成测试
- [ ] 页面能正常加载
- [ ] Tab切换正常
- [ ] 与其他页面无冲突
- [ ] 主题样式正确应用

### 6.3 边界测试
- [ ] AID长度边界值
- [ ] 密钥长度边界值
- [ ] FID边界值 (0-15)
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
- 支持所有 Mifare DESFire 卡片
- 命令兼容性自动继承自 PM3 客户端

---

## 9. 总结

Mifare DESFire 页面提供了完整的卡片操作功能，包括信息读取、应用管理、文件操作、认证等。页面采用 Tab 布局，结构清晰，操作直观。通过集成 `HfMfdesCmd` 命令类，实现了与 PM3 客户端的完全兼容，同时提供了友好的用户界面。

该页面的实现遵循了 Flutter 的最佳实践，使用了现代的 Material 3 设计，提供了良好的用户体验。