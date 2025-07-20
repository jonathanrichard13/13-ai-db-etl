# Installation Guide

## Prerequisites

- Node.js 14.x or higher
- PostgreSQL 12.x or higher
- Git

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/database-optimization-project.git
cd database-optimization-project
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Database Setup

#### Create Database

```bash
createdb workshop_db
```

#### Run Schema Migration

```bash
npm run db:setup
```

### 4. Environment Configuration

```bash
cp .env.example .env
```

Edit the `.env` file with your database credentials:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=workshop_db
DB_USER=your_username
DB_PASSWORD=your_password
```

### 5. Run ETL Process

```bash
npm run etl
```

## Verification

To verify the installation:

1. Check database connection:

   ```bash
   psql -U your_username -d workshop_db -c "SELECT version();"
   ```

2. Verify tables:

   ```bash
   psql -U your_username -d workshop_db -c "\dt"
   ```

3. Run ETL script:
   ```bash
   npm start
   ```

## Troubleshooting

### Common Issues

1. **Database Connection Error**

   - Verify PostgreSQL is running
   - Check credentials in `.env` file
   - Ensure database exists

2. **Permission Denied**

   - Check user permissions
   - Verify pg_hba.conf configuration

3. **Node.js Version Issues**
   - Ensure Node.js 14.x or higher
   - Use `node --version` to check

### Getting Help

- Check the logs in the console output
- Review the database logs
- Refer to the main README.md for detailed documentation
