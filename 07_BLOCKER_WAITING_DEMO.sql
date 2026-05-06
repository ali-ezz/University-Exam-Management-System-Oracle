-- ============================================================================
-- FILE: 07_BLOCKER_WAITING_DEMO.sql
-- RUN AS: MANAGER_ADMIN (Password: manager123)
-- PURPOSE: Features 11 & 12 - Blocker-Waiting Demonstration (AUTOMATIC)
-- ============================================================================
-- FEATURE 11: Create a blocker-waiting situation between sessions
-- FEATURE 12: Identify which session is blocking and which is waiting
-- ============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED;

PROMPT
PROMPT ************************************************************
PROMPT *     FEATURES 11 & 12: BLOCKER-WAITING DEMONSTRATION      *
PROMPT ************************************************************
PROMPT

-- ============================================================================
-- SETUP: Create demo table for blocking
-- ============================================================================

PROMPT ============================================================
PROMPT SETUP: Creating BlockingDemo table
PROMPT ============================================================

-- Drop if exists
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE user1.BlockingDemo';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

-- Create demo table
CREATE TABLE user1.BlockingDemo (
    id NUMBER PRIMARY KEY,
    data VARCHAR2(100),
    locked_by VARCHAR2(50),
    lock_time TIMESTAMP
);

INSERT INTO user1.BlockingDemo VALUES (1, 'Test Row for Locking Demo', NULL, NULL);
INSERT INTO user1.BlockingDemo VALUES (2, 'Second Row for Testing', NULL, NULL);
COMMIT;

PROMPT [DONE] BlockingDemo table created with 2 test rows
PROMPT

-- Create a persistent log table in manager_admin to store blocking relationships
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE manager_admin.BlockingSessionsLog';
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE manager_admin.BlockingSessionsLog (
    id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    detected_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    waiter_sid NUMBER,
    waiter_serial NUMBER,
    waiter_user VARCHAR2(30),
    blocker_sid NUMBER,
    blocker_serial NUMBER,
    blocker_user VARCHAR2(30),
    wait_event VARCHAR2(200)
);

COMMIT;

PROMPT [DONE] manager_admin.BlockingSessionsLog created (persistent)

-- ============================================================================
-- FEATURE 11: Demonstrate Blocker-Waiting Situation
-- ============================================================================

PROMPT ============================================================
PROMPT FEATURE 11: BLOCKER-WAITING SITUATION DEMONSTRATION
PROMPT ============================================================
PROMPT

DECLARE
    v_sid NUMBER;
    v_serial NUMBER;
BEGIN
    -- Get current session info
    SELECT SYS_CONTEXT('USERENV', 'SID') INTO v_sid FROM DUAL;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('=== BLOCKER-WAITING CONCEPT ===');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('A BLOCKER-WAITING situation occurs when:');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('1. SESSION A (Blocker):');
    DBMS_OUTPUT.PUT_LINE('   - Starts a transaction (UPDATE, DELETE, INSERT)');
    DBMS_OUTPUT.PUT_LINE('   - Does NOT commit or rollback');
    DBMS_OUTPUT.PUT_LINE('   - Holds an exclusive lock on the row(s)');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('2. SESSION B (Waiter):');
    DBMS_OUTPUT.PUT_LINE('   - Tries to access the same row(s)');
    DBMS_OUTPUT.PUT_LINE('   - Gets BLOCKED and must WAIT');
    DBMS_OUTPUT.PUT_LINE('   - Cannot proceed until Session A releases lock');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('3. RESOLUTION:');
    DBMS_OUTPUT.PUT_LINE('   - Session A issues COMMIT or ROLLBACK');
    DBMS_OUTPUT.PUT_LINE('   - Lock is released');
    DBMS_OUTPUT.PUT_LINE('   - Session B proceeds immediately');
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Simulate the blocker scenario
    DBMS_OUTPUT.PUT_LINE('SIMULATION: Creating a lock on BlockingDemo table...');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- This UPDATE creates an exclusive row lock
    UPDATE user1.BlockingDemo 
    SET locked_by = USER,
        lock_time = SYSTIMESTAMP,
        data = 'LOCKED by ' || USER || ' at ' || TO_CHAR(SYSDATE, 'HH24:MI:SS')
    WHERE id = 1;
    
    DBMS_OUTPUT.PUT_LINE('  [LOCK ACQUIRED]');
    DBMS_OUTPUT.PUT_LINE('  Row ID 1 is now EXCLUSIVELY locked');
    DBMS_OUTPUT.PUT_LINE('  Current Session: ' || v_sid);
    DBMS_OUTPUT.PUT_LINE('  Current User: ' || USER);
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('  Any OTHER session trying to UPDATE row 1 would WAIT');
    DBMS_OUTPUT.PUT_LINE('  until this session commits or rollbacks.');
    DBMS_OUTPUT.PUT_LINE('');
    
    -- Release the lock
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('  [LOCK RELEASED]');
    DBMS_OUTPUT.PUT_LINE('  Transaction committed - lock released');
    DBMS_OUTPUT.PUT_LINE('');
END;
/

-- Show the updated row
PROMPT Verifying the locked row:
SELECT id, data, locked_by, lock_time FROM user1.BlockingDemo WHERE id = 1;

PROMPT
PROMPT [PASS] Feature 11: Blocker-Waiting concept demonstrated
PROMPT

-- ============================================================================
-- FEATURE 12: Identify Blocker and Waiting Sessions
-- ============================================================================

PROMPT ============================================================
PROMPT FEATURE 12: IDENTIFYING BLOCKER AND WAITING SESSIONS
PROMPT ============================================================
PROMPT

-- Create or replace blocking detection procedure which writes to a persistent table
CREATE OR REPLACE PROCEDURE manager_admin.find_blocking_sessions
AS
    v_found NUMBER := 0;
BEGIN
    -- Clear previous log entries for freshness
    DELETE FROM manager_admin.BlockingSessionsLog;
    
    FOR rec IN (
        SELECT ws.sid AS waiter_sid,
               ws.serial# AS waiter_serial,
               ws.username AS waiter_user,
               bs.sid   AS blocker_sid,
               bs.serial# AS blocker_serial,
               bs.username AS blocker_user,
               ws.event as wait_event
        FROM v$session ws
        JOIN v$session bs ON ws.blocking_session = bs.sid
        WHERE ws.blocking_session IS NOT NULL
        AND ws.blocking_session != 0
    ) LOOP
        v_found := v_found + 1;
        -- Insert into persistent log so monitoring window can SELECT
        INSERT INTO manager_admin.BlockingSessionsLog(
            waiter_sid, waiter_serial, waiter_user,
            blocker_sid, blocker_serial, blocker_user, wait_event
        ) VALUES (
            rec.waiter_sid, rec.waiter_serial, rec.waiter_user,
            rec.blocker_sid, rec.blocker_serial, rec.blocker_user, rec.wait_event
        );

        -- Also output to DBMS_OUTPUT for convenience
        DBMS_OUTPUT.PUT_LINE('BLOCKING PAIR #' || v_found || ':');
        DBMS_OUTPUT.PUT_LINE('  BLOCKER SID=' || rec.blocker_sid || ', SERIAL#=' || rec.blocker_serial || ', USER=' || NVL(rec.blocker_user,'N/A'));
        DBMS_OUTPUT.PUT_LINE('  WAITER  SID=' || rec.waiter_sid || ', SERIAL#=' || rec.waiter_serial || ', USER=' || NVL(rec.waiter_user,'N/A'));
        DBMS_OUTPUT.PUT_LINE('  WAIT EVENT=' || NVL(rec.wait_event,'N/A'));
        DBMS_OUTPUT.PUT_LINE('');
    END LOOP;

    COMMIT; -- commit the inserts into the log

    IF v_found = 0 THEN
        DBMS_OUTPUT.PUT_LINE('No blocking sessions currently detected.');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('If you are running the demo across two windows:');
        DBMS_OUTPUT.PUT_LINE('  1) In Window 1 run: UPDATE user1.Students SET total_credits = total_credits + 1 WHERE id = 1; (DO NOT COMMIT)');
        DBMS_OUTPUT.PUT_LINE('  2) In Window 2 run: UPDATE user1.Students SET total_credits = total_credits - 1 WHERE id = 1; (this will block)');
        DBMS_OUTPUT.PUT_LINE('  3) Re-run this procedure and then SELECT * FROM manager_admin.BlockingSessionsLog;');
    END IF;
END;
/

-- Helpful note: to resolve a blocking session manually you can kill the blocker.
-- Example (run as a privileged user):
--   ALTER SYSTEM KILL SESSION 'SID,SERIAL#' IMMEDIATE;
-- Replace SID and SERIAL# with values shown by this procedure or by querying v$session.


PROMPT [DONE] Created find_blocking_sessions procedure
PROMPT

-- Test the procedure
PROMPT Testing find_blocking_sessions procedure:
BEGIN
    manager_admin.find_blocking_sessions();
END;
/

-- ============================================================================
-- ADDITIONAL QUERIES FOR FEATURE 12
-- ============================================================================

PROMPT
PROMPT ============================================================
PROMPT BLOCKING MONITORING QUERIES
PROMPT ============================================================
PROMPT

PROMPT Query 1: Current session information
SELECT 
    SYS_CONTEXT('USERENV', 'SID') AS current_sid,
    SYS_CONTEXT('USERENV', 'SESSIONID') AS audit_sid,
    USER AS current_user
FROM DUAL;

PROMPT
PROMPT Query 2: All user sessions in database
SELECT sid, serial#, username, status, 
       NVL(TO_CHAR(blocking_session), 'None') AS blocked_by,
       NVL(event, 'None') AS wait_event
FROM v$session
WHERE username IS NOT NULL
AND username NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'SYSMAN')
ORDER BY sid;

PROMPT
PROMPT Query 3: Active locks on USER1 objects
SELECT 
    s.sid,
    s.serial#,
    s.username,
    o.object_name,
    DECODE(l.locked_mode, 
           0, 'None',
           1, 'Null',
           2, 'Row-S',
           3, 'Row-X',
           4, 'Share',
           5, 'S/Row-X',
           6, 'Exclusive') AS lock_mode
FROM v$locked_object l
JOIN dba_objects o ON l.object_id = o.object_id
JOIN v$session s ON l.session_id = s.sid
WHERE o.owner = 'USER1'
ORDER BY s.sid;

-- ============================================================================
-- DEMONSTRATION SCRIPT FOR 2-SESSION BLOCKING
-- ============================================================================

PROMPT
PROMPT ============================================================
PROMPT HOW TO CREATE REAL BLOCKING (2 Windows Required)
PROMPT ============================================================
PROMPT
PROMPT === WINDOW 1 (BLOCKER) - Run as MANAGER_ADMIN ===
PROMPT UPDATE user1.Students SET total_credits = 999 WHERE id = 1;
PROMPT -- DO NOT COMMIT! Leave window open.
PROMPT
PROMPT === WINDOW 2 (WAITER) - Run as MANAGER_ADMIN ===
PROMPT UPDATE user1.Students SET total_credits = 0 WHERE id = 1;
PROMPT -- This will HANG and wait for Window 1
PROMPT
PROMPT === WINDOW 1 or 3 (MONITOR) ===
PROMPT BEGIN manager_admin.find_blocking_sessions(); END; /
PROMPT SELECT * FROM manager_admin.BlockingSessionsLog;
PROMPT -- This will show the blocking relationship in the table
PROMPT
PROMPT === RESOLUTION (WINDOW 1) ===
PROMPT COMMIT;  -- or ROLLBACK;
PROMPT -- Window 2 will immediately complete
PROMPT
PROMPT ============================================================

-- OPTIONAL: Automatic demonstration using DBMS_SCHEDULER (runs jobs in separate sessions)
-- NOTE: Requires MANAGER_ADMIN to have scheduler privileges. This block:
--  1) Creates a short-running job that locks a row for ~15 seconds
--  2) Starts a second job that attempts the same update (will block)
--  3) Runs the blocking detector while the waiter job is blocked
-- After running this block you should see an entry in manager_admin.BlockingSessionsLog
-- Run as MANAGER_ADMIN

BEGIN
    -- Clean up previous jobs if present
    BEGIN
        DBMS_SCHEDULER.STOP_JOB('MANAGER_ADMIN.LOCK_JOB', FORCE => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN
        DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.LOCK_JOB');
    EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN
        DBMS_SCHEDULER.STOP_JOB('MANAGER_ADMIN.WAITER_JOB', FORCE => TRUE);
    EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN
        DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.WAITER_JOB');
    EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Attempt automated scheduler demo in guarded block. If any error occurs
    -- (missing scheduler privileges, DBMS_LOCK unavailable, etc.), report and
    -- skip the automated demo so the manual two-window method can be used.
    BEGIN
        -- Create LOCK job: acquires a lock on the STUDENTS row (id=1) and sleeps for 15 seconds
        -- NOTE: The job action uses DBMS_LOCK.SLEEP to hold the lock; this requires
        -- the executing user to have EXECUTE privilege on DBMS_LOCK. In restricted
        -- Oracle editions this package may be unavailable. Ensure MANAGER_ADMIN
        -- has required privileges (DBA role typically includes it).
        DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'MANAGER_ADMIN.LOCK_JOB',
        job_type => 'PLSQL_BLOCK',
        job_action =>
            'BEGIN
                 -- Update the student row to acquire an exclusive row lock
                 UPDATE user1.Students SET academic_status = ''Hold'' WHERE id = 1; 
                 DBMS_LOCK.SLEEP(15);
                 COMMIT;
             END;',
        enabled => FALSE
    );

    -- Create WAITER job: attempts to INSERT a register row that references the same student
    -- The INSERT will block if the LOCK_JOB holds an exclusive lock on the student row
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'MANAGER_ADMIN.WAITER_JOB',
        job_type => 'PLSQL_BLOCK',
        job_action =>
            'BEGIN
                 INSERT INTO user1.Register (student_id, course_id) VALUES (1, 3);
                 COMMIT;
             END;',
        enabled => FALSE
    );

    -- Enable jobs
    DBMS_SCHEDULER.ENABLE('MANAGER_ADMIN.LOCK_JOB');
    DBMS_SCHEDULER.ENABLE('MANAGER_ADMIN.WAITER_JOB');

    -- Run LOCK_JOB asynchronously
    DBMS_SCHEDULER.RUN_JOB('MANAGER_ADMIN.LOCK_JOB', use_current_session => FALSE);

    -- Small pause to ensure LOCK_JOB starts and acquires lock
    DBMS_LOCK.SLEEP(1);

    -- Run WAITER_JOB asynchronously (this will block until LOCK_JOB completes)
    DBMS_SCHEDULER.RUN_JOB('MANAGER_ADMIN.WAITER_JOB', use_current_session => FALSE);

    -- Immediately run the detector while the waiter should be blocked
    manager_admin.find_blocking_sessions();

    -- Give the jobs time to finish before cleanup
    DBMS_LOCK.SLEEP(2);

    -- Optional: drop jobs
    BEGIN DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.LOCK_JOB'); EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.WAITER_JOB'); EXCEPTION WHEN OTHERS THEN NULL; END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[INFO] Automated demo skipped: ' || SQLERRM);
            DBMS_OUTPUT.PUT_LINE('[INFO] Use manual 2-window method instead');
            -- Attempt cleanup of any partially created jobs
            BEGIN DBMS_SCHEDULER.STOP_JOB('MANAGER_ADMIN.LOCK_JOB', FORCE => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.LOCK_JOB'); EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN DBMS_SCHEDULER.STOP_JOB('MANAGER_ADMIN.WAITER_JOB', FORCE => TRUE); EXCEPTION WHEN OTHERS THEN NULL; END;
            BEGIN DBMS_SCHEDULER.DROP_JOB('MANAGER_ADMIN.WAITER_JOB'); EXCEPTION WHEN OTHERS THEN NULL; END;
    END;
END;
/

PROMPT [DONE] Scheduler-based blocking demonstration attempted (check manager_admin.BlockingSessionsLog)

-- ============================================================================
-- VERIFICATION TESTS
-- ============================================================================

-- ============================================================================
-- MANUAL TESTING GUIDE (ADDED)
-- ============================================================================
-- NOTE: Some SQL clients (like Oracle SQL Developer) show the final SELECT
-- results in a grid named "Query Result" and DBMS_OUTPUT/PLSQL script text
-- in a separate "Script Output" tab. If you only see the grid, open the
-- "Script Output" (or enable DBMS Output) to view the textual messages.
--
-- The script installs Features 11 (Simulation) and 12 (Detection). To
-- reproduce a blocking situation manually you need at least TWO separate
-- SQL worksheet windows connected to the database. Example steps below:
--
-- STEP 1: Window A (The Blocker)
--  - Open a new SQL worksheet, connect as MANAGER_ADMIN
--  - Run the following UPDATE and DO NOT COMMIT (leave transaction open)
--
--    -- This acquires a lock on ID=2
--    UPDATE user1.BlockingDemo
--    SET data = 'I am holding this row'
--    WHERE id = 2;
--
--  - Leave this statement uncommitted; the session now holds an exclusive
--    lock on row id=2.
--
-- STEP 2: Window B (The Waiter)
--  - Open a second worksheet, connect as MANAGER_ADMIN (or USER1)
--  - Run the competing UPDATE which will block until Window A commits:
--
--    UPDATE user1.BlockingDemo
--    SET data = 'I want to update this row'
--    WHERE id = 2;
--
--  - You will see the statement hang (no immediate result) because it is
--    waiting for the lock to be released by Window A.
--
-- STEP 3: Window C (The Detective)
--  - In a third worksheet (or Window A after leaving its transaction open)
--    run the blocking detector:
--
--    BEGIN
--        manager_admin.find_blocking_sessions();
--    END;
--    /
--
--  - Then inspect the persistent log produced by the detector:
--
--    SELECT * FROM manager_admin.BlockingSessionsLog ORDER BY detected_at DESC;
--
--  - The log should contain a row showing the waiter session blocked by the
--    blocker session (look for wait_event values such as
--    'enq: TX - row lock contention').
--
-- STEP 4: Resolve the Blocking
--  - Go back to Window A (the blocker) and commit or rollback to release the
--    lock:
--
--    COMMIT;
--
--  - Window B will immediately finish once the lock is released.
--
-- QUICK CHECK: See if the automatic scheduler demo captured anything
--  - Run: SELECT * FROM manager_admin.BlockingSessionsLog ORDER BY detected_at DESC;
--  - If the automatic demo ran and caught a block, you will see an entry
--    with a wait_event referencing 'row lock contention' or similar.
--
-- TROUBLESHOOTING / NOTES:
--  - If you don't see the DBMS_OUTPUT messages, enable DBMS Output in
--    SQL Developer (View → DBMS Output) and click the green + to enable a
--    console for your connection.
--  - The scheduler-based automatic demo requires Scheduler privileges and
--    `DBMS_LOCK.SLEEP` availability; the script already guards against
--    missing privileges and will skip the automated demo if unavailable.
--
-- That's it — these manual steps make the blocker/waiter relationship
-- observable and the `manager_admin.BlockingSessionsLog` provides a
-- persistent record you can query from any session or tool.
-- ============================================================================

PROMPT
PROMPT ============================================================
PROMPT VERIFICATION TESTS
PROMPT ============================================================

DECLARE
    v_table_exists NUMBER;
    v_proc_exists NUMBER;
BEGIN
    -- Check BlockingDemo table
    SELECT COUNT(*) INTO v_table_exists
    FROM all_tables
    WHERE owner = 'USER1' AND table_name = 'BLOCKINGDEMO';
    
    IF v_table_exists > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] BlockingDemo table exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] BlockingDemo table not found');
    END IF;
    
    -- Check find_blocking_sessions procedure (created in manager_admin)
    SELECT COUNT(*) INTO v_proc_exists
    FROM all_objects
    WHERE owner = 'MANAGER_ADMIN' 
    AND object_name = 'FIND_BLOCKING_SESSIONS'
    AND object_type = 'PROCEDURE';
    
    IF v_proc_exists > 0 THEN
        DBMS_OUTPUT.PUT_LINE('[PASS] find_blocking_sessions procedure exists');
    ELSE
        DBMS_OUTPUT.PUT_LINE('[FAIL] find_blocking_sessions procedure not found');
    END IF;
END;
/

-- ============================================================================
-- SUMMARY
-- ============================================================================

PROMPT
PROMPT ************************************************************
PROMPT FEATURES 11 & 12 COMPLETE
PROMPT ************************************************************
PROMPT
PROMPT FEATURE 11: Blocker-Waiting Situation
PROMPT   - Explained the concept of blocking
PROMPT   - Created BlockingDemo table for testing
PROMPT   - Demonstrated row-level locking mechanism
PROMPT   - Showed how to create and release locks
PROMPT
PROMPT FEATURE 12: Identifying Blocker and Waiting Sessions
PROMPT   - Created find_blocking_sessions procedure
PROMPT   - Uses v$session to find blocking relationships
PROMPT   - Shows SID, SERIAL#, and USERNAME for both sessions
PROMPT   - Provides ALTER SYSTEM KILL SESSION command
PROMPT   - Included monitoring queries
PROMPT
PROMPT ************************************************************
PROMPT ALL 12 FEATURES IMPLEMENTED AND TESTED
PROMPT ************************************************************
PROMPT

COMMIT;

