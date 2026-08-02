-- ============================================================
-- Bike-Taxi Platform: PostgreSQL + PostGIS Schema
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('PASSENGER', 'DRIVER', 'ADMIN');
CREATE TYPE driver_status AS ENUM ('OFFLINE', 'ONLINE', 'ON_TRIP', 'SUSPENDED');
CREATE TYPE vehicle_type AS ENUM ('BIKE', 'SCOOTER');
CREATE TYPE ride_status AS ENUM (
  'REQUESTED', 'ACCEPTED', 'ARRIVED', 'STARTED', 'COMPLETED', 'CANCELLED'
);
CREATE TYPE payment_method AS ENUM ('CASH', 'UPI');
CREATE TYPE payment_status AS ENUM ('PENDING', 'PAID', 'FAILED');

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- users
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone_number    VARCHAR(15) NOT NULL UNIQUE,
    full_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(150) UNIQUE,
    role            user_role NOT NULL DEFAULT 'PASSENGER',
    password_hash   TEXT,
    is_verified     BOOLEAN NOT NULL DEFAULT false,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_phone ON users (phone_number);
CREATE INDEX idx_users_role ON users (role);

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- drivers
-- ============================================================
CREATE TABLE drivers (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id             UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    license_number      VARCHAR(30) NOT NULL UNIQUE,
    license_expiry      DATE NOT NULL,
    status              driver_status NOT NULL DEFAULT 'OFFLINE',
    rating_avg          NUMERIC(2,1) NOT NULL DEFAULT 5.0 CHECK (rating_avg BETWEEN 0 AND 5),
    total_rides         INTEGER NOT NULL DEFAULT 0,
    is_document_verified BOOLEAN NOT NULL DEFAULT false,
    wallet_balance      NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_drivers_status ON drivers (status);
CREATE INDEX idx_drivers_user_id ON drivers (user_id);

CREATE TRIGGER trg_drivers_updated_at
BEFORE UPDATE ON drivers
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- vehicles
-- ============================================================
CREATE TABLE vehicles (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id       UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    vehicle_type    vehicle_type NOT NULL DEFAULT 'BIKE',
    registration_no VARCHAR(20) NOT NULL UNIQUE,
    make            VARCHAR(50),
    model           VARCHAR(50),
    color           VARCHAR(30),
    year            SMALLINT,
    insurance_expiry DATE,
    is_active       BOOLEAN NOT NULL DEFAULT true,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uniq_active_vehicle_per_driver
    ON vehicles (driver_id) WHERE is_active = true;

CREATE INDEX idx_vehicles_driver_id ON vehicles (driver_id);

CREATE TRIGGER trg_vehicles_updated_at
BEFORE UPDATE ON vehicles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- driver_locations (history) + current_driver_location (live)
-- ============================================================
CREATE TABLE driver_locations (
    id              BIGSERIAL PRIMARY KEY,
    driver_id       UUID NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
    geom            GEOMETRY(Point, 4326) NOT NULL,
    heading         SMALLINT CHECK (heading BETWEEN 0 AND 359),
    speed_kmph      NUMERIC(5,2),
    accuracy_meters NUMERIC(6,2),
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_driver_locations_geom ON driver_locations USING GIST (geom);
CREATE INDEX idx_driver_locations_driver_time
    ON driver_locations (driver_id, recorded_at DESC);
CREATE INDEX idx_driver_locations_recorded_brin
    ON driver_locations USING BRIN (recorded_at);

CREATE TABLE current_driver_location (
    driver_id    UUID PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
    geom         GEOMETRY(Point, 4326) NOT NULL,
    heading      SMALLINT,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_current_driver_location_geom
    ON current_driver_location USING GIST (geom);

-- ============================================================
-- rides
-- ============================================================
CREATE TABLE rides (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    passenger_id        UUID NOT NULL REFERENCES users(id),
    driver_id           UUID REFERENCES drivers(id),
    vehicle_id          UUID REFERENCES vehicles(id),

    pickup_geom         GEOMETRY(Point, 4326) NOT NULL,
    pickup_address      TEXT,
    drop_geom           GEOMETRY(Point, 4326) NOT NULL,
    drop_address        TEXT,

    status              ride_status NOT NULL DEFAULT 'REQUESTED',

    distance_meters     NUMERIC(10,2),
    duration_seconds    INTEGER,
    route_geom          GEOMETRY(LineString, 4326),

    fare_estimated      NUMERIC(8,2),
    fare_final          NUMERIC(8,2),
    payment_method      payment_method,
    payment_status      payment_status NOT NULL DEFAULT 'PENDING',

    otp_code            CHAR(4),
    cancellation_reason TEXT,
    cancelled_by        user_role,

    requested_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    accepted_at         TIMESTAMPTZ,
    arrived_at          TIMESTAMPTZ,
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rides_passenger_id ON rides (passenger_id);
CREATE INDEX idx_rides_driver_id ON rides (driver_id);
CREATE INDEX idx_rides_status ON rides (status);
CREATE INDEX idx_rides_pickup_geom ON rides USING GIST (pickup_geom);
CREATE INDEX idx_rides_requested_at ON rides (requested_at DESC);

CREATE UNIQUE INDEX uniq_driver_active_ride
    ON rides (driver_id)
    WHERE status IN ('ACCEPTED', 'ARRIVED', 'STARTED');

CREATE TRIGGER trg_rides_updated_at
BEFORE UPDATE ON rides
FOR EACH ROW EXECUTE FUNCTION set_updated_at();
