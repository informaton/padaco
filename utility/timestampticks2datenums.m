function datenums = timestampticks2datenums(timestampticks)
    %   ref: https://learn.microsoft.com/en-us/dotnet/api/system.datetime.ticks
    % NET.Ticks = A single tick represents one hundred nanoseconds or one ten-millionth of a second. There are 10,000 ticks in a millisecond (see TicksPerMillisecond) and 10 million ticks in a second.
    % The value of this property represents the number of 100-nanosecond intervals that have elapsed since 12:00:00 midnight, January 1, 0001 in the Gregorian calendar, which represents MinValue.
    % ticksPerSec = 10^7;  % unitsTime per sec - number of ticks in a second
    % secondsPerHour = 3600;
    % hoursPerDay = 24;

    unitsTimePerDay = 24*3600*10^7;
    matlabDateTimeOffset = 365+1+1;  %367, 365 days for the first year + 1 day for the first month + 1 day for the first day of the month
    %start, stop and delta date nums

    datenums = timestampticks/unitsTimePerDay + matlabDateTimeOffset;
end