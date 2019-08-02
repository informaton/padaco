classdef PAParam < handle
    
    events
        ValueSet;
    end
    
    properties(SetAccess=private)
        type;
    end
    
    properties(SetAccess=protected)
        description;
        default;
        value;
    end
    
    methods
        function this = PAParam(classType, varargin)
            narginchk(1,9);
            if(~this.setType(classType))
                fprintf(2,'Unable to set parameter type to %s\n',classType);
            else
                
                args.description = this.type;
                args.default = [];
                args.value = [];
                args = mergepvpairs(args,varargin{:});
                this.setDescription(args.description);
                if(~empty(this.default))
                    this.setDefault(args.default);
                end
                if(~isempty(this.value))
                    this.setValue(args.value);
                end
            end
        end
    end
    
    methods(Access=protected)
        function didSet = setValue(this, value2set)
            if(isa(value2set,this.type))
                this.value = value2set;
                didSet = true;
                this.notify('ValueSet');
            else
                didSet = false;
            end
        end
        
        function didSet = setDescription(this, descStr)
            if(nargin>1 && ischar(descStr))
                this.description = descStr;
                didSet = true;
            else
                didSet = false;
            end
        end
        
    end
    
    methods(Access=private)
        
        function didSet = setType(this, classType)
            if(isa(classType,'function_handle'))
                classType = func2str(classType);
            end
            
            if(ischar(classType) && ~empty(meta.class.fromName(classType)))
                this.type = classType;
                didSet = true;
            else
                didSet = false;
            end
        end        
    end
end