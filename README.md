looper_not_bruce_willis
=======================

matlab utility for iterating over combinations of parameters

#### Examples
Let's say we want to run a classification function (meinClassifier.m) with various regularization penalties and for various subject datasets:

    parameters.regularization_penalties = [1 10 100];    
    parameters.subjects = {'john' 'paul' 'ringo' 'george'};

    looped = loopify(parameters,'execute_fn','meinClassifier');

    




