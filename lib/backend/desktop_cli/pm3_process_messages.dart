/// Framework-independent message contract with legacy Chinese defaults.
///
/// Flutter callers supply an adapter; standalone Dart tools need no framework.
class Pm3ProcessMessages {
  const Pm3ProcessMessages();

  String messageConnectionFailed(String value) => '连接失败: $value';
  String get messageConnectionTimedOut => '[连接超时]';
  String messageConnectionTimedOutSCheckThatThe(String value) =>
      '连接超时 (${value}s)，请检查设备是否已连接';
  String messageCoolingDownS(String value) => '[请等待冷却: ${value}s]';
  String messageCouldNotReadTheExitStatusAfter(String value, String value2) =>
      'PM3 $value 流关闭后读取退出状态失败: $value2';
  String messageCouldNotStartPm3PathCheckThe(String value, String value2) =>
      '无法启动 PM3 程序: $value\n路径: $value2\n请检查路径是否正确，程序是否已编译';
  String messageError(String value) => '[错误] $value';
  String get messageErrorCommandTimedOutTheSessionWas => '[错误] 命令超时，会话已停止';
  String get messageFailedToForceTerminatePm3KillProcess =>
      '强制终止 PM3 进程失败: KILL/整树终止未成功';
  String messageFailedToSendQuit(String value) => '发送 quit 失败: $value';
  String messageFailedToSendTheReadOnlyPm3(String value) =>
      'PM3 BAT 只读握手写入失败: $value';
  String messageFailedToTerminatePm3(String value) => '终止 PM3 进程失败: $value';
  String messageFailedToTerminatePm3ReturnedFalse(String value) =>
      '终止 PM3 进程失败: $value 返回 false';
  String get messageFailedToTerminatePm3TermProcessTree =>
      '终止 PM3 进程失败: TERM/整树终止未成功';
  String messageFailedWhileWaitingForPm3ToExit(String value) =>
      '等待 PM3 退出失败: $value';
  String messageFailedWhileWaitingForPm3ToStart(String value) =>
      '等待 PM3 启动失败: $value';
  String get messageFatalErrorOnPm3Stderr => 'PM3 stderr 出现致命错误';
  String get messageFatalErrorOnPm3Stdout => 'PM3 stdout 出现致命错误';
  String get messageNotConnected => '[未连接]';
  String get messagePermissionDeniedForTheSerialPortTry =>
      '串口权限不足\n请尝试: sudo chmod 666 /dev/ttyACM0\n或将用户加入 dialout 组';
  String messagePleaseWaitSecondsBeforeRetrying(String value) =>
      '请等待 $value 秒后再试';
  String messagePm3ProcessExitStatusError(String value) =>
      'PM3 进程退出状态错误: $value';
  String messagePm3ProcessExitedBeforeTheConnectionPrompt(String value) =>
      'PM3 进程在连接提示前退出 (code=$value)';
  String messagePm3ProcessExitedCode(String value) => '[PM3 进程退出, code=$value]';
  String messagePm3ProgramNotFoundOnWindowsSelect(String value) =>
      '找不到 PM3 程序: $value\nWindows 请优先选择官方发行包根目录的 pm3.bat；Linux 请选择 proxmark3';
  String messagePm3StderrStreamError(String value) => 'PM3 stderr 流错误: $value';
  String messagePm3StdoutStreamError(String value) => 'PM3 stdout 流错误: $value';
  String messagePm3StreamClosed(String value) => 'PM3 $value 流已关闭';
  String messageSerialConnectionError(String value) => '串口连接错误: $value';
  String get messageSerialDeviceNotFoundCheckThePm3 =>
      '串口设备不存在，请检查 PM3 是否已通过 USB 连接';
  String get messageThePm3ProcessManagerHasBeenDisposed => 'PM3 进程管理器已释放';
  String get messageThePm3SessionDisconnectedBeforeTheCommand =>
      'PM3 会话在命令完成前断开';
  String get messageTheSerialPortIsInUseBy =>
      '串口 已被其他进程占用\n请关闭其他使用该端口的程序（如另一个 pm3 终端）';
  String get messageTimedOutWaitingForPm3ToExit => '终止 PM3 后等待退出超时';
  String messageUsingPm3(String value) => '[使用 PM3: $value]';
  String messageWorkingDirectory(String value) => '[工作目录: $value]';
  String get pm3Busy => 'PM3 命令仍在执行，请等待完成或断开连接';
}
