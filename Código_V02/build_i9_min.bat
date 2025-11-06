@echo off
set OSSCAD=C:\OSS-CAD-SUITE
set TOP=controlador_caixa_dagua

call "%OSSCAD%\environment.bat"
cd %~dp0

echo [1/4] Synth
yosys -p "read_verilog -sv decodificador_nivel.v controlador_caixa_dagua.v; synth_ecp5 -top %TOP% -json %TOP%.json"

echo [2/4] P
nextpnr-ecp5 --json "%TOP%.json" --textcfg "%TOP%.config" --lpf "C:\Users\yurig\Desktop\projeto-final-verilog\pins.lpf" --45k --package CABGA381 --speed 6

echo [3/4] Pack
ecppack --compress "%TOP%.config" "%TOP%.bit"

echo [4/4] Program (RAM)
openFPGALoader -b colorlight-i9 "%TOP%.bit"
REM openFPGALoader -b colorlight-i9 --unprotect-flash -f --verify "%TOP%.bit"
REM openFPGALoader -b colorlight-i9 --bulk-erase
echo === DONE ===

REM openFPGALoader -b colorlight-i9 --unprotect-flash -f --verify "%TOP%.bit"
