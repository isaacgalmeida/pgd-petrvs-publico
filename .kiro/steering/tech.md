# Technology Stack

## Backend

- **Framework**: Laravel 10.x (PHP 8.1+)
- **Database**: Multi-tenant architecture with Stancl/Tenancy
- **Queue System**: Laravel Horizon for job processing
- **Authentication**: Laravel Sanctum + JWT
- **PDF Generation**: DomPDF
- **Excel Processing**: Maatwebsite Excel, PhpSpreadsheet
- **External Integrations**: Google API Client, SOAP services
- **Auditing**: Laravel Auditing for change tracking
- **Development Tools**: Laravel Telescope, Tinker

## Frontend

- **Framework**: Angular 18.x
- **Language**: TypeScript 5.4.x
- **UI Components**: PrimeNG 17.x, Bootstrap 5.3.x
- **Icons**: FontAwesome 6.x, Bootstrap Icons
- **Rich Text**: TinyMCE
- **Calendar**: FullCalendar
- **Utilities**: Moment.js, UUID, XLSX processing
- **Development**: Karma, Jasmine, Protractor for testing

## Build System & Commands

### Backend (Laravel)

```bash
# Development setup
composer install
php artisan key:generate
php artisan migrate
php artisan serve

# Queue processing
php artisan horizon

# Testing
php artisan test
```

### Frontend (Angular)

```bash
# Development setup
npm install

# Development server
npm run start  # Serves on 0.0.0.0 with polling

# Build for production
npm run build  # Outputs to ../back-end/public

# Build for development
npm run build-dev

# Testing
npm run test
npm run e2e
```

## Docker Integration

- Backend container: `petrvs_php`
- Frontend container: `petrvs_node`
- Access containers via provided shell scripts

## Environment Configuration

- Backend: `.env.dev.template`, `.env.production.template`
- Frontend: Proxy configuration in `src/proxy.conf.json`
- Multi-environment build configurations (dev/production)
