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
    properties(Access=private)
        help;
    end
    
    methods
        function this = PAParam(classType, varargin)
            narginchk(1,inf);
            if(~this.setType(classType))
                fprintf(2,'Unable to set parameter type to %s\n',classType);
            else                
                args.default = [];
                args.description = this.type;
                args.help = '';
                args = mergepvpairs(args,varargin{:});                
                if(~isempty(args.default))
                    this.setDefault(args.default);
                end
                this.setDescription(args.description);
                this.setHelp(args.help);
            end
        end
        
        function canIt = canSetValue(this, value2set)
            canIt = isa(value2set,this.type);
        end
        
        function didSet = setValue(this, value2set)
            didSet = false;
            if(nargin>1 && this.canSetValue(value2set))
                this.value = value2set;
                didSet = true;
                this.notify('ValueSet');
            end
        end
        
        function hasIt = hasHelp(this)
            hasIt = ~isempty(this.help);
        end
        
        function helpStr = getHelp(this)
            helpStr = this.help;
        end

    end
    
    methods(Access=protected)
        function setHelp(this, helpStr)
            if(ischar(helpStr))
                this.help = helpStr;
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
            
            if(ischar(classType) && ~isempty(meta.class.fromName(classType)))
                this.type = classType;
                didSet = true;
            else
                didSet = false;
            end
        end
        function didSet = setDefault(this, defaultValue)
            if(isa(defaultValue,this.type))
                this.default = defaultValue;
                this.setValue(defaultValue);  % this may fail if the default is out of bounds
                didSet = true;  % but don'tmake setting the current value's success or failure mean a requirement for replying the value was set.
            else
                didSet = false;
            end
        end
    end
end