@echo off
rem Собирает установщик: dist\GOD-OF-GRIMERKA-Setup.exe (компилятор .NET Framework 4 есть в любой Windows).
rem heroes.png — рендер героев из меню игры; обновить: Godot ... -- --menu-render=<путь>\tools\setup\heroes.png
setlocal
set ROOT=%~dp0..\..
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%ROOT%\dist" mkdir "%ROOT%\dist"
"%CSC%" /nologo /target:winexe /optimize+ /codepage:65001 /win32icon:"%ROOT%\godot\icon.ico" /resource:"%~dp0heroes.png",heroes.png /r:System.Web.Extensions.dll /r:System.Windows.Forms.dll /r:System.Drawing.dll /out:"%ROOT%\dist\GOD-OF-GRIMERKA-Setup.exe" "%~dp0Setup.cs"
exit /b %ERRORLEVEL%
