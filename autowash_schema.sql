-- ============================================================================
-- SQL DDL SCHEMA SCRIPT FOR AUTOWASH PRO (SU26SWP01)
-- Matches: AutoWash.vpp (Visual Paradigm ERD) & C# Entity Framework Core Model
-- Target Database: PostgreSQL / Supabase
-- Note: Table and column names are mapped to lowercase for Supabase compatibility
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table: tiers
-- ----------------------------------------------------------------------------
CREATE TABLE tiers (
    tierid SERIAL PRIMARY KEY,
    tiername VARCHAR(255) NOT NULL,
    minrankingbalance INT NOT NULL,
    maintainbalance INT NOT NULL,
    bookingwindowdays INT NOT NULL,
    queuepriority INT NOT NULL,
    pointmultiplier DECIMAL(19, 2) NOT NULL,
    discountpercent DECIMAL(19, 2) NOT NULL,
    badgecolor INT,
    sortorder INT NOT NULL
);

-- ----------------------------------------------------------------------------
-- 2. Table: accounts
-- ----------------------------------------------------------------------------
CREATE TABLE accounts (
    accountid SERIAL PRIMARY KEY,
    googleid VARCHAR(255),
    fullname VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    passwordhash VARCHAR(255),
    role INT NOT NULL, -- Enum AccountRole (int representation)
    isactive BOOLEAN NOT NULL DEFAULT TRUE,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for accounts
CREATE UNIQUE INDEX uq_accounts_googleid ON accounts(googleid) WHERE googleid IS NOT NULL;
CREATE UNIQUE INDEX uq_accounts_email ON accounts(email);
CREATE UNIQUE INDEX uq_accounts_phone ON accounts(phone) WHERE phone IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 3. Table: customers
-- ----------------------------------------------------------------------------
CREATE TABLE customers (
    customerid SERIAL PRIMARY KEY,
    accountid INT NOT NULL REFERENCES accounts(accountid) ON DELETE CASCADE,
    membershipcode VARCHAR(50) NOT NULL,
    tierid INT NOT NULL REFERENCES tiers(tierid) ON DELETE RESTRICT,
    pointbalance INT NOT NULL DEFAULT 0,
    lifetimepoints INT NOT NULL DEFAULT 0,
    rankingbalance INT NOT NULL DEFAULT 0,
    totalvisits INT NOT NULL DEFAULT 0,
    totalspend INT NOT NULL DEFAULT 0,
    joinedat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lastvisitat TIMESTAMP,
    lasttierreviewat TIMESTAMP
);

-- Indexes for customers
CREATE UNIQUE INDEX uq_customers_accountid ON customers(accountid);
CREATE UNIQUE INDEX uq_customers_membershipcode ON customers(membershipcode);

-- ----------------------------------------------------------------------------
-- 4. Table: vehicles
-- ----------------------------------------------------------------------------
CREATE TABLE vehicles (
    vehicleid SERIAL PRIMARY KEY,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    licenseplate VARCHAR(255) NOT NULL,
    brand VARCHAR(255),
    model VARCHAR(255),
    vehicleclass VARCHAR(50),
    registeredat TIMESTAMP NOT NULL
);

-- Indexes for vehicles
CREATE UNIQUE INDEX uq_vehicles_licenseplate ON vehicles(licenseplate);

-- ----------------------------------------------------------------------------
-- 5. Table: services
-- ----------------------------------------------------------------------------
CREATE TABLE services (
    serviceid SERIAL PRIMARY KEY,
    servicename VARCHAR(255) NOT NULL,
    description TEXT,
    category INT NOT NULL, -- Enum ServiceCategory
    baseprice INT NOT NULL,
    estimatedminutes INT NOT NULL,
    isaddon BOOLEAN NOT NULL DEFAULT FALSE,
    isactive BOOLEAN NOT NULL DEFAULT TRUE,
    isfeatured BOOLEAN NOT NULL DEFAULT FALSE
);

-- ----------------------------------------------------------------------------
-- 6. Table: bookings
-- ----------------------------------------------------------------------------
CREATE TABLE bookings (
    bookingid SERIAL PRIMARY KEY,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE RESTRICT,
    vehicleid INT NOT NULL REFERENCES vehicles(vehicleid) ON DELETE RESTRICT,
    scheduledat TIMESTAMP NOT NULL,
    status INT NOT NULL, -- Enum BookingStatus
    baseprice INT NOT NULL,
    tierdiscount INT NOT NULL DEFAULT 0,
    promodiscount INT NOT NULL DEFAULT 0,
    pointsdiscount INT NOT NULL DEFAULT 0,
    finalprice INT NOT NULL,
    pointsearned INT NOT NULL DEFAULT 0,
    pointsredeemed INT NOT NULL DEFAULT 0,
    redemptionid INT, -- FK added later to avoid circular references
    notes TEXT,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    checkinat TIMESTAMP,
    confirmedat TIMESTAMP,
    washingat TIMESTAMP,
    completeat TIMESTAMP,
    noshowat TIMESTAMP,
    fixeddurationminutes INT NOT NULL,
    pointsused INT,
    pointsvaluevnd INT,
    stars SMALLINT,
    reviewtext TEXT,
    ratingtags VARCHAR(255),
    ratingbonuspoints INT,
    cancelreason TEXT,
    cancelledby VARCHAR(255),
    cancelledat TIMESTAMP,
    reminder1sent BOOLEAN NOT NULL DEFAULT FALSE,
    reminder2sent BOOLEAN NOT NULL DEFAULT FALSE,
    noshowemailsent BOOLEAN NOT NULL DEFAULT FALSE,
    waitingcheckoutemailsent BOOLEAN NOT NULL DEFAULT FALSE,
    checkedoutat TIMESTAMP,
    checkedoutby VARCHAR(255),
    tieridsnapshot INT REFERENCES tiers(tierid) ON DELETE SET NULL,
    pointmultipliersnapshot DECIMAL(19, 2),
    reschedulecount INT NOT NULL DEFAULT 0
);

-- Indexes for bookings
CREATE INDEX idx_bookings_customerid ON bookings(customerid);
CREATE INDEX idx_bookings_scheduledat ON bookings(scheduledat);
CREATE INDEX idx_bookings_status ON bookings(status);

-- Unique index to prevent duplicate active bookings for a vehicle at the same time
CREATE UNIQUE INDEX uq_bookings_vehicle_scheduledat_active 
ON bookings(vehicleid, scheduledat) 
WHERE status != 4 AND status != 5 AND status != 7; -- Excludes Completed, Cancelled, and NoShow

-- ----------------------------------------------------------------------------
-- 7. Table: queues
-- ----------------------------------------------------------------------------
CREATE TABLE queues (
    queueid SERIAL PRIMARY KEY,
    bookingid INT REFERENCES bookings(bookingid) ON DELETE SET NULL,
    vehicleid INT REFERENCES vehicles(vehicleid) ON DELETE SET NULL,
    customerid INT REFERENCES customers(customerid) ON DELETE SET NULL,
    licenseplate VARCHAR(50) NOT NULL,
    customername VARCHAR(100),
    tierid INT REFERENCES tiers(tierid) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL, -- QueueStatus enum represented as string
    position INT NOT NULL,
    checkinat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    startedat TIMESTAMP,
    completedat TIMESTAMP,
    currentstage VARCHAR(50),
    staffnote TEXT
);

-- Indexes for queues
CREATE INDEX idx_queue_status ON queues(status);
CREATE INDEX idx_queue_plate ON queues(licenseplate);

-- ----------------------------------------------------------------------------
-- 8. Table: rewards
-- ----------------------------------------------------------------------------
CREATE TABLE rewards (
    rewardid SERIAL PRIMARY KEY,
    rewardname VARCHAR(255) NOT NULL,
    description TEXT,
    pointcost INT NOT NULL,
    rewardtype VARCHAR(50) NOT NULL,
    discountvalue DECIMAL(19, 2),
    serviceid INT REFERENCES services(serviceid) ON DELETE SET NULL,
    mintierid INT REFERENCES tiers(tierid) ON DELETE SET NULL,
    validdays INT NOT NULL,
    stocklimit INT,
    redeemedcount INT NOT NULL DEFAULT 0,
    maxredemptionspercustomer INT,
    isactive BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 9. Table: rewardredemptions
-- ----------------------------------------------------------------------------
CREATE TABLE rewardredemptions (
    redemptionid SERIAL PRIMARY KEY,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    rewardid INT NOT NULL REFERENCES rewards(rewardid) ON DELETE RESTRICT,
    bookingid INT REFERENCES bookings(bookingid) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL, -- RedemptionStatus represented as string
    expiresat TIMESTAMP NOT NULL,
    redeemedat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usedat TIMESTAMP,
    vouchercode VARCHAR(50) NOT NULL
);

-- Indexes for rewardredemptions
CREATE INDEX idx_redemptions_customerid ON rewardredemptions(customerid);
CREATE INDEX idx_redemptions_customer_status ON rewardredemptions(customerid, status);
CREATE UNIQUE INDEX uq_rewardredemptions_vouchercode ON rewardredemptions(vouchercode);

-- Now we can add the circular FK on bookings referencing rewardredemptions
ALTER TABLE bookings 
ADD CONSTRAINT fk_bookings_redemption 
FOREIGN KEY (redemptionid) REFERENCES rewardredemptions(redemptionid) ON DELETE SET NULL;

-- ----------------------------------------------------------------------------
-- 10. Table: bookingservices
-- ----------------------------------------------------------------------------
CREATE TABLE bookingservices (
    bookingserviceid SERIAL PRIMARY KEY,
    bookingid INT NOT NULL REFERENCES bookings(bookingid) ON DELETE CASCADE,
    serviceid INT NOT NULL REFERENCES services(serviceid) ON DELETE RESTRICT,
    pricesnapshot INT NOT NULL
);

-- Unique constraint for BookingServices
CREATE UNIQUE INDEX uq_bookingservices ON bookingservices(bookingid, serviceid);

-- ----------------------------------------------------------------------------
-- 11. Table: loyaltytransactions
-- ----------------------------------------------------------------------------
CREATE TABLE loyaltytransactions (
    transactionid SERIAL PRIMARY KEY,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE RESTRICT,
    points INT NOT NULL,
    transactiontype VARCHAR(50) NOT NULL,
    bookingid INT REFERENCES bookings(bookingid) ON DELETE SET NULL,
    redemptionid INT REFERENCES rewardredemptions(redemptionid) ON DELETE SET NULL,
    expirydate DATE,
    isexpired BOOLEAN NOT NULL DEFAULT FALSE,
    fromtierid INT REFERENCES tiers(tierid) ON DELETE SET NULL,
    totierid INT REFERENCES tiers(tierid) ON DELETE SET NULL,
    amount INT,
    spendingwindow VARCHAR(100),
    note TEXT,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for loyaltytransactions
CREATE INDEX idx_lt_customerid ON loyaltytransactions(customerid);
CREATE INDEX idx_lt_type ON loyaltytransactions(transactiontype);
CREATE INDEX idx_lt_expiry ON loyaltytransactions(expirydate, isexpired);

-- ----------------------------------------------------------------------------
-- 12. Table: tierperks
-- ----------------------------------------------------------------------------
CREATE TABLE tierperks (
    perkid SERIAL PRIMARY KEY,
    tierid INT NOT NULL REFERENCES tiers(tierid) ON DELETE CASCADE,
    perktype VARCHAR(50) NOT NULL,
    perkvalue DECIMAL(19, 2) NOT NULL,
    serviceid INT REFERENCES services(serviceid) ON DELETE SET NULL,
    description TEXT NOT NULL,
    isactive BOOLEAN NOT NULL DEFAULT TRUE
);

-- ----------------------------------------------------------------------------
-- 13. Table: bookingreschedulehistories
-- ----------------------------------------------------------------------------
CREATE TABLE bookingreschedulehistories (
    id SERIAL PRIMARY KEY,
    bookingid INT NOT NULL REFERENCES bookings(bookingid) ON DELETE CASCADE,
    oldscheduledat TIMESTAMP NOT NULL,
    newscheduledat TIMESTAMP NOT NULL,
    changedby VARCHAR(255) NOT NULL,
    reason TEXT,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 14. Table: payments
-- ----------------------------------------------------------------------------
CREATE TABLE payments (
    paymentid SERIAL PRIMARY KEY,
    bookingid INT NOT NULL REFERENCES bookings(bookingid) ON DELETE RESTRICT,
    paymentmethod INT NOT NULL,
    amount INT NOT NULL,
    status INT NOT NULL,
    txnref VARCHAR(100),
    transactionno VARCHAR(100),
    responsecode VARCHAR(20),
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paidat TIMESTAMP
);

CREATE UNIQUE INDEX uq_payments_txnref ON payments(txnref) WHERE txnref IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 15. Table: otpverifications
-- ----------------------------------------------------------------------------
CREATE TABLE otpverifications (
    otpid SERIAL PRIMARY KEY,
    email VARCHAR(100) NOT NULL,
    platenumber VARCHAR(50),
    purpose VARCHAR(50),
    code VARCHAR(6) NOT NULL,
    expiresat TIMESTAMP NOT NULL,
    isused BOOLEAN NOT NULL DEFAULT FALSE,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_otp_email ON otpverifications(email);
CREATE INDEX idx_otp_platenumber ON otpverifications(platenumber) WHERE platenumber IS NOT NULL;

-- ----------------------------------------------------------------------------
-- 16. Table: loyaltyconfigs
-- ----------------------------------------------------------------------------
CREATE TABLE loyaltyconfigs (
    configid SERIAL PRIMARY KEY,
    pointsperthousandvnd INT NOT NULL,
    pointexpirymonths INT NOT NULL,
    tierreviewdayofmonth INT NOT NULL,
    rankingwindowyears INT NOT NULL,
    updatedat TIMESTAMP,
    updatedby INT REFERENCES accounts(accountid) ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- 17. Table: notifications
-- ----------------------------------------------------------------------------
CREATE TABLE notifications (
    notificationid SERIAL PRIMARY KEY,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    isread BOOLEAN NOT NULL DEFAULT FALSE,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notifications_customerid ON notifications(customerid);
CREATE INDEX idx_notifications_isread ON notifications(customerid, isread);

-- ----------------------------------------------------------------------------
-- 18. Table: reviews
-- ----------------------------------------------------------------------------
CREATE TABLE reviews (
    id SERIAL PRIMARY KEY,
    bookingid INT NOT NULL REFERENCES bookings(bookingid) ON DELETE CASCADE,
    customerid INT NOT NULL REFERENCES customers(customerid) ON DELETE CASCADE,
    rating INT NOT NULL,
    comment TEXT,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX uq_reviews_bookingid ON reviews(bookingid);

-- ----------------------------------------------------------------------------
-- 19. Table: bookingauditlogs
-- ----------------------------------------------------------------------------
CREATE TABLE bookingauditlogs (
    id SERIAL PRIMARY KEY,
    bookingid INT NOT NULL REFERENCES bookings(bookingid) ON DELETE CASCADE,
    action VARCHAR(255) NOT NULL,
    description TEXT,
    performedby VARCHAR(255) NOT NULL,
    createdat TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- Seeding Initial Master Data (Example basic service)
-- ============================================================================
INSERT INTO services (serviceid, servicename, description, category, baseprice, estimatedminutes, isaddon, isactive, isfeatured)
VALUES (999, 'Standard Car Wash', 'Dịch vụ rửa xe tiêu chuẩn bao gồm: Rửa ngoại thất, vệ sinh bánh xe, hút bụi nội thất, lau kính, lau taplo, dưỡng nội thất cơ bản, kiểm tra cuối.', 1, 250000, 60, FALSE, TRUE, TRUE)
ON CONFLICT (serviceid) DO NOTHING;
