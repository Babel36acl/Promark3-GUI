/// Terminal page — interactive pm3 console.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pm3gui/state/app_state.dart';
import 'package:pm3gui/services/pm3_command_catalog.dart';
import 'package:pm3gui/l10n/l10n.dart';

class _AutocompleteIntent extends Intent {
  const _AutocompleteIntent();
}

class _AutocompletePrevIntent extends Intent {
  const _AutocompletePrevIntent();
}

class TerminalPage extends StatefulWidget {
  const TerminalPage({super.key});

  @override
  State<TerminalPage> createState() => _TerminalPageState();
}

class _TerminalPageState extends State<TerminalPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _outputSelectionFocusNode = FocusNode();
  final _keyboardFocusNode = FocusNode();

  List<Pm3CommandEntry> _catalog = const [];
  final Map<String, List<Pm3CommandEntry>> _suggestionIndex = {};
  List<Pm3CommandEntry> _suggestions = const [];

  List<Pm3CommandEntry> _cycleCandidates = const [];
  int _cycleIndex = -1;
  bool _ignoreNextInputChange = false;

  int _lastTerminalLineCount = 0;
  String? _catalogLanguage;
  Object? _catalogError;
  int _catalogRequest = 0;

  bool get _isCyclingAutocomplete => _cycleCandidates.isNotEmpty;

  List<Pm3CommandEntry> get _displaySuggestions {
    return _isCyclingAutocomplete ? _cycleCandidates : _suggestions;
  }

  String? get _selectedSuggestionCommand {
    if (!_isCyclingAutocomplete || _cycleIndex < 0) return null;
    if (_cycleIndex >= _cycleCandidates.length) return null;
    return _cycleCandidates[_cycleIndex].command;
  }

  Pm3CommandEntry? get _selectedOrFirstSuggestion {
    if (_displaySuggestions.isEmpty) return null;
    if (_selectedSuggestionCommand == null) return _displaySuggestions.first;
    for (final e in _displaySuggestions) {
      if (e.command == _selectedSuggestionCommand) return e;
    }
    return _displaySuggestions.first;
  }

  Pm3CommandEntry? get _activeEntry {
    final input = _inputController.text;
    if (input.trim().isEmpty) return null;

    for (final e in _catalog) {
      if (e.appliesToInput(input)) return e;
    }

    if (_displaySuggestions.isNotEmpty) return _displaySuggestions.first;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_catalogLanguage != language) {
      _catalogLanguage = language;
      _catalog = const [];
      _suggestionIndex.clear();
      _suggestions = const [];
      _resetAutocompleteCycle();
      _loadCatalog(language);
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _outputSelectionFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_ignoreNextInputChange) {
      _ignoreNextInputChange = false;
    } else {
      _resetAutocompleteCycle();
    }
    _updateSuggestions();
  }

  void _resetAutocompleteCycle() {
    if (!_isCyclingAutocomplete) return;
    _cycleCandidates = const [];
    _cycleIndex = -1;
  }

  Future<void> _loadCatalog(String language) async {
    final request = ++_catalogRequest;
    try {
      final loaded = await Pm3CommandCatalog.load(
          preferZh: language == 'zh', bundle: DefaultAssetBundle.of(context));
      if (!mounted || request != _catalogRequest) return;
      setState(() {
        _catalogError = null;
        _catalog = loaded;
        _rebuildSuggestionIndex();
        _updateSuggestions();
      });
    } on FlutterError catch (error) {
      if (mounted && request == _catalogRequest) {
        setState(() => _catalogError = error);
      }
    } on FormatException catch (error) {
      if (mounted && request == _catalogRequest) {
        setState(() => _catalogError = error);
      }
    }
  }

  void _rebuildSuggestionIndex() {
    _suggestionIndex.clear();
    for (final e in _catalog) {
      final parts = e.command.toLowerCase().trim().split(RegExp(r'\s+'));
      if (parts.isEmpty || parts.first.isEmpty) continue;

      void addKey(String key) {
        final list =
            _suggestionIndex.putIfAbsent(key, () => <Pm3CommandEntry>[]);
        list.add(e);
      }

      addKey(parts.first);
      if (parts.length >= 2) {
        addKey('${parts[0]} ${parts[1]}');
      }
    }
  }

  List<Pm3CommandEntry> _candidateEntriesForQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _catalog;

    final parts = q.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return _catalog;

    if (parts.length >= 2) {
      final twoToken = '${parts[0]} ${parts[1]}';
      final twoTokenCandidates = _suggestionIndex[twoToken];
      if (twoTokenCandidates != null) return twoTokenCandidates;
    }

    final oneTokenCandidates = _suggestionIndex[parts.first];
    return oneTokenCandidates ?? _catalog;
  }

  void _updateSuggestions() {
    final query = _inputController.text.trim();
    if (query.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }

    final candidates = _candidateEntriesForQuery(query);
    final prefixMatches =
        candidates.where((e) => e.commandPrefixMatches(query)).toList();
    final fuzzyMatches = candidates.where((e) => e.matches(query)).toList();

    final merged = <Pm3CommandEntry>[];
    final seen = <String>{};

    for (final e in [...prefixMatches, ...fuzzyMatches]) {
      if (seen.add(e.command)) {
        merged.add(e);
      }
      if (merged.length >= 6) break;
    }

    final matches = merged;
    setState(() => _suggestions = matches);
  }

  void _cycleAutocomplete({required bool forward}) {
    if (!_isCyclingAutocomplete) {
      if (_suggestions.isEmpty) return;
      _cycleCandidates = List<Pm3CommandEntry>.from(_suggestions);
      _cycleIndex = forward ? 0 : _cycleCandidates.length - 1;
    } else {
      final len = _cycleCandidates.length;
      if (len == 0) return;
      final delta = forward ? 1 : -1;
      _cycleIndex = ((_cycleIndex + delta) % len + len) % len;
    }

    final selected = _cycleCandidates[_cycleIndex].command;
    setState(() {});
    _setInputText(selected, preserveCycle: true);
  }

  void _setInputText(String value, {required bool preserveCycle}) {
    if (preserveCycle) {
      _ignoreNextInputChange = true;
    }

    _inputController.text = value;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: value.length),
    );
    _focusNode.requestFocus();
  }

  void _insertParamToken(String paramLine) {
    final token = _extractParamToken(paramLine);
    if (token.isEmpty) return;

    final old = _inputController.text;
    final needsSpace = old.isNotEmpty && !old.endsWith(' ');
    final next = '$old${needsSpace ? ' ' : ''}$token ';

    _setInputText(next, preserveCycle: false);
  }

  String _extractParamToken(String paramLine) {
    final text = paramLine.trim();
    if (text.isEmpty) return '';

    final parts = text.split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';

    for (final p in parts) {
      if (p.startsWith('--')) return p;
      if (p.startsWith('-')) return p;
    }

    return parts.first;
  }

  void _submitCommand() {
    final cmd = _inputController.text.trim();
    if (cmd.isEmpty) return;
    context.read<AppState>().sendCommand(cmd);
    _inputController.clear();
    _resetAutocompleteCycle();
    setState(() => _suggestions = const []);
    _focusNode.requestFocus();

    // Scroll to bottom after a short delay for output to arrive
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _scheduleAutoScrollIfOutputChanged(int lineCount) {
    if (lineCount == _lastTerminalLineCount) return;
    _lastTerminalLineCount = lineCount;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final position = _scrollController.position;
      final nearBottom = (position.maxScrollExtent - position.pixels) < 120;
      if (nearBottom || lineCount <= 1) {
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep a subscription to the revision counter so the widget rebuilds
    // when terminal output changes. Value itself is unused below.
    context.select<AppState, int>((s) => s.outputRevision);
    final isConnected = context.select<AppState, bool>((s) => s.isConnected);
    final appState = context.read<AppState>();
    final output = appState.terminalOutputStripped;

    // Use the actual line count for auto-scroll logic so we detect
    // appended lines correctly (outputRevision is a revision counter).
    _scheduleAutoScrollIfOutputChanged(output.length);

    return Column(
      children: [
        if (_catalogError case final error?)
          Text(context.l10n.terminalCatalogError(error.toString()),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        // Quick command bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickBtn(context.l10n.terminalHfSearch, 'hf search'),
                _quickBtn(context.l10n.terminalLfSearch, 'lf search'),
                _quickBtn(context.l10n.terminal14aInfo, 'hf 14a info'),
                _quickBtn(context.l10n.hardwareVersion, 'hw version'),
                _quickBtn(context.l10n.antennaTune, 'hw tune'),
                _quickBtn(context.l10n.terminalLfRead, 'lf read'),
                _quickBtn(context.l10n.terminalAutopwn, 'hf mf autopwn'),
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Terminal output
        Expanded(
          child: Container(
            color: const Color(0xFF0D0D1A),
            child: SelectableRegion(
              selectionControls: materialTextSelectionControls,
              focusNode: _outputSelectionFocusNode,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: output.length,
                itemBuilder: (context, index) {
                  final line = output[index];
                  return Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.4,
                      color: _lineColor(line),
                    ),
                  );
                },
              ),
            ),
          ),
        ),

        if (_displaySuggestions.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFF17172A),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _displaySuggestions.map(
                (item) {
                  final selected = item.command == _selectedSuggestionCommand;
                  return ActionChip(
                    label: Text(
                      item.command,
                      style: const TextStyle(fontSize: 12),
                    ),
                    tooltip: item.localizedTooltip,
                    backgroundColor: selected ? Colors.blueGrey.shade700 : null,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _setInputText(item.command, preserveCycle: false);
                    },
                  );
                },
              ).toList(),
            ),
          ),

        if (_selectedOrFirstSuggestion != null)
          Container(
            width: double.infinity,
            color: const Color(0xFF17172A),
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Text(
              context.l10n.messageHint(
                  (_selectedOrFirstSuggestion!.localizedHint).toString()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blueGrey.shade100,
              ),
            ),
          ),

        // Input bar
        Container(
          color: const Color(0xFF1A1A2E),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Text(
                'pm3 › ',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: isConnected ? Colors.greenAccent : Colors.grey,
                ),
              ),
              Expanded(
                child: Shortcuts(
                  shortcuts: {
                    const SingleActivator(LogicalKeyboardKey.tab):
                        const _AutocompleteIntent(),
                    const SingleActivator(
                      LogicalKeyboardKey.tab,
                      shift: true,
                    ): const _AutocompletePrevIntent(),
                  },
                  child: Actions(
                    actions: {
                      _AutocompleteIntent: CallbackAction<_AutocompleteIntent>(
                        onInvoke: (_) {
                          _cycleAutocomplete(forward: true);
                          return null;
                        },
                      ),
                      _AutocompletePrevIntent:
                          CallbackAction<_AutocompletePrevIntent>(
                        onInvoke: (_) {
                          _cycleAutocomplete(forward: false);
                          return null;
                        },
                      ),
                    },
                    child: KeyboardListener(
                      focusNode: _keyboardFocusNode,
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent) {
                          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                            _navigateHistory(-1);
                          } else if (event.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            _navigateHistory(1);
                          }
                        }
                      },
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: context.l10n.terminalInputHint,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _submitCommand(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu_book, size: 20),
                onPressed: _showQuickInputPanel,
                tooltip: context.l10n.terminalCatalog,
              ),
              IconButton(
                icon: const Icon(Icons.send, size: 20),
                onPressed: _submitCommand,
                tooltip: context.l10n.terminalSend,
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep, size: 20),
                onPressed: () {
                  context.read<AppState>().clearTerminal();
                },
                tooltip: context.l10n.messageClearTerminal,
              ),
            ],
          ),
        ),

        if (_activeEntry != null && _activeEntry!.params.isNotEmpty)
          Container(
            width: double.infinity,
            color: const Color(0xFF141426),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _activeEntry!.params
                  .take(8)
                  .map(
                    (p) => InputChip(
                      label: Text(
                        p,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _insertParamToken(p),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _showQuickInputPanel() async {
    if (_catalog.isEmpty) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final searchCtrl = TextEditingController();
        var filtered = _catalog;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateFilter(String q) {
              final query = q.trim().toLowerCase();
              setSheetState(() {
                if (query.isEmpty) {
                  filtered = _catalog;
                } else {
                  filtered = _catalog
                      .where((e) =>
                          e.command.toLowerCase().contains(query) ||
                          e.name.toLowerCase().contains(query) ||
                          e.className.toLowerCase().contains(query))
                      .toList();
                }
              });
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: context.l10n.terminalSearchHint,
                      ),
                      onChanged: updateFilter,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 380,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            dense: true,
                            title: Text(item.command),
                            subtitle: Text(
                              item.localizedHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${item.className}·${item.name}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            onTap: () => Navigator.pop(context, item.command),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null && selected.isNotEmpty) {
      _setInputText(selected, preserveCycle: false);
    }
  }

  Widget _quickBtn(String label, String cmd) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () {
          context.read<AppState>().sendCommand(cmd);
        },
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Color _lineColor(String line) {
    if (line.startsWith('[pm3]')) return Colors.cyanAccent;
    if (line.startsWith('[ERR]') || line.contains('[-]')) {
      return Colors.redAccent;
    }
    if (line.contains('[+]')) return Colors.greenAccent;
    if (line.contains('[=]')) return Colors.white70;
    if (line.contains('[#]')) return Colors.yellow;
    return Colors.white54;
  }

  void _navigateHistory(int direction) {
    final appState = context.read<AppState>();
    final history = appState.commandHistory;
    if (history.isEmpty) return;

    appState.historyIndex += direction;
    if (appState.historyIndex < 0) appState.historyIndex = 0;
    if (appState.historyIndex >= history.length) {
      appState.historyIndex = history.length;
      _inputController.clear();
      return;
    }

    _setInputText(history[appState.historyIndex], preserveCycle: false);
  }
}
