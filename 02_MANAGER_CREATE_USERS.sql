-- ============================================================================
-- FILE: 02_MANAGER_CREATE_USERS.sql
-- RUN AS: MANAGER_ADMIN (Password: manager123)
-- PURPOSE: Create User1 and User2, plus DBUserCreationLog table
-- ============================================================================
-- FEATURE 1 (Part B): Manager creates two users
--   - User1 will create Students and Courses tables
--   - User2 will insert 5 rows of student data
--   - DBUserCreationLog table logs all user creations
-- ============================================================================
























SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================
PROMPT FILE 2: MANAGER CREATES USER1 AND USER2
PROMPT Run as: MANAGER_ADMIN
PROMPT ============================================================

-- ============================================================================
-- CLEANUP: Drop existing objects if re-running
-- ============================================================================
PROMPT
PROMPT [CLEANUP] Removing existing objects...

BEGIN
    -- Drop tables in correct order (respecting foreign keys)
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE manager_admin.BlockingSessionsLog CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE manager_admin.GradeUpdaters CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE manager_admin.DBUserCreationLog CASCADE CONSTRAINTS'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    -- Drop procedures
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE manager_admin.log_user_creation'; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE manager_admin.find_blocking_sessions'; EXCEPTION WHEN OTHERS THEN NULL; END;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('[DONE] Existing MANAGER_ADMIN objects cleaned');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('[INFO] Cleanup skipped or partial: ' || SQLERRM);
END;
/

PROMPT

-- ============================================================================
-- STEP 1: Create DBUserCreationLog table (for Feature 1)
-- ============================================================================
PROMPT
PROMPT [STEP 1] Creating DBUserCreationLog table...

CREATE TABLE manager_admin.DBUserCreationLog (
    log_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username        VARCHAR2(50) NOT NULL,
    created_by      VARCHAR2(50) NOT NULL,
    creation_date   TIMESTAMP DEFAULT SYSTIMESTAMP
);

PROMPT [DONE] DBUserCreationLog table created

-- ============================================================================
-- STEP 2: Create PL/SQL Procedure to log user creation (Feature 1)
-- ============================================================================
PROMPT
PROMPT [STEP 2] Creating log_user_creation procedure...

CREATE OR REPLACE PROCEDURE manager_admin.log_user_creation(
    p_username   IN VARCHAR2,
    p_created_by IN VARCHAR2
) AS
BEGIN
    INSERT INTO manager_admin.DBUserCreationLog (username, created_by, creation_date)
    VALUES (UPPER(p_username), UPPER(p_created_by), SYSTIMESTAMP);
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  Logged: User ' || UPPER(p_username) || ' created by ' || UPPER(p_created_by));
END;
/

PROMPT [DONE] log_user_creation procedure created

-- ============================================================================
-- STEP 3: Create USER1 (will create tables)
-- ============================================================================
PROMPT
PROMPT [STEP 3] Creating USER1...

CREATE USER user1 IDENTIFIED BY user1pass
    DEFAULT TABLESPACE users
    QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO user1;
GRANT CREATE TABLE TO user1;
GRANT CREATE SEQUENCE TO user1;
GRANT UNLIMITED TABLESPACE TO user1;

-- Log user creation
BEGIN
    manager_admin.log_user_creation('USER1', 'MANAGER_ADMIN');
END;
/

PROMPT [DONE] USER1 created (Password: user1pass)

-- ============================================================================
-- STEP 4: Create USER2 (will insert data)
-- ============================================================================
PROMPT
PROMPT [STEP 4] Creating USER2...

CREATE USER user2 IDENTIFIED BY user2pass
    DEFAULT TABLESPACE users
    QUOTA UNLIMITED ON users;

GRANT CREATE SESSION TO user2;

-- Log user creation
BEGIN
    manager_admin.log_user_creation('USER2', 'MANAGER_ADMIN');
END;
/

PROMPT [DONE] USER2 created (Password: user2pass)

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================

-- ============================================================================
-- STEP 5: Create GradeUpdaters table (used by grade authorization trigger)
-- ============================================================================
PROMPT
PROMPT [STEP 5] Creating manager_admin.GradeUpdaters table and inserting USER1...

CREATE TABLE manager_admin.GradeUpdaters (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username VARCHAR2(50) NOT NULL,
    created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- Allow USER1 to read this table so triggers owned by USER1 can consult it
GRANT SELECT ON manager_admin.GradeUpdaters TO user1;

-- Insert USER1 as an authorized grade updater (so schema-owner professors or user1 can be granted later)
BEGIN
    INSERT INTO manager_admin.GradeUpdaters (username) VALUES ('USER1');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN NULL;
END;
/
COMMIT;

PROMPT [DONE] GradeUpdaters table created and USER1 added

-- Also ensure MANAGER_ADMIN is present so admin tests and procedures can use it
BEGIN
    INSERT INTO manager_admin.GradeUpdaters (username) VALUES ('MANAGER_ADMIN');
EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN NULL;
END;
/
COMMIT;

-- ==========================================================================
-- Helper: Authorization wrapper function
-- Manager-side function so USER1 need only EXECUTE privilege (no direct table SELECT)
-- ==========================================================================
PROMPT
PROMPT [STEP 6] Creating manager_admin.is_grade_updater helper function...

CREATE OR REPLACE FUNCTION manager_admin.is_grade_updater(p_username IN VARCHAR2) RETURN NUMBER IS
    v_cnt NUMBER := 0;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM manager_admin.GradeUpdaters gu WHERE gu.username = UPPER(p_username);
    RETURN v_cnt;
EXCEPTION
    WHEN OTHERS THEN
        -- If anything goes wrong, return 0 (not authorized)
        RETURN 0;
END;
/

-- Allow USER1 to call the helper without needing direct SELECT on GradeUpdaters
GRANT EXECUTE ON manager_admin.is_grade_updater TO user1;
COMMIT;

PROMPT [DONE] Helper function created and EXECUTE granted to USER1

PROMPT
PROMPT ============================================================
PROMPT VERIFICATION TESTS
PROMPT ============================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Test 1: DBUserCreationLog exists
    SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'DBUSERCREATIONLOG';
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] DBUserCreationLog table exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] DBUserCreationLog table NOT found');
    END IF;
    
    -- Test 2: User1 exists
    SELECT COUNT(*) INTO v_count FROM all_users WHERE username = 'USER1';
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] USER1 exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] USER1 NOT found');
    END IF;
    
    -- Test 3: User2 exists
    SELECT COUNT(*) INTO v_count FROM all_users WHERE username = 'USER2';
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] USER2 exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] USER2 NOT found');
    END IF;
    
    -- Test 4: Users logged in DBUserCreationLog
    SELECT COUNT(*) INTO v_count FROM manager_admin.DBUserCreationLog;
    IF v_count >= 2 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] ' || v_count || ' users logged in DBUserCreationLog');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] Users not logged properly');
    END IF;
END;
/

-- Show log contents
PROMPT
PROMPT DBUserCreationLog contents:
SELECT log_id, username, created_by, TO_CHAR(creation_date, 'YYYY-MM-DD HH24:MI:SS') AS created_at 
FROM manager_admin.DBUserCreationLog;

PROMPT
PROMPT ============================================================
PROMPT FEATURE 1 COMPLETE: User Management
PROMPT   - MANAGER_ADMIN created by SYS
PROMPT   - USER1 created by MANAGER_ADMIN (for tables)
PROMPT   - USER2 created by MANAGER_ADMIN (for data)
PROMPT   - All creations logged in DBUserCreationLog
PROMPT ============================================================
PROMPT
PROMPT NEXT STEP: Connect as USER1 and run file 03
PROMPT   Username: user1
PROMPT   Password: user1pass
PROMPT ============================================================
