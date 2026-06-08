% Parameters
Fs   = 44.1e3;      % Sampling frequency (44.1 kHz)
C    = 1e-12;       % Capacitance (1 pF)
Ictl = 10e-6;       % Control current (1 uA)
Vt   = 26e-3;       % Thermal voltage (26 mV)
r    = 0.7;         % Resonance factor (0 < r <= 1)


% Time and input signal
N = 500;                  % Number of samples
t = (0:N-1)/Fs;           % Time vector
x = sin(2*pi*1e2*t);      % Input: 100 Hz sine wave

% Initialize state arrays
ya = zeros(1, N);
yb = zeros(1, N);
yc = zeros(1, N);
yd = zeros(1, N);
Wa = zeros(1, N);
Wb = zeros(1, N);
Wc = zeros(1, N);

% Precompute integration constant
k = Ictl / (C * Fs);

% Simulation loop
for n = 2:N
    % Calculate input nonlinear term
    input_nl = tanh((x(n) - 4*r*yd(n-1)) / (2*Vt));

    % Stage a
    ya(n) = ya(n-1) + k * (input_nl - Wa(n-1));
    Wa(n) = tanh(ya(n) / (2*Vt));

    % Stage b
    yb(n) = yb(n-1) + k * (Wa(n) - Wb(n-1));
    Wb(n) = tanh(yb(n) / (2*Vt));

    % Stage c
    yc(n) = yc(n-1) + k * (Wb(n) - Wc(n-1));
    Wc(n) = tanh(yc(n) / (2*Vt));

    % Stage d
    yd(n) = yd(n-1) + k * (Wc(n) - tanh(yd(n-1)/(2*Vt)));
end


% Plotting
figure;
subplot(5,1,1); plot(t, ya); title('Stage y_a(n)'); grid on;
subplot(5,1,2); plot(t, yb); title('Stage y_b(n)'); grid on;
subplot(5,1,3); plot(t, yc); title('Stage y_c(n)'); grid on;
subplot(5,1,4); plot(t, yd); title('Stage y_d(n)'); grid on;
subplot(5,1,5); plot(t, x);  title('Input x(n)');  xlabel('Time (s)'); grid on;
