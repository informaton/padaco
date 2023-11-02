% p is the noise level you can add to it
function testMapping(r,c, p)
    if nargin<3
        p=0;
    end
    if nargin<1
        % Generate example x matrix
        r = 5;
        c = 3;
    elseif nargin<2
        c = r;
    end

    x = randi(100, r, c);

    % Create y and get the known permutation
    [y, known_perm] = createY(x);

    % Add Gaussian noise to y
    noise = p * rand(size(y)); % Generate Gaussian noise with standard deviation p
    y = y + noise;
    y = round(y);
    %  known_perm

    methods = {'cross-correlation', 'euclidean', 'cosine', 'manhattan', 'chebyshev', 'hamming'};

    for method = methods
        computed_mapping = computeMapping(x, y, method{1});
        correct_matches = sum(computed_mapping == known_perm);
        total_rows = length(computed_mapping);
        disp([method{1} '. Correctly matched rows: ' num2str(correct_matches) '/' num2str(total_rows) ' (' num2str(100*correct_matches/total_rows) '%)']);
        
        if correct_matches~=total_rows
            for i = 1:total_rows
                x_row_str = sprintf('(%d) %s', i, mat2str(x(i,:)));
                if computed_mapping(i)==0
                    result_str = [x_row_str ' - DID NOT MAP -  FAIL'];
                else
                    mapping_str = sprintf('(%d-%d) %s', i, computed_mapping(i), mat2str(y(computed_mapping(i),:)));
                    y_row_str = sprintf('(%d) %s', computed_mapping(i), mat2str(y(computed_mapping(i),:)));

                    if computed_mapping(i) == known_perm(i)
                        result_str = [x_row_str ' ' mapping_str ' ' y_row_str ' PASS'];
                    else
                        result_str = [x_row_str ' ' mapping_str ' ' y_row_str ' FAIL'];
                    end
                end
                disp(result_str);
            end
        end

        disp('-----------------------------');
    end

end


function [y, perm] = createY(x, y)
    % If y is not provided, create it by randomly reshuffling rows of x
    p=0;
    if nargin < 2
        perm = randperm(size(x, 1));
        y = x(perm, :);
    else
        perm = [];
    end
end
