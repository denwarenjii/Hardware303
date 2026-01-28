import matplotlib.pyplot as plt
import re
import numpy as np
import os

from enum import Enum, auto

# Regex pattern to search for 'number.number'
# r for raw-mode to get rid of double-escapes
# \d+ matches any number once or more
# \. matches .
#
# Compiled regex objects are faster
# https://docs.python.org/3/library/re.html#re.compile
#
freq_pattern = re.compile(r"\d+\.\d+")

SQUARE_DIR_TD = "square_time_domain/"
SQUARE_DIR_FD = "square_freq_domain/"

SAW_DIR_TD = "sawtooth_time_domain/"
SAW_DIR_FD = "sawtooth_freq_domain/"

class Waveform(Enum):
    SQUARE = auto()
    SAWTOOTH = auto()

# Sampling frequency
F_S = 44100

def parse_file(filename):
    amplitudes = {}

    with open(filename, 'r') as file:
        # The current frequency entry being parsed
        freq = 0

        for line in file:
            res = freq_pattern.search(line)

            if res:
                freq = res.group()
                amplitudes[freq] = []
            else:
                stripped_line = line.strip()
                sample = int(stripped_line) if stripped_line != "" else 0
                amplitudes[freq].append(sample)

    return amplitudes

def plot_amplitudes(type, amplitudes):
    for freq, vals in amplitudes.items():
        norm_amplitudes = np.array(vals) / np.max(np.abs(vals))
        time = np.linspace(0, 100, len(norm_amplitudes))

        fft_vals = np.abs(np.fft.rfft(norm_amplitudes)) / np.max(np.abs(norm_amplitudes))
        fft_freqs = np.fft.rfftfreq(len(time), 1/F_S)

        plot_name = "Square" if type == Waveform.SQUARE else "Sawtooth"
        file_name = "square_fig_" if type == Waveform.SQUARE else "sawtooth_fig_"
        dir_prefix = SQUARE_DIR_TD if type == Waveform.SQUARE else SAW_DIR_TD

        # Time domain plot
        plt.figure()
        plt.plot(time, norm_amplitudes)
        plt.title(f"Time Domain {plot_name} Wave [" + str(freq) + " Hz]")
        plt.xlabel("Time (ms)")
        plt.ylabel("Amplitude")
        plt.grid(True, axis="both", which="both")

        plt.savefig(dir_prefix + file_name + "time_" + str.replace(freq, '.', '_') + "hz.png")
     
        plt.close()

        # Frequency domain plot
        plt.plot(fft_freqs, fft_vals)
        plt.title(f"{plot_name} Wave Discrete Fourier Transform")
        plt.xlabel("Frequency (Hz)")
        plt.ylabel("Magnitude")
        plt.xscale('log')
        plt.grid(True, axis='both', which='both', linestyle='-')
        plt.figure()

        plt.savefig(dir_prefix + file_name + "freq_" + str.replace(freq, '.', '_') + "hz.png")

        plt.close()

def plot_amplitudes_freq_domain(type, amplitudes):
    # FFT values. Note that these are only amplitudes (we need to generate the frequency axis
    # by ourselves). Also note that we use rfft to get only positive frequency values.
    square_fft_vals = np.abs(np.fft.rfft(square_amplitudes)) / np.max(np.abs(square_amplitudes))
    sawtooth_fft_vals = np.abs(np.fft.rfft(sawtooth_amplitudes)) / np.max(np.abs(sawtooth_amplitudes))
    
    # FFT frequency bins.
    square_fft_freqs = np.fft.rfftfreq(len(square_time), 1/F_S)
    sawtooth_fft_freqs = np.fft.rfftfreq(len(sawtooth_time), 1/F_S)


if __name__ == "__main__":

    try:
        os.mkdir(SQUARE_DIR_TD, mode=0o777);
        os.mkdir(SQUARE_DIR_FD, mode=0o777);

        os.mkdir(SAW_DIR_TD, mode=0o777);
        os.mkdir(SAW_DIR_FD, mode=0o777);

    except FileExistsError:
        # Do nothing if the directories already exist
        pass

    square_amplitudes = parse_file("square.txt")
    saw_amplitudes = parse_file("sawtooth.txt")

    plot_amplitudes(Waveform.SQUARE, square_amplitudes)
    plot_amplitudes(Waveform.SAWTOOTH, saw_amplitudes)
