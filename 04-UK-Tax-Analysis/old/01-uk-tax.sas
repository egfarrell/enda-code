

%macro monthvat;    /* macro variable p refers to the period */

	data _null_;
		set vat.vat_per_lookup end=finish;
		call symput('vat_per'!!compress(_N_),trim(left(period_vat)));
		call symput('cal_per'!!compress(_N_),trim(left(period_calendar)));
		if finish = 1 then call symputx('period_num',_N_);
	run;

%do i = 1 %to &period_num.;
	
		filename mvat&&vat_per&i.. "&task_path.\irt_mbi_infile20&&cal_per&i..";
		data mvat&&vat_per&i.. (where = ((not (vatref9 in ('000000000','999999999'))
							 &(refperiod<999)
							 &(60<=rec_type<=65)
							 &(0<=stagger<=15)
							 &(1<=ret_type<=2)
							 &(turnover<99999999998))));
			infile mvat&&vat_per&i.. ; 
			input vatref9 $ 1-9 
		          vatref $ 1-7 
		          checkdig $ 8-9 
		          refperiod 10-12 
			      rec_type 13-14 
		          stagger 15-16 
		          vatsic5 17-21 
		          ret_type 22-22 
		          turnover 23-33;

				 arrivalperiod = &&vat_per&i..;
		run;

%end;
%mend;

%macro duplicate(minp=,maxp=);

%do period = &minp %to &maxp;

proc sql;
create table vat.mvat&period. as
select distinct vatref9,
          		vatref,
          		checkdig,
				refperiod,
	      		rec_type,
          		stagger,
          		vatsic5, 
          		ret_type,
          		turnover,
				arrivalperiod
from mvat&period.

quit;

proc delete data = mvat&period.;run;

%end;
%mend;

%macro allvat_split_to_periods(minp=,maxp=);

%do period = &minp %to &maxp;
/*create empti period tables where the records from each monthly 
  file will be inserted at the next step*/

proc sql;

create table vat.ref_period_&period.
(vatref9 char(9),
 vatref char(7), 
 checkdig char(2),
 refperiod num,
 rec_type num,
 stagger num,
 vatsic5 num,
 ret_type num,
 turnover num,
 refperiod num,
 arrivalperiod num);

quit;

%end;

%do mfile = &minp %to &maxp; /*Picks each of the monthly VAT files (datasets)*/

%do period = &minp %to &mfile; /* And inserts into the appropriate period dataset the reports for this period*/

%put &mfile. file vat.mvat_&mfile. period &period.; 

proc sql;
   
   insert into vat.ref_period_&period.
   select * from vat.mvat&mfile.
   where refperiod = &period.;
quit; 

%end;/* for the period cycle*/

proc delete data = vat.mvat&mfile.;run;

%end;/* for the monthly files cycle*/

%mend;


%macro duplicate2 (minp=, maxp=);

Proc sql;

create table before_cleaning
(ref_period num,
 initial_reports num);

Create table after_cleaning
(ref_period num,
 Reporters num,
 Reports num,
 duplicates num);

Quit;

%do i=&minp %to &maxp;

proc sort data= vat.ref_period_&i;
by vatref9 arrivalperiod rec_type descending turnover;
run;

data vat.ref_period_d2_&i;
set vat.ref_period_&i;
by vatref9 arrivalperiod rec_type descending turnover;

marker = 0;
if (lag(vatref9) = vatref9) and 
   (lag(arrivalperiod) ne arrivalperiod) 
then marker = 1;

if (lag(vatref9) = vatref9) and 
   (lag(arrivalperiod) = arrivalperiod) and
   (lag(rec_type) ne rec_type)
then marker = 1;

if (lag(vatref9) = vatref9) and 
   (lag(arrivalperiod) = arrivalperiod) and
   (lag(rec_type) = rec_type) and
   (lag (turnover) ne turnover)
then marker = 1;

if marker = 0;

run;

proc sql;

insert into before_cleaning
select &i,
      count(turnover) as reports
from vat.ref_period_&i.;

insert into after_cleaning
select &i,
	  count(distinct vatref9) as reporters,
      count(turnover) as reports,
      calculated reports - calculated reporters as duplicates
from vat.ref_period_d2_&i.;

quit;

proc delete data = vat.ref_period_&i.;run;

proc datasets library = vat;
change ref_period_d2_&i. = ref_period_&i.;
quit;

%end;

proc sql;

create table check_duplicates as
select a.*,
       b.initial_reports - a.reports as cleared_dups
from after_cleaning a left join 
     before_cleaning b
on a.ref_period = b.ref_period;


quit;

proc delete data = before_cleaning;run;
proc delete data = after_cleaning;run;

%mend;
