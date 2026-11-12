---
name: plsql
description: 'Desarrollo PL/SQL en este repositorio: crear o modificar packages (.pks/.pkb), procedures, functions, triggers, vistas y tablas para Oracle eBS y APEX. Usar al escribir, revisar o depurar código PL/SQL, programas concurrentes de eBS, o al agregar objetos nuevos a eBS_DB o APEX_DB.'
---

# PL/SQL (TI Finanzas)

## Cuándo usar
- Crear o modificar packages, procedures, functions, vistas o tablas PL/SQL.
- Revisar o depurar código PL/SQL existente en `eBS_DB/` o `APEX_DB/`.
- Crear programas concurrentes para Oracle eBS.

## Estructura del repositorio
- `eBS_DB/<Módulo>/` — objetos de la base de eBS, por módulo: `AP`, `AR`, `GL`, `Cash`, `Utilities`, `iSupplier`.
- `APEX_DB/<Módulo>/` — objetos de la base de APEX.
- Dentro de cada módulo se agrupa por tipo: `Package/`, `Procedure/`, `Function/`, `Table/`, `View/`, `Materialized View/`, `Script/`.

## Convenciones de archivos
- Packages en dos archivos: especificación `.pks` y cuerpo `.pkb`, con el mismo nombre que el package.
- Functions sueltas: `.sql` o `.fnc`; tablas y vistas: `.sql`.
- Todo objeto se crea con `CREATE OR REPLACE` y esquema explícito (p. ej. `XXWEBC.`), terminando con `/` en línea propia.

## Convenciones de código
- Nombres de objetos custom con prefijo `XX` (p. ej. `XXAR_`, `XXAP_`, `XXGEPP_`) o `CUST_` según el módulo; sufijo `_PKG` para packages y `_TBL` para tablas cuando aplique.
- Parámetros con prefijo `p_` (entrada) y variables locales con `v_`; variables globales de package con `vg_`.
- Programas concurrentes de eBS: el procedure principal recibe `errbuf OUT VARCHAR2, retcode OUT NUMBER` como primeros parámetros (ver `MAIN_PROCEDURE` en [XXAR_CIERRE_IEPS.pks](../../eBS_DB/AR/Package/XXAR_CIERRE_IEPS.pks)).
- Logging a tablas custom mediante procedures de log dentro del package (p. ej. `XXLOG` en [XXAP_TRACKING_AP_PKG.pkb](../../eBS_DB/AP/Package/XXAP_TRACKING_AP_PKG.pkb)), con niveles 0=todo, 1=error, 2=warning, 3=message, 4=debug.
- Manejar excepciones con `EXCEPTION WHEN OTHERS` registrando `SQLERRM` en el log; en concurrentes asignar `retcode := 2` en error.
- Comentarios y mensajes en español.

## Procedimiento
1. Ubicar el módulo y tipo de objeto correctos (`eBS_DB/<Módulo>/<Tipo>/` o `APEX_DB/<Módulo>/<Tipo>/`).
2. Si es un package, actualizar siempre `.pks` y `.pkb` en conjunto y verificar que las firmas coincidan.
3. Seguir las convenciones de nombres y logging descritas arriba.
4. Usar sintaxis compatible con Oracle (sin extensiones de otros motores); validar la compilación en la base cuando haya conexión disponible (SQLcl).
