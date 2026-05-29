%% Parameters
Fs = 44100;        % Sampling frequency
T = 2;             % Duration in seconds
f = 100;           % Waveform frequency in Hz (square wave)
r = 1.1;           % Resonance: 0 < r <= 1
f_c = 100;        % Desired cutoff frequency in Hz

% Moog Filter Parameters
V_t = 26e-3;       % Thermal voltage
C   = 1e-12;       % Capacitance
k   = 2 * pi * f_c / Fs;       % Normalized coefficient
I_ctl = k * C * Fs;            % Control current based on cutoff

%% Time and input signal
t = linspace(0, T, Fs*T);
x = square(2 * pi * f * t);    % Input square wave
N = length(x);

%% Initialize filter state
y_a = zeros(N, 1);
y_b = zeros(N, 1);
y_c = zeros(N, 1);
y_d = zeros(N, 1);
W_a = zeros(N, 1);
W_b = zeros(N, 1);
W_c = zeros(N, 1);

%% Filter loop
for n = 2:N
    y_a(n) = y_a(n-1) + k * (tanh((x(n) - 4*r*y_d(n-1)) / (2*V_t)) - W_a(n-1));
    W_a(n) = tanh(y_a(n) / (2*V_t));

    y_b(n) = y_b(n-1) + k * (W_a(n) - W_b(n-1));
    W_b(n) = tanh(y_b(n) / (2*V_t));

    y_c(n) = y_c(n-1) + k * (W_b(n) - W_c(n-1));
    W_c(n) = tanh(y_c(n) / (2*V_t));

    y_d(n) = y_d(n-1) + k * (W_c(n) - tanh(y_d(n-1) / (2*V_t)));
end

%% Output
y_out = y_d;
y_out = y_out / max(abs(y_out));  % Normalize to avoid clipping

%% Play the non-filtered audio
soundsc(x, Fs)

pause(length(x)/Fs + 0.5);  % Wait for audio duration + a little extra time

%% Play the filtered audio
soundsc(y_out, Fs);

%% Optional: Save to file
audiowrite('filtered_square_wave.wav', y_out, Fs);

%% Plot for visualization
figure;
subplot(3,1,1); plot(t, x); title('Input Square Wave'); grid on;
subplot(3,1,2); plot(t, y_out); title('Filtered Output (y_d)'); grid on;
subplot(3,1,3); spectrogram(y_out, 512, 256, 512, Fs, 'yaxis'); title('Spectrogram');
