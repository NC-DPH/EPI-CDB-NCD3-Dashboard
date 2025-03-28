### This code selects a date based on availability and preference. 

* If MMWR_DATE_BASIS is filled in (not missing), use that.

* Otherwise, if SYMPTOM_ONSET_DATE is filled in, use that instead.

* If SYMPTOM_ONSET_DATE is missing but RPTI_SOURCE_DT_SUBMITTED is filled in, use RPTI_SOURCE_DT_SUBMITTED.

* If none of the above are available, use the date part of CREATE_DT as the fallback.