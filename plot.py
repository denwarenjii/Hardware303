import matplotlib.pyplot as plt
import numpy as np

if __name__ == "__main__":

    Fs = 44100

    square_amplitudes = []
    sawtooth_amplitudes = []

    with open("square.txt", 'r') as file:
        for line in file:
            square_amplitudes.append(int(line.strip()))

    with open("sawtooth.txt", 'r') as file:
        for line in file:
            sawtooth_amplitudes.append(int(line.strip()))
     
    # Normalize the amplitudes to 1.
    square_amplitudes = np.array(square_amplitudes) / np.max(np.abs(square_amplitudes))
    sawtooth_amplitudes = np.array(sawtooth_amplitudes) / np.max(np.abs(sawtooth_amplitudes))

    # Time array in ms.
    square_time = np.linspace(0, 100, len(square_amplitudes))
    sawtooth_time = np.linspace(0, 100, len(sawtooth_amplitudes))

    
    # FFT values. Note that these are only amplitudes (we need to generate the frequency axis
    # by ourselves). Also note that we use rfft to get only positive frequency values.
    square_fft_vals = np.abs(np.fft.rfft(square_amplitudes)) / np.max(np.abs(square_amplitudes))
    sawtooth_fft_vals = np.abs(np.fft.rfft(sawtooth_amplitudes)) / np.max(np.abs(sawtooth_amplitudes))
    
    # FFT frequency bins.
    square_fft_freqs = np.fft.rfftfreq(len(square_time), 1/Fs)
    sawtooth_fft_freqs = np.fft.rfftfreq(len(sawtooth_time), 1/Fs)
    
    # Figure 1 - Time domain square wave.
    plt.plot(square_time, square_amplitudes)
    plt.title("Time Domain Square Wave")
    plt.xlabel("Time (ms)")
    plt.ylabel("Amplitude")
    plt.grid(True, axis="both", which="both")
    plt.figure()

    # Figure 2 - Time domain sawtooth.
    plt.plot(sawtooth_time, sawtooth_amplitudes)
    plt.title("Time Domain Sawtooth Wave")
    plt.xlabel("Time (ms)")
    plt.ylabel("Amplitude")
    plt.grid(True, axis="both", which="both")
    plt.figure()

    # Figure 3 - Square wave FFT.
    plt.plot(square_fft_freqs, square_fft_vals)
    plt.title("Square Wave Discrete Fourier Transform")
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude")
    plt.xscale('log')
    plt.grid(True, axis='both', which='both', linestyle='-')
    plt.figure()

    # Figure 4 - Sawtooth wave FFT.
    plt.plot(sawtooth_fft_freqs, sawtooth_fft_vals)
    plt.title("Sawtooth Wave Discrete Fourier Transform")
    plt.xlabel("Frequency (Hz)")
    plt.ylabel("Magnitude")
    plt.xscale('log')
    plt.grid(True, axis='both', which='both', linestyle='-')


    plt.show()
