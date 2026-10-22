# iCLASS/Picopass Page Documentation

> Original design reference (before PR #27). The diagrams, examples, and feature goals
> below, translated from Chinese, do not establish the current implementation or real-card
> validation status; new or modified interfaces must use the [Chinese/English ARB and validation contract](localization.md).
> For current usage and support scope, see the [README](../README.en.md).

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating iCLASS and Picopass cards, including reading information, reading and writing data, key cracking, and card simulation.

### 1.2 Technical Implementation
- **File**: `lib\ui\pages\hf_iclass_page.dart`
- **Class name**: `HfIclassPage`
- **Extends**: `StatefulWidget`
- **Core command class**: `HfIclassCmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Info] [Read/Write] [Cracking] [Emulator]             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Info:                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Get Info]  [Read Card]  [Dump Card]                  │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 2 - Read/Write:                                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Block: [0-31 ▼]  Key: [________________] [Read]       │    │
│  │ Data: [________________] [Write]                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 3 - Cracking:                                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Check Keys]  [Loclass Attack]  [Sniff Traffic]        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 4 - Emulator:                                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Load File] [Save File] [View] [Simulate]              │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class HfIclassPage extends StatefulWidget {
  const HfIclassPage({super.key});
  @override
  State<HfIclassPage> createState() => _HfIclassPageState();
}

class _HfIclassPageState extends State<HfIclassPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
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

  // Command execution method
  void _execute(String cmd) {
    final appState = context.read<AppState>();
    if (!appState.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PM3 not connected')),
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
            Tab(text: 'Info'),
            Tab(text: 'Read/Write'),
            Tab(text: 'Cracking'),
            Tab(text: 'Emulator'),
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

  // Builder methods for each tab
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildCrackTab() { ... }
  Widget _buildEmulatorTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Get Info | `hf iclass info` | Read basic card information |
| Read Card | `hf iclass reader` | Read card data |
| Dump Card | `hf iclass dump -f dump.iclass` | Dump all card data |
| Read Block | `hf iclass rdbl -b <block> [-k <key>]` | Read data from the specified block |
| Write Block | `hf iclass wrbl -b <block> -d <data> [-k <key>]` | Write data to the specified block |
| Check Keys | `hf iclass chk` | Check default keys |
| Loclass Attack | `hf iclass loclass` | Perform offline cracking |
| Sniff Traffic | `hf iclass sniff` | Sniff card communication |
| Load File | `hf iclass eload -f <file>` | Load a dump file into the emulator |
| Save File | `hf iclass esave -f <file>` | Save emulator data to a file |
| View | `hf iclass eview` | View the current emulator state |
| Simulate | `hf iclass sim` | Start card simulation |

### 3.2 Info Tab

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
              label: const Text('Get Info'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass reader'),
              icon: const Icon(Icons.read_more),
              label: const Text('Read Card'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass dump -f dump.iclass'),
              icon: const Icon(Icons.download),
              label: const Text('Dump Card'),
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

### 3.3 Read/Write Tab

```dart
Widget _buildReadWriteTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('Block: ', style: TextStyle(fontSize: 14)),
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
                  hintText: '16-digit hexadecimal key',
                  helperText: 'Example: 0011223344556677',
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
              child: const Text('Read'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Data: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _blockData),
                onChanged: (value) => _blockData = value,
                decoration: const InputDecoration(
                  hintText: '16-digit hexadecimal data',
                  helperText: 'Example: 0011223344556677',
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
              child: const Text('Write'),
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

### 3.4 Cracking Tab

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
              label: const Text('Check Keys'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass loclass'),
              icon: const Icon(Icons.lock_open),
              label: const Text('Loclass Attack'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass sniff'),
              icon: const Icon(Icons.radio),
              label: const Text('Sniff Traffic'),
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

### 3.5 Emulator Tab

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
              label: const Text('Load File'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass esave -f emulator.iclass'),
              icon: const Icon(Icons.save),
              label: const Text('Save File'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass eview'),
              icon: const Icon(Icons.visibility),
              label: const Text('View'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf iclass sim'),
              icon: const Icon(Icons.phone_android),
              label: const Text('Simulate'),
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

### 3.6 Result Display Component

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
                  _result.isEmpty ? 'Run a command to view the results' : _result,
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

## 4. UI/UX Design

### 4.1 Color Usage
- **Primary color**: `AppTheme.accentBlue` (#38BDF8)
- **Background color**: `AppTheme.darkBg` (#0F172A)
- **Card color**: `AppTheme.darkSurface` (#1E293B)
- **Text color**: `AppTheme.auxiliaryGrey` (#94A3B8)
- **Error color**: `#F87171`

### 4.2 Interaction Design
- **Button styles**: Use `ElevatedButton` and `OutlinedButton`
- **Input validation**: Validate hex format and length in real time
- **Loading state**: Display a `CircularProgressIndicator` while executing a command
- **Result display**: Use a monospace font for command output
- **File selection**: Use the `file_picker` plugin to select files
- **Key input**: Support optional key input

### 4.3 Responsive Design
- Adapt to different screen sizes
- Automatically adjust the layout on small screens
- Maintain clickable target areas for action buttons

---

## 5. Dependencies

| Dependency | Purpose | Version |
|------|------|------|
| `flutter` | Core framework | 3.24+ |
| `provider` | State management | ^6.0.0 |
| `file_picker` | File selection | ^5.0.0 |
| `pm3gui` | Internal library | - |

---

## 6. Test Plan

### 6.1 Functional Tests
- [ ] All buttons send the correct commands
- [ ] Input validation works correctly
- [ ] Results are displayed correctly
- [ ] File selection works correctly
- [ ] Optional key input works correctly

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] No conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] Block number boundary values (0, 31)
- [ ] Data length boundary values
- [ ] Key length boundary values
- [ ] Prompt when no device is connected
- [ ] Operations without a key

---

## 7. Code Optimization

### 7.1 Performance Optimization
- Use `const` constructors to reduce rebuilds
- Optimize state updates to avoid unnecessary repaints
- Use `SingleTickerProviderStateMixin` to improve animation performance

### 7.2 Code Quality
- Add detailed comments
- Extract repeated code into separate methods
- Follow Dart code style guidelines
- Ensure comprehensive error handling

---

## 8. Compatibility

### 8.1 Device Compatibility
- Support all devices that run Flutter
- Adapt to phones, tablets, and desktop platforms

### 8.2 Proxmark3 Compatibility
- Support Iceman firmware
- Support all iCLASS and Picopass cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The iCLASS/Picopass page provides a complete set of card operations, including reading information, reading and writing data, key cracking, and card simulation. The page uses a tabbed layout with a clear structure and intuitive controls. Integrating the `HfIclassCmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses modern Material 3 design to provide a good user experience.
