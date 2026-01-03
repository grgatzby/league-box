# League Box

Rails app generated with [lewagon/rails-templates](https://github.com/
lewagon/rails-templates).

A Rails-based tennis box league management system that helps tennis clubs organize intra-club championships. Players are divided into boxes of comparable skill level (4-6 players), compete in monthly rounds, and rankings are automatically updated after each match.

## Overview

League Box is a web application designed to manage tennis box league tournaments within a club. The system organizes players into skill-based boxes, tracks match results, maintains rankings, and facilitates communication through real-time chatrooms.

### Key Concepts

- **Box League**: A tournament format where players are grouped into boxes of 4-6 players based on skill level
- **Rounds**: Monthly competition periods where players compete against others in their box
- **Promotion/Relegation**: At the end of each round, top players move up boxes and bottom players move down
- **Round Ranking**: Current round standings within each box
- **League Table**: Overall tournament standings across all rounds

## Features

### For Players

- View boxes in list or table format
- Enter match scores after playing
- View round rankings and overall league tables
- Access box-specific chatrooms for communication
- View personal match history and scores
- Set user preferences (e.g., clear format display)

### For Referees

All player features, plus:

- Enter, edit, and delete match scores for any player
- Access general chatroom (for communication with referees from other clubs)
- Access all chatrooms within their club
- Request new round creation from admin

### For Admins

All referee features, plus:

- Create new clubs and boxes from formatted CSV files
- Create and manage rounds
- Access any chatroom in the system
- Manage club settings and configurations

## Tech Stack

### Backend

- **Ruby** 3.3.10
- **Rails** 7.0.4
- **PostgreSQL** - Database
- **Redis** - Action Cable adapter for real-time features
- **Devise** - User authentication
- **CarrierWave** + **Cloudinary** - Image uploads (profile pictures)

### Frontend

- **Hotwire** (Turbo + Stimulus) - Modern Rails frontend framework
- **Bootstrap** 5.2 - UI framework
- **Font Awesome** 6.1 - Icons
- **Simple Form** - Form builder
- **Action Cable** - WebSocket support for real-time chat

### Additional Tools

- **Sprockets** - Asset pipeline
- **Sass** - CSS preprocessing
- **Faker** - Test data generation
- **Mail Form** - Contact form handling

### Internationalization

- Multi-language support: English (en), French (fr), Dutch (nl)
- Locale-based routing
- Comprehensive translation files

## Prerequisites

Before you begin, ensure you have the following installed:

- **Ruby** 3.3.10 (use [rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io/))
- **PostgreSQL** 9.3 or higher
- **Redis** (for Action Cable)
- **Node.js** and **npm** or **yarn**
- **Bundler** gem
- **Cloudinary account** (for image uploads in production)

## Installation & Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd league-box
```

### 2. Install Dependencies

Install Ruby gems:

```bash
bundle install
```

Install JavaScript dependencies:

```bash
yarn install
# or
npm install
```

### 3. Database Setup

Create and setup the database:

```bash
rails db:create
rails db:migrate
rails db:seed
```

Or use the setup script which handles all of this:

```bash
bin/setup
```

### 4. Environment Variables

Create a `.env` file in the root directory (if using dotenv-rails) with the following variables:

```bash
# Database (if not using default PostgreSQL settings)
# DATABASE_URL=postgres://user:password@localhost/league_box_development

# Cloudinary (for image uploads)
CLOUDINARY_URL=cloudinary://api_key:api_secret@cloud_name

# Redis (for Action Cable)
REDIS_URL=redis://localhost:6379/0
```

### 5. Start Required Services

Make sure PostgreSQL and Redis are running:

```bash
# PostgreSQL (macOS with Homebrew)
brew services start postgresql

# Redis (macOS with Homebrew)
brew services start redis

# Or start them manually
postgres -D /usr/local/var/postgres
redis-server
```

## Running the Application

### Development Mode

Start the development server using the Procfile.dev:

```bash
bin/dev
```

This will start:
- Rails server (web)
- JavaScript build watcher (js)

Alternatively, start them separately:

```bash
# Terminal 1: Rails server
rails server

# Terminal 2: JavaScript watcher
yarn build --watch
```

The application will be available at `http://localhost:3000`

### Production Mode

```bash
RAILS_ENV=production rails server
```

## Project Structure

```
league-box/
├── app/
│   ├── assets/          # Stylesheets, images, JavaScript builds
│   ├── channels/        # Action Cable channels (chatrooms)
│   ├── controllers/     # MVC controllers
│   ├── helpers/         # View helpers
│   ├── javascript/     # Stimulus controllers and JS
│   ├── jobs/            # Background jobs
│   ├── mailers/         # Email templates
│   ├── models/          # ActiveRecord models
│   ├── uploaders/       # CarrierWave uploaders
│   └── views/           # ERB templates
├── config/              # Application configuration
│   ├── locales/         # i18n translation files
│   └── routes.rb        # Route definitions
├── db/
│   ├── migrate/         # Database migrations
│   └── schema.rb        # Current database schema
├── test/                # Test files
└── public/              # Static assets
```

## Database Schema

### Key Models and Relationships

```
Club
├── has_many :users
├── has_many :rounds
└── has_many :courts

Round
├── belongs_to :club
├── has_many :boxes
└── has_many :user_box_scores (through boxes)
  - start_date, end_date, league_start

Box
├── belongs_to :round
├── belongs_to :chatroom
├── has_many :matches
└── has_many :user_box_scores
  - box_number

Match
├── belongs_to :box
├── belongs_to :court
└── has_many :user_match_scores
  - time

User
├── belongs_to :club
├── has_many :user_match_scores
├── has_many :user_box_scores
├── has_many :messages
└── has_one :preference
  - email, first_name, last_name, nickname, phone_number, role, profile_picture

UserMatchScore
├── belongs_to :user
└── belongs_to :match
  - points, score_set1, score_set2, score_tiebreak, is_winner, input_user_id, input_date

UserBoxScore
├── belongs_to :user
└── belongs_to :box
  - points, rank, sets_won, sets_played, matches_won, matches_played, games_won, games_played

Chatroom
├── has_many :messages
└── has_one :box
  - name

Message
├── belongs_to :chatroom
└── belongs_to :user
  - content

Preference
└── belongs_to :user
  - clear_format
```

## Internationalization

The application supports three languages:

- **English** (en) - Default
- **French** (fr)
- **Dutch** (nl)

### Locale Routing

Routes are scoped by locale:

```
/en/boxes
/fr/boxes
/nl/boxes
```

The locale is automatically detected from the URL or browser headers.

### Translation Files

Translation files are located in `config/locales/`:

- `en.yml`, `fr.yml`, `nl.yml` - General translations
- `devise.en.yml`, `devise.fr.yml`, `devise.nl.yml` - Authentication translations
- `views/` - View-specific translations organized by controller

## Additional Features

### CSV Export

The application provides CSV export functionality for:

- Box data for a round (`boxes_csv/boxes`)
- Match scores for a round (`boxes_csv/scores`)
- Round league table (`user_box_scores_csv/league_table_round`)
- Overall league table (`user_box_scores_csv/league_table`)

### Real-time Chat

- Each box has its own chatroom
- Real-time messaging via Action Cable
- General chatroom available for referees
- WebSocket-based communication

### Score Tracking

- Automatic calculation of rankings based on match results
- Points system for wins/losses
- Tracks sets, games, and matches won/played
- Real-time updates to round rankings and league tables

## Testing

Run the test suite:

```bash
rails test
```

Or run specific test files:

```bash
rails test test/models/user_test.rb
rails test test/controllers/boxes_controller_test.rb
```

## Development

### Code Generation

The application uses custom generators that skip:

- Asset generation (handled by webpack)
- Helper generation
- Test framework fixtures

### Database Migrations

Create a new migration:

```bash
rails generate migration MigrationName
```

Run migrations:

```bash
rails db:migrate
```

Rollback:

```bash
rails db:rollback
```

## Deployment Considerations

### Production Environment Variables

Ensure these are set in your production environment:

- `RAILS_ENV=production`
- `LEAGUE_BOX_DATABASE_PASSWORD` (for PostgreSQL)
- `CLOUDINARY_URL` (for image uploads)
- `REDIS_URL` (for Action Cable)

### Database

The production database configuration expects:

- PostgreSQL database named `league_box_production`
- User `league_box` with password from environment variable

### Assets

Precompile assets for production:

```bash
RAILS_ENV=production rails assets:precompile
```

## Contributing

This project was generated using [lewagon/rails-templates](https://github.com/lewagon/rails-templates) from the [Le Wagon coding bootcamp](https://www.lewagon.com).

## License

[Created by Guillaume Cazals]


# application schema in https://kitt.lewagon.com/db/95868

This app helps organise intra club tennis championship where players are divided into boxes of 4 to 6 players
Within a one month time frame (a round) players will compete against other players of their box; at the end of the round
the best players in each box are upgraded one or two boxes, the worst are downgraded one or two boxes.
Available features:
- players can: view a box in list view or table view, enter their new match score, view all other boxes,
             view the round rank list and overall league table (all rounds aggregate), access their box chatroom.
- referees can additionnaly: enter / edit / delete a match score, access the #general chatroom (to chat with other clubs
             referees) and all of the chatrooms of their club, request a new round creation from the admin.
- admin can additionnaly: access any chatroom, create a new club and its boxes (from a formatted CSV file including the
             players list), create the next round.
