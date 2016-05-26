% This example uses two sinusoidal signals instead of one.

% Imagine a band-pass filter which exhibits 0 gain at 0Hz (baseband), some
% positive gain at the center of the pass band and 0 gain at some frequency
% outside of the human movement spectrum (say, 50Hz).  If a sinusoidal
% signal of amplitude 5g (1 g =  1 unit of gravity or 9.82m/s^2) and
% frequency equal to the center of the pass band were passed through the
% filter, sampled and summed, the output would result in a relatively large
% value.  However, if that same 5g signal were passed through the filter
% with a frequency slightly lower or higher than the pass band (by, say,
% +/-2Hz), the sampled and summed output would result in a much lower
% value.  These values are referred to as counts.

close all;  % close figures
Amp1 = 5;
Amp2 = 5;

Fs = 40;
Fcenter = 0.75;
bits = 8;
levels = 2^bits;
dynamicRange = 4.26; % 4.26g/sec dynamic range == +/-2.13g/sec (centered at 0)
resolution = dynamicRange/levels;  %each level is considered 1 count

Fsig1 = 4;
Fsig2 = 10;
A = -9.8;
Fcenter= Fsig1;

dur_sec = 2;
analog_fs = 1/0.001;
x = 0:1/Fs:dur_sec;

sinSig1 = Amp1*sin(2*pi*Fsig1*x)+A;
sinSig2 = Amp2*sin(2*pi*Fsig2*x);
sinSig = sinSig1+sinSig2;

subplot(2,2,1);
plot(x,sinSig1+sinSig2);
title(sprintf('y = %u\\cdotsin(2\\pi(%u\\cdotx)) + %u\\cdotsin(2\\pi(%u\\cdotx)) %+0.2f',Amp1,Fsig1,Amp2,Fsig2, A));
ylabel('Amplitude');
xlabel('Time (sec)');

subplot(2,2,2);

% Perform no averaging here
psdSettings.FFT_window_sec = dur_sec;
psdSettings.interval = dur_sec;
psdSettings.wintype = 'rectwin';
psdSettings.removemean =false;
[sigPSD, freq_vec, nfft] = featureFcn.getpsd(sinSig,Fs,psdSettings);  %getpsd(signal_x,Fs,PSD_settings,ZeroPad)
stem(freq_vec, sigPSD);
title('Y = PSD(y)');
ylabel('Amplitude'); % Max value occurs at (A^2)/2 for A*sin(2pi*f*x)
xlabel('Frequency (Hz)');


% Build a filter
Fc = Fsig1;
Fmax = Fs/2;
f_over = 2;
Fpass = [0.25 2.5];
Fpass = [Fcenter-f_over, Fcenter+f_over];

Wpass = Fpass/Fmax;  %normalized frequency
peak2peakDB = 3;  % reduces by 1/2
peak2peakDB = 3;
n_order = 5;
[h_b,h_a] = cheby1(n_order, peak2peakDB, Wpass); %, 'bandpass');

% Filter data
filt_sinSig = filter(h_b,h_a, sinSig);

%/freqz(h_b,h_a); 
% Show filtered results
subplot(2,2,3);
plot(x,filt_sinSig);
title(sprintf('y = %u\\cdotsin(2\\pi(%u\\cdotx)) + %u\\cdotsin(2\\pi(%u\\cdotx)) %+0.2f',Amp1,Fsig1,Amp2,Fsig2, A));
ylabel('Amplitude');
xlabel('Time (sec)');

subplot(2,2,4);

[sigPSD, freq_vec, nfft] = featureFcn.getpsd(filt_sinSig,Fs,psdSettings);  %getpsd(signal_x,Fs,PSD_settings,ZeroPad)
stem(freq_vec, sigPSD);
title('Y = PSD(y)');
ylabel('Amplitude'); % Max value occurs at (A^2)/2 for A*sin(2pi*f*x)
xlabel('Frequency (Hz)');

set(gcf,'inverthardcopy','off','color',[1 1 1]);
% evaluate the frequency response over 100 points.
% [H,W] = freqz(h_a,h_b,100);

% Visualize the frequency response over 100 points.
% freqz(h_a,h_b,n_order);

%count = 1/fs*sum(filteredSignal(1:fs));

