-- ============================================================================
-- FILE: 03_USER1_CREATE_TABLES.sql
-- RUN AS: USER1 (Password: user1pass)
-- PURPOSE: User1 creates all required tables
-- ============================================================================
-- Per the task: "Let User 1 create the Students and Courses tables"
-- We also create all other required tables here for the system to work
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================
PROMPT FILE 3: USER1 CREATES ALL TABLES
PROMPT Run as: USER1
PROMPT ============================================================

-- ============================================================================
-- CLEANUP: Drop all existing tables if re-running
-- ============================================================================
PROMPT
PROMPT [CLEANUP] Dropping existing tables...

BEGIN
    -- Drop in reverse dependency order
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Warnings CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.AuditTrail CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.ExamResults CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Exams CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Register CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Students CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Courses CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.Professors CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE user1.BlockingDemo CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[DONE] Existing USER1 tables cleaned');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] Table cleanup skipped: ' || SQLERRM);
END;
/


-- ============================================================================
-- TABLE 1: Professors (id, name, department)
-- ============================================================================
PROMPT
PROMPT [TABLE 1] Creating Professors...

CREATE TABLE user1.Professors (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR2(100) NOT NULL,
    department  VARCHAR2(100)
);

PROMPT [DONE] Professors table created

-- ============================================================================
-- TABLE 2: Courses (id, name, professor_id, credit_hours, prerequisite_course_id)
-- ============================================================================
PROMPT
PROMPT [TABLE 2] Creating Courses...

CREATE TABLE user1.Courses (
    id                      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name                    VARCHAR2(100) NOT NULL,
    professor_id            NUMBER REFERENCES user1.Professors(id),
    credit_hours            NUMBER(1) CHECK (credit_hours BETWEEN 1 AND 6),
    prerequisite_course_id  NUMBER REFERENCES user1.Courses(id)
);

PROMPT [DONE] Courses table created

-- ============================================================================
-- TABLE 3: Students (id, name, academic_status, total_credits)
-- ============================================================================
PROMPT
PROMPT [TABLE 3] Creating Students...

CREATE TABLE user1.Students (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name            VARCHAR2(100) NOT NULL,
    academic_status VARCHAR2(20) DEFAULT 'Active' 
                    CHECK (academic_status IN ('Active', 'Suspended', 'Graduated')),
    total_credits   NUMBER DEFAULT 0
);

PROMPT [DONE] Students table created

-- ============================================================================
-- TABLE 4: Register (id, student_id, course_id)
-- ============================================================================
PROMPT
PROMPT [TABLE 4] Creating Register...

CREATE TABLE user1.Register (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id  NUMBER NOT NULL REFERENCES user1.Students(id),
    course_id   NUMBER NOT NULL REFERENCES user1.Courses(id),
    CONSTRAINT uk_student_course UNIQUE (student_id, course_id)
);

PROMPT [DONE] Register table created

-- ============================================================================
-- TABLE 5: Exams (id, course_id, exam_date, exam_type)
-- ============================================================================
PROMPT
PROMPT [TABLE 5] Creating Exams...

CREATE TABLE user1.Exams (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    course_id   NUMBER NOT NULL REFERENCES user1.Courses(id),
    exam_date   DATE NOT NULL,
    exam_type   VARCHAR2(20) CHECK (exam_type IN ('Midterm', 'Final', 'Quiz'))
);

PROMPT [DONE] Exams table created

-- ============================================================================
-- TABLE 6: ExamResults (id, registration_id, grade, status)
-- NOTE: Uses registration_id (not student_id) as per requirements
-- ============================================================================
PROMPT
PROMPT [TABLE 6] Creating ExamResults...

-- NOTE: 'grade' stores the letter grade (A/B/C/D/F). The optional numeric 'score'
-- column is not required by the base spec but can be added later if desired.
CREATE TABLE user1.ExamResults (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    registration_id NUMBER NOT NULL REFERENCES user1.Register(id),
    score           NUMBER(5,2) DEFAULT NULL,
    grade           VARCHAR2(2),
    status          VARCHAR2(10) CHECK (status IN ('Pass', 'Fail')),
    CONSTRAINT chk_score_range CHECK (score IS NULL OR (score BETWEEN 0 AND 100))
);

PROMPT [DONE] ExamResults table created

-- ============================================================================
-- TABLE 7: AuditTrail (id, table_name, operation, old_data, new_data, timestamp)
-- ============================================================================
PROMPT
PROMPT [TABLE 7] Creating AuditTrail...

CREATE TABLE user1.AuditTrail (
    id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    table_name  VARCHAR2(50) NOT NULL,
    operation   VARCHAR2(20) NOT NULL,
    old_data    VARCHAR2(1000),
    new_data    VARCHAR2(1000),
    timestamp   TIMESTAMP DEFAULT SYSTIMESTAMP
);

PROMPT [DONE] AuditTrail table created

-- ============================================================================
-- TABLE 8: Warnings (id, student_id, warning_reason, warning_date)
-- ============================================================================
PROMPT
PROMPT [TABLE 8] Creating Warnings...

CREATE TABLE user1.Warnings (
    id              NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    student_id      NUMBER NOT NULL REFERENCES user1.Students(id),
    warning_reason  VARCHAR2(500) NOT NULL,
    warning_date    DATE DEFAULT SYSDATE
);

PROMPT [DONE] Warnings table created

-- ============================================================================
-- GRANT PRIVILEGES TO USER2 (for data insertion)
-- ============================================================================
PROMPT
PROMPT [GRANTS] Granting privileges to USER2...

-- Ensure USER2 can perform DELETE for cleanup scripts when re-running
GRANT SELECT, INSERT, DELETE ON user1.Professors TO user2;
GRANT SELECT, INSERT, DELETE ON user1.Courses TO user2;
GRANT SELECT, INSERT, DELETE ON user1.Students TO user2;
GRANT SELECT, INSERT, DELETE ON user1.Register TO user2;
GRANT SELECT, INSERT, DELETE ON user1.Exams TO user2;
GRANT SELECT, INSERT, DELETE ON user1.ExamResults TO user2;
GRANT SELECT, INSERT, DELETE ON user1.AuditTrail TO user2;
GRANT SELECT, INSERT, DELETE ON user1.Warnings TO user2;

PROMPT [DONE] Privileges granted to USER2

-- ============================================================================
-- GRANT PRIVILEGES TO MANAGER_ADMIN (for PL/SQL features)
-- ============================================================================
PROMPT
PROMPT [GRANTS] Granting privileges to MANAGER_ADMIN...

GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Professors TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Courses TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Students TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Register TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Exams TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.ExamResults TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.AuditTrail TO manager_admin;
GRANT SELECT, INSERT, UPDATE, DELETE ON user1.Warnings TO manager_admin;

-- Grant trigger creation on Register table
GRANT ALTER ON user1.Register TO manager_admin;
GRANT ALTER ON user1.ExamResults TO manager_admin;

PROMPT [DONE] Privileges granted to MANAGER_ADMIN

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================
PROMPT
PROMPT ============================================================
PROMPT VERIFICATION TESTS
PROMPT ============================================================

DECLARE
    v_count NUMBER;
    v_expected NUMBER := 8;
BEGIN
    SELECT COUNT(*) INTO v_count FROM user_tables;
    IF v_count >= v_expected THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_count || ' tables created');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Expected ' || v_expected || ' tables, found ' || v_count);
    END IF;
END;
/

-- List all tables
PROMPT
PROMPT Tables created by USER1:
SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT
PROMPT ============================================================
PROMPT ALL TABLES CREATED SUCCESSFULLY
PROMPT ============================================================
PROMPT Tables: Professors, Courses, Students, Register,
PROMPT         Exams, ExamResults, AuditTrail, Warnings
PROMPT ============================================================
PROMPT
PROMPT NEXT STEP: Connect as USER2 and run file 04
PROMPT   Username: user2
PROMPT   Password: user2pass
PROMPT ============================================================
