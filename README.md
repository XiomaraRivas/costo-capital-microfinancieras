# Costo de capital de las entidades microfinancieras del Perú y su relación con la morosidad

| | |
|---|---|
| **Autora** | Xiomara Heydi Rivas Ames |
| **Código de matrícula** | 2024200520M |
| **Tema del temario** | N.º 63 – Costo de capital de las entidades microfinancieras y su relación con la morosidad |
| **Curso** | Finanzas I (055D) – Unidad II – Semestre 2026-II |
| **Docente** | Dr. Ciro Iván Machacuay Meza |
| **Institución** | Universidad Nacional del Centro del Perú – Facultad de Economía |

**Repositorio:** https://github.com/XiomaraRivas/costo-capital-microfinancieras
**Dashboard interactivo:** https://xiomararivas.github.io/costo-capital-microfinancieras/

## Objetivo

Evaluar si una mayor morosidad de la cartera se traduce en un mayor costo de fondeo y en un cambio en la rentabilidad del patrimonio (ROE) de las cajas municipales, cajas rurales, empresas financieras y empresas de créditos del Perú.

## Fuentes y endpoints

| Vía | Fuente | Endpoint | Qué se obtiene |
|---|---|---|---|
| 1. API | BCRPData (no requiere clave) | `https://estadisticas.bcrp.gob.pe/estadisticas/series/api/PD04722MM-PN01273PM/json/2018-1/2025-12/esp` | Tasa de referencia de la política monetaria (PD04722MM) e inflación a 12 meses (PN01273PM) |
| 2. Descarga programática | SBS – Información estadística | `https://intranet2.sbs.gob.pe/estadistica/financiera/{AÑO}/{Mes}/{CÓDIGO}-{abreviatura}{AÑO}.XLS` | Indicadores financieros (C-1301, C-2301, B-3301, C-4301) y estados financieros (C-1101, C-2101, B-3101, C-4103) por entidad |

Llave común para unir las fuentes: **año y mes** (y, dentro de la SBS, **tipo de entidad + entidad + año + mes**).

## Periodo y fecha de corte

- `FECHA_INICIO`: enero de 2018
- `FECHA_CORTE`: diciembre de 2025
- Fechas de extracción: SBS el 22/11/2026; BCRP el 24/11/2026.

## Orden de ejecución

Abrir el proyecto en RStudio (la carpeta del proyecto es el directorio de trabajo) y ejecutar, en este orden:

1. `codigo/01_extraccion_api.R` – descarga las series del BCRP por API.
2. `codigo/02_scraping_web.R` – descarga los 768 archivos de la SBS (8 códigos × 96 meses; unos 20 minutos por la pausa de 1 segundo entre solicitudes).
3. `codigo/03_limpieza_datos.R` – lee los archivos, une las fuentes, revisa faltantes y atípicos y genera `datos_procesados/datos_procesados_2024200520M.csv`.
4. `codigo/04_analisis.R` – genera las tablas y figuras del artículo en `/salidas`.
5. (Opcional) `dashboard/dashboard.Rmd` – botón **Knit** para generar el dashboard interactivo.

## Versión del lenguaje y librerías

- R 4.5.1
- Paquetes: `httr`, `jsonlite`, `digest`, `readxl`, `writexl` (análisis) y `flexdashboard`, `plotly`, `DT` (dashboard).
- Versiones exactas en `sessionInfo.txt`.
- Ninguna de las fuentes requiere clave de acceso (ver `.env.example`).

## Resultado principal

Con un panel de 45 entidades, 96 meses y 3 289 observaciones, y regresiones con efectos fijos por entidad, la morosidad **no** tiene un efecto significativo sobre el costo de fondeo (que depende de la tasa de referencia del BCRP: +0.22 por punto), pero **sí reduce el ROE en 1.76 puntos** por cada punto de morosidad.

## Integridad

Hash SHA-256 de `datos_procesados/datos_procesados_2024200520M.csv`:

```
1b7c992d5e08fe39ce0c78955404bc6d50e7d20ee760f576d2cfbe3e1f58b15c
```
