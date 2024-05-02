% p is the noise level you can add to it
function results = testMapping(r,c, p)
    addpath("~/git/padaco/utility/");
    methods = {'cross_correlation', 'euclidean', 'cosine', 'manhattan', 'chebyshev'};    
    if nargin ==1 && any(strcmpi(r, {'methods','mappings'}))
        results = methods;
    else

        if nargin<3
            p=300;
        end
        if nargin<1
            % Generate example x matrix
            r = 5;
            c = 30;
        elseif nargin<2
            c = r;
        end


        is_verbose = false;
        x = randi(100, r, c);

        % Create y and get the known permutation
        [y, known_perm] = createY(x);

        % Add Gaussian noise to y
        noise = p * rand(size(y)); % Generate Gaussian noise with standard deviation p
        y = y + noise;
        y = round(y);
        %  known_perm

        methods = {'cross_correlation', 'euclidean', 'cosine', 'manhattan', 'chebyshev'};
        % 'hamming' - dropping hamming, which does not do well
        % 'mahalanobis' - needs to have more rows than columns
        results = mkstruct(methods);

        for method = methods
            computed_mapping = computeMapping(x, y, method{1});
            correct_matches = sum(computed_mapping == known_perm);
            total_rows = length(computed_mapping);
            results.(method{1}) = correct_matches/total_rows;
            if ~nargout
                disp([method{1} '. Correctly matched rows: ' num2str(correct_matches) '/' num2str(total_rows) ' (' num2str(100*correct_matches/total_rows) '%)']);

                if is_verbose && correct_matches~=total_rows
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
