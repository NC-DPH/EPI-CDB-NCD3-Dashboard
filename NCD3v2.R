# install package loader
if (!require("pacman")) install.packages("pacman")

# load necessary packages
pacman::p_load(
  dplyr, rio, lubridate, haven #to read SAS database
)

# import datasets, and only selected columns so loads faster. may take up to 1 min for main case file. 
case_phi <- read_sas('Z:/20241101/case_phi.sas7bdat', col_select = c(1,16))
case <- read_sas('Z:/20241101/case.sas7bdat', col_select = c(1,3:6, 8:10, 12, 14, 20:33, 35))
Admin_question_package_addl <- read_sas('Z:/20241101/Admin_question_package_addl.sas7bdat', col_select = c(2,6))

# functions
create_case_combo <- function(classification_user, type_user, report_to_cdc_user = NULL) {
  df <- case %>% 
    filter(if (is.null(classification_user)) TRUE else CLASSIFICATION_CLASSIFICATION %in% classification_user,
           TYPE %in% type_user,
           if (is.null(report_to_cdc_user)) TRUE else REPORT_TO_CDC %in% report_to_cdc_user) %>% 
    left_join(case_phi, by = "CASE_ID") %>% 
    left_join(Admin_question_package_addl, by = "CASE_ID")
  return(df)
}

create_final_df <- function(dataset, end_date=today(), user_disease_name, status_user="Closed") {
  df <- dataset %>% 
    select(OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID, MMWR_YEAR, MMWR_DATE_BASIS, AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6, SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, CURRENT_STATE) %>% 
    mutate(MMWR_YEAR = as.numeric(MMWR_YEAR),
           EVENT_DATE = case_when(
             !is.na(MMWR_DATE_BASIS) ~ MMWR_DATE_BASIS,
             !is.na(SYMPTOM_ONSET_DATE) ~ SYMPTOM_ONSET_DATE,
             is.na(SYMPTOM_ONSET_DATE) & !is.na(RPTI_SOURCE_DT_SUBMITTED) ~ RPTI_SOURCE_DT_SUBMITTED,
             TRUE ~ date(CREATE_DT)),
           Year = year(EVENT_DATE),
           Month = month(EVENT_DATE),
           Quarter = quarter(EVENT_DATE),
           Disease_Group = user_disease_name
    ) %>% 
    filter(EVENT_DATE >= as.Date("2015-01-01") & EVENT_DATE <= as.Date(end_date),
           STATUS %in% status_user,
           CURRENT_STATE %in% c("NC", "")) %>% 
    mutate(Counts = n()) %>% 
    arrange(TYPE_DESC, OWNING_JD)
  
  return(df)
}


# analysis
class(enteric)
colnames(enteric)
str(enteric)
unique(enteric$STATE)
class(case$REPORT_TO_CDC)

# cleanup
rm(enteric, enteric2, enterics, case_combo, case_combo_final, case_combo_sub)

# enteric
case_combo <- create_case_combo(classification_user=c("Confirmed", "Probable"), c("BOT", "BOTI", "CAMP", "CRYPT", "CYCLO", "ECOLI", "FBOTHER", "CPERF", "FBPOIS", "STAPH", "HUS", "LIST", "SAL", "SHIG", "TRICH", "TYPHOID", "TYPHCAR", "VIBOTHER", "VIBVUL"), c("Yes", "No"))
case_combo_sub <- create_case_combo(c("Suspect"), c("ECOLI"), c("Yes", "No"))
case_combo_final <- rbind(dataset=case_combo, case_combo_sub)
enteric <- create_final_df(dataset=case_combo_final, user_disease_name="Enteric")


# HAI
case_combo <- create_case_combo(c("Confirmed", "Probable"), c("CAURIS", "STRA", "SAUR", "TSS", "TSSS"), c("Yes"))
case_combo_sub <- create_case_combo(c("Confirmed", "Probable"), c("CRE"))
case_combo_final <- rbind(case_combo, case_combo_sub)
HAI <- create_final_df(dataset=case_combo_final, user_disease_name="Healthcare Acquired Infection")

# Hep
case_combo <- create_case_combo(c("Confirmed", "Probable"), c("HEPB_C", "HEPB_P", "HEPA", "HEPB_A", "HEPC", "HEPB_U", "HEPCC"), c("Yes"))
hep <- create_final_df(dataset=case_combo, user_disease_name="Hepatitis")

# Respiratory
case_combo <- create_case_combo(c("Confirmed", "Probable"), c("FLU", "FLUD", "LEG"), c("Yes"))
case_combo_sub <- create_case_combo(c("Confirmed", "Probable"), c("FLUDA"))
case_combo_final <- rbind(case_combo, case_combo_sub)
Resp <- create_final_df(dataset=case_combo_final, user_disease_name="Respiratory")


# VPD
case_combo <- create_case_combo(c("Confirmed", "Probable"), c("DIP", "HFLU", "MEAS", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "RUB", "RUBCONG", "TET", "VARICELLA"), c("Yes"))
case_combo_sub <- create_case_combo(c("Confirmed", "Probable"), c("AFM", "MENP", "VAC"))
case_combo_final <- rbind(case_combo, case_combo_sub)
vpd <- create_final_df(dataset=case_combo_final, user_disease_name="Vaccine Preventable")

# zoonotic 
case_combo <- create_case_combo(c("Confirmed", "Probable"), c("ANTH", "ARB", "BRU", "CHIKV", "DENGUE", "EHR", "HGE", "EEE", "HME", 
                                                              "LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", 
                                                              "YF", "ZIKA", "VHF"), c("Yes"))
case_combo_sub <- create_case_combo(c("Confirmed", "Probable"), c("CJD"))
case_combo_final <- rbind(case_combo, case_combo_sub)
zoo <- create_final_df(dataset=case_combo_final, user_disease_name="Vector-Borne/Zoonotic")

# std additional packages required.
# must already load previous packages at top of this file.
pacman::p_load(
  rlang,  stringr
)

# function
create_std_df <- function(include_column, date_basis, date_label, user_type, report_to_cdc_user = NULL) {
  
  # remove quotes from date_label
  date_label_noquotes <- as.character(noquote(date_label))
    # allow this to be evaluated later
  user_type <- enquo(user_type)

  df <- case %>% 
  filter({{date_basis}} >= as.Date("2015-01-01") & {{date_basis}} <= as.Date("2025-02-01"),
         CLASSIFICATION_CLASSIFICATION %in% c("Confirmed", "Probable"),
         !!user_type,
         if (!is.null(report_to_cdc_user)) REPORT_TO_CDC %in% report_to_cdc_user else TRUE) %>% 
  mutate(MMWR_YEAR = as.numeric(MMWR_YEAR),
         Counts = n(),
         !!quo_name(date_label_noquotes) := year({{date_basis}}),
         Year = year({{date_basis}}),
         Quarter = quarter({{date_basis}})
  ) %>% 
  select(OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID, MMWR_YEAR, MMWR_DATE_BASIS, AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6, SYMPTOM_ONSET_DATE, {{include_column}}, Counts, Year, Quarter, {{date_label_noquotes}}) %>% 
  arrange(TYPE_DESC, OWNING_JD, {{date_label_noquotes}})
  
  return(df)
}

# chlamydia and gonorrhea
cg <- create_std_df(DEDUPLICATION_DATE, DEDUPLICATION_DATE, "DEDUP_YEAR", TYPE %in% c("CHLAMYDIA", "GONOR"), "Yes")

# low incidence STD
std <- create_std_df(DEDUPLICATION_DATE, SYMPTOM_ONSET_DATE, "SYMPTOM_YEAR", (TYPE %in% c("GRANUL", "LGRANUL", "NGURETH", "PID")) | (TYPE == "CHANCROID" & REPORT_TO_CDC == "Yes"))

# syphilis
syph1 <- create_std_df(LHD_DIAGNOSIS_DATE, LHD_DIAGNOSIS_DATE, "LHD_DX_YR", (str_detect(TYPE, "SYPH") & !str_detect(TYPE, "CONGSYPH") & REPORT_TO_CDC == "Yes"))
syph2 <- create_std_df(LHD_DIAGNOSIS_DATE, BIRTH_DATE, "DOB", TYPE == "CONGSYPH", "Yes")



# put all databases together
final <- bind_rows(enteric, HAI, hep, Resp, vpd, zoo, cg, std, syph1, syph2)
final_nostd <- bind_rows(enteric, HAI, hep, Resp, vpd, zoo)

# save final databases
saveRDS(final, "final.rds")
saveRDS(final_nostd, "final_nostd.rds")


# remove intermediate databases if above works
rm(enteric, HAI, hep, Resp, vpd, zoo, cg, std, syph1, syph2, case_combo, case_combo_final, case_combo_sub)

# cleaning disease names
final_nostd <- final_nostd %>% 
  mutate(County_substr = substr(OWNING_JD, 1, nchar(OWNING_JD) - 7),
         Disease = recode(TYPE_DESC, 
                          'Syphilis - 01. Primary Syphilis' = 'Syphilis - Primary Syphilis',
                          'Syphilis - 02. Secondary Syphilis' = 'Syphilis - Secondary Syphilis',
                          'Syphilis - 03. Early, Non-Primary, Non-Secondary Syphilis' = 'Syphilis - Early, Non-Primary, Non-Secondary Syphilis',
                          'Syphilis - 05. Late Latent Syphilis' = 'Syphilis - Late Latent Syphilis',
                          'Syphilis - 05. Syphilis Late w/ clinical manifestations' = 'Syphilis - Late Latent Syphilis',
                          'Syphilis - 05. Unknown Duration or Late Syphilis' = 'Syphilis - Late Latent Syphilis',
                          'Syphilis - 08. Congenital Syphilis' = 'Syphilis - Congenital Syphilis',
                          'Carbapenem-resistant Enterobacteriaceae' = 'Carbapenem-resistant Enterobacterales',
                          'Campylobacter infection' = 'Campylobacteriosis',
                          'Monkeypox' = 'Mpox',
                          'ZIKA' = 'Zika',
                          'Foodborne poisoning' = 'Foodborne poisoning (fish/mushroom/ciguatera)',
                          'Vibrio infection' = 'Vibrio infection (other than cholera and vulnificus)')
         ) %>% 
  filter(County_substr != "",
         TYPE_DESC != "",
         Disease != 'Syphilis - Unknown Syphilis (700)')


# aggregate date packages
pacman::p_load(lubridate)

# aggregate by week
agg_weekly <- final_nostd %>% 
  mutate(Week = week(EVENT_DATE)) %>% 
  group_by(Year, Disease, Week) %>% 
  summarise(Cases = n())


# aggregate for aberration dashboard
pacman::p_load(epikit)
selected_diseases <- c("Campylobacter infection (50)", "Cryptosporidiosis (56)", "Cyclosporiasis (63)", "E. coli - shiga toxin producing (53)", "Salmonellosis (38)", "Shigellosis (39)", "Vibrio infection (other than cholera and vulnificus) (55)", "Carbapenem-resistant Enterobacteriaceae (CRE)", "Pertussis (47)", "Streptococcal invasive infection, Group A (61)", "Dengue (7)", "Varicella")

aberration_weekly <- final_nostd %>%
  filter(Disease %in% selected_diseases) %>% 
  mutate(Week = week(EVENT_DATE),
         age_cat = age_categories(AGE, breakers = c(0, 5, 10, 15, 20, 30, 40, 50))) %>% 
  group_by(Year, Disease, Week, age_cat, GENDER, HISPANIC, RACE1, County_substr) %>% 
  summarise(Cases = n())

# export
export(aberration_weekly, "aberration_weekly.xlsx")

# aggregate by week and join with data scaffolding table
expanded_scaffold <- expand.grid(Disease = selected_diseases, Year = 2015:2024, Hispanic = Hispanic, age_cat = age_cat, Week = 1:53, Gender = c("Male", "Female", ""), Cases = 0)
age_cat = unique(aberration_weekly$age_cat)
Hispanic = unique(aberration_weekly$HISPANIC)
Race1 = unique(aberration_weekly$RACE1)
County = unique(aberration_weekly$County_substr)

# aggregate by week and join with data scaffolding table
all_diseases <- unique(agg_weekly$Disease)
expanded_scaffold <- expand.grid(Disease = all_diseases, Year = 2015:2024, Week = 1:53)

agg_weekly_full <- agg_weekly %>% 
  # join with data scaffolding table
  full_join(expanded_scaffold, by = c("Year" = "Year", "Week" = "Week", "Disease" = "Disease"), keep=FALSE) %>% 
  arrange(Disease, Year, Week) %>% 
  # final mutation, add 0 for week with no cases, and add epiweek
  mutate(Cases = coalesce(Cases, 0),
         epiweek = make_yearweek(year=Year, week=Week),
         epiweek2 = as.Date(epiweek)
         ) #for Excel

# other aggregations
agg_monthly <- final_nostd %>% 
  select(Year, Disease, Disease_Group, Month) %>% 
  group_by(Year, Disease, Month) %>% 
  summarise(Cases = n())

agg_quarterly <- final_nostd %>% 
  mutate(Week = epiweek(EVENT_DATE)) %>% 
  select(Year, Disease, Disease_Group, Quarter) %>% 
  group_by(Year, Disease, Quarter) %>% 
  summarise(Cases = n())

# aggregate weekly by region
# get region information from county
pacman::p_load(rio, here)
county_region <- import(here("County_Regions.xlsx"))
final_nostd <- left_join(final_nostd, county_region, by = c("OWNING_JD" = "County_new")) 

region_weekly <- final_nostd %>% 
  mutate(Week = epiweek(EVENT_DATE)) %>% 
  select(Year, Region, Disease, Disease_Group, Week) %>% 
  group_by(Year, Region, Disease, Week) %>% 
  summarise(Cases = n(), .groups = "keep") %>% 
  arrange(Disease, Year, Region, Week)

# export
export(agg_weekly, "agg_weekly.xlsx")

# saving and clean up
# save
saveRDS(agg_weekly, "agg_weekly.rds")
saveRDS(region_weekly, "region_weekly.rds")

rm(Admin_question_package_addl, case, case_phi, county_region)
rm(final, final2, final3, county_region)
