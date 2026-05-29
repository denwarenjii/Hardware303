F_s   = 44.1e3;
C     = 1e-12;
I_ctl = 6.3e-9;  % Set to match ~1kHz cutoff
V_t   = 26e-3;
r     = 0.9;     

N = 1000;                                 
x = sin(2*pi*1e2*(0:N-1)/F_s);            

% Preallocate arrays
y_a = zeros(1, N);
y_b = zeros(1, N);
y_c = zeros(1, N);
y_d = zeros(1, N);
W_a = zeros(1, N);
W_b = zeros(1, N);
W_c = zeros(1, N);

% Loop through time samples
for n = 3:N


    % y_a(n) = y_a(n-1) + \frac{I_{ctl}}{C F_s} \left( tanh \left( \frac{x(n) - 4 r y_d(n-1)}{2 V_t} \right) - W_a(n-1) \right)
    y_a(n) = y_a(n - 1) + ((I_ctl) / (C * F_s)) * ( tanh((x(n) - 4*r*y_d(n - 1)) / (2*V_t))  - W_a(n - 1));

    % W_a(n) = tanh \left( \frac{y_a(n)}{2 V_t} \right)
    W_a(n) = tanh((y_a(n))/(2 * V_t));



    % y_b(n) = y_b(n-1) + \frac{I_{ctl}}{C F_s} \left( W_a(n) - W_b(n-1)  \right)
    y_b(n) = y_b(n-1) + ((I_ctl) / (C * F_s)) * (W_a(n) - W_b(n-1));

    % W_b(n) = tanh \left ( \frac{y_b(n)}{2 V_t})
    W_b(n) = tanh((y_b(n)) / (2 * V_t));


    % y_c(n) = y_c(n-1) + \frac{I_{ctl}}{C F_s} \left( W_b(n) - W_c(n-1)  \right)
    y_c(n) = y_c(n - 1) + ((I_ctl) / (C * F_s)) * (W_b(n) - W_c(n - 1));

    % W_c(n) = tanh \left ( \frac{y_c(n)}{2 V_t})
    W_c(n) = tanh((y_c(n)) / (2 * V_t));


    % y_d(n) = y_d(n-1) + \frac{I_{ctl}}{C F_s} \left( W_c(n) - tanh\left( \frac{y_d(n-1)}{2 V_t} \right) \right)
    y_d(n) = y_d(n - 1) + ((I_ctl) / (C * F_s)) * (W_c(n) - tanh((y_d(n - 1)) / (2 * V_t)));

end

% Plot the results
t = (0:N-1)/F_s;
figure;
subplot(5,1,1); plot(t, y_a); title('y_a(n)'); grid on;
subplot(5,1,2); plot(t, y_b); title('y_b(n)'); grid on;
subplot(5,1,3); plot(t, y_c); title('y_c(n)'); grid on;
subplot(5,1,4); plot(t, y_d); title('y_d(n)'); grid on;
subplot(5,1,5); plot(t, x); title('Input x(n)'); grid on;
xlabel('Time (s)');
