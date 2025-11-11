function [trainedModel, validationAccuracy, resolvedFeatureNames] = trainLogRegECOC(csvPath)
%TRAINLOGREGECOC Entrena un modelo multiclase (AB/ID/SM) con logística + ECOC.
% [trainedModel, validationAccuracy, resolvedFeatureNames] = trainLogRegECOC(csvPath)
%
% - Lee el CSV preservando encabezados originales.
% - Mapea columnas aunque MATLAB haya "arreglado" los nombres.
% - Estandariza (z-score) y entrena ECOC con clasificadores binarios logísticos.
% - Devuelve un struct con predictFcn para tablas y predictFromCSV para CSVs.

%% ---------- 1) Leer CSV preservando encabezados ----------
T = readPreserve(csvPath);

%% ---------- 2) Definir features y clases válidas ----------
requiredFeatures = { ...
 'Acceleration Z(g)_entropy'
 'Acceleration Z(g)_std'
 'Acceleration Z(g)_var'
 'Acceleration Y(g)_std'
 'Acceleration Y(g)_var'
 'Angular velocity Y(°/s)_energy'
 'Angular velocity Y(°/s)_std'
 'Angular velocity Y(°/s)_var'
 'Angular velocity Y(°/s)_MAV'
 'Acceleration Y(g)_entropy'};

validLabels = {'AB','ID','SM'};

% Detectar columna de etiqueta de forma flexible
labelCandidates = {'label','Label','LABEL','clase','Clase','class','Class'};
labelName = '';
for k = 1:numel(labelCandidates)
    if ismember(labelCandidates{k}, T.Properties.VariableNames)
        labelName = labelCandidates{k};
        break
    end
end
if isempty(labelName)
    error('No se encontró la columna de etiquetas (por ejemplo "label").');
end

%% ---------- 3) Resolver nombres reales en la tabla ----------
[resolvedFeatureNames, missing] = resolveNames(T, requiredFeatures);
if ~isempty(missing)
    err = "Faltan columnas en el CSV:" + newline + join(string(missing), newline);
    error(err);
end

%% ---------- 4) Filtrar por clases válidas y limpiar filas vacías ----------
maskClass  = ismember(T.(labelName), validLabels);
T = T(maskClass, :);

% Quitar filas con NaN en cualquiera de las features resueltas
Xraw = T{:, resolvedFeatureNames};
nanRows = any(isnan(Xraw),2);
if any(nanRows)
    T(nanRows,:) = [];
    Xraw(nanRows,:) = [];
end
Y = categorical(T.(labelName), validLabels);

if isempty(T)
    error('No quedan filas válidas tras filtrar clases y NaNs.');
end

%% ---------- 5) Estandarizar (z-score) ----------
[mu, sigma] = deal(mean(Xraw,1), std(Xraw,0,1));
sigma(sigma==0) = 1; % evitar división por cero
X = (Xraw - mu) ./ sigma;

%% ---------- 6) Entrenar logística + ECOC ----------
t = templateLinear('Learner','logistic', ...
                   'Regularization','ridge', ...
                   'Lambda',1e-4, ...
                   'Solver','lbfgs');

cls = fitcecoc(X, Y, ...
    'Learners', t, ...
    'Coding',   'onevsone', ...
    'ClassNames', categorical(validLabels), ...
    'Verbose',  0);

%% ---------- 7) Validación cruzada (5-fold) ----------
cv = crossval(cls, 'KFold', 5);
validationLoss = kfoldLoss(cv);             % error promedio
validationAccuracy = 1 - validationLoss;

%% ---------- 8) Armar predictFcn y utilidades ----------
trainedModel = struct();
trainedModel.ClassificationECOC   = cls;
trainedModel.RequiredFeatureNames = requiredFeatures(:);
trainedModel.ResolvedFeatureNames = resolvedFeatureNames(:);
trainedModel.LabelName            = labelName;
trainedModel.Mu                   = mu;
trainedModel.Sigma                = sigma;
trainedModel.ClassOrder           = categorical(validLabels);

% Predicción desde TABLE (con resolución robusta de nombres)
trainedModel.predictFcn = @(tbl) localPredictFromTable(tbl, trainedModel);

% Predicción directa desde CSV (preservando encabezados)
trainedModel.predictFromCSV = @(pathCSV) localPredictFromCSV(pathCSV, trainedModel);

fprintf('Modelo entrenado. Validación (5-fold) accuracy = %.4f\n', validationAccuracy);

%% ========== SUBFUNCIONES ANIDADAS (acceden a variables del workspace) ==========

    function Tout = readPreserve(path)
        % Lectura robusta preservando encabezados originales
        try
            opts = detectImportOptions(path, 'VariableNamingRule','preserve');
            Ttmp = readtable(path, opts);
        catch
            Ttmp = readtable(path, 'VariableNamingRule','preserve');
        end
        Tout = Ttmp;
    end

    function [resolved, missingList] = resolveNames(Tin, wanted)
        % Mapea cada nombre en 'wanted' a la columna real en Tin:
        % 1) exacto, 2) "sanitizado" (makeValidName), 3) VariableDescriptions.
        vars    = string(Tin.Properties.VariableNames);
        varsSan = string(matlab.lang.makeValidName(vars, 'ReplacementStyle','delete'));
        wantSan = string(matlab.lang.makeValidName(wanted, 'ReplacementStyle','delete'));

        descs = strings(size(vars));
        if ~isempty(Tin.Properties.VariableDescriptions)
            descs = string(Tin.Properties.VariableDescriptions);
        end

        resolved   = strings(size(wanted));
        missingList = strings(0,1);

        for i = 1:numel(wanted)
            f   = string(wanted{i});
            fSan= wantSan(i);

            % 1) exacta
            idx = find(vars == f, 1);
            % 2) sanitizada
            if isempty(idx)
                idx = find(varsSan == fSan, 1);
            end
            % 3) por descriptions
            if isempty(idx) && any(descs ~= "")
                idx = find(descs == f, 1);
            end

            if isempty(idx)
                missingList(end+1) = f; %#ok<AGROW>
            else
                resolved(i) = vars(idx);
            end
        end
    end

    function labels = localPredictFromTable(tblIn, model)
        % Recibe una TABLE y devuelve etiquetas categóricas con el orden del entrenamiento.
        if ~istable(tblIn)
            error('La entrada a predictFcn debe ser una tabla (table).');
        end

        % Resolver nombres en la tabla de entrada contra los requeridos
        [resolvedIn, missingIn] = resolveNames(tblIn, model.RequiredFeatureNames);
        if ~isempty(missingIn)
            err = "Faltan columnas en la tabla de entrada:" + newline + join(string(missingIn), newline);
            error(err);
        end

        % Extraer X y estandarizar con mu/sigma del entrenamiento
        Xin = tblIn{:, resolvedIn};
        if any(any(isnan(Xin)))
            error('La tabla de entrada contiene NaNs en las columnas de características.');
        end
        Xin = (Xin - model.Mu) ./ model.Sigma;

        % Predecir
        labels = predict(model.ClassificationECOC, Xin);
        % Asegurar orden de clases consistente
        labels = categorical(labels, model.ClassOrder);
    end

    function labels = localPredictFromCSV(pathCSV, model)
        % Lee CSV preservando encabezados y llama a localPredictFromTable
        Tin = readPreserve(pathCSV);
        labels = localPredictFromTable(Tin, model);
    end

end
trainLogRegECOC('caracteristicas.csv');