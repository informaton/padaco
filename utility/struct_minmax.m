
% ======================================================================
%> @brief Evaluates the range (min, max) of components found in the
%> input struct argument and returns the range as struct values with
%> matching fieldnames/organization as the input struct's highest level.
%> @param dataStruct A structure whose fields are either structures or vectors.
%> @retval structMinMax a struct whose fields correspond to those of
%> the input struct and whose values are [min, max] vectors that
%> correspond to the minimum and maximum values found in the input
%> structure for that field.
%> @note Consider the example
%> @note dataStruct.accel.x = [-1 20 5 13];
%> @note dataStruct.accel.y = [1 70 9 3];
%> @note dataStruct.accel.z = [-10 2 5 1];
%> @note dataStruct.lux = [0 0 0 9];
%> @note structRange.accel is [-10 70]
%> @note structRange.lux is [0 9]
%======================================================================
function structMinmax = struct_minmax(dataStruct)
    fnames = fieldnames(dataStruct);
    structMinmax = struct();
    for f=1:numel(fnames)
        curField = dataStruct.(fnames{f});
        structMinmax.(fnames{f}) = minmax(struct_getRecurseMinmax(curField));
    end
end


%                     ruleFields = fieldnames(obj.usageStateRules);
%                     for f=1:numel(ruleFields)
%                         curField = ruleFields{f};
%                         if(hasfield(ruleStruct,curField) && class(ruleStruct.(curField)) == class(obj.usageStateRules.(curField)))
%                             obj.usageStateRules.(curField) = ruleStruct.(curField);
%                         end
%                     end
%
% end

% ======================================================================
%> @brief Recursive helper function for minmax()
%> input struct argument and returns the range as struct values with
%> matching fieldnames/organization as the input struct's highest level.
%> @param dataStruct A structure whose fields are either structures or vectors.
%> @retval minmaxVec Nx2 vector of minmax values for the given dataStruct.
% ======================================================================
function minmaxVec = struct_getRecurseMinmax(dataStruct)
    if(isstruct(dataStruct))
        minmaxVec = [];
        fnames = fieldnames(dataStruct);
        for f=1:numel(fnames)
            minmaxVec = minmax([struct_getRecurseMinmax(dataStruct.(fnames{f})),minmaxVec]);
        end
    else
        %minmax is performed on each row; just make one row
        minmaxVec = double(minmax(dataStruct(:)'));
    end
end