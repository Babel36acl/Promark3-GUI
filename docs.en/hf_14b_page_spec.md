# HF 14443-B Page Documentation

> Original design reference (before PR #27). The diagrams, examples, and feature goals
> below, translated from Chinese, do not establish the current implementation or real-card
> validation status; new or modified interfaces must use the [Chinese/English ARB and validation contract](localization.md).
> For current usage and support scope, see the [README](../README.en.md).

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating ISO14443-B cards, including reading information, reading and writing data, and card simulation.

### 1.2 Technical Implementation
- **File**: `lib\ui\pages\hf_14b_page.dart`
- **Class name**: `Hf14bPage`
- **Extends**: `StatefulWidget`
- **Core command class**: `Hf14bCmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Info] [Read/Write] [Simulation]                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Info:                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Reader]  [Tag Info]  [APDU]                          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 2 - Read/Write:                                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ APDU Command: [________________] [Send]              │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Tab 3 - Simulation:                                        │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ [Simulate Card]                                      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class Hf14bPage extends StatefulWidget {
  const Hf14bPage({super.key});
  @override
  State<Hf14bPage> createState() => _Hf14bPageState();
}

class _Hf14bPageState extends State<Hf14bPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
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
            Tab(text: 'Simulation'),
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

  // Builder methods for each tab
  Widget _buildInfoTab() { ... }
  Widget _buildReadWriteTab() { ... }
  Widget _buildSimTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Reader | `hf 14b reader` | Read a 14443-B card |
| Tag Info | `hf 14b info` | Read tag information |
| APDU | `hf 14b apdu` | Send an APDU command |
| Send | `hf 14b apdu -s <apdu>` | Send the specified APDU |
| Simulate Card | `hf 14b sim` | Simulate a 14443-B card |

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
              onPressed: () => _execute('hf 14b reader'),
              icon: const Icon(Icons.read_more),
              label: const Text('Reader'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf 14b info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Tag Info'),
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

### 3.3 Read/Write Tab

```dart
Widget _buildReadWriteTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('APDU Command: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _apdu),
                onChanged: (value) => _apdu = value,
                decoration: const InputDecoration(
                  hintText: 'Hexadecimal APDU command',
                  helperText: 'Example: 00A4040000',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf 14b apdu -s $_apdu'),
              child: const Text('Send'),
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

### 3.4 Simulation Tab

```dart
Widget _buildSimTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _execute('hf 14b sim'),
          icon: const Icon(Icons.phone_android),
          label: const Text('Simulate Card'),
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
- **Input validation**: Validate hex format in real time
- **Loading state**: Display a `CircularProgressIndicator` while executing a command
- **Result display**: Use a monospace font for command output

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

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] No conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] APDU length boundary values
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
- Support all ISO14443-B cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The HF 14443-B page provides a complete set of card operations, including reading information, APDU communication, and card simulation. The page uses a tabbed layout with a clear structure and intuitive controls. Integrating the `Hf14bCmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses modern Material 3 design to provide a good user experience.
