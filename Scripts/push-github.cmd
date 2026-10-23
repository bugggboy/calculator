@echo off
rem 一键把本地工程推到新建的 GitHub 仓库。
rem 用法：
rem   Scripts\push-github.cmd https://github.com/你的用户名/calculator.git
rem
rem 推送时如果弹出浏览器登录窗口，登录你的 GitHub 账号即可（Git Credential Manager）。
rem 不需要手工生成 Token。
setlocal

if "%~1"=="" (
    echo 用法: Scripts\push-github.cmd ^<仓库地址^>
    echo 例如: Scripts\push-github.cmd https://github.com/zhangsan/calculator.git
    pause
    exit /b 1
)

cd /d "%~dp0.."
echo 工作目录: %CD%
echo 目标仓库: %~1
echo.

git remote remove origin >nul 2>&1
git remote add origin "%~1"
if errorlevel 1 (
    echo 添加 remote 失败，检查仓库地址是否正确。
    pause
    exit /b 1
)

echo 开始推送 main 分支……
git push -u origin main
set "CODE=%ERRORLEVEL%"
echo.
if "%CODE%"=="0" (
    echo 推送成功。回到 GitHub 网页：
    echo   1^) 点 Actions -^> Build Unsigned IPA -^> Run workflow
    echo   2^) configuration 选 Release，make_release 勾上
    echo   3^) 等 5~10 分钟，去 Releases 页面用手机 Safari 下载 .ipa
) else (
    echo 推送失败，退出码 %CODE%。常见原因：仓库地址写错、网络需要代理、未登录。
)
pause
exit /b %CODE%
