
/*1.	Verify and Clean 1000 pounds errors*/
%macro verify_clean_1000p (per=, patt=, case=);

%if &patt. = m %then %let per_1 = %Eval(&per. - 1);
%if &patt. = q %then %let per_1 = %Eval(&per. - 3);
%if &patt. = a %then %let per_1 = %Eval(&per. - 12);

proc sql;

create table verify_1000p_&per._&patt. As
select a.ruref,
	  a.class,
 	  a.ru_vat_to, 
	  case
         when ((b.ru_vat_to not in (., 0)) 
          and (a.ru_vat_to  between b.ru_vat_to*0.00065 and  b.ru_vat_to*0.00135)) 
         then 1
         else 0
      end as clean_marker
from vat.ruto_&case._&patt.&per. as a left join
     vat.ruto_&case._&patt.&per_1. as b 
on a.ruref = b.ruref;

update vat.ruto_&case._&patt.&per.
set  ru_vat_to  = ru_vat_to*1000, 
     clean_marker = 1
where ruref in (select ruref from verify_1000p_&per._&patt.
                              where clean_marker = 1);
quit;
%mend;/*verify_clean_1000p*/

/*3.	Verify and Clean Strange Quarterly Reporting Patterns*/


%macro verify_clean_Qrep_patterns (per=, case=);

%let patt = q;
%let per_3 = %eval(&per - 3);
%let per_6 = %eval(&per - 6);
%let per_9 = %eval(&per - 9);

proc sort data = vat.ruto_&case._&patt.&per.;
by ruref; run;

proc sort data = vat.ruto_&case._&patt.&per_3.;
by ruref; run;

proc sort data = vat.ruto_&case._&patt.&per_6.;
by ruref; run;

proc sort data = vat.ruto_&case._&patt.&per_9.;
by ruref; run;

data four_quarters
         four_quarter_clean(where =(clean_marker = 0));
merge   vat.ruto_&case._&patt.&per. (in = in_current)
               vat.ruto_&case._&patt.&per_3. (keep = ruref ru_vat_to rename = (ru_vat_to = ru_vat_to_3))
                vat.ruto_&case._&patt.&per_6. (keep = ruref ru_vat_to rename = (ru_vat_to = ru_vat_to_6))
                vat.ruto_&case._&patt.&per_9. (keep = ruref ru_vat_to  rename = (ru_vat_to = ru_vat_to_9));
by ruref;

four_q_to = ru_vat_to + ru_vat_to_3 + ru_vat_to_6 + ru_vat_to_9;
if four_q_to ne 0 then do;
	prop_1  = ru_vat_to/four_q_to;
               prop_2 = ru_vat_to_3/four_q_to;
               prop_3 = ru_vat_to_6/four_q_to;
               prop_4 = ru_vat_to_9/four_q_to;
end;
else do;
               prop_1 = 0;
               prop_2 = 0;
               prop_3 = 0;
               prop_4 = 0;
end;

if ru_vat_to not in (0, .) and
   (ru_vat_to = ru_vat_to_3) and
   (ru_vat_to = ru_vat_to_6) and
   (ru_vat_to = ru_vat_to_9) then clean_marker = 2;

/*ru_vat_to = ru_vat_to_3 = ru_vat_to_6 <> ru_vat_to_9*/
/*ru_vat_to = ru_vat_to_3 = ru_vat_to_9 <> ru_vat_to_6*/
/*ru_vat_to = ru_vat_to_9 = ru_vat_to_6 <> ru_vat_to_3*/
/*ru_vat_to_9 = ru_vat_to_3 = ru_vat_to_6 <> ru_vat_to*/

if ((ru_vat_to not in (0, .)) and  (ru_vat_to_9 not in (0, .))) and
    ((ru_vat_to = ru_vat_to_3) and
     (ru_vat_to_3 = ru_vat_to_6) and
     (ru_vat_to_6 ne ru_vat_to_9)) then clean_marker = 3;

 if ((ru_vat_to not in (0, .)) and  (ru_vat_to_6 not in (0, .))) and
    ((ru_vat_to = ru_vat_to_3) and
     (ru_vat_to_3 = ru_vat_to_9) and
     (ru_vat_to_9 ne ru_vat_to_6)) then clean_marker = 3;

if ((ru_vat_to not in (0, .)) and  (ru_vat_to_3 not in (0, .))) and
    ((ru_vat_to = ru_vat_to_9) and
     (ru_vat_to_9 = ru_vat_to_6) and
     (ru_vat_to_6 ne ru_vat_to_3)) then clean_marker = 3;

if ((ru_vat_to not in (0, .)) and  (ru_vat_to_3 not in (0, .))) and
    ((ru_vat_to_9 = ru_vat_to_3) and
     (ru_vat_to_3 = ru_vat_to_6) and
     (ru_vat_to_6 ne ru_vat_to)) then clean_marker = 3;
/*
if (ru_vat_to = 0) and  
   (ru_vat_to_3 = 0) and
    (ru_vat_to_6 = 0) and
    (ru_vat_to_9 ne .)  then clean_marker = 4;

if (ru_vat_to = 0) and  
   (ru_vat_to_3 = 0) and
    (ru_vat_to_6 ne .) and
    (ru_vat_to_9  = 0)  then clean_marker = 4;

if (ru_vat_to = 0) and  
   (ru_vat_to_3 ne .) and
    (ru_vat_to_6  = 0) and
    (ru_vat_to_9  = 0)  then clean_marker = 4;
*/
if (ru_vat_to ne .) and  
   (ru_vat_to_3 = 0) and
    (ru_vat_to_6 = 0) and
    (ru_vat_to_9  = 0)  then clean_marker = 4;

if in_current;

run;

%medians(argument = prop_1, data_set=four_quarter_clean);
%medians(argument = prop_2, data_set=four_quarter_clean);
%medians(argument = prop_3, data_set=four_quarter_clean);
%medians(argument = prop_4, data_set=four_quarter_clean);

proc sort data = four_quarters;
by class; run;

data four_q_medians;
merge med_prop_1
            med_prop_2
            med_prop_3
            med_prop_4
            four_quarters (in = in_main);
by class;

if in_main;

run;

%update_q_patterns(period = &per_9, n = 4);
%update_q_patterns(period = &per_6, n = 3);
%update_q_patterns(period = &per_3, n = 2);
%update_q_patterns(period = &per, n = 1);

 %mend;/* verify_clean_Qrep_patterns */

/*4.	Verify and Clean Suspicious Values*/


%macro verify_clean_susp_val (per=, patt=, case=);

%if &patt. = m %then %let per_1 = %eval(&per. - 1);
%if &patt. = q %then %let per_1 = %eval(&per. - 3);
%if &patt. = a %then %let per_1 = %eval(&per. - 12);

proc sql;

create table neighbour_periods as
select a.class,
           a.ruref,
		   a.freq_rep,
           a.ru_vat_to,
           b.ru_vat_to as ru_vat_to_1,
           a.clean_marker
from vat.ruto_&case._&patt.&per. a left join
           vat.ruto_&case._&patt.&per_1. b
on a.ruref = b.ruref;

quit;

%medians(argument=ru_vat_to, data_set=neighbour_periods);
%medians(argument=ru_vat_to_1, data_set=neighbour_periods);

proc sort data=neighbour_periods;
by class;

data verify_susp_val clean(where=(clean_marker=0));
merge  neighbour_periods
       med_ru_vat_to
       med_ru_vat_to_1;
by class;

score_1 = ru_vat_to/med_ru_vat_to;
score_2 = ru_vat_to_1/med_ru_vat_to_1;

select;
	when (score_1 ge score_2) ratio = score_1/score_2;
	when (score_2 gt score_1) ratio = score_2/score_1;
	otherwise;
end;

select;
	when ((compress(freq_rep) = 'm') and (ratio gt 7)) clean_marker = 5;
	when ((compress(freq_rep) = 'q') and (ratio gt 5)) clean_marker = 5;
	when ((compress(freq_rep) = 'a') and (ratio gt 4)) clean_marker = 5;
	otherwise;
end;
run;

%calculate_sum(argument = ru_vat_to, data_set = clean);
%calculate_sum(argument = ru_vat_to_1, data_set = clean);

data  values_to_update;
merge verify_susp_val (in = in_main)
             sum_ru_vat_to
             sum_ru_vat_to_1;
by class;

if  sum_ru_vat_to_1 ne 0 then growth_ratio = sum_ru_vat_to/ sum_ru_vat_to_1;
else   growth_ratio = 0;

if in_main and clean_marker = 5;

run;

proc sql;

create table ruto_&case._&patt.&per. As
select a.*,
       b.ru_vat_to_1*b.growth_ratio as new_vat_to
from vat.ruto_&case._&patt.&per. a left join
         values_to_update b
on a.ruref = b.ruref;

update ruto_&case._&patt.&per.
Set ru_vat_to = new_vat_to,
    clean_marker = 5
where new_vat_to ne .;

quit;

data vat.ruto_&case._&patt.&per.;
set ruto_&case._&patt.&per. (drop = new_vat_to);
run;

%mend;/* verify_clean_susp_val */

/*5.	Putting all verifying and cleaning together*/


%macro verify_and_clean (minp=, maxp=, case=);

%do i = 1 %to 3;

	%if &i. = 1 %then %let pattern = m;
	%if &i. = 2 %then %let pattern = q;
	%if &i. = 3 %then %let pattern = a;

	%do period = &minp. %to &maxp.;

		%verify_clean_1000p (per=&period., patt=&pattern., case=&case.);

		%if &pattern = q %then %verify_clean_Qrep_patterns (per=&period., case=&case.);

		%verify_clean_susp_val (per=&period., patt=&pattern., case=&case.);

	%end; /*period*/

%end; /*I (pattern)*/

%mend; /* verify_and_clean */

%macro verify_and_clean2 (minp=, maxp=);

	%do period = &minp. %to &maxp.;

		%verify_clean_1000p (per=&period., patt=m, case=);

		%verify_clean_susp_val (per=&period., patt=m, case=);

	%end; /*period*/

%mend; /* verify_and_clean */

