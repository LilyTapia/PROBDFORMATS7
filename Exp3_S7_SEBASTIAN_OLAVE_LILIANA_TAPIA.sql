----------------------------------------------------------------------------------------------------
--                            SEBASTIÁN OLAVE- LILIANA TAPIA                                      --
----------------------------------------------------------------------------------------------------


-- CREAMOS EL PAQUETE paquete_multas
CREATE OR REPLACE PACKAGE paquete_multas AS
  -- FUNCIÓN con la cual obtenemos el valor de descuento de la multa para pacientes mayores de 70 años
  FUNCTION obtener_descuento_multa(edad_paciente IN NUMBER) RETURN NUMBER;

  -- Variable pública para almacenar el valor de la multa
  v_valor_multa NUMBER;

  -- Variable pública para almacenar el valor de descuento de la multa para pacientes mayores de 70 años
  v_valor_descuento NUMBER;
END paquete_multas;
/

-- Creamos el cuerpo del paquete para la gestión de multas
CREATE OR REPLACE PACKAGE BODY paquete_multas AS
  -- FUNCIÓN para obtener el valor de descuento de la multa para pacientes mayores de 70 años
  FUNCTION obtener_descuento_multa(edad_paciente IN NUMBER) RETURN NUMBER IS
    v_porcentaje_descuento NUMBER;
  BEGIN
    -- Obtenemos el porcentaje de descuento según la edad del paciente
    SELECT porcentaje_descto
    INTO v_porcentaje_descuento
    FROM PORC_DESCTO_3RA_EDAD
    WHERE edad_paciente BETWEEN anno_ini AND anno_ter;

    -- Devolver el porcentaje de descuento
    RETURN v_porcentaje_descuento;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- Si no se encuentra un descuento para la edad del paciente, devuelve 0
      RETURN 0;
  END obtener_descuento_multa;
BEGIN
  -- Inicializamos el valor de la multa
  v_valor_multa:= 0;

  -- Inicializamos el valor de descuento de la multa
  v_valor_descuento:= 0;
END paquete_multas;
/

-- FUNCIÓN ALMACENADA para obtener el nombre de la especialidad de la atención médica
CREATE OR REPLACE FUNCTION obtener_nombre_especialidad(id_especialidad IN NUMBER) RETURN VARCHAR2 IS
  v_nombre_especialidad VARCHAR2(25);
BEGIN
  -- Obtenemos el nombre de la especialidad desde la tabla ESPECIALIDAD
  SELECT nombre
  INTO v_nombre_especialidad
  FROM ESPECIALIDAD
  WHERE esp_id = id_especialidad;

  -- Devolvemos el nombre de la especialidad
  RETURN v_nombre_especialidad;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    -- Si no se encuentra la especialidad, devolver un mensaje de error
    RETURN 'Especialidad no encontrada';
END obtener_nombre_especialidad;
/

-- PROCEDIMIENTO ALMACENADO para generar la información de todas las atenciones médicas que fueron pagadas fuera de plazo el año anterior
CREATE OR REPLACE PROCEDURE generar_info_atenciones_morosas AS
  -- Declaración de un VARRAY para almacenar los valores de las multas por días de atraso
  TYPE varray_multas IS VARRAY(7) OF NUMBER;
  v_multas varray_multas;

  -- Declaración de variables para almacenar los datos de la atención médica
  v_pac_run          NUMBER(8);
  v_pac_dv_run       VARCHAR(1);
  v_pac_nombre       VARCHAR2(50);
  v_ate_id           NUMBER(3);
  v_fecha_venc_pago  DATE;
  v_fecha_pago       DATE;
  v_dias_morosidad   NUMBER(3);
  v_especialidad     VARCHAR2(30);
  v_costo_atencion   NUMBER(8);
  v_monto_multa      NUMBER(6);
  v_observacion      VARCHAR2(100);
  v_edad_paciente    NUMBER;
  v_descuento        NUMBER;
BEGIN
  -- Inicializamos el VARRAY con los valores de las multas por especialidad
  v_multas:= varray_multas(1200, 1300, 1700, 1900, 1100, 2000, 2300);

  -- Truncamos la tabla PAGO_MOROSO
  EXECUTE IMMEDIATE 'TRUNCATE TABLE PAGO_MOROSO';

  -- Obtenemos la información de las atenciones médicas morosas del año anterior
  FOR rec IN (
    SELECT
      p.pac_run,
      p.dv_run,
      p.pnombre || ' ' || p.snombre || ' ' || p.apaterno || ' ' || p.amaterno AS pac_nombre,
      a.ate_id,
      pa.fecha_venc_pago,
      pa.fecha_pago,
      pa.fecha_pago - pa.fecha_venc_pago AS dias_morosidad,
      m.esp_id,
      a.costo AS costo_atencion,
      p.fecha_nacimiento
    FROM PACIENTE p
    JOIN ATENCION a
      ON p.pac_run = a.pac_run
    JOIN PAGO_ATENCION pa
      ON a.ate_id = pa.ate_id
    JOIN MEDICO m
      ON a.med_run = m.med_run
    WHERE
      EXTRACT(YEAR FROM pa.fecha_pago) = EXTRACT(YEAR FROM SYSDATE) - 1
      AND pa.fecha_pago > pa.fecha_venc_pago
  ) LOOP
    -- Asignamos los valores de la atención médica a las variables
    v_pac_run:= rec.pac_run;
    v_pac_dv_run:= rec.dv_run;
    v_pac_nombre:= rec.pac_nombre;
    v_ate_id:= rec.ate_id;
    v_fecha_venc_pago:= rec.fecha_venc_pago;
    v_fecha_pago:= rec.fecha_pago;
    v_dias_morosidad:= rec.dias_morosidad;
    v_especialidad:= obtener_nombre_especialidad(rec.esp_id);
    v_costo_atencion:= rec.costo_atencion;
    v_edad_paciente:= EXTRACT(YEAR FROM rec.fecha_venc_pago) - EXTRACT(YEAR FROM rec.fecha_nacimiento);

    -- Calculamos la multa según la especialidad
    CASE rec.esp_id
      WHEN 100 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(1);
      WHEN 200 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(2);
      WHEN 300 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(3);
      WHEN 400 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(4);
      WHEN 500 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(5);
      WHEN 600 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(6);
      WHEN 700 THEN
        v_monto_multa:= v_dias_morosidad * v_multas(7);
      ELSE
        v_monto_multa:= 0;
    END CASE;

    -- Aplicamos lógica de descuento si el paciente es mayor de 70 años
    IF v_edad_paciente > 70 THEN
      v_descuento:= paquete_multas.obtener_descuento_multa(v_edad_paciente);
      v_monto_multa:= v_monto_multa * (1 - v_descuento / 100);
      v_observacion:= 'Paciente tenía ' || v_edad_paciente || ' a la fecha de atención. Se aplicó descuento paciente mayor a 70 años';
    END IF;

    -- Insertamos la información en la tabla PAGO_MOROSO
    INSERT INTO PAGO_MOROSO (
      pac_run,
      pac_dv_run,
      pac_nombre,
      ate_id,
      fecha_venc_pago,
      fecha_pago,
      dias_morosidad,
      especialidad_atencion,
      costo_atencion,
      monto_multa,
      observacion
    ) VALUES (
      v_pac_run,
      v_pac_dv_run,
      v_pac_nombre,
      v_ate_id,
      v_fecha_venc_pago,
      v_fecha_pago,
      v_dias_morosidad,
      v_especialidad,
      v_costo_atencion,
      v_monto_multa,
      v_observacion
    );
  END LOOP;

  -- Confirmamos con commit
  COMMIT;
END generar_info_atenciones_morosas;
/

EXECUTE generar_info_atenciones_morosas;

-- Consulta para comprobar los resultados en la tabla PAGO_MOROSO
SELECT * FROM pago_moroso;
