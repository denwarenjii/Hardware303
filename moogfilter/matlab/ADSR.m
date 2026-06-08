%------------------------------------------------------------------------------
% ADSR.m
%
% 
%   Revision History:
%     ??/??/????   Chris M.   Initial revision.
% 
%  TODO:
%   - Add duty cycle input.


F_s = 44100; % Sampling frequency (44.1 kHz)
T   = 0.5;

% ADSR (Attack Decay Sustain Release) Envelope generation. 
attack_time   = 0.05;   % Attack duration (s)
decay_time    = 0.3;    % Decay duration (s)
sustain_level = 0.5;    % Sustain level (0 to 1)
release_time  = 0.15;   % Release duration (s)

attack_samples  = round(Fs * attack_time);
decay_samples   = round(Fs * decay_time);
release_samples = round(Fs * release_time);
sustain_samples = round(Fs * (T - attack_time - decay_time - release_time));

% Make sure total samples add up correctly
total_samples = attack_samples + decay_samples + sustain_samples + release_samples;

attack_env = linspace(0, 1, attack_samples);
decay_env = linspace(1, sustain_level, decay_samples);
sustain_env = sustain_level * ones(1, sustain_samples);
release_env = linspace(sustain_level, 0, release_samples);

adsr_env = [attack_env, decay_env, sustain_env, release_env];

% -------------------------------

% Parameters for cutoff modulation
f_c_min = 100;      % Min cutoff frequency (Hz)
f_c_max = 5000;     % Max cutoff frequency (Hz)

f_c_t = f_c_min + adsr_env * (f_c_max - f_c_min);

%% Parameters
Fs = 44100;        % Sampling frequency

f = 100;           % Waveform frequency in Hz (square wave)
r = 1.1;           % Resonance: 0 < r <= 1
% f_c = 100;         % Desired cutoff frequency in Hz

% Moog Filter Parameters
V_t = 26e-3;       % Thermal voltage
C   = 1e-12;       % Capacitance
% k   = 2 * pi * f_c / Fs;       % Normalized coefficient
% I_ctl = k * C * Fs;            % Control current based on cutoff



% Initialize arrays for k and I_ctl per sample
k_t = 2 * pi .* f_c_t / Fs;
I_ctl_t = k_t * C * Fs;


%% Time and input signal
t = linspace(0, T, Fs * T);
x = square(2 * pi * f * t);    % Input square wave
N = length(x);

figure;
plot(t, f_c_t, 'LineWidth', 1.5);
xlabel('Time (s)');
ylabel('Cutoff Frequency (Hz)');
title('Time-Varying Cutoff Frequency f_c(t)');
grid on;
