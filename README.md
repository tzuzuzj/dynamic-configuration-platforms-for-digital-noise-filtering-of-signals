Copyright 2020 Stefan Dangl (stefan.dangl@tuwien.ac.at),
License: ISC license

# Dynamic configuration Platforms for digital noise filtering of Signals

## Pre-requisites

### Hardware:
- Altera DE2-70 FPGA-Board
- Wondom DSP Board
- PJRC Teensy 3.6 MCU
- Windows 10 PC

### Software:
- Python 3
- Octave 5.1.0.0
- Quartus II 13.0 (newer versions may not work with the recomended FPGA-Board)
- Sigma Studio 4.4
- Arduino 1.8.10 + teensy.exe


## Preperation-Step

1) Connect your Windows PC with the MCU.

2) Open the Arduino Project "\src\noise_detection.ino"

3) choose: Tools -> Board -> Teensy 3.6

4) Upload the Program.


## FPGA-Implementation

1) Connect your Windows PC with the FPGA-Board.

2) Open the Quartus II Project **\src\quartus_project\AutomatedDigitalFilter.qpf**.
Start the Compilation, open the programmer and start the programming of the FPGA-Board.

3) Open the FPGA-script with a text editor and adjust the **15th line** following:
change
`start GNU_Octave_CLI --persist scripts\filter_coefficients.m`
to
`start <your absolute program path of GNU Octave CLI> --persist <your absolute path of the repository>\scripts\filter_coefficients.m`

4) Run the FPGA-script. The filter instrument should now adjust its behavior automatically depending on the input signal.
If the script doesn't work correctly check if you connected the MCU to the correct COM port.

5) To run the files on an Unix machine the shell script has to be changed slightly.


## DSP-Implementation

1) Connect your Windows PC with the DSP-Board.

2) Open the Sigma Studio Project **\src\SigmaStudio_Project\AutomatedDigitalFilter.dspproj**.
Select: **Tools** -> **Script**. A new window should open.
At the new window, select: **File** -> **Open** -> **repo\scripts\SigmaStudio_script.sss** -> **Tools** -> **Run Script**

3) Start the DSP-Script. The filter instrument should now adjust its behavior automatically depending on the input signal.
If the script doesn't work correctly check if you connected the MCU with the correct COM port.

4) Unfortunately, at the current state Sigma Studio is not available for Unix systems.
