classdef PAEnumListParam < PAEnumParam
    
    methods
        
        % ensure we only have category values placed in the value field
        function didSet = setValue(this, value2set)
            didSet = false;
            if(nargin>1 && this.canSetValue(value2set))
                if islogical(value2set) || isnumeric(value2set)
                    value2set = this.categories(value2set);
                end
                if iscell(value2set)
                    value2set = unique(value2set);
                elseif contains(value2set, ',')  % for example:  'choi,imported_file' which happens when importing from a text file
                    value2set = unique(strsplit(value2set,','));
                else                    
                    value2set = {value2set};
                end
                this.value = value2set;
                didSet = true;
                this.notify('ValueSet');
            end
        end
        
        % Allow categories or indices as values 2 set
        function canIt = canSetValue(this, value2set)
            canIt = false;
            if nargin>1 && ~isempty(value2set)
                numValues = numel(value2set);
                numCategories = numel(this.categories);
                if islogical(value2set) && any(value2set) && numValues==numCategories
                    canIt = true;
                elseif ischar(value2set)
                    if contains(value2set, ',')
                        canIt = this.canSetValue(unique(strsplit(value2set, ','))); % for example:  'choi,imported_file' which happens when importing from a text file
                    else
                        canIt = canSetValue@PAEnumParam(this, value2set);
                    end
                elseif numValues <= numCategories
                    if isnumeric(value2set) && all(arrayfun(@(x)(x>=1 && x<= numCategories), value2set))
                        canIt = true;                    
                    elseif iscell(value2set)
                        % anonymous function calls to sublcass method are not allowed :( 
                        %canIt = all(cellfun(@(c)(canSetValue@PAEnumParam(this, c)), value2set));
                        canIt = false(numValues,1);
                        for c=1:numValues
                            canIt(c) = canSetValue@PAEnumParam(this, value2set{c});
                        end
                        canIt = all(canIt);
                    end
                end                    
            end           
        end
        
        function str = num2str(this)
            str = strjoin(this.value, ',');
        end
    end
end