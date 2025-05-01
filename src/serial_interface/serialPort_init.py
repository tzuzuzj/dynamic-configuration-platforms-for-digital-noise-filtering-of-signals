# hint: wait until FPGA was successfully programmed before you use this script

import serial
import time


# serial port config
ser = serial.Serial("COM5", 9600, timeout=1, parity=serial.PARITY_EVEN)


# read the filter coefficients
fd = open("..\..\data\init_coefficients.txt", "r")
content = fd.read()

time.sleep(0.1)


# send the filter coefficients
i = 0
while i < 127:
    hex_string = content[i] + content[i+1]
    print(hex_string)
    hex_data = int(hex_string, 16)
    data = bytes([hex_data])
    ser.write(data)
    i+=2

    time.sleep(0.01)
