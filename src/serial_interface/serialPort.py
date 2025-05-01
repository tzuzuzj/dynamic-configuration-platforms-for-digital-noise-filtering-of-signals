import serial
import time


# serial port config
ser = serial.Serial("COM5", 9600, timeout=1, parity=serial.PARITY_EVEN)

time.sleep(1)

# read the new filter coefficients
fd = open("..\..\data\shared_buffer.txt", "r")
content = fd.read()
fd.close()

# read the old filter coefficients
fd = open("..\..\data\shared_buffer_old.txt", "r")
content_old = fd.read()
fd.close()

# check if they are equal
if content == content_old:
    print("no new data")

print("new data")
# save current content as old content
fd = open("..\..\data\shared_buffer_old.txt", "w")
fd.write(content)
fd.close()


# send the filter coefficients
i = 0
while i < 127:
    hex_string = content[i] + content[i+1]
    print(hex_string)
    hex_data = int(hex_string, 16)
    data = bytes([hex_data])
    ser.write(data)
    i+=2

    time.sleep(0.08)
