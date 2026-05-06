-- ============================================================================
-- FILE: 05_MANAGER_PLSQL_FEATURES.sql
-- RUN AS: MANAGER_ADMIN (Password: manager123)
-- PURPOSE: Create all PL/SQL features (2-10)
-- ============================================================================
-- Features implemented:
--   2. Exam Eligibility Trigger (prerequisite check)
--   3. Grade Calculation Function
--   4. Automated Warning Procedure
--   5. Audit Trail Triggers (BEFORE INSERT/DELETE)
--   6. Course Performance Report (Cursor)
--   7. Exam Schedule Management
--   8. Multi-Exam Grade Update with Transactions
--   9. Student Suspension Procedure
--   10. GPA Function + Grade Authorization Trigger
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================
PROMPT FILE 5: MANAGER CREATES PL/SQL FEATURES
PROMPT Run as: MANAGER_ADMIN
PROMPT ============================================================

-- ============================================================================
-- CLEANUP: Drop existing PL/SQL objects if re-running
-- ============================================================================
PROMPT
PROMPT [CLEANUP] Dropping existing PL/SQL objects...

BEGIN
    -- Drop triggers
    BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER user1.trg_grade_authorization'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER user1.trg_check_prerequisite'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER user1.trg_audit_register_delete'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER user1.trg_audit_register_insert'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Drop procedures
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE user1.suspend_students_with_warnings'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE user1.update_multiple_grades'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE user1.display_exam_schedule'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE user1.course_performance_report'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE user1.issue_warnings_for_failures'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Drop functions
    BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION user1.calculate_gpa'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION user1.calculate_grade'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[DONE] Existing PL/SQL objects cleaned');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] PL/SQL cleanup skipped: ' || SQLERRM);
END;
/


-- ============================================================================
-- FEATURE 2: Exam Eligibility Validation Trigger
-- ============================================================================
-- Checks if student completed prerequisite before registering for a course
-- ============================================================================

PROMPT
PROMPT [FEATURE 2] Creating prerequisite eligibility trigger...

CREATE OR REPLACE TRIGGER user1.trg_check_prerequisite
BEFORE INSERT ON user1.Register
FOR EACH ROW
DECLARE
    v_prereq_id     NUMBER;
    v_prereq_name   VARCHAR2(100);
    v_course_name   VARCHAR2(100);
    v_completed     NUMBER;
BEGIN
    -- Get the prerequisite for the course being registered
    SELECT prerequisite_course_id, name
    INTO v_prereq_id, v_course_name
    FROM user1.Courses
    WHERE id = :NEW.course_id;
    
    -- If course has a prerequisite
    IF v_prereq_id IS NOT NULL THEN
        -- Get prerequisite name
        SELECT name INTO v_prereq_name
        FROM user1.Courses
        WHERE id = v_prereq_id;

            -- Check: has the student PASSED the prerequisite exam?
            SELECT COUNT(*) INTO v_completed
            FROM user1.Register r
            JOIN user1.ExamResults er ON r.id = er.registration_id
            WHERE r.student_id = :NEW.student_id
            AND r.course_id = v_prereq_id
            AND er.status = 'Pass';

            IF v_completed = 0 THEN
                RAISE_APPLICATION_ERROR(-20001, 
                    'Cannot register for "' || v_course_name || 
                    '": Prerequisite "' || v_prereq_name || '" not completed.');
            END IF;
    END IF;
END;
/

PROMPT [DONE] Feature 2: Prerequisite eligibility trigger created

-- ============================================================================
-- FEATURE 3: Grade Calculation Function
-- ============================================================================
-- Takes ExamResults ID, calculates grade, updates table, returns grade
-- Grade scale: 90-100=A, 80-89=B, 70-79=C, 60-69=D, <60=F
-- ============================================================================

-- NOTE: A new numeric `score` column exists on `user1.ExamResults` (0-100).
-- The `calculate_grade` function prefers an explicit numeric score parameter
-- when provided and will persist that numeric score into the `ExamResults`
-- row. This allows tests to call `calculate_grade(id, numeric_score)` to compute
-- and persist grades based on raw performance data.

-- NOTE: This function currently STANDARDIZES or RE-CALCULATES an existing
-- ExamResults entry: it reads the existing `grade` value and maps it to a
-- representative numeric score solely for demonstration purposes, then
-- assigns a canonical letter grade and Pass/Fail status. It does NOT
-- compute a grade from a raw numeric exam score by default.
--
-- If you need true score-based calculation from raw performance data,
-- change the signature (option A) or add a new function (option B):
-- Option A (modify):
--   CREATE OR REPLACE FUNCTION user1.calculate_grade(
--       p_exam_result_id IN NUMBER,
--       p_score         IN NUMBER
--   ) RETURN VARCHAR2
--   ... use p_score directly for thresholds ...
--
-- Option B (new): implement `calculate_grade_from_score(p_exam_result_id, p_score)`
-- and leave this function as a compatibility wrapper.

PROMPT
PROMPT [FEATURE 3] Creating grade calculation function...

CREATE OR REPLACE FUNCTION user1.calculate_grade(
    p_exam_result_id IN NUMBER,
    p_numeric_score  IN NUMBER DEFAULT NULL
) RETURN VARCHAR2
AS
    v_current_grade VARCHAR2(2);
    v_new_grade     VARCHAR2(2);
    v_status        VARCHAR2(10);
    v_score         NUMBER;
BEGIN
    -- Determine numeric score to use: prefer explicit parameter, else stored score
    IF p_numeric_score IS NOT NULL THEN
        v_score := p_numeric_score;
        -- persist provided score for record-keeping
        UPDATE user1.ExamResults SET score = v_score WHERE id = p_exam_result_id;
    ELSE
        BEGIN
            SELECT score INTO v_score FROM user1.ExamResults WHERE id = p_exam_result_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN NULL; -- No exam result row found
        END;
    END IF;

    -- If there is still no numeric score, cannot compute
    IF v_score IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Calculate grade based on score
    IF v_score >= 90 THEN
        v_new_grade := 'A';
        v_status := 'Pass';
    ELSIF v_score >= 80 THEN
        v_new_grade := 'B';
        v_status := 'Pass';
    ELSIF v_score >= 70 THEN
        v_new_grade := 'C';
        v_status := 'Pass';
    ELSIF v_score >= 60 THEN
        v_new_grade := 'D';
        v_status := 'Pass';
    ELSE
        v_new_grade := 'F';
        v_status := 'Fail';
    END IF;
    
    -- Update the ExamResults table with computed grade/status
    UPDATE user1.ExamResults
    SET grade = v_new_grade,
        status = v_status
    WHERE id = p_exam_result_id;
    
    RETURN v_new_grade;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;
END;
/

PROMPT [DONE] Feature 3: Grade calculation function created

-- ============================================================================
-- FEATURE 4: Automated Warning Issuance Procedure
-- ============================================================================
-- Issues warnings for students with 2+ failing grades
-- ============================================================================

PROMPT
PROMPT [FEATURE 4] Creating automated warning procedure...

CREATE OR REPLACE PROCEDURE user1.issue_warnings_for_failures
AS
    CURSOR c_failing_students IS
        SELECT r.student_id, s.name, COUNT(*) as fail_count
        FROM user1.Register r
        JOIN user1.Students s ON r.student_id = s.id
        JOIN user1.ExamResults er ON r.id = er.registration_id
        WHERE er.status = 'Fail'
        GROUP BY r.student_id, s.name
        HAVING COUNT(*) >= 2;
    
    v_warning_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Checking for students with 2+ failing grades...');
    -- Insert warnings for failing students, avoiding duplicates within 30 days.
    INSERT INTO user1.Warnings (student_id, warning_reason, warning_date)
    SELECT t.student_id, 'Academic Warning: ' || t.fail_count || ' courses failed', SYSDATE
    FROM (
        SELECT r.student_id, COUNT(*) as fail_count
        FROM user1.Register r
        JOIN user1.ExamResults er ON r.id = er.registration_id
        WHERE er.status = 'Fail'
        GROUP BY r.student_id
        HAVING COUNT(*) >= 2
    ) t
    WHERE NOT EXISTS (
        SELECT 1 FROM user1.Warnings w
        WHERE w.student_id = t.student_id
        AND w.warning_reason = 'Academic Warning: ' || t.fail_count || ' courses failed'
        AND w.warning_date > SYSDATE - 30
    );

    v_warning_count := SQL%ROWCOUNT;

    IF v_warning_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  No students have 2+ failures or warnings already exist within 30 days.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Total warnings issued: ' || v_warning_count);
    END IF;

    COMMIT;
END;
/

PROMPT [DONE] Feature 4: Automated warning procedure created

-- ============================================================================
-- FEATURE 5: Audit Trail Triggers (BEFORE INSERT/DELETE on Register)
-- ============================================================================

PROMPT
PROMPT [FEATURE 5] Creating audit trail triggers...

CREATE OR REPLACE TRIGGER user1.trg_audit_register_insert
BEFORE INSERT ON user1.Register
FOR EACH ROW
BEGIN
    INSERT INTO user1.AuditTrail (table_name, operation, old_data, new_data, timestamp)
    VALUES (
        'Register',
        'INSERT',
        NULL,
        'student_id=' || :NEW.student_id || ', course_id=' || :NEW.course_id,
        SYSTIMESTAMP
    );
END;
/

CREATE OR REPLACE TRIGGER user1.trg_audit_register_delete
BEFORE DELETE ON user1.Register
FOR EACH ROW
BEGIN
    INSERT INTO user1.AuditTrail (table_name, operation, old_data, new_data, timestamp)
    VALUES (
        'Register',
        'DELETE',
        'id=' || :OLD.id || ', student_id=' || :OLD.student_id || ', course_id=' || :OLD.course_id,
        NULL,
        SYSTIMESTAMP
    );
END;
/

PROMPT [DONE] Feature 5: Audit trail triggers created

-- ============================================================================
-- FEATURE 6: Course Performance Report (Cursor)
-- ============================================================================
-- Generates pass/fail statistics for a specific course
-- ============================================================================

PROMPT
PROMPT [FEATURE 6] Creating course performance report procedure...

CREATE OR REPLACE PROCEDURE user1.course_performance_report(
    p_course_id IN NUMBER
)
AS
    v_course_name   VARCHAR2(100);
    v_pass_count    NUMBER := 0;
    v_fail_count    NUMBER := 0;
    v_total         NUMBER := 0;
    
    CURSOR c_results IS
        -- Include students who are registered even if they have no exam result yet
        SELECT s.id AS student_id, s.name AS student_name, 
               er.grade, er.status
        FROM user1.Students s
        JOIN user1.Register r ON s.id = r.student_id
        LEFT JOIN user1.ExamResults er ON r.id = er.registration_id
        WHERE r.course_id = p_course_id;
BEGIN
    -- Get course name
    SELECT name INTO v_course_name
    FROM user1.Courses
    WHERE id = p_course_id;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('COURSE PERFORMANCE REPORT');
    DBMS_OUTPUT.PUT_LINE('Course: ' || v_course_name || ' (ID: ' || p_course_id || ')');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('Student ID', 12) || RPAD('Name', 25) || 
                         RPAD('Grade', 8) || 'Status');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 12, '-') || RPAD('-', 25, '-') || 
                         RPAD('-', 8, '-') || '------');
    
    FOR rec IN c_results LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.student_id, 12) || 
            RPAD(rec.student_name, 25) || 
            RPAD(NVL(rec.grade, 'N/A'), 8) || 
            NVL(rec.status, 'No Grade')
        );

        v_total := v_total + 1;
        IF rec.status = 'Pass' THEN
            v_pass_count := v_pass_count + 1;
        ELSIF rec.status = 'Fail' THEN
            v_fail_count := v_fail_count + 1;
        ELSE
            NULL; -- No grade yet
        END IF;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('SUMMARY:');
    DBMS_OUTPUT.PUT_LINE('  Total Students: ' || v_total);
    DBMS_OUTPUT.PUT_LINE('  Passed: ' || v_pass_count || 
                         ' (' || ROUND(v_pass_count * 100 / NULLIF(v_total, 0), 1) || '%)');
    DBMS_OUTPUT.PUT_LINE('  Failed: ' || v_fail_count || 
                         ' (' || ROUND(v_fail_count * 100 / NULLIF(v_total, 0), 1) || '%)');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('Course not found with ID: ' || p_course_id);
END;
/

PROMPT [DONE] Feature 6: Course performance report created

-- ============================================================================
-- FEATURE 7: Exam Schedule Management
-- ============================================================================

PROMPT
PROMPT [FEATURE 7] Creating exam schedule procedure...

CREATE OR REPLACE PROCEDURE user1.display_exam_schedule(
    p_course_id IN NUMBER DEFAULT NULL
)
AS
    v_found BOOLEAN := FALSE;
    v_exists NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('EXAM SCHEDULE');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('');
    -- If a specific course ID was provided, ensure it exists
    IF p_course_id IS NOT NULL THEN
        SELECT COUNT(*) INTO v_exists FROM user1.Courses WHERE id = p_course_id;
        IF v_exists = 0 THEN
            DBMS_OUTPUT.PUT_LINE('Error: Course ID ' || p_course_id || ' not found.');
            RETURN;
        END IF;
    END IF;
    DBMS_OUTPUT.PUT_LINE(RPAD('Course', 30) || RPAD('Exam Date', 15) || 'Exam Type');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', 30, '-') || RPAD('-', 15, '-') || '---------');
    
    FOR rec IN (
        SELECT c.name AS course_name, e.exam_date, e.exam_type
        FROM user1.Exams e
        JOIN user1.Courses c ON e.course_id = c.id
        WHERE (p_course_id IS NULL OR e.course_id = p_course_id)
        ORDER BY e.exam_date
    ) LOOP
        v_found := TRUE;
        DBMS_OUTPUT.PUT_LINE(
            RPAD(rec.course_name, 30) || 
            RPAD(TO_CHAR(rec.exam_date, 'YYYY-MM-DD'), 15) || 
            rec.exam_type
        );
    END LOOP;
    
    IF NOT v_found THEN
        DBMS_OUTPUT.PUT_LINE('No exams scheduled' || 
            CASE WHEN p_course_id IS NOT NULL 
                 THEN ' for course ID ' || p_course_id 
                 ELSE '' END);
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

PROMPT [DONE] Feature 7: Exam schedule procedure created

-- ============================================================================
-- FEATURE 8: Multi-Exam Grade Update with Transactions
-- ============================================================================
-- Updates grades for multiple registrations in a single transaction
-- Rolls back if any error occurs
-- ============================================================================

PROMPT
PROMPT [FEATURE 8] Creating multi-grade update procedure...

CREATE OR REPLACE PROCEDURE user1.update_multiple_grades(
    p_registration_ids IN VARCHAR2,  -- Comma-separated list: '1,2,3'
    p_new_grade        IN VARCHAR2
)
AS
    v_id            NUMBER;
    v_pos           NUMBER;
    v_list          VARCHAR2(1000) := p_registration_ids;
    v_update_count  NUMBER := 0;
    v_status        VARCHAR2(10);
    v_token         VARCHAR2(100);
BEGIN
    -- Determine pass/fail status
    IF p_new_grade IN ('A', 'B', 'C', 'D') THEN
        v_status := 'Pass';
    ELSE
        v_status := 'Fail';
    END IF;

    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Updating grades to ' || p_new_grade || '...');

    -- Process each token in the comma-separated list. Skip empty tokens and
    -- handle whitespace robustly. If any token is invalid, rollback all changes
    -- and raise an error to the caller (requirement: rollback on any error).
    WHILE LENGTH(TRIM(v_list)) > 0 LOOP
        v_pos := INSTR(v_list, ',');
        IF v_pos = 0 THEN
            v_token := TRIM(v_list);
            v_list := '';
        ELSE
            v_token := TRIM(SUBSTR(v_list, 1, v_pos - 1));
            v_list := SUBSTR(v_list, v_pos + 1);
        END IF;

        IF v_token IS NULL OR v_token = '' THEN
            CONTINUE; -- ignore empty tokens like double commas
        END IF;

        BEGIN
            v_id := TO_NUMBER(v_token);
        EXCEPTION
            WHEN VALUE_ERROR THEN
                ROLLBACK;
                RAISE_APPLICATION_ERROR(-20010, 'Invalid registration id: ' || v_token);
        END;

        UPDATE user1.ExamResults
        SET grade = p_new_grade,
            status = v_status
        WHERE id = v_id;

        IF SQL%ROWCOUNT > 0 THEN
            v_update_count := v_update_count + 1;
            DBMS_OUTPUT.PUT_LINE('  Updated ExamResult ID ' || v_id);
        ELSE
            -- Non-existent ID is considered an error per requirements: rollback all
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20011, 'ExamResult ID ' || v_id || ' does not exist. All changes rolled back.');
        END IF;
    END LOOP;

    -- COMMIT here because requirement specifies the procedure commits on success
    -- and rolls back completely on any error. Caller should be aware this
    -- procedure controls the transaction boundary.
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('COMMIT: ' || v_update_count || ' records updated successfully.');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('ROLLBACK: Error occurred - ' || SQLERRM);
        RAISE;
END;
/

PROMPT [DONE] Feature 8: Multi-grade update procedure created

-- ============================================================================
-- FEATURE 9: Student Suspension Based on Warnings
-- ============================================================================
-- Suspends students with 3+ warnings and logs to AuditTrail
-- ============================================================================

PROMPT
PROMPT [FEATURE 9] Creating student suspension procedure...

CREATE OR REPLACE PROCEDURE user1.suspend_students_with_warnings
AS
    CURSOR c_warned_students IS
        SELECT w.student_id, s.name, s.academic_status, COUNT(*) as warning_count
        FROM user1.Warnings w
        JOIN user1.Students s ON w.student_id = s.id
        WHERE s.academic_status = 'Active'
        GROUP BY w.student_id, s.name, s.academic_status
        HAVING COUNT(*) >= 3;
    
    v_suspended_count NUMBER := 0;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Checking for students with 3+ warnings...');
    
    FOR rec IN c_warned_students LOOP
        -- Update student status
        UPDATE user1.Students
        SET academic_status = 'Suspended'
        WHERE id = rec.student_id;
        
        -- Log to AuditTrail
        INSERT INTO user1.AuditTrail (table_name, operation, old_data, new_data, timestamp)
        VALUES (
            'Students',
            'UPDATE',
            'id=' || rec.student_id || ', status=' || rec.academic_status,
            'id=' || rec.student_id || ', status=Suspended',
            SYSTIMESTAMP
        );
        
        v_suspended_count := v_suspended_count + 1;
        DBMS_OUTPUT.PUT_LINE('  SUSPENDED: ' || rec.name || 
                             ' (' || rec.warning_count || ' warnings)');
    END LOOP;
    
    IF v_suspended_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('  No students have 3+ warnings.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Total students suspended: ' || v_suspended_count);
    END IF;
    
    COMMIT;
END;
/

PROMPT [DONE] Feature 9: Student suspension procedure created

-- ============================================================================
-- FEATURE 10A: GPA Calculation Function
-- ============================================================================
-- Calculates GPA based on grades and credit hours
-- ============================================================================

PROMPT
PROMPT [FEATURE 10A] Creating GPA calculation function...

CREATE OR REPLACE FUNCTION user1.calculate_gpa(
    p_student_id IN NUMBER
) RETURN NUMBER
AS
    v_total_points   NUMBER := 0;
    v_total_credits  NUMBER := 0;
    v_gpa            NUMBER(3,2);
    v_grade_points   NUMBER;
BEGIN
    FOR rec IN (
        SELECT c.credit_hours, er.grade
        FROM user1.Register r
        JOIN user1.Courses c ON r.course_id = c.id
        JOIN user1.ExamResults er ON r.id = er.registration_id
        WHERE r.student_id = p_student_id
        AND er.grade IS NOT NULL
    ) LOOP
        -- Convert grade to points
        CASE rec.grade
            WHEN 'A' THEN v_grade_points := 4.0;
            WHEN 'B' THEN v_grade_points := 3.0;
            WHEN 'C' THEN v_grade_points := 2.0;
            WHEN 'D' THEN v_grade_points := 1.0;
            WHEN 'F' THEN v_grade_points := 0.0;
            ELSE v_grade_points := 0.0;
        END CASE;
        
        v_total_points := v_total_points + (v_grade_points * NVL(rec.credit_hours, 3));
        v_total_credits := v_total_credits + NVL(rec.credit_hours, 3);
    END LOOP;
    
    IF v_total_credits > 0 THEN
        v_gpa := ROUND(v_total_points / v_total_credits, 2);
    ELSE
        v_gpa := 0.00;
    END IF;
    
    RETURN v_gpa;
END;
/

PROMPT [DONE] Feature 10A: GPA calculation function created

-- ============================================================================
-- FEATURE 10B: Grade Authorization Trigger
-- ============================================================================
-- Checks if user is authorized to update grades
-- Only MANAGER_ADMIN or specific professors can update grades
-- ============================================================================

PROMPT
PROMPT [FEATURE 10B] Creating grade authorization trigger...

CREATE OR REPLACE TRIGGER user1.trg_grade_authorization
BEFORE UPDATE OF grade ON user1.ExamResults
FOR EACH ROW
DECLARE
    v_user VARCHAR2(50);
    v_allowed_count NUMBER := 0;
BEGIN
    v_user := USER;
    
    -- Prefer checking the GradeUpdaters table in manager_admin. If the table
    -- does not exist or an error occurs, fall back to a safe allow-list.
    -- The manager_admin.GradeUpdaters table lists usernames authorized to
    -- update grades. This trigger consults that table and is FAIL-SECURE:
    -- if the table cannot be queried (missing privileges or other error),
    -- the trigger denies the update to avoid a security bypass.
    BEGIN
        -- Use manager-side helper to check authorization; avoids cross-schema SELECT privilege issues
        v_allowed_count := manager_admin.is_grade_updater(v_user);
    EXCEPTION
        WHEN OTHERS THEN
            -- Fail-secure: if authorization system is unavailable, deny access
            RAISE_APPLICATION_ERROR(-20002, 'Authorization system unavailable. Access denied.');
    END;

    IF v_allowed_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 
            'Unauthorized: User "' || v_user || '" is not allowed to modify grades.');
    END IF;

    -- Log the grade change for auditing
    DBMS_OUTPUT.PUT_LINE('Grade update authorized for user: ' || v_user);
END;
/

PROMPT [DONE] Feature 10B: Grade authorization trigger created

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================
PROMPT
PROMPT ============================================================
PROMPT VERIFICATION TESTS
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Check triggers
    SELECT COUNT(*) INTO v_count 
    FROM all_triggers 
    WHERE owner = 'USER1' AND trigger_name LIKE 'TRG%';
    DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' triggers created');
    
    -- Check functions
    SELECT COUNT(*) INTO v_count 
    FROM all_objects 
    WHERE owner = 'USER1' AND object_type = 'FUNCTION';
    DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' functions created');
    
    -- Check procedures
    SELECT COUNT(*) INTO v_count 
    FROM all_objects 
    WHERE owner = 'USER1' AND object_type = 'PROCEDURE';
    DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_count || ' procedures created');
END;
/

-- List all PL/SQL objects
PROMPT
PROMPT PL/SQL objects created:
SELECT object_name, object_type 
FROM all_objects 
WHERE owner = 'USER1' 
AND object_type IN ('TRIGGER', 'FUNCTION', 'PROCEDURE')
ORDER BY object_type, object_name;

PROMPT
PROMPT ============================================================
PROMPT ALL PL/SQL FEATURES CREATED (Features 2-10)
PROMPT ============================================================
PROMPT
PROMPT NEXT STEP: Run file 06 to test all features
PROMPT   Stay connected as MANAGER_ADMIN
PROMPT ============================================================
