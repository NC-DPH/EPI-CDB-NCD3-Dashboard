# All diseases in the North Carolina Disease Database Dashboard (NCD3) are imported from the denormalized EDSS tables using the following filters:

CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
and REPORT_TO_CDC = 'Yes'
and STATUS = 'Closed'
and EVENT_STATE in ('NC' ' ')

# These apply to the following diseases:
"BOT", "BOTI", "CAMP", "CRYPT", "CYCLO", "ECOLI", "FBOTHER", "CPERF", "FBPOIS", "STAPH", "HUS", "LIST", "SAL", "SHIG", "TRICH", "TYPHOID", "TYPHCAR", "VIBOTHER", "VIBVUL"
"CAURIS", "STRA", "SAUR", "TSS", "TSSS"
"HEPB_P", "HEPA", "HEPB_A", "HEPC", "HEPB_U", "HEPCC"
"FLU", "FLUD", "LEG"
"CHLAMYDIA", "GONOR"
"CHANCROID"
"%SYPH%", "CONGSYPH"
"DIP", "HFLU", "MEAS", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "RUB", "RUBCONG", "TET", "VARICELLA"
"ANTH", "ARB", "BRU", "CHIKV", "DENGUE", "EHR", "HGE", "EEE", "HME", "LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", "YF", "ZIKA", "VHF"


# Exceptions are listed below, and the filters used that differ from those stated above are highlighted:

ECOLI
CLASSIFICATION_CLASSIFICATION = "Suspect" (in addition to "Confirmed", "Probable")
	and REPORT_TO_CDC = 'Yes'

CRE
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
/*Removed the REPORT_TO_CDC=”Yes” filter for Carbapenem-resistant Enterobacteriaceae*/

HEPB_C
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and STATUS in ("Closed", "Open")

FLUDA
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
/*Removed the REPORT_TO_CDC=”Yes” filter for Influenza, adult death (18 years of age or more)*/

# TB – see TB file source

"GRANUL", "LGRANUL", "NGURETH", "PID"
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
/*Removed the REPORT_TO_CDC=”Yes” filter for Granuloma inguinale, Lymphogranuloma venereum, Nongonococcal urethritis, Pelvic inflammatory disease*/


# HIV – see HIV file source


"AFM", "MENP", "VAC"
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
/*Removed the REPORT_TO_CDC=”Yes” filter for Acute flaccid myelitis, Pneumococcal meningitis, Vaccinia*/


CJD
CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
/*Removed the REPORT_TO_CDC=”Yes” filter for Creutzfeldt-Jakob Disease*/


