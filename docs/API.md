# API Documentation

## ETL Cleaner Script

### Overview

The `etl-cleaner.js` script provides automated data cleaning functionality for the database optimization project.

### Class: ETLDataCleaner

#### Constructor

```javascript
const cleaner = new ETLDataCleaner();
```

Creates a new instance with database connection pool using environment variables.

#### Methods

##### `executeSQLFile(filePath)`

Executes SQL commands from a file.

**Parameters:**

- `filePath` (string): Path to the SQL file

**Returns:** Promise

**Example:**

```javascript
await cleaner.executeSQLFile("./scripts/etl-data-cleaning.sql");
```

##### `runDataQualityAnalysis()`

Performs comprehensive data quality analysis.

**Returns:** Promise

**Analysis includes:**

- Total record counts
- NULL value analysis
- Duplicate detection
- Invalid format identification

##### `createBackup()`

Creates backup tables for all main tables.

**Returns:** Promise

**Tables backed up:**

- users → users_backup
- auth → auth_backup
- user_roles → user_roles_backup
- user_divisions → user_divisions_backup
- user_logs → user_logs_backup

##### `runETLCleaning()`

Executes the complete ETL cleaning process.

**Returns:** Promise

**Process includes:**

1. Data quality analysis
2. Backup creation
3. SQL script execution
4. Final validation

##### `validateDataPatterns()`

Validates specific data patterns and formats.

**Returns:** Promise

**Validations:**

- Email format validation
- Phone number format check
- Username uniqueness
- Referential integrity

## Usage Examples

### Basic Usage

```javascript
const { ETLDataCleaner } = require("./scripts/etl-cleaner");

async function main() {
  const cleaner = new ETLDataCleaner();

  try {
    await cleaner.runETLCleaning();
    console.log("ETL process completed successfully");
  } catch (error) {
    console.error("ETL process failed:", error);
  }
}

main();
```

### Custom Analysis

```javascript
const cleaner = new ETLDataCleaner();

// Run only data quality analysis
await cleaner.runDataQualityAnalysis();

// Create backups only
await cleaner.createBackup();

// Validate data patterns
await cleaner.validateDataPatterns();
```

## Environment Variables

| Variable      | Description       | Default     |
| ------------- | ----------------- | ----------- |
| `DB_HOST`     | Database host     | localhost   |
| `DB_PORT`     | Database port     | 5432        |
| `DB_NAME`     | Database name     | workshop_db |
| `DB_USER`     | Database user     | postgres    |
| `DB_PASSWORD` | Database password | password    |

## Error Handling

The script includes comprehensive error handling:

- **Connection Errors**: Automatic retry logic
- **SQL Errors**: Detailed error logging with query context
- **Validation Errors**: Clear error messages with data context

## Performance Considerations

- Uses connection pooling for database efficiency
- Batch processing for large datasets
- Progress logging for long-running operations
- Memory-efficient streaming for large SQL files

## Logging

The script provides detailed logging:

- 📄 SQL file execution
- ✅ Successful operations
- ❌ Error conditions
- 📊 Analysis results
- 💾 Backup operations
- 🔍 Validation results
