/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */
/* Enda Farrell 2016 */

/* Read in the monthly HMRC returns */
%macro monthvat;

    /*
       For the selective editing test:
       Just use 25 hard-coded months: 499 to 523
    */

    %let vat_per1   = 499;   %let cal_per1   = 1410;
    %let vat_per2   = 500;   %let cal_per2   = 1411;
    %let vat_per3   = 501;   %let cal_per3   = 1412;
    %let vat_per4   = 502;   %let cal_per4   = 1501;
    %let vat_per5   = 503;   %let cal_per5   = 1502;
    %let vat_per6   = 504;   %let cal_per6   = 1503;
    %let vat_per7   = 505;   %let cal_per7   = 1504;
    %let vat_per8   = 506;   %let cal_per8   = 1505;
    %let vat_per9   = 507;   %let cal_per9   = 1506;
    %let vat_per10  = 508;   %let cal_per10  = 1507;
    %let vat_per11  = 509;   %let cal_per11  = 1508;
    %let vat_per12  = 510;   %let cal_per12  = 1509;
    %let vat_per13  = 511;   %let cal_per13  = 1510;
    %let vat_per14  = 512;   %let cal_per14  = 1511;
    %let vat_per15  = 513;   %let cal_per15  = 1512;
    %let vat_per16  = 514;   %let cal_per16  = 1601;
    %let vat_per17  = 515;   %let cal_per17  = 1602;
    %let vat_per18  = 516;   %let cal_per18  = 1603;
    %let vat_per19  = 517;   %let cal_per19  = 1604;
    %let vat_per20  = 518;   %let cal_per20  = 1605;
    %let vat_per21  = 519;   %let cal_per21  = 1606;
    %let vat_per22  = 520;   %let cal_per22  = 1607;
    %let vat_per23  = 521;   %let cal_per23  = 1608;
    %let vat_per24  = 522;   %let cal_per24  = 1609;
    %let vat_per25  = 523;   %let cal_per25  = 1610;

    %let period_num = 25;

    %do i = 1 %to &period_num. ;

        %put "cal_per &i:  " &&cal_per&i;
        %put "vat_per &i:  " mvat&&vat_per&i;

        /*
        # layout HMRC Vat file: "irt_mbi_infileYYYYMM"

                Sample data:

                1.  vatref:             100001227
                2.  period number:      513
                3.  record type:        60
                4.  stagger:            1
                5.  vat SIC:            70229
                6.  retrun type:        1
                7.  turnover (to):      40700
                8.  expenditure (xp):   0
                9.  return date:        160103
                10. HMRC SIC:           70229
                11. 2 Digit:            70
        */


        filename mvat&&vat_per&i.. "&task_path.\input-files-vat\irt_mbi_infile20&&cal_per&i.." ;

        * basic cleaning ;
        data mvat&&vat_per&i.. (where = ((not (vatref9 in ('000000000','999999999'))
                                          & (refperiod < 999)
                                          & (60 <= rec_type <= 65)
                                          & ( 0 <= stagger  <= 15)
                                          & ( 1 <= ret_type <=  2)
                                          & (turnover < 99999999998)))) ;

            infile mvat&&vat_per&i.. ;

            input vatref9       $ 1-9
                  vatref        $ 1-7
                  checkdig      $ 8-9
                  refperiod     10-12
                  rec_type      13-14
                  stagger       15-16
                  vatsic5       17-21
                  ret_type      22-22
                  turnover      23-33 ;

                arrivalperiod = &&vat_per&i.. ;
        run ;

        /*
           sample data:
           vatref9	    vatref	    checkdig	refperiod	rec_type	stagger	vatsic5	ret_type	turnover	arrivalperiod
           100000285	1000002	    85	        489	        60	        1	    27120	1	        1617086	    492
           100001380	1000013	    80	        489	        60	        1	    56301	1	        108530	    492
           100002322	1000023	    22	        490	        60	        2	    43210	1	        47278	    492
           100002616	1000026	    16	        490	        61	        2	    43290	1	        1756	    492
           100003221	1000032	    21	        490	        60	        2	    43390	1	        72058	    492
           100003319	1000033	    19	        490	        60	        2	    43991	1	        65304	    492
        */


        /* Save the cleaned HMRC RETURN DATA in 'STAGE01' folder */
        data STAGE01.mvat&&vat_per&i..;
            set mvat&&vat_per&i..;
        run;

    %end ;

%mend monthvat;



/* Remove any duplicate HMRC returns */
%macro duplicate(minp=, maxp=);

    %do period = &minp %to &maxp;
        %Debug ("output 2: creating table: mvat&period");

        proc sql;
            /* does "DISTINCT" apply to all fields or just "vatref9"? */
            create table STAGE02.mvat&period
            as
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
                from   STAGE01.mvat&period;
                /* from   mvat&period. */
        quit;

        proc delete data = output1.mvat&period. ;
        run ;
    %end;
%mend duplicate;



%macro allvat_split_to_periods(minp=,maxp=);

       %do period = &minp %to &maxp;
           /* create empty period tables where the records from */
           /* each monthly file will be inserted in the next step */
           proc sql;
               create table WORK.ref_period_&period.
                            (
                             vatref9        char(9),
                             vatref         char(7),
                             checkdig       char(2),
                             refperiod      num,
                             rec_type       num,
                             stagger        num,
                             vatsic5        num,
                             ret_type       num,
                             turnover       num,
                             refperiod      num,
                             arrivalperiod  num
                            );
           quit;
       %end;

    /* Pick each of the monthly VAT files (datasets) */
    %do mfile = &minp %to &maxp;
        %debug ("output 3: outer loop:   mfile = &mfile");

        /* insert reports for this period into the */
        /* appropriate period dataset */
        %do period = &minp %to &mfile;

            %debug ("   inner loop:  mvat&mfile  ---> insert into: ref_period_&period") ;
            proc sql;
                insert into WORK.ref_period_&period.
                    select  *
                    from    STAGE02.mvat&mfile
                    where   refperiod = &period;
            quit;
        %end;

            proc delete data = STAGE02.mvat&mfile. ;
            run ;

    %end;  * monthly files cycle ;

    %do period = &minp %to &maxp;
        /* ef: copy output files to my disk */
        data STAGE03.ref_period_&period;
            set WORK.ref_period_&period;
        run;
    %end;

%mend allvat_split_to_periods;



/* stage 4 */
%macro duplicate2(minp=, maxp=);

    proc sql;
        create table STAGE04.before_cleaning
                        (
                        ref_period      num,
                        initial_reports num
                        );

        Create table STAGE04.after_cleaning
                        (
                        ref_period      num,
                        Reports         num,
                        Reporters       num,
                        duplicates      num
                        );
    quit;

    %do i=&minp %to &maxp;
        %debug ("   STAGE04:  Processing: ref_period_&i") ;

        /* -------------------------------------------- */
        /* ef extra step: copy data from previous stage */
        /* (keep each stage of processing separate) */
            data STAGE04.ref_period_&i;
                set STAGE03.ref_period_&i;
            run;
        /* -------------------------------------------- */


        proc sort data = STAGE04.ref_period_&i;
            by vatref9 arrivalperiod rec_type descending turnover;
        run;


        /* main OUTPUT FILE from this stage! */
        data STAGE04.ref_period_D2_&i;

            /* ef: is this being sorted a 2nd time? */
            set STAGE04.ref_period_&i;
                by  vatref9 arrivalperiod rec_type descending turnover;

            marker = 0;

            if (lag(vatref9)        = vatref9) and
               (lag(arrivalperiod) ne arrivalperiod)
               then
                    marker = 1;

            if (lag(vatref9)       = vatref9)       and
               (lag(arrivalperiod) = arrivalperiod) and
               (lag(rec_type)     ne rec_type)
               then
                    marker = 1;

            if (lag(vatref9)       = vatref9)       and
               (lag(arrivalperiod) = arrivalperiod) and
               (lag(rec_type)      = rec_type)      and
               (lag(turnover)      ne turnover)
               then
                    marker = 1;

            if marker = 0;
        run;


        proc sql;
            insert into STAGE04.before_cleaning
                select &i,
                       count(turnover)          as reports
                from   STAGE04.ref_period_&i.;



            insert into STAGE04.after_cleaning
                select &i,
                       count(turnover)                            as reports,
                       count(distinct vatref9)                    as reporters,
                       calculated reports - calculated reporters  as duplicates
                from   STAGE04.ref_period_D2_&i.;
        quit;

    %end;


    proc sql;
        create table STAGE04.check_duplicates
        as
            select     a.*,
                       b.initial_reports - a.reports   as cleared_dups
            from       STAGE04.after_cleaning          a
            left join  STAGE04.before_cleaning         b
            on         a.ref_period = b.ref_period;
    quit;

    /*
        ref_period      Reports     Reporters   duplicates    cleared_dups
           492	        760566	    760566	             0	          2031
           493	        591187	    591187	             0	          1498
           494	        572636	    572636	             0	          1369
           495	        766014	    766014	             0	          1894
           496	        594035	    594035	             0	          1539
           497	        574575	    574575	             0	          1433
           498	        773167	    773167	             0	          1828
           499	        597742	    597742	             0	          1430
           500	        578183	    578183	             0	          1345
           501	        782227	    782227	             0	          1921
           502	        601187	    601187	             0	          1404
           503	        579562	    579562	             0	          1185
           504	        792045	    792045	             0	          1737
           505	        605155	    605155	             0	          1288
           506	        581911	    581911	             0	          1170
           507	        798292	    798292	             0	          1536
    */

%mend;
