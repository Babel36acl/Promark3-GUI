# Mifare Ultralight/NTAG Page Documentation

> Historical design reference (pre-PR #27). The diagrams, examples, and feature goals
> below do not establish the current implementation or physical-card verification
> status; new or modified interfaces must follow the [Chinese/English ARB and validation contract](localization.md).
> See the [README](../README.en.md) for current usage and supported scope.

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating Mifare Ultralight and NTAG series cards, including reading information, reading and writing data, NDEF operations, and card simulation.

### 1.2 Technical Implementation
- **File**: [`lib/ui/pages/hf_mfu_page.dart`](../lib/ui/pages/hf_mfu_page.dart)
- **Class name**: `HfMfuPage`
- **Extends**: `StatefulWidget`
- **Core command class**: `HfMfuCmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Info] [Read/Write] [NDEF] [Emulator] [Tools]         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Info:                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Get Info] [Dump Card] [Wipe Card]                    │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 2 - Read/Write:                                        │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Block Number: [0-255 ▼] [Read Block]                  │     │
│  │ Data: [________________] [Write Block]              │     │
│  │ Password: [________________] [Authenticate]          │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 3 - NDEF:                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Read NDEF]  Result display area...                  │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 4 - Emulator:                                          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Load File] [Save to File] [View] [Simulate]          │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 5 - Tools:                                             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Generate Key] [Generate Password] [Set UID]         │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class HfMfuPage extends StatefulWidget {
  const HfMfuPage({super.key});
  @override
  State<HfMfuPage> createState() => _HfMfuPageState();
}

class _HfMfuPageState extends State<HfMfuPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
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
            Tab(text: 'NDEF'),
            Tab(text: 'Emulator'),
            Tab(text: 'Tools'),
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

  // Builder methods for each tab
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildNdefTab() { ... }
  Widget _buildEmulatorTab() { ... }
  Widget _buildToolsTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Get Info | `hf mfu info` | Read basic tag information |
| Dump Card | `hf mfu dump -f dump.mfu` | Dump all card data |
| Wipe Card | `hf mfu wipe` | Wipe the entire card |
| Read Block | `hf mfu rdbl -b <block>` | Read data from the specified block |
| Write Block | `hf mfu wrbl -b <block> -d <data>` | Write data to the specified block |
| Authenticate | `hf mfu cauth -p <pwd>` | Authenticate using a password |
| Read NDEF | `hf mfu ndefread` | Read NDEF data |
| Load into Emulator | `hf mfu eload -f <file>` | Load a dump file into the emulator |
| Save Emulator | `hf mfu esave -f <file>` | Save emulator data to a file |
| View Emulator | `hf mfu eview` | View the current emulator state |
| Simulate Card | `hf mfu sim` | Start card simulation |
| Generate Key | `hf mfu keygen` | Generate default keys |
| Generate Password | `hf mfu pwdgen` | Generate default passwords |
| Set UID | `hf mfu setuid -u <uid>` | Set the card UID |

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
              onPressed: () => _execute('hf mfu info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Get Info'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu dump -f dump.mfu'),
              icon: const Icon(Icons.download),
              label: const Text('Dump Card'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Wipe'),
                    content: const Text('Are you sure you want to wipe the entire card? This operation cannot be undone!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _execute('hf mfu wipe');
                        },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_forever),
              label: const Text('Wipe Card'),
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

### 3.3 Read/Write Tab

```dart
Widget _buildReadWriteTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('Block Number: ', style: TextStyle(fontSize: 14)),
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
              child: const Text('Read Block'),
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
              onPressed: () => _execute('hf mfu wrbl -b $_blockNumber -d $_blockData'),
              child: const Text('Write Block'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Password: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _password),
                onChanged: (value) => _password = value,
                decoration: const InputDecoration(
                  hintText: '8-digit hexadecimal password',
                  helperText: 'Example: 00112233',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(8),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfu cauth -p $_password'),
              child: const Text('Authenticate'),
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

### 3.4 NDEF Tab

```dart
Widget _buildNdefTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _execute('hf mfu ndefread'),
          icon: const Icon(Icons.nfc),
          label: const Text('Read NDEF'),
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
                  allowedExtensions: ['mfu', 'bin', 'dump'],
                );
                if (result != null) {
                  _execute('hf mfu eload -f ${result.files.single.path}');
                }
              },
              icon: const Icon(Icons.file_open),
              label: const Text('Load File'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu esave -f emulator.mfu'),
              icon: const Icon(Icons.save),
              label: const Text('Save to File'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu eview'),
              icon: const Icon(Icons.visibility),
              label: const Text('View'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu sim'),
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

### 3.6 Tools Tab

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
              label: const Text('Generate Key'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfu pwdgen'),
              icon: const Icon(Icons.lock),
              label: const Text('Generate Password'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Set UID'),
                    content: TextField(
                      controller: TextEditingController(text: _uid),
                      onChanged: (value) => _uid = value,
                      decoration: const InputDecoration(
                        hintText: '14-digit hexadecimal UID',
                        helperText: 'Example: 0123456789ABC',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                        LengthLimitingTextInputFormatter(14),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _execute('hf mfu setuid -u $_uid');
                        },
                        child: const Text('Confirm'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Set UID'),
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

### 3.7 Result Display Component

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
                  _result.isEmpty ? 'Run a command to view results' : _result,
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
- **Input validation**: Validate hexadecimal format and length in real time
- **Loading state**: Display a `CircularProgressIndicator` while a command is running
- **Result display**: Display command output in a monospaced font
- **Dangerous operations**: Require a confirmation dialog for dangerous operations such as wiping
- **File selection**: Use the `file_picker` plugin to select files

### 4.3 Responsive Design
- Adapt to different screen sizes
- Automatically adjust the layout on small screens
- Preserve the tappable areas of action buttons

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
- [ ] Results display correctly
- [ ] File selection works correctly
- [ ] Confirmation dialogs for dangerous operations work correctly

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] There are no conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] Block number boundary values (0, 255)
- [ ] Data length boundary values
- [ ] Password length boundary values
- [ ] UID length boundary values
- [ ] Prompt when no device is connected

---

## 7. Code Optimization

### 7.1 Performance Optimization
- Use `const` constructors to reduce rebuilds
- Optimize state updates to avoid unnecessary repaints
- Use `SingleTickerProviderStateMixin` to improve animation performance

### 7.2 Code Quality
- Add detailed comments
- Extract duplicated code into separate methods
- Follow Dart code style guidelines
- Ensure comprehensive error handling

---

## 8. Compatibility

### 8.1 Device Compatibility
- Support all devices that run Flutter
- Adapt to phones, tablets, and desktop platforms

### 8.2 Proxmark3 Compatibility
- Support Iceman firmware
- Support all Mifare Ultralight and NTAG cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The Mifare Ultralight/NTAG page provides a complete set of card operations, including reading information, reading and writing data, NDEF operations, and card simulation. The page uses a tabbed layout with a clear structure and intuitive controls. Integration with the `HfMfuCmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses a modern Material 3 design to provide a good user experience.
