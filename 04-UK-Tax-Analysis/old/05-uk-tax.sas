%macro back_together (minp=, maxp=);

%do period = &minp. % to &maxp.;

%do i = 1 %to 3;

%if &i. = 1 %then %let patt = m;
%if &i. = 2 %then %let patt = q;
%if &i. = 3 %then %let patt = a;

data ruto_&patt.&period.;
set vat.ruto_simple_&patt.&period.
    vat.ruto_complex_&patt.&period.;
run;

proc delete data=vat.ruto_simple_&patt.&period.;run;
proc delete data=vat.ruto_complex_&patt.&period.;run;

%end; /*i*/

%end; /*period*/

%mend;


%macro transform_p_to_m (minp=,maxp=);


%do period = &minp. %to &maxp.;

proc sql;

create table vat.month_&period. 
(ruref char(12),
 refperiod num,
 arrivalperiod num,
 rx_period num,
 comp_ve num,
 comp_er num,
 ru_vat_to num,
 raw_ru_vat_to num,
 clean_marker num);

insert into vat.month_&period.
select ruref,
       &period. as refperiod,
       arrivalperiod,
       rx_period,
       case
	       when compress(case_ve) = 'complex' then 1
		   else 0
	   end as comp_ve,
       case
	       when compress(case_er) = 'complex' then 1
		   else 0
	   end as comp_er,
       ru_vat_to,
       original_ru_vat_to as raw_ru_vat_to,
       clean_marker
from ruto_m&period.;

quit;

%put monthly reports inserted into vat.month_&period. from ruto_m&period.;

%do q = 0 %to 2;

%let i = %eval(&period. - &q.);

%if &i. ge &minp. %then 
	%do;
		proc sql;
			insert into vat.month_&i.
			select ruref,
                   &i. as refperiod,
                   arrivalperiod,
                   rx_period,
                   case
	                   when compress(case_ve) = 'complex' then 1
	                   else 0
	               end as comp_ve,
	               case
	                   when compress(case_er) = 'complex' then 1
	                   else 0
	               end as comp_er,
	               ru_vat_to/3 as ru_vat_to,
	               original_ru_vat_to/3 as raw_ru_vat_to,
	               clean_marker
          from ruto_q&period.;
          quit;
        %put quarterly reports inserted into vat.month_&i. from ruto_q&period.;
    %end; /*%if &i. ge &minp.*/
%else %put no earlier months;

%end; /*q*/

%do a = 0 %to 11;

%let j = %eval(&period. - &a.);

%if &j. ge &minp. %then 
%do;
	proc sql;
		insert into vat.month_&j.
			select ruref,
                   &j. as refperiod,
                   arrivalperiod,
                   rx_period,
                   case
	                   when compress(case_ve) = 'complex' then 1
	                   else 0
	               end as comp_ve,
	               case
	                   when compress(case_er) = 'complex' then 1
	                   else 0
	               end as comp_er,
	               ru_vat_to/12 as ru_vat_to,
	               original_ru_vat_to/12 as raw_ru_vat_to,
	               clean_marker
            from ruto_a&period.;
	quit;
	%put annual reports inserted into vat.month_&j. from ruto_a&period.;
%end; /*%if &j. ge &minp. */
%else %put no earlier months;
%end; /*a*/

%end; /*period*/

%mend;

%macro populating_ruvatto (period=);

proc sql;

create table find_rurefs as
select distinct ruref,
          rx_period
from ru_vat_to_m&period. 
where division = '';

create table where_to_look as
select distinct rx_period
from ru_vat_to_m&period.
where division = '';

 create table data_pool
 (ruref char(12),
  legal_status char(1),
  division char(8),
  section char(1),
  empband char(1),
  class char(5),
  frozen_empment num,
  current_empment num,
  frozen_reg_to num,
  current_reg_to num,
  frozen_SIC07 char(8),
  current_SIC07 char(8),
  live_lu num,
  gor char(1),   /*Mila: added on 12062015*/
  ssr char(1));  /*Mila: added on 12062015*/

  create table rows_to_replace like ru_vat_to_m&period.;

 quit;

proc sql noprint;

	select nobs
	into :periods_to_check
	from dictionary.tables
    where libname = 'WORK' 
    and memname = 'WHERE_TO_LOOK';

quit;

%if &periods_to_check. gt 0 %then %do;

	 data _null_;
	 set where_to_look end=finish;
	 	call symput('p_to_lookin'||compress(_N_),trim(left(rx_period)));
	 	if finish = 1 then call symputx('last_num', _N_);
	 run;

	%do i = 1 %to &last_num.;

		proc sql;

		insert into data_pool
		select ruref,
			   compress(legal_status),
			   division,
			   section,
			   empband,
			   class,
			   frozen_empment,
			   current_empment,
			   frozen_reg_to,
			   current_reg_to,
			   frozen_SIC07,
			   current_SIC07,
			   live_lu,
			   gor, /*Mila: added on 12062015*/
			   ssr /*Mila: added on 12062015*/
		from vat.rx_&&p_to_lookin&i..
		where ruref in (select ruref from find_rurefs 
		                 where rx_period = &&p_to_lookin&i.. );
		quit;

	%end; /*i*/

		proc sql;

		insert into rows_to_replace
		select a.ruref,
		       a.refperiod,
		       a.arrivalperiod,
			   a.rx_period,
			   case
			   	   when a.complexity gt 0 then 'complex'
				   else 'simple'
			   end as complexity,
		       b.legal_status,
		       b.division,
		       b.section,
		       b.empband,
		       b.class,
		       b.frozen_empment,
			   b.current_empment,
		       (b.frozen_reg_to*1000)/12 as monthly_fr_reg_to,
		       (b.current_reg_to*1000)/12 as monthly_reg_to,
		       b.current_SIC07,
		       b.frozen_SIC07,
		       b.live_lu,
		       a.ru_vat_to,
		       a.raw_ru_vat_to,
		       a.clean_marker,
			   b.gor, /*Mila: added on 12062015*/
			   b.ssr  /*Mila: added on 12062015*/
		from  data_pool b  left join
		      vat_to_&period. a
		on b.ruref = a.ruref;

		quit;

	%end;/*if there are rows in where to look*/
%mend;

%macro consolidate(minp=, maxp=);
proc sql;

create table before_replacement
(period num,
 vat_to_before num);

create table after_replacement
(period num,
 vat_to_after num);

quit;

%do period = &minp. %to &maxp.;

proc sql;

create table vat_to_&period. as
select ruref,
       &period. as refperiod,
       max(arrivalperiod) as arrivalperiod,
	   max(rx_period) as rx_period,
	   sum(comp_ve)+ sum(comp_er) as complexity,
	   count(ruref) as vat_reporters,
       sum(ru_vat_to) as ru_vat_to,
       sum(raw_ru_vat_to) as raw_ru_vat_to,
	   max(clean_marker) as clean_marker
from vat.month_&period.
group by ruref;

insert into before_replacement
select &period. as period,
       sum(ru_vat_to) as vat_to_before
from vat_to_&period.;

create table ru_vat_to_m&period. as
select a.ruref,
       a.refperiod,
       a.arrivalperiod,
	   a.rx_period,
	   case
	   	   when a.complexity gt 0 then 'complex'
		   else 'simple'
	   end as complexity,
       b.legal_status,
       b.division,
       b.section,
       b.empband,
       b.class,
       b.frozen_empment,
	   b.current_empment,
       (b.frozen_reg_to*1000)/12 as monthly_fr_reg_to,
       (b.current_reg_to*1000)/12 as monthly_reg_to,
       b.current_SIC07,
       b.frozen_SIC07,
       b.live_lu,
       a.ru_vat_to,
       a.raw_ru_vat_to,
       a.clean_marker,
	   b.gor, /*Mila: added on 12062015*/
	   b.ssr /*Mila: added on 12062015*/

from vat_to_&period. a left join
     vat.rx_&period. b 
on a.ruref = b.ruref;


quit;

%populating_ruvatto (period=&period.);

proc sql;

delete from ru_vat_to_m&period.
where division = '';

insert into ru_vat_to_m&period.
select * from rows_to_replace;

insert into after_replacement
select &period. as period,
		sum(ru_vat_to) as vat_to_after
from ru_vat_to_m&period.;

create table vat.ruto__m&period. as
select *, 
       'm' as freq_rep
from Ru_vat_to_m&period.;

quit;

%end;/*period*/

proc sql;

create table check_replacement as
select a.period,
       a.vat_to_before,
	   b.vat_to_after,
	   a.vat_to_before - b.vat_to_after as difference
from before_replacement a left join
     after_replacement b
on a.period = b.period;

quit;

%mend;
