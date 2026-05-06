-- ============================================================================
-- FILE: 04_USER2_INSERT_DATA.sql
-- RUN AS: USER2 (Password: user2pass)
-- PURPOSE: User2 inserts 5 students and their registered courses
-- ============================================================================
-- Per the task: "Let User 2 insert 5 rows of student data and their 
-- registered courses"
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================
PROMPT FILE 4: USER2 INSERTS DATA
PROMPT Run as: USER2
PROMPT ============================================================

-- ==========================================================================
-- CLEANUP: Remove previous test data when re-running this file
-- ==========================================================================
BEGIN
    DELETE FROM user1.ExamResults;
    DELETE FROM user1.Warnings;
    DELETE FROM user1.Register;
    DELETE FROM user1.Exams;
    DELETE FROM user1.Students;
    DELETE FROM user1.Courses;
    DELETE FROM user1.Professors;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[CLEANUP] Existing data removed');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] No existing data to clean or cleanup skipped: ' || SQLERRM);
END;
/

-- ============================================================================
-- STEP 1: Insert Professors
-- ============================================================================
PROMPT
PROMPT [STEP 1] Inserting Professors...

INSERT INTO user1.Professors (name, department) VALUES ('Dr. Yusuf Ahmed', 'Computer Science');
INSERT INTO user1.Professors (name, department) VALUES ('Dr. Toqa Hassan', 'Computer Science');
INSERT INTO user1.Professors (name, department) VALUES ('Dr. Mohamed Ali', 'Mathematics');

COMMIT;
PROMPT [DONE] 3 Professors inserted

-- ============================================================================
-- STEP 2: Insert Courses (with prerequisite relationships)
-- ============================================================================
PROMPT
PROMPT [STEP 2] Inserting Courses...

-- Courses WITHOUT prerequisites (must be inserted first)
INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Introduction to Programming', 1, 3, NULL);

INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Calculus I', 3, 4, NULL);

INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Discrete Mathematics', 3, 3, NULL);

-- Courses WITH prerequisites
INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Data Structures', 1, 3, 1);  -- Requires: Introduction to Programming (id=1)

INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Database Systems', 2, 3, 4); -- Requires: Data Structures (id=4)

INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Algorithms', 1, 3, 4);       -- Requires: Data Structures (id=4)

INSERT INTO user1.Courses (name, professor_id, credit_hours, prerequisite_course_id)
VALUES ('Calculus II', 3, 4, 2);      -- Requires: Calculus I (id=2)

COMMIT;
PROMPT [DONE] 7 Courses inserted

-- ============================================================================
-- STEP 3: Insert 5 Students (as required)
-- ============================================================================
PROMPT
PROMPT [STEP 3] Inserting 5 Students...

INSERT INTO user1.Students (name, academic_status, total_credits) 
VALUES ('Alice Johnson', 'Active', 15);

INSERT INTO user1.Students (name, academic_status, total_credits) 
VALUES ('Bob Smith', 'Active', 12);

INSERT INTO user1.Students (name, academic_status, total_credits) 
VALUES ('Carol Williams', 'Active', 9);

INSERT INTO user1.Students (name, academic_status, total_credits) 
VALUES ('David Brown', 'Active', 6);

INSERT INTO user1.Students (name, academic_status, total_credits) 
VALUES ('Eve Davis', 'Active', 18);

COMMIT;
PROMPT [DONE] 5 Students inserted

-- ============================================================================
-- STEP 4: Insert Registrations
-- NOTE: At this point, no prerequisite trigger exists yet, so all 
-- registrations will succeed. The trigger will be created in file 05.
-- ============================================================================
PROMPT
PROMPT [STEP 4] Inserting Course Registrations...

-- Student 1 (Alice) - advanced student
INSERT INTO user1.Register (student_id, course_id) VALUES (1, 1);  -- Intro to Prog
INSERT INTO user1.Register (student_id, course_id) VALUES (1, 2);  -- Calculus I

-- Student 2 (Bob)
INSERT INTO user1.Register (student_id, course_id) VALUES (2, 1);  -- Intro to Prog
INSERT INTO user1.Register (student_id, course_id) VALUES (2, 3);  -- Discrete Math

-- Student 3 (Carol)
INSERT INTO user1.Register (student_id, course_id) VALUES (3, 1);  -- Intro to Prog
INSERT INTO user1.Register (student_id, course_id) VALUES (3, 2);  -- Calculus I

-- Student 4 (David)
INSERT INTO user1.Register (student_id, course_id) VALUES (4, 1);  -- Intro to Prog
INSERT INTO user1.Register (student_id, course_id) VALUES (4, 2);  -- Calculus I

-- Student 5 (Eve)
INSERT INTO user1.Register (student_id, course_id) VALUES (5, 1);  -- Intro to Prog

COMMIT;
PROMPT [DONE] 14 Registrations inserted

-- ============================================================================
-- STEP 5: Insert Exams
-- ============================================================================
PROMPT
PROMPT [STEP 5] Inserting Exams...

INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (1, DATE '2024-10-15', 'Midterm');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (1, DATE '2024-12-20', 'Final');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (2, DATE '2024-10-16', 'Midterm');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (2, DATE '2024-12-21', 'Final');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (4, DATE '2024-10-18', 'Midterm');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (4, DATE '2024-12-22', 'Final');
INSERT INTO user1.Exams (course_id, exam_date, exam_type) VALUES (5, DATE '2024-12-23', 'Final');

COMMIT;
PROMPT [DONE] 7 Exams inserted

-- ============================================================================
-- STEP 6: Insert Exam Results
-- NOTE: Some students will have 'Fail' status to test warning system
-- ============================================================================
PROMPT
PROMPT [STEP 6] Inserting Exam Results...

-- Insert exam results for base/prerequisite registrations only (Intro, Calculus I, Discrete Math)
-- Use subqueries to resolve registration_id so ordering changes won't break references

-- Alice: Intro (course 1) and Calculus I (course 2)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 1 AND r.course_id = 1),
    92, 'A', 'Pass'
);
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 1 AND r.course_id = 2),
    85, 'B', 'Pass'
);

-- Bob: Intro (1) and Discrete Math (3)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 2 AND r.course_id = 1),
    75, 'C', 'Pass'
);
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 2 AND r.course_id = 3),
    45, 'F', 'Fail'
);

-- Carol: Intro (1) and Calculus I (2)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 3 AND r.course_id = 1),
    30, 'F', 'Fail'
);
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 3 AND r.course_id = 2),
    35, 'F', 'Fail'
);

-- David: Intro (1) and Calculus I (2)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 4 AND r.course_id = 1),
    85, 'B', 'Pass'
);
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 4 AND r.course_id = 2),
    75, 'C', 'Pass'
);

-- Eve: Intro (1)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 5 AND r.course_id = 1),
    95, 'A', 'Pass'
);

COMMIT;
PROMPT [DONE] Base exam results inserted

-- ============================================================================
-- STEP 7: Insert advanced registrations (after prerequisites passed)
-- ============================================================================
PROMPT
PROMPT [STEP 7] Inserting advanced registrations (post-prerequisite)...
-- ============================================================================
-- STEP 8: Insert Exam Results for advanced registrations
-- ============================================================================
PROMPT
PROMPT [STEP 8] Inserting advanced Exam Results...
-- ============================================================================
-- STEP 7: Insert first-level advanced registrations (Data Structures)
-- ============================================================================
PROMPT
PROMPT [STEP 7] Inserting first-level advanced registrations (Data Structures)...

-- Alice: Data Structures (4)
INSERT INTO user1.Register (student_id, course_id) VALUES (1, 4);  -- Data Structures

-- Bob: Data Structures (4)
INSERT INTO user1.Register (student_id, course_id) VALUES (2, 4);  -- Data Structures

-- Eve: Data Structures (4)
INSERT INTO user1.Register (student_id, course_id) VALUES (5, 4);  -- Data Structures

COMMIT;
PROMPT [DONE] First-level advanced registrations inserted

-- ============================================================================
-- STEP 8: Insert Exam Results for first-level advanced courses (Data Structures)
-- ============================================================================
PROMPT
PROMPT [STEP 8] Inserting Exam Results for Data Structures registrations...

-- Alice: Data Structures (student 1, course 4)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 1 AND r.course_id = 4),
    92, 'A', 'Pass'
);

-- Bob: Data Structures (student 2, course 4) - Fail
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 2 AND r.course_id = 4),
    40, 'F', 'Fail'
);

-- Eve: Data Structures (student 5, course 4)
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 5 AND r.course_id = 4),
    90, 'A', 'Pass'
);

COMMIT;
PROMPT [DONE] First-level advanced Exam Results inserted

-- ============================================================================
-- STEP 9: Insert second-level advanced registrations (after Data Structures passed)
-- ============================================================================
PROMPT
PROMPT [STEP 9] Inserting second-level advanced registrations (post-Data Structures)...

-- Alice: Database Systems (5)
INSERT INTO user1.Register (student_id, course_id) VALUES (1, 5);  -- Database Systems

-- Eve: Algorithms (6)
INSERT INTO user1.Register (student_id, course_id) VALUES (5, 6);  -- Algorithms

COMMIT;
PROMPT [DONE] Second-level advanced registrations inserted

-- ============================================================================
-- STEP 10: Insert Exam Results for second-level advanced courses
-- ============================================================================
PROMPT
PROMPT [STEP 10] Inserting Exam Results for second-level advanced courses...

-- Alice: Database Systems
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 1 AND r.course_id = 5),
    85, 'B', 'Pass'
);

-- Eve: Algorithms
INSERT INTO user1.ExamResults (registration_id, score, grade, status)
VALUES (
    (SELECT id FROM user1.Register r WHERE r.student_id = 5 AND r.course_id = 6),
    88, 'B', 'Pass'
);

COMMIT;
PROMPT [DONE] Second-level advanced Exam Results inserted

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================
PROMPT
PROMPT ============================================================
PROMPT VERIFICATION TESTS
PROMPT ============================================================

DECLARE
    v_students NUMBER;
    v_courses NUMBER;
    v_registers NUMBER;
    v_exams NUMBER;
    v_results NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_students FROM user1.Students;
    SELECT COUNT(*) INTO v_courses FROM user1.Courses;
    SELECT COUNT(*) INTO v_registers FROM user1.Register;
    SELECT COUNT(*) INTO v_exams FROM user1.Exams;
    SELECT COUNT(*) INTO v_results FROM user1.ExamResults;
    
    IF v_students = 5 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] 5 Students inserted (as required)');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected 5 students, found ' || v_students);
    END IF;
    
    IF v_courses >= 5 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_courses || ' Courses inserted');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Not enough courses');
    END IF;
    
    IF v_registers >= 10 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_registers || ' Registrations inserted');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Not enough registrations');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_exams || ' Exams created');
    DBMS_OUTPUT.PUT_LINE('[INFO] ' || v_results || ' Exam Results created');
END;
/

-- Show students with their registration count
PROMPT
PROMPT Students and their registrations:
SELECT s.id, s.name, s.academic_status, COUNT(r.id) as registered_courses
FROM user1.Students s
LEFT JOIN user1.Register r ON s.id = r.student_id
GROUP BY s.id, s.name, s.academic_status
ORDER BY s.id;

-- Show students with failing grades (for warning test)
PROMPT
PROMPT Students with failing grades:
SELECT s.name, COUNT(*) as fail_count
FROM user1.Students s
JOIN user1.Register r ON s.id = r.student_id
JOIN user1.ExamResults er ON r.id = er.registration_id
WHERE er.status = 'Fail'
GROUP BY s.name
HAVING COUNT(*) >= 2;

PROMPT
PROMPT ============================================================
PROMPT DATA INSERTION COMPLETE
PROMPT ============================================================
PROMPT Summary:
PROMPT   - 3 Professors
PROMPT   - 7 Courses (with prerequisites)
PROMPT   - 5 Students (as required)
PROMPT   - 14 Registrations
PROMPT   - 7 Exams
PROMPT   - 14 Exam Results (Bob & Carol have 2+ fails each)
PROMPT ============================================================
PROMPT
PROMPT NEXT STEP: Connect as MANAGER_ADMIN and run file 05
PROMPT   Username: manager_admin
PROMPT   Password: manager123
PROMPT ============================================================
