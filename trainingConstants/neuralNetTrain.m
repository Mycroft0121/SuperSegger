function [net,fun] = neuralNetTrain (X, Y, numCanidates)
% Solve a Pattern Recognition Problem with a Neural Network
% Script generated by Neural Pattern Recognition app
%
% This script assumes these variables are defined:
%
%   X - input data.
%   Y - target data.
%   numCanidates - number of times to repeat training
%
%
% Script was generated by Neural Pattern Recognition app
% University of Washington, 2016
% This file is part of SuperSegger.


fun = @scoreNeuralNet;

if ~exist('numCanidates','var') || isempty(numCanidates)
    numCanidates = 1;
end

t = [(Y == 0),Y]';
x = X';


% Choose a Training Function
% For a list of all training functions type: help nntrain
% 'trainlm' is usually fastest.
% 'trainbr' takes longer but may be better for challenging problems.
% 'trainscg' uses less memory. Suitable in low memory situations.
trainFcn = 'trainbr';  % Scaled conjugate gradient backpropagation.

% Create a Pattern Recognition Network
hiddenLayerSize = 10;
net = patternnet(hiddenLayerSize);

% Setup Division of Data for Training, Validation, Testing
net.divideParam.trainRatio = 70/100;
net.divideParam.valRatio = 15/100;
net.divideParam.testRatio = 15/100;

%Make sure the overfit is real.
net.trainParam.max_fail = net.trainParam.epochs / 10;

numTotal = numel(t(1,:));
numTrue = numel(find(t(1,:)==0));
numFalse = numel(find(t(1,:)==1));

errorWeights = {[(t(1,:)==0) * 0 + (t(1,:)==1) * numTotal / numFalse; (t(2,:)==0) * 0 + (t(2,:)==1) * numTotal / numTrue]};



% Train the Network
canidates = {};
for i = 1:numCanidates
    [canidates{i}] = train(net,x,t,{},{},errorWeights);
end

% Test the Network
% y = net(x);
% e = gsubtract(t,y);
% performance = perform(net,t,y);
tind = vec2ind(t);
percentError = [];
for i = 1:numCanidates
    net = canidates{i};
    y = net(x);
    yind = vec2ind(y);
    percentError(i) = sum(tind ~= yind)/numel(tind);
end

[percentErrors, index] = min(percentError);

net = canidates{index};
disp (['Percent Error from neural network predictions : ',num2str(percentErrors)]);

end

