-- =====================================================
-- ETL DATA CLEANING SCRIPT FOR USERS TABLE
-- =====================================================
-- This script removes NULL values, duplicates, and invalid formats
-- from the users table and related tables
-- =====================================================

-- Create backup tables before cleaning
CREATE TABLE IF NOT EXISTS users_backup AS SELECT * FROM users;
CREATE TABLE IF NOT EXISTS auth_backup AS SELECT * FROM auth;
CREATE TABLE IF NOT EXISTS user_roles_backup AS SELECT * FROM user_roles;
CREATE TABLE IF NOT EXISTS user_divisions_backup AS SELECT * FROM user_divisions;
CREATE TABLE IF NOT EXISTS user_logs_backup AS SELECT * FROM user_logs;

-- =====================================================
-- PHASE 1: DATA ANALYSIS - Identify dirty data
-- =====================================================

-- Analyze NULL values in users table
SELECT 
    'users' as table_name,
    COUNT(*) as total_rows,
    COUNT(CASE WHEN auth_id IS NULL THEN 1 END) as null_auth_id,
    COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as null_full_name,
    COUNT(CASE WHEN username IS NULL OR TRIM(username) = '' THEN 1 END) as null_username,
    COUNT(CASE WHEN birth_date IS NULL THEN 1 END) as null_birth_date,
    COUNT(CASE WHEN phone_number IS NULL OR TRIM(phone_number) = '' THEN 1 END) as null_phone,
    COUNT(CASE WHEN email IS NULL OR TRIM(a.email) = '' THEN 1 END) as null_email
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id;

-- Identify duplicate users (by username)
SELECT 
    username,
    COUNT(*) as duplicate_count
FROM users 
WHERE username IS NOT NULL
GROUP BY username 
HAVING COUNT(*) > 1;

-- Identify duplicate users (by email)
SELECT 
    a.email,
    COUNT(*) as duplicate_count
FROM users u
JOIN auth a ON u.auth_id = a.id
WHERE a.email IS NOT NULL
GROUP BY a.email 
HAVING COUNT(*) > 1;

-- Identify invalid email formats
SELECT 
    u.id,
    u.username,
    a.email
FROM users u
JOIN auth a ON u.auth_id = a.id
WHERE a.email IS NOT NULL 
AND a.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

-- Identify invalid phone numbers
SELECT 
    id,
    username,
    phone_number
FROM users 
WHERE phone_number IS NOT NULL 
AND phone_number !~ '^\+?[0-9]{10,15}$';

-- Identify invalid birth dates (future dates or unrealistic ages)
SELECT 
    id,
    username,
    birth_date
FROM users 
WHERE birth_date IS NOT NULL 
AND (birth_date > CURRENT_DATE OR birth_date < '1900-01-01');

-- Identify orphaned records (users without auth)
SELECT 
    u.id,
    u.username,
    u.auth_id
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id
WHERE a.id IS NULL;

-- =====================================================
-- PHASE 2: DATA CLEANING - Remove/Fix dirty data
-- =====================================================

-- Step 1: Clean invalid email formats in auth table
UPDATE auth 
SET email = LOWER(TRIM(email))
WHERE email IS NOT NULL;

-- Step 2: Remove records with invalid email formats that can't be fixed
DELETE FROM auth 
WHERE email IS NULL 
OR email = '' 
OR email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$';

-- Step 3: Clean phone numbers - standardize format
UPDATE users 
SET phone_number = REGEXP_REPLACE(phone_number, '[^0-9+]', '', 'g')
WHERE phone_number IS NOT NULL;

-- Step 4: Remove records with invalid phone numbers
UPDATE users 
SET phone_number = NULL
WHERE phone_number IS NOT NULL 
AND LENGTH(REGEXP_REPLACE(phone_number, '[^0-9]', '', 'g')) < 10;

-- Step 5: Clean username - remove extra spaces and convert to lowercase
UPDATE users 
SET username = LOWER(TRIM(username))
WHERE username IS NOT NULL;

-- Step 6: Clean full_name - remove extra spaces
UPDATE users 
SET full_name = TRIM(REGEXP_REPLACE(full_name, '\s+', ' ', 'g'))
WHERE full_name IS NOT NULL;

-- Step 7: Remove records with invalid birth dates
UPDATE users 
SET birth_date = NULL
WHERE birth_date IS NOT NULL 
AND (birth_date > CURRENT_DATE OR birth_date < '1900-01-01');

-- Step 8: Clean bio fields - remove excessive whitespace
UPDATE users 
SET bio = TRIM(bio)
WHERE bio IS NOT NULL AND TRIM(bio) != '';

UPDATE users 
SET long_bio = TRIM(long_bio)
WHERE long_bio IS NOT NULL AND TRIM(long_bio) != '';

-- Set empty strings to NULL
UPDATE users 
SET bio = NULL 
WHERE bio IS NOT NULL AND TRIM(bio) = '';

UPDATE users 
SET long_bio = NULL 
WHERE long_bio IS NOT NULL AND TRIM(long_bio) = '';

-- Step 9: Remove orphaned users (users without valid auth)
DELETE FROM users 
WHERE auth_id IS NULL 
OR auth_id NOT IN (SELECT id FROM auth);

-- Step 10: Handle duplicate usernames - keep the oldest record
WITH duplicate_usernames AS (
    SELECT username, MIN(created_at) as earliest_created
    FROM users 
    WHERE username IS NOT NULL
    GROUP BY username 
    HAVING COUNT(*) > 1
),
users_to_delete AS (
    SELECT u.id
    FROM users u
    JOIN duplicate_usernames d ON u.username = d.username
    WHERE u.created_at > d.earliest_created
)
DELETE FROM users 
WHERE id IN (SELECT id FROM users_to_delete);

-- Step 11: Handle duplicate emails - keep the oldest record
WITH duplicate_emails AS (
    SELECT a.email, MIN(a.created_at) as earliest_created
    FROM auth a
    GROUP BY a.email 
    HAVING COUNT(*) > 1
),
auth_to_delete AS (
    SELECT a.id
    FROM auth a
    JOIN duplicate_emails d ON a.email = d.email
    WHERE a.created_at > d.earliest_created
)
DELETE FROM auth 
WHERE id IN (SELECT id FROM auth_to_delete);

-- Step 12: Remove users with essential NULL values
DELETE FROM users 
WHERE full_name IS NULL 
OR TRIM(full_name) = ''
OR username IS NULL 
OR TRIM(username) = '';

-- =====================================================
-- PHASE 3: CLEAN RELATED TABLES
-- =====================================================

-- Clean user_roles table
DELETE FROM user_roles 
WHERE user_id NOT IN (SELECT id FROM users)
OR role IS NULL 
OR TRIM(role) = '';

-- Standardize role names
UPDATE user_roles 
SET role = LOWER(TRIM(role));

-- Remove duplicate roles for same user
WITH duplicate_roles AS (
    SELECT user_id, role, MIN(created_at) as earliest_created
    FROM user_roles 
    GROUP BY user_id, role 
    HAVING COUNT(*) > 1
),
roles_to_delete AS (
    SELECT ur.id
    FROM user_roles ur
    JOIN duplicate_roles dr ON ur.user_id = dr.user_id AND ur.role = dr.role
    WHERE ur.created_at > dr.earliest_created
)
DELETE FROM user_roles 
WHERE id IN (SELECT id FROM roles_to_delete);

-- Clean user_divisions table
DELETE FROM user_divisions 
WHERE user_id NOT IN (SELECT id FROM users)
OR division_name IS NULL 
OR TRIM(division_name) = '';

-- Standardize division names
UPDATE user_divisions 
SET division_name = TRIM(REGEXP_REPLACE(division_name, '\s+', ' ', 'g'));

-- Remove duplicate divisions for same user
WITH duplicate_divisions AS (
    SELECT user_id, division_name, MIN(created_at) as earliest_created
    FROM user_divisions 
    GROUP BY user_id, division_name 
    HAVING COUNT(*) > 1
),
divisions_to_delete AS (
    SELECT ud.id
    FROM user_divisions ud
    JOIN duplicate_divisions dd ON ud.user_id = dd.user_id AND ud.division_name = dd.division_name
    WHERE ud.created_at > dd.earliest_created
)
DELETE FROM user_divisions 
WHERE id IN (SELECT id FROM divisions_to_delete);

-- Clean user_logs table
DELETE FROM user_logs 
WHERE user_id NOT IN (SELECT id FROM users)
OR action IS NULL 
OR TRIM(action) = '';

-- Standardize action names
UPDATE user_logs 
SET action = LOWER(TRIM(action));

-- =====================================================
-- PHASE 4: DATA VALIDATION AFTER CLEANING
-- =====================================================

-- Final data quality report
SELECT 
    'FINAL REPORT' as report_type,
    'users' as table_name,
    COUNT(*) as total_clean_rows,
    COUNT(CASE WHEN auth_id IS NULL THEN 1 END) as remaining_null_auth_id,
    COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as remaining_null_full_name,
    COUNT(CASE WHEN username IS NULL OR TRIM(username) = '' THEN 1 END) as remaining_null_username,
    COUNT(CASE WHEN phone_number IS NOT NULL AND phone_number !~ '^\+?[0-9]{10,15}$' THEN 1 END) as invalid_phone_numbers,
    COUNT(CASE WHEN birth_date IS NOT NULL AND (birth_date > CURRENT_DATE OR birth_date < '1900-01-01') THEN 1 END) as invalid_birth_dates
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id;

-- Check for remaining duplicates
SELECT 'Duplicate usernames remaining' as check_type, COUNT(*) as count
FROM (
    SELECT username
    FROM users 
    GROUP BY username 
    HAVING COUNT(*) > 1
) duplicates
UNION ALL
SELECT 'Duplicate emails remaining' as check_type, COUNT(*) as count
FROM (
    SELECT email
    FROM auth 
    GROUP BY email 
    HAVING COUNT(*) > 1
) duplicates;

-- =====================================================
-- PHASE 5: UPDATE INDEXES AND STATISTICS
-- =====================================================

-- Rebuild indexes for better performance
REINDEX TABLE users;
REINDEX TABLE auth;
REINDEX TABLE user_roles;
REINDEX TABLE user_divisions;
REINDEX TABLE user_logs;

-- Update table statistics
ANALYZE users;
ANALYZE auth;
ANALYZE user_roles;
ANALYZE user_divisions;
ANALYZE user_logs;

-- =====================================================
-- PHASE 6: CREATE DATA QUALITY MONITORING VIEWS
-- =====================================================

-- Create view for ongoing data quality monitoring
CREATE OR REPLACE VIEW data_quality_monitor AS
SELECT 
    'users' as table_name,
    COUNT(*) as total_rows,
    COUNT(CASE WHEN auth_id IS NULL THEN 1 END) as null_auth_id,
    COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as null_full_name,
    COUNT(CASE WHEN username IS NULL OR TRIM(username) = '' THEN 1 END) as null_username,
    COUNT(CASE WHEN phone_number IS NOT NULL AND phone_number !~ '^\+?[0-9]{10,15}$' THEN 1 END) as invalid_phone,
    COUNT(CASE WHEN birth_date IS NOT NULL AND (birth_date > CURRENT_DATE OR birth_date < '1900-01-01') THEN 1 END) as invalid_birth_date,
    CURRENT_TIMESTAMP as last_checked
FROM users u
LEFT JOIN auth a ON u.auth_id = a.id;

-- Create function for future data validation
CREATE OR REPLACE FUNCTION validate_user_data()
RETURNS TABLE (
    issue_type TEXT,
    issue_count BIGINT,
    sample_records TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'Invalid Email Format' as issue_type,
        COUNT(*) as issue_count,
        STRING_AGG(DISTINCT a.email, ', ') as sample_records
    FROM users u
    JOIN auth a ON u.auth_id = a.id
    WHERE a.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
    
    UNION ALL
    
    SELECT 
        'Invalid Phone Number' as issue_type,
        COUNT(*) as issue_count,
        STRING_AGG(DISTINCT phone_number, ', ') as sample_records
    FROM users 
    WHERE phone_number IS NOT NULL 
    AND phone_number !~ '^\+?[0-9]{10,15}$'
    
    UNION ALL
    
    SELECT 
        'Future Birth Date' as issue_type,
        COUNT(*) as issue_count,
        STRING_AGG(DISTINCT birth_date::TEXT, ', ') as sample_records
    FROM users 
    WHERE birth_date > CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================

SELECT 'ETL Data Cleaning Process Completed Successfully!' as message,
       'Check the backup tables if you need to restore any data' as note,
       'Use SELECT * FROM data_quality_monitor; to check current data quality' as monitoring;
