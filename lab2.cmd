@echo off

set LOG=%1
set BASE=%2
set PROCESS=%3
set ARCHIVE_PATH=%4
set TARGET_IP=%5
set MAX_LOG=%6

if not exist "%LOG%" (
    echo [%date% %time%] Файл з ім’ям %LOG% створено. > "%LOG%"
) else (
    echo [%date% %time%] Файл з ім’ям %LOG% відкрито. >> "%LOG%"
)

w32tm /resync >> "%LOG%" 2>&1

echo [%date% %time%] Список процесів: >> "%LOG%"
tasklist >> "%LOG%"

taskkill /IM "%PROCESS%" /F >> "%LOG%" 2>&1

set COUNT=0
for %%f in (%BASE%\temp* %BASE%\*.TMP) do (
    if exist "%%f" (
        del /q "%%f"
        set /a COUNT=COUNT+1
    )
)
echo [%date% %time%] Видалено %COUNT% тимчасових файлів. >> "%LOG%"

for /f "tokens=1-4 delims=:. " %%a in ("%time%") do (
    set h=%%a
    set m=%%b
    set s=%%c
)
set datetime=%date:/=-%_%h%-%m%-%s%
set ARCH_NAME=%datetime%.zip

powershell -Command "if (Test-Path '%BASE%') { Compress-Archive -Path '%BASE%\*' -DestinationPath '%ARCH_NAME%' }" >> "%LOG%" 2>&1
if exist "%ARCH_NAME%" (
    move "%ARCH_NAME%" "%ARCHIVE_PATH%" >> "%LOG%"
    echo [%date% %time%] Архів переміщено до %ARCHIVE_PATH%. >> "%LOG%"
)

powershell -Command "$y=(Get-Date).AddDays(-1).Date; $found=(Get-ChildItem '%ARCHIVE_PATH%' | Where-Object { $_.LastWriteTime.Date -eq $y }).Count; if ($found -eq 0) { Add-Content '%LOG%' 'Немає архіву за минулий день.' }"

forfiles /p "%ARCHIVE_PATH%" /m *.zip /d -30 /c "cmd /c del /q @path" >> "%LOG%"
echo [%date% %time%] Старі архіви очищено. >> "%LOG%"

ping 8.8.8.8 -n 1 >nul && (
    echo [%date% %time%] Інтернет доступний. >> "%LOG%"
) || (
    echo [%date% %time%] Інтернет недоступний. >> "%LOG%"
)

ping %TARGET_IP% -n 1 >nul
if %errorlevel%==0 (
    echo [%date% %time%] IP %TARGET_IP% активний. Завершення... >> "%LOG%"
    shutdown /s /m \\%TARGET_IP% /t 0 /f >> "%LOG%"
) else (
    echo [%date% %time%] Комп’ютер з IP %TARGET_IP% недоступний. >> "%LOG%"
)

net view >> "%LOG%" 2>&1

for /f %%i in (ipon.txt) do (
    ping %%i -n 1 >nul
    if errorlevel 1 (
        echo [%date% %time%] %%i недоступний. >> "%LOG%"
    )
)

for %%A in ("%LOG%") do set SIZE=%%~zA
if %SIZE% GTR %MAX_LOG% (
    echo [%date% %time%] Лог-файл перевищує %MAX_LOG% байт. >> "%LOG%"
)

powershell -Command "Get-PSDrive -PSProvider FileSystem | Select Name, @{n='Free(MB)';e={[math]::Round($_.Free/1MB)}}, @{n='Used(MB)';e={[math]::Round($_.Used/1MB)}}" >> "%LOG%"

set SYSINFO=systeminfo_%datetime%.txt
systeminfo > "%SYSINFO%"
