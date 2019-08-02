function argStruct = mergepvpairs(defaultStruct, varargin)
    argStruct = mergeStructi(defaultStruct, struct(varargin{:}));
end