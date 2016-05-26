% Using the method when pulling in binary data.
function axesUBit12Data = acti_double2ubit12(axesFloatData)
    encodingEPS = 1/341; %from trial and error - or math
    % precision = 'ubit12=>double';
    
    numBits = 12;
    maxValue = 2^(numBits-1);  
    % axesFloatData = (-bitand(axesUBitData,2048)+bitand(axesUBitData,2047))*encodingEPS;
    % axesUBit12Data = axesFloatData/encodingEPS-(maxValue*sign(axesFloatData)-maxValue)/2;  % this logic states that we only add the max value when dealing with negative float values; so we can get the 'u' part of our ubit12 correct.
    axesUBit12Data = axesFloatData/encodingEPS+(-min(sign(axesFloatData),0)*maxValue);  %here's another approach to the same logic.
                    
    
end