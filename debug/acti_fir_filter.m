function [filt_sigOut, filtfilt_sigOut] = acti_fir_filter(sigIn,fs, n_order,peak2peakDB)
    
    if(nargin<4 || isempty(peak2peakDB))
        peak2peakDB = 3;  % reduces by 1/2
        %peak2peakDB = .1;
    
    end

    if(nargin<3 || isempty(n_order))
        n_order = 3;
        n_order = 2;
    end
    
    Fmax = fs/2;
    Fpass = [0.25 2.5];
    
    Wpass = Fpass/Fmax;  %normalized frequency
    
    [h_a,h_b] = cheby1(n_order, peak2peakDB, Wpass, 'bandpass');
    
    % Filter data
    filt_sigOut = filter(h_a,h_b, sigIn);
    
    filtfilt_sigOut = filtfilt(h_a,h_b, sigIn);
    
    if(nargout==0)
        plotPSDs(sigIn, filt_sigOut, filtfilt_sigOut,fs);
        
        % plotSigs(sigIn,filt_sigOut, filtfilt_sigOut);
    end
end
