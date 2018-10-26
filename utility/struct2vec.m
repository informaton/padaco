%======================================================================
%> @brief flattens a structure to a single dimensional array (i.e. a
%> vector)
%> @param structure A struct with any number of fields.
%> @retval vector A vector with values that are taken from the
%> structure.
%> @author Hyatt Moore IV
%======================================================================
function vector = struct2vec(structure,vector)
    if(nargin<2)
        vector = [];
    end
    if(~isstruct(structure))
        vector = structure;
    else
        fnames = fieldnames(structure);
        for f=1:numel(fnames)
            vector = [vector;struct2vec(structure.(fnames{f}))];
        end
    end
end