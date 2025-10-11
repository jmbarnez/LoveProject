@echo off
echo Building .love file...

REM Create temp directory for game files
if exist "temp_game" rmdir /s /q "temp_game"
mkdir "temp_game"

REM Copy game files (exclude build files and executables)
robocopy . "temp_game" /E /XF "*.exe" "*.bat" "*.zip" "*.love" "*.md" ".gitignore" /XD ".git" "temp_game" /NFL /NDL /NJH /NJS

REM Create the .love file
cd "temp_game"
powershell "Compress-Archive -Path * -DestinationPath ../Novus.zip -Force"
cd ..

REM Rename zip to love
if exist "Novus.love" del "Novus.love"
ren "Novus.zip" "Novus.love"

REM Cleanup
rmdir /s /q "temp_game"

echo Build complete: Novus.love
echo.
echo To run this game:
echo 1. Install Love2D from https://love2d.org
echo 2. Double-click Novus.love or drag it onto love.exe
pause