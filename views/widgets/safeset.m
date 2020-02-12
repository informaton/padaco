% Set wrapper for struct of handles, which may not have the given tag, or
% may not be a handle.

% Hyatt Moore, 7/22/2019
function didSafeSet = safeset(structOfHandles,tag, varargin)
    didSafeSet = false;
    if(isstruct(structOfHandles) && isfield(structOfHandles,tag) && ishandle(structOfHandles.(tag)))
        set(structOfHandles.(tag),varargin{:});
        didSafeSet = true;
    end
    if(~didSafeSet)
        fprintf(2,'Could not safely set handle tag (%s)\n',tag);
    end
end