@echo off
chcp 65001 >nul
title Go Linux 交叉编译脚本
setlocal enabledelayedexpansion

echo ========================================
echo    Go Windows to Linux 交叉编译工具
echo ========================================
echo.

rem ==========================================
rem 用户可配置区域 - 按需修改以下变量
rem ==========================================

rem main.go 相对于项目根目录的路径
set "MAIN_PATH=./cmd/picoclaw/main.go"

rem 生成的可执行文件名（不含后缀）
set "APP_NAME=picoclaw"

rem 目标系统：linux
set "GOOS=linux"

rem 目标架构：amd64(常见云服务器) 或 arm64(ARM架构)
set "GOARCH=amd64"

rem CGO: 0(推荐静态链接) 或 1(动态链接，需配置交叉编译器)
set "CGO_ENABLED=0"

rem ==========================================

echo [配置信息]
echo        源码路径: %MAIN_PATH%
echo        输出目录: ./build
echo        应用名称: %APP_NAME%
echo        目标系统: %GOOS%
echo        目标架构: %GOARCH%
echo        CGO状态:  %CGO_ENABLED%
echo.

rem 检查 Go 环境
go version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未检测到 Go 环境，请确保 Go 已安装并添加到 PATH
    pause
    exit /b 1
)

rem 检查源文件是否存在
set "CHECK_PATH=%MAIN_PATH:./=%"
if not exist "%MAIN_PATH%" if not exist "%CHECK_PATH%" (
    echo [错误] 未找到源文件: %MAIN_PATH%
    echo [提示] 请检查 MAIN_PATH 变量配置是否正确
    echo [提示] 当前工作目录: %CD%
    pause
    exit /b 1
)

rem 整理依赖（如果存在 go.mod）
if exist go.mod (
    echo [信息] 正在整理依赖...
    go mod tidy
    if errorlevel 1 (
        echo [警告] 依赖整理失败，继续尝试编译...
    )
    echo.
)

rem 创建 build 目录（如果不存在）
if not exist build mkdir build

rem 编译
echo [信息] 正在编译 Linux 可执行文件...

rem 构建输出文件名（带路径）
set "OUTPUT_NAME=build\%APP_NAME%-%GOOS%-%GOARCH%"

rem 设置环境变量并编译
setlocal
set GOOS=%GOOS%
set GOARCH=%GOARCH%
set CGO_ENABLED=%CGO_ENABLED%

rem 编译命令
go build -ldflags="-s -w" -o %OUTPUT_NAME% %MAIN_PATH%

if errorlevel 1 (
    endlocal
    echo.
    echo [错误] 编译失败！
    pause
    exit /b 1
)

endlocal

echo.
echo [成功] 编译完成: %OUTPUT_NAME%
echo.

rem 验证文件
if exist %OUTPUT_NAME% (
    echo [信息] 文件详情:
    dir %OUTPUT_NAME%
    echo.

    rem 可选：打包
    set /p PACKAGE=是否打包为 tar.gz 方便传输？(Y/N):
    if /I "!PACKAGE!"=="Y" (
        set "ARCHIVE_NAME=build\%APP_NAME%-%GOOS%-%GOARCH%.tar.gz"
        if exist !ARCHIVE_NAME! del !ARCHIVE_NAME!

        rem 注意：tar 在 Windows 10 1803+ 自带，但需要正确路径格式
        tar -czf !ARCHIVE_NAME! -C build %APP_NAME%-%GOOS%-%GOARCH%

        if errorlevel 1 (
            echo [提示] 打包失败，请确保系统支持 tar 命令
        ) else (
            echo [成功] 已打包: !ARCHIVE_NAME!
            set /p DEL_ORIG=是否删除原文件保留压缩包？(Y/N):
            if /I "!DEL_ORIG!"=="Y" (
                del %OUTPUT_NAME%
                echo [信息] 已删除原可执行文件，仅保留压缩包
            )
        )
    )

    echo.
    echo ========================================
    echo  部署命令（在 Ubuntu 上执行）:
    echo.
    echo  1. 上传文件到服务器：
    echo     scp %OUTPUT_NAME% user@server:/path/to/app/
    echo     或（如果打包了）
    echo     scp build\%APP_NAME%-%GOOS%-%GOARCH%.tar.gz user@server:/path/to/app/
    echo.
    echo  2. 在服务器上执行：
    echo     cd /path/to/app
    if /I "!PACKAGE!"=="Y" (
        echo     tar -xzf %APP_NAME%-%GOOS%-%GOARCH%.tar.gz
    )
    echo     chmod +x %APP_NAME%-%GOOS%-%GOARCH%
    echo     ./%APP_NAME%-%GOOS%-%GOARCH%
    echo ========================================
) else (
    echo [错误] 未找到输出文件
)

echo.
pause