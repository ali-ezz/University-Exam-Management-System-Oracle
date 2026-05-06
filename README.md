# University Exam Management System – Oracle PL/SQL Architecture & Implementation

## Full Documentation

---

## 1. PROJECT IDENTIFICATION & OVERVIEW

This project implements a comprehensive **University Exam Management System** using **Oracle PL/SQL**. It follows a multi‑user architecture with strict separation of duties, robust business logic, and a full suite of database objects (tables, triggers, functions, procedures). The system is deployed through a sequence of SQL scripts executed by different administrative roles.

**Core features:**

- User management with audit logging
- Prerequisite validation before course registration
- Automatic grade calculation and pass/fail status assignment
- Academic warning system for failing students
- Full audit trail for critical operations
- Course performance reporting
- Exam schedule management
- Transaction‑safe batch grade updates
- Student suspension based on accumulated warnings
- GPA calculation and grade authorisation
- Concurrency management with blocker‑waiter detection

---

## 2. EXECUTION CONTEXT & USER HIERARCHY

The system is deployed by executing SQL files in a strict order, with each file running under a specific Oracle user. This enforces the principle of least privilege.

| User              | Role                        | Password            | Responsibilities                                        |
| ----------------- | --------------------------- | ------------------- | ------------------------------------------------------- |
| **SYS**           | Root Administrator (SYSDBA) | (OS authentication) | Creates MANAGER_ADMIN; grants DBA privileges            |
| **MANAGER_ADMIN** | System Manager              | manager123          | Creates sub‑users; deploys PL/SQL logic; monitors logs  |
| **USER1**         | Schema Owner                | user1pass           | Owns all tables; defines structural constraints         |
| **USER2**         | Data Operator               | user2pass           | Performs data entry (Inserts Students, Courses, Grades) |

---

## 3. EXECUTION ORDER (SCRIPTS)

To deploy the system, the SQL files must be executed in the following order:

| Step | File Name                       | Run As        | Description                                                               |
| ---- | ------------------------------- | ------------- | ------------------------------------------------------------------------- |
| 1    | `01_SYS_CREATE_MANAGER.sql`     | SYS           | Cleans up old users; creates MANAGER_ADMIN; grants DBA roles.             |
| 2    | `02_MANAGER_CREATE_USERS.sql`   | MANAGER_ADMIN | Creates USER1 & USER2; creates logging table; logs user creation.         |
| 3    | `03_USER1_CREATE_TABLES.sql`    | USER1         | Creates all 8 tables; sets up PK/FK constraints; grants table privileges. |
| 4    | `04_USER2_INSERT_DATA.sql`      | USER2         | Inserts Professors, Courses, Students, Exams, and initial Results.        |
| 5    | `05_MANAGER_PLSQL_FEATURES.sql` | MANAGER_ADMIN | Deploys Triggers, Functions, and Procedures (Features 2‑10).              |
| 6    | `06_TESTING_ALL_FEATURES.sql`   | MANAGER_ADMIN | Runs test cases for all features to verify functionality.                 |
| 7    | `07_BLOCKER_WAITING_DEMO.sql`   | MANAGER_ADMIN | Demonstrates row‑locking and session killing (Features 11‑12).            |

---

## 4. DATABASE SCHEMA (ENTITY RELATIONSHIP DIAGRAM)

The following entities and relationships define the system:

- **PROFESSORS** (id, name, department)
- **COURSES** (id, name, professor_id FK, credit_hours, prerequisite_course_id self‑FK)
- **STUDENTS** (id, name, academic_status, total_credits)
- **REGISTER** (id, student_id FK, course_id FK, UNIQUE constraint)
- **EXAMS** (id, course_id FK, exam_date, exam_type)
- **EXAM_RESULTS** (id, registration_id FK, score, grade, status)
- **WARNINGS** (id, student_id FK, warning_reason, warning_date)
- **AUDIT_TRAIL** (id, table_name, operation, old_data, new_data, timestamp)

**Supporting tables (Manager schema):**

- **DB_USER_CREATION_LOG** – logs every user creation
- **GRADE_UPDATERS** – whitelist of users authorised to update grades

**Relationships:**

- PROFESSORS 1:N COURSES
- COURSES 1:N REGISTER (via course_id)
- STUDENTS 1:N REGISTER, 1:N WARNINGS
- REGISTER 1:N EXAM_RESULTS
- COURSES 1:N EXAMS

---

## 5. DETAILED FEATURE IMPLEMENTATIONS

### 5.1 Feature 1: User Management & Logging

- **Type:** DDL & Procedure
- **Implementation:** MANAGER_ADMIN creates users. A procedure `log_user_creation` inserts a record into `DBUserCreationLog` whenever a user is created.
- **Audit Table:** `manager_admin.DBUserCreationLog` (log_id, username, created_by, creation_date)

### 5.2 Feature 2: Prerequisite Validation

- **Type:** Trigger (`trg_check_prerequisite`)
- **Fires:** BEFORE INSERT on `REGISTER`
- **Logic:** Checks if the course has a prerequisite. If yes, verifies that the student has passed the prerequisite by querying `EXAM_RESULTS`.
- **Error:** Raises `ORA-20001` if prerequisites not met.

### 5.3 Feature 3: Grade Calculation

- **Type:** Function (`calculate_grade`)
- **Input:** `exam_result_id`, optional numeric score override.
- **Logic:** Determines letter grade (A, B, C, D, F) and pass/fail status based on score ranges (90+, 80‑89, 70‑79, 60‑69, <60). Updates the `EXAM_RESULTS` record.
- **Returns:** The calculated grade letter.

### 5.4 Feature 4: Automated Warnings

- **Type:** Procedure (`issue_warnings_for_failures`)
- **Logic:** Uses a cursor to find students with 2+ 'Fail' statuses in `EXAM_RESULTS`. Inserts a warning record for each, avoiding duplicates within 30 days.
- **Table:** `WARNINGS`

### 5.5 Feature 5: Registration Audit Trail

- **Type:** Triggers (`trg_audit_register_insert`, `trg_audit_register_delete`)
- **Logic:** Captures any INSERT or DELETE on `REGISTER`. Logs operation type, old/new data, and timestamp into `AUDIT_TRAIL`.

### 5.6 Feature 6: Performance Report

- **Type:** Procedure (`course_performance_report`)
- **Input:** `course_id`
- **Logic:** Joins `REGISTER` and `EXAM_RESULTS` to display a formatted report of all students in that course, their grades, and overall pass/fail percentage.

### 5.7 Feature 7: Exam Schedule

- **Type:** Procedure (`display_exam_schedule`)
- **Input:** Optional `course_id` (NULL = all courses)
- **Logic:** Queries `EXAMS` and `COURSES`, displays course name, exam date, and type. Handles the case where no exams are scheduled.

### 5.8 Feature 8: Batch Grade Update (Transaction Control)

- **Type:** Procedure (`update_multiple_grades`)
- **Input:** Comma‑separated list of registration IDs and a new grade letter.
- **Logic:** Processes each ID; updates grade and status. If *any* update fails (e.g., ID not found), performs a ROLLBACK to undo all changes. On full success, COMMITs.

### 5.9 Feature 9: Student Suspension

- **Type:** Procedure (`suspend_students_with_warnings`)
- **Logic:** Identifies students with 3 or more warnings. Updates their `academic_status` to 'Suspended' and logs the change in `AUDIT_TRAIL`.

### 5.10 Feature 10A: GPA Calculation

- **Type:** Function (`calculate_gpa`)
- **Input:** `student_id`
- **Logic:** Calculates weighted GPA (Σ(Grade Points × Credit Hours) / Σ(Credit Hours)). Grade points: A=4.0, B=3.0, C=2.0, D=1.0, F=0.0. Returns GPA rounded to 2 decimals.

### 5.11 Feature 10B: Grade Authorisation Trigger

- **Type:** Trigger (`trg_grade_authorization`)
- **Fires:** BEFORE UPDATE OF grade ON `EXAM_RESULTS`
- **Logic:** Checks the `manager_admin.is_grade_updater` function against the current user. If not authorised, raises `ORA-20002`.

### 5.12 Feature 11: Blocker‑Waiting Situation Demonstration

- **Type:** Demonstration (using `BlockingDemo` table)
- **Logic:** Session 1 updates a row without committing; Session 2 attempts to update the same row and hangs. This illustrates exclusive row locking.

### 5.13 Feature 12: Session Management (Blocker Detection)

- **Type:** Procedure (`find_blocking_sessions`)
- **Logic:** Queries `v$session`, `v$lock`, and `dba_blockers` to identify blocker and waiter sessions. Logs results to `BlockingSessionsLog` and provides the command to kill the blocking session (`ALTER SYSTEM KILL SESSION ...`).

---

## 6. TABLE STRUCTURES (SCHEMA)

All tables are owned by **USER1** unless otherwise noted.

| Table          | Key Columns                                                  | Purpose                                 |
| -------------- | ------------------------------------------------------------ | --------------------------------------- |
| `PROFESSORS`   | id, name, department                                         | Faculty information                     |
| `COURSES`      | id, name, professor_id, credit_hours, prerequisite_course_id | Course catalog with prerequisite chains |
| `STUDENTS`     | id, name, academic_status, total_credits                     | Student master data                     |
| `REGISTER`     | id, student_id, course_id, UNIQUE(student_id, course_id)     | Course enrollment                       |
| `EXAMS`        | id, course_id, exam_date, exam_type                          | Exam scheduling                         |
| `EXAM_RESULTS` | id, registration_id, score, grade, status                    | Student exam performance                |
| `AUDIT_TRAIL`  | id, table_name, operation, old_data, new_data, timestamp     | Change tracking                         |
| `WARNINGS`     | id, student_id, warning_reason, warning_date                 | Academic warnings                       |
| `BlockingDemo` | id, data, locked_by, lock_time                               | Table used for lock demonstrations      |

**Manager Schema Tables:**

| Table                 | Key Columns                                          | Purpose                                  |
| --------------------- | ---------------------------------------------------- | ---------------------------------------- |
| `DBUserCreationLog`   | log_id, username, created_by, creation_date          | User creation audit                      |
| `GradeUpdaters`       | id, username, created_at                             | Authorised grade updaters                |
| `BlockingSessionsLog` | id, waiter_sid, blocker_sid, wait_event, detected_at | Persistent log of blocking relationships |

---

## 7. BUSINESS RULES & CONSTRAINTS

- **Prerequisites:** A student cannot register for a course unless they have passed its prerequisite.
- **Grades:** Numeric score (0‑100) maps to letter grades and pass/fail status.
- **Warnings:** Automatically issued when a student fails 2 or more courses (preventing duplicate warnings within 30 days).
- **Suspension:** Students with 3 or more warnings are automatically suspended.
- **Grade Updates:** Only users listed in `GradeUpdaters` (USER1, MANAGER_ADMIN) may modify grades.
- **Transactions:** Multi‑row grade updates are atomic – all succeed or all fail.
- **Audit Trail:** All INSERT/DELETE operations on `REGISTER`, and all `UPDATE` operations on `STUDENTS` (for suspensions) are logged.

---

## 8. TEST SCENARIOS & SAMPLE DATA

The system is populated with a realistic dataset:

- **Professors:** Dr. Yusuf Ahmed, Dr. Toqa Hassan, Dr. Mohamed Ali.
- **Courses:** Introduction to Programming, Data Structures, Algorithms, Database Systems, Discrete Mathematics, Calculus I, Calculus II, with prerequisite chains.
- **Students (5):** Alice, Bob, Carol, David, Eve – with varying performance to test warnings and suspensions.
- **Exam Results:** Include passes and failures to trigger warnings (Bob and Carol each fail 2 courses initially).

**Key test cases executed by `06_TESTING_ALL_FEATURES.sql`:**

- Prerequisite block (Carol fails Intro → cannot register Data Structures).
- Warning generation (Bob & Carol receive warnings after failing 2 courses).
- Suspension procedure (after artificially adding third warning).
- Grade update transaction rollback (invalid ID in batch).
- GPA calculation for all students.
- Grade authorisation check (USER2 denied).

---

## 9. PERFORMANCE & SCALABILITY CONSIDERATIONS

- **Indexes:** Implicit indexes on primary keys and unique constraints; recommended additional indexes on foreign keys and common filter columns (e.g., `register(student_id, course_id)`, `examresults(registration_id, status)`).
- **Transaction Management:** Short, well‑defined transactions to minimise locking.
- **Lock Monitoring:** `find_blocking_sessions` procedure for real‑time detection; historical logging enables trend analysis.
- **Batch Operations:** Multi‑grade update uses procedural parsing of comma‑separated IDs; for very large lists, bulk binding could be added.

---

## 10. TROUBLESHOOTING COMMON ISSUES

| Issue                                     | Likely Cause                                 | Solution                                                    |
| ----------------------------------------- | -------------------------------------------- | ----------------------------------------------------------- |
| ORA-01031: insufficient privileges        | Running script as wrong user                 | Connect with the user specified in the execution order      |
| ORA-00955: name already in use            | Re‑running scripts without cleanup           | Cleanup sections in scripts handle this                     |
| ORA-02270: no matching unique/primary key | Foreign key reference to non‑existent parent | Ensure data insertion order follows dependency              |
| ORA-20001 (prerequisite not met)          | Student hasn’t passed prerequisite           | Expected business rule; register only after passing         |
| ORA-20002 (unauthorised grade update)     | User not in GradeUpdaters                    | Add user to GradeUpdaters table or use authorised account   |
| Hanging session (blocking)                | Uncommitted transaction holding locks        | Commit/rollback blocker, or use `ALTER SYSTEM KILL SESSION` |

---

## 11. EXTENSION & FUTURE ENHANCEMENTS

- **Real‑time dashboards:** Materialised views for GPA, enrolment statistics.
- **Email notifications:** Send alerts on suspension or warnings.
- **Role‑based access control:** Expand `GradeUpdaters` into a more flexible role system.
- **Performance tuning:** Partition large tables (`EXAM_RESULTS`), implement index monitoring.
- **Integration:** Web service wrappers for key procedures, enabling a front‑end student portal.

---

## 12. STATISTICS

| Metric                          | Count                                                                                                                                  |
| ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| SQL Scripts                     | 7                                                                                                                                      |
| Database Users                  | 4 (SYS, MANAGER_ADMIN, USER1, USER2)                                                                                                   |
| Core Tables                     | 8 (USER1 schema)                                                                                                                       |
| Supporting Tables               | 3 (Manager schema)                                                                                                                     |
| Triggers                        | 4 (prerequisite, audit_insert, audit_delete, grade_authorization)                                                                      |
| Functions                       | 3 (calculate_grade, calculate_gpa, is_grade_updater)                                                                                   |
| Procedures                      | 6 (issue_warnings, course_performance_report, display_exam_schedule, update_multiple_grades, suspend_students, find_blocking_sessions) |
| Stored Procedure Lines (PL/SQL) | ~1,000+                                                                                                                                |
| Test Cases                      | 19 automated + manual security test                                                                                                    |

---



The University Exam Management System is a comprehensive Oracle PL/SQL database application implementing academic workflow management with advanced security, business rule enforcement, and audit capabilities.

**Core Objectives**:

- Manage professors, courses, students, registrations, exams, and results
- Enforce prerequisite validation for course registration
- Automate academic warnings and student suspension
- Provide grade calculation and GPA computation
- Maintain complete audit trails for compliance
- Implement role-based access control with authorization checks

**Key Metrics**:

- Total Lines: ~2000 lines of PL/SQL code
- Tables: 8 core entities
- Features: 12 implemented (Features 1-12)
- PL/SQL Objects: 4 triggers, 2 functions, 5 procedures

---

## 2. System Architecture

### Architecture Layers

```
Presentation Layer
  - SQL*Plus / SQL Developer Interface
  - DBMS_OUTPUT for reporting

Application Logic Layer
  - Triggers (Business Rule Enforcement)
  - Functions (Calculations: Grade, GPA)
  - Procedures (Reports, Updates, Warnings)
  - Authorization Checks

Data Access Layer
  - Stored Procedures with Parameter Validation
  - Secure Views for Role-Based Data Access
  - Audit Trail Integration

Database Layer (Oracle)
  - 8 Normalized Tables with FK Constraints
  - Identity Columns for Primary Keys
  - CHECK Constraints for Domain Validation

Security Layer
  - Multi-User Schema Separation
  - GradeUpdaters Authorization Table
  - DBUserCreationLog for Audit Compliance
```

### Execution Flow

```
SYS (SYSDBA)
  -> Creates MANAGER_ADMIN with DBA privileges
  -> Grants V$ view access for monitoring

MANAGER_ADMIN
  -> Creates USER1 (Schema Owner) and USER2 (Data Operator)
  -> Deploys PL/SQL business logic (Features 2-10)
  -> Runs comprehensive test suite (File 06)
  -> Demonstrates concurrency features (File 07)

USER1
  -> Owns all 8 application tables
  -> Defines structural constraints and relationships
  -> Grants DML privileges to USER2

USER2
  -> Performs data entry operations
  -> Inserts professors, courses, students, exams, results
  -> Cannot modify grades (authorization enforced)
```

---

## 3. User Hierarchy & Privileges

### User Roles Matrix

| User          | Role               | Password   | Responsibilities                                        |
| ------------- | ------------------ | ---------- | ------------------------------------------------------- |
| SYS           | Root Administrator | (SYSDBA)   | Creates MANAGER_ADMIN; grants DBA privileges            |
| MANAGER_ADMIN | System Manager     | manager123 | Creates sub-users; deploys PL/SQL logic; monitors logs  |
| USER1         | Schema Owner       | user1pass  | Owns all tables; defines structural constraints         |
| USER2         | Data Operator      | user2pass  | Performs data entry (inserts students, courses, grades) |

### Privilege Model

**MANAGER_ADMIN Privileges**:

- DBA role (full database administration)
- CREATE/DROP USER, GRANT ANY PRIVILEGE
- CREATE ANY TABLE/TRIGGER/PROCEDURE
- INSERT/UPDATE/DELETE ANY TABLE
- SELECT on V$ views (session, lock, locked_object monitoring)

**USER1 Privileges**:

- CREATE SESSION, CREATE TABLE, CREATE SEQUENCE
- UNLIMITED TABLESPACE quota
- ALTER on Register and ExamResults (for trigger creation)

**USER2 Privileges**:

- CREATE SESSION only
- SELECT, INSERT, DELETE on USER1 tables (no UPDATE on grades)

### Authorization System

**GradeUpdaters Table** (manager_admin schema):

```sql
CREATE TABLE manager_admin.GradeUpdaters (
  id NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username VARCHAR2(50) NOT NULL,
  created_at TIMESTAMP DEFAULT SYSTIMESTAMP
);
```

**Authorization Function**:

```sql
CREATE OR REPLACE FUNCTION manager_admin.is_grade_updater(
  p_username IN VARCHAR2
) RETURN NUMBER;
-- Returns 1 if authorized, 0 if not (fail-secure default)
```

**Authorized Users**: USER1, MANAGER_ADMIN
**Unauthorized Users**: USER2, all others (default deny)

---

## 4. Execution Order & File Structure

### File Execution Sequence

| Step | File Name                     | Run As        | Description                                                      |
| ---- | ----------------------------- | ------------- | ---------------------------------------------------------------- |
| 1    | 01_SYS_CREATE_MANAGER.sql     | SYS           | Cleans old users; creates MANAGER_ADMIN; grants DBA roles        |
| 2    | 02_MANAGER_CREATE_USERS.sql   | MANAGER_ADMIN | Creates USER1 & USER2; creates logging table; logs user creation |
| 3    | 03_USER1_CREATE_TABLES.sql    | USER1         | Creates all 8 tables; sets PK/FK constraints; grants privileges  |
| 4    | 04_USER2_INSERT_DATA.sql      | USER2         | Inserts professors, courses, students, exams, initial results    |
| 5    | 05_MANAGER_PLSQL_FEATURES.sql | MANAGER_ADMIN | Deploys triggers, functions, procedures (Features 2-10)          |
| 6    | 06_TESTING_ALL_FEATURES.sql   | MANAGER_ADMIN | Runs test cases for all features to verify functionality         |
| 7    | 07_BLOCKER_WAITING_DEMO.sql   | MANAGER_ADMIN | Demonstrates row-locking and session killing (Features 11-12)    |

### Project Directory Structure

```
ADB_PROJECT/
├── 01_SYS_CREATE_MANAGER.sql          # SYS initialization
├── 02_MANAGER_CREATE_USERS.sql        # User management & logging
├── 03_USER1_CREATE_TABLES.sql         # Schema definition (8 tables)
├── 04_USER2_INSERT_DATA.sql           # Sample data population
├── 05_MANAGER_PLSQL_FEATURES.sql      # PL/SQL business logic
├── 06_TESTING_ALL_FEATURES.sql        # Comprehensive test suite
├── 07_BLOCKER_WAITING_DEMO.sql        # Concurrency demonstration
└── README.md                          # Project documentation
```

---

## 5. Database Schema

### Entity Relationship Diagram

```
PROFESSORS (1) ──< COURSES (N)
                      │
                      ├──< REGISTER (N) >── STUDENTS (1)
                      │         │
                      │         └──< EXAM_RESULTS (N)
                      │
                      └──< EXAMS (N)

WARNINGS (N) ──> STUDENTS (1)
AUDIT_TRAIL (N) ──> All DML operations
```

### Table Relationships

| Relationship              | Cardinality | Description                            |
| ------------------------- | ----------- | -------------------------------------- |
| PROFESSORS to COURSES     | 1:N         | Professor teaches multiple courses     |
| COURSES to REGISTER       | 1:N         | Course has multiple enrollments        |
| STUDENTS to REGISTER      | 1:N         | Student enrolls in multiple courses    |
| REGISTER to EXAM_RESULTS  | 1:N         | Registration has multiple exam results |
| COURSES to EXAMS          | 1:N         | Course has multiple exam sessions      |
| COURSES to COURSES (self) | 1:1         | Prerequisite relationship              |
| STUDENTS to WARNINGS      | 1:N         | Student may receive multiple warnings  |

---

## 6. Table Structures

### 6.1 PROFESSORS Table

| Column     | Type          | Key | Description               |
| ---------- | ------------- | --- | ------------------------- |
| id         | NUMBER        | PK  | Auto-generated identity   |
| name       | VARCHAR2(100) |     | Professor name (NOT NULL) |
| department | VARCHAR2(100) |     | Department name           |

### 6.2 COURSES Table

| Column                 | Type          | Key | Description                   |
| ---------------------- | ------------- | --- | ----------------------------- |
| id                     | NUMBER        | PK  | Auto-generated identity       |
| name                   | VARCHAR2(100) |     | Course name (NOT NULL)        |
| professor_id           | NUMBER        | FK  | References PROFESSORS(id)     |
| credit_hours           | NUMBER(1)     |     | Credit hours (CHECK 1-6)      |
| prerequisite_course_id | NUMBER        | FK  | Self-reference to COURSES(id) |

### 6.3 STUDENTS Table

| Column          | Type          | Key | Description                                  |
| --------------- | ------------- | --- | -------------------------------------------- |
| id              | NUMBER        | PK  | Auto-generated identity                      |
| name            | VARCHAR2(100) |     | Student name (NOT NULL)                      |
| academic_status | VARCHAR2(20)  |     | Active/Suspended/Graduated (default: Active) |
| total_credits   | NUMBER        |     | Accumulated credits (default: 0)             |

### 6.4 REGISTER Table (Junction/Bridge)

| Column                        | Type   | Key | Description                    |
| ----------------------------- | ------ | --- | ------------------------------ |
| id                            | NUMBER | PK  | Auto-generated identity        |
| student_id                    | NUMBER | FK  | References STUDENTS(id)        |
| course_id                     | NUMBER | FK  | References COURSES(id)         |
| UNIQUE(student_id, course_id) |        |     | Prevents duplicate enrollments |

### 6.5 EXAMS Table

| Column    | Type         | Key | Description                           |
| --------- | ------------ | --- | ------------------------------------- |
| id        | NUMBER       | PK  | Auto-generated identity               |
| course_id | NUMBER       | FK  | References COURSES(id)                |
| exam_date | DATE         |     | Exam date (NOT NULL)                  |
| exam_type | VARCHAR2(20) |     | Midterm/Final/Quiz (CHECK constraint) |

### 6.6 EXAM_RESULTS Table

| Column          | Type         | Key | Description                   |
| --------------- | ------------ | --- | ----------------------------- |
| id              | NUMBER       | PK  | Auto-generated identity       |
| registration_id | NUMBER       | FK  | References REGISTER(id)       |
| score           | NUMBER(5,2)  |     | Numeric score (0-100 or NULL) |
| grade           | VARCHAR2(2)  |     | Letter grade (A/B/C/D/F)      |
| status          | VARCHAR2(10) |     | Pass/Fail (CHECK constraint)  |

### 6.7 WARNINGS Table

| Column         | Type          | Key | Description                    |
| -------------- | ------------- | --- | ------------------------------ |
| id             | NUMBER        | PK  | Auto-generated identity        |
| student_id     | NUMBER        | FK  | References STUDENTS(id)        |
| warning_reason | VARCHAR2(500) |     | Reason for warning (NOT NULL)  |
| warning_date   | DATE          |     | Date issued (default: SYSDATE) |

### 6.8 AUDIT_TRAIL Table

| Column     | Type           | Key | Description                              |
| ---------- | -------------- | --- | ---------------------------------------- |
| id         | NUMBER         | PK  | Auto-generated identity                  |
| table_name | VARCHAR2(50)   |     | Affected table name                      |
| operation  | VARCHAR2(20)   |     | INSERT/UPDATE/DELETE                     |
| old_data   | VARCHAR2(1000) |     | Data before change                       |
| new_data   | VARCHAR2(1000) |     | Data after change                        |
| timestamp  | TIMESTAMP      |     | Change timestamp (default: SYSTIMESTAMP) |

### 7. Feature Implementation Details

### Feature 1: User Management & Logging

**Type**: DDL + Procedure
**Implementation**:

- MANAGER_ADMIN creates users with audit logging
- log_user_creation procedure inserts records into DBUserCreationLog
- Automatic case normalization and transaction commitment

### Feature 2: Prerequisite Validation Trigger

**Type**: BEFORE INSERT Trigger on REGISTER
**Logic**:

```sql
-- Check if course has prerequisite
-- Query ExamResults for PASS status on prerequisite course
-- Raise ORA-20001 if prerequisites not met
```

**Business Rules**:

- Only PASS status satisfies prerequisite requirement
- Multiple attempts allowed (one pass sufficient)
- Real-time validation during registration
- Clear error messages with course names

### Feature 3: Grade Calculation Function

**Type**: Function calculate_grade
**Parameters**: exam_result_id, numeric_score (optional)
**Returns**: VARCHAR2 letter grade (A/B/C/D/F)



- Dual-purpose: calculate from new score or update existing
- Automatic status determination (Pass/Fail)
- Direct database update with NULL-safe handling

### Feature 4: Automated Warning Procedure

**Type**: Procedure issue_warnings_for_failures
**Logic**:

- Aggregate cursor finds students with 2+ failing grades
- Inserts warning record with failure count in reason
- 30-day cooldown prevents duplicate warnings for same reason
- Automatic COMMIT for persistence

### Feature 5: Registration Audit Trail Triggers

**Type**: BEFORE INSERT/DELETE Triggers on REGISTER
**Logic**:

- Captures operation type, timestamp, and :OLD/:NEW values
- Logs to AUDIT_TRAIL table with complete data capture
- Immutable audit trail for compliance requirements

### Feature 6: Course Performance Report

**Type**: Procedure course_performance_report
**Parameters**: course_id
**Output**: Formatted report with:

- Student list with grades and pass/fail status
- Pass rate and failure rate percentages
- Column-aligned DBMS_OUTPUT formatting

### Feature 7: Exam Schedule Management

**Type**: Procedure display_exam_schedule
**Parameters**: course_id (optional, NULL = all courses)
**Output**: Course name, exam date, exam type sorted by date

### Feature 8: Batch Grade Update with Transactions

**Type**: Procedure update_multiple_grades
**Parameters**: p_registration_ids (CSV string), p_new_grade
**Transaction Control**:

- Atomic updates: all succeed or all rollback
- Invalid ID triggers immediate ROLLBACK
- Status synchronization: grade determines Pass/Fail
- Robust CSV parsing with whitespace handling

### Feature 9: Student Suspension Procedure

**Type**: Procedure suspend_students_with_warnings
**Logic**:

- Identifies students with 3+ warnings and Active status
- Updates academic_status to 'Suspended'
- Logs status change to AUDIT_TRAIL
- Automatic COMMIT after processing

### Feature 10A: GPA Calculation Function

**Type**: Function calculate_gpa
**Parameters**: student_id
**Returns**: NUMBER(3,2) GPA value




**Formula**: GPA = SUM(GradePoints * CreditHours) / SUM(CreditHours)
**Features**:

- Weighted by credit hours
- Zero-division protection
- Rounded to 2 decimal places
- Handles missing credit hours (defaults to 3)

### Feature 10B: Grade Authorization Trigger

**Type**: BEFORE UPDATE Trigger on EXAM_RESULTS
**Logic**:

- Checks current USER against GradeUpdaters table
- Uses manager_admin.is_grade_updater helper function
- Raises ORA-20002 if unauthorized
- Fail-secure: authorization failure denies access

### Feature 11: Blocker-Waiting Demonstration

**Type**: Educational Demo + Test Table
**Purpose**: Demonstrates Oracle row-level locking (ACID properties)
**Mechanism**:

- Session 1: UPDATE without COMMIT holds exclusive row lock
- Session 2: UPDATE same row blocks until Session 1 commits/rolls back
- Illustrates transaction isolation and concurrency control

### Feature 12: Blocking Session Detection

**Type**: Procedure find_blocking_sessions
**Logic**:

- Queries V$SESSION for blocking_session relationships
- Logs detected pairs to BlockingSessionsLog table
- Provides blocker/waiter session details and wait events
- Supports automated monitoring via DBMS_SCHEDULER

---

## 8. PL/SQL Objects Summary

### Triggers (4 Total)

| Trigger Name              | Table        | Event         | Purpose                          |
| ------------------------- | ------------ | ------------- | -------------------------------- |
| trg_check_prerequisite    | REGISTER     | BEFORE INSERT | Validate course prerequisites    |
| trg_audit_register_insert | REGISTER     | BEFORE INSERT | Log new registrations            |
| trg_audit_register_delete | REGISTER     | BEFORE DELETE | Log removed registrations        |
| trg_grade_authorization   | EXAM_RESULTS | BEFORE UPDATE | Enforce grade update permissions |

### Functions (2 Total)

| Function Name   | Parameters                    | Returns  | Purpose                               |
| --------------- | ----------------------------- | -------- | ------------------------------------- |
| calculate_grade | exam_result_id, numeric_score | VARCHAR2 | Convert numeric score to letter grade |
| calculate_gpa   | student_id                    | NUMBER   | Calculate weighted GPA for student    |

### Procedures (5 Total)

| Procedure Name                 | Parameters                  | Purpose                                      |
| ------------------------------ | --------------------------- | -------------------------------------------- |
| issue_warnings_for_failures    | None                        | Auto-issue warnings for 2+ failing courses   |
| course_performance_report      | course_id                   | Generate formatted course performance report |
| display_exam_schedule          | course_id (optional)        | Display exam schedule for course(s)          |
| update_multiple_grades         | registration_ids CSV, grade | Atomic batch grade updates                   |
| suspend_students_with_warnings | None                        | Suspend students with 3+ warnings            |

### Supporting Procedures (MANAGER_ADMIN Schema)

| Procedure Name         | Purpose                                       |
| ---------------------- | --------------------------------------------- |
| log_user_creation      | Standardized logging for user creation events |
| find_blocking_sessions | Detect and log blocking session pairs         |

---

## 9. Testing & Verification

### Test Suite Structure (File 06)

**Test 1: User Management**

- Verify 3 users exist (MANAGER_ADMIN, USER1, USER2)
- Confirm 2+ audit log entries for user creation
- Display audit log contents for manual verification

**Test 2: Prerequisite Trigger**

- Negative: David (failed prerequisite) attempts Database Systems → Expect ORA-20001
- Positive: Alice (passed prerequisite) attempts Algorithms → Expect success
- Verify error code and message content

**Test 3: Grade Calculation**

- Test existing score calculation (ID 1, stored score)
- Test override parameter (ID 2, provided score 85 → Grade B)
- Boundary tests: score 60 → D/Pass, score 59 → F/Fail
- Verify database persistence of calculated grades

**Test 4: Automated Warnings**

- Pre-test: Identify students with 2+ fails (Bob, Carol)
- Execute procedure and verify warnings table populated
- Confirm warning reason includes failure count
- Verify 30-day duplicate prevention logic

**Test 5: Audit Trail Triggers**

- Phase 1: INSERT test registration → Verify audit entry count +1
- Phase 2: DELETE test registration → Verify audit entry count +1
- Display audit entries showing old_data/new_data capture

**Test 6: Course Performance Report**

- Execute for Course 1 (Intro to Programming, 5 students)
- Verify formatted output with grades and pass/fail status
- Confirm accurate pass/fail percentage calculations

**Test 7: Exam Schedule Display**

- Execute for all courses (default parameter)
- Verify 7 exams displayed sorted by date
- Confirm course name resolution via join

**Test 8: Batch Grade Update**

- Phase 1: Update IDs 10,11 to grade 'A' → Expect COMMIT, both updated
- Phase 2: Update IDs 10,9999,11 to grade 'B' → ID 9999 invalid → Expect ROLLBACK, no changes
- Verify final state matches expectations

**Test 9: Student Suspension**

- Setup: Add warnings to reach 3+ threshold for Bob/Carol
- Execute suspension procedure
- Verify academic_status changed to 'Suspended'
- Confirm audit trail entry for status change

**Test 10A: GPA Calculation**

- Loop through all 5 students and calculate/display GPA
- Verify weighted calculation: Alice ~3.46, Bob ~1.67, Carol ~0.00, David ~3.00, Eve ~4.00
- Confirm precision (2 decimal places) and zero-division handling

**Test 10B: Grade Authorization**

- Phase 1: MANAGER_ADMIN updates grade → Expect success
- Phase 2: Manual test required (connect as USER2, attempt update) → Expect ORA-20002
- Verify authorization table and fail-secure behavior

### Test Results Summary

- Automated Tests: 19/19 passing
- Manual Tests: 1/1 required (security validation)
- All features integrated with no major compatibility issues
- Business rules enforced: prerequisites, warnings, suspensions functional

### Post-Test Database State

**Intentionally Preserved**:

- Suspended student status (Bob, Carol) for workflow demonstration
- Modified grades (IDs 10, 11) for transaction testing validation
- Additional warnings and audit entries for compliance verification

**Cleaned Up**:

- Test registration (student 4 → course 3) removed within transaction
- Temporary test data isolated and rolled back

---

## 10. Concurrency Management

### Feature 11: Blocker-Waiting Demonstration

**Manual Two-Window Method**:

```sql
-- Window 1 (Blocker): Connect as USER1
UPDATE user1.Students SET total_credits = 999 WHERE id = 1;
-- DO NOT COMMIT - holds exclusive row lock

-- Window 2 (Waiter): Connect as USER1 in separate session
UPDATE user1.Students SET total_credits = 0 WHERE id = 1;
-- This statement blocks, waiting for Window 1 to commit/rollback

-- Window 3 (Monitor): Connect as MANAGER_ADMIN
BEGIN
  manager_admin.find_blocking_sessions();
END;
-- Displays blocking pair details

-- Resolution (Window 1):
COMMIT;  -- or ROLLBACK
-- Window 2 immediately proceeds
```

**Automated Scheduler Method** (requires DBMS_SCHEDULER privileges):

- LOCK_JOB: Holds lock on student record for 15 seconds
- WAITER_JOB: Starts 1 second later, attempts conflicting update
- Self-cleaning jobs demonstrate real blocking scenario

### Feature 12: Blocking Session Detection

**Detection Algorithm**:

```sql
SELECT ws.sid AS waiter_sid, ws.serial# AS waiter_serial,
       ws.username AS waiter_user,
       bs.sid AS blocker_sid, bs.serial# AS blocker_serial,
       bs.username AS blocker_user,
       ws.event AS wait_event
FROM v$session ws
JOIN v$session bs ON ws.blocking_session = bs.sid
WHERE ws.blocking_session IS NOT NULL
  AND ws.blocking_session != 0;
```

**BlockingSessionsLog Table**:

- Persistent storage of detected blocking relationships
- Columns: detected_at, waiter_*, blocker_*, wait_event
- Enables historical analysis and trend reporting

**find_blocking_sessions Procedure**:

- Clears log table, detects current blockers, inserts new entries
- Outputs formatted details via DBMS_OUTPUT
- Returns count of detected blocking pairs

### Lock Resolution Strategies

**Normal Resolution**:

- COMMIT: Successful transaction completion, releases locks
- ROLLBACK: Transaction failure/abort, releases locks

**Forced Resolution** (Emergency DBA intervention):

```sql
ALTER SYSTEM KILL SESSION 'sid,serial#' IMMEDIATE;
-- Example using detected values:
ALTER SYSTEM KILL SESSION '144,12345' IMMEDIATE;
```

**Prevention Strategies**:

1. Keep transactions short; commit frequently
2. Consistent access order across application modules
3. Use NOWAIT or timeout clauses for lock acquisition
4. Implement regular blocking detection monitoring
5. Design proper transaction boundaries in application logic

### Oracle Wait Events Reference

| Wait Event                    | Description                 | Resolution                           |
| ----------------------------- | --------------------------- | ------------------------------------ |
| enq: TX - row lock contention | Row-level lock contention   | Commit/rollback blocker session      |
| enq: TM - contention          | Table-level lock contention | Reduce DDL operations during peak    |
| library cache lock            | Object compilation/parsing  | Avoid DDL during high-load periods   |
| buffer busy waits             | Buffer pool contention      | Increase buffers or tune SQL queries |

### Monitoring Queries

**Current Session Information**:

```sql
SELECT SYS_CONTEXT('USERENV', 'SID') AS current_sid,
       SYS_CONTEXT('USERENV', 'SESSIONID') AS audit_sid,
       USER AS current_user
FROM DUAL;
```

**All User Sessions**:

```sql
SELECT sid, serial#, username, status,
       NVL(TO_CHAR(blocking_session), 'None') AS blocked_by,
       NVL(event, 'None') AS wait_event
FROM v$session
WHERE username IS NOT NULL
  AND username NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'SYSMAN')
ORDER BY sid;
```

**Active Locks on USER1 Objects**:

```sql
SELECT s.sid, s.serial#, s.username, o.object_name,
       DECODE(l.locked_mode, 0,'None', 1,'Null', 2,'Row-S',
              3,'Row-X', 4,'Share', 5,'S/Row-X', 6,'Exclusive') AS lock_mode
FROM v$locked_object l
JOIN dba_objects o ON l.object_id = o.object_id
JOIN v$session s ON l.session_id = s.sid
WHERE o.owner = 'USER1'
ORDER BY s.sid;
```

---

## 11. Installation & Setup

### Prerequisites

- Oracle Database 11g or higher
- SYSDBA connection privileges for initial setup
- USERS tablespace available with sufficient quota
- DBMS_LOCK and DBMS_SCHEDULER packages accessible (for advanced features)

### Setup Procedure

**Step 1: SYS Initialization**

```bash
sqlplus / as sysdba
@01_SYS_CREATE_MANAGER.sql
```

- Cleans existing test users and sessions
- Creates MANAGER_ADMIN with DBA privileges
- Grants V$ view access for monitoring
- Verification: Query DBA_USERS and DBA_ROLE_PRIVS

**Step 2: User Management**

```bash
sqlplus manager_admin/manager123
@02_MANAGER_CREATE_USERS.sql
```

- Creates USER1 (schema owner) and USER2 (data operator)
- Sets up DBUserCreationLog and GradeUpdaters tables
- Logs user creation events for audit compliance
- Verification: Query ALL_USERS and manager_admin tables

**Step 3: Schema Creation**

```bash
sqlplus user1/user1pass
@03_USER1_CREATE_TABLES.sql
```

- Creates all 8 application tables with constraints
- Sets up identity columns, foreign keys, CHECK constraints
- Grants SELECT/INSERT/DELETE to USER2; full DML + ALTER to MANAGER_ADMIN
- Verification: Query USER_TABLES and USER_CONSTRAINTS

**Step 4: Data Population**

```bash
sqlplus user2/user2pass
@04_USER2_INSERT_DATA.sql
```

- Inserts 3 professors, 7 courses, 5 students
- Creates 14 registrations with prerequisite chains
- Populates 7 exams and 14 exam results with varied performance
- Verification: Count records in each table; verify prerequisite relationships

**Step 5: PL/SQL Deployment**

```bash
sqlplus manager_admin/manager123
@05_MANAGER_PLSQL_FEATURES.sql
```

- Deploys 4 triggers, 2 functions, 5 procedures
- Implements Features 2-10 business logic
- Verification: Query ALL_OBJECTS for USER1 schema

**Step 6: Testing**

```bash
sqlplus manager_admin/manager123
@06_TESTING_ALL_FEATURES.sql
```

- Runs comprehensive test suite for all features
- Outputs PASS/FAIL status for each test case
- Verification: Review DBMS_OUTPUT for test results

**Step 7: Concurrency Demo** (Optional)

```bash
sqlplus manager_admin/manager123
@07_BLOCKER_WAITING_DEMO.sql
```

- Demonstrates blocking detection and resolution
- Creates BlockingSessionsLog table and find_blocking_sessions procedure
- Verification: Execute manual two-window blocking scenario

### Post-Installation Verification

**Table Count Verification**:

```sql
SELECT COUNT(*) FROM user_tables WHERE owner = 'USER1';
-- Expected: 8 tables
```

**Object Count Verification**:

```sql
SELECT object_type, COUNT(*)
FROM all_objects
WHERE owner = 'USER1'
  AND object_type IN ('TRIGGER', 'FUNCTION', 'PROCEDURE')
GROUP BY object_type;
-- Expected: TRIGGER: 4, FUNCTION: 2, PROCEDURE: 5
```

**Data Population Verification**:

```sql
SELECT 'Professors' AS table_name, COUNT(*) AS row_count FROM user1.Professors
UNION ALL SELECT 'Courses', COUNT(*) FROM user1.Courses
UNION ALL SELECT 'Students', COUNT(*) FROM user1.Students
UNION ALL SELECT 'Register', COUNT(*) FROM user1.Register
UNION ALL SELECT 'Exams', COUNT(*) FROM user1.Exams
UNION ALL SELECT 'ExamResults', COUNT(*) FROM user1.ExamResults;
-- Expected: Professors: 3, Courses: 7, Students: 5, Register: 14, Exams: 7, ExamResults: 14
```

---

## 12. Security Considerations

### Principle of Least Privilege Implementation

| User          | Granted Privileges                                   | Justification                                          |
| ------------- | ---------------------------------------------------- | ------------------------------------------------------ |
| USER1         | CREATE TABLE, SEQUENCE, UNLIMITED TABLESPACE         | Schema owner needs structural control                  |
| USER2         | CREATE SESSION, SELECT/INSERT/DELETE on USER1 tables | Data operator needs entry capabilities only            |
| MANAGER_ADMIN | DBA role, ALTER on specific tables                   | System manager needs deployment and maintenance access |

### Defense in Depth Layers

1. **Authentication**: Password-protected users with schema separation
2. **Authorization**: GradeUpdaters whitelist for grade modifications
3. **Audit Trail**: DBUserCreationLog and AUDIT_TRAIL for compliance tracking
4. **Separation of Duties**: USER1 (structure) vs USER2 (data) vs MANAGER_ADMIN (security)
5. **Fail-Secure Defaults**: Authorization function returns 0 (deny) on any error

### Secure Design Patterns

**Case Normalization**:

- UPPER() applied to usernames prevents case-sensitivity bypass attempts
- Consistent handling across authorization checks and audit logs

**Indirect Access**:

- USER1 accesses GradeUpdaters via is_grade_updater function, not direct table access
- Prevents enumeration of authorized users while enabling authorization checks

**Transaction Safety**:

- COMMIT in logging procedures ensures audit persistence even if main transaction rolls back
- Explicit transaction boundaries in batch operations (Feature 8) prevent partial updates

**SQL Injection Prevention**:

- Feature 8 uses parameterized list parsing with TO_NUMBER validation
- No dynamic SQL construction with user input in critical procedures

### Audit and Compliance

**Audit Requirements Met**:

- Who: Creator and created user logged in DBUserCreationLog
- What: User creation, grade updates, status changes captured
- When: Precise TIMESTAMP with microsecond precision
- Where: Source database instance and session context

**Retention Policy**:

- DBUserCreationLog: Permanent record (no automatic purging)
- AUDIT_TRAIL: Consider archival strategy for long-term compliance
- BlockingSessionsLog: Implement retention policy based on operational needs

**Access Control**:

- Log tables accessible only to MANAGER_ADMIN
- Authorization table protected via function interface
- Direct grants limited to necessary privileges only






