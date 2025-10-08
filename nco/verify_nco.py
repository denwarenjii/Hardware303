import matplotlib.pyplot as plt
import re
import numpy as np
import os

# Compiled regex objects are faster
# https://docs.python.org/3/library/re.html#re.compile
#
# Regex pattern to search for 'number.number'
# r for raw-mode to get rid of double-escapes
# \d+ matches any number once or more
# \. matches .
pattern = re.compile(r"\d+\.\d+")

SQUARE_DIR_TD = "square_time_domain/"
SQUARE_DIR_FD = "square_freq_domain/"

SAW_DIR_TD = "sawtooth_time_domain/"
SAW_DIR_FD = "sawtooth_freq_domain/"

if __name__ == "__main__":

    try:
        os.mkdir(SQUARE_DIR_TD, mode=0o777);
        os.mkdir(SQUARE_DIR_FD, mode=0o777);

        os.mkdir(SAW_DIR_TD, mode=0o777);
        os.mkdir(SAW_DIR_FD, mode=0o777);

    except FileExistsError:
        # Do nothing if the directories already exist
        pass

    Fs = 44100

    # int -> list of int dictionaries mapping frequencies being tested to their time
    # domain values
    square_amplitudes = {}
    sawtooth_amplitudes = {}

    with open("square.txt", 'r') as file:
        # The current frequency entry being parsed
        freq = 0
        for line in file:
            # Search for the frequency being tested. This indicates that a new
            # frequency is being tested
            res = pattern.search(line)

            if res:
                # Get the match of the regex pattern
                freq = res.group()
                # Initialize the frequency's time domain entry to the empty list
                square_amplitudes[freq] = []
            else:
                # Strip leading and trailing whitespace and convert to int
                stripped_line = line.strip()
                sample = int(stripped_line if stripped_line != "" else "0")
                square_amplitudes[freq].append(sample)

        # Plot the waveform in the time and frequency domain once they've all
        # been processed


    with open("sawtooth.txt", 'r') as file:
        # The current frequency entry being parsed
        freq = 0
        for line in file:
            # Search for the frequency being tested. This indicates that a new
            # frequency is being tested
            res = pattern.search(line)

            if res:
                # Get the match of the regex pattern
                freq = res.group()
                # Initialize the frequency's time domain entry to the empty list
                sawtooth_amplitudes[freq] = []
            else:
                # Strip leading and trailing whitespace and convert to int
                stripped_line = line.strip()
                sample = int(stripped_line if stripped_line != "" else "0")
                sawtooth_amplitudes[freq].append(sample)


    for freq, vals in square_amplitudes.items():
        # Normalize the amplitudes to 1.
        square_amplitudes = np.array(vals) / np.max(np.abs(vals))

        # Time array in ms.
        square_time = np.linspace(0, 100, len(square_amplitudes))
        
        # FFT values. Note that these are only amplitudes (we need to generate the frequency axis
        # by ourselves). Also note that we use rfft to get only positive frequency values.
        square_fft_vals = np.abs(np.fft.rfft(square_amplitudes)) / np.max(np.abs(square_amplitudes))
        
        # FFT frequency bins.
        square_fft_freqs = np.fft.rfftfreq(len(square_time), 1/Fs)
        
        # Figure 1 - Time domain square wave.
        plt.figure()
        plt.plot(square_time, square_amplitudes)
        plt.title("Time Domain Square Wave [" + str(freq) + " Hz]")
        plt.xlabel("Time (ms)")
        plt.ylabel("Amplitude")
        plt.grid(True, axis="both", which="both")
        plt.savefig(SQUARE_DIR_TD + "square_fig_time_" + str.replace(freq, '.', '_') + "hz.png")
        
        plt.close()

        # Figure 2 - Square wave FFT.
        plt.figure()
        plt.plot(square_fft_freqs, square_fft_vals)
        plt.title("Square Wave Discrete Fourier Transform [" + str(freq) + " Hz]")
        plt.xlabel("Frequency (Hz)")
        plt.ylabel("Magnitude")
        plt.xscale('log')
        plt.grid(True, axis='both', which='both', linestyle='-')

        plt.savefig(SQUARE_DIR_FD + "square_fig_freq_" + str.replace(freq, '.', '_') + "hz.png")

        plt.close()

    # first_kv = next(iter(square_amplitudes.items()))
    # print(f"first (key,value) pair in square_amplitudes")
    # print(first_kv)
    #
    # first_kv = next(iter(sawtooth_amplitudes.items()))
    # print(f"first (key,value) pair in square_amplitudes")
    # print(first_kv)
