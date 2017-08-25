%> Converts incoming string to a partitioned cell.  This is helpful in
%places where matlab uicontrols don't work as well and the textwrap
%alternative is not great.
%> @reference http://ascii.cl/
%> Carriage return = \f = 10
%> Line feed = \n = 13
%> Tab = \t = 9
function outCell =  str2cell(instring,delim)
    if(nargin<2 || isempty(delim))
        delim = '\n';
    end
    outCell = textscan(instring,'%s','delimiter',delim);
    outCell = outCell{1};
end

% function outCell = legacy(instrsting)
%     LF = 13;
%     delim = LF;
%     s = sprintf('%s',instring);  % make sure we convert any \n to their string format
%     newLineCount = sum(s==delim);
%     numRows = newLineCount+1;
%     outCell = cell(numRows,1);
%     
%     for c=1:numRows
%         [outCell{c}, instring] = strtok(instring, delim); 
%     end
% end