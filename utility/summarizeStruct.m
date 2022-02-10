% summaryStruct = summarizeStruct(inputStruct)
% Calls getLiteSummary for each field of inputStruct and returns 
% result in summaryStruct under same field name.
% Summary statistics for each field include:
%   .mx = mean(demo.(fieldname))
%   .var = var(demo.(fieldname))
%   .sem = sem(demo.(fieldname))
%   .n = numel(demo.(fieldname))
%   .string = string output of the above
%
% An empty argument will return a struct with the summary statistic fields
% as empty or 0 (for n).
%
% Written by Hyatt Moore IV, Informaton; August 8, 2015
% - Updated to support tables; 2/4/2019
function summary = summarizeStruct(queryStruct)

    if(nargin<1)
        summary = [];
    else
        if(istable(queryStruct))
            rowNames = queryStruct.Properties.VariableNames;
        else
            rowNames = fieldnames(queryStruct);
        end
        for r=1:numel(rowNames)
            try
                rowName = rowNames{r};
                
                summary.(rowName) = getLiteSummary(queryStruct.(rowName));
            catch me
                showME(me);
            end
        end
    end
end