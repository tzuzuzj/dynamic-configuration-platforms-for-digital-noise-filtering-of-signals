% (C) Stefan Dangl (dangl.stefan@gmx.at)
% Project: Dynamic configuration Platforms for digital noise filtering of signals
% This script computes the filter coefficients for a given bandpass.


pkg load signal;
clc;
output_precision(16);


% Function to sort the sequence of bytes to send them in the right order.
function hex_string = switch_bytes (hex_string)
  i = 1;
  while (i <= 8)
    a = hex_string(i);
    hex_string(i) = hex_string(16-i);
    hex_string(16-i) = a;

    a = hex_string(i+1);
    hex_string(i+1) = hex_string(17-i);
    hex_string(17-i) = a;

    i = i + 2;
  endwhile

endfunction


% sampling frequency
s = tf('s');
Ts_high = 1/96000;


% get Information about the filter
Input_fileID = fopen('../../data/FilterInformation.txt');
input_data = dlmread (Input_fileID, ' ')
fclose(Input_fileID);


% calculate the cut off frequencies
low_co = (input_data(2) * 6);
high_co = (input_data(3) * 6);


% generate filter in State-space representation
[b,a] = butter(1, [low_co, high_co], 's');
Hc = tf(b,a);
Hd=c2d(Hc,Ts_high);
[num,den] = tfdata(Hd);
[A,B,C,D] = tf2ss(num,den);

% open shared buffer
fileID = fopen('../tmp/shared_buffer.txt','w');


% write coefficients (binary representation) to shared buffer ...

ui = typecast(A(1,1), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(A(1,2), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(B(1), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(A(2,1), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(A(2,2), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(B(2), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(C(1), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);

ui = typecast(C(2), 'uint64');
ui_hex = dec2hex (ui, 16);
output = switch_bytes(ui_hex);
fprintf(fileID, output);


% close the shared buffer and octave
fclose(fileID);
exit
