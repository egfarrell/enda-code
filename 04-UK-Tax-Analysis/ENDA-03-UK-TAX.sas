
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */

/* stage 11 */
%macro linking_vat_ent;

    data _null_;
            /*
                This data step populates macro variables:
                - &extract_period,
                - &vat period
                - &number of periods,
                based on the "Vat_ent_lookup" file (IDBR extracts period lookup.xls)

                File: misc.Vat_ent_lookup
                extract_period      extract_layout      period_vat
                --------------------------------------------------
                201601              2                   514
                201602              2                   515
                201603              2                   516
            */

            set misc.Vat_ent_lookup end=finish;

            call symput('extract_per'   !!compress(_N_),    trim(left(extract_period)));
            call symput('vat_per'       !!compress(_N_),    trim(left(period_vat)));

            if finish = 1
            then call symputx('period_num',_N_);
    run;

    %debug ("Stage 11:")
    %debug ("linking_vat_ent: read MISC.vat_per_lookup")
    %debug ("   period_num:     &period_num")


    proc sql;

        /*
           These 2 tables are auxiliary tables and will
           be linked at the end of the macro to shed light
           on the quality of linking between VAT reports and
           Enterprises at each period of interest.
        */

        create table STAGE11.vat_reporters   (
                                             period         num,
                                             vat_reporters  num,
                                             reported_to    num format=d24.
                                             );


        create table STAGE11.link_reporters  (
                                             period          num,
                                             linked_reps     num,
                                             transfered_to   num format=d24.
                                             );

    quit;


    %do i = 2 %to &period_num.; * counter for 'VAT_Enterprise' datasets ;

        /*
            Set the earliest 'vat_reference' period to be
            linked to the 'VAT_Enterprise' dataset relevant
            for this period
        */
        %let j = %eval(&i. - 1);
        %let p = %eval(&&vat_per&j.. - 1);

        %debug ("   outer loop (period)")

        %debug ("   i is :          &i")
        %debug ("   j is :          &j")
        %debug ("   vat_per&j is :  &&vat_per&j")
        %debug ("   p is :          &p")


        %do period =&p. %to &&vat_per&i..;

            %debug ("       inner loop (period)")
            %debug ("       period is:      &period to &&vat_per&i..")
            %debug ("       extract_per&i:  &&extract_per&i..")

            /*
                This loop is for the 'vat_reference' periods
                to be linked with the 'VAT_Enterprise' dataset
                relevant for these periods.

                The 'VAT_Enterprise' datasets are roughly
                *quarterly* so the idea is to link all the
                vat_reference periods from the previous
                VAT_Enterprise dataset to the current one.
            */

            proc sql;

                /*
                   insert row for each reference period noting:
                   1. how many VAT traders reported for that period
                   2. the amount Turnover they reported.
                */


                insert into stage11.vat_reporters     select &period.         as period,
                                                             count(vatref9)   as vat_reporters,
                                                             sum(turnover)    as reported_to
                                                       from  STAGE04.ref_period_d2_&period.; /* <----- monthly HMRC vat file */
                                                /*     from   vat.    ref_period_&period.;              */



                /*
                   the table 'STAGE11.vat_ent_rp_&Period.'
                   is the main product of this macro.

                   It links VAT traders reported for
                   a particular reference period to the
                   enterprises from IDBR associated with
                   them up to this quarter
                */

                create table stage11.vat_ent_rp_&Period.
                as
                    select    a.vatref9,
                              a.refperiod,
                              a.stagger,
                              a.vatsic5,
                              a.turnover,
                              a.arrivalperiod,

                              b.entref,
                              b.rx_period,
                              b.emp_proportion,
                              /* -------------------------------------------- */
                              /* -------------------------------------------- */
                              a.turnover * b.emp_proportion as vat_ent_to,
                              /* -------------------------------------------- */
                              /* -------------------------------------------- */
                              b.case_ve

                    
                    from      stage04.ref_period_d2_&period.    a  /* <----- monthly HMRC vat file */
                    left join stage10.vatent_&&extract_per&i..  b

                    on        a.vatref9 = b.vatref9;




                /*
                   There are no missing links between VAT
                   refs and Enterprises.
                */


                /* EF: This table is never used???? */
                create table stage11.missing_&period.
                as
                    select vatref9,
                           refperiod,
                           stagger,
                           vatsic5,
                           turnover,
                           arrivalperiod
                 /* from   vat.ref_period_&period. */
                    from   STAGE04.ref_period_d2_&period.
                    where  vatref9 not in (select vatref9
                                            from  stage11.Vat_ent_rp_&period.);





                insert into stage11.link_reporters
                    select &period.          as period,
                            count(vatref9)   as linked_reps,
                            sum(vat_ent_to)  as transfered_to
                    from stage11.vat_ent_rp_&Period.;
                 /* from vat.    vat_ent_rp_&Period.; */


            quit;

        %end; * period ;

    %end; * i ;

    /*
        - The loss of VAT turnover comes from failing to
          find enterprise data in the corresponding REPEX
          files from IDBR for particular periods, hence:

            - employment proportions for them are missing
            - or employment proportions for them are 0

        - and the VAT turnover associated with them gets
          lost.

        - But the number of VAT reporters is wrongly blown
          up, as the code actually counts the number of rows
          which represents the fact that 1 representative
          VAT reference may be associated with more than one
          enterprise

    */


    proc sql;
    /* create table vat.linking_vat_ent */
        create table stage11.linking_vat_ent
        as
            select     a.period,
                       a.vat_reporters,
                       a.reported_to,
                       b.linked_reps,
                       b.transfered_to,
                       a.vat_reporters - b.linked_reps                        as missing_reps,
                       (a.reported_to  - b.transfered_to) / b.transfered_to   as per_lost_to
            from       stage11.vat_reporters    a
            left join  stage11.link_reporters   b
            on         a.period = b.period;
    quit;


%mend linking_vat_ent;



/* stage 12 */
%macro severing_vat_ent_link (minp=, maxp=);

    proc sql;
        create table stage12.check_for_dup (
                                           period      num,
                                           vat_ent_to  num format=d24.
                                           );

    quit;
    %debug ("after first create table: stage12.check_for_dup");


    %do period = &minp. %to &maxp.;

            /* copy the file from the previous folder */
            data STAGE12.vat_ent_rp_&Period.;
                set stage11.vat_ent_rp_&Period.;
            run;

            proc sql;
                 /* alter table  vat.    vat_ent_rp_&Period.   add entref_stag     char(12), */
                    alter table  STAGE12.vat_ent_rp_&Period.   add entref_stag  char(12), freq_rep  char(1);

                    update       STAGE12.vat_ent_rp_&Period.   set freq_rep    = 'm'  where  stagger = 0;
                    update       STAGE12.vat_ent_rp_&Period.   set freq_rep    = 'q'  where  stagger between 1 and 3;
                    update       STAGE12.vat_ent_rp_&Period.   set freq_rep    = 'a'  where  stagger gt 3;

                    update       STAGE12.vat_ent_rp_&Period.   set entref_stag = entref || '_' || freq_rep;
            quit;


            /*
               data vat.ve_complex_&Period.
                    vat.ve_simple_&Period.;
            */
            data stage12.data_ve_complex_&Period. 
                 stage12.data_ve_simple_&Period.;

                 /* set vat.    vat_ent_rp_&Period.; */
                    set STAGE12.vat_ent_rp_&Period.;

                    if case_ve = 'complex'  then output stage12.data_ve_complex_&Period.;
                    if case_ve = 'simple'   then output stage12.data_ve_simple_&Period.;
            run;


            proc sql;

                    create table stage12.ve_complex_&period.    as
                                                                select   entref_stag,
                                                                         max(arrivalperiod)  as arrivalperiod,
                                                                         sum(vat_ent_to)     as vat_ent_to
                                                                /* from     vat.    ve_complex_&period. */
                                                                from     stage12.data_ve_complex_&period.
                                                                group by entref_stag;



                    create table stage12.veto_complex_&period.  as
                                                                select  &period.                    as refperiod,
                                                                        substr(entref_stag,1,10)    as entref,
                                                                        substr(entref_stag,12,1)    as freq_rep,
                                                                        arrivalperiod,
                                                                        vat_ent_to,
                                                                        'complex'                   as case_ve
                                                                from    stage12.ve_complex_&period.;



                    insert into stage12.check_for_dup           select  &period.,
                                                                        sum(vat_ent_to)
                                                                from    stage12.veto_complex_&period.;



                    create table stage12.veto_simple_&period.   as
                                                                select  &period.                    as refperiod,
                                                                        substr(entref_stag,1,10)    as entref,
                                                                        substr(entref_stag,12,1)    as freq_rep,
                                                                        arrivalperiod,
                                                                        vat_ent_to,
                                                                        'simple'                    as case_ve
                                                                from    stage12.data_ve_simple_&Period.;



                    insert into stage12.check_for_dup           select  &period.,
                                                                        sum(vat_ent_to)
                                                                from    stage12.veto_simple_&period.;


                 /*
                    EF: dont bother dropping these fields cos
                    I've made a new version of this table
                 */
                 /* alter table vat.vat_ent_rp_&Period. */
                 /* alter table stage12.vat_ent_rp_&Period.  drop entref_stag, freq_rep; */

            quit;

            /* combine simple and complex */
            data STAGE12.data_veto_&period;
                set STAGE12.veto_complex_&period
                    STAGE12.veto_simple_&period;
            run;


            proc sql;

                /*
                   check out the following SQL join!
                   It seems to create many duplicate records...
                */

                    create table STAGE12.veto_&period  as  select   a.*,
                                                                    b.rx_period
                                                       from         STAGE12.data_veto_&period.    a
                                                       left join    STAGE12.vat_ent_rp_&Period.   b
                                                       on           a.entref = b.entref
                                                       where        b.rx_period ne .;
            quit;

    %end; *  period  ;



    proc sql;
            Create table stage12.chk_for_dup        as
                                                    Select   period,
                                                             Sum(vat_ent_to) as vat_ent_to
                                                    From     stage12.check_for_dup
                                                    Group by period;



        /* create table vat.check_severing     as  */
            create table stage12.check_severing     as
                                                    select    a.period,
                                                              a.vat_ent_to - b.transfered_to as check
                                                    from      stage12.chk_for_dup           a
                                                    left join stage11.Linking_vat_ent       b
                                                    /* left join vat.Linking_vat_ent b */
                                                    on        a.period = b.period;


    quit;

%mend severing_vat_ent_link;



/*
   called from: '%linking_with_ru' (part of STAGE 13)
*/
%macro populating_ruto (period=);

    /*
       key idea: 

                BLANK               
       look for BLANK RU references!
                BLANK               
    */
    proc sql;
        create table STAGE13.find_entrefs   as
                                            select  distinct  entref,
                                                              rx_period
                                            from              STAGE13.ruto_&period
                                            where             ruref = '';

        create table STAGE13.where_to_look  as
                                            select  distinct rx_period
                                            from             STAGE13.ruto_&period
                                            where            ruref = '';
    quit;


    proc sql noprint;
            select  nobs
            into    :periods_to_check
            from    dictionary.tables
            /* where   libname = 'WORK' */
            where   libname = 'STAGE13'
            and     memname = 'WHERE_TO_LOOK';
    quit;


    %Debug ("after reading dictionary.tables");
    %Debug ("periods_to_check is:  &periods_to_check");


    %if &periods_to_check GT 0 %then
    %do;

        data _null_;
            set STAGE13.where_to_look end=finish;

            call symput('p_to_lookin' || compress(_N_),   trim(left(rx_period)));

            if finish = 1
            then call symputx('last_num', _N_);
        run;

        %Debug ("periods_to_check IS > 0.");
        %debug ("last_num is: &last_num")

        %do i = 1 %to &last_num.;

            %debug ("   in loop 1 to last_num: i = &i")

            proc sql;
                create table STAGE13.data_pool      as
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
                                               /*   from            vat.rx_&&p_to_lookin&i.. */
                                                    from            STAGE06.rx_&&p_to_lookin&i..
                                                    where           entref in 
                                                                              (select  entref
                                                                               from    STAGE13.find_entrefs
                                                                               where   rx_period = &&p_to_lookin&i.. );


                /*
                    Sample: data_pool
                                               current     current_        current_      legal_    ent_                                                  frozen_      frozen_        frozen_     frozen_     current_
                   entref      ruref           _empment    reg_to          SIC07         status    empment     division    section   empband     class   empment      reg_to         SIC07       SIC03       SIC03       live_lu  emp_proportion
                   9900022753  49900022753     1           0               46360                   1           46          G         1           G_1     0            0              46360                               0        1
                   9900573609  49900573609     1           81              49410                   1           49          H         1           H_1     1            81             49410                               1        1
                   9900611123  49900611123     1           0               46900                   1           46          G         1           G_1     0            0              46900                               0        1
                   9900673825  49900673825     1           0               46470                   1           46          G         1           G_1     0            0              46470                               0        1
                   9900713242  49900713242     1           1               90010                   1           90          R         1           R_1     1            1              90010                               0        1
                   9900851713  49900851713     1           159             68100                   1           68          L         1           L_1     1            159            68100                               1        1
                   9900851886  49900851886     1           4               02100                   1           02          A         1           A_B_1   0            0              02100                               0        1
                   9900977854  49900977854     3           100             56103                   3           56          I         1           I_1     3            100            56103                               0        1
                */



                %put 'after creating data_pool table'

                /*
                   notice: the TURNOVER is apportioned here!
                   (b.vat_ent_to * a.emp_proportion)      as ru_vat_to,
                */
                insert into STAGE13.rows_to_replace       select   distinct  a.*,
                                                                             b.refperiod,
                                                                             b.arrivalperiod,
                                                                             b.freq_rep,
                                                                             b.vat_ent_to,
                                                                             b.vat_ent_to * a.emp_proportion      as ru_vat_to,
                                                                             b.case_ve,
                                                                             b.rx_period
                                                       /* from               data_pool     a */
                                                       /* left join          ruto_&period. b */
                                                          from               STAGE13.data_pool       a
                                                          left join          STAGE13.ruto_&period.   b
                                                          on                 a.entref = b.entref
                                                          where              b.ruref  = '';

                %put 'after inserting into rows_to_replace'


            quit;

        %end; /* i */

    %end; /* if &periods_to_check. gt 0  */
    %else
    %do;
        %Debug ("periods_to_check not greater than 0.");
        %Debug ("not creating data pool etc...");
    %end;

%mend populating_ruto;





/* stage 13 */
%macro linking_with_ru (minp=, maxp=);

    /*
        The key output file: "ruto_&period" is initially
        based on:

            1. rx_&period
            2. veto_&period

    */

    proc sql;
        /* 'Lost' rx */
        create table STAGE13.lost_rx_data   (
                                            period          num,
                                            pattern         char(1),
                                            ents_not_on_rx  num,
                                            lost_vat_to     num format = d16.
                                            );


        /* 'Found' rx */
        create table STAGE13.found_rx_data  (
                                            period          num,
                                            pattern         char(1),
                                            ents_on_rx      num,
                                            found_vat_to    num format = d16.
                                            );

    quit;


    %do period =&minp. %to &maxp.;

            %debug ("in period loop &minp to &maxp: period = &period")

            proc sql;

                /*
                   ef note ******************************************
                   ef note ******************************************

                            Sometimes I only select 'entrefs' that exist in
                            the file: 'MISC.test_cases'

                   ef note ******************************************
                   ef note ******************************************
                */
                create table STAGE13.ruto_&period.      as
                                                                /* distinct! */
                                                                /* distinct! */
                                                                /* distinct! */
                                                        select     distinct  b.entref,
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
                                                                             b.case_ve,
                                                                             b.rx_period,
                                                                             /* ef: I moved this logic here cos of SAS 'LOCK' errors */
                                                                             b.vat_ent_to * a.emp_proportion as  original_ru_vat_to,
                                                                             0                               as  clean_marker,
                                                                             'simple'                        as  case_er length=7,

                                                                             /*    -------------------------- */
                                                                             /*    apportion RU turnover!     */
                                                                             /*    -------------------------- */
                                                                             b.vat_ent_to * a.emp_proportion as ru_vat_to
                                                                             /*    -------------------------- */
                                                                             /*    -------------------------- */

                                                        from                 STAGE06.rx_&period.      a
                                                        right join           STAGE12.veto_&period.    b
                                                        on                   a.entref = b.entref

                                                        /* ef testing: ------------------------------- */
                                                        /* ef testing: ------------------------------- */
                                                        where                b.entref in (select entref from MISC.test_cases);
                                                        /* ef testing: ------------------------------- */
                                                        /* ef testing: ------------------------------- */


                                                        /* ef-debug: temporary filter - for VAT apportionment sprint investigation */
                                                         /* where               b.entref  = '9900918848';  */


                                                        /* ef-note: old code to trace a failing case */
                                                        /* where      a.ruref   = '49905175967'; */
                                                        /* where      a.entref  = '9905175967'; */




                /*
                    STAGE06.rx_&period:

                                entref          ruref              current_       current_        current_     legal_     live_lu     frozen_       frozen_      frozen_      current_    frozen_      inq_stop        gor     ssr     division    section     empband     class       ent_            emp_
                                                                    empment        reg_to          SIC07        status                 empment       SIC07        SIC03        SIC03       reg_to                                                                                       empment         proportion
                                --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                9900000034      49900000034        1              22235           24510        1          1           1             24510        27510        27510       22235        8               F       E       24          C           1           C_1         1               1
                                9900000050      49900000050        1              111             82990        1          1           1             82990        74879        74879       111          8               F       E       82          N           1           N_1         1               1
                                9900000062      49900000062        1              111             82990        1          1           1             82990        74879        74879       111          8               F       E       82          N           1           N_1         1               1
                                9900000101      49900000101        1              103             74909        1          1           1             74909        74879        74879       103          8               F       E       74          M           1           M_1         1               1
                                9900000102      49900000102        0              10138           70100        1          1           0             70100        74158        74158       10138        5               F       E       70          M           1           M_1         0               0
                                9900000118      49900000118        82             11111           29320        1          2           82            29320        34300        34300       11111        5               F       E       29          C           3           C_3         82              1
                                9900000126      49900000126        127            37394           33120        1          5           127           33120        29522        29522       37394        5               G       G       33          C           4           C_4         127             1
                                9900000127      49900000127        2              300             42990        1          0           2             42990        45213        45213       300          5               Y       Y       42          F           1           F_1         2               1
                                9900000144      50000060105        149            108294          49410        1          1           149           49410        60249        60249       108294       5               Y       Y       49          H           4           H_4         329             0.452887538
                                9900000144      50000060104        180            42865           49410        1          5           180           49410        60249        60249       42865        5               G       F       49          H           4           H_4         329             0.547112462
                                9900000148      49900000148        223            105127          66290        1          5           223           66290        67200        67200       105127       5               H       H       66          K           4           K_4         223             1


                    STAGE12.veto_&period:

                                refperiod   entref        freq_rep  arrivalperiod       vat_ent_to          case_ve     rx_period
                                -------------------------------------------------------------------------------------------------
                                501         9900000002    q         504                 4500                simple      503
                                501         9900000007    q         503                 25848.534601        complex     503
                                501         9900000009    q         503                 25848.534601        complex     503
                                501         9900000013    q         503                 2791641.7369        complex     503
                                501         9900000014    q         503                 516970.69202        complex     503
                                501         9900000017    q         503                 25848.534601        complex     503


                */

                create table STAGE13.rows_to_replace    like STAGE13.ruto_&period.;

            quit;


            /*
               this macro creates the 'rows_to_replace'
               table which tries to track down RU's with
               a blank reference...
            */
            %populating_ruto(period=&period);

            /* %debug ('just before return statement: linking_with_ru') */
            /* %return; */

            proc sql;

                    /*
                       Gather togeter all records that have
                       a blank RU reference
                    */
                    create table STAGE13.lost_vat_&period.      as
                                                                select distinct entref,
                                                                                refperiod,
                                                                                freq_rep,
                                                                                vat_ent_to
                                                                from            STAGE13.ruto_&period.
                                                                /* ------------------------------------------------------------------------------ */
                                                                where           ruref = '';
                                                                /* ------------------------------------------------------------------------------ */


                 /* DELETE  */
                    DELETE from STAGE13.ruto_&period.           where ruref = '';
                 /* DELETE  */


                 /* INSERT */
                    INSERT into STAGE13.ruto_&period.           select * 
                 /* INSERT */                                   from   STAGE13.rows_to_replace;




                    insert into STAGE13.LOST_rx_data            select   distinct &period.                   as period,
                                                                                  freq_rep                   as pattern,
                                                                                  count(distinct entref)     as ents_not_on_rx,
                                                                                  sum(vat_ent_to)            as LOST_VAT_TO
                                                                from              STAGE13.lost_vat_&period.  
                                                                /* ------------------------------------------------------------------------------ */
                                                                GROUP BY          freq_rep;
                                                                /* ------------------------------------------------------------------------------ */



                    insert into STAGE13.FOUND_rx_data           select   distinct &period.                   as period,
                                                                                  freq_rep                   as pattern,
                                                                                  count(distinct entref)     as ents_on_rx,
                                                                                  sum(ru_vat_to)             as FOUND_VAT_TO
                                                                from              STAGE13.rows_to_replace
                                                                /* ------------------------------------------------------------------------------ */
                                                                GROUP BY          freq_rep;
                                                                /* ------------------------------------------------------------------------------ */



                    /*
                        ef: this was giving SAS LOCK error
                        solution: just create the two columns when you create the table above

                       add two new columns to the table
                       alter table STAGE13.ruto_&period.           Add  original_ru_vat_to  num,
                                                                        clean_marker        num;
                    */


                    /*
                        ef: this was giving SAS LOCK error
                        solution: this logic moved to 'create table' statement above

                       set all cases to be "clean" by
                       default! (ie set clean_marker=0)

                        update STAGE13.ruto_&period.                Set  original_ru_vat_to = ru_vat_to,
                                                                     clean_marker       = 0;
                    */


                    /*
                       Assess COMPLEXITY: 
                          For each enterprise, see how many
                          associated RU's they have.
                    */
                    create table STAGE13.assess_comp        as
                                                            select    entref,
                                                                      count(ruref)            as associated_RUs
                                                            from      STAGE13.ruto_&period.
                                                            Group by  entref;



                    /*
                        ef: this was giving SAS 'LOCK' error
                        just create the column when you create the table above

                       Alter table STAGE13.ruto_&period.          add case_er char(7);
                        Update STAGE13.ruto_&period.               set case_er = 'simple';
                    */




                    Update STAGE13.ruto_&period.           Set     case_er = 'complex'
                                                           Where   entref in 
                                                                          (select  entref
                                                                           from    STAGE13.assess_comp
                                                                           where   associated_RUs GT 1);

            quit;



            /*
               EF: All these files were originally stored in
               library 'VAT' but Ive changed them to be stored
               in library 'STAGE13'
            */
            data STAGE13.ruto_simple_a&period
                 STAGE13.ruto_simple_q&period
                 STAGE13.ruto_simple_m&period

                 STAGE13.ruto_complex_a&period
                 STAGE13.ruto_complex_q&period
                 STAGE13.ruto_complex_m&period;

                /*
                   split everything into 6 files:

                        1. simple    "a" - annual
                        2. simple    "q" - quarterly
                        3. simple    "m" - monthly

                        4. complex   "a" - annual
                        5. complex   "q" - quarterly
                        6. complex   "m" - monthly
                */                      

                set STAGE13.ruto_&period;

                if (case_ve = 'simple') and 
                   (case_er = 'simple') then
                do;
                    select;
                        when (freq_rep = 'a')   output  STAGE13.ruto_simple_a&period.;
                        when (freq_rep = 'q')   output  STAGE13.ruto_simple_q&period.;
                        when (freq_rep = 'm')   output  STAGE13.ruto_simple_m&period.;
                        otherwise;
                    end;
                end;
                else
                do;
                    select;
                        when (freq_rep = 'a')   output  STAGE13.ruto_complex_a&period.;
                        when (freq_rep = 'q')   output  STAGE13.ruto_complex_q&period.;
                        when (freq_rep = 'm')   output  STAGE13.ruto_complex_m&period.;
                        otherwise;
                    end;
                end;
            run;

            /*
                sample data: ruto_* file

                entref          ruref          current_     current_      current_SIC07     legal_status     ent_empment      division      section    empband   class      frozen_        frozen_reg_to     frozen_SIC07      frozen_SIC03    current_SIC03    live_lu     emp_proportion     refperiod    arrivalperiod    freq_rep      vat_ent_to      ru_vat_to        case_ve         rx_period           original_ru_vat_to      clean_marker     case_er
                ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                9900002657       49900002657   1            80            64999                              1                64            K          1         K_1        1              80                64999                                              1           1                  516          516              q             0               0                complex         516                 0                       0                simple
                9900021428       49900021428   1            120           46110                              1                46            G          1         G_1        1              120               46110                                              0           1                  516          516              q             0               0                complex         516                 0                       0                simple
                9900023154       49900023154   1            44            01450                              1                01            A          1         A_B_1      1              44                01450                                              0           1                  516          516              q             2638            2638             simple          516                 2638                    0                simple
                9900137013       49900137013   390          35635         27110                              390              27            C          4         C_4        390            35635             27110                                              4           1                  516          516              q             0               0                complex         516                 0                       0                simple
                9900168169       49900168169   2            862           46240                              2                46            G          1         G_1        2              862               46240                                              1           1                  516          516              q             0               0                simple          516                 0                       0                simple
                9900174817       49900174817   21           1486          69102                              21               69            M          2         M_2        21             1486              69102                                              2           1                  516          516              q             19199           19199            simple          516                 19199                   0                simple
                9900183168       49900183168   2            75            47540                              2                47            G          1         G_1        2              75                47540                                              1           1                  516          516              q             0               0                simple          516                 0                       0                simple
                9900235658       49900235658   5            170           68320                              5                68            L          1         L_1        5              170               68320                                              1           1                  516          516              q             0               0                simple          516                 0                       0                simple
                9900303789       49900303789   78           5174          62090                              78               62            J          3         J_2        78             5174              62090                                              1           1                  516          516              q             0               0                complex         516                 0                       0                simple
            */

    %end; /* period */

    %Debug ("after period loop, about to create: check_vr_linking")

    proc sql;
        create table STAGE13.check_vr_linking  as
                                               select     a.*,
                                                          b.ents_on_rx,
                                                          b.found_vat_to,
                                                          a.ents_not_on_rx - b.ents_on_rx    as unit_diff,
                                                          a.lost_vat_to    - b.found_vat_to  as to_diff

                                               from       STAGE13.lost_rx_data      a
                                               left join  STAGE13.found_rx_data     b

                                               on         a.period  = b.period
                                               and        a.pattern = b.pattern;


            /*
                Sample:
                check_vr_linking

               period      pattern     ents_not_on_rx      lost_vat_to         ents_on_rx      found_vat_to   unit_diff    to_diff
               -------------------------------------------------------------------------------------------------------------------
               513         a           7                   417885.00000000     .               .              .            .
               513         m           183                 52372339            .               .              .            .
               513         q           1676                1278904333          .               .              .            .
               514         a           3                   52533.00000000      .               .              .            .
               514         m           146                 15211569            .               .              .            .
               514         q           499                 59495721            .               .              .            .
               515         a           1                   0                   .               .              .            .
               515         m           6                   1308500             .               .              .            .
               515         q           14                  63209.00000000      .               .              .            .
               516         q           1                   0                   .               .              .            .
            */

    quit;

%mend linking_with_ru; /* stage 13 */





/* stage 14 */
%macro check_vat_ru (minp=, maxp=);

    proc sql;
        create table STAGE14.check_vr_link (
                                           period       num,
                                           ruvat_to     num
                                           );

    quit;


    %do period = &minp  %to  &maxp;

        proc sql;
         /* insert into vat.    check_vr_link */
            insert into STAGE14.check_vr_link   select &period.,
                                                       sum(ru_vat_to)
                                                from   STAGE13.ruto_&period.;
        quit;

    %end;


    /*
        Sample:
        check_vr_link

        period      ruvat_to
        -------------------------
        513         1.0586123 E12
        514         228723932063
        515         516467566
        516         5909968
    */


%mend check_vat_ru;
