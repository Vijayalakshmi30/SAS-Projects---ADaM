/*log file*/
proc printto log='/home/u63774111/Project/Log files/adex.log';

libname sasval "/home/u63774111/Project/Project_2/xpt_sas_val"; 
libname val xport "/home/u63774111/Project/Project_2/Validation/ADEX.xpt" access=readonly; 
proc copy inlib=val outlib=sasval; 
run; 

libname adinput "/home/u63774111/Project/Project_2/ADinput";

*** 1. Variables from ADSL dataset ***;

data frm_adsl(keep=SUBJID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC RANDDT REMISS REMISSN ITTFL SAFFL EFFL CA125FL TRTDCFL
                   COMPLFL STDDCFL SFUDCFL SFUFL TRTSDT TRTEDT FPDUR STUDYID USUBJID SITEID INVNAM INVID COUNTRY TRT01P TRT01PN
                   TRT01A TRT01AN);
set sasval.adsl;
run;

*** 2. Duration (months) treatment received ***;

data txdur;
length PARAM $40;
set frm_adsl;
PARAM='Duration of Treatment Received (months)';
PARAMCD='TXDUR';
if TRTSDT^=. then AVAL=((TRTEDT-TRTSDT)+1)/30.4375;
DTYPE='DIFFERENCE';
run;

*** 3. Total Number of 150mg capsules taken ***;

* 3.1 Sorting DA dataset with few conditions *;
proc sort data=adinput.da out=da nodupkey;
by USUBJID DARFTDTC DADTC DATESTCD DAORRES;
run;

* 3.2 Derive total number of capsules taken per subject for AVAL*;
proc means data=da sum;
by USUBJID;
var DASTRESN;
where DATESTCD='TAKENAMT';
output out=total_capsules (drop=_TYPE_ _FREQ_) sum=AVAL;
run;

data cumcap_;
set total_capsules;
run;

* 3.3 Merging cumcap_ and frm_adsl *;
data cumcap;
length PARAM $40;
merge frm_adsl cumcap_;
PARAM='Total Number of 150mg Capsules Taken';
PARAMCD='CUMCAP';
DTYPE='SUM';
run;

*** 4. Total Cumulative Dose (g) ***;

data cumdose;
length PARAM $40;
merge frm_adsl cumcap_;
PARAM='Total Cumulative Dose (g)';
PARAMCD='CUMDOSE';
AVAL=(AVAL*150)/1000;
DTYPE='SUM';
run;

*** 5. Dose Intensity ***;

* 5.1 Parameters required for AVAL *;
data intens_(keep=USUBJID AVAL);
merge frm_adsl cumcap_;
by USUBJID;
tot_num= AVAL;
days=(TRTEDT-TRTSDT)+1;
AVAL=(tot_num/days)*100;
run;

* 5.2 Creating intens data *;
data intens;
length PARAM $40;
merge frm_adsl intens_;
PARAM='Dose Intensity (%)';
PARAMCD='INTENS';
DTYPE='PERCENTAGE';
run;

*** 6. Concatenating txdur cumcap cumdose intens ***;
data adex;
length PARAM DTYPE $40 PARAMCD $8;
retain SUBJID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC RANDDT REMISS REMISSN ITTFL SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL SFUDCFL 
       SFUFL TRTSDT TRTEDT FPDUR PARAM PARAMCD AVAL DTYPE STUDYID USUBJID SITEID INVNAM INVID COUNTRY TRT01P TRT01PN TRT01A TRT01AN
       TRTP;
label PARAM='Analysis Parameter Description'
      PARAMCD='Analysis Parameter Short Name'
      AVAL='Analysis Value'
      DTYPE='Derivation Type'
      TRTP='Planned Treatment (Record Level)';
set txdur cumcap cumdose intens;
TRTP=TRT01P;
run;

libname mysdtm '/home/u63774111/Project/Output';

proc sort data=adex out=mysdtm.adex;
by studyid usubjid subjid paramcd;
run;

proc contents data=mysdtm.adex varnum;
run;