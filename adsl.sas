/*log file*/
proc printto log='/home/u63774111/Project/Log files/adsl.log';

/*Retrieving DM dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/DM.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run; 


proc format;
value agegrp
      18-<41='18 - 40'
      41-<65='41 - 64'
      65-high='>= 65'
      other='missing';
value agegrpn
      18-<41='1'
      41-<65='2'
      65-high='3'
      other='missing';
run;


data data1;
retain STUDYID USUBJID SUBJID SITEID INVNAM INVID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC COUNTRY ARM ARMCD TRT01P TRT01PN;
label STUDYID='Study Identifier'
      USUBJID='Unique Subject Identifier'
      SUBJID='Subject Identifier for the Study'
      SITEID='Study Site Identifier'
      INVNAM='Investigator Name'
      INVID='Investigator Identifier'
      AGE='Age'
      AGEU='Age Units'
      AGEGR1='Age Group 1 (Char)'
      AGEGR1N='Age Group 1 (Num)'
      SEX='Sex'
      RACE='Race'
      ETHNIC='Ethnicity'
      COUNTRY='Country'
      ARM='Description of Planned Arm'
      ARMCD='Planned Arm Code'
      TRT01P='Planned Treatment'
      TRT01PN='Planned Treatment Number';
length AGEGR1 $8 TRT01P $10;
set adinput.dm;
AGEGR1=put(AGE,agegrp.);
AGEGR1N=input(put(AGE,agegrpn.),best.);
if upcase(ARM)='CMP-135' then do;
   TRT01P='CMP-135';
   TRT01PN=1;
   END;
else if upcase(ARM)='PLACEBO' then do;
   TRT01P='Placebo';
   TRT01PN=0;
   END;
run;


/*==================================================*/

/*Retrieving EX dataset for TRT01A and TRT01AN*/
/*============================================*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/EX.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run; 


proc sort data=adinput.ex(keep=USUBJID EXTRT EXSTDTC) out=sort_ex;
by USUBJID EXTRT EXSTDTC;
run;


data data2;
set sort_ex;
by USUBJID EXTRT EXSTDTC;

length TRT01A $10;
retain TRT01A TRT01AN;

/*for first EXTRT of each USUBJID*/
if first.USUBJID then do;
   temptrt=upcase(left(strip(extrt)));
   if upcase(left(strip(EXTRT)))='CMP-135' then do;
      trt01a='CMP-135';
      trt01an=1;
      end;
   else if upcase(left(strip(EXTRT)))='PLACEBO' then do;
      trt01a='Placebo';
      trt01an=0;
      end;
      else put "AL" "ERT: Invalid value of EXTRT. USUBJID=" USUBJID ",EXTRT=" EXTRT;
   end; 
   
/*After first treatment*/
else do;
     /*Ensure subjects get same treatments (CMP-135 or PLACEBO) throughout the study*/
     if upcase(TRT01A) NE upcase(left(strip(EXTRT))) then
        put "AL" "ERT: Subject with mixed treatments. USUBJID=" usubjid ", 1st trt=" trt01a ", add'l trt=" extrt ", add'l trt date=" exstdtc; 
   end;
   
/*If a subject got both CMP-135 snd PLACEBO then assign to CMP135*/
if first.USUBJID;
run;


/*Merging data1 and data2*/
proc sort data=data1 out=sort_data1;
by USUBJID;
run;

proc sort data=data2 out=sort_data2;
by USUBJID;
run;

data trt;
retain STUDYID USUBJID SUBJID SITEID INVNAM INVID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC COUNTRY ARM ARMCD TRT01P TRT01PN TRT01A TRT01AN;
label TRT01A='Actual Treatment'
      TRT01AN='Actual Treatment Number';
merge sort_data1 sort_data2;
by USUBJID;
run; 

/*Getting RANDDT for ITTFL */

/*Retrieving DS dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/DS.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

/*DTHDT DTHFL DTHDCRS*/
data dth(keep=USUBJID DSSTDTC DTHDT DTHFL DTHPER DTHDCRS);
label DTHDT='Date of Death'
      DTHFL='Death Population Flag'
      DTHPER='Death Time Period'
      dthdcrs='Death Reason';
length DTHPER $30 DTHDCRS $80;
set adinput.ds;
format DTHDT IS8601DA.;
if (DSCAT='OTHER EVENT') and DSSCAT='DEATH';
if EPOCH in ('STUDY PERIOD','SURVIVAL FOLLOW-UP');
DTHDT=input(DSSTDTC,IS8601DA.);
if DTHDT>0 then DTHFL='Y';
if EPOCH='STUDY PERIOD' then DTHPER='STUDY PERIOD';
else if EPOCH='SURVIVAL FOLLOW-UP' then DTHPER='SURVIVAL FOLLOW-UP PERIOD';
DTHDCRS=DSTERM;
run;


***Study Start date/randomization date***;
data data3(keep=USUBJID STDSDT STDSDTC RANDDT DSSTDTC DSDECOD);
label STDSDT='Study Start Date (Num)'
      STDSDTC='Study Start Date (Char)'
      RANDDT='Randomization Date';
set adinput.ds;
if DSCAT='PROTOCOL MILESTONE' and EPOCH='SCREENING' and DSTERM='RANDOMIZATION' then do;
   length STDSDTC $20;
   format RANDDT STDSDT IS8601DA.;
   STDSDT = input(strip(scan(DSSTDTC,1,'T')), IS8601DA.);
   STDSDTC = strip(DSSTDTC);
   RANDDT = STDSDT;
   end;
if STDSDT^=.;
run;

/*Merging trt dth and data3*/
data data4;
label ITTFL='Intent-To-Treat Population Flag';
merge trt(in=a) dth data3;
by USUBJID;
if a;
if RANDDT>0 then ITTFL='Y';
else ITTFL='N';
run;

/*Getting TRTSDTC and TRTSDT for SAFFL*/
/*Retrieving da dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/DA.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;


/*TRTSDTC and TRTSDT*/
data data5(keep=USUBJID TRTSDTC TRTSDT);
label TRTSDT='First Treatment Date (num)';
format TRTSDT IS8601DA.;
attrib TRTSDTC label='First Treatment Date (char)' length=$20;
set adinput.da;
where DARFTDTC ^='' and DASTRESN>0;
TRTSDTC=strip(DARFTDTC);
if TRTSDTC ^='' then TRTSDT=input(TRTSDTC, IS8601DA.);
run;

/*Getting first treatment date*/
proc sort data=data5 out=sort_data5;
by USUBJID TRTSDT;
run;

data first_trt;
set sort_data5;
if first.USUBJID;
by USUBJID TRTSDT;
run;

/*Merging data4 and first_trt for TRTSDTC TRTSDT SAFFL*/
data data6;
label SAFFL='Safety Population Flag';
merge data4(in=a) first_trt;
if a;
if TRTSDT>0 then SAFFL='Y';
else SAFFL='N';
run;


/*Getting REMISSN from ZH for EFFL and RSP125 for CA125FL*/
/*Retrieving ZH dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/ZH.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

proc transpose data=adinput.zh out=zh;
by USUBJID;
var ZHORRES;
id ZHTESTCD;
run;

data zh(keep=USUBJID REMISS REMISSN RSP125 HPATHTYP HSUBTYP);
label REMISS='Current Remission Status (Char)'
      REMISSN='Current Remission Status (Num)'
      RSP125='CA-125 Responder Flag'
      HPATHTYP='Histopathologic Type'
      HSUBTYP='Histologic Subtype';
length REMISS HPATHTYP HSUBTYP $40;
set zh(rename=DXRMS=REMISS);
if REMISS='SECOND COMPLETE REMISSION' then REMISSN=1;
else if REMISS='THIRD COMPLETE REMISSION' then REMISSN=2;
else REMISSN=.;
if RSP125YN='Y' then RSP125='Y';
else RSP125='N';
run;

/*Combining tu dataset with zh(data7) for EFFL*/
/*Retrieving TU dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/TU.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data tu(keep=USUBJID VISITNUM TUSPID TUORRES);
set adinput.tu;
if VISITNUM>1 and TUSPID='CTSA';
if TUORRES ^='';
run;

proc sort data=tu out=sort_tu nodupkey;
by USUBJID;
run;

/*Merging data6 zh tu for EFFL*/
data data7;
merge data6(in=a) zh sort_tu(in=b);
by USUBJID;
if a;
***Efficacy population flag***;
if (b and remissn>0 and saffl='Y') then EFFL='Y';
else EFFL='N';
run;

proc freq data=data7;
tables EFFL;
run;

/*TRTDCRS*/
data data8(keep=USUBJID TRTDCRS);
label TRTDCRS='Treatment Discontinuation Reason';
length TRTDCRS $80;
set adinput.ds;
***Treatment Discontinuation***;
if DSCAT='DISPOSITION EVENT' and EPOCH='STUDY PERIOD'
   and (index(upcase(DSSCAT),'CMP-135') or index(upcase(DSSCAT),'PLACEBO')) then do;
   TRTDCRS=strip(DSDECOD);
   end;
if TRTDCRS^='';
run;   

/*Merge data7 and data8 and named it as merge_78*/
data merge78;
merge data7(in=a) data8;
by USUBJID;
run;


/*STDEDTC STDEDT STDDCRS*/
***Treatment Discontinuation***;
proc sort data=adinput.ds out=sort_ds;
by USUBJID DSSTDTC;
run;

data std(keep=USUBJID STDEDTC STDEDT STDDCRS);
label STDEDTC='Study End Date (Char)'
      STDEDT='Study End Date (Num)'
      STDDCRS='Study Period Discontinuation Reason';
length STDEDTC $20 length STDDCRS $80;
format STDEDT IS8601DA.;
set sort_ds;
***Study discontinuation date and reason***;
if (DSCAT='DISPOSITION EVENT') and (DSSCAT='STUDY PERIOD') 
    and (EPOCH='STUDY PERIOD');
STDEDT=input(strip(scan(DSSTDTC,1,'T')), IS8601DA.);
STDEDTC=DSSTDTC;
STDDCRS=strip(DSDECOD);
run;

/*Merging merge78 and std name it as mergestd*/
data mergestd;
merge merge78(in=a) std;
by USUBJID;
run;

/*TRTDCFL, COMPLFL and CA125FL*/

data data8;
label EFFL='Efficacy-Evaluable Population Flag'
      CA125FL='Efficacy-Evaluable CA125 Population Flag'
      TRTDCFL='Treatment Discontinuation Flag';
set mergestd;
if (SAFFL='Y') and (RSP125='Y') then CA125FL='Y';
else CA125FL='N';
***Discontinuation Population Flag***;
if TRTDCRS^='' then TRTDCFL='Y';
else TRTDCFL='N';
if STDEDT>0 and upcase(strip(STDDCRS)) in ('PROGRESSIVE DISEASE','DEATH') then COMPLFL='Y';
else COMPLFL='N';
run;

proc freq data=data8;
tables EFFL;
run;

/*COMPFL*/
data data9(keep=USUBJID COMPLFL);
label COMPLFL='Study Period Completers Flag';
set adinput.ds;
format STDEDT IS8601DA.;
if (DSCAT='DISPOSITION EVENT') and DSSCAT='STUDY PERIOD';
if(EPOCH='STUDY PERIOD') and DSTERM in ('DEATH','DISEASE PROGRESSION - RADIOGRAPHIC');
COMPLFL='Y';
run;

/*STDDCFL*/
data data10(keep=USUBJID STDDCFL);
label STDDCFL='Study Period Discontinuation Flag';
set adinput.ds;
if (DSCAT='DISPOSITION EVENT') and DSSCAT='STUDY PERIOD';
if(EPOCH='STUDY PERIOD') and DSTERM ^= '';
STDDCFL='Y';
run;

/*SFUDCFL*/
data data11(keep=USUBJID SFUDCFL);
label SFUDCFL='Follow-Up Period Discontinuation Flag';
set adinput.ds;
if (DSCAT='DISPOSITION EVENT') and DSSCAT='FOLLOW-UP';
if(EPOCH='SURVIVAL FOLLOW-UP') and DSTERM ^= '';
SFUDCFL='Y';
run;

data data12;
merge data8(in=a) data9 data10 data11;
by USUBJID;
if a;
run;


/*SFUFL*/
***Derive survival follow-up entry flag (SFUFL)***;

/*Retrieving suppds dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/SUPPDS.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data ds_sfufl(keep=USUBJID SFUFL);
rename QVAL=SFUFL; 
set adinput.suppds;
where QNAM='DSFUYN';
run;

proc sort data=ds_sfufl nodupkey;
by USUBJID;
run;

/*Merging data12 and ds_sfufl*/
data data13;
label SFUFL='Survival Follow-Up Period Entry Flag';
length SFUFL $1;
merge data12(in=a) ds_sfufl;
by USUBJID;
run;

/*TRTEDTC TRTEDT*/
/*Retrieving DA dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/DA.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data da(keep= USUBJID TRTEDTC TRTEDT);
set adinput.da;
label TRTEDT='Last Treatment Date (num)';
format TRTEDT IS8601DA.;
TRTEDTC=strip(DADTC);
if TRTEDTC^='' then TRTEDT=input(TRTEDTC, IS8601DA.);
if DADTC ^='' and DASTRESN>0;
run;

proc sort data=da;
by USUBJID descending TRTEDTC;
run;

data data14;
attrib TRTEDTC label='Last Treatment Date (char)' length=$20;
set da;
if first.USUBJID;
by USUBJID descending TRTEDTC;
run;

/*Merging data13 and data14*/
data data15;
merge data13(in=a) data14;
by USUBJID;
if a;
run;

proc freq data=merge78;
tables EFFL;
run;

/*TRTDCDT TRTDCDTC*/
data data16(keep=USUBJID TRTDCDT TRTDCDTC);
label TRTDCDT='Treatment Discontinuation Date';
set adinput.ds;
***Treatment Discontinuation***;
if DSCAT='DISPOSITION EVENT' and EPOCH='STUDY PERIOD'
   and (index(upcase(DSSCAT),'CMP-135') or index(upcase(DSSCAT),'PLACEBO')) then do;
   length TRTDCRS $80;
   format TRTDCDT IS8601DA.;
   if DSDTC^='' then do;
   TRTDCDT=input(strip(scan(DSDTC,1,'T')), IS8601DA.);
   TRTDCDTC=DSDTC;
   end;
end;
if TRTDCDT^=.;
run;   

data data17;
merge data15(in=a) data16;
by USUBJID;
run;


/*SFUEDTC*/
data sfu_end(keep=USUBJID SFUEDTC SFUEDT);
label SFUEDT='Survival Follow-Up End Date (Num)'
      SFUEDTC='Survival Follow-Up End Date (Char)';
length SFUEDTC $20;
format SFUEDT IS8601DA.;
set sort_ds;
if (DSCAT='DISPOSITION EVENT') and DSSCAT='FOLLOW-UP';
if(EPOCH='SURVIVAL FOLLOW-UP') and DSTERM ^= '';
SFUEDTC=DSSTDTC;
SFUEDT=input(strip(scan(DSSTDTC,1,'T')), IS8601DA.);
run;

data data18;
merge data17(in=a) sfu_end;
by USUBJID;
if a;
run;

/*PRTXDTC PRTXDT*/
***Latest prior cancer surgery date per subject***;

***Prior cancer surgery***;
/*Retrieving YP dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/YP.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data surgery(keep=USUBJID YPENDTC PRSURGFL);
length YPENDTC $10;
set adinput.yp;
if YPCAT = 'PRIOR CANCER-RELATED SURGERY OR PROCEDURE';
run;

proc sort data=surgery out=surgery(rename=(YPENDTC=PRTXDTC));
by USUBJID;
run;

***Prior Radiotherapy***;
/*Retrieving XR dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/XR.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;


data radiotx(keep=USUBJID XRENDTC);
length XRENDTC $10;
set adinput.xr;
if XROCCUR='Y';
run;

proc sort data=radiotx out=radiotx(rename=(XRENDTC=PRTXDTC));
by USUBJID;
run;

***Prior cancer systemic therapy***;
/*Retrieving CM dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/CM.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;


data systemtx(keep=USUBJID CMENDTC);
length CMENDTC $10;
set adinput.cm;
if CMCAT='PRIOR CANCER THERAPY';
run;

proc sort data=systemtx out=systemtx(rename=(CMENDTC=PRTXDTC));
by USUBJID;
run;

/*Concatenating surgery radiotx systemtx*/
data prtx;
set surgery radiotx systemtx;
format PRTXDT IS8601DA.;
label PRTXDT='Last Prior Cancer Treatment Date';
if PRTXDTC ^='' then do;
   if length(strip(PRTXDTC))=10 then PRTXDT=input(PRTXDTC, IS8601DA.);
   ***Impute partial dates to June-15***;
   else if length(strip(PRTXDTC))=7 then PRTXDT=input(strip(PRTXDTC)||'-06',IS8601DA.);
   else if length(strip(PRTXDTC))=4 then PRTXDT=input(strip(PRTXDTC)||'-06-15',IS8601DA.);
   end;
run;

proc sort data=prtx out=prtx2;
    by USUBJID descending PRTXDTC;
run;

data prtx2;
    set prtx2;
    by USUBJID;
    if first.USUBJID then output;
run;

/*Merging prtx2 and data18*/
data data19;
merge data18(in=a) prtx2;
by USUBJID;
if a;
run;


/*PRSURGFL*/
data prsurgfl(keep=USUBJID PRSURGFL);
label PRSURGFL='Prior Cancer Surgery Flag';
set surgery;
PRSURGFL='Y';
run;

proc sort data=prsurgfl noduprecs;
by USUBJID;
run;


/*PRRADFL*/ 
data prradfl(keep=USUBJID PRRADFL);
label PRRADFL='Prior Cancer Radiotherapy Flag';
set radiotx;
PRRADFL='Y';
run;

proc sort data=prradfl noduprecs;
by USUBJID;
run;


/*PRSYSFL*/
data prsysfl(keep=USUBJID PRSYSFL);
label PRSYSFL='Prior Cancer Systemic Therapy Flag';
set systemtx;
PRSYSFL='Y';
run;

proc sort data=prsysfl noduprecs;
by USUBJID;
run;


/*Merging data19 psurgfl prradfl prsysfl*/
data data20;
merge data19(in=a) prsurgfl prradfl prsysfl;
by USUBJID;
run;

/*BWT BHT*/
***Baseline Characteristics from VS (BWT BHT)***;

/*Retrieving VS dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/VS.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data vs(keep=USUBJID VSTESTCD VSSTRESN VSBLFL VSDTC VISITNUM VISIT);
set adinput.vs;
where VSTESTCD in ('HEIGHT','WEIGHT')
      and VISITNUM in (1,2)
      and VSSTRESN>0
      and VSDTC^='';
run;

proc sort data=vs;
by USUBJID VSTESTCD VISITNUM VSDTC;
run;

data vs1(keep=USUBJID BHT VISITNUM);
set vs(where=(VSTESTCD='HEIGHT'));
by USUBJID VSTESTCD VISITNUM VSDTC;
if VISITNUM=1; *Height only collected at Screening visit*;
BHT=VSSTRESN;
if last.USUBJID;
run;

data vs2(keep=USUBJID BWT VISITNUM);
set vs(where=(VSTESTCD='WEIGHT'));
by USUBJID VSTESTCD VISITNUM VSDTC;
BWT=VSSTRESN;
if last.USUBJID;
run;

/*BECOG*/
/*Retrieving QS dataset*/
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/QS.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run;

data qs(keep=USUBJID VISIT VISITNUM QSSTRESN);
set adinput.qs;
if (strip(upcase(QSTESTCD))='ECOG') and (VISITNUM IN (1,2)) 
   and (QSSTRESN>=0);
run;

proc sort data=qs;
by USUBJID VISITNUM;
run;

data qs(keep=USUBJID BECOG);
label BECOG='Baseline ECOG Score';
set qs;
by USUBJID VISITNUM;
if last.USUBJID;
BECOG=QSSTRESN;
run;

/*Merging data20 vs1 vs2 BECOG*/
data data21;
label BHT='Baseline Height (cm)'
      BWT='Baseline Weight (kg)';
merge data20(in=a) vs1 vs2 qs;
by USUBJID;
if a;
run;

/*TRTDUR STDDUR FPDUR PRTXDUR*/
libname mysdtm '/home/u63774111/Project/Output';


data mysdtm.adsl;
retain STUDYID USUBJID SUBJID SITEID INVNAM INVID AGE AGEU AGEGR1 AGEGR1N 
       SEX RACE ETHNIC COUNTRY ARM ARMCD TRT01P TRT01PN TRT01A TRT01AN ITTFL
       SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL SFUDCFL SFUFL DTHFL RANDDT 
       TRTSDTC TRTSDT TRTEDTC TRTEDT TRTDCDT STDSDTC STDSDT STDEDTC STDEDT 
       SFUEDTC SFUEDT DTHDT TRTDUR STDDUR FPDUR DTHPER TRTDCRS STDDCRS
       DTHDCRS PRTXDT PRTXDUR PRSURGFL PRRADFL PRSYSFL BWT BHT BECOG REMISS 
       REMISSN RSP125 HPATHTYP HSUBTYP;
keep STUDYID USUBJID SUBJID SITEID INVNAM INVID AGE AGEU AGEGR1 AGEGR1N 
       SEX RACE ETHNIC COUNTRY ARM ARMCD TRT01P TRT01PN TRT01A TRT01AN ITTFL
       SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL SFUDCFL SFUFL DTHFL RANDDT 
       TRTSDTC TRTSDT TRTEDTC TRTEDT TRTDCDT STDSDTC STDSDT STDEDTC STDEDT 
       SFUEDTC SFUEDT DTHDT TRTDUR STDDUR FPDUR DTHPER TRTDCRS STDDCRS
       DTHDCRS PRTXDT PRTXDUR PRSURGFL PRRADFL PRSYSFL BWT BHT BECOG REMISS 
       REMISSN RSP125 HPATHTYP HSUBTYP; 
label TRTDUR=' Duration of Treatment (Days)'
      STDDUR='Duration of Study Period (Days)'
      FPDUR='Safety Follow-Up Duration (Days)'
      PRTXDUR='Weeks Since Last Prior Cancer TX';
length TRTDCRS $80;
set data21;
if SFUDCFL='' then SFUDCFL='N';
if PRRADFL='' then PRRADFL='N';
if TRTEDT>=TRTSDT then TRTDUR=(TRTEDT-TRTSDT+1);
else TRTDUR=.;
if (STDSDT^=.) or (STDEDT^=.) then do; 
   if STDEDT>=STDSDT then STDDUR=(STDEDT-STDSDT+1);
   else STDDUR=.;
   end;
***Safety Follow-Up Duration for ISS***;
_fpdate=max(STDEDT,SFUEDT);
if TRTSDT*_fpdate>0 then FPDUR=(_fpdate-TRTSDT+1);
***Weeks since last cancer treatment***;
if nmiss(RANDDT, PRTXDT)=0 then PRTXDUR=(RANDDT-PRTXDT+1)/7;
run;

proc contents data=mysdtm.adsl varnum;
run;















