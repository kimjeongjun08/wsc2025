use dev;
CREATE TABLE user (
    userid INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL,
    status_message VARCHAR(255)
);
CREATE INDEX idx_email ON user(email);
