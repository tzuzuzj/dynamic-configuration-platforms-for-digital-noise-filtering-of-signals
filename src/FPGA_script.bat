# Use this file for adaptive filtering via FPGA-board

cls

cd scripts
mode COM3 BAUD=9600 PARITY=n DATA=8
serial_interface\serialPort_init.py

:loop
	TIMEOUT 1
	echo 1 > COM3
	COPY COM3 ..\data\filterInformation.txt
	type ..\data\filterInformation.txt
	TIMEOUT 1
	start GNU_Octave_CLI --persist filter_coefficients\filter_coefficients.m		# You may have to adapt this line according to your installation of GNU Octave
	TIMEOUT 3
	serial_interface\serialPort.py
	goto loop
