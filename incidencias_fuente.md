# Registro de incidencias de las fuentes

| Fecha y hora (Lima) | Fuente / URL | Respuesta | Descripción | Solución |
|---|---|---|---|---|
| 21/11/2026, 00:28–00:33 | `https://intranet2.sbs.gob.pe/estadistica/financiera/2025/Enero/C-1301-en2025.XLS` | "Error 20 – The proxy failed to connect to the web server, due to TCP connection timeout" y luego `ERR_HTTP2_PROTOCOL_ERROR` | El servidor de estadísticas de la SBS no respondió durante la madrugada; la caída afectaba incluso a archivos descargados antes con éxito. | Caída temporal del servidor. Se reintentó el 22/11/2026 y el servidor respondió con normalidad (HTTP 200). No fue necesario sustituir la fuente. |
| 22/11/2026, 00:24 | `https://intranet2.sbs.gob.pe/estadistica/financiera/2025/Enero/C-4101-en2025.XLS` | HTTP 404 | El código de archivo supuesto para los estados financieros de las empresas de créditos no existe. | Se identificó en el portal de la SBS que el código correcto es **C-4103**. |
