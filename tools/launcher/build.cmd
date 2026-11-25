@echo off
rem Собирает лаунчер компилятором .NET Framework 4 (есть в любой Windows): dist\GOD-OF-GRIMERKA-Launcher.exe
setlocal
set ROOT=%~dp0..\..
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%ROOT%\dist" mkdir "%ROOT%\dist"
"%CSC%" /nologo /target:winexe /optimize+ /codepage:65001 /win32icon:"%ROOT%\godot\icon.ico" /r:System.IO.Compression.dll /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /out:"%ROOT%\dist\GOD-OF-GRIMERKA-Launcher.exe" "%~dp0Launcher.cs" "%~dp0FastDownload.cs" "%~dp0GamePackage.cs"
exit /b %ERRORLEVEL%
