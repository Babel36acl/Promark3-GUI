# Mifare DESFire Page Documentation

> Historical design reference (pre-PR #27). The diagrams, examples, and feature goals
> below do not establish the current implementation or physical-card verification
> status; new or modified interfaces must follow the [Chinese/English ARB and validation contract](localization.md).
> See the [README](../README.en.md) for current usage and supported scope.
>
> The current applications tab uses `desfireApplicationsTab`, rendered in English as **Applications**;
> the editor's **Apply** action retains `messageApply`. These must not be merged
> just because their Chinese labels are the same.

## 1. Page Overview

### 1.1 Feature Goals
Implement a complete interface for operating Mifare DESFire cards, including reading information, managing applications, working with files, and authentication.

### 1.2 Technical Implementation
- **File**: [`lib/ui/pages/hf_mfdes_page.dart`](../lib/ui/pages/hf_mfdes_page.dart)
- **Class name**: `HfMfdesPage`
- **Extends**: `StatefulWidget`
- **Core command class**: `HfMfdesCmd`

---

## 2. Page Structure

### 2.1 Overall Layout
```
┌─────────────────────────────────────────────────────────────┐
│  TabBar: [Info] [Applications] [Files] [Management]            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Tab 1 - Info:                                              │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [Detect] [Info] [Get UID] [Free Memory] [Check Keys]  │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 2 - Applications:                                      │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [List AIDs] [List Applications]                     │     │
│  │ AID: [________] [Select Application]                 │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 3 - Files:                                             │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ [List Files] [Dump Application]                      │     │
│  │ FID: [____] [Read] [Write]                           │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
│  Tab 4 - Management:                                        │
│  ┌─────────────────────────────────────────────────────┐     │
│  │ Key Number: [0-15 ▼]  Algorithm: [AES/DES ▼]          │     │
│  │ Key: [________________] [Authenticate]               │     │
│  │ [Format PICC]                                       │     │
│  └─────────────────────────────────────────────────────┘     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Component Structure

```dart
class HfMfdesPage extends StatefulWidget {
  const HfMfdesPage({super.key});
  @override
  State<HfMfdesPage> createState() => _HfMfdesPageState();
}

class _HfMfdesPageState extends State<HfMfdesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State variables
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
            Tab(text: 'Applications'),
            Tab(text: 'Files'),
            Tab(text: 'Management'),
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

  // Builder methods for each tab
  Widget _buildInfoTab() { ... }
  Widget _buildAppTab() { ... }
  Widget _buildFileTab() { ... }
  Widget _buildManageTab() { ... }
}
```

---

## 3. Feature Implementation

### 3.1 Core Command Mapping

| Button | Command | Description |
|------|------|------|
| Detect | `hf mfdes detect` | Detect a DESFire card |
| Info | `hf mfdes info` | Read basic card information |
| Get UID | `hf mfdes getuid` | Get the card UID |
| Free Memory | `hf mfdes freemem` | View free memory |
| Check Keys | `hf mfdes chk` | Check default keys |
| List AIDs | `hf mfdes getaids` | List all application AIDs |
| List Applications | `hf mfdes lsapp` | List current applications |
| Select Application | `hf mfdes selectapp -a <aid>` | Select the specified application |
| List Files | `hf mfdes getfileids` | List files in the current application |
| Dump Application | `hf mfdes dump` | Dump data from the current application |
| Read File | `hf mfdes read -f <fid>` | Read the specified file |
| Write File | `hf mfdes write -f <fid> -d <data>` | Write data to the specified file |
| Authenticate | `hf mfdes auth -k <key> -a <algo>` | Authenticate using the specified algorithm |
| Format PICC | `hf mfdes formatpicc` | Format the entire card |

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
              onPressed: () => _execute('hf mfdes detect'),
              icon: const Icon(Icons.search),
              label: const Text('Detect'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes info'),
              icon: const Icon(Icons.info_outline),
              label: const Text('Info'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes getuid'),
              icon: const Icon(Icons.credit_card),
              label: const Text('Get UID'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes freemem'),
              icon: const Icon(Icons.storage),
              label: const Text('Free Memory'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes chk'),
              icon: const Icon(Icons.key),
              label: const Text('Check Keys'),
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

### 3.3 Applications Tab

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
              label: const Text('List AIDs'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes lsapp'),
              icon: const Icon(Icons.apps),
              label: const Text('List Applications'),
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
                  hintText: '6-digit hexadecimal AID',
                  helperText: 'Example: 000000',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfdes selectapp -a $_aid'),
              child: const Text('Select Application'),
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

### 3.4 Files Tab

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
              label: const Text('List Files'),
            ),
            ElevatedButton.icon(
              onPressed: () => _execute('hf mfdes dump'),
              icon: const Icon(Icons.download),
              label: const Text('Dump Application'),
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
              child: const Text('Read'),
            ),
            ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    String data = '';
                    return AlertDialog(
                      title: const Text('Write File'),
                      content: TextField(
                        onChanged: (value) => data = value,
                        decoration: const InputDecoration(
                          hintText: 'Hexadecimal data',
                          helperText: 'Example: 00112233',
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
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
                            _execute('hf mfdes write -f $_fid -d $data');
                          },
                          child: const Text('Confirm'),
                        ),
                      ],
                    );
                  },
                );
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

### 3.5 Management Tab

```dart
Widget _buildManageTab() {
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            const Text('Key Number: ', style: TextStyle(fontSize: 14)),
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
            const Text('Algorithm: ', style: TextStyle(fontSize: 14)),
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
            const Text('Key: ', style: TextStyle(fontSize: 14)),
            Expanded(
              child: TextFormField(
                controller: TextEditingController(text: _key),
                onChanged: (value) => _key = value,
                decoration: const InputDecoration(
                  hintText: '32-digit hexadecimal key (AES)',
                  helperText: 'Example: 00112233445566778899AABBCCDDEEFF',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _execute('hf mfdes auth -k $_key -a $_algorithm'),
              child: const Text('Authenticate'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Format'),
                content: const Text('Are you sure you want to format the entire card? This operation cannot be undone!'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _execute('hf mfdes formatpicc');
                    },
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.format_shapes),
          label: const Text('Format PICC'),
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
- **Dangerous operations**: Require a confirmation dialog for dangerous operations such as formatting
- **Algorithm selection**: Support switching between AES and DES algorithms

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
- [ ] Confirmation dialogs for dangerous operations work correctly
- [ ] Algorithm selection works correctly

### 6.2 Integration Tests
- [ ] The page loads correctly
- [ ] Tab switching works correctly
- [ ] There are no conflicts with other pages
- [ ] Theme styles are applied correctly

### 6.3 Boundary Tests
- [ ] AID length boundary values
- [ ] Key length boundary values
- [ ] FID boundary values (0-15)
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
- Support all Mifare DESFire cards
- Command compatibility is automatically inherited from the PM3 client

---

## 9. Summary

The Mifare DESFire page provides a complete set of card operations, including reading information, managing applications, working with files, and authentication. The page uses a tabbed layout with a clear structure and intuitive controls. Integration with the `HfMfdesCmd` command class provides full compatibility with the PM3 client while offering a user-friendly interface.

The page implementation follows Flutter best practices and uses a modern Material 3 design to provide a good user experience.
