# =====================================================================
#  03_limpieza_datos.R
#  Limpieza, unión y construcción del panel de microfinancieras
#  Tema N.º 63: Costo de capital de las entidades microfinancieras
#               y su relación con la morosidad
#  Autora: Rivas Ames, Xiomara Heydi (2024200520M)
#  Finanzas I (055D) - Unidad II - 2026-II
# ---------------------------------------------------------------------
#  Qué hace:
#   1. Lee los 768 archivos de la SBS descargados por 02_descarga_sbs.R
#      (no los modifica; solo los lee).
#   2. De los archivos de indicadores toma: morosidad, ROE, gastos de
#      administración y ratio de capital global de cada entidad.
#   3. De los estados financieros toma: gastos financieros, pasivo total,
#      activo total y patrimonio, y calcula el costo de fondeo.
#   4. Une todo con las series del BCRP (01_extraccion_api.R).
#   5. Revisa datos faltantes y valores atípicos, y guarda el panel final.
# =====================================================================

library(readxl)
library(writexl)
library(digest)

CODIGO_ALUMNA <- "2024200520M"
dir.create("datos_procesados", showWarnings = FALSE)
dir.create("logs", showWarnings = FALSE)

# ---------------------- FUNCIONES DE APOYO ----------------------------

# Quita tildes para que las búsquedas de texto no fallen
sin_tildes <- function(x) chartr("\u00e1\u00e9\u00ed\u00f3\u00fa\u00c1\u00c9\u00cd\u00d3\u00da\u00f1\u00d1",
                                  "aeiouAEIOUnN", x)

# Convierte texto a número ("n.d.", "-" o vacío pasan a NA)
a_numero <- function(x) suppressWarnings(as.numeric(gsub(",", "", x)))

# La SBS publica algunos archivos en formato .xls antiguo y otros en .xlsx,
# aunque todos terminan en .XLS. Si el archivo es realmente .xlsx (empieza
# con las letras "PK"), se hace una copia temporal con la extensión correcta
# para que R lo pueda abrir. El archivo original no se modifica.
ruta_lectura <- function(ruta) {
  inicio <- readBin(ruta, what = "raw", n = 2)
  if (identical(inicio, charToRaw("PK"))) {
    copia <- tempfile(fileext = ".xlsx")
    file.copy(ruta, copia)
    return(copia)
  }
  ruta
}

# Lee una hoja de Excel como una matriz de texto
leer_hoja <- function(ruta, hoja = 1) {
  tabla <- suppressMessages(read_excel(ruta, sheet = hoja, col_names = FALSE,
                                       col_types = "text", .name_repair = "minimal"))
  m <- as.matrix(tabla)
  m <- trimws(gsub("\\s+", " ", sin_tildes(m)))
  m[m == ""] <- NA
  m
}

# Busca en qué celdas aparece un texto (devuelve filas y columnas)
buscar <- function(m, patron) {
  which(matrix(grepl(patron, m), nrow = nrow(m)), arr.ind = TRUE)
}

# Crea una "clave" para que el mismo nombre de entidad coincida entre archivos
clave_entidad <- function(x) {
  x <- gsub("\\(\\*+\\)|\\*", "", x)
  x <- tolower(sin_tildes(x))
  x <- gsub("[^a-z ]", " ", x)            # quita números de notas al pie
  x <- trimws(gsub("\\s+", " ", x))
  equivalencias <- c(
    "caja municipal de credito popular lima"    = "cmcp lima",
    "caja municipal de credito popular de lima" = "cmcp lima",
    "crac censosud scotia"                      = "crac cencosud scotia",
    "santander"                                 = "santander consumo"
  )
  ifelse(x %in% names(equivalencias), equivalencias[x], x)
}

# ---------------------- LECTURA DE INDICADORES ------------------------
PATRONES_IND <- c(
  ratio_capital = "^Ratio de Capital Global",
  morosidad     = "^Creditos Atrasados \\(criterio SBS\\)\\** ?/ ?Creditos Directos",
  gastos_adm    = "^Gastos de Administracion Anualizad",
  roe           = "^Utilidad (Neta )?Anualizada (sobre|/) Patrimonio"
)

leer_indicadores <- function(ruta) {
  m <- leer_hoja(ruta_lectura(ruta), 1)
  pos <- buscar(m, PATRONES_IND["ratio_capital"])
  if (nrow(pos) == 0) return(NULL)
  col_etiquetas <- sort(unique(pos[, "col"]))
  fila_inicio   <- min(pos[, "row"])
  c0 <- min(col_etiquetas)

  # Fila de cada indicador (las filas son iguales en todos los bloques)
  filas <- sapply(PATRONES_IND, function(p) {
    f <- which(grepl(p, m[, c0])); if (length(f) > 0) f[1] else NA
  })

  # Fila con los nombres de las entidades: la última fila con 2 o más textos
  # antes del primer indicador
  fila_nombres <- NA
  for (i in (fila_inicio - 1):1) {
    celdas <- m[i, ]
    es_nombre <- !is.na(celdas) & !(seq_along(celdas) %in% col_etiquetas) &
      is.na(a_numero(celdas)) &
      !grepl("^(Actualiz|Indicadores|\\(|SOLVENCIA)", celdas)
    if (sum(es_nombre) >= 2) { fila_nombres <- i; break }
  }
  if (is.na(fila_nombres)) return(NULL)
  cols <- which(es_nombre)

  res <- data.frame(entidad = trimws(gsub("\\(\\*+\\)|\\*", "", m[fila_nombres, cols])),
                    stringsAsFactors = FALSE)
  for (v in names(filas)) {
    res[[v]] <- if (is.na(filas[v])) NA else a_numero(m[filas[v], cols])
  }
  res
}

# ---------------------- LECTURA DE ESTADOS FINANCIEROS ----------------
PATRONES_BG  <- c(pasivo = "^TOTAL PASIVO$", activo = "^TOTAL ACTIVO$",
                  patrimonio = "^PATRIMONIO$")
PATRONES_GYP <- c(gastos_fin = "^GASTOS FINANCIEROS")

leer_hoja_ef <- function(m, patrones) {
  marcas <- do.call(rbind, lapply(patrones, function(p) buscar(m, p)))
  if (is.null(marcas) || nrow(marcas) == 0) return(NULL)
  col_etiquetas <- sort(unique(marcas[, "col"]))
  c0 <- min(col_etiquetas)
  filas <- sapply(patrones, function(p) {
    f <- which(grepl(p, m[, c0])); if (length(f) > 0) f[1] else NA
  })

  fila_mn <- which(apply(m[1:min(15, nrow(m)), , drop = FALSE], 1,
                         function(r) any(r == "MN", na.rm = TRUE)))[1]
  if (is.na(fila_mn)) return(NULL)
  fila_nombres <- fila_mn - 1

  celdas <- m[fila_nombres, ]
  cols <- which(!is.na(celdas) & !(seq_along(celdas) %in% col_etiquetas) &
                  is.na(a_numero(celdas)) &
                  !grepl("^(Activo|Pasivo)$", celdas))
  res <- list()
  for (j in cols) {
    rango <- j:min(j + 3, ncol(m))
    col_total <- rango[which(toupper(m[fila_mn, rango]) == "TOTAL")[1]]
    if (is.na(col_total)) next
    fila <- data.frame(entidad = trimws(gsub("\\(\\*+\\)|\\*", "", celdas[j])),
                       stringsAsFactors = FALSE)
    for (v in names(filas)) {
      fila[[v]] <- if (is.na(filas[v])) NA else a_numero(m[filas[v], col_total])
    }
    res[[length(res) + 1]] <- fila
  }
  if (length(res) == 0) return(NULL)
  do.call(rbind, res)
}

leer_estados_financieros <- function(ruta) {
  bg <- NULL; gyp <- NULL
  ruta <- ruta_lectura(ruta)
  for (h in seq_along(excel_sheets(ruta))) {
    m <- leer_hoja(ruta, h)
    titulo <- paste(na.omit(as.vector(m[1:min(4, nrow(m)), ])), collapse = " ")
    if (grepl("Balance", titulo))  bg  <- leer_hoja_ef(m, PATRONES_BG)
    if (grepl("Ganancia", titulo)) gyp <- leer_hoja_ef(m, PATRONES_GYP)
  }
  if (is.null(bg) || is.null(gyp)) return(NULL)
  bg$clave  <- clave_entidad(bg$entidad)
  gyp$clave <- clave_entidad(gyp$entidad)
  merge(bg, gyp[, c("clave", "gastos_fin")], by = "clave")
}

# ---------------------- RECORRER TODOS LOS ARCHIVOS -------------------
log_sbs <- read.csv(file.path("logs", "log_descarga_sbs.csv"), stringsAsFactors = FALSE)
log_sbs <- log_sbs[log_sbs$estado != "no disponible", ]

lista_ind <- list(); lista_ef <- list(); problemas <- c()
for (k in seq_len(nrow(log_sbs))) {
  a <- log_sbs[k, ]
  ruta <- file.path("datos_crudos", "sbs", a$archivo)
  d <- tryCatch(
    if (a$contenido == "indicadores") leer_indicadores(ruta) else leer_estados_financieros(ruta),
    error = function(e) NULL)
  if (is.null(d) || nrow(d) == 0) { problemas <- c(problemas, a$archivo); next }
  d$tipo <- a$tipo; d$anio <- a$anio; d$mes <- a$mes
  if (a$contenido == "indicadores") {
    lista_ind[[length(lista_ind) + 1]] <- d
  } else {
    lista_ef[[length(lista_ef) + 1]] <- d
  }
  if (k %% 50 == 0) cat("Archivos leídos:", k, "de", nrow(log_sbs), "\n")
}
ind <- do.call(rbind, lista_ind)
ef  <- do.call(rbind, lista_ef)
cat("Archivos que no se pudieron leer:", length(problemas), "\n")

# ---------------------- UNIR INDICADORES Y ESTADOS FINANCIEROS --------
ind$clave <- clave_entidad(ind$entidad)
ind <- ind[!grepl("total|servicios financieros", ind$clave), ]
ef  <- ef[!grepl("total|servicios financieros", ef$clave), ]
ind <- ind[!duplicated(ind[, c("tipo", "clave", "anio", "mes")]), ]
ef  <- ef[!duplicated(ef[, c("tipo", "clave", "anio", "mes")]), ]

panel <- merge(ind, ef[, c("tipo", "clave", "anio", "mes",
                           "gastos_fin", "pasivo", "activo", "patrimonio")],
               by = c("tipo", "clave", "anio", "mes"))

# Nombre "bonito" de cada entidad: el más reciente que publicó la SBS
panel <- panel[order(panel$clave, panel$anio, panel$mes), ]
ultimo_nombre <- tapply(panel$entidad, panel$clave, function(x) tail(x, 1))
panel$entidad <- gsub("\\s+", " ", ultimo_nombre[panel$clave])

# ---------------------- VARIABLES DEL ESTUDIO -------------------------
# Costo de fondeo: gastos financieros del año (acumulados a la fecha,
# llevados a 12 meses) entre el pasivo total, en %.
panel$costo_fondeo <- panel$gastos_fin * 12 / panel$mes / panel$pasivo * 100
# Tamaño: logaritmo del activo total (miles de soles)
panel$tamano <- log(panel$activo)

# ---------------------- CONTROL DE CALIDAD ----------------------------
n_inicial <- nrow(panel)
# 1) Entidades sin operaciones ese mes (reportan todo en cero)
inactivas <- (panel$ratio_capital %in% 0 & panel$morosidad %in% 0) |
  is.na(panel$pasivo) | panel$pasivo <= 0 | is.na(panel$activo) | panel$activo <= 0
panel <- panel[!inactivas, ]
# 2) Valores imposibles
imposibles <- panel$costo_fondeo < 0 | panel$costo_fondeo > 50 |
  panel$morosidad < 0 | panel$morosidad > 100
imposibles[is.na(imposibles)] <- FALSE
panel <- panel[!imposibles, ]
# 3) Marca de atípicos (fuera del percentil 1-99); no se borran, se marcan
marcar <- function(x) {
  q <- quantile(x, c(0.01, 0.99), na.rm = TRUE)
  !is.na(x) & (x < q[1] | x > q[2])
}
panel$atipico <- marcar(panel$costo_fondeo) | marcar(panel$morosidad) | marcar(panel$roe)

# ---------------------- UNIR CON BCRP ---------------------------------
bcrp <- read.csv(file.path("datos_crudos", "bcrp",
                           paste0("datos_crudos_bcrp_", CODIGO_ALUMNA, ".csv")))
panel <- merge(panel, bcrp[, c("anio", "mes", "tasa_referencia", "inflacion_12m")],
               by = c("anio", "mes"), all.x = TRUE)

panel$fecha <- as.Date(sprintf("%d-%02d-01", panel$anio, panel$mes))
panel <- panel[order(panel$tipo, panel$entidad, panel$fecha), ]
panel <- panel[, c("tipo", "entidad", "fecha", "anio", "mes",
                   "costo_fondeo", "morosidad", "roe", "gastos_adm",
                   "ratio_capital", "tamano", "activo", "pasivo", "patrimonio",
                   "gastos_fin", "tasa_referencia", "inflacion_12m", "atipico")]
rownames(panel) <- NULL

# ---------------------- GUARDAR ---------------------------------------
ruta_csv <- file.path("datos_procesados", paste0("panel_microfinancieras_", CODIGO_ALUMNA, ".csv"))
write.csv(panel, ruta_csv, row.names = FALSE)
write_xlsx(panel, file.path("datos_procesados",
                            paste0("panel_microfinancieras_", CODIGO_ALUMNA, ".xlsx")))

hash <- digest(ruta_csv, algo = "sha256", file = TRUE)
faltantes <- sapply(panel[, c("costo_fondeo", "morosidad", "roe", "gastos_adm",
                              "ratio_capital", "tamano")], function(x) sum(is.na(x)))

resumen <- c(
  paste("Fecha de ejecucion:", Sys.time()),
  paste("Archivos SBS leidos:", nrow(log_sbs) - length(problemas), "de", nrow(log_sbs)),
  paste("Archivos con problemas:", paste(problemas, collapse = ", ")),
  paste("Observaciones al unir:", n_inicial),
  paste("Eliminadas por inactividad:", sum(inactivas)),
  paste("Eliminadas por valores imposibles:", sum(imposibles)),
  paste("Observaciones finales:", nrow(panel)),
  paste("Entidades:", length(unique(panel$entidad))),
  paste("Meses:", length(unique(panel$fecha))),
  paste("Marcadas como atipicas (no eliminadas):", sum(panel$atipico)),
  paste("Faltantes por variable:", paste(names(faltantes), faltantes, sep = "=", collapse = "; ")),
  paste("SHA-256 del panel:", hash)
)
writeLines(resumen, file.path("logs", "log_limpieza.txt"))
writeLines(capture.output(sessionInfo()), "sessionInfo.txt")

cat("\n================ RESUMEN ================\n")
cat(resumen, sep = "\n")
cat("\nEntidades por tipo:\n")
print(tapply(panel$entidad, panel$tipo, function(x) length(unique(x))))
