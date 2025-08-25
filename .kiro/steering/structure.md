# Project Structure

## Root Level Organization

```
├── back-end/          # Laravel API backend
├── front-end/         # Angular frontend application
├── resources/         # Deployment and infrastructure resources
├── CHANGELOG.md       # Version history and changes
└── README.md          # Project documentation
```

## Backend Structure (Laravel)

```
back-end/
├── app/               # Application logic
├── bootstrap/         # Framework bootstrap files
├── config/            # Configuration files
├── database/          # Migrations, seeders, factories
├── public/            # Web server document root (Angular builds here)
├── resources/         # Views, language files, assets
├── routes/            # Route definitions
├── storage/           # File storage, logs, cache
├── tests/             # PHPUnit tests
├── composer.json      # PHP dependencies
├── artisan            # Laravel command-line interface
└── .env templates     # Environment configuration templates
```

## Frontend Structure (Angular)

```
front-end/
├── src/               # Source code
│   ├── app/           # Angular application modules
│   ├── assets/        # Static assets (images, styles, docs)
│   └── environments/  # Environment-specific configs
├── e2e/               # End-to-end tests
├── angular.json       # Angular CLI configuration
├── package.json       # Node.js dependencies
├── tsconfig.json      # TypeScript configuration
└── postbuild.js       # Post-build processing script
```

## Key Conventions

### File Naming

- Laravel: Follow PSR-4 autoloading standards
- Angular: Use kebab-case for files, PascalCase for classes
- SCSS: Component-specific styles in Angular components

### Build Output

- Angular builds directly to `../back-end/public/`
- Production builds use hash-free output for Laravel integration
- Assets are copied to appropriate Laravel public directories

### Environment Management

- Backend: Environment templates for dev/production
- Frontend: Angular environments with proxy configuration
- Docker: Separate containers with shell access scripts

### Multi-tenant Architecture

- Database tenancy handled by Stancl/Tenancy package
- Tenant-specific configurations and data isolation
- Shared codebase with tenant-aware routing

### Helper Files

- Backend: Custom helpers in `app/Helpers/` (auto-loaded)
- Frontend: Utilities and services in Angular service pattern
- Shared: Documentation in `resources/` for deployment guides
