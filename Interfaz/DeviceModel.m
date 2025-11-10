classdef DeviceModel < handle
    properties
        deviceName   string
        address      string           % dirección MAC o nombre
        position     double           % no usado, pero conservado
        callbackFcn  function_handle  % @(data,t) ... (opcional, para compatibilidad)
    end

    properties (SetAccess=private)
        b            % objeto ble
        cNotify      % characteristic FFE4 (notify)
        cWrite       % characteristic FFE9 (write)
        isOpen   logical = false

        % buffers de datos (ajústalos a tu formato real)
        tempBytes   uint8 = uint8([])
        timestamps  datetime = datetime.empty
        data_list   cell = {}

        % --- Buffers para datos parseados (como en tu app) ---
        accBuf double = []         % [N x 3] datos de Ax, Ay, Az (g)
        accIdx double = []         % [N x 1] índice de muestra
        tAcc_sec double = []       % tiempo relativo (s)
        dtAcc_sec double = []      % delta t entre muestras
        sampleCounterAcc double = 0

        gyrBuf double = []         % [N x 3] datos de Gx, Gy, Gz (°/s)
        gyrIdx double = []         % [N x 1] índice de muestra
        tGyr_sec double = []       % tiempo relativo (s)
        dtGyr_sec double = []      % delta t entre muestras
        sampleCounterGyr double = 0

        angBuf double = []         % [N x 3] datos de AngX, AngY, AngZ (°)
        angIdx double = []         % [N x 1] índice de muestra
        tAng_sec double = []       % tiempo relativo (s)
        dtAng_sec double = []      % delta t entre muestras

        startTime datetime = datetime.empty  % tiempo de inicio
    end

    properties (Constant)
        SERVICE_UUID = "0000FFE5-0000-1000-8000-00805F9A34FB";
        UUID_NOTIFY  = "0000FFE4-0000-1000-8000-00805F9A34FB";
        UUID_WRITE   = "0000FFE9-0000-1000-8000-00805F9A34FB";

        CALIB_ACCEL  = uint8([0xFF 0xAA 0x01 0x01 0x00]);
        CALIB_MAGNET = uint8([0xFF 0xAA 0x01 0x07 0x00]);
        EXIT_CALIB   = uint8([0xFF 0xAA 0x01 0x00 0x00]);
        SAVE_CFG     = uint8([0xFF 0xAA 0x00 0x00 0x00]);
        % Comandos adicionales para iniciar transmisión
        SET_RATE_100HZ = uint8([0xFF 0xAA 0x03 0x0D 0x00]);  % Configurar 100Hz
        START_CONTINUOUS = uint8([0xFF 0xAA 0x27 0x3A 0x00]); % Iniciar salida continua
    end

    methods
        function obj = DeviceModel(device_name, nameOrAddr, callback_method, position)
            fprintf("Inicializando modelo del dispositivo %s...\n", device_name);
            obj.deviceName  = string(device_name);
            obj.address     = string(nameOrAddr);
            obj.callbackFcn = callback_method;
            obj.position    = position;
        end

        function open_device(obj)
            % Conecta, descubre characteristics, suscribe notificaciones
            if obj.isOpen && ~isempty(obj.b) && isvalid(obj.b)
                fprintf("Ya estaba abierto: %s [%s]\n", obj.b.Name, obj.b.Address);
                return
            end

            fprintf("Abriendo dispositivo %s en posición %g...\n", obj.deviceName, obj.position);

            % 1) Conectar
            obj.b = ble(obj.address);
            obj.isOpen = true;
            obj.startTime = datetime('now');  % Inicializar tiempo de inicio
            fprintf("Conectado a: %s [%s]\n", obj.b.Name, obj.b.Address);

            % 2) Tomar characteristics por UUID de servicio + char
            obj.cNotify = characteristic(obj.b, obj.SERVICE_UUID, obj.UUID_NOTIFY);
            obj.cWrite  = characteristic(obj.b, obj.SERVICE_UUID, obj.UUID_WRITE);

            if isempty(obj.cNotify) || isempty(obj.cWrite)
                error('No se encontraron characteristics FFE4/FFE9 en FFE5.');
            end

            % 3) Reset buffers
            obj.resetBuffers();

            % 4) Enviar comandos para configurar e iniciar transmisión
            obj.send_command(obj.EXIT_CALIB); pause(0.2);
            obj.send_command(obj.SET_RATE_100HZ); pause(0.2);
            obj.send_command(obj.START_CONTINUOUS); pause(0.5);

            % 5) Suscribirse a notificaciones
            subscribe(obj.cNotify, 'notification', @(src,evt)obj.on_data_received(evt));

            fprintf("Notificaciones activadas en %s\n", obj.UUID_NOTIFY);
        end

        function calibrate_magnetometer(obj, rotSeconds)
            if nargin < 2, rotSeconds = 10; end
            if ~obj.isReady()
                error('No hay conexión BLE ni characteristics asignadas.');
            end
            obj.send_command(obj.CALIB_MAGNET);
            fprintf("Iniciando calibración del magnetómetro. Gira 360° en X/Y/Z...\n");
            pause(rotSeconds);
            obj.send_command(obj.EXIT_CALIB);
            pause(0.3);
            obj.send_command(obj.SAVE_CFG);
            fprintf("Calibración magnética completada y guardada.\n");
        end

        function calibrate_accelerometer(obj, holdSeconds)
            if nargin < 2, holdSeconds = 2; end
            if ~obj.isReady()
                error('No hay conexión BLE ni characteristics asignadas.');
            end
            obj.send_command(obj.CALIB_ACCEL);
            pause(holdSeconds);
            obj.send_command(obj.EXIT_CALIB);
            pause(0.3);
            obj.send_command(obj.SAVE_CFG);
            fprintf("Calibración de acelerómetro completada y guardada.\n");
        end

        function collect_data(obj, secondsToCollect)
            if nargin < 2, secondsToCollect = 10; end
            if ~obj.isReady()
                error('No hay conexión BLE ni notificaciones activas.');
            end
            fprintf("Recopilando datos durante %d s...\n", secondsToCollect);
            pause(secondsToCollect);
            fprintf("Fin de recopilación. Datos acumulados: ACC=%d, GYR=%d, ANG=%d\n", ...
                size(obj.accBuf,1), size(obj.gyrBuf,1), size(obj.angBuf,1));
        end

        function data = getData(obj)
            % Devuelve los buffers para guardar en la app
            data = struct('accBuf', obj.accBuf, 'accIdx', obj.accIdx, 'tAcc_sec', obj.tAcc_sec, ...
                          'gyrBuf', obj.gyrBuf, 'gyrIdx', obj.gyrIdx, 'tGyr_sec', obj.tGyr_sec, ...
                          'angBuf', obj.angBuf, 'angIdx', obj.angIdx, 'tAng_sec', obj.tAng_sec, ...
                          'startTime', obj.startTime);
        end

        function close(obj)
            % Detener notificaciones y cerrar
            if ~isempty(obj.cNotify)
                try unsubscribe(obj.cNotify); catch, end
            end
            if ~isempty(obj.b) && isvalid(obj.b)
                try delete(obj.b); catch, end
            end
            obj.isOpen = false;
            obj.b      = [];
            obj.cNotify= [];
            obj.cWrite = [];
            fprintf("Dispositivo cerrado.\n");
        end
    end

    methods (Access=private)
        function tf = isReady(obj)
            tf = obj.isOpen && ~isempty(obj.b) && isvalid(obj.b) ...
                 && ~isempty(obj.cWrite) && ~isempty(obj.cNotify);
        end

        function send_command(obj, bytes5)
            % Enviar 5 bytes por FFE9 (sin respuesta)
            write(obj.cWrite, uint8(bytes5), 'withoutresponse');
        end

        function resetBuffers(obj)
            obj.accBuf = zeros(0,3); obj.accIdx = zeros(0,1); obj.sampleCounterAcc = 0;
            obj.gyrBuf = zeros(0,3); obj.gyrIdx = zeros(0,1); obj.sampleCounterGyr = 0;
            obj.angBuf = zeros(0,3); obj.angIdx = zeros(0,1);
            obj.tAcc_sec = []; obj.dtAcc_sec = [];
            obj.tGyr_sec = []; obj.dtGyr_sec = [];
            obj.tAng_sec = []; obj.dtAng_sec = [];
            obj.tempBytes = uint8([]); obj.timestamps = datetime.empty; obj.data_list = {};
        end

        function on_data_received(obj, evt)
            % evt.Data (uint8), evt.Timestamp (datetime)
            raw = evt.Data;
            ts  = evt.Timestamp;

            % DEBUG: Imprimir bytes recibidos
            fprintf('Bytes recibidos: %d - Hex: %s\n', numel(raw), num2str(raw, '%02X '));

            % Acumula en buffers simples
            obj.tempBytes = [obj.tempBytes; raw(:)]; %#ok<AGROW>
            obj.timestamps(end+1,1) = ts;           %#ok<AGROW>

            % Parsing de frames (adaptado de tu app)
            obj.parseData(raw, ts);

            % Callback opcional
            if ~isempty(obj.callbackFcn)
                try
                    obj.callbackFcn(raw, ts);
                catch
                    % evita romper la suscripción
                end
            end
        end

        function parseData(obj, bytes, ts)
            % Adaptación del código de onBleData para parsear frames
            bytes = uint8(bytes(:)).';   % fila
            persistent rxBuf
            if isempty(rxBuf), rxBuf = uint8([]); end
            rxBuf = [rxBuf, bytes]; %#ok<AGROW>

            tRel = seconds(ts - obj.startTime);

            i = 1;
            while i <= numel(rxBuf)
                rem = numel(rxBuf) - i + 1;

                % Formato A: 11B 0x55
                if rem >= 11 && rxBuf(i) == hex2dec('55')
                    fr = rxBuf(i:i+10);
                    id = fr(2);
                    switch id
                        case hex2dec('51') % ACC
                            ax = typecast(uint8(fr(3:4)),'int16'); ay = typecast(uint8(fr(5:6)),'int16'); az = typecast(uint8(fr(7:8)),'int16');
                            acc = double([ax ay az]) / 32768 * 16;
                            obj.sampleCounterAcc = obj.sampleCounterAcc + 1;
                            obj.accBuf(end+1,:) = acc; obj.accIdx(end+1,1) = obj.sampleCounterAcc;
                            if isempty(obj.tAcc_sec), obj.tAcc_sec = tRel; obj.dtAcc_sec = NaN;
                            else, obj.tAcc_sec(end+1,1) = tRel; obj.dtAcc_sec(end+1,1) = diff([obj.tAcc_sec(end-1); obj.tAcc_sec(end)]);
                            end
                        case hex2dec('52') % GYRO
                            gx = typecast(uint8(fr(3:4)),'int16'); gy = typecast(uint8(fr(5:6)),'int16'); gz = typecast(uint8(fr(7:8)),'int16');
                            gyr = double([gx gy gz]) / 32768 * 2000;
                            obj.sampleCounterGyr = obj.sampleCounterGyr + 1;
                            obj.gyrBuf(end+1,:) = gyr; obj.gyrIdx(end+1,1) = obj.sampleCounterGyr;
                            if isempty(obj.tGyr_sec), obj.tGyr_sec = tRel; obj.dtGyr_sec = NaN;
                            else, obj.tGyr_sec(end+1,1) = tRel; obj.dtGyr_sec(end+1,1) = diff([obj.tGyr_sec(end-1); obj.tGyr_sec(end)]);
                            end
                        case hex2dec('53') % ANG
                            angx = typecast(uint8(fr(3:4)),'int16'); angy = typecast(uint8(fr(5:6)),'int16'); angz = typecast(uint8(fr(7:8)),'int16');
                            ang = double([angx angy angz]) / 32768 * 180;
                            obj.angBuf(end+1,:) = ang; obj.angIdx(end+1,1) = size(obj.angBuf,1);
                            if isempty(obj.tAng_sec), obj.tAng_sec = tRel; obj.dtAng_sec = NaN;
                            else, obj.tAng_sec(end+1,1) = tRel; obj.dtAng_sec(end+1,1) = diff([obj.tAng_sec(end-1); obj.tAng_sec(end)]);
                            end
                    end
                    i = i + 11; continue;
                end

                % Formato B: 20B 0x61
                if rem >= 20 && rxBuf(i+1) == hex2dec('61')
                    fr20 = rxBuf(i:i+19);
                    ax = obj.getSigned16(bitor(bitshift(uint16(fr20(4)),8), uint16(fr20(3))));
                    ay = obj.getSigned16(bitor(bitshift(uint16(fr20(6)),8), uint16(fr20(5))));
                    az = obj.getSigned16(bitor(bitshift(uint16(fr20(8)),8), uint16(fr20(7))));
                    gx = obj.getSigned16(bitor(bitshift(uint16(fr20(10)),8), uint16(fr20(9))));
                    gy = obj.getSigned16(bitor(bitshift(uint16(fr20(12)),8), uint16(fr20(11))));
                    gz = obj.getSigned16(bitor(bitshift(uint16(fr20(14)),8), uint16(fr20(13))));
                    axg = double(ax)/32768*16; ayg = double(ay)/32768*16; azg = double(az)/32768*16;
                    gxd = double(gx)/32768*2000; gyd = double(gy)/32768*2000; gzd = double(gz)/32768*2000;
                    angx = obj.getSigned16(bitor(bitshift(uint16(fr20(16)),8), uint16(fr20(15))));
                    angy = obj.getSigned16(bitor(bitshift(uint16(fr20(18)),8), uint16(fr20(17))));
                    angz = obj.getSigned16(bitor(bitshift(uint16(fr20(20)),8), uint16(fr20(19))));
                    ang = double([angx angy angz])/32768*180;

                    obj.sampleCounterAcc = obj.sampleCounterAcc + 1;
                    obj.accBuf(end+1,:) = [axg ayg azg]; obj.accIdx(end+1,1) = obj.sampleCounterAcc;
                    if isempty(obj.tAcc_sec), obj.tAcc_sec = tRel; obj.dtAcc_sec = NaN;
                    else, obj.tAcc_sec(end+1,1) = tRel; obj.dtAcc_sec(end+1,1) = diff([obj.tAcc_sec(end-1); obj.tAcc_sec(end)]);
                    end

                    obj.sampleCounterGyr = obj.sampleCounterGyr + 1;
                    obj.gyrBuf(end+1,:) = [gxd gyd gzd]; obj.gyrIdx(end+1,1) = obj.sampleCounterGyr;
                    if isempty(obj.tGyr_sec), obj.tGyr_sec = tRel; obj.dtGyr_sec = NaN;
                    else, obj.tGyr_sec(end+1,1) = tRel; obj.dtGyr_sec(end+1,1) = diff([obj.tGyr_sec(end-1); obj.tGyr_sec(end)]);
                    end

                    obj.angBuf(end+1,:) = ang; obj.angIdx(end+1,1) = size(obj.angBuf,1);
                    if isempty(obj.tAng_sec), obj.tAng_sec = tRel; obj.dtAng_sec = NaN;
                    else, obj.tAng_sec(end+1,1) = tRel; obj.dtAng_sec(end+1,1) = diff([obj.tAng_sec(end-1); obj.tAng_sec(end)]);
                    end

                    i = i + 20; continue;
                end
                break;
            end
            rxBuf = rxBuf(i:end);
        end

        function s = get
        end 
    end 
end