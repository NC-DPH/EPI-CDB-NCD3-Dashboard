																/*LAST MODIFIED DATE: 3-13-24*/
													/*LAST MODIFIED BY: LINDA YELTON (LWY) linda.yelton@dhhs.nc.gov*/
/*Purpose: Script in progres to create the Data Source for the North Carolina Disease Data Dashboard (NCD3) next update*/
/*	Internal server: https://internaldashboards.ncdhhs.gov/#/site/DPH/projects/400*/
/*	External server: https://dashboards.ncdhhs.gov/#/site/DPH/projects/158*/
/*	Internal server workbook names:*/
/*		NCD3 v2 2024 Jan Update*/
/*		NCD3 Updated Quarterly Dashboard*/
/*		NCD3 Dashboard with Demographics*/


/*Must have access to NCEDSS_SAS(Z:) - CBD denorm server to run this program*/
libname denorm 'Z:\20240301'; /*This can be updated as needed to produce most recent counts; M. Hilton provides a new extract monthly*/
options compress=yes;
options nofmterr;

/*%let EndDate = '01DEC2023'd*/

/* Must have access to CD Users Shared (T:) to access these */
/* files to be used later in program */

/* TB */
libname tb 'T:\Tableau\SAS folders\SAS datasets\TB Program Data 2005 - 2022'; /*this will need to be refreshed as newer years of counts are needed*/

/* HIV */
proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\HIV AIDS 2015-2023 by quarter_through Q4.xlsx' out=HIV dbms=xlsx replace; run;

/* Annual and Quarterly County population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\County Census Pop_10_22.xlsx'
out=county_pops dbms=xlsx replace; run;
/* Demographic County population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\NCD3 Demo Dashboard\County Census Pop_10_22.xlsx'
out=demo_county_pops dbms=xlsx replace; run;

/* Annual and Quarterly State population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\State Census Pop_10_22.xlsx'
out=state_pops dbms=xlsx replace; run;
/* Demographic State population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\NCD3 Demo Dashboard\State Census Pop_10_22.xlsx'
out=demo_state_pops dbms=xlsx replace; run;

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

/*proc sql;*/
/*create table enteric as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', */
/*	symptom_onset_date, DATE_FOR_REPORTING,*/
/*	CALCULATED SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Enteric' as Disease_Group,*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE CALCULATED SYMPTOM_YEAR*/
/*	and CLASSIFICATION_CLASSIFICATION in ("Suspect", "Confirmed", "Probable")*/
/*	and TYPE in ("BOT", "BOTI", "CAMP", "CRYPT", "CYCLO", "ECOLI", */
/*	"FBOTHER", "CPERF", "FBPOIS", "STAPH", "HUS", "LIST", "SAL",*/
/*	"SHIG", "TRICH", "TYPHOID", "TYPHCAR", "VIBOTHER", "VIBVUL")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, CALCULATED SYMPTOM_YEAR, OWNING_JD;*/
/*quit;*/


/*The variable name for “Date of initial report to public health” in the DD tables is called “RPTI_SOURCE_DT_SUBMITTED”.*/
/*It is found in the “Admin_question_package_addl” table.*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Enteric' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;



																				/*HAI*/

/*proc sql;*/
/*create table HAI1 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', */
/*	symptom_onset_date, DATE_FOR_REPORTING,*/
/*	input(mmwr_year, 4.) as Year label='Year',*/
/*	QTR(MMWR_DATE_BASIS) as Quarter,*/
/*	'MMWR Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where mmwr_year in ('2015', '2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023')*/
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("CAURIS", "CRE", "SAUR", "TSS", "TSSS")*/
/*"STRA"*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, MMWR_Year, OWNING_JD;*/
/*quit;*/
/**/
/*proc sql;*/
/*create table HAI2 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',*/
/*	symptom_onset_date, DATE_FOR_REPORTING,*/
/*	CALCULATED SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE CALCULATED SYMPTOM_YEAR */
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE = ("STRA")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, calculated symptom_year, OWNING_JD;*/
/*quit;*/
/**/
/*Combine all HAI data sets*/
/*data HAI3;*/
/*length Reporting_Date_Type $25;*/
/*set HAI1 HAI2;*/
/*Disease_Group='Healthcare Acquired Infection';*/
/*run;*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Healthcare Acquired Infection' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;




															/*Hep Table 1 - MMWR_YEAR*/
/*proc sql;*/
/*create table hep1 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	input(mmwr_year, 4.) as MMWR_YEAR,  MMWR_DATE_BASIS, symptom_onset_date, deduplication_date, DATE_FOR_REPORTING,*/
/*	input(mmwr_year, 4.) as Year label='Year',*/
/*	QTR(MMWR_DATE_BASIS) as Quarter,*/
/*	'MMWR Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where mmwr_year in ('2015', '2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023')*/
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("HEPB_C", "HEPB_P")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, MMWR_Year, OWNING_JD;*/
/*quit;*/

															/*HEP TABLE 2 - SYMPTOM_YEAR*/
/*proc sql;*/
/*create table hep2 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, REPORT_TO_CDC,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',*/
/*	DATE_FOR_REPORTING, symptom_onset_date, deduplication_date,*/
/*	CALCULATED SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE CALCULATED SYMPTOM_YEAR */
/*where calculated SYMPTOM_YEAR GE 2022*/ 
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("HEPA", "HEPB_A", "HEPC", "HEPB_U")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*and status = 'closed'*/
/*order by TYPE_DESC, SYMPTOM_YEAR, OWNING_JD;*/
/*quit;*/

															/*HEP TABLE 3 - DEDUP_YEAR*/
/*proc sql;*/
/*create table hep3 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, */
/*	YEAR(DEDUPLICATION_DATE) as DEDUP_YEAR label= 'Year of DEDUP',*/
/*	REPORT_TO_CDC, symptom_onset_date, DATE_FOR_REPORTING,*/
/*	CALCULATED DEDUP_YEAR as Year label='Year',*/
/*	QTR(DEDUPLICATION_DATE) as Quarter,*/
/*	'Deduplication Date' as Reporting_Date_Type,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE CALCULATED DEDUP_YEAR */
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("HEPCC")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, dedup_YEAR, OWNING_JD;*/
/*quit;*/

/*Combine all hep data sets*/
/*data hep4;*/
/*length Reporting_Date_Type $25;*/
/*set hep1 hep2 hep3;*/
/*Disease_Group='Hepatitis';*/
/*run;*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
		left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("HEPB_C", "HEPB_P", "HEPA", "HEPB_A", "HEPC", "HEPB_U", "HEPCC")
	and s.REPORT_TO_CDC = 'Yes';
quit;

proc sql;
create table Hep as
	select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Hepatitis' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;


																	/*RESPIRATORY 1*/
/*proc sql;*/
/*create table RESP1 as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', */
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date,*/
/*	CALCULATED SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	'Respiratory' as Disease_Group,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE CALCULATED SYMPTOM_YEAR */
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("FLU", "FLUD", "FLUDA", "LEG")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, SYMPTOM_YEAR, OWNING_JD;*/
/*quit;*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Respiratory' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;


																/*RESPIRATORY 2 - TB*/
proc sql;
create table tb as
select
	Year,
	Year as MMWR_YEAR format 4., 
	propcase(county) as OWNING_JD label='County' format=$30. length=30, 
	'TB' as TYPE_DESC,
	COUNT as Case_Ct label = 'Counts',
/*	COUNT as Confirmed label='Confirmed Count',*/
/*	. as Probable label='Probable Count',*/
	COUNT as Cases_County_Annual label='Cases_County_Annual'
from tb.tb_cty_cts_2005_2022
where 2015 LE year
order by mmwr_year;

data tb;
set tb;
Reporting_Date_Type='MMWR Year';
Disease_Group='Tuberculosis';
run;



																	/*SEXUALLY TRANSMITTED*/

/*CHLAMYDIA & GONORRHEA = Deduplication Date*/

proc sql;
create table cg as
select OWNING_JD, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,
	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, symptom_onset_date, 
	year(DEDUPLICATION_DATE) AS DEDUP_YEAR LABEL = 'YEAR OF DEDUPLICATION',
	DEDUPLICATION_DATE, DATE_FOR_REPORTING,
	CALCULATED DEDUP_YEAR as Year label='Year',
	QTR(DEDUPLICATION_DATE) as Quarter,
	'Deduplication Date' as Reporting_Date_Type,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
where 2015 LE CALCULATED DEDUP_YEAR 
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
	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DEDUPLICATION_DATE, DATE_FOR_REPORTING,
	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date,
	CALCULATED SYMPTOM_YEAR as Year label='Year',
	QTR(symptom_onset_date) as Quarter,
	'Symptom Onset Date' as Reporting_Date_Type,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR
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
	'LHD Diagnosis Date' as Reporting_Date_Type,
	year(LHD_DIAGNOSIS_DATE) AS LHD_DX_YR LABEL = 'LHD DX YEAR', LHD_DIAGNOSIS_DATE, DATE_FOR_REPORTING,
	CALCULATED LHD_DX_YR as Year label='Year',
	QTR(LHD_DIAGNOSIS_DATE) as Quarter,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
where 2015 LE CALCULATED LHD_DX_YR
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
	'Birth Date' as Reporting_Date_Type,
	YEAR(BIRTH_DATE) as DOB label = 'YEAR OF BIRTH', LHD_DIAGNOSIS_DATE, DATE_FOR_REPORTING,
	CALCULATED DOB as Year label='Year',
	QTR(BIRTH_DATE) as Quarter,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6
from denorm.case
where 2015 LE CALCULATED DOB
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


/*HIV/AIDS; File provided by Jason Maxwell on 3/12/24, analyst for HIV/STD program; jason.maxwell@dhhs.nc.gov*/

/*HIV*/
proc sql;
create table hiv1 as
select *,
	"HIV" as TYPE_DESC,
/*	Cases as Confirmed_Quarterly label='Confirmed Count Quarterly',*/
/*	. as Probable_Quarterly label='Probable Count Quarterly',*/
	Qtr as Quarter label='Quarter',
	Cases as Cases_County_Quarterly label='Cases_County_Quarterly'
from HIV;
/*proc transpose data=hiv1 out=hiv1(drop=_name_ rename=(col1=Counts));*/
/*by TYPE_DESC OWNING_JD;*/
/*run;*/

proc sql;
create table hiv1 as
select *,
	sum(Cases_County_Quarterly) as Cases_County_Annual
from hiv1
group by Year, County
order by Year desc, County, Quarter;


data hiv1;
length TYPE_DESC $4;
set hiv1;
Reporting_Date_Type='Earliest Diagnosis Date';
Disease_Group='Sexually Transmitted';
County_substr = propcase(County);
Disease = 'HIV';
run;

proc iml;
edit hiv1;
read all var {County_substr} where(County_substr="Mcdowell");
County_substr = "McDowell";
replace all var {County_substr} where(County_substr="Mcdowell");
close hiv1;


																/*VPD*/
/*proc sql;*/
/*create table VPD as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label='Year of Onset', symptom_onset_date, DATE_FOR_REPORTING,*/
/*	calculated SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Vaccine Preventable' as Disease_Group,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE calculated SYMPTOM_YEAR */
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("DIP", "HFLU", "MEAS", "MENP", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "AFM", "RUB", "RUBCONG", "TET", "VAC", "VARICELLA")*/
/*	and REPORT_TO_CDC = 'Yes'*/
/*order by TYPE_DESC, OWNING_JD, SYMPTOM_YEAR;*/
/*quit;*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Vaccine Preventable' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . then SYMPTOM_ONSET_DATE
	    when SYMPTOM_ONSET_DATE = . and RPTI_SOURCE_DT_SUBMITTED ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;


																/*ZOONOTIC*/

/*proc sql;*/
/*create table zoo as*/
/*select OWNING_JD, TYPE, TYPE_DESC, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*	COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',*/
/*	input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,*/
/*	'Symptom Onset Date' as Reporting_Date_Type,*/
/*	YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date, DATE_FOR_REPORTING,*/
/*	calculated SYMPTOM_YEAR as Year label='Year',*/
/*	QTR(symptom_onset_date) as Quarter,*/
/*	'Vector-Borne/Zoonotic' as Disease_Group,*/
/*	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6*/
/*from denorm.case*/
/*where 2015 LE calculated SYMPTOM_YEAR */
/*	and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") */
/*	and TYPE in ("ANTH", "ARB", "BRU", "CHIKV", "CJD", "DENGUE", "EHR", "HGE", "EEE", "HME", */
/*	"LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", */
/*	"YF", "ZIKA", "VHF")*/
/*	and REPORT_TO_CDC = 'Yes' */
/*order by TYPE_DESC, SYMPTOM_YEAR, MMWR_Year, OWNING_JD;*/
/*quit;*/

proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
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
	input(MMWR_YEAR, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
	count(distinct CASE_ID) as Case_Ct label = 'Counts', 
	'Vector-Borne/Zoonotic' as Disease_Group,
	AGE, GENDER, HISPANIC, RACE1, RACE2, RACE3, RACE4, RACE5, RACE6,
	case 
	    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
		when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01DEC2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;

/*QA*/
/*proc freq data = zoo; tables TYPE_DESC*SYMPTOM_YEAR/MISSING NOCOL NOCUM NOPERCENT NOROW; RUN;


/*Union all diseases summary in period - add disease group and meta data*/

data final;
length Reporting_Date_Type $25;
length Disease_Group $30;
/*set ENTERIC HAI3 HEP4 RESP1 std_ALL VPD ZOO;*/
set Enteric HAI Hep Resp std_ALL VPD zoo;
County_substr=substr(OWNING_JD, 1, length(OWNING_JD)-7);
run;

/*Renaming section*/
data final;
set final;
TYPE_DESC=scan(TYPE_DESC, 1, '(');
if TYPE_DESC='Syphilis - 01. Primary Syphilis' then TYPE_DESC='Syphilis - Primary Syphilis';
	else if TYPE_DESC='Syphilis - 02. Secondary Syphilis' then TYPE_DESC='Syphilis - Secondary Syphilis';
	else if TYPE_DESC='Syphilis - 03. Early, Non-Primary, Non-Secondary Syphilis' then TYPE_DESC='Syphilis - Early, Non-Primary, Non-Secondary Syphilis';
	else if TYPE_DESC='Syphilis - 05. Late Latent Syphilis' then TYPE_DESC='Syphilis - Late Latent Syphilis';
	else if TYPE_DESC='Syphilis - 05. Syphilis Late w/ clinical manifestations' then TYPE_DESC='Syphilis - Late Latent Syphilis';
	else if TYPE_DESC='Syphilis - 05. Unknown Duration or Late Syphilis' then TYPE_DESC='Syphilis - Late Latent Syphilis';
	else if TYPE_DESC='Syphilis - 08. Congenital Syphilis' then TYPE_DESC='Syphilis - Congenital Syphilis';
	else if TYPE_DESC='Syphilis - Unknown Syphilis' then TYPE_DESC=' ';
	else if TYPE_DESC='Carbapenem-resistant Enterobacteriaceae' then TYPE_DESC='Carbapenem-resistant Enterobacterales';
	else if TYPE_DESC='Campylobacter infection' then TYPE_DESC='Campylobacteriosis';
	else if TYPE_DESC='Chlamydia' then TYPE_DESC='Chlamydia trachomatis infection';
	else if TYPE_DESC='Monkeypox' then TYPE_DESC='Mpox';
	else if TYPE_DESC='ZIKA' then TYPE_DESC='Zika';
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
where year=2022;

data temp;
set temp;
year=2023;
run;

data county_pops;
set county_pops temp;
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
/*	OWNING_JD label='County' format=$30. length=30,*/
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',*/
	count(distinct CASE_ID) as Cases_County_Annual
from final
group by Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group
order by Year desc, County_substr, TYPE_DESC;

/*proc sql;*/
/*create table hiv_annual (drop=Qtr Cases Confirmed_Quarterly Probable_Quarterly Quarter Cases_County_Quarterly) as*/
/*select * from hiv1*/
/*group by Year, County_substr*/
/*order by Year desc, County_substr;*/

proc sort data=hiv1 out=hiv_annual (keep=TYPE_DESC County County_substr Year Reporting_Date_Type Disease_Group Disease Cases_County_Annual) nodupkey;
by Year County_substr;
run;


/*data agg_annual;*/
/*set agg_annual tb;*/
/*County_substr=substr(OWNING_JD, 1, length(OWNING_JD)-7);*/
/*run;*/
data agg_annual;
set agg_annual hiv_annual(drop=County);
run;


proc sql;
create table agg_quarter as
select
	Year, Quarter, County_substr,
/*	OWNING_JD label='County' format=$30. length=30, */
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed_Quarterly label='Confirmed Count Quarterly',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable_Quarterly label='Probable Count Quarterly',*/
	count(distinct CASE_ID) as Cases_County_Quarterly
/*	substr(OWNING_JD, 1, length(OWNING_JD)-7) as County_substr*/
from final
group by Year, Quarter, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group
order by Year desc, Quarter, County_substr, TYPE_DESC;

data agg_quarter;
set agg_quarter
	hiv1(keep=Year Quarter County_Substr TYPE_DESC Reporting_Date_Type Disease_Group Cases_County_Quarterly);
run;

/*Add rows for when no cases were reported for the county/year/disease*/

proc sort data=county_pops out=unique_counties (keep=COUNTY) nodupkey ;
by COUNTY;
run;

data unique_diseases;
set agg_quarter;
run;
proc sort data=unique_diseases out=unique_diseases (keep=TYPE_DESC Disease_Group) nodupkey ;
by TYPE_DESC;
run;
data unique_diseases;
set unique_diseases;
if cmiss(of _all_) then delete;
run;

data unique_years;
do Year=2015 to 2023; output; end;
run;

data unique_quarters;
do Quarter=1 to 4; output; end;
run;

proc sql;
create table unique_table_a as
select unique_counties.*, unique_diseases.TYPE_DESC, unique_years.* , unique_quarters.*
from unique_counties cross join unique_diseases cross join unique_years cross join unique_quarters;

proc sql;
create table agg_quarter as
select coalesce(a.Year,b.Year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.TYPE_DESC,b.TYPE_DESC) as TYPE_DESC,
	coalesce(a.County_substr,b.COUNTY) as County_substr, a.*
from agg_quarter a full join unique_table_a b
	on a.year=b.year and a.Quarter=b.Quarter and a.TYPE_DESC=b.TYPE_DESC and a.County_substr=b.COUNTY;

proc sql;
create table case_agg as
select coalesce(a.Year,b.Year) as Year,
	coalesce(a.County_substr,b.County_substr) as County_substr,
	coalesce(a.TYPE_DESC,b.TYPE_DESC) as Disease, 
	coalesce(a.Reporting_Date_Type,b.Reporting_Date_Type) as Reporting_Date_Type,
	coalesce(a.Disease_Group,b.Disease_Group) as Disease_Group,
	a.*, b.*
from agg_annual a full join agg_quarter b
on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC
order by Year desc, County_substr, TYPE_DESC/*, AgeGroup, GENDER, HISPANIC, Race*/;



/*Add rows for when no cases were reported for the county/year/disease*/

proc sort data=county_pops out=unique_counties (keep=COUNTY) nodupkey ;
by COUNTY;
run;

proc sort data=agg_annual out=unique_diseases (keep=TYPE_DESC /*Reporting_Date_Type */Disease_Group) nodupkey ;
by TYPE_DESC;
run;
data unique_diseases;
set unique_diseases;
Disease=TYPE_DESC;
if cmiss(of _all_) then delete;
run;

data unique_years;
do Year=2015 to 2023; output; end;
run;

data unique_quarters;
do Quarter=1 to 4; output; end;
run;

proc sql;
create table unique_table_b as
select unique_counties.*, unique_diseases.Disease, unique_years.* , unique_quarters.*
from unique_counties cross join unique_diseases cross join unique_years cross join unique_quarters;


proc sql;
create table cases as
select coalesce(a.Year,b.Year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.Disease,b.Disease) as Disease,
	coalesce(a.County_substr,b.COUNTY) as County_substr, a.*
from case_agg a full join unique_table_b b
	on a.year=b.year and a.Quarter=b.Quarter and a.Disease=b.Disease and a.County_substr=b.COUNTY;


/*Join with county population data*/
proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.County_substr,b.COUNTY) as County_substr, a.*, b.*
from cases a left join county_pops b
	on a.Year=b.year and a.County_substr=b.COUNTY;

data case_rates (keep=Year Quarter County_substr Disease Reporting_Date_Type Disease_Group Cases_County_Annual
Cases_County_Quarterly county_pop_adjusted male female
white black ai_an asian_pi multi_race hispanic nonhispanic);
set case_rates;
if Disease='Influenza, pediatric death' then county_pop_adjusted=age_0_17;
	else if Disease='Influenza, adult death' then county_pop_adjusted=age_18GE;
	else if Disease='HIV' then county_pop_adjusted=county_pop-age_0_12;
	else county_pop_adjusted=county_pop;
run;


/*Replace missing case totals and incidence with 0*/
data case_rates;
set case_rates;
if missing(Cases_County_Annual) then Cases_County_Annual=0;
if missing(Cases_County_Quarterly) then Cases_County_Quarterly=0;
County_Incidence_100k=Cases_County_Annual/county_pop_adjusted*100000;
County_Incidence_100k_Quarterly=Cases_County_Quarterly/county_pop_adjusted*100000;
format County_Incidence_100k 8.1;
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
where year=2022;

data temp;
set temp;
year=2023;
run;

data state_pops;
set state_pops temp;
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
	Year, Quarter, Disease, sum(Cases_County_Quarterly) as Cases_State_Quarterly/*, AgeGroup*/
from case_rates
group by Year, Quarter, Disease/*, AgeGroup*/
order by Year desc, Quarter, Disease/*, AgeGroup*/;

proc sql;
create table state_rates as
select a.*, b.*
from state_rates_annual a natural join state_rates_quarter b;

proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.Disease,b.Disease) as Disease,
	a.*, b.Cases_State_Annual, b.Cases_State_Quarterly
from case_rates a full join state_rates b
	on a.year=b.year and a.Quarter=b.Quarter and a.Disease=b.Disease;

proc sql;
create table case_rates as
select a.*, b.*
from case_rates a left join state_pops b
	on a.Year=b.year;

/*Finalize*/

data case_rates_final (keep=Year Quarter Reporting_Date_Type Disease Disease_Group County_substr
	Cases_County_Annual Cases_County_Quarterly
	county_pop_adjusted County_Incidence_100k County_Incidence_100k_Quarterly
	Cases_State_Annual Cases_State_Quarterly
	state_pop_adjusted State_Incidence_100k State_Incidence_100k_Quarterly);
set case_rates;
where Year <=2023;
/*if (Year=2023 and Quarter=2) or (Year=2023 and Quarter=3) or (Year=2023 and Quarter=4) then delete;*/
if missing(Cases_State_Annual) then Cases_State_Annual=0;
	else Cases_State_Annual=Cases_State_Annual;
if Disease='Influenza, pediatric death' then state_pop_adjusted=age_0_17;
	else if Disease='Influenza, adult death' then state_pop_adjusted=age_18GE;
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
	else do;
		County_Incidence_100k=County_Incidence_100k;
		County_Incidence_100k_Quarterly=County_Incidence_100k_Quarterly;
		State_Incidence_100k=Cases_State_Annual/state_pop_adjusted*100000;
		State_Incidence_100k_Quarterly=Cases_State_Quarterly/state_pop_adjusted*100000;
		end;
format State_Incidence_100k 8.1;
run;

proc sort data=case_rates_final;
by descending Year Quarter Disease County_substr;
run;


/*proc export data=case_rates_final*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\12-01-23_data_aggregated_quarterly_3-14-24.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Cases by Quarter County";*/
/*run;*/



											/*Demographics Section*/

/*proc export data=cases*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\12-01-23_data_aggregated_demographic_cases_12-07-23.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Demographic Cases";*/
/*run;*/

/*proc sql;*/
/*create table case_agg_demographics as*/
/*select*/
/*	Year, */
/*	OWNING_JD label='County' format=$30. length=30, */
/*	TYPE_DESC label='Disease',*/
/*	put(age, agegrp.) as AgeGroup,*/
/*	GENDER, HISPANIC,*/
/*	case when (RACE2 ne '' or RACE3 ne '' or RACE4 ne '' or RACE5 ne '' or RACE6 ne '') then "Multi-Race"*/
/*		else RACE1*/
/*		end as Race,*/
/*	count(distinct CASE_ID) as Demographic_Subtotal*/
/*from final*/
/*group by Year, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race*/
/*order by Year desc, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race;*/

/*proc sql;*/
/*create table case_agg_annual as*/
/*select agg_agegroup.*, b.**/
/*from case_agg_annual a full join case_agg_demographics b*/
/*	on a.Year=b.Year and a.OWNING_JD=b.OWNING_JD and a.TYPE_DESC=b.TYPE_DESC*/
/*order by Year desc, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race;*/


/*Add year to demographic population tables; Apply suppression*/

proc sql;
create table temp as
select *
from demo_county_pops
where year=2022;
data temp;
set temp;
year=2023;
run;

data demo_county_pops;
set demo_county_pops temp;
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


proc sql;
create table temp as
select *
from demo_state_pops
where year=2022;
data temp;
set temp;
year=2023;
run;

data demo_state_pops;
set demo_state_pops temp;
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


/*Match race choices with population data variables*/
proc sql;
create table final(drop=RACE1 RACE2 RACE3 RACE4 RACE5 RACE6) as
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
data final;
format HISPANIC $15.;
set final;
if Race='' then Race='Missing/Unknown';
else if Race='Unknown' then Race='Missing/Unknown';

if find (Hispanic,"Yes")>0 then HISPANIC='Hispanic';
else if find (Hispanic,"No")>0 then HISPANIC='non-Hispanic';
else if HISPANIC='' then HISPANIC='Missing/Unknown';
else if find (Hispanic, "Unknown")>0 then HISPANIC='Missing/Unknown';
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
	65-high='65+';
run;


/*Generate Age Summary*/

/*proc sql;*/
/*create table cases_age as*/
/*select TYPE_DESC, disease_group, OWNING_JD, mmwr_year, AgeGroup, SYMPTOM_YEAR, DOB, LHD_DX_YR, DEDUP_YEAR, count(TYPE_DESC) as Count*/
/*from final*/
/*group by TYPE_DESC, disease_group, OWNING_JD, mmwr_year, AgeGroup*/
/*order by TYPE_DESC, disease_group, OWNING_JD, mmwr_year, AgeGroup;*/
/*quit;*/

/* Export age summary table*/
/*proc export data=cases_age*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\age_summary_ncd3_040123.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Cases Age Summary";*/
/*run;*/
/*quit;*/


/*Join in Population Data; assign age categories ((if needed - not required for YTD reporting; used in NCD3 2.0))*/

/*proc sql;*/
/*create table agegroups as*/
/*select a.*, upcase(tranwrd(a.OWNING_JD, 'County', '')) as joinwrd,*/
/*	b.age_0_04_pop2020, b.age_05_11_pop2020, b.age_12_17_pop2020, b.age_18_24_pop2020, b.age_25_49_pop2020, b.age_50_64_pop2020, b.age_GE65_pop2020*/
/*from cases_age a*/
/*left join county_pops b*/
/*on upcase(tranwrd(a.OWNING_JD,'County',''))=b.upper_cnty;*/

/*Calculate Age-Specific Rates*/

/*create table agegroups2 as*/
/*select */
/*	TYPE_DESC,*/
/*	OWNING_JD,*/
/*	MMWR_YEAR,*/
/*	AgeGroup,*/
/*	Count,*/
/*	case */
/*		when AgeGroup='0-5' then Count/age_0_04_pop2020 */
/*		when AgeGroup='5-12' then Count/age_05_11_pop2020 */
/*		when AgeGroup='12-18' then Count/age_12_17_pop2020 */
/*		when AgeGroup='18-25' then Count/age_18_24_pop2020 */
/*		when AgeGroup='25-50' then Count/age_25_49_pop2020 */
/*		when AgeGroup='50-64' then Count/age_50_64_pop2020 */
/*		when AgeGroup='65+' then Count/age_GE65_pop2020  else . end as agerate*/
/*from agegroups*/
/*order by TYPE_DESC, OWNING_JD, mmwr_year, AgeGroup;*/
/*quit;*/


data agg_agegroup;
set final;
	AgeGroup=put(age, agegrp.);
run;
proc sql;
create table agg_agegroup as
select Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group,
	AgeGroup, count(distinct CASE_ID) as County_Annual_Cases_AgeGroup
from agg_agegroup
group by Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group, AgeGroup
order by Year desc, County_substr, TYPE_DESC, AgeGroup;

proc sql;
create table agg_agegroup_state as
select
	Year, TYPE_DESC, AgeGroup,
	sum(County_Annual_Cases_AgeGroup) as State_Annual_Cases_AgeGroup
from agg_agegroup
group by Year, TYPE_DESC, AgeGroup
order by Year desc, TYPE_DESC, AgeGroup;

proc sql;
create table agg_agegroup as
select a.*, b.*
from agg_agegroup a left join agg_agegroup_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.AgeGroup=b.AgeGroup
order by Year desc, County_substr, TYPE_DESC, AgeGroup;

/*proc transpose data=agg_agegroup out=agg_agegroup(drop=_NAME_);*/
/*  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;*/
/*  id AgeGroup;*/
/*  var Total_AgeGroup;*/
/*run;*/

proc sql;
create table rates_agegroup as
select a.*, b.*
from agg_agegroup a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_agegroup as
select
	Year, County_substr, TYPE_DESC, AgeGroup, County_Annual_Cases_AgeGroup, State_Annual_Cases_AgeGroup,
	case
			when AgeGroup='0-12' then State_Annual_Cases_AgeGroup/age_0_12*100000
			when AgeGroup='13-17' then State_Annual_Cases_AgeGroup/age_13_17*100000
			when AgeGroup='18-24' then State_Annual_Cases_AgeGroup/age_18_24*100000
			when AgeGroup='25-49' then State_Annual_Cases_AgeGroup/age_25_49*100000
			when AgeGroup='50-64' then State_Annual_Cases_AgeGroup/age_50_64*100000
			when AgeGroup='65+' then State_Annual_Cases_AgeGroup/age_GE65*100000
		end as State_Annual_Incidence_AgeGroup
from rates_agegroup;

proc sql;
create table rates_agegroup as
select a.*, b.*
from rates_agegroup a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_agegroup as
select
	Year, County_substr, TYPE_DESC, AgeGroup,
	State_Annual_Cases_AgeGroup, State_Annual_Incidence_AgeGroup, County_Annual_Cases_AgeGroup,
	case when AgeGroup='0-12' then County_Annual_Cases_AgeGroup/age_0_12*100000
		when AgeGroup='13-17' then County_Annual_Cases_AgeGroup/age_13_17*100000
		when AgeGroup='18-24' then County_Annual_Cases_AgeGroup/age_18_24*100000
		when AgeGroup='25-49' then County_Annual_Cases_AgeGroup/age_25_49*100000
		when AgeGroup='50-64' then County_Annual_Cases_AgeGroup/age_50_64*100000
		when AgeGroup='65+' then County_Annual_Cases_AgeGroup/age_GE65*100000
		end as County_Annual_Incidence_AgeGroup
from rates_agegroup
order by Year desc, County_substr, TYPE_DESC, AgeGroup;

/*Adjust population denominators for Influenzas and HIV*/
/*proc sql;*/
/*create table rates_agegroup_special as*/
/*select a.*, b.**/
/*from agg_agegroup a left join state_pops_sup b*/
/*	on a.Year=b.year;*/
/*where TYPE_DESC in ('*/

proc sql;
create table rates_agegroup as
select
	Year, County_substr, TYPE_DESC, AgeGroup, County_Annual_Cases_AgeGroup, State_Annual_Cases_AgeGroup,
	case
			when AgeGroup='0-12' then State_Annual_Cases_AgeGroup/age_0_12*100000
			when AgeGroup='13-17' then State_Annual_Cases_AgeGroup/age_13_17*100000
			when AgeGroup='18-24' then State_Annual_Cases_AgeGroup/age_18_24*100000
			when AgeGroup='25-49' then State_Annual_Cases_AgeGroup/age_25_49*100000
			when AgeGroup='50-64' then State_Annual_Cases_AgeGroup/age_50_64*100000
			when AgeGroup='65+' then State_Annual_Cases_AgeGroup/age_GE65*100000
		end as State_Annual_Incidence_AgeGroup
from rates_agegroup;

proc sql;
create table rates_agegroup as
select a.*, b.*
from rates_agegroup a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_agegroup as
select
	Year, County_substr, TYPE_DESC, AgeGroup,
	State_Annual_Cases_AgeGroup, State_Annual_Incidence_AgeGroup, County_Annual_Cases_AgeGroup,
	case when AgeGroup='0-12' then County_Annual_Cases_AgeGroup/age_0_12*100000
		when AgeGroup='13-17' then County_Annual_Cases_AgeGroup/age_13_17*100000
		when AgeGroup='18-24' then County_Annual_Cases_AgeGroup/age_18_24*100000
		when AgeGroup='25-49' then County_Annual_Cases_AgeGroup/age_25_49*100000
		when AgeGroup='50-64' then County_Annual_Cases_AgeGroup/age_50_64*100000
		when AgeGroup='65+' then County_Annual_Cases_AgeGroup/age_GE65*100000
		end as County_Annual_Incidence_AgeGroup
from rates_agegroup
order by Year desc, County_substr, TYPE_DESC, AgeGroup;


data rates_agegroup;
set rates_agegroup;
if left(AgeGroup) NE '.' and State_Annual_Incidence_AgeGroup=. then do;
	County_Annual_Cases_AgeGroup=.; State_Annual_Cases_AgeGroup=.; end;
if left(AgeGroup) NE '.' and County_Annual_Incidence_AgeGroup=. then County_Annual_Cases_AgeGroup=.;
run;


/*Generate Gender Summary*/

proc sql;
create table agg_GENDER as
select
	Year, County_substr, TYPE_DESC,	Reporting_Date_Type, Disease_Group,
	GENDER, count(distinct CASE_ID) as County_Annual_Cases_GENDER
from final
group by Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group, GENDER
order by Year desc, County_substr, TYPE_DESC, GENDER;

/*proc transpose data=agg_GENDER out=agg_GENDER(drop=_NAME_);*/
/*  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;*/
/*  id GENDER;*/
/*  var Total_Gender;*/
/*run;*/

proc sql;
create table agg_GENDER_state as
select
	Year, TYPE_DESC, GENDER,
	sum(County_Annual_Cases_GENDER) as State_Annual_Cases_GENDER
from agg_GENDER
group by Year, TYPE_DESC, GENDER
order by Year desc, TYPE_DESC, GENDER;

proc sql;
create table agg_GENDER as
select a.*, b.*
from agg_GENDER a left join agg_GENDER_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER
order by Year desc, County_substr, TYPE_DESC, GENDER;

proc sql;
create table rates_GENDER as
select a.*, b.*
from agg_GENDER a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDER as
select
	Year, County_substr, TYPE_DESC, GENDER, County_Annual_Cases_GENDER, State_Annual_Cases_GENDER,
	case
			when GENDER='Female' then State_Annual_Cases_GENDER/female*100000
			when GENDER='Male' then State_Annual_Cases_GENDER/male*100000
		end as State_Annual_Incidence_GENDER
from rates_GENDER;

proc sql;
create table rates_GENDER as
select a.*, b.*
from rates_GENDER a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDER as
select
	Year, County_substr, TYPE_DESC, GENDER,
	State_Annual_Cases_GENDER, State_Annual_Incidence_GENDER, County_Annual_Cases_GENDER,
	case
			when GENDER='Female' then County_Annual_Cases_GENDER/female*100000
			when GENDER='Male' then County_Annual_Cases_GENDER/male*100000
		end as County_Annual_Incidence_GENDER
from rates_GENDER
order by Year desc, County_substr, TYPE_DESC, GENDER;

data rates_GENDER;
set rates_GENDER;
if GENDER NE ' ' and State_Annual_Incidence_GENDER=. then do;
	State_Annual_Cases_GENDER=.; County_Annual_Cases_GENDER=.; end;
if GENDER NE ' ' and County_Annual_Incidence_GENDER=. then County_Annual_Cases_GENDER=.;
run;



/*Generate Ethnicity-Hispanic Summary*/

proc sql;
create table agg_HISPANIC as
select
	Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group,
/*	'Hispanic_'||HISPANIC as HISPANIC length=17,*/ HISPANIC,
	count(distinct CASE_ID) as County_Annual_Cases_HISPANIC
from final
group by Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group, HISPANIC
order by Year desc, County_substr, TYPE_DESC, HISPANIC;
/*data agg_HISPANIC;*/
/*set agg_HISPANIC;*/
/*if HISPANIC='Hispanic_' then HISPANIC='Hispanic_NoAnswer';*/
/*run;*/

/*proc transpose data=agg_HISPANIC out=agg_HISPANIC(drop=_NAME_);*/
/*  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;*/
/*  id HISPANIC;*/
/*  var Total_HISPANIC;*/
/*run;*/

proc sql;
create table agg_HISPANIC_state as
select
	Year, TYPE_DESC, HISPANIC,
	sum(County_Annual_Cases_HISPANIC) as State_Annual_Cases_HISPANIC
from agg_HISPANIC
group by Year, TYPE_DESC, HISPANIC
order by Year desc, TYPE_DESC, HISPANIC;

proc sql;
create table agg_HISPANIC as
select a.*, b.*
from agg_HISPANIC a left join agg_HISPANIC_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.HISPANIC=b.HISPANIC
order by Year desc, County_substr, TYPE_DESC, HISPANIC;

proc sql;
create table rates_HISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from agg_HISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_HISPANIC as
select
	Year, County_substr, TYPE_DESC, HISPANIC, County_Annual_Cases_HISPANIC, State_Annual_Cases_HISPANIC,
	case
			when HISPANIC='Hispanic' then State_Annual_Cases_HISPANIC/hispanicyes*100000
			when HISPANIC='non-Hispanic' then State_Annual_Cases_HISPANIC/nonhispanic*100000
		end as State_Annual_Incidence_HISPANIC
from rates_HISPANIC;

proc sql;
create table rates_HISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from rates_HISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_HISPANIC as
select
	Year, County_substr, TYPE_DESC, HISPANIC,
	State_Annual_Cases_HISPANIC, State_Annual_Incidence_HISPANIC, County_Annual_Cases_HISPANIC,
	case
			when HISPANIC='Hispanic' then County_Annual_Cases_HISPANIC/hispanicyes*100000
			when HISPANIC='non-Hispanic' then County_Annual_Cases_HISPANIC/nonhispanic*100000
		end as County_Annual_Incidence_HISPANIC
from rates_HISPANIC
order by Year desc, County_substr, TYPE_DESC, HISPANIC;

data rates_HISPANIC;
set rates_HISPANIC;
if HISPANIC NE 'Missing/Unknown' and State_Annual_Incidence_HISPANIC=. then do;
	State_Annual_Cases_HISPANIC=.; County_Annual_Cases_HISPANIC=.; end;
if HISPANIC NE 'Missing/Unknown' and County_Annual_Incidence_HISPANIC=. then County_Annual_Cases_HISPANIC=.;
run;


/*Generate Race Summary*/

proc sql;
create table agg_race as
select
	Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group, Race,
	count(distinct CASE_ID) as County_Annual_Cases_Race
from final
group by Year, County_substr, TYPE_DESC, Reporting_Date_Type, Disease_Group, Race
order by Year, County_substr, TYPE_DESC, Race;
/*data agg_race;*/
/*set agg_race;*/
/*if Race='Other' then Race='Race_Other';*/
/*else if Race='Unknown' then Race='Race_Unknown';*/
/*run;*/

/*proc transpose data=agg_race out=agg_race(drop=_NAME_);*/
/*  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;*/
/*  id Race;*/
/*  var Total_Race;*/
/*run;*/

proc sql;
create table agg_Race_state as
select
	Year, TYPE_DESC, Race,
	sum(County_Annual_Cases_Race) as State_Annual_Cases_Race
from agg_Race
group by Year, TYPE_DESC, Race
order by Year desc, TYPE_DESC, Race;

proc sql;
create table agg_Race as
select a.*, b.*
from agg_Race a left join agg_Race_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.Race=b.Race
order by Year desc, County_substr, TYPE_DESC, Race;

proc sql;
create table rates_Race as
select a.*, b.*
from agg_Race a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_Race as
select
	Year, County_substr, TYPE_DESC, Race, County_Annual_Cases_Race, State_Annual_Cases_Race,
	case when Race='American Indian Alaskan Native' then State_Annual_Cases_Race/ai_an*100000
		when Race='Asian or Native Hawaiian or Pacific Islander' then State_Annual_Cases_Race/asian_pi*100000
		when Race='Black or African American' then State_Annual_Cases_Race/black*100000
		when Race='Multi-Race' then State_Annual_Cases_Race/multi_race*100000
		when Race='Other' then State_Annual_Cases_Race/nonhispanic*100000
		when Race='White' then State_Annual_Cases_Race/white*100000
		end as State_Annual_Incidence_Race
from rates_Race;

proc sql;
create table rates_Race as
select a.*, b.*
from rates_Race a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_Race as
select
	Year, County_substr, TYPE_DESC, Race,
	State_Annual_Cases_Race, State_Annual_Incidence_Race, County_Annual_Cases_Race,
	case
			when Race='American Indian Alaskan Native' then County_Annual_Cases_Race/ai_an*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' then County_Annual_Cases_Race/asian_pi*100000
			when Race='Black or African American' then County_Annual_Cases_Race/black*100000
			when Race='Multi-Race' then County_Annual_Cases_Race/multi_race*100000
			when Race='White' then County_Annual_Cases_Race/white*100000
		end as County_Annual_Incidence_Race
from rates_Race
order by Year desc, County_substr, TYPE_DESC, Race;

data rates_Race;
set rates_Race;
if Race NE 'Missing/Unknown' and State_Annual_Incidence_Race=. then do;
	State_Annual_Cases_Race=.; County_Annual_Cases_Race=.; end;
if Race NE 'Missing/Unknown' and County_Annual_Incidence_Race=. then County_Annual_Cases_Race=.;
run;



/*Combine*/
proc sql;
create table demographic_simple as
select rates_AgeGroup.*, rates_GENDER.*, rates_HISPANIC.*, rates_Race.*
from rates_AgeGroup a left join rates_GENDER b
	on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC
	/*	and a.Reporting_Date_Type=b.Reporting_Date_Type and a.Disease_Group=b.Disease_Group*/
left join rates_HISPANIC c
	on a.Year=c.Year and a.County_substr=c.County_substr and a.TYPE_DESC=c.TYPE_DESC
left join rates_Race d
	on a.Year=d.Year and a.County_substr=d.County_substr and a.TYPE_DESC=d.TYPE_DESC
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup, Race, HISPANIC;



									/*Cross-tabs*/

/*Gender X Age*/

data agg_GENDERXAge;
set final;
	AgeGroup=put(age, agegrp.);
run;
proc sql;
create table agg_GENDERXAge as
select Year, County_substr, TYPE_DESC, GENDER, AgeGroup,
	count(distinct CASE_ID) as County_Ann_Cases_GENDERXAge
from agg_GENDERXAge
group by Year, County_substr, TYPE_DESC, GENDER, AgeGroup
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup;

proc sql;
create table agg_GENDERXAge_state as
select
	Year, TYPE_DESC, GENDER, AgeGroup,
	sum(County_Ann_Cases_GENDERXAge) as State_Annual_Cases_GENDERXAge
from agg_GENDERXAge
group by Year, TYPE_DESC, GENDER, AgeGroup
order by Year desc, TYPE_DESC, GENDER, AgeGroup;

proc sql;
create table agg_GENDERXAge as
select a.*, b.*
from agg_GENDERXAge a left join agg_GENDERXAge_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER and a.AgeGroup=b.AgeGroup
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup;

proc sql;
create table rates_GENDERXAge as
select a.*, b.*
from agg_GENDERXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXAge as
select
	Year, County_substr, TYPE_DESC, GENDER, AgeGroup, County_Ann_Cases_GENDERXAge, State_Annual_Cases_GENDERXAge,
	case
			when GENDER='Female' and AgeGroup='0-12' then State_Annual_Cases_GENDERXAge/female_0_12*100000
			when GENDER='Female' and AgeGroup='13-17' then State_Annual_Cases_GENDERXAge/female_13_17*100000
			when GENDER='Female' and AgeGroup='18-24' then State_Annual_Cases_GENDERXAge/female_18_24*100000
			when GENDER='Female' and AgeGroup='25-49' then State_Annual_Cases_GENDERXAge/female_25_49*100000
			when GENDER='Female' and AgeGroup='50-64' then State_Annual_Cases_GENDERXAge/female_50_64*100000
			when GENDER='Female' and AgeGroup='65+' then State_Annual_Cases_GENDERXAge/female_65GE*100000
			when GENDER='Male' and AgeGroup='0-12' then State_Annual_Cases_GENDERXAge/male_0_12*100000
			when GENDER='Male' and AgeGroup='13-17' then State_Annual_Cases_GENDERXAge/male_13_17*100000
			when GENDER='Male' and AgeGroup='18-24' then State_Annual_Cases_GENDERXAge/male_18_24*100000
			when GENDER='Male' and AgeGroup='25-49' then State_Annual_Cases_GENDERXAge/male_25_49*100000
			when GENDER='Male' and AgeGroup='50-64' then State_Annual_Cases_GENDERXAge/male_50_64*100000
			when GENDER='Male' and AgeGroup='65+' then State_Annual_Cases_GENDERXAge/male_65GE*100000
		end as State_Ann_Incidence_GENDERXAge
from rates_GENDERXAge;

proc sql;
create table rates_GENDERXAge as
select a.*, b.*
from rates_GENDERXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXAge as
select
	Year, County_substr, TYPE_DESC, GENDER, AgeGroup,
	State_Annual_Cases_GENDERXAge, State_Ann_Incidence_GENDERXAge, County_Ann_Cases_GENDERXAge,
	case
			when GENDER='Female' and AgeGroup='0-12' then County_Ann_Cases_GENDERXAge/female_0_12*100000
			when GENDER='Female' and AgeGroup='13-17' then County_Ann_Cases_GENDERXAge/female_13_17*100000
			when GENDER='Female' and AgeGroup='18-24' then County_Ann_Cases_GENDERXAge/female_18_24*100000
			when GENDER='Female' and AgeGroup='25-49' then County_Ann_Cases_GENDERXAge/female_25_49*100000
			when GENDER='Female' and AgeGroup='50-64' then County_Ann_Cases_GENDERXAge/female_50_64*100000
			when GENDER='Female' and AgeGroup='65+' then County_Ann_Cases_GENDERXAge/female_65GE*100000
			when GENDER='Male' and AgeGroup='0-12' then County_Ann_Cases_GENDERXAge/male_0_12*100000
			when GENDER='Male' and AgeGroup='13-17' then County_Ann_Cases_GENDERXAge/male_13_17*100000
			when GENDER='Male' and AgeGroup='18-24' then County_Ann_Cases_GENDERXAge/male_18_24*100000
			when GENDER='Male' and AgeGroup='25-49' then County_Ann_Cases_GENDERXAge/male_25_49*100000
			when GENDER='Male' and AgeGroup='50-64' then County_Ann_Cases_GENDERXAge/male_50_64*100000
			when GENDER='Male' and AgeGroup='65+' then County_Ann_Cases_GENDERXAge/male_65GE*100000
		end as County_Ann_Incidence_GENDERXAge
from rates_GENDERXAge
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup;

data rates_GENDERXAge;
set rates_GENDERXAge;
if GENDER NE '' and left(AgeGroup) NE '.' and State_Ann_Incidence_GENDERXAge=. then do;
	State_Annual_Cases_GENDERXAge=.; County_Ann_Cases_GENDERXAge=.; end;
if GENDER NE '' and left(AgeGroup) NE '.' and County_Ann_Incidence_GENDERXAge=. then County_Ann_Cases_GENDERXAge=.;
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
select Year, County_substr, TYPE_DESC, GENDER, Race,
	count(distinct CASE_ID) as County_Ann_Cases_GENDERXRace
from final
group by Year, County_substr, TYPE_DESC, GENDER, Race
order by Year desc, County_substr, TYPE_DESC, GENDER, Race;

proc sql;
create table agg_GENDERXRace_state as
select
	Year, TYPE_DESC, GENDER, Race,
	sum(County_Ann_Cases_GENDERXRace) as State_Annual_Cases_GENDERXRace
from agg_GENDERXRace
group by Year, TYPE_DESC, GENDER, Race
order by Year desc, TYPE_DESC, GENDER, Race;

proc sql;
create table agg_GENDERXRace as
select a.*, b.*
from agg_GENDERXRace a left join agg_GENDERXRace_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER and a.Race=b.Race
order by Year desc, County_substr, TYPE_DESC, GENDER, Race;


proc sql;
create table rates_GENDERXRace as
select a.*, b.*
from agg_GENDERXRace a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXRace as
select
	Year, County_substr, TYPE_DESC, GENDER, Race, County_Ann_Cases_GENDERXRace, State_Annual_Cases_GENDERXRace,
	case
			when GENDER='Female' and Race='American Indian Alaskan Native'
				then State_Annual_Cases_GENDERXRace/female_ai_an*100000
			when GENDER='Female' and Race='Asian or Native Hawaiian or Pacific Islander'
				then State_Annual_Cases_GENDERXRace/female_asian_pi*100000
			when GENDER='Female' and Race='Black or African American'
				then State_Annual_Cases_GENDERXRace/female_black*100000
			when GENDER='Female' and Race='Multi-Race'
				then State_Annual_Cases_GENDERXRace/female_multi_race*100000
			when GENDER='Female' and Race='White'
				then State_Annual_Cases_GENDERXRace/female_white*100000
			when GENDER='Male' and Race='American Indian Alaskan Native'
				then State_Annual_Cases_GENDERXRace/male_ai_an*100000
			when GENDER='Male' and Race='Asian or Native Hawaiian or Pacific Islander'
				then State_Annual_Cases_GENDERXRace/male_asian_pi*100000
			when GENDER='Male' and Race='Black or African American'
				then State_Annual_Cases_GENDERXRace/male_black*100000
			when GENDER='Male' and Race='Multi-Race'
				then State_Annual_Cases_GENDERXRace/male_multi_race*100000
			when GENDER='Male' and Race='White'
				then State_Annual_Cases_GENDERXRace/male_white*100000
		end as State_Ann_Incidence_GENDERXRace
from rates_GENDERXRace;

proc sql;
create table rates_GENDERXRace as
select a.*, b.*
from rates_GENDERXRace a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXRace as
select
	Year, County_substr, TYPE_DESC, GENDER, Race,
	State_Annual_Cases_GENDERXRace, State_Ann_Incidence_GENDERXRace, County_Ann_Cases_GENDERXRace,
	case
			when GENDER='Female' and Race='American Indian Alaskan Native'
				then County_Ann_Cases_GENDERXRace/female_ai_an*100000
			when GENDER='Female' and Race='Asian or Native Hawaiian or Pacific Islander'
				then County_Ann_Cases_GENDERXRace/female_asian_pi*100000
			when GENDER='Female' and Race='Black or African American'
				then County_Ann_Cases_GENDERXRace/female_black*100000
			when GENDER='Female' and Race='Multi-Race'
				then County_Ann_Cases_GENDERXRace/female_multi_race*100000
			when GENDER='Female' and Race='White'
				then County_Ann_Cases_GENDERXRace/female_white*100000
			when GENDER='Male' and Race='American Indian Alaskan Native'
				then County_Ann_Cases_GENDERXRace/male_ai_an*100000
			when GENDER='Male' and Race='Asian or Native Hawaiian or Pacific Islander'
				then County_Ann_Cases_GENDERXRace/male_asian_pi*100000
			when GENDER='Male' and Race='Black or African American'
				then County_Ann_Cases_GENDERXRace/male_black*100000
			when GENDER='Male' and Race='Multi-Race'
				then County_Ann_Cases_GENDERXRace/male_multi_race*100000
			when GENDER='Male' and Race='White'
				then County_Ann_Cases_GENDERXRace/male_white*100000
		end as County_Ann_Incidence_GENDERXRace
from rates_GENDERXRace
order by Year desc, County_substr, TYPE_DESC, GENDER, Race;

data rates_GENDERXRace;
set rates_GENDERXRace;
if GENDER NE '' and Race NE '' and State_Ann_Incidence_GENDERXRace=. then do;
	State_Annual_Cases_GENDERXRace=.; County_Ann_Cases_GENDERXRace=.; end;
if GENDER NE '' and Race NE '' and County_Ann_Incidence_GENDERXRace=. then County_Ann_Cases_GENDERXRace=.;
run;


/*Gender X HISPANIC*/

proc sql;
create table agg_GENDERXHISPANIC as
select Year, County_substr, TYPE_DESC, GENDER, HISPANIC,
	count(distinct CASE_ID) as County_Ann_Cases_GENDERXHISPANIC
from final
group by Year, County_substr, TYPE_DESC, GENDER, HISPANIC
order by Year desc, County_substr, TYPE_DESC, GENDER, HISPANIC;

proc sql;
create table agg_GENDERXHISPANIC_state as
select
	Year, TYPE_DESC, GENDER, HISPANIC,
	sum(County_Ann_Cases_GENDERXHISPANIC) as State_Ann_Cases_GENDERXHISPANIC
from agg_GENDERXHISPANIC
group by Year, TYPE_DESC, GENDER, HISPANIC
order by Year desc, TYPE_DESC, GENDER, HISPANIC;

proc sql;
create table agg_GENDERXHISPANIC as
select a.*, b.*
from agg_GENDERXHISPANIC a left join agg_GENDERXHISPANIC_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER and a.HISPANIC=b.HISPANIC
order by Year desc, County_substr, TYPE_DESC, GENDER, HISPANIC;


proc sql;
create table rates_GENDERXHISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from agg_GENDERXHISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_GENDERXHISPANIC as
select
	Year, County_substr, TYPE_DESC, GENDER, HISPANIC, County_Ann_Cases_GENDERXHISPANIC, State_Ann_Cases_GENDERXHISPANIC,
	case
			when GENDER='Female' and HISPANIC='Yes' then State_Ann_Cases_GENDERXHISPANIC/female_hisp*100000
			when GENDER='Female' and HISPANIC='No' then State_Ann_Cases_GENDERXHISPANIC/female_nonhisp*100000
			when GENDER='Male' and HISPANIC='Yes' then State_Ann_Cases_GENDERXHISPANIC/male_hisp*100000
			when GENDER='Male' and HISPANIC='No' then State_Ann_Cases_GENDERXHISPANIC/male_nonhisp*100000
		end as State_Ann_Inci_GENDERXHISPANIC
from rates_GENDERXHISPANIC;

proc sql;
create table rates_GENDERXHISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from rates_GENDERXHISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_GENDERXHISPANIC as
select
	Year, County_substr, TYPE_DESC, GENDER, HISPANIC,
	State_Ann_Cases_GENDERXHISPANIC, State_Ann_Inci_GENDERXHISPANIC, County_Ann_Cases_GENDERXHISPANIC,
	case
			when GENDER='Female' and HISPANIC='Yes' then County_Ann_Cases_GENDERXHISPANIC/female_hisp*100000
			when GENDER='Female' and HISPANIC='No' then County_Ann_Cases_GENDERXHISPANIC/female_nonhisp*100000
			when GENDER='Male' and HISPANIC='Yes' then County_Ann_Cases_GENDERXHISPANIC/male_hisp*100000
			when GENDER='Male' and HISPANIC='No' then County_Ann_Cases_GENDERXHISPANIC/male_nonhisp*100000
		end as County_Ann_Inci_GENDERXHISPANIC
from rates_GENDERXHISPANIC
order by Year desc, County_substr, TYPE_DESC, GENDER, HISPANIC;

data rates_GENDERXHISPANIC;
set rates_GENDERXHISPANIC;
if GENDER NE '' and HISPANIC NE '' and HISPANIC NE 'Unknown' and State_Ann_Inci_GENDERXHISPANIC=. then do;
	State_Ann_Cases_GENDERXHISPANIC=.; County_Ann_Cases_GENDERXHISPANIC=.; end;
if GENDER NE '' and HISPANIC NE '' and HISPANIC NE 'Unknown' and County_Ann_Inci_GENDERXHISPANIC=. then County_Ann_Cases_GENDERXHISPANIC=.;
run;


/*Race X Age*/

data agg_RaceXAge;
set final;
	AgeGroup=put(age, agegrp.);
run;
proc sql;
create table agg_RaceXAge as
select Year, County_substr, TYPE_DESC, Race, AgeGroup,
	count(distinct CASE_ID) as County_Ann_Cases_RaceXAge
from agg_RaceXAge
group by Year, County_substr, TYPE_DESC, Race, AgeGroup
order by Year desc, County_substr, TYPE_DESC, Race, AgeGroup;

proc sql;
create table agg_RaceXAge_state as
select
	Year, TYPE_DESC, Race, AgeGroup,
	sum(County_Ann_Cases_RaceXAge) as State_Annual_Cases_RaceXAge
from agg_RaceXAge
group by Year, TYPE_DESC, Race, AgeGroup
order by Year desc, TYPE_DESC, Race, AgeGroup;

proc sql;
create table agg_RaceXAge as
select a.*, b.*
from agg_RaceXAge a left join agg_RaceXAge_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.Race=b.Race and a.AgeGroup=b.AgeGroup
order by Year desc, County_substr, TYPE_DESC, Race, AgeGroup;

proc sql;
create table rates_RaceXAge as
select a.*, b.*
from agg_RaceXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_RaceXAge as
select
	Year, County_substr, TYPE_DESC, Race, AgeGroup, County_Ann_Cases_RaceXAge, State_Annual_Cases_RaceXAge,
	case
			when Race='American Indian Alaskan Native' and AgeGroup='0-12' then State_Annual_Cases_RaceXAge/ai_an_0_12*100000
			when Race='American Indian Alaskan Native' and AgeGroup='13-17' then State_Annual_Cases_RaceXAge/ai_an_13_17*100000
			when Race='American Indian Alaskan Native' and AgeGroup='18-24' then State_Annual_Cases_RaceXAge/ai_an_18_24*100000
			when Race='American Indian Alaskan Native' and AgeGroup='25-49' then State_Annual_Cases_RaceXAge/ai_an_25_49*100000
			when Race='American Indian Alaskan Native' and AgeGroup='50-64' then State_Annual_Cases_RaceXAge/ai_an_50_64*100000
			when Race='American Indian Alaskan Native' and AgeGroup='65+' then State_Annual_Cases_RaceXAge/ai_an_65GE*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='0-12' then State_Annual_Cases_RaceXAge/asian_pi_0_12*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='13-17' then State_Annual_Cases_RaceXAge/asian_pi_13_17*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='18-24' then State_Annual_Cases_RaceXAge/asian_pi_18_24*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='25-49' then State_Annual_Cases_RaceXAge/asian_pi_25_49*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='50-64' then State_Annual_Cases_RaceXAge/asian_pi_50_64*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='65+' then State_Annual_Cases_RaceXAge/ai_an_65GE*100000
			when Race='Black or African American' and AgeGroup='0-12' then State_Annual_Cases_RaceXAge/black_0_12*100000
			when Race='Black or African American' and AgeGroup='13-17' then State_Annual_Cases_RaceXAge/black_13_17*100000
			when Race='Black or African American' and AgeGroup='18-24' then State_Annual_Cases_RaceXAge/black_18_24*100000
			when Race='Black or African American' and AgeGroup='25-49' then State_Annual_Cases_RaceXAge/black_25_49*100000
			when Race='Black or African American' and AgeGroup='50-64' then State_Annual_Cases_RaceXAge/black_50_64*100000
			when Race='Black or African American' and AgeGroup='65+' then State_Annual_Cases_RaceXAge/black_65GE*100000
			when Race='Multi-Race' and AgeGroup='0-12' then State_Annual_Cases_RaceXAge/multi_race_0_12*100000
			when Race='Multi-Race' and AgeGroup='13-17' then State_Annual_Cases_RaceXAge/multi_race_13_17*100000
			when Race='Multi-Race' and AgeGroup='18-24' then State_Annual_Cases_RaceXAge/multi_race_18_24*100000
			when Race='Multi-Race' and AgeGroup='25-49' then State_Annual_Cases_RaceXAge/multi_race_25_49*100000
			when Race='Multi-Race' and AgeGroup='50-64' then State_Annual_Cases_RaceXAge/multi_race_50_64*100000
			when Race='Multi-Race' and AgeGroup='65+' then State_Annual_Cases_RaceXAge/multi_race_65GE*100000
			when Race='White' and AgeGroup='0-12' then State_Annual_Cases_RaceXAge/white_0_12*100000
			when Race='White' and AgeGroup='13-17' then State_Annual_Cases_RaceXAge/white_13_17*100000
			when Race='White' and AgeGroup='18-24' then State_Annual_Cases_RaceXAge/white_18_24*100000
			when Race='White' and AgeGroup='25-49' then State_Annual_Cases_RaceXAge/white_25_49*100000
			when Race='White' and AgeGroup='50-64' then State_Annual_Cases_RaceXAge/white_50_64*100000
			when Race='White' and AgeGroup='65+' then State_Annual_Cases_RaceXAge/white_65GE*100000
		end as State_Ann_Incidence_RaceXAge
from rates_RaceXAge;

proc sql;
create table rates_RaceXAge as
select a.*, b.*
from rates_RaceXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_RaceXAge as
select
	Year, County_substr, TYPE_DESC, Race, AgeGroup,
	State_Annual_Cases_RaceXAge, State_Ann_Incidence_RaceXAge, County_Ann_Cases_RaceXAge,
	case
			when Race='American Indian Alaskan Native' and AgeGroup='0-12' then County_Ann_Cases_RaceXAge/ai_an_0_12*100000
			when Race='American Indian Alaskan Native' and AgeGroup='13-17' then County_Ann_Cases_RaceXAge/ai_an_13_17*100000
			when Race='American Indian Alaskan Native' and AgeGroup='18-24' then County_Ann_Cases_RaceXAge/ai_an_18_24*100000
			when Race='American Indian Alaskan Native' and AgeGroup='25-49' then County_Ann_Cases_RaceXAge/ai_an_25_49*100000
			when Race='American Indian Alaskan Native' and AgeGroup='50-64' then County_Ann_Cases_RaceXAge/ai_an_50_64*100000
			when Race='American Indian Alaskan Native' and AgeGroup='65+' then County_Ann_Cases_RaceXAge/ai_an_65GE*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='0-12' then County_Ann_Cases_RaceXAge/asian_pi_0_12*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='13-17' then County_Ann_Cases_RaceXAge/asian_pi_13_17*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='18-24' then County_Ann_Cases_RaceXAge/asian_pi_18_24*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='25-49' then County_Ann_Cases_RaceXAge/asian_pi_25_49*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='50-64' then County_Ann_Cases_RaceXAge/asian_pi_50_64*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and AgeGroup='65+' then County_Ann_Cases_RaceXAge/ai_an_65GE*100000
			when Race='Black or African American' and AgeGroup='0-12' then County_Ann_Cases_RaceXAge/black_0_12*100000
			when Race='Black or African American' and AgeGroup='13-17' then County_Ann_Cases_RaceXAge/black_13_17*100000
			when Race='Black or African American' and AgeGroup='18-24' then County_Ann_Cases_RaceXAge/black_18_24*100000
			when Race='Black or African American' and AgeGroup='25-49' then County_Ann_Cases_RaceXAge/black_25_49*100000
			when Race='Black or African American' and AgeGroup='50-64' then County_Ann_Cases_RaceXAge/black_50_64*100000
			when Race='Black or African American' and AgeGroup='65+' then County_Ann_Cases_RaceXAge/black_65GE*100000
			when Race='Multi-Race' and AgeGroup='0-12' then County_Ann_Cases_RaceXAge/multi_race_0_12*100000
			when Race='Multi-Race' and AgeGroup='13-17' then County_Ann_Cases_RaceXAge/multi_race_13_17*100000
			when Race='Multi-Race' and AgeGroup='18-24' then County_Ann_Cases_RaceXAge/multi_race_18_24*100000
			when Race='Multi-Race' and AgeGroup='25-49' then County_Ann_Cases_RaceXAge/multi_race_25_49*100000
			when Race='Multi-Race' and AgeGroup='50-64' then County_Ann_Cases_RaceXAge/multi_race_50_64*100000
			when Race='Multi-Race' and AgeGroup='65+' then County_Ann_Cases_RaceXAge/multi_race_65GE*100000
			when Race='White' and AgeGroup='0-12' then County_Ann_Cases_RaceXAge/white_0_12*100000
			when Race='White' and AgeGroup='13-17' then County_Ann_Cases_RaceXAge/white_13_17*100000
			when Race='White' and AgeGroup='18-24' then County_Ann_Cases_RaceXAge/white_18_24*100000
			when Race='White' and AgeGroup='25-49' then County_Ann_Cases_RaceXAge/white_25_49*100000
			when Race='White' and AgeGroup='50-64' then County_Ann_Cases_RaceXAge/white_50_64*100000
			when Race='White' and AgeGroup='65+' then County_Ann_Cases_RaceXAge/white_65GE*100000
	end as County_Ann_Incidence_RaceXAge
from rates_RaceXAge
order by Year desc, County_substr, TYPE_DESC, Race, AgeGroup;

data rates_RaceXAge;
set rates_RaceXAge;
if Race NE '' and left(AgeGroup) NE '.' and State_Ann_Incidence_RaceXAge=. then do;
	State_Annual_Cases_RaceXAge=.; County_Ann_Cases_RaceXAge=.; end;
if Race NE '' and left(AgeGroup) NE '.' and County_Ann_Incidence_RaceXAge=. then County_Ann_Cases_RaceXAge=.;
run;

/*proc export data=rates_RaceXAge*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Race X Age";*/
/*run;*/


/*Ethnicity X Age*/

data agg_HISPANICXAge;
set final;
	AgeGroup=put(age, agegrp.);
run;
proc sql;
create table agg_HISPANICXAge as
select Year, County_substr, TYPE_DESC, HISPANIC, AgeGroup,
	count(distinct CASE_ID) as County_Ann_Cases_HISPANICXAge
from agg_HISPANICXAge
group by Year, County_substr, TYPE_DESC, HISPANIC, AgeGroup
order by Year desc, County_substr, TYPE_DESC, HISPANIC, AgeGroup;

proc sql;
create table agg_HISPANICXAge_state as
select
	Year, TYPE_DESC, HISPANIC, AgeGroup,
	sum(County_Ann_Cases_HISPANICXAge) as State_Annual_Cases_HISPANICXAge
from agg_HISPANICXAge
group by Year, TYPE_DESC, HISPANIC, AgeGroup
order by Year desc, TYPE_DESC, HISPANIC, AgeGroup;

proc sql;
create table agg_HISPANICXAge as
select a.*, b.*
from agg_HISPANICXAge a left join agg_HISPANICXAge_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.HISPANIC=b.HISPANIC and a.AgeGroup=b.AgeGroup
order by Year desc, County_substr, TYPE_DESC, HISPANIC, AgeGroup;

proc sql;
create table rates_HISPANICXAge as
select a.*, b.*, b.hispanic as hispanicyes
from agg_HISPANICXAge a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_HISPANICXAge as
select
	Year, County_substr, TYPE_DESC, HISPANIC, AgeGroup, County_Ann_Cases_HISPANICXAge, State_Annual_Cases_HISPANICXAge,
	case
			when HISPANIC='Yes' and AgeGroup='0-12' then State_Annual_Cases_HISPANICXAge/hisp_0_12*100000
			when HISPANIC='Yes' and AgeGroup='13-17' then State_Annual_Cases_HISPANICXAge/hisp_13_17*100000
			when HISPANIC='Yes' and AgeGroup='18-24' then State_Annual_Cases_HISPANICXAge/hisp_18_24*100000
			when HISPANIC='Yes' and AgeGroup='25-49' then State_Annual_Cases_HISPANICXAge/hisp_25_49*100000
			when HISPANIC='Yes' and AgeGroup='50-64' then State_Annual_Cases_HISPANICXAge/hisp_50_64*100000
			when HISPANIC='Yes' and AgeGroup='65+' then State_Annual_Cases_HISPANICXAge/hisp_65GE*100000
			when HISPANIC='No' and AgeGroup='0-12' then State_Annual_Cases_HISPANICXAge/nonhisp_0_12*100000
			when HISPANIC='No' and AgeGroup='13-17' then State_Annual_Cases_HISPANICXAge/nonhisp_13_17*100000
			when HISPANIC='No' and AgeGroup='18-24' then State_Annual_Cases_HISPANICXAge/nonhisp_18_24*100000
			when HISPANIC='No' and AgeGroup='25-49' then State_Annual_Cases_HISPANICXAge/nonhisp_25_49*100000
			when HISPANIC='No' and AgeGroup='50-64' then State_Annual_Cases_HISPANICXAge/nonhisp_50_64*100000
			when HISPANIC='No' and AgeGroup='65+' then State_Annual_Cases_HISPANICXAge/nonhisp_65GE*100000
		end as State_Ann_Incidence_HISPANICXAge
from rates_HISPANICXAge;

proc sql;
create table rates_HISPANICXAge as
select a.*, b.*, b.hispanic as hispanicyes
from rates_HISPANICXAge a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_HISPANICXAge as
select
	Year, County_substr, TYPE_DESC, HISPANIC, AgeGroup,
	State_Annual_Cases_HISPANICXAge, State_Ann_Incidence_HISPANICXAge, County_Ann_Cases_HISPANICXAge,
	case
			when HISPANIC='Yes' and AgeGroup='0-12' then County_Ann_Cases_HISPANICXAge/hisp_0_12*100000
			when HISPANIC='Yes' and AgeGroup='13-17' then County_Ann_Cases_HISPANICXAge/hisp_13_17*100000
			when HISPANIC='Yes' and AgeGroup='18-24' then County_Ann_Cases_HISPANICXAge/hisp_18_24*100000
			when HISPANIC='Yes' and AgeGroup='25-49' then County_Ann_Cases_HISPANICXAge/hisp_25_49*100000
			when HISPANIC='Yes' and AgeGroup='50-64' then County_Ann_Cases_HISPANICXAge/hisp_50_64*100000
			when HISPANIC='Yes' and AgeGroup='65+' then County_Ann_Cases_HISPANICXAge/hisp_65GE*100000
			when HISPANIC='No' and AgeGroup='0-12' then County_Ann_Cases_HISPANICXAge/nonhisp_0_12*100000
			when HISPANIC='No' and AgeGroup='13-17' then County_Ann_Cases_HISPANICXAge/nonhisp_13_17*100000
			when HISPANIC='No' and AgeGroup='18-24' then County_Ann_Cases_HISPANICXAge/nonhisp_18_24*100000
			when HISPANIC='No' and AgeGroup='25-49' then County_Ann_Cases_HISPANICXAge/nonhisp_25_49*100000
			when HISPANIC='No' and AgeGroup='50-64' then County_Ann_Cases_HISPANICXAge/nonhisp_50_64*100000
			when HISPANIC='No' and AgeGroup='65+' then County_Ann_Cases_HISPANICXAge/nonhisp_65GE*100000
	end as County_Ann_Incid_HISPANICXAge
from rates_HISPANICXAge
order by Year desc, County_substr, TYPE_DESC, HISPANIC, AgeGroup;

data rates_HISPANICXAge;
set rates_HISPANICXAge;
if HISPANIC NE '' and HISPANIC NE 'Unknown' and left(AgeGroup) NE '.' and State_Ann_Incidence_HISPANICXAge=. then do;
	State_Annual_Cases_HISPANICXAge=.; County_Ann_Cases_HISPANICXAge=.; end;
if HISPANIC NE '' and HISPANIC NE 'Unknown' and left(AgeGroup) NE '.' and County_Ann_Incid_HISPANICXAge=. then County_Ann_Cases_HISPANICXAge=.;
run;


/*Race X Ethnicity*/

proc sql;
create table agg_RaceXHISPANIC as
select Year, County_substr, TYPE_DESC, Race, HISPANIC,
	count(distinct CASE_ID) as County_Ann_Cases_RaceXHISPANIC
from final
group by Year, County_substr, TYPE_DESC, Race, HISPANIC
order by Year desc, County_substr, TYPE_DESC, Race, HISPANIC;

proc sql;
create table agg_RaceXHISPANIC_state as
select
	Year, TYPE_DESC, Race, HISPANIC,
	sum(County_Ann_Cases_RaceXHISPANIC) as State_Annual_Cases_RaceXHISPANIC
from agg_RaceXHISPANIC
group by Year, TYPE_DESC, Race, HISPANIC
order by Year desc, TYPE_DESC, Race, HISPANIC;

proc sql;
create table agg_RaceXHISPANIC as
select a.*, b.*
from agg_RaceXHISPANIC a left join agg_RaceXHISPANIC_state b
	on a.Year=b.year and a.TYPE_DESC=b.TYPE_DESC and a.Race=b.Race and a.HISPANIC=b.HISPANIC
order by Year desc, County_substr, TYPE_DESC, Race, HISPANIC;

proc sql;
create table rates_RaceXHISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from agg_RaceXHISPANIC a left join demo_state_pops_sup b
	on a.Year=b.year;

proc sql;
create table rates_RaceXHISPANIC as
select
	Year, County_substr, TYPE_DESC, Race, HISPANIC, County_Ann_Cases_RaceXHISPANIC, State_Annual_Cases_RaceXHISPANIC,
	case
			when Race='American Indian Alaskan Native' and HISPANIC='Yes' then State_Annual_Cases_RaceXHISPANIC/hisp_ai_an*100000
			when Race='American Indian Alaskan Native' and HISPANIC='No' then State_Annual_Cases_RaceXHISPANIC/nonhisp_ai_an*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and HISPANIC='Yes' then State_Annual_Cases_RaceXHISPANIC/hisp_asian_pi*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and HISPANIC='No' then State_Annual_Cases_RaceXHISPANIC/nonhisp_asian_pi*100000
			when Race='Black or African American' and HISPANIC='Yes' then State_Annual_Cases_RaceXHISPANIC/hisp_black*100000
			when Race='Black or African American' and HISPANIC='No' then State_Annual_Cases_RaceXHISPANIC/nonhisp_black*100000
			when Race='Multi-Race' and HISPANIC='Yes' then State_Annual_Cases_RaceXHISPANIC/hisp_multi_race*100000
			when Race='Multi-Race' and HISPANIC='No' then State_Annual_Cases_RaceXHISPANIC/nonhisp_multi_race*100000
			when Race='White' and HISPANIC='Yes' then State_Annual_Cases_RaceXHISPANIC/hisp_white*100000
			when Race='White' and HISPANIC='No' then State_Annual_Cases_RaceXHISPANIC/nonhisp_white*100000
		end as State_Ann_Inci_RaceXHISPANIC
from rates_RaceXHISPANIC;

proc sql;
create table rates_RaceXHISPANIC as
select a.*, b.*, b.hispanic as hispanicyes
from rates_RaceXHISPANIC a left join demo_county_pops_sup b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table rates_RaceXHISPANIC as
select
	Year, County_substr, TYPE_DESC, Race, HISPANIC,
	State_Annual_Cases_RaceXHISPANIC, State_Ann_Inci_RaceXHISPANIC, County_Ann_Cases_RaceXHISPANIC,
	case
			when Race='American Indian Alaskan Native' and HISPANIC='Yes' then County_Ann_Cases_RaceXHISPANIC/hisp_ai_an*100000
			when Race='American Indian Alaskan Native' and HISPANIC='No' then County_Ann_Cases_RaceXHISPANIC/nonhisp_ai_an*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and HISPANIC='Yes' then County_Ann_Cases_RaceXHISPANIC/hisp_asian_pi*100000
			when Race='Asian or Native Hawaiian or Pacific Islander' and HISPANIC='No' then County_Ann_Cases_RaceXHISPANIC/nonhisp_asian_pi*100000
			when Race='Black or African American' and HISPANIC='Yes' then County_Ann_Cases_RaceXHISPANIC/hisp_black*100000
			when Race='Black or African American' and HISPANIC='No' then County_Ann_Cases_RaceXHISPANIC/nonhisp_black*100000
			when Race='Multi-Race' and HISPANIC='Yes' then County_Ann_Cases_RaceXHISPANIC/hisp_multi_race*100000
			when Race='Multi-Race' and HISPANIC='No' then County_Ann_Cases_RaceXHISPANIC/nonhisp_multi_race*100000
			when Race='White' and HISPANIC='Yes' then County_Ann_Cases_RaceXHISPANIC/hisp_white*100000
			when Race='White' and HISPANIC='No' then County_Ann_Cases_RaceXHISPANIC/nonhisp_white*100000
	end as County_Ann_Inci_RaceXHISPANIC
from rates_RaceXHISPANIC
order by Year desc, County_substr, TYPE_DESC, Race, HISPANIC;

data rates_RaceXHISPANIC;
set rates_RaceXHISPANIC;
if  Race NE '' and HISPANIC NE '' and HISPANIC NE 'Unknown' and State_Ann_Inci_RaceXHISPANIC=. then do;
	State_Annual_Cases_RaceXHISPANIC=.; County_Ann_Cases_RaceXHISPANIC=.; end;
if Race NE '' and HISPANIC NE '' and HISPANIC NE 'Unknown' and County_Ann_Inci_RaceXHISPANIC=. then County_Ann_Cases_RaceXHISPANIC=.;
run;


/*Combine*/

proc sql;
create table demographic_multiple as
select rates_GENDERXAge.*, rates_GENDERXRace.*, rates_GENDERXHISPANIC.*
from rates_GENDERXAge a left join rates_GENDERXRace b
	on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER
left join rates_GENDERXHISPANIC c
	on a.Year=c.Year and a.County_substr=c.County_substr and a.TYPE_DESC=c.TYPE_DESC and a.GENDER=c.GENDER
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup, Race, HISPANIC;
proc sql;
create table demographic_multiple as
select demographic_multiple.*, rates_RaceXAge.*, rates_HISPANICXAge.*, rates_RaceXHISPANIC.*
from demographic_multiple a left join rates_RaceXAge b
	on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC 
		and a.Race=b.Race and a.AgeGroup=b.AgeGroup
left join rates_HISPANICXAge c
	on a.Year=c.Year and a.County_substr=c.County_substr and a.TYPE_DESC=c.TYPE_DESC 
		and a.HISPANIC=c.HISPANIC and a.AgeGroup=c.AgeGroup
left join rates_RaceXHISPANIC d
	on a.Year=d.Year and a.County_substr=d.County_substr and a.TYPE_DESC=d.TYPE_DESC
		and a.Race=d.Race and a.HISPANIC=d.HISPANIC
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup, Race, HISPANIC;

/*proc export data=demographic_multiple*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics_multiple.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Demographic CD";*/
/*run;*/

proc sql;
create table demographic_all as
select demographic_simple.*, demographic_multiple.*
from demographic_simple a full join demographic_multiple b
	on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC and a.GENDER=b.GENDER
		and a.Race=b.Race and a.AgeGroup=b.AgeGroup and a.HISPANIC=b.HISPANIC
order by Year desc, County_substr, TYPE_DESC, GENDER, AgeGroup, Race, HISPANIC;

/*Suppress perinatal rates*/
proc contents data=demographic_all out=_DemoTableNames_;
run;

proc sql noprint;
select name into :IncidenceNames separated by ' ' from _DemoTableNames_ where name ? ('Inci');
data Incidence;
set demographic_all(keep=TYPE_DESC &IncidenceNames);
run;

data Incidence(drop=i);
set Incidence;
array x &IncidenceNames;
do i=1 to dim(x);
    if TYPE_DESC='Botulism - infant' then x(i)=.;
    else if TYPE_DESC='Hepatitis B - Perinatally Acquired' then x(i)=.;
    else if TYPE_DESC='Syphilis - Congenital Syphilis' then x(i)=.;
end;
run;

data demographic_all;
merge demographic_all(drop=&IncidenceNames) Incidence(drop=TYPE_DESC);
run;



/*proc export data=demographic_all*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\rates_cd_demographics.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Demographic CD";*/
/*run;*/





/*Save SAS environment*/

/*Caution: This libref should never point to a storage location containing any other data,
because prior to storing the SAS WORK datasets and catalogs,
SAS will delete all of the contents of this library.*/

/*options presenv; */
/*libname bkuploc 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20231201data';*/
/*filename restore 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20231201data\restoration_pgm.sas';*/
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
/*tables TYPE_DESC*mmwr_year/missing;*/
/*tables OWNING_JD/missing;*/
/*where TYPE_DESC='HIV Disease' and mmwr_year='2020';*/
/*run;*/
/**/
/*QA*/
/**/
/**/
/*Create List of Diseases (if needed - not required for YTD reporting; used in NCD3 2.0)*/

/*1*/
/*proc sql;*/
/*	create table diseases as*/
/*	select distinct TYPE_DESC*/
/*	from all_diseases*/
/*	order by TYPE_DESC;*/
/*quit;*/

/*/*2 proc freq data = all_diseases; tables TYPE_DESC; run;*/
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
on a.TYPE_DESC=b.TYPE_DESC
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
select distinct TYPE_DESC
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
