% wrapper for matlab struct
% fields is the field names you want.
%> mkstruct({'blah','vleh'})
%> mkstruct({'blah','vleh'},10)
%> mkstruct({'blah','vleh'},{'strings',[10,9,8]})
%> mkstruct({'blah','vleh'},{{'strings','stunk'},{10,9,8,12,14}})
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
            values = values(:);            
            try                
                fieldValueCell = [fields, values]';
                stc = struct(fieldValueCell{:});
            catch me
                if numel(fields)==numel(values)
                    stc = mkstruct_robust(fields, values);                
                else
                    rethrow(me)
                end
            end
        else
            stc = mkstruct_robust(fields, values);
        end
    end
end

function stc = mkstruct_robust(fields, values)
    stc = struct();
    if numel(fields)==numel(values)
        for f=1:numel(fields)
            field = fields{f};
            value = values{f};
            stc.(field) = value;
        end
    else
        throw(MException('Informaton:Utility','Mismatch in number of fields (%d) and values (%d)', numel(fields), numel(values)))
    end
end
