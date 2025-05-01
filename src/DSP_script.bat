# Use this file for the adaptive filtering via DSP-board

cls
cd scripts

echo 0 0 0 0 0 > ..\data\filterInformation.txt
mode COM3 BAUD=9600 PARITY=n DATA=8

:DSP_loop
	echo 1 > COM3
	COPY COM3 ..\data\filterInformation.txt
	TIMEOUT 1
	goto DSP_loop
