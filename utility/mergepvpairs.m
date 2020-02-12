function argStruct = mergepvpairs(defaultStruct, varargin)
    % Need to handl possibilty of cell values for field values, which need
    % to be placed in additional {} for the struct(..) command to work.
    for v=2:2:numel(varargin)
        if(iscell(varargin{v}) && numel(varargin{v})>1)
            varargin(v)={varargin(v)};
        end
    end
    argStruct = mergeStructi(defaultStruct, struct(varargin{:}));
end