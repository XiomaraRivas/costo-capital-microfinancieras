# =====================================================================
#  04_analisis.R
#  Análisis: tablas, figuras y regresiones de panel
#  Tema N.º 63: Costo de capital de las entidades microfinancieras
#               y su relación con la morosidad
#  Autora: Rivas Ames, Xiomara Heydi (2024200520M)
#  Finanzas I (055D) - Unidad II - 2026-II
# ---------------------------------------------------------------------
#  Pregunta: ¿las entidades con más morosidad tienen un mayor costo de
#  fondeo (costo de la deuda) y un mayor costo de patrimonio (ROE)?
#  Método: regresión de panel con efectos fijos por entidad y errores
#  estándar agrupados por entidad (cluster).
# =====================================================================

library(writexl)

CODIGO_ALUMNA <- "2024200520M"
dir.create(file.path("salidas", "tablas"),  recursive = TRUE, showWarnings = FALSE)
dir.create(file.path("salidas", "figuras"), recursive = TRUE, showWarnings = FALSE)

panel <- read.csv(file.path("datos_procesados",
                            paste0("panel_microfinancieras_", CODIGO_ALUMNA, ".csv")),
                  stringsAsFactors = FALSE)
panel$fecha <- as.Date(panel$fecha)

VARS <- c("costo_fondeo", "morosidad", "roe", "gastos_adm",
          "ratio_capital", "tamano", "tasa_referencia", "inflacion_12m")
CONTROLES <- c("morosidad", "gastos_adm", "ratio_capital", "tamano", "tasa_referencia")

guardar_tabla <- function(tabla, nombre) {
  write.csv(tabla, file.path("salidas", "tablas", paste0(nombre, ".csv")), row.names = FALSE)
  write_xlsx(tabla, file.path("salidas", "tablas", paste0(nombre, ".xlsx")))
  cat("\n=====", nombre, "=====\n"); print(tabla, row.names = FALSE)
}

# ---------------------- TABLA 1: ESTADÍSTICOS DESCRIPTIVOS ------------
desc <- data.frame(
  variable = VARS,
  n        = sapply(VARS, function(v) sum(!is.na(panel[[v]]))),
  media    = sapply(VARS, function(v) mean(panel[[v]], na.rm = TRUE)),
  desv_est = sapply(VARS, function(v) sd(panel[[v]], na.rm = TRUE)),
  minimo   = sapply(VARS, function(v) min(panel[[v]], na.rm = TRUE)),
  mediana  = sapply(VARS, function(v) median(panel[[v]], na.rm = TRUE)),
  maximo   = sapply(VARS, function(v) max(panel[[v]], na.rm = TRUE))
)
desc[, -1] <- round(desc[, -1], 2)
guardar_tabla(desc, "tabla1_descriptivos")

# ---------------------- TABLA 2: MEDIANAS POR TIPO DE ENTIDAD ---------
por_tipo <- aggregate(panel[, VARS[1:5]], by = list(tipo = panel$tipo),
                      FUN = median, na.rm = TRUE)
por_tipo$entidades     <- as.vector(tapply(panel$entidad, panel$tipo, function(x) length(unique(x)))[por_tipo$tipo])
por_tipo$observaciones <- as.vector(table(panel$tipo)[por_tipo$tipo])
por_tipo[, 2:6] <- round(por_tipo[, 2:6], 2)
guardar_tabla(por_tipo, "tabla2_medianas_por_tipo")

# ---------------------- TABLA 3: CORRELACIONES ------------------------
corr <- round(cor(panel[, VARS], use = "pairwise.complete.obs"), 2)
corr <- data.frame(variable = rownames(corr), corr, row.names = NULL)
guardar_tabla(corr, "tabla3_correlaciones")

# ---------------------- REGRESIÓN DE PANEL ----------------------------
# Efectos fijos por entidad: se compara a cada entidad consigo misma en el
# tiempo. Errores agrupados por entidad (cluster), calculados a mano para
# no depender de paquetes adicionales.
efectos_fijos <- function(datos, dependiente) {
  datos <- datos[complete.cases(datos[, c(dependiente, CONTROLES)]), ]
  formula <- as.formula(paste(dependiente, "~",
                              paste(CONTROLES, collapse = " + "), "+ factor(entidad)"))
  modelo <- lm(formula, data = datos)
  X <- model.matrix(modelo); e <- residuals(modelo)
  XtX_inv <- solve(crossprod(X))
  grupos <- datos$entidad
  carne <- matrix(0, ncol(X), ncol(X))
  for (g in unique(grupos)) {
    s <- crossprod(X[grupos == g, , drop = FALSE], e[grupos == g])
    carne <- carne + s %*% t(s)
  }
  G <- length(unique(grupos)); n <- nrow(X); k <- ncol(X)
  V <- (G / (G - 1)) * ((n - 1) / (n - k)) * XtX_inv %*% carne %*% XtX_inv
  b  <- coef(modelo)[CONTROLES]
  ee <- sqrt(diag(V))[CONTROLES]
  t  <- b / ee
  p  <- 2 * pt(abs(t), df = G - 1, lower.tail = FALSE)
  # R2 "within" (dentro de cada entidad)
  y_dm <- datos[[dependiente]] - ave(datos[[dependiente]], datos$entidad)
  r2_within <- 1 - sum(e^2) / sum(y_dm^2)
  list(tabla = data.frame(variable = CONTROLES, coeficiente = round(b, 4),
                          error_est = round(ee, 4), t = round(t, 2), p_valor = round(p, 4),
                          signif = ifelse(p < 0.01, "***", ifelse(p < 0.05, "**",
                                                                   ifelse(p < 0.10, "*", ""))),
                          row.names = NULL),
       n = n, entidades = G, r2_within = round(r2_within, 3))
}

mostrar_modelo <- function(res, nombre, titulo) {
  tabla <- res$tabla
  tabla <- rbind(tabla, data.frame(variable = c("Observaciones", "Entidades", "R2 within"),
                                   coeficiente = c(res$n, res$entidades, res$r2_within),
                                   error_est = NA, t = NA, p_valor = NA, signif = ""))
  cat("\n", titulo, "\n")
  guardar_tabla(tabla, nombre)
}

sin_atipicos <- panel[!panel$atipico, ]

# TABLA 4: costo de fondeo (costo de la deuda)
m_cf  <- efectos_fijos(panel, "costo_fondeo")
m_cf2 <- efectos_fijos(sin_atipicos, "costo_fondeo")
mostrar_modelo(m_cf,  "tabla4a_costo_fondeo",  "Costo de fondeo - todas las observaciones")
mostrar_modelo(m_cf2, "tabla4b_costo_fondeo_sin_atipicos", "Costo de fondeo - sin atípicos")

# TABLA 5: ROE (costo / rendimiento del patrimonio)
m_roe  <- efectos_fijos(panel, "roe")
m_roe2 <- efectos_fijos(sin_atipicos, "roe")
mostrar_modelo(m_roe,  "tabla5a_roe",  "ROE - todas las observaciones")
mostrar_modelo(m_roe2, "tabla5b_roe_sin_atipicos", "ROE - sin atípicos")

# TABLA 6: efecto de la morosidad sobre el costo de fondeo, por tipo de entidad
por_tipo_reg <- do.call(rbind, lapply(sort(unique(panel$tipo)), function(tp) {
  r <- efectos_fijos(panel[panel$tipo == tp, ], "costo_fondeo")
  fila <- r$tabla[r$tabla$variable == "morosidad", ]
  data.frame(tipo = tp, coef_morosidad = fila$coeficiente, error_est = fila$error_est,
             p_valor = fila$p_valor, signif = fila$signif,
             observaciones = r$n, entidades = r$entidades)
}))
guardar_tabla(por_tipo_reg, "tabla6_morosidad_por_tipo")

# ---------------------- FIGURAS ---------------------------------------
tipos   <- sort(unique(panel$tipo))
colores <- c("#1F4E79", "#C0504D", "#4F9A5A", "#B07D12")
mediana_mensual <- function(var) {
  a <- aggregate(panel[[var]], by = list(fecha = panel$fecha, tipo = panel$tipo),
                 FUN = median, na.rm = TRUE)
  names(a)[3] <- var; a
}

# Figura 1: costo de fondeo por tipo de entidad
f1 <- mediana_mensual("costo_fondeo")
png(file.path("salidas", "figuras", "figura1_costo_fondeo.png"), width = 1800, height = 1000, res = 200)
par(mar = c(4, 4.5, 2, 1))
plot(range(f1$fecha), range(f1$costo_fondeo), type = "n", xlab = "",
     ylab = "Costo de fondeo (%)", main = "Costo de fondeo mediano por tipo de entidad, 2018-2025")
for (i in seq_along(tipos)) {
  s <- f1[f1$tipo == tipos[i], ]
  lines(s$fecha, s$costo_fondeo, col = colores[i], lwd = 2)
}
legend("topleft", legend = tipos, col = colores, lwd = 2, bty = "n", cex = 0.85)
dev.off()

# Figura 2: morosidad por tipo de entidad
f2 <- mediana_mensual("morosidad")
png(file.path("salidas", "figuras", "figura2_morosidad.png"), width = 1800, height = 1000, res = 200)
par(mar = c(4, 4.5, 2, 1))
plot(range(f2$fecha), range(f2$morosidad), type = "n", xlab = "",
     ylab = "Morosidad (%)", main = "Morosidad mediana por tipo de entidad, 2018-2025")
for (i in seq_along(tipos)) {
  s <- f2[f2$tipo == tipos[i], ]
  lines(s$fecha, s$morosidad, col = colores[i], lwd = 2)
}
legend("topleft", legend = tipos, col = colores, lwd = 2, bty = "n", cex = 0.85)
dev.off()

# Figura 3: morosidad frente a costo de fondeo y frente a ROE (sin atípicos)
png(file.path("salidas", "figuras", "figura3_dispersion.png"), width = 2000, height = 900, res = 200)
par(mfrow = c(1, 2), mar = c(4.5, 4.5, 2.5, 1))
col_puntos <- colores[match(sin_atipicos$tipo, tipos)]
plot(sin_atipicos$morosidad, sin_atipicos$costo_fondeo, pch = 16, cex = 0.5,
     col = adjustcolor(col_puntos, 0.4), xlab = "Morosidad (%)",
     ylab = "Costo de fondeo (%)", main = "Morosidad y costo de fondeo")
abline(lm(costo_fondeo ~ morosidad, data = sin_atipicos), lwd = 2)
plot(sin_atipicos$morosidad, sin_atipicos$roe, pch = 16, cex = 0.5,
     col = adjustcolor(col_puntos, 0.4), xlab = "Morosidad (%)",
     ylab = "ROE (%)", main = "Morosidad y ROE")
abline(lm(roe ~ morosidad, data = sin_atipicos), lwd = 2)
legend("bottomleft", legend = tipos, col = colores, pch = 16, bty = "n", cex = 0.7)
dev.off()

writeLines(capture.output(sessionInfo()), "sessionInfo.txt")
cat("\nListo: tablas en salidas/tablas y figuras en salidas/figuras\n")
