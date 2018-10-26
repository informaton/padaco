function [timeElapsedStr, timeElapsed] = getTimeElapsedStr(startTime)
    timeElapsed = now-startTime;
    if(timeElapsed>=1/24)
        timeElapsedStr = datestr(timeElapsed,'HH:MM:SS');
    elseif(timeElapsed>=1/1440)
        timeElapsedStr = datestr(timeElapsed,'MM:SS');
    else
        timeElapsedStr = [datestr(timeElapsed,'SS'),' s'];
    end

end