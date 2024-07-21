
-- E. Farrell 2013
-- E. Farrell 2013
-- E. Farrell 2013
-- E. Farrell 2013
-- E. Farrell 2013

CREATE OR REPLACE PACKAGE BODY reg_docs_populate_pk
AS

-- retrieve status_code from lusi_reg.reg_docs
-- Used to decided if a particular student
-- already has an ID photo or not
FUNCTION get_reg_docs_status (p_regno IN VARCHAR2)
RETURN
    reg_docs.status_code%TYPE
IS

        -- local variables
        vStatus           reg_docs.status_code%TYPE;

BEGIN

        SELECT  d.status_code
        INTO    vStatus
        FROM    reg_docs d
        WHERE   d.regno = p_regno;

        RETURN  vStatus;

EXCEPTION
        WHEN no_data_found THEN
            -- no record/status found on reg_docs
            -- theres no photo for this student
            RETURN NULL;

        WHEN OTHERS THEN
            -- DBMS_OUTPUT.PUT_LINE('Error in [get_reg_docs_status]:  ' || SQLERRM);
            RETURN NULL;

END get_reg_docs_status;

-- Try to retrieve a previous ID photo from the
-- Symmetry Card System and populate "reg_docs" with it.
-- (Only applies to students who previously studied at
-- Lboro and don't already have a photo on reg_docs)
PROCEDURE get_previous_id_photos
IS

        -- Build a cursor of:
        -- 1. students who studied previously at Lboro
        -- 2. and we HAVENT checked already for a symmetry photo
        CURSOR c_previous_students_unchecked
        IS
            SELECT     rs.regno
            FROM       reg_students        rs,
                       student_programmes  sp
            WHERE      rs.student_id = sp.std_student_id

                       -- only include students we
                       -- havent checked already
            AND        rs.image_check_flag = 'N'

                       -- previous students of lboro will
                       -- have more than one programme record
            HAVING     count (sp.std_student_id) > 1

            GROUP BY   rs.regno;

        -- local variables
        blSymmetryPhoto     BLOB;
        vStatusRegDocs       reg_docs.status_code%TYPE;
        vStatusHasPhoto      reg_docs.status_code%TYPE;

        -- RAW is used to copy a BLOB over a dblink.
        -- Note! 32k is the max BLOB size that can be copied.
        l_raw               RAW(32000) := NULL;

BEGIN
        -- store status code which indicates a
        -- photo exists on the reg_docs table
        vStatusHasPhoto := reg_const_pk.get_status_export_successful();

        -- Loop through each previous student
        -- trying to figure out if we have a photo already
        << check_students >>

        FOR CurrentRow IN c_previous_students_unchecked
        LOOP
                -- Is there a photo on reg_docs already?
                vStatusRegDocs := get_reg_docs_status (CurrentRow.regno);

                -- debug code
                -- DBMS_OUTPUT.PUT_LINE('CurrentRow.regno :' ||  CurrentRow.regno);
                -- DBMS_OUTPUT.PUT_LINE('vStatusRegDocs : ' ||  vStatusRegDocs);

                IF vStatusRegDocs = vStatusHasPhoto
                THEN
                        -- stop processing - we already
                        -- have a good photo for them
                        -- DBMS_OUTPUT.PUT_LINE('Photo on reg_docs already');
                        NULL;

                ELSE
                        -- debug code
                        -- DBMS_OUTPUT.PUT_LINE('no valid photo on reg_docs, try symmetry');

                        -- nothing already on reg_docs,
                        -- but try Symmetry Card System
                        blSymmetryPhoto := image_get.image_blob (CurrentRow.regno);

                        IF DBMS_LOB.GETLENGTH (blSymmetryPhoto) = 0
                        THEN
                                -- stop processing - no Symmetry photo.
                                -- Theres nothing else we can do...
                                -- DBMS_OUTPUT.PUT_LINE('no photo on symmetry');
                                NULL;

                        ELSE
                                -- Found a previous photo on symmetry!
                                -- Recast photo BLOB into RAW...
                                -- (needed for updates accross a dblink)
                                l_raw := blSymmetryPhoto;

                                if vStatusRegDocs is NULL
                                THEN
                                        -- debug code
                                        -- DBMS_OUTPUT.PUT_LINE('found symmetry photo! inserting into reg_docs');

                                        -- no record on reg_docs already, so create
                                        -- new record and insert symmetry photo.
                                        -- Note: setting status to "vStatusHasPhoto"
                                        -- will ensure virus checking and compression
                                        -- steps are skipped in reg_docs_pk.photo_export
                                        INSERT INTO reg_docs (regno,
                                                              blob_user_uploaded,
                                                              blob_compressed,
                                                              status_code)

                                                    VALUES    (CurrentRow.regno,
                                                               l_raw,
                                                               l_raw,
                                                               vStatusHasPhoto);

                                ELSE
                                        -- debug code
                                        -- DBMS_OUTPUT.PUT_LINE('found symmetry photo! updating existing reg_docs record');

                                         -- already something on reg_docs
                                         -- so update existing record...
                                        UPDATE  reg_docs d
                                        SET     d.blob_user_uploaded    = l_raw,
                                                d.blob_compressed       = l_raw,
                                                d.status_code           = vStatusHasPhoto
                                        WHERE   d.regno = CurrentRow.regno;

                                END IF;

                                COMMIT;

                        END IF;

                END IF;

        END LOOP check_students;

        -- finished checking this batch of students,
        -- so set flag to "Y" cos we dont want to
        -- check them again in the future....
        UPDATE  reg_students
        SET     image_check_flag = 'Y'
        WHERE   image_check_flag = 'N';

EXCEPTION
        WHEN OTHERS THEN
            -- DBMS_OUTPUT.PUT_LINE('Error in [get_previous_id_photos]:  ' || SQLERRM);
            RAISE_APPLICATION_ERROR(-20101,'Error in get_previous_id_photos : '||SQLERRM, TRUE);

END get_previous_id_photos;

END reg_docs_populate_pk;
/
SHOW ERRORS
