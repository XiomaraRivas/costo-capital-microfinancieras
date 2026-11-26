# Diccionario de variables

Archivo: `datos_procesados/datos_procesados_2024200520M.csv` · Frecuencia: **mensual** · Periodo: enero 2018 – diciembre 2025 · 3 289 observaciones (45 entidades, panel no balanceado).
Llave: `tipo` + `entidad` + `fecha`.

| Variable | Definición | Unidad | Frecuencia | Fuente exacta | URL o endpoint de origen |
|---|---|---|---|---|---|
| `tipo` | Tipo de entidad (Cajas Municipales, Cajas Rurales, Financieras, Empresas de Créditos) | texto | – | SBS | Página del boletín estadístico de cada tipo de entidad |
| `entidad` | Nombre de la entidad (el más reciente publicado por la SBS) | texto | mensual | SBS | Archivos C-1301, C-2301, B-3301, C-4301 |
| `fecha` | Primer día del mes de la observación | fecha (AAAA-MM-DD) | mensual | – | Construida a partir de `anio` y `mes` |
| `anio`, `mes` | Año y mes de la observación | número | mensual | – | – |
| `costo_fondeo` | Gastos financieros acumulados en el año, llevados a 12 meses, entre el pasivo total | % | mensual | Calculada con datos de la SBS | Archivos C-1101, C-2101, B-3101, C-4103 (Balance General y Estado de Ganancias y Pérdidas) |
| `morosidad` | Créditos atrasados (criterio SBS) entre créditos directos | % | mensual | SBS – Indicadores financieros | `https://intranet2.sbs.gob.pe/estadistica/financiera/{AÑO}/{Mes}/{C-1301 / C-2301 / B-3301 / C-4301}-{abrev}{AÑO}.XLS` |
| `roe` | Utilidad neta anualizada entre patrimonio promedio | % | mensual | SBS – Indicadores financieros | Ídem |
| `gastos_adm` | Gastos de administración anualizados (entre créditos directos en cajas y empresas de créditos; entre activo productivo en financieras) | % | mensual | SBS – Indicadores financieros | Ídem |
| `ratio_capital` | Ratio de capital global | % | mensual | SBS – Indicadores financieros | Ídem |
| `tamano` | Logaritmo natural del activo total | log (miles de S/) | mensual | Calculada con datos de la SBS | Archivos de estados financieros |
| `activo` | Total activo | miles de S/ | mensual | SBS – Balance General | `https://intranet2.sbs.gob.pe/estadistica/financiera/{AÑO}/{Mes}/{C-1101 / C-2101 / B-3101 / C-4103}-{abrev}{AÑO}.XLS` |
| `pasivo` | Total pasivo | miles de S/ | mensual | SBS – Balance General | Ídem |
| `patrimonio` | Patrimonio | miles de S/ | mensual | SBS – Balance General | Ídem |
| `gastos_fin` | Gastos financieros acumulados desde enero del año | miles de S/ | mensual | SBS – Estado de Ganancias y Pérdidas | Ídem |
| `tasa_referencia` | Tasa de referencia de la política monetaria | % | mensual | BCRPData, serie PD04722MM | `https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PD04722MM/json/2018-1/2025-12/esp` |
| `inflacion_12m` | Variación porcentual del IPC en 12 meses | % | mensual | BCRPData, serie PN01273PM | `https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PN01273PM/json/2018-1/2025-12/esp` |
| `atipico` | Marca de observación fuera de los percentiles 1–99 del costo de fondeo, la morosidad o el ROE (no se elimina) | lógica (TRUE/FALSE) | mensual | Calculada en `03_limpieza_datos.R` | – |
