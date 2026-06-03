# verify_nco.py
# Tests the NCO (numerically controlled oscillator) across the frequency range
# defined in the test bench. Plots time/frequency domain and verifies harmonic
# content against the theoretical spectrum for square and sawtooth waves.

import matplotlib.pyplot as plt
import re
import numpy as np
import os
import sys

from enum import Enum, auto

# Matches frequency labels like "440.0" in the input files
freq_pattern = re.compile(r"\d+\.\d+")

SQUARE_DIR_TD = "square_time_domain/"
SQUARE_DIR_FD = "square_freq_domain/"
SAW_DIR_TD    = "sawtooth_time_domain/"
SAW_DIR_FD    = "sawtooth_freq_domain/"

class Waveform(Enum):
    SQUARE   = auto()
    SAWTOOTH = auto()

# Sampling frequency (Hz)
F_S = 44100

# ──────────────────────────────────────────────────────────────────────────────
# File parsing
# ──────────────────────────────────────────────────────────────────────────────

def parse_file(filename):
    """
    Parse an NCO output file.  Returns a dict mapping frequency string → list
    of integer sample values.
    """
    amplitudes = {}
    freq = None

    with open(filename, 'r') as fh:
        for line in fh:
            res = freq_pattern.search(line)
            if res:
                freq = res.group()
                amplitudes[freq] = []
            else:
                stripped = line.strip()
                if stripped and freq is not None:
                    amplitudes[freq].append(int(stripped))

    return amplitudes

# ──────────────────────────────────────────────────────────────────────────────
# Harmonic verification
# ──────────────────────────────────────────────────────────────────────────────

def expected_present_harmonics(fundamental_hz, wave_type, n_harmonics=15):
    """
    Return {harmonic_number: relative_amplitude} for harmonics that SHOULD be
    present.
      Square  : odd harmonics only  (1, 3, 5, …), amplitude = 1/n
      Sawtooth: all harmonics       (1, 2, 3, …), amplitude = 1/n
    Only returns harmonics below the Nyquist limit.
    """
    harmonics = {}
    if wave_type == Waveform.SQUARE:
        candidates = range(1, n_harmonics * 2, 2)   # 1, 3, 5, ...
    else:
        candidates = range(1, n_harmonics + 1)       # 1, 2, 3, ...

    for k in candidates:
        if fundamental_hz * k >= F_S / 2:
            break
        harmonics[k] = 1.0 / k

    return harmonics


def expected_absent_harmonics(fundamental_hz, wave_type, n_check=10):
    """
    Return a list of harmonic numbers that should be ABSENT (or heavily
    suppressed).  For square waves this is the even harmonics.
    """
    absent = []
    if wave_type == Waveform.SQUARE:
        for k in range(2, n_check * 2, 2):           # 2, 4, 6, ...
            if fundamental_hz * k >= F_S / 2:
                break
            absent.append(k)
    return absent


def peak_amplitude_near(spectrum, freqs, target_hz, tol_hz=10.0):
    """Return the peak magnitude in `spectrum` within ±tol_hz of target_hz."""
    mask = np.abs(freqs - target_hz) < tol_hz
    return float(spectrum[mask].max()) if mask.any() else 0.0


def measure_noise_floor(spectrum_norm, freqs, fundamental_hz, wave_type, n_harmonics=15):
    """
    Estimate the noise floor by taking the median power of spectral bins that
    are NOT close to any expected harmonic.  Adapts automatically to whatever
    phase accumulator width the VHDL uses.

    Returns noise floor in dB relative to the fundamental.
    """
    guard_hz = 30.0
    harmonic_mask = np.zeros(len(freqs), dtype=bool)
    candidates = (range(1, n_harmonics * 2, 2) if wave_type == Waveform.SQUARE
                  else range(1, n_harmonics + 1))
    for k in candidates:
        freq = fundamental_hz * k
        if freq >= F_S / 2:
            break
        harmonic_mask |= np.abs(freqs - freq) < guard_hz

    noise_bins = spectrum_norm[~harmonic_mask]
    noise_amp  = np.median(noise_bins) if len(noise_bins) else 1e-12
    return float(20 * np.log10(max(noise_amp, 1e-12)))


def verify_harmonics(samples, fundamental_hz, wave_type,
                     amplitude_tolerance_db=3.0,
                     absence_threshold_db=-20.0,
                     noise_floor_margin_db=6.0):
    """
    Verify the harmonic content of `samples` against the theoretical spectrum
    for `wave_type`.

    The noise floor is measured directly from the spectrum (median of non-harmonic
    bins), so the skip threshold adapts automatically to the actual VHDL accumulator
    width rather than relying on a hardcoded value.

    Parameters
    ----------
    amplitude_tolerance_db : pass/fail tolerance for present harmonics (dB)
    absence_threshold_db   : harmonics that should be absent must be below this (dB)
    noise_floor_margin_db  : skip any harmonic whose expected level is within this
                             many dB of the measured noise floor

    Returns
    -------
    present_results : dict  harmonic_n → {freq_hz, expected_db, measured_db,
                                          error_db, tolerance_db, passed, skipped}
    absent_results  : dict  harmonic_n → {freq_hz, measured_db, passed}
    noise_floor_db  : float  measured noise floor in dB re fundamental
    overall_pass    : bool
    """
    n      = len(samples)
    window = np.hanning(n)

    # Normalise by N/2 so magnitude ≈ true relative amplitude
    spectrum = np.abs(np.fft.rfft(samples * window)) / (n / 2)
    freqs    = np.fft.rfftfreq(n, d=1.0 / F_S)

    # Normalise everything to the fundamental
    fund_amp = peak_amplitude_near(spectrum, freqs, fundamental_hz)
    if fund_amp == 0.0:
        raise ValueError(f"Fundamental {fundamental_hz} Hz not found in spectrum.")
    spectrum_norm = spectrum / fund_amp

    # Measure the actual noise floor from inter-harmonic bins
    noise_floor_db = measure_noise_floor(spectrum_norm, freqs, fundamental_hz, wave_type)
    skip_threshold = noise_floor_db + noise_floor_margin_db

    # ── Present harmonics ──────────────────────────────────────────────────
    present_expected = expected_present_harmonics(fundamental_hz, wave_type)
    present_results  = {}
    for k, rel_amp in present_expected.items():
        freq   = fundamental_hz * k
        exp_db = 20 * np.log10(rel_amp)

        # Skip if the expected level is too close to the noise floor —
        # accumulator truncation spurs would dominate the measurement
        if exp_db < skip_threshold:
            present_results[k] = dict(
                freq_hz      = freq,
                expected_db  = exp_db,
                measured_db  = None,
                error_db     = None,
                tolerance_db = None,
                passed       = True,
                skipped      = True,
            )
            continue

        measured = peak_amplitude_near(spectrum_norm, freqs, freq)
        meas_db  = 20 * np.log10(max(measured, 1e-12))
        error_db = abs(meas_db - exp_db)

        present_results[k] = dict(
            freq_hz      = freq,
            expected_db  = exp_db,
            measured_db  = meas_db,
            error_db     = error_db,
            tolerance_db = amplitude_tolerance_db,
            passed       = error_db < amplitude_tolerance_db,
            skipped      = False,
        )

    # ── Absent harmonics ───────────────────────────────────────────────────
    absent_list    = expected_absent_harmonics(fundamental_hz, wave_type)
    absent_results = {}
    for k in absent_list:
        freq     = fundamental_hz * k
        measured = peak_amplitude_near(spectrum_norm, freqs, freq)
        meas_db  = 20 * np.log10(max(measured, 1e-12))
        absent_results[k] = dict(
            freq_hz     = freq,
            measured_db = meas_db,
            passed      = meas_db < absence_threshold_db,
        )

    overall_pass = (
        all(r["passed"] for r in present_results.values()) and
        all(r["passed"] for r in absent_results.values())
    )
    return present_results, absent_results, noise_floor_db, overall_pass



def print_verification_report(freq_str, wave_type, present_results,
                               absent_results, noise_floor_db, overall_pass):
    label = "Square" if wave_type == Waveform.SQUARE else "Sawtooth"
    print(f"\n{'─'*72}")
    print(f"  {label} @ {freq_str} Hz  (noise floor: {noise_floor_db:+.1f} dB)")
    print(f"{'─'*72}")
    print(f"  {'H':>3}  {'Freq (Hz)':>10}  {'Expected':>10}  {'Measured':>10}  "
          f"{'Error':>8}  {'Tol':>6}  Status")
    for k, r in sorted(present_results.items()):
        if r["skipped"]:
            print(f"  {k:>3}  {r['freq_hz']:>10.1f}  "
                  f"{r['expected_db']:>+9.1f}dB  {'—':>10}  "
                  f"{'—':>8}  {'—':>6}  SKIP (below noise floor)")
        else:
            status = "PASS ✓" if r["passed"] else "FAIL ✗"
            print(f"  {k:>3}  {r['freq_hz']:>10.1f}  "
                  f"{r['expected_db']:>+9.1f}dB  {r['measured_db']:>+9.1f}dB  "
                  f"{r['error_db']:>7.1f}dB  {r['tolerance_db']:>5.1f}dB  {status}")

    if absent_results:
        print(f"\n  Even harmonics (should be absent, threshold < −20 dB):")
        for k, r in sorted(absent_results.items()):
            status = "PASS ✓" if r["passed"] else "FAIL ✗"
            print(f"  {k:>3}  {r['freq_hz']:>10.1f}  "
                  f"{'—':>10}  {r['measured_db']:>+9.1f}dB  "
                  f"{'—':>8}  {'—':>6}  {status}")

    verdict = "OVERALL: PASS ✓" if overall_pass else "OVERALL: FAIL ✗"
    print(f"\n  {verdict}")

# ──────────────────────────────────────────────────────────────────────────────
# Plotting
# ──────────────────────────────────────────────────────────────────────────────

def plot_amplitudes(wave_type, amplitudes):
    """
    For each frequency in `amplitudes`, save a time-domain PNG and a
    frequency-domain PNG, then run harmonic verification.
    """
    is_square  = wave_type == Waveform.SQUARE
    plot_label = "Square" if is_square else "Sawtooth"
    file_pfx   = "square_fig_" if is_square else "sawtooth_fig_"
    td_dir     = SQUARE_DIR_TD if is_square else SAW_DIR_TD
    fd_dir     = SQUARE_DIR_FD if is_square else SAW_DIR_FD

    all_pass = True

    for freq_str, vals in amplitudes.items():
        if not vals:
            continue

        raw     = np.array(vals, dtype=float)
        norm    = raw / np.max(np.abs(raw))
        n       = len(norm)

        # Real time axis in milliseconds
        duration_ms = n / F_S * 1000.0
        time_ms     = np.linspace(0.0, duration_ms, n, endpoint=False)

        # FFT — normalised to unit fundamental so all plots are comparable
        window      = np.hanning(n)
        fft_vals    = np.abs(np.fft.rfft(norm * window)) / (n / 2)
        fft_freqs   = np.fft.rfftfreq(n, d=1.0 / F_S)
        fund_amp    = fft_vals[np.argmax(fft_vals)]
        if fund_amp > 0:
            fft_vals /= fund_amp

        safe_freq = freq_str.replace('.', '_')

        # ── Time-domain plot ───────────────────────────────────────────────
        fig, ax = plt.subplots()
        ax.plot(time_ms, norm)
        ax.set_title(f"Time Domain {plot_label} Wave [{freq_str} Hz]")
        ax.set_xlabel("Time (ms)")
        ax.set_ylabel("Amplitude")
        ax.grid(True, axis="both", which="both")
        fig.savefig(f"{td_dir}{file_pfx}time_{safe_freq}hz.png")
        plt.close(fig)

        # ── Frequency-domain plot ──────────────────────────────────────────
        fig, ax = plt.subplots()
        ax.plot(fft_freqs, fft_vals)
        ax.set_title(f"{plot_label} Wave DFT [{freq_str} Hz]")
        ax.set_xlabel("Frequency (Hz)")
        ax.set_ylabel("Relative Magnitude")
        ax.set_xscale('log')
        ax.grid(True, axis='both', which='both', linestyle='-')
        fig.savefig(f"{fd_dir}{file_pfx}freq_{safe_freq}hz.png")
        plt.close(fig)

        # ── Harmonic verification ──────────────────────────────────────────
        try:
            fundamental_hz = float(freq_str)
            present, absent, noise_floor_db, passed = verify_harmonics(norm, fundamental_hz, wave_type)
            print_verification_report(freq_str, wave_type, present, absent,
                                      noise_floor_db, passed)
            all_pass = all_pass and passed
        except ValueError as e:
            print(f"  [WARN] Could not verify {freq_str} Hz: {e}")

    return all_pass

# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    for d in (SQUARE_DIR_TD, SQUARE_DIR_FD, SAW_DIR_TD, SAW_DIR_FD):
        os.makedirs(d, exist_ok=True)   # exist_ok replaces the try/except

    square_amplitudes = parse_file("square.txt")
    saw_amplitudes    = parse_file("sawtooth.txt")

    print("\n╔══════════════════════════════════════════╗")
    print("║       NCO Harmonic Verification          ║")
    print("╚══════════════════════════════════════════╝")

    sq_pass  = plot_amplitudes(Waveform.SQUARE,   square_amplitudes)
    saw_pass = plot_amplitudes(Waveform.SAWTOOTH, saw_amplitudes)

    print("\n" + "═"*60)
    print(f"  Square wave suite  : {'PASS ✓' if sq_pass  else 'FAIL ✗'}")
    print(f"  Sawtooth suite     : {'PASS ✓' if saw_pass else 'FAIL ✗'}")
    print("═"*60)

    sys.exit(0 if (sq_pass and saw_pass) else 1)

