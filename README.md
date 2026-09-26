Party Discourse and Citizens' Concerns in Spain

This repository contains the R code and data for an analysis of how well the discourse of Spain's four main national parties (PSOE, PP, VOX and SUMAR) matches the concerns of their voters.

What this project does

The project compares two sides of Spanish politics: what parties talk about in their programmes, and what their voters say are the country's main problems. It combines text analysis of party programmes with survey microdata from the Centro de Investigaciones Sociológicas (CIS). Specifically, the project:

- Extracts and cleans the text of each party's programme from PDF. It removes headers, running titles, URLs, numbers and all-caps words, then splits each programme into balanced fragments of about 200 words that respect sentence boundaries.
- Builds a document-feature matrix with quanteda. It removes Spanish stopwords plus a custom list of very frequent, uninformative terms ("país", "personas", "españa", …) and trims rare terms.
- Estimates a Structural Topic Model (STM) with 5 topics, using party as a prevalence covariate. It then uses estimateEffect to test how the presence of each topic differs across parties.
- Uses the CIS December 2023 Barometer (study no. 3431) to select respondents who intend to vote for PSOE, PP, VOX or SUMAR and whose main concern for Spain is one of five issues: climate change, education, gender-based violence, the economy or public safety.
- Compares how often each concern is mentioned by each party's voters. It estimates a multinomial logit model of vote intention on main concern and a binary logit model for VOX voters, and plots the predicted probability of voting for each party given each concern.

Repository contents

All files are in the final/ folder:

- final_codigo_limpio.R: full analysis pipeline. It reads and cleans the party programmes, splits them into fragments, tokenizes them, estimates the STM, cleans the CIS survey, and runs the descriptive analysis and the multinomial and logistic models.
- programa_psoe.pdf, programa_sumar.pdf, programa_vox.pdf: programmes for the 23 July 2023 general election.
- programa_pp_25.pdf: PP programme document dated July 2025.
- MD3431/: CIS Barometer of December 2023 (study no. 3431, fieldwork 1–7 December 2023, 4,613 interviews). Includes the microdata (3431.sav, 3431_num.csv, 3431_etiq.csv, DA3431, ES3431), the questionnaire (cues3431.pdf), the codebook (codigo3431.pdf) and the technical sheet (FT3431.pdf).

Data availability

All the data used in this project is included in the repository. The CIS microdata is publicly available from the CIS data catalogue, and the party programmes are published by each party.

How to run
1. Clone the repository and set the working directory to the final/ folder, because the script uses relative paths (./programa_vox.pdf, ./MD3431/3431_num.csv).
2. Install the required packages:
r
   install.packages(c("nnet", "dplyr", "pdftools", "stm", "LDAvis", "quanteda",
                      "purrr", "ggplot2", "ggeffects", "stringr", "tidyr"))
3. Load stringr and tidyr before running the script. The script uses str_replace_all(), str_split() and unnest_longer() but does not load these packages itself:
r
   library(stringr)
   library(tidyr)
   source("final_codigo_limpio.R")

Contact

If you have questions about the data or the analysis, please contact me at agathadelolmo@gmail.com.

Disclaimer

This code was developed as part of an academic project. It is shared for transparency and reproducibility; it has not been optimized or documented to production standards.
