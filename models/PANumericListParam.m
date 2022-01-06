classdef PANumericListParam < PANumericParam
    
    methods        
        function canIt = canSetValue(this, value2set)
            try
                if strcmpi(this.type,'logical')
                    value2set = value2set~=0; % force logical type since MATLAB does not consider numeric 1 and 0 as logical
                end
                canIt = all(isa(value2set,this.type)) && ...
                    ( ...
                        isempty(value2set) || ...
                        (all(value2set>=this.minAllowed) && all(value2set<=this.maxAllowed)) || ...
                        (any(isnan(value2set)) && isnan(this.default)) ...
                    );                
            catch me
                showME(me);
                canIt = false;
            end
        end
    end
end