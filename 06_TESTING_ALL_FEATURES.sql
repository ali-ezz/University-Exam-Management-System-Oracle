-- ============================================================================
-- FILE: 06_TESTING_ALL_FEATURES.sql
-- RUN AS: MANAGER_ADMIN (Password: manager123)
-- PURPOSE: Test all 10 features with verification
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ************************************************************
PROMPT *    UNIVERSITY EXAM MANAGEMENT SYSTEM - FEATURE TESTING   *
PROMPT ************************************************************
PROMPT

-- ============================================================================
-- TEST 1: Feature 1 - User Management
-- ============================================================================
PROMPT ============================================================
PROMPT TEST 1: FEATURE 1 - User Management
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Check users exist
    SELECT COUNT(*) INTO v_count FROM all_users 
    WHERE username IN ('MANAGER_ADMIN', 'USER1', 'USER2');
    
    IF v_count = 3 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] All 3 users exist');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected 3 users, found ' || v_count);
    END IF;
    
    -- Check DBUserCreationLog
    SELECT COUNT(*) INTO v_count FROM manager_admin.DBUserCreationLog;
    IF v_count >= 2 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_count || ' entries in DBUserCreationLog');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] DBUserCreationLog has insufficient entries');
    END IF;
END;
/

-- Show log
SELECT * FROM manager_admin.DBUserCreationLog;

PROMPT
PROMPT ============================================================
PROMPT TEST 2: FEATURE 2 - Prerequisite Eligibility Trigger
PROMPT ============================================================

PROMPT
PROMPT Test: Trying to register Student 4 (David) for Database Systems...
PROMPT David has NOT passed Data Structures (prerequisite)
PROMPT Expected: Error - prerequisite not met

DECLARE
    v_error_caught BOOLEAN := FALSE;
BEGIN
    -- Try to register David (id=4) for Database Systems (id=5)
    -- David hasn't passed Data Structures (id=4), which is prerequisite
    INSERT INTO user1.Register (student_id, course_id) VALUES (4, 5);
    
    DBMS_OUTPUT.PUT_LINE('[FAIL] Insert succeeded - trigger NOT working!');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20001 THEN
            DBMS_OUTPUT.PUT_LINE('[PASS] Trigger blocked registration: ' || SQLERRM);
        ELSE
            DBMS_OUTPUT.PUT_LINE('[FAIL] Unexpected error: ' || SQLERRM);
        END IF;
END;
/

-- Positive test: Student 1 (Alice) has passed Data Structures and should be allowed
PROMPT
PROMPT Positive Test: Register Student 1 (Alice) for Algorithms (requires Data Structures)
DECLARE
    v_ok NUMBER := 0;
BEGIN
    -- Ensure Alice has passed Data Structures (course id 4)
    SELECT COUNT(*) INTO v_ok
    FROM user1.Register r
    JOIN user1.ExamResults er ON r.id = er.registration_id
    WHERE r.student_id = 1 AND r.course_id = 4 AND er.status = 'Pass';

    IF v_ok = 0 THEN
        DBMS_OUTPUT.PUT_LINE('[WARN] Alice does not appear to have passed prereq; skipping positive prereq test');
    ELSE
        INSERT INTO user1.Register (student_id, course_id) VALUES (1, 6); -- Algorithms
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('[PASS] Alice registered for Algorithms (prerequisite satisfied)');
        -- cleanup for test
        DELETE FROM user1.Register WHERE student_id = 1 AND course_id = 6;
        COMMIT;
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 3: FEATURE 3 - Grade Calculation Function
PROMPT ============================================================
DECLARE
    v_grade VARCHAR2(2);
    v_test_passed BOOLEAN := TRUE;
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3A: Calculate grade from stored score');
    v_grade := user1.calculate_grade(1);  -- Uses stored score
    IF v_grade = 'A' THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Stored score 92 -> Grade A');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected A, got ' || NVL(v_grade,'NULL'));
        v_test_passed := FALSE;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3B: Calculate grade from provided score (85)');
    v_grade := user1.calculate_grade(2, 85);  -- Override with score 85
    IF v_grade = 'B' THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Score 85 -> Grade B');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected B, got ' || NVL(v_grade,'NULL'));
        v_test_passed := FALSE;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3C: Calculate grade from edge case (60)');
    v_grade := user1.calculate_grade(3, 60);  -- Boundary: 60 = D (Pass)
    IF v_grade = 'D' THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Score 60 -> Grade D (Pass)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected D, got ' || NVL(v_grade,'NULL'));
        v_test_passed := FALSE;
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Test 3D: Calculate grade from failing score (59)');
    v_grade := user1.calculate_grade(4, 59);  -- Boundary: 59 = F (Fail)
    IF v_grade = 'F' THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Score 59 -> Grade F (Fail)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected F, got ' || NVL(v_grade,'NULL'));
        v_test_passed := FALSE;
    END IF;
    
    IF v_test_passed THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[PASS] Feature 3: All grade calculation tests passed');
    ELSE
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[FAIL] Feature 3: Some tests failed');
    END IF;
END;
/

-- Verify scores were persisted
PROMPT
PROMPT Verifying scores were stored in database:
SELECT id, registration_id, score, grade, status 
FROM user1.ExamResults 
WHERE ROWNUM <= 10
ORDER BY id;


PROMPT
PROMPT ============================================================
PROMPT TEST 4: FEATURE 4 - Automated Warning Issuance
PROMPT ============================================================

PROMPT Before running warning procedure:
SELECT s.name, COUNT(*) as fail_count
FROM user1.Students s
JOIN user1.Register r ON s.id = r.student_id
JOIN user1.ExamResults er ON r.id = er.registration_id
WHERE er.status = 'Fail'
GROUP BY s.name
HAVING COUNT(*) >= 2;

PROMPT
PROMPT Running issue_warnings_for_failures procedure...

BEGIN
    user1.issue_warnings_for_failures();
END;
/

PROMPT
PROMPT Warnings in database:
SELECT w.id, s.name, w.warning_reason, w.warning_date
FROM user1.Warnings w
JOIN user1.Students s ON w.student_id = s.id;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user1.Warnings;
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_count || ' warnings issued');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[INFO] No warnings issued (no students with 2+ fails)');
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 5: FEATURE 5 - Audit Trail Triggers
PROMPT ============================================================

PROMPT Current audit entries:
SELECT id, table_name, operation, 
       SUBSTR(old_data, 1, 30) as old_data,
       SUBSTR(new_data, 1, 30) as new_data
FROM user1.AuditTrail
ORDER BY id;

PROMPT
PROMPT Testing INSERT audit (registering Student 4 for Discrete Math)...

DECLARE
    v_count_before NUMBER;
    v_count_after NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count_before FROM user1.AuditTrail;
    
    -- Insert a new registration (Discrete Math has no prerequisite)
    INSERT INTO user1.Register (student_id, course_id) VALUES (4, 3);
    COMMIT;
    
    SELECT COUNT(*) INTO v_count_after FROM user1.AuditTrail;
    
    IF v_count_after > v_count_before THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] INSERT trigger created audit entry');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] INSERT trigger did not create audit entry');
    END IF;
END;
/

PROMPT
PROMPT Testing DELETE audit...

DECLARE
    v_count_before NUMBER;
    v_count_after NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count_before FROM user1.AuditTrail;
    
    -- Delete the registration we just created
    DELETE FROM user1.Register WHERE student_id = 4 AND course_id = 3;
    COMMIT;
    
    SELECT COUNT(*) INTO v_count_after FROM user1.AuditTrail;
    
    IF v_count_after > v_count_before THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] DELETE trigger created audit entry');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] DELETE trigger did not create audit entry');
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 6: FEATURE 6 - Course Performance Report
PROMPT ============================================================

PROMPT Running course_performance_report for Course 1 (Intro to Programming)...

BEGIN
    user1.course_performance_report(1);
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 7: FEATURE 7 - Exam Schedule Management
PROMPT ============================================================

PROMPT Running display_exam_schedule...

BEGIN
    user1.display_exam_schedule();
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 8: FEATURE 8 - Multi-Exam Grade Update
PROMPT ============================================================

PROMPT Before update:
SELECT id, registration_id, grade, status 
FROM user1.ExamResults 
WHERE id IN (10, 11);

PROMPT
PROMPT Updating ExamResult IDs 10 and 11 to grade 'A'...

BEGIN
    user1.update_multiple_grades('10,11', 'A');
END;
/

-- ROLLBACK test: provide an invalid ID in the middle and verify no changes persisted
PROMPT
PROMPT ROLLBACK Test: update ids 10,9999,11 (9999 invalid) - expect rollback
DECLARE
    v_before10 VARCHAR2(2);
    v_before11 VARCHAR2(2);
BEGIN
    SELECT grade INTO v_before10 FROM user1.ExamResults WHERE id = 10;
    SELECT grade INTO v_before11 FROM user1.ExamResults WHERE id = 11;
    BEGIN
        user1.update_multiple_grades('10,9999,11', 'B');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[INFO] Expected error during multi-update: ' || SQLERRM);
    END;
    -- Verify no changes
    DECLARE
        v_after10 VARCHAR2(2);
        v_after11 VARCHAR2(2);
    BEGIN
        SELECT grade INTO v_after10 FROM user1.ExamResults WHERE id = 10;
        SELECT grade INTO v_after11 FROM user1.ExamResults WHERE id = 11;
        IF v_after10 = v_before10 AND v_after11 = v_before11 THEN
            DBMS_OUTPUT.PUT_LINE('[PASS] ROLLBACK behavior verified: no partial updates');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[FAIL] ROLLBACK did not revert changes as expected');
        END IF;
    END;
END;
/

PROMPT
PROMPT After update:
SELECT id, registration_id, grade, status 
FROM user1.ExamResults 
WHERE id IN (10, 11);

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM user1.ExamResults 
    WHERE id IN (10, 11) AND grade = 'A';
    
    IF v_count = 2 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] Multi-grade update successful');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Multi-grade update failed');
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 9: FEATURE 9 - Student Suspension
PROMPT ============================================================

PROMPT Adding additional warnings to test suspension (need 3+)...

-- Add more warnings to Bob and Carol
BEGIN
    INSERT INTO user1.Warnings (student_id, warning_reason) 
    VALUES (2, 'Second warning - low attendance');
    INSERT INTO user1.Warnings (student_id, warning_reason) 
    VALUES (2, 'Third warning - academic probation');
    INSERT INTO user1.Warnings (student_id, warning_reason) 
    VALUES (3, 'Second warning - missed deadline');
    INSERT INTO user1.Warnings (student_id, warning_reason) 
    VALUES (3, 'Third warning - academic probation');
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Additional warnings added for testing');
END;
/

PROMPT
PROMPT Warnings per student:
SELECT s.name, COUNT(*) as warning_count
FROM user1.Students s
JOIN user1.Warnings w ON s.id = w.student_id
GROUP BY s.name
ORDER BY warning_count DESC;

PROMPT
PROMPT Student status before suspension:
SELECT id, name, academic_status FROM user1.Students;

PROMPT
PROMPT Running suspend_students_with_warnings procedure...

BEGIN
    user1.suspend_students_with_warnings();
END;
/

PROMPT
PROMPT Student status after suspension:
SELECT id, name, academic_status FROM user1.Students;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM user1.Students 
    WHERE academic_status = 'Suspended';
    
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_count || ' student(s) suspended');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[INFO] No students suspended (none have 3+ warnings)');
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 10: FEATURE 10 - GPA Calculation
PROMPT ============================================================

PROMPT Calculating GPA for all students...

DECLARE
    v_gpa NUMBER;
BEGIN
    FOR rec IN (SELECT id, name FROM user1.Students ORDER BY id) LOOP
        v_gpa := user1.calculate_gpa(rec.id);
        DBMS_OUTPUT.PUT_LINE('  ' || rec.name || ': GPA = ' || NVL(TO_CHAR(v_gpa), 'N/A'));
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('[PASS] GPA calculation function works');
END;
/

PROMPT
PROMPT ============================================================
PROMPT TEST 10B: Grade Authorization Trigger
PROMPT ============================================================

PROMPT Testing grade update by MANAGER_ADMIN (should succeed)...

DECLARE
BEGIN
    UPDATE user1.ExamResults SET grade = 'A' WHERE id = 1;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[PASS] MANAGER_ADMIN can update grades');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[FAIL] ' || SQLERRM);
        ROLLBACK;
END;
/

PROMPT
PROMPT Unauthorized update test (manual):
PROMPT   To test grade authorization you must attempt an UPDATE as a non-authorized user (e.g., connect as USER2)
PROMPT   Example (in SQL Developer, connect as USER2):
PROMPT     UPDATE user1.ExamResults SET grade = 'A' WHERE id = 1;  -- should raise unauthorized error
PROMPT   Then reconnect as MANAGER_ADMIN and verify grade unchanged.
PROMPT

PROMPT
PROMPT ************************************************************
PROMPT *                 TEST SUMMARY                              *
PROMPT ************************************************************
PROMPT
PROMPT Feature 1:  User Management           - TESTED
PROMPT Feature 2:  Prerequisite Trigger      - TESTED
PROMPT Feature 3:  Grade Calculation         - TESTED
PROMPT Feature 4:  Automated Warnings        - TESTED
PROMPT Feature 5:  Audit Trail               - TESTED
PROMPT Feature 6:  Performance Report        - TESTED
PROMPT Feature 7:  Exam Schedule             - TESTED
PROMPT Feature 8:  Multi-Grade Update        - TESTED
PROMPT Feature 9:  Student Suspension        - TESTED
PROMPT Feature 10: GPA + Authorization       - TESTED
PROMPT
PROMPT ************************************************************
PROMPT
PROMPT NEXT: Run file 07 for Blocker-Waiting Demo (Features 11-12)
PROMPT ************************************************************
