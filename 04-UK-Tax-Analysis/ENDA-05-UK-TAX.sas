
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */

%macro simple_complex_back_together (minp=, maxp=);
    /*
       just combine all the:
        'ruto_simple_*'
        'ruto_complex_*'
       files back into 'ruto_"pattern"_period' files...
    */

    %do period = &minp. %to &maxp.;
            %do i = 1 %to 3;
                %if &i. = 1 %then %let patt = m;
                %if &i. = 2 %then %let patt = q;
                %if &i. = 3 %then %let patt = a;

                data STAGE17.ruto_&patt.&period.;
                    set STAGE13.ruto_simple_&patt.&period.
                        STAGE13.ruto_complex_&patt.&period.;
                run;

                /*
                   proc delete  data=STAGE13.ruto_simple_&patt.&period.;    run;
                   proc delete  data=STAGE13.ruto_complex_&patt.&period.;   run;
                */
            %end;
    %end;

%mend simple_complex_back_together;




%macro transform_p_to_m (minp=,maxp=);

    /*
       monthly   cases -   just take the reported turnover
       quarterly cases -   divide turnover by 3
       annual    cases -   divide turnover by 12
    */

    %do period = &minp. %to &maxp.;

            /*
               MONTHLY REPORTS
               MONTHLY REPORTS
               MONTHLY REPORTS
            */
            PROC SQL;
                /* create table vat.month_&period. (ruref           char(12), */
                create table STAGE18.month_&period. (ruref           char(12),
                                                    refperiod       num,
                                                    arrivalperiod   num,
                                                    rx_period       num,
                                                    comp_ve         num,
                                                    comp_er         num,
                                                    ru_vat_to       num,
                                                    raw_ru_vat_to   num,
                                                    clean_marker    num
                                                    );



                /* insert into vat.month_&period. */
                insert into STAGE18.month_&period.
                    select ruref,
                           &period                  as refperiod,
                           arrivalperiod,
                           rx_period,
                           case
                               when compress(case_ve) = 'complex'
                               then 1
                               else 0
                           end                      as comp_ve,
                           case
                               when compress(case_er) = 'complex'
                               then 1
                               else 0
                           end                      as comp_er,
                           ru_vat_to,
                           original_ru_vat_to       as raw_ru_vat_to,
                           clean_marker
                    /* from ruto_m&period.; */
                    from STAGE17.ruto_m&period.;
            QUIT;

            /* %put monthly reports
                    inserted into vat.month_&period.
                    from ruto_m&period.;
            */
            %put monthly reports inserted into STAGE18.month_&period. from STAGE17.ruto_m&period.;



            /*
               QUARTERLY REPORTS - divide turnover by 3!
               QUARTERLY REPORTS - divide turnover by 3!
               QUARTERLY REPORTS - divide turnover by 3!
            */
            %do q = 0 %to 2;
                    %let i = %eval(&period. - &q.);

                    %if &i  GE  &minp  %then
                    %do;
                        PROC SQL;
                            /* insert into vat.month_&i. */
                            insert into STAGE18.month_&i.
                                select ruref,
                                        &i.                          as refperiod,
                                        arrivalperiod,
                                        rx_period,
                                        case
                                            when compress(case_ve) = 'complex'
                                            then 1
                                            else 0
                                        end                          as comp_ve,
                                        case
                                            when compress(case_er) = 'complex'
                                            then 1
                                            else 0
                                        end                          as comp_er,
                                        ru_vat_to / 3                as ru_vat_to,
                                        original_ru_vat_to / 3       as raw_ru_vat_to,
                                        clean_marker
                                from   STAGE17.ruto_q&period.;
                        QUIT;
                        %put quarterly reports inserted into STAGE18.month_&i. from STAGE17.ruto_q&period.;
                    %end;
                    %else
                        %put no earlier months;

            %end; * quarterly loop ;



            /*
               ANNUAL REPORTS - divide turnover by 12!
               ANNUAL REPORTS - divide turnover by 12!
               ANNUAL REPORTS - divide turnover by 12!
            */
            %do a = 0 %to 11;
                    %let j = %eval(&period - &a);

                    %if &j  ge &minp  %then
                        %do;
                            proc sql;
                                /* insert into vat.month_&j. */
                                insert into STAGE18.month_&j.
                                    select ruref,
                                        &j.                      as refperiod,
                                        arrivalperiod,
                                        rx_period,
                                        case
                                            when compress(case_ve) = 'complex'
                                            then 1
                                            else 0
                                        end                      as comp_ve,
                                        case
                                            when compress(case_er) = 'complex'
                                            then 1
                                            else 0
                                        end                      as comp_er,
                                        ru_vat_to / 12           as ru_vat_to,
                                        original_ru_vat_to / 12  as raw_ru_vat_to,
                                        clean_marker
                                    /* from   ruto_a&period.; */
                                    from   STAGE17.ruto_a&period;
                            quit;
                            /* %put annual reports inserted into vat.month_&j. from ruto_a&period.; */
                            %put annual reports inserted into STAGE18.month_&j. from STAGE17.ruto_a&period.;
                        %end;
                    %else
                        %put no earlier months;

            %end; * annual loop ;


    %end; * outer period loop;


%mend transform_p_to_m;





/* nested macro: called from 'consolidate' */
%macro populating_ruvatto (period=);

    PROC SQL;
            /* get 'ruref' for blank divisions */
            create table STAGE19.find_rurefs        as
                                                    select  distinct ruref,
                                                            rx_period
                                                    from    STAGE19.ru_vat_to_m&period.
                                                    where   division = '';


            /* get 'rx_period' for blank divisions */
            create table STAGE19.where_to_look      as
                                                    select  distinct rx_period
                                                    from    STAGE19.ru_vat_to_m&period.
                                                    where   division = '';


            create table STAGE19.data_pool          (
                                                        ruref             char(12),
                                                        legal_status      char(1),
                                                        division          char(8),
                                                        section           char(1),
                                                        empband           char(1),
                                                        class             char(5),
                                                        frozen_empment    num,
                                                        current_empment   num,
                                                        frozen_reg_to     num,
                                                        current_reg_to    num,
                                                        frozen_SIC07      char(8),
                                                        current_SIC07     char(8),
                                                        live_lu           num,
                                                        gor               char(1),   /*Mila: added on 12062015*/
                                                        ssr               char(1)    /*Mila: added on 12062015*/
                                                    );


            create table STAGE19.rows_to_replace    like STAGE19.ru_vat_to_m&period.;
    QUIT;


    /* any Vat Periods where division = '' */
    PROC SQL NOPRINT;
            select nobs
            into   :periods_to_check
            from   dictionary.tables
            /* where  libname = 'WORK' */
            where  libname = 'STAGE19'
            and    memname = 'WHERE_TO_LOOK';
    QUIT;


    %if &periods_to_check. GT 0 %then
    %do;
            DATA _NULL_;
                set STAGE19.where_to_look end=finish;

                call symput('p_to_lookin' || compress(_N_),  trim(left(rx_period)));

                if finish = 1 then
                call symputx('last_num', _N_);
            RUN;


            %do i = 1 %to &last_num.;
                    PROC SQL;
                        insert into STAGE19.data_pool    select ruref,
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
                                                                gor,
                                                                ssr
                                                      /* from   vat.rx_&&p_to_lookin&i.. */
                                                         from   STAGE06.rx_&&p_to_lookin&i..
                                                         where  ruref in (select ruref
                                                                          from   STAGE19.find_rurefs
                                                                          where  rx_period = &&p_to_lookin&i.. );

                    QUIT;

            %end;

            PROC SQL;
                insert into STAGE19.rows_to_replace         select   a.ruref,
                                                                     a.refperiod,
                                                                     a.arrivalperiod,
                                                                     a.rx_period,
                                                                     case
                                                                         when a.complexity gt 0
                                                                         then 'complex'
                                                                         else 'simple'
                                                                     end                          as complexity,
                                                                     b.legal_status,
                                                                     b.division,
                                                                     b.section,
                                                                     b.empband,
                                                                     b.class,
                                                                     b.frozen_empment,
                                                                     b.current_empment,
                                                                     (b.frozen_reg_to  * 1000) / 12    as monthly_fr_reg_to,
                                                                     (b.current_reg_to * 1000) / 12    as monthly_reg_to,
                                                                     b.current_SIC07,
                                                                     b.frozen_SIC07,
                                                                     b.live_lu,
                                                                     a.ru_vat_to,
                                                                     a.raw_ru_vat_to,
                                                                     a.clean_marker,
                                                                     b.gor,
                                                                     b.ssr
                                                        from         STAGE19.data_pool        b
                                                        left join    STAGE19.vat_to_&period.  a
                                                        on           b.ruref = a.ruref;


            QUIT;

    %end; * if there are rows in where to look ;

%mend populating_ruvatto;



/* stage 19 */
%macro consolidate(minp=, maxp=);
    PROC SQL;
            create table STAGE19.before_replacement   (
                                                      period num,
                                                      vat_to_before num
                                                      );


            create table STAGE19.after_replacement   (
                                                     period num,
                                                     vat_to_after num
                                                     );
    QUIT;


    %do period = &MinP  %to &MaxP ;

            PROC SQL;

                /*
                   'STAGE19.vat_to_...' is created from 'STAGE18.month_&period'
                */
                create table STAGE19.vat_to_&period.      as
                                                          select   ruref,
                                                                   &period.                   as refperiod,
                                                                   max(arrivalperiod)         as arrivalperiod,
                                                                   max(rx_period)             as rx_period,
                                                                   sum(comp_ve)+ sum(comp_er) as complexity,
                                                                   count(ruref)               as vat_reporters,
                                                                   sum(ru_vat_to)             as ru_vat_to,
                                                                   sum(raw_ru_vat_to)         as raw_ru_vat_to,
                                                                   max(clean_marker)          as clean_marker
                                                       /* from     vat.month_&period.                            */
                                                          from     STAGE18.month_&period.
                                                          group by ruref;



                insert into STAGE19.before_replacement    select   &period.        as period,
                                                                   sum(ru_vat_to)  as vat_to_before
                                                          from     STAGE19.vat_to_&period;



                /* turnover: multiply by 1000, divide by 12 */
                create table STAGE19.ru_vat_to_m&period.  as
                                                          select     a.ruref,
                                                                     a.refperiod,
                                                                     a.arrivalperiod,
                                                                     a.rx_period,
                                                                     case
                                                                         when a.complexity gt 0
                                                                         then 'complex'
                                                                         else 'simple'
                                                                     end                               as complexity,
                                                                     b.legal_status,
                                                                     b.division,
                                                                     b.section,
                                                                     b.empband,
                                                                     b.class,
                                                                     b.frozen_empment,
                                                                     b.current_empment,
                                                                     (b.frozen_reg_to  * 1000) / 12    as  monthly_fr_reg_to,
                                                                     (b.current_reg_to * 1000) / 12    as  monthly_reg_to,
                                                                     b.current_SIC07,
                                                                     b.frozen_SIC07,
                                                                     b.live_lu,
                                                                     a.ru_vat_to,
                                                                     a.raw_ru_vat_to,
                                                                     a.clean_marker,
                                                                     b.gor, /*Mila: added on 12062015*/
                                                                     b.ssr /*Mila: added on 12062015*/
                                                          from       STAGE19.vat_to_&period.     a
                                                          left join  STAGE06.rx_&period.         b
                                                    /*    left join  vat.rx_&period. b */
                                                          on         a.ruref = b.ruref;
            QUIT;


            %populating_ruvatto(period=&period);


            PROC SQL;
                    delete from STAGE19.ru_vat_to_m&period.   where division = '';

                    insert into STAGE19.ru_vat_to_m&period.   select * from stage19.rows_to_replace;


                    insert into STAGE19.after_replacement     select &period.         as period,
                                                                     sum(ru_vat_to)   as vat_to_after
                                                              from   STAGE19.ru_vat_to_m&period.;


                    /* watch out: double underscore! */
                    /* watch out: double underscore! */
                    /* watch out: double underscore! */
                    create table STAGE19.ruto__m&period.      as
                                                              select *,
                                                                     'm' as freq_rep
                                                              from   STAGE19.ru_vat_to_m&period.;
            QUIT;

    %end; * period ;



    PROC SQL;
        create table STAGE19.check_replacement   as
                                                 select     a.period,
                                                            a.vat_to_before,
                                                            b.vat_to_after,
                                                            a.vat_to_before - b.vat_to_after    as difference
                                                 from       STAGE19.before_replacement    a
                                                 left join  STAGE19.after_replacement     b
                                                 on         a.period = b.period;
    QUIT;


%mend consolidate;
