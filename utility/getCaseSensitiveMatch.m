% returns the exact case-sensitive spelling of the last matching field (for struct input) or
% string (for cell input) of the second input argument with the first input
% (a string).
function caseSensitiveMatch = getCaseSensitiveMatch(caseInsensitiveStrToMatch, caseSensitiveStringsOrStruct)
    if(isstruct(caseSensitiveStringsOrStruct))        
        caseSensitiveStrings = fieldnames(caseSensitiveStringsOrStruct);
    else
        caseSensitiveStrings = caseSensitiveStringsOrStruct;
    end
    
    matchVector = strcmpi(caseSensitiveStrings,caseInsensitiveStrToMatch);
    if(any(matchVector))
        caseSensitiveMatch = caseSensitiveStrings{matchVector};
    else
        caseSensitiveMatch  = '';    
    end
end