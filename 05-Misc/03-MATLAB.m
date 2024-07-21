% Enda Farrell July 2012
% Sample Matlab Code
% (Not full Function shown)

% First calculate (wrapped) phase of levy
% index of price signal and volatility
levy_phase = atan2(levy_vol, levy_signal);

% METHOD 1:
% use builtin MATLAB function
phase_unwrapped1 = unwrap(levy_phase);

% METHOD 2:
% Unwrap the signal Levyphase(n)
% using increments of pi
phase_unwrapped2 = levy_phase;

for i = 2:length(levy_phase)
    % Work out difference
    % between successive signals
    difference = levy_phase(i) - levy_phase(i-1);

     if difference > pi
        phase_unwrapped2(i:end) = phase_unwrapped2(i:end) - 2*pi;
    elseif difference < -pi
        phase_unwrapped2(i:end) = phase_unwrapped2(i:end) + 2*pi;
    end
end

% METHOD 3:
% Phase upwrapping as per Blackledge (2006) page 135,
% an alternative method to calculate the Lévy_phase
% which does not need explict unwrapping.

% Initialise variables for Method 3
% this is daily price = equal time between each data point
time_unit = 1;
integration = 0;

% Calculating phase at time = 0
phase_unwrapped3(1) = atan2(levy_vol(1), levy_signal(1));

for i = 2:n
    % Notation:
    % f  = real part of signal
    % q  = imaginary component of signal
    % A  = amplitude of signal
    % Df = derivative of f
    % Dq = derivative of q

    % Approach:

    % Analytic Signal:
        % signal = f + i*q

    % Instantaneous Frequency of Signal:
        % freq = 1/A^2 * [f*Dq - q*Df]

    % Unwrapped Phase of signal (at time t):
        % phase(i) = phase(0) + integrate(freq from 0 to t)

    % Calculate phase amplitude 'A'
    A_squared = levy_signal(i)^2 + levy_vol(i)^2;

    % Calculate differential
    % of Levy Signal and Levy Volatility
    diff_Levysig = (levy_signal(i) - levy_signal(i-1)) / time_unit;
    diff_Levyvol = (levy_vol(i) - levy_vol(i-1)) / time_unit;

    % Calculate (instantaneous) frequency of the signal
    Levy_freq = (A_squared^-1)*((levy_signal(i)*diff_Levyvol) - (levy_vol(i)*diff_Levysig));

    % increment integration variable
    integration = integration + Levy_freq;

    % Calculate (unwrapped) phase
    % by integrating the frequency
    phase_unwrapped3(i) = phase_unwrapped3(1) + integration;
end

% calculate best linear fit of unwrapped Levy phase signal
% Method 1: Matlab function
% - polynominal fit of degree 1 (straight line)
phase_unwrapped3_bestfit     = polyfit(x,phase_unwrapped3,1);
phase_unwrapped3_model       = polyval(phase_unwrapped3_bestfit,x);

% Subtract best fit model
% from original unwrapped phase signal
phase_unwrapped3_adjusted    = phase_unwrapped3 - phase_unwrapped3_model;

% Finally normalise all phases
levy_phase              = levy_phase ./ max(abs(levy_phase));
phase_unwrapped1        = phase_unwrapped1 ./ max(abs(phase_unwrapped1));
phase_unwrapped2        = phase_unwrapped2 ./ max(abs(phase_unwrapped2));
phase_unwrapped3        = phase_unwrapped3 ./ max(abs(phase_unwrapped3));
phase_unwrapped3_model  = phase_unwrapped3_model./max(abs(phase_unwrapped3_model));
phase_unwrapped3_output = phase_unwrapped3_output./max(abs(phase_unwrapped3_output));
