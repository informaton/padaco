function [timeElapsedStr, timeElapsed] = getTimeElapsedStr(startTime)
    timeElapsed = now-startTime;
    if(timeElapsed>=1/24)
        timeElapsedStr = datestr(timeElapsed,'hh:mm:ss');
    elseif(timeElapsed>=1/1440)
        timeElapsedStr = datestr(timeElapsed,'mm:ss');
    else
        timeElapsedStr = [datestr(timeElapsed,'ss'),' s'];
    end

end