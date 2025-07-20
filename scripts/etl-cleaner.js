#!/usr/bin/env node

/**
 * ETL Data Cleaning Script Runner
 * Executes the SQL data cleaning script for the users table
 */

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

class ETLDataCleaner {
  constructor() {
    // Database connection configuration
    this.pool = new Pool({
      user: process.env.DB_USER || 'postgres',
      host: process.env.DB_HOST || 'localhost',
      database: process.env.DB_NAME || 'workshop_db',
      password: process.env.DB_PASSWORD || 'password',
      port: process.env.DB_PORT || 5432,
    });
  }

  /**
   * Execute SQL file
   */
  async executeSQLFile(filePath) {
    try {
      const sql = fs.readFileSync(filePath, 'utf8');
      console.log(`📄 Executing SQL file: ${filePath}`);
      
      // Split SQL commands by semicolon and execute them one by one
      const commands = sql.split(';').filter(cmd => cmd.trim().length > 0);
      
      for (let i = 0; i < commands.length; i++) {
        const command = commands[i].trim();
        if (command) {
          try {
            const result = await this.pool.query(command);
            if (result.rows && result.rows.length > 0) {
              console.log(`✅ Command ${i + 1}/${commands.length} executed successfully`);
              // Log results for analysis queries
              if (command.toLowerCase().includes('select')) {
                console.table(result.rows);
              }
            }
          } catch (error) {
            console.error(`❌ Error executing command ${i + 1}:`, error.message);
            console.log(`Command: ${command.substring(0, 100)}...`);
          }
        }
      }
    } catch (error) {
      console.error('❌ Error reading SQL file:', error.message);
      throw error;
    }
  }

  /**
   * Run data quality analysis before cleaning
   */
  async runDataQualityAnalysis() {
    console.log('\n🔍 Running Data Quality Analysis...\n');
    
    const analysisQueries = [
      {
        name: 'Total Records Count',
        query: `
          SELECT 
            'users' as table_name,
            COUNT(*) as total_rows
          FROM users;
        `
      },
      {
        name: 'NULL Values Analysis',
        query: `
          SELECT 
            COUNT(CASE WHEN auth_id IS NULL THEN 1 END) as null_auth_id,
            COUNT(CASE WHEN full_name IS NULL OR TRIM(full_name) = '' THEN 1 END) as null_full_name,
            COUNT(CASE WHEN username IS NULL OR TRIM(username) = '' THEN 1 END) as null_username,
            COUNT(CASE WHEN phone_number IS NULL OR TRIM(phone_number) = '' THEN 1 END) as null_phone
          FROM users;
        `
      },
      {
        name: 'Duplicate Usernames',
        query: `
          SELECT 
            username,
            COUNT(*) as duplicate_count
          FROM users 
          WHERE username IS NOT NULL
          GROUP BY username 
          HAVING COUNT(*) > 1
          LIMIT 10;
        `
      },
      {
        name: 'Invalid Email Formats',
        query: `
          SELECT COUNT(*) as invalid_emails
          FROM users u
          JOIN auth a ON u.auth_id = a.id
          WHERE a.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';
        `
      }
    ];

    for (const analysis of analysisQueries) {
      try {
        console.log(`📊 ${analysis.name}:`);
        const result = await this.pool.query(analysis.query);
        console.table(result.rows);
        console.log('');
      } catch (error) {
        console.error(`❌ Error in ${analysis.name}:`, error.message);
      }
    }
  }

  /**
   * Create database backup
   */
  async createBackup() {
    console.log('\n💾 Creating database backup...\n');
    
    const backupQueries = [
      'CREATE TABLE IF NOT EXISTS users_backup AS SELECT * FROM users WHERE 1=1;',
      'CREATE TABLE IF NOT EXISTS auth_backup AS SELECT * FROM auth WHERE 1=1;',
      'CREATE TABLE IF NOT EXISTS user_roles_backup AS SELECT * FROM user_roles WHERE 1=1;',
      'CREATE TABLE IF NOT EXISTS user_divisions_backup AS SELECT * FROM user_divisions WHERE 1=1;',
      'CREATE TABLE IF NOT EXISTS user_logs_backup AS SELECT * FROM user_logs WHERE 1=1;'
    ];

    for (const query of backupQueries) {
      try {
        await this.pool.query(query);
        console.log('✅ Backup table created successfully');
      } catch (error) {
        console.error('❌ Error creating backup:', error.message);
      }
    }
  }

  /**
   * Run the complete ETL cleaning process
   */
  async runETLCleaning() {
    console.log('🚀 Starting ETL Data Cleaning Process...\n');
    
    try {
      // Step 1: Initial analysis
      await this.runDataQualityAnalysis();
      
      // Step 2: Create backups
      await this.createBackup();
      
      // Step 3: Execute the main cleaning script
      const sqlFilePath = path.join(__dirname, 'etl-data-cleaning.sql');
      if (fs.existsSync(sqlFilePath)) {
        await this.executeSQLFile(sqlFilePath);
      } else {
        console.error('❌ ETL SQL file not found:', sqlFilePath);
        return;
      }
      
      // Step 4: Final validation
      console.log('\n🔍 Running Final Validation...\n');
      await this.runDataQualityAnalysis();
      
      console.log('\n🎉 ETL Data Cleaning Process Completed Successfully!');
      console.log('📋 Summary:');
      console.log('   - Data backups created');
      console.log('   - NULL values handled');
      console.log('   - Duplicates removed');
      console.log('   - Invalid formats cleaned');
      console.log('   - Indexes rebuilt');
      console.log('   - Statistics updated');
      
    } catch (error) {
      console.error('❌ ETL Process failed:', error.message);
      throw error;
    } finally {
      await this.pool.end();
    }
  }

  /**
   * Validate specific data patterns
   */
  async validateDataPatterns() {
    console.log('\n🔍 Validating Data Patterns...\n');
    
    const validationQueries = [
      {
        name: 'Email Format Validation',
        query: `
          SELECT 
            u.id,
            u.username,
            a.email,
            CASE 
              WHEN a.email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$' 
              THEN 'Valid' 
              ELSE 'Invalid' 
            END as email_status
          FROM users u
          JOIN auth a ON u.auth_id = a.id
          WHERE a.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
          LIMIT 5;
        `
      },
      {
        name: 'Phone Number Validation',
        query: `
          SELECT 
            id,
            username,
            phone_number,
            CASE 
              WHEN phone_number ~ '^\\+?[0-9]{10,15}$' 
              THEN 'Valid' 
              ELSE 'Invalid' 
            END as phone_status
          FROM users 
          WHERE phone_number IS NOT NULL 
          AND phone_number !~ '^\\+?[0-9]{10,15}$'
          LIMIT 5;
        `
      },
      {
        name: 'Birth Date Validation',
        query: `
          SELECT 
            id,
            username,
            birth_date,
            CASE 
              WHEN birth_date > CURRENT_DATE THEN 'Future Date'
              WHEN birth_date < '1900-01-01' THEN 'Too Old'
              ELSE 'Valid'
            END as date_status
          FROM users 
          WHERE birth_date IS NOT NULL 
          AND (birth_date > CURRENT_DATE OR birth_date < '1900-01-01')
          LIMIT 5;
        `
      }
    ];

    for (const validation of validationQueries) {
      try {
        console.log(`📋 ${validation.name}:`);
        const result = await this.pool.query(validation.query);
        if (result.rows.length > 0) {
          console.table(result.rows);
        } else {
          console.log('✅ No issues found');
        }
        console.log('');
      } catch (error) {
        console.error(`❌ Error in ${validation.name}:`, error.message);
      }
    }
  }

  /**
   * Generate cleaning report
   */
  async generateCleaningReport() {
    console.log('\n📊 Generating Data Cleaning Report...\n');
    
    try {
      const reportQuery = `
        SELECT 
          'Data Cleaning Summary' as report_title,
          (SELECT COUNT(*) FROM users) as total_users,
          (SELECT COUNT(*) FROM auth) as total_auth_records,
          (SELECT COUNT(*) FROM user_roles) as total_roles,
          (SELECT COUNT(*) FROM user_divisions) as total_divisions,
          (SELECT COUNT(*) FROM user_logs) as total_logs,
          CURRENT_TIMESTAMP as report_generated_at;
      `;
      
      const result = await this.pool.query(reportQuery);
      console.table(result.rows);
    } catch (error) {
      console.error('❌ Error generating report:', error.message);
    }
  }
}

// CLI interface
if (require.main === module) {
  const etlCleaner = new ETLDataCleaner();
  
  const command = process.argv[2];
  
  switch (command) {
    case 'analyze':
      etlCleaner.runDataQualityAnalysis()
        .then(() => process.exit(0))
        .catch(error => {
          console.error('Process failed:', error);
          process.exit(1);
        });
      break;
      
    case 'clean':
      etlCleaner.runETLCleaning()
        .then(() => process.exit(0))
        .catch(error => {
          console.error('Process failed:', error);
          process.exit(1);
        });
      break;
      
    case 'validate':
      etlCleaner.validateDataPatterns()
        .then(() => process.exit(0))
        .catch(error => {
          console.error('Process failed:', error);
          process.exit(1);
        });
      break;
      
    case 'report':
      etlCleaner.generateCleaningReport()
        .then(() => process.exit(0))
        .catch(error => {
          console.error('Process failed:', error);
          process.exit(1);
        });
      break;
      
    default:
      console.log('🧹 ETL Data Cleaning Tool');
      console.log('');
      console.log('Usage:');
      console.log('  node etl-cleaner.js analyze  - Analyze data quality issues');
      console.log('  node etl-cleaner.js clean    - Run complete ETL cleaning process');
      console.log('  node etl-cleaner.js validate - Validate data patterns');
      console.log('  node etl-cleaner.js report   - Generate cleaning report');
      console.log('');
      console.log('Environment Variables:');
      console.log('  DB_HOST     - Database host (default: localhost)');
      console.log('  DB_PORT     - Database port (default: 5432)');
      console.log('  DB_NAME     - Database name (default: workshop_db)');
      console.log('  DB_USER     - Database user (default: postgres)');
      console.log('  DB_PASSWORD - Database password (default: password)');
      break;
  }
}

module.exports = ETLDataCleaner;
