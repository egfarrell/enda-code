/*
Enda Farrell 2017
Enda Farrell 2017
Enda Farrell 2017
*/

%macro make_folder(parent, new_folder);
        /*
        Create a new folder on disk
        */
        DATA _NULL_;
            newpath = DCREATE(&new_folder, &parent);
            put 'Created a new folder: ' newpath=;
        RUN;
%mend;

%macro excel_import(workbook=, sheet=, sas_dataset=);

        PROC IMPORT
            DATAFILE  =  &workbook
            OUT       =  &sas_dataset REPLACE
            DBMS      =  EXCEL;
            SHEET     =  &sheet;
            GETNAMES  =  YES;
        RUN;

%mend;

%macro define_global_variables;

        DATA _NULL_;
                set EXCEL_INPUT_FILES
                end = finish;
                call symput('input_folder_' !! compress(_N_),  trim(left(INPUT_FOLDER))    );
                call symput('input_file_'   !! compress(_N_),  trim(left(INPUT_FILENAME))  );
                if (finish = 1)
                then call symputx('total_input_files', _N_);
        RUN;

        DATA _NULL_;
                set EXCEL_QUESTIONS
                end = finish;
                call symput('question_' !! compress(_N_),  trim(left(QUESTION)));
                if (finish = 1)
                then call symputx('total_questions', _N_);
        RUN;

        DATA _NULL_;
                set EXCEL_DEALERS
                end = finish;
                call symput('dealer_ref_' !! compress(_N_),  trim(left(RUREFERENCE)));
                if (finish = 1)
                then call symputx('total_dealers', _N_);
        RUN;

        /* Print a summary of all the Excel Spreadsheet parameters */
        %show_global_variables;

        /* Validate filenames (from parameters Spreadsheet) */
        %do i = 1 %to &total_input_files;

                %let filepath = &&input_folder_&i.\&&input_file_&i...sas7bdat;
                /* %put filepath &f:  &filepath; */

                %if NOT %sysfunc(fileexist("&filepath")) %then
                %do;
                        /*
                        Cannot find the input file specified
                        in the Excel Spreadsheet - ABORT!
                        */
                        %PUT;
                        %PUT ---ERROR----  Cannot find input file &i: "&filepath";
                        %PUT ---ERROR----  Check input parameters in Sheet "input_files", Workbook: "&param_file";
                        %PUT;
                        %abort CANCEL;
                %end;
        %end;

        /* Validate question numbers (from parameters Spreadsheet) */
        %do i = 1 %to &total_questions;

                %if %sysevalf(%superq(question_&i)=, boolean) %then
                %do;
                        /* The question number is blank...  */
                        /* Probably a blank row in Excel. ABORT! */
                        %PUT;
                        %PUT ---ERROR----  Blank question found;
                        %PUT ---ERROR----  Check if row %eval(&i + 1) is blank in Sheet "questions", Workbook: "&param_file";
                        %PUT;
                        %abort CANCEL;
                %end;

        %end;

        /* Validate Dealer RUReferences (from parameters Spreadsheet) */
        %do i = 1 %to &total_dealers;

                %if &&dealer_ref_&i = . %then
                %do;
                        /* The Dealer Reference is blank...  */
                        /* Probably a blank row in Excel. ABORT! */
                        %PUT;
                        %PUT ---ERROR----  Blank SIC code found;
                        %PUT ---ERROR----  Check if row %eval(&i + 1) is blank in Sheet "Dealers", Workbook: "&param_file";
                        %PUT;
                        %abort CANCEL;
                %end;

        %end;

%mend;

%macro show_global_variables;

        /*
           Print a summary of the parameters 
           passed in from Excel...
        */

        PROC SQL;

            select  "Excel Sheet:   input_files: ", *
            from    EXCEL_INPUT_FILES;

            select  "Excel Sheet:       dealers: ", RUReference FORMAT=15.0
            from    EXCEL_DEALERS;

            select  "Excel Sheet:     questions: ", *
            from    EXCEL_QUESTIONS;
        QUIT;

        %put ;
        %put Global Variables: Input Files to be processed:;

        %do f = 1 %to &total_input_files;
            %put input_folder_&f: &&input_folder_&f   input_file_&f: &&input_file_&f;
        %end;

        %put ;
        %put Global Variables: Dealers to be searched for:;

        %do d = 1 %to &total_dealers;
            %put dealer_ref_&d: &&dealer_ref_&d;
        %end;

        %put ;
        %put Global Variables: Question numbers to be processed:;

        %do q = 1 %to &total_questions;
            %put question_&q: &&question_&q;
        %end;
%mend;

%macro extract_dealers();

        /*
            Go through each input file,
            and pick off specific dealers...

            This will reduce the size of the files 
            to be searched and speed up processing.
        */

        %let insert_comma = ,;

        %do j = 1 %to &total_input_files;

            libname FILE_LIB    "&&input_folder_&j";

            PROC SQL;
                    /*  Create a new reduced dataset made up of specific dealers only */
                    create table dealer_subset_&j
                    as
                        select   *
                        from     FILE_LIB.&&input_file_&j

                        where    RUReference in (
                                                  /* build a list of (many) dealer references */
                                                  %do d = 1 %to &total_dealers;
                                                      %if (&d > 1) %then %bquote(&insert_comma);
                                                      &&dealer_ref_&d
                                                  %end;
                                                )

                        order by RUReference;

                    select  "dealer_subset_&j - rows found: ", count(*)
                    FROM dealer_subset_&j
                    ;

                    select  RUReference, CurrentSIC, FormStatus, IDBRPeriod
                    FROM dealer_subset_&j
                    ;

            QUIT;

        %end;

%mend ;

%macro extract_question(dataset=, question=, period_number=);
    /*
        Extract all responses for a SPECIFIC QUESTION
        but exclude records with an invalid *Form Status* (200 or 1000)
    */

    %put ;
    %put Custom Msg: Searching for question  : &question;
    %put Custom Msg: On Dataset              : &dataset;
    %put ;

    %let insert_comma = ,;

    /*
        Does this question exist on the dataset??
        SAS *crashes* if the question doesnt exist.

        Run a safety query to find out...
    */
    PROC SQL outobs=1 noprint;
        select   name
        into     :question_exists
        from     SAFETY_TABLE
        where    upcase(memname) = upcase("&dataset")
        and      name            = "&question"
        ;
    QUIT;

    %if %SYMEXIST(question_exists) %then 
    %do;
        /*
           All OK - It's safe to execute the SQL!
        */

        PROC SQL;
                create table &dataset._&question
                as
                    select   RUReference,
                             CurrentSIC,
                             FormStatus,
                             IDBRPeriod,
                             Employees,
                             Turnover,
                             &period_number    as periodnumber,
                             "&question"       as question,
                             &question         as value

                    from     &dataset

                             /* exclude invalid records */
                    where    FormStatus not in (200, 1000);

        QUIT;

    %end;
    %else
    %do;
        %put Custom Warning: Could not find question "&question" on "&dataset";
    %end;

%mend;

%macro create_safety_table();

    /*
       This code looks at each dealer file and 
       checks which questions actually exist on it.

       It outputs the results to a "safety table".

       The reason for the safety table is that
       subsequent SQL statements could crash
       if they try to select a column that 
       doesn't actually exist.
    */

    %let insert_comma = ,;

    PROC SQL;
        create table safety_table
        as
            select   name               label = 'question number:',
                     memname            label = 'exists on dataset:'

            from     DICTIONARY.COLUMNS

            where    upcase(LIBNAME)  = 'WORK'

            and      upcase(MEMNAME)  in ( %do j = 1 %to &total_input_files;
                                                "DEALER_SUBSET_&j"
                                                %if (&j > 1) %then %bquote(&insert_comma);
                                            %end;
                                         )

            and      name             in ( %do i = 1 %to &total_questions;
                                                "&&question_&i"
                                                %if (&i > 1) %then %bquote(&insert_comma);
                                           %end;
                                         )
            ;
           
        
        
        /*
           *for debugging only:;
           select * 
           from safety_table;
        */
       
    QUIT;

%mend;

%macro extract_all_questions();

    /* create a list of which questions exsit on which datasets */
    %create_safety_table();

    /* Scan each file of dealer responses */
    %do j = 1 %to &total_input_files;

            /* ...and look for a specific question  */
            %do i = 1 %to &total_questions;

                %extract_question(dataset        = dealer_subset_&j,
                                  question       = &&question_&i,
                                  period_number  = &j);
            %end;

    %end;

%mend;

%macro merge_responses(lib=, merged_file=);

        /* create a large file of all dealer responses */

        DATA &lib..&merged_file;

            format RUReference     best11. ;
            format CurrentSIC      best5.  ;
            format FormStatus      best4.  ;
            format IDBRPeriod      best6.  ;
            format Employees       best18. ;
            format Turnover        best18. ;
            format periodnumber    best12. ;
            format question        $15.    ;
            format value           best18. ;

            SET %do j = 1 %to &total_input_files;

                    %do i = 1 %to &total_questions;

                            %if %sysfunc(exist(dealer_subset_&j._&&question_&i)) %then
                            %do;
                                dealer_subset_&j._&&question_&i
                            %end;
                            %else
                            %do;
                                %put Custom Warning: dataset "dealer_subset_&j._&&question_&i" doesnt exist.;
                            %end;

                    %end;
                %end;
            ;
        RUN;

        /* Also make a *CSV* copy */
        %let CSV_FOLDER = %sysfunc(PATHNAME(&lib));
        %put The CSV will be saved in: &CSV_FOLDER;

        
        PROC EXPORT
            DATA      =  &lib..&merged_file
            DBMS      =  CSV
            OUTFILE   =  "&CSV_FOLDER.\&merged_file..csv"
            REPLACE;
            PUTNAMES  =  YES;
        RUN;

%mend;

%macro calc_stats(infile=, outfile=);

        PROC SQL;
            create table &outfile
            as
                select   rureference,
                         question,
                         COUNT(*)    as num_responses  label ="Number of Responses",
                         MIN(value)  as min_val        label ="Min Response",
                         MAX(value)  as max_val        label ="Max Response",
                         MEAN(value) as mean           label ="Mean",
                         STD(value)  as std            label ="Standard Deviation"

                FROM     &infile

                group by rureference,
                         question
                ;

                /* Let the user see the summary stats */
                select  *
                FROM    &outfile
                ;
        QUIT;

%mend;
