% Converts a cell of strings to a single string using the specified
% delimiter to break between cells
function outString = cell2str(inCell, delim, includeTrailingDelim)
    if(~iscell(inCell) || isempty(inCell))
        outString = '';
    else
        if(nargin<2 || isempty(delim) || ~ischar(delim))
            delim = '\n';
        end
        if(nargin < 3 || isempty(includeTrailingDelim))
            includeTrailingDelim = true;
        end
        outString = '';
        for r=1:numel(inCell)
            if(includeTrailingDelim && r==numel(inCell))
                outString = sprintf('%s%s',outString,inCell{r});
            else
                outString = sprintf(strcat('%s',inCell{r},delim),outString);
            end
        end
end