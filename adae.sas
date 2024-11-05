/*log file*/
proc printto log='/home/u63774111/Project/Log files/adae.log';

libname sasval "/home/u63774111/Project/Project_2/xpt_sas_val"; 

data frm_adsl;
    length SUBJID $10 SITEID $20;
    set sasval.adsl;
    keep STUDYID USUBJID SUBJID SITEID TRT01P TRT01PN TRT01A TRT01AN
         REMISS REMISSN ITTFL SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL
         SFUDCFL SFUFL TRTSDT TRTSDTC TRTEDT TRTEDTC INVNAM INVID AGE
         AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC COUNTRY RANDDT;
    label STUDYID='Study ID'
          REMISS='Current Remission Status (char)'
          ITTFL='Intent-to-Treat Population Flag'
          STDDCFL='Study Period Discontiuation Flag'
          TRTSDT='First Treatment (GDC) Date (num)'
          TRTSDTC='First Treatment (GDC) Date (char)'
          TRTEDT='Last Treatment (GDC) Date (num)'
          TRTEDTC='Last Treatment (GDC) Date (char)';
run;

*Retrieving AE dataset*;
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/AE.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run; 

data frm_ae;
length AETERM AEMODIFY AEDECOD AEBODSYS AETRTOTH $200 AESTDTC AEENDTC AEACN AESDISAB AESCONG AEDTHDTC AESMIE $20 DTHAUTYN $2 AESHOSP $3;
set adinput.ae;
rename DOMAIN=SRCDOM
       AESEQ=SRCSEQ;
keep USUBJID DOMAIN AESEQ AETERM AEMODIFY AEDECOD AEBODSYS AESTDTC AESTRTPT AEENDTC
     AEENRTPT AESDT AEEDT AESER AEREL AETOXGR AETOXGRN AEACN AETRTOTH AESDTH
     AEDTHDTC DTHAUTYN AESLIFE AESHOSP AESDISAB AESCONG AESMIE AERELNST;
label DOMAIN='Source Domain'
      AESEQ='Source Sequence Number'
      AESDT='AE Start Date'
      AEEDT='AE End Date'
      AETOXGRN='Standard Toxicity Grade (num)'
      AETRTOTH='Treatment for AE'
      AEDTHDTC='Death Date'
      DTHAUTYN='Was Autopsy Performed';
format AESDT AEEDT IS8601DA.;
*AESDT*;
if length(strip(substr(AESTDTC,1,10)))=10 then AESDT=input(substr(AESTDTC,1,10), IS8601DA.);
else AESDT=.;
*AEEDT*;
if length(strip(substr(AEENDTC,1,10)))=10 then AEEDT=input(substr(AEENDTC,1,10),IS8601DA.);
else AEEDT=.;
*AETOXGRN*;
AETOXGRN=input(AETOXGR, 8.);
*AETRTOTH*;
if AEACNOTH^='MULTIPLE' and AECONTRT='N' then AETRTOTH=AEACNOTH;
else if AEACNOTH in ('NONE','') and AECONTRT='Y' then AETRTOTH='MEDICATION';
else if AEACNOTH ^in ('MULTIPLE','NONE','') and AECONTRT='Y' then AETRTOTH=strip(AEACNOTH)||'; MEDICATION';
*AEDTHDTC and DTHAUTYN*;
if AESDTH='N' then do;
   AEDTHDTC='';
   DTHAUTYN='';
   end;
run;

*Merging frm_adsl and frm_ae*;
proc sort data=frm_adsl;
by USUBJID;
run;

proc sort data=frm_ae;
by USUBJID;
run;

data data1;
label AESDY='Relative Start Day of AE'
      TRTEM='Treatment Emergent';
merge frm_adsl(in=a) frm_ae(in=b);
by USUBJID;
if b;
if AESDT>=TRTSDT then AESDY=AESDT-TRTSDT+1;
else if .<AESDT<TRTSDT then AESDY=AESDT-TRTSDT;
*Treatment Emergent - TRTEM*;
*(1) For complete AE start date*;
if AESDT>0 and TRTSDT>. and AESDT<TRTSDT then TRTEM='N';
*(2) For a partial AE start date (AESTDTC)*;
if AESDT=. then do;
*(a) missing start day*;
if length(compress(AESTDTC,'-'))=6 then do;
   missday=compress(AESTDTC,'-');
   trtday=compress(substr(TRTSDTC,1,7),'-');
   if missday<trtday then TRTEM='N';
   end;
*(b) if month is missing*;
if length(compress(AESTDTC,'-'))=4 then do;
   missyear=AESTDTC;
   trtyear=substr(TRTSDTC,1,4);
   if missyear<trtyear then TRTEM='N';
   end;
end;
if TRTEM^='N' then TRTEM='Y';
run;

/*AEHLGT*/

*Retrieving SUPPAE dataset*;
libname adinput "/home/u63774111/Project/Project_2/ADinput"; 
libname stdmad xport "/home/u63774111/Project/Project_2/SDTM/SUPPAE.xpt" access=readonly; 
proc copy inlib=stdmad outlib=adinput; 
run; 

proc sort data=adinput.suppae out=sorted_suppae;
by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL;
run;

proc transpose data=sorted_suppae out=transposed_suppae(drop=_NAME_);
    by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL;
    id QNAM;
    var QVAL;
run;

data frm_suppae;
    length AEHLGT AEHLT AELLT $200 AELLTCD $8 AEHDTC $20;
    label AEHLGT='High Level Group Term'
          AEHLT='High Level Term'
          AELLT='Low Level Term'
          AELLTCD='Low Level Term Code'
          AEHDTC='Hospitalization Admission Date';
    set transposed_suppae;
    rename RDOMAIN=SRCDOM 
           CHAR_IDVARVAL_num=SRCSEQ;
    keep STUDYID RDOMAIN USUBJID CHAR_IDVARVAL_num AEHLGT AEHLT AELLT AELLTCD AEHDTC AERELNS1 AERELNS2;
    CHAR_IDVARVAL_num = input(IDVARVAL, best.);
run;

*Merging data1 and frm_suppae*;
proc sort data=frm_suppae;
by STUDYID SRCDOM USUBJID SRCSEQ;
run;

data data2;
merge data1(in=a) frm_suppae(in=b);
by STUDYID SRCDOM USUBJID SRCSEQ;
if a;
run; 

*Create variable AERELOTH after merging ae and suppae which is data2*;

/*Final ADAE dataset*/
libname mysdtm '/home/u63774111/Project/Output';

data mysdtm.adae;
    length AERELOTH $200;
    label AERELOTH='Relationship to Non-Study Treatment';
    retain STUDYID USUBJID SUBJID SITEID TRT01P TRT01PN TRT01A TRT01AN 
           REMISS REMISSN ITTFL SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL
           SFUDCFL SFUFL SRCDOM SRCSEQ AETERM AEMODIFY AEDECOD AEBODSYS AEHLGT 
           AEHLT AELLT AELLTCD TRTSDT TRTSDTC TRTEDT TRTEDTC AESTDTC AESTRTPT
           AEENDTC AEENRTPT AESDT AEEDT AESDY AESER AEREL AERELOTH AETOXGR
           AETOXGRN AEACN AETRTOTH AESDTH AEDTHDTC DTHAUTYN AESLIFE AESHOSP
           AEHDTC AESDISAB AESCONG AESMIE TRTEM INVNAM INVID AGE AGEU AGEGR1
           AGEGR1N SEX RACE ETHNIC COUNTRY RANDDT;
    set data2;
    keep STUDYID USUBJID SUBJID SITEID TRT01P TRT01PN TRT01A TRT01AN 
         REMISS REMISSN ITTFL SAFFL EFFL CA125FL TRTDCFL COMPLFL STDDCFL
         SFUDCFL SFUFL SRCDOM SRCSEQ AETERM AEMODIFY AEDECOD AEBODSYS AEHLGT
         AEHLT AELLT AELLTCD TRTSDT TRTSDTC TRTEDT TRTEDTC AESTDTC AESTRTPT
         AEENDTC AEENRTPT AESDT AEEDT AESDY AESER AEREL AERELOTH AETOXGR
         AETOXGRN AEACN AETRTOTH AESDTH AEDTHDTC DTHAUTYN AESLIFE AESHOSP
         AEHDTC AESDISAB AESCONG AESMIE TRTEM INVNAM INVID AGE AGEU AGEGR1
         AGEGR1N SEX RACE ETHNIC COUNTRY RANDDT;
    *AERELOTH*;
    if AERELNST^='MULTIPLE' then AERELOTH=AERELNST;
    else if AERELNST='MULTIPLE' then AERELOTH=strip(AERELNS1)||'; '||strip(AERELNS2);
run;


proc contents data=mysdtm.adae varnum;
run;
