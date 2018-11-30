@if "%DEBUG%" == "" @echo off

@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.

@rem put this somewhere that's often ignored by git
set output_dir=%DIRNAME%\out\ndk\standalone

call :generate_standalone_ndk
call :generate_config

echo Done
exit /b %ERRORLEVEL%


:generate_standalone_ndk

@rem check for NDK standalone
if exist "%output_dir%" echo Standalone NDK files found! && exit /b 0

cd %ANDROID_HOME%
for /f "tokens=* usebackq" %%F in (`dir "*make_standalone_toolchain.py" /s /b`) do (
	set standalone_script=%%F
)
cd %DIRNAME%

@rem Try to find and print some info about the NDK based on the location of the toolchain script
if exist "%standalone_script%" goto standaloneScriptFound

echo NDK not found. Please make sure that ANDROID_HOME is set and the NDK has been installed there
exit /b 1

:standaloneScriptFound
echo Standalone NDK files appear to be missing.
echo     Attempting to install them...
for %%F in (%standalone_script%) do set tools_dir=%%~dpF
set tools_dir=%tools_dir:~0,-1%
for %%F in (%tools_dir%) do set build_dir=%%~dpF
set build_dir=%build_dir:~0,-1%
for %%F in (%build_dir%) do set ndk_dir=%%~dpF
for /f "tokens=* usebackq" %%F in (`findstr "[0-9.]{5,}" %ndk_dir%\source.properties`) do (
	set ndk_version=%%F
)
echo         NDK version %ndk_version% found at %ndk_dir%

echo         Installing the standalone NDK for "x86|arm|arm64" into %output_dir%
mkdir %output_dir%
"%standalone_script%" --arch x86 --api 16 --install-dir "%output_dir%\x86"
"%standalone_script%" --arch arm --api 16 --install-dir "%output_dir%\arm"
"%standalone_script%" --arch arm64 --api 21 --install-dir "%output_dir%\arm64"

@rem end of generate_standalone_ndk
exit /b 0


:generate_config

@rem check for our generated cargo file
set cargo_dir=%DIRNAME%\.cargo
set generated_cargo_config=%cargo_dir%\config
set generated_cargo_config_hash=%cargo_dir%\.config-windows.hash
set generated_cargo_config_hash_tmp=%cargo_dir%\.config-windows.hash.tmp

if exist "%generated_cargo_config%" goto configExists
goto notFound

:configExists
if exist "%generated_cargo_config_hash%" goto checkConfig
goto notFound

:checkConfig
echo Cargo config found!

certutil -hashfile %generated_cargo_config% > %generated_cargo_config_hash_tmp%
comp %generated_cargo_config_hash% %generated_cargo_config_hash_tmp% /m
if %ERRORLEVEL% equ 0 exit /b 0
echo.

echo     but it does not appear to be correct! Regenerating it.

set backup_config=%cargo_dir%\config.backup
echo     First, backing it up from %generated_cargo_config% to %backup_config%
copy %generated_cargo_config% %backup_config%
goto generate

:notFound
echo Cargo config not found!

:generate
echo     Generating cargo config at %generated_cargo_config%

mkdir %cargo_dir% 2>NUL

@rem Cargo needs forward slashes
set output_dir=%output_dir:\=/%

(

	echo #auto-generated by build-ndk-standalone.bat.  Modifications may get replaced.
	echo.
	echo [build]
	echo target-dir = "build/rust/target"
	echo.
	echo [target.i686-linux-android]
	echo ar = "%output_dir%/x86/bin/i686-linux-android-ar.exe"
	echo linker = "%output_dir%/x86/bin/i686-linux-android-clang.cmd"
	echo.
	echo [target.armv7-linux-androideabi]
	echo ar = "%output_dir%/arm/bin/arm-linux-androideabi-ar.exe"
	echo linker = "%output_dir%/arm/bin/arm-linux-androideabi-clang.cmd"
	echo.
	echo [target.aarch64-linux-android]
	echo ar = "%output_dir%/arm64/bin/aarch64-linux-android-ar.exe"
	echo linker = "%output_dir%/arm64/bin/aarch64-linux-android-clang.cmd"

) > %generated_cargo_config%

certutil -hashfile %generated_cargo_config% > %generated_cargo_config_hash%

@rem end of generate_config
exit /b 0