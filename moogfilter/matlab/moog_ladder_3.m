% Moog Ladder filter (Huovilainen 2004) implementation


% The notes for the C major scale are C, D, E, F, G, A, B, C
C_major_midi_notes = [60, 62, 64, 65, 67, 69, 71, 72];

C_major_asc_desc = [C_major_midi_notes, fliplr(C_major_midi_notes(1:end-1))];


F_s = 44100; % Sampling frequency (44.1 kHz)
T   = 0.5;

% ADSR (Attack Decay Sustain Release) Envelope generation. 
attack_time   = 0.1;    % Attack duration (s)
decay_time    = 0.3;    % Decay duration (s)
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
N = length(adsr_env)

f_base = 50;


f_c_min = 200;    % Minimum cutoff frequency
f_c_max = 5000;   % Maximum cutoff frequency

% Cutoff frequency as a function of time.
f_c_t = f_c_min + adsr_env * (f_c_max - f_c_min);

%% Parameters

f = 100; % Note frequency
r = 0.7; % Resonance (0 < r <= 1 for normal, >= 1 for self-oscillation)

V_t = 26e-3; % Thermal voltage
C   = 1e-12; % Capacitance

% Initialize arrays for k and I_ctl per sample
k_t = 2 * pi .* f_c_t / F_s;
I_ctl_t = k_t * C * F_s;

t = linspace(0, T, F_s*T);
x = square(2 * pi * f * t);
N = length(x);

y_a = zeros(N, 1);
y_b = zeros(N, 1);
y_c = zeros(N, 1);
y_d = zeros(N, 1);
W_a = zeros(N, 1);
W_b = zeros(N, 1);
W_c = zeros(N, 1);

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

%% Output
y_out = y_d;
y_out = y_out / max(abs(y_out));  % Normalize to avoid clipping

%% Play the non-filtered audio

rms_x = sqrt(mean(x .^ 2));

target_rms = 0.5;
rms_y = sqrt(mean(y_out .^ 2));


x_norm = x * (0.4);
sound(x_norm, F_s)

pause(length(x)/F_s + 0.5);  % Wait for audio duration + a little extra time

%% Play the filtered audio

y_out_norm = y_out * (1.0 / rms_x);
soundsc(y_out_norm, F_s);

%% Optional: Save to file
% audiowrite('filtered_square_wave.wav', y_out, F_s);

%% Plot for visualization
figure;
subplot(3,1,1); plot(t, x); title('Input Square Wave'); grid on;
subplot(3,1,2); plot(t, y_out); title('Filtered Output (y_d)'); grid on;
subplot(3,1,3); spectrogram(y_out, 512, 256, 512, F_s, 'yaxis'); title('Spectrogram');


function f = midi_to_f(midi_note)
    f = 440 * 2.0 ^ ((midi_note - 69) / 12);
end

function f_c = keytracked_cutoff(midi_note, f_base, k)
    % Computes cutoff frequency with key tracking
    f_c = f_base * 2.^((k * (midi_note - 60))/12);
end
