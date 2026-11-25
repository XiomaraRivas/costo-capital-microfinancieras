# Costo de capital de las entidades microfinancieras del Perú y su relación con la morosidad

**Autora:** Rivas Ames, Xiomara Heydi (2024200520M)
**Curso:** Finanzas I (055D) – Unidad II – 2026-II
**Docente:** Dr. Machacuay Meza, Ciro Iván
**Universidad Nacional del Centro del Perú – Facultad de Economía**

## Objetivo
Evaluar si una mayor morosidad se traduce en un mayor costo de fondeo y en un cambio en el ROE de las cajas municipales, cajas rurales, financieras y empresas de créditos del Perú (2018–2025).

## Fuentes de datos
| Vía | Fuente | Qué se obtiene |
|---|---|---|
| 1. API | BCRPData (sin clave) | Tasa de referencia (PD04722MM) e inflación 12 meses (PN01273PM) |
| 2. Descarga programática | SBS – archivos Excel mensuales | Indicadores y estados financieros por entidad |

## Cómo reproducir
Ejecutar en R 4.5.1, en orden:
1. `01_extraccion_api.R`
2. `02_descarga_sbs.R` (unos 20 minutos)
3. `03_limpieza_datos.R`
4. `04_analisis.R`

Paquetes: `httr`, `jsonlite`, `readxl`, `writexl`, `digest`.
