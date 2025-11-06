@echo off
set OSSCAD=C:\OSS-CAD-SUITE
set TOP=transistor_sensor_test
set LPF=transistor_sensor_test.lpf

call "%OSSCAD%\environment.bat"
cd %~dp0

echo [1/4] Synth
yosys -p "read_verilog -sv %TOP%.sv; synth_ecp5 -top %TOP% -json %TOP%.json"

echo [2/4] 
nextpnr-ecp5 --json "%TOP%.json" --textcfg "%TOP%.config" --lpf "%LPF%" --45k --package CABGA381 --speed 6

echo [3/4] Pack
ecppack --compress "%TOP%.config" "%TOP%.bit"

echo [4/4] Program (RAM)
REM openFPGALoader -b colorlight-i9 "%TOP%.bit"
openFPGALoader -b colorlight-i9 --unprotect-flash -f --verify "%TOP%.bit"

echo === DONE ===