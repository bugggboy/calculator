@echo off
rem 运行 Core 层的 Swift 单元测试（不需要 Mac）
rem 用法：双击，或在 cmd 里执行 Scripts\test-core.cmd
setlocal

set "SWIFT_ROOT=D:\Swift"
if not exist "%SWIFT_ROOT%\Toolchains" set "SWIFT_ROOT=%LOCALAPPDATA%\Programs\Swift"

set "PATH=%SWIFT_ROOT%\Toolchains\6.4.1+Asserts\usr\bin;%SWIFT_ROOT%\Runtimes\6.4.1\usr\bin;%PATH%"
set "SDKROOT=%SWIFT_ROOT%\Platforms\6.4.1\Windows.platform\Developer\SDKs\Windows.sdk"

rem Windows 环境变量名不区分大小写，Swift 遇到大小写重复的键会直接崩溃
set "http_proxy="
set "https_proxy="
set "all_proxy="

cd /d "%~dp0..\Core"
echo 工作目录: %CD%
echo 工具链:   %SWIFT_ROOT%
echo.
swift test %*
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (echo 结果: 通过) else (echo 结果: 失败，退出码 %CODE%)
pause
exit /b %CODE%
