---
name: oracle-apex
description: 'Desarrollo con Oracle APEX: objetos de BD en APEX_DB/, APIs de APEX (APEX_JSON, APEX_JWT, APEX_AUTHENTICATION, APEX_DEBUG, APEX_APPLICATION), SQL para reportes interactivos y LOVs, autenticación custom y páginas/procesos APEX. Usar al crear, revisar o depurar código PL/SQL que corre dentro de APEX o que da soporte a aplicaciones APEX.'
---

# Oracle APEX (TI Finanzas)

## Cuándo usar
- Crear o modificar packages, vistas o tablas que dan soporte a aplicaciones APEX (`APEX_DB/`).
- Escribir SQL para reportes interactivos (IR/IG), gráficas o LOVs de APEX.
- Trabajar con APIs de APEX: `APEX_JSON`, `APEX_JWT`, `APEX_AUTHENTICATION`, `APEX_APPLICATION`, `APEX_DEBUG`, `APEX_UTIL`, `APEX_COLLECTION`, `APEX_MAIL`.
- Implementar autenticación/autorización custom (sentry functions, JWT, post_login).

## Estructura del repositorio
- `APEX_DB/<Módulo>/<Tipo>/` — objetos de la base de APEX, por módulo (`Cash`, `Utilities`, etc.) y tipo (`Package/`, `Table/`, `View/`, ...).
- Seguir las mismas convenciones de PL/SQL del repo (skill `plsql`): prefijo `XX`, packages en `.pks`/`.pkb`, `CREATE OR REPLACE`, parámetros `p_`, variables `v_`.
- Esquemas usados en APEX_DB: algunos objetos llevan esquema explícito (p. ej. `CFDI_AP_AR.`) y otros se crean en el parsing schema; respetar el estilo del objeto existente al modificarlo.

## Convenciones APEX
- Nombres de objetos de soporte APEX con prefijo `XXAPEX_` o `XX<MÓDULO>_APEX_` (p. ej. [XXCASH_APEX_CASHLESS_PKG.pks](../../../APEX_DB/Cash/Pakage/XXCASH_APEX_CASHLESS_PKG.pks), [XXAPEX_WORKSPACE_APEX_USERS.sql](../../../APEX_DB/Utilities/Table/XXAPEX_WORKSPACE_APEX_USERS.sql)).
- JSON: usar `APEX_JSON` (`parse`, `get_varchar2`, `stringify`) para construir/leer payloads; ver [XXUTILITIES_JWT.pkb](../../../APEX_DB/Utilities/Package/XXUTILITIES_JWT.pkb).
- Autenticación custom con JWT: `apex_jwt.encode/decode/validate` + `apex_authentication.post_login` y `apex_authentication.is_public_user`, siguiendo el patrón de `XXUTILITIES_JWT`.
- Usuario de sesión: `apex_application.g_user`; ítems de página vía bind variables (`:P1_ITEM`) o `v('ITEM')` en objetos de BD.
- Depuración: `apex_debug.trace/error` además del logging a tablas custom del repo.
- En procesos AJAX (`apex_application.g_x01..g_x10`) devolver JSON con `APEX_JSON` y manejar errores con `EXCEPTION WHEN OTHERS` registrando `SQLERRM`.
- Comentarios y mensajes en español.

## SQL para APEX
- Reportes interactivos / Interactive Grid: queries con alias de columna estables (no `SELECT *`), sin `ORDER BY` fijo salvo necesidad (APEX lo administra).
- LOVs: devolver dos columnas `display_value, return_value` (en ese orden).
- Vistas en `APEX_DB/<Módulo>/View/` cuando el query sea complejo o se reutilice entre páginas.

## Procedimiento
1. Ubicar el módulo correcto en `APEX_DB/<Módulo>/<Tipo>/`; si no existe el tipo, crear la carpeta siguiendo la estructura actual.
2. Si es un package, actualizar `.pks` y `.pkb` en conjunto y verificar que las firmas coincidan.
3. Reutilizar las APIs de APEX en lugar de reimplementar (JSON, JWT, mail, colecciones).
4. Validar la compilación en la base cuando haya conexión disponible (SQLcl) y probar el objeto desde una sesión APEX si aplica.
