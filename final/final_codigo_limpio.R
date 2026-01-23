library(nnet)
library(dplyr)
library(pdftools)
library(stm)
library(LDAvis)
library(quanteda)
library(purrr)
library(ggplot2)
library(ggeffects)

#### ------------------------------------------------------ ####
#### -----------  LIMPIAR PROGRAMAS ELECTORALES ----------- ####
#### ------------------------------------------------------ ####

### ---- VOX ----
programa_vox <- data.frame(texto = pdftools::pdf_text("./programa_vox.pdf"))

programa_vox_clean <- programa_vox %>%
  slice(7:nrow(programa_vox)) %>%
  mutate(
    texto = texto %>%
      str_replace_all("-\\s*\n?\\s*", "") %>%
      str_replace_all("www\\.votaabascal\\.es", "") %>%
      str_replace_all("\\b[[:upper:]]{2,}\\b", "") %>%
      str_replace_all("\\d+", "") %>%
      str_squish()
  ) %>%
  summarise(
    texto = paste(texto, collapse = " ")
  )
programa_vox_clean <- data.frame(texto = programa_vox_clean$texto, partido = "VOX")

### ---- SUMAR ----
programa_sumar <- data.frame(texto = pdftools::pdf_text("./programa_sumar.pdf"))

programa_sumar_clean <- programa_sumar %>%
  slice(7:nrow(programa_sumar)) %>%
  mutate(
    texto = texto %>%
      str_replace_all("-\\s*\n?\\s*", "") %>%
      str_replace_all("Una democracia económica y ecosocial al servicio de las personas Economía", "") %>%
      str_replace_all("Una democracia económica y ecosocial al servicio de las personas Trabajo decente. Mejorar la vida de las personas trabajadoras", "") %>%
      str_replace_all("Una democracia económica y ecosocial al servicio de las personas La transición ecológica justa, el desafío de nuestro tiempo", "") %>%
      str_replace_all("Una democracia económica y ecosocial al servicio de las personas Por un mundo rural vivo y activo", "") %>%
      str_replace_all("Una democracia económica y ecosocial al servicio de las personasHábitat para la vida", "") %>%
      str_replace_all("\\b[[:upper:]]{2,}\\b", "") %>%
      str_replace_all("\\d+", "") %>%
      str_squish()
  ) %>%
  summarise(
    texto = paste(texto, collapse = " ")
  )
programa_sumar_clean <- data.frame(texto = programa_sumar_clean$texto, partido = "SUMAR")

### ---- PP ----
programa_pp <- data.frame(texto = pdftools::pdf_text("./programa_pp_25.pdf"))

programa_pp_clean <- programa_pp %>%
  slice(4:nrow(programa_pp)) %>%
  mutate(
    texto = texto %>%
      str_replace_all("\\b[[:upper:]]{2,}\\b", "") %>%
      str_replace_all("\\d+", "") %>%
      str_squish()
  ) %>%
  summarise(
    texto = paste(texto, collapse = " ")
  )
programa_pp_clean <- data.frame(texto = programa_pp_clean$texto, partido = "PP")

### ---- PSOE ----
programa_psoe <- data.frame(texto = pdftools::pdf_text("./programa_psoe.pdf"))

programa_psoe_clean <- programa_psoe %>%
  slice(17:nrow(programa_psoe)) %>%
  mutate(
    texto = texto %>%
      str_replace_all("\\b[[:upper:]]{2,}\\b", "") %>%
      str_replace_all("\\d+", "") %>%
      str_squish()
  ) %>%
  summarise(
    texto = paste(texto, collapse = " ")
  )
programa_psoe_clean <- data.frame(texto = programa_psoe_clean$texto, partido = "PSOE")

programas <- rbind(programa_psoe_clean, programa_sumar_clean, programa_vox_clean, programa_pp_clean)

### ---- DIVIDIR EN FRAGMENTOS ----
chunk_text_balanced <- function(text, target = 200, min_last = 50) {

  sentences <- str_split(text, "(?<=[.!?])\\s+")[[1]]
  sent_lengths <- str_count(sentences, "\\S+")

  chunks <- character()
  current <- character()
  current_len <- 0

  for (i in seq_along(sentences)) {
    diff_now <- abs(current_len - target)
    diff_add <- abs(current_len + sent_lengths[i] - target)

    if (current_len > 0 && diff_now <= diff_add) {
      chunks <- c(chunks, paste(current, collapse = " "))
      current <- character()
      current_len <- 0
    }

    current <- c(current, sentences[i])
    current_len <- current_len + sent_lengths[i]
  }

  chunks <- c(chunks, paste(current, collapse = " "))

  if (length(chunks) > 1) {
    last_len <- str_count(chunks[length(chunks)], "\\S+")
    if (last_len < min_last) {
      chunks[length(chunks)-1] <- paste(chunks[length(chunks)-1], chunks[length(chunks)])
      chunks <- chunks[-length(chunks)]
    }
  }
  return(chunks)
}

df_chunks <- programas %>%
  mutate(texto_original = texto) %>%
  select(-texto) %>%
  mutate(chunks = map(texto_original, chunk_text_balanced)) %>%
  unnest_longer(chunks) %>%
  rename(texto = chunks) %>%
  select(-texto_original) %>%
  mutate(doc_id = row_number()) %>%
  mutate(texto = str_replace_all(texto, "[^[:alpha:]\\s]", " "),
         texto = str_squish(texto),
         partido = as.factor(partido))

### ---- TOKENIZAR ----
stopwords_custom <- c(
  "país", "personas", "españa", "sánchez", "españoles", "medio", "social"
)

corpus_chunks <- corpus(df_chunks, text_field = "texto")

toks_chunks <- tokens(
  corpus_chunks,
  remove_numbers = TRUE,
  remove_symbols = TRUE,
  remove_punct   = TRUE
) %>%
  tokens_remove(stopwords_custom, case_insensitive = TRUE) %>%
  tokens_tolower() %>%
  tokens_remove(stopwords("es"))

dfm_chunks <- dfm(toks_chunks) %>%
  dfm_trim(min_termfreq = 5, min_docfreq = 3)

dfm_chunks <- dfm_chunks[rowSums(dfm_chunks) > 0, ]
stm_input <- convert(dfm_chunks, to = "stm")
docs  <- stm_input$documents
vocab <- stm_input$vocab
meta  <- stm_input$meta

non_empty <- lengths(docs) > 0
docs <- docs[non_empty]
meta <- meta[non_empty, ]

meta <- data.frame(
  partido = factor(meta)
)

### ---- STM ----
set.seed(123)
stm_chunks <- stm(
  documents = docs,
  vocab = vocab,
  K = 5,
  prevalence = ~ partido,
  data = meta,
  max.em.its = 150,
  init.type = "Spectral"
)

labelTopics(stm_chunks)

meta$partido <- factor(
  meta$partido,
  levels = c("PSOE", "PP", "SUMAR", "VOX")
)

prep <- estimateEffect(
  1:5 ~ partido,
  stm_chunks,
  meta = meta,
  uncertainty = "Global"
)
summary(prep, topics = 1:5)


#### ------------------------------------------------------ ####
#### -----------  LIMPIAR LA ENCUESTA DEL CIS  ------------ ####
#### ------------------------------------------------------ ####

### ---- LIMPIAR LA ENCUESTA ----
preocupaciones <- read.csv("./MD3431/3431_num.csv", sep = ";")

preocupaciones_clean <- preocupaciones %>% select(INTENCIONGR, problema = PESPANNA1) %>%
  filter(
    problema %in% c(80, 22, 19, 8, 3),
    INTENCIONGR %in% c(1,2,3,21)
  )

preocupaciones_long <- preocupaciones_clean %>%
  mutate(
    problema_lab = case_when(
      problema == 80 ~ "Cambio climático",
      problema == 22 ~ "Educación",
      problema == 19 ~ "Violencia de género",
      problema == 8  ~ "Economía",
      problema == 3  ~ "Inseguridad ciudadana"
    ),
    partido = case_when(
      INTENCIONGR == 1 ~ "PSOE",
      INTENCIONGR == 2 ~ "PP",
      INTENCIONGR == 3 ~ "VOX",
      INTENCIONGR == 21 ~ "SUMAR"
    )
  )

tabla_partido <- preocupaciones_long %>%
  count(partido, problema_lab) %>%
  group_by(partido) %>%
  mutate(porc = n / sum(n))

ggplot(tabla_partido,
       aes(x = problema_lab, y = porc, fill = partido)) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(
    y = "Proporción de menciones",
    x = "Problema considerado importante"
  )

### ---- MODELO MULTINOMIAL ----
modelo_multinom <- multinom(
  partido ~ problema_lab,
  data = preocupaciones_long
)

summary(modelo_multinom)
exp(coef(modelo_multinom))

preocupaciones_long %>%
  mutate(vox = ifelse(partido == "VOX", 1, 0)) %>%
  glm(vox ~ problema_lab, family = binomial, data = .)

### ---- PREDICCIONES DE PROBABILIDAD ----
pred <- ggpredict(modelo_multinom, terms = "problema_lab")
plot(pred)

pred_df <- as.data.frame(pred)

pred_df$partido <- rep(c("PP", "PSOE", "SUMAR", "VOX"), 5)
unique(pred_df$partido)

ggplot(pred_df, aes(x = x, y = predicted, color = partido)) +
  geom_point(size = 3) +
  scale_color_manual(
    values = c(
      PP    = "#1F77B4",
      PSOE  = "#D62728",
      VOX   = "#2CA02C",
      SUMAR = "#C2185B"
    )
  ) +
  labs(
    x = "Problema considerado más importante",
    y = "Probabilidad predicha de voto",
    color = "Partido",
    title = "Probabilidad de voto según la principal preocupación ciudadana"
  ) +
  theme_minimal(base_size = 13)

p_ciudadanos <- preocupaciones_long %>%
  group_by(problema_lab, partido) %>%
  count(problema_lab) %>%
  ungroup() %>%
  group_by(partido) %>%
  mutate(p_ciudadanos = n / sum(n)) %>%
  arrange(partido)
