function [filt_sigOut, filtfilt_sigOut] = acti_iir_filter(sigIn,fs, n_order,peak2peakDB)
    
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
    Wp = Wpass(1);
    Ws = Wpass(2);
    Rp = peak2peakDB;
    Rs = 60;
    
    % Cheby 1
    [n_order, Wp] = cheb1ord(Wp, Ws, Rp, Rs) ;
    [h_a,h_b] = cheby1(n_order, peak2peakDB, Wpass, 'bandpass');
    
    % Cheby 2
    [n_order, Wp] = cheb2ord(Wp, Ws, Rp, Rs) ;
    [h_a,h_b] = cheby2(n_order, peak2peakDB, Wpass, 'bandpass');
    
    % Butterworth filter
    Wp = Wpass;
    Ws = [Wpass(1)-0.1, Wpass(2)+0.1];
    [n_order, Wn] = buttord(Wp, Ws, Rp, Rs);  
    [h_a,h_b] = butter(n_order,Wn);
    
    % Filter data
    filt_sigOut = filter(h_a,h_b, sigIn);
    
    filtfilt_sigOut = filtfilt(h_a,h_b, sigIn);
    
    if(nargout==0)
        plotPSDs(sigIn, filt_sigOut, filtfilt_sigOut,fs);
        
        % plotSigs(sigIn,filt_sigOut, filtfilt_sigOut);
    end
end
