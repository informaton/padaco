classdef PACategoricalParam < PAParam
    properties(SetAccess=protected)
        categories;
    end
    
    methods
        function this = PACategoricalParam(varargin)
            this@PAParam('categorical',varargin{:});
            this.categories = categories(this.default);
            this.setValue(char(this.default));
        end
        
        % Also in PAEnumParam
        function canIt = canSetValue(this, value2set)
            canIt = nargin>1 && ischar(value2set) && any(strcmpi(value2set,this.categories));
        end
    end
end