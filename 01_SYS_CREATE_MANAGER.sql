-- ============================================================================
-- FILE: 01_SYS_CREATE_MANAGER.sql
-- RUN AS: SYS AS SYSDBA
-- PURPOSE: Create the Manager-Admin user with full privileges
-- ============================================================================
-- FEATURE 1 (Part A): User Management - SYS creates Manager
-- The Manager-Admin will have SYSDBA-like privileges to:
--   1. Create users (User1, User2)
--   2. Create tables, triggers, procedures, functions
--   3. Grant privileges
-- ============================================================================
























SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT ============================================================
PROMPT FILE 1: CREATING MANAGER-ADMIN USER
PROMPT Run as: SYS AS SYSDBA
PROMPT ============================================================





















-- ============================================================================
-- CLEANUP: Drop existing users if re-running (COMPLETE VERSION)
-- ============================================================================


















PROMPT
PROMPT [CLEANUP] Dropping existing users and killing sessions...

DECLARE
    v_cleanup_errors VARCHAR2(4000);
BEGIN
    -- Drop all objects owned by users first (prevents cascade issues)
    FOR u IN (SELECT username FROM dba_users WHERE username IN ('MANAGER_ADMIN', 'USER1', 'USER2')) LOOP
        BEGIN
            -- Step 1: Kill all active sessions for this user
            FOR s IN (SELECT sid, serial# FROM v$session WHERE username = u.username) LOOP
                BEGIN
                    EXECUTE IMMEDIATE 'ALTER SYSTEM KILL SESSION ''' || s.sid || ',' || s.serial# || ''' IMMEDIATE';
                    DBMS_OUTPUT.PUT_LINE('  Killed session: ' || s.sid || ',' || s.serial# || ' for ' || u.username);
                EXCEPTION 
                    WHEN OTHERS THEN 
                        DBMS_OUTPUT.PUT_LINE('  Could not kill session ' || s.sid || ': ' || SQLERRM);
                END;
            END LOOP;






            -- Step 2: Wait a moment for sessions to terminate
            BEGIN
                DBMS_LOCK.SLEEP(2);
            EXCEPTION WHEN OTHERS THEN NULL; END;
            
            -- Step 3: Drop the user with CASCADE
            EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
            DBMS_OUTPUT.PUT_LINE('[SUCCESS] Dropped user: ' || u.username);
            
        EXCEPTION
            WHEN OTHERS THEN
                -- Log but continue with other users
                v_cleanup_errors := v_cleanup_errors || u.username || ': ' || SQLERRM || CHR(10);
                DBMS_OUTPUT.PUT_LINE('[WARNING] Could not drop ' || u.username || ': ' || SQLERRM);
        END;
    END LOOP;
    






































    -- Report any cleanup errors
    IF v_cleanup_errors IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('[INFO] Some cleanup operations had issues:');
        DBMS_OUTPUT.PUT_LINE(v_cleanup_errors);
        DBMS_OUTPUT.PUT_LINE('[INFO] If users still exist, manually disconnect all sessions and re-run.');
    END IF;
END;
/

















































-- Additional wait to ensure cleanup completes
BEGIN
    BEGIN DBMS_LOCK.SLEEP(1); EXCEPTION WHEN OTHERS THEN NULL; END;
END;
/

PROMPT [CLEANUP] Cleanup phase complete
PROMPT

-- ============================================================================
-- CREATE MANAGER_ADMIN USER
-- ============================================================================
CREATE USER manager_admin IDENTIFIED BY manager123
    DEFAULT TABLESPACE users
    QUOTA UNLIMITED ON users;

-- Grant DBA role for full administrative privileges
GRANT DBA TO manager_admin;
GRANT CREATE SESSION TO manager_admin;
GRANT CREATE USER TO manager_admin;
GRANT DROP USER TO manager_admin;
GRANT GRANT ANY PRIVILEGE TO manager_admin;
GRANT CREATE ANY TABLE TO manager_admin;
GRANT CREATE ANY TRIGGER TO manager_admin;
GRANT CREATE ANY PROCEDURE TO manager_admin;
GRANT ALTER ANY TABLE TO manager_admin;
GRANT INSERT ANY TABLE TO manager_admin;
GRANT UPDATE ANY TABLE TO manager_admin;
GRANT DELETE ANY TABLE TO manager_admin;
GRANT SELECT ANY TABLE TO manager_admin;
GRANT UNLIMITED TABLESPACE TO manager_admin;

-- Grant access to v$ views for blocker-waiting queries
GRANT SELECT ON v_$session TO manager_admin;
GRANT SELECT ON v_$lock TO manager_admin;
GRANT SELECT ON v_$locked_object TO manager_admin;

PROMPT
PROMPT ============================================================
PROMPT MANAGER_ADMIN user created successfully!
PROMPT Password: manager123
PROMPT ============================================================

-- ============================================================================
-- VERIFICATION TEST
-- ============================================================================
























PROMPT
PROMPT [TEST] Verifying user creation...

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM dba_users WHERE username = 'MANAGER_ADMIN';
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] MANAGER_ADMIN user exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] MANAGER_ADMIN user NOT found');
    END IF;
    
    SELECT COUNT(*) INTO v_count FROM dba_role_privs WHERE grantee = 'MANAGER_ADMIN' AND granted_role = 'DBA';
    IF v_count = 1 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] DBA role granted to MANAGER_ADMIN');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] DBA role NOT granted');
    END IF;
END;
/

PROMPT
PROMPT ============================================================
PROMPT NEXT STEP: Connect as MANAGER_ADMIN and run file 02
PROMPT   Username: manager_admin
PROMPT   Password: manager123
PROMPT ============================================================






























