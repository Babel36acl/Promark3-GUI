# ISO15693 Page Documentation

> Original design reference (before PR #27). The diagrams, examples, and feature goals
> below, translated from Chinese, do not establish the current implementation or real-card
> validation status; new or modified interfaces must use the [Chinese/English ARB and validation contract](localization.md).
> For current usage and support scope, see the [README](../README.en.md).

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating ISO15693 cards, including reading information, reading and writing data, AFI operations, and card simulation.

### 1.2 Technical Implementation
- **File**: `lib\ui\pages\hf_15_page.dart`
- **Class name**: `Hf15Page`
- **Extends**: `StatefulWidget`
- **Core command class**: `Hf15Cmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Info] [Read/Write] [Tools]                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Info:                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Reader]  [Tag Info]  [Dump Card]  [Wipe Card]         │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 2 - Read/Write:                                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Block: [0-255 ▼]  [Read Block]                        │    │
│  │ Data: [________________] [Write Block]               │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 3 - Tools:                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Find AFI]  [Set UID]  [Simulate Card]  [Sniff]        │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class Hf15Page extends StatefulWidget {
  const Hf15Page({super.key});
  @override
  State<Hf15Page> createState() => _Hf15PageState();
}

class _Hf15PageState extends State<Hf15Page>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
  int _blockNumber = 0;
  String _blockData = '';
  String _uid = '';
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
            Tab(text: 'Tools'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(),
              _buildReadWriteTab(),
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
  Widget _buildToolsTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Reader | `hf 15 reader` | Reader mode; automatically read cards |
| Tag Info | `hf 15 info` | Read basic tag information |
| Dump Card | `hf 15 dump -f dump.15` | Dump all card data |
| Wipe Card | `hf 15 wipe` | Wipe the entire card |
| Read Block | `hf 15 rdbl -b <block>` | Read data from the specified block |
| Write Block | `hf 15 wrbl -b <block> -d <data>` | Write data to the specified block |
| Find AFI | `hf 15 findafi` | Find the Application Family Identifier |
| Set UID | `hf 15 csetuid -u <uid>` | Set the card UID |
| Simulate Card | `hf 15 sim` | Start card simulation |
| Sniff | `hf 15 sniff` | Sniff card communication |

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
              onPressed: () => _execute('hf 15 reader'),
              icon: const Icon(Icons.read_more),
              label: const Text('Reader'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 15 info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Tag Info'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 15 dump -f dump.15'),
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
                          _execute('hf 15 wipe');
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
            const Text('Block: ', style: TextStyle(fontSize: 14)),
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
              onPressed: () => _execute('hf 15 rdbl -b $_blockNumber'),
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
              onPressed: () => _execute('hf 15 wrbl -b $_blockNumber -d $_blockData'),
              child: const Text('Write Block'),
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

### 3.4 Tools Tab

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
              onPressed: () => _execute('hf 15 findafi'),
              icon: const Icon(Icons.search),
              label: const Text('Find AFI'),
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
                          _execute('hf 15 csetuid -u $_uid');
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
            ElevatedButton.icon(
              onPressed: () => _execute('hf 15 sim'),
              icon: const Icon(Icons.phone_android),
              label: const Text('Simulate Card'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 15 sniff'),
              icon: const Icon(Icons.radio),
              label: const Text('Sniff'),
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

### 3.5 Result Display Component

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
- **Dangerous operations**: Dangerous operations such as wiping require a confirmation dialog

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
| `pm3gui` | Internal library | - |

---

## 6. Test Plan

### 6.1 Functional Tests
- [ ] All buttons send the correct commands
- [ ] Input validation works correctly
- [ ] Results are displayed correctly
- [ ] Dangerous-operation confirmation dialogs work correctly

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] No conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] Block number boundary values (0, 255)
- [ ] Data length boundary values
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
- Support all ISO15693 cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The ISO15693 page provides a complete set of card operations, including reading information, reading and writing data, AFI operations, and card simulation. The page uses a tabbed layout with a clear structure and intuitive controls. Integrating the `Hf15Cmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses modern Material 3 design to provide a good user experience.
