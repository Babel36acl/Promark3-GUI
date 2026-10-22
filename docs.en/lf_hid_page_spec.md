# HID Prox Page Documentation

> Historical design reference (pre-PR #27). The diagrams, examples, and feature goals
> below do not establish the current implementation or physical-card verification
> status; new or modified interfaces must follow the [Chinese/English ARB and validation contract](localization.md).
> See the [README](../README.en.md) for current usage and supported scope.
>
> `lf hid brute` enumerates facility codes/card numbers against a reader; it does not perform cryptographic key recovery.
> The current interface already uses the dedicated `hidReaderBruteForceTab`, `hidReaderBruteForceTitle`, and `hidStartBruteForce`
> resources, covered by [Chinese/English regression tests](../test/ui/lf_hid_page_test.dart);
> see the [localization guide](localization.md) for behavior and validation scope.

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating HID Prox low-frequency cards, including reading information, cloning cards, simulating cards, and brute forcing.

### 1.2 Technical Implementation
- **File**: [`lib/ui/pages/lf_hid_page.dart`](../lib/ui/pages/lf_hid_page.dart)
- **Class name**: `LfHidPage`
- **Extends**: `StatefulWidget`
- **Core command class**: `LfHidCmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Read] [Clone/Simulate] [Cracking]                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Read:                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Read HID Card] [Demodulate Signal]                  │     │
│  │ Result display area...                              │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 2 - Clone/Simulate:                                    │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Card Number Data: [________________]                │     │
│  │ [Clone to T55xx] [Simulate Card]                     │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 3 - Cracking:                                          │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ FC: [____] (optional)                               │     │
│  │ [Brute Force]                                       │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class LfHidPage extends StatefulWidget {
  const LfHidPage({super.key});
  @override
  State<LfHidPage> createState() => _LfHidPageState();
}

class _LfHidPageState extends State<LfHidPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
  String _cardData = '';
  String _fc = '';
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
            Tab(text: 'Read'),
            Tab(text: 'Clone/Simulate'),
            Tab(text: 'Cracking'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildReadTab(),
              _buildCloneSimTab(),
              _buildCrackTab(),
            ],
          ),
        ),
      ],
    );
  }

  // Builder methods for each tab
  Widget _buildReadTab() { ... }
  Widget _buildCloneSimTab() { ... }
  Widget _buildCrackTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Read HID Card | `lf hid reader` | Read an HID Prox card |
| Demodulate Signal | `lf hid demod` | Demodulate an HID signal |
| Clone to T55xx | `lf hid clone -w <data>` | Clone to a T55xx card |
| Simulate Card | `lf hid sim -w <data>` | Simulate an HID card |
| Brute Force | `lf hid brute [-f <fc>]` | Brute force HID cards |

### 3.2 Read Tab

```dart
Widget _buildReadTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('lf hid reader'),
              icon: const Icon(Icons.nfc),
              label: const Text('Read HID Card'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('lf hid demod'),
              icon: const Icon(Icons.radio),
              label: const Text('Demodulate Signal'),
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

### 3.3 Clone/Simulate Tab

```dart
Widget _buildCloneSimTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('Card Number Data: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _cardData),
                onChanged: (value) => _cardData = value,
                decoration: const InputDecoration(
                  hintText: 'Wiegand-format data',
                  helperText: 'Example: 26bit-format data',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () => _execute('lf hid clone -w $_cardData'),
              icon: const Icon(Icons.copy),
              label: const Text('Clone to T55xx'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('lf hid sim -w $_cardData'),
              icon: const Icon(Icons.phone_android),
              label: const Text('Simulate Card'),
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
        Row(
          children: [
            const Text('FC: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _fc),
                onChanged: (value) => _fc = value,
                decoration: const InputDecoration(
                  hintText: ' facility code (optional)',
                  helperText: 'Example: 123',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            final cmd = _fc.isNotEmpty
                ? 'lf hid brute -f $_fc'
                : 'lf hid brute';
            _execute(cmd);
          },
          icon: const Icon(Icons.lock_open),
          label: const Text('Brute Force'),
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
- **Input validation**: Validate numeric format in real time
- **Loading state**: Display a `CircularProgressIndicator` while a command is running
- **Result display**: Display command output in a monospaced font
- **FC input**: Support optional facility code input

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
| `pm3gui` | Internal library | - |

---

## 6. Test Plan

### 6.1 Functional Tests
- [ ] All buttons send the correct commands
- [ ] Input validation works correctly
- [ ] Results display correctly
- [ ] Optional FC input works correctly

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] There are no conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] Card number data length boundary values
- [ ] FC input boundary values
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
- Support all HID Prox cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The HID Prox page provides a complete set of card operations, including reading information, cloning cards, simulating cards, and brute forcing. The page uses a tabbed layout with a clear structure and intuitive controls. Integration with the `LfHidCmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses a modern Material 3 design to provide a good user experience.
