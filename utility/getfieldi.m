% Case insensitive field retriever for MATLAB's struct/dictionary type.
% 2/5/2020
% Copyright Hyatt Moore, IV
function value = getfieldi(structIn, fieldToGet, defaultResult)
    narginchk(1,2);
    if nargin<2
        defaultResult = [];
    end
    value = defaultResult;
    if isstruct(structIn)
        fields = fieldnames(structIn);
        match = fields(strcmpi(fields,fieldToGet));        
        if ~isempty(match)
            value = structIn.(match{1});
        end
    end
end