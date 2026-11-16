@echo off
rem Запуск Godot-версии GOD OF GRIMERKA. Нужен Godot 4.7 в tools\godot (или укажи свой путь ниже).
cd /d "%~dp0"
set GODOT=tools\godot\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot 4.7 не найден в tools\godot. Скачай его с https://godotengine.org и положи туда.
  pause
  exit /b 1
)
start "" "%GODOT%" --path godot
