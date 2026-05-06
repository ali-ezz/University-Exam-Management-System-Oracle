# Oracle University Exam Management System

A comprehensive Oracle PL/SQL implementation for managing university exams, student registrations, grades, warnings, and audit trails.

## Overview

This repository contains a complete exam management solution built using Oracle SQL and PL/SQL scripts. It is designed for university database administrators, faculty, and academic IT teams who need a reliable, role-based system for student enrollment, exam scheduling, grade processing, and policy enforcement.

## Problem Solved

Many academic institutions require a centralized system to manage student course registration, prerequisite validation, exam scoring, grade authorization, warnings, and audit logging. This project provides a secure, database-driven workflow for those operations using Oracle database features.

## Features

- User and role management with least-privilege deployment
- Course registration with prerequisite enforcement
- Automated grade calculation and pass/fail assignment
- Academic warning generation for failing students
- Student suspension workflow based on repeated warnings
- GPA calculation and grade authorization controls
- Audit trail for registration, grade, and status changes
- Exam schedule reporting and course performance summaries
- Transaction-safe batch grade update operations
- Blocker-waiter deadlock and session-lock demonstration

## Tech Stack

- Oracle Database
- PL/SQL
- SQL scripts

## Prerequisites

- Oracle Database instance
- SQL*Plus, SQLcl, or equivalent Oracle client
- Access to a SYSDBA account and the ability to create users and schemas

## Installation

1. Clone the repository to your local machine:
   ```bash
   git clone https://github.com/ali-ezz/University-Exam-Management-System-Oracle.git
   cd University-Exam-Management-System-Oracle
   ```
2. Review connection settings and environment placeholders in `.env.example`.
3. Execute the SQL scripts in the order shown below using the appropriate Oracle user account.

## Usage

Run the scripts in sequence to deploy the system and verify functionality:

1. `01_SYS_CREATE_MANAGER.sql` as `SYS`
2. `02_MANAGER_CREATE_USERS.sql` as `MANAGER_ADMIN`
3. `03_USER1_CREATE_TABLES.sql` as `USER1`
4. `04_USER2_INSERT_DATA.sql` as `USER2`
5. `05_MANAGER_PLSQL_FEATURES.sql` as `MANAGER_ADMIN`
6. `06_TESTING_ALL_FEATURES.sql` as `MANAGER_ADMIN`
7. `07_BLOCKER_WAITING_DEMO.sql` as `MANAGER_ADMIN`

### Example

```sql
CONNECT sys/your_sys_password AS SYSDBA
@01_SYS_CREATE_MANAGER.sql
CONNECT manager123@ORCL
@02_MANAGER_CREATE_USERS.sql
CONNECT user1pass@ORCL
@03_USER1_CREATE_TABLES.sql
CONNECT user2pass@ORCL
@04_USER2_INSERT_DATA.sql
``` 

## Project Structure

- `01_SYS_CREATE_MANAGER.sql` — root setup and manager creation
- `02_MANAGER_CREATE_USERS.sql` — user creation and grant management
- `03_USER1_CREATE_TABLES.sql` — schema and table creation
- `04_USER2_INSERT_DATA.sql` — sample data insertion
- `05_MANAGER_PLSQL_FEATURES.sql` — triggers, functions, procedures, and business logic
- `06_TESTING_ALL_FEATURES.sql` — end-to-end feature validation
- `07_BLOCKER_WAITING_DEMO.sql` — lock and session management demonstration
- `.env.example` — database connection placeholder values
- `LICENSE` — open-source license
- `.gitignore` — ignored local files and temp artifacts
- `requirements.txt` — optional dependency references
- `CONTRIBUTING.md` — contribution guidelines
- `CHANGELOG.md` — release notes and version history
- `.github/` — issue and pull request templates

## Results

This repository delivers a structured Oracle database application with:

- role-based deployment and permission control
- validation of prerequisites and academic policy enforcement
- audit-ready change tracking for critical operations
- automated workflows for warnings, suspensions, and grade updates
- demonstration of Oracle locking behavior and session management

## Future Improvements

- Add automated deployment scripts for Oracle CLI environments
- Build a web or desktop UI for student and administrator workflows
- Add unit tests for PL/SQL procedures and validation packages
- Publish database diagrams and ER design documentation

## License

This project is licensed under the MIT License. See `LICENSE` for details.
