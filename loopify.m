function [loops] = loopify( args, varargin)
% This function is for the general case where we want to iterate over all possible combinations of values for various
% arguments.  Given 
% 
% This function will assign a unique number to each permutation of the parameters in 
% in the 'args' struct, looping in the order that the struct fields 
%
% Input
%
% args - struct, contains the parameter values to iterate over
%
% varargin - accepts additional parameters passed in via name, value pairs:
% 
%         'execute_fn' - string, a function name to call
%
%              'range' -  [min_idx max_idx], range of indices
%          		             - if 'fn name' specified, will only run for those indices
%                      		 - if 'fn name' not specified, will return permutation for the range
%
%      'constant_args' - cell array, allows specifying additional arguments that always get
%      					 passed to the function specified in the 'execute_fn' (doesn't get used
%      					     - if 'execute_fn' is empty this doesn't get used
%      					     - values are specified in the call to 'execute_fn' BEFORE the other,
%      					       "non-constant" parameters
%
% Output
%
% loops - struct, contains the following fields:
%
%        'indices' - integer array of linear indices corresponding to a unique combination
%                    of parameters in row-major order, iterating over parameters as
%                    the order they appear in 'args.fieldnames'
%
%     'subscripts' - {num_params x 1} cell array, each cell array contains a [numel(indicies) x 1]
%                    array (numeric or cell depending argument type) specifying the argument value
%                    for a particular argument, index pair e.g.:
%                                
%                          loops.subscripts{2}{3} - gives the 2nd parameter value, for the 
%                                                   3rd combination
%
%        'results' - {numel(indices) x nargout('execute_fn')} cell array, entry {i,j} contains the
%        			 jth output argument from calling 'execute_fn' for the ith combination of args
%
% Example 1 - create argument combinations
%
% args.first = {'A' 'B' 'C'};
% args.second = [1 3];
%
% % create all possible combinations of arguments
% loops = loopify(args);
%
%      loops =
%        indices: [1 2 3 4 5 6]     % unique argument combinations
%        subscripts: {2x1 cell}     
%        results: {}                % empty because no 'execute_fn'
%
%  loops.subscripts{:}              % each row corresponds to an argument index
%        ans = [1] [2] [3] [1] [2] [3]
%        ans = [1] [1] [1] [2] [2] [2]
%
% % create only combinations 2 through 4
% loops = loopify(args,'range',2:4);
%      loops =
%        indices: [ 2 3 4]          % unique argument combinations
%        subscripts: {2x1 cell}     
%        results: {}                % empty because no 'execute_fn'
%
%  loops.subscripts{:}              
%        ans = [2] [3] [1]
%        ans = [1] [1] [2] 
%
%
% Example 2 Actually call a function
%
% args.first = [1 2];
% args.second = [1 2 3];
%
% loops = loopify(args,'execute_fn','minus');
%
%      loops =
%        indices: [1 2 3 4 5 6]     % unique argument combinations
%        subscripts: {2x1 cell}     
%        results: {6x1 cell}
%
%      loops.results =              % each row contains result
%         [0]     % this is the result of calling minus(1,1)
%         [1]     % this is the result of calling minus(2,1)
%         [-1]    % the result of minus(1,2)
%         [0]	  % the result of minus(2,2)
%         [-2]    % the result of minus(1,3)
%         [-1]    % the result of minus(2,3)
%
% NOTE: requires parsepropval.m function from matlab file exchange
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% some setup
parameters = fieldnames(args);
% calculate total number of parameters
num_params = numel(parameters);
% grab the number of possible values for each parameter
sizes = structfun(@numel,args);
total_num_combinations = prod(sizes);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% handle arguments
defaults.range = 1 : total_num_combinations;
defaults.execute_fn = '';
defaults.constant_args = {};
options = parsepropval(defaults,varargin{:});


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% map desired index range to argument combinations

% this let's us get the subscripts for all the values in our range
loops.indices = options.range;
loops.subscripts = cell(num_params,1);
[loops.subscripts{:} ] = arrayfun(@(idx) ind2sub(sizes,idx), options.range,'UniformOutput',false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% execute a script if specified
if ~isempty(options.execute_fn)

	try 
		fn_handy = str2func(options.execute_fn);
	catch err
		disp(['Invalid value for argument "execute_fn":' options.execute_fn ' - could not create function handle from specified value.  Likely a typo or you do not have the function in your path']);
		throw(err);
	end

	num_argouts = nargout(options.execute_fn);
	loops.results = cell(numel(loops.indices),num_argouts);

	for result_idx = 1 : numel(loops.indices)
		% this gets the correct parameters for the current index
		current_iteration_params = arrayfun( @(param_idx) extract_value_from_subscript(getfield(args, parameters{param_idx}),loops.subscripts{param_idx}{result_idx} ) , 1:num_params, 'UniformOutput',false);

		% here we accomodate the possibility of passing in constant arguments
		if ~isempty(options.constant_args)
			current_iteration_params = {options.constant_args{:} current_iteration_params{:}};
		end
	
		% finally store results
		[loops.results{result_idx,:}] = fn_handy(current_iteration_params{:});
	end
else
	loops.results = {};
end

end

function [value] = extract_value_from_subscript(s,idx)
	if iscell(s)
		value = s{idx};
	else
		value = s(idx);
	end
end
