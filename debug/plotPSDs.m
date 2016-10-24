
function plotPSDs(sigIn, filt_sigIn, filtfilt_sigIn,Fs)
    
    % Perform no averaging here
    figure;
    
    dur_sec = numel(sigIn)/Fs;  % assume all parameters have same number of elements.
    % Perform no averaging here
    psdSettings.FFT_window_sec = dur_sec;
    psdSettings.interval = dur_sec;
    psdSettings.wintype = 'rectwin';
    psdSettings.removemean =false;
    [sigInPSD, freq_vec] = featureFcn.getpsd(sigIn,Fs,psdSettings);  %getpsd(signal_x,Fs,PSD_settings,ZeroPad)
    filt_sigInPSD = featureFcn.getpsd(filt_sigIn,Fs,psdSettings);  %getpsd(signal_x,Fs,PSD_settings,ZeroPad)
    filtfilt_sigInPSD = featureFcn.getpsd(filtfilt_sigIn,Fs,psdSettings);  %getpsd(signal_x,Fs,PSD_settings,ZeroPad)

    
    % Perform no averaging here
    
    
    % Show time series on the left side
    x = 1:numel(sigIn);
    
    subplot(3,2,1);
    stem(x, sigIn);
    title('sig');
    xlim([1 x(end)]);

    % Show filtered results
    subplot(3,2,3);    
    stem(x, filt_sigIn);
    title('filter(sig)');
    xlim([1 x(end)]);

    subplot(3,2,5);    
    stem(x, filtfilt_sigIn);
    title('filfilt(sig)');     
    xlim([1 x(end)]);

    % Show spectrum on the right hand side.
    
    subplot(3,2,2);
    stem(freq_vec, sigInPSD);
    title('PSD of sig');
    ylabel('Amplitude'); % Max value occurs at (A^2)/2 for A*sin(2pi*f*x)
    xlabel('Frequency (Hz)');
    
    


    
    % Show filtered results
    subplot(3,2,4);    
    stem(freq_vec, filt_sigInPSD);
    title('PSD of filter(sig)');
    ylabel('Amplitude'); % Max value occurs at (A^2)/2 for A*sin(2pi*f*x)
    xlabel('Frequency (Hz)');

    subplot(3,2,6);    
    stem(freq_vec, filtfilt_sigInPSD);
    title('PSD of filfilt(sig)');
    ylabel('Amplitude'); % Max value occurs at (A^2)/2 for A*sin(2pi*f*x)
    xlabel('Frequency (Hz)');
    
end