# Autora: Xiomara Heydi Rivas Ames
# Código de matrícula: 2024200520M
# Tema N.º 63 del temario: Costo de capital de las entidades microfinancieras y su relación con la morosidad
# Fecha de extracción: SBS 22/11/2026 · BCRP 24/11/2026 (fecha de corte de los datos: 31/12/2025)
# =====================================================================
#  02_scraping_web.R
#  Vía 2: descarga programática de archivos Excel publicados por la SBS
#  Tema N.º 63: Costo de capital de las entidades microfinancieras
#               y su relación con la morosidad
#  Autora: Rivas Ames, Xiomara Heydi (2024200520M)
#  Finanzas I (055D) - Unidad II - 2026-II
# ---------------------------------------------------------------------
#  Qué hace:
#   Descarga, mes por mes (enero 2018 - diciembre 2025), dos archivos
#   para cada tipo de entidad microfinanciera:
#     - Indicadores financieros (morosidad, ROE, gastos, ratio de capital)
#     - Balance General y Estado de Ganancias y Pérdidas (costo de fondeo)
#   Guarda cada archivo sin modificar en datos_crudos/sbs/ y registra en
#   un log la URL, la fecha de descarga, el código HTTP y el hash SHA-256.
# =====================================================================

library(httr)
library(digest)

# ---------------------- PARÁMETROS FIJOS ------------------------------
FECHA_INICIO <- 2018   # enero de 2018
FECHA_CORTE  <- 2025   # diciembre de 2025
URL_BASE    <- "https://intranet2.sbs.gob.pe/estadistica/financiera"
CARPETA     <- file.path("datos_crudos", "sbs")
PAUSA       <- 1      # segundos entre descargas (respeto al servidor)
USER_AGENT  <- "Xiomara Rivas Ames - UNCP Economia - Finanzas I (fines academicos)"

# Códigos de archivo de la SBS (verificados en la web de la SBS el 22/11/2026)
CODIGOS <- data.frame(
  tipo    = c("Cajas Municipales", "Cajas Municipales",
              "Cajas Rurales",     "Cajas Rurales",
              "Financieras",       "Financieras",
              "Empresas de Creditos", "Empresas de Creditos"),
  archivo = c("indicadores", "estados_financieros",
              "indicadores", "estados_financieros",
              "indicadores", "estados_financieros",
              "indicadores", "estados_financieros"),
  codigo  = c("C-1301", "C-1101",
              "C-2301", "C-2101",
              "B-3301", "B-3101",
              "C-4301", "C-4103"),
  stringsAsFactors = FALSE
)

# Nombre de la carpeta del mes y abreviatura que usa la SBS en el archivo.
# Si la primera abreviatura no existe, el código prueba las siguientes.
MESES <- list(
  list(nombre = "Enero",     abrev = c("en")),
  list(nombre = "Febrero",   abrev = c("fe")),
  list(nombre = "Marzo",     abrev = c("ma")),
  list(nombre = "Abril",     abrev = c("ab")),
  list(nombre = "Mayo",      abrev = c("my", "may")),
  list(nombre = "Junio",     abrev = c("jn", "jun")),
  list(nombre = "Julio",     abrev = c("jl", "jul")),
  list(nombre = "Agosto",    abrev = c("ag")),
  list(nombre = "Setiembre", abrev = c("se", "set", "st")),
  list(nombre = "Octubre",   abrev = c("oc")),
  list(nombre = "Noviembre", abrev = c("no")),
  list(nombre = "Diciembre", abrev = c("di"))
)

dir.create(CARPETA, recursive = TRUE, showWarnings = FALSE)
dir.create("logs", showWarnings = FALSE)

# ---------------------- REGISTRO EN log_ejecucion.txt -----------------
# Escribe cada mensaje en la consola y en log_ejecucion.txt, con fecha y hora
registrar <- function(...) {
  linea <- paste0(format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " | ", paste0(...))
  cat(linea, "\n")
  cat(linea, "\n", file = "log_ejecucion.txt", append = TRUE)
}

# ---------------------- FUNCIÓN DE DESCARGA ---------------------------
descargar_un_archivo <- function(anio, mes, codigo) {
  for (ab in mes$abrev) {
    nombre  <- sprintf("%s-%s%d.XLS", codigo, ab, anio)
    url     <- sprintf("%s/%d/%s/%s", URL_BASE, anio, mes$nombre, nombre)
    destino <- file.path(CARPETA, nombre)

    # Si ya se descargó antes, no se vuelve a pedir al servidor
    if (file.exists(destino) && file.size(destino) > 1000) {
      return(data.frame(url = url, archivo = nombre, http = 200,
                        bytes = file.size(destino),
                        sha256 = digest(destino, algo = "sha256", file = TRUE),
                        estado = "ya existia", fecha_descarga = as.character(Sys.time())))
    }

    resp <- tryCatch(
      GET(url, user_agent(USER_AGENT), timeout(60), write_disk(destino, overwrite = TRUE)),
      error = function(e) NULL
    )
    Sys.sleep(PAUSA)

    if (!is.null(resp) && status_code(resp) == 200 && file.size(destino) > 1000) {
      return(data.frame(url = url, archivo = nombre, http = 200,
                        bytes = file.size(destino),
                        sha256 = digest(destino, algo = "sha256", file = TRUE),
                        estado = "descargado", fecha_descarga = as.character(Sys.time())))
    }
    if (file.exists(destino)) file.remove(destino)   # borra descargas fallidas
    ultimo_http <- if (is.null(resp)) NA else status_code(resp)
  }
  data.frame(url = url, archivo = nombre, http = ultimo_http, bytes = NA,
             sha256 = NA, estado = "no disponible",
             fecha_descarga = as.character(Sys.time()))
}

# ---------------------- BUCLE PRINCIPAL -------------------------------
registros <- list()
for (anio in FECHA_INICIO:FECHA_CORTE) {
  for (m in seq_along(MESES)) {
    for (i in seq_len(nrow(CODIGOS))) {
      r <- descargar_un_archivo(anio, MESES[[m]], CODIGOS$codigo[i])
      r$anio <- anio; r$mes <- m
      r$tipo <- CODIGOS$tipo[i]; r$contenido <- CODIGOS$archivo[i]
      registros[[length(registros) + 1]] <- r
      registrar(sprintf("02_scraping_web | SBS | %d-%02d | %s | %s | HTTP %s | %s",
                        anio, m, CODIGOS$tipo[i], r$archivo, r$http, r$estado))
    }
  }
}

log_sbs <- do.call(rbind, registros)
log_sbs <- log_sbs[, c("anio", "mes", "tipo", "contenido", "archivo", "url",
                       "http", "bytes", "sha256", "estado", "fecha_descarga")]
write.csv(log_sbs, file.path("logs", "log_descarga_sbs.csv"), row.names = FALSE)

# ---------------------- RESUMEN ---------------------------------------
cat("\n================ RESUMEN ================\n")
print(table(log_sbs$tipo, log_sbs$estado))
cat("Archivos esperados:", nrow(log_sbs), "\n")
cat("Archivos disponibles:", sum(log_sbs$estado != "no disponible"), "\n")
registrar("02_scraping_web | SBS | archivos descargados: ", sum(log_sbs$estado != "no disponible"), " de ", nrow(log_sbs))
