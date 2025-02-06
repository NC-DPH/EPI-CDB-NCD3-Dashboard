																/*LAST MODIFIED DATE: 10-30-24*/
													/*LAST MODIFIED BY: LINDA YELTON (LWY) linda.yelton@dhhs.nc.gov*/
/*Purpose: Script in progres to create the Data Source for the North Carolina Disease Data Dashboard (NCD3) next update*/
/*	Internal server: https://internaldashboards.ncdhhs.gov/#/site/DPH/projects/400*/
/*	External server: https://dashboards.ncdhhs.gov/#/site/DPH/projects/158*/


/*Must have access to NCEDSS_SAS(Z:) - CBD denorm server to run this program*/
libname denorm 'Z:\20241101'; /*This can be updated as needed to produce most recent counts; M. Hilton provides a new extract monthly*/
options compress=yes;
options nofmterr;

/*%let EndDate = '31DEC2023'd;*/
%let EndDate = %sysfunc(today(),DATE9);

/* Must have access to CD Users Shared (T:) to access these */
/* files to be used later in program */

/* TB */
libname tb 'T:\Tableau\SAS folders\SAS datasets\TB Program Data 2015 - 2023'; /*this will need to be refreshed as newer years of counts are needed*/

/* HIV */
/*proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\HIV AIDS 2015-2023.xlsx' out=HIV_annual dbms=xlsx replace; run;*/
proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\HIV AIDS 2015-2024 by quarter_08222024_clean.xlsx' out=HIV_quarterly dbms=xlsx replace; run;


/* Annual and Quarterly County population */
/*proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\County Census Pop_10_22.xlsx'*/
/*out=county_pops dbms=xlsx replace; run;*/
/* Demographic County population */
/*proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\NCD3 Demo Dashboard\County Census Pop_10_22_LWY.xlsx'*/
/*out=demo_county_pops dbms=xlsx replace; run;*/

proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2023 Vintage Estimates\County Census Pop_15_23.xlsx'
out=county_pops dbms=xlsx replace; run;


/* Annual and Quarterly State population */
/*proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\State Census Pop_10_22.xlsx'*/
/*out=state_pops dbms=xlsx replace; run;*/
/* Demographic State population */
/*proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\NCD3 Demo Dashboard\State Census Pop_10_22_LWY.xlsx'*/
/*out=demo_state_pops dbms=xlsx replace; run;*/

proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2023 Vintage Estimates\State Census Pop_15_23.xlsx'
out=state_pops dbms=xlsx replace; run;


/*Regions file*/
proc import datafile='T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\County_Regions_NCALHD.xlsx' out=regions dbms=xlsx replace; run;


/*proc sql;*/
/*create table types as*/
/*select distinct TYPE, TYPE_DESC*/
/*from denorm.case;*/
/*quit;*/
/**/
/*proc freq data = types;*/
/*tables TYPE*TYPE_DESC/MISSING NOCOL NOCUM NOPERCENT NOROW; RUN;*/
/*run;*/
/*quit;*/


											/*BEGIN CREATING TABLES TO MERGE; DISEASE GROUPS ARE IN ALPHABETICAL ORDER*/



																			/*Enteric*/


/*The variable name for “Date of initial report to public health” in the DD tables is called “RPTI_SOURCE_DT_SUBMITTED”.*/
/*It is found in the “Admin_question_package_addl” table.*/

proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("BOT", "BOTI", "CAMP", "CRYPT", "CYCLO", "ECOLI", 
		"FBOTHER", "CPERF", "FBPOIS", "STAPH", "HUS", "LIST", "SAL",
		"SHIG", "TRICH", "TYPHOID", "TYPHCAR", "VIBOTHER", "VIBVUL")
	and s.REPORT_TO_CDC = 'Yes';
quit;

/*Join with State variable for subsetting use in a later step. The state field is in the CASE_PHI table.*/
/*“Suspect” classification removed for all Enteric diseases except Shigella toxin producing E. coli */

proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION = "Suspect"
	and s.type = "ECOLI"
	and s.REPORT_TO_CDC = 'Yes';
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table Enteric as
select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, /*DATE_FOR_REPORTING,*/
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Enteric' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
/*	case */
/*	    when MMWR_DATE_BASIS ne . then 'MMWR_DATE_BASIS'*/
/*		when SYMPTOM_ONSET_DATE ne . then 'SYMPTOM_ONSET_DATE'*/
/*	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED ne . then 'RPTI_SOURCE_DT_SUBMITTED'*/
/*	    else 'datepart(CREATE_DT)'*/
/*	    end as Reporting_Date_Type, */
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
/*where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '31DEC2023'd*/
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and STATUS = 'Closed'
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;



																				/*HAI*/

proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("CAURIS", "STRA", "SAUR", "TSS", "TSSS")
	and s.REPORT_TO_CDC = 'Yes';
quit;

/*Removed the REPORT_TO_CDC=”Yes” filter for Carbapenem-resistant Enterobacteriaceae*/
proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type = "CRE";
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table HAI as
select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, 
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Healthcare Acquired Infection' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and STATUS = 'Closed'
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;




															/*Hep Table 1 - MMWR_YEAR*/

proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("HEPB_P", "HEPA", "HEPB_A", "HEPC", "HEPB_U", "HEPCC")
	and s.REPORT_TO_CDC = 'Yes'
	and s.STATUS = 'Closed';
quit;

proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type = "HEPB_C"
	and s.STATUS in ("Closed", "Open");
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table Hep as
	select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, 
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Hepatitis' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;


																	/*RESPIRATORY 1*/

proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("FLU", "FLUD", "LEG")
	and s.REPORT_TO_CDC = 'Yes';
quit;

/*Removed the REPORT_TO_CDC=”Yes” filter for Influenza, adult death (18 years of age or more)*/
proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type = "FLUDA";
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table Resp as
select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, 
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Respiratory' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and STATUS = 'Closed'
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;


																/*RESPIRATORY 2 - TB*/
proc sql;
create table tb as
select
	year,
/*	Year as MMWR_YEAR format 4., */
/*	propcase(county) as OWNING_JD label='County' format=$30. length=30, */
	propcase(substr(county, 1, length(county)-7)) as County_substr,
	'TB' as Disease,
	'Tuberculosis' as Disease_Group,
/*	'MMWR Year' as Reporting_Date_Type,*/
	COUNT as Case_Ct label = 'Counts',
/*	COUNT as Confirmed label='Confirmed Count',*/
/*	. as Probable label='Probable Count',*/
	COUNT as Cases_County_Annual label='Cases_County_Annual'
from tb.tb_cty_cts_2015_2023
/*where 2015 LE year*/
order by year;

proc iml;
edit tb;
read all var {County_substr} where(County_substr="Mcdowell");
County_substr = "McDowell";
replace all var {County_substr} where(County_substr="Mcdowell");
close tb;



																	/*SEXUALLY TRANSMITTED*/

/*CHLAMYDIA & GONORRHEA = Deduplication Date*/

proc sql;
create table cg as
select OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, symptom_onset_date, 
	year(DEDUPLICATION_DATE) AS DEDUP_YEAR LABEL = 'YEAR OF DEDUPLICATION',
	DEDUPLICATION_DATE, 
	CALCULATED DEDUP_YEAR as Year label='Year',
	QTR(DEDUPLICATION_DATE) as Quarter,
/*	'Deduplication Date' as Reporting_Date_Type,*/
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
/*where 2015 LE CALCULATED DEDUP_YEAR */
where '01JAN2015'd LE DEDUPLICATION_DATE LE "&EndDate"d
	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and TYPE in ("CHLAMYDIA", "GONOR")
	and REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, OWNING_JD, DEDUP_YEAR;
quit;

/*LOW INCIDENCE STDS*/

/*Removed the REPORT_TO_CDC=”Yes” filter for Granuloma inguinale, Lymphogranuloma venereum,
	Nongonococcal urethritis, Pelvic inflammatory disease*/
proc sql;
create table STD as
select OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DEDUPLICATION_DATE, 
	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date,
	CALCULATED SYMPTOM_YEAR as Year label='Year',
	QTR(symptom_onset_date) as Quarter,
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
/*where 2015 LE CALCULATED SYMPTOM_YEAR*/
where '01JAN2015'd LE symptom_onset_date LE "&EndDate"d
	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and (	TYPE in  ("GRANUL", "LGRANUL", "NGURETH", "PID")
			or (TYPE = "CHANCROID" and REPORT_TO_CDC = 'Yes')	)
order by TYPE_DESC, OWNING_JD, SYMPTOM_YEAR;
quit;

/*SYPHILIS = LHD Diagnosis Date*/

proc sql;
create table syph1 as
select OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID, symptom_onset_date,
	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
/*	'LHD Diagnosis Date' as Reporting_Date_Type,*/
	year(LHD_DIAGNOSIS_DATE) AS LHD_DX_YR LABEL = 'LHD DX YEAR', LHD_DIAGNOSIS_DATE,
	CALCULATED LHD_DX_YR as Year label='Year',
	QTR(LHD_DIAGNOSIS_DATE) as Quarter,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
/*where 2015 LE CALCULATED LHD_DX_YR*/
where '01JAN2015'd LE LHD_DIAGNOSIS_DATE LE "&EndDate"d
	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
	and TYPE like "%SYPH%"
	and TYPE NOT LIKE "CONGSYPH"
	and REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, OWNING_JD, LHD_DIAGNOSIS_DATE;
quit;

proc sql;
create table syph2 as
select OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID, symptom_onset_date,
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
/*	'Birth Date' as Reporting_Date_Type,*/
	YEAR(BIRTH_DATE) as DOB label = 'YEAR OF BIRTH', LHD_DIAGNOSIS_DATE,
	CALCULATED DOB as Year label='Year',
	QTR(BIRTH_DATE) as Quarter,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
/*where 2015 LE CALCULATED DOB*/
where '01JAN2015'd LE BIRTH_DATE LE "&EndDate"d
	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
	and TYPE like "CONGSYPH"
	and REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, OWNING_JD, DOB;
quit;

/*QA*/
/*proc freq data = syph2; tables TYPE_DESC*DOB/MISSING NOCOL NOCUM NOPERCENT NOROW; run;
	
/*Combine all SYPHILIS data sets*/
data std_ALL;
set CG STD syph1 syph2;
Disease_Group='Sexually Transmitted';
run;


/*HIV/AIDS; File provided by Jason Maxwell, analyst for HIV/STD program; jason.maxwell@dhhs.nc.gov*/

/*HIV*/
data hiv1;
length Disease $4;
set HIV_quarterly;
/*set HIV_annual;*/
Disease='HIV';
/*Reporting_Date_Type='Earliest Diagnosis Date';*/
Disease_Group='Sexually Transmitted';
County_substr = propcase(OWNING_JD);
Cases_County_Quarterly=Cases;
where OWNING_JD ne "NC TOTAL";
run;

/*proc transpose data=hiv1*/
/*out=hiv1(drop=_NAME_ rename=(col1=Cases_County_Annual  _LABEL_=Year_Char));*/
/*var _2015 - _2023;*/
/*by Disease OWNING_JD Disease_Group County_substr;*/
/*run;*/

proc iml;
edit hiv1;
read all var {County_substr} where(County_substr="Mcdowell");
County_substr = "McDowell";
replace all var {County_substr} where(County_substr="Mcdowell");
close hiv1;

/*Quarterly:*/
/*proc sort data=hiv1;*/
/*by Disease OWNING_JD Disease_Group County_substr /*Cases_County_Quarterly;*/
/*run;*/
/**/

proc sql;
create table hiv1 as
select *,
/*	input(Year_Char,4.) as Year*/
	sum(Cases_County_Quarterly) as Cases_County_Annual
from hiv1
group by Year, County_substr
order by Year desc, County_substr
	, Quarter
;



																/*VPD*/


proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("DIP", "HFLU", "MEAS", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "RUB", "RUBCONG", "TET", "VARICELLA")
	and s.REPORT_TO_CDC = 'Yes';
quit;

/*Removed the REPORT_TO_CDC=”Yes” filter for Acute flaccid myelitis, Pneumococcal meningitis, Vaccinia;*/
proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("AFM", "MENP", "VAC");
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table VPD as
select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, 
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Vaccine Preventable' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and STATUS = 'Closed'
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;



																/*ZOONOTIC*/


proc sql;
create table CASE_COMBO as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("ANTH", "ARB", "BRU", "CHIKV", "DENGUE", "EHR", "HGE", "EEE", "HME", 
	"LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", 
	"YF", "ZIKA", "VHF")
	and s.REPORT_TO_CDC = 'Yes';
quit;

/*Removed the REPORT_TO_CDC=”Yes” filter for Creutzfeldt-Jakob Disease*/
proc sql;
create table CASE_COMBO_sub as
select s.*, /*a.State*/a.EVENT_STATE, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("CJD");
quit;

data case_combo;
set case_combo case_combo_sub;
run;

proc sql;
create table zoo as
select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Vector-Borne/Zoonotic' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else datepart(CREATE_DT)
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, /*state*/EVENT_STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= "&EndDate"d
	and STATUS = 'Closed'
	and /*state*/EVENT_STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;

/*QA*/
/*proc freq data = zoo; tables TYPE_DESC*SYMPTOM_YEAR/MISSING NOCOL NOCUM NOPERCENT NOROW; RUN;


/*Union all diseases summary in period - add disease group and meta data*/

data final;
length Disease_Group $30;
set Enteric HAI Hep Resp std_ALL VPD zoo;
County_substr=substr(OWNING_JD, 1, length(OWNING_JD)-7);
run;

/*Cleaning disease names*/
data final;
set final;
Disease=scan(TYPE_DESC, 1, '(');
if Disease='Syphilis - 01. Primary Syphilis' then Disease='Syphilis - Primary Syphilis';
	else if Disease='Syphilis - 02. Secondary Syphilis' then Disease='Syphilis - Secondary Syphilis';
	else if Disease='Syphilis - 03. Early, Non-Primary, Non-Secondary Syphilis' then Disease='Syphilis - Early, Non-Primary, Non-Secondary Syphilis';
	else if Disease='Syphilis - 05. Late Latent Syphilis' then Disease='Syphilis - Late Latent Syphilis';
	else if Disease='Syphilis - 05. Syphilis Late w/ clinical manifestations' then Disease='Syphilis - Late Latent Syphilis';
	else if Disease='Syphilis - 05. Unknown Duration or Late Syphilis' then Disease='Syphilis - Late Latent Syphilis';
	else if Disease='Syphilis - 08. Congenital Syphilis' then Disease='Syphilis - Congenital Syphilis';
	else if Disease='Syphilis - Unknown Syphilis' then delete;
	else if Disease='Carbapenem-resistant Enterobacteriaceae' then Disease='Carbapenem-resistant Enterobacterales';
	else if Disease='Campylobacter infection' then Disease='Campylobacteriosis';
/*	else if Disease='Chlamydia' then Disease='Chlamydia trachomatis infection';*/
	else if Disease='Monkeypox' then Disease='Mpox';
	else if Disease='ZIKA' then Disease='Zika';
	else if Disease='Foodborne poisoning' then Disease='Foodborne poisoning (fish/mushroom/ciguatera)';
	else if Disease='Vibrio infection' then Disease='Vibrio infection (other than cholera and vulnificus)';
where County_substr is not missing and TYPE_DESC is not missing;
run;

/*proc sort data=final;*/
/*by descending Year OWNING_JD TYPE_DESC CLASSIFICATION_CLASSIFICATION Age CASE_ID;*/
/*run;*/

/*libname interim 'T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\Interim';*/
/*data interim.final; */
/*set final;*/
/*run;*/



/*Add year to county population file; fix county name*/

proc sql;
create table temp as
select *
from county_pops
where year=2023;

data temp_2024;
set temp;
year=2024;
run;

data county_pops;
set county_pops temp_2024;
COUNTY = propcase(COUNTY);
run;

proc iml;
edit county_pops;
read all var {COUNTY} where(COUNTY="Mcdowell");
COUNTY = "McDowell";
replace all var {COUNTY} where(COUNTY="Mcdowell");
close county_pops;


/*Aggregate cases*/

ods listing;
ods results;

proc sql;
create table agg_annual as
select
	Year,  County_substr,
	Disease, /*Reporting_Date_Type,*/ Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',*/
	count(distinct CASE_ID) as Cases_County_Annual
from final
group by Year, County_substr, Disease, /*Reporting_Date_Type,*/ Disease_Group
order by Year desc, County_substr, Disease;


proc sort data=hiv1 out=hiv_annual (keep=Disease County_substr Year Disease_Group Disease Cases_County_Annual) nodupkey;
by Year County_substr;
run;

data agg_annual;
set agg_annual hiv_annual tb(drop=Case_Ct);
run;


proc sql;
create table agg_quarter as
select
	Year, Quarter, County_substr,
/*	OWNING_JD label='County' format=$30. length=30, */
	Disease, Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed_Quarterly label='Confirmed Count Quarterly',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable_Quarterly label='Probable Count Quarterly',*/
	count(distinct CASE_ID) as Cases_County_Quarterly
from final
group by Year, Quarter, County_substr, Disease, Disease_Group
order by Year desc, Quarter, County_substr, Disease;

data agg_quarter;
set agg_quarter
	hiv1(keep=Year Quarter County_Substr Disease Disease_Group Cases_County_Quarterly);
run;

/*Add rows for when no cases were reported for the county/year/disease*/

proc sort data=county_pops out=unique_counties (keep=COUNTY) nodupkey ;
by COUNTY;
run;

data unique_diseases;
set agg_annual;
run;
proc sort data=unique_diseases out=unique_diseases (keep=Disease Disease_Group) nodupkey ;
by Disease;
run;
data unique_diseases;
set unique_diseases;
if cmiss(of _all_) then delete;
run;

data unique_years;
do Year=2015 to 2024; output; end;
run;

data unique_quarters;
do Quarter=1 to 4; output; end;
run;

proc sql;
create table unique_table/*_a*/ as
select unique_counties.*, unique_diseases.Disease, unique_years.* 
	, unique_quarters.*
from unique_counties cross join unique_diseases cross join unique_years
	cross join unique_quarters
;

proc sql;
create table agg_quarter as
/*create table agg_annual as*/
select coalesce(a.Year,b.Year) as Year, coalescec(a.Disease,b.Disease) as Disease, a.Disease_Group,
	coalescec(a.County_substr,b.COUNTY) as County_substr/*, a.**/
	, a.Cases_County_Quarterly, coalesce(a.Quarter,b.Quarter) as Quarter
from agg_quarter a full join unique_table b
/*from agg_annual a full join unique_table b*/
	on a.year=b.year and a.Disease=b.Disease and a.County_substr=b.COUNTY
	and a.Quarter=b.Quarter
	;

proc sql;
create table case_agg as
select coalesce(a.Year,b.Year) as Year,
	coalesce(a.County_substr,b.County_substr) as County_substr,
	coalesce(a.Disease,b.Disease) as Disease, 
	coalesce(a.Disease_Group,b.Disease_Group) as Disease_Group,
	a.Cases_County_Annual, b.Quarter, b.Cases_County_Quarterly
from agg_annual a full join agg_quarter b
on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease
order by Year desc, County_substr, Disease;



/*Add rows for when no cases were reported for the county/year/disease*/

/*proc sort data=agg_annual out=unique_diseases (keep=Disease Reporting_Date_Type Disease_Group) nodupkey ;*/
/*by Disease;*/
/*run;*/
/*data unique_diseases;*/
/*set unique_diseases;*/
/*Disease=Disease;*/
/*if cmiss(of _all_) then delete;*/
/*run;*/
/**/
/*proc sql;*/
/*create table unique_table_b as*/
/*select unique_counties.*, unique_diseases.Disease, unique_years.* , unique_quarters.**/
/*from unique_counties cross join unique_diseases cross join unique_years cross join unique_quarters;*/


/*proc sql;*/
/*create table cases as*/
/*select coalesce(a.Year,b.Year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.Disease,b.Disease) as Disease,*/
/*	coalesce(a.County_substr,b.COUNTY) as County_substr, a.**/
/*from case_agg a full join unique_table_b b*/
/*	on a.year=b.year and a.Quarter=b.Quarter and a.Disease=b.Disease and a.County_substr=b.COUNTY;*/


/*Join with county population data*/
proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.County_substr,b.COUNTY) as County_substr, a.*, b.*
/*from cases a left join county_pops b*/
from case_agg a left join county_pops b
/*from agg_annual a left join county_pops b*/
	on a.Year=b.year and a.County_substr=b.COUNTY;

data case_rates (keep=Year County_substr Disease Disease_Group Cases_County_Annual county_pop_adjusted
Quarter Cases_County_Quarterly
male female white black ai_an asian_pi multi_race hispanic nonhispanic);
set case_rates;
/*if Disease='Influenza, pediatric death' then county_pop_adjusted=age_0_17;*/
/*	else if Disease='Influenza, adult death' then county_pop_adjusted=age_18GE;*/
if Disease='Influenza, pediatric death' then county_pop_adjusted=age_0_12+age_13_17;
	else if Disease='Influenza, adult death' then county_pop_adjusted=age_18_24+age_25_49+age_50_64+age_GE65;
	else if Disease='HIV' then county_pop_adjusted=county_pop-age_0_12;
	else county_pop_adjusted=county_pop;
run;


/*Replace missing case totals and incidence with 0*/
data case_rates;
set case_rates;
if missing(Cases_County_Annual) then Cases_County_Annual=0;
County_Incidence_100k=Cases_County_Annual/county_pop_adjusted*100000;
format County_Incidence_100k 8.1;
if missing(Cases_County_Quarterly) then Cases_County_Quarterly=0;
County_Incidence_100k_Quarterly=Cases_County_Quarterly/county_pop_adjusted*100000;
format County_Incidence_100k_Quarterly 8.1;
run;

/*Add disease_groups back*/
proc sql;
create table case_rates as
select /*coalesce(a.Reporting_Date_Type,b.Reporting_Date_Type) as Reporting_Date_Type,*/
	coalesce(a.Disease_Group,b.Disease_Group) as Disease_Group, a.*
from case_rates a left join unique_diseases b
on a.Disease=b.Disease;


/*Add state rates*/

proc sql;
create table temp as
select *
from state_pops
where year=2023;

data temp_2024;
set temp;
year=2024;
run;

data state_pops;
set state_pops temp_2024;
run;


proc sort data=case_rates out=case_rates_annual_nodup(keep=Year Disease Cases_County_Annual County_substr) nodupkey;
by descending Year Disease County_substr;
run;

proc sql;
create table state_rates_annual as
select
	Year, Disease, sum(Cases_County_Annual) as Cases_State_Annual
from case_rates_annual_nodup
group by Year, Disease
order by Year desc, Disease;


proc sql;
create table state_rates_quarter as
select
	Year, Quarter, Disease, sum(Cases_County_Quarterly) as Cases_State_Quarterly
from case_rates
group by Year, Quarter, Disease
order by Year desc, Quarter, Disease;

proc sql;
create table state_rates as
select a.*, b.*
from state_rates_annual a natural join state_rates_quarter b;

proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.Disease,b.Disease) as Disease, a.*, b.Cases_State_Annual
	, coalesce(a.Quarter,b.Quarter) as Quarter, b.Cases_State_Quarterly
from case_rates a full join state_rates b
/*from case_rates a full join state_rates_annual b*/
	on a.year=b.year and a.Disease=b.Disease
		and a.Quarter=b.Quarter
;

proc sql;
create table case_rates as
select a.*, b.*
from case_rates a left join state_pops b
	on a.Year=b.year;

proc sql;
create table case_rates as
select a.*, b.Region
from case_rates a left join regions b
	on a.County_substr=b.County;

/*Finalize*/

data case_rates_final (keep=Year Disease Disease_Group County_substr Cases_County_Annual Region
	county_pop_adjusted County_Incidence_100k Cases_State_Annual state_pop_adjusted State_Incidence_100k
	Quarter Cases_County_Quarterly County_Incidence_100k_Quarterly Cases_State_Quarterly State_Incidence_100k_Quarterly
	); 
set case_rates;
where Year <=2024;
if (Year=2024 and Quarter=4) then delete;
if missing(Cases_State_Annual) then Cases_State_Annual=0;
/*if Disease='Influenza, pediatric death' then state_pop_adjusted=age_0_17;*/
/*	else if Disease='Influenza, adult death' then state_pop_adjusted=age_18GE;*/
if Disease='Influenza, pediatric death' then state_pop_adjusted=age_0_12+age_13_17;
	else if Disease='Influenza, adult death' then state_pop_adjusted=age_18_24+age_25_49+age_50_64+age_GE65;
	else if Disease='HIV' then state_pop_adjusted=total_pop-age_0_12;
	else state_pop_adjusted=total_pop;
if Disease='Botulism - infant' then do;
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		County_Incidence_100k_Quarterly=.;
		State_Incidence_100k_Quarterly=.;
		end;
	else if Disease='Hepatitis B - Perinatally Acquired' then do;
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		County_Incidence_100k_Quarterly=.;
		State_Incidence_100k_Quarterly=.;
		end;
	else if Disease='Syphilis - Congenital Syphilis' then do;
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		County_Incidence_100k_Quarterly=.;
		State_Incidence_100k_Quarterly=.;
		end;
	else if Disease='TB' then do;
		County_Incidence_100k=round(County_Incidence_100k, .1);
		State_Incidence_100k=round(Cases_State_Annual/state_pop_adjusted*100000, .1);
		Cases_County_Quarterly=.;
		Cases_State_Quarterly=.;
		County_Incidence_100k_Quarterly=.;
		State_Incidence_100k_Quarterly=.;
		end;
	else do;
		County_Incidence_100k=round(County_Incidence_100k, .1);
		State_Incidence_100k=round(Cases_State_Annual/state_pop_adjusted*100000, .1);
		County_Incidence_100k_Quarterly=round(County_Incidence_100k_Quarterly, .1);
		State_Incidence_100k_Quarterly=round(Cases_State_Quarterly/state_pop_adjusted*100000, .1);
		end;
format County_Incidence_100k State_Incidence_100k
	County_Incidence_100k_Quarterly State_Incidence_100k_Quarterly
	8.1;
run;

proc sort data=case_rates_final;
by descending Year Disease County_substr Quarter;
run;

/*Un-comment section below to export file for importing to Tableau:*/

/*proc export data=case_rates_final*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\11-01-24_data_aggregated_quarterly.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Cases by County";*/
/*run;*/

/*proc export data=case_rates_final*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\10-02-24_data_aggregated_annual.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Cases by County";*/
/*run;*/



											/*Demographics Section*/


/*Match race choices with population data variables*/
proc sql;
create table demoInput(drop=RACE1 RACE2 RACE3 RACE4 RACE5 RACE6) as
select *,
	case
			when (RACE2 ne '' or RACE3 ne '' or RACE4 ne '' or RACE5 ne '' or RACE6 ne '') then "Multi-Race"
			when RACE1='Asian' then 'Asian or Native Hawaiian or Pacific Islander'
			when RACE1='Native Hawaiian or Pacific Islander' then 'Asian or Native Hawaiian or Pacific Islander'
			else RACE1
		end as Race
from final
	where Year <=2023;

/*Combine responses that are Missing/Unknown*/
data demoInput;
format HISPANIC $15.;
set demoInput;
if Race='' then Race='Missing/Unknown';
else if Race='Unknown' then Race='Missing/Unknown';

if find(Hispanic,"Yes")>0 then HISPANIC='Hispanic';
else if find(Hispanic,"No")>0 then HISPANIC='Non-Hispanic';
else if HISPANIC='' then HISPANIC='Missing/Unknown';
else if find(Hispanic, "Unknown")>0 then HISPANIC='Missing/Unknown';
run;


/*Create Age Bins*/
proc format;
value agegrp
/*	0-<5='0-5'*/
/*	5-<12='5-12'*/
	0-<13='0-12'
	13-<18='13-17'
	18-<25='18-24'
	25-<50='25-49'
	50-<65='50-64'
	65-high='65+'
	.='Missing/Unknown';
run;


/*Add year to demographic population tables; Apply suppression*/

/*proc sql;*/
/*create table temp as*/
/*select **/
/*from demo_county_pops*/
/*where year=2022;*/
/*data temp;*/
/*set temp;*/
/*year=2023;*/
/*run;*/

data demo_county_pops;
set county_pops /*temp*/;
COUNTY = propcase(COUNTY);
run;
proc iml;
edit demo_county_pops;
read all var {COUNTY} where(COUNTY="Mcdowell");
COUNTY = "McDowell";
replace all var {COUNTY} where(COUNTY="Mcdowell");
close demo_county_pops;

data demo_county_pops_sup;
set demo_county_pops;
array tosuppress _numeric_;
	do over tosuppress;
	if tosuppress<500 then tosuppress='';
	end;
run;


/*proc sql;*/
/*create table temp as*/
/*select **/
/*from demo_state_pops*/
/*where year=2022;*/
/*data temp;*/
/*set temp;*/
/*year=2023;*/
/*run;*/

data demo_state_pops;
set state_pops /*temp*/;
run;

data demo_state_pops_sup;
set demo_state_pops;
array tosuppress _numeric_;
	do over tosuppress;
	if tosuppress<500 then tosuppress='';
	end;
run;


data county_pops_sup;
set county_pops;
array tosuppress _numeric_;
	do over tosuppress;
	if tosuppress<500 then tosuppress='';
	end;
run;

data state_pops_sup;
set state_pops;
array tosuppress _numeric_;
	do over tosuppress;
	if tosuppress<500 then tosuppress='';
	end;
run;


%macro suppress_cases(group);

/*data &group;*/
/*set &group;*/
/*format County_Demo_Annual_Incidence 10.1;*/
/*County_Demo_Annual_Incidence=County_Demo_Annual_Cases/Population_County*100000;*/
/*County_Annual_Cases_Sup=0;*/
/*County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);*/
/*if Demographic NE 'Missing/Unknown' and State_Annual_Incidence=. then do;*/
/*	County_Annual_Cases_Sup=County_Demo_Annual_Cases;*/
/*	County_Demo_Annual_Cases=0;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	end;*/
/*if Demographic NE 'Missing/Unknown' and County_Demo_Annual_Incidence=. then do;*/
/*	County_Annual_Cases_Sup=County_Demo_Annual_Cases;*/
/*	County_Demo_Annual_Cases=0;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	end;*/


/*If population<500 for year-county-disease-demographic, then suppress those cases,
	and also suppress second lowest if not already included;
	total cases suppressed are shown in 'Suppressed' subgroup*/
data &group;
set &group;
format County_Demo_Annual_Incidence 10.1;
County_Demo_Annual_Incidence=round(County_Demo_Annual_Cases/Population_County*100000, .1);
pop_lt500_suppressed=0;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other' and State_Annual_Incidence=. then do;
	pop_lt500_suppressed=County_Demo_Annual_Cases;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other' and County_Demo_Annual_Incidence=. then do;
	pop_lt500_suppressed=County_Demo_Annual_Cases;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
run;

proc sort data=&group;
  by Year County_substr Disease Population_County/* County_Annual_Cases_Sup*/;
run;

data SecondLowestPopTable(keep=Year County_substr Disease SecondLowestPop);
set &group;
SecondLowestPop=Demographic;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table &group as
select a.*, b.*
from &group a left join SecondLowestPopTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

/*proc sort data=&group;*/
/*by Year County_substr Disease Demographic;*/
/*run;*/

proc sql;
create table suppress_le500 as
select Year, County_substr, Disease,
/*	Disease_Group, Cases_County_Annual, Demographic_Group, SecondLowestPop,*/
/*	'Total Suppressed' as Demographic,*/
	'Yes' as pop_lt500,
	sum(pop_lt500_suppressed) as suppressed_total
from &group
group by Year, County_substr, Disease
/*	, Disease_Group, Cases_County_Annual, Demographic_Group, SecondLowestPop*/
having suppressed_total>0;

/*data &group;*/
/*set &group suppress_le500(drop=pop_lt500 suppressed_total);*/
/*run;*/

proc sql;
create table &group as
select a.*, b.pop_lt500, b.suppressed_total
from &group a left join suppress_le500 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

data &group;
set &group;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
/*if Suppression='Yes' and Demographic ne 'Suppressed'*/
/*if Demographic NE 'Missing/Unknown' and Population_County=. and Demographic ne 'Suppressed'*/
/*	then County_Annual_Cases_char='Suppressed';*/
if Demographic NE 'Missing/Unknown' and Demographic NE 'Other' and Population_County=. then County_Annual_Cases_char='Suppressed';
if pop_lt500='Yes' and Demographic=SecondLowestPop then do;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
	else if pop_lt500='' then pop_lt500='No';
drop SecondLowestPop pop_lt500_suppressed;
run;


/*If only one bar is shown in figure for year-county-disease-demographic,
	then suppress number of cases and number suppressed for that demographic*/
/*proc sql;*/
/*create table count_bars as*/
/*select Year, County_substr, Disease,*/
/*	count(Demographic) as n_bars*/
/*from &group*/
/*where Demographic ne 'Suppressed'*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join count_bars b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group(drop=n_bars pop_lt500);*/
/*set &group;*/
/*if pop_lt500='Yes' and n_bars =1 then do;*/
/*	County_Demo_Annual_Cases=.;*/
/*	County_Demo_Annual_Incidence=.;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	end;*/
/*run;*/

%mend;


%macro suppress_cases_mult(group);

data &group;
set &group;
format County_Demo_Annual_Incidence 10.1;
County_Demo_Annual_Incidence=round(County_Demo_Annual_Cases/Population_County*100000, .1);
pop_lt500_suppressed=0;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other'
	and Demographic2 NE 'Missing/Unknown' and Demographic2 NE '' and Demographic2 NE 'Other' and State_Annual_Incidence=. then do;
		pop_lt500_suppressed=County_Demo_Annual_Cases;
		County_Demo_Annual_Cases=0;
		County_Annual_Cases_char='Suppressed';
		end;
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other'
	and Demographic2 NE 'Missing/Unknown' and Demographic2 NE '' and Demographic2 NE 'Other' and County_Demo_Annual_Incidence=. then do;
		pop_lt500_suppressed=County_Demo_Annual_Cases;
		County_Demo_Annual_Cases=0;
		County_Annual_Cases_char='Suppressed';
		end;
run;

proc sort data=&group;
  by Year County_substr Disease Population_County/* County_Annual_Cases_Sup*/;
run;

data SecondLowestPopTable(keep=Year County_substr Disease SecondLowestPop SecondLowestPop2);
set &group;
SecondLowestPop=Demographic;
SecondLowestPop2=Demographic2;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table &group as
select a.*, b.*
from &group a left join SecondLowestPopTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

/*proc sort data=&group;*/
/*by Year County_substr Disease Demographic Demographic2;*/
/*run;*/

proc sql;
create table suppress_le500 as
select Year, County_substr, Disease,
/*	Disease_Group, Cases_County_Annual, Demographic_Group, SecondLowestPop, SecondLowestPop2,*/
/*	'Total Suppressed' as Demographic, 'Total Suppressed' as Demographic2,*/
	'Yes' as pop_lt500,
	sum(pop_lt500_suppressed) as suppressed_total
from &group
group by Year, County_substr, Disease
/*	, Disease_Group, Cases_County_Annual, Demographic_Group, SecondLowestPop, SecondLowestPop*/
having suppressed_total>0;

/*data &group;*/
/*set &group suppress_le500(drop=pop_lt500 suppressed_total);*/
/*run;*/

proc sql;
create table &group as
select a.*, b.*
from &group a left join suppress_le500 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

data &group;
set &group;
/*County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);*/
/*if Suppression='Yes' and Demographic ne 'Suppressed'*/
/*if Demographic NE 'Missing/Unknown' and Demographic2 NE 'Missing/Unknown' and Population_County=. and Demographic ne 'Suppressed'*/
/*	then County_Annual_Cases_char='Suppressed';*/
if pop_lt500='Yes' and Demographic=SecondLowestPop and Demographic2=SecondLowestPop2 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
	else if pop_lt500='' then pop_lt500='No';
drop SecondLowestPop SecondLowestPop2 pop_lt500_suppressed;
run;

/*proc sql;*/
/*create table count_bars as*/
/*select Year, County_substr, Disease, */
/*	count(Demographic) as n_bars*/
/*from &group*/
/*where Demographic ne 'Suppressed' and Demographic2 ne 'Suppressed'*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join count_bars b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group(drop=n_bars);*/
/*set &group;*/
/*if pop_lt500='Yes' and n_bars =1 then do;*/
/*	County_Demo_Annual_Cases=.;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	end;*/
/*run;*/

/*If cases <= 5 for year-county-disease-demographic, then suppress those cases, 
	and also suppress second lowest case aggregate if not already included;
	total cases suppressed are added to 'Suppressed' subgroup*/
proc sort data=&group;
  by Year County_substr Disease County_Demo_Annual_Cases;
run;

data SecondLowestCasesTable(keep=Year County_substr Disease SecondLowestCases);
set &group;
where County_Demo_Annual_Cases ne 0;
SecondLowestCases=County_Demo_Annual_Cases;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table &group as
select a.*, b.*
from &group a left join SecondLowestCasesTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table county_demo_le5 as
select Year, County_substr, Disease, 
	sum(County_Demo_Annual_Cases) as demo_cases_le5_count,
	case when min(County_Demo_Annual_Cases) le 5 then 'Yes' else 'No'
	end as demo_cases_le5
from &group
/*where Demographic ne 'Suppressed' and Demographic2 ne 'Suppressed' and County_Demo_Annual_Cases ne 0*/
where 0 < County_Demo_Annual_Cases le 5 and Demographic ne ''
group by Year, County_substr, Disease;

proc sql;
create table &group as
select a.*, b.demo_cases_le5_count, b.demo_cases_le5
from &group a left join county_demo_le5 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

/*proc sql;*/
/*create table county_demo_le5_count as*/
/*select Year, County_substr, Disease, */
/*	sum(County_Demo_Annual_Cases) as demo_cases_le5_count*/
/*from &group*/
/*where County_Demo_Annual_Cases le 5*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.demo_cases_le5_count*/
/*from &group a left join county_demo_le5_count b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/

/*data &group(drop=SecondLowestCases demo_cases_le5);*/
/*set &group;*/
/*if 0 < County_Demo_Annual_Cases le 5 then County_Annual_Cases_char='Suppressed';*/
/*if demo_cases_le5='Yes' and County_Demo_Annual_Cases=SecondLowestCases then County_Annual_Cases_char='Suppressed';*/
/*run;*/

data &group(drop=SecondLowestCases demo_cases_le5 demo_cases_le5_count);
set &group;
if demo_cases_le5='Yes' and suppressed_total=. then suppressed_total=0;
if demo_cases_le5='Yes' then suppressed_total=suppressed_total+demo_cases_le5_count+SecondLowestCases;
if 0 < County_Demo_Annual_Cases le 5 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
if demo_cases_le5='Yes' and County_Demo_Annual_Cases=SecondLowestCases then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
run;

%mend;


/*%macro secondary_suppress(group);*/
/**/
/*proc sort data=&group;*/
/*  by Year County_substr Disease Population_County descending County_Annual_Cases_Sup;*/
/*run;*/
/**/
/*data SecondLowestTable(keep=Year County_substr Disease SecondLowest);*/
/*set &group;*/
/*SecondLowest=Demographic;*/
/*by Year County_substr Disease;*/
/*if first.Disease then Marker=0;*/
/*  Marker+1;*/
/*if Marker = 2;*/
/*run;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join SecondLowestTable b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*proc sql;*/
/*create table suppression as*/
/*select Year, County_substr, Disease, Disease_Group, Cases_County_Annual,*/
/*	'Suppressed' as Demographic, 'Yes' as pop_lt500,*/
/*	sum(County_Annual_Cases_Sup) as County_Demo_Annual_Cases*/
/*from &group*/
/*group by Year, County_substr, Disease, Disease_Group, Cases_County_Annual*/
/*having County_Demo_Annual_Cases>0*/
/*order by Year desc, County_substr, Disease;*/
/**/
/*data &group;*/
/*set &group suppression(drop=pop_lt500);*/
/*run;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join suppression(keep=Year County_substr Disease pop_lt500) b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group;*/
/*set &group;*/
/*if pop_lt500='' then pop_lt500='No';*/
/*run;*/
/**/
/*data &group;*/
/*set &group;*/
/*County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);*/
/*if pop_lt500='Yes' and Demographic=SecondLowest then do;*/
/*	County_Demo_Annual_Cases=0;*/
/*	County_Annual_Cases_char='Suppressed'; end;*/
/*drop SecondLowest;*/
/*run;*/
/**/
/*proc sql;*/
/*create table count_bars as*/
/*select Year, County_substr, Disease, */
/*	count(Demographic) as n_bars*/
/*from &group*/
/*where Demographic ne 'Suppressed'*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join count_bars b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group(drop=n_bars pop_lt500);*/
/*set &group;*/
/*if pop_lt500='Yes' and n_bars =1 then do;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	County_Demo_Annual_Cases=.;*/
/*	end;*/
/*run;*/
/**/
/*%mend;*/


/*%macro secondary_suppress_mult(group);*/
/**/
/*proc sort data=&group;*/
/*  by Year County_substr Disease Population_County descending County_Annual_Cases_Sup;*/
/*run;*/
/**/
/*data SecondLowestTable(keep=Year County_substr Disease SecondLowest SecondLowest2);*/
/*set &group;*/
/*SecondLowest=Demographic;*/
/*SecondLowest2=Demographic2;*/
/*by Year County_substr Disease;*/
/*if first.Disease then Marker=0;*/
/*  Marker+1;*/
/*if Marker = 2;*/
/*drop Marker;*/
/*run;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join SecondLowestTable b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*proc sql;*/
/*create table suppression as*/
/*select Year, County_substr, Disease, Disease_Group, Cases_County_Annual,*/
/*	'Suppressed' as Demographic, 'Suppressed' as Demographic2,  'Yes' as pop_lt500,*/
/*	sum(County_Annual_Cases_Sup) as County_Demo_Annual_Cases*/
/*from &group*/
/*group by Year, County_substr, Disease, Disease_Group, Cases_County_Annual*/
/*having County_Demo_Annual_Cases>0*/
/*order by Year desc, County_substr, Disease;*/
/**/
/*data &group;*/
/*set &group suppression(drop=pop_lt500);*/
/*run;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join suppression(keep=Year County_substr Disease pop_lt500) b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group;*/
/*set &group;*/
/*if pop_lt500='' then pop_lt500='No';*/
/*run;*/
/**/
/*data &group;*/
/*set &group;*/
/*County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);*/
/*if pop_lt500='Yes' and Demographic=SecondLowest and Demographic2=SecondLowest2 then do;*/
/*	County_Demo_Annual_Cases=0;*/
/*	County_Annual_Cases_char='Suppressed'; end;*/
/*drop SecondLowest SecondLowest2;*/
/*run;*/
/**/
/*proc sql;*/
/*create table count_bars as*/
/*select Year, County_substr, Disease, */
/*	count(Demographic) as n_bars*/
/*from &group*/
/*where Demographic ne 'Suppressed' and Demographic2 ne 'Suppressed'*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join count_bars b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group(drop=n_bars pop_lt500);*/
/*set &group;*/
/*if pop_lt500='Yes' and n_bars =1 then do;*/
/*	County_Annual_Cases_char='Suppressed';*/
/*	County_Demo_Annual_Cases=.;*/
/*	end;*/
/*run;*/
/**/
/**/
/*proc sort data=&group;*/
/*  by Year County_substr Disease County_Demo_Annual_Cases;*/
/*run;*/
/**/
/*data SecondLowestCasesTable(keep=Year County_substr Disease SecondLowestCases);*/
/*set &group;*/
/*where County_Demo_Annual_Cases ne 0;*/
/*SecondLowestCases=County_Demo_Annual_Cases;*/
/*by Year County_substr Disease;*/
/*if first.Disease then Marker=0;*/
/*  Marker+1;*/
/*if Marker = 2;*/
/*drop Marker;*/
/*run;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join SecondLowestCasesTable b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*proc sql;*/
/*create table county_demo_le5 as*/
/*select Year, County_substr, Disease, */
/*	case when min(County_Demo_Annual_Cases) le 5 then 'Yes' else 'No'*/
/*	end as demo_cases_le5*/
/*from &group*/
/*where Demographic ne 'Suppressed' and Demographic2 ne 'Suppressed' and County_Demo_Annual_Cases ne 0*/
/*group by Year, County_substr, Disease;*/
/**/
/*proc sql;*/
/*create table &group as*/
/*select a.*, b.**/
/*from &group a left join county_demo_le5 b*/
/*		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;*/
/**/
/*data &group(drop=SecondLowestCases demo_cases_le5);*/
/*set &group;*/
/*if 0 < County_Demo_Annual_Cases le 5 then County_Annual_Cases_char='Suppressed';*/
/*if demo_cases_le5='Yes' and County_Demo_Annual_Cases=SecondLowestCases then County_Annual_Cases_char='Suppressed';*/
/*run;*/
/**/
/*%mend;*/


/*If no data, ''; N and IR not shown.
  If response is present in NC EDSS but not represented in the population file, ''; N shown, IR not shown.
  If data are present in both files but suppressed due to population denominator, '0'; N and IR are shown as '0';
	next-lowest subcategory is also shown as '0'.*/



/*Generate Age Summary*/

data agg_agegroup;
set demoInput;
	Demographic=put(age, agegrp.);
run;

proc sql;
create table agg_agegroup as
select Year, County_substr, Disease, Disease_Group, 
	Demographic, count(distinct CASE_ID) as County_Demo_Annual_Cases
from agg_agegroup
group by Year, County_substr, Disease, Disease_Group, Demographic
order by Year desc, County_substr, Disease, Demographic;

proc sql;
create table agg_agegroup as
select a.*, b.Cases_County_Annual
from agg_agegroup a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_agegroup_state as
select
	Year, Disease, Demographic,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_agegroup
group by Year, Disease, Demographic
order by Year desc, Disease, Demographic;
proc sql;
create table agg_agegroup as
select a.*, b.State_Annual_Cases
from agg_agegroup a left join agg_agegroup_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic
order by Year desc, County_substr, Disease, Demographic;


proc sql;
create table rates_agegroup as
select a.*, b.*
from agg_agegroup a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_agegroup as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='0-12' then age_0_12
			when Demographic='13-17' then age_13_17
			when Demographic='18-24' then age_18_24
			when Demographic='25-49' then age_25_49
			when Demographic='50-64' then age_50_64
			when Demographic='65+' then age_GE65
		end as Population_State
from rates_agegroup;

proc sql;
create table rates_agegroup as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_agegroup a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_agegroup as
select
	Year, County_substr, Disease, Disease_Group, Demographic,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case when Demographic='0-12' then age_0_12
		when Demographic='13-17' then age_13_17
		when Demographic='18-24' then age_18_24
		when Demographic='25-49' then age_25_49
		when Demographic='50-64' then age_50_64
		when Demographic='65+' then age_GE65
		end as Population_County,
	'Age Group' as Demographic_Group
from rates_agegroup
order by Year desc, County_substr, Disease, Demographic;

/*%suppress_cases(rates_agegroup);*/
/*%secondary_suppress(rates_agegroup);*/

proc delete data=work.agg_agegroup work.agg_agegroup_state;
run;


/*Generate Gender Summary*/

proc sql;
create table agg_GENDER as
select
	Year, County_substr, Disease, Disease_Group,
	GENDER as Demographic length=45, count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic
order by Year desc, County_substr, Disease, Demographic;

proc sql;
create table agg_GENDER as
select a.*, b.Cases_County_Annual
from agg_GENDER a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_GENDER_state as
select
	Year, Disease, Demographic,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_GENDER
group by Year, Disease, Demographic
order by Year desc, Disease, Demographic;

proc sql;
create table agg_GENDER as
select a.*, b.*
from agg_GENDER a left join agg_GENDER_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic
order by Year desc, County_substr, Disease, Demographic;


proc sql;
create table rates_GENDER as
select a.*, b.*
from agg_GENDER a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDER as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Female' and Disease='Influenza, adult death' then female_age_18GE
			when Demographic='Female' and Disease='Influenza, pediatric death' then female_age_0_17
			when Demographic='Male' and Disease='Influenza, adult death' then male_age_18GE
			when Demographic='Male' and Disease='Influenza, pediatric death' then male_age_0_17
			when Demographic='Female' then female
			when Demographic='Male' then male
		end as Population_State
from rates_GENDER;

proc sql;
create table rates_GENDER as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_GENDER a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDER as
select
	Year, County_substr, Disease, Disease_Group, Demographic,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='Female' and Disease='Influenza, adult death' then female_age_18GE
			when Demographic='Female' and Disease='Influenza, pediatric death' then female_age_0_17
			when Demographic='Male' and Disease='Influenza, adult death' then male_age_18GE
			when Demographic='Male' and Disease='Influenza, pediatric death' then male_age_0_17
			when Demographic='Female' then female
			when Demographic='Male' then male
		end as Population_County,
	'Gender' as Demographic_Group
from rates_GENDER
order by Year desc, County_substr, Disease, Demographic;

/*%suppress_cases(rates_GENDER);*/
/*%secondary_suppress(rates_GENDER);*/

proc delete data=work.agg_GENDER work.agg_GENDER_state;
run;


/*Generate Ethnicity-Hispanic Summary*/

proc sql;
create table agg_HISPANIC as
select
	Year, County_substr, Disease, Disease_Group,
	HISPANIC as Demographic length=45,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic
order by Year desc, County_substr, Disease, Demographic;

proc sql;
create table agg_HISPANIC as
select a.*, b.Cases_County_Annual
from agg_HISPANIC a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_HISPANIC_state as
select
	Year, Disease, Demographic,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_HISPANIC
group by Year, Disease, Demographic
order by Year desc, Disease, Demographic;

proc sql;
create table agg_HISPANIC as
select a.*, b.*
from agg_HISPANIC a left join agg_HISPANIC_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic
order by Year desc, County_substr, Disease, Demographic;


proc sql;
create table rates_HISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from agg_HISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_HISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Hispanic' and Disease='Influenza, adult death' then hispanic_age_18GE
			when Demographic='Hispanic' and Disease='Influenza, pediatric death' then hispanic_age_0_17
			when Demographic='Non-Hispanic' and Disease='Influenza, adult death' then nonhispanic_age_18GE
			when Demographic='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhispanic_age_0_17
			when Demographic='Hispanic' then hispanicyes
			when Demographic='Non-Hispanic' then nonhispanic
		end as Population_State
from rates_HISPANIC;

proc sql;
create table rates_HISPANIC as
select a.*, b.*, b.hispanic as hispanicyes,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_HISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_HISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='Hispanic' and Disease='Influenza, adult death' then hispanic_age_18GE
			when Demographic='Hispanic' and Disease='Influenza, pediatric death' then hispanic_age_0_17
			when Demographic='Non-Hispanic' and Disease='Influenza, adult death' then nonhispanic_age_18GE
			when Demographic='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhispanic_age_0_17
			when Demographic='Hispanic' then hispanicyes
			when Demographic='Non-Hispanic' then nonhispanic
		end as Population_County,
	'Ethnicity' as Demographic_Group
from rates_HISPANIC
order by Year desc, County_substr, Disease, Demographic;

/*%suppress_cases(rates_HISPANIC);*/
/*%secondary_suppress (rates_HISPANIC);*/

proc delete data=work.agg_HISPANIC work.agg_HISPANIC_state;
run;


/*Generate Race Summary*/

proc sql;
create table agg_Race as
select
	Year, County_substr, Disease, Disease_Group, Race as Demographic length=45,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic
order by Year, County_substr, Disease, Demographic;

proc sql;
create table agg_Race as
select a.*, b.Cases_County_Annual
from agg_Race a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_Race_state as
select
	Year, Disease, Demographic,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_Race
group by Year, Disease, Demographic
order by Year desc, Disease, Demographic;

proc sql;
create table agg_Race as
select a.*, b.*
from agg_Race a left join agg_Race_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic
order by Year desc, County_substr, Disease, Demographic;


proc sql;
create table rates_Race as
select a.*, b.*
from agg_Race a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_Race as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
		when Demographic='American Indian Alaskan Native' and Disease='Influenza, adult death' then ai_an_age_18GE
		when Demographic='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death' then asian_pi_age_18GE
		when Demographic='Black or African American' and Disease='Influenza, adult death' then black_age_18GE
		when Demographic='Multi-Race' and Disease='Influenza, adult death' then multi_race_age_18GE
		when Demographic='White' and Disease='Influenza, adult death' then white_age_18GE
		when Demographic='American Indian Alaskan Native' and Disease='Influenza, pediatric death' then ai_an_age_0_17
		when Demographic='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death' then asian_pi_age_0_17
		when Demographic='Black or African American' and Disease='Influenza, pediatric death' then black_age_0_17
		when Demographic='Multi-Race' and Disease='Influenza, pediatric death' then multi_race_age_0_17
		when Demographic='White' and Disease='Influenza, pediatric death' then white_age_0_17
		when Demographic='American Indian Alaskan Native' then ai_an
		when Demographic='Asian or Native Hawaiian or Pacific Islander' then asian_pi
		when Demographic='Black or African American' then black
		when Demographic='Multi-Race' then multi_race
		when Demographic='White' then white
		end as Population_State
from rates_Race;

proc sql;
create table rates_Race as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_Race a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_Race as
select
	Year, County_substr, Disease, Disease_Group, Demographic,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
		when Demographic='American Indian Alaskan Native' and Disease='Influenza, adult death' then ai_an_age_18GE
		when Demographic='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death' then asian_pi_age_18GE
		when Demographic='Black or African American' and Disease='Influenza, adult death' then black_age_18GE
		when Demographic='Multi-Race' and Disease='Influenza, adult death' then multi_race_age_18GE
		when Demographic='White' and Disease='Influenza, adult death' then white_age_18GE
		when Demographic='American Indian Alaskan Native' and Disease='Influenza, pediatric death' then ai_an_age_0_17
		when Demographic='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death' then asian_pi_age_0_17
		when Demographic='Black or African American' and Disease='Influenza, pediatric death' then black_age_0_17
		when Demographic='Multi-Race' and Disease='Influenza, pediatric death' then multi_race_age_0_17
		when Demographic='White' and Disease='Influenza, pediatric death' then white_age_0_17
		when Demographic='American Indian Alaskan Native' then ai_an
		when Demographic='Asian or Native Hawaiian or Pacific Islander' then asian_pi
		when Demographic='Black or African American' then black
		when Demographic='Multi-Race' then multi_race
		when Demographic='White' then white
		end as Population_County,
	'Race' as Demographic_Group
from rates_Race
order by Year desc, County_substr, Disease, Demographic;

/*%suppress_cases(rates_Race);*/
/*%secondary_suppress(rates_Race);*/

proc delete data=work.agg_Race work.agg_Race_state;
run;


/*Combine*/

/*proc sql;*/
/*create table demographic_simple as*/
/*select rates_AgeGroup.*, rates_GENDER.*, rates_HISPANIC.*, rates_Race.**/
/*from rates_AgeGroup a left join rates_GENDER b*/
/*	on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease and a.Demographic_Group=b.Demographic_Group*/
/*left join rates_HISPANIC c*/
/*	on a.Year=c.Year and a.County_substr=c.County_substr and a.Disease=c.Disease and a.Demographic_Group=c.Demographic_Group*/
/*left join rates_Race d*/
/*	on a.Year=d.Year and a.County_substr=d.County_substr and a.Disease=d.Disease and a.Demographic_Group=d.Demographic_Group*/
/*order by Year desc, County_substr, Disease, GENDER, AgeGroup, Race, HISPANIC;*/

data demographic_simple;
format Demographic $45.;
set rates_AgeGroup rates_GENDER rates_HISPANIC rates_Race;
run;


data demographic_simple;
set demographic_simple;
format County_Demo_Annual_Incidence 10.1;
County_Demo_Annual_Incidence=round(County_Demo_Annual_Cases/Population_County*100000, .1);
pop_lt500_suppressed=0;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other' and State_Annual_Incidence=. then do;
	pop_lt500_suppressed=County_Demo_Annual_Cases;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other' and County_Demo_Annual_Incidence=. then do;
	pop_lt500_suppressed=County_Demo_Annual_Cases;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
run;

proc sort data=demographic_simple;
  by Year County_substr Disease Population_County/* County_Annual_Cases_Sup*/;
run;

data SecondLowestPopTable(keep=Year County_substr Disease SecondLowestPop);
set demographic_simple;
SecondLowestPop=Demographic;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table demographic_simple as
select a.*, b.*
from demographic_simple a left join SecondLowestPopTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;


proc sql;
create table suppress_le500 as
select Year, County_substr, Disease,
	'Yes' as pop_lt500,
	sum(pop_lt500_suppressed) as suppressed_total
from demographic_simple
group by Year, County_substr, Disease
having suppressed_total>0;


proc sql;
create table demographic_simple as
select a.*, b.pop_lt500, b.suppressed_total
from demographic_simple a left join suppress_le500 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

data demographic_simple;
set demographic_simple;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
if Demographic NE 'Missing/Unknown' and Demographic NE 'Other' and Population_County=. then County_Annual_Cases_char='Suppressed';
if pop_lt500='Yes' and Demographic=SecondLowestPop then do;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
	else if pop_lt500='' then pop_lt500='No';
drop SecondLowestPop pop_lt500_suppressed;
run;

/* Suppress all demographics when cases for the county-year-disease are <=5 */
data demographic_simple;
set demographic_simple;
/*if 0 < Cases_County_Annual le 5 and Demographic ne 'Total Suppressed' and suppressed_total=. then suppressed_total=0;*/
/*if 0 < Cases_County_Annual le 5 and Demographic ne 'Total Suppressed' then do;*/
if 0 < Cases_County_Annual le 5 and suppressed_total=. then suppressed_total=0;
if 0 < Cases_County_Annual le 5 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	suppressed_total=suppressed_total+Cases_County_Annual;
	County_Annual_Cases_char='Suppressed';
	end;
run;

/*Add suppressed case totals*/
proc sql;
create table demo_suppress as
select Year, County_substr, Disease, Disease_Group, Cases_County_Annual, Demographic_Group, 
	'Total Suppressed' as Demographic, 
	max(suppressed_total) as County_Demo_Annual_Cases,
	put(calculated County_Demo_Annual_Cases, 10.) as County_Annual_Cases_char
from demographic_simple
where County_Annual_Cases_char='Suppressed'
group by Year, County_substr, Disease, Disease_Group, Cases_County_Annual, Demographic_Group;

data demographic_simple;
set demographic_simple demo_suppress;
run;
proc sort data=demographic_simple;
by Year County_substr Disease Demographic_Group Demographic;
run;

/*proc export data=demographic_simple*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\DemoSimple.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*run;*/



									/*Cross-tabs*/

/*Gender X Age*/

data agg_GENDERXAge;
length Demographic Demographic2 $45;
set demoInput;
Demographic=GENDER;
Demographic2=put(age, agegrp.);
run;
proc sql;
create table agg_GENDERXAge as
select Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from agg_GENDERXAge
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXAge as
select a.*, b.Cases_County_Annual
from agg_GENDERXAge a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_GENDERXAge_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_GENDERXAge
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXAge as
select a.*, b.*
from agg_GENDERXAge a left join agg_GENDERXAge_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_GENDERXAge as
select a.*, b.*
from agg_GENDERXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Female' and Demographic2='0-12' then female_0_12
			when Demographic='Female' and Demographic2='13-17' then female_13_17
			when Demographic='Female' and Demographic2='18-24' then female_18_24
			when Demographic='Female' and Demographic2='25-49' then female_25_49
			when Demographic='Female' and Demographic2='50-64' then female_50_64
			when Demographic='Female' and Demographic2='65+' then female_65GE
			when Demographic='Male' and Demographic2='0-12' then male_0_12
			when Demographic='Male' and Demographic2='13-17' then male_13_17
			when Demographic='Male' and Demographic2='18-24' then male_18_24
			when Demographic='Male' and Demographic2='25-49' then male_25_49
			when Demographic='Male' and Demographic2='50-64' then male_50_64
			when Demographic='Male' and Demographic2='65+' then male_65GE
		end as Population_State
from rates_GENDERXAge;

proc sql;
create table rates_GENDERXAge as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_GENDERXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='Female' and Demographic2='0-12' then female_0_12
			when Demographic='Female' and Demographic2='13-17' then female_13_17
			when Demographic='Female' and Demographic2='18-24' then female_18_24
			when Demographic='Female' and Demographic2='25-49' then female_25_49
			when Demographic='Female' and Demographic2='50-64' then female_50_64
			when Demographic='Female' and Demographic2='65+' then female_65GE
			when Demographic='Male' and Demographic2='0-12' then male_0_12
			when Demographic='Male' and Demographic2='13-17' then male_13_17
			when Demographic='Male' and Demographic2='18-24' then male_18_24
			when Demographic='Male' and Demographic2='25-49' then male_25_49
			when Demographic='Male' and Demographic2='50-64' then male_50_64
			when Demographic='Male' and Demographic2='65+' then male_65GE
		end as Population_County,
		'Gender by Age Group' as Demographic_Group
from rates_GENDERXAge
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_GENDERXAge);*/
/*%secondary_suppress_mult(rates_GENDERXAge);*/

proc delete data=work.agg_GENDERXAge work.agg_GENDERXAge_state;
run;

/*proc export data=rates_GENDERXAge*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\2-1-24_data_GENDERXAge.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Gender X Age";*/
/*run;*/


/*Gender X Race*/

proc sql;
create table agg_GENDERXRace as
select Year, County_substr, Disease, Disease_Group,
	GENDER as Demographic length=45, Race as Demographic2 length=45,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXRace as
select a.*, b.Cases_County_Annual
from agg_GENDERXRace a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_GENDERXRace_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_GENDERXRace
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXRace as
select a.*, b.*
from agg_GENDERXRace a left join agg_GENDERXRace_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_GENDERXRace as
select a.*, b.*
from agg_GENDERXRace a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXRace as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Female' and Demographic2='American Indian Alaskan Native'
				then female_ai_an
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander'
				then female_asian_pi
			when Demographic='Female' and Demographic2='Black or African American'
				then female_black
			when Demographic='Female' and Demographic2='Multi-Race'
				then female_multi_race
			when Demographic='Female' and Demographic2='White'
				then female_white

			when Demographic='Female' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, adult death'
				then female_ai_an_age_18GE
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death'
				then female_asian_pi_age_18GE
			when Demographic='Female' and Demographic2='Black or African American' and Disease='Influenza, adult death'
				then female_black_age_18GE
			when Demographic='Female' and Demographic2='Multi-Race' and Disease='Influenza, adult death'
				then female_multi_race_age_18GE
			when Demographic='Female' and Demographic2='White' and Disease='Influenza, adult death'
				then female_white_age_18GE
			when Demographic='Female' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, pediatric death'
				then female_ai_an_age_0_17
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death'
				then female_asian_pi_age_0_17
			when Demographic='Female' and Demographic2='Black or African American' and Disease='Influenza, pediatric death'
				then female_black_age_0_17
			when Demographic='Female' and Demographic2='Multi-Race' and Disease='Influenza, pediatric death'
				then female_multi_race_age_0_17
			when Demographic='Female' and Demographic2='White' and Disease='Influenza, pediatric death'
				then female_white_age_0_17

			when Demographic='Male' and Demographic2='American Indian Alaskan Native'
				then male_ai_an
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander'
				then male_asian_pi
			when Demographic='Male' and Demographic2='Black or African American'
				then male_black
			when Demographic='Male' and Demographic2='Multi-Race'
				then male_multi_race
			when Demographic='Male' and Demographic2='White'
				then male_white

			when Demographic='Male' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, adult death'
				then male_ai_an_age_18GE
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death'
				then male_asian_pi_age_18GE
			when Demographic='Male' and Demographic2='Black or African American' and Disease='Influenza, adult death'
				then male_black_age_18GE
			when Demographic='Male' and Demographic2='Multi-Race' and Disease='Influenza, adult death'
				then male_multi_race_age_18GE
			when Demographic='Male' and Demographic2='White' and Disease='Influenza, adult death'
				then male_white_age_18GE
			when Demographic='Male' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, pediatric death'
				then male_ai_an_age_0_17
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death'
				then male_asian_pi_age_0_17
			when Demographic='Male' and Demographic2='Black or African American' and Disease='Influenza, pediatric death'
				then male_black_age_0_17
			when Demographic='Male' and Demographic2='Multi-Race' and Disease='Influenza, pediatric death'
				then male_multi_race_age_0_17
			when Demographic='Male' and Demographic2='White' and Disease='Influenza, pediatric death'
				then male_white_age_0_17

		end as Population_State
from rates_GENDERXRace;

proc sql;
create table rates_GENDERXRace as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_GENDERXRace a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXRace as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Population_State,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases,
	case
			when Demographic='Female' and Demographic2='American Indian Alaskan Native'
				then female_ai_an
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander'
				then female_asian_pi
			when Demographic='Female' and Demographic2='Black or African American'
				then female_black
			when Demographic='Female' and Demographic2='Multi-Race'
				then female_multi_race
			when Demographic='Female' and Demographic2='White'
				then female_white
			when Demographic='Male' and Demographic2='American Indian Alaskan Native'
				then male_ai_an
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander'
				then male_asian_pi
			when Demographic='Male' and Demographic2='Black or African American'
				then male_black
			when Demographic='Male' and Demographic2='Multi-Race'
				then male_multi_race
			when Demographic='Male' and Demographic2='White'
				then male_white

			when Demographic='Female' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, adult death'
				then female_ai_an_age_18GE
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death'
				then female_asian_pi_age_18GE
			when Demographic='Female' and Demographic2='Black or African American' and Disease='Influenza, adult death'
				then female_black_age_18GE
			when Demographic='Female' and Demographic2='Multi-Race' and Disease='Influenza, adult death'
				then female_multi_race_age_18GE
			when Demographic='Female' and Demographic2='White' and Disease='Influenza, adult death'
				then female_white_age_18GE
			when Demographic='Male' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, adult death'
				then male_ai_an_age_18GE
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, adult death'
				then male_asian_pi_age_18GE
			when Demographic='Male' and Demographic2='Black or African American' and Disease='Influenza, adult death'
				then male_black_age_18GE
			when Demographic='Male' and Demographic2='Multi-Race' and Disease='Influenza, adult death'
				then male_multi_race_age_18GE
			when Demographic='Male' and Demographic2='White' and Disease='Influenza, adult death'
				then male_white_age_18GE

			when Demographic='Female' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, pediatric death'
				then female_ai_an_age_0_17
			when Demographic='Female' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death'
				then female_asian_pi_age_0_17
			when Demographic='Female' and Demographic2='Black or African American' and Disease='Influenza, pediatric death'
				then female_black_age_0_17
			when Demographic='Female' and Demographic2='Multi-Race' and Disease='Influenza, pediatric death'
				then female_multi_race_age_0_17
			when Demographic='Female' and Demographic2='White' and Disease='Influenza, pediatric death'
				then female_white_age_0_17
			when Demographic='Male' and Demographic2='American Indian Alaskan Native' and Disease='Influenza, pediatric death'
				then male_ai_an_age_0_17
			when Demographic='Male' and Demographic2='Asian or Native Hawaiian or Pacific Islander' and Disease='Influenza, pediatric death'
				then male_asian_pi_age_0_17
			when Demographic='Male' and Demographic2='Black or African American' and Disease='Influenza, pediatric death'
				then male_black_age_0_17
			when Demographic='Male' and Demographic2='Multi-Race' and Disease='Influenza, pediatric death'
				then male_multi_race_age_0_17
			when Demographic='Male' and Demographic2='White' and Disease='Influenza, pediatric death'
				then male_white_age_0_17

		end as Population_County,
		'Gender by Race' as Demographic_Group
from rates_GENDERXRace
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_GENDERXRace);*/
/*%secondary_suppress_mult (rates_GENDERXRace);*/

proc delete data=work.agg_GENDERXRace work.agg_GENDERXRace_state;
run;

/*Gender X HISPANIC*/

proc sql;
create table agg_GENDERXHISPANIC as
select Year, County_substr, Disease, Disease_Group,
	GENDER as Demographic, HISPANIC as Demographic2,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXHISPANIC as
select a.*, b.Cases_County_Annual
from agg_GENDERXHISPANIC a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_GENDERXHISPANIC_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_GENDERXHISPANIC
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_GENDERXHISPANIC as
select a.*, b.*
from agg_GENDERXHISPANIC a left join agg_GENDERXHISPANIC_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_GENDERXHISPANIC as
select a.*, b.*
from agg_GENDERXHISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXHISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Female' and Demographic2='Hispanic' then female_hisp
			when Demographic='Female' and Demographic2='Non-Hispanic' then female_nonhisp
			when Demographic='Male' and Demographic2='Hispanic' then male_hisp
			when Demographic='Male' and Demographic2='Non-Hispanic' then male_nonhisp

			when Demographic='Female' and Demographic2='Hispanic' and Disease='Influenza, adult death' then female_hisp_age_18GE
			when Demographic='Female' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then female_nonhisp_age_18GE
			when Demographic='Male' and Demographic2='Hispanic' and Disease='Influenza, adult death' then male_hisp_age_18GE
			when Demographic='Male' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then male_nonhisp_age_18GE

			when Demographic='Female' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then female_hisp_age_0_17
			when Demographic='Female' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then female_nonhisp_age_0_17
			when Demographic='Male' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then male_hisp_age_0_17
			when Demographic='Male' and Demographic2='non-Hispanic' and Disease='Influenza, pediatric death' then male_nonhisp_age_0_17

		end as Population_State
from rates_GENDERXHISPANIC;

proc sql;
create table rates_GENDERXHISPANIC as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_GENDERXHISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXHISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='Female' and Demographic2='Hispanic' then female_hisp
			when Demographic='Female' and Demographic2='Non-Hispanic' then female_nonhisp
			when Demographic='Male' and Demographic2='Hispanic' then male_hisp
			when Demographic='Male' and Demographic2='Non-Hispanic' then male_nonhisp

			when Demographic='Female' and Demographic2='Hispanic' and Disease='Influenza, adult death' then female_hisp_age_18GE
			when Demographic='Female' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then female_nonhisp_age_18GE
			when Demographic='Male' and Demographic2='Hispanic' and Disease='Influenza, adult death' then male_hisp_age_18GE
			when Demographic='Male' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then male_nonhisp_age_18GE

			when Demographic='Female' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then female_hisp_age_0_17
			when Demographic='Female' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then female_nonhisp_age_0_17
			when Demographic='Male' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then male_hisp_age_0_17
			when Demographic='Male' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then male_nonhisp_age_0_17

		end as Population_County,
		'Gender by Ethnicity' as Demographic_Group
from rates_GENDERXHISPANIC
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_GENDERXHISPANIC);*/
/*%secondary_suppress_mult(rates_GENDERXHISPANIC);*/

proc delete data=work.agg_GENDERXHISPANIC work.agg_GENDERXHISPANIC_state;
run;


/*Race X Age*/

data agg_RaceXAge;
length Demographic Demographic2 $45;
set demoInput;
	Demographic=Race;
	Demographic2=put(age, agegrp.);
run;
proc sql;
create table agg_RaceXAge as
select Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from agg_RaceXAge
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_RaceXAge as
select a.*, b.Cases_County_Annual
from agg_RaceXAge a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_RaceXAge_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_RaceXAge
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_RaceXAge as
select a.*, b.*
from agg_RaceXAge a left join agg_RaceXAge_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_RaceXAge as
select a.*, b.*
from agg_RaceXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_RaceXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='American Indian Alaskan Native' and Demographic2='0-12' then ai_an_0_12
			when Demographic='American Indian Alaskan Native' and Demographic2='13-17' then ai_an_13_17
			when Demographic='American Indian Alaskan Native' and Demographic2='18-24' then ai_an_18_24
			when Demographic='American Indian Alaskan Native' and Demographic2='25-49' then ai_an_25_49
			when Demographic='American Indian Alaskan Native' and Demographic2='50-64' then ai_an_50_64
			when Demographic='American Indian Alaskan Native' and Demographic2='65+' then ai_an_65GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='0-12' then asian_pi_0_12
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='13-17' then asian_pi_13_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='18-24' then asian_pi_18_24
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='25-49' then asian_pi_25_49
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='50-64' then asian_pi_50_64
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='65+' then ai_an_65GE
			when Demographic='Black or African American' and Demographic2='0-12' then black_0_12
			when Demographic='Black or African American' and Demographic2='13-17' then black_13_17
			when Demographic='Black or African American' and Demographic2='18-24' then black_18_24
			when Demographic='Black or African American' and Demographic2='25-49' then black_25_49
			when Demographic='Black or African American' and Demographic2='50-64' then black_50_64
			when Demographic='Black or African American' and Demographic2='65+' then black_65GE
			when Demographic='Multi-Race' and Demographic2='0-12' then multi_race_0_12
			when Demographic='Multi-Race' and Demographic2='13-17' then multi_race_13_17
			when Demographic='Multi-Race' and Demographic2='18-24' then multi_race_18_24
			when Demographic='Multi-Race' and Demographic2='25-49' then multi_race_25_49
			when Demographic='Multi-Race' and Demographic2='50-64' then multi_race_50_64
			when Demographic='Multi-Race' and Demographic2='65+' then multi_race_65GE
			when Demographic='White' and Demographic2='0-12' then white_0_12
			when Demographic='White' and Demographic2='13-17' then white_13_17
			when Demographic='White' and Demographic2='18-24' then white_18_24
			when Demographic='White' and Demographic2='25-49' then white_25_49
			when Demographic='White' and Demographic2='50-64' then white_50_64
			when Demographic='White' and Demographic2='65+' then white_65GE
		end as Population_State
from rates_RaceXAge;

proc sql;
create table rates_RaceXAge as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_RaceXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_RaceXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='American Indian Alaskan Native' and Demographic2='0-12' then ai_an_0_12
			when Demographic='American Indian Alaskan Native' and Demographic2='13-17' then ai_an_13_17
			when Demographic='American Indian Alaskan Native' and Demographic2='18-24' then ai_an_18_24
			when Demographic='American Indian Alaskan Native' and Demographic2='25-49' then ai_an_25_49
			when Demographic='American Indian Alaskan Native' and Demographic2='50-64' then ai_an_50_64
			when Demographic='American Indian Alaskan Native' and Demographic2='65+' then ai_an_65GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='0-12' then asian_pi_0_12
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='13-17' then asian_pi_13_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='18-24' then asian_pi_18_24
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='25-49' then asian_pi_25_49
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='50-64' then asian_pi_50_64
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='65+' then ai_an_65GE
			when Demographic='Black or African American' and Demographic2='0-12' then black_0_12
			when Demographic='Black or African American' and Demographic2='13-17' then black_13_17
			when Demographic='Black or African American' and Demographic2='18-24' then black_18_24
			when Demographic='Black or African American' and Demographic2='25-49' then black_25_49
			when Demographic='Black or African American' and Demographic2='50-64' then black_50_64
			when Demographic='Black or African American' and Demographic2='65+' then black_65GE
			when Demographic='Multi-Race' and Demographic2='0-12' then multi_race_0_12
			when Demographic='Multi-Race' and Demographic2='13-17' then multi_race_13_17
			when Demographic='Multi-Race' and Demographic2='18-24' then multi_race_18_24
			when Demographic='Multi-Race' and Demographic2='25-49' then multi_race_25_49
			when Demographic='Multi-Race' and Demographic2='50-64' then multi_race_50_64
			when Demographic='Multi-Race' and Demographic2='65+' then multi_race_65GE
			when Demographic='White' and Demographic2='0-12' then white_0_12
			when Demographic='White' and Demographic2='13-17' then white_13_17
			when Demographic='White' and Demographic2='18-24' then white_18_24
			when Demographic='White' and Demographic2='25-49' then white_25_49
			when Demographic='White' and Demographic2='50-64' then white_50_64
			when Demographic='White' and Demographic2='65+' then white_65GE
	end as Population_County,
	'Race by Age' as Demographic_Group
from rates_RaceXAge
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_RaceXAge);*/
/*%secondary_suppress_mult(rates_RaceXAge);*/

proc delete data=work.agg_RaceXAge work.agg_RaceXAge_state;
run;

/*proc export data=rates_RaceXAge*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Race X Age";*/
/*run;*/


/*Ethnicity X Age*/

data agg_HISPANICXAge;
length Demographic Demographic2 $45;
set demoInput;
	Demographic=HISPANIC;
	Demographic2=put(age, agegrp.);
run;
proc sql;
create table agg_HISPANICXAge as
select Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from agg_HISPANICXAge
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_HISPANICXAge as
select a.*, b.Cases_County_Annual
from agg_HISPANICXAge a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_HISPANICXAge_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_HISPANICXAge
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_HISPANICXAge as
select a.*, b.*
from agg_HISPANICXAge a left join agg_HISPANICXAge_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_HISPANICXAge as
select a.*, b.*
from agg_HISPANICXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_HISPANICXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='Hispanic' and Demographic2='0-12' then hisp_0_12
			when Demographic='Hispanic' and Demographic2='13-17' then hisp_13_17
			when Demographic='Hispanic' and Demographic2='18-24' then hisp_18_24
			when Demographic='Hispanic' and Demographic2='25-49' then hisp_25_49
			when Demographic='Hispanic' and Demographic2='50-64' then hisp_50_64
			when Demographic='Hispanic' and Demographic2='65+' then hisp_65GE
			when Demographic='Non-Hispanic' and Demographic2='0-12' then nonhisp_0_12
			when Demographic='Non-Hispanic' and Demographic2='13-17' then nonhisp_13_17
			when Demographic='Non-Hispanic' and Demographic2='18-24' then nonhisp_18_24
			when Demographic='Non-Hispanic' and Demographic2='25-49' then nonhisp_25_49
			when Demographic='Non-Hispanic' and Demographic2='50-64' then nonhisp_50_64
			when Demographic='Non-Hispanic' and Demographic2='65+' then nonhisp_65GE
		end as Population_State
from rates_HISPANICXAge;

proc sql;
create table rates_HISPANICXAge as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_HISPANICXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_HISPANICXAge as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='Hispanic' and Demographic2='0-12' then hisp_0_12
			when Demographic='Hispanic' and Demographic2='13-17' then hisp_13_17
			when Demographic='Hispanic' and Demographic2='18-24' then hisp_18_24
			when Demographic='Hispanic' and Demographic2='25-49' then hisp_25_49
			when Demographic='Hispanic' and Demographic2='50-64' then hisp_50_64
			when Demographic='Hispanic' and Demographic2='65+' then hisp_65GE
			when Demographic='Non-Hispanic' and Demographic2='0-12' then nonhisp_0_12
			when Demographic='Non-Hispanic' and Demographic2='13-17' then nonhisp_13_17
			when Demographic='Non-Hispanic' and Demographic2='18-24' then nonhisp_18_24
			when Demographic='Non-Hispanic' and Demographic2='25-49' then nonhisp_25_49
			when Demographic='Non-Hispanic' and Demographic2='50-64' then nonhisp_50_64
			when Demographic='Non-Hispanic' and Demographic2='65+' then nonhisp_65GE
	end as Population_County,
	'Ethnicity by Age Group' as Demographic_Group
from rates_HISPANICXAge
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_HISPANICXAge);*/
/*%secondary_suppress_mult (rates_HISPANICXAge);*/

proc delete data=work.agg_HISPANICXAge work.agg_HISPANICXAge_state;
run;


/*Race X Ethnicity*/

proc sql;
create table agg_RaceXHISPANIC as
select Year, County_substr, Disease, Disease_Group,
	Race as Demographic format=$45., HISPANIC as Demographic2 format=$45.,
	count(distinct CASE_ID) as County_Demo_Annual_Cases
from demoInput
group by Year, County_substr, Disease, Disease_Group, Demographic, Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;

proc sql;
create table agg_RaceXHISPANIC as
select a.*, b.Cases_County_Annual
from agg_RaceXHISPANIC a left join agg_annual b
	on a.Year=b.year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table agg_RaceXHISPANIC_state as
select
	Year, Disease, Demographic, Demographic2,
	sum(County_Demo_Annual_Cases) as State_Annual_Cases
from agg_RaceXHISPANIC
group by Year, Disease, Demographic, Demographic2
order by Year desc, Disease, Demographic, Demographic2;

proc sql;
create table agg_RaceXHISPANIC as
select a.*, b.*
from agg_RaceXHISPANIC a left join agg_RaceXHISPANIC_state b
	on a.Year=b.year and a.Disease=b.Disease and a.Demographic=b.Demographic and a.Demographic2=b.Demographic2
order by Year desc, County_substr, Disease, Demographic, Demographic2;


proc sql;
create table rates_RaceXHISPANIC as
select a.*, b.*
from agg_RaceXHISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_RaceXHISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2, Cases_County_Annual, County_Demo_Annual_Cases, State_Annual_Cases,
	case
			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' then hisp_ai_an
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' then nonhisp_ai_an
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' then hisp_asian_pi
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' then nonhisp_asian_pi
			when Demographic='Black or African American' and Demographic2='Hispanic' then hisp_black
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' then nonhisp_black
			when Demographic='Multi-Race' and Demographic2='Hispanic' then hisp_multi_race
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' then nonhisp_multi_race
			when Demographic='White' and Demographic2='Hispanic' then hisp_white
			when Demographic='White' and Demographic2='Non-Hispanic' then nonhisp_white

			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_ai_an_age_18GE
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_ai_an_age_18GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_asian_pi_age_18GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_asian_pi_age_18GE
			when Demographic='Black or African American' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_black_age_18GE
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_black_age_18GE
			when Demographic='Multi-Race' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_multi_race_age_18GE
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_multi_race_age_18GE
			when Demographic='White' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_white_age_18GE
			when Demographic='White' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_white_age_18GE

			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_ai_an_age_0_17
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_ai_an_age_0_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_asian_pi_age_0_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_asian_pi_age_0_17
			when Demographic='Black or African American' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_black_age_0_17
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_black_age_0_17
			when Demographic='Multi-Race' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_multi_race_age_0_17
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_multi_race_age_0_17
			when Demographic='White' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_white_age_0_17
			when Demographic='White' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_white_age_0_17

		end as Population_State
from rates_RaceXHISPANIC;

proc sql;
create table rates_RaceXHISPANIC as
select a.*, b.*,
State_Annual_Cases/Population_State*100000 as State_Annual_Incidence format=10.1
from rates_RaceXHISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_RaceXHISPANIC as
select
	Year, County_substr, Disease, Disease_Group, Demographic, Demographic2,
	State_Annual_Cases, State_Annual_Incidence, Cases_County_Annual, County_Demo_Annual_Cases, Population_State,
	case
			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' then hisp_ai_an
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' then nonhisp_ai_an
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' then hisp_asian_pi
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' then nonhisp_asian_pi
			when Demographic='Black or African American' and Demographic2='Hispanic' then hisp_black
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' then nonhisp_black
			when Demographic='Multi-Race' and Demographic2='Hispanic' then hisp_multi_race
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' then nonhisp_multi_race
			when Demographic='White' and Demographic2='Hispanic' then hisp_white
			when Demographic='White' and Demographic2='Non-Hispanic' then nonhisp_white

			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_ai_an_age_18GE
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_ai_an_age_18GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_asian_pi_age_18GE
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_asian_pi_age_18GE
			when Demographic='Black or African American' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_black_age_18GE
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_black_age_18GE
			when Demographic='Multi-Race' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_multi_race_age_18GE
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_multi_race_age_18GE
			when Demographic='White' and Demographic2='Hispanic' and Disease='Influenza, adult death' then hisp_white_age_18GE
			when Demographic='White' and Demographic2='Non-Hispanic' and Disease='Influenza, adult death' then nonhisp_white_age_18GE

			when Demographic='American Indian Alaskan Native' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_ai_an_age_0_17
			when Demographic='American Indian Alaskan Native' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_ai_an_age_0_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_asian_pi_age_0_17
			when Demographic='Asian or Native Hawaiian or Pacific Islander' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_asian_pi_age_0_17
			when Demographic='Black or African American' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_black_age_0_17
			when Demographic='Black or African American' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_black_age_0_17
			when Demographic='Multi-Race' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_multi_race_age_0_17
			when Demographic='Multi-Race' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_multi_race_age_0_17
			when Demographic='White' and Demographic2='Hispanic' and Disease='Influenza, pediatric death' then hisp_white_age_0_17
			when Demographic='White' and Demographic2='Non-Hispanic' and Disease='Influenza, pediatric death' then nonhisp_white_age_0_17

	end as Population_County,
	'Race by Ethnicity' as Demographic_Group
from rates_RaceXHISPANIC
order by Year desc, County_substr, Disease, Demographic, Demographic2;

/*%suppress_cases_mult(rates_RaceXHISPANIC);*/
/*%secondary_suppress_mult (rates_RaceXHISPANIC);*/

proc delete data=work.agg_RaceXHISPANIC work.agg_RaceXHISPANIC_state;
run;



								/*Combine Demographic Cross-tabs Tables*/
data demographic_multiple;
format Demographic Demographic2 Demographic_Group $45.;
set rates_GENDERXAge rates_GENDERXRace rates_GENDERXHISPANIC rates_RaceXAge rates_HISPANICXAge rates_RaceXHISPANIC;
run;


/*If no data, ''; N and IR not shown.
  If response is present in NC EDSS but not represented in the population file, ''; N shown, IR not shown.
  If data are present in both files but suppressed due to population denominator, '0'; N and IR are shown as '0';
	next-lowest subcategory is also shown as '0'.*/

data demographic_multiple;
set demographic_multiple;
format County_Demo_Annual_Incidence 10.1;
County_Demo_Annual_Incidence=round(County_Demo_Annual_Cases/Population_County*100000, .1);
pop_lt500_suppressed=0;
County_Annual_Cases_char=put(County_Demo_Annual_Cases, 10.);
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other'
	and Demographic2 NE 'Missing/Unknown' and Demographic2 NE '' and Demographic2 NE 'Other' and State_Annual_Incidence=. then do;
		pop_lt500_suppressed=County_Demo_Annual_Cases;
		County_Demo_Annual_Cases=0;
		County_Annual_Cases_char='Suppressed';
		end;
if Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other'
	and Demographic2 NE 'Missing/Unknown' and Demographic2 NE '' and Demographic2 NE 'Other' and County_Demo_Annual_Incidence=. then do;
		pop_lt500_suppressed=County_Demo_Annual_Cases;
		County_Demo_Annual_Cases=0;
		County_Annual_Cases_char='Suppressed';
		end;
run;

proc sort data=demographic_multiple;
  by Year County_substr Disease Population_County/* County_Annual_Cases_Sup*/;
run;

data SecondLowestPopTable(keep=Year County_substr Disease SecondLowestPop SecondLowestPop2);
set demographic_multiple;
SecondLowestPop=Demographic;
SecondLowestPop2=Demographic2;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table demographic_multiple as
select a.*, b.*
from demographic_multiple a left join SecondLowestPopTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;


proc sql;
create table suppress_le500 as
select Year, County_substr, Disease,
	'Yes' as pop_lt500,
	sum(pop_lt500_suppressed) as suppressed_total
from demographic_multiple
group by Year, County_substr, Disease
having suppressed_total>0;


proc sql;
create table demographic_multiple as
select a.*, b.*
from demographic_multiple a left join suppress_le500 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

data demographic_multiple;
set demographic_multiple;
if pop_lt500='Yes' and Demographic=SecondLowestPop and Demographic2=SecondLowestPop2 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
	else if pop_lt500='' then pop_lt500='No';
drop SecondLowestPop SecondLowestPop2 pop_lt500_suppressed;
run;


/*If cases <= 5 for year-county-disease-demographic, then suppress those cases, 
	and also suppress second lowest case aggregate if not already included;
	total cases suppressed are added to 'Suppressed' subgroup*/
proc sort data=demographic_multiple;
  by Year County_substr Disease County_Demo_Annual_Cases;
run;

data SecondLowestCasesTable(keep=Year County_substr Disease SecondLowestCases SecondLowestCaseDemo1 SecondLowestCaseDemo2);
set demographic_multiple;
where County_Demo_Annual_Cases ne 0;
SecondLowestCases=County_Demo_Annual_Cases;
SecondLowestCaseDemo1=Demographic;
SecondLowestCaseDemo2=Demographic2;
by Year County_substr Disease;
if first.Disease then Marker=0;
  Marker+1;
if Marker = 2;
drop Marker;
run;

proc sql;
create table demographic_multiple as
select a.*, b.*
from demographic_multiple a left join SecondLowestCasesTable b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease;

proc sql;
create table county_demo_le5 as
select Year, County_substr, Disease, Demographic_Group,
	sum(County_Demo_Annual_Cases) as demo_cases_le5_count,
	case when min(County_Demo_Annual_Cases) le 5 then 'Yes' else 'No'
	end as demo_cases_le5
from demographic_multiple
where 0 < County_Demo_Annual_Cases le 5 and Demographic ne ''
/*where 0 < County_Demo_Annual_Cases le 5 and Demographic NE 'Missing/Unknown' and Demographic NE '' and Demographic NE 'Other'*/
/*	and Demographic2 NE 'Missing/Unknown' and Demographic2 NE '' and Demographic2 NE 'Other'*/
group by Year, County_substr, Disease, Demographic_Group;

proc sql;
create table demographic_multiple as
select a.*, b.demo_cases_le5_count, b.demo_cases_le5
from demographic_multiple a left join county_demo_le5 b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease and a.Demographic_Group=b.Demographic_Group;


data demographic_multiple(drop=SecondLowestCases SecondLowestCaseDemo1 SecondLowestCaseDemo2 demo_cases_le5 demo_cases_le5_count);
set demographic_multiple;
/*if demo_cases_le5='Yes' and suppressed_total=. then suppressed_total=0;*/
if County_Demo_Annual_Cases le 5 and suppressed_total=. then suppressed_total=0;
if demo_cases_le5='Yes' then suppressed_total=suppressed_total+demo_cases_le5_count+SecondLowestCases;
/*if County_Demo_Annual_Cases le 5 then */
if 0 < County_Demo_Annual_Cases le 5 then do;
/*	suppressed_total=suppressed_total+County_Demo_Annual_Cases+SecondLowestCases;*/
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
if demo_cases_le5='Yes' and Demographic=SecondLowestCaseDemo1 and Demographic2=SecondLowestCaseDemo2 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	County_Annual_Cases_char='Suppressed';
	end;
run;


/* Suppress all demographics when cases for the county-year-disease are <=5 */
data demographic_multiple;
set demographic_multiple;
if 0 < Cases_County_Annual le 5 and suppressed_total=. then suppressed_total=0;
if 0 < Cases_County_Annual le 5 then do;
	County_Demo_Annual_Cases=0;
	County_Demo_Annual_Incidence=.;
	suppressed_total=suppressed_total+Cases_County_Annual;
	County_Annual_Cases_char='Suppressed';
	end;
run;

/*Add suppressed case totals*/
proc sql;
create table demo_suppress as
select Year, County_substr, Disease, Disease_Group, Cases_County_Annual, Demographic_Group, 
	'Total Suppressed' as Demographic, 'Total Suppressed' as Demographic2,
	max(suppressed_total) as County_Demo_Annual_Cases,
	put(calculated County_Demo_Annual_Cases, 10.) as County_Annual_Cases_char
from demographic_multiple
where County_Annual_Cases_char='Suppressed'
group by Year, County_substr, Disease, Disease_Group, Cases_County_Annual, Demographic_Group;

data demographic_multiple;
set demographic_multiple demo_suppress;
run;
proc sort data=demographic_multiple;
by Year County_substr Disease Demographic_Group Demographic;
run;


/*proc export data=demographic_multiple*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics_multiple.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Demographic CD";*/
/*run;*/


/*Remove IR for infant populations*/
data demographic_all;
format Demographic Demographic2 Demographic_Group $45.;
set demographic_simple demographic_multiple;
County_Demo_Annual_Incidence=round(County_Demo_Annual_Incidence, .1);
State_Annual_Incidence=round(State_Annual_Incidence, .1);
if Disease='Botulism - infant' or Disease='Hepatitis B - Perinatally Acquired' or Disease='Syphilis - Congenital Syphilis' then do;
	County_Demo_Annual_Incidence=.;
	State_Annual_Incidence=.;
	end;
run;

/*If only one bar is shown in figure for year-county-disease-demographic,
	then suppress number of cases and number suppressed for that demographic*/
/*Suppress number of cases when only one bar is shown in figure*/
proc sql;
create table count_bars_shown as
select Year, County_substr, Disease, Demographic_Group,
	count(Demographic) as n_bars_shown/*,
	max(suppressed_total) as suppressed_total*/
from demographic_all
where Demographic ne 'Total Suppressed' and Demographic2 ne 'Total Suppressed'
group by Year, County_substr, Disease, Demographic_Group;

proc sql;
create table demographic_all as
select a.*, b.n_bars_shown
from demographic_all a left join count_bars_shown b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease and a.Demographic_Group=b.Demographic_Group;

data demographic_all(drop=n_bars_shown pop_lt500);
set demographic_all;
if /*pop_lt500='Yes' and*/ n_bars_shown=1 and (Demographic='Total Suppressed' or Demographic2='Total Suppressed') then do;
	County_Demo_Annual_Cases=0;
/*	County_Demo_Annual_Incidence=.;*/
	County_Annual_Cases_char='Suppressed';
	end;
run;


/*If suppressed total = number of bars shown in figure for year-county-disease-demographic,
	then remove total number suppressed for that demographic*/
proc sql;
create table count_bars_suppressed as
select Year, County_substr, Disease, Demographic_Group,
	count(Demographic) as n_bars_suppressed
from demographic_all
where County_Annual_Cases_char='Suppressed'
group by Year, County_substr, Disease, Demographic_Group;

proc sql;
create table demographic_all as
select a.*, b.n_bars_suppressed
from demographic_all a left join count_bars_suppressed b
		on a.Year=b.Year and a.County_substr=b.County_substr and a.Disease=b.Disease and a.Demographic_Group=b.Demographic_Group;

data demographic_all(drop=n_bars_suppressed);
set demographic_all;
if (Demographic='Total Suppressed' or Demographic2='Total Suppressed')
		and put(n_bars_suppressed, 3.)=County_Annual_Cases_char then do;
	County_Demo_Annual_Cases=0;
	County_Annual_Cases_char='Suppressed';
	end;
run;


/*Add 'All Counties' option to Counties dropdown*/
proc sort data=demographic_all out=AllCounties
	(drop=County_substr Cases_County_Annual County_Demo_Annual_Cases County_Demo_Annual_Incidence
		Population_County County_Annual_Cases_char) nodupkey ;
by Year Disease Demographic_Group Demographic;
run;
data AllCounties;
set AllCounties;
County_substr='All Counties';
County_Demo_Annual_Cases=State_Annual_Cases;
/*County_Annual_Cases_Sup=0;*/
Population_County=Population_State;
County_Annual_Cases_char=put(State_Annual_Cases, 10.);
run;

data demographic_all;
set demographic_all AllCounties;
run;

proc sort data=demographic_all;
by Year County_substr Disease Demographic_Group Demographic;
run;



/*libname interim 'T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\Interim';*/
/*data interim.demographic_all; */
/*set demographic_all;*/
/*run;*/

/*proc export data=demographic_all*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="CD - Demographics";*/
/*run;*/





/*Save SAS environment*/

/*Caution: This libref should never point to a storage location containing any other data,
because prior to storing the SAS WORK datasets and catalogs,
SAS will delete all of the contents of this library.*/

/*options presenv; */
/*libname bkuploc 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20240401data';*/
/*filename restore 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20240401data\restoration_pgm.sas';*/
/*proc presenv*/
/* permdir=bkuploc*/
/* sascode=restore*/
/* show_comments;*/
/* run; */


/*THE FOLLOWING LEGACY CODE NOT IN CURRENT USE*/

data all_diseases;
set final /*case_agg*/ ;
run;

/*proc freq data= all_diseases;*/
/*tables Disease*mmwr_year/missing;*/
/*tables OWNING_JD/missing;*/
/*where Disease='HIV Disease' and mmwr_year='2020';*/
/*run;*/
/**/
/*QA*/
/**/
/**/
/*Create List of Diseases (if needed - not required for YTD reporting; used in NCD3 2.0)*/

/*1*/
/*proc sql;*/
/*	create table diseases as*/
/*	select distinct Disease*/
/*	from all_diseases*/
/*	order by Disease;*/
/*quit;*/

/*/*2 proc freq data = all_diseases; tables Disease; run;*/
/*/*3 proc contents data = all_diseases; run;*/


/*Add Metadata to Summary Table (if needed - not required for YTD reporting; used in NCD3 2.0)*/

proc sql;
create table ncd3output as
select a.*, 
	b.TYPE_DESC_clean,
	b.Disease,
	b.Nickname,
	b.Disease_Group,
	b._Incidence_Calculation,
	b.Case_Table_Variable,
	b.Counted_By,
	b.Number_of_Days_to_Report
from final a
left join dgrps b
on a.Disease=b.Disease
having MMWR_YEAR NE ''
order by b.Disease_Group, b.disease, a.OWNING_JD, a.MMWR_YEAR;

/* Join final output to be stratified by NCALHD Region*/
proc sql;
create table ncd3outputreg as
select a.*, 
	b.*
from ncd3output a
join regions b
on a.OWNING_JD=b.county
having MMWR_YEAR NE ''
order by b.county, a.OWNING_JD, a.MMWR_YEAR;


/*Check to see that metadata is associated with each disease*/
create table nodisease as
select distinct Disease
from ncd3output
where Disease='';
quit;

/* Export file to T: Drive; remember to update date to reflect date program is run*/

/*proc export data=ncd3outputreg*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\032723NCD3_OUTPUT.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="NCD3 2.0 COUNTS";*/
/*run;*/
/*quit;*/
