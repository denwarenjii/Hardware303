% Moog Ladder filter (Huovilainen 2004) implementation

% The notes for the C major scale are C, D, E, F, G, A, B, C
C_major_midi_notes = [60, 62, 64, 65, 67, 69, 71, 72];

C_major_asc_desc = [C_major_midi_notes, fliplr(C_major_midi_notes(1:end-1))];


F_s = 44100; % Sampling frequency (44.1 kHz)
T   = 0.5;

% ADSR (Attack Decay Sustain Release) Envelope generation. 
attack_time   = 0.1;    % Attack duration (s)
decay_time    = 0.25;    % Decay duration (s)
sustain_level = 0.3;    % Sustain level (0 to 1)
release_time  = 0.15;    % Release duration (s)



attack_samples  = round(F_s * attack_time);
decay_samples   = round(F_s * decay_time);
release_samples = round(F_s * release_time);
sustain_samples = round(F_s * (T - attack_time - decay_time - release_time));

% Make sure total samples add up correctly
total_samples = attack_samples + decay_samples + sustain_samples + release_samples;

attack_env  = linspace(0, 1, attack_samples);
decay_env   = linspace(1, sustain_level, decay_samples);
sustain_env = sustain_level * ones(1, sustain_samples);
release_env = linspace(sustain_level, 0, release_samples);

adsr_env = [attack_env, decay_env, sustain_env, release_env];

f_c_min = 50;    % Minimum cutoff frequency
f_c_max = 500;   % Maximum cutoff frequency

% Cutoff frequency as a function of time.
f_c_t = f_c_min + adsr_env * (f_c_max - f_c_min);

%% Parameters

% f = 100; % Note frequency


r = 2; % Resonance (0 < r <= 1 for normal, >= 1 for self-oscillation)

V_t = 26e-3; % Thermal voltage
C   = 1e-12; % Capacitance

% Initialize arrays for k and I_ctl per sample
k_t = 2 * pi .* f_c_t / F_s;
I_ctl_t = k_t * C * F_s;

t = linspace(0, T, F_s*T);
% x = square(2 * pi * f * t);
% N = length(x);
N = length(t);

y_a = zeros(N, 1);
y_b = zeros(N, 1);
y_c = zeros(N, 1);
y_d = zeros(N, 1);
W_a = zeros(N, 1);
W_b = zeros(N, 1);
W_c = zeros(N, 1);

y_s = zeros(length(C_major_asc_desc), N);


% for f_i = 1:length(C_major_asc_desc)
%     f = midi_to_f(C_major_asc_desc(f_i));
%     x = square(2 * pi * f * t);
%     x_norm = x * 0.4;
%     sound(x_norm, F_s);
%     pause(0.4);
% end

for f_i = 1:length(C_major_asc_desc)

    f = midi_to_f(C_major_asc_desc(f_i));
    x = square(2 * pi * f * t);

    for n = 2:N

        k = k_t(n);
        I_ctl = I_ctl_t(n);

        y_a(n) = y_a(n-1) + k * (tanh((x(n) - 4*r*y_d(n-1)) / (2*V_t)) - W_a(n-1));
        W_a(n) = tanh(y_a(n) / (2*V_t));

        y_b(n) = y_b(n-1) + k * (W_a(n) - W_b(n-1));
        W_b(n) = tanh(y_b(n) / (2*V_t));

        y_c(n) = y_c(n-1) + k * (W_b(n) - W_c(n-1));
        W_c(n) = tanh(y_c(n) / (2*V_t));

        y_d(n) = y_d(n-1) + k * (W_c(n) - tanh(y_d(n-1) / (2*V_t)));
    end

    y_out = y_d;

    y_s(f_i, :) = y_out;

    soundsc(y_out, F_s);
    pause(0.4);

end

% %% Output
% y_out = y_d;
% y_out = y_out / max(abs(y_out));  % Normalize to avoid clipping
% 
% %% Play the non-filtered audio
% 
% rms_x = sqrt(mean(x .^ 2));
% 
% target_rms = 0.5;
% rms_y = sqrt(mean(y_out .^ 2));
% 
% 
% x_norm = x * (0.4);
% sound(x_norm, F_s)
% 
% pause(length(x)/F_s + 0.5);  % Wait for audio duration + a little extra time
% 
% %% Play the filtered audio
% 
% y_out_norm = y_out * (1.0 / rms_x);
% soundsc(y_out_norm, F_s);
% 
% %% Optional: Save to file
% % audiowrite('filtered_square_wave.wav', y_out, F_s);
% 
% %% Plot for visualization
% figure;
% subplot(3,1,1); plot(t, x); title('Input Square Wave'); grid on;
% subplot(3,1,2); plot(t, y_out); title('Filtered Output (y_d)'); grid on;
% subplot(3,1,3); spectrogram(y_out, 512, 256, 512, F_s, 'yaxis'); title('Spectrogram');

% X_pos = X(1:floor(N/2)+1);            % Include DC and Nyquist if even N
% f_pos = (0:floor(N/2)) * (Fs / N);    % Frequency vector (Hz)

f = (0:floor(N/2)) * (F_s / N);     % Frequency vector (Hz)

y_s_1_dft = abs(fft(y_s(1, :)));
y_s_1_dft = y_s_1_dft(1:floor(N/2) + 1)

y_s_2_dft = abs(fft(y_s(2, :)));
y_s_2_dft = y_s_2_dft(1:floor(N/2) + 1)

y_s_3_dft = abs(fft(y_s(3, :)));
y_s_3_dft = y_s_3_dft(1:floor(N/2) + 1)

xlabel('Frequency (Hz)');
ylabel('|X(f)|');
title('DFT Magnitude Spectrum');

figure
subplot(3, 1, 1); plot(f, y_s_1_dft); title('A4 Filtered DFT'); xlabel('Frequency (Hz)'); ylabel('X(f)'); grid on;
subplot(3, 1, 2); plot(f, y_s_2_dft); title('B4 Filtered DFT'); xlabel('Frequency (Hz)'); ylabel('X(f)'); grid on;
subplot(3, 1, 3); plot(f, y_s_3_dft); title('B4 Filtered DFT'); xlabel('Frequency (Hz)'); ylabel('X(f)'); grid on;

function f = midi_to_f(midi_note)
    f = 440 * 2.0 ^ ((midi_note - 69) / 12);
end

function f_c = keytracked_cutoff(midi_note, f_base, k)
    % Computes cutoff frequency with key tracking
    f_c = f_base * 2.^((k * (midi_note - 60))/12);
end

function updateCursor(~, event, hCursor, player, t)
    currentSample = get(player, 'CurrentSample');
    currentTime = currentSample / player.SampleRate;
    set(hCursor, 'XData', [currentTime currentTime]);
    drawnow limitrate; % Avoid CPU overload
end
