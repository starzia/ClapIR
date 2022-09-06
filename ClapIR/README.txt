Differences with paper signal processing:
In ClapRecorder.m we are using a higher clap detection threshold than 100x (40dB) over the energy of the background level (where background is defined as the minimum).
We also save a background level spectrum and apply a 10x (20dB) minimum threshold for each frequency band.
