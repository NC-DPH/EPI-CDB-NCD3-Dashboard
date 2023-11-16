																/*LAST MODIFIED DATE: 11/01/23*/
													/*LAST MODIFIED BY: LINDA YELTON (LWY) linda.yelton@dhhs.nc.gov*/
/*Purpose: Copied from NCD3v2_lwy_072423.sas to troubleshoot discrepencies in NCD3 for MCU diseases brought up by Justin Alberton*/


/*Must have access to NCEDSS_SAS(Z:) - CBD denorm server to run this program*/
libname denorm 'C:\Users\lwelton\Downloads'; 
options compress=yes;
options nofmterr;

/* Must have access to CD Users Shared (T:) to access these files*/

/* TB file to be used later in program */
libname tb 'T:\Tableau\SAS folders\SAS datasets\TB Program Data 2005 - 2022'; /*this will need to be refreshed as newer years of counts are needed*/

/*Import Meta data, disease-specific files, clean disease names and groups in GCDC_Detail file*/

/*proc import datafile='T:\Tableau\NCD3 2.0\2022\NCD3_metadata_MASTER_ads.xlsx' out=dgrps dbms=xlsx replace; sheet="NCD3 Diseases"; run;*/
/*proc import datafile='T:\Tableau\NCD3 2.0\2022\NCALHD_LHDs_Counties_2023.xlsx' out=regions dbms=xlsx replace; sheet="NCD3 Regions"; run;*/
/* HIV file to be used later in program */
proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\HIV 2015-2022 by quarter_clean.xlsx' out=HIV dbms=xlsx replace; run;
/*proc import datafile='T:\Tableau\NCD3 2.0\SAS Datasets\CURRENT_USE_NCD3_2.0_HIV AIDS 2015-2022.xlsx' out=AIDS dbms=xlsx replace; sheet="AIDS"; run;*/


/*Sort NCD3 2.0 Metadata*/
/*PROC SORT DATA=dgrps;*/
/*  BY type_desc;*/
/*RUN;*/
/*Sort Regions file*/
/*PROC SORT DATA=regions;*/
/*  BY county;*/
/*RUN;*/
/*Sort HIV counts*/
/*PROC SORT DATA=HIV;*/
/* BY OWNING_JD;*/
/*RUN;*/
/*Sort AIDS counts*/
/*PROC SORT DATA=AIDS;*/
/*  BY OWNING_JD;*/
/*RUN;*/


/*proc sql;*/
/*create table types as*/
/*select distinct type, type_desc*/
/*from denorm.case;*/
/*quit;*/
/**/
/*proc freq data = types;*/
/*tables type*type_desc/MISSING NOCOL NOCUM NOPERCENT NOROW; RUN;*/
/*run;*/
/*quit;*/


											/*BEGIN CREATING TABLES TO MERGE; DISEASE GROUPS ARE IN ALPHABETICAL ORDER*/



																			/*Enteric*/

proc sql;
create table enteric as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', 
symptom_onset_date, DATE_FOR_REPORTING, age,
CALCULATED SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter,
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR
AND CLASSIFICATION_CLASSIFICATION in ("Suspect", "Confirmed", "Probable")
and type in ("BOT", "BOTI", "CAMP", "CRYPT", "CYCLO", "ECOLI", 
"FBOTHER", "CPERF", "FBPOIS", "STAPH", "HUS", "LIST", "SAL",
"SHIG", "TRICH", "TYPHOID", "TYPHCAR", "VIBOTHER", "VIBVUL")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, CALCULATED SYMPTOM_YEAR, OWNING_JD;
quit;


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
create table enteric as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', age,
QTR(symptom_onset_date) as Quarter,
case 
    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
	when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
    else CREATE_DT
    end as EVENT_DATE format=DATE9., 
year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,
SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

data entericTest;
set enteric;
where Year=2022;
run;
proc sql;
create table entericTest as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from entericTest
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;

proc sql;
    select sum(Total) as Sum
    from entericTest;


data enteric;
set enteric;
Disease_Group='Enteric';
Reporting_Date_Type='Symptom Onset Date';
run;

																				/*HAI*/

proc sql;
create table HAI1 as
select owning_jd, type, type_desc,CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', 
symptom_onset_date, DATE_FOR_REPORTING, age,
input(mmwr_year, 4.) as Year label='Year',
QTR(MMWR_DATE_BASIS) as Quarter
from denorm.case
where mmwr_year in ('2015', '2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023') /*use for NCD3 2.0*/
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("CAURIS", "CRE", /*"STRA"*/, "SAUR", "TSS", "TSSS")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, MMWR_Year, OWNING_JD;
quit;

data HAI1;
set HAI1;
Reporting_Date_Type='MMWR Date';
run;

proc sql;
create table HAI2 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',
symptom_onset_date, age, DATE_FOR_REPORTING,
CALCULATED SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR 
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type = ("STRA")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, calculated symptom_year, OWNING_JD;
quit;

data HAI2;
set HAI2;
Reporting_Date_Type='Symptom Onset Date';
run;

/*Combine all HAI data sets*/
data HAI3;
length Reporting_Date_Type $25;
set HAI1 HAI2;
Disease_Group='Healthcare Acquired Infection';
run;


proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("CAURIS", "CRE", "STRA", "SAUR", "TSS", "TSSS")
	and s.REPORT_TO_CDC = 'Yes';
quit;

proc sql;
create table HAI as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', age,
QTR(symptom_onset_date) as Quarter,
case 
    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
	when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
    else CREATE_DT
    end as EVENT_DATE format=DATE9., 
year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,
SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

data HAITest;
set HAI;
where Year=2022;
run;
proc sql;
create table HAITest as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from HAITest
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;

proc sql;
    select sum(Total) as Sum
    from HAITest;

															/*Hep Table 1 - MMWR_YEAR*/
proc sql;
create table hep1 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR,  MMWR_DATE_BASIS, symptom_onset_date, deduplication_date, age, DATE_FOR_REPORTING,
input(mmwr_year, 4.) as Year label='Year',
QTR(MMWR_DATE_BASIS) as Quarter
from denorm.case
where mmwr_year in ('2015', '2016', '2017', '2018', '2019', '2020', '2021', '2022', '2023') /*use for NCD3 2.0*/
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("HEPB_C", "HEPB_P")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, MMWR_Year, OWNING_JD;
quit;

data hep1;
set hep1;
Reporting_Date_Type='MMWR Date';
run;


															/*HEP TABLE 2 - SYMPTOM_YEAR*/
proc sql;
create table hep2 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, REPORT_TO_CDC,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',
DATE_FOR_REPORTING, symptom_onset_date, deduplication_date, age,
CALCULATED SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR /*use for NCD3 2.0*/
/*where calculated SYMPTOM_YEAR GE 2022*/ /*use for YTD*/
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("HEPA", "HEPB_A", "HEPC", "HEPB_U")
AND REPORT_TO_CDC = 'Yes'
/*and status = 'closed'*/
order by TYPE_DESC, SYMPTOM_YEAR, OWNING_JD;
quit;

data hep2;
set hep2;
Reporting_Date_Type='Symptom Onset Date';
run;

															/*HEP TABLE 3 - DEDUP_YEAR*/
proc sql;
create table hep3 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, 
YEAR(DEDUPLICATION_DATE) as DEDUP_YEAR label= 'Year of DEDUP',
REPORT_TO_CDC, symptom_onset_date, age, DATE_FOR_REPORTING,
CALCULATED DEDUP_YEAR as Year label='Year',
QTR(DEDUPLICATION_DATE) as Quarter
from denorm.case
where 2015 LE CALCULATED DEDUP_YEAR /*use for NCD3 2.0*/
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("HEPCC")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, dedup_YEAR, OWNING_JD;
quit;

data hep3;
set hep3;
Reporting_Date_Type='Deduplication Date';
run;

/*Combine all hep data sets*/
data hep4;
length Reporting_Date_Type $25;
set hep1 hep2 hep3;
Disease_Group='Hepatitis';
run;


																	/*RESPIRATORY 1*/
proc sql;
create table RESP1 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', 
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', 
symptom_onset_date, age,
CALCULATED SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR 
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("FLU", "FLUD", "FLUDA", "LEG")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, SYMPTOM_YEAR, OWNING_JD;
quit;


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

/*proc sql;*/
/*create table RESP1 as*/
/*select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,*/
/*COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', */
/*age,*/
/*CALCULATED SYMPTOM_YEAR as Year label='Year',*/
/*QTR(symptom_onset_date) as Quarter,*/
/**/
/*EVENT_DATE=SYMPTOM_ONSET_DATE format=MMDDYY10.,*/
/**/
/*case when SYMPTOM_ONSET_DATE = . then SPECIMEN_DATE*/
/*	when SYMPTOM_ONSET_DATE = . and SPECIMEN_DATE = . then DATE_INITIAL_REPORT_TO_PH*/
/*	when SYMPTOM_ONSET_DATE = . and SPECIMEN_DATE = . and EVENT_DATE=DATE_INITIAL_REPORT_TO_PH = . then CREATE_DATE*/
/*	end as EVENT_DATE,*/
/*YEAR=year(EVENT_DATE), MONTH=month(EVENT_DATE),*/
/*from CASE_COMBO*/
/*order by TYPE_DESC, YEAR, OWNING_JD;*/
/*quit;*/


/*proc sql;*/
/*create table Resp as*/
/*select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,*/
/*input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,*/
/*COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', */
/*age,*/
/*QTR(symptom_onset_date) as Quarter,*/
/*case */
/*      when SYMPTOM_ONSET_DATE ne . and Disease_Onset_qualifier="Date symptoms began" then SYMPTOM_ONSET_DATE*/
/*      when (SYMPTOM_ONSET_DATE = . or Disease_onset_qualifier ne "Date symptoms began" ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED*/
/*      when (SYMPTOM_ONSET_DATE = . or Disease_onset_qualifier ne "Date symptoms began" ) and RPTI_SOURCE_DT_SUBMITTED  = . then CREATE_DT*/
/*      else SYMPTOM_ONSET_DATE*/
/*      end as EVENT_DATE format=DATE9., */
/*year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,*/
/*SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE*/
/*from CASE_COMBO*/
/*where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd*/
/*	and STATUS = 'Closed'*/
/*	and STATE in ('NC' ' ')*/
/*order by TYPE_DESC, YEAR, OWNING_JD;*/

proc sql;
create table Resp as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', 
age,
QTR(symptom_onset_date) as Quarter,
case 
    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
	when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
/*      when (SYMPTOM_ONSET_DATE = . or Disease_onset_qualifier ne "Date symptoms began" ) and RPTI_SOURCE_DT_SUBMITTED  = . then CREATE_DT*/
    else CREATE_DT
    end as EVENT_DATE format=DATE9., 
year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,
SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

data resptest;
set resp;
where Year=2022;
run;

proc sql;
create table resptest as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from resp1test
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;

proc sql;
    select sum(Total) as Sum
    from Resp1Test;

data resp1test;
set resp1;
where Year=2022;
run;

proc sql;
create table resp1test as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from resp1test
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;

proc export data=resp1test
    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\Respiratory Cases 2022 on NCD3.xlsx"
    dbms=xlsx
    replace;
    sheet="Respiratory Cases 2022";
run;



/*data resp1;*/
/*set denorm.case_phi(keep=owning_jd type type_desc CLASSIFICATION_CLASSIFICATION CASE_ID MMWR_DATE_BASIS DATE_FOR_REPORTING*/
/*MMWR_YEAR age SYMPTOM_ONSET_DATE);*/
/**/
/*input mmwr_year 4.;*/
/*Case_Ct=COUNT(DISTINCT CASE_ID) label = 'Counts'; */
/*Quarter=QTR(symptom_onset_date);*/
/**/
/*format EVENT_DATE MMDDYY10.;*/
/*EVENT_DATE=SYMPTOM_ONSET_DATE;*/
/**/
/**/
/*if SYMPTOM_ONSET_DATE = . then EVENT_DATE=SPECIMEN_DATE;*/
/*if SYMPTOM_ONSET_DATE = . and SPECIMEN_DATE = . then EVENT_DATE=DATE_INITIAL_REPORT_TO_PH=EVENT_DATE;*/
/*if SYMPTOM_ONSET_DATE = . and SPECIMEN_DATE = . and EVENT_DATE=DATE_INITIAL_REPORT_TO_PH = . then EVENT_DATE=CREATE_DATE;*/
/**/
/*YEAR=year(EVENT_DATE);*/
/*MONTH=month(EVENT_DATE);*/
/*COUNTY=REPORTING_COUNTY;*/
/**/
/*if year(EVENT_DATE) lt year(EVENT_DATE) then delete;*/
/*else if EVENT_DATE gt &END_DATE then delete;*/
/*else if STATE not in ("NC" " ") then delete;*/
/*else if EVENT_STATUS ne "Closed" then delete;*/
/*else EVENT_DATE=SYMPTOM_ONSET_DATE;*/
/**/
/*run;*/

data RESP1;
set RESP1;
Reporting_Date_Type='Symptom Onset Date';
Disease_Group='Respiratory';
run;

																/*RESPIRATORY 2 - TB*/
proc sql;
create table tb as
select
	Year,
	Year as MMWR_YEAR format 4., 
	propcase(county) as OWNING_JD label='County' format=$30. length=30, 
	'TB' as TYPE_DESC,
	COUNT as Case_Ct label = 'Counts',
	COUNT as Confirmed label='Confirmed Count',
	. as Probable label='Probable Count',
	COUNT as Total label='Total'
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
select owning_jd, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, symptom_onset_date, 
year(DEDUPLICATION_DATE) AS DEDUP_YEAR LABEL = 'YEAR OF DEDUPLICATION',
DEDUPLICATION_DATE, age, DATE_FOR_REPORTING,
CALCULATED DEDUP_YEAR as Year label='Year',
QTR(DEDUPLICATION_DATE) as Quarter
from denorm.case
where 2015 LE CALCULATED DEDUP_YEAR 
and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
and type in ("CHLAMYDIA", "GONOR")
AND REPORT_TO_CDC = 'Yes'
ORDER by type_desc, owning_jd, DEDUP_YEAR;
quit;

data cg;
set cg;
Reporting_Date_Type='Deduplication Date';
run;

/*LOW INCIDENCE STDS*/

proc sql;
create table STD as
select owning_jd, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, symptom_onset_date, DEDUPLICATION_DATE, age, DATE_FOR_REPORTING,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset',
CALCULATED SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE CALCULATED SYMPTOM_YEAR /*use for NCD3 2.0*/
/*where CALCULATED SYMPTOM_YEAR LE 2022*/ /*use for YTD*/
and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
and (
	type in  ("GRANUL", "LGRANUL", "NGURETH", "PID")
	or (type = "CHANCROID" and REPORT_TO_CDC = 'Yes')
)
ORDER by type_desc, owning_jd, SYMPTOM_YEAR;
quit;

data STD;
set STD;
Reporting_Date_Type='Symptom Onset Date';
run;

/*SYPHILIS = LHD Diagnosis Date*/

proc sql;
create table syph1 as
select owning_jd, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID, symptom_onset_date,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
year(LHD_DIAGNOSIS_DATE) AS LHD_DX_YR LABEL = 'LHD DX YEAR',
LHD_DIAGNOSIS_DATE, age, DATE_FOR_REPORTING,
CALCULATED LHD_DX_YR as Year label='Year',
QTR(LHD_DIAGNOSIS_DATE) as Quarter
from denorm.case
/*where CALCULATED LHD_DX_YR GE 2022*/ /*use for YTD*/
where 2015 LE CALCULATED LHD_DX_YR /*use for NCD3 2.0*/
and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type like "%SYPH%"
AND TYPE NOT LIKE "CONGSYPH"
AND REPORT_TO_CDC = 'Yes'
ORDER by type_desc, owning_jd, LHD_DIAGNOSIS_DATE;
quit;

data syph1;
set syph1;
Reporting_Date_Type='LHD Diagnosis Date';
run;

proc sql;
create table syph2 as
select owning_jd, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID, symptom_onset_date,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(BIRTH_DATE) as dob label = 'YEAR OF BIRTH', LHD_DIAGNOSIS_DATE, age, DATE_FOR_REPORTING,
CALCULATED DOB as Year label='Year',
QTR(BIRTH_DATE) as Quarter
from denorm.case
where 2015 LE CALCULATED DOB
and CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type like "CONGSYPH"
and REPORT_TO_CDC = 'Yes'
order by type_desc, owning_jd, DOB;
quit;

data syph2;
set syph2;
Reporting_Date_Type='Birth Date';
run;

/*QA*/
/*proc freq data = syph2; tables type_desc*DOB/MISSING NOCOL NOCUM NOPERCENT NOROW; run;
	
/*Combine all SYPHILIS data sets*/
data std_ALL;
set CG STD syph1 syph2;
Disease_Group='Sexually Transmitted';
run;


/*HIV/AIDS; File provided by Jason Maxwell on 7/6/23, analyst for HIV/STD program; jason.maxwell@dhhs.nc.gov*/

/*HIV*/
proc sql;
create table hiv1 as
select *, "HIV" as TYPE_DESC
from hiv;
/*proc transpose data=hiv1 out=hiv1(drop=_name_ rename=(col1=Counts));*/
/*by TYPE_DESC OWNING_JD;*/
/*run;*/
proc sql;
create table hiv1 as
select *, /*Counts,
input(_LABEL_, 4.) as Year,
Counts as Confirmed label='Confirmed Count',*/
Total as Confirmed label='Confirmed Count',
. as Probable label='Probable Count'
/*Counts as Total label='Total'*/
from hiv1;

/*AIDS*/
/*proc sql;*/
/*create table aids1 as*/
/*select *, "AIDS" as TYPE_DESC*/
/*from aids;*/
/*proc transpose data=aids1 out=aids1(drop=_name_ rename=(col1=Counts));*/
/*by TYPE_DESC OWNING_JD;*/
/*run;*/
/*proc sql;*/
/*create table aids1 as*/
/*select TYPE_DESC, OWNING_JD, Counts,*/
/*input(_LABEL_, 4.) as Year,*/
/*Counts as Confirmed label='Confirmed Count',*/
/*. as Probable label='Probable Count',*/
/*Counts as Total label='Total'*/
/*from aids1;*/

/* COMBINE HIV/AIDS DATA*/
data HIV/*AIDS*/;
length TYPE_DESC $4;
set HIV1/* AIDS1*/;
Reporting_Date_Type='Earliest Diagnosis Date';
Disease_Group='Sexually Transmitted';
RUN;


																/*VPD*/
proc sql;
create table VPD as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
YEAR(symptom_onset_date) as SYMPTOM_YEAR label='Year of Onset', symptom_onset_date, age, DATE_FOR_REPORTING,
calculated SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE calculated SYMPTOM_YEAR 
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("DIP", "HFLU", "MEAS", "MENP", "NMEN", "MPOX", "MUMPS", "PERT", "POL", "AFM", "RUB", "RUBCONG", "TET", "VAC", "VARICELLA")
AND REPORT_TO_CDC = 'Yes'
order by TYPE_DESC, OWNING_JD, SYMPTOM_YEAR;
quit;


proc sql;
create table CASE_COMBO as
select s.*, a.State, b.RPTI_SOURCE_DT_SUBMITTED
from DENORM.CASE 
as s left join Denorm.CASE_PHI as a on s.case_id=a.case_id
                              left join Denorm.Admin_question_package_addl as b on s.case_id=b.case_id
where s.CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable")
	and s.type in ("DIP", "HFLU", "MEAS", "MENP", "NMEN", "MPOX", "MUMPS", "PERT", "POL", /*"AFM",*/ "RUB", "RUBCONG", "TET", "VAC", "VARICELLA")
	and s.REPORT_TO_CDC = 'Yes';
quit;

proc sql;
create table VPD as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', age,
QTR(symptom_onset_date) as Quarter,
case 
    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
	when SYMPTOM_ONSET_DATE ne . and /*Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
    else CREATE_DT
    end as EVENT_DATE format=DATE9., 
year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,
SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

data VPDTest;
set VPD;
where Year=2022;
run;
proc sql;
create table VPDTest as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from VPDTest
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;

proc sql;
    select sum(Total) as Sum
    from VPDTest;


data vpd;
set vpd;
Reporting_Date_Type='Symptom Onset Date';
Disease_Group='Vaccine Preventable';
run;

																/*ZOONOTIC*/

proc sql;
create table zoo1 as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date, age, DATE_FOR_REPORTING,
calculated SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from denorm.case
where 2015 LE calculated SYMPTOM_YEAR 
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("ANTH", "ARB", "BRU", "CHIKV", "CJD", "DENGUE", "EHR", "HGE", "EEE", "HME", 
"LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", 
"YF", "ZIKA", "VHF")
AND REPORT_TO_CDC = 'Yes' /*use for YTD*/
order by TYPE_DESC, SYMPTOM_YEAR, MMWR_Year, OWNING_JD;
quit;


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
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS, DATE_FOR_REPORTING,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts', age,
QTR(symptom_onset_date) as Quarter,
case 
    when MMWR_DATE_BASIS ne . then MMWR_DATE_BASIS
	when SYMPTOM_ONSET_DATE ne . /*and Disease_Onset_qualifier="Date symptoms began"*/ then SYMPTOM_ONSET_DATE
    when (SYMPTOM_ONSET_DATE = . /*or Disease_onset_qualifier ne "Date symptoms began"*/ ) and RPTI_SOURCE_DT_SUBMITTED  ne . then RPTI_SOURCE_DT_SUBMITTED
    else CREATE_DT
    end as EVENT_DATE format=DATE9., 
year(calculated EVENT_DATE) as Year, month(calculated EVENT_DATE) as Month,
SYMPTOM_ONSET_DATE, DISEASE_ONSET_QUALIFIER, RPTI_SOURCE_DT_SUBMITTED, CREATE_DT, STATUS, STATE
from CASE_COMBO
where calculated EVENT_DATE >= '01JAN2015'd and calculated EVENT_DATE <= '01JUL2023'd
	and STATUS = 'Closed'
	and STATE in ('NC' ' ')
order by TYPE_DESC, YEAR, OWNING_JD;
quit;

data zooTest;
set zoo;
where Year=2022;
run;
proc sql;
create table zooTest as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from zooTest
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;
proc sql;
    select sum(Total) as Sum
    from zooTest;

data zooTest1;
set zoo1;
where Year=2022;
run;
proc sql;
create table zooTest1 as
select
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease',  
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total
from zooTest1
group by Year, OWNING_JD, TYPE_DESC
order by Year desc, OWNING_JD, TYPE_DESC;


data zoo;
set zoo;
Reporting_Date_Type='Symptom Onset Date';
Disease_Group='Vector-Borne/Zoonotic';
run;

/*QA*/
/*proc freq data = zoo; tables type_desc*SYMPTOM_YEAR/MISSING NOCOL NOCUM NOPERCENT NOROW; RUN;


/*Union all diseases summary in period - add disease group and meta data*/

data final;
length Reporting_Date_Type $25;
length Disease_Group $30;
set ENTERIC HAI3 HEP4 RESP1 std_ALL VPD ZOO;
/*agegroup=put(age, agegrp.);*/
run;

/*Deen added this to group Syphilis before case aggregation*/
data final;
set final;
TYPE_DESC=scan(TYPE_DESC, 1, '(');
if TYPE_DESC='Syphilis - 01. Primary Syphilis' then TYPE_DESC='Syphilis - Primary Syphilis';
	else if TYPE_DESC='Syphilis - 02. Secondary Syphilis' then TYPE_DESC='Syphilis - Secondary Syphilis';
	else if TYPE_DESC='Syphilis - 03. Early, Non-Primary, Non-Secondary Syphilis' then TYPE_DESC='Syphilis - Early, Non-Primary, Non-Secondary Syphilis';
	else if TYPE_DESC='Syphilis - 05. Syphilis Late w/ clinical manifestations' then TYPE_DESC='Syphilis - Late Latent Syphilis';
	else if TYPE_DESC='Syphilis - 05. Unknown Duration or Late Syphilis' then TYPE_DESC='Syphilis - Late Latent Syphilis';
	else if TYPE_DESC='Syphilis - Unknown Syphilis' then TYPE_DESC=' ';
run;

/*proc sort data=final;*/
/*by descending Year OWNING_JD TYPE_DESC CLASSIFICATION_CLASSIFICATION Age CASE_ID;*/
/*run;*/

/*libname interim 'T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\Interim';*/
/*data interim.final; */
/*set final;*/
/*run;*/


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

/*Generate Age Summary (if needed - not required for YTD reporting; used in NCD3 2.0)*/

/*proc sql;*/
/*create table cases_age as*/
/*select type_desc, disease_group, owning_jd, mmwr_year, agegroup, SYMPTOM_YEAR, DOB, LHD_DX_YR, DEDUP_YEAR, count(type_desc) as Count*/
/*from final*/
/*group by type_desc, disease_group, owning_jd, mmwr_year, agegroup*/
/*order by type_desc, disease_group, owning_jd, mmwr_year, agegroup;*/
/*quit;*/

/* Export age summary table*/
/*proc export data=cases_age*/
/*    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\SAS Output\age_summary_ncd3_040123.xlsx"*/
/*    dbms=xlsx*/
/*    replace;*/
/*    sheet="Cases Age Summary";*/
/*run;*/
/*quit;*/

/*Import population file if CRUDE case rates are needed (not required for YTD reporting; used in NCD3 2.0)*/

/*proc import datafile='T:\Respiratory\2019-nCoV\Operations\Surveillance\Reports\Black Caucus\County Population Denominators\2020_Pop\EPI_COVID19_POP2020_VACCINEGROUP_STATE TOTAL.xlsx'*/
/*out=age_pops dbms=xlsx replace; sheet="POP2020_by County"; run;*/
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\County Census Pop_10_22.xlsx'
out=county_pops dbms=xlsx replace; run;

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



/*Join in Population Data; assign age categories ((if needed - not required for YTD reporting; used in NCD3 2.0))*/

/*proc sql;*/
/*create table agegroups as*/
/*select a.*, upcase(tranwrd(a.owning_jd, 'County', '')) as joinwrd,*/
/*	b.age_0_04_pop2020, b.age_05_11_pop2020, b.age_12_17_pop2020, b.age_18_24_pop2020, b.age_25_49_pop2020, b.age_50_64_pop2020, b.age_GE65_pop2020*/
/*from cases_age a*/
/*left join county_pops b*/
/*on upcase(tranwrd(a.owning_jd,'County',''))=b.upper_cnty;*/

/*Calculate Age-Specific Rates*/

/*create table agegroups2 as*/
/*select */
/*	TYPE_DESC,*/
/*	OWNING_JD,*/
/*	MMWR_YEAR,*/
/*	agegroup,*/
/*	Count,*/
/*	case */
/*		when agegroup='0-5' then Count/age_0_04_pop2020 */
/*		when agegroup='5-12' then Count/age_05_11_pop2020 */
/*		when agegroup='12-18' then Count/age_12_17_pop2020 */
/*		when agegroup='18-25' then Count/age_18_24_pop2020 */
/*		when agegroup='25-50' then Count/age_25_49_pop2020 */
/*		when agegroup='50-64' then Count/age_50_64_pop2020 */
/*		when agegroup='65+' then Count/age_GE65_pop2020  else . end as agerate*/
/*from agegroups*/
/*order by type_desc, owning_jd, mmwr_year, agegroup;*/
/*quit;*/

ods listing;
ods results;

proc sql;
create table case_agg_annual as
select
	Year, 
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed label='Confirmed Count',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable label='Probable Count',
	count(distinct CASE_ID) as Total/*,
	agegroup*/
from final
group by Year, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group/*, agegroup*/
order by Year desc, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group/*, agegroup*/;


data case_agg_annual;
set case_agg_annual tb;
County_substr=substr(OWNING_JD, 1, length(OWNING_JD)-7);
run;


proc sql;
create table case_agg_quarter as
select
	Year, Quarter,
	OWNING_JD label='County' format=$30. length=30, 
	TYPE_DESC label='Disease', Reporting_Date_Type, Disease_Group,
	sum(case when CLASSIFICATION_CLASSIFICATION='Confirmed' then 1 else 0 end) as Confirmed_Quarterly label='Confirmed Count Quarterly',
	sum(case when CLASSIFICATION_CLASSIFICATION='Probable' then 1 else 0 end) as Probable_Quarterly label='Probable Count Quarterly',
	count(distinct CASE_ID) as Total_Quarterly,
	substr(OWNING_JD, 1, length(OWNING_JD)-7) as County_substr/*,
	agegroup*/
from final
group by Year, Quarter, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group/*, agegroup*/
order by Year desc, Quarter, OWNING_JD, TYPE_DESC, Reporting_Date_Type, Disease_Group/*, agegroup*/;

data case_agg_quarter;
set case_agg_quarter hiv;
if type_desc='HIV' then County_substr = propcase(OWNING_JD);
run;

/*This section for when including HIV data*/
proc iml;
edit case_agg_quarter;
read all var {County_substr} where(County_substr="Mcdowell");
County_substr = "McDowell";
replace all var {County_substr} where(County_substr="Mcdowell");
close case_agg_quarter;

/*Add rows for when no cases were reported for the county/year/disease*/

proc sort data=county_pops out=unique_counties (keep=COUNTY) nodupkey ;
by COUNTY;
run;

proc sort data=case_agg_quarter out=unique_diseases (keep=TYPE_DESC Reporting_Date_Type Disease_Group) nodupkey ;
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
create table case_agg_quarter as
select coalesce(a.Year,b.Year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.TYPE_DESC,b.TYPE_DESC) as TYPE_DESC,
	coalesce(a.County_substr,b.COUNTY) as County_substr, a.*
from case_agg_quarter a full join unique_table_a b
	on a.year=b.year and a.Quarter=b.Quarter and a.TYPE_DESC=b.TYPE_DESC and a.County_substr=b.COUNTY;

proc sql;
create table case_agg as
select coalesce(a.Year,b.Year) as Year, coalesce(a.County_substr,b.County_substr) as County_substr,
	coalesce(a.TYPE_DESC,b.TYPE_DESC) as DISEASE, coalesce(a.OWNING_JD,b.OWNING_JD) as OWNING_JD,
	coalesce(a.Reporting_Date_Type,b.Reporting_Date_Type) as Reporting_Date_Type,
	coalesce(a.Disease_Group,b.Disease_Group) as Disease_Group, coalesce(a.Confirmed,b.Confirmed_Quarterly) as Confirmed, 
	coalesce(a.Total,b.Total_Quarterly) as Total,
	a.*, b.*
from case_agg_annual a full join case_agg_quarter b
on a.Year=b.Year and a.County_substr=b.County_substr and a.TYPE_DESC=b.TYPE_DESC;

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

proc sort data=case_agg out=unique_diseases (keep=Disease Reporting_Date_Type Disease_Group) nodupkey ;
by Disease;
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
create table unique_table_b as
select unique_counties.*, unique_diseases.Disease, unique_years.* , unique_quarters.*
from unique_counties cross join unique_diseases cross join unique_years cross join unique_quarters;

proc sql;
create table case_rates as
select coalesce(a.Year,b.Year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.Disease,b.Disease) as Disease,
	coalesce(a.County_substr,b.COUNTY) as County_substr, a.*
from case_agg a full join unique_table_b b
	on a.year=b.year and a.Quarter=b.Quarter and a.Disease=b.Disease and a.County_substr=b.COUNTY;

/*Join with county population data*/
proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.County_substr,b.COUNTY) as County_substr, a.*, b.*
from case_rates a left join county_pops b
	on a.Year=b.year and a.County_substr=b.COUNTY;

data case_rates (keep=Year Quarter County_substr Disease Reporting_Date_Type Disease_Group Probable Confirmed Total
Probable_Quarterly Confirmed_Quarterly Total_Quarterly county_pop_adjusted);
set case_rates;
if Disease='Influenza, pediatric death' then county_pop_adjusted=age_0_17;
	else if Disease='Influenza, adult death' then county_pop_adjusted=age_18GE;
	else if Disease='HIV' then county_pop_adjusted=county_pop-age_0_12;
	else county_pop_adjusted=county_pop;
run;


/*Replace missing case totals and incidence with 0*/
data case_rates;
set case_rates;
if missing(Total) then Total=0;
if missing(Total_Quarterly) then Total_Quarterly=0;
County_Incidence_100k=Total/county_pop_adjusted*100000;
County_Incidence_100k_Quarterly=Total_Quarterly/county_pop_adjusted*100000;
format County_Incidence_100k 8.1;
format County_Incidence_100k_Quarterly 8.1;
run;

/*Add disease_groups back*/
proc sql;
create table case_rates as
select coalesce(a.Reporting_Date_Type,b.Reporting_Date_Type) as Reporting_Date_Type,
	coalesce(a.Disease_Group,b.Disease_Group) as Disease_Group, a.*
from case_rates a left join unique_diseases b
on a.Disease=b.Disease;


/*Add state rates*/

proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\State Census Pop_10_22.xlsx'
out=state_pops dbms=xlsx replace; run;

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


proc sort data=case_rates out=case_rates_annual_nodup(keep=Year Disease Confirmed Probable Total County_substr) nodupkey;
by descending Year Disease County_substr;
run;

proc sql;
create table state_rates_annual as
select
	Year, Disease, sum(Total) as Cases_State
from case_rates_annual_nodup
group by Year, Disease
order by Year desc, Disease;


proc sql;
create table state_rates_quarter as
select
	Year, Quarter, Disease, sum(Total_Quarterly) as Cases_State_Quarterly/*, agegroup*/
from case_rates
group by Year, Quarter, Disease/*, agegroup*/
order by Year desc, Quarter, Disease/*, agegroup*/;

proc sql;
create table state_rates as
select a.*, b.*
from state_rates_annual a natural join state_rates_quarter b;

proc sql;
create table case_rates as
select coalesce(a.Year,b.year) as Year, coalesce(a.Quarter,b.Quarter) as Quarter, coalesce(a.Disease,b.Disease) as Disease,
	a.*, b.Cases_State, b.Cases_State_Quarterly
from case_rates a full join state_rates b
	on a.year=b.year and a.Quarter=b.Quarter and a.Disease=b.Disease;

proc sql;
create table case_rates as
select a.*, b.*
from case_rates a left join state_pops b
	on a.Year=b.year;

/*Finalize*/

data case_rates_final (keep=Year Quarter Reporting_Date_Type Disease Disease_Group County_substr Probable Confirmed Total 
	Probable_Quarterly Confirmed_Quarterly Total_Quarterly county_pop_adjusted County_Incidence_100k County_Incidence_100k_Quarterly
	Cases_State Cases_State_Quarterly state_pop_adjusted State_Incidence_100k State_Incidence_100k_Quarterly);
set case_rates;
where Year <=2023;
if (Year=2023 and Quarter=2) or (Year=2023 and Quarter=3) or (Year=2023 and Quarter=4) then delete;
if missing(Cases_State) then Cases_State=0;
	else Cases_State=Cases_State;
if Disease='Influenza, pediatric death' then state_pop_adjusted=age_0_17;
	else if Disease='Influenza, adult death' then state_pop_adjusted=age_18GE;
	else if Disease='HIV' then state_pop_adjusted=total_pop-age_0_12;
	else state_pop_adjusted=total_pop;
if Disease='Botulism - infant' then do;
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		end;
	else if Disease='Hepatitis B - Perinatally Acquired' then do;
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		end;
	else if Disease='Syphilis - 08. Congenital Syphilis' then do;
		Disease='Syphilis - Congenital Syphilis'
		County_Incidence_100k=.;
		State_Incidence_100k=.;
		end;
	else do;
		County_Incidence_100k=County_Incidence_100k;
		County_Incidence_100k_Quarterly=County_Incidence_100k_Quarterly;
		State_Incidence_100k=Cases_State/state_pop_adjusted*100000;
		State_Incidence_100k_Quarterly=Cases_State_Quarterly/state_pop_adjusted*100000;
		end;
format State_Incidence_100k 8.1;
if Disease='Carbapenem-resistant Enterobacteriaceae' then Disease='Carbapenem-resistant Enterobacterales';
	else if Disease='Campylobacter infection' then Disease='Campylobacteriosis';
	else if Disease='Chlamydia' then Disease='Chlamydia trachomatis infection';
	else if Disease='Monkeypox' then Disease='Mpox';
	else Disease=Disease;
run;


proc export data=case_rates_final
    outfile="T:\Tableau\NCD3 2.0\NCD3 2.0 Output\Tableau Data Sources\07-01-23_data_aggregated_quarterly_100523.xlsx"
    dbms=xlsx
    replace;
    sheet="Aggregated Cases by Quarter County";
run;
/*Would like to update the sheet name to 'Quarter' but then Tableau will throw a fit when trying to Edit Connection to the above file*/


/*Save SAS environment*/
options presenv; 

/*Caution: This libref should never point to a storage location containing any other*/
/*data, since prior to storing the SAS WORK datasets and catalogs, SAS will delete*/
/*all of the contents of this library.*/
libname bkuploc 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20230701data_addquarterly';
filename restore 'T:\Tableau\NCD3 2.0\SAS programs\SAS Backups\20230701data_addquarterly\restoration_pgm.sas';
proc presenv
 permdir=bkuploc
 sascode=restore
 show_comments;
 run; 


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
/*	select distinct type_desc*/
/*	from all_diseases*/
/*	order by type_desc;*/
/*quit;*/

/*/*2 proc freq data = all_diseases; tables type_desc; run;*/
/*/*3 proc contents data = all_diseases; run;*/


/*Add Metadata to Summary Table (if needed - not required for YTD reporting; used in NCD3 2.0)*/

proc sql;
create table ncd3output as
select a.*, 
	b.type_desc_clean,
	b.Disease,
	b.Nickname,
	b.Disease_Group,
	b._Incidence_Calculation,
	b.Case_Table_Variable,
	b.Counted_By,
	b.Number_of_Days_to_Report
from final a
left join dgrps b
on a.type_desc=b.type_desc
having MMWR_YEAR NE ''
order by b.Disease_Group, b.disease, a.OWNING_JD, a.MMWR_YEAR;

/* Join final output to be stratified by NCALHD Region*/
proc sql;
create table ncd3outputreg as
select a.*, 
	b.*
from ncd3output a
join regions b
on a.owning_jd=b.county
having MMWR_YEAR NE ''
order by b.county, a.OWNING_JD, a.MMWR_YEAR;


/*Check to see that metadata is associated with each disease*/
create table nodisease as
select distinct type_desc
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
