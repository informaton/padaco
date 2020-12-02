function isIt = isVerLessThan(ver1, ver2)
    v1Nums = getRevisionNums(ver1);
    v2Nums = getRevisionNums(ver2);
    if v1Nums(1) ~= v2Nums(1)         % major version
        isIt = v1Nums(1) < v2Nums(1);
    elseif v1Nums(2) ~= v2Nums(2)     % minor version
        isIt = v1Nums(2) < v2Nums(2);
    else   
        isIt = v1Nums(3) < v2Nums(3);  %minor version revision
    end    
end

function revNums = getRevisionNums(verStr)
    if verStr(1)=='v'
        verStr = verStr(2:end);
    end
    revNums = sscanf(verStr, '%d.%d.%d')';
    
    % 0-fill as necessary
    if numel(revNums) < 2
        revNums(2) = 0;
        if numel(revNums) < 3
            revNums(3) = 0;
        end
    end
end
