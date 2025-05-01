// (c) Stefan Dangl (dangl.stefan@gmx.at)
// Project: Dynamic configuration Platforms for digital noise filtering of signals
// This code represents a simple noise detection based on FFT. Depending on the frequency spectrum
// cut-off frequencies of a bandpass filter are computed and outputted via serial interface.

#include <Audio.h>
#include <Wire.h>
#include <SPI.h>
#include <SD.h>
#include <SerialFlash.h>

const int myInput = AUDIO_INPUT_LINEIN;

int server_state = 0;

// Create the Audio components.
AudioInputI2S audioInput; // audio shield: mic or line-in
AudioAnalyzeFFT1024 myFFT;
AudioOutputI2S audioOutput; // audio shield: headphones & line-out
AudioConnection patchCord1(audioInput, 0, myFFT, 0);

AudioControlSGTL5000 audioShield;

void setup()
{
  // Enable the audio shield and set the output volume.
  AudioMemory(12);
  audioShield.enable();
  audioShield.inputSelect(myInput);
  audioShield.volume(0.5);

  // Configure the window algorithm to use
  myFFT.windowFunction(AudioWindowHanning1024);
}

void loop()
{
  float avrg;
  float lower_avrg;
  float higher_avrg;

  int lower_cofs;
  int higher_cofs;

  if (myFFT.available()) // new FFT data available?
  {
    avrg = calc_avrg();

    lower_cofs = calc_lower_cofs(avrg); // cofs = cut off frequency step
    higher_cofs = calc_higher_cofs(avrg);

    lower_avrg = calc_lower_sum(lower_cofs);
    higher_avrg = calc_higher_sum(higher_cofs);

    if (Serial.available()) // Check for a request by the server
    {
      server_state = Serial.read();
    }

    // If the Server sends a request, start sending the filter informations.
    if (server_state == 10)
    {
      Serial.print(avrg);
      Serial.print(" ");
      Serial.print((lower_cofs - lower_cofs / 2) * 43);
      Serial.print(" ");
      Serial.print((higher_cofs + higher_cofs) * 43);
      Serial.print(" ");
      Serial.print(lower_avrg);
      Serial.print(" ");
      Serial.print(higher_avrg);
      Serial.println();
      Serial.write(0x1a);
    }
  }
}

// calculates the average of the fft values. Only consider values greater 0
float calc_avrg()
{
  float n;
  float fft_sum = 0.0;
  int frequ_steps_higher_zero = 0;

  for (int i = 0; i < 512; i++) // frequency steps 0Hz to 22kHz
  {
    n = myFFT.read(i) * 3;
    if (n >= 0.01)
    {
      fft_sum += n;
      frequ_steps_higher_zero++;
    }
  }
  return fft_sum / frequ_steps_higher_zero;
}

// calculate the lower cut off frequency of the later builded band pass
int calc_lower_cofs(float avrg)
{
  float n;

  for (int i = 0; i < 512; i++)
  {
    n = myFFT.read(i) * 3;
    if (n >= avrg)
    {
      return i;
    }
  }
  return 0;
}

// calculate the higher cut off frequency of the later builded band pass
int calc_higher_cofs(float avrg)
{
  float n;

  for (int i = 511; i >= 0; i--)
  {
    n = myFFT.read(i) * 3;
    if (n >= avrg)
    {
      return i;
    }
  }
  return 0;
}

// calculate the avrg of the lower frequency area
float calc_lower_sum(int lower_cofs)
{
  float n;
  float fft_sum = 0.0;
  int frequ_steps_higher_zero = 0;

  for (int i = 0; i < lower_cofs; i++)
  {
    n = myFFT.read(i) * 3;
    if (n >= 0.01)
    {
      fft_sum += n;
      frequ_steps_higher_zero++;
    }
  }
  return fft_sum / frequ_steps_higher_zero;
}

// calculate the avrg of the higher frequency area
float calc_higher_sum(int higher_cofs)
{
  float n;
  float fft_sum = 0.0;
  int frequ_steps_higher_zero = 0;

  for (int i = 511; i > higher_cofs; i--)
  {
    n = myFFT.read(i) * 3;
    if (n >= 0.01)
    {
      fft_sum += n;
      frequ_steps_higher_zero++;
    }
  }
  return fft_sum / frequ_steps_higher_zero;
}
