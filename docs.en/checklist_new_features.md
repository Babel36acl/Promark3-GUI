# PM3GUI New Feature Page Development Checklist

> The Phase checklists and their original checked states below are retained as design records from before PR #27. They do not represent current implementation progress,
> SDK requirements, or supported platforms. For current development entry points, see the [documentation index](README.md) and
> [Localization](localization.md); do not directly copy the hardcoded Chinese text in the old examples.

## Localization Acceptance for Newly Added Pages (PR #27)

- [ ] English and Chinese ARB resources are complete; sentences use named placeholders, and different meanings such as nouns/actions use different keys.
- [ ] Labels, tooltips, validation, confirmation/danger messages, empty states, and errors all use the current interface language.
- [ ] Temporary validation models inherit the current language; failed imports do not alter the original data.
- [ ] Raw PM3 commands, hexadecimal data, protocol identifiers, and persisted fields are not translated.
- [ ] Standalone Dart tools do not introduce Flutter runtime dependencies, and the actual `dart run` entry points have regression coverage.
- [ ] Failures to locate/save the language directory are visible on the settings page; initialization can still complete, and subsequent saves can be retried.
- [ ] English and Chinese pages and dialogs have been specifically checked in default/smaller desktop windows and with text scaling.
- [ ] After changes, run `flutter gen-l10n`, resource integrity checks, static analysis, and relevant tests.
- [ ] Synchronize Markdown/HTML documentation, and clearly distinguish code tests, Linux builds, and real-device validation.

## Pre-development Checks

### Environment Preparation

- [x] Flutter SDK 3.24+ is installed
- [x] Project dependencies are updated (`flutter pub get`)
- [x] Existing code has no compilation errors (`flutter analyze`)
- [x] The application starts and runs normally

### Code Review

- [x] Read [pm3_commands.dart](../lib/services/pm3_commands.dart) to understand available commands
- [x] Read [mifare_page.dart](../lib/ui/pages/mifare_page.dart) to understand code patterns
- [x] Read [home_page.dart](../lib/ui/home_page.dart) to understand the navigation structure

---

## Phase 1: Basic Preparation

### Task 1.1: Update the Navigation Structure

**File**: `lib/ui/home_page.dart`

#### Import Statements

- [ ] Add the `hf_mfu_page.dart` import
- [ ] Add the `hf_iclass_page.dart` import
- [ ] Add the `hf_15_page.dart` import
- [ ] Add the `hf_mfdes_page.dart` import
- [ ] Add the `lf_hid_page.dart` import

#### _pages List Update

- [ ] Add `HfMfuPage()` after `MifarePage()`
- [ ] Add `HfIclassPage()`
- [ ] Add `Hf15Page()`
- [ ] Add `LfHidPage()` after `LfPage()`

#### _navItems List Update

- [ ] Add the NTAG navigation item (Icons.memory)
- [ ] Add the iCLASS navigation item (Icons.badge)
- [ ] Add the ISO15693 navigation item (Icons.contactless)
- [ ] Add the HID navigation item (Icons.door_front_door_outlined)

#### Verification

- [ ] `flutter analyze` reports no errors
- [ ] The application compiles normally
- [ ] The sidebar displays all new navigation items

---

## Phase 2: Mifare Ultralight/NTAG Page

### File: `lib/ui/pages/hf_mfu_page.dart`

#### Basic Structure

- [ ] The file header contains a `library;` declaration
- [ ] All necessary imports
- [ ] `HfMfuPage` StatefulWidget class
- [ ] `_HfMfuPageState` state class
- [ ] `SingleTickerProviderStateMixin` mixin
- [ ] TabController initialization and disposal

#### Tab Structure (5 Tabs)

- [ ] TabBar contains 5 Tabs
- [ ] TabBarView contains 5 corresponding pages
- [ ] Tabs: Info, Read/Write, NDEF, Emulator, Tools

#### "Info" Tab

- [ ] [Get Info] button -> `HfMfuCmd.info()`
- [ ] [Dump Card] button -> `HfMfuCmd.dump()`
- [ ] [Wipe Card] button -> `HfMfuCmd.wipe()` (with a confirmation dialog)
- [ ] Result display area

#### "Read/Write" Tab

- [ ] Block number input (0-255)
- [ ] [Read Block] button -> `HfMfuCmd.rdbl()`
- [ ] Data input (16-character hex validation)
- [ ] [Write Block] button -> `HfMfuCmd.wrbl()`
- [ ] Password input (8-character hex)
- [ ] [Authenticate] button -> `HfMfuCmd.cauth()`

#### "NDEF" Tab

- [ ] [Read NDEF] button -> `HfMfuCmd.ndefRead()`
- [ ] NDEF result display area

#### "Emulator" Tab

- [ ] File selection functionality
- [ ] [Load into Emulator] -> `HfMfuCmd.eload()`
- [ ] [Save Emulator] -> `HfMfuCmd.esave()`
- [ ] [View Emulator] -> `HfMfuCmd.eview()`
- [ ] [Simulate Card] -> `HfMfuCmd.sim()`

#### "Tools" Tab

- [ ] [Generate Keys] -> `HfMfuCmd.keygen()`
- [ ] UID input (optional)
- [ ] [Generate Password] -> `HfMfuCmd.pwdgen()`
- [ ] [Set UID] -> `HfMfuCmd.setuid()`

#### Common Functionality

- [ ] The `_execute()` method checks the connection state
- [ ] Show a SnackBar message when disconnected
- [ ] Use a monospace font to display hex data
- [ ] Dangerous operations have confirmation dialogs

---

## Phase 3: iCLASS/Picopass Page

### File: `lib/ui/pages/hf_iclass_page.dart`

#### Basic Structure

- [ ] Correct imports
- [ ] StatefulWidget structure
- [ ] TabController (4 tabs)

#### Tab Structure (4 Tabs)

- [ ] Tabs: Info, Read/Write, Cracking, Emulator

#### "Info" Tab

- [ ] [Get Info] -> `HfIclassCmd.info()`
- [ ] [Read Card] -> `HfIclassCmd.reader()`
- [ ] [Dump Card] -> `HfIclassCmd.dump()`

#### "Read/Write" Tab

- [ ] Block number selector (0-31)
- [ ] Key input (16-character hex, optional)
- [ ] [Read Block] -> `HfIclassCmd.rdbl()`
- [ ] Data input (16-character hex)
- [ ] [Write Block] -> `HfIclassCmd.wrbl()`

#### "Cracking" Tab

- [ ] [Check Keys] -> `HfIclassCmd.chk()`
- [ ] [Loclass Attack] -> `HfIclassCmd.loclass()`
- [ ] [Sniff Communication] -> `HfIclassCmd.sniff()`

#### "Emulator" Tab

- [ ] [Load File] -> `HfIclassCmd.eload()`
- [ ] [Save File] -> `HfIclassCmd.esave()`
- [ ] [View] -> `HfIclassCmd.eview()`
- [ ] [Simulate Card] -> `HfIclassCmd.sim()`

---

## Phase 4: ISO15693 Page

### File: `lib/ui/pages/hf_15_page.dart`

#### Basic Structure

- [ ] Correct imports
- [ ] StatefulWidget structure
- [ ] TabController (3 tabs)

#### Tab Structure (3 Tabs)

- [ ] Tabs: Info, Read/Write, Tools

#### "Info" Tab

- [ ] [Reader] -> `Hf15Cmd.reader()`
- [ ] [Tag Info] -> `Hf15Cmd.info()`
- [ ] [Dump Card] -> `Hf15Cmd.dump()`
- [ ] [Wipe Card] -> `Hf15Cmd.wipe()`

#### "Read/Write" Tab

- [ ] Block number input
- [ ] [Read Block] -> `Hf15Cmd.rdbl()`
- [ ] Data input
- [ ] [Write Block] -> `Hf15Cmd.wrbl()`

#### "Tools" Tab

- [ ] [Find AFI] -> `Hf15Cmd.findafi()`
- [ ] UID input
- [ ] [Set UID] -> `Hf15Cmd.csetuid()`
- [ ] [Simulate Card] -> `Hf15Cmd.sim()`
- [ ] [Sniff] -> `Hf15Cmd.sniff()`

---

## Phase 5: Mifare DESFire Page

### File: `lib/ui/pages/hf_mfdes_page.dart`

#### Basic Structure

- [ ] Correct imports
- [ ] StatefulWidget structure
- [ ] TabController (4 tabs)

#### Tab Structure (4 Tabs)

- [ ] Tabs: Info, Applications, Files, Management

#### "Info" Tab

- [ ] [Detect] -> `HfMfdesCmd.detect()`
- [ ] [Info] -> `HfMfdesCmd.info()`
- [ ] [Get UID] -> `HfMfdesCmd.getuid()`
- [ ] [Free Memory] -> `HfMfdesCmd.freemem()`
- [ ] [Check Keys] -> `HfMfdesCmd.chk()`

#### "Applications" Tab

- [ ] [List AIDs] -> `HfMfdesCmd.getaids()`
- [ ] [List Applications] -> `HfMfdesCmd.lsapp()`
- [ ] AID input (6-character hex)
- [ ] [Select Application] -> `HfMfdesCmd.selectapp()`

#### "Files" Tab

- [ ] [List Files] -> `HfMfdesCmd.getfileids()`
- [ ] FID input
- [ ] [Read File] -> `HfMfdesCmd.read()`
- [ ] Data input
- [ ] [Write File] -> `HfMfdesCmd.write()`
- [ ] [Dump Application] -> `HfMfdesCmd.dump()`

#### "Management" Tab

- [ ] Key number input
- [ ] Key input
- [ ] Algorithm selection (AES/DES)
- [ ] [Authenticate] -> `HfMfdesCmd.auth()`
- [ ] [Format PICC] button (with confirmation) -> `HfMfdesCmd.formatpicc()`

---

## Phase 6: HID Prox Page

### File: `lib/ui/pages/lf_hid_page.dart`

#### Basic Structure

- [ ] Correct imports
- [ ] StatefulWidget structure
- [ ] TabController (3 tabs)

#### Tab Structure (3 Tabs)

- [ ] Tabs: Read, Clone/Simulate, Cracking

#### "Read" Tab

- [ ] [Read HID Card] -> `LfHidCmd.reader()`
- [ ] [Demodulate Signal] -> `LfHidCmd.demod()`
- [ ] Result display area (parse FC/CN)

#### "Clone/Simulate" Tab

- [ ] Card number data input (Wiegand format)
- [ ] [Clone to T55xx] -> `LfHidCmd.clone()`
- [ ] [Simulate Card] -> `LfHidCmd.sim()`

#### "Cracking" Tab

- [ ] FC input (optional)
- [ ] [Brute Force] -> `LfHidCmd.brute()`

---

## Phase 7: Testing and Optimization

### Task 7.1: Unit Tests

- [ ] Test tab switching on each page
- [ ] Test that all buttons trigger the correct commands
- [ ] Test input validation (hex format, length)
- [ ] Test messages when no device is connected

### Task 7.2: Integration Tests

- [ ] Test that sidebar navigation switches pages correctly
- [ ] Test that theme switching works normally
- [ ] Test that there are no conflicts with existing pages
- [ ] Test application startup and runtime performance

### Task 7.3: Code Optimization

- [ ] Extract shared components (ActionCard, ResultDisplay, etc.)
- [ ] Optimize duplicate code
- [ ] Add necessary comments
- [ ] Run `flutter analyze` to check for issues

---

## Color Scheme Change Checklist

### Completed Changes

#### 1. Theme File Update (`lib/ui/theme.dart`)

- [x] Switch to a single-mode theme
- [x] Use a dark blue dashboard color scheme
- [x] Remove the lightTheme() method
- [x] Rename darkTheme() to theme()
- [x] Update all color references
- [x] Fix the deprecated `withOpacity` method

#### 2. Application State Update (`lib/state/app_state.dart`)

- [x] Remove the `isDarkMode` state
- [x] Remove the `toggleTheme()` method

#### 3. Main Application Update (`lib/main.dart`)

- [x] Update the theme reference to `AppTheme.theme()`
- [x] Remove theme mode switching logic

#### 4. Home Page Update (`lib/ui/home_page.dart`)

- [x] Remove the theme toggle button
- [x] Clean up related code

#### 5. Settings Page Update (`lib/ui/settings_page.dart`)

- [x] Remove the theme settings option

#### 6. Connection Page Update (`lib/ui/pages/connection_page.dart`)

- [x] Import the new theme file
- [x] Replace all Morandi color references
- [x] Use the new blue theme colors

#### 7. Compilation Verification

- [x] `flutter analyze` reports no errors
- [x] The application compiles normally

### Color Scheme

- **Dark blue background**: `#0F172A`
- **Card color**: `#1E293B`
- **Highlight blue**: `#38BDF8`
- **Secondary gray text**: `#94A3B8`
- **Divider**: `#334155`
- **Error color**: `#F87171`

### Verification Results

- [x] The application starts normally
- [x] All pages display correctly
- [x] Consistent color styling
- [x] No compilation errors

---

## Summary

The color scheme changes are complete, and the application now uses a single-theme mode with a dark blue dashboard style. All related files have been updated, and compilation verification has passed. Development of the new feature pages can begin next.
