% appends a new key to the struct's last key-value pair, when value is not
% a stuct.
% > labelProps = 
% 
%   struct with fields:
% 
%            accel: [1×1 struct]
%            steps: 'Steps'
%              lux: 'Luminance'
%     inclinometer: [1×1 struct]
% 
% > labelProps = appendKeyToStruct(labelProps, 'string')  
% 
%   struct with fields:
% 
%            accel: [1×1 struct]
%            steps: [1×1 struct]
%              lux: [1×1 struct]
%     inclinometer: [1×1 struct]
%
% > labelProps.lux
% 
% ans = 
% 
%   struct with fields:
% 
%     string: 'Luminance'
function reStruct = appendKeyToStruct(reStruct, newKey)
    if isstruct(reStruct)
       keys = fieldnames(reStruct);
       for k=1:numel(keys)
           key = keys{k};
           val = reStruct.(key);
           if isstruct(val)
               reStruct.(key) = appendKeyToStruct(val, newKey);
           else
               reStruct.(key) = struct(newKey, val);
           end
       end
    end
end