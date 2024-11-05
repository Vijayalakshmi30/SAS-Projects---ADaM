/*log file*/
proc printto log='/home/u63774111/Project/Log files/adtte.log';

libname sasval "/home/u63774111/Project/Project_2/xpt_sas_val"; 

data frm_adsl;
    set sasval.adsl;
    keep USUBJID SUBJID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC ITTFL SAFFL EFFL CA125FL
         TRTSDT TRTEDT STDSDT STDEDT RANDDT DTHDT DTHPER BECOG REMISS REMISSN RSP125 
         HPATHTYP HSUBTYP STUDYID SITEID INVNAM INVID COUNTRY TRT01P TRT01PN TRT01A
         TRT01AN;
run;


*** 1. TU Dataset ***;
libname adinput "/home/u63774111/Project/Project_2/ADinput";

*TUMLDT*;
data tu;
keep USUBJID TUDTC1 TUORRES;
format TUDTC1 IS8601DA.;
set adinput.tu;
TUDTC1=input(TUDTC, IS8601DA.);
if (TUORRES^='') and (TUDTC1<=input('2010-05-15',yymmdd10.));
run;

proc sort data=tu out=sort_tu;
by USUBJID descending TUDTC1;
run;

data tu1(keep=USUBJID TUDTC1 rename=(TUDTC1=TUMLDT));
label TUDTC1='Last Tumor Assessment Date';
format TUDTC1 IS8601DA.;
set sort_tu;
by USUBJID descending TUDTC1;
if first.USUBJID;
run;


*FPDDT*;
data tu_;
format TUDTC1 IS8601DA.;
set adinput.tu;
TUDTC1=input(TUDTC, IS8601DA.);
if (TUDTC1<=input('2010-05-15',yymmdd10.)) and (substr(TUORRES,1,2) in ('Y','NL'));
run;

proc sort data=tu_ out=sort_tu_(keep=USUBJID TUDTC TUDTC1);
by USUBJID TUDTC1;
run;

data tu2(keep=USUBJID TUDTC TUDTC1 rename=(TUDTC1=FPDDT));
label FPDDT='First PD Date';
set sort_tu_;
by USUBJID TUDTC1;
if first.USUBJID;
run;


*** 2. FCA125DT ***;

** 2.1 Merging ADSL and LB**;

data lb1(keep=USUBJID CA125FL TRTSDT LBTESTCD LBORRES LBORRES1 LBORNRHI LBORNRHI1 LBDTC LBDTC1);
merge frm_adsl(in=a) adinput.lb(in=b);
by USUBJID; 
*Condition 1*;
if CA125FL='Y';
*Condition 2*;
format LBDTC1 IS8601DA.;
LBDTC1=input(LBDTC, yymmdd10.); 
if (LBTESTCD='CA125') and (LBDTC1>=TRTSDT);
*Condition 3*;
LBORRES1=input(LBORRES,best.);
LBORNRHI1=input(LBORNRHI,best.);
if (nmiss(LBORRES1)=0) and (LBORRES1>=(2*LBORNRHI1));
*Condition 5*;
if nmiss(LBDTC1)=0 and (LBDTC1<=input('2010-05-15',yymmdd10.));
run;

** 2.2 Sorting data for condition 4**;
proc sort data=lb1 out=sort_lb1(keep=USUBJID LBDTC1);
by USUBJID LBDTC1;
run;

** Condition 4 and FCA125DT**;
data lb1(keep=USUBJID FCA125DT);
    set sort_lb1;
    by USUBJID LBDTC1;

    * Initialize firstdt and lastdt variables;
    retain firstdt lastdt;
    
    attrib firstdt format=IS8601DA.
           lastdt format=IS8601DA.
           FCA125DT format=IS8601da. label='First CA-125 Elevation Date';

    if first.USUBJID then firstdt = LBDTC1;
    if last.USUBJID then lastdt = LBDTC1;

    * Condition 4: Calculate the difference between dates and filter the observations;
    if last.USUBJID and lastdt - firstdt >= 7;
    FCA125DT = firstdt;
run;


*** 3. LCA125DT ***;

data lb2;
merge frm_adsl adinput.lb(keep=USUBJID LBTESTCD LBDTC LBORRES);
by USUBJID;
*Applying conditions*;
format LBDTC1 IS8601DA.;
LBDTC1=input(LBDTC, yymmdd10.);
if (CA125FL='Y') and LBORRES^='' and LBDTC1^=. and LBDTC1<=input('2010-05-15',yymmdd10.) 
   and LBTESTCD='CA125' and LBDTC1>=TRTSDT;
run;

proc sort data=lb2 out=sort_lb2(keep=USUBJID LBDTC1);
by USUBJID descending LBDTC1;
run;

data lb2(rename=(LBDTC1=LCA125DT));
label LCA125DT='Last CA-125 Assessment Date';
set sort_lb2;
by USUBJID descending LBDTC1;
if first.USUBJID;
run;


*** 4. Merging frm_adsl tu1 tu2 lb1 lb2, naming it as data1 ***;

data data1;
merge frm_adsl(in=a) tu1 tu2 lb1 lb2;
by USUBJID;
if a;
run;


*** 5. FPD125DT & TRTP ***;

data fpd;
set data1;
attrib FPD125DT format=IS8601DA. label='First PD Date for CA-125 Responder';
* FPD125DT Logic *;
if CA125FL = 'Y' then do;
   if nmiss(FPDDT, FCA125DT) = 0 then do;
      if FPDDT < FCA125DT then FPD125DT = FPDDT;
      else if FPDDT > FCA125DT then FPD125DT = FCA125DT;
      else FPD125DT = FPDDT;
   end;
   else if FPDDT = . then FPD125DT = FCA125DT;
   else if FCA125DT = . then FPD125DT = FPDDT;
end;
TRTP=TRT01P;
run;


*** 6. Time to PFS (Progression Free Survival) ***;

data pfs(drop=_DTHDT);
length PARAM EVNTDESC $80 PARAMCD $8;
format ADT STARTDT IS8601DA.;
set fpd;
PARAM='TIME TO PROGRESSION FREE SURVIVAL (month)';
PARAMCD='TTPFS';
STARTDT=RANDDT;

* _DTHDT Logic *;
if DTHDT > 0 and DTHDT <= input("2010-05-15",yymmdd10.)  then _DTHDT = DTHDT;
else _DTHDT = .;

* ADT Logic *;
if nmiss(_DTHDT, FPDDT) = 0 then do;
    if FPDDT <= _DTHDT then ADT = FPDDT;
    else ADT = _DTHDT;
end;
else if nmiss(_DTHDT) > 0 and FPDDT > 0 then ADT = FPDDT;
else if _DTHDT > 0 and nmiss(FPDDT) > 0 then ADT = _DTHDT;
else if nmiss(FPDDT, _DTHDT) > 0 and TUMLDT > 0 then ADT = TUMLDT;
else ADT = RANDDT;

*CNSR*;
if (nmiss(FPDDT)=0) or nmiss(_DTHDT)=0 then CNSR=0;
else if nmiss(TUMLDT)=0 then CNSR = 1;
else CNSR = 2;

*EVNTDESC*;
if nmiss(_DTHDT, FPDDT) = 0 then do;
   if FPDDT<=_DTHDT then EVNTDESC='DISEASE PROGRESSION';
   else EVNTDESC='DEATH';
   end;
else if nmiss(_DTHDT) > 0 and FPDDT > 0 then EVNTDESC='DISEASE PROGRESSION';
else if _DTHDT > 0 and nmiss(FPDDT) > 0 then EVNTDESC='DEATH';
else if (nmiss(FPDDT, _DTHDT) > 0) and TUMLDT > 0 then EVNTDESC='CENSORED AS OF LAST TUMOR SCAN DATE';
else EVNTDESC='CENSORED AS OF RANDOMIZATION DATE';

*AVAL*;
AVAL=(ADT-STARTDT+1)/30.4375;
run;


*** 7. Time to PFS for CA-125 Responders ***;

data pfs125(drop=_DTHDT);
length PARAM EVNTDESC $80 PARAMCD $8;
set fpd;
PARAM='TIME TO PROGRESSION FREE SURVIVAL CA-125 RESPONDER (month)';
PARAMCD='TTPFS125';
STARTDT=RANDDT;

** _DTHDT Logic **;
if DTHDT > 0 and DTHDT <= input("2010-05-15",yymmdd10.)  then _DTHDT = DTHDT;
else _DTHDT = .;

** ADT EVNTDESC Logic **;

* i. All three dates are non-missing *;
if nmiss(fpddt, _dthdt, fca125dt)=0 then do;
      ADT=min(fpddt, _dthdt,fca125dt);
     *EVNTDESC*;
      if ADT=_DTHDT then EVNTDESC='DEATH';
      else if ADT=FPDDT then EVNTDESC='DISEASE PROGRESSION';
      else EVNTDESC='CA-125 CRITERIA AS DISEASE PROGRESSION';
      end;
* ii. Two dates are non-missing *;
else if nmiss(fpddt, _dthdt,fca125dt)=1 then do;
        if nmiss(fpddt,_dthdt)=0 then do;
                if fpddt =<_dthdt then do;
                   ADT=FPDDT;
                   EVNTDESC='DISEASE PROGRESSION';
                   end;
                else do;
                   ADT=_DTHDT;
                   EVNTDESC='DEATH';
                   end;
                end;
        else if nmiss(fpddt,fca125dt)=0 then do;
                if FPDDT<=FCA125DT then do;
                   ADT=FPDDT;
                   EVNTDESC='DISEASE PROGRESSION';
                   end;
                else do;
                   ADT=FCA125DT;
                   EVNTDESC='CA-125 CRITERIA AS DISEASE PROGRESSION';
                   end;
                end;
        else if nmiss(_dthdt,fca125dt)=0 then do;
                if _DTHDT<=FCA125DT then do;
                   ADT=_DTHDT;
                   EVNTDESC='DEATH';
                   end;
                else do;
                   ADT=FCA125DT;
                   EVNTDESC='CA-125 CRITERIA AS DISEASE PROGRESSION';
                   end;
                end;
        end;
* iii. Only one date is non-missing *; 
else if nmiss(fpddt, _dthdt,fca125dt)=2 then do;
        if FPDDT>0 then do;
                ADT=FPDDT;
                EVNTDESC='DISEASE PROGRESSION';
                end;
        else if _DTHDT>0 then do;
                ADT=_DTHDT;
                EVNTDESC='DEATH';
                end;
        else if FCA125DT>0 then do;
                ADT=FCA125DT;
                EVNTDESC='CA-125 CRITERIA AS DISEASE PROGRESSION';
                end;
        end;
* iv. All dates are missing *;
else if nmiss(fpddt, _dthdt,fca125dt)=3 then do;
        if nmiss(TUMLDT, LCA125DT)=0 then do;
               ADT=max(TUMLDT, LCA125DT);
               if ADT=TUMLDT then EVNTDESC='CENSORED AS OF LAST TUMOR SCAN DATE';
               else if ADT=LCA125DT then EVNTDESC='CENSORED AS OF LAST CA-125 LAB ASSESSMENT DATE';
               end;
        else if nmiss(TUMLDT, LCA125DT)=1 then do;
                if TUMLDT>0 then do;
                        ADT=TUMLDT;
                        EVNTDESC='CENSORED AS OF LAST TUMOR SCAN DATE';
                        end;
                else if LCA125DT>0 then do;
                        ADT=LCA125DT;
                        EVNTDESC='CENSORED AS OF LAST CA-125 LAB ASSESSMENT DATE';
                        end;
                end;
        else if nmiss(TUMLDT, LCA125DT)=2 then do;
                ADT=RANDDT;
                EVNTDESC='CENSORED AS OF RANDOMIZATION DATE';
                end;
        end;

** CNSR **;

/*
if CA125FL='Y';
if (FPDDT>0 or _DTHDT>0 or FPD125DT>0) then CNSR=0;
else if nmiss(TUMLDT)=0 then CNSR=1;
else if nmiss(LCA125DT)=0 then CNSR=2;
else CNSR=3;
*/

if CA125FL='Y';
if (FPDDT>0 or _DTHDT>0 or FPD125DT>0) then CNSR=0;
else do;
     *Both dates are non-missing*;
     if nmiss(tumldt, lca125dt)=0 then do;
        if tumldt >= lca125dt then cnsr=1;
        else cnsr=2;
        end;
     *One of the dataes is non-missing*;
     else if nmiss(tumldt,lca125dt)=1 then do;
        if tumldt>0 then cnsr=1;
        else cnsr=2;
        end;
      *Both dates are missing*;
      else cnsr=3;
      end;
     
        
** PFS duration in months **;
AVAL=(ADT-STARTDT+1)/30.4375;

run;


*** 8. Time to OS (Overall Survival) ***;

* 8.1 DS dataset for ADT derivation for (if death didn't occur)*;
data os_adt(keep=USUBJID DSSTDTC1);
merge fpd(keep=USUBJID DTHDT) adinput.ds;
by USUBJID;
format DSSTDTC1 IS8601DA.;
DSSTDTC1=input(DSSTDTC, yymmdd10.);
if DTHDT<0 and (DSCAT='DISPOSITION EVENT') and DSSCAT in ('STUDY PERIOD','FOLLOW-UP') and DSDECOD^='DEATH';
run;

proc sort data=os_adt;
by USUBJID descending DSSTDTC1;
run;

data os_adt1(rename=(DSSTDTC1=ADT));
set os_adt;
by USUBJID descending DSSTDTC1;
if first.USUBJID;
run;

* 8.2 DS dataset for ADT derivation for (if death occurred) *;
data os_adt_dth(keep=USUBJID DSSTDTC1);
merge fpd(keep=USUBJID DTHDT) adinput.ds;
by USUBJID;
format DSSTDTC1 IS8601DA.;
DSSTDTC1=input(DSSTDTC, yymmdd10.);
if DTHDT>0;
run;

proc sort data=os_adt_dth;
by USUBJID descending DSSTDTC1;
run;

data os_adt_dth1(rename=(DSSTDTC1=ADT));
set os_adt_dth;
by USUBJID descending DSSTDTC1;
if first.USUBJID;
run;

* 8.3 ADT for OS*;
data os_adt_;
set os_adt1 os_adt_dth1;
run;

proc sort data=os_adt_;
by USUBJID;
run;

* 8.4 CNSR EVNTDESC *;

* 8.4.1 Selecting latest date per subject based on few conditions from DS dataset *;
data ds1;
set adinput.ds;
format DSSTDTC1 IS8601DA.;
DSSTDTC1=input(DSSTDTC, yymmdd10.);
where DSCAT='DISPOSITION EVENT' and DSSCAT in ('STUDY PERIOD','FOLLOW-UP');
run;

proc sort data=ds1;
by USUBJID descending DSSTDTC1;
run;

data ltst(rename=(dsstdtc1=latest_) keep=USUBJID DSSTDTC1);
set ds1;
by USUBJID descending DSSTDTC1;
if first.USUBJID;
run;

* 8.4.2 Selecting DSDECOD *;
data dscode(keep=USUBJID DSDECOD);
merge adinput.ds ltst;
by USUBJID;
format DSSTDTC1 IS8601DA.;
DSSTDTC1=input(DSSTDTC, yymmdd10.);
if (DSCAT='DISPOSITION EVENT') and (DSSCAT in ('STUDY PERIOD','FOLLOW-UP')) and (DSSTDTC1=latest_);
run; 

* 8.4.3 CNSR EVNTDESC for OS *;
data os_cnsr(keep=USUBJID CNSR EVNTDESC);
length EVNTDESC $80;
set dscode;
if DSDECOD='DEATH' then do;
   CNSR=0;
   EVNTDESC='EVENT: DEATH DUE TO ANY CAUSE';
   end;
else do;
     if DSDECOD='STUDY TERMINATED BY SPONSOR' then do;
             CNSR=1;
             EVNTDESC='CENSORED AS OF DATE SPONSOR DECIDED TO TERMINATE THE STUDY';
             end;
     else if DSDECOD='LOST TO FOLLOW-UP' then do;
             CNSR=2;
             EVNTDESC='CENSORED AS OF DATE DUE TO LOST TO FOLLOW-UP';
             end;
     else if DSDECOD='WITHDRAWAL BY SUBJECT' then do;
             CNSR=3;
             EVNTDESC='CENSORED AS OF DATE SUBJECT DECIDED TO WITHDRAW';
             end;
     else if DSDECOD='OTHER' then do;
             CNSR=4;
             EVNTDESC='CENSORED AS OF DATE OF WITHDRAWAL DUE TO OTHER REASONS';
             end;
     else if DSDECOD='PROGRESSIVE DISEASE' then do;
             CNSR=5;
             EVNTDESC='CENSORED AS OF DATE OF DISEASE PROGRESSION';
             end;
     end;
run;

proc sort data=os_cnsr;
by USUBJID;
run;

* 8.5 Merging ADT CNSR EVNTDESC fpd *;
data os;
length PARAM $80 PARAMCD $8;
merge fpd(keep=STUDYID USUBJID SUBJID SITEID INVNAM INVID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC COUNTRY TRT01P TRT01PN
               TRT01A TRT01AN BECOG REMISS REMISSN RSP125 HPATHTYP HSUBTYP RANDDT TRTSDT TRTEDT STDSDT STDEDT DTHDT DTHPER
               ITTFL SAFFL EFFL CA125FL) 
      os_adt_ 
      os_cnsr;
by USUBJID;
PARAM='TIME TO OVERALL SURVIVAL (month)';
PARAMCD='TTOS';
STARTDT=RANDDT;
* PFS duration in months *;
AVAL=(ADT-STARTDT+1)/30.4375;
run;


*** 9. Final ADTTE dataset***;

libname mysdtm '/home/u63774111/Project/Output';

data adtte;
retain SUBJID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC ITTFL SAFFL EFFL CA125FL TRTSDT TRTEDT STDSDT
       STDEDT RANDDT DTHDT DTHPER BECOG REMISS REMISSN RSP125 HPATHTYP HSUBTYP TUMLDT FPDDT FPD125DT
       FCA125DT LCA125DT PARAM PARAMCD STARTDT ADT CNSR EVNTDESC AVAL STUDYID USUBJID SITEID INVNAM
       INVID COUNTRY TRT01P TRT01PN TRT01A TRT01AN TRTP;
keep SUBJID AGE AGEU AGEGR1 AGEGR1N SEX RACE ETHNIC ITTFL SAFFL EFFL CA125FL TRTSDT TRTEDT STDSDT
     STDEDT RANDDT DTHDT DTHPER BECOG REMISS REMISSN RSP125 HPATHTYP HSUBTYP TUMLDT FPDDT FPD125DT
     FCA125DT LCA125DT PARAM PARAMCD STARTDT ADT CNSR EVNTDESC AVAL STUDYID USUBJID SITEID INVNAM
     INVID COUNTRY TRT01P TRT01PN TRT01A TRT01AN TRTP;
attrib TRTP length=$10 label='Planned Treatment (Record Level)'
       FPDDT label='First PD Date'
       LCA125DT label='Last CA-125 Assessment Date'
       PARAM label='Analysis Parameter Description'
       PARAMCD label='Analysis Parameter Short Name'
       STARTDT label='Time to Event Origin Date for Subject' format=IS8601DA.
       ADT label='Analysis Date'
       CNSR label='Censoring Indicator'
       EVNTDESC label='Event Description'
       AVAL label='Analysis Value';       
set pfs pfs125 os;
TRTP=TRT01P;
run;

proc sort data=adtte out=mysdtm.adtte(label='Time to Events Analysis (Efficacy)');
by STUDYID USUBJID SUBJID PARAMCD PARAM;
run;

proc contents data=mysdtm.adtte varnum;
run;
