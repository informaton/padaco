% wrapper for matlab struct
% fields is the field names you want.
%> mkstruct({'blah','vleh'})
%> mkstruct({'blah','vleh'},10)
%> mkstruct({'blah','vleh'},{'strings',[10,9,8]})
%> @author Hyatt Moore IV, 1/29/2018
function stc = mkstruct(fields,values)
if(nargin<1)
    stc = struct;
else    
    
    fields = fields(:);

    if(nargin<2 || isempty(values))
        values = cell(size(fields)); % make it empty
    end
    if(~iscell(values))
        values = mat2cell(repmat(values,size(fields)),ones(size(fields)));
    end
    values = values(:);
    
    fieldValueCell = [fields, values]';
    stc = struct(fieldValueCell{:});
end