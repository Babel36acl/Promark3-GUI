import 'package:pm3gui/backend/desktop_cli/pm3_process_messages.dart';
import 'app_localizations.dart';

final class LocalizedPm3ProcessMessages implements Pm3ProcessMessages {
  const LocalizedPm3ProcessMessages(this._localizations);

  final AppLocalizations _localizations;

  @override
  String messageConnectionFailed(String value) =>
      _localizations.messageConnectionFailed(value);
  @override
  String get messageConnectionTimedOut =>
      _localizations.messageConnectionTimedOut;
  @override
  String messageConnectionTimedOutSCheckThatThe(String value) =>
      _localizations.messageConnectionTimedOutSCheckThatThe(value);
  @override
  String messageCoolingDownS(String value) =>
      _localizations.messageCoolingDownS(value);
  @override
  String messageCouldNotReadTheExitStatusAfter(String value, String value2) =>
      _localizations.messageCouldNotReadTheExitStatusAfter(value, value2);
  @override
  String messageCouldNotStartPm3PathCheckThe(String value, String value2) =>
      _localizations.messageCouldNotStartPm3PathCheckThe(value, value2);
  @override
  String messageError(String value) => _localizations.messageError(value);
  @override
  String get messageErrorCommandTimedOutTheSessionWas =>
      _localizations.messageErrorCommandTimedOutTheSessionWas;
  @override
  String get messageFailedToForceTerminatePm3KillProcess =>
      _localizations.messageFailedToForceTerminatePm3KillProcess;
  @override
  String messageFailedToSendQuit(String value) =>
      _localizations.messageFailedToSendQuit(value);
  @override
  String messageFailedToSendTheReadOnlyPm3(String value) =>
      _localizations.messageFailedToSendTheReadOnlyPm3(value);
  @override
  String messageFailedToTerminatePm3(String value) =>
      _localizations.messageFailedToTerminatePm3(value);
  @override
  String messageFailedToTerminatePm3ReturnedFalse(String value) =>
      _localizations.messageFailedToTerminatePm3ReturnedFalse(value);
  @override
  String get messageFailedToTerminatePm3TermProcessTree =>
      _localizations.messageFailedToTerminatePm3TermProcessTree;
  @override
  String messageFailedWhileWaitingForPm3ToExit(String value) =>
      _localizations.messageFailedWhileWaitingForPm3ToExit(value);
  @override
  String messageFailedWhileWaitingForPm3ToStart(String value) =>
      _localizations.messageFailedWhileWaitingForPm3ToStart(value);
  @override
  String get messageFatalErrorOnPm3Stderr =>
      _localizations.messageFatalErrorOnPm3Stderr;
  @override
  String get messageFatalErrorOnPm3Stdout =>
      _localizations.messageFatalErrorOnPm3Stdout;
  @override
  String get messageNotConnected => _localizations.messageNotConnected;
  @override
  String get messagePermissionDeniedForTheSerialPortTry =>
      _localizations.messagePermissionDeniedForTheSerialPortTry;
  @override
  String messagePleaseWaitSecondsBeforeRetrying(String value) =>
      _localizations.messagePleaseWaitSecondsBeforeRetrying(value);
  @override
  String messagePm3ProcessExitStatusError(String value) =>
      _localizations.messagePm3ProcessExitStatusError(value);
  @override
  String messagePm3ProcessExitedBeforeTheConnectionPrompt(String value) =>
      _localizations.messagePm3ProcessExitedBeforeTheConnectionPrompt(value);
  @override
  String messagePm3ProcessExitedCode(String value) =>
      _localizations.messagePm3ProcessExitedCode(value);
  @override
  String messagePm3ProgramNotFoundOnWindowsSelect(String value) =>
      _localizations.messagePm3ProgramNotFoundOnWindowsSelect(value);
  @override
  String messagePm3StderrStreamError(String value) =>
      _localizations.messagePm3StderrStreamError(value);
  @override
  String messagePm3StdoutStreamError(String value) =>
      _localizations.messagePm3StdoutStreamError(value);
  @override
  String messagePm3StreamClosed(String value) =>
      _localizations.messagePm3StreamClosed(value);
  @override
  String messageSerialConnectionError(String value) =>
      _localizations.messageSerialConnectionError(value);
  @override
  String get messageSerialDeviceNotFoundCheckThePm3 =>
      _localizations.messageSerialDeviceNotFoundCheckThePm3;
  @override
  String get messageThePm3ProcessManagerHasBeenDisposed =>
      _localizations.messageThePm3ProcessManagerHasBeenDisposed;
  @override
  String get messageThePm3SessionDisconnectedBeforeTheCommand =>
      _localizations.messageThePm3SessionDisconnectedBeforeTheCommand;
  @override
  String get messageTheSerialPortIsInUseBy =>
      _localizations.messageTheSerialPortIsInUseBy;
  @override
  String get messageTimedOutWaitingForPm3ToExit =>
      _localizations.messageTimedOutWaitingForPm3ToExit;
  @override
  String messageUsingPm3(String value) => _localizations.messageUsingPm3(value);
  @override
  String messageWorkingDirectory(String value) =>
      _localizations.messageWorkingDirectory(value);
  @override
  String get pm3Busy => _localizations.pm3Busy;
}
