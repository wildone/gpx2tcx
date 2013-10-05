:: gpx2tcx.cmd by Paul Colby (http://colby.id.au), no rights reserved ;)
:: $Id: gpx2tcx.cmd 298 2012-02-24 22:09:33Z paul $
@echo off

:: Optional: uncomment the following line to change UTC timezones.
set TIMEZONE=+11:00

:: Optional: uncomment the following line to set the altitude of the first point.
:: This will do nothing if your HRM files actually include altitude data, but helps
:: devices like the RCX5 with no altitude data, and sites like Strava that don't like that.
set ALTITUDE=1.0

:: Update this path to include the location(s) UnxUtils is insstalled.
set PATH=%PATH%;C:\Program Files\UnxUtils\usr\local\wbin;C:\Program Files (x86)\UnxUtils\usr\local\wbin

:: Jump the to "main" block.
goto main

:: UnxUtils' sed does not support the -i flag, so we perform the equivalent manually.
:: usage: call:sedInPlace script filename
:sedInPlace
sed.exe -re "%~1" "%~2" > "%~2.tmp"
diff.exe -qs "%2" "%2.tmp" > nul
if ERRORLEVEL 1 copy "%2.tmp" "%2" > nul
del "%2.tmp"
goto :EOF

:convert
if not exist "%~1.gpx" goto :EOF
echo Processing %~1...
gawk.exe -f "gpx2tcx.awk" -v ALTITUDE=%ALTITUDE% -v HRMFILE=%~1.hrm "%~1.gpx" > %~1.tcx
if defined TIMEZONE call:sedInPlace "s/([>""""][0-9]{4}(-[0-9]{2}){2}T([0-9]{2}:){2}[0-9]{2})Z([<""""])/\1%TIMEZONE%\4/g" %~1.tcx
goto :EOF

:main
FOR /f %%A IN ( 'ls.exe -1 *.gpx *.tcx 2^>^&1 ^| sed.exe -e "s/\.[^.]*$//" ^| uniq.exe -c ^| sed -ne "s/^ *1.//p"' ) DO call::convert %%A

pause
