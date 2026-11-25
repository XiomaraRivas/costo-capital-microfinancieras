# =====================================================================
#  01_extraccion_api.R
#  Vía 1: extracción por API (BCRPData)
#  Tema N.º 63: Costo de capital de las entidades microfinancieras
#               y su relación con la morosidad
#  Autora: Rivas Ames, Xiomara Heydi (2024200520M)
#  Finanzas I (055D) - Unidad II - 2026-II
# ---------------------------------------------------------------------
#  Qué hace:
#   Descarga de la API del BCRP dos series mensuales que sirven como
#   variables de control macroeconómico:
#     - PD04722MM: Tasa de referencia de la política monetaria (%)
#     - PN01273PM: Inflación, variación porcentual de 12 meses (%)
#   Guarda la respuesta original (JSON) y una tabla CSV/XLSX.
# =====================================================================

library(httr)
library(jsonlite)
library(writexl)
library(digest)

# ---------------------- PARÁMETROS FIJOS ------------------------------
FECHA_INICIO <- "2018-1"
FECHA_FIN    <- "2025-12"
SERIES       <- c(tasa_referencia = "PD04722MM",
                  inflacion_12m   = "PN01273PM")
USER_AGENT   <- "Xiomara Rivas Ames - UNCP Economia - Finanzas I (fines academicos)"
CARPETA      <- file.path("datos_crudos", "bcrp")
CODIGO_ALUMNA <- "2024200520M"

dir.create(CARPETA, recursive = TRUE, showWarnings = FALSE)
dir.create("logs", showWarnings = FALSE)

# ---------------------- CONSULTA A LA API -----------------------------
url <- sprintf("https://estadisticas.bcrp.gob.pe/estadisticas/series/api/%s/json/%s/%s/esp",
               paste(SERIES, collapse = "-"), FECHA_INICIO, FECHA_FIN)

resp <- GET(url, user_agent(USER_AGENT), timeout(60))
cat("Consulta BCRP:", url, "\nCódigo HTTP:", status_code(resp), "\n")
stop_for_status(resp)

texto <- content(resp, as = "text", encoding = "UTF-8")
ruta_json <- file.path(CARPETA, "bcrp_respuesta_original.json")
writeLines(texto, ruta_json, useBytes = TRUE)
Sys.sleep(1)

# ---------------------- CONVERSIÓN A TABLA ----------------------------
datos <- fromJSON(texto, simplifyVector = FALSE)
nombres_series <- sapply(datos$config$series, function(s) s$name)
cat("Series recibidas:\n"); print(nombres_series)

MESES_BCRP <- c(Ene = 1, Feb = 2, Mar = 3, Abr = 4, May = 5, Jun = 6,
                Jul = 7, Ago = 8, Sep = 9, Set = 9, Oct = 10, Nov = 11, Dic = 12)

filas <- lapply(datos$periods, function(p) {
  partes <- strsplit(p$name, "\\.")[[1]]          # ejemplo: "Ene.2018"
  valores <- suppressWarnings(as.numeric(unlist(p$values)))  # "n.d." -> NA
  data.frame(anio = as.integer(partes[2]),
             mes  = as.integer(MESES_BCRP[partes[1]]),
             periodo = p$name,
             tasa_referencia = valores[1],
             inflacion_12m   = valores[2])
})
bcrp <- do.call(rbind, filas)

write.csv(bcrp, file.path(CARPETA, paste0("datos_crudos_bcrp_", CODIGO_ALUMNA, ".csv")),
          row.names = FALSE)
write_xlsx(bcrp, file.path(CARPETA, paste0("datos_crudos_bcrp_", CODIGO_ALUMNA, ".xlsx")))

# ---------------------- LOG -------------------------------------------
log_api <- data.frame(fuente = "BCRPData API", url = url,
                      http = status_code(resp),
                      series = paste(SERIES, collapse = ", "),
                      observaciones = nrow(bcrp),
                      sha256_json = digest(ruta_json, algo = "sha256", file = TRUE),
                      fecha_descarga = as.character(Sys.time()))
write.csv(log_api, file.path("logs", "log_api_bcrp.csv"), row.names = FALSE)

cat("\nListo:", nrow(bcrp), "meses descargados (debería ser 96).\n")
print(head(bcrp)); print(tail(bcrp))
