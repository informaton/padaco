% Transforms a struct, cell, or singleton with PAParam values to only have their value properties.
function mixed = paparamsToValues(mixed)
    if isa(mixed, 'PAParam')
        mixed = mixed.value;
    elseif iscell(mixed)
        mixed = cellfun(@(m) paparamsToValues(m), mixed, 'uniformoutput',false);
    elseif isstruct(mixed)
        fnames = fieldnames(mixed);
        for f=1:numel(fnames)
            fname = fnames{f};
            mixed.(fname) = paparamsToValues(mixed.(fname));
        end
    end
end
