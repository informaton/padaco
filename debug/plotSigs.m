
function plotSigs(sigIn, filt_sigIn, filtfilt_sigIn)
    
    % Perform no averaging here
    figure;
    
    subplot(3,1,1);
    stem(freq_vec, sigIn);
    title('sig');
    
    % Show filtered results
    subplot(3,1,2);    
    stem(freq_vec, filt_sigIn);
    title('filter(sig)');
  
    subplot(3,1,3);    
    stem(freq_vec, filtfilt_sigIn);
    title('filfilt(sig)'); 
end