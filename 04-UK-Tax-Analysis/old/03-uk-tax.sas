
%macro linking_vat_ent;

/*this data set creates and populates the macro variables extract_period, 
vat period and number of periods, based on the vat.Vat_ent_lookup dataset
(IDBR extracts  period lookup.xls)*/

	data _null_;
		set vat.Vat_ent_lookup end=finish;
		call symput('extract_per'!!compress(_N_),trim(left(extract_period)));
		call symput('vat_per'!!compress(_N_),trim(left(period_vat)));
		if finish = 1 then call symputx('period_num',_N_);
	run;
proc sql;

/*The first 2 tables are auxiliary tables and will be linked at the end of the
macro to shed light at the quality of the linking between the VAT reports and 
the Enterprises at each period of interest.  */

create table vat_reporters
(period num,
 vat_reporters num,
 reported_to num format=d24.);

create table link_reporters
(period num,
 linked_reps num,
 transfered_to num format=d24.);

quit;

%do i = 2 %to &period_num.;/*this is the counter for the VAT_Enterprise datasets*/

%let j = %eval(&i. - 1);
%let p = %eval(&&vat_per&j.. - 1);/*this sets the earliest vat_reference period 
to be linked to the VAT_Enterprise dataset relevant for this period*/

%do period =&p. %to &&vat_per&i..;/*this is the loop for the vat_reference periods 
to be linked with the VAT_Enterprise dataset relevant for these periods. 
The VAT_Enterprise datasets are roughly quarterly 
so the idea is to link all the vat_reference periods from the previous VAT_Enterprise dataset
to the current one.*/

proc sql;

/*this statement will insert a row for each reference period noting how many VAT traders
had reported for that period and the amount Turnover they reported.*/

insert into vat_reporters
select &period. as period,
       count(vatref9) as vat_reporters,
	   sum(turnover) as reported_to
from vat.ref_period_&period.;

/*the table below is the main product of this macro and it links the VAT traders reported
for a particular reference period to the enterprises from IDBR associated with them up to this quarter*/

create table vat.vat_ent_rp_&Period. as
select a.vatref9,
	   a.refperiod,
	   a.stagger,
	   a.vatsic5,
	   a.turnover,
	   a.arrivalperiod,
       b.entref,
	   b.rx_period,
	   b.emp_proportion,
       a.turnover*b.emp_proportion as vat_ent_to,
	   b.case_ve
from vat.ref_period_&period. a left join
     vat.vatent_&&extract_per&i.. b
on a.vatref9 = b.vatref9;

/*There are no missing links between VAT refs and Enterprises.*/
create table missing_&period. as
select vatref9,
	   refperiod,
	   stagger,
	   vatsic5,
	   turnover,
	   arrivalperiod
from vat.ref_period_&period.
where vatref9 not in (select vatref9 from vat.Vat_ent_rp_&period.);


insert into link_reporters
select &period. as period,
       count(vatref9) as linked_reps,
	   sum(vat_ent_to) as transfered_to
from vat.vat_ent_rp_&Period.;


quit;

%end;/*period*/

%end;/*i*/

/*The loss of VAT turnover comes from failing to find enterprise data in the corresponding
repex files from IDBR for the particular periods, hence the employment proportions for them
are either missing or 0 and the VAT turnover associated with them gets lost. But the number 
of vat reporters is wrongly blown up, as the code actually counts the number of rows which
are representing the fact that 1 representative VAT reference may be associated with more 
than one enterprise*/

proc sql;

create table vat.linking_vat_ent as
select a.period,
       a.vat_reporters,
       a.reported_to,
	   b.linked_reps,
	   b.transfered_to,
	   a.vat_reporters  - b.linked_reps as missing_reps,
       (a.reported_to - b.transfered_to)/b.transfered_to as per_lost_to
from vat_reporters a left join 
     link_reporters b
on a.period = b.period;

quit;

%mend;

%macro severing_vat_ent_link (minp=,maxp=);

proc sql;
create table check_for_dup 
(period num,
 vat_ent_to num format=d24.);
quit;

%do period =&minp. %to &maxp.;

proc sql;

alter table vat.vat_ent_rp_&Period.
add entref_stag char(12),
    freq_rep char(1);

update vat.vat_ent_rp_&Period.
set freq_rep = 'm' 
where stagger = 0;

update vat.vat_ent_rp_&Period.
set freq_rep = 'q' 
where stagger between 1 and 3;

update vat.vat_ent_rp_&Period.
set freq_rep = 'a' 
where stagger gt 3;

update vat.vat_ent_rp_&Period.
set entref_stag = entref||'_'||freq_rep;

quit;

data vat.ve_complex_&Period.
     vat.ve_simple_&Period.;
set vat.vat_ent_rp_&Period.;

if case_ve = 'complex' then output vat.ve_complex_&Period.;
if case_ve = 'simple' then output vat.ve_simple_&Period.;

run;

proc sql;

create table ve_complex_&period. as
select entref_stag,
       max(arrivalperiod) as arrivalperiod,
	   sum(vat_ent_to) as vat_ent_to
from vat.ve_complex_&period.
group by entref_stag;

create table veto_complex_&period. as
select &period. as refperiod,
       substr(entref_stag,1,10) as entref,
	   substr(entref_stag,12,1) as freq_rep,
	   arrivalperiod,
       vat_ent_to,
	   'complex' as case_ve
from ve_complex_&period.;

insert into check_for_dup
select &period.,
       sum(vat_ent_to)
from veto_complex_&period.;

create table veto_simple_&period. as
select &period. as refperiod,
       substr(entref_stag,1,10) as entref,
	   substr(entref_stag,12,1) as freq_rep,
	   arrivalperiod,
       vat_ent_to,
	   'simple' as case_ve
from vat.ve_simple_&Period.;

insert into check_for_dup
select &period.,
       sum(vat_ent_to)
from veto_simple_&period.;

alter table vat.vat_ent_rp_&Period.
drop entref_stag,
     freq_rep;

quit;

data veto_&period;
set veto_complex_&period.
    veto_simple_&period.;
run;

proc sql;

create table vat.veto_&period as
select a.*,
       b.rx_period
from veto_&period. a left join
     vat.vat_ent_rp_&Period. b
on a.entref = b.entref
where b.rx_period ne .; 

quit;

%end;/*period*/

proc sql;

Create table chk_for_dup as
Select period,
      Sum(vat_ent_to) as vat_ent_to
From check_for_dup
Group by period;

create table vat.check_severing as
select a.period,
       a.vat_ent_to - b.transfered_to as check
from chk_for_dup a left join
     vat.Linking_vat_ent b
on a.period = b.period;

quit;

%mend;
%macro populating_ruto (period=);

proc sql;

create table find_entrefs as
select distinct  entref,
          rx_period
from ruto_&period. 
where ruref = '';

create table where_to_look as
select distinct rx_period
from ruto_&period.
where ruref = '';

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

			create table data_pool as
			select distinct entref,
				   ruref,
				   current_empment,
				   current_reg_to,
				   current_SIC07,
				   legal_status,
				   ent_empment,
				   division,
				   section,
				   empband,
				   class,
				   frozen_empment,
				   frozen_reg_to,
				   frozen_sic07,
				   frozen_sic03,
				   current_sic03,
			       live_lu,
				   emp_proportion
			from vat.rx_&&p_to_lookin&i..
			where entref in (select entref from find_entrefs 
			                 where rx_period = &&p_to_lookin&i.. );

			insert into rows_to_replace
			select distinct a.*,
			       b.refperiod,
				   b.arrivalperiod,
				   b.freq_rep,
				   b.vat_ent_to,
				   b.vat_ent_to*a.emp_proportion as ru_vat_to,
				   b.case_ve,
				   b.rx_period  
			from data_pool a left join
			     ruto_&period. b
			on a.entref = b.entref
			where b.ruref = ''; 

		quit;
	%end; /*i*/
%end;/*if*/
%mend;

%macro linking_with_ru (minp=,maxp=);

proc sql;

create table lost_rx_data
(period num,
 pattern char(1),
 ents_not_on_rx num,
 lost_vat_to num format = d16.);

create table found_rx_data
(period num,
 pattern char(1),
 ents_on_rx num,
 found_vat_to num format = d16.);

quit;


%do period =&minp. %to &maxp.;

proc sql;

create table ruto_&period. as
select distinct b.entref,
	   a.ruref,
	   a.current_empment,
	   a.current_reg_to,
	   a.current_SIC07,
	   a.legal_status,
	   a.ent_empment,
	   a.division,
	   a.section,
	   a.empband,
	   a.class,
	   a.frozen_empment,
	   a.frozen_reg_to,
	   a.frozen_sic07,
	   a.frozen_sic03,
	   a.current_sic03,
       a.live_lu,
	   a.emp_proportion,
	   b.refperiod,
	   b.arrivalperiod,
	   b.freq_rep,
	   b.vat_ent_to,
	   b.vat_ent_to*a.emp_proportion as ru_vat_to,
	   b.case_ve,
	   b.rx_period
from vat.rx_&period. a right join
     vat.veto_&period. b
on a.entref = b.entref;

create table rows_to_replace like ruto_&period.;

quit;

%populating_ruto (period=&period.);

proc sql;
create table lost_vat_&period. as
select distinct entref,
	            refperiod,
	            freq_rep,
	            vat_ent_to
from ruto_&period.
where ruref = '';

delete from ruto_&period.
where ruref = '';

insert into ruto_&period.
select * from rows_to_replace;

insert into lost_rx_data
select distinct &period. as period,
                freq_rep as pattern,
	            count(distinct entref) as ents_not_on_rx,
	            sum(vat_ent_to) as lost_vat_to
from lost_vat_&period.
group by freq_rep;

insert into found_rx_data
select distinct &period. as period,
                freq_rep as pattern,
	            count(distinct entref) as ents_on_rx,
	            sum(ru_vat_to) as found_vat_to
from rows_to_replace
group by freq_rep;

alter table ruto_&period.
Add original_ru_vat_to num,
        clean_marker num;

update ruto_&period.
Set  original_ru_vat_to = ru_vat_to,
        clean_marker = 0;

create table assess_comp as
select entref,
       count(ruref) as associated_rus
from ruto_&period.
Group by entref;

Alter table ruto_&period.
Add case_er char(7);

Update ruto_&period.
Set case_er = 'simple';

Update ruto_&period.
Set case_er = 'complex'
Where entref in (select entref 
                 from assess_comp 
                 where associated_rus gt 1);

quit;

/*splitting complex and simple*/

data vat.ruto_simple_a&period.
     vat.ruto_simple_q&period.
	 vat.ruto_simple_m&period.
     vat.ruto_complex_a&period.
     vat.ruto_complex_q&period.
     vat.ruto_complex_m&period.;
set ruto_&period;

if (case_ve = 'simple') and (case_er = 'simple') then do;
	select;
		when (freq_rep = 'a') output vat.ruto_simple_a&period.;
		when (freq_rep = 'q') output vat.ruto_simple_q&period.;
		when (freq_rep = 'm') output vat.ruto_simple_m&period.;
		otherwise;
	end;/*select*/
end;/*if do*/
else do;
	select;
		when (freq_rep = 'a') output vat.ruto_complex_a&period.;
		when (freq_rep = 'q') output vat.ruto_complex_q&period.;
		when (freq_rep = 'm') output vat.ruto_complex_m&period.;
		otherwise;
	end;/*select*/
end;/*else do*/

run;

%end;/*period*/

proc sql;

create table vat.check_vr_linking as
select a.*,
       b.ents_on_rx,
	   b.found_vat_to,
	   a.ents_not_on_rx - b.ents_on_rx as unit_diff,
       a.lost_vat_to - b.found_vat_to as to_diff
from lost_rx_data a left join
     found_rx_data b
on a.period = b.period
and a.pattern = b.pattern;

quit;
%mend;

%macro check_vat_ru (minp=, maxp=);

proc sql;

create table vat.check_vr_link
(period num,
 ruvat_to num);

quit;

%do period = &minp. %to &maxp.;

proc sql;

insert into vat.check_vr_link
select &period.,
       sum(ru_vat_to)
from ruto_&period.;

quit;

%end;/*period*/

%mend;

