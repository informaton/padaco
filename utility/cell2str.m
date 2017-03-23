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
            includeTrailingDelim = false;
        end
        outString = '';
        for r=1:numel(inCell)
            if(~includeTrailingDelim && r==numel(inCell))
                outString = sprintf('%s%s',outString,inCell{r});
            else
                % Need two percents signs before first s to get the correct
                % format string to use in the following sprintf call.
                fmtStr = sprintf('%%s%s%s',inCell{r},delim);
                outString = sprintf(fmtStr,outString);
                % Used to do it this way before realizing that strcat
                % removed trailing white space
                % outString = sprintf(strcat('%s',inCell{r},delim),outString);
            end
        end
end