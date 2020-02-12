% --------------------------------------------------------------------
%> @brief Estimates daylight intensity across the given timeframe
%> @param numSections (optional) Number of chunks to estimate
%> daylight at across the study.  Default is 100.
%> @param datenumVec Optional instance of datenum().  Date time will
%> be calculated from this when included a 24 hour period, midnight-midnight,
%> is assumed.
%> @retval daylightVector Vector of estimated daylight from the time of day at startStopDatenums.
%> @retval startStopDatenums Nx2 matrix of datenum values whose
%> rows correspond to the start/stop range that the meanLumens
%> value (at the same row position) was derived from.
% --------------------------------------------------------------------
function [daylightVector,startStopDatenums] = getDaylightEstimate(numSections,datenumVec)
if(nargin<1 || isempty(numSections) || numSections <=1)
    numSections = 100;
end
if(nargin<2) ||isempty(datenumVec)
    datenumVec = datenum(0);
end

% otherwise, default to a 24 hour period.
if(numel(datenumVec)==1)
    datenumVec = [datenumVec, datenumVec+1-1/24/60/60/1000]; % i.e. + 23:59:59.999
end

indices = ceil(linspace(1,numel(datenumVec),numSections+1));
startStopDatenums = [datenumVec(indices(1:end-1)),datenumVec(indices(2:end))];
[~,~,~,H,MI,S] = datevec(mean(startStopDatenums,2));
dayTime = [H,MI,S]*[1; 1/60; 1/3600];
%             dayTime = [[H(:,1),MI(:,1),S(:,1)]*[1;1/60;1/3600], [H(:,2),MI(:,2),S(:,2)]*[1;1/60;1/3600]];

% obtain the middle spot of the daytime chunk. --> this does
% not work because the hours flip over at 24:00.
%             dayTime = [H,MI,S]*[1;1;1/60;1/60;1/3600;1/3600]/2;


% linear model for daylight
%             daylightVector = (-abs(dayTime-12)+12)/12;

% sinusoidal models for daylight
T = 24;
%             daylightVector = cos(2*pi/T*(dayTime-12));
%             daylightVector = sin(pi/T*dayTime);  %just take half of a cycle here ...

daylightVector= (cos(2*pi*(dayTime-12)/T)+1)/2;  %this is spread between 0 and 1; with 1 being brightest at noon.

end