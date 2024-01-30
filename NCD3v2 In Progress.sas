																/*LAST MODIFIED DATE: 1/17/23*/
													/*LAST MODIFIED BY: LINDA YELTON (LWY) linda.yelton@dhhs.nc.gov*/
/*Purpose: Script in progres to create the Data Source for the North Carolina Disease Data Dashboard (NCD3) next update*/
/*	Internal server: https://internaldashboards.ncdhhs.gov/#/site/DPH/projects/400*/
/*	External server: https://dashboards.ncdhhs.gov/#/site/DPH/projects/158*/
/*	Internal server workbook name: NCD3 v2 2023 Update - Adding Quarterly Data*/
/*	Tableau workbook location: T:\Tableau\NCD3 2.0\Tableau Workbooks\NCD3 v2 2023 July Update for CDB site Quarterly in Progress.twbx*/


/*Must have access to NCEDSS_SAS(Z:) - CBD denorm server to run this program*/
libname denorm 'Z:\20240101'; /*This can be updated as needed to produce most recent counts; M. Hilton provides a new extract monthly*/
options compress=yes;
options nofmterr;

/* Must have access to CD Users Shared (T:) to access these */
/* files to be used later in program */

/* TB */
libname tb 'T:\Tableau\SAS folders\SAS datasets\TB Program Data 2005 - 2022'; /*this will need to be refreshed as newer years of counts are needed*/

/* HIV */
proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\HIV AIDS 2015-2023 by quarter_through Q3.xlsx' out=HIV dbms=xlsx replace; run;

/* County population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\County Census Pop_10_22.xlsx'
out=county_pops dbms=xlsx replace; run;

/* State population */
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\State Census Pop_10_22.xlsx'
out=state_pops dbms=xlsx replace; run;


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
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
	and s.type in ("FLU", "FLUD", "FLUDA", "LEG")
	and s.REPORT_TO_CDC = 'Yes';
quit;

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
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
	YEAR(BIRTH_DATE) as dob label = 'YEAR OF BIRTH', LHD_DIAGNOSIS_DATE, DATE_FOR_REPORTING,
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


/*HIV/AIDS; File provided by Jason Maxwell on 7/6/23, analyst for HIV/STD program; jason.maxwell@dhhs.nc.gov*/

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
	and s.type in ("DIP", "HFLU", "MEAS", "MENP", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "RUB", "RUBCONG", "TET", "VAC", "VARICELLA")
	and s.REPORT_TO_CDC = 'Yes';
quit;

proc sql;
create table CASE_COMBO_sub as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type = "AFM";
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
		when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
	    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
	    else CREATE_DT
	    end as EVENT_DATE format=DATE9., 
	year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month, QTR(calculated EVENT_DATE) as Quarter,
	SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
	and s.type in ("ANTH", "ARB", "BRU", "CHIKV", "CJD", "DENGUE", "EHR", "HGE", "EEE", "HME", 
	"LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", 
	"YF", "ZIKA", "VHF")
	and s.REPORT_TO_CDC = 'Yes';
quit;

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
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
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
AgeGroup=put(age, agegrp.);
run;

/*Deen added this to group Syphilis before case aggregation*/
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
run;

/*proc sort data=final;*/
/*by descending Year OWNING_JD TYPE_DESC CLASSIFICATION_CLASSIFICATION Age CASE_ID;*/
/*run;*/

/*libname interim 'T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\Interim';*/
/*data interim.final; */
/*set final;*/
/*run;*/



/*Edit county population file*/

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

ods listing;
ods results;

proc sql;
create table agg_annual as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',*/
	count(distinct CASE_ID) as Cases_County_Annual
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group
order by Year desc, OWNING_JD, TYPE_DESC;


/*proc sql;*/
/*create table case_agg_annual as*/
/*select agg_agegroup.*, b.**/
/*from case_agg_annual a full join case_agg_demographics b*/
/*	on a.Year=b.Year and a.OWNING_JD=b.OWNING_JD and a.TYPE_DESC=b.TYPE_DESC*/
/*order by Year desc, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race;*/


proc sql;
create table hiv_annual (drop=Qtr Cases Confirmed_Quarterly Probable_Quarterly Quarter Cases_County_Quarterly) as
select * from hiv1
group by Year, County_substr
order by Year desc, County_substr;
/*proc sort data=hiv1 out=hiv_annual (drop=Qtr Cases Confirmed_Quarterly Probable_Quarterly Quarter Cases_County_Quarterly) nodupkey;*/
/*by Year County_substr;*/
/*run;*/

data agg_annual;
set agg_annual /*tb*/;
County_substr=substr(OWNING_JD, 1, length(OWNING_JD)-7);
run;
data agg_annual;
set agg_annual hiv_annual(drop=County);
run;


proc sql;
create table agg_quarter as
select
	Year, Quarter,
/*	OWNING_JD label='County' format=$30. length=30, */
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed_Quarterly label='Confirmed Count Quarterly',*/
/*	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable_Quarterly label='Probable Count Quarterly',*/
	count(distinct CASE_ID) as Cases_County_Quarterly,
	substr(OWNING_JD, 1, length(OWNING_JD)-7) as County_substr
from final
group by Year, Quarter, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group
order by Year desc, Quarter, OWNING_JD, TYPE_DESC;

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
order by Year desc, OWNING_JD, TYPE_DESC/*, AgeGroup, GENDER, HISPANIC, Race*/;


/*Deen edit 8/23/2023. Commented out this code. Re-wrote and moved to before aggregation step*/
/*data case_agg;*/
/*set case_agg;*/
/*Disease=scan(TYPE_DESC, 1, '(');*/
/*if Disease='Syphilis - 05. Syphilis Late w/ clinical manifestations' then Disease='Syphilis - 05. Late Latent Syphilis';*/
/*	else if Disease='Syphilis - 05. Unknown Duration or Late Syphilis' then Disease='Syphilis - 05. Late Latent Syphilis';*/
/*	else if Disease='Syphilis - Unknown Syphilis' then Disease=' ';*/
/*run;*/

/*proc sql;*/
/*create table case_agg as*/
/*select a.*, b.**/
/*from case_agg2 a join case_agg_quarter b*/
/*on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC;*/
/*proc sort data=case_agg;*/
/*by descending Year OWNING_JD Quarter TYPE_DESC  ;*/
/*run;*/


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

/*proc export data=cases*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\12-01-23_data_aggregated_demographic_cases_12-07-23.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Demographic Cases";*/
/*run;*/


/*Join with county population data*/
proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.County_substr,b.COUNTY) as County_substr, a.*, b.*
from cases a left join county_pops b
	on a.Year=b.year and a.County_substr=b.COUNTY;

data case_rates (keep=Year Quarter County_substr Disease Reporting_Date_Type Disease_Group Cases_County_Annual
Cases_County_Quarterly county_pop_adjusted /*Demographic_Subtotal*/ male female
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
if /*(Year=2023 and Quarter=2) or (Year=2023 and Quarter=3) or */(Year=2023 and Quarter=4) then delete;
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
if Disease='Carbapenem-resistant Enterobacteriaceae' then Disease='Carbapenem-resistant Enterobacterales';
	else if Disease='Campylobacter infection' then Disease='Campylobacteriosis';
	else if Disease='Chlamydia' then Disease='Chlamydia trachomatis infection';
	else if Disease='Monkeypox' then Disease='Mpox';
	else Disease=Disease;
run;

proc sort data=case_rates_final;
by descending Year Quarter Disease County_substr;
run;


/*proc export data=case_rates_final*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\12-01-23_data_aggregated_quarterly_1-23-24.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Aggregated Cases by Quarter County";*/
/*run;*/



/*Demographics Section*/


/*proc sql;*/
/*create table case_agg_demographics as*/
/*select*/
/*	Year, */
/*	OWNING_JD label='County' format=$30. length=30, */
/*	TYPE_DESC label='Disease',*/
/*	AgeGroup, GENDER, HISPANIC,*/
/*	case when (RACE2 ne '' or RACE3 ne '' or RACE4 ne '' or RACE5 ne '' or RACE6 ne '') then "Multi-Race"*/
/*		else RACE1*/
/*		end as Race,*/
/*	count(distinct CASE_ID) as Demographic_Subtotal*/
/*from final*/
/*group by Year, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race*/
/*order by Year desc, OWNING_JD, TYPE_DESC, AgeGroup, GENDER, HISPANIC, Race;*/


/*Create Age Bins*/
proc format;
	value agegrp
		0-<5='0-5'
		5-<12='5-12'
		12-<18='12-18'
		18-<25='18-25'
		25-<50='25-50'
		50-<65='50-64'
		65-high='65+';
run;

proc sql;
create table agg_agegroup as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
	put(age, agegrp.) as AgeGroup,
	count(distinct CASE_ID) as Total_AgeGroup
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group, AgeGroup
order by Year, OWNING_JD, TYPE_DESC, AgeGroup;

proc transpose data=agg_agegroup out=agg_agegroup(drop=_NAME_);
  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;
  id AgeGroup;
  var Total_AgeGroup;
run;


proc sql;
create table agg_GENDER as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
	GENDER, count(distinct CASE_ID) as Total_GENDER
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group, GENDER
order by Year, OWNING_JD, TYPE_DESC, GENDER;

proc transpose data=agg_GENDER out=agg_GENDER(drop=_NAME_);
  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;
  id GENDER;
  var Total_Gender;
run;


proc sql;
create table agg_HISPANIC as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
/*	'Hispanic_'||HISPANIC as HISPANIC length=17,*/ HISPANIC,
	count(distinct CASE_ID) as Total_HISPANIC
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group, HISPANIC
order by Year, OWNING_JD, TYPE_DESC, HISPANIC;
/*data agg_HISPANIC;*/
/*set agg_HISPANIC;*/
/*if HISPANIC='Hispanic_' then HISPANIC='Hispanic_NoAnswer';*/
/*run;*/

proc transpose data=agg_HISPANIC out=agg_HISPANIC(drop=_NAME_);
  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;
  id HISPANIC;
  var Total_HISPANIC;
run;


proc sql;
create table agg_race as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
	case when (RACE2 ne '' or RACE3 ne '' or RACE4 ne '' or RACE5 ne '' or RACE6 ne '') then "Multi-Race"
		else RACE1
		end as Race,
	count(distinct CASE_ID) as Total_Race
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group, Race
order by Year, OWNING_JD, TYPE_DESC, Race;
/*data agg_race;*/
/*set agg_race;*/
/*if Race='Other' then Race='Race_Other';*/
/*else if Race='Unknown' then Race='Race_Unknown';*/
/*run;*/

proc transpose data=agg_race out=agg_race(drop=_NAME_);
  by Year OWNING_JD TYPE_DESC Reporting_Date_Type Disease_Group;
  id Race;
  var Total_Race;
run;


proc sql;
create table demographic_counts as
select agg_annual.*, agg_GENDER.*, agg_HISPANIC.*, agg_race.*
from agg_annual a left join agg_GENDER b
on a.Year=b.Year and a.OWNING_JD=b.OWNING_JD and a.TYPE_DESC=b.TYPE_DESC
	and a.Reporting_Date_Type=b.Reporting_Date_Type and a.Disease_Group=b.Disease_Group
left join agg_race c
on a.Year=c.Year and a.OWNING_JD=c.OWNING_JD and a.TYPE_DESC=c.TYPE_DESC
	and a.Reporting_Date_Type=c.Reporting_Date_Type and a.Disease_Group=c.Disease_Group
left join agg_HISPANIC d
on a.Year=d.Year and a.OWNING_JD=d.OWNING_JD and a.TYPE_DESC=d.TYPE_DESC
	and a.Reporting_Date_Type=d.Reporting_Date_Type and a.Disease_Group=d.Disease_Group
order by Year desc, OWNING_JD, TYPE_DESC;

proc sql;
create table demographic_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.County_substr,b.COUNTY) as County_substr, a.*, b.*
from demographic_counts a left join county_pops b
	on a.Year=b.year and a.County_substr=b.COUNTY;

proc sql;
create table demographic_rates as
select demographic_counts a left join county_pops b
on 	on a.Year=b.year and a.County_substr=b.COUNTY;


/*Save SAS environment*/

/*Caution: This libref should never point to a storage location containing any other data,*/
/*since prior to storing the SAS WORK datasets and catalogs,*/
/*SAS will delete all of the contents of this library.*/

/*options presenv; */
/*libname bkuploc 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20231201data';*/
/*filename restore 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20231201data\restoration_pgm.sas';*/
/*proc presenv*/
/* permdir=bkuploc*/
/* sascode=restore*/
/* show_comments;*/
/* run; */


/*THE FOLLOWING NOT IN USE YET*/

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

proc export data=ncd3outputreg
    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\032723NCD3_OUTPUT.xlsx"
    dbms=xlsx
    replace;
    sheet="NCD3 2.0 COUNTS";
run;
quit;
