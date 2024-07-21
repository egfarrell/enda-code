%macro topping_up_sic07 (period=);

/* This macro is topping up the missing SIC 07 classification codes
using the conversion matrix to translate the SIC 03 codes into SIC 07 ones*/

proc sql;

create table rx_missing07 as
select ruref,
       current_sic03,
	   frozen_sic03,
	   current_sic07,
	   frozen_sic07,
	   RAND('UNIFORM') as r_weight
from rx2&period.
where compress(current_sic07) in ('0.', '00000');


create table rx_03tr07 as
select a.ruref,
       a.current_sic03,
	   a.frozen_sic03,
	   compress(put(b.sic07, 8.)) as trans_sic07,
	   abs(a.r_weight - b.weight) as choice
from rx_missing07 a left join
     vat.conv_matrix b
on a.current_sic03 = compress(put(b.sic03, 8.));

create table rx_03tr07_l as
select ruref,
       min(choice) as chosen
from rx_03tr07
group by ruref;

create table rx_03tr07_i as
select a.ruref,
       a.trans_sic07,
       RAND('UNIFORM') as r_choice
from rx_03tr07 a right join 
     rx_03tr07_l b
on a.ruref = b.ruref and
   a.choice = b.chosen;

create table rx_03tr07_ll as
select ruref,
       min(r_choice) as chosen
from rx_03tr07_i
group by ruref;

create table rx_03tr07_f as
select a.ruref,
       a.trans_sic07
from rx_03tr07_i a right join 
     rx_03tr07_ll b
on a.ruref = b.ruref and
   a.r_choice = b.chosen;

create table rx3&period. as
select a.entref,
       a.ruref,
	   a.current_empment,
	   a.current_reg_to,
       case 
	    	when compress(a.current_sic07) in ('0.', '00000') then b.trans_sic07
			else a.current_SIC07
       end as current_SIC07,
	   a.legal_status,
	   a.live_lu,
	   a.live_vat,
	   a.frozen_empment,
       case 
	    	when compress(a.frozen_sic07) in ('0.', '00000') then b.trans_sic07
			else a.frozen_SIC07
       end as frozen_SIC07,
	   a.frozen_SIC03,
	   a.current_SIC03,
	   a.frozen_reg_to,
	   a.inq_stop,
	   a.gor,
	   a.ssr
	from rx2&period. a left join
     rx_03tr07_f b
on a.ruref = b.ruref;

quit;

%mend;

%macro harmonise_repex(endd=);

	data _null_;
		set vat.vat_per_lookup end=finish;
		call symput('vat_per'!!compress(_N_),trim(left(period_vat)));
		call symput('full_per'!!compress(_N_),trim(left(full_period)));
		call symput('repex_layout'!!compress(_N_),trim(left(repex_layout)));
		if finish = 1 then call symputx('period_num',_N_);
	run;


%do i = 1 %to  &period_num.;

	%if ^%sysfunc(exist(vat.rx_&&vat_per&i)) %then %do;

/*--------------------------------------------------------------------------------*/
		%if &&repex_layout&i.. = 1 %then %do;

			proc sql;

			create table tmp_rx&&vat_per&i.. as
			select compress(put(entref, d10.)) as entref,
			       compress(put(ruref, d11.)) as ruref,
				   curempm as current_empment,
				   curturn as current_reg_to,
				   '00000' as current_SIC07,
			       compress(put(status, 8.)) as legal_status,
				   livelu as live_lu,
				   livevat as live_vat,
				   froempm as frozen_empment,
				   '00000' as frozen_SIC07,
				   compress(put(frosic03, 8.)) as frozen_SIC03,
				   compress(put(cursic03, 8.)) as current_SIC03,
				   froturn as frozen_reg_to,
				   compress(put(inqstop, 8.)) as inq_stop,
				   gor,
				   ssr
			from vat.rx&&full_per&i..
			where substr(compress(put(ruref, d11.)),1,1) ne '6'
			and inqcode = 999;

			/*the rurefs starting with 6 
			are enterprise_group reporters and they will overlap with the RUs having 
			references that strat with 4 or 5 linked to the same enterprise.*/

			quit;

			%end;/*repex_layout = 1*/

			%if &&repex_layout&i.. = 2 %then %do;

			proc sql;

			create table tmp_rx&&vat_per&i.. as
			select compress(put(entref, d10.)) as entref,
			       compress(put(ruref, d11.)) as ruref,
				   curempm as current_empment,
				   curturn as current_reg_to,
				   compress(put(cursic07, 8.)) as current_SIC07,
			       compress(put(status, 8.)) as legal_status,
				   livelu as live_lu,
				   livevat as live_vat,
				   froempm as frozen_empment,
				   compress(put(frosic07, 8.)) as frozen_SIC07,
				   compress(put(frosic03, 8.)) as frozen_SIC03,
				   compress(put(cursic03, 8.)) as current_SIC03,
				   froturn as frozen_reg_to,
				   compress(put(inqstop, 8.)) as inq_stop,
				   gor,
				   ssr
			from vat.rx&&full_per&i..
			where substr(compress(put(ruref, d11.)),1,1) ne '6'
			and inqcode = 999;/*the rurefs starting with 6 
			are enterprise_group reporters and they will overlap with the RUs having 
			references that strat with 4 or 5 linked to the same enterprise.*/

			quit;
			%end;/*repex_layout = 2*/

			%if &&repex_layout&i.. = 3 %then %do;
			proc sql;

			create table tmp_rx&&vat_per&i.. as
			select compress(put(entref, d10.)) as entref,
			       ruref,
				   curempm as current_empment,
				   curturn as current_reg_to,
				   compress(put(cursic07, 8.)) as current_SIC07,
			       compress(put(status, 8.)) as legal_status,
				   livelu as live_lu,
				   livevat as live_vat,
				   froempm as frozen_empment,
				   compress(put(frosic07, 8.)) as frozen_SIC07,
				   compress(put(frosic03, 8.)) as frozen_SIC03,
				   compress(put(cursic03, 8.)) as current_SIC03,
				   froturn as frozen_reg_to,
				   compress(put(inqstop, 8.)) as inq_stop,
				   gor,
				   ssr
			from vat.rx&&full_per&i..
			where substr(compress(ruref),1,1) ne '6'
			and inqcode = 999;

			quit;
			%end;/*repex_layout = 3*/

			%if &&repex_layout&i.. = 4 %then %do;
			proc sql;

			create table tmp_rx&&vat_per&i.. as
			select entref,
			       ruref,
				   curempment as current_empment,
				   curturn as current_reg_to,
				   cursic07 as current_SIC07,
			       status as legal_status,
				   livelu as live_lu,
				   livevat as live_vat,
				   froempment as frozen_empment,
				   frosic07 as frozen_SIC07,
				   frosic03 as frozen_SIC03,
				   cursic03 as current_SIC03,
				   froturn as frozen_reg_to,
				   inqstop as inq_stop,
				   gor,
				   ssr
			from vat.rx&&full_per&i..
			where substr(compress(ruref),1,1) ne '6'
			and inqcode = '999';

			quit;
			%end;/*repex_layout = 4*/

			%if &&repex_layout&i.. = 5 %then %do;

			proc sql;

			create table tmp_rx&&vat_per&i.. as
			select compress(put(entref, d10.)) as entref,
			       compress(put(ruref, d11.)) as ruref,
				   curempm as current_empment,
				   curturn as current_reg_to,
				   compress(put(cursic07, 8.)) as current_SIC07,
			       compress(put(status, 8.)) as legal_status,
				   livelu as live_lu,
				   livevat as live_vat,
				   froempm as frozen_empment,
				   compress(put(frosic07, 8.)) as frozen_SIC07,
				   compress(put(frosic03, 8.)) as frozen_SIC03,
				   compress(put(cursic03, 8.)) as current_SIC03,
				   froturn as frozen_reg_to,
				   inqstop as inq_stop,
				   gor,
				   ssr
			from vat.rx&&full_per&i..
			where substr(compress(put(ruref, d11.)),1,1) ne '6'
			and inqcode = 999;/*the rurefs starting with 6 
			are enterprise_group reporters and they will overlap with the RUs having 
			references that strat with 4 or 5 linked to the same enterprise.*/

			quit;
			%end;/*repex_layout = 5*/

		/* keep only alive units - things that have died within the last month? */
		proc sql;
			create table rx&&vat_per&i..
			as select a.*, b.ruref, b.deathdate
			from tmp_rx&&vat_per&i.. as a
			left join vat.repunit&endd. as b
			on a.ruref=b.ruref
			where b.deathdate in (. '')
		quit;


			data rx2&&vat_per&i..;
			set rx&&vat_per&i..;

			select;
				when ((frozen_sic07 ne .) and (current_sic07 eq .)) current_sic07 = frozen_sic07;
				when ((frozen_sic07 eq .) and (current_sic07 ne .)) frozen_sic07 = current_sic07;
				when ((frozen_sic03 ne .) and (current_sic03 eq .)) current_sic03 = frozen_sic03;
				when ((frozen_sic03 eq .) and (current_sic03 ne .)) frozen_sic03 = current_sic03;
				otherwise;
			end;

			if length(compress(current_SIC07)) lt 5 then current_sic07 = compress('0'||current_sic07);
			if length(compress(frozen_SIC07)) lt 5 then frozen_sic07 = compress('0'||frozen_sic07);

			run;

			%topping_up_sic07 (period=&&vat_per&i..);

			data rx_t&&vat_per&i.. (drop = sec2 emp2);
			set rx3&&vat_per&i.. ;

			if length(compress(current_SIC07)) lt 5 then current_sic07 = compress('0'||current_sic07);
			if length(compress(frozen_SIC07)) lt 5 then frozen_sic07 = compress('0'||frozen_sic07);

			division = substr(current_SIC07,1,2);

			select;
				when (division in ('01' '02' '03')) section = 'A' ;
				when (division in ('05' '06' '07' '08' '09')) section = 'B' ;
				when (division in ('10' '11' '12' '13' '14'
			                       '15' '16' '17' '18' '19'
			                       '20' '21' '22' '23' '24'
			                       '25' '26' '27' '28' '29'
			                       '30' '31' '32' '33')) section = 'C' ;
				when (division ='35') section = 'D' ;
				when (division in ('36' '37' '38' '39')) section = 'E' ;
				when (division in ('41' '42' '43')) section = 'F' ;
				when (division in ('45' '46' '47')) section = 'G' ;
				when (division in ('49' '50' '51' '52' '53')) section = 'H' ;
				when (division in ('55' '56')) section = 'I' ;
				when (division in ('58' '59' '60' '61' '62' '63')) section = 'J' ;
				when (division in ('64' '65' '66')) section = 'K' ;
				when (division ='68') section = 'L' ;
				when (division in ('69' '70' '71' '72' '73' '74' '75')) section = 'M' ;
				when (division in ('77' '78' '79' '80' '81' '82')) section = 'N' ;
				when (division ='84') section = 'O' ;
				when (division ='85') section = 'P' ;
				when (division in ('86' '87' '88')) section = 'Q' ;
				when (division in ('90' '91' '92' '93')) section = 'R' ;
				when (division in ('94' '95' '96')) section = 'S' ;
				when (division in ('97' '98')) section = 'T' ;
				when (division ='99') section = 'U' ;
				otherwise;
			end;

			select;
			    when (0<=current_empment<10) empband='1';
				when (10<=current_empment<50) empband='2';
				when (50<=current_empment<100) empband='3';
				when (current_empment>=100) empband='4';
				otherwise;
			end;

				if section in('A','B') then sec2='A_B';
				else sec2=section;
				if section in('J','M', 'N') and empband in('2','3') then emp2='2';
				else emp2=empband; 

				class=compress(sec2||'_'||emp2);
			run;

			proc sql;

			create table ent_emp_&&vat_per&i.. as
			select entref,
			       sum(current_empment) as ent_empment
			from rx_t&&vat_per&i..
			group by entref;

			create table transite as
			select a.*,
			       b.ent_empment,
			       case 
				   		when b.ent_empment ne 0 then a.current_empment/b.ent_empment
						else 0
			       end as emp_proportion
			from rx_t&&vat_per&i.. a left join
			     ent_emp_&&vat_per&i.. b
			on a.entref = b.entref;

			create table vat.rx_&&vat_per&i.. as
			select * from transite;

			quit;

			proc delete data = transite; run;
			proc delete data = rx&&vat_per&i..; run;
			proc delete data = rx2&&vat_per&i..; run;
			proc delete data = rx3&&vat_per&i..; run;
			proc delete data = rx_t&&vat_per&i..; run;
			proc delete data = vat.rx&&full_per&i..; run;

/*--------------------------------------------------------------------------------*/
	%end; /*if vat.rx_XXX doesn't exist*/
%end; /*i*/

proc delete data = Rx_03tr07; run;
proc delete data = Rx_03tr07_f; run;
proc delete data = Rx_03tr07_i; run;
proc delete data = Rx_03tr07_l; run;
proc delete data = Rx_03tr07_ll; run;

%mend;

%macro vatent_read_in;

	data _null_;
		set vat.Vat_ent_lookup end=finish;
		call symput('extract_per'!!compress(_N_),trim(left(extract_period)));
		call symput('vat_per'!!compress(_N_),trim(left(period_vat)));
		call symput('layout'!!compress(_N_),trim(left(extract_layout)));
		if finish = 1 then call symputx('period_num',_N_);
	run;


%do i = 1 %to &period_num.;
	
	%if ^%sysfunc(exist(vat.vatent_&&extract_per&i..)) %then %do;

		%put file to be imported vatunit_&&extract_per&i.. ; 

			filename ve&&extract_per&i.. "&task_path.\vatunit_&&extract_per&i..";
			data vatent_&&extract_per&i..;
			infile ve&&extract_per&i..;
			input 
			entref $ 1-10 
			vatref9 $ 12-20;

			vat_period = &&vat_per&i..;

			run;

	%end; /*if vat.vatent_&&extract_per&i doesn't exists */
%end; /*i*/

%mend;

%macro ve_tidy_up;

data _null_;
	set vat.Vat_ent_lookup end=finish;
	call symput('extract_per'!!compress(_N_),trim(left(extract_period)));
	if finish = 1 then call symputx('period_num',_N_);
run;

%do i = 1 %to &period_num.;

	%if ^%sysfunc(exist(vat.vatent_&&extract_per&i..)) %then %do;

		proc sql;

		create table ve_&&extract_per&i.. as
		select *,
		       compress(vatref9||'_'||entref) as veref
		from vatent_&&extract_per&i
		order by calculated veref;

		quit;

		data vat.vatent_&&extract_per&i.. (drop = marker);
		set ve_&&extract_per&i..;
		by veref;

		if first.veref then marker = 0;
		else marker = 1;

		if marker = 0;

		run;
	%end; /*if vat.vatent_&&extract_per&i.. doesn't exists */
%end;

%mend;


%macro ent_emp_in_ve;

/*this macro will populate the VAT unit extracts with enterprise employment;
                  and calculate the proportion of the emplyment
                  in each enterprise as part of a vat representative*/

/*all the repex files have to be already read in and enterprise employment summaries 
  (ent_emp_&period.) created from them*/

/*the VAT unit extracts are created at different time and lesser frequency than the repext files,
  so the minimum time distance will be used when populating the VATent tables with ent_empment.*/

/*A rx_pool will be created containing the entrefs and the corresponding employment 
  at each point in time from all the repext files covering the period of interest (2007 - 2013)*/

/*the VAT ent table will pick the ent_empment from the pool for the corresponding entref 
  and min distance between the period of the VAT unit extract and the repext*/


data _null_;
	set vat.Vat_ent_lookup end=finish;
	call symput('vat_period'!!compress(_N_),trim(left(period_vat)));
	call symput('extract_per'!!compress(_N_),trim(left(extract_period)));
	if finish = 1 then call symputx('period_num',_N_);
run;

%do i = 1 %to &period_num.;

%if &i. = 1 %then %do;
	%let b = &i ;
	%let f = %eval(&i + 1);
%end;

%if (&i. gt 1) and (&i. lt &period_num.) %then %do;
	%let b = %eval(&i. - 1);
	%let f = %eval(&i. + 1);
%end;

%if &i. = &period_num. %then %do;
	%let b = %eval(&i. - 1) ;
	%let f = &i.;
%end;

%put start from &&vat_period&b.. to &&vat_period&f..;

proc sql;

create table rx_pool_&&extract_per&i..
(entref char(12),
 ent_empment num,
 rx_period num,
 ve_rx_dist num);

 quit;

%do period = &&vat_period&b.. %to &&vat_period&f..;

proc sql;

insert into rx_pool_&&extract_per&i..
select distinct entref as entref,
       ent_empment as ent_empment,
       &period. as rx_period,
	   %eval(&&vat_period&i.. - &period.) as ve_rx_dist
from  vat.rx_&period.;

quit;

/*proc delete data = ent_emp_&period.;run;*/

%end;/*period*/

proc sql;

create table ents_in_&&extract_per&i.. as
select entref,
	   min(abs(ve_rx_dist)) as min_dist
from rx_pool_&&extract_per&i.. 
group by entref;

create table rx_data_&&extract_per&i.. as
select b.entref,
       a.ent_empment,
       a.rx_period,
       b.min_dist*sign(a.ve_rx_dist) as min_dist
from ents_in_&&extract_per&i.. b left join
     rx_pool_&&extract_per&i.. a     
on   b.entref = a.entref 
and  b.min_dist*sign(a.ve_rx_dist) = a.ve_rx_dist;

create table ents_in_&&extract_per&i.. as
select entref,
	   max(min_dist) as best_dist
from rx_data_&&extract_per&i.. 
group by entref;

create table rx_pool_&&extract_per&i.. as
select b.entref,
       a.ent_empment,
       a.rx_period,
       b.best_dist
from ents_in_&&extract_per&i.. b left join
     rx_data_&&extract_per&i.. a     
on   b.entref = a.entref 
and  b.best_dist = a.min_dist;


create table vat.ve_&&extract_per&i.. as
select a.*,
       b.*
from vat.vatent_&&extract_per&i.. a left join
     rx_pool_&&extract_per&i.. b
on   a.entref = b.entref;

quit;

proc delete data = ents_in_&&extract_per&i..; run;
proc delete data = rx_pool_&&extract_per&i..; run;
proc delete data = rx_data_&&extract_per&i..; run;

%end; /*i*/

%mend;

%macro ve_employment;

data _null_;
	set vat.Vat_ent_lookup end=finish;
	call symput('extract_per'!!compress(_N_),trim(left(extract_period)));
	if finish = 1 then call symputx('period_num',_N_);
run;

%do i = 1 %to &period_num.;

proc sql;

create table vat9_empment as
select vatref9,
       sum(ent_empment) as vat9_empment
from vat.ve_&&extract_per&i..
group by vatref9;

create table vat.vatent_&&extract_per&i.. as
select a.*,
       case
       	when b.vat9_empment not in (0, .) then a.ent_empment/b.vat9_empment
	   	else 0
	   end as emp_proportion
from vat.ve_&&extract_per&i.. a left join 
     vat9_empment b
on a.vatref9 = b.vatref9
where rx_period ne .;

/*classify the VAT-Enterprise relation as simple or complex*/

create table m_to_1 as
select entref,
       count(vatref9) as vat9_instances
from vat.vatent_&&extract_per&i..
group by entref
having calculated vat9_instances = 1;

create table m_to_one as
select a.*,
       b.vatref9 
from m_to_1 a left join
     vat.vatent_&&extract_per&i.. b
on a.entref = b.entref;

create table one_to_m as
select vatref9,
       count(vatref9) as vat9_instances
from vat.vatent_&&extract_per&i..
group by vatref9
having calculated vat9_instances = 1;

create table one_to_one as
select *
from m_to_one 
where vatref9 in (select vatref9 from one_to_m);

alter table vat.vatent_&&extract_per&i..
add case_ve char(7);

update vat.vatent_&&extract_per&i..
set case_ve='simple';

update vat.vatent_&&extract_per&i..
set case_ve='complex'
where entref not in (select entref from one_to_one) ;    

quit;

proc delete data = vat.ve_&&extract_per&i..; run;

%end;

proc delete data = vat9_empment; run;
proc delete data = m_to_1; run;
proc delete data = m_to_one; run;
proc delete data = one_to_m; run;
proc delete data = one_to_one; run;

%mend;
