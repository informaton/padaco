classdef PAEnumParam < PAStringParam
    properties(SetAccess=protected)
        categories;
    end
    
    methods
        function this = PAEnumParam(varargin)
            this@PAStringParam(varargin{:});
            args.categories = [];
            args = mergepvpairs(args, varargin{:});
            this.categories = args.categories();
            this.setValue(char(this.default));
        end
        
        function canIt = canSetValue(this, value2set)
            canIt = nargin>1 && ischar(value2set) && any(strcmpi(value2set,this.categories));
        end
    end
end